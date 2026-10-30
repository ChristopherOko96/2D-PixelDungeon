# Talentbäume und Seelensplitter

Stand: 29.10.2026. Grundlage: der Master-Prompt des Nutzers und die abgenommene
Planer-Seite „Klassen und Talentbäume“. Diese Fassung ersetzt die
Seelenkristalle, Talentbäume und Unterklassen der Frostgruft
(`src/hell/meta_store.gd`).

## Entscheidungen (29.10.2026)

1. **Klassen:** 4 Klassen (Magier, Bogenschütze, Krieger, Nekromant) × 3
   Zweige × 14 Talente in 8 Reihen = 168 Talente (tiefere Bäume und der
   Nekromant mit Diener, Fluch und Seele: Entscheidung 29.10.2026; vorher
   3 Klassen mit je 6 Talenten in 4 Reihen).
2. **Level:** Das Charakterlevel 1–30 gilt pro Klasse und wird dauerhaft im
   Profil gespeichert. Das Team-Level im Run bleibt für die Karten bei
   Levelaufstieg.
3. **Einheitlich:** Ein gemeinsames Profil für alle Storys. Die alten
   Frostgruft-Kristalle verfallen.
4. **Schwierigkeit:** Normal, Schwer und Albtraum werden neu eingebaut. Das
   Boss-Level ist Etage × 2 plus Schwierigkeitsbonus. Gold aus Runs wird im
   Profil gespeichert.
5. **Tasten:** Es gibt keine Standardfähigkeiten der Klassen mehr. Gelernte
   aktive Talente liegen auf 1–4 (Belegung im Talentmenü umstellbar), die
   Ultimate auf R. Eine neue Figur beginnt mit leerer Leiste. Ein Relikt in der
   Hand legt seine eigenen Fähigkeiten auf 1–4.
8. **Ein Zweig:** Der erste Talentpunkt legt den Zweig fest. Wer Feuermagier
   ist, kann nicht in Frost oder Arkan lernen. Die anderen Zweige öffnen sich
   erst nach dem Zurücksetzen (kostet Gold). Pro Zweig sind 40 Punkte
   möglich, bis Level 30 gibt es 29: Man muss auswählen.
9. **Ressourcen:** Magier und Nekromant zahlen mit Mana, der Bogenschütze mit
   Ausdauer, der Krieger mit Zorn. Der Magier hat am meisten Mana (150), der
   Nekromant 120. Mana-Kugeln am Boden und Mana-Tränke füllen nach.
7. **Tempo:** Max-Level erst nach mehreren kompletten Läufen (etwa drei Läufe
   zu je 10 Etagen; geändert am 29.10.2026, vorher eineinhalb Etagen).
6. **Maßstab:** 1 Meter entspricht einer Kachel (32 Pixel).

## Regeln

| Bereich | Regel | Wert (alles in `assets/data/talents.json`) |
|---|---|---|
| Talentpunkte | ab Level 2 einer pro Level | 29 bei Level 30 |
| Ränge | normale Talente 3, Ultimate 1 | – |
| Reihen I–VIII | Level 2 / 5 / 8 / 11 / 14 / 17 / 21 / 25, dazu 0 / 2 / 5 / 8 / 11 / 14 / 17 / 20 Punkte im Zweig | `tiers` |
| Ein Zweig | der erste Punkt wählt ihn, andere Zweige erst nach dem Zurücksetzen | `TalentRules.chosen_spec` |
| Ultimate (Stufe 1) | freier Punkt und 1 Seelensplitter, nur eine gleichzeitig | `soul_shards.ultimate_cost` |
| Ultimate-Stufen | Stufe 2 für 2, Stufe 3 für 3 Splitter; jede Stufe verändert die Fähigkeit (siehe unten), dazu +10 / +20 % Schaden bzw. Wirkung | `tier_costs`, `tier_bonus_pct`, `stages` je Ultimate |
| Zurücksetzen | 25 Gold pro Level; alle Punkte und Splitter zurück, Ultimate-Stufen enden | `reset_gold_per_level` |
| Ressourcen | Magier Mana 150 (+7/s), Nekromant Mana 120 (+6/s), Ausdauer 100 (+10/s), Zorn 0–100 (+10 je Treffer, +5 je erlittenem Treffer) | `resources` |
| Mana am Boden | ein fallender Gegner lässt mit 18 % eine Mana-Kugel (+20 % Mana) liegen, Boss und Nebenboss immer einen Mana-Trank (volles Mana); nur Helden mit Mana heben sie auf; nach 25 s weg, höchstens 12 gleichzeitig | `mana_orbs` |
| Neue passive Typen | Schaden mit allem (`damage_pct`), ein Talent stärker (`talent_pct`), kürzere Abklingzeiten (`cdr_pct`), billigere Talente (`cost_pct`), Ressource pro Kill (`res_on_kill`) | je Talent |
| Gemeinsame Abklingzeit | 1 s nach jedem aktiven Talent | `global_cooldown` |
| Status | Brennen 12 %/s 4 s, Gift 10 %/s 5 s, Blutung 10 %/s 4 s des Grundangriffs; erneuern statt stapeln | `statuses` |
| Krit | 5 % Grundchance, 150 % Schaden | `base_crit` |
| Fallen | höchstens 2 pro Spieler | `max_traps` |
| Bosse | immun gegen Einfrieren, Festhalten und Provokation | Code |

