# Code-Prüfung Start und Spiel (2026-11-05)

Nur aus dem Code, ohne Spielen. Dazu vier kurze Messläufe mit einem Hilfsskript (nicht im Projekt,
nur im Scratchpad): Startzeiten von Menü und Story-Welten, eine Zeitleiste aller Ladevorgänge
(`--verbose`, jede Zeile mit Uhrzeit) und Mikro-Zeiten einzelner Funktionen. Godot 4.7.2
(Editor-Binary, Konsole), 1280x720, Windows. **Nichts am Spiel geändert.**

Grundlage: `production/qa/evidence/perf/story/ergebnis.md` (Runden 1 und 2) und Commit `1e417341`
(Gegner-Index, Gas-Abfragen, gemeinsamer Talent-Schnappschuss, Treffer-Materialien). Was dort schon
gemacht ist, zähle ich hier nicht noch einmal.

## Gemessene Startzeiten

| Schritt | warm (Dateien im Windows-Cache) | kalt (erster Start des Tages) |
|---|---|---|
| Engine bis Skriptstart | 0,7–0,9 s | 1,8 s |
| Hauptmenü: Skripte übersetzen (`main.tscn` laden) | 6,6–6,9 s | – |
| Hauptmenü: `game.gd` anlegen | 1,0 s | – |
| Hauptmenü: `game._ready` (alte Dungeon-Ansicht + Menü) | 12,4 s | 23,6 s |
| **Menü steht nach** | **~21 s** | **~32 s** |
| Erste Story-Welt nach dem Menü: `_ready` | 3,7–4,0 s | – |
| danach die ersten 2 Bilder | 0,1–0,8 s | – |
| Story-Welt ohne Menü vorher (Testskripte): Skripte übersetzen | 6,0–7,1 s | – |
| Story-Welt ohne Menü vorher: `_ready` | 8,2 s | 26,6 s |
| Etagenwechsel `load_floor` | 0,63–0,96 s | – |

Zeitleiste von `game._ready` (warm, 12,4 s), grob:

- ~2,3 s am Anfang (Hilfsobjekte, Rigs, Figuren-Katalog der alten Ansicht)
- **2,8 s `SoulField.prepare()`** (Seelenfeld-Bilder, siehe S1)
- ~3,5 s rund 800 Bilder der alten Figuren laden plus Silhouetten pixelweise in GDScript
- ~1,2 s rund 700 Sounds (Sfx der alten Ansicht)
- **~3,0 s die drei Story-Szenen laden** (übersetzt `hell_game.gd` und alles, was es vorlädt), nur um
  daraus `theme_path` zu lesen (siehe S2)

Zeitleiste `_ready` einer Story-Welt ohne Menü vorher (warm, 8,2 s): Bilder 0,5 s, Feuer-Animation
0,7 s, Sounds 1,6 s, Rigs und Effektbilder 1,4 s, Weltgenerator 0,9 s, **Seelenfeld 2,8 s**.

## Start: Funde nach Gewinn und Risiko

### S1. Seelenfeld wird bei jedem Programmstart neu ausgeschnitten (2,8 s)

- **Wo:** `src/vfx/soul_field.gd:23-63` (`prepare`), aufgerufen in `src/vfx/talent_fx.gd:360-361`
  (`TalentFx._init`). Jede `TalentFx` löst es aus: die alte Dungeon-Ansicht im Menü und die Talente
  jeder Story-Welt. Das Ergebnis liegt danach in `static var`, also einmal je Programmstart.
- **Jetzt:** 24 Bilder à 256×256 aus `smooth_sheet_24.png`; je Bild eine Flutfüllung vom Rand mit
  `Vector2i`-Warteschlange und `get_pixelv`/`set_pixelv` (65 536 Pixel je Bild, jedes mit 4
  Nachbarn in die Warteschlange), dann eine Zeilensuche mit `get_pixel`. Das läuft für jede Klasse,
  nicht nur für den Nekromanten.
- **Vorschlag A (empfohlen):** die fertigen Bilder einmal per Skript backen
  (`scripts/bake_soul_field.gd`) und als PNG ins Projekt legen; `prepare()` lädt sie nur noch. Die
  Ausschneide-Regel bleibt im Skript für neue Quellbilder. Alternativ (B) dieselbe Flutfüllung auf
  den rohen Bytes (`image.get_data()`, `PackedInt32Array` als Warteschlange) rechnen.
- **Bild:** gleich. Beweis: alle 24 + 24 + 1 Bilder alt gegen neu Byte für Byte vergleichen.
- **Gewinn:** ~2,7 s beim Menüstart (bei A fast alles, bei B geschätzt 2,3–2,6 s). Risiko gering.

### S2. Das Menü lädt alle drei Story-Szenen, nur um einen Pfad zu lesen (~3 s)

- **Wo:** `src/game.gd:2649` (`_build_main_menu` → `_story_worlds`), `src/game.gd:2700-2719`
  (`_scene_theme` macht `load(scene_path)` und liest `theme_path` aus dem `SceneState`).
- **Jetzt:** `load()` einer `.tscn` lädt auch ihr Skript `hell_game.gd` und dessen ~68 Vorlade-Ketten:
  ~3 s Skript-Übersetzung, bevor das Menü erscheint. Zusätzlich wird `story_campaigns.json` zweimal
  gelesen (`src/game.gd:2647` und `:2702`) und je Welt Theme- und Weltpaket-JSON geparst.
