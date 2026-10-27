"""Cuts the goblin and orc figures out of their two sheets.

The sheets (assets/sprites/orcs/source/) show one standing figure per creature
on a dark, slightly blue tiled floor. The background is removed by flood fill
from the image border over dark bluish pixels (figures have warm dark
outlines, so the fill stops there). The remaining pixels are grouped into
figures by connected areas, matched to names in reading order, scaled to their
game height and saved with a 1 px outline as assets/sprites/orcs/<name>.png,
listed in manifest.json.

Run: python -I scripts/slice_orc_sheets.py [--list]
"""
import json
import os
import sys
from collections import deque
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCE = os.path.join(ROOT, "assets", "sprites", "orcs", "source")
OUT = os.path.join(ROOT, "assets", "sprites", "orcs")
OUTLINE = (12, 10, 12, 255)

# Figures in reading order (top row left to right, then the next row) with
# their height in the game in pixels. "trap" is the bear trap lying beside
# the trapper; it becomes the trap hazard's sprite.
# Sheet A's floor shading and the figures' dark armour defeat automatic
# separation there, so its figure areas are given by hand (x0, y0, x1, y1).
BOXES = {
    "orcs_a.webp": [(60, 170, 305, 440), (350, 80, 580, 440), (620, 160, 890, 440), (915, 140, 1160, 440), (1235, 170, 1480, 440),
        (40, 780, 172, 845), (140, 600, 335, 845), (355, 500, 600, 845), (590, 520, 880, 845), (880, 490, 1150, 845), (1160, 395, 1660, 850)],
}

SHEETS = {
    "orcs_a.webp": [
        ("g_cutthroat", 40), ("g_spearman", 46), ("g_archer", 40), ("g_shieldbearer", 42), ("g_bomber", 40),
        ("trap", 16), ("g_trapper", 38), ("g_shaman", 46), ("g_captain", 44), ("o_brute", 54), ("o_warlord", 104),
    ],
    "orcs_b.webp": [
        ("g_skirmisher", 36), ("g_hunter", 38), ("g_phalanx", 40), ("g_flailer", 38),
        ("o_bonecaller", 56), ("o_berserker", 60), ("o_chieftain", 66), ("o_blackknight", 60),
    ],
}


def background(pixel, reference):
    r, g, b = pixel[:3]
    # The floor colour itself, with compression noise ...
    if abs(r - reference[0]) <= 9 and abs(g - reference[1]) <= 9 and abs(b - reference[2]) <= 9:
        return True
    # ... the near-black shade around the figures ...
    if max(r, g, b) < 30 and b >= r and max(r, g, b) - min(r, g, b) < 12:
        return True
    # ... and the bluish grid lines; figures have warm dark outlines.
    return max(r, g, b) < 62 and b >= r + 3 and b >= g + 2


