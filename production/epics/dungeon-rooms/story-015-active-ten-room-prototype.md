# Story015: Ten maps in the normal prototype, boss in room10

Status: Integrated, screenshots captured.26October2026.

The user explicitly authorized promoting the latest crypt library into the
normal prototype. `assets/data/dungeon_rooms.json` now contains ten templates
with campaign_room_count10. The first is the entrance, eight intermediate
normal rooms are seeded/shuffled without replacement, and the tenth is the boss.
`encounter.boss_enemies=3` means one boss plus two normal companions. Old3-room
lobby/victory labels are dynamic. The ordinary F5/Dev Run and crypt launcher
all load the active campaign; the saved personal source dungeon is untouched.

Stored configuration validation and normal seeded generation succeeded. A real
normal-game capture session generated ten distinct rooms and directly opened
rooms1,8,9,10 for unchanged GPU screenshots. Room10 actually spawned one boss;
other captured rooms spawned no boss. The Esc map shows ten nodes.

See `production/qa/evidence/current-prototype/README.md` for images and capture
conditions. This is focused startup/spawn/render evidence, not a full completed
playthrough, multiplayer test or performance result.

Prior active library backup:
`user://dungeon_editor/backups/dungeon_1793031994_27031155.json`.
