"""Builds the Hell-Dungeon sprites the world kit needs beyond the hell sheets (key room, boss gate,
banners per floor colour, breakables, furniture, hidden stairs, blue fire of floor 10).

The hell sheets have no fountain, shop, shelves, statues, rugs, crates or the like. Each missing
sprite is taken from its crypt counterpart (assets/sprites/krypta, the same names) and repainted
in the hell palette: its stone in the hell's dark violet-brown stone, its wood charred, its iron
dark; flames, gold, mana and cloth keep their colour. The palette ramps are measured from the hell
sprites themselves. Banners, torches and fire bowls come from the hell sprites (recoloured for
the floor colours and the blue fire). Blood and moss decals keep only the stain: blood stays
blood, moss becomes ash.

Usage (repo root): py -3 -I tools/hell_dungeon/build_hell_extras.py
Writes the PNGs into assets/sprites/hell and adds them to its manifest.json ({name: {w, h, kind, src}}).
No dependencies: uses tools/hell_dungeon/img.py.
"""
import colorsys
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import img  # noqa: E402

ROOT = os.path.join(HERE, '..', '..')
HELL = os.path.join(ROOT, 'assets', 'sprites', 'hell')
KRYPTA = os.path.join(ROOT, 'assets', 'sprites', 'krypta')


def load(d, name):
    return img.load(os.path.join(d, name + '.png'))


def hsv(c):
    return colorsys.rgb_to_hsv(c[0] / 255, c[1] / 255, c[2] / 255)


def lum(c):
    return (0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]) / 255


def ramp_from(names, keep):
    """Average colour per luminance step (24 steps) of the pixels of these hell sprites that keep() accepts."""
    bins = [[0, 0, 0, 0] for _ in range(24)]
    for n in names:
        im = load(HELL, n)
        for y in range(im.h):
            for x in range(im.w):
                c = im.get(x, y)
                if c[3] < 200 or not keep(c):
                    continue
                b = bins[min(23, int(lum(c) * 24))]
                b[0] += c[0]; b[1] += c[1]; b[2] += c[2]; b[3] += 1
    pts = [(k, (b[0] / b[3], b[1] / b[3], b[2] / b[3])) for k, b in enumerate(bins) if b[3] > 6]
    lo, hi = pts[0][0], pts[-1][0]

    def at(t):
        """Colour at 0..1 along the ramp (darkest to lightest measured step)."""
        k = lo + t * (hi - lo)
        for (k0, c0), (k1, c1) in zip(pts, pts[1:]):
            if k0 <= k <= k1:
                f = (k - k0) / (k1 - k0) if k1 > k0 else 0
                return tuple(int(c0[i] + (c1[i] - c0[i]) * f) for i in range(3))
        return tuple(int(v) for v in (pts[0][1] if k < lo else pts[-1][1]))
    return at


def dull(c):
    h, s, v = hsv(c)
    return s < .5 or v < .45


STONE = ramp_from(['wall_h', 'floor_00', 'floor_04', 'rune_pillar_a', 'rune_pillar_b', 'obelisk', 'altar', 'demon_lintel'], dull)
WOOD = ramp_from(['bridge_h', 'bridge_v', 'chest_closed', 'chest_empty'], dull)
IRON = ramp_from(['chain_a', 'chain_b', 'chain_long', 'cage_hang', 'portcullis'], dull)


def flame(c):
    h, s, v = hsv(c)
    return (h < .17 or h > .95) and s > .45 and v > .72


def gold(c):
    h, s, v = hsv(c)
    return .09 < h < .17 and s > .4 and v > .5


def blue(c):
    h, s, v = hsv(c)
    return .47 < h < .75 and s > .3


def cloth(c):
    h, s, v = hsv(c)
    return (h < .04 or h > .9) and s > .45


