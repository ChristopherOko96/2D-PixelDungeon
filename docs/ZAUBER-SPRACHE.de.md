# Zauber-Sprache: Jeder Zauber ist die Materie seines Elements

Stand 2026-10-31. Entscheidung des Nutzers: ein Aussehen für alle Zauber in
allen Welten (Krypta, Hölle, Frostgruft, Hauptdungeon). Kein Zauber ist mehr
eine aufgeklebte Sprite-Explosion („8-bit cheap staged sprite explosions“),
sondern Pixel-Materie seines Elements mit Physik. Umgesetzt in
`src/vfx/talent_fx.gd`, `talent_pixels.gd`, `talent_palette.gd`,
`particles.gd` und den Tabellen `assets/data/vfx_talents.json`,
`assets/data/vfx_particles.json`. Beide Laufzeiten (Krypta `dungeon_view.gd`,
Story-Welten `hell_talents.gd`) zeichnen über dieselben Klassen.

## 1. Materie, nicht Sprites

- Ein Zauber besteht aus ganzen Art-Pixeln (Krypta 2 px, Story-Welten 3 px),
  deckend, in den fünf Stufen seiner Rampe (deep/shade/body/lite/spec aus
  `talent_palette.gd`), mit dunkler Tusche-Kontur (`INK`), lichtes Nord-Rim,
  Spec-Farbe nur in einzelnen Zellen.
- Ausblenden nur per 4x4-Dither (`PixelPaint.shown`), nie Transparenz.
- Alles endet an Wänden (`PixelPaint.clip`, von der Welt gesetzt).
- Sheets bleiben nur für Formen, die man lesen muss: Hieb (`slash`,
  `slash_rage`), Wirbel (`whirl`), Kralle (`claw`), Pfeile (`hail_arrow`,
  `arrow_impact`, `sky_spear`, `poison_dart`), Messer (`knife`), Phönix, Meteor.

## 2. Vier Takte pro aktivem Talent

| Takt | Dauer | Was passiert | Code |
|---|---|---|---|
| **CAST** | 0,1–0,22 s nach Stufe | Element-Pixel sammeln sich an der Hand (Brust + `cast.hand` Zellen in Zielrichtung), hellen auf, dann ein Blitz, der ausdithert. Wie viele und von wie weit: `cast.cells/reach/span/flash` je Stufe. | `TalentPixels.gather`, `talent_fx._gather` |
| **FLIGHT** | solange der Schuss fliegt | Kern-Kugel (`shots.tiers.core` Zellen) in der Form der Materie plus gedittherter Element-Schweif (`trail` Zellen); leuchtet auf der Glow-Ebene (`glow`). Feuer lässt Glut abperlen. | `TalentPixels.shot`, `draw_bullet`, `draw_glow` |
| **IMPACT** | 0,45 s | Gemalter Ausbruch (`TalentPixels.impact`) plus Pixel-Physik in `particles.gd` mit Schwerkraft, Abprallen, Liegenbleiben; Riss oder Brandfleck (`crack`); Shake/Hitstop/Blitz nach Stufe (`shots.feel` → `tiers`). | `talent_fx._impact`, `_matter`, `_burst_physics` |
| **RESIDUE** | 1–5 s (`residue.*.time`) | Das Element bleibt am Boden liegen: kleine Lache (`pool_paint`, Quelle `talent_residue`) oder liegengebliebene Splitter. Zonen hinterlassen ihren Rest, wenn sie enden (`zone_time`, Linien alle `path_every` Punkte). | `_leave`, `_residue_entries`, `_zone_residue` |

Auto-Angriffe hinterlassen nichts; der Giftpfeil (trapper_1) nur beim Aufschlag.
Gewicht nach Wichtigkeit: kurze Übertreibung (Stufen small/medium/large/huge in
`vfx_talents.json tiers` und `shots.tiers`), dann zurück zur Ruhe, nie dauerhaft.

### Woher der Aufschlag weiß, dass er stattfindet

