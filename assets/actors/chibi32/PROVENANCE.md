# Chibi32 actor art — source and import

Current27.10.2026. Created and restyled with the built-in Imagegen tool, using
the newly generated detailed crypt actors as identity references. The user's
hell sheets and room were references for density only, never theme/palette.

User steering selected32×32 after an initial64px proposal, then cute chibi
proportions instead of adult anatomy. Final runtime keys are32×32 for all eight
actors; the high-resolution source sheets are preserved master artwork.

| Actor | Generated master | Exact prompt | Native32 keys |
| --- | --- | --- | --- |
| Warden | [sheet](source/player_warden_chibi_sheet.png) | [prompt](source/player_warden_prompt.txt) | [contact](keys/player_warden/preview_contact.png) |
| Ranger | [sheet](source/player_ranger_chibi_sheet.png) | [prompt](source/player_ranger_prompt.txt) | [contact](keys/player_ranger/preview_contact.png) |
| Arcanist | [sheet](source/player_arcanist_chibi_sheet.png) | [prompt](source/player_arcanist_prompt.txt) | [contact](keys/player_arcanist/preview_contact.png) |
| Lizard | [sheet](source/player_lizard_chibi_sheet.png) | [prompt](source/player_lizard_prompt.txt) | [contact](keys/player_lizard/preview_contact.png) |
| Skeleton archer | [sheet](source/skeleton_archer_chibi_sheet.png) | [prompt](source/skeleton_archer_prompt.txt) | [contact](keys/skeleton_archer/preview_contact.png) |
| Necromancer | [sheet](source/necromancer_chibi_sheet.png) | [prompt](source/necromancer_prompt.txt) | [contact](keys/necromancer/preview_contact.png) |
| Skeleton guard | [sheet](source/skeleton_guard_chibi_sheet.png) | [prompt](source/skeleton_guard_prompt.txt) | [contact](keys/skeleton_guard/preview_contact.png) |
| Eldritch boss | [sheet](source/boss_chibi_sheet.png) | [prompt](source/boss_prompt.txt) | [contact](keys/boss/preview_contact.png) |

Each sheet supplies four views (south/east/north/west) and four key poses
(idle/walk/attack/hurt). North is an authored rear view. The sixteen complete
eight-connected silhouettes are extracted and sorted by row/column; uneven
sheet spacing is not assumed to be a regular quarter crop. Nearest sampling,
hard alpha and a64-color actor palette create actual native32 keys. Bright/jade
accents are retained beside common costume shades so eyes/crystals do not
disappear only because they occupy fewer pixels. Foot endY31 is shared across
poses; a single scale per actor preserves equipment proportions.

The actor profile and import report record sizes, scale and per-frame bounds.
The baker adds transparent movement padding, then produces48 articulated motion
clips per actor in four views. The generated keys themselves are not claimed
to be48 separate hand-drawn animation sets. The runtime uses2× integer pixels
for ordinary actors,3× for the larger boss, and nearest filtering.

Previous adult-proportion candidates are retained in `../detail32/`; they are
not active. Old Story023 source art and atlases also remain intact. Full usage,
schema and observed evidence: [CHIBI32-ELDRITCH.de.md](../../../docs/CHIBI32-ELDRITCH.de.md).
