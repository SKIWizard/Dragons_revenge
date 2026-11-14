#!/usr/bin/env python3
"""Draw transparent 16x16 icons in Material enum order with hard pixel edges."""
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "assets/sprites/material_icons.png"
NAMES = [
    "sand", "water", "stone", "smoke", "wood", "fire", "steam",
    "plasma", "lava", "powder", "boom", "petrol", "acid", "iron", "snow",
    "knight_debris", "ogre_debris", "ground", "grass", "glass", "blood", "potion",
]
COLORS = {
    "sand": ((210, 180, 40), (255, 230, 0), (134, 105, 26)),
    "water": ((0, 105, 148), (30, 144, 255), (0, 40, 116)),
    "stone": ((105, 105, 105), (169, 169, 169), (56, 61, 70)),
    "smoke": ((128, 128, 128), (180, 180, 180), (82, 84, 95)),
    "wood": ((139, 69, 19), (160, 120, 80), (79, 43, 32)),
    "fire": ((255, 69, 0), (255, 215, 0), (156, 27, 15)),
    "steam": ((220, 220, 220), (255, 255, 253), (141, 160, 170)),
    "plasma": ((200, 0, 200), (255, 100, 255), (95, 27, 138)),
    "lava": ((178, 34, 34), (255, 99, 71), (96, 23, 35)),
    "powder": ((80, 80, 80), (120, 120, 120), (41, 45, 48)),
    "boom": ((254, 0, 0), (255, 100, 100), (127, 12, 25)),
    "petrol": ((73, 77, 43), (95, 100, 55), (42, 47, 33)),
    "acid": ((0, 200, 0), (100, 255, 100), (24, 82, 26)),
    "iron": ((80, 80, 59), (122, 129, 119), (45, 49, 49)),
    "snow": ((230, 242, 250), (255, 255, 254), (137, 184, 210)),
    "knight_debris": ((152, 22, 35), (220, 69, 69), (91, 9, 23)),
    "ogre_debris": ((145, 18, 39), (216, 63, 74), (88, 8, 27)),
    "ground": ((160, 120, 80), (205, 170, 125), (104, 62, 35)),
    "grass": ((55, 120, 15), (115, 185, 70), (25, 89, 5)),
    "glass": ((118, 184, 196), (205, 238, 239), (75, 137, 158)),
    "blood": ((143, 14, 32), (211, 54, 65), (107, 8, 25)),
    "potion": ((230, 86, 170), (246, 133, 195), (179, 38, 122)),
}


def draw_icon(name: str) -> Image.Image:
    image = Image.new("RGBA", (16, 16))
    d = ImageDraw.Draw(image)
    body, light, dark = COLORS[name]
    if name in {"water", "petrol", "acid", "lava", "blood", "potion"}:
        d.polygon([(8, 1), (4, 7), (2, 10), (3, 13), (6, 15), (10, 15), (13, 12), (12, 8)], fill=dark)
        d.polygon([(8, 2), (5, 8), (4, 11), (6, 13), (10, 13), (12, 11), (10, 7)], fill=body)
        d.rectangle((6, 8, 7, 10), fill=light)
        d.point((8, 6), fill=light)
        if name == "lava":
            d.line([(5, 12), (8, 9), (10, 11)], fill=light, width=2)
    elif name in {"fire", "plasma"}:
        d.polygon([(3, 14), (3, 9), (6, 6), (7, 1), (10, 5), (12, 3), (13, 10), (11, 15), (5, 15)], fill=dark)
        d.polygon([(5, 13), (5, 9), (8, 5), (9, 9), (11, 7), (11, 12), (9, 14)], fill=body)
        d.polygon([(7, 13), (8, 9), (10, 12), (9, 14)], fill=light)
    elif name in {"smoke", "steam"}:
        d.ellipse((3, 8, 10, 14), fill=dark)
        d.ellipse((7, 5, 14, 12), fill=body)
        d.ellipse((3, 3, 9, 9), fill=light)
        d.rectangle((7, 1, 9, 4), fill=body)
    elif name == "wood":
        d.rectangle((2, 4, 13, 12), fill=dark)
        d.rectangle((3, 5, 10, 11), fill=body)
        d.line((4, 6, 10, 6), fill=light, width=1)
        d.line((4, 9, 10, 9), fill=dark, width=1)
        d.ellipse((10, 5, 14, 11), fill=light, outline=dark)
    elif name in {"stone", "iron"}:
        d.polygon([(2, 10), (4, 5), (10, 3), (14, 7), (13, 12), (9, 14), (3, 13)], fill=dark)
        d.polygon([(4, 7), (10, 4), (12, 7), (10, 11), (3, 11)], fill=body)
        d.line((5, 6, 9, 5), fill=light, width=2)
        if name == "iron":
            d.rectangle((4, 10, 12, 12), fill=light)
    elif name == "boom":
        d.polygon([(8, 0), (10, 5), (15, 3), (12, 8), (15, 13), (10, 11), (8, 16), (6, 11), (1, 13), (4, 8), (1, 3), (6, 5)], fill=dark)
        d.polygon([(8, 3), (10, 7), (12, 6), (11, 9), (12, 12), (8, 10), (5, 12), (6, 8), (4, 6), (7, 7)], fill=body)
        d.rectangle((7, 7, 9, 9), fill=light)
    elif name == "snow":
        for endpoints in [((8, 1), (8, 14)), ((1, 8), (14, 8)), ((3, 3), (12, 12)), ((12, 3), (3, 12))]:
            d.line((*endpoints[0], *endpoints[1]), fill=dark, width=3)
            d.line((*endpoints[0], *endpoints[1]), fill=light, width=1)
        d.rectangle((7, 7, 9, 9), fill=body)
    else:  # sand and powder: a small, readable heap
        d.polygon([(1, 13), (5, 9), (7, 5), (10, 8), (14, 13), (13, 15), (2, 15)], fill=dark)
        d.polygon([(3, 13), (6, 9), (8, 8), (12, 13)], fill=body)
        for point in [(6, 11), (9, 11), (11, 13), (7, 13)]:
            d.point(point, fill=light)
    return image


def main() -> None:
    sheet = Image.new("RGBA", (16 * len(NAMES), 16))
    for i, name in enumerate(NAMES):
        sheet.alpha_composite(draw_icon(name), (16 * i, 0))
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(OUTPUT)
    print(OUTPUT)


if __name__ == "__main__":
    main()
