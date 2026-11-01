# Klang-Recherche – freie Quellen für Delve Disaster

Stand 2026-11-01. Ergänzt `docs/KLANG-KONZEPT.de.md` §4.6. **Nur gesucht und
gelesen, nichts heruntergeladen.** Jede Lizenz stammt von der Seite des Pakets
selbst:

- OpenGameArt (OGA): Seiten direkt gelesen (Lizenzfeld, Hinweistext, Dateiliste).
- itch.io: zeigt eine Cloudflare-Prüfung. Die wurde **nicht** umgangen; gelesen
  wurden die Kopien auf web.archive.org (Stand 2025-07 bis 2026-09). **Vor dem
  Download die Live-Seite noch einmal ansehen.**
- Kenney, Freesound, Sonniss, Pixabay: direkt gelesen.
- Passung ist nach Beschreibung geschätzt, **nicht angehört**.

## Legende

| Zeichen | Bedeutung |
|---|---|
| ✅ | CC0 – frei, keine Nennung nötig |
| 🟡 | CC-BY 3.0/4.0 oder OGA-BY 3.0 – frei, **Namensnennung + Lizenzlink** (Text steht in der Zeile) |
| ⚠️ | eigene Lizenz, im Spiel erlaubt, aber **Weitergabe der Rohdateien verboten** → Problem, weil das Repo öffentlich ist |
| ❌ | ausgeschlossen: NC, ND, SA (Share-Alike), unklar, kostenpflichtig, Herkunft fraglich |
| Passung 1–5 | 5 = knackig, Pixel-Dungeon, 8/16-Bit-nah, aber nicht nur Chiptune; 1 = kinoreif/realistisch oder falsches Genre |

Schon im Projekt (nicht noch einmal laden): Kenney Impact Sounds, Kenney „50 RPG
sound effects“, Knochen-Pack, rubberduck „80 CC0 creature SFX“ #1 und #2, fünf
Musikstücke (`assets/audio/library/CREDITS.md`).

**Grundregel fürs öffentliche Repo:** CC0 und CC-BY erlauben, die Rohdateien
mitzuveröffentlichen (CC-BY mit Nennung, Lizenzlink und Hinweis „geschnitten /
konvertiert“). Lizenzen mit Weitergabe-Verbot (Sonniss, Chequered Ink, Leohpaz
itch.io, Shapeforms, Pixabay) sind im fertigen Spiel erlaubt, als lose Dateien im
öffentlichen Repo aber nicht oder nur grauzonig.

---

## 0 Die vorhandenen „Pixel Combat“-Klänge (Lizenz geklärt)

Ordner `C:\Users\Cylor\Desktop\Sound Pixel Combat` (siehe
`assets/audio/sfx/license_note.md`). Er enthält **zwei** Pakete:

| Teil im Ordner | Paket | Autor | Seite | Lizenz (wörtlich) | Umfang | Befund |
|---|---|---|---|---|---|---|
| 350 Dateien `*_HY_PC.wav` (DSGN…, MAGSpel…, UIClick… usw.) | **FREE Pixel Combat SFX** | Helton Yan (Credits auf der Seite: Helton Yan, Beto Bezerra) | https://heltonyan.itch.io/pixelcombat | „This work is licensed under Attribution 4.0 International.“ · Feld „Asset license: Creative Commons Attribution v4.0 International“ · „No generative AI was used“ | 2100 Einzeldateien oder 350 „Sausage Files“ (je 6 Varianten in einer Datei), WAV 96 kHz/24 Bit, 4,65 GB entpackt; Downloads „Single Files.zip“ 2,1 GB / „Sausage Files.zip“ 1,8 GB; Name-your-price (0 €) | ✅🟡 **Sicher nutzbar, auch im öffentlichen Repo – mit Nennung.** Die 350 Dateien im Ordner sind genau die Sausage-Fassung. |
| Unterordner `Card and Board`, `Combat and Gore`, `Human`, `Musical Effects`, `UI`, `Weapons`, `digital` | **400 Sounds Pack** (sehr wahrscheinlich – Ordnernamen = Kategorien der Seite, Ordnerdatum 10./11.11.2025 = Devlog „New 400 Sounds Pack!“ vom 11.11.2025; nicht per Prüfsumme bestätigt) | Chequered Ink | https://ci.itch.io/400-sounds-pack | „You may use these game assets for ANY and ALL uses including commercial use, with or without giving credit, except that you may not sell or redistribute the unaltered assets as your own game assets.“ | 400 WAV, „400 Sounds Pack.zip“ 64 MB, Name-your-price | ⚠️ Im Spiel frei, keine Nennung nötig. **Unveränderte** WAVs im öffentlichen Repo sind eine Grauzone („redistribute the unaltered assets“). Sauber: nur geschnittene/bearbeitete Fassungen ins Repo, oder Chequered Ink fragen. |

Nennung Pixel Combat (Vorschlag für `CREDITS.md`):
`„Pixel Combat SFX“ von Helton Yan (Sounddesign Helton Yan, Beto Bezerra), https://heltonyan.itch.io/pixelcombat – CC BY 4.0 (https://creativecommons.org/licenses/by/4.0/) – geschnitten und konvertiert.`

Damit ist der Punkt „Licence: unknown“ in `license_note.md` für die `_HY_PC`-Dateien
erledigt (Notiz dort bitte nachziehen – diese Recherche schreibt nur diese Datei).

---

## 1 Heldenstimmen

Ziel aus dem Konzept: elf_f (weiblich, jung, agil), knight_m (tief), wizard_m
(mittel, älter), necro_m (heiser) – nur Laute, keine Wörter.

