from __future__ import annotations

import argparse
import sys
from pathlib import Path


ROOT_DIR = Path(__file__).resolve().parents[1]
if str(ROOT_DIR) not in sys.path:
    sys.path.insert(0, str(ROOT_DIR))

from backend.infrastructure.repositories.json_interaction_repository import (
    JsonInteractionRepository,
)
from backend.infrastructure.repositories.postgres_interaction_repository import (
    PostgresInteractionRepository,
)
from backend.infrastructure.repositories.sqlite_interaction_repository import (
    SqliteInteractionRepository,
)


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Migrate interaction events from JSON or SQLite to PostgreSQL."
    )
    parser.add_argument(
        "--source",
        choices=["sqlite", "json"],
        default="sqlite",
        help="Source interaction store to migrate from.",
    )
    parser.add_argument(
        "--append",
        action="store_true",
        help="Allow inserting into a non-empty PostgreSQL interactions table.",
    )
    args = parser.parse_args()

    source_repo = (
        JsonInteractionRepository()
        if args.source == "json"
        else SqliteInteractionRepository()
    )
    destination_repo = PostgresInteractionRepository(seed_from_json=False)

    interactions = source_repo.get_all()
    existing = destination_repo.get_all()

    if existing and not args.append:
        print(
            "PostgreSQL already contains interaction rows. "
            "Re-run with --append if you intentionally want to add duplicates/new rows.",
            file=sys.stderr,
        )
        return 1

    for interaction in interactions:
        destination_repo.add(interaction)

    print(
        f"Migrated {len(interactions)} interaction events from "
        f"{args.source} to PostgreSQL."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
