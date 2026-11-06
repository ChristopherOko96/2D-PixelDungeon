# Himmelsspeer-Rig: Nachweis 05.11.2026

Arbeitsbranch `codex/port-0x72-onto-main`. Keine neue Bildgenerierung,
kein Commit/Push. Aktueller Ablauf und Schema: `docs/HIMMELSSPEER-RIG.de.md`.

| Prüfung | Ergebnis |
| --- | --- |
| marksman_ultimate_fx_test | 46 Checks, 0 Fehler |
| ranger_vfx_test | 36 Checks, 0 Fehler |
| marksman_rig_test | 9 Checks, 0 Fehler |
| marksman_sprites_test | 72 Checks, 0 Fehler |
| ranger_fields_test | 27 Checks, 0 Fehler |
| Geänderte Skripte und Aufnahmeskripte laden | 9/0 |
| Hölle/Frostgruft: echter bezahlter Lade-/Freigabepfad und Bogensocket | 8 Assertions, 0 Fehler |

190 fokussierte Logik-/Darstellungs-/Hostchecks insgesamt, zusätzlich acht
Story-Assertions. Die fünf positiven Suiten und finalen Aufnahmen enthalten
keine `SCRIPT ERROR`-/Parse-Fehler. Die bekannten Ressourcen-/ObjectDB-/GL-/RID-
Meldungen beim Beenden der Szenen bleiben bestehen; keine Reparaturbehauptung.
Ein Auszug der nicht in Godots Logdatei enthaltenen letzten Stderr-Meldungen
steht separat in `exit-stderr-excerpt.txt`.

## Was geprüft wurde

Neun tatsächliche Quellmasken ohne verlorene oder doppelte Pixel, gecachte
Texturen, Gelenkhierarchie des Kopfes, zwei echte fünfgliedrige Nachlaufketten,
Nachlauf hinter dem Speerende, getrennte ballistische Teile und sichere
Wandebenen auch in Gegen-/Diagonalrichtung. Ladung bricht korrekt ab,
Wiederholungsframes erzeugen keine neuen Partikel, die Partikelrate bei
60/144 Zeichnungen pro Sekunde ist innerhalb eines Teilchens gleich.
Partikelbudget, Raumwechsel und veraltete Bogensockets werden abgefangen.

Die zusätzliche Präsentationszeit ist auf 50 ms gegenüber dem letzten
Hostalter begrenzt. Eine isolierte Negativkontrolle mit dem unbeschränkten
Zeitpfad ließ die beiden Altersprüfungen tatsächlich fehlschlagen
(`spear-unbounded-regression.log`, erwartete 2 Fehler bei damals 45 Checks).
Der Produktionspfad blieb während dieses Gegenversuchs unverändert.

## Aufnahmen und Grenzen

Zwölf rohe 1280×720-GPU-Viewportbilder aus tatsächlichen Szenen:

- `01-aufbau.png`, `02-gespannt.png`: bezahlter Ladezustand.
- `03-abschuss.png`, `04-flug.png`: Abschuss und Flug im Laufzeit-Labor.
- `05-wandkontakt.png`, `06-einzelteile.png`: Kontakt und abgelöste Teile.
- `hell-charge.png`, `hell-flight.png`, `hell-impact.png`: Höllen-Renderer.
- `frost-charge.png`, `frost-flight.png`, `frost-impact.png`: Frostgruft-Renderer.

Das sind vorbereitete Trainingsbuilds mit isolierten Profilen und manuell
fortgeschalteter Simulation, keine erspielten Kampagnen, LAN-/Netzwerk- oder
Leistungsmessungen. Der reguläre Host berechnet Kosten, Ladung und Freigabe.

Die Aufnahmeskripte stellen Halten ausdrücklich her: im Labor keine alten
neutralen Eingabekommandos; im Story-Test derselbe Hosttick innerhalb des
vorhandenen Sync-Adapters mit `SoulCharge.hold(true)` statt Abfrage einer
physisch gedrückten R-Taste. Die erste Story-Fixture hatte diese Haltequelle
nicht und wurde vor den finalen Aufnahmen korrigiert. Ihr ursprünglicher
Fehllauf bleibt als `spear-story-capture-first-attempt.log` erhalten.

## Wiederholen

Godot 4.7.2 aus der Projektwurzel; APPDATA vorab auf einen eigenen Scratchpfad
setzen. Suiten mit `--headless --path . --script res://tests/<Name>.gd`.
Ein echter Renderer wird für die beiden Aufnahmeskripte benötigt:

```
godot --path . --script res://scripts/capture_himmelsspeer.gd
godot --path . --script res://scripts/capture_himmelsspeer_story.gd
```

`receipt.json` hält finale Quellen-/Bildhashes und Prüfsummenstände fest.