| Paket | Autor | Seite | Direktlink | Lizenz (wörtlich) / Nennung | Dateien | Größe, Format | Deckt ab | Passung |
|---|---|---|---|---|---|---|---|---|
| **Female RPG Voice Starter Pack** ✅ | cicifyre | https://opengameart.org/content/female-rpg-voice-starter-pack | https://opengameart.org/sites/default/files/RPG%20Voice%20Starter%20Pack.zip | CC0 · „Credit appreciated, but not required. :)“ | 3 Frauenstimmen (niedlich, mittel, reif/burschikos) × ca. 30 Zeilen | 8,8 MB ZIP | **Elfe:** attack 1–3, damaged 1–3, jump 1–3, healed 1–3 je Stimme; dazu Zauberwörter (fire, ice, curse …) | 4 |
| **Female Hurt Grunts & Groans** ✅ | Nocturnal_Vanguard (Sprecherin „AuraVoice“) | https://opengameart.org/content/female-hurt-grunts-groans | https://opengameart.org/sites/default/files/female_hurt_grunts_groans_1.ogg | CC0 · „Whatever SFX I post here, use however you like! No credit required.“ | 1 Datei mit mehreren Lauten (schneiden) | 0,19 MB OGG | Elfe: Schmerz leicht/schwer, Stöhnen | 4 |
| **Dying Voices – Female – RPG** ✅ | Galacti-Chron (Sprecherin Sky Rae) | https://opengameart.org/node/99640 | https://opengameart.org/sites/default/files/Dying-Voices-FEMALE-RPG.zip | Lizenzfeld zeigt **CC-BY 3.0 und CC0**; Hinweistext: „These sound effects are licensed under cc0 (Public Domain), this means you are free to use the pack for commercial and non-commercial projects, royalty free, without crediting Galacti-Chron.“ → CC0 wählen, Nennung trotzdem nett | 54 | 2,2 MB ZIP | Elfe: Tod (Achtung: „dying lines“ – teils gesprochene Wörter, beim Anhören aussortieren) | 3 |
| Female Warrior Grunts 🟡 | SkyRae | https://opengameart.org/content/female-warrior-grunts | https://opengameart.org/sites/default/files/Grunts%20HD%20Deep.mp3 | CC-BY 3.0 · Nennung: „SkyRae“ | 1 (mehrere Laute) | 0,2 MB MP3 | Elfe: Anstrengung/Angriff, eher tief | 3 |
| **Male Grunt/Yelling sounds** ✅ | HaelDB | https://opengameart.org/content/male-gruntyelling-sounds | https://opengameart.org/sites/default/files/yelling%20sounds.zip | „OGA-BY 3.0 / CC0“ (doppelt lizenziert → CC0 wählen) | **4 verschiedene Männerstimmen** × 10–12 Schreie/Grunzer | 9,7 MB ZIP | **Ritter, Magier, Nekromant mit getrennten Klangfarben** – Angriff, Schmerz, Schrei | 5 |
| **15 vocal male strain/hurt/pain/jump sounds** ✅ | qubodup | https://opengameart.org/content/15-vocal-male-strainhurtpainjump-sounds | https://opengameart.org/sites/default/files/slightscreams.7z | CC0 („Available under CC0 starting 2024-08-30“) · Nennung optional: „qubodup“ | 15 | 1,4 MB 7z | Anstrengung, leichter Schmerz, Sprung (Magier, mittel) | 4 |
| 11 male human pain/death sounds 🟡 | Michel Baradari (eingereicht von qubodup) | https://opengameart.org/content/11-male-human-paindeath-sounds | https://opengameart.org/sites/default/files/michelbaradari-human.7z | CC-BY 3.0 · Nennung: „Michel Baradari“ | 11 | 0,5 MB 7z | Ritter: Schmerz und Tod | 4 |
| grunts of male death and pain ✅ | thebardofblasphemy | https://opengameart.org/content/grunts-male-death-and-pain | https://opengameart.org/sites/default/files/death%20pain%20grunts.wav | CC0 · „You have my blessing to do whatever you want with this sound file.“ | 1 Datei, mehrere Todesgrunzer | 4,4 MB WAV | Tod (schneiden) | 3 |
| Generic Hero Effort Noises 🟡 | tinsin | https://opengameart.org/content/generic-hero-effort-noises | https://opengameart.org/sites/default/files/Valiant%20Genericus%20%28Effort%20Noises%29.wav | „CC-BY 3.0 / CC-BY-SA 3.0“ → CC-BY 3.0 wählen · Nennung: „tinsin“ | 1 Datei, viele Laute | 2,2 MB WAV | Ritter/Held: Schwung-, Hebe-, Sprunglaute (Zelda-artig) | 4 |
| Voices Sound Effects Library 🟡 | Little Robot Sound Factory | https://opengameart.org/content/voices-sound-effects-library | https://opengameart.org/sites/default/files/Voices_Sound_Effect_Library.zip | CC-BY 3.0 · „Attribute Little Robot Sound Factory, and provide this link where possible: www.littlerobotsoundfactory.com“ | 450 (u. a. 15 Evil Human, 31 Good Human, 4 Dying Breath) | 101,8 MB ZIP (MP3 + WAV) | **Nekromant:** böses Lachen/Stimme; siehe auch §5 | 4 |

---

## 2 Zauber und Magie

| Paket | Autor | Seite | Direktlink | Lizenz (wörtlich) / Nennung | Dateien | Größe, Format | Deckt ab | Passung |
|---|---|---|---|---|---|---|---|---|
| **Pixel Combat SFX** (schon vorhanden, §0) 🟡 | Helton Yan | https://heltonyan.itch.io/pixelcombat | nur itch-Knopf | CC BY 4.0 | 2100 / 350 | 1,8–2,1 GB | Cast, Skill Release/Impact, Explosion, Buff – Feuer, Blitz, Dunkel, Wasser | 5 |
| **8 Magic Attacks** 🟡 | Leohpaz | https://opengameart.org/content/8-magic-attacks | https://opengameart.org/sites/default/files/8_rpg_battle_magic_sfx_free_samples.zip | CC-BY 4.0 · Nennung: „Leohpaz“ | 8 | 4,2 MB ZIP | Feuer-Explosion, Eis-Explosion, Donner, Wasser, Wind, Erde, Aufladen, **Gift** – Retro-RPG-Stil | 5 |
| **8 Heals and Buffs SFX** 🟡 | Leohpaz | https://opengameart.org/content/8-heals-and-buffs-sfx | https://opengameart.org/sites/default/files/8_rpg_heals_buffs_sfx_samples.zip | CC-BY 4.0 · Nennung: „Leohpaz“ | 8 | 6,9 MB ZIP | **Heilig/Heilung**, Buff, Debuff, Wiederbeleben, Absorbieren, Schlaf, Tempo | 5 |
| **Magic Spell SFX Soundpack** 🟡 | Leonardo Calvo (Soundrack) | https://thesoundrack.itch.io/freemagicspellsfx | 9 externe Links (Fire, Lightning, Wind, Water, Earth, Ice, Holy, Dark, Acid) | „License – Attribution 4.0 International – https://creativecommons.org/licenses/by/4.0/“ (laut Autor auch in der Datei) · Nennung: „Leonardo Calvo (Soundrack)“ | 425 | Größe nicht angegeben, WAV 96 kHz (eher groß) | **Alle Elemente inkl. Heilig, Dunkel, Säure/Gift** | 4 |
| **Basic Spell Impacts [Free/CC0]** ✅ | lentikula | https://lentikula.itch.io/freecc0-basic-spell-impacts-sfx | nur itch-Knopf | „I release this pack under a CC0 license, so you can use it in whatever project without attribution“ | 20 (je 5 Blitz, Feuer, Eis, Wasser) | 13 MB ZIP, WAV 48 kHz/24 Bit | Einschläge Feuer/Eis/Blitz/Wasser | 4 |
| **JC Sounds – Fantasy SFX Pack Vol 1** 🟡 | JC Sounds | https://opengameart.org/content/jc-sounds-fantasy-sfx-pack-vol-1 | https://opengameart.org/sites/default/files/fantasy_sfx_pack_vol_1.7z | CC-BY 4.0 · „CC BY 4.0 - Credit: JC Sounds“ | 58 | 4,7 MB 7z | Feuer/Eis/Blitz: Aufbau, Abschuss, Einschlag, Schleife; Heil-Glöckchen; **Nekromantie-Gesang (Schleife)**; Teleport; Schild; Mana-Sog; Schwerter; **Bogen: Spannen, Schuss, Treffer** | 4 (neuer Uploader, Feb. 2026 – Herkunft beim Anhören prüfen) |
| 3 dark magic spells ✅ | qubodup | https://opengameart.org/content/3-dark-magic-spells | https://opengameart.org/sites/default/files/dark_magic.7z | CC0 | 3 | 0,8 MB 7z | Leere/Dunkel | 3 |
| Ice & Electricity Magic 🟡 | qubodup | https://opengameart.org/content/ice-electricity-magic | https://opengameart.org/sites/default/files/qubodupIceAndElectricitySpells.7z | CC-BY 3.0 · Nennung: „qubodup“ | mehrere | 1,4 MB 7z | Eis-Zauber, Strom/Zap | 3 |
| Magic Spell SFX ✅ | JaggedStone | https://opengameart.org/content/magic-spell-sfx | einzelne OGG, z. B. https://opengameart.org/sites/default/files/magical_1_0.ogg | CC0 · „None needed“ | 7 | je 40–80 KB OGG | allgemeines Zaubern (für Dungeon-Crawler gemacht) | 3 |
| Freeze Spell ✅ | artisticdude | https://opengameart.org/content/freeze-spell-0 | https://opengameart.org/sites/default/files/freeze.wav | CC0 | 1 | 0,6 MB WAV | Einfrieren | 3 |
| Magic SFX Sample 🟡 | ViRiX (David Mckee) | https://opengameart.org/content/magic-sfx-sample | https://opengameart.org/sites/default/files/Magic%20SFX%20Preview%20Pack.zip | CC-BY 3.0 · „Some of the sounds in this project were created by ViRiX Dreamcore (David Mckee) www.soundcloud.com/virix“ | 5 | 1,6 MB ZIP | Zauber, glitzernd | 3 |
| Steam release sounds ✅ | bart | https://opengameart.org/content/steam-release-sounds | https://opengameart.org/sites/default/files/steam_hisses.zip | CC0 · „Attribution appreciated :)“ | mehrere | 0,6 MB ZIP | **Gift-/Gaszischen**, Dampfstoß | 4 |
| Acid burn sounds 🟡 | mikhog (nutzt Michel Baradaris Lava splash) | https://opengameart.org/content/acid-burn-sounds | https://opengameart.org/sites/default/files/acid%20burn_0.mp3 | CC-BY 3.0 · Nennung: „mikhog, Michel Baradari“ | 2 | je 23 KB MP3 | Säure/Gift brutzelt | 3 |
| Horror Sound Effects Library 🟡 | Little Robot Sound Factory | https://opengameart.org/content/horror-sound-effects-library | https://opengameart.org/sites/default/files/Horror%20Sound%20Library.zip | CC-BY 3.0 · LRSF-Nennung wie oben | 69 (3 Blut-Tropf-Schleifen, 10 Blut-Tropfen, 4 Knochenbruch, 8 böses Lachen/Schreie, 12 Monster/Zombie, 5 Ambiences, Tor auf) | 70 MB ZIP | **Blut**, Knochen, Grusel | 3 |

