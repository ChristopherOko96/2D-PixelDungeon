# Mechanik-Bewertung „Delve Disaster“: Kampf, Räume, Etagen, Läufe

Stand 2026-11-01 · Rolle: Game Designer · Fokus: Story-Welten (Krypta, Frostgruft, Hölle über `src/hell/hell_game.gd`)
Baut auf `BEWERTUNG.md` (Items, Tränke, Flüche, Funde) auf und wiederholt nichts daraus. `ux-review/BEFUND.md` habe ich
nicht im Einzelnen gelesen. Bedienpunkte stehen hier nur, wenn sie eine Regel betreffen.
Grundlage: Daten und Code, Vergleich mit Fachliteratur und Entwickler-Vorträgen. Kein Spieltest, keine Telemetrie.

## 0. Gesamturteil: BEDENKEN (nichts kritisch), Zielwerte NICHT BEURTEILT

- **Der Kern ist gesund:** Räume schließen sich im Kampf. Auf dem kürzesten Weg liegen 11–17 von 22–31 Räumen, der Rest ist
  freiwillige Erkundung mit echtem Lohn (Tresor, Geheimräume). Jede Etage hat einen Wächter. Der Lauf-Baum zwingt zur Wahl
  (etwa 13 Punkte für etwa 60 % des Baums). Die Elemente wirken auf beide Seiten. Todesursachen haben Texte (`why`).
- **Bedenken 1, Fairness im Moment:** Die Vorwarnzeiten der Krypta- und Höllen-Gegner stehen fest im Code (`hell_monsters.gd
  _run_act`), nicht in den Daten. Der Nahkampfhieb kündigt sich nur **0,35 s** vorher an und **zielt bis zum Auslösen nach**.
  Aus dem Nahkampf kann man ihm per Reaktion nicht entkommen.
- **Bedenken 2, Masse ohne Ordnung:** Ein Kampfraum hat 4–12 Gegner. Es gibt keine Grenze, wie viele gleichzeitig angreifen.
  Ein allgemeines Ausweichen habe ich nicht gefunden. Die Ausweich-Fähigkeit kommt erst ab Level 6.
- **Bedenken 3, Entscheidungen:** Das Dämonensiegel lohnt sich immer (keine echte Wahl). Hölle und Frostgruft haben dieselbe
  Schwierigkeitskurve und dieselben Boss-LP. Nach dem ersten Sieg gibt es keine Stufen für Meister.
- **Ziele:** In dieser Sitzung habe ich kein Kampf-GDD und keine Zielwerte geprüft (laut `BEWERTUNG.md` ist
  `design/registry/entities.yaml` leer). Abweichungen sind deshalb **NICHT BEURTEILT – KEINE ZIELE**. Ich messe gegen die
  Absichten in `docs/LAUF-DESIGN.de.md` und `docs/HELL-DUNGEON.de.md` und gegen die Quellen unten.

## 1. Datenquellen und Grenzen

Gelesen: `assets/data/hell_balance.json`, `krypta_balance.json`, `krypta_monsters.json` (Skelett, Knochenwächter),
`combat_hordes.json`, `element_rules.json` (Ausschnitte), `talents.json` (Begleiter), `frost_theme.json` (Abklingzeiten,
Vorwarnzeiten), `hell_floors.json` und `frost_floors.json` (`boss`, `diff`), `src/hell/hell_monsters.gd` (Spawn, `_run_act`),
`src/hell/hell_monster_rules.gd pick_attack`, `src/world_kit/world_core.gd` (Gegner je Raum, `diff`), `docs/LAUF-DESIGN.de.md`,
`docs/HELL-DUNGEON.de.md`, `docs/HELDEN-MODUL.de.md`.
Grenzen:
- **Nicht gelesen:** `talent_combat.gd`, `run_tree.json`, die Grundwerte des Heldenschadens, `story_feel.gd` (Rückmeldung beim
  eigenen Treffer). Aussagen dazu sind als Vermutung markiert.
- Vorwarnzeiten aus dem Code gelten für Krypta und Hölle. Die Frostgruft zieht ihre aus `frost_theme.json` (0,6–0,7 s, einmal 1,6 s).
- `combat_hordes.json` (25–50 Gegner je Raum) gehört zu `src/dungeon/hordes.gd`. Das ist der alte Hauptdungeon, nicht die Story-Welten.
- Mit **(K)** markiert: aus eigener Fachkenntnis, in dieser Sitzung nicht per Link geprüft.

## 2. Die Zahlen, auf denen die Urteile stehen

