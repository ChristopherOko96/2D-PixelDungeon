# Crypt of the Damned — aktueller Prototyp zur manuellen Abnahme

## Aktuell: erste ruhige Pixelböden, klare Mauerkanten, keine Dekoration

Die letzte Nutzerkorrektur vom 26.10.2026 bestimmt die Grafik des ersten
Godot-Prototyps 44c9b80: den originalen 32px-Schieferboden, ruhige erhöhte Mauern
und orange Fackeln. Sowohl das graue generierte Materialexperiment als auch die
anschließende gesättigte Original-Pack-Darstellung sind abgelöst.

Die zehn aktiven Krypta-Karten nutzen `render_style=classic_quiet` und
`decoration_enabled=false`. Möbel, Pflanzen, Grabobjekte, Truhen,
Belohnungssockel und Nebel/Hintergrundpartikel werden derzeit nicht dargestellt.
Gameplay-Türen, Treppe, Feuer, Figuren und die automatische Kartenauswahl bleiben.
Künftige Dekoration soll demselben ruhigen Pixelstil entsprechen.

Zehn Karten, eigenständige Grundrisse, geschlossene Wandkonturen, Kollision und
Boss ausschließlich in Raum10 bleiben erhalten. Der persönliche Quellentwurf
bleibt unverändert; ausgewählte Räume lassen sich weiter direkt im Editor
spielen. Die ursprünglichen Grafikquellen werden nicht überschrieben.

Boden und Wandzeilen werden einmal pro Raumänderung vorbereitet, Wände weiterhin
mit Figuren nach Tiefe sortiert. Kollisions-/Navigationsdaten und unveränderte
Raumgeometrie in Netzwerk-Snapshots werden zwischengespeichert. Ein isoliertes
CPU-Profil derselben Gartenansicht senkte die mediane Zeichenzeit von 15,343 ms
auf 0,353 ms. Die genauen Bedingungen und Navigationswerte stehen in der
verlinkten Umsetzung. Eine zusätzliche sichtbare Solo-Gartenszene mit sechs
Gegnern erreichte auf derRX6600 über sechs Sekunden144FPS (Bildzeit p95=8,29ms).
Vier-Spieler-Leistung und die manuelle visuelle und spielerische Abnahme bleiben offen.
[Umsetzung und Stilreferenz](ORIGINAL-TILE-RESTORE.de.md),
[Story017](../production/epics/dungeon-rooms/story-017-quiet-classic-performance.md).

Die folgenden Grafikstände und ihre Bilder dokumentieren den Verlauf. Aussagen
über neue Steintiles, aktive Pack-Requisiten oder Nebel sind historisch.

## Historisch: Original-Tiles wieder aktiv

Die anschließend verworfene graue Stein-Neugestaltung ist deaktiviert.
Alle zehn Karten verwenden wieder die gelieferten Original-Paletten mit
originalen Pack-Requisiten und warmen Fackeln aus dem ersten Godot-Prototyp.
Boss10 und alle Spiel-/Editorfunktionen bleiben erhalten.
[Details und historische Ansichten](ORIGINAL-TILE-RESTORE.de.md).
Die älteren Abschnitte über aktive neue Steintiles sind damit historisch.


## Im normalen Prototyp integriert

Auf ausdrücklichen Nutzerauftrag vom26.10.2026 ist die Zehnerbibliothek jetzt die
aktive `assets/data/dungeon_rooms.json`. **F5**, `./scripts/Dev.ps1 Run` und
`Crypt-of-the-Damned.cmd` laden sie ohne besonderen Kandidatenparameter.
Die frühere Kandidatenbegrenzung weiter unten ist damit historisch überholt.
Der persönliche Originalentwurf bleibt unangetastet; die alte aktive Bibliothek
wurde vor dem Ersetzen unter `user://dungeon_editor/backups/` gesichert.

Raum1 ist die Vorhalle, Räume2–9 werden ohne Wiederholung gemischt, Raum10 ist
immer die Bosskammer. Dort bedeutet `encounter.boss_enemies=3`: **ein Boss plus
zwei normale Begleitgegner**. Erst nach allen zehn gesäuberten Räumen öffnet der
Bossabstieg die nächste Ebene. Belohnungskarten und freie Erkundung bleiben erhalten.

[Historische Spielaufnahmen des Materialexperiments](../production/qa/evidence/current-prototype/README.md)
entstanden aus dem normalen Spiel mit Seed42026. Garten und Boss wurden für die
Fotos direkt aufgerufen. Das ist kein Nachweis eines vollständig gespielten Laufs.


## Frühere Revision: Raum direkt spielen, neue Steintiles, feste Sockel

`Crypt-Editor.cmd` lädt die aktuelle Kandidatenbibliothek. Im Dropdown einen Raum
wählen und rechts **AUSGEWÄHLTEN RAUM SPIELEN** drücken. Dabei wird genau dieser
Bearbeitungsstand verwendet, auch ungespeichert und ohne3-Raum-Validierung.
Fehlende sichere Starts existieren nur in einer temporären Kopie. Der Rückknopf
oben bringt denselben Entwurf zurück. Die komplette Bibliotheksprüfung bleibt
für eine ausdrückliche Übernahme separat erhalten.