Lücke: Ein echtes „Schwarzes Loch“-Dröhnen gibt es fertig kaum. Bauen aus: Pixel
Combat „Dark Energy Sphere“/„Mind Eraser“ + 4 Atmospheric ghostly loops (§7) +
Kenney Sci-fi Sounds (§6), rückwärts und tiefer gepitcht.

---

## 3 Element-Schleifen und -Ambience

| Paket | Autor | Seite | Direktlink | Lizenz (wörtlich) / Nennung | Dateien | Größe, Format | Deckt ab | Passung |
|---|---|---|---|---|---|---|---|---|
| **Lava loop** 🟡 | Blender Foundation (Yo Frankie!), eingereicht von Lamoot | https://opengameart.org/content/lava-loop | https://opengameart.org/sites/default/files/lavaloop.zip | CC-BY 3.0 · Nennung: „Blender Foundation – Yo Frankie!“ | 1 Schleife | 3,1 MB ZIP | Lava blubbert (Schleife) | 4 |
| Lava Loop 2 / Lava Loop 4 (Freesound) ✅ | Fission9 | https://freesound.org/people/Fission9/sounds/474852/ (und …/474850/) | Download nur mit Freesound-Konto | „Creative Commons 0“ (Einzelseite 474852 geprüft) | 2 | Loop 4: 10,9 MB WAV, 0:39 | tiefes Lava-Becken, nahtlos | 4 |
| Lava splash 🟡 | Michel Baradari | https://opengameart.org/content/lava-splash | https://opengameart.org/sites/default/files/lava.flac | CC-BY 3.0 · Nennung: „Michel Baradari“ | 1 | 0,1 MB FLAC | Lavaspritzer, Brutzeln | 4 |
| **40 CC0 water / splash / slime SFX** ✅ | rubberduck | https://opengameart.org/content/40-cc0-water-splash-slime-sfx | https://opengameart.org/sites/default/files/water-splash-slime-sfx.zip | CC0 | 40 (3 Blasen, 6 Schleifen Blasen/Regen/Wasser, 16 Schleim, 15 Spritzer) | 2,3 MB ZIP | **Pfütze, Wasserspritzer, Blubbern, Schleim** | 5 |
| Steam release sounds ✅ | bart | siehe §2 | | CC0 | | 0,6 MB | Dampfzischen, Gasleck | 4 |
| **Fire Crackling** ✅ | AntumDeluge | https://opengameart.org/content/fire-crackling | https://opengameart.org/sites/default/files/fire-1.wav (OGG: …/fire-1_0.ogg) | CC0 („Licensing: Creative Commons Zero (CC0)“) | 1 | 0,25 MB WAV | Kaminknistern (Kohlenbecken, Glut) | 4 |
| Fire Loop 🟡 | qubodup | https://opengameart.org/content/fire-loop | https://opengameart.org/sites/default/files/qubodupFireLoop.ogg | CC-BY 3.0 · Nennung: „qubodup“ | 1 | 68 KB OGG / 1,2 MB FLAC | Feuer-Schleife | 4 |
| **wind1** ✅ | Luke.RUSTLTD | https://opengameart.org/content/wind1 | https://opengameart.org/sites/default/files/wind1.wav (bis wind5.wav) | CC0 | 5 × 1 min, loopbar | je 5,3 MB WAV | Wind/Schneesturm (synthetisch, sauber) | 4 |
| wind whoosh loop ✅ | SketchMan3 | https://opengameart.org/content/wind-whoosh-loop | https://opengameart.org/sites/default/files/wind%20woosh%20loop.ogg | CC0 | 1 | 0,25 MB OGG | heller Wind (Frostgruft) | 3 |
| blizzard looped.aif (Freesound) ✅ | m0ments | https://freesound.org/people/m0ments/sounds/679941/ | Freesound-Konto | CC0-Suchfilter (Einzelseite nicht geöffnet) | 1 | – | Schneesturm-Schleife | 3 |
| FOL-gas-leak-01/02 (Freesound) ✅ | henrikcederblad | https://freesound.org/people/henrikcederblad/sounds/615668/ | Freesound-Konto | CC0-Suchfilter (Einzelseite nicht geöffnet) | 2 | – | Gasleck-Zischen | 3 |

---

## 4 Physik und Trümmer

