# Story 006: Transparente Belohnungskarten und echte Pixel-Schrift

> **Epic**: Dungeon aus Raumvorlagen
> **Status**: Done
> **Layer**: Presentation / UI Integration
> **Type**: UI
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-10-25

## Context

Der Nutzer lehnt die bisherige Belohnungsliste im großen Menürahmen und die
Systemschrift ab. Gewünscht sind frei stehende Symbole/Karten vor transparentem
Hintergrund und eine zum Pixelstil passende Schrift. Fehlende passende Symbole
sollen mit dem Bildgenerierungssystem erstellt werden.

## Acceptance Criteria

- [x] Drei eigenständige Karten mit großem zentralem Symbol, Perkname und Wirkung.
- [x] Halbtransparente Karten und Hintergrund; die Spielwelt bleibt sichtbar.
  Der undurchsichtige Informationsrahmen ist gleichzeitig vollständig verborgen.
- [x] Maus, Links/Rechts, Enter und Tab unterstützen die Auswahl. Fokus wandert
  erst nach Hostbestätigung zu Ready und bleibt bei weiteren Snapshots stabil.
- [x] Fünf passende transparente Symbole erzeugt, als16×16-RGBA normalisiert;
  Originale und vollständige Prompts im Projekt erhalten.
- [x] Pixelify Sans lokal mit OFL-Lizenz eingebunden; deutsche Zeichen geprüft.
  Spiel, Menüs, HUD, Artreferenz und Baukasten verwenden dieselbe Schrift.
- [x] Solo-Pause und lokaler Mehrspieler-Eingabeschutz gelten für beide Ansichten.
  Gewählte Karten bleiben nach Schließen/Wiederöffnen korrekt markiert.
- [x] Auswahl und Ready verwenden weiterhin die normalen Hostprüfungen.
  Doppelte Klicks, ausstehende Bestätigung und Rückkehr zur Erkundung geprüft.
- [x] UI-Integration, tatsächlicher Host/Client-Kartenlauf, bestehende Regeln,
  Import und OpenGL-Sichtprüfung bestanden.

## Implementation

`reward_overlay.gd` ist ein eigener Geschwisterknoten des Informationsmenüs.
`game.gd` verwaltet `reward_open` innerhalb des gemeinsamen Modalzustands.
Der Belohnungs-Menüpunkt öffnet diese separate Ansicht. Frühere Listenbuttons
wurden entfernt. Die Karten stellen nie selbst Perks oder Raumfortschritt her.

`pixel_style.gd` lädt die gebündelte proportionale Pixelify Sans ohne Antialiasing
oder Systemfallback. `assets/fonts/` enthält die unveränderte TTF und OFL.
`assets/items/perks/` enthält fünf separate, mit dem eingebauten image_gen erzeugte
Symbole samt Originalen, Prompts und reproduzierbarer Normalisierung. Die großen
Originaldateien werden durch `.gdignore` nicht als Spielressourcen importiert.

## Evidence

- Neue Kartenprüfung vor Umsetzung rot1/1; jetzt `REWARD_CARDS checked=20 failures=0`.
- `PAUSE_MENU25/0`, Spielregeln22/0, Erkundung51/0, Dungeon-Integration23/0,
  Editor-Integration25/0 bestanden. Import/Parse:16 Spielskripte.
- Echte Host-/Client-Belohnungsauswahl: PASS,
  `Logs/reward-network-smoke/20261025-233204-a5c5ec33`. Normaler Kampf,
  unterschiedliche Karten/Perks, beide bestätigt und bereit, Erkundung in Raum1,
  beide Overlays geschlossen, beide Exit0. Keine künstlichen Gegnerlöschungen.
- Bestehender echter Menü-/Netzwerkfall: PASS,
  `Logs/pause-network-smoke/20261025-233204-b7603be1`.
- Zusätzlicher unabhängiger Kartenlauf: PASS,
  `Logs/reward-network-smoke/20261025-233152-c1ca2d18`.
- Unabhängige Codeprüfung ohne materielle Findings; Reviewer führte20/0 und25/0 aus.
- Karten vor/nach Auswahl, neue Schriftprobe, Menü, Artreferenz und Baukasten
  mit OpenGL gerendert und angesehen. Deutsche Glyphen und proportionale Breiten
  zusätzlich mit Godot geprüft. NativePNG-Maße, Alpha0/255 und höchstens24 Farben
  je Icon aus den Dateien geprüft.

## Limits

Weitere UI-Stilabstimmung bleibt möglich; dies ist keine behauptete ästhetische
Freigabe. Keine neue LAN-/WAN-/Latenz-/Leistungsabnahme und keine neue Mechanik.
Die Kartenbilder sind angehaltene UI-Fixtures; der separate Prozess-Smoke prüft
den tatsächlichen Kampf und die autoritative Vergabe.

Bedienung, Bilder, Lizenz und Prompts: `docs/BELOHNUNGEN.de.md`.
