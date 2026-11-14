#!/usr/bin/env python3
"""Nearest-neighbour previews at 1x, 4x, 8x plus a light/dark contact sheet."""
from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
BACKGROUNDS = {"light": (236, 235, 219, 255), "dark": (24, 32, 42, 255)}


def preview(sprite: Image.Image, scale: int, background: tuple[int, ...]) -> Image.Image:
    canvas = Image.new("RGBA", (32, 32), background)
    canvas.alpha_composite(sprite)
    return canvas.resize((32*scale, 32*scale), Image.Resampling.NEAREST)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--sprites", type=Path, default=ROOT / "assets/sprites")
    parser.add_argument("--output-dir", type=Path, default=ROOT / "art/previews")
    args = parser.parse_args()
    args.output_dir.mkdir(parents=True, exist_ok=True)
    paths = sorted(args.sprites.glob("dragon_*.png"))
    if not paths:
        raise SystemExit("no dragon sprites found")
    for path in paths:
        sprite = Image.open(path).convert("RGBA")
        for scale in (1, 4, 8):
            for label, color in BACKGROUNDS.items():
                preview(sprite, scale, color).save(args.output_dir / f"{path.stem}_{scale}x_{label}.png")

    # Two rows per concept: light and dark. The source image is never smoothed.
    sheet = Image.new("RGB", (len(paths)*280, 2*280), (45, 48, 53))
    d = ImageDraw.Draw(sheet)
    for column, path in enumerate(paths):
        sprite = Image.open(path).convert("RGBA")
        for row, (label, color) in enumerate(BACKGROUNDS.items()):
            x, y = column*280+12, row*280+8
            sheet.paste(preview(sprite, 8, color).convert("RGB"), (x, y))
            d.text((x, y+260), f"{path.stem} / {label}", fill=(255, 255, 255))
    sheet.save(args.output_dir / "dragon_concepts.png")
    print(args.output_dir / "dragon_concepts.png")


if __name__ == "__main__":
    main()
