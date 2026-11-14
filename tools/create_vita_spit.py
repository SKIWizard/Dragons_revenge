#!/usr/bin/env python3
"""Make small mouth-opening poses for Vita's idle and seven running frames."""
import argparse
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "DinoSprites - vita.png"
OUTPUT = ROOT / "assets/sprites/dino_vita_spit.png"
RUN_OUTPUT = ROOT / "assets/sprites/dino_vita_spit_run.png"
RUN_FRAMES = 7
OUTLINE = (50, 56, 33, 255)
GREEN = (159, 188, 77, 255)
RED = (188, 71, 55, 255)
TRANSPARENT = (0, 0, 0, 0)


def pose(base: Image.Image, opening: int) -> Image.Image:
    frame = base.copy()
    if opening == 0:
        return frame
    draw = ImageDraw.Draw(frame)
    # Preserve the eye, head and silhouette. Only the last few muzzle pixels
    # become a small upper lip, dark mouth and lower jaw.
    draw.rectangle((15, 11, 19, 14), fill=TRANSPARENT)
    draw.line((14, 11, 19, 11), fill=OUTLINE)
    draw.line((16, 10, 18, 10), fill=GREEN)
    if opening == 1:
        draw.line((15, 12, 19, 12), fill=GREEN)
        draw.line((15, 13, 19, 13), fill=OUTLINE)
    else:
        draw.rectangle((16, 12, 19, 12 + (opening == 3)), fill=OUTLINE)
        jaw_y = 14 if opening == 2 else 15
        draw.line((15, jaw_y, 19, jaw_y), fill=GREEN)
        draw.line((16, jaw_y + 1, 19, jaw_y + 1), fill=OUTLINE)
        if opening == 3:
            draw.point((18, 14), fill=RED)
    return frame


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--force", action="store_true", help="regenerate derived sprite sheets")
    args = parser.parse_args()
    if OUTPUT.exists() and RUN_OUTPUT.exists() and not args.force:
        raise SystemExit("Both spit sprite sheets already exist; use --force to rebuild them")
    source = Image.open(SOURCE).convert("RGBA")
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    if args.force or not OUTPUT.exists():
        base = source.crop((0, 0, 24, 24))
        sheet = Image.new("RGBA", (24 * 4, 24))
        for opening in range(4):
            sheet.alpha_composite(pose(base, opening), (opening * 24, 0))
        sheet.save(OUTPUT)
        print(OUTPUT)
    if args.force or not RUN_OUTPUT.exists():
        sheet = Image.new("RGBA", (24 * 4 * RUN_FRAMES, 24))
        for opening in range(4):
            for walk_frame in range(RUN_FRAMES):
                source_x = (4 + walk_frame) * 24
                base = source.crop((source_x, 0, source_x + 24, 24))
                index = opening * RUN_FRAMES + walk_frame
                sheet.alpha_composite(pose(base, opening), (index * 24, 0))
        sheet.save(RUN_OUTPUT)
        print(RUN_OUTPUT)


if __name__ == "__main__":
    main()
