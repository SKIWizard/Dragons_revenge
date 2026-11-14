"""Create small transparent egg and Russian instruction cards for the intro."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
UI = ROOT / "assets" / "ui"
UI.mkdir(parents=True, exist_ok=True)
EGG_OUT = ROOT / "assets" / "sprites" / "intro_egg.png"

egg = Image.open(ROOT / "egg.png").convert("RGBA").resize((16, 18), Image.Resampling.NEAREST)
pixels = egg.load()
for y in range(18):
    for x in range(16):
        r, g, b, _ = pixels[x, y]
        if b > r or (r < 110 and g < 110):
            pixels[x, y] = (0, 0, 0, 0)
egg.save(EGG_OUT)

font_path = "/System/Library/Fonts/Supplemental/Arial Unicode.ttf"
font = ImageFont.truetype(font_path, 22)
cards = {
    "egg": "НАЖМИТЕ ЛЮБУЮ КЛАВИШУ,\nЧТОБЫ ВЫЛУПИТЬСЯ",
    "move": "A / D — ХОДИТЬ     ПРОБЕЛ — ПРЫГАТЬ",
    "fire": "НАЖМИТЕ МЫШЬЮ, ЧТОБЫ ПУСТИТЬ ОГОНЬ",
    "fight": "СОЖГИТЕ ИХ",
    "barrel": "НАЖМИТЕ E, ЧТОБЫ СЪЕСТЬ БОЧКУ",
}
for name, label in cards.items():
    lines = label.split("\n")
    width = max(int(ImageDraw.Draw(Image.new("RGBA", (1, 1))).textbbox((0, 0), line, font=font)[2]) for line in lines) + 8
    image = Image.new("RGBA", (width, len(lines) * 29), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    for row, line in enumerate(lines):
        draw.text((4, row * 29), line, font=font, fill=(255, 236, 185, 255),
                  stroke_width=1, stroke_fill=(48, 35, 38, 255))
    image.save(UI / f"intro_{name}.png")

# Each character occupies one cell. The game reveals only the first N cells
# of each row, giving Cyrillic a reliable typewriter effect on every platform.
dialogue = {
    "awakening": ["Где я? Что это за место"],
    "knight": ["ДРАКОН?!?! откуда здесь дракон???", "мы убили всех из них"],
    "dragon_shock": ["ВЫ УБИЛИ МОИХ СОРОДИЧЕЙ?!"],
    "knight_threat": ["Мы убили всех драконов которых нашли.",
                      "И мы убьём и тебя, ничтожество"],
    "dragon_vow": ["Я СОЖГУ ВСЕХ ВАС И НЕ ДАМ ПОГАСНУТЬ",
                   "НИ ОДНОМУ ВАШЕМУ ДОМУ"],
}
glyph_font = ImageFont.truetype(font_path, 19)
for name, lines in dialogue.items():
    image = Image.new("RGBA", (max(map(len, lines)) * 16, len(lines) * 30), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    for row, line in enumerate(lines):
        for col, char in enumerate(line):
            draw.text((col * 16 + 1, row * 30), char, font=glyph_font,
                      fill=(255, 240, 212, 255), stroke_width=1,
                      stroke_fill=(43, 29, 48, 255))
    image.save(UI / f"dialogue_{name}.png")
