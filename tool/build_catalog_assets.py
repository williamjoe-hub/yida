import json
import sys
from pathlib import Path
import numpy as np
from PIL import Image, ImageStat
from scipy import ndimage
from catalog_72 import STYLES, COLORS

ROOT = Path(__file__).resolve().parents[1]
SHEETS = ROOT / "assets" / "catalog_sheets"
OUTPUT = ROOT / "assets" / "catalog"
OUTPUT.mkdir(parents=True, exist_ok=True)

color_key = sys.argv[1]
color_name, _ = COLORS[color_key]
items = []


def garment_catalog_tile(sheet, box, category):
    """Recover, isolate, and center one garment from a nominal 4x4 cell."""
    nominal_width = box[2] - box[0]
    nominal_height = box[3] - box[1]
    expand_x = round(nominal_width * 0.10)
    expand_y = round(nominal_height * 0.10)
    expanded = (
        max(0, box[0] - expand_x),
        max(0, box[1] - expand_y),
        min(sheet.width, box[2] + expand_x),
        min(sheet.height, box[3] + expand_y),
    )
    cell = sheet.crop(expanded)
    width, height = cell.size
    patch_size = max(6, round(min(width, height) * 0.07))
    margin = max(8, round(min(width, height) * 0.07))
    patches = []
    for left, top in (
        (margin, margin),
        (width - margin - patch_size, margin),
        (margin, height - margin - patch_size),
        (width - margin - patch_size, height - margin - patch_size),
    ):
        patches.append(cell.crop((left, top, left + patch_size, top + patch_size)))
    strip = Image.new("RGB", (patch_size * 4, patch_size))
    for index, patch in enumerate(patches):
        strip.paste(patch, (index * patch_size, 0))
    background = tuple(round(value) for value in ImageStat.Stat(strip).median)
    pixels = np.asarray(cell).copy()
    background_array = np.asarray(background, dtype=np.uint8)
    brightness = pixels.astype(np.float32).mean(axis=2)
    line_threshold = min(253.0, float(background_array.mean()) + 5.0)
    bright = brightness >= line_threshold

    def thin_runs(candidates):
        marked = []
        start = None
        for position, active in enumerate([*candidates, False]):
            if active and start is None:
                start = position
            elif not active and start is not None:
                if position - start <= max(6, round(min(width, height) * 0.025)):
                    marked.extend(range(max(0, start - 1), min(len(candidates), position + 1)))
                start = None
        return marked

    grid_rows = thin_runs((bright.mean(axis=1) > 0.68).tolist())
    grid_columns = thin_runs((bright.mean(axis=0) > 0.68).tolist())
    if grid_rows:
        pixels[grid_rows, :] = background_array
    if grid_columns:
        pixels[:, grid_columns] = background_array
    delta = pixels.astype(np.int32) - np.asarray(background, dtype=np.int32)
    foreground = np.sqrt(np.sum(delta * delta, axis=2)) > 10
    border = max(2, round(min(width, height) * 0.008))
    foreground[:border, :] = False
    foreground[-border:, :] = False
    foreground[:, :border] = False
    foreground[:, -border:] = False
    connected = ndimage.binary_closing(foreground, iterations=2)
    connected = ndimage.binary_dilation(connected, iterations=2)
    labels, count = ndimage.label(connected)
    center_x = (box[0] + box[2]) / 2 - expanded[0]
    center_y = (box[1] + box[3]) / 2 - expanded[1]
    components = []
    for label_id in range(1, count + 1):
        ys, xs = np.where(labels == label_id)
        area = len(xs)
        if area < max(25, width * height * 0.00035):
            continue
        left, right = int(xs.min()), int(xs.max()) + 1
        top, bottom = int(ys.min()), int(ys.max()) + 1
        component_width = right - left
        component_height = bottom - top
        if component_width > width * 0.86 and component_height < height * 0.025:
            continue
        if component_height > height * 0.86 and component_width < width * 0.025:
            continue
        if component_width > width * 0.84 and component_height > height * 0.84:
            fill_ratio = area / (component_width * component_height)
            if fill_ratio < 0.12:
                continue
        component_center_x = float(xs.mean())
        component_center_y = float(ys.mean())
        distance = np.hypot(
            (component_center_x - center_x) / width,
            (component_center_y - center_y) / height,
        )
        score = area / (1 + distance * 3.5)
        components.append(
            (
                score,
                area,
                left,
                top,
                right,
                bottom,
                component_center_x,
                component_center_y,
                label_id,
            )
        )

    if components:
        main = max(components, key=lambda item: item[0])
        main_left, main_top, main_right, main_bottom = main[2:6]
        left = main_left
        top = main_top
        right = main_right
        bottom = main_bottom
        pad_x = max(6, round((right - left) * 0.055))
        pad_y = max(6, round((bottom - top) * 0.055))
        left = max(0, left - pad_x)
        top = max(0, top - pad_y)
        right = min(width, right + pad_x)
        bottom = min(height, bottom + pad_y)
        main_mask = labels == main[8]
        main_mask = ndimage.binary_fill_holes(main_mask)
        main_mask = ndimage.binary_dilation(main_mask, iterations=2)
        clean_pixels = np.empty_like(pixels)
        clean_pixels[:] = np.asarray(background, dtype=np.uint8)
        clean_pixels[main_mask] = pixels[main_mask]
        clean_cell = Image.fromarray(clean_pixels, "RGB")
        product = clean_cell.crop((left, top, right, bottom))
    else:
        product = sheet.crop(box)

    max_sizes = {
        "hat": (410, 350),
        "top": (410, 425),
        "outer": (410, 440),
        "bottom": (370, 445),
        "dress": (390, 445),
    }
    max_width, max_height = max_sizes.get(category, (410, 430))
    scale = min(max_width / product.width, max_height / product.height)
    target = (
        max(1, round(product.width * scale)),
        max(1, round(product.height * scale)),
    )
    product = product.resize(target, Image.Resampling.LANCZOS)
    tile = Image.new("RGB", (512, 512), background)
    tile.paste(product, ((512 - target[0]) // 2, (512 - target[1]) // 2))
    return tile


def shoe_catalog_tile(sheet, box):
    """Extract a complete shoe from the special 4-column, 2-row sheets."""
    cell = sheet.crop(box)
    width, height = cell.size
    patch_size = max(6, round(min(width, height) * 0.07))
    margin = max(7, round(min(width, height) * 0.06))
    patches = []
    for left, top in (
        (margin, margin),
        (width - margin - patch_size, margin),
        (margin, height - margin - patch_size),
        (width - margin - patch_size, height - margin - patch_size),
    ):
        patches.append(cell.crop((left, top, left + patch_size, top + patch_size)))
    strip = Image.new("RGB", (patch_size * 4, patch_size))
    for index, patch in enumerate(patches):
        strip.paste(patch, (index * patch_size, 0))
    background = tuple(round(value) for value in ImageStat.Stat(strip).median)

    pixels = np.asarray(cell)
    delta = pixels.astype(np.int32) - np.asarray(background, dtype=np.int32)
    foreground = np.sqrt(np.sum(delta * delta, axis=2)) > 11
    border = max(3, round(min(width, height) * 0.012))
    foreground[:border, :] = False
    foreground[-border:, :] = False
    foreground[:, :border] = False
    foreground[:, -border:] = False
    connected = ndimage.binary_closing(foreground, iterations=2)
    connected = ndimage.binary_dilation(connected, iterations=1)
    labels, count = ndimage.label(connected)
    components = []
    for label_id in range(1, count + 1):
        ys, xs = np.where(labels == label_id)
        if len(xs) < max(30, width * height * 0.0004):
            continue
        left, right = int(xs.min()), int(xs.max()) + 1
        top, bottom = int(ys.min()), int(ys.max()) + 1
        component_width = right - left
        component_height = bottom - top
        if component_width > width * 0.85 and component_height < height * 0.025:
            continue
        if component_height > height * 0.85 and component_width < width * 0.025:
            continue
        components.append((len(xs), left, top, right, bottom))

    if components:
        largest = max(item[0] for item in components)
        kept = [item for item in components if item[0] >= largest * 0.018]
        left = min(item[1] for item in kept)
        top = min(item[2] for item in kept)
        right = max(item[3] for item in kept)
        bottom = max(item[4] for item in kept)
        pad_x = max(7, round((right - left) * 0.055))
        pad_y = max(7, round((bottom - top) * 0.09))
        left = max(0, left - pad_x)
        top = max(0, top - pad_y)
        right = min(width, right + pad_x)
        bottom = min(height, bottom + pad_y)
        product = cell.crop((left, top, right, bottom))
    else:
        product = cell

    scale = min(448 / product.width, 400 / product.height)
    target = (
        max(1, round(product.width * scale)),
        max(1, round(product.height * scale)),
    )
    product = product.resize(target, Image.Resampling.LANCZOS)
    tile = Image.new("RGB", (512, 512), background)
    tile.paste(product, ((512 - target[0]) // 2, (512 - target[1]) // 2))
    return tile

for batch in range(5):
    sheet = Image.open(SHEETS / f"{color_key}_{batch + 1:02}.png").convert("RGB")
    for cell in range(16):
        index = batch * 16 + cell
        if index >= len(STYLES):
            break
        row, column = divmod(cell, 4)
        vertical_divisions = 3 if batch == 4 else 4
        box = (
            round(column * sheet.width / 4), round(row * sheet.height / vertical_divisions),
            round((column + 1) * sheet.width / 4),
            round((row + 1) * sheet.height / vertical_divisions),
        )
        style_id, name, category, material = STYLES[index]
        filename = f"{style_id}_{color_key}_{material}.webp"
        tile = (
            shoe_catalog_tile(sheet, box)
            if batch == 4
            else garment_catalog_tile(sheet, box, category)
        )
        tile.save(OUTPUT / filename, "WEBP", quality=87, method=6)
        items.append({
            "id": f"{style_id}_{color_key}", "name": f"{color_name}{name}",
            "style": name, "styleId": style_id, "color": color_name,
            "colorId": color_key, "material": material, "category": category,
            "asset": f"assets/catalog/{filename}",
        })

manifest = OUTPUT / f"manifest_{color_key}.json"
manifest.write_text(json.dumps(items, ensure_ascii=False, indent=2), encoding="utf-8")
print(color_key, len(items), sum((OUTPUT / Path(item["asset"]).name).stat().st_size for item in items))