| Größe | Wert | Ort |
|---|---|---|
| Held: Leben, Tempo, Schutzzeit nach Treffer | 12 halbe Herzen (max 24), 360 px/s, 0,9 s | `*_balance.json player` |
| Schaden je Treffer | Monster 1, Boss 2 halbe Herzen | `monsters.hit_mob/hit_boss` |
| Gegner je Kampfraum | `min(9, 2 + 2·Größe + 0..1)` + `extra` (0→3) = **4–12** | `world_core.gd:595`, `:141` |
| Kurve je Etage | LP ×1,00→2,44 (+0,16), Tempo ×1,00→1,36 (+0,04), `extra` 0,0,0,1,1,1,2,2,2,3 | `hell_floors.json`, `frost_floors.json` (gleich) |
| Boss-LP Etage 1→10 | 46, 60, 90, 105, 120, 160, 175, 190, 240, 340 (×7,4) | Hölle und Frostgruft **gleich** |
| Boss-Takt | Beschwören alle 4,0→2,4 s, Feuerring 0→1,6 s | dito |
| Ausweich-Fähigkeit | erst ab Level 6, Abklingzeit 7 / 8 / 14 s (drei Klassen) | `frost_theme.json` Z. 917, 1069, 1452 |
| Erster Angriff nach dem Spawn | zufällig gestreut (`Rules.first_cooldown(a, randf())`) | `hell_monsters.gd:222` – gut |

**Vorwarnzeiten (Krypta/Hölle, im Code) gegen die Reaktion.** Ein einfacher Seh-Reiz braucht beim Menschen etwa
200–250 ms bis zur Antwort. Eine Wahl unter mehreren Reizen dauert länger. Ein Ausweichschritt von 50–90 px kostet bei
360 px/s noch einmal 0,14–0,25 s. **Mindestens fair sind also etwa 0,4–0,5 s ab dem Moment, ab dem das Ziel feststeht.**

| Art | Vorwarnung | Ziel steht fest | Beispiel | Urteil |
|---|---|---|---|---|
| `swing` | 0,35 s | erst beim Auslösen (Z. 1093) | Skelett: Radius 140, Bogen 115°, alle 1,8 s | **aus dem Nahkampf nicht reagierbar**: 90 px raus = 0,25 s + 0,25 s Reaktion = 0,5 s > 0,35 s |
| `bolt` | 0,35 s | beim Auslösen (Z. 975) | Schütze 700 px/s, Leerenbomber 950 px/s | ab 400 px fair, unter 250 px nicht |
| `dash` | 0,5 s | nach 0,5 s (Z. 926–931) | 760 px/s, 380 px | fair; belohnt Seitwärtslaufen |
| `lob` | 0,45 s + 0,8 s Flug | bei 0,45 s, Marke am Boden | Radius 70 | fair, gut lesbar |
| `slam` | 0,75 s (Sprung 0,7) | Ort fest | Knochenwächter: Radius 280, Welle 0,5 s | fair, wenn die Welle wächst; als Scheibe zu groß (230 px in 0,5 s geht nicht) |
| `ring`, `spiral` | 0,45 / 0,4 s Aufladen | Muster | Kugeln 280–300 px/s | fair (Lücken lesen) |
| Mimik-Biss | 0,5 s, aus `mimic_bite.json` | – | – | fair, und als einzige in Daten |

## 3. Bewertung

### 3.1 Moment zu Moment (Bewegung, Angriff, Ausweichen, Ansagen, Rückmeldung)

- **Ansagen sind sichtbar und gut gemacht.** Es gibt Bodenwarnungen für Fläche, Gasse und Kegel (`_px_ellipse`, Gassen-Telegraph
  Z. 2885), Aufladen mit Partikeln und Klang (`_released`) sowie Gewichtsstufen für Einschläge (Wackeln, Blitz, Rückstoß, Hitstop
  nur für schwere Boss-Schläge). Das entspricht „Juice it or lose it“ und Swinks Forderung, dass Rückmeldung die Wirkung lesbar
  macht. `shake_scale` als Schalter für Barrierefreiheit ist vorbildlich.
- **Das Timing passt nicht dazu.** Hieb und Bolzen zielen bis zum Auslösen nach. Damit hilft Reaktion nicht, nur vorausschauender
  Abstand. Wer getroffen wird, „hätte es nicht sehen können“. Genau das nennen Leitfäden zu Telegraphs den Hauptgrund für
  Unfairness. Csikszentmihalyi: Kompetenz entsteht nur, wenn man versteht, warum man scheitert.
- **Vorwarnzeiten fest im Code** (0,35 / 0,45 / 0,5 / 0,75 s in `_run_act`) widersprechen der Projektregel „Spielwerte aus Daten“.
  Die Frostgruft hat sie in Daten und großzügiger (0,6–0,7 s). Damit fühlen sich die drei Welten im Moment verschieden fair an.
