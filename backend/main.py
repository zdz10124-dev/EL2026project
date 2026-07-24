"""
对外接口：
- GET /
- GET /health
- POST /v1/recommendations/upload-record
- POST /v1/recommendations/search
- GET /v1/recommendations/{record_id}
"""

from __future__ import annotations

import base64
import math
import mimetypes
import os
import random
import sqlite3
import uuid
from contextlib import contextmanager
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any, Iterator, Literal

import json as json_lib

import bcrypt
import httpx
import jwt
from fastapi import (Depends, FastAPI, File, Form, HTTPException, Request,
                     UploadFile, status)
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel, Field

try:
    from .middleware.request_limits import AiRequestLimitMiddleware
except ImportError:
    from middleware.request_limits import AiRequestLimitMiddleware


APP_DIR = Path(__file__).resolve().parent
DB_PATH = APP_DIR / "recommendations.db"
UPLOAD_DIR = APP_DIR / "uploads"
LOCAL_TIMEZONE = timezone(timedelta(hours=8))
RECOMMENDATION_THRESHOLD = 55.0
MIN_VOTE_COUNT_TO_HIDE = 5
MIN_DOWNVOTE_COUNT_TO_HIDE = 3
DOWNVOTE_RATIO_TO_HIDE = 0.6
REPORT_COUNT_TO_HIDE = 3

# ---- Auth & AI Proxy 配置 ----
JWT_SECRET = os.environ.get("JWT_SECRET", "dev-secret-change-in-production")
JWT_ALGORITHM = "HS256"
JWT_EXPIRE_HOURS = 72
OPENAI_API_KEY = os.environ.get("OPENAI_API_KEY", "")
OPENAI_BASE_URL = os.environ.get("OPENAI_BASE_URL", "https://api.openai.com/v1")
OPENAI_MODEL = os.environ.get("OPENAI_MODEL", "gpt-4o")

security = HTTPBearer(auto_error=False)


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


class HealthAnalysisRequest(BaseModel):
    period: str = Field(pattern="^(7d|30d)$")
    profile: dict[str, Any] = Field(default_factory=dict)
    metrics: dict[str, Any]
    allowed_evidence: list[str] = Field(default_factory=list, max_length=20)


class DailyAgentPlanRequest(BaseModel):
    context: dict[str, Any]
    allowed_evidence: list[str] = Field(min_length=1, max_length=30)


class DailyAgentAction(BaseModel):
    category: Literal["diet", "exercise", "rest"]
    priority: Literal["low", "medium", "high"]
    title: str = Field(min_length=1, max_length=40)
    action: str = Field(min_length=1, max_length=160)
    evidence: list[str] = Field(min_length=1, max_length=5)
    target: Literal[
        "recordMeal",
        "recordExercise",
        "decideMeal",
        "recoveryCheckIn",
        "openHealth",
        "none",
    ]


class DailyAgentPlanResult(BaseModel):
    summary: str = Field(min_length=1, max_length=240)
    actions: list[DailyAgentAction] = Field(min_length=1, max_length=3)


app = FastAPI(title="今天吃什么 联网推荐服务", version="1.0.0")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
app.add_middleware(AiRequestLimitMiddleware)
app.mount("/media", StaticFiles(directory=str(UPLOAD_DIR)), name="media")


@contextmanager
def get_connection() -> Iterator[sqlite3.Connection]:
    connection = sqlite3.connect(DB_PATH)
    connection.row_factory = sqlite3.Row
    try:
      yield connection
      connection.commit()
    finally:
      connection.close()


def initialize_database() -> None:
    UPLOAD_DIR.mkdir(parents=True, exist_ok=True)
    with get_connection() as connection:
        connection.execute(
            """
            CREATE TABLE IF NOT EXISTS users(
                id TEXT PRIMARY KEY,
                username TEXT NOT NULL UNIQUE,
                password_hash TEXT NOT NULL,
                created_at TEXT NOT NULL
            )
            """
        )
        connection.execute(
            """
            CREATE TABLE IF NOT EXISTS uploaded_records(
                id TEXT PRIMARY KEY,
                client_record_id TEXT NOT NULL UNIQUE,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL,
                dish_name TEXT NOT NULL,
                dish_name_normalized TEXT NOT NULL,
                location_text TEXT,
                province TEXT,
                city TEXT,
                district TEXT,
                latitude REAL,
                longitude REAL,
                price REAL,
                rating_score REAL,
                comment TEXT,
                owner_client_id TEXT,
                uploader_name TEXT,
                uploader_avatar TEXT,
                is_active INTEGER NOT NULL DEFAULT 1,
                image_path TEXT,
                image_filename TEXT,
                uploaded_at TEXT NOT NULL,
                updated_remote_at TEXT NOT NULL
            )
            """
        )
        connection.execute(
            """
            CREATE INDEX IF NOT EXISTS idx_uploaded_records_dish
            ON uploaded_records(dish_name_normalized)
            """
        )
        connection.execute(
            """
            CREATE TABLE IF NOT EXISTS recommendation_votes(
                subject_key TEXT NOT NULL,
                fingerprint TEXT NOT NULL,
                action TEXT NOT NULL,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL,
                PRIMARY KEY(subject_key, fingerprint)
            )
            """
        )
        connection.execute(
            """
            CREATE TABLE IF NOT EXISTS recommendation_reports(
                subject_key TEXT NOT NULL,
                fingerprint TEXT NOT NULL,
                reason TEXT,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL,
                PRIMARY KEY(subject_key, fingerprint)
            )
            """
        )
        connection.execute(
            """
            CREATE TABLE IF NOT EXISTS hidden_recommendations(
                subject_key TEXT PRIMARY KEY,
                hidden_reason TEXT NOT NULL,
                stats_json TEXT,
                created_at TEXT NOT NULL
            )
            """
        )
        connection.execute(
            """
            CREATE TABLE IF NOT EXISTS recommendation_comments(
                id TEXT PRIMARY KEY,
                recommendation_id TEXT NOT NULL,
                author_client_id TEXT NOT NULL,
                author_name TEXT NOT NULL,
                author_avatar TEXT NOT NULL,
                content TEXT NOT NULL,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL
            )
            """
        )
        connection.execute(
            """
            CREATE INDEX IF NOT EXISTS idx_recommendation_comments_record
            ON recommendation_comments(recommendation_id, created_at DESC)
            """
        )

        existing_columns = {
            row["name"]
            for row in connection.execute("PRAGMA table_info(uploaded_records)").fetchall()
        }
        if "owner_client_id" not in existing_columns:
            connection.execute(
                "ALTER TABLE uploaded_records ADD COLUMN owner_client_id TEXT"
            )
        if "uploader_name" not in existing_columns:
            connection.execute(
                "ALTER TABLE uploaded_records ADD COLUMN uploader_name TEXT"
            )
        if "uploader_avatar" not in existing_columns:
            connection.execute(
                "ALTER TABLE uploaded_records ADD COLUMN uploader_avatar TEXT"
            )
        if "is_active" not in existing_columns:
            connection.execute(
                "ALTER TABLE uploaded_records ADD COLUMN is_active INTEGER NOT NULL DEFAULT 1"
            )
            connection.execute("UPDATE uploaded_records SET is_active = 1")


