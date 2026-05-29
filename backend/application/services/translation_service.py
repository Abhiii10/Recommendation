from __future__ import annotations

import logging

from backend.core.config import settings


SUPPORTED_PAIRS = {
    ("en", "ne"): "Helsinki-NLP/opus-mt-en-ne",
    ("ne", "en"): "Helsinki-NLP/opus-mt-ne-en",
    ("en", "hi"): "Helsinki-NLP/opus-mt-en-hi",
    ("hi", "en"): "Helsinki-NLP/opus-mt-hi-en",
    ("en", "fr"): "Helsinki-NLP/opus-mt-en-fr",
    ("fr", "en"): "Helsinki-NLP/opus-mt-fr-en",
}

_MODEL_CACHE: dict[str, object] = {}

logger = logging.getLogger(__name__)


class TranslationService:
    def translate(self, text: str, src: str, tgt: str) -> str:
        if src == tgt:
            return text

        model_id = SUPPORTED_PAIRS.get((src, tgt))
        if not model_id:
            logger.warning("Unsupported translation pair: %s -> %s", src, tgt)
            return text

        try:
            translator = _MODEL_CACHE.get(model_id)
            if translator is None:
                from transformers import pipeline

                translator = pipeline(
                    "translation",
                    model=model_id,
                    device=-1,
                    cache_dir=settings.MODEL_DIR,
                )
                _MODEL_CACHE[model_id] = translator

            result = translator(text)
            return result[0]["translation_text"]
        except Exception:
            logger.exception("Translation failed for pair: %s -> %s", src, tgt)
            return text

    def is_supported(self, src: str, tgt: str) -> bool:
        return (src, tgt) in SUPPORTED_PAIRS
