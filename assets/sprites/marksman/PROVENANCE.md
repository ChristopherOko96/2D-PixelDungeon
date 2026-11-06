# Scharfschützen-Angriffe

2026-11-05: the existing spear source is now also partitioned into a nine-part
ultimate rig, with two five-joint native feather wake chains. No new image
generation or source PNG changes. See `docs/HIMMELSSPEER-RIG.de.md`.

2026-11-04. Generated using the built-in Imagegen tool, then deterministically
imported by `scripts/import_marksman_sprites.gd`. New original effect artwork;
the supplied 0x72 source files and their licenses remain intact.

The user requested new sharpshooter attack sprites, reviewed the seven-attack
board shown in this chat, then requested implementation in the current game.
The approved board is preserved as `source/approved_attack_board.png`.
Its hooded character is a reference, not an active replacement hero.
The exact board prompt is `source/approved_attack_board_prompt.txt`; its style
reference was `production/qa/evidence/style-reference-review/style-b-original-roles.png`.

`source/attack_effects.png` is the unmodified generated transparent master.
`source/attack_effects_prompt.txt` preserves its exact prompt. The reference
for that call was the approved board. The output's actual size was 1448×1086;
the importer uses proportional grid boundaries, not the requested 1024×768.

The twelve native outputs, in master row order:

1. aimed_arrow, piercing_arrow, volley_arrow, hail_arrow;
2. spear_arrow, hunters_mark, hit_small, hit_large;
3. chips_a, chips_b, dust_a, dust_b.

Arrow PNGs are 7×21 pointing up, effect PNGs 16×16. The importer retains a
fixed eighteen-color wood/cream/gold/olive palette and hard alpha. Runtime
uses nearest filtering and the existing world art scale. Spear head, shaft
and feathers are masked once by the existing rig library and remain separate
moving parts at wall contact. No generated source or sheet is sent over RPC.
# Celestial lance revision — 2026-11-05

`celestial_lance.png` is code-authored 11×41 pixel art from
`scripts/generate_celestial_lance.cjs` (explicit pixel grid, five colors,
hard alpha). Only the nine-part ultimate rig uses this new source. Original
generated master, arrow sprites and their provenance remain preserved below.
