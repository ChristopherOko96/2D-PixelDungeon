# Godot-Entwicklungsumgebung für Basement Run

Stand: 25.10.2026. Auf ausdrücklichen Nutzerwunsch wird **Godot** verwendet.
Die frühere Unity-Konfiguration gehört zur dokumentierten Ausgangslage und
bestimmt diese Entwicklungsumgebung nicht mehr.

## Schnellstart unter Windows

Im Explorer startet `Spielen.cmd` den Spielstand per Doppelklick;
`Godot-Editor.cmd` öffnet das Projekt im Editor. Beide verwenden denselben
PowerShell-Wrapper wie die folgenden Befehle.

Das Repository in PowerShell öffnen. Alle folgenden Befehle werden im
Repositoryverzeichnis ausgeführt. Der Branch für diese Arbeit heißt
`codex/v2` im separaten Fork `Wugu7/2D-PixelDungeon-V2`; nicht auf `main` wechseln.

```powershell
./scripts/Dev.ps1 Doctor
./scripts/Dev.ps1 Check
./scripts/Dev.ps1 Open
```

`Open` öffnet den Godot-Editor. `Run` startet den kleinen Spielstand direkt:

```powershell
./scripts/Dev.ps1 Run
```

Godot wird als portable Standardausgabe **4.7.2** verwendet. GDScript benötigt
hier kein .NET-SDK. Der Compatibility Renderer vermeidet zusätzliche
Renderpipeline-Pakete. Engine und Standardport stehen in
`scripts/godot-environment.json`; Projekteinstieg ist `project.godot` mit
`res://src/main.tscn`. Die kleine Spiellogik liegt in `src/game.gd`, die
Darstellung in `src/dungeon_view.gd`, Spielwerte und Perk-Daten in
`src/data/balance.json`.

## Engine finden

Der Wrapper sucht in dieser Reihenfolge:

1. Übergebener Parameter `-GodotPath`.
2. Umgebungsvariable `GODOT_PATH`.
3. Ignorierte Datei `scripts/godot.local.json`, Eigenschaft `godotPath`.
4. Portable Engine neben dem Repository:
   `../tools/godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe`.
5. Passender Godot-Befehl auf `PATH`.

```powershell
./scripts/Dev.ps1 Doctor -GodotPath 'D:/Tools/Godot/Godot_v4.7.2-stable_win64_console.exe'
```

Für einen persönlichen Pfad kann die ignorierte lokale JSON-Datei enthalten:

```json
{ "godotPath": "D:/Tools/Godot/Godot_v4.7.2-stable_win64_console.exe" }
```

