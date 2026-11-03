# Nekromant-Seelenangriffe — 01.11.2026

Auf `codex/port-0x72-onto-main`, zuvor geholtes main b178a185 erhalten.
Keine Veröffentlichung oder Git-Änderung am Remote. „Push Leute“ wird als
Rückstoß der Gegner durch den Ring umgesetzt.

## GPU-Beobachtung

`scripts/capture_necro_soul_attacks.gd` öffnet den normalen Spielrenderer,
einen legalen Level-30-Seele-Build und eine kontrollierte offene Begegnung.
Der echte Start mit 50 Seelen genügt dank eines frühen, regulär vergüteten
Ring-Kills. Drei Gegner haben für diesen Aufbau wenig Leben. Die Fähigkeiten
gehen über normale Eingaben: Ring, gehaltene Lanzenfähigkeit, Seelenblitz.
Kein erspielter Lauf und kein Leistungsbenchmark.

181 Rohbilder über sechs simulierte Sekunden, 30 Bilder/s unter
`output/necro-soul-attacks/game-frames/`; Standbilder `soul-*.png` hier.
`output/necro-soul-attacks/game-preview.gif` zeigt einen 800×530-Ausschnitt;
alle 181 GIF-Bilder wurden wieder dekodiert. Sichtprüfung umfasst breite
Pfütze mit freier Mitte, aufladende Geister, große artikulierte Lanzengeister,
einschlagende Seelenblitze und Seelenverbrauch. Nächste Schritte unten sind
keine Ersetzung der persönlichen Spielgefühl-/Artabnahme.

Aufnahme wiederholen: Godot 4.7.2 mit
`--path . --max-fps 120 --script scripts/capture_necro_soul_attacks.gd` starten.
GIF: Windows PowerShell mit
`-File output/necro-soul-attacks/assemble_game_preview.ps1`.

## Regression und Integration

Die neuen Szenarien wurden vor der Korrektur fehlschlagend beobachtet:
ursprünglicher Stand 12 Prüfungen / 8 Fehler (Ladung, Ringgröße/Rückstoß,
Story-Zielbindung, Deckung und Treffer vor Wand). Danach zusätzlich gezielt
Menüabbruch mit gedrückter Verteidigung und die verzögerte erste Attacke aller
acht Begleiterarten. Die zugehörigen Red-Logs bleiben unter `Logs/` erhalten.

`tests/necro_soul_attacks_test.gd` prüft bezahlte Ladung/Teilladung/Maximalwert,
genau einen Schuss, ignorierte gefälschte Kraft-/Schadenswerte, Tod und
Raum-/Menüabbruch, hohlen Ring und kollisionsgebundenen Rückstoß, stabile
Storykennungen, selbstständige Deckungsaufnahme, ersten Gegner vor einer Wand,
Wandkontakt, erste Attacke und Verfolgung aller acht Begleiterarten.
Ergebnis: **41/0**.

`tests/necro_story_attacks_test.gd` verwendet beide echten Storyszenen:
bezahlte Ladung, tatsächlicher Mobtreffer, eindeutige Gegnerkennung, Stoppen
an einer Kiste und eigenständiges Umrunden/Angreifen durch einen Begleiter.
Ergebnis: **18/0**, aufgeteilt auf Hölle und Frostgruft.

Weitere ausgeführte Regressionen: Talentkampf 361/0 (eine frühere
Durchbohrungsprüfung entfällt bei der nun beim ersten Kontakt endenden Lanze),
Ring 19/0, Seelen/Aggro 60/0, Wächterbefehle 26/0, bestehende Storytalente 36/0,
Protokoll 20/0, Interpolation 57/0, Ringmaterial-Geometrie 18/0, Reliktkarten 30/0.
Dauerhafte Begleiter nach der verkürzten Anfangswartezeit: 39/0. Insgesamt
zwölf fokussierte Suiten mit 725 bestandenen Prüfungen im aktuellen Umfang.
Die Kataloghilfe stellt bei aufladbaren Fähigkeiten einen kurzen Tastentipp dar;
gehaltene Eingaben und Ressourcengrenzen prüft die neue Suite separat.

## Zwei reale Prozesse

`tests/necro_soul_attacks_network_smoke.ps1` bestand mit zwei echten lokalen
ENet-Spielprozessen und regulär zugelassenen Spielern. Host und Client sahen
beide großen Ringe, Ablauf, Schaden sowie bezahlte Aufladung, geladenes
Fluggeschoss und Kontakt-Ereignis. Ergebnis:
`Logs/necro-soul-attacks/20261101-134441-b40fa556/summary.json`.
Regeln 14, Protokoll 4. Kontrollierter Aufbau auf Loopback; kein LAN/WAN-,
Vier-Spieler- oder Lastnachweis.

Die erste zusätzliche Story-/Netzwerkfixture hatte die Lanzen-Voraussetzungen
nicht vollständig verteilt; die reguläre Build-Prüfung entfernte das Talent.
Die korrigierte Fixture erfüllt die bestehenden Freischaltregeln, ohne sie
zu lockern. Bestehende sechs ObjectDB-/zwei Ressourcen-Diagnosen beim Ende
von Game-Fixtures bleiben sichtbar. Der Sandbox-GPU-Lauf kann den persönlichen
Shadercache nicht beschreiben; das verhindert die Darstellung nicht.
