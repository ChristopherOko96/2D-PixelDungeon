# Treffer-Rig: Prüfstand 04.11.2026

- `hit_burst_rig_test`: 39/0, echte native Masken/Gelenke und Feedback-Zählergrenzen.
- Bestehendes `feedback_test`: 19/0.
- `capture_hit_rig`: echter Gezielter Schuss, Projektil trifft Zielpuppe,
  Lebensverlust und entstandener Rig-Effekt jeweils bestätigt.
- `capture_hit_rig_story`: 4/0, tatsächliche Pfeilkollisionen und entstandene
  Effekte in den Höllen-/Frostgruft-Szenen.

`01-confirmed-hit.png`, `02-rays-and-chips.png`, `03-hell-hit.png` und
`04-frost-hit.png` sind rohe 1280×720-GPU-Viewportbilder aus vorbereiteten
Trainingszuständen. Nur das zweite Bild erhöht das lokale Rig-Alter um 90 ms,
um die Teile nach dem Kernblitz zu zeigen. Keine erspielte Kampagne und keine
Netzwerk-/LAN-/Performanceabnahme. Tests und Aufnahmen nutzen isolierte Profile.

Die bereits dokumentierten ObjectDB-/Resource-/Texturmeldungen beim Beenden
der Spiel-Fixtures bleiben gesondert von Skriptfehlern zu betrachten; diese
Änderung beansprucht keine Reparatur der Ressourcenfreigabe. Die beiden
fokussierten headless Suiten endeten ohne solche Meldungen.

Wiederholen mit Godot 4.7.2 aus der Projektwurzel:

```
godot --headless --path . --script res://tests/hit_burst_rig_test.gd
godot --headless --path . --script res://tests/feedback_test.gd
godot --path . --script res://scripts/capture_hit_rig.gd
godot --path . --script res://scripts/capture_hit_rig_story.gd
```

Vor Prüfungen APPDATA auf einen eigenen Scratchpfad setzen. Die letzten beiden
Befehle benötigen einen wirklichen Renderer. Konfiguration, Schema und Grenzen:
`docs/TREFFER-RIG.de.md`. Es wurden keine Kampagnenprofile verändert.
