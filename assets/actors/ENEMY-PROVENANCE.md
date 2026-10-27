# Enemy actor key art

Created on 2026-10-26 with the built-in image generation tool, using the project's existing enemy art as visual references. These source sheets supply authored directional key poses to the shared animation baker. They are not, on their own, 48 completed animation sequences.

## Sources and identity

| Actor | Preserved identity | Original generated sheet | Exact generation prompt |
| --- | --- | --- | --- |
| Skeleton archer | Warm bone skull, shortbow, brown quiver | [source/skeleton_archer_poses.png](source/skeleton_archer_poses.png) | [source/skeleton_archer_prompt.txt](source/skeleton_archer_prompt.txt) |
| Necromancer | Violet hood and robe, skull face, teal soul staff | [source/necromancer_poses.png](source/necromancer_poses.png) | [source/necromancer_prompt.txt](source/necromancer_prompt.txt) |
| Skeleton guard | Warm bone, small round shield, short sword | [source/skeleton_guard_poses.png](source/skeleton_guard_poses.png) | [source/skeleton_guard_prompt.txt](source/skeleton_guard_prompt.txt) |
| Boss | Existing broad purple horned demon, red eyes, pale horns and claws | [source/boss_poses.png](source/boss_poses.png) | [source/boss_prompt.txt](source/boss_prompt.txt) |

References inspected before generation:

- `assets/sprites/crypt_enemies/preview_zoom.png`
- `assets/sprites/crypt_enemies/skeleton_archer_idle_f0.png`
- `assets/sprites/crypt_enemies/necromancer_idle_f0.png`
- `assets/sprites/crypt_enemies/skeleton_guard_idle_f0.png`
- `assets/sprites/0x72/big_demon_idle_anim_f0.png`

The original PNGs and prompts are retained unchanged. Legacy sprites in `assets/sprites/crypt_enemies/` and `assets/sprites/0x72/` are not replaced by this import.

## Directional key poses

Each original sheet contains four rows and four columns. Columns are south/front, east/right, north/rear, west/left. Rows are idle, move, attack, hurt. North is a generated back view, not a vertical flip. West is also independently generated; no horizontal mirror is used for these keys.

The generated sheets have uneven margins. Dividing their dimensions into four equal slices cuts through some feet and can introduce pixels from a neighbouring pose. The importer instead extracts the sixteen largest eight-connected alpha silhouettes, orders them by row and column, and retains each silhouette's own pixel mask. This removes neighbouring fragments without cutting the intended character silhouette.

## Runtime pixel contract

| Actor | Key canvas | Nominal idle height | Exclusive used-foot end Y | World scale |
| --- | --- | --- | --- | --- |
| Skeleton archer | 24 × 32 | 20 px | 31 | 2 |
| Necromancer | 24 × 32 | 20 px | 31 | 2 |
| Skeleton guard | 28 × 32 | 20 px | 31 | 2 |
| Boss | 48 × 48 | 32 px | 47 | 2 |

The exclusive foot end leaves the final canvas row transparent. Every pose is positioned against the same role-specific foot line. A single uniform source scale per actor comes from the tallest idle view; it is reused for all sixteen poses. Width and height are never scaled independently. Wide attack gestures increase transparent canvas padding instead of shrinking the body or clipping a weapon. All final keys fit their canvases without clipping.

Nearest-neighbour sampling produces hard pixel edges. Alpha is thresholded at 0.6 to transparent or fully opaque. The NPCs use the existing twenty-colour crypt palette; the boss adds ten purple/red hues. This processing uses Godot's Image API, not Python image editing. The effective world pixel block remains 2 for every actor.

## Rebuild and inspect

Run from the Godot project root:

```text
godot --headless --path . --script res://scripts/import_enemy_actor_keys.gd
```

The importer writes sixteen key PNGs per actor at `assets/actors/keys/{actor}/{direction}_{pose}.png`, plus `preview_contact.png`, a nearest-neighbour `preview_zoom.png`, and `layout.json`. The combined report is `assets/actors/enemy_key_import_report.json`.

Each layout records the source alpha bounds, projected size, destination origin, exclusive foot end, clipping flag, canvas size, scale, and direction provenance. The animation baker should read the actual key dimensions or layout metadata; the guard and boss intentionally use wider canvases.

All four contact sheets were visually inspected after import. The final import completed with 64 keys and no clipping.