- **Kein allgemeines Ausweichen.** In `hell_game.gd` habe ich keines gefunden. Die Suche nach `dodge/roll/dash` ergab nur
  Klassenfähigkeiten und die F-Rüstungen. `story_sound.gd` hat zwar einen Klang `dodge`. Gibt es doch eine Taste, entfällt M1.
  Hades (Dash), Gungeon (Rolle) und Dead Cells (Rolle) geben das Ausweichen ab Minute 1 (K). Bei uns sind die Etagen 1–3 reines
  Laufen gegen 0,35-s-Hiebe. Die Schutzzeit von 0,9 s fängt Doppeltreffer ab, ersetzt aber kein Werkzeug (SDT: Kompetenz
  braucht ein Verb).
- Rückmeldung beim **eigenen** Treffer habe ich nicht geprüft (`story_feel.gd`). Ein Vorschlag dazu steht unter F5.

### 3.2 Raum zu Raum

- **Gegnerzahl ohne Angriffsordnung.** 9 Skelette greifen in Reichweite zusammen etwa 9 × (1/1,8 + 1/4,2) ≈ **7 Angriffe pro
  Sekunde** an. Die Schutzzeit deckelt den Schaden auf etwa 1,1 Treffer/s, also 12 halbe Herzen in etwa 11 s. DOOM (2016) und
  viele Action-Spiele vergeben „Angriffsmarken“: Nur 2–3 Gegner dürfen gleichzeitig ausholen (K). So bleibt die Masse lesbar.
  Der Zufallsstart der Abklingzeiten bei uns verhindert nur die erste Salve.
- **Raumschloss plus Belohnung** trägt den Takt: schließen, kämpfen, Herz oder Runenstein (35 % / 60 %). Ruhepausen gibt es in
  Schatz-, Schrein- und Geheimräumen. Gut.
- **Erkunden lohnt sich** (Feuerschalen → Tresor mit Herzcontainer und voller Heilung, Druckplatten, 3-Treffer-Schädelhaufen
  vor Geheimwänden). Das Zeichen für das Geheimnis ist lesbar, wie die Risse bei Spelunky und Isaac (K). Aber man **sieht nicht**,
  was hinter einer Tür liegt. Hades zeigt die Belohnung an der Tür und macht jeden Raumwechsel zu einer Wahl (K, SDT: Autonomie).
- **Grube:** 2 halbe Herzen und zurück in den **Startraum**. Der Weg zurück kostet Zeit, aber keine Entscheidung. Strafe besser
  im Raum lassen (F4).

### 3.3 Etage zu Etage

- **Linearer Anstieg ohne Sägezahn in der Etage.** LP und Tempo wachsen gleichmäßig, `extra` in Stufen alle 3 Etagen. Der
  Sägezahn entsteht nur durch den Wächter am Ende. Innerhalb einer Etage ist der erste Raum so schwer wie der letzte vor dem Boss.
- **Bosse zählen gegen Gegner ×7,4 gegen ×2,44.** Ob Boss-Kämpfe dadurch zu lang werden, hängt am Schadenszuwachs des Helden
  (Waffenstufe, Segen, Baum). Den habe ich nicht gemessen. Bei 1 Schaden und 0,26 s Takt dauern sie reine Trefferzeit
  12 s (Etage 1) bis 89 s (Etage 10). Mit realistischer Trefferquote ist es etwa das Doppelte. Das muss gemessen werden (G1).
- **Zehn Boss-Kämpfe je Lauf** (Wächter jede Etage, Mini 3/6/9) geben einen verlässlichen Höhepunkt alle 6–10 min. Das ist gut
  für den Flow. Hades hat vier große Bosse je Lauf (K). Bei uns tragen Etage 3/6/9/10 die größte Last (Ignaroth-Phasen). Das passt.
- **Hölle = Frostgruft in Zahlen** (gleiche `diff`-Kurve, gleiche Boss-LP). Die Welten unterscheiden sich nur in Gegnern und
  Elementen, nicht im Takt. Schell, Linse „Abwechslung“ (K): Jede Welt sollte ihre eigene Spannungskurve haben.

### 3.4 Lauf zu Lauf

- **Tod = Etage 1** bei 10 Etagen × 6–10 min. Ein Lauf dauert also 60–100 min. Ein Tod auf Etage 9 kostet über eine Stunde.
  Die Regel „Kosten des Scheiterns passend zur Häufigkeit“ (Flow) ist gespannt. Hades, Dead Cells und Slay the Spire liegen bei
  etwa 30–60 min je Lauf (K). Spelunky gibt nach jeder Welt Abkürzungen (Derek Yu, K). Deine Entscheidung vom 29.10.
  („Zone von vorn“) gilt. G3 ist deshalb nur eine Option.
- **Meta-Talente öffnen Knoten** statt sie zu schenken (`RunTree.gate`). Das ist das gesunde Modell aus Dead Cells (Baupläne
  erweitern die Auswahl, K). Werte-Talente (Schaden, Tempo, Herzen) sind dagegen senkrechte Macht. Sie machen spätere Läufe
  leichter, ohne neue Herausforderung zu geben.
