# Hell-Dungeon

Stand 28.10.2026. Neuer Einzelspieler-Modus mit zehn Etagen im Höllenstil aus `rooms.zip`.
Start: Hauptmenü → **LEVEL-AUSWAHL (DEBUG)** → Welt **HELL-DUNGEON** → je Etage **START** (Eingang) oder
**BOSS** (direkt im Bossraum, der Kampf beginnt sofort); außerdem `Hell-Dungeon.cmd` oder `scripts/Dev.ps1 HellDungeon`.
Spielfigur und Gegner sind Platzhalter; Monster werden später gesondert entworfen.

## Regeln

- **Kampfräume** (alle außer Eingang, Schlüssel-, Schatz-, Tresor-, Geheim- und Portalraum) verriegeln beim
  Betreten alle Türen; der Sieg öffnet sie wieder. Danach fällt oft ein Herz oder ein Runenstein.
- **Farbschlüssel:** Glut (Hauptweg, fällt in einem Seitenraum vor dem Tor), Knochen (Beutekammer), Dämon
  (Bosstor). Jeder passt nur in sein Tor, man kann sich nicht aussperren.
- **Feuerschalen** sind über mehrere Räume der Etage verteilt. Brennen alle, öffnet sich das Gitter zum
  **Riesentresor** (Lichtstrahlen, +1 Herzcontainer, volle Gesundheit, Runensteine).
- **Druckplatten:** leuchten nacheinander auf; in dieser Reihenfolge betreten lässt eine Belohnungstruhe
  erscheinen (Runensteine und ein Herz). Ein falscher Schritt löscht alle Platten.
- **Geheimräume:** Vor jeder geheimen Wand steht ein großer Schädelhaufen. Nach genau 3 Treffern zerfällt
  er und der versteckte Gang öffnet sich. Große Schädelhaufen gibt es nur dort; Deko sind kleine Schädelstapel.
- **Dämonensiegel** (ab Etage 4: 3 je Etage, ab Etage 7: 4; höchstens eines je Kampfraum, meist abseits des
  Hauptwegs): nach 8 Treffern bricht es. Zu 50 % gibt es einen dauerhaften Segen (+1 Schaden, 15 % schneller
  schießen, 10 % schneller laufen, 25 % mehr Reichweite oder ein Herzcontainer), sonst springen drei
  mittelschwere Dämonen heraus und der Raum verriegelt erneut, ohne zweiten Schlüssel oder zweite Belohnung.
- **Gruben:** Fallen nur für die Figur. Hineinlaufen kostet ein Herz und wirft zurück in den Startraum.
- **Klon-Skill:** Belohnung für den Boss auf Etage 9. Q ruft einen Klon für insgesamt 2 Minuten. Er folgt,
  weicht aus, wird von Gegnern ignoriert, nimmt keinen Schaden und schießt selbst. Einmal gestartet läuft er
  bis zum Ende; beim Portal pausiert er mit seiner Restzeit, auf der nächsten Etage geht es mit Q weiter.
- **Übertrag:** Herzen, Runensteine, Segen und der Klon-Skill wandern durch das Portal mit.
- **Kürzester Weg:** Der Boss ist nie erst nach allen Räumen erreichbar (11–17 von 22–31 Räumen,
  geprüft in `tests/hell_floor_data_test.gd`). Erkunden bringt Tresore, Herzen und Runensteine.
- **Tiefe:** mehr Lava, Stacheln und Schlote, zähere und schnellere Gegner, ab Etage 4 Feuerspucker,
  Bosse mit Feuerringen; Zwischenbosse auf 3, 6 und 9, der Höllenfürst auf 10. Optik: dunkler, roter Schleier.

Steuerung: WASD laufen, Pfeiltasten oder linke Maustaste schießen, E/Leertaste Aktion, Q Klon, M Karte,
L Licht, R Etage neu, 1–0 Etage wählen, Esc Hauptmenü.

## Aufbau

| Teil | Ort |
| --- | --- |
| Etagen-Kern, Generator, Bild-Werkzeuge, Browser-Vorschau | `tools/hell_dungeon/` (siehe README dort) |
| Gebackene Etagen | `assets/data/hell_floors.json` (aus `bake_floors.js`) |
| Spielwerte | `assets/data/hell_balance.json` |
| Grafiken (134, Weltmaßstab) | `assets/sprites/hell/` mit `manifest.json` und `LICENSE-NOTE.md` |
| Laufzeit | `src/hell/hell_game.gd` (Szene `hell_dungeon.tscn`), `hell_floor_data.gd`, `hell_walls.gd`, `hell_rules.gd` |
| Tests | `tests/hell_floor_data_test.gd`, `tests/hell_walls_test.gd`, `tests/hell_rules_test.gd`, `tests/hell_boss_start_test.gd` |
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
| `doors[]` | `a`, `b` (Räume), `kind` (open, lock, puzzle, secret, boss), `key`, `group`, `hidden`, `dir` (h/v), `cells` (2×2 Durchgang), Mittelpunkt `cx`/`cy`, `crack_x`/`crack_y` (ungenutzt seit den Schädelhaufen) |
| `groups` | Rätselgruppen: `kind` (braziers, plates, sequence), `label`, `spread`, `reward` (`chest` = Belohnungstruhe) |
| `props[]`, `decals[]`, `wall_decor[]`, `lights[]` | Deko in Weltpixeln; `solid` = Kollisionsrechteck, `low` = flach am Boden; Licht `r` = Radius |
| `ents[]` | `type` (chest, vault, key, heart, gem, brazier, plate, spikes, vent, portal, seal, skullheap, pit), Position, `room` und je nach Typ `key`, `group`, `order`, `offset`, `phase`, `magic`, `loot`, `hp` (Treffer bis zum Bruch), `door` (Index der Geheimtür hinter dem Schädelhaufen) |

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
| `seal` | `bless_chance` (Anteil Segen), `demons` (Anzahl), `demon_kind` (Gegnerart) |
| `blessings` | `dmg` (+Schaden), `rate_mul`/`rate_min` (Schussabstand), `speed_mul`, `range_mul`, `heart` (halbe Herzen) |
| `pit` | `damage` (halbe Herzen), `reach_x`/`reach_y` (px um die Grubenmitte) |
| `clone` | `floor` (Etage des Bosses mit Skill), `duration` (s), `fire_every` (s), `range` (px), `follow`/`weave` (px) |
| `sequence_chest` | `gems_base` (+ Etage) und `heart` der Belohnungstruhe |

## Grenzen

Einzelspieler, keine Netzwerk-Replikation. Gegner, Boss und Figur sind Platzhalter. Lizenz der
Höllen-Grafiken ungeklärt (`assets/sprites/hell/LICENSE-NOTE.md`).
