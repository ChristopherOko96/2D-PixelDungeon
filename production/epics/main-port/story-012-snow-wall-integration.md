# Story 012: Schnee an den Mauern der Frostgruft

> **Epic**: Welt-Baukasten, Story 2 Frostgruft
> **Status**: Neu umgesetzt 2026-10-30 — HD-Satz mit den Schnee-Zeichnungen des Nutzers (tools/frost_dungeon/snow_hd.py); visuelle Nutzerabnahme offen
> **Type**: Visual/Feel
> **Last Updated**: 2026-10-30
> **Branch**: `feat/frost-world-kit`

## Neuumsetzung 2026-10-30 (HD)

- Statt Schnee aufzumalen kommen alle verschneiten HD-Sprites aus den Zeichnungen des Nutzers: `Frost_mit_Schnee.zip` und das Blatt `assets_mit_schnee.png` (beides in `tools/frost_dungeon/snow_hd_src/`).
- Der Boden, die Taustellen und der Shop bleiben; der Shop-Tisch kommt aus dem Blatt.
- Nord-/Südmauer: Kachel aus der ZIP-Mauer (Haube, Eiszapfen, Schneefuß). Mauerzellen, deren Fuß keine Schneezelle berührt (Abgrund, Eis, Taustelle), zeichnen `wall_h_bare`, die erste Mauer (`hell_game.gd` `_strip`).
- Seitenmauer: Schneehügel auf der Mauerkrone im ZIP-Stil (`snow_hd.py` `wall_v`).
- Im HD-Satz (`frost_theme.json` skins.hd `baked_snow`) entfallen die gezeichneten Mauerlippen, Kontaktmulden, Vordergrund-Akzente und Einlassfugen. Der Pixel-Satz bleibt unverändert.
- Nachweis: `production/qa/evidence/frost-snow-zip/hd/`.

## Ziel und Referenz

Die Mauern und Requisiten der Frostgruft sollen so wirken, als stünden sie seit Langem in einer Schneedecke.

Am 2026-10-30 wurde die erste Umsetzung visuell abgelehnt: Die großen `drift_0`–`drift_5`
bildeten geschlossene weiße „Perlenkränze“ um Feuerschalen, Urnen, Knochen, Platten und Ecken.
Die Überarbeitung ersetzt diese Reihen durch objektgenaue Kontaktmulden, dezente Schattenfugen und
wenige, direkt am unteren Spriterand liegende Schneepolster. Bodenplatten erhalten eine flache
Einlassfuge statt eines Schneerahmens; Mauerlippen und Ecken werden deutlich flacher.

- **Referenzbild:** `C:\Users\ctnsa\Downloads\ChatGPT-Bild 30. Okt. 2026, 12_18_24.png` (liegt beim Nutzer, nicht im Repo).
- **Was es zeigt:**
  - Die Mauern stehen im HD-Satz auf Schnee.
  - Am Mauerfuß liegt eine zusammenhängende, unregelmäßige Schneelippe aus Hügeln.
  - Darunter und in den Lücken liegt eine schmale blaugraue Kontaktfuge.
  - Die Mauerkronen tragen eine Schneeauflage.
- **Was nicht übernommen wird:** HUD, Karte, Figur und Raumform des Bildes.

## Ausgangsproblem

Bisher legte `src/hero/frost_snow.gd` an jedem Mauerfuß Reihen einzelner runder Schneehaufen (`drift_0`–`drift_5`) ab. Das sah aus wie Perlenschnüre vor der Mauer und nicht wie Schnee, aus dem die Mauer aufsteigt:

- keine Kontaktfuge;
- an Ecken doppelte Klumpen;
- an den Seitenwänden durchgehende Haufenreihen;
- sichtbare Wiederholung.

Außerdem stand in `frost_theme.json` unter `snow` der Wert `"shade": 0.32`, den `FrostSnow.DEFAULTS` gar nicht kannte. Er wurde also nie gelesen.

