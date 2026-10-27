# Game Brief: Basement Run

## Aktueller verbindlicher Stand,26.10.2026

Die jüngsten Nutzerkorrekturen haben Vorrang vor den historischen Abschnitten:

- **Festgelegte Krypta-Art-Direction:** Ruhige32px-Schieferkrypta mit warmem
  Feuer und dazu passende Untote: Skelettbogenschütze, Nekromant und
  Schildkrieger. Gemeinsame2px-Pixelblöcke, Konturen, Knochen-/Violettpalette
  und bestehendes Wobble-/Treffer-/Todessystem. Neue Rollen und Animationen
  sind im Prototyp; [Stilstandard und Regeln](../docs/CRYPT-ENEMIES.de.md).
- **Core-Design vor weiterer Online-Abnahme:** Der Nutzer stellt LAN-/Online-
  und Lastabnahme vorerst zurück. Story021 erweitert den Katalog auf48eigene
  kombinierbare Perks: Schussmuster/Flugbahnen, Elemente, bedingte Treffer,
  Schutz und Risiko. Persönliche geeignete Dreierangebote, feste Stapelgrenzen
  und freie Synergien. [Katalog und Regeln](../docs/PERKS.de.md).
- **Godot, maximal vier Gesamtspieler**, getrennte Clients mit autoritativem Host.
- **Crypt of the Damned:** zehn verschiedene große Karten pro Ebene; Eingang
  zuerst, acht normale Karten ohne Wiederholung gemischt, Boss nur in Raum10.
  Nach dem Kampf erscheinen persönliche Belohnungskarten automatisch. Gesäuberte
  Räume bleiben begehbar; E an Türen verbindet die Räume. Die separate Boss-
  Treppe führt nach Abschluss der Ebene in eine neu erzeugte Krypta-Ebene.
- **Ruhiger erster Pixelstil:**32×32-Weltraster, ursprüngliche Schieferböden,
  klare erhöhte Mauerkanten und warmes oranges Feuer. Zurzeit keine Möbel,
  Pflanzen, Grabdekoration oder Nebel. Künftige Assets müssen diesen Stil treffen.
- **Lesbarkeit und Vollbild:** lokal gebündelte Pixel Operator8 in16/24/32px;
  1280×720-Designbasis, Spielansicht über die ganze Fenster-/Bildschirmfläche,
  unverzerrte Anpassung anderer Seitenverhältnisse. Herzen oben links im Spiel;
  Details über ESC. Vollbild mit F11, Alt+Enter oder ESC→Anzeige.
- Der Editor erstellt Raumvorlagen auf freier Fläche; der persönliche gespeicherte
  Entwurf bleibt erhalten.
- **Netzwerkstand:** begrenzte Client-Positionsinterpolation mit Raum-/Laufgrenzen
  und Mauereckenprüfung; Versions-/Datenabgleich vor der Spieleraufnahme.
  Solo sowie zwei/vier lokale Prozesse haben den aktuellen Zehn-Raum-Lauf,
  Boss, Abstieg und Neustart nach verdientem Perk bestanden. Ein lokaler Vierer-
  Störlauf mit100ms nominaler RTT/1% UDP-Verlust und ein sichtbarer1080p-Vierer-
  Kampagnenlauf sind dokumentiert. Echte LAN-Hardware/30Minuten und persönliche
  Stil-/Spielgefühl-Abnahme stehen aus; laut Nutzer ist nur dieser PC vorhanden.

[Umsetzung, Ergebnisse und Grenzen](../docs/GAMEDEV-UMSETZUNG.de.md).

**Neueste Editor-Korrektur26.10.2026:** Eine neue Raumvorlage beginnt auf einer
vollständig freien weißen/schwarzen Zeichenfläche. Boden, frei geformte Kontur,
Wände, Türen und Startplätze werden ausdrücklich gesetzt. Es gibt keinen
automatischen Außenrahmen oder vorgegebenen Eingang. Die frühere Beschreibung
rechteckiger dekorierbarer Räume gilt nur noch für bestehende Vorlagen.


