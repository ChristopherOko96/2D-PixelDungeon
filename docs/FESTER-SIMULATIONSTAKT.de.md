# Fester Simulationstakt für die Story-Welten

Stand: 03.11.2026. Im lokalen Code umgesetzt und nach ausdrücklicher Freigabe
des Nutzers gezielt getestet. Die Freigabe „Kannst du mal testen“ ersetzt für
diese Prüfung die vorherige Vorgabe, keine Tests auszuführen. Visuelle
Spielabnahme und ein längerer Lasttest stehen weiterhin aus.

## Problem und Änderung

`src/hell/hell_game.gd` führte bisher pro gerendertem Bild genau ein
`_update(min(delta, 0.05))` aus. Bei 15 FPS vergingen deshalb pro realer Sekunde
nur 0,75 Sekunden in der Simulation. Außerdem variierten die Schrittweiten
von Bewegung, KI und Projektilen mit der Bildrate.

Die Story-Laufzeit verwendet jetzt `src/physics_kit/fixed_step_clock.gd`:

- Verstrichene Bildzeit wird gesammelt. Jeder Gameplay-Schritt erhält dieselbe
  Dauer von 1/60 s. Ein Bild kann keinen, einen oder mehrere Schritte auslösen.
- Bei beispielsweise 15 FPS sind normalerweise vier Schritte je Bild fällig.
  Zeit wird nicht mehr an der bisherigen 50-ms-Grenze abgeschnitten.
- Pro Bild werden höchstens acht Schritte ausgeführt. Noch offene Zeit bleibt
  im Puffer und wird in folgenden Bildern nachgeholt.
- Kamera, Inventaransicht, Licht und HUD werden einmal je Render-Bild
  aktualisiert. Die Render-FPS werden hier nicht auf 60 begrenzt.
- Krypta, Frostgruft und Hölle verwenden dieselbe Story-Laufzeit und damit
  denselben Scheduler. Der ältere ENet-Spielkern bleibt unverändert.

## Pause, Hitstop und Laden

Die bisherigen pausierenden Menüs (ESC, Talente und Run-Talente sowie
Siegel-Auswahl) leeren den Zeitpuffer. Auch ein während eines Nachholschritts
geöffnetes Siegel-Menü stoppt die restlichen Schritte. Der erste Zeitwert
nach einer Pause wird ausgelassen, damit keine Menüzeit nachsimuliert wird.
Inventar und Karte erhalten dadurch keine zusätzliche Pausefunktion.

Hitstop wird in festen Zeitschritten abgebaut. Diese Zeit wird verbraucht,
während der Kampf absichtlich stillsteht; sie wird danach nicht nachgeholt.
Die bisherige Priorität von StoryFeel und dem Rig-Hitstop bleibt erhalten.

`load_floor()` leert ebenfalls den Puffer und beendet eine noch laufende
Schrittserie. Der erste Render-Zeitwert nach dem Laden wird ausgelassen, damit
die synchrone Dungeon-Erzeugung nicht als Kampfzeit gilt. Das gilt ebenso für
den ersten Frame beim Start. Kamera und Held werden wie bisher beim Laden
positioniert; während Tod und Ergebnis läuft die Kamera nicht neu an.

## Konfiguration

Datei: `assets/data/physics_clock.json`, Schema 1.

| Feld | Standard | Bedeutung |
| --- | --- | --- |
| `schema_version` | 1 | Version dieses Datenformats. |
| `tick_hz` | 60 | Gameplay-Schritte je simulierter Sekunde; Ladegrenzen 1 bis 240. |
| `max_steps_per_frame` | 2 | Maximale Nachholarbeit vor dem nächsten Bild; Ladegrenzen 1 bis 64 (Code-Standard 8). |
| `max_pending_steps` | 3 | Höchstens so viele Schritte Zeit warten; mehr verfällt. 0 = alles behalten (Code-Standard). |

**Änderung 05.11.2026 (Nutzerentscheid):** 8 Nachholschritte ohne Verfall erzeugten im Kampf eine
Spirale: Ein Schritt kostete 12–20 ms, also fast so viel, wie er simuliert. Jedes langsame Bild
holte dann mehr Schritte nach und wurde noch langsamer (gemessen 3–6 Schritte je Bild,
Frostgruft 110–129 ms je Bild). Jetzt gibt es höchstens 2 Schritte je Bild, und Restzeit über
3 Schritte verfällt. Ab 30 FPS läuft die Welt in Echtzeit wie zuvor. Darunter läuft sie langsamer,
statt zu stocken. Belege: `production/qa/evidence/perf/code-pruefung-2026-11-05.md`.

