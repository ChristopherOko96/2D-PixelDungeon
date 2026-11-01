# Gameplay-Bewertung „Delve Disaster“: Items, Identifizieren, Flüche, Funde

Stand 2026-11-01 · Rolle: Game Designer · Fokus: Story-Welten (Krypta, Frostgruft, Hölle über `hell_game.gd`)
Grundlage: Daten und Code (unten), Vergleich mit bekannten Roguelikes (Quellen am Ende). Kein Spieltest, keine Telemetrie.

## 0. Gesamturteil

**KRITISCH in einem Punkt, sonst BEDENKEN.**

- Kritisch: Der **Nekromant findet nie eine Waffe, die er tragen kann.** In `items.json` gibt es für ihn nur `bone_staff`
  (die Startwaffe). `inventory.gd _roll_weapon` greift dann auf Waffen *aller* Klassen zurück, und `_equip`
  lehnt sie ab („Nur für …“). Für ihn ist also jeder Waffenfund wertlos (25 % aller Truhenfunde, 50 % der Wächter-Beute).
- Bedenken: Es gibt zu wenige Tränke für ein Erkennungsspiel mit 12 Sorten. Mimiks bringen in den Story-Welten keine Beute.
  10 der 24 Trank-Aktionen sind nach dem Erkennen keine echte Wahl mehr. Tränke kann man nur über das Inventar benutzen,
  und das Spiel läuft dabei weiter. Das treibt zum Horten. 5 der 9 F-Fähigkeiten doppeln ein Verb, das die Klasse schon hat
  (3 davon tragen sogar denselben Namen).
- Ziele: `design/gdd/` hat kein Item-GDD, `design/registry/entities.yaml` ist leer. Abweichungen von Zielwerten sind
  deshalb **NICHT BEURTEILT – KEINE ZIELE**. Ich messe gegen die Absichten in `docs/ITEM-SYSTEM-V2.de.md` („Jeder Fund ist eine
  kleine Wette“) und `docs/LAUF-DESIGN.de.md` („Funde und Punkte sind Entscheidungen, keine Selbstläufer“, „mindestens 2 Truhen“).

## 1. Datenquellen und Grenzen

Gelesen: `assets/data/items.json`, `assets/data/armor_powers.json`, `assets/data/hell_balance.json`,
`assets/data/frost_talents.json` (Unterklassen-Fähigkeiten), `assets/data/hero_skills.json` (Lauf-Baum-Knoten),
`src/items/inventory.gd`, `src/hero/story_items.gd`, `src/hell/hell_game.gd` (Truhen, Tresor, Siegel, Wächter, Mimik),
`src/world_kit/world_pack.gd` und `world_core.gd` (wo Truhen stehen), `docs/GEGENSTAENDE.de.md`,
`docs/ITEM-SYSTEM-V2.de.md`, `docs/LAUF-DESIGN.de.md`, `docs/HELL-DUNGEON.de.md`.

Grenzen:
- **Funde je Etage sind geschätzt**, nicht gemessen: Truhen pro Etage aus dem Generator abgeleitet (siehe 3.4).
  Empfehlung R14 macht daraus eine Messung.
- Der Fix von heute (Heilung, Brand und Gift über Zeit, Sprengtrank, Fluchschaden) ist berücksichtigt.
  Zahlen zu Ticks (3.1) bitte gegen den neuen Stand prüfen.
- Die Recherche hat vor allem Wikis und Spieler-Guides gefunden, keine Entwickler-Changelogs von Shattered PD oder DCSS.
  Was ich aus eigener Spielkenntnis ergänze, ist mit **(K)** markiert und war in dieser Sitzung nicht per Link prüfbar.

## 2. Was in anderen Spielen funktioniert

