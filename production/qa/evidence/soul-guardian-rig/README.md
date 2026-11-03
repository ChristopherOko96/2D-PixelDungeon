# Seelenwächter: echtes Cutout-Rig

31.10.2026, Godot 4.7.2 standard / Compatibility, lokaler Windows-Rechner.
Auftrag: das bestehende Skelett-Rig auf den freigegebenen Seelenwächter anwenden.
Keine neue Kunstgeneration, keine Kampf-/Ressourcen-/Netzwerkregeländerung.

## Implementierung

Neun transparente Teile aus dem ersten Hover-Key des genehmigten Atlas:
Kopf, Rumpf, zwei Arme, zwei Hände, drei Schweifglieder. RigLibrary lädt sie;
RigRenderer löst dieselben Eltern-/Pivot-Transformationen wie bei Skeletten.
Kontinuierliche Bewegungen statt überblendeter Ganzkörperbilder. Unterlappende
Originalpixel schließen Gelenke. Gemeinsame Boden-Sichtgrenze begrenzt auch
gespiegelte und gestreckte Arme an Wänden. Die Staubaura läuft weiter.

Daten/Rebuild/Schema: `docs/NEKROMANT-SEELENWAECHTER.de.md` und
`assets/vfx/soul_guardian/PROVENANCE.md`.

## Fokussierte Prüfungen

| Suite | Prüfungen | Fehler |
|---|---:|---:|
| soul_guardian_rig_test | 58 | 0 |
| soul_guardian_art_test | 93 | 0 |
| soul_motion_test | 54 | 0 |
| rig_library_test | 163 | 0 |
| hell_rig_renderer_test | 73 | 0 |
| soul_guardian_test | 51 | 0 |
| Summe dieser sechs Suites | 492 | 0 |

Rig-Prüfungen: Originalpixel je Cutout, vollständige neutrale Rekonstruktion,
alle neun Teile ändern sich zwischen 60-Hz-Zeitpunkten, Hand bleibt am bewegten
Arm, Spiegelung und 3×-Skalierung, Reichweite am echten Trefferzeitpunkt,
Rückkehr zur Ruhepose, Phasenwechsel ohne Neustart des Schwebens, Anfang/Ende,
Cache-Wiederverwendung und Wandgrenze in beiden Richtungen.

Zusätzlich ausgeführt: `rig_variants_test`, 598 Prüfungen / **2 Fehler**. Dieser
historische Kandidatentest erwartet weiterhin genau 15 aktive Rigs und einen
noch nicht aktiven `frost_necro`. Der aktuelle Bestand hat bereits mehr Rigs
und enthält diesen Frostgegner. Kontrolllauf mit dem **unveränderten Renderer
aus HEAD** meldet exakt dieselben beiden Fehler; siehe `rig_variants_baseline.log`.
`assets/data/rigs.json` blieb unverändert (SHA256
`9D21C01C1F016AFF1E5756F93ED9B4C54057C6D77504D41D4E49DCE806DABD6C`).
Keine Anpassung dieses alten Kandidaten-Gates im Rahmen der Geist-Animation.

Import/Spielausgabe auf SCRIPT ERROR geprüft. Bekannte Sandbox-Diagnostik:
user://-Log/Shadercache nicht schreibbar. Das bestehende Game-Fixture meldet
beim Ende weiterhin sechs ObjectDB-Instanzen/zwei Ressourcen in Benutzung.
Kein sauberer Prozessabbau behauptet.

## Beobachtete GPU-Darstellung

`scripts/capture_soul_guardian_rig.gd` lädt das echte Game mit kontrolliertem
Level-30-Build, explizit gefülltem Ressourcenvorrat und drei Testgegnern.
Normaler R-Befehl beschwört den Wächter. Echte Gegner-KI, Treffer und normales
Seelenfeld ab 2,5 s; der Besitzer bewegt sich weg. Wächter erscheint, schwebt,
greift an, kämpft weiter und endet nach seiner bestehenden Dauer. Kein erspielter
Lauf. 381 gerenderte Bilder, jeweils 2×1/60 s Simulationszeit, insgesamt 12,667 s.
Bild 365 bei 12,167 s hat keinen aktiven Wächter mehr. Ausgewählte rohe
1280×720-GPU-Bilder sind hier erhalten, alle Bilder liegen in
`output/soul-guardian-rig/game-frames/`.

`output/soul-guardian-rig/game-preview.gif`: Ausschnitt 480×480, 381 Bilder,
30 FPS mit 3/3/4-centisekündiger GIF-Taktung; alle Bilder nach Kodierung dekodiert.
GIF hat eine quantisierte 256-Farben-Vorschaupalette, rohe PNGs bleiben exakt.
Rebuild: Windows PowerShell mit
`output/soul-guardian-rig/assemble_game_preview.ps1`.

Statische Sichtprüfung der Spielbilder 33, 155 und 350: Greifen, Feldkombination,
gespiegeltes Auflösen. Keine offenen Gelenke oder doppelten Augen beobachtet.
Persönliche Bewegungsabnahme bleibt beim Nutzer. Keine neue LAN-/WAN-/Vier-
Spieler-/FPS- oder vollständige Kampagnenaussage; keine neuen Snapshotfelder.

Wiederholen: Godot `--headless --path . --script tests/<suite>.gd`; für die GPU-
Aufnahme `--path . --script scripts/capture_soul_guardian_rig.gd` ohne headless.