- **Vorschlag:** `theme_path` ohne Laden der Szene bestimmen (die drei Pfade stehen fest in den
  `.tscn`; entweder in `story_campaigns.json` mitführen oder die Zeile `theme_path = "…"` aus dem
  Szenentext lesen). Danach die gewählte Story-Szene mit `ResourceLoader.load_threaded_request` im
  Hintergrund vorladen, solange der Spieler im Menü ist (das Projekt nutzt das schon für den Rückweg
  ins Menü, `src/ui/loading_screen.gd:167`).
- **Bild:** Menü gleich (gleiche Einträge; Beweis: `_story_worlds()` alt gegen neu vergleichen).
- **Gewinn:** Menü ~3 s früher. Ohne Hintergrund-Vorladen wandert die Übersetzung in den Story-Start;
  mit Vorladen ist sie meist schon fertig, wenn der Spieler die Klasse gewählt hat. Risiko gering
  (Pfad lesen) bis mittel (Hintergrund-Laden von Skripten).

### S3. Die alte Dungeon-Ansicht wird für das Menü komplett aufgebaut (~5–7 s warm, mehr kalt)

- **Wo:** `src/game.gd:381` (`view = preload("res://src/dungeon_view.gd").new()` in `_ready`),
  `src/dungeon_view.gd:155-219` (`_ready`), Silhouetten `src/dungeon_view.gd:838-846`,
  Sounds `src/dungeon_view.gd:786-796`.
- **Jetzt:** Beim Start entstehen Figuren-Katalog, Rig-Renderer, Atmosphäre, und für jedes Bild der
  alten Helden und Gegner eine weiße Silhouette pixelweise in GDScript (`get_pixel`/`set_pixel`),
  dazu ~800 Bilder und ein voller Sfx mit ~700 Sounds. Das Menü braucht davon nur Musik und
  Klick-Geräusche (`src/game.gd:2964-2967` → `view.play_ui_sound`).
- **Vorschlag:** Die schweren Teile der alten Ansicht erst beim ersten alten Lauf (Lobby, alter
  Dungeon, Editor-Test) vorbereiten: z. B. `view.ensure_assets()` in `_start_solo`/Lobby/Editor;
  Musik und Klicks bleiben sofort da. Einfachere Teilschritte: nur die Silhouetten aufschieben, oder
  `_silhouette` auf Bytes rechnen (gleiches Ergebnis, ~10× schneller).
- **Bild:** Menü gleich. Der alte Dungeon sieht gleich aus, lädt aber beim ersten Betreten länger.
  Der alte Dungeon muss weiter laden (Load-Check plus ein Start).
- **Gewinn:** geschätzt 4–6 s warm vom Menüstart (S1 nicht mitgezählt). Risiko mittel: `game.gd`
  benutzt `view` an 39 Stellen; jede muss vor dem ersten alten Lauf noch funktionieren.

### S4. Feuer- und Brunnen-Animationen werden bei jedem Weltstart neu gerechnet (0,5–0,85 s)

- **Wo:** `src/vfx/fire_anim.gd:35` (`build`), aufgerufen in `src/hell/hell_game.gd:825`
  (`_load_textures`, auch bei jedem Wechsel Pixel/HD über `apply_graphics`, `:840`).
- **Jetzt:** Für jedes Feuer- und Wasserbild der Welt 8 Bilder pixelweise in GDScript
  (19 `get_pixel`/`set_pixel`-Stellen), jedes Mal neu, auch für dieselbe Welt beim nächsten Lauf.
- **Vorschlag:** (a) im Prozess merken (statisch, Schlüssel: Bildpfad, Block, Einstellungen) – hilft
  bei jedem weiteren Lauf, Etagenwechsel nicht betroffen; (b) zusätzlich oder statt dessen auf Bytes
  rechnen; (c) Ergebnis auf Platte zwischenspeichern (`user://cache/`, Schlüssel aus Quell-Hash und
  `vfx_fire_anim.json`).
- **Bild:** gleich. Beweis: alle Bilder und Flammenspitzen (`_tips`) alt gegen neu vergleichen.
- **Gewinn:** 0,5–0,85 s je Weltstart und je Grafikwechsel. Risiko gering.

### S5. Jeder Sfx lädt alle ~700 Sounds sofort (1,2–1,6 s, wenn nicht im Speicher)

- **Wo:** `src/vfx/sfx.gd:156-196` (`reload` → `_add_event` → `load(file)` für jede Variante jedes
  Ereignisses), dazu `audio_library.json` (267 KB) und `audio_sfx.json` (216 KB) je Sfx geparst.
- **Jetzt:** Menü (alte Ansicht) und jede Story-Welt haben je einen Sfx. Solange der erste lebt,
  trifft der zweite den Speicher; beim Rückweg ins Menü wird alles neu geladen.
- **Vorschlag:** Sounds beim Programmstart im Hintergrund anfordern (`load_threaded_request`) und
  beim ersten Abspielen abholen, oder ein gemeinsamer statischer Sound-Speicher für alle Sfx.