| Thema | Spiel und Regel | Lehre für uns |
|---|---|---|
| Farbe → Wirkung pro Lauf, Erkennen durch Benutzen | **Isaac**: Pillen sind unbekannt („???“), jede Farbe hat pro Lauf eine feste Wirkung, die erste Einnahme zeigt sie für alle Pillen dieser Farbe; PHD zeigt sie sofort. [Isaac-Wiki: Pills] | Das ist genau unser Modell. Es trägt, weil Pillen häufig sind und es Gegenstände gibt, die das Risiko ändern (PHD). |
| Gut/Böse-Hinweis vor dem Erkennen | **Brogue**: Detect Magic markiert jedes Item der Etage als gut, böse oder neutral; Tränke, die als böse markiert sind, wirft man. Throw-ID wird empfohlen, sobald die wichtigen guten Tränke bekannt sind. [Brogue-Wiki Guide] | Ein **Teilhinweis** (gut/böse) macht das Raten zur Abwägung, ohne es zu beenden. |
| Schlechte Tränke werfen | **Brogue, Shattered PD**: Bekannte schädliche Tränke sind Wurfwaffen gegen Gegner, die im Nahkampf zu stark sind. In SPD zerplatzen Tränke beim Aufprall. [SPD-Guides, Steam-Forum] | Unser Wurfteil für Feuer/Eis/Gift/Blend/Spreng ist richtig. |
| Früh probieren | **SPD**: Guides raten, unbekannte Tränke früh zu trinken, weil schädliche Tränke in den ersten Etagen weniger anrichten und man weniger verliert. [SPD Beginner’s Guide] | Probieren muss in Etage 1–3 bezahlbar sein: dort gezielt Tränke und einen Fluchbrecher hinlegen. |
| Sicherer probieren | **SPD**: Exotische Tränke machen das Erkennen sicherer. [SPD-Quick-Guide] | Es braucht billige Wege, das Risiko zu senken, nicht nur Kristalle. |
| ID als Mühe | **DCSS-Forum**: Spieler fordern, das Erkennen ganz zu streichen; es bringe fast nur Mühe, nur Flüche seien ein echter Grund. DCSS hat 0.25 (2020) Flüche und Fluch-Entfernung gestrichen **(K)**. [Crawl-Forum, Dev-Blog 05/2020] | Erkennen darf nie zur Pflichtarbeit werden. Wer es behält, braucht Flüche, die echte Entscheidungen erzeugen (bei uns: Fluch → Segen, das ist gut). |
| ID als Geheimnis | **Roguelike-Analyse (Gamasutra)**: Unbekannte Items lassen die Welt geheimnisvoll wirken und lösen den Fortschritt vom reinen Würfelglück; Spielerwissen wird zu Macht. [Eight Rules] | Unser Pro-Lauf-Mischen ist richtig. Es braucht nur genug Wiederholungen, damit sich Wissen auszahlt. |
| Fluch-Prüfung billig | **NetHack**: Ein Item auf einen Altar legen zeigt verflucht/gesegnet; Preise im Laden verraten die Trankgruppe; „remove curse“ als Schriftrolle. [NetHackWiki Potion, Remove curse] **(K für Altar/Preise)** | Ein **Ort** im Dungeon, der Flüche zeigt, ist eine billige, spannende ID-Quelle (bei uns: Schrein-Räume). |
| Fluchrate | **SPD** würfelt Waffen grob zu 30 % verflucht **(K, Quelltext `Weapon.random`)**; NetHack grob 10 % bei vielen Item-Arten **(K)**. | 60 % bei uns heißt: „unbekannt = verflucht“. Das ist kaum noch eine Wette. |
| Horten | **Design-Artikel**: Verbrauchsgüter billig und häufig machen; Gegenstände vermeiden, die immer die beste Wahl, aber zu selten zum Benutzen sind; verlässlichen Nachschub geben. [Gamasutra „Hoarders“, Game-Wisdom ×2] | Mehr Tränke, Heilung häufiger, kleine Wurf-/Trinkwerte statt seltener Riesenwerte. |
| Benutzen auf einer Taste | **Isaac**: Pille/Karte auf Q, aktives Item auf Leertaste, lädt sich pro geschafftem Raum auf; **Gungeon**: Blanks auf Q, zu Beginn jeder Etage wieder auf 2 aufgefüllt; **Hades**: Cast-Kristalle sammelt man im Kampf wieder auf **(K)**. | Eine Taste senkt die Hürde im Kampf. Nachschub pro Etage oder pro Raum verhindert das Horten. |

## 3. Bewertung der Systeme

### 3.1 Tränke: Trinken gegen Werfen (Werte aus `items.json`, Held hat 12 halbe Herzen, `hell_balance.json`)

| Trank (id) | Trinken | Werfen | Urteil |
|---|---|---|---|
| `healing` | +4 halbe Herzen (⅓ vom Start) | +2 nur für Helden im Radius 80; Begleiter zählen nicht (`game.players` = nur der Held) | Trinken klar besser, Wurf fast sinnlos |
| `strength` | Schaden ×1,4 für 20 s | „zerplatzt wirkungslos“ | Wurf tot |
| `haste` | Laufen ×1,35 für 15 s; **kein** Angriffstempo (`speed_mult`) | wirkungslos | schwächster gute Trank, Wurf tot |
| `shield` | 2 Abwehrladungen ohne Zeitlimit, **stapelbar** (`runtime.shield += 2`) | wirkungslos | stark; horten und vor dem Boss stapeln lohnt sich |
| `regeneration` | 6 halbe Herzen über 18 s | Regeneration für Helden im Radius 80 | gut, Wurf nur für sich selbst |
| `aftershock` | ganzer Lauf: `blast` +0,3, stapelt | 3 × 3 Schaden | bekannt trinkt man ihn immer |
| `chainlight` | ganzer Lauf: `storm` +0,35, stapelt | 4 Schaden an höchstens 4 Gegnern | bekannt trinkt man ihn immer |
| `fire` | brennt 4 s | Feuerpfütze r64, 5 s, 2 dps + Brand | Wurf gut, Trinken tot |
| `ice` | 6 s Laufen ×0,6 **und Schaden ×0,5** (`weak`) | friert r72 für 2,5 s ein, macht Glatteis | Wurf sehr gut, Trinken tot |
| `blind` | 10 s fast blind | Taumeln r84 für 4 s (Boss 35 %) | Wurf gut, Trinken tot |
| `poison` | Gift 5 s | Giftpfütze r72, 5 s, 1,5 dps | Wurf gut, Trinken tot |
| `explosion` | 3 Schaden an dir, sonst nichts | 12 Schaden r92 | Wurf sehr gut, Trinken tot |

