from __future__ import annotations

import json as json_lib
import sqlite3
from typing import Any

from settings import (
    DOWNVOTE_RATIO_TO_HIDE,
    MIN_DOWNVOTE_COUNT_TO_HIDE,
    MIN_VOTE_COUNT_TO_HIDE,
    REPORT_COUNT_TO_HIDE,
)
from utils import now_iso


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
