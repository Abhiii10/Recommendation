from __future__ import annotations

import json

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field

from backend.core.config import settings


router = APIRouter()


class TranslateRequest(BaseModel):
    text: str = Field(..., min_length=1)
    direction: str = "autoDetect"
    context: str = "tourism"


class TranslateResponse(BaseModel):
    translated: str
    roman: str = ""
    confidence: float = 0.0
    source: str = "claude"


SYSTEM_PROMPT = """You are a Nepali language translator for a Nepal rural tourism app. Rules:
- Always translate TO standard Nepali (ne-NP), never Hindi
- Devanagari script input = Nepali, not Hindi
- Provide both Devanagari and Roman transliteration in response
- Keep tourism context in mind
- Return JSON: {nepali, roman, confidence, notes}"""


@router.post("/translate", response_model=TranslateResponse)
async def translate(payload: TranslateRequest) -> TranslateResponse:
    if settings.offline_mode:
        return TranslateResponse(
            translated=payload.text,
            roman="",
            confidence=0.0,
            source="offline",
        )

    if not settings.anthropic_api_key.strip():
        raise HTTPException(
            status_code=503,
            detail="Claude translation fallback is disabled.",
        )

    try:
        from anthropic import AsyncAnthropic
    except ImportError as exc:
        raise HTTPException(
            status_code=503,
            detail="Install the anthropic Python package to enable Claude fallback.",
        ) from exc

    client = AsyncAnthropic(api_key=settings.anthropic_api_key)
    user_prompt = (
        f"Direction: {payload.direction}\n"
        f"Context: {payload.context}\n"
        f"Text: {payload.text}\n\n"
        "If the direction asks Nepali to English, set nepali to the English "
        "translation and roman to an empty string. Otherwise set nepali to "
        "standard Nepali in Devanagari."
    )

    try:
        message = await client.messages.create(
            model=settings.anthropic_model,
            max_tokens=300,
            temperature=0.1,
            system=SYSTEM_PROMPT,
            messages=[{"role": "user", "content": user_prompt}],
        )
    except Exception as exc:
        raise HTTPException(
            status_code=502,
            detail="Claude translation failed.",
        ) from exc

    content = "".join(
        block.text for block in message.content if getattr(block, "text", None)
    ).strip()
    try:
        data = json.loads(content)
    except json.JSONDecodeError as exc:
        raise HTTPException(
            status_code=502,
            detail="Claude returned an invalid translation response.",
        ) from exc

    translated = str(data.get("nepali") or "").strip()
    if not translated:
        raise HTTPException(status_code=502, detail="Claude returned no text.")

    confidence = data.get("confidence", 0.7)
    if not isinstance(confidence, (int, float)):
        confidence = 0.7

    return TranslateResponse(
        translated=translated,
        roman=str(data.get("roman") or "").strip(),
        confidence=max(0.0, min(float(confidence), 0.95)),
        source="claude",
    )
