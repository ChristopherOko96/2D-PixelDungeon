"""The snowy HD set of the Frostgruft from the user's drawn snow assets.

Source: tools/frost_dungeon/snow_hd_src/ (Frost_mit_Schnee.zip, 2026-10-30): the HD props and walls
redrawn with snow, about twice the game's size, cut from a sheet with some padding and neighbour
fragments. Every HD sprite that stands in the snow takes its look from there; where the zip has no
fitting drawing the sprite is drawn in the same style from its snowless original
(assets/sprites/frost_hd/frost_ohne_schnee/): a snow cushion on its upper edges with a dark outline
and a row of snow puffs over its foot.

Each sprite keeps its old canvas size (the world kit lays the floors out from the HD manifest), so a
drawing is cleaned of fragments, trimmed and fitted into that canvas, keeping its proportions.
The floors, the thaw patches and the winter pieces stay as build_frost_extras.py draws them.

py -3 -I tools/frost_dungeon/snow_hd.py   (also run at the end of build_frost_extras.py)
"""
import json
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, '..', '..')
sys.path.insert(0, os.path.join(ROOT, 'tools', 'hell_dungeon'))
import img  # noqa: E402

SRC = os.path.join(HERE, 'snow_hd_src')
OUT = os.path.join(ROOT, 'assets', 'sprites', 'frost_hd')
BARE = os.path.join(OUT, 'frost_ohne_schnee')

# HD name -> the zip drawing it takes (same name unless given)
FROM_ZIP = {
    'altar': 'altar', 'banner_1': 'banner_1', 'banner_2': 'banner_2', 'banner_3': 'banner_3',
    'barrel_a': 'barrel_a', 'barrel_b': 'barrel_b', 'barrel_c': 'barrel_c', 'bench': 'bench', 'bones_t': 'bones_t',
    'boulders': 'boulders', 'rocks_b': 'boulders_large', 'skull_pile': 'skull_pile_small',
    'bowl_blue': 'bowl_blue', 'brazier_blue': 'brazier_blue', 'brazier_bowl': 'brazier_bowl', 'brazier_demon': 'brazier_demon',
    'brazier_floor': 'brazier_floor', 'brazier_low': 'brazier_low', 'brazier_low_b': 'brazier_low_b', 'brazier_rune': 'brazier_rune',
    'bridge_h': 'bridge_h', 'bridge_v': 'bridge_v', 'cage_hang': 'cage_hang', 'cage_small': 'cage_small', 'candelabra': 'candelabra',
    'carpet': 'carpet', 'chest_closed': 'chest_closed', 'chest_open': 'chest_open', 'coal': 'coal', 'coal_skulls': 'coal_skulls',
    'corner_cap': 'corner_cap', 'crate_pile': 'crate_pile', 'demon_head': 'demon_head', 'demon_plate': 'demon_plate',
    'door_stairs': 'door_stairs', 'door_stairs_small': 'door_stairs_arch', 'fire_plate': 'fire_plate', 'fountain': 'fountain',
    'gargoyle': 'gargoyle', 'gate_side': 'gate_side', 'grate': 'grate', 'grate_b': 'grate_b', 'hanging_brazier': 'hanging_brazier',
    'torch_pillar_blue': 'torch_pillar_blue', 'torch_pillar': 'torch_pillar_blue', 'brazier_pillar': 'brazier_rune',
    'vent': 'vent', 'wall_brazier': 'wall_brazier',
}
# the user's second sheet (assets_mit_schnee.png, 2026-10-30): the snowless sprites redrawn with
# snow, on a dark ground in an 8 x 7 grid, in this order; None = a cell drawn across its neighbours
# (the wide wall gates and the fire pillar grown into them): those come from the zip or their originals
SHEET = os.path.join(SRC, 'sheet_missing_snow.png')
SHEET_GRID = (8, 7)
SHEET_ORDER = [None, None, None, None, 'chest_empty', 'chest_gold', 'chest_vault', 'crate_a',
               'crate_b', 'crate_c', 'jamb_b', 'moss_rubble_a', 'moss_rubble_b', 'moss_ruin', 'obelisk', 'portal',
               'portal_dark', 'rocks_a', 'rocks_dark', 'rocks_lava', 'rune_pillar_a', 'rune_pillar_b', 'rune_pillar_c', 'rune_pillar_d',
               'sacks_a', 'sacks_b', 'sacks_c', 'shelf', 'shop_table', 'skull_heap', 'skull_obelisk', 'skull_pile',
               'spire_big', 'spire_big_b', 'spire_big_t', 'spire_mid', 'spire_small', 'spire_t', 'spires_lava', 'spires_t',
               'stairs_down', 'statue_angel', 'statue_monk', 'table_a', 'table_b', 'table_c', 'torch_pillar', 'urn_a',
               'urn_b', 'urn_c', 'urn_d', 'urn_e', 'wall_h_glowpost', 'wall_post_slit']
