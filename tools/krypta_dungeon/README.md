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