- **Ton:** gleich, solange jeder Sound beim ersten Abspielen schon da ist (sonst wartet das erste
  Abspielen kurz). **Bild:** unberührt.
- **Gewinn:** ~1,2 s beim Menüstart (kalt mehr). Risiko gering bis mittel.

### S6. Beim Story-Start friert das Menü ~4 s ein, bevor der Ladebildschirm kommt

- **Wo:** `src/game.gd:2783-2802` (`_open_story_scene`: `add_child(scene)` läuft synchron durch
  `_ready`), Ladebildschirm erst am Ende von `load_floor` (`src/hell/hell_game.gd:1016-1027`).
- **Vorschlag:** Den Ladebildschirm der Welt zuerst zeigen, zwei Bilder warten (wie `_enter_floor`,
  `src/hell/hell_game.gd:1000-1007`), dann die Welt aufbauen.
- **Bild: ändert sich** (der Ladebildschirm kommt früher, statt eines stehenden Menüs). Spart keine
  Rechenzeit, fühlt sich aber schneller an. Nur, wenn du das willst.

### S7. Weltgenerator 0,6–0,95 s je Etage

- **Wo:** `src/hell/hell_game.gd:875` (`world.build_raw`), `src/world_kit/world_pack.gd`,
  `src/world_kit/world_core.gd`.
- **Jetzt:** läuft im Hauptthread; beim Etagenwechsel steht der Ladebildschirm in der Zeit still.
- **Vorschlag:** zuerst mit Messpunkten im Generator die teuren Schritte finden (nicht gemacht).
  Danach: schnellere Schritte bei gleichem Ergebnis (Beweis: gleiche Etage für gleiche Laufnummer,
  `build_raw` alt gegen neu für viele Nummern), oder Generator im Thread, damit der Ladebildschirm
  weiterläuft.
- **Gewinn:** offen (bis ~0,9 s je Etage). Risiko mittel (Zufall und statische Speicher im Thread).

### S8. Skript-Übersetzung beim Menüstart (~9–10 s zusammen)

- **Wo:** `src/game.gd:12-60` (~50 `preload` des alten Spiels: Mehrspieler, Editor, Testraum,
  Cheats, Dungeon-Generator …), `src/dungeon_view.gd:6-66` (~35 weitere), plus S2.
- **Jetzt:** Godot übersetzt alle vorgeladenen Skripte, bevor das Menü erscheint; die Story-Kette
  allein kostet kalt 6–7 s.
- **Vorschlag:** Nur-alt-Module mit `load()` beim ersten Gebrauch statt `preload` (Mehrspieler,
  Editor, Testraum, Cheats); langfristig ein schlankes Menü getrennt vom alten Spiel. Vorher prüfen,
  wie viel ein exportierter Build hier spart (dort liegen die Skripte schon als Tokens vor).
- **Bild:** gleich. **Gewinn:** geschätzt 2–4 s. Risiko mittel bis hoch (viele Stellen, Typen aus
  `preload`-Konstanten werden in Signaturen benutzt).

### S9. Kleinkram beim Start

- `src/game.gd:357`: `dungeon_rooms.json` (1,4 MB) wird bei jedem Menüstart geparst, gebraucht nur für
  den alten Dungeon und die Debug-Liste. Aufschieben (die Datei selbst bleibt unberührt). Gewinn
  ~0,1–0,2 s (nicht gemessen).
- Dieselben Bilder werden beim Anlegen von `game.gd` mehrfach von Platte gelesen
  (z. B. `skelet_idle_anim_f0.png` dreimal), weil niemand sie dazwischen hält. Klein.
- Rückweg ins Menü (`MENU_SCENE` = `res://src/main.tscn`, `src/hell/hell_game.gd:95`) baut das ganze
  Menü samt alter Ansicht neu: S1, S3 und S5 helfen hier mit.

## Spiel: Funde nach Gewinn und Risiko

Vorweg: In den Story-Welten liest nichts pro Bild Dateien oder JSON. Alle Stellen mit `load`,
`JSON.parse`, `FileAccess` in den heißen Dateien merken sich ihr Ergebnis beim ersten Aufruf
(`_room_signs`, `xray`, `gore`, `lexicon`, `_chest_reach`, `skill_sound`, `_gore_table`, `_flask`).
`duplicate(true)` pro Bild gibt es nur noch in `TalentCombat.snapshot`, und das ist seit `1e417341`
einmal je Bild geteilt.

### R1. Partikel-Schleife: dieselben Werte je Partikel mehrfach nachschlagen (3,3–4,8 ms gesamt)

- **Wo:** `src/vfx/particles.gd:2006-2058` (`update`), `:2060-2174` (`_move`).
- **Jetzt:** Je Partikel und Schritt bis zu viermal `_mode(str(particle.get("mode", "")))`, dazu
  `_data.get("wall_bounce"/"wind_air"/"bounce_min"/"bounce"/"ground_friction")` und `_ice(...)` –
  alles Werte, die sich während eines `update` nicht ändern.
- **Vorschlag:** die `_data`-Werte einmal je `update` in Felder holen; den Modus je Partikel einmal
  pro `_move` nachschlagen und weiterreichen. Die Reihenfolge der Würfel (`_rng`) bleibt unberührt.
  (`remove_at` mitten in der Liste bleibt, wie in Runde 2 begründet.)
