from __future__ import annotations

import math
import sqlite3
from datetime import datetime

from fastapi import HTTPException, Request

from settings import LOCAL_TIMEZONE

_DISH_SYNONYMS = {
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
_DISH_SUFFIXES = ("套餐", "盖饭", "便当", "小份", "大份", "中份", "特辣", "微辣", "中辣")
_DROP_CHARS = " ,，.。!！?？-_/\\()（）[]【】"


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
    normalized = "".join(char for char in normalized if char not in _DROP_CHARS)
    for source, target in _DISH_SYNONYMS.items():
        normalized = normalized.replace(source, target)
    for suffix in _DISH_SUFFIXES:
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


def parse_datetime_aware(value: str) -> datetime:
    parsed = datetime.fromisoformat(value)
    if parsed.tzinfo is None:
        return parsed.replace(tzinfo=LOCAL_TIMEZONE)
    return parsed.astimezone(LOCAL_TIMEZONE)


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
