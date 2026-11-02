# Physik-Plan (Bestandsaufnahme 2026-11-02)

Auftrag des Nutzers (2026-11-02): "Jetzt bitte die Physik im gesamten Projekt perfektionieren", dann: den ganzen Vorschlag von D1 bis D12 umsetzen, das Wochenkontingent dafür aufbrauchen und vor dessen Ende sauber anhalten (dann bis zur Rücksetzung warten). Diese Datei ist das Gedächtnis des Vorhabens: jede Sitzung und jedes Modell (auch Fable) liest sie zuerst und hakt erledigte Pakete im Status ab.

- Herkunft: Workflow `physics-audit` (5 Prüfer je Bereich, jeder Befund von einem zweiten Agenten am Code gegengeprüft, 1 Planer). 59 bestätigte Befunde, 1 verworfen.
- Rohdaten (alle Befunde, Pläne, Begründungen, englisch): [`docs/physik-audit-2026-11-02.json`](physik-audit-2026-11-02.json).
- Nur die drei Story-Welten zählen (Krypta, Frostgruft, Hölle auf `src/hell/hell_game.gd`); `src/game.gd` muss nur weiter laden.
- Ziel (seit 2026-10-30): jeder Effekt ist die Physik seines Elements; Schaden-Fußabdrücke bleiben deterministisch, alles andere ist Darstellung.
- Arbeitsweise: je Paket Load-Check + betroffene Tests + höchstens eine Probe mit Bild in einer Story-Szene; nach jeder Etappe ein Bild an den Nutzer; Commit/Push nur auf sein Wort (Ablauf: fetch, Bruder-Änderungen melden, Konflikte vorher melden, codex_v2 und main pushen).

## Entscheidungen D1–D12

### D1: Should the talents' leftover pools (fire, Glatteis, blood, void after shots, novas and blinks) affect gameplay? (F24, F15, F28)

- Look only: they show, ring and wet soles, but never hurt or trip anyone
- Gameplay for a named short list only (Feuerball blast fire, lava, Phönix trail, Frostsprung), laid by talent_combat on the host clock and sparing the caster
- Keep as now (random length, hurts the caster, comes from drawing code)

Empfehlung: Look only in Phase 1, because it fixes the self-burn bug and keeps footprints deterministic. Then add the short gameplay list as its own step, where a talent's text promises a ground effect.

**Entschieden:** Empfehlung angenommen: zuerst nur Optik (schadet/rutscht niemandem), danach eine kurze Liste mit echter Wirkung, wo der Talenttext es verspricht.

### D2: Should matter meeting matter change gameplay? This reverses the 2026-10-30 'visible only' decision (F12, F15).

- Yes, on the host clock with residue excluded: water on fire puts it out, poison gas over lava or fire ignites, poison on lava explodes, steam over ice condenses
- No: only fix the picture so it never contradicts the rules (fire stays visible, crust only where it is really crusted)
- Partly: only fire plus poison becomes real; water on fire stays visual

Empfehlung: Do the picture fix first (R9, no rule change). Then option 1, because it is what 'every effect is the physics of its element' means. It needs one balance check in Krypta and Hölle.

**Entschieden:** Empfehlung angenommen: erst das Bild korrigieren (keine Regeländerung), danach Option 1 (Materie trifft Materie ändert das Spiel), mit Balance-Check in Krypta und Hölle.

### D3: How should the Krypta's Moder behave in gameplay? (F48)

- Cold poison sludge: poison on it does nothing, water only ripples, debris sinks without glow
- Keep the lava rules (poison explodes, water boils) under the green look
- Sludge whose miasma a fire spell ignites into a flash

Empfehlung: Option 1. Today a poison puddle exploding on green sludge contradicts what the player sees.

**Entschieden:** Empfehlung angenommen: Option 1, kalter Giftschlamm.

### D4: How long should Glatteis last in the story worlds, and which liquids can frost freeze? (F17, F18)

- Melts by itself after ice_time 8 s (faster near lava or fire); only water freezes, blood and poison get a rime look only
- Lasts the pool's whole life as now; frost freezes water, blood and poison
- Melts only when fire touches it

Empfehlung: Option 1. It uses the existing element_rules.json ice_time, and monster poison is no longer silently removed by ice.

**Entschieden:** Empfehlung angenommen: Option 1, Glatteis schmilzt nach ice_time 8 s (nahe Feuer/Lava schneller); nur Wasser gefriert.

### D5: How hard should talent blasts and shockwaves push living enemies? (F37, F44, F40)

- Fix direction and make pushes add up now; ultimate-sized pushes only on the final blow; mass by body size normalized to the median mob so typical mobs are unchanged
- Full pushes by tier on every hit (enemies get thrown out of the Meteor crater and Singularität fields)
- Fix the direction only and keep 60 px/s

Empfehlung: Option 1. It is visibly physical without pushing enemies out of the hero's own lingering zones.

**Entschieden:** Empfehlung angenommen: Option 1, Richtung korrigieren und Stöße addieren; ganz große Stöße nur beim tödlichen Schlag; Masse nach Körpergröße, normiert auf den Median-Gegner.

### D6: Should enemy blasts and boss slams break crates, urns, seals and skull heaps? (F49)

- No: they only shake and chip them; only hero blasts break them
- Yes: everything breaks by distance, so bosses can release undead crates or open secrets

Empfehlung: Option 1.

**Entschieden:** Empfehlung angenommen: Option 1, nur Heldenzauber zerbrechen Requisiten; Gegner-Explosionen erschüttern nur.

### D7: Should a fire spell light an unlit puzzle fire bowl? (F56)

- Yes, but only the bowl a fire shot hits directly, the same as pressing E
- No: the puzzles stay E-only; fire only makes the flame flare

Empfehlung: Yes, direct hit only, so a single blast cannot light a whole puzzle out of order.

**Entschieden:** Empfehlung angenommen: ja, nur bei direktem Treffer eines Feuerschusses.

### D8: What should the world do during the 1.8 s after the hero dies? (F42)

- Everything keeps moving with damage off
- A uniform slow motion for everything, particles included
- Everything freezes, particles included

Empfehlung: Option 1. Slow motion is the cheaper fallback.

**Entschieden:** Empfehlung angenommen: Option 1, alles bewegt sich weiter, Schaden aus.

### D9: Should a knockback on Glatteis send the hero gliding? It can carry him into hazards. (F45)

- Yes, with about 60 % of the knock as glide
- A short glide (about 30 %)
- No: the knock stops as on stone

Empfehlung: 60 %. It matches how his own walking already slides on ice.

**Entschieden:** Empfehlung angenommen: 60 % des Stoßes als Gleiten.

### D10: What happens to gold that lands in lava, Moder or a pit? (F52)

- Credited at once, with a hiss or a plop
- Spat back onto the rim
- Lost

Empfehlung: Credited at once, because the player keeps the gold and still sees the physics.

**Entschieden:** Empfehlung angenommen: sofort gutgeschrieben, mit Zischen/Plopp.

### D11: Is the large depth-sorting job worth it (particles hidden behind monsters, pillars and the hero)? (F3)

- Yes, after the one particle world (R2)
- Only for low or settled matter
- No

Empfehlung: Yes, after R2, which halves the work.

**Entschieden:** Empfehlung angenommen: ja, nach R2 (eine Partikelwelt).

### D12: How should the brother's snow, wind and flame-tip parts be handled? (F57, F58, and the brother's parts of F16, F55, F56)

- He implements F57 and F58 and exposes a wind vector, a monster slide entry point and the flame tip; we use them
- We add small entry points in his files with his OK
- Leave snow and wind as they are for now

Empfehlung: Option 1. Ask him before Phase 4. Our phases 1-3 need nothing from his files except the optional flame tip in R21.

**Entschieden:** Nutzer 2026-11-02: "D12 jetzt machen" – wir bauen Schnee-Schmelzen, Wind als Weltkraft, Monster-Rutsch-Einstieg und Flammenspitze selbst in den Dateien des Bruders und markieren es im Commit zu seiner Durchsicht (wie fire_anim.gd).

## Themen

