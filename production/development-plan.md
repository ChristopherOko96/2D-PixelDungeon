# Entwicklungsplan: Basement Run mit Godot und Multiplayer

## Aktuell: Krypta-Stil festgelegt und drei Untotenrollen

Der Nutzer priorisiert die Art Direction vor der Balanceabnahme. Story022
setzt den bisherigen ruhigen32px-Kryptastil als Standard fort und ergänzt
Skelettbogenschütze, Nekromant und Schildkrieger.36Idle-/Lauf-/Angriffsframes,
gemeinsamePixelgröße/Palette und die vorhandenen Wobble-/Treffer-/Todeseffekte.
Rollen sind im normalen Seed-Lauf gemischt, der Nekromant ab Raum3 und höchstens
einmal pro Raum; Beschwörungen bleiben hart begrenzt. Boss ausschließlich10.

AI171/0, Gameintegration127/0, Assets/Feedback82/0, Schild-/Überschuss4/0,
Perks100/0 und Feedback19/0. Kontrollierte2-Prozess-Replikation bestanden.
Sichtbare GPU-Animationen im Originalrenderer und aktualisierte F6-Werkstatt
vorhanden. Persönliches Stil-/Spielgefühl bleibt zu bewerten, weitere Online-/
Lastabnahme ist zurückgestellt. [Stilstandard, Gegner und Bilder](../docs/CRYPT-ENEMIES.de.md).

## Aktueller Core-Ausbau:48 kombinierbare Perks

Der Nutzer priorisiert Core-Design und stellt weitere LAN-/Online-/Lastabnahme
vorerst zurück. Story021 erweitert fünf einfache Segen auf48eigene Perks mit
unterschiedlichen Schuss-, Flug-, Element-, Schutz- und bedingten Wirkungen.
Drei persönliche Angebote berücksichtigen Stapelgrenzen, Voraussetzungen,
fehlende Heilung und bestehende Tags. Keine festen Klassen oder Setzwänge.

Gezielte Regeln/Katalog667/0, tatsächliche Kampf-/Kombinationsprüfungen100/0,
UI159/0; bestehende Spiel-/Erkundungsregeln24/0 und85/0. Zwei echte lokale
Prozesse prüfen persönliche Karten, Wahlbestätigung, doppelte/ungültige Wahl
und Inventarreplikation in einer kontrollierten Belohnungsfixture. Sichtbare
GPU-Prüfansichten von Karten, Inventar und Projektil-/Statuseffekten sind
gesichert. Keine neue vollständige Kampagnen-, LAN- oder FPS-Abnahme für diesen
Perkstand. Langfristige Balance und persönliches Spielgefühl bleiben zu bewerten.

[Perkkatalog und Buildbeispiele](../docs/PERKS.de.md),
[Story021](epics/dungeon-rooms/story-021-perk-builds.md).

## Aktuell ausgeführt: Clientglättung, Aufnahmeprüfung und Koopnachweise

Story019 implementiert bounded Clientinterpolation, stabile Projektilkennungen,
Serverzeit und Protokoll-/Regel-/Engine-/Datenabgleich vor Lobbyrechten. Story020
belegt aktuelle Solo-/Zwei-/Vier-Prozess-Zehnerläufe, Rückweg ohne Farming,
Boss10, Abstieg und echte Perk/Wipe/Neustartfälle. Vierer-UDP-Störung ebenfalls
bestanden.190 gezielte Logikprüfungen und sechs reale Aufnahmerollen ohne Fehler.

Sichtbarer1080p-Vierer-Client über alle zehn Räume/Boss/Treppe:143,68FPS im Mittel,
p958,035ms; jedes Raum-Kampf-p95 unter16,667ms. Private Testbotnavigation wurde
vorher vorbereitet, weil deren kalter Wegaufbau sonst die Renderprobe belastet;
Grenzwerte unverändert, vorherige Fehlmessung und Diagnose bleiben dokumentiert.

Nutzer bestätigt nur einen PC. Echte Zwei-Rechner-/30Minuten-LAN-Abnahme und
persönliches Stil-/Spielgefühl bleiben offen, statt lokale Prozesse als LAN
auszugeben. [Prüfbericht](../docs/GAMEDEV-UMSETZUNG.de.md),
[vorbereiteter LAN-Ablauf](../docs/LAN-ABNAHME.de.md).

## Aktuell: lesbare Schrift, ganze Spielfläche und Review

Story018 integriert Pixel Operator8 samt Lizenz, klare16/24/32px-Typografie und
ein Spielbild über die gesamte Fensterfläche. F11/Alt+Enter/ESC→Anzeige schalten
Vollbild um; Kamera, HUD, Eingaben, Dimmer und Schwarzblenden passen sich an.
Gefundene Lobby- und Kartentextüberläufe wurden korrigiert. Gezielte GPU-
Sichtprüfung von Fenster/Vollbild/anderen Formaten, keine breite Spieltestserie.

Als Nächstes: manuelle Abnahme des aktuellen Zehn-Raum-Laufs, danach
Clientglättung/Versionsabgleich und belegte Zwei-/Vier-Spieler-LAN-Läufe mit
Bildzeitmessung. Neue Dekoration folgt erst nach Stilfeedback.
[Review und konkrete nächste Schritte](../docs/UI-VOLLBILD-REVIEW.de.md).

## Aktuell: ruhiger erster Prototyp und Rucklerkorrektur