**Seelensplitter:** Nur der echte Boss eines Laufs gibt sie, also der Boss
auf Etage 10. Das gilt in jeder Welt. Normale Gegner, Elitegegner,
Nebenbosse (Etage 3, 6 und 9), beschworene Gegner und Truhen geben nie
welche. Jeder faire Bosssieg bringt fest 2 Splitter (`soul_shards.per_boss`).
Dazu kommt ein weiterer Splitter mit der Chance der Schwierigkeit
(`extra_pct`: Normal 0 %, Schwer 25 %, Albtraum 50 %). Der erste Albtraum-Sieg
pro Boss und Profil bringt ebenfalls einen weiteren.
Das Ultimate ist eine Erweiterung in drei Stufen (Entscheidung 29.10.2026):
Freischalten kostet 1 Splitter, Stufe 2 kostet 2 und Stufe 3 kostet 3, zusammen 6.
Auf Normal ist das etwa eine Stufe pro vollem Lauf: frei nach dem ersten,
Stufe 2 nach dem zweiten, Stufe 3 nach dem dritten Lauf. Der Boss zählt
bei jedem Charakterlevel, auch der Endboss auf Normal mit Level 30
(Entscheidung 29.10.2026). Farmen verhindert schon, dass es nur einen Boss pro
Lauf gibt.

**Ultimate-Stufen:** Jede Stufe verändert die Fähigkeit selbst und gilt
zusätzlich zur vorigen (`stages` in `talents.json`, `TalentRules.staged`).

| Ultimate | Stufe 2 | Stufe 3 |
|---|---|---|
| Inferno | Glutkern: +2 m Radius, Brennen +3 s | Feuersturm: zweite Explosion nach 1,5 s (120 %), danach 6 s brennender Boden |
| Absoluter Nullpunkt | Ewiges Eis: +1,5 s Einfrieren, Bosse 70 % langsamer für 6 s | Splitterbruch: nach 3 s zweite Welle mit 180 % in 7 m |
| Zeitbruch | Beschleunigung: +3 s, +15 % Zauberschaden | Zeitschleife: alle anderen Fähigkeiten laden sofort nach; am Ende Arkanwelle 200 % in 5 m |
| Letzter Pfeil | Durchschlag: durchbohrt alle Gegner, 380 % | Pfeilsturm: drei Pfeile im Fächer |
| Todeszone | Sumpfgift: +1,5 m, +4 s, Gegner 40 % langsamer | Seuchenherz: jede Sekunde 60 % statt alle 2 s 40 % |
| Alpharuf | Großes Rudel: 3 statt 2 Begleiter, +5 s | Rudelführer: Biss jede Sekunde mit 55 %, doppelt so viel Leben |
| Blutrausch | Blutdurst: 20 % Lebensraub, nur +5 % erlittener Schaden | Blutgericht: +4 s, +20 % Schaden, am Ende Blutschlag 250 % in 4 m |
| Unbezwingbar | Schildstoß: beim Wirken Schockwelle 120 % in 4 m, +2 s | Vergeltung: 75 % weniger Schaden, am Ende Entladung 300 % in 5 m |
| Klingentanz | Wirbelklingen: 9 statt 6 Angriffe, 5 m Reichweite | Finale: Treffer lassen bluten, am Ende Schlussstreich 300 % in 5 m |
Keine Splitter gibt es in diesen Fällen:
- der Kampf dauerte unter 20 s,
- der Held hatte unter 5 % Schadensanteil,
- der Held war nicht dabei,
- die Abschluss-Kennung wurde schon gewertet.

**EXP und Gold:** Gegner 10 EXP und 1 Gold, Nebenbosse 150 EXP, Bosse 400 EXP
und 40 Gold, jede neue Etage 100 EXP und 15 Gold. Für das nächste Level
braucht man 50 × Level EXP, für jedes Level dieselbe Regel. Level 30 braucht
damit 21 750 EXP, das sind etwa drei komplette Läufe zu je 10 Etagen
(Nutzerentscheid 29.10.2026: Talente deutlich schwerer zu bekommen, Max-Level
erst nach mehreren Läufen; vorher 2,5 × Level, etwa eineinhalb Etagen).

**Schwierigkeit:** Leben der Gegner ×1 / 1,5 / 2,2, Schaden ×1 / 1,3 / 1,6.
Gewählt wird sie im Talentmenü, und sie gilt für die Runs des Hosts.

## Aufbau

