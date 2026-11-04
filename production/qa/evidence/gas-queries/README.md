# Gasabfragen: Korrektheit und CPU-Zeit

04.11.2026, `codex_v2`, lokale Änderung auf dem bereits optimierten Gegnerindex.
Nicht committed/gepusht. Die eingefrorene Gas-Referenz stammt aus
`7c39036ec9c12a3ba5b490b9f17293075666e5ee`; dieses Feld war vor dieser Änderung
gegenüber dem Commit unverändert.

## Umsetzung

`src/physics_kit/gas_field.gd` speichert konservative Grenzen um die tatsächlichen
Partikel jeder Wolke. Entfernte Wolken werden vor den Partikelschleifen verworfen.
Die Atemluft wählt ihre Kandidaten einmal pro Ring statt pro Probe. Schritt,
Verdrängung und Atemluft verlassen ein leeres Feld sofort. Es gibt keinen neuen
Qualitätsregler, keine geringere Partikelzahl und keine Änderung an Kräften,
Schaden oder dem Simulationsintervall. Details: `docs/GAS-PERFORMANCE.de.md`.

## Prüfungen

Vor der Änderung: `gas_queries_test` mit 1.250 Prüfungen, zwei erwarteten Fehlern
(`red.txt`). 128 entfernte Figuren verursachten 110.592 Partikelbesuche in der
Dichteberechnung; nach der Änderung sind es null. Ein naher Akteur prüft weiterhin
seine Wolke. Die deterministische Arbeitsgrenze verhindert eine Rückkehr zur
vollständigen Suche, ohne sich auf schwankende Rechnerzeiten zu verlassen.

| Suite, abschließender Stand | Prüfungen | Fehler |
|---|---:|---:|
| gas_queries_test | 1.250 | 0 |
| gas_field_test | 28 | 0 |
| element_exposure_test | 49 | 0 |
| Gesamt | 1.327 | 0 |

Die neue Suite vergleicht mit einer vollständigen Suche: Wind, Wände, Verdrängung,
Explosion, Sog, Geschossschneisen, Zündung, Verblassen, Dichte, Materialwahl,
Sichtweite, Raumwechsel, negative Koordinaten und sofortige neue Spawns. 180
aufeinanderfolgende Verdrängungen ohne Zwischenschritt prüfen insbesondere,
dass spätere Figuren fortgeschobenes Gas weiterhin erreichen. Die eingefrorene
Git-Referenz in den Benchmarks prüft zusätzlich die alten Abfrageverfahren.

## Gepaarter Gas-Benchmark

`scripts/bench_gas_queries.gd`: altes und neues Feld im selben Prozess; ihre
Reihenfolge wechselt pro Paar. Acht Aufwärm- und 56 gemessene Schritte zu 1/60 s.
Gleiche deterministische Wolken und Figurenpfade. Gemessen werden der vollständige
Gasschritt, Verdrängung, Atemluft sowie einige Schneisen/Reaktionsabfragen.
Der abschließende Lauf verwendet das aktuelle Monsterprofil aus
`element_rules.json`: vier Ringproben, 42 Weltpixel Probenradius; Figurenradius 18.
Alle sieben Fälle haben exakt gleiche Antworten und Partikelzustände.

| Figuren | Wolken | Anordnung | vorher ms | nachher ms |
|---:|---:|---|---:|---:|
| 128 | 0 | verteilt | 26,07 | 1,73 |
| 32 | 4 | verteilt | 11,11 | 8,13 |
| 64 | 12 | verteilt | 38,03 | 20,12 |
| 128 | 12 | verteilt | 86,49 | 42,74 |
| 128 | 24 | verteilt | 125,71 | 46,48 |
| 128 | 4 | alle im Gas | 38,21 | 38,85 |
| 8 | 4 | alle im Gas | 2,59 | 2,75 |

Bei 128 verteilten Figuren und zwölf/24 Wolken spart das Gassystem hier rund
51/63 % CPU-Zeit. Bei dichter Überlappung bleibt die nötige Kontaktarbeit und
es entstehen in diesen Messungen rund 2–6 % Zusatzaufwand.
Zeitbudgets: Median des gepaarten Nachher/Vorher-Verhältnisses höchstens 0,70
für die verteilten Fälle mit mindestens zwölf Wolken, sonst höchstens 1,15.
Alle Budgets bestanden. Das sind relative Optimierungsbudgets, kein 60-FPS-Ziel.

`paired.json` und `paired-final.txt` enthalten Endmessung und p95-Werte.
`paired-eight-samples-initial.json` ist ausdrücklich eine frühere synthetische
Messung mit acht Proben/24 Pixeln Radius und ohne die abschließenden Leerfeld-
Abkürzungen; nicht direkt mit der Endmessung vergleichen.

