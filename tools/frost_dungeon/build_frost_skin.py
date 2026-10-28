"""Builds the Frostgruft sprite skin from the user's 0x72 archive.

Every name the Hell-Dungeon core and runtime draw (assets/sprites/hell/manifest.json)
gets an ice-coloured counterpart cut from 0x72 DungeonTileset II, its extended set
and Superdark's sheets, at one pixel density (16 px source -> x3). Frost-only
sprites (monsters, boss phases, keys) are added under their own names.

Usage (repo root):
  py -3 -I tools/frost_dungeon/build_frost_skin.py "<extracted archive>/Sprite Sheet 0x72" assets/sprites/frost
Needs Pillow. Writes <name>.png, manifest.json; LICENSE-NOTE.md is kept by hand.
"""
import json
import os
import sys

from PIL import Image

SRC = sys.argv[1]
OUT = sys.argv[2]
FR = os.path.join(SRC, '0x72_DungeonTilesetII_v1.7', 'frames')
EXT = os.path.join(SRC, 'dungeontiles-extended v1.1', 'dungeontileset-extended.png')
K = 3  # pixel density for everything except the boss

RAMPS = {
    'ice': ['#0a1430', '#163063', '#2b5ea3', '#4f93d6', '#8cc8f2', '#d2f1ff', '#ffffff'],
    'deep': ['#060a24', '#0f1d4e', '#1d3b8a', '#2f63c4', '#58a0ea', '#9fd8ff', '#e6f8ff'],
    'storm': ['#141a3a', '#2c3b74', '#5a73b8', '#93b3e6', '#c9def8', '#eef6ff', '#ffffff'],
    'stone': ['#0c1226', '#1a2442', '#2c3a60', '#435683', '#6479a6', '#93a8cc', '#c8d6ec'],
    'grav': ['#0e0820', '#22144a', '#3a2678', '#5a40a8', '#8466d0', '#b39cf0', '#e6dcff'],
    'rime': ['#0e1630', '#1f2d52', '#34497a', '#4f679c', '#7590c0', '#a9c2e2', '#dbe8f6'],
    'water': ['#04102a', '#082050', '#0f3478', '#1b4f9c', '#2f6fbe', '#5a98da', '#9cc8f0'],
}
GLOW = {'ice': '#7ff6ff', 'deep': '#ffffff', 'storm': '#b8a8ff', 'stone': '#7ff6ff', 'water': '#7ff6ff', 'grav': '#d6b8ff', 'rime': '#7ff6ff'}


def hexc(h):
    return tuple(int(h[i:i + 2], 16) for i in (1, 3, 5))


def recolor(im, ramp='ice', glow=True, stretch=False):
    """Maps brightness onto an ice ramp; saturated green or red pixels become glow."""
    im = im.convert('RGBA')
    out = im.copy()
    p = out.load()
    rp = [hexc(c) for c in RAMPS[ramp]]
    lum = [(0.3 * r + 0.59 * g + 0.11 * b) / 255 for r, g, b, a in im.getdata() if a]
    lo, hi = (min(lum), max(lum)) if stretch and lum else (0.0, 1.0)
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = p[x, y]
            if a == 0:
                continue
            if glow and max(r, g, b) - min(r, g, b) > 70 and (g > r + 40 or (r > g + 60 and r > b + 60)):
                p[x, y] = hexc(GLOW[ramp]) + (a,)
                continue
            l = (0.3 * r + 0.59 * g + 0.11 * b) / 255
            if stretch:
                l = 0.12 + 0.85 * (l - lo) / max(0.01, hi - lo)
            if l < 0.12:
                p[x, y] = rp[0] + (a,)
                continue
            p[x, y] = rp[min(len(rp) - 1, int(l * 1.15 * (len(rp) - 1) + 0.5))] + (a,)
    return out


def frame(name):
    return Image.open(os.path.join(FR, name + '.png')).convert('RGBA')


_ext = None


def ext(box):
    global _ext
    if _ext is None:
        _ext = Image.open(EXT).convert('RGBA')
    return _ext.crop(box)


