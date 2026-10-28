# Hell-Dungeon sprites — source and licence note

- **Source:** `rooms.zip` from the user (folder `C:\Users\ctnsa\Desktop\Projekte\Assets_Vorlagen`),
  sheets `tiles/SOURCE_hell_tilesheet.png`, `decorations/SOURCE_hell_propsheet.png` and the room design
  `room_designs/combat_A_obsidian_pillars.png` (corner cap and side wall piece only).
- **Processing:** cut and cleaned by `tools/hell_dungeon/extract.py` (hard alpha edge, no red/purple halo,
  fully opaque floor and lava tiles, neighbour fragments removed), then resampled to world scale by
  `tools/hell_dungeon/world.py` (one floor slab = 96 px). `manifest.json` lists every file, its size and
  the sheet rectangle it came from.
- **Licence: unknown.** The sheets carry no licence and look AI-generated. The user chose this look as the
  Hell-Dungeon style on 2026-10-28. Clarify or replace before a public release of the game.
