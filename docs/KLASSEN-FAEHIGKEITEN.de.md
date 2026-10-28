# Klassen und Fähigkeiten

Stand: 27.10.2026. **Entwurf, mit dem Nutzer abgestimmt, noch nicht umgesetzt.**
Grundlage sind die Klassen und Werte aus `origin/main` (Bruder, Commit 357d509),
die auf `codex_v2` noch nicht übernommen sind. Die übergeordneten Entscheidungen
stehen in `AGENTS.md` unter „Feature decisions: merging main into the target
design (2026-10-27)“. Alle Zahlen sind Startwerte; beim Umsetzen gehören sie in
`src/data/balance.json` und werden beim Spielen feinjustiert.

## Umsetzungsstand

**28.10.2026 umgesetzt: alle 12 Fähigkeiten, ihre 48 Upgrades, die Klassen-Passiven,
geteilte Team-EXP und das neue Perk-System.** Entscheidungen des Nutzers dazu:

- **Perks:** Level-ups geben drei Klassen-Karten (Upgrades freigeschalteter Fähigkeiten
  und Klassen-Passive). Bosse und Nebenbosse geben eine Wahl aus den allgemeinen Perks.
  Nach normalen Räumen gibt es keine Karten mehr (`perk_rules.room_rewards` = false;
  der alte Modus bleibt für Tests schaltbar).
- **Wahl im Kampf:** Die Karten erscheinen rechts, das Spiel läuft weiter, gewählt
  wird per Mausklick. Tasten 1–4 bleiben Fähigkeiten.
- **Tempo:** Ultimate (Level 10) etwa zu Beginn von Etage 5. Kurve 48 × Level^1,2;
  gemessen rund 780 EXP pro Etage (Seed 4242).
- **EXP:** Gegner lassen grüne EXP-Kugeln fallen; sie fliegen zum nächsten Helden
  und füllen eine gemeinsame Team-Leiste. Alle leveln gleichzeitig, jeder Held heilt
  ein Herz und bekommt eigene Karten.
- **Wände:** Alle drei Ultimates brechen Innenwände (Pfeilfaust beim Aufprall,
  Photoneneis nach 0,6 s auf derselben Stelle, Hiebe während Rage). Innenwände sind
  Mauerzellen mit Boden auf beiden Seiten; Außenwände und Zellen an Türen bleiben.
- **Icons:** Jede Karte zeigt die Waffe der eigenen Klasse (0x72-Sprite) mit
  Effekt-Zeichen; allgemeine Waffen-Perks bekommen ebenfalls die Klassenwaffe.

Werte: `assets/data/hero_skills.json`. Code: `src/combat/hero_skills.gd`,
`src/player/class_perks.gd`, `src/player/team_progress.gd`,
`src/dungeon/wall_breaker.gd`, `src/ui/skill_icons.gd`, `src/ui/level_cards.gd`,
`src/vfx/skill_fx.gd`. Test `tests/hero_skills_test.gd`, Nachweis
`production/qa/evidence/hero-skills/`.

Abweichungen von den Tabellen unten: Rückwärtssprung heißt im Spiel kurz
„Rücksprung“; Pfeilfaust und Klingenwelle prallen an Wänden mit einem schmalen Kern
ab, damit sie durch Gänge fliegen. Der Level-Up-Konflikt mit den Tasten 1–4 ist durch
die Mauswahl gelöst.

**Schritt 2 (27.10.2026): Klassen und Grundangriffe.**

- Klassenwahl: Solo über die Heldenkarten nach „Story-Modus“, Mehrspieler über den
  Knopf „< KLASSE >“ in der Lobby (vom Host geprüft, nur vor dem Laufstart).
- Grundangriff (Linksklick): Schwertkämpfer schlägt im Kegel vor sich (64 px,
  ca. 115°, nicht durch Wände), Bogenschütze schießt Pfeile, Magier schießt Kugeln,
  die beim Ende ihres Flugs mit halbem Schaden im Umkreis von 40 px explodieren.
