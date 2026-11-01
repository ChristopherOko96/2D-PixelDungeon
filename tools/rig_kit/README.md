# Rig-Daten: ein Weg für alle Rigs

Alle Rig-Dateien des Spiels entstehen auf einem Weg. Das Verzeichnis
`assets/data/rig_manifest.json` nennt jede Datei in der Reihenfolge, in der
das Spiel sie lädt, und sagt, woraus sie gebaut wird.

- `src/rig/rig_library.gd` lädt genau diese Liste (`RigLibrary.rig_sources()`).
  Für eine neue Rig-Datei reicht ein Eintrag im Verzeichnis, Code muss nicht
  geändert werden.
- `tools/rig_kit/build_rigs.js` baut jede Datei aus ihren Schritten.
- `tools/rig_kit/rig_check.js` enthält die Prüfungen.
- `tools/rig_kit/hand_rigs/` enthält die Quellen der Rigs, für die es keinen
  Generator gibt.

## Befehle (im Repo-Ordner)

```
node tools/rig_kit/build_rigs.js           bauen; schreibt nur Dateien, die sich ändern, bei einem Fehler gar nichts
node tools/rig_kit/build_rigs.js --check   nur prüfen und vergleichen, schreibt nichts; Exit-Code 1 bei Fehler oder Abweichung
node tools/rig_kit/build_rigs_test.js      Unit-Test des Bauskripts (arbeitet in einem Temp-Ordner)
```

Der Godot-Test ist `tests/rig_manifest_test.gd`.

## Woher jede Datei kommt

| Datei | Schritte, in dieser Reihenfolge |
|---|---|
| `rigs.json` | 1. `production/art-proof/0x72-style/export_rigs.js` (die freigegebene Prüfseite) · 2. `hand_rigs/hell_0x72.json` (13 Figuren der Hölle) · 3. `tools/frost_dungeon/export_frost_rigs.js` (15 Figuren der Frostgruft, schreibt ihre PNGs) |
| `companion_rigs.json` | `hand_rigs/companion_rigs.json`, Byte für Byte kopiert |
| `krypta_boss_rigs.json` | `hand_rigs/krypta_boss_rigs.json`, Byte für Byte kopiert |
| `story_rigs.json` | `tools/krypta_dungeon/export_story_rigs.js`, liest das eben gebaute `rigs.json` |
| `hell_rigs.json` | 1. `tools/hell_dungeon/export_rigs.js` (drache1 bis drache4, schreibt ihre PNGs) · 2. `hand_rigs/hell_layered.json` (blutfledermaus) |
| `rig_actions.json` | keine Schritte, wird von Hand gepflegt |

**Regel:** Eine Datei mit Schritten nie direkt bearbeiten. Ändere stattdessen den
Generator oder die Hand-Quelle und führe den Build aus. Sonst meldet `--check`
die Datei als `DRIFT`.

Die alten Aufrufe der Generatoren funktionieren weiter. `export_rigs.js` der
Prüfseite startet jetzt den ganzen Build, damit es `rigs.json` nicht mehr leert.
`tools/hell_dungeon/export_mob_rigs.js` gehört nicht zum Build (siehe
`not_built`), denn brandskelett liegt als Rechteck-Rig in `rigs.json`.

## Was `--check` prüft

- Jede gebaute Datei und jedes PNG gleicht seinem Build. Unterschiede nur bei
  den Zeilenenden (CRLF/LF) zählen nicht.
- Jede Teil-ID ist im Rig nur einmal vergeben. Jeder Elternteil, jedes
  `alsoDetach`, jedes Gruppenmitglied und jeder Punkt nennt ein Teil des Rigs.
  Keine Elternkette läuft im Kreis.
- Jeder Bildschlüssel ist zu diesem Zeitpunkt schon geladen. Jeder Bildpfad und
  jede Teil-PNG existiert. Jedes ausgeschnittene Teil besitzt mindestens ein
  Pixel. Bekannte Ausnahmen stehen in `check.known_empty_parts`.
