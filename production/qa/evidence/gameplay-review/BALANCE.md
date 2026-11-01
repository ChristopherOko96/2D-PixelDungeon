# Balance-Analyse "Delve Disaster" (Story-Welten Krypta, Frostgruft, Hölle)

Stand 2026-11-01. Ich habe nur gelesen: kein Spiel-Code und keine Daten geändert, kein Mess-Skript angelegt.
Die Werte sind von Hand aus den Daten gerechnet (in dieser Sitzung gab es kein Shell-Werkzeug).
Kennzeichen: **(D)** = steht so in den Daten/im Code, **(A)** = meine Annahme, **(S)** = Schätzung, **(K)** = übliche Zielgröße bei Action-Roguelites (Branchenkonvention, keine harte Quelle).

## 0. Regeln, die alles bestimmen (D)

| Regel | Wert | Quelle |
|---|---|---|
| Hero-LP | Halbe Herzen (1 Herz = 2 LP) | hell_game.gd `_hurt`/`_lose_hp`, items.json `_doc` |
| Schaden pro Treffer am Helden | Mob **1 LP**, Boss **2 LP**, auf **jeder** Etage gleich | hell_balance.json `monsters.hit_mob/hit_boss`, hell_monsters.gd:910 |
| Schwierigkeitsgrad, Schaden | × 1,0 / 1,3 / 1,6 (abgerundet, Rest wird mitgezählt, min. 1) | talents.json `difficulties`, hell_talents.gd `incoming` |
| Schwierigkeitsgrad, Gegner-HP | × 1,0 / 1,5 / 2,2 (gilt auch für Bosse) | `difficulties.*.hp`, `hp_scale()` |
| Etagen-Skalierung Mobs | HP × (1 + (n−1)·0,16), Tempo × (1 + (n−1)·0,04) | **fest im Code**: world_core.gd:141 `difficulty_for` |
| Mob-HP | round(Basis-HP × Etagenfaktor) × Schwierigkeits-HP | hell_monster_rules.gd `spawn_hp`, hell_game.gd:1921 |
| Boss-HP | Etagen-Boss-HP × hpMul (überall 1) × Schwierigkeits-HP; **keine** Tempo-Skalierung | `spawn_hp`, hell_monsters.gd:224 |
| Unverwundbarkeit nach Treffer | 0,9 s → höchstens 1,1 Treffer pro s | hell_balance.json `player.invulnerable` |
| LP-Obergrenze | 24 LP (12 Herzen) | `player.max_hp_cap` |
| Gegner pro Kampfraum | min(9, 2 + 2·Türen + 0..1), also 4–9 | world_core.gd:595 |
| Heldenschaden | `state.dmg` (Klassenwaffe) × Krit × Karten × Gegenstands-Faktor × Talente | hell_game.gd `_damage_mob` |
| Gegenstände | Faktor = gefundene Waffe / Startwaffe (z. B. Katana 6,2/5 Schaden, 0,30/0,40 Pause → DPS × 1,65) | story_items.gd `damage_mult/rate_mult` |

Faktor pro Etage: F1 = 1,00 · F5 = 1,64 · F10 = 2,44 (Tempo 1,00 / 1,16 / 1,36).

## 1. Gegner pro Welt (Normal; Schwer × 1,5, Albtraum × 2,2)

Heldentempo zum Vergleich: 340–370 px/s. "Quote" = Gegnertempo / 350.

### Krypta (krypta_monsters.json)

