"""The snow at the Frostgruft's walls: the pieces src/hero/frost_wall_snow.gd lays along every wall
that rises out of a snow field (production/epics/main-port/story-012-snow-wall-integration.md).

A wall stands in the snow; it does not have snowballs lying in front of it. Each contact edge
between a snow floor cell and a wall gets two layers:
- a contact seam (ao_*): a narrow blue-grey shade on the floor right at the wall's foot, 3 to 8 px,
  a little darker on the wall's lowest pixels, irregular; it shows where the snow lip dips;
- a snow lip (lip_*, corner_*): one band of snow banked against the wall, rising into mounds and
  dipping into folds and the odd break, covering the wall's lowest pixels and reaching onto the
  floor, lit from above: a white top edge, cold blue towards its foot, a soft blue outline and a
  shade line where it lies on the floor snow.

Every piece covers half a cell edge (48 px). Its profile (how far the snow climbs over the wall and
how far it reaches onto the floor) runs through knots every 8 px. At both ends of a half it meets
one of two joins (JOIN: 0 a break, 1 the middle of a mound); the game picks the join at every half
boundary from the boundary's world position, so the two halves meeting there always agree and a
long wall is a run of different halves with breaks and mounds at no fixed rhythm. End pieces taper
the lip out (doorways, ice, thaw, the stairs door); corner pieces carry the lip round an inner
corner (one pile filling the pocket) or an outer corner (wrapping round the wall's edge), so a
corner never gets two lips on each other. Shading is worked out per pixel from the shape in screen
directions (light from above), so left and right side pieces are drawn as themselves, never a
mirrored copy with the light on the wrong side.

Sizes are world px; block = the art pixel (3 for the pixel set, 2 for the HD set). Every frame edge
is a multiple of 6, so the pieces sit on both sets' grids. The anchors (where a piece's origin, the
start of its half on the wall line or the corner point, lies in its image) and the variant counts
go to assets/data/frost_wall_snow.json.
Built by tools/frost_dungeon/build_frost_extras.py (winter_pieces).
"""
import img

HALF = 48
UP, DOWN = 12, 18          # compact frames: a contact edge, not a snow bank
OVR, OUT = 6, 12
S_FLOOR, S_OVER = 12, 6
AO_IN, AO_OUT = 4, 8
# The joins a half starts or ends with, (over the wall, onto the floor): 0 = a break, the lip
# nearly gone and the seam showing; 1 = the middle of a mound (end and corner pieces join with 1);
# 2 (north walls) = the middle of a big mound. Side walls join their end and corner pieces with 0:
# there the snow lies in loose mounds along the wall, never a closed white edge.
JOIN = {
    'h': ((0, 2), (3, 6), (5, 9)),
    'v': ((0, 1), (1, 4)),
    's': ((0, 2), (2, 5)),
}
# run pieces per kind and join pair: snow_wall_<kind>_<start join><end join>_<k>
PER_JOIN = {'lip_h': 2, 'lip_left': 2, 'lip_right': 2, 'lip_s': 2}
SEAMS = {'ao_h': 4, 'ao_left': 3, 'ao_right': 3}
SEAM_JOIN = 4


def hexc(h):
    return tuple(int(h[i:i + 2], 16) for i in (1, 3, 5))


# the Frostgruft's snow (build_frost_extras.py SNOW, snow_tile) and stone (STONE) colours
HI, BODY, BODY2, LIT, SOFT, MID, RIM, SHADE, DEEP, OUTL = (hexc(c) for c in (
    '#ffffff', '#f9fcff', '#f1f7fe', '#ffffff', '#dce8f6', '#c3d6ee', '#a9c2e2', '#87a3cf', '#55709e', '#8fa9d0'))
SEAM = hexc('#26325a')


def _h(i, j, seed):
    v = (i * 374761393 + j * 668265263 + seed * 2147483647) & 0xFFFFFFFF
    v = ((v ^ (v >> 13)) * 1274126177) & 0xFFFFFFFF
    return ((v ^ (v >> 16)) & 0xFFFF) / 65535


def profile(knots):
    """A smooth function through (position, value) knots, flat beyond the first and last."""
    def f(t):
        if t <= knots[0][0]:
            return knots[0][1]
        for (a, va), (b, vb) in zip(knots, knots[1:]):
            if t <= b:
                u = (t - a) / (b - a)
                u = u * u * (3 - 2 * u)
                return va + (vb - va) * u
        return knots[-1][1]
    return f


