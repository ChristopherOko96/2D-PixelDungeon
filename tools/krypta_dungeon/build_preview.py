"""Inlines the crypt skin, the world kit core, the crypt floors, figures and monsters into one preview page.

Usage (repo root):
  py -3 -I tools/krypta_dungeon/build_preview.py <skin_dir> <out.html>
The skin comes from build_krypta_skin.py, the page from make_template.py (krypta_template.html).
The placeholder hero is the 0x72 knight, as in the hell preview; the merchant is the 0x72 dwarf.
"""
import base64
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, '..', '..')
skin, out = sys.argv[1], sys.argv[2]


def b64(path):
    return 'data:image/png;base64,' + base64.b64encode(open(path, 'rb').read()).decode()


def text(*parts):
    return open(os.path.join(*parts), encoding='utf-8').read()


assets, sizes = {}, {}
for name, m in json.load(open(os.path.join(skin, 'manifest.json'), encoding='utf-8')).items():
    assets[name] = b64(os.path.join(skin, name + '.png'))
    sizes[name] = [m['w'], m['h']]
for kind in ('idle', 'run'):
    for i in range(4):
        n = 'knight_m_%s_anim_f%d' % (kind, i)
        assets[n] = b64(os.path.join(ROOT, 'assets', 'sprites', '0x72', n + '.png'))
# the merchant behind the shop table (always the same one, idle only)
for i in range(4):
    n = 'dwarf_m_idle_anim_f%d' % i
    assets[n] = b64(os.path.join(ROOT, 'assets', 'sprites', '0x72', n + '.png'))
html = text(HERE, 'krypta_template.html')
for key, val in (('__ASSETS__', json.dumps(assets)), ('__SIZES__', json.dumps(sizes)), ('__CORE__', text(ROOT, 'tools', 'world_kit', 'world_core.js')),
                 ('__PIX__', text(HERE, 'krypta_pix.js')), ('__FLOORS__', text(HERE, 'krypta_floors.js')), ('__MONSTERS__', text(HERE, 'krypta_monsters.js'))):
    assert key in html, key
    html = html.replace(key, val)
open(out, 'w', encoding='utf-8').write(html)
print(len(assets), 'assets,', round(len(html) / 1e6, 2), 'MB ->', out)
