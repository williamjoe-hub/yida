from pathlib import Path

from PIL import Image, ImageDraw

from catalog_72 import COLORS, STYLES


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "assets" / "catalog"
shoes = [item for item in STYLES if item[2] == "shoes"]
colors = list(COLORS)
cell = 150
label = 24
canvas = Image.new("RGB", (cell * len(shoes), (cell + label) * len(colors)), "white")
draw = ImageDraw.Draw(canvas)
for row, color in enumerate(colors):
    for column, (style_id, name, _, material) in enumerate(shoes):
        image = Image.open(OUTPUT / f"{style_id}_{color}_{material}.webp").convert("RGB")
        image.thumbnail((cell, cell), Image.Resampling.LANCZOS)
        x = column * cell + (cell - image.width) // 2
        y = row * (cell + label) + (cell - image.height) // 2
        canvas.paste(image, (x, y))
        draw.text((column * cell + 4, row * (cell + label) + cell + 3), f"{color} {style_id}", fill="black")
canvas.save(ROOT / "tool" / "shoe_audit.png")
print(ROOT / "tool" / "shoe_audit.png")
