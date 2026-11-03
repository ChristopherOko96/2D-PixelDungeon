# Fluchkoloss, Totenbrut und Knochenball — 02.11.2026

Aktuelle Umsetzung der Nutzerkorrektur: Ein normaler Gegner-Tod in der echten
eigenen Ulti-Giftpfütze ruft den Fluchkoloss. Die frühere Diener-Opfer-Regel ist
ersetzt. Pro Pfütze einmal, maximal ein lebender Koloss pro Besitzer. Die
Skelette der Ulti platzen sofort; das normale Seuchenfeld behält seine Läufer.

5: Fluchwelle mit 0,65 s Vorbereitung, acht Meter Reichweite, Sichtprüfung,
Schwächung, Verwundbarkeit und Verfall. 6: Totenbrut mit 0,8 s Vorbereitung,
sechs Meter Reichweite, bis zu drei echte eigene Leichen, maximal drei lebende
kleine Fluchmonster für acht Sekunden. Kein kostenloses Auffüllen ohne Leichen,
keine doppelt bezahlte Leiche. Tote Zaubernde brechen ihre Vorbereitung ab.
Sekundär-/Begleiter-Tötungen erzeugen keine endlose Leichenarmee.

Alle Monster verwenden dieselben acht bereits freigegebenen CurseSpirit-Teile,
echte Körperteil-HP und RigRenderer. Koloss 3×, Brut 1×; getrennte Klauen,
Kiefer und dreiteiliger Schweif, aufsteigende Entstehung und eigene Befehlsposen.
Knochenball: sieben gecachte Schädel-/Brustkorb-/Beinknochen-Teile im echten
Elternknochen-Solver, 0,65 s bezahlte Ladephase, Abschuss, Knochenspur, Splash.
Die vorhandene schrittweise Wand-/Körperteilprüfung beendet den Flug am ersten
Kontakt. Keine neue Bildgenerierung, keine Änderung der Raum-/Heldenkunst.

## Tatsächliche Prüfung

- `Logs/curse-monster-evolution-red.log`: zuerst 7 Fehler / 29 Prüfungen gesehen.
- `Logs/curse-monster-evolution-final.log`: 57 / 0, tatsächliche Game-Pfade,
  Leichenlimit, Wandprüfung, fremde Besitzer, konsumierte/abgelaufene Quellen,
  Boss-/Summon-/Sekundärschutz, tote Zaubernde, bezahlte Ladung und Abbruch.
- `Logs/curse-evolution-rig-final.log`: 49 / 0; echte Quelltexturen, Eltern,
  Klauen-/Kieferbewegung, Miniatur, sieben Knochenball-Gelenke, Kontinuität.
- `Logs/curse-evolution-story.log`: 42 / 0 über Hölle und Frost.
- `Logs/curse-evolution-regression.log`: 19 / 0, bestehende Fluchmechanik.
- `Logs/curse-evolution-talent-catalog.log`: 360 / 0, vorhandener Talentkatalog.
- `Logs/curse-evolution-companions.log`: 42 / 0, bestehende Begleiter-Befehle.
- `Logs/curse-evolution-protocol.log`: 20 / 0, Sitzungsprüfung. Zusammen
  **589 erfolgreiche fokussierte Prüfungen**, ohne doppelt gezählte Einstiegstests.
- Zwei echte lokale ENet-Prozesse:
  `Logs/necro-blood/20261102-203800-fdf0ec56/summary.json`, beide bestanden.
  Normale Client-Eingaben 1, R, 5, 6; beide Peers sehen Ladephase, Koloss,
  Fluchwelle und Fluchbrut. Vorhandene Diener-/Blut-/Strahlprüfungen ebenfalls
  bestanden. Kontrollierte Gegner-Tode sind Fixtures, kein erspielter Lauf.

Keine finalen SCRIPT ERROR/Assertions. Die bereits bekannte Game-Fixture
meldet beim Beenden teilweise sechs ObjectDB-/zwei Ressourcen-Reste.
Loopback ist kein Zwei-PC-LAN-, WAN-, Kampagnen- oder Leistungstest.

## Sichtbare Originalaufnahmen

`Logs/curse-evolution-gpu.log` nimmt sechs geänderte Fälle direkt mit dem
Godot-GPU-Renderer auf; `Logs/curse-boneball-final-gpu.log` ersetzt anschließend
den Knochenball mit der nach Sichtkontrolle korrigierten Knochenauswahl.
640×360 PNG, 30 Bilder/s, unveränderter Ausschnitt aus dem echten 1280×720-Bild.
Keine Videokompression, keine reduzierte Palette, kein Resize. Quellen unter
`production/qa/evidence/necromancer-catalog-hq/`.

Die gemeinsame Ansicht `Nekromant-Angriffe.cmd` enthält jetzt 40 Aufnahmen und
21 passive Talente. Browserprüfung: alle 40 laden, Play/Pause/Einzelschritt,
320/360/736/1360 px ohne Überlauf, keine JS-Ausnahmen, Inline-PNGs bytegleich.
`output/necromancer-catalog/original-browser-review.json` enthält das Ergebnis.

Regelsatz 23, Protokoll 4, Nekromantenregelschema 7. Werte und Testanleitung:
`docs/NEKROMANT-DIENER-FLUCH.de.md`. Keine Nutzerabnahme vorweggenommen.