# hung on a wall or from the ceiling: fitted to the top of the canvas; flat on the floor: centred
TOP = {'banner_1', 'banner_2', 'banner_3', 'cage_hang', 'hanging_brazier', 'wall_brazier'}
FLAT = {'bridge_h', 'bridge_v', 'carpet', 'demon_plate', 'fire_plate', 'grate', 'grate_b', 'vent'}
# drawn in the zip style from the snowless original
DRAWN = ['boss_arch', 'boss_gate', 'boss_gate_blue', 'chest_empty', 'chest_gold', 'chest_vault', 'crate_a', 'crate_b', 'crate_c',
         'demon_lintel', 'jamb_a', 'jamb_b', 'moss_rubble_a', 'moss_rubble_b', 'moss_ruin', 'obelisk', 'portal', 'portal_dark',
         'portcullis', 'rocks_lava', 'rune_pillar_a', 'rune_pillar_b', 'rune_pillar_c', 'rune_pillar_d', 'sacks_a', 'sacks_b',
         'sacks_c', 'shelf', 'skull_heap', 'skull_obelisk', 'spire_big', 'spire_big_b', 'spire_big_t', 'spire_mid', 'spire_small',
         'spire_t', 'spires_lava', 'spires_t', 'stairs_down', 'statue_angel', 'statue_monk', 'table_a', 'table_b', 'table_c',
         'urn_a', 'urn_b', 'urn_c', 'urn_d', 'urn_e', 'wall_h_glowpost', 'wall_post_slit', 'wall_v_glow', 'wall_v_glow_b',
         'wall_v_glow_blue']
# set into a wall: a cap on top, no puffs (the wall's own foot carries the snow)
NO_FOOT = {'demon_lintel', 'portcullis', 'boss_arch', 'boss_gate', 'boss_gate_blue', 'wall_h_glowpost', 'wall_post_slit',
           'jamb_a', 'jamb_b', 'wall_v_glow', 'wall_v_glow_b', 'wall_v_glow_blue', 'stairs_down'}
# snowless originals with a stray speck from their cut (scattered rubble keeps all its stones)
SPECKED = {'sacks_a'}
# the warm shop: a light dusting only
DUSTED = ['shop_table']

# the zip's snow: dark outline, cold shade, body, light
INK = (22, 32, 66)
SHADE2 = (104, 136, 192)
SHADE1 = (164, 190, 230)
BODY = (218, 230, 248)
LIGHT = (248, 251, 255)


def h1(i, seed):
    v = (i * 374761393 + seed * 668265263) & 0xffffffff
    v = ((v ^ (v >> 13)) * 1274126177) & 0xffffffff
    return ((v ^ (v >> 16)) & 0xffff) / 65535.0


def smooth(x, seed):
    i = math.floor(x)
    f = x - i
    f = f * f * (3 - 2 * f)
    return h1(i, seed) * (1 - f) + h1(i + 1, seed) * f


def alpha(im, x, y):
    return im.buf[(y * im.w + x) * 4 + 3] if 0 <= x < im.w and 0 <= y < im.h else 0


# ---------- the zip drawings ----------

