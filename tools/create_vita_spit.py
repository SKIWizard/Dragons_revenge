#!/usr/bin/env python3
"""Derive a wide cartoon mouth for Vita's idle and seven running frames."""
import argparse
from pathlib import Path
from collections import Counter, defaultdict
from PIL import Image
from create_vita_eat import frame as eating_pose

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "DinoSprites - vita.png"
OUTPUT = ROOT / "assets/sprites/dino_vita_spit.png"
RUN_OUTPUT = ROOT / "assets/sprites/dino_vita_spit_run.png"
MORT_SOURCE = ROOT / "dinoCharactersVersion1.1/sheets/DinoSprites - mort.png"
MORT_OUTPUT = ROOT / "assets/sprites/dino_mort_spit.png"
MORT_RUN_OUTPUT = ROOT / "assets/sprites/dino_mort_spit_run.png"
RUN_FRAMES = 7
FRAME_W, FRAME_H = 48, 32
SPIT_POSES = ((0, 0, 0), (28, 9, 22), (32, 7, 25), (35, 6, 27))


def pose(base: Image.Image, opening: int) -> Image.Image:
    return eating_pose(base, *SPIT_POSES[opening])


def recolor_mort(sheet: Image.Image, vita: Image.Image, mort: Image.Image) -> Image.Image:
    votes = defaultdict(Counter)
    for y in range(24):
        for x in range(24):
            original, red = vita.getpixel((x, y)), mort.getpixel((x, y))
            if original[3] and red[3]:
                votes[original][red] += 1
    mapping = {color: matches.most_common(1)[0][0] for color, matches in votes.items()}
    mapping[(255, 255, 255, 255)] = (255, 255, 255, 255)
    colors = tuple(mapping)
    result = Image.new("RGBA", sheet.size)
    for y in range(sheet.height):
        for x in range(sheet.width):
            pixel = sheet.getpixel((x, y))
            if pixel[3]:
                nearest = min(colors, key=lambda c: sum((c[i] - pixel[i]) ** 2 for i in range(3)))
                result.putpixel((x, y), mapping[nearest][:3] + (pixel[3],))
    return result


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
        sheet = Image.new("RGBA", (FRAME_W * 4, FRAME_H))
        for opening in range(4):
            sheet.alpha_composite(pose(base, opening), (opening * FRAME_W, 0))
        sheet.save(OUTPUT)
        print(OUTPUT)
    if args.force or not RUN_OUTPUT.exists():
        sheet = Image.new("RGBA", (FRAME_W * 4 * RUN_FRAMES, FRAME_H))
        for opening in range(4):
            for walk_frame in range(RUN_FRAMES):
                source_x = (4 + walk_frame) * 24
                base = source.crop((source_x, 0, source_x + 24, 24))
                index = opening * RUN_FRAMES + walk_frame
                sheet.alpha_composite(pose(base, opening), (index * FRAME_W, 0))
        sheet.save(RUN_OUTPUT)
        print(RUN_OUTPUT)
    mort = Image.open(MORT_SOURCE).convert("RGBA")
    for original, output in ((OUTPUT, MORT_OUTPUT), (RUN_OUTPUT, MORT_RUN_OUTPUT)):
        if args.force or not output.exists():
            recolor_mort(Image.open(original).convert("RGBA"), source, mort).save(output)
            print(output)


if __name__ == "__main__":
    main()