- **10 von 24 Aktionen sind nach dem Erkennen keine Wahl mehr**: 3 tote Würfe, 2 Würfe, die immer schlechter sind,
  5 tote Trinkoptionen. Vor dem Erkennen ist das gewollt (das Risiko des Probierens, wie in Brogue/SPD). Danach bleibt
  im Fenster aber nur ein sinnvoller Knopf.
- **Lauf-Tränke stapeln** und sind genauso häufig wie Heilung. Sie bestimmen einen Lauf und sollten seltener sein.
- **Text passt nicht zur Regel** (nach dem Fix prüfen): `poison` sagt „5 s ein halbes Herz pro Sekunde“ (= 5). `apply()`
  tickt aber alle 1,5 s (≈ 3). `ice` sagt „Angriffe langsamer“, der Code halbiert den *Schaden*. `haste` sagt „35 % schneller“
  und meint nur das Laufen.
- Trinken unbekannt: 5 von 12 schaden (42 %). Für ein Probier-Spiel ist das in Ordnung, wenn es frühen, billigen Nachschub gibt.

### 3.2 Identifizieren

- **Es gibt zu wenige Tränke, damit sich Wissen auszahlt.** Tränke kommen in den Story-Welten nur aus Truhen (Anteil 3/16
  der Funde) und aus Dämonensiegeln (ab Etage 4). Geschätzt sind das **0,7–1,2 Tränke je Etage, also etwa 7–12 im Lauf**.
  Alle 12 Sorten sind gleich wahrscheinlich (`_roll_kind`: `randi_range`). Bei 9 Tränken sieht man im Mittel
  12 × (1 − (11/12)^9) ≈ **6,5 Sorten**, nur etwa **2,5 Tränke treffen eine schon bekannte Farbe**. **Heiltränke: im Mittel
  0,75 pro Lauf.** Das Erkennen ist also nicht mühsam, aber fast bedeutungslos: Man lernt eine Farbe und sieht sie selten wieder.
- Kristall: 1 fest je Etage plus Truhen-Funde, etwa 1,5 je Etage. Dem stehen etwa 3 unbekannte Ausrüstungsstücke und
  1 Trank je Etage gegenüber. Kristalle sind also knapp, das ist eine echte Wahl. Gut so.
- Ausrüstung: Anlegen erkennt sofort, riskiert aber einen klebenden Fluch. Der Kristall dient vor allem als Fluch-Test.
  Das ist sauber und nicht mühsam.
- Spiegelkristall: zeigt nur die Tränke im Rucksack. Weil Tränke stapeln und selten sind, zeigt er meist 1–2 Sorten.
  Dann ist er kaum besser als ein Kristall, aber genauso selten (Gewicht 0,6). Ein schwacher Fund.
- Es gibt keinen **Teilhinweis** (gut/böse) und kein **Ausschlussverfahren** (die letzte unbekannte Farbe bleibt unbekannt,
  obwohl sie feststeht).

### 3.3 Flüche und Segen

- Fluch → Segen beim Brechen ist eine starke eigene Idee: Ein verfluchtes Stück plus Stein ist eine Investition.
  Das ist besser als in DCSS oder NetHack, wo der Fluch nur weg ist.
- **Rate**: Waffe 60 %, Rüstung 50 %, Ring 45 %, Amulett 35 % (`curse_by_slot`). Bei 60 % liest man „unbekannt = verflucht“.
  Das ist kaum noch eine Wette (SPD grob 30 % **(K)**). Der Wunsch „oft verflucht“ steht in `docs/GEGENSTAENDE.de.md`.
  Deshalb ist die Rate unten eine Stellschraube für dich, kein Muss.
- **Stärke ungleich**: `night` (Licht schwächer) und `sluggish` (Laufen ×0,8) sind milde.
  `bloodthirst` (1 Schaden alle 25 s) kostet etwa 2,4 halbe Herzen pro Minute. Auf einer 6–10 Minuten langen Etage ist das
  mehr als das ganze Leben (12). Ohne Stein und Heilung ist das ein Lauf-Ende. `fragile` (+1 je Treffer) **verdoppelt**
  den Schaden normaler Monster (`hit_mob` 1 → 2). `sealed` nimmt eine ganze Fähigkeit.
- **Steine**: fest auf Etage 2, 4, 6, 8 und **10** (`stone_every: 2`, `floor % 2 == 0`). Auf Etage 1 gibt es keinen,
  auf Etage 10 ist er nutzlos. Wer früh probiert, wird also bestraft, gerade dann, wenn das Spiel das Probieren lehren sollte.
- Geschätzt kommen etwa 8–10 Steine und etwa 15 verfluchte Funde in einen Lauf. Das reicht, weil man nicht alles anlegt.
- Es gibt **keinen Notausgang**: Ein klebender Fluch bleibt bis zum nächsten Stein. Das ist fair, solange Steine verlässlich kommen.
  Mit Etage 1 ohne Stein ist es das nicht.

### 3.4 Fundtempo über 10 Etagen

