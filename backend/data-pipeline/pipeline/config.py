"""Settings, read from backend/.env so the API and the pipeline share one config."""
from __future__ import annotations

import os
from pathlib import Path

from dotenv import load_dotenv

PIPELINE_DIR = Path(__file__).resolve().parent.parent
BACKEND_DIR = PIPELINE_DIR.parent
load_dotenv(BACKEND_DIR / ".env")


def _int(name: str, default: int) -> int:
    try:
        return int(os.getenv(name, default))
    except (TypeError, ValueError):
        return default


DB = {
    "host": os.getenv("DB_HOST", "127.0.0.1"),
    "port": _int("DB_PORT", 3306),
    "user": os.getenv("DB_USER", "billfixer"),
    "password": os.getenv("DB_PASSWORD", ""),
    "database": os.getenv("DB_NAME", "billfixer"),
}
REDIS_URL = os.getenv("REDIS_URL", "redis://127.0.0.1:6379")
REDIS_KEY_PREFIX = os.getenv("REDIS_KEY_PREFIX", "bf:")
REDIS_ENABLED = os.getenv("REDIS_ENABLED", "true").lower() == "true"

DOWNLOAD_DIR = Path(os.getenv("PIPELINE_DOWNLOAD_DIR", PIPELINE_DIR / "downloads"))
USER_AGENT = "Mozilla/5.0 (compatible; BillFixer-DataPipeline/1.0; +https://billfixer.dakshyaminfotech.store)"

# How often each source is *checked*. A check that finds no upstream change is cheap.
INTERVAL_HOURS = {"fpl": 24, "hospitals": 24, "mpfs": 168, "mrf": 168}

MRF_MAX_BYTES = _int("MRF_MAX_BYTES", 4 * 1024 ** 3)          # skip price files larger than 4 GB
MRF_MAX_PROVIDERS_PER_RUN = _int("MRF_MAX_PROVIDERS_PER_RUN", 25)
MRF_KEEP_ALL_CODES = os.getenv("MRF_KEEP_ALL_CODES", "false").lower() == "true"
MPFS_CONVERSION_FACTOR = os.getenv("MPFS_CONVERSION_FACTOR")  # optional override, e.g. 33.4009
