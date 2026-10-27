# Story017: Quiet first prototype, no room dressing, and stutter reduction

Status: Implemented; focused CPU profiles recorded, manual acceptance pending. 26 October 2026.

The latest user clarification selects the FIRST Godot prototype 44c9b80:
original 32px slate floor, clear raised masonry edges and the original warm
orange torch. It supersedes the saturated original-pack restoration in016
and the earlier dense generated material experiment.

Active crypt rooms use `render_style=classic_quiet` and
`decoration_enabled=false`. Furniture, plants, memorial props, chests,
reward pedestals and fog/background motes are omitted. Gameplay doors,
interior stairs, fire, actors and automatic reward cards remain. Future
dressing must follow this same quiet pixel style. Original PNG sources remain.

`src/classic_dungeon_art.gd` prepares a native floor texture and tightly cropped
wall-row textures at the room-change boundary. The view reuses these surfaces
and keeps wall rows in the actor depth order. No per-frame full-room tile
classification or generated material pass is needed for this style.

Collision/navigation data is cached for repeated movement/path queries;
enemy path refreshes are staggered. Snapshot handling reuses local presentation
state and cached room geometry rather than repeatedly copying or transmitting
the full unchanged authored tile collection with each dynamic update.

All ten active maps, their wall/collision logic, boss exclusively in room10,
editor authoring, exploration, reward cards and fades remain. The personal
saved source dungeon is unchanged. There was no blanket Git revert or rollback
to the early three-room gameplay implementation.

Focused draw profiling used the same garden layout, 1769 tiles, one player,
six enemies and 120 samples before/after in an isolated actual GPU DungeonView.
CPU time inside `_draw` changed from 15.343 ms median / 17.079 ms p95 to 0.353 ms
median / 0.386 ms p95. One-time presentation preparation was 38.466 ms.

The same ten obstructed garden path queries changed from 1878.081 ms total to
11.223 ms total, with 50.327 ms for initial graph construction. All ten resulting
paths had no blocked segments against the original collision predicate.

Raw timings and capture conditions:
[performance.json](../../qa/evidence/classic-quiet/performance.json).

These are isolated CPU measurements, not full-game frame or GPU timings,
a measured FPS guarantee, a completed playthrough or a multiplayer load result.
An additional visible normal-prototype solo garden profile ran real combat
with six enemies, one second warmup and six seconds sampling on the RX6600.
It recorded864frames/143.98FPS, median6.945ms / p958.290ms / max9.114ms frame
interval. Game callbacks had p950.163ms process and1.481ms physics time.
No player/enemy stats were changed. A previous hidden-window capture recorded
50FPS; the separate visible-window measurement avoids treating that capture
condition as the game's performance. Host visuals/camera update each physics
tick via local_visual_tick while network snapshots remain20Hz.

No broad unit/gameplay/network suite was run for this revision. Longer sessions,
visual/play acceptance and multiplayer performance remain open.

Guide: `docs/ORIGINAL-TILE-RESTORE.de.md`; current crypt status:
`docs/CRYPT-OF-THE-DAMNED.de.md`. Earlier screenshot collections show historical
material and pack-restoration stages, not acceptance of the current result.