## Technische Umsetzung

### Assets: `tools/frost_dungeon/wall_snow.py`

Der Generator wird von `build_frost_extras.py` aufgerufen.

- **Halbe Zellkanten:** Jedes Stück deckt eine halbe Zellkante ab (48 px). Sein Profil gibt an, wie weit der Schnee die Mauer hinaufreicht und wie weit auf den Boden.
- **Aufbau einer Lippe:** ein flaches Band mit ein bis drei runden Hügeln.
- **Gemeinsame Anschlüsse:** An beiden Enden trifft jedes Stück einen festen Anschluss:
  - 0 = Lücke, die Fuge ist sichtbar;
  - 1 = Hügelmitte;
  - 2 = großer Hügel, nur an Nordmauern.
- **Kein Tapetenmuster:** Das Spiel wählt den Anschluss an jeder Grenze aus deren Weltposition. Beide Hälften, die sich dort treffen, bekommen also denselben, und lange Mauern haben Lücken und Hügel ohne festen Takt.
- **Schattierung:** Sie wird pro Pixel aus der Form in Bildschirmrichtung berechnet, mit Licht von oben:
  - weiße Oberkante;
  - kaltblauer Fuß;
  - weicher blauer Umriss gegen den Bodenschnee;
  - Schattenlinie auf dem Boden.
- **Seitenwände:** Linke und rechte Seitenwände bekommen deshalb eigene Stücke, nicht gespiegelte Kopien.
- **Pixelraster:** Der Pixel-Satz ist in 3-px-Blöcken gebaut, der HD-Satz in 2-px-Blöcken, mit harten Alphakanten. Alle Rahmenmaße sind Vielfache von 6.
- **Anker und Anzahlen** landen in `assets/data/frost_wall_snow.json`.

### Laufzeit: `src/hero/frost_wall_snow.gd`

Das Modul gehört zu `frost_snow.gd` und arbeitet so:

1. **Kontakte erkennen.** `contacts()` liest das Zellraster einmal pro Etage. Jede Kante zwischen einer Schneezelle und einer Wand (Nord, West, Ost, Süd) wird nach ihren Nachbarn eingeordnet:
   - **run:** Die Lippe läuft an der Mauer weiter.
   - **inner:** Innenecke, wenn die Nachbarzelle selbst Wand ist.
   - **outer:** Außenecke. Die Diagonale ist begehbar, an der Mauerecke steht ein Pfosten.
   - **end:** Durchgang, Treppentür, Eis oder Tauung.
2. **Diagonalen für Ecken.** Außenecken werden über die Diagonalnachbarn erkannt. Eine Zelle mit einer Türzelle unter ihren acht Nachbarn steht im Türrahmen: Sie bekommt keine Seitenlippen, und ihre Nordlippe läuft dort aus, statt sich in die Ecke zu türmen.
3. **Stücke wählen.** `place()` setzt die Stücke:
   - Halbe Kanten erhalten Lauf-, End- oder Eckstücke.
   - **Innenecke:** ein Eckstück mit Haufen. Es übernimmt auch die obere Hälfte der Seitenkante.
   - **Außenecke:** Die Nordlippe endet in einem Haufen um den Fuß des Eckpfostens. Das Stück übernimmt die untere Hälfte der Seitenkante darüber, damit kein Schnee den Pfosten hochläuft.
   - **Seitenwände:** lose Hügel. Sie treffen End- und Eckstücke immer mit einer Lücke, damit keine geschlossene weiße Kontur entsteht.
4. **Freie Mauerfüße.** Sie bleiben frei unter:
   - der Treppentür (`door_stairs`);
   - breiten Bannern, die über den Mauerfuß herabhängen (breiter als 56 px, mehr als 24 px tiefer). Diese Banner hängen vor dem Schnee.
