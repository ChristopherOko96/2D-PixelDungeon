# Player key artwork provenance

The four player identities were newly drawn with the built-in Imagegen tool on
2026-10-26. Each identity has one preserved transparent 4-by-4 source sheet and
its exact generation prompt in `source/`. These are directional key poses for
the animation compiler; the 16 keys are not claimed to be 48 animation clips.

| Actor | Visual identity | Preserved source | Exact prompt |
| --- | --- | --- | --- |
| `player_warden` | Teal helmet, short leather body, compact crossbow/focus | `source/player_warden_poses_sheet.png` | `source/player_warden_prompt.txt` |
| `player_ranger` | Amber cap, pale face/hair, compact crossbow/focus | `source/player_ranger_poses_sheet.png` | `source/player_ranger_prompt.txt` |
| `player_arcanist` | Violet pointed hat, short robe, crystal staff | `source/player_arcanist_poses_sheet.png` | `source/player_arcanist_prompt.txt` |
| `player_lizard` | Coral scales, short muzzle/tail, cream belly, crossbow/focus | `source/player_lizard_poses_sheet.png` | `source/player_lizard_prompt.txt` |

The ranger source produced a rounded cap/helmet-like silhouette rather than the
requested cloth hood. The selected original is preserved as requested; the
importer does not invent a different costume. The weapons retain the existing
ranged gameplay roles and do not add class mechanics.

The visual references supplied to Imagegen were the existing
`assets/sprites/crypt_enemies/preview_zoom.png`, the respective old 0x72 player
idle frame (`knight_m`, `elf_f`, `wizzard_m`, `lizard_m`), and the quiet dungeon
room screenshot at
`production/qa/evidence/story-021-perk-builds/04-combined-projectiles.png`.
The old player images served as identity references; they were not copied into
the new keys. No external sprite download was added.

## Source preservation

Original PNG SHA-256 values:

| Actor | SHA-256 |
| --- | --- |
| Warden | `d00b20651bfee7162713fa23ddf6a6e1fbf295e6c5b30d3800171158e2796128` |
| Ranger | `3b96c392aea3d172a6bfcfc493cc1670d9f75a9b56defba207f0b4a7124b038d` |
| Arcanist | `6afc028ffa7b3fd079ef42aee825192c0e6be1d93ac10368472d0f1e1ea7b534` |
| Lizard | `2549436e02b6e25ea09a52be733837e9782b85d13cd343e850c6681de85f795c` |

## Reproducible import

Run from the project root with the pinned Godot binary:

```powershell
& '../tools/godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script res://scripts/import_player_actor_keys.gd
```

The importer uses Godot image APIs only. It splits the source into four columns
(south, east, north, west) and four rows (idle, move, attack, hurt), takes the
largest connected actor silhouette within each cell, and excludes disconnected
neighbour-cell bleed and VFX specks from the crop bounds. This matters for the
arcanist's extended staff, which crosses a source cell boundary. It does not
rotate an upright sprite to fabricate a north view. All four source directions
are used directly; no west mirror operation is applied.

Each actor receives one fixed scale derived from its four idle poses, targeting
20 native pixels in height. Hats, weapons and tails use the surrounding padding
instead of reducing a character's body size to fit a 16-pixel-wide box. The same
scale is applied to all 16 poses of that actor, preserving pose proportions.
The result is nearest-neighbour sampled and mapped to 16 shared crypt colors
plus four identity colors. Alpha is strictly 0 or 255.

Every key is a **24-by-32 RGBA PNG**, displayed at source scale 2 by the motion
bank. Its visible alpha ends at Y=31 (exclusive), leaving the final row
transparent. The foot center is aligned to X=12 where space permits; the
import report records the few wide poses whose X placement must be clamped to
keep the complete gesture in the canvas. No pose is resized independently or
cut off to fit.

Outputs are `keys/<actor>/<direction>_<pose>.png`. Each actor directory also
contains the native contact sheet, a nearest-neighbour enlarged visual preview,
and `import_report.json` with source bounds, fixed scale, placement, used
rectangle and per-key RGBA digest.

## Import validation

The importer validates nonempty artwork, hard alpha, and the common foot
baseline before writing a key. The final import produced all 64 keys, with
16 distinct RGBA images per actor and no canvas overflow.
A second import produced byte-identical PNG hashes for all 64 keys.

| Actor | Idle visible heights, S/E/N/W | Maximum key width/height |
| --- | --- | --- |
| Warden | 20 / 19 / 19 / 19 | 19 / 21 |
| Ranger | 20 / 20 / 20 / 20 | 20 / 20 |
| Arcanist | 20 / 20 / 20 / 20 | 24 / 21 |
| Lizard | 20 / 20 / 20 / 20 | 24 / 21 |

The contact sheets were visually checked for genuine front/side/back views,
uniform foot baselines, chibi proportions and the teal/amber/violet/coral player
identities. Gameplay and balance testing are outside this artwork import.