def run_profiles(seed, a, b, over_max, out_max, band_max=3):
    """Over and out profiles of one half of a straight lip from join a to join b ((over, out)
    pairs): a low band of snow along the wall (thin enough at places for the seam to show), with
    one to three rounded mounds on it. A mound join puts half a mound of the join's size on the
    boundary (the neighbouring half draws its other half), a break join leaves the band there."""
    mounds = []   # (centre, half width, height onto the floor, height over the wall)
    for at, j in ((0, a), (HALF, b)):
        if j[1] > 6:
            mounds.append((at, 13, j[1], j[0]))
    for k in range(2):
        if k > 0 and _h(seed, k, 1) < .4:
            continue
        w = 9 + _h(seed, k, 2) * 6
        c = w + 1 + _h(seed, k, 3) * (HALF - 2 * w - 2)
        m = .45 + .55 * _h(seed, k, 4)
        mounds.append((c, w, out_max * m, over_max * m))
    band = profile([(0, min(a[1], band_max)), (16, band_max * _h(seed, 5, 5)), (32, band_max * _h(seed, 6, 5)), (HALF, min(b[1], band_max))])
    band_over = profile([(0, min(a[0], 1)), (24, 2 * _h(seed, 7, 5)), (HALF, min(b[0], 1))])

    def bump(t, i):
        best = 0.0
        for c, w, *hs in mounds:
            u = (t - c) / w
            if u * u < 1:
                best = max(best, hs[i] * (1 - u * u) ** .5)
        return best
    return (lambda t: max(band_over(t), bump(t, 1))), (lambda t: max(band(t), bump(t, 0)))


def taper_profiles(join, end_at_zero=True):
    """Over and out profiles of a half whose lip runs out at position 0 (a rounded end) and meets
    join at 48; end_at_zero False runs out at 48 instead."""
    over = [(0, 0), (8, 0), (20, join[0] * .6), (34, join[0]), (HALF, join[0])]
    out = [(0, -2), (6, 3), (18, join[1] * .7), (34, join[1]), (HALF, join[1])]
    fo, fu = profile(over), profile(out)
    if end_at_zero:
        return fo, fu
    return (lambda t: fo(HALF - t)), (lambda t: fu(HALF - t))


def folds(out):
    """Where the out profile has a low between two higher stretches (a fold line)."""
    vals = [out(t) for t in range(0, HALF + 1, 2)]
    return [t * 2 for t in range(2, len(vals) - 2) if vals[t] < vals[t - 2] - 1 and vals[t] <= vals[t + 2] - 1 and vals[t] > 4]


class Piece:
    """One piece: its frame (x0, y0, x1, y1) in world px round its origin, the snow region
    inside(x, y), floor(x, y) (true where a pixel lies on the floor, for the shade and the outline),
    creases (crease(x, y): a pixel of a fold between two mounds) and the pixels it may draw
    (own(x, y))."""

    def __init__(self, frame, inside, floor, own=None, crease=None):
        self.frame, self.inside, self.floor = frame, inside, floor
        self.own = own or (lambda x, y: True)
        self.crease = crease or (lambda x, y: False)


def _fill(out, x, y, b, c):
    for yy in range(y, y + b):
        for xx in range(x, x + b):
            out.set(xx, yy, c)


