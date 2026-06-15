from __future__ import annotations

import uuid
from pathlib import Path
from typing import Any

from fastapi import APIRouter, File, Form, HTTPException, Request, UploadFile

from database import get_connection
from feedback import evaluate_and_apply_moderation
from recommendation_engine import (
    build_aggregate,
    build_ordered_items,
    choose_weighted_record,
    fetch_all_records,
    recommendation_reason,
    score_candidate,
    stable_randomizer,
)
from schemas import (
    CommentRequest,
    ReportRequest,
    SearchRequest,
    VisibilityRequest,
    VoteRequest,
)
from settings import RECOMMENDATION_THRESHOLD, UPLOAD_DIR
from utils import (
    compute_distance,
    location_display_text,
    matches_distance_bucket,
    matches_price_bucket,
    normalize_dish_name,
    now_iso,
    parse_optional_float,
    parse_optional_text,
    recommendation_fingerprint,
)

router = APIRouter(prefix="/v1/recommendations", tags=["recommendations"])


@router.post("/upload-record")
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


@router.post("/search")
def search_recommendations(payload: SearchRequest, request: Request) -> dict[str, Any]:
    rows = fetch_all_records()
    filtered_rows = []
    for row in rows:
        distance_meters = compute_distance(row, payload.latitude, payload.longitude)
        if payload.distance_buckets and not any(
            matches_distance_bucket(distance_meters, bucket)
            for bucket in payload.distance_buckets
        ):
            continue
        if payload.price_buckets and not any(
            matches_price_bucket(row["price"], bucket) for bucket in payload.price_buckets
        ):
            continue
        filtered_rows.append(row)

    grouped = _group_by_normalized_dish(filtered_rows)
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
                    "distance_meters": representative_distance if representative_distance is not None else nearest_distance,
                    "feedback": feedback,
                }
            )

    ordered_items = build_ordered_items(candidates, randomizer)
    start = max(payload.page - 1, 0) * payload.page_size
    end = start + payload.page_size
    return {
        "success": True,
        "message": "ok",
        "data": {
            "total": len(ordered_items),
            "page": payload.page,
            "page_size": payload.page_size,
            "items": ordered_items[start:end],
        },
    }


@router.get("/{record_id}")
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
        fingerprint = recommendation_fingerprint(request)
        feedback = evaluate_and_apply_moderation(
            connection,
            record["dish_name_normalized"],
            fingerprint,
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


@router.post("/{record_id}/comments")
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


@router.post("/{record_id}/visibility")
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


@router.post("/{record_id}/vote")
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

    return {"success": True, "message": "ok", "data": {"feedback": feedback}}


@router.post("/{record_id}/report")
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

    return {"success": True, "message": "ok", "data": {"feedback": feedback}}


def _group_by_normalized_dish(rows: list[Any]) -> dict[str, list[Any]]:
    grouped: dict[str, list[Any]] = {}
    for row in rows:
        grouped.setdefault(row["dish_name_normalized"], []).append(row)
    return grouped