Truhen je Etage (geschätzt aus `world_pack.gd` und `world_core.gd`): Portalraum 1, Schatzraum 1, Geheimräume 0–2,
Kampfräume je 35 %. In Hölle und Krypta sind davon 60 % Mimiks (`mimic_fight`), in der Frostgruft 0 %.
Das ergibt etwa **4–6 echte Truhen** (Hölle/Krypta) bzw. **7–9** (Frostgruft); jede gibt mit 70→90 % einen Fund.

| Quelle (Story-Welten) | Was | Bemerkung |
|---|---|---|
| Truhe (`chest`) | 1 Fund: Waffe 25 %, Ausrüstung 19 %, Trank 19 %, Kristall 12,5 %, Stein 6 %, Rest Steine/Siegel | die erste Truhe der Etage bringt Kristall + Stein (gerade Etagen) |
| Riesentresor (`gold_crate`) | Waffe/Ausrüstung selten+ und Kristall + Stein | nur wenn alle Feuerschalen brennen |
| Dämonensiegel (`crate`) | 14→24 % ein Fund | ab Etage 4, 3–4 je Etage |
| Etagen-Wächter (`mimic`) | Waffe/Ausrüstung selten+ (100 %) | auf Etage 10 nichts (der Lauf ist gewonnen) |
| Mini-Wächter | Ausrüstung/Waffe selten+ | |
| **Mimik-Truhe** | **nichts außer der normalen Raumbelohnung** | in `hell_game.gd` ruft der Mimik-Kampf kein `loot` auf |
| Urnen/Fässer/Kisten | nur Runensteine, Herz oder Untote | keine Items |

- Seltenheit wächst linear (`rarity_weights`). Episch oder besser: Etage 1 → 4 %, Etage 4 → 14 %, Etage 7 → 24 %, Etage 10 → 34 %.
  Weil der Wächter jeder Etage selten+ garantiert, gibt es pro Etage einen Höhepunkt. Das passt zum Sägezahn-Muster
  (Spannung, Belohnung am Boss, neues Niveau) und ist **gesund**.
- **Mimiks** sind in Hölle/Krypta 60 % der Kampfraum-Truhen und zahlen nichts. Spieler lernen: „Truhen in Kampfräumen
  sind Fallen.“ Das kostet Funde und widerspricht dem Gefühl „jeder Fund ist eine Wette“ (in der alten Krypta gab der Mimik selten+).
- **Power-Rüstungen** kommen geschätzt etwa 1 Mal pro Etage (Extrawurf: Truhe 10 %, Wächter 35 %, Tresor 20 %,
  Mini 50 %, plus der normale Ausrüstungswurf, wo 5 von 8 epischen Stücken Klassenrüstungen sind). Bei 2 Rüstungen
  je Klasse (Magier 3) hat man die Wahl schon um Etage 2–3 gesehen. Danach sind sie kein Ereignis mehr.
- Legendäre Waffen: Schwertkämpfer 4, Bogenschütze 1, Magier 1, Nekromant 0. Für Bogen und Magier ist „legendär“
  immer dasselbe Stück.

### 3.5 F-Rüstungen gegen Talente

| F-Fähigkeit (Rüstung) | Was die Klasse schon hat | Befund |
|---|---|---|
| SCHILDWALL (`bulwark_harness`, 3 s, Abklingzeit 14 s) | Unterklasse Schwertkämpfer `ta_wall` **SCHILDWALL** (4 s, 9 s) | gleicher Name, und die F-Version ist **in allem schlechter** |
| BLUTRAUSCH (`berserker_cuirass`) | Unterklasse `ax_rush` **BLUTRAUSCH** (6 s) und Lauf-Baum-Knoten **BLUTRAUSCH** (Rage) | dreimal derselbe Name, drei Regeln |
| KNOCHENSCHILD (`grave_bone_plate`) | Unterklasse Nekromant `ne_shield` **KNOCHENSCHILD** | gleicher Name, ähnliche Rolle |
| LEERENSCHRITT (`void_vestment`, 330 px, 9 s) | Fähigkeit 3 BLINZELN (180 px, 7 s) | zweites Blinzeln, das F-Blinzeln ist besser |
| SCHATTENSPRUNG (`ranger_cloak`) | Fähigkeit 3 RÜCKSPRUNG | zweiter Ausweichsprung |
| PFEILHAGEL, FLAMMENKREIS, EISPANZER, SEELENSOG | – | eigene Verben, gut |

5 von 9 F-Fähigkeiten geben kein neues Verb. Die Taste F soll aber etwas *hinzufügen* (Isaac/Gungeon: das aktive Item
ist eine eigene Handlung). Gleiche Namen machen Talente und Items schwer lesbar.

### 3.6 Lesbarkeit und Bedienung

- **Tränke und Steine nur über das Inventar**: Taste I, Platz klicken, Knopf klicken, beim Werfen noch ins Ziel klicken.
  Das Spiel läuft dabei weiter. Im Kampf ist das zu langsam, also hebt man Tränke für „später“ auf: Horten durch Reibung.
  Es gibt keine Schnelltaste.
