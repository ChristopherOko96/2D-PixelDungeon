# Projektbestandsaufnahme: 2D-PixelDungeon / Basement Run

Stand: 24.10.2026. Untersuchte Ausgangsbasis: Commit `e6204688157dbbb6d10faa7906ace5fa482d016d` auf `main`.
Arbeitsbranch: `codex/development-environment-plan`.
Diese Bestandsaufnahme trennt vorhandene Festlegungen, deinen neuen Auftrag und vorgeschlagene Spielregeln.
**Aktuelle Engine-Vorgabe:** Du hast anschließend ausdrücklich Godot statt Unity gewählt.
Der neue Entwicklungsstand verwendet deshalb Godot 4.7.2 und GDScript; Unity bleibt nur als historischer Ausgangsbefund dokumentiert.
**Aktuelle Größen- und Grafikvorgabe:** maximal vier Spieler, acht lediglich als spätere Option; echte Pixel-Art-Quelldateien mit 32 × 32 Pixeln.

## Was dein Bruder bisher beschrieben hat

Der vorhandene Spielbrief nennt das Spiel **Basement Run**: ein kurzes Raum-Roguelike nach dem Vorbild von **The Binding of Isaac**.
Man betritt einen Raum, besiegt Gegner durch Twin-Stick-Schießen und Ausweichen, sammelt eine Belohnung ein und geht weiter zum Boss.
Items verändern Werte oder Schüsse; ihre Kombination soll von Lauf zu Lauf unterschiedliche Builds erzeugen.
Ein Lauf endet bei null Herzen, anschließend beginnt ein neuer Lauf.

Der ursprüngliche MVP umfasst:

- eine Spielfigur mit Bewegung und Twin-Stick-Schießen;
- einen Gegnertyp mit einfacher KI;
- einen zufällig aus Vorlagen zusammengesetzten Dungeon;
- Herzen, Schaden und Tod;
- ungefähr fünf Items, die Werte oder Schüsse verändern;
- einen Boss am Ende eines einzigen Stockwerks.

Die ursprüngliche Baufolge lautet: Bewegung/Schießen → ein Kampfraum → Raumgenerator → Items → Boss.
Meta-Progression, weitere Stockwerke, Shops, Spezialräume, Speichern sowie Story und Dialoge sind ausdrücklich ausgeschlossen.
**Auch Multiplayer war ausdrücklich ausgeschlossen.** Das ist der wichtigste Unterschied zu deinem Auftrag.
Der visuelle Vorschlag lautete „düsterer Cartoon-Look in 2D“ mit einfachen Sprites und trockenen Soundeffekten.
Pixel-Art wurde dort nicht verbindlich definiert.