- Die bestehenden 48 Perks rechnen auf die Klassenwerte auf. Elf reine
  Geschoss-Perks werden dem Schwertkämpfer nicht angeboten (Feld
  `projectile_only` in `balance.json`).
- Code: `src/player/hero_class.gd`, `perk_combat.gd` (`melee`, `splash`),
  Test `tests/hero_class_test.gd`, Nachweis `production/qa/evidence/hero-classes-step2/`.

## Gemeinsame Regeln

- **Drei Klassen:** Schwertkämpfer, Bogenschütze, Magier mit den 0x72-Figuren aus
  `main`. Die Echse folgt später als vierte Klasse. Gleiche Klassen im Team sind erlaubt.
- **Linksklick** bleibt der Grundangriff der Klassenwaffe.
- **Tasten 1–4** sind aktive Fähigkeiten, nur mit Abklingzeiten, ohne Mana.
  Taste 1 ab Spielstart, Taste 2/3/4 ab Level 3/6/10. Taste 4 ist immer das Ultimate.
- **Schaden** einer Fähigkeit ist ein Vielfaches des Waffenschadens („2×“ = doppelter
  Waffenschaden). Perks, die den Waffenschaden erhöhen, verstärken so auch die Fähigkeiten.
- **Level-Up:** drei Karten, gewählt mit den Tasten 1–4 bzw. per Klick. Angeboten
  werden Fähigkeits-Perks nur für bereits freigeschaltete Fähigkeiten sowie passive
  Klassen-Perks, jeweils nur bis zur Höchststufe. Ist alles ausgebaut, gibt es
  Heilung oder einen Schutztreffer (wie die bestehende Regel bei erschöpftem Perk-Pool).
- **Bosse** lassen allgemeine Perks fallen (Katalog folgt, Quelle: die bestehenden
  48 Perks aus `docs/PERKS.de.md`). Nach normalen Räumen gibt es keine Perk-Karten.
- **Krit-System:** Ein gemeinsames System für Rage (Schwertkämpfer) und Präzision
  (Bogenschütze).
- **Bewegungsfähigkeiten** (Ansturm, Rückwärtssprung, Blinzeln) prüft der Host gegen
  Wände; Spieler landen nie in Wänden oder außerhalb des Raums.
- **Bosse und Nebenbosse** sind gegen Rückstoß, Einfrieren und Verlangsamung
  deutlich widerstandsfähiger (Werte je Fähigkeit unten).
- Schaden, Treffer und Effekte bleiben host-autoritativ wie bisher.

## Schwertkämpfer

5 Herzen (10 LP), Tempo 185. Schwert: 5 Schaden, alle 0,4 s, 64 px Reichweite,
Bogen ca. 115°. Rolle: Nahkämpfer mit den meisten Herzen, hält Gegner zusammen.

### 1 · Wirbelklinge (ab Start)
Rundumhieb, Radius 80 px, 2× Schaden, starker Rückstoß. Dauer 0,35 s mit 50 %
Lauftempo. **Abklingzeit 6 s.**

| Perk | Wirkung | Max |
|---|---|---|
| Doppelwirbel | Zweite Umdrehung direkt danach (70 % Schaden) | 1 |
| Sog | Zieht Gegner im Umkreis von 140 px vorher 40 px heran | 1 |
| Glutwirbel | Setzt in Brand: 1 Schaden/s für 3 s | 1 |
| Weiter Schwung | +20 % Radius | 2 |

### 2 · Klingenwelle (ab Level 3)
Sichelwelle in Mausrichtung, 320 px weit, 48 px breit, durchdringt alle Gegner,
stoppt an Wänden. 1,5× Schaden. **Abklingzeit 5 s.**

