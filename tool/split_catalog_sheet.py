from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
PRODUCTS = ROOT / "assets" / "products"
SOURCE = PRODUCTS / "campus_catalog_sheet.png"

NAMES = [
    "cap_black", "beanie_beige", "bucket_navy", "cap_olive",
    "tee_white", "hoodie_navy", "shirt_blue", "cardigan_sage",
    "jeans_blue", "trousers_charcoal", "cargo_beige", "shorts_black",
    "sneakers_white", "canvas_black", "loafers_brown", "runners_grey",
]

image = Image.open(SOURCE).convert("RGB")
for index, name in enumerate(NAMES):
    row, column = divmod(index, 4)
    left = round(column * image.width / 4)
    top = round(row * image.height / 4)
    right = round((column + 1) * image.width / 4)
    bottom = round((row + 1) * image.height / 4)
    tile = image.crop((left, top, right, bottom)).resize((640, 640), Image.Resampling.LANCZOS)
    tile.save(PRODUCTS / f"catalog_{name}.webp", "WEBP", quality=88, method=6)
