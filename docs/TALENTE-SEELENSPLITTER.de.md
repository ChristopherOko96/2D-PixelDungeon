# Talentbäume und Seelensplitter

Stand: 29.10.2026. Grundlage: der Master-Prompt des Nutzers und die abgenommene
Planer-Seite „Klassen und Talentbäume“. Diese Fassung ersetzt die
Seelenkristalle, Talentbäume und Unterklassen der Frostgruft
(`src/hell/meta_store.gd`).

## Entscheidungen (29.10.2026)

1. **Klassen:** 3 Klassen × 3 Spezialisierungen × 6 Talente = 54 Talente.
   Der frühere Plan mit 4 Klassen pro Held und Bäumen der Tiefe 12 entfällt.
2. **Level:** Das Charakterlevel 1–30 gilt pro Klasse und wird dauerhaft im
   Profil gespeichert. Das Team-Level im Run bleibt für die Karten bei
   Levelaufstieg.
3. **Einheitlich:** Ein gemeinsames Profil für alle Storys. Die alten
   Frostgruft-Kristalle verfallen.
4. **Schwierigkeit:** Normal, Schwer und Albtraum werden neu eingebaut. Das
   Boss-Level ist Etage × 2 plus Schwierigkeitsbonus. Gold aus Runs wird im
   Profil gespeichert.
5. **Tasten:** Die Klassen-Skills bleiben auf 1–4. Aktive Talente liegen auf
   Shift + 1–4 (Belegung im Talentmenü umstellbar), die Ultimate auf R.
7. **Tempo:** Max-Level nach etwa eineinhalb kompletten Etagen.
6. **Maßstab:** 1 Meter entspricht einer Kachel (32 Pixel).

## Regeln

| Bereich | Regel | Wert (alles in `assets/data/talents.json`) |
|---|---|---|
| Talentpunkte | ab Level 2 einer pro Level | 29 bei Level 30 |
| Ränge | normale Talente 3, Ultimate 1 | – |
| Stufe I / II / III / IV | Level 2 / 6 + 3 Punkte / 12 + 7 / 20 + 12 im Zweig | `tiers` |
| Ultimate | freier Punkt und 3 Seelensplitter, nur eine gleichzeitig | `soul_shards.ultimate_cost` |
| Seelenstufen | 2 / 4 / 7 Splitter für +5 / +10 / +15 % (ersetzt), Stufe 3 auch −5 % Abklingzeit | `tier_costs`, `tier_bonus_pct` |
| Ultimates ohne Schaden | Zeitbruch, Unbezwingbar: +0,5 / 1 / 1,5 s; Blutrausch: Schaden und Lebensraub ×1,05 / 1,10 / 1,15 | `duration_bonus_s`, `soul` je Talent |
| Zurücksetzen | 25 Gold pro Level; alle Punkte und Splitter zurück, Seelenstufen enden | `reset_gold_per_level` |
| Ressourcen | Mana 100 (+6/s), Ausdauer 100 (+10/s), Zorn 0–100 (+10 je Treffer, +5 je erlittenem Treffer) | `resources` |
| Gemeinsame Abklingzeit | 1 s nach jedem aktiven Talent | `global_cooldown` |
| Status | Brennen 12 %/s 4 s, Gift 10 %/s 5 s, Blutung 10 %/s 4 s des Grundangriffs; erneuern statt stapeln | `statuses` |
| Krit | 5 % Grundchance, 150 % Schaden | `base_crit` |
| Fallen | höchstens 2 pro Spieler | `max_traps` |
| Bosse | immun gegen Einfrieren, Festhalten und Provokation | Code |

**Seelensplitter:** Nur echte Etagenbosse droppen sie. Normale Gegner,
Elitegegner, Nebenbosse, beschworene Gegner und Truhen geben nie welche. Die
Chance liegt bei 8 / 15 / 25 % (Normal / Schwer / Albtraum), höchstens ein
Splitter pro Bosssieg. Nach 9 berechtigten Siegen ohne Splitter ist der 10.
garantiert (Pechschutz). Der erste Albtraum-Sieg pro Boss und Profil ist
garantiert und setzt den Pechschutz zurück. Kein Splitter und keine
Pechschutz-Zählung gibt es in diesen Fällen:
- der Boss liegt mehr als 5 Level unter dem Charakter,
- der Kampf dauerte unter 20 s,
- der Held hatte unter 5 % Schadensanteil,
- der Held war nicht dabei,
- die Abschluss-Kennung wurde schon gewertet.

**EXP und Gold:** Gegner 10 EXP und 1 Gold, Nebenbosse 150 EXP, Bosse 400 EXP
und 40 Gold, jede neue Etage 100 EXP und 15 Gold. Für das nächste Level
braucht man 2,5 × Level EXP. Level 30 braucht damit etwa 1 090 EXP, das sind
grob eineinhalb komplette Etagen (Nutzerentscheid 29.10.2026: Max-Level nach
etwa eineinhalb Etagen, nicht nach vielen Runs).

**Schwierigkeit:** Leben der Gegner ×1 / 1,5 / 2,2, Schaden ×1 / 1,3 / 1,6.
Gewählt wird sie im Talentmenü, und sie gilt für die Runs des Hosts.

## Aufbau

