"""Builds the crypt sprite skin (Story 1, Krypta der Verdammten) from the user's asset set.

Every name the Hell-Dungeon core and preview draw (assets/sprites/hell/manifest.json) gets a
crypt counterpart cut from Krypta_Asset_Set_Komplett.zip (01_Einzelassets_Transparent), so the
hell generator, dressing rules and runtime run unchanged with the crypt look. The poison mire
that replaces lava is the hell lava recoloured; the heart pickup keeps the hell sprite.

Usage (repo root, set extracted):
  py -3 -I tools/krypta_dungeon/build_krypta_skin.py "<extracted>/Krypta_Asset_Set" <out_dir>
Writes <name>.png and manifest.json ({name: {w, h, kind, src}}) like the hell skin.
No dependencies: uses tools/hell_dungeon/img.py.
"""
import colorsys
import json
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', 'hell_dungeon'))
import img  # noqa: E402

SET, OUT = sys.argv[1], sys.argv[2]
HELL = os.path.join(HERE, '..', '..', 'assets', 'sprites', 'hell')
SLAB = 96
PREFIX = {'D': '01_dekoration_loot_', 'I': '02_krypta_interieur_', 'B': '03_krypta_bausteine_'}
MAN = {a['id']: a for a in json.load(open(os.path.join(SET, '03_Vorschau_und_Dokumentation', 'asset_manifest.json'), encoding='utf-8'))['assets']}

