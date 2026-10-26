"""Cuts the infernal monster and boss sheets into game frames.

Both sheets are generated images on a dark background without alpha
(assets/sprites/infernal/source/). For every frame this script removes the
background by flood fill from the frame border (so black mouths and eyes inside
a creature stay), aligns creature frames on the centre of their feet, scales
them, hardens the alpha for crisp pixels and adds a 1 px dark outline. It
writes assets/sprites/infernal/<creature>/<animation>_f<N>.png and
assets/sprites/infernal/manifest.json.

Run: python -I scripts/slice_infernal_sheets.py
"""
import json
import os
from collections import deque
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCE = os.path.join(ROOT, "assets", "sprites", "infernal", "source")
OUT = os.path.join(ROOT, "assets", "sprites", "infernal")
OUTLINE = (14, 8, 16, 255)

SHEETS = {
    "monsters_sheet.webp": {
        "bands": [(18, 85), (100, 170), (185, 245), (250, 328), (330, 402), (403, 474), (474, 536), (537, 606)],
        "gap": 5, "threshold": 40, "scale": 0.8,
        # creature: {animation: (band, [segments], anchored)}
        "creatures": {
            "glutling": {"idle": (0, [0, 1, 2, 3, 4], True), "dash": (0, [5], True), "attack": (0, [6], True), "hurt": (0, [8], True), "death": (0, [9], True), "fire_patch": (0, [7], False)},
            "schattling": {"idle": (1, [0, 1, 2, 3, 4], True), "dash": (1, [5], True), "attack": (1, [6], True), "hurt": (1, [9], True), "death": (1, [10], True), "void_cloud": (1, [7], False), "void_orb": (1, [8], False)},
            "funkenball": {"idle": (2, [0, 1, 2, 3, 4], True), "attack": (2, [5], True), "beam": (2, [6], True), "hurt": (2, [7], True), "death": (2, [8], True)},
            "blutqualle": {"idle": (3, [0, 1, 2, 3, 4, 5, 6], True), "hurt": (3, [9], True), "death": (3, [10], True), "blood_pillar": (3, [7], False), "blood_splash": (3, [8], False)},
            "stachelwaechter": {"idle": (4, [0, 1, 2, 3, 4], True), "claw": (4, [5], True), "attack": (4, [6], True), "charge": (4, [7], True), "hurt": (4, [8], True), "death": (4, [9], True)},
            "leerenpriester": {"idle": (5, [0, 1, 2, 3], True), "attack": (5, [4, 5], True), "hurt": (5, [8], True), "death": (5, [9], True), "void_circle": (5, [6], False)},
            "krabbenteufel": {"idle": (6, [0, 1, 2, 3], True), "attack": (6, [4, 5], True), "hurt": (6, [8], True), "death": (6, [9], True), "spikes": (6, [7], False)},
            "fackelteufel": {"idle": (7, [0, 1, 2, 3], True), "attack": (7, [4, 5], True), "hurt": (7, [9], True), "death": (7, [10], True), "fireball": (7, [6], False), "fire_ring": (7, [7], False), "flame_pillar": (7, [8], False)},
        },
    },
    "boss_sheet.webp": {
        "bands": [(3, 103), (108, 199), (204, 288), (293, 376), (382, 464), (469, 550), (555, 635), (640, 721), (726, 806), (811, 871), (876, 942)],
        "gap": 8, "threshold": 45, "scale": 1.0,
        "creatures": {
            "molgrax": {
                "idle": (0, [0, 1, 2, 3, 4], True), "walk": (1, list(range(10)), True), "swipe": (3, list(range(7)), True),
                "slam": (4, list(range(10)), True), "throw": (5, [0, 1, 2, 3, 4, 5], True), "fireball": (5, [8], False),
                "void": (6, list(range(11)), True), "eruption": (7, list(range(8)), True), "lava_wave": (7, [8], False),
                "rage": (8, list(range(8)), True), "stagger": (9, list(range(8)), True), "death": (10, list(range(9)), True),
            },
        },
    },
}


def bright(pixel, threshold):
    return max(pixel) >= threshold