Ein Talent-Schuss hat kein eigenes Ereignis im Snapshot (nur der Feuerball mit
`splash_m` schickt `explosion`). `draw_bullet` merkt sich jeden gezeigten
Talent-Schuss; `draw_ground` (Beginn des nächsten Frames) vergleicht die beiden
letzten Zeichen-Durchgänge: Ein Schuss, den kein Schuss desselben Talents in
`shots.fizzle_tol` Krypta-px um seine vorhergesagte Stelle fortsetzt, ist
eingeschlagen (Gegner, Wand oder Reichweitenende). In den Story-Welten liegt
der Bodenpunkt `shot_lift` (30 px) unter dem gezeichneten Schuss
(`set_art` setzt ihn für das 3-px-Raster; die Welt darf ihn überschreiben).

## 3. Element je Spezialisierung (`talent_palette.gd SPEC_ELEMENT`)

| Klasse | Spezialisierung | Element | Materie beim Aufschlag | Rest am Boden |
|---|---|---|---|---|
| Magier | fire | fire | Funken, Flammen, Glut, Rußfleck | Feuerlache / Glut, die ausgeht |
| Magier | frost | ice | Splitter, die rutschen, Frostfleck, Rauhreif | Eislache (Rime) |
| Magier | arcane → **Leerenmagier** | void | Motten, die erst nach innen gezogen werden (Implosion), dann streuen | Leeren-Fleck (zieht Motten an) |
| Schütze | sniper | gold | Funken + liegengebliebene Splitter | nur Splitter |
| Schütze | trapper | poison | Tropfen im Bogen, landen als Bodenpixel | Giftpfütze |
| Schütze | beast | beast (`spirit` für das Rudel von Alpharuf) | Staub, Brocken | nur Splitter |
| Schwertkämpfer | berserk | blood | Tropfen | Blutspritzer |
| Schwertkämpfer | guard | **stone** (neu, erdiges Graubraun) | Geröll, Staub, Bodenrisse | nur Splitter |
| Schwertkämpfer | blade | steel | Funken + Splitter | nur Splitter |
| Nekromant | minion | **bone** (neu, Elfenbein) | Splitter | nur Splitter |
| Nekromant | curse | **curse** (neu, dunkles Rotviolett) | Motten | nur Splitter |
| Nekromant | soul | **soul** (neu, blasses Blauviolett) | Motten | nur Splitter |
| – | – | water | Tropfen | Nässe (Wasserlache) |

Die Leeren-Rampe sind die Farben der Leeren-Pfütze aus `vfx_pools.json`
(241238, 3a1f5c, 7a3fb8, c27bff, f2d9ff; Kontur bleibt `INK`). Aliasse
(`ALIASES`): `arcane`→void, `frost`/`snow`→ice, `flames`/`lava`/`firewall`/
`crater`→fire, `plague`→poison, `souls`→soul, `bleed`→blood. `ramp()` fällt
auf Stahl zurück. Materie-Art je Element: `KIND` (spark, shard, drop, mote, chip).

## 4. Was ersetzt wurde

| Vorher (Sheet-Frames) | Jetzt |
|---|---|
| `TALENT_BURSTS`, `TALENT_BLINKS`, `BLINKS` (bone/blood/stone/poison/void/arcane/shadow_burst, smoke_puff, blink) | `TalentPixels.burst`/`impact` im Element + Partikel (`_blink_physics`: Rauch für Rauchsprung/Rückwärtssalto, Schatten für Schattenschritt/-flucht, sonst Materie) |
| `TALENT_CASTS` (fire_charge, bubbles, star_burst, rage_aura …), `_cast` | CAST-Takt `TalentPixels.gather` nach Stufe (`cast.kind_tier` aus talents.json `type`) |
| `RINGS`, `TALENT_RINGS`, `_ring` (fire/frost/arcane/steel/blood/quake/curse/soul/shout_ring) | `TalentPixels.nova`/`waves` mit exaktem Trefferradius |
| `TALENT_DASHES` stone_burst/gold_bubble | Element-Burst + Geröll/Staub-Partikel; `claw`/`slash` bleiben |
| `spike_trap` Sheet | `TalentPixels.trap`: Dornenring mit tropfendem Gift (thorn), Eisenfalle mit Glutkern (iron), Seilnetz (net); scharf = Puls, ausgelöst = Sprung + Ausdünnen. Art aus Snapshot: `boom` → iron, `r` > `traps.net_over` → net, sonst thorn |
| explosion: fire_explosion/fire_sparks/smoke_puff/fire_ring | `nova` + `impact` fire, `fire_burst`-Partikel, Feuer-Rest |
| meteor_impact/stone_burst/fire_sparks, rune_circle | `impact` fire+stone, Geröll + Bodenrisse; `PixelPaint.warning` |
| crit_spark, hit_spark, level_up, shield_bubble, frost_burst/blink an Pet-Schüssen, net-Sheet | Gold-/Stahl-Burst, Dome-Blitz, `shot`/`burst`, `trap("net")` |
| Basis-Feuerball (`draw_basic_fireball`) Sheet + Alpha-Kreis | `TalentPixels.shot("fire")` mit heißem Kern und Glut-Schweif |

