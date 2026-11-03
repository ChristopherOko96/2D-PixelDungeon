# Schattensprung — 01.11.2026

Aktuell umgesetzt: [Regeln und Testschritte](../../../../docs/NEKROMANT-SCHATTENSPRUNG.de.md).
Arbeitsbranch `codex/port-0x72-onto-main`; kein Commit/Push/Merge dieser Revision.

## Tatsächlich beobachtet

`scripts/capture_soul_leap.gd`: normaler GPU-Spielrenderer, legaler Seele-Build,
kontrollierte offene Begegnung. 241 Bilder mit 30 simulierten Bildern/s über
acht Sekunden. Sprung, kurze normale Bewegung vom Spurende weg, dann Ring.
Die 50 Startseelen werden regulär verbraucht; kein Ressourcen-Refill.
Der Test-God-Flag verhindert Schäden, ohne die Figur als unverwundbar blinken
zu lassen. Kein erspielter Lauf oder Leistungstest.

Standbilder `soul-*.png` hier; alle Rohbilder unter `output/soul-leap/game-frames/`.
`output/soul-leap/game-preview.gif` ist der 960×530-Ausschnitt dieser Aufnahme.
Der GIF-Assembler dekodiert alle 241 Bilder erneut. Visuell geprüft: vorhandene
Kutte/Kapuze als tatsächlicher Heldenrig, geneigte/zusammengezogene Kutte,
mitbewegter Stab, Sprungbogen und Bodenschatten, zusammenhängende Seelenspur
mit Geister-Rigs, Ringmaterial und Ablauf. Keine neu erzeugten Actorbilder.

Ein erster Bildcheck zeigte, dass der spielbare Nekromant zuvor im Sprite-
Fallback blieb: `CLASS_RIGS` enthielt nur Ritter, Bogenschütze und Magier.
Das vorhandene `necro`-Rig verwendet exakt dieselbe 0x72-Quellgrafik. Es wurde
für den Helden in Krypta und Storywelten angebunden; der extra Waffenlayer
bleibt am bestehenden Heldenstab, keine zweite NPC-Waffe.

## Prüfungen

- Schattensprung 13/0: reale Auflade-/Flugphase, Rang-3-Reichweite, primitive
  Rig-Daten, schmale Spur/CC/Ablauf, Raumwechsel, Wand und tatsächlicher
  Kollisionsradius, fünf Sekunden Ring/Feld, aktiver Nekromantenrig.
- Bestehender Talentkampf 361/0, Ring 19/0, Seelenangriffe 41/0,
  echte Storyadapter einschließlich Sprung/Positionsrückgabe 22/0, Ringgeometrie 18/0,
  Wächterbefehle 26/0.
- Wächter/Testpreset 52/0: aktueller Seele-Fokusplatz 3 ist Schattensprung.

Neue Sprung-/Dauerfälle wurden zuerst fehlschlagend geprüft. Der zusätzliche
Held-Rig-Test wurde vor Anbindung fehlschlagend beobachtet. Eine frühe Wand-
Fixture nahm fälschlich 14 px statt der tatsächlichen 12 px Spielerradius an;
die Grenze liest jetzt den autoritativen Wert, ohne die Wandprüfung zu lockern.

## Zwei echte Spielprozesse

`tests/soul_leap_network_smoke.ps1` bestand über lokales ENet mit zwei regulär
zugelassenen Spielern, Regeln 15/Protokoll 4. Beide Prozesse beobachteten die
vorherige Lanzenaufladung, geladenes Geschoss, Einschlag, große fünfsekündige
Ringe sowie Held-Sprungfortschritt und schmale fünfsekündige Seelenspuren.
Ergebnis: `Logs/soul-leap/20261101-141523-f45759a0/summary.json`.

Die Netzwerkfixture setzt am Anfang auf dem Host volle Seelen, um mehrere
Fähigkeiten hintereinander prüfen zu können; die normalen Kosten bleiben aktiv.
Ein erster zusätzlicher Sprung lag noch im globalen Cooldown nach der Lanze
und wurde korrekt abgewiesen; die Fixture wartet jetzt den Cooldown ab.

Loopback und kontrollierte Testkämpfe sind keine LAN-/WAN-/Vier-Spieler-/
Kampagnen- oder Leistungsmessung. Nutzerabnahme von Aussehen und Spielgefühl
bleibt offen. Vorhandene sechs ObjectDB-/zwei Ressourcen-Diagnosen beim Ende
der Game-Fixtures und die Sandbox-Shadercache-Warnung sind weiter sichtbar.

## Nächster Zweig

Der bestätigte Blut-/Fluch-Schwerpunkt ist als konkreter, noch nicht aktivierter
[Entwurf](../../../../docs/NEKROMANT-BLUTFLUCH-ENTWURF.de.md) festgehalten.
