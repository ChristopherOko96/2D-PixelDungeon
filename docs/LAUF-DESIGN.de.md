# Lauf-Design: Dungeon Crawler mit Tod, Items, Lauf-Talenten (ENTWURF)

Status: **freigegeben 29.10.2026** ("Ja, so umsetzen"; offene Frage 3.3: dauerhafte Talente schalten Knoten frei). Alle vier Schritte umgesetzt (Schritt 3: docs/ITEM-SYSTEM-V2.de.md, Abschnitt Umsetzung). Fasst Dwaynes Liste (Item-System,
Speicherstand, Level-Up) und die Entscheidungen des Nutzers vom 29.10.2026 zu
einem Lauf zusammen. Ersetzt die Abschnitte zu Lauf und Level in
`docs/ITEM-SYSTEM-V2.de.md`; die Item-Regeln dort gelten weiter.

Kerngedanke (Nutzer): **Dungeon Crawler. Stirbt der Held, beginnt die Zone von
vorn bis zum Endboss.** Deshalb muss alles, was man im Lauf findet und lernt,
den Lauf spürbar stärker machen, und alles davon geht beim Tod verloren.

Entscheidungen (29.10.2026):
1. Beim Tod wird der Lauf-Stand gelöscht; Speichern dient nur zum Unterbrechen.
2. Nach dem Tod bleiben nur **Talente und Seelenkristalle** (Meta-Fortschritt),
   in allen drei Welten.
3. Ein Level-Up gibt einen **Talentpunkt im Lauf-Baum** der Klasse; der Baum
   verfällt beim Tod.

## 1. Überblick

Eine **Zone** ist eine Welt: Krypta der Verdammten, Hell-Dungeon, Frostgruft.
Ein **Lauf** geht von Etage 1 bis zum Endboss der Zone. Im Lauf wächst der Held
auf zwei Wegen: **Level** (Erfahrung → Talentpunkte im Lauf-Baum) und **Funde**
(Waffen, Rüstung, Ring, Amulett, Tränke, Steine). Der Tod beendet den Lauf:
Level, Baum, Rucksack, Ausrüstung und Trank-Wissen sind weg. Die verdienten
Seelenkristalle bleiben und kaufen dauerhafte Talente im Hauptmenü.

## 2. Spielgefühl

Jeder Lauf erzählt seine eigene Geschichte: „Diesmal habe ich früh einen
Ring des Lebensraubs gefunden und alles in Wirbelklinge gesteckt.“ Der Tod tut
weh, aber man kommt mit Seelenkristallen und mehr Wissen zurück. Funde und
Punkte sind Entscheidungen, keine Selbstläufer.

## 3. Regeln

### 3.1 Tod und Neustart (alle Welten)
- Fällt der Held (alle Helden in der Krypta), endet der Lauf. Ein
  **Lauf-Ende-Bildschirm** zeigt erreichte Etage, besiegte Wächter, beste Funde
  und die verdienten Seelenkristalle; Knöpfe: „Neuer Lauf“, „Hauptmenü“.
- **Neuer Lauf** beginnt auf Etage 1 der Zone mit neuem Zufall (neue Karten,
  neue Trankfarben), Startwaffe der Klasse, Level 1, leerem Rucksack.
- Die Hölle und die Frostgruft verlieren damit das Wiederaufstehen auf der
  Etage (heute: nach 1,8 s volle Herzen am Etagenstart) und die Taste
  R „Etage neu beginnen“.
- Phönix-Leben und ähnliche Rettungen aus Talenten oder Items bleiben erlaubt:
  sie verhindern den Tod einmal, sie heben ihn nicht auf.

### 3.2 Speicherstände
- Ein Lauf hat **einen** Stand je Platz (3 Plätze je Modus bleiben). Er wird am
  Etagenanfang und beim Verlassen ins Hauptmenü geschrieben.
- **Beim Tod wird der Stand des Laufs gelöscht.** Ein geladener Stand ist
  danach derselbe Lauf; stirbt man wieder, ist er weg.
- Kein Laden eines älteren Stands desselben Laufs (keine Rückkehr vor einen Tod).

