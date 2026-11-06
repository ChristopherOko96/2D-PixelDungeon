# Waldläufer-Fähigkeiten, 03.11.2026

Acht rohe Godot-Viewport-Aufnahmen in 1280×720 aus dem tatsächlichen
Trainingsraum. `scripts/capture_ranger_fields.gd` erzeugt vorbereitete
Zustände und spielt zwischen den Aufnahmen Welt- und Rendererframes ab.
Kein erspielter Durchlauf, keine Leistungs-/LAN-/WAN-Abnahme.

1. Bezahlte Ladung des Himmelsspeers.
2. Breiter native geriggter Pfeil im Flug.
3. Getrennte Rig-Teile, Holzsplitter und Funken vor der ersten Wand.
4. Scharfe Giftfalle vor Auslösung.
5. Vorhandene echte Giftpfütze mit kleinerer Giftwolke über ihrem Zentrum.
6. Rankensog kurz nach Beginn.
7. Dieselben Gegner zum Zentrum gezogen.
8. Aktueller Talentbaum mit Giftfalle und Rankensog.

Die Kopf-/Schaft-/Federteile wurden im ersten Entwurf zu weit vor dem
Pfeilanker gezeichnet. Die echte Aufnahme deckte das auf; eine geometrische
Regression schlug anschließend vor der Korrektur zweimal fehl. Jetzt
begrenzt die Host-Kontaktebene alle Teile einschließlich rotierender Splitter.

`receipt.json` hält Quell-/Bildhashes, einzelne erfolgreiche Prüfungen und
den Zwei-Prozess-ENet-Nachweis fest. Der Netzwerktest prüft insbesondere
Treffbreite und Wandnormale des Pfeils auf Host und Client; die neuen
Giftmedien werden durch Host- und Hölle/Frostgruft-Integration geprüft.
Bekannte Fixture-Warnungen beim Beenden (ObjectDB/Resources/DummyTexture)
bleiben offen; keine Behauptung fehlerfreien Speicherabbaus.

Aktuelle Regeln und Bedienung: `docs/WALDLAEUFER-FELDER.de.md`.
