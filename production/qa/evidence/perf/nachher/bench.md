# VFX-Rechenzeit (nachher)

Krypta, Seed 4242, groesster Raum, V-Sync aus, 240 Frames je Stufe nach 30 Aufwaerm-Frames.

| Stufe | Mittel ms | p95 ms | Max ms |
|---|---|---|---|
| 1 leer | 1.42 | 1.97 | 2.38 |
| 2 + 6 Pfuetzen | 4.17 | 10.09 | 11.88 |
| 3 + 3 Gaswolken | 3.21 | 6.96 | 13.83 |
| 4 + Partikel-Dauerlast | 12.29 | 20.02 | 24.04 |
| 5 + Strudel und Sturm | 16.80 | 23.87 | 31.97 |
| 6 - Gas | 14.43 | 21.12 | 22.27 |
| 7 - Pfuetzen und Strudel | 9.51 | 10.46 | 14.00 |
| 8 - Partikel-Last (Sturm bleibt) | 6.11 | 7.41 | 10.35 |

Einzelkosten unter Volllast (ms je Aufruf, Mittel ueber 20):

| Teil | ms |
|---|---|
| Gas zeichnen | 1.71 |
| Pfuetzen zeichnen (ohne Backen) | 2.15 |
|   Pfuetzen: Ueberlagerung | 0.11 |
|   Pfuetzen: Ringe, Risse, Funken | 0.20 |
|   Pfuetzen: Kruste, Reaktion, Sog | 0.03 |
|   Gas: ein Material neu aufbauen | 2.64 |
| Sturm zeichnen | 1.18 |
| Strudel zeichnen | 3.37 |
| Partikel zeichnen | 0.40 |
| Partikel-Schritt | 0.60 |
| Gas-Schritt | 0.17 |
| Pfuetzen backen (alle Felder) | 28.53 |
|   backen: poison | 3.97 |
|   backen: void | 6.67 |
|   backen: lava | 7.14 |
|   backen: ice | 3.40 |
|   backen: blood | 4.02 |
|   backen: water | 3.98 |
