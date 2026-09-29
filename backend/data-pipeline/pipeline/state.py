"""Per-source bookkeeping: data_sources (change detection) and ingest_runs (history)."""
from __future__ import annotations

from datetime import datetime, timedelta, timezone
from typing import Optional


def utcnow() -> datetime:
    return datetime.now(timezone.utc).replace(tzinfo=None)


def get(conn, source: str) -> dict:
    with conn.cursor() as cur:
        cur.execute("SELECT * FROM data_sources WHERE name = %s", (source,))
        row = cur.fetchone()
    conn.commit()
    return row or {}


def due(conn, source: str, interval_hours: int) -> bool:
    row = get(conn, source)
    last = row.get("last_checked_at")
    return last is None or last < utcnow() - timedelta(hours=interval_hours)


def mark(conn, source: str, *, status: str, error: Optional[str] = None, changed: bool = False,
         etag: Optional[str] = None, last_modified: Optional[str] = None, content_hash: Optional[str] = None,
         source_url: Optional[str] = None) -> None:
    with conn.cursor() as cur:
        cur.execute(
            """INSERT INTO data_sources (name, source_url, etag, last_modified, content_hash, last_checked_at, last_changed_at, status, error)
               VALUES (%s, %s, %s, %s, %s, UTC_TIMESTAMP(), IF(%s, UTC_TIMESTAMP(), NULL), %s, %s)
               ON DUPLICATE KEY UPDATE
                 source_url = COALESCE(VALUES(source_url), source_url),
                 etag = COALESCE(VALUES(etag), etag),
                 last_modified = COALESCE(VALUES(last_modified), last_modified),
                 content_hash = COALESCE(VALUES(content_hash), content_hash),
                 last_checked_at = UTC_TIMESTAMP(),
                 last_changed_at = IF(%s, UTC_TIMESTAMP(), last_changed_at),
                 status = VALUES(status), error = VALUES(error)""",
            (source, source_url, etag, last_modified, content_hash, changed, status, (error or "")[:1000] or None, changed),
        )
    conn.commit()


def start_run(conn, source: str) -> int:
    with conn.cursor() as cur:
        cur.execute("INSERT INTO ingest_runs (source, started_at, status) VALUES (%s, UTC_TIMESTAMP(), 'running')", (source,))
        run_id = cur.lastrowid
    conn.commit()
    return run_id


def finish_run(conn, run_id: int, status: str, rows: int = 0, message: Optional[str] = None) -> None:
    with conn.cursor() as cur:
        cur.execute(
            "UPDATE ingest_runs SET finished_at = UTC_TIMESTAMP(), status = %s, rows_upserted = %s, message = %s WHERE id = %s",
            (status, rows, (message or "")[:1000] or None, run_id),
        )
    conn.commit()