def loose(file, box, key_bg=None):
    im = Image.open(os.path.join(SRC, file)).convert('RGBA').crop(box)
    if key_bg:
        p = im.load()
        for y in range(im.height):
            for x in range(im.width):
                if p[x, y][:3] == key_bg:
                    p[x, y] = (0, 0, 0, 0)
    return im


def up(im, k=K):
    return im.resize((im.width * k, im.height * k), Image.NEAREST)


def trim(im):
    b = im.getbbox()
    return im.crop(b) if b else im


def canvas(w, h):
    return Image.new('RGBA', (w, h), (0, 0, 0, 0))


def tile(parts, cols, rows):
    """parts[row][col] are 16 px tiles; returns the grid at density K."""
    c = canvas(cols * 16, rows * 16)
    for y in range(rows):
        for x in range(cols):
            c.alpha_composite(parts[y][x], (x * 16, y * 16))
    return up(c)


def side_by_side(images, gap=0):
    w = sum(i.width for i in images) + gap * (len(images) - 1)
    h = max(i.height for i in images)
    c = canvas(w, h)
    x = 0
    for i in images:
        c.alpha_composite(i, (x, h - i.height))
        x += i.width + gap
    return c


def ice(name, ramp='ice', **kw):
    return recolor(frame(name), ramp, **kw)


out = {}


def put(name, im, src):
    im.save(os.path.join(OUT, name + '.png'))
    out[name] = {'w': im.width, 'h': im.height, 'kind': 'sprite', 'src': src}


def put_tile(name, im, src):
    put(name, im, src)
    out[name]['kind'] = 'opaque'


os.makedirs(OUT, exist_ok=True)

# ---------- floor: one 96 px cell = 2 x 2 0x72 floor tiles ----------
floors = [frame('floor_%d' % i) for i in range(1, 9)]
CRACKS = [ext((16, 64, 32, 80)), ext((32, 64, 48, 80)), ext((16, 80, 32, 96)), ext((32, 96, 48, 112))]
for i in range(12):
    a, b, c, d = (floors[(i + k * 3) % 8] for k in range(4))
    if i >= 8:
        a = CRACKS[i - 8]
    # hell's "hot" tiles (02, 03, 07, 08, 09) become rime patches, the rest plain stone
    ramp = 'rime' if i in (2, 3, 7, 8, 9) else 'stone'
    put_tile('floor_%02d' % i, recolor(tile([[a, b], [c, d]], 2, 2), ramp, glow=False), '0x72 floor_1..8 (+extended Risse), umgefärbt')

# ---------- open ice water where hell has lava ----------
for i, ramp in enumerate(['water', 'deep']):
    put_tile('lava_%02d' % i, recolor(tile([[floors[i], floors[i + 2]], [floors[i + 4], floors[i + 1]]], 2, 2), ramp, glow=False), '0x72 floor, umgefärbt zu Eiswasser')
rim = canvas(96, 96)
rim.alpha_composite(up(side_by_side([frame('edge_down')] * 2)), (0, 0))
put('lava_edge_top', recolor(rim, 'ice', glow=False), '0x72 edge_down, umgefärbt (Eiskante)')

# ---------- walls: north strip 74 px high, side columns 62 px wide ----------
top = frame('wall_top_mid').crop((0, 7, 16, 16))  # 9 px cap -> 27 px
wall = canvas(64, 25)
for x in range(4):
    wall.alpha_composite(top, (x * 16, 0))
    wall.alpha_composite(frame('wall_mid').crop((0, 0, 16, 16)), (x * 16, 9))
