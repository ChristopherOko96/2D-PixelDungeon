# Game Brief: Basement Run

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

**Stockwerk nach Isaac, Entscheidung vom 25.10.2026 (Projektinhaber):** Ein
Stockwerk hat zufällig 6–10 verzweigte Räume mit Türen; der Boss liegt in der
vom Start entferntesten Sackgasse, dazu ein Schatzraum. Türen bleiben zu, bis
ein Raum geräumt ist; wer durch eine offene Tür geht, nimmt die Gruppe mit.
Perks gibt es im Schatzraum und nach dem Boss. Umsetzung:
[Story 002](../production/epics/dungeon-rooms/story-002-isaac-floor.md).
Als Grafik-Folgeschritt ist das 0x72-Set (16×16, doppelt gezeichnet auf das
32er-Raster) beschlossen.

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
- Mehrere Stockwerke
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
  Perkauswahl, gemeinsames Ready-Gate und ein aus Vorlagen erzeugter
  Drei-Raum-Lauf. Die genannten Spielregeln bleiben Produktvorschläge;
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
