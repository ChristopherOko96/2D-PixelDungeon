# Klang-Konzept – Delve Disaster (Story-Welten)

> Stand 2026-11-01 · Audio Director · gilt nur für die drei Story-Welten auf `src/hell/hell_game.gd`:
> **Krypta der Verdammten**, **Die Frostgruft**, **Der Hell-Dungeon**. Der alte Hauptdungeon (`src/game.gd`) ist veraltet und wird hier nicht beplant.
> Dieses Dokument ändert keinen Code. Umsetzung: gameplay-programmer / engine-programmer (Code), sound-designer (Dateien, Schnitt, Pegel), Audio Director (Abnahme des Mix).

**Ziel des Nutzers (sinngemäß):** Jede Figur klingt so, wie sie aussieht. Die Bogenschützin ist eine Frau und bekommt eine Frauenstimme. Jeder Gegner hat einen Todeslaut. Alles, was sich bewegt – Figuren, Objekte, Partikel, Trümmer –, hat einen Klang. Der Mix muss sich voll und richtig anfühlen, nicht leer und trocken.

Gelesen für dieses Dokument: `assets/data/audio_sfx.json`, `audio_mix.json`, `audio_music.json`, `audio_library.json`, `frost_theme.json` (sounds, classes; Hölle und Krypta erben `sounds` und `music` daraus über `hero_keys`), `talents.json` (pet, classes), `src/vfx/sfx.gd`, `src/audio/audio_mix.gd`, `src/audio/music.gd`, `src/hero/story_sound.gd`, `src/vfx/feedback.gd`, dazu die Funktionslisten von `hell_game.gd`, `hell_monsters.gd`, `story_elements.gd`, `particles.gd` und `talent_combat.gd`.

---

## 0 Befund heute

| # | Befund | Folge |
|---|---|---|
| 1 | 52 Ereignisse in `audio_sfx.json`, dazu 11 synthetische Piepser in `sfx.gd` (shoot, swing, enemy_shoot, windup, hit, boss_hit, kill, boss_kill, hurt, door, stairs). Alle drei Welten teilen **eine** Sound-Zuordnung (frost_theme.json `sounds`), **eine** Ambience (`dungeon_wind_drips`) und **dieselbe** Musik. | Die Welten klingen gleich. Die Frostgruft klingt nach tropfender Krypta. |
| 2 | Das ganze Talentsystem (`src/combat/talent_combat.gd`: rund 30 Talentarten, 12 Ultimates, Fallen, Zustände, Arkanes Gefüge, Begleiter) löst **keinen einzigen** Klang aus. | Die stärksten Momente des Spiels sind stumm. |
| 3 | Heldenstimme: ein Satz (`hurt_voice` = creatures_2 human_01–08) für alle vier Helden, auch für die Bogenschützin (`elf_f`). | Die Frau stöhnt mit der Männerstimme. |
| 4 | Ansagen (Windups): `feedback.gd` spielt nur `windup_<kind>`, wenn es das Ereignis gibt (beam, fuse, summon). Geriggte Figuren bekommen sonst bewusst keinen Ersatzton – und alle Story-Monster sind geriggt (`story_sound.rig`). | Fast jeder Story-Angriff beginnt ohne hörbare Ansage. |
| 5 | Nur drei Materialien (bone, flesh, void). Höllenhund = Zombie, Glutschädel = trockener Knochen, Golem = Knochen, Eiskristall = Leere, Eisschleim = Fleisch. Ein Kettenangriff (`chain`) klingt wie ein Bambuspfeil, ein Feueratem (`breath`) wie ein Kreaturengebrüll. | Was man sieht, passt nicht zu dem, was man hört. |
| 6 | Elemente: `feedback.gd` ruft `frost` (Einfrieren, Eisrüstung, Eis-Landung, Eisblock), `drink` und `potion_break` – diese Ereignisse gibt es nicht. Dampf, Tauen, Kruste, Blitz-Ladung, Heiliges Licht und Schockwelle sind stumm, Explosionen leihen sich das kleine `blast`. | Die Element-Physik (Ziel seit 2026-10-30) hat keine Klang-Physik. |
| 7 | Partikel und Trümmer (`particles.gd`, `gas.gd`, `pool_paint.gd`, `snowstorm.gd`) haben keinen Klang. | „Alles, was sich bewegt, klingt“ ist zu 0 % erfüllt. |
| 8 | Kein Raumklang: `AudioStreamPlayer` ohne Position. Ein Gegner am Bildrand ist so laut wie einer direkt am Helden, es gibt kein Links/Rechts. Kein Hall, kein Filter. | Genau das Gefühl „leer und trocken“. |
| 9 | Stimmen-Pool: 24 Spieler reihum, ohne Priorität. Ein langer Boss-Schrei kann von einem Schritt abgeschnitten werden. | Wichtiges geht unter, sobald es voll wird. |
| 10 | Falsche Leihgaben: Der Schneemann erwacht mit `hit_bone`, ein gelöstes Rätsel klingt nach `regrow`, Druckplatten nach UI-Klicks, Schlüssel und Relikte nach `perk`. Die Frostgruft-Schritte klingen nach Beton, obwohl `footstep_snow_000–004` in der Bibliothek liegt. | Viele kleine Brüche, die sich summieren. |
| 11 | Lizenz: Das Paket `pixel_combat` hat „license: unknown“ und liefert rund 80 Dateien (Schwert, Schüsse, Gegnerangriffe, Windups, UI, Stinger). | Blocker vor jeder Veröffentlichung. |
| 12 | Verdacht auf Doppel-Auslösung (im Spiel prüfen): `hell_game:_lose_hp` spielt `hurt` + `hurt_voice`, `feedback.gd` spielt zusätzlich `hurt` (mit der Schicht `hurt_voice`). Der Heldenschuss läuft über `hell_game:_attack` (Theme `shot_magic`) **und** über `feedback.gd`. Der Nekromant fällt in `feedback.gd` auf den Synth-Piepser `shoot`, weil nur `class_id == "mage"` das Ereignis `shoot_magic` bekommt. | Treffer und Schüsse sind womöglich doppelt so laut; der Nekromant piepst. |

---

## 1 Klangidentität

### 1.1 Sieben Regeln gegen „leer und trocken“

1. **Drei Schichten pro Klang:** Transient (0–30 ms, sagt *was* passiert), Körper (30–400 ms, sagt *woraus* es ist), Ausklang (0,3–2 s, sagt *wo* es ist). Den Ausklang liefert der Welt-Hall (§3.2), nicht jede Datei.
2. **Nie Stille im Raum:** Jede Welt hat ein Ambience-Bett (Raumton + zufällige Punktquellen), das nie unter −30 LUFS-S fällt.
3. **Nähe hat Höhen, Ferne hat Hall:** Nahe Klänge trocken und hell, ferne Klänge leiser, dumpfer und hallig (Far-Bus, §3.5).
4. **Was man sieht, hört man:** Material und Stimme kommen aus dem Aussehen (`rig_materials`, Stimmsätze). Kein Fleischklang auf Eis, keine Männerstimme bei einer Frau.
5. **Keine Maschinengewehre:** Keine zwei gleichen Dateien hintereinander, Tonhöhe und Lautstärke streuen, jede Partikelart ist gedrosselt (§3.9).
6. **Wichtiges bleibt hörbar:** Prioritäten, Ducking und Stimmen-Reserve (§3.4, §3.6). Der eigene Treffer, Boss-Ansagen und der Tod sind immer zu hören.
7. **Stille als Werkzeug:** Vor dem Urknall, dem Boss-Auftritt und dem Boss-Tod gibt es 0,3 s „Luft holen“, das macht den Knall groß.

### 1.2 Die drei Welten

| | **Krypta der Verdammten** | **Die Frostgruft** | **Der Hell-Dungeon** |
|---|---|---|---|
| In 3–6 Wörtern | trocken, steinern, modrig, hallend, knöchern | kristallin, windig, klirrend, weit, kalt | grollend, fauchend, glühend, metallisch, schwer |
| Raum (Hall) | mittleres Steingewölbe, Nachhall ≈ 1,4 s, Höhen gedämpft, Vorverzögerung 20 ms | große Eishalle, Nachhall ≈ 2,2 s, hell (kaum gedämpft), Vorverzögerung 40 ms | riesige Kaverne, Nachhall ≈ 2,8 s, dunkel (stark gedämpft), Vorverzögerung 55 ms |
| Boden (Schritte) | Stein, Staub, Knochensplitter | Schnee knirschend, Glatteis quietschend und kratzend | Asche und Schlacke knirschend, Stein, heiße Kruste |
| Ambience-Bett | tiefer Raumton (60–200 Hz), Tropfen alle 3–9 s, ferner Luftzug, selten fernes Knochenrieseln | Windbett mit Böen (an `snowstorm.gd` gekoppelt), Eis-Knarzen, klirrende Eiszapfen | Sub-Grollen (30–80 Hz), Feuerrauschen, blubbernde Lava-Punkte, ferne Ketten, selten ferne Schreie |
| Signatur-Materialien | Knochen, Holz, Tuch, Kerze | Eis, Glas, gefrorenes Metall, Schnee | Feuer, Lava, Ketten, Eisen |
| Musikfarbe | Orgel- und Cembalo-Reste, gedämpfte Trommeln, geflüsterter Chor (die vorhandenen Cembalo-Stinger passen hierher) | Celesta, Glocken, gestrichene Gläser, tiefe Streicher, sparsame Pauke | Industrie-Trommeln, verzerrte Bässe, Chor (die vorhandenen „Heavy“-Tracks passen hierher) |
| Vermeiden | grelles Metall, Synth-Laser | dumpfe Fleischklänge ohne Eisschicht | helles Glöckchen-Klingeln (außer heilig) |

### 1.3 Die Elemente

| Element | In 3–6 Wörtern | Transient | Körper | Ausklang | Schleife (Fläche, Wolke) | Bibliothek heute |
|---|---|---|---|---|---|---|
| **Feuer** | fauchend, knisternd, gierig, warm | Zündung, „Wumms“ (tief) | Flammenrauschen 200 Hz–2 kHz | Glutknistern 0,5–1,5 s | Flammenflattern + Knistern | – |
| **Lava** | zäh, blubbernd, schwer, glühend | dicker Plopp | zähes Gluckern (tief-mittel) + Zischen | Brutzeln, Abkühl-Knacken | träges Blubbern | burble_01–02 (passend) |
| **Eis** | kristallin, splitternd, hell, klirrend | Glas-Knacken | kristalliner Schimmer | rutschende Splitter, kalter heller Hall | leises Rauhreif-Knistern | impact_glass_* (gut) |
| **Wasser** | spritzend, nass, schwappend | Platscher | Schwappen | Tropfen | Plätschern | – |
| **Dampf** | zischend, weiß, blendend, nebelig | Zisch-Stoß (3–8 kHz) | weißes Rauschen | auslaufendes Zischen | leises Dampfrauschen | – |
| **Gift / Gas** | blubbernd, säuerlich, zischend, dumpf | nasser Plopp | saures Sprudeln + Gaszischen | tiefes Blubbern | Blasen + Zischen | slime_*, cough_* (Teil) |
| **Leere** | saugend, rückwärts, hohl, tief | rückwärts anschwellender Sog | Vakuum-Saugen nach innen | Sub-Abfall, hohles Nachklingen, kurze Stille | tiefes Summen, das „Luft frisst“ | hit_void, void_burst (gut) |
| **Blitz** | knallend, knisternd, scharf, elektrisch | trockener Knall | brummender Bogen | knisternde Funken | Netzbrummen + zufällige Zaps | – |
| **Heilig** | glockig, schimmernd, warm, aufsteigend | Glockenschlag | Chorfläche, Schimmer | aufsteigendes Funkeln | leiser Chor | impact_bell_heavy_* (Glocke) |
| **Blut** | nass, klatschend, schmatzend, dick | nasser Klatsch | Schmatzen | Tropfenprasseln | – | impact_soft_* (Teil) |
| **Knochen** | trocken, klappernd, hohl, splitternd | trockenes Klacken | Rasseln | Knochen rollen aus und liegen | Klappern (Gehen) | bones_rattle_*, bones-2 (gut) |
| **Gold** | klimpernd, hell, metallisch, satt | Münz-Klink | Klimpern | Münzen rollen aus | – | handlecoins, handlecoins2 |
| Seele (Zusatz) | geisterhaft, flüsternd, ziehend | Atemstoß | Flüster-Whoosh | Hall-Fahne | – | attack_soul (gut) |
| Beben / Stein (Zusatz) | dumpf, rollend, brechend | tiefer Schlag | Steinbrechen | Geröll rollt aus | fernes Grollen | impact_mining_* (gut) |
| Fluch (Zusatz) | dunkel, verzerrt, schwer | tiefer Stich | verzerrtes Anschwellen | Flüstern | – | – |

### 1.4 Heldenstimmen und Heldengeräusche (Foley)

Pro Held ein eigener Stimmsatz, ausgewählt über das Sprite (`voice_of`, §4.4). **Niemals das Geschlecht durch Tonhöhenverschiebung „machen“** – eine hochgepitchte Männerstimme klingt nach Zeichentrick. Die Bogenschützin braucht echte Aufnahmen einer Frauenstimme.

| Held | `class_id` | Sprite | Geschlecht | Stimme | Foley (zum Schritt, −9 dB) | Waffe |
|---|---|---|---|---|---|---|
| Schwertkämpfer | swordsman | knight_m | männlich | tief, kräftig, kurz gepresst (Bariton) | Plattenrüstung + Kettenhemd-Klirren | Schwert: Metall-Whoosh, „Sching“ |
| **Bogenschützin** | archer | **elf_f** | **weiblich** | hell, agil, atemnah (Mezzo); kurze Laute statt Schreie | Leder, klappernde Pfeile im Köcher | Bogen: Sehnen-Twang + Federzischen |
| Magier | mage | wizzard_m (Feuer-Spec: Look custom_pyromancer) | männlich | mittel-tief, älter, beherrscht | Robe, Holzstab | Stab: Element des Specs (Feuer, Frost, Leere) |
| Nekromant | necromancer | necromancer | männlich | heiser, rau, dunkel flüsternd | Robe + klickender Knochenstab | Knochenstab: Seelen-Flüstern |

