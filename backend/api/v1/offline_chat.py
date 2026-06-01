from functools import lru_cache

from fastapi import APIRouter

from backend.application.dto.requests import ChatRequestDto
from backend.application.dto.responses import ChatResponseDto

router = APIRouter()


@lru_cache(maxsize=1)
def _get_service():
    from backend.application.services.offline_chat_service import OfflineChatService

    return OfflineChatService()


@router.post("", response_model=ChatResponseDto)
async def offline_chat(payload: ChatRequestDto) -> ChatResponseDto:
    return await _get_service().answer(payload)