| Modul | Aufgabe |
|---|---|
| `src/progress/profile.gd` | Profil als Dictionary, prüfen, laden und speichern (`user://profile.json`, erst in eine Zwischendatei, dann ersetzen). Testläufe nutzen `user://profile_test.json`. |
| `src/progress/talent_rules.gd` | Punkte, Stufen, Ränge, Ultimate, Seelenstufen, Reset, Leiste, EXP |
| `src/progress/soul_drops.gd` | Boss-Level, Berechtigung, Wurf, Pechschutz, Albtraum-Erstsieg, Kennungen |
| `src/progress/run_progress.gd` | Verbindet Run und Profil: EXP, Gold, Schwierigkeit, Bosssiege; schickt Belohnungen an die Mitspieler |
| `src/combat/talent_combat.gd` | Alle 54 Talente im Kampf: Ressourcen, Leiste, Ultimate, Buffs, Schild, Konter, Wölfe, Fallen, Giftzone, Passivboni |
| `src/ui/talent_screen.gd` | Talentmenü im Hauptmenü |
| `src/ui/run_hud.gd` | Talentleiste, Ressourcenleiste, Meldung „SEELENSPLITTER ERHALTEN!“ und Levelaufstieg |
| `src/vfx/talent_fx.gd` | Wölfe, Fallen, Zonen und kurze Effekte im Spielbild |
| `src/ui/talent_bar.gd` | Talentleiste und Belohnungsanzeige, in allen Maps gleich |
| `src/hell/hell_talents.gd` | Dieselben Talente in Frostgruft und Hölle: übersetzt Held, Gegner, Schaden, Status, Wände und HUD der Hell-Laufzeit für `talent_combat.gd`; bringt EXP, Gold, Level und Schwierigkeit dorthin |

**Mehrspieler:** Der Host entscheidet alles, was sich fälschen ließe: welcher
Gegner fiel, ob ein Held beteiligt war, Kampfdauer, Schadensanteile,
Boss-Level und den Zufallswurf. Jeder Held bekommt daraus ein
Belohnungsereignis. Sein eigenes Spiel wendet es mit denselben reinen Regeln
auf sein Profil an und speichert es; Pechschutz, Erstsiege und gewertete
Kennungen liegen dort. Die Builds der Clients prüft der Host gegen die Regeln
(`TalentRules.repair`), bevor sie zählen.

Grenze: Es gibt keinen eigenen Server. Ein manipuliertes Spiel könnte sein
eigenes Profil-File ändern. Gegen doppelte oder erfundene Belohnungen im
laufenden Spiel schützt das trotzdem.

## Stand

| Teil | Stand |
|---|---|
| Daten, Regeln, Profil, Drops | umgesetzt, `tests/talent_progress_test.gd` (158 Prüfungen) |
| 54 Talente im Kampf der Gruft | umgesetzt, `tests/talent_combat_test.gd` (120 Prüfungen) |
| Talentmenü, HUD-Leiste, Splitter-Meldung | umgesetzt, Bilder in `production/qa/evidence/talents/` (`scripts/capture_talents.gd`) |
| Frostgruft und Hölle | Dieselben 54 Talente mit derselben Leiste (Shift + 1–4, R), EXP und Gold pro Gegner, Schwierigkeit, Splitter vom Endboss. Kristalle und Unterklassen entfallen. `tests/hell_talents_test.gd` |

## Offen

- **Merge mit main (29.10.2026, Nutzerentscheid „beides kombinieren“):** Von
  main bleiben Lauf-Baum (Taste B), Tod beendet den Lauf, Item-System 2,
  Spielstände und das einheitliche HUD. Unser Talentprofil ersetzt die
  dauerhaften Talente und Seelenkristalle von `docs/LAUF-DESIGN.de.md` 3.3:
  Keine Lauf-Baum-Knoten warten mehr auf ein dauerhaftes Talent
  (`src/hell/card_kit.gd`, `game.gd` `_apply_meta`). „Etage neu starten“
  entfällt wie bei main; R löst die Ultimate aus. Provokation durch den Wolf
  wirkt auf die Frostgruft-Gegner, aber noch nicht auf die eigenen Monster
  der Hölle (`hell_monsters.gd`).
- **Icons und Effekte (29.10.2026):** Jedes Talent hat ein eigenes
  14×14-Pixelmotiv (`src/ui/talent_icons.gd`, `icon` in `talents.json`).
  Die Effekte spielen Pixel-Sheets aus `scripts/make_fx_sprites.gd`:
  Feuer-, Frost-, Arkan-, Stahl- und Schrei-Ring, Inferno-Säule, Nullpunkt,
  Sternexplosion, Schildblase, Eislanze, Arkangeschoss, Zielmarke,
  Giftwolke, Dornenfalle, Krallen (`src/vfx/talent_fx.gd`). Bilder:
  `production/qa/evidence/attacks/`.
- **Auftragsliste:** Seit 29.10.2026 eine Seite „Auftrag“ im Pausenmenü
  (`src/ui/quest_view.gd`), in Krypta, Frostgruft und Hölle gleich. Frostgruft
  und Hölle öffnen mit Esc dasselbe Pausenmenü (`src/pause_menu.gd`).
  Nutzerentscheid 29.10.2026: nur im Menü, keine extra Zeile im HUD.
- **Wolf-Grafik:** Im 0x72-Pack gibt es keinen Wolf. Der Wolf ist eine kleine
  Pixelfigur in den Farben des Packs.
- **Lokalisierung:** Wie im übrigen Spiel sind die Texte deutsch fest
  eingetragen.
- **Mehrspieler-Lauf:** Ist nur über die Regeln getestet. Ein echter Lauf mit
  zwei Spielern steht noch aus.
