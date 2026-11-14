#!/usr/bin/env python3
"""Derive an eight-frame barrel-eating cartoon pose from the supplied Vita sprite."""

import argparse
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "DinoSprites - vita.png"
OUTPUT = ROOT / "assets/sprites/dino_vita_eat.png"
FRAME_W, FRAME_H = 48, 32

# Reach, upper muzzle, lower jaw. The bite happens at frame four (0.36 s).
POSES = [(0, 0, 0), (26, 9, 23), (34, 6, 26), (41, 4, 29),
         (46, 3, 30), (43, 4, 29), (31, 8, 25), (0, 0, 0)]

OUTLINE = (50, 56, 33, 255)
SHADOW = (136, 160, 67, 255)
GREEN = (159, 188, 77, 255)
HIGHLIGHT = (177, 198, 94, 255)
MOUTH = (54, 20, 28, 255)
MOUTH_SHADOW = (35, 16, 25, 255)
TONGUE = (196, 63, 49, 255)
TONGUE_LIGHT = (220, 89, 70, 255)
TEETH = (255, 255, 255, 255)
SPIKE = (196, 63, 49, 255)


def frame(base: Image.Image, reach: int, top: int, bottom: int) -> Image.Image:
    result = Image.new("RGBA", (FRAME_W, FRAME_H))
    result.alpha_composite(base, (0, 7))
    if reach == 0:
        return result

    d = ImageDraw.Draw(result)
    # Replace only the original head. The torso, belly, tail and feet stay
    # anchored while the head stretches around the barrel.
    d.rectangle((3, 7, 23, 21), fill=(0, 0, 0, 0))
    d.polygon([(6, 16), (19, 16), (23, 24), (18, 27), (9, 24)], fill=OUTLINE)
    d.polygon([(8, 17), (18, 17), (20, 24), (17, 25), (10, 23)], fill=SHADOW)

    inner_top = top + 8
    inner_bottom = bottom - 5

    # Broad upper skull and squared muzzle, matching the reference silhouette.
    d.polygon([(4, 11), (8, 8), (19, 8), (22, top + 3),
               (reach - 5, top), (reach - 1, top + 3),
               (reach, inner_top + 2), (reach - 3, inner_top + 4),
               (21, 19), (7, 19), (4, 16)], fill=OUTLINE)
    d.polygon([(6, 11), (9, 9), (19, 9), (23, top + 5),
               (reach - 5, top + 2), (reach - 2, top + 4),
               (reach - 2, inner_top + 1), (reach - 5, inner_top + 2),
               (20, 17), (7, 17)], fill=GREEN)
    d.polygon([(12, 10), (22, top + 6), (reach - 6, top + 3),
               (reach - 5, top + 5), (23, 14)], fill=HIGHLIGHT)
    d.polygon([(14, 15), (reach - 6, inner_top - 1),
               (reach - 4, inner_top + 1), (19, 18)], fill=SHADOW)

    # A large mouth cavity joins the back of the jaw instead of floating beside it.
    d.polygon([(17, 17), (reach - 5, inner_top + 1),
               (reach - 2, inner_top + 3), (reach - 3, inner_bottom - 1),
               (reach - 7, inner_bottom + 2), (19, 24), (15, 22)], fill=MOUTH_SHADOW)
    d.polygon([(19, 18), (reach - 6, inner_top + 3),
               (reach - 5, inner_bottom), (21, 23)], fill=MOUTH)

    if bottom - top >= 18:
        d.polygon([(20, 23), (reach - 11, inner_bottom - 2),
                   (reach - 7, inner_bottom + 1), (25, 24)], fill=TONGUE)
        d.line([(25, 23), (reach - 10, inner_bottom - 2)], fill=TONGUE_LIGHT, width=1)

    # Separate lower jaw, still connected to the original body.
    d.polygon([(15, 22), (21, 23), (reach - 6, inner_bottom + 1),
               (reach - 2, bottom - 3), (reach - 2, bottom - 1),
               (reach - 5, bottom), (26, bottom - 1), (18, 27), (13, 26)], fill=OUTLINE)
    d.polygon([(17, 24), (23, 24), (reach - 7, bottom - 3),
               (reach - 3, bottom - 3), (reach - 4, bottom - 2),
               (25, bottom - 3), (18, 25)], fill=GREEN)
    d.line([(22, 25), (reach - 7, bottom - 3)], fill=SHADOW, width=1)

    d.rectangle((8, 12, 14, 17), fill=TEETH)
    d.rectangle((11, 13, 12, 16), fill=OUTLINE)
    d.rectangle((4, 12, 5, 15), fill=SPIKE)
    d.rectangle((4, 19, 5, 22), fill=SPIKE)
    if inner_bottom - inner_top >= 5:
        d.polygon([(reach - 13, inner_top + 2), (reach - 10, inner_top + 2),
                   (reach - 11, inner_top + 6)], fill=TEETH)
        d.polygon([(reach - 7, inner_top + 3), (reach - 4, inner_top + 3),
                   (reach - 5, inner_top + 7)], fill=TEETH)
        d.polygon([(reach - 12, inner_bottom), (reach - 9, inner_bottom),
                   (reach - 10, inner_bottom - 4)], fill=TEETH)
        d.polygon([(reach - 6, inner_bottom - 1), (reach - 3, inner_bottom - 1),
                   (reach - 4, inner_bottom - 5)], fill=TEETH)
    return result


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--force", action="store_true", help="replace the derived sheet intentionally")
    args = parser.parse_args()
    if OUTPUT.exists() and not args.force:
        raise SystemExit("Eating sheet already exists; use --force to rebuild it")
    base = Image.open(SOURCE).convert("RGBA").crop((0, 0, 24, 24))
    sheet = Image.new("RGBA", (FRAME_W * len(POSES), FRAME_H))
    for index, pose in enumerate(POSES):
        sheet.alpha_composite(frame(base, *pose), (index * FRAME_W, 0))
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(OUTPUT)
    print(OUTPUT)


if __name__ == "__main__":
    main()