def repaint(src, mode, keep=('flame', 'gold', 'blue', 'cloth')):
    """Repaints a crypt sprite in the hell palette. mode: 'stone' maps every other pixel to the
    hell stone ramp by its brightness within the sprite; 'wood' maps grey pixels to iron and
    the rest to charred wood."""
    tests = {'flame': flame, 'gold': gold, 'blue': blue, 'cloth': cloth}
    kept = [tests[k] for k in keep]
    px = [(x, y) for y in range(src.h) for x in range(src.w) if src.get(x, y)[3] > 0]
    ls = sorted(lum(src.get(x, y)) for x, y in px if not any(t(src.get(x, y)) for t in kept))
    lo, hi = (ls[len(ls) // 50], ls[-1 - len(ls) // 50]) if ls else (0, 1)
    out = img.Img(src.w, src.h)
    for x, y in px:
        c = src.get(x, y)
        if any(t(c) for t in kept):
            if cloth(c) and 'cloth' in keep:   # the hell's reds are deeper
                h, s, v = hsv(c)
                r, g, b = colorsys.hsv_to_rgb(h, min(1, s * 1.05), v * .82)
                c = (int(r * 255), int(g * 255), int(b * 255), c[3])
            out.set(x, y, c)
            continue
        t = max(0.0, min(1.0, (lum(c) - lo) / max(.01, hi - lo)))
        if mode == 'wood':
            ramp = IRON if hsv(c)[1] < .22 else WOOD
        else:
            ramp = STONE
        out.set(x, y, ramp(t) + (c[3],))
    return out


def hue_to(src, target, test=lambda c: True, sat=1.0):
    """Turns the hue of the pixels test() accepts to target (0..1), keeping brightness."""
    out = img.Img(src.w, src.h, bytearray(src.buf))
    for y in range(src.h):
        for x in range(src.w):
            c = src.get(x, y)
            if c[3] == 0 or not test(c):
                continue
            h, s, v = hsv(c)
            r, g, b = colorsys.hsv_to_rgb(target, min(1, s * sat), v)
            out.set(x, y, (int(r * 255), int(g * 255), int(b * 255), c[3]))
    return out


def red_part(c):
    h, s, v = hsv(c)
    return (h < .08 or h > .9) and s > .35


def warm(c):
    h, s, v = hsv(c)
    return (h < .17 or h > .93) and s > .35 and v > .35


def blue_fire(src):
    """The hell fire turned to the faint blue of floor 10 (yellow cores become white-blue)."""
    out = img.Img(src.w, src.h, bytearray(src.buf))
    for y in range(src.h):
        for x in range(src.w):
            c = src.get(x, y)
            if c[3] == 0 or not warm(c):
                continue
            h, s, v = hsv(c)
            hue = .6 - (.04 if h > .08 and h < .17 else 0)
            r, g, b = colorsys.hsv_to_rgb(hue, s * (.55 if v > .9 else .85), v)
            out.set(x, y, (int(r * 255), int(g * 255), int(b * 255), c[3]))
    return out


def stain(src, keep, paint):
    """Only the stain of a crypt floor decal (keep accepts its pixels), repainted by paint(c)."""
    out = img.Img(src.w, src.h)
    for y in range(src.h):
        for x in range(src.w):
            c = src.get(x, y)
            if c[3] and keep(c):
                out.set(x, y, paint(c))
    return out


def blood(c):
    h, s, v = hsv(c)
    return (h < .05 or h > .92) and s > .35 and v > .2


def moss(c):
    h, s, v = hsv(c)
    return .15 < h < .45 and s > .2


def ash_patch(seed, size=90):
    """A soft patch of ash on the floor (the hell's moss): grey flakes thinning out to the rim,
    a few dim embers in it. Pixel blocks of 3 like the hell sprites."""
    def noise(x, y):
        h = (x * 374761393 + y * 668265263 + seed * 2147483647) & 0xFFFFFFFF
        h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
        return ((h ^ (h >> 16)) & 0xFFFF) / 65535
    out = img.Img(size, size)
    n = size // 3
    cx = cy = n / 2
    for by in range(n):
        for bx in range(n):
            d = ((bx - cx) ** 2 + ((by - cy) * 1.25) ** 2) ** .5 / (n / 2)
            if noise(bx, by) * 1.1 <= d ** 1.6 + .25:
                continue
            g = int(70 + noise(bx + 99, by) * 55)
            c = (215, 80, 40, 235) if noise(bx, by + 77) > .965 and d < .6 else (g + 6, g - 2, g + 2, int(150 + 70 * max(0, 1 - d)))
            for y in range(by * 3, by * 3 + 3):
                for x in range(bx * 3, bx * 3 + 3):
                    out.set(x, y, c)
    return out


def strip_flame(src):
    """A torch with its flame put out (the extinguished torch of the hidden stairs)."""
    out = img.Img(src.w, src.h, bytearray(src.buf))
    for y in range(src.h):
        for x in range(src.w):
            c = src.get(x, y)
            if c[3] and warm(c) and hsv(c)[2] > .5:
                out.set(x, y, (0, 0, 0, 0))
    return out


BANNER_HUE = {'blue': .61, 'green': .33, 'purple': .78, 'gold': .12, 'teal': .48, 'pink': .9}

# crypt sprite -> how it is repainted ('stone', 'wood' or 'keep')
FROM_CRYPT = {
    'fountain': 'stone', 'boss_gate': 'stone', 'boss_arch': 'stone', 'stairs_down': 'stone',
    'moss_rubble_a': 'stone', 'moss_rubble_b': 'stone', 'moss_ruin': 'stone',
    'statue_monk': 'stone', 'gargoyle': 'stone',
    'shop_table': 'wood', 'table_a': 'wood', 'table_b': 'wood', 'table_c': 'wood', 'bench': 'wood', 'shelf': 'wood',
    'barrel_a': 'wood', 'barrel_b': 'wood', 'barrel_c': 'wood', 'crate_a': 'wood', 'crate_b': 'wood', 'crate_c': 'wood',
    'crate_pile': 'wood', 'candelabra': 'wood', 'sacks_a': 'wood', 'sacks_b': 'wood', 'sacks_c': 'wood',
    'urn_a': 'stone', 'urn_b': 'stone', 'urn_c': 'stone', 'urn_d': 'stone', 'urn_e': 'stone',
    'carpet': 'keep', 'rug_red': 'keep', 'rug_blue': 'keep', 'mat': 'keep', 'rug_square': 'keep',
    'chest_vault': 'keep', 'npc_idle_f0': 'keep', 'npc_idle_f1': 'keep', 'npc_idle_f2': 'keep', 'npc_idle_f3': 'keep',
}


def build():
    man_path = os.path.join(HELL, 'manifest.json')
    man = json.load(open(man_path, encoding='utf-8'))
    made = {}

    def put(name, im, src):
        img.save(im, os.path.join(HELL, name + '.png'))
        made[name] = {'w': im.w, 'h': im.h, 'kind': 'sprite', 'src': src}

    for name, mode in FROM_CRYPT.items():
        src = load(KRYPTA, name)
        if mode == 'keep':
            # cloth and gold as they are, the rugs a shade deeper
            im = repaint(src, 'wood', keep=('flame', 'gold', 'blue', 'cloth')) if name in ('carpet', 'rug_red', 'mat', 'rug_square') else src
            if name in ('carpet', 'rug_red', 'mat', 'rug_square'):
                im = rug(src)
            put(name, im, 'krypta ' + name)
        else:
            put(name, repaint(src, mode), 'krypta %s, hell %s' % (name, mode))
    # the key room's two statues are demons in the hell: the gargoyle in hell stone
    put('statue_angel', repaint(load(KRYPTA, 'gargoyle'), 'stone'), 'krypta gargoyle, hell stone')
    # banners: the hell banner, recoloured per floor colour (red stays the hell's own)
    base = load(HELL, 'banner_b')
    put('boss_banner', base, 'hell banner_b')
    for colour, hue in BANNER_HUE.items():
        put('boss_banner_' + colour, hue_to(base, hue, red_part, 1.0), 'hell banner_b, ' + colour)
    # floor 10's blue fire, from the hell's own torches and bowls
    put('brazier_blue', blue_fire(load(HELL, 'brazier_bowl')), 'hell brazier_bowl, blue fire')
    put('bowl_blue', blue_fire(load(HELL, 'brazier_low')), 'hell brazier_low, blue fire')
    put('wall_torch_blue', blue_fire(load(HELL, 'wall_torch_hook')), 'hell wall_torch_hook, blue fire')
    put('wall_v_glow_blue', blue_fire(load(HELL, 'wall_v_glow')), 'hell wall_v_glow, blue glow')
    put('torch_pillar', load(HELL, 'brazier_pillar'), 'hell brazier_pillar')
    put('torch_pillar_blue', blue_fire(load(HELL, 'brazier_pillar')), 'hell brazier_pillar, blue fire')
    put('boss_gate_blue', blue_fire(made_img(made, 'boss_gate')), 'boss_gate, blue fire')
    # the extinguished torch of the hidden stairs: the hell wall torch without its flame
    put('torch_dead', strip_flame(load(HELL, 'wall_torch_hook')), 'hell wall_torch_hook without flame')
    # floor stains: blood stays blood, moss becomes ash
    for k in 'abcdef':
        put('blood_' + k, stain(load(KRYPTA, 'blood_' + k), blood, lambda c: (int(c[0] * .85), int(c[1] * .6), int(c[2] * .6), 235)), 'krypta blood_%s, stain only' % k)
    for k, seed in zip('abc', (3, 11, 23)):
        put('moss_' + k, ash_patch(seed), 'ash patch (moss slot), seed %d' % seed)
    # the mimic a mimic chest wakes as (the crypt's, assets/data/hell_balance.json monsters.borrow),
    # its atlas in charred hell wood with the gold and the glow kept
    mimic = mimic_wood(img.load(os.path.join(KRYPTA, 'monsters', 'mimik.png')))
    img.save(mimic, os.path.join(HELL, 'monsters', 'mimik.png'))
    print('mimic atlas ->', os.path.join(HELL, 'monsters', 'mimik.png'))
    man.update(made)
    text = json.dumps(man, indent=1, ensure_ascii=False).replace('\n', '\r\n')
    open(man_path, 'w', encoding='utf-8', newline='').write(text)
    print(len(made), 'sprites ->', HELL)
    # the same pieces for the pixel graphics set (assets/sprites/hell_0x72)
    pman_path = os.path.join(PIXEL, 'manifest.json')
    pman = json.load(open(pman_path, encoding='utf-8'))
    pixel = lambda n: img.load(os.path.join(PIXEL, n + '.png'))
    # pieces the hell has itself come from the pixel set's own sprites, the figure stays as it is
    own = {'boss_banner': lambda: pixel('banner_b'), 'brazier_blue': lambda: blue_fire(pixel('brazier_bowl')),
           'bowl_blue': lambda: blue_fire(pixel('brazier_low')), 'wall_torch_blue': lambda: blue_fire(pixel('wall_torch_hook')),
           'wall_v_glow_blue': lambda: blue_fire(pixel('wall_v_glow')), 'torch_pillar': lambda: pixel('brazier_pillar'),
           'torch_pillar_blue': lambda: blue_fire(pixel('brazier_pillar')), 'torch_dead': lambda: strip_flame(pixel('wall_torch_hook'))}
    for colour, hue in BANNER_HUE.items():
        own['boss_banner_' + colour] = (lambda hue=hue: hue_to(pixel('banner_b'), hue, red_part, 1.0))
    for name in made:
        if name.startswith('npc_idle'):
            im = img.load(os.path.join(HELL, name + '.png'))
        elif name in own:
            im = own[name]()
        else:
            im = pixelize(img.load(os.path.join(HELL, name + '.png')))
        if not name.startswith('npc_idle'):
            im = quantize(im)
        img.save(im, os.path.join(PIXEL, name + '.png'))
        pman[name] = {'h': im.h, 'kind': 'sprite', 'src': 'hell %s in the 0x72 manner (build_hell_extras.py)' % name, 'w': im.w}
    text = json.dumps(dict(sorted(pman.items())), indent=1, ensure_ascii=False, sort_keys=True)
    open(pman_path, 'w', encoding='utf-8', newline='\n').write(text + '\n')
    print(len(made), 'pixel sprites ->', PIXEL)


PIXEL = os.path.join(ROOT, 'assets', 'sprites', 'hell_0x72')
# the pixel set's hell palette: HEX of scripts/make_hell_skin.gd (tests/hell_skin_test.gd allows no other colour)
_HEX = open(os.path.join(ROOT, 'scripts', 'make_hell_skin.gd'), encoding='utf-8').read()
_HEX = _HEX[_HEX.index('const HEX := {'):]
_HEX = _HEX[:_HEX.index('\n}')]
PALETTE = [tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) for h in re.findall(r'"[a-z0-9]+": "([0-9a-f]{6})"', _HEX)]
INK = (0x12, 0x0a, 0x12, 255)


def pixelize(src, f=6, k=3):
    """An HD hell sprite in the 0x72 manner: one source pixel per f x f block (half the HD size in
    the world at k = 3), its colour snapped to the hell palette, a 1 px dark outline."""
    w, h = max(1, (src.w + f - 1) // f), max(1, (src.h + f - 1) // f)
    grid = [[None] * w for _ in range(h)]
    for by in range(h):
        for bx in range(w):
            cs = [src.get(x, y) for y in range(by * f, min(src.h, by * f + f)) for x in range(bx * f, min(src.w, bx * f + f))]
            solid = [c for c in cs if c[3] > 110]
            if len(solid) * 2 < len(cs):
                continue
            avg = tuple(sum(c[i] for c in solid) // len(solid) for i in range(3))
            grid[by][bx] = snap(avg)
    out = img.Img((w + 2) * k, (h + 2) * k)
    for by in range(-1, h + 1):
        for bx in range(-1, w + 1):
            c = grid[by][bx] if 0 <= by < h and 0 <= bx < w else None
            if c is None and any(0 <= by + dy < h and 0 <= bx + dx < w and grid[by + dy][bx + dx] is not None for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                c = INK
            if c is None:
                continue
            for y in range((by + 1) * k, (by + 2) * k):
                for x in range((bx + 1) * k, (bx + 2) * k):
                    out.set(x, y, c)
    return out


def snap(c):
    """The nearest colour of the pixel set's palette."""
    best = min(PALETTE, key=lambda p: 2 * (p[0] - c[0]) ** 2 + 4 * (p[1] - c[1]) ** 2 + 3 * (p[2] - c[2]) ** 2)
    return best + (255,)


def quantize(src):
    """Every opaque pixel snapped to the pixel set's palette, the rest cleared."""
    out = img.Img(src.w, src.h)
    for y in range(src.h):
        for x in range(src.w):
            c = src.get(x, y)
            if c[3] > 127:
                out.set(x, y, snap(c))
    return out


def mimic_wood(src):
    """The 0x72 mimic in hell wood: its orange-brown planks charred (the hell chest's wood), its
    gold fittings, teeth, tongue and dark outline as they are."""
    def kept(c):
        h, s, v = hsv(c)
        return v < .2 or (s < .2 and v > .8) or (.85 < h or h < .02) and s > .3 and v > .6 or (.11 < h < .18 and s > .5 and v > .75)
    px = [(x, y) for y in range(src.h) for x in range(src.w) if src.get(x, y)[3] and not kept(src.get(x, y))]
    ls = sorted(lum(src.get(x, y)) for x, y in px)
    lo, hi = (ls[len(ls) // 50], ls[-1 - len(ls) // 50]) if ls else (0, 1)
    out = img.Img(src.w, src.h, bytearray(src.buf))
    for x, y in px:
        c = src.get(x, y)
        t = max(0.0, min(1.0, (lum(c) - lo) / max(.01, hi - lo)))
        out.set(x, y, WOOD(t * .9) + (c[3],))
    return out


def made_img(made, name):
    return img.load(os.path.join(HELL, name + '.png'))


def rug(src):
    """A rug in the hell's deeper crimson, its gold border kept."""
    out = img.Img(src.w, src.h, bytearray(src.buf))
    for y in range(src.h):
        for x in range(src.w):
            c = src.get(x, y)
            if c[3] == 0 or gold(c) or blue(c):
                continue
            h, s, v = hsv(c)
            r, g, b = colorsys.hsv_to_rgb(.99 if h > .5 or h < .06 else h, min(1, s * 1.1), v * .78)
            out.set(x, y, (int(r * 255), int(g * 255), int(b * 255), c[3]))
    return out


if __name__ == '__main__':
    build()
