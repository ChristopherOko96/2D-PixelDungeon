# The permanent companions that the 0x72 archive does not have, drawn in its
# style: the #222222 outline around the whole figure, flat colour steps lit
# from the top left, 4 idle and 4 walk frames like the archive's actors.
#   water_elemental: a swirling water spirit with a whirl for feet (16x22)
#   bone_warrior:    the archive's skeleton with an iron helmet, a round
#                    shield and a short sword (16x20)
#   pyro:            the fire mage's Pyro-Monster: a hunched charcoal imp
#                    with glowing magma cracks, a flickering flame mane,
#                    horns and claws (16x22, user wish 30.10.2026)
# Output: assets/sprites/companions/<kind>_<idle|walk>_f<0-3>.png
# Run: python -X utf8 scripts/make_companion_sprites.py
import math
import os
from PIL import Image

OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'sprites', 'companions')
INK = (0x22, 0x22, 0x22, 255)


def outline(px, w, h):
    """Every empty pixel touching the figure (4 neighbours) becomes ink."""
    out = dict(px)
    for (x, y) in px:
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            q = (x + dx, y + dy)
            if q not in px and 0 <= q[0] < w and 0 <= q[1] < h:
                out[q] = INK
    return out


def save(px, w, h, name):
    im = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    for (x, y), c in outline(px, w, h).items():
        if 0 <= x < w and 0 <= y < h:
            im.putpixel((x, y), c)
    im.save(os.path.join(OUT, name))


def ellipse(px, cx, cy, rx, ry, shade):
    for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
        for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
            nx, ny = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
            if nx * nx + ny * ny <= 1.0:
                px[(x, y)] = shade(nx, ny)


# --- water elemental --------------------------------------------------------
DEEP, MID, LIGHT, FOAM, EYE = (0x1f, 0x4f, 0xa8, 255), (0x34, 0x86, 0xd8, 255), (0x76, 0xc4, 0xf6, 255), (0xd8, 0xf4, 0xff, 255), (0xff, 0xff, 0xff, 255)


def water(nx, ny):
    lit = -nx * 0.7 - ny * 0.6
    return LIGHT if lit > 0.45 else MID if lit > -0.35 else DEEP


def elemental(frame, walking):
    px = {}
    t = frame / 4.0 * math.tau
    bob = round(math.sin(t)) if not walking else (frame % 2)
    lean = 0.6 if walking else 0.0
    # the whirl it glides on: a narrowing column with foam stripes that turn
    for y in range(14, 22):
        half = 1.5 + (21 - y) * 0.45
        cx = 8 + lean * (y - 14) * 0.15 + math.sin(t + y * 0.9) * 0.6
        for x in range(16):
            d = x + 0.5 - cx
            if abs(d) <= half:
                stripe = (x + y + frame * (2 if walking else 1)) % 4 == 0
                px[(x, y)] = FOAM if stripe and abs(d) < half - 0.5 else (MID if d < 0 else DEEP)
    # body and head
    ellipse(px, 8 + lean, 11 + bob, 5.2, 4.6, water)
    ellipse(px, 8 + lean, 5.2 + bob, 3.9, 3.6, water)
    # a crest of foam on the head, rising and falling
    for x in range(6, 11):
        if (x + frame) % 3 != 0:
            px[(x + round(lean), 1 + bob + (1 if x in (6, 10) else 0))] = FOAM
    # arms: two blobs that swing (idle: float up and down; walk: swing)
    swing = math.sin(t) * (1.6 if walking else 1.0)
    ellipse(px, 2.6 + lean, 10.5 + bob - swing, 1.7, 2.2, water)
    ellipse(px, 13.4 + lean, 10.5 + bob + swing, 1.7, 2.2, water)
    # glowing eyes and a ripple across the chest
    ex = 8 + round(lean)
    px[(ex - 2, 5 + bob)] = EYE
    px[(ex + 1, 5 + bob)] = EYE
    px[(ex - 2, 6 + bob)] = FOAM
    px[(ex + 1, 6 + bob)] = FOAM
    for x in range(5, 11):
        if (x + frame) % 2 == 0:
            px[(x + round(lean), 11 + bob)] = LIGHT
    return px


# --- bone warrior -----------------------------------------------------------
BONE_D, BONE_L = (0xd3, 0xbf, 0xa9, 255), (0xfd, 0xf7, 0xed, 255)
IRON_D, IRON_M, IRON_L = (0x4e, 0x52, 0x63, 255), (0x80, 0x88, 0x9c, 255), (0xc4, 0xcc, 0xd8, 255)
WOOD_D, WOOD_M, BRASS = (0x6b, 0x3e, 0x26, 255), (0x9a, 0x5b, 0x32, 255), (0xd9, 0xa8, 0x48, 255)
GLOW, SOCKET = (0x9c, 0xff, 0x8a, 255), (0x22, 0x22, 0x22, 255)


