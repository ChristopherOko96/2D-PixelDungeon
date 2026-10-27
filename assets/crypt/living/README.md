# Animated crypt environment

**Aktive Original-Pack-Darstellung:** Nach dem Zurückstellen der Steinoptik
werden alle maskierten Frames einschließlich Frame0 identisch auf zwei Weltpixel
pro logischem Pixel projiziert. Die Quellen bleiben unverändert, Körper bleiben
fest. Statische crypt-Props verwenden Original-Pack-Ersatzgrafiken.


16animation types, four generated PNG frames each, native64px. The manifest
sets32/64px display size and individual frame rates. Place them on the32px world
grid via the **LIVING** editor palette. The original generated sheets are kept
under `source/`, the unchanged extracted frames under `frames/`.

Generated using the built-in image tool on26October2026. Exact prompts:
[PROMPTS.md](PROMPTS.md). Frame slicing:
`python scripts/import_living_sprites.py SHEET_A SHEET_B`.

## Static objects, animated contents

The raw generated frames vary some pot/stone details. The runtime therefore
does **not** swap whole object images. `living_sprite_library.gd` always keeps
frame0 as the fixed body and composites only explicitly allowed effect pixels:

- Flowers/leaves move above fixed pots, beds and roots.
- Flames change above fixed braziers and fixed candle wax/wicks.
- Lantern light changes inside a fixed metal structure.
- Well water changes within the fixed basin; the rim and body stay identical.
- Pages move above the fixed book stand; a drip changes beside the fixed urn.
- Mushrooms/runes change light while retaining their silhouettes.
- Free butterflies and wisps intentionally move as particles.

The manifest's `effect_regions` use `rect`, `ellipse` or `polygon` masks in64px
source coordinates. Modes: `replace`, `color_only`, `cyan_only`, `warm_only`,
`foliage_only`. Optional source/base color filters and source offsets keep
generated flame pixels attached to fixed wicks. `static_body_frame=0` documents
the invariant; there are no per-frame object translations or scale changes.
Outside effect masks the composed RGBA pixels are exactly those of frame0.
Original PNGs are never rewritten by this renderer.

`frame_image(id,frame)` exposes the actual composed output for asset previews.
The current `living_preview.gif` uses that output rather than the raw wobbling
frames. Export caches with `scripts/export_crypt_art_preview.gd`, then run
`python scripts/import_living_sprites.py --preview-frames .godot/art_preview/living`.

The **LIVING** palette automatically chooses non-blocking structure and disables
full replacement, preserving the floor below a prop. Room dressing is governed
by `assets/data/crypt_decoration_catalog.json`: paired planting beds, archive
rows, memorial lines and ritual clusters preserve central aisles and safe starts.
Decoration remains a visual candidate for the user's manual approval.