- **Es fehlt eine Meisterleiter.** Hades (Hitze), Slay the Spire (Aufstieg 1–20) und Dead Cells (Boss-Zellen) geben nach dem
  ersten Sieg selbst gewählte Schwierigkeit mit Belohnung (K). Bei uns ist der Sieg das Ende der Motivation für Achiever.
- **Lauf-Baum: gesund.** 1 Punkt je Level, Ziel Level 14 ± 2, Stufe 2 ab 2 Punkten im Ast: Sid Meiers „interessante
  Entscheidungen“, weil man nicht alles bekommt. Fähigkeiten kommen auf Level 1/3/6/10. Der Ultimate-Ast hat nur die letzten
  4–6 Punkte. Das ist gewollt.

### 3.5 Klassen und Builds

- Asymmetrisch und lesbar: Nahkampf mit Ansturm, Fernkampf mit Rücksprung, Magier mit Blinzeln und drei Elementpfaden,
  Nekromant mit Beschwörungen. Die Ausweichverben unterscheiden sich in der Rolle (Angriff, Rückzug, Umgehen). Das ist gute
  asymmetrische Balance.
- Bau-Vielfalt entsteht aus Baum × Funde × Element. Ob die Synergie „Brand aus der Waffe + Großbrand“ (LAUF-DESIGN 3.5)
  wirklich greift, habe ich im Code nicht geprüft.
- Den Nekromanten ohne Waffenpool beschreibt `BEWERTUNG.md` R1. Das gilt weiter.

### 3.6 Begleiter (`talents.json`, Faktoren zum Grundwert)

| Begleiter | LP | Schaden / Takt = DPS | Besonderheit | Urteil |
|---|---|---|---|---|
| Wolf | 1,0 | 1,0 / 1,0 = **1,00** | – | Bezugswert |
| Bär | 1,7 | 1,3 / 1,35 = **0,96** | Tempo 0,75 | Panzer ohne Wirkung, falls `roar` keine Gegner bindet |
| Falke | 0,7 | 1,15 / 0,8 = **1,44** | fliegt, Tempo 1,5 | **wahrscheinlich dominant**: höchste DPS, und Flug meidet Pfützen und Lava |
| Wasserelementar | 1,0 | **1,00** | Fernkampf 5 m | passt; gut für Reaktionen (nass + Blitz) |
| Knochenkrieger | 1,0 | **1,00** | Schildstoß | Bezug |
| Pyro | 1,2 | 1,1 / 1,0 = **1,10** | Feuerring | leicht stark, Element-Stifter |

Transitive Balance verlangt: mehr Leistung bei mehr Kosten. Der Falke hat keine passende Schwäche. Seine 0,7 LP zählen nur, wenn
Gegner ihn treffen.

### 3.7 Element-Reaktionen: Entscheidung oder Rauschen?

- **Systemisch richtig:** Zonen schaden Helden **und** Gegnern (`enemy_hurt` 0,2–0,45), Gegner malen ihr Element (Stampf-Rest,
  Atem-Wolke, Pfützen-Stampfer), Reaktionen sind stark (`explode_damage` 8, das ist mehr als die LP eines Skeletts auf Etage 1;
  Eis 8 s ×0,4; Dampf blendet). Das ist das Modell der „Chemie-Engine“ von Breath of the Wild: Elemente ändern Zustände nach
  festen Regeln, und Spieler finden Lösungen aus dem Bauch heraus.
- **Aber ob es eine Entscheidung ist, hängt an drei Dingen, die fehlen oder ungeprüft sind:** (1) Man sieht vorher, was ein
  Treffer in dieser Pfütze auslöst. (2) Jede Klasse kann gezielt **vorbereiten** und **zünden**. (3) Es gibt einen Lohn, den man
  merkt. Weil die Gegner den Boden ständig selbst bemalen, ist es wahrscheinlich, dass die meisten Reaktionen **zufällig** passieren.
  Das ist Rauschen, auch wenn es schön aussieht. Ohne Messung (G1) lässt sich das nicht entscheiden.
- Stark: Die Todestexte (`why`: „im Dampf verbrüht“) erfüllen die Kompetenz-Regel (wissen, warum).

### 3.8 Risiko und Lohn

| Wahl | Einsatz | Lohn | Urteil |
|---|---|---|---|
| Dämonensiegel (ab Etage 4, 3–4 je Etage) | 50 %: 3 Dämonen, Raum schließt | 50 %: **dauerhafter** Segen, stapelbar | **keine echte Wahl**: Der Erwartungswert ist immer positiv, Dämonen geben sogar EXP. Rational bricht man jedes Siegel. |
| Feuerschalen → Tresor | Wege, Kämpfe | +1 Herzcontainer, volle Heilung | gut, gestaffelt |
| Druckplatten | Gedächtnis, Fehler löscht | Truhe, Herz | gut, kleine Pause |
| Seitenräume erkunden | Kämpfe, Zeit | Funde, EXP | gut, aber blind (keine Vorschau) |
| Mimik-Truhe | siehe `BEWERTUNG.md` R2 | – | – |