- **Bild:** gleich. Beweis wie in Runde 2: alte Kopie gegen neu, gleicher Seed, alle Partikelarten,
  600 Schritte, jedes Partikel gleich.
- **Gewinn:** geschätzt 0,5–1,5 ms je Bild bei vielen Partikeln. Risiko gering.

### R2. HUD wird jedes Bild komplett neu gezeichnet (~3,5 ms)

- **Wo:** `src/hell/hell_game.gd:5187-5266` (`_draw_hud`), Texte über
  `src/ui/hud_style.gd:74-81` (je Text Umriss + Text, ggf. Breitenmessung, Farbe per Name).
- **Jetzt:** `hud.queue_redraw()` jedes Bild (`src/hell/hell_game.gd:2835`); alles wird neu
  aufgebaut, auch was sich nicht bewegt (Rahmen, Beschriftungen, Etagen-Panel).
- **Vorschlag:** das HUD in Teil-Controls zerlegen (Heldenleiste, Zauberleiste, Etagen-Panel, Chips)
  und jedes nur neu zeichnen, wenn sich seine Eingaben ändern (Zahlen, Maus, Zeit für Pulsieren).
  Unveränderte Teile behalten ihre Zeichenbefehle, also dasselbe Bild.
- **Bild:** gleich, wenn die Änderungsprüfung alle Eingaben abdeckt; genau das ist das Risiko
  (zeitabhängige Pulse, Hover). Beweis: je Teil Zeichenbefehle alt/neu über viele Bilder vergleichen.
- **Gewinn:** 1–2,5 ms. Risiko mittel bis hoch.

### R3. Leuchten (~1,5 ms Zeichnen + 0,26–0,5 ms `story_glow.frame`)

- **Wo:** `src/vfx/glow.gd`, `src/hero/story_glow.gd` (`frame` ab `:157`, Filter in `frame`, `mark`,
  `_track_strikes`). Gemessen jetzt: `story_glow.frame` 0,50 ms (Krypta, Hölle), 0,26 ms (Frostgruft).
- **Vorschlag:** Lichtlisten nicht jedes Bild neu bauen, nur geänderte Einträge; Filter-Lambdas durch
  eine Schleife ohne neue Listen ersetzen. Erst mit Messpunkten zeigen, wo die 1,5 ms liegen.
- **Bild:** gleich. **Gewinn:** 0,3–1 ms. Risiko mittel.

### R4. Rückstands-Ebene zeichnen (0,9–1,2 ms)

- **Wo:** `_residue_layer.draw` (hinter der Marke `tg.gas_sync`), `src/vfx/pool_paint.gd`.
- **Vorschlag (aus Runde 2):** eine eigene `PoolPaint` mit eigenem Backen statt Neuzeichnen jedes Bild.
- **Bild:** gleich bei exaktem Backen. **Gewinn:** ~0,5–1 ms. Risiko mittel.

### R5. 5–8 ms Skript-Zeit ohne Messpunkt

- **Wo:** vermutlich `src/hell/hell_monsters.gd`, Rigs, `src/hero/story_hero.gd`,
  `src/hero/story_feel.gd` (Teile von `update`).
- **Vorschlag:** zuerst nur messen (vorübergehende `PerfMarks`, danach byte-gleich zurück), dann
  gezielt. Ändert nichts am Spiel. Größter offener Topf.

### R6. Interaktions-Hinweis baut jedes Bild eine Liste aller Etagen-Objekte (0,12–0,16 ms)

- **Wo:** `src/hell/hell_game.gd:1782-1842` (`_interactables`, `_nearest`), aus `_draw_hud`.
- **Jetzt:** für alle 70–120 Objekte der Etage ein Dictionary mit fertigem Text (teils mit
  `%`-Formatierung), dann wird das nächste in Reichweite gesucht.
- **Vorschlag:** in `_nearest` erst Abstand und Reichweite prüfen, den Text nur für das gewählte
  Objekt bauen. `_interactables()` bleibt für andere Aufrufer.
- **Bild:** gleich (Beweis: `_nearest()` alt/neu an vielen Heldenpositionen). Gewinn ~0,1 ms. Risiko gering.

### R7. Inventar-Schnappschuss jedes Bild, auch bei geschlossenem Fenster (0,08 ms)

- **Wo:** `src/hell/hell_game.gd:2820-2822`, `src/hero/story_items.gd:217-228`.
- **Vorschlag:** nur neu bauen, wenn sich das Inventar geändert hat (Zähler in `story_items`).
- **Gewinn:** ~0,08 ms. Klein, nur zusammen mit anderem.

### R8. Die ersten Bilder nach dem Laden einer Etage (0,1–0,8 s je Bild)

- Gemessen: Hölle 0,4–0,77 s für die ersten zwei Bilder, Krypta 0,15–0,57 s, Frostgruft
  0,08–0,11 s; nach Etagenwechsel in der Hölle 0,41–0,53 s. Im normalen Spiel liegt der
  Ladebildschirm darüber, man sieht kein Ruckeln. Ursache nicht untersucht (erste Zeichnung der
  Chunks, Shader). Niedrige Priorität.

