# Story 004: Boss-Angriffe mit Ultimate, EXP, Level und Spieler-HUD

> **Epic**: Dungeon aus Raumvorlagen
> **Status**: In Progress
> **Layer**: Feature + Presentation
> **Type**: Visual/Feel + Logic
> **Estimate**: L
> **Last Updated**: 2026-10-26

## Context

Vorgabe des Projektinhabers vom 25.10.2026 (Boss-Animationen, EXP-Orbs, Levelsystem,
Stat-Anzeige, Herzen, einheitliches HUD), ergänzt um: „Der Boss soll eine ultimative
Fähigkeit haben, einen heftigen Strahl, dem man ausweichen soll. Die normalen Angriffe
sollen auch schwer auszuweichen sein.“

**Architektur** wie in Story 003: Der Host simuliert, die Clients zeichnen alles in
`_draw()`. Es gibt keine Szene pro Gegner. Deshalb gibt es weder AnimationPlayer noch
GPUParticles2D pro Boss. Die Phasen kommen aus dem Snapshot (`move`, `attack`,
`attack_p`, Zähler `attacks`/`impacts`) und werden in `src/vfx/feedback.gd` animiert:
Feder-Squash, eigene Posen, Partikel-Pool, Shake und Hitstop. Das Projekt hat nur
einen Boss (Big Demon). „Jeder Boss eigene Animationen“ heißt hier: Jede seiner fünf
Attacken hat eigene Animationen.

## Acceptance Criteria

- [x] Boss-Angriffsfolge mit eigener Vorbereitung, Ausführung und Erholung pro Angriff:
  - **Salve:** Der Boss holt Luft, bläht sich auf, das Maul glüht, Zielstrahlen erscheinen. Er schießt einen Fächer aus 7 Schüssen auf den **vorausberechneten** Ort, danach 6 schnellere Schüsse in die Lücken.
  - **Doppelring:** Er duckt sich zitternd, Warnringe erscheinen. Nach einem langsamen Ring holt ein schneller, versetzter Ring diesen ein.
  - **Ansturm:** Er bäumt sich auf und scharrt Staub. Eine Warnspur mit Pfeilen blinkt, sobald das Ziel feststeht. Beim Sturm gibt es Streckung und Nachbilder. Prallt er gegen eine Wand, splittern Trümmer, danach taumelt er benommen.
  - **Sprung:** Er geht tief in die Hocke, springt hoch und schrumpft dabei zum Schatten. Eine Zielmarke mit sich schließendem Ring zeigt die Landung. Die Landung macht Flächenschaden (ein ganzes Herz), schleudert einen Trümmerring, erzeugt einen Riss, starken Shake und Hitstop. In der Luft ist er unverwundbar.
- [x] **Ultimate-Strahl:**
  - Er kommt erstmals unter 60 % Leben, danach alle 5 Angriffe.
  - Während er Energie sammelt, wird der Raum dunkler, Funken strömen ins Maul und ein Warnstrahl folgt dem Ziel. Kurz vor dem Schuss bleibt der Warnstrahl stehen und blinkt.
  - Der Strahl brennt 2,4 s. Er hält zuerst 0,45 s die angekündigte Linie und dreht sich dann nie schneller als 60 % dessen, was ein seitlich laufender Spieler auf seiner Entfernung schafft, insgesamt höchstens 0,2 rad. Seitlich laufen weicht ihm also immer aus, auch weit weg an der Wand.
  - Er trifft jeden Spieler höchstens einmal (ein ganzes Herz) und wird von Wänden und Deckung gestoppt.
  - Danach sackt der Boss erschöpft zusammen. Das ist das Angriffsfenster.
- [x] Boss-Idle, -Bewegung (schwerer Stampfschritt), -Treffer und -Tod passen zu seiner Masse. Beim Tod zittert er erst, dann platzt er in mehreren Stößen. Animation und Projektile kommen aus demselben Host-Zeitpunkt.
- [x] **EXP-Orbs:**
  - Gegner lassen genau einmal Orbs fallen: Kobold 5, Schamane 10, Boss 100 (`balance.json: exp`). Die Werte pro Gegnertyp sind konfigurierbar.
  - Die Orbs springen heraus, wippen und funkeln. Zum Spieler werden sie ab 110 px gezogen, nach dem Raumkampf aus dem ganzen Raum.
  - Bei Kontakt wird die EXP sofort gutgeschrieben und es gibt einen Partikelstoß.
  - Orbs, die beim Raumwechsel noch liegen, bekommt der nächste lebende Spieler.
  - Glück erhöht die Chance auf zusätzliche EXP.
