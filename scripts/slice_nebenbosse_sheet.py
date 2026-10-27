"""Cuts the four demon mini-bosses and the dungeon props out of their sheet.

The sheet (assets/sprites/nebenbosse/source/demons_props.png) shows floor
tiles, pillars, wall hangings, floor decoration, lava pools, a portal and,
in the bottom row, the four demon variants, all on one flat near-black
background. Because the props are dark stone themselves, only pixels close to
that background colour are removed (flood fill from the border), not every
dark pixel. Each figure area is given by hand (x0, y0, x1, y1), scaled to its
game height and saved with a 1 px outline:
  demons -> assets/sprites/nebenbosse/<name>.png  + manifest.json
  props  -> assets/sprites/props/<name>.png       + manifest.json

Run: python -I scripts/slice_nebenbosse_sheet.py
Then: python -I scripts/animate_orc_figures.py nebenbosse
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from slice_orc_sheets import finish, keep_figures  # noqa: E402
from collections import deque  # noqa: E402
from PIL import Image  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SHEET = os.path.join(ROOT, "assets", "sprites", "nebenbosse", "source", "demons_props.png")
DEMONS = os.path.join(ROOT, "assets", "sprites", "nebenbosse")
PROPS = os.path.join(ROOT, "assets", "sprites", "props")

# name: (box, game height in px, folder)
FIGURES = {
    # The four mini-bosses, bottom row.
    "n_axe": ((30, 700, 278, 905), 78, DEMONS),
    "n_hex": ((330, 700, 528, 902), 74, DEMONS),
    "n_crab": ((585, 708, 798, 895), 70, DEMONS),
    "n_wing": ((815, 708, 1045, 904), 82, DEMONS),
    # Wall hangings.
    "chains": ((44, 262, 260, 470), 60, PROPS),
    "cage": ((286, 260, 410, 468), 58, PROPS),
    "banner": ((1166, 508, 1272, 690), 52, PROPS),
    "cage_lit": ((1294, 508, 1392, 688), 52, PROPS),
    # Floor decoration.
    "rune_r": ((440, 296, 560, 466), 34, PROPS),
    "rune_s": ((575, 296, 695, 466), 34, PROPS),
    "rune_x": ((715, 296, 835, 466), 34, PROPS),
    "bones": ((866, 326, 1064, 456), 28, PROPS),
    "skulls": ((1078, 300, 1264, 460), 36, PROPS),
    "crystal": ((1290, 300, 1402, 462), 34, PROPS),
    "crystals": ((1420, 298, 1626, 460), 34, PROPS),
    "spikes": ((954, 560, 1138, 690), 30, PROPS),
    "totem": ((1404, 508, 1506, 690), 42, PROPS),
    "spire": ((1532, 508, 1626, 690), 40, PROPS),
    "altar": ((1172, 60, 1382, 262), 62, PROPS),
    "cauldron": ((1424, 60, 1630, 262), 54, PROPS),
    # Lava pools (the floor hazard) and the portal to the next floor.
    "lava_s": ((36, 548, 130, 620), 28, PROPS),
    "lava_m": ((158, 548, 278, 636), 34, PROPS),
    "lava_l": ((320, 548, 458, 636), 38, PROPS),
    "portal": ((488, 480, 698, 690), 92, PROPS),
}


def near_background(pixel, reference):
    r, g, b = pixel[:3]
    return abs(r - reference[0]) <= 12 and abs(g - reference[1]) <= 12 and abs(b - reference[2]) <= 12


def clear_from_border(image, reference):
    """Removes background pixels reachable from the crop's edge."""
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
        if not near_background(pixels[x, y], reference):
            continue
        pixels[x, y] = (0, 0, 0, 0)
        queue.extend([(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)])


def main():
    sheet = Image.open(SHEET).convert("RGBA")
    pixels = sheet.load()
    corner = sorted(pixels[x, 4][:3] for x in range(0, sheet.width, 9))
    reference = corner[len(corner) // 2]
    manifests = {DEMONS: {}, PROPS: {}}
    for name, (box, height, folder) in FIGURES.items():
        figure = sheet.crop(box)
        clear_from_border(figure, reference)
        keep_figures(figure, strong_needed=4)
        figure = figure.crop(figure.getbbox())
        out = finish(figure, height)
        out.save(os.path.join(folder, name + ".png"))
        manifests[folder][name] = {"size": [out.width, out.height]}
    for folder, manifest in manifests.items():
        with open(os.path.join(folder, "manifest.json"), "w", encoding="utf-8") as handle:
            json.dump(manifest, handle, indent=1)
    print("sliced", sum(len(m) for m in manifests.values()))


if __name__ == "__main__":
    main()