## Empfohlene Reihenfolge

1. **S1** Seelenfeld backen: ~2,7 s Start, Bild bewiesen gleich, wenig Risiko.
2. **S2** Story-Pfade ohne Szenenladen, Story-Szene im Hintergrund vorladen: Menü ~3 s früher.
3. **S4** Feuer-Animation merken bzw. schneller rechnen: 0,5–0,85 s je Weltstart.
4. **R1** Partikel-Schleife: 0,5–1,5 ms je Bild, gleiche Prüfung wie Runde 2.
5. **S3** alte Ansicht erst bei Bedarf: größter Brocken (4–6 s), aber mehr Aufwand.
6. **S5** Sounds im Hintergrund.
7. **R5** messen, dann R2/R3/R4 je nach Ergebnis.

S6 (Ladebildschirm früher) ändert das Bild und ist deine Entscheidung. S1 bis S4 zusammen: Menü
geschätzt von ~21 s auf ~12 s (warm), Story-Start etwa gleich oder schneller.

## Nachtrag: FPS im Spiel und Ruckeln (2026-11-05, Mittag)

Ziel des Nutzers: mehr FPS im Spiel und ein flüssiges Bild ohne Zittern und Hänger.

### Hauptursache: Nachhol-Spirale des festen 60-Hz-Takts

Seit `09ce07d1` (03.11., `docs/FESTER-SIMULATIONSTAKT.de.md`) rechnet die Story-Welt feste
Schritte zu 1/60 s und holt pro Bild bis zu 8 Schritte nach (`assets/data/physics_clock.json`,
`src/physics_kit/fixed_step_clock.gd`, `src/hell/hell_game.gd:2795-2835`). Vorher lief genau ein
`_update(min(delta, 0.05))` je Bild. Kostet ein Schritt fast so viel wie die 16,7 ms, die er
simuliert, wird jedes langsame Bild noch langsamer, weil es mehr Schritte nachholen muss.

`scripts/bench_story.gd` (Feuermagier, 8 Gegner), heute, Kopie mit Schrittzähler:

| Welt | ms je Bild (Mittel / p95 / Max) | Schritte je Bild (Mittel / Max) |
|---|---|---|
| Krypta | 33,6–56,9 / 62–124 / 116–170 | 3,2 / 8 |
| Hölle | 62,4–73,9 / 130–153 / 206–217 | 3,6 / 8 |
| Frostgruft | 110,5–128,7 / 162–215 / 258–281 | 6,0 / 8 |

Zum Vergleich am 02.11. (ein Schritt je Bild): 23 / 28 / 33 ms. Die Anzahl der Schritte schwankt
von Bild zu Bild zwischen 1 und 8. Das ist das sichtbare Ruckeln: ungleich lange Bilder und dazu
Geschosse, Begleiter und Partikel, die ohne Zwischenbilder einmal einen und einmal acht Schritte weit
springen. Held, Gegner und Kamera bekommen in den noch nicht committeten Änderungen einer anderen
Sitzung (`docs/KAMERA-STABILITAET.de.md`) schon Zwischenbilder.

Die Werte schwanken stark, weil während der Messung **Deadlock** lief (5,3 GB, hohe CPU-Last). Saubere
Zahlen gibt es nur mit geschlossenem Spiel; abwechselnd alt/neu gemessen bleibt der Vergleich fair.

### Hebel in Reihenfolge

1. **Nachholen begrenzen** (Entscheidung): `max_steps_per_frame` 8 → 2 (oder 3) und ältere
   Restzeit verwerfen. Dann gibt es keine Spirale mehr, die Bildzeit bleibt bei Zeichnen plus höchstens
   zwei Schritte. Preis: Bei Überlast läuft das Spiel kurz etwas langsamer, statt zu stocken.
   Jedes einzelne Bild sieht gleich aus.
2. **Kosten je Schritt senken, Bild bewiesen gleich:** Jede Millisekunde pro Schritt spart 2–8 ms pro
   Bild. Größte Posten je Bild in der Spirale: `u.feel` (Partikel) 7,8 / 22 / 35 ms, `u.talents`
   Frostgruft 27 ms, `u.rigs` 0,9–4,3 ms, `u.zones+world` Frostgruft 6,8 ms, `u.mobs` Frostgruft 6,5 ms.
   Zuerst R1 (Partikel), dann `u.talents` der Frostgruft mit Messpunkten aufschlüsseln.
3. **Gleichmäßiger Takt** (Entscheidung): Optional eine Bildraten-Grenze (60 oder stabil 30), damit
   jedes Bild gleich viele Schritte bekommt. Ruhiger, aber bei 30 weniger Bilder.
4. **Zwischenbilder auch für Geschosse, Begleiter und Partikel**: erst nach 1 und 2; bei stabilen
   60 FPS mit einem Schritt je Bild ist das nicht mehr nötig.

## Umsetzung (2026-11-05, nach „Ja, beides“)

### Was geändert ist

- `assets/data/physics_clock.json`: `max_steps_per_frame` 8 → 2, neu `max_pending_steps` 3.
- `src/physics_kit/fixed_step_clock.gd`: neues Feld `max_pending_steps`. Zeit über so viele Schritte
  verfällt in `begin_frame`; 0 (Code-Standard) behält alles wie bisher.
