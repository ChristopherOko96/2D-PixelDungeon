# Story 003: Getrennte Artstyle-Referenz und gemeinsame Herzgrafik

> **Epic**: Dungeon aus Raumvorlagen
> **Status**: Done
> **Layer**: Presentation
> **Type**: UI
> **Estimate**: M
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-10-25

## Context

**GDD**: `design/game-brief.md`, Nutzerfeedback zu Raum, Figuren/Animationen und HUD
**Requirement**: Online-Referenzen Brotato/Binding of Isaac recherchieren;
Artbereiche getrennt darstellen; Herzen zu einer Grafik zusammenfassen.
**ADR Governing Implementation**: N/A (minimal — no ADRs)
**Engine**: Godot4.7.2 | **Risk**: HIGH (lokale4.7-Versionsreferenz)

Der Vier-Spieler-Prototyp funktioniert, seine Gestaltung ist weiterhin in
Abstimmung. Eine feste Referenzkomposition ermöglicht konkrete Vergleiche
vor weiteren zufälligen Inhalten. Der Nutzer präzisierte Bravetail zu Brotato.

## Acceptance Criteria

- [x] Offizielle Referenzseiten und unsere Ableitungen sind verlinkt dokumentiert.
- [x] Eine feste Szene ist im Editor sichtbar und über F6 als Designvorschau startbar.
- [x] Raum, Figuren/Effekte und HUD sind getrennt sowie als Gesamtbild betrachtbar.
- [x] Volle/halbe/leere Herzen werden in einem transparenten Bild zusammengesetzt;
  auch das Live-HUD verwendet diese gemeinsame Grafik.
- [x] Farben, Höhen und Umgebungsschatten sind in einem eigenen Profil einstellbar;
  vorhandene Renderfunktionen werden wiederverwendet.
- [x] Änderungen am Profil aktualisieren die Vorschau, ohne Kollisionsrechtecke
  oder die Hostsimulation zu verändern.
- [x] Alle Ansichten visuell geprüft, Szene im Editor geladen, zehn Spielskripte
  erfolgreich importiert/geparst; bestehende Spiel-/Erkundungsregeln bestehen.

## Implementation Notes

Quelle/Bedienung/Profileinheiten: `docs/ART-DIRECTION.de.md`.
Die Vorschau löst keine Netzwerkverbindung aus und ist ausdrücklich als
Designvorschau beschriftet. Neues Renderprofil mit Standardwerten erhält die
bisherige Darstellung. Die Herzzeile wird nur bei Zustandsänderung neu erzeugt.

## Out of Scope

Ein endgültig freigegebener Gesamt-Artstyle, neue vollständige Charakterlaufzyklen,
zusätzliche Spielmechaniken und eine neue Netzwerkabnahme sind nicht Teil dieses
Werkstatt-Schritts. Die Freigabe einer künftigen Stiländerung wird nicht vorgetäuscht.

## Files

`src/art_reference.tscn`, `src/art_reference.gd`, `src/art_style_profile.gd`,
`assets/data/art_style_reference.tres`, `src/health_strip.gd`,
`src/dungeon_hud.gd`, `src/dungeon_view.gd`, `src/dungeon_tiles.gd`,
`src/item_art.gd`, erzeugte UIDs, Dokumentation und Bildbelege.

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above.*

## Test Evidence

`ART_REFERENCE layers=4 single_health_image=true profile_refresh=true geometry_unchanged=true`,
CaptureExit0. Headless-Editorstart mit Referenzszene Exit0. Alle vier OpenGL-
Ansichten sowie volle/teilweise/leere HP-Bilder angesehen. Tatsächlicher
Spielstart mit neuem HUD ohne Fehler; `GAME_RULES22/0`, `EXPLORATION_RULES51/0`.
Details: `production/qa/verification.md`.

## Dependencies

- Depends on: `story-002-native16-exploration.md`
- Unlocks: gezielte Stilabstimmung, weitere Raumvorlagen und Charakteranimationen.
