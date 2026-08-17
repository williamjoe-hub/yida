from pathlib import Path
from PIL import Image, ImageEnhance


ROOT = Path(__file__).resolve().parents[1]
PRODUCTS = ROOT / "assets" / "products"
TARGET_BG = (245, 243, 239, 255)  # AppTheme.bg / main page background


def normalize(path: Path) -> None:
    image = Image.open(path).convert("RGB")
    # Keep every original garment pixel intact. A mild contrast/sharpness pass
    # restores fabric detail, then a global channel calibration maps the corner
    # background to AppTheme.bg without cutting into white garments.
    canvas = ImageEnhance.Contrast(image).enhance(1.12)
    canvas = ImageEnhance.Sharpness(canvas).enhance(1.10)
    w, h = canvas.size
    px = canvas.load()
    samples = [px[2, 2], px[w - 3, 2], px[2, h - 3], px[w - 3, h - 3]]
    key = tuple(round(sum(c[i] for c in samples) / len(samples)) for i in range(3))
    target = TARGET_BG[:3]
    channels = canvas.split()
    canvas = Image.merge(
        "RGB",
        tuple(
            channel.point(lambda value, d=target[i] - key[i]: max(0, min(255, value + d)))
            for i, channel in enumerate(channels)
        ),
    )
    output = path.with_suffix(".webp")
    canvas.resize((720, 720), Image.Resampling.LANCZOS).save(output, "WEBP", quality=90, method=6)
    thumb = path.with_name(path.stem + "_thumb.webp")
    canvas.resize((280, 280), Image.Resampling.LANCZOS).save(thumb, "WEBP", quality=84, method=6)
    print(output.name, output.stat().st_size, thumb.name, thumb.stat().st_size)


for item in PRODUCTS.glob("*.png"):
    normalize(item)