Stimm-Ereignisse je Held (Anzahl der Varianten): Schmerz leicht 8, Schmerz schwer 4, Tod 3, Anstrengung 6, Ausweichen/Blocken 4, Husten 3, Brennen 2, Sturz 2, Stufenaufstieg/Sieg 3, Kampfschrei 2 – zusammen 37 je Held, 148 insgesamt. Für Schritt S reichen 15 je Held (Schmerz leicht 6, Schmerz schwer 3, Tod 2, Anstrengung 4).

---

## 2 Ereignis-Matrix

**Legende**
- **Schlüssel:** Name in `audio_sfx.json`; NEU = gibt es noch nicht; „Sätze“ = ein Ereignis mit Dateisätzen je Stimme, Boden, Element, Material oder Welt (§4.4).
- **Auslöser:** `datei:funktion`. Abkürzungen: feedback = `src/vfx/feedback.gd`, hell_game = `src/hell/hell_game.gd`, hell_monsters = `src/hell/hell_monsters.gd`, story_elements = `src/hell/story_elements.gd`, talent_combat = `src/combat/talent_combat.gd`, particles = `src/vfx/particles.gd`.
- **Bus:** Ziel-Bus aus §3.1. **P:** Priorität 1 = muss man hören … 4 = Hintergrund.
- **Stimmen / Abstand:** höchstens so viele gleichzeitig / kürzester Abstand zwischen zwei Abspielungen.
- **Variation:** Tonhöhenstreuung, Lautstärkestreuung, Anzahl Varianten.
- **Heute:** ✔ = passende Datei vorhanden · ~ = klingt, aber geliehen, unpassend oder unvollständig · ✖ = stumm oder nur Synth-Piepser · **L** = eine passende Datei liegt schon in `audio_library.json` und muss nur verdrahtet werden.
- Alle Klänge außer P1, UI, Musik, Ambience-Bett und den eigenen Heldenklängen spielen **an ihrer Position** (§3.5).

### A Held – Bewegung, Angriff, Schaden, Zustand

| # | Schlüssel | Auslöser | Klang | Bus | P | Stimmen / Abstand | Variation | Figur | Heute |
|---|---|---|---|---|---|---|---|---|---|
| A1 | `step` (Sätze je Boden: stone, snow, ice, wet, ash) | feedback:update (Schritt-Takt), Rig-Schritte | Stein: trockener Absatz · Schnee: Knirschen · Glatteis: helles Quietschen + Kratzen · Pfütze: Platschen · Asche: Kies-Knirschen | Step | 3 | 1 / Takt = step_time | ±6 %, ±2 dB, 6–8 je Boden | + A2 je Held | ~ überall Beton (Schnee: **L** footstep_snow_000–004) |
| A2 | `foley_move` NEU (Sätze je Held) | zusammen mit `step` | knight_m: Platte + Kette · elf_f: Leder + Köcher · wizard_m / necro_m: Robe (+ Knochenstab-Klick) | Step | 4 | 1 | ±5 %, 4 je Satz | je Held | ✖ (**L** teilweise: cloth1–4, belthandle1–2) |
| A3 | `step_ally` | feedback:update (Mitspieler) | wie A1, an der Position des Mitspielers | Step | 3 | 2 | wie A1 | je Held | ~ |
| A4 | `swing` | hell_game:_swing, feedback:_observe_player | Metall-Whoosh mit kurzem „Sching“ | Hero | 2 | 2 / 0,05 s | ±5 %, 4 → 6 | knight_m | ✔ (Lizenz offen) |
| A5 | `swing_heavy` NEU | feedback (slash_rage), Kombo-Schläge | tiefer Whoosh + Druck-Wumms | Hero | 2 | 2 | ±4 %, 4 | knight_m | ✖ |
| A6 | `shoot_arrow` | hell_game:_attack/_fire, feedback:_observe_player | Sehnen-Twang + Federzischen | Hero | 2 | 3 / 0,06 s (Abklingzeit nur 0,22 s) | ±4 %, ±1,5 dB, 8 | elf_f | ~ (Bambuspeitsche, keine Sehne) |
| A7 | `shoot_magic` (Sätze je Spec: fire, frost, arcane) | wie A6 | Grund: Smaragdkugel · Feuer: Wumms + Knistern · Frost: Kristall-Zirpen · Leere: saugender Plopp | Hero | 2 | 3 / 0,08 s | ±5 %, 4 je Satz | wizard_m | ~ (nur der Grundsatz) |
| A8 | `shoot_necro` NEU | wie A6 (class necromancer) | hohles Seelen-Flüstern + Knochenklick | Hero | 2 | 3 / 0,08 s | ±5 %, 4 | necro_m | ✖ (Verdacht: Synth-Piepser) |
| A9 | `wall_hit` (Sätze je Stil: arrow, magic, fire, frost, arcane, void, poison, gold, bone, metal) | feedback:_wall_hit | Pfeil: Holz-Tock auf Stein · Feuer: Wumms + Zischen · Frost: Glas-Tick · Leere: Saug-Plopp · Gift: nasser Klatsch · Gold: Münz-Klink · Knochen: Klacken | Impact | 3 | 3 / 0,05 s | ±8 %, 3–4 je Stil | – | ✖ (nur metal → `block`) |
| A10 | `hurt` | feedback:_observe_player; hell_game:_hurt/_lose_hp | satter, kurzer Körpertreffer | Focus | 1 | 1 / 0,12 s | ±4 %, 5 | – | ✔ |
| A11 | `vo_hurt` (Sätze je Stimme), ersetzt `hurt_voice` | zusammen mit A10 | kurzer Schmerzlaut, Atem | Voices | 1 | 1 / 0,35 s (nie bei jedem Schadenstick) | ±3 % (Stimmen nie stärker verbiegen), 8 | je Held (§1.4) | ~ (ein Männersatz für alle, auch für elf_f) |
| A12 | `vo_hurt_heavy` NEU | Treffer ab 2 halben Herzen, Krit, Rückstoß | lauter, gepresster Schrei | Voices | 1 | 1 / 0,6 s | ±3 %, 4 | je Held | ✖ |
| A13 | `hurt_element` NEU (Sätze: burn, frost, poison, void, shock) | hell_game:dot_hurt/dot_hurt_f, _hero_conditions | Brennen: Zischen · Frost: Knistern · Gift: Blubbern · Leere: Verzerrung · Blitz: Zap | Focus | 2 | 1 / 0,5 s | ±6 %, 3 je Satz | – | ✖ |
| A14 | `vo_death` + `bodyfall` NEU | hell_game:_lose_hp → end_run(false) | Todeslaut, dann fällt der Körper (+ Rüstung, Bogen oder Stab) | Focus | 1 | 1 | ±2 %, 3 | je Held + Ausrüstung | ✖ (heute nur `hurt_voice` + `team_wipe`) |
| A15 | `lowhp_heartbeat` NEU (Schleife) | hp_f() < 30 % (hell_game:_update_player) | Herzschlag, unter 15 % schneller | Focus | 1 | 1 Schleife | – | – | ✖ |
| A16 | `dodge` NEU | talent_combat:_step_defense (dodge, Bogenschützin) | Stoff-Whoosh + leichter Abroll-Tock (+ `vo_effort` mit 40 %) | Hero | 2 | 1 / 0,15 s | ±5 %, 4 | elf_f | ✖ |
| A17 | `block_raise` / `block_hold` (Schleife) / `block_hit` / `block_break` / `block_regen` | talent_combat:_step_defense, incoming (block: Magier, Schwertkämpfer, Nekromant) | knight_m: Schild-Metall · wizard_m: summende Glas-Barriere · necro_m: klackende Knochenwand | Hero | 2 | 2 / 0,05 s | ±5 %, 3 je Satz | je Held | ~ (nur der Treffer `block`, Metall) |
| A18 | `dash` / `dash_land` NEU | hell_game:on_dash_land; Talente dash, leap | Whoosh + Rutschen; Landung: Tock + Staub | Hero | 2 | 1 | ±5 %, 4 | – | ✖ |
| A19 | `blink_out` / `blink_in` | Talente blink; Theme `blink` | zweiteilig: Sog weg – Plopp da | Hero | 2 | 1 | ±4 %, 3 | – | ~ (`void_burst`) |
| A20 | `ice_skid` NEU (Schleife) | hell_game:_update_player (_skid auf Glatteis) | Kratzen + Eissplitter, Lautstärke folgt dem Tempo | Step | 3 | 1 Schleife | Tonhöhe folgt dem Tempo | – | ✖ |
| A21 | `medium_enter` / `medium_wade` (Schleife) / `medium_exit` NEU (Sätze: water, lava, poison, blood) | hell_game:_step_elements (hero_medium) | Hineinplatschen, Waten, Abtropfen; Lava: Zischen | Step | 2 | 1 Schleife | ±5 %, 3 je Satz | – | ✖ |
| A22 | `gas_breath` (Schleife) + `vo_cough` NEU | hell_game:_step_elements/_step_gas (hero_gas) | gedämpftes Atmen, Husten je Stimme | Voices | 2 | 1 / 1,2 s (Husten) | ±3 %, 3 je Stimme | je Held | ✖ (**L** cough_01–03, männlich) |
| A23 | `mad_whisper` NEU (Schleife) | hell_game:_void_mind (Wahn) | Flüstern, das durch das Stereobild wandert | Voices | 3 | 1 Schleife | – | – | ✖ |
| A24 | `pit_fall` NEU | hell_game:_fall_into_pit | Fall-Whoosh + `vo_fall` + ferner Aufprall + Schimmer bei der Rückkehr | Focus | 1 | 1 | ±2 %, 2 | je Held | ✖ |
| A25 | `level_up` | hell_game (Theme `level_up`), feedback (Team-Stufe) | aufsteigendes Licht, Chor, Glocke | Focus | 1 | 1 | 2 | – | ~ (`perk` / `room_clear`) |
| A26 | `skill_cast` (hero_skills.json „sound“) | feedback:_observe_player (skill_casts) | je Fähigkeit ein eigener Klang statt geliehener Gegnerklänge | Hero | 2 | 2 | ±5 % | – | ~ (geliehene Gegnerklänge) |
| A27 | `clone_spawn` / `clone_end` NEU | hell_game:use_skill, _update_clone | schimmernder Aufbau, Zerfall | Hero | 2 | 1 | ±4 %, 2 | – | ~ (cleanse → `room_clear`) |
| A28 | `mana_orb` NEU | talent_combat:_step_orbs, restore_mana | Glasglöckchen + Einsaugen | World | 3 | 2 / 0,08 s | ±6 %, 4 | – | ✖ |
| A29 | `no_mana` / `on_cooldown` | hell_game:act (Theme `no_cooldown`) | leises, dumpfes Verpuffen | UI | 3 | 1 / 0,3 s | 2 | – | ~ (`ui_back`) |
| A30 | `crystals_bank` NEU | hell_game:_bank_crystals | Kristall-Kaskade | Focus | 2 | 1 | 2 | – | ✖ |
| A31 | `familiar_chirp` / `familiar_whoosh` NEU | src/hero/familiar.gd (Irrwisch) | selten ein Zirpen, leiser Whoosh bei schneller Bewegung | Hero | 4 | 1 / 6 s | ±8 %, 6 | Magier | ✖ (**L** cute_01–10) |
| A32 | `run_won` NEU | hell_game:end_run(true) | Sieg-Fanfare je Welt | Focus | 1 | 1 | – | – | ~ (`level_up` → `perk`) |
| A33 | `vo_effort` / `vo_cast_ult` / `vo_taunt` NEU | Angriffe (jeder 4.–5., Chance 30 %), Ultimate-Start, taunt_area | Anstrengung, Ultimate-Ruf, Kampfschrei | Voices | 2 | 1 / 1,5 s | ±3 %, 6 / 3 / 2 | je Held | ✖ |

### B Talente und Ultimates (`talent_combat.gd`) – heute alles stumm

Gemeinsam: Sätze je Element (fire, frost, void, shock, poison, holy, bone, physical), Bus Hero, an der Position des Wirkpunkts, außer Ultimates (Focus, ohne Position).

