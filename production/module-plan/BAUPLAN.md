# Bauplan · Systeme als eigenständige Module

Stand 2026-11-01. Grundlage: Vier Lese-Agenten haben Physik, Rigs, Zauber und die übrigen Systeme
kartiert. Die Rohdaten mit Datei:Zeile-Belegen liegen in `production/module-plan/systemkarte.json`.
Am Code wurde nichts geändert.

## Kurzantwort

Ja, das geht. Godot verlangt dafür nichts Besonderes. Ein Modul braucht fünf Dinge, die der
Welt-Baukasten (`src/world_kit/`) schon vormacht:

1. **Eine Einstiegsklasse** mit `class_name`, damit man sie ohne Dateipfad findet.
2. **Einen geschriebenen Vertrag** („Host“): eine kleine Basisklasse mit den wenigen Fragen, die das
   Modul an das Spiel stellt, zum Beispiel `solid(punkt)`, `verletze(ziel, menge, element)` oder
   `pfuetzen_unter(punkt)`. Das Modul greift dann nie mehr selbst ins Spiel (`g.`) hinein.
3. **Werte in JSON** statt Zahlen im Code.
4. **Eine Anleitung** auf Deutsch, zum Beispiel „So baust du X in deine Welt ein“ und
   „So legst du einen neuen Y an“.
5. **Einen Test und eine kleine Demo-Szene**, in der man das System ohne Lauf ausprobieren kann.

Dann kann dein Bruder, oder wer sonst am Projekt arbeitet, eine neue Welt bauen, die nur den
Vertrag erfüllt. Physik, Rigs und Zauber kommen dazu, ohne dass er `hell_game.gd` kennen muss.

## Was wir heute haben

### Schon eigenständig (greifen nicht ins Spiel)

| System | Dateien | Es fehlt noch |
|---|---|---|
| Welt-Baukasten (vom Bruder) | `src/world_kit/` | nichts, er ist das Vorbild |
| Kamera | `src/hell/story_camera.gd` | Anleitung, `class_name` |
| Klang-Kern (Abspielen, Mischpult, Musik) | `src/vfx/sfx.gd`, `src/audio/` | Anleitung, Demo |
| Spielgefühl-Kern (Blitz, Stauchen, Wackeln, Hitstop) | `src/vfx/feedback.gd` | Anleitung, kleine Fassade |
| Pixelmaterie (fallender Sand, Splitter, Spuren) | `src/vfx/particles.gd` | Anleitung, einheitliche Maßeinheit |
| Gas | `src/vfx/gas.gd` | Spielregel und Zeichnung trennen |
| Pfützen und Flüssigkeiten | `src/vfx/pool_paint.gd` | Spielregel und Zeichnung trennen |
| Element-Regeln (was ein Medium tut) | `src/combat/element_rules.gd` + `element_rules.json` | Wahnsinn und Leerenmagier herauslösen |
| Körperteile (LP je Teil, Abtrennen) | `src/combat/body_parts.gd` | nichts Grobes |
| Rig-Zeichnung und Rig-Daten | `src/rig/` | Datenweg vereinheitlichen, große Datei aufteilen |
| Talentbäume, Lauf-Baum | `src/progress/talent_rules.gd`, `run_tree.gd` | Anleitung |
| Zauber-Aussehen (Elementsprache) | `src/vfx/talent_*.gd` | hängt an Schlüsselnamen der Laufzeit |
| HUD-Baukasten, Optionen | `src/ui/hud_kit.gd`, `skill_bar.gd`, `options_panel.gd` | Anleitung |
| Item-Regeln, Spielstand-Speicher | `src/items/item_rules.gd`, `src/save/save_store.gd` | Anleitung |

### Halb eigenständig

| System | Zugriffe ins Spiel | Problem |
|---|---|---|
| Zauber-Laufzeit (`talent_combat.gd`) | über einen ungeschriebenen Vertrag | zwei Umsetzungen (alter Dungeon, Story-Welten), aber nur über „Hat es diese Methode?“ |
| Inventar (`inventory.gd`) | 53 | dasselbe Muster: ungeschriebener Vertrag |
| Zerstörung (`story_wreck.gd`) | 40 | schreibt in Wände, Lichter und Beute; noch nicht eingecheckt |
| Rüstungskräfte (Taste F) | 65 | eigene Zeichen- und Splitterlogik neben den Zaubern |