# Opaque floor slabs (one slab = 96 px). Cold: the plain four-slab stone, turned and mirrored so
# it does not repeat, and the cracked slab; the hell "hot" slots get rune and bone floors, so
# deeper crypt floors look more worn and haunted. Second value: r = turned 90 degrees, f = mirrored.
FLOORS = {
    'floor_00': 'B001', 'floor_04': ('B001', 'r'), 'floor_01': 'B003', 'floor_10': ('B001', 'f'), 'floor_11': ('B003', 'r'),
    'floor_02': ('B003', 'f'), 'floor_03': 'B004', 'floor_07': 'B005', 'floor_08': ('B004', 'r'), 'floor_09': ('B005', 'f'),
    'floor_05': 'B011', 'floor_06': 'B015',
}
# Sprites: hell name -> crypt asset id (D = Dekoration/Loot, I = Interieur, B = Bausteine).
# Optional second value: fixed scale; else the asset keeps its pixel size unless it is far
# off the hell sprite's footprint.
SPRITES = {
    'wall_h': ('B030', 1.0), 'wall_h_glowpost': 'B033', 'wall_post_slit': 'B036', 'wall_torch_block': 'B041',
    'wall_skull_a': 'D107', 'wall_skull_b': 'I024', 'wall_v_glow': 'B043', 'wall_v_glow_b': 'B047',
    'door_stairs': ('B066', 1.0), 'door_stairs_small': ('B067', 1.0), 'gate_side': ('B048', 1.0), 'jamb_a': 'B049', 'jamb_b': 'B050',
    'portcullis': ('B051', 1.0), 'demon_lintel': ('B052', 1.0), 'obelisk': 'B054', 'banner_a': 'B055', 'banner_b': 'B056',
    'banner_chain': 'B058', 'cage_small': 'B059',
    'rune_pillar_a': 'I029', 'rune_pillar_b': 'I031', 'rune_pillar_c': 'I033', 'rune_pillar_d': 'I034',
    'grate': 'I114', 'spike_block': 'D150', 'brazier_floor': 'B069', 'demon_plate': 'B073', 'rune_small': 'B071',
    'rune_plate': ('B072', 1.0), 'rune_big': ('B022', 1.0), 'fire_plate': ('B007', 1.0), 'pit': ('B013', 1.0),
    'chain_a': 'D116', 'chain_b': 'D117', 'chain_swag': 'D118', 'skull_pile_t': 'D084', 'bones_t': 'D086',
    'spire_t': 'B097', 'spires_t': 'D093', 'brazier_low': 'B085', 'brazier_low_b': 'B087', 'demon_head': 'D083',
    'skull_pile': 'B090', 'bone_a': 'D087', 'bone_b': 'D088', 'coal': 'D091', 'bone_c': 'D089', 'rubble': 'B112',
    'spire_small': 'B109', 'spire_tiny': 'B105', 'spire_big_t': 'I101', 'spire_mid': 'B093', 'rocks_a': 'D095', 'rocks_b': 'D094',
    'spires_lava': 'I084', 'brazier_pillar': 'B064', 'brazier_rune': 'B063', 'brazier_demon': 'B065', 'brazier_bowl': 'B070',
    'wall_torch_hook': 'D024', 'hanging_brazier': 'D037', 'wall_brazier': 'D026', 'torch_a': 'D027', 'torch_b': 'D017', 'torch_c': 'D019',
    'chain_long': 'B077', 'chain_long_b': 'B078', 'chain_swag_b': 'D118', 'chain_hang': 'D116', 'cage_hang': 'D119', 'chain_hook': 'D117',
    'shackle_a': 'D122', 'shackle_skull': 'D121', 'shackle_b': 'D123', 'skull_heap': ('D084', 1.4), 'coal_skulls': 'D086',
    'bones_scatter': 'B107', 'bone_d': 'B091', 'bone_e': 'B108', 'bone_f': 'D090', 'bone_g': 'B106',
    'banner_1': 'D001', 'banner_2': 'D002', 'banner_3': 'D003', 'banner_4': 'D004', 'banner_5': 'D005',
    'spire_big': 'I083', 'spire_big_b': 'I086', 'rocks_lava': 'I062', 'rocks_dark': 'I063', 'boulders': 'D096',
    'spike_trap': ('D158', 1.0), 'spike_trap_b': 'D150', 'grate_a': 'B020', 'vent': ('B014', .8), 'grate_b': 'B104',
    'altar': ('I064', 1.0), 'skull_obelisk': 'I028',
    # world kit rules: key room fountain (mana, one use), the dressed boss gate and its carpet
    'fountain': ('D161', 1.35), 'boss_gate': ('B051', 1.4), 'boss_arch': ('B048', 1.45), 'boss_banner': ('D131', 1.4), 'carpet': ('D006', 1.0),
    'shop_table': ('I077', 1.3), 'chest_vault': ('D045', 1.0), 'stairs_down': ('B067', 1.3), 'torch_pillar': ('B049', 1.0),
    'brazier_blue': ('B086', .9), 'bowl_blue': ('B070', .9),
    # crypt dressing: blood and moss on the floor, furniture, urns, barrels, breakable crates
    'blood_a': ('I151', 1.4), 'blood_b': ('I152', 1.3), 'blood_c': ('I153', 1.3), 'blood_d': ('I154', 1.0), 'blood_e': ('I170', 1.45), 'blood_f': ('I174', 1.3),
    'moss_a': ('I168', 1.5), 'moss_b': ('I169', 1.5), 'moss_c': ('I145', 1.4), 'moss_rubble_a': ('I143', 1.0), 'moss_rubble_b': ('I122', 1.0), 'moss_ruin': ('I101', 1.0),
    'barrel_a': ('D052', 1.0), 'barrel_b': ('D053', 1.0), 'barrel_c': ('D054', 1.0), 'urn_a': ('D055', 1.0), 'urn_b': ('D057', 1.0), 'urn_c': ('D058', 1.0),
    'urn_d': ('D059', 1.0), 'urn_e': ('D060', 1.0), 'sacks_a': ('I119', 1.0), 'sacks_b': ('I120', 1.0), 'sacks_c': ('I121', 1.0), 'crate_pile': ('I098', 1.0),
    'table_a': ('I071', 1.0), 'table_b': ('I072', 1.0), 'table_c': ('I080', 1.0), 'candelabra': ('I075', 1.0), 'shelf': ('I076', 1.0),
    'crate_a': ('D047', 1.0), 'crate_b': ('D048', 1.0), 'crate_c': ('D050', 1.0),
    'statue_angel': ('I028', 1.0), 'statue_monk': ('I040', 1.0), 'gargoyle': ('I030', 1.0),
    'rug_red': ('D009', 1.0), 'rug_blue': ('D010', 1.0), 'mat': ('D015', 1.0), 'rug_square': ('D023', 1.0), 'bench': ('I078', 1.0),
    'chest_closed': 'D041', 'chest_open': 'D043', 'chest_gold': 'D044', 'chest_empty': 'D042',
    'key': ('D074', 1.2), 'rune_gem': ('I181', .8),
    'icon_scroll': 'B071', 'icon_swords': 'D108', 'icon_chest': 'D041', 'icon_demon': 'D107', 'icon_demon_big': 'D109', 'icon_door': 'I002',
}
# Poison mire instead of lava: [shadow .. highlight].
MIRE = [(10, 22, 14), (22, 52, 26), (44, 96, 38), (86, 150, 52), (150, 206, 84), (214, 246, 150)]
SOUL = [(8, 16, 40), (20, 46, 96), (40, 96, 170), (90, 160, 230), (170, 220, 255), (240, 250, 255)]


