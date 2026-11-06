# Begrenzte Talent-Gegnersuche

05.11.2026; Godot 4.7.2, lokal auf `codex_v2`, Basis `7c39036e` mit den
vorherigen lokalen Performanceänderungen. Nicht committed/gepusht.

## Verhalten

Siehe `docs/GEGNER-SUCHE.de.md`: zehn begrenzte Suchstellen verwenden
geordnete räumliche Kandidaten. Exakte Trefferbedingungen bleiben bestehen.
Kleine Gruppen und nicht begrenzte Abfragen behalten die vollständige Suche;
dichte Gruppen verwenden die aktuelle Gegnerliste ohne zusätzlichen
Talent-Indexaufbau. Verschiebungen aktualisieren die räumliche Zuordnung.

## Prüfungen

| Skript unter `tests/` | Prüfungen | Fehler |
| --- | ---: | ---: |
| talent_spatial_queries_test.gd | 252 | 0 |
| story_enemy_index_test.gd | 208 | 0 |
| story_enemy_index_integration_test.gd | 36 | 0 |
| hell_talents_test.gd | 36 | 0 |
| necro_story_attacks_test.gd | 30 | 0 |

Die ersten vier Suiten liefen mit dem finalen Code. Die Nekromanten-Suite lief
vor der letzten Optimierung des dichten Rückfallpfads; dieser wurde anschließend
durch die neuen Adapterprüfungen und die Story-Integration abgedeckt. Insgesamt
562 Prüfungen ohne Assertionsfehler. Die ursprüngliche vollständige Suche
scheiterte erwartungsgemäß am neuen Nachweis vermiedener Vollscans
(`talent-spatial-red.log`); anschließend war die Suite grün.

Abgedeckt: 80 gesetzte Zufallsabfragen gegen 258 Körper, Radien, tote Gegner,
Bosse, negative Koordinaten, Gleichstand, Wandfilter und Trefferreihenfolge;
Fallen, Landungsfrost, unmittelbare Verschiebung, unbeschränkte Suche sowie
dichter Rückfall ohne Neuaufbau, auch mit anschließend entferntem Zielpunkt.
Die Integration lädt echte Krypta-, Höllen- und Frostgruft-Szenen mit je
32 Gegnern und prüft unter anderem Teleports und Geschossreihenfolge.

Die Umgebung kann `user://logs/godot.log` nicht schreiben; Konsolenausgaben
wurden separat gespeichert. Die echten Szenen melden die bereits bekannten
Ressourcenwarnungen beim Beenden (887 Texture-RIDs, 2244 bzw. 2258 ObjectDB-
Instanzen und sechs Ressourcen). Dies ist keine fehlerfreie Ressourcenfreigabe.
In den finalen Prüflogs stehen keine Script- oder Parse-Fehler.

## Gepaarte CPU-Messung

`scripts/bench_talent_queries.gd`: derselbe Prozess, je 50 Phasen, davon zehn
Aufwärmphasen. Reihenfolge alter/neuer Suchweg wechselt pro Phase. Je Phase
64 Zielabfragen und 16 Flächenabfragen. Abstand der Körper: 240 px (verteilt)
oder 8 px (dicht). Der vorherige Bewegungsphasen-Index liefert den Dichtehinweis;
ein zusätzlicher Talent-Neuaufbau ist im Zeitbudget enthalten, wenn erforderlich.
Beide Suchwege nutzen denselben aktuellen Kampfcode; der Referenzadapter hat
keine räumliche API. Treffer und Ziele werden in jeder Phase verglichen.

| Gegner | Verteilung | Vollsuche µs | Adaptiv µs | Verhältnis |
| ---: | --- | ---: | ---: | ---: |
| 8 | verteilt | 783 | 827 | 1,056 |
| 32 | verteilt | 2416 | 1851 | 0,766 |
| 128 | verteilt | 9506 | 3804 | 0,400 |
| 256 | verteilt | 15860 | 5060 | 0,319 |
| 8 | dicht | 867 | 784 | 0,904 |
| 32 | dicht | 2740 | 2413 | 0,881 |
| 128 | dicht | 10331 | 9239 | 0,894 |
| 256 | dicht | 19887 | 19393 | 0,975 |

Alle acht Fälle ergebnisgleich; Performance-Grenze für große verteilte Gruppen
bestanden. Der erste Versuch mit bedingungsloser räumlicher Abfrage war im
dichten Fall langsamer (`talent-query-bench-initial.log`); deshalb der adaptive
Rückfall. Kleine Unterschiede beim vollständigen Rückfall sind keine belastbare
Gewinngarantie. Es handelt sich um eine einzelne synthetische Vergleichsmessung,
ohne Rendering, Netzwerk oder vollständige Kampfsimulation. Kein FPS-Versprechen.

Reproduktion mit der konfigurierten Godot-Binärdatei aus dem Projektverzeichnis:

```text
godot --headless --path . -s res://tests/talent_spatial_queries_test.gd
godot --headless --path . -s res://tests/story_enemy_index_test.gd
godot --headless --path . -s res://tests/story_enemy_index_integration_test.gd
godot --headless --path . -s res://tests/hell_talents_test.gd
godot --headless --path . -s res://tests/necro_story_attacks_test.gd
godot --headless --path . -s res://scripts/bench_talent_queries.gd
```
