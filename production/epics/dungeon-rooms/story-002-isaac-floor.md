# Story 002: Isaac-Stockwerk mit Türen, Schatzraum und Minimap

> **Epic**: Dungeon aus Raumvorlagen
> **Status**: In Progress
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: L
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-10-25

## Context

**GDD**: `design/game-brief.md`
**Requirement**: Brief MVP feature 3 — Zufällig zusammengesetzter Dungeon aus Raumvorlagen, erweitert um das Stockwerk-Modell von The Binding of Isaac
**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)
**Engine**: Godot 4.7.2 | **Risk**: HIGH (4.7 timeline rating in `docs/engine-reference/godot/VERSION.md`)
**Engine Notes**: none (no ADR engine-compatibility analysis at minimal)
**Control Manifest Rules**: N/A (minimal — no control manifest)

Story 001 erzeugt eine feste Kette aus drei Räumen, und die Gruppe wird nach
jeder Perk-Wahl automatisch weitergeschickt. Der Projektinhaber hat am
25.10.2026 das Isaac-Modell festgelegt (übernommen aus der Unity-Linie, dort
Story 003): Wie viele Räume vor dem Boss geräumt werden müssen, hängt vom Weg
ab und ändert sich mit jedem Lauf.

Entscheidungen vom 25.10.2026:
- 6–10 Räume pro Stockwerk, aus dem Lauf-Seed.
- Wer durch eine offene Tür geht, nimmt die ganze Gruppe mit (kein getrenntes Erkunden).
- Perks gibt es im Schatzraum und nach dem Boss, nicht nach jedem Raum.

## Acceptance Criteria

- [x] Die Raumanzahl liegt pro Lauf zufällig zwischen 6 und 10 (einstellbar) und folgt aus dem Seed; gleicher Seed, Generatorversion und Daten ergeben dieselbe Karte.
- [x] Die Karte ist ein verzweigter, schleifenfreier Raster-Baum; jeder Raum ist vom Start erreichbar, Nachbarschaften sind beidseitig und haben Türen in bis zu vier Richtungen.
- [x] Es gibt genau einen Startraum ohne Gegner, einen Schatzraum und einen Bossraum; Schatz- und Bossraum sind Sackgassen, der Bossraum ist die vom Start am weitesten entfernte Sackgasse.
- [x] Türen sind geschlossen, solange im Raum Gegner leben; geräumte Räume können wieder betreten werden und erzeugen keine Gegner neu.
- [x] Läuft ein lebender Spieler durch eine offene Tür, wechselt die ganze Gruppe in den Nachbarraum und erscheint an der gegenüberliegenden Tür.
- [x] Perks werden im Schatzraum und nach dem Boss je Spieler persönlich gewählt; nach dem Boss-Perk und gemeinsamem Bereit ist der Lauf gewonnen.
- [x] Eine Minimap zeigt besuchte und angrenzende Räume; Boss- und Schatzraum sind markiert, sobald sie sichtbar sind.
- [x] Bestehende Spielregeln, Vierer-Lobby und der Zwei-Prozess-Netzwerktest laufen weiter; der Netzwerktest findet den Weg zum Boss selbst.
- [x] Bildbeleg einer Tür, der Minimap und des Schatzraums aus dem echten Spiel in `production/qa/evidence/`.

## Implementation Notes

- Generatorversion 2: Baum-Wachstum auf dem Raster (neue Zelle nur mit genau einem belegten Nachbarn), Bossraum per Breitensuche als entferntestes Blatt, Schatzraum als weiteres Blatt.
- Türen liegen mittig auf den Wänden; Vorlagen müssen die Türzugänge frei halten (Validierung).
- Der Host bleibt Autorität: Türwechsel, Raumzustand und Minimap-Sichtbarkeit kommen aus dem Snapshot.

## Out of Scope

- 0x72-Grafik (Folgeschritt), weitere Stockwerke, Shops, Geheimräume, Schlüssel und Bomben.
- Getrenntes Erkunden einzelner Spieler.

## Files

- `src/dungeon/dungeon_generator.gd` (Generatorversion 2: Baum, Raumarten, Türen, Eintrittspunkte, Validierung der Türzugänge)
- `src/game.gd` (Phase „explore“, Türwechsel, Raumzustände, Perks nur in Schatz- und Bossraum, Minimap-Sichtbarkeit, Testspieler-Navigation)
- `src/dungeon_view.gd` (Türen offen/vergittert, Rahmenfarbe nach Nachbarraum)
- `src/dungeon/dungeon_map.gd` (2D-Minimap)
- `src/data/balance.json`, `assets/data/dungeon_rooms.json` (Raumanzahl 6–10, 3–5 Gegner, Generatorversion 2, Säule der Galerie aus der Nordtür verschoben)
- `tests/dungeon_generator_test.gd`, `tests/dungeon_integration_test.gd`, `tests/game_rules.gd`, `tests/dungeon_network_smoke.ps1`
- `production/qa/evidence/story-002-isaac-floor/01–05`

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above.*

## Test Evidence

**Story Type**: Integration
**Required evidence**: Generator-, Integrations- und Spielregeltests sowie der Zwei-Prozess-Netzwerktest; Bildbeleg aus dem echten Spiel.

Ausgeführt am 25.10.2026 (Godot 4.7.2, lokal):
- `DUNGEON_GENERATOR checked=9508 failures=0` (48 Seeds, alle Raumzahlen 6–10, Baum, Türsymmetrie, Boss als entfernteste Sackgasse, begehbare Türzugänge).
- `DUNGEON_INTEGRATION checked=26 failures=0`, `GAME_RULES checked=32 failures=0`, `Dev.ps1 Check` ohne Fehler.
- Zwei echte Prozesse: Seed 24680 (7 Räume, 3 Türwechsel, 3 Kampfräume inkl. Boss) und Seed 84329 (10 Räume, 8 Türwechsel, 6 Kampfräume inkl. Boss); identische Layouts, Sieg auf beiden Seiten, Exitcodes 0.
- Vierer-Lobby (`network_smoke.ps1 -Players 4`) weiterhin PASS.
- Echtes Spielfenster, Seed 10004: Start mit offenen Türen und Minimap, Schatzkammer, vergitterte Türen mit rotem Bossrahmen, Bosskampf, Sieg — `production/qa/evidence/story-002-isaac-floor/01–05`.
- Beim Durchspielen gefunden und behoben: Der Türauslöser (±32 px) war schmaler als die gezeichnete Öffnung (80 px); ein sichtbar in der Tür stehender Spieler ging nicht hindurch. Jetzt ±40 px.

**Status**: [x] Vorhanden und ausgeführt; lokaler Funktionsnachweis, kein LAN-/Leistungsnachweis.

## Dependencies

- Depends on: `production/epics/dungeon-rooms/story-001-seeded-rooms.md` (Done)
- Unlocks: 0x72-Grafik, weitere Stockwerke