| # | Schlüssel | Auslöser | Klang | Bus | P | Stimmen / Abstand | Variation | Heute |
|---|---|---|---|---|---|---|---|---|
| B1 | `tal_cast` | talent_combat:cast, _run | kurzes Aufladen in der Farbe des Elements | Hero | 2 | 3 / 0,06 s | ±5 %, 3 je Element | ✖ |
| B2 | `tal_projectile` + `tal_impact` | _run (projectile), bullet_hit | Abschuss + Einschlag im Element | Hero / Impact | 2 | 4 / 0,05 s | ±6 %, 4 | ✖ |
| B3 | `tal_nova` | _run (nova), _area | Ring-Ausbruch: Feuer-Wumms-Ring, splitternde Frostnova, Leere-Implosion, heilige Glocke | Hero | 2 | 2 | ±4 %, 3 | ✖ |
| B4 | `tal_zone_start` / `_loop` / `_end` | _run (zone), _step_zones, _zone_element | Feuerbett-Knistern, Frostwind, Giftblubbern, Leere-Summen | Hero | 3 | 2 Schleifen | – | ✖ |
| B5 | `tal_meteor_fall` + `tal_meteor_hit` | _run (meteor), _meteor_aftermath | fallendes Pfeifen 1–1,5 s (die Ansage), Einschlag + Beben + Glut | Hero | 1 | 2 | ±3 %, 3 | ✖ |
| B6 | `tal_glacier` | _run (glacier), _land_freeze | Eiswand wächst ächzend, knackt | Hero | 2 | 1 | 3 | ✖ |
| B7 | `tal_chain` | _run (chain) | Blitzbogen je Sprung, jeder Sprung etwas höher | Hero | 2 | 4 / 0,06 s | +6 % je Sprung, 4 | ✖ |
| B8 | `tal_line` | _run (line) | scharfer Peitschen-Durchschuss | Hero | 2 | 2 | 3 | ✖ |
| B9 | `tal_trap_set` / `_arm` / `_snap` | _run (trap), _step_traps | Klick, Tick, Zuschnappen (+ Element) | World | 2 | 2 | 3 je | ✖ |
| B10 | `tal_net` | _run (net) | Wurf-Whoosh + sich spannendes Seil | Hero | 2 | 1 | 3 | ✖ |
| B11 | `tal_summon` | _run (summon), _spawn_pet | anschwellende Beschwörung + Ankunft je Begleiter (C) | Hero | 2 | 1 | 2 je | ✖ |
| B12 | `tal_buff_on` / `_off`, `tal_awaken` | _run (buff, awaken), _awaken | Kraft-Schimmer; Erwachen mit Gebrüll | Hero | 2 | 1 | 3 | ✖ |
| B13 | `tal_shield_on` / `_hit` / `_break` | _run (shield), _dome_hit | Kuppel summt an, Treffer-Ping, Zerspringen | Hero | 2 | 2 / 0,05 s | 3 je | ✖ |
| B14 | `tal_echo` | _run (echo), _echo_point | Kopie des letzten Zaubers, −6 dB, Tiefpass 3 kHz, mehr Hall | Hero | 3 | 2 | – | ✖ |
| B15 | `tal_devour`, `catch_shot`, `essence` | _run (devour), catch_shot, _essence | schluckender Sog; gefangenes Geschoss wird verschluckt; Essenz flüstert zum Helden | Hero | 2 | 2 / 0,1 s | 3 je | ✖ |
| B16 | `gefuege_store` / `gefuege_spend` | feed, _store, spend (Arkanes Gefüge) | je Einheit ein winziges Glöckchen in der Tonhöhe des Elements; Ausgeben = Akkord | Hero | 3 | 2 / 0,08 s | Tonhöhe je Element, 3 | ✖ |
| B17 | `ult_singularity` (drei Teile) | _run (singularity), _collapse, _fling_caught, _step_flung | 2–3 s steigender Sog → Sub-Implosion → Urknall (0,3 s Stille davor) | Focus | 1 | 1 | – | ✖ |
| B18 | `tal_mark` | _run (mark) | Ziel-Ping + tiefer Ton | Hero | 3 | 1 | 2 | ✖ |
| B19 | `tal_harvest` | _run (harvest) | Seelen fliegen mit Whoosh zum Helden | Hero | 2 | 2 | 3 | ✖ |
| B20 | `tal_channel_start` / `_loop` / `_end` | _run (channel) | Strahl-Schleife | Hero | 2 | 1 Schleife | – | ✖ |
| B21 | `tal_counter` | _run (counter) | Parier-Klirren + Gegenhieb | Hero | 2 | 1 | 3 | ✖ |
| B22 | `tal_bulwark`, `tal_taunt_area` | _run (bulwark, taunt_area) | Stein und Metall verfestigen sich; Kriegsschrei (`vo_taunt`) | Hero / Voices | 2 | 1 | 2 | ✖ |
| B23 | `tal_melee` (Sätze je Element) | _run (melee) | Schwung im Element (Feuerklinge, Frostklinge …) | Hero | 2 | 2 / 0,05 s | ±5 %, 3 je | ✖ |
| B24 | `wall_slam` | _wall_slam, _flight_over | geschleuderter Gegner prallt: dumpfer Körper + Steinriss | Impact | 2 | 2 / 0,08 s | 3 | ✖ |
| B25 | `lance_drops` | _lance_drops, _drop_now, _land | landende Tropfen und Splitter: kleine Ticks | Debris | 4 | 3 / 0,05 s | ±10 %, 4 | ✖ |
| B26 | `tal_pool` | _pool_at | Pfütze entsteht im Element (Klatsch) + leise Schleife | Hero | 3 | 2 | 3 | ✖ |
| B27 | `ult_ready` | ultimate_cd abgelaufen (src/ui/talent_bar.gd) | leises Glöckchen | UI | 3 | 1 | 1 | ✖ |
| B28 | `status_<x>` (burn, poison, bleed, freeze_on, freeze_off, stun, slow, mad, blind) | _apply_status, _status, _madden, _hold_enemy | am Gegner: Zisch-Tick, Blubber-Tick, Tropfen, Eis-Einschluss-Knacken, Auftau-Knacken, Benommenheits-Klingeln, Frost-Knarzen, Flüstern | Enemy | 3 | 2 je Zustand / 0,35 s | ±8 %, 3 je | ✖ |
| B29 | `heal` | _heal, heal_on_kill, _heal_pet | warmes Glöckchen | Hero | 2 | 1 / 0,3 s | 3 | ✖ |
| B30 | `ult_<id>` × 12 (je drei Teile: Laden, Auslösen, Ausklang) | _run (Ultimates), _stage_effects | ein Signaturklang je Spec; duckt die Musik um −4 dB | Focus | 1 | 1 | – | ✖ |

### C Begleiter (`talent_combat.gd`, `src/vfx/companion_rigs.gd`) – heute alles stumm

Auslöser für alle: talent_combat:_spawn_pet (Ankunft), _step_pets (Bewegung, Leerlauf), pet_cast / _pet_strike / _pet_hit (Fähigkeiten), _hurt_pet (Treffer, Teilverlust über body_parts), `dying_p` in companion_rigs.gd (Tod). Bus: Fähigkeiten Hero (−6 dB), Stimmen Voices. P2 für Fähigkeiten und Tod, P3 für Leerlauf (höchstens alle 6 s). Alle an ihrer Position.

| # | Begleiter | Ankunft | Stimme, Leerlauf | Bewegung | Fähigkeit 1 | Fähigkeit 2 | Treffer, Teilbruch | Tod | Heute |
|---|---|---|---|---|---|---|---|---|---|
| C1 | Wolf | Heulen | Hecheln, Knurren | leichte Pfoten | Zerfleischen: Knurren + Biss + Fleisch | Heulen (Spott): langes Heulen | Jaulen | Winseln, das verklingt | ✖ (**L** howl, attack_01–05) |
| C2 | Bär | Brüllen | Brummen | schwere Tritte | Prankenhieb: schwerer Whoosh + Krallenriss | Brüllen (Spott) | tiefes Grunzen | langes Stöhnen | ✖ (**L** roar_01–03, troll_01–03) |
| C3 | Falke | Schrei | seltener Ruf | Flügelschläge (an die Animation gebunden, gedrosselt) | Sturzflug: Pfeifen + Einschlag | Augenhacker: doppeltes Picken | Kreischen | Federpuff | ✖ |
| C4 | Wasserelementar | Wasser wallt auf | Blubbern | Schwappen | Eislanze: Knacken + Whoosh | Frostnova: Eisring-Ausbruch | Platschen | zusammenfallende Welle | ✖ (**L** burble_01–02, impact_glass) |
| C5 | Skelette (Beschwörung) | Boden reißt + Klappern | Klappern | Knochenschritte | Hieb | – | Knochentreffer | Zerfallen | ✖ (**L** bones_rattle, kill_bone) |
| C6 | Knochenkrieger | Rüstung + Klappern | hohles Schädelraunen | klappernde Schritte | Schildschlag: Metall + Knochen | Knochenschrei (Spott) | `hit_bone` | `collapse_bone` | ✖ (**L**) |
| C7 | Knochenkoloss | Beben | tiefes Ächzen | schwere Stampfer | Stampfschlag | – | schwerer Knochen | großer Einsturz | ✖ (**L** stomp_01, bones-2) |
| C8 | Pyro-Monster | Feuersäule | knisterndes Knurren | heiß zischende Schritte | Glutfaust: Feuer-Whoosh + Wumms | Feuerkreis: Ring-Wumms | Zischen | Ausbrennen + Glutknistern | ✖ |
| C9 | `pet_heal` / `pet_return` | talent_combat:_care, _heal_pet; Teleport zurück ab 14 m | leises Atmen / Glöckchen; Whoosh | – | – | – | – | – | ✖ |
| C10 | `pet_auto_toggle` | talent_combat:toggle_pet_auto (Rechtsklick) | UI-Klick an / aus | – | – | – | – | – | ✖ |

### D Gegner

#### D1 Wer klingt wie? (Aussehen → Material, Hülle, Stimme)

Neu: Ein Monster hat ein **Material** (Körper), optional eine **Hülle** (`coat`: frost, fire, void, lava – eine zusätzliche Schicht auf Treffer und Tod) und eine **Größe** (small +15 % Tonhöhe, normal, big −20 % Tonhöhe + Stampfer). Neue Materialien: stone, ice, slime, beast, imp, bat, ghost, caster, chain, armored, wood_flesh, dragon, snow, wind (14 neue zu den 3 bestehenden).

| Welt | id | Aussehen | heute (`rig_materials`) | neu: Material + Hülle (Größe) | Stimme | Hinweis |
|---|---|---|---|---|---|---|
| Krypta | skelett, skelettschuetze, skelettwache | Skelette | bone | bone | keine, Klappern | passt |
| Krypta | knochenwaechter, knochenkoloss | große Skelette | bone | bone (big) | Ächzen | Stampfer fehlen |
| Krypta | nekromant, nekromantenfuerst | Robenträger | flesh | caster | heiser murmelnd; der Fürst tiefer | `kill_necro` passt, wird in der Story aber nie gespielt |
| Krypta | zombie, moderkoloss | Untote | flesh | flesh (Koloss: big) | Stöhnen | passt |
| Krypta | frostleiche, eiszombie | gefrorene Untote | flesh / **bone** | flesh + frost | gefrorenes Stöhnen | eiszombie steht als bone – Widerspruch |
| Krypta | grabmutter | weibliche Untote | flesh | flesh (big) | **weiblich:** tiefes Klagen | eine Gegnerin darf nicht die männliche Monsterstimme haben |
| Krypta | leerenbomber, leerenbrut, leerenrufer | Leerenwesen | void | void | Zischen, Summen | passt |
| Krypta / Hölle | mimik, truhenfresser | Truhen-Monster | flesh | wood_flesh | Schmatzen + knarrendes Holz | |
| Krypta | archivar | geisterhafter Archivar | flesh | ghost (+ raschelndes Papier) | Flüstern | **L** bookflip1–3 |
| Frostgruft | frost_skeleton | Skelett mit Eis | bone | bone + frost | – | |
| Frostgruft | ice_knight, frost_commander | gerüstete Eisskelette | bone | armored + frost | Kommandant ruft | Metall fehlt |
| Frostgruft | golem | Eisgolem | **bone** | stone + frost (big) | tiefes Grollen | falsch gemappt |
| Frostgruft | ice_slime, ice_slime_m, ice_slime_s | Eisschleime | **flesh** | slime + frost (Größe: s, m, groß) | Schmatzen | **L** slime_01–08 |
| Frostgruft | frost_necromancer | Robenträger | flesh | caster + frost | heiser | |
| Frostgruft | frost_imp | Imp | **void** | imp + frost | Kichern, Zirpen | falsch gemappt |
| Frostgruft | frost_whirl | Wirbel | void | wind | Wirbelwind-Schleife | |
| Frostgruft | ice_crystal | Kristall | **void** | ice | singendes Glas | **L** impact_glass_* |
| Frostgruft | ice_zombie | Eis-Zombie | **bone** | flesh + frost | Stöhnen | frost_theme sagt flesh, rig_materials bone |
| Frostgruft | snowman (Mimik der Frostgruft) | Schneemann | **fehlt** | snow | Grollen beim Erwachen | heute: `hit_bone` beim Erwachen, Tod = Synth-Piepser `kill` |
| Hölle | glutschaedel | fliegender brennender Schädel | bone | bone + fire (small) | Zähneklappern | dazu Flammenflattern als Schleife |
| Hölle | brandskelett | brennendes Skelett | bone | bone + fire | Klappern | |
| Hölle | glutwaechter | Glutwächter (wirft Lava, stampft Pfützen) | bone | stone + lava (big) | schweres Steingrollen | |
| Hölle | hoellenhund | Höllenhund | flesh | beast + fire | Bellen, Knurren, Hecheln | **L** barking_01–02 |
| Hölle | dreischlund | dreiköpfiger Hund (Boss) | flesh | beast + fire (big) | Gebrüll in drei Tonhöhen übereinander | |
| Hölle | glutimp | Imp | flesh | imp + fire | Kichern | |
| Hölle | blutfledermaus | Fledermaus | flesh | bat | Quieken + Flattern | |
| Hölle | aschenpriester | Priester | flesh | caster + fire | Singsang | |
| Hölle | kettenschinder | Schinder mit Ketten | flesh | chain | Grunzen, schleifende Ketten | |
| Hölle | kerkermeister | Kerkermeister (Boss) | flesh | chain (big) | tiefe Stimme, Schlüsselbund | |
| Hölle | kesselbrut | Kesselbrut | flesh | slime + lava | Blubbern | **L** burble_01–02 |
| Hölle | drache1, drache2, drache3 | Drachenformen (Ignaroth) | flesh | dragon + fire (big) | riesiges Gebrüll | Flügel, Feueratem |
| Hölle | drache4 | Leerendrache | void | dragon + void (big) | Gebrüll + Sog | |
| Hölle | peingeist, seelenhirte, klagender_hueter | Geister | void | ghost | Klagen und Heulen; der Hirte: Chor-Summen | |

#### D2 Gegner-Ereignisse je Familie

