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

# Zweite Runde: Zauber und Talente (2026-10-30)

Messung mit `scripts/bench_spells.gd`: Krypta-Testraum, Seed 4242, je Spezialisierung alle
Leistenzauber und das Ultimate (Stufe 3) im Wechsel alle 0,26 s (mit dem Test-Profil: keine
Kosten, 0,5 s Abklingzeit, also ein Ultimate etwa jede Sekunde: ein Stresstest), 6 s Messzeit,
V-Sync aus. Ein Zauber, der noch nachlaedt, wird jetzt erneut versucht, statt uebersprungen zu
werden; so kommt jeder Zauber in jedem Lauf in derselben Reihe (vorher fiel das Ultimate je nach
Framezeit mal aus). Der Rechner schwankt zwischen Laeufen um 10 bis 20 %.

| Spezialisierung | vorher Mittel | vorher Max | nachher Mittel | nachher Max |
|---|---|---|---|---|
| Schwert/Berserker | 5,70 ms | 19,7 ms | 5,78 ms | 16,9 ms |
| Schwert/Wache | 11,28 ms | 27,3 ms | 7,30 ms | 24,6 ms |
| Schwert/Klinge | 6,91 ms | 35,3 ms | 7,48 ms | 18,0 ms |
| Bogen/Scharfschuetze | 4,53 ms | 14,2 ms | 4,99 ms | 11,4 ms |
| Bogen/Fallensteller | 18,07 ms | 343,8 ms | 17,13 ms | 94,5 ms |
| Bogen/Bestien | 11,84 ms | 18,0 ms | 13,00 ms | 24,9 ms |
| Magier/Feuer | 76,20 ms | 349,8 ms | 16,57 ms | 58,2 ms |
| Magier/Frost | 18,88 ms | 77,6 ms | 16,78 ms | 44,7 ms |
| Magier/Arkan | 9,97 ms | 32,0 ms | 8,73 ms | 25,1 ms |

Einzelne Talent-Ereignisse ueber ihre ganze Dauer bei 60 fps (Krypta, Wand-Clip an), gleiches Bild:

| Ereignis | vorher | nachher |
|---|---|---|
| Ultimate-Nova Feuer / Eis (8 m) | 8,4 ms | 3,7 / 2,7 ms |
| Inferno-Wirken (Stufe 3) | 8,7 ms | 5,0 ms |
| Nullpunkt-Wirken (Stufe 3) | 8,0 ms | 4,8 ms |
| Feuersturm-Welle | 5,9 ms | 3,8 ms |
| Feuerring (4 m) | 3,0 ms | 1,3 ms |

Spitzen (langsamste Frames, Feuermagier): die Pfuetzen kosteten in einzelnen Frames 25 bis 51 ms
(neues Feld auf einen Schlag gebacken, grosse Pfuetze auf einen Schlag gelegt); jetzt hoechstens
3 ms Backen und 2 ms Legen je Frame (8 ms, wenn ein Bild laenger als 0,1 s wartet).

Element-Volllast (`scripts/bench_vfx.gd`, Stufe 5 + Strudel und Sturm): 16,8 ms (erste Runde)
-> 11,4 bis 14,0 ms; Strudel und Sturmzone werden einmal je 12-fps-Takt gerechnet.

Was geaendert wurde:

- Zeichenweg (`src/vfx/pixel_paint.gd`): `PixelPaint.paint` zeichnet eine ganze Zellen-Karte und
  fragt den Wand-Clip selbst aus seinem Gedaechtnis (0,4 statt 1,1 Mikrosekunden je Zelle).
- Ultimates (`src/vfx/talent_ults.gd`): `_flush`, `_flush_under`, `_paint` ueber diesen Weg;
  `_disc` und `_flame` fragen das Dither zuerst und ohne Funktionsaufruf.
- Nova (`src/vfx/talent_pixels.gd`): Ringe als gepackte Zahlenlisten, gemerkt solange der Radius
  steht; Unterlage und Farbe in einem Durchgang (Zeile fuer Zeile, gleiches Ergebnis); die
  Nachglut ohne Winkel.
- Pfuetzen (`src/vfx/pool_paint.gd`): die Form eines Feldes (lebende Zellen, verschwundene mit
  Schmelzwasser, Raster, Umriss, Lippe, Lichtkranz der Leere) wird in Scheiben gerechnet wie
  schon das Schattieren; grosse Formen rechnet ein Hintergrund-Thread samt Geburts- und Endzeiten;
  auf leeren Boden kommt eine Pfuetze in einem Rutsch (`Dictionary.merge`), ueber Bestehendes in
  Scheiben von der Mitte aus (weit vor ihrem Ausbreiten). Neue Werte in `vfx_pools.json`:
  `bake_budget_ms`, `lay_budget_ms`, `lay_now_cells`, `catch_up_after_ms`, `catch_up_ms`.
- Strudel, Sturmzone, Todeszone: einmal je 12-fps-Takt gerechnet und als Bild gezeichnet;
  Schildkuppel: Form nur neu, wenn sie sich aendert.
- Mess-Skript: SPIKE-Zeilen schluesseln langsame Frames auf (Abschnitte, Marken, Pfuetzen-Teile).

Gleiches Bild nachgewiesen: 350 Bilder aller Talentformen (9 Novas, 18 Ultimate-Formen, 6 Wellen,
4 Auren, 2 Zonen, Schreie, Flammen, Zielmarke, Schrift, Wolken, Funken, Spur) pixelgleich vor und
nach der Aenderung; Pfuetzen aller Materialien an 15 Zeitpunkten (84 Pruefpunkte, auch Ueberlappung,
Schmelzwasser, Leere-Kranz, 21 700-Zellen-Feuerboden) gleich, auch gegen den Stand vor beiden
Runden (Commit bc148b48). Die Takt-Effekte im Bild: `runde2-look/vergleich-1.png` bis `-3.png`.

Offen:

- Ultimate-Novas in der Ausbreitung 5 bis 7 ms je Frame (der wachsende Ring wird jedes Frame neu
  gebaut).
- Riesige Feuerfelder (Feuersturm-Boden, etwa 21 700 Zellen) brauchen etwa 22 ms Schattieren je
  Bild: ein neues Bild nur alle paar Frames. Der naechste grosse Schritt waere ein Shader.
- Fallensteller-Spitzen im Bench kommen aus der Stapelung (bis 14 Todeszonen samt Giftwolken
  gleichzeitig); eine Zone im Spiel: 0,95 ms, 5,7 ms im Takt-Frame.
- Hoelle und Frostgruft nicht gemessen.
