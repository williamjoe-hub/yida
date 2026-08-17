import sys
from pathlib import Path

from PIL import Image, ImageDraw

from catalog_72 import STYLES


ROOT = Path(__file__).resolve().parents[1]
color = sys.argv[1]
cell = 112
label = 18
columns = 8
rows = 9
canvas = Image.new("RGB", (cell * columns, (cell + label) * rows), "white")
draw = ImageDraw.Draw(canvas)
for index, (style_id, name, category, material) in enumerate(STYLES):
    row, column = divmod(index, columns)
    image = Image.open(
        ROOT / "assets" / "catalog" / f"{style_id}_{color}_{material}.webp"
    ).convert("RGB")
    image.thumbnail((cell, cell), Image.Resampling.LANCZOS)
    x = column * cell + (cell - image.width) // 2
    y = row * (cell + label) + (cell - image.height) // 2
    canvas.paste(image, (x, y))
    draw.text((column * cell + 3, row * (cell + label) + cell + 2), style_id, fill="black")
path = ROOT / "tool" / f"catalog_audit_{color}.png"
canvas.save(path)
print(path)
