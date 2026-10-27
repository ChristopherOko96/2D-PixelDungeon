# Story007:32-Pixel-Raster, Animationen und Schwarzblenden

Status: Done ·26.10.2026 · Workflow minimal · Branch `codex_v2`, lokale Änderungen.

Nutzerauftrag: Sounds/Animationen des neuen Godot-`main` übernehmen, wieder32×32,
Editor als Raumvorlagen-Baukasten und schwarze Aus-/Einblendung beim Tür-/Treppenwechsel.

- Native Geometrie auf896×480 verdoppelt; Geschwindigkeiten/Radien entsprechend
  angepasst. Generator4, alte16-Pixel-Entwürfe werden verlustfrei eingelesen.
- Original0x72-Frames samt Lizenz, Synthesizer, Treffer-/Todesfeedback übernommen.
  Treppe hat eigenen Sound. Boss verwendet datengetriebene Angriffsphasen.
- Host hält Übergabe an; Token/Deckungsframe und Zielpuffer schützen jeden Client.
- Regel-/Integrationsprüfungen bestanden: Animation25, Feedback19, Transition29,
  Session19, Spiel22, Erkundung52, Dungeon23, Menü25, Karten20, Editor32.
- Vier echte Prozesse über zwei Ebenen bestanden:
  `Logs/dungeon-network-smoke/20261026-011814-50622b16`.
- Zwei echte Fade-Beobachter: fünf gedeckte Wechsel, fünf Sounds,
  einschließlich Treppe; `Logs/transition-network-smoke/20261026-012523-f9ad7cca`.
- OpenGL-Aufnahmen und vollständige schwarze Tür-/Treppenframes geprüft.

Bedienung: [Animationen und Übergänge](../../../docs/ANIMATIONEN-UEBERGAENGE.de.md).
Netzwerktests sind lokale Funktionsnachweise; LAN/WAN und Performance bleiben offen.
