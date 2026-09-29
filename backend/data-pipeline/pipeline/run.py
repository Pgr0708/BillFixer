"""Pipeline entry point.

    python -m pipeline.run                          # all sources that are due
    python -m pipeline.run --source fpl --force     # one source, ignore the interval
    python -m pipeline.run --add-site 010001 https://www.example-hospital.org
"""
from __future__ import annotations

import argparse
import logging
import sys
import time

from . import config, db, state
from .lock import AlreadyRunning, single_instance
from .sources import fpl, hospitals, mpfs, mrf

SOURCES = {"fpl": fpl, "hospitals": hospitals, "mpfs": mpfs, "mrf": mrf}
ORDER = ["fpl", "hospitals", "mpfs", "mrf"]  # hospitals before mrf: prices attach to providers

log = logging.getLogger("pipeline")


def run_source(conn, name: str, force: bool) -> bool:
    if not force and not state.due(conn, name, config.INTERVAL_HOURS[name]):
        log.info("%-9s not due yet", name)
        return True
    run_id = state.start_run(conn, name)
    started = time.monotonic()
    try:
        status, rows, message = SOURCES[name].run(conn, force=force)
        state.finish_run(conn, run_id, status, rows, message)
        log.info("%-9s %-7s %6d rows  %5.1fs  %s", name, status, rows, time.monotonic() - started, message)
        return status != "error"
    except Exception as exc:
        conn.rollback()
        # Existing data stays in place — the app keeps working on the last good copy.
        state.finish_run(conn, run_id, "error", 0, str(exc))
        state.mark(conn, name, status="error", error=str(exc))
        log.error("%-9s error   %s", name, exc)
        return False


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description="BillFixer official-data pipeline")
    parser.add_argument("--source", choices=["all", *ORDER], default="all")
    parser.add_argument("--force", action="store_true", help="ignore check intervals and change detection")
    parser.add_argument("--add-site", nargs=2, metavar=("CMS_FACILITY_ID", "WEBSITE_URL"),
                        help="register a hospital website so its price file can be discovered")
    parser.add_argument("-v", "--verbose", action="store_true")
    args = parser.parse_args(argv)
    logging.basicConfig(level=logging.DEBUG if args.verbose else logging.INFO,
                        format="%(asctime)s %(levelname)-7s %(name)s: %(message)s")

    try:
        with single_instance():
            conn = db.connect()
            try:
                if args.add_site:
                    fid, url = args.add_site
                    with conn.cursor() as cur:
                        n = cur.execute("UPDATE providers SET website = %s, mrf_url = NULL WHERE cms_facility_id = %s", (url, fid.zfill(6)))
                    conn.commit()
                    log.info("registered %s for facility %s (%s row)", url, fid, n)
                    return 0 if n else 1
                names = ORDER if args.source == "all" else [args.source]
                results = [run_source(conn, n, args.force) for n in names]
                return 0 if all(results) else 1
            finally:
                conn.close()
    except AlreadyRunning as exc:
        log.info("skipping: %s", exc)
        return 0


if __name__ == "__main__":
    sys.exit(main())