Die Werte werden beim Erzeugen der Story-Laufzeit geladen. Eine Änderung der
Tickrate kann das Spielgefühl und die CPU-Kosten beeinflussen und braucht
eine eigene Abnahme; sie ist keine gewöhnliche FPS- oder Grafikoption.

## Grenzen

Ein fester Takt erhöht nicht automatisch die FPS. Reicht die CPU dauerhaft
nicht für 60 Schritte je Sekunde oder wird das Nachholbudget dauerhaft
überschritten, bleibt die Simulation zurück. Zwei Schritte je Bild reichen
für Echtzeit bis 30 Render-Bilder je Sekunde. Darunter verfällt Zeit über
`max_pending_steps`, und die Welt läuft entsprechend langsamer (seit
05.11.2026; vorher acht Schritte ohne Verfall).

Diese Änderung ergänzt weder Render-Interpolation für alle Figuren noch eine
deterministische Wiederholung von Eingaben und Zufallsentscheidungen. Eingaben
und die bestehenden Weltregeln bleiben erhalten; Projektil-Kollisionen sind
ein separater Punkt des Reviews. Direktaufrufe von `_update(dt)` durch vorhandene
Hilfsskripte umgehen den Scheduler weiterhin; der normale Spielweg ist `_process`.

## Prüfstand

- `tests/story_clock_test.gd`: **18 Prüfungen, 0 fehlgeschlagen**.
  Zeitgeber für 15/30/60/144/240 FPS, wechselnde Bildzeiten, erhaltene Restzeit,
  Pause, Etagenwechsel und ungültige Zeitwerte; eigene Einstellungen ohne Profile.
- `tests/story_clock_integration_test.gd`: **63 Prüfungen, 0 fehlgeschlagen**.
  Die echten Szenen von Krypta, Frostgruft und Hölle laden; deren `_process`
  wird mit kontrollierten Bildzeiten aufgerufen. Weltzeit und Abklingzeit sind
  nach einer Sekunde bei allen fünf Raten gleich. Pausen, Hitstop und tatsächliches
  Erzeugen der zweiten Etage sind enthalten. Profile und Einstellungen sind isoliert.
- Dasselbe Integrationsfixture mit der alten Story-Datei aus `cb145387`:
  **21 von 60 Prüfungen schlagen erwartungsgemäß fehl**. Bei 15 FPS vergehen
  nur 0,75 Spielsekunden; die neue Fassung erreicht exakt 1,00. Drei weitere
  Prüfungen betreffen ausschließlich den neuen Zeitgeber und entfallen im Altvergleich.
- Integrationsfixture mit `--realtime`: **6 Prüfungen, 0 fehlgeschlagen**.
  Normale Engine-Callbacks aller drei Welten mit 15/60-FPS-Limit, jeweils
  etwa zwei Sekunden. Spielzeit liegt innerhalb der Toleranz von 0,1 s um
  die reale Zeit; beobachtete Abweichung maximal rund 0,064 s.

Damit bestehen **87 gezielte Prüfungen** des neuen Stands. Die finalen Läufe
melden keine Script-/Parse-Fehler. Beim Beenden der Integrationsläufe meldet
Godot jedoch 797 Texture-RIDs, 2.019 ObjectDB-Instanzen und sechs verbliebene
Ressourcen. Dieselben Zahlen treten bereits mit der alten Story-Datei auf;
sie sind ein gesonderter offener Befund, keine fehlerfreie Gesamtfreigabe.

Die Läufe waren headless: kein GPU-Benchmark, kein Netzwerktest und kein Beleg
für die optische Flüssigkeit auf einem schnellen Bildschirm. Vor einer
Veröffentlichung fehlen insbesondere die sichtbare Spielabnahme und Lastmessungen.
Vollständiger Prüfbericht und Ausgaben:
[Story-Clock-Prüfung](../production/qa/evidence/story-clock/REPORT.de.md).

Bezug: [Projektabgleich vom 03.11.2026](PROJEKTABGLEICH-2026-11-03.de.md).