- T1 Spells do not meet the world: talent shots skip the end of their step and pass through walls at 37 fps or more (hell_talents.gd:459, checked: range(1, steps) never tests the end point). Talent explosions ignore props and breakables, impacts land at a guessed point, and talent hits get no hit reaction (F23, F47, F49, F34, F25).
- T2 Two matter worlds plus painted copies: the hero kit and attacks run their own Particles instance. hell_game.embers, StoryHero._bits, RigFx, gold coins and wreck shards each have their own, simpler physics. Ultimates and talent pixels paint drops, shards and embers next to their particle versions (F0/F32, F11, F51, F52, F54, F29, F30, F31).
- T3 Drawing code changes gameplay, which breaks the deterministic-footprint rule: residue pools placed by talent_fx with a random length hurt and trip the caster, and particles.freeze_liquids turns gameplay poison and blood into Glatteis (F24, F17; F15 and F28 caution).
- T4 The picture contradicts the rules: pool reactions are drawn against ElementRules.top (hidden fire still burns, a 'safe' crust still burns, poison hisses instead of exploding). Overlapping pools are drawn by spawn order. Reactions throw the wrong matter, poison gas burns from its centroid and comes back whole, and the Krypta's Moder runs the lava code (F12, F21, F13, F14, F26, F48).
- T5 Contact physics between materials is missing: gas over lava or fire, poison on lava and residue never react. Ice never thaws on its own, every gas moves the same way, and the necromancer's poison is a painted circle (F15, F18, F16, F28, F19).
- T6 One rule for all particle physics: every material bounces like rubber. There is no air drag or buoyancy, comet arcs are integrated with Euler, the wells miss their core, walls, gates and props are not solid to matter, blasts and wells act through walls, hitting the cap pops or teleports matter, and particles ignore the depth order (F1, F2, F9, F4, F8, F50, F5, F6, F7, F3).
- T7 Frame-rate dependence: knockback decays per frame, gas parting is applied per call, trails emit per draw, ambient embers and vents spawn per frame, and wall gaps and core misses grow with v·dt (F35, F22, F10, F51, F53, F8, F9, F4, F57).
- T8 Bodies: pushes are assigned instead of added and point away from the hero instead of the blast. They ignore mass, keep velocity into walls and stop dead on ice the same as on stone. Corpses freeze and vanish, and flights stop dead and snap upright (F37, F44, F46, F40, F36, F41, F45).
- T9 The Frostgruft lags behind Krypta and Hölle because it has no monster runtime: no pool reactions, ragdolls fly in random directions through walls, contact does not knock the hero, boss pushes teleport him, there is no wading, and freezing only happens in the other worlds (F20, F38, F39, F43, F55, F17).
- T10 Static world objects: traps and gates switch by swapping sprites, torches are sealed animation loops, and settled debris never moves again. On hero death everything freezes except the particles (F53, F56, F54, F42).
- T11 Owned by the brother (saidPC), needs his OK: snow does not melt from fire or blasts, the wind exists only in the screen overlay, there is no skid entry point for monsters, and the flame tip is not exposed (F57, F58, plus the brother's parts of F16, F55 and F56).
- Phase 1 picture: Hölle. A Feuerball talent hits a wall beside lava, with a barrel and an imp in reach. The burst sits on the wall face, chips fly off the wall normal, the hero's embers hiss out in the lava instead of lying on it, the barrel shatters along the blast, the imp bleeds from the talent hit, and no fire puddle is left under the mage.
- Phase 2 picture: Krypta room with Moder. A fire talent ignites a Giftwolke. A flame front runs through it puff by puff and leaves a fireball, embers, a scorch star and rising smoke, with no green veil. The Moder bubbles olive with miasma. A water puddle over burning ground still shows the fire.
- Phase 3 picture: Hölle. A blast next to a closed portcullis and a pillar. Drops splat with crowns and stick to the gate bars, smoke rises and widens, debris strikes the wall face, matter behind the pillar is hidden by it, gold bounces off the wall, a shard sinks into the lava with a plop, and the talent's matter is particles only.
- Phase 4 picture: Frostgruft. A Rage or Urknall throw across Glatteis. Bodies glide, then roll back upright. Ragdoll parts fly away from the blow and bounce off walls. Fire melts a snowman's frost pool rim first, with steam, into water that monsters slide and wade through.

## Arbeitspakete (Rangfolge, Etappen 1–4)

Status: `[ ]` offen, `[~]` angefangen, `[x]` erledigt (mit Commit). Befund-Nummern F.. beziehen sich auf `findings` in der JSON (Index).

### Etappe 1

#### [~] R1: Talent shots stop at the first wall and burst at the contact point

- Aufwand M (the sweep alone is S), Risiko low, Besitzer ours; Befunde F23, F47, F34
- Dateien: `src/hell/hell_talents.gd`, `src/combat/talent_combat.gd`, `src/vfx/talent_fx.gd`, `src/hell/story_wreck.gd`, `src/hell/hell_game.gd`, `src/vfx/mage_bolt.gd`, `src/hero/story_feel.gd`
- Jetzt: At 60 fps a talent shot never meets a wall: talent_blocked tests only interior samples, and none when the step is under 12 px. The shot turns invisible inside the wall, comes out in the next room and hits monsters behind the wall. talent_fx guesses the impact from the shot vanishing (talent_fx.gd:777), so the boom, shatter and residue appear where its 1.6 s life ends, often in mid-air about 700 px away. At low fps the shot just vanishes at the stone with no chips. MageBolt bursts inside the wall cell (mage_bolt.gd:146).
- Danach: _step_bullets gets its own sweep: samples every 6 px or less including the end point, then a bisection to the contact point and a normal from story_feel's side probes. The shot ends there. A shot_ends {at, normal, talent, style} list in the snapshot replaces talent_fx's guess, so the burst, sparks and shards fly off the wall normal from the wall face. The wall is worn through wreck.hit_line, which also breaks a smashable prop in the way; an unbroken breakable calls _hit_breakable. There is no extra feel.wall_hit (it would double the matter). In hell_game the MageBolt position is set to the contact before burst(). talent_blocked stays unchanged for the melee line-of-sight check.

#### [~] R2: One particle world for hero attacks, the kit and talents

- Aufwand M, Risiko medium, Besitzer ours; Befunde F0, F32, F10
- Dateien: `src/hero/story_skill_fx.gd`, `src/hero/story_hero.gd`, `src/vfx/skill_fx.gd`, `src/vfx/attack_fx.gd`, `src/vfx/particles.gd`, `src/hero/story_feel.gd`, `src/hell/hell_game.gd`
- Jetzt: Hero fireballs, fist bursts and shot impacts use a second Particles instance (story_skill_fx.gd:46, story_hero.gd:156). It has no sink, no liquids and no sound. Embers, soot and frost lie on top of Hölle lava, and the hero's floor marks are drawn over lava pools, gas, the ice slab and his own shadow. Blasts and the Singularität move the world's debris but not the hero's debris next to it. Hero matter makes no landing sound. Trails spawn once per draw call, so a 144 Hz screen shows 2.4× the trail of a 60 Hz one (skill_fx.gd:220, attack_fx.gd:366).
- Danach: skill_fx.particles, skill_fx.skill.particles and attack.particles point to g.feel.feedback.particles. A `shared` flag skips the second update, draw and clear calls. embers(), frost(), stain() and scatter() check sinks(), so the hero's embers hiss out in lava and his marks lie under the liquid surfaces. Every blast and well moves all matter, landings make sounds, and there is one budget (max_particles raised to about 900). Trails are emitted from update time per distance flown, so they look the same at any refresh rate.

#### [x] R3: Talent hits throw the target's own matter; talent swings clang on walls

- Aufwand S, Risiko low, Besitzer ours; Befunde F25
- Dateien: `src/hell/hell_talents.gd`, `src/combat/talent_combat.gd`, `src/vfx/talent_fx.gd`, `src/hero/story_feel.gd`
- Jetzt: _damage_enemy never calls g.feel.on_hit (hell_talents.gd:475). Wutschlag, Schildstoß, Schnittwunde, Fächerschnitt, Erdspalter, the dashes, every nova and Durchschuss show only the slash sheet and a white flash: no blood, bone chips, slime or spark from the target. Dash matter appears at the dash start in the class colour. Talent swings into walls are silent.
- Danach: Each talent hit runs story_feel.on_hit with the material's sound only once (the feedback path plays it). Blood drops splat, bone chips settle, slime splashes and the target squashes. A talent_swing_wall hook in talent_combat's melee branch and channel swing (:692) clangs on walls and props. Dashes raise dust along their path, and shot hits throw less matter.

#### [~] R4: Drawing code stops changing gameplay: residue pools and rime freeze become looks only

- Aufwand S for visual-only; M if residue becomes gameplay (D1), Risiko medium (removes damage and slips that players currently get), Besitzer ours; Befunde F24, F17
- Dateien: `src/vfx/talent_fx.gd`, `src/vfx/pool_paint.gd`, `src/physics_kit/pool_field.gd`, `src/vfx/particles.gd`, `src/hell/story_exposure_host.gd`
- Jetzt: A Feuerball into a nearby wall leaves fire that burns the Feuermagier himself ('im Feuer verbrannt'). Every Wirbelsturm or Blutiger Schrei leaves a blood slick under the berserker, even with no hit. A Frostlanze on a wall leaves Glatteis, and a fizzled void shot leaves a pool that hurts and silences. These pools come from draw passes with a random length (talent_fx.gd:342/959). The Blizzard's rime (particles.freeze_liquids → pool_field.freeze_near) silently turns a monster's poison puddle into slippery ice that no longer poisons, but only in Krypta and Hölle.
- Danach: Talent residue lives in its own visual-only PoolPaint: it shows, rings and wets soles, but never hurts or trips anyone. particles.freeze_liquids calls a new pool_paint.freeze_look that adds drawing-only ice and never writes pool_field. Gameplay ice comes only from story_elements.frost_at. Residue that should act in gameplay is decided under D1 and laid later from talent_combat events, sparing the caster.

#### [x] R5: Talent blasts bite walls and break props, crates and urns

- Aufwand M, Risiko medium (seals and skull heaps take blast hits), Besitzer ours; Befunde F47, F49
- Dateien: `src/hell/hell_talents.gd`, `src/combat/talent_combat.gd`, `src/hell/story_wreck.gd`, `src/hell/hell_game.gd`, `src/hero/story_feel.gd`, `src/hell/story_elements.gd`
- Jetzt: Meteor, Nova and talent explosions call only _element and never wreck.blast (talent_combat.gd:2499), so candles, bones and urns beside a Meteor stay whole. Crates, urns and barrels break only from the hero's swing and shots. A fireball or boss slam blows the candle beside a barrel to shards while the barrel does not even shake (story_wreck.gd:226).
- Danach: hell_talents walks the snapshot events once per id. Explosion, nova and impact events with r >= blast.min_radius call wreck.blast and the breakables hook. Pyro-shot events that _explode already blasted are tagged and skipped. Breakables in reach shake and chip, and those in the core shatter along hit_dir. Enemy blasts and owner-0 poison explosions only shake and chip them (D6).

#### [x] R6: Knockback distance and the Rage slam window no longer depend on the frame rate

- Aufwand S, Risiko low, Besitzer ours; Befunde F35
- Dateien: `src/physics_kit/motion_kit.gd`, `assets/data/physics_motion.json`, `src/hero/story_hero.gd`, `src/hell/hell_monsters.gd`, `src/hell/hell_game.gd`
- Jetzt: The push decays by 0.86 per frame (motion_kit.gd:163). A Rage throw flies about 111 px at 60 Hz, 46 px at 144 Hz and 223 px at 30 Hz. The slam only counts within about 72 px of a wall at 60 Hz, but 30 px at 144 Hz. A sword knock moves an enemy 18 px at 60 Hz and 7 px at 144 Hz.
- Danach: step_body uses push*pow(decay, dt*60), which keeps today's 60 Hz tuning exactly. It returns push_in and hit, so check_slam (story_hero.gd:222) stops hardcoding /0.86. Throws and slam windows are the same on every machine. R23 and R27 build on this.

### Etappe 2

#### [~] R7: Reactions throw their own matter: explosion, boiling, rain and thaw

- Aufwand M, Risiko low, Besitzer ours; Befunde F13
- Dateien: `src/hell/story_elements.gd`, `src/vfx/particles.gd`, `src/vfx/pool_paint.gd`, `src/physics_kit/gas_field.gd`
- Jetzt: A poison explosion is 22 green sparks bouncing on the floor plus a flash disc (story_elements.gd:411). In the Frostgruft it is only a shake and a flash. Boiling throws 5 frost-blue sparks. Condensing steam throws frost sparks upward before a puddle spreads from its middle. A thaw is 4 frost sparks.
- Danach: One helper that needs only _particles()/_pscale(), so it works in all three worlds. An explosion is fire_burst, tumbling embers, a scorch_star and a smoke cloud left behind (the old crypt pattern). Boiling is dense steam puffs rising for about 1 s. Rain is drops falling from the cloud's height over its area, building the puddle as they land through drop_landed. A thaw hisses and drips. The four frost _burst_in calls go away.

#### [x] R8: Ignited poison gas burns as a front, and burnt gas stays gone

- Aufwand M, Risiko medium (the explosion moves to where the gas really is), Besitzer ours; Befunde F14, F26
- Dateien: `src/physics_kit/gas_field.gd`, `src/hell/story_elements.gd`, `src/vfx/talent_fx.gd`, `src/combat/talent_combat.gd`, `src/vfx/gas.gd`
- Jetzt: Fire tests a cloud by its spawn centroid and radius (gas_field.gd:395-407). A cloud spread down a corridor goes off in its middle, and fire at its visible tail can miss. The green veil fades for 1.4 s and is blown outward by its own blast. A burnt or swallowed Giftwolke comes back whole on the next frame through GasField.sync (gas_field.gd:107), can explode again and keeps poisoning.
- Danach: GasField.ignite gives each puff burn_at = now + distance/speed on the host clock. Each puff flashes to flame (fire_burst) and becomes dark smoke, and damage applies once per cloud. Ignition tests real thickness (gas.thickness >= dense_from). end_cloud records the key as spent so sync never re-adds it, and the talent zone ends with the gas (tc end_zone).

#### [~] R9: The pool picture shows what the rules do

- Aufwand M, Risiko medium, Besitzer ours; Befunde F12, F21
- Dateien: `src/vfx/pool_paint.gd`, `assets/data/vfx_pools.json`, `src/hell/story_elements.gd`, `src/combat/element_rules.gd`
- Jetzt: Blood or water over burning ground hides the fire while the hero keeps burning, and the fire stays invisible after the blood dries. Poison touching fire hisses like steam. Blood, poison or water on lava paints a dark crust that reads as safe but still burns (pool_paint.gd:1605-1661). Overlapping pools are drawn in spawn order (pool_paint.gd:446): clean water is drawn over the poison that is poisoning you, and blood in water is a hard red sheet.
- Danach: The draw loop and liquid_at are sorted by ElementRules priority, so the material that acts is drawn on top. A liquid over fire is hidden and hisses at the rim instead of hiding the fire. Liquids on lava hiss away without crust, and crust is drawn only where story_elements.crusted() is true. Poison meeting fire or lava flares as flame. Drawing-only mixes (bloodwater, toxicwater) in vfx_pools.json tint water.

#### [x] R10: The Krypta's Moder is cold sludge, not lava

- Aufwand M, Risiko medium (the gameplay part needs D3), Besitzer ours; Befunde F48
- Dateien: `src/hell/hell_game.gd`, `src/hero/story_feel.gd`, `src/hell/hell_monsters.gd`, `src/hell/story_elements.gd`, `src/hell/story_wreck.gd`, `assets/data/krypta_balance.json`
- Jetzt: The green Moder bubbles orange-white lava domes at 9/s (hell_game.gd:3352-3385). They burst into orange glut drops that lie as embers and cool to soot. Liquids on it hiss and crust (story_feel.gd:786). Shockwaves throw orange lava tongues (hell_monsters.gd:3150). A poison puddle on Moder explodes and water boils (story_elements.gd:351). Krypta and Frostgruft debris sinks into tiles 2/3 with a heat glow, so even glaze ice swallows debris (story_wreck.gd:918).
- Danach: theme.liquid.material plus a hell_game._floor_mat() helper. Moder shows slow olive bubbles that pop into miasma wisps, green drops that lie as wet poison pixels, ripples and a sluggish slosh, with no embers, soot, steam or crust. Debris sinks into Moder without glow, and glaze ice never swallows debris. Puddle gameplay on Moder follows D3.

#### [~] R11: Each gas moves like its material, parting is per second, and shots cut lanes

- Aufwand M, Risiko medium (poison dose at high fps changes), Besitzer ours; Befunde F16, F22
- Dateien: `src/physics_kit/gas_field.gd`, `assets/data/vfx_gas.json`, `src/vfx/gas.gd`, `src/hell/hell_game.gd`
- Jetzt: All five gases share one set of constants (gas_field.gd:264). Boiling steam lies on the floor for about 6 s like poison, frost mist does not sink, and smoke behaves like poison. part() runs once per frame with no dt (gas_field.gd:227), so the hero parts gas 2.4× harder at 144 fps, and his poison dose and view range depend on the fps. cut() is only used by the old dungeon, so arrows, fireballs and monster shots fly through clouds without leaving a lane.
- Danach: vfx_gas.json gets per-material physics (swell, thin, spread, drift, hold). Steam swells and is gone in about 1.5 s with a drawn rise, smoke swells and lingers, poison creeps low into corners, and frost mist spreads wide and flat. part() and cut() take dt. Every eshot and talent bullet inside a cloud cuts a lane that closes behind it, and the monsters' part radius scales with m.r.

#### [~] R12: Pools land at impact and shrink while they drain

- Aufwand S, Risiko medium (timing of damage cells), Besitzer ours; Befunde F19
- Dateien: `src/physics_kit/pool_field.gd`, `src/vfx/pool_paint.gd`, `src/hell/story_elements.gd`
- Jetzt: A thrown poison potion shatters, nothing lies there for about 0.33 s, then the full 5000-cell pool appears in one frame together with its splash (pool_field.gd:181, timings from the zone start). A pool drained by a void mouth stays full while its motes stream away, then vanishes rim first in 0.35 s.
- Danach: Threaded pools count their cell births from max(start, commit). That is still deterministic, so the pool spreads after it shows, and the crown and drops play at impact. PoolField.retime(key, now, new_end, toward) shrinks a drained pool toward the mouth, far rim first.

#### [~] R13: Contact reactions for any matter, whatever made it (after D2)

- Aufwand M, Risiko medium (gameplay change, reverses the 2026-10-30 'visible only' decision), Besitzer ours; Befunde F15, F12
- Dateien: `src/hell/story_elements.gd`, `src/physics_kit/pool_field.gd`, `src/physics_kit/gas_field.gd`
- Jetzt: Between attacks only two checks run: water against lava circles, and puddle centres on a tile-2 floor (story_elements.gd:178/349/441). Poison gas drifting over Hölle lava or a fire puddle never ignites. A poison puddle on lava does nothing. Steam over Frostgruft ice never condenses, and frost mist over water never freezes.
- Danach: A 0.2 s contact pass checks a few gas puffs per cloud against materials_at and the hot floor, and calls fire_at, frost_at or condense. PoolField.pools_near returns both zones and field pools, so the same meeting always reacts the same way. Residue stays out per D1. Depends on R4 and R8.

#### [ ] R14: Seuchenfeld becomes real poison gas over a pool, Seelensturm a soul well

- Aufwand M, Risiko medium, Besitzer ours; Befunde F28
- Dateien: `src/vfx/talent_fx.gd`, `src/hell/story_exposure_host.gd`, `src/physics_kit/gas_field.gd`, `src/physics_kit/pool_field.gd`
- Jetzt: The necromancer's plague is a see-through circle (alpha 0.16) with a looping poison sheet (talent_fx.gd:1741). It never spreads, is never blown away, never explodes and lays no pool, yet it poisons everything in r every second. Seelensturm is a sprite loop.
- Danach: Plague is spreading poison gas over a poison pool of about 0.8 r. It parts around bodies, is blown by blasts and burns as a front (R8). It spares its owner through an owner field in the cloud and pool records that StoryExposureHost filters on. Seelensturm swirls soul motes on a particles.well with suck=false. The sprite stays only when gas is null. Depends on R4 and R8.

### Etappe 3

#### [~] R15: Each material lands its own way; buoyancy and air drag

- Aufwand M, Risiko low, Besitzer ours; Befunde F1, F2
- Dateien: `src/vfx/particles.gd`, `assets/data/vfx_particles.json`
- Jetzt: Every particle mode shares one contact rule (particles.gd:1872). Drops hop and roll 5-10 px like beads. Flames and smoke bounce off walls. Ice shards, rubble and skulls skate across lava and only vanish where they come to rest. Water drops vanish in lava silently, kicked wet pixels just disappear, and pool pixels fly off as hard chips. There is no drag on vz (particles.gd:1905): flakes speed up while falling, smoke, steam and embers accelerate upward forever as rigid columns, and motes 'rise' by sliding north into walls (particles.gd:1394/1497). A flame's glow stays white-yellow at full strength, then pops off (particles.gd:2214).
- Danach: Per-mode contact data in vfx_particles.json (wall: bounce, slide or stick; floor: bounce or splat) with a separate `stuck` flag, not `landed`. Drops splat on first contact with a short streak and a 1-2 px crown, ring into pools and paint wall faces. Flames and smoke creep along walls. Matter that touches lava at z<=0 sinks at once with a hiss or a plop (the skull branch too). vz gets air drag with a terminal speed: flakes drift down, smoke widens, embers rise then fall as they cool, and motes rise in height. Flame glow cools along the ramp. Comet modes keep air 0.

#### [x] R16: Walls, gates and props stop matter; blasts and wells cannot act through walls

- Aufwand M, Risiko low, Besitzer ours; Befunde F50, F8, F5
- Dateien: `src/vfx/particles.gd`, `src/hero/story_feel.gd`, `src/hell/hell_game.gd`
- Jetzt: Blood drops, chips, shards and rubble sail through closed portcullises, pillars, braziers, chests and crates and settle under or behind them (particles.gd:177, story_feel.gd:791). Gas does stop there. Debris turns away before the wall: 4 crypt px short at 60 fps, up to 13 at the dt clamp. It slips through corners, and matter born inside a wall passes through it. A blast or the Singularität makes debris in the next room jump, or drags pixels from behind a wall (particles.gd:1609-1727, 930-950, 1272-1292).
- Danach: Closed doors, solid prop footprints and unbroken breakables are erased from the particles' walkable cells and restored when a door opens or a crate breaks. Drops splat on the gate bars and debris bounces off pillars. Wall hits clamp to the crossed cell face at any fps, corners reflect on the smaller penetration, and matter born in a wall leaves on the open side. kick, blow, _suck and the wells use a cached DDA _sees(), so matter behind a wall stays put.

#### [~] R17: Talent looks become particles: only shapes stay painted

- Aufwand M, Risiko low, Besitzer ours; Befunde F29, F30, F31, F27, F33, F34
- Dateien: `src/vfx/talent_ults.gd`, `src/vfx/talent_pixels.gd`, `src/vfx/talent_fx.gd`, `src/hell/hell_talents.gd`
- Jetzt: Erdspalter's slam plays the old Blutrausch blood fountain (talent_ults.gd:78/529). Eissturz, Blutwelle, Feuersturm, the Meteor call, the flask and the Klingensturm finale paint drops, shards and embers on top of their particles or instead of them. A talent shot's embers travel with the ball and never fall behind (talent_pixels.gd:915). Impact drops and motes are painted next to their particle versions, and the Glutkette's flames hang where the target was. Schildwall and Seelenschild shatter into ice, and stone domes chip ice (talent_fx.gd:1262/2368). Pfeilhagel lands on its own clock with no matter (talent_fx.gd:1722). Archer arrows throw gold, coin-like chips (talent_fx.gd:890).
- Danach: Painted matter is gated by paint_matter. Shots shed world-space embers, frost and motes per second from _step_bullets. Erdspalter kicks dust at take-off and throws rubble at landing. A burning target carries its fire. Domes chip and fall in their own element (stone plates and dust, soul motes, ice). Pfeilhagel volleys land on the damage ticks with chips, dust and a quivering shaft. Arrows splinter back off the surface with one tip spark.

#### [~] R18: Every flying thing uses the one particle world: world embers, hero side matter, rig chips, gold, wreck piles

- Aufwand L, Risiko medium, Besitzer ours; Befunde F51, F11, F52, F54
- Dateien: `src/hell/hell_game.gd`, `src/hell/hell_monsters.gd`, `src/hell/boss_kit.gd`, `src/hero/story_hero.gd`, `src/hell/card_kit.gd`, `src/rig/rig_renderer.gd`, `src/rig_kit/rig_fx.gd`, `src/hell/gold_loot.gd`, `src/hell/story_wreck.gd`
- Jetzt: hell_game.embers and _burst (every hero blast, boss phase and death, well and level-up) are straight-line squares with no gravity that fly through walls (hell_game.gd:2198/3174). They spawn per frame, so 144 Hz shows 2.4× as many, and the 360 cap slices them off at full alpha. Block, counter and blood-price matter uses its own gravity and never lands (story_hero.gd:552). Rig chips fly through walls. Gold coins fly into walls and lie glinting on lava (gold_loot.gd:177). Settled wreck shards never move again, ice chips never melt, and shards lie on top of pits (story_wreck.gd:772).
- Danach: _burst and the ambient embers go to the feel particles at a rate per second through room(). Sparks fall, bounce, lie as embers and turn to soot, ambient lava embers rise buoyantly, and the Krypta gets miasma instead of embers. Blood-price drops stain. Rig chips with a known floor point land. Coins bounce off wall faces, sink into lava with a hiss (D11) and are relaunched by blasts. Wreck piles are relaunched by blasts and fronts, ice chips melt, and pieces over pits fall in.

#### [~] R19: No popping at the particle cap, frost always melts, cheap Gefüge blob

- Aufwand S, Risiko low, Besitzer ours; Befunde F6, F7
- Dateien: `src/vfx/particles.gd`
- Jetzt: At the cap the oldest particle is removed (particles.gd:1945). Mid-air chunks and drops snap to the floor, smoke vanishes in one frame, and a comet can lay its puddle mid-flight. At the frost cap the dropped melt entries stay frozen forever (particles.gd:2400). The whole _vapor list, up to 4000 entries, is rescanned every frame. The fused Gefüge blob costs about 30k distance operations and 625 draw_rect calls per frame (particles.gd:1231).
- Danach: One scan per frame picks unprotected, nearly dead cosmetic matter, which dithers out, with a hard cap at 1.05×. Airborne matter never teleports and comets always land. smoke, steam, kick and rubble go through room(). Frost always melts, and _vapor uses due-time buckets. The Gefüge blob is baked to a texture on the 12 fps beat, with one-pass nearest-lump lookups and no str().

#### [x] R20: Comets land on the gameplay spot; wells swallow along the path

- Aufwand S, Risiko low, Besitzer ours; Befunde F9, F4
- Dateien: `src/vfx/particles.gd`, `assets/data/vfx_particles.json`
- Jetzt: Comets (gore and pool splashes) land about one frame early and 6-18 crypt px short of where gameplay hits, and clink off pillars (particles.gd:656/1905). Matter near the Singularität crosses its core and slingshots back and forth, worse at low fps (particles.gd:941). A rubble block swirls like a mote.
- Danach: Exact ballistic height (z += vz·dt - ½g·dt²) with a touchdown back-off, so comets land at the gameplay spot at any fps. Splash particles skip wall collision while high. A swept closest-approach test swallows matter whose path crosses the core (fuse particles skipped), the speed change per step is capped, and the well force is divided by mass: dust streams in first and rubble drags.

#### [~] R21: Traps, gates, vents and torches move and shed matter (fire_anim flame-tip hook needs the brother)

- Aufwand M, Risiko low, Besitzer ours; Befunde F53, F56
- Dateien: `src/hell/hell_game.gd`, `src/vfx/particles.gd`, `src/vfx/fire_anim.gd`
- Jetzt: Spikes flip between sprites (hell_game.gd:3719). Ice traps vanish in one frame (:4377). Hölle vents and the Krypta's grave-gas vent spit straight ember squares (:3097). Portcullises pop in although the toast says 'Die Gitter fallen' (:4113). Torches and braziers are sealed loops (:3673): no sparks, no smoke, no lean from a blast, no dimming from frost or water.
- Danach: Presentation edge timers sit on the gameplay booleans. Spikes shoot up with overshoot and grit, ice spikes burst with chips and break into frost shards, vents roar buoyant flames and smoke, and the grave vent breathes green gas. Gates drop in 0.15-0.2 s with dust and a camera kick. Torches shed embers and a thread of smoke, lean and flare or gutter from pressure fronts, and hiss and dim near frost or water, all with per-second accumulators and only in view. Lighting bowls with fire follows D7.

#### [x] R22: Particles are hidden by actors and props by depth

- Aufwand L, Risiko medium, Besitzer ours; Befunde F3
- Dateien: `src/hero/story_feel.gd`, `src/hero/story_hero.gd`, `src/hell/hell_game.gd`, `src/vfx/particles.gd`
- Jetzt: All flying matter is drawn at z 12, above the y-sorted actors at z 10 (story_feel.gd:147/652, hell_game.gd:418). Chunks, skulls, shards and drops behind a monster, Ignaroth, a pillar, a brazier, a chest or the hero are painted over them.
- Danach: Particles are band-drawn inside _draw_actors by floor y. Matter north of a foot is covered, matter south of it covers. High matter and the glow pass stay on top. Depends on R2, so only one instance needs banding.

### Etappe 4

#### [~] R23: Pushes add up, point away from the blast, scale with mass and respect walls

- Aufwand L, Risiko medium (balance), Besitzer ours; Befunde F37, F44, F46, F40
- Dateien: `src/hell/hell_talents.gd`, `src/combat/talent_combat.gd`, `src/hell/hell_game.gd`, `src/hell/hero_kit.gd`, `src/physics_kit/motion_kit.gd`, `src/hell/hell_monsters.gd`, `src/hell/story_elements.gd`, `src/hell/sub_kit.gd`, `assets/data/physics_motion.json`
- Jetzt: Talent hits set m.k to 60 px/s away from the hero, even for blasts (hell_talents.gd:477). Meteor, Nova and Urknall move living enemies about 7 px, and an enemy between the hero and the impact is pulled into it. Every zone tick resets a running shove, and photon beam ticks stop bodies dead mid-flight (hell_game.gd:1984). A sword pushes a Glutimp and a Kettenschinder the same. Thrown bodies pass through packs. On ice, monsters keep pressing into walls, stay stuck inside newly spawned ice or gravity walls, and leap slams hop through wall cells (motion_kit.gd:155). Boss shockwaves never shove adds or gas.
- Danach: Impulses are added and clamped at about 1000 px/s, point away from the blast centre, scale by tier (D5) and by mass ((r/r_ref)², kit bosses immovable). Ticks and beams never cancel a flight. Flung or slammed bodies knock others like bowling pins (restitution 0.4). The velocity into a blocked axis is lost, bodies are pushed out of new solids, leap paths are marched in 8 px samples, and wave fronts shove non-kit monsters once per front. Depends on R6.

#### [~] R24: Felled bodies keep the blow; flights skid, land and roll upright

- Aufwand M, Risiko medium, Besitzer ours; Befunde F36, F41
- Dateien: `src/hell/hell_monsters.gd`, `src/combat/talent_combat.gd`, `src/hero/story_hero.gd`, `src/vfx/talent_fx.gd`, `src/hell/frost_moves.gd`, `src/hell/boss_kit.gd`, `src/physics_kit/motion_kit.gd`
- Jetzt: 13 of the 18 Hölle monsters freeze where they die, play one death row and vanish after 0.75 s (hell_monsters.gd:575/1696). The blow's momentum and the Urknall tumble are dropped. Urknall flights stop dead from 760 px/s and snap upright (talent_combat.gd:2548). Rage slam kills fly into the wall. Frostgruft dash and Golem charge wall hits are silent.
- Danach: Corpses slide with the blow, with friction, stop at walls and turn with their tumble, then dissolve as now, with ash or ember particles carrying the velocity. Flights slow down (speed·sqrt(left/total), floor 0.25) and roll back upright to the nearest TAU. Slam kills splat on the wall and come apart away from it. Dash and charge wall hits crunch with dust, a shake and a small recoil.

#### [~] R25: One freeze rule on the game clock; ice thaws rim first and on a timer

- Aufwand M, Risiko medium (gameplay ice duration), Besitzer ours; Befunde F17, F18
- Dateien: `src/vfx/pool_paint.gd`, `src/physics_kit/pool_field.gd`, `src/hell/story_elements.gd`, `src/hero/story_feel.gd`, `assets/data/element_rules.json`
- Jetzt: Frozen zones are never marked frozen, so lightning still charges them and fire still boils them. The Frostgruft talents freeze nothing (story_feel.gd:638-642). Glatteis lasts the puddle's whole life, even beside lava (story_elements.gd:140/371). Fire pops it back to water in one frame with 4 frost sparks. Fire on a monster's frost pool does nothing in the rules.
- Danach: story_elements.frost_at freezes its zones through a keys filter in pool_field.freeze_near, the same in all three worlds; the Frostgruft talent layer is added to set_liquids. Ice melts rim first from the fire's side over 0.5-1 s with steam and drips (per-cell thaw times, 'thawed' events in batches). It melts by itself after ice_time, faster near heat (D4). Fire on an ice pool lays melt water.

#### [~] R26: The Frostgruft joins the element and body physics: pools, wading, ragdolls, contact knock, boss pushes

- Aufwand L, Risiko medium, Besitzer ours; Befunde F20, F55, F38, F39, F43
- Dateien: `src/hell/story_elements.gd`, `src/hell/frost_moves.gd`, `src/hell/frost_fx.gd`, `src/hell/hell_talents.gd`, `src/hero/story_items.gd`, `src/hell/hell_game.gd`, `src/hell/frost_rigs.gd`, `src/hell/drake_rig_host.gd`, `src/hell/boss_kit.gd`, `src/combat/talent_combat.gd`, `assets/data/frost_theme.json`
- Jetzt: Frostgruft: no pool reactions, and potions are plain circles. Snowmen's frost patches slip only the hero, inside a circle, and vanish with no melt water (frost_moves.gd:494). Nobody wades (hell_game.gd:2842), and lava and Moder tiles have no wading in any world. Ragdolls scatter in random directions and fly through walls, and Urknall figures stay upright (frost_rigs.gd:137). Body contact, dashers and the Golem's charge never knock the hero (hell_game.gd:2942). Boss phase pushes teleport him 160 px (boss_kit.gd:89), the vortex sticks him at walls, and Unbezwingbar's knockback immunity does nothing.
- Danach: The Frostgruft's pool layer becomes the rules' truth: frost_moves and hero pools sync into it, monsters slide on them, and pool_paint draws cracks and melt water. Everyone wades with rings and wet soles (stable m.wk keys), and lava and Moder steps work everywhere. Ragdolls fly away from the blow with the kill stamp and tumble, and bounce off walls (renderer.solid). Contact, dashes and charges knock the hero. Boss pushes are eased knocks with distance falloff, pulls slide along walls, and cc_immune stops every forced move. Monster skid marks are in R30 (brother).

#### [~] R27: A knock on ice sends bodies gliding

- Aufwand M, Risiko medium, Besitzer ours; Befunde F45
- Dateien: `src/physics_kit/motion_kit.gd`, `assets/data/physics_motion.json`
- Jetzt: On Glatteis (grip 0.015) a frost wave stops the hero as dead as on stone, because the eased knock never touches player.vel (motion_kit.gd:100). There are no skid marks and no lean. Monster pushes decay the same on ice as on stone.
- Danach: A knock on ground with low grip hands about 60 % of its speed to player.vel (D10). The hero glides, and the brother's existing frost_snow skid and lean logic follows without any edit to his file. Monster pushes decay with a softened grip (at least 0.12), so a Rage throw glides further but not across the room. Depends on R6.

#### [~] R28: The world keeps moving during the hero's death beat

- Aufwand M, Risiko medium, Besitzer ours; Befunde F42
- Dateien: `src/hell/hell_game.gd`
- Jetzt: For 1.8 s after death (hell_game.gd:2540) enemy bolts hang in the air, ragdoll pieces stop mid-flight, and pools and gas freeze, while blood, dust and embers keep flying around them.
- Danach: Everything steps passively with damage off: shots fly and hit walls harmlessly, and rigs, corpses, gas and pools continue. Or, per D8, a uniform slow motion applies to everything.

#### [~] R29: [Brother] Fire and blasts melt and throw snow

- Aufwand M, Risiko low, Besitzer brother; Befunde F57
- Dateien: `src/hero/frost_snow.gd`, `src/hell/hell_game.gd`
- Jetzt: In the Frostgruft a Feuerball, Meteor or Flammenmeer leaves pristine snow under the embers and soot, and footprints still form in scorched spots. Slide chips are flat rects falling in screen y with no floor; they vanish in mid-air and spawn per frame (frost_snow.gd:157-175).
- Danach: Fire melts snow into a dark wet patch with the hand-made thaw_a slush edge and steam, which slowly refreezes. Blasts dig a crater and throw clods that land. Chips are emitted per N px slid as feel particles and lie as frost.

#### [~] R30: [Brother] Wind is a world force, plus entry points for monster skids and the flame tip

- Aufwand M, Risiko low, Besitzer brother; Befunde F58, F16, F55, F56
- Dateien: `src/vfx/snowstorm.gd`, `src/hero/frost_snow.gd`, `src/vfx/fire_anim.gd`, `src/vfx/particles.gd`, `src/vfx/gas.gd`
- Jetzt: The snowstorm's flakes are glued to the camera with no parallax (snowstorm.gd:137). Nothing in the world feels the wind: gas, smoke, flames, motes and the talents' snow drift as in still air. Frostgruft monsters sliding on glaze leave no skid marks.
- Danach: Flakes are world matter at three depths with parallax. The brother exposes one wind vector (screen px/s ÷ zoom ÷ feel.scale) that we apply to the light particle modes (weighted by drag), to the gas drawing drift and to torch lean. frost_snow gets a slide entry point for monsters, and fire_anim exposes the flame tip for R21.

## Schnelle Korrekturen (Etappe 1)

- [x] F23 hell_talents.gd:543: give _step_bullets its own sweep that also tests the end point and leave talent_blocked unchanged (verified: range(1, steps) at :459 skips the end, so at 60 fps no talent shot ever meets a wall).
- [x] F35 motion_kit.gd:163: use push*pow(decay, dt*60), which keeps 60 Hz tuning, and return push_in so story_hero.gd:222 stops dividing by 0.86. Throws and the Rage slam become the same at any fps.
- [~] F25 hell_talents.gd:475: call g.feel.on_hit(m, direction, false) in _damage_enemy's feedback block, and the old sound only when there is no feel. Every talent hit throws blood, chips or slime.
- [x] F26 gas_field.gd end_cloud plus sync (:107): record spent keys so a burnt or eaten Giftwolke never comes back whole the next frame.
- [x] F22 gas_field.gd:227/243: add dt to part() and cut() (speed*k*12*dt), so gas parting and the poison dose no longer depend on the fps.
- [~] F29 talent_ults.gd:78: stop mapping berserk_14 (now Erdspalter) to the old Blutrausch blood fountain.
- [x] F27 talent_fx.gd:1262/2368: set _shield_el from Pal.element_of for every shield talent and read the dome's own element in _dome_hit_physics. Schildwall stops shattering into ice.
- [x] F13 story_elements.gd:411: build _explode from particles.fire_burst, embers and scorch_star plus a smoke cloud, like the old crypt's feedback.gd:191-197, instead of 22 green sparks.
- [ ] F19 pool_field.gd:181: count threaded pool births from max(start, commit), so a potion pool spreads after it appears instead of popping in already spread.
- [x] F39 hell_game.gd:2942 plus frost_theme.json: after a landed Frostgruft contact hit, call frost_fx.hit_hero with 'contact' or 'dash' and add knock.contact 300. The Golem's charge finally shoves the hero.
- [x] F38 frost_rigs.gd:137: add e.kill (from hit_fx or m.k), e.tumble and renderer.solid = box_blocked. Frostgruft ragdolls then fly away from the blow and stop at walls.
- [x] F9 particles.gd:1905: integrate comet height exactly (z += vz·dt - ½g·dt²), so splashes land where gameplay hits.
- [x] F4 particles.gd:941: add a swept closest-approach core test in _step_wells (skip fuse particles), so no more slingshot through the Singularität.
- [~] F6 particles.gd:2400/2405: at the frost cap, melt the dropped entry immediately instead of leaving it frozen forever.
- [~] F52 gold_loot.gd:177: per-axis g.box_blocked bounce with v *= -0.4, so coins stop flying into walls.

## Alle bestätigten Befunde (Kurzfassung)

| F | Bereich | Art | Wirkung | Aufwand | Besitzer | Ort | Befund |
|---|---|---|---|---|---|---|---|
| F0 | core | inconsistent | 5 | M | ours | `src/hero/story_skill_fx.gd:46` | Hero skills/attacks run a second, disconnected particle world: embers and frost lie on top of Hölle lava, gas and the ice slab |
| F1 | core | missing-physics | 4 | M | ours | `src/vfx/particles.gd:1872` | All matter makes contact like a rubber ball: drops bounce and slide, fire and smoke bounce off walls, shards skate across lava |
| F2 | core | missing-physics | 4 | S | ours | `src/vfx/particles.gd:1905` | No air drag on height and weightless matter cannot rise: flakes speed up, smoke and embers shoot up forever, motes 'rise' across the floor |
| F3 | core | inconsistent | 3 | L | ours | `src/hero/story_feel.gd:652` | Particles are never hidden by actors or props: debris behind a monster, pillar or hero is drawn in front of it |
| F4 | core | tunneling | 3 | S | ours | `src/vfx/particles.gd:941` | Void wells miss their own core: fast matter jumps across it and slingshots back and forth, worse at low fps |
| F5 | core | inconsistent | 3 | M | ours | `src/vfx/particles.gd:1609` | Blasts and wells act through walls: kick, blow, the wells' pull and _suck have no occlusion |
| F6 | core | bug | 3 | S | ours | `src/vfx/particles.gd:1945` | Eviction at the cap teleports airborne debris to the floor and pops cosmetics; most emitters bypass room(); frost at its cap never melts |
| F7 | core | performance | 3 | S | ours | `src/vfx/particles.gd:1231` | Gefüge blob drawing is an O(pixels × lumps × 2) GDScript loop every frame |
| F8 | core | tunneling | 2 | S | ours | `src/vfx/particles.gd:1873` | Wall hits bounce off empty air up to v·dt short of the wall; corners are cut; matter born in a wall passes through it |
| F9 | core | frame-rate | 2 | S | ours | `src/vfx/particles.gd:656` | Comets land early and short by about v·dt (Euler vs analytic arc) and clink off walls away from the gameplay spot |
| F10 | core | frame-rate | 2 | S | ours | `src/vfx/skill_fx.gd:220` | Trail particles are emitted inside draw calls, so their density scales with the refresh rate |
| F11 | core | inconsistent | 2 | M | ours | `src/hero/story_hero.gd:552` | Hand-rolled side physics (StoryHero._bits, RigFx) with other gravity, no floor and no residue |
| F12 | fluids | inconsistent | 5 | M | ours | `src/vfx/pool_paint.gd:1605` | Pool reactions are only drawn and contradict the rules: fire that looks put out keeps burning, crust that looks safe still burns, poison hisses instead of exploding |
| F13 | fluids | painted-not-simulated | 5 | M | ours | `src/hell/story_elements.gd:411` | Reactions throw the wrong matter: boiling flings frost sparks, a poison explosion is green sparks, condensing rain is thrown upward |
| F14 | fluids | missing-physics | 4 | M | ours | `src/hell/story_elements.gd:112` | Ignited poison gas does not burn: it fades green from its centroid and gets blown outward by its own blast |
| F15 | fluids | missing-physics | 4 | M | ours | `src/hell/story_elements.gd:178` | Contact reactions barely exist: poison gas over lava or fire never ignites, poison onto lava does nothing, residue pools never react |
| F16 | fluids | missing-physics | 4 | M | ours | `src/physics_kit/gas_field.gd:264` | All five gases move the same: steam lies on the floor like poison, frost mist doesn't sink, no gas feels the Frostgruft wind |
| F17 | fluids | bug | 4 | S | ours | `src/vfx/particles.gd:1540` | Frost from the drawing code freezes gameplay pools, poison and blood included, but only in Krypta and Hölle |
| F18 | fluids | missing-physics | 4 | M | ours | `src/hell/story_elements.gd:140` | Glatteis never thaws on its own, pops back to water in one frame when fire thaws it, and fire cannot melt a monster's frost pool |
| F19 | fluids | bug | 4 | S | ours | `src/physics_kit/pool_field.gd:181` | Big pools pop in late and already spread; pools drained by the void stay full, then collapse |
| F20 | fluids | inconsistent | 4 | L | ours | `src/hell/story_elements.gd:183` | Frostgruft pools sit outside the element physics: no reactions, monsters never slide on move ice, potions are plain circles |
| F21 | fluids | inconsistent | 3 | M | ours | `src/vfx/pool_paint.gd:446` | Overlapping pools hide each other by spawn order, not by which one acts, and liquids never mix |
| F22 | fluids | frame-rate | 3 | S | ours | `src/physics_kit/gas_field.gd:227` | Gas parting depends on the frame rate, and shots never cut through gas in the story worlds |
| F23 | abilities | tunneling | 5 | S | ours | `src/hell/hell_talents.gd:459` | Talent projectiles never check the end of their step, so at 60 fps they fly through every wall |
| F24 | abilities | bug | 5 | M | ours | `src/vfx/talent_fx.gd:342` | Residue pools are made by the drawing code, yet they hurt and trip the hero and monsters |
| F25 | abilities | missing-physics | 5 | S | ours | `src/hell/hell_talents.gd:475` | Talent hits get no hit reaction from the creature, and talent swings throw no matter |
| F26 | abilities | bug | 4 | S | ours | `src/vfx/talent_fx.gd:353` | Giftwolke gas comes back whole right after it explodes or is swallowed, and can be set off again |
| F27 | abilities | inconsistent | 4 | S | ours | `src/vfx/talent_fx.gd:1262` | Schildwall and Seelenschild look like Kristallschild and shatter into ice; stone domes chip ice |
| F28 | abilities | inconsistent | 4 | S | ours | `src/vfx/talent_fx.gd:1741` | The necromancer's poison and soul zones are see-through circles and sprite sheets, not gas or pools |
| F29 | abilities | painted-not-simulated | 4 | M | ours | `src/vfx/talent_ults.gd:529` | Ultimate painters ignore paint_matter; Erdspalter still plays the old Blutrausch blood fountain |
| F30 | abilities | painted-not-simulated | 4 | M | ours | `src/vfx/talent_pixels.gd:915` | Talent shots paint their flight matter, while the left-click bolts shed real particles |
| F31 | abilities | painted-not-simulated | 3 | S | ours | `src/vfx/talent_pixels.gd:1319` | Impact drops, motes, shards, feathers and the Glutkette's flames are painted next to their particle twins |
| F32 | abilities | inconsistent | 3 | M | ours | `src/hero/story_skill_fx.gd:46` | The hero kit and attacks use a second particle world that wells, blasts, pools and gas never touch |
| F33 | abilities | painted-not-simulated | 3 | M | ours | `src/vfx/talent_fx.gd:1722` | Pfeilhagel: arrows fall on a free-running clock, not the damage ticks, and leave no matter |
| F34 | abilities | missing-physics | 3 | S | ours | `src/vfx/talent_fx.gd:890` | Arrow and bolt impacts are gold sparks and coin-like chips at a guessed point, never splinters off the surface |
| F35 | bodies | frame-rate | 5 | S | ours | `src/physics_kit/motion_kit.gd:163` | Monster knockback decays per frame, so throw distance and the Rage slam window change with the frame rate |
| F36 | bodies | missing-physics | 4 | M | ours | `src/hell/hell_monsters.gd:1696` | Hölle bodies freeze where they died, play one death row and vanish after 0.75 s |
| F37 | bodies | bug | 4 | M | ours | `src/hell/hell_talents.gd:477` | Talent hits replace the knockback with 60 px/s away from the hero, ignoring where the blast was |
| F38 | bodies | inconsistent | 4 | S | ours | `src/hell/frost_rigs.gd:137` | Frostgruft ragdolls scatter randomly, fly through walls and never tumble |
| F39 | bodies | inconsistent | 4 | S | ours | `src/hell/hell_game.gd:2942` | Frostgruft body contact, dashers and the Golem's charge never knock the hero back |
| F40 | bodies | missing-physics | 4 | M | ours | `src/hell/hell_monsters.gd:1599` | Boss shockwaves push the hero only when they damage him, and never push monsters or gas |
| F41 | bodies | feel | 3 | M | ours | `src/combat/talent_combat.gd:2548` | Thrown bodies end badly: Urknall flights stop dead and snap upright, Rage slam kills rebound the wrong way, dash and charge wall hits are silent |
| F42 | bodies | inconsistent | 3 | M | ours | `src/hell/hell_game.gd:2540` | Hero death freezes shots, rigs and debris in mid-air while particles keep moving |
| F43 | bodies | bug | 3 | S | ours | `src/hell/boss_kit.gd:89` | Frostgruft boss pushes teleport the hero, the vortex pull sticks at walls, and Unbezwingbar's knockback immunity is never applied |
| F44 | bodies | missing-physics | 3 | M | ours | `src/hell/hell_game.gd:1984` | Knockback ignores body size, and thrown bodies pass through crowds without transferring momentum |
| F45 | bodies | inconsistent | 3 | M | ours | `src/physics_kit/motion_kit.gd:100` | On ice a knockback stops as fast as on stone |
| F46 | bodies | tunneling | 3 | M | ours | `src/physics_kit/motion_kit.gd:155` | Monster wall collision: velocity into a wall is kept, bodies get stuck inside solids, and large steps can pass through thin props |
| F47 | world | missing-physics | 5 | M | ours | `src/hell/hell_talents.gd:543` | Talent spells never touch walls, props or crates |
| F48 | world | inconsistent | 5 | M | ours | `src/hell/hell_game.gd:3352` | Krypta's green Moder runs the Hölle's lava physics |
| F49 | world | inconsistent | 4 | S | ours | `src/hell/hell_game.gd:3047` | Crates, urns and barrels shrug off every blast |
| F50 | world | tunneling | 4 | S | ours | `src/vfx/particles.gd:177` | Pixel particles fly through closed gates, pillars and crates |
| F51 | world | painted-not-simulated | 4 | M | ours | `src/hell/hell_game.gd:3174` | World embers and _burst are straight-line squares spawned per frame |
| F52 | world | tunneling | 4 | S | ours | `src/hell/gold_loot.gd:177` | Gold coins fly through walls and lie on lava |
| F53 | world | painted-not-simulated | 3 | M | ours | `src/hell/hell_game.gd:3719` | Traps and gates switch by sprite pop, not motion |
| F54 | world | missing-physics | 3 | M | ours | `src/hell/story_wreck.gd:772` | Settled shards and chips never move again |
| F55 | world | inconsistent | 3 | S | ours | `src/hell/hell_game.gd:2842` | No wading in the Frostgruft, and none in lava or Moder tiles anywhere |
| F56 | world | missing-physics | 3 | M | ours | `src/hell/hell_game.gd:3673` | Torches and braziers are sealed animation loops |
| F57 | world | missing-physics | 3 | M | brother | `src/hero/frost_snow.gd:376` | Snow melts only under fire bowls; fire and blasts leave it untouched |
| F58 | world | missing-physics | 3 | M | brother | `src/vfx/snowstorm.gd:137` | Wind blows only in the screen overlay |

Vorschläge, Prüfbegründungen und Spielerbild je Befund: in der JSON unter `findings[i]` (`now`, `should`, `proposal`, `check`).

## Fortschritt

- 2026-11-02: Bestandsaufnahme gesichert; Wochenkontingent bei 91 %. Umsetzung beginnt mit Etappe 1 (schnelle Korrekturen zuerst).
- 2026-11-02 (Etappe 1, schnelle Korrekturen, uncommittet): F23 Talent-Schüsse prüfen jetzt den Endpunkt (6-px-Abtastung + Halbierung, hell_talents.gd _shot_contact) und nutzen die Wand ab (wreck.hit_line); F35 Rückstoß pow(decay, dt*60) + push_in (motion_kit.gd, hell_monsters/hell_game m.k_in, story_hero check_slam); F25 Talent-Treffer rufen feel.on_hit (Swing-an-Wand-Hook noch offen); F26 verbrannte Giftwolken bleiben weg (gas_field _spent); F22 Gas-Teilen/Schneiden pro Sekunde (dt); F29 Erdspalter ohne Blutfontäne (paint_matter-Gates der Ulti-Maler noch offen); F27 Schild-Kuppeln in ihrem Element; F13 Reaktionen werfen ihre Materie (story_elements _react_matter); F52 Gold prallt an Wänden ab (Lava-Gutschrift noch offen); F38 Frostgruft-Ragdolls fliegen vom Schlag weg, stoppen an Wänden; F39 Berührung schubst in der Frostgruft (knock.contact 300); F9 exakte Kometenbögen, über Wänden ohne Wandstoß; F4 Sog-Kern schluckt auch im Vorbeiflug; F6 Frost am Limit schmilzt (Eviction-Schutz noch offen). Tests grün: hell_talents 14, gas_field 28, element_reactions 32, gold_loot 38, motion_kit 37, actor_motion 14, particles_physics 26, frost_combat 35, frost_runtime 39, gefuege_spit 17.
- 2026-11-02 (Etappe 1 weiter, uncommittet): R2 eine Partikelwelt (StorySkillFx.share: Held-Skills und Angriffe werfen in die Welt-Partikel, max_particles 900, Glut/Frost/Flecken/Streu sinken in Lava; offen: Spuren pro Distanz statt pro Zeichnung F10); R4/D1 Rest-Pfützen der Zauber auf eigener Bild-Ebene (talent_fx _residue_layer); D4 teilweise: Frost friert nur Wasser (pool_field/pool_paint "freezes"; offen: Schmelzen nach 8 s, Aufteilung Bild/Regel F17); R5/D6 Heldenexplosionen zerbrechen Kisten/Urnen/Siegel, Gegnerexplosionen erschüttern nur (story_wreck.blast), Talent-Explosionen/Novas/Einschläge nagen an Wänden (hell_talents _wreck_blasts); R1 Bild: production/qa/evidence/physik-etappe1/ (Feuerball platzt an der Wand). Bekannt und nicht neu: story_glow_test "ember bloom matches particles.gd draw_glow" (offene Nutzerentscheidung ember bloom drift). Sicherung: scratchpad physik-etappe1.patch.
- 2026-11-02 (Etappe 2/4 + Entscheidungen, uncommittet): D3/R10 Krypta-Moder kalter Schlamm (theme.liquid.material "moder", hell_game _floor_mat; Blasen/Tropfen grün, keine Hitze, keine Explosion/Kochen darauf, Trümmer sinken ohne Glut); R8/F14 brennende Giftwolke: Zündung an der wirklich berührten Wolke (gas_field touching), Feuerfront läuft durch (ignite, reactions.ignite_speed 260), jedes Wölkchen flammt auf + Rauch (story_elements _burn_puffs), verbranntes Gas bleibt weg; D2 teilweise: Giftgas über Lava oder brennenden Pfützen zündet von selbst (_gas_meets_heat, alle 0,2 s; offen: Wasser löscht Feuerpfützen sichtbar, Pfützen-Pfützen-Kontakt); D4: Glatteis schmilzt nach ice_time 8 s (auf Lava 3x schneller) mit Dampf/Tropfen; D9: Stoß auf Glatteis -> 60 % Gleiten (physics_motion.json knock.ice_glide, MotionKit.knock_hero, StoryMotionHost.hero_grip; Monster-Gleiten offen); D8: nach dem Tod laufen Gas, Frost-Wellen/Stöße, Rigs und Trümmer weiter, ohne Schaden (Gegner-Schüsse/Leichen-Alterung offen); D10: Gold in Lava/Moder sofort gutgeschrieben + Zischen; D12 (für saidPC zur Durchsicht): frost_snow.melt (Feuer schmilzt Schnee zum Tau-Fleck + Dampf, Explosion bläst Flocken hoch; Aufrufe in story_elements._fire_at und story_wreck.blast), Rutsch-Splitter je Strecke als Partikel, Schneesturm-Wind als Weltkraft (particles.wind je Modus-Anteil, gas_field.wind; gesetzt in hell_game aus snowstorm.wind()/Zoom; snowstorm.gd selbst unverändert). Tests grün: element_reactions 32, gas_field 28, gold_loot 38, element_exposure 49, motion_kit 37, frost_combat 35, frost_runtime 39, run_end 35, krypta_world 15, frost_wall_snow 267, particles 26.
- 2026-11-02 (weiter, uncommittet): D5/R23 Talent-Stöße addieren sich, kommen von der Explosion (talent_combat _hit: away), geteilt durch Masse (Radius/mass_ref_r 28)^2 in [0.4, 4], Summe höchstens 1000 px/s (physics_motion.json push.talent/boss_talent/max/mass_ref_r/mass; Boss-Schockwellen-Stoß F40 offen); R15/F1/F2: Tropfen klatschen auf (modes.drop floor splat), Flamme/Rauch/Funke/Glut gleiten an Wänden (wall slide), Luftwiderstand air je Modus (Rauch 2, Glut 1.5, Flocke 3, Flamme 1); R24/F36 Leichen in Krypta/Hölle rutschen mit dem Schlag weiter und stoppen an Wänden (hell_monsters corpses v); F41 geschleuderte Körper rollen in 0,25 s auf die Füße (talent_combat rolling, gefuege.roll_s); D7/R21 ein Feuerschuss (Talent oder Held) zündet die getroffene unbeleuchtete Feuerschale (hell_game _light_brazier/fire_hits_brazier). Bild D12: production/qa/evidence/physik-etappe2/. Bekannt und nicht neu: tests/talent_combat_test 41 Fehler auch mit dem committeten talent_combat.gd.
- 2026-11-02 (weiter, uncommittet): R16/F5 Explosionen (kick, blow) und Sog-Brunnen wirken nur, wo sie hinsehen (particles.sees: DDA über das 32-px-Bodenraster, je Aufruf zwischengespeichert; Tore/Requisiten als Hindernis noch offen); R11/F16 jedes Gas bewegt sich wie sein Material (vfx_gas.json materials.<mat>.physics: hold_k, drift_k, damping_k, wind_k, Dampf life 2,5 s); R17/F29/F31 Ulti-Splitter/-Chips/-Bluttropfen und Treffer-Tropfen/-Funken werden mit Partikeln nicht mehr zusätzlich gemalt (F30 Flugspuren der Talent-Schüsse noch offen). Tests grün: particles 26, gefuege 17, gas_field 28, element_reactions 32, talent_companion 42.
- 2026-11-02 (weiter, uncommittet): F40 Boss-Schockwellen schubsen auch überrollte Gegner (je einmal, monsters.feel.wave_push 280) und stoßen das Gas an (hell_monsters _shove_front); F10 Geschoss-Spuren pro Sekunde statt pro Zeichnung (skill_fx/attack_fx _due). Tests grün: hell_monsters 138, story_skill_fx 38, story_player_fx 132.
- 2026-11-02 (weiter, uncommittet): F21 überlappende Pfützen in Regel-Priorität gezeichnet (pool_paint _draw_order, ElementRules priority); F55 Waten in der Frostgruft (Held + Figuren durch die Talent-Pfützen, stabile Schlüssel m.wk); R3 Talent-Nahkampf klirrt an Wänden/zerschlägt Requisiten (talent_combat "melee" -> hell_talents.talent_swing_wall -> feel.swing_wall + wreck.swing); R19/F6 Eviction schützt Gefüge-Materie, Kometen-Blobs und Trümmer in der Luft (Funken/Rauch zuerst). Tests grün; talent_combat_test weiter 41 alte Fehler.
- 2026-11-02 (weiter, uncommittet): F44 Heldenschläge schubsen nach Masse und addieren sich (hell_game _damage_mob); R12/F19 große Pfützen breiten sich ab dem Erscheinen aus (pool_field born = max(start, commit)); D9-Rest: gestoßene Gegner gleiten auf Glatteis (MotionKit.step_body: push * grip^dt, push.ice_floor 0.12). Tests grün: motion_kit 37, actor_motion 14, frost_runtime 39, hell_monsters 138, pool_field 54, element_exposure 49, story_hero 13.
- 2026-11-02 (weiter, uncommittet): R9/F12 Pfützenbild: Flüssigkeit auf Feuer verzischt, das Feuer bleibt sichtbar (vfx_pools.json liquid+fire a_to gone), Gift an Feuer/Lava lodert auf statt zu zischen (pool_paint _react_pair flare); F30 fliegende Talent-Geschosse werfen echte Glut/Reif/Funken pro Sekunde ab (talent_fx _shed_flight, Schüsse mit id in hell_talents), gemalte Glut nur ohne Partikel. Bild R8: production/qa/evidence/physik-etappe2/krypta-gas-uebersicht.png. Tests grün: pool_field 54, matter_kit 58, element_reactions 32, hell_talents 14, talent_companion 42.
- 2026-11-02 (weiter, uncommittet): R21/F53 Schlote: Hölle wirft echte Flammen, Krypta-Moder-Schlot grüne Dünste + Rauch, pro Sekunde statt pro Bild (hell_game _vent_matter; Stacheln/Tore/Eisfallen-Bewegung noch offen); F18 Feuer schmilzt Monster-Frostpfützen zu Schmelzwasser mit Dampf (story_elements _fire_at "ice", reactions.melt_time 6). Tests grün: krypta_world 15, element_reactions 32.
- 2026-11-02 (weiter, uncommittet): D8-Rest: Gegnerschüsse fliegen nach dem Tod weiter (monsters.update_shots, _hurt schont den Gefallenen); D2/R13/F15: berührende Pfützen reagieren (Wasser löscht Feuerpfütze mit Dampf, Gift an Feuer/Lava explodiert; story_elements _pools_meet, alle 0,2 s). Tests grün: element_reactions 32, hell_monsters 138, run_end 35.

## Noch offen (Stand 2026-11-02, nach dem dritten Durchgang)

Committet und gepusht: der erste Durchgang (f084c69f) und der zweite und dritte Durchgang (der Commit danach, 2026-11-02; Zeilen unten). Ohne Entscheidung des Nutzers ist nichts mehr umsetzbar; offen sind nur noch:

- R26 Rest (Entscheidung nötig): die Gift-, Feuer- und Leere-Pfützen der Frostgruft-Angriffe als echte Pfützen im Pool-Layer. Dann wirken sie über die Element-Physik auch auf Monster, und der Held bekommt ihren Schaden über die Pfützen-Regel statt über die Angriffs-Zone (Balance-Änderung). Heute: nur Warnringe, Wirkung nur auf den Helden.
- R14 Rest (Entscheidung nötig): Seuchenfeld als echtes Spiel-Giftgas mit Schonung des Besitzers (Balance-Änderung). Heute: Schadenszone plus Giftdünste als Bild.
- R18 Rest (bewusst so gelassen): hell_game.embers (nur ohne Partikel), Wrack-Haufen und Goldmünzen haben eigene Physik mit Wänden.
- Bekannte alte Testfehler, unverändert: talent_combat_test 41 (gleich mit 535c814b), story_glow_test "ember bloom" (offene Entscheidung ember bloom drift).

Erledigt seit der ersten Liste: R1, R9, R12, R16, R17, R19, R21, R22/D11, R23, R24, R25, R30, F17, F21, D1 Schritt 2 geprüft; Einzelheiten in den Fortschrittszeilen.

### Fortschritt zweiter und dritter Durchgang
- 2026-11-02 (weiter, uncommittet): R1 Einschläge an Wänden spiegeln an der Wandnormalen (talent_fx _off_wall); R17 Schildbruch-Splitter/Begleiter-Blut nur ohne Partikel; R24 rutschende Leichen neigen sich (pose lean); R14 Seuchenfeld-Dünste und Seelensturm-Wirbel als Partikel; R21 Stacheln fahren hoch/runter mit Staub; R23 geschleuderte Körper rempeln an (gefuege.bump_m 0.8, roll_s 0.25 in madness_rules.json); D11/R22 Tiefenbänder. Tests grün: particles 26, story_player_fx 132, hell_monsters 138, gefuege 17, hell_talents 14, krypta_world 15, talent_companion 42.
- 2026-11-02 (zweiter Durchgang nach f084c69f, uncommittet): R18 Teil (StoryHero.matter und fallende RigFx-Splitter in die Welt-Partikel), R16 Tore/Requisiten/Kisten stoppen Partikel. Tests grün: rig_debris 26, hell_rig_renderer 73, story_hero 13, frost_runtime 39, particles 26, krypta_world 15, hell_monsters 138. Wochenkontingent 94 %.
- 2026-11-02 (zweiter Durchgang, uncommittet): F7 Gefüge-Brocken werden im 12-fps-Takt in ein Bild gebacken und dazwischen nur verschoben (particles _draw_fused bake_tex/bake_key; Bild production/qa/evidence/physik-etappe3/gefuege-klumpen-vorgezeichnet.png, sieht aus wie vorher). Tests grün: particles 26, gefuege 17.
- 2026-11-02 (dritter Durchgang, uncommittet): R21 Fallgitter fallen in 0,18 s mit Staub/Splittern und werden in 0,35 s hochgezogen (hell_game d.drop, _draw_gate); R24 Leichen zerfallen beim Auflösen zu Staub und Asche-Funken; R17 Meteor-Fall wirft echte Glut. Tests grün: krypta_world 15, hell_monsters 138, talent_companion 42.
- 2026-11-02 (dritter Durchgang): R9 Kruste nur nach Regel; D1 Schritt 2 geprüft (nichts zu tun). Tests grün: pool_field 54, matter_kit 58.
- 2026-11-02 (dritter Durchgang): R12 früher endende Pfützen gehen vom Rand. Tests grün: pool_field 54, element_exposure 49, element_reactions 32.
- 2026-11-02 (dritter Durchgang, zur Durchsicht durch saidPC): R30 Schneeflocken mit Tiefe: snowstorm.gd follow(cam_pos, zoom) verschiebt die Flocken mit der Kamera, nahe Flocken (d) stärker als ferne (0,35 + 0,65·d), Sprünge über 400 px (Raumwechsel) zählen nicht; hell_game ruft es jedes Bild. Test grün: frost_runtime 39.
- 2026-11-02 (dritter Durchgang): R26 Teil: die Eisflächen der Frostgruft-Angriffe (frost_patch, ice_slide) sind auch für Monster Glatteis (frost_moves ice_under, Griff aus element_rules.json mediums.ice), außer für Frost-Wesen; Schneemänner zählen jetzt als Frost-Wesen (actor_tags snow/schnee). Der Held behält dort seine Glätte-Bedingung (keine Balance-Änderung für ihn). Offen: Gift-/Feuer-/Leere-Pfützen der Angriffe als echte Pfützen im Pool-Layer. Tests grün: frost_runtime 39, frost_combat 35, element_exposure 49, hell_monster_rules 38.
- 2026-11-02 (dritter Durchgang): R17 Rest: Phönixschritt wirft echte Glut vom Vogel (fällt aus seiner Höhe, 50/s), Sturzflug wirft Federn im Kielwasser (Partikelart flake: Luftwiderstand, Wind) und einen Federpuff beim Zuschlagen; gemalt nur ohne Partikel (talent_fx _shed_count). Bild production/qa/evidence/physik-etappe3/phoenix-glut-partikel.png. Tests grün: story_skill_fx 38, talent_companion 42, hell_talents 14.
- 2026-11-02 (dritter Durchgang): R23 Rest: Körpermasse für Stöße = (Radius / Median-Radius der Monster der Welt)², ohne Bosse, neu gemessen, wenn sich die Zahl der Monster ändert; mass_ref_r nur noch, solange keiner da ist (hell_game body_mass, auch für Talent-Treffer in hell_talents). Tests grün: hell_talents 14, motion_kit 37, actor_motion 14, frost_combat 35, hell_monster_rules 38, hell_monsters 138, gefuege 17.
- 2026-11-02 (dritter Durchgang, zur Durchsicht durch saidPC): R21 Fackeln und Wandbecken werfen echte Glut und einen Rauchfaden von jeder Flammenspitze (fire_anim.gd tips() aus flame_regions, beim build berechnet; hell_game _wall_fire_matter; Raten/Farben in vfx_particles.json wall_fire). Bild production/qa/evidence/physik-etappe3/fackel-glut-rauch.png. Tests grün: krypta_world 15, particles 26, fountain_and_fire.
- 2026-11-02 (dritter Durchgang): R25 Rest: Feuer taut Glatteis von seiner Seite her, die nächsten Zellen sofort, die fernsten nach physics.thaw_time 0,35 s (pool_field thaw_near plant Zeiten, advance lässt sie tauen und meldet "thawed"; pool_paint folgt dem Feld statt selbst alles auf einmal zu löschen). Tests grün: pool_field 56 (neu: taut von der Feuerseite), element_reactions 32, element_exposure 49, matter_kit 58, story_player_fx 132.
- 2026-11-02 (dritter Durchgang): F17 Teil: Eis-Explosionen der Gegner (story_feel on_blast, Frostgruft-Hagel/-Schläge in frost_moves) frieren Wasser jetzt über die Spielregel (story_elements frost_at, auch Dampf kondensiert zu Regen), nicht mehr nur über den Zeichen-Code. Offen: particles.freeze_liquids selbst nur noch als Bild (freeze_look), damit Talent-Rückstände nicht über die Zeichnung Glatteis werden. Tests grün: element_reactions 32, frost_combat 35, frost_runtime 39, hell_monsters 138, story_player_fx 132, krypta_world 15.
- 2026-11-02 (dritter Durchgang): R19 Teil: Rauch, Dampf, Schutt und das Aufwirbeln durch Explosionen (kick) fragen jetzt room() wie die anderen Effekt-Quellen, also keine harten Sprünge an der Obergrenze; auch die Fackel-Glut. Tests grün: particles 26, story_player_fx 132, matter_kit 58, rig_debris 26.
- 2026-11-02 (dritter Durchgang): F21 Rest: Mischfarben (nur Bild): wo Wasser auf Blut trifft, zeigt sich Blutwasser (Wasser-Rampe zu 62 % zu Blut), wo es auf Gift trifft, Giftwasser (Gift mit Schleier und Dünsten, zu 45 % zu Wasser); Reaktionstabelle kennt jetzt Material-Paare vor Stil-Paaren (vfx_pools.json reactions water+blood/water+poison, materials bloodwater/toxicwater; pool_paint _react). Bild production/qa/evidence/physik-etappe3/mischfarben-blutwasser-giftwasser.png. Tests grün: pool_field 56, element_reactions 32, matter_kit 58.
- 2026-11-02 (dritter Durchgang): R21 Rest: Frostgruft-Eisfallen brechen mit Eissplittern aus dem Schnee (particles.shatter statt Staub) und sinken über 0,08 s in ihren Riss zurück, dabei bröckeln ein paar Splitter ab (hell_game spikes-Update, _draw_ice_trap/_draw_ice_burst sink). Tests grün: frost_runtime 39, krypta_world 15.
- 2026-11-02 (dritter Durchgang): F17 erledigt: die Pfützen-Schicht der Welt ist bei den Partikeln als Regel-Schicht markiert (set_liquids dritter Eintrag true, story_feel); particles.freeze_liquids/thaw_liquids lassen sie aus, dort friert und taut nur noch die Regel (story_elements frost_at/thaw). Bild-Schichten (geworfene Tränke, Talent-Rückstände) frieren weiter über die Zeichnung. Tests grün: particles 26, element_reactions 32, story_player_fx 132, krypta_world 15, hell_monsters 138, pool_field 56.
- 2026-11-02 (dritter Durchgang, zur Durchsicht durch saidPC): R26/R30 Monster-Rutschspuren: rutscht ein Frostgruft-Monster (kein fester Griff, hell_game m.slid) schneller als skid_speed, kratzt es statt Pfotenabdrücken Rutschspuren alle 8 px, breiter je größer es ist (frost_snow.gd update/draw_floor). Tests grün: frost_runtime 39, frost_wall_snow 267.
- 2026-11-02 (dritter Durchgang): R19 Rest: verdrängter Verdunstungs-Frost an der Obergrenze geht sofort statt ewig zu liegen (_vapor_go); die Verdunstungsliste wird nur noch durchsucht, wenn ihr frühester Termin da ist (_vapor_next). Eviction-Schutz und Frost-Obergrenze waren schon im ersten Durchgang erledigt. Tests grün: particles 26, story_player_fx 132, frost_runtime 39, matter_kit 58, story_skill_fx 38.
