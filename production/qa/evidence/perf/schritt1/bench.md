# VFX-Rechenzeit (nach Gas)

Krypta, Seed 4242, groesster Raum, V-Sync aus, 240 Frames je Stufe nach 30 Aufwaerm-Frames.

| Stufe | Mittel ms | p95 ms | Max ms |
|---|---|---|---|
| 1 leer | 1.25 | 1.71 | 2.18 |
| 2 + 6 Pfuetzen | 5.27 | 20.80 | 42.28 |
| 3 + 3 Gaswolken | 5.92 | 28.19 | 46.25 |
| 4 + Partikel-Dauerlast | 16.72 | 34.03 | 49.85 |
| 5 + Strudel und Sturm | 21.95 | 36.95 | 55.24 |

Einzelkosten unter Volllast (ms je Aufruf, Mittel ueber 20):

| Teil | ms |
|---|---|
| Gas zeichnen | 3.16 |
| Pfuetzen zeichnen (ohne Backen) | 5.26 |
| Strudel zeichnen | 3.26 |
| Partikel zeichnen | 0.60 |
| Partikel-Schritt | 0.79 |
| Gas-Schritt | 0.18 |
| Pfuetzen backen (alle Felder) | 31.53 |
|   backen: poison | 4.18 |
|   backen: void | 7.98 |
|   backen: lava | 8.41 |
|   backen: ice | 3.59 |
|   backen: blood | 4.26 |
|   backen: water | 4.13 |