Unverändert (nicht im Auftrag): die Zonen-Looks der Ultimates (`_draw_looks`:
flame_tongue, lava_pool, ice_block, vortex, snowfall, soul_wisp, poison_cloud)
und die Shift-Block-Blasen (`_draw_guard`).

## 4a. Feuer: die Sprache des Feuermagiers (2026-10-31)

Rückmeldung des Nutzers nach dem Spielen: die Angriffe des Feuermagiers waren
„zu lasch“, ohne die gewollte Pixel-Animation, das Flammenmeer eine gezogene
Linie. Feuer bekommt deshalb eine eigene, fettere Ausprägung der vier Takte
(`vfx_talents.json "fire"`, Code in `talent_fx.gd`, `talent_pixels.gd`
`shot/boom/fire_line/ember_chain/wings/crater`, `talent_ults.gd
_meteor_call`, `particles.gd ember_sparks`). Krypta 2 px und Story-Welten 3 px
teilen den Code. Jeder Feuer-Rest ist eine echte Lache (`pools.add` über die
Quelle `talent` / `talent_residue`), damit die Element-Physik des Hosts auf
alles wirkt, was darin steht.

| Talent | FLIGHT / Form | IMPACT | RESIDUE |
|---|---|---|---|
| **fire_1 Feuerball** | Kern mit weißglühendem Herz (`heart`), Glut-Schweif, der die Rampe hinunter abkühlt und absackt (`tail`), Glut, die abperlt und fällt | „Fette Explosion in Stößen“ (`boom`): ein weißer Blitz-Frame, der Feuerball schwillt klumpig auf und kühlt, Flammenzungen stehen auf, 3 Druckringe laufen gestaffelt aus (0,25 s), Funken fliegen im Bogen; in den Partikeln Glutfunken, die hüpfen und ~1,5 s als Glut liegen bleiben (`ember_sparks`), Brandstern und Ruß. Gefühl Stufe medium (`shots.talent_feel`). Trifft er einen Gegner, trägt das `explosion`-Ereignis (Trefferradius) den Boom, sonst der verschwundene Schuss. | Feuerlache 4–9 Zellen |
| **fire_7 Flammenmeer** | Beim Ziehen: Glut-Spur aus Zellen mit kleinen Zungen (keine Linie) | Echte Feuerlachen entlang des Strichs (`pool_every`, verkohlter Boden und auftreibende Flammen aus `pool_paint`), darüber ein Glutkern mit kriechenden hellen Zellen und 3–5 Zellen hohe Pixel-Zungen im 12-fps-Takt (`fire_line`), Rauchwolken in der Gas-Ebene (`gas.emit "smoke"`, ohne Gas Partikel-Rauch) | In den letzten `ash` s brennt es zu Asche herunter (Zungen schrumpfen, graue Asche dithert ein); danach Glut, die zu Ruß stirbt, und Asche-Pixel statt neuer Lache |
| **fire_9 Infernospeer** | Speer aus Glut (`_spear`): weißglühende Spitze, Schaft kühlt zum Ende ab, Hitzeflimmern als gedittherte dunkle Zellen, die neben dem Schaft wackeln (`shimmer`) | Boom Stufe large, der Boden reißt (`floor_crack`, `spear.crack` Äste) | Lava (`talent_residue` → `residue.lava`, 3–5 s), kühlt mit ihrer Kruste aus |
| **fire_11 Glutkette** | Kette aus Glutfunken von Glied zu Glied (`ember_chain`): gezackte Glutzellen, Kopf weißglühend, Funken springen ab | Jeder Sprung ein kleiner Boom plus Funken; die Ziele brennen `chain.burn` s sichtbar (`TalentPixels.flames` an den Treffpunkten — der Snapshot kennt keine Gegner-Zustände) | — |
| **fire_14 Meteor** | CAST: Ruf in den Himmel (`_meteor_call`: Glutstrom aus der Hand nach oben, Blitz an der Hand; Glutkrater: Glutkern am Boden, Meteorschauer: drei Seitenströme). FLIGHT: Schatten wächst und dunkelt (`shadow`), Glut strömt vom Stein | Riesen-Boom (`meteor.size`), Hitstop/Shake/Blitz Stufe huge (`ult_impact`), Gesteinssplitter, die liegen bleiben (`chips`), Bodenrisse; Krater = echte Lavalache (`lava_share`) mit glühenden Rissen, Zungen und aufsteigender Glut (`crater`), Rauch | Lava, die auskühlt (`residue.lava` über `talent_residue`) |
| **fire_5 Phönixschritt** | Phönix-Sheet bleibt; Glut-Flügel beim Start und bei der Ankunft (`wings`) | Feuer-Burst an beiden Enden | Feuerspur: Feuerlachen alle `trail_every` px entlang des Sprungs, brennen `trail` s (1,5) |

