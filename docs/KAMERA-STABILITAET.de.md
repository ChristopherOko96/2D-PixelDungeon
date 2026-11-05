# Ruhige Pixelkamera und Zwischenbilder

05.11.2026, auf Basis `1e417341`, lokale Änderung auf `codex_v2`.

## Ursache und Korrektur

Die Story-Kamera änderte ihren Zoom bei Ruhe, Gegnergruppen und Ultimates.
Zusammen mit Nearest-Texturen und einer nicht am Bildschirmraster ausgerichteten
Kameraverschiebung änderte das ständig die Abbildung der Bodentexel. Zusätzlich
las die Kamera pro Bild die letzte Position des eigenen 60-Hz-Simulationstakts.
Eine höhere Bildrate allein beseitigt diese Treppenbewegung nicht.

Pixel-Skins behalten jetzt den Basiszoom. Folgen, Mausvorlauf, Kampfzentrierung
und die bestehenden optionalen Erschütterungen bleiben; ihre gemeinsame
Translation wird erst am Ende auf physische Bildschirmpixel gerundet. Dabei
werden Fenster-Stretch und die Bildschirmmitte berücksichtigt. Der interne
Kamerazustand bleibt ungerundet, damit kleine Bewegungen nicht verloren gehen.
HD-Skins behalten ihre dynamischen Zooms. Der Ausschnitt im Pixelmodus wird
bei großen Gegnergruppen somit nicht mehr automatisch weiter.

`StoryPresentation` speichert vor jedem Spielschritt nur Spieler- und
Gegnerpositionen. Die übrige Zeit im festen Takt liefert den Interpolationsanteil.
Kamera, Heldenkörper, Waffe, visuelle Abdeckung, Gegnerkörper, Schatten und
ihre Grundbeleuchtung verwenden diese Darstellungspositionen. Die Gegner-ID
wird zusätzlich gegen die tatsächliche Dictionary-Identität geprüft. Neue
Gegner ohne Historie und tote Körper werden direkt am aktuellen Ort dargestellt.

Die Simulation wird weder extrapoliert noch verlangsamt. Die Darstellung liegt
höchstens einen Tick (bei 60 Hz rund 16,7 ms) zurück. Unter Überlast wird der
Anteil bei eins begrenzt; vorhandene Simulationsschuld bleibt erhalten.
Diese Änderung löst deshalb keine dauerhaft zu teure Kampfsimulation.
Pause, Etagenwechsel, Run-Ende und externe Kamerasprünge verwerfen Historie.
Große Positionssprünge werden direkt dargestellt, statt quer durch Wände
zu gleiten. Projektile, Begleiter und freie Effektpartikel behalten ihren
bisherigen Darstellungstakt; dies ist keine vollständige VFX-Interpolation.

## Treffermasken und Eingabe

Die Story-Gegner mit teilbaren Rigs verwenden gezeichnete Körperteile auch für
Treffermasken und Angriffspunkte. Ihr Renderer rundet die ursprüngliche Pose
und addiert erst danach die Darstellungsverschiebung. Der Host entfernt genau
diese Verschiebung für Körpermasken und Angriffspunkte. Die sichtbare
Grundposition verändert dadurch weder `p`/`pos` noch die ursprünglichen
Kollisionsmatrizen. Beleuchtung behält die gezeichnete Position.

Die Kamera aktualisiert ihren Canvas-Transform unmittelbar nach der Änderung.
Welt-/Bildschirmumrechnung und das Zielen verwenden somit denselben Transform
wie die Darstellung. Globale Pixel-Snap- oder Physics-Interpolation-Schalter
werden nicht zusätzlich aktiviert: Die Story simuliert über einen eigenen
Zeitgeber und zeichnet ihre Dictionaries selbst.

## Konfiguration

Optionale Felder in `assets/data/story_camera.json`:

| Feld | Standard | Bedeutung |
| --- | --- | --- |
| `pixel.fixed_zoom` | `true` | Pixelkamera behält Zoomfaktor 1 über dem Basiszoom. |
| `pixel.snap_translation` | `true` | Gemeinsame Kameratranslation auf Bildschirmraster ausrichten. |
| `presentation.teleport_distance` | `192.0` | Maximale Strecke in Weltpixeln pro Tick, die noch interpoliert wird. |

Die vorhandenen Optionen „Kamerabewegung reduzieren“ und „Bildschirmwackeln“
bleiben nutzbar. Keine Texturen, Farben oder Auflösungsregeln wurden ersetzt.

## Nachweise und Grenzen

`production/qa/evidence/camera-stability/README.md` dokumentiert Regressionen,
gezielte Tests und GPU-Aufnahmen. Eine ruhige Kameratranslation wurde auf der
echten Krypta bei mehreren Fenstergrößen geprüft. Statische Screenshots sind
keine vollständige subjektive Bewegungsabnahme und kein Schlachten-FPS-Test.

Engine-API-Referenzen:
[Viewport-Stretch](https://docs.godotengine.org/en/stable/classes/class_viewport.html#class-viewport-method-get-stretch-transform),
[Camera2D](https://docs.godotengine.org/en/stable/classes/class_camera2d.html).
