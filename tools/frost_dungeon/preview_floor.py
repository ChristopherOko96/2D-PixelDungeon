"""Renders a baked Frostgruft floor with the frost skin into one PNG (overview, not the game view).

Usage (repo root): py -3 -I tools/frost_dungeon/preview_floor.py <floor 1-10> <out.png> [scale]
Draws floor tiles, ice water, decals, props and entities depth-sorted; door frames mark
locks (gold, ice, crystal), puzzle gates, secret walls and the boss exit. Needs Pillow.
"""
import json
import sys

from PIL import Image, ImageDraw

DATA = 'assets/data/frost_floors.json'
SKIN = 'assets/sprites/frost/'
ENT = {'chest': 'chest_closed', 'key': 'key', 'portal': 'portal_dark', 'brazier': 'brazier_bowl', 'heart': 'heart',
       'gem': 'rune_gem', 'skullheap': 'skull_heap', 'seal': 'demon_plate', 'pit': 'pit', 'plate': 'rune_plate'}
DOOR = {'puzzle': (127, 246, 255), 'secret': (155, 231, 176), 'boss': (184, 168, 255)}
KEY = {'A': (232, 194, 90), 'B': (79, 180, 255), 'C': (242, 248, 255)}
_cache = {}


def sprite(name):
    if name not in _cache:
        _cache[name] = Image.open(SKIN + name + '.png').convert('RGBA')
    return _cache[name]


def render(f, scale):
    c = f['cell']
    cols = f['cols']
    cells = [(i % cols, i // cols) for i, v in enumerate(f['grid']) if v != '0']
    x0, y0 = min(x for x, _ in cells) - 1, min(y for _, y in cells) - 1
    x1, y1 = max(x for x, _ in cells) + 2, max(y for _, y in cells) + 2
    img = Image.new('RGBA', ((x1 - x0) * c, (y1 - y0) * c), (6, 9, 20, 255))
    ox, oy = -x0 * c, -y0 * c

    def paste(im, x, y):
        if x >= 0 and y >= 0:
            img.alpha_composite(im, (int(x), int(y)))

    for x, y in cells:
        i = y * cols + x
        tile = 'lava_00' if f['grid'][i] in '23' else f['tile_names'][int(f['tiles'][i], 36)]
        paste(sprite(tile), x * c + ox, y * c + oy)
    for d in f['decals']:
        im = sprite(d['name'])
        paste(im, d['x'] - im.width / 2 + ox, d['y'] - im.height / 2 + oy)
    items = [(p['y'], p['name'], p['x'], p['flip']) for p in f['props'] if p['name']]
    items += [(e['y'], ENT[e['type']], e['x'], False) for e in f['ents'] if e['type'] in ENT]
    for y, name, x, flip in sorted(items):
        im = sprite(name).transpose(Image.FLIP_LEFT_RIGHT) if flip else sprite(name)
        paste(im, x - im.width / 2 + ox, y - im.height + oy)
    draw = ImageDraw.Draw(img)
    for d in f['doors']:
        col = KEY.get(d['key']) if d['kind'] == 'lock' else DOOR.get(d['kind'])
        if col:
            draw.rectangle([d['cx'] - 44 + ox, d['cy'] - 44 + oy, d['cx'] + 44 + ox, d['cy'] + 44 + oy], outline=col, width=6)
    if scale != 1:
        img = img.resize((int(img.width * scale), int(img.height * scale)), Image.NEAREST)
    return img.convert('RGB')


if __name__ == '__main__':
    floors = json.load(open(DATA, encoding='utf-8'))['floors']
    n = int(sys.argv[1])
    out = render(floors[n - 1], float(sys.argv[3]) if len(sys.argv) > 3 else 0.33)
    out.save(sys.argv[2])
    print(sys.argv[2], out.size)
