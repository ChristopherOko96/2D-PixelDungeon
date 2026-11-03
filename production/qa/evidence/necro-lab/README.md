# Nekromant-Kampflabor – fokussierte Prüfung

2026-11-02, Godot 4.7.2 Compatibility, lokale Offline-Instanz.

## Automatische Prüfungen

| Prüfung | Ergebnis | Log |
| --- | --- | --- |
| Echter Laborstart, Isolation, drei Zweige/sechs Belegungen, Zielfläche, Autoangriff, Pause, Reset | 22/0 | `Logs/necro-lab-final.log` |
| Unveränderlicher Boden-Snapshot nach Besitzer-/Raumwechsel, echter Worker | 3/0 | `Logs/necro-lab-floor-worker.log` |
| Vorhandene Fluch-/Blutstrahlregeln | 19/0 | `Logs/necro-lab-curse-regression.log` |
| Vorhandene Ringgeometrie/hohle Mitte/Geistersaum | 18/0 | `Logs/necro-lab-ring-shape.log` |
| Zwei überlappende Blutquellen einzeln verbrauchen | 3 Bedingungen erfüllt | `Logs/necro-lab-pool-overlap.log` |

Neuer Labortest zunächst rot: `Logs/necro-lab-red.log`. In den ersten GPU-Aufnahmen trat ein echter `Bad address index` beim Worker-Zugriff auf den Szenenknoten auf (`Logs/necro-lab-gpu.log`). Die gemeinsame Bodenabfrage hält nun kopierte Bodenzellen; finale GPU-Aufnahme ohne `SCRIPT ERROR`: `Logs/necro-lab-gpu-final.log`.

Bekannte Game-Fixture-Diagnose beim Beenden: sechs ObjectDB-Instanzen / zwei Ressourcen verbleiben. Das ist separat von den erfolgreichen Assertions und bedeutet keine vollständige Speicherfreigabe-Abnahme.

## Tatsächliche GPU-Bilder

`scripts/capture_necro_lab.gd` startet das echte Offline-Spiel, setzt kontrollierte Kampfzustände und speichert unveränderte GPU-Viewports mit 1280×720 Pixeln. Keine hochskalierte Konzeptgrafik und kein gespielter Kampagnendurchlauf.

- `01-zielen.png`: platzierte Giftfeld-Vorschau und Blutstrahl-Reichweite.
- `02-fluch-blut.png`: Fluchmonster aus realem Gifttod und Blutverbindungen.
- `03-seelenring.png`: hohle, vollständig aufgebaute Seelen-Bodenfläche mit bestehenden Geister-Rigs.
- `04-diener.png`: Knochenkrieger, zeitlich begrenzte Bogenschützen und echte Blutlachen.

Das Aufnahmeprogramm wartet auf Shape-Worker, Materialaufbau und Texturberechnung. Frühe Bilder zeigten nur Geister, bevor die Materialtextur fertig war; diese Bilder wurden ersetzt. Die Prüfung ist auf das Labor und die betroffenen Regeln beschränkt, ohne neue Netzwerk-, Kampagnen- oder FPS-Aussage.
