# Seelenwaechter: Implementierung und Nachweise

31.10.2026. Konkrete Stilprobe vom Nutzer freigegeben; danach ausdruecklicher
Auftrag zu Animation und Spielintegration. Seele-Ultimate `soul_14` ersetzt
Seelenernte. Keine Commits/Pushes/Merges. Branch `codex/port-0x72-onto-main`.

## Aktueller Umfang

Vier Clips: Erscheinen, Schweben, Greifen, Aufloesen. 32 Timeline-Keys mit
31 unabhaengigen sichtbaren Posen und einem bewusst gehaltenen Impact-Key.
Rechts gezeichnet, links gespiegelt; keine vier separat gezeichneten Ansichten.
18 Farben, harte Alpha, nearest. Benachbarte Keys zeitlich ueberblendet;
Texturen/Spiegelungen werden einmal vorbereitet.

Host berechnet Bewegung, Ziele, Treffer, Wand/Kegel/Reichweite, gemeinsame
CC-Sperre mit dem Feld, Besitzerzustand und Ablauf. 12 s Dauer, 40 Mana,
60 s Reload. Stufe 2: +4 s; Stufe 3: Welle 100 % bis 5 m. Kein neuer
Lebensbalken, kein eigener schadensberechnender Client. Gespeicherte
Freischaltung/Stufen bleiben durch dieselbe Talent-ID erhalten.

Das echte Testraum-Preset war ueberfuellt; die normale Buildpruefung entfernte
deshalb die Ultimate. Es verteilt jetzt legale Level-30-Punkte. Alle zwoelf
Spezialisierungen behalten ihre Ultimate, Hostvalidierung unveraendert.
Seele: 1 Seelenblitz, 2 Seelenpanzer, 3 Seelenlanze, 4 Seelensturm, R Waechter.

Datenfelder, Werte, Testweg: `docs/NEKROMANT-SEELENWAECHTER.de.md`.
Quellen/Prompt/Import: `assets/vfx/soul_guardian/PROVENANCE.md`.

## Gezielte Checks

| Suite | Checks | Fehler |
|---|---:|---:|
| soul_guardian_test | 51 | 0 |
| talent_combat_test | 361 | 0 |
| soul_guardian_art_test | 93 | 0 |
| soul_field_test | 79 | 0 |
| soul_detail_test | 91 | 0 |
| hell_talents_test (beide Welten) | 30 | 0 |
| snapshot_interpolation_test | 57 | 0 |
| session_protocol_test | 20 | 0 |
| Gesamt | 782 | 0 |

Aufruf jeweils `--headless --path . --script tests/<suite>.gd`.
Ausgaben in `logs/`; zusaetzliche Engine-Logs unter
`output/necromancer-soul-guardian-v1/`.

Geprueft: echter verzoegerter Schaden/Ownercredit, keine Sofort-Ernte,
Kosten/Reload, keine doppelten Geister, Aufloesen ohne Treffer, Ziele/Feld,
Wand/Kegel/Reichweite, Bossimmunitaet, gemeinsame CC-Sperre,
Tod/Raumwechsel/Neustart, Stufen, Snapshotkopien, clientseitige Positionen,
native Pixel und Texturcache. Transparente RGB werden vor dem Zaehlen der
sichtbaren Posen normalisiert; keine unsichtbaren Uniqueness-Marker.

Vor den Korrekturen beobachtet und erhalten:
- Erster Featuretest gegen die alte Ultimate: 1 Check, 1 Fehler (Werkzeugausgabe).
- `cleanup-before.log`: Cast-/Wellen-VFX blieben nach Raumwechsel zurueck.
- `arena-before.log`: echtes Testraum-Preset konnte Ultimate nicht behalten.
- Interpolation zuerst 57/1, nach Integration 57/0.

## Zwei echte Prozesse

`./tests/soul_guardian_network_smoke.ps1`: lokaler ENet-Host und separater Client,
Aufnahmepruefung Protokoll 4 / Regeln 9. Beide nutzen den normalen R-Input/RPC-Weg.
Zwei Besitzer, hoechstens zwei Waechter bei gehaltenem R, alle vier Phasen,
Host-Schaden/Welle und Ablauf auf beiden Seiten beobachtet.

Erfolgreicher Lauf `Logs/soul-guardian/20261031-181458-f6ff6701/summary.json`;
Resultate/Prozessausgaben hier unter `network/`. Vorheriger erfolgreicher Lauf:
`20261031-180506-b2d8dd1f`. Spaetere Raum-VFX-/Testraum-Korrektur ist im aktuellen
51-Check-Test enthalten und aendert keinen Transport.

Erhaltene Fehlversuche: `180108-085eae77` ohne UDP-Verbindung in der Sandbox;
`180254-d5ee3d4f` fiel korrekt wegen fehlender template_id der synthetischen
Raumfixture trotz bestandener Spielassertions durch. Danach vollstaendige
Fixture ohne Scriptfehler. `181250-fb8c4b36` erreichte beim parallelen GPU-/
Spieltest das 12-s-Host-Startlimit; kein Spielnachweis. Startreserve jetzt 30 s,
final separat erfolgreich wiederholt. Keine Performanceanforderung gelockert.

## GPU-Beobachtung

`scripts/capture_soul_guardian.gd`: echter Compatibility-Spielrenderer,
1280x720, kontrollierter legaler Build und erreichbare Gegner mit echter KI.
Feste Simulationsschritte, keine erspielte Kampagne oder FPS-Messung.

- `guardian-000/003/008.png`: Erscheinen und vollstaendiger Geist.
- `guardian-013.png`: echter Griff/Trefferfeedback.
- `guardian-030/062.png`: Geist und Feld im Kampf.
- `guardian-wave.png`: Wellenzeitpunkt im Feldkampf.
- `guardian-135/140/143.png`: Aufloesen in Partikel.
- `guardian-146/152.png`: nach Ablauf kein Geist mehr.
- `testraum-seele.png`: realer start_test_arena-Aufruf, echte UI und R/4-Preset.

153 rohe GPU-Frames: `output/necromancer-soul-guardian-v1/game-frames/`.
Animierter 400x400-Ausschnitt: dort `game-preview.gif`, ca. 12,7 s. Alle 153
GIF-Frames vollstaendig dekodiert, PNGs und eine GIF-Dekodierung angesehen.
Die erste GPU-Fixture hatte Gegner im unbetretbaren Nachbarbereich; sie war
kein Kampfnachweis. Finale Fixture prueft Erreichbarkeit vor dem Start.

Bekannte schon im roten Ausgangstest vorhandene Exit-Diagnostik: sechs
ObjectDB-Instanzen/zwei Ressourcen bei Game-Fixtures. Sandbox ausserdem
user://-Log-/Shadercache-Schreibrechte. Kein SCRIPT ERROR im finalen Lauf.
Dies wird nicht als diagnostisch voellig fehlerfreier Exit oder Leaktest gewertet.

Kein neuer Vier-Spieler-, LAN/WAN-, Vollrun- oder Leistungstest.
Spielgefuehl/Timing und langfristige Balance brauchen persoenliches Feedback.
