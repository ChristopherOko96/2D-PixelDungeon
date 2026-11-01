# Zeilenenden · Stand und Vorschlag (M0d)

Stand 01.11.2026, Zweig `codex_v2`. Zum Besprechen mit deinem Bruder.
`.gitattributes` ist **nicht** geändert. Dieses Blatt schlägt nur vor.

## Kurz

- **Im Repository selbst ist alles schon LF.** `git ls-files --eol` findet keine einzige
  Datei mit CRLF im Index (`i/crlf`: 0). Die Mischung gibt es nur in diesem Arbeitsordner.
- Woher die Mischung kommt: Git für Windows steht systemweit auf `core.autocrlf=true`
  (`C:/Program Files/Git/etc/gitconfig`). Beim Auschecken macht Git aus LF also CRLF.
  Dateien, die später ein Werkzeug neu geschrieben hat (Godot, Codex, Claude), sind
  wieder LF. Dateien, die seit dem Auschecken nur bearbeitet wurden, sind CRLF geblieben.
- `.editorconfig` verlangt schon heute `end_of_line = lf` für alle Dateien. Godot schreibt
  selbst LF: alle 5533 `.import`-Dateien sind LF.
- Eine Regel `* text=auto eol=lf` ändert deshalb **nichts an der Geschichte und an keinem
  Commit-Inhalt**. Sie sorgt nur dafür, dass jeder Arbeitsordner LF bekommt, egal wie
  `core.autocrlf` eingestellt ist.

## Zählung im Arbeitsordner

Nur Dateien, die Git verfolgt und als Text erkennt (`git ls-files --eol`, Spalte `w/`).
Bilder, Töne und leere Dateien zählen nicht mit.

| Ordner | CRLF | LF | gemischt |
|---|---:|---:|---:|
| `(Projektwurzel)` | 10 | 13 | 0 |
| `.agents/` | 0 | 74 | 0 |
| `.claude/` | 4 | 430 | 0 |
| `.codex/` | 0 | 49 | 0 |
| `.github/` | 3 | 0 | 0 |
| `assets/data/` | 22 | 35 | 0 |
| `assets/` (ohne `data`) | 31 | 5491 | 0 |
| `design/` | 3 | 3 | 0 |
| `docs/` | 62 | 40 | 0 |
| `output/` | 5 | 0 | 0 |
| `production/` | 34 | 94 | 0 |
| `scripts/` | 94 | 133 | 0 |
| `src/` (Wurzel) | 10 | 61 | 0 |
| `src/combat/` | 12 | 10 | 0 |
| `src/core/` | 0 | 3 | 0 |
| `src/debug/` | 1 | 11 | 0 |
| `src/dungeon/` | 6 | 10 | 0 |
| `src/editor/` | 1 | 11 | 0 |
| `src/hell/` | 36 | 13 | 0 |
| `src/hero/` | 13 | 9 | 0 |
| `src/online/` | 2 | 0 | 0 |
| `src/player/` | 5 | 5 | 0 |
| `src/progress/` | 8 | 2 | 0 |
| `src/rig/` | 0 | 6 | 0 |
| `src/save/` | 2 | 4 | 0 |
| `src/ui/` | 11 | 22 | 0 |
| `src/vfx/` | 17 | 35 | 0 |
| `src/world_kit/` | 4 | 0 | 0 |
| übrige `src/`-Ordner (`ai`, `audio`, `data`, `gameplay`, `items`, `networking`) | 0 | 12 | 0 |
| `studio-tests/` | 129 | 1 | 0 |
| `tests/` | 101 | 170 | 0 |
| `tools/companions/` | 0 | 2 | 0 |
| `tools/frost_dungeon/` | 11 | 134 | 0 |
| `tools/hell_dungeon/` | 24 | 1 | 0 |
| `tools/krypta_dungeon/` | 11 | 2 | 1 |
| `tools/world_kit/` | 4 | 0 | 0 |
| **Summe** | **676** | **6886** | **1** |

Nach Dateiart: `.gd` 176 CRLF zu 226 LF, `.json` 60 zu 84, `.md` 225 zu 583,
`.js` 28 zu 7, `.py` 32 zu 5, `.uid` 129 zu 271. Die eine gemischte Datei ist
`tools/krypta_dungeon/README.md`.

Die Dateien deines Bruders sind hier alle CRLF: `src/world_kit/*`, `tools/world_kit/*`,
`src/hell/hell_walls.gd`, `src/hero/frost_snow.gd`. Im Index sind sie LF wie alle anderen.

## Was die Mischung heute kostet

- Agenten müssen CRLF-Dateien mit dem Edit-Werkzeug bearbeiten, sonst entstehen kaputte
  oder gemischte Zeilenenden. `sed` und Python-Umschreiber sind dort verboten.
- Exakte Textvergleiche (Edit-Ersetzungen, Skripte, die Zeilen suchen) brechen, wenn eine
  Datei CRLF hat und der gesuchte Text LF.