def segments(image, band, gap, threshold):
    pixels = image.load()
    columns = [sum(1 for y in range(*band) if bright(pixels[x, y], threshold)) > 1 for x in range(image.width)]
    found, start, last = [], None, 0
    for x, filled in enumerate(columns):
        if filled:
            if start is None:
                start = x
            last = x
        elif start is not None and x - last > gap:
            found.append((start, last + 1))
            start = None
    if start is not None:
        found.append((start, last + 1))
    return [s for s in found if s[1] - s[0] >= 6]


def cut(image, band, segment):
    """Crops a frame with a margin and clears the background reachable from its border."""
    box = (max(0, segment[0] - 3), band[0], min(image.width, segment[1] + 3), band[1])
    frame = image.crop(box).convert("RGBA")
    pixels = frame.load()
    width, height = frame.size
    seen = set()
    queue = deque()
    for x in range(width):
        queue.extend([(x, 0), (x, height - 1)])
    for y in range(height):
        queue.extend([(0, y), (width - 1, y)])
    while queue:
        x, y = queue.popleft()
        if (x, y) in seen or not (0 <= x < width and 0 <= y < height):
            continue
        seen.add((x, y))
        r, g, b, _ = pixels[x, y]
        if max(r, g, b) > 34:
            continue
        pixels[x, y] = (0, 0, 0, 0)
        queue.extend([(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)])
    bounds = frame.getbbox()
    return frame.crop(bounds) if bounds else frame


def feet_centre(frame):
    pixels = frame.load()
    top = int(frame.height * 0.6)
    total, count = 0, 0
    for y in range(top, frame.height):
        for x in range(frame.width):
            if pixels[x, y][3]:
                total += x
                count += 1
    return total / count if count else frame.width / 2


def finish(frame, scale):
    size = (max(1, round(frame.width * scale)), max(1, round(frame.height * scale)))
    frame = frame.resize(size, Image.LANCZOS)
    pixels = frame.load()
    for y in range(frame.height):
        for x in range(frame.width):
            r, g, b, a = pixels[x, y]
            pixels[x, y] = (r, g, b, 255) if a >= 110 else (0, 0, 0, 0)
    outlined = frame.copy()
    target = outlined.load()
    for y in range(frame.height):
        for x in range(frame.width):
            if pixels[x, y][3]:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < frame.width and 0 <= ny < frame.height and pixels[nx, ny][3]:
                    target[x, y] = OUTLINE
                    break
    return outlined


def main():
    manifest = {}
    for sheet_name, sheet in SHEETS.items():
        image = Image.open(os.path.join(SOURCE, sheet_name)).convert("RGB")
        found = {}
        for creature, animations in sheet["creatures"].items():
            folder = os.path.join(OUT, creature)
            os.makedirs(folder, exist_ok=True)
            manifest[creature] = {}
            for animation, (band_index, indices, anchored) in animations.items():
                band = sheet["bands"][band_index]
                if band_index not in found:
                    found[band_index] = segments(image, band, sheet["gap"], sheet["threshold"])
                frames = [cut(image, band, found[band_index][i]) for i in indices]
                if anchored:
                    centres = [feet_centre(f) for f in frames]
                    half = max(max(c, f.width - c) for f, c in zip(frames, centres))
                    canvas = (int(half * 2) + 2, max(f.height for f in frames))
                    offsets = [(int(round(canvas[0] / 2 - c)), canvas[1] - f.height) for f, c in zip(frames, centres)]
                else:
                    canvas = (max(f.width for f in frames), max(f.height for f in frames))
                    offsets = [((canvas[0] - f.width) // 2, (canvas[1] - f.height) // 2) for f in frames]
                for i, (frame, offset) in enumerate(zip(frames, offsets)):
                    sheet_frame = Image.new("RGBA", canvas, (0, 0, 0, 0))
                    sheet_frame.paste(frame, offset, frame)
                    final = finish(sheet_frame, sheet["scale"])
                    final.save(os.path.join(folder, "%s_f%d.png" % (animation, i)))
                manifest[creature][animation] = {"frames": len(frames), "size": [final.width, final.height]}
    with open(os.path.join(OUT, "manifest.json"), "w", encoding="utf-8") as handle:
        json.dump(manifest, handle, indent=1)
    print("sliced", {c: len(a) for c, a in manifest.items()})


if __name__ == "__main__":
    main()
