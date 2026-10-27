# Raumgenerator: Daten und Spielablauf

Stand: 25.10.2026. Umsetzung von MVP-Merkmal 3 des Spielbriefs, Baufolge 4.
Der Host erzeugt vor Laufbeginn die vollständige Raumfolge und sendet die
aktuelle Geometrie im Snapshot. Clients zeichnen diesen Grundriss; ihre eigenen
Zufallswerte entscheiden weder Hindernisse noch Spawns oder Raumabschluss.

## Datenformat 1

Quelle: `assets/data/dungeon_rooms.json`. Zahlen sind Pixelwerte, außer wenn
ausdrücklich Tile-Einheiten genannt werden. Koordinaten liegen innerhalb des
Raums, ohne den HUD-Versatz `(32,156)`.

| Feld | Bedeutung und aktueller Wert |
| --- | --- |
| `schema_version` | Datenstrukturversion, unterstützt: `1` |
| `generator_version` | Version der Raumfolge und stabilen IDs, unterstützt: `3` (seit 27.10.2026: Raumformen über `cutouts_tiles`) |
| `tile_size` | `32` Pixel pro Tile, passend zu den 32×32-Quellsprites |
| `world_size` | `[896,480]`: 28×15 Tiles große Zeichenfläche |
| `play_bounds` | `[32,48,832,400]`: x, y, Breite, Höhe des begehbaren Bodens innerhalb der Außenmauern |
| `max_actor_radius` | `24` Pixel: größter aktueller Körperradius (Boss), Sicherheitsmaß für erreichbare Flächen und Spawns |
| `templates` | Mindestens drei normale Raumvorlagen und eine Bossvorlage |

Jede Vorlage hat folgende Felder:

| Feld | Format und Bedeutung |
| --- | --- |
| `id` | Eindeutige, nicht leere Kennung |
| `title` | Raumname für die Statuszeile |
| `boss` | `true` nur für Bossvorlagen |
| `accent_color` | Optionale Hex-Farbe; Renderer verwendet sonst seine violette Grundfarbe |
| `obstacles_tiles` | Liste `[x,y,w,h]` ganzzahliger Tile-Rechtecke; Multiplikation mit `32` ergibt die solide Pixelgeometrie |
| `cutouts_tiles` | Optional, Standard leer. Liste `[x,y,w,h]` ganzzahliger Tile-Rechtecke, die den Raum formen (Kreuz, Treppe, Gang). Sie dürfen in die Außenmauern ragen, werden auf die Zeichenfläche beschnitten, kollidieren wie Deckung und erscheinen im Layout zusätzlich unter `cutouts`. Alle vier Türen und die Raummitte müssen frei bleiben. |
| `player_spawns` | Mindestens vier freie `[x,y]`-Pixelpositionen für Host und drei Clients |
| `enemy_spawns` | Mindestens fünf freie `[x,y]`-Pixelpositionen für die derzeit höchstens fünf Gegner pro Raum |

Die Säulen sind absichtlich nur ein bis drei Tiles breit und ein bis zwei
Tiles hoch. Freie Umlaufwege bleiben auch bei Bossradius 24 verbunden.
Spielerspawns liegen links bei x=150/202/254/306, Gegner rechts bei x=640–800;
das trennt die Gruppen zum Raumstart. Die Bossarena bleibt offen.
Anzahl, Werte und Radien der Gegner stehen weiterhin in `src/data/balance.json`.
Mehr Gegner als Spawnplätze sind kein unterstütztes Inhaltsupdate.

Ungültige Versionen, Typen, Maße, blockierte Spawns und getrennte Bodenflächen
werden vor Laufbeginn abgelehnt. Der Generator verwendet einen eigenen
Zufallszahlengenerator. Eine Folge umfasst allgemein 3–10 Räume; der aktuelle
Spielablauf erzeugt genau **drei** anhand der drei Einträge in `rooms.enemy_counts`.
Nur der letzte Raum ist ein Boss. Die normalen Vorlagen werden gemischt;
benachbarte Räume wiederholen keine Vorlage.

## Raumkennung und Geometrie

Eine ID wie `v1-s24680-r02` bezeichnet Generatorversion, Seed und fortlaufenden
Raumindex. Identische Daten, Version und Seed ergeben dieselbe Folge samt
Geometrie. Änderungen am Schema erhöhen `schema_version`; Änderungen, die die
Zuordnung von Seed zu Inhalt verändern, müssen `generator_version` erhöhen und
die unterstützten Konstanten samt Tests anpassen. Das ist noch keine vollständige
Netzwerk-Kompatibilitätsprüfung zwischen unterschiedlichen Spielversionen.

Generierte Layouts enthalten `id`, `template_id`, `title`, `generator_version`,
`grid_x`, `grid_y`, `boss`, `prev_id`, `next_id`, `obstacles` (Pixel-Rechtecke),
`player_spawns`, `enemy_spawns`, `play_bounds`, `world_size`, `tile_size` und Farbe.
Die logischen Raumkoordinaten bilden eine zusammenhängende lineare Route mit
horizontalen oder vertikalen Schritten; die Karte zeigt nur die tatsächliche
Reihenfolge der Übergänge. Es gibt noch keine frei wählbaren Abzweigungen.

Bewegung wird auf dem Host gegen um den Körperradius vergrößerte Rechtecke
geprüft. Die feste X-/Y-Reihenfolge erlaubt Gleiten an Wänden; schnelle Schüsse
prüfen ihre gesamte Flugstrecke und stoppen vor Deckung. Gegner suchen bei
Bedarf über ein 32-Pixel-Navigationsraster einen Weg, zwischengespeichert für
0,3 Sekunden. Das Rendern verwendet exakt dieselben Hindernisrechtecke.

Der gemeinsame Übergang bleibt Kampf → persönlicher Perk → alle Lebenden
bereit → nächster Raum. Die gezeichnete Tür ist dekorativ. Ein berührtes Tor
ersetzt das Ready-Gate nicht. Nach der Bossbelohnung folgt der Sieg.

## Prüfen und reproduzieren

```powershell
$godot = '../tools/godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe'
& $godot --headless --path . --script res://tests/dungeon_generator_test.gd
& $godot --headless --path . --script res://tests/dungeon_integration_test.gd
./tests/dungeon_network_smoke.ps1 -Seed 24680
& $godot --path . -- --host --auto-start --seed 24680
```

`ROOM_LAYOUT` protokolliert pro Raum ID, Vorlage, Version und SHA256 des
serialisierten Layouts. Der Prozess-Smoke verlangt drei gleiche Layouts sowie
Kampf, Belohnung und Sieg in zwei unabhängigen Prozessen. Seed betrifft den
Grundriss; zufällige Perkangebote und der zeitliche Kampfverlauf sind damit
nicht festgeschrieben. Ein Neustart ohne `--seed` wählt einen neuen Seed.

Lokale Funktionsnachweise und Bild: [Prüfbericht](../production/qa/verification.md).
Reales LAN/WAN, Paketverlust, Bandbreite und Vier-Spieler-Leistung bleiben offen.