| # | Schlüssel | Auslöser | Klang | Bus | P | Stimmen / Abstand | Variation | Heute |
|---|---|---|---|---|---|---|---|---|
| D2-1 | `idle_<fam>` | feedback:_observe_enemy (moving, IDLE_RANGE) | Klappern, Stöhnen, Knurren, Summen, Kichern … | Idle | 4 | 3 / 0,5–1 s, Chance 35 % | ±10 %, 6–10 | ~ (nur bone, flesh) |
| D2-2 | `move_<fam>` NEU | feedback:_observe_enemy (moving); hell_monsters:_move | große Schritte, Flattern, Schleimen, schleifende Ketten, Flammenflattern | Idle | 3 | 3 / Animationstakt | ±8 %, 4 | ✖ |
| D2-3 | `hit_<fam>` + `coat_<x>_hit` | feedback:_observe_enemy (hits); hell_game:_damage_mob; hell_talents | Material + Hülle (z. B. Knochen + Feuerzischen) | Impact | 2 | 4 / 0,04 s | ±7 %, 4–6 | ~ (3 von 17 Materialien) |
| D2-4 | `break_<fam>` | feedback (part_breaks); body_parts | Knochen bricht, Fleisch reißt, Eis splittert, Stein bricht … | Impact | 2 | 3 / 0,05 s | ±6 %, 3 | ~ (nur bone, flesh, void) |
| D2-5 | `kill_<fam>` + `coat_<x>_kill` | feedback:_play_death; hell_game (Theme `kill_*`) | Todesklang je Material, Hülle: Ausbrennen, Eis zerspringt, Leere fällt zusammen | Enemy | 2 | 4 / 0,03 s | ±6 %, 4 | ~ (bone, flesh, void + necro; der Rest klingt falsch oder piepst) |
| D2-6 | `vo_enemy_hurt_<fam>` NEU | feedback (hits), Chance 30 % | kurzer Schmerzlaut der Kreatur | Voices | 3 | 2 / 0,6 s | ±6 %, 4 | ✖ |
| D2-7 | `vo_enemy_death_<fam>` | feedback:_play_death (Schicht) | Todeslaut der Kreatur | Voices | 2 | 3 / 0,05 s | ±5 %, 4 | ~ (`kill_flesh` = die_01–04) |
| D2-8 | `regrow` | feedback (part_regrows) | Teil wächst nach | Enemy | 3 | 2 | 2 | ✔ |
| D2-9 | `block` | feedback (blocks, Schildträger) | Parade, Metall | Impact | 2 | 2 | 3 | ✔ |
| D2-10 | `windup_fuse` / `bomber_pop` / `void_burst` | feedback | Lunte, Abschuss-Plopp, Implosion | Enemy | 2 | 2 | 3 | ✔ |

#### D3 Angriffe (Ansage, Auslösen, Einschlag)

Heute bilden `story_attacks` (audio_sfx.json) rund 40 Story-Angriffe auf 9 Krypta-Arten ab. Neu: eigene Arten mit Sätzen je Element und für jede Art eine Ansage (`windup_<kind>`).

| # | Schlüssel | Auslöser (story_attacks-Gruppe) | Klang | Bus | P | Stimmen / Abstand | Variation | Heute |
|---|---|---|---|---|---|---|---|---|
| D3-1 | `windup_<kind>` für **jede** Art | feedback:_observe_enemy (attack == windup) | Einatmen, Scharren, Ausholen, Aufladen – je Art | Enemy / Boss | 2 | 3 / 0,1 s | ±5 %, 3 je Art | ✖ (nur beam, fuse, summon) |
| D3-2 | `attack_slash` | hell swing; moves spin (Gegner) | Klingen-Whoosh | Enemy | 2 | 3 | ±8 %, 4 | ✔ |
| D3-3 | `attack_bite` | hell dash; kits fist, charge; moves dash; behaviors dasher | Biss / Ansturm | Enemy | 2 | 3 | ±10 %, 1 → 4 | ~ (eine Datei, für Ansturm zu klein) |
| D3-4 | `attack_arrow` | moves bullets; kits fan; behaviors shooter, turret | Pfeil; für Eissplitter: Kristall-Tick | Enemy | 2 | 3 / 0,05 s | ±5 %, 4 | ~ (Pfeil auch für Eissplitter) |
| D3-5 | `attack_soul` | hell bolt, lob, homing, spiral; Ersatz für Gegner | Seelenkugel | Enemy | 2 | 3 | 3 | ~ (Feuer, Lava und Gift klingen nach dunkler Seele) |
| D3-6 | `attack_salve` | hell ring; Salven ab 3 Schüssen | Salve | Boss | 2 | 2 | 3 | ~ (Leere für jedes Element) |
| D3-7 | `attack_slam` | hell slam; kits stomp | Aufprall | Boss | 2 | 2 | 3 | ✔ |
| D3-8 | `attack_roar` | hell breath, scream, flight; moves frost_nova, cone | Gebrüll | Boss | 2 | 2 | 3 | ~ (Feueratem = Gebrüll) |
| D3-9 | `attack_summon` | hell summon, echoes, hands, meteors; kits icicles, chill_zones, teleport_center, last_stand | Beschwörung | Boss | 2 | 2 | 2 | ~ (für 9 sehr verschiedene Angriffe) |
| D3-10 | `attack_beam` | hell beam, sweep; kits breath, spiral | Strahl | Boss | 2 | 1 | 3 | ~ (lila Laser auch für Feuer) |
| D3-11 | `attack_breath_<el>` NEU (fire, frost, poison, void) | hell breath; kits breath; moves cone | Feuer: Flammenwerfer-Schleife · Frost: eisiger Sturm · Gift: Zischen · Leere: Sog | Boss / Enemy | 2 | 2 Schleifen | – | ✖ |
| D3-12 | `attack_lob_<el>` + `lob_land_<el>` NEU | hell lob (kesselbrut, glutwaechter); moves lob | dumpfer Mörser-Abschuss + Flugpfeifen; Landung: Lava- oder Giftklatsch | Enemy | 2 | 3 | ±6 %, 3 | ✖ |
| D3-13 | `attack_chain` | hell chain (Kettenschinder, Kerkermeister) | Kettenpeitsche + Metallrasseln | Enemy | 2 | 2 | 4 | ~ (Bambuspfeil) |
| D3-14 | `attack_scream` | hell scream | echter Schrei (Geist, Banshee) | Boss / Enemy | 2 | 1 | 3 | ~ (Gebrüll / Seele; **L** scream_01–02) |
| D3-15 | `attack_burrow` | hell burrow | Graben (Schleife) + Auftauchen | Enemy | 2 | 1 Schleife | – | ~ (slam / bite) |
| D3-16 | `attack_flight` | hell flight | große Flügelschläge + Vorbeiflug | Boss | 2 | 1 | 3 | ~ (Gebrüll) |
| D3-17 | `attack_teleport` | hell teleport | weicher Leere-Plopp: weg – da | Enemy / Boss | 2 | 2 | 3 | ✖ (bewusst stumm – der Spieler muss aber hören, wohin es ging) |
| D3-18 | `trail_<el>` (Schleife) | hell trail | knisternde Feuerspur | Enemy | 3 | 2 Schleifen | – | ✖ (stumm) |
| D3-19 | `frost_nova` / `frost_cone` | moves frost_nova, cone | Eisring-Ausbruch, Frostatem | Boss / Enemy | 2 | 2 | 3 | ~ (Gebrüll) |
| D3-20 | `whirl` (Schleife) | moves spin, vortex | Wirbelwind | Enemy | 2 | 1 Schleife | – | ~ (slam / slash) |
| D3-21 | `ice_strikes` | moves strikes | Eisdornen brechen nacheinander aus dem Boden | Boss | 2 | 4 / 0,06 s | ±8 %, 4 | ✖ (stumm) |
| D3-22 | `ice_armor` | moves armor (fx `armor`) | knisternde Eisrüstung wächst | Enemy | 2 | 1 | 2 | ~ (`frost` fehlt → `perk`) |
| D3-23 | `icicles_fall` | kits icicles | Pfeifen von oben + Zerspringen | Boss | 1 | 4 / 0,08 s | ±6 %, 4 | ~ (Beschwörung) |
| D3-24 | `chill_zone` | kits chill_zones | Frost zischt auf den Boden | Boss | 2 | 2 | 3 | ~ (Beschwörung) |
| D3-25 | `meteors_incoming` | hell meteors | Grollen von oben + Pfeifen | Boss | 1 | 3 | 3 | ~ (Beschwörung) |
| D3-26 | `hands_rise` | hell hands | Boden reißt + greifende Knochen | Boss | 2 | 3 | 3 | ~ (Beschwörung) |
| D3-27 | `eshot_passby` NEU | hell_monsters:update_shots (Schuss näher als 120 px am Helden) | kurzes Vorbeizischen | Enemy | 3 | 2 / 0,12 s | ±8 %, 4 | ✖ |
| D3-28 | `eshot_impact_<el>` NEU | hell_monsters:_shot_impact, _shot_trail | kleiner Einschlag im Element | Impact | 3 | 3 / 0,05 s | ±8 %, 3 je | ✖ |

### E Bosse und Wächter (`hell_monsters.gd`, `boss_kit.gd`, `frost_moves.gd`)

| # | Schlüssel | Auslöser | Klang | Bus | P | Stimmen / Abstand | Variation | Heute |
|---|---|---|---|---|---|---|---|---|
| E1 | `boss_intro` (Sätze je Welt) | feedback:_actor (erster Boss im Raum); hell_game:enter_boss_room | Welt-Stinger: Orgel (Krypta), Glocken + Eis (Frost), Trommeln + Chor (Hölle) | Focus | 1 | 1 | – | ~ (ein Horror-Stinger für alle) |
| E2 | `boss_flyin` NEU | hell_monsters:start_intro, _update_intro (flyin) | näher kommende Flügel und Gebrüll | Boss | 1 | 1 | – | ✖ |
| E3 | `boss_vo_<id>` (je Boss: Gebrüll, Schmerz, Tod) | boss_kit, hell_monsters (Akte), story_sound:_roars | eigene Stimme je Boss nach D1 | Voices | 1 | 1 | ±3 %, 3 je | ~ (`attack_roar` für alle) |
| E4 | `boss_rage` | frost_moves (rage_below), story_sound:_roars | Wut: Gebrüll + Herzschlag-Schub | Boss | 1 | 1 | 2 | ~ (`attack_roar`) |
| E5 | `boss_form_swap` | hell_monsters:_set_form (Ignaroth) | Verwandlung: Feuerwirbel + Gebrüll | Boss | 1 | 1 | – | ~ (`attack_roar`) |
| E6 | `boss_hit_layer` NEU | feedback (Treffer am Boss) | tiefer Wumms unter dem Materialtreffer | Impact | 2 | 2 / 0,06 s | ±5 %, 3 | ✖ (Synth `boss_hit` nur als Notlösung) |
| E7 | `boss_lord_end` NEU | hell_monsters:_start_lord_end, _update_lord_end | langes Ende: Bröckeln, erlöschendes Feuer, letzter Schrei, Stille | Focus | 1 | 1 | – | ✖ |
| E8 | `boss_kill` | feedback:_play_death (boss) | großer Knall | Focus | 1 | 1 | 1 | ✔ |
| E9 | `boss_defeated` (Sätze je Welt) | feedback; Theme `boss_dead` | Sieg-Melodie je Welt | Focus | 1 | 1 | – | ~ (Cembalo passt nur zur Krypta) |
| E10 | `boss_last_stand` | kits last_stand | tiefer Herzschlag + Gebrüll | Boss | 1 | 1 | – | ~ (Beschwörung) |
| E11 | `boss_landing` (Sätze je Zonenart) | story_sound:frame (landings) | Landungen von wave, erupt, land, meteor, hand, line je eigener Klang | Boss | 2 | 2 / 0,08 s | ±5 %, 3 je | ~ (ein `blast` für alles) |

### F Element-Reaktionen (`story_elements.gd`)

| # | Schlüssel | Auslöser | Klang | Bus | P | Stimmen / Abstand | Variation | Heute |
|---|---|---|---|---|---|---|---|---|
| F1 | `react_explode` | story_elements:_explode (Feuer auf Gift), Kette bis explode_chain; feedback element explode | Gas-Wumms + chemischer Knall + Trümmer; in der Kette je Stufe 80 ms später und −4 % tiefer | Impact | 2 | 3 / 0,08 s | ±4 %, 4 | ~ (kleines `blast`) |
| F2 | `react_ignite` NEU | story_elements:fire_passes (Gas fängt Feuer) | Zünd-Whoosh | Impact | 2 | 2 | 3 | ✖ |
| F3 | `react_boil` NEU | story_elements:_boil; feedback steam / crust | Wasser kocht auf, Dampfstoß | Impact | 2 | 2 / 0,1 s | 3 | ✖ |
| F4 | `react_thaw` NEU | story_elements:fire_at (Eis taut); feedback thaw | Knacken + Tropfen | Impact | 3 | 2 | 3 | ✖ |
| F5 | `react_freeze` NEU | story_elements:frost_at (Glatteis); feedback freeze (ruft das fehlende `frost`) | Wasser gefriert knisternd | Impact | 2 | 2 | 3 | ✖ |
| F6 | `react_crust` NEU | story_elements:_lava_meets_water | Zischen + krachende Gesteinskruste | Impact | 2 | 2 | 3 | ✖ |
| F7 | `react_douse` NEU | story_elements:water_at (Feuer geht aus) | „Pschhh“ | Impact | 3 | 2 | 3 | ✖ |
| F8 | `react_charge` + `charge_loop` + `charge_zap` | story_elements:lightning_at, _step_charges | Einschlag; geladene Pfütze brummt (Schleife); Zap je Gegner im Takt charge_tick | Impact | 2 | 2 Schleifen, Zaps 3 / 0,15 s | ±10 %, 4 | ✖ |
| F9 | `react_wave` NEU | story_elements:wave_at | Druckwelle: tiefes „Wumpf“ + Luftstoß | Impact | 2 | 2 | 3 | ✖ |
| F10 | `react_quake` | story_elements:quake_at | Grollen + Steinriss + Geröll | Impact | 2 | 2 | 3 | ~ (`blast`) |
| F11 | `react_holy` + `holy_heal` | story_elements:holy_at | Glocke + anschwellender Chor; Heil-Glöckchen am Helden | Hero | 2 | 1 | 2 | ✖ |
| F12 | `void_swallow` / `void_gulp` | story_elements:void_at, _void_swallows | Sog, der Pfützen und Gas frisst; ab und zu ein Schlucken | Hero | 3 | 2 / 0,6 s | 3 | ✖ |
| F13 | `floor_meets` (Sätze: boom, boil, freeze) | story_elements:_floor_meets_puddles | Gift auf Lava knallt, Wasser auf Lava kocht, Wasser auf Eis gefriert | Impact | 3 | 2 | 3 je | ✖ |

