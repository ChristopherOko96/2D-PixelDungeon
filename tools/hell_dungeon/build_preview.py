"""Inline the world-scale hell assets, their sizes, the floor core and the placeholder hero into the preview page.

Usage: py -3 -I build_preview.py <template.html> <world_dir> <hero_dir> <hell_core.js> <out.html>
"""
import base64, json, os, sys

tpl, world, hero, core, out = sys.argv[1:6]
assets, sizes = {}, {}
manifest = json.load(open(os.path.join(world, 'manifest.json'), encoding='utf-8'))
for f in sorted(os.listdir(world)):
    if f.endswith('.png'):
        assets[f[:-4]] = 'data:image/png;base64,' + base64.b64encode(open(os.path.join(world, f), 'rb').read()).decode()
for name, m in manifest.items():
    sizes[name] = [m['w'], m['h']]
for kind in ('idle', 'run'):
    for i in range(4):
        n = 'knight_m_%s_anim_f%d' % (kind, i)
        assets[n] = 'data:image/png;base64,' + base64.b64encode(open(os.path.join(hero, n + '.png'), 'rb').read()).decode()
html = open(tpl, encoding='utf-8').read()
html = html.replace('__ASSETS__', json.dumps(assets)).replace('__SIZES__', json.dumps(sizes))
html = html.replace('__CORE__', open(core, encoding='utf-8').read())
open(out, 'w', encoding='utf-8').write(html)
print(len(assets), 'assets,', round(len(html) / 1e6, 2), 'MB ->', out)
