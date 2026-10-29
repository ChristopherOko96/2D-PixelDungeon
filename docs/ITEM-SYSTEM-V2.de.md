# Item-System 2: Inventar, Verbrauch, Ausrüstung mit Zufall

Status: **umgesetzt 29.10.2026** ("Ja, mit allen vier"). Lauf, Tod, Level und Meta stehen in
`docs/LAUF-DESIGN.de.md`; dieses Dokument ist die Quelle der Item-Regeln.
Die vier neuen Verbrauchsitems (3.4, 3.5) sind vom Nutzer freigegeben.

Auftrag (Dwayne): Item-System, eventuell Klon-Beschwörung auf Zeit, für
Krypta, Hölle und Frostgruft. Nutzer: Inventar + Verbrauchsitems + Ausrüstung,
die das Spiel beeinflusst; Zufall, der gut oder schlecht ausgehen kann, nach
dem Prinzip klassischer Roguelikes (eigene Inhalte, nichts übernommen).

## 1. Überblick

Die Krypta hat schon ein Item-System (`docs/GEGENSTAENDE.de.md`): Waffen in
fünf Seltenheiten, unbekannt und oft verflucht, Flüche, die ein
Fluchbrecherstein zum Segen macht, zwölf Tränke mit pro Lauf gemischten Farben,
Identifizierungskristalle. Version 2 macht daraus **ein gemeinsames System für
alle drei Welten** und erweitert es um **Ausrüstungsplätze**, **Aufwertungsstufen**
und eine **Klon-Beschwörung auf Zeit**.

## 2. Spielgefühl

„Was ist das?“ Jeder Fund ist eine kleine Wette: Der unbekannte Ring kann dich
schneller machen oder dein Licht dämpfen, der rote Trank heilen oder
explodieren. Wer Kristalle spart, spielt sicher; wer probiert, lernt schneller
und riskiert mehr. Gute Funde verändern den Lauf spürbar.

## 3. Regeln

### 3.1 Ein Inventar für alle Welten
- Rucksack mit 12 Plätzen (wie jetzt), Taste **I**, das neutrale Inventar-Fenster
  (`src/ui/inventory_panel.gd`) in allen drei Welten. Das Spiel läuft weiter.
- Ein Regelkern (`src/items/inventory.gd`, `item_rules.gd`) für alle Welten;
  Hölle und Frostgruft bekommen einen Adapter wie bei den Helden
  (`src/hero/story_items.gd`): Funde aus Truhen, Fässern, Bossen und
  Geheimräumen, Wirkungen auf Herzen, Tempo, Schaden, Abklingzeiten.
- Speicherstände sichern den Rucksack und die Ausrüstung mit.

### 3.2 Ausrüstungsplätze (neu)
| Platz | Wirkt auf | Beispiele für Grundwerte |
| --- | --- | --- |
| Waffe | Angriff (wie jetzt) | Schaden, Tempo, Reichweite, Wirkungen |
| Rüstung (neu) | Verteidigung | +Herzen, Treffer abwehren, Tempo − |
| Ring (neu) | eine Spielregel | Krit-Chance, Abklingzeit, Lebensraub, Licht |
| Amulett (neu) | eine große Wirkung | Klon beim Fallen, Zeitlupe bei wenig Leben |

### 3.3 Zufall: gut oder schlecht
- **Unbekannt**: Ausrüstung zeigt nur Art und Seltenheit. Anlegen oder ein
  Kristall zeigt Werte, Aufwertungsstufe und Fluch.
- **Aufwertungsstufe** von −3 bis +3, beim Fund gewürfelt; verfluchte Stücke
  haben meist negative Stufen. Jede Stufe ändert die Grundwerte um einen festen
  Anteil (Formel 4.2).
- **Fluch** (wie jetzt bei Waffen, neu auch für Rüstung, Ring, Amulett):
  klebt, bis ein Fluchbrecherstein ihn bricht; dann wird er zum Segen.
- **Tränke** (die zwölf vorhandenen): unbekannt nach Farbe, Farben pro Lauf
  neu gemischt; Trinken oder Werfen verrät sie für das Team.

### 3.4 Klon-Beschwörung auf Zeit
Der Klon der Hölle (`state.skill`, Taste Q) wird ein Gegenstand:
**Klonsiegel (Vorschlag)** – benutzen ruft einen Klon für 20 s, der mit
kämpft und Gegner ablenkt; verbraucht sich. In der Krypta erscheint dasselbe
Klonbild (Spiegelbild des Helden). Seltene Version: 35 s.

### 3.5 Neue Verbrauchsitems (nur Vorschläge, brauchen dein OK)
| Vorschlag | Wirkung | Zufall |
| --- | --- | --- |
| Klonsiegel | Klon auf Zeit (3.4) | – |
| Aufwertungsstein | +1 Stufe auf ein Ausrüstungsstück | bei verfluchten 50 %: Fluch wird stärker |
| Würfelstein | würfelt die Stufe eines Stücks neu (−3 … +3) | reines Glück |
| Spiegelkristall | zeigt alle Tränke im Rucksack | – |

## 4. Formeln

### 4.1 Seltenheit eines Funds
Gewichte wie jetzt (`items.json` → `rarity_weights`), linear von Etage 1 bis 10:
`gewicht(r, e) = lerp(w1(r), w10(r), (e − 1) / 9)`; Wahl gewichtet.