### G Zonen und Gefahren der Monster und der Welt

| # | Schlüssel | Auslöser | Klang | Bus | P | Stimmen / Abstand | Variation | Heute |
|---|---|---|---|---|---|---|---|---|
| G1 | `puddle_spawn_<el>` | hell_monsters:_zone (kind puddle) | Pfütze klatscht auf (Lava, Gift, Leere, Frost, Blut) | World | 3 | 3 / 0,1 s | ±8 %, 3 je | ✖ |
| G2 | `puddle_loop_<el>` | Pfützen in Heldennähe (pool_entries) | Lava blubbert, Gift sprudelt, Leere summt | Ambience | 4 | 3 Schleifen (die nächsten) | – | ✖ |
| G3 | `zone_wave` | hell_monsters (kind wave) | laufende Bodenwelle: Grollen, das wandert | Boss | 2 | 2 | 3 | ~ (`blast`, nur bei Bossen) |
| G4 | `zone_fissure` | hell_monsters:_fissure (kind line) | Riss + Lava schießt hoch | Boss | 2 | 2 | 3 | ~ (`blast`) |
| G5 | `zone_arc` | hell_monsters (kind arc) | Bogen-Schlag mit Luftzug | Enemy | 2 | 2 | 3 | ✖ |
| G6 | `zone_meteor` | hell_monsters (kind meteor) | Pfeifen beim Fallen → Einschlag | Boss | 1 | 3 / 0,08 s | ±5 %, 3 | ~ (`blast`) |
| G7 | `zone_cone_<el>` (Schleife) | hell_monsters (kind cone) | Atem-Kegel: Feuerrauschen, Frostwind | Boss | 2 | 2 Schleifen | – | ✖ |
| G8 | `zone_erupt` | hell_monsters (kind erupt) | Lava bricht aus | Boss | 2 | 2 | 3 | ~ (`blast`) |
| G9 | `zone_land` | hell_monsters (kind land, Drache) | sehr schwerer Aufprall + Trümmer | Boss | 1 | 1 | 2 | ~ (`blast`) |
| G10 | `zone_hand` | hell_monsters:_px_hand (kind hand) | Boden reißt + Hand greift zu | Boss | 2 | 3 | 3 | ~ (Beschwörung) |
| G11 | `firewall_loop` + `ash_line` | hell_monsters:_draw_firewall, _ash_line | Feuerwand-Schleife; zurück bleibt rieselnde Asche | Enemy | 2 | 2 Schleifen | – | ✖ |
| G12 | `lava_splash` (auch slag_spout, fountain, lob_drips) | hell_monsters:lava_splash, _slag_spout, _fountain, _lob_drips | Lavaspritzer, Schlacke, Tropfen brutzeln am Boden | World | 3 | 3 / 0,06 s | ±10 %, 4 | ✖ |
| G13 | `rift` | hell_monsters:_rift | Riss in der Leere | Enemy | 2 | 2 | 3 | ✖ |
| G14 | `scream_front` | hell_monsters:_scream_blast, _sound_fronts, _sound_dust | Schall-Front des Schreis: Druck + Staubrieseln | Boss | 2 | 1 | 2 | ✖ (der Schrei ist heute nur zu sehen) |
| G15 | `crack_floor` | hell_monsters:_crack_floor | Bodenriss läuft | World | 3 | 2 / 0,1 s | 3 | ✖ |
| G16 | `scorch_sizzle` | hell_monsters:_scorch, _update_scorches | Brandfleck brutzelt und kühlt ab | Debris | 4 | 2 / 0,3 s | 3 | ✖ |
| G17 | `phys_blast_embers` | hell_monsters:_phys_blast | Glutfunken stieben | Debris | 3 | 2 | 3 | ✖ |
| G18 | `mad_strike` | hell_monsters:_mad_strike, _mad_zone; hell_game:_themed_mad_strike | Wahnsinnige Gegner schlagen einander: Treffer + Flüstern | Impact | 3 | 3 | – | ~ (Treffer über `hit_*`) |
| G19 | `mob_in_medium` | hell_monsters:_step_medium, _medium_on_mob; hell_game:_step_mob_medium | Gegner brennt oder watet in Lava, Gift, Wasser | Enemy | 3 | 3 / 0,4 s | 3 | ✖ |
| G20 | `hazard_spikes` | hell_game:_update_hazards | Dornen schnellen hoch, Klinge | World | 2 | 2 | 3 | ✖ |
| G21 | `ice_trap` | hell_game:_draw_ice_trap, _draw_ice_burst (Eisriss, Eisausbruch) | Knacken in Ruhe, Ausbruch als Lawine | World | 2 | 2 | 3 | ✖ |
| G22 | `lava_bubble` | hell_game:_bubble_lava | einzelne Blasen platzen (Punktquelle) | Ambience | 4 | 4 / 0,2 s | ±12 %, 6 | ✖ (**L** burble_01–02) |
| G23 | `lava_slosh` | hell_game:_slosh_lava | Lava schwappt | Ambience | 4 | 2 | 4 | ✖ |
| G24 | `ember_float` | hell_game:_update_embers | leises Glutknistern in der Luft | Ambience | 4 | 1 Schleife | – | ✖ |

### H Partikel und Trümmer (`particles.gd`, `gas.gd`, `pool_paint.gd`, `snowstorm.gd`)

Regeln für alle: ein Klang **pro Aufruf**, nicht pro Teilchen; Lautstärke folgt der Menge; Landeticks nur mit Chance und Budget (§3.9). Bus Debris, wenn nicht anders genannt.

| # | Schlüssel | Auslöser | Klang | P | Stimmen / Abstand | Variation | Heute |
|---|---|---|---|---|---|---|---|
| H1 | `burst_debris` | particles:burst (mode debris) | kleine Steinsplitter prasseln | 3 | 3 / 0,05 s | ±10 %, 6 | ✖ |
| H2 | `burst_drops` | particles:burst (drop), drops | Tropfen prasseln (Blut, Gift, Wasser) | 3 | 3 / 0,05 s | ±10 %, 6 | ✖ |
| H3 | `burst_dust` | particles:burst (dust), dust_flat, kick | weicher Staub-Puff, flaches Zischen | 4 | 2 / 0,1 s | ±8 %, 4 | ✖ |
| H4 | `sparks` | particles:sparks, burst (spark) | feine Metallfunken-Ticks | 3 | 3 / 0,04 s | ±12 %, 6 | ✖ |
| H5 | `splat` | particles:splat, stain, splat_burst, wall_splat | nasser Klatsch am Boden oder an der Wand (je Material) | 3 | 3 / 0,06 s | ±8 %, 4 je Material | ✖ |
| H6 | `drip` | particles:drip (Tropfspur verwundeter Gegner) | winziges Tropfen | 4 | 2 / 0,4 s | ±15 %, 6 | ✖ |
| H7 | `wall_crack` | particles:crack | kleiner Riss im Stein | 3 | 2 / 0,08 s | 3 | ✖ |
| H8 | `rubble` | particles:rubble | Geröll rollt und bleibt hart liegen | 3 | 3 / 0,08 s | ±8 %, 5 | ✖ (**L** impact_mining_000–004) |
| H9 | `chips` | particles:chips | Knochen- und Steinsplitter ticken | 3 | 3 / 0,05 s | ±12 %, 6 | ✖ |
| H10 | `shatter` (+ `shard_break`, `shard_scratch`) | particles:shatter, _break_shard, _scratch | Eissplitter klirren, zerbrechen beim Landen, kratzen über den Boden | 3 | 3 / 0,05 s | ±10 %, 6 | ✖ (**L** impact_glass_*) |
| H11 | `rime_grow` (Schleife) | particles:frost, frost_clumps, rime_grow, _grow_rime | Rauhreif wächst knisternd | 4 | 1 Schleife | – | ✖ |
| H12 | `liquid_freeze` / `liquid_thaw` / `melt` | particles:freeze_liquids, thaw_liquids, _melt | Knistern beim Gefrieren; Knacken + Tropfen beim Tauen | 3 | 2 | 3 je | ✖ |
| H13 | `embers` | particles:embers, ember_sparks, _burn_embers, _cool | Glut knistert, kühlt mit feinem „Tink“ ab | 4 | 2 / 0,15 s | ±10 %, 4 | ✖ |
| H14 | `flames` / `fire_burst` | particles:flames, fire_burst | Flammen-Flattern; Feuer-Wumms | 3 | 2 | 3 | ~ (`fire_burst` nur über `blast` bei der Explosion) |
| H15 | `scorch_star` | particles:scorch_star | Brandstern brutzelt | 4 | 2 | 2 | ✖ |
| H16 | `steam` / `smoke` | particles:steam, smoke | Dampf zischt; Rauch: weicher Whoosh | 3 | 2 / 0,2 s | 3 je | ✖ |
| H17 | `snow_puff` | particles:snow | Schnee-Puff | 4 | 2 / 0,15 s | 4 | ✖ |
| H18 | `comet` + `land_splash` | particles:comet, _land_splash | Flug-Whoosh, kleiner Spritzer beim Aufkommen | 3 | 3 / 0,06 s | ±10 %, 4 | ✖ |
| H19 | `well` / `implode` | particles:well, implode, _suck | Sog-Brunnen, Implosion | 2 | 2 | 3 | ~ (Implosion nur über fx `void_burst`) |
| H20 | `motes` / `holy_motes` / `shadow` | particles:motes, holy, shadow | leiser Schimmer; heiliges Funkeln; dunkler Whoosh | 4 | 2 / 0,2 s | 4 | ✖ |
| H21 | `blow` | particles:blow | Böe bläst Gas und Teilchen fort | 3 | 1 | 3 | ✖ |
| H22 | `settle_tick` | particles:_settle (Stück bleibt liegen) | Landeticks je Material, Chance 20 % | 4 | 8 Stimmen im Debris-Bus, 14 Ticks/s gesamt | ±12 %, ±3 dB, 8 je Material | ✖ |
| H23 | `pool_spread` / `wet` | particles:_spread_pools, wet | Flüssigkeit breitet sich leise glucksend aus | 4 | 1 Schleife | – | ✖ |
| H24 | `floor_crack` | particles:floor_crack | Bodenriss breitet sich aus | 3 | 2 | 3 | ✖ |
| H25 | `gas_cloud_loop` | src/vfx/gas.gd (Wolken in Heldennähe) | Gas zischt leise; Giftgas blubbert | 4 | 2 Schleifen | – | ✖ |
| H26 | `pool_charge_loop` | pool_paint.gd (charge_pool, electrify) | knisterndes Netzbrummen über der Pfütze | 3 | 2 Schleifen | – | ✖ |
| H27 | `snowstorm_wind` (+ Böen) | src/vfx/snowstorm.gd (storm_every, gust_every, storm_ramp) | Wind wächst mit dem Sturm, Böen im Takt der Böen-Logik | 4 (Ambience) | 1 Schleife + 2 Böen | – | ✖ (nur das allgemeine Bett) |
| H28 | `wall_snow_puff` | src/hero/frost_wall_snow.gd, frost_snow.gd | Schnee rieselt von der Wand bei Kontakt | 4 | 2 / 0,3 s | 3 | ✖ |

### I Welt und Objekte (`hell_game.gd`)

| # | Schlüssel | Auslöser | Klang | Bus | P | Stimmen / Abstand | Variation | Heute |
|---|---|---|---|---|---|---|---|---|
| I1 | `gate_open` (Sätze je Welt: Holz, Eisen, Eis) | hell_game:act (Theme `gate_open`) | Krypta: Holztür · Hölle: Eisengitter rasselt hoch · Frost: Eistor knackt | World | 2 | 1 | 2 je | ~ (eine Holztür für alles) |
| I2 | `doors_lock` / `fight_start` | hell_game:_start_fight; feedback (Kampf beginnt) | schwere Türen schlagen zu + musikalischer Schlag | World | 2 | 1 | 2 | ~ (UI-Schloss) |
| I3 | `gate_locked` | hell_game:act (verschlossen) | Rütteln an Eisen, dumpfes Nein | World | 3 | 1 / 0,5 s | 2 | ~ (`doors_lock`) |
| I4 | `chest_open` | hell_game:act (chest); feedback chest_open | Riegel + Scharnier + Deckel + Münzen | World | 2 | 1 | 3 | ~ (nur ein Holzschlag) |
| I5 | `vault_open` NEU | hell_game:act (Tresortruhe der Hölle) | schweres Schloss, Gold-Kaskade | Focus | 1 | 1 | 1 | ✖ |
| I6 | `crate_break` | hell_game:_break_crate; feedback crate_break | Holz splittert | World | 2 | 2 | 5 | ✔ (+ zusätzlich `hit_bone`, prüfen) |
| I7 | `breakable_hit` / `breakable_break` NEU | hell_game:_hit_breakable (Krüge, Urnen, Fässer) | Ton zerspringt, Holz, Knochenurne | World | 2 | 2 | 3 je Art | ✖ |
| I8 | `seal_break` NEU | hell_game:_break_seal | magisches Siegel zerbricht | World | 2 | 1 | 2 | ✖ |
| I9 | `mimic_spring` | hell_game:_wake_mimic; feedback mimic_spring | Holz splittert + Schmatzen + Brüllen | Enemy | 1 | 1 | 2 | ~ (`attack_bite` + `attack_roar`) |
| I10 | `snowman_wake` NEU | hell_game:wake_snowman | Schnee bricht auf + Grollen | Enemy | 1 | 1 | 2 | ~ (`hit_bone`) |
| I11 | `secret_open` / `wall_break` | hell_game:_open_secret; feedback wall_break | Stein mahlt, Wand bricht, Geröll | World | 2 | 1 | 2 | ~ (`collapse_bone` + `break_bone`) |
| I12 | `plate` / `plate_wrong` | hell_game:_update_hazards (Druckplatten) | Steinplatte senkt sich mit „Klonk“; falsch: dumpfer Rückschlag | World | 2 | 1 | 3 / 2 | ~ (`ui_click` / `ui_back`) |
| I13 | `puzzle_solved` | hell_game:_solve_group | Mechanik rastet ein + kurzes Glockenmotiv | Focus | 1 | 1 | 2 | ~ (`regrow`) |
| I14 | `key_pickup` | hell_game:act (Theme `key`) | Schlüsselbund klimpert | World | 2 | 1 | 3 | ~ (`perk`) |
| I15 | `relic_pickup` | hell_game:act (Theme `relic`) | anschwellender Schimmer je Relikt | Focus | 2 | 1 | 2 | ~ (`perk`) |
| I16 | `stairs` (+ Schritte hinab) | hell_game:_open_stairs, choose_stairs | Stein mahlt auf, Schritte entfernen sich | World | 2 | 1 | 2 | ~ (Cembalo-Motiv) |
| I17 | `enemy_spawn` NEU | feedback (fx enemy_spawn); hell_game:_spawn_mob | Staub-Puff + Grollen beim Aufsteigen | Enemy | 2 | 3 / 0,1 s | 3 | ✖ |
| I18 | `drop_<kind>` NEU | hell_game:_drop (Gold, Herz, Schlüssel, Kugel fällt) | Aufkommen je Gegenstand | World | 3 | 3 / 0,05 s | 3 je | ✖ |
| I19 | `gold_burst` / `gold_pickup` NEU | hell_game:_burst (gold) | Münzen fächern auf; Aufsammeln klimpert | World | 3 | 2 / 0,05 s | ±6 %, 4 | ✖ (**L** handlecoins, handlecoins2) |
| I20 | `loot_taken` | feedback (fx loot_taken) | Beute aufgenommen, je Gegenstandsart | World | 2 | 2 | 3 | ~ (`perk`) |
| I21 | `torch_loop` NEU | Deko-Lichter (Fackeln, Becken) | knisternde Fackel als Punktquelle | Ambience | 4 | 4 Schleifen (die nächsten) | – | ✖ |
| I22 | `respawn` NEU | hell_game:_respawn | Rückkehr-Schimmer | Focus | 2 | 1 | 1 | ✖ |

