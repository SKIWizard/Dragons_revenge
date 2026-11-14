"""Pack the supplied barbarian frames at their native 20x20 resolution."""

from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "microFantasy.v0.4/characters/barbarian"
OUTPUT = ROOT / "assets/sprites/barbarian.png"
FRAME_SIZE = 20
GROUPS = (("idle", 4), ("run", 4), ("attack", 13))


def main() -> None:
    sheet = Image.new("RGBA", (FRAME_SIZE * sum(count for _, count in GROUPS), FRAME_SIZE))
    frame = 0
    for animation, count in GROUPS:
        for number in range(1, count + 1):
            with Image.open(SOURCE / f"barbarian_{animation}_{number:02}.png") as source:
                image = source.convert("RGBA")
                if image.size != (FRAME_SIZE, FRAME_SIZE):
                    raise ValueError(f"Unexpected barbarian frame size: {image.size}")
                sheet.alpha_composite(image, (frame * FRAME_SIZE, 0))
            frame += 1
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(OUTPUT)
    print(f"Saved {frame} unscaled barbarian frames to {OUTPUT}")


if __name__ == "__main__":
    main()
