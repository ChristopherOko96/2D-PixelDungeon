# Story 004: Eigene Räume im Dungeon-Baukasten gestalten

> **Epic**: Dungeon aus Raumvorlagen
> **Status**: Done
> **Layer**: Authoring / Integration
> **Type**: Tool
> **Estimate**: M
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-10-25

## Context

**GDD**: `design/game-brief.md`, Nutzerwunsch nach eigener Dungeon-Gestaltung
**Requirement**: Ohne Programmierarbeit Räume bauen und im bestehenden Spiel nutzen;
eine Schritt-für-Schritt-Anleitung bereitstellen.
**ADR Governing Implementation**: N/A (minimal — no ADRs)
**Engine**: Godot4.7.2

Der Nutzer möchte die Gestaltung selbst übernehmen können. Die bestehende
Geometrieprüfung und der vorhandene Renderer bilden die Grundlage. Der Baukasten
verändert keine laufende Mehrspielersitzung; Übernehmen wirkt beim Neustart.

## Acceptance Criteria

- [x] Eigenständige F6-Szene und Windows-Starter; deutscher Ablauf dokumentiert.
- [x] Wände/Boden auf dem16×16-Raster mit kontinuierlichen Pinselstrichen und
  zusammengefasster Geometrie, Undo/Redo, neue/duplizierte/löschbare Räume.
- [x] Vier Spieler- und fünf Gegnerstartplätze, gekoppelte Türspuren,
  Boss-Innentreppe, Feuer und Belohnungsdarstellung platzierbar.
- [x] Vier Originalpaletten pro Raum wählbar; Zufall bleibt als Standard möglich.
- [x] Bibliothek zufällig verwendbar oder als bewusste Drei-Raum-Folge.
- [x] Entwürfe separat speichern und laden; fehlerhaftes JSON lässt den Entwurf
  unberührt. Unfertige Geometrie darf gespeichert, aber nicht übernommen werden.
- [x] Vor Ersetzen einer Datei wird eine Sicherung erstellt. Save As darf die
  Validierung der aktiven Spieldatei nicht umgehen.
- [x] Ausgewählten Raum mit echter Hostsimulation lokal testen und zum Entwurf
  zurückkehren, ohne aktive Projektdaten zu veröffentlichen.
- [x] Import, Autorentests, Datei-/Spielintegration, bestehende Regeln und
  Vier-Prozess-Regression bestanden; Oberfläche und Testlauf visuell geprüft.

## Implementation Notes

`dungeon_editor_model.gd` hält Zustände und Undo-Transaktionen ohne Dateizugriffe.
`dungeon_editor_store.gd` begrenzt geladene Daten, schreibt eine temporäre Datei
und sichert den vorherigen Inhalt vor dem Ersetzen. `dungeon_editor.gd` verbindet
Werkzeuge, Vorschau, Prüfung und isolierten Solo-Raumtest.

Generator3 ergänzt optionale `room_order`, `door_lanes`, `theme`, `reward_spawn`,
`brazier_spawns` und `stairs_spawn`. Der Renderer und die Hostkollision verwenden
die erzeugten Layoutdaten. Ohne optionale Felder bleibt der vorhandene Inhalt.
Native16-Entwürfe der Generatorversion2 werden beim Laden migriert.

## Out of Scope

Beliebige Außenkonturen, verzweigte freie Weltkarten, Tileset-Import,
eigene Fallen-/Gegnerregeln, Live-Änderungen laufender Sitzungen und Exportbuilds.
Der aktuelle Außenrahmen448×240 und die Drei-Raum-Ebene bleiben bestehen.
Artstyle-Freigabe und vollständige Charakteranimationssätze bleiben offen.

## Test Evidence

- `DUNGEON_AUTHORING checked=18 failures=0`.
- `DUNGEON_EDITOR_INTEGRATION checked=25 failures=0`: echte temporäre Dateien,
  Backups, Save/Load, abgewiesenes JSON, abgewiesene Übernahme, geschützter
  aktiver Pfad, Pinsel/Undo/Redo, Nordtür-Halbzeile, Feuer/Truhe/Bosstreppe,
  Hostlayout aus gespeicherten Daten und Rückkehr vom Loopback-Solotest.
- Vor Umsetzung: fehlendes Modell rot. Nordtür-Regression rot18/1, danach18/0.
  Save-As-Regressionsfall rot23/1, nach Pfadschutz23/0; anschließend erweitert25/0.
- Bestehende Suiten: Generator4146/0, Ports1585/0, Spielregeln22/0,
  Dungeon-Integration23/0 und Erkundung51/0.
- `Dev.ps1 Check`:13 Spielskripte importiert und geladen.
- Vier echte Prozesse, Generator3, zwei Ebenen, sechs gleiche Layouts,
  24 persönliche Perks und freie Erkundung: PASS, Lauf
  `20261025-204655-4300ddc6`. Der vorherige Lauf zeigte einen Zeitfehler im
  Testabbau später gestarteter Clients; Laufzeiten werden nun relativ zum
  tatsächlichen Startfortschritt berechnet. Spielregeln dafür nicht verändert.
- OpenGL-Aufnahmen von Baukasten und tatsächlichem Testlauf mit gemalter Wand
  und gewählter Amber-Palette angesehen. Projektdaten dabei nicht übernommen.

## Dependencies

- Depends on: Story002 (native16/Erkundung), Story003 (wiederverwendete Darstellung).
- Guide: `docs/DUNGEON-EDITOR.de.md`; Daten: `docs/DUNGEON.de.md`.
- Details und Bilder: `production/qa/verification.md`.
