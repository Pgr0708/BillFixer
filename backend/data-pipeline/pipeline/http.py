"""HTTP with retries, conditional requests (ETag / Last-Modified) and capped streaming downloads."""
from __future__ import annotations

import hashlib
import os
import tempfile
from dataclasses import dataclass
from pathlib import Path
from typing import Optional

import requests
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry

from . import config

_session: Optional[requests.Session] = None


def session() -> requests.Session:
    global _session
    if _session is None:
        s = requests.Session()
        retry = Retry(
            total=5, connect=5, read=3, backoff_factor=2,
            status_forcelist=(429, 500, 502, 503, 504),
            allowed_methods=("GET", "HEAD"), respect_retry_after_header=True, raise_on_status=False,
        )
        adapter = HTTPAdapter(max_retries=retry, pool_connections=4, pool_maxsize=4)
        s.mount("https://", adapter)
        s.mount("http://", adapter)
        s.headers.update({"User-Agent": config.USER_AGENT, "Accept": "*/*"})
        _session = s
    return _session


class UpstreamError(RuntimeError):
    pass


def get_json(url: str, timeout: int = 30):
    r = session().get(url, timeout=timeout, headers={"Accept": "application/json"})
    if r.status_code != 200:
        raise UpstreamError(f"GET {url} → HTTP {r.status_code}")
    return r.json()


def get_text(url: str, timeout: int = 30, max_bytes: int = 5 * 1024 * 1024) -> str:
    r = session().get(url, timeout=timeout, stream=True)
    if r.status_code != 200:
        raise UpstreamError(f"GET {url} → HTTP {r.status_code}")
    data = r.raw.read(max_bytes + 1, decode_content=True)
    if len(data) > max_bytes:
        raise UpstreamError(f"{url} larger than {max_bytes} bytes")
    return data.decode(r.encoding or "utf-8", errors="replace")


@dataclass
class Download:
    changed: bool
    path: Optional[Path]
    etag: Optional[str]
    last_modified: Optional[str]
    sha256: Optional[str]
    content_type: str = ""


def download(url: str, *, etag: Optional[str] = None, last_modified: Optional[str] = None,
             max_bytes: int = config.MRF_MAX_BYTES, timeout: int = 120) -> Download:
    """Stream to a temp file. 304 → changed=False. Aborts past max_bytes. Caller deletes the file."""
    headers = {}
    if etag:
        headers["If-None-Match"] = etag
    if last_modified:
        headers["If-Modified-Since"] = last_modified
    config.DOWNLOAD_DIR.mkdir(parents=True, exist_ok=True)
    with session().get(url, headers=headers, stream=True, timeout=timeout) as r:
        if r.status_code == 304:
            return Download(False, None, etag, last_modified, None)
        if r.status_code != 200:
            raise UpstreamError(f"GET {url} → HTTP {r.status_code}")
        declared = int(r.headers.get("Content-Length") or 0)
        if declared and declared > max_bytes:
            raise UpstreamError(f"{url} is {declared} bytes (limit {max_bytes})")
        digest = hashlib.sha256()
        size = 0
        fd, tmp = tempfile.mkstemp(dir=config.DOWNLOAD_DIR, suffix=".part")
        try:
            with os.fdopen(fd, "wb") as fh:
                for chunk in r.iter_content(chunk_size=1024 * 1024):
                    if not chunk:
                        continue
                    size += len(chunk)
                    if size > max_bytes:
                        raise UpstreamError(f"{url} exceeded {max_bytes} bytes")
                    digest.update(chunk)
                    fh.write(chunk)
        except BaseException:
            Path(tmp).unlink(missing_ok=True)
            raise
        return Download(True, Path(tmp), r.headers.get("ETag"), r.headers.get("Last-Modified"),
                        digest.hexdigest(), r.headers.get("Content-Type", ""))