| Perk | Wirkung | Max |
|---|---|---|
| Wellenfächer | 3 Wellen im Fächer, je 70 % Schaden | 1 |
| Bumerang | Welle kehrt zurück und trifft erneut | 1 |
| Schwere Welle | +50 % Schaden, größer, fliegt langsamer | 1 |
| Weitwurf | +30 % Flugweite | 2 |

### 3 · Ansturm (ab Level 6)
Sprint zur Maus, 160 px in 0,2 s, dabei unverwundbar. 1× Schaden an allem auf
dem Weg. **Abklingzeit 8 s.**

| Perk | Wirkung | Max |
|---|---|---|
| Zweite Ladung | Zwei Anstürme hintereinander | 1 |
| Schockwelle | Stoß am Ende: 64 px, 1× Schaden, 0,5 s betäubt | 1 |
| Kampfrausch | Danach 3 s lang 30 % schnellere Hiebe | 1 |
| Schulterstoß | Getroffene werden weit weggestoßen und 0,8 s betäubt | 1 |

### 4 · Rage (Ultimate, ab Level 10)
Zieht eine zweite Klinge: 6 s lang doppelt so schnelle Hiebe (0,4 s → 0,2 s,
verrechnet mit Flinke Klinge) und 25 % Krit-Chance mit 2× Schaden. Zweites Schwert
in der anderen Hand, rote Aura. Gilt nur für den Grundangriff. **Abklingzeit 20 s.**

| Perk | Wirkung | Max |
|---|---|---|
| Blutrausch | Jeder Kill in Rage verlängert sie um 0,5 s (höchstens +3 s) | 1 |
| Scharfe Klingen | +15 % Krit-Chance | 2 |
| Henkersstreich | Krits +50 % Schaden (2× → 2,5× → 3×) | 2 |
| Entfesselt | Während Rage laden Fähigkeiten 1–3 doppelt so schnell | 1 |

### Passive Klassen-Perks (aus `main`)
Schwerer Hieb (+25 % Schaden, 3) · Flinke Klinge (12 % schnellere Hiebe, 3) ·
Eiserne Haut (+1 Herz, 3) · Blutdurst (Kills heilen manchmal, 2) · Parade (Hiebe
zerschlagen Geschosse, 1).

## Bogenschütze

4 Herzen (8 LP), Tempo 190. Kurzbogen: 2 Schaden, alle 0,2 s, 600 px/s, ca. 720 px
Reichweite. Rolle: Fernschaden und Feldkontrolle, der Wendigste.

### 1 · Salve (ab Start)
Fächer aus 5 Pfeilen über 60°, je 1,5× Schaden. **Abklingzeit 5 s.**

| Perk | Wirkung | Max |
|---|---|---|
| Breite Salve | +2 Pfeile | 2 |
| Doppelsalve | Zweite Salve 0,15 s später (60 % Schaden) | 1 |
| Splitterpfeile | Treffer spalten sich in 2 Pfeile (35 % Schaden) | 1 |
| Giftspitzen | Gift: 0,8 Schaden/s für 3 s | 1 |

### 2 · Ballistapfeil (ab Level 3)
Taste halten zum Aufladen (bis 1 s), loslassen schießt. 3× bis 8× Schaden je nach
Ladung, durchbohrt alle Gegner in einer Linie, 900 px weit, stoppt an Wänden.
Beim Aufladen 50 % Lauftempo. **Abklingzeit 7 s** ab dem Schuss.

| Perk | Wirkung | Max |
|---|---|---|
| Schnellspanner | 40 % kürzere Ladezeit | 1 |
| Giftspur | Pfeil hinterlässt 2 s lang eine Giftspur | 1 |
| Jägermal | Getroffene 4 s markiert: +25 % Schaden von allen Spielern | 1 |
| Wuchtspitze | +30 % Schaden | 2 |

