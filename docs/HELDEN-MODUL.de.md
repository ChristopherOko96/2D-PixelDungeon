# Gemeinsames Helden-Modul (Stand 29.10.2026)

Ziel des Nutzers: Schwertkämpfer, Bogenschützin und Magier aus der Krypta der
Verdammten, samt Angriffen, Bloom, Fähigkeiten und Animationen, auch im
Hell-Dungeon und in der Frostgruft. Entscheidung: ein gemeinsames Modul, die
Welt-Logik der Story-Welten bleibt. Vorher werden Schwertkämpfer und
Bogenschützin poliert, der Magier war es schon.

## Schritt 1: Darstellung als Modul (fertig, in der Krypta aktiv)

`src/hero/hero_look.gd` zeichnet einen Klassenhelden mit seiner Waffe nur aus
seinem Anzeige-Zustand (Snapshot-Felder). `px` ist die Pixelgröße: 2 in der
Krypta, 3 in den Story-Welten.

- **Schwert:** Der Held lehnt sich in jeden Hieb, die Klinge zieht eine gefüllte
  Sichel. In der Raserei hält er zwei Klingen; der zweite Hieb kommt von der
  anderen Seite zurück (Doppelschlag, rote Sichel).
- **Wirbelklinge:** Die Klinge kreist zweimal um den Helden, der sich mitdreht;
  der Boden antwortet mit Staub (die alte weiße Wirbel-Grafik ist entfallen).
- **Ansturm (und Rücksprung):** Nachbilder und Tempolinien entlang des Wegs,
  Funken bei jedem Treffer.
- **Bogen:** Der Bogen steht quer zur Schussrichtung. Zwischen den Schüssen wird
  die Sehne mit eingelegtem Pfeil zurückgezogen und schnellt beim Schuss nach
  vorn; Ballistapfeil hält die volle Spannung. Die eingezeichnete Sehne jedes
  Bogens wird erkannt und durch die gespannte ersetzt (auch bei gefundenen Bögen).
- **Stab:** kurzer Rückstoß, wenn ein Zauber den Stab verlässt.

`src/vfx/slice_fx.gd`: Kleine Gegner, die in der Raserei sterben, zerfallen in
zwei Hälften entlang des Hiebs (das Ruhebild des Rigs wird geschnitten), die
auseinandergleiten, kippen und verblassen; eine dunkelrote Linie markiert den
Schnitt. Bosse und Mini-Bosse werden nie zerteilt.

## Neue Regeln des Schwertkämpfers (Krypta, Host)

Werte in `assets/data/hero_skills.json` → `sword_feel`.

| Regel | Wert |
| --- | --- |
| Schritt in jeden Hieb | `lunge` 8 px, in der Raserei `rage_lunge` 12 px |
| Raserei: zweiter Hieb, gespiegelt | nach `rage_second_delay` 0,12 s |
| Raserei-Treffer wirft den Gegner | `rage_push` 520 px/s |
| Wandaufprall: geworfener Körper trifft eine Wand | ab `slam_speed` 220 px/s, innerhalb `slam_window` 0,45 s: `slam_damage` 0,8 × Waffenschaden, `slam_stun` 0,6 s, Riss und Staub |
| Ansturm schleudert Körper vom Weg | `charge_side_push` 380 px/s (mit Schulterstoß kräftig nach vorn und etwas zur Seite) |

Bosse werden nicht geworfen (nur wie bisher geschoben) und prallen nicht auf.

## Technik

- Host: `src/combat/hero_skills.gd` (`rage_active`, `lunge`, `rage_hit`, `_throw`,
  `check_slam`, verzögerter `rage_swing`, Ansturm-Wurf), `src/perk_combat.gd`
  (`melee(..., mirrored)`, `swing_dir`), `src/game.gd` (Wandaufprall im
  Rückstoß-Schritt, Snapshot `swing_dir` und `slice`).
- Darstellung: `src/dungeon_view.gd` ruft das Modul (`_draw_class_hero`,
  `_draw_class_weapon`, `_draw_rig_enemy`); `src/rig/rig_renderer.gd` lässt
  zerteilte Gegner nicht zusätzlich zerbröseln; `src/vfx/skill_fx.gd` zeigt
  Wandaufprall und Ansturm-Treffer.
- Test: `tests/hero_polish_test.gd`. Belege: `production/qa/evidence/hero-polish/`
  (`scripts/capture_hero_polish.gd`, optional mit einer anderen Raumdatei).

## Schritt 2: Helden in Hölle und Frostgruft (fertig)

`src/hero/story_hero.gd` bringt die Krypta-Helden in `src/hell/hell_game.gd`, ohne
die Welt-Logik (Schlüssel, Rätsel, Talente, Unterklassen, Relikte) anzufassen:

- Der Held wird über `hero_look.gd` gezeichnet (Pixelgröße der Welt, Waffen in
  `weapon_scale`), schaut in Zielrichtung und dreht sich beim Wirbel mit. Mit einem
  Relikt in der Hand bleibt die Relikt-Darstellung der Welt.
- Pfeile und Zauberkugeln des Helden kommen aus `attack_fx.gd` (Leuchtspur, Kugel
  mit Runenring, Abschuss- und Einschlagsblitz, Bloom), auf eigenen, um den
  Pixelfaktor vergrößerten Ebenen; die Welt zeichnet diese Schüsse nicht mehr selbst.
- Schwert: Schritt in jeden Hieb, in der Raserei der zweite Hieb zurück und
  geworfene Körper mit Wandaufprall (Schaden, Betäubung, Beben). Bosse werden nie
  geworfen. Werte aus `hero_skills.json` → `sword_feel`, um den Pixelfaktor skaliert.
- Eingriffe in die Hell-Laufzeit: `_fire` meldet Schüsse, `_swing(dir, mirrored)`,
  `_update` ruft das Modul, die Bewegung der Gegner prüft den Wandaufprall (auch in
  `hell_monsters.gd`), `_draw_hero` zeichnet über das Modul.
- Test: `tests/story_hero_test.gd`. Belege: `production/qa/evidence/story-heroes/`
  (`scripts/capture_story_heroes.gd`).

## Schritt 3: Fähigkeiten-Effekte und schlanke Leiste (fertig)

`src/hero/story_skill_fx.gd` zeichnet die Fähigkeiten in Hölle und Frostgruft mit
der Krypta-Darstellung (`src/vfx/skill_fx.gd`): Pixel-Effekte, Pixelpartikel mit
Bodenspuren und Bloom. Die Regeln der Fähigkeiten bleiben die der Welt; das Modul
liest nur, was sie hinterlassen.

| Fähigkeit | Darstellung jetzt |
| --- | --- |
| Wirbelklinge | Klinge kreist um den Helden, Staub vom Boden |
| Klingenwelle, Pfeilfaust | Krypta-Geschosse mit Nachbild und Leuchten |
| Feuerball | Feuerkugel mit Glut-Funken; Explosion mit Glut, Rauch und Bodenspur, an der Wand eine kleine Explosion |
| Kettenblitz | gegabelte Blitze mit Nachglühen, Funken an jedem Treffer |
| Blinzeln | violette Blitze an Start und Ziel |
| Photoneneis | Eis-Feuer-Strahl der Krypta; endet an der ersten Wand (Bild und Schaden) |
| Rücksprung | Krähenfüße der Krypta, Staub |
| Raserei | rote Aura, Ausbruch zum Start |

Die Effekte kennen die Wände der Welt (eine 96-px-Zelle der Welt sind 2×2
Krypta-Zellen) und enden dort. Eingriffe in die Hell-Laufzeit: `_draw_skill_fx`
und `_draw_zones` überspringen, was das Modul zeichnet; die Explosion trägt die
Art des Geschosses (`shot`); `hero_kit.beam_end` lässt den Strahl an der Wand enden.

**Schlanke Fähigkeitenleiste** (`src/ui/skill_bar.gd`, Krypta, Hölle und
Frostgruft gemeinsam): ein flacher dunkler Streifen 10 px über dem Rand,
44-px-Felder mit den Krypta-Symbolen, Taste klein in der Ecke, Abklingzeit als
Schatten mit Zahl, „LV n“ solange gesperrt, pulsierender Rahmen bei laufender
Raserei oder Strahl. Der Name erscheint nur, wenn die Maus auf dem Feld liegt.
In allen drei Welten führt ein kleines Level-Feld die Reihe an, die EXP-Linie
läuft am Fuß (in Hölle und Frostgruft stand das Level vorher oben links unter
den Schlüsseln). Größen: `assets/data/ui_run_hud.json` → `skill_bar`.

- Test: `tests/story_skill_fx_test.gd`. Belege:
  `production/qa/evidence/story-skills/before` und `after`
  (`scripts/capture_story_skills.gd`).

## Noch offen

1. Zerteilen gibt es nur in der Krypta: Die Hell-Monster sind fertige Bildstreifen,
   keine Teil-Rigs. Kommt mit dem geplanten Umbau der Monster auf Körperteile.
2. Meteorregen, Pfeilregen und die Relikt-Effekte (Schwerkraftstab) zeichnet die
   Welt weiter selbst; die Krypta hat dafür keine Vorlage.