def now_iso() -> str:
    return datetime.now(LOCAL_TIMEZONE).isoformat()


def normalize_dish_name(value: str) -> str:
    normalized = (
        value.strip()
        .lower()
        .replace("（", "(")
        .replace("）", ")")
        .replace("，", ",")
        .replace("　", " ")
    )
    normalized = "".join(char for char in normalized if char not in " ,，.。!！?？-_/\\()（）[]【】")
    synonyms = {
        "西红柿": "番茄",
        "蕃茄": "番茄",
        "马铃薯": "土豆",
        "洋芋": "土豆",
        "薯仔": "土豆",
        "鸡蛋": "蛋",
        "米饭": "饭",
        "白米饭": "饭",
        "炒饭饭": "炒饭",
    }
    for source, target in synonyms.items():
        normalized = normalized.replace(source, target)
    suffixes = ("套餐", "盖饭", "便当", "小份", "大份", "中份", "特辣", "微辣", "中辣")
    for suffix in suffixes:
        if normalized.endswith(suffix) and len(normalized) > len(suffix) + 1:
            normalized = normalized[: -len(suffix)]
    return normalized or value.strip().lower()


def parse_optional_float(value: str | None) -> float | None:
    if value is None:
        return None
    trimmed = value.strip()
    if not trimmed:
        return None
    try:
        return float(trimmed)
    except ValueError as error:
        raise HTTPException(status_code=400, detail=f"数值字段格式错误：{value}") from error


def parse_optional_text(value: str | None) -> str | None:
    if value is None:
        return None
    trimmed = value.strip()
    return trimmed or None


def haversine_meters(
    latitude_a: float,
    longitude_a: float,
    latitude_b: float,
    longitude_b: float,
) -> float:
    radius = 6371000.0
    lat_a = math.radians(latitude_a)
    lat_b = math.radians(latitude_b)
    delta_lat = math.radians(latitude_b - latitude_a)
    delta_lon = math.radians(longitude_b - longitude_a)
    value = (
        math.sin(delta_lat / 2) ** 2
        + math.cos(lat_a) * math.cos(lat_b) * math.sin(delta_lon / 2) ** 2
    )
    return 2 * radius * math.atan2(math.sqrt(value), math.sqrt(1 - value))


def matches_distance_bucket(distance_meters: float | None, bucket: str) -> bool:
    if distance_meters is None:
        return False
    if bucket == "within_500m":
        return distance_meters <= 500
    if bucket == "within_2km":
        return distance_meters <= 2000
    if bucket == "within_5km":
        return distance_meters <= 5000
    if bucket == "beyond_5km":
        return distance_meters > 5000
    return False


def matches_price_bucket(price: float | None, bucket: str) -> bool:
    if price is None:
        return False
    if bucket == "under_20":
        return price < 20
    if bucket == "between_20_40":
        return 20 <= price < 40
    if bucket == "between_40_60":
        return 40 <= price < 60
    if bucket == "above_60":
        return price >= 60
    return False


def compute_distance(
    row: sqlite3.Row,
    latitude: float | None,
    longitude: float | None,
) -> float | None:
    row_latitude = row["latitude"]
    row_longitude = row["longitude"]
    if (
        latitude is None
        or longitude is None
        or row_latitude is None
        or row_longitude is None
    ):
        return None
    return haversine_meters(latitude, longitude, row_latitude, row_longitude)


def location_display_text(row: sqlite3.Row) -> str:
    if row["location_text"]:
        return row["location_text"]
    for key in ("district", "city", "province"):
        value = row[key]
        if value:
            return value
    return "未填写"


