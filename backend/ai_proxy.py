from __future__ import annotations

import httpx
from fastapi import APIRouter, Depends, HTTPException

from auth import get_current_user
from schemas import AiChatRequest
from settings import OPENAI_API_KEY, OPENAI_BASE_URL

router = APIRouter(prefix="/v1/ai", tags=["ai"])


@router.post("/chat")
async def ai_chat(
    request: AiChatRequest,
    user: dict = Depends(get_current_user),
) -> dict:
    if not OPENAI_API_KEY:
        raise HTTPException(status_code=500, detail="服务端未配置 AI API Key")

    body = request.model_dump(mode="json")
    async with httpx.AsyncClient(timeout=120.0) as client:
        response = await client.post(
            f"{OPENAI_BASE_URL}/chat/completions",
            headers={
                "Authorization": f"Bearer {OPENAI_API_KEY}",
                "Content-Type": "application/json",
            },
            json=body,
        )

    if response.status_code != 200:
        raise HTTPException(
            status_code=502,
            detail=f"AI 服务错误 ({response.status_code}): {response.text}",
        )

    return response.json()