| Gegner | HP F1 / F5 / F10 | Angriffe alle … s | Tempo F1 → F10 | Quote F1 / F10 | Besonderheit |
|---|---|---|---|---|---|
| Skelett | 5 / 8 / 12 | Hieb 1,8 · Sprung 4,2 (760 px/s) | 140 → 190 | 0,40 / 0,54 | |
| Skelettschütze | 3 / 5 / 7 | Pfeil 2,2 · Salve 6 | 120 → 163 | 0,34 / 0,47 | Fernkampf |
| Skelettwache | 9 / 15 / 22 | 3,4 · 3,6 | 95 → 129 | 0,27 / 0,37 | Schild vorn |
| Nekromant | 6 / 10 / 15 | Fluch 3,2 · Ruf 9 | 95 → 129 | 0,27 / 0,37 | beschwört |
| Kleiner Zombie | 4 / 7 / 10 | Sprung 2,8 (820 px/s) · Spucke 4 | 150 → 204 | 0,43 / 0,58 | |
| Eiszombie | 7 / 11 / 17 | Frostatem 4,5 | 110 → 150 | 0,31 / 0,43 | |
| Leerenbomber | 3 / 5 / 7 | 4 · 3 | 190 → 258 | 0,54 / 0,74 | |
| Mimik | 8 / 13 / 20 | Biss 2,4 (900 px/s) · 8 | 130 → 177 | 0,37 / 0,51 | |

### Frostgruft (frost_theme.json `mobs`)

| Gegner | HP F1 / F5 / F10 | Angriff | Tempo F1 → F10 | Quote F1 / F10 | Besonderheit |
|---|---|---|---|---|---|
| Eis-Zombie | 7 / 11 / 17 | Berührung | 90 → 122 | 0,26 / 0,35 | verlangsamt 1,5 s auf 0,6 |
| Frost-Skelett | 4 / 7 / 10 | Schuss alle 2,2 s (420 px/s) | 170 → 231 | 0,49 / 0,66 | hält 300 px Abstand |
| Eisschleim (ganze Kette) | 6+2·3+4·1,5 = **18** / ~29 / **45** | Berührung | 100–170 | 0,29–0,49 | teilt sich zweimal, 7 Körper |
| Frostkobold | 3 / 4 / 6 | Sprint alle 2,0 s (650 px/s) | 190 → 258 | 0,54 / 0,74 | |
| Frostwirbel | 5 / 8 / 12 | Sog 140 px/s in 380 px | 110 → 150 | 0,31 / 0,43 | |
| Eisritter | 8 / 13 / 20 | Berührung | 120 → 163 | 0,34 / 0,47 | Schild vorn |
| Eiskristall | 6 / 10 / 15 | Fächer 5 Schüsse alle 2,6 s | 0 | – | Geschütz |

### Hölle (hell_monsters.json, 8 Mob-Defs)

HP der Defs: 3, 5, 3, 6, 5, 6, **16**, 5. Der Ausreißer 16 ist sehr wahrscheinlich der Kettenschinder (EXP 16). F10: 7–15 HP, Kettenschinder 39. Die Tempo-Werte der Höllen-Defs habe ich nicht ausgelesen (offen, siehe 7).

### Bosse, alle drei Welten (hell_floors.json, frost_floors.json; krypta_world.json hat dieselbe Reihe (A))

| Etage | Typ | Hölle / Frost | HP Normal | Schwer | Albtraum |
|---|---|---|---|---|---|
| 1 | Hüter | Glutwächter / Gr. Eisschleim | 46 | 69 | 101 |
| 2 | Hüter | Dreischlund / Kobold-Rudelführer | 60 | 90 | 132 |
| 3 | Zwischenboss | Ignaroth Salamander / Frostnekromant | 90 | 135 | 198 |
| 4 | Hüter | Kesselbrut / Frostwirbel-Zwillinge | 105 | 158 | 231 |
| 5 | Hüter | Seelenhirte / Kristallwächter | 120 | 180 | 264 |
| 6 | Zwischenboss | Jungdrache / Frostleiche | 160 | 240 | 352 |
| 7 | Hüter | Kerkermeister / Eisritter-Garde | 175 | 263 | 385 |
| 8 | Hüter | Klagender Hüter / Sturmkristall | 190 | 285 | 418 |
| 9 | Zwischenboss | Glutdrache / Frostkommandant | 240 | 360 | 528 |
| 10 | Endboss | Obsidianform / Hrimgar | 340 | 510 | 748 |

