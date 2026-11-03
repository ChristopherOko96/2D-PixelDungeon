# Element-Physik

Stand 2026-10-31. Entscheidung des Nutzers: Alles, was in einem Element steht,
spürt es, Held wie Monster, in jedem Kapitel (Hauptdungeon, Hölle, Frostgruft,
Krypta). Nur ein Wesen dieses Elements bleibt verschont. Was aufeinandertrifft,
reagiert wie im echten Leben: Feuer zündet Gift, Wasser kocht, Frost friert,
Wasser löscht.

## Eine Regel für alle Welten

| Datei | Rolle |
|---|---|
| `assets/data/element_rules.json` | Die Tabelle: Medien, Gase, Sicht, Reaktionen, Kombinationen, Element-Tags. |
| `src/combat/element_rules.gd` | Liest die Tabelle einmal; reine Regeln (`medium`, `gas`, `top`, `immune`, `tags`, `slide`, `pull`). Für Wahn und Gefüge nur noch Weiterleitungen. |
| `src/physics_kit/element_exposure.gd` | **`ElementExposure`**: was Pfütze und Gas mit einem Wesen machen, für Held und alle Gegner in allen drei Story-Welten (siehe unten). |
| `src/physics_kit/exposure_host.gd` | Der Vertrag, über den `ElementExposure` mit einem Spiel spricht. |
| `src/hell/story_exposure_host.gd` | Der Adapter der Story-Welten (Krypta, Hölle, Frostgruft) für diesen Vertrag. |
| `src/combat/madness_rules.gd`, `assets/data/madness_rules.json` | `MadnessRules`: Wahn (`madness`), Leerenmagier (`void_mind`) und die Daten des Arkanen Gefüges (`gefuege`). Keine Physik, darum getrennt. |
| `src/combat/elements.gd`, `src/combat/boss_moves.gd` | Hauptdungeon (Host): Gase und Pfützen auf Helden und Gegner, Reaktionen. |
| `src/dungeon_view.gd` | Hauptdungeon (Client): die Sicht im Gas (`_step_vision`, `_update_darkness`). |
| `src/hell/hell_game.gd` | Story-Welten: ruft `exposure().step` für den Helden (`_step_elements`) und die Frostgruft-Gegner (`_step_mob_medium`); die Sicht (`vision`), die Wahn-Uhr des Helden. |
| `src/hell/hell_monsters.gd` | Story-Welten: ruft `g.exposure().step` für die Höllen- und Krypta-Monster (`_step_medium`); Atemwolken, Reaktionen beim Aufschlag (`_react`). |
| `src/hell/story_elements.gd` | Story-Welten: die Reaktionen (Feuer, Frost, Wasser, Lava trifft Wasser). |
| `src/physics_kit/gas_field.gd` | **`GasField`**: die Gaswolken als Spielregel (Puffs als Daten, ihre Physik): `at`, `around`, `extent` (wie dicht, wie weit), `clouds_of`, `end_cloud` (siehe unten). |
| `src/physics_kit/pool_field.gd` | **`PoolField`**: die Pfützen als Spielregel: `materials_at` (was liegt unter einem Punkt, auch das Eis der Regeln), `covers`, `pools_at`, `centre`, `freeze_near`, `thaw_near`, `evaporate` (siehe unten). |
| `src/physics_kit/field_host.gd`, `callable_field_host.gd` | Der Vertrag beider Felder (nur: wo ist offener Boden) und seine Fassung für eine Callable. |
| `src/vfx/gas.gd`, `src/vfx/pool_paint.gd` | Die Zeichnung der beiden Felder. Ihre alten Aufrufe (`at`, `around`, `materials_at`, `covers`, `sync` …) leiten ans Feld weiter. |

## Medien (worin man steht)

Werte in `element_rules.json` `mediums`. Einheiten: `hurt` halbe Herzen pro
`tick` Sekunden für den Helden; `enemy_hurt` Heldentreffer pro Sekunde für ein
Monster (im Hauptdungeon Schadenspunkte pro Sekunde); `slow` Anteil der
Laufgeschwindigkeit; `grip` Anteil des Schwungs, der nach einer Sekunde bleibt;
`status` {Zustand: [Wert, Sekunden]}, jeden Frame neu gesetzt, wirkt also so
lange nach, wie es dort steht.

