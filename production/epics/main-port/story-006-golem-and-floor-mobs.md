# Story 006: Stein-Golem als Boss und neue Gegner pro Stockwerk

> **Epic**: Dungeon aus Raumvorlagen
> **Status**: In Progress
> **Type**: Feature + Visual/Feel
> **Last Updated**: 2026-10-26

## Context

Wunsch des Projektinhabers vom 26.10.2026: ein mitgeliefertes Sprite-Sheet (Stein-Golem mit Axt, Kristallkern und Gift-Effekten) soll als Boss eines Stockwerks mit seinen Fähigkeiten ins Spiel. Die Animationen sollen gut sein, mit Augenmerk auf Richtungswechsel. Außerdem sollen die Gegner pro Stockwerk anders sein und neue Fähigkeiten haben.

**Umsetzung:**
- Jedes Stockwerk hat seinen Boss und seine Gegnermischung (`balance.json: floors`, rotierend):

  | Stockwerk | Boss | Gegner |
  |---|---|---|
  | 1 | Dämon | Kobold, Ork-Schamane |
  | 2 | Golem | Kobold, Imp, Skelett |
  | 3 | Dämon | Imp, Kobold, Skelett, Nekromant |
  | 4 | Golem | Imp, Nekromant, Skelett, Schamane |

- Der Story-Modus bleibt Stockwerk 1.
- Die Golem-Angriffe, die Fähigkeiten der neuen Gegner und die Bodengefahren liegen in einem eigenen Modul, `src/combat/abilities.gd`. Es nutzt die gemeinsamen Angriffsphasen aus `game.gd`.

## Acceptance Criteria

- [x] **Sheet zerlegt:** `scripts/slice_golem_sheet.py` entfernt den Hintergrund, schneidet die Bilder aus, richtet sie auf Körpermitte und Füße aus und skaliert sie um 1,9. Ergebnis sind 21 Animationen und Effekte samt `manifest.json`.
- [x] **Golem-Angriffe**, jeder mit eigenen Bildern aus dem Sheet:
  - **Axt-Hieb:** Er hebt die Axt (Bilder 0–7) und schlägt durch (8–11) mit einem Ausfallschritt. Getroffen wird, wer im Kegel vor ihm steht, dazu fliegt ein Fächer aus Schnittwellen.
  - **Steinhagel:** 6 Felsbrocken nacheinander, auf den vorausberechneten Ort gezielt.
  - **Bodenbeben:** Drei Risslinien laufen auf den Spieler zu. Jeder Ausbruch warnt 0,35 s vorher.
  - **Bumerang-Axt:** Die Axt fliegt hin und zurück. Während sie unterwegs ist, hat der Golem keine Axt in der Hand, beim Fangen zeigt er die Fang-Pose.
  - **Giftkugel:** Eine Steinkugel fliegt im Bogen auf eine markierte Landestelle, explodiert und verstreut Giftsplitter.
  - **Gift-Spirale:** Drei rotierende Arme aus Giftgeschossen.
  - **Ultimate „Dornen“:** Erstmals unter 60 % Leben, dann alle 5 Angriffe. 4 Wellen Dornen wachsen unter den Spielern und an zufälligen Stellen. 0,75 s Warnzeit reichen, um auszuweichen.
- [x] **Golem-Grundanimationen:** Stehen (5 Bilder), Laufen (7), Tod mit Zerfall in Schutt (9) und Treffer-Blitz.
- [x] **Richtungswechsel:**
  - Bosse drehen sich träge: erst wenn das Ziel deutlich auf der anderen Seite steht (mehr als 24 px) und höchstens alle 0,4 s.
  - Während eines gezielten Angriffs bleibt die Blickrichtung fest.
  - Beim Umdrehen wird der Körper kurz schmal und dann in der neuen Richtung wieder breit (0,1 s, Bosse 0,22 s).
- [x] **Neue Gegner mit Fähigkeiten**, jeweils mit eigenen 0x72-Sprites:
  - **Imp:** duckt sich und zeigt eine rote Sprungbahn, dann springt er auf dich zu.
  - **Skelett:** hält Abstand und wirft einen Fächer aus drei Knochen.
  - **Nekromant:** Ein Beschwörungskreis erscheint, dann ruft er Zombies herbei, höchstens 4.
- [x] **EXP:** eigene Werte pro Art (Golem 120, Imp 6, Skelett 10, Nekromant 15, Zombie 2).

## Test Evidence

Ausgeführt am 26.10.2026:
- `GAME_RULES checked=135 failures=0`, davon 29 neu:
  - Der Golem nutzt alle 6 Angriffe; die Ultimate kommt erst, wenn er verletzt ist.
  - Der Hieb trifft vorn, aber nicht hinten.
  - Das Beben warnt vor dem Schaden und verschont, wer nicht im Riss steht.
  - Die Axt fliegt hin und zurück; die Kugel landet und explodiert.
  - Die Dornen erscheinen unter dem Spieler mit genug Zeit zum Ausweichen.
  - Der Golem dreht sich weder bei knappem Abstand noch mehrmals sofort hintereinander.
  - Imp springt, Skelett wirft drei Knochen, Nekromant beschwört und hält das Limit ein.
- `FEEDBACK checked=28` (inkl. Drehanimation), `PROGRESSION 48`, `ONLINE 20`, `DUNGEON_INTEGRATION 26`, alle ohne Fehler. Der Netzwerklauf im Story-Modus ist bestanden.
- Aufnahme mit Godot Movie Maker: Endlos-Modus ab Stockwerk 2. Der Bot wird dabei am Leben gehalten (nur für die Aufnahme), damit der ganze Kampf aufs Bild kommt. Er besiegt den Golem und spielt danach Räume auf Stockwerk 3. Bilder 01–08 in `production/qa/evidence/story-006-golem-and-floor-mobs/`.

**Offen:**
- Die Balance ist ungetestet: Testbots weichen nicht aus und sterben ohne Hilfe am Golem.
- Das Sheet ist eine generierte Grafik mit weichen Kanten; ein Pixel-Feinschliff wäre möglich.
- Die Nutzungsrechte am Sheet liegen beim Projektinhaber (`assets/sprites/golem/SOURCE-NOTE.md`).
