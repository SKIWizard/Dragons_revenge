"""Render Russian menu labels as portable transparent PNGs."""

from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

root = Path(__file__).resolve().parents[1]
output = root / "assets" / "ui"
output.mkdir(parents=True, exist_ok=True)
font = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial Unicode.ttf", 29)
for name, label in {
    "play": "ИГРАТЬ",
    "settings": "НАСТРОЙКИ",
    "volume": "ГРОМКОСТЬ",
    "back": "НАЗАД",
}.items():
    bounds = ImageDraw.Draw(Image.new("RGBA", (1, 1))).textbbox((0, 0), label, font=font, stroke_width=1)
    image = Image.new("RGBA", (bounds[2]-bounds[0]+8, bounds[3]-bounds[1]+8), (0, 0, 0, 0))
    ImageDraw.Draw(image).text((4-bounds[0], 4-bounds[1]), label, font=font,
                               fill=(255, 236, 190, 255), stroke_width=1,
                               stroke_fill=(36, 29, 42, 255))
    image.save(output / f"menu_{name}.png")
