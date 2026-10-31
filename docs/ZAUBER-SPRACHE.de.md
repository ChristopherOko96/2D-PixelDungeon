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

## 4b. Frost: die Sprache des Frostmagiers (2026-10-31)

Gleicher Standard wie Feuer (§4a): Gewicht, Pixel-Animation, Einschläge in
Stößen, echte Lachen als Rest. Eis ist starr: es zerspringt, rutscht, friert
und schmilzt. Werte in `vfx_talents.json "frost"`, Code in `talent_fx.gd`
(`_shatter_at`, `_mage_look_pools`, `_zone_matter`, `_mage_blink`,
`_dome_end`), `talent_pixels.gd` (`_lance`, `shatter`, `blizzard`,
`ice_trail`, `_crystal`, `_sliver`), `talent_ults.gd` (`_glacier_call`,
`glacier_field`), `talent_dome.gd` (Risse). Partikel: `particles.shatter`,
`rime_grow`, `frost`, `freeze_liquids` (vorhanden, unverändert).

| Talent | FLIGHT / Form | IMPACT | RESIDUE |
|---|---|---|---|
| **frost_1 Frostlanze** | Facettierte Eislanze (`frost.lance.length` je Stufe), oben lichte Facette, heller Grat, Spitze blitzt im Takt weiß, ein Glanz läuft den Grat hinunter; dahinter Frostnebel, der auseinanderdriftet und absinkt (`mist`) | Zerspringen in Stößen (`shatter`): ein weißer Blitz-Frame, Eisstern, 2 kalte Druckringe, Splitter fliegen im flachen Bogen, kippen in 8 Lagen und liegen als glitzernder Reif; Partikel-Splitter, die rutschen, Raureif wächst, Flüssigkeiten in `freeze` frieren (Wasserlache → Glatteis). Gefühl small | Eislache (`residue.ice`) |
| **frost_9 Splittersalve** | Drei kleine Lanzen (Stufe small) | Kleiner Shatter je Lanze | kleine Eislache |
| **frost_7 Blizzard** | Schnee und Eissplitter im Wirbel (innen schneller, innere Flocken als Schlieren), Frostnebel kriecht am Boden | Echte Frostlachen, die wachsen (`blizzard.pools`, alle `grow` s eine mehr), Raureif an neuer Stelle alle `rime_every` s, Frostgas (`gas.emit "frost"`) alle `mist_every` s | Endet schmelzend: Wasserlache (`residue.melt`, `talent_residue frost_7`) |
| **frost_11 Frostsprung** | Eisspur mit Raureif-Kristallen (2–5 Zellen), die nacheinander aufploppen und glitzern | Shatter an beiden Enden; Partikel: Splitter, Frostflecken entlang des Wegs, Raureif und Frieren am Ziel | Eislache am Start und am Ziel |
| **frost_5 Kristallschild** | Kristallkuppel (`talent_dome`, Element aus dem Cast) | Jeder Treffer (`dome_hit`) reißt sichtbar: gezackter Riss vom Treffpunkt nach innen, lichte Kante, Ast in der Mitte (höchstens `dome.cracks`) | Am Ende zerspringt die Kuppel: Shatter an der Brust, `frost.shield.shards` Splitter |
| **frost_14 Gletschergrab** | CAST: Frostnebel an den Füßen, ein Eiskristall wächst in der Hand und zerspringt bei `glacier.throw`; Stufe 1 Raureifring, Stufe 2 Haarrisse | Landung: Nova + großer Shatter (`burst_size`), kalter Blitz; Eisspitzen brechen in Wellen aus dem Boden (`wave` s je Ring, Mitte am höchsten, Splitter an den Füßen, Glanz am Grat) über echter Glatteis-Lache (`pool_share`); Stufe 1 Raureif am Rand; Eissturz (Stufe 2) zerspringt am Ende | Große Glatteis-Lache (`residue.glatteis`) und Shatter der Spitzen |
| **frost_3 Wasserelementar** | Begleiter-Rig unverändert; seine Eislanze ist eine kleine Frostlanze | Shatter beim Auftreffen (verzögert auf die Landung, `frost.pet_lance`); Frostnova: Nova + Shatter + Eis-Physik | Eislache der Nova |