def clean(im):
    """Keeps the drawing and drops what the cut took from its neighbours: the largest opaque region,
    plus regions of a twentieth of its size that do not touch the cut's edge; thin lines (a sheet's
    grid) go too."""
    w, h = im.w, im.h
    label = [0] * (w * h)
    regions = []   # [pixels, x0, y0, x1, y1]
    for start in range(w * h):
        if label[start] or im.buf[start * 4 + 3] < 60:
            continue
        rid = len(regions) + 1
        label[start] = rid
        stack, got = [start], []
        x0 = x1 = start % w
        y0 = y1 = start // w
        while stack:
            p = stack.pop()
            got.append(p)
            px, py = p % w, p // w
            x0, x1, y0, y1 = min(x0, px), max(x1, px), min(y0, py), max(y1, py)
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    nx, ny = px + dx, py + dy
                    if 0 <= nx < w and 0 <= ny < h:
                        q = ny * w + nx
                        if not label[q] and im.buf[q * 4 + 3] >= 60:
                            label[q] = rid
                            stack.append(q)
        regions.append((got, x0, y0, x1, y1))
    if not regions:
        return im
    big = max(len(r[0]) for r in regions)
    mask = bytearray(w * h)
    for got, x0, y0, x1, y1 in regions:
        n = len(got)
        edge = x0 == 0 or y0 == 0 or x1 == w - 1 or y1 == h - 1
        thin = min(x1 - x0, y1 - y0) < 3
        if n == big or (n >= big * .05 and not edge and not thin):
            for p in got:
                mask[p] = 1
    # soft edge pixels next to a kept pixel stay
    out = img.Img(w, h)
    for y in range(h):
        for x in range(w):
            i = y * w + x
            near = mask[i] or any(0 <= x + dx < w and 0 <= y + dy < h and mask[(y + dy) * w + x + dx]
                                  for dx in (-1, 0, 1) for dy in (-1, 0, 1))
            if near:
                out.buf[i * 4:i * 4 + 4] = im.buf[i * 4:i * 4 + 4]
    return out


def trim(im, thr=8):
    xs = [x for x in range(im.w) if any(alpha(im, x, y) > thr for y in range(im.h))]
    ys = [y for y in range(im.h) if any(alpha(im, x, y) > thr for x in range(im.w))]
    if not xs:
        return im
    return im.crop(xs[0], ys[0], xs[-1] - xs[0] + 1, ys[-1] - ys[0] + 1)


def resize(im, nw, nh):
    """Area-average resampling with premultiplied alpha (a clean downscale of the drawings)."""
    sx, sy = im.w / nw, im.h / nh
    out = img.Img(nw, nh)
    for y in range(nh):
        y0, y1 = y * sy, (y + 1) * sy
        for x in range(nw):
            x0, x1 = x * sx, (x + 1) * sx
            r = g = b = a = wsum = 0.0
            for yy in range(int(y0), min(im.h, int(math.ceil(y1)))):
                wy = min(y1, yy + 1) - max(y0, yy)
                if wy <= 0:
                    continue
                for xx in range(int(x0), min(im.w, int(math.ceil(x1)))):
                    wx = min(x1, xx + 1) - max(x0, xx)
                    if wx <= 0:
                        continue
                    wgt = wx * wy
                    i = (yy * im.w + xx) * 4
                    pa = im.buf[i + 3] / 255.0
                    r += im.buf[i] * pa * wgt
                    g += im.buf[i + 1] * pa * wgt
                    b += im.buf[i + 2] * pa * wgt
                    a += pa * wgt
                    wsum += wgt
            if a <= 0 or wsum <= 0:
                continue
            al = a / wsum
            if al < .12:
                continue
            al = min(1.0, al * 1.08)
            out.set(x, y, (min(255, int(r / a + .5)), min(255, int(g / a + .5)), min(255, int(b / a + .5)), int(al * 255 + .5)))
    return out


