# Story-Welten: Rechenzeit, erste Runde (2026-11-02)

Messung mit `scripts/bench_story.gd` (neu): Krypta, Hölle, Frostgruft auf `src/hell/hell_game.gd`,
Feuermagier mit allen Feuertalenten, Leiste und Ultimate im Wechsel alle 0,3 s, 8 Gegner,
8 s nach 1 s Aufwärmen, V-Sync aus, 1280x720. Einzelläufe: `story-vorher.md`, `story-nachher.md`.

## Wo die Zeit hingeht

| Welt | Frame Mittel | Logik und Zeichnen | Rendern (CPU) | Grafikkarte | Rest |
|---|---|---|---|---|---|
| Krypta | 23,4 bis 24,9 ms | 22,1 ms | 1,1 ms | 0,45 ms | 0,15 ms |
| Hölle | 28,2 bis 29,2 ms | 26,7 ms | 1,3 ms | 0,46 ms | 0,18 ms |
| Frostgruft | 32,1 bis 34,4 ms | 32,6 ms | 1,6 ms | 0,53 ms | 0,24 ms |

Fast alles ist Skript-Zeit (GDScript, Logik und `_draw`). Die Grafikkarte ist nicht der Engpass.
Größte gemessene Teile je Frame (Krypta / Hölle / Frostgruft):

- HUD 4,6 ms: Zauberleiste 2,0, Heldenleiste 1,4, Chips und Hinweis 0,7, Etagen-Panel 0,3
- Partikel-Simulation (`u.feel`) 3,3 / 4,0 / 4,4 ms
- Leuchten (`glow.gd` mit `story_glow.draw`) 1,4 bis 1,5 ms; `story_glow.frame` 0,4 bis 0,6 ms
- Talent-Pfützen und -Wolken abgleichen (`tg.pools_sync`, `tg.gas_sync`) zusammen 1,6 bis 2,0 ms
- Partikel-Ebenen zeichnen (`story_feel`) ~1 ms
- Frostgruft: Zonen, Fallen, Schnee, Gold, Räume (`u.zones+world`) 1,25 ms
- Etwa 5 bis 8 ms Skript-Zeit sind noch keinem Messpunkt zugeordnet.

## Diese Runde (ohne Bildänderung)

- Der Talentstand für das HUD (`hell_talents.hud_state`, 0,28 ms je Aufruf) wird während einer
  HUD-Zeichnung nur einmal berechnet statt dreimal (Zauberleiste, Ressourcenleiste, Begleiter);
  ebenso die Laufpunkte (`hell_game._run_points_left`). Der Merker gilt nur während `draw_hud`
  und wird danach gelöscht. Geprüft: gemerkter Stand gleich frisch berechnetem; nächste Zeichnung
  rechnet neu; Tests grün.
- Messpunkte (`PerfMarks`) in `hell_game.gd`: Abschnitte von `_update`, die Zeichen-Ebenen,
  `story_glow.frame` (zwei Uhrzeit-Abfragen je Teil).

Nachher: Krypta 22,5 / 23,9 ms, Hölle 27,0 / 27,0 ms, Frostgruft 31,7 / 32,5 ms (zwei Läufe),
also etwa 1 bis 1,5 ms je Frame weniger.

Ein Pixelvergleich des ganzen Bildes ist nicht möglich: die Welten laufen auch mit festem Seed und
festen Frames nicht bitgleich (eigene Zufallsgeneratoren, Hintergrund-Threads der Pfützen). Die
Änderung ist reines Merken innerhalb einer Zeichnung, die Abnehmer lesen nur.

## Nächste Hebel (wenn wieder Kontingent da ist)

1. Partikel-Simulation (3 bis 4,4 ms): Schleife über Dictionaries; Kandidaten: Entfernen ohne
   `remove_at` mitten in der Liste (Reihenfolge erhalten), Werte einmal lesen, Wände je Zelle merken.
2. HUD-Zeichnung (noch ~3,5 ms): viele Texte mit Umriss je Frame; statische Teile (Rahmen,
   Beschriftungen) in ein Bild backen und nur bei Änderung neu zeichnen.
3. Leuchten (1,5 ms): Lichtlisten je Frame neu gebaut; nur geänderte neu rechnen.
4. Talent-Pfützen/-Wolken abgleichen (bis 2 ms): Einträge nur neu bauen, wenn sich Zonen ändern.
5. Die 5 bis 8 ms ohne Messpunkt zuordnen (weitere Marken in hell_monsters, Rigs, story_hero).

# Zweite Runde (2026-11-02, ohne Bildänderung)

## Was die Hebel 4 und 1 wirklich kosteten

Feinere Probe-Marken (danach wieder entfernt) zeigten: Die Talent-Pfützenliste ist im Bench leer;
`tg.pools_sync` ist fast ganz der Abgleich der Rückstands-Pfützen (~13 je Frame, billig), und davon
wiederum fast alles die Form neuer Rückstände (~0,3 je Frame, je ~4 bis 5 ms Flutfüllung). Die
Flutfüllung fragt je Zelle `hell_game._floor_open` → `box_blocked`, und `box_blocked` ging bei jedem
Aufruf **alle** zerstörbaren Objekte der Etage durch (32 bis 37 Kisten, Siegel, Schädelhaufen):
19 bis 31 µs je Aufruf, 35 bis 67 Aufrufe je Frame (Pfützen, Gas, Monster, Rigs, Gold).
`tg.gas_sync` misst übrigens auch das Zeichnen der Rückstands-Ebene (die Marke steht hinter
`pools.draw`/`_residue_layer.draw`); der eigentliche Gas-Abgleich ist ~0,01 ms.

