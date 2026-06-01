#!/usr/bin/env bash
set -euo pipefail

PORT="${PORT:-8000}"
FORCE_RESTART="${FORCE_RESTART:-false}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "$ROOT_DIR"

if [[ -x "${ROOT_DIR}/.venv/bin/python" ]]; then
  PYTHON="${ROOT_DIR}/.venv/bin/python"
else
  PYTHON="python"
fi

backend_healthy() {
  if command -v curl >/dev/null 2>&1; then
    curl -fsS --max-time 3 "http://127.0.0.1:${PORT}/health" >/dev/null 2>&1
    return $?
  fi

  "${PYTHON}" - <<PY >/dev/null 2>&1
import urllib.request
urllib.request.urlopen("http://127.0.0.1:${PORT}/health", timeout=3)
PY
}

if [[ "${FORCE_RESTART}" != "true" ]] && backend_healthy; then
  echo "Backend is already running and healthy on port ${PORT}."
  echo "Use FORCE_RESTART=true if you intentionally want to stop it and start local uvicorn."
  exit 0
fi

echo "Checking port ${PORT}..."
if command -v lsof >/dev/null 2>&1; then
  PIDS="$(lsof -ti tcp:"${PORT}" || true)"
else
  PIDS=""
fi

if [[ -n "${PIDS}" ]]; then
  if [[ "${FORCE_RESTART}" != "true" ]]; then
    echo "Port ${PORT} is occupied and backend health did not pass."
    echo "Stop the conflicting process or rerun with FORCE_RESTART=true."
    exit 1
  fi

  echo "Killing process(es) on port ${PORT}: ${PIDS}"
  kill -9 ${PIDS}
fi

echo "Starting FastAPI backend on port ${PORT}..."
exec "${PYTHON}" -m uvicorn backend.main:app --host 0.0.0.0 --port "${PORT}" --reload
