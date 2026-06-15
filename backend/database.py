from __future__ import annotations

import sqlite3
from contextlib import contextmanager
from typing import Iterator

from settings import DB_PATH, UPLOAD_DIR


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
        _create_users_table(connection)
        _create_uploaded_records_table(connection)
        _create_feedback_tables(connection)
        _create_comments_table(connection)
        _migrate_uploaded_records(connection)


def _create_users_table(connection: sqlite3.Connection) -> None:
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


def _create_uploaded_records_table(connection: sqlite3.Connection) -> None:
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


def _create_feedback_tables(connection: sqlite3.Connection) -> None:
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


def _create_comments_table(connection: sqlite3.Connection) -> None:
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


def _migrate_uploaded_records(connection: sqlite3.Connection) -> None:
    existing_columns = {
        row["name"]
        for row in connection.execute("PRAGMA table_info(uploaded_records)").fetchall()
    }
    optional_columns = {
        "owner_client_id": "TEXT",
        "uploader_name": "TEXT",
        "uploader_avatar": "TEXT",
        "is_active": "INTEGER NOT NULL DEFAULT 1",
    }
    for column_name, column_type in optional_columns.items():
        if column_name not in existing_columns:
            connection.execute(
                f"ALTER TABLE uploaded_records ADD COLUMN {column_name} {column_type}"
            )
            if column_name == "is_active":
                connection.execute("UPDATE uploaded_records SET is_active = 1")