**Maßgebliche Fortschreibung26.10.2026:** Wieder32×32-Weltraster. Der Editor
erstellt frei dimensionierte rechteckige Raumvorlagen (12–64 ×10–48 Felder)
aus einer leeren Vorlage, mit Einzel-Tile-Palette und Q/E-Drehung. Der Generator
kombiniert sie zu Dungeons. Eine sanfte Kamera folgt dem eigenen Charakter und
schwenkt leicht zur Maus. Die weiter unten dokumentierte16×16-Korrektur ist
damit historisch. Sounds/Animationen des Godot-Standes von `main` sind übernommen;
Tür und Treppe verwenden Schwarzblenden mit jeweils passendem Sound.

**One-sentence pitch:** Du kämpfst dich alleine oder gemeinsam mit bis zu vier Spielern in separaten Clients per Twin-Stick-Schießen durch Pixel-Dungeon-Räume und baust aus Raum-Belohnungen einen starken Build.

**Scope-Änderung vom 24.10.2026:** Der ursprüngliche Entwurf des Projektinhabers
war ein Einzelspieler-MVP und schloss Multiplayer aus (Git-Ausgangsstand
`e620468`). Die aktuelle Nutzeranforderung ergänzt Multiplayer und Pixel-Art.
Die folgenden technischen und spielmechanischen Vorschläge sind als solche
markiert; sie sind keine nachträglichen Aussagen über die Absichten des Bruders.

**Engine-Korrektur am 24.10.2026:** Der Nutzer möchte ausdrücklich **Godot statt
Unity**. Der Unity-Download wurde gestoppt. Entwicklungsbasis: Godot 4.7.2,
GDScript, Compatibility-Renderer und ENet für getrennte Spielclients.

**Präzisierung im selben Auftrag:** Der Nutzer begrenzt den aktuellen Stand auf
**maximal vier Gesamtspieler** zugunsten klar lesbarer Kämpfe. Acht Spieler sind
lediglich eine spätere Ausbauoption. Verbindliche visuelle Grundlage:
**32×32 Pixel pro Sprite beziehungsweise Tile**, mit klarer Farbtrennung.
Zusätzlich zu Isaac dient Vampire Survivors als Spielgefühl-Referenz; große
Gegnermengen sind kein Ziel des ersten Prototyps. Idle-Animationen für Feuer,
Spieler und Umgebung gehören in einen späteren Polishing-Schritt.

## Core loop
- Einen Raum betreten, die Gegner mit Schüssen und Ausweichen besiegen.
- Nach jedem abgeschlossenen Kampfraum einen Perk beziehungsweise eine
  Item-Belohnung bekommen, die deine Werte oder Schüsse verändert.
- Zum nächsten Raum weitergehen, bis der Boss kommt.

## Player goal & fail state — what "working" looks like
- Du erreichst den Boss am Ende des Stockwerks und besiegst ihn.
- Einzelspieler: Der Lauf endet, wenn deine Herzen auf null fallen.
- Multiplayer-Vorschlag: Der Lauf endet beim Tod des gesamten Teams. Verhalten
  für Wiederbelebung und ausgeschiedene Spieler ist noch zu entscheiden.

## MVP — what must exist to be the game
- Spielfigur mit Bewegung und Twin-Stick-Schießen
- Ein Gegnertyp mit einfacher KI
- Zufällig zusammengesetzter Dungeon aus Raumvorlagen
- Herzen-Leben, Schaden und Tod
- Item-Pickups, die Schuss oder Werte verändern (etwa 5 Stück)
- Ein Boss am Ende des einen Stockwerks
- Separate Clients mit gemeinsamem Spielzustand; zuerst zwei Spieler nachweisen,
  danach vier Gesamtspieler testen (Host zählt mit).
- Früher Verbindungstest vor dem vollständigen Einzelspieler-Spielaufbau.

## Out of scope — not building this
- Meta-Progression und Freischaltungen
- Weitere Themenwelten; der implementierte Abstieg verwendet erneut die Krypta-Bibliothek
- Shop und Spezialräume
- Speichersystem
- Story und Dialoge
- Vorschlag für den ersten Multiplayer-MVP: kein Beitritt während eines Laufs,
  keine automatische Host-Migration, kein Matchmaking oder öffentliches Backend.

## Build order
1. Godot-Projekt und reproduzierbare Entwicklungsbefehle einrichten.
2. Zwei separate Clients mit Host verbinden und Sitzungsgrenzen prüfen.
3. Bewegung, Schießen, Gegner und Schaden gemeinsam in einem Raum prüfen.
4. Raumgenerator und serverseitig vergebene Raum-Perks ergänzen.
5. Ein Stockwerk mit etwa fünf Perks und Boss vollständig spielbar machen.
6. Vier Gesamtspieler auf Lesbarkeit sowie unter Latenz und Paketverlust testen.
7. Feuer-, Charakter- und Umgebungsanimationen auf dem 32×32-Raster polieren.