- Unbekannte Stücke zeigen kein Fluchrisiko. Unbekannte Tränke zeigen nicht, wie viele Sorten noch offen sind
  oder wie viele davon schaden.
- Der Wurf zeigt vorher keinen Wirkradius (64–92 px je Trank).
- Gut: Funde leuchten nach Seltenheit, Hinweise erscheinen oben, Element-Zeile bei erkannten Stücken.

### 3.7 Degenerierte oder tote Strategien

1. **Schutztrank stapeln**: Ladungen haben keine Obergrenze und keine Zeit. Sammeln und vor dem Boss alle trinken
   ergibt bei 3 Tränken 6 abgewehrte Treffer. Das ist mild, aber es belohnt das Horten.
2. **Lauf-Tränke immer trinken**: Kein Grund, sie zu werfen. Das ist akzeptabel, wenn man es so meint (siehe R8).
3. **Kampfraum-Truhen meiden** (Hölle/Krypta): Die Chance ist 60 % Kampf ohne Item gegen 40 % kleiner Fund.
   Rational ist es, nicht zu öffnen.
4. **Nekromant ignoriert Waffen** (Fehler, siehe oben).

## 4. Empfehlungen nach Wert und Aufwand

Wert 1–5, Aufwand S (unter einem halben Tag), M (1–2 Tage), L (mehr).

| # | Thema | Wert | Aufwand |
|---|---|---|---|
| R1 | Nekromant bekommt brauchbare Funde | 5 | S |
| R2 | Mimiks zahlen in den Story-Welten | 5 | S |
| R3 | Mehr Tränke, gewichtet, frühe feste Tränke | 5 | S |
| R4 | Schnelltasten für Tränke | 5 | M |
| R5 | Lesbares Risiko und leichteres Erkennen | 4 | S |
| R6 | Faire Flüche (Steine früh, nie tödlich, Blutzoll) | 4 | S |
| R7 | Jeder Trank hat einen zweiten Weg | 4 | M |
| R8 | Lauf-Tränke seltener, Schutz gedeckelt, Eile auch Angriff | 3 | S |
| R9 | F-Fähigkeiten: eigene Namen und eigene Verben | 4 | S (Namen) / M (Verben) |
| R10 | Power-Rüstung als Meilenstein statt Dauerregen | 3 | S |
| R11 | Wurfvorschau mit Radius | 3 | S–M |
| R12 | Schrein zeigt Flüche (billige Fluch-Prüfung) | 3 | M |
| R13 | Lauf-Ende zeigt ungenutzte Verbrauchsgüter | 2 | S |
| R14 | Funde je Etage messen (Seed-Test) | 4 | M |

**R1 Nekromant.** Problem: Kein Waffenpool, der Ersatz sind fremde Waffen (siehe 0). Beleg: `items.json` hat nur
`bone_staff` mit `class: necromancer`; `inventory.gd _roll_weapon` füllt mit fremden Waffen auf. Änderung jetzt:
Ist der Klassenpool einer Seltenheit leer, wird stattdessen `_roll_gear(depth, minimum)` gewürfelt. Später: 6–8
Nekromanten-Stäbe/Sensen in `items.json` (je Seltenheit mindestens einer). Wirkung: Der Nekromant hat dieselbe Fundkurve
wie alle anderen.

**R2 Mimik-Beute.** Problem: 60 % der Kampfraum-Truhen sind Kämpfe ohne Item, also lohnt es sich nicht, sie zu öffnen.
Beleg: alte Krypta (Mimik = selten+, `drops.mimic`) und das Risiko-Lohn-Prinzip (mehr Risiko → mehr Lohn).
Änderung: `hell_game.gd _wake_mimic` setzt `r.mimic_loot = true` und merkt sich die Stelle; `_clear_room` ruft dann,
wenn `r.get("mimic_loot")` gesetzt ist und `again` falsch, `story_items.loot("mimic", at)` auf (selten+ Waffe/Ausrüstung).
Wirkung: Die Truhe wird eine echte Wette: Kampf und gute Beute oder ein kleiner Fund.

**R3 Trank-Nachschub.** Problem: etwa 9 Tränke je Lauf, 0,75 Heiltränke, Wissen zahlt sich kaum aus (3.2). Beleg:
Isaac/SPD leben von häufigen Verbrauchsgütern; die Artikel zum Horten sagen „billig und häufig“. Änderung in `items.json`:
- Gewicht je Trank (neues Feld `weight`): `healing` 3, `regeneration` 1,5, `shield` 1,5, `strength` 1,2, `haste` 1,
  `fire` 1,2, `poison` 1,2, `ice` 1, `explosion` 1, `blind` 0,8, `aftershock` 0,5, `chainlight` 0,5 (Summe 14,4,
  Heilung 21 %). `inventory.gd _roll_kind`, Zweig `"potion"`: gewichtet wählen statt `randi_range`.
- `drops.chest.kinds.potion` 3 → 5, `drops.crate.kinds.potion` 5 → 6.
- `per_floor.potion_floors: [1, 2, 3]`: Die erste Truhe dieser Etagen bringt zusätzlich einen Trank (`floor_finds`).
Wirkung: etwa 13–16 Tränke je Lauf, etwa 3 Heiltränke, man sieht Farben zwei- oder dreimal. Das Probieren lernt man
in den ersten 10 Minuten, wenn es am billigsten ist (SPD-Rat).

