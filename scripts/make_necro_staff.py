# The necromancer's bone sceptre, 8x30 like the 0x72 magic staffs (same
# outline colour and layout), drawn by hand: a skull with green eyes on a bone shaft.
import sys
from PIL import Image
rows = [
"..aaaa..",
".awwwwa.",
"awwwwwwa",
"awgwwgwa",
"awgwwgwa",
".awwwwa.",
"..awsa..",
"..asba..",
]
shaft = "..awba.."
knob = ".awwwba."
for y in range(8, 29):
    rows.append(knob if y in (13, 20) else shaft)
rows.append("..aaaa..")
pal = {'a': (0x22, 0x22, 0x22, 255), 'w': (0xe8, 0xdc, 0xc6, 255), 'b': (0xa8, 0x97, 0x7a, 255), 's': (0x6a, 0x5c, 0x48, 255), 'g': (0x9c, 0xff, 0x8a, 255), '.': (0, 0, 0, 0)}
im = Image.new('RGBA', (8, len(rows)))
for y, r in enumerate(rows):
    for x, c in enumerate(r):
        im.putpixel((x, y), pal[c])
im.save(sys.argv[1])
print(im.size)
