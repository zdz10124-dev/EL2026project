from __future__ import annotations

from typing import Any

from pydantic import BaseModel, Field


class SearchRequest(BaseModel):
    distance_buckets: list[str] = Field(default_factory=list)
    price_buckets: list[str] = Field(default_factory=list)
    page: int = 1
    page_size: int = 12
    latitude: float | None = None
    longitude: float | None = None


class UserRegister(BaseModel):
    username: str = Field(min_length=2, max_length=32)
    password: str = Field(min_length=4, max_length=128)


class UserLogin(BaseModel):
    username: str
    password: str


class VoteRequest(BaseModel):
    action: str = Field(pattern="^(upvote|downvote)$")


class ReportRequest(BaseModel):
    reason: str | None = Field(default=None, max_length=240)


class CommentRequest(BaseModel):
    content: str = Field(min_length=1, max_length=280)
    author_name: str | None = Field(default=None, max_length=32)
    author_avatar: str | None = Field(default=None, max_length=8)


class VisibilityRequest(BaseModel):
    active: bool


class AiChatMessage(BaseModel):
    role: str
    content: Any


class AiChatRequest(BaseModel):
    model: str = "gpt-4o"
    messages: list[AiChatMessage]
    temperature: float = 0.3
    response_format: dict[str, str] | None = None
