# Story021:48 unterschiedliche Perks und kombinierbare Builds

**Status:** Implemented and focused verified; manual balance feedback pending
**Last Updated:** 2026-10-26
**Type:** Gameplay / Integration / UI
**Layer:** Feature
**ADR:** N/A — minimal workflow; host authority retained
**Depends on:** Implemented Story019/020 code; hardware LAN acceptance deferred by user

Der Nutzer priorisiert Core-Design vor weiteren Online-/LAN-/Lasttests und
beauftragt eine große Auswahl eigener Perks mit kombinierbaren Wirkungen im
Sinne von Brotato/Isaac/Vampire Survivors. Keine Übernahme fremder Kataloge.
Tier: workflow minimal. Bestehende ruhige32px-Grafik und zehn Karten bleiben.

## Acceptance criteria

-48 eigene stabile Definitionen mit unterschiedlichem Nutzen, Beschreibung,
  Seltenheit, Tags und Stapelgrenzen; alle Effekte an reale Hostsimulation gebunden.
- Projektilmuster, Flugbahnen, Durchschlag/Abpraller, Status- und Folgewirkungen,
  bedingter Schaden, Heilung/Schutz und Risiko-Builds kombinieren sich.
- Drei persönliche geeignete Angebote, keine Dopplungen/maximalen Stapel oder
  reine Voll-LP-Heilung. Synergien werden begünstigt, nicht erzwungen. Der
  ausgeschöpfte Pool hat einen wirksamen begrenzten Fallback.
- Host bestätigt eigene Angebote genau einmal; ungültige/fremde Aktionen
  bewirken keine Grants. Neue Läufe löschen Builds, Ebenenwechsel bewahren sie.
- Lesbare transparente Karten,48 unterscheidbare Pixelicons und gruppiertes
  scrollbares Inventar. Sichtbarer GPU-Nachweis; Tests prüfen konkrete Effekte
  und Kombinationen, keine durch Test-Cheats als gespielt bezeichnete Kampagne.
- Geschoss-/Proc-/Status-Grenzen und Gegnerreserve verhindern unbeschränkte
  Ketten und unterdrückte Bossangriffe. Keine neue LAN-/FPS-Abnahme behaupten.

## Files

- src/perk_rules.gd, src/perk_combat.gd, src/data/balance.json
- src/game.gd, src/session_protocol.gd, src/dungeon_view.gd
- src/reward_overlay.gd, src/pause_menu.gd, src/perk_icons.gd
- tests/perk_rules_test.gd, tests/perk_combat_test.gd, tests/perk_ui_test.gd
- tests/perk_network_peer.gd, tests/perk_network_smoke.ps1
- docs/PERKS.de.md

## Verification

667 Regel-/Katalogprüfungen,100 tatsächliche Kampfprüfungen aller48 IDs und
ausgewählter Kombinationen,159 UI-Prüfungen ohne Fehler. Alte Spielregeln24/0,
Erkundung85/0, Interpolation53/0 und Protokoll20/0. Zwei echte lokale Prozesse
bestätigen persönliche Angebote/Wahl/Inventare. Kontrollierte Test-Fixtures
werden nicht als gespielte Kampagne ausgegeben. RED-Nachweise vor Änderungen
vorhanden, einschließlich Heavy-Schaden und verlorener Seelenpanzerladung.

Die sichtbare GPU-Ansicht zeigt tatsächliche Spielcontrols/Icons und simulierte
Geschosse/Statusanzeigen in einem ausdrücklich eingerichteten Prüfzustand.
Keine neue vollständige Kampagnen-/Leistungs-/LAN-Abnahme. Der persönliche
Dungeon ist per SHA256 unverändert. Ergebnisse und Bilder: docs/PERKS.de.md.

Run result: OBSERVED — production/qa/evidence/story-021-perk-builds/01-element-cards.png,
02-combination-cards.png,03-grouped-inventory.png,04-combined-projectiles.png.
