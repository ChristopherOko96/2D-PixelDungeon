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
| `krypta_monsters.js` | Acht Gegner und zehn Bosse für die Vorschau-Laufzeit (gleiche Schnittstelle wie `hell_monsters.js`). |
| `krypta_template.html` | Die Vorschauseite. Wird direkt bearbeitet (Schlüsselkammer, Prunktor, Druckplatten, Mana). |
| `make_template.py` | Hat `krypta_template.html` einmal aus der Hell-Vorlage abgeleitet. Nicht mehr ausführen: es würde die Änderungen danach überschreiben. |
| `build_preview.py` | Setzt Skin, Welt-Kern, Etagen, Figuren und Monster zu einer HTML-Datei zusammen. `py -3 -I tools/krypta_dungeon/build_preview.py <skin_dir> <out.html>` |
| `export_world.js` | Schreibt die Krypta-Daten für Godot nach `assets/data/krypta_world.json`. `node tools/krypta_dungeon/export_world.js` |
| `export_monsters.js` | Schreibt Monster und Bosse für Godot (`assets/data/krypta_monsters.json`, Bilder in `assets/sprites/krypta/monsters/`). `node tools/krypta_dungeon/export_monsters.js` |
| `check_runs.js` | Prüft viele zufällige Läufe gegen die Dungeon- und Baukasten-Regeln. `node tools/krypta_dungeon/check_runs.js <skin_dir>/manifest.json 200 [erste Nummer] [Paketmodul]`; die Hölle: `... assets/sprites/hell/manifest.json 200 1 tools/hell_dungeon/hell_world.js` |

Reihenfolge nach Änderungen: Skin bauen (für Godot nach `assets/sprites/krypta`), `build_preview.py`, `check_runs.js`; für Godot zusätzlich `export_world.js`, bei Monstern `export_monsters.js`, und nach Generator-Änderungen `tools/world_kit/dump_floors.js` plus `tests/world_kit_parity_test.gd`. Überblick: `docs/WELT-BAUKASTEN.de.md`.
