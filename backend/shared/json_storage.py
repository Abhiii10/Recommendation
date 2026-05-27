import json
from pathlib import Path
from typing import Any


class JsonStorage:
    def __init__(self, path: Path):
        self.path = path

    def read(self) -> Any:
        self.path.parent.mkdir(parents=True, exist_ok=True)
        if not self.path.exists():
            self.path.write_text("[]", encoding="utf-8")
        raw = self.path.read_text(encoding="utf-8").strip()
        if not raw:
            self.path.write_text("[]", encoding="utf-8")
            return []
        return json.loads(raw)

    def write(self, data: Any) -> None:
        self.path.parent.mkdir(parents=True, exist_ok=True)
        self.path.write_text(
            json.dumps(data, indent=2, ensure_ascii=False),
            encoding="utf-8",
        )
