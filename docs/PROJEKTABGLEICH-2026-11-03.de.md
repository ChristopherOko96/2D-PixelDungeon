# Projektabgleich vom 03.11.2026

Reiner Code- und Datenvergleich. Keine Tests, Spielstarts, Imports oder Benchmarks
ausgeführt. Bestehende QA-Dateien und Commit-Texte sind historische Angaben,
keine neue Prüfung durch diesen Abgleich. Keine Codeänderungen, kein Merge,
Commit oder Push.

Folgearbeit am 03.11.2026: Der Nutzer hat anschließend die Entkopplung von
Simulation und Render-FPS beauftragt. Der lokale Umbau und sein noch ungeprüfter
Laufzeitstand sind in [Fester Simulationstakt](FESTER-SIMULATIONSTAKT.de.md)
festgehalten. Der folgende Vergleich beschreibt weiterhin den Stand vor diesem Umbau.

## GitHub und lokaler Stand

Die GitHub-Anbindung bestätigt für `main` und `codex_v2` denselben Commit:
`cb145387b1825d2f4db63b64a4d32a9363431fda`, vom 02.11.2026,
23:22:36 Uhr Europe/Berlin. Der lokale Checkout auf `codex_v2` enthält diesen
Stand bereits. Gegenüber dem zuletzt hier geprüften `a7c5847d` sind drei
Commits hinzugekommen; 32 Dateien haben sich geändert.

Ein direkter `git fetch origin` scheiterte am Verbindungsaufbau
(`getaddrinfo() thread failed to start`). Der aktuelle Branchstand wurde
anschließend über die GitHub-API bestätigt; ein Pull war nicht erforderlich.

## Änderungen seit dem letzten Review

| Commit | Änderung | Bewertung aus dem Code |
| --- | --- | --- |
| `979d7b9a` | Magier-Basisgeschosse und Projektiltalente landen am Mausziel, innerhalb ihrer Reichweite; Boden-Effekte und Zielmarkierung ergänzt. | Sinnvolle Verbesserung der Kontrolle über Elementeffekte. Treffer- und Wandbehandlung sind noch nicht überall vereinheitlicht. |
| `733786a4` | Speicher-Slots schreiben in `.tmp`, lesen das Ergebnis zurück und behalten den vorherigen Stand als `.bak`; Laden kann auf das Backup zurückfallen. | Der frühere Befund zum direkten Überschreiben der Slots ist wesentlich verbessert. Das separate Heldenprofil verwendet noch einen anderen Speicherweg. |
| `cb145387` | Größeres Spielerlicht in Krypta und Hölle, geringere Dunkelheit und Randabdunklung in deren Weltpaketen. | Lesbarkeit gezielt datengetrieben angepasst; Frostgruft wurde dabei nicht umgestaltet. Neue Bilder liegen im Repository; keine neue visuelle Abnahme in diesem Review. |

## Lokale Inhalte außerhalb der Commits

- `assets/data/dungeon_rooms.json`: lokal elf statt zehn Vorlagen. Die Vorhalle
  `crypt_01` wurde gestaltet und hat vier Türanschlüsse; `raum_01` / „Neuer Raum 1“
  ist neu (1280 × 832 Welteinheiten). Die anderen Vorlagen nicht als ungeändert
  garantieren: dieser Abgleich ist keine vollständige Raumprüfung.
- `assets/data/audio_music.json`: inhaltlich ist die Menü-Musik von
  `dungeon_ambience` auf `amb_hell_evil_temple` geändert.
- `assets/data/audio_sfx.json`: nach JSON-Vergleich ohne Berücksichtigung
  gleichwertiger Ganzzahl-/Dezimalschreibweisen keine inhaltliche Änderung.
- 1.823 geänderte/unversionierte `.import`-Dateien wurden im Git-Status gezählt;
  ihr Inhalt wurde hier nicht einzeln geprüft.
- Unsere Hinweise in `AGENTS.md`, `docs/WELT-BAUKASTEN.de.md` und die neue
  `docs/STORY-RAUMMODULE.de.md` liegen weiterhin lokal, noch nicht committet.

Diese Inhalte wurden weder überschrieben noch automatisch zusammengeführt.

## Priorisierte Verbesserungen

1. **Gemeinsame Raumvorlagen für die Story-Etagen.** Die Nutzerentscheidung aus
   [STORY-RAUMMODULE.de.md](STORY-RAUMMODULE.de.md) bleibt maßgeblich: gestaltete
   Räume prozedural verbinden, mit denselben Charakteren, Talenten, Items,
   Gegnern, Sounds und Effekten. `world_core.gd` und `world_pack.gd` sind seit
   `a7c5847d` unverändert; der Anschluss der Editor-Räume fehlt weiterhin.
   Zuerst Format, Türanschlüsse, Größenabbildung (Editor 32 / Story 96
   Welteinheiten je Zelle), Raumrollen und Seed-Verhalten festlegen.
2. **Kampfsimulation vom Render-Takt lösen.**
   `src/hell/hell_game.gd:2593` begrenzt `delta` weiterhin auf 0,05 s und holt
   die abgeschnittene Zeit nicht nach. Unter 20 FPS verlangsamt sich dadurch
   die Simulation. Feste Simulationsschritte und getrennte Darstellung vorsehen.
3. **Projektilkontakte gemeinsam auswerten.**
   `hell_game.gd:_update_shots` prüft vielfach nur die Endposition; rigbasierte
   Treffer und `hell_talents.gd:_step_bullets` verwenden teilweise den Flugabschnitt.
   Einheitlich den tatsächlich zurückgelegten Abschnitt und den ersten Kontakt
   behandeln. Bei einem auf das Mausziel verkürzten Schritt auch dessen echten
   Start bewahren, statt ihn als `s.p - s.v * dt` zurückzurechnen.
4. **Profil ebenso zuverlässig wie Slots speichern.**
   `src/progress/profile.gd:178` prüft das Schreiben nicht und entfernt die alte
   Profildatei vor dem Umbenennen der temporären Datei. Einen gemeinsamen
   geprüften Speichermechanismus mit Wiederherstellung für Slots und Profile
   vorsehen; das betrifft den dauerhaften Heldenfortschritt.
5. **Zielanzeige und erreichbaren Aufschlag abstimmen.**
   `hell_game.gd:mage_mark` begrenzt die Entfernung, berücksichtigt aber keine
   Wand auf dem Flugweg. Als UX-Verbesserung den erreichbaren Aufschlag anzeigen
   oder eine blockierte Zielposition erkennbar markieren.

Diese Punkte sind Codebefunde bzw. Empfehlungen, keine neu reproduzierten
Spielfehler. Story-Koop fehlt weiterhin; der ältere ENet-Spielkern in `game.gd`
bleibt getrennt von der Story-Laufzeit. Die Vereinheitlichung der Inhalte
allein wird diesen Koop-Anschluss nicht herstellen.

## Empfohlener nächster Schritt

Den vorhandenen Editor-Raumsatz als Ausgangsmaterial für ein gemeinsames
Raumformat aufnehmen und dessen Abbildung in den Story-Generator ausarbeiten.
Keine feste Custom-Run-Raumfolge und keinen weiteren Spielkern einführen.
Die vorhandenen persönlichen Räume bleiben erhalten. Ausführung oder Tests
sind durch diesen Bericht nicht beauftragt.