| Modul | Aufgabe |
|---|---|
| `src/progress/profile.gd` | Profil als Dictionary, prüfen, laden und speichern (`user://profile.json`, erst in eine Zwischendatei, dann ersetzen). Testläufe nutzen `user://profile_test.json`. |
| `src/progress/talent_rules.gd` | Punkte, Stufen, Ränge, Ultimate und ihre Stufen (`staged`), Reset, Leiste, EXP |
| `src/progress/soul_drops.gd` | Boss-Level, Berechtigung, Splitter pro Bosssieg, Zusatzchance, Albtraum-Erstsieg, Kennungen |
| `src/progress/run_progress.gd` | Verbindet Run und Profil: EXP, Gold, Schwierigkeit, Bosssiege; schickt Belohnungen an die Mitspieler |
| `src/combat/talent_combat.gd` | Alle 54 Talente im Kampf: Ressourcen, Leiste, Ultimate, Buffs, Schild, Konter, Wölfe, Fallen, Giftzone, Passivboni |
| `src/ui/talent_screen.gd` | Talentmenü im Hauptmenü |
| `src/ui/run_hud.gd` | Talentleiste, Ressourcenleiste, Meldung „SEELENSPLITTER ERHALTEN!“ und Levelaufstieg |
| `src/vfx/talent_fx.gd` | Wölfe, Fallen, Zonen und kurze Effekte im Spielbild |
| `src/ui/talent_bar.gd` | Talentleiste und Belohnungsanzeige, in allen Maps gleich |
| `src/hell/hell_talents.gd` | Dieselben Talente in Frostgruft und Hölle: übersetzt Held, Gegner, Schaden, Status, Wände und HUD der Hell-Laufzeit für `talent_combat.gd`; bringt EXP, Gold, Level und Schwierigkeit dorthin |

**Mehrspieler:** Der Host entscheidet alles, was sich fälschen ließe: welcher
Gegner fiel, ob ein Held beteiligt war, Kampfdauer, Schadensanteile,
Boss-Level und den Zufallswurf. Jeder Held bekommt daraus ein
Belohnungsereignis. Sein eigenes Spiel wendet es mit denselben reinen Regeln
auf sein Profil an und speichert es; Erstsiege und gewertete
Kennungen liegen dort. Die Builds der Clients prüft der Host gegen die Regeln
(`TalentRules.repair`), bevor sie zählen.

Grenze: Es gibt keinen eigenen Server. Ein manipuliertes Spiel könnte sein
eigenes Profil-File ändern. Gegen doppelte oder erfundene Belohnungen im
laufenden Spiel schützt das trotzdem.

## Stand

| Teil | Stand |
|---|---|
| Daten, Regeln, Profil, Drops | umgesetzt, `tests/talent_progress_test.gd` (158 Prüfungen) |
| 54 Talente im Kampf der Gruft | umgesetzt, `tests/talent_combat_test.gd` (120 Prüfungen) |
| Talentmenü, HUD-Leiste, Splitter-Meldung | umgesetzt, Bilder in `production/qa/evidence/talents/` (`scripts/capture_talents.gd`) |
| Frostgruft und Hölle | Dieselben 54 Talente mit derselben Leiste (Shift + 1–4, R), EXP und Gold pro Gegner, Schwierigkeit, Splitter vom Endboss. Kristalle und Unterklassen entfallen. `tests/hell_talents_test.gd` |

## Offen

- **Merge mit main (29.10.2026, Nutzerentscheid „beides kombinieren“):** Von
  main bleiben Lauf-Baum (Taste B), Tod beendet den Lauf, Item-System 2,
  Spielstände und das einheitliche HUD. Unser Talentprofil ersetzt die
  dauerhaften Talente und Seelenkristalle von `docs/LAUF-DESIGN.de.md` 3.3:
  Keine Lauf-Baum-Knoten warten mehr auf ein dauerhaftes Talent
  (`src/hell/card_kit.gd`, `game.gd` `_apply_meta`). „Etage neu starten“
  entfällt wie bei main; R löst die Ultimate aus. Provokation durch den Wolf
  wirkt auf die Frostgruft-Gegner, aber noch nicht auf die eigenen Monster
  der Hölle (`hell_monsters.gd`).
- **Begleiter (29.10.2026):** Der Bestienmeister wählt im Talentmenü Wolf oder
  Bär (`talents.json` → `pet.kinds`, Profil `companion`). Der Bär hat 1,7× Leben
  und 1,3× Schaden, beißt 1,35× seltener und läuft 0,75× so schnell. Sprites:
  „Enchanted Forest Characters“ von Superdark, das Begleitpaket zu 0x72
  (`assets/sprites/forest_0x72/`, Lizenz: frei, auch kommerziell).
- **Talent-Test (29.10.2026, nur Debug):** Hauptmenü „TALENT-TEST (DEBUG)“
  schaltet auf ein eigenes Testprofil (`user://profile_debug.json`): jede
  Klasse Level 30, 99 Seelensplitter, 99 999 Gold, Talente ohne Kosten und
  mit 0,5 s Abklingzeit. Das echte Profil bleibt unberührt.
- **Pausenmenü:** zeigt oben rechts die Seelensplitter, in jeder Story.
- **Talentmenü (29.10.2026):** neu gestaltet mit Karten, Kopfleisten in der
  Zweigfarbe, Icons in 3×/4× Größe, Rangpunkten und Pixelify Sans für Text.
