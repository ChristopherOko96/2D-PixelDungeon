# VFX-Rechenzeit: Ergebnis der ersten Runde (2026-10-30)

Messung mit `scripts/bench_vfx.gd`: Krypta, Seed 4242, groesster Raum, V-Sync aus,
240 Frames je Stufe nach 30 Aufwaerm-Frames. Die Last wird stufenweise aufgebaut.

| Stufe | vorher Mittel | vorher p95 | nachher Mittel | nachher p95 |
|---|---|---|---|---|
| 1 leer | 1,36 ms | 1,85 ms | 1,42 ms | 1,97 ms |
| 2 + 6 Pfuetzen | 7,19 ms | 21,56 ms | 4,17 ms | 10,09 ms |
| 3 + 3 grosse Gaswolken | 37,95 ms | 57,54 ms | 3,21 ms | 6,96 ms |
| 4 + Partikel-Dauerlast | 38,69 ms | 58,10 ms | 12,29 ms | 20,02 ms |
| 5 + Strudel und Sturm | 44,58 ms | 63,78 ms | 16,80 ms | 23,87 ms |

Einzelkosten unter Volllast (ms):

| Teil | vorher | nachher |
|---|---|---|
| Gas zeichnen je Frame | 17,15 | 1,74 |
| Gas: ein Material neu aufbauen (15 Hz, eins je Frame) | 11 (alle drei) | 2,6 |
| Pfuetzen zeichnen je Frame | 11,5 | 1,4 |
| Pfuetzen-Reaktionen je Frame | 1,1 bis 3,8 | 0,1 |
| Lichtkranz der Leere je Frame | ~0,8 | 0,07 |
| Backen Lava / Leere / einfache Pfuetze | 8,4 / 7,0 / 4,1 | 7,2 / 6,6 / 4,0 (hoechstens eins je Frame) |
| Strudel zeichnen | 3,35 | 3,3 (unveraendert) |
| Sturmzone zeichnen | - | 1,2 |

Was geaendert wurde:

- Gas (`src/vfx/gas.gd`): die Wolkenform wird hoechstens 15-mal pro Sekunde (vfx_gas.json draw_hz)
  in ein Bild je Material gerechnet und als eine Textur gezeichnet, statt jede Zelle jedes Frame
  einzeln; je Frame nur ein Material, das am laengsten wartende; Wandtest je Block von 8 x 8 Zellen
  gemerkt (open_memory_s).
- Pfuetzen (`src/vfx/pool_paint.gd`): hoechstens eine Material-Schicht wird je Frame neu gebacken
  (vfx_pools.json bakes_per_frame); Reaktionen nur, wo sich zwei Materialien ueberlappen; der
  Lichtkranz der Leere im 12-fps-Takt als Textur; Belegung als Byte-Raster, Pixel als Byte-Puffer;
  Spiralwinkel der Leere und Lava-Plattenpunkte werden gemerkt; Wand- und Lava-Boden-Abfragen je
  Zelle gemerkt.
- Messpunkte fuer das Mess-Skript: `PoolPaint.bake_counts / draw_us / draw_parts`,
  `dungeon_view.frame_stats`.

Der Look ist gleich geblieben (look-uebersicht.png: Gas an der Wand, Todeszone, Giftatem,
Leere-Lache, Strudel vorher und nachher).

Offen:

- Backen einer Pfuetzen-Schicht kostet weiter 4 bis 7 ms (GDScript je Zelle); naechster Schritt:
  das Backen ueber mehrere Frames verteilen oder die Lava- und Leere-Bewegung per Shader.
- Strudel (3,3 ms) und Sturmzone (1,2 ms) zeichnen jede Zelle jedes Frame: im 12-fps-Takt als Textur.
- Partikel-Physik unter Dauerlast etwa 3 ms.
- Hoelle und Frostgruft nicht gemessen.