Segen stapeln ohne Deckel bei Tempo (`speed_mul` 1,1ⁿ) und Reichweite (1,25ⁿ). Nur der Schusstakt hat eine Untergrenze (0,12 s,
nach etwa 5 Segen erreicht). `dmg +1` ist flach. Wie stark das ist, hängt vom Grundschaden ab (ungeprüft). Ist er 1, verdoppelt
**ein** Segen den Schaden.

### 3.9 Degenerierte oder tote Strategien

1. **Jedes Siegel brechen** (3.8). Das ist kein Fehler, aber eine Pflichtarbeit statt einer Wahl.
2. **Am Rand kreisen statt kämpfen** gegen Nahkämpfer: Weil der Hieb nachzielt, ist Abstand das einzige sichere Mittel. Der
   Schwertkämpfer verliert damit seinen Kern (Sirlin: Das Spiel soll das gewollte Können belohnen, K).
3. **Falke wählen** (3.6), sobald er offen ist.
4. **Tempo- und Reichweiten-Segen** stapeln in der Hölle ohne Deckel.

## 4. Vorschläge nach Wert und Aufwand

Aufwand S (unter einem halben Tag), M (1–2 Tage), L (mehr). Nachweis je Punkt laut Projektregel: Load-Check plus höchstens eine
Probe mit Bild in einer Story-Szene oder im Story-Testraum.

### Feinschliff (klein, sicher)

**F1 Vorwarnzeiten in die Daten, Ziel früher festlegen.** Problem: 0,35-s-Hieb mit Nachzielen (2, 3.1), Werte im Code.
Quelle: Reaktionszeit 200–250 ms; Leitfaden zu Telegraphs („Zeit zwischen Ansage und Treffer muss Wahrnehmen und Antworten
erlauben“); Dead Cells „versteckte Tricks für Fairness“. Änderung: In `krypta_balance.json` und `hell_balance.json` kommt
`monsters.tells`: `swing 0.5`, `bolt 0.45`, `lob 0.45`, `dash 0.5`, `slam 0.75`, `ring 0.45`, `summon 0.6`, dazu
`aim_lock 0.6` (Anteil der Vorwarnzeit, ab dem das Ziel feststeht). Bosse bekommen `boss_tells` (gleich, Hieb 0,45).
`_run_act` liest diese Werte. Für `swing` und `bolt` wird der Winkel bei `aim_lock × tell` gespeichert statt beim Auslösen.
Wirkung: 0,2 s nach dem Festlegen bleiben 0,25 s Bewegung, also 90 px, und das reicht aus dem Nahkampf. Abstand bleibt eine
Wahl, keine Pflicht. Aufwand S. Risiko: Kämpfe werden leichter. Gegenmittel: `every` des Hiebs 1,8 → 1,6.

**F2 Begleiter angleichen.** Problem: Falke-DPS 1,44, Bär-DPS unter Wolf (3.6). Quelle: transitive Balance. Änderung:
`falcon.every` 0,8 → 0,95 (DPS 1,21). `bear.dmg` 1,3 → 1,4. Falls `roar` noch nicht bindet: `roar` lenkt Gegner im Radius 220
für 3 s auf den Bären. Wirkung: Der Falke ist Schaden mit wenig LP, der Bär ein echter Panzer. Aufwand S. Risiko gering.

**F3 Welten bekommen eigene Kurven.** Problem: Hölle und Frostgruft gleich (3.3). Quelle: Schell, Linse Abwechslung (K);
Sägezahn. Änderung in den Bake-Parametern von `world_core.gd:141` je Welt: Krypta (Einstieg) LP +0,12, Tempo +0,03, `extra` ab
Etage 5; Frostgruft (Kontrolle) LP +0,18, Tempo +0,02, `extra` ab Etage 6; Hölle (Druck) LP +0,14, Tempo +0,05, `extra` ab
Etage 3. Boss-LP der Frostgruft ×1,1, der Hölle ×0,95. Wirkung: Jede Welt fühlt sich im Takt anders an. Aufwand S–M. Risiko:
Die EXP-Kurve verschiebt sich, also `tests/run_curve_test.gd` danach laufen lassen.

**F4 Grube straft im Raum.** Problem: zurück in den Startraum (3.2). Änderung: `pit.return: "room_entry"`. Der Held erscheint an
der Tür, durch die er den Raum betreten hat. Bei verriegeltem Raum bleibt er drinnen. Schaden bleibt 2. Wirkung: Die Strafe
kostet Leben, keinen Fußweg. Aufwand S. Risiko gering.

