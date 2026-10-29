# Plan: offene Karten, Klassen-Ausbau, Themen-Bosse und Skilltree

Stand: 28.10.2026. **Mit dem Nutzer abgestimmt, in Umsetzung** (siehe
„Umsetzungsstand“). Grundlage sind die Wünsche des Nutzers vom 28.10.2026 und
die Empfehlungen, die er für alle vier offenen Fragen angenommen hat (siehe
„Entscheidungen“).

**Story zuerst, Endlos später (Entscheidung des Nutzers, 28.10.2026, nachmittags):**
Der Story-Modus öffnet eine Story-Auswahl (`assets/data/story_campaigns.json`):
Story 1 „Krypta der Verdammten“ ist spielbar, Story 2 „Die Frostgruft“ (Eis-Thema,
Entwurf: Artefakt „Die Frostgruft“) und Story 3 stehen auf BALD. Der Endlos-Modus
steht im Menü auf BALD; die offenen Etagen bleiben für ihn im Code und lassen
sich mit `--endless` starten. (Vormittags war kurz das Gegenteil entschieden:
nur Endlos, Story gestrichen.)

## Umsetzungsstand

| Teil | Stand | Wo |
|---|---|---|
| Aggro nach Sicht | umgesetzt | `src/combat/aggro.gd`, `balance.aggro`, `tests/aggro_test.gd` |
| Offene Etagen mit Räumen, Gängen, Truhen und Kisten | umgesetzt | `src/dungeon/open_floor.gd`, `assets/data/dungeon_open_floor.json`, `tests/open_floor_test.gd`, `tests/open_floor_game_test.gd` |
| Story-Auswahl (Story 1 spielbar, 2 und 3 BALD), Endlos auf BALD | umgesetzt | `src/main_menu.gd`, `assets/data/story_campaigns.json`, `tests/main_menu_flow_test.gd` |
| Story 2 „Die Frostgruft“ | Entwurf zur Abnahme | Artefakt „Die Frostgruft“ |
| Nebel (Minikarte offen) | umgesetzt für Endlos-Etagen | `src/vfx/fog_memory.gd`, `themed_monsters.json` `fog` |
| Themen, 0x72-Monster, Bosse und Nebenbosse aus `codex/0x72-dungeon` | umgesetzt für Endlos-Etagen | `src/combat/sheet_monsters.gd`, `src/vfx/sheet_art.gd`, `assets/data/themed_monsters.json`, `tests/sheet_monsters_test.gd`, Bilder `production/qa/evidence/themed-floors/` |
| Endbosse mit zwei Phasen | offen | – |
| Kleinere Waffen und Waffenstufen | offen | – |
| Skilltree im Menü | ersetzt durch Talentbäume und Seelensplitter (29.10.2026) | `docs/TALENTE-SEELENSPLITTER.de.md` |

**Themen-Etagen (29.10.2026):** Jede Endlos-Etage zieht eines der Themen Gruft,
Orklager, Hölle oder Himmel, nie zweimal hintereinander. Das Thema färbt Boden
und Wände, wählt die Bannerfarbe und malt Details (Spinnweben, Moos, Lavarisse,
Goldeinlagen) in den gebackenen Raum. Die Gruppen kommen aus der Monsterliste
des Themas; auf Boss- und Nebenboss-Etagen führt der Boss oder Nebenboss des
Themas die Endgruppe an (Faulkönig/Seelenrufer, Ogerkriegsherr/Kristall-Wogol,
Höllenprinz/Geflügelter Chort, Seraphiel/Goldener Engel). Diese Gegner und die
Orks sind **Sheet-Monster**: Sie werden aus fünfzeiligen Sheets gezeichnet und
haben keinen Teile-Kampf; Angriff, Treffer und Tod der Sheets sind aus den
0x72-Frames abgeleitet, die Bosse tragen dazugemalte Pixelteile (Nutzerentscheid
29.10.2026: „Sheets übernehmen“). Gegner, die es als Gruft-Rig gibt
(Mini-Zombie, Nekromant), bleiben Rigs. Über allem liegt der Nebel: Ungesehenes
ist schwarz, Gesehenes gedimmt. Die Story-Gruft ist unverändert.
Bilder: `scripts/capture_themed_floors.gd`.