def asset(short):
    return img.load(os.path.join(SET, MAN[PREFIX[short[0]] + short[1:]]['transparent_png']))


def resample(src, dw, dh, hard=True):
    """Box filter with premultiplied alpha (tools/hell_dungeon/world.py); hard alpha edge for sprites."""
    out = img.Img(dw, dh)
    sw, sh, b = src.w, src.h, src.buf
    for dy in range(dh):
        y0 = dy * sh // dh; y1 = max(y0 + 1, (dy + 1) * sh // dh)
        for dx in range(dw):
            x0 = dx * sw // dw; x1 = max(x0 + 1, (dx + 1) * sw // dw)
            r = g = bb = a = n = 0
            for y in range(y0, y1):
                i = (y * sw + x0) * 4
                for x in range(x0, x1):
                    al = b[i + 3]
                    r += b[i] * al; g += b[i + 1] * al; bb += b[i + 2] * al; a += al; n += 1
                    i += 4
            o = (dy * dw + dx) * 4
            if a:
                out.buf[o] = r // a; out.buf[o + 1] = g // a; out.buf[o + 2] = bb // a
            out.buf[o + 3] = a // n
    if hard:
        for i in range(3, len(out.buf), 4):
            out.buf[i] = 255 if out.buf[i] >= 128 else 0
    return out


def over(im, base=(18, 16, 20)):
    """Composites onto an opaque dark base (floors: no see-through gaps)."""
    out = img.Img(im.w, im.h)
    for i in range(0, len(im.buf), 4):
        k = im.buf[i + 3] / 255
        for c in range(3):
            out.buf[i + c] = int(im.buf[i + c] * k + base[c] * (1 - k))
        out.buf[i + 3] = 255
    return out


BANNER_HUES = {'blue': 220, 'green': 125, 'purple': 275, 'gold': 46, 'teal': 178, 'pink': 318}


def hue_shift(im, hue):
    """Moves the warm, saturated pixels (red cloth, orange flame) to the given hue; stone and wood stay."""
    out = img.Img(im.w, im.h, bytearray(im.buf))
    for i in range(0, len(out.buf), 4):
        r, g, b = (out.buf[i + c] / 255 for c in range(3))
        h, s, v = colorsys.rgb_to_hsv(r, g, b)
        if s > .38 and v > .18 and (h < 50 / 360 or h > 335 / 360):
            nr, ng, nb = colorsys.hsv_to_rgb(hue / 360, s, v)
            out.buf[i:i + 3] = bytes((int(nr * 255), int(ng * 255), int(nb * 255)))
    return out


def extinguish(im):
    """A torch without its flame: bright warm (fire) pixels go transparent, the iron stays."""
    out = img.Img(im.w, im.h, bytearray(im.buf))
    for i in range(0, len(out.buf), 4):
        r, g, b = (out.buf[i + c] / 255 for c in range(3))
        h, s, v = colorsys.rgb_to_hsv(r, g, b)
        if s > .35 and v > .45 and (h < 65 / 360 or h > 335 / 360):
            out.buf[i + 3] = 0
    return out


def shade(im, f):
    out = img.Img(im.w, im.h, bytearray(im.buf))
    for i in range(0, len(out.buf), 4):
        for c in range(3):
            out.buf[i + c] = min(255, int(out.buf[i + c] * f))
    return out


def ramp(im, pal, hot_only=False):
    """Maps brightness onto a palette; hot_only keeps grey stone and only recolours saturated (lava) pixels."""
    out = img.Img(im.w, im.h, bytearray(im.buf))
    b = out.buf
    for i in range(0, len(b), 4):
        if not b[i + 3]:
            continue
        r, g, bl = b[i], b[i + 1], b[i + 2]
        lum = (0.3 * r + 0.59 * g + 0.11 * bl) / 255
        if hot_only and max(r, g, bl) - min(r, g, bl) < 60:
            v = int((r + g + bl) / 3 * .8)
            b[i:i + 3] = bytes((v, v, int(v * 1.05) if v < 243 else 255))
            continue
        k = min(len(pal) - 1, int(lum * (.95 if not hot_only else 1.2) * (len(pal) - 1) + .3))
        b[i:i + 3] = bytes(pal[k])
    return out