Quelle: [Spielbrief](../design/game-brief.md).
Da der Branch diesen Brief an den neuen Auftrag anpassen kann, ist die ursprüngliche Fassung zusätzlich über den
[Spielbrief im Ausgangscommit](https://github.com/ChristopherOko96/2D-PixelDungeon/blob/e6204688157dbbb6d10faa7906ace5fa482d016d/design/game-brief.md) nachvollziehbar.
Das beschreibt die dokumentierte Absicht; weitere persönliche Vorstellungen deines Bruders lassen sich daraus nicht ableiten.

## Was im Repository tatsächlich vorhanden war

Der Ausgangsstand enthält ein umfangreiches **Claude Code Game Studios**-Gerüst mit Rollen, Arbeitsabläufen, Regeln und Vorlagen.
Diese Menge an Dokumentation ist noch kein entsprechend umfangreicher Spielprototyp.
Auf der untersuchten Basis fehlen `Assets/`, `Packages/` und `ProjectSettings/`; ein importierbares Unity-Spielprojekt ist dort noch nicht angelegt.
`src/` enthält lediglich die lokale Anleitung und eine Platzhalterdatei.
`production/stage.txt` und `project.yaml` führen den Stand als `Concept`.

Im ursprünglichen Stand waren Unity 6.3 LTS, C#, URP mit 2D Renderer und Unity Physics 2D festgelegt.
`project.yaml` ist die primäre Konfiguration; Build-, Test- und Smoke-Befehle waren dort noch Platzhalter.
Die ergänzenden technischen Präferenzen nennen PC als Ziel, Tastatur/Maus mit WASD und Maus-Zielen sowie Gamepad als sekundäre Eingabe.
60 FPS sind vorgesehen; 300 Draw Calls und 1 GB Speicher sind dort vorgeschlagene Budgets, keine gemessenen Ergebnisse.

Quellen: [Projektkonfiguration](../project.yaml), [Studio-Konfiguration](../CLAUDE.md),
[technische Präferenzen](../.claude/docs/technical-preferences.md), [Quellordner-Anleitung](../src/CLAUDE.md),
[Projektphase](../production/stage.txt).

## Dein Auftrag vom 24.10.2026

Dein Auftrag erweitert den vorhandenen Entwurf um folgende Rahmenbedingungen:

| Bereich | Neuer Zielrahmen |
| --- | --- |
| Engine | Godot statt Unity; Entwicklungsbasis Godot 4.7.2 / GDScript |
| Darstellung | 2D-Pixel-Dungeon mit Isaac als spielerischer Referenz; echte 32 × 32-Pixel-Quellsprites |
| Mehrspieler | Getrennte Spielclients verbinden sich zu einer gemeinsamen Sitzung |
| Spielerzahl | Maximal vier Teilnehmer inklusive Host; acht bleiben eine spätere Option |
| Räume und Builds | Belohnungen beziehungsweise Perks im Raumfortschritt sind ein Kernbestandteil |
| Vorbereitung | Bestehende Dokumentation verstehen, Entwicklungsumgebung aufbauen und Entwicklung planen |
| Zusammenarbeit | Auf eigenem Branch arbeiten und später eine Zusammenführung prüfen |

„Bis zu acht“ war der ursprüngliche Auftrag und wurde anschließend ausdrücklich auf **maximal vier** reduziert.
**Aktuelle Abnahme:** zunächst zwei getrennte Clients mit gemeinsamem Gameplay, danach ein Host und drei Clients sowie die Ablehnung eines fünften Teilnehmers.
Eine spätere Erweiterung auf acht erfordert eine neue Entscheidung und eigene Tests; sie ist kein aktuelles Leistungsversprechen.
Die ursprüngliche Einzelspieler-Abgrenzung ist damit überholt; neue Multiplayer-Regeln müssen ausdrücklich ergänzt werden.

## Technischer Vorschlag für den ersten spielbaren Abschnitt

**Aktuelle technische Richtung:** Godot 4.7.2 mit GDScript und dem eingebauten ENet-Transport für getrennte Clients verwenden.
Ein Spieler startet einen Host, der gleichzeitig Server und eigener Spielclient ist.
Die weiteren Teilnehmer starten jeweils einen separaten Client und verbinden sich zunächst lokal oder im LAN.
Eine dedizierte Serveranwendung kann später dieselben Zuständigkeiten übernehmen, ist für diesen ersten Nachweis nicht nötig.

Der Host entscheidet über Dungeon-Seed, Gegner, Treffer, Schaden, Lebenspunkte, Belohnungen und Raumwechsel.
Clients senden Eingabeabsichten; sie bestimmen weder ihren Schaden noch ihre erhaltenen Perks selbst.
Lokale Darstellung, Eingaberückmeldung und gegebenenfalls Bewegungsvorhersage müssen mit dem bestätigten Zustand abgeglichen werden.
Diese Zuständigkeiten sollten vor Combat und Items feststehen, damit Einzelspieler-Code später nicht umfassend umgebaut werden muss.

Für den Nachweis gehören dazu: Spielerlimit inklusive Host, Versionsprüfung, ungültige Eingaben, Verbindungsabbruch und sauberes Verlassen einer Sitzung.
Internet-Lobbys, Relay, Konten und automatische Host-Migration sind gesonderte Arbeitspakete.
Eine erfolgreiche Verbindung über `127.0.0.1` beweist noch keine Verbindung zwischen zwei Rechnern oder über das Internet.

Quellen für den aktuellen Ansatz: [Godot-Netzwerkreferenz](engine-reference/godot/modules/networking.md),
[Netzwerkregeln](../.claude/rules/network-code.md), [Netzwerk-Rollenbeschreibung](../.claude/agents/network-programmer.md).
Die Referenz enthält illustrative Codebeispiele; Paketversionen und verwendete APIs sind bei der Implementierung gesondert zu prüfen.
Sie ersetzt weder Eingabevalidierung noch einen echten Mehrclient-Test.
Der zuvor erwogene Ansatz mit Unity Netcode for GameObjects / Unity Transport ist durch deine Godot-Vorgabe abgelöst.

## Offene Spielregeln mit vorgeschlagenen Startwerten

Die folgenden Antworten sind **Vorschläge**, keine bereits bestätigten Entscheidungen deines Bruders.
Sie sollen den ersten spielbaren Abschnitt eindeutig und später veränderbar machen.

| Offene Frage | Vorgeschlagene Regel für den ersten Abschnitt |
| --- | --- |
| Koop oder gegeneinander? | Gemeinsamer Koop-Lauf gegen Gegner; kein PvP. |
| Wie entstehen Raum-Perks? | Nach jedem abgeschlossenen Kampfraum erhält jeder Spieler eine eigene Perk-Auswahl. |
| Wer besitzt einen Perk? | Der auswählende Spieler; keine umkämpften gemeinsamen Drops im ersten Abschnitt. |
| Wie wird gewechselt? | Das Team bleibt im selben Raum; nach Raumabschluss und Auswahlphase erfolgt der gemeinsame Wechsel. |
| Was bedeutet Tod? | Ausgeschiedene Spieler warten; nächster Raum belebt mit halben maximalen LP wieder. Bei vollständigem Team-Aus endet der Lauf. |
| Was passiert bei Host-Verlust? | Sitzung endet mit verständlicher Meldung; kein stiller Weiterlauf oder automatische Migration. |
| Dürfen Spieler später beitreten? | Beitritt zunächst nur in der Lobby; laufende Runs bleiben geschlossen. |
| Wie werden vier Spieler lesbar? | Eigene Kamera pro Client, vier unterscheidbare Figurenfarben und lesbare Schüsse; Lesbarkeit mit vier Spielern prüfen. |
| Wie skaliert der Schwierigkeitsgrad? | Eine datenbasierte Skalierung anhand aktiver Teilnehmer; konkrete Formeln nach Mehrspieler-Playtests festlegen. |
| Was heißt Pixel-Art konkret? | Tatsächliche 32 × 32-PNGs, begrenzte Palette und Nearest-Filter; Spieler und Boden nativ 1×, Boss bewusst ganzzahlig 2×. |

Vor einem größeren Content-Ausbau sollten insbesondere Perk-Verteilung, Tod/Wiederbelebung und Raumwechsel gemeinsam festgelegt werden.
Die Aussage „Perks in jedem Raum“ wird hier vorläufig als Belohnung **nach Abschluss eines Kampfraums** verstanden.
Ob auch Start-, Boss- oder spätere Spezialräume eine Auswahl anbieten, bleibt offen.

## Konsequenzen für Entwicklungsumgebung und Ablage

Mit der neuen Godot-Vorgabe ist `project.godot` der Projekteinstieg; GDScript und Szenen liegen unter `src/`.
Godot-Tests können unter `tests/` liegen; `studio-tests/` bleibt davon getrennt.
Für den historischen Unity-Entwurf wären dagegen `Assets/` und `Assets/Tests/` erforderlich gewesen.
Editor, Rendering und Startbefehle brauchen reproduzierbare Versionen; der neue Stand ist auf Godot 4.7.2 ausgerichtet.
Godot-Szenen und Ressourcen müssen gültige Referenzen haben; vom Editor erzeugte UIDs werden zusammen mit ihren Dateien geführt.
Lokale Installationspfade gehören in lokale Konfiguration und nicht als Voraussetzung in fremde Arbeitskopien.
Die acht ursprünglichen 32 × 32-Quellsprites liegen unter `assets/sprites/` und werden vom Renderer tatsächlich verwendet.
Sie umfassen vier Spielerfarben, Slime, Boss, Fackel und Steinboden; sie sind keine Referenzen auf entfernte Assets.
Der reproduzierbare [Godot-Generator](../scripts/generate_pixel_assets.gd) zeichnet die PNGs direkt auf ein 32 × 32-Bildraster.
Figuren-Idle, mehr Fackelframes und zusätzliche Umgebungsanimationen bleiben spätere Politur; die vorhandene Fackelbeleuchtung flackert bereits.

Quellen: [Code-Root-Auflösung](../.claude/docs/code-root-resolution.md),
[Ordnerstruktur](../.claude/docs/directory-structure.md), [Szenenregeln](../.claude/rules/scene-files.md).
Die praktische Einrichtung wird im [Entwicklungsleitfaden](DEVELOPMENT.de.md) beschrieben;
die Schritte und Abnahmekriterien stehen im [Entwicklungsplan](../production/development-plan.md).

Der eigene Branch hält Änderungen von `main` getrennt und kann später per Pull Request zusammengeführt werden.
Ein Branch ist keine separate GitHub-Fork-Kopie; diese Unterscheidung ist für die vereinbarte Zusammenarbeit relevant.
Diese Bestandsaufnahme selbst erstellt weder einen Fork noch einen Merge.

## Umfang und Grenzen der Dokumentenprüfung

Im Ausgangscommit wurden **alle 568 Markdown-Dateien** erfasst und ihre vollständigen Inhalte nach Projektaussagen, Zuständigkeiten und relevanten Regeln durchsucht.
Die maßgeblichen Design-, Konfigurations-, Unity- und Netzwerkdokumente wurden vertieft gelesen; für den Engine-Wechsel kamen die relevanten Godot-Referenzen hinzu.
Das bedeutet nicht, dass jeder Absatz sämtlicher generischer Vorlagen und anderer Engine-Rollen semantisch im Detail geprüft wurde.

| Gruppe | Markdown-Dateien | Bedeutung |
| --- | ---: | --- |
| `.claude/skills/` | 186 | Wiederverwendbare Studio-Befehle und deren Referenzen |
| `.claude/docs/`, `.claude/agents/`, `.claude/rules/` | 191 | Studio-Anleitungen, Rollen, Regeln und Vorlagen |
| `studio-tests/` sowie Godot-/Unreal-Referenzen | 157 | Tests des Studios und Dokumentation anderer Engines |
| Übrige Root-, Design-, Unity- und Projektdateien | 34 | Darunter die tatsächlich projektspezifischen Festlegungen |
| **Gesamt** | **568** | Ausgangsbestand vor den neuen Dokumenten |

Die Zuordnung jeder Datei und der geprüfte Ausgangsbestand stehen im [Markdown-Inventar](MARKDOWN-INVENTORY.md).
Besonders wichtig: `studio-tests/` prüft Studio-Skills und Agenten; daraus folgt kein getestetes Gameplay.
Einträge über Godot, Unreal, Economy, Live-Ops oder Erzählung sind ebenfalls kein Beleg für geplante Spielfeatures.

Diese Bestandsaufnahme dokumentiert Befunde und Vorschläge. Sie behauptet keinen erfolgreichen Spiel-Export,
Gameplay-Test oder Test mit zwei beziehungsweise vier Teilnehmern.
Der tatsächliche Einrichtungs- und Prüfstand muss separat im Entwicklungsleitfaden festgehalten werden.
