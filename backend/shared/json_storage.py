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
        return json.loads(self.path.read_text(encoding="utf-8"))

    def write(self, data: Any) -> None:
        self.path.parent.mkdir(parents=True, exist_ok=True)
        self.path.write_text(
            json.dumps(data, indent=2, ensure_ascii=False),
            encoding="utf-8",
        )
