"""Cuts the stone golem sprite sheet into game frames.

The sheet (assets/sprites/golem/source/golem_sheet.webp) is a generated image
on a light checkerboard without alpha. This script removes the background,
cuts each animation's frames by the column gaps found per row, aligns every
golem frame on its body centre and feet, scales it up smoothly and writes
assets/sprites/golem/<animation>_f<N>.png plus manifest.json.

Run: python -I scripts/slice_golem_sheet.py
"""
import json
import os
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCE = os.path.join(ROOT, "assets", "sprites", "golem", "source", "golem_sheet.webp")
OUT = os.path.join(ROOT, "assets", "sprites", "golem")
SCALE = 1.9

# Row bands (y ranges) of the sheet, top to bottom.
BANDS = [(4, 59), (68, 114), (125, 179), (188, 245), (255, 309), (312, 369), (377, 420), (423, 465), (469, 518), (518, 574)]

# animation: (band, [segment index or explicit (x0, x1)], anchored) - anchored frames are the golem
# (aligned on body centre and feet); effects are centred as they are.
ANIMATIONS = {
    "cleave": (0, list(range(12)), True),
    "idle": (1, [0, 1, 2, 3, 4], True),
    "boulder": (1, [6, 7, 8, 9, 10, 11, 12], False),
    "channel": (2, list(range(10)), True),
    "quake": (3, list(range(7)), True),
    "quake_burst": (3, [7], False),
    "barrage": (4, list(range(10)), True),
    "rock": (4, [10, 11], False),
    "rage": (5, list(range(6)), True),
    "thorns": (5, [6, 7, 8, 9, 10, 11], False),
    "throw": (6, [(19, 80)], True),
    "unarmed": (6, [1], True),
    "catch": (6, [9], True),
    "walk": (7, list(range(7)), True),
    "death": (8, list(range(9)), True),
    "spike": (9, [0], False),
    "slash": (9, [1], False),
    "axe": (9, [2, 3], False),
    "axe_spin": (6, [8], False),
    "burst": (9, [4], False),
    "blast": (9, [-5, -4, -3, -2, -1], False),
}


def is_background(pixel):
    return min(pixel) > 215 and max(pixel) - min(pixel) < 18


def segments(image, band):
    width = image.width
    pixels = image.load()
    columns = [any(not is_background(pixels[x, y]) for y in range(*band)) for x in range(width)]
    found, start, last = [], None, 0
    for x, filled in enumerate(columns):
        if filled:
            if start is None:
                start = x
            last = x
        elif start is not None and x - last > 5:
            found.append((start, last + 1))
            start = None
    if start is not None:
        found.append((start, last + 1))
    # Specks narrower than 4 px are compression noise, not frames.
    return [s for s in found if s[1] - s[0] >= 4]


def cut(image, band, segment):
    box = (segment[0], band[0], segment[1], band[1])
    frame = image.crop(box).convert("RGBA")
    pixels = frame.load()
    for y in range(frame.height):
        for x in range(frame.width):
            r, g, b, _ = pixels[x, y]
            if is_background((r, g, b)):
                pixels[x, y] = (0, 0, 0, 0)
    # Remove the pale fringe left by the old background around the outline.
    for _ in range(2):
        clear = []
        for y in range(frame.height):
            for x in range(frame.width):
                r, g, b, a = pixels[x, y]
                if a and min(r, g, b) > 185 and max(r, g, b) - min(r, g, b) < 30:
                    near = [(x + dx, y + dy) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))]
                    if any(not (0 <= nx < frame.width and 0 <= ny < frame.height) or pixels[nx, ny][3] == 0 for nx, ny in near):
                        clear.append((x, y))
        for x, y in clear:
            pixels[x, y] = (0, 0, 0, 0)
    bounds = frame.getbbox()
    return frame.crop(bounds) if bounds else frame


def body_centre(frame):
    """Horizontal centre of the dark stone body, ignoring bright effects."""
    pixels = frame.load()
    total, count = 0, 0
    for y in range(frame.height):
        for x in range(frame.width):
            r, g, b, a = pixels[x, y]
            if a and (r + g + b) / 3 < 110:
                total += x
                count += 1
    return total / count if count else frame.width / 2


def main():
    image = Image.open(SOURCE).convert("RGB")
    manifest = {}
    cache = {}
    for name, (band_index, indices, anchored) in ANIMATIONS.items():
        band = BANDS[band_index]
        if band_index not in cache:
            cache[band_index] = segments(image, band)
        found = cache[band_index]
        frames = [cut(image, band, i if isinstance(i, tuple) else found[i]) for i in indices]
        if anchored:
            centres = [body_centre(f) for f in frames]
            half = max(max(c, f.width - c) for f, c in zip(frames, centres))
            height = max(f.height for f in frames)
            canvas = (int(half * 2) + 2, height)
            placed = []
            for frame, centre in zip(frames, centres):
                sheet = Image.new("RGBA", canvas, (0, 0, 0, 0))
                sheet.paste(frame, (int(round(canvas[0] / 2 - centre)), canvas[1] - frame.height), frame)
                placed.append(sheet)
        else:
            canvas = (max(f.width for f in frames), max(f.height for f in frames))
            placed = []
            for frame in frames:
                sheet = Image.new("RGBA", canvas, (0, 0, 0, 0))
                sheet.paste(frame, ((canvas[0] - frame.width) // 2, (canvas[1] - frame.height) // 2), frame)
                placed.append(sheet)
        size = (round(canvas[0] * SCALE), round(canvas[1] * SCALE))
        for i, frame in enumerate(placed):
            frame.resize(size, Image.LANCZOS).save(os.path.join(OUT, "%s_f%d.png" % (name, i)))
        manifest[name] = {"frames": len(placed), "size": list(size), "anchored": anchored}
    with open(os.path.join(OUT, "manifest.json"), "w", encoding="utf-8") as handle:
        json.dump(manifest, handle, indent=1)
    print("sliced", {k: v["frames"] for k, v in manifest.items()})


if __name__ == "__main__":
    main()
