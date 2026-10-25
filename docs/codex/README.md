# Codex-Studio für Basement Run

Das Studio ergänzt das bestehende Pixel-Dungeon projektlokal. **Godot 4.7.2,
GDScript, vier Gesamtspieler und 32×32-Pixelgrafik** bleiben gesetzt.
Die neueren gemeinsamen Quellen unter `.claude/` werden beibehalten.

## Starten und weiterarbeiten

Im Explorer `Codex-Studio.cmd` doppelklicken oder im Projektverzeichnis:

```powershell
./scripts/Studio.ps1 Doctor
./scripts/Studio.ps1 Open
```

Im Codex-Desktop kann stattdessen genau dieser Repositoryordner geöffnet werden.
Skills werden aus `.agents/skills/` des aktiven Projektordners geladen.
Ein Chat im übergeordneten Sammelordner erhält sie nicht automatisch.
Falls neue Skills fehlen, Codex im Projekt neu öffnen.
Das Setup verändert keine globalen Einstellungen oder Vertrauensstufen.

In das **Codex-Chatfeld**, nicht in PowerShell:

```text
$studio-help
$studio-code-review src/game.gd
$studio-qa-plan
```

Zum Fortsetzen reicht auch:

```text
Lies AGENTS.md und production/development-plan.md. Setze die nächste sinnvolle
Aufgabe für Basement Run um: Godot 4.7.2, maximal vier Spieler, echte 32×32-
Sprites. Behalte lesbare Kämpfe bei und prüfe Änderungen mit den vorhandenen
Spieltests. Starte keine neue Engine- oder Spielkonzept-Einrichtung.
```

`$studio-start` bleibt verfügbar, ist für dieses vorhandene Spiel aber kein
notwendiger Neueinrichtungs-Schritt.

## Eingerichtete Teile

- Codex-Einstiege für die **74 vorhandenen Workflows** unter `.agents/skills/`.
- **49 Rollendefinitionen** unter `.codex/agents/`, darunter Godot, Gameplay,
  Netzwerk, Art und QA. Modell und Berechtigungen folgen der Sitzung.
- Verzeichnisanleitungen und alle **14 Regeldateien** mit Originalmustern im
  [Regelindex](path-rules.md). Globale Muster bleiben dateispezifisch.
- [runtime.md](runtime.md) übersetzt Claude-Werkzeuge, Rollen und Shell-
  Vorverarbeitung und berücksichtigt die aktuelle project.yaml-Auflösung.
- Windows-Helfer für Start und Prüfung; kein pip-Paket, Claude Code oder neuer
  API-Schlüssel ist erforderlich.

Godot bleibt über `Spielen.cmd`, `Godot-Editor.cmd` und `scripts/Dev.ps1`
erreichbar. Details: [Entwicklungsumgebung](../DEVELOPMENT.de.md).

## Pflege und Prüfung

```powershell
./scripts/Studio.ps1 Check
./scripts/Studio.ps1 Sync
```

`Check` prüft generierte Dateien und führt Adapter-Regressionsprüfungen unter
tests/template aus. `Sync` regeneriert nur markierte verwaltete Dateien.
Unmarkierte eigene Dateien sind bei Kollision geschützt; root AGENTS.md und
Spieldateien werden nicht generiert. Quellen und Generator vor Änderungen lesen.

Optionale Validatoren führen **keinen Commit oder Push** aus:

```powershell
./scripts/Studio.ps1 CommitCheck
./scripts/Studio.ps1 PushCheck
```

Dies registriert keine automatischen Codex-Hooks. Studio-Prüfungen und
Spiel-/Netzwerktests sind getrennt. Ergebnisse:
[Einrichtungsbericht](SETUP-REPORT.de.md).

## Quellen und lokale Anpassungen

Codex-Anbindung aus
[chuanglibs/Claude-Code-Game-Studios-Codex](https://github.com/chuanglibs/Claude-Code-Game-Studios-Codex),
Commit `d202f58a3977a1ffaddd660ad782724a4392e012`.
Gemeinsames Studio ursprünglich von
[Donchitos/Claude-Code-Game-Studios](https://github.com/Donchitos/Claude-Code-Game-Studios).
Die vorhandene MIT-Lizenz und Copyright-Zeile bleiben erhalten.

Der Fork liefert ursprünglich 73 Workflows. Hier werden unsere 74 neueren
Quellen verwendet. Angepasst sind komplexe Regelpfade, studio-tests,
project.yaml-Konfigurationsauflösung, Windows-Werkzeugerkennung und
isolierte Tests für neuere Validatoren.

Offizielle Formatgrundlagen:
[lokale Skills](https://learn.chatgpt.com/docs/build-skills),
[Custom Agents](https://learn.chatgpt.com/docs/agent-configuration/subagents),
[Konfiguration](https://learn.chatgpt.com/docs/config-file/config-reference).
