"""HTTP with retries, conditional requests (ETag / Last-Modified) and capped streaming downloads."""
from __future__ import annotations

import hashlib
import os
import shutil
import subprocess
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


# Some federal hosts (data.cms.gov, behind Akamai) answer 403 to Python's TLS/HTTP fingerprint even with a
# polite User-Agent, but accept curl. On a 403 we retry once through the system curl binary.
CURL_USER_AGENT = "BillFixerDataPipeline/1.0 (+https://billfixer.dakshyaminfotech.store)"


def _curl(url: str, out: Path, headers: dict, max_bytes: int, timeout: int, attempts: int = 6) -> tuple[int, dict]:
    """curl with patience: the CDN intermittently answers 403 to automated clients, so back off and retry."""
    import time
    status, resp = 0, {}
    for i in range(attempts):
        status, resp = _curl_once(url, out, headers, max_bytes, timeout)
        if status != 403:
            return status, resp
        time.sleep(min(5 * 2 ** i, 60))
    return status, resp


def _curl_once(url: str, out: Path, headers: dict, max_bytes: int, timeout: int) -> tuple[int, dict]:
    """GET url into `out` with curl. Returns (status, lower-cased response headers). Raises if curl is missing."""
    curl = shutil.which("curl")
    if not curl:
        raise UpstreamError(f"GET {url} blocked (403) and curl is not installed for the fallback")
    hdr_file = out.with_suffix(out.suffix + ".hdr")
    cmd = [curl, "-sS", "-L", "--compressed", "--retry", "3", "--retry-delay", "5",
           "--max-time", str(timeout), "--max-filesize", str(max_bytes),
           "-A", CURL_USER_AGENT, "-D", str(hdr_file), "-o", str(out), "-w", "%{http_code}"]
    for k, v in headers.items():
        cmd += ["-H", f"{k}: {v}"]
    cmd.append(url)
    try:
        proc = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout + 30)
        status = int((proc.stdout or "0").strip()[-3:] or 0)
        resp: dict = {}
        if hdr_file.exists():
            # With -L there may be several header blocks; the last one belongs to the final response.
            for line in hdr_file.read_text(errors="replace").splitlines():
                if line.upper().startswith("HTTP/"):
                    resp = {}
                elif ":" in line:
                    k, v = line.split(":", 1)
                    resp[k.strip().lower()] = v.strip()
        if proc.returncode not in (0,) and status == 0:
            raise UpstreamError(f"curl {url} failed: {proc.stderr.strip()[:200]}")
        return status, resp
    finally:
        hdr_file.unlink(missing_ok=True)


def _curl_bytes(url: str, headers: dict, timeout: int, max_bytes: int) -> bytes:
    config.DOWNLOAD_DIR.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=config.DOWNLOAD_DIR, suffix=".curl")
    os.close(fd)
    path = Path(tmp)
    try:
        status, _ = _curl(url, path, headers, max_bytes, timeout)
        if status != 200:
            raise UpstreamError(f"GET {url} → HTTP {status} (curl)")
        return path.read_bytes()
    finally:
        path.unlink(missing_ok=True)


def get_json(url: str, timeout: int = 30):
    r = session().get(url, timeout=timeout, headers={"Accept": "application/json"})
    if r.status_code == 403:
        import json
        return json.loads(_curl_bytes(url, {"Accept": "application/json"}, timeout, 50 * 1024 * 1024))
    if r.status_code != 200:
        raise UpstreamError(f"GET {url} → HTTP {r.status_code}")
    return r.json()


def get_text(url: str, timeout: int = 30, max_bytes: int = 5 * 1024 * 1024) -> str:
    r = session().get(url, timeout=timeout, stream=True)
    if r.status_code == 403:
        r.close()
        return _curl_bytes(url, {}, timeout, max_bytes).decode("utf-8", errors="replace")
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
        if r.status_code == 403:
            return _download_with_curl(url, headers, etag, last_modified, max_bytes, timeout)
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


def _download_with_curl(url: str, headers: dict, etag: Optional[str], last_modified: Optional[str],
                        max_bytes: int, timeout: int) -> Download:
    fd, tmp = tempfile.mkstemp(dir=config.DOWNLOAD_DIR, suffix=".part")
    os.close(fd)
    path = Path(tmp)
    try:
        status, resp = _curl(url, path, headers, max_bytes, max(timeout, 600))
        if status == 304:
            path.unlink(missing_ok=True)
            return Download(False, None, etag, last_modified, None)
        if status != 200:
            raise UpstreamError(f"GET {url} → HTTP {status} (curl)")
        digest = hashlib.sha256()
        with open(path, "rb") as fh:
            for chunk in iter(lambda: fh.read(1024 * 1024), b""):
                digest.update(chunk)
        return Download(True, path, resp.get("etag"), resp.get("last-modified"), digest.hexdigest(), resp.get("content-type", ""))
    except BaseException:
        path.unlink(missing_ok=True)
        raise