| Medium | Wirkung |
|---|---|
| Lava | verletzt, brennt nach (`burn`), bremst stark; Feuer- und Höllenwesen sind immun. Verkrustet, wenn Wasser sie trifft (`crust_time`), und ist dann kühler Stein. |
| Feuer | wie Lava, schwächer. |
| Wasser | bremst leicht, macht nass (`wet`), löscht Brand (`douse`), leitet Blitz. |
| Eis (Glatteis, Frostpfützen) | kein Halt: der Schwung bleibt (`grip` 0.015), wer loslässt, rutscht weiter. Frostwesen stehen sicher. |
| Gift | verletzt, vergiftet, bremst; Untote, Giftwesen und Leerenwesen sind immun. |
| Blut | rutschig (`grip` 0.35), bremst leicht. |
| Leere | verletzt, versiegelt die Fähigkeiten (`silence`), zieht zur Mitte (`pull`); Leerenwesen sind immun. |

Die Lava- und Eis-Kacheln einer Welt behalten ihre `theme.liquid`-Regel; das
Obige gilt für Pfützen und Wolken.

## Gase (was man atmet)

Werte in `gases`. Eine Wolke zählt ab `dense_from` Dichte; weil jeder, der in
einer Wolke steht, sie um sich teilt, wird in Armlänge gemessen (`gas.around`).

| Gas | Wirkung |
|---|---|
| Dampf | verbrüht, macht nass, Monster schießen nicht (`blind_shots`); die Sicht schließt sich ganz (`vision` 1). Feuerwesen sind immun. |
| Rauch | nur Sicht (0.85) und keine Schüsse. |
| Gift | vergiftet, Sicht 0.55; Untote, Giftwesen, Leerenwesen immun. |
| Leere | versiegelt, bremst, Sicht 0.9. |
| Frost | kühlt (`slow`), Sicht 0.45; Frostwesen immun. |

**Die Sicht im Gas** (`vision`): Steht der Held in einer Wolke, wird die Welt
außerhalb der Wolke dunkel (`dark` 0.94 bei voller Sicht-Stärke); er behält
die Wolke um sich, so weit sie reicht (acht Strahlen, `probe_hz` mal pro
Sekunde, zwischen `min_radius` und `max_radius`). Lichter in der Wolke bleiben
gedimmt, die fernen verschwinden. Beim Verlassen öffnet sich die Sicht wieder
(`fade_out`).

**Atemwolken**: Der Gift-, Frost- oder Feueratem eines Monsters bleibt als
Wolke hängen (Gift, Frost, Rauch), dort wo er hinging (`hell_monsters.gd
_breath_cloud`).

## Reaktionen (was aufeinandertrifft)

Werte in `reactions`; im Hauptdungeon gewinnen die eigenen Werte aus
`src/data/balance.json` `element`.

| Treffen | Folge |
|---|---|
| Feuer/Lava auf Gift (Pfütze oder Wolke) | Explosion: Schaden im Umkreis, Bodenrisse, Druckwelle; zündet das nächste Gift (`explode_chain`). Das Gift ist verbraucht. |
| Feuer/Lava auf Wasser | kocht zu Dampf (`steam_scale`, `steam_time`). |
| Frost auf Wasser | Glatteis (`ice_time`); Feuer taut es wieder. |
| Frost auf Dampf | kondensiert: fällt als Wasser (`rain_scale`). |
| Wasser auf Lava | Kruste (`crust_time`), das Wasser verdampft. |
| Blitz in Wasser/Gift/Blut | geladen: alle `charge_tick` s nimmt jeder Gegner darin Schaden und ist kurz betäubt (`charge_stun`, Bosse die Hälfte); der Held bleibt verschont, Glatteis isoliert. Hauptdungeon: `charge_*` in `src/data/balance.json`. Story-Welten (seit 2026-10-31): `story_elements.gd lightning_at`, Schaden in Heldentreffern (`charge_hits`), die Pfütze knistert (`pool_paint.gd charge_pool`). |

Auslöser: die Talente des Helden (Feuer, Frost: `talent_combat.gd _element`),
die Angriffe der Monster beim Aufschlag (Lob, Meteor, Slam: `_react`), ein
Feuerschuss, der durch Giftgas fliegt (`fire_passes`: die Dämpfe fangen; die
Pfützen darunter bleiben, der Schuss ist in der Luft), der Boden der Welt
(`_floor_meets_puddles`: Gift auf Lavakacheln geht hoch, Wasser kocht, Wasser
auf Eiskacheln friert), der Testraum.

