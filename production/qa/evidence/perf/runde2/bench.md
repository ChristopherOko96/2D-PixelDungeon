# VFX-Rechenzeit (Runde 2)

Krypta, Seed 4242, groesster Raum, V-Sync aus, 240 Frames je Stufe nach 30 Aufwaerm-Frames.

| Stufe | Mittel ms | p95 ms | Max ms |
|---|---|---|---|
| 1 leer | 1.38 | 1.93 | 2.45 |
| 2 + 6 Pfuetzen | 4.58 | 7.84 | 9.35 |
| 3 + 3 Gaswolken | 3.75 | 7.87 | 12.01 |
| 4 + Partikel-Dauerlast | 12.07 | 16.70 | 20.56 |
| 5 + Strudel und Sturm | 13.95 | 20.13 | 25.54 |
| 6 - Gas | 11.21 | 19.21 | 21.27 |
| 7 - Pfuetzen und Strudel | 8.69 | 10.58 | 13.43 |
| 8 - Partikel-Last (Sturm bleibt) | 5.21 | 7.57 | 10.61 |

Einzelkosten unter Volllast (ms je Aufruf, Mittel ueber 20):

| Teil | ms |
|---|---|
| Gas zeichnen | 1.54 |
| Pfuetzen zeichnen (ohne Backen) | 1.16 |
|   Pfuetzen: Ueberlagerung | 0.07 |
|   Pfuetzen: Ringe, Risse, Funken | 0.17 |
|   Pfuetzen: Kruste, Reaktion, Sog | 0.04 |
|   Gas: ein Material neu aufbauen | 2.65 |
| Sturm zeichnen | 1.12 |
| Strudel zeichnen | 3.44 |
| Partikel zeichnen | 0.60 |
| Partikel-Schritt | 0.82 |
| Gas-Schritt | 0.19 |
| Pfuetzen backen (alle Felder) | 0.14 |
|   backen: lava | 0.06 |
|   backen: poison | 0.03 |
|   backen: void | 0.03 |
|   backen: ice | 0.03 |
|   backen: blood | 0.03 |
|   backen: water | 0.03 |