### 3.3 Meta-Fortschritt (bleibt nach dem Tod)
- Seelenkristalle aus jedem Lauf (Etagen, Wächter, Nebenziele; Werte wie jetzt
  in `frost_talents.json` → `currency`).
- Die dauerhaften Talente im Hauptmenü (TALENTE, Unterklassen, Meisterfähigkeit)
  gelten künftig in **allen drei Welten**, auch in der Krypta.
- **Offen:** Die dauerhaften Talente enthalten heute dieselben Wirkungen wie
  Lauf-Upgrades (z. B. ZWILLINGSFEUER, GROSSBRAND). Vorschlag: Ein dauerhaftes
  Talent schaltet einen Knoten im Lauf-Baum **frei** (er erscheint erst dann),
  statt ihn sofort zu geben. So gibt es kein doppeltes Stapeln, und der
  Meta-Fortschritt erweitert die Wahl im Lauf.

### 3.4 Lauf-Talente (ersetzt die Level-Karten in allen Welten)
- Jedes Level-Up: **1 Talentpunkt**, Heilung (wie jetzt) und ein kurzes
  Aufleuchten. Der Punkt wird im Lauf-Baum ausgegeben (Taste **T** öffnet ihn,
  das Spiel läuft weiter, wie das Inventar). Ungenutzte Punkte bleiben liegen.
- Der Baum je Klasse hat **fünf Äste**: einen je Fähigkeit (4) und einen für
  Passive. Inhalt sind die vorhandenen Upgrades (`hero_skills.json`):

| Klasse | Ast 1 | Ast 2 | Ast 3 | Ast 4 | Passiv |
| --- | --- | --- | --- | --- | --- |
| Schwertkämpfer | Wirbelklinge: Doppelwirbel, Sog, Glutwirbel, Weiter Schwung | Klingenwelle: Wellenfächer, Bumerang, Schwere Welle, Weitwurf | Ansturm: Zweiter Ansturm, Schockwelle, Kampfrausch, Schulterstoß | Raserei: Blutrausch, Scharfe Klingen, Henker, Entfesselt | Schwer, Flink, Kraft, Blutdurst, Parade |
| Bogenschütze | Salve: Breite Salve, Doppelsalve, Splitter, Giftspitzen | Ballista: Schnellspanner, Giftspur, Jägermal, Wuchtspitze | Rücksprung: Sprengfalle, Zweiter Sprung, Rückenwind, Eisdornen | Pfeilfaust: Mauerbrecher, Sprengspitze, Frostkern, Splitterhagel | Mehrfachschuss, Durchschuss, Schnellfeuer, Adlerauge, Krit, Flink, Abpraller |
| Magier | Feuerball: Zwillingsfeuer, Brandmal, Großbrand, Lavaspur | Kettenblitz: Mehr Sprünge, Überladung, Sturmfeld, Rückkopplung | Blinzeln: Arkanriss, Zweites Blinzeln, Spiegelbild, Phasenschild | Photoneneis: Langer Atem, Prisma, Glutkern, Frostbiss | Fokus, Eile, Nova, Sucher, Schild, Doppelzauber |

- **Reihenfolge im Ast:** Stufe 1 (zwei Knoten) frei wählbar, Stufe 2 (zwei
  Knoten) braucht 2 Punkte im selben Ast. Ein Fähigkeits-Ast öffnet sich erst,
  wenn die Fähigkeit freigeschaltet ist (Level 1 / 3 / 6 / 10 wie jetzt).
- **Mehrstufige Knoten** (heute „Stufe 1/3“) nehmen mehrere Punkte.
- Relikt-Karten der Story-Welten (Schwerkraftstab, Hammer, Schattendolch)
  werden ein sechster Ast, solange das Relikt im Lauf getragen wird.

