#!/usr/bin/env bash
set -euo pipefail

PORT="${PORT:-8000}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "$ROOT_DIR"

echo "Checking port ${PORT}..."
if command -v lsof >/dev/null 2>&1; then
  PIDS="$(lsof -ti tcp:"${PORT}" || true)"
else
  PIDS=""
fi

if [[ -n "${PIDS}" ]]; then
  echo "Killing process(es) on port ${PORT}: ${PIDS}"
  kill -9 ${PIDS}
fi

echo "Starting FastAPI backend on port ${PORT}..."
exec uvicorn backend.main:app --host 0.0.0.0 --port "${PORT}" --reload
