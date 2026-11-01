# Klang-Ereignisse – was der Code der Story-Welten abfragt

> Stand 2026-11-01 · gameplay-programmer · für den Daten-Agenten (`assets/data/audio_sfx.json`, `audio_library.json`, `audio_music.json`).
> Grundlage: `docs/KLANG-KONZEPT.de.md`. Regeln: `assets/data/audio_rules.json`. Code: `src/vfx/sfx.gd` (Resolver, Stimmen-Pool, Raumklang), `src/hero/story_sound.gd` (Routing), `src/audio/audio_mix.gd` (Busse), `src/audio/music.gd` (Musik je Welt).
> Fehlt ein Schlüssel, bleibt es still (kein Fehler, kein Piepser); `sfx.misses` zählt mit.

## 1 So findet der Code eine Datei (Resolver)

Für ein angefragtes Ereignis `E` probiert `sfx.gd` der Reihe nach:

1. `prefer[E]` (z. B. `hurt_voice` → zuerst `vo_hurt`; `shoot` → zuerst `shoot_necro`), dann `E`, dann `fallback[E]` (`shoot` → `shoot_magic`), dann die Rückfälle des Aufrufers (z. B. `react_explode` → `blast`), dann `prefix_fallback` (`windup_*` → `windup_generic`).
2. Jeder dieser Namen zuerst mit **Satz**: `E_<satz>` (Material, Element, Boden, Art), mit den Umbenennungen aus `set_alias`: `frost` → `ice`, `poison` → `slime`, `holy` → `spirit` (beide Namen gelten). Dann ohne Satz.
3. Bei Material-Ereignissen (`hit`, `kill`, `break`, `idle`, `move`, `vo_enemy_hurt`, `vo_enemy_death`, `settle_tick`, `splat`) die Material-Kette: `ice` → `void`, `fire` → `flesh`, `stone` → `bone`, `slime` → `flesh`, `spirit` → `void`, `gold` → `bone`.
4. Jeder Name als `<name>@<profil>`, dann `<name>@<welt>`, dann `<name>`.

Der erste Schlüssel mit Dateien spielt.

- **Profile der Helden:** `female` (elf_f, Bogenschützin), `male_knight` (knight_m), `male_wizard` (wizzard_m, custom_pyromancer), `male_necro` (necromancer).
- **Begleiter:** `wolf`, `bear`, `falcon`, `water_elemental`, `pyro`, `bone_warrior`.
- **Welten:** `krypta`, `frost`, `hell`.
- **Strenge Stimme:** `female` (und `monster_female` der Grabmutter) fällt bei Stimm-Ereignissen (`vo_*`, `hurt_voice`) **nie** auf eine andere Stimme zurück. Fehlt `vo_hurt@female`, schweigt die Bogenschützin, statt mit einer Männerstimme zu stöhnen.
- **Sätze in einer Datei:** Statt eigener Schlüssel kann ein Ereignis `"sets": {...}` mit `"set_by"` tragen. Mit `set_by` `voice` oder `world` wird daraus `E@<satz>`, sonst `E_<satz>`.

Gelesene Felder je Ereignis (alle optional):

| Feld | Bedeutung |
|---|---|
| `category` | Bus und Pegel |
| `priority` | 1–4 |
| `positional` | `false` = immer mittig |
| `max_distance` | Reichweite in Weltpixeln |
| `max_voices` | höchstens so viele gleichzeitig |
| `min_interval` | kürzester Abstand in s |
| `chance` | Wahrscheinlichkeit 0–1 |
| `vol_spread_db` | Lautstärke-Streuung |
| `volume_db`, `spread`, `pitch` | Pegel-Trim, Tonhöhen-Streuung, feste Tonhöhe |
| `with` | Schicht, die mitspielt |
| `loop` | `true`: spielt als eine Schleife je Quelle und blendet aus, wenn die Quelle endet |

Fehlt ein Feld, gelten die Vorgaben aus `audio_rules.json` `event_defaults` (nach Präfix).

**Kategorien:** `focus`, `stinger`, `voice`, `hero`, `pet`, `impact`, `enemy`, `boss`, `world`, `ally`, `step`, `idle`, `debris`, `ambience` (`amb_point` gleichwertig), `ui`.

