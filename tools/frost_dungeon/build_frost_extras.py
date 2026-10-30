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


def ice_crack(block, seed):
    """The ice trap at rest: a thin dark crack in the ice with a pale rim (32 x 12 cells of `block`)."""
    W_, H_ = 32, 14
    out = img.Img(W_ * block, H_ * block)
    y = H_ / 2
    for x in range(2, W_ - 2):
        y += (noise1(x / 3.0, seed) - .5) * 1.6
        y = max(3, min(H_ - 4, y))
        for k, col in ((-2, '#d2f1ff'), (-1, '#6aa8e6'), (0, '#0a1a3c'), (1, '#0f2a55'), (2, '#2b5ea3'), (3, '#9fd3f6')):
            if k in (1, 2) and noise1(x / 2.0, seed + 3) < .35:
                continue
            yy = int(y) + k
            for dy in range(block):
                for dx in range(block):
                    out.set(x * block + dx, yy * block + dy, tuple(int(col[i:i + 2], 16) for i in (1, 3, 5)) + (255,))
    return out


def ice_burst(block, seed):
    """The ice trap firing: a cluster of ice shards shot up out of the crack (32 x 36 cells of `block`)."""
    W_, H_ = 32, 36
    g = [[None] * W_ for _ in range(H_)]
    shard = ramp(['#2b5ea3', '#6aa8e6', '#b8e2fa', '#ffffff'])
    # the outer shards lean outward (they burst out of the crack), the big one stands in the middle
    for i, (cx, h, w) in enumerate(((5, 15, 3.0), (27, 17, 3.0), (9, 25, 3.6), (23, 27, 3.6), (13, 19, 2.6), (20, 21, 2.6), (16, 34, 4.6))):
        for y in range(H_ - h, H_):
            t = (y - (H_ - h)) / h
            half = w * 1.6 * t ** .8
            lean = (cx - 16) * .35 * (1 - t)
            for x in range(W_):
                d = x + .5 - cx - lean
                if abs(d) <= half:
                    # a dark rim, a lit left face, a shaded right face, a white ridge near the tip
                    if abs(d) > half - .9:
                        g[y][x] = shard(.08)
                    elif abs(d) < .6 and t < .55:
                        g[y][x] = (255, 255, 255)
                    else:
                        g[y][x] = shard((.95 if d < 0 else .62) - .35 * t)
    out = img.Img(W_ * block, H_ * block)
    for y in range(H_):
        for x in range(W_):
            if g[y][x] is not None:
                for yy in range(y * block, y * block + block):
                    for xx in range(x * block, x * block + block):
                        out.set(xx, yy, g[y][x] + (255,))
    return out


WINTER_NAMES = {'snow_a', 'snow_b', 'snow_c', 'snow_d', 'snowman', 'glacier_a', 'glacier_b', 'ice_crack', 'ice_burst'}


def winter_pieces(block):
    """The snow pieces of one set: name -> image (block 1 = HD, 3 = pixel)."""
    hell_src = HELL if block == 1 else HELL_PIX
    pieces = {('snow_' + k): snow_patch(seed, 120, block) for k, seed in zip('abcd', (3, 11, 19, 27))}
    pieces['snowman'] = snowman(3)
    pieces['glacier_a'] = glacier(img.load(os.path.join(hell_src, 'spire_big.png')), block, 5, 3)
    pieces['glacier_b'] = glacier(img.load(os.path.join(hell_src, 'spire_big_b.png')), block, 9, 3)
    pieces['ice_crack'] = ice_crack(3, 4)
    pieces['ice_burst'] = ice_burst(3, 4)
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
        img.save(im, os.path.join(FROST_HD, name + '.png'))
        hd[name] = {'w': im.w, 'h': im.h, 'kind': m['kind'], 'src': 'hell %s, frozen%s (build_frost_extras.py)' % (src, ', snow cap' if name in CAPPED else '')}
    for name, m in frost.items():
        if name in hell or name in WINTER_NAMES:
            continue
        shutil.copyfile(os.path.join(FROST, name + '.png'), os.path.join(FROST_HD, name + '.png'))
        hd[name] = dict(m)
    # the snow pieces last: the pixel set has its own of the same names
    for name, im in winter_pieces(1).items():
        img.save(im, os.path.join(FROST_HD, name + '.png'))
        hd[name] = {'w': im.w, 'h': im.h, 'kind': 'sprite', 'src': 'drawn: %s (build_frost_extras.py)' % name}
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
    for name in CAPPED:
        path, base = os.path.join(FROST, name + '.png'), os.path.join(BASE, name + '.png')
        if not os.path.exists(path):
            continue
        if not os.path.exists(base):
            shutil.copyfile(path, base)
        save_safe(snowcap(img.load(base), 3, len(name)), path)
    for name, im in winter_pieces(3).items():
        img.save(im, os.path.join(FROST, name + '.png'))
        frost[name] = {'w': im.w, 'h': im.h, 'kind': 'sprite', 'src': 'drawn: %s (build_frost_extras.py)' % name}
        made += 1
    save_manifest(os.path.join(FROST, 'manifest.json'), frost, b'\r\n' in open(os.path.join(FROST, 'manifest.json'), 'rb').read())
    print(made, 'pixel sprites ->', FROST)


if __name__ == '__main__':
    build()
