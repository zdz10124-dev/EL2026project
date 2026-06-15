from __future__ import annotations

import random
import sqlite3
from datetime import datetime
from typing import Any

from database import get_connection
from schemas import SearchRequest
from settings import LOCAL_TIMEZONE
from utils import compute_distance, location_display_text, parse_datetime_aware


def fetch_all_records() -> list[sqlite3.Row]:
    with get_connection() as connection:
        rows = connection.execute(
            "SELECT * FROM uploaded_records WHERE is_active = 1 ORDER BY created_at DESC"
        ).fetchall()
    return rows


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
        distances = [compute_distance(record, latitude, longitude) for record in records]
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


def build_ordered_items(
    candidates: list[dict[str, Any]],
    randomizer: random.Random,
) -> list[dict[str, Any]]:
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
                recommendation_reason(selected["aggregate"], selected["distance_meters"]),
                selected["feedback"],
            )
        )
    return ordered_items
