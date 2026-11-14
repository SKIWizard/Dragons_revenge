#!/usr/bin/env python3
"""Derive two 24x24 jump poses from Vita's first frame without editing the source."""
import argparse
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "DinoSprites - vita.png"
OUTPUT = ROOT / "assets/sprites/dino_vita_jump.png"

OUTLINE = (50, 56, 33, 255)
SHADOW = (136, 160, 67, 255)
GREEN = (159, 188, 77, 255)
TRANSPARENT = (0, 0, 0, 0)


def pose(base: Image.Image, rising: bool) -> Image.Image:
    frame = base.copy()
    draw = ImageDraw.Draw(frame)
    # Move the head by one source pixel. Keep the neck joined to the torso.
    head = base.crop((4, 4, 20, 12))
    draw.rectangle((4, 4, 19, 11), fill=TRANSPARENT)
    frame.paste(head, (4, 3 if rising else 5))
    if rising:
        for x in range(7, 15):
            frame.putpixel((x, 11), base.getpixel((x, 12)))
    draw = ImageDraw.Draw(frame)
    draw.rectangle((6, 18, 16, 21), fill=TRANSPARENT)
    if rising:
        # Both knees tuck in; the rear foot folds back and the front foot points up.
        draw.point((7, 18), fill=OUTLINE)
        draw.line((8, 18, 9, 18), fill=SHADOW)
        draw.point((10, 18), fill=OUTLINE)
        draw.line((12, 18, 14, 18), fill=GREEN)
        draw.point((15, 18), fill=OUTLINE)
        draw.line((6, 19, 8, 19), fill=OUTLINE)
        draw.line((13, 19, 15, 19), fill=OUTLINE)
    else:
        # Feet extend down and apart, ready to meet the ground.
        draw.line((8, 18, 9, 18), fill=SHADOW)
        draw.line((10, 18, 10, 20), fill=OUTLINE)
        draw.line((12, 18, 13, 18), fill=GREEN)
        draw.line((14, 18, 14, 20), fill=OUTLINE)
        draw.line((8, 19, 9, 20), fill=SHADOW)
        draw.line((12, 19, 13, 20), fill=GREEN)
        draw.line((7, 21, 10, 21), fill=OUTLINE)
        draw.line((12, 21, 15, 21), fill=OUTLINE)
    return frame


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--force", action="store_true", help="replace the generated jump sheet")
    args = parser.parse_args()
    if OUTPUT.exists() and not args.force:
        raise SystemExit(f"{OUTPUT} already exists; remove it only after reviewing")
    with Image.open(SOURCE) as sheet:
        base = sheet.convert("RGBA").crop((0, 0, 24, 24))
        source_colors = {color for color in base.get_flattened_data() if color[3]}
    result = Image.new("RGBA", (48, 24), TRANSPARENT)
    for index, rising in enumerate((True, False)):
        frame = pose(base, rising)
        assert frame.size == (24, 24)
        assert {color for color in frame.get_flattened_data() if color[3]} <= source_colors
        result.alpha_composite(frame, (index * 24, 0))
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    result.save(OUTPUT)
    print(OUTPUT)


if __name__ == "__main__":
    main()