## Änderungen

- `src/hell/hell_game.gd`: `box_blocked` fragt die zerstörbaren Objekte über ein Raster
  (`_index_breakables`, einmal in `load_floor` gebaut, danach nur gelesen, also auch für die
  Pfützen-Threads sicher). Jedes Objekt steht unter jeder Zelle (96 px), die seine Box berührt,
  Kanten eingeschlossen; die Anfrage liest die Zellen ihrer Box, Kanten eingeschlossen, und prüft
  dort genau wie vorher (`not broken and _breakable_box(e).intersects(box)`). Warum gleich: Schneidet
  die Box ein Objekt, haben beide einen gemeinsamen Punkt, und dessen Zelle liegt in beiden
  Zellbereichen. Für eine andere oder gewachsene Liste (Tests hängen Kisten an), negative oder
  unendliche Größen und Boxen über mehr als 16 Zellen bleibt die alte Schleife über alle.
  `solid_grid.get(…, [])` baut kein leeres Array mehr je Zelle (`_NOTHING`).
- `src/vfx/particles.gd`: `_mode` und `_ice` bauen ihr Ersatz-Dictionary nur noch, wenn der Modus
  fehlt (ein `.get`-Default wird in GDScript bei jedem Aufruf gebaut, `_move` fragt `_mode` für jedes
  Partikel jedes Frame). Zurück kommt dasselbe Dictionary wie vorher.
- Nicht gemacht: Partikel ohne `remove_at` mitten in der Schleife entfernen. `emit` in der Schleife
  kann über `_evict` vorne Einträge entfernen und damit die Indizes verschieben; das exakt
  nachzubauen lohnt das Risiko für geschätzt <0,1 ms nicht.

## Beweis gleicher Ergebnisse

- `box_blocked` alt gegen neu in allen drei Welten, zwei Mal mit verschiedenen Etagen: 39 540 und
  39 270 Boxen (Zufall, rund um jedes Objekt, genau auf Objekt- und Zellkanten ±0,001, Größe 0,
  negativ, riesig; ein Drittel der Objekte zerbrochen; eine Kiste nachträglich angehängt):
  0 Abweichungen, 4 802 bzw. 4 765 davon von einem Objekt getroffen. Je Aufruf 19 bis 31 µs → 3,6
  bis 4,8 µs.
- Partikel alt (Kopie) gegen neu, gleicher Seed, gleiche Würfe (Trümmer, Funken an der Wand, Glut,
  Flammen, Eissplitter, Schnee, Rauch, Dampf, Tropfen, unbekannter Modus), Wind an und aus, Puffer
  voll: 600 Schritte, ~460 000 Partikel-Schritte, jedes Partikel, Würfelzustand, Bodenpixel,
  Pfützen und Glut gleich.
- Load-Check `hell_game.gd`, `particles.gd`, `game.gd` OK. Tests grün: pool_field, particles_physics,
  story_player_fx, story_skill_fx, krypta_world, frost_runtime, hell_monsters_integration,
  hell_talents. Bekannte Altfehler unverändert: talent_combat 41, story_glow „ember bloom“.

## Messung

Die getrennten Vorher-/Nachher-Läufe (`story-runde2-vorher1/2.md`, `story-runde2-nachher1/2.md`)
taugen nicht für die Summe: im Nachher-Lauf waren auch unberührte Teile (Rendern in der Engine,
Leuchten) 10 bis 15 % langsamer. Deshalb abwechselnd alt, neu, alt, neu gemessen
(`story-runde2-ab-*.md`), ms je Frame:

| Welt | alt 1 | neu 1 | alt 2 | neu 2 | Mittel alt → neu |
|---|---|---|---|---|---|
| Krypta | 25,98 | 22,79 | 25,25 | 23,74 | 25,6 → 23,3 (−2,4) |
| Hölle | 29,34 | 26,81 | 29,70 | 28,64 | 29,5 → 27,7 (−1,8) |
| Frostgruft | 35,47 | 32,04 | 35,57 | 34,70 | 35,5 → 33,4 (−2,2) |

Messpunkte (Mittel alt → neu, Krypta / Hölle / Frostgruft): `tg.pools_sync` 0,93→0,45 /
1,19→0,54 / 1,40→0,64; `u.feel` 3,79→3,34 / 4,45→4,01 / 5,36→4,81; `u.mobs`+`u.rigs` 0,57→0,46 /
0,95→0,79 / 1,83→1,27. Unberührt und gleich geblieben: `glow.frame`, `u.hero+items`.

## Nächste Hebel

1. Rückstands-Ebene zeichnen (`tg.gas_sync`, eigentlich `_residue_layer.draw`, 0,9 bis 1,2 ms): eine
   zweite `PoolPaint` neben der der Welt, mit eigenem Backen.
2. Partikel-Schleife (`u.feel` noch 3,3 bis 4,8 ms): weitere Dictionary-Lesungen je Partikel.
3. HUD-Zeichnung (~3,5 ms) und Leuchten (1,5 ms) wie in Runde 1 beschrieben.
