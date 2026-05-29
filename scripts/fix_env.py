from __future__ import annotations

from pathlib import Path


ROOT_DIR = Path(__file__).resolve().parents[1]
UTF8_BOM = b"\xef\xbb\xbf"


def main() -> None:
    env_files = [
        path
        for path in ROOT_DIR.rglob(".env")
        if ".git" not in path.relative_to(ROOT_DIR).parts
    ]

    if not env_files:
        print(f"No .env files found under {ROOT_DIR}")
        return

    for path in env_files:
        raw = path.read_bytes()

        if raw.startswith(UTF8_BOM):
            raw = raw[len(UTF8_BOM):]

        raw = raw.replace(b"\r\n", b"\n").replace(b"\r", b"\n")
        path.write_bytes(raw)
        print(f"Fixed env file: {path}")


if __name__ == "__main__":
    main()
