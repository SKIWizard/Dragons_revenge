#!/usr/bin/env python3
"""Build an integer-pixel barrel break sheet and matching collision mask."""
import argparse
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "barrel.png"
SHEET = ROOT / "assets/sprites/barrel_break.png"
MASK = ROOT / "barrel_mask.odin"
SIZE = (20, 24)
FRAMES = 6


def paste_piece(frame: Image.Image, source: Image.Image, box, dx: int, dy: int) -> None:
    piece = source.crop(box)
    frame.alpha_composite(piece, (box[0] + dx, box[1] + dy))


def flatten_base(base: Image.Image) -> None:
    """Give the barrel a level, full-width footprint on the ground."""
    pixels = base.load()
    pixels[17, 21] = pixels[2, 21]
    pixels[2, 22] = pixels[3, 22]
    pixels[17, 22] = pixels[16, 22]
    for x in range(2, 18):
        if pixels[x, 23][3] == 0:
            r, g, b, _ = pixels[x, 22]
            pixels[x, 23] = (max(0, r-6), max(0, g-4), max(0, b-3), 255)


def build() -> tuple[Image.Image, list[int]]:
    source = Image.open(SOURCE).convert("RGBA")
    cropped = source.crop(source.getbbox())
    base = cropped.resize(SIZE, Image.Resampling.NEAREST)
    pixels = base.load()
    for y in range(SIZE[1]):
        for x in range(SIZE[0]):
            r, g, b, a = pixels[x, y]
            pixels[x, y] = (r, g, b, 255 if a >= 128 else 0)
    flatten_base(base)
    mask = [sum((1 << x) for x in range(SIZE[0]) if base.getpixel((x, y))[3]) for y in range(SIZE[1])]
    frames = [base]
    dark = (45, 27, 35, 255)
    cracked = base.copy()
    draw = ImageDraw.Draw(cracked)
    draw.line(((10, 3), (9, 8), (11, 12), (10, 16), (12, 20)), fill=dark, width=1)
    frames.append(cracked)
    fragment_frames = (
        (((0, 0, 10, 24), -2, 0), ((10, 0, 20, 24), 2, 0)),
        (((0, 0, 10, 12), -2, -2), ((10, 0, 20, 12), 2, -2),
         ((0, 12, 10, 24), -2, 2), ((10, 12, 20, 24), 2, 2)),
        (((2, 1, 9, 5), -2, -2), ((11, 1, 18, 5), 2, -2),
         ((1, 7, 7, 15), -2, 0), ((13, 7, 19, 15), 2, 0),
         ((7, 15, 13, 22), 0, 2)),
        (((3, 3, 7, 7), -2, -2), ((14, 4, 18, 8), 2, -2),
         ((3, 15, 7, 19), -2, 2), ((14, 16, 18, 20), 2, 2)),
    )
    for fragments in fragment_frames:
        frame = Image.new("RGBA", SIZE)
        for box, dx, dy in fragments:
            paste_piece(frame, base, box, dx, dy)
        frames.append(frame)
    sheet = Image.new("RGBA", (SIZE[0] * FRAMES, SIZE[1]))
    for index, frame in enumerate(frames):
        sheet.alpha_composite(frame, (index * SIZE[0], 0))
    return sheet, mask


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--force", action="store_true", help="replace generated barrel files")
    args = parser.parse_args()
    if (SHEET.exists() or MASK.exists()) and not args.force:
        raise SystemExit("Generated barrel files already exist; remove them only when intentionally rebuilding")
    sheet, rows = build()
    SHEET.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(SHEET)
    MASK.write_text(
        "package main\n\n// Generated from barrel.png by tools/create_barrel_animation.py.\n"
        "BARREL_MASK := [24]u32{\n"
        + "".join(f"    0x{row:05X},\n" for row in rows)
        + "}\n"
    )
    print(SHEET, MASK)


if __name__ == "__main__":
    main()
