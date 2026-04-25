#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PRIMARY_SOURCE="$ROOT_DIR/backend/data/destinations.json"
FALLBACK_SOURCE="$ROOT_DIR/data/destinations.json"
DESTINATION="$ROOT_DIR/app/assets/data/backend_destinations.json"

if [[ -f "$PRIMARY_SOURCE" ]]; then
  SOURCE="$PRIMARY_SOURCE"
elif [[ -f "$FALLBACK_SOURCE" ]]; then
  SOURCE="$FALLBACK_SOURCE"
else
  echo "Could not find destinations.json in backend/data or data." >&2
  exit 1
fi

mkdir -p "$(dirname "$DESTINATION")"
cp "$SOURCE" "$DESTINATION"

echo "Synced dataset:"
echo "  $SOURCE"
echo "  -> $DESTINATION"
