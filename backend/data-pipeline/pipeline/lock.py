from __future__ import annotations

import fcntl
import os
from contextlib import contextmanager
from pathlib import Path

from . import config


class AlreadyRunning(RuntimeError):
    pass


@contextmanager
def single_instance(name: str = "pipeline"):
    """Only one pipeline run per machine (timer overlap, manual run during a scheduled run)."""
    path = Path(os.getenv("PIPELINE_LOCK_DIR", config.PIPELINE_DIR)) / f".{name}.lock"
    fh = open(path, "w")
    try:
        fcntl.flock(fh, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError as exc:
        fh.close()
        raise AlreadyRunning(f"another {name} run holds {path}") from exc
    try:
        fh.write(str(os.getpid()))
        fh.flush()
        yield
    finally:
        fcntl.flock(fh, fcntl.LOCK_UN)
        fh.close()