## 2 Raum, Busse, Prioritäten (kurz)

- **Raumklang:** Mit Position spielt ein Klang über einen `AudioStreamPlayer2D`; der `AudioListener2D` sitzt am Helden (Brusthöhe), Links/Rechts folgt der Bildschirm-x.
  - Reichweite 14 Kacheln (96 px), Abfall 1,6, Panorama 0,5. Boss ×1,5, Trümmer ×0,64, Leerlauf ×0,57, Schritte ×0,43, Ansagen ×1,5.
  - Weiter als 8 Kacheln: Bus `Far` (Tiefpass 3,5 kHz, mehr Hall).
  - Mittig bleiben: Priorität 1, `focus`, `stinger`, `ui` und die eigenen Klänge des Helden.
  - Die Treffer, Tode und Blocks von `feedback.gd` tragen keine Position; sie spielen dort, wo im selben Frame die Partikel des Treffers aufgingen.
- **Bus-Baum:** Master (Limiter −1 dB)
  - Music, Ambience (beide mit Gas-Tiefpass)
  - SFX
    - Focus
    - Voices
    - Room (Welt-Hall und Gas-Tiefpass) mit Hero, Boss, Enemy, Impact, World, Step, Idle, Debris und Far
  - UI
- **Ducking:** Focus duckt Music, Ambience, Debris (≈ −6 dB) und Room (≈ −3 dB). Boss duckt Enemy, Idle, Debris und Music (≈ −3 dB). Voices duckt Step und Debris (≈ −3 dB).
- **Hall je Welt:** Krypta ≈ 1,4 s steinern, Frostgruft ≈ 2,2 s hell, Hölle ≈ 2,8 s dunkel (`audio_mix.json` `spaces`).
- **Stimmen-Pool:** 40 Stimmen, davon 8 nur für Priorität 1. Obergrenzen je Bus: Debris 8, Step 4, Idle 3, Enemy 10, Impact 8, World 6, Voices 4, Boss 4, Hero 6. Priorität 4 stiehlt nie, Priorität 1 wird nie gestohlen.
- **Lautheit:** Ziel −16 LUFS integriert, True Peak ≤ −1 dBTP. Die Dateien pegelt `audio_library.json` `gain_db`.

## 3 Die Schlüssel, die der Code jetzt abfragt

In der Liste steht `‹el›` für einen Element-Satz:

- `fire`
- `frost` bzw. `ice`
- `void`
- `arcane`
- `shock`
- `poison` bzw. `slime`
- `holy` bzw. `spirit`
- `bone`
- `physical`
- `water`

`‹mat›` steht für die Materialien `bone`, `flesh`, `void`, `gold`, `ice`, `fire`, `stone`, `slime`, `spirit`. Jeder Schlüssel darf zusätzlich `@<welt>` tragen, die Helden-Schlüssel `@<profil>`.

### Held (mittig, `@<profil>`)

| Schlüssel | Wann |
|---|---|
| `hurt` + Schicht `hurt_voice` → `vo_hurt` | Treffer (feedback) |
| `vo_hurt_heavy` | Treffer ab 2 halben Herzen |
| `vo_death` + `bodyfall` | Tod |
| `hurt_element_‹burn\|poison\|frost\|void\|shock›` | Schaden über Zeit; fehlt der Schlüssel, spielt das alte `hurt` |
| `shoot_arrow`, `shoot_magic`, `shoot_necro` | Schuss; der Nekromant fragt `shoot`, das zu `shoot_necro` und dann zu `shoot_magic` wird, ohne Piepser |
| `swing` | Schwerthieb |
| `step_‹stone\|snow\|ash\|wet›` + Schicht `foley_move` | Schritt |
| `step_ally` | Schritt eines Mitspielers |
| `lowhp_heartbeat` (Schleife) | unter 30 % Leben, unter 15 % schneller |
| `gas_breath_‹gas›` (Schleife), `vo_cough` | im Gas, Husten nicht im Dampf |
| `medium_enter_‹stil›`, `medium_wade_‹stil›` (Schleife), `medium_exit_‹stil›` | Wasser, Lava, Gift, Blut |
| `dash`, `dash_land`, `dodge` | Bewegung |
| `pit_fall` + `vo_fall` | Sturz in die Grube |
| `respawn` | Rückkehr |
| `vo_effort` (30 % je Zauber, 40 % je Ausweichen), `vo_cast_ult`, `vo_taunt` | Stimme beim Zaubern |