Story017 setzt die neueste Nutzerkorrektur um: originale ruhige 32px-Böden des
ersten Godot-Prototyps 44c9b80, klare erhöhte Mauerkanten und warmes oranges
Originalfeuer. Die gesättigte Pack-Restaurierung aus Story016 ist überholt.
Aktive Räume verwenden `classic_quiet` ohne Raumdekoration, Truhen,
Belohnungssockel oder Nebel. Spätere Assets müssen zu diesem Stil passen.

Boden und Wandzeilen werden bei Raumänderung vorbereitet; Wand-/Figuren-Tiefe
bleibt erhalten. Kollisions-/Navigationsdaten und unveränderte Raumgeometrie in
Snapshots werden zwischengespeichert. Ein isoliertes CPU-Profil derselben
Gartenansicht ergab 15,343→0,353 ms mediane Zeichenzeit; zehn gleiche blockierte
Pfadanfragen 1878,081→11,223 ms gesamt. Bedingungen und einmalige Vorbereitung
stehen in Story017. Eine sichtbare sechssekündige Solo-Gartenmessung mit sechs
Gegnern ergab144FPS auf derRX6600, Bildzeit p95=8,29ms. Vier-Spieler-Leistung
und die manuelle Stil-/Spielabnahme bleiben offen. Keine breite
Spiel-/Unit-/Netzwerktestserie wurde für diese Korrektur ausgeführt.

Zehn aktive Karten, Boss nur in Raum10, Editorfunktionen, Belohnungskarten und
Schwarzblenden bleiben erhalten. Der persönliche Entwurf bleibt unverändert.
[Story017](epics/dungeon-rooms/story-017-quiet-classic-performance.md),
[aktueller Stil und Grenzen](../docs/ORIGINAL-TILE-RESTORE.de.md).

Die folgenden Abschnitte beschreiben frühere Entwicklungsstände; bei
widersprüchlichen Grafikangaben gilt die oben stehende aktuelle Korrektur.

## Historisch: zurück zu den Original-Tiles

Story016 deaktiviert die abgelehnte dichte Steinoptik. Zehn aktive Karten sind
auf die vier gelieferten Paletten umgestellt; Original-Pack-Requisiten, ruhige
Böden und warme Fackeln orientieren sich an den Nutzer-Atlanten und dem ersten
Godot-Prototyp44c9b80. Geometrie/Kollision und Boss10 sind unverändert.
[Umsetzung und Grenzen](../docs/ORIGINAL-TILE-RESTORE.de.md).


## Aktiv: zehn Karten im normalen Prototyp

Story015 übernimmt die aktuelle Krypta-Bibliothek nach ausdrücklichem Auftrag in
F5/Dev Run. Eingang zuerst, acht normale Vorlagen ohne Wiederholung gemischt,
Boss allein in Raum10 (mit zwei normalen Begleitern). Die frühere aktive Datei
ist gesichert, der persönliche Quellentwurf unverändert. Normale Initialisierung,
zehn verschiedene Layouts und der tatsächliche Boss-Spawn wurden in einer
gezielten Bildsession beobachtet. Die Räume wurden für Fotos direkt geöffnet;
kein vollständiger Durchlauf und keine breite Testserie.
[Bilder und Bedingungen](qa/evidence/current-prototype/README.md).


## Aktuell: ausgewählten Raum selbst spielen und die neue Art Direction beurteilen

Story014 stellt einen direkten Offline-Spielstart für den ausgewählten Entwurf
bereit. Der Editor blockiert nicht mehr an anderen Räumen oder einer Drei-Raum-
Folge. Im aktualisierten Gartenfenster kann der Nutzer jetzt selbst starten.
Die manuelle Spiel-/Bildbewertung bleibt ausdrücklich offen.

16Umgebungsanimationen und Themenregeln ergänzen Blumenbeete, Bücherreihen und
Ritual-/Grabgruppen. Auf die jüngste Nutzerkorrektur folgen neue Steintiles im
Stil der Requisiten und statische Frame0-Körper mit getrennten Effektmasken.
Originale, Geometrie und Kollision bleiben erhalten. Nur Import, Syntax und
Art-Authoring ausgeführt; keine automatisierten Spieltests.


## Aktueller Kandidat: Crypt of the Damned

Story013 bereitet eine getrennte Zehnerbibliothek zur manuellen Abnahme vor.
Nach zwei abgelehnten Bildreihen wurde die Kopie ganzer Räume verworfen. Der
Generator verwendet unabhängige Kammergraphen und eine vollständige deterministische
Wandkontur mit Original-Tiles. Weitere Teile: Krypta-Einrichtung, Tore, Nebel,
zufällige Gegnerstarts und automatisch einfliegende Belohnungskarten.
Auf Nutzerwunsch keine Spiel-/Unit-/Netzwerktests; nur Asset-Import und Syntax.
Die optische Abnahme ist offen. Der eigene Entwurf und die normale aktive
Bibliothek bleiben erhalten. [Anleitung](../docs/CRYPT-OF-THE-DAMNED.de.md).


## Ganze Flächen statt einzelner Tiles

Nach Nutzerklärung ergänzt Story011 den Modus **Bereich auswählen**, sichtbare
Ersetzen-/Löschen-Buttons, Strg+A, Entf/Rücktaste und Esc. Die Flächenaktion ist
jeweils ein Undo-Schritt. Modell24/0, UI20/0, Editorregressionen und grafische
Prüfung bestanden. [Bedienung](../docs/DUNGEON-EDITOR.de.md).


## Aktuelle Editor-Reparatur

