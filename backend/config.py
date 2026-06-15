"""Backward-compatible config exports for older scripts.

New backend code imports from settings.py. This file is kept so existing local
scripts that import config.APP_DIR / DB_PATH / UPLOAD_DIR keep working.
"""

from settings import APP_DIR, DB_PATH, LOCAL_TIMEZONE, UPLOAD_DIR

__all__ = ["APP_DIR", "DB_PATH", "UPLOAD_DIR", "LOCAL_TIMEZONE"]
