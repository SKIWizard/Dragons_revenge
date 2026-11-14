"""Pack the supplied blue knight frames without altering their source pixels."""

from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "microFantasy.v0.4/characters/knight_blue"
OUTPUT = ROOT / "assets/sprites/knight_blue.png"
FRAME_SIZE = 20
GROUPS = (("idle", 4), ("run", 8), ("attack", 13))


def main() -> None:
    sheet = Image.new("RGBA", (FRAME_SIZE * sum(n for _, n in GROUPS), FRAME_SIZE))
    frame = 0
    for animation, count in GROUPS:
        for number in range(1, count + 1):
            with Image.open(SOURCE / f"knight_blue_{animation}_{number:02}.png") as original:
                image = original.convert("RGBA")
                if image.size == (16, 16):
                    # Idle frames sit four pixels higher in the supplied files.
                    sheet.alpha_composite(image, (frame * FRAME_SIZE, 4))
                elif image.size == (20, 20):
                    sheet.alpha_composite(image, (frame * FRAME_SIZE, 0))
                else:
                    raise ValueError(f"Unexpected {animation} frame size: {image.size}")
            frame += 1
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(OUTPUT)
    print(f"Saved {frame} unscaled frames to {OUTPUT}")


if __name__ == "__main__":
    main()