- `src/vfx/particles.gd`: Die Partikel-Schleife liest die Einstellungen (`wall_bounce`, `wind_air`,
  `bounce_min`, `bounce`, `ground_friction`, `z_ease`, Eiswerte) einmal je `update`
  (`_step_settings`), den Modus und „ist Splitter“ einmal je Partikel, die Lebenszeit einmal.
  Rechenweg und Reihenfolge sind unverändert.
- Tests: `tests/story_clock_test.gd` hat 5 neue Prüfungen zur Restzeit-Grenze; vor der Änderung schlugen
  2 davon fehl. `tests/story_clock_integration_test.gd` erwartet jetzt die neue Regel
  (15 FPS → 0,5 s Spielzeit je Sekunde), der Hitstop läuft über 6 einzelne Bilder.
- `docs/FESTER-SIMULATIONSTAKT.de.md`: Tabelle und Grenzen nachgetragen.

### Beweise

- Partikel alt (Kopie von HEAD) gegen neu: gleicher Raum mit Wandsäule, gleiche Würfe aller 16
  Modi plus unbekanntem Modus, Splitter, Funken, Glut, Flammen, Schnee, Rauch, Dampf, Tropfen,
  Geröll, Seelenstrom, Schädel/`z_to`/Rauchrest/Fels-Markierungen, Wind an/aus, 600 Schritte,
  ~403 000 Partikel-Schritte: **jede Member-Variable nach jedem Schritt gleich** (Partikel, Glut,
  Pfützen, Boden-Pixel als Bytes, Zufallszustand), 21 600 Vergleiche, 0 Abweichungen.
  Gegenprobe: dieselbe Datei mit `bounce` × 1,0001 wird ab Schritt 9 als abweichend gemeldet.
- Tests: `story_clock_test` 23/0, `story_clock_integration_test` 63/0 und `--realtime` 6/0,
  `particles_physics_test` 26/0. Load-Check `particles.gd`, `fixed_step_clock.gd`,
  `hell_game.gd`, `game.gd` OK.
- Bild: `fps-2026-11-05-frostgruft-neu.png` (Kampf in der Frostgruft mit neuem Stand).

### Messung (abwechselnd, Deadlock lief weiter im Hintergrund)

Bench-Kopie mit zwei Korrekturen: gezaubert wird alle 0,3 s **Spielzeit** (vorher Echtzeit; bei
langsamerer Welt kamen sonst mehr Zauber je Spielsekunde), dazu Hänger und Bildsprünge.
Reihenfolge A2 B2 C2, dann C3 B3 A3. A = alter Takt, alte Partikel; B = neuer Takt, alte Partikel;
C = neuer Takt, neue Partikel. Je Zelle: Mittel der zwei Läufe.

| Welt | | ms je Bild | Bilder >100 ms (je 8 s) | längstes Bild | Weltgeschwindigkeit | Bildsprung Ø |
|---|---|---|---|---|---|---|
| Krypta | A | 35,6 | 3 | 154–199 ms | 0,96 | 7,5 ms |
| | B | 36,3 | 1 | 107–127 ms | 0,82 | 6,4 ms |
| | C | 33,9 | 1,5 | 117 ms | 0,85 | 6,4 ms |
| Hölle | A | 46,2 | 5,5 | 185–258 ms | 0,95 | 8,2 ms |
| | B | 46,1 | 7,5 | 145–148 ms | 0,68 | 9,1 ms |
| | C | 44,2 | 8,5 | 137 ms | 0,70 | 7,6 ms |
| Frostgruft | A | 72,4 | 16,5 | 168–175 ms | 0,96 | 12,6 ms |
| | B | 47,4 | 2 | 133–145 ms | 0,68 | 9,2 ms |
| | C | 43,9 | 3,5 | 144–148 ms | 0,73 | 8,5 ms |

Partikel (`u.feel` je Bild, B → C): Krypta 7,6 → 6,9, Hölle 9,2 → 8,7, Frostgruft 8,7 → 7,2 ms.

**Ehrliche Einordnung:**

- Die Frostgruft gewinnt klar: 13,8 → 22,8 FPS, Hänger über 100 ms von ~16 auf ~3 je 8 s.
- In Krypta und Hölle bleibt die Bildrate etwa gleich. Die schlimmsten Hänger werden kürzer
  (bis 258 ms → bis 148 ms). In der Hölle gibt es aber etwas mehr Bilder über 100 ms (5,5 → 8,5
  je 8 s), und in diesem schweren Bench läuft die Welt langsamer: Krypta mit 85 %, Hölle mit
  70 % der Echtzeit.
- Ein Spielschritt kostet auf diesem Rechner mit Deadlock im Hintergrund 11–20 ms. Damit sind
  30 FPS in Echtzeit im schweren Kampf nicht erreichbar, egal wie der Takt eingestellt ist.
- Die Partikel-Änderung spart 0,5–1,5 ms je Bild, bei gleichem Bild.
- Stellschraube: `max_steps_per_frame` 3 / `max_pending_steps` 4 hält die Welt bis 20 FPS in
  Echtzeit. Die Bilder werden dann länger als mit 2, aber es gibt weiter keine Spirale bis 8.