**Atemwolken** gibt es auch im Hauptdungeon: der Kegel eines Bosses
(`boss_moves.gd _cone`) lässt sein Gas hängen (`breath_gas`, `breath_r`,
`breath_time`).

## Kombinationen (der eigene Zustand trifft das Medium)

Werte in `combos`.

- **Brennend ins Gift**: Wer brennt (`fire_t` bei Monstern: Lava, Feuer, ein
  Brand; `burn` beim Helden) und Gift betritt oder atmet, zündet es.
- **Nass**: Wer nass ist, kann nicht angezündet werden (`wet_blocks_burn`);
  Frostnebel friert ihn kurz ein (`freeze_wet` 0.7 s, Bosse nie). Ein Monster
  friert auch auf Eis ein, der Held nur im Frostnebel (auf Eis rutscht er):
  `exposure.<profil>.freeze_on`.
- Seit 2026-11-01 gelten beide Kombinationen auch für die Frostgruft-Gegner.

## Das Modul `ElementExposure` (seit 2026-11-01)

`src/physics_kit/element_exposure.gd` ist die eine Stelle, die Medien und Gase
auf ein Wesen anwendet. Es greift nie selbst ins Spiel, sondern fragt seinen
Host (`src/physics_kit/exposure_host.gd`). Ein Spiel baut einen Adapter, der
diesen Vertrag erfüllt, und ruft jeden Frame für jedes Wesen `step`:

```gdscript
var exposure := ElementExposure.new(MyExposureHost.new(world))
var met := exposure.step(monster, dt)
monster.env = met.medium   # Halt und Sog für die Bewegung (slow, slide, grip, pull, centre)
```

- **Welt**: `pools_under`, `gas_around`, `pool_centre`, `lava_crusted`,
  `ignite` (Feuer setzt Gift in Brand), `world_scale`.
- **Wesen**: `profile` („hero“ oder „monster“), `actor_at`, `actor_alive`,
  `actor_burrowed`, `actor_altitude`, `actor_boss`, `actor_tags`, `exempt`
  (fühlt das Material gar nicht: der Leerenmagier in der Leere), `warded`
  (kein Schaden, kein Zustand: ein Trank wirkt nach), `has_status`,
  `set_status`, `clear_status`, `hurt`, `timer`/`set_timer`, `show_combo`.
- **Werte**: `element_rules.json` `exposure`: `air_above` (ab dieser Höhe in
  der Luft: nichts wirkt), je Profil die Gas-Abtastung (`gas_body`,
  `gas_pad`, `gas_samples`: Held 22 × 1,5 + 24 px an 8 Punkten, Monster
  18 + 24 px an 4), die Schadensart (`ticked`, `hurt_key`, `boss_hurt`),
  `dot_scale`, `freeze_on`, `own_clock` (der Wahn des Helden läuft über seine
  eigene Uhr), `why`.
- **Ergebnis** von `step`: `medium`, `style`, `gas`, `gas_mat`, `blind`,
  `vision`, `maddening`, `ignited` („pool“ oder „gas“), `skipped`.

Die Story-Welten teilen sich einen Adapter (`src/hell/story_exposure_host.gd`)
und eine Instanz je Welt (`hell_game.gd exposure()`). Seither bekommen die
Frostgruft-Gegner dieselben Regeln wie die der Hölle und der Krypta: die
Kombinationen (ein brennender Eis-Zombie im Gift löst die Giftexplosion aus),
keine Wirkung eingegraben oder in der Luft, und eine Boss-Prüfung für alle.
Offen: In der Frostgruft gehen nur die Giftschwaden einer Pfütze hoch, eine
Pfütze ohne Schwaden nicht, weil `story_elements.gd` dort noch keine Pfützen
kennt (BAUPLAN M1e). Test: `tests/element_exposure_test.gd` (unechter Host).

## Spielfeld und Zeichnung: `PoolField` und `GasField` (seit 2026-11-01)

Pfützen und Gas waren als Aussehen gebaut, wurden aber als Spielregel gelesen
(BAUPLAN M1d). Jetzt ist jedes zweierlei:

- **Das Feld ist die Wahrheit.** `PoolField` (`src/physics_kit/pool_field.gd`)
  hält die Pfützen: Zellen auf dem Kunstraster mit Geburt, Ende und Rang, je
  Pfütze Stil, Material, Landepunkt und Werfer (`owner`). `GasField`
  (`src/physics_kit/gas_field.gd`) hält die Puffs jeder Wolke und ihre Physik.
  Beide fragen das Spiel nur über `src/physics_kit/field_host.gd`, wo offener
  Boden ist, und laufen nur auf der Uhr des Spiels (`sync`, `advance`, `step`),
  nie auf den Bildern oder der Uhr des Rechners.
- **Die Zeichnung liest das Feld.** `pool_paint.gd` zeichnet die Zellen des
  Feldes (dieselben Arrays) und dazu, was nur Aussehen ist: Tropfenpfützen,
  Schmelzwasser, die sichtbaren Reaktionen (eine Flüssigkeit unter Lavakruste
  verschwindet, eine Flüssigkeit an einer Eispfütze wird zu Eis), Ringe, Risse,
  Funken, die Strudel der Leere. `gas.gd` zeichnet die Puffs als Schleier.

Was sich dadurch geändert hat (gewollt):

- **Gezeichnetes Eis zählt nicht mehr als Glatteis.** Wo Gift oder Wasser an
  einer Frost- oder Eispfütze liegt, wird es nur gezeichnet zu Eis
  (`vfx_pools.json reactions liquid+ice`); früher zählte `materials_at` jede
  Eiszelle, und der Boden wurde dort rutschig. Echtes Glatteis macht nur
  `freeze_near` (der Frost der Regeln). Auch eine gefrorene Tropfenpfütze ist
  nur Aussehen.
- **Große Pfützen zählen zu einem festen Zeitpunkt.** Eine Pfütze ab
  `thread_cells` Zellen wird weiter auf einem Hintergrund-Thread geformt, zählt
  aber genau `max(shape_commit_s, shape_commit_per_1000_cells_s je 1000
  Zellen)` Sekunden Spielzeit, nachdem das Feld sie sah (ein Gifttrank in der
  Hölle mit 5003 Zellen nach 0,33 s), auf jedem Rechner gleich. Ist der Thread
  dann nicht fertig, wartet das Feld. Früher erschien sie, sobald der Thread
  fertig war und die Zeichnung sie abholte, also je nach Rechner und Bildrate.
- **Die Uhr des Feldes stellt das Spiel.** `hell_game.gd _step_elements` ruft
  `advance(state.t)` der Pfützenebene. Die Frostgruft, deren Pfützen bisher nur
  beim Zeichnen ihre Uhr bekamen, zählt jetzt auf der Spieluhr.

Unverändert: das Aussehen (Probe 2026-11-01: 13 Bilder aus Hölle, Frostgruft
und Krypta vor und nach dem Umbau pixelgleich), die Formen, die Zeiten, die
Antworten von `materials_at` und `covers` für jede geworfene Pfütze und jede
Gaswolke (ein Raster von 2501 Punkten je Moment gleich, bis auf das gezeichnete
Eis oben). Ein Feld ohne Zeichnung:

```gdscript
var field := PoolField.new(3.0, MyFloorHost.new())
field.sync([{"id": 1, "k": "pool", "st": "poison", "x": 300.0, "y": 200.0, "r": 60.0, "p": 0.0, "L": 5.0}], now)
var mats := field.materials_at(point)   # ["poison"]
var gas := GasField.new(3.0, MyFloorHost.new())
gas.emit("breath:1", "poison", at, 60.0, 4.0, now)
gas.step(dt, now)
var breathed := gas.around(feet, 24.0, 4)   # {"mat": "poison", "d": 0..1}
```

Werte: `vfx_pools.json` (`_field_note`, `shape_commit_s`,
`shape_commit_per_1000_cells_s`, `purge_every_s`), `vfx_gas.json` (`seed`).
Tests: `tests/pool_field_test.gd`, `tests/gas_field_test.gd` (unechter Boden).
Offen: Die Talente syncen ihre Pfützen und Giftwolken noch beim Zeichnen
(`talent_fx.gd draw_ground`), und die Frostgruft legt ihre Pfützenebene erst
dort an; die Frostgruft-Monsterpfützen (`frost_moves.gd`) sind noch kein Teil
des Feldes (beides BAUPLAN M1e).

