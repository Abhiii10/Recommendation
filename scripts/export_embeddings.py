from __future__ import annotations

import json
import sys
from datetime import datetime, timezone
from pathlib import Path

import numpy as np


PROJECT_ROOT = Path(__file__).resolve().parents[1]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from backend.core.config import settings  # noqa: E402
from backend.domain.entities.destination import Destination  # noqa: E402
from backend.infrastructure.ml.sbert_encoder import (  # noqa: E402
    DestinationTextBuilder,
    SbertEncoder,
)


DESTINATIONS_FILE = PROJECT_ROOT / "data" / "destinations.json"
OUTPUT_DIR = PROJECT_ROOT / "app" / "assets" / "data"
EMBEDDINGS_FILE = OUTPUT_DIR / "destination_embeddings.json"
META_FILE = OUTPUT_DIR / "embedding_meta.json"
INT8_SCALE = 127
TARGET_BYTES = 5 * 1024 * 1024


def _load_destinations() -> list[Destination]:
    with DESTINATIONS_FILE.open("r", encoding="utf-8") as handle:
        raw = json.load(handle)

    if not isinstance(raw, list):
        raise ValueError(f"Expected a destination list in {DESTINATIONS_FILE}")

    return [Destination(**item) for item in raw]


def _quantize_to_int8(embeddings: np.ndarray) -> np.ndarray:
    clipped = np.clip(embeddings, -1.0, 1.0)
    return np.rint(clipped * INT8_SCALE).astype(np.int8)


def _write_json(path: Path, payload: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as handle:
        json.dump(payload, handle, ensure_ascii=False, separators=(",", ":"))


def _format_size(num_bytes: int) -> str:
    if num_bytes >= 1024 * 1024:
        return f"{num_bytes / (1024 * 1024):.2f} MB"
    if num_bytes >= 1024:
        return f"{num_bytes / 1024:.1f} KB"
    return f"{num_bytes} bytes"


def main() -> None:
    destinations = _load_destinations()
    text_builder = DestinationTextBuilder()
    texts = [text_builder.build(destination) for destination in destinations]

    print(
        f"Encoding {len(destinations)} destinations with {settings.model_name}..."
    )
    embeddings = SbertEncoder().encode_texts(texts)
    if embeddings.ndim != 2:
        raise ValueError("SBERT returned an unexpected embedding shape")

    quantized = _quantize_to_int8(embeddings)
    entries = {
        destination.id: quantized[index].astype(int).tolist()
        for index, destination in enumerate(destinations)
    }

    metadata = {
        "model": settings.model_name,
        "dims": int(embeddings.shape[1]),
        "count": len(destinations),
        "quantized": True,
        "dtype": "int8",
        "scale": INT8_SCALE,
        "normalization": "L2",
        "generated_at": datetime.now(timezone.utc).isoformat(),
    }

    _write_json(EMBEDDINGS_FILE, entries)
    _write_json(META_FILE, metadata)

    size = EMBEDDINGS_FILE.stat().st_size
    status = "OK" if size <= TARGET_BYTES else "OVER TARGET"
    print(f"Wrote {EMBEDDINGS_FILE}")
    print(f"Wrote {META_FILE}")
    print(f"Embedding file size: {_format_size(size)} ({status}, target < 5 MB)")
    print(f"Dimensions: {metadata['dims']}, quantized: int8 / {INT8_SCALE}")


if __name__ == "__main__":
    main()