## Vollständiger Krypta-Simulationsschritt

`scripts/bench_story_gas.gd`: zwei echte Krypta-Szenen, Seed 4242, derselbe Raum.
Beide verwenden den bereits vorhandenen neuen Gegnerindex und den aktuellen
Spielcode. Nur der Gas-Painter der Referenz lädt das alte Gasfeld aus Git.
Partikelverknüpfungen bleiben angeschlossen. Acht Aufwärm- und 24 Messschritte,
abwechselnde Reihenfolge und gleicher globaler Zufallsseed vor jedem Schritt.
Hohe Gegner-HP, unterdrückte Angriffe und Helden-Unverwundbarkeit sind lediglich
Fixture-Einstellungen. Gemessen wird jeweils der gesamte `game._update`-Aufruf.

| Gegner | Wolken | vorher ms | nachher ms | weniger CPU-Zeit | p95 vorher/nachher |
|---:|---:|---:|---:|---:|---:|
| 32 | 4 | 27,73 | 22,66 | 18,3 % | 31,82 / 25,89 |
| 128 | 0 | 74,98 | 44,94 | 40,1 % | 81,77 / 48,88 |
| 128 | 12 | 134,26 | 85,97 | 36,0 % | 145,54 / 97,26 |

In jedem Schritt stimmen Positionen, Gegner-HP, Umgebungszustände, Gastimer,
Status/Blindheit, Helden-HP/anteiliger Schaden, Helden-Gas und sämtliche
Gaspartikel exakt überein. Die beiden Fälle mit Gas betreffen am Ende tatsächlich
zwei bzw. 16 Gegner mit Schaden oder Blindheit; die Fixture prüft dies ebenfalls.
Alle drei Szenarien bestehen ihre CPU-Budgets (Verhältnis höchstens 0,90 beim
großen Gasfall, sonst 1,15). Details: `story.json`, `story-final.txt`.
`story-initial.json` zeigt den ersten Lauf vor den abschließenden Abkürzungen
für komplett leere Felder; insbesondere dessen Leerfeldwert ist überholt.

## Grenzen und Hinweise

- Headless-CPU-Zeiten einer kontrollierten Fixture, **keine gemessenen Render-FPS**.
  Der große Gasfall bleibt mit rund 86 ms weit oberhalb der 16,67 ms für 60 Schritte/s.
  Grafik, reale Kampfrunden, alle Klassenkombinationen und vier Clients sind damit
  nicht abgenommen. Absolute Zeiten schwanken; deshalb erfolgt der Vergleich
  paarweise im selben Prozess.
- Alle abschließenden Prozesse liefern Exitcode 0 und ihre Abschlussmarker;
  keine `SCRIPT ERROR` oder Parse-Fehler. Die Umgebung meldet weiterhin, dass
  `user://logs/godot.log` nicht zum Schreiben geöffnet werden kann. Die Logs hier
  werden separat über PowerShell gesichert.
- Ein früher Aufbauversuch der Story-Fixture brach wegen des benötigten
  Konstruktorarguments beim Scriptwechsel ab und wurde beendet. Der Benchmark
  erstellt den Referenz-Painter jetzt mit seinen Argumenten und übernimmt die
  Gasverknüpfungen. Dieser Fehlversuch zählt nicht als Testnachweis und änderte
  keinen Spielcode. Endläufe sind fehlerfrei.
- Die Story-Fixture schreibt ausschließlich nach `output/gas-story-bench` und
  entfernt ihre Profil-/Einstellungsdateien danach. Übrig bleibt die Messdatei.
- Nächster Kandidat: wiederholte Aufbereitung von Gegner-/Feedback-Daten; danach
  gemeinsame Darstellungs-Snapshots und die Kosten dynamischer Flüssigkeitsflächen.

## Reproduktion aus dem Repositoryverzeichnis

Godot-Version aus `scripts/godot-environment.json`, derzeit 4.7.2 standard.
`godot` unten bezeichnet diese lokale ausführbare Datei.

```powershell
./production/qa/evidence/gas-queries/recreate-baseline.ps1
godot --headless --path . -s res://tests/gas_queries_test.gd
godot --headless --path . -s res://tests/gas_field_test.gd
godot --headless --path . -s res://tests/element_exposure_test.gd
godot --headless --path . -s res://scripts/bench_gas_queries.gd
godot --headless --path . -s res://scripts/bench_story_gas.gd
```

Die Benchmarks einzeln ausführen, ohne gleichzeitige andere Tests. Das Hilfsskript
rekonstruiert nur ignorierte Referenzdateien unter `output/gas-query-baseline`;
es wechselt keinen Branch und ersetzt keine aktive Quelldatei.
