"""Create only new boss dialogue labels, ending title, and Mort-derived animations."""

from collections import Counter, defaultdict
from pathlib import Path
import shutil
from PIL import Image, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parents[1]
SPRITES = ROOT / "assets/sprites"
UI = ROOT / "assets/ui"
ending_source = next(ROOT.glob("*дракон*закате.png"))
shutil.copyfile(ending_source, ROOT / "assets/backgrounds/ending_sunset.png")
ending_art = Image.open(ending_source).convert("RGB")
wide = ending_art.resize((1080, 609), Image.Resampling.BICUBIC).filter(ImageFilter.GaussianBlur(5))
wide = Image.blend(wide, Image.new("RGB", wide.size, (33, 15, 32)), 0.45)
fitted_width = round(ending_art.width * 609 / ending_art.height)
portrait = ending_art.resize((fitted_width, 609), Image.Resampling.LANCZOS)
edge = Image.new("L", portrait.size, 255)
for x in range(fitted_width):
    opacity = min(255, x * 255 // 42, (fitted_width - 1 - x) * 255 // 42)
    for y in range(609):
        edge.putpixel((x, y), max(0, opacity))
wide.paste(portrait, ((1080 - fitted_width) // 2, 0), edge)
wide.save(ROOT / "assets/backgrounds/ending_sunset_wide.png")
VITA = Image.open(ROOT / "DinoSprites - vita.png").convert("RGBA")
MORT = Image.open(ROOT / "dinoCharactersVersion1.1/sheets/DinoSprites - mort.png").convert("RGBA")

# Both sheets share a 24x24 frame layout. Map source colours by corresponding
# pixels in their first frame, keeping every generated animation pixel exact.
votes = defaultdict(Counter)
for y in range(24):
    for x in range(24):
        source = VITA.getpixel((x, y))
        target = MORT.getpixel((x, y))
        if source[3] and target[3]:
            votes[source][target] += 1
colour_map = {source: matches.most_common(1)[0][0] for source, matches in votes.items()}
# The Mort sheet draws its eye slightly differently, so the frequency vote for
# Vita's pure white is tied. Keep teeth and eye highlights white in every pose.
colour_map[(255, 255, 255, 255)] = (255, 255, 255, 255)
source_colours = tuple(colour_map)


def mort_colour(pixel):
    source = min(source_colours, key=lambda colour: sum((colour[i] - pixel[i]) ** 2 for i in range(3)))
    mapped = colour_map[source]
    return mapped[:3] + (pixel[3],)


for original, result in (
    ("dino_vita_jump.png", "dino_mort_jump.png"),
    ("dino_vita_spit.png", "dino_mort_spit.png"),
    ("dino_vita_spit_run.png", "dino_mort_spit_run.png"),
    ("dino_vita_eat.png", "dino_mort_eat.png"),
):
    image = Image.open(SPRITES / original).convert("RGBA")
    output = Image.new("RGBA", image.size)
    for y in range(image.height):
        for x in range(image.width):
            pixel = image.getpixel((x, y))
            if pixel[3]:
                output.putpixel((x, y), mort_colour(pixel))
    output.save(SPRITES / result)

font = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial Unicode.ttf", 19)
lines = {
    "boss_question": "Кто ты такой, чёрт возьми?",
    "boss_answer": "Я тот кто отомстит вам за свой род",
    "boss_defiance": "Я... Я не могу проиграть тебе!",
    "boss_farewell": "Ты достойно сражался...",
}
for name, line in lines.items():
    image = Image.new("RGBA", (len(line) * 16, 30), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    for index, character in enumerate(line):
        draw.text((index * 16 + 1, 0), character, font=font,
                  fill=(255, 240, 212, 255), stroke_width=1,
                  stroke_fill=(43, 29, 48, 255))
    image.save(UI / f"dialogue_{name}.png")

title_font = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial Unicode.ttf", 48)
title = "ПРОДОЛЖЕНИЕ СЛЕДУЕТ"
box = ImageDraw.Draw(Image.new("RGBA", (1, 1))).textbbox((0, 0), title, font=title_font, stroke_width=2)
image = Image.new("RGBA", (box[2] - box[0] + 20, box[3] - box[1] + 20), (0, 0, 0, 0))
ImageDraw.Draw(image).text((10 - box[0], 10 - box[1]), title, font=title_font,
                           fill=(255, 226, 164, 255), stroke_width=2,
                           stroke_fill=(48, 18, 34, 255))
image.save(UI / "ending_title.png")
