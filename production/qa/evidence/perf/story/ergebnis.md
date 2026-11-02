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
