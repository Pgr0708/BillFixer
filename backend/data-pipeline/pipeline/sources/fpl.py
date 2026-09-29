"""HHS Poverty Guidelines via the official ASPE API.

GET https://aspe.hhs.gov/topics/poverty-economic-mobility/poverty-guidelines/api/{year}/{us|ak|hi}/{1..8}
→ {"data": {"year": "2026", "household_size": "1", "income": "15960", "state": "US"}, "status": 200}
The API silently falls back to the latest year for unknown years, so the returned year is verified.
"""
from __future__ import annotations

import hashlib
import json
import logging
import time
from datetime import date
from decimal import Decimal
from typing import List, Optional, Tuple

from .. import cache, http, state

log = logging.getLogger(__name__)
API = "https://aspe.hhs.gov/topics/poverty-economic-mobility/poverty-guidelines/api"
REGIONS = ("us", "ak", "hi")
SIZES = range(1, 9)


def parse_response(payload: dict, year: int, region: str, size: int) -> Optional[Decimal]:
    """Return the guideline amount, or None if the API answered for a different year/region/size."""
    data = (payload or {}).get("data") or {}
    try:
        if int(data.get("year")) != year or int(data.get("household_size")) != size:
            return None
        if str(data.get("state", "")).lower() != region:
            return None
        amount = Decimal(str(data.get("income")))
    except (TypeError, ValueError, ArithmeticError):
        return None
    return amount if Decimal("1000") < amount < Decimal("1000000") else None


def looks_consistent(rows: List[Tuple[str, int, Decimal]]) -> bool:
    """Guidelines rise by a constant per-person increment within a region — reject anything else."""
    for region in REGIONS:
        amounts = [a for r, _, a in sorted(rows, key=lambda x: (x[0], x[1])) if r == region]
        if len(amounts) != 8:
            return False
        steps = {amounts[i + 1] - amounts[i] for i in range(7)}
        if len(steps) != 1 or next(iter(steps)) <= 0:
            return False
    return True


def fetch_year(year: int) -> Optional[List[Tuple[str, int, Decimal]]]:
    rows = []
    for region in REGIONS:
        for size in SIZES:
            payload = http.get_json(f"{API}/{year}/{region}/{size}")
            amount = parse_response(payload, year, region, size)
            if amount is None:
                log.info("fpl %s not published yet (or unexpected answer for %s/%s)", year, region, size)
                return None
            rows.append((region, size, amount))
            time.sleep(0.2)  # be polite to a government API
    return rows if looks_consistent(rows) else None


def run(conn, force: bool = False) -> Tuple[str, int, str]:
    this_year = date.today().year
    upserted = 0
    notes = []
    all_rows = []
    for year in (this_year, this_year - 1):
        with conn.cursor() as cur:
            cur.execute("SELECT COUNT(*) AS n FROM fpl_guidelines WHERE year = %s", (year,))
            have = cur.fetchone()["n"]
        conn.commit()
        if have == 24 and year < this_year and not force:
            continue  # past years never change
        try:
            rows = fetch_year(year)
        except http.UpstreamError as exc:
            if have == 24:
                # Guidelines change once a year; if HHS blocks this server today, the copy we have is still correct.
                log.warning("fpl %s: source unreachable (%s) — keeping the %s rows already stored", year, exc, have)
                notes.append(f"{year}: kept existing (source unreachable)")
                continue
            raise
        if not rows:
            notes.append(f"{year}: not available")
            continue
        all_rows.extend((year, *r) for r in rows)
        with conn.cursor() as cur:
            cur.executemany(
                """INSERT INTO fpl_guidelines (year, region, household_size, amount, source_url, fetched_at)
                   VALUES (%s, %s, %s, %s, %s, UTC_TIMESTAMP())
                   ON DUPLICATE KEY UPDATE amount = VALUES(amount), source_url = VALUES(source_url), fetched_at = VALUES(fetched_at)""",
                [(year, r, s, str(a), f"{API}/{year}/{r}/{s}") for r, s, a in rows],
            )
        conn.commit()
        upserted += len(rows)
        notes.append(f"{year}: ok")

    digest = hashlib.sha256(json.dumps([[y, r, s, str(a)] for y, r, s, a in all_rows]).encode()).hexdigest() if all_rows else None
    previous = state.get(conn, "fpl").get("content_hash")
    changed = bool(digest and digest != previous)
    state.mark(conn, "fpl", status="ok", changed=changed, content_hash=digest, source_url=API)
    if changed:
        cache.bump("fpl")
    return ("ok" if upserted else "skipped", upserted, "; ".join(notes) or "up to date")
