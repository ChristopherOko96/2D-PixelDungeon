# Hell-Dungeon

Stand 28.10.2026. Neuer Einzelspieler-Modus mit zehn Etagen im Höllenstil aus `rooms.zip`.
Start: Hauptmenü → **HELL-DUNGEON (NEU)**, `Hell-Dungeon.cmd` oder `scripts/Dev.ps1 HellDungeon`.
Spielfigur und Gegner sind Platzhalter; Monster werden später gesondert entworfen.

## Regeln

- **Kampfräume** (alle außer Eingang, Schlüssel-, Schatz-, Tresor-, Geheim- und Portalraum) verriegeln beim
  Betreten alle Türen; der Sieg öffnet sie wieder. Danach fällt oft ein Herz oder ein Runenstein.
- **Farbschlüssel:** Glut (Hauptweg, fällt in einem Seitenraum vor dem Tor), Knochen (Beutekammer), Dämon
  (Bosstor). Jeder passt nur in sein Tor, man kann sich nicht aussperren.
- **Feuerschalen** sind über mehrere Räume der Etage verteilt. Brennen alle, öffnet sich das Gitter zum
  **Riesentresor** (Lichtstrahlen, +1 Herzcontainer, volle Gesundheit, Runensteine).
- **Druckplatten:** leuchten nacheinander auf; in dieser Reihenfolge betreten öffnet einen Geheimraum.
  Ein falscher Schritt löscht alle Platten.
- **Geheimwand:** Risse und Geröll, mit E aufbrechen.
- **Kürzester Weg:** Der Boss ist nie erst nach allen Räumen erreichbar (11–17 von 22–31 Räumen,
  geprüft in `tests/hell_floor_data_test.gd`). Erkunden bringt Tresore, Herzen und Runensteine.
- **Tiefe:** mehr Lava, Stacheln und Schlote, zähere und schnellere Gegner, ab Etage 4 Feuerspucker,
  Bosse mit Feuerringen; Zwischenbosse auf 3, 6 und 9, der Höllenfürst auf 10. Optik: dunkler, roter Schleier.

Steuerung: WASD laufen, Pfeiltasten oder linke Maustaste schießen, E/Leertaste Aktion, M Karte,
L Licht, R Etage neu, 1–0 Etage wählen, Esc Hauptmenü.

## Aufbau

| Teil | Ort |
| --- | --- |
| Etagen-Kern, Generator, Bild-Werkzeuge, Browser-Vorschau | `tools/hell_dungeon/` (siehe README dort) |
| Gebackene Etagen | `assets/data/hell_floors.json` (aus `bake_floors.js`) |
| Spielwerte | `assets/data/hell_balance.json` |
| Grafiken (134, Weltmaßstab) | `assets/sprites/hell/` mit `manifest.json` und `LICENSE-NOTE.md` |
| Laufzeit | `src/hell/hell_game.gd` (Szene `hell_dungeon.tscn`), `hell_floor_data.gd`, `hell_walls.gd`, `hell_rules.gd` |
| Tests | `tests/hell_floor_data_test.gd`, `tests/hell_walls_test.gd`, `tests/hell_rules_test.gd` |
| Nachweise | `production/qa/evidence/hell-dungeon/` (`scripts/capture_hell_dungeon.gd`) |

Der Modus ist bewusst vom vernetzten Krypta-Spiel (`src/game.gd`) getrennt: kein Host, keine Snapshots.

## Schema `assets/data/hell_floors.json`

`{ schema: 1, source, floors: [...] }`, ein Eintrag je Etage:

| Schlüssel | Bedeutung |
| --- | --- |
| `n`, `title`, `circle`, `final` | Etagennummer 1–10, Name, Kreis, letzte Etage |
| `theme` | `dark` (Deckkraft der Dunkelheit 0–1), `grade` (Rotschleier 0–1), `vignette` (Randrot 0–1), `embers` (Funken je Frame über Lava), `hot` (Anteil glühender Bodenplatten 0–1), `wall_glow`, `circle` |
| `boss` | `name`, `hp` (Trefferpunkte), `summon` (Sekunden zwischen Beschwörungen), `ring` (Sekunden zwischen Feuerringen, 0 = keine), `mini`, `final` |
| `diff` | `hp` und `speed` (Faktoren auf die Gegnerwerte), `extra` (zusätzliche Gegner je Raum), `shooters` |
| `cols`, `rows`, `cell` | Kartengröße in Zellen, Zellgröße in Pixeln (96) |
| `grid` | ein Zeichen je Zelle: 0 leer, 1 Boden, 2 Lava, 3 Brücke |
| `holes` | 1 = Mauerinsel innerhalb eines Raums |
| `tiles`, `tile_names` | Bodenplatte je Zelle als Base-36-Ziffer in `tile_names` |
| `room_at` | Raumindex je Zelle, −1 für Gänge und Leere |
| `quick` | Räume auf dem kürzesten Weg zum Boss inklusive nötiger Schlüssel |
| `rooms[]` | `index`, `id`, `name`, `kind`, `type` (start, combat, key, treasure, secret, boss, portal), `icon`, `icon_key`, `bx`/`by`/`bw`/`bh` (Begrenzung in Zellen), `mobs`, `drop` (Schlüssel A/B/C), `reward`, `spawn`, `cleared`, `info`, `on_path` |
| `doors[]` | `a`, `b` (Räume), `kind` (open, lock, puzzle, secret, boss), `key`, `group`, `hidden`, `dir` (h/v), `cells` (2×2 Durchgang), Mittelpunkt `cx`/`cy`, Rissposition `crack_x`/`crack_y` |
| `groups` | Rätselgruppen: `kind` (braziers, plates, sequence), `label`, `spread` |
| `props[]`, `decals[]`, `wall_decor[]`, `lights[]` | Deko in Weltpixeln; `solid` = Kollisionsrechteck, `low` = flach am Boden; Licht `r` = Radius |
| `ents[]` | `type` (chest, vault, key, heart, gem, brazier, plate, spikes, vent, portal), Position, `room` und je nach Typ `key`, `group`, `order`, `offset`, `phase`, `magic`, `loot` |

## Schema `assets/data/hell_balance.json`

| Schlüssel | Bedeutung |
| --- | --- |
| `player` | `hp` (halbe Herzen zu Beginn), `max_hp_cap`, `speed` (px/s), `lava_slow` (Faktor), `invulnerable` (s nach Treffer), `half_width`/`height` (Kollisionsbox) |
| `shot` | `speed` (px/s), `life` (s), `cooldown` (s) |
| `enemy_shot` | `speed`, `ring_speed` (px/s), `life` (s), `hit_radius` (px) |
| `mobs` | je Platzhalter `hp`, `speed`, `scale`, `radius`; `spucker.fire_every` (s), `keep_away` (px); `boss.max_adds` |
| `hazards` | `spike_period` (s je Phase), `vent_period`, `vent_burst` (s), `vent_radius` (px) |
| `drops` | Wahrscheinlichkeit für Herz und Runenstein nach einem Kampf |
| `vault` | Runensteine `gems_base` + `gems_per_floor` × Etage, `heart_containers` |
| `view` | sichtbare Weltbreite, Basisbreite, Licht der Figur, max. Lichter im Shader, Helligkeitsstufen |

## Grenzen

Einzelspieler, keine Netzwerk-Replikation. Gegner, Boss und Figur sind Platzhalter. Lizenz der
Höllen-Grafiken ungeklärt (`assets/sprites/hell/LICENSE-NOTE.md`).