### 3.5 Funde lohnen sich (Item-Ökonomie im Lauf)
Item-Regeln aus `docs/ITEM-SYSTEM-V2.de.md` (Rucksack, Waffe/Rüstung/Ring/Amulett,
Aufwertung −3…+3, Flüche → Segen, unbekannte Tränke). Dazu im Lauf:
- **Feste Quellen je Etage:** mindestens 2 Truhen, 1 Kristall (Erkennen),
  jede 2. Etage 1 Fluchbrecher; Mini-Wächter (Etage 3/6/9) lassen ein Stück
  „selten oder besser“ fallen, der Endboss nichts (der Lauf ist dann gewonnen).
- **Tiefe zählt:** Seltenheitsgewichte steigen von Etage 1 bis 10 (wie jetzt).
- **Synergien:** Wirkungen von Funden greifen in die Lauf-Talente (z. B. Brand
  aus der Waffe + Großbrand), damit Funde und Punkte zusammen einen Bau ergeben.
- **Klonsiegel (Vorschlag):** Klon auf Zeit; ersetzt die heutige Klon-Taste Q
  der Hölle (Klon mit Lauf-Uhr) durch ein Fundstück.

## 4. Formeln

### 4.1 Erfahrung je Level (eine Kurve für alle Welten)
`need(L) = base × L^exponent` (wie jetzt in Hölle und Frostgruft).
Ziel: am Endboss einer Zone **Level 14 ± 2** → 13 Punkte, etwa 60 % des Baums
(rund 22 bis 25 Knoten je Klasse). So muss man wählen. `base`, `exponent` und
die Erfahrung je Gegner je Welt werden in einem Test über einen simulierten
Lauf eingestellt (Etagen × Gegner × Erfahrung).

### 4.2 Seelenkristalle je Lauf
`SK = floor_base + per_floor × Etage + guardian × Wächter + mini × Mini-Wächter
+ final × Endboss + side_goal × Nebenziele` (wie jetzt), auch bei einem Tod.

### 4.3 Aufwertung, Fluchchance, Seltenheit
Wie `docs/ITEM-SYSTEM-V2.de.md` Abschnitt 4.

## 5. Sonderfälle
- Tod während ein Speicherstand geschrieben wird: erst löschen, dann den
  Lauf-Ende-Bildschirm zeigen; ein halber Stand wird nie geladen.
- Krypta mit mehreren Spielern: der Lauf endet, wenn alle gefallen sind
  (wie jetzt); Punkte und Bäume je Held, Level geteilt (Team-Level wie jetzt).
- Lauf gewonnen (Endboss besiegt): Stand wird gelöscht, Seelenkristalle plus
  Endboss-Bonus, Lauf-Ende-Bildschirm mit „Sieg“.
- Spiel während eines Laufs beendet (Fenster zu): der zuletzt geschriebene
  Etagen-Stand bleibt; das ist der einzige Weg zurück in diesen Lauf.

## 6. Abhängigkeiten
`hell_game.gd` (Tod, Respawn, Taste R, Level, CardKit), `card_kit.gd`,
`hero_kit.gd`, `meta_store.gd`, `frost_talents.json`; Krypta `game.gd`,
`team_progress.gd`, `level_cards.gd`, `class_perks.gd`, `hero_skills.json`;
Speicher `src/save/*`; HUD (`hud_kit.gd`: offene Talentpunkte am Level-Feld).

## 7. Stellschrauben
EXP-Kurve je Welt, Punkte je Level, Kosten mehrstufiger Knoten, Bedingung für
Stufe 2 im Ast, feste Fundquellen je Etage, Seelenkristall-Werte.

## 8. Abnahmekriterien
- In allen drei Welten führt der Tod zum Lauf-Ende-Bildschirm und ein neuer
  Lauf beginnt auf Etage 1; der Speicherstand des Laufs ist danach weg.
- Seelenkristalle und dauerhafte Talente bleiben nach dem Tod erhalten.
- Jedes Level-Up gibt einen Punkt; der Lauf-Baum zeigt Äste, Stufen und
  gesperrte Fähigkeits-Äste; ausgegebene Punkte wirken sofort.
- Ein simulierter Lauf erreicht am Endboss Level 14 ± 2 (Test).
- Funde aus festen Quellen erscheinen je Etage wie beschrieben (Test mit Seed).

## Umsetzung Schritt 1 (29.10.2026)

