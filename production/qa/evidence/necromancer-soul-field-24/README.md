# Seelenfeld: 24 statt sechs Bilder

Hinweis zur späteren Korrektur: Die PNGs dieses Ordners wurden bei der
Lavafeld-Prüfung erneut aufgenommen und zeigen nun die aktuelle Lava-
Darstellung. Ursprüngliche 24er-Quelltafel und GIF sind unverändert erhalten.
Der aktuelle vollständige Nachweis liegt unter `../necromancer-soul-lava/`.

31.10.2026. Nutzerwunsch: mehr Bilder für flüssigere Animation. Imagegen
erweitert die bestehende Vorlage auf 24 unterschiedliche Phasen im selben
Stil, Raster 6×4 à 256×256. Quelle/Prompt unter `assets/vfx/soul_field/`.
Originaltafel und ursprüngliches GIF bleiben erhalten. Neues GIF:
`output/necromancer-soul-field-v2/soul-field-preview.gif` (24 Bilder).

Aktiv im gemeinsamen Seelensturm-Renderer: 0,055 s statt 0,22 s pro Bild;
Loop bleibt 1,32 s. GIF wechselt aus Formatgründen 50/60 ms, damit seine
Gesamtdauer ebenfalls 1,32 s beträgt. Runtime nutzt durchgehend 55 ms.
Feldanker und Ausdehnung proportional an halbierte Einzelbildmaße angepasst.
Gesamte vorbereitete Pixelfläche bleibt identisch: 24×256² = 6×512².
Keine neue Kollisionsform, Treffer, Dauer, Kosten, Abklingzeit oder
Elementreaktion. Geister sind weiterhin Darstellung des Schadensfelds.

`tests/soul_field_test.gd`: **77/0**, einschließlich aller 24 Bildphasen,
unterschiedlicher Bilddaten, transparenter Ränder, stabiler Loopdauer,
später Phase und Cache-Wiederverwendung. GIF: alle 24 Bilder dekodiert.
Sichtbarer Godot-GPU-Lauf via `scripts/capture_mage_fireball.gd -- --soul`
zeichnet alle 24 Phasen in diesem Ordner auf. Eingerichteter Prüfzustand,
kein gespielter Lauf und keine LAN-/Lastabnahme. Die vorhandenen
user://-Cache-/Editorrechte- und Ressourcenmeldungen der Fixtures bestehen
weiter; siehe früheren Nachweis unter `necromancer-soul-field/README.md`.
Keine neue breite Kampfsuite: Gameplaywerte unverändert, gezielte
Animationsprüfung plus tatsächlicher Renderer. Kein Commit/Push/Merge.
