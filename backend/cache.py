from __future__ import annotations

import hashlib
import json
import logging
from typing import Any

from backend.core.config import settings

logger = logging.getLogger(__name__)
_client = None


def _redis_client():
    global _client

    if not settings.redis_enabled:
        return None

    if _client is not None:
        return _client

    try:
        from redis import Redis
    except ImportError as exc:
        logger.warning("Redis caching disabled; redis package is missing: %s", exc)
        return None

    try:
        client = Redis.from_url(
            settings.redis_url,
            decode_responses=True,
            socket_connect_timeout=2,
            socket_timeout=2,
        )
        client.ping()
        _client = client
        return client
    except Exception as exc:
        logger.warning("Redis caching unavailable at %s: %s", settings.redis_url, exc)
        return None


def get_cache(key: str) -> Any | None:
    if not settings.redis_enabled:
        return None

    client = _redis_client()
    if client is None:
        return None

    try:
        raw = client.get(key)
        if raw is None:
            return None
        return json.loads(raw)
    except Exception as exc:
        logger.warning("Redis cache read failed for key %s: %s", key, exc)
        return None


def set_cache(key: str, value: Any, ttl: int | None = None) -> None:
    if not settings.redis_enabled:
        return

    client = _redis_client()
    if client is None:
        return

    try:
        client.setex(
            key,
            ttl or settings.redis_cache_ttl_seconds,
            json.dumps(value, sort_keys=True, separators=(",", ":")),
        )
    except Exception as exc:
        logger.warning("Redis cache write failed for key %s: %s", key, exc)


def make_cache_key(user_id: str | None, preferences_dict: dict[str, Any]) -> str:
    payload = {
        "user_id": user_id or "anonymous",
        "preferences": _normalize(preferences_dict),
    }
    encoded = json.dumps(payload, sort_keys=True, separators=(",", ":"))
    digest = hashlib.sha256(encoded.encode("utf-8")).hexdigest()
    return f"recommendations:{digest}"


def _normalize(value: Any) -> Any:
    if isinstance(value, dict):
        return {
            str(key): _normalize(value[key])
            for key in sorted(value)
        }

    if isinstance(value, (list, tuple)):
        return [_normalize(item) for item in value]

    return value