**R4 Schnelltasten.** Problem: Tränke brauchen 3–4 Klicks, das Spiel läuft weiter, also hortet man (3.6). Beleg: Isaac (Q),
Gungeon (Q/Leertaste). Änderung: Im Inventar macht ein Rechtsklick einen Trankstapel zum **Schnelltrank** (Merker im Rucksack-Eintrag).
**H** trinkt ihn, **G** wirft ihn sofort zum Mauspunkt. In `hell_game.gd` sind beide Tasten frei. Ohne Merker trinkt H
den ersten bekannten Heiltrank. Das Symbol mit Anzahl steht neben dem F-Platz in der Fähigkeitenleiste (`talent_bar.gd`).
Wirkung: Tränke werden im Kampf benutzt. Das ist das größte Mittel gegen das Horten.

**R5 Lesbares Risiko, leichteres Erkennen.** Problem: Das Risiko ist unsichtbar, und es gibt kein Ausschlussverfahren. Beleg:
Brogue (gut/böse vorab), NetHack-Praxis (ausschließen). Änderung:
- Ein unbekanntes Stück zeigt in `inventory.gd view()` die Zeile „FLUCHRISIKO 60 %“ (Wert aus `curse_by_slot` für seinen Platz).
- Ein unbekannter Trank zeigt „NOCH UNBEKANNT: n SORTEN, k DAVON SCHADEN BEIM TRINKEN“. Dafür bekommt jeder Trank ein
  neues Feld `harmful: true` (für fire, ice, blind, poison, explosion).
- **Letzte Farbe von selbst**: Kennt man 11 Sorten, lernt `_learn` die zwölfte sofort und zeigt einen Hinweis.
- **Spiegelkristall** zeigt zusätzlich bei jedem unbekannten Stück im Rucksack nur „verflucht“ oder „rein“, nicht den Fluch selbst.
  Das ist neuer Code in `_use`, Zweig `mirror_crystal`, mit einem neuen Feld `curse_seen` am Stück.
Wirkung: Jeder Fund bleibt eine Wette, aber eine, deren Einsatz man sieht. Der Spiegelkristall wird ein begehrter Fund.

**R6 Faire Flüche.** Problem: kein Stein auf Etage 1, nutzloser Stein auf Etage 10; Blutzoll kann allein töten (3.3).
Beleg: Fehlschläge müssen in ihren Kosten zur Häufigkeit passen (Flow-Regel); SPD: früh probieren soll billig sein. Änderung:
- `per_floor.stone_floors: [1, 3, 5, 7, 9]` statt `stone_every: 2`; `floor_finds` liest die Liste.
- Fluchschaden ist nie tödlich: `story_items.gd dot_player` und `strike_at` lassen mindestens 1 halbes Herz übrig.
  Tränke dürfen weiter töten, das ist das Risiko des Probierens.
- `curses.bloodthirst.every` 25 → 40.
- Stellschraube für dich (kein Muss): `curse_by_slot` Waffe 0,6 → 0,45, Rüstung 0,5 → 0,4, Ring 0,45 → 0,35,
  Amulett bleibt 0,35. Dann ist „unbekannt“ wieder eine Wette und nicht fast sicher schlecht.
Wirkung: Der Fluch → Segen-Kreislauf ist ab Etage 1 lernbar, und kein Fluch beendet allein einen Lauf.

**R7 Jeder Trank hat einen zweiten Weg.** Problem: 10 von 24 Aktionen sind tot (3.1). Beleg: Brogue zeigt, dass ein
„schlechter“ Trank eine Nische haben kann (Dunkelheit hilft beim Schleichen), und SPD hat exotische Varianten. Die Hauptwirkung
bleibt klar die bessere, die andere ist eine kleine Nische. Änderung (neue Felder in `items.json`, Regeln in
`inventory.gd _drink` / `_throw`, Wirkung in `story_items.gd apply`):
- Getrunken behalten die schlechten Tränke ihren Schaden, bekommen danach aber einen Vorteil, passend zur Element-Physik:
  - `fire`: danach 20 s immun gegen Brand und Lava-Brand (`after: "fireproof", after_time: 20`).
  - `ice`: Laufen ×0,75 statt ×0,6 und kein `weak` mehr; löscht Brand sofort, danach 20 s immun gegen Brand und Kälte.
  - `poison`: danach 30 s immun gegen Gift und Giftgas.
  - `blind`: Gegner verlieren 3 s deine Spur (wie `shadow_leap.lost`).
  - `explosion`: 3 Schaden an dir **und** 12 an Gegnern im Radius 92 (Notfall-Nova).
- Geworfen wirken die guten Tränke auf Held, Klon und Begleiter im Radius 80, schwächer als getrunken:
  - `strength`: ×1,25 für 12 s (`throw_value`, `throw_time`).
  - `haste`: ×1,25 für 10 s.
  - `shield`: je Ziel 1 Ladung (`throw_charges: 1`).
  - `healing` und `regeneration` zählen künftig auch Begleiter. Welche Liste die Begleiter liefert (`talent_combat.gd`),
    legt der Programmierer fest.
