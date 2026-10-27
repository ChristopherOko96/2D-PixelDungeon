# Unified crypt stone

**Verworfen/archiviert:** Der Nutzer hat diese graue Materialoptik wieder
abgelehnt. `UnifiedSkin.active=false`; aktive Räume verwenden die gelieferten
Original-Atlanten. Diese Quellen bleiben nur zur Wiederherstellung erhalten.
Sie dürfen nicht automatisch wieder eingeschaltet werden.


Current presentation revision,26October2026: the user requested that all existing
dungeon terrain match the detailed gray-violet furniture rather than keep the
old bright-purple surface style. The original four atlases remain unchanged.

The new generated master is `source/crypt_material_atlas.png`; the full built-in
image-generation prompt is in [PROMPT.md](PROMPT.md). The16material cells are
separated at native32×32 under `materials/` with nearest-neighbor sampling.

`src/unified_dungeon_skin.gd` uses those surfaces for all224cells of the four
existing terrain palettes. It retains the exact alpha silhouette and directional
relief of the original cells. IDs, wall joins, positions, floor masks and
collision remain authored data. The editor and live game use the same remapping.
Legacy rectangular rooms sample a224×256atlas at native32 detail.

Material IDs0–3: quiet flagstones, cracked flagstones, moss, worn engravings;
4–9: back/front masonry, coping, pier, baseboard and vertical edge;
10–15: garden stone/soil, water, stair, rubble, cracked wall and ivy wall.
Reserved accents are available for future room variants; the current mapping
uses the shared masonry/floor family consistently.

Reimport an atlas with `python scripts/import_unified_materials.py PATH`.
`scripts/export_crypt_art_preview.gd` exports the actual runtime texture caches
for static art illustrations, without creating a game scene. Matching preview
atlases in this folder are illustrations, not a gameplay test or export build.
