from __future__ import annotations

import hashlib
import time
from collections import defaultdict, deque

from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import JSONResponse


class AiRequestLimitMiddleware(BaseHTTPMiddleware):
    def __init__(self, app, requests_per_minute: int = 30, max_body_bytes: int = 34 * 1024 * 1024):
        super().__init__(app)
        self.requests_per_minute = requests_per_minute
        self.max_body_bytes = max_body_bytes
        self._requests: dict[str, deque[float]] = defaultdict(deque)

    async def dispatch(self, request: Request, call_next):
        if not request.url.path.startswith("/v1/ai/"):
            return await call_next(request)

        content_length = request.headers.get("content-length")
        if content_length:
            try:
                if int(content_length) > self.max_body_bytes:
                    return JSONResponse({"detail": "AI 请求内容过大"}, status_code=413)
            except ValueError:
                return JSONResponse({"detail": "无效的 Content-Length"}, status_code=400)

        identity = request.headers.get("authorization") or (
            request.client.host if request.client else "unknown"
        )
        identity_hash = hashlib.sha256(identity.encode("utf-8")).hexdigest()
        now = time.monotonic()
        bucket = self._requests[identity_hash]
        while bucket and now - bucket[0] >= 60:
            bucket.popleft()
        if len(bucket) >= self.requests_per_minute:
            return JSONResponse({"detail": "AI 请求过于频繁，请稍后再试"}, status_code=429)
        bucket.append(now)
        return await call_next(request)
