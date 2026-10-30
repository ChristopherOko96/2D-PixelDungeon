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

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, '..', '..')
sys.path.insert(0, os.path.join(ROOT, 'tools', 'hell_dungeon'))
import img  # noqa: E402

SPR = os.path.join(ROOT, 'assets', 'sprites')
HELL, HELL_PIX, FROST, FROST_HD = (os.path.join(SPR, d) for d in ('hell', 'hell_0x72', 'frost', 'frost_hd'))


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


def save_manifest(path, man, crlf):
    text = json.dumps(dict(sorted(man.items())), indent=1, ensure_ascii=False, sort_keys=True) + '\n'
    open(path, 'w', encoding='utf-8', newline='').write(text.replace('\n', '\r\n') if crlf else text)


def build():
    hell = json.load(open(os.path.join(HELL, 'manifest.json'), encoding='utf-8'))
    frost = json.load(open(os.path.join(FROST, 'manifest.json'), encoding='utf-8'))
    # HD
    os.makedirs(FROST_HD, exist_ok=True)
    hd = {}
    for name, m in hell.items():
        src = INSTEAD.get(name, name)
        im = freeze(img.load(os.path.join(HELL, src + '.png')), name)
        img.save(im, os.path.join(FROST_HD, name + '.png'))
        hd[name] = {'w': im.w, 'h': im.h, 'kind': m['kind'], 'src': 'hell %s, frozen (build_frost_extras.py)' % src}
    for name, m in frost.items():
        if name in hell:
            continue
        shutil.copyfile(os.path.join(FROST, name + '.png'), os.path.join(FROST_HD, name + '.png'))
        hd[name] = dict(m)
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
    save_manifest(os.path.join(FROST, 'manifest.json'), frost, b'\r\n' in open(os.path.join(FROST, 'manifest.json'), 'rb').read())
    print(made, 'pixel sprites ->', FROST)


if __name__ == '__main__':
    build()
