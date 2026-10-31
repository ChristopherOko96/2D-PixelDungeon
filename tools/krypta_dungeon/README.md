# Krypta-Werkzeuge (Story 1, Neubau)

Die Krypta läuft auf dem Welt-Baukasten (`tools/world_kit/world_core.js`, Regeln dort im README),
mit eigenen Etagenwerten, Texten, dem Krypta-Asset-Set als Skin und den Gegnern der bisherigen
Krypta. Jeder Lauf würfelt eine Weltnummer; aus ihr leiten sich die zehn Etagen ab
(`KryptaFloors.forRun`).

| Datei | Zweck |
| --- | --- |
| `build_krypta_skin.py` | Baut den Skin aus dem entpackten Set: jeder Sprite-Name bekommt ein Krypta-Motiv, dazu Brunnen, Prunktor, Bossbanner und Teppich. Brücken und Wandecken werden aus der langen Mauer (B030) zusammengesetzt. `py -3 -I tools/krypta_dungeon/build_krypta_skin.py "<entpackt>/Krypta_Asset_Set" <skin_dir>` |
| `krypta_floors.js` | Das Krypta-Paket als Daten: zehn Etagen (Titel, Boss, Werte), Wortwahl, Ausstattungstabellen. Die Funktionen (Weltnummer pro Lauf, gerade Brücken, Ausstattung) kommen aus `tools/world_kit/world_pack.js`. |
| `make_pix.py` | Packt die 0x72-Figuren und den Leerenrufer nach `krypta_pix.js`. `py -3 -I tools/krypta_dungeon/make_pix.py tools/krypta_dungeon/krypta_pix.js` |
| `krypta_monsters.js` | Acht Gegner und zehn Bosse für die Vorschau-Laufzeit (gleiche Schnittstelle wie `hell_monsters.js`). Feld `rig`: das Krypta-Teile-Rig (`assets/data/rigs.json`), mit dem das Spiel die Figur zeichnet, in ihrer Größe (ein Quellpixel = `scale` Weltpixel); Treffer, abgetrennte Teile und Leiche folgen dem Rig (`src/hell/drake_rig_host.gd` `adopt_looks`). Feld `shot`: ihr Element (bone, poison, frost, gold, soul, void); Geschosse, Atem, Stampfer, Warnkreise und Rückstände zeigen es (`src/hell/hell_monsters.gd` `own_element`). Feld `material` (bone, flesh, void): wie abgetrennte Teile splittern und wie die Figur bei Treffer und Tod klingt. Feld `pool`: Wurfgeschosse und Stampfer hinterlassen eine schadende Lache ihres Elements (wie die Lava der Hölle). Der Exporter schreibt dazu `glow`: die leuchtenden Pixel des Generators (`P.glow`: Augen, Glut, Funkeln) als Leuchtpunkte für das Spiel (`src/hero/story_glow.gd`). |
| `krypta_template.html` | Die Vorschauseite. Wird direkt bearbeitet (Schlüsselkammer, Prunktor, Druckplatten, Mana). |
| `make_template.py` | Hat `krypta_template.html` einmal aus der Hell-Vorlage abgeleitet. Nicht mehr ausführen: es würde die Änderungen danach überschreiben. |
| `build_preview.py` | Setzt Skin, Welt-Kern, Etagen, Figuren und Monster zu einer HTML-Datei zusammen. `py -3 -I tools/krypta_dungeon/build_preview.py <skin_dir> <out.html>` |
| `export_world.js` | Schreibt die Krypta-Daten für Godot nach `assets/data/krypta_world.json`. `node tools/krypta_dungeon/export_world.js` |
| `export_monsters.js` | Schreibt Monster und Bosse für Godot (`assets/data/krypta_monsters.json`, Bilder in `assets/sprites/krypta/monsters/`). Misst dabei die sichtbare Figur (Stehen und Laufen) und schreibt ihre Mitte als `hit_cy` (Kunstpixel über den Füßen): Dort sitzt im Spiel der Trefferkreis `stats.r` (`src/hell/hell_monsters.gd` `hit_cy`). Ein Boss soll seinen Kreis ungefähr ausfüllen (Breite etwa 2 r); sonst `scale` anpassen. `node tools/krypta_dungeon/export_monsters.js` |
| `check_runs.js` | Prüft viele zufällige Läufe gegen die Dungeon- und Baukasten-Regeln. `node tools/krypta_dungeon/check_runs.js <skin_dir>/manifest.json 200 [erste Nummer] [Paketmodul]`; die Hölle: `... assets/sprites/hell/manifest.json 200 1 tools/hell_dungeon/hell_world.js` |