put('wall_h', recolor(up(wall), 'stone', glow=False).crop((0, 0, 192, 74)), '0x72 wall_top_mid + wall_mid, umgefärbt')
put('wall_v', recolor(up(side_by_side([frame('wall_edge_mid_left').crop((0, 0, 5, 16)), frame('wall_mid').crop((0, 0, 16, 16))])).crop((0, 0, 62, 48)), 'stone', glow=False), '0x72 wall_edge_mid_left + wall_mid, umgefärbt')
put('corner_cap', recolor(up(frame('wall_top_left')).resize((76, 76), Image.NEAREST), 'stone', glow=False), '0x72 wall_top_left, umgefärbt')
post = recolor(up(frame('column_wall')), 'stone', glow=False)
put('wall_h_glowpost', post.crop((0, 0, 48, 96)), '0x72 column_wall, umgefärbt')
put('wall_post_slit', post.crop((0, 0, 48, 96)), '0x72 column_wall, umgefärbt')
put('wall_v_glow', recolor(up(frame('wall_fountain_mid_blue_anim_f0')), 'ice'), '0x72 wall_fountain_mid_blue')
put('wall_v_glow_b', recolor(up(frame('wall_fountain_mid_blue_anim_f1')), 'ice'), '0x72 wall_fountain_mid_blue')
put('wall_torch_block', recolor(up(ext((128, 352, 144, 376))), 'ice', glow=False), 'extended Fackel, umgefärbt')
put('wall_skull_a', recolor(up(frame('wall_hole_1')), 'stone', glow=False), '0x72 wall_hole_1, umgefärbt')
put('wall_skull_b', recolor(up(frame('wall_hole_2')), 'stone', glow=False), '0x72 wall_hole_2, umgefärbt')

# ---------- gates, stairs, portal ----------
leaf = up(frame('doors_leaf_closed'))
put('portcullis', recolor(side_by_side([leaf, leaf]), 'ice', glow=False), '0x72 doors_leaf_closed x2, umgefärbt')
put('gate_side', recolor(up(frame('doors_leaf_open')), 'ice', glow=False), '0x72 doors_leaf_open, umgefärbt')
put('jamb_a', recolor(up(frame('doors_frame_left')), 'stone', glow=False), '0x72 doors_frame_left, umgefärbt')
put('jamb_b', recolor(up(frame('doors_frame_right')), 'stone', glow=False), '0x72 doors_frame_right, umgefärbt')
put('demon_lintel', recolor(up(frame('doors_frame_top'), 4), 'stone', glow=False), '0x72 doors_frame_top, umgefärbt')
stairs = up(frame('floor_stairs'), 6)
put('door_stairs', recolor(stairs, 'ice', glow=False), '0x72 floor_stairs')
put('door_stairs_small', recolor(up(frame('floor_stairs'), 4), 'ice', glow=False), '0x72 floor_stairs')
put('portal', recolor(stairs, 'ice'), '0x72 floor_stairs, umgefärbt (offen)')
put('portal_dark', recolor(stairs, 'deep', glow=False), '0x72 floor_stairs, umgefärbt (verschlossen)')
ladder = recolor(up(side_by_side([frame('floor_ladder')] * 2)), 'stone', glow=False)
put('bridge_v', ladder, '0x72 floor_ladder, umgefärbt (Eisbrücke)')
put('bridge_h', ladder.rotate(90, expand=True), '0x72 floor_ladder, umgefärbt (Eisbrücke)')

# ---------- pillars, braziers (frost flames), altar ----------
col = recolor(up(trim(frame('column'))), 'stone', glow=False)
for n in ('rune_pillar_a', 'rune_pillar_b', 'rune_pillar_c', 'rune_pillar_d', 'obelisk'):
    put(n, col, '0x72 column, umgefärbt')
put('skull_obelisk', recolor(up(trim(frame('column'))), 'ice', glow=False), '0x72 column, umgefärbt')
torch = recolor(up(trim(ext((128, 352, 144, 376)))), 'ice', glow=False)
for n in ('brazier_bowl', 'brazier_pillar', 'brazier_rune', 'brazier_low', 'brazier_low_b', 'brazier_floor', 'brazier_demon',
          'hanging_brazier', 'wall_brazier', 'wall_torch_hook', 'torch_a', 'torch_b', 'torch_c'):
    put(n, torch, 'extended Fackel, umgefärbt (Frostflamme)')