- [x] **Level:**
  - Die benötigte EXP ist 100 × Level^1,5. Überschuss zählt fürs nächste Level, auch mehrere Aufstiege auf einmal werden verarbeitet.
  - Beim Aufstieg gibt es eine Lichtsäule, „LEVEL UP!“, eine Fanfare, Partikel und eine kleine Heilung.
  - Upgrades hängen an einer Stelle (`_on_level_up`) ein.
- [x] **Zentrale Werte (`src/player/progression.gd`):** Schaden, Angriffstempo, Bewegung, Reichweite, Schusstempo, Glück und Level kommen aus denselben Spielerwerten, mit denen der Host rechnet. Neue Perks: Fernblick, Pfeilwind, Glücksklee.
- [x] **HUD (`src/ui/hud.gd`, CanvasLayer, vom Bildschirmwackeln unberührt):**
  - **Herzen oben links:** voll = 2 HP, halb = 1 HP, leer = verlorene Kapazität (0x72-Herzen). Ab 8 Herzen beginnt eine neue Reihe. Bei Schaden blinkt das Herz, bei Heilung gibt es ein grünes Plus, bei wenig HP schlägt es. Überheilung ist begrenzt.
  - **Oben:** Level, EXP-Balken und Zahlen.
  - **Rechte Spalte:** Werte mit Pixel-Icons. Änderungen leuchten mit ▲ oder ▼ auf.
  - Die Perk-Auswahl liegt jetzt über dem Raum, damit die Werte immer sichtbar bleiben.

## Out of Scope / offen

- Nur ein Boss im Spiel. Weitere Bosse brauchen eigene Sprites. Für neue Boss-Typen fehlen konkret: Angriffs- und Sprungbilder, z. B. `ogre`- oder `big_zombie`-Frames aus 0x72 (vorhanden, aber ohne Angriffsframes).
- Bewusst keine Shader-Instanzen pro Gegner (siehe Story 003).
- Level-Up-Auswahl (Karten) ist vorbereitet, aber nicht gebaut.
- Die Balance (Boss 160 HP, Schadenswerte, EXP-Kurve) ist ein erster Stand und muss angespielt werden.

## Test Evidence

Ausgeführt am 26.10.2026 (Godot 4.7.2):
- `GAME_RULES checked=97 failures=0` (inkl. „seitlich laufen weicht dem Strahl aus“ auf 130/300/560 px; Gegenprobe mit altem, schnell folgendem Strahl schlägt fehl): alle Boss-Angriffe kommen vor; die Salve führt vor; der Sprung macht unverwundbar, landet auf der Marke und verursacht Schaden; der Ansturm prallt an der Wand ab und lässt den Boss betäubt stehen; der Strahl ist erst ab der HP-Schwelle frei, trifft auf der Linie genau einmal, verschont daneben, endet an der Wand, dreht langsam und wiederholt sich selten; EXP fällt genau einmal, Magnet, Gutschrift, mehrfacher Levelaufstieg, Heilung, Snapshot-Werte, Raumwechsel; nach einem Team-Wipe bleibt kein Strahl stehen.
- `PROGRESSION checked=48 failures=0`: Formel, Überschuss, Aufteilung, Werte, Herzen (3/6 → voll, halb, leer), neue Reihe, HUD-Blinken.
- `FEEDBACK checked=27 failures=0`: unterschiedliche Vorbereitung pro Angriff, Sprunghöhe, Landungs-Shake und -Hitstop, Strahl-Funken, Nachbilder, Orb- und Level-Up-Effekte.
- `DUNGEON_INTEGRATION 26`, `DUNGEON_GENERATOR 9508`, alle ohne Fehler.
- Netzwerklauf mit zwei echten Prozessen bis zum Bosssieg, Seed 24680 (7 Räume) und 84329 (10 Räume), beide PASS. Die Logs enthalten `LEVEL_UP`. Lobby mit 4 Spielern: PASS.
- Godot Movie Maker, Solo-Bot gegen den Boss (`--debug-room boss`): Bilder 01–11 in `production/qa/evidence/story-004-boss-exp-hud/`.
- Beim Durchsehen gefunden und behoben: (1) Nach einem Team-Wipe blieb der Strahl dauerhaft im Bild. (2) Der Strahl traf mehrfach und tötete einen stehenden Spieler. (3) Orbs blieben nach dem Bosssieg liegen. (4) Bei 70 HP starb der Boss, bevor er Ansturm und Sprung zeigte; jetzt hat er 160 HP.

**Status**: Bildbelege vorhanden; Abnahme des Spielgefühls und der Balance durch den Projektinhaber steht aus.