Reihenfolge nach Änderungen: Skin bauen (für Godot nach `assets/sprites/krypta`), `build_preview.py`, `check_runs.js`; für Godot zusätzlich `export_world.js`, bei Monstern `export_monsters.js`, und nach Generator-Änderungen `tools/world_kit/dump_floors.js` plus `tests/world_kit_parity_test.gd`. Überblick: `docs/WELT-BAUKASTEN.de.md`.

## Pixel-Skin (`build_krypta_pixel_skin.gd`)

`godot --headless --path . -s res://tools/krypta_dungeon/build_krypta_pixel_skin.gd` baut
`assets/sprites/krypta_pixel/`: für jeden Namen des HD-Sets (`assets/sprites/krypta/manifest.json`)
ein PNG gleichen Namens und gleicher Pixelgröße, zusammengesetzt aus den 16-px-Quellen der alten
Krypta (`assets/sprites/0x72`, `crypt_props`, `decor`, `0x72_extended`), 1 Quellpixel = 3 Weltpixel
(nearest neighbour, wie `hero_scale` 3). Das Manifest trägt die HD-Größen; `krypta_theme.json` nennt
beide Sets unter `skins` (PIXEL/HD-Umschalter im Pausenmenü und in den Optionen) und `world_sizes` =
HD-Manifest, damit beide Sets dieselbe Etage bauen. Monster sind Rigs, nicht im Skin. Danach einmal
`godot --headless --path . --import`.

| HD-Name | Pixel-Quelle |
| --- | --- |
| `floor_00..11` | 2x2 aus 0x72 `floor_1..8`, `decor/floor_dark_*`, `floor_moss`, `floor_crack_3` |
| `lava_*` (Moder) | gezeichnet: kachelbarer Giftmoder; Rand: 0x72-Ziegellippe mit Schleimlinie |
| `wall_h` | 0x72 `wall_top_mid` + `wall_mid`; `wall_v`, `wall_top`, `corner_cap`: gezeichnet (dunkle Mauerkrone, Kantenstreifen) |
| `wall_post_slit`, `jamb_*`, `rune_pillar_a-c`, `skull_obelisk`, `moss_ruin` | 0x72 `column` / `column_wall` |
| `torch_*`, `wall_torch_*`, `wall_v_glow*`, `boss_gate*` | `crypt_props/wall_torch_f*`, `0x72_extended/wall_torch_anim_f2`; `*_blue` blaue Flamme, `torch_dead` ohne Flamme |
| `torch_pillar*`, `candelabra`, `rune_pillar_d` | `crypt_props/candle_column_f0` |
| `brazier_*`, `bowl_blue`, `wall_brazier`, `hanging_brazier` | gezeichnete Steinschale + `decor/fire_f*` als Seelenflamme (grün, blau) |
| `chest_*`, `icon_chest` | 0x72 `chest_full_open_anim_f0/f2`, `chest_empty_open_anim_f2` (Tresor x4) |
| `portal*`, `stairs_down`, `door_stairs*`, `gate_side`, `portcullis`, `boss_arch`, `demon_lintel` | 0x72 `doors_leaf_open/closed`, `doors_frame_*`, `floor_stairs` |
| `fountain` | 0x72 `wall_fountain_top_1` + `mid_blue` + `basin_blue` |
| `statue_angel`, `statue_monk`, `gargoyle` | 0x72 `angel`, `necromancer`, `big_demon` zu Stein gefärbt, auf Sockel |
| `crate_*`, `shelf`, `shop_table` | 0x72 `crate`, `decor/cabinet`, 0x72 `flask_*` |
| `rug_*`, `carpet`, `mat` | `decor/rug_red` / `rug_beige`, nine-sliced (blau: Rot zu Blau) |
| `moss_*`, `moss_rubble_*` | grüne Pixel aus `decor/floor_moss` |
| `heart`, `rune_plate`, `icon_scroll`, `icon_door` | 0x72 `ui_heart_full`, `button_blue_up`, `decor/sign_1`, `doors_leaf_closed` |
| `banner_*`, `boss_banner_*`, `urn_*`, `barrel_*`, `sacks_*`, `table_*`, `bench`, `altar`, `bone_*`, `skull_*`, `chain_*`, `cage_*`, `shackle_*`, `spire*`, `rocks_*`, `boulders`, `rubble`, `coal*`, `rune_*`, `*_plate`, `pit`, `grate*`, `vent`, `spike_*`, `blood_*`, `bridge_*`, `obelisk`, `key`, `rune_gem`, `fire_orb`, `icon_demon*`, `icon_swords` | im 0x72-Stil gezeichnet, Farben der Packs |
| `npc_idle_f0-3` | unverändert (schon 0x72 `dwarf_m`) |

Kein HD-Sprite musste übernommen werden; zu große Stücke werden am Rand beschnitten (der Lauf meldet sie).
