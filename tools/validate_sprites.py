#!/usr/bin/env python3
"""Check hard pixel-art constraints; visual quality still needs human review."""
from __future__ import annotations

import argparse
import json
from collections import deque
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
PALETTE = json.loads((ROOT / "art/palettes/dragon.json").read_text())["colors"]
ALLOWED = {tuple(bytes.fromhex(value.lstrip("#"))) for value in PALETTE.values()}


def validate(path: Path) -> list[str]:
    errors: list[str] = []
    with Image.open(path) as opened:
        if opened.size != (32, 32):
            errors.append(f"expected 32x32, got {opened.size}")
        if opened.mode != "RGBA":
            errors.append(f"expected RGBA, got {opened.mode}")
        image = opened.convert("RGBA")
    opaque = {(x, y) for y in range(image.height) for x in range(image.width) if image.getpixel((x, y))[3] == 255}
    alphas = {pixel[3] for pixel in image.get_flattened_data()}
    if not alphas <= {0, 255}:
        errors.append("semi-transparent pixels found (possible antialiasing)")
    colors = {image.getpixel(pos)[:3] for pos in opaque}
    if not 8 <= len(colors) <= 16:
        errors.append(f"expected 8-16 opaque colors, got {len(colors)}")
    if colors - ALLOWED:
        errors.append(f"{len(colors - ALLOWED)} colors are outside the shared palette")
    if not opaque:
        errors.append("empty sprite")
        return errors
    remaining = set(opaque)
    components: list[int] = []
    while remaining:
        queue = deque([remaining.pop()])
        size = 1
        while queue:
            x, y = queue.popleft()
            for next_pos in ((x-1, y), (x+1, y), (x, y-1), (x, y+1)):
                if next_pos in remaining:
                    remaining.remove(next_pos)
                    queue.append(next_pos)
                    size += 1
        components.append(size)
    if len(components) > 1:
        errors.append(f"{len(components)} disconnected opaque clusters; check isolated pixels")
    return errors


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("paths", nargs="*", type=Path)
    args = parser.parse_args()
    paths = args.paths or sorted((ROOT / "assets/sprites").glob("*.png"))
    if not paths:
        raise SystemExit("no sprites found")
    failures = 0
    for path in paths:
        errors = validate(path)
        print(f"{'FAIL' if errors else 'OK  '} {path}: " + ("; ".join(errors) if errors else "32x32 RGBA, binary alpha, palette and silhouette valid"))
        failures += bool(errors)
    raise SystemExit(1 if failures else 0)


if __name__ == "__main__":
    main()