**Offene Etagen, wie sie gebaut werden:** Eine Etage ist eine Karte von
76 × 56 Tiles. Die Räume liegen auf einem Raster aus 4 × 3 Zellen, je Zelle ein
Raum, und die benutzten Zellen hängen immer zusammen. Nachbarräume verbindet ein
5 Tiles breiter Gang; ein Teil der übrigen Nachbarpaare bekommt einen zweiten
Gang, damit die Karte Schleifen hat. Es gibt keine Türen. Wände und Boden baut
`CryptGenerator`, gezeichnet wird mit dem 0x72-Gruft-Renderer des Spiels
(`src/crypt_0x72_art.gd`), es kommt also keine eigene Grafik dazu. Der Startraum
ist leer; jeder mittlere Raum hat eine schlafende Gegnergruppe; im Raum, der am
weitesten vom Start entfernt ist, wartet die Endgruppe der Etage (Boss,
Nebenboss oder starke Gruppe) mit der Treppe nach unten. Hordenwellen gibt es
auf offenen Etagen nicht. Truhen stehen an Nordwänden der mittleren Räume, Kisten
in kleinen Gruppen an den Wänden. Alle Werte stehen in
`assets/data/dungeon_open_floor.json`. Bilder: `production/qa/evidence/open-floors/`,
ganze Karten mit `scripts/capture_open_floor.gd`.

Die Debug-Levelauswahl im Menü springt weiter in die alte Raumkette, die sie
auflistet; Tests und Netzwerk-Smoke-Läufe nutzen ebenfalls die Raumkette, außer
sie starten mit `--endless`.
Alle Zahlen sind Startwerte; beim Umsetzen gehören sie in `src/data/balance.json`
bzw. die passenden Daten-Dateien und werden beim Spielen feinjustiert.

Grafiken kommen ausschließlich aus den Vorgaben des Nutzers
(`Sprite Sheet 0x72.rar`): 0x72 DungeonTileset II v1.7 und Dungeon Tileset II
Extended (beide CC0), ganzzahlig 2× auf dem 32-px-Raster. Pakete ohne
Lizenznachweis (Fantasy RPG NPCs, lose Einzel-Sheets unbekannter Herkunft)
werden erst genutzt, wenn ihre Quelle geklärt ist.

## Entscheidungen (28.10.2026)

1. **Grundlage:** Wir bauen auf `origin/main` auf (Commit `1c15294`, Klassen,
   Fähigkeiten, Team-EXP, Gruft-Etagen). Aus `codex/0x72-dungeon` (Commit
   `58d0467`) werden übernommen: Kartengenerator 4, Tile-Kollision, Fog of War,
   Aggro-System, Themen, 0x72-Monster und -Bosse, Raumhülle aus 0x72-Kacheln.
2. **Kartenform:** offene Hallen mit breiten Durchgängen und Säulen, keine
   organischen Höhlen. Die gemauerten 0x72-Wände tragen diese Form; für Höhlen
   fehlt passende Felsgrafik.
3. **Skilltree:** vor allem Freischaltungen (Startwaffen, Varianten von
   Fähigkeiten) plus wenige, gedeckelte Werte-Boni. Er darf die Level-up-Karten
   im Lauf nicht entwerten.
4. **Zweite Phase:** alle Endbosse, keine Nebenbosse.

## Schritt 0 · Grundlage zusammenführen

- Die Systeme aus `codex/0x72-dungeon` auf `origin/main` übertragen (Branch
  `codex/port-0x72-onto-main`).
