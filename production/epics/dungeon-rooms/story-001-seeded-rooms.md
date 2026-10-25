# Story 001: Seed-basierte Räume, Geometrie und Raumkarte

> **Epic**: Dungeon aus Raumvorlagen
> **Status**: Done
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: M
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-10-25

## Context

**GDD**: `design/game-brief.md`
**Requirement**: Brief MVP feature 3 — Zufällig zusammengesetzter Dungeon aus Raumvorlagen
**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)
**Engine**: Godot 4.7.2 | **Risk**: HIGH (4.7 timeline rating in `docs/engine-reference/godot/VERSION.md`)
**Engine Notes**: none (no ADR engine-compatibility analysis at minimal)
**Control Manifest Rules**: N/A (minimal — no control manifest)

Der bestehende Prototyp konnte drei Kämpfe mit Perks und Boss abschließen,
zeichnete dafür aber immer dieselbe Arena. Der nächste fehlende Baustein der
Baufolge ist deshalb der Raumgenerator. Aktuelles Ziel bleibt ein gemeinsamer
kurzer Lauf für höchstens vier Gesamtspieler, kein weiteres Stockwerk.

## Acceptance Criteria

- [x] Gleicher Seed, Generatorversion und Daten erzeugen dieselbe verbundene Route mit eindeutigen IDs; andere Seeds bieten Variation.
- [x] Mindestens drei normale Vorlagen und eine Bossvorlage existieren im 32-Pixel-Raster; der aktuelle Lauf wählt zwei normale Räume und den Boss.
- [x] Vier Spielerspawns und alle Gegnerspawns sind frei und erreichbar; ungültige Daten starten keinen Lauf.
- [x] Spieler und Gegner bewegen sich nicht durch Säulen; Gegner umgehen Deckung.
- [x] Eigene und feindliche Projektile stoppen auch bei großen Zeitschritten an Deckung.
- [x] Host und unabhängiger Client erhalten in allen drei Räumen identische IDs, Vorlagen, Versionen und Layout-Prüfsummen und erreichen den Boss-Sieg mit persönlichen Perks.
- [x] Eine Raumkarte zeigt aktuelle, abgeschlossene und kommende Räume einschließlich Boss; bestehende 32×32-Sprites und vier Spielerfarben bleiben erhalten.
- [x] Vorhandene Spielregeln sowie Vierer-Verbindung und sauberer Abbau bestehen weiter.

## Implementation Notes

`src/dungeon/dungeon_generator.gd` erzeugt die Route, validiert Daten und bietet
gemeinsame Geometrie-/Wegsuchefunktionen. Der Host integriert diese in Bewegung,
Schüsse, Spawns und Snapshots. Clients zeichnen die übertragenen Daten.
Schema, Zahlen, Versionsregeln und Grenzen: `docs/DUNGEON.de.md`.

## Out of Scope

- Frei wählbare Abzweigungen, zusätzliche Stockwerke, Shops oder Spezialräume.
- Animationen, neue Perk-Kombinationen, WAN/Relay, Interpolation und Leistungsgarantien.
- Ein vollständiges Protokoll für den Beitritt mit unterschiedlichen Inhaltsversionen.

## Files

- `src/dungeon/dungeon_generator.gd`, `src/dungeon/dungeon_map.gd` und erzeugte UIDs
- `assets/data/dungeon_rooms.json`
- `src/game.gd`, `src/dungeon_view.gd`
- `tests/dungeon_generator_test.gd`, `tests/dungeon_integration_test.gd` und erzeugte UIDs
- `tests/dungeon_network_smoke.ps1`
- `production/qa/evidence/godot-seeded-dungeon.png`
- `docs/DUNGEON.de.md`, bestehender Entwicklungsplan, Spielbrief und Prüfbericht

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above.*

## Test Evidence

- Vor Implementierung beobachtet: Generator-Test rot bei fehlender Implementierung;
  Integrationsprüfung `checked=3 failures=2` gegen den bisherigen Spielstand.
- Danach: `DUNGEON_GENERATOR checked=4146 failures=0`,
  `DUNGEON_INTEGRATION checked=22 failures=0`, `GAME_RULES checked=21 failures=0`.
- `Dev.ps1 Check`: Import und Laden aller vier Spielskripte erfolgreich.
- Zwei echte Prozesse: Seed 24680, drei identische Layouts, drei Kämpfe,
  sechs persönliche Perks, Boss und Sieg auf beiden Seiten; Exitcodes 0.
- Vierer-Lobby mit gleichzeitigem Trennen weiterhin erfolgreich, keine Godot-Fehler.
- Echte Hauptspielaufnahme visuell geprüft: `production/qa/evidence/godot-seeded-dungeon.png`.
- Konkrete Logläufe und Grenzen: `production/qa/verification.md`, Abschnitt Raumgenerator.

**Status**: [x] Vorhanden und ausgeführt; lokaler Funktionsnachweis, kein LAN-/Leistungsnachweis.

## Dependencies

- Depends on: None — auf vorhandenem Godot-/ENet-Prototyp `44c9b80` aufgebaut.
- Unlocks: Vier-Spieler-Kampf, Abbruchfälle im Übergang und spätere LAN-Abnahme.