5. **Cache.** Die Stücke liegen pro Zeichen-Chunk im Präsentationscache `chunks`. Neu gebaut wird er:
   - beim Etagenwechsel (`reset()`);
   - wenn eine Geheimwand aufgeht (`walls_changed()` aus `_open_secret`);
   - wenn eine Feuerschale ihre Schneefläche abgetaut hat (in `update()`).
6. **Zeichnen.** `draw()` zeichnet nur noch die gecachten Stücke. Es gibt keine Rasterprüfung pro Frame.
7. **Determinismus.** Die Variation hängt nur von der Etage ab (`floor_seed`: Nummer und Name), von der Position und vom Theme-Wert `seed`. Es gibt keinen Zufall pro Frame oder Lauf.
8. **Nur Darstellung.**
   - Keine Kollision, Navigation oder Raumgeometrie wird verändert.
   - Nichts landet in `state`, im Spielstand oder in RPCs. Die Frostgruft hat keine Netzwerkpfade.

### Zeichenreihenfolge (`src/hell/hell_game.gd`)

Pro Chunk gibt es nur in der Frostgruft drei zusätzliche Ebenen. Alle haben Nearest-Filterung, auch im HD-Satz, der sonst linear filtert.

| Ebene | z | Inhalt |
| --- | --- | --- |
| `back` | 0 | Boden, Abziehbilder, Nord- und Seitenmauern, Pfosten, Mauerdeko |
| `snow_ao` | 1 | Kontaktfugen über den untersten Mauerpixeln und dem Boden direkt davor |
| `snow_lip` | 2 | Schneelippen über den Fugen und dem Mauerfuß |
| Figuren, Requisiten, Effekte | 5–12 | unverändert über der Lippe; die Figur verschwindet nie dahinter |
| `front` | 20 | Vorderwände (Süd) |
| `snow_front` | 21 | Schnee an der Rückseite der Vorderwände, über ihrer Oberkante |

Die Fuge liegt hinter der Lippe und ist in deren Lücken sichtbar. Abgrund und Türöffnungen bekommen keinen Schnee, weil nur Schneezellen Kontakte haben und die Lippe immer auf der Seite ihrer Zelle liegt.

### Datensteuerung (`assets/data/frost_theme.json` → `wall_snow`)

| Wert | Standard | Wirkung |
| --- | --- | --- |
| `seam` | 1.0 | Stärke (Alpha) der Kontaktfugen |
| `lip` | 1.0 | Stärke der Schneelippen |
| `breaks` | 0.38 | Anteil der Halbgrenzen an Nord- und Südmauern, an denen die Lippe zur Lücke absinkt |
| `side_breaks` | 0.6 | dasselbe an Seitenwänden (lose Hügel) |
| `sink` | 0 | px, um die die Nordlippen höher an der Mauer sitzen |
| `scale` | 1 | ganzzahlige Größe der Stücke |
| `seed` | 0 | andere Anordnung bei gleicher Etage |
| `south` | true | Schnee an der Rückseite von Vorderwänden |

Weitere Punkte:
- Form, Höhe und Breite der Lippen liegen im Generator (`JOIN`, `run_profiles`, Rahmenmaße), weil nicht ganzzahliges Skalieren die Pixelkunst zerstören würde.
- Der tote Wert `snow.shade` ist entfernt. Ein Test stellt sicher, dass jeder Schlüssel in `snow` und `wall_snow` auch gelesen wird.

## Assetliste

Die folgenden Dateien liegen je in `assets/sprites/frost/` (Pixel) und `assets/sprites/frost_hd/` (HD), 66 Stück pro Satz. Alle sind generiert, die Quelle ist `tools/frost_dungeon/wall_snow.py`.

