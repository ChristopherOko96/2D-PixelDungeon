# Crypt enemy sprite provenance

Generated on2026-10-26 with the built-in `image_gen.imagegen` tool using the
project's existing0x72 character frames only as visual style references.
The imported project actors are new generated subjects, not replacements of
the original0x72 files. Original project assets and their license notes remain
unchanged under `assets/sprites/0x72/`.

## Source images and prompts

- `source/skeleton_archer_sheet.png` — skeleton with small wooden shortbow;
  exact prompt: `source/skeleton_archer_prompt.txt`.
- `source/necromancer_sheet.png` — muted violet-robed skeletal caster with
  a small turquoise soul flame; exact prompt: `source/necromancer_prompt.txt`.
- `source/skeleton_guard_sheet.png` — skeleton with a small rusty round shield
  and short sword; exact prompt: `source/skeleton_guard_prompt.txt`.

Each generated sheet contains4columns and3rows: idle, walking, attack.
The full generated transparent PNGs are retained. They are not used as large
textures during gameplay; the engine loads the imported individual frames.

## Deterministic import

`scripts/import_crypt_enemies.gd` crops equal cells, aligns all feet to the same
bottom baseline, uses one uniform role scale for all frames, then maps colors
to a restrained20-color crypt palette. Import works on16×24effective pixels,
then doubles each pixel to2×2blocks on a32×48transparent canvas. No smoothing
or partial alpha is retained. Shapes are never stretched independently per
frame. `import_report.json` records all source crops and projected origins.

Paths consumed by the game:

`assets/sprites/crypt_enemies/<role>_<idle|run|attack>_f<0..3>.png`

The frame canvas is world-sized and renders at1×; old0x72character images
continue to render at2×. Frame0grounding and the game's existing feedback
system supply hit flash, recoil, hitstun, wobble and death pose.

`preview_contact.png` displays all36frames at actual asset size.
`preview_zoom.png` is its4×nearest-neighbor inspection view.

Read-only validation of the36final frames passed: every PNG is32×48RGBA,
all nontransparent alpha is fully opaque, every2×2pixel block is uniform,
each role/state has four distinct frame pixel hashes, and **all36used alpha
rectangles end at y=46** (two transparent bottom rows). Visible silhouettes
are30–36worldpixels high depending on pose; the canvas includes headroom.
The original goblin is likewise a small actor beside the taller player sprites.

The generated artwork is an implemented candidate matched to the retained
crypt style; subjective visual acceptance belongs to the user.