Die Versionsausgabe muss mit `4.7.2.stable` beginnen. Ein anderer Editorpatch
wird nicht stillschweigend akzeptiert. Portable Binärdateien und Maschinenpfade
werden nicht in den Git-Branch aufgenommen. Die Godot-Downloadquelle ist die
[offizielle Veröffentlichung 4.7.2](https://github.com/godotengine/godot-builds/releases/tag/4.7.2-stable).

## Host und eigenständigen Client starten

Zwei getrennte Spielprozesse auf demselben Rechner:

```powershell
./scripts/Dev.ps1 Host -Port 7777
./scripts/Dev.ps1 Join -Address 127.0.0.1 -Port 7777
```

Der Host öffnet eine Lobby. Sobald der zweite Teilnehmer verbunden ist, kann
der Host den Lauf über die Oberfläche starten. `Run` erlaubt den Einstieg über
die Spieloberfläche. Vorgesehene Bedienung des kleinen Entwicklungsstands:
WASD zum Bewegen, Maus zum Zielen und linke Maustaste zum Schießen. Nach einem
Raumerfolg Perk auswählen und Bereitschaft bestätigen. Die tatsächliche Prüfung
dieser Abläufe steht im Prüfstatus unten; die Steuerung ist kein automatischer
Nachweis, dass bereits alle Spielregeln fertig sind.

Im LAN auf dem zweiten Rechner statt `127.0.0.1` die LAN-IP des Hostrechners
verwenden. Beide müssen denselben Port und denselben Spielstand verwenden.
Die aktuelle Grenze beträgt auf Nutzerwunsch **vier Teilnehmer insgesamt**, also
Host plus drei Clients. Acht Teilnehmer bleiben eine spätere Option. Das
konfigurierte Viererlimit ist noch kein Leistungsnachweis für vier Teilnehmer.

Internetspiel benötigt eine wirklich erreichbare Hostadresse und UDP-Port.
Firewall, Routerweiterleitung und NAT sind gesondert zu prüfen. Ein Relay,
Matchmakingdienst oder öffentlich gehosteter Server ist nicht eingerichtet.
Eine erfolgreiche lokale Verbindung belegt kein funktionierendes Internetspiel.

## Darstellung und Lesbarkeit

Die aktuelle Gestaltungsanforderung sind **echte 32×32-PNG-Sprites** auf einem
32-Pixel-Grundraster, mit Nearest-Filterung und ohne Glättung. Die Dateien werden
unter `assets/sprites/` angelegt; der zugehörige Generator ist
`scripts/generate_pixel_assets.gd`. Die tatsächlichen PNG-Abmessungen werden
separat geprüft und bis dahin nicht als nachgewiesen ausgegeben.

Die Kampfszene soll in Richtung The Binding of Isaac und Vampire Survivors
verständlich bleiben: vier klar unterscheidbare Spielerfarben, erkennbare Gegner
und eine deutliche Trennung eigener und feindlicher Projektile. Übersichtlicher
Kampf ist ein Abnahmekriterium. Idle-/Schussanimationen und Umgebung erhalten
spätere gezielte Politur; weitere Bodenvarianten sind keine Voraussetzung für
diesen ersten Stand.

## Was die Befehle prüfen

| Befehl | Wirkung | Aussagegrenze |
| --- | --- | --- |
| `Doctor` | Featurebranch, Projektdateien und tatsächliche Engineversion prüfen | Kein Gameplay-/Netzwerktest |
| `Open` | Godot-Editor öffnen | Noch kein erfolgreicher Import bestätigt |
| `Run` | Kleinen Spielstand starten | Verhalten manuell prüfen |
| `Host` | Eigenen Hostprozess auf dem angegebenen UDP-Port starten | Verbindungen und Spielablauf anschließend prüfen |
| `Join` | Eigenen Clientprozess mit Zieladresse und Port starten | Verbindungsversuch ist noch kein erfolgreicher Beitritt |
| `Check` | Headless-Import und Laden aller `src/**/*.gd` mit dem vorhandenen Parsehelfer | Keine vollständigen Spieltests, keine Netzwerk-/Exportprüfung |

`Check` wertet Exitcode und Ausgabe aus. `SCRIPT ERROR`, Parsefehler oder
fehlgeschlagene Skriptladung zählen auch bei Exitcode 0 als Fehler. Ein Aufruf
ohne gefundene Spielskripte gilt ebenfalls nicht als bestanden. Import und
Parseprüfung werden protokolliert; lokale Ausgaben liegen unter ignoriertem
`Logs/`. Der bestehende Helfer ist
`.claude/scripts/godot-parse-check.gd`.

Für Windows-Exporte müssen passende Godot-Export-Templates und ein Export-Preset
vorhanden sein; ein fertiger Export wird hier noch nicht zugesagt. Spielregel-
und Prozessprüfungen sind separat vorhanden. `Check` führt sie nicht automatisch
aus. `studio-tests/` testet Studio-Anweisungen, nicht das Dungeon-Spiel.

## Spielregeln und Netzwerk getrennt prüfen

Die eingebaute `SceneTree`-Prüfsuite braucht kein zusätzliches Test-Addon:

```powershell
$godot = '../tools/godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe'
& $godot --headless --path . --script res://tests/game_rules.gd
```

Bei einem persönlichen Enginepfad `$godot` entsprechend setzen. Die Suite
`tests/game_rules.gd` prüft serverseitige Spielregeln, unter anderem doppelte/
ungültige Perkauswahl, Eingabevalidierung, Ready-Gate, Wiederbelebung,
Unverwundbarkeit, Teamwipe und den Übergang Boss → Belohnung → Sieg.
Sie ersetzt keine Verbindung mit echten Clientprozessen.

Die Prozessprüfungen starten eigene lokale Hosts/Clients und räumen ihre
Prozesse anschließend auf:

```powershell
./tests/network_smoke.ps1 -Players 2
./tests/network_smoke.ps1 -Players 4
./tests/network_smoke.ps1 -Players 4 -DisconnectOrder reverse
```

Bei einem eigenen Enginepfad zusätzlich `-GodotPath $godot` übergeben. Mit zwei
Teilnehmern wird der geskriptete Lauf geprüft; mit vier die Lobby mit Host und
drei unabhängigen Clients. Ausgaben bleiben in
`Logs/network-smoke/<eindeutiger-lauf>/`. Die Vier-Teilnehmer-Prüfung belegt weder
einen vollständigen Vier-Spieler-Lauf noch Leistung oder LAN-/WAN-Verbindung.
Ergebnisse tatsächlich ausgeführter Prüfungen stehen im folgenden Status.

## Prüfstatus dieser Einrichtung

Nachprüfung vom 25.10.2026: Ein sporadischer Fehler bei gleichzeitigem ENet-
Verbindungsabbau wurde beobachtet. Godots für dieses Host/Client-Modell nicht
benötigtes Client-Relay ist jetzt vor dem Verbindungsaufbau deaktiviert;
Teilnehmerzustand kommt weiterhin über die Host-Snapshots. Die Fehlerausgabe
wird nicht unterdrückt. Erneut bestanden: 21 Spielregeln, Zwei-Spieler-Smoke
sowie Vier-Spieler-Smokes mit gleichzeitigem und umgekehrt gestaffeltem
Trennen. Die folgenden ursprünglichen Nachweise bleiben als Verlauf erhalten.

- Engine bereitgestellt und Version geprüft: `4.7.2.stable.official.ed1daf0bf`.
- SHA256 des heruntergeladenen ZIP-Archivs der portablen Windows-Ausgabe:
  `731980f9608d61333e5baf54a2ef17210acc7a538446c0cb9969f002aca1e953`.
- Wrapper statisch auf gültige PowerShell-Syntax geprüft; `Doctor` unter
  Windows PowerShell 5.1 erfolgreich ausgeführt.
- `Check` unter Windows PowerShell 5.1 erfolgreich ausgeführt: Headless-Import
  ohne Fehler, danach beide Spielskripte `src/game.gd` und
  `src/dungeon_view.gd` erfolgreich geladen. Kein Spieltest.
- Eingebaute Spielregelsuite tatsächlich mit Godot headless ausgeführt:
  `GAME_RULES checked=21 failures=0`, Exitcode 0. Enthält unter anderem
  Bossbelohnung, einmalige Perks, Ready-Gate und Ablehnung ungültiger Eingaben.
- Grafischer Spielstart und Sichtprüfung erfolgreich: Menü und Kampfszene
  dargestellt; Bildbeleg unter
  [production/qa/evidence/godot-prototype.png](../production/qa/evidence/godot-prototype.png).
- Zwei getrennte ENet-Prozesse über Loopback erfolgreich geprüft, einschließlich
  Belohnung nach dem Bossraum: `RoomsCleared=3`, `PerksSelected=6`,
  `RUN_COMPLETED players=2`, Sieg auf beiden Seiten; Host und Client mit Exitcode
  0, ohne stderr-Ausgaben oder MTU-Warnungen. Alle drei Räume einschließlich
  persönlicher Perkauswahl und gemeinsamem Ready-Gate durchlaufen. Das ist kein
  manueller Spielspaß- oder LAN-Nachweis.
- Aktueller Viererstand erneut geprüft: Import und beide Spielskripte fehlerfrei,
  21 Regelprüfungen bestanden. Alle acht PNG-Quelldateien haben laut ausgelesenen
  Bildmaßen genau 32×32 Pixel. Figuren, Schleim, Fackel und Bodentile erscheinen
  in Originalgröße; der Boss verwendet die 32×32-Quelle mit zweifacher Skalierung.
- Vier separate Prozesse erfolgreich verbunden: ein Host und drei Clients,
  Snapshots auf allen Clients und fehlerfreier gleichzeitiger Verbindungsabbau.
  Ein grafischer Vierer-Lobbylauf wurde zusätzlich geprüft:
  [Vierer-Lobby](../production/qa/evidence/godot-lobby-4.png).
- Ein fünfter Teilnehmer erhielt im zehnsekündigen Kapazitätstest weder einen
  erfolgreichen Beitritt noch einen Snapshot. Die Gruppe blieb bei vier.
  In diesem Zeitfenster erschien keine ausdrückliche Ablehnungsmeldung.
- Vollständiger Vier-Spieler-Kampf unter künstlicher Latenz, zwei reale
  LAN-Rechner, WAN und Belastungsmessung: **noch ausstehend**.
- Kleiner spielbarer Prototyp: drei Kampfräume einschließlich Boss, fünf einfache
  datenbasierte Perks und gemeinsamer Raumwechsel. Neue Raumvorlagen, weitere
  Pixel-Assets und Animationen, ausgearbeitete Perk-Kombinationen und ein produktionsreifes
  Stockwerk bleiben weitere Arbeit.
- Prototypregel: Gefallene Spieler kehren am nächsten Raum mit 50 % ihres
  maximalen Lebens zurück; nur lebende Teilnehmer müssen bereit bestätigen.
  Dies ist noch keine abgestimmte Regel für die spätere Veröffentlichung.
- Protokoll-/Inhaltsversionierung, Interpolation, Bandbreitenmessung und
  Internetbetrieb sind noch auszubauen beziehungsweise zu prüfen.

Der [Prüfbericht](../production/qa/verification.md) fasst die Nachweise zusammen.
Ziele und Abnahmen stehen in
`production/development-plan.md`; die ursprüngliche Spielidee und ihre
Abweichungen sind in `docs/PROJECT-REVIEW.de.md` zusammengefasst.