**F5 Eigener Treffer und Treffer am Helden lesbar.** Problem: Hitstop gibt es nur beim schweren Boss-Schlag. Ob der eigene
Treffer Rückmeldung hat, ist ungeprüft. Quelle: Swink, „Game Feel“; Jonasson & Purho, „Juice it or lose it“; Nijman, „The Art of
Screenshake“ (K). Änderung (nur falls es noch nicht vorhanden ist): `feel.hero_hit_stop 0.05` beim Treffer am Helden plus
Rot-Blitz am Rand; `feel.kill_stop 0.03` beim Todesstoß eines Monsters; `small.shake` 4 → 3, wenn mehr als 6 Gegner leben.
Wirkung: Jeder Treffer am Helden ist eindeutig, das Bild zittert in großen Räumen nicht dauernd. Aufwand S. Risiko gering.

**F6 Segen deckeln.** Problem: Tempo und Reichweite ohne Deckel (3.8). Änderung: `blessings.speed_max 1.3`,
`blessings.range_max 1.6`. Bei Deckel würfelt das Siegel einen anderen Segen. Aufwand S. Risiko gering.

### Mechanik (Regeln ändern)

**M1 Allgemeines Ausweichen ab Level 1** (entfällt, falls es eins gibt). Problem: Das erste Verb gegen Schaden kommt mit
Level 6 (2, 3.1). Quelle: Hades, Gungeon, Dead Cells (K); SDT/PENS (Ryan, Rigby, Przybylski 2006): Kompetenz braucht ein
Werkzeug. Änderung: Taste Umschalt: 110 px in 0,18 s, Schutz 0,12 s, Abklingzeit 1,0 s (`hero.dodge` in den Themen-Daten).
Die Klassenfähigkeit 3 bleibt die stärkere Fassung. Ihre Abklingzeit sinkt um 15 %, damit sie nicht entwertet wird. Wirkung:
Etage 1–3 lehren Ausweichen statt nur Abstand. Aufwand M. Risiko: Kämpfe werden zu leicht. Gegenmittel: Mit Ausweichen bleibt
F1 bei Hieb 0,45.

**M2 Angriffsmarken.** Problem: bis zu 7 Angriffe pro Sekunde, alle gleichzeitig (3.2). Quelle: DOOM-2016-Kampfdesign mit
Marken (K); Hick'sches Gesetz: Mehr gleichzeitige Reize verlängern die Antwortzeit. Änderung: `monsters.tokens: 3` (Bosse zählen
nicht). Ein Monster startet ein `act` nur mit einer freien Marke im Umkreis von 600 px um den Helden. Ohne Marke hält es seine
Abklingzeit bei 0,2 s und umkreist. Fernkampf und Nahkampf haben getrennte Töpfe (2 + 2), damit Schützen nicht verstummen.
Wirkung: Große Räume bleiben lesbar und fühlen sich trotzdem voll an. Aufwand M. Risiko: Räume dauern länger. Gegenmittel:
`extra` behalten, Marken auf Etage 7+ bei 4.

**M3 Siegel als echte Wahl (Chaos-Tor-Modell).** Problem: Brechen lohnt sich immer (3.8). Quelle: Sid Meier, „interessante
Entscheidungen“ (GDC 2012, K); Hades-Chaos-Tore: erst ein Preis, dann ein starker Lohn (K). Änderung: Vor dem Bruch zeigt das
Siegel **zwei** mögliche Segen. Wer bricht, zahlt sicher: 3 Dämonen **und** ein Fluch für die nächsten 2 Kampfräume (Gegner
+20 % Tempo oder kein Herz-Fund). Danach wählt man einen der zwei Segen. `bless_chance` entfällt. Höchstens 2 Siegel je Etage
geben Segen, danach nur Runensteine. Wirkung: Man bricht, wenn der Segen zum Bau passt und das Leben reicht, sonst nicht.
Aufwand M. Risiko: Weniger Segen insgesamt. Gegenmittel: Segen etwas stärker (`rate_mul` 0,85 → 0,82).

**M4 Belohnung an Tür und Karte zeigen.** Problem: Erkunden ist blind (3.2). Quelle: Hades-Türsymbole (K); SDT: Autonomie
heißt wählen mit Wissen. Änderung: Seitenräume abseits des kürzesten Wegs (`on_path` falsch) zeigen an ihrer Tür und auf der
Karte (M) ein Symbol für das, was dort liegt: Truhe, Siegel, Schrein, Feuerschale oder Herz. Geheimräume bleiben verborgen.
Daten gibt es schon (`rooms[].reward`, `icon`). Wirkung: Der Spieler entscheidet: „Brauche ich ein Herz oder riskiere ich das
Siegel?“ Aufwand M. Risiko gering.

