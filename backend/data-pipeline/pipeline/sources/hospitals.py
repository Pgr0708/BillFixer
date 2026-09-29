"""CMS Hospital General Information (dataset xubh-q36u) → providers.

The metastore endpoint exposes `modified` and the CSV download URL. We only re-download when
`modified` changes. Ownership maps to tax status; "Voluntary non-profit" hospitals must have
a financial assistance policy under IRC §501(r).
"""
from __future__ import annotations

import csv
import io
import logging
import re
from typing import Dict, Iterator, Optional, Tuple

from .. import cache, http, state
from ..db import batched, new_id

log = logging.getLogger(__name__)
METASTORE = "https://data.cms.gov/provider-data/api/1/metastore/schemas/dataset/items/xubh-q36u"
MIN_EXPECTED_ROWS = 1000  # sanity guard — never deactivate hospitals because of a truncated file

ACRONYMS = {"LLC", "LLP", "INC", "VA", "UC", "UCSF", "UCLA", "USC", "NYU", "UAB", "UT", "UPMC", "HCA", "CHI",
            "SSM", "OSF", "MUSC", "UNC", "OHSU", "II", "III", "IV", "ER", "ICU", "PA", "NY", "LA", "DC"}


def pretty_name(raw: str) -> str:
    """'ST. MARY'S MEDICAL CENTER, LLC' → "St. Mary's Medical Center, LLC" (str.title() mangles apostrophes)."""
    def fix(word: str) -> str:
        core = re.sub(r"[^A-Za-z]", "", word).upper()
        if core in ACRONYMS:
            return word.upper()
        return re.sub(r"[A-Za-z]+('[A-Za-z]+)?", lambda m: m.group(0)[0].upper() + m.group(0)[1:].lower(), word)
    return " ".join(fix(w) for w in raw.strip().split())


def tax_status(ownership: str) -> str:
    o = (ownership or "").strip().lower()
    if o.startswith("voluntary non-profit") or o.startswith("voluntary nonprofit"):
        return "nonprofit"
    if o.startswith("proprietary") or o == "physician" or o.startswith("physician"):
        return "for_profit"
    if o.startswith("government") or o in {"tribal", "veterans health administration", "department of defense"} \
            or "veterans" in o or "defense" in o:
        return "government"
    return "unknown"


def _norm(key: str) -> str:
    return re.sub(r"[^a-z0-9]+", "_", (key or "").strip().lower()).strip("_")


def _pick(row: Dict[str, str], *names: str) -> Optional[str]:
    for n in names:
        v = row.get(n)
        if v not in (None, ""):
            return v.strip()
    return None


def parse_csv(text_stream) -> Iterator[Tuple]:
    reader = csv.DictReader(text_stream)
    reader.fieldnames = [_norm(f) for f in (reader.fieldnames or [])]
    for row in reader:
        facility_id = _pick(row, "facility_id", "provider_id", "ccn")
        raw_name = _pick(row, "facility_name", "hospital_name")
        if not facility_id or not raw_name:
            continue
        ownership = _pick(row, "hospital_ownership", "ownership") or ""
        state_code = (_pick(row, "state") or "")[:2].upper() or None
        zip_code = re.sub(r"[^0-9-]", "", _pick(row, "zip_code", "zip") or "")[:10] or None
        phone = re.sub(r"[^0-9]", "", _pick(row, "telephone_number", "phone_number") or "")[:20] or None
        emergency = _pick(row, "emergency_services")
        yield (
            facility_id.zfill(6)[:20], pretty_name(raw_name)[:500], raw_name[:500],
            (_pick(row, "address") or "")[:500] or None,
            pretty_name(_pick(row, "city_town", "city") or "")[:100] or None,
            state_code, zip_code, phone,
            (_pick(row, "hospital_type") or "")[:120] or None,
            ownership[:120] or None, tax_status(ownership),
            None if emergency is None else (1 if emergency.lower() in ("yes", "y", "true") else 0),
        )


def run(conn, force: bool = False):
    meta = http.get_json(METASTORE)
    modified = meta.get("modified")
    dist = next((d for d in meta.get("distribution", []) if "csv" in str(d.get("mediaType", "")).lower()), None)
    if not dist:
        raise http.UpstreamError("CMS metastore has no CSV distribution")
    url = dist["downloadURL"]

    if not force and modified and state.get(conn, "hospitals").get("last_modified") == modified:
        state.mark(conn, "hospitals", status="ok", source_url=METASTORE)
        return ("skipped", 0, f"unchanged since {modified}")

    dl = http.download(url, max_bytes=200 * 1024 * 1024)
    seen = 0
    try:
        with open(dl.path, "r", encoding="utf-8-sig", errors="replace", newline="") as fh, conn.cursor() as cur:
            cur.execute("CREATE TEMPORARY TABLE IF NOT EXISTS _seen_cms (id VARCHAR(20) PRIMARY KEY)")
            cur.execute("TRUNCATE _seen_cms")
            for batch in batched(parse_csv(fh), 500):
                cur.executemany(
                    """INSERT INTO providers (id, cms_facility_id, name, facility_name, address, city, state, zip, phone,
                         hospital_type, ownership_raw, tax_status, emergency_services, is_active, source_updated_at)
                       VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, 1, %s)
                       ON DUPLICATE KEY UPDATE name = VALUES(name), facility_name = VALUES(facility_name),
                         address = VALUES(address), city = VALUES(city), state = VALUES(state), zip = VALUES(zip),
                         phone = VALUES(phone), hospital_type = VALUES(hospital_type), ownership_raw = VALUES(ownership_raw),
                         tax_status = VALUES(tax_status), emergency_services = VALUES(emergency_services),
                         is_active = 1, source_updated_at = VALUES(source_updated_at)""",
                    [(new_id(), *row, modified) for row in batch],
                )
                cur.executemany("INSERT IGNORE INTO _seen_cms (id) VALUES (%s)", [(row[0],) for row in batch])
                seen += len(batch)
                conn.commit()
            if seen >= MIN_EXPECTED_ROWS:
                cur.execute("""UPDATE providers p LEFT JOIN _seen_cms s ON s.id = p.cms_facility_id
                               SET p.is_active = 0 WHERE p.cms_facility_id IS NOT NULL AND s.id IS NULL""")
            conn.commit()
    finally:
        dl.path.unlink(missing_ok=True)

    if seen < MIN_EXPECTED_ROWS:
        raise http.UpstreamError(f"only {seen} hospitals parsed — keeping existing data active")
    state.mark(conn, "hospitals", status="ok", changed=True, last_modified=modified, content_hash=dl.sha256, source_url=METASTORE)
    cache.bump("providers")
    return ("ok", seen, f"{seen} hospitals (CMS modified {modified})")