| Paket | Autor | Seite | Direktlink | Lizenz (wörtlich) / Nennung | Dateien | Größe, Format | Deckt ab | Passung |
|---|---|---|---|---|---|---|---|---|
| **75 CC0 breaking / falling / hit sfx** ✅ | rubberduck | https://opengameart.org/content/75-cc0-breaking-falling-hit-sfx | https://opengameart.org/sites/default/files/sfx_breaking_and_falling.zip | CC0 | 75 | 1,6 MB ZIP | **Geröll, Brechen, Fallen, Aufprall** | 5 |
| **100 CC0 metal and wood SFX** ✅ | rubberduck | https://opengameart.org/content/100-cc0-metal-and-wood-sfx | https://opengameart.org/sites/default/files/100-CC0-wood-metal-SFX.zip | CC0 | 100 | 2,0 MB ZIP | **Metall-Klirren (Schwert fällt)**, Schlüssel, Schloss, Feder, **Holz bricht/knarzt**, Metalltür | 5 |
| **80 CC0 RPG SFX** ✅ | rubberduck | https://opengameart.org/content/80-cc0-rpg-sfx | https://opengameart.org/sites/default/files/80-CC0-RPG-SFX_0.zip | CC0 | 80 (3 Klinge, 3 Kette, 22 Kreatur, 21 Gegenstand inkl. **Münzen**/Edelstein, 3 Schloss, 9 Zauber inkl. Feuer, 4 Steine, 5 Holz) | 1,8 MB ZIP | Münzen, Ketten, Steine, Holz | 5 |
| 100 CC0 SFX ✅ | rubberduck | https://opengameart.org/content/100-cc0-sfx | https://opengameart.org/sites/default/files/100-CC0-SFX_0.zip | CC0 | 100 (u. a. 5 Glas, 12 Metall, Türen, Explosion, Spritzer) | 2,9 MB ZIP | Glas-Klirren, Metall | 4 |
| 100 CC0 SFX #2 ✅ | rubberduck | https://opengameart.org/content/100-cc0-sfx-2 | https://opengameart.org/sites/default/files/sfx_100_v2.zip | CC0 | 100 (Luft, Tür, Schritte, Glas, Steine, **Donner**, Holz) | 2,4 MB ZIP | Steine, Glas, Donner | 4 |
| **Coins Sound Effects Library** 🟡 | Little Robot Sound Factory | https://opengameart.org/content/coins-sound-effects-library | https://opengameart.org/sites/default/files/Coins%20Sound%20Library.zip | CC-BY 3.0 · LRSF-Nennung | 151 (56 einzelne Münze, 46 wenige, 23 mehrere, 14 Schütten, 9 Edelstein) | 17,6 MB ZIP | **Münzen fallen/klimpern/schütten** | 4 |
| RPG Sound Pack ✅ | artisticdude | https://opengameart.org/content/rpg-sound-pack | https://opengameart.org/sites/default/files/rpg_sound_pack.zip | CC0 | 95 WAV | 12,5 MB ZIP | Münzwurf, Kettenhemd, Flasche, Blasen, Schwert ziehen/klirren, Zauber | 4 |
| Ice breaking/shattering ✅ | IgnasD | https://opengameart.org/content/ice-breakingshattering | https://opengameart.org/sites/default/files/IceShatters_0.zip | CC0 | einige | 75 KB ZIP | **Eis zerspringt, Klirren** | 4 |
| Ice cracking (Freesound) ✅ | kyles („ice grinding cracking freezing designed“), karlis.stigis („Ice Cracks“) | https://freesound.org/people/kyles/sounds/452645/ · https://freesound.org/people/karlis.stigis/sounds/168712/ | Freesound-Konto | CC0-Suchfilter (Einzelseiten nicht geöffnet) | 2 | – | Gefrier-Knacken, Eis-Knarzen | 4 |
| Squish Sounds Effects ✅ | EZduzziteh | https://opengameart.org/content/squish-sounds-effects | einzelne MP3, z. B. https://opengameart.org/sites/default/files/squish_01_0.mp3 | CC0 | 8 | je ~8 KB MP3 | **Fleisch/Gore-Klatschen**, Matsch | 4 |
| Casino Audio ✅ | Kenney | https://kenney.nl/assets/casino-audio | Download-Knopf auf der Seite | „Creative Commons CC0“ | 50 | nicht angegeben | Chips/Würfel → kurzes Münzklicken | 3 |

---

## 5 Kreaturenstimmen

| Paket | Autor | Seite | Direktlink | Lizenz (wörtlich) / Nennung | Dateien | Größe, Format | Deckt ab | Passung |
|---|---|---|---|---|---|---|---|---|
| **Voices Sound Effects Library** 🟡 | Little Robot Sound Factory | https://opengameart.org/content/voices-sound-effects-library | https://opengameart.org/sites/default/files/Voices_Sound_Effect_Library.zip | CC-BY 3.0 · „Attribute Little Robot Sound Factory, and provide this link where possible: www.littlerobotsoundfactory.com“ | 450 (**30 Demon, 69 Zombie, 65 Small Creature, 51 Orc**, 22 Splat, 25 Dinosaur …) | 101,8 MB ZIP | **Imp/Dämon, Zombie, kleine Viecher, Orks**, Gore-Splat | 4 |
| **Zombies Sound Pack** ✅ | artisticdude | https://opengameart.org/content/zombies-sound-pack | https://opengameart.org/sites/default/files/zombies.zip | CC0 | 24 WAV | 4,7 MB ZIP | **Zombie-Stöhnen, -Tod** | 4 |
| **Zombie / Skeleton / Monster Voice Effects** ✅ | ArcadeParty | https://opengameart.org/content/zombie-skeleton-monster-voice-effects | https://opengameart.org/sites/default/files/Voice%20Effects%20Zombie-Skeleton-Monster%20Human%20Male.zip | CC0 | einige + ein paar männliche Laute | 2,0 MB ZIP | **Skelett**, Zombie, Monster | 4 |
| 15 monster grunt/pain/death sounds 🟡 | Michel Baradari | https://opengameart.org/content/15-monster-gruntpaindeath-sounds | https://opengameart.org/sites/default/files/michelbaradari-monsters.7z | CC-BY 3.0 · Nennung: „Michel Baradari“ | 15 | 0,8 MB 7z | Imp/Dämon/Höllenhund: Grunzen, Schmerz, Tod | 4 |
| Monster Sound Pack, Volume 1 ✅ | Ogrebane | https://opengameart.org/content/monster-sound-pack-volume-1 | https://opengameart.org/sites/default/files/monster-sounds-volume-2.zip | CC0 | mehrere | 2,0 MB ZIP | Knurren, Grunzen, Tod (Eisriese, Ritter-Gegner) | 4 |
| Big scary troll sounds ✅ | Darsycho | https://opengameart.org/content/big-scary-troll-sounds | https://opengameart.org/sites/default/files/troll-roars_0.ogg (+ idle) | CC0 · „Feel free to use for whatever, credit is appreciated!“ | 3 OGG | 0,1–0,3 MB | **Eisriese**, großer Boss | 4 |
| CC0 Deep Monster Roar ✅ | trazzz123 | https://opengameart.org/content/cc0-deep-monster-roar | https://opengameart.org/sites/default/files/monster_roar.wav | CC0 | 1 | 1,3 MB WAV | **Drachen-/Riesengebrüll** | 4 |
| Fantasy Sound Effects Library 🟡 | Little Robot Sound Factory | https://opengameart.org/content/fantasy-sound-effects-library | https://opengameart.org/sites/default/files/Fantasy%20Sound%20Library.zip | CC-BY 3.0 · LRSF-Nennung | 45 (2 Drachenknurren, 5 Goblin, 3 Fallen, 5 Gold aufheben, 3 Jingles, 18 Schritte) | 31 MB ZIP | Drache, Goblin/Imp, Fallen, Gold | 4 |
| **Ghost Monster Voice Moaning & Growling** ✅ | qubodup | https://opengameart.org/content/ghost-monster-voice-moaning-growling | https://opengameart.org/sites/default/files/qubodup-GhostMoans.zip | CC0 | viele | 4,0 MB ZIP | **Geister, Leere-Flüstern** | 4 |
| Dog Snarl Grunt Grumble ✅ | qubodup | https://opengameart.org/content/dog-snarl-grunt-grumble | https://opengameart.org/sites/default/files/dog_0.7z | CC0 | einige | 0,3 MB 7z | **Höllenhund** (tiefer pitchen), Wolf-Knurren | 4 |
| Wolf howl (Freesound) ✅ | NaturesTemper | https://freesound.org/people/NaturesTemper/sounds/398430/ | Freesound-Konto | CC0-Suchfilter (Einzelseite nicht geöffnet) | 1 | – | **Wolf heult** (Begleiter) | 3 |
| Wolf Monster Sound ✅ | CaveboyTup | https://opengameart.org/content/wolf-monster-sound | https://opengameart.org/sites/default/files/wolf_monster_6.mp3 | CC0 · „CC0 - Made from CC0 sounds.“ | 1 | 13 KB MP3 | Fantasy-Wolf | 3 |
| Bear Growls ✅ | AntumDeluge (Quelle: U.S. Fish & Wildlife Service) | https://opengameart.org/content/bear-growls | https://opengameart.org/sites/default/files/bear.zip | CC0 | einige | 0,1 MB ZIP (FLAC/OGG) | **Bär** (Begleiter) | 4 |
| hawk.wav (Freesound) ✅ | denalwa | https://freesound.org/people/denalwa/sounds/582183/ | Freesound-Konto | CC0-Suchfilter (Einzelseite nicht geöffnet) | 1 | – | **Falke** (Begleiter) | 3 |
| 40 CC0 water / splash / slime ✅ | rubberduck | siehe §3 | | CC0 | 16 Schleim | | **Eisschleim/Schleim** | 5 |

