# Himmelslanze — 05.11.2026

Nutzerkritik: Der bisherige Pfeil wirkte nicht wie eine ultimative Fähigkeit.
Neue eigenständige 11×41-Kristalllanze mit weißgoldenem Kern, breiter Spitze,
Energieschwingen, neu zugeordneten neun Masken und weiterem Nachlauf.
Keine Änderungen an Kampfwerten, Hostautorität oder Protokoll.

Sechs rohe 1280×720-GPU-Aufnahmen mit dem tatsächlichen Laborrenderer:
01 Aufbau, 02 gespannte Ladung, 03 Abschuss, 04 Flug, 05 Wandkontakt,
06 abgelöste Teile. Lade-, Flug- und Kontaktbild wurden visuell angesehen.
Trainingsaufbau mit manuellem Simulationsschritt, kein erspielter Lauf.
Die alten Bilder unter ../himmelsspeer-rig/ bleiben historische Belege.

Aktuelle fokussierte Prüfungen: ultimate_fx 46/0, ranger_vfx 36/0,
marksman_sprites 72/0 = 154 Prüfungen ohne Fehler. Die Breitenprüfung misst
jetzt Quellbreite × Skalierung gegen den tatsächlichen Trefferkorridor;
die vorherige feste Skalierungszahl war an die alte 7-Pixel-Quelle gekoppelt.
Vorschau: 14 Auswahlvorgänge und drei Ultimate-Phasen geprüft.

Der erste Testaufruf kam vor Ende des Assetimports und brach am fehlenden
PNG-Loader ab; beendet, Import abgewartet, final erneut erfolgreich ausgeführt.
Beim Editorstart einmal Safe-save-Warnung. Finale Tests und Aufnahme enthalten
keine SCRIPT ERROR-/Parse-Fehler. Die Aufnahme meldet beim Beenden weiterhin
die bekannten sechs ObjectDB-Instanzen und zwei noch verwendeten Ressourcen.
Keine neue Story-/LAN-/FPS- oder subjektive Spielgefühl-Abnahme.

Wiederholen: scripts/generate_celestial_lance.cjs mit Node; Godot-Import,
anschließend tests/marksman_ultimate_fx_test.gd, tests/ranger_vfx_test.gd und
tests/marksman_sprites_test.gd headless ausführen. GPU-Aufnahme:
Godot --path . --script res://scripts/capture_himmelsspeer.gd.
APPDATA für die Belege auf Logs/lance-user isoliert.
