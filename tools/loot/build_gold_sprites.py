"""The gold of the story worlds (src/hell/gold_loot.gd): coin and money bag sprites in both
graphics sets, written to assets/sprites/loot/.

- HD coin: the 0x72 coin (assets/sprites/0x72/coin_anim_f0-f3.png, 6x7), enlarged 4x with
  nearest pixels, so the HD set's smooth filtering keeps it crisp.
- Pixel coin: the items sheet's turning coin and its glint (assets/items/animation_sheet_items.png,
  row 3: cells 1-4 turn, 5-6 glint), 16x16 as drawn.
- Pixel bag: the items sheet's money bag (assets/items/item_sheet_items.png, cell [32,80]).
- HD bag: the same bag drawn up to 64x64 with Scale2x (EPX) twice: edges and curves smoothed
  instead of blocky, the colours of the original kept.

py -3 -I tools/loot/build_gold_sprites.py
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, '..', '..')
sys.path.insert(0, os.path.join(ROOT, 'tools', 'hell_dungeon'))
import img  # noqa: E402

OUT = os.path.join(ROOT, 'assets', 'sprites', 'loot')


def scale2x(src):
    """Scale2x (EPX): every pixel becomes four; a corner takes its two neighbours' colour where
    they agree, so diagonal edges come out smooth instead of stepped."""
    out = img.Img(src.w * 2, src.h * 2)

    def px(x, y):
        x = min(max(x, 0), src.w - 1)
        y = min(max(y, 0), src.h - 1)
        return src.get(x, y)
    for y in range(src.h):
        for x in range(src.w):
            p = px(x, y)
            a, b, c, d = px(x, y - 1), px(x + 1, y), px(x - 1, y), px(x, y + 1)
            e0 = a if (c == a and c != d and a != b) else p
            e1 = b if (a == b and a != c and b != d) else p
            e2 = c if (d == c and d != b and c != a) else p
            e3 = d if (b == d and b != a and d != c) else p
            out.set(x * 2, y * 2, e0)
            out.set(x * 2 + 1, y * 2, e1)
            out.set(x * 2, y * 2 + 1, e2)
            out.set(x * 2 + 1, y * 2 + 1, e3)
    return out


def build():
    os.makedirs(OUT, exist_ok=True)
    made = []
    for i in range(4):
        coin = img.load(os.path.join(ROOT, 'assets', 'sprites', '0x72', 'coin_anim_f%d.png' % i))
        img.save(coin.scale(4), os.path.join(OUT, 'coin_hd_f%d.png' % i))
        made.append('coin_hd_f%d' % i)
    anim = img.load(os.path.join(ROOT, 'assets', 'items', 'animation_sheet_items.png'))
    for i in range(4):
        img.save(anim.crop(16 * i, 32, 16, 16), os.path.join(OUT, 'coin_px_f%d.png' % i))
        made.append('coin_px_f%d' % i)
    for i in range(2):
        img.save(anim.crop(16 * (4 + i), 32, 16, 16), os.path.join(OUT, 'coin_px_glint_f%d.png' % i))
        made.append('coin_px_glint_f%d' % i)
    items = img.load(os.path.join(ROOT, 'assets', 'items', 'item_sheet_items.png'))
    bag = items.crop(32, 80, 16, 16)
    img.save(bag, os.path.join(OUT, 'bag_px.png'))
    img.save(scale2x(scale2x(bag)), os.path.join(OUT, 'bag_hd.png'))
    made += ['bag_px', 'bag_hd']
    return made


if __name__ == '__main__':
    print(len(build()), 'gold sprites ->', OUT)
