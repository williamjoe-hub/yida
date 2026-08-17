from collections import deque
from pathlib import Path
from PIL import Image, ImageFilter
import sys


def remove_edge_background(source: str, target: str) -> None:
    image = Image.open(source).convert("RGBA")
    rgb = image.convert("RGB")
    width, height = image.size
    pixels = rgb.load()

    corners = [pixels[2, 2], pixels[width - 3, 2], pixels[2, height - 3], pixels[width - 3, height - 3]]
    key = tuple(sum(channel[i] for channel in corners) // len(corners) for i in range(3))

    def distance(color):
        return sum((color[i] - key[i]) ** 2 for i in range(3)) ** 0.5

    # Only background-like pixels connected to the canvas edge can be removed.
    # This preserves dark hair, pupils and clothing even when the backdrop is black.
    threshold = 72
    visited = bytearray(width * height)
    queue = deque()
    for x in range(width):
        queue.append((x, 0)); queue.append((x, height - 1))
    for y in range(height):
        queue.append((0, y)); queue.append((width - 1, y))

    while queue:
        x, y = queue.popleft()
        index = y * width + x
        if visited[index] or distance(pixels[x, y]) > threshold:
            continue
        visited[index] = 255
        if x: queue.append((x - 1, y))
        if x + 1 < width: queue.append((x + 1, y))
        if y: queue.append((x, y - 1))
        if y + 1 < height: queue.append((x, y + 1))

    mask = Image.frombytes("L", (width, height), bytes(255 - value for value in visited))
    mask = mask.filter(ImageFilter.GaussianBlur(1.1))
    output = image.copy()
    output.putalpha(mask)
    output.save(target)
    print(f"saved {target}; sampled edge key={key}")


if __name__ == "__main__":
    remove_edge_background(sys.argv[1], sys.argv[2])
