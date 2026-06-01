from __future__ import annotations

import json
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
                SELECT
                    user_id,
                    destination_id,
                    event_type,
                    value,
                    timestamp,
                    recommendation_id,
                    recommended_destination_ids,
                    pipeline_used
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
                recommendation_id=row["recommendation_id"],
                recommended_destination_ids=self._decode_recommended_ids(
                    row["recommended_destination_ids"]
                ),
                pipeline_used=row["pipeline_used"],
            )
            for row in rows
        ]

    def add(self, interaction: Interaction) -> None:
        with self._connect() as connection:
            connection.execute(
                """
                INSERT INTO interactions (
                    user_id,
                    destination_id,
                    event_type,
                    value,
                    timestamp,
                    recommendation_id,
                    recommended_destination_ids,
                    pipeline_used
                )
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    interaction.user_id,
                    interaction.destination_id,
                    interaction.event_type,
                    interaction.value,
                    interaction.timestamp,
                    interaction.recommendation_id,
                    json.dumps(interaction.recommended_destination_ids),
                    interaction.pipeline_used,
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
                    recommendation_id TEXT,
                    recommended_destination_ids TEXT NOT NULL DEFAULT '[]',
                    pipeline_used TEXT,
                    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
                )
                """
            )
            self._add_column_if_missing(
                connection,
                "recommendation_id",
                "TEXT",
            )
            self._add_column_if_missing(
                connection,
                "recommended_destination_ids",
                "TEXT NOT NULL DEFAULT '[]'",
            )
            self._add_column_if_missing(
                connection,
                "pipeline_used",
                "TEXT",
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
            connection.execute(
                """
                CREATE INDEX IF NOT EXISTS idx_interactions_recommendation
                ON interactions(recommendation_id)
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
                    user_id,
                    destination_id,
                    event_type,
                    value,
                    timestamp,
                    recommendation_id,
                    recommended_destination_ids,
                    pipeline_used
                )
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                """,
                [
                    (
                        item.get("user_id", ""),
                        item.get("destination_id", ""),
                        item.get("event_type", ""),
                        float(item.get("value", 1.0) or 1.0),
                        item.get("timestamp"),
                        item.get("recommendation_id"),
                        json.dumps(item.get("recommended_destination_ids") or []),
                        item.get("pipeline_used"),
                    )
                    for item in seed_items
                    if item.get("user_id")
                    and item.get("destination_id")
                    and item.get("event_type")
                ],
            )
            connection.commit()

    def _add_column_if_missing(
        self,
        connection: sqlite3.Connection,
        column_name: str,
        column_sql: str,
    ) -> None:
        columns = {
            row["name"]
            for row in connection.execute("PRAGMA table_info(interactions)").fetchall()
        }
        if column_name not in columns:
            connection.execute(
                f"ALTER TABLE interactions ADD COLUMN {column_name} {column_sql}"
            )

    @staticmethod
    def _decode_recommended_ids(raw: str | None) -> list[str]:
        if not raw:
            return []

        try:
            decoded = json.loads(raw)
        except (TypeError, ValueError):
            return []

        if not isinstance(decoded, list):
            return []

        return [str(item) for item in decoded]
