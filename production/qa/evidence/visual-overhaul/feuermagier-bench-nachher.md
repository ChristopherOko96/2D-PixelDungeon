# VFX-Rechenzeit (nachher)

Krypta, Seed 4242, groesster Raum, V-Sync aus, 240 Frames je Stufe nach 30 Aufwaerm-Frames.

| Stufe | Mittel ms | p95 ms | Max ms |
|---|---|---|---|
| 1 leer | 5.17 | 5.99 | 6.86 |
| 2 + 6 Pfuetzen | 7.42 | 11.02 | 13.14 |
| 3 + 3 Gaswolken | 8.31 | 12.59 | 17.27 |
| 4 + Partikel-Dauerlast | 15.28 | 19.30 | 22.49 |
| 5 + Strudel und Sturm | 17.11 | 24.09 | 26.49 |
| 6 - Gas | 13.35 | 21.03 | 22.56 |
| 7 - Pfuetzen und Strudel | 12.21 | 14.02 | 19.68 |
| 8 - Partikel-Last (Sturm bleibt) | 8.01 | 9.85 | 11.13 |

Einzelkosten unter Volllast (ms je Aufruf, Mittel ueber 20):

| Teil | ms |
|---|---|
| Gas zeichnen | 1.45 |
| Pfuetzen zeichnen (ohne Backen) | 0.40 |
|   Pfuetzen: Ueberlagerung | 0.03 |
|   Pfuetzen: Ringe, Risse, Funken | 0.02 |
|   Pfuetzen: Kruste, Reaktion, Sog | 0.03 |
|   Gas: ein Material neu aufbauen | 2.23 |
| Sturm zeichnen | 1.16 |
| Strudel zeichnen | 3.31 |
| Partikel zeichnen | 0.49 |
| Partikel-Schritt | 0.74 |
| Gas-Schritt | 0.16 |
| Pfuetzen backen (alle Felder) | 0.04 |
|   backen: poison | 0.03 |
|   backen: void | 0.03 |
|   backen: water | 0.02 |