def build_aggregate(records: list[sqlite3.Row]) -> dict[str, Any]:
    prices = [item["price"] for item in records if item["price"] is not None]
    ratings = [item["rating_score"] for item in records if item["rating_score"] is not None]
    latest_record = max(records, key=lambda item: item["created_at"])
    return {
        "upload_count": len(records),
        "average_rating": round(sum(ratings) / len(ratings), 2) if ratings else None,
        "average_price": round(sum(prices) / len(prices), 2) if prices else None,
        "latest_recorded_at": latest_record["created_at"],
    }


def parse_datetime_aware(value: str) -> datetime:
    parsed = datetime.fromisoformat(value)
    if parsed.tzinfo is None:
        return parsed.replace(tzinfo=LOCAL_TIMEZONE)
    return parsed.astimezone(LOCAL_TIMEZONE)


def score_candidate(
    records: list[sqlite3.Row],
    latitude: float | None,
    longitude: float | None,
) -> tuple[float, float | None]:
    aggregate = build_aggregate(records)
    average_rating = aggregate["average_rating"] or 0.0
    rating_score = average_rating * 10

    nearest_distance = None
    if latitude is not None and longitude is not None:
      distances = [
          compute_distance(record, latitude, longitude)
          for record in records
      ]
      actual_distances = [item for item in distances if item is not None]
      if actual_distances:
          nearest_distance = min(actual_distances)

    if nearest_distance is None:
        distance_score = 50.0
    elif nearest_distance <= 500:
        distance_score = 100.0
    elif nearest_distance <= 2000:
        distance_score = 80.0
    elif nearest_distance <= 5000:
        distance_score = 60.0
    else:
        distance_score = 35.0

    heat_score = min(len(records), 10) / 10 * 100
    latest_recorded_at = parse_datetime_aware(aggregate["latest_recorded_at"])
    days_since_latest = max(
        0.0,
        (datetime.now(LOCAL_TIMEZONE) - latest_recorded_at).total_seconds() / 86400,
    )
    freshness_score = max(0.0, 100 - days_since_latest * 3)

    total_score = (
        rating_score * 0.55
        + distance_score * 0.25
        + heat_score * 0.15
        + freshness_score * 0.05
    )
    return total_score, nearest_distance


def choose_weighted_record(
    records: list[sqlite3.Row],
    latitude: float | None,
    longitude: float | None,
    randomizer: random.Random,
) -> tuple[sqlite3.Row, float | None]:
    weighted_options: list[tuple[sqlite3.Row, float, float | None]] = []
    for record in records:
        distance = compute_distance(record, latitude, longitude)
        if distance is None:
            weighted_options.append((record, 1.0, None))
        else:
            weighted_options.append((record, 1.0 / max(distance, 50.0), distance))

    total_weight = sum(weight for _, weight, _ in weighted_options)
    cursor = randomizer.uniform(0, total_weight)
    for record, weight, distance in weighted_options:
        cursor -= weight
        if cursor <= 0:
            return record, distance
    record, _, distance = weighted_options[-1]
    return record, distance


def stable_randomizer(payload: SearchRequest) -> random.Random:
    seed = "|".join(
        [
            ",".join(sorted(payload.distance_buckets)),
            ",".join(sorted(payload.price_buckets)),
            str(payload.latitude or ""),
            str(payload.longitude or ""),
            datetime.now(LOCAL_TIMEZONE).strftime("%Y-%m-%d"),
        ]
    )
    return random.Random(seed)


def build_recommendation_item(
    record: sqlite3.Row,
    aggregate: dict[str, Any],
    distance_meters: float | None,
    reason: str,
    feedback: dict[str, Any],
) -> dict[str, Any]:
    return {
        "id": record["id"],
        "dish_name": record["dish_name"],
        "location": location_display_text(record),
        "price": record["price"],
        "rating": record["rating_score"],
        "distance_meters": round(distance_meters, 1) if distance_meters is not None else None,
        "reason": reason,
        "description": record["comment"],
        "uploader_name": record["uploader_name"],
        "uploader_avatar": record["uploader_avatar"],
        "aggregate": aggregate,
        "feedback": feedback,
    }


def recommendation_reason(
    aggregate: dict[str, Any],
    distance_meters: float | None,
) -> str:
    parts = []
    average_rating = aggregate["average_rating"]
    if average_rating is not None:
        parts.append(f"同菜品平均评分 {average_rating:.1f}")
    parts.append(f"公开记录 {aggregate['upload_count']} 条")
    if distance_meters is not None:
        if distance_meters < 1000:
            parts.append(f"距离你约 {distance_meters:.0f}m")
        else:
            parts.append(f"距离你约 {distance_meters / 1000:.1f}km")
    return "，".join(parts)


def fetch_all_records() -> list[sqlite3.Row]:
    with get_connection() as connection:
        rows = connection.execute(
            "SELECT * FROM uploaded_records WHERE is_active = 1 ORDER BY created_at DESC"
        ).fetchall()
    return rows


def recommendation_fingerprint(request: Request) -> str:
    header_value = (
        request.headers.get("x-client-id")
        or request.headers.get("x-device-id")
        or request.headers.get("x-user-id")
    )
    if header_value:
        return header_value.strip()
    if request.client and request.client.host:
        return f"ip:{request.client.host}"
    return "anonymous"