Die Bosse greifen alle 2,4–11 s an und laufen 75–120 px/s (Quote 0,2–0,35). Ein Boss-Treffer kostet 2 LP.

## 2. Heldenseite

### Klassen-Grundwerte (frost_theme.json `classes`, für alle Story-Welten über `hero_from`)

| Klasse | LP | Tempo | Schaden / Pause | DPS Einzelziel | DPS im Raum (S) | Abwehr (talents.json `defense`) |
|---|---|---|---|---|---|---|
| Schwertkämpfer | **14** | 340 | 2,5 / 0,40 s | **6,25** | 9,4 (Bogen 2,0 rad, 150 px, ~1,5 Ziele (A)) | Block, 2 Treffer |
| Bogenschütze | 12 | 370 | 1,0 / 0,22 s | 4,55 | **4,55** (Einzelziel) | Rolle 2×, 0,4 s unverwundbar |
| Magier | **10** | 350 | 1,75 / 0,40 s | 4,38 | 8,75 (Splash 110 px, ~2 Ziele (A)) | Block, 2 Treffer |
| Nekromant | 11 | 350 | 1,6 / 0,42 s | **3,81** | 7,6 (Splash 100 px) | Knochenschild |

### Typischer Build (A): Faktor auf den Grund-DPS

| Etage | Lauf-Stufe (S) | Karten | Annahme | DPS-Faktor |
|---|---|---|---|---|
| F1 | 4 | 3 | Startwaffe, Karten eher LP/Talente | × 1,0 |
| F5 | 8 | 7 | 2× +15 % Schaden, 2× −10 % Pause, Waffe "selten" (× 1,3), Ausrüstung +5 % | × 2,2 |
| F10 | 11 | 10 | 3× +15 %, 3× −10 % Pause, Waffe "episch" (× 1,7), Ring + Rüstung +20 % | **× 4,2** |

Karten addieren sich (A). Legendäre Waffen im Vergleich: Sonnenklinge × 2,5 DPS, Sonnenbogen × 2,1, Sonnenstab × 1,75.

### Erste aktive Talente (talents.json): Anteil am Grundschaden

Anteil = Talent-Multiplikator / (Abklingzeit / Waffenpause), also wie viel ein Einsatz im Verhältnis zu den normalen Angriffen in seiner Abklingzeit beiträgt.

| Talent | Schaden Rang 1/3 | Abklingzeit, Kosten | Anteil Rang 1 / 3 | Bewertung |
|---|---|---|---|---|
| Feuerball (fire_1) | 1,25 / 1,65 + 50 % Splash + Brand | 4 s, 14 Mana | 12,5 % / 16,5 % | gut, aber Mana: dauerhaft nur 1 Wurf pro 21 s (Regeneration 0,67/s) → +2,4 % |
| Pyro-Monster (fire_3) | 0,35 alle 1,4 s, dauerhaft | 30 s | +10 % DPS | stark für einen Punkt |
| Wutschlag (berserk_1) | 1,45 / 1,95 | 5 s, 20 | 11,6 % / 15,6 % | in Ordnung |
| Wirbelsturm (berserk_3) | 0,9 im Radius 3 m | 10 s | 3,6 % pro Ziel | schwach bei wenigen Zielen |
| **Gezielter Schuss (sniper_1)** | 1,5 / 2,0 | 6 s, 20 Ausdauer | **5,5 % / 7,3 %** | **nahezu nutzlos** |
| Durchschuss (sniper_3) | 1,15 × bis zu 3 Ziele | 10 s, 25 | 2,5 % pro Ziel | schwach |

Ursache: Die Bogen-Talente sind Prozent vom Einzelschuss, der Bogen schießt aber alle 0,22 s. Ein Gezielter Schuss ersetzt nur 1,5 der 27 normalen Schüsse in seinen 6 s. Ausdauer reicht dauerhaft (Kosten 3,3/s, Regeneration 5/s), Mana dagegen nicht (so gewollt, Nutzerentscheidung 30.10.).