### J Gegenstände (`src/hero/story_items.gd`, `feedback.gd`)

| # | Schlüssel | Auslöser | Klang | Bus | P | Stimmen / Abstand | Variation | Heute |
|---|---|---|---|---|---|---|---|---|
| J1 | `potion_break` | feedback (potion_throw) | Glas zerspringt + Flüssigkeit spritzt in der Trankfarbe | World | 2 | 2 | 4 | ~ (ruft das fehlende `potion_break` → `crate_break`) |
| J2 | `potion_blast` | feedback (potion_blast) | Explosion mit Glasregen | Impact | 2 | 2 | 3 | ~ (`blast`) |
| J3 | `drink` | feedback (drink) | Korken, Gluckern, Schlucken | Hero | 2 | 1 | 3 | ~ (ruft das fehlende `drink` → `perk`) |
| J4 | `curse` | feedback (curse) | dunkles, verzerrtes Anschwellen | Focus | 2 | 1 | 2 | ~ (`attack_roar`) |
| J5 | `cleanse` | feedback (cleanse) | heiliges Glöckchen + Chor | Hero | 2 | 1 | 2 | ~ (`room_clear`) |
| J6 | `identify` | feedback (identify) | Schimmer + kurzes Motiv | UI | 3 | 1 | 2 | ~ (`perk`) |
| J7 | `equip` / `unequip` NEU (Sätze: Metall, Leder, Stoff, Schmuck) | story_items (Ausrüsten) | Foley je Material | UI | 3 | 1 | 3 je | ✖ |
| J8 | `bag_full` / `item_drop` NEU | story_items | dumpfes „voll“; Gegenstand fällt | UI | 3 | 1 | 2 | ✖ |
| J9 | `inventory_open` / `_close` NEU | src/ui/inventory_panel.gd (Taste I) | Tasche, Leder | UI | 3 | 1 | 2 | ✖ (**L** clothbelt, bookopen) |
| J10 | `throw_arm` NEU | hell_game (throw_slot gesetzt) | Trank wird gezogen | UI | 3 | 1 | 2 | ✖ |

### K Bedienoberfläche und HUD

| # | Schlüssel | Auslöser | Klang | Bus | P | Heute |
|---|---|---|---|---|---|---|
| K1 | `ui_click` | Menüs | Klick | UI | 3 | ✔ |
| K2 | `ui_back` | Menüs | Zurück | UI | 3 | ✔ |
| K3 | `ui_hover` NEU | Menüs (Maus über Knopf) | sehr leiser Tick, 0,05 s | UI | 4 | ✖ |
| K4 | `talent_open` / `talent_learn` / `talent_refund` NEU | src/ui/talent_screen.gd; hell_game:open_run_talents | Buch auf, Rune leuchtet auf, Rune erlischt | UI | 3 | ✖ (**L** bookopen, bookflip) |
| K5 | `skill_ready` NEU | src/ui/skill_bar.gd (Abklingzeit vorbei) | sehr leises Glöckchen, nur bei Ultimate und langen Abklingzeiten | UI | 3 | ✖ |
| K6 | `toast` NEU | hell_game:_toast | weicher Hinweiston | UI | 4 | ✖ |
| K7 | `map_open` NEU | hell_game:_draw_map (große Karte) | Pergament | UI | 3 | ✖ |
| K8 | `pause_open` / `_close` NEU | hell_game:open_pause | dumpfes Abtauchen (zusammen mit dem Pause-Filter, §3.7) | UI | 3 | ✖ |
| K9 | `save_ok` NEU | hell_game:save_slot | kurzer Bestätigungston | UI | 3 | ✖ |
| K10 | `stairs_pick` / `run_tree` NEU | hell_game:choose_stairs; src/ui/run_tree_view.gd | Auswahl-Klang | UI | 3 | ✖ |

### L Musik und Stinger (`src/audio/music.gd`, `audio_music.json`)

| # | Schlüssel | Auslöser | Klang | Bus | P | Heute |
|---|---|---|---|---|---|---|
| L1 | `menu` | music.gd decide (menu) | Titelmusik | Music | 4 | ~ (die Ambience `dungeon_ambience` dient als Musik) |
| L2 | `explore` (Sätze je Welt) | decide (explore) | ruhige Schicht, Welt-Farbe (§1.2) | Music | 4 | ~ (ein Track für alle Welten) |
| L3 | `combat` (Sätze je Welt) | decide (combat) | Kampfschicht über der Erkunden-Schicht | Music | 3 | ~ (`heavy_dungeon` für alle) |
| L4 | `boss` (Sätze je Welt) | decide (boss) | eigener Boss-Track je Welt | Music | 3 | ~ (`heavy_boss_battle_1` für alle) |
| L5 | `stinger_fight_start` | hell_game:_start_fight | musikalischer Schlag beim Kampfbeginn | Focus | 2 | ~ (`doors_lock`) |
| L6 | `room_clear` | feedback (combat → reward) | positives Motiv | Focus | 2 | ✔ |
| L7 | `team_wipe` | feedback (dead) | Niederlage | Focus | 1 | ✔ |
| L8 | Stems und Übergänge NEU | music.gd (_enter, calm_hold) | Erkunden und Kampf als synchrone Schichten, taktgenaue Wechsel | Music | – | ✖ |
| L9 | Low-HP-Filter NEU | hp_f() < 30 % | Musik wird dumpf (Tiefpass), Herzschlag drüber | Music | 1 | ✖ |
| L10 | Wahn-Färbung NEU | hell_game:_void_mind | Phaser + Tiefpass auf der Musik | Music | 3 | ✖ |

### M Ambience je Welt

| # | Schlüssel | Auslöser | Klang | Bus | P | Heute |
|---|---|---|---|---|---|---|
| M1 | `amb_bed_krypta` | Welt = Krypta | Steinraumton, Tropfen, Luftzug | Ambience | 4 | ~ (`dungeon_wind_drips` passt nur hier) |
| M2 | `amb_bed_frost` NEU | Welt = Frostgruft | Windbett, Eis-Knarzen | Ambience | 4 | ✖ |
| M3 | `amb_bed_hell` NEU | Welt = Hölle | Sub-Grollen, Feuerrauschen | Ambience | 4 | ✖ |
| M4 | `amb_drip` NEU (Punktquellen) | zufällig, 3–9 s, Krypta und Frost (Schmelzwasser) | einzelne Tropfen mit Hall, an zufälligen Orten im Raum | Ambience | 4 | ✖ (nur im Bett eingebacken) |
| M5 | `amb_ice_creak` NEU | zufällig, 8–20 s, Frostgruft | Eis knarzt, ferner Gletscherriss | Ambience | 4 | ✖ |
| M6 | `amb_far_hell` NEU | zufällig, 15–40 s, Hölle | ferne Ketten, ferne Schreie | Ambience | 4 | ✖ |
| M7 | `amb_lava_rumble` NEU (Punktquellen) | Lava-Kacheln in Heldennähe | tiefes Lava-Grollen | Ambience | 4 | ✖ |
| M8 | `amb_room_tone` NEU (Sätze: klein, mittel, Arena) | hell_game:_update_rooms (Raumgröße) | Raumton passend zur Größe | Ambience | 4 | ✖ |
| M9 | `amb_bone_settle` NEU | zufällig, 10–30 s, Krypta | fernes Knochenrieseln | Ambience | 4 | ✖ |

### Summe der Matrix

| Abschnitt | Zeilen | ✔ passt | ~ geliehen / unpassend | ✖ fehlt |
|---|---|---|---|---|
| A Held | 33 | 2 | 12 | 19 |
| B Talente, Ultimates | 30 | 0 | 0 | 30 |
| C Begleiter | 10 | 0 | 0 | 10 |
| D Gegner (D2 + D3) | 38 | 5 | 23 | 10 |
| E Bosse | 11 | 1 | 7 | 3 |
| F Element-Reaktionen | 13 | 0 | 2 | 11 |
| G Zonen, Gefahren | 24 | 0 | 7 | 17 |
| H Partikel, Trümmer | 28 | 0 | 2 | 26 |
| I Welt, Objekte | 22 | 1 | 13 | 8 |
| J Gegenstände | 10 | 0 | 6 | 4 |
| K Bedienoberfläche | 10 | 2 | 0 | 8 |
| L Musik, Stinger | 10 | 2 | 5 | 3 |
| M Ambience | 9 | 0 | 1 | 8 |
| **Gesamt** | **248** | **13** | **78** | **157** |

Mit den Sätzen (Stimmen, Böden, Elemente, Materialien, Welten) sind das rund **350 neue Ereignis-Schlüssel**. Von den 52 vorhandenen Ereignissen bleiben fast alle als Grund- oder Rückfallklang erhalten.

---

## 3 Mix-Plan

> Godot-Hinweis: Alle hier genannten Klassen und Eigenschaften (AudioStreamPlayer2D `max_distance` / `attenuation` / `panning_strength` / `max_polyphony`, AudioListener2D, AudioEffectReverb, AudioEffectLowPassFilter, AudioEffectCompressor `sidechain`, AudioEffectPhaser, AudioStreamRandomizer, AudioStreamSynchronized, AudioStreamInteractive) müssen vor der Umsetzung gegen `docs/engine-reference/godot/` (Godot 4.7.2) geprüft werden. Der Audio Director schreibt keinen Engine-Code.

### 3.1 Bus-Baum

Heute: Master ← Music (−7), Ambience (−12), SFX (0) ← Focus (0), UI (−3). Neu (in `audio_mix.json`, angelegt von `audio_mix.gd`):

```
Master  (HardLimiter, Decke −1 dB)
├─ Music      −7 dB   [Duck: Focus −6 dB, Boss −3 dB, Ultimate −4 dB] [Tiefpass: Low-HP, Gas, Wahn, Pause] [Phaser: Wahn]
├─ Ambience  −12 dB   [Duck: Focus −6 dB] [Tiefpass: Gas, Pause]  (Bett + Punktquellen; Raum steckt in der Aufnahme)
├─ SFX         0 dB   [EQ: Hochpass 30 Hz] [Bus-Kompressor sanft 2:1, Schwelle −14 dB]
│  ├─ Focus    0 dB   eigener Treffer, Low-HP, Stinger, P1-Ansagen – nie gefiltert, wenig Hall (wet 0,05)
│  ├─ Voices  −2 dB   Helden-, Begleiter-, Boss-Stimmen – Kompressor 3:1, Hall wet 0,08–0,10
│  └─ Room     0 dB   [Welt-Hall: Reverb dry 1,0 / wet je Welt] [Tiefpass: Gas, Pause] [Duck: Focus −3 dB]
│     ├─ Hero    −3 dB   eigene Angriffe, Talente, Begleiter-Fähigkeiten (−6 dB per Kategorie)
│     ├─ Boss    −2 dB   Boss-Angriffe, Landungen (auch Duck-Schlüssel)
│     ├─ Enemy   −6 dB   [Duck: Boss −3 dB]
│     ├─ Impact  −4 dB
│     ├─ World   −7 dB
│     ├─ Step   −13 dB   [Duck: Voices −3 dB]
│     ├─ Idle   −15 dB   [Duck: Boss −3 dB]
│     ├─ Debris −14 dB   [Kompressor 4:1, Schwelle −26 dB, Attack 1 ms, Release 120 ms] [Tiefpass 9 kHz] [Duck: Focus −6, Boss −3, Voices −3]
│     └─ Far     −3 dB   [Tiefpass 3,5 kHz, Hall wet +0,10] – alles weiter als 8 Kacheln vom Helden
└─ UI         −3 dB
```

Kategorien → Busse: focus, stinger → Focus · voice (NEU) → Voices · hero → Hero · ally → Hero (−7 dB) · pet (NEU) → Hero (−6 dB) · boss → Boss · enemy → Enemy · impact → Impact · world → World · step → Step · idle → Idle · debris (NEU) → Debris · amb_point (NEU) → Ambience · ui → UI.

Ein Godot-Bus hat genau ein Sendeziel. Darum hängen Hero bis Far unter `Room` (der die Welt-Hall-Einfügung trägt), Focus und Voices bekommen eigene, kleinere Hall-Einfügungen. Mehrere Duck-Schlüssel auf einem Bus = mehrere Kompressoren hintereinander, jeder mit eigener `sidechain`.

