"""Cut, clean and catalogue the hell assets from the two source sheets and one room design.

Usage: py -3 -I extract.py <rooms_dir> <out_dir>
Cleaning: floors/lava become fully opaque (composited over a dark base);
sprites get a hard alpha edge (no red/purple halo) and lose isolated specks.
"""
import json, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import img

T = 'tiles/SOURCE_hell_tilesheet.png'
P = 'decorations/SOURCE_hell_propsheet.png'
D = 'room_designs/combat_A_obsidian_pillars.png'
PS = 0.6   # prop sheet -> world scale (chest ~ one floor slab)

# name: (sheet, x, y, w, h, kind, world_scale)
A = {}
for i in range(12):
    A['floor_%02d' % i] = (T, [50, 164, 279, 391, 504, 619, 731, 844, 956, 1072, 1186, 1298][i] + 1, 63, 97, 97, 'opaque', 1.0)
A['lava_00'] = (T, 52, 182, 95, 92, 'opaque', 1.0)
A['lava_01'] = (T, 166, 182, 95, 92, 'opaque', 1.0)
A['lava_edge_top'] = (T, 504, 180, 99, 96, 'opaque', 1.0)
# walls and doors (tile sheet, world scale 1)
A.update({
    'wall_h': (T, 49, 308, 188, 74, 'sprite', 1.0),
    'wall_h_glowpost': (T, 428, 292, 50, 100, 'sprite', 1.0),
    'wall_post_slit': (T, 1089, 298, 63, 98, 'sprite', 1.0),
    'wall_torch_block': (T, 49, 405, 82, 118, 'sprite', 1.0),
    'wall_skull_a': (T, 432, 413, 62, 115, 'sprite', 1.0),
    'wall_skull_b': (T, 508, 413, 65, 114, 'sprite', 1.0),
    'wall_v_glow': (T, 345, 402, 61, 153, 'sprite', 1.0),
    'wall_v_glow_b': (T, 601, 405, 77, 149, 'sprite', 1.0),
    'door_stairs': (T, 49, 729, 162, 110, 'sprite', 1.0),
    'door_stairs_small': (T, 225, 729, 109, 108, 'sprite', 1.0),
    'gate_side': (T, 49, 565, 175, 133, 'sprite', 1.0),
    'jamb_a': (T, 248, 565, 47, 136, 'sprite', 1.0),
    'jamb_b': (T, 318, 565, 47, 136, 'sprite', 1.0),
    'portcullis': (T, 399, 575, 216, 105, 'sprite', 1.0),
    'demon_lintel': (T, 632, 575, 264, 110, 'sprite', 1.0),
    'obelisk': (T, 919, 574, 83, 139, 'sprite', 1.0),
    'banner_a': (T, 1012, 558, 84, 117, 'sprite', 1.0),
    'banner_b': (T, 1105, 558, 89, 138, 'sprite', 1.0),
    'banner_chain': (T, 1215, 558, 141, 110, 'sprite', 1.0),
    'cage_small': (T, 1348, 577, 50, 130, 'sprite', 1.0),
    'bridge_v': (T, 350, 703, 167, 136, 'sprite', 1.0),
    'bridge_h': (T, 537, 712, 157, 107, 'sprite', 1.0),
    'rune_pillar_a': (T, 1003, 701, 97, 141, 'sprite', 1.0),
    'rune_pillar_b': (T, 1119, 715, 77, 128, 'sprite', 1.0),
    'rune_pillar_c': (T, 1221, 694, 84, 148, 'sprite', 1.0),
    'rune_pillar_d': (T, 1332, 717, 67, 125, 'sprite', 1.0),
    'grate': (T, 764, 729, 101, 104, 'sprite', 1.0),
    'spike_block': (T, 880, 730, 102, 103, 'sprite', 1.0),
    'brazier_floor': (T, 58, 857, 85, 98, 'sprite', 1.0),
    'demon_plate': (T, 171, 859, 96, 86, 'sprite', 1.0),
    'rune_small': (T, 294, 869, 86, 76, 'sprite', 1.0),
    'rune_plate': (T, 406, 854, 104, 99, 'sprite', 1.0),
    'rune_big': (T, 540, 854, 100, 99, 'sprite', 1.0),
    'fire_plate': (T, 665, 854, 104, 98, 'sprite', 1.0),
    'pit': (T, 789, 854, 105, 98, 'sprite', 1.0),
    'chain_a': (T, 915, 854, 13, 95, 'sprite', 1.0),
    'chain_b': (T, 947, 855, 16, 96, 'sprite', 1.0),
    'chain_swag': (T, 983, 857, 77, 91, 'sprite', 1.0),
    'skull_pile_t': (T, 1086, 860, 68, 50, 'sprite', 1.0),
    'bones_t': (T, 1180, 875, 55, 45, 'sprite', 1.0),
    'spire_t': (T, 1238, 858, 69, 111, 'sprite', 1.0),
    'spires_t': (T, 1320, 857, 81, 70, 'sprite', 1.0),
    'brazier_low': (T, 170, 958, 80, 84, 'sprite', 1.0),
    'brazier_low_b': (T, 56, 965, 84, 74, 'sprite', 1.0),
    'demon_head': (T, 274, 981, 75, 57, 'sprite', 1.0),
    'skull_pile': (T, 368, 974, 85, 67, 'sprite', 1.0),
    'bone_a': (T, 474, 989, 46, 42, 'sprite', 1.0),
    'bone_b': (T, 539, 985, 40, 43, 'sprite', 1.0),
    'coal': (T, 606, 980, 75, 58, 'sprite', 1.0),
    'bone_c': (T, 702, 982, 37, 45, 'sprite', 1.0),
    'rubble': (T, 759, 972, 87, 65, 'sprite', 1.0),
    'spire_small': (T, 867, 971, 52, 61, 'sprite', 1.0),
    'spire_tiny': (T, 922, 978, 41, 53, 'sprite', 1.0),
    'spire_big_t': (T, 984, 940, 94, 104, 'sprite', 1.0),
    'spire_mid': (T, 1086, 929, 64, 101, 'sprite', 1.0),
    'rocks_a': (T, 1164, 975, 69, 62, 'sprite', 1.0),
    'rocks_b': (T, 1249, 982, 51, 55, 'sprite', 1.0),
    'spires_lava': (T, 1322, 939, 74, 101, 'sprite', 1.0),
})
# props (prop sheet, scaled into the world)
A.update({
    'brazier_pillar': (P, 25, 48, 123, 221, 'sprite', PS),
    'brazier_rune': (P, 173, 79, 107, 189, 'sprite', PS),
    'brazier_demon': (P, 297, 82, 132, 186, 'sprite', PS),
    'brazier_bowl': (P, 447, 103, 116, 165, 'sprite', PS),
    'wall_torch_hook': (P, 596, 94, 81, 176, 'sprite', PS),
    'hanging_brazier': (P, 695, 36, 106, 232, 'sprite', PS),
    'wall_brazier': (P, 821, 57, 94, 213, 'sprite', PS),
    'torch_a': (P, 947, 109, 58, 145, 'sprite', PS),
    'torch_b': (P, 1046, 116, 74, 141, 'sprite', PS),
    'torch_c': (P, 1158, 117, 65, 144, 'sprite', PS),
    'chain_long': (P, 33, 306, 26, 158, 'sprite', PS),
    'chain_long_b': (P, 95, 306, 27, 158, 'sprite', PS),
    'chain_swag_b': (P, 148, 305, 95, 165, 'sprite', PS),
    'chain_hang': (P, 266, 305, 37, 167, 'sprite', PS),
    'cage_hang': (P, 321, 305, 73, 178, 'sprite', PS),
    'chain_hook': (P, 424, 306, 44, 162, 'sprite', PS),
    'shackle_a': (P, 495, 325, 46, 107, 'sprite', PS),
    'shackle_skull': (P, 560, 325, 57, 124, 'sprite', PS),
    'shackle_b': (P, 648, 325, 43, 122, 'sprite', PS),
    'skull_heap': (P, 714, 322, 178, 138, 'sprite', PS),
    'coal_skulls': (P, 898, 332, 144, 92, 'sprite', PS),
    'bones_scatter': (P, 919, 435, 118, 60, 'sprite', PS),
    'bone_d': (P, 1073, 348, 63, 56, 'sprite', PS),
    'bone_e': (P, 1151, 353, 76, 63, 'sprite', PS),
    'bone_f': (P, 1053, 393, 52, 75, 'sprite', PS),
    'bone_g': (P, 1167, 423, 65, 54, 'sprite', PS),
    'banner_1': (P, 19, 508, 127, 172, 'sprite', PS),
    'banner_2': (P, 159, 507, 115, 170, 'sprite', PS),
    'banner_3': (P, 288, 512, 111, 165, 'sprite', PS),
    'banner_4': (P, 411, 509, 99, 159, 'sprite', PS),
    'banner_5': (P, 523, 507, 109, 175, 'sprite', PS),
    'spire_big': (P, 646, 492, 158, 175, 'sprite', PS),
    'spire_big_b': (P, 812, 515, 136, 157, 'sprite', PS),
    'rocks_lava': (P, 947, 541, 99, 130, 'sprite', PS),
    'rocks_dark': (P, 1045, 557, 74, 112, 'sprite', PS),
    'boulders': (P, 1127, 588, 105, 78, 'sprite', PS),
    'spike_trap': (P, 21, 718, 160, 102, 'sprite', PS),
    'spike_trap_b': (P, 186, 718, 126, 100, 'sprite', PS),
    'grate_a': (P, 322, 713, 112, 106, 'sprite', PS),
    'vent': (P, 453, 713, 118, 106, 'sprite', PS),
    'grate_b': (P, 587, 712, 123, 109, 'sprite', PS),
    'altar': (P, 753, 677, 316, 190, 'sprite', PS),
    'skull_obelisk': (P, 1088, 674, 140, 196, 'sprite', PS),
    'portal': (P, 26, 845, 282, 211, 'sprite', PS),
    'portal_dark': (P, 331, 837, 250, 224, 'sprite', PS),
    'chest_closed': (P, 602, 925, 162, 125, 'sprite', PS),
    'chest_open': (P, 789, 902, 140, 144, 'sprite', PS),
    'chest_gold': (P, 940, 913, 126, 138, 'sprite', PS),
    'chest_empty': (P, 1091, 904, 137, 149, 'sprite', PS),
    'heart': (P, 26, 1108, 95, 91, 'sprite', PS),
    'fire_orb': (P, 147, 1104, 87, 96, 'sprite', PS),
    'key': (P, 268, 1087, 63, 118, 'sprite', PS),
    'rune_gem': (P, 367, 1096, 74, 108, 'sprite', PS),
    'icon_scroll': (P, 480, 1107, 93, 90, 'sprite', PS),
    'icon_swords': (P, 601, 1107, 90, 90, 'sprite', PS),
    'icon_chest': (P, 716, 1107, 95, 90, 'sprite', PS),
    'icon_demon': (P, 837, 1093, 105, 110, 'sprite', PS),
    'icon_demon_big': (P, 969, 1084, 128, 123, 'sprite', PS),
    'icon_door': (P, 1120, 1097, 104, 102, 'sprite', PS),
})
# wall frame pieces from the room design (RGB on black; already world scale)
A.update({
    'corner_cap': (D, 38, 8, 76, 76, 'design', 1.0),
    'wall_v': (D, 38, 628, 62, 70, 'design', 1.0),
})