### Talente und Ultimates (`‹el›`; Ultimates als `focus`, mittig)

- **Zauber:** `tal_cast`.
- **Je Talentart beim Wirken:** `tal_projectile`, `tal_zone_start`, `tal_trap_set`, `tal_shield_on`, `tal_glacier`, `tal_line`, `tal_counter`, `tal_bulwark`, `tal_taunt_area`, `tal_harvest`, `tal_channel_start`, `tal_devour`, `tal_melee`, `tal_awaken`.
- **Wirkung:** `tal_nova`, `tal_meteor_fall`, `tal_meteor_hit`, `tal_chain` (je Sprung 60 ms später und +6 % höher), `tal_net`, `tal_buff_on`, `tal_mark`, `tal_summon`, `tal_echo`, `tal_impact`, `tal_trap_snap`, `tal_zone_end`, `tal_zone_loop` (Schleife), `tal_shield_hit`, `tal_pool`, `blink_out`, `blink_in`, `block_hit`, `block_break`.
- **Leerenmagier:** `catch_shot`, `lance_drops`, `wall_slam`, `splat`, `void_gulp`, `gefuege_store`, `gefuege_spend`.
- **Ressourcen:** `mana_orb`, `no_mana`, `heal`.
- **Zustände am Gegner:** `status_burn`, `status_poison`, `status_bleed`, `status_slow`, `status_freeze_on`.
- **Ultimates:** `ult_<talent-id>` (Rückfall `ult_cast`), `ult_singularity_release`.

### Begleiter (`@wolf|bear|falcon|water_elemental|pyro|bone_warrior`)

`pet_spawn`, `pet_idle` (alle 6–12 s), `pet_attack`, `pet_<fähigkeits-id>` (Rückfall `pet_ability_1`), `pet_ability_2` (Spott/Heulen), `pet_hurt`, `pet_death`.

### Gegner (an ihrer Position)

- **Ansagen:**
  - Kette: `windup_<roh>`, dann `windup_<krypta-art>`, dann `windup_generic`.
  - `<roh>` ist die echte Angriffsart, z. B. `breath`, `lob`, `chain`, `dash`, `frost_nova`, `icicles`.
- **Auslösen:**
  - Zuerst die Schlüssel der echten Angriffsart, im Element (‹el›): `attack_breath`, `attack_lob`, `attack_chain`, `attack_scream`, `attack_burrow`, `attack_flight`, `attack_teleport`, `trail`, `frost_nova`, `frost_cone`, `whirl`, `ice_strikes`, `ice_armor`, `icicles_fall`, `chill_zone`, `meteors_incoming`, `hands_rise`.
  - Danach die Krypta-Art `attack_<slash|bite|arrow|soul|salve|slam|roar|summon|beam>`.
- **Treffer und Tod:**
  - Über feedback: `hit_‹mat›`, `kill_‹mat›`, `break_‹mat›`, `idle_‹mat›`.
  - Stimmen: `vo_enemy_hurt_‹mat›` (30 %), `vo_enemy_death_‹mat›`; die Grabmutter mit `@monster_female`.
  - Hülle: `coat_‹frost|fire|lava›_hit`, `coat_‹frost|fire|lava›_kill`.
- **Bosse:**
  - `boss_hit_layer`, `boss_vo_<id>_hurt` → `boss_hurt_<id>`, `boss_vo_<id>_death` → `boss_death_<id>`, `boss_roar_<id>` → `boss_vo_<id>_roar`.
  - `boss_flyin`, `boss_rage` → `attack_roar`, `boss_form_swap` → `attack_roar`, `boss_lord_end`.
  - `boss_landing_<zonenart>` → `blast`.
