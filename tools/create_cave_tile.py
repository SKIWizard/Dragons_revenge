"""Make a seamless cave brick tile by cutting the framed edge off tile 0."""

from pathlib import Path
from PIL import Image

root = Path(__file__).resolve().parents[1]
source = Image.open(root / "Castle" / "castle_tileset_16x16.png").convert("RGBA")
# Tile zero has a transparent top/left rim and a dark pixel just inside it.
# Keep the brick interior and use its 14x14 cells directly as the repeat unit.
tile = source.crop((2, 2, 16, 16))
output = root / "assets" / "backgrounds" / "cave_brick_seamless.png"
output.parent.mkdir(parents=True, exist_ok=True)
tile.save(output)
