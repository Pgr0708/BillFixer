"""Hospital price transparency machine-readable files (45 CFR Part 180).

Discovery:  https://<hospital website>/cms-hpt.txt  → "mrf-url: …" per location
Formats:    CMS template v2 JSON, CSV "tall" and CSV "wide" (github.com/CMSgov/hospital-price-transparency)
Files can be several GB, so JSON is streamed with ijson and CSV row by row; only codes the app
compares against are kept (or all CPT/HCPCS with MRF_KEEP_ALL_CODES=true).
"""
from __future__ import annotations

import csv
import json
import logging
import re
import statistics
from collections import defaultdict
from decimal import Decimal, InvalidOperation
from pathlib import Path
from typing import Dict, Iterable, Iterator, List, Optional, Tuple
from urllib.parse import urlparse

from .. import cache, config, http, state
from ..db import batched, new_id

log = logging.getLogger(__name__)
TARGETS_FILE = config.PIPELINE_DIR / "mrf_targets.json"

# CMS shoppable services + the most common ED, imaging, lab and E/M codes seen on bills.
TARGET_CODES = set("""
99202 99203 99204 99205 99211 99212 99213 99214 99215 99281 99282 99283 99284 99285 99291 99292
99221 99222 99223 99231 99232 99233 99238 99239 99243 99244 99385 99386 99395 99396
80047 80048 80050 80051 80053 80055 80061 80069 80074 80076 81000 81001 81002 81003 81025 82040 82247 82310
82565 82947 83036 84153 84443 84450 84460 84520 85004 85014 85018 85025 85027 85610 85730 86140 86592
87070 87086 87088 87186 87804 87880 36415 36416
70450 70486 70553 71045 71046 71047 71048 71250 71260 72040 72070 72100 72110 72131 72141 72148 72158 72193
73030 73060 73110 73130 73221 73502 73560 73562 73590 73610 73630 73721 74018 74019 74176 74177 74178
76536 76604 76641 76642 76700 76705 76770 76801 76805 76811 76815 76817 76830 76856 77065 77066 77067 78452 93306
93000 93005 93010 93015 93350 93452 93880 93970 95810 96360 96361 96365 96366 96372 96374 96375
90832 90834 90837 90846 90847 90853 92507 97110 97112 97116 97140 97161 97162 97163 97530
19120 29826 29827 29880 29881 42820 43235 43239 45378 45380 45385 47562 49505 55700 55866 59400 59510 59610
62322 62323 64483 66821 66984 20610 11042 12001 12002 12011 10060 10120
J1885 J2405 J1100 J0696 J7030 J7050 J1170 J2270 J3010 J1642 G0378 G0390 A0427 A0429
""".split())

CODE_TYPES = {"CPT": "hcpcs", "HCPCS": "hcpcs", "MS-DRG": "ms_drg", "DRG": "drg", "APR-DRG": "drg",
              "RC": "rev_code", "NDC": "ndc", "ICD": "icd"}


# ── cms-hpt.txt ────────────────────────────────────────────────────────────
def parse_hpt_txt(text: str) -> List[Dict[str, str]]:
    blocks, current = [], {}
    for raw in text.splitlines():
        line = raw.strip()
        if not line:
            if current:
                blocks.append(current)
                current = {}
            continue
        if ":" in line:
            key, value = line.split(":", 1)
            current[key.strip().lower()] = value.strip()
    if current:
        blocks.append(current)
    return [b for b in blocks if b.get("mrf-url")]


STOP = {"the", "of", "and", "hospital", "medical", "center", "centre", "health", "healthcare", "inc", "llc", "regional", "system"}


def _tokens(s: str) -> set:
    return {t for t in re.findall(r"[a-z0-9]+", (s or "").lower()) if t not in STOP and len(t) > 1}


