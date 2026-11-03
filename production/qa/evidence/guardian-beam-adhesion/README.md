# Seelenwächter: haftender, tatsächlich geriggter Seelenstrahl

Nutzerauftrag: die Strahlfähigkeit des beschworenen Seelenmonsters soll das
vorhandene Rig-System verwenden, flüssiger animiert sein und am Gegner haften.

## Umsetzung

Host wählt den ersten sichtbaren Gegner auf der anfänglichen Schusslinie bis
8 m; danach stabile ID und laufend aktualisierte Richtung/Endposition.
Tod, Wand, Reichweitenverlust oder Besitzerende stoppen Schaden/Verbindung.
Nach Abbruch keine neue Bindung im selben Kanal. Eingabe/Maus dürfen die
Bindung nicht ersetzen; Schaden/Markierung bleiben vollständig host-owned.
Vorbereitung, Kanalzeit, Takt und Befehls-Abklingzeit wurden nicht erhöht.
Regelsatz 21, Protokoll 4; neue Snapshotfelder sind primitive Darstellung.

Zwei echte 24-Gelenk-Ketten aus vorhandenen freigegebenen Wächter-Schwanzpixeln,
parent-local affine Posen und bestehender RigRenderer.solve_pose. Enden an der
animierten Hand und dem dargestellten Körper-Rig des Zielgegners. Langsame
Wellen im Inneren, separat geriggte kleine Seelengeister im Strom und am Ziel,
sichtbare Hand-/Armvorbereitung. Keine neue Bildgenerierung oder Atlasersetzung.

## Tatsächliche Verifikation

| Prüfung | Ergebnis | Log |
| --- | --- | --- |
| Neue Gegnerbindung und Abbruch | 16/0 | Logs/guardian-adhesion-green.log |
| 48 tatsächliche Rig-Gelenke, feste Enden, 60-Hz-Kontinuität, Cache | 301/0 | Logs/guardian-beam-rig.log |
| Bestehende 5/6-Befehle, Konvertierung, Grenzen | 27/0 | Logs/guardian-beam-commands.log |
| Wächter-Posen/Zeiten und bisherige Kurvenhelfer | 1522/0 | Logs/guardian-beam-visual.log |
| Tatsächliche Hölle/Frost-Adapter mit bewegtem Strahlziel | 30/0 | Logs/guardian-beam-story-final.log |
| Sitzungsregeln | 20/0 | Logs/guardian-beam-protocol.log |

Der neue Bindungstest wurde zuerst gegen den alten Code ausgeführt:
**10 erwartete Fehlschläge** bei 16 Checks (`Logs/guardian-adhesion-red.log`).
Danach 16/0. Die bestehenden Game-Fixtures melden weiter ihre bekannten
6 ObjectDB-/2 Ressourcen-Aufräumdiagnosen beim Beenden. Keine SCRIPT ERROR
oder Assertions in den abschließenden Läufen.

Zwei tatsächliche lokale ENet-Prozesse bestanden:
`Logs/guardian-commands/20261101-225154-1743d722/summary.json`.
Host und Client beobachteten bewegte angeheftete Enden (`beam_followed=true`),
bezahlte Beschwörung, Schaden, Seelenmal, Untergebene, Befehle und Ablauf.
Loopback und kontrollierte Begegnung, keine LAN-/WAN-/Leistungsabnahme.

## Originalaufnahme

Nur `guardian_beam` wurde mit `capture_necromancer_catalog.gd -- --hq --only
guardian_beam` neu aufgenommen: 122 PNGs in 640×360, 30 Bilder/s, unverkleinert.
Ein Gegner bewegt sich absichtlich quer zur ursprünglichen Strahlrichtung.
Echte Host-Kampfberechnung und GPU-Darstellung, kein erfundener Vorschauzeichner.
Kontrollierte Gegner/Builds/Startressourcen; kein verdienter Kampagnendurchlauf.
Log: `Logs/guardian-beam-hq-capture.log`; Frames:
`production/qa/evidence/necromancer-catalog-hq/guardian_beam/`.

Verlustfreie Animation: `output/necromancer-catalog/waechterstrahl-original.png`.
Gemeinsame lokale Ansicht `output/necromancer-catalog/nekromant-original.html`;
`#guardian_beam` öffnet direkt den aktualisierten Strahl. Die 38 Aufnahmen und
Pausen-/Einzelbildsteuerung wurden im tatsächlichen Browser erneut geprüft.
Inline-Bildauswahl und Originalbilder wurden ebenfalls aktualisiert. Kein
neuer Bildkompressionsverlust, keine neue breite Kampagne, kein Commit/Push/Merge.