def floor_colour(image):
    pixels = image.load()
    border = sorted(pixels[x, 2][:3] for x in range(0, image.width, 7))
    return border[len(border) // 2]


def clear_holes(image, reference, minimum=25):
    """Floor showing through gaps inside a figure (between arm and axe, say):
    enclosed patches of floor colour the border fill could not reach."""
    pixels = image.load()
    width, height = image.size
    seen = bytearray(width * height)
    for y0 in range(height):
        for x0 in range(width):
            if seen[y0 * width + x0] or not pixels[x0, y0][3] or not background(pixels[x0, y0], reference):
                continue
            queue = deque([(x0, y0)])
            seen[y0 * width + x0] = 1
            members = []
            while queue:
                x, y = queue.popleft()
                members.append((x, y))
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < width and 0 <= ny < height and not seen[ny * width + nx] and pixels[nx, ny][3] and background(pixels[nx, ny], reference):
                        seen[ny * width + nx] = 1
                        queue.append((nx, ny))
            if len(members) >= minimum:
                for x, y in members:
                    pixels[x, y] = (0, 0, 0, 0)


def clear_background(image, reference):
    pixels = image.load()
    width, height = image.size
    seen = bytearray(width * height)
    queue = deque()
    for x in range(width):
        queue.extend([(x, 0), (x, height - 1)])
    for y in range(height):
        queue.extend([(0, y), (width - 1, y)])
    while queue:
        x, y = queue.popleft()
        if not (0 <= x < width and 0 <= y < height) or seen[y * width + x]:
            continue
        seen[y * width + x] = 1
        if not background(pixels[x, y], reference):
            continue
        pixels[x, y] = (0, 0, 0, 0)
        queue.extend([(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)])


def figures(image, minimum=250, gap=6):
    """Bounding boxes of connected opaque areas, nearby pieces merged."""
    pixels = image.load()
    width, height = image.size
    seen = bytearray(width * height)
    boxes = []
    for y0 in range(height):
        for x0 in range(width):
            if seen[y0 * width + x0] or pixels[x0, y0][3] == 0:
                continue
            queue = deque([(x0, y0)])
            seen[y0 * width + x0] = 1
            count, left, top, right, bottom = 0, x0, y0, x0, y0
            while queue:
                x, y = queue.popleft()
                count += 1
                left, top, right, bottom = min(left, x), min(top, y), max(right, x), max(bottom, y)
                for dx in (-1, 0, 1):
                    for dy in (-1, 0, 1):
                        nx, ny = x + dx, y + dy
                        if 0 <= nx < width and 0 <= ny < height and not seen[ny * width + nx] and pixels[nx, ny][3]:
                            seen[ny * width + nx] = 1
                            queue.append((nx, ny))
            if count >= 40:
                boxes.append([left, top, right + 1, bottom + 1, count])
    merged = True
    while merged:
        merged = False
        for i in range(len(boxes)):
            for j in range(i + 1, len(boxes)):
                a, b = boxes[i], boxes[j]
                if a[0] - gap < b[2] and b[0] - gap < a[2] and a[1] - gap < b[3] and b[1] - gap < a[3]:
                    boxes[i] = [min(a[0], b[0]), min(a[1], b[1]), max(a[2], b[2]), max(a[3], b[3]), a[4] + b[4]]
                    del boxes[j]
                    merged = True
                    break
            if merged:
                break
    return [b for b in boxes if b[4] >= minimum]


def strong(pixel):
    r, g, b = pixel[:3]
    return max(r, g, b) - min(r, g, b) > 34 or max(r, g, b) > 95


def strong_boxes(image, gap=10, minimum=300):
    """Figure boxes from clearly coloured or bright pixels only: skin, metal and
    fire never appear in the floor, so its noise cannot chain figures together."""
    mask = image.copy()
    pixels = mask.load()
    for y in range(mask.height):
        for x in range(mask.width):
            if not strong(pixels[x, y]):
                pixels[x, y] = (0, 0, 0, 0)
    return figures(mask, minimum, gap)


def peel(image, rounds=8):
    """Removes dark grey floor bits still stuck to a figure's edge."""
    pixels = image.load()
    width, height = image.size
    for _ in range(rounds):
        clear = []
        for y in range(height):
            for x in range(width):
                r, g, b, a = pixels[x, y]
                if not a or max(r, g, b) >= 44 or max(r, g, b) - min(r, g, b) >= 14:
                    continue
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if not (0 <= nx < width and 0 <= ny < height) or pixels[nx, ny][3] == 0:
                        clear.append((x, y))
                        break
        for x, y in clear:
            pixels[x, y] = (0, 0, 0, 0)


def keep_figures(image, strong_needed=6):
    """Clears leftover floor specks: keeps only opaque areas that contain some
    clearly coloured or bright pixels (skin, metal, fire), which the dark grey
    floor never has."""
    pixels = image.load()
    width, height = image.size
    seen = bytearray(width * height)
    areas = []
    for y0 in range(height):
        for x0 in range(width):
            if seen[y0 * width + x0] or pixels[x0, y0][3] == 0:
                continue
            queue = deque([(x0, y0)])
            seen[y0 * width + x0] = 1
            members, strong = [], 0
            while queue:
                x, y = queue.popleft()
                members.append((x, y))
                r, g, b, _ = pixels[x, y]
                if max(r, g, b) - min(r, g, b) > 28 or max(r, g, b) > 80:
                    strong += 1
                for dx in (-1, 0, 1):
                    for dy in (-1, 0, 1):
                        nx, ny = x + dx, y + dy
                        if 0 <= nx < width and 0 <= ny < height and not seen[ny * width + nx] and pixels[nx, ny][3]:
                            seen[ny * width + nx] = 1
                            queue.append((nx, ny))
            areas.append((strong, members))
    # Keep the figure (and pieces of it like a raised weapon); drop floor bits
    # and the edges of neighbouring figures reaching into the box.
    largest = max((len(m) for _, m in areas), default=0)
    for strong, members in areas:
        if strong < strong_needed or len(members) < largest * 0.04:
            for x, y in members:
                pixels[x, y] = (0, 0, 0, 0)


def reading_order(boxes):
    boxes = sorted(boxes, key=lambda b: (b[1] + b[3]) / 2)
    rows, current = [], []
    for box in boxes:
        if current and (box[1] + box[3]) / 2 - (current[-1][1] + current[-1][3]) / 2 > 120:
            rows.append(current)
            current = []
        current.append(box)
    if current:
        rows.append(current)
    return [b for row in rows for b in sorted(row, key=lambda b: b[0])]


def finish(figure, target_height):
    scale = target_height / figure.height
    size = (max(1, round(figure.width * scale)), target_height)
    figure = figure.resize(size, Image.LANCZOS)
    pixels = figure.load()
    for y in range(figure.height):
        for x in range(figure.width):
            r, g, b, a = pixels[x, y]
            pixels[x, y] = (r, g, b, 255) if a >= 120 else (0, 0, 0, 0)
    padded = Image.new("RGBA", (figure.width + 2, figure.height + 2), (0, 0, 0, 0))
    padded.paste(figure, (1, 1), figure)
    out = padded.copy()
    source, target = padded.load(), out.load()
    for y in range(padded.height):
        for x in range(padded.width):
            if source[x, y][3]:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < padded.width and 0 <= ny < padded.height and source[nx, ny][3]:
                    target[x, y] = OUTLINE
                    break
    return out


def main():
    listing = "--list" in sys.argv
    manifest = {}
    for sheet_name, names in SHEETS.items():
        image = Image.open(os.path.join(SOURCE, sheet_name)).convert("RGBA")
        reference = floor_colour(image)
        clear_background(image, reference)
        clear_holes(image, reference)
        peel(image)
        boxes = [list(b) + [0] for b in BOXES[sheet_name]] if sheet_name in BOXES else reading_order(figures(image))
        if listing:
            print(sheet_name, len(boxes), [b[:4] for b in boxes])
            continue
        if len(boxes) != len(names):
            raise SystemExit("%s: found %d figures, expected %d: %s" % (sheet_name, len(boxes), len(names), [b[:4] for b in boxes]))
        for (name, height), box in zip(names, boxes):
            area = (max(0, box[0] - 4), max(0, box[1] - 4), min(image.width, box[2] + 4), min(image.height, box[3] + 4))
            figure = image.crop(area)
            keep_figures(figure)
            figure = figure.crop(figure.getbbox())
            out = finish(figure, height)
            out.save(os.path.join(OUT, name + ".png"))
            manifest[name] = {"size": [out.width, out.height]}
    if not listing:
        with open(os.path.join(OUT, "manifest.json"), "w", encoding="utf-8") as handle:
            json.dump(manifest, handle, indent=1)
        print("sliced", len(manifest))


if __name__ == "__main__":
    main()
