# Story 002: Native 16-Pixel-Grafik und freie Dungeon-Erkundung

> **Epic**: Dungeon aus Raumvorlagen
> **Status**: Done
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: L
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-10-25

## Context

**GDD**: `design/game-brief.md`, verbindliche Fortschreibung vom 25.10.2026
**Requirement**: Brief MVP feature 3 und direkte Nutzerergänzung: Original-Tilesets,
16×16 statt 32×32, räumliche Wände, passende Türen, freies Laufen nach Abschluss,
Abstieg in die nächste Ebene, HP und Hitstun, Original-UI/Feuer/Itemgrafiken.
**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)
**Engine**: Godot 4.7.2 | **Risk**: HIGH (4.7 timeline rating)
**Engine Notes**: source references and actual installed-engine checks
**Control Manifest Rules**: N/A (minimal — no control manifest)

## Acceptance Criteria

- [x] Raster und acht Basissprites sind nativ 16×16; vier gelieferte Dungeon-
  Atlanten bleiben unverändert und werden in passende semantische Regionen zerlegt.
- [x] Wandoberkanten, senkrechte Flächen, Ecken und Schatten vermitteln die
  verlangte räumliche Draufsicht. Seitliche Türen zeigen keine Treppengrafik.
- [x] Raumtüren folgen der generierten Route und haben passende Gegentüren sowie
  vier freie Ankunftsplätze. Der Bossraum besitzt einen eigenen Innenabstieg.
- [x] Kampfabschluss und Perk-Ready teleportieren niemanden. Bewegung bleibt
  erlaubt; erst E am Ausgang mit allen lebenden Teilnehmern in der Nähe wechselt.
- [x] Gesäuberte Räume bleiben besuchbar, ohne Gegner-/Perk-/Revive-Farming.
- [x] Nach dem Boss bleibt die Ebene begehbar. Treppennutzung erzeugt eine neue
  Ebene mit frischen IDs und erhält den Build.
- [x] HP-Herzen, Raumfortschrittsbalken, Feuer, Effekte und Perkicons verwenden die
  gelieferten Sheets. Treffer verursachen kurz Hitstun/Rückstoß; Boss-Cooldown
  verhindert dauernde Unterdrückung seiner Angriffe.
- [x] Zwei und vier getrennte Spielprozesse durchlaufen zwei Ebenen mit gleichen
  Raumkennungen und Prüfsummen, persönlichen Perks und fehlerfreiem Abbau.

## Implementation Notes

Host-Autorität, vorhandene Maximalzahl vier und bestehende Sender-/Phasenprüfung
bleiben die Grundlage. `explore` ergänzt den Ablauf nach `reward`; nur der Host
prüft Exitnähe und die lebende Gruppe. Native Geometrie ist 448×240, Anzeigezoom
2×. Generatorversion 2 trägt Themes, gegenseitige Türen und Ankunftsslots.
Schema und Zahlen: `docs/DUNGEON.de.md`, `docs/EXPLORATION.de.md`.

## Out of Scope

WAN/Relay, Netzwerk-Kompatibilität verschiedener Spielversionen, Speichern,
Inventar mit weiteren Itemfunktionen, Shops, frei verzweigte Dungeon-Graphen,
weitere Gegner und Leistungszusagen.

## Files

- `src/game.gd`, `src/data/balance.json`
- `src/dungeon/dungeon_generator.gd`, `assets/data/dungeon_rooms.json`
- `src/dungeon_view.gd`, `src/dungeon_tiles.gd`, `src/dungeon_hud.gd`, `src/item_art.gd`
- `assets/tilesets/`, `assets/ui/`, `assets/items/`, `assets/sprites/`
- `scripts/generate_pixel_assets.gd`
- `tests/game_rules.gd`, `tests/dungeon_generator_test.gd`, `tests/dungeon_ports_test.gd`,
  `tests/dungeon_integration_test.gd`, `tests/exploration_rules_test.gd`,
  `tests/dungeon_network_smoke.ps1`
- Dokumentation, zugehörige erzeugte UIDs und finale Bildbelege

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above.*

## Test Evidence

Neue Erkundungsprüfung wurde gegen den alten Stand rot beobachtet (6/3).
Port-Test zeigte vor Umsetzung 25 Fehler; die bereits migrierte 16-Pixel-Suite
scheiterte vor der Radiuskorrektur mit 14 Fehlern. Danach bestehen alle fünf
Godot-Suiten. Echte Bot-Eingaben schließen zwei Ebenen ab: 2 Peers/12 Perks,
4 Peers/24 Perks, jeweils sechs identische Layouts und abschließend `explore`.
Alle Prozesse Exit0, keine Godot-Fehler. Genaue Läufe und finale Sichtprüfung:
`production/qa/verification.md`.

Die erste grafische Fassung wurde nach Nutzerkritik überarbeitet: fälschlich
als Mauerecken verwendete Treppenregionen entfernt, echte Backsteinflächen
und Oberkanten zugeordnet, hohe Nordwand und Frontwand ergänzt, Säulen mit
Dachplatte/Frontfläche/Schatten projiziert und mit Figuren nach Tiefe sortiert.
Echte Hauptspielaufnahme der korrigierten Fassung visuell geprüft.

## Dependencies

- Depends on: `production/epics/dungeon-rooms/story-001-seeded-rooms.md`
- Unlocks: weitere Raumformen, manuelles Spielgefühl und LAN-/Latenzabnahme.
