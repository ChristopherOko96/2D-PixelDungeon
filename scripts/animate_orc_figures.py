"""Builds animation frames for the goblin and orc figures.

The source art has one standing figure per creature, so this script derives
pixel frames from it (assets/sprites/orcs/<name>.png):
  idle   4 frames  the upper body breathes (moves down a pixel and back),
  walk   4 frames  the legs step in turn (one leg lifted, the body bobbing),
  windup 2 frames  the figure leans back, gathering itself,
  strike 2 frames  it lunges forward and settles.
Frames keep the source size so the feet stay on the same line. Output:
assets/sprites/orcs/frames/<name>_<animation>_f<N>.png and frames.json.

Run after slice_orc_sheets.py: python -I scripts/animate_orc_figures.py
The demon mini-bosses use the same frames: pass their folder name,
python -I scripts/animate_orc_figures.py nebenbosse
"""
import json
import os
import sys
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FOLDER = os.path.join(ROOT, "assets", "sprites", sys.argv[1] if len(sys.argv) > 1 else "orcs")
OUT = os.path.join(FOLDER, "frames")
SKIP = {"trap"}
LEG_SHARE = 0.3


def blank(image):
    return Image.new("RGBA", image.size, (0, 0, 0, 0))


def legs_split(image):
    """Row where the legs begin and the column between the two feet."""
    pixels = image.load()
    top = int(image.height * (1.0 - LEG_SHARE))
    total, count = 0, 0
    for y in range(top, image.height):
        for x in range(image.width):
            if pixels[x, y][3]:
                total += x
                count += 1
    return top, int(total / count) if count else image.width // 2


def shift_region(source, target, box, dx, dy):
    region = source.crop(box)
    target.alpha_composite(region, (box[0] + dx, box[1] + dy))


def breathe(image, drop):
    """Upper body lowered by `drop` pixels over unchanged legs."""
    top, _ = legs_split(image)
    frame = blank(image)
    shift_region(image, frame, (0, top, image.width, image.height), 0, 0)
    shift_region(image, frame, (0, 0, image.width, top), 0, drop)
    return frame


def step(image, lifted, bob):
    """One leg (left or right of the split) lifted, the body bobbing up."""
    top, middle = legs_split(image)
    frame = blank(image)
    left = (0, top, middle, image.height)
    right = (middle, top, image.width, image.height)
    lift = max(2, round(image.height * 0.07))
    # The lifted foot leaves its bottom rows (sole and ground outline) behind,
    # so no line hangs under it; the body overlaps the legs by `bob` rows so no
    # seam opens when it rises.
    if lifted == "left":
        shift_region(image, frame, (left[0], left[1], left[2], left[3] - 2), -1, -lift)
        shift_region(image, frame, right, 0, 0)
    else:
        shift_region(image, frame, left, 0, 0)
        shift_region(image, frame, (right[0], right[1], right[2], right[3] - 2), 1, -lift)
    shift_region(image, frame, (0, 0, image.width, min(image.height, top + bob)), 0, -bob)
    return frame


def lean(image, amount):
    """Shears the figure around its feet: negative leans back, positive forward."""
    height = image.height
    pad = abs(int(amount)) + 1
    wide = Image.new("RGBA", (image.width + pad * 2, height), (0, 0, 0, 0))
    wide.alpha_composite(image, (pad, 0))
    # x_source = x + shear * (height - y): the top moves most, the feet stay.
    shear = -amount / max(1, height)
    sheared = wide.transform(wide.size, Image.AFFINE, (1, shear, -shear * height, 0, 1, 0), resample=Image.NEAREST)
    return sheared.crop((pad, 0, pad + image.width, height))


def main():
    os.makedirs(OUT, exist_ok=True)
    manifest = json.load(open(os.path.join(FOLDER, "manifest.json"), encoding="utf-8"))
    frames = {}
    for name in manifest:
        if name in SKIP:
            continue
        image = Image.open(os.path.join(FOLDER, name + ".png")).convert("RGBA")
        # Movements scale with the figure: a warlord sways more than a goblin.
        h = image.height
        drop = max(1, round(h * 0.03))
        bob = max(1, round(h * 0.035))
        sets = {
            "idle": [image, breathe(image, max(1, drop // 2)), breathe(image, drop), breathe(image, max(1, drop // 2))],
            "walk": [step(image, "left", bob), breathe(image, max(1, drop // 2)), step(image, "right", bob), breathe(image, max(1, drop // 2))],
            "windup": [lean(image, -round(h * 0.06)), lean(image, -round(h * 0.11))],
            "strike": [lean(image, round(h * 0.14)), lean(image, round(h * 0.05))],
        }
        frames[name] = {}
        for animation, images in sets.items():
            for i, frame in enumerate(images):
                frame.save(os.path.join(OUT, "%s_%s_f%d.png" % (name, animation, i)))
            frames[name][animation] = len(images)
    with open(os.path.join(OUT, "frames.json"), "w", encoding="utf-8") as handle:
        json.dump(frames, handle, indent=1)
    print("animated", len(frames))


if __name__ == "__main__":
    main()
