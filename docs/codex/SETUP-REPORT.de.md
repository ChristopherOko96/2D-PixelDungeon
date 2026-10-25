# Einrichtungsbericht: Codex Game Studios

Stand: 24.10.2026. Ziel: das vorhandene Basement-Run-Projekt in
`outputs/2D-PixelDungeon`, Branch `codex/development-environment-plan`.

## Ergebnis

Die projektlokale Codex-Anbindung ist eingerichtet und geprüft. Grundlage:
[chuanglibs/Claude-Code-Game-Studios-Codex](https://github.com/chuanglibs/Claude-Code-Game-Studios-Codex)
bei Commit `d202f58a3977a1ffaddd660ad782724a4392e012`.
Das bestehende Studio-Gerüst 1.2.0 und die vorhandene MIT-Lizenz bleiben erhalten.

| Teil | Ergebnis |
| --- | --- |
| Workflow-Einstiege | 74 aus den vorhandenen aktuellen Quellen generiert |
| Rollendefinitionen | 49 TOML-Dateien geprüft, ohne Modell-/Berechtigungsüberschreibungen |
| Verzeichnisanleitungen | 13 verwaltete Anleitungen; Root-AGENTS.md bleibt manuell gepflegt |
| Bedingte Pfadregeln | Alle 37 Muster aus 14 Regeldateien erhalten |
| Windows-Start | `Codex-Studio.cmd` und `scripts/Studio.ps1` vorhanden |
| Werkzeuge | Python 3.12.6, Git Bash und vorhandene Codex-Desktop-Binärdatei erkannt |
| Codex-Metadatenprüfung | 74 Studio-Skills erkannt und aktiviert, keine Repository-Skillfehler |
| Adapter-Regressionssuite | 26 Tests ausgeführt: 25 bestanden, 1 Windows-Symlinktest übersprungen |
| Godot-Prüfung | Import und beide Spielskripte erfolgreich; 21 Regelprüfungen bestanden |

Die Metadatenprüfung nutzt den lokalen Codex-App-Server mit
`config/read` und `skills/list`, ohne Modellturn zu starten. Die verwendete
Codex-Version ist `0.164.0-alpha.11.1` aus der vorhandenen Desktop-Installation.
Eine ältere CLI 0.130 liegt ebenfalls auf dem Rechner; der Starter wählt die
neuere vorhandene Version. Globale Modell-, Rechte- oder Vertrauenseinstellungen
wurden nicht geändert. Das ist kein Nachweis von 49 separat ausgeführten Rollen;
deren Definitionen sind geprüft, ihre Delegation erfolgt bei benötigten Aufgaben.

## Erhaltene Projektvorgaben

- Godot 4.7.2, GDScript und Compatibility Renderer.
- Maximal vier Gesamtspieler, also Host plus drei Clients.
- Echte 32×32-Pixelgrafik und klare Darstellung der Kämpfe.
- Bestehende Spieldateien, PNGs, Projektkonfiguration, Spielbrief, Tests und Plan.

Vor der Einrichtung wurden 679 bestehende, nicht ignorierte Dateien gesichert
und ihre SHA256-Werte erfasst. Der Vergleich bestätigt unveränderte Spiel- und
Assetdateien. Geändert wurden von diesem Bestand nur Root-AGENTS.md, README.md
und drei gezielt angepasste Validatoren. Weitere Dateien sind neue Studio-Dateien.

Die vorhandene Phase `Concept` wurde nicht automatisch angehoben. Technischer
Prototyp und Prüfstand stehen weiterhin im Entwicklungsplan; ein formales
Phasengate wird durch die Studio-Einrichtung nicht als bestanden erklärt.

## Notwendige Anpassungen gegenüber dem Fork

- Aus den neueren lokalen Quellen werden 74 statt 73 Skill-Einstiege erzeugt.
- Komplexe Dateimuster bleiben im bedingten Regelindex erhalten. Es werden keine
  Unity-Verzeichnisse erzeugt, keine Windows-Groß-/Kleinschreibungs-Kollisionen
  mit `assets/` eingeführt und keine Dateien in ignorierten Speichern benötigt.
- Die aktuelle `project.yaml`-Auflösung einschließlich lokaler Einstellungen,
  Rigor und Automation wird genutzt. Claude-Shell-Vorverarbeitung wird in Codex
  ausdrücklich aufgelöst; sie läuft nicht allein durch Lesen einer Skill-Datei.
- Git Bash und Python werden für Validatoren auch außerhalb von PATH gefunden.
  Die zusätzliche Umgebung gilt nur für deren Unterprozess.
- Drei vorhandene Validatoren unterscheiden jetzt AGENTS-/CLAUDE-Anleitungen
  von Spieldokumenten und Assets. Die neuere Prüfung gestagter Dateiinhalte bleibt
  erhalten. Regressionen wurden vor der Korrektur fehlschlagen gesehen.
- Hook-Tests verwenden vollständig isolierte temporäre Projekte. Sie können
  nicht versehentlich die eigentlichen Projektdateien prüfen oder verändern.

## Geprüfte Befehle

```powershell
./scripts/Studio.ps1 Doctor
./scripts/Studio.ps1 Check
./scripts/Dev.ps1 Check
$godot = '../tools/godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe'
& $godot --headless --path . --script res://tests/game_rules.gd
```

Zusätzlich wurden alle Rollen als TOML geparst, Quellen-/Regellinks geprüft,
die tatsächliche Konfigurationsauflösung für Godot/minimal/guided ausgeführt
und `git diff --check` ohne Befund abgeschlossen. Die tatsächlichen vorhandenen
Netzwerktests werden in [DEVELOPMENT.de.md](../DEVELOPMENT.de.md) dokumentiert;
die Studio-Einrichtung ersetzt keine LAN-/WAN- oder Leistungstests.

## Weiterarbeiten

`Codex-Studio.cmd` öffnet Codex im richtigen Repositoryordner. Im Desktop kann
derselbe Ordner geöffnet werden. Im Chat `$studio-help` eingeben oder eine
konkrete Aufgabe aus `production/development-plan.md` beauftragen.
Für laufende Chats im übergeordneten Sammelordner gilt: neue Projekt-Skills
werden dort nicht automatisch als Skills dieses Ordners geladen.

Es wurde kein Git-Commit, Push, Merge oder GitHub-Fork ausgeführt.
Alle Änderungen liegen lokal auf dem bestehenden Entwicklungsbranch.
