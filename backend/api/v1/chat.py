from fastapi import APIRouter

from backend.application.dto.requests import ChatRequestDto
from backend.application.dto.responses import ChatResponseDto
from backend.application.services.groq_chat_service import GroqChatService

router = APIRouter()
service = GroqChatService()


@router.post("", response_model=ChatResponseDto)
async def chat(payload: ChatRequestDto) -> ChatResponseDto:
    return await service.answer(payload)
