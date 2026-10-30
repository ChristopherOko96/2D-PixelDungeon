# Welt-Baukasten (Stand 30.10.2026)

Story 1 „Krypta der Verdammten“, Story 2 „Die Frostgruft“ und Story 3 „Der Hell-Dungeon“ laufen auf
dem Welt-Baukasten: Jede Etage wird beim Betreten aus einer Weltnummer gebaut. Ein neuer Lauf würfelt eine neue Weltnummer, also neue
Grundrisse, Räume, Rätsel und Verstecke; Etagennamen, Bosse und Schwierigkeit bleiben fest.

## Aufbau

| Teil | Datei |
| --- | --- |
| Generator (für alle Welten) | `src/world_kit/world_core.gd`, Vorlage `tools/world_kit/world_core.js` |
| Weltpaket (Wortwahl, Ausstattung, Weltnummer → Etagen-Seeds; für jede Welt dasselbe) | `src/world_kit/world_pack.gd`, Vorlage `tools/world_kit/world_pack.js` |
| Krypta-Daten in JS | `tools/krypta_dungeon/krypta_floors.js` |
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
`tests/world_kit_parity_test.gd` vergleicht je Welt 20 Etagen Feld für Feld mit dem JS
(`node tools/world_kit/dump_floors.js assets/sprites/krypta/manifest.json` für die Krypta,
`node tools/world_kit/dump_floors.js assets/sprites/hell/manifest.json tests/data/world_kit_reference_hell.json tools/hell_dungeon/hell_world.js`
für die Hölle).
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

## Die Hölle (Story 3)

Der Hell-Dungeon behält Aussehen, Licht, Lava, Gegner, Bosse und alle Spielmechanik; nur die
Weltkarte entsteht jetzt bei jedem Lauf neu, auch Etage 1. Es gelten dieselben festen Regeln wie
in der Krypta (Schlüsselkammer, Prunktor, Druckplatten, Zerbrechliches, Mimiks, Vergessene
Stiege, kein Weg versperrt), mit Höllen-Raumgrößen: Kampfräume sind meist mittelgroß (zwei
Felder, `two`/`twoSide` = 0,8), die wenigen großen verlieren leicht ihre Ecken (`trimLarge` 2).

| Teil | Datei |
| --- | --- |
| Höllen-Daten (Etagen, Bosse, Namen, Tabellen) | `tools/hell_dungeon/hell_world.js` → `assets/data/hell_world.json` (`node tools/hell_dungeon/export_world.js`) |
| Thema | `assets/data/hell_theme.json` (`world_pack`; `world_sizes`: HD-Maße, damit Pixel- und HD-Satz dieselbe Etage bauen) |
| Fehlende Grafiken (Brunnen, Laden, Wasserspeier, Prunktor, Banner je Etagenfarbe, Fässer, Urnen, Kisten, Teppiche, Treppe, erloschene Fackel, blaues Feuer, Asche) | `tools/hell_dungeon/build_hell_extras.py`: aus den Krypta-Gegenstücken in Höllenstein und verkohltem Holz, für `assets/sprites/hell` und den Pixel-Satz `assets/sprites/hell_0x72` (Höllen-Palette aus `scripts/make_hell_skin.gd`) |
| Mimik | die Krypta-Mimik in Höllenholz, geliehen über `assets/data/hell_balance.json` → `monsters.borrow`; sie steht in keiner Etagen-Mischung |
| Vorschau | `py -3 -I tools/hell_dungeon/build_world_preview.py <out.html>` |

Regeln prüfen: `node tools/krypta_dungeon/check_runs.js assets/sprites/hell/manifest.json 200 1 tools/hell_dungeon/hell_world.js`.
Die gebackenen Etagen `assets/data/hell_floors.json` liest die Hölle nicht mehr; sie bleiben für
ihre Tests und Werkzeuge liegen.

Belege: `production/qa/evidence/hell-welt/` (Pixel) und `hell-welt/hd/`
(`scripts/capture_krypta_dungeon.gd -- <dir> <class> res://src/hell/hell_dungeon.tscn [pixel|hd]`).

## Die Frostgruft (Story 2)