BASE = (27, 18, 22)


def clean_opaque(im):
    b = im.buf
    for i in range(0, len(b), 4):
        a = b[i + 3]
        for c in range(3):
            b[i + c] = (b[i + c] * a + BASE[c] * (255 - a)) // 255
        b[i + 3] = 255


def clean_sprite(im, thr=128):
    w, h, b = im.w, im.h, im.buf
    for i in range(0, len(b), 4):
        b[i + 3] = 255 if b[i + 3] >= thr else 0
    # drop isolated specks (fewer than 2 opaque 8-neighbours)
    kill = []
    for y in range(h):
        for x in range(w):
            if b[(y * w + x) * 4 + 3] == 0:
                continue
            n = 0
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    if (dx or dy) and 0 <= x + dx < w and 0 <= y + dy < h and b[((y + dy) * w + x + dx) * 4 + 3]:
                        n += 1
            if n < 2:
                kill.append(y * w + x)
    for p in kill:
        b[p * 4 + 3] = 0
    # drop fragments of neighbouring sheet pieces: keep only the substantial regions
    label = [0] * (w * h)
    sizes = [0]
    for start in range(w * h):
        if label[start] or not b[start * 4 + 3]:
            continue
        lid = len(sizes); sizes.append(0)
        stack = [start]; label[start] = lid
        while stack:
            p = stack.pop(); sizes[lid] += 1
            px, py = p % w, p // w
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    nx, ny = px + dx, py + dy
                    if 0 <= nx < w and 0 <= ny < h:
                        q = ny * w + nx
                        if not label[q] and b[q * 4 + 3]:
                            label[q] = lid; stack.append(q)
    if len(sizes) > 1:
        keep_min = max(40, max(sizes) * 0.12)
        for p in range(w * h):
            if label[p] and sizes[label[p]] < keep_min:
                b[p * 4 + 3] = 0
    # darken the outermost ring slightly so the glow halo reads as an outline
    edge = []
    for y in range(h):
        for x in range(w):
            if b[(y * w + x) * 4 + 3] == 0:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if not (0 <= nx < w and 0 <= ny < h) or b[(ny * w + nx) * 4 + 3] == 0:
                    edge.append(y * w + x)
                    break
    for p in edge:
        i = p * 4
        r, g, bb = b[i], b[i + 1], b[i + 2]
        # halo pixels are dark red/purple: pull them towards a neutral dark outline
        m = (r + g + bb) // 3
        b[i], b[i + 1], b[i + 2] = (min(r, m + 10) * 3) // 5, (g * 3) // 5, (min(bb, m + 10) * 3) // 5
    return im


