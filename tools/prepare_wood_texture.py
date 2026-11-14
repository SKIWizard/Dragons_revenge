"""Make an exact PNG copy of the decoded user-supplied wood JPEG."""

from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "wood_texture.jpg"
DESTINATION = ROOT / "assets/textures/wood_texture.png"


def main() -> None:
    with Image.open(SOURCE) as source:
        image = source.convert("RGB")
        DESTINATION.parent.mkdir(parents=True, exist_ok=True)
        image.save(DESTINATION, format="PNG")
    print(f"Saved {image.width}x{image.height} wood texture to {DESTINATION}")


if __name__ == "__main__":
    main()
