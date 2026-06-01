from __future__ import annotations

from fastapi import HTTPException

from backend.application.dto.requests import ChatRequestDto
from backend.application.dto.responses import ChatResponseDto
from backend.offline_chat import build_offline_chat_reply


class OfflineChatService:
    async def answer(self, request: ChatRequestDto) -> ChatResponseDto:
        question = request.question.strip()

        if not question:
            raise HTTPException(
                status_code=400,
                detail="Question cannot be empty.",
            )

        payload = build_offline_chat_reply(
            question,
            top_k=min(request.top_k, 3),
            reason="offline chat endpoint",
        )
        answer = str(payload["reply"])

        return ChatResponseDto(
            answer=answer,
            reply=answer,
            source="offline_rule_based",
            used_context=[
                str(name)
                for name in payload.get("used_context", [])
                if str(name).strip()
            ],
            offline=True,
            fallback="rule_based",
        )
