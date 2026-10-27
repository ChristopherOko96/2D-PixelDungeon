# Raumgenerator: Daten und Spielablauf

Stand: 26.10.2026. Umsetzung von MVP-Merkmal 3 des Spielbriefs, Baufolge 4.
Der Host erzeugt vor Laufbeginn die vollständige Raumfolge und sendet die
aktuelle Geometrie im Snapshot. **Generatorversion 4 verwendet native
32×32-Pixel-Geometrie**. Der Baukasten erstellt Raumvorlagen, aus denen der
Generator zufällige Dungeons mit den vier Nutzer-Tilesets sowie passenden
Türen und einem eigenen Treppenabgang zusammensetzt.
Clients zeichnen diesen Grundriss; ihre eigenen
Zufallswerte entscheiden weder Hindernisse noch Spawns oder Raumabschluss.

## Freie Raumkonturen

Neue Vorlagen haben `layout_mode:"freeform"`. `play_bounds` umfasst dann die
ganze Zeichenfläche `[0,0,Breite,Höhe]`; es gibt keinen automatischen Boden,
keine Außenmauern und keine vier vorgegebenen Türen. Der gemalte Boden definiert
die Kontur. Nicht bemalte Zellen werden zu zusammengefassten `void_obstacles`
und blockieren Bewegung, Projektile und Wegsuche. Der Renderer zeichnet diese
Kollisionen nicht als Wände. Sichtbare Wandgrafik stammt ausschließlich vom Autor.

`painted_tiles` erlaubt je Zelle eine Ebene `floor` und eine Ebene `structure`.
`floor` ist immer begehbare Grundfläche, `structure` trägt Wand oder Dekoration
mit wählbarem `solid`. Insgesamt höchstens6144 Einträge; unbekannte IDs, doppelte
Ebenenzellen und ungültige Drehungen werden vor dem Laden abgewiesen.

`authored_doors` enthält höchstens64 Einträge `{x,y,side,tile,rotation}`:
Koordinaten in Zellen, Richtung `north/east/south/west`, freigegebene Grafik-ID
und0–3 Vierteldrehungen. Nur diese Türen sind mögliche Verbindungen. Die
Raumplanung sucht deterministisch eine Folge aus vorhandenen Gegenrichtungen;
sie erfindet keine fehlenden Öffnungen. `selected_room_order(...)` liefert eine
passende Folge für den Einzeltest mit der ausgewählten Vorlage.

Ein Boss benötigt ausdrücklich `stairs_spawn`; `stairs_art:{tile,rotation}`
bestimmt seine Grafik. Feuer und Truhe haben im freien Modus keine Standardorte.
Unfertige Entwürfe dürfen0–4 Spieler- und0–5 Gegnerstartplätze enthalten. Erst
Spielübernahme und Test verlangen4/5 freie Starts, zusammenhängenden Boden,
mindestens eine brauchbare Tür, vier freie Ankunftsplätze pro Tür und beim Boss
einen erreichbaren Abstieg. Ältere rechteckige Vorlagen behalten ihre Regeln.

## Datenformat 1

Quelle: `assets/data/dungeon_rooms.json`. Zahlen sind Pixelwerte, außer wenn
ausdrücklich Tile-Einheiten genannt werden. Koordinaten liegen innerhalb des
Raums bei **1×-Spielzoom**. Die896×480 große Editorleinwand beginnt bei `(32,156)`
und passt große Räume verkleinert ein; das Hauptspiel zeigt einen kamerageführten
Ausschnitt ab `(192,120)`. Bildschirmversätze
verändern keine Raumkoordinaten oder Kollisionen.

| Feld | Bedeutung und aktueller Wert |
| --- | --- |
| `schema_version` | Datenstrukturversion, unterstützt: `1` |
| `generator_version` | Version der Raumfolge und stabilen IDs, aktuell: `4` |
| `tile_size` | `32` Pixel pro logischem Tile |
| `world_size` | `[896,480]`: 28×15 Tiles große native Zeichenfläche |
| `play_bounds` | `[32,48,832,400]`: x, y, Breite, Höhe des begehbaren Bodens innerhalb der Außenmauern |
| `max_actor_radius` | `24` Pixel: größter aktueller Körperradius (Boss), Sicherheitsmaß für erreichbare Flächen und Spawns |
| `templates` | Mindestens drei normale Raumvorlagen und eine Bossvorlage |
| `room_order` | Optionales Kompatibilitätsfeld der Generator-API: 3–10 Raum-IDs; alle außer der letzten normal, letzte Boss. Anzahl muss zur angeforderten Raumzahl passen. Der Baukasten entfernt das Feld aus geladenen Arbeitsständen und veröffentlicht eine Bibliothek ohne feste Folge. Nur sein isolierter Raumtest setzt intern eine vorübergehende Reihenfolge. |
| `door_lanes` | Optionales Objekt: `vertical` ist die gemeinsame X-Mitte der Nord-/Südtüren, `horizontal` die Y-Mitte der West-/Osttüren, jeweils Pixel. Ohne Angabe: Mitte des begehbaren Bereichs `(448,248)`. |

