# Krypta-Atmosphäre (Leerenstimmung)

Stand 29.10.2026. Die **Krypta der Verdammten** (Story 1, der vernetzte Krypta-Lauf in `src/game.gd` und
`src/dungeon_view.gd`) wirkt düsterer und „leerenbehaftet“, angelehnt an das lila Leerenthema des Leerenrufers.
Alles ist reine Darstellung beim Client: kein Einfluss auf Regeln, Netzwerk oder Spielstände.

Vorher/Nachher: `production/qa/evidence/crypt-atmosphere/` (`vorher/`, `nachher/`, `vergleich-*.png`).

## Was sich ändert

- **Raumfilter:** Boden, Wände und Requisiten des 0x72-Raums werden etwas dunkler, kontrastreicher, weniger
  braun, und dunkle Töne kippen ins 0x72-Violett `#473579`. Helle Pixel (Flammenkerne, Lichtschächte) behalten
  ihre Helligkeit. Der Filter liegt **nur auf dem Raum**: Helden, Gegner, Geschosse und Effekte behalten ihre
  eigenen Farben, die Lesbarkeit bleibt. Die Dunkelheit der Krypta wird etwas stärker (0,32 statt 0,2 aus
  `balance.json`) und bekommt einen dunkel-violetten Schatten `#0d0818`.
- **Nebel:** feine violette Schwaden ziehen langsam durch die Räume, zwei Schichten mit eigenem Wind, seitlich
  gestreckt und ineinander verwirbelt. Der Nebel liegt auf dem Raster der 0x72-Pixel (2 Weltpixel) und in
  wenigen Alpha-Stufen, also kein weicher Verlauf. Er liegt standardmäßig **unter** den Figuren (Bodennebel)
  und unter der Dunkelheit. Ein Shader auf einem Rechteck: billig, keine Texturen.
- **Lila Flammen:** Wandfackeln, Kerzensäulen und offene Bodenfeuer brennen in der 0x72-Lila-Rampe
  (`#473579`, `#5f2d56`, `#8156aa`, `#993970`, `#c278d0`, `#f0b3dd`, Kern `#fdf7ed`). Es sind dieselben
  8 Frames mit denselben Pixeln, nur umgefärbt (Farbtausch Pixel für Pixel, die Form bleibt exakt). Ihr
  Glühen ist violett `#c278d0`, ihr Lichtkreis in der Dunkelheit etwas kleiner (×0,85).
- **Kerzensäulen pixelgenau:** Die Kerzenbilder sind 16×32 mit 8 leeren Zeilen unten, wurden aber in ein
  16×24-Feld gestaucht gezeichnet (Pixelzeilen fielen weg). Jetzt wird nur der 16×24-Ausschnitt gezeichnet,
  jede Zeile bleibt ganz. Das gilt auch für die Dungeon-Werkstatt.

Wann es an ist: im laufenden Krypta-Lauf in 0x72-Räumen, solange die Krypta-Dunkelheit an ist (Kampf,
Erkunden, Belohnung, Tod). Lobby, Menüs, Editor-Vorschau, Hölle und Frostgruft bleiben unverändert. Die
Flammen sind in jedem 0x72-Krypta-Raum des Laufs lila.

## Daten: `assets/data/vfx_crypt_atmosphere.json`

Fehlt ein Schlüssel, gilt der Standardwert aus `src/vfx/crypt_atmosphere.gd` (`DEFAULTS`); Zahlen außerhalb
des erlaubten Bereichs werden begrenzt, unlesbare Farben durch den Standard ersetzt.

