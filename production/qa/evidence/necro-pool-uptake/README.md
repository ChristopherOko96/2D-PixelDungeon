# Sichtbare Blutlache und geriggte Aufnahme

01.11.2026, `codex/port-0x72-onto-main`, Godot 4.7.2 Compatibility.
Nutzerkorrektur: Die vorhandene echte Blutpfütze soll nach dem markierten Tod
zuerst liegen bleiben. Anschließend sollen Blutpartikel aus dieser Lache in
den Knochenkrieger wandern.

## Umsetzung

- Die echte `PoolPaint`-Blutlache bleibt erhalten. Zu Beginn der Aufnahme
  liegen 0,65 Sekunden zwischen Kontakt und dem ersten Blutgewinn. Die
  Pfütze wird erst nach Aufnahme ihres endlichen Inhalts beendet.
- Eine lokale Host-Reservierung bindet einen lebenden Krieger an genau die
  vorhandene Quelle. Ihr restlicher Inhalt bleibt am Quellobjekt; ein Abbruch
  erzeugt keine neue volle 25-Blut-Portion. Eine zweite Figur kann dieselbe
  Quelle nicht gleichzeitig abrechnen.
- Tod, Raumwechsel, Wand, zu große Entfernung, Ablauf, Materialwechsel und
  tatsächliche Entfernung der Quelle beenden Blutgewinn und Partikelstrom.
  Bereits eingezogenes Blut bleibt im Balken; tatsächlicher Rest bleibt in
  der vorhandenen Pfütze. Referenzen werden nur lokal gehalten, nie im RPC.
- 14 kleine Blutpartikel verwenden vorhandene Blut-Spriteausschnitte und den
  bestehenden `RigRenderer.solve_pose`. Sie starten an Punkten der tatsächlichen
  Oberfläche und fliegen auf gekrümmten Bahnen in den aktuellen Torso-Sockel.
  Anlauf, einzelne Tropfen und Auslauf blenden weich. Kein starrer Strahl für
  diese Aufnahme; der separate Blutstrahl bleibt unverändert.
- Die vorhandene Pfützenoberfläche erhält kleine `PoolPaint.ripple`-Impulse.
  Keine neue flache Ersatzfläche, kein zusätzlicher Ring, keine neu generierten
  Spritebilder. Der ursprüngliche Blutpfützen-Painter zeichnet weiterhin den Boden.

Regelsatz **19**, Protokoll **4**, Nekromantenregelschema **4**.
`blood.form_before_pull_s` und `blood.pull_radius_m` konfigurieren Vorlauf
und maximale Verbindung vom Pfützenrand. Darstellung unter
`necro_spell_rigs.json → motion.absorption`: Anzahl, Flugzeit, Aufstieg,
Verteilung, Größe und Flüssigkeitsimpulse. Seelenkosten, Ulti-Schwelle,
Bogenschützen und vorhandene Rigs bleiben nach dem vorigen Diener-Umbau erhalten.

## Prüfungen

| Test | Ergebnis | Log |
| --- | --- | --- |
| `necro_pool_absorption_test.gd` | 12 / 0 | `Logs/necro-absorb-green.log` |
| `necro_spell_rig_test.gd` | 46 / 0 | `Logs/necro-absorb-rig.log` |
| `necro_blood_curse_test.gd` | 39 / 0 | `Logs/necro-absorb-core.log` |
| `necro_blood_cycle_test.gd` | 25 / 0 | `Logs/necro-absorb-cycle.log` |
| `necro_branches_story_test.gd` | 34 / 0 | `Logs/necro-absorb-story.log` |
| `session_protocol_test.gd` | 20 / 0 | `Logs/necro-absorb-protocol.log` |

Vor der Änderung meldete `Logs/necro-absorb-red.log` acht fehlgeschlagene
Anforderungen: sofort entfernte Quelle, fehlende sichtbare Phase, verwaiste
Aufnahme und doppelter Restinhalt. Anschließend wurde die tatsächliche
Entfernung aus der Medienliste gesondert nachgestellt: Der Test in
`Logs/necro-absorb-removed-red.log` scheiterte zunächst mit einer veralteten
Quellreferenz und besteht nach der Identitätsprüfung der echten Medienliste.
Der aktuelle Test prüft auch Abbruch bei Tod und Ablauf, Raumwechsel,
Teilaufnahme, Wiederbeschwörung und zwei Krieger an derselben Quelle.

Die Rigprüfung kontrolliert zusätzlich Ursprung, gekrümmten Aufstieg und
exaktes Ende der Tropfenbahn am Körper-Sockel. Die vorhandenen Ausschnitt- und
Gelenkprüfungen bleiben enthalten.

Erfolgreiche Logs sind auf `SCRIPT ERROR` und fehlgeschlagene Assertions
geprüft. Die bisherigen Game-Fixtures melden beim Beenden weiterhin
6 ObjectDB-Instanzen / 2 verwendete Ressourcen; sauberer Teardown wird
nicht behauptet.

## Aufnahme und Netzwerk

`blood-animation.gif`: **181 echte GPU-Frames bei 30 FPS**, etwa sechs Sekunden,
640×360-Ausschnitt aus dem tatsächlichen 1280×720-Spiel. Alle GIF-Frames werden
beim Zusammenbau wieder decodiert. Originale unter `blood-frames/`, ausgewählte
vollständige Bilder daneben. Sichtprüfung: `blood-075.png` zeigt die vorhandene
Lache vor dem Einziehen; `blood-095.png` Lache, Tropfen zum Körper und steigenden
Balken. Am Ende kommen genau 25 Blut an.

Aufnahme: `scripts/capture_necro_pool_uptake.gd`, Log `Logs/necro-absorb-gpu.log`.
GIF-Rezept: `output/necro-pool-uptake/assemble.ps1` (Windows PowerShell 5).
Kontrollierte Fixture mit legalem Level-30-Build, 100 Anfangsseelen,
500-HP-Gegner und Debug-Schutz. Blutmal wird normal bezahlt; ein markierter
Gegner stirbt über den tatsächlichen Schadenspfad. Kein direkt gewährtes Blut.
Das ist kein erspielter Lauf, keine Geschmacksabnahme und keine Lastmessung.

`tests/necro_blood_network_smoke.ps1` startet zwei echte lokale ENet-Prozesse.
`network-result.json` hält deren Ergebnis einschließlich gleichzeitig
vorhandener physischer Quelle und Aufnahme-Endpunkte auf beiden Peers fest.
Loopback auf einem PC, keine Zwei-Rechner-LAN-/WAN-Prüfung.

Aktuelle Anleitung: `docs/NEKROMANT-DIENER-FLUCH.de.md`.
Finale Quellstände: `source-hashes.json`. Kein Commit, Push oder Merge.