### 4.2 Aufwertungsstufe
`stufe = clamp(round(normal(mittel, streuung)), −3, +3)` mit
`mittel = +0,5` (unverflucht) bzw. `−1,5` (verflucht), `streuung = 1,0`.
Wirkung: `wert = grundwert × (1 + 0,15 × stufe)` (bei Werten, wo weniger besser
ist, z. B. Abklingzeit: `grundwert × (1 − 0,08 × stufe)`).

### 4.3 Fluchchance je Platz
`fluch(platz) = curse_chance × anteil(platz)`; Vorschlag: Waffe 0,6 (wie jetzt),
Rüstung 0,5, Ring 0,45, Amulett 0,35.

## 5. Sonderfälle
- Voller Rucksack: der Fund bleibt liegen und leuchtet; Hinweis „Rucksack voll“.
- Verfluchtes Stück angelegt und Fluchbrecher fehlt: es bleibt; Ablegen zeigt
  „Der Fluch hält es fest“.
- Klonsiegel ohne Platz zum Erscheinen (Wand): der Klon erscheint am nächsten
  freien Punkt um den Helden.
- Wechsel der Welt (Krypta ↔ Story): Funde gelten je Lauf; Story-Läufe beginnen
  mit leerem Rucksack und der Startwaffe ihrer Klasse.
- Mehrspieler (Krypta): Wissen über Tränke teilt das Team (wie jetzt), Ausrüstung
  jeder für sich.

## 6. Abhängigkeiten
`inventory.gd`, `item_rules.gd`, `items.json`, `inventory_panel.gd` (Krypta);
`hell_game.gd`, `relic_kit.gd` (Relikte bleiben eigene Sache), `story_save.gd`,
Truhen der Hölle; HUD (`hud_kit.gd`: Ausrüstung als kleine Symbole unter den
Herzen); Sounds (Fund, Anlegen, Fluch).

## 7. Stellschrauben (alles in `items.json`)
Rucksackgröße, Seltenheitsgewichte je Etage, Fluchchance je Platz, Mittel und
Streuung der Stufen, Anteil je Stufe, Klon-Dauer, Funde je Quelle.

## 8. Abnahmekriterien
- In allen drei Welten öffnet **I** dasselbe Inventar; Funde aus Truhen landen dort.
- Rüstung, Ring und Amulett lassen sich anlegen und ändern die Werte sichtbar
  (Statusseite, HUD).
- Ein unbekanntes Stück zeigt erst nach Anlegen oder Kristall seine Stufe und
  einen Fluch; ein Fluch hält das Stück, bis ein Fluchbrecher ihn bricht.
- Die Stufen folgen Formel 4.2 (Test mit festem Seed).
- Das Klonsiegel ruft den Klon für die eingestellte Zeit; danach verschwindet er.
- Speichern und Laden behalten Rucksack und Ausrüstung.

## Reihenfolge danach (aus Dwaynes Liste)
1. Level-Up im Spiel sinnvoll: eine Karte-Wahl-Logik für alle Welten
   (Krypta-Karten und Hell-Karten zusammenführen).
2. Item-System 2 (dieses Dokument).
3. Sounds je Klasse und Monster.
4. Animationen für jede Klasse und jedes Monster (mit Körperteilen für die
   Hell- und Frost-Monster).

## Umsetzung (29.10.2026)

- Regeln: `src/items/item_rules.gd` (Plätze, Stufen, Werte und Flüche aller angelegten Stücke),
  `src/items/inventory.gd` (Funde, Stufen beim Fund, Fluchchance je Platz, Abnehmen, Aufwerten, Neu würfeln,
  Benutzen, Klon, feste Funde je Etage, Beute der Mini-Wächter). Daten: `assets/data/items.json`
  (`gear`, `stage`, `curse_by_slot`, `per_floor`, vier Verbrauchsitems). Bilder: `scripts/make_item_sprites.gd`
  → `assets/sprites/items/` (5 Rüstungen, 5 Ringe, 5 Amulette, 4 Verbrauchsitems im 0x72-Stil).
- Fenster `src/ui/inventory_panel.gd` im neutralen Stil, in allen Welten gleich (Taste I).
- Krypta: erste Truhe jeder Ebene mit den festen Funden; Mini-Wächter lassen ein seltenes Stück fallen;
  der Klon ist ein Spiegelbild in der Gestalt der Klasse, das schießt.
- Hölle und Frostgruft: `src/hero/story_items.gd` lässt dieselben Regeln laufen (Schatten-Held) und übersetzt
  sie: Werte als Faktoren auf Schaden, Angriffstempo, Tempo und Abklingzeit; Herzen der Rüstung; Brand, Gift,
  Frost, Krit, Lebensraub, Nachbeben und Kettenblitz bei Treffern; Siegel, Zerbrechlich, Nacht; Tränke auf den
  Helden und geworfen auf Monster; das Klonsiegel ruft den Klon der Welt. Funde aus Truhen, Riesentresor,
  Siegeln, Wächtern und Mini-Wächtern; ist der Rucksack voll, bleibt der Fund am Boden und wird beim
  Darüberlaufen aufgehoben. Der Rucksack zieht mit auf die nächste Etage und in den Speicherstand.
- Tests: `tests/items_v2_test.gd` (Krypta), `tests/story_items_test.gd` (Hölle, Frostgruft).
  Belege: `production/qa/evidence/items-v2` (`scripts/capture_items_v2.gd`).