put('altar', recolor(up(trim(ext((64, 112, 112, 144)))), 'ice', glow=False), 'extended Brunnen, umgefärbt')

# ---------- ice crystals instead of spires (Superdark crystal elemental) ----------
BG = (60, 60, 60)
crystals = [trim(loose('6DNLbZ.png', b, BG)) for b in [(375, 177, 391, 217), (322, 218, 332, 234), (309, 236, 319, 246)]]
cry = [recolor(up(c), 'ice', glow=False, stretch=True) for c in crystals]
for n, c in (('spire_big', 0), ('spire_big_b', 0), ('spire_big_t', 0), ('spire_t', 1), ('spires_t', 1), ('spire_mid', 1),
             ('spires_lava', 1), ('spire_small', 2), ('spire_tiny', 2)):
    put(n, cry[c], '6DNLbZ Kristall (Superdark-Stil), umgefärbt')
rock = trim(loose('6DNLbZ.png', (264, 236, 273, 246), BG))
for n in ('boulders', 'rocks_a', 'rocks_b', 'rocks_dark', 'rocks_lava', 'rubble', 'coal'):
    put(n, recolor(up(rock), 'stone', glow=False), '6DNLbZ Steinbrocken, umgefärbt')

# ---------- bones, skulls, small clutter ----------
skull = recolor(up(trim(frame('skull'))), 'ice', glow=False)
for n in ('skull_pile', 'skull_pile_t', 'coal_skulls', 'bones_t', 'bones_scatter', 'bone_a', 'bone_b', 'bone_c', 'bone_d', 'bone_e', 'bone_f', 'bone_g', 'demon_head'):
    put(n, skull, '0x72 skull, umgefärbt')
put('skull_heap', cry[1], '6DNLbZ Kristall vor geheimer Wand')
crate = recolor(up(trim(frame('crate'))), 'stone', glow=False)
for n in ('cage_small', 'cage_hang'):
    put(n, crate, '0x72 crate, umgefärbt')
banners = [recolor(up(frame('wall_banner_' + c)), 'ice', glow=False) for c in ('blue', 'green', 'red', 'yellow')]
for i, n in enumerate(('banner_1', 'banner_2', 'banner_3', 'banner_4', 'banner_5', 'banner_a', 'banner_b', 'banner_chain')):
    put(n, banners[i % 4], '0x72 wall_banner_*, umgefärbt')
goo = recolor(up(frame('wall_goo')), 'ice', glow=False)
for n in ('chain_a', 'chain_b', 'chain_long', 'chain_long_b', 'chain_swag', 'chain_swag_b', 'chain_hang', 'chain_hook', 'shackle_a', 'shackle_skull', 'shackle_b'):
    put(n, goo, '0x72 wall_goo, umgefärbt (Eiszapfen an der Wand)')

# ---------- floor decals, plates, traps ----------
rug = recolor(up(ext((176, 64, 224, 112))), 'ice', glow=False)
put('rune_big', rug, 'extended Teppich, umgefärbt')
put('rune_small', recolor(up(ext((176, 64, 208, 96))), 'ice', glow=False), 'extended Teppich, umgefärbt')
put('rune_plate', recolor(up(frame('button_blue_up'), 6), 'ice', glow=False), '0x72 button_blue_up')
put('fire_plate', recolor(up(frame('wall_fountain_basin_blue_anim_f0'), 6), 'ice', glow=False), '0x72 wall_fountain_basin_blue')
put('demon_plate', recolor(up(trim(frame('chest_mimic_open_anim_f0')), 5), 'ice', glow=False), '0x72 chest_mimic, umgefärbt (Mimic statt Siegel)')
put('pit', recolor(up(frame('hole'), 6), 'deep', glow=False), '0x72 hole')
spikes = recolor(up(frame('floor_spikes_anim_f3'), 6), 'ice', glow=False)
for n in ('spike_trap', 'spike_trap_b', 'spike_block'):
    put(n, spikes, '0x72 floor_spikes_anim, umgefärbt (Eisdornen)')
