# Frostgruft-Werkzeuge (Story 2)

Die Frostgruft nutzt den Generator und die Laufzeit des Hell-Dungeons (`tools/hell_dungeon`, `src/hell`)
mit eigenen Etagenwerten, Texten und einem Eis-Skin.

| Datei | Zweck |
| --- | --- |
| `build_frost_skin.py` | Baut `assets/sprites/frost/` aus dem 0x72-Archiv: jeder Hell-Sprite-Name als Eis-Variante, dazu Monster, Boss-Phasen und Schlüssel. `py -3 -I tools/frost_dungeon/build_frost_skin.py "<entpacktes Archiv>/Sprite Sheet 0x72" assets/sprites/frost` |
| `bake_frost_floors.js` | Schreibt `assets/data/frost_floors.json` (gleiches Schema wie `hell_floors.json`). `node tools/frost_dungeon/bake_frost_floors.js` |
| `preview_floor.py` | Übersichtsbild einer Etage mit dem Skin. `py -3 -I tools/frost_dungeon/preview_floor.py 1 out.png 0.33` |

Reihenfolge nach Änderungen: Skin bauen, Etagen backen (die Größen kommen aus dem Skin-Manifest),
dann `tests/frost_floor_data_test.gd` laufen lassen. Herkunft und Lizenz: `assets/sprites/frost/LICENSE-NOTE.md`.
