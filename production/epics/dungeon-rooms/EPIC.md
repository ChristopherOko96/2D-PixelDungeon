# Epic: Dungeon aus Raumvorlagen

Quelle: `design/game-brief.md`, MVP-Merkmal 3 und Baufolge 4.
Workflow: minimal; vorhandene Kampf-, Perk- und ENet-Grundlage wird weitergeführt.
Ziel: ein kurzer gemeinsamer Lauf mit verschiedenen, aus einem Seed erzeugten
Räumen und verlässlicher Geometrie auf Host und Clients.

| # | Story | Type | Status | ADR |
| --- | --- | --- | --- | --- |
| 001 | [Seed-basierte Räume, Geometrie und Raumkarte](story-001-seeded-rooms.md) | Integration | Done | N/A (minimal — no ADRs) |

Weitere Baufolge nach dieser Story: vollständigen Vier-Spieler-Kampf und
Verbindungsabbrüche während Belohnung/Übergang prüfen; anschließend LAN und
Latenz/Paketverlust nachweisen. Animationen bleiben ein späterer Polishing-Schritt.