- **Icons und Effekte (29.10.2026):** Jedes Talent hat ein eigenes
  14×14-Pixelmotiv (`src/ui/talent_icons.gd`, `icon` in `talents.json`).
  Die Effekte spielen Pixel-Sheets aus `scripts/make_fx_sprites.gd`:
  Feuer-, Frost-, Arkan-, Stahl- und Schrei-Ring, Inferno-Säule, Nullpunkt,
  Sternexplosion, Schildblase, Eislanze, Arkangeschoss, Zielmarke,
  Giftwolke, Dornenfalle, Krallen (`src/vfx/talent_fx.gd`). Bilder:
  `production/qa/evidence/attacks/`.
- **Auftragsliste:** Seit 29.10.2026 eine Seite „Auftrag“ im Pausenmenü
  (`src/ui/quest_view.gd`), in Krypta, Frostgruft und Hölle gleich. Frostgruft
  und Hölle öffnen mit Esc dasselbe Pausenmenü (`src/pause_menu.gd`).
  Nutzerentscheid 29.10.2026: nur im Menü, keine extra Zeile im HUD.
- **Wolf-Grafik:** Im 0x72-Pack gibt es keinen Wolf. Der Wolf ist eine kleine
  Pixelfigur in den Farben des Packs.
- **Lokalisierung:** Wie im übrigen Spiel sind die Texte deutsch fest
  eingetragen.
- **Mehrspieler-Lauf:** Ist nur über die Regeln getestet. Ein echter Lauf mit
  zwei Spielern steht noch aus.

## Tiefere Bäume, ein Zweig, Nekromant (29.10.2026)

- **Aufbau pro Zweig:** Reihe I bis VI je zwei Talente, Reihe VII ein
  Schlussstein, Reihe VIII die Ultimate. Pro Zweig fünf bis sieben aktive
  Talente, die übrigen sind passiv. Auf die Leiste passen vier: Man wählt aus.
- **Alte Profile:** Version 1 hatte die Ultimate als `<zweig>_6`. Beim Laden
  heißt sie jetzt `<zweig>_14`. Ein Build über mehrere Zweige behält den
  Zweig mit den meisten Punkten. Talente über ihrer Reihe werden
  zurückgenommen, die Punkte kommen zurück. Kein Seelensplitter geht verloren.
- **Talentmenü:** Oben die vier Klassen. Im Baum drei Reiter für die Zweige
  („dein Zweig“, „gesperrt“, „noch frei wählbar“), darunter die acht Reihen
  mit Stufe, Level und nötigen Punkten. Rechts die Details.
- **Keine Klassenfähigkeiten:** In der Krypta liefern `ClassPerks.skills`
  nichts mehr, der Lauf-Baum (B) hat nur noch die passiven Werte. In
  Frostgruft und Hölle bietet der Lauf-Baum keine Fähigkeits-Karten mehr.
  Ob eine Welt Level, Lauf-Baum und Leiste hat, hängt dort jetzt an ihren
  Level-Regeln (`hell_game.heroic()`).
- **Nekromant:** 0x72-Figur `necromancer`, Knochenstab (rotes 0x72-Stabbild,
  Seelengeschosse). Seine Skelette nutzen die 0x72-Skelettbilder
  (`pet_kind: skeleton`). In Frostgruft und Hölle eigene Klasse mit eigenen
  Lauf-Karten.

| Zweig | Aktive Talente | Ultimate |
|---|---|---|
| Feuermagier | Flammenpfeil, Feuerring, Phönixschritt, Lavafeld, Glutkette | Inferno |
| Frostmagier | Frostlanze, Eisnova, Kristallschild, Blizzard, Splittersalve, Frostsprung | Absoluter Nullpunkt |
| Arkanmagier | Arkangeschoss, Magisches Echo, Raumsprung, Arkane Explosion, Arkanlanze, Manaschild | Zeitbruch |
| Scharfschütze | Gezielter Schuss, Durchschuss, Jägermarkierung, Salve, Rückwärtssalto, Pfeilregen | Letzter Pfeil |
| Fallensteller | Giftpfeil, Dornenfalle, Explosionsfalle, Giftwolke, Netzfalle, Rauchsprung | Todeszone |
| Bestienmeister | Tiergefährte, Fass!, Doppelschuss, Jagdruf, Raubtiersprung | Alpharuf |
| Berserker | Wutschlag, Wirbelsturm, Raserei, Ansturm, Erdspalter, Blutiger Schrei | Blutrausch |
| Schildwächter | Schildstoß, Schutzwall, Kampfgeschrei, Wächtereid, Erderschütterung, Schildwall, Vorstoß | Unbezwingbar |
| Klingenmeister | Schnittwunde, Konterschlag, Klingensturm, Fächerschnitt, Wurfmesser, Schattenschritt | Klingentanz |
| Diener (Nekromant) | Skelett erheben, Knochenspeer, Befehl, Leichenexplosion, Skelettwache, Grabessprung | Armee der Toten |
| Fluch (Nekromant) | Fluchgeschoss, Fluch der Schwäche, Lähmender Fluch, Seuchenfeld, Blutfluch, Schattenflucht | Totenfluch |
| Seele (Nekromant) | Seelenblitz, Seelennova, Seelenschild, Seelensprung, Seelenlanze, Seelensturm | Seelenexplosion |

