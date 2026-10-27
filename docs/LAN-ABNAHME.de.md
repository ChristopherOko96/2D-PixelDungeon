# Abnahme auf zwei echten LAN-Rechnern

**Noch nicht ausgeführt:** Der Nutzer hat bestätigt, dass aktuell nur dieser
PC verfügbar ist. Die bestandenen lokalen2-/4-Prozess-Läufe und der UDP-
Verzögerungs-/Verlustlauf ersetzen diesen Hardware-Nachweis nicht.

## Gemeinsam spielen

Auf beiden Rechnern denselben aktuellen Projektstand und Godot4.7.2 verwenden.
Der neue Beitrittsabgleich prüft Protokoll-/Regelversion, Enginepatch, Generator
und Raum-/Balance-Daten. Abweichungen in diesen Feldern werden vor Aufnahme
abgewiesen. Identische Quellstände weiterhin selbst sicherstellen: Beliebige
Codeänderungen erkennt der Datenhash nicht; Protokoll-/Regeländerungen benötigen
eine angepasste explizite Version.

Im Repository auf RechnerA:

```powershell
./scripts/Dev.ps1 Host -Port 7777
```

Die IPv4-Adresse des Hosts zeigt beispielsweise `ipconfig`. Auf RechnerB:

```powershell
./scripts/Dev.ps1 Join -Address <IPv4-DES-HOSTS> -Port 7777
```

Die Platzhalteradresse vor Ausführung ersetzen. Host startet, sobald alle in der
Lobby sichtbar sind. F11 schaltet Vollbild; ESC öffnet Informationen. Im Koop
pausiert ESC die anderen Teilnehmer nicht. Vier Teilnehmer bedeuten Host plus
drei Clients; mindestens ein Client muss tatsächlich auf dem zweiten PC laufen.

## Reproduzierbarer technischer Zehn-Raum-Lauf

Die vorbereiteten Testpeers verwenden normale Bewegung, Schüsse, Kartenbuttons
und E-Interaktion. Sie verändern keine HP-, Schaden- oder Raumzustände direkt.
In beiden Terminals Godotpfad und Logordner festlegen:

```powershell
$lanGodot = '../tools/godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe'
New-Item -ItemType Directory -Path Logs/lan-acceptance -Force
```

Auf RechnerA:

```powershell
& $lanGodot --headless --max-fps 120 --path . --script res://tests/ten_room_campaign_peer.gd -- --campaign-role host --campaign-bind 0.0.0.0 --campaign-port 7777 --campaign-players 2 --campaign-seed 42026 --campaign-seconds 900 --campaign-report Logs/lan-acceptance/host.json
```

Auf RechnerB:

```powershell
& $lanGodot --headless --max-fps 120 --path . --script res://tests/ten_room_campaign_peer.gd -- --campaign-role client --campaign-address <IPv4-DES-HOSTS> --campaign-port 7777 --campaign-players 2 --campaign-seed 42026 --campaign-seconds 900 --campaign-report Logs/lan-acceptance/client.json
```

Für vier Teilnehmer auf allen Peers `--campaign-players 4` setzen und insgesamt
drei Clientprozesse starten; unterschiedliche Reportnamen verwenden. Ohne diese
zusätzlichen Clients wartet der Host. Konsolenausgaben beider Rechner behalten.
Beide Berichte müssen PASS melden und dieselben elf Layoutkennungen/-Hashes
enthalten. Die kopierten Berichte müssen um Rechner, Verbindungsart und Laufzeit
ergänzt werden; eine konfigurierte LAN-Adresse allein beweist keine zweite Maschine.

## Noch offene Abnahme

- Ein vollständiger gemeinsamer Gewinn- und Verlustlauf, Belohnungen, Rückweg,
  Boss10, Treppe und Neustart auf den realen Rechnern.
- Mindestens30Minuten echter LAN-Betrieb ohne Absturz, doppelte Perks oder
  bleibende Zustandsabweichung; genaue Hardware, Auflösung und Dauer aufzeichnen.
- Sichtbare Darstellung/Framezeiten auf der späteren Zielhardware prüfen.
  Headless-Prozesse zeigen keine grafische FPS-Leistung.
- Die lokale künstliche100ms-RTT-/1%-UDP-Verlustprüfung ist separat dokumentiert.
  Ein echter Test über zwei Internetanschlüsse ist ebenfalls noch nicht erfolgt.

Die persönliche Stil-/Spielgefühl-Abnahme bleibt beim Nutzer; die technischen
Bots können sie nicht ersetzen. [Aktueller Prüfbericht](GAMEDEV-UMSETZUNG.de.md).