### 3.2 Räume: Hall je Welt

Eine AudioEffectReverb auf `Room` (dry 1,0, wet wie unten), dazu kleinere auf Focus und Voices. Die Werte stehen als `spaces` in `audio_mix.json`, die Welt schaltet sie beim Laden um.

| Parameter | Krypta | Frostgruft | Hölle |
|---|---|---|---|
| room_size | 0,55 | 0,75 | 0,90 |
| damping | 0,65 | 0,15 | 0,75 |
| spread | 0,8 | 1,0 | 0,9 |
| hipass | 0,15 | 0,25 | 0,05 |
| predelay_msec | 20 | 40 | 55 |
| predelay_feedback | 0,25 | 0,35 | 0,30 |
| wet auf Room | 0,20 | 0,24 | 0,22 |
| wet auf Voices | 0,08 | 0,10 | 0,10 |
| wet auf Focus | 0,05 | 0,06 | 0,06 |

Je Raum: `room_size` +0,10 in Boss-Arenen, −0,15 in Gängen und kleinen Räumen (Fläche aus `W.rooms`). Beim Raumwechsel (hell_game:_update_rooms) gleitet der Wert in 0,5 s. Hölle zusätzlich: ein schwacher Chorus auf Ambience (Hitzeflimmern).

### 3.3 Lautheit

**Ziel im Spiel (PC):** −16 LUFS integriert (±1) über eine 10-Minuten-Sitzung mit Kämpfen, True Peak ≤ −1 dBTP, Loudness Range 8–12 LU. Erkunden soll leiser sein als der Boss – das macht den Mix lebendig statt flach. Erkunden allein: −20 bis −18 LUFS-S.

**Dateien (vom sound-designer pegeln, gemessen in LUFS statt wie heute in mittleren dBFS):**

| Kategorie | Format | Kanäle | Rate | Länge | Ziel-Lautheit der Datei |
|---|---|---|---|---|---|
| SFX-Einzelklang | OGG Vorbis q5 | mono | 44,1 kHz | ≤ 2 s (Boss ≤ 4 s) | −16 LUFS-M max., TP −1 dBTP |
| Stimmen | OGG q6 | mono | 44,1 kHz | ≤ 1,5 s | −16 LUFS-M max. |
| SFX-Schleifen | OGG q5 | mono | 44,1 kHz | 2–8 s, nahtlos | −22 LUFS-I |
| Ambience-Bett | OGG q5 | stereo | 44,1 kHz | 60–180 s, nahtlos | −26 LUFS-I |
| Musik, Stems | OGG q6 | stereo | 44,1 kHz | taktgenaue Schleifen | −18 LUFS-I |
| Stinger | OGG q6 | stereo | 44,1 kHz | ≤ 6 s | −16 LUFS-M max. |
| UI | OGG q5 | mono | 44,1 kHz | ≤ 0,5 s | −20 LUFS-M max. |

**Ziele im Mix (im Spiel gemessen, kurzzeitig):** eigener Treffer −10 LUFS-M · Heldenstimme −14 · Boss-Gebrüll −11 · eigene Angriffe −16 · Treffer an Gegnern −17 · nahe Gegnerangriffe −18, ferne −26 · Schritte −28 · Trümmer-Ticks −32 bis −30 · UI −20 · Musik −22 (Erkunden) / −20 (Kampf) · Ambience −30 bis −27.

Werkzeug: `scripts/prepare_audio_library.js` misst heute „mean_db“. Es soll LUFS-M, LUFS-I und True Peak messen und `gain_db` daraus setzen (tools-programmer).

Dateinamen für neue Dateien: `[kategorie]_[kontext]_[name]_[variante].ogg`, z. B. `vo_hero_elf_f_hurt_01.ogg`, `sfx_elem_ice_crack_03.ogg`, `sfx_mob_beast_kill_02.ogg`, `sfx_debris_stone_tick_07.ogg`, `amb_frost_wind_loop.ogg`, `mus_hell_combat_drums_loop.ogg`.

### 3.4 Prioritäten und Ducking

| P | Bedeutung | Beispiele | Regel |
|---|---|---|---|
| 1 | muss man hören | eigener Treffer, eigener Tod, Low-HP, Boss-Ansagen, Ultimates, Stinger | ohne Position, eigene Stimmenreserve, wird nie gestohlen |
| 2 | Spiel-Information | eigene Angriffe, Gegner-Ansagen und -Angriffe, Treffer, Tode, Reaktionen | an der Position; Ansagen außerhalb des Bildes nie leiser als −9 dB |
| 3 | Rückmeldung | Schritte, Aufsammeln, Status-Ticks, Pfützen, Trümmer | an der Position, darf gestohlen werden |
| 4 | Bett | Leerlauf, Ambience-Punkte, Partikel-Ticks | stiehlt nie, wird bei Platzmangel verworfen |

| Auslöser (Schlüssel-Bus) | duckt | Tiefe | Attack / Release |
|---|---|---|---|
| Focus (eigener Treffer, Low-HP, Stinger) | Music, Ambience | −6 dB | 2 ms / 450 ms (heute: Schwelle −30 dB, Ratio 6) |
| Focus | Room (alle Welt-SFX) | −3 dB | 1 ms / 250 ms |
| Focus | Debris | −6 dB | 1 ms / 300 ms |
| Boss (Gebrüll, große Ansagen, Landungen) | Enemy, Idle, Debris | −3 dB | 5 ms / 400 ms |
| Boss | Music | −3 dB | 10 ms / 600 ms |
| Voices (Heldenstimme) | Step, Debris | −3 dB | 2 ms / 200 ms |
| Ultimate (Focus über Schwelle) | Music | −4 dB | 10 ms / 800 ms |
| Boss-Auftritt, Urknall, Boss-Tod | alles außer Focus | 0,3 s Stille davor | gesteuert, nicht per Kompressor |

Hitstop (feedback.gd, game-feel): Der Klang startet im Treffer-Frame und wird nie bis zum Ende des Hitstops verzögert.

### 3.5 Raumklang (2D)

- **Ohne Position** (Mitte): P1, UI, Musik, Ambience-Bett, die eigenen Angriffe, Stimme und Schritte des Helden.
- **Mit Position:** alles andere, über einen Pool aus `AudioStreamPlayer2D` mit einem `AudioListener2D` am Helden. Weil die Kamera dem Helden folgt, entspricht das Links/Rechts der Bildschirm-x-Lage.
- **Entfernungen** (Weltpixel, 1 Kachel = 96 px): volle Lautstärke bis 2 Kacheln; `max_distance` 14 Kacheln (1344 px); `attenuation` 1,6. Bosse × 1,5 (21 Kacheln), Trümmer 9 Kacheln, Leerlauf 8, Gegnerschritte 6.
- **Panorama:** `panning_strength` 0,5 – nie hart links oder rechts (Pixel-Look, ermüdet sonst mit Kopfhörern). Gegner-Ansagen außerhalb des Bildes: volle Seite, mindestens −9 dB, damit man weiß, woher es kommt.
- **Tiefe:** Klänge weiter als 8 Kacheln spielen auf dem Far-Bus (dumpfer, halliger). Das ist der wichtigste Hebel gegen „trocken“.
- **Achtung Koordinaten:** `feedback.gd` rechnet in Krypta-Pixeln (Weltpixel / `feel.scale`). Eine neue Abspiel-Funktion `play_at(name, world_pos, context)` in `sfx.gd` braucht Weltpixel; `story_feel.gd` rechnet um.

### 3.6 Stimmen-Pool und Stehlen

- 40 Stimmen statt 24: 8 nur für P1 reserviert, 32 geteilt.
- Obergrenzen je Bus: Debris 8, Step 4, Idle 3, Enemy 10, Impact 8, World 6, Voices 4 (Heldenstimme 1: ein neuer Schmerzlaut ersetzt den alten nur, wenn er schwerer ist), Boss 4, Hero 6.
- Je Ereignis: `max_voices` (Vorgabe 3), `min_interval` (gibt es schon), `chance` (Wahrscheinlichkeit).
- Wenn keine Stimme frei ist, in dieser Reihenfolge stehlen: (1) die Stimme mit der niedrigsten Priorität unter der neuen, (2) bei gleicher Priorität die fernste bzw. leiseste, (3) die älteste. P1 wird nie gestohlen, P4 stiehlt nie.
- Schleifen (Zonen, Gas, Ladung, Waten, Rutschen, Fackeln): höchstens 6 gleichzeitig, die nächsten gewinnen, Ein- und Ausblenden 0,2 s.
- Godot bietet `AudioStreamRandomizer` (zufällige Variante, Tonhöhe, Lautstärke, keine Wiederholung) und `max_polyphony`; beides kann die eigene Variantenwahl in `sfx.gd` ersetzen – Entscheidung der Programmierung.

### 3.7 Filter: Gas, Dampf, Wahn, Pause

Eine Quelle für Sehen und Hören: Der Wert, mit dem `hell_game:_ease_vision` die Sicht verschleiert, steuert auch die Grenzfrequenz. **Was man nicht sieht, hört man dumpf.**

| Zustand | Quelle | Filter | Busse | Rampe |
|---|---|---|---|---|
| Held im Dampf | hero_gas (steam), _ease_vision | Tiefpass 2200 Hz, Resonanz 0,6 | Room, Ambience; Music 4000 Hz | 0,25 s rein / 0,6 s raus |
| Held im Giftgas | hero_gas (poison) | Tiefpass 1500 Hz + `vo_cough` | Room, Ambience; Music 3000 Hz | wie oben |
| Wahn (Leere) | _void_mind | Tiefpass 1200 Hz + Phaser auf Music, `mad_whisper` | Music, Ambience | 0,4 s |
| Low-HP unter 30 % | hp_f() | Tiefpass 1800 Hz auf Music, Herzschlag auf Focus | Music | 1 s |
| Pause, Inventar, Talentmenü | open_pause, inventory_panel, talent_screen | Tiefpass 800 Hz, −6 dB | Room, Ambience, Music | 0,2 s |

Focus und UI werden **nie** gefiltert – der eigene Treffer bleibt auch im Gas klar.

### 3.8 Dynamische Musik

- **Je Welt** eine Erkunden-Schicht und eine Kampf-Schicht als synchrone Stems (gleiches Tempo, gleiche Tonart), dazu ein eigener Boss-Track mit Intro und Schleife.
- Vorschlag: Krypta 80–90 BPM, d-Moll · Frostgruft 70–80 BPM, e-Moll mit Glocken · Hölle 140–160 BPM, c-Moll phrygisch (die vorhandenen `heavy_dungeon` 160 BPM und `heavy_boss_battle_1` 200 BPM passen zur Hölle, `determined_pursuit` ist ungenutzt).
- Zustände bleiben `music.gd decide`: menu, explore, combat, boss. Kampf → Erkunden: Die Kampf-Schicht blendet nach `calm_hold` (6 s) in 3 s aus, die Erkunden-Schicht läuft weiter (kein harter Wechsel).
- **Stinger je Welt (8):** fight_start, room_clear, boss_intro, boss_phase, boss_defeated, level_up, run_won, team_wipe. Auf den nächsten Schlag quantisiert (höchstens 250 ms warten), außer boss_intro und team_wipe (sofort).
- Umsetzung: `AudioStreamSynchronized` für die Stems und `AudioStreamInteractive` für die Übergänge (ab Godot 4.3, gegen die Engine-Referenz prüfen). Rückfall: zwei gleichzeitig gestartete Player in `music.gd`, nur die Lautstärke wird geschichtet.

### 3.9 Partikel und Trümmer – Klang ohne Maschinengewehr

1. **Ein Klang pro Aufruf**, nicht pro Teilchen (burst, shatter, rubble …).
2. **Menge → Lautstärke:** vol_db = Basis + 4 · log2(Anzahl / 8), begrenzt auf −6 … +3 dB. Große Stücke tiefer.
3. **Landeticks** (particles:_settle): Chance 20 % bei Knochen, Stein, Eis, 15 % bei Flüssigkeit; höchstens 8 Stimmen auf Debris, insgesamt 14 Ticks/s, `min_interval` 0,04 s je Ereignis, ±12 % Tonhöhe, ±3 dB.
4. **Bündeln:** Wollen in 100 ms mehr als 6 Ticks spielen, spielt stattdessen ein „Prassel“-Klang.
5. **Ausblenden:** P4 außerhalb des Bildes und weiter als 9 Kacheln wird gar nicht erst gestartet.
6. **Flächen als Schleife:** Rauhreif, sich ausbreitende Pfützen und Gas bekommen je Art eine gemeinsame Schleife in Heldennähe; ihre Lautstärke folgt der Menge in der Nähe.
7. Partikel spielen **nie** auf Focus, immer auf Debris: Der Kompressor dort klebt sie zu einem Bett zusammen.

---

## 4 Umsetzung

### 4.1 Schritt S – sofort hörbar besser (klein, ≈ 2–4 Tage, vor allem Daten)

1. **Lizenz `pixel_combat` klären** oder Ersatz einplanen (Producer + Audio Director). Blocker für jede Veröffentlichung.
2. **Bibliothek verdrahten** (nur `audio_sfx.json`): Schnee-Schritte für die Frostgruft (footstep_snow), das fehlende `frost` aus impact_glass_*, `potion_break` aus impact_glass_heavy, Höllenhund aus barking_01–02, Schleime aus slime_01–08, Wolf `howl`, Bär roar_01–03, Irrwisch cute_01–10, Gold handlecoins, Husten cough_01–03, Lava und Kessel burble_01–02, Archivar bookflip1–3, Geröll impact_mining_*, Heiliges impact_bell_heavy_*, Tore creak1–3 + doorclose_*.
3. **`rig_materials` berichtigen** (golem, ice_crystal, frost_imp, ice_slime*, eiszombie / ice_zombie, snowman) und die ersten neuen Materialien (ice, slime, beast, ghost) mit Bibliotheksdateien anlegen.
4. **Heldenstimmen:** `voice_of` + Stimmsätze in `sfx.gd` (kleine Code-Änderung: Satz nach Sprite wählen). Mindestens 15 Dateien je Held, **die Bogenschützin zuerst**.
5. **Todeslaut-Garantie:** Jede Monster-id steht in `rig_materials`; der Rückfall `kill` ist eine echte Datei statt eines Piepsers.
6. **Synth-Piepser ersetzen** (shoot, hit, kill, windup, boss_hit, enemy_shoot) durch echte Dateien.
7. **Doppel-Auslösungen prüfen** (hurt, Heldenschuss) und den Nekromanten-Schuss reparieren (`shoot_necro`).
8. **Ansage-Rückfall:** Geriggte Figuren ohne `windup_<kind>` bekommen ein kurzes `windup_generic` (Einatmen / Scharren).