## Element-Tags (wer verschont bleibt)

`actor_tags` ordnet Wörtern in der Kennung ein Element zu (`skel` → Untot,
`zombie` → Gift, `frost` → Frost, `leere` → Leere, `imp`/`glut` → Feuer); dazu
kommen das eigene Schuss-Element eines Defs (`shot`) und sein Material
(`bone` → Untot). Höllenmonster ohne eigenes Schuss-Element gelten als
Höllenwesen (Feuer und Lava tun ihnen nichts).

## Die Leere frisst (seit 2026-10-31)

Werte in `element_rules.json` `swallow`. Eine Leerenpfütze, der Strudel eines
Bosses oder eine ziehende Talentzone (die Singularität) ist ein Maul: andere
Pfützen innerhalb `reach` × Radius laufen in `time` Sekunden aus, ihre Materie
strömt als Pixel-Motes ins Maul (Story-Welten: `story_elements.gd
_void_swallows`, `hell_monsters.gd` pfx `fly`); Gaswolken werden eingesaugt
(`gas.gd suck`: die Puffs strömen mit `pull` nach innen, im Maul dünnen sie um
`thin` pro Sekunde aus, eine ganz gefressene Wolke endet) und das Maul schluckt
alle `gulp` Sekunden sichtbar. Im Hauptdungeon dasselbe (`elements.gd
_void_swallows`: Pools laufen aus, die Wolken wandern zum Maul und schrumpfen).
Leere frisst keine Leere.

## Lebensleiste und Schaden über Zeit (seit 2026-10-31)

Der Schaden der Medien und Gase am Helden ist stetig: `hurt` ist halbe Herzen
pro Sekunde und läuft über `hell_game.gd dot_hurt_f` in `state.dot`; ein halbes
Herz geht, sobald ein ganzes geschuldet ist, leise (kurzer Flash, Treffer-Laut,
kein Punch). Die Lebensleiste zeigt `hp_f` = Herzen minus Schuld, also das
Abfließen (`src/ui/hud_kit.gd`). Zustände (`burn`, `poison`) sind ebenso halbe
Herzen pro Sekunde (`hero_fx.gd`). Im Hauptdungeon sammelt `elements.gd dot_f`
die Bruchteile je Held (`player.dot_acc`) und landet ganze Punkte; die Sicht
bekommt `hp_f` im Snapshot. Die Sätze sind so gesetzt, dass drei Herzen in Lava
etwa fünf bis sechs Sekunden halten (vorher unter drei): Lava 0.7 + Brand 0.45,
Feuer 0.5, Gift 0.45, Leere 0.55, Dampf 0.5, Giftgas 0.4. Monster behalten ihre
Ticks (`enemy_hurt` × `tick`).

## Testraum

Story-Testraum (`src/debug/story_testraum.gd`, Werte `debug_story_testraum.json` `elements.kraft`): BLITZ (Kettenblitz, lädt Pfützen), STURM, DRUCKWELLE (bläst Gas weg, Pfützen schwingen), BEBEN (Risse, Eis bricht, Betäubung) und HEILIG (Untote/Leere nehmen Schaden, der Held im Licht heilt) über `story_elements.gd` `lightning_at`, `wave_at`, `quake_at`, `holy_at`.

Pfützen liegen 60 s, Gase 30 s (`debug_test_arena.json`), damit die Reaktionen
der anderen Elemente darauf geprüft werden können.

## Geprüft (Probes im Scratchpad, 2026-10-31)

Krypta und Hauptdungeon: Mimik brennt in Lava, Skelett ignoriert Gift; Held
im Dampf sieht nur die Wolke, wird nass; auf Eis rutscht er nach dem Loslassen
60–80 px weiter; Gift vergiftet, Lava brennt nach, Wasser löscht den Brand.
Reaktionen in der Krypta: Explosion, Dampf, Glatteis (Held rutscht), Tauen,
Kruste. Atemwolke des Moderkoloss vergiftet und schließt die Sicht. Kombos in
beiden Laufzeiten. Dauerläufe: Krypta 10 Etagen ohne Fehler.
