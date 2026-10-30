"""Builds the Frostgruft's HD graphics set and the world kit pieces of its pixel set.

HD (assets/sprites/frost_hd): every sprite of the HD hell set (assets/sprites/hell, world kit
pieces included) frozen: its stone in the Frostgruft's blue-grey stone, its glow, fire and cracks
in ice light, its lava as glaze ice. Red banners and rugs, gold, hearts, mana blue and the floor
colours of the banners keep their colour; the merchant stays as he is. The Frostgruft's own
sprites (monsters, boss phases, keys, allies, weapons) come from the pixel set unchanged, as the
hell's monsters are pixel figures in its HD set too.

Pixel (assets/sprites/frost): the world kit pieces the pixel set lacked, frozen the same way
from the hell's pixel set (assets/sprites/hell_0x72), so they keep their whole 0x72 pixels.

The ramps are the Frostgruft's own (tools/frost_dungeon/build_frost_skin.py, RAMPS).
Usage (repo root): py -3 -I tools/frost_dungeon/build_frost_extras.py
No dependencies: uses tools/hell_dungeon/img.py.
"""
import colorsys
import json
import os
import shutil
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, '..', '..')
sys.path.insert(0, os.path.join(ROOT, 'tools', 'hell_dungeon'))
import img  # noqa: E402
sys.path.insert(0, HERE)
import wall_snow  # noqa: E402

SPR = os.path.join(ROOT, 'assets', 'sprites')
HELL, HELL_PIX, FROST, FROST_HD = (os.path.join(SPR, d) for d in ('hell', 'hell_0x72', 'frost', 'frost_hd'))
# the pixel set's sprites before their snow caps (kept once, so a rebuild never caps twice)
BASE = os.path.join(HERE, 'pixel_base')


def ramp(hexes):
    cs = [tuple(int(h[i:i + 2], 16) for i in (1, 3, 5)) for h in hexes]

    def at(t):
        t = max(0.0, min(1.0, t)) * (len(cs) - 1)
        k = min(len(cs) - 2, int(t))
        f = t - k
        return tuple(int(cs[k][i] + (cs[k + 1][i] - cs[k][i]) * f) for i in range(3))
    return at


STONE = ramp(['#0c1226', '#1a2442', '#2c3a60', '#435683', '#6479a6', '#93a8cc', '#c8d6ec'])
ICE = ramp(['#0a1430', '#163063', '#2b5ea3', '#4f93d6', '#8cc8f2', '#d2f1ff', '#ffffff'])
GLAZE = ramp(['#1b4f9c', '#2f6fbe', '#5a98da', '#8cc8f2', '#b8e2fa', '#e6f8ff'])

# sprites that keep their red cloth, their gold, or stay as they are
CLOTH = {'boss_banner', 'carpet', 'rug_red', 'mat', 'rug_square', 'shop_table', 'heart', 'icon_demon', 'icon_demon_big'}
GOLD = {'chest_gold', 'chest_open', 'chest_vault', 'key', 'carpet', 'rug_red', 'rug_blue', 'mat', 'rug_square', 'shop_table', 'shelf', 'icon_chest'}
AS_IS = {'npc_idle_f0', 'npc_idle_f1', 'npc_idle_f2', 'npc_idle_f3', 'heart'}
# sprites whose own colours stay: the floor-colour banners, mana, floor 10's blue fire, blue rugs and urns
COLOURED = {'boss_banner_blue', 'boss_banner_green', 'boss_banner_purple', 'boss_banner_gold', 'boss_banner_teal', 'boss_banner_pink',
            'fountain', 'brazier_blue', 'bowl_blue', 'wall_torch_blue', 'wall_v_glow_blue', 'torch_pillar_blue', 'boss_gate_blue',
            'rug_blue', 'urn_a', 'urn_b', 'urn_c', 'urn_d', 'urn_e', 'shelf', 'shop_table'}
# the hell's lava is the Frostgruft's glaze ice
GLAZED = {'lava_00', 'lava_01'}
# where the Frostgruft says something else: the secret wall's skull heap is an ice crystal (the
# hell's obsidian spires, frozen)
INSTEAD = {'skull_heap': 'spire_big_t'}


def hsv(c):
    return colorsys.rgb_to_hsv(c[0] / 255, c[1] / 255, c[2] / 255)


def lum(c):
    return (0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]) / 255


def freeze(src, name):
    """One sprite frozen (see the module note)."""
    if name in AS_IS:
        return src
    out = img.Img(src.w, src.h, bytearray(src.buf))
    for y in range(src.h):
        for x in range(src.w):
            c = src.get(x, y)
            if c[3] == 0:
                continue
            h, s, v = hsv(c)
            warm = (h < .17 or h > .93) and s > .35
            if name in GLAZED or (name == 'lava_edge_top' and warm and v > .5):
                out.set(x, y, GLAZE(lum(c) * 1.2) + (c[3],))
                continue
            if name in GOLD and .09 < h < .17 and s > .4 and v > .5:
                continue
            if name in CLOTH and (h < .04 or h > .9) and s > .45:
                continue
            if name in COLOURED and s > .45 and v > .3 and (.2 < h < .93 or name == 'boss_banner_gold'):
                continue
            if warm and s > .45 and v > .5:            # fire, glow, cracks: ice light
                out.set(x, y, ICE(.32 + .5 * v * (1.1 - .3 * s)) + (c[3],))
                continue
            out.set(x, y, STONE(min(1.0, lum(c) * 1.9 + .12)) + (c[3],))
    return out


