# Story 009: Goblins und Orks, Boss Grumskar und tiefere Stockwerke

> **Epic**: Dungeon aus Raumvorlagen
> **Status**: In Progress
> **Type**: Feature + Visual/Feel
> **Last Updated**: 2026-10-26

## Context

Wunsch des Projektinhabers vom 26.10.2026:
- Die Orks aus den mitgelieferten Bildern sollen ins Spiel.
- Auf tieferen Stockwerken sollen mehr Monster pro Raum kommen, die vielleicht auch mehr Angriffe können.

Die Bilder zeigen je ein stehendes Bild pro Figur, ohne Animationsreihen. Die Bewegung entsteht über die vorhandene Pose-Schicht: Atmen, Laufhüpfer, Ausholen, Drehung, Treffer und Tod. Das Umgebungs-Sheet (dritte Datei) ist noch nicht verbaut.

## Acceptance Criteria

- [x] **Zuschnitt:** `scripts/slice_orc_sheets.py` schneidet 19 Bilder aus: 17 Kreaturen, den Kriegsherrn und die Bärenfalle. Boden, Raster und Schatten werden entfernt, auch Boden zwischen Arm und Waffe. Jede Figur wird auf ihre Spielgröße skaliert und bekommt eine Kontur. Bild A nutzt von Hand gesetzte Bereiche, weil seine dunklen Rüstungen die automatische Trennung stören.
- [x] **Ork-Kreaturen mit eigenen Fähigkeiten:**

  | Kreatur | Fähigkeit |
  |---|---|
  | Meuchler, Phalanx | Sprungangriff |
  | Speerwerfer | gezielter Speer |
  | Bogenschütze | 3 Pfeile hintereinander |
  | Jäger | 3er-Pfeilfächer |
  | Schildträger, Phalanx, Schwarzritter | **Schild blockt Schüsse von vorn** (Schwerthiebe gehen durch) |
  | Bombenwerfer | Bombe im Bogen, Feuerexplosion |
  | Fallensteller | **Bärenfallen**, die zuschnappen und kurz festhalten |
  | Schamane | **heilt** verletzte Verbündete, sonst eine suchende Kugel |
  | Hauptmann, Häuptling | **Kriegsschrei** macht Verbündete schneller und ruft Verstärkung |
  | Rohling | Bodenstampfer |
  | Kettenschwinger | Flegelwirbel |
  | Knochenrufer | ruft Skelette |
  | Berserker | Ansturm, unter halbem Leben **Raserei** |
  | Schwarzritter | Hieb |
  | Plänkler | schnell, ohne Angriff |

- [x] **Boss GRUMSKAR, DER SCHÄDELKÖNIG:**
  - **Angriffe:** Axt-Hieb mit Schnittwellen, Ansturm, Kriegsschrei (Plänkler und Eile), Bumerang-Axt und Erdrisse in 5 Linien.
  - **Ultimate „Kopfjagd“:** Stachelfelder mit Warnung.
  - Da er keine Bewegungsbilder hat, bekommt er schwere Ausholposen.
- [x] **Endlos-Stockwerke** (5er-Zyklus):
  1. Molgrax
  2. Golem
  3. **Grumskar (Ork-Stockwerk)**
  4. Dämon (gemischt mit Orks)
  5. Golem (Schwarzritter, Berserker, Häuptling …)
- [x] **Tiefe** (`balance.json: depth`):
  - Pro Stockwerk +0,75 Kreaturen je Raum, höchstens 10, und mehr Fernkämpfer.
  - Ab Stockwerk 2 Elite-Kreaturen: 8 % Chance pro Stockwerk, höchstens 45 %. Elite heißt 1,8-fache Lebenspunkte, größer, rote Aura, schnellere Angriffe und nach jedem Angriff zusätzlich ein Ring aus 8 Geschossen.
  - Alle 3 Stockwerke bekommen Fächer-Angriffe einen Schuss mehr.

## Test Evidence

Ausgeführt am 26.10.2026:
- `GAME_RULES checked=220 failures=0`, davon 44 neu:
  - Jede der 16 Ork-Arten setzt ihre Fähigkeit ein.
  - Der Schild blockt von vorn, aber nicht von hinten und nicht gegen das Schwert.
  - Schamane heilt, Kriegsschrei beschleunigt, Falle verletzt und hält fest, Berserker rast.
  - Tiefere Stockwerke haben mehr Kreaturen; die Obergrenze hält.
  - Elite ist zäher und schießt den Zusatzring; tiefe Stockwerke geben Zusatzschüsse.
  - Grumskar nutzt alle 5 Angriffe und steht mit Namen in der Leiste.
- Alle übrigen Testsammlungen sind grün; der Netzwerklauf siehe unten.
- Aufnahmen mit Bot (am Leben gehalten): Ork-Stockwerk, Grumskar-Kampf und Stockwerk 8 mit 9 Kreaturen. Bilder in `production/qa/evidence/story-009-orcs-and-depth/`.

**Offen:**
- Die Balance ist nicht angespielt.
- Die Umgebungsgrafiken (Böden, Säulen, Lava, Portal, Deko) und die vier Dämonen-Varianten aus dem dritten Bild sind noch nicht verbaut.
- Nutzungsrechte: siehe `assets/sprites/orcs/SOURCE-NOTE.md`.
