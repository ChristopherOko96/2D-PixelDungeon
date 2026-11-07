# Beuteordnung der Welten (verbindliches Regelwerk)

Stand 07.11.2026, vom Nutzer freigegeben (Konzeptseite „Beuteordnung der Welten“,
https://claude.ai/artifact/MP6d8JjbiiVeWggCjXjkHA). Gilt für **alle** Story-Welten
(Krypta = Story 1, Frostgruft = Story 2, Hölle = Story 3) und jede künftige Welt.
Alle Zahlen stehen in `assets/data/reward_rules.json`, der Code liest nur dort
(`src/progress/reward_rules.gd`). Wer eine Zahl ändert, ändert sie dort und hier.

Leben wird in **LP** gezählt (1 Herz = 2 LP, so zählt das Spiel intern).

---

## 1. Kapitel, Helden und Tiefe

### 1.1 Freischaltung (Hauptsystem)
- Story 1 ist offen. Story 2 öffnet sich, sobald **irgendein** Held Story 1 durchgespielt
  hat (Endboss besiegt), Story 3 nach Story 2. Die Freischaltung gilt fürs ganze Konto
  und bleibt, auch wenn der Held später stirbt.
- Ein Held ist eine Klasse des Kontos (Schwertkämpfer, Bogenschütze, Magier, Nekromant).

### 1.2 Fortlaufender Held (Hauptsystem)
- Wer Story K durchspielt, dessen Held wird **gesichert**: Leben, Lebensgrenze, Gold,
  Gegenstände, Segen, Laufstufe, Relikt, alles was von Etage zu Etage mitgeht
  (`StorySave.CARRIED`). Datei `user://story_progress.json`.
- Mit genau diesem Held kann man Story K + 1 weiterspielen (Karte „MIT HELD WEITER“).
  Andere Klassen dürfen das nicht mit Übernahme, sie haben Story K nicht durchgespielt.
- Stirbt der Held, ist er weg: mit Gold und Gegenständen. Die Freischaltung bleibt.
- Startet man mit derselben Klasse einen **neuen** Lauf, geht ein wartender Held dieser
  Klasse verloren (das Menü fragt vorher).
- Heldenstufe, Talente, Runen und Seelensplitter gehören wie bisher dem Konto.

### 1.3 Neuer Held in einem freigeschalteten Kapitel (Nebensystem)
- Ist Story K freigeschaltet, kann jeder Held dort **frisch** beginnen: Startwerte, kein
  Gold, keine Gegenstände. Dann gelten die Regeln genau wie für Story 1 (Tiefe = Etage).

### 1.4 Tiefe T
Alle Regeln rechnen mit der **Tiefe T** statt mit der Etage E:

    T = E + 10 × (Kapitel, die dieser Held schon durchgespielt hat)

- Frischer Held: T = E (1 bis 10) in jedem Kapitel.
- Fortlaufender Held in Story 2: T = 11 bis 20, in Story 3: T = 21 bis 30.
- **Ausnahme:** Die Legendär-Karte (Abschnitt 4) gilt immer nach der Etage E des Kapitels.
- **Kapitelhärte:** Für einen fortlaufenden Held haben Gegner und Bosse mehr Leben:
  × (1 + 0,6 × K), K = schon durchgespielte Kapitel (Story 2: × 1,6, Story 3: × 2,2).

### 1.5 Debug
- Hauptmenü DEBUG → „STORY (DEBUG)“: alle Welten offen, jede Klasse, ohne Speichern
  (kein Spielstand, keine Freischaltung, kein gesicherter Held). Zum Austesten.

---

## 2. Schaden, Leben, Herzen (Maßeinheit Treffer)

| Größe | Regel |
|---|---|
| Schaden je Treffer `dmg(T)` | T 1–3: 1 LP · 4–6: 2 · 7–10: 3 · ab 11: 1 + ⌊(T−1)/3⌋ (11–12: 4, …, 28–30: 10) |
| Bosse | doppelter Schaden |
| Alles, was den Helden trifft | Gegner, Geschosse, Flächen, Fallen, Lava, Dornen: Grundschaden × dmg(T) |
| Lebensgrenze-Deckel | 20 × dmg(T) LP (Gegenstands-Leben liegt wie bisher obendrauf) |
| Start | 12 LP wie bisher (plus Talente) |

**Heilherz** (rot): heilt 2 Treffer = 2 × dmg(T) LP. Bleibt liegen, wenn das Leben voll ist.

**Lebensherz** (golden): hebt die Lebensgrenze um seinen Wert **und** heilt genau so viel
(2 LP übrig, Lebensherz +2 → 4 LP; Grenze 5 → 7). Über dem Deckel heilt es nur.
Wird immer aufgehoben.

| Quelle | Lebensherz |
|---|---|
| Etagenwächter und Mini-Wächter (nicht der Endboss) | +4 LP |
| Rätsel Stufe 3 | ⌈T/2⌉ LP |
| Rätsel Stufe 4 | ⌈T/2⌉ + 1 LP |
| Rätsel Stufe 5 | ⌈T/2⌉ + 2 LP |
| Verborgener Raum, Schatztresor | wie Stufe 3 |
| Opferstein, viertes Opfer | wie Stufe 5 |

---

## 3. Beutewert, Seltenheit, Gold, Runen

    Beutewert W = T + 2 × (Stufe − 1)
    Gold einer Rätseltruhe = 10 + 4 × W

- Mindestseltenheit des garantierten Stücks: W 1–3 ungewöhnlich, 4–9 selten, ab 10 episch.
  **Nie legendär über den Beutewert.**
- Seltenheitsgewichte aller normalen Würfe, Etage 1 → 10 (darüber wie 10):
  gewöhnlich 60 → 15, ungewöhnlich 28 → 30, selten 10 → 35, episch 2 → 20, **legendär 0 → 0**.
- Gold sonst unverändert (Gegner 1, Wächter 40, Etage erreicht 15, Truhe 3 + E, Kisten 3).
  Die Laufsumme (etwa 2.400 Gold bei allen Rätseln) ist die Grundlage für Händlerpreise.

### Rätselstufen 1–5 (jede Etage gleich)
| Stufe | Gegenstände | Heilherzen | Lebensherz | Rune | Steine | nie verflucht |
|---|---|---|---|---|---|---|
| 1 Leicht | 1 garantiert | 1 | – | – | – | – |
| 2 Etwas schwerer | 1 garantiert + 1 Truhenwurf | 1 | – | 10 % | – | – |
| 3 Mittelschwer | 1 garantiert (eigene Klasse) + 1 Truhenwurf | 2 | ⌈T/2⌉ | 25 % | Kristall oder Fluchbrecher | ja |
| 4 Schwer | 2 garantiert (eins eigene Klasse) | 2 | ⌈T/2⌉+1 | 50 % | Aufwertungsstein | ja |
| 5 Sehr schwer | 2 garantiert eigene Klasse, eins eine Seltenheit höher (max. episch) + 1 Truhenwurf | 3 | ⌈T/2⌉+2 | 1 sicher | Aufwertungs- + Würfelstein | ja |

„nie verflucht“ gilt für die garantierten Stücke, nicht für legendäre (Abschnitt 4).

### Stufenverteilung je Etage (Chance je Rätselraum)
| Etage | St.1 | St.2 | St.3 | St.4 | St.5 |
|---|---|---|---|---|---|
| 1–2 | 70 | 30 | – | – | – |
| 3–4 | 25 | 45 | 30 | – | – |
| 5–6 | 5 | 25 | 40 | 22 | 8 |
| 7–8 | – | 10 | 35 | 38 | 17 |
| 9–10 | – | 5 | 15 | 45 | 35 |

Jede Rätsel-Raumdatei trägt ihre Stufe (`loot.tier` 1–5 der Schatztruhe); der Etagenbau
zieht nach dieser Tabelle. Alte Dateien mit 1–3 wurden umgestellt: 1 → 2, 2 → 3, 3 → 4.

---

## 4. Legendär-Karte

Chance, dass das **beste** Stück einer Rätseltruhe legendär wird (nach Etage E des Kapitels):

| | E5 | E6 | E7 | E8 | E9 | E10 |
|---|---|---|---|---|---|---|
| Stufe 5 | 3 % | 3 % | 3 % | 3 % | 35 % | **100 %, nie verflucht** |
| Stufe 4 | – | – | 3 % | 3 % | 3 % | 35 % |
| Stufe 3 | – | – | – | – | 3 % | 3 % |

Alle anderen Felder: 0. Dazu **Endboss Etage 10: genau ein legendäres Stück** (Waffe,
Rüstung, Ring oder Amulett, für die Klasse des Helden, nie verflucht).

- **Fluch:** Jedes legendäre Stück außer Etage 10 Stufe 5 und Endboss würfelt erst eine
  Fluchchance zwischen 75 und 90 %, dann mit ihr den Fluch.
- **Überall sonst nie legendär:** Gegner, Kisten, Truhen, Goldkiste, Mimik, Etagen- und
  Mini-Wächter, Tresor, Geheimräume, Teufelspakt, Opferstein.
- **Machtrüstungen** (Rüstungen mit Kraft): nebenbei nur epische; legendäre nur über die
  Karte und den Endboss.
- Blutpreis, teurer Pfad bei Stufe 5: eine zweite Chance aus der Karte.

---

## 5. Alle Quellen

| Quelle | Inhalt |
|---|---|
| Gegner | 1 Gold, Rune 1 %, keine Gegenstände |
| Raum gesäubert | 35 % Heilherz, sonst 60 % 1 Gold |
| Kiste/Fass/Vase | Gegenstand 14 → 24 % (normale Seltenheit), sonst 35 % nichts, 45 % 3 Gold, 20 % Heilherz; Rune 6 % |
| Normale Truhe | Gegenstand 70 → 90 %, Gold 3 + E, Heilherz 25 %, Rune 15 %, Machtrüstung 10 % (nur episch); erste Truhe der Etage: Kristall usw. |
| Goldkiste (60 % je Etage) | Waffe oder Rüstung selten+, Kristall, Fluchbrecher; Machtrüstung 20 % (episch) |
| Mimik | Waffe oder Rüstung selten+; Machtrüstung 35 % (episch) |
| Mini-Wächter (E3, 6, 9) | Stück selten+ (E9: episch), Lebensherz +4, Machtrüstung 50 % (episch), Relikt, 40 Gold, Rune |
| Etagenwächter | Stück selten+ (ab E7 episch), Lebensherz +4, Machtrüstung 50 % (episch), Relikt, 40 Gold, Rune |
| Endboss E10 | genau 1 legendäres Stück (nie verflucht), 40 Gold, 2 Runen |
| Rätseltruhe | nach Stufe (Abschnitt 3) + Legendär-Karte |
| Geheimraum (Geheimwand) | wie Stufe 2, nie Mimik |
| Verborgener Raum (Plattenrätsel) | wie Stufe 3, nie Mimik |
| Schatztresor | Gold 2 × (10 + 4 × (T + 4)), Rune sicher, 1 Stück selten+, Lebensherz wie Stufe 3, 1 Heilherz |
| Etage erreicht | 15 Gold |

---

## 6. Preisräume

Preis in Treffern, Lohn in Beutewert.

- **Blutpreis** (Hölle): drei Pfade, 2/3/4 Dornenherzen à 2 × dmg(T) LP (stoppt bei 1 LP).
  Truhe = Raumstufe −1 / ±0 / +1 (Stufe 5 teuer: zweite Legendär-Chance). Dornen verletzen
  je Feld nur einmal, der Rückweg ist frei. Inschrift erklärt es.
- **Teufelspakt** (Hölle): Lebensgrenze −(2 × dmg(T)) dauerhaft (nie unter 12 LP). Eins von
  drei offenen Angeboten auf W = T + 10: episches Stück eigene Klasse, nie verflucht, Stufe +2;
  zwei Dämonensegen; drei Runen + Aufwertungsstein. Nie legendär.
- **Opferstein** (Hölle): jedes Opfer kostet 2 × dmg(T) LP (nie tödlich). 1.: Gold wie Stufe 2,
  2.: Stück wie Stufe 3, 3.: wie Stufe 4, 4.: wie Stufe 5 mit Lebensherz, ohne Legendär-Chance.
- **Opfergrube** (Hölle): Wellenkampf, Truhe steigt je überstandener Welle um eine Stufe (max. 5),
  nach jeder Welle darf man nehmen und gehen.
- Krypta „Grabraub“, Frostgruft „Eisopfer“: Richtung, noch nicht gebaut.

---

## 7. Inschrift

Jede Rätsel-Inschrift endet mit einer festen, aus den Daten geschriebenen Zeile:

    Schwierigkeit ◆◆◆◆◇ · Lohn: episch oder besser, 2 Stücke, Lebensherz +5, Rune möglich, Legendär-Chance

Rätselräume sind Nebenräume: Wer die Zeile liest und nicht will, geht vorbei.

---

## 8. Bosse und Lava

- Bosse erscheinen nie mitten in der Lava (jeder Bossraum hat eine feste Mitte, 5 × 5 Felder).
- Lavabosse (`hell_balance.json` monsters.lava_bosses: Glutwächter, Kesselbrut) gehen durch Lava.
- Alle anderen laufenden Bosse (Kerkermeister, Klagender Hüter, Seelenhirte, Ignaroth …) betreten nie
  Lava: Sie bleiben am Rand stehen oder springen über einen schmalen Strom (boss_leap: bis 4 Felder,
  0,7 s). Fliegende Bosse sind davon nicht betroffen. Test: `tests/hell_boss_lava_test.gd`.

## 9. Für später

- Händlerpreise nach der Goldsumme je Lauf.