grate = recolor(up(frame('floor_ladder'), 4), 'deep', glow=False)
for n in ('grate', 'grate_a', 'grate_b', 'vent'):
    put(n, grate, '0x72 floor_ladder, umgefärbt (Frostschlot)')

# ---------- loot, icons, shots ----------
put('chest_closed', up(trim(ext((304, 336, 320, 352))), 4), 'extended Truhe')
put('chest_open', up(trim(frame('chest_full_open_anim_f2')), 4), '0x72 chest_full_open_anim')
put('chest_gold', up(trim(frame('chest_full_open_anim_f2')), 4), '0x72 chest_full_open_anim')
put('chest_empty', up(trim(frame('chest_empty_open_anim_f2')), 4), '0x72 chest_empty_open_anim')
put('heart', up(trim(frame('flask_big_red')), 4), '0x72 flask_big_red (Heiltrank)')
key = trim(ext((325, 322, 330, 333)))
put('key', up(key, 6), 'extended Schlüssel')
put('rune_gem', recolor(up(trim(ext((341, 325, 346, 331))), 6), 'ice', glow=False), 'extended Edelstein, umgefärbt (Eissplitter)')
put('fire_orb', recolor(up(trim(ext((128, 336, 144, 352))), 4), 'ice', glow=False), 'extended Flamme, umgefärbt (Frostkugel)')
put('icon_scroll', up(frame('button_blue_up'), 4), '0x72 button_blue_up')
put('icon_swords', up(trim(frame('weapon_regular_sword')), 3), '0x72 weapon_regular_sword')
put('icon_chest', up(trim(ext((304, 336, 320, 352))), 4), 'extended Truhe')
put('icon_door', up(frame('floor_stairs'), 4), '0x72 floor_stairs')
golem_head = loose('4GxFHH.png', (12, 14, 36, 38))
put('icon_demon', up(recolor(golem_head, 'ice')), 'Superdark Golem-Kopf, umgefärbt')
put('icon_demon_big', up(recolor(golem_head, 'ice'), 4), 'Superdark Golem-Kopf, umgefärbt')

# ---------- frost-only: keys, monsters, bosses ----------
put('key_gold', up(key, 6), 'extended Schlüssel (Gold)')
put('key_ice', recolor(up(key, 6), 'ice', glow=False), 'extended Schlüssel, umgefärbt')
put('key_crystal', recolor(up(key, 6), 'storm', glow=False), 'extended Schlüssel, umgefärbt')


def anim(name, frames, src, ramp=None, k=K, **kw):
    for i, f in enumerate(frames):
        put('%s_f%d' % (name, i), up(recolor(f, ramp, **kw) if ramp else f, k), src)


anim('mob_ice_zombie', [frame('ice_zombie_anim_f%d' % i) for i in range(4)], '0x72 ice_zombie_anim')
anim('mob_frost_skeleton', [frame('skelet_run_anim_f%d' % i) for i in range(4)], '0x72 skelet_run_anim, umgefärbt', 'ice')
anim('mob_frost_necromancer', [frame('necromancer_anim_f%d' % i) for i in range(4)], '0x72 necromancer_anim, umgefärbt', 'deep')
anim('mob_frost_corpse', [frame('big_zombie_idle_anim_f%d' % i) for i in range(4)], '0x72 big_zombie_idle_anim, umgefärbt', 'ice')
water = [(289, 198, 320, 217), (278, 221, 297, 234), (274, 236, 288, 246)]
air = [(348, 184, 374, 217), (311, 218, 321, 234), (299, 236, 308, 246)]
for i, b in enumerate(water):
    put('mob_ice_slime_%d' % i, up(recolor(trim(loose('6DNLbZ.png', b, BG)), 'ice', glow=False)), '6DNLbZ Wasser-Elementar, umgefärbt')
for i, b in enumerate(air[:2]):
    put('mob_frost_whirl_%d' % i, up(recolor(trim(loose('6DNLbZ.png', b, BG)), 'storm', glow=False)), '6DNLbZ Luft-Elementar, umgefärbt')
