from fastapi import APIRouter

from backend.application.dto.requests import ChatRequestDto
from backend.application.dto.responses import ChatResponseDto
from backend.application.services.offline_chat_service import OfflineChatService
from backend.application.services.translation_service import TranslationService

router = APIRouter()
_service = OfflineChatService()
_translator = TranslationService()


@router.post("", response_model=ChatResponseDto)
async def offline_chat(payload: ChatRequestDto) -> ChatResponseDto:
    if payload.language != "en" and _translator.is_supported(payload.language, "en"):
        translated_question = _translator.translate(payload.question, payload.language, "en")
        payload = payload.model_copy(update={"question": translated_question})

    result = await _service.answer(payload)

    if payload.language != "en" and _translator.is_supported("en", payload.language):
        translated_answer = _translator.translate(result.answer, "en", payload.language)
        result = result.model_copy(update={"answer": translated_answer})

    return result