def render(p, block):
    """The piece's pixels: snow lit from above (white top edges, cold blue towards the bottom
    edges, a cold rim on the floor side), a soft blue outline where it borders the floor and a shade
    line on the floor under its bottom edge. Hard edges, whole blocks, no smoothing."""
    x0, y0, x1, y1 = p.frame
    w, h = (x1 - x0) // block, (y1 - y0) // block
    out = img.Img(x1 - x0, y1 - y0)
    centre = lambda bx, by: (x0 + bx * block + block / 2, y0 + by * block + block / 2)
    cache = {}

    def snow(bx, by):
        k = (bx, by)
        if k not in cache:
            cache[k] = p.inside(*centre(bx, by))
        return cache[k]
    for by in range(h):
        for bx in range(w):
            x, y = centre(bx, by)
            if not p.own(x, y):
                continue
            if snow(bx, by):
                below = 0
                while below < 8 and snow(bx, by + below + 1):
                    below += 1
                above = 0
                while above < 8 and snow(bx, by - above - 1):
                    above += 1
                # how far down the mound this pixel lies (0 its top, 1 its foot): lit on top, cold below
                f = above / max(1, above + below)
                if below == 0:
                    c = SHADE if p.floor(x, y + block) else RIM
                elif above == 0:
                    c = HI
                elif not snow(bx + 1, by) and p.floor(x + block, y):
                    c = RIM
                elif not snow(bx - 1, by):
                    c = LIT if f < .6 else MID
                elif p.crease(x, y) and f > .4:
                    c = MID
                elif f > .75 or below == 1:
                    c = RIM
                elif f > .55:
                    c = MID
                elif f > .4:
                    c = SOFT
                else:
                    c = BODY if _h(bx, by, 7) > .3 else BODY2
                a = 255
            elif not p.floor(x, y):
                continue
            elif snow(bx, by - 1):
                c, a = DEEP, 170    # the lip's shade on the floor right under it
            elif snow(bx - 1, by) or snow(bx + 1, by):
                c, a = OUTL, 200    # its outline against the floor snow
            elif snow(bx, by - 2):
                c, a = DEEP, 60
            else:
                continue
            _fill(out, bx * block, by * block, block, c + (a,))
    return out