| Stücke | Anzahl | Zweck |
| --- | --- | --- |
| `snow_wall_lip_h_<a><b>_<k>` | 18 (9 Anschlusspaare × 2) | Lippe am Fuß von Nordmauern |
| `snow_wall_lip_h_end_l/_r` | 2 | auslaufende Nordlippe |
| `snow_wall_lip_left_<a><b>_<k>`, `snow_wall_lip_right_<a><b>_<k>` | je 8 | Hügel an Seitenwänden (Wand links/rechts) |
| `snow_wall_lip_left_end_t/_b`, `snow_wall_lip_right_end_t/_b` | 4 | letzter Hügel vor Ecke oder Durchgang |
| `snow_wall_lip_s_<a><b>_<k>`, `snow_wall_lip_s_end_l/_r` | 8 + 2 | Schnee an der Rückseite von Vorderwänden |
| `snow_wall_corner_inner_l/_r` | 2 | Innenecken |
| `snow_wall_corner_outer_l/_r` | 2 | Außenecken (Haufen um den Pfostenfuß) |
| `snow_wall_ao_h_00..03`, `snow_wall_ao_h_end_l/_r`, `snow_wall_ao_left_00..02`, `snow_wall_ao_right_00..02` | 12 | Kontaktfugen |

Dazu kommt `assets/data/frost_wall_snow.json` mit Ankern und Anzahlen. Die bisherigen
`drift_0`–`drift_5` werden nicht mehr zur Einbettung von Objekten, Platten, Feuerschalen oder
Taurändern verwendet. Gerade diese Mehrfachreihen waren die Ursache der abgelehnten weißen Ringe.

## Überarbeitung nach Nutzerfeedback

- `snowfoot()` wird jetzt in beiden Grafik-Sätzen wirklich auf Requisiten angewendet. Die wenigen
  Schneepixel liegen dadurch direkt auf der echten unteren Alpha-Silhouette von Schädelhaufen,
  Felsen, Urnen, Feuerschalen, Kisten und weiteren festen Objekten.
- Vor dem Objekt liegt eine flache, pixelquantisierte Kontaktmulde; der größte Teil davon bleibt
  durch das Objekt verdeckt. Das erzeugt Tiefe, ohne einen hellen Außenring zu bilden.
- Kleine lose Knochen/Items erhalten nur einen schmalen Kontaktschatten und einen einzelnen
  Vorderkanten-Akzent.
- Rune-, Druck- und Bodenplatten erhalten eine schmale Einlassfuge und höchstens zwei kurze
  Schneepixel-Akzente an der Vorderkante, keinen vierseitigen Schneerahmen.
- Der generische Schneeball-Ring um aktive Tauflächen wurde vollständig entfernt; die unregelmäßige
  Kante steckt bereits in der Tauflächen-Textur.
- Mauerlaufstücke und Ecken wurden auf etwa die halbe Tiefe/Höhe reduziert. Ecken führen die Lippe
  nur noch um die Kante, statt einen separaten weißen Hügel zu erzeugen.

## Abnahmekriterien

