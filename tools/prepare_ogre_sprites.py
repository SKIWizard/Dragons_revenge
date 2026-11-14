"""Pack Micro Fantasy's troll frames as the ogre without resampling pixels."""

from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "microFantasy.v0.4/characters/troll"
OUTPUT = ROOT / "assets/sprites/ogre.png"
FRAME_SIZE = 22
GROUPS = (("idle", 4, 6), ("run", 4, 5), ("attack", 8, 0))


def main() -> None:
    sheet = Image.new("RGBA", (FRAME_SIZE * sum(count for _, count, _ in GROUPS), FRAME_SIZE))
    frame = 0
    for animation, count, y_offset in GROUPS:
        for number in range(1, count + 1):
            with Image.open(SOURCE / f"troll_{animation}_{number:02}.png") as original:
                image = original.convert("RGBA")
                expected = (22, 22) if animation == "attack" else (16, 16)
                if image.size != expected:
                    raise ValueError(f"Unexpected {animation} frame size: {image.size}")
                sheet.alpha_composite(image, (frame * FRAME_SIZE, y_offset))
            frame += 1
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(OUTPUT)
    print(f"Saved {frame} unscaled ogre frames to {OUTPUT}")


if __name__ == "__main__":
    main()
