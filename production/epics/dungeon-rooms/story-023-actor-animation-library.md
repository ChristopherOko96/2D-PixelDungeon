# Story023: Acht Figuren mit jeweils48 Animationsabläufen

**Status:** Implemented and focused verified; user animation/feel feedback pending
**Last Updated:** 2026-10-27
**Type:** Visual / Feel / UI / Integration
**Layer:** Feature
**ADR:** N/A — minimal workflow; offline art baking and existing host authority
**Depends on:** Story022 implemented; visual revision explicitly requested

Der Nutzer meint ausdrücklich mindestens40 eigenständige Abläufe pro Figur,
nicht40 Einzelbilder. Vier Spieler sollen wie die Kryptagegner mit Imagegen
im bestehenden Stil entstehen. Richtungen zählen nicht als eigene Aktionen.

## Acceptance criteria

- Vier neue Spieler, drei Kryptagegner und bestehende Bossidentität: je48
  unterschiedliche Abläufe, vier echte Ansichten und mindestens sechs Bilder
  je gerichtetem Ablauf. Quelldateien, Prompts und Importer bleiben erhalten.
- Körperteile und Waffen bewegen sich sichtbar; unabhängige Aktionen haben
  eigene Posen/Kurven statt nur anderer Geschwindigkeit oder Markierungspixel.
  Gemeinsames Bewegungspadding verhindert abgeschnittene Waffen/Gliedmaßen.
- Bestehendes Gameplay steuert passende Animationen über Hostdaten. Perks,
  vier Spieler und Raum10-Boss bleiben erhalten. Neue Clips führen keine
  unbestellten Klassen-/Sprint-/Ausweichmechaniken ein.
- Animationswerkstatt bietet alle acht Figuren,48 Aktionen, vier Richtungen,
  Wiedergabe, Tempo, Zoom und einzelne Bilder; ungebundene Aktionen sind
  ausdrücklich als vorbereitet gekennzeichnet.
- Nearest,2-Weltpixel-Blöcke, feste Fußanker, vorberechnete Atlanten/Flashmasken
  und endlicher Cache; keine Bildverarbeitung pro Spielbild.
- Fokussierte Bank-, Zustands-, UI- und Snapshotprüfungen sowie echte
  GPU-Aufnahmen. Keine neue LAN-/Last-/Kampagnenfreigabe. Nutzer bewertet Art.

## Files

- src/actor_animation_bank.gd, src/actor_motion_controller.gd
- src/animation_studio.gd, src/animation_studio.tscn
- src/game.gd, src/dungeon_view.gd, src/vfx/feedback.gd
- src/perk_combat.gd, src/session_protocol.gd, src/data/balance.json
- src/art_reference.gd, scripts/Dev.ps1, Animation-Studio.cmd
- scripts/import_player_actor_keys.gd, scripts/import_enemy_actor_keys.gd
- scripts/bake_actor_animations.gd
- assets/actors/source/, keys/, baked/, provenance and import reports
- assets/data/actor_animations.json
- tests/actor_animation_bank_test.gd, tests/actor_motion_controller_test.gd
- tests/actor_rig_quality_test.gd, tests/actor_game_integration_test.gd
- tests/actor_render_anchor_test.gd, tests/animation_studio_ui_test.gd
- tests/crypt_enemy_network_peer.gd
- docs/ACTOR-ANIMATIONS.de.md, docs/ART-DIRECTION.de.md
- docs/NETZWERK-SITZUNG.de.md, docs/DEVELOPMENT.de.md, README.md
- assets/sprites/README.md, production/development-plan.md, this epic/status
- production/qa/evidence/story-023-actor-animation-library/

## Verification

Bank21.597/0, Motion14/0, Rig8/0, Gameintegration38/0, Studio1.965/0
(mit GPU-Aufnahme1.966/0), Fußanker-GPU10/0 und kontrollierte Replikation
zwischen zwei lokalen Prozessen bestanden. Bewahrte RED-Nachweise: fehlende
Bank/Motion, Krallenmaske/Stabseite und Fußanker mit drei tatsächlichen
Renderfehlern. UI-Regressionen Pause/Einzelschritte/Clipping wurden ebenfalls
vor Korrektur fehlgeschlagen gesehen. Import und Parse der19 beteiligten
Skripte erfolgreich; grüne Logs enthalten keine Engine-/Scriptfehler.

Bestehende Perks100/0, Feedback19/0, Gegner-AI171/0, Gegnerintegration127/0,
Spielregeln24/0, Erkundung85/0, Mitgliedschaft5/0 und Protokoll20/0 bestehen.
Regel-/Erkundungstests sind kontrollierte Fixtures, keine gespielte Kampagne.
Persönlicher Entwurf unverändert:
SHA256 B8AFDCE111E0005407E1CE0BCF4427276EFED51CC987C65099671C82701BBF16.

Unabhängige statische Nachprüfung von1.152 ausgewählten Bildern behebt zwei
sichtbare Fehler (abgetrennte Bosskrallen und wechselnde Stabhand). Nicht
jeder der9.216 Frames wurde visuell abgenommen. Die48 Abläufe entstehen aus
Richtungs-Keyposen und Körperteilkurven; keine48 handgezeichneten Aktionssets.
35 IDs sind rollenabhängig angebunden,13 vorbereitet. Native32px-Welt,
ruhige Krypta, vier Spieler,48Perks und Boss ausschließlich10 bleiben erhalten.

## Run and handoff

Run result: OBSERVED — production/qa/evidence/story-023-actor-animation-library/
07-eight-actors-animation.gif,02-animation-studio.png,03-crypt-reference.png,
04-prototype-solo.png,05-foot-anchor-regression.png,06-boss-preview-6x.png.
GPU-Vorschau und echter Solo-Start, keine Kampagnen-/LAN-/FPS-Abnahme.

Nächster GameDev-Schritt: Nutzer bewertet Silhouetten, Bewegungsvielfalt,
Timing und Treffergewicht in der Animationswerkstatt und im Prototypen.
Feedback bestimmt das anschließende Polishing. Keine neuen Klassenfähigkeiten,
keine zusätzliche Online-/Lastfreigabe und kein Commit/Push/Merge.