**M5 Reaktionen lesbar und belohnt.** Problem: Reaktionen sind wohl meist Zufall (3.7). Quelle: BotW-Chemie-Engine (GDC 2017);
Brogue und DCSS zeigen jede Regel am Objekt (K). Änderung:
- Liegt der Mauspunkt über einer Zone, mit der das Element des eigenen Angriffs reagiert, erscheint dort ein kleines Symbol
  (Explosion, Eis, Dampf, Leiten).
- Neues Pausen-Blatt „Reaktionen“: Eine Reaktion wird beim ersten Auslösen eingetragen (Entdecken für Explorer).
- Reaktionen, die der Held auslöst, geben +25 % EXP auf Tötungen in den folgenden 2 s (`reactions.hero_exp_mul 1.25`).
  Ein Nebenziel je Etage („3 Reaktionen auslösen“) zahlt Seelenkristalle.
Wirkung: Element-Physik wird ein Werkzeug, das man bewusst einsetzt, nicht nur Bild. Aufwand M. Risiko: EXP-Kurve, also
`run_curve_test` danach.

**M6 Sägezahn in der Etage.** Problem: erster Raum so schwer wie der letzte (3.3). Änderung: `mobs` je Kampfraum nach Lage auf
dem kürzesten Weg: das erste Drittel −1, das letzte Drittel +1. Der Raum direkt vor dem Bosstor ist ein Ruheraum (Schrein oder
Herz). Wirkung: Spannung baut sich zur Boss-Tür hin auf, dann löst sie sich. Aufwand M. Risiko gering.

### Größer (neue Systeme)

**G1 Lauf-Messung (Telemetrie, lokal).** Problem: Boss-Dauer, Todesursachen, Reaktionen, Begleiterwahl sind nur Schätzungen.
Quelle: Slay the Spire, „Metrics Driven Design and Balance“ (GDC 2019): Jeder Lauf wurde protokolliert, und Mega Crit nannte das
Werkzeug sein wichtigstes. Änderung: Bei Lauf-Ende eine JSON-Zeile in `user://runs.jsonl` schreiben: Klasse, Welt, Etage, Zeit je
Raum und Boss, Todesursache (`why` plus Angriffs-`id`), Schaden je Angriffs-`id`, Reaktionen nach Auslöser (Held, Gegner, Welt),
Begleiter, Segen, Baum-Knoten. Ein Werkzeug fasst sie zusammen. Wirkung: F1, F2, M3 und M5 werden nachstellbar statt geraten.
Aufwand M. Risiko keins (nur lokal, kein Netz).

**G2 Schwur-Stufen (Meisterleiter).** Problem: Nach dem Sieg fehlt ein Ziel (3.4). Quelle: Hades-Hitze, Slay-the-Spire-Aufstieg,
Dead-Cells-Boss-Zellen (K); Koster, „A Theory of Fun“: Spaß ist Lernen, und ein beherrschtes Muster langweilt. Änderung: Nach
dem ersten Sieg einer Welt gibt es 5 Schwüre, je einzeln wählbar: +1 Gegner je Raum, Elite-Gegner mit einem Zusatz, Bosse mit
Wutphase unter 30 %, Heilung bei Level-Up halbiert, Siegel ohne Wahl. **Vorwarnzeiten werden nie kürzer.** Jeder Schwur gibt
+15 % Seelenkristalle und einen Rahmen am Klassenbild. Wirkung: Gründe zum Wiederspielen für Meister. Aufwand L. Risiko: Inhalt
muss sich tragen. Mit 2 Schwüren starten.

**G3 Etappen-Start (deine Entscheidung, nicht empfohlen ohne dein OK).** Problem: 60–100 min Lauf, Tod = Etage 1 (3.4).
Quelle: Flow-Regel zu den Kosten des Scheiterns; Spelunky-Abkürzungen (Derek Yu, K). Option: Nach dem ersten Sieg über den
Wächter von Etage 3 oder 6 darf ein neuer Lauf dort beginnen: mit Level 4 bzw. 8, Startwaffe, 2 zufälligen seltenen Funden und
ohne die Seelenkristalle der übersprungenen Etagen. Wirkung: Späte Etagen lassen sich üben, ohne die Regel „Tod = Lauf vorbei“
aufzugeben. Aufwand L. Risiko: weicht deine Entscheidung vom 29.10. auf. Alternative ohne Regelbruch: Etagen auf 8 kürzen.

## 5. Werte, die Aufmerksamkeit brauchen (ohne Zielwert, nur Vorschläge)