- Ergebnis der Sichtung (28.10.2026): main hat Raumhülle, Kamera und 0x72-Wände
  schon selbst. Generator 4 des Zweigs wird nicht übernommen, weil er Räume mit
  Gängen baut; die offenen Etagen entstehen direkt auf mains `CryptGenerator`.
  Übernommen werden Aggro (erledigt), Nebel, Themen, 0x72-Monster und Bosse.
- Bestehende Tests beider Linien laufen danach gemeinsam grün.
- Auf den Codex-Zweigen wird laut Nutzer nicht mehr gearbeitet.

## Schritt 1 · Waffen kleiner, Grundangriff mit sichtbaren Stufen

**Waffengröße.** Waffen bleiben pixelgenau 2×. Jede Klasse beginnt mit einer
kleinen Waffe aus 0x72; sie sitzt am Griffpunkt der Hand und liegt beim Zielen
nach oben teils hinter dem Körper. Größere Sprites kommen erst über Stufen.

**Grundangriff-Pfad.** Neue Level-up-Karten für den Linksklick, 3 Stufen nach
der Startwaffe. Jede Stufe tauscht das Waffen-Sprite und ändert sichtbar den
Angriff:

| Klasse | Start | Stufe 1 | Stufe 2 | Stufe 3 |
|---|---|---|---|---|
| Schwertkämpfer | Kurzschwert | Langschwert: Klinge länger, +20 % Reichweite des Hiebs, +1 Schaden | Zweihänder: Hieb im Halbkreis, Rückstoß | Flammenklinge: setzt 3 s in Brand |
| Bogenschütze | Kurzbogen | Langbogen: Pfeil durchschlägt einen Gegner | Kompositbogen: zwei Pfeile pro Schuss | Explosivpfeil: kleiner Flächenschaden beim Aufprall |
| Magier | Holzstab | Kristallstab: Kugel teilt sich beim Aufprall in 3 | Glutstab: größere Explosion, Brandfläche 2 s | Arkanstab: Kugel lenkt leicht auf das nächste Ziel |

Der Kettenblitz bleibt die Fähigkeit 2 des Magiers und wird hier nicht doppelt
vergeben.

**Keine abstrakten Werte.** Karten und Seitenleiste nennen keine Werte wie
„Reichweite“ mehr. Jede Karte beschreibt, was man im Spiel sieht. Die
Seitenleiste zeigt stattdessen Waffe, Fähigkeiten und ihre Stufen.

## Schritt 2 · Offene Karten

- **Generator 5** auf Basis von Generator 4: Die Etage ist eine zusammenhängende
  Fläche aus offenen Hallen, verbunden durch breite Durchgänge (mindestens 5
  Tiles), mit Säulen und Mauerresten als Deckung. Es gibt keine Türen; nur die
  Boss-Arena hat ein Tor, das sich beim Betreten schließt.
- Seed-basiert und deterministisch; Tests prüfen Zusammenhang, Mindestbreite der
  Wege, freie Spawns und erreichbare Boss-Arena.
- **Fog of War:** Lichtradius um jeden Helden; aufgedeckte Bereiche bleiben
  gedimmt sichtbar (`balance.fog`).
- **Gegner** schlafen, bis sie einen Helden sehen (Sichtlinie, `balance.aggro`),
  rufen dann ihr Rudel und greifen nicht durch Wände an.
- **Minikarte rechts:** zeigt nur die aufgedeckten Tiles, die eigene Position
  und die Mitspieler. Boss-Arena und Truhen erscheinen erst, wenn sie
  aufgedeckt sind.
- Gegner werden über die Karte verteilt in Gruppen gesetzt; die Gruppe passt zum
  Thema der Etage.

## Schritt 3 · Endlos-Modus mit Themen

- Jede Etage zieht zufällig ein Thema; dasselbe Thema kommt nie zweimal
  hintereinander.