def best_location(blocks: List[Dict[str, str]], provider_name: str) -> Optional[Dict[str, str]]:
    if not blocks:
        return None
    if len(blocks) == 1:
        return blocks[0]
    target = _tokens(provider_name)
    scored = sorted(((len(target & _tokens(b.get("location-name", ""))) / max(1, len(target | _tokens(b.get("location-name", "")))), b)
                     for b in blocks), key=lambda x: x[0], reverse=True)
    return scored[0][1] if scored[0][0] >= 0.25 else None


# ── aggregation ────────────────────────────────────────────────────────────
def _money(v) -> Optional[Decimal]:
    if v is None or v == "":
        return None
    try:
        d = Decimal(str(v).replace("$", "").replace(",", "").strip())
        return d if d.is_finite() and Decimal(0) <= d < Decimal(100_000_000) else None
    except (InvalidOperation, ValueError):
        return None


def _setting(v: str) -> str:
    v = (v or "").strip().lower()
    return v if v in ("inpatient", "outpatient", "both") else "unknown"


def _keep(code: str, ctype: str) -> bool:
    if ctype != "hcpcs":
        return False
    return config.MRF_KEEP_ALL_CODES or code in TARGET_CODES


class Aggregator:
    """Collapse every payer row into one reference record per (code, type, setting)."""

    def __init__(self):
        self.data = defaultdict(lambda: {"desc": None, "gross": [], "cash": [], "neg": [], "min": [], "max": [], "payers": set()})

    def add(self, code, ctype, setting, desc, gross=None, cash=None, negotiated=None, minimum=None, maximum=None, payer=None):
        code = re.sub(r"[^0-9A-Z]", "", str(code or "").upper())[:20]
        ctype = CODE_TYPES.get(str(ctype or "").upper(), "other")
        if not code or not _keep(code, ctype):
            return
        d = self.data[(code, ctype, _setting(setting))]
        d["desc"] = d["desc"] or (str(desc).strip()[:500] if desc else None)
        for key, val in (("gross", gross), ("cash", cash), ("neg", negotiated), ("min", minimum), ("max", maximum)):
            m = _money(val)
            if m is not None and m > 0:
                d[key].append(m)
        if payer and negotiated not in (None, ""):
            d["payers"].add(str(payer).strip().lower()[:120])

    def records(self) -> Iterator[Tuple]:
        for (code, ctype, setting), d in self.data.items():
            neg = d["neg"]
            lo = min(neg + d["min"]) if (neg or d["min"]) else None
            hi = max(neg + d["max"]) if (neg or d["max"]) else None
            med = statistics.median(neg) if neg else None
            yield (code, ctype, d["desc"], setting,
                   str(max(d["gross"])) if d["gross"] else None,
                   str(min(d["cash"])) if d["cash"] else None,
                   str(lo) if lo is not None else None, str(hi) if hi is not None else None,
                   str(Decimal(med).quantize(Decimal("0.01"))) if med is not None else None,
                   len(d["payers"]))


# ── JSON (CMS template v2) ─────────────────────────────────────────────────
def parse_json(fh, agg: Aggregator) -> Dict[str, Optional[str]]:
    import ijson

    meta = {"version": None, "last_updated_on": None}
    for prefix, event, value in ijson.parse(fh):
        if prefix in ("version", "last_updated_on") and event in ("string", "number"):
            meta[prefix] = str(value)
        if prefix == "standard_charge_information" and event == "start_array":
            break
    fh.seek(0)
    for item in ijson.items(fh, "standard_charge_information.item", use_float=False):
        codes = [(c.get("code"), c.get("type")) for c in item.get("code_information") or []]
        for sc in item.get("standard_charges") or []:
            for code, ctype in codes:
                payers = sc.get("payers_information") or []
                agg.add(code, ctype, sc.get("setting"), item.get("description"), gross=sc.get("gross_charge"),
                        cash=sc.get("discounted_cash"), minimum=sc.get("minimum"), maximum=sc.get("maximum"))
                for p in payers:
                    agg.add(code, ctype, sc.get("setting"), item.get("description"),
                            negotiated=p.get("standard_charge_dollar"), payer=p.get("payer_name"))
    return meta