def _jitter(seed, block):
    """A few single-block bumps on the lip's top edge (snow crystals), never at the half's ends."""
    def j(t):
        if t < 2 * block or t > HALF - 2 * block:
            return 0
        return block if _h(int(t // block), 3, seed) > .9 else 0
    return j


# ---------- straight halves ----------

def lip_h(seed, block, a, b):
    """A half of the lip at the foot of a north wall (the wall above, the floor below)."""
    over, out = run_profiles(seed, JOIN['h'][a], JOIN['h'][b], 5, 10, band_max=2)
    jit = _jitter(seed, block)
    fl = folds(out)

    def inside(x, y):
        return -(over(x) + jit(x)) <= y < out(x)
    return Piece((0, -UP, HALF, DOWN), inside, lambda x, y: y >= 0,
                 crease=lambda x, y: any(abs(x - f) < block for f in fl) and y > out(x) - 4 * block)


def lip_h_end(block, left):
    over, out = taper_profiles(JOIN['h'][1], left)
    return Piece((0, -UP, HALF, DOWN), lambda x, y: out(x) > 1 and -over(x) <= y < out(x), lambda x, y: y >= 0)


def lip_side(seed, block, wall_left, a, b):
    """A half of a side lip: wall_left = the wall is on the left (the snow lies right of it)."""
    over, out = run_profiles(seed, JOIN['v'][a], JOIN['v'][b], 1, 5, band_max=1)
    s = 1 if wall_left else -1
    fl = folds(out)

    def inside(x, y):
        return -over(y) <= x * s < out(y)
    frame = (-OVR, 0, OUT, HALF) if wall_left else (-OUT, 0, OVR, HALF)
    return Piece(frame, inside, lambda x, y: x * s >= 0,
                 crease=lambda x, y: any(abs(y - f) < block for f in fl) and x * s > out(y) - 4 * block)


def lip_side_end(block, wall_left, top):
    """The last half of a side lip before a corner or a doorway: one small mound, the lip gone at
    both ends (side lips join with a break there)."""
    c = 30 if top else 18
    out = lambda t: 4 * max(0.0, 1 - ((t - c) / 10) ** 2) ** .5
    over = lambda t: 0
    s = 1 if wall_left else -1
    frame = (-OVR, 0, OUT, HALF) if wall_left else (-OUT, 0, OVR, HALF)
    return Piece(frame, lambda x, y: out(y) > 1 and -over(y) <= x * s < out(y), lambda x, y: x * s >= 0)


def lip_s(seed, block, a, b):
    """A half of the snow lying against the back of a front (south) wall: the floor is above."""
    over, out = run_profiles(seed, JOIN['s'][a], JOIN['s'][b], 3, 6, band_max=1)
    return Piece((0, -S_FLOOR, HALF, S_OVER), lambda x, y: -out(x) <= y < over(x), lambda x, y: y < 0)


def lip_s_end(block, left):
    over, out = taper_profiles(JOIN['s'][1], left)
    return Piece((0, -S_FLOOR, HALF, S_OVER), lambda x, y: out(x) > 1 and -out(x) <= y < over(x), lambda x, y: y < 0)


# ---------- corners ----------

def corner_inner(block, wall_left):
    """The pocket where a north wall meets a side wall: one pile filling the corner, its lip
    running out along the north wall to the mound join and along the side wall to a break (owns the
    north half and the side's top half).
    Origin: the corner point; wall_left = the side wall is on the left."""
    s = 1 if wall_left else -1
    jh, jv = JOIN['h'][1], JOIN['v'][0]
    oh = profile([(0, 2), (24, 1), (HALF, jh[0])])
    uh = profile([(0, 4), (24, 2), (HALF, jh[1])])
    ov = profile([(0, 2), (26, 1), (HALF, jv[0])])
    uv = profile([(0, 4), (26, 2), (HALF, jv[1])])

    def inside(x, y):
        d = x * s
        if d >= 0 and -oh(d) <= y < uh(d):
            return True
        if y >= 0 and -ov(y) <= d < uv(y):
            return True
        # one low turn at the pocket; never a separate white hill around the corner
        return d >= -1 and y >= -3 and ((d - 3) / 8) ** 2 + ((y - 1) / 6) ** 2 <= 1
    frame = (-OVR, -UP, HALF, HALF) if wall_left else (-HALF, -UP, OVR, HALF)
    return Piece(frame, inside, lambda x, y: x * s >= 0 and y >= 0, own=lambda x, y: -HALF < x * s < HALF and y < HALF)


def corner_outer(block, wall_right):
    """An outer corner: the north lip runs to the wall's corner, where a post stands (the walls'
    posts, hell_walls.gd), and ends in a pile banked round the post's foot, a little past the
    corner onto the floor beside it. It owns the side's lower half above the corner, which the post
    covers, so no lip climbs the post. Origin: the corner point; wall_right = the wall block lies
    right of the corner (the floor left of it)."""
    s = 1 if wall_right else -1
    jh = JOIN['h'][1]
    oh = profile([(0, 4), (14, 3), (30, 2), (HALF, jh[0])])
    uh = profile([(0, 7), (14, 6), (30, 5), (HALF, jh[1])])

    def inside(x, y):
        d = x * s
        if d >= 0 and -oh(d) <= y < uh(d):
            return True
        # a narrow wrap at the post's foot, without a freestanding mound
        return y >= -4 and ((d + 1) / 9) ** 2 + ((y - 2) / 7) ** 2 <= 1
    frame = (-OUT, -UP, HALF, DOWN) if wall_right else (-HALF, -UP, OUT, DOWN)
    return Piece(frame, inside, lambda x, y: y >= 0 or x * s < -24, own=lambda x, y: x * s < HALF)


# ---------- contact seams ----------

SEAM_FRAMES = {'h': (0, -AO_IN, HALF, AO_OUT), 'left': (-AO_IN, 0, AO_OUT, HALF), 'right': (-AO_OUT, 0, AO_IN, HALF)}


def seam(seed, block, kind, taper=None):
    """A contact seam half: kind 'h' (north wall: the wall above, the floor below), 'left' /
    'right' (side wall on that side). On the floor right at the wall 3 to 8 px deep through knots,
    strongest at the wall; on the wall's lowest pixels a lighter touch. taper 'start' / 'end' runs it
    out at that end of the half."""
    depth = profile([(0, SEAM_JOIN)] + [(k * 12, 3 + _h(seed, k, 18) * 3) for k in (1, 2, 3)] + [(HALF, SEAM_JOIN)])
    if taper == 'start':
        d0 = depth
        depth = lambda t: d0(t) * min(1.0, max(0.0, (t - 6) / 18))
    elif taper == 'end':
        d1 = depth
        depth = lambda t: d1(t) * min(1.0, max(0.0, (HALF - 6 - t) / 18))
    x0, y0, x1, y1 = SEAM_FRAMES[kind]
    out = img.Img(x1 - x0, y1 - y0)
    for by in range((y1 - y0) // block):
        for bx in range((x1 - x0) // block):
            x, y = x0 + bx * block + block / 2, y0 + by * block + block / 2
            t, onto = (x, y) if kind == 'h' else ((y, x) if kind == 'left' else (y, -x))
            d = depth(t)
            if d < 1.5:
                continue
            if 0 <= onto <= d:
                a = int(90 + 120 * (1 - onto / d) ** .7)
            elif -block * 2 <= onto < 0:
                a = 60 if onto < -block else 100
            else:
                continue
            _fill(out, bx * block, by * block, block, SEAM + (a // 10 * 10,))
    return out


# ---------- the set ----------

def pieces(block):
    """name -> (image, anchor): every wall snow piece of one set (block 3 pixel, 2 HD)."""
    made = {}

    def put(name, p):
        made[name] = (render(p, block), (-p.frame[0], -p.frame[1]))
    for a in range(len(JOIN['h'])):
        for b in range(len(JOIN['h'])):
            for k in range(PER_JOIN['lip_h']):
                put('snow_wall_lip_h_%d%d_%d' % (a, b, k), lip_h(101 + a * 1000 + b * 500 + k * 13, block, a, b))
    for a in (0, 1):
        for b in (0, 1):
            for k in range(PER_JOIN['lip_left']):
                put('snow_wall_lip_left_%d%d_%d' % (a, b, k), lip_side(301 + a * 1000 + b * 500 + k * 17, block, True, a, b))
                put('snow_wall_lip_right_%d%d_%d' % (a, b, k), lip_side(401 + a * 1000 + b * 500 + k * 19, block, False, a, b))
            for k in range(PER_JOIN['lip_s']):
                put('snow_wall_lip_s_%d%d_%d' % (a, b, k), lip_s(501 + a * 1000 + b * 500 + k * 23, block, a, b))
    put('snow_wall_lip_h_end_l', lip_h_end(block, True))
    put('snow_wall_lip_h_end_r', lip_h_end(block, False))
    for side, left in (('left', True), ('right', False)):
        put('snow_wall_lip_%s_end_t' % side, lip_side_end(block, left, True))
        put('snow_wall_lip_%s_end_b' % side, lip_side_end(block, left, False))
    put('snow_wall_lip_s_end_l', lip_s_end(block, True))
    put('snow_wall_lip_s_end_r', lip_s_end(block, False))
    put('snow_wall_corner_inner_l', corner_inner(block, True))
    put('snow_wall_corner_inner_r', corner_inner(block, False))
    put('snow_wall_corner_outer_l', corner_outer(block, True))
    put('snow_wall_corner_outer_r', corner_outer(block, False))
    for kind in ('h', 'left', 'right'):
        anchor = (-SEAM_FRAMES[kind][0], -SEAM_FRAMES[kind][1])
        for k in range(SEAMS['ao_' + kind]):
            made['snow_wall_ao_%s_%02d' % (kind, k)] = (seam(601 + k * 29 + len(kind), block, kind), anchor)
    made['snow_wall_ao_h_end_l'] = (seam(701, block, 'h', 'start'), (0, AO_IN))
    made['snow_wall_ao_h_end_r'] = (seam(709, block, 'h', 'end'), (0, AO_IN))
    return made


def layout(made):
    """The data file the game reads (assets/data/frost_wall_snow.json): anchors and counts, the
    same for both sets."""
    return {
        '_note': 'Wall snow pieces of the Frostgruft, generated by tools/frost_dungeon/wall_snow.py (do not edit; '
                 'read by src/hero/frost_wall_snow.gd). half = px of wall per piece; per_join = run pieces per kind '
                 'and join pair (snow_wall_<kind>_<start join><end join>_<k>, join 0 = a break, 1 = a mound, 2 = a big mound); '
                 'joins = joins per wall kind; seams = '
                 'contact seam pieces per kind (snow_wall_ao_<kind>_<k>); anchors = px in each image where the piece\'s '
                 'origin lies (the start of its half on the wall line, or the corner point).',
        'half': HALF,
        'per_join': PER_JOIN,
        'joins': {'h': len(JOIN['h']), 'left': len(JOIN['v']), 'right': len(JOIN['v']), 's': len(JOIN['s'])},
        'seams': SEAMS,
        'anchors': {name: list(anchor) for name, (_, anchor) in sorted(made.items())},
    }