- [x] Gerade Mauern haben eine flache, zusammenhängende, unregelmäßige Lippe aus Hügeln und Senken.
- [x] Unter der Lippe und in ihren Lücken ist eine schmale blaugraue Kontaktfuge sichtbar.
- [x] Die Lippe überdeckt stellenweise die untersten Mauerpixel (0–13 px, Hügelkuppen höher, Lücken gar nicht).
- [x] Lange Mauern zeigen keine Wiederholung gleicher runder Haufen: 18 Nordstücke, Anschluss pro Grenze aus der Weltposition.
- [x] Seitenwände haben eigene, richtungsabhängige Stücke (links/rechts) und nur lose Hügel, keine geschlossene Kontur.
- [x] Innen- und Außenecken sind über eigene Eckstücke verbunden, ohne doppelte Klumpen. Die Außenecke umschließt den Eckpfosten am Fuß.
- [x] Auf der Abgrundseite liegt kein Schnee.
- [x] Durchgänge, Türrahmen, Treppentür und breite Banner bleiben frei.
- [x] Mauergeometrie, Kollision und Navigation sind unverändert (Test vergleicht Raster und `solids`).
- [x] Gleiche Etage ergibt gleiche Darstellung; kein Flackern, keine Neuverteilung pro Frame.
- [x] Nearest-Filterung und harte Pixelkanten in Pixel und HD.
- [x] Keine Rasterprüfung pro Frame.
- [x] Keine generischen Drift-Reihen oder geschlossenen weißen Ringe um Feuerschalen, Objekte oder Platten.
- [x] Große Requisiten haben silhouette-gebundene Schneepolster plus flache Kontaktmulde.
- [x] Kleine Items und Knochen bleiben mit genau einem kleinen Vorderkanten-Akzent lesbar.
- [x] Bodenplatten haben eine Einlassfuge und höchstens zwei Vorderkanten-Akzente.
- [x] Fußspuren, Eis, Tauflächen, Feuerstellen und Figuren bleiben funktional erhalten (Frost-Tests).
- [ ] **Visuelle Nutzerabnahme:** Geschmack und Nähe zum Referenzbild beurteilt der Nutzer.

## Test- und Screenshot-Nachweise

**Tests, ausgeführt am 30.10.2026:**
- `tests/frost_wall_snow_test.gd` (erweitert): 265/0. Zusätzlich abgedeckt sind:
  - gerade Nordmauer und Innenecken;
  - linke und rechte Seitenwand;
  - Außenecke;
  - Durchgang mit Türrahmen;
  - Treppentür und breite Banner;
  - Abgrundseite und Eis;
  - Determinismus und übereinstimmende Anschlüsse;
  - jedes Stück in beiden Sätzen vorhanden;
  - alle Theme-Werte gelesen;
  - echte Etage: Raster, Kollision und `state` unverändert, Ebenen-z und Filterung.
  - Objekt-Einbettungsvertrag für Schädelhaufen, Urne, Feuerschale, Knochen und Bodenplatte.
- Bestehende Tests:
  - `frost_runtime_test` 36/0;
  - `frost_combat_test` 35/0;
  - `graphics_switch_test` 19/0;
  - `story_glow_test` 307/0;
  - `world_kit_parity_test` 663/0;
  - `story_player_fx_test` 130/0;
  - `story_pause_test` 16/0.
- `./scripts/Dev.ps1 Check -GodotPath …`: Import und Parse für 139 Skripte OK.
- `scripts/capture_frost_winter.gd` (Pixel): alle Winter-Checks OK. Die Eisfalle wurde übersprungen, weil es auf dieser Etage keine gibt.
- Soak (`scripts/soak_krypta.gd`, Schwertkämpfer, 60 s): Lauf bis Etage 3 ohne Skriptfehler.

**Echte GPU-Aufnahmen (Godot 4.7.2, 1280×720, Weltlauf 4242, Etage 1)** mit `scripts/capture_frost_wall_snow.gd`:

- `production/qa/evidence/frost-wall-snow/before-pixel/`, `before-hd/`:
  - der alte Stand mit den Drift-Perlen;
  - die Spots 05/06 der Vorher-Aufnahmen liegen noch an Feuerschalen, weil die Spot-Auswahl danach angepasst wurde.
- `after-pixel/`, `after-hd/`: der neue Stand. Je Aufnahme eine Übersicht und eine 3× vergrößerte Nahaufnahme `-nah`:
  - `01-startraum`;
  - `02-gerade-nordwand`;
  - `03-seitenwand-links`;
  - `04-seitenwand-rechts`;
  - `05-innenecke`;
  - `06-aussenecke`;
  - `07-tuer`;
  - `08-treppe`.
