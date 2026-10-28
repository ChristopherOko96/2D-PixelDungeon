"""Resample cleaned assets to world scale (one floor slab = 96 px).

Usage: py -3 -I world.py <clean_dir> <world_dir>
Box filter with premultiplied alpha; sprites get their hard alpha edge back.
"""
import json, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import img

SLAB = 96


def resample(src, dw, dh):
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
    return out


def main():
    src_dir, dst_dir = sys.argv[1], sys.argv[2]
    os.makedirs(dst_dir, exist_ok=True)
    man = json.load(open(os.path.join(src_dir, 'manifest.json')))
    out = {}
    for name, m in man.items():
        im = img.load(os.path.join(src_dir, name + '.png'))
        if m['kind'] == 'opaque':
            im = resample(im, SLAB, SLAB)
        elif m['scale'] != 1.0:
            im = resample(im, max(1, round(im.w * m['scale'])), max(1, round(im.h * m['scale'])))
            for i in range(3, len(im.buf), 4):
                im.buf[i] = 255 if im.buf[i] >= 128 else 0
        img.save(im, os.path.join(dst_dir, name + '.png'))
        out[name] = {'w': im.w, 'h': im.h, 'kind': m['kind'], 'src': m['src']}
    json.dump(out, open(os.path.join(dst_dir, 'manifest.json'), 'w'), indent=1)
    print(len(out), 'world assets in', dst_dir)


if __name__ == '__main__':
    main()
