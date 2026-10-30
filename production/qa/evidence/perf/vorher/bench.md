# VFX-Rechenzeit (vorher)

Krypta, Seed 4242, groesster Raum, V-Sync aus, 240 Frames je Stufe nach 30 Aufwaerm-Frames.

| Stufe | Mittel ms | p95 ms | Max ms |
|---|---|---|---|
| 1 leer | 1.39 | 1.95 | 2.58 |
| 2 + 6 Pfuetzen | 7.44 | 22.20 | 43.43 |
| 3 + 3 Gaswolken | 38.73 | 57.86 | 61.38 |
| 4 + Partikel-Dauerlast | 39.19 | 58.24 | 61.36 |
| 5 + Strudel und Sturm | 44.74 | 62.95 | 64.27 |

Einzelkosten unter Volllast (ms je Aufruf, Mittel ueber 20):

| Teil | ms |
|---|---|
| Gas zeichnen | 17.15 |
| Pfuetzen zeichnen (ohne Backen) | 11.52 |
| Strudel zeichnen | 3.35 |
| Partikel zeichnen | 0.23 |
| Partikel-Schritt | 0.35 |
| Gas-Schritt | 0.19 |
| Pfuetzen backen (alle Felder) | 32.31 |