def fetch_feedback_summary(
    connection: sqlite3.Connection,
    subject_key: str,
    fingerprint: str | None = None,
) -> dict[str, Any]:
    vote_rows = connection.execute(
        "SELECT action, COUNT(*) AS count FROM recommendation_votes WHERE subject_key = ? GROUP BY action",
        (subject_key,),
    ).fetchall()
    report_count = connection.execute(
        "SELECT COUNT(*) AS count FROM recommendation_reports WHERE subject_key = ?",
        (subject_key,),
    ).fetchone()["count"]
    hidden_row = connection.execute(
        "SELECT hidden_reason, created_at FROM hidden_recommendations WHERE subject_key = ?",
        (subject_key,),
    ).fetchone()

    counts = {row["action"]: row["count"] for row in vote_rows}
    upvote_count = counts.get("upvote", 0)
    downvote_count = counts.get("downvote", 0)
    vote_total = upvote_count + downvote_count
    downvote_ratio = downvote_count / vote_total if vote_total else 0.0
    current_vote = None
    current_reported = False

    if fingerprint:
        current_vote_row = connection.execute(
            "SELECT action FROM recommendation_votes WHERE subject_key = ? AND fingerprint = ?",
            (subject_key, fingerprint),
        ).fetchone()
        current_vote = current_vote_row["action"] if current_vote_row else None
        current_reported = (
            connection.execute(
                "SELECT 1 FROM recommendation_reports WHERE subject_key = ? AND fingerprint = ?",
                (subject_key, fingerprint),
            ).fetchone()
            is not None
        )

    return {
        "upvote_count": upvote_count,
        "downvote_count": downvote_count,
        "report_count": report_count,
        "vote_total": vote_total,
        "downvote_ratio": round(downvote_ratio, 4),
        "current_vote": current_vote,
        "current_reported": current_reported,
        "is_hidden": hidden_row is not None,
        "hidden_reason": hidden_row["hidden_reason"] if hidden_row else None,
    }


def evaluate_and_apply_moderation(
    connection: sqlite3.Connection,
    subject_key: str,
    fingerprint: str | None = None,
) -> dict[str, Any]:
    summary = fetch_feedback_summary(connection, subject_key, fingerprint)
    should_hide = False
    hidden_reason = None

    if (
        summary["downvote_count"] >= MIN_DOWNVOTE_COUNT_TO_HIDE
        and summary["vote_total"] >= MIN_VOTE_COUNT_TO_HIDE
        and summary["downvote_ratio"] >= DOWNVOTE_RATIO_TO_HIDE
    ):
        should_hide = True
        hidden_reason = "downvote_threshold"

    if summary["report_count"] >= REPORT_COUNT_TO_HIDE:
        should_hide = True
        hidden_reason = "report_threshold"

    if should_hide and not summary["is_hidden"]:
        connection.execute(
            """
            INSERT INTO hidden_recommendations(subject_key, hidden_reason, stats_json, created_at)
            VALUES(?, ?, ?, ?)
            ON CONFLICT(subject_key) DO UPDATE SET
                hidden_reason = excluded.hidden_reason,
                stats_json = excluded.stats_json,
                created_at = excluded.created_at
            """,
            (
                subject_key,
                hidden_reason,
                json_lib.dumps(summary, ensure_ascii=False),
                now_iso(),
            ),
        )
        summary = fetch_feedback_summary(connection, subject_key, fingerprint)

    return summary


@app.on_event("startup")
def on_startup() -> None:
    initialize_database()


@app.get("/")
def root() -> dict[str, Any]:
    return {
        "success": True,
        "message": "today-eat-api",
        "data": {"service": "recommendations", "status": "ok"},
    }


@app.get("/health")
def health() -> dict[str, Any]:
    return {"success": True, "message": "ok", "data": {"status": "healthy"}}


