# Gegner-Statuseffekte — 05.11.2026

Nutzerauftrag: erkennbare Partikel direkt an brennenden, vergifteten und nassen
Gegnern. Spätere Klarstellung: zuerst diese Darstellung, Fallenalchemist separat.

## Umsetzung

Gemeinsamer Emissionsbesitzer in Feedback, vier visuell unterscheidbare Effekte:
Flammenzungen, hohle Giftbläschen, fallende Wassertropfen, Kristallfunken bei
explizitem Frostzustand. Seitliche Emission hält die Zeichen außerhalb der
deckenden Körperpixel sichtbar. Freie Teilchen verbleiben im vorhandenen
physikalischen Löser und erzeugen keine neuen Gameplay-Flächen.

Hauptdungeon nutzt die bestehende replizierte Statusliste. Krypta, Hölle und
Frostgruft übersetzen ihre tatsächlichen Zustandszeitfelder. Generischer Stun
ist kein Frost, Blutung ist kein Feuer. Kein Schaden-/Kampf-/Protokollumbau.
Details und Datenschema: docs/GEGNER-STATUSEFFEKTE.de.md.

## Ergebnisse

- enemy_status_fx_test: 39 Prüfungen, 0 Fehler.
- feedback_test: 19 Prüfungen, 0 Fehler.
- particles_physics_test: 26 Prüfungen, 0 Fehler.
- Labor-Aufnahme: 2 Assertions, 0 Fehler; alle vier Effekte im echten Löser,
  nach Entfernen der Zustände und Ablauf der freien Teilchen keine Restemission.
- Story-Aufnahme: 12 Assertions, 0 Fehler; reale Zustandsvergabe über den
  Exposure-Host in Hölle, Frostgruft und Krypta; alle drei Statusarten erreichen
  die jeweiligen lokalen Feedbackbesitzer und emittieren im gemeinsamen Löser.

Insgesamt 98 fokussierte Prüfungen/Assertions, keine SCRIPT ERROR-/Parse-Fehler
in den finalen Läufen. Die bekannten Teardown-Warnungen bleiben: Labor sechs
ObjectDB-Instanzen/zwei Ressourcen; Storys 1357 ObjectDB-Instanzen/sechs
Ressourcen und 887 GL/RID-Texturen. Stderr separat erhalten; keine Behauptung,
dass diese älteren Ressourcenprobleme hier behoben wurden.

## Aufnahmen

Sechs rohe 1280×720-GPU-Viewportbilder und vier unvergrößerte Ausschnitte:

- 01-status-overview: oben links Feuer, Mitte Gift, rechts Wasser;
  unten links Frost, rechts Gift und Wasser zusammen.
- 02-status-motion: dieselben Gegner zu einem späteren Zeitpunkt.
- 03-cleansed: Zustände entfernt, verbleibende Partikel abgelaufen.
- 04-hell, 05-frost, 06-krypta: links Feuer, Mitte Gift, rechts Wasser.
- *-detail.png: ausschließlich ausgeschnittene Regionen dieser Bilder.

Alle sind kontrollierte Trainingszustände mit echten Host-Statusaufrufen,
keine erspielten Läufe. Das Labor schreitet Simulation und Partikelbesitzer
gemeinsam in 1/60-s-Schritten fort; keine Abhängigkeit von der Geschwindigkeit
des Aufnahmerechners. Keine Netzwerk-, Kampagnen- oder FPS-Abnahme.

Wiederholung: Godot 4.7.2, isoliertes APPDATA (Logs/status-user bzw.
Logs/status-story-user), --path . --script res://scripts/capture_enemy_status.gd
bzw. capture_enemy_status_story.gd mit echtem Compatibility-Renderer.
Die drei Tests laufen headless mit --script res://tests/<Name>.gd.
