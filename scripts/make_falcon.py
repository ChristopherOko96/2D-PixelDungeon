# The beast master's falcon (user wish 30.10.2026). The 0x72 archive and its
# Enchanted Forest pack have no bird, so it is drawn here in their style:
# 32x32 frames like the forest wolf and bear, a dark ink outline, flat colour
# steps lit from the top, facing right. A slate-backed falcon with a cream,
# streaked breast, the dark "moustache" stripe under the eye, a yellow beak
# and talons. It always flies: idle and walk are both wing beats (up, level,
# down, level); the game draws it above its shadow.
# Output: assets/sprites/companions/falcon_<idle|walk>_f<0-3>.png
# Run: python -X utf8 scripts/make_falcon.py
import os
from PIL import Image

OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'sprites', 'companions')
INK = (28, 17, 23, 255)
SLATE = (96, 90, 104, 255)
SLATE_LIGHT = (136, 130, 142, 255)
WING = (74, 60, 66, 255)
WING_DARK = (48, 38, 44, 255)
WING_EDGE = (160, 146, 140, 255)
CREAM = (234, 220, 188, 255)
STREAK = (150, 118, 96, 255)
BEAK = (240, 192, 72, 255)
BEAK_TIP = (60, 52, 50, 255)
EYE = (20, 14, 16, 255)


def inside(poly, x, y):
    hit = False
    j = len(poly) - 1
    for i in range(len(poly)):
        xi, yi = poly[i]
        xj, yj = poly[j]
        if (yi > y) != (yj > y) and x < (xj - xi) * (y - yi) / (yj - yi) + xi:
            hit = not hit
        j = i
    return hit


def fill(px, poly, color_at):
    for y in range(32):
        for x in range(32):
            if inside(poly, x + 0.5, y + 0.5):
                px[(x, y)] = color_at(x, y)


def ellipse(px, cx, cy, rx, ry, color_at):
    for y in range(32):
        for x in range(32):
            nx, ny = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
            if nx * nx + ny * ny <= 1.0:
                px[(x, y)] = color_at(x, y)


def outline(px):
    out = dict(px)
    for (x, y) in px:
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            q = (x + dx, y + dy)
            if q not in px and 0 <= q[0] < 32 and 0 <= q[1] < 32:
                out[q] = INK
    return out


# wing tip and trailing point per beat; the near wing, shoulder at (15, 16)
BEATS = {
    'up': ((5, 0), (1, 8)),
    'level': ((0, 11), (5, 18)),
    'down': ((7, 31), (2, 24)),
}


def wing(px, beat, far=False):
    tip, trail = BEATS[beat]
    # a long pointed falcon wing: broad at the arm, narrow primaries
    poly = [(12, 15), (21, 15), tip, trail] if beat != 'down' else [(12, 17), (21, 17), tip, trail]
    if far:
        poly = [(x + 3, y - 1) for (x, y) in poly]

    def tone(x, y):
        if far:
            return WING_DARK
        dist = abs(x - tip[0]) + abs(y - tip[1])
        if dist < 9:
            return WING_DARK if (x + y) % 2 == 0 or dist < 5 else WING
        if (y <= 15 and beat != 'down') and (x + y) % 3 == 0:
            return WING_EDGE
        return WING
    fill(px, poly, tone)
    # ragged primary tips along the trailing edge
    for key in [k for k in px if px[k] in (WING_DARK,) and abs(k[0] - tip[0]) + abs(k[1] - tip[1]) < 9 and (k[0] * 2 + k[1]) % 5 == 0]:
        if not far: del px[key]


def frame(beat, bob):
    px = {}
    if beat == 'up':
        wing(px, beat, far=True)
    cy = 18 + bob
    # tail: a fan with dark bands
    fill(px, [(10, cy - 1), (3, cy - 3), (2, cy + 2), (10, cy + 2)], lambda x, y: WING_DARK if x % 3 == 0 else SLATE)
    # body: slate back, cream streaked breast
    ellipse(px, 16, cy, 7.5, 4.2, lambda x, y: (SLATE_LIGHT if y < cy - 2 else SLATE) if y < cy else (STREAK if (x + y) % 4 == 0 and y > cy else CREAM))
    # head
    hx, hy = 23, cy - 3
    # dark hood over the crown and nape, a white cheek
    ellipse(px, hx, hy, 3.8, 3.5, lambda x, y: WING_DARK if y < hy or x < hx - 1 else CREAM)
    px[(hx + 1, hy + 1)] = WING_DARK  # the moustache stripe runs down from the eye
    px[(hx + 1, hy + 2)] = WING_DARK
    px[(hx + 1, hy - 1)] = EYE
    px[(hx, hy - 1)] = BEAK  # yellow eye ring
    px[(hx + 2, hy - 1)] = BEAK
    # hooked beak
    px[(hx + 3, hy)] = BEAK
    px[(hx + 4, hy)] = BEAK
    px[(hx + 4, hy + 1)] = BEAK_TIP
    # talons tucked under the body
    for x in (14, 17):
        px[(x, cy + 4)] = BEAK
        px[(x + 1, cy + 5)] = BEAK
    wing(px, beat)
    return px


def save(px, name):
    im = Image.new('RGBA', (32, 32), (0, 0, 0, 0))
    for (x, y), c in outline(px).items():
        if 0 <= x < 32 and 0 <= y < 32:
            im.putpixel((x, y), c)
    im.save(os.path.join(OUT, name))


def main():
    os.makedirs(OUT, exist_ok=True)
    cycle = [('up', 0), ('level', 0), ('down', 1), ('level', 1)]
    for i, (beat, bob) in enumerate(cycle):
        save(frame(beat, bob), 'falcon_walk_f%d.png' % i)
    # idle: the same beats, the body rising on the down stroke a little less
    for i, (beat, bob) in enumerate([('level', 0), ('down', 0), ('level', 1), ('up', 1)]):
        save(frame(beat, bob), 'falcon_idle_f%d.png' % i)
    print('ok')


main()
