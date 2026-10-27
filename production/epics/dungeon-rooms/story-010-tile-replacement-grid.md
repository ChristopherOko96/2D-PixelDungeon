# Story010: Direktes Tile-Ersetzen und Kollisionsraster

Status: Done ·26.10.2026 · Workflow minimal · lokale Änderungen auf `codex_v2`.

Der Nutzer meldet wirkungsloses Übermalen bestehender Tiles und möchte blockierte
und begehbare Felder beim eingeschalteten Raster erkennen.

- Deduplizierung gilt nur innerhalb eines laufenden Pinselstrichs und bei
  unverändertem Pinsel. Neue Grafik, Rotation, Ebene oder Kollision wirken sofort,
  auch bei Q/E und Mausbewegung innerhalb derselben Zelle.
- Palette bietet **ERSETZEN**, standardmäßig an. Boden ersetzt überlagerte Wand,
  Tür/Treppe; Struktur behält darunterliegenden Boden. Aus bearbeitet gezielt nur
  eine Ebene. Startplätze, Feuer und Truhe bleiben erhalten. Undo/Redo ist atomar.
- Tile-Ersetzen in älteren Räumen entfernt nur die gewählte Säulenzelle;
  Nachbarwände bleiben bestehen.
- Read-only Klassifikation aus tatsächlichem Layout: Grün/begehbar, Rot-X/Wand,
  Grau-Schraffur/kein Boden. Legende und Zellenhinweis; Raster aus zeigt reine Grafik.
- Replacement29/0, Klassifikation17/0, gerenderte Overlay-Pixel6/0. Vor Korrektur
  gleiche-Zelle-/Drag-Repros13/4 und Legacy-Säule29/2 rot beobachtet.
- Bestehende freie Modell-/UI-/Geometrieprüfungen13/0,20/0,30/0; frühere UI20/0,
  Editorintegration32/0, Autorenmodell27/0 und Dungeonintegration23/0 bestanden.
- OpenGL-Aufnahmen mit/ohne Raster und Ersetzen-Palette angesehen:
  `production/qa/evidence/editor-collision-grid-{on,off}.png`,
  `editor-replace-palette.png`. Logs `Logs/editor-repair-*.log`.

[Bedienung](../../../docs/DUNGEON-EDITOR.de.md). Kein neues Netzwerkprotokoll;
der Rasterzustand ist ausschließlich lokal im Editor.
