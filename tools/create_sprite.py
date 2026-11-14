#!/usr/bin/env python3
"""Draw three intentional 32x32 dragon concepts with Pillow primitives."""
from __future__ import annotations

import argparse
import json
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
PALETTE = json.loads((ROOT / "art/palettes/dragon.json").read_text())["colors"]


def draw_concept(name: str) -> Image.Image:
    image = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    d = ImageDraw.Draw(image)

    def poly(points, color):
        d.polygon(points, fill=PALETTE[color])

    def rect(box, color):
        d.rectangle(box, fill=PALETTE[color])

    def point(x, y, color):
        d.point((x, y), fill=PALETTE[color])

    if name == "sprout":
        # Broad leaf wing, curled tail, round head. Wing and tail sit behind body.
        poly([(11, 14), (5, 7), (2, 6), (4, 13), (1, 18), (7, 19), (11, 17)], "outline")
        poly([(9, 14), (5, 9), (4, 9), (6, 14), (3, 17), (8, 17)], "wing_shadow")
        poly([(5, 9), (8, 12), (8, 15), (6, 14)], "wing_light")
        poly([(11, 22), (6, 21), (3, 23), (3, 26), (7, 28), (10, 26), (8, 25), (6, 25), (8, 24), (12, 26)], "outline")
        poly([(9, 23), (5, 23), (5, 26), (7, 26), (7, 24), (10, 26)], "mid_green")
        poly([(11, 14), (19, 12), (24, 16), (25, 24), (21, 28), (12, 28), (9, 23)], "outline")
        poly([(12, 15), (19, 14), (23, 18), (23, 24), (20, 27), (12, 26), (10, 22)], "shadow")
        poly([(13, 15), (19, 14), (22, 17), (19, 20), (13, 20), (11, 18)], "green")
        poly([(13, 15), (18, 14), (20, 15), (17, 17), (13, 17)], "light_green")
        poly([(19, 18), (23, 20), (22, 25), (19, 26), (17, 23)], "belly_shadow")
        poly([(19, 18), (22, 20), (21, 24), (19, 24), (18, 22)], "belly")
        rect((19, 19, 20, 20), "belly_light")
        poly([(17, 8), (18, 4), (20, 7), (23, 4), (24, 9)], "outline")
        poly([(18, 7), (19, 5), (20, 8), (22, 7), (23, 6), (23, 10)], "belly")
        poly([(14, 11), (17, 8), (24, 8), (27, 11), (27, 15), (30, 16), (30, 19), (27, 21), (19, 21), (14, 18)], "outline")
        poly([(16, 11), (19, 9), (24, 9), (26, 12), (26, 16), (29, 17), (28, 19), (19, 19), (15, 17)], "green")
        poly([(17, 11), (20, 9), (24, 10), (25, 12), (19, 13), (16, 14)], "light_green")
        poly([(20, 10), (23, 9), (24, 10), (21, 11)], "highlight")
        poly([(25, 16), (29, 17), (28, 19), (24, 19)], "belly")
        rect((22, 13, 24, 15), "eye")
        point(22, 13, "eye_shine")
        point(28, 17, "outline")
        point(18, 18, "cheek")
        poly([(11, 25), (15, 25), (16, 29), (11, 29)], "outline")
        rect((12, 26, 14, 28), "mid_green")
        poly([(20, 25), (24, 25), (25, 29), (20, 29)], "outline")
        rect((21, 26, 23, 28), "green")
        rect((11, 29, 16, 29), "deep_shadow")
        rect((20, 29, 25, 29), "deep_shadow")
    elif name == "kite":
        # Taller, more alert: triangular wing and upright neck.
        poly([(12, 17), (6, 3), (3, 4), (6, 16), (2, 20), (9, 21), (14, 18)], "outline")
        poly([(11, 16), (6, 6), (5, 7), (8, 16), (5, 19), (10, 19)], "wing")
        poly([(5, 6), (8, 12), (9, 15), (7, 13)], "wing_light")
        poly([(11, 23), (5, 23), (2, 25), (5, 28), (10, 26)], "outline")
        poly([(9, 23), (5, 24), (4, 25), (6, 26), (10, 25)], "shadow")
        poly([(11, 15), (20, 13), (25, 17), (24, 25), (20, 28), (10, 27), (8, 21)], "outline")
        poly([(12, 16), (19, 14), (23, 17), (22, 25), (19, 27), (11, 25), (9, 21)], "shadow")
        poly([(13, 16), (20, 15), (21, 18), (16, 20), (10, 19)], "green")
        poly([(13, 16), (17, 15), (20, 16), (17, 17), (13, 18)], "highlight")
        poly([(19, 18), (23, 19), (23, 24), (19, 26), (17, 22)], "belly_shadow")
        poly([(20, 18), (22, 20), (21, 24), (19, 24), (18, 22)], "belly")
        poly([(16, 8), (18, 3), (20, 7), (22, 4), (23, 8)], "outline")
        poly([(18, 7), (18, 5), (20, 8), (22, 6), (22, 9)], "belly_light")
        poly([(14, 10), (17, 7), (24, 8), (27, 10), (27, 14), (30, 15), (30, 18), (26, 20), (17, 19), (13, 15)], "outline")
        poly([(16, 10), (18, 8), (23, 9), (26, 11), (26, 15), (29, 16), (28, 18), (17, 18), (14, 15)], "mid_green")
        poly([(16, 10), (19, 8), (23, 9), (24, 11), (20, 12), (15, 13)], "light_green")
        poly([(20, 9), (23, 9), (24, 10), (21, 10)], "highlight")
        poly([(24, 16), (29, 16), (28, 18), (24, 18)], "belly")
        rect((21, 12, 23, 14), "eye")
        point(21, 12, "eye_shine")
        point(28, 16, "outline")
        point(17, 16, "cheek")
        poly([(10, 25), (14, 25), (15, 29), (10, 29)], "outline")
        rect((11, 26, 13, 28), "green")
        poly([(19, 25), (23, 25), (24, 29), (19, 29)], "outline")
        rect((20, 26, 22, 28), "mid_green")
        rect((10, 29, 15, 29), "deep_shadow")
        rect((19, 29, 24, 29), "deep_shadow")
    elif name == "ember":
        # Lower, rounder dragon with a swept-back wing and pointed tail.
        poly([(9, 17), (2, 11), (2, 7), (8, 10), (12, 13), (14, 18)], "outline")
        poly([(9, 16), (4, 11), (4, 9), (9, 12), (11, 17)], "wing_shadow")
        poly([(4, 9), (8, 11), (9, 13), (6, 12)], "wing_light")
        poly([(11, 22), (5, 21), (2, 19), (4, 25), (1, 27), (8, 28), (12, 25)], "outline")
        poly([(10, 23), (5, 22), (4, 21), (5, 25), (4, 26), (8, 26)], "mid_green")
        poly([(11, 15), (20, 13), (26, 17), (26, 24), (21, 28), (12, 28), (8, 24)], "outline")
        poly([(12, 16), (20, 14), (24, 17), (24, 24), (20, 27), (12, 26), (10, 23)], "shadow")
        poly([(12, 16), (19, 14), (22, 17), (19, 20), (12, 20)], "green")
        poly([(12, 16), (18, 15), (20, 16), (17, 18), (11, 18)], "light_green")
        poly([(18, 19), (23, 19), (24, 24), (20, 26), (17, 24)], "belly_shadow")
        poly([(19, 19), (22, 19), (23, 23), (20, 24), (18, 22)], "belly")
        rect((19, 19, 21, 20), "belly_light")
        poly([(16, 10), (16, 6), (19, 8), (21, 5), (23, 9)], "outline")
        poly([(17, 8), (17, 7), (19, 9), (21, 7), (22, 9)], "belly")
        poly([(13, 10), (18, 8), (24, 9), (28, 12), (28, 16), (31, 17), (30, 21), (24, 22), (16, 19), (12, 15)], "outline")
        poly([(15, 11), (19, 9), (24, 10), (27, 12), (27, 17), (29, 18), (29, 20), (23, 20), (14, 16)], "green")
        poly([(16, 11), (20, 9), (24, 10), (26, 12), (20, 13), (14, 14)], "light_green")
        poly([(20, 9), (23, 10), (22, 11), (18, 11)], "highlight")
        poly([(26, 17), (29, 18), (29, 20), (25, 20)], "belly")
        rect((22, 13, 24, 15), "eye")
        point(22, 13, "eye_shine")
        point(29, 18, "outline")
        point(18, 18, "cheek")
        poly([(11, 25), (15, 25), (16, 29), (11, 29)], "outline")
        rect((12, 26, 14, 28), "mid_green")
        poly([(20, 25), (24, 25), (25, 29), (20, 29)], "outline")
        rect((21, 26, 23, 28), "green")
        rect((11, 29, 16, 29), "deep_shadow")
        rect((20, 29, 25, 29), "deep_shadow")
    else:
        raise ValueError(f"unknown concept: {name}")
    return image


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output-dir", type=Path, default=ROOT / "assets/sprites")
    parser.add_argument("--force", action="store_true", help="overwrite previously generated PNGs")
    args = parser.parse_args()
    args.output_dir.mkdir(parents=True, exist_ok=True)
    for name in ("sprout", "kite", "ember"):
        path = args.output_dir / f"dragon_{name}.png"
        if path.exists() and not args.force:
            raise SystemExit(f"{path} exists; use --force only after reviewing it")
        draw_concept(name).save(path)
        print(path)


if __name__ == "__main__":
    main()