Schon da: rubberduck „80 CC0 creature SFX“ #1/#2 (Aliens, Monster) und das Knochen-Pack (trockenes Rasseln).

---

## 6 Welt, Gegenstände, Bedienoberfläche

| Paket | Autor | Seite | Direktlink | Lizenz (wörtlich) / Nennung | Dateien | Größe, Format | Deckt ab | Passung |
|---|---|---|---|---|---|---|---|---|
| **Door Open, Door Close Set** ✅ | qubodup | https://opengameart.org/content/door-open-door-close-set | https://opengameart.org/sites/default/files/qubodup-DoorSet.7z | CC0 | mehrere (Holz, Metall, quietschend, schwer) | 3,3 MB 7z | **Türen, Gitter** | 4 |
| 100 CC0 metal and wood SFX ✅ | rubberduck | siehe §4 | | CC0 | | 2,0 MB | Metalltür, Schloss, Schlüssel, Feder (Falle) | 5 |
| Chain winch sounds ✅ | bart | https://opengameart.org/content/chain-winch-sounds | https://opengameart.org/sites/default/files/winch.zip | CC0 · „Credit appreciated. :)“ | einige | 1,5 MB ZIP | **Ketten**, Winde (Kettenfolterer) | 3 |
| 4 Space / Portal Sounds ✅ | Écrivain | https://opengameart.org/content/4-space-portal-sounds | https://opengameart.org/sites/default/files/tts.zip | CC0 | 4 MP3 | 0,4 MB ZIP | **Portal** | 3 |
| **Level up, power up, Coin get (13 Sounds)** ✅ | wobbleboxx | https://opengameart.org/content/level-up-power-up-coin-get-13-sounds | https://opengameart.org/sites/default/files/SoundPack01.zip | CC0 · „If you want to give credit (not required): "WobbleBoxx Workshop"“ | 13 | 6,8 MB ZIP | **Stufenaufstieg, Power-up, Münze, Pling** | 5 |
| **The Essential Retro Video Game Sound Effects Collection [512 sounds]** ✅ | Juhani Junkala (OGA-Seite „512 Sound Effects (8-bit style)“ von SubspaceAudio; Readme nennt Junkala) | https://opengameart.org/content/512-sound-effects-8-bit-style | https://opengameart.org/sites/default/files/The%20Essential%20Retro%20Video%20Game%20Sound%20Effects%20Collection%20%5B512%20sounds%5D.zip | CC0 | 512 WAV | 20,6 MB ZIP | Pickups, Menü, Explosionen, Sprünge – 8-Bit | 3 (zu chiptunig für Kampf, gut für UI/Pickups) |
| 50 CC0 retro / synth SFX ✅ | rubberduck | https://opengameart.org/content/50-cc0-retro-synth-sfx | https://opengameart.org/sites/default/files/50-CC0-retro-synth-SFX.zip | CC0 | 50 (+ LMMS-Quellen) | 1,9 MB ZIP | Power-up, Münze, Tod, Explosion | 3 |
| 8-Bit Sound Effects Library 🟡 | Little Robot Sound Factory | https://opengameart.org/content/8-bit-sound-effects-library | https://opengameart.org/sites/default/files/8-Bit%20Sound%20Library.zip | CC-BY 3.0 · LRSF-Nennung | 40 | 5,6 MB ZIP | Pickup, Öffnen, Jingles Sieg/Niederlage | 3 |
| **Interface Sounds** ✅ | Kenney | https://kenney.nl/assets/interface-sounds | Download-Knopf | „Creative Commons CC0“ | 100 | nicht angegeben | **Klicks, Bestätigen, Fehler, Hover** | 4 |
| UI Audio ✅ | Kenney | https://kenney.nl/assets/ui-audio | Download-Knopf | „Creative Commons CC0“ | 50 | nicht angegeben | Schalter, Klicks | 3 |
| **Music Jingles** ✅ | Kenney | https://kenney.nl/assets/music-jingles | Download-Knopf | „Creative Commons CC0“ | 85 | nicht angegeben | **Stinger**: Sieg, Niederlage, Fund | 4 |
| Sci-fi Sounds / Digital Audio ✅ | Kenney | https://kenney.nl/assets/sci-fi-sounds · https://kenney.nl/assets/digital-audio | Download-Knopf | „Creative Commons CC0“ | 70 / 60 | nicht angegeben | Rohstoff für Leere-Dröhnen, Zaps | 2 |
| UI Sound Effects Library 🟡 | Little Robot Sound Factory | https://opengameart.org/content/ui-sound-effects-library | https://opengameart.org/sites/default/files/UI%20Sound%20Library.zip | CC-BY 3.0 · LRSF-Nennung | 105 | 3,4 MB ZIP | Klicks, Mund-UI-Laute | 3 |
| Fantasy Sound Effects Library 🟡 | LRSF | siehe §5 | | | | 31 MB | **3 Fallen**, Inventar auf, Gold aufheben | 4 |
| Fire Crackling ✅ | AntumDeluge | siehe §3 | | | | | **Kohlenbecken** | 4 |

---

## 7 Ambience je Welt und Musik

### 7.1 Ambience

| Welt | Paket | Autor | Seite | Direktlink | Lizenz / Nennung | Größe, Format | Passung |
|---|---|---|---|---|---|---|---|
| Krypta | **Dark Cavern Ambient** ✅ | Paul Wortmann | https://opengameart.org/content/dark-cavern-ambient | https://opengameart.org/sites/default/files/dark_cavern_ambient_002.ogg (+ _001) | CC0 | 2 × 1,7 MB OGG (1 mit Fade, 1 Schleife) | 4 |
| Krypta | **4 Atmospheric ghostly loops** ✅ | Independent.nu (eingereicht von qubodup) | https://opengameart.org/content/4-atmospheric-ghostly-loops | https://opengameart.org/sites/default/files/independent_nu_ljudbank-atmosphere_moody.7z | CC0 | 4 Schleifen, 3,4 MB 7z | 4 |
| Krypta | Horror Sound Effects Library 🟡 | LRSF | siehe §2 | | CC-BY 3.0 | 5 Ambiences + Tropf-Schleifen, 70 MB | 3 |
| Krypta | (schon da) Loopable Dungeon Ambience, Dungeon Ambience | JaggedStone, yd | | | | | – |
| Frostgruft | **wind1** ✅ | Luke.RUSTLTD | siehe §3 | | CC0 | 5 × 1 min WAV | 4 |
| Frostgruft | Ice cracking (Freesound) ✅ | kyles, karlis.stigis | siehe §4 | | CC0-Filter | | 4 |
| Hölle | **Lava loop** 🟡 | Blender Foundation | siehe §3 | | CC-BY 3.0 | 3,1 MB | 4 |
| Hölle | **Evil temple Ambiance loop** ✅ | Brandon Morris (eingereicht von HaelDB) | https://opengameart.org/content/evil-temple-ambiance-loop | https://opengameart.org/sites/default/files/evil_temple.ogg | „OGA-BY 3.0 / CC0“ → CC0 | 5,3 MB OGG | 4 |
| Hölle | Background Rumble Noise 🟡 | gryc | https://opengameart.org/content/background-rumble-noise | https://opengameart.org/sites/default/files/background_ambience.ogg | CC-BY 3.0 · Nennung „gryc“ | 0,16 MB OGG (Zug-Grollen, 4–25 s loopen) | 3 |