- Jede `scales`-Angabe gehört zu einem Rig derselben Datei. Item-`scale` liegt
  zwischen 0,1 und 4.
- `disables` und `weakens` nennen eine Rig-Aktion (`rig_actions.json`
  `categories`, `check.legacy_actions`) oder eine Angriffs-ID eines Monsters,
  das dieses Rig trägt.
- Jedes Rig, das eine Tabelle nennt, existiert. Die Tabellen stehen unter
  `check.references`: Krypta, Hölle, Frostgruft, Begleiter und Helden.
- Kein Schicht-Rig heißt wie ein Rechteck-Rig (die RigLibrary würde es
  überspringen).
- Ein `held`-Block nennt einen bekannten Stil (sword, bow, staff), eine Hand als
  [x, y] und Griff und Spitze als Anteile des Bildes (0 bis 1).

## Gehaltene Waffe (`held`)

Die Waffe eines Helden wechselt im Spiel (gefundene Schwerter, Bögen, Stäbe).
Deshalb trägt das Waffen-Item seines Rigs einen `held`-Block: Er sagt, wie die
Figur jedes Bild hält, das man ihr gibt. Das Item selbst legt das Elternteil
(`parent`) und die Zeichenreihenfolge (`z`) fest.

```
"held": {"style": "sword", "hand": [8, 14.4], "grip": [0.5, 0.9], "tip": [0.5, 0], "rest": 0, "scale": 1}
```

- `style`: wie `src/hero/hero_look.gd` die Waffe bewegt (sword, bow, staff).
- `hand`: die Schulter in Figur-Pixeln auf dem Elternteil. Schwert und Bogen
  schwingen um sie, der Stab steht `side` Pixel daneben (zur Blickseite).
- `grip` und `tip`: wo die Hand das Bild hält und wo seine Spitze ist, als Anteil
  von Breite und Höhe des Bildes.
- `rest`: zusätzliche Drehung in Radiant; `scale`: Faktor auf die Größe.
- Nur beim Stab: `side` (Figur-Pixel) und `length` (Höhe in Figur-Pixeln).

Die Werte der Helden stehen in den Generatoren: knight, elf und wizard in
`production/art-proof/0x72-style/export_rigs.js` (`HERO_HELD`), necro_hero in
`tools/krypta_dungeon/export_story_rigs.js`. Danach den Build laufen lassen.
Im Spiel fragt das Rig über `RigHeldHost` (`src/rig_kit/rig_held_host.gd`) nach
den Teilen und trägt sie mit dem Elternteil mit (`src/rig_kit/rig_held.gd`).
Der Test ist `tests/hero_weapon_rig_test.gd`.

## Neuer Generator

Ein Generator ist ein Node-Modul mit `rigKit(ctx)`:

- `ctx.root` ist der Repo-Ordner und `ctx.data` die Datei bis zu diesem Schritt
  (oder `null`). `ctx.read("res://…")` liefert eine früher gebaute Datei, die
  im Verzeichnis unter `"reads"` stehen muss. `ctx.options` enthält die
  Optionen des Builds.
- Er gibt `{ data, files: [{ file, png }], notes }` zurück und schreibt selbst
  nichts. Die Ordner seiner PNGs gehören ins Verzeichnis unter `"writes"`.
- Rigs aus früheren Schritten darf er nicht ändern. Tut er es doch, bricht der
  Build mit einem Namenskonflikt ab.

## Bekannt (Stand 01.11.2026)

- Beim glutwaechter und den drei frost_golem-Rigs besitzen Kopf und Schultern
  kein eigenes Pixel, weil die Rechtecke des Rumpfs sie mit abdecken. Das ist
  so geblieben, weil ein neuer Zuschnitt das Aussehen ändert.
- Die Ladereihenfolge ist die alte: rigs, companion, boss, story, hell, actions.