# ── CSV (tall + wide) ──────────────────────────────────────────────────────
def parse_csv(fh, agg: Aggregator) -> Dict[str, Optional[str]]:
    reader = csv.reader(fh)
    head: List[List[str]] = []
    for row in reader:
        head.append(row)
        if any(c.strip().lower() == "description" for c in row):
            break
        if len(head) > 5:
            raise ValueError("CSV header row with 'description' not found — not a CMS template file")
    cols = [c.strip().lower() for c in head[-1]]
    meta = {"version": None, "last_updated_on": None}
    if len(head) >= 3:
        keys = [c.strip().lower() for c in head[0]]
        vals = head[1] + [""] * len(keys)
        m = dict(zip(keys, vals))
        meta = {"version": m.get("version") or None, "last_updated_on": m.get("last_updated_on") or None}

    idx = {c: i for i, c in enumerate(cols)}
    code_cols = [(i, idx.get(f"{c}|type")) for c, i in idx.items() if re.fullmatch(r"code\|\d+", c)]
    wide_neg = [i for c, i in idx.items() if re.fullmatch(r"standard_charge\|.+\|.+\|negotiated_dollar", c)]
    wide_payers = {i: cols[i].split("|")[1] for i in wide_neg}
    g = lambda row, name: row[idx[name]] if name in idx and idx[name] < len(row) else None  # noqa: E731

    for row in reader:
        if not row:
            continue
        desc, setting = g(row, "description"), g(row, "setting")
        for ci, ti in code_cols:
            code = row[ci] if ci < len(row) else None
            ctype = row[ti] if ti is not None and ti < len(row) else None
            if not code:
                continue
            agg.add(code, ctype, setting, desc, gross=g(row, "standard_charge|gross"),
                    cash=g(row, "standard_charge|discounted_cash"),
                    minimum=g(row, "standard_charge|min"), maximum=g(row, "standard_charge|max"))
            if "standard_charge|negotiated_dollar" in idx:  # tall
                agg.add(code, ctype, setting, desc, negotiated=g(row, "standard_charge|negotiated_dollar"), payer=g(row, "payer_name"))
            for i in wide_neg:  # wide
                if i < len(row):
                    agg.add(code, ctype, setting, desc, negotiated=row[i], payer=wide_payers[i])
    meta["format"] = "csv_wide" if wide_neg else "csv_tall"
    return meta


def parse_file(path: Path, content_type: str = "") -> Tuple[Aggregator, Dict[str, Optional[str]]]:
    agg = Aggregator()
    with open(path, "rb") as probe:
        first = probe.read(2048).lstrip()
    is_json = "json" in content_type or first.startswith(b"{") or path.suffix.lower() == ".json"
    if is_json:
        with open(path, "rb") as fh:
            meta = parse_json(fh, agg)
        meta["format"] = "json"
    else:
        with open(path, "r", encoding="utf-8-sig", errors="replace", newline="") as fh:
            meta = parse_csv(fh, agg)
    return agg, meta


# ── orchestration ──────────────────────────────────────────────────────────
def _site_root(url: str) -> Optional[str]:
    p = urlparse(url if "://" in url else f"https://{url}")
    return f"{p.scheme}://{p.netloc}" if p.netloc else None


def apply_targets(conn) -> int:
    """Optional mrf_targets.json: [{"cmsFacilityId": "010001", "website": "https://…", "mrfUrl": "https://…"}]."""
    if not TARGETS_FILE.exists():
        return 0
    targets = json.loads(TARGETS_FILE.read_text())
    with conn.cursor() as cur:
        for t in targets:
            cur.execute("UPDATE providers SET website = COALESCE(%s, website), mrf_url = COALESCE(%s, mrf_url) WHERE cms_facility_id = %s",
                        (t.get("website"), t.get("mrfUrl"), str(t.get("cmsFacilityId", "")).zfill(6)))
    conn.commit()
    return len(targets)


