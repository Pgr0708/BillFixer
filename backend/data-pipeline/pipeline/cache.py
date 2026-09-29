"""Invalidate API caches after new data lands (the API reads `bf:cachever:<ns>`)."""
from __future__ import annotations

import logging

from . import config

log = logging.getLogger(__name__)


def bump(namespace: str) -> None:
    if not config.REDIS_ENABLED:
        return
    try:
        import redis

        r = redis.Redis.from_url(config.REDIS_URL, socket_timeout=3, socket_connect_timeout=3)
        r.incr(f"{config.REDIS_KEY_PREFIX}cachever:{namespace}")
    except Exception as exc:  # cache invalidation is best-effort; entries also expire on their own TTL
        log.warning("cache bump for %s failed: %s", namespace, exc)
