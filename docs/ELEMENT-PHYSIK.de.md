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
| `src/combat/element_rules.gd` | Liest die Tabelle einmal; reine Regeln (`medium`, `gas`, `top`, `immune`, `tags`, `slide`, `pull`). |
| `src/combat/elements.gd`, `src/combat/boss_moves.gd` | Hauptdungeon (Host): Gase und Pfützen auf Helden und Gegner, Reaktionen. |
| `src/dungeon_view.gd` | Hauptdungeon (Client): die Sicht im Gas (`_step_vision`, `_update_darkness`). |
| `src/hell/hell_game.gd` | Story-Welten: der Held (`_step_elements`), die Frostgruft-Gegner (`_step_mob_medium`), die Sicht (`vision`). |
| `src/hell/hell_monsters.gd` | Story-Welten: die Höllen- und Krypta-Monster (`_step_medium`), Atemwolken, Reaktionen beim Aufschlag (`_react`). |
| `src/hell/story_elements.gd` | Story-Welten: die Reaktionen (Feuer, Frost, Wasser, Lava trifft Wasser). |
| `src/vfx/gas.gd` | Gaswolken: `at`, `around`, `extent` (wie dicht, wie weit), `clouds_of`, `end_cloud`. |
| `src/vfx/pool_paint.gd` | Pfützen: `materials_at` (was liegt unter einem Punkt, auch gefrorenes Eis). |

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
| Blitz in Wasser/Gift/Blut | geladen (`charge_*`, Hauptdungeon). |

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
  Frostnebel friert ihn kurz ein (`freeze_wet` 0.7 s, Bosse nie).

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

Pfützen liegen 60 s, Gase 30 s (`debug_test_arena.json`), damit die Reaktionen
der anderen Elemente darauf geprüft werden können.

## Geprüft (Probes im Scratchpad, 2026-10-31)

Krypta und Hauptdungeon: Mimik brennt in Lava, Skelett ignoriert Gift; Held
im Dampf sieht nur die Wolke, wird nass; auf Eis rutscht er nach dem Loslassen
60–80 px weiter; Gift vergiftet, Lava brennt nach, Wasser löscht den Brand.
Reaktionen in der Krypta: Explosion, Dampf, Glatteis (Held rutscht), Tauen,
Kruste. Atemwolke des Moderkoloss vergiftet und schließt die Sicht. Kombos in
beiden Laufzeiten. Dauerläufe: Krypta 10 Etagen ohne Fehler.
