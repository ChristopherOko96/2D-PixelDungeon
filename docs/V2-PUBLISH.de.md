# Pixel Dungeon V2: Entwicklungsbranch und Veröffentlichung

Stand: 25.10.2026.

## Aktuelles Ziel auf Nutzerwunsch

Am 25.10.2026 hat der Nutzer ausdrücklich angefordert, die bisherigen Änderungen
einschließlich Raumgenerator im Repository seines Bruders auf **`codex_v2`**
hochzuladen. Dieser Branchname ist absichtlich ohne Schrägstrich geschrieben.

- Ziel: [ChristopherOko96/2D-PixelDungeon, Branch codex_v2](https://github.com/ChristopherOko96/2D-PixelDungeon/tree/codex_v2).
- Remote `origin` zeigt auf dieses Repository. Keine Änderung oder Zusammenführung
  nach `main`, kein Force-Push und keine Änderung des Standardbranches.
- Der Branch enthält den bisherigen Godot-/Codex-Studio-Stand aus `44c9b80`
  und den danach entwickelten Raumgenerator. Er geht weiterhin von `e620468` aus.
- Die Unity-/Kenney-Commits auf `main` werden nicht automatisch hineingemergt.

## Vorheriger separater Fork

- Original: [ChristopherOko96/2D-PixelDungeon](https://github.com/ChristopherOko96/2D-PixelDungeon).
- Separater Fork: [Wugu7/2D-PixelDungeon-V2](https://github.com/Wugu7/2D-PixelDungeon-V2).
- Bisheriger Godot-Stand: [`codex/v2`](https://github.com/Wugu7/2D-PixelDungeon-V2/tree/codex/v2), Commit `44c9b80`.
- Lokaler Remote `origin` zeigt weiterhin auf das Original; `v2` zeigt auf den Fork.
- Die Standardansicht des V2-Forks soll auf `codex/v2` zeigen; sein `main`
  bleibt als unveränderte Original-Linie erhalten.

Der Godot-Stand geht von `e6204688157dbbb6d10faa7906ace5fa482d016d` aus.
Das Original hat inzwischen die zusätzlichen Commits `739fbb5` (Kenney Tiny
Dungeon) und `6914bd2` (Unity-Projekt) erhalten. Diese wurden nicht ungefragt in
die ausdrücklich gewünschte Godot-Linie übernommen. Der Fork enthält den
Originalstand in seinem `main`; unsere Änderungen wurden zuerst auf `codex/v2` geführt.
Ein späterer Merge wäre eine gesonderte Entscheidung.

**V2 ist ein Entwicklungsname.** Es wird damit weder ein fertiges Spiel noch eine
stabile Version 2.0 oder eine veröffentlichte Windows-Exportdatei behauptet.

## Welche Workflows schon vorhanden waren

Das ursprüngliche Repository enthielt bereits das Claude Code Game Studios-
Gerüst: Rollen, Workflow-Skills, Regeln, Vorlagen und Prüfskripte unter `.claude/`.
Die neu hinzugefügte Codex-Anbindung macht dieselben aktuellen Quellen über
`.agents/skills/`, `.codex/agents/` und `AGENTS.md` nutzbar. Es sind keine zwei
konkurrierenden Spielsysteme.

Diese Dateien beeinflussen die **KI-gestützte Entwicklung**, wenn Claude Code
oder Codex im Projekt verwendet werden. Sie gehören nicht zur laufenden
Godot-Spiellogik. `project.godot` startet `src/main.tscn`; das Spiel lädt weder
die Studio-Workflows noch deren Shell-Befehle.

Im aktuellen Repository liegen keine GitHub-Actions-Workflows. Ein Git-Push
startet daher keine darin konfigurierte automatische Spieleentwicklung,
Bereitstellung oder Modellanfrage. Claude-spezifische Hooks gelten für dessen
Entwicklersitzungen; Codex verwendet die dokumentierten expliziten Prüfungen.

## Inhalt des V2-Stands

- Godot 4.7.2 und GDScript, getrennte Clients mit ENet.
- Maximal vier Gesamtspieler: Host plus drei Clients.
- Acht echte 32×32-PNG-Basisgrafiken und reproduzierbarer Sprite-Generator.
- Drei Kampfräume einschließlich Boss, persönliche Raum-Perks und Ready-Gate.
- Seed-basierte Vorlagenwahl, stabile Raumkennungen, Hindernisse, Gegnerwege und Raumkarte.
- Codex-Studio mit 74 Skill-Einstiegen und 49 Rollendefinitionen.
- Spielbrief, Bestandsaufnahme, Entwicklungsplan und dokumentierte Prüfungen.

Logs, `.godot`-Cache, lokale Einstellungen und die portable Engine neben dem
Repository gehören nicht in den Commit. Nach einem frischen Klon muss Godot
4.7.2 separat vorhanden sein; der [Entwicklungsleitfaden](DEVELOPMENT.de.md)
beschreibt den Enginepfad und die Startbefehle.

## Weiterarbeiten und veröffentlichen

```powershell
git switch codex_v2
./scripts/Studio.ps1 Check
./scripts/Dev.ps1 Check
git push origin codex_v2
```

Vor einem Commit beziehungsweise Push sind zusätzlich die passenden expliziten
Studio-Validatoren und Spielprüfungen auszuführen. Es gibt keinen automatischen
Merge nach `main`. Die bestehenden Grenzen bleiben dokumentiert: LAN/WAN,
Latenz, Leistung, zusätzliche Raumarten und vollständiges Animations-Polishing
benötigen weitere Arbeit.

Vor dem ersten Fork-Push wurden die Studio-Prüfungen ausgeführt (25 bestanden,
ein Windows-Symlinktest übersprungen), beide Godot-Skripte erfolgreich importiert
und 21 Spielregelprüfungen bestanden. Ein dabei gefundener sporadischer
Verbindungsabbaufehler wurde durch Abschalten des ungenutzten Client-Relays
behoben. Zwei gezielte Vierer-Abbautests und der Zwei-Spieler-Smoke bestehen
danach ohne Godot-Fehler. Details stehen im
[Prüfbericht](../production/qa/verification.md).
Die zusätzliche Prüfung des Raumgenerators ist dort separat dokumentiert.
