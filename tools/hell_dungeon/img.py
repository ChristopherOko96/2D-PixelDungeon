"""Minimal PNG toolkit (no dependencies): load, save, crop, scale, paste, components."""
import struct, zlib


class Img:
    def __init__(self, w, h, buf=None):
        self.w, self.h = w, h
        self.buf = buf if buf is not None else bytearray(w * h * 4)

    def get(self, x, y):
        i = (y * self.w + x) * 4
        return self.buf[i], self.buf[i + 1], self.buf[i + 2], self.buf[i + 3]

    def set(self, x, y, c):
        i = (y * self.w + x) * 4
        self.buf[i:i + 4] = bytes(c)

    def crop(self, x0, y0, w, h):
        out = Img(w, h)
        for y in range(h):
            sy = y0 + y
            if 0 <= sy < self.h:
                a = max(0, x0); b = min(self.w, x0 + w)
                if a < b:
                    s = (sy * self.w + a) * 4
                    d = (y * w + (a - x0)) * 4
                    out.buf[d:d + (b - a) * 4] = self.buf[s:s + (b - a) * 4]
        return out

    def scale(self, f):
        """Nearest-neighbour integer upscale."""
        out = Img(self.w * f, self.h * f)
        for y in range(self.h):
            row = bytearray()
            for x in range(self.w):
                i = (y * self.w + x) * 4
                row += self.buf[i:i + 4] * f
            for k in range(f):
                d = ((y * f + k) * out.w) * 4
                out.buf[d:d + len(row)] = row
        return out

    def paste(self, src, ox, oy):
        """Alpha-composite src onto self."""
        for y in range(src.h):
            ty = oy + y
            if not 0 <= ty < self.h:
                continue
            for x in range(src.w):
                tx = ox + x
                if not 0 <= tx < self.w:
                    continue
                si = (y * src.w + x) * 4
                a = src.buf[si + 3]
                if a == 0:
                    continue
                di = (ty * self.w + tx) * 4
                if a == 255:
                    self.buf[di:di + 4] = src.buf[si:si + 4]
                    continue
                da = self.buf[di + 3]
                oa = a + da * (255 - a) // 255
                for c in range(3):
                    self.buf[di + c] = (src.buf[si + c] * a + self.buf[di + c] * da * (255 - a) // 255) // max(oa, 1)
                self.buf[di + 3] = oa

    def rect(self, x0, y0, w, h, c):
        for x in range(x0, x0 + w):
            for y in (y0, y0 + h - 1):
                if 0 <= x < self.w and 0 <= y < self.h:
                    self.set(x, y, c)
        for y in range(y0, y0 + h):
            for x in (x0, x0 + w - 1):
                if 0 <= x < self.w and 0 <= y < self.h:
                    self.set(x, y, c)


def load(path):
    d = open(path, 'rb').read()
    i = 8; idat = b''; pl = None; trns = None
    while i < len(d):
        n = struct.unpack('>I', d[i:i + 4])[0]; t = d[i + 4:i + 8]; c = d[i + 8:i + 8 + n]
        if t == b'IHDR':
            w, h, bd, ct, _, _, il = struct.unpack('>IIBBBBB', c)
        elif t == b'IDAT':
            idat += c
        elif t == b'PLTE':
            pl = c
        elif t == b'tRNS':
            trns = c
        i += 12 + n
    assert bd == 8 and il == 0, (path, bd, il)
    bpp = {6: 4, 2: 3, 0: 1, 4: 2, 3: 1}[ct]
    raw = zlib.decompress(idat); st = w * bpp
    out = bytearray(w * h * 4); prev = bytearray(st); o = 0
    for y in range(h):
        f = raw[o]; o += 1
        line = bytearray(raw[o:o + st]); o += st
        if f == 1:
            for x in range(bpp, st):
                line[x] = (line[x] + line[x - bpp]) & 255
        elif f == 2:
            for x in range(st):
                line[x] = (line[x] + prev[x]) & 255
        elif f == 3:
            for x in range(st):
                a = line[x - bpp] if x >= bpp else 0
                line[x] = (line[x] + ((a + prev[x]) >> 1)) & 255
        elif f == 4:
            for x in range(st):
                a = line[x - bpp] if x >= bpp else 0
                b = prev[x]; c = prev[x - bpp] if x >= bpp else 0
                p = a + b - c; pa = abs(p - a); pb = abs(p - b); pc = abs(p - c)
                line[x] = (line[x] + (a if pa <= pb and pa <= pc else b if pb <= pc else c)) & 255
        prev = line
        base = y * w * 4
        if ct == 6:
            out[base:base + w * 4] = line
        elif ct == 2:
            for x in range(w):
                out[base + x * 4:base + x * 4 + 4] = line[x * 3:x * 3 + 3] + b'\xff'
        elif ct == 3:
            for x in range(w):
                k = line[x]
                a = trns[k] if trns and k < len(trns) else 255
                out[base + x * 4:base + x * 4 + 4] = pl[k * 3:k * 3 + 3] + bytes([a])
        else:
            raise ValueError('unsupported color type %d' % ct)
    return Img(w, h, out)


def save(img, path):
    raw = bytearray()
    st = img.w * 4
    for y in range(img.h):
        raw.append(0)
        raw += img.buf[y * st:(y + 1) * st]

    def chunk(t, c):
        return struct.pack('>I', len(c)) + t + c + struct.pack('>I', zlib.crc32(t + c) & 0xffffffff)
    data = b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', img.w, img.h, 8, 6, 0, 0, 0))
    data += chunk(b'IDAT', zlib.compress(bytes(raw), 9)) + chunk(b'IEND', b'')
    open(path, 'wb').write(data)


def components(img, thr=100, min_px=40):
    """Bounding boxes of 8-connected regions with alpha >= thr."""
    w, h = img.w, img.h
    mask = bytearray(w * h)
    for i in range(w * h):
        if img.buf[i * 4 + 3] >= thr:
            mask[i] = 1
    boxes = []
    for start in range(w * h):
        if mask[start] != 1:
            continue
        stack = [start]; mask[start] = 2
        x0 = x1 = start % w; y0 = y1 = start // w; n = 0
        while stack:
            p = stack.pop(); n += 1
            px, py = p % w, p // w
            x0 = min(x0, px); x1 = max(x1, px); y0 = min(y0, py); y1 = max(y1, py)
            for dy in (-1, 0, 1):
                ny = py + dy
                if not 0 <= ny < h:
                    continue
                for dx in (-1, 0, 1):
                    nx = px + dx
                    if 0 <= nx < w:
                        q = ny * w + nx
                        if mask[q] == 1:
                            mask[q] = 2; stack.append(q)
        if n >= min_px:
            boxes.append((x0, y0, x1 - x0 + 1, y1 - y0 + 1, n))
    return boxes
