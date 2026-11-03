# Seelenring: 5 m Durchmesser, Feld nur außen

31.10.–01.11.2026. Nutzer bestätigt 5 m Gesamtdurchmesser und die Beibehaltung
der zuvor angenommenen Feld-/Schweif-VFX. Godot 4.7.2 / Compatibility.

## Beobachtetes Ergebnis

Normales `soul_3` (jetzt Seelenring): bisheriger einmaliger Novaschaden,
sechs Rig-Geister laufen nach außen. Nach 0,65 s bleibt ein 4 s aktiver Saum
mit Außenradius 80 px und Innenradius 56 px. Nur der Saum erhält das gemeinsame
Seelenmaterial und Festhalte-Geister. Keine zusätzliche DoT-Schadensquelle.
22 Seelen und 11 s Abklingzeit bleiben. Der Ring bleibt am Auslöseort.

`scripts/capture_soul_ring.gd` rendert das echte Game in der aktuellen Krypta.
Kontrollierter gültiger Level-30-Build mit Ring auf 2 und drei Testgegnern.
Echter 50-Seelen-Start, kein Auffüllen der Ressource. Ein normaler Taste-2-
Befehl, echte Gegner-KI/Treffer/Status und späteres Weggehen des Spielers.
181 GPU-Bilder in 2×1/60-s-Schritten, 6 s Simulation. Ausgewählte rohe
1280×720-Bilder hier. Ab Bild 20 (0,667 s) aktiver Saum; Bild 140 (4,667 s)
hat keinen aktiven Saum mehr. Kontrollierte Begegnung, kein erspielter Lauf.

`--arena-only` öffnet den echten Testraum, wählt Nekromant/Seele, prüft das
gültige Preset (Ring 2, gesetztes Feld 4, Wächter R), löst Taste 2 aus und
speichert `testraum-ring.png`. Keine UI-Nachbildung und kein Build-Validator-
Bypass. Sichtprüfung: freier Boden innen, echtes äußeres Material, lesbare
Rig-Geister und die normalen Slots. Welt-/Actor-/Terrain-Sprites bleiben.

`output/soul-ring/game-preview.gif`: 181 Bilder, Ausschnitt 480×480, 30 FPS
mit 3/3/4-centisekündiger Taktung. Nach dem Kodieren alle Bilder dekodiert.
GIF-256-Farbenpalette ist Vorschau; PNGs bleiben exakt. Rebuild mit Windows
PowerShell und `output/soul-ring/assemble_game_preview.ps1`.

## Fokussierte Checks

| Suite | Checks | Fehler |
|---|---:|---:|
| soul_ring_test | 19 | 0 |
| soul_ring_shape_test | 18 | 0 |
| talent_combat_test | 361 | 0 |
| hell_talents_test | 36 | 0 |
| session_protocol_test | 20 | 0 |
| snapshot_interpolation_test | 57 | 0 |
| soul_particles_test | 41 | 0 |
| soul_guardian_rig_test | 58 | 0 |
| soul_guardian_test | 51 | 0 |
| necro_souls_aggro_test | 60 | 0 |
| Summe | 721 | 0 |

Ring-spezifisch: richtige Kosten/CD und Durchmesser, kein Feld vor Ankunft der
Welle, leerer Innenbereich, Kontakt nur am Saum, Snapshot-Innenradius, keine
Schadensvervielfachung, Standort bleibt fest, Ablauf, Boss-Immunität, gemeinsame
Betäubungssperre, Ursprung der Geister im Saum, Wandprüfung, Raumwechsel.
Materialzellen bei Artgröße 2 und 3 vollständig innerhalb des 80/56-px-Rings;
kein Pixel im Loch. PoolPaint-Arbeiter, Cache-Wiederverwendung und sechs
Rig-Geister am tatsächlichen Saum sind geprüft.

Zusätzliche gemeinsame Begleiterprüfung: Der neue Ringsaum wird bei der
Zielwahl berücksichtigt und das bisherige gesetzte Seelenfeld bleibt auch
ohne reines Präsentationsfeld `look` erkannt. Der vorhandene Wächtertest wurde
bei dieser zwischenzeitlichen Regression beobachtet (`guardian-preference-before.log`),
danach die alte Talent-ID-Erkennung erhalten und der neue Ringfall ergänzt.
Aktuelle Wächter-/Aggro- und Ringprüfungen bestehen gemeinsam.

Die erste GPU-Aufnahme zeigte einzelne degenerierte Clip-Polygone während
der auslaufenden Geisterwelle. Der neue reproduzierende Test wurde vor dem Fix
beim Fehlschlagen beobachtet: `clipping-before.log`. Der gemeinsame Rig-
Renderer bereinigt doppelte/gerade Boden-Ecken vor der Triangulation. Komplett
kollabierte Clips bleiben unsichtbar. Aktuelle GPU-Aufnahme ohne Triangulations-
oder SCRIPT ERROR. Kein bloßes Ignorieren des Prozess-Exitcodes.

## Zwei reale lokale Prozesse

`tests/soul_ring_network_smoke.ps1` / `soul_ring_network_peer.gd`: echter ENet-
Host und Client, zugelassen mit **Regelversion 11 / Protokoll 4**. Beide senden
normale Skill-Inputs für ihr gelerntes Talent. Je ein Ring pro Besitzer trotz
gehaltener Eingabe; beide Empfänger sehen die gleichen 80/56-px-Grenzen,
Besitzer, aktiven Zeiten, echten Novaschaden und die Entfernung nach Ablauf.
Zusammenfassung: `network-summary.json`; Originale:
`Logs/soul-ring/20261031-235304-901b6510/summary.json`. 2 Prozesse bestanden.
Nur lokales Loopback mit kontrolliertem Aufbau, kein LAN-/WAN-/Lasttest.

Die bekannte Sandbox-Diagnostik zu user://-Log/Shadercache bleibt. Das Game-
Fixture meldet wie vorher sechs ObjectDB-Instanzen/zwei Ressourcen beim Ende;
kein sauberer Prozessabbau behauptet. Keine neue vollständige Kampagnen-,
Vier-Spieler-, Leistungs- oder Langzeitbalanceabnahme. Nutzer beurteilt Gefühl.
Quellen/Schema/Bedienung: `docs/NEKROMANT-SEELENRING.de.md`. `stamp.json`
enthält SHA256 der wesentlichen Quellen dieser aktuellen Beobachtung.