### Überleben: Treffer bis zum Tod bei Start-LP (ohne Block/Rolle)

| Klasse | Normal Mob / Boss | Schwer Mob / Boss | Albtraum Mob / Boss |
|---|---|---|---|
| Schwert (14) | 14 / 7 | 10,8 / 5,4 | 8,8 / 4,4 |
| Bogen (12) | 12 / 6 | 9,2 / 4,6 | 7,5 / 3,8 |
| Magier (10) | 10 / 5 | 7,7 / 3,8 | 6,3 / 3,1 |
| Nekro (11) | 11 / 5,5 | 8,5 / 4,2 | 6,9 / 3,4 |

Ziel (K): früh 5–8 ungeblockte Treffer. Normal liegt bei Mobs mit 10–14 darüber (nachsichtig), bei Bossen mit 5–7 im Ziel.
Später steigen die Helden-LP (Kraftkarte +2 LP × 3, Rüstung +2…+6, Herzcontainer im Tresor) bis zur Grenze von 24 LP, **der Treffer bleibt aber 1 LP**. Auf F10 hält der Held auf Normal ~20–24 Mob-Treffer aus.

### Heilung pro Etage (Normal, (S): ~10 Kampfräume, 3 Truhen, 10 Kisten (A))

| Quelle | Regel (D) | F1 | F5 | F10 |
|---|---|---|---|---|
| Tränke aus Truhen | 0,70→0,90 × Trank-Anteil 5/18 = 28 % | 0,58 | 0,66 | 0,75 |
| Tränke aus Kisten | 0,14→0,24 × Trank-Anteil 6/14,9 = 40 % | 0,56 | 0,74 | 0,97 |
| Fester Zusatztrank | `potion_floors` [1,2,3] | 1 | 0 | 0 |
| **Tränke gesamt** | | **2,1** | **1,4** | **1,7** |
| Heilwert pro Zufallstrank | Heilung 20,8 % × 4 + Erholung 10,4 % × 6 + Schutz 10,4 % × 2 Treffer ≈ 1,7 LP | 3,6 LP | 2,3 LP | 2,9 LP |
| Schädliche Tränke | Feuer, Gift, Explosion, Eis, Blendung = 36 % der Gewichte; Feuer/Gift/Explosion kosten ~2,8 LP | Erwartung pro unbekanntem Trank netto ≈ +1,0 LP | | |
| Herzen | `drops.heart` 0,35 pro Quelle × 2 LP (hell_game.gd:2035; ~10 Quellen (A)) | ~7 LP | ~7 LP | ~7 LP |
| Stufenaufstieg | +2 LP (`leveling.heal`) | ~6 LP (3 Stufen) | ~2 LP | ~2 LP |
| Tresor | Herzcontainer +2 LP max **und volle Heilung** (hell_game.gd:1655) | je Fund | je Fund | je Fund |
| **Summe ohne Tresor** | | **~17 LP** | **~11 LP** | **~12 LP** |

## 3. Abgeleitete Zahlen

### Zeit bis zum Kill (TTK = HP / DPS, Normal, typischer Build)

Referenz-Mob = 6 Basis-HP (Nekromant, Brandskelett; der Eis-Zombie hat 7) → 6 / 10 / 15 HP. Elite = Kettenschinder 16 / 26 / 39 HP.

| Ziel | Schwert | Bogen | Magier | Nekro | Ziel (K) |
|---|---|---|---|---|---|
| Normaler Mob F1 | 0,96 s | 1,32 s | 1,37 s | 1,57 s | 1–3 s ✔ |
| Normaler Mob F5 | 0,73 s | 1,00 s | 1,04 s | 1,19 s | 1–3 s, an der Untergrenze |
| Normaler Mob F10 | **0,57 s** | 0,79 s | 0,82 s | 0,94 s | **unter dem Ziel** |
| Normaler Mob F10 Albtraum (33) | 1,25 s | 1,73 s | 1,79 s | 2,06 s | ✔ |
| Elite F1 | 2,6 s | 3,5 s | 3,7 s | 4,2 s | 5–10 s ✘ |
| Elite F10 | 1,5 s | 2,0 s | 2,1 s | 2,4 s | 5–10 s ✘ |