- `bare-pixel/`, `bare-hd/`: dieselben Spots mit ausgeschaltetem Mauerschnee (`bare`).
- Vorher|Nachher nebeneinander:
  - `vergleich-pixel-01-startraum.png`;
  - `vergleich-hd-01-startraum.png`;
  - `vergleich-pixel-02-gerade-nordwand-nah.png`;
  - `vergleich-hd-02-gerade-nordwand-nah.png`.

**Aktuelle Codex-Überarbeitung:** `production/qa/evidence/frost-snow-codex/pixel/` und `hd/`.
Neben den acht Mauer-Spots enthält sie reale Aufnahmen für Schädelhaufen, Felshaufen, Knochen,
Feuerschale und Bodenplatte (`09`–`14`). Die HD-Übersicht zeigt den vollständigen Startraum ohne
die abgelehnten weißen Objekt-Ringe.

## Bearbeitete Dateien

**Neu:**
- `src/hero/frost_wall_snow.gd`
- `tools/frost_dungeon/wall_snow.py`
- `assets/data/frost_wall_snow.json`
- `assets/sprites/frost{,_hd}/snow_wall_*.png` (+ `.import`)
- `tests/frost_wall_snow_test.gd`
- `scripts/capture_frost_wall_snow.gd`
- diese Story
- `production/qa/evidence/frost-wall-snow/`

**Geändert:**
- `src/hero/frost_snow.gd`:
  - keine Drift-Reihen mehr an Mauern;
  - keine Drift-Ringe mehr an Objekten, Platten oder Tauflächen;
  - getrennte Unter-/Überzeichnung für Kontaktschatten und winzige Vorderkanten-Akzente;
  - Mauerschnee wird gebaut, beim Abtauen neu gebaut, und es gibt `walls_changed()`.
- `src/hell/hell_game.gd`:
  - drei Schnee-Ebenen pro Chunk in der Frostgruft;
  - `draw_layer`-Fälle;
  - Neuaufbau nach `_open_secret`.
- `assets/data/frost_theme.json`: Block `wall_snow`, toter Wert `snow.shade` entfernt.
- `tools/frost_dungeon/build_frost_extras.py`:
  - erzeugt die Mauerstücke;
  - schreibt die Ankerdatei;
  - räumt veraltete Stücke weg;
  - speichert HD-Sprites mit Wiederholversuch.
  - wendet `snowfoot()` und `pit_rim()` nun tatsächlich in Pixel und HD an.
- `assets/sprites/frost{,_hd}/manifest.json`: neue Einträge.

## Bekannte Abweichungen

- **Hügelgröße:** Die Lippen wurden nach der ersten Nutzerablehnung nochmals stark abgeflacht.
- **Mauerkronen:** Sie behalten die vorhandene Schneeauflage der Wand-Sprites (`snowcap`). Sie wurde nicht neu gezeichnet.
- **Südmauern:** Sie bekommen keine eigene Kontaktfuge, weil dort keine Kontaktkante zum Boden sichtbar ist, nur eine kleine Schneelippe auf der Oberkante.
- **Südliche Ecken und obere Seitenwandenden:** Sie laufen über Endstücke aus und haben keine eigenen Eckstücke.
- **Durchgänge und Banner:** Zellen im Türrahmen und unter breiten Bannern bleiben ganz ohne Lippe. Neben Durchgängen ist der Mauerfuß darum stellenweise kahl.
- **Regressionstest für `snow.shade`:** Der Test, dass alle `snow`-Schlüssel gelesen werden, wurde nur gegen den reparierten Stand ausgeführt. Gegen den alten Stand mit `"shade": 0.32` schlägt er nach seiner Logik fehl (der Schlüssel fehlt in `FrostSnow.DEFAULTS`), wurde dort aber nicht laufen gesehen.

## Visuelle Nutzerabnahme

Offen. Zu beurteilen sind:
- Größe und Dichte der Hügel;
- Stärke der Fuge (`seam`);
- Anteil der Lücken (`breaks`, `side_breaks`);
- Aussehen der Seitenwände und Ecken in Pixel und HD.
