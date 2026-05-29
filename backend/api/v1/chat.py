from functools import lru_cache

from fastapi import APIRouter

from backend.application.dto.requests import ChatRequestDto
from backend.application.dto.responses import ChatResponseDto

router = APIRouter()


@lru_cache(maxsize=1)
def _get_service():
    from backend.application.services.groq_chat_service import GroqChatService

    return GroqChatService()


@router.post("", response_model=ChatResponseDto)
async def chat(payload: ChatRequestDto) -> ChatResponseDto:
    return await _get_service().answer(payload)