### 3 · Rückwärtssprung (ab Level 6)
Sprung 140 px weg von der Maus in 0,25 s, dabei unverwundbar. Am Startpunkt bleiben
Krähenfüße (48 px, 4 s, 40 % langsamer). **Abklingzeit 8 s.**

| Perk | Wirkung | Max |
|---|---|---|
| Sprengfalle | Krähenfüße explodieren beim ersten Kontakt (64 px, 3× Schaden) | 1 |
| Zweite Ladung | Zwei Sprünge hintereinander | 1 |
| Rückenwind | Danach 3 s lang 30 % schnellere Schüsse | 1 |
| Eisdornen | Verlangsamung 60 % statt 40 % | 1 |

### 4 · Pfeilfaust-Schuss (Ultimate, ab Level 10)
0,3 s Ausholen mit Warnlinie. Riesiger Pfeil, 64 px breit, 500 px/s, bis 480 px.
4× Schaden beim Treffer, alle getroffenen Gegner werden mitgeschoben. Prallen sie
gegen eine Wand, platzt der Pfeil: 10× Schaden im Umkreis von 80 px und 70 %
Verlangsamung, die über 4 s gleichmäßig auf 0 abklingt. Ohne Wand keine Explosion.
Bosse und Nebenbosse werden nur 32 px gestoßen und platzen nur bei Wandkontakt.
**Abklingzeit 18 s.**

| Perk | Wirkung | Max |
|---|---|---|
| Mauerbrecher | +50 % Explosionsschaden | 2 |
| Sprengspitze | Platzt auch ohne Wand am Ende der Flugbahn (60 % Schaden) | 1 |
| Frostkern | Verlangsamung startet bei 90 % und hält 2 s länger | 1 |
| Splitterhagel | Explosion schleudert 6 Splitter (je 1× Schaden) | 1 |

### Passive Klassen-Perks (aus `main`)
Mehrfachschuss (+1 Pfeil, 3) · Durchschlag (+1 Gegner, 2) · Schnellfeuer (12 %
schneller, 3) · Adlerauge (+20 % Reichweite und Tempo, 2) · Präzision (15 % Krit, 3) ·
Leichtfuß (+15 Tempo, 3) · Abpraller (1).
Durchschlag, Abpraller und Präzision wirken auf alle Pfeile, auch die der
Fähigkeiten. Mehrfachschuss und Schnellfeuer nur auf den Grundangriff.

## Magier

3 Herzen (6 LP), Tempo 180. Smaragdstab: 3,5 Schaden, alle 0,4 s, 380 px/s, ca.
570 px Reichweite, 40 px Explosion mit halbem Schaden. Rolle: Flächenschaden mit
Feuer, Blitz und Frost; verwundbar, muss Abstand halten.

### 1 · Feuerball (ab Start)
Kugel, 300 px/s, explodiert bei Treffer, an Wänden oder nach 500 px: 64 px Radius,
3× Schaden, Brand 1 Schaden/s für 3 s. **Abklingzeit 4 s.**

| Perk | Wirkung | Max |
|---|---|---|
| Zwillingsfeuer | 2 Feuerbälle statt einem, auf Stufe 2 drei | 2 |
| Brandmal | Brennende Gegner explodieren beim Tod (48 px, 80 % Schaden) | 1 |
| Großbrand | +30 % Explosionsradius | 2 |
| Lavaspur | Flugbahn brennt 2 s nach | 1 |

### 2 · Kettenblitz (ab Level 3)
Sofortiger Blitz auf den Gegner nächst der Maus (bis 360 px), springt auf bis zu 4
weitere (je bis 120 px). 2,5× Schaden beim ersten Ziel, −15 % pro Sprung,
0,2 s Betäubung. **Abklingzeit 7 s.**

| Perk | Wirkung | Max |
|---|---|---|
| Weitere Sprünge | +2 Sprünge | 2 |
| Überladung | +40 % Schaden gegen verlangsamte oder eingefrorene Gegner | 1 |
| Gewitterfeld | Am letzten Ziel 2 s Gewitter (48 px) | 1 |
| Rückkopplung | Jeder Sprung verkürzt die Abklingzeit um 0,3 s | 1 |

