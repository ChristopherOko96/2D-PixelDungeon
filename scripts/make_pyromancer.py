# The fire mage's own figure after the user's concept sheet (30.10.2026),
# drawn in the 0x72 hero format: 16x28 frames, #222222 outline, flat colour
# steps, 4 idle + 4 run frames and a hit frame, so it drops in where the
# archive's wizzard_m stood. A red hood with a pointed tip and a shadowed face
# with glowing eyes, a black robe with gold trim and a gold clasp, embers
# flickering at the hem.
# Output: assets/sprites/0x72/custom_pyromancer_<idle|run|hit>_anim_f<n>.png
# (custom_*: drawn for this game, not part of the 0x72 archive)
# Run: python -X utf8 scripts/make_pyromancer.py
import os
from PIL import Image

OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'sprites', '0x72')
PAL = {'a': (0x22, 0x22, 0x22), 'R': (0xa8, 0x28, 0x1c), 'r': (0x6a, 0x1a, 0x1a), 'o': (0xe0, 0x5a, 0x2a),
       'k': (0x2a, 0x1a, 0x1e), 'K': (0x46, 0x30, 0x34), 'g': (0xe0, 0xae, 0x4c), 'G': (0xa8, 0x7a, 0x30),
       's': (0x12, 0x0a, 0x0c), 'y': (0xff, 0xd0, 0x60), 'f': (0xff, 0xe0, 0x80), 'F': (0xff, 0x8a, 0x2a)}

BODY = [
    "......aaa.......",
    ".....aRRRa......",
    "....aRoRRRa.....",
    "....aRoRRRRa....",
    "...aRRRRRRRRa...",
    "...aRRRaaaaRa...",
    "...aRRasssssa...",
    "..aRRRasyssya...",
    "..arRRasssssa...",
    "..akrRRaaaaRa...",
    ".agkkRRRRRRkga..",
    ".agKkkRgRkkKga..",
    "..aKkkRgRkkKa...",
    "..akkkRgRkkka...",
    "..akKkRGRkKka...",
    "..akkRRgRRkka...",
    "..akkRRgRRkkka..",
    ".akkkRRgRRkkka..",
    ".akkRRRgRRRkka..",
]
HEM = [".aggggggggggga..", ".aRoRoRoRoRoRa.."]
FEET = {"stand": "..aKa....aKa....", "a": ".aKa......aKa...", "b": "...aKa..aKa....."}
TOP = 6  # first row of the hood


def frame(bob=0, lean=0, feet="stand", flames=0, hit=False):
    rows = ["." * 16 for _ in range(28)]
    for i, line in enumerate(BODY):
        y = TOP + i + bob
        shift = lean if i < 10 else 0
        line = (("." * shift) + line)[:16] if shift > 0 else line
        rows[y] = line
    rows[25] = HEM[0]
    rows[26] = HEM[1] if flames % 2 == 0 else HEM[1].replace("Ro", "oR")
    rows[27] = FEET[feet]
    im = Image.new('RGBA', (16, 28), (0, 0, 0, 0))
    for y, line in enumerate(rows):
        for x, c in enumerate(line):
            if c in PAL:
                col = PAL[c]
                if hit and c not in 'as': col = tuple(min(255, v + 90) for v in col)
                im.putpixel((x, y), col + (255,))
    # embers drifting up beside the robe, a different spot each frame
    for (x, y, c) in [[(1, 22, 'F'), (14, 18, 'f')], [(0, 19, 'f'), (14, 23, 'F')], [(1, 16, 'F'), (15, 20, 'f')], [(2, 24, 'f'), (14, 15, 'F')]][flames % 4]:
        if im.getpixel((x, y))[3] == 0: im.putpixel((x, y), PAL[c] + (255,))
    return im


def main():
    for f, bob in enumerate([0, 0, 1, 1]):
        frame(bob=bob, flames=f).save(os.path.join(OUT, 'custom_pyromancer_idle_anim_f%d.png' % f))
    for f, (lean, feet) in enumerate([(0, "stand"), (1, "a"), (0, "stand"), (1, "b")]):
        frame(bob=f % 2, lean=lean, feet=feet, flames=f + 1).save(os.path.join(OUT, 'custom_pyromancer_run_anim_f%d.png' % f))
    frame(hit=True).save(os.path.join(OUT, 'custom_pyromancer_hit_anim_f0.png'))
    print('ok')


main()