### Boss-TTK (reiner Schaden, ohne Ausweichen; mit ~70 % Trefferzeit (K) × 1,43)

Build-Faktor pro Etage (A): 1,0 / 1,3 / 1,6 / 1,9 / 2,2 / 2,6 / 3,0 / 3,4 / 3,8 / 4,2.

| Etage | HP | Schwert | Bogen | Magier | Nekro |
|---|---|---|---|---|---|
| 1 | 46 | 7,4 s | 10,2 s | 10,5 s | 12,1 s |
| 2 | 60 | 7,4 s | 10,2 s | 10,6 s | 12,1 s |
| 3 (Zwischen) | 90 | 9,0 s | 12,4 s | 12,9 s | 14,8 s |
| 4 | 105 | 8,8 s | 12,1 s | 12,6 s | 14,4 s |
| 5 | 120 | 8,7 s | 12,0 s | 12,4 s | 14,3 s |
| 6 (Zwischen) | 160 | 9,8 s | 13,5 s | 14,0 s | 16,1 s |
| 7 | 175 | 9,3 s | 12,8 s | 13,3 s | 15,3 s |
| 8 | 190 | 8,9 s | 12,2 s | 12,7 s | 14,6 s |
| 9 (Zwischen) | 240 | 10,1 s | 13,9 s | 14,4 s | 16,6 s |
| 10 (End) | 340 | 13,0 s | 17,8 s | 18,6 s | 21,3 s |

Ziel (K): Etagen-Hüter 30–60 s, Zwischenboss 45–75 s, Endboss 60–120 s. Selbst mit Ausweichzeit (× 1,43) und Flug-/Grab-/Verwandlungsphasen (immun) dauern die Kämpfe nur ~10–45 s. **Bosse sterben 3–6× zu schnell.** Pets und Talente sind dabei noch nicht eingerechnet.

### Schaden pro Raum (S)

Formel: LP-Verlust = N_Mobs × T_Kampf / Ø-Angriffspause × p_Treffer, mit N = 6, Ø-Pause 3 s, p = 0,05 (geübter Spieler (K)), T = Raum-HP / Raum-DPS × 1,6 (Laufen, Zielen).

| | Schwert | Bogen | Magier | Nekro |
|---|---|---|---|---|
| F1 Kampfzeit / LP-Verlust pro Raum | 6,1 s / 0,6 | 12,7 s / **1,3** | 6,6 s / 0,7 | 7,6 s / 0,8 |
| F1 pro Etage (10 Räume) | 6 LP | **13 LP** | 7 LP | 8 LP |
| F10 Kampfzeit / LP-Verlust pro Raum | 3,7 s / 0,4 | 7,5 s / 0,8 | 3,9 s / 0,4 | 4,5 s / 0,5 |
| F10 pro Etage | 4 LP | 8 LP | 4 LP | 5 LP |

Schwer kostet × 1,95 so viel (HP × 1,5, Schaden × 1,3), Albtraum × 3,5. Auf Normal sinkt der Verlust pro Etage über den Lauf, während Heilung (~12 LP) und Max-LP (bis 24) steigen. **Die Kurve wird nach hinten flacher statt steiler.**

### EXP und Stufen

Lauf-Stufe (frost_theme.json `leveling`: Bedarf = 60 · Stufe^1,3; Mob-EXP 2–16, Ø ~8 (A); Hüter 120, Zwischenboss 250; ~60 Kills pro Etage (talents.json-Notiz)):

| Nach Etage | EXP gesamt (S) | Lauf-Stufe | Karten / Laufbaum-Punkte |
|---|---|---|---|
| 1 | ~600 | 4 | 3 |
| 5 | ~3 000 | 8 | 7 |
| 10 | ~6 400 | 11 | 10 (`run_tree.points_per_level` 1) |