@app.post("/v1/recommendations/upload-record")
async def upload_record(
    request: Request,
    client_record_id: str = Form(...),
    created_at: str = Form(...),
    updated_at: str = Form(...),
    dish_name: str = Form(...),
    location_text: str = Form(""),
    price: str = Form(""),
    rating_score: str = Form(""),
    comment: str = Form(""),
    province: str = Form(""),
    city: str = Form(""),
    district: str = Form(""),
    latitude: str = Form(""),
    longitude: str = Form(""),
    uploader_name: str = Form(""),
    uploader_avatar: str = Form(""),
    image: UploadFile | None = File(default=None),
) -> dict[str, Any]:
    client_record_id = client_record_id.strip()
    dish_name = dish_name.strip()
    if not client_record_id or not dish_name:
        raise HTTPException(status_code=400, detail="client_record_id 和 dish_name 不能为空")

    normalized_dish_name = normalize_dish_name(dish_name)
    now = now_iso()
    remote_id = ""
    image_filename = None
    image_path = None
    owner_client_id = recommendation_fingerprint(request)
    normalized_name = parse_optional_text(uploader_name) or "饭搭子"
    normalized_avatar = parse_optional_text(uploader_avatar) or "🍜"

    with get_connection() as connection:
        existing = connection.execute(
            "SELECT id, image_filename FROM uploaded_records WHERE client_record_id = ?",
            (client_record_id,),
        ).fetchone()
        if existing:
            remote_id = existing["id"]
            image_filename = existing["image_filename"]
        else:
            remote_id = f"pub_{uuid.uuid4().hex}"

        if image is not None and image.filename:
            suffix = Path(image.filename).suffix or ".jpg"
            image_filename = f"{remote_id}{suffix}"
            image_bytes = await image.read()
            target_path = UPLOAD_DIR / image_filename
            target_path.write_bytes(image_bytes)
            image_path = f"/media/{image_filename}"
        elif existing:
            image_path = f"/media/{image_filename}" if image_filename else None

        payload = {
            "id": remote_id,
            "client_record_id": client_record_id,
            "created_at": created_at,
            "updated_at": updated_at,
            "dish_name": dish_name,
            "dish_name_normalized": normalized_dish_name,
            "location_text": parse_optional_text(location_text),
            "province": parse_optional_text(province),
            "city": parse_optional_text(city),
            "district": parse_optional_text(district),
            "latitude": parse_optional_float(latitude),
            "longitude": parse_optional_float(longitude),
            "price": parse_optional_float(price),
            "rating_score": parse_optional_float(rating_score),
            "comment": parse_optional_text(comment),
            "owner_client_id": owner_client_id,
            "uploader_name": normalized_name,
            "uploader_avatar": normalized_avatar,
            "is_active": 1,
            "image_path": image_path,
            "image_filename": image_filename,
            "uploaded_at": now,
            "updated_remote_at": now,
        }

        connection.execute(
            """
            INSERT INTO uploaded_records(
                id, client_record_id, created_at, updated_at, dish_name, dish_name_normalized,
                location_text, province, city, district, latitude, longitude,
                price, rating_score, comment, owner_client_id, uploader_name, uploader_avatar,
                is_active, image_path, image_filename,
                uploaded_at, updated_remote_at
            ) VALUES(
                :id, :client_record_id, :created_at, :updated_at, :dish_name, :dish_name_normalized,
                :location_text, :province, :city, :district, :latitude, :longitude,
                :price, :rating_score, :comment, :owner_client_id, :uploader_name, :uploader_avatar,
                :is_active, :image_path, :image_filename,
                :uploaded_at, :updated_remote_at
            )
            ON CONFLICT(client_record_id) DO UPDATE SET
                created_at = excluded.created_at,
                updated_at = excluded.updated_at,
                dish_name = excluded.dish_name,
                dish_name_normalized = excluded.dish_name_normalized,
                location_text = excluded.location_text,
                province = excluded.province,
                city = excluded.city,
                district = excluded.district,
                latitude = excluded.latitude,
                longitude = excluded.longitude,
                price = excluded.price,
                rating_score = excluded.rating_score,
                comment = excluded.comment,
                owner_client_id = excluded.owner_client_id,
                uploader_name = excluded.uploader_name,
                uploader_avatar = excluded.uploader_avatar,
                is_active = excluded.is_active,
                image_path = COALESCE(excluded.image_path, uploaded_records.image_path),
                image_filename = COALESCE(excluded.image_filename, uploaded_records.image_filename),
                updated_remote_at = excluded.updated_remote_at
            """,
            payload,
        )

    return {
        "success": True,
        "message": "uploaded",
        "data": {"remote_id": remote_id, "updated_at": now},
    }


@app.post("/v1/recommendations/search")
def search_recommendations(payload: SearchRequest, request: Request) -> dict[str, Any]:
    rows = fetch_all_records()
    filtered_rows = []
    for row in rows:
        distance_meters = compute_distance(row, payload.latitude, payload.longitude)
        if payload.distance_buckets:
            if not any(
                matches_distance_bucket(distance_meters, bucket)
                for bucket in payload.distance_buckets
            ):
                continue
        if payload.price_buckets:
            if not any(
                matches_price_bucket(row["price"], bucket)
                for bucket in payload.price_buckets
            ):
                continue
        filtered_rows.append(row)

    grouped: dict[str, list[sqlite3.Row]] = {}
    for row in filtered_rows:
        grouped.setdefault(row["dish_name_normalized"], []).append(row)

    randomizer = stable_randomizer(payload)
    fingerprint = recommendation_fingerprint(request)
    candidates: list[dict[str, Any]] = []
    with get_connection() as connection:
        for records in grouped.values():
            subject_key = records[0]["dish_name_normalized"]
            feedback = evaluate_and_apply_moderation(connection, subject_key, fingerprint)
            if feedback["is_hidden"]:
                continue
            total_score, nearest_distance = score_candidate(
                records,
                payload.latitude,
                payload.longitude,
            )
            if total_score < RECOMMENDATION_THRESHOLD:
                continue
            aggregate = build_aggregate(records)
            representative_record, representative_distance = choose_weighted_record(
                records,
                payload.latitude,
                payload.longitude,
                randomizer,
            )
            candidates.append(
                {
                    "score": total_score,
                    "representative": representative_record,
                    "aggregate": aggregate,
                    "distance_meters": representative_distance or nearest_distance,
                    "feedback": feedback,
                }
            )

    ordered_items: list[dict[str, Any]] = []
    remaining = candidates[:]
    while remaining:
        total_weight = sum(item["score"] for item in remaining)
        cursor = randomizer.uniform(0, total_weight)
        selected_index = 0
        for index, item in enumerate(remaining):
            cursor -= item["score"]
            if cursor <= 0:
                selected_index = index
                break
        selected = remaining.pop(selected_index)
        ordered_items.append(
            build_recommendation_item(
                selected["representative"],
                selected["aggregate"],
                selected["distance_meters"],
                recommendation_reason(
                    selected["aggregate"],
                    selected["distance_meters"],
                ),
                selected["feedback"],
            )
        )

    start = max(payload.page - 1, 0) * payload.page_size
    end = start + payload.page_size
    page_items = ordered_items[start:end]
    return {
        "success": True,
        "message": "ok",
        "data": {
            "total": len(ordered_items),
            "page": payload.page,
            "page_size": payload.page_size,
            "items": page_items,
        },
    }


