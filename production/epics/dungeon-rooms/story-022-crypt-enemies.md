# Story022: Verbindlicher Krypta-Stil und drei Untotenrollen

**Status:** Implemented and focused verified; subjective visual/feel feedback pending
**Last Updated:** 2026-10-26
**Type:** Gameplay / Presentation / Integration
**Layer:** Feature
**ADR:** N/A — minimal workflow; existing host authority and feedback retained
**Depends on:** Implemented Story021; further online/load acceptance deferred

Der Nutzer legt den aktuellen Stil als Grundlage fest und beauftragt dazu
Skelettbogenschütze, Nekromant und Skelettkrieger mit kleinem Schild. Alle
sollen dieselbe Pixelästhetik, Wobble-/Trefferreaktion und Animation besitzen.

## Acceptance criteria

- Ruhige32px-Krypta mit klaren Mauerkanten und warmem Feuer bleibt der Standard.
  Die drei neuen Figuren passen zu Konturen, Pixelgröße, Palette und Proportionen
  der bestehenden Figuren; eigene Idle-/Lauf-/Angriffsbilder.
- Bogenschütze kündigt einen gerichteten ausweichbaren Pfeil an, Nekromant
  nutzt Seelenzauber und begrenzte Beschwörungen, Schildkrieger schützt seine
  Vorderseite und besitzt eine lesbare Angriffsvorbereitung/Erholung.
- Trefferblinken, Hitstun, Rückstoß, Wobble, Trefferpartikel, Ton und Tod gelten
  auch für die neuen Rollen. Schildblock hat eigenes sichtbares Feedback.
- Seed-basierte Mischungen im normalen Lauf; Boss ausschließlich in Raum10.
  Beschwörung ist hostgeprüft, räumlich sicher und mengen-/casterbegrenzt.
- Bestehende Perks funktionieren auch mit den neuen Gegnern. Keine Änderung an
  persönlichem Dungeon, Raumgeometrie, Kartenbibliothek oder neue Dekoration.
- Gezielte Verhaltens-/Integrationsprüfungen, tatsächliche GPU-Ansicht der
  drei Gegner und nachvollziehbare Art-Herkunft. Keine neue LAN-/FPS-Freigabe.

## Files

- src/crypt_enemy_ai.gd, src/crypt_enemy_sprites.gd
- src/game.gd, src/dungeon_view.gd, src/vfx/feedback.gd
- src/perk_combat.gd, src/art_reference.gd
- src/data/balance.json, src/session_protocol.gd
- assets/sprites/crypt_enemies/, scripts/import_crypt_enemies.gd
- tests/crypt_enemy_ai_test.gd, tests/crypt_enemy_integration_test.gd
- tests/crypt_enemy_visual_test.gd, tests/crypt_enemy_perk_guard_test.gd
- tests/crypt_enemy_network_peer.gd, tests/crypt_enemy_network_smoke.ps1
- docs/ART-DIRECTION.de.md, docs/CRYPT-ENEMIES.de.md
- assets/sprites/crypt_enemies/source/*_prompt.txt — exact Imagegen prompts
- production/qa/evidence/story-022-crypt-enemies/ — screenshots/animation/results

## Verification and remaining feedback

AI171/0, Gameintegration127/0, Assets/Feedback82/0, Schild-/Perkregression4/0,
bestehende Perks100/0 und Feedback19/0. Spielregeln24/0 und Erkundung85/0.
Zwei echte lokale Prozesse replizieren Rollen, Angriffe/Zielbindung, Block,
Beschwörung und Pfeilstil. Dies ist eine kontrollierte Fixture, keine gespielte
Kampagne oder LAN-/FPS-Abnahme. RED-Nachweise vor Implementierung/Korrekturen
behalten: fehlendes Roster, ungültiger Beschwörungsplatz, Blockfeedback und
falscher Überschussschaden nach Schildreduktion.

36Frames generiert/importiert, harte Alpha und2px-Pixelblöcke validiert.
Alle Fußkanten y46, ursprüngliche Spielfiguren bleiben2×, neue Weltframes1×.
GPU-Rollenvergleich und30animierte Aufnahmen im Originalrenderer bei3×Zoom,
zusätzlich normale Stilwerkstatt. Persönlicher Dungeon bleibt SHA256-identisch.
[Aktuelle Nachweise und Herkunft](../../../docs/CRYPT-ENEMIES.de.md).

Die Art Direction ist die aktuelle verbindliche Grundlage. Die persönliche
Bewertung der neuen Figuren/Animationen und spätere Balance bleiben beim Nutzer.

Run result: OBSERVED — production/qa/evidence/story-022-crypt-enemies/03-enemy-animation.gif
und02-crypt-style-reference.png; bewusste Design-Demonstration, keine Kampagne.
