"""Make a lossless raylib-compatible copy of the supplied stone texture."""

from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "stone_texture.avif"
DESTINATION = ROOT / "assets/textures/stone_texture.png"


def main() -> None:
    with Image.open(SOURCE) as source:
        image = source.convert("RGB")
        DESTINATION.parent.mkdir(parents=True, exist_ok=True)
        image.save(DESTINATION, format="PNG")
    print(f"Saved {image.width}x{image.height} stone texture to {DESTINATION}")


if __name__ == "__main__":
    main()
