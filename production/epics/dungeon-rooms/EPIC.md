# Epic: Dungeon aus Raumvorlagen

Quelle: `design/game-brief.md`, MVP-Merkmal 3 und Baufolge 4.
Workflow: minimal; vorhandene Kampf-, Perk- und ENet-Grundlage wird weitergeführt.
Ziel: ein kurzer gemeinsamer Lauf mit verschiedenen, aus einem Seed erzeugten
Räumen und verlässlicher Geometrie auf Host und Clients.

| # | Story | Type | Status | ADR |
| --- | --- | --- | --- | --- |
| 001 | [Seed-basierte Räume, Geometrie und Raumkarte](story-001-seeded-rooms.md) | Integration | Done | N/A (minimal — no ADRs) |
| 002 | [Native 16-Pixel-Grafik und freie Erkundung](story-002-native16-exploration.md) | Integration | Done | N/A (minimal — no ADRs) |
| 003 | [Getrennte Artstyle-Referenz und Herzgrafik](story-003-art-reference.md) | UI | Done | N/A (minimal — no ADRs) |
| 004 | [Dungeon-Baukasten für eigene Räume](story-004-dungeon-editor.md) | Tool | Done | N/A (minimal — no ADRs) |
| 005 | [Spielansicht und Esc-Pausenmenü](story-005-pause-menu.md) | UI / Integration | Done | N/A (minimal — no ADRs) |
| 006 | [Transparente Belohnungskarten und Pixel-Schrift](story-006-reward-cards.md) | UI | Done | N/A (minimal — no ADRs) |
| 007 | [32-Pixel-Raster, Animationen und Schwarzblenden](story-007-native32-animations-transitions.md) | Integration | Done | N/A (minimal) |
| 008 | [Leere Räume, Tile-Palette und Kamera](story-008-free-rooms-palette-camera.md) | Tool / Presentation | Done | N/A (minimal) |
| 009 | [Freie Zeichenfläche ohne vorgegebenen Grundriss](story-009-freeform-canvas.md) | Tool / Integration | Done | N/A (minimal) |
| 010 | [Tile-Ersetzen und sichtbare Kollisionen im Raster](story-010-tile-replacement-grid.md) | Tool / Fix | Done | N/A (minimal) |
| 011 | [Ganze Flächen auswählen, löschen und ersetzen](story-011-area-editing.md) | Tool | Done | N/A (minimal) |

| 013 | [Crypt of the Damned: Konturen und eigenständige Grundrisse](story-013-crypt-candidate.md) | Generation / Presentation | Manual acceptance pending | N/A (minimal) |

| 014 | [Ausgewählten Raum spielen, belebte Themen und einheitliche Steintiles](story-014-selected-room-living-art.md) | Tool / Presentation | Manual acceptance pending | N/A (minimal) |

| 015 | [Zehn Karten im normalen Prototyp und Boss in Raum10](story-015-active-ten-room-prototype.md) | Integration | Integrated / screenshots captured | N/A (minimal) |

| 016 | [Original-Tiles und erste Prototyp-Stimmung wiederherstellen](story-016-original-tile-restore.md) | Presentation | Visual direction superseded by017 | N/A (minimal) |
| 017 | [Ruhiger erster Prototyp ohne Dekoration und Rucklerkorrektur](story-017-quiet-classic-performance.md) | Presentation / Performance | Implemented / CPU profiled / manual acceptance pending | N/A (minimal) |
| 018 | [Lesbare Pixelschrift und Vollbild](story-018-readable-font-fullscreen.md) | UI / Presentation | Implemented / visual review complete / manual play acceptance pending | N/A (minimal) |
| 019 | [Clientglättung und kompatible Sitzungsaufnahme](story-019-client-smoothing-admission.md) | Networking / Presentation | Implemented / locally verified | N/A (minimal) |
| 020 | [Aktuelle Zehner-Koopabnahme](story-020-ten-room-coop-acceptance.md) | Integration / QA | Local passed / real LAN and subjective acceptance pending | N/A (minimal) |
| 021 | [48 unterschiedliche Perks und Builds](story-021-perk-builds.md) | Gameplay / Integration / UI | Implemented / focused verified / balance feedback pending | N/A (minimal) |
| 022 | [Krypta-Stil und drei Untotenrollen](story-022-crypt-enemies.md) | Gameplay / Presentation | Implemented / focused verified / visual feedback pending | N/A (minimal) |
| 023 | [Acht Figuren mit je48 Animationsabläufen und Animationswerkstatt](story-023-actor-animation-library.md) | Visual / Feel / UI / Integration | Implemented / focused verified / user animation feedback pending | N/A (minimal) |
| 024 | [32px-Chibis und Lovecraft-Boss](story-024-chibi32-eldritch.md) | Visual / Feel / Integration | Implemented / focused verified / user style feedback pending | N/A (minimal) |

Story024 ersetzt die Figurenart durch niedlichere32×32-Chibis und den
Lovecraft-artigen Schläfer der Tiefe.48 Abläufe bleiben erhalten. Die Höllen-
Referenzen bestimmen nur Pixeldichte; keine Welt-/Materialübernahme daraus.

Aktueller Figurenstand ist Story023: vier neue Spieler und vier Untoten-/Boss-
Identitäten mit je48 gebackenen Bewegungsabläufen. Animation-Studio.cmd dient
der direkten Auswahl, Richtungsansicht und Bildprüfung.35 Aktionskennungen
sind rollenabhängig an vorhandene Spielzustände angebunden,13 vorbereitet.
Nächster Schritt ist die persönliche Animations-/Feel-Abnahme; weitere
Online-/Lastprüfung bleibt nach Nutzerpriorität zurückgestellt.

Aktuelle Grafikvorgabe ist Story017: ruhiger originaler 32px-Schieferboden,
klare Mauerflächen und warmes orangefarbenes Feuer. Keine Raumdekoration oder
Nebel; spätere Assets nur in demselben Stil. Zehn Karten und Boss10 bleiben
erhalten, ebenso der persönliche Quellentwurf. Cache-Änderungen und gezielte
CPU-Profile sind dokumentiert. Eine sichtbare sechssekündige Solo-Gartenmessung
mit sechs Gegnern ergab144FPS auf derRX6600 (Bildzeit p95=8,29ms). Manuelle
Abnahme und Vier-Spieler-Leistungsfreigabe bleiben offen.

Weitere Baufolge: manuelles Spielgefühl und Verbindungsabbrüche während
Belohnung/Übergang prüfen; anschließend LAN und Latenz/Paketverlust nachweisen.
Vier-Spieler-Kampf ist lokal über zwei Ebenen belegt. Feuer, Figuren und
Trefferfeedback sind animiert; frei dimensionierte rechteckige Vorlagen und
die Tile-Palette sind nutzbar. Story009 ergänzt selbst gemalte freie Konturen,
getrennte Ebenen und eigene Türpositionen auf einer leeren Zeichenfläche.