def turned(im, how):
    """r: turned 90 degrees clockwise, f: mirrored left to right (square slabs only)."""
    if not how:
        return im
    out = img.Img(im.w, im.h)
    for y in range(im.h):
        for x in range(im.w):
            out.set(x, y, im.get(y, im.h - 1 - x) if how == 'r' else im.get(im.w - 1 - x, y))
    return out


def bevel(im, light=(150, 140, 130), dark=(26, 22, 26)):
    """A 2 px lit top-left and dark bottom-right edge: a wall top seen from above."""
    for y in range(im.h):
        for x in range(im.w):
            if x < 2 or y < 2:
                im.set(x, y, light + (255,))
            elif x >= im.w - 2 or y >= im.h - 2:
                im.set(x, y, dark + (255,))
    return im


def paste(dst, src, ox, oy):
    for y in range(src.h):
        for x in range(src.w):
            r, g, b, a = src.get(x, y)
            if a and 0 <= ox + x < dst.w and 0 <= oy + y < dst.h:
                k = a / 255
                d = dst.get(ox + x, oy + y)
                dst.set(ox + x, oy + y, (int(r * k + d[0] * (1 - k)), int(g * k + d[1] * (1 - k)), int(b * k + d[2] * (1 - k)), max(a, d[3])))


def fit_scale(name, src, hell):
    """Keeps pixel size when close to the hell footprint (crisp pixels), else scales towards it."""
    if name not in hell:
        return 1.0
    s = math.sqrt(hell[name]['w'] * hell[name]['h'] / (src.w * src.h))
    if .8 <= s <= 1.25:
        return 1.0
    return max(.7, min(1.4, s))


def rot90(im):
    """Turned 90 degrees clockwise (any size)."""
    out = img.Img(im.h, im.w)
    for y in range(out.h):
        for x in range(out.w):
            out.set(x, y, im.get(y, im.h - 1 - x))
    return out


def tiled(src, w, h):
    out = img.Img(w, h)
    for y in range(0, h, src.h):
        for x in range(0, w, src.w):
            paste(out, src, x, y)
    return out


def wall_block(face, cap, w, h):
    """A wall end seen from above: dark brick with a rim of light cap stones on every side."""
    out = tiled(shade(face, .7), w, h)
    rim = 12
    top = tiled(cap, w, cap.h).crop(0, 2, w, rim)
    side = rot90(tiled(cap, h, cap.h).crop(0, 2, h, rim))
    paste(out, top, 0, 0); paste(out, top, 0, h - rim); paste(out, side, 0, 0); paste(out, side, w - rim, 0)
    return bevel(out, (190, 180, 168), (10, 8, 12))


def bridge(cap, face, w, h):
    """A stone bridge walked top to bottom: rows of cap stones across, brick rails left and right, a drop shadow."""
    out = img.Img(w, h)
    rail = 18
    deck = img.Img(w - 2 * rail, h)
    row = tiled(cap, w + 46, cap.h)
    for i, y in enumerate(range(0, h, cap.h)):
        paste(deck, row.crop((i * 23) % 46, 0, deck.w, cap.h), 0, y)
    paste(out, shade(deck, .9), rail, 0)
    brick = shade(tiled(face, rail, h), .8)
    stones = rot90(tiled(cap, h, cap.h).crop(0, 0, h, 10))
    for x in (0, w - rail):
        paste(out, brick, x, 0); paste(out, stones, x + 4, 0)
        for y in range(h):
            out.set(x, y, (12, 10, 14, 255)); out.set(x + rail - 1, y, (12, 10, 14, 255))
    return out


def arch_portal(dark):
    """The crypt arch (I012) with a soul-blue glow (active) or black depth (spent) inside."""
    a = asset('I012')
    out = img.Img(a.w, a.h)
    cx, cy, rx, ry = a.w / 2, a.h * .58, a.w * .36, a.h * .44
    for y in range(a.h):
        for x in range(a.w):
            d = ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2
            if d <= 1 and y > a.h * .12:
                if dark:
                    out.set(x, y, (6, 6, 10, 255))
                else:
                    k = 1 - d
                    out.set(x, y, (int(30 + 140 * k * k), int(60 + 170 * k), int(120 + 135 * k), 255))
    paste(out, a, 0, 0)
    return out