### 7.2 Musik (2–4 je Welt)

| Welt | Stück | Autor | Seite | Direktlink | Lizenz (wörtlich) / Nennung | Größe, Format | Stil | Passung |
|---|---|---|---|---|---|---|---|---|
| Krypta | **LOOP BOX #3** (17 Stücke, enthält „In Darkness“ als Schleife) 🟡 | Of Far Different Nature | https://opengameart.org/content/essentials-pack-for-fantasy-games-loop-box-3-orchestral-soundtracks-for-rpgs-and-adventures | https://opengameart.org/sites/default/files/of_far_different_nature_-_loop_box_3_cc-by_-_ogg_files_1.zip | CC-BY 4.0 · „[...] by Of Far Different Nature (https://fardifferent.carrd.co/)“ | 31,1 MB ZIP (OGG); WAV 99,3 MB | Orchester + Synth, Höhlen/Gräber, nahtlos | 4 |
| Krypta | RPG – The Graveyard 🟡 | Hitctrl | https://opengameart.org/content/rpg-the-graveyard | https://opengameart.org/sites/default/files/RPG_-_The_Graveyard.ogg | CC-BY 3.0 · Nennung „HitCtrl“ | 1,9 MB OGG | Streicher, Chor, gruselig, loopbar | 4 |
| Krypta | Caves of Sorrow 🟡 | Alexandr Zhelanov | https://opengameart.org/content/caves-of-sorrow | https://opengameart.org/sites/default/files/Caves%20of%20sorrow.ogg | CC-BY 3.0 · „Alexandr Zhelanov, https://soundcloud.com/alexandr-zhelanov“ | 4,6 MB OGG | dunkle Höhle | 4 |
| Krypta (Boss) | Final_Boss_Lair 🟡 | Hitctrl | https://opengameart.org/content/finalbosslair | https://opengameart.org/sites/default/files/Final_Boss_Lair.ogg | CC-BY 3.0 · Nennung „Hitctrl“ (bittet um Bescheid) | 3,0 MB OGG | Boss-Hort, unheimlich | 4 |
| Krypta | Spooky Dungeon ✅ | Memoraphile @ You're Perfect Studio | https://opengameart.org/content/spooky-dungeon | https://opengameart.org/sites/default/files/Memoraphile%20-%20Spooky%20Dungeon_0.ogg | „CC-BY 4.0 / OGA-BY 3.0 / CC0“ → CC0 | 0,5 MB OGG | 8-Bit, loopbar | 3 |
| Frostgruft | **Cold Sanctuary** 🟡 | Jonathan Shaw (InspectorJ) | https://opengameart.org/content/cold-sanctuary-rpg-orchestral-essentials-dungeon-music | https://opengameart.org/sites/default/files/Cold%20Sanctuary%20MP3.zip | CC-BY 3.0 · „"Cold Sanctuary" Composed by Jonathan Shaw (www.jshaw.co.uk)“ | 2,9 MB ZIP (MP3) | frostiger Dungeon, Orchester | 4 |
| Frostgruft | Ice Cave 🟡 | TAD | https://opengameart.org/content/ice-cave | https://opengameart.org/sites/default/files/Ice%20Cave_0.ogg | CC-BY 4.0 · Nennung „TAD“ | 2,2 MB OGG | Orchester, loopbar | 4 |
| Frostgruft | Beyond the Frozen Veil ✅ | Synth-thetic | https://opengameart.org/content/beyond-the-frozen-veil | https://opengameart.org/sites/default/files/synth-thetic_-_beyond_the_frozen_veil_-_cc0.7z | CC0 · „Free to use however you like with no attribution required.“ | 23,8 MB 7z | Eis-Königreich, glitzernd, loopbar | 3 |
| Frostgruft (Boss) | Battle themes 🟡 | Alexandr Zhelanov | https://opengameart.org/content/battle-themes | https://opengameart.org/sites/default/files/Battle%20Themes.zip | CC-BY 4.0 · „Alexandr Zhelanov https://soundcloud.com/alexandr-zhelanov“ | 7,4 MB ZIP (MP3) | Kampf | 3 |
| Frostgruft (Boss) | Music loops pack 1 – Dark Fantasy 🟡 | Chris „Torone“ CB | https://torone.itch.io/music-loops-pack-1-dark-fantasy | itch-Knopf | „Those loops are under Creative Common Attribution 4.0“ · Nennung „Chris "Torone" CB“ | 18 MB ZIP (4 OGG: 2 Erkunden, 1 Kampf, 1 Erzählung) | Dark Fantasy, Orchester | 4 |
| Hölle | **Heated Lands** 🟡 | Jonathan Shaw (InspectorJ) | https://opengameart.org/content/heated-lands-rpg-orchestral-essentials-dungeon-music | https://opengameart.org/sites/default/files/Heated%20Lands%20MP3.zip | CC-BY 3.0 · „"Heated Lands" Composed by Jonathan Shaw (www.jshaw.co.uk)“ | 3,8 MB ZIP (MP3) | heißer Dungeon, Orchester | 4 |
| Hölle | The 9th Circle ✅ | Joth | https://opengameart.org/content/the-9th-circle | https://opengameart.org/sites/default/files/The%209th%20Circle%20V2.mp3 | CC0 · „Credit to Joth appreciated but not required“ | 3,4 MB MP3 | industriell, „Satans Nachtclub“ | 3 |
| Hölle (Boss Drache) | The King of Hell (Final Boss Theme) 🟡 | Spring Spring (Julie Damsgaard) | https://opengameart.org/content/the-king-of-hell-final-boss-theme | https://opengameart.org/sites/default/files/yet%20another%20soundtrack%20-%20Track%2006%20%28The%20King%20of%20Hell%20%28Final%20Boss%29%29_0.ogg | „CC-BY 3.0/CC-BY 4.0/CC-BY-SA …“ → CC-BY 4.0 · „Produced by Julie Damsgaard/Spring Spring/Spring Enterprises @ https://spring-enterprises.neocities.org“ | 3,4 MB OGG | 8-Bit-Endboss | 3 |
| Hölle (Boss) | Dragged Through Hellfire 🟡 | Zander Noriega | https://opengameart.org/content/dragged-through-hellfire | https://opengameart.org/sites/default/files/Zander%20Noriega%20-%20Dragged%20Through%20Hellfire.zip | CC-BY 3.0 · Nennung „Zander Noriega“ | 50,9 MB ZIP | brutaler Metal | 3 |
| alle (lang) | A Darkness Opus 🟡 | Alexandr Zhelanov | https://opengameart.org/content/a-darkness-opus | https://opengameart.org/sites/default/files/A%20Darkness%20Opus.ogg | OGA-BY 3.0 · Nennung wie oben | 35,2 MB OGG, 10 min | „Diablo-Stil“ | 4 |

Schon da: „Heavy Boss Battle 1“ (MintoDog) passt zum Drachen, „Determined Pursuit“ (Emma_MA) als Kampf.

