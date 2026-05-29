from __future__ import annotations

from pathlib import Path
import secrets
import shutil


ROOT_DIR = Path(__file__).resolve().parents[1]
AUTH_SECRET_PLACEHOLDER = "change-this-auth-secret-in-production"

ENV_FILES = [
    (ROOT_DIR / "backend" / ".env.example", ROOT_DIR / "backend" / ".env"),
    (ROOT_DIR / "app" / ".env.example", ROOT_DIR / "app" / ".env"),
]

REQUIRED_KEYS = {
    ROOT_DIR / "backend" / ".env": [
        "GROQ_API_KEY",
        "GEMINI_API_KEY",
        "AUTH_SECRET_KEY",
    ],
    ROOT_DIR / "app" / ".env": [
        "AI_BACKEND_BASE_URL",
    ],
}


def main() -> None:
    for source, destination in ENV_FILES:
        _copy_if_missing(source, destination)

    backend_env = ROOT_DIR / "backend" / ".env"
    _ensure_auth_secret(backend_env)

    for env_path, keys in REQUIRED_KEYS.items():
        values = _read_env(env_path)
        for key in keys:
            value = values.get(key, "").strip()
            if not value or value == AUTH_SECRET_PLACEHOLDER:
                print(f"WARNING: {key} is still empty in {env_path}")


def _copy_if_missing(source: Path, destination: Path) -> None:
    if destination.exists():
        print(f"Keeping existing {destination}")
        return

    if not source.exists():
        print(f"WARNING: template missing: {source}")
        return

    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(source, destination)
    print(f"Created {destination} from {source}")


def _ensure_auth_secret(env_path: Path) -> None:
    values = _read_env(env_path)
    current = values.get("AUTH_SECRET_KEY", "").strip()

    if current and current != AUTH_SECRET_PLACEHOLDER:
        return

    _set_env_value(env_path, "AUTH_SECRET_KEY", secrets.token_hex(32))
    print(f"Generated secure AUTH_SECRET_KEY in {env_path}")


def _read_env(path: Path) -> dict[str, str]:
    if not path.exists():
        return {}

    values: dict[str, str] = {}
    for line in path.read_text(encoding="utf-8-sig").splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith("#") or "=" not in stripped:
            continue

        key, value = stripped.split("=", 1)
        values[key.strip()] = value.strip()

    return values


def _set_env_value(path: Path, key: str, value: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    lines = path.read_text(encoding="utf-8-sig").splitlines() if path.exists() else []
    prefix = f"{key}="
    updated = False

    for index, line in enumerate(lines):
        if line.strip().startswith(prefix):
            lines[index] = f"{key}={value}"
            updated = True
            break

    if not updated:
        lines.append(f"{key}={value}")

    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