# ---------- snow (the visual winter of the Frostgruft) ----------

SNOW = ramp(['#7f9cc4', '#a9c2e2', '#d2e4f4', '#eef6ff', '#ffffff'])
# what wears a snow cap on every upward edge: walls, pillars, stones, skulls, statues, furniture,
# gates (fire, torches, braziers, floors, rugs, banners and figures stay bare: fire melts snow)
CAPPED = ['wall_h', 'wall_h_glowpost', 'wall_post_slit', 'corner_cap', 'wall_v', 'wall_v_glow', 'wall_v_glow_b', 'jamb_a', 'jamb_b', 'gate_side',
          'rune_pillar_a', 'rune_pillar_b', 'rune_pillar_c', 'rune_pillar_d', 'obelisk', 'skull_obelisk', 'skull_pile', 'skull_heap', 'coal_skulls',
          'rocks_a', 'rocks_dark', 'rocks_lava', 'boulders', 'spire_big', 'spire_big_b', 'spire_big_t', 'spire_mid', 'spire_small', 'spires_t',
          'spires_lava', 'spire_t', 'altar', 'demon_lintel', 'portcullis', 'boss_gate', 'boss_gate_blue', 'boss_arch', 'stairs_down', 'door_stairs',
          'door_stairs_small', 'statue_angel', 'statue_monk', 'gargoyle', 'barrel_a', 'barrel_b', 'barrel_c', 'crate_a', 'crate_b', 'crate_c',
          'crate_pile', 'urn_a', 'urn_b', 'urn_c', 'urn_d', 'urn_e', 'table_a', 'table_b', 'table_c', 'bench', 'shelf', 'shop_table', 'sacks_a',
          'sacks_b', 'sacks_c', 'chest_closed', 'cage_small', 'moss_rubble_a', 'moss_rubble_b', 'moss_ruin', 'fountain', 'portal', 'portal_dark']