Heldenstufe (talents.json: nächste Stufe = 50 × Stufe, Stufe 30 = 21 750 EXP; Kill 10, Etage 100, Zwischenboss 150, Boss 400):
Ein voller Lauf bringt 6 000 (Kills) + 1 000 (Etagen) + 450 (3 Zwischenbosse) + 2 800 (7 Hüter/Endboss à 400, (A)) ≈ **10 250 EXP**.

| | Laut Notiz (7 000/Lauf) | Ist (10 250/Lauf) | Vorschlag `base` 65 |
|---|---|---|---|
| Nach Lauf 1 | Stufe 17 (16 Punkte) | **Stufe 20 (19 Punkte)** | Stufe 18 |
| Nach Lauf 2 | Stufe 24 | **Stufe 29** | Stufe 25 |
| Stufe 30 erreicht | Lauf 3–4 | **Lauf 3, früh (≈ 2,1 Läufe)** | Lauf 3 (≈ 2,8 Läufe) |

Gewollt waren laut `levels._note` "etwa drei volle Läufe". Weil die Boss-EXP in der Notiz fehlen, wird das Maximum fast einen Lauf zu früh erreicht.

## 4. Vergleich mit den Zielwerten, Ausreißer

| # | Befund | Beleg | Schwere |
|---|---|---|---|
| A1 | **Bosse viel zu weich**: 7–21 s statt 30–120 s | Boss-TTK-Tabelle | hoch |
| A2 | **Mob-HP wächst langsamer als der Held** (× 2,44 gegen × 4,2) → Mob-TTK fällt von ~1,3 s auf ~0,8 s | TTK F1/F10 | hoch |
| A3 | **Eingehender Schaden wächst nicht mit der Etage** (1/2 LP), die Helden-LP schon (bis 24) | Abschnitt 0, Überleben | hoch |
| A4 | **Schwertkämpfer dominiert**: höchste Einzelziel-DPS (1,64 × Nekro), meiste LP (14), Block, Reichweite 150 px (fast Fernkampf gegen Boss-Radius 70) | Klassentabelle | mittel |
| A5 | **Bogenschütze schwächste Klasse im Raum** (4,55 gegen 7,6–9,4 Raum-DPS), höchster LP-Verlust pro Etage (13 LP auf F1) | Raum-Tabelle | mittel |
| A6 | **Gezielter Schuss nahezu nutzlos** (5,5 %), Durchschuss schwach | Talent-Tabelle | mittel |
| A7 | Nekromant langsamster Boss-Killer (21 s auf F10), ausgeglichen nur über Pets | Boss-TTK | niedrig–mittel |
| A8 | Heldenstufe 30 nach ~2,1 statt ~3 Läufen | EXP-Tabelle | mittel |
| A9 | Verfolger sind zu langsam (Quote 0,26–0,44 auf F1): Kiten ist trivial, Gefahr kommt nur von Sprüngen | Gegner-Tabellen | mittel |
| A10 | Eliten zu weich (2–4 s statt 5–10 s); die Krypta hat keine echte Elite (max. 9 HP) | TTK Elite | niedrig |
| A11 | Eisschleim-Kette = 3 × Referenz-Mob (18 → 45 HP über 7 Körper) | Frost-Tabelle | niedrig |
| A12 | Zwischenbosse sind HP-Sprünge (+50 %, +33 %, +26 %), danach fällt es wieder (+17 %, +9 %): sägezahnförmig, gewollt | Boss-Tabelle | Info |
| A13 | **Welten sind zahlenmäßig fast gleich** (gleiche Etagenformel, gleiche Boss-Reihe, gleicher Treffer). Unterschiede kommen nur aus den Mustern: Frost hat Verlangsamung und Sog (am schwersten für die Bewegung), die Hölle den einen 16-HP-Mob | alle Tabellen | Info |
| A14 | Schwierigkeitsgrade gut gestaffelt (Bedrohung × 1,95 / × 3,5); Albtraum F10 trifft das Mob-TTK-Ziel | TTK-Tabelle | ✔ |
| A15 | Unverwundbarkeit 0,9 s liegt im üblichen Bereich 0,5–1,0 s (K) | | ✔ |
| A16 | Etagen-Skalierung steht fest im Code (world_core.gd:141), gegen die Projektregel "Werte aus Daten" | | Technik |