Der Garten erhält Blumen, Efeu, Pilze, Wurzeln, Falter und einen Brunnen in
geordneten Beeten. Archiv, Kapelle, Ossarium und Grabkammern haben eigene Paletten
und Platzierungsregeln im `crypt_decoration_catalog.json`. IDs und Parameter
sind dort Daten: layout, focal, primary/secondary/accent, safety_radius112px,
spacing_cells2, aisle_half_width1 und maximal2–4Gruppen/14–18Objekte pro Kammer.
`room_theme`, `decoration_summary` und `crypt_dressing` markieren das Ergebnis.
Neue Deko ist standardmäßig nicht blockierend und schützt zentrale Laufachsen.

Auf Nutzerkorrektur ersetzt ein neues Materialset die Oberflächen aller vier
Dungeon-Tilesets im Editor und Spiel. Die224ursprünglichen Zellkonturen und ihre
Kollision bleiben unverändert. Originalquellen bleiben erhalten. Herkunft und
Materialrollen: [Unified stone](../assets/crypt/unified/README.md).

Die16Umgebungsanimationen haben64Frames. Der Renderer hält jeden Grundkörper
auf Frame0 fest und animiert ausschließlich Effektmasken: Wasser im Becken,
Flammen über der Schale, Licht, Blätter, Seiten und Tropfen. Stein, Töpfe, Wachs,
Metall und Buchständer bleiben stehen. Details/Prompts:
[Animierte Umgebung](../assets/crypt/living/README.md).

Die Bildübersichten sind reine Gestaltungsansichten. Gameplay und visuelle
Abnahme wurden weiterhin dem Nutzer überlassen; keine automatischen Tests.


Stand:26.10.2026. Diese Fassung ist ein separater Kandidat. Der eigene Entwurf
`assets/data/custom_dungeons/dungeon_mein_entwurf.json` und die aktive Bibliothek
`assets/data/dungeon_rooms.json` werden durch die Erstellung nicht ersetzt.

`Crypt-of-the-Damned.cmd` öffnet das Spiel mit der Kandidatenbibliothek. Danach
**Solo** wählen oder dort eine Sitzung hosten. `Crypt-Editor.cmd` öffnet die zehn
gespeicherten Gestaltungsbeispiele zum Ansehen und Bearbeiten. Die Beispiele sind
Momentaufnahmen; der prozedurale Spielstart verwendet einen neuen Seed.

## Verbindliche Gestaltung

Maßstab ist die Wandlogik des selbst gebauten Raums `room_001`, nicht dessen
Grundriss. Die zwei zuerst gezeigten Entwurfsreihen wurden verworfen. Insbesondere
werden weder ganze Raumkopien noch aus dem unvollständigen rechten Erweiterungsteil
abgeleitete Nachbarschaftsregeln weiterverwendet.

Der Generator baut zehn unabhängige Raumgraphen: Vorhalle, Knochengalerien,
Sarkophaghof, Kapelle, Katakomben, Graburnengarten, Reliquienarchiv, Grab der
Namenlosen, Trauerhallen und Bosskrypta. Die Zeichenflächen haben64×44Felder,
entsprechend2048×1408Pixeln. Kammerlängen, Gangknicke, Einrichtung und Gegner
variieren mit dem Seed; Grundrissfamilien bleiben erkennbar. Zufall garantiert
keine unbegrenzte Zahl einzigartiger Karten. Die Vorhalle startet, acht normale
Vorlagen werden gemischt, der Boss schließt die Zehnerfolge ab.

## Wandaufbau

`src/dungeon/crypt_generator.gd` führt die Schritte getrennt aus:

1. Kammern und fünf Felder breite Gänge ergeben eine gemeinsame Bodenmenge.
2. Alle acht Nachbarzellen außerhalb dieser Menge bilden die vollständige Kontur.
3. Jede Konturzelle erhält genau einen deterministischen Wandtyp. Wände werden
   weder zufällig gewählt noch als überlappende Einzelstempel gesetzt.
4. Einrichtung folgt erst danach, mit Abstand zu Startpunkten, Türen und Treppe.

Die Rollen verwenden die originalen violetten Tiles:

| Rolle | Tile |
| --- | --- |
| Obere Mauerfläche mit Krone | `violet_002` |
| Untere Mauerfläche | `violet_037` |
| Linke / rechte Seitenkante | `violet_021` / `violet_027` |
| Außenecken NW / NE / SW / SE | `007` / `005` / `036` / `034` |
| Innenecken NW / NE / SW / SE | `033` / `029` / `012` / `008` |

