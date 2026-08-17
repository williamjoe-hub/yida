from collections import deque
from pathlib import Path
from PIL import Image, ImageFilter, ImageOps

ROOT = Path(__file__).resolve().parents[1]
PRODUCTS = ROOT / "assets" / "products"
SOURCES = [
    "catalog_cap_black.webp", "catalog_beanie_beige.webp", "catalog_bucket_navy.webp", "catalog_cap_olive.webp",
    "catalog_tee_white.webp", "catalog_hoodie_navy.webp", "catalog_shirt_blue.webp", "catalog_cardigan_sage.webp",
    "catalog_jeans_blue.webp", "catalog_trousers_charcoal.webp", "catalog_cargo_beige.webp", "catalog_shorts_black.webp",
    "catalog_sneakers_white.webp", "catalog_canvas_black.webp", "catalog_loafers_brown.webp", "catalog_runners_grey.webp",
]

def foreground_mask(image: Image.Image, threshold: float = 24) -> Image.Image:
    rgb = image.convert("RGB")
    width, height = rgb.size
    pixels = rgb.load()
    corners = [pixels[2, 2], pixels[width - 3, 2], pixels[2, height - 3], pixels[width - 3, height - 3]]
    key = tuple(sum(item[channel] for item in corners) / 4 for channel in range(3))

    def background(color):
        return sum((color[channel] - key[channel]) ** 2 for channel in range(3)) ** .5 < threshold

    visited = bytearray(width * height)
    queue = deque()
    for x in range(width):
        queue.extend(((x, 0), (x, height - 1)))
    for y in range(height):
        queue.extend(((0, y), (width - 1, y)))
    while queue:
        x, y = queue.popleft()
        index = y * width + x
        if visited[index] or not background(pixels[x, y]):
            continue
        visited[index] = 255
        if x: queue.append((x - 1, y))
        if x + 1 < width: queue.append((x + 1, y))
        if y: queue.append((x, y - 1))
        if y + 1 < height: queue.append((x, y + 1))
    alpha = Image.frombytes("L", (width, height), bytes(255 - item for item in visited))
    return alpha.filter(ImageFilter.GaussianBlur(.65))

for source_name in SOURCES:
    source = Image.open(PRODUCTS / source_name).convert("RGB")
    alpha = foreground_mask(source)
    # Neutral mid-grey carries luminosity/texture; Flutter's BlendMode.color
    # changes hue and saturation while preserving this luminance.
    grey = ImageOps.grayscale(source)
    grey = ImageOps.autocontrast(grey, cutoff=(1, 1))
    rgba = Image.merge("RGBA", (grey, grey, grey, alpha))
    output = PRODUCTS / source_name.replace(".webp", "_tint.webp")
    rgba.save(output, "WEBP", lossless=True, method=6)
    print(output.name, output.stat().st_size)