---

## 8 Geprüft und verworfen (oder nur mit Vorbehalt)

| Quelle | Seite | Grund |
|---|---|---|
| Sonniss GameAudioGDC Bundles ⚠️ | https://sonniss.com/gameaudiogdc | Lizenz: „All of the sounds are royalty free and commercially usable.“, „No attribution is required …“, aber Weitergabe „Not as sound effects. That covers the original files and any edited or re-designed versions“ und „Use for AI/ML training is strictly prohibited“. Je Jahr 9–48 GB (2015–2024, zusammen ≈ 207 GB), überwiegend realistisch/kinoreif. Passung 2. Nur als Steinbruch, Rohdateien nie ins öffentliche Repo. |
| Pixabay Sound Effects ⚠️ | https://pixabay.com/service/license-summary/ | Pixabay Content License (kein CC): frei, ohne Nennung, aber „You cannot sell or distribute Content … on a Standalone basis“; Uploads von Nutzern, Herkunft je Datei unklar. Nicht empfohlen. |
| Shapeforms Audio Free Sound Effects ⚠️ | https://shapeforms.itch.io/shapeforms-audio-free-sfx | „royalty-free … no credit required“, Details nur im „full license agreement“ im Download; ein Kommentator las darin ein Weitergabeverbot auch einzelner Klänge. 180 Klänge, 115 MB, vor allem Sci-Fi/UI (nützlich: „Arcane Activations“, „The Mint – Coins“). Passung 3. |
| Leohpaz „RPG Essentials SFX – Free!“ ⚠️ | https://leohpaz.itch.io/rpg-essentials-sfx-free | Eigene Lizenz: „free to use in your projects“, „You may not sell it or distribute this asset pack for free“, „Credits are not mandatory“. 48 Klänge, 15 MB, Stil perfekt (Passung 5) – aber Rohdateien nicht ins öffentliche Repo. Die OGA-Auszüge (8 Magic Attacks, 8 Heals and Buffs) sind CC-BY 4.0 und damit sicher. |
| VoiceBosch DAMAGE / DEATH / EFFORT SOUNDS (Male) ❌ | https://opengameart.org/content/damage-sounds-male-audio-pack (…/death-sounds-male-audio-pack, …/effort-sounds-male-audio-pack) | CC-BY-SA 4.0 (Share-Alike). Inhaltlich gut (22 Schmerz, 25 Tod, 41 Anstrengung), nur einzeln ladbar. Erst nach bewusster Entscheidung für SA. |
| Female Gruntwork – 1 ❌ | https://opengameart.org/content/female-gruntwork-1 | CC-BY-SA 4.0 |
| 7 male pain voices ❌ | https://opengameart.org/content/7-male-pain-voices | CC-BY-SA 3.0 |
| Spell Sounds Starter Pack (p0ss) ❌ | https://opengameart.org/content/spell-sounds-starter-pack | CC-BY-SA 3.0 / GPL |
| 25 spooky sound effects, 6 monstrous growls (bart), Big Monster Moan (qubodup) ❌ | OGA | jeweils nur CC-BY-SA/GPL (bei „25 spooky“ auch CC-BY 3.0 wählbar, verlangt aber Link auf opengameart.org) |
| Dark Ambience Soundscapes (yewbic) ❌ | https://opengameart.org/content/dark-ambience-soundscapes | CC-BY-SA 3.0 |
| Thunder, rain and wind (Jute) ❌ | https://opengameart.org/content/thunder-rain-and-wind | nur GPL |
| Voice Over Asset – Female (chinomi) ❌ | https://chinomi.itch.io/voice-over-asset-female-mid-range-american | Inhalt passt (attack1–4, hurt1–3, defeat), aber **keine Lizenz angegeben** |
| Females Archer Warrior Voice Pack (Mashmashu) ❌ | https://mashmashustudio.itch.io/females-archer-warrior-voice-pack | kostenpflichtig (4,99 $) |
| 10 Dungeon Drones (Dave Lindsay) ❌ | https://davelindsay.itch.io/10-dungeon-drones | kostenpflichtig (2 $), CC-BY 4.0 mit Zusatz „You may not redistribute or resell this asset“ |
| JDSherbert Pixel Explosions SFX Pack ❌ | https://jdsherbert.itch.io/pixel-explosions-sfx-pack | Lizenz nur in `LICENSE.pdf` im Download, auf der Seite nicht lesbar → unklar |
| Bald Eagle Screams | https://opengameart.org/content/bald-eagle-screams | CC-BY 3.0/GPL, aber aus einem YouTube-Video „with permission from the owner given in the comments“ → Herkunft wackelig; lieber Freesound-CC0-Falke |
| Kevin MacLeod (incompetech) | https://incompetech.com/music/royalty-free/licenses/ | „No charge. Requires that you credit the music.“ – Nennung wird pro Stück generiert, manche Stücke laufen inzwischen unter der filmmusic.io-Standardlizenz. Nur mit Prüfung je Stück. |

---

## 9 Empfohlene Download-Liste (nach Nutzen)

Reihenfolge = was die meisten offenen Lücken aus `KLANG-KONZEPT.de.md` §4.6 pro MB
schließt. Alle CC0 oder CC-BY, also auch fürs öffentliche Repo sicher.