Die Ultimates des Nekromanten haben wie alle anderen zwei Ausbaustufen:
Armee der Toten (Ewige Wacht, Knochensturm), Totenfluch (Weitreichend,
Seuchenherd), Seelenexplosion (Seelensog, Seelenstrom).

## Mana, Begleiter, Aggro und neue Ultimates (30.10.2026)

Entscheidungen des Nutzers: Mana soll spürbar sein (kein Dauerzaubern), jede
Ultimate hat rund eine Minute Abklingzeit, und jeder Zweig bekommt eine eigene
große Ultimate (Meteor, Eisblock usw.), „nicht zu broken“. Frostmagier,
Bestienmeister und Nekromant-Diener bekommen einen dauerhaften Begleiter mit
eigener Leiste.

### Mana

| Klasse | Max. | Erholung |
|---|---|---|
| Magier | 120 Mana | +3 / s |
| Nekromant | 100 Mana | +2,5 / s |
| Bogenschütze | 100 Ausdauer | +5 / s |
| Krieger | 100 Zorn | durch Treffer |

- Das TALENT-TEST-Profil kostet jetzt Mana und hat echte Abklingzeiten.
- Jede Ultimate hat 60 s Abklingzeit (`ultimate_cd`) und kostet bei Mana-Klassen 40 Mana. Abklingzeit-Talente und Zeitbruch wirken nicht auf sie.

### Dauerhafte Begleiter (`talents.json` → `pet`)

| Zweig | Talent | Begleiter | Taste 5 | Taste 6 |
|---|---|---|---|---|
| Frost | `frost_3` Wasserelementar (ersetzt Eisnova) | Wasserelementar, schießt aus 5 m | Eislanze (60 %, verlangsamt) | Frostnova (40 % in 3 m, friert 1,5 s) |
| Bestienmeister | `beast_1` Tiergefährte | Wolf / Bär | Zerfleischen / Prankenhieb | Heulen / Brüllen (verspotten) |
| Diener | `minion_1` Knochenkrieger (ersetzt Skelett erheben) | Knochenkrieger | Schildschlag (betäubt 1 s) | Knochenschrei (verspotten) |

- `frost_4` heißt jetzt Elementarbund (+Leben, +Schaden des Elementars).
- Ein gelernter Begleiter steht ab Laufbeginn da, kommt in jeden Raum mit und springt zum Helden zurück, wenn er mehr als 14 m entfernt ist. Nach 4 s ohne Kampf heilt er 8 % pro Sekunde.
- Er greift Gegner an, die seinen Helden angreifen, sonst den nächsten in 6 m.
- Ist er tot, bleibt er tot, bis das Talent erneut gewirkt wird (30 s Abklingzeit, Mana). Solange er lebt, sperrt das Talent („Begleiter lebt noch“).
- Tasten 5/6 (Eingabe-Bits 9/10) lösen die Fähigkeiten aus. Ein Rechtsklick aufs Symbol (Bits 11/12) schaltet Auto. Bei Auto setzt der Begleiter die Fähigkeit im Kampf selbst ein, sonst macht er nur normale Angriffe. Bei Auto laufen zwei helle Funken um das Symbol.
- HUD: Der Begleiter-Balken steht unter dem Heldenstreifen (`HudKit.pet_panel`), dazu ein kleiner Balken über dem Begleiter.
- Sprites: Wasserelementar und Knochenkrieger sind im 0x72-Stil neu gezeichnet (`scripts/make_companion_sprites.py` → `assets/sprites/companions/`). Der Knochenkoloss nutzt `big_zombie` aus dem Archiv.

### Aggro nach Schaden

- Jeder Gegner führt eine Liste `threat` (Held: Peer-ID, Begleiter: `PET_KEY - pet.id`). Er greift an, wer ihm am meisten Schaden gemacht hat.
- Ein Wechsel braucht 10 % mehr (`pet.threat.switch_pct`).
- Verspotten geht vor. Bosse bleiben beim nächsten Helden und lassen sich nicht verspotten.
- Gegner, die einen Begleiter angreifen, verletzen ihn in Reichweite: 0,8 Leben/s, Nebenbosse 2/s.

### Die 12 Ultimates