Story010 behebt das Übermalen auf derselben Zelle und ergänzt sichtbare
Kollisionen im Raster. ERSETZEN ist standardmäßig aktiv; ausgeschaltet lässt
sich eine Ebene unter einer anderen bearbeiten. Rasterfarben und Schraffuren
zeigen Boden, Wand und fehlenden Boden. Replacement29/0, Klassifikation17/0,
OpenGL-Pixel6/0 und bestehende Editor-/Geometrieprüfungen bestanden.
[Bedienung](../docs/DUNGEON-EDITOR.de.md).


## Neueste Editor-Korrektur: freie Konturen

Story009 ersetzt den automatisch eingerichteten Rechteckraum bei neuen Vorlagen
durch eine vollständig leere Zeichenfläche. Nur gemalter Boden ist begehbar;
Boden und Wand/Deko haben eigene Ebenen. Türkoordinate, Richtung und Grafik werden
vom Autor gesetzt. Die Raumplanung verbindet vorhandene passende Gegenrichtungen.
Startplätze und Bossabstieg werden ausdrücklich platziert. Alte Vorlagen bleiben
erhalten. Anleitung: [Freier Dungeon-Editor](../docs/DUNGEON-EDITOR.de.md).


## Aktueller Stand vom 26.10.2026

Die jüngste Nutzerkorrektur setzt wieder **32×32** als Weltraster. Der neue
Godot-Stand des Bruders auf `main` wurde gelesen; Sounds,0x72-Animationen und
Feedback sind selektiv übernommen. Tür-/Treppenwechsel erhalten eine gemeinsame
Schwarzblende und getrennte Sounds. Details stehen in Story007 und
[Animationen/Übergänge](../docs/ANIMATIONEN-UEBERGAENGE.de.md).

Der anschließende Editorauftrag ergänzt **LEERER RAUM**, eigene Maße pro Vorlage,
eine Palette aus280 separaten32×32-PNGs und Q/E-Vierteldrehung. Solide Zellen
wirken in der Hostkollision. Der Generator kombiniert kleine und große Vorlagen;
die Spielkamera folgt lokal mit leichtem Mausschwenk, das HUD bleibt fest.
[Editoranleitung](../docs/DUNGEON-EDITOR.de.md), Story008 und
[Prüfbericht](qa/verification.md) halten Umfang und Nachweise fest.

Änderungen liegen lokal auf `codex_v2`. Kein neuer Commit, Push oder Merge in
`main` wurde durch diese Aufträge vorgenommen. Die unten aufgeführten Stände
beschreiben die vorherige Entwicklung;16-Pixel-Raster und fester Außenrahmen
sind durch die aktuelle Korrektur überholt. `main` ist inzwischen ebenfalls
Godot; die ursprüngliche Unity-Linie ist historisch.


Status: **Fortgeschriebener Prototypplan**, Stand 25.10.2026. Zukünftige Spielregeln und Messziele sind
Vorschläge. Der vorhandene kleine Entwicklungsstand ersetzt keinen Nachweis eines
vollständigen Dungeon-Spiels oder belastbarer Vier-Spieler-Performance.

Aktuelles Veröffentlichungsziel auf ausdrücklichen Nutzerwunsch vom 25.10.2026:
`codex_v2` in `ChristopherOko96/2D-PixelDungeon`. Der vorherige V2-Fork bleibt
erhalten; die Unity-Linie auf `main` bleibt getrennt.
Details: [Veröffentlichung](../docs/V2-PUBLISH.de.md).

## Ziel und Herkunft der Anforderungen

Ein 2D-Pixel-Dungeon-Crawler mit Twin-Stick-Kampf, zufällig zusammengesetzten
Räumen und Perks nach Raumerfolgen. Mehrere eigenständige Spielclients sollen
gemeinsam spielen können. The Binding of Isaac ist die spielmechanische Referenz.

| Herkunft | Inhalt | Einordnung |
| --- | --- | --- |
| Erster Nutzerauftrag | 2D-Pixel-Spiel, Raum-Perks, verbundene separate Clients, anfangs bis zu acht Spieler; kleinere Grenze möglich | Ursprünglicher Multiplayer-Rahmen |
| Nutzerkorrektur im selben Auftrag | Godot verwenden; Unity nicht herunterladen | Maßgebliche Engineentscheidung für diese Arbeit |
| Jüngste Nutzerkorrektur | Höchstens vier Spieler jetzt; acht nur als spätere Option. Echte 32×32-Pixelgrafik und gut lesbarer Kampf in Richtung Isaac/Vampire Survivors | Aktueller verbindlicher Umfang |
| Ausgangscommit `e6204688157dbbb6d10faa7906ace5fa482d016d` | @design/game-brief.md: Arbeitstitel Basement Run; Bewegung, Schießen, Gegner, Herzen, Raumvorlagen, etwa fünf Items, ein Stockwerk und Boss | Ursprüngliche Spielidee des Bruders |
| Derselbe Ausgangscommit | Multiplayer im Spielbrief ausgeschlossen; Unity 6.3 LTS in @project.yaml und @CLAUDE.md konfiguriert | Historischer Stand; durch den neuen Auftrag geändert |
| Dieser Entwurf | Kooperativer Hostbetrieb, konkrete Loot-, Todes- und Übergangsregeln sowie Messziele | Vorschläge, keine behaupteten Entscheidungen des Bruders |

Am Ausgangscommit existierten Studio-Anweisungen und Referenzdokumente, aber kein
implementiertes Spiel. `studio-tests/` prüft dieses Studio-Gerüst und enthält keine
ausgeführten Spieltests. Die aktuelle Godot-Grundlage wurde neu im eigenen Branch
angelegt; die folgenden Umsetzungsnachweise gelten für diesen Entwicklungsstand.