def fit(im, w, h, align='bottom'):
    """The drawing as large as fits into a w x h canvas, keeping its proportions."""
    s = min(w / im.w, h / im.h)
    nw, nh = max(1, round(im.w * s)), max(1, round(im.h * s))
    small = resize(im, nw, nh)
    out = img.Img(w, h)
    oy = {'bottom': h - nh, 'top': 0, 'center': (h - nh) // 2}[align]
    out.paste(small, (w - nw) // 2, oy)
    return out


_sheet = None


def sheet_cell(name):
    """The drawing in the user's sheet. Its cell grown by a margin (drawings reach past their cell),
    the dark ground cleared by a fill from the border, the grey-violet grid lines cleared by colour;
    of what is left the regions whose centre lies in the cell stay (neighbours' parts go)."""
    global _sheet
    if _sheet is None:
        _sheet = img.load(SHEET)
    i = SHEET_ORDER.index(name)
    cols, rows = SHEET_GRID
    cw, ch = _sheet.w / cols, _sheet.h / rows
    m = 30
    cx0, cy0 = (i % cols) * cw, (i // cols) * ch
    x0, y0 = max(0, int(cx0) - m), max(0, int(cy0) - m)
    x1, y1 = min(_sheet.w, int(cx0 + cw) + m), min(_sheet.h, int(cy0 + ch) + m)
    cell = _sheet.crop(x0, y0, x1 - x0, y1 - y0)
    w, h = cell.w, cell.h

    def ground(x, y):
        r, g, b, _ = cell.get(x, y)
        return max(r, g, b) < 70 and b - r < 22 and abs(g - r) < 10

    def line(x, y):
        r, g, b, _ = cell.get(x, y)
        return max(r, g, b) <= 135 and abs(g - r) <= 6 and 12 <= b - r <= 45

    seen = bytearray(w * h)
    stack = [(x, y) for x in range(w) for y in (0, h - 1)] + [(x, y) for y in range(h) for x in (0, w - 1)]
    while stack:
        x, y = stack.pop()
        if not (0 <= x < w and 0 <= y < h) or seen[y * w + x] or not (ground(x, y) or line(x, y)):
            continue
        seen[y * w + x] = 1
        cell.buf[(y * w + x) * 4 + 3] = 0
        stack += [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]
    for y in range(h):
        for x in range(w):
            if line(x, y) and all(alpha(cell, x + dx, y + dy) == 0 or line(x + dx, y + dy)
                                  for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                cell.buf[(y * w + x) * 4 + 3] = 0
    # the regions of this cell
    label = [0] * (w * h)
    regions = []
    for start in range(w * h):
        if label[start] or cell.buf[start * 4 + 3] < 60:
            continue
        label[start] = 1
        stack, got = [start], []
        while stack:
            p = stack.pop()
            got.append(p)
            px, py = p % w, p // w
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    nx, ny = px + dx, py + dy
                    if 0 <= nx < w and 0 <= ny < h and not label[ny * w + nx] and cell.buf[(ny * w + nx) * 4 + 3] >= 60:
                        label[ny * w + nx] = 1
                        stack.append(ny * w + nx)
        sx = sum(p % w for p in got) / len(got) + x0
        sy = sum(p // w for p in got) / len(got) + y0
        xs_, ys_ = [p % w for p in got], [p // w for p in got]
        thin = min(max(xs_) - min(xs_), max(ys_) - min(ys_)) < 4   # a grid line's remnant
        mine = cx0 <= sx < cx0 + cw and cy0 <= sy < cy0 + ch and not thin
        regions.append((got, mine))
    big = max((len(g) for g, mine in regions if mine), default=0)
    out = img.Img(w, h)
    keep = bytearray(w * h)
    for got, mine in regions:
        if mine and len(got) >= max(12, big * .03):
            for p in got:
                keep[p] = 1
    for y in range(h):
        for x in range(w):
            i = y * w + x
            if keep[i] or any(0 <= x + dx < w and 0 <= y + dy < h and keep[(y + dy) * w + x + dx]
                              for dx in (-1, 0, 1) for dy in (-1, 0, 1)):
                if cell.buf[i * 4 + 3]:
                    out.buf[i * 4:i * 4 + 4] = cell.buf[i * 4:i * 4 + 4]
    return trim(out)


def from_zip(name, w, h):
    src = img.load(os.path.join(SRC, FROM_ZIP[name] + '.png'))
    align = 'top' if name in TOP else 'center' if name in FLAT else 'bottom'
    return fit(trim(clean(src)), w, h, align)


# ---------- the zip style on the snowless originals ----------

def snow_colour(t):
    """t 0 = the cushion's lit top, 1 = its shaded underside."""
    if t < .25:
        return LIGHT
    if t < .7:
        return BODY
    return SHADE1


def cap(im, seed, depth=4, ledges=True):
    """A snow cushion on the upper edges: thicker on the top edge, a puffy wavy top with the zip's
    dark outline, its underside in cold shade and a few short drips."""
    w, h = im.w, im.h
    out = img.Img(w, h, bytearray(im.buf))
    solid = lambda x, y: alpha(im, x, y) > 110
    top = {}
    for x in range(w):
        for y in range(h):
            if solid(x, y):
                top[x] = y
                break
    snow = {}
    for x in range(w):
        for y in range(h):
            if not solid(x, y) or solid(x, y - 1):
                continue
            first = top.get(x) == y
            if not first and (not ledges or y > h * .7):
                continue
            n = smooth(x / 5.0, seed + (0 if first else 31))
            d = (depth + int(n * 2.99)) if first else max(2, depth - 2 + int(n * 1.99))
            # its puffy top rises above the edge a little, where there is room
            rise = int(smooth(x / (depth * 1.4), seed + 7) * (depth * .7 + 1)) if first else int(smooth(x / 3.0, seed + 9) * 1.5)
            for k in range(-rise, d):
                yy = y + k
                if yy < 0 or yy >= h or (k >= 0 and not solid(x, yy)):
                    continue
                snow[(x, yy)] = (k + rise) / max(1, d + rise - 1)
            # drips from the underside
            if first and h1(x, seed + 3) > .9 and d + 2 < h:
                for k in range(d, d + 1 + int(h1(x, seed + 4) * 2.99)):
                    if solid(x, y + k):
                        snow[(x, y + k)] = .8
    for (x, y), t in snow.items():
        out.set(x, y, snow_colour(t) + (255,))
    # the outline round the snow where it meets the air, a cold line where it lies on the thing
    for (x, y) in list(snow):
        for dx, dy in ((0, -1), (-1, 0), (1, 0), (0, 1)):
            nx, ny = x + dx, y + dy
            if (nx, ny) in snow or not (0 <= nx < w and 0 <= ny < h):
                continue
            if alpha(im, nx, ny) <= 110:
                out.set(nx, ny, INK + (255,))
            elif dy == 1:
                o = im.get(nx, ny)
                out.set(nx, ny, ((o[0] + SHADE2[0]) // 2, (o[1] + SHADE2[1]) // 2, (o[2] + SHADE2[2]) // 2, 255))
    return out


def puffs(im, seed, size=1.0):
    """The thing shrinks a little and rises off the canvas floor; a row of snow puffs covers its
    foot, overlapping, lit from the upper left, with the dark outline."""
    w, h = im.w, im.h
    body = trim(im, 40)
    # puffs about a tenth of the thing's width, as in the zip drawings
    base = min(body.w, 150)
    r_lo, r_hi = max(3.5, base * .075) * size, max(5.0, base * .115) * size
    margin = int(r_hi * .75)
    s = min(1.0, (h - margin) / body.h, w / body.w)
    nw, nh = max(1, round(body.w * s)), max(1, round(body.h * s))
    body = resize(body, nw, nh) if s < 1.0 else body
    out = img.Img(w, h)
    bx = (w - nw) // 2
    out.paste(body, bx, h - margin - nh)
    foot = h - margin - 1
    # where the thing touches the ground: the columns of its lowest rows
    xs = [x for x in range(w) if any(alpha(out, x, y) > 110 for y in range(max(0, foot - 3), foot + 1))]
    if not xs:
        return out
    lo, hi = xs[0], xs[-1]
    mid, half = (lo + hi) / 2.0, max(1.0, (hi - lo) / 2.0)
    circles = []
    x = lo - r_lo * .5
    i = 0
    while x <= hi + r_lo * .5:
        # bigger mounds towards the middle, smaller ones spilling past the sides
        k = 1.0 - min(1.0, abs(x - mid) / (half + r_lo)) * .45
        r = (r_lo + (r_hi - r_lo) * h1(i, seed)) * k
        cy = foot - r * (.05 + .3 * h1(i, seed + 2))
        circles.append((x, cy, r))
        x += r * (.95 + .3 * h1(i, seed + 5))
        i += 1
    # a few small ones in front, low on the ground
    for j in range(max(1, len(circles) // 3)):
        cx = lo + (hi - lo) * h1(j, seed + 11)
        r = r_lo * (.55 + .2 * h1(j, seed + 12))
        circles.append((cx, foot + r * .35, r))
    # back to front: each mound over the ones behind it, lit by its own surface (light from the
    # upper left), outlined where it stands against the air or the mound behind
    lx, ly = -.45, -.85
    snowed = set()
    for cx, cy, r in sorted(circles, key=lambda c: c[1] + c[2] * .2):
        for y in range(int(cy - r) - 2, int(cy + r) + 3):
            for x in range(int(cx - r) - 2, int(cx + r) + 3):
                if not (0 <= x < w and 0 <= y < h):
                    continue
                dx, dy = x + .5 - cx, y + .5 - cy
                d = math.sqrt(dx * dx + dy * dy)
                if d > r + 1.0:
                    continue
                if d > r:
                    if dy < r * .55:   # the outline, open at the mound's base; a soft seam over snow
                        out.set(x, y, (SHADE2 if (x, y) in snowed else INK) + (255,))
                    continue
                nz = math.sqrt(max(0.0, 1 - (d / r) ** 2))
                lit = (dx / r) * lx + (dy / r) * ly + nz * .55
                c = LIGHT if lit > .78 else BODY if lit > .32 else SHADE1 if lit > -.1 else SHADE2
                out.set(x, y, c + (255,))
                snowed.add((x, y))
    return out


def dust(im, seed):
    """A few light flecks of snow on the upper edges (the warm shop)."""
    w, h = im.w, im.h
    out = img.Img(w, h, bytearray(im.buf))
    for x in range(w):
        if smooth(x / 6.0, seed) < .72:
            continue
        for y in range(h):
            if alpha(im, x, y) > 110:
                out.set(x, y, LIGHT + (255,))
                if y + 1 < h and alpha(im, x, y + 1) > 110:
                    out.set(x, y + 1, SHADE1 + (255,))
                break
    return out


def drawn(name):
    im = img.load(os.path.join(BARE, name + '.png'))
    if name in SPECKED:
        im = clean(im)
    seed = sum(map(ord, name))
    depth = max(3, min(8, round(min(im.w, im.h) * .07)))
    # room above for the cushion's puffy top
    room = int(depth * .7 + 1)
    body = trim(im, 40)
    if body.h > im.h - room:
        s = (im.h - room) / body.h
        body = resize(body, max(1, round(body.w * s)), max(1, round(body.h * s)))
    roomy = img.Img(im.w, im.h)
    roomy.paste(body, (im.w - body.w) // 2, im.h - body.h)
    im = cap(roomy, seed, depth)
    if name not in NO_FOOT:
        im = puffs(im, seed)
    return im


def flip_h(im):
    out = img.Img(im.w, im.h)
    for y in range(im.h):
        for x in range(im.w):
            i, j = (y * im.w + x) * 4, (y * im.w + im.w - 1 - x) * 4
            out.buf[j:j + 4] = im.buf[i:i + 4]
    return out


# the north and south walls: a run of the zip wall between its end blocks, mirrored so the strip
# repeats without a seam; WALL_FACE = the game's wall face (px), WALL_FACE_SRC = the zip rows down to
# the stone's foot: the snow below it hangs over the floor
WALL_CUT = (72, 165)
WALL_FACE, WALL_FACE_SRC = 74, 88


def wall_h():
    src = trim(clean(img.load(os.path.join(SRC, 'wall_h.png'))))
    run = src.crop(WALL_CUT[0], 0, WALL_CUT[1] - WALL_CUT[0], src.h)
    pair = img.Img(run.w * 2, run.h)
    pair.paste(run, 0, 0)
    pair.paste(flip_h(run), run.w, 0)
    s = WALL_FACE / WALL_FACE_SRC
    return resize(pair, round(pair.w * s), round(pair.h * s))


def wall_v():
    """The side walls' crown seen from above under drifted snow: a height field of soft mounds
    (repeating with the tile's height, so the run has no seam) where it lies deep enough, lit from
    the upper left with the zip's shades and outline; stone shows at the thin edges and the glowing
    inner edge stays free."""
    im = img.load(os.path.join(BARE, 'wall_v.png'))
    w, h = im.w, im.h
    out = img.Img(w, h, bytearray(im.buf))
    xs = [x for x in range(w) if alpha(im, x, h // 2) > 110]
    lo, hi = xs[0], xs[-1]
    a0, b0 = lo + 2, hi - 9
    mid, half = (a0 + b0) / 2.0, (b0 - a0) / 2.0
    tau = 2 * math.pi

    # overlapping round mounds along the crown, wrapped round the tile's height
    blobs = []
    for i in range(11):
        by = (i + .4 * h1(i, 5)) * h / 11.0
        bx = mid + (h1(i, 6) - .5) * half * 1.0
        blobs.append((bx, by, half * (.5 + .3 * h1(i, 7))))

    def height(x, y):
        best = -1.0
        for bx, by, r in blobs:
            for wrap in (-h, 0, h):
                dx, dy = (x - bx) / r, (y - by - wrap) / r
                best = max(best, 1 - dx * dx - dy * dy)
        return best

    field = {}
    for y in range(h):
        for x in range(a0, b0 + 1):
            hv = height(x, y)
            if hv > 0:
                field[(x, y)] = hv
    for (x, y), hv in field.items():
        # light from the upper left on the field's slope (wrapping in y)
        gx = height(x + 1, y) - height(x - 1, y)
        gy = height(x, (y + 1) % h) - height(x, (y - 1) % h)
        lit = (gx * .55 + gy * .85) * -3.0 + hv * .5
        c = LIGHT if lit > .55 else BODY if lit > .12 else SHADE1 if lit > -.25 else SHADE2
        out.set(x, y, c + (255,))
    for (x, y) in list(field):
        for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
            n = (x + dx, (y + dy) % h)
            if n not in field and lo <= x + dx <= hi:
                out.set(x + dx, (y + dy) % h, INK + (255,))
    return out


def build():
    made = []
    for name, make in (('wall_h', wall_h), ('wall_v', wall_v)):
        img.save(make(), os.path.join(OUT, name + '.png'))
        made.append(name)
    # the first, snowless wall for wall cells whose foot touches no snow (hell_game.gd _strip)
    img.save(img.load(os.path.join(BARE, 'wall_h.png')), os.path.join(OUT, 'wall_h_bare.png'))
    for name in sorted(FROM_ZIP):
        bare = os.path.join(BARE, name + '.png')
        if not os.path.exists(bare):
            continue
        base = img.load(bare)
        img.save(from_zip(name, base.w, base.h), os.path.join(OUT, name + '.png'))
        made.append(name)
    for name in DRAWN:
        if not os.path.exists(os.path.join(BARE, name + '.png')) or name in SHEET_ORDER:
            continue
        img.save(drawn(name), os.path.join(OUT, name + '.png'))
        made.append(name)
    for name in SHEET_ORDER:
        if name is None:
            continue
        base = img.load(os.path.join(BARE, name + '.png'))
        img.save(fit(sheet_cell(name), base.w, base.h), os.path.join(OUT, name + '.png'))
        made.append(name)
    for name in DUSTED:
        if name in SHEET_ORDER:
            continue
        img.save(dust(img.load(os.path.join(BARE, name + '.png')), sum(map(ord, name))), os.path.join(OUT, name + '.png'))
        made.append(name)
    manifest(made)
    return made


def manifest(made):
    """The HD manifest's entries of the sprites made here (sizes, source)."""
    path = os.path.join(OUT, 'manifest.json')
    man = json.load(open(path, encoding='utf-8'))
    for name in made + ['wall_h_bare']:
        im = img.load(os.path.join(OUT, name + '.png'))
        src = ('the zip %s (snow_hd.py)' % FROM_ZIP[name] if name in FROM_ZIP else
               "the user's sheet, cell %s (snow_hd.py)" % name if name in SHEET_ORDER else
               'the zip wall run, mirrored (snow_hd.py)' if name == 'wall_h' else
               'frost_ohne_schnee wall_h: walls off the snow (snow_hd.py)' if name == 'wall_h_bare' else
               'frost_ohne_schnee %s in the zip snow style (snow_hd.py)' % name)
        entry = dict(man.get(name, man.get('wall_h', {})))
        entry.update({'w': im.w, 'h': im.h, 'src': src})
        man[name] = entry
    text = json.dumps(dict(sorted(man.items())), indent=1, ensure_ascii=False, sort_keys=True) + '\n'
    open(path, 'w', encoding='utf-8', newline='').write(text)


if __name__ == '__main__':
    names = sys.argv[1:]
    if names:
        for n in names:
            b = img.load(os.path.join(BARE, n + '.png'))
            im = fit(sheet_cell(n), b.w, b.h) if n in SHEET_ORDER else from_zip(n, b.w, b.h) if n in FROM_ZIP else dust(b, sum(map(ord, n))) if n in DUSTED else drawn(n)
            img.save(im, os.path.join(OUT, n + '.png'))
        print(len(names), 'HD snow sprites ->', OUT)
    else:
        print(len(build()), 'HD snow sprites ->', OUT)