### Fest verschweißt (das eigentliche Hindernis)

| Datei | Zugriffe ins Spiel |
|---|---|
| `src/hell/story_elements.gd` (Element-Reaktionen) | 150, dazu etwa 33 Schreibzugriffe in fremde Daten |
| `src/hero/story_items.gd` | 135 |
| `src/hero/story_glow.gd` | 118 |
| `src/hero/story_feel.gd` | 90 |
| `src/hero/story_sound.gd` | 43 |
| `src/hell/hell_game.gd` als Mittelpunkt | etwa 2256 Zugriffe aus 27 Modulen |

Die Kerne sind also schon gut. Fest verschweißt sind die Story-Adapter zwischen den Kernen und dem Spiel.

## Fehler und Doppelungen

### Physik

- **Dieselbe Physik läuft je Welt über andere Wege.** Was Pfützen und Gas mit einer Figur machen,
  wird an drei Stellen berechnet: in `hell_game.gd`, in `hell_monsters.gd` und im alten Dungeon.
  Die Frostgruft-Gegner bekommen dabei **keine Kombinationen** (ein brennender Gegner läuft ins
  Gift, und nichts passiert). Außerdem fehlt dort die Prüfung, ob ein Gegner eingegraben ist oder fliegt.
- Die Frostgruft hat **keine Pfützen-Reaktionen** und eigene Monster-Pfützen, die das Spiel nicht
  als Pfützen erkennt. Dazu kommen eine eigene Kopie des Rückstoßes und **Ragdolls, die durch Wände fallen**.
- Der Rückstoß des Helden steht **zweimal** im Code, mit denselben Zahlen.
- Gas-Abtastradien und der Griff auf Glatteis sind **feste Zahlen im Code**, und jede Kopie hat andere.
- Gas und Pfützen sind als reines Aussehen gebaut, werden aber als Spielregel gelesen. Folge:
  Eiszellen, die nur gezeichnet sind, zählen als echtes Eis, und Spuren hängen an einem
  Hintergrund-Thread.
- Blitz-Aufladung und die Wellen-, Beben- und Heilig-Reaktionen der Story-Welten erreicht man nur im Testraum.

### Rigs

- **Fehler (geprüft):** Bei 10 Krypta-Gegnern legt ein abgetrenntes Teil keinen Angriff still.
  Die Rigs stammen aus dem alten Dungeon und nennen die Angriffe `attack`, `cast` und `block`.
  Die Krypta-Angriffe heißen aber `hieb`, `fluch`, `schild`, `atem` und so weiter. Betroffen sind
  Skelett, Skelettschütze, Skelettwache, Nekromant, Knochenwächter, Moderkoloss, Nekromantenfürst,
  Frostleiche, Archivar und Knochenkoloss. Nichts im Code prüft diese Zuordnung.
- Ein **neuer Rig-Gegner** braucht heute 5–7 Dateien, eine neue Bewegungsfamilie 10–13 Dateien
  in JS, JSON und GDScript.
- Die Rig-Daten liegen in fünf JSON-Dateien, die fünf Generatoren erzeugen oder die von Hand
  gepflegt werden. Einige Rigs haben gar keinen Generator. Die Posen-Logik gibt es dreimal:
  einmal in GDScript, zweimal in den JS-Vorschauen.
- `rig_renderer.gd` (über 2000 Zeilen) mischt Zeichnen, Ragdoll-Physik, Partikel und Boss-Effekte.
- **Es gibt drei getrennte Splitter-Physiken:** Ragdoll, Zerstörung (`story_wreck`) und die
  fallengelassene Heldenwaffe.
- In der Frostgruft verlieren Rig-Gegner keine Teile und fallen ohne Schlagrichtung.
- Heldenwaffen hängen nicht am Rig, sondern werden extra gezeichnet.

### Zauber

- Heute gehört zu jedem Zauber-Typ eigener Code: 28 Typen, davon dienen 15 genau einem Talent
  und einer (`wall`) gar keinem. Die vier Takte (Wirken, Flug, Einschlag, Rückstand) gibt es nur
  im Aussehen. Den Einschlag erkennt das Spiel nur daran, dass ein Geschoss verschwindet.