| Rang | Paket | URL | Lizenz | Größe | Füllt |
|---|---|---|---|---|---|
| 1 | Female RPG Voice Starter Pack + Female Hurt Grunts & Groans + Dying Voices – Female | https://opengameart.org/content/female-rpg-voice-starter-pack · https://opengameart.org/content/female-hurt-grunts-groans · https://opengameart.org/node/99640 | CC0 | 8,8 + 0,2 + 2,2 MB | **Elfen-Stimme komplett**: Angriff, Schmerz, Tod |
| 2 | Male Grunt/Yelling sounds (HaelDB) | https://opengameart.org/content/male-gruntyelling-sounds | CC0 (oder OGA-BY) | 9,7 MB | **3 Männerstimmen mit eigener Klangfarbe** (Ritter, Magier, Nekromant) |
| 3 | rubberduck: 75 breaking/falling/hit + 100 metal and wood + 40 water/splash/slime + 80 RPG SFX | Seiten in §3/§4 | CC0 | 1,6 + 2,0 + 2,3 + 1,8 MB | Geröll, Holz, Metall, Schwert fällt, Pfütze, Schleim, Münzen, Ketten, Steine |
| 4 | Leohpaz 8 Magic Attacks + 8 Heals and Buffs | https://opengameart.org/content/8-magic-attacks · https://opengameart.org/content/8-heals-and-buffs-sfx | CC-BY 4.0 | 4,2 + 6,9 MB | Feuer/Eis/Donner/Wasser/Wind/**Gift**, **Heilig/Heilung**, Buffs – im Retro-RPG-Stil |
| 5 | Basic Spell Impacts (lentikula) | https://lentikula.itch.io/freecc0-basic-spell-impacts-sfx | CC0 | 13 MB | Einschläge Feuer, Eis, Blitz, Wasser |
| 6 | JC Sounds – Fantasy SFX Pack Vol 1 | https://opengameart.org/content/jc-sounds-fantasy-sfx-pack-vol-1 | CC-BY 4.0 | 4,7 MB | Zauber-Aufbau/Schleifen, **Bogen (Elfe)**, **Nekromantie-Gesang**, Teleport, Schild |
| 7 | Voices Sound Effects Library (LRSF) | https://opengameart.org/content/voices-sound-effects-library | CC-BY 3.0 | 101,8 MB | **Dämonen/Imps, Zombies, kleine Kreaturen**, böse Menschen (Nekromant), Splats |
| 8 | Zombies Sound Pack + Zombie/Skeleton/Monster Voice Effects + Ghost Moaning + Dog Snarl + Bear Growls | §5 | CC0 | 4,7 + 2,0 + 4,0 + 0,3 + 0,1 MB | Zombie, Skelett, Geister/Leere, Höllenhund, Bär |
| 9 | Level up, power up, Coin get + Kenney Interface Sounds + Kenney Music Jingles | §6 | CC0 | 6,8 MB + Kenney (nicht angegeben) | Stufenaufstieg, Pickups, UI, Stinger |
| 10 | Door Open/Close Set + Chain winch + 4 Portal Sounds | §6 | CC0 | 3,3 + 1,5 + 0,4 MB | Türen, Gitter, Ketten, Portal |
| 11 | Element-Schleifen: Lava loop, Lava splash, Steam release, Fire Crackling, wind1, Ice breaking/shattering | §3/§4 | CC-BY 3.0 (Lava) / CC0 | 3,1 + 0,1 + 0,6 + 0,3 + 5,3 (je Wind) + 0,1 MB | Lava, Dampf/Gas, Kohlenbecken, Frostwind, Eis-Klirren |
| 12 | Magic Spell SFX Soundpack (Soundrack) | https://thesoundrack.itch.io/freemagicspellsfx | CC-BY 4.0 | unbekannt, groß (96 kHz) | 425 Zauber inkl. **Dunkel, Säure, Heilig** – Auswahl treffen |
| 13 | Fantasy + Coins Sound Effects Library (LRSF) | §4/§5 | CC-BY 3.0 | 31 + 17,6 MB | Drachenknurren, Fallen, Gold; 151 Münzklänge |
| 14 | Ambience: Dark Cavern Ambient, 4 Atmospheric ghostly loops, Evil temple Ambiance loop | §7.1 | CC0 | 3,4 + 3,4 + 5,3 MB | Krypta- und Höllen-Grundton, Leere-Dröhnen |
| 15 | Musik: LOOP BOX #3, Cold Sanctuary, Heated Lands, Final_Boss_Lair, The 9th Circle, Ice Cave | §7.2 | CC-BY 4.0/3.0, CC0 | 31,1 + 2,9 + 3,8 + 3,0 + 3,4 + 2,2 MB | je Welt Erkunden + Boss |
| 16 | Monster Sound Pack Vol 1 + Big scary troll + CC0 Deep Monster Roar + 15 monster grunt (Baradari) | §5 | CC0 / CC-BY 3.0 | 2,0 + 0,4 + 1,3 + 0,8 MB | Eisriese, Drache, Imp-Tod |
| 17 | 15 vocal male strain + 11 male pain/death (Baradari) + Generic Hero Effort Noises | §1 | CC0 / CC-BY 3.0 | 1,4 + 0,5 + 2,2 MB | Reserve und Varianten für die Männerstimmen |

Freesound-Einzelklänge (Lava Loop 4, Ice Cracks, Wolf howl, hawk, gas leak, blizzard)
brauchen ein kostenloses Freesound-Konto – das legt der Nutzer selbst an.

---

## 10 Namensnennung – Vorlage für `CREDITS.md`

Nur für die CC-BY-/OGA-BY-Pakete nötig (CC0 freiwillig). Immer mit Lizenzlink und
„geschnitten/konvertiert“, wenn bearbeitet.

```
Pixel Combat SFX – Helton Yan (Helton Yan, Beto Bezerra) – https://heltonyan.itch.io/pixelcombat – CC BY 4.0
8 Magic Attacks, 8 Heals and Buffs SFX – Leohpaz – opengameart.org – CC BY 4.0
JC Sounds Fantasy SFX Pack Vol 1 – Credit: JC Sounds – opengameart.org – CC BY 4.0
Magic Spell SFX Soundpack – Leonardo Calvo (Soundrack) – https://thesoundrack.itch.io/freemagicspellsfx – CC BY 4.0
Voices / Fantasy / Coins / Horror Sound Effects Library – Little Robot Sound Factory – www.littlerobotsoundfactory.com – CC BY 3.0
11 male human pain/death sounds, 15 monster grunt/pain/death sounds, Lava splash – Michel Baradari – opengameart.org – CC BY 3.0
Lava loop – Blender Foundation (Yo Frankie!) – opengameart.org – CC BY 3.0
Fire Loop, Ice & Electricity Magic – qubodup – opengameart.org – CC BY 3.0
Generic Hero Effort Noises – tinsin – opengameart.org – CC BY 3.0
Female Warrior Grunts – SkyRae – opengameart.org – CC BY 3.0
"Cold Sanctuary", "Heated Lands" – Composed by Jonathan Shaw (www.jshaw.co.uk) – CC BY 3.0
LOOP BOX #3 – by Of Far Different Nature (https://fardifferent.carrd.co/) – CC BY 4.0
RPG - The Graveyard, Final_Boss_Lair – HitCtrl – opengameart.org – CC BY 3.0
Caves of Sorrow, Battle themes, A Darkness Opus – Alexandr Zhelanov, https://soundcloud.com/alexandr-zhelanov – CC BY 3.0 / CC BY 4.0 / OGA-BY 3.0
Ice Cave – TAD – opengameart.org – CC BY 4.0
Music loops pack 1 - Dark Fantasy – Chris "Torone" CB – https://torone.itch.io – CC BY 4.0
The King of Hell (Final Boss Theme) – Produced by Julie Damsgaard/Spring Spring/Spring Enterprises @ https://spring-enterprises.neocities.org – CC BY 4.0
Dragged Through Hellfire – Zander Noriega – CC BY 3.0
```

---

## 11 Risiken und offene Punkte

1. **Chequered Ink im Repo:** Die Unterordner des vorhandenen Ordners sind sehr
   wahrscheinlich das „400 Sounds Pack“. Die Lizenz verbietet die Weitergabe
   *unveränderter* Dateien. Wenn davon WAVs unverändert im öffentlichen Repo
   liegen: bearbeiten, durch CC0 ersetzen oder beim Autor nachfragen.
2. **Pixel Combat:** jetzt geklärt (CC BY 4.0) – aber nur mit Nennung erlaubt;
   solange die Nennung fehlt, ist die Nutzung nicht lizenzkonform.
3. **itch.io-Lizenzen** wurden auf Archivkopien gelesen; vor dem Download die
   Live-Seite prüfen (Lizenz kann sich ändern).
4. **Dying Voices – Female:** Lizenzfeld zeigt CC-BY 3.0 *und* CC0; der Text sagt
   CC0. Zur Sicherheit trotzdem „Galacti-Chron / Sky Rae“ nennen.
5. **JC Sounds (Feb. 2026) und Soundrack:** neue bzw. kleine Uploader, „No AI“
   nicht ausgewiesen – beim Anhören auf KI-/Fremdmaterial achten.
6. **Doppellizenzen** (HaelDB, Evil temple, Spooky Dungeon, Generic Hero Effort,
   King of Hell): in `CREDITS.md` festhalten, welche Lizenz gewählt wurde.
7. **Freesound:** Lizenz pro Klang; hier nur über den CC0-Suchfilter gefunden,
   außer Lava Loop 4 nicht einzeln geöffnet. Download braucht ein Konto.
8. **Kenney:** Download-Größen stehen nicht auf den Seiten.
9. **Geschmack:** Passung ist aus Beschreibungen geschätzt. Vor dem Einbau
   anhören – besonders Stimmen (Wörter statt Laute?) und Musik (Lautheit, Loop).