## 5. Vorgeschlagene Änderungen (nach Wirkung sortiert)

| Rang | Problem (Beleg) | Änderung: Datei, Schlüssel, alt → neu | Erwartete Wirkung | Risiko |
|---|---|---|---|---|
| 1 | A1 Bosse 7–21 s | hell_floors.json, frost_floors.json, krypta_world.json, je `boss.hp` F1–F10: 46/60/90/105/120/160/175/190/240/340 → **115/150/225/260/300/400/440/475/600/1200** | Hüter 20–40 s, Zwischenboss 30–55 s, Endboss 50 s (Schwert) bis 100 s (Nekro), mit Ausweichen | längere Kämpfe = mehr 2-LP-Treffer für Magier/Nekro; Ignaroths Formen und Frost-`boss_kits` mit eigenen HP-Listen (frost_theme.json ~Z. 489) einzeln prüfen |
| 2 | A2 Mob-HP × 2,44 gegen Held × 4,2 | world_core.gd:141 `"hp": 1 + (n - 1) * 0.16` → **0.30** (Code; besser als neuer Schlüssel `monsters.floor_hp_step` in hell_balance.json) | Mob-TTK bleibt über den Lauf bei ~0,9–1,3 s (F10-Mob 22 HP) | Code-Änderung; Räume auf F10 dauern ~50 % länger; Eisschleim-Kette wird noch zäher (siehe 12) |
| 3 | A3 Max-LP 24 bei gleichem Treffer | hell_balance.json `player.max_hp_cap` 24 → **18** | F10: ~18 statt ~24 Mob-Treffer bis zum Tod; Herzcontainer und Kraftkarten zählen früher | späte Kraftkarten und Container verfallen; LP-Anzeige prüfen |
| 4 | A3 Treffer immer 1/2 LP | Code + neuer Schlüssel hell_balance.json `monsters.hit_floor_step` (z. B. Boss 2 → 3 LP ab F5, Mob 1 → 2 LP ab F8) | Bosse späterer Etagen werden spürbar gefährlicher | Code-Änderung; mit Rang 3 abstimmen, nicht beides voll |
| 5 | A5 Bogen 4,55 DPS | frost_theme.json `classes.archer.weapon.damage` 1.0 → **1.25** | DPS 5,7; Raum-Verlust F1 13 → ~10 LP | Einzelziel liegt dann knapp unter Schwert-neu (5,75); Boss-TTK prüfen |
| 6 | A6 Gezielter Schuss 5,5 % | talents.json `sniper_1.dmg` [1.5, 1.75, 2.0] → **[2.6, 3.0, 3.4]** | Anteil 9,5–12,5 %, auf Höhe von Wutschlag/Feuerball | Krit-Talent (sniper_2) vervielfacht große Einzeltreffer: Krit-Spitzen ansehen |
| 7 | A6 Durchschuss 2,5 %/Ziel | talents.json `sniper_3.dmg` [1.15, 1.35, 1.55] → **[1.8, 2.1, 2.4]** | ~4 % pro Ziel, 12 % bei 3 Zielen | gering |
| 8 | A4 Schwert dominiert | frost_theme.json `classes.swordsman.weapon.damage` 2.5 → **2.3** | DPS 6,25 → 5,75 (Abstand zum Nekro 1,64 → 1,37) | Schwert bleibt Klasse mit den meisten LP; gefühlt "schwächer": Spieltest |
| 9 | A4 Reichweite 150 px | frost_theme.json `classes.swordsman.weapon.reach` 150 → **125** | Nahkampf bleibt ein Risiko, Boss-Kontakt nötiger | trifft im Wirbel weniger Ziele; nur zusammen mit Rang 8 testen |
| 10 | A7 Nekro langsamster | frost_theme.json `classes.necromancer.weapon.cooldown` 0.42 → **0.38** | DPS 3,81 → 4,21 (+10 %) | Pets (minion-Baum) könnten ihn schon tragen: erst mit Pets messen |
| 11 | A8 Stufe 30 nach 2,1 Läufen | talents.json `levels.base` 50 → **65** | Stufe 30 nach ~2,8 Läufen, wie in der Notiz gewollt | vorher klären, ob jeder Hüter `exp.boss` 400 gibt (sonst reicht 55) |
| 12 | A9 Verfolger zu langsam | krypta_monsters.json `skelett.stats.speed` 140 → **175**, `zombie` 150 → **180**, `eiszombie` 110 → **140**; frost_theme.json `mobs.ice_zombie.speed` 90 → **120**, `mobs.ice_slime.speed` 100 → **125** | Quote F1 ~0,35–0,51, F10 ~0,48–0,70: Kiten braucht Bewegung, bleibt aber möglich | Eis-Zombie verlangsamt bei Berührung: Kombination prüfen |
| 13 | A10 Eliten 2–4 s | hell_monsters.json `kettenschinder.stats.hp` 16 → **22**; krypta_monsters.json `skelettwache.stats.hp` 9 → **12**; frost_theme.json `mobs.ice_knight.hp` 8 → **11** | Elite-TTK ~3,5–5 s (mit Rang 2 auf F10 ~3–4 s) | Schildträger zusätzlich zäh durch Frontblock: Spieltest |
| 14 | A11 Schleimkette | frost_theme.json `mobs.ice_slime_s.hp` 1.5 → **1.0** (nur bei Rang 2) | Kette F10 45 → ~37 HP | gering |

