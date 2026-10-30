# Hell-Dungeon tools

One source of truth for the ten hell floors: `hell_core.js` holds floor 1 (handmade, user-approved) and
the seeded generator for floors 2-10. The browser preview and the Godot game both use its output.

| File | Purpose |
| --- | --- |
| `hell_core.js` | Floor data, generator, dressing rules, quickest-path check. Pure JS (node and browser). |
| `bake_floors.js` | `node tools/hell_dungeon/bake_floors.js` writes `assets/data/hell_floors.json` for Godot. |
| `check_floors.js` | `node tools/hell_dungeon/check_floors.js ./tools/hell_dungeon/hell_core.js ./assets/sprites/hell/manifest.json` prints rooms, quickest path, doors and entities per floor. |
| `preview_template.html` | The playable browser preview (all floors, floor picker, minimap). |
| `build_preview.py` | Inlines sprites, sizes and the core into one HTML file: `py -3 -I build_preview.py preview_template.html ../../assets/sprites/hell ../../assets/sprites/0x72 hell_core.js <out.html>` |
| `img.py`, `extract.py`, `world.py`, `contact.py` | Dependency-free PNG tools: cut and clean the source sheets (`extract.py <rooms_dir> <clean_dir>`), resample to world scale (`world.py <clean_dir> assets/sprites/hell`), contact sheet for review. |

After changing `hell_core.js`: run `bake_floors.js`, then the tests `tests/hell_floor_data_test.gd`,
and rebuild the preview if it should match.

## The hell on the world kit (the game's floors now)

The game no longer reads the baked floors: every hell floor is built live from the run number on the
world kit (`docs/WELT-BAUKASTEN.de.md`). `hell_core.js` and `hell_floors.json` stay for their tests.

| File | Purpose |
| --- | --- |
| `hell_world.js` | The hell as a world kit pack: ten floors (titles, bosses, hazards as before, floor 1 generated too), hell room sizes, names, banner colours, dressing tables. |
| `export_world.js` | `node tools/hell_dungeon/export_world.js` writes `assets/data/hell_world.json` for Godot. |
| `build_hell_extras.py` | `py -3 -I tools/hell_dungeon/build_hell_extras.py` paints the world kit pieces the hell sheets lack (from their crypt counterparts, in the hell palette) into `assets/sprites/hell` and the pixel set `assets/sprites/hell_0x72`, and the hell-wood mimic atlas `assets/sprites/hell/monsters/mimik.png`. |
| `build_world_preview.py` | `py -3 -I tools/hell_dungeon/build_world_preview.py <out.html>`: the playable preview of the generated hell (the crypt's world kit page with the hell's pack, skin and monsters). |

## Monsters and Ignaroth's part rigs

