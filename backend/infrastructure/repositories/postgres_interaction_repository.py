from __future__ import annotations

from datetime import datetime, timezone
from typing import Any, List

from backend.core.config import settings
from backend.domain.entities.interaction import Interaction
from backend.domain.repositories.interaction_repository import InteractionRepository
from backend.shared.json_storage import JsonStorage


class PostgresInteractionRepository(InteractionRepository):
    """
    PostgreSQL-backed interaction storage.

    This is intentionally limited to interaction persistence for now because
    recommendation learning depends on fast, durable event writes first.
    Destination and accommodation reads can continue using JSON while the app
    migrates incrementally.
    """

    def __init__(
        self,
        database_url: str | None = None,
        *,
        seed_from_json: bool = True,
    ):
        self._database_url = database_url or settings.database_url

        if not self._database_url:
            raise RuntimeError(
                "DATABASE_URL is required when INTERACTION_STORAGE_BACKEND=postgres."
            )

        self._ensure_schema()
        if seed_from_json:
            self._seed_from_json_if_empty()

    def get_all(self) -> List[Interaction]:
        with self._connect() as connection:
            with connection.cursor() as cur:
                cur.execute(
                    """
                    SELECT
                        user_id,
                        destination_id,
                        event_type,
                        value,
                        event_timestamp,
                        recommendation_id,
                        recommended_destination_ids,
                        pipeline_used
                    FROM interactions
                    ORDER BY id ASC
                    """
                )
                rows = cur.fetchall()

        return [
            Interaction(
                user_id=row["user_id"],
                destination_id=row["destination_id"],
                event_type=row["event_type"],
                value=float(row["value"]),
                timestamp=self._timestamp_to_string(row["event_timestamp"]),
                recommendation_id=row["recommendation_id"],
                recommended_destination_ids=[
                    str(item)
                    for item in (row["recommended_destination_ids"] or [])
                ],
                pipeline_used=row["pipeline_used"],
            )
            for row in rows
        ]

    def add(self, interaction: Interaction) -> None:
        event_timestamp = interaction.timestamp or datetime.now(timezone.utc).isoformat()

        from psycopg.types.json import Jsonb

        with self._connect() as connection:
            with connection.cursor() as cur:
                cur.execute(
                    """
                    INSERT INTO interactions (
                        user_id,
                        destination_id,
                        event_type,
                        value,
                        event_timestamp,
                        recommendation_id,
                        recommended_destination_ids,
                        pipeline_used
                    )
                    VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
                    """,
                    (
                        interaction.user_id,
                        interaction.destination_id,
                        interaction.event_type,
                        float(interaction.value),
                        event_timestamp,
                        interaction.recommendation_id,
                        Jsonb(interaction.recommended_destination_ids),
                        interaction.pipeline_used,
                    ),
                )
            connection.commit()

    def _connect(self) -> Any:
        try:
            import psycopg
            from psycopg.rows import dict_row
        except ImportError as exc:
            raise RuntimeError(
                "PostgreSQL storage requires psycopg. Install dependencies with "
                "`pip install -r requirements.txt`."
            ) from exc

        return psycopg.connect(self._database_url, row_factory=dict_row)

    def _ensure_schema(self) -> None:
        with self._connect() as connection:
            with connection.cursor() as cur:
                cur.execute(
                    """
                    CREATE TABLE IF NOT EXISTS destinations (
                        id TEXT PRIMARY KEY,
                        name TEXT NOT NULL,
                        district TEXT,
                        province TEXT,
                        payload JSONB NOT NULL DEFAULT '{}'::jsonb,
                        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                        updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
                    )
                    """
                )
                cur.execute(
                    """
                    CREATE TABLE IF NOT EXISTS accommodations (
                        id TEXT PRIMARY KEY,
                        destination_id TEXT NOT NULL,
                        name TEXT NOT NULL,
                        payload JSONB NOT NULL DEFAULT '{}'::jsonb,
                        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                        updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
                    )
                    """
                )
                cur.execute(
                    """
                    CREATE TABLE IF NOT EXISTS users (
                        id TEXT PRIMARY KEY,
                        username TEXT NOT NULL,
                        email TEXT,
                        is_synthetic BOOLEAN NOT NULL DEFAULT FALSE,
                        preferences JSONB NOT NULL DEFAULT '{}'::jsonb,
                        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                        updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
                    )
                    """
                )
                cur.execute(
                    """
                    CREATE TABLE IF NOT EXISTS interactions (
                        id BIGSERIAL PRIMARY KEY,
                        user_id TEXT NOT NULL,
                        destination_id TEXT NOT NULL,
                        event_type TEXT NOT NULL,
                        value DOUBLE PRECISION NOT NULL DEFAULT 1.0,
                        event_timestamp TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                        recommendation_id TEXT,
                        recommended_destination_ids JSONB NOT NULL DEFAULT '[]'::jsonb,
                        pipeline_used TEXT,
                        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
                    )
                    """
                )
                cur.execute(
                    """
                    ALTER TABLE interactions
                    ADD COLUMN IF NOT EXISTS recommendation_id TEXT
                    """
                )
                cur.execute(
                    """
                    ALTER TABLE interactions
                    ADD COLUMN IF NOT EXISTS recommended_destination_ids JSONB
                    NOT NULL DEFAULT '[]'::jsonb
                    """
                )
                cur.execute(
                    """
                    ALTER TABLE interactions
                    ADD COLUMN IF NOT EXISTS pipeline_used TEXT
                    """
                )
                cur.execute(
                    """
                    CREATE INDEX IF NOT EXISTS idx_interactions_user_destination
                    ON interactions(user_id, destination_id)
                    """
                )
                cur.execute(
                    """
                    CREATE INDEX IF NOT EXISTS idx_interactions_destination_event
                    ON interactions(destination_id, event_type)
                    """
                )
                cur.execute(
                    """
                    CREATE INDEX IF NOT EXISTS idx_interactions_event_timestamp
                    ON interactions(event_type, event_timestamp DESC)
                    """
                )
                cur.execute(
                    """
                    CREATE INDEX IF NOT EXISTS idx_interactions_user_timestamp
                    ON interactions(user_id, event_timestamp DESC)
                    """
                )
                cur.execute(
                    """
                    CREATE INDEX IF NOT EXISTS idx_interactions_destination_timestamp
                    ON interactions(destination_id, event_timestamp DESC)
                    """
                )
                cur.execute(
                    """
                    CREATE INDEX IF NOT EXISTS idx_interactions_recommendation
                    ON interactions(recommendation_id)
                    """
                )
            connection.commit()

    def _seed_from_json_if_empty(self) -> None:
        with self._connect() as connection:
            with connection.cursor() as cur:
                cur.execute("SELECT COUNT(*) AS count FROM interactions")
                row = cur.fetchone()

            if row["count"]:
                return

            seed_items = JsonStorage(settings.interactions_file).read()

            if not seed_items:
                return

            from psycopg.types.json import Jsonb

            with connection.cursor() as cur:
                cur.executemany(
                    """
                    INSERT INTO interactions (
                        user_id,
                        destination_id,
                        event_type,
                        value,
                        event_timestamp,
                        recommendation_id,
                        recommended_destination_ids,
                        pipeline_used
                    )
                    VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
                    """,
                    [
                        (
                            item.get("user_id", ""),
                            item.get("destination_id", ""),
                            item.get("event_type", ""),
                            float(item.get("value", 1.0) or 1.0),
                            item.get("timestamp") or datetime.now(timezone.utc).isoformat(),
                            item.get("recommendation_id"),
                            Jsonb(item.get("recommended_destination_ids") or []),
                            item.get("pipeline_used"),
                        )
                        for item in seed_items
                        if item.get("user_id")
                        and item.get("destination_id")
                        and item.get("event_type")
                    ],
                )
            connection.commit()

    def _timestamp_to_string(self, value: Any) -> str | None:
        if value is None:
            return None

        if isinstance(value, datetime):
            return value.isoformat()

        return str(value)