Element-Auslöser bleiben beim Host (`fire_passes` an Feuerschüssen,
`_element` an `nova`/`explosion`/`impact` und Zonen-Ticks → `elements.fire_at`):
Feuerball-Explosion, Flammenmeer-Ticks, Meteor und Krater erreichen ihn; die
Reaktionen (Gift explodiert, Wasser dampft) zeichnen `elements.gd`/`feedback.gd`
und die Lachen-Ebene. Nicht angebunden (Meldung, nicht hier gelöst): der
Infernospeer (kein `explosion`-Ereignis, `pierce`), die Glutkette (nur `_hit`)
und der Phönixschritt (`_area` ohne `_element`) lösen `fire_at` nicht aus.

## 5. Stellschrauben (`assets/data/vfx_talents.json`)

- `shots.tiers.<stufe>`: core, trail, burst, parts, crack, glow; `shots.talent_tier` je Schuss-Talent; `shots.feel`; `shots.fizzle_tol`.
- `cast`: span, cells, reach, flash je Stufe; hand; kind_tier.
- `residue.<element>`: st (Material), cells [small, huge], share, cap, time; `chips`, `zone_time`, `path_every`.
- `traps`: net_over, radius, pulse, spring.
- `events`: neu `explosion: medium`, `leap_slam: medium`, `chain: small`; `ult_impact: huge` (der Meteor-Einschlag).
- `fire`: heart, tail, boom (time, flash, pulses, pulse_span, size, size_share, sparks, lie, scorch), spear, flammenmeer, chain, meteor, phoenix; `shots.talent_feel`, `residue.lava`, `residue.talent_residue`.
- `vfx_particles.json fire`: spark_speed, ember_lie, spark_soot (`particles.ember_sparks`).
- `vfx_particles.json shot`: drops, drop_life, motes, mote_life, chips, chip_life (neue Helfer `particles.drops/motes/chips`).

## 6. Geprüft

- Ladeprüfung (`scripts/dev_load_check.gd`) aller geänderten Skripte: OK.
- Bench `scripts/bench_vfx.gd` vorher/nachher: siehe Bericht (Budget ≤ 18 ms Mittel bei Volllast).
- Hinweis: Die Ultimates in `talents.json` heißen `<spec>_14`; die Formen in
  `talent_ults.gd` matchen noch `<spec>_6` (Altstand) und zeichnen für die neuen
  Ultimates nichts – deren Takte kommen jetzt aus der allgemeinen Sprache
  (`cast` huge, `nova`-Physik, Rest nach Anteil). Die alte `pools`-Tabelle ist
  deshalb leer.
