# Story009: Grundrisse auf einer wirklich freien Zeichenfläche

Status: Done ·26.10.2026 · Workflow minimal · Branch `codex_v2`, lokale Änderungen.

Der Nutzer möchte den Grundriss selbst bauen: keine automatisch erzeugten Böden,
Außenmauern oder vier Eingänge. Neue Vorlagen sind daher `layout_mode=freeform`
mit voller Zeichenfläche. Bestehende rechteckige Vorlagen bleiben erhalten.

- Weißer/schwarzer Hintergrund und optionales Raster ändern nur die Ansicht.
- Gemalter Boden definiert die freie Kontur; unbemalte Stellen blockieren.
- Boden und Wand/Deko haben getrennte Ebenen mit eigener Grafik und Drehung.
- Echte Türen behalten Position, Grafik und Verbindungsrichtung; Platzieren
  öffnet die darüberliegende Wand, ohne Boden oder Gegenöffnung zu erfinden.
- Startplätze und Bossabstieg werden ausdrücklich gesetzt. Unfertige Arbeit
  bleibt speicherbar; Veröffentlichung und Test prüfen begehbare Verbindungen.
- Die Dungeonplanung und der Einzeltest suchen passende vorhandene Türseiten.
- Modell13/0, Geometrie/Dateien30/0, Editor20/0, tatsächliche Renderpixel4/0.
  Angepasste Modell-/UI-/Autorenregression18/0,20/0,27/0; bestehende Regeln grün.
- Zwei reale ENet-Prozesse übertragen799 Zellen, freien Grundriss, Void/Wand-
  Kollision und frei gesetzte Innenraumtür identisch:
  `Logs/custom-room-network/20261026-113731` (kontrollierte Transport-Fixture).
- Leere weiße/schwarze Fläche, manuell gemalteL-Form und Palette unter OpenGL
  angesehen. Siehe `production/qa/evidence/freeform-*.png`.

Regressionsbefunde vor Korrektur rot gesehen: vorheriger automatischer Renderer,
kleine getrennte Bodeninsel, Koordinatenüberlauf, ungeeignete feste Testfolge
und zu große unlesbare Draftdatei. Keine neue LAN-/WAN-/Leistungsabnahme.

[Schritt-für-Schritt-Anleitung](../../../docs/DUNGEON-EDITOR.de.md).