def process_provider(conn, p: dict) -> int:
    mrf_url = p.get("mrf_url")
    if not mrf_url and p.get("website"):
        root = _site_root(p["website"])
        blocks = parse_hpt_txt(http.get_text(f"{root}/cms-hpt.txt")) if root else []
        chosen = best_location(blocks, p["name"])
        if not chosen:
            raise http.UpstreamError(f"no matching location in {root}/cms-hpt.txt")
        mrf_url = chosen["mrf-url"]
    if not mrf_url:
        return 0

    dl = http.download(mrf_url, etag=p.get("mrf_etag"), last_modified=p.get("mrf_last_modified"))
    if not dl.changed:
        with conn.cursor() as cur:
            cur.execute("UPDATE providers SET mrf_last_fetched = UTC_TIMESTAMP() WHERE id = %s", (p["id"],))
        conn.commit()
        return 0
    try:
        agg, meta = parse_file(dl.path, dl.content_type)
    finally:
        dl.path.unlink(missing_ok=True)  # never keep raw price files on disk

    records = list(agg.records())
    effective = (meta.get("last_updated_on") or "")[:10] or None
    if effective and not re.fullmatch(r"\d{4}-\d{2}-\d{2}", effective):
        effective = None
    with conn.cursor() as cur:
        cur.execute("DELETE FROM hospital_price_records WHERE provider_id = %s", (p["id"],))
        for batch in batched(records, 500):
            cur.executemany(
                """INSERT INTO hospital_price_records (id, provider_id, code, code_type, description, setting, gross_charge,
                     cash_price, min_rate, max_rate, median_rate, payer_count, effective_date, mrf_version, fetched_at)
                   VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, UTC_TIMESTAMP())""",
                [(new_id(), p["id"], *r, effective, (meta.get("version") or "")[:50] or None) for r in batch],
            )
        cur.execute(
            """UPDATE providers SET mrf_url = %s, mrf_format = %s, mrf_last_fetched = UTC_TIMESTAMP(),
                 mrf_etag = %s, mrf_last_modified = %s WHERE id = %s""",
            (mrf_url[:2000], meta.get("format", "unknown"), dl.etag, dl.last_modified, p["id"]),
        )
    conn.commit()  # one transaction: the old prices are replaced atomically
    return len(records)


def run(conn, force: bool = False):
    apply_targets(conn)
    with conn.cursor() as cur:
        cur.execute(
            """SELECT id, name, website, mrf_url, mrf_etag, mrf_last_modified FROM providers
               WHERE is_active = 1 AND (website IS NOT NULL OR mrf_url IS NOT NULL)
               ORDER BY mrf_last_fetched IS NOT NULL, mrf_last_fetched LIMIT %s""",
            (config.MRF_MAX_PROVIDERS_PER_RUN,),
        )
        providers = cur.fetchall()
    conn.commit()
    if not providers:
        state.mark(conn, "mrf", status="ok")
        return ("skipped", 0, "no hospitals with a website or MRF URL yet — see mrf_targets.example.json")

    total, errors = 0, []
    for p in providers:
        try:
            n = process_provider(conn, p)
            total += n
            log.info("mrf %s: %s price records", p["name"], n)
        except Exception as exc:  # one hospital's broken file must not stop the others
            conn.rollback()
            errors.append(f"{p['name']}: {exc}")
            log.warning("mrf %s failed: %s", p["name"], exc)
    state.mark(conn, "mrf", status="error" if errors and not total else "ok", changed=total > 0,
               error="; ".join(errors)[:1000] or None)
    if total:
        cache.bump("providers")
    return ("ok" if not errors else "error" if not total else "ok", total, f"{len(providers)} hospitals, {len(errors)} errors")