def main():
    os.makedirs(OUT, exist_ok=True)
    hell = json.load(open(os.path.join(HELL, 'manifest.json'), encoding='utf-8'))
    man = {}

    def put(name, im, kind, src):
        img.save(im, os.path.join(OUT, name + '.png'))
        man[name] = {'w': im.w, 'h': im.h, 'kind': kind, 'src': src}

    for name, spec in FLOORS.items():
        sid, turn = spec if isinstance(spec, tuple) else (spec, '')
        put(name, turned(resample(over(asset(sid)), SLAB, SLAB, hard=False), turn), 'opaque', sid + turn)
    for name in ('lava_00', 'lava_01', 'lava_edge_top'):
        put(name, ramp(img.load(os.path.join(HELL, name + '.png')), MIRE, hot_only=name == 'lava_edge_top'), 'opaque', 'hell/' + name + ' as poison mire')
    # Wall pieces from the long wall B030: its light cap stones (rows 1-17) and its dark brick face.
    wall = over(asset('B030'))
    cap = wall.crop(1, 1, 184, 17)
    face = wall.crop(4, 28, 62, 54)
    wv = img.Img(62, 70)
    paste(wv, face, 0, 0); paste(wv, face.crop(0, 0, 62, 16), 0, 54)
    put('wall_v', bevel(shade(wv, .78), (120, 112, 104), (12, 10, 14)), 'design', 'B030 brick face')
    # Where side walls end (room corners and the steps of cut rooms) the same brick wall carries on:
    # no cap stones, no rim, so the corner reads as wall and not as a block.
    put('corner_cap', shade(tiled(face, 76, 76), .78), 'design', 'B030 brick face')
    # Bridges are walked along their rails: bridge_v (over a band running left-right, walked up/down)
    # has stone planks across and rails left and right; bridge_h is the same bridge turned.
    bv = bridge(cap, face, 212, 212)
    put('bridge_v', bv, 'sprite', 'B030 planks, rails left/right')
    put('bridge_h', rot90(bv), 'sprite', 'B030 planks, rails top/bottom')
    put('portal', arch_portal(False), 'sprite', 'I012 with soul glow')
    put('portal_dark', arch_portal(True), 'sprite', 'I012 spent')
    put('heart', img.load(os.path.join(HELL, 'heart.png')), 'sprite', 'hell/heart')
    put('fire_orb', ramp(img.load(os.path.join(HELL, 'fire_orb.png')), SOUL), 'sprite', 'hell/fire_orb as soul orb')
    for name, spec in SPRITES.items():
        sid, fixed = spec if isinstance(spec, tuple) else (spec, None)
        src = asset(sid)
        s = fixed if fixed is not None else fit_scale(name, src, hell)
        im = src if s == 1.0 else resample(src, max(1, round(src.w * s)), max(1, round(src.h * s)))
        put(name, im, 'sprite', sid)
    # Boss gate banners: red on floors 3, 6, 9 and 10, one other colour each on the rest.
    red = img.load(os.path.join(OUT, 'boss_banner.png'))
    for colour, hue in BANNER_HUES.items():
        put('boss_banner_' + colour, hue_shift(red, hue), 'sprite', 'D131 recoloured ' + colour)
    # Floor 10 burns blue: the torch pillar and the wall torch with soul-blue flames.
    put('torch_pillar_blue', hue_shift(img.load(os.path.join(OUT, 'torch_pillar.png')), 215), 'sprite', 'B049 blue flame')
    put('wall_torch_blue', hue_shift(img.load(os.path.join(OUT, 'wall_torch_hook.png')), 215), 'sprite', 'D024 blue flame')
    put('wall_v_glow_blue', hue_shift(img.load(os.path.join(OUT, 'wall_v_glow.png')), 215), 'sprite', 'B043 blue flame')
    # the merchant behind the shop table (always the same figure, idle only): the 0x72 dwarf
    for f in range(4):
        put('npc_idle_f%d' % f, img.load(os.path.join(HERE, '..', '..', 'assets', 'sprites', '0x72', 'dwarf_m_idle_anim_f%d.png' % f)), 'sprite', '0x72 dwarf_m idle')
    put('torch_dead', extinguish(img.load(os.path.join(OUT, 'wall_torch_hook.png'))), 'sprite', 'D024 without flame')
    put('boss_gate_blue', hue_shift(img.load(os.path.join(OUT, 'boss_gate.png')), 215), 'sprite', 'B051 blue flames')
    missing = sorted(set(hell) - set(man))
    json.dump(man, open(os.path.join(OUT, 'manifest.json'), 'w'), indent=1)
    print(len(man), 'crypt sprites ->', OUT, '| missing hell names:', missing or 'none')


if __name__ == '__main__':
    main()