| File | Purpose |
| --- | --- |
| `hell_monsters.js` | Every hell monster as a small pixel program (`draw(P, anim, frame)`), stats, attacks, floors. Ignaroth (`drache1..4`) has no drawing of his own here: his defs take their frame size and finished frames from `drake_hybrid.js` (`def.frame(anim, f)`, `sheetLayout`), his atlas stores 3x3 texels per source px (`px: 3`; 98 MB for all four, see `drakeDef`), his death row crumbles in his material (`ash`: violet for form 4), and `r` is half his body-and-legs footprint. |
| `drake_hybrid.js` | Ignaroth's production art, the approved concept "Hybrid" (user, 2026-10-29: "Ja, so einbauen"): every rig part sculpted from volumes, lit and quantised to the 0x72 palette, tagged with its part (`P.part`) and pivots/points (`P.joint`). `renderRig(form, part, frame, skip)` draws one part isolated (or all), `parts`/`compose` stack them by the rig layers (`PARENT`, `Z`), `posed(form, pose, frame, pad)` turns the parts about their pivots like `src/rig/rig_poses.gd`, `wingRange(form, wing)` gives a wing's `flap` sign and `swing` range, `sheetPose`/`sheetLayout`/`sheetFrame` pose the atlas rows (idle, run, attack, cast, fly; death comes from idle). UMD: `window.DrakeHybrid` in the browser preview, after `hell_monsters.js`. |
| `concepts/hybrid.js` | Thin wrapper over `drake_hybrid.js`: the concept's rig check and preview sheets (`node tools/hell_dungeon/concepts/hybrid.js [repo_root]` writes `production/qa/evidence/drake-concepts/hybrid_*.png`). |
| `export_monsters.js` | `node tools/hell_dungeon/export_monsters.js [repo_root] [--only id,id]` writes the atlases `assets/sprites/hell/monsters/<id>.png` and `assets/data/hell_monsters.json`. `--only` writes just those atlases and replaces just those entries of the existing JSON (every other entry, the floors and the key order stay), e.g. `--only drache1,drache2,drache3,drache4` after a change to Ignaroth's art. |
| `export_rigs.js` | `node tools/hell_dungeon/export_rigs.js [repo_root] [--preview]` writes Ignaroth's four forms as part rigs: one full-frame PNG per part in `assets/sprites/hell/rigs/drache<N>/` (1 px per source px, flames as `<part>_0..3.png` flipbooks) and `assets/data/hell_rigs.json` (parts, pivots, parents, layers, HP weights, what a lost part disables or weakens, groups, points; wings also `flap` and `swing`). It creates missing folders and deletes part files of a form that its rig no longer lists (with their `.import` files). `--preview` also writes `production/qa/evidence/hell-rigs/preview_drache<N>.png` (rest pose from the parts, an exploded view with pivots, one row per part). |
| `export_rigs.js --check` | `node tools/hell_dungeon/export_rigs.js [repo_root] --check` writes nothing and checks `hell_rigs.json` and its PNGs on disk: images exist, fit the frame, are not empty and have no opaque pixel on row 0, column 0 or the last column (cut by the frame); flipbooks have 4 frames, at least 3 of them different; parents, pivots, points and feet make sense; each severable part holds 8-20 % of the form, all of them together at most 60 %, the body the largest unbreakable share; each severable part has at least 20 px where a hit lands on it (the highest layer there, as `RigLibrary.part_at` decides); every attack id in `disables`, `weakens`, `exposed` and the groups exists for that form in `hell_monsters.json`; `alsoDetach` parts and group members exist with hp >= 1; only wings carry `flap` (+-1, matching the side their membrane spreads to) and `swing` ([lo <= 0 <= hi] within +-pi). Prints `HELL_RIGS checked=N failures=M`, exits 1 on a failure. |
| `monster_sheet.js` | Review sheet of every monster's animations; also the PNG writer the exporters use. |

How the rig export works: `drake_hybrid.js` `renderRig(form, part, frame)` draws the form in its rest
pose with a painter that keeps only the draw calls tagged with that part, so each part comes out whole
(also where other parts cover it) with its own outline. Neighbours that overlap at a joint (body and
neck, neck and head, the tail chain) draw no outline over each other (`SEAMLESS`). Each form's frame is
the drawing cropped with 2 px to spare (79x47, 92x64, 120x98, 186x128 source px; the feet on the bottom
row). The tail's ten steps map to five parts: tail_1 2 steps, tail_2 4 (the part a cut takes off in
forms 1 and 2, and the highest tail layer, so hits on its joints count for it), tail_3 and tail_4 1
each, tail_5 2 (with the spiked club in forms 3 and 4). Part ids and layers live in `drake_hybrid.js`
(`PARENT`, `Z`); HP weights and effects in `export_rigs.js` (`FORMS`).

Wings (`wingRange`): `flap` is 1 when the membrane spreads left of its pivot (a clockwise turn lifts
it) and -1 when it spreads right of it (form 4's far wing, fanned out beside the head); `swing` is the
range of turns (rad, 0.01 steps, at most 1.2) in which the wing covers no more of the head, horns and
jaw than at rest (+1 % of its pixels, at least 4). The head lies on the side of the smaller limit.

The wing and head rules (`src/rig/rig_poses.gd`, mirrored for the sheets in `drake_hybrid.js`
`sheetPose`; the approved design doc `docs/HOELLE-RIGS.de.md` does not describe them yet):

- Every wing turn in the poses is written as a lift (positive = up, as for a flap 1 wing) and turned
  by the wing's flap sign at the end, so both wings lift together; roar ("rear up with the wings
  raised") and the take-off windup lift, the take-off pushes off with one downstroke (`DRAKE_PUSH`).
- Every wing turn eases into its swing range, and the limit on the head's side recedes as the head
  rears: by all of the neck's backward turn and all of the head's for a wing behind the head (form 3's
  far wing), a quarter of the head's for a wing above it (form 4's far wing, `DRAKE_WING_HEAD_REAR`).