| Zweig | Ultimate | Grundform | Stufe 2 | Stufe 3 |
|---|---|---|---|---|
| Feuer | Meteor | nach 1 s 300 % in 4 m, Krater brennt 4 s | Krater 4,5 m, 7 s | 3 kleine Meteore (je 80 %) |
| Frost | Gletschergrab | Eisblock 4 m, 8 s: 25 %/s, 60 % langsamer, Mitte friert 2 s | +3 s, +1 m | zerspringt: 200 % in 5 m, friert 2 s |
| Arkan | Singularität | zieht 4 s in 5 m (nicht Bosse), 30 % je 0,5 s, am Ende 180 % | 7 m, stärkerer Sog | 250 % in 6 m, alle anderen Fähigkeiten laden nach |
| Scharfschütze | Himmelsspeer | Linie 14 m, 350 %, immer kritisch | +20 % Schaden 6 s auf Getroffene | 200 % in 4 m am Ende der Bahn |
| Fallensteller | Jagdgrund | Netz hält 2,5 s in 4 m, 3 Fallen | 5 Fallen, +1 s | Fallen hinterlassen Giftwolken |
| Bestienmeister | Wildes Erwachen | Begleiter 12 s riesig: ×2 Schaden, +50 % Leben, Flächenbisse, verspottet in 5 m | +4 s, heilt zur Hälfte | 2 Geisterwölfe für 10 s |
| Berserker | Erdspalter | Sprung, 280 % in 4 m, 8 s +25 % Schaden | Aufprall betäubt 1,5 s | zweite Welle 150 %, 15 % Lebensraub |
| Schildwächter | Bollwerk | verspottet in 6 m 4 s, 8 s −50 % Schaden, immun | Dornenschild: Nahkampf-Angreifer nehmen 100 % | am Ende 250 % in 5 m |
| Klingenmeister | Klingensturm | 4 s, alle 0,4 s 50 % in 3 m, laufen möglich | Blutung | 6 Geisterklingen je 100 % |
| Diener | Knochenkoloss | 20 s, verspottet in 5 m, 120 % in 2 m alle 1,5 s | +10 s, mehr Leben | zerfällt: 200 % in 4 m |
| Fluch | Seuchengrube | 5 m, 8 s: 30 %/s, Gift, Gegner darin −25 % Schaden | Gefallene stehen 10 s als Skelett auf (max. 4) | +2 m, +4 s |
| Seele | Seelenernte | 200 % in 6 m, je Treffer 2 % Leben und 4 Mana, normale Gegner unter 15 % sterben | +2 m | zweite Welle 150 % in 8 m, alle anderen Fähigkeiten laden nach |

Bosse frieren nie ein, werden nicht festgehalten, nicht gezogen und nicht
sofort getötet, sie werden stattdessen verlangsamt. Die neuen Effekt-Sheets
(`meteor`, `ice_block`, `vortex`, `net`, `sky_spear`, `soul_wisp`) erzeugt
`scripts/make_fx_sprites.gd`.

Tests: `tests/talent_pet_test.gd` (Begleiter, Aggro, HUD) und die Ultimate-
Prüfungen in `tests/talent_combat_test.gd`. Bilder:
`production/qa/evidence/pets-ultimates/`.

### Eigene Animationen für die aktiven Talente (30.10.2026)

Jeder Zweig sieht jetzt eigen aus. `scripts/make_fx_sprites.gd` zeichnet 22
weitere Sheets im 0x72-Stil. `src/vfx/talent_fx.gd` ordnet sie in den Tabellen
`TALENT_SHOTS`, `TALENT_RINGS`, `TALENT_BURSTS`, `TALENT_BLINKS`,
`TALENT_DASHES`, `TALENT_SWINGS` und `TALENT_CASTS` den Talenten zu. Felder
wählen ihr Aussehen über `look` in `talents.json`: Schnee, Pfeile, Seuche,
Seelen, Eis und Arkan.

| Zweig | Neu |
|---|---|
| Feuer | Glutkette als Magmabolzen |
| Frost | Splittersalve als Eissplitter, Blizzard mit Schneetreiben |
| Arkan | Arkanlanze, Arkane Explosion mit Arkan-Explosion, Manaschild in Lila |
| Scharfschütze | Rückwärtssalto als Rauchwolke, Pfeilregen mit fallenden Pfeilen |
| Fallensteller | Giftpfeil als grüner Pfeil, Rauchsprung als Rauchwolke |
| Bestienmeister | Raubtiersprung mit Krallen |
| Berserker | Wutschlag und Erdspalter mit Wut-Hieb, Erdspalter dazu mit Steinsplittern, Blutiger Schrei mit Blutring, Ansturm mit Staubspur |
| Schildwächter | Schildstoß und Schildwall in Gold, Erderschütterung mit Bebenring, Vorstoß mit Goldschild |
| Klingenmeister | Wurfmesser dreht sich, Schnitte mit Blut, Schattenschritt als Schattenwolke |
| Diener | Knochenspeer, Leichenexplosion und Grabessprung mit Knochensplittern, Skelettwache |
| Fluch | Fluchgeschoss als grüner Totenkopf, Blutfluch als Blutkugel, Fluch der Schwäche mit Totenkopf über dem Ziel, Lähmender Fluch mit Fluchring |
| Seele | Seelenblitz, Seelenlanze, Seelennova, Seelenschild, Seelensprung, Seelensturm mit kreisenden Seelen |

Bilder: `production/qa/evidence/talent-anims/` (`00-uebersicht.png` zeigt alle 12 Zweige).

### Feuermagier nach dem Konzeptblatt (30.10.2026)

Der Nutzer hat ein Konzeptblatt („Feuermagier · Animations-Konzept“) und ein
Bild des Talentmenüs geschickt. Die Figur des Magiers bleibt der jetzige
0x72-Pixelmagier. Übernommen werden die Attacken, die Namen und das
Menü-Layout.

