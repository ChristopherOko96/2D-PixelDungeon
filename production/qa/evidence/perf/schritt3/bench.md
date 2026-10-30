# VFX-Rechenzeit (Messung)

Krypta, Seed 4242, groesster Raum, V-Sync aus, 240 Frames je Stufe nach 30 Aufwaerm-Frames.

| Stufe | Mittel ms | p95 ms | Max ms |
|---|---|---|---|
| 1 leer | 1.52 | 2.14 | 2.89 |
| 2 + 6 Pfuetzen | 4.16 | 9.29 | 12.88 |
| 3 + 3 Gaswolken | 3.58 | 10.18 | 11.48 |
| 4 + Partikel-Dauerlast | 12.50 | 20.15 | 21.54 |
| 5 + Strudel und Sturm | 16.80 | 23.68 | 28.26 |
| 6 - Gas | 14.56 | 20.83 | 21.89 |
| 7 - Pfuetzen und Strudel | 9.58 | 10.56 | 14.34 |
| 8 - Partikel-Last (Sturm bleibt) | 6.05 | 7.19 | 10.23 |

Einzelkosten unter Volllast (ms je Aufruf, Mittel ueber 20):

| Teil | ms |
|---|---|
| Gas zeichnen | 1.87 |
| Pfuetzen zeichnen (ohne Backen) | 1.33 |
|   Pfuetzen: Ueberlagerung | 0.07 |
|   Pfuetzen: Ringe, Risse, Funken | 0.17 |
|   Pfuetzen: Kruste, Reaktion, Sog | 0.04 |
|   Gas: ein Material neu aufbauen | 2.72 |
| Sturm zeichnen | 1.08 |
| Strudel zeichnen | 3.26 |
| Partikel zeichnen | 0.36 |
| Partikel-Schritt | 0.59 |
| Gas-Schritt | 0.19 |
| Pfuetzen backen (alle Felder) | 28.96 |
|   backen: poison | 4.08 |
|   backen: void | 6.75 |
|   backen: lava | 7.29 |
|   backen: ice | 3.53 |
|   backen: blood | 4.13 |
|   backen: water | 4.03 |