Jede Vorlage hat folgende Felder:

| Feld | Format und Bedeutung |
| --- | --- |
| `id` | Eindeutige, nicht leere Kennung |
| `title` | Raumname für die Statuszeile |
| `boss` | `true` nur für Bossvorlagen |
| `accent_color` | Optionale Hex-Farbe; Renderer verwendet sonst seine violette Grundfarbe |
| `obstacles_tiles` | Liste `[x,y,w,h]` ganzzahliger Tile-Rechtecke; Multiplikation mit `32` ergibt die solide Pixelgeometrie |
| `player_spawns` | Mindestens vier freie `[x,y]`-Pixelpositionen für Host und drei Clients |
| `enemy_spawns` | Mindestens fünf freie `[x,y]`-Pixelpositionen für die derzeit höchstens fünf Gegner pro Raum |
| `theme` | Optional: `violet`, `rose`, `moss` oder `amber`. Ohne Angabe bestimmt der Seed die Palette. |
| `reward_spawn` | Optional: `[x,y]`-Pixelposition der Belohnungsdarstellung. Standard `[448,240]` nur in älteren rechteckigen Räumen; freie Räume ohne Angabe zeigen keine Truhe. |
| `brazier_spawns` | Optional: bis zu16 `[x,y]`-Pixelpositionen; `[]` entfernt Feuer. Die vier bisherigen Standardorte gelten nur für ältere rechteckige Vorlagen. |
| `stairs_spawn` | Gewünschte Treppenmitte in Pixeln im Bossraum. Im freien Modus ausdrücklich erforderlich; ältere Vorlagen dürfen automatisch einen freien Innenplatz suchen. |
| `world_size`, `play_bounds` | Eigene Raummaße in Pixeln,12–64 ×10–48 ganze32-Pixel-Tiles. Freeform: `[0,0,Breite,Höhe]`. Ältere Größenänderung: `[32,64,Breite−64,Höhe−96]`. Ohne Angaben bleiben bei alten Vorlagen Bibliothekswerte erhalten. |
| `door_lanes` | Optional pro Vorlage; überschreibt die Bibliotheksvorgabe. Bei verschiedenen Raummaßen liegen zugeordnete Türen an ihrer jeweiligen Wand; lokale Pixelmitten müssen nicht identisch sein. |
| `painted_tiles` | Optionales Array aus `{x,y,tile,rotation,solid,layer}`; Zellkoordinaten, feste Palette-ID, Drehung0–3, Kollision und `floor/structure`. Höchstens6144 Einträge, eine Zelle pro Ebene; keine Dateipfade. |
| `blank`, `reward_visible` | Optionale Editor-Präsentationsflags. Eine neue leere Vorlage zeigt keine Figuren oder Belohnungsvorschau; der normale Kampf-/Belohnungsablauf bleibt unverändert. |

Solide `painted_tiles` ergänzen die autoritativen Hindernisse; ihre Grafik ersetzt
die automatisch gezeichnete Säule an dieser Stelle. Das Layout überträgt die
gewählten Zellen und `tile_obstacles` für diese Darstellung an alle Clients.
Der Dateiimport prüft Dimensionen, IDs, Drehung, Typen und doppelte Zellen vorab.
Die vorhandene Veröffentlichungskontrolle prüft zusätzlich Erreichbarkeit,
Spawns und Tür-Ankunftsplätze. Unfertige Entwürfe bleiben separat speicherbar.

Die mitgelieferten älteren Säulen sind absichtlich nur ein bis drei Tiles breit und ein bis zwei
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
benachbarte Räume wiederholen keine Vorlage. Die räumlichen Verbindungen bestimmt
ebenfalls der Seed. Die Farben können pro Vorlage festgelegt werden.
Das Kompatibilitätsfeld `room_order` darf auf API-Ebene Vorlagen wiederholen;
es gehört nicht zum aktuellen Veröffentlichungsablauf des Baukastens.

Der [Dungeon-Baukasten](DUNGEON-EDITOR.de.md) bearbeitet diese Felder ohne
JSON-Handarbeit. Er liest auch **16×16-Dateien der Generatorversion 2 oder 3** und
migriert sie **nur im Arbeitsspeicher** auf 32×32 und Generatorversion 4. Die
geladene Originaldatei bleibt unverändert, bis der Nutzer ausdrücklich speichert
oder die Bibliothek im Spiel übernimmt. Beim Ersetzen wird vorher gesichert.
Raummaße, Radien, Spawns, optionale Ausstattung und Türspuren werden verdoppelt;
Tile-Rechtecke und Raum-IDs bleiben erhalten. Eine alte feste `room_order` wird
aus dem Editor-Arbeitsstand mit Statushinweis entfernt. Die Laufzeit selbst
erwartet Version 4 mit 32-Pixel-Tiles.
Der Dateidialog prüft Struktur und Grenzen; „Im Spiel verwenden“ prüft zusätzlich
die komplette Geometrie und alle vier möglichen Türanschlüsse jeder Vorlage.