def noise1(x, seed):
    """Smooth 1-D value noise, 0..1."""
    def h(i):
        v = (i * 374761393 + seed * 668265263) & 0xFFFFFFFF
        v = ((v ^ (v >> 13)) * 1274126177) & 0xFFFFFFFF
        return ((v ^ (v >> 16)) & 0xFFFF) / 65535
    i, f = int(x // 1), x % 1
    u = f * f * (3 - 2 * f)
    return h(i) * (1 - u) + h(i + 1) * u


def snowcap(src, block, seed=1, unit=None):
    """Snow lying on every upward edge of a sprite: on the topmost edge 2 to 5 blocks deep, on lower
    ledges 1 to 2, white on top fading to a cold blue, a thin shadow under it. block = the pixel
    size (1 for HD, 3 for the pixel set) so the cap keeps the sprite's grid; unit = px per depth step
    (the pixel size; HD sprites take 3 so their caps read as thick as the pixel set's)."""
    unit = unit or block
    out = img.Img(src.w, src.h, bytearray(src.buf))
    solid = lambda x, y: 0 <= x < src.w and 0 <= y < src.h and src.get(x, y)[3] > 100
    first = {}
    for bx in range(0, src.w, block):
        for y in range(0, src.h, block):
            if solid(bx, y):
                first[bx] = y
                break
    for bx in range(0, src.w, block):
        for y in range(0, src.h, block):
            if not solid(bx, y) or solid(bx, y - block):
                continue
            top = first.get(bx) == y
            n = noise1(bx / (block * 7.0), seed + (0 if top else 17))
            depth = ((2 + int(n * 3.99)) if top else (1 + int(n * 1.99))) * unit // block
            if not top and y > src.h * .8:
                continue
            for k in range(depth + 1):
                yy = y + k * block
                if not solid(bx, yy):
                    break
                c = SNOW(1 - k / max(1, depth) * .55) if k < depth else None
                for dy in range(block):
                    for dx in range(block):
                        px, py = bx + dx, yy + dy
                        if px >= src.w or py >= src.h or src.get(px, py)[3] <= 100:
                            continue
                        if c is None:   # the shadow under the cap
                            o = src.get(px, py)
                            out.set(px, py, (o[0] * 3 // 4, o[1] * 3 // 4, min(255, o[2] * 4 // 5 + 20), o[3]))
                        else:
                            out.set(px, py, c + (255,))
    return out


def noise2(x, y, seed):
    def h(i, j):
        v = (i * 374761393 + j * 668265263 + seed * 2147483647) & 0xFFFFFFFF
        v = ((v ^ (v >> 13)) * 1274126177) & 0xFFFFFFFF
        return ((v ^ (v >> 16)) & 0xFFFF) / 65535
    i, j, fx, fy = int(x // 1), int(y // 1), x % 1, y % 1
    u, v = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
    a = h(i, j) * (1 - u) + h(i + 1, j) * u
    b = h(i, j + 1) * (1 - u) + h(i + 1, j + 1) * u
    return a * (1 - v) + b * v


def snow_patch(seed, size, block):
    """A drift of snow on the floor: an irregular soft heap, lit from the top left, a blue shadow on
    its lower right rim and a few glints. HD (block 1) fades out at the rim; the pixel set (block 3)
    keeps a hard edge on its grid. Neighbouring patches overlap into fields."""
    n = size // block
    out = img.Img(n * block, n * block)
    c = n / 2
    for by in range(n):
        for bx in range(n):
            dx, dy = (bx - c) / c, (by - c) / c
            # a rounded square (superellipse), so overlapping drifts close into one field
            d = (dx ** 4 + dy ** 4) ** .25
            edge = .8 + .24 * (noise2(bx / (n / 5), by / (n / 5), seed) - .5) * 2
            if d > edge:
                continue
            rim = (edge - d) / edge
            # mostly an even white so drifts merge into one field; a soft blue shade only at the rim
            light = .7 + .1 * noise2(bx / (n / 9), by / (n / 9), seed + 5) + .05 * (-dx * .6 - dy * .8)
            if rim < .1:
                light -= .2
            col = SNOW(max(0, min(1, light)))
            if noise2(bx * 1.7, by * 1.7, seed + 9) > .93 and rim > .3:
                col = (255, 255, 255)
            a = 255 if block > 1 else int(255 * min(1, rim / .22))
            for y in range(by * block, by * block + block):
                for x in range(bx * block, bx * block + block):
                    out.set(x, y, col + (a,))
    return out


def snowman(block):
    """A snowman: three snowballs lit from the top left, coal eyes and buttons, a carrot nose, stick
    arms and a red scarf. Drawn on a 24 x 36 grid of `block` px (HD 3 px, pixel set 3 px with an
    outline) so both sets share its proportions."""
    W_, H_ = 24, 36
    g = [[None] * W_ for _ in range(H_)]
    def ball(cx, cy, r):
        for y in range(H_):
            for x in range(W_):
                dx, dy = (x + .5 - cx) / r, (y + .5 - cy) / r
                if dx * dx + dy * dy <= 1:
                    nz = max(0, 1 - dx * dx - dy * dy) ** .5
                    g[y][x] = SNOW(max(0, min(1, .35 + .55 * (-.5 * dx - .6 * dy + .6 * nz))))
    ball(12, 27, 8.5); ball(12, 15.5, 6.2); ball(12, 6.5, 4.6)
    for x, y in ((10, 5), (14, 5), (12, 13), (12, 16), (12, 19)):
        g[y][x] = (24, 28, 40)
    for x in (13, 14, 15):
        g[7][x] = (232, 120, 40) if x < 15 else (200, 90, 30)
    for x in range(7, 18):
        g[10][x] = (190, 40, 50)
        g[11][x] = (150, 28, 40) if x % 3 else (190, 40, 50)
    for y in (12, 13, 14):
        g[y][16] = (160, 30, 42)
    for i in range(6):
        g[14 - i // 2][5 - i // 2 if i < 5 else 2] = (92, 62, 44)
        g[14 - i // 2][18 + i // 2] = (92, 62, 44)
    outline = block == 3
    out = img.Img((W_ + 2) * block, (H_ + 2) * block)
    for y in range(-1, H_ + 1):
        for x in range(-1, W_ + 1):
            c = g[y][x] if 0 <= y < H_ and 0 <= x < W_ else None
            if c is None and outline and any(0 <= y + v < H_ and 0 <= x + u < W_ and g[y + v][x + u] is not None for u, v in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                c = (0x0c, 0x12, 0x26)
            if c is None:
                continue
            for yy in range((y + 1) * block, (y + 2) * block):
                for xx in range((x + 1) * block, (x + 2) * block):
                    out.set(xx, yy, tuple(c) + (255,))
    return out


def glacier(src, block, seed, unit=None):
    """Glacier ice from an obsidian spire: bright translucent blue ice with white facets and a snow cap."""
    out = img.Img(src.w, src.h, bytearray(src.buf))
    bright = ramp(['#3f78c0', '#6aa8e6', '#9fd3f6', '#d2f1ff', '#ffffff'])
    for y in range(src.h):
        for x in range(src.w):
            c = src.get(x, y)
            if c[3]:
                out.set(x, y, bright(min(1.0, lum(c) * 1.8 + .15)) + (c[3],))
    return snowcap(out, block, seed, unit)


OUTLINE = (0x0c, 0x12, 0x26)


def hexc(h):
    return tuple(int(h[i:i + 2], 16) for i in (1, 3, 5))


def grid_image(g, block, outline=True):
    """A colour grid (None = empty) as an image of `block` px pixels, with the dark 1 px outline of
    the pixel figures around everything solid."""
    H_, W_ = len(g), len(g[0])
    pad = 1 if outline else 0
    out = img.Img((W_ + 2 * pad) * block, (H_ + 2 * pad) * block)
    for y in range(-pad, H_ + pad):
        for x in range(-pad, W_ + pad):
            c = g[y][x] if 0 <= y < H_ and 0 <= x < W_ else None
            if c is None and outline and any(0 <= y + v < H_ and 0 <= x + u < W_ and g[y + v][x + u] is not None for u, v in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                c = OUTLINE
            if c is None:
                continue
            for yy in range((y + pad) * block, (y + pad + 1) * block):
                for xx in range((x + pad) * block, (x + pad + 1) * block):
                    out.set(xx, yy, tuple(c[:3]) + (255,))
    return out


def ice_crack(block, seed):
    """The ice trap at rest: a short jagged crack in the snow, dark blue inside, with a thin pale
    lip of pushed-up snow on its upper side, small enough to read as a crack, not a stroke
    (18 x 9 cells of `block`)."""
    W_, H_ = 18, 9
    g = [[None] * W_ for _ in range(H_)]
    y = 4.0
    for x in range(2, W_ - 2):
        y += (noise1(x / 2.2, seed) - .5) * 1.8
        y = max(2.0, min(H_ - 3.0, y))
        width = 1 + (1 if 4 < x < W_ - 5 else 0)
        for k in range(width):
            g[int(y) + k][x] = hexc('#0f1f44') if k == 0 else hexc('#1d3b7a')
        g[int(y) - 1][x] = hexc('#ffffff')
        if g[int(y) + width][x] is None:
            g[int(y) + width][x] = hexc('#9fbcdf')
    return grid_image(g, block, outline=False)


def ice_burst(block, seed):
    """The ice trap firing: a few chunky ice spikes broken up out of the crack, each with a dark
    outline, a lit and a shaded face and a snowy foot, like the pixel set's crystals
    (20 x 24 cells of `block`, outlined)."""
    W_, H_ = 20, 24
    g = [[None] * W_ for _ in range(H_)]
    lit, shade, deep = ramp(['#9fd3f6', '#d2f1ff', '#ffffff']), ramp(['#3f78c0', '#6aa8e6', '#9fd3f6']), hexc('#2b5ea3')
    # (foot x, height, half width at the foot, lean per row)
    for cx, h, w, lean in ((4, 11, 2.2, -.22), (16, 13, 2.2, .22), (7, 17, 2.8, -.1), (13, 18, 2.8, .1), (10, 23, 3.4, 0.0)):
        for y in range(H_ - h, H_ - 1):
            t = (y - (H_ - h)) / h
            half = max(.5, w * t)
            mid = cx + lean * (H_ - 1 - y)
            for x in range(W_):
                d = x + .5 - mid
                if abs(d) <= half:
                    g[y][x] = lit(1 - t) if d < 0 else (shade(1 - t) if d < half * .6 else deep)
    for x in range(1, W_ - 1):   # the snow kicked up at the foot
        if g[H_ - 2][x] is not None or 3 < x < W_ - 3:
            g[H_ - 1][x] = hexc('#eef6ff')
    return grid_image(g, block)


def snow_tile(seed, block):
    """A tileable snow floor cell (96 px): soft white with cold blue hollows, a few drift ridges and
    glints, as on the snowy ground of a winter map. HD (block 1) is smooth, the pixel set (block 3)
    keeps its grid in few steps."""
    n = 96 // block
    out = img.Img(96, 96)
    per = 4   # noise period in cells: the tile repeats seamlessly
    def tnoise(x, y, scale, s):
        fx, fy = x / n * per * scale, y / n * per * scale
        p = per * scale
        i, j = int(fx), int(fy)
        u, v = fx - i, fy - j
        u, v = u * u * (3 - 2 * u), v * v * (3 - 2 * v)
        h = lambda a, b: _h(a % p, b % p, s)
        return (h(i, j) * (1 - u) + h(i + 1, j) * u) * (1 - v) + (h(i, j + 1) * (1 - u) + h(i + 1, j + 1) * u) * v
    snow = ramp(['#a9c2e2', '#c9dcf0', '#e2eef9', '#f2f8ff'])
    for by in range(n):
        for bx in range(n):
            v = .55 * tnoise(bx, by, 1, seed) + .3 * tnoise(bx, by, 2, seed + 1) + .15 * tnoise(bx, by, 4, seed + 2)
            t = .25 + .75 * v
            if block > 1:
                t = round(t * 4) / 4
            c = snow(t)
            if _h(bx * 7 + 3, by * 5 + 1, seed + 9) > .985:
                c = (255, 255, 255)
            for y in range(by * block, by * block + block):
                for x in range(bx * block, bx * block + block):
                    out.set(x, y, c + (255,))
    return out


def _h(i, j, seed):
    v = (i * 374761393 + j * 668265263 + seed * 2147483647) & 0xFFFFFFFF
    v = ((v ^ (v >> 13)) * 1274126177) & 0xFFFFFFFF
    return ((v ^ (v >> 16)) & 0xFFFF) / 65535


def thaw(floor, seed, block, size=150):
    """A patch where fire melted the snow: the stone floor showing through an irregular hole, a dark
    wet rim and a lip of slush, drawn over the snow (size px, the floor texture repeated)."""
    n = size // block
    out = img.Img(n * block, n * block)
    c = n / 2
    for by in range(n):
        for bx in range(n):
            dx, dy = (bx - c) / c, (by - c) / c
            d = (dx * dx + dy * dy) ** .5
            edge = .72 + .22 * (noise2(bx / (n / 6), by / (n / 6), seed) - .5) * 2
            if d > edge + .08:
                continue
            for y in range(by * block, by * block + block):
                for x in range(bx * block, bx * block + block):
                    f = floor.get(x % floor.w, y % floor.h)
                    if d > edge:      # the slush lip
                        out.set(x, y, hexc('#c9dcf0') + (int(255 * (1 - (d - edge) / .08)) if block == 1 else 255,))
                    elif d > edge - .1:   # wet, dark rim
                        out.set(x, y, (f[0] * 3 // 5, f[1] * 3 // 5, min(255, f[2] * 3 // 4 + 10), 255))
                    else:   # the stone, a little lighter: wet and lit by the fire beside it
                        out.set(x, y, (min(255, f[0] * 5 // 4 + 12), min(255, f[1] * 5 // 4 + 12), min(255, f[2] * 5 // 4 + 16), 255))
    return out


def snow_monster(frame):
    """The snowman mimic, awake: three snowballs, a top hat, an angry face with glowing orange eyes
    under heavy brows and a jagged grin, a carrot nose, twig claws. It has no legs: its walk is a
    hop in which the three balls fly apart and come back together. 8 frames on a 32 x 64 grid (x3
    like every pixel figure); the foot sits on the bottom row, the hop's lift is inside the frame."""
    W_, H_ = 32, 64
    g = [[None] * W_ for _ in range(H_)]

    def put(x, y, c):
        if 0 <= x < W_ and 0 <= y < H_:
            g[y][x] = c
    # (lift, gap between balls, squash) per frame: crouch, push off, rise, peak, fall, land, squash, recover
    lift, gap, sq = ((0, 0, .82), (2, 1, 1.0), (6, 2, 1.08), (9, 3, 1.1), (7, 2, 1.04), (2, 1, .96), (0, 0, .8), (0, 0, .94))[frame]
    body = ramp(['#7f9cc4', '#a9c2e2', '#d2e4f4', '#eef6ff', '#ffffff'])

    def ball(cx, cy, r, s):
        rx, ry = r / s ** .5, r * s
        for y in range(H_):
            for x in range(W_):
                dx, dy = (x + .5 - cx) / rx, (y + .5 - cy) / ry
                if dx * dx + dy * dy <= 1:
                    nz = max(0, 1 - dx * dx - dy * dy) ** .5
                    g[y][x] = body(max(0, min(1, .3 + .6 * (-.5 * dx - .6 * dy + .5 * nz))))
    cx = 16
    ground = H_ - 1 - lift
    r1, r2, r3 = 8.0, 6.0, 6.2
    y1 = ground - r1 * sq
    y2 = y1 - r1 * sq - r2 * sq + 2 - gap
    y3 = y2 - r2 * sq - r3 * sq + 2 - gap
    ball(cx, y1, r1, sq); ball(cx, y2, r2, sq); ball(cx, y3, r3, sq)
    y1, y2, y3 = int(y1), int(y2), int(y3)
    coal = (24, 28, 40)
    for yy in (y1 - 3, y1 + 1, y2 - 1, y2 + 2):
        put(cx, yy, coal)
    # twig claws from the middle ball, raised while it is in the air
    raise_ = 3 if lift > 4 else 0
    for side in (-1, 1):
        x0 = cx + side * 6
        for i in range(6):
            put(x0 + side * i, y2 - i // 2 - (raise_ * i) // 5, hexc('#c0581a'))
        tx, ty = x0 + side * 6, y2 - 3 - raise_
        for ux, uy in ((side, -1), (side, 1), (0, -2), (side * 2, 0)):
            put(tx + ux, ty + uy, hexc('#ff8a3a'))
    # the face: heavy angry brows, glowing orange eyes, a wide jagged grin, the carrot nose
    dark = (18, 20, 30)
    for x, dy in ((cx - 4, -3), (cx - 3, -2), (cx - 2, -2), (cx + 2, -2), (cx + 3, -2), (cx + 4, -3)):
        put(x, y3 + dy, dark)
    for x in (cx - 3, cx - 2, cx + 2, cx + 3):
        put(x, y3 - 1, hexc('#ff6a1a'))
    put(cx - 2, y3 - 1, hexc('#ffd040')); put(cx + 2, y3 - 1, hexc('#ffd040'))
    for x in range(cx - 4, cx + 5):
        put(x, y3 + 3, dark)
        put(x, y3 + 2, (240, 244, 250) if (x + cx) % 2 == 0 else dark)
    put(cx - 5, y3 + 2, dark); put(cx + 5, y3 + 2, dark)
    for i in range(5):
        put(cx + 1 + i, y3 + 0, hexc('#e8781e') if i < 4 else hexc('#b04a10'))
    # the top hat with a red band
    top = y3 - int(r3 * sq) + 1
    for x in range(cx - 6, cx + 6):
        put(x, top, hexc('#1c1e28'))
    for y in range(top - 7, top):
        for x in range(cx - 4, cx + 4):
            put(x, y, hexc('#8a1c2a') if y == top - 1 else hexc('#3a3d4a') if x == cx - 4 else hexc('#23252f'))
    return grid_image(g, 3)


ICICLE = ramp(['#6aa8e6', '#b8e2fa', '#ffffff'])


def icicles(src, block, seed):
    """Icicles hanging from the snow on top of a wall: under the cap, every few pixels one icicle 1
    to 4 blocks long, tapering, pale with a bright highlight."""
    out = img.Img(src.w, src.h, bytearray(src.buf))
    solid = lambda x, y: 0 <= x < src.w and 0 <= y < src.h and src.get(x, y)[3] > 100
    for bx in range(0, src.w, block):
        top = next((y for y in range(0, src.h, block) if solid(bx, y)), None)
        if top is None or _h(bx // block, 7, seed) < .62:
            continue
        start = top + 6 * block if block > 1 else top + 14
        length = 1 + int(_h(bx // block, 3, seed) * 3.99)
        for k in range(length * (1 if block > 1 else 3)):
            y = start + k * (block if block > 1 else 1)
            if not solid(bx, y):
                break
            col = ICICLE(1 - k / max(1, length * (1 if block > 1 else 3)))
            w = block if block > 1 else max(1, 3 - k // 3)
            for dy in range(block if block > 1 else 1):
                for dx in range(w):
                    if bx + dx < src.w and y + dy < src.h:
                        out.set(bx + dx, y + dy, col + (255,))
    return out


ICICLED = {'wall_h', 'wall_h_glowpost', 'wall_post_slit', 'corner_cap', 'gate_side', 'boss_gate', 'boss_gate_blue', 'portcullis', 'demon_lintel', 'boss_arch'}
FLOORS = ['floor_%02d' % i for i in range(12)]
MONSTER = ['mob_snowman_f%d' % i for i in range(8)]
# what stands on the snow and sinks into it a little: snow cushions over its lower edge (snowfoot);
# the wall faces get them along their foot, the pits round their rim (pit_rim)
FOOTED = {'wall_h', 'wall_h_glowpost', 'wall_post_slit', 'gate_side', 'jamb_a', 'jamb_b', 'boss_gate', 'boss_gate_blue', 'boss_arch',
          'rune_pillar_a', 'rune_pillar_b', 'rune_pillar_c', 'rune_pillar_d', 'obelisk', 'skull_obelisk', 'skull_pile', 'skull_heap', 'coal_skulls',
          'rocks_a', 'rocks_dark', 'rocks_lava', 'boulders', 'spire_big', 'spire_big_b', 'spire_big_t', 'spire_mid', 'spire_small', 'spires_t',
          'spires_lava', 'spire_t', 'altar', 'stairs_down', 'statue_angel', 'statue_monk', 'gargoyle', 'barrel_a', 'barrel_b', 'barrel_c',
          'crate_a', 'crate_b', 'crate_c', 'crate_pile', 'urn_a', 'urn_b', 'urn_c', 'urn_d', 'urn_e', 'table_a', 'table_b', 'table_c', 'bench',
          'shelf', 'shop_table', 'sacks_a', 'sacks_b', 'sacks_c', 'chest_closed', 'chest_open', 'chest_gold', 'chest_empty', 'chest_vault',
          'cage_small', 'moss_rubble_a', 'moss_rubble_b', 'moss_ruin', 'fountain', 'portal', 'portal_dark', 'candelabra',
          'brazier_bowl', 'brazier_pillar', 'brazier_rune', 'brazier_low', 'brazier_low_b', 'brazier_floor', 'brazier_demon', 'brazier_blue',
          'bowl_blue', 'torch_pillar', 'torch_pillar_blue', 'snowman', 'glacier_a', 'glacier_b'}
RIMMED = {'pit'}


def snowfoot(src, block, seed, unit=None):
    """The thing stands a little sunk in the snow: small snow cushions lie over its lower edge where
    it touches the ground, uneven lumps (unit = px per step: 3 for both sets), white on top and
    cold blue below, some spilling a step past its sides. Done on the sprite itself, so it sits
    exactly where the thing touches the floor."""
    unit = unit or block
    out = img.Img(src.w, src.h, bytearray(src.buf))
    solid = lambda x, y: 0 <= x < src.w and 0 <= y < src.h and src.get(x, y)[3] > 100
    cols = []
    for x in range(0, src.w, block):
        yb = next((y for y in range(src.h - 1, -1, -1) if solid(x, y)), None)
        if yb is not None:
            cols.append((x, yb))
    if not cols:
        return out
    # the contact: columns whose lowest pixel lies near the sprite's lowest row
    floor_y = max(yb for _, yb in cols)
    contact = [(x, yb) for x, yb in cols if yb >= floor_y - 4 * unit]
    if not contact:
        return out
    lo, hi = contact[0][0], contact[-1][0]
    def lump(x):
        # bumps of 1 to 3 steps, an extra one now and then
        n = noise1(x / (unit * 3.2), seed) * .7 + noise1(x / (unit * 1.4), seed + 5) * .3
        return 1 + int(n * 2.99)
    for x, yb in contact:
        h = lump(x) * unit
        for k in range(0, h, block):
            y = yb - k
            if not solid(x, y):
                break
            t = k / max(1, h)
            c = SNOW(min(1, .45 + .55 * t))   # white on top of the cushion, blue at its foot
            for dy in range(block):
                for dx in range(block):
                    if x + dx < src.w and y + dy < src.h:
                        out.set(x + dx, y + dy, c + (255,))
        # a fine cold line where the cushion meets the thing, so the snow reads as lying on it
        y = yb - h
        if solid(x, y):
            for dy in range(block):
                for dx in range(block):
                    if x + dx < src.w and y + dy < src.h:
                        o = src.get(x + dx, y + dy)
                        out.set(x + dx, y + dy, ((o[0] + 2 * 0x8e) // 3, (o[1] + 2 * 0xaa) // 3, (o[2] + 2 * 0xd0) // 3, 255))
    # a step of snow spilling past each side at the ground
    for side, x0 in ((-1, lo), (1, hi)):
        for k in range(1, 3):
            x = x0 + side * k * block
            if 0 <= x < src.w and not solid(x, floor_y):
                for dy in range(block):
                    for dx in range(block):
                        if x + dx < src.w and floor_y - dy >= 0:
                            out.set(x + dx, floor_y - dy, SNOW(.6) + (255,))
    return out


def pit_rim(src, block, seed, unit=None):
    """Snow round the rim of a pit: an uneven white border on its frame, thicker on the top edge."""
    unit = unit or block
    out = img.Img(src.w, src.h, bytearray(src.buf))
    for y in range(0, src.h, block):
        for x in range(0, src.w, block):
            if src.get(x, y)[3] <= 100:
                continue
            edge = min(x, y / 1.6, src.w - 1 - x, src.h - 1 - y) / unit
            n = noise2(x / (block * 4.0), y / (block * 4.0), seed)
            if edge < 1.5 + n * 2.2:
                c = SNOW(.75 + .25 * n)
                for dy in range(block):
                    for dx in range(block):
                        if x + dx < src.w and y + dy < src.h:
                            out.set(x + dx, y + dy, c + (255,))
    return out


DRIFTS = 6
WINTER_NAMES = {'snow_a', 'snow_b', 'snow_c', 'snow_d', 'snowman', 'glacier_a', 'glacier_b', 'ice_crack', 'ice_burst',
                'thaw_a', 'thaw_b', 'thaw_c'} | set(FLOORS) | set(MONSTER) | {'drift_%d' % k for k in range(DRIFTS)} | set(wall_snow.pieces(6))
# the wall snow's anchors and counts (src/hero/frost_wall_snow.gd)
WALL_SNOW_DATA = os.path.join(ROOT, 'assets', 'data', 'frost_wall_snow.json')


def drift(block, seed):
    """A small snow drift lying on the floor: two to four rounded lumps side by side, lit white on
    top, cold blue on their lower half, a darker blue underside where they press on the ground and a
    faint contact shade just below. The game lays rows of them at the foot of everything standing on
    the snow, round floor plates and pits and along the walls (src/hero/frost_snow.gd), drawn over
    the thing's lower edge so it stands a little sunk in. 48 x 24 px; the pixel set in 3 px steps."""
    W_, H_ = 48 // block, 24 // block
    lumps = []
    n = 2 + int(_h(seed, 1, 3) * 2.99)
    for i in range(n):
        cx = (i + .5) / n * W_ + (_h(seed, i, 5) - .5) * W_ * .18
        rx = W_ / n * (.58 + _h(seed, i, 7) * .3)
        ry = H_ * (.36 + _h(seed, i, 9) * .16)
        cx = max(rx + .5, min(W_ - rx - .5, cx))   # whole lumps, never cut at the frame
        lumps.append((cx, H_ - (2 if block == 1 else 1) - ry, rx, ry))
    shade = hexc('#7f9cc4')
    under = hexc('#5f7eaa')
    def inside(x, y):
        best = None
        for cx, cy, rx, ry in lumps:
            dx, dy = (x + .5 - cx) / rx, (y + .5 - cy) / ry
            d = dx * dx + dy * dy
            if d <= 1 and (best is None or dy < best[1]):
                best = (d, dy, dx)
        return best
    out = img.Img(W_ * block, H_ * block)
    for y in range(H_):
        for x in range(W_):
            hit = inside(x, y)
            if hit is None:
                # the contact shade right under a lump
                if inside(x, y - 1) is not None or inside(x, y - 2) is not None:
                    c, a = under, 70 if block == 1 else 90
                else:
                    continue
            else:
                d, dy, dx = hit
                below = inside(x, y + 1) is None
                edge = inside(x - 1, y) is None or inside(x + 1, y) is None or inside(x, y - 1) is None
                if below:
                    c, a = shade, 255          # the lump's foot, darker where it sits on the floor
                elif edge:
                    c, a = hexc('#b9cde6'), 255   # a faint cold rim so the lump reads against the snow
                else:
                    # white on top, a soft cold blue towards the foot
                    t = max(0, min(1, .9 - .38 * max(0, dy + .2) - .14 * dx))
                    c, a = SNOW(t), 255
            for yy in range(y * block, y * block + block):
                for xx in range(x * block, x * block + block):
                    out.set(xx, yy, c + (a,))
    return out


def winter_pieces(block):
    """The snow pieces of one set: name -> image (block 1 = HD, 3 = pixel). The floor cells become
    snow; thaw patches show the old stone floor where fire melted it."""
    hell_src = HELL if block == 1 else HELL_PIX
    pieces = {('snow_' + k): snow_patch(seed, 120, block) for k, seed in zip('abcd', (3, 11, 19, 27))}
    pieces['snowman'] = snowman(3)
    pieces['glacier_a'] = glacier(img.load(os.path.join(hell_src, 'spire_big.png')), block, 5, 3)
    pieces['glacier_b'] = glacier(img.load(os.path.join(hell_src, 'spire_big_b.png')), block, 9, 3)
    for k in range(DRIFTS):
        pieces['drift_%d' % k] = drift(block, 11 + k * 7)
    pieces['ice_crack'] = ice_crack(3, 4)
    pieces['ice_burst'] = ice_burst(3, 4)
    # the old stone floor (HD: the hell floor frozen; pixel: the set's own floor before the snow)
    stone = freeze(img.load(os.path.join(HELL, 'floor_00.png')), 'floor_00') if block == 1 else img.load(os.path.join(BASE, 'floor_00.png'))
    for k, seed in zip('abc', (5, 13, 21)):
        pieces['thaw_' + k] = thaw(stone, seed, block)
    for i, name in enumerate(FLOORS):
        pieces[name] = snow_tile(31 + i * 7, block)
    for i, name in enumerate(MONSTER):
        pieces[name] = snow_monster(i)
    # the snow at the walls (tools/frost_dungeon/wall_snow.py): pixel set in 3 px blocks, HD in 2 px
    for name, (im, _) in wall_snow.pieces(3 if block == 3 else 2).items():
        pieces[name] = im
    return pieces


def save_safe(im, path):
    """Saves through a temporary file (a sprite Windows still holds open after a game run cannot be
    opened for writing, but it can be replaced)."""
    retry(lambda: img.save(im, os.path.normpath(path)))


def retry(write):
    """Runs a file write, trying again for a few seconds: right after a big batch of writes Windows
    may still hold a just-written file (virus scan, indexing) and refuses to open it."""
    for k in range(40):
        try:
            return write()
        except OSError:
            if k == 39:
                raise
            time.sleep(0.25)


def save_manifest(path, man, crlf):
    text = json.dumps(dict(sorted(man.items())), indent=1, ensure_ascii=False, sort_keys=True) + '\n'
    retry(lambda: open(path, 'w', encoding='utf-8', newline='').write(text.replace('\n', '\r\n') if crlf else text))


def build():
    hell = json.load(open(os.path.join(HELL, 'manifest.json'), encoding='utf-8'))
    frost = json.load(open(os.path.join(FROST, 'manifest.json'), encoding='utf-8'))
    # HD
    os.makedirs(FROST_HD, exist_ok=True)
    hd = {}
    for name, m in hell.items():
        src = INSTEAD.get(name, name)
        im = freeze(img.load(os.path.join(HELL, src + '.png')), name)
        if name in CAPPED:
            im = snowcap(im, 1, len(name), 3)
        if name in ICICLED:
            im = icicles(im, 1, len(name))
        if name in FOOTED:
            im = snowfoot(im, 1, len(name), 3)
        if name in RIMMED:
            im = pit_rim(im, 1, len(name), 3)
        save_safe(im, os.path.join(FROST_HD, name + '.png'))
        hd[name] = {'w': im.w, 'h': im.h, 'kind': m['kind'], 'src': 'hell %s, frozen%s (build_frost_extras.py)' % (src, ', snow cap' if name in CAPPED else '')}
    for name, m in frost.items():
        if name in hell or name in WINTER_NAMES:
            continue
        shutil.copyfile(os.path.join(FROST, name + '.png'), os.path.join(FROST_HD, name + '.png'))
        hd[name] = dict(m)
    # the snow pieces last: the pixel set has its own of the same names
    for name, im in winter_pieces(1).items():
        save_safe(im, os.path.join(FROST_HD, name + '.png'))
        hd[name] = {'w': im.w, 'h': im.h, 'kind': 'opaque' if name in FLOORS else 'sprite', 'src': 'drawn: %s (build_frost_extras.py)' % name}
    save_manifest(os.path.join(FROST_HD, 'manifest.json'), hd, False)
    print(len(hd), 'HD sprites ->', FROST_HD)
    # pixel: the world kit pieces the pixel set lacks
    pix = json.load(open(os.path.join(HELL_PIX, 'manifest.json'), encoding='utf-8'))
    made = 0
    for name in hell:
        if name in frost or name not in pix:
            continue
        im = freeze(img.load(os.path.join(HELL_PIX, name + '.png')), name)
        img.save(im, os.path.join(FROST, name + '.png'))
        frost[name] = {'w': im.w, 'h': im.h, 'kind': pix[name].get('kind', 'sprite'), 'src': 'hell_0x72 %s, frozen (build_frost_extras.py)' % name}
        made += 1
    # snow caps on the pixel set: always painted on the untouched sprite, kept once in BASE
    os.makedirs(BASE, exist_ok=True)
    for name in sorted(set(CAPPED) | FOOTED | RIMMED):
        path, base = os.path.join(FROST, name + '.png'), os.path.join(BASE, name + '.png')
        if not os.path.exists(path) or name in WINTER_NAMES:
            continue
        if not os.path.exists(base):
            shutil.copyfile(path, base)
        im = img.load(base)
        if name in CAPPED:
            im = snowcap(im, 3, len(name))
        if name in ICICLED:
            im = icicles(im, 3, len(name))
        if name in FOOTED:
            im = snowfoot(im, 3, len(name), 3)
        if name in RIMMED:
            im = pit_rim(im, 3, len(name), 3)
        save_safe(im, path)
    for name in FLOORS:   # the stone floor stays under the snow for the thaw patches
        if not os.path.exists(os.path.join(BASE, name + '.png')):
            shutil.copyfile(os.path.join(FROST, name + '.png'), os.path.join(BASE, name + '.png'))
    # wall snow pieces a rebuild no longer draws (tools/frost_dungeon/wall_snow.py changed) leave both sets
    for d, man in ((FROST, frost), (FROST_HD, None)):
        for f in os.listdir(d):
            name = f[:-4]
            if f.startswith('snow_wall_') and f.endswith('.png') and name not in WINTER_NAMES:
                os.remove(os.path.join(d, f))
                if os.path.exists(os.path.join(d, f + '.import')):
                    os.remove(os.path.join(d, f + '.import'))
                if man is not None:
                    man.pop(name, None)
    for name, im in winter_pieces(3).items():
        save_safe(im, os.path.join(FROST, name + '.png'))
        frost[name] = {'w': im.w, 'h': im.h, 'kind': 'opaque' if name in FLOORS else 'sprite', 'src': 'drawn: %s (build_frost_extras.py)' % name}
        made += 1
    save_manifest(os.path.join(FROST, 'manifest.json'), frost, b'\r\n' in open(os.path.join(FROST, 'manifest.json'), 'rb').read())
    print(made, 'pixel sprites ->', FROST)
    data = json.dumps(wall_snow.layout(wall_snow.pieces(6)), indent=1, ensure_ascii=False) + '\n'
    retry(lambda: open(WALL_SNOW_DATA, 'w', encoding='utf-8', newline='').write(data))
    print('wall snow layout ->', WALL_SNOW_DATA)
    # the HD set's snow from the user's drawings (snow_hd.py), over the drawn caps and cushions
    import snow_hd
    print(len(snow_hd.build()), 'HD snow sprites ->', FROST_HD)


if __name__ == '__main__':
    build()