- Under a wing above the head (flap -1) the neck hands 70 % of a backward turn to the head
  (`DRAKE_NECK_UNDER_WING`): the head rears as far, but is not carried up into the wing.
- A wing resting against the head (room toward it < 0.1 rad, `DRAKE_WING_TOUCH`) breathes and beats
  only upward, through its whole range (`_drake_beat`), instead of parking at the limit half a beat.
- `tests/drake_pose_test.gd` checks the wing against the posed head (+2 % of its pixels), the lift
  of roar and take-off, the downstroke, the full beat and the joints (45 % of the rest overlap kept).

Tuned phases: `DRAKE_CYCLES`, `DRAKE_FLIP_PHASE` and `DRAKE_FLIP_BEAT` exist only to keep three parts
from peaking in one 1/30 s (ANIM-01's bin check, a matter of chance with 12-18 parts on unrelated
periods). After any change to the idle, walk or flight poses, run `tests/drake_pose_test.gd`; if only
"at most 2 parts peak in one 1/30 s bin" fails, sweep the constant of that gait in steps of 0.1 (the
crowded bin is printed with its parts), keep a value in the middle of a passing band and note the band
next to the constant.

The atlases: every row is posed from the same parts (`sheetPose`, a simple 8-frame loop per row with
the feet kept on the floor), and the frame is the union of all rows, cropped so the feet's middle is the
frame's horizontal centre and the ground row its bottom row, like every other monster's frame: 90x49,
99x66, 125x103, 222x156 source px. So every place that draws a drake sheet (intro, echoes,
transformation, the browser bestiary) shows the hybrid art. Known gap: a row repeats every 8 frames
(0.6-0.9 s), so in the sheets all parts share that one period (phases and a second harmonic on tail and
jaw only spread their peaks); the void_lord feel (ANIM-01/06) exists only in the part rig, which the
game draws once `DrakeRigHost` is wired into `hell_monsters.gd`. Until then hosts that draw the atlas
can aim from the rig: `RigLibrary.foot_offset("drache<N>", "mouth" | "core" | "top")` gives world px
from the feet, which the atlas frames share (bottom centre).

After changing Ignaroth's drawing, his poses or the rig tables:

```
node tools/hell_dungeon/export_rigs.js --preview
node tools/hell_dungeon/export_rigs.js --check
node tools/hell_dungeon/export_monsters.js --only drache1,drache2,drache3,drache4
<godot> --headless --path . --import
<godot> --headless --path . -s tests/hell_rig_library_test.gd
<godot> --headless --path . -s tests/drake_pose_test.gd
<godot> --path . --resolution 960x600 -s res://scripts/capture_hell_rigs.gd -- res://production/qa/evidence/hell-rigs 1,2,3,4 rig
<godot> --path . --resolution 1280x720 -s res://scripts/capture_hell_rigs.gd -- res://production/qa/evidence/hell-rigs 1,2,3,4 game
```

The capture (a window is needed) has two modes. `rig` draws the four forms through `RigLibrary`,
`RigPoses` and `RigRenderer` into `production/qa/evidence/hell-rigs/rig-drache<N>-{idle,walk,attacks,flight,hit,sever}.png`:
rig previews, not what the player sees yet. `game` debug-starts the real hell scene in the boss rooms of
floors 3, 6, 9 and 10 (its own user:// graphics and meta files, deleted afterwards) and saves
`game-drache<N>-{steht,schuss,atem}.png` and `game-drache4-hd.png`: the atlas as the game draws it, with
a cyan cross on the rig's mouth and a yellow one on `hell_monsters.gd`'s breath origin.