for i in range(2):
    put('mob_ice_crystal_%d' % i, cry[i], '6DNLbZ Kristall-Elementar, umgefärbt')
anim('mob_ice_knight', [loose('RGngLG.png', (i * 16, 1600, i * 16 + 16, 1632)) for i in range(8)], 'Superdark RGngLG Ritter')
anim('mob_frost_imp', [loose('RGngLG.png', (i * 16, 608, i * 16 + 16, 640)) for i in range(8)], 'Superdark RGngLG Hornkobold')
put('mob_frost_commander', up(recolor(loose('knights.png', (80, 96, 112, 128)), 'ice', glow=False)), 'Superdark knights großer Ritter, umgefärbt')
golem_cols = [(0, 48), (64, 112), (128, 176), (192, 240), (256, 304), (320, 368)]
for phase, ramp in (('boss_golem_p1', 'ice'), ('boss_golem_p2', 'deep'), ('boss_golem_p3', 'storm')):
    anim(phase, [loose('4GxFHH.png', (a, 8, b, 56)) for a, b in golem_cols], 'Superdark Golem (4GxFHH), umgefärbt', ramp, 4)
anim('boss_golem_walk', [loose('4GxFHH.png', (a, 64, b, 112)) for a, b in golem_cols], 'Superdark Golem (4GxFHH), umgefärbt', 'ice', 4)

# ---------- relic weapons and their summons ----------
put('weapon_gravity_hammer', frame('weapon_big_hammer'), '0x72 weapon_big_hammer')
put('weapon_gravity_staff', frame('weapon_red_magic_staff'), '0x72 weapon_red_magic_staff')
put('weapon_shadow_dagger', frame('weapon_knife'), '0x72 weapon_knife')
anim('ally_golem', [loose('4GxFHH.png', (a, 8, b, 56)) for a, b in golem_cols], 'Superdark Golem (4GxFHH), umgefärbt (Gravitationssteingolem)', 'grav', 2)
anim('ally_golem_walk', [loose('4GxFHH.png', (a, 64, b, 112)) for a, b in golem_cols], 'Superdark Golem (4GxFHH), umgefärbt (Gravitationssteingolem)', 'grav', 2)
put('rock_throw', up(recolor(rock, 'grav', glow=False), 5), '6DNLbZ Steinbrocken, umgefärbt (geworfener Fels)')
put('rock_spike', recolor(cry[1], 'grav', glow=False), '6DNLbZ Kristall, umgefärbt (Felsdorn)')
# ---------- subclass summons (necromancer, frost mage, beast tamer) ----------
def fr(name, n):
    return [frame('%s_f%d' % (name, i)) for i in range(n)]


anim('ally_skeleton', fr('skelet_run_anim', 4), '0x72 skelet_run_anim')
anim('ally_big_zombie', fr('big_zombie_run_anim', 4), '0x72 big_zombie_run_anim', None, 2)
anim('ally_big_demon', fr('big_demon_run_anim', 4), '0x72 big_demon_run_anim', None, 2)
anim('ally_frost_giant', fr('ogre_run_anim', 4), '0x72 ogre_run_anim, umgefärbt (Frostriese)', 'ice', 4)
put('ally_ice_elemental', up(recolor(trim(loose('6DNLbZ.png', (289, 198, 320, 217), BG)), 'ice', glow=False)), '6DNLbZ Wasser-Elementar, umgefärbt (Eiselementar)')
EF = 'Enchanted Forest - Individual Frames/'
for beast in ('Wolf', 'Bear', 'Ent'):
    anim('ally_' + beast.lower(), [trim(loose(EF + beast + '/' + beast + '_Walk_%d.png' % i, (0, 0, 64, 64))) for i in range(1, 5)], 'Superdark ' + beast, None, 2)
json.dump(out, open(os.path.join(OUT, 'manifest.json'), 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
print(len(out), 'sprites ->', OUT)