@app.get("/v1/recommendations/{record_id}")
def recommendation_detail(record_id: str, request: Request) -> dict[str, Any]:
    with get_connection() as connection:
        record = connection.execute(
            "SELECT * FROM uploaded_records WHERE id = ?",
            (record_id,),
        ).fetchone()
        if record is None:
            raise HTTPException(status_code=404, detail="推荐记录不存在")
        related_rows = connection.execute(
            "SELECT * FROM uploaded_records WHERE dish_name_normalized = ? AND is_active = 1 ORDER BY created_at DESC",
            (record["dish_name_normalized"],),
        ).fetchall()
        feedback = evaluate_and_apply_moderation(
            connection,
            record["dish_name_normalized"],
            recommendation_fingerprint(request),
        )
        if feedback["is_hidden"] or int(record["is_active"] or 0) == 0:
            raise HTTPException(status_code=410, detail="该推荐已被下架")

        comment_rows = connection.execute(
            """
            SELECT * FROM recommendation_comments
            WHERE recommendation_id = ?
            ORDER BY created_at DESC
            """,
            (record_id,),
        ).fetchall()

    aggregate = build_aggregate(list(related_rows))
    base_url = str(request.base_url).rstrip("/")
    image_url = f"{base_url}{record['image_path']}" if record["image_path"] else None
    distance_meters = None
    fingerprint = recommendation_fingerprint(request)
    data = {
        "id": record["id"],
        "dish_name": record["dish_name"],
        "location": location_display_text(record),
        "price": record["price"],
        "rating": record["rating_score"],
        "created_at": record["created_at"],
        "description": record["comment"],
        "image_url": image_url,
        "distance_meters": distance_meters,
        "reason": recommendation_reason(aggregate, distance_meters),
        "uploader_name": record["uploader_name"],
        "uploader_avatar": record["uploader_avatar"],
        "comments": [
            {
                "id": row["id"],
                "recommendation_id": row["recommendation_id"],
                "author_name": row["author_name"],
                "author_avatar": row["author_avatar"],
                "content": row["content"],
                "created_at": row["created_at"],
                "is_mine": row["author_client_id"] == fingerprint,
            }
            for row in comment_rows
        ],
        "aggregate": aggregate,
        "feedback": feedback,
    }
    return {"success": True, "message": "ok", "data": data}