def clean_design(im):
    """Design crops are opaque RGB on black: make near-black background transparent."""
    b = im.buf
    for i in range(0, len(b), 4):
        if b[i] + b[i + 1] + b[i + 2] < 24:
            b[i + 3] = 0


def trim(im):
    w, h, b = im.w, im.h, im.buf
    xs = [x for y in range(h) for x in range(w) if b[(y * w + x) * 4 + 3]]
    ys = [y for y in range(h) for x in range(w) if b[(y * w + x) * 4 + 3]]
    if not xs:
        return im, 0, 0
    x0, x1, y0, y1 = min(xs), max(xs), min(ys), max(ys)
    return im.crop(x0, y0, x1 - x0 + 1, y1 - y0 + 1), x0, y0


def main():
    root, out = sys.argv[1], sys.argv[2]
    os.makedirs(out, exist_ok=True)
    sheets = {}
    manifest = {}
    for name, (sheet, x, y, w, h, kind, scale) in A.items():
        if sheet not in sheets:
            sheets[sheet] = img.load(os.path.join(root, sheet))
        pad = 0 if kind in ('opaque', 'design') else 4
        im = sheets[sheet].crop(x - pad, y - pad, w + 2 * pad, h + 2 * pad)
        if kind == 'opaque':
            clean_opaque(im)
        elif kind == 'design':
            clean_design(im)
        else:
            clean_sprite(im)
            im, _, _ = trim(im)
        img.save(im, os.path.join(out, name + '.png'))
        manifest[name] = {'w': im.w, 'h': im.h, 'scale': scale, 'kind': kind,
                          'src': '%s @ %d,%d %dx%d' % (os.path.basename(sheet), x, y, w, h)}
    json.dump(manifest, open(os.path.join(out, 'manifest.json'), 'w'), indent=1)
    print(len(manifest), 'assets written to', out)


if __name__ == '__main__':
    main()
