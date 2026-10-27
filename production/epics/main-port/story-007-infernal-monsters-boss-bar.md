# Story 007: Höllen-Monster, Boss Molgrax und Boss-Leiste

> **Epic**: Dungeon aus Raumvorlagen
> **Status**: In Progress
> **Type**: Feature + Visual/Feel + UI
> **Last Updated**: 2026-10-26

## Context

Wunsch des Projektinhabers vom 26.10.2026:
- Die 8 Monster aus dem mitgelieferten Monster-Sheet sollen als Standardmonster in den Endlos-Modus. Sie nutzen ihre Attacken und sind herausfordernd, aber schwächer als ein Boss.
- Der Boss kommt aus dem zweiten Sheet und bekommt einen passenden Namen.
- Im Bossraum zeigt eine Leiste oben Namen und Leben, statt einer Leiste über dem Kopf.

## Acceptance Criteria

- [x] **Sheets zerlegt:** `scripts/slice_infernal_sheets.py` entfernt den dunklen Hintergrund per Flutfüllung vom Rand aus, sodass Mäuler und Augen erhalten bleiben. Die Bilder werden auf die Füße ausgerichtet, scharf skaliert und bekommen eine 1-px-Kontur. Ergebnis sind 8 Monster mit Stehen, Angriff, Treffer, Tod und Effekten sowie Molgrax mit 12 Animationen.
- [x] **Monster und ihre Fähigkeiten** (`balance.json: mobs`, `attacks`):

  | Monster | Fähigkeit |
  |---|---|
  | Glutling | spuckt Feuerbälle; hinterlässt beim Tod ein Feuerfeld (mit Warnung) |
  | Schattling | langsame Leerenkugel, die dem Spieler folgt |
  | Funkenball | schnell; Feuerstoß aus 4 Kugeln |
  | Blutqualle | Blutsäule unter dem Spieler (0,7 s Warnung) |
  | Stachelwächter | Tank; Bodenstampfer mit Trümmerring |
  | Leerenpriester | Doppel-Leerenbolzen plus Leerenkreis unter dem Spieler |
  | Krabbenteufel | Ausfall-Sprung, danach eine Stachelreihe |
  | Fackelteufel | gezielter Feuerball plus Glutring |

  Jedes Monster hat höchstens ein Viertel der Lebenspunkte des Bosses (12–28 statt 230).
- [x] **Endlos-Stockwerke** (rotierend):

  | Stockwerk | Boss | Monster |
  |---|---|---|
  | 1 | Molgrax | Glutling, Krabbenteufel, Schattling, Funkenball |
  | 2 | Golem | Glutling, Stachelwächter, Imp, Blutqualle, Skelett, Fackelteufel |
  | 3 | Dämon | Krabbenteufel, Stachelwächter, Glutling, Leerenpriester, Fackelteufel, Nekromant |
  | 4 | Molgrax | Mischung aus allen |

  Der Story-Modus behält Kobolde, Schamanen und den Dämon.
- [x] **Molgrax, der Glutschlund**, jeder Angriff mit eigenen Bildern aus dem Sheet:
  - **Feuerkralle:** Kegel-Treffer plus Flammenfächer.
  - **Feuerbälle:** 3 große, vorausgezielte Feuerbälle.
  - **Bodenschlag:** Schaden im Umkreis plus Trümmerring.
  - **Lava-Eruption:** 3 Ringe, die nacheinander mit Warnung ausbrechen.
  - **Leeren-Ritual:** beschwört Schattlinge und lässt Leerensäulen unter den Spielern aufsteigen.
  - **Ultimate „Inferno“:** Zorn-Aura und 4 Wellen Flammensäulen, danach taumelt er erschöpft.
  - **Grundanimationen:** Laufen (10 Bilder), Stehen (5), Tod (9).
- [x] **Bossnamen:**
  - AZGAROTH, FÜRST DER TIEFE (Dämon)
  - KORRUM, DER GRANITWÄCHTER (Golem)
  - MOLGRAX, DER GLUTSCHLUND
- [x] **Boss-Leiste** oben über dem Raum, mit Namen und roter Leiste. Ein heller Rest zeigt den gerade verlorenen Schaden und sinkt verzögert nach, bei Treffern wackelt die Leiste. Die Leiste über dem Kopf des Bosses entfällt.

## Test Evidence

Ausgeführt am 26.10.2026:
- `GAME_RULES checked=176 failures=0`, darin:
  - Jedes der 8 Monster greift an und ist deutlich schwächer als der Boss.
  - Der Glutling hinterlässt beim Tod ein Feuerfeld.
  - Die Boss-Leiste zeigt Namen und volles Leben, sinkt bei Schaden und fehlt ohne Boss.
  - Molgrax nutzt alle 5 Angriffe.
  - Die Story-Aufstellung bleibt unverändert.
- Alle übrigen Testsammlungen sind grün.
- Aufnahme eines Endlos-Laufs mit Bot (für die Aufnahme am Leben gehalten). Der Bot räumt Stockwerk 1, besiegt Molgrax und erreicht Stockwerk 3. Bilder 01–04 in `production/qa/evidence/story-007-infernal-monsters-boss-bar/`.

**Offen:**
- Die Balance ist nicht angespielt.
- Die Sheets sind generierte Grafiken; die Nutzungsrechte liegen beim Projektinhaber (`assets/sprites/infernal/SOURCE-NOTE.md`).
