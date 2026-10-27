# Story008: Leere Räume, Tile-Palette und Kamera

Status: Done ·26.10.2026 · Workflow minimal · Branch `codex_v2`.

Nutzerauftrag: leerer Raum, selbst wählbare Raumgröße, separat auswählbare32×32-
Zellen, Q/E für vier Richtungen und leichte Spieler-/Mauskamera.

- Pro Vorlage12–64 ×10–48 ganze Tiles; verschiedene Maße im selben Dungeon.
- Leere Vorlagen ohne Einrichtung; automatische rechteckige Außenmauer.
  Größenwechsel ist rückgängig und schneidet keine gesetzten Inhalte ab.
-280 separate PNGs aus Original-Sheets; Pinsel mit vier Vierteldrehungen,
  Linksklick/Drag setzt, Rechtsklick löscht, optional solide Kollision.
- Gespeicherte Zellen werden validiert und im Hostlayout übertragen.
  Die Kamera wandelt Ziele korrekt zwischen Bildschirm/Welt um; HUD bleibt fest.
- Neue Modell-/Dateiprüfung14/0, echte Editor-/Spielintegration15/0, Kamera4/0.
  Bestehende Generator4146, Ports1585, Autor25, Editor32, Dungeon23,
  Erkundung52, Session19, Menü25 und Karten20 jeweils ohne Fehler.
- Zwei reale ENet-Prozesse:798 Zellen,1280×768, Vierteldrehung und Kollision
  identisch empfangen. Log: `Logs/custom-room-network/20261026-080624`.
  Dies ist eine synthetische Transport-Fixture, kein Kampf-/Performancetest.
- OpenGL: blanker Raum, Größenänderung, Palette und Kamerabewegung gerendert
  und angesehen. Quellen: `production/qa/evidence/editor-blank32.png`,
  `editor-variable-room32.png`, `editor-tile-palette32.png`, `camera-*-room32.png`.
- Erneuter realer Host-/Client-Lauf nach Kameraanbindung: fünf vollständig
  gedeckte Wechsel über zwei Ebenen, fünf passende Sounds und weiterlaufende
  Snapshots. `Logs/transition-network-smoke/20261026-110204-d4046c72`.

Anleitung: [Dungeon-Editor](../../../docs/DUNGEON-EDITOR.de.md).
