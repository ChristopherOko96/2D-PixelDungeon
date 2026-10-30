# Frostgruft-Werkzeuge (Story 2)

Die Frostgruft nutzt den Generator und die Laufzeit des Hell-Dungeons (`tools/hell_dungeon`, `src/hell`)
mit eigenen Etagenwerten, Texten und einem Eis-Skin.

| Datei | Zweck |
| --- | --- |
| `build_frost_skin.py` | Baut `assets/sprites/frost/` aus dem 0x72-Archiv: jeder Hell-Sprite-Name als Eis-Variante, dazu Monster, Boss-Phasen und Schlüssel. `py -3 -I tools/frost_dungeon/build_frost_skin.py "<entpacktes Archiv>/Sprite Sheet 0x72" assets/sprites/frost` |
| `bake_frost_floors.js` | Schreibt `assets/data/frost_floors.json` (gleiches Schema wie `hell_floors.json`). `node tools/frost_dungeon/bake_frost_floors.js` |
| `preview_floor.py` | Übersichtsbild einer Etage mit dem Skin. `py -3 -I tools/frost_dungeon/preview_floor.py 1 out.png 0.33` |

## Auf dem Welt-Baukasten (die Etagen des Spiels)

Das Spiel liest die gebackenen Etagen nicht mehr: Jede Etage entsteht beim Betreten aus der
Weltnummer (`docs/WELT-BAUKASTEN.de.md`). `bake_frost_floors.js` und `frost_floors.json` bleiben für
ihre Tests.

| Datei | Zweck |
| --- | --- |
| `frost_world.js` | Die Frostgruft als Weltpaket: zehn Etagen, Namen, Wortwahl, Bannerfarben, Ausstattung, keine Mimiks. |
| `export_world.js` | `node tools/frost_dungeon/export_world.js` schreibt `assets/data/frost_world.json`. |
| `build_frost_extras.py` | Baut den HD-Satz `assets/sprites/frost_hd` (HD-Hölle eingefroren, Gegner aus dem Pixel-Satz) und ergänzt im Pixel-Satz die Baukasten-Teile. `py -3 -I tools/frost_dungeon/build_frost_extras.py` |
| `snow_hd.py` | Der Schnee des HD-Satzes aus den Zeichnungen des Nutzers (`snow_hd_src/`: Frost_mit_Schnee.zip und `sheet_missing_snow.png`): freistellen, zuschneiden, in die alte Leinwandgröße einpassen; Nord-/Südmauer als gespiegelte, nahtlose ZIP-Kachel, `wall_h_bare` = erste Mauer für Mauerzellen ohne Schneekontakt. Läuft am Ende von `build_frost_extras.py` mit. `py -3 -I tools/frost_dungeon/snow_hd.py [name …]` |
| `build_world_preview.py` | Spielbare Vorschau der generierten Frostgruft. `py -3 -I tools/frost_dungeon/build_world_preview.py <out.html>` |

Reihenfolge nach Änderungen: Skin bauen, Etagen backen (die Größen kommen aus dem Skin-Manifest),
dann `tests/frost_floor_data_test.gd` laufen lassen. Herkunft und Lizenz: `assets/sprites/frost/LICENSE-NOTE.md`.
