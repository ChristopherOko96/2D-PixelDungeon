# Fluch-Ulti: Giftgrube → Dienertod → Fluchkoloss

Nutzerauftrag: Die Ulti des Fluch-Builds bleibt eine Giftpfütze. Sterben die
eigenen Diener darin, soll daraus ein großes Fluchmonster erscheinen.

## Implementierte Regel

R platziert weiterhin die echte vorhandene Giftgrube mit Verfall/Schwächung.
Gegner-Tote darin erzeugen weiterhin begrenzte Skelettläufer. Der erste eigene
Dienertod innerhalb der noch aktiven realen Ultimate-Giftquelle manifestiert
genau einen freundlichen Fluchkoloss am Pfützenzentrum. Tatsächlicher Tod,
Laufzeitende und Selbstexplosion eines Läufers zählen. Fremde Diener, Tode
außerhalb/hinter einer Wand, verzehrte oder abgelaufene Quellen zählen nicht.
Jeder Diener wird einmal verarbeitet; jede Pfütze manifestiert einmal und
gleichzeitig lebt höchstens ein Fluchkoloss pro Besitzer. Der Koloss selbst
und sein Ablauf erzeugen keinen Nachfolger. Raumwechsel entfernt ihn.

Der Koloss kämpft selbstständig zwölf Sekunden, mit 40 Grundleben, 90 %
Heldengrundschaden alle 1,4 Sekunden und 2 m Flächenangriffen. Werte unter
`necromancer_rules.json → curse.ultimate_monster` (Schema 6): `time` Sekunden,
`hp`, `damage` als Grundschadenanteil, `every` Sekunden, `cleave_m`, `speed`
als Begleitergeschwindigkeitsfaktor, `art_scale` als Rig-Größenfaktor.
Die vorhandenen Ultimate-Aufwertungen ändern weiter Feldgröße/-dauer;
Seelenkosten und Abklingzeit bleiben erhalten. Regelsatz 22, Protokoll 4.

## Vorhandenes Rig und Quellen

`src/rig/curse_monster_rig.gd` registriert die acht bereits freigegebenen
Fluchgeist-Teile als Kampfrig mit Körperteil-HP im bestehenden RigLibrary /
RigRenderer / BodyParts / CompanionRigs-Weg. Native 3×-Darstellung in der
Krypta, langsamer Fangkiefer, zwei unabhängig schlagende Klauen, verzögerter
dreigliedriger Schweif und Auftauchen aus dem bestehenden Feld. Bestehende
Verfolgung/Wandnavigation und Todeszerfall. Keine neue Bildgenerierung,
kein Seelenwächter und keine zweite übermalte Giftfläche.

Ein eigener Kaltstartcheck stellt sicher, dass ein Client das Monster auch
ohne vorher sichtbaren anderen Begleiter darstellen kann. Die Texturen werden
einmalig registriert, nicht pro Bild ausgeschnitten oder neu erzeugt.

## Tatsächliche Prüfungen

| Prüfung | Ergebnis | Log |
| --- | --- | --- |
| Reale Todes-/Ablauf-/Selbstexplosionspfade und Grenzen | 29/0 | Logs/curse-ultimate-monster-green.log |
| Körperteil-Rig, kontinuierliche Posen, Client-Kaltstart | 30/0 | Logs/curse-monster-rig-final.log |
| Tatsächliche Hölle/Frost einschließlich neuer Beschwörung | 42/0 | Logs/curse-monster-story.log |
| Vorhandene Fluchangriffe, Läufer und Blutstrahl | 19/0 | Logs/curse-monster-regression.log |
| Vorhandene Begleiterregeln | 42/0 | Logs/curse-monster-companions.log |
| Sitzungsprüfung | 20/0 | Logs/curse-monster-protocol.log |

Vor der Umsetzung zeigte der neue tatsächliche Kampftest vier erwartete
Fehlschläge (`curse-ultimate-monster-red.log`). Der zusätzliche Client-
Kaltstarttest wurde ebenfalls zuerst fehlschlagen gesehen (1/30,
`curse-monster-cold-client-red.log`); danach 30/0. Abschließende Läufe ohne
SCRIPT ERROR/Assertions. Bekannte Game-Fixture-Aufräumdiagnosen (6 ObjectDB,
2 Ressourcen) bleiben beim Beenden dokumentiert.

Zwei tatsächliche lokale ENet-Prozesse bestanden auf Host und Client mit
`curse_monster=true`: `Logs/necro-blood/20261101-230816-cd4fb3bc/summary.json`.
Der Client nutzt normale validierte R-Eingabe; der Host löst einen vorbereiteten
Gegnertod innerhalb der realen Giftgrube aus. Der daraus entstehende Läufer
explodiert im Feld und ruft den Koloss. Blutaufnahme, Form, Befehle, Mehrfach-
Blutstrahl und Todesflüche bleiben im selben Lauf geprüft. Loopback, keine
LAN-/WAN-/Leistungsabnahme und kein erspielter Kampagnendurchlauf.

## Scharfe Vorschau

Alle drei Ultimate-Stufen wurden mit `capture_necromancer_catalog.gd -- --hq
--curse-ultimates` im tatsächlichen GPU-Renderer neu aufgenommen. Je 182
verlustfreie 640×360-PNGs bei 30 Bildern/s, unverkleinerter Viewport-Ausschnitt;
der Diener stirbt durch seine echte Kontakt-/Explosionslogik.
`Logs/curse-monster-hq-capture.log`; Frames unter
`production/qa/evidence/necromancer-catalog-hq/curse_14*`.

Native APNG: `output/necromancer-catalog/fluchkoloss-original.png`.
Die gemeinsame Auswahl (`Nekromant-Angriffe.cmd`) und ihre scharfen Standbilder
zeigen den neuen Ablauf und die aktualisierten Regeln. Im tatsächlichen Browser
sind alle 38 Auswahlen, Play/Pause/Einzelbild und Originalpixel erneut geprüft.
Die vorbereiteten Builds/Gegner/Startressourcen sind Präsentationsfixtures,
keine neue Balance-, Kampagnen- oder Nutzerabnahme. Kein Commit/Push/Merge.