def warrior(frame, walking):
    px = {}
    bob = (1 if frame in (1, 3) else 0) if walking else (1 if frame in (2, 3) else 0)
    # skull with an iron helmet over the top half
    for y in range(2, 9):
        for x in range(5, 12):
            px[(x, y + bob)] = BONE_L if x < 10 else BONE_D
    for x in range(5, 12):
        px[(x, 1 + bob)] = IRON_L if x < 8 else IRON_M
        px[(x, 2 + bob)] = IRON_M if x < 10 else IRON_D
        px[(x, 3 + bob)] = IRON_D
    px[(8, 0 + bob)] = IRON_M  # the helmet's ridge
    # eye sockets with a green glow, the teeth
    for x in (6, 9):
        px[(x, 5 + bob)] = SOCKET
        px[(x + 1, 5 + bob)] = GLOW
    for x in range(6, 11):
        px[(x, 7 + bob)] = BONE_D if x % 2 else BONE_L
    # neck and ribcage
    px[(8, 9 + bob)] = BONE_D
    for y in range(10, 15):
        for x in range(6, 11):
            px[(x, y + bob)] = BONE_L if (y % 2 == 0 and x != 8) else BONE_D
    # legs: idle stand apart, walk alternates
    step = (frame % 2) if walking else 0
    left = [(6, 15), (6, 16), (6 - step, 17), (6 - step, 18)]
    right = [(10, 15), (10, 16), (10 + (1 - step) * (1 if walking else 0), 17), (10 + (1 - step) * (1 if walking else 0), 18)]
    for (x, y) in left + right:
        px[(x, y + (0 if y > 16 else bob))] = BONE_D if y > 16 else BONE_L
    # sword in the right hand: the blade points up, it lifts on the step
    lift = 1 if (walking and frame % 2) else 0
    for y in range(3, 11):
        px[(13, y + bob - lift)] = IRON_L if y < 6 else IRON_M
    px[(12, 11 + bob - lift)] = BRASS
    px[(13, 11 + bob - lift)] = BRASS
    px[(14, 11 + bob - lift)] = BRASS
    px[(13, 12 + bob - lift)] = WOOD_D
    px[(12, 12 + bob)] = BONE_L  # the hand
    # round shield on the left arm: wood, brass rim and boss
    for y in range(8, 16):
        for x in range(0, 6):
            nx, ny = (x + 0.5 - 3.0) / 3.0, (y + 0.5 - 12.0) / 4.0
            d = nx * nx + ny * ny
            if d <= 1.0:
                px[(x, y + bob)] = BRASS if d > 0.62 else (WOOD_M if nx + ny < 0.2 else WOOD_D)
    px[(3, 11 + bob)] = IRON_L
    px[(3, 12 + bob)] = IRON_M
    return px


# --- pyro monster ----------------------------------------------------------------
COAL_D, COAL_M, COAL_L = (0x2a, 0x1c, 0x1e, 255), (0x4a, 0x30, 0x2c, 255), (0x6e, 0x48, 0x3a, 255)
LAVA, LAVA_HOT, FLAME_R, FLAME_O, FLAME_Y = (0xc8, 0x38, 0x1c, 255), (0xff, 0x9a, 0x3a, 255), (0xd8, 0x46, 0x1c, 255), (0xff, 0x8a, 0x2a, 255), (0xff, 0xd8, 0x60, 255)
HORN = (0xe8, 0xd6, 0xb0, 255)


def coal(nx, ny):
    lit = -nx * 0.7 - ny * 0.6
    return COAL_L if lit > 0.5 else COAL_M if lit > -0.3 else COAL_D


def pyro(frame, walking):
    px = {}
    t = frame / 4.0 * math.tau
    bob = (1 if frame in (1, 3) else 0) if walking else (1 if frame in (2, 3) else 0)
    # the flame mane behind the head, flickering every frame
    for x in range(3, 13):
        height = 3 + int(2.5 * (0.5 + 0.5 * math.sin(x * 1.7 + t * 2.0)))
        for k in range(height):
            y = 6 + bob - k
            px[(x, y)] = FLAME_Y if k < 1 else FLAME_O if k < 3 else FLAME_R
    # hunched body and head of charcoal rock
    ellipse(px, 8, 13 + bob, 5.4, 4.6, coal)
    ellipse(px, 8, 7.5 + bob, 3.8, 3.4, coal)
    # horns
    for (x, y) in ((4, 4), (4, 3), (3, 2), (12, 4), (12, 3), (13, 2)):
        px[(x, y + bob)] = HORN
    # glowing eyes and a burning mouth
    px[(6, 7 + bob)] = FLAME_Y
    px[(10, 7 + bob)] = FLAME_Y
    for x in range(7, 10):
        px[(x, 9 + bob)] = LAVA_HOT if (x + frame) % 2 == 0 else LAVA
    # magma cracks across the chest, pulsing
    for (x, y) in ((6, 12), (7, 13), (8, 13), (9, 14), (10, 13), (7, 15), (6, 16)):
        px[(x, y + bob)] = LAVA_HOT if (x + y + frame) % 3 == 0 else LAVA
    # clawed arms swinging
    swing = round(math.sin(t) * (1.5 if walking else 0.6))
    ellipse(px, 2.4, 13 + bob - swing, 1.6, 2.4, coal)
    ellipse(px, 13.6, 13 + bob + swing, 1.6, 2.4, coal)
    for (x, y) in ((1, 16 - swing), (3, 16 - swing), (13, 16 + swing), (15, 16 + swing)):
        px[(x, y + bob)] = FLAME_O
    # legs
    step = (frame % 2) if walking else 0
    for (x, y) in ((6 - step, 18), (6 - step, 19), (6 - step, 20), (10 + step, 18), (10 + step, 19), (10 + step, 20)):
        px[(x, y)] = COAL_M
        px[(x + 1, y)] = COAL_D
    px[(6 - step, 21)] = FLAME_R
    px[(11 + step, 21)] = FLAME_R
    return px


def main():
    os.makedirs(OUT, exist_ok=True)
    for motion in ('idle', 'walk'):
        for f in range(4):
            save(elemental(f, motion == 'walk'), 16, 22, 'water_elemental_%s_f%d.png' % (motion, f))
            save(warrior(f, motion == 'walk'), 16, 20, 'bone_warrior_%s_f%d.png' % (motion, f))
            save(pyro(f, motion == 'walk'), 16, 22, 'pyro_%s_f%d.png' % (motion, f))
    print('ok', OUT)


main()