## 4c. Leere: die Sprache des Leerenmagiers (2026-10-31)

Die Leere zieht: erst nach innen, dann der Ausbruch; sie verschluckt Licht
(kein Glow beim Sog, nur schwach beim Ausbruch). Werte in `vfx_talents.json
"void"`, Code in `talent_fx.gd` (`_implode_at`, `_echo`, `_mage_blink`,
`_zone_matter`), `talent_pixels.gd` (`_void_core`, `implosion`, `_tear`,
`rift`, `fold`, `void_dots`, `echo`, `singularity`), `talent_ults.gd`
(`_void_call`, `_collapse`), `talent_dome.gd` (Motten, Welle nach innen).
Partikel: `particles.implode`, `well` (vorhanden); `vfx_particles.json
void.implode_time` jetzt 0,15 s (der Sog). Das Verschlucken von Lachen und
Gas macht der Host (`elements.void_at`, `_void_swallows`).

| Talent | FLIGHT / Form | IMPACT | RESIDUE |
|---|---|---|---|
| **arcane_1 Leerengeschoss** | Dunkler Kern (schwarzes Herz, violetter Rand, Glanz kriecht herum); die Spur wird zum Kern hin gebogen: Motten hinter und neben ihm werden hineingezogen (keine Spur nach außen) | Implosion (`implosion`): `implode.pull` des Lebens (0,15 s) ziehen Motten auf Spiralen hinein, der Kern wächst; ein Frame Leere; dann Ausbruch der Motten, dunkler Druckring; Partikel-Implosion zieht Staub und lose Pixel mit. Gefühl small | Leerenfleck (`residue.void`), der Host verschluckt Pfützen/Gas in Reichweite |
| **arcane_9 Leerenlanze** | Stufe large, hinter dem Kern ein gezackter Riss im Raum (`void.lance.crack`) | Implosion mit Riss quer darüber, Bodenriss in den Partikeln. Gefühl medium | Leerenfleck |
| **arcane_7 Leerenriss** | – | Eine gezackte schwarze Linie reißt auf (`rift.open`), biegt sich zum Ring (`ring`), innen dunkel, Motten werden von außerhalb des Radius eingesogen; dann Druckring genau bis zum Trefferradius | Leerenfleck (Nova-Anteil) |
| **arcane_5 Raumsprung** | Gepunktete Leerenspur (`fold.dots`) | Faltung: am Start schließt sich ein dunkler Ring zu einem Punkt, am Ziel öffnet sich einer; Motten am Ziel | Leerenfleck am Start |
| **arcane_3 Magisches Echo** | Dunklerer violetter Geist des letzten Zaubers (Rampe eine Stufe tiefer): Schuss als Geistkugel mit nachhängendem Doppel, Nova/Zone als Geistring, sonst Geist-Sammeln; dazu Geistring an den Füßen | – | – |
| **arcane_11 Manaschild** | Dunkelviolette Kuppel, Motten driften vom Rand nach innen | Treffer: eine Welle läuft vom Treffpunkt nach innen (`dome.ripple`) statt Funken | Am Ende faltet sie sich ein (kleine Implosion) |
| **arcane_14 Singularität** | CAST: Motten von überall in die Hand, ein schwarzer Kern mit violettem Horizont wächst und schnappt bei `call.throw` zu; Stufe 1 dunkler Ring an den Füßen, der sich schließt; Stufe 2 Glanzring um den Kern | Zone: schwarzer Kern mit hellem Horizont, Akkretionsring aus Motten auf engen Spiralen (Schlieren nahe am Kern), Spiralarme aus dunklem Boden kriechen hinein; Stufe 1 äußerer Mottenring; Partikel-`well` zieht Staub, lose Pixel und Glut hinein; Kollaps (`_collapse`): riesige Implosion mit Riss, Stufe 2 (Urknall) helle Strahlen bis zum Radius | Leerenfleck; Lachen und Gas verschluckt der Host |

Element-Auslöser (Frost friert Wasser, Leere verschluckt) liegen beim Host
(`talent_combat._element`, `elements.gd`, `story_elements.gd`).

