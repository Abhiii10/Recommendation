from functools import lru_cache

from fastapi import APIRouter

from backend.application.dto.requests import ChatRequestDto
from backend.application.dto.responses import ChatResponseDto

router = APIRouter()


@lru_cache(maxsize=1)
def _get_service():
    from backend.application.services.offline_chat_service import OfflineChatService

    return OfflineChatService()


@lru_cache(maxsize=1)
def _get_translator():
    from backend.application.services.translation_service import TranslationService

    return TranslationService()


@router.post("", response_model=ChatResponseDto)
async def offline_chat(payload: ChatRequestDto) -> ChatResponseDto:
    translator = _get_translator()

    if payload.language != "en" and translator.is_supported(payload.language, "en"):
        translated_question = translator.translate(
            payload.question,
            payload.language,
            "en",
        )
        payload = payload.model_copy(update={"question": translated_question})

    result = await _get_service().answer(payload)

    if payload.language != "en" and translator.is_supported("en", payload.language):
        translated_answer = translator.translate(
            result.answer,
            "en",
            payload.language,
        )
        result = result.model_copy(update={"answer": translated_answer})

    return result