Empfohlenes Paket für den ersten Spieltest: 1 + 2 + 3 + 5 + 6 + 8. Danach 10/11/12 nach Gefühl.
Kontrolle danach (gleiche Rechnung): Mob F10 ~0,9–1,3 s, Boss F1 ~29–39 s, Endboss ~70–100 s mit Ausweichen.

## 6. Werte ohne Änderungsbedarf

- Schwierigkeitsgrade (`difficulties`): sinnvoll gestaffelt.
- Mana-Knappheit des Magiers: so gewollt (Nutzerentscheidung 30.10.2026). Ausdauer des Bogens leert sich dagegen nie (Kosten 3,3/s < Regeneration 5/s). Nur ein Hinweis, nicht ändern, solange die Bogen-Talente schwach sind.
- Trankgewichte nach der heutigen Änderung: 42 % heilen/schützen, 36 % schaden. Ein unbekannter Trank bringt im Mittel +1 LP, das passt zum Risiko-Spiel des Identifizierens.
- Unverwundbarkeit 0,9 s, Rolle 0,4 s, Block 2 Treffer.

## 7. Offene Punkte (nicht sicher aus den Daten)

1. `drops.heart` 0,35 (hell_game.gd:2035): pro Kill oder pro Kiste/Raum? Bei "pro Kill" wären es ~20 Herzen pro Etage, dann wäre Heilung der größte Ausreißer. Den Aufrufer prüfen.
2. Krypta-Boss-HP: krypta_world.json enthält `"hp":46`; ich nehme an, die Reihe ist dieselbe.
3. Tempo der Höllen-Mobs nicht ausgelesen (hell_monsters.json `stats.speed`).
4. Gibt jeder Hüter `exp.boss` 400 oder nur der Endboss (wichtig für Rang 11)?
5. Splash-Anteil von Magier/Nekro (voller Schaden angenommen) und ob Karten additiv stapeln.
6. Talent-Basisschaden = `state.dmg` (angenommen).
