"""
对外接口：
- GET /
- GET /health
- POST /v1/recommendations/upload-record
- POST /v1/recommendations/search
- GET /v1/recommendations/{record_id}
"""

from __future__ import annotations

import math
import os
import random
import sqlite3
import uuid
from contextlib import contextmanager
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any, Iterator

import json as json_lib

import bcrypt
import httpx
import jwt
from fastapi import (FastAPI, File, Form, HTTPException, Request, UploadFile,
                     status)
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel, Field


APP_DIR = Path(__file__).resolve().parent
DB_PATH = APP_DIR / "recommendations.db"
UPLOAD_DIR = APP_DIR / "uploads"
LOCAL_TIMEZONE = timezone(timedelta(hours=8))
RECOMMENDATION_THRESHOLD = 55.0

# ---- Auth & AI Proxy 配置 ----
JWT_SECRET = os.environ.get("JWT_SECRET", "dev-secret-change-in-production")
JWT_ALGORITHM = "HS256"
JWT_EXPIRE_HOURS = 72
OPENAI_API_KEY = os.environ.get("OPENAI_API_KEY", "")
OPENAI_BASE_URL = os.environ.get("OPENAI_BASE_URL", "https://api.openai.com/v1")

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


class AiChatMessage(BaseModel):
    role: str
    content: Any


class AiChatRequest(BaseModel):
    model: str = "gpt-4o"
    messages: list[AiChatMessage]
    temperature: float = 0.3
    response_format: dict[str, str] | None = None


app = FastAPI(title="今天吃什么 联网推荐服务", version="1.0.0")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
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


def now_iso() -> str:
    return datetime.now(LOCAL_TIMEZONE).isoformat()


def normalize_dish_name(value: str) -> str:
    return " ".join(value.strip().lower().split())


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
) -> dict[str, Any]:
    return {
        "id": record["id"],
        "dish_name": record["dish_name"],
        "location": location_display_text(record),
        "price": record["price"],
        "rating": record["rating_score"],
        "distance_meters": round(distance_meters, 1) if distance_meters is not None else None,
        "reason": reason,
        "aggregate": aggregate,
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
            "SELECT * FROM uploaded_records ORDER BY created_at DESC"
        ).fetchall()
    return rows


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
                price, rating_score, comment, image_path, image_filename,
                uploaded_at, updated_remote_at
            ) VALUES(
                :id, :client_record_id, :created_at, :updated_at, :dish_name, :dish_name_normalized,
                :location_text, :province, :city, :district, :latitude, :longitude,
                :price, :rating_score, :comment, :image_path, :image_filename,
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
def search_recommendations(payload: SearchRequest) -> dict[str, Any]:
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
    candidates: list[dict[str, Any]] = []
    for records in grouped.values():
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
            "SELECT * FROM uploaded_records WHERE dish_name_normalized = ? ORDER BY created_at DESC",
            (record["dish_name_normalized"],),
        ).fetchall()

    aggregate = build_aggregate(list(related_rows))
    base_url = str(request.base_url).rstrip("/")
    image_url = f"{base_url}{record['image_path']}" if record["image_path"] else None
    distance_meters = None
    data = {
        "id": record["id"],
        "dish_name": record["dish_name"],
        "location": location_display_text(record),
        "price": record["price"],
        "rating": record["rating_score"],
        "created_at": record["created_at"],
        "comment": record["comment"],
        "image_url": image_url,
        "distance_meters": distance_meters,
        "reason": recommendation_reason(aggregate, distance_meters),
        "aggregate": aggregate,
    }
    return {"success": True, "message": "ok", "data": data}


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