| Reihe | Aktiv (links) | Passiv (rechts) |
|---|---|---|
| I | Feuerball (`fire_1`): explodiert beim Einschlag, die Hälfte des Schadens in 1,5 m | Glutbeherrschung |
| II | Flammenwall (`fire_3`, neuer Typ `wall`): 5 m lange Feuerwand quer zum Blick, 4 s | Schwelende Glut |
| III | Phönixschritt (`fire_5`): Flug als Phönix, Schaden am Start und bei der Ankunft | Brennende Seele (heilt pro Kill) |
| IV | Lavafeld (`fire_7`): 3 m, 6 s, 145/165/185 % über 6 s, 30 % langsamer | Glutpanzer |
| V | Infernospeer (`fire_9`, vorher passiv „Pyromanie“): durchbohrt alles | Feuerfluss |
| VI | Glutkette (`fire_11`, neuer Typ `chain`): springt bis zu 4-mal, je 15 % schwächer | Zündfunke |
| VII | Feuerseele | |
| VIII | Meteor (Ultimate), mit Zielrune | |

Animationen (`scripts/make_fx_sprites.gd`): `fire_charge` (Ladung am Stab),
`fire_spear`, `phoenix`, `flame_tongue` (Flammen der Wand), `lava_pool`,
`rune_circle`. Dazu kommen die Explosion des Feuerballs, die gezackte Glutkette und die Glutspur
des Phönix in `src/vfx/talent_fx.gd`. Neue Symbole: `fireball`, `flamewall`,
`phoenix`, `lava`, `chain`.

Talentmenü (`src/ui/talent_screen.gd`) für alle Zweige im Konzept-Look:
- Zweig-Banner oben.
- Reihen-Tafeln I–VIII links mit Level und Punkten.
- In der Mitte aktive Talente links und passive rechts, verbunden über eine Raute auf der leuchtenden Mittelachse.
- Reihe VII und die Ultimate auf der Achse.
- Rechts das Detailfeld mit großem Symbol, Rang-Punkten, Text, Werte-Tabelle (Kosten, Abklingzeit, Dauer, Verlangsamung, Radius, Sprünge), Voraussetzung, rotem Hinweis und Bronze-Knöpfen.
- Der Hintergrund ist in der Zweigfarbe getönt, mit aufsteigender Glut.

Bilder: `production/qa/evidence/fire-mage/`.

### Zweite Runde Feuermagier (30.10.2026)

- **Mana:** Magier und Nekromant erholen 0,67 Mana pro Sekunde, also etwa 2 Mana alle 3 s. Eine Taste ohne genug Ressource zeigt „Wenig Mana“, „Wenig Ausdauer“ oder „Wenig Zorn“ über dem Helden (Ereignis `no_res`, höchstens alle 0,8 s).
- **Leiste:** Die Felder sind jetzt 56 px groß, die Symbole 44 px (`ui_run_hud.json`).
- **Feuerball:** Neues großes Sheet `fireball_big` (40 px, 8 Bilder) und die Explosion `fire_explosion` (96 px, 10 Bilder: Blitz, Feuerball, Flammenring, Rauch).
- **Skillen im Lauf:** **K** öffnet das Talentmenü in Krypta, Frostgruft und Hölle. Solo steht das Spiel still. Ein neuer Build gilt sofort. `set_build(..., keep = true)` behält Mana und Abklingzeiten, damit Umskillen nichts auffüllt.
- **Figur:** Der Magier ist jetzt der Pyromant vom Konzeptblatt (`scripts/make_pyromancer.py` → `assets/sprites/0x72/custom_pyromancer_*`, 16×28 wie die 0x72-Helden). In der Krypta zeichnet er seine Bilder direkt, ohne das alte Rig.

Bilder: `production/qa/evidence/fire-mage/08`–`12`, `00-pyromant.png`.

### Falke, Tierfähigkeiten, Pfeilhagel und Meteor (30.10.2026)

- **Falke:** Der Bestienmeister wählt im Talentmenü jetzt zwischen Wolf, Bär und Falke (`pet.kinds.falcon`). Der Falke hat 70 % Leben, macht 115 % Schaden, greift schneller an (`every` 0,8) und fliegt (`flying`). Er wird über seinem Schatten gezeichnet. Das 0x72-Archiv hat keinen Vogel, deshalb zeichnet `scripts/make_falcon.py` ihn im Stil des Forest-Packs (32×32, 4 Flügelschläge) nach `assets/sprites/companions/falcon_*`.
- **Falkenfähigkeiten:**
  - **Sturzflug** (`dive`) springt auf einen Gegner bis 6 m: 130 % Schaden und Blutung.
  - **Augenhacker** (`blind`) macht 40 % Schaden und blendet. Normale Gegner stehen 2 s still, Bosse sind 3 s um 40 % langsamer.
