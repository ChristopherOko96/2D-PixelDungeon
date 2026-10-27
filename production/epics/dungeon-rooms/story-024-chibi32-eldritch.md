# Story024: Lesbare32px-Chibis und Lovecraft-Boss

**Status:** Implemented and focused verified; user style/feel feedback pending
**Last Updated:** 2026-10-27
**Type:** Visual / Feel / Integration
**Layer:** Feature
**ADR:** N/A — minimal; existing animation bank and host gameplay retained
**Depends on:** Story023 implemented; user explicitly requests visual replacement

## Current scope

Die Höllenreferenzen bestimmen ausschließlich die Pixeldichte. Aus ihnen wird
weder ein Höllenthema noch eine neue Weltpalette abgeleitet. Der Nutzer
reduziert während der Umsetzung die zunächst vorgeschlagenen64px auf32×32
und verlangt anschließend niedlichere Chibi-Proportionen statt realistischer
Anatomie. Die letzten beiden Korrekturen gelten für den endgültigen Stand.

Vier Spieler und die drei Kryptagegner erhalten große lesbare Köpfe/Augen,
kurze sichtbare Beine und kräftige Hände/Stiefel. Der ehemalige rote gehörnte
Hüter wird durch ein blaugrünes Lovecraft-Tentakelwesen ersetzt. Kostüme und
Farberkennung bleiben erhalten. Generierte Master und exakte Prompts bewahren;
aktive Quellen sind echte32×32-PNGs mit harter Alpha und Integerdarstellung.

## Acceptance criteria

- Acht aktive Figuren mit32×32-Quellcanvas, lesbaren Augen/Händen/Beinen und
  niedlicheren Proportionen; neue Quellen separat von historischen Entwürfen.
- Boss besitzt Tentakelkopf, Jadeaugen und fremdartige Kryptaidentität;
  keine Hörner, rote Dämonenhaut, Lava oder Feuer als Monsterdesign.
- Alle48 bestehenden Bewegungsabläufe und vier Richtungen bleiben verfügbar.
  Fußanker, Trefferfeedback und Hostsicherheit bleiben erhalten.
- Keine Welt-/Dungeon-Neugestaltung aus den Referenzbildern. Persönlicher
  Quellentwurf, zehn Karten, Boss10 und48Perks bleiben unverändert.
- Native Spriteexporte, gebackene Atlanten und Werkstatt tatsächlich ansehen;
  kurze Asset-/Render-/Integrationschecks, keine neue LAN-/Lastfreigabe.

## Files

- assets/data/actor_detail_profile.json, assets/data/actor_animations.json
- assets/actors/chibi32/source/, keys/, baked/, PROVENANCE.md, import_report.json
- assets/actors/chibi32/actor_animations_candidate.json
- assets/actors/detail32/ — inactive adult candidates and exact prompts
- assets/actors/legacy_actor_animations_story023.json — historical catalog
- scripts/import_actor_detail_keys.gd, scripts/bake_actor_animations.gd
- src/animation_studio.gd, src/game.gd, src/data/balance.json
- tests/actor_detail_visual_test.gd, tests/actor_detail_import_test.gd
- tests/actor_rig_quality_test.gd — historical remap fixture decoupled from new art
- docs/CHIBI32-ELDRITCH.de.md, docs/ACTOR-ANIMATIONS.de.md
- docs/ART-DIRECTION.de.md, README.md, AGENTS.md, epic/QA/development status
- production/qa/evidence/story-024-detail32-eldritch/

## Verification

Der Assetvertrag scheitert am alten aktiven Katalog wie erwartet (RED1/1).
Zuschnittregression zunächst RED1/1; nach Extraktion ganzer Silhouetten33/0.
Native Assets691/0, vollständige Animationsbank21.597/0, Rig8/0, Motion14/0,
Studio1.965/0, Gameintegration38/0 und Kryptaintegration127/0 bestehen.
Letztere prüft weiterhin Boss ausschließlich10 und seine zwei Begleiter.
Import und Parse der beteiligten Skripte erfolgreich, grüne Logs ohne
Engine-/Scriptfehler.128 neue native Schlüsselbilder und16 aktive Atlanten.

Unabhängige statische Nachprüfung:1.152 ausgewählte Bilder aus sechs Aktionen,
vier Richtungen und allen acht Figuren; keine auffälligen abgeschnittenen
Stiefel/Waffen oder neuen abgetrennten Boss-Hände/Tentakel in dieser Auswahl.
Neue Zauberposen halten den Stab auf derselben Handseite. Die Reservierung von
hellen/Jadefarben hält kleine Augen-/Kristallakzente im64-Farben-Export sichtbar.
Die weichere Samplingalternative wurde mit einer behaltenen Vergleichsgrafik
verworfen. Keine Behauptung, jedes der9.216 Bilder sei ästhetisch abgenommen.

Persönlicher Entwurf unverändert:
SHA256 B8AFDCE111E0005407E1CE0BCF4427276EFED51CC987C65099671C82701BBF16.
Karten, Kollisionen, Gegnerwerte,48Perks und maximal vier Teilnehmer bleiben.
Einzige Balance-Dateiänderung ist der Anzeigename des Bosses; der Protokoll-
und Regelschemawert4/4 bleibt, der vorhandene Inhaltsabgleich erkennt den Namen.

## Run and handoff

Run result: OBSERVED — production/qa/evidence/story-024-detail32-eldritch/
07-eight-actors-animation.gif,02-animation-studio.png,03-crypt-reference.png
und04-prototype-solo.png. GPU-Designvorschau plus echter Solo-Start, keine
neue Kampagnen-, LAN- oder Leistungsfreigabe. Werkstatt startet aktuelle Art.

Nächster GameDev-Schritt: Nutzer bewertet32px-Pixeldichte, Niedlichkeit,
Lesbarkeit und Bewegungsgefühl. Gezieltes Polishing folgt diesem Feedback.
Quellmaster sind nicht als native32px-Dateien ausgegeben. Kein Commit/Push/Merge.