@app.post("/v1/recommendations/{record_id}/comments")
def create_recommendation_comment(
    record_id: str,
    payload: CommentRequest,
    request: Request,
) -> dict[str, Any]:
    content = payload.content.strip()
    if not content:
        raise HTTPException(status_code=400, detail="评论内容不能为空")

    fingerprint = recommendation_fingerprint(request)
    author_name = parse_optional_text(payload.author_name) or "饭搭子"
    author_avatar = parse_optional_text(payload.author_avatar) or "🍜"
    now = now_iso()
    comment_id = f"comment_{uuid.uuid4().hex}"

    with get_connection() as connection:
        record = connection.execute(
            "SELECT id, is_active FROM uploaded_records WHERE id = ?",
            (record_id,),
        ).fetchone()
        if record is None:
            raise HTTPException(status_code=404, detail="推荐记录不存在")
        if int(record["is_active"] or 0) == 0:
            raise HTTPException(status_code=410, detail="该推荐已下架，无法评论")
        connection.execute(
            """
            INSERT INTO recommendation_comments(
                id, recommendation_id, author_client_id, author_name,
                author_avatar, content, created_at, updated_at
            ) VALUES(?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                comment_id,
                record_id,
                fingerprint,
                author_name,
                author_avatar,
                content,
                now,
                now,
            ),
        )

    return {
        "success": True,
        "message": "ok",
        "data": {
            "id": comment_id,
            "recommendation_id": record_id,
            "author_name": author_name,
            "author_avatar": author_avatar,
            "content": content,
            "created_at": now,
            "is_mine": True,
        },
    }


@app.post("/v1/recommendations/{record_id}/visibility")
def set_recommendation_visibility(
    record_id: str,
    payload: VisibilityRequest,
    request: Request,
) -> dict[str, Any]:
    fingerprint = recommendation_fingerprint(request)
    with get_connection() as connection:
        record = connection.execute(
            "SELECT id, owner_client_id FROM uploaded_records WHERE id = ?",
            (record_id,),
        ).fetchone()
        if record is None:
            raise HTTPException(status_code=404, detail="推荐记录不存在")
        if (record["owner_client_id"] or "") != fingerprint:
            raise HTTPException(status_code=403, detail="只能修改自己上传的记录")
        connection.execute(
            "UPDATE uploaded_records SET is_active = ?, updated_remote_at = ? WHERE id = ?",
            (1 if payload.active else 0, now_iso(), record_id),
        )

    return {
        "success": True,
        "message": "ok",
        "data": {"record_id": record_id, "active": payload.active},
    }


@app.post("/v1/recommendations/{record_id}/vote")
def vote_recommendation(record_id: str, payload: VoteRequest, request: Request) -> dict[str, Any]:
    with get_connection() as connection:
        record = connection.execute(
            "SELECT dish_name_normalized FROM uploaded_records WHERE id = ?",
            (record_id,),
        ).fetchone()
        if record is None:
            raise HTTPException(status_code=404, detail="推荐记录不存在")

        subject_key = record["dish_name_normalized"]
        fingerprint = recommendation_fingerprint(request)
        now = now_iso()
        connection.execute(
            """
            INSERT INTO recommendation_votes(subject_key, fingerprint, action, created_at, updated_at)
            VALUES(?, ?, ?, ?, ?)
            ON CONFLICT(subject_key, fingerprint) DO UPDATE SET
                action = excluded.action,
                updated_at = excluded.updated_at
            """,
            (subject_key, fingerprint, payload.action, now, now),
        )
        feedback = evaluate_and_apply_moderation(connection, subject_key, fingerprint)

    return {
        "success": True,
        "message": "ok",
        "data": {"feedback": feedback},
    }


@app.post("/v1/recommendations/{record_id}/report")
def report_recommendation(record_id: str, payload: ReportRequest, request: Request) -> dict[str, Any]:
    with get_connection() as connection:
        record = connection.execute(
            "SELECT dish_name_normalized FROM uploaded_records WHERE id = ?",
            (record_id,),
        ).fetchone()
        if record is None:
            raise HTTPException(status_code=404, detail="推荐记录不存在")

        subject_key = record["dish_name_normalized"]
        fingerprint = recommendation_fingerprint(request)
        now = now_iso()
        existing = connection.execute(
            "SELECT 1 FROM recommendation_reports WHERE subject_key = ? AND fingerprint = ?",
            (subject_key, fingerprint),
        ).fetchone()
        if existing:
            connection.execute(
                "DELETE FROM recommendation_reports WHERE subject_key = ? AND fingerprint = ?",
                (subject_key, fingerprint),
            )
        else:
            connection.execute(
                """
                INSERT INTO recommendation_reports(subject_key, fingerprint, reason, created_at, updated_at)
                VALUES(?, ?, ?, ?, ?)
                ON CONFLICT(subject_key, fingerprint) DO UPDATE SET
                    reason = excluded.reason,
                    updated_at = excluded.updated_at
                """,
                (subject_key, fingerprint, parse_optional_text(payload.reason), now, now),
            )
        feedback = evaluate_and_apply_moderation(connection, subject_key, fingerprint)

    return {
        "success": True,
        "message": "ok",
        "data": {"feedback": feedback},
    }


# ===== 用户认证 =====


def _hash_password(password: str) -> str:
    return bcrypt.hashpw(password.encode(), bcrypt.gensalt()).decode()


def _check_password(password: str, password_hash: str) -> bool:
    return bcrypt.checkpw(password.encode(), password_hash.encode())


def _create_token(user_id: str, username: str) -> str:
    payload = {
        "user_id": user_id,
        "username": username,
        "exp": datetime.now(LOCAL_TIMEZONE) + timedelta(hours=JWT_EXPIRE_HOURS),
    }
    return jwt.encode(payload, JWT_SECRET, algorithm=JWT_ALGORITHM)


def _get_current_user(
    credentials: HTTPAuthorizationCredentials | None = Depends(security),
) -> dict:
    if credentials is None:
        raise HTTPException(status_code=401, detail="未登录")
    try:
        payload = jwt.decode(
            credentials.credentials, JWT_SECRET, algorithms=[JWT_ALGORITHM]
        )
        return {"user_id": payload["user_id"], "username": payload["username"]}
    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=401, detail="登录已过期，请重新登录")
    except jwt.InvalidTokenError:
        raise HTTPException(status_code=401, detail="无效的登录凭证")


@app.post("/v1/auth/register")
def register(payload: UserRegister) -> dict:
    username = payload.username.strip()
    if not username:
        raise HTTPException(status_code=400, detail="用户名不能为空")

    password_hash = _hash_password(payload.password)
    user_id = f"user_{uuid.uuid4().hex}"
    now = now_iso()

    with get_connection() as connection:
        existing = connection.execute(
            "SELECT id FROM users WHERE username = ?", (username,)
        ).fetchone()
        if existing:
            raise HTTPException(status_code=409, detail="用户名已存在")
        connection.execute(
            "INSERT INTO users(id, username, password_hash, created_at) VALUES(?, ?, ?, ?)",
            (user_id, username, password_hash, now),
        )

    token = _create_token(user_id, username)
    return {
        "success": True,
        "message": "注册成功",
        "data": {"user_id": user_id, "username": username, "token": token},
    }


@app.post("/v1/auth/login")
def login(payload: UserLogin) -> dict:
    username = payload.username.strip()
    with get_connection() as connection:
        row = connection.execute(
            "SELECT id, username, password_hash FROM users WHERE username = ?",
            (username,),
        ).fetchone()

    if row is None or not _check_password(payload.password, row["password_hash"]):
        raise HTTPException(status_code=401, detail="用户名或密码错误")

    token = _create_token(row["id"], row["username"])
    return {
        "success": True,
        "message": "登录成功",
        "data": {
            "user_id": row["id"],
            "username": row["username"],
            "token": token,
        },
    }


@app.get("/v1/auth/me")
def auth_me(user: dict = Depends(_get_current_user)) -> dict:
    return {"success": True, "data": user}


# ===== AI 代理（服务端持有 API Key，客户端不暴露） =====


async def _request_structured_ai(body: dict[str, Any]) -> dict[str, Any]:
    if not OPENAI_API_KEY:
        raise HTTPException(status_code=500, detail="服务端未配置 AI API Key")
    async with httpx.AsyncClient(timeout=120.0) as client:
        response = await client.post(
            f"{OPENAI_BASE_URL.rstrip('/')}/chat/completions",
            headers={
                "Authorization": f"Bearer {OPENAI_API_KEY}",
                "Content-Type": "application/json",
            },
            json=body,
        )
    if response.status_code != 200:
        raise HTTPException(
            status_code=502,
            detail=f"AI 服务错误 ({response.status_code}): {response.text[:500]}",
        )
    try:
        content = response.json()["choices"][0]["message"]["content"].strip()
        if content.startswith("```"):
            content = content.split("\n", 1)[1].rsplit("```", 1)[0].strip()
        value = json_lib.loads(content)
        if not isinstance(value, dict):
            raise ValueError("AI response is not an object")
        return value
    except (KeyError, IndexError, TypeError, ValueError, json_lib.JSONDecodeError) as error:
        raise HTTPException(status_code=502, detail="AI 返回内容不是有效 JSON 对象") from error


@app.post("/v1/ai/chat")
async def ai_chat(
    request: AiChatRequest,
    user: dict = Depends(_get_current_user),
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


@app.post("/v1/ai/exercise-recognition")
async def recognize_exercise(
    activity_type: str = Form(...),
    images: list[UploadFile] = File(...),
    user: dict = Depends(_get_current_user),
) -> dict[str, Any]:
    if not 1 <= len(images) <= 4:
        raise HTTPException(status_code=400, detail="请上传 1 至 4 张运动截图")

    image_parts: list[dict[str, Any]] = []
    for image in images:
        inferred_type = mimetypes.guess_type(image.filename or "")[0]
        media_type = (
            image.content_type
            if (image.content_type or "").startswith("image/")
            else inferred_type
        )
        if not (media_type or "").startswith("image/"):
            raise HTTPException(status_code=400, detail="仅支持图片文件")
        content = await image.read()
        if len(content) > 8 * 1024 * 1024:
            raise HTTPException(status_code=413, detail="单张图片不能超过 8 MB")
        encoded = base64.b64encode(content).decode("ascii")
        image_parts.append({
            "type": "image_url",
            "image_url": {"url": f"data:{media_type};base64,{encoded}"},
        })

    body = {
        "model": OPENAI_MODEL,
        "messages": [
            {
                "role": "system",
                "content": (
                    "你是运动截图结构化识别助手。只提取截图中明确出现的数据，"
                    "无法确认的字段返回 null，只输出 JSON 对象。detail 使用标准键："
                    "跑步 average_pace/cadence_spm，游泳 stroke/laps，骑行 "
                    "average_speed_kmh/elevation_gain_m，步行 steps/average_speed_kmh。"
                ),
            },
            {
                "role": "user",
                "content": [
                    {
                        "type": "text",
                        "text": (
                            f"运动类型：{activity_type}。返回 started_at、duration_seconds、"
                            "distance_meters、average_heart_rate_bpm、peak_heart_rate_bpm、"
                            "calories_kcal、rpe、detail、confidence、warnings。"
                        ),
                    },
                    *image_parts,
                ],
            },
        ],
        "response_format": {"type": "json_object"},
        "temperature": 0.1,
    }
    result = await _request_structured_ai(body)
    return {"success": True, "data": result}


@app.post("/v1/ai/health-analysis")
async def analyze_health(
    request: HealthAnalysisRequest,
    user: dict = Depends(_get_current_user),
) -> dict[str, Any]:
    body = {
        "model": OPENAI_MODEL,
        "messages": [
            {
                "role": "system",
                "content": (
                    "你是生活方式健康教练。仅依据输入 metrics 给出最多 6 条饮食、运动或休息建议。"
                    "每条建议必须包含 category、priority、title、action 和 evidence，"
                    "evidence 必须逐字选自 allowed_evidence。"
                    "禁止疾病诊断和处方，只输出包含 overview、recommendations、risk_alerts 的 JSON。"
                ),
            },
            {
                "role": "user",
                "content": json_lib.dumps(request.model_dump(mode="json"), ensure_ascii=False),
            },
        ],
        "response_format": {"type": "json_object"},
        "temperature": 0.3,
    }
    result = await _request_structured_ai(body)
    return {"success": True, "data": result}


@app.post("/v1/ai/daily-plan")
async def generate_daily_plan(
    request: DailyAgentPlanRequest,
    user: dict = Depends(_get_current_user),
) -> dict[str, Any]:
    body = {
        "model": OPENAI_MODEL,
        "messages": [
            {
                "role": "system",
                "content": (
                    "你是个人健康 Agent 的行动规划器。只能引用 allowed_evidence 中逐字匹配的依据。"
                    "输出 summary 和 1 至 3 条 actions，每条含 category、priority、title、action、"
                    "evidence、target。禁止疾病诊断、处方、治疗和药物建议，只输出 JSON。"
                ),
            },
            {
                "role": "user",
                "content": json_lib.dumps(
                    request.model_dump(mode="json"), ensure_ascii=False
                ),
            },
        ],
        "response_format": {"type": "json_object"},
        "temperature": 0.2,
    }
    result = await _request_structured_ai(body)
    try:
        validated = DailyAgentPlanResult.model_validate(result)
    except Exception as error:
        raise HTTPException(status_code=502, detail="AI 每日计划格式无效") from error

    allowed_evidence = set(request.allowed_evidence)
    for action in validated.actions:
        if not set(action.evidence).issubset(allowed_evidence):
            raise HTTPException(status_code=502, detail="AI 每日计划引用了未授权依据")
    return {"success": True, "data": validated.model_dump(mode="json")}