- Für echte Bildrate und weniger Zeitlupe müssen die Kosten je Schritt sinken: als Nächstes die
  5–8 ms ohne Messpunkt und `u.talents` der Frostgruft aufschlüsseln, danach HUD und Leuchten
  (je Bild).

## Aufschlüsselung pro Bild (2026-11-05, Nachmittag)

Drei Messrunden mit vorübergehenden Messpunkten. Jede Hülle misst mit eigener Uhr und damit
verschachtelungssicher. Danach wurden alle Dateien aus der Sicherung zurückgeschrieben und per
Prüfsumme als byte-gleich bestätigt (16 Dateien, 0 Abweichungen). Neuer Takt (2/3), Zaubern nach
Spielzeit, Deadlock lief weiter. ms je Bild bei ~1,85 Spielschritten je Bild:

| Teil | Krypta | Hölle | Frostgruft |
|---|---|---|---|
| **Bild gesamt** | 44,3 | 51,5 | 51,0 |
| Spielschritte (`_step_simulation`) | 17,1 | 19,1 | 23,1 |
| davon Partikel-Simulation (`particles.update`) | 8,7 | 9,8 | 6,8 |
| davon Talent-Schritt (`tc.step`) | 1,7 | 1,2 | **6,6** |
| davon Rigs / Gegner / Welt | 2,5 | 3,9 | 4,6 |
| Licht-Vorbereitung (`story_glow.frame`) | 0,8 | 0,8 | 0,5 |
| **Zeichnen gesamt** | 23,6 | 28,5 | 22,8 |
| davon Akteur-Ebene (`_draw_actors`) | 13,3 | 23,2 | 14,4 |
| … Talent-Effekte (`draw_world` + `draw_over`) | 4,3 | 5,6 | 5,1 |
| … Rig-Teile unter den Figuren (`drake_rig.draw_under` u. a.) | 2,0 | **7,5** | 0,9 |
| … Partikel-Bänder: Filtern + Sortieren (`begin_bands`) | 1,6 | 2,5 | 1,2 |
| … Partikel-Bänder: Zeichnen (`draw_band`) | 1,8 | 2,6 | 1,5 |
| … Held | 1,7 | 2,0 | 1,8 |
| … Gegner | 0,4 | 0,5 | 2,5 |
| HUD | 3,3 | 3,1 | 3,0 |
| Licht zeichnen (`glow.gd`) | 2,1 | 2,3 | 1,7 |
| Partikel-Ebenen (`FeelLayer`) / Geschoss-Ebenen (`ShotLayer`) | 1,2 / 1,1 | 1,4 / 0,9 | 1,3 / 1,0 |
| Schneesturm (`_process` + Zeichnen) | – | – | 2,2 |
| Engine, Rendern, Rest | 2,3 | 2,5 | 2,4 |

Die Zeilen der Akteur-Ebene („…“) stammen aus der dritten Runde (Bild 37 / 56 / 50 ms), alle
anderen aus der zweiten. Deshalb lassen sie sich nicht exakt aufsummieren.
Die Grafikkarte ist mit 0,4–2 ms nie der Engpass. Fast alles ist GDScript: Simulation und das
Aufbauen der Zeichenbefehle.

### Vorschläge, Bild jeweils bewiesen gleich

1. **Partikel-Bänder** (`particles.gd` `begin_bands`/`draw_band`): Filtern ohne Lambda, gleicher
   Sortiervergleich ohne Umwandlungen (gleicher Algorithmus, gleiche Vergleiche, also gleiche
   Reihenfolge), Bänder per Indexbereich statt `slice`-Kopie. ~0,7–1,5 ms.
2. **Partikel-Simulation** (7–10 ms): erst die Teilschritte messen (`_steer_souls`, `_spread_pools`,
   `_burn_embers`, Hauptschleife …), dann den größten angehen. Zählt doppelt (2 Schritte je Bild).
3. **Talent-Schritt der Frostgruft** (6,6 ms): aufschlüsseln, vermutlich eine Schleife über alle
   Gegner oder das Eis.
4. **Schneesturm** (2,2 ms): reine Schleife, ohne Bildänderung beschleunigen.
5. **Rig-Teile Hölle** (7,5 ms): `rig_renderer.gd` hat noch nicht committete Änderungen der
   Kamera-Sitzung, deshalb erst nach deren Commit.
6. **HUD, Licht, Talent-Effekte** (je 2–5 ms): größerer Umbau (Teile nur bei Änderung neu zeichnen).

Mit 1 bis 4 geschätzt 5–9 ms weniger je Bild (44–51 → ~38–44 ms). Für 60 FPS im schweren Kampf
(16,7 ms) reicht Feinschliff nicht. Dafür müssten Partikel und Effekte gebündelt gezeichnet werden
(MultiMesh oder ein Shader) oder die Partikel-Simulation in nativen Code (GDExtension). Das ist ein
eigener, größerer Schritt mit neuer Bildabnahme.

## Umsetzung Punkte 1–4 (2026-11-05, Abend)

Zwei weitere Messrunden (vorübergehend, danach byte-gleich zurück) fanden die Ursachen:

- **Partikel-Update:** fast alles ist die Hauptschleife (4,7–6,6 ms je Bild). Darin legte `solid()` je
  Partikel und Schritt ein leeres Array als Ersatzwert an.