- Git warnt bei LF-Dateien „LF will be replaced by CRLF the next time Git touches it“.
- Die eigentliche Gefahr für riesige Diffs: Wer `core.autocrlf=false` hat und mit einem
  Editor CRLF speichert, committet CRLF. Dann ist im Diff jede Zeile geändert. Heute
  schützt davor nur, dass alle zufällig `autocrlf=true` haben.

## Vorgeschlagene Regeln für `.gitattributes`

Die vorhandenen Regeln (`*.sh`, `*.awk`, `.worktreeinclude`, `*.tsv`, `.claude/**/*.md`)
bleiben. Neu dazu, ganz oben:

```gitattributes
# Alles, was Git als Text erkennt, ist im Repository und in jedem Arbeitsordner LF,
# egal wie core.autocrlf steht (.editorconfig verlangt LF schon heute).
* text=auto eol=lf

# Die Godot-Dateien ausdrücklich als Text (falls Git eine einmal falsch einschätzt).
*.gd       text eol=lf
*.gdshader text eol=lf
*.tscn     text eol=lf
*.tres     text eol=lf
*.import   text eol=lf
*.uid      text eol=lf
*.cfg      text eol=lf
*.json     text eol=lf
*.js       text eol=lf
*.md       text eol=lf

# Batch-Dateien braucht cmd.exe mit CRLF (Sprungmarken und goto brechen sonst).
*.cmd text eol=crlf
*.bat text eol=crlf

# Binärdateien nie anfassen.
*.png  binary
*.jpg  binary
*.webp binary
*.wav  binary
*.ogg  binary
*.mp3  binary
*.ttf  binary
*.otf  binary
*.blend binary
```

`.ps1` bleibt LF. 12 der 14 PowerShell-Skripte sind schon LF und laufen unter
Windows PowerShell 5.1. Wichtig ist nur, dass `.ps1`-Dateien ASCII bleiben oder ein BOM
haben: PowerShell 5.1 liest eine `.ps1` ohne BOM als ANSI.

## Einmalige Umstellung

Nur mit einem **sauberen Arbeitsordner auf beiden Rechnern**. Alles Offene erst
committen und pushen, sonst gehen Änderungen verloren.

1. Beide committen und pushen ihren Stand. Hier liegen gerade viele offene Änderungen
   (Umbau-Workflow); die müssen zuerst rein.
2. Ein Rechner, eigener Zweig: die Regeln in `.gitattributes` eintragen und **allein**
   committen, zum Beispiel `chore: line ending rules in .gitattributes`.
3. `git add --renormalize .` und dann `git status`. Erwartung: **nichts geändert**, weil
   der Index schon LF ist. Taucht doch eine Datei auf, kommt sie in einen eigenen Commit
   `chore: normalize line endings` (nie zusammen mit echten Änderungen).
4. Den Arbeitsordner einmal frisch auf LF schreiben lassen (nur bei sauberem Stand):
   `git rm -r --cached -q .` und danach `git reset --hard`. Danach zeigt
   `git ls-files --eol` überall `w/lf` (bei `*.cmd`/`*.bat` `w/crlf`).
5. Prüfen: `scripts/Dev.ps1 Tests` (lädt alles, läuft alle Tests) und einmal das Spiel
   starten.
6. Pushen, Bruder holt den Zweig, macht bei sich Schritt 4 einmal, fertig.

## Was das für den Checkout deines Bruders heißt

- **Kein Konflikt durch die Umstellung.** Seine Commits sind schon LF (der Index war nie
  CRLF), es ändert sich also kein Dateiinhalt in der Geschichte. Merges und Rebases
  laufen wie vorher.
- Nach dem Holen der Regel bleiben seine Dateien zunächst, wie sie sind (CRLF). Erst
  Schritt 4 schreibt sie als LF. Davor kann `git status` einzelne Dateien als geändert
  zeigen, obwohl nur das Zeilenende anders ist. `git add --renormalize .` räumt das auf.
- Seine Werkzeuge: Godot schreibt LF. Node-Skripte (`tools/world_kit/*.js`,
  `tools/krypta_dungeon/*.js`) schreiben, was der Code schreibt; die erzeugten JSON-Dateien
  werden ohnehin beim Commit nach LF umgewandelt. Ein Editor nach `.editorconfig`
  (VS Code, Rider, Notepad++ mit Plugin) speichert LF.
- Wenn er `core.autocrlf=false` und einen Editor ohne `.editorconfig` hat, ist die Regel
  genau sein Schutz: Git speichert trotzdem LF.
- Absprechen: der Zeitpunkt (beide sauber), wer Schritt 2 bis 4 macht, und ob seine
  offenen Änderungen an `src/world_kit/`, `tools/world_kit/` und den drei
  `*_world.json` vorher als eigener Commit hineinkommen.

## Danach

- Die Agenten-Regel „CRLF-Dateien nur mit dem Edit-Werkzeug“ kann entfallen.
- `git ls-files --eol | grep -v "w/lf"` als kurze Prüfung zeigt sofort, wenn wieder eine
  CRLF-Datei hineinrutscht.
