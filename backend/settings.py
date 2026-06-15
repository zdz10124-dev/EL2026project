from __future__ import annotations

import os
from datetime import timedelta, timezone
from pathlib import Path

APP_DIR = Path(__file__).resolve().parent
DB_PATH = APP_DIR / "recommendations.db"
UPLOAD_DIR = APP_DIR / "uploads"
LOCAL_TIMEZONE = timezone(timedelta(hours=8))

RECOMMENDATION_THRESHOLD = 55.0
MIN_VOTE_COUNT_TO_HIDE = 5
MIN_DOWNVOTE_COUNT_TO_HIDE = 3
DOWNVOTE_RATIO_TO_HIDE = 0.6
REPORT_COUNT_TO_HIDE = 3

JWT_SECRET = os.environ.get("JWT_SECRET", "dev-secret-change-in-production")
JWT_ALGORITHM = "HS256"
JWT_EXPIRE_HOURS = 72

OPENAI_API_KEY = os.environ.get("OPENAI_API_KEY", "")
OPENAI_BASE_URL = os.environ.get("OPENAI_BASE_URL", "https://api.openai.com/v1")
