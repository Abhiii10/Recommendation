from __future__ import annotations

from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
IMAGE_DIR = ROOT / "app" / "assets" / "images"
MAX_SIZE = (1600, 900)
QUALITY = 76


def optimize_png_to_webp(source: Path) -> Path:
    target = source.with_name(f"{source.stem}_hero.webp")
    image = Image.open(source).convert("RGB")
    image.thumbnail(MAX_SIZE, Image.Resampling.LANCZOS)
    image.save(target, "WEBP", quality=QUALITY, method=6)
    return target


def main() -> None:
    for source in IMAGE_DIR.glob("*.png"):
        target = optimize_png_to_webp(source)
        print(
            f"{source.name}: {source.stat().st_size:,} bytes -> "
            f"{target.name}: {target.stat().st_size:,} bytes"
        )


if __name__ == "__main__":
    main()