## Aktueller Ausbau: Nutzer-Tilesets, Erkundung und Trefferfeedback

Nach Ablehnung der ersten Belohnungsansicht umgesetzt: drei transparente,
frei stehende Karten mit großen Pixel-Symbolen. Die Auswahl steht separat vor
der Welt; der Menürahmen ist ausgeblendet. Lokal gebündelte **Pixelify Sans**
ersetzt die Systemschrift in allen Spiel-/Werkstatt-UIs. Fünf neue Symbole mit
eingebauter Bildgenerierung erzeugt und als16×16-RGBA aufbereitet; Prompts,
Originale und Schriftlizenz erhalten. Story006:20 Kartenprüfungen,25 Menüprüfungen,
bestehende Suiten, zwei echte Clients mit unterschiedlichen Karten/Hostbestätigung
und anschließender Erkundung bestanden. [Bedienung](../docs/BELOHNUNGEN.de.md).

Aktueller UI-Auftrag umgesetzt: eigene Herzen oben links, mittige Spielwelt,
Raum/Boss/Karte/Gruppe/Perks und Sitzungsdaten im [Esc-Menü](../docs/SPIELMENUE.de.md).
Solo pausiert die Simulation; Mehrspieler-Menüs bleiben persönlich bei weiter
laufender Welt. Perk-/Ready-Aktionen und Erkundung bleiben erhalten. Story005:
25 neue Integrationsprüfungen, bestehende Suiten, echter Host-/Client-Menütest,
Vierer-Lauf über zwei Ebenen und visuelle Prüfung der sechs Menüseiten bestanden.

Auf Nutzerwunsch ist ein [Dungeon-Baukasten](../docs/DUNGEON-EDITOR.de.md)
ergänzt:16×16-Wandpinsel, Startpunkte, gekoppelte Türen, Boss-Innentreppe,
Feuer/Truhe, Raumfarben sowie zufällige Auswahl oder feste Drei-Raum-Folge.
Entwürfe sind separat und rückgängig bearbeitbar. Nur eine geprüfte Übernahme
ersetzt mit Sicherung die aktive Datei. Ein echter lokaler Raumtest erhält
beim Zurückkehren den Entwurf. Story004 erfasst Umfang und Grenzen: vorhandener
448×240-Außenrahmen, bis zu64 Raumvorlagen, weiterhin höchstens vier Spieler.
Autorentest18/0, Datei-/Spielintegration25/0, bestehende Suiten und Vier-Prozess-
Lauf über zwei Ebenen mit Generator3 bestanden; Oberfläche/Testlauf angesehen.

Zusätzlicher nächster Grafikschritt umgesetzt: eine feste, direkt im Godot-
Editor sichtbare [Artstyle-Werkstatt](../docs/ART-DIRECTION.de.md) mit separaten
Ansichten für Raum, Figuren/Effekte und HUD. Alle Herzen bilden eine Grafik.
Die Referenz ist für weitere Stilabstimmung vorgesehen; der Nutzer hat den
Gesamt-Artstyle noch nicht als endgültig bestätigt. Online-Referenzen sind
insbesondere **Brotato** und The Binding of Isaac. Story003 dokumentiert die
Werkstatt sowie deren getrennte Grafik-/Editorprüfung.

Die jüngste Korrektur ersetzt 32×32 durch **16×16**. Native Welt: 448×240 mit
ganzzahliger 2×-Anzeige. Originale Dungeon-, UI-, Item- und Animationssheets
bestimmen jetzt Boden, räumliche Wände, Durchgänge, Herzen, Feuer und Perkicons.
Der Nutzer verlangt sichtbare Wandoberkanten und vertikale Innenflächen wie in
seiner animierten Referenz; ein flacher Rahmen und Treppensymbole als Seitentür
erfüllen diesen Auftrag nicht.

Der bisher automatische Ready→Raumwechsel wurde ersetzt: Ready schaltet freie
Erkundung frei, E an einer räumlichen Tür mit der versammelten Gruppe wechselt
den Raum. Zurückgehen in gesäuberte Räume erzeugt keine Gegner, Belohnungen oder
wiederholte Wiederbelebung. Nach dem Boss bleibt die Ebene begehbar; die separate
Innentreppe führt in die nächste erzeugte Ebene und erhält den Build.
HP-Anzeigen, Hitstun, abgefangener Rückstoß und Trefferanimationen sind integriert.
Details und Parameter: [Erkundung](../docs/EXPLORATION.de.md).

