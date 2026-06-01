from functools import lru_cache
import logging

from fastapi import APIRouter, HTTPException

from backend.application.dto.requests import ChatRequestDto
from backend.application.dto.responses import ChatResponseDto
from backend.application.services.chat_fallback import build_rule_based_chat_response
from backend.core.config import settings

router = APIRouter()
logger = logging.getLogger(__name__)


@lru_cache(maxsize=1)
def _get_service():
    if settings.groq_api_key or not settings.gemini_api_key:
        from backend.application.services.groq_chat_service import GroqChatService

        return GroqChatService()

    from backend.application.services.gemini_chat_service import GeminiChatService

    return GeminiChatService()


@router.post("", response_model=ChatResponseDto)
async def chat(payload: ChatRequestDto) -> ChatResponseDto:
    if settings.offline_mode:
        return build_rule_based_chat_response(
            payload.question,
            [],
            reason="OFFLINE_MODE=true",
        )

    if not settings.groq_api_key and not settings.gemini_api_key:
        return build_rule_based_chat_response(
            payload.question,
            [],
            reason="no AI provider configured",
        )

    try:
        return await _get_service().answer(payload)
    except HTTPException:
        raise
    except Exception as exc:
        logger.warning("Chat service failed; returning local fallback: %s", exc)
        return build_rule_based_chat_response(
            payload.question,
            [],
            reason=f"the chat service failed: {type(exc).__name__}",
        )