- **Wolf und Bär:** Zerfleischen verlangsamt jetzt zusätzlich um 40 % für 3 s. Der Prankenhieb lässt alle Getroffenen bluten.
- **Wunden sichtbar:** Jede Blutung durch einen Begleiter zeigt Blut, jede Blendung kreisende Sterne (Ereignis `pet_strike`). Der Sturzflug zieht eine Federspur (`dive`).
- **Pfeilhagel** (vorher Pfeilregen, `sniper_11`): Der Radius ist von 3 auf 4 m gewachsen. Große Hagelpfeile (`hail_arrow`) fallen über dem ganzen Feld und schlagen mit Staub, Splittern und steckendem Pfeil ein (`arrow_impact`). Zum Schluss landet die letzte Salve auf einmal, mit Staub-Druckwelle (Ereignis `arrow_finale`). Pfeilhagel bleibt beim Scharfschützen, nicht bei den Tiergefährten.
- **Meteor** (`fire_14`):
  - Neues Sheet `meteor_big` (64×96, 8 Bilder): ein taumelnder Fels mit glühenden Magmarissen in einem dicken Feuerschweif.
  - Der Einschlag `meteor_impact` (128 px, 12 Bilder) zeigt Blitz, Feuerkuppel, Feuerpilz, Staub-Druckwelle, fliegende Brocken und Rauch.
  - Danach bleibt ein Krater (Zonen-Look `crater`) mit Lava, glühenden Rissen, Flammen und Rauch.
  - Die kleinen Meteore des Schauers explodieren wie Feuerbälle.
- **Feuerball:** Das Sheet ist jetzt 48 px groß, mit weiß glühendem Kern und Hitzeschein. Im Flug fällt Glut hinter ihm ab. Die Explosion wirft zusätzlich Funken (`fire_sparks`), hinterlässt Rauch und einen Brandfleck.

Bilder: `production/qa/evidence/falcon-hail-meteor/` (`scripts/capture_falcon_hail_meteor.gd`).

### Flammenmeer, Pyro-Monster, Abwehr auf Shift, Begleiter-Ziele, Karten (30.10.2026)

Entscheidungen des Nutzers: Das Lavafeld wird zum gezogenen Flammenmeer, das Pyro-Monster ersetzt den Flammenwall, die Abwehr liegt auf **Shift**, und jede Klasse bekommt eine.

- **Flammenmeer** (`fire_7`, Typ `drawn`):
  - Taste halten und mit der Maus eine Linie ziehen, bis zu 10 m lang. Eine Füllleiste an der Spitze zeigt die Restlänge.
  - Die Linie entsteht beim Loslassen, wenn die Länge aufgebraucht ist oder nach 2,5 s. Ein kurzes Antippen legt 3 m quer zur Blickrichtung.
  - Die Linie brennt 6 s, alle 0,5 s 12/14/16 %, dazu Brennen und 30 % langsamer.
  - Code: `talent_combat.hold()` → `_draw_step` → `_finish_draw`, Zonen mit `path`; im Bild `talent_fx` mit den Looks `flames` und `_draw_line_preview`.
- **Pyro-Monster** (`fire_3`, `pet.kinds.pyro`):
  - Ein dauerhafter Feuerbegleiter mit Glutfaust (90 % und Brennen) und Feuerkreis (60 % in 2,5 m und Brennen).
  - Gezeichnet von `scripts/make_companion_sprites.py` → `assets/sprites/companions/pyro_*`.
- **Begleiter-Ziele** (`_pet_prey`):
  - Zuerst das Ziel, das der Held selbst angreift (`hero_target`), sonst das aktuelle Ziel, sonst ein Gegner, der auf den Helden oder den Begleiter geht.
  - Der Begleiter bleibt am Gegner, bis er tot ist, egal wie weit der Held läuft. Erst ohne Kampf kommt er zurück; das Teleportieren gibt es nur außerhalb eines Kampfes.
- **Abwehr auf Shift** (`talents.json` → `defense`, Bit `DEFEND_BIT` 13):
  - Bogenschütze **Ausweichen**: 3 m Rolle in Laufrichtung, 0,4 s unverwundbar, 2 Ladungen, eine pro 4 s zurück.
  - Magier **Magischer Block**, Krieger **Schildblock**, Nekromant **Knochenschild**: gehalten fangen sie ganze Treffer. Nach 2 Treffern zerbrechen sie für 8 s. Gesenkt kommt alle 3 s ein Treffer zurück.
  - Im Bild: eine Blase mit Punkten für die übrigen Treffer, Risse nach einem Treffer, Splitter beim Bruch.
  - In der Leiste steht ein eigenes Feld **SH** mit Punkten.
- **Beschreibung beim Überfahren:** Jedes Feld der Leiste zeigt eine Karte mit Name, Text, Kosten und Abklingzeit (`SkillBar._card`).
- **Linksklick des Magiers:** ein kleiner Feuerball mit Glutspur, der am Gegner und an der Wand platzt (Krypta: `dungeon_view` und `feedback`; Hölle: Schuss `pyro`, `talent_fx.draw_basic_fireball`).
- **Fehler behoben:** Die Krypta hat die Tasten-Bits auf 511 begrenzt. Die Tasten 5 und 6 (Bit 9 und 10) wurden dadurch zu „1–4 und R gleichzeitig“. Jetzt ist die Grenze 16 Bit; der Test `test_keys_five_and_six_keep_their_own_bits` schlägt mit dem alten Code fehl.

Tests: `tests/talent_defense_test.gd` (30 Prüfungen) und die angepassten Talent-Suiten. Bilder: `production/qa/evidence/round3-flammenmeer-block/` (`scripts/capture_round3.gd`).