## Raumkennung und Geometrie

Eine ID wie `v4-s24680-r02` bezeichnet Generatorversion, Seed und fortlaufenden
Raumindex. Identische Daten, Version und Seed ergeben dieselbe Folge samt
Geometrie. Änderungen am Schema erhöhen `schema_version`; Änderungen, die die
Zuordnung von Seed zu Inhalt verändern, müssen `generator_version` erhöhen und
die unterstützten Konstanten samt Tests anpassen. Das ist noch keine vollständige
Netzwerk-Kompatibilitätsprüfung zwischen unterschiedlichen Spielversionen.

Generierte Layouts enthalten `id`, `template_id`, `title`, `generator_version`,
`grid_x`, `grid_y`, `boss`, `prev_id`, `next_id`, `obstacles` (Pixel-Rechtecke),
`player_spawns`, `enemy_spawns`, `play_bounds`, `world_size`, `tile_size`, Farbe,
`theme` (`rose/moss/amber/violet`) und `exits`.
Jeder Exit enthält `id`, `kind` (`door/stairs`), `side`, `rect` in nativen
Pixeln und `target_room` (1-basiert, 0 für den Abstieg). Tür-Exits tragen zusätzlich
vier freie `entry_spawns` außerhalb des Rückkehr-Interaktionsradius. Gegenüberliegende
Türen verbinden dieselbe Spur der benachbarten Räume. Trigger sind 32×32;
die Innentreppe liegt auf freier Bodenfläche des Bossraums.
Die logischen Raumkoordinaten bilden eine zusammenhängende lineare Route mit
horizontalen oder vertikalen Schritten; die Karte zeigt nur die tatsächliche
Reihenfolge der Übergänge. Es gibt noch keine frei wählbaren Abzweigungen.

Bewegung wird auf dem Host gegen um den Körperradius vergrößerte Rechtecke
geprüft. Die feste X-/Y-Reihenfolge erlaubt Gleiten an Wänden; schnelle Schüsse
prüfen ihre gesamte Flugstrecke und stoppen vor Deckung. Gegner suchen bei
Bedarf über ein 32-Pixel-Navigationsraster einen Weg, zwischengespeichert für
0,3 Sekunden. Das Rendern verwendet exakt dieselben Hindernisrechtecke.

Der gemeinsame Ablauf ist Kampf → persönlicher Perk → alle Lebenden bereit →
freie Erkundung. Erst E an einer Tür mit der versammelten lebenden Gruppe
wechselt den Raum. Bereits gesäuberte Räume bleiben ohne neue Gegner/Perks
besuchbar. Auch nach dem Boss bleibt die Ebene offen, bis die Gruppe die
Innentreppe verwendet. Der nächste Floor bekommt einen neuen abgeleiteten
Seed; Builds und Lebenszustand bleiben erhalten. Details: [Erkundung](EXPLORATION.de.md).

## Historie: Generatorversion 2 und 3

Der Stand vom 25.10.2026 verwendete native 16-Pixel-Geometrie aus Version 2.
Generatorversion 3 ergänzte darauf die manuelle Raumgestaltung und eine optionale
feste Raumfolge. Seine Zeichenfläche war 448×240 Pixel mit 2×-Anzeige, der
begehbare Bereich `[16,24,416,200]` und der maximale Körperradius 12 Pixel.
Diese Maße gelten für ältere Entwürfe; der aktuelle Generator verwendet die oben
beschriebenen Werte der Version 4. Der Baukasten übernimmt passende Entwürfe
über die Migration beim Laden.

## Prüfen und reproduzieren

```powershell
$godot = '../tools/godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe'
& $godot --headless --path . --script res://tests/dungeon_generator_test.gd
& $godot --headless --path . --script res://tests/dungeon_integration_test.gd
& $godot --headless --path . --script res://tests/dungeon_ports_test.gd
./tests/dungeon_network_smoke.ps1 -Seed 24680
& $godot --path . -- --host --auto-start --seed 24680
```

`ROOM_LAYOUT` protokolliert pro Raum ID, Vorlage, Version und SHA256 des
serialisierten Layouts. Der Prozess-Smoke verlangt sechs gleiche Layouts über
zwei Ebenen sowie Kämpfe, Belohnungen, räumliche Übergänge und abschließende
Erkundung in zwei oder vier unabhängigen Prozessen. Seed betrifft den
Grundriss; zufällige Perkangebote und der zeitliche Kampfverlauf sind damit
nicht festgeschrieben. Ein Neustart ohne `--seed` wählt einen neuen Seed.

Lokale Funktionsnachweise und Bild: [Prüfbericht](../production/qa/verification.md).
Reales LAN/WAN, Paketverlust, Bandbreite und Vier-Spieler-Leistung bleiben offen.
