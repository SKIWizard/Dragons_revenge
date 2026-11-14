"""Pack Colour 1 FreeKnight frames without resampling or modifying sources."""

from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "FreeKnight_v1/Colour1/NoOutline/120x80_PNGSheets"
OUTPUT = ROOT / "assets/sprites/free_knight_boss.png"
SOURCE_WIDTH = 120
FRAME_HEIGHT = 80
GROUPS = (("Idle", 10), ("Run", 10), ("Attack", 4),
          ("Jump", 3), ("Fall", 3), ("Dash", 2))


def main() -> None:
    frames = sum(count for _, count in GROUPS)
    sheet = Image.new("RGBA", (frames * SOURCE_WIDTH, FRAME_HEIGHT))
    frame = 0
    for name, count in GROUPS:
        with Image.open(SOURCE / f"_{name}.png") as source:
            image = source.convert("RGBA")
            if image.size != (count * SOURCE_WIDTH, 80):
                raise ValueError(f"Unexpected {name} sheet size: {image.size}")
            for index in range(count):
                left = index * SOURCE_WIDTH
                frame_image = image.crop((left, 0, left + SOURCE_WIDTH, FRAME_HEIGHT))
                sheet.alpha_composite(frame_image, (frame * SOURCE_WIDTH, 0))
                frame += 1
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(OUTPUT)
    print(f"Saved {frame} native-pixel boss frames to {OUTPUT}")


if __name__ == "__main__":
    main()