### Das Arkane Gefüge (2026-10-31)

Der Leerenmagier trägt verschluckte Elemente in einer Tasche (Snapshot
`player_state(id).gefuege = {cap, units: [{el, n}]}`). Werte in
`vfx_talents.json "void"` (`swallow`, `eject`, `tether`, `splat`, `mad`),
`ui_hud_style.json "gefuege"` und `vfx_gore.json "splat"`.

| Teil | Bild |
|---|---|
| **Anzeige** (`talent_bar.gd draw_gefuege`, beide Laufzeiten) | Kleine dunkle Kugel (~34 px) rechts der Manaleiste: Tintenrand, schwacher violetter Randschein (Dither), schwarzes Inneres, Füllbogen n/cap im Uhrzeigersinn ab oben. Je Einheit ein farbiger Pixel (2x2 px, Rampen-Lite des Elements, `tone` für Lava/Wasser/Eis) auf eigener Umlaufbahn, die ältesten am Kern, innen schneller. Kommt etwas hinein: kurzer Puls, die neue Einheit fällt vom Rand ein; leert sie sich: die Pixel platzen nach außen |
| **Verschlucken** (Ereignis `swallow`, `TalentPixels.stream`) | Die gefressene Materie strömt als Motten in ihren Farben auf gebogenen Bahnen vom Ort in den Mund (`tx, ty` + Brust); erst langsam, dann gezogen; am Mund ein dunkler Schluck. Partikel-`well` saugt den Staub am Ort. Gefühl small |
| **Singularität: Gefangene** (Zone `caught`, `TalentPixels.tether`) | Gegner lassen sich nicht bewegen, also hängen sie an dunkelvioletten Fesseln zum Kern; ihre Essenz (Farbe nach Gore-Material) fließt als Motten hinein, ein Flimmerring um sie zeigt das Aussaugen. Position: Eintrag mit x/y, `caught_at`, `enemy_at` des Hosts (Story-Welten: `story_feel.mob_at`) oder das Rig |
| **Urknall-Ausstoß** (Ereignis `eject`, `TalentPixels.comets`) | Ein Frame Leere am Kern, dann fliegen die Einheiten als Kometenpixel (Kopf + 3 Schweifzellen) auf einer Spirale hinaus und spritzen beim Landen; ihre Materie fliegt in den Partikeln mit (die Lachen macht der Host). Gefühl large |
| **Aufprall an der Wand** (Ereignis `splat`, `particles.splat_burst`) | Fleisch: Blutspritzer von der Wand zurück, Brocken die springen und liegen bleiben, Blut an Wand (läuft herunter) und Boden. Knochen: Splitter, Staubwolke, ein rollender Schädel (3x3, dreht sich beim Rollen). Leere: Motten. Gold: Münzen mit Glanz. Gerigte Gegner zerfallen entlang des Rückpralls (`rig_renderer.fling_near`). Gefühl large (Wackeln, kurzer Hitstop) |
| **Wahnsinn** (`boss_fx.gd _draw_madness`) | Gegner mit `mad` (Story: `m.mad_t`): 4 violette Pixel kreisen um den Kopf, Augen glühen violett, ab und zu steigt ein „?“ auf. Held: `mad_warn` lässt den Bildrand violett pulsieren (Dither, flüsternde Strichel); `mad` wellt den Rand und kippt ihn alle 1,7 s für 2 Frames ins Inverse (aus mit `vignette.flicker = false` oder Engine-Meta `reduce_flashing`) |

## 4d. Materie statt Malerei (2026-10-31, Befund `review-magier/BEFUND.md` 5, 7, 9, 10)

Gemalt bleibt nur, was eine **Form** ist: Blitz-Frame, Druck- und Schockringe, Kerne,
Risse, der Feuerball mit seinen Zungen, der Eisstern, die Gletscherspitzen als Körper.
Alles, was **fliegt**, ist ein Partikel in `src/vfx/particles.gd` mit Geschwindigkeit,
Schwerkraft, Boden- und Wandprall, Reibung und Liegenbleiben
(`TalentPixels.paint_matter` ist aus, sobald der Host Partikel hat):