| Wert | Jetzt | Vorschlag | Grund |
|---|---|---|---|
| Hieb-Vorwarnung (Code) | 0,35 s, Ziel beim Auslösen | 0,5 s, Ziel ab 60 % | F1 |
| Bolzen-Vorwarnung (Code) | 0,35 s | 0,45 s | F1 |
| `talents.json falcon.every` | 0,8 | 0,95 | F2 |
| `talents.json bear.dmg` | 1,3 | 1,4 | F2 |
| `blessings.speed_max` / `range_max` | – | 1,3 / 1,6 | F6 |
| `monsters.tokens` | – | 3 (2 + 2 getrennt) | M2 |
| `pit.return` | Startraum | Raumeingang | F4 |
| `diff` je Welt | gleich in Hölle und Frost | siehe F3 | F3 |

## 6. Top 10 (Wert 1–5 geteilt durch Aufwand)

| # | Vorschlag | Art | Wert | Aufwand | Risiko |
|---|---|---|---|---|---|
| 1 | F1 Vorwarnzeiten in Daten, Ziel früher fest | Feinschliff | 5 | S | gering |
| 2 | G1 Lauf-Messung (Telemetrie, lokal) | Größer | 5 | M | keins |
| 3 | M1 Allgemeines Ausweichen ab Level 1 | Mechanik | 5 | M | mittel |
| 4 | M2 Angriffsmarken (3 gleichzeitig) | Mechanik | 4 | M | mittel |
| 5 | F2 Begleiter angleichen (Falke, Bär) | Feinschliff | 3 | S | gering |
| 6 | M3 Siegel als echte Wahl | Mechanik | 4 | M | mittel |
| 7 | M4 Belohnung an Tür und Karte | Mechanik | 4 | M | gering |
| 8 | F3 Eigene Kurve je Welt | Feinschliff | 3 | S–M | gering |
| 9 | M5 Reaktionen lesbar und belohnt | Mechanik | 4 | M | gering |
| 10 | F6 Segen deckeln | Feinschliff | 2 | S | gering |

Danach: F5, F4, M6, G2, G3 (G3 nur auf deine Entscheidung).

## 7. Quellen

In dieser Sitzung gefunden:
- Slay the Spire, Metrics Driven Design and Balance (Anthony Giovannetti, GDC 2019):
  https://www.gdcvault.com/browse/gdc-19/play/1025731 ·
  https://www.gamedeveloper.com/design/learn-i-slay-the-spire-i-s-metrics-driven-approach-to-game-balancing-at-gdc-2019 ·
  https://gdconf.com/news/learn-slay-spires-successful-metrics-driven-approach-game-balancing-gdc-2019
- Breath of the Wild, Change and Constant (Fujibayashi, Takizawa, Dohta, GDC 2017), Chemie-Engine:
  https://www.thumbsticks.com/gdc-17-breath-of-the-wild-science-lies ·
  https://gamesbeat.com/the-legend-of-zelda-breath-of-the-wild-makes-chemistry-just-as-important-as-physics/
- Dead Cells, Postmortem von Sébastien Benard (GDC 2019): https://www.pocketgamer.biz/video-a-dead-cells-post-mortem-from-motion-twins-sebastian-bernard ·
  Fairness-Tricks: https://80.lv/articles/dead-cells-hidden-tricks-that-make-the-game-feel-fair
- Telegraph-Leitfaden (Sekundärquelle): https://bugnet.io/blog/how-to-design-enemy-attack-telegraphs ·
  Hades und Zugänglichkeit: https://cur.at/Q1SvLFd?m=web
- Reaktionszeit 200–250 ms, Seh- gegen Hörreiz (Woodworth & Schlossberg 1965, über Vortragsfolien):
  https://docs.google.com/presentation/d/1WxDIPRvfaIy6NU_Lq8BWDv5Pm0ZgTtVU/htmlpresent ·
  Antwortaufgaben im Spieldesign (Carleton, GI 2025): https://www.csit.carleton.ca/~rteather/pdfs/GI2025_Response_Tasks.pdf

Aus Fachkenntnis **(K)**, nicht per Link geprüft: Steve Swink, „Game Feel“ (2008); Raph Koster, „A Theory of Fun“ (2004);
Jesse Schell, „The Art of Game Design“ (Linsen); Csikszentmihalyi, „Flow“ (1990); Ryan, Rigby, Przybylski, „The Motivational
Pull of Video Games“ (Motivation and Emotion 30, 2006, PENS); Sid Meier, „Interesting Decisions“ (GDC 2012); Jonasson & Purho,
„Juice it or lose it“ (2012); Jan Willem Nijman, „The Art of Screenshake“ (2013); DOOM (2016), Angriffsmarken im Kampfdesign
(GDC-Vortrag von id Software); Derek Yu, „Spelunky“ (Boss Fight Books 2016); Hades: Türsymbole, Chaos-Tore, Hitze; Slay the Spire:
Aufstieg; Dead Cells: Boss-Zellen und Baupläne; Gungeon: Ausweichrolle; David Sirlin, „Playing to Win“; Brogue und DCSS: Regeln
am Objekt sichtbar.
