# Kamera: Sonderräume und Fensterformate

09.11.2026, Basis `676af43a`, lokale Änderungen auf `codex_v2`.
Dieses Protokoll dokumentiert den aktuellen Nachtest, nicht fehlende Artefakte
des ursprünglichen Kamera-Durchgangs vom 05.11.

## Reproduktion und Ergebnisse

`tests/story_presentation_integration_test.gd` wurde zuerst erweitert und gegen
den unveränderten Runtime-Code ausgeführt: **751 Prüfungen, 97 Fehler**.
72 Fehler betrafen den tatsächlichen erweiterten Viewport; 25 betrafen den
animierten Zoom im Labyrinth bzw. Spiegelraum und dessen Rückkehr zum Basiszoom.
Danach wurde die Runtime korrigiert und derselbe Test erneut ausgeführt.

| Test | Ergebnis |
| --- | --- |
| `story_presentation_test.gd` | 2434 / 0 Fehler |
| `story_camera_test.gd` | 13 / 0 Fehler |
| `story_camera_jitter_test.gd` | 3 / 0 Fehler |
| `story_presentation_integration_test.gd`, headless | 751 / 0 Fehler |
| `story_presentation_integration_test.gd -- --capture`, GPU | 756 / 0 Fehler |
| `maze_rooms_test.gd` | 12 / 0 Fehler |

Godot 4.7.2, Compatibility/OpenGL, Radeon RX 6600. Die GPU-Prüfung zeichnet die
echte Krypta bei 1280×720, 1365×767, 1920×1080, 2560×1080 und 1024×768 auf.
Die PNGs liegen neben dieser Datei. Ultrawide- und 4:3-Aufnahmen wurden visuell
kontrolliert. Die Assertions vergleichen zusätzlich pro Bild die tatsächliche
Canvas-Transformation mit Pixelraster, Aim-Umrechnung und Sichtbarkeitsbereich.
Der Test nutzt isolierte Profile/Speicherpfade und entfernt seine temporären
Dateien. Der Labyrinthtest prüft weiterhin Dunkelheit und Gegnerplatzierung;
seine alte Erwartung eines zusätzlichen Pixel-Zooms wurde bewusst ersetzt.

## Grenzen

Keine Script-/Parse-Fehler in den aufgezeichneten Läufen. Godot meldet fehlenden
Schreibzugriff auf `user://logs/godot.log`, im GPU-Lauf zusätzlich auf den
Shader-Cache. Die Konsolenausgaben wurden deshalb separat gespeichert.

Kein Schlachten-Benchmark und keine FPS-Steigerung behauptet. Statische Bilder
ersetzen keine subjektive Bewegungsabnahme. Im Pixelmodus wechselt der
Spiegelraum einmalig direkt auf seinen notwendigen weiten Ausschnitt; innerhalb
des Raums bleibt der Zoom stabil. Gameplay-Takt, Schaden, Gegneranzahl und
Netzwerklogik wurden nicht geändert.