*Abnahme S:* kein Piepser mehr in den Story-Welten · die Bogenschützin stöhnt mit einer Frauenstimme · jeder Gegnertod ist hörbar und passt zum Material · in der Frostgruft knirscht der Schnee.

### 4.2 Schritt M – Raum und Ordnung (mittel, ≈ 1–2 Wochen)

1. `sfx.gd`: `play_at(name, world_pos, context)`, Pool aus AudioStreamPlayer2D, AudioListener2D am Helden; `feedback.gd` und `story_sound.gd` geben Positionen weiter.
2. Prioritäten, Stimmen-Pool, Obergrenzen, Stehl-Regeln, `max_voices`, `chance` (§3.6).
3. Bus-Baum, Welt-Hall (`spaces`), Duck-Ketten, Gas-/Dampf-Tiefpass an `_ease_vision` (§3.1–3.7).
4. Element-Sätze: `attack_<kind>` und `windup_<kind>` mit `set_by: element`; die Zeilen D3, F und G.
5. Talent-Hooks: `talent_combat.gd` meldet `sound_events` (kind, element, pos, owner – wie die fx events) an feedback/sfx. Zuerst B1–B13, B28, B29.
6. Begleiter-Sätze C1–C8.
7. Ambience-Betten je Welt + Punktquellen (Lava, Tropfen, Fackeln), Kopplung an `snowstorm.gd` (M1–M9, H27, G22–G24).

*Abnahme M:* ein Gegner links klingt links · ein Gegner am Rand ist leiser und halliger · die drei Welten sind blind am Klang erkennbar (5-s-Hörprobe) · jeder Angriff hat eine Ansage · jedes Talent klingt.

### 4.3 Schritt L – alles, was sich bewegt, klingt (groß, ≈ 2–4 Wochen)

1. Partikel- und Trümmer-Klang (Abschnitt H) mit Ticks, Bündeln und Budgets (§3.9).
2. Die 12 Ultimates dreiteilig, die Singularität mit Stille davor; Boss-Signaturen je Boss (E), Ignaroths Formen, das Ende des Herrschers.
3. Dynamische Musik je Welt (Stems, 8 Stinger je Welt, quantisiert).
4. LUFS-Messung im Werkzeug; Mix-Abnahme mit Messprotokoll und Aufnahme in `production/qa/evidence/`.
5. Klangwerkstatt (`src/ui/sound_workshop.gd`) erweitern: Sätze (Stimme, Boden, Element, Material, Welt), Priorität, Position, Busse und Hall live hören.

*Abnahme L:* 10-Minuten-Sitzung bei −16 LUFS ±1, TP ≤ −1 dBTP, LRA 8–12 LU · jede Matrixzeile im Testraum geprüft und auf ✔ gesetzt.

### 4.4 Vorschlag Datenformat (`audio_sfx.json`, schema_version 3)

Neue Felder je Ereignis (alle optional, die heutigen bleiben gültig): `priority` (1–4), `positional` (bool), `max_distance` (px), `max_voices`, `chance` (0–1), `vol_spread_db`, `loop` (bool), `set_by` („voice“, „surface“, „element“, „material“, „spec“, „world“), `sets` (Satzname → Dateiliste), `fallback_set`, `coat_layer`. Neue Blöcke: `voice_of` (Sprite → Stimmsatz), `rig_materials` als Objekt (mat, coat, size).

```json
{
  "schema_version": 3,
  "voice_of": {"knight_m": "knight_m", "elf_f": "elf_f", "wizzard_m": "wizard_m", "custom_pyromancer": "wizard_m", "necromancer": "necro_m"},
  "rig_materials": {
    "glutschaedel": {"mat": "bone", "coat": "fire", "size": "small"},
    "golem": {"mat": "stone", "coat": "frost", "size": "big"},
    "skelett": {"mat": "bone"}
  },
  "events": {
    "vo_hurt": {
      "label": "Schmerzlaut des Helden",
      "category": "voice",
      "priority": 1,
      "positional": false,
      "set_by": "voice",
      "sets": {
        "elf_f": ["res://assets/audio/sfx/vo/vo_hero_elf_f_hurt_01.ogg"],
        "knight_m": ["res://assets/audio/sfx/vo/vo_hero_knight_m_hurt_01.ogg"]
      },
      "fallback_set": "knight_m",
      "spread": 0.03,
      "vol_spread_db": 1.0,
      "min_interval": 0.35,
      "max_voices": 1
    },
    "hit": {
      "label": "Treffer am Gegner",
      "category": "impact",
      "priority": 2,
      "positional": true,
      "set_by": "material",
      "sets": {"bone": [], "ice": []},
      "coat_layer": "coat_{coat}_hit",
      "max_voices": 4,
      "min_interval": 0.04
    }
  }
}
```

`audio_mix.json` (schema_version 2): `buses` mit `effects`, `spaces` (Hall je Welt, §3.2), `filters` (§3.7), `ducks` als Liste, `voice_pool` (Größe, P1-Reserve, Obergrenzen). `audio_music.json` (schema_version 2): `worlds` → krypta / frost / hell mit explore, combat, boss, ambience, stingers.

### 4.5 Offene Entscheidungen

Diese Punkte entscheidet der Nutzer. Meine Empfehlung ist markiert.

1. **Raumklang**
   - *2D-Player + Hörer am Helden (empfohlen):* Godot rechnet Abstand und Links/Rechts selbst; wenig Code, sauber. Kostet einen Umbau von `sfx.gd`.
   - *Eigene Rechnung:* Lautstärke und Panorama selbst ausrechnen, über Panner-Busse; volle Kontrolle, aber mehr Code und Busse.
   - *Mono lassen:* kein Aufwand, aber der Mix bleibt flach – widerspricht dem Ziel.
2. **Heldenstimmen**
   - *CC0-/lizenzfreie Sprecheraufnahmen, eine Stimme je Held (empfohlen):* schnell, passt zum Aussehen; die Auswahl muss zu den vier Profilen in §1.4 passen.
   - *Eigene Aufnahmen:* genau passend und einmalig, aber Aufwand (Mikrofon, Sprecher, Schnitt).
   - *Nur Atmer, keine Schreie:* einfacher zu finden, wirkt aber dünner.
3. **Musik je Welt**
   - *Je Welt eigene Erkunden- und Kampf-Stems + eigener Boss (empfohlen):* stärkste Weltidentität; braucht 9 Musikstücke.
   - *Ein gemeinsamer Satz, die Ambience färbt die Welt:* günstiger, Welten weniger unterscheidbar.
   - *Wie heute:* kein Aufwand, die Frostgruft klingt weiter nach Metal-Hölle.
4. **Dichte der Partikel-Klänge**
   - *Sparsames Bett: ein Klang pro Ausbruch + 20 % Landeticks (empfohlen):* „alles klingt“, ohne Matsch.
   - *Dicht: jedes größere Stück tickt:* sehr körperlich, Gefahr von Brei und Ermüdung.
   - *Nur große Trümmer:* ruhig, aber die kleinen Partikel bleiben stumm – verfehlt den Wunsch „wirklich jedes Partikel“.

### 4.6 Klang-Bedarf aus neuen Paketen (für die Recherche)

Bevorzugt CC0; sonst eine Lizenz, die kommerzielle Spiele erlaubt, mit Quelle in `audio_library.json` dokumentiert. Suchorte: OpenGameArt, Kenney, Freesound (Filter CC0), Sonniss GDC Game Audio Bundles (lizenzfrei, Lizenztext prüfen), itch.io (Lizenz je Paket prüfen). Die Zahlen sind Varianten (Dateien).

| # | Gruppe | Klangtypen (Anzahl) | Summe | Schritt |
|---|---|---|---|---|
| 1 | **Heldenstimmen** – 4 Profile: **elf_f weiblich**, jung und agil · knight_m männlich, tief · wizard_m männlich, mittel und älter · necro_m männlich, heiser. Nur Laute, keine Wörter. | je Profil: Schmerz leicht 8, Schmerz schwer 4, Tod 3, Anstrengung 6, Ausweichen/Blocken 4, Husten 3, Brennen 2, Sturz 2, Stufenaufstieg/Sieg 3, Kampfschrei 2 (= 37) | 148 | S (15 je Profil), Rest M |
| 2 | Schritte und Foley | Glatteis 8, Pfütze 8, Asche/Kies 8, Plattenrüstung 6, Leder + Köcher 6, Pfoten 6, schwere Stampfer 6, kleine Flügel 6, große Flügel 6, Schleim-Gleiten 4, schleifende Kette (Schleife) 2, Robe 4 | 70 | S (Glatteis, Pfütze, Asche), Rest M |
| 3 | Kreaturen | Höllenhund-Knurren 6, Imp-Kichern 8, Fledermaus-Quieken 6, Geister-Klagen 10, Banshee-Schrei 2, Drachengebrüll 6, Drache einatmen 3, Golem-Grollen 4, **weibliches Monster-Klagen (Grabmutter) 4**, Beschwörer-Singsang und Flüstern 8, Falkenschrei 4, Wolf-Jaulen und -Winseln 4, Bär Schmerz/Tod 3, Feuerkreatur-Knurren 4, Wasserwesen 4, Schädel-Klappern 4, allgemeine Todeslaute 6 | 86 | M |
| 4 | Elemente | Feuer-Wumms 6, Feuer-Schleife 2, Knistern 6, Flammenwerfer-Schleife 2, Lavablasen 8, Lavaspritzer 6, Brutzeln 6, Eis-Knacken 8, Eis-Klirren 8, Frostwind-Schleife 2, Rauhreif-Schleife 2, Wasserspritzer 8, Dampfstoß 6, Dampf-Schleife 2, Säureblasen 6, Sprudeln 4, Gas-Schleife 2, Gasexplosion 4, Leere-Sog 6, Implosion 4, Rückwärts-Anschwellen 4, Blitz-Knall 6, Strom-Schleife 2, kleiner Zap 8, heiliger Chor 3, Heil-Glöckchen 4, Blutklatsch 8, Schmatzen 6, Tropfen 8, Münzen fächern auf 4, Münz-Klink 8, Seelen-Whoosh 6, Fluch-Anschwellen 3 | 168 | M |
| 5 | Einschläge und Trümmer | Geröll 10, Steinriss / Mahlen 6, Kiesel-Ticks 12, Holzsplitter 6, Ton-/Urnenbruch 6, kleine Glas-Ticks 8, Körperfall 4, Wandaufprall 4, Druckwelle 4, Beben-Grollen 4, Meteor-Pfeifen 4, Meteor-Einschlag 4, Pfeil in Stein 4, Metall-/Schild-Klirren 6, Eissplitter-Kratzen 4 | 86 | M (Geröll, Glas in S aus der Bibliothek) |
| 6 | Waffen und Magie | Bogensehne 6, Pfeil-Whoosh 6, Zauber je Element 7 × 4 = 28, Strahl-Schleifen 3, Barriere-Summen 1 + Treffer 4 + Bruch 2, Abrollen 4, Falle Setzen/Schärfen/Zuschnappen 6, Netz 3, Kettenpeitsche 4, schweres Schwert 4, Klingen-„Sching“ 4, Ultimate-Aufbau 12 | 87 | S (Bogensehne), Rest M/L |
| 7 | Welt | Eisengitter 3, Steintür mahlt 3, Druckplatte 4, Mechanik/Rätsel gelöst 3, Schlüsselbund 3, Tresor öffnen 1 + Gold-Kaskade 2, Fackel-Schleife 2, Tropfen 10, schwingende Ketten 4, ferne Schreie 4, Wind-Schleife 2 + Böen 6, Eis-Knarzen 6, ferner Gletscherriss 4, Lava-Grollen 1, Raumtöne 3, Siegel bricht 3, Grollen beim Erscheinen 3 | 67 | M |
| 8 | Bedienoberfläche | Talent lernen 2, Talent zurücksetzen 1, Inventar auf/zu 2, Ausrüsten 4, Fehler 2, Abklingzeit bereit 2, Ultimate bereit 1, Karte 1, Hover 2, Hinweis 1, Pause 2, Speichern 1 | 21 | M |
| 9 | Musik | je Welt Erkunden-Stems + Kampf-Stems (synchron, 3 Sätze), Boss-Track für Krypta und Frostgruft (2; die Hölle hat einen), 8 Stinger je Welt (24), Menü 1 | 30 Stücke | L |
| | **Summe SFX** | | **733** | |

Mindestbedarf für Schritt S (neu zu beschaffen): Heldenstimmen 60 (davon 15 weiblich), Glatteis-, Pfützen- und Asche-Schritte 24, Bogensehne 6, Trinken 3, Ansage-Rückfall 6, Todes-Rückfall 4 – rund **100 Dateien**.

### 4.7 Abnahme und Nachweis

- Jede Matrixzeile wird im Story-Testraum (`src/debug/story_testraum.gd`) ausgelöst und gehört; danach steht sie auf ✔.
- Je Schritt eine Aufnahme (Bild + Ton) und ein LUFS-Messprotokoll in `production/qa/evidence/`.
- Hörprobe: Je Welt 5 s Erkunden und 5 s Kampf; drei Hörer ordnen sie blind den Welten zu (Ziel: alle richtig).
- Prüfliste „nichts geht unter“: In einem Kampf mit 8 Gegnern, Gas und einem Boss sind der eigene Treffer, die Boss-Ansage und der Low-HP-Herzschlag immer klar zu hören.