## Multiplayer — bestätigtes Ziel und Vorschläge

- **Bestätigt:** eigenständige Clients, gemeinsames Dungeon-Spiel, aktuell maximal
  vier Gesamtspieler. Eine Erweiterung auf acht wird gegebenenfalls später bewertet.
- **Technischer Vorschlag:** Ein Host spielt selbst und entscheidet über
  kritischen Spielzustand; Godots High-Level-Multiplayer-API und ENet.
- **Spielregel-Vorschlag:** Jeder Spieler erhält pro abgeschlossenem Kampfraum
  genau eine persönliche Perk-Auswahl; kein Konkurrenzkampf um denselben Drop.
- **Raumwechsel-Vorschlag:** Das Team bleibt im selben Raum und wechselt erst
  nach gemeinsamer Bereitschaft. Kein getrenntes Erkunden im ersten MVP.
- **Verbindungsvorschlag:** Erst localhost/LAN, anschließend Internet-Verbindung
  über UDP-Portfreigabe, VPN oder einen separat zu untersuchenden Relay-Dienst.
- Implementierter Prototyp: Host mit bis zu drei Clients, persönliche
  Perkauswahl, gemeinsame Freigabe der Erkundung und ein aus Vorlagen erzeugter
  Zehn-Raum-Lauf mit Boss10. Die damaligen Vorschläge oben sind historische Einordnung;
  Nachweise und offene Punkte stehen im Entwicklungsplan.

Ausführliche Bestandsaufnahme: [Projektanalyse](../docs/PROJECT-REVIEW.de.md).
Umsetzung und Abnahmekriterien: [Entwicklungsplan](../production/development-plan.md).

---
**Who it's for / what they feel:** Spieler, die kurze Läufe lieben und bei jedem Fund denken „was passiert, wenn ich das kombiniere?“.

**Art & audio direction:** 2D-Pixel-Art mit 32×32-Sprites/Tiles gemäß neuer
Nutzeranforderung, Nearest-Filter ohne Glättung und trockene Soundeffekte.
Spielerfarben, Feinde und Projektile müssen bei vier Teilnehmern unterscheidbar
bleiben. Der ursprüngliche Entwurf nannte einen düsteren Cartoon-Look; die
Pixel-Art-Präzisierung ersetzt diese lose Vorgabe. Ausführliche Idle-Animationen
und weitere Umgebungsdetails folgen beim Polishing.

**Reference game:** The Binding of Isaac. Der MVP übernimmt nur den Kern: Raum-Roguelike mit Twin-Stick-Schießen und Item-Builds, ohne die Meta-Ebene.

## Verbindliche Fortschreibung vom 25.10.2026

Die jüngste Nutzerkorrektur ersetzt die oben historisch genannte 32×32-Vorgabe
durch **16×16** für Tile-Raster und Figurenquellen. Die gelieferten vier
Dungeon-Atlanten sowie UI-, Item- und Animationssheets bestimmen den Grafikstil:
sichtbare Wandoberkanten und senkrechte Flächen für räumliche Tiefe, helle
Böden, dunkle Konturen, Herzen-HUD, animiertes Feuer und Treffer-Effekte.

Der Nutzer erweitert auch den ursprünglichen Umfang „ein Stockwerk“: Nach
Kampf und persönlicher Belohnung bleibt die Ebene frei begehbar. Gesäuberte
Räume dürfen rückwärts besucht werden. Der gemeinsame Raumwechsel wird an
einer passenden Tür mit E ausgelöst; nach dem Boss geht es über eine separate
Innentreppe in die nächste erzeugte Ebene. Perks und Lebenszustand bleiben
beim Abstieg erhalten. Neue Ebenen bestehen vorerst aus demselben kleinen
Drei-Raum-Baukasten; zusätzliche Themenwelten sind damit nicht umgesetzt.

HP-Anzeigen, kurzer Hitstun, Rückstoß und Schadensblinken gehören zum aktuellen
Kampf. Vier Gesamtspieler bleiben die Grenze. Diese Fortschreibung geht den
älteren Raster-, Build-order- und Out-of-scope-Aussagen oben vor.
