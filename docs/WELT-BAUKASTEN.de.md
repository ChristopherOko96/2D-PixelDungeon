# Welt-Baukasten (Stand 29.10.2026)

Story 1 „Krypta der Verdammten“ läuft als erste Welt auf dem Welt-Baukasten: Jede Etage wird beim
Betreten aus einer Weltnummer gebaut. Ein neuer Lauf würfelt eine neue Weltnummer, also neue
Grundrisse, Räume, Rätsel und Verstecke; Etagennamen, Bosse und Schwierigkeit bleiben fest.

## Aufbau

| Teil | Datei |
| --- | --- |
| Generator (für alle Welten) | `src/world_kit/world_core.gd`, Vorlage `tools/world_kit/world_core.js` |
| Krypta-Paket (Wortwahl, Ausstattung, Weltnummer → Etagen-Seeds) | `src/world_kit/krypta_pack.gd`, Vorlage `tools/krypta_dungeon/krypta_floors.js` |
| Krypta-Daten (Etagen, Bosse, Namen, Tabellen) | `assets/data/krypta_world.json` (aus dem JS: `node tools/krypta_dungeon/export_world.js`) |
| Krypta-Thema | `assets/data/krypta_theme.json`, Szene `src/hell/krypta_dungeon.tscn` |
| Grafiken | `assets/sprites/krypta/` (`build_krypta_skin.py`), Monster `assets/sprites/krypta/monsters/` |
| Monster und Bosse | `assets/data/krypta_monsters.json` (`node tools/krypta_dungeon/export_monsters.js`), Balance `assets/data/krypta_balance.json` |

Die Story-Laufzeit `src/hell/hell_game.gd` ist dieselbe wie für Hölle und Frostgruft: Helden,
Fähigkeiten, Heldenwahl, Esc-Menü, Spielstände, Item-System 2, Talente und das Kampfgefühl von
Story 1 sind unverändert. Ein Thema mit `world_pack` baut seine Etagen live
(`load_floor` → `world.build_raw(n, Weltnummer)`), statt gebackene Etagen zu lesen.

Die Weltnummer steht im Lauf-Zustand (`world_run`) und wird mit jedem Spielstand gespeichert
(`src/save/story_save.gd`); ein geladener Stand baut dieselbe Welt nach.

Vorschau und Spiel bauen aus derselben Weltnummer genau dieselbe Welt:
`tests/world_kit_parity_test.gd` vergleicht 20 Etagen Feld für Feld mit dem JS
(`node tools/world_kit/dump_floors.js assets/sprites/krypta/manifest.json`).
Eine Etage braucht in Godot etwa 0,5 bis 1,1 Sekunden.

## Feste Regeln jeder Etage

- Kampfräume sind mittel oder groß; kleine Räume nur für Start, Schlüsselkammer, Tresore,
  Beutekammer, Geheimräume, Treppe und Abstieg.
- Das Bosstor öffnet nur mit dem Goldschlüssel. Er liegt in der Schlüsselkammer, die jedes Mal
  gleich aussieht: Laden mit Händler und zwei Bücherregalen oben links, zwei Banner in der
  Etagenfarbe, Manabrunnen zwischen zwei Statuen oben rechts, Schlüssel auf dem großen Teppich.
  Man betritt sie immer rechts unten.
- In den Bossraum geht es immer von unten durch das Prunktor mit zwei Bannern, zwei Fackeln und
  Teppich. Banner rot auf Etage 3, 6, 9, 10, sonst eine Farbe je Etage; Etage 10 brennt blau.
- Vier bis sechs Druckplatten in fester Reihenfolge öffnen den Riesentresor (goldene Truhe) oder
  einen verborgenen Gang; mehr Platten geben mehr Belohnung. Die Reihenfolge wird nicht angezeigt.
- Kein Weg ist versperrt: Moder, Gruben, Möbel und Brunnen geben jeden Weg frei
  (`clear_ways`; Brücke über Moder, Hindernis entfernt).
- Vasen, Fässer und Kisten zerbrechen bei jedem Angriff des Helden: nichts, Runensteine, ein Herz,
  aus Kisten auch Untote.
- Mimiks zeigen sich nie als Monster: Sie stehen als Truhe im Raum (in Kampfräumen 60 %,
  Schatztruhen 15 %) und greifen erst beim Öffnen an.
- Ab Etage 2 manchmal eine Vergessene Stiege hinter einer glatten Wand. Eine einzige erloschene
  Fackel im Raum davor öffnet sie (anzünden mit E). Die Treppe führt in eine frühere Etage nach
  Wahl (Taste 1–9), mit neu gewürfelter Welt; Herzen, Steine, Level und Gegenstände bleiben.

## Noch offen

- Der Manabrunnen füllt vorerst die Fähigkeiten-Abklingzeiten auf, bis Mana in die Story-Welten kommt.
- Der Händler-Laden hat noch keine Waren; der Händler ist der 0x72-Zwerg als Platzhalter.
- Die Story-Welten haben kein LAN-Koop; die alte Krypta-Laufzeit (`src/game.gd`) bleibt für den
  Endlos-Modus.

Belege: `production/qa/evidence/krypta-welt/` (`scripts/capture_krypta_dungeon.gd`).
