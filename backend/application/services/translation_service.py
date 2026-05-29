from __future__ import annotations

import logging
from urllib.parse import urlencode

import httpx

logger = logging.getLogger(__name__)


SUPPORTED_PAIRS = {
    ("en", "ne"): ("en-US", "ne-NP"),
    ("ne", "en"): ("ne-NP", "en-US"),
    ("hi", "en"): ("hi", "en"),
    ("en", "hi"): ("en", "hi"),
}


class TranslationService:
    async def translate(self, text: str, src: str, tgt: str) -> tuple[str, float]:
        if src == tgt:
            return text, 1.0

        langpair = SUPPORTED_PAIRS.get((src, tgt))
        if not langpair:
            logger.warning("Unsupported translation pair: %s -> %s", src, tgt)
            return text, 0.0

        query = urlencode(
            {
                "q": text,
                "langpair": f"{langpair[0]}|{langpair[1]}",
            },
        )
        url = f"https://api.mymemory.translated.net/get?{query}"

        try:
            async with httpx.AsyncClient(timeout=5.0) as client:
                response = await client.get(url)
                response.raise_for_status()
            payload = response.json()
            response_data = payload.get("responseData")
            if not isinstance(response_data, dict):
                return text, 0.0

            translated = str(response_data.get("translatedText") or "").strip()
            match_score = _to_float(response_data.get("match"))

            if not translated:
                return text, 0.0

            if match_score < 0.5:
                logger.warning(
                    "Low MyMemory translation match %.2f for pair %s -> %s",
                    match_score,
                    src,
                    tgt,
                )

            return translated, match_score
        except Exception as exc:
            logger.warning(
                "MyMemory translation failed for pair %s -> %s: %s",
                src,
                tgt,
                exc,
            )
            return text, 0.0

    def is_supported(self, src: str, tgt: str) -> bool:
        return (src, tgt) in SUPPORTED_PAIRS


def _to_float(value: object) -> float:
    if isinstance(value, (int, float)):
        return float(value)
    if isinstance(value, str):
        try:
            return float(value)
        except ValueError:
            return 0.0
    return 0.0