- Bewusst ohne zweiten Weg: `aftershock` und `chainlight` (Begründung R8).
Wirkung: Auch ein erkannter Trank gibt zwei Möglichkeiten. Der Wurf zum Erkennen verschenkt einen guten Trank nicht mehr ganz.

**R8 Lauf-Tränke, Schutz, Eile.** Problem: Lauf-Tränke sind so häufig wie Heilung, Schutz stapelt endlos, und Eile ist schwach.
Änderung: Gewicht der Lauf-Tränke 0,5 (R3). Ihr Wurf bleibt schwach, mit dem Text „Lieber trinken: wirkt den ganzen Lauf“
als klarem Grund. `shield.max_charges: 4` (Deckel in `_drink`). `haste.rate: 0.85`: `story_items.gd rate_mult` multipliziert
den Wert, solange `effects.haste` läuft, der Text wird „15 s schneller laufen und angreifen“. Dazu die Texte von `poison`
und `ice` an die echten Regeln anpassen (3.1).

**R9 F-Fähigkeiten.** Problem: 5 von 9 doppeln ein Verb, und 3 Namen kommen doppelt vor (3.5). Änderung jetzt (S, nur Daten):
neue Namen in `armor_powers.json`: `shield_wall` → „BOLLWERK“, `blood_rush` → „BLUTZORN“, `bone_shield` → „GEBEINKRANZ“.
Später (M): neue Verben, z. B. Bollwerk = 3 s Rammstoß nach vorn mit Rückstoß; Leerenschritt = Sog ohne Sprung (der Magier
kann schon blinzeln); Schattensprung = Köder an der alten Stelle statt eines zweiten Sprungs. Wirkung: F fügt eine Handlung hinzu,
und die Namen lassen sich wieder lesen.

**R10 Power-Rüstung als Meilenstein.** Problem: etwa 1 je Etage, ab Etage 3 kein Ereignis mehr. Änderung in
`armor_powers.json drops`: `boss` 0,5 → 1,0 nur für den ersten Mini-Wächter, `chest` 0,1 → 0,04, `mimic` 0,35 → 0,25.
Neue Regel „garantiert: eine eigene Power-Rüstung beim Wächter von Etage 2“ als Feld `guarantee_floor: 2`.
Wirkung: Die F-Taste kommt früh und sicher, danach ist jede weitere Rüstung ein seltener Tauschmoment.

**R11 Wurfvorschau.** Im Wurfmodus (`throw_slot >= 0`) zeichnet `hell_game.gd` einen Ring um die Maus: bei bekannten Tränken
mit ihrem `radius`, bei unbekannten mit 80 px in neutraler Farbe. So sieht man, ob man selbst im Feuer stehen wird.

**R12 Schrein zeigt Flüche.** Die Räume `shrine` gibt es schon (`world_core.gd`: Feuerplatte und Herz). Wer auf die Platte tritt,
sieht einmal pro Schrein bei allen unbekannten Stücken „verflucht“ oder „rein“ (NetHack-Altar). Das ist eine billige ID-Quelle,
die man erst finden muss.

**R13 Lauf-Ende.** `HudKit.result_panel` zeigt zusätzlich „UNGENUTZT: 4 Tränke, 2 Steine“. Das ist ein sanfter Lernanstoß gegen
das Horten, ohne neue Regel.

**R14 Messen.** Ein Test erzeugt mit festem Seed 10 Etagen je Welt und zählt Truhen, Tränke, Kristalle, Steine, verfluchte Funde
und Power-Rüstungen je Etage (`tests/unit/items/` oder neben `tests/run_curve_test.gd`). Damit werden die Schätzungen dieses
Berichts zu Zahlen. Danach R3 und R10 nachstellen.

## 5. Werte, die Aufmerksamkeit brauchen (ohne Zielwert, daher nicht beurteilt, nur Vorschläge)

| Wert | Jetzt | Vorschlag | Grund |
|---|---|---|---|
| `drops.chest.kinds.potion` | 3 | 5 | Nachschub (R3) |
| `drops.crate.kinds.potion` | 5 | 6 | Nachschub (R3) |
| `potions.*.weight` | – (alle gleich) | siehe R3 | Heilung häufig, Lauf-Tränke selten |
| `per_floor.stone_every` | 2 (Etage 2–10) | `stone_floors` [1,3,5,7,9] | Probieren ab Etage 1 fair |
| `curses.bloodthirst.every` | 25 | 40 | allein nicht tödlich |
| `curse_by_slot.weapon` | 0,6 | 0,45 (deine Wahl) | „unbekannt“ soll eine Wette sein |
| `potions.shield.max_charges` | – | 4 | kein endloses Stapeln |
| `potions.haste.rate` | – | 0,85 | Eile spürbar machen |
| `armor_powers drops.chest` | 0,1 | 0,04 | Meilenstein (R10) |

## 6. Jetzt umsetzen (Checkliste für den Programmierer)

