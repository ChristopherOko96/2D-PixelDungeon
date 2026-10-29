# Hell-Dungeon 0x72 skin — source and licence note

- **What:** the Hell-Dungeon level art (tiles, walls, decorations, props, loot, icons) in the pixel
  style of the Krypta der Verdammten, with the hell's own colours. Every name of
  `assets/sprites/hell/manifest.json` has a sprite here, plus `wall_top`.
- **Built by:** `scripts/make_hell_skin.gd` (Godot, no other tools), from the user's 0x72 folder:
  `godot --headless --path . -s res://scripts/make_hell_skin.gd -- "<...>/Sprite Sheet 0x72"`
- **Sources:**
  - 0x72 DungeonTilesetII v1.7: floor, walls, column, column_wall, wall_hole, chest, hole,
    floor_spikes, button, big_demon, ui_heart, doors frames, weapon_regular_sword.
    Author Robert (0x72), CC0 (see `assets/sprites/0x72/LICENSE-NOTE.md`).
  - dungeontiles-extended v1.1 by Nijikokun (https://nijikokun.itch.io/dungeontileset-ii-extended,
    same style, made for 0x72's set): flames, torches, candles, the arch, the key and the sign.
    Free pack; the user confirmed its use on 2026-10-28 (see `assets/sprites/frost/LICENSE-NOTE.md`).
  - Everything else is drawn pixel by pixel in that script in the 0x72 manner. That covers lava,
    obsidian spires, rocks, coal, bones, the skull, chains, cages, braziers, banners, runes, the seal,
    the altar, the portcullis, the portal, bridges, grates and the lintel.
- **Colours:** only the hell palette (`HEX` in the script), sampled from the first hell set in
  `assets/sprites/hell/`. Every 0x72 colour is mapped onto it per material.
- **Density:** 16 px tiles drawn x3 (one floor cell = 2 x 2 tiles = 96 px). Heart, sign, big demon
  icon and runestone are x4/x5 because the game draws them smaller. Checked by
  `tests/hell_skin_test.gd`.
- **Licence:** the 0x72 parts are CC0; the extended parts as above. The drawn parts are this
  project's own work. Credits: 0x72, Nijikokun.