- Hölle/Frostgruft: `end_run(won)` statt Wiederaufstehen; Taste R entfällt; der letzte
  Wächter beendet den Lauf als Sieg; E auf dem Ergebnis startet `new_run()` (frische Szene,
  gleiche Klasse, Etage 1). Jeder Lauf hat eine `run_id`; `run_slot` hält den Platz auf dem
  neuesten Etagenanfang; `SaveStore.erase_run` löscht beim Lauf-Ende alle Plätze dieses Laufs.
- Krypta: Team gefallen → Plätze des Laufs (`crypt-<seed>`) gelöscht; E startet den neuen Lauf (Host).
- Ergebnis-Kasten für alle Welten: `HudKit.result_panel` (Etage geschafft, Lauf beendet, Sieg).
- Test: `tests/run_end_test.gd`. Belege: `production/qa/evidence/run-end` (`scripts/capture_run_end.gd`).
- Bekannt: `tests/game_rules.gd` hat 9 alte Fehler (Belohnung direkt nach dem Raum, vor dem Horden-System), nicht von hier.

## Umsetzung Schritt 2 (29.10.2026): Lauf-Talente

- Modell `src/progress/run_tree.gd` (+ `assets/data/run_tree.json`): 1 Punkt je Level, Äste je Fähigkeit
  (offen ab ihrem Level) und Passiv/Grundwerte, Stufe 2 ab 2 Punkten im Ast, Höchststufen.
- Fenster `src/ui/run_tree_view.gd` (Taste **B**, das Spiel läuft weiter, Klick setzt den Punkt), in
  allen Welten gleich; „+n“ neben dem Level in der Heldenleiste.
- Krypta: `ClassPerks.run_tree`, `team_progress.take_talent`, Netz-Aktion `talent`; Level-Ups bringen keine
  Karten mehr (Boss-Belohnungen bleiben). Hölle/Frostgruft: `CardKit.tree` / `take_node` aus den Themenkarten.
- EXP-Kurve: ein voller Lauf erreicht Hölle Level 15, Frostgruft Level 14 (`tests/run_curve_test.gd`).
  Die Krypta ist nicht simuliert (Etagen werden erzeugt); ihr Baum fasst 32 bis 36 Punkte.
- Tests: `tests/run_tree_test.gd`. Belege: `production/qa/evidence/run-tree` (`scripts/capture_run_tree.gd`).

## Umsetzung Schritt 4 (29.10.2026): dauerhafte Talente überall

- Talentkarten (z. B. ZWILLINGSFEUER) geben keine Gratis-Stufe mehr: sie **öffnen** den Knoten im Lauf-Baum,
  ihr Rang ist dort die Höchststufe (`RunTree.gate`, `MetaStore.gated_cards`). Ohne Talent ist der Knoten
  gesperrt („im Hauptmenü unter TALENTE freischalten“).
- Die Hölle nutzt jetzt dieselben Talente und Seelenkristalle (`hell_theme.json` → `hero_keys` + talents).
- Krypta: Werte-Talente (Schaden, Tempo, Lauf, Herzen) wirken auf den Host-Helden, Talentkarten öffnen
  Knoten, jede geschaffte Ebene zahlt Seelenkristalle (Wächter-Bonus), Ergebnis-Kasten zeigt sie.
  Mitspieler im Mehrspieler haben ihren Baum ohne Talent-Sperren (ihr Fortschritt liegt auf ihrem Rechner).
- Test- und Aufnahme-Skripte lesen oder ändern die echte Talentdatei nie.

## Bau-Reihenfolge (Vorschlag)
1. Tod = Lauf-Ende in Hölle und Frostgruft, Lauf-Ende-Bildschirm in allen Welten,
   Stand beim Tod löschen.
2. Lauf-Talente: ein Baum-Modell für alle Welten, Fenster (Taste T), ersetzt die
   Level-Karten; EXP-Kurve über einen simulierten Lauf einstellen.
3. Item-System 2 in allen Welten (Rucksack, neue Plätze, feste Fundquellen).
4. Meta-Talente in allen drei Welten (mit der offenen Frage aus 3.3).
