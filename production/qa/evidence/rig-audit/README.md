# Rig-Prüfansichten, 2026-11-03

Die PNGs sind rohe Godot-Viewport-Aufnahmen in 1280×720. `effects-*`,
`monsters-*` und `native-*` verwenden die echten Laufzeit-Zeichenpfade in zwei
Animationsphasen. `live-necro/` und `live-archer/` zeigen vorbereitete Zustände
im tatsächlichen Spielrenderer. Keine erspielte Kampagne und keine LAN-/FPS-
oder subjektive Art-Abnahme.

Aufnahmehelfer: `scripts/capture_rig_audit.gd`, `capture_rig_game.gd` und
`capture_rig_archer.gd`. Die frühere Aufnahmehistorie bleibt erhalten.
`ring-probe.png` ist eine lokale Diagnose und gehört nicht zum Prüfsatz.

Der Bericht `docs/RIG-ANIMATIONEN-AUDIT.de.md` erklärt Umfang und Grenzen.
`scripts/receipt_rig_audit.cjs` prüft die erfolgreichen Logs und erstellt
`receipt.json` mit Hashes, einzelnen Prüfzahlen und beiden lokalen
Zwei-Prozess-Netzwerkresultaten. Die Logpfade bleiben zur Reproduktion
aufgeführt; Logs selbst gehören nicht in die Spielassets.
