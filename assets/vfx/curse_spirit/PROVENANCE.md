# Fluchgeist — freigegebene Quellteile

Quelle: `production/qa/evidence/curse-spirit-concept-v1/fluchgeist-konzept-v1.png`.
Der exakte ursprüngliche Imagegen-Prompt und Herkunftsbeleg liegen daneben.
Der Nutzer hat diese konkrete Tafel anschließend mit „Bau das mal bitte.
Genau so“ zur Übernahme freigegeben.

`scripts/import_curse_spirit_rig.gd` schneidet Kopf, Fangkiefer, Kern, zwei
Klauen und drei Schweifglieder aus der rechten Explosionsansicht aus. Die
Farbauswahl entfernt den Tafelhintergrund; Nearest-Skalierung, harte Alpha und
eine dunkle Pixelkontur ergeben acht native 32×44-Ebenen. `bind.png` ist die
zusammengesetzte Kontrollansicht, kein zusätzlicher Animationstrack.

`assets/data/curse_spirit_rig.json` und `src/rig/curse_spirit_rig.gd` verwenden
das bestehende RigLibrary/RigRenderer-System mit kontinuierlichen Gelenkposen.
Keine Seelengeistgrafik wurde umgefärbt oder wiederverwendet. Kein weiterer
Bildgenerierungsaufruf; ursprüngliche Spielgrafiken und Lizenzen bleiben erhalten.

Reproduktion: Godot `--headless --path . --script scripts/import_curse_spirit_rig.gd`.
Kontrolle: `tests/curse_spirit_rig_test.gd`, 25 Prüfungen bestanden.

Die große freundliche Kampfform `curse_colossus` verwendet dieselben acht
Texturen und Gelenke ohne Bildänderung. `src/rig/curse_monster_rig.gd` ergänzt
getrennte Klauenangriffe, langsame Fangkiefer-/Schweifbewegung, Auftauchen und
Körperteil-HP im gemeinsamen Begleiter-Renderer. Native 3×-Darstellung in der
Krypta; kein neuer Generierungsaufruf und kein Seelenwächter als Ersatzgrafik.