- **Frostgruft-Talentschritt:** nicht Wegsuche oder Zielwahl (< 0,3 ms), sondern `_hurt_pet`
  (3,3 ms je Bild). Gegner treffen den Begleiter, und `RigLibrary.nearest_part` sucht das getroffene
  Teil mit `reach` 48: Je Teil wurde ein Fenster von etwa 51×51 Pixeln per `get_pixelv` geprüft.

### Was geändert ist

- `src/vfx/particles.gd`:
  - `begin_bands` filtert mit einer Schleife statt Lambda und sortiert mit `_floor_y_before` (gleicher
    Vergleich ohne Umwandlungen).
  - `draw_band` übergibt einen Indexbereich statt einer `slice`-Kopie (`draw_particles` hat dafür
    `from`/`to`).
  - `solid()` fragt die Wandboxen nur, wenn es welche gibt (in den Story-Welten nie), mit
    gemeinsamem leerem Ersatz `_NO_WALLS`.
- `src/rig/rig_library.gd` `_pixel_distance`: Das Suchfenster wird auf `image.get_used_rect()`
  zugeschnitten. Jeder Pixel außerhalb ist ganz durchsichtig und wurde vorher übersprungen. Zeilen
  und Spalten laufen in derselben Reihenfolge, also gewinnt bei Gleichstand dasselbe Teil. Das wirkt
  auf alle Teil-Treffer: Begleiter, Gegner-Rigs, Bosse.
- `src/vfx/snowstorm.gd`: Die Einstellungen (`fall`, `size`, `alpha`, Sturmfaktoren, Kamera-Schub)
  werden einmal vor der Flocken-Schleife gelesen. Die Rechenausdrücke bleiben in derselben
  Reihenfolge, also bitgleich.

### Beweise

- Partikel alt (Stand nach Runde 1) gegen neu: 600 Schritte, ~403 000 Partikel-Schritte, alle Member
  nach jedem Schritt und alle 25 Schritte die Band-Reihenfolge gleich. Das in eigene Viewports
  gezeichnete Bild (Bänder zwischen Linien, dann die hohen Partikel) ist Byte für Byte gleich.
  0 Abweichungen bei 28 225 Vergleichen.
- Teil-Treffertest: alter Code (Kopie) gegen neuen über alle 74 Rigs, jedes Teil und Item, 57 744
  Proben (10 689 Treffer), Radien von 0,5 bis 48 px: 0 Abweichungen; 4,8 s → 0,7 s (6,7× schneller).
- Schneesturm alt gegen neu: 900 Schritte mit Böen, Sturm und Kamerafahrt, 850 Flocken, alle Member
  jedes Schritts gleich, 5 Bilder Byte für Byte gleich.
- Tests: `particles_physics` 26/0, `rig_library` 163/0, `hell_rig_library` 352/0,
  `body_parts_weakens` 66/0. Load-Check `particles.gd`, `rig_library.gd`, `snowstorm.gd`,
  `hell_game.gd`, `game.gd` OK.

### Messung (abwechselnd O1 N1 N2 O2, neuer Takt, Deadlock aus)

| Welt | alt | neu | FPS |
|---|---|---|---|
| Krypta | 22,5 ms | 22,0 ms | 44 → 45 |
| Hölle | 28,0 ms | 27,4 ms | 36 → 36,5 |
| Frostgruft | 32,3 ms | **25,9 ms** | 31 → **39** |

Weltgeschwindigkeit mit neuem Stand: Krypta 93 %, Hölle 88 %, Frostgruft 93 % der Echtzeit
(1,2–1,5 Schritte je Bild; verloren wird nur in Ausreißern über 33 ms). Mit `max_steps_per_frame`
3 / `max_pending_steps` 4 bliebe die Welt jetzt näher an der Echtzeit, ohne Spirale bis 8.

Zum Vergleich mit dem Nachtrag oben: Diese Zahlen sind ohne Deadlock gemessen, die früheren mit. Sie
lassen sich deshalb nicht direkt gegenüberstellen.

## Hinweise zur Messung

- Ein Lauf je Zahl; die Zeiten schwanken stark mit dem Datei-Cache von Windows (Story-`_ready` kalt
  26,6 s, warm 8,2 s; Menü-`_ready` kalt 23,6 s, warm 12,4 s).
- Gemessen im Editor-Binary mit Testskript, nicht im exportierten Spiel; dort kann vor allem die
  Skript-Übersetzung (S8) anders ausfallen.
- Die Einzelteile (Feuer, Generator, Seelenfeld) sind auf der laufenden Welt ein zweites Mal
  aufgerufen; die Zahlen gelten also bei schon geladenen Bildern.
- Das Messskript schreibt nichts ins Projekt; Testprofil und Test-Einstellungen wie in
  `scripts/bench_story.gd` (das angelegte `user://profile_test.json` danach wieder gelöscht).
- Zeilennummern und Messungen gelten für den Arbeitsstand vom 2026-11-05 11:50, also mit den noch
  nicht committeten Änderungen anderer Sitzungen in `hell_game.gd`, `hell_monsters.gd`,
  `story_glow.gd`, `story_hero.gd`, `rig_renderer.gd` u. a.
