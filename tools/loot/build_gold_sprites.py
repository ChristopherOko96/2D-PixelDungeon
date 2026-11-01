"""The loot of the story worlds (src/hell/gold_loot.gd): coin, money bag and rune stone sprites in
both graphics sets, written to assets/sprites/loot/. One look in every world.

- HD coin: the 0x72 coin (assets/sprites/0x72/coin_anim_f0-f3.png, 6x7), enlarged 4x with
  nearest pixels, so the HD set's smooth filtering keeps it crisp.
- Pixel coin: the items sheet's turning coin and its glint (assets/items/animation_sheet_items.png,
  row 3: cells 1-4 turn, 5-6 glint), 16x16 as drawn.
- Pixel bag: the items sheet's money bag (assets/items/item_sheet_items.png, cell [32,80]).
- HD bag: the same bag drawn up to 64x64 with Scale2x (EPX) twice: edges and curves smoothed
  instead of blocky, the colours of the original kept.
- HD rune stone: the cut ice-blue rune diamond of the HD set (assets/sprites/frost_hd/rune_gem.png).
- Pixel rune stone: the same diamond of the 0x72 set (assets/sprites/hell_0x72/rune_gem.png),
  recoloured by brightness into the HD stone's blues, so both sets show one stone.

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
    hd = img.load(os.path.join(ROOT, 'assets', 'sprites', 'frost_hd', 'rune_gem.png'))
    img.save(hd, os.path.join(OUT, 'rune_hd.png'))
    img.save(recolour(img.load(os.path.join(ROOT, 'assets', 'sprites', 'hell_0x72', 'rune_gem.png')), palette(hd)),
             os.path.join(OUT, 'rune_px.png'))
    made += ['rune_hd', 'rune_px']
    return made


def palette(im, steps=6):
    """The image's colours sorted by brightness, `steps` of them evenly picked."""
    seen = sorted({im.get(x, y)[:3] for y in range(im.h) for x in range(im.w) if im.get(x, y)[3] > 200},
                  key=lambda c: 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2])
    return [seen[round(i * (len(seen) - 1) / (steps - 1))] for i in range(steps)]


def recolour(im, ramp):
    """Every opaque pixel takes the ramp colour of its own brightness (the shape stays)."""
    lums = [0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2] for y in range(im.h) for x in range(im.w)
            for c in [im.get(x, y)] if c[3] > 0]
    lo, hi = min(lums), max(lums)
    out = img.Img(im.w, im.h)
    for y in range(im.h):
        for x in range(im.w):
            r, g, b, a = im.get(x, y)
            if a == 0:
                continue
            t = (0.299 * r + 0.587 * g + 0.114 * b - lo) / max(1.0, hi - lo)
            t = t ** 0.45 if t > 0.08 else 0.0   # the stone lit like the HD one, the outline stays dark
            out.set(x, y, ramp[min(len(ramp) - 1, int(t * len(ramp)))] + (a,))
    return out


if __name__ == '__main__':
    print(len(build()), 'loot sprites ->', OUT)