- **Schüsse:** `eshot_passby`, `eshot_impact_‹el›`.

### Zonen, Gefahren, Element-Reaktionen (an ihrer Position)

- **Pfützen:** `puddle_spawn_‹el›`, `puddle_loop_‹el›` (Schleife, die 3 nächsten), `charge_loop` (Schleife).
- **Zonen:** `zone_wave`, `zone_fissure`, `zone_arc`, `zone_meteor` (Pfeifen beim Erscheinen), `zone_cone_‹el›`, `zone_erupt`, `zone_land`, `zone_hand`.
- **Gefahren:** `rift_‹el›`, `scream_front`, `lava_splash`, `phys_blast_embers`, `crack_floor` (`crack_floor_ice`), `mad_strike`.
- **Reaktionen:**
  - `react_explode` (Rückfall `blast`; in der Kette je Stufe 80 ms später und −4 % tiefer), `react_quake` (Rückfall `blast`).
  - `react_ignite`, `react_boil`, `react_thaw`, `react_freeze`, `react_crust`, `react_douse`, `react_charge`, `charge_zap`, `react_wave`, `react_holy`, `void_swallow`, `floor_meets_freeze`.

### Partikel und Trümmer (Bus Debris, ein Klang je Aufruf)

- **Ausbrüche:** `burst_debris`, `burst_drops`, `burst_dust`, `sparks`, `chips`, `splat`, `drip`, `wall_crack`, `embers`, `fire_burst`, `shatter`, `shard_break`, `snow_puff`, `comet`, `land_splash`, `rime_grow`, `implode`, `rubble`, `scorch_star`, `floor_crack`, `holy_motes`, `shadow`, `liquid_freeze`, `liquid_thaw`, `steam`, `smoke`, `blow`.
- **Landeticks:** `settle_tick_‹bone|stone|ice|liquid›` (20 %, Flüssigkeit 15 %, höchstens 14/s); mehr als 6 in 100 ms werden ein `settle_patter`.
- **Stummschalten:** Eine Art wird still, wenn `audio_rules.json` `particles.events` ihr `""` zuordnet.

### Welt, Gegenstände, Bedienung

| Gruppe | Schlüssel |
|---|---|
| Theme-Ereignisse (mittig) | `chest_open`, `gate_open`, `gate_locked`, `stinger_fight_start` (+ das alte `doors_lock`), `stairs`, `room_clear`, `key_pickup`, `relic_pickup`, `level_up`, `run_won`, `boss_intro`, `boss_phase`, `boss_defeated`, `plate`, `plate_wrong`, `puzzle_solved`, `secret_open`, `on_cooldown`, `crate_break`, `snowman_wake`; fehlt der neue Schlüssel, spielt die alte Zuordnung aus `frost_theme.json` `sounds` |
| an der Position | `enemy_spawn`, `drop_<art>` (gold, heart, key …), `gold_burst`, `breakable_hit`, `seal_break`, `mimic_spring` |
| Bedienung | `talent_open`, `toast`, `stairs_pick`, `save_ok`, `pause_open` |
| über feedback (unverändert) | `perk`, `room_clear`, `team_wipe`, `boss_intro`, `boss_kill`, `boss_defeated`, `doors_lock`, `block`, `regrow`, `chest_open`, `crate_break`, `void_burst`, `bomber_pop`, `blast` |

### Ambience und Musik

- **Punktquellen** (Kategorie `ambience`, zufällig um den Helden):
  - Krypta: `amb_drip`, `amb_bone_settle`
  - Frostgruft: `amb_drip`, `amb_ice_creak`
  - Hölle: `amb_far_hell`
- **Musik** (`audio_music.json` `worlds`, Bibliotheks-Ids):
  - `mus_<krypta|frost|hell>_<explore|combat|boss>`
  - Ambience-Bett `amb_bed_<krypta|frost|hell>`
  - Fehlt ein Track, spielen die bisherigen `states` und das bisherige `ambience`.
- **Stinger je Welt:** über `@<welt>` (z. B. `boss_intro@frost`, `boss_defeated@hell`, `gate_open@krypta`).
