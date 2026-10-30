# 16x16 DungeonTileset II — source and license note

- **Author:** Robert (0x72)
- **Version:** v1.7 (`0x72_DungeonTilesetII_v1.7.zip`)
- **Source:** https://0x72.itch.io/dungeontileset-ii (pay what you want, downloaded 2026-10-25)
- **License:** CC0, per the author's own statement in the itch.io comments
  ("use this tileset for whatever you like (CC-0)"), e.g. https://itch.io/post/8951485

The zip itself ships no license file; its README covers only tile layout.
The project owner decided on 2026-10-25 to use and redistribute the pack on
the strength of the author's statement. If the author ever publishes different
terms, re-check them here.

Only the frames this game draws are copied here, unchanged: the idle, run and
hit frames of `knight_m`, `elf_f`, `wizzard_m` and `lizard_m`, and the idle and
run frames of `goblin`, `orc_shaman` and `big_demon`. They are drawn at an
integer 2x scale, so each source pixel covers 2x2 on the game's 32 px grid.

Added later from the same pack, unchanged: crypt tiles and props (floors,
walls, banners, fountains, doors, column, crate, skull, chests) and on
2026-10-28 the Mimik frames `chest_mimic_open_anim_f0-2` (Werkstatt Mimik).

Added 2026-10-29 for the themed endless floors (ported from the
`codex/0x72-dungeon` branch), unchanged: idle and run frames of `chort`,
`wogol`, `doc`, `pumpkin_dude`, `big_zombie`, `angel`, `orc_warrior`,
`masked_orc`, plus `wall_edge_mid_left`, `wall_edge_mid_right`, `wall_goo` and
`wall_goo_base`. The five-row sheets in `assets/sprites/orcs_0x72/` and
`assets/sprites/bosses_0x72/` start from these 0x72 frames; their attack, hit
and death rows are derived from them, and the bosses add drawn pixel parts.


`custom_pyromancer_*` is not from the archive: it is drawn for this game in the archive's hero format (16x28, 4 idle, 4 run, 1 hit frame) by `scripts/make_pyromancer.py`, after the user's fire mage concept sheet (30.10.2026).

`assets/sprites/companions/falcon_*` is not from the archive either (the archive has no bird): the beast master's falcon, drawn for this game in the Enchanted Forest pack's format (32x32, ink outline, 4 wing beats) by `scripts/make_falcon.py` (user wish 30.10.2026).

`assets/sprites/companions/pyro_*` is drawn for this game too: the fire mage's Pyro-Monster, a charcoal imp in the archive's 16x22 companion format by `scripts/make_companion_sprites.py` (user wish 30.10.2026).
