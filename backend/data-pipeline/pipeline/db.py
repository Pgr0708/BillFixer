from __future__ import annotations

import contextlib
import uuid
from typing import Iterable, Iterator, Sequence

import pymysql

from . import config


def connect() -> pymysql.connections.Connection:
    return pymysql.connect(
        **config.DB,
        charset="utf8mb4",
        autocommit=False,
        connect_timeout=15,
        read_timeout=300,
        write_timeout=300,
        init_command="SET time_zone = '+00:00'",
        cursorclass=pymysql.cursors.DictCursor,
    )


@contextlib.contextmanager
def transaction(conn) -> Iterator[pymysql.cursors.Cursor]:
    cur = conn.cursor()
    try:
        yield cur
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        cur.close()


def batched(rows: Iterable[Sequence], size: int = 500) -> Iterator[list]:
    batch: list = []
    for row in rows:
        batch.append(row)
        if len(batch) >= size:
            yield batch
            batch = []
    if batch:
        yield batch


def new_id() -> str:
    return str(uuid.uuid4())