| Vorher gemalt | Jetzt Physik |
|---|---|
| Rand-Trümmer jeder Nova | `talent_fx._rim`, wenn die Front ankommt (Glut, Splitter, Tropfen, Motten, Staub) |
| Funken-Bögen des Booms | `ember_sparks`: prallen ab, liegen als Glut |
| Splitter und Nebel des Shatter | `shatter` (rutschen, liegen als Reif, die Spitze glitzert: `ice.glint_*`) |
| Motten von Implosion, Leerenriss, Raumsprung, Singularität, Fesseln, Schlucken | Motten in einem `well` (Sog, Kern verschluckt), Auflösen per Dither |
| Flocken und Splitter im Blizzard | `particles.snow` (Flocke: fast schwerelos, flattert, liegt als Reif und taut) im Wind-`well` |
| Flammen und Glut im Meteorkrater | aufsteigende `flames` und `ember` |
| Funken der Glutkette | fliegen, wenn das Glied trifft |
| Gletschergrab: Splitter am Fuß jeder Spitze, Wurf aus der Hand | `shatter` beim Durchbruch bzw. beim Wurf |
| Kometen des Urknalls | `particles.comet`: ballistisch auf die echte Landestelle, platscht dort in die Pool-Ebene (`drop_landed`), Eis bricht, Knochen und Gold springen |

Budget: über `soft_cap` (0,8) von `max_particles` werfen kosmetische Emitter weniger
(`particles.room`), am Limit keine. Der Urknall wirft höchstens `gefuege.eject_max` = 10
Bolzen (`element_rules.json`), also wenige, dichte Landungen. Glow: kurz und eng
(`vfx_talents.json glow`, `vfx_particles.json glow`). Kleine Talente (`talent_events`):
Raumsprung stößt am Ziel den Boden an und wirft Motten, Leerenschild und Kristallschild
ziehen ihre Materie beim Aufbau an, splittern beim Treffer und zerbersten am Ende.

## 5. Stellschrauben (`assets/data/vfx_talents.json`)

- `shots.tiers.<stufe>`: core, trail, burst, parts, crack, glow; `shots.talent_tier` je Schuss-Talent; `shots.feel`; `shots.fizzle_tol`.
- `cast`: span, cells, reach, flash je Stufe; hand; kind_tier.
- `residue.<element>`: st (Material), cells [small, huge], share, cap, time; `chips`, `zone_time`, `path_every`.
- `traps`: net_over, radius, pulse, spring.
- `events`: neu `explosion: medium`, `leap_slam: medium`, `chain: small`; `ult_impact: huge` (der Meteor-Einschlag).
- `fire`: heart, tail, boom (time, flash, pulses, pulse_span, size, size_share, sparks, lie, scorch), spear, flammenmeer, chain, meteor, phoenix; `shots.talent_feel`, `residue.lava`, `residue.talent_residue`.
- `vfx_particles.json fire`: spark_speed, ember_lie, spark_soot (`particles.ember_sparks`).
- `frost`: lance, shatter, blizzard, sprung, shield, glacier, pet_lance; `void`: implode, lance, rift, fold, echo, shield, singularity, call, collapse; `residue.melt`, `residue.glatteis`; `dome.cracks/void_motes/ripple`.
- `vfx_particles.json void.implode_time`: 0,15 s (der Sog der Leere).
- `vfx_particles.json shot`: drops, drop_life, motes, mote_life, chips, chip_life (neue Helfer `particles.drops/motes/chips`).

## 6. Geprüft

- Ladeprüfung (`scripts/dev_load_check.gd`) aller geänderten Skripte: OK.
- Bench `scripts/bench_vfx.gd` vorher/nachher: siehe Bericht (Budget ≤ 18 ms Mittel bei Volllast).
- Hinweis: Die Ultimates in `talents.json` heißen `<spec>_14`; die Formen in
  `talent_ults.gd` matchen noch `<spec>_6` (Altstand) und zeichnen für die neuen
  Ultimates nichts – deren Takte kommen jetzt aus der allgemeinen Sprache
  (`cast` huge, `nova`-Physik, Rest nach Anteil). Die alte `pools`-Tabelle ist
  deshalb leer.
