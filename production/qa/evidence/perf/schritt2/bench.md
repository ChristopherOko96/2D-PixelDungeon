# VFX-Rechenzeit (nach Pfuetzen)

Krypta, Seed 4242, groesster Raum, V-Sync aus, 240 Frames je Stufe nach 30 Aufwaerm-Frames.

| Stufe | Mittel ms | p95 ms | Max ms |
|---|---|---|---|
| 1 leer | 1.39 | 1.94 | 2.66 |
| 2 + 6 Pfuetzen | 3.97 | 10.57 | 11.86 |
| 3 + 3 Gaswolken | 3.34 | 11.47 | 16.77 |
| 4 + Partikel-Dauerlast | 12.39 | 20.91 | 30.48 |
| 5 + Strudel und Sturm | 17.64 | 28.34 | 43.77 |
| 6 - Gas | 14.66 | 21.82 | 23.87 |
| 7 - Pfuetzen und Strudel | 9.56 | 10.70 | 14.13 |
| 8 - Partikel-Last (Sturm bleibt) | 6.19 | 7.55 | 10.59 |

Einzelkosten unter Volllast (ms je Aufruf, Mittel ueber 20):

| Teil | ms |
|---|---|
| Gas zeichnen | 2.11 |
| Pfuetzen zeichnen (ohne Backen) | 1.40 |
|   Pfuetzen: Ueberlagerung | 0.07 |
|   Pfuetzen: Ringe, Risse, Funken | 0.16 |
|   Pfuetzen: Kruste, Reaktion, Sog | 0.04 |
|   Gas neu aufbauen | 11.08 |
| Sturm zeichnen | 1.18 |
| Strudel zeichnen | 3.26 |
| Partikel zeichnen | 0.32 |
| Partikel-Schritt | 0.53 |
| Gas-Schritt | 0.18 |
| Pfuetzen backen (alle Felder) | 29.93 |
|   backen: poison | 4.05 |
|   backen: void | 6.91 |
|   backen: lava | 8.35 |
|   backen: ice | 3.50 |
|   backen: blood | 4.02 |
|   backen: water | 4.03 |