- Das Thema legt fest: Monsterliste, Nebenbosse, Endboss, Bodenfärbung, Banner,
  Deko und Lichtfarbe. Nichts davon wird themenfremd gemischt.
- Themen: Kerker, Gruft, Orklager, Hölle, Himmel (vorhanden), dazu Sumpf
  (`swampy`, `muddy`, `tiny_slug`) und Frost (`ice_zombie`), weil 0x72 dafür
  Monster hat.

## Schritt 4 · Endbosse mit zwei Phasen

Pro Thema ein Endboss, deutlich größer als normale Gegner, im 0x72-Stil
(0x72-Modell mit ergänzten Pixelteilen). Ab 50 % LP wechselt jeder Endboss
sichtbar in Phase 2: Brüllen, kurze Unverwundbarkeit, neue Angriffe, höheres
Tempo. Jede Fähigkeit hat eine Vorwarnung und einen Weg auszuweichen.
Nebenbosse bleiben einphasig.

### Ork-Schamane (Orklager) – zuerst umsetzen

| Kennung | Phase | Name | Was passiert | Ausweichen |
|---|---|---|---|---|
| O1 | 1 | Giftkugeln | Fächer aus 5 Giftkugeln, Gift 2 s | Zwischen die Kugeln |
| O2 | 1 | Heiltotem | Setzt ein Totem, das ihn heilt, bis es zerstört ist | Totem zerschlagen |
| O3 | 1 | Rudelruf | Ruft 3 Goblins | Früh erledigen |
| O4 | 1 | Wurzelfalle | Warnkreis unter einem Spieler, dann 1,5 s festgehalten | Kreis verlassen |
| O5 | 2 | Sprung in die Mitte | Teleportiert in die Arenamitte, 2 s Schild, Brüllen | Abwarten |
| O6 | 2 | Totemkreis | 4 Totems im Kreis drehen Blitzstrahlen um die Mitte | Mit der Drehung laufen, Totems zerstören |
| O7 | 2 | Kettenblitz | Blitz springt zwischen nahen Spielern | Abstand zueinander halten |
| O8 | 2 | Erdstoß-Wellen | Ringe aus Erdstößen in Wellen, jeweils mit Lücke | Durch die Lücke |

### Weitere Endbosse

Gleiches Schema (4 Fähigkeiten pro Phase). Quellen sind der Entwurf
`docs/BOSS-FAEHIGKEITEN.de.md` (Leerenrufer, Moderkoloss, Frostleiche,
Knochenkoloss) und die Bosse aus `codex/0x72-dungeon` (Faulkönig,
Ogerkriegsherr, Höllenprinz, Seraphiel). Zuordnung zu den Themen beim
Umsetzen von Schritt 3 festlegen; jedes Thema bekommt genau einen Endboss.

## Schritt 5 · Skilltree im Menü

- Pro Klasse ein Baum mit etwa 15 Knoten in 3 Ästen, im Hauptmenü verteilbar.
- **Punkte nur aus dem Dungeon:** 1 Punkt pro besiegtem Endboss, 1 Punkt pro 3
  erreichten Etagen im Endlos-Modus. Gespeichert lokal und im Konto
  (`src/online/progress.gd`).
- **Inhalt vor allem Freischaltungen:** alternative Startwaffe, Varianten einer
  Fähigkeit (z. B. Wirbelklinge zieht Gegner an statt sie wegzustoßen),
  zusätzliche Kartenoptionen beim Level-up.
- **Wenige Werte-Boni**, gedeckelt (z. B. +1 Herz insgesamt, +10 % Tempo
  insgesamt), damit der Lauf selbst entscheidend bleibt.
- Zurücksetzen im Menü jederzeit kostenlos.

## Reihenfolge und Nachweis

0 → 1 → 2 → 3 → 4 → 5. Jeder Schritt endet mit grünen Tests und Screenshots
unter `production/qa/evidence/`, die der Nutzer vor dem nächsten Schritt sieht.
