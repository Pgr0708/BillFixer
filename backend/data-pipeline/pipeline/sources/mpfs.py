"""Medicare Physician Fee Schedule national payment amounts (benchmark only — never a 'correct price').

Finds the newest quarterly RVU zip on cms.gov (RVU{yy}D → A), reads the PPRRVU file, and computes
national amounts: (work + PE + malpractice RVU) × conversion factor, for facility and non-facility settings.
"""
from __future__ import annotations

import csv
import io
import logging
import re
import zipfile
from datetime import date
from decimal import Decimal, InvalidOperation, ROUND_HALF_UP
from typing import Iterator, List, Optional, Tuple

from .. import cache, config, http, state
from ..db import batched

log = logging.getLogger(__name__)
INDEX = "https://www.cms.gov/medicare/payment/fee-schedules/physician/pfs-relative-value-files"
CODE_RE = re.compile(r"^[0-9A-Z]{5}$")
PAYABLE = {"A", "R", "T"}
CENT = Decimal("0.01")


def candidate_pages(today: Optional[date] = None) -> List[Tuple[str, str, str]]:
    today = today or date.today()
    out = []
    for year in (today.year, today.year - 1):
        yy = f"{year % 100:02d}"
        for q in "dcba":
            out.append((f"{INDEX}/rvu{yy}{q}", str(year), q.upper()))
    return out


def find_zip_url(html: str, base: str = "https://www.cms.gov") -> Optional[str]:
    for href in re.findall(r'href="([^"]+\.zip)"', html, flags=re.I):
        if "rvu" in href.lower():
            return href if href.startswith("http") else base + href
    return None


def _dec(value: str) -> Optional[Decimal]:
    try:
        v = Decimal(str(value).strip())
        return v if v.is_finite() else None
    except (InvalidOperation, ValueError):
        return None


def parse_pprrvu(lines: List[List[str]], cf_override: Optional[Decimal] = None) -> Iterator[Tuple]:
    """Yield (code, modifier, description, status, nonfacility_amount, facility_amount, cf)."""
    first_data = next((i for i, r in enumerate(lines) if r and CODE_RE.match(r[0].strip().upper())), None)
    if first_data is None:
        return
    # Header text is spread over the rows above the data; merge it column-wise to find columns by name.
    header_rows = [r for r in lines[max(0, first_data - 4):first_data] if len(r) >= 10]
    width = max(len(r) for r in lines[first_data:first_data + 5])
    merged = [" ".join((r[i] if i < len(r) else "") for r in header_rows).upper() for i in range(width)]

    def col(*need, avoid=()):
        for i, h in enumerate(merged):
            if all(n in h for n in need) and not any(a in h for a in avoid):
                return i
        return None

    i_status = col("STATUS") if col("STATUS") is not None else 3
    i_nonfac = col("NON", "TOTAL") if col("NON", "TOTAL") is not None else 11
    i_fac = col("FACILITY", "TOTAL", avoid=("NON",)) if col("FACILITY", "TOTAL", avoid=("NON",)) is not None else 12
    i_cf = col("CONV") if col("CONV") is not None else 24

    for r in lines[first_data:]:
        if not r or not CODE_RE.match(r[0].strip().upper()):
            continue
        cells = r + [""] * (width - len(r))
        status = cells[i_status].strip().upper()[:1]
        if status not in PAYABLE:
            continue
        cf = cf_override or _dec(cells[i_cf])
        if cf is None or not (Decimal(20) < cf < Decimal(60)):
            continue
        nonfac = _dec(cells[i_nonfac])
        fac = _dec(cells[i_fac])
        if nonfac is None and fac is None:
            continue
        yield (
            r[0].strip().upper(), (cells[1].strip().upper() or "")[:4], cells[2].strip()[:200] or None, status,
            str((nonfac * cf).quantize(CENT, ROUND_HALF_UP)) if nonfac is not None else None,
            str((fac * cf).quantize(CENT, ROUND_HALF_UP)) if fac is not None else None,
            str(cf.quantize(Decimal("0.0001"))),
        )


def run(conn, force: bool = False):
    src = state.get(conn, "mpfs")
    zip_url = year = quarter = None
    for page, y, q in candidate_pages():
        try:
            url = find_zip_url(http.get_text(page))
        except http.UpstreamError:
            continue
        if url:
            zip_url, year, quarter = url, y, q
            break
    if not zip_url:
        raise http.UpstreamError("no RVU zip found on cms.gov")

    dl = http.download(zip_url, etag=None if force else src.get("etag"),
                       last_modified=None if force else src.get("last_modified"), max_bytes=100 * 1024 * 1024)
    if not dl.changed or (not force and dl.sha256 and dl.sha256 == src.get("content_hash")):
        if dl.path:
            dl.path.unlink(missing_ok=True)
        state.mark(conn, "mpfs", status="ok", source_url=zip_url)
        return ("skipped", 0, f"RVU{year[-2:]}{quarter} unchanged")

    try:
        with zipfile.ZipFile(dl.path) as z:
            member = next((n for n in z.namelist() if re.search(r"PPRRVU.*\.(csv|txt)$", n, re.I)), None)
            if not member:
                raise http.UpstreamError(f"PPRRVU file not found in {zip_url}")
            text = z.read(member).decode("latin-1")
        lines = list(csv.reader(io.StringIO(text)))
        override = _dec(config.MPFS_CONVERSION_FACTOR) if config.MPFS_CONVERSION_FACTOR else None
        rows = list(parse_pprrvu(lines, override))
        if len(rows) < 1000:
            raise http.UpstreamError(f"only {len(rows)} payable codes parsed from {member} — keeping existing rates")
        with conn.cursor() as cur:
            for batch in batched(rows, 1000):
                cur.executemany(
                    """INSERT INTO mpfs_rates (code, modifier, description, status_code, nonfacility_amount, facility_amount,
                         conversion_factor, year, quarter, fetched_at)
                       VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, UTC_TIMESTAMP())
                       ON DUPLICATE KEY UPDATE description = VALUES(description), status_code = VALUES(status_code),
                         nonfacility_amount = VALUES(nonfacility_amount), facility_amount = VALUES(facility_amount),
                         conversion_factor = VALUES(conversion_factor), year = VALUES(year), quarter = VALUES(quarter),
                         fetched_at = VALUES(fetched_at)""",
                    [(*r, year, quarter) for r in batch],
                )
                conn.commit()
            cur.execute("DELETE FROM mpfs_rates WHERE year <> %s OR quarter <> %s", (year, quarter))
        conn.commit()
    finally:
        dl.path.unlink(missing_ok=True)

    state.mark(conn, "mpfs", status="ok", changed=True, etag=dl.etag, last_modified=dl.last_modified,
               content_hash=dl.sha256, source_url=zip_url)
    cache.bump("mpfs")
    return ("ok", len(rows), f"RVU{year[-2:]}{quarter}: {len(rows)} codes")