| Schlüssel | Bedeutung | Bereich |
|---|---|---|
| `enabled` | ganze Atmosphäre an/aus | bool |
| `grade.enabled` | Raumfilter an/aus | bool |
| `grade.exposure` | Helligkeit dunkler und mittlerer Töne (1 = unverändert) | 0–1,5 |
| `grade.highlight_from` / `highlight_to` | ab dieser Helligkeit wird die Abdunklung ausgeblendet (Lichter bleiben hell) | 0–1 |
| `grade.contrast` / `grade.pivot` | Kontrast um diese Helligkeit (1 = unverändert) | 0,5–2 / 0–1 |
| `grade.saturation` | Sättigung (1 = unverändert, 0 = grau) | 0–2 |
| `grade.tint_color` / `tint_strength` / `tint_range` | Farbe, Stärke und Helligkeitsgrenze der violetten Schatten | Farbe / 0–1 / 0,01–1 |
| `darkness.strength` | Deckkraft der Dunkelheit außerhalb der Lichter (ersetzt `balance.json` `lighting.darkness`) | 0–1 |
| `darkness.shade_color` | Farbe der Dunkelheit | Farbe |
| `fog.enabled` | Nebel an/aus | bool |
| `fog.over_actors` | `true`: Nebel über den Figuren statt darunter | bool |
| `fog.color` / `fog.density` | Nebelfarbe und Deckkraft der dichtesten Schwade (klein halten) | Farbe / 0–1 |
| `fog.coverage` / `fog.softness` | ab welchem Rauschwert Nebel beginnt (höher = weniger Schwaden) und wie weich er einsetzt | 0–1 / 0,01–1 |
| `fog.stretch` / `fog.warp` | seitliche Streckung der Schwaden, Stärke der Verwirbelung | 0,5–6 / 0–3 |
| `fog.pixel` / `fog.bands` | Weltpixel je Nebelpixel, Anzahl Alpha-Stufen | 1–8 / 1–16 |
| `fog.layers[]` | bis zu 3 Schichten: `scale` (Größe in Weltpixeln), `wind` ([x, y] Weltpixel pro Sekunde), `weight` (Anteil) | 16–2048 / – / 0–1 |
| `flames.enabled` / `floor_fires` | lila Flammen an/aus, auch offene Bodenfeuer | bool |
| `flames.recolor` | 0x72-Originalfarbe → Rampenfarbe (`"rrggbb"`); Ziele außerhalb der Lila-Rampe werden verworfen | – |
| `flames.light_color` / `glow_strength` | Farbe und Stärke des Glühens um Fackeln und Kerzen | Farbe / 0–1 |
| `flames.light_radius_scale` | Lichtkreis der Flammen in der Dunkelheit (× `torch_radius`) | 0–2 |

Zum Feintuning reicht die JSON-Datei; nach dem Speichern den Lauf neu starten.

## Technik

- `src/vfx/crypt_atmosphere.gd`: lädt und prüft die Daten (`load_data`, `parse`), färbt Flammen-Frames um
  (`recolor`, `flame_texture`, zwischengespeichert), baut das Filtermaterial; enthält die Knoten `RoomLayer`
  (zeichnet den Raum hinter der Ansicht, mit Filter) und `CryptFog` (Nebelrechteck).
- `assets/shaders/canvas_vfx_crypt_grade.gdshader` (Farbfilter), `assets/shaders/canvas_vfx_crypt_fog.gdshader`
  (Nebel). Beide für alle Renderer inkl. Compatibility, ohne Texturzugriffe.
- `src/dungeon_view.gd`: Raum-Ebene und Nebel als Kinder vor der Dunkelheit; `_update_atmosphere()` schaltet
  Filter und Nebel jedes Bild; Fackel-Glühen und Lichtkreise aus den Daten.
- `src/crypt_0x72_art.gd`: `use_flame_colors()` tauscht die Flammen-Frames; Kerzen über `CANDLE_REGION`.
- `src/vfx/darkness.gd`: nimmt optional `shade_color` an.

## Prüfen

```
godot --headless --path . -s tests/vfx_crypt_atmosphere_test.gd
godot --path . --windowed --resolution 1280x720 -s res://scripts/capture_crypt_atmosphere.gd -- res://production/qa/evidence/crypt-atmosphere/nachher
```

Der Test prüft das Laden (Bereiche, Standardwerte, kaputte Werte), dass Flammen nur Rampenfarben bekommen und
ihre Pixelform behalten, und dass Kerzen ungestaucht gezeichnet werden. Das Capture-Skript nimmt fünf Bilder an
festen Stellen auf (Seed 4242, Debug-Raum „RAUM 02“, Kamera ohne Mausvorlauf); Bild 05 zeigt dieselbe Stelle
3 Sekunden später, der Nebel ist weitergezogen.

## Offen

- Die Dungeon-Werkstatt (Editor) zeigt Fackeln weiter orange und ohne Filter, das Hauptmenü ebenso.
- Der Nebel liegt über dem ganzen Raumrechteck, also auch über der Leere zwischen unregelmäßigen Raumteilen.
- Die warmen Lichtschächte und roten Lavabrunnen bleiben warm.
