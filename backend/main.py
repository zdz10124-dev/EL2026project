"""
Today Eat backend entrypoint.

Public endpoints are registered in app_factory.create_app and remain unchanged:
- GET /
- GET /health
- POST /v1/recommendations/upload-record
- POST /v1/recommendations/search
- GET /v1/recommendations/{record_id}
- POST /v1/recommendations/{record_id}/comments
- POST /v1/recommendations/{record_id}/visibility
- POST /v1/recommendations/{record_id}/vote
- POST /v1/recommendations/{record_id}/report
- POST /v1/auth/register
- POST /v1/auth/login
- GET /v1/auth/me
- POST /v1/ai/chat
"""

from __future__ import annotations

import sys
from pathlib import Path

BACKEND_DIR = Path(__file__).resolve().parent
if str(BACKEND_DIR) not in sys.path:
    sys.path.insert(0, str(BACKEND_DIR))

from app_factory import create_app

app = create_app()

__all__ = ["app", "create_app"]
