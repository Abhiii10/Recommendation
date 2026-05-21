from __future__ import annotations

import sqlite3
from pathlib import Path
from typing import List

from backend.core.config import settings
from backend.domain.entities.interaction import Interaction
from backend.domain.repositories.interaction_repository import InteractionRepository
from backend.shared.json_storage import JsonStorage


class SqliteInteractionRepository(InteractionRepository):
    def __init__(self, db_path: Path | None = None):
        self._db_path = db_path or settings.app_db_file
        self._db_path.parent.mkdir(parents=True, exist_ok=True)
        self._ensure_schema()
        self._seed_from_json_if_empty()

    def get_all(self) -> List[Interaction]:
        with self._connect() as connection:
            rows = connection.execute(
                """
                SELECT user_id, destination_id, event_type, value, timestamp
                FROM interactions
                ORDER BY id ASC
                """
            ).fetchall()

        return [
            Interaction(
                user_id=row["user_id"],
                destination_id=row["destination_id"],
                event_type=row["event_type"],
                value=float(row["value"]),
                timestamp=row["timestamp"],
            )
            for row in rows
        ]

    def add(self, interaction: Interaction) -> None:
        with self._connect() as connection:
            connection.execute(
                """
                INSERT INTO interactions (
                    user_id, destination_id, event_type, value, timestamp
                )
                VALUES (?, ?, ?, ?, ?)
                """,
                (
                    interaction.user_id,
                    interaction.destination_id,
                    interaction.event_type,
                    interaction.value,
                    interaction.timestamp,
                ),
            )
            connection.commit()

    def _connect(self) -> sqlite3.Connection:
        connection = sqlite3.connect(self._db_path, timeout=10)
        connection.row_factory = sqlite3.Row
        connection.execute("PRAGMA journal_mode=WAL")
        connection.execute("PRAGMA foreign_keys=ON")
        return connection

    def _ensure_schema(self) -> None:
        with self._connect() as connection:
            connection.execute(
                """
                CREATE TABLE IF NOT EXISTS interactions (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    user_id TEXT NOT NULL,
                    destination_id TEXT NOT NULL,
                    event_type TEXT NOT NULL,
                    value REAL NOT NULL DEFAULT 1.0,
                    timestamp TEXT,
                    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
                )
                """
            )
            connection.execute(
                """
                CREATE INDEX IF NOT EXISTS idx_interactions_user_destination
                ON interactions(user_id, destination_id)
                """
            )
            connection.execute(
                """
                CREATE INDEX IF NOT EXISTS idx_interactions_destination_event
                ON interactions(destination_id, event_type)
                """
            )
            connection.commit()

    def _seed_from_json_if_empty(self) -> None:
        with self._connect() as connection:
            count = connection.execute(
                "SELECT COUNT(*) AS count FROM interactions"
            ).fetchone()["count"]

            if count:
                return

            seed_items = JsonStorage(settings.interactions_file).read()

            if not seed_items:
                return

            connection.executemany(
                """
                INSERT INTO interactions (
                    user_id, destination_id, event_type, value, timestamp
                )
                VALUES (?, ?, ?, ?, ?)
                """,
                [
                    (
                        item.get("user_id", ""),
                        item.get("destination_id", ""),
                        item.get("event_type", ""),
                        float(item.get("value", 1.0) or 1.0),
                        item.get("timestamp"),
                    )
                    for item in seed_items
                    if item.get("user_id")
                    and item.get("destination_id")
                    and item.get("event_type")
                ],
            )
            connection.commit()