- **Vieles ist mehrfach gebaut:**
  - Geschosse 5×
  - Flächenschaden 5×, mit verschiedener Trefferform (mal zählen die Füße, mal der Körper)
  - Kettenblitz 3×
  - Teleport 5×
  - Schaden über Zeit auf 3 Wegen
  - Schilde 4×
  - Feuerball-Zeichnung 4×
  - drei verschiedene Weltmaßstäbe
- **Fehler (geprüft):** „Raumsprung“ (`arcane_5`) verspricht, Verlangsamungen zu lösen. Das ist
  nirgends gebaut, der Aufruf läuft still ins Leere (`talent_combat.gd:396`).
- **Leistung (geprüft):** `talents.json` (112 KB) wird bei jedem Zeichnen der Fähigkeitsleiste
  neu gelesen, weil `Profile.data()` nichts zwischenspeichert.
- Vermutet, noch nicht im Spiel gemessen: Gift und Blutung zählen in der Story-Welt als Brennen,
  und ihr Schaden wird womöglich doppelt mit dem Schadenswert multipliziert.
- Rund 3000 Zeilen alter Klassenfähigkeiten (HeroKit-Fähigkeiten 1–4, SubKit, StorySkillFx,
  Fähigkeitskarten) sind in den Story-Welten seit dem 29.10. nicht mehr erreichbar.

### Team und Werkzeuge

- `hell_game.gd` hat drei Autoren und die meisten Merge-Konflikte.
- Es fehlen eine Liste, wer welche Dateien pflegt, und ein Testlauf über alle Tests.
  `docs/DEVELOPMENT.de.md` beschreibt noch das alte Spiel.
- Die Zeilenenden sind gemischt (CRLF und LF), und `.gitattributes` regelt `.gd` nicht.
- 92 Stellen lesen JSON selbst ein, ohne gemeinsamen Lader.

## Vorschlag zur Freigabe

Jeder Punkt hat eine Kennung. Du kannst ganze Pakete oder einzelne Punkte freigeben.
Aufwand: S klein, M mittel, L groß.

### Paket F · Sofort-Fehler (unabhängig vom Umbau)

| ID | Was | Aufwand |
|---|---|---|
| F1 | Krypta-Rigs: `disables` auf die echten Angriffsnamen umstellen und eine Prüfung einbauen, die falsche Namen meldet | S |
| F2 | Raumsprung löst Verlangsamungen wirklich | S |
| F3 | `talents.json` einmal lesen und zwischenspeichern | S |
| F4 | Gift und Blutung in der Story: eigener Schaden über Zeit, Doppel-Multiplikation prüfen und beheben | S |

### Paket M0 · Fundament

| ID | Was | Aufwand |
|---|---|---|
| M0a | Ein gemeinsamer JSON-Lader mit Zwischenspeicher, ein Einstellungspfad, eine `world_id` je Welt | S |
| M0b | `docs/MODULE.de.md`: welches Modul wofür da ist, die Regel „Module greifen nicht in `g.`“, das Vertragsmuster | S |
| M0c | Ein Testlauf-Skript, das alle Tests startet und die Fehlschläge auflistet | S |
| M0d | Zeilenenden-Regel in `.gitattributes`, nur nach Absprache mit deinem Bruder, sonst entstehen riesige Diffs | S |

### Paket M1 · Physik-Baukasten

| ID | Was | Aufwand |
|---|---|---|
| M1a | Pixel-Grundbausteine und ein Materie-Dienst: eine Maßeinheit, keine kopierten Tabellen | S |
| M1b | Ein Bewegungsmodul für Rückstoß, Rutschen und Sog, Werte in JSON; ersetzt beide Kopien | S |
| M1c | Ein `ElementExposure` für Held und alle Gegner in allen drei Welten; die Frostgruft bekommt die Kombinationen | M |
| M1d | Gas und Pfützen: Spielfeld (Spielregel) und Zeichnung trennen | M |
| M1e | Reaktions-Motor hinter einem Vertrag; ersetzt die 150 Zugriffe in `story_elements.gd`; die Frostgruft-Pfützen werden echte Pfützen | L |
| M1f | Zerstörung als Modul (vorher einchecken) | M |
| M1g | Schnee und Wetter: nur zusammen mit deinem Bruder, das sind seine Dateien | M |
| M1h | Demo „Physik-Sandkasten“, Anleitung, Tests | S |