### 3 · Blinzeln (ab Level 6)
Teleport bis 180 px zur Maus, nicht durch Wände (letzter freier Punkt auf der
Linie). Danach 0,3 s unverwundbar. **Abklingzeit 7 s.**

| Perk | Wirkung | Max |
|---|---|---|
| Arkanriss | Explosion am Startpunkt (64 px, 2× Schaden) | 1 |
| Zweite Ladung | Zwei Teleporte hintereinander | 1 |
| Spiegelbild | Abbild bleibt 2 s stehen und lockt Gegner an | 1 |
| Phasenschild | Danach 3 s lang ein Schutztreffer | 1 |

### 4 · Fusionsmagie: Photoneneis (Ultimate, ab Level 10)
Kanalisierter Strahl aus Eis und Feuer: Taste halten, **bis 5 s**, loslassen beendet
ihn früher. 400 px lang, 24 px breit, durchdringt Gegner, stoppt an Wänden, folgt der
Maus mit höchstens 180°/s (Strahltechnik vom Boss-Ultimate aus `main`).
4× Schaden pro Sekunde in Ticks alle 0,25 s. Ignite: 1,5 Schaden/s für 4 s,
wird im Strahl erneuert, nicht gestapelt. Slow: 50 % im Strahl, danach über 3 s
gleichmäßig abklingend. Der Magier läuft beim Kanalisieren mit 30 % Tempo, kein
Grundangriff; Treffer unterbrechen nicht. Bosse: voller Schaden, halber Slow.
**Abklingzeit 20 s** ab Ende des Strahls.

| Perk | Wirkung | Max |
|---|---|---|
| Langer Atem | +1 s Strahldauer | 2 |
| Prisma | Spaltet sich am ersten Gegner in 2 Nebenstrahlen (50 % Schaden) | 1 |
| Glutkern | Ignite +50 % Schaden, springt beim Tod auf nahe Gegner über | 1 |
| Frostbiss | Slow startet bei 70 % und klingt über 5 s ab | 1 |

### Passive Klassen-Perks (aus `main`)
Fokus (+25 % Schaden, 3) · Arkane Eile (12 % schneller, 3) · Nova (größere
Explosionen, 3) · Suchende Kugeln (2) · Arkanschild (blockt alle 12 s einen Treffer, 1) ·
Doppelzauber (2).
Fokus wirkt auf alles. Nova, Suchende Kugeln und Doppelzauber nur auf den
Grundangriff, damit Doppelzauber und Zwillingsfeuer sich nicht vervielfachen.

## Offen für die Umsetzung

- **Level-Kurve:** Mit `main` (100 × Level^1,5, ca. 10 EXP pro normalem Gegner) wäre
  Level 10 erst um Etage 15–18 erreicht. Freischalt-Level oder EXP-Werte müssen an die
  40-Etagen-Story angepasst werden.
- **Photoneneis** mit 5 s (bis 7 s mit Langer Atem) ist das stärkste Ultimate auf dem
  Papier (70 Grundschaden plus Ignite); beim Spielen gegen Rage und Pfeilfaust prüfen.
- **Level-Up-Karten und Fähigkeiten auf 1–4:** Solange ein Angebot offen ist, belegen
  die Karten die Tasten. Wie das im laufenden Kampf mit dem Zaubern zusammenspielt,
  ist noch zu klären.
- **Grafik:** Zweite Klinge, Strahl- und Explosionseffekte im 0x72-Stil; neue Grafik
  läuft über die bestehende Stilprobe-und-Freigabe-Regel in `AGENTS.md`.
- **Allgemeine Boss-Perks:** Auswahl aus den 48 bestehenden Perks steht noch aus.