Tatsächliche Nachweise: 4146 Generator-, 1585 Port-, 23 Integrations-, 22 Spielregel-
und 51 Erkundungsprüfungen bestanden. Zwei und vier getrennte Prozesse haben
je zwei Ebenen mit sechs identischen Layouts, zwölf beziehungsweise 24 Perks,
Türen, Treppen und anschließender Erkundung durchlaufen. Vier-Spieler-Kampf ist
damit lokal funktional belegt; LAN/WAN, Latenz/Paketverlust und Leistung bleiben
offen. [Prüfbericht](qa/verification.md#native16-erkundung-und-trefferfeedback).

## Basis vor diesem Ausbau

- Der nächste fehlende Kernschritt aus Baufolge 4 / Phase 3 ist umgesetzt:
  [Raumgenerator-Story](epics/dungeon-rooms/story-001-seeded-rooms.md).
  Drei normale Vorlagen plus Bossvorlage ergeben einen verbundenen Drei-Raum-Lauf
  mit Seed, Generatorversion und stabilen IDs. Der Host überträgt die gewählte
  Geometrie; Säulen blockieren Bewegung und beide Projektilarten. Gegner umgehen
  Deckung, eine kleine Raumkarte zeigt Fortschritt und Boss. 4146 Generator-
  und 22 Integrationsprüfungen sowie die bisherigen 21 Spielregeln bestehen.
  Zwei echte Prozesse beenden alle drei identischen Layouts mit sechs Perks;
  die Vierer-Lobby besteht weiterhin. Bild und genaue Prüfgrenzen stehen im
  [Prüfbericht](qa/verification.md#raumgenerator-vom-25102026).

- Phase 0 ist als lokale Entwicklungsgrundlage eingerichtet: portable Godot-
  Version geprüft, `Doctor` und Import-/Parseprüfung erfolgreich. Grafischer
  Spielstart mit Menü und Kampfszene geprüft; Bildbeleg unter
  @production/qa/evidence/godot-prototype.png (**NEU**).
- Die eingebaute Suite **NEU** @tests/game_rules.gd wurde ausgeführt:
  `GAME_RULES checked=21 failures=0`, Exitcode 0. Sie prüft Spielregeln direkt
  mit Godot, darunter finale Belohnung → Ready-Gate → Sieg, doppelte Perks,
  ungültige Eingaben, Wiederbelebung und Teamwipe. Sie ersetzt keine echten Peers.
- Phase 1 ist für zwei getrennte ENet-Prozesse über Loopback belegt. Ein erster
  automatisierter Rauchtest durchlief drei Räume einschließlich Boss bis zum
  Sieg; beide Prozesse endeten sauber mit Exitcode 0.
- Phasen 2–4 sind teilweise als kleiner Prototyp umgesetzt: gemeinsame Bewegung,
  Schießen, Gegner/Boss, fünf einfache datenbasierte Perks und Raumwechsel. Die
  persönliche Auswahl und das gemeinsame Ready-Gate wurden auch nach dem
  Bossraum erfolgreich durchlaufen. Vollständiger Zwei-Prozess-Nachweis:
  `RoomsCleared=3`, `PerksSelected=6`, `RUN_COMPLETED players=2`, Sieg auf beiden
  Seiten, Host-/Client-Exitcode 0, keine stderr-Ausgabe oder MTU-Warnung.
- Prototypregel: Gefallene kehren am nächsten Raum mit 50 % ihres maximalen
  Lebens zurück; nur lebende Teilnehmer müssen bereit bestätigen. Diese Regel
  ist implementiertes Versuchverhalten und noch keine bestätigte Release-Regel.
- Der aktuelle Viererstand besteht Import, 21 Regelprüfungen und die Verbindung
  von Host plus drei Clientprozessen mit sauberem gleichzeitigen Trennen.
  Ein fünfter Teilnehmer wurde im zehnsekündigen Testfenster nicht aufgenommen.
  Alle acht PNG-Quelldateien sind anhand ihrer Bildmaße als 32×32 verifiziert;
  Kampfszene und Vierer-Lobby wurden grafisch geprüft. Der Boss wird aus seiner
  32×32-Quelle bewusst zweifach dargestellt. Nachweise:
  **NEU** @production/qa/verification.md und @production/qa/evidence/godot-lobby-4.png.
- Phase 5 bleibt offen: keine Vier-Spieler-Leistungszusage aus dem konfigurierten
  Limit ableiten. Reales LAN, WAN und Belastung müssen gesondert belegt werden.
- Protokoll-/Inhaltsversionen, Interpolation und Bandbreitenmessung bleiben
  Ausbauaufgaben. Detaillierter Prüfstatus: **NEU** @docs/DEVELOPMENT.de.md.

## Technische Grundlage und Umfang

- **Godot 4.7.2 standard**, GDScript, Compatibility Renderer, Godot Physics 2D.
  Kein .NET-SDK und keine zusätzliche Netzwerkbibliothek für den ersten Stand.
- Einstieg über `project.godot` und `src/main.tscn`; native Godot-High-Level-
  Multiplayer-API mit ENet über UDP. Ein Host spielt mit und führt die
  maßgebliche Simulation aus. Zuerst lokale Verbindung/LAN.
- Aktuelle Obergrenze: **vier Teilnehmer insgesamt = ein Hostspieler plus drei
  Clients**. Zwei getrennte Spielprozesse zuerst prüfen, anschließend vier.
  Acht ist ausschließlich eine spätere Erweiterungsoption; es gehört nicht zur
  aktuellen Abnahme und rechtfertigt kein höheres aktives Sitzungslimit.
- Der kleine spielbare Entwicklungsstand umfasst drei Räume einschließlich Boss
  aus mehreren Vorlagen sowie fünf einfache Perks. Verzweigte Erkundung, ein
  vollständiges produktionsreifes Stockwerk und ausgearbeitete Perk-Kombinationen
  bleiben weitere Arbeitspakete.
- Vorschlag: Windows-PC und Koop im gemeinsamen Raum zuerst. Keine Konten,
  Metaprogression, laufenden Spielbeitritte oder automatische Hostmigration im
  ersten Stand. Gamepad, weitere Plattformen und Persistenz anschließend bewerten.

## Pixelgrafik und übersichtlicher Kampf

Verbindliche aktuelle Gestaltungsrichtung: echte **16×16-PNG-Sprites** auf einem
16-Pixel-Grundraster, Nearest-Filterung und keine Glättung. Dies ersetzt die
frühere 32×32-Anforderung. @assets/sprites/
enthält die Rasterdateien; NEU @scripts/generate_pixel_assets.gd ist der
Generator. Die tatsächlichen PNG-Maße werden vor einer Erfolgsaussage geprüft.
Vergrößerte primitive Formen allein erfüllen diese Anforderung nicht.

The Binding of Isaac und Vampire Survivors dienen der Kampflesbarkeit als
Referenz: vier klar unterscheidbare Spielerfarben, erkennbare Gegnersilhouetten,
eigene und feindliche Projektile visuell getrennt, sichtbare Treffer- und
Schadensrückmeldung. Im nächsten Grafikdurchgang Idle-/Schussanimationen und
Umgebungsdetails gezielt verbessern. Weitere Bodenvarianten sind für diesen
ersten Umfang nicht erforderlich.

**Abnahme:** PNG-Metadaten bestätigen 16×16 bei den Basissprites. Eine aktuelle
Spielaufnahme zeigt scharfe Pixelkanten und auch mit vier Teilnehmern erkennbare
Spieler, Gegner und Projektilrichtungen. Ein Rastermaß allein belegt noch keine
übersichtliche Kampfszene.

## Architekturvorschlag

Der Host entscheidet über gültige Bewegung, Schussfrequenz, Projektilentstehung,
Treffer, Schaden, Gegner, Raumabschluss und Belohnungen. Clients senden Eingaben
und zeigen den bestätigten Zustand an. Für jede Spielaktion werden Absender,
Besitz, Phase, Wertebereiche und Rate geprüft. Ein Client darf sich weder Schaden
noch Perks selbst verbindlich zuweisen. Wiederholte Auswahl- oder Ready-Anfragen
bewirken keinen zweiten Effekt. Hostautorität verhindert kein Cheating durch den
Host selbst; ein dedizierter Server wäre eine spätere eigene Ausbaustufe.

Raumfolge und Vorlagenwahl entstehen aus Seed und Generatorversion. Der Host
bestätigt Raumkennung und dynamischen Spielzustand. Derselbe Seed macht
Godot-Physik nicht deterministisch; Kampf und Gegner werden maßgeblich simuliert
und verteilt. Interpolation und bei Bedarf Vorhersage folgen einer funktionierenden
und gemessenen Grundverbindung.

Spielwerte und Perks werden als Daten gehalten. Netzwerk, Darstellung, Eingabe
und Spiellogik erhalten im weiteren Ausbau getrennte Module. Der kompakte
Prototyp darf diese Grenzen zunächst in wenigen Dateien abbilden; vor weiterem
Inhalt muss seine Aufteilung mit Tests abgesichert werden.

## Aufgaben nach Phasen

`@pfad` bezeichnet einen am Ausgangscommit vorgefundenen Projektpfad. **NEU**
bezeichnet ein neu angelegtes oder vorgeschlagenes Ziel dieses Entwicklungszweigs;
diese Pfade sind keine Belege für vorhandene Implementierung im Originalstand.

### Phase 0 — Godot-Umgebung und kleiner Einstieg

1. Eigene Arbeitskopie mit Branch `codex/development-environment-plan` verwenden;
   @.gitignore, @.gitattributes und @CONTRIBUTING.md berücksichtigen. Historische
   Unity-Einstellungen auf die vom Nutzer gewünschte Godot-Grundlage umstellen.
2. Godot 4.7.2 als portable Standardausgabe bereitstellen; vollständige Ausgabe
   von `--version` und Downloadprüfsumme festhalten. NEU
   @scripts/godot-environment.json und @scripts/Dev.ps1 pinnen und prüfen die
   Engine. Maschinenpfade bleiben in ignorierter lokaler Konfiguration.
3. NEU @project.godot, @src/main.tscn, @src/game.gd und @src/dungeon_view.gd:
   startbarer 2D-Raum, einfache Eingabe und erkennbare Platzhalterdarstellung.
   Godot-Ressourcen und Szenen im nativen Format pflegen; Cache nicht versionieren.
4. NEU @docs/DEVELOPMENT.de.md: Editorstart, Spielstart, Host/Join und Import-/
   Parseprüfung dokumentieren. Die eingebaute `SceneTree`-Suite NEU
   @tests/game_rules.gd und die unabhängigen Prozessprüfungen NEU
   @tests/network_smoke.ps1 gezielt ausführen und ausbauen. Ein erfolgreicher
   Parsecheck ist kein Gameplaytest. Exporte benötigen passende Export-Templates
   und Export-Presets.

**Abnahme:** `Doctor` bestätigt den tatsächlichen Enginepatch und Featurebranch.
`Check` importiert das Projekt und lädt die Spielskripte ohne Parse-/Scriptfehler;
auch Fehler bei Exitcode 0 müssen auffallen. `Run` zeigt den kleinen Spielstand.
Fehlende Exporte, Tests oder manuelle Sichtprüfung werden getrennt benannt.

### Phase 1 — zwei eigenständige Prozesse verbinden

1. NEU @src/game.gd: Hoststart, ENet-Verbindung, Lobby, Teilnehmerzuordnung,
   Kapazitätsgrenze und verständliche Fehlermeldungen. Standardport: UDP 7777.
2. Host und Client zuerst auf `127.0.0.1`, danach auf zwei Rechnern im LAN starten.
   Getrennte Prozesse beweisen mehr als zwei Ansichten einer Editorinstanz.
3. Beitritt, volle Sitzung, ungültige Adresse und Client-/Hosttrennung gezielt
   prüfen. Vor Freigabe Protokoll-/Inhaltsversionen beim Verbindungsaufbau abgleichen.

**Abnahme:** Zwei Spielprozesse sehen dieselben zwei Teilnehmer im selben Raum.
Ein Clientabbruch räumt seinen Teilnehmerzustand auf. Hostverlust wird erkennbar
gemeldet. Ein Loopback-Nachweis allein ist kein LAN- oder WAN-Nachweis. Diese
Phase wird vor einem vollständigen Solospiel bearbeitet.

### Phase 2 — gemeinsamer Kampf und geprüfte Eingaben

1. NEU @src/game.gd weiterentwickeln: Bewegung, getrenntes Zielen, Schießen,
   Gegner, Schaden und Tod aus @design/game-brief.md für zwei Spieler abbilden.
2. Absender, Eingabegrenzen, Feuerrate und Phase auf dem Host prüfen. Fremde
   Spielfiguren steuern oder beliebigen Schaden übertragen darf wirkungslos bleiben.
3. Vor Erweiterung in NEU @src/player/, @src/combat/ und @src/networking/
   aufteilen, wenn die wachsende Komplexität dies rechtfertigt. Tests sichern
   Formeln und Zustandswechsel, Prozessprüfungen sichern die Replikation.

**Abnahme:** Beide Spieler bewegen sich und treffen denselben Gegner.
Gegnerlebenspunkte, Spielerleben und Tod stimmen nach Zustandsabgleich überein.
Ungültige Eingaben verändern keinen unzulässigen Zustand. Sichtbares Verhalten
wird im laufenden Spiel geprüft und mit Bildbelegen dokumentiert.

### Phase 3 — Räume, Übergänge und Perks

1. NEU @src/dungeon/ und @assets/data/: zusammenhängende Raumfolge aus Vorlagen,
   Seed, Generatorversion und stabilen Kennungen. Der Host bestätigt den Raum-
   und Kampfzustand. NEU @src/perks/: stabile IDs, Effekte und Stapelregeln.
2. **Vorschlag:** Jeder berechtigte Spieler erhält nach jedem abgeschlossenen
   Kampfraum genau eine persönliche Perk-Auswahl. Der Host bestätigt Angebot und
   Auswahl genau einmal. Der erste Entwicklungsstand darf diesen Ablauf mit
   wenigen einfachen Perks erproben, ohne fünf fertige Perks vorzutäuschen.
3. **Vorschlag:** Gemeinsamer Raumwechsel erst nach Kampf, Auswahlphase und
   Bereitschaft aller verbundenen lebenden Spieler. Tote/getrennte Spieler
   blockieren den Übergang nicht. Abbrüche aktualisieren die Teilnehmermenge.
4. **Vorschlag:** Neue Beitritte nur in der Lobby, kein Reconnect in laufende
   Läufe. Aktuelle Prototypregel: Gestorbene beobachten bis zum nächsten Raum und
   kehren dann mit 50 % maximalem Leben zurück; als Produktregel noch abzustimmen.
   Teamwipe beendet den Lauf. Hostverlust beendet die Sitzung mit Meldung, ohne
   automatische Hostmigration.

**Abnahme:** Zwei Clients stimmen bei Raumkennung und Inventar überein. Doppelte
Auswahl gewährt keinen zusätzlichen Perk. Türkontakt vor Kampfabschluss wechselt
keinen Raum. Clienttrennung während der Auswahl, Teamwipe, Hostverlust und
unerlaubter später Beitritt werden geprüft. Einzelne bereits funktionierende
Prototypabläufe werden von noch offenen Regeln getrennt protokolliert.

### Phase 4 — vollständiger gemeinsamer Lauf

1. @design/game-brief.md mit den abgestimmten Multiplayer-Regeln und der
   Pixel-Art-Richtung pflegen. Historische Aussagen bleiben in der Bestandsaufnahme
   nachvollziehbar; neue Regeln müssen als solche erkennbar sein.
2. NEU @assets/data/, @assets/sprites/ und @src/rooms/: Raumvorlagen, ungefähr
   fünf unterscheidbare kombinierbare Perks und Boss ergänzen. Platzhalter durch
   eigene, lizenzierte Pixel-Assets und Audio ersetzen.
3. Lobby → mehrere Kampfräume mit Belohnungen → Boss → Ergebnis → neuer Lauf
   schließen. HUD für eigenes Leben, Team und Perks; Gamepad anschließend ergänzen.

**Abnahme:** Zwei Spieler beenden einen vollständigen Gewinn- und Verlustlauf.
Neustart übernimmt keine alten Gegner oder Perks. Fünf Perks wirken verschieden;
mindestens zwei Kombinationen werden anhand ihrer Daten geprüft. Ein unendlicher
Prototypraum mit Wellen gilt nicht als fertiges Stockwerk mit Boss.

### Phase 5 — Kapazität, LAN und Internet belegen

1. Sitzungen mit 2 und 4 Teilnehmern testen: Host plus 1 oder 3 Clients.
   Mindestens zwei reale Rechner einsetzen. Mehrere Prozesse auf einem Rechner
   zeigen Funktion, aber keine Performance auf der späteren Zielhardware.
2. **Vorgeschlagenes Netzwerktestziel:** 100 ms RTT und 1 % Paketverlust bei
   Bewegung, Schüssen, Kampfabschluss und Perkauswahl. Messmethode, Simulator,
   Dauer und Zustandskorrekturen dokumentieren. Zusätzlich mindestens 30 Minuten
   ungestörtes LAN ohne Absturz, doppelte Belohnung oder bleibende Abweichung.
3. **Vorgeschlagenes Darstellungsziel:** 60 FPS. Referenzhardware, Auflösung,
   Gegner-/Projektilzahl und Messmethode sind offen. Ohne dieses Szenario keine
   Performancezusage. Vier Spieler benötigen zusätzlich einen vollständigen
   Boss- und Belohnungsdurchlauf mit Netzwerk- und Framemessungen.
4. Nach LAN folgt ein Test über zwei echte Internetanschlüsse. ENet verwendet
   UDP; Router, NAT, Hostadresse und Firewall müssen tatsächliche Erreichbarkeit
   erlauben. Ein Relay ist ein gesondertes Architektur-/Betriebsprojekt und
   derzeit nicht konfiguriert. Keine Unity-Relay-Abhängigkeit hinzufügen.
5. CI für Import/Parsechecks und echte Spieltests einrichten. Windows-Exporte
   erst mit passenden Godot-Export-Templates und einem geprüften Preset
   automatisieren. Leere Tests oder Studio-Textprüfungen gelten nicht als Spieltest.

**Abnahme:** Die freigegebene Spielergrenze folgt den bestandenen Prüfungen.
Vier Spieler werden erst mit Nachweis unterstützt genannt. WAN bleibt ungeprüft,
solange kein echter WAN-Test vorliegt. Fehler führen zu weiterer Arbeit oder einer
ausdrücklich kleineren Grenze, nicht zu einer unbelegten Vier-Spieler-Zusage.
Eine spätere Erweiterung auf acht benötigt einen eigenen Umfangsentscheid und
erneute Kapazitäts-, Lesbarkeits- und Belastungsprüfungen.

## Aktueller Figurenstand,27.10.2026

Story024 ersetzt die Story023-Grafiken durch32×32-Chibis und einen blaugrünen
Lovecraft-Tentakelboss. Die zunächst erwogenen64px/adulten Proportionen wurden
durch die beiden jüngsten Nutzerkorrekturen ersetzt. Native Bilder und alte
Quellen sind getrennt erhalten; Karten-/Höllenthema wird aus den drei Referenzen
nicht übernommen. [Aktuelle Art und Nachweise](../docs/CHIBI32-ELDRITCH.de.md).

Story023 ergänzt vier neue Spieler und je48 eigene Bewegungsabläufe für die
acht Spieler-/Gegner-/Bossfiguren. Vier Richtungen zählen nicht als weitere
Aktionen. Die Bank nutzt generierte Richtungs-Keyposen mit gebackenen
Körperteilkurven.35 Aktionen sind rollenabhängig an vorhandene Spielzustände
angebunden,13 für spätere Mechaniken vorbereitet. Animation-Studio.cmd erlaubt
den direkten Vergleich mit Zeitlupe und Einzelbildern.

Nächster GameDev-Schritt ist jetzt die persönliche Figuren-/Animationsabnahme
im Studio und im normalen Prototyp: Silhouetten, Schuss-/Treffergewicht,
Rückwärts-/Seitwärtsbewegung und lesbarer Tod. Konkretes Feedback steuert den
nächsten Polishing-Durchgang. Neue Klassenfähigkeiten und weitere Online-/Last-
Abnahme bleiben getrennte Aufgaben. [Umfang und Nachweise](../docs/ACTOR-ANIMATIONS.de.md).

## Abhängigkeiten und Risiken

Phase 0 → 1 → 2 → 3 → 4 → 5. Netzwerkprüfungen begleiten ab Phase 1 jede Änderung.
Frühe Vier-Teilnehmer-Checks sind sinnvoll; sie ersetzen keinen kompletten
Lauf mit gemessener Last. Benötigt werden die gepinnte portable Engine, später
Export-Templates, zwei Testrechner und für WAN zwei Internetanschlüsse.

| Offener Punkt | Vorschlag | Noch abzustimmen oder nachzuweisen |
| --- | --- | --- |
| Spielergrenze | Aktuell höchstens vier insgesamt, zwei zuerst belegen | Viererbetrieb mit vollständigem Lauf und Messungen; acht nur spätere Option |
| Koop | Gemeinsamer Raum | Friendly Fire, Spielerkollision, Schwierigkeitsskalierung |
| Perks | Persönliche Auswahl je erfolgreichem Kampfraum | Auswahlangebot, Stapelgrenzen, tote Spieler |
| Tod und Übergang | Prototyp: Rückkehr im nächsten Raum mit 50 % maximalem Leben; Ready-Gate nur für Lebende | Endgültige Wiederbelebungsregel, Timeout, Untätigkeit |
| Verbindung | Host/ENet/LAN zuerst | Reconnect, Relay, dedizierter Server |
| Darstellung | Echte 32×32-PNG-Sprites, Nearest, lesbarer Kampf | PNG-Metadaten, Vier-Spieler-Übersicht, Animation/Umgebung und Audio |
| Leistung | Vorgeschlagene 60 FPS | Referenzhardware, Lastszenario und Messwerte |

Die Nutzerkorrektur bestimmt Godot als Engine. Konkrete Detailregeln werden mit
dem Bruder vor ihrer endgültigen Umsetzung abgestimmt und im Spielbrief erfasst.

## Branch, Fork und spätere Zusammenführung

Arbeitsbranch: `codex/development-environment-plan`, abgeleitet von `origin/main`.
Die lokale Arbeitskopie ist kein neu angelegter GitHub-Fork. Weitere Änderungen
in überschaubaren `codex/<thema>`-Branches entwickeln. Vor Veröffentlichung Diff,
Status und tatsächliche Prüfungen kontrollieren. Bei Pushrechten ist ein Branch
im Ursprungsrepository mit PR gegen `main` möglich; alternativ ein persönlicher
Fork mit dem Original als `upstream`. Keine vorhandenen Remotes grundlos ändern.
Zusammenführung erfolgt nach Review; kein automatischer Merge oder direktes
Arbeiten auf `main`.