### Paket M2 · Rig-Baukasten

| ID | Was | Aufwand |
|---|---|---|
| M2a | Ein Datenweg: ein Verzeichnis aller Rigs und ein Bauskript mit `--check` | M |
| M2b | `rig_renderer.gd` aufteilen in Zeichnen, Effekte und eine gemeinsame Splitter-Physik, die auch Zerstörung und Heldenwaffe nutzen | L |
| M2c | Ein allgemeiner Rig-Host mit kleinem Adapter je Welt; die Frostgruft bekommt Teileverlust, Schlagrichtung und Wände | L |
| M2d | Heldenwaffen als Rig-Teile | S |
| M2e | Anleitung „Neuen Rig-Gegner anlegen“ in höchstens drei Schritten, Demo, Tests | S |

### Paket M3 · Zauber-Baukasten

| ID | Was | Aufwand |
|---|---|---|
| M3a | Den Zauber-Vertrag als Basisklasse aufschreiben; beide Welten erfüllen ihn | M |
| M3b | Zauber als Daten in vier Takten (Wirken, Flug, Einschlag, Rückstand), gebaut aus gemeinsamen Bausteinen: je ein Geschoss, eine Fläche mit einer Trefferform, eine Kette, ein Teleport, ein Weg für Schaden über Zeit, ein Schild; dazu echte Einschlag-Ereignisse | L |
| M3c | Rüstungskräfte und Magier-Grundangriff auf dieselben Bausteine | M |
| M3d | Anleitung „Neuen Zauber anlegen“, Demo, Tests | S |
| M3e | Die rund 3000 Zeilen alter Klassenfähigkeiten entfernen, nur auf deinen Wunsch | M |

### Paket M4 · Übrige Module

| ID | Was | Aufwand |
|---|---|---|
| M4a | Kamera, Klang-Kern, Spielgefühl-Kern, HUD-Baukasten, Item-Regeln, Speicher: Anleitung, `class_name`, Demo | S |
| M4b | Ein `WorldContext` mit öffentlichen Fragen statt privater `g._…`-Aufrufe | M |
| M4c | Die Story-Adapter darauf umstellen, in dieser Reihenfolge: Klang, Gefühl, Licht, Items | L |

### Paket T · Team

| ID | Was | Aufwand |
|---|---|---|
| T1 | Zuständigkeitsliste, wer welche Dateien pflegt (aus der Git-Geschichte, du bestätigst sie) | S |
| T2 | `docs/DEVELOPMENT.de.md` auf die Story-Welten umschreiben | S |
| T3 | Später: die Baukästen zusätzlich als Godot-Addons (`addons/`), damit sie auch in andere Projekte passen | M |

## Reihenfolge und Vorsicht

- Anfangen erst, wenn der laufende A–D-Workflow fertig und eingecheckt ist. Er bearbeitet gerade
  dieselben Dateien (`hell_game.gd`, `hell_monsters.gd`, `rig_renderer.gd` und weitere).
- **Hinweis:** Im Arbeitsstand sind Dateien des Welt-Baukastens deines Bruders geändert
  (`src/world_kit/`, `tools/world_kit/`, die Welt-JS-Dateien und die drei `*_world.json`),
  wahrscheinlich für D6 (eigene Kurve je Welt). Diese Änderungen sollten vor dem Push einen
  eigenen Commit bekommen und deinem Bruder gezeigt werden.
- Empfohlene Folge: F → M0 → M1 → M2 → M3 → M4, T nebenher.
- Die Dateipfade bleiben zuerst, wo sie sind. Bisher nutzt kein Modul `class_name`. Ein Umzug
  würde je Datei bis zu 18 Stellen brechen, dazu die Testskripte und alte Spielstände, die
  Szenenpfade speichern.
- Große Umbauten an `hell_game.gd` am besten in einem abgesprochenen Zeitfenster oder auf einem
  eigenen Zweig, damit dein Bruder nicht gleichzeitig dort arbeitet.
- Für jeden Schritt gilt: Ladeprüfung plus eine Probe mit Bild in einer Story-Szene.