Die Richtungen beschreiben die Lage des **Wandfeldes** relativ zur Bodenfläche.
Wandgrafiken bleiben ungedreht, damit die Beleuchtungsrichtung erhalten bleibt.
Kontakt-Schatten auf dem Boden ergänzen die sichtbaren Mauerflächen. Fehlender
Boden blockiert über zusammengefasste Void-Rechtecke; diese werden nicht als
zusätzliche Mauerblöcke gerendert. Der gebrochene nördliche Eingang im ersten Level
verwendet das originale `violet_045`. Andere Übergänge sind separate Kryptentore.

## Zusätzliche optionale Datenfelder

Die vorhandene Generator4-/Schema1-Struktur bleibt bestehen. Andere Bibliotheken
verwenden weiter ihre bisherigen Regeln.

| Feld | Bedeutung / Standard |
| --- | --- |
| `campaign_room_count` | Anzahl Räume pro Ebene,3–10; Standard bisherige Balance |
| `campaign_title` | Anzeigename, hier `Crypt of the Damned` |
| `crypt_procedural` | Kandidat beim Spielstart aus Rezepten erzeugen; sonst false |
| `crypt_style_source` | Quellraum, SHA256, feste Wandrollen und Bodenfamilie |
| `crypt_recipe.chambers` | `[x,y,w,h]` in32px-Zellen; die ersten zwei sind die festen Ankunftskammern |
| `crypt_recipe.links` | Paare von Kammerindizes, die über Gänge verbunden werden |
| `crypt_profile` | Krypta-Präsentation, standardmäßig false |
| `crypt_entrance` | Nur die erste Vorlage trägt den gebrochenen Anfangseingang |
| `crypt_wall` am Tile | Aus der Kontur erzeugte Mauer; ohne Boden darunter genügt die Void-Kollision |
| `encounter.min_enemies/max_enemies` | Seed-basierte normale Gegnerzahl, im Kandidaten5–10 |
| `encounter.spawn_min_distance` |288Pixel Schutzabstand zur tatsächlichen Ankunft der Spieler |
| `encounter.enemy_spacing` |80Pixel Mindestabstand zwischen gewählten Gegnerstarts |
| `encounter_seed` | Nur zur Laufzeit: Host-Seed für Gegnerplatzierung |
| `crypt_ambience.fog_opacity/fog_speed` |0,16 Deckkraft /5Pixel pro Sekunde für langsamen Hintergrundnebel |
| `reward_presentation.card_duration/card_stagger` in Balance |0,4Sekunden Einflug,0,08Sekunden Versatz je Karte |

Der Bossraum enthält einen Boss mit zwei Begleitern. Gegnerpositionen werden auf
freien Zellen durch den Host gewählt; zurückkehrende Spieler lösen keinen neuen
Gegnerspawn aus. Nach der Belohnung bleibt die bekannte freie Erkundung erhalten.

Eine tatsächliche Änderung im Editor schaltet die bearbeitete Kopie auf explizit
gemalte Vorlagen um (`crypt_procedural=false`). Dadurch überschreibt ein späterer
Seed keine persönlichen Änderungen. Entwürfe werden weiter ausdrücklich gespeichert;
die bestehende Funktion **IM SPIEL VERWENDEN** bleibt die Übernahmegrenze.

## Grafik, Belohnungen und Bedienung

16zusätzliche Krypta-Requisiten liegen unter `assets/crypt/props/`. Der Editor
zeigt sie in der Gruppe **CRYPT**. Die PNGs sind64×64 auf einem32px-Platzierungsraster;
ihre überstehenden Bildteile werden nach Tiefe sortiert. Originalatlanten bleiben
erhalten. Herkunft und Erzeugung: `assets/crypt/README.md`.

Das Außenfeld ist fast schwarz und enthält langsam ziehende, schwache Nebelbänder.
Diese liegen hinter dem Boden und beeinflussen weder Sichtbarkeit von Gegnern
noch Kollision. Tore haben getrennte offene/geschlossene Bilder und behalten die
vorhandene Schwarzblende. Belohnungskarten öffnen beim ersten Erreichen der
Belohnungsphase automatisch und fliegen nacheinander ein. Esc darf sie schließen;
die gleiche Belohnung wird anschließend nicht automatisch erneut aufgedrängt.

## Stand der Abnahme

Auf ausdrücklichen Nutzerwunsch wurden **keine Spieltests, Unit-Tests oder
Mehrspieler-Smokes** gestartet. Ausgeführt wurden nur die Asset-Erzeugung, Godots
Asset-Import und reine Syntaxprüfung ohne Spielausführung. Statische Designbilder
sind keine Nachweise für tatsächliches Spielgefühl, Performance oder fehlerfreie
Darstellung aller Seeds. Die visuelle und spielerische Abnahme steht aus.

Strukturelle Inspiration: Shattered Pixel Dungeon trennt Raumaufbau, Ausgestaltung
und Gegnerplatzierung in seinem
[RegularLevel](https://github.com/00-Evan/shattered-pixel-dungeon/blob/master/core/src/main/java/com/shatteredpixel/shatteredpixeldungeon/levels/RegularLevel.java).
Es wurde kein Java-Code und kein Asset dieses Projekts übernommen.