Die Frostgruft behält Etagen, Bosse, Gefahren, Gegner (ihre eigene Kampfebene), Helden, Items,
Talente und Oberfläche; nur die Weltkarte entsteht jetzt bei jedem Lauf neu. Es gelten die festen
Regeln der Welten mit den Raumgrößen des Baukastens (Kampfräume mittel oder groß). Mimiks gibt es
hier nicht (die Frostgruft hat keinen). Der Bossschlüssel liegt offen in der Schlüsselkammer wie in
Krypta und Hölle; Schlüssel in Truhen (`key_in_chest`) sind abgeschaltet.

| Teil | Datei |
| --- | --- |
| Frost-Daten | `tools/frost_dungeon/frost_world.js` → `assets/data/frost_world.json` (`node tools/frost_dungeon/export_world.js`) |
| Thema | `assets/data/frost_theme.json` (`world_pack`, `world_sizes` = HD-Maße, `skins` für Pixel und HD) |
| Grafik Pixel | `assets/sprites/frost` (0x72-Eis-Satz) plus die Baukasten-Teile, eingefroren aus `assets/sprites/hell_0x72` |
| Grafik HD | `assets/sprites/frost_hd`: der HD-Höllensatz eingefroren (Stein blaugrau, Glut wird Eislicht, Lava wird Glatteis; rote Banner und Teppiche, Gold, Herzen, Mana und Etagenfarben bleiben). Gegner, Schlüssel und Begleiter aus dem Pixel-Satz. Beides baut `py -3 -I tools/frost_dungeon/build_frost_extras.py` |
| Vorschau | `py -3 -I tools/frost_dungeon/build_world_preview.py <out.html>` (Gegner dort Platzhalter aus der Krypta) |

### Winter (Aussehen der Frostgruft)

- **Nebel statt Dunkelheit:** hell, bläulich-weiß, mit treibenden Schwaden; Licht lichtet ihn in feinen
  Stufen auf (Thema `fog`, `src/hero/story_glow.gd`, `assets/shaders/canvas_vfx_darkness.gdshader`).
- **Leichter Schneesturm** über dem ganzen Bild, auch über HUD und Menüs, mit Böen (Thema `snowstorm`,
  `src/vfx/snowstorm.gd`).
- **Schnee in der Welt** (Weltpaket `winter`, JS und GDScript gleich): Schneefelder auf etwa der Hälfte
  des Bodens, um Feuer und Licht geschmolzen; Knochen und Steinhaufen stark ausgedünnt, keine
  Ascheflecken; Schneemänner und Eisgletscher in manchen Kampfräumen (die Wegeprüfung hält alles frei).
- **Schneekappen** auf Mauern, Säulen, Steinen, Schädeln, Statuen, Möbeln, Toren und Truhen in beiden
  Grafik-Sätzen; Feuer, Fackeln und Schalen bleiben frei (`build_frost_extras.py`, Pixel-Originale in
  `tools/frost_dungeon/pixel_base`).
- **Fußspuren** von Held und Monstern im Schnee, die nach einigen Sekunden verblassen; auf Glatteis
  rutscht der Held, statt zu laufen: Beine still, Neigung in Rutschrichtung, Kratzspuren und
  Eissplitter (Thema `snow`, `src/hero/frost_snow.gd`).
- **Eisfalle** statt Stacheln: ein Spalt im Eis, aus dem beim Auslösen eine Eislawine schießt.

Belege: `production/qa/evidence/frost-welt/winter-hd/` und `winter-pixel/`
(`scripts/capture_frost_winter.gd -- <dir> [pixel|hd]`).

Pixel und HD schaltet das Esc-Menü um, wie in der Hölle. Belege: `production/qa/evidence/frost-welt/`
(Pixel) und `frost-welt/hd/`.

## Noch offen

- Der Manabrunnen füllt vorerst die Fähigkeiten-Abklingzeiten auf, bis Mana in die Story-Welten kommt.
- Der Händler-Laden hat noch keine Waren; der Händler ist der 0x72-Zwerg als Platzhalter.
- Die Story-Welten haben kein LAN-Koop; die alte Krypta-Laufzeit (`src/game.gd`) bleibt für den
  Endlos-Modus.

Belege: `production/qa/evidence/krypta-welt/` (`scripts/capture_krypta_dungeon.gd`).