- [ ] **1 Nekromant-Funde** (S): `src/items/inventory.gd _roll_weapon`: Ist der Klassenpool leer, `return _roll_gear(depth, minimum)`
      statt fremder Waffen. Test: Ein Nekromant mit Seed bekommt nie eine Waffe, die er nicht anlegen kann.
- [ ] **2 Mimik zahlt** (S): `src/hell/hell_game.gd _wake_mimic`: `W.rooms[e.room].mimic_loot = true`; in `_clear_room`, wenn
      `r.get("mimic_loot", false)` und nicht `again`: `story_items.loot("mimic", at)`.
- [ ] **3 Trank-Nachschub** (S): `assets/data/items.json`: `weight` je Trank (R3), `drops.chest.kinds.potion` 5,
      `drops.crate.kinds.potion` 6, `per_floor.potion_floors` [1,2,3]; `inventory.gd _roll_kind` (gewichtet) und `floor_finds`.
- [ ] **4 Faire Flüche** (S): `items.json per_floor.stone_floors` [1,3,5,7,9] plus `floor_finds`;
      `curses.bloodthirst.every` 40; `src/hero/story_items.gd dot_player` und `strike_at`: Schaden höchstens `state.hp − 1`.
- [ ] **5 Lesbares Risiko** (S): `inventory.gd view()`: Zeile „FLUCHRISIKO n %“ bei unbekannten Stücken, „NOCH UNBEKANNT:
      n SORTEN, k SCHADEN BEIM TRINKEN“ bei unbekannten Tränken (`harmful` in `items.json`); `_learn`: die letzte Farbe von selbst.
- [ ] **6 Schnelltasten** (M): `src/hell/hell_game.gd` Eingabe H (trinken) und G (werfen zur Maus) über `story_items.act`;
      Rechtsklick in `src/ui/inventory_panel.gd` setzt den Schnelltrank; Symbol in `src/ui/talent_bar.gd`.
- [ ] **7 Zwei Wege je Trank** (M): neue Felder in `items.json` (`after`, `after_time`, `throw_value`, `throw_time`,
      `throw_charges`, `max_charges`, `haste.rate`); `inventory.gd _drink` / `_throw`; `story_items.gd apply`, `rate_mult`,
      Begleiter im Wurfradius. Danach die Texte von `poison`, `ice`, `haste` an die echten Regeln anpassen.
- [ ] **8 F-Namen** (S): `assets/data/armor_powers.json powers.*.name`: BOLLWERK, BLUTZORN, GEBEINKRANZ.

Nachweis je Punkt laut Projektregel: Load-Check plus höchstens eine Probe mit Bild in einer Story-Szene oder im Story-Testraum.

## 7. Quellen

In dieser Sitzung gefunden:
- Isaac-Wiki, Pills: https://bindingofisaacrebirth.wiki.gg/wiki/Pills
- Brogue-Wiki, Beginner’s Guide to the Early Depths (Detect Magic, Throw-ID): https://brogue.fandom.com/wiki/Beginner%27s_Guide_to_the_Early_Depths?oldid=6258
- Brogue-Wiki, Cursed item: https://brogue.wiki/wiki/Cursed_item
- Shattered PD, Beginners’ Guide (früh trinken): https://gamepretty.com/shattered-pixel-dungeon-beginners-guide/
- Shattered PD, Quick Guide (exotische Tränke, Erkennen): https://www.speedrun.com/shpd/guides/h39dc
- Shattered PD, Tipps: https://kosgames.com/shattered-pixel-dungeon-tips-and-tricks-for-beginner-21095/
- Steam-Forum, Spielerdiskussion zu Trank-ID und Wurf: https://steamcommunity.com/app/506870/discussions/0/154642901283999820
- NetHackWiki, Potion: https://nethackwiki.com/wiki/Potion
- NetHackWiki, Scroll of remove curse: https://nethackwiki.com/wiki/Scroll_of_remove_curse
- Crawl-Forum, „Remove identification“ (Spielerthread): https://crawl.develz.org/tavern/viewtopic.php?p=269419
- DCSS Dev-Blog-Archiv Mai 2020 (Release-Zyklus 0.25): https://crawl.develz.org/wordpress/2020/05
- Gamasutra/Game Developer, The Eight Rules of Roguelike Design: https://www.gamedeveloper.com/pc/analysis-the-eight-rules-of-roguelike-design
- Game Developer, How to stop making hoarders: https://www.gamedeveloper.com/game-platforms/how-to-stop-making-hoarders-in-video-games
- Game-Wisdom, Combating the Hoarding Syndrome: https://game-wisdom.com/critical/hoarding-game-design
- Game-Wisdom, How Hoarding Encourages Bad Game Design: https://game-wisdom.com/critical/hoarding-bad-game-design

Aus Spielkenntnis **(K)**, nicht per Link geprüft: DCSS 0.25 streicht Flüche; SPD-Fluchrate etwa 30 % für Waffen
(Quelltext `Weapon.random`, https://github.com/00-Evan/shattered-pixel-dungeon); NetHack-Altar und Preis-ID;
Gungeon füllt Blanks zu Beginn jeder Etage auf 2 auf; Isaac lädt aktive Items pro Raum; Hades-Cast-Kristalle.
