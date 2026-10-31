# Gegner-Befund: Waffen nach dem Tod und Gegner-Durchlauf der Krypta (2026-10-31)

Gemeldet vom User: „In der Krypta (und überhaupt) sterben Gegner, aber ihre Waffen bewegen sich weiter.
Bei den Skelett-Schwertkämpfern sieht man es am besten: wenn sie sterben oder ihr Körper wegfliegt,
bewegt sich das Schwert weiter, als wäre es noch Teil eines lebenden Körpers.“

## 1. Der Schwert-Bug

### Reproduktion
Probe in der Krypta-Story-Szene (`res://src/hell/krypta_dungeon.tscn`). Jeder Fall wurde einzeln
aufgebaut: Nahkampf des Schwertkämpfers gegen `skelett` und `skelettwache`, Schwert zuerst
abgetrennt (Teil-HP) und danach getötet, ein wahnsinniges Skelett erschlägt ein anderes, Feuerball
(`fire_1`), Meteor (`fire_14`) und Urknall (Singularität, `arcane_14`, Seelenstufe 2).
Pro Frame wurde gemessen:
- Zeichnet das Rig den toten Gegner noch?
- Ist das Schwert gleichzeitig in der Hand und als Trümmer zu sehen?
- Wie bewegen sich die Trümmerteile, bis sie liegen bleiben?
- Fliegt die Waffe mit einem Körperteil mit, also nah dran, gleich schnell und im Haltewinkel?

Was **nicht** kaputt ist (gemessen):
- Ein toter Gegner wird nie weiter vom Rig gezeichnet. Die einzige Ausnahme ist der eine Tick
  zwischen hp ≤ 0 und dem Entfernen.
- Das Schwert ist nie gleichzeitig in der Hand und als Trümmer zu sehen. Wurde es vorher abgetrennt,
  verschwindet es aus der Hand und liegt sofort ruhig.
- Alle Trümmer liegen spätestens nach etwa 1,5 s still.
- Der lebende Gegner und seine Leiche nutzen denselben Actor-Schlüssel (`e<uid>`).
- Diese Pfade sind identisch und ebenfalls sauber:
  - Frostgruft: `frost_rigs` über `feel_e.dying_p`
  - Begleiter: `bone_warrior` gehört zur Skelett-Familie
  - Krypta-Hauptdungeon: `game.gd` → `dungeon_view` (4 Skelett-Tode geprüft)

Was **reproduziert** wurde:
- **Urknall, Tod an der Wand (u1):** Schwert v = (841, −68) px/s, Schädel v = (807, 2) px/s, Drehung
  des Schwerts nur 2,5 rad/s. Beide fliegen etwa 800 px deckungsgleich durch den Raum, das Schwert
  bleibt im Haltewinkel über dem Schädel. Das sieht aus wie ein Körper, der sein Schwert noch trägt.
- **Nahkampf gegen die Skelettwache:** 33 Frames, in denen die Waffe mit einem Körperteil mitfliegt.
- Bild: `vorher-urknall-schwert-fliegt-mit-schaedel.png` (Bilder 2–5: Schädel und Schwert ziehen
  zusammen nach links oben) und `vorher-skelettwache-nahkampf.png`.

### Ursache
In `src/rig/rig_renderer.gd` wurden gehaltene Gegenstände (`rig.items`: Schwert, Dolch, Schild,
Bogen) beim Zerfallen in `_piece()` genauso behandelt wie Körperteile:
- gleicher Schlagkegel (±0,6 rad)
- gleiches Tempo (`speed × Impuls × jitter`)
- gleicher Auftrieb
- eine zufällige Drehung zwischen −10 und 10 × Impuls, die oft fast 0 ist

Das Schwert in der Hand überlappt den Schädel. Deshalb startet es am selben Punkt mit fast derselben
Geschwindigkeit und dreht sich kaum: Es fliegt im Haltewinkel mit dem Körper mit. Mit der
Splat-Stufe des Urknalls (3,2 × Bildmaßstab) fliegt die ganze Gruppe quer durch den Raum.
`_fling_apart()` (Splat, nachdem der Tod schon begonnen hat) gab außerdem allen Teilen dieselbe Linie.

### Fix
- **`src/rig/rig_renderer.gd`:** Ein gehaltener Gegenstand (ein Teil mit `hand` oder `tip`) löst
  sich jetzt aus der Hand:
  - Seine Richtung wird um `loose.side` = 0,9 rad zur Seite der Hand aus der Schlagachse gedreht.
  - Tempo × 0,8 und Auftrieb × 0,5, damit er früher auf den Boden scheppert.
  - Er überschlägt sich immer, mit 9–15 rad/s × √Impuls in zufälliger Richtung.
  - Das gilt auch in `_fling_apart()`.
  - Neue Helfer `_loose()` und `_loose_spin()`; das Trümmerstück bekommt das Feld `held`.
  - Für Körperteile ändert sich nichts (gleiche Reihenfolge der Zufallszahlen).
  - Die Kopf-Doku der Datei ist ergänzt.
- **`assets/data/vfx_gore.json`:** neuer Eintrag `ragdoll.loose {side, speed, lift, spin}` plus
  Erklärung in `_ragdoll_note`. Die Werte sind ohne Code-Änderung einstellbar.

Damit bleibt eine Waffe entweder in der lebenden Hand oder fliegt als loses Trümmerstück davon,
nie beides. Allein weiteranimiert wird sie nie (das war auch vorher nicht der Fall, siehe oben).

### Vorher / Nachher (Messung)

| | Tode | Frames mit Waffe im Haltewinkel am Körper | Drehung der Waffe im Flug |
|---|---|---|---|
| vorher | 11 + Urknall-Einzellauf | 33 (Skelettwache) + Urknall u1 (≈ 25 Frames deckungsgleich, Drehung 2,5 rad/s) | 0–24 rad, oft fast keine Drehung im Flug |
| nachher | 26 (2× jeder Story-Fall + 4 im Krypta-Hauptdungeon) | 0 bei 25 von 26; einmal 3 Frames (Dolch der Skelettwache, rutscht schon am Boden) | 1,4–20 rad, jede Waffe überschlägt sich |

Bilder nachher:
- `nachher-urknall-schwert-lose.png`
- `nachher-urknall-vollbild.png` (unten links: das Schwert überschlägt sich getrennt vom Schädel;
  die beiden Skelette mit HP-Balken leben noch und taumeln mit ihrem Schwert in der Hand, so ist es
  gewollt)
- `nachher-skelettwache-nahkampf.png`
- `nachher-kryptahauptdungeon-skelettwache.png`

Tests: Ladeprüfung (`scripts/dev_load_check.gd`) OK für `rig_renderer.gd`, `drake_rig_host.gd`,
`hell_game.gd`, `dungeon_view.gd` und `companion_rigs.gd`. Die Proben liegen im Scratchpad; ihre
res://-Kopien sind gelöscht.

## 2. Gegner-Durchlauf (Krypta-Story, alle 18 Defs)

Jeder Gegner wurde einzeln gespawnt. Er kämpfte 3,3 s gegen den Schwertkämpfer, der passiv blieb
und laufend geheilt wurde, und wurde danach getötet. Gemessen wurden: ob er per Rig gezeichnet wird,
wie weit er läuft, gestartete und längste Attacke, Treffer am Helden, Rig-Zeichnungen nach dem Tod,
Trümmer, übrige Zonen und Schüsse, Konsolenfehler. Bilder: `sweep-board-0/1/2.png` (je Zeile ein
Gegner: 2 Kampfbilder, +6 und +40 Frames nach dem Tod).

Für alle 18 gilt:
- keine Konsolenfehler
- alle bewegen sich (80–693 px)
- 1–4 Attacken in 3,3 s, die längste dauert 0,9 s (keine hängende KI, keine endlose Attacke)
- kein Rig wird nach dem Tod gezeichnet
- keine gegnerischen Schüsse bleiben übrig
- keine grauen oder fehlenden Texturen

| Gegner | Rig | Befund | Status |
|---|---|---|---|
| skelett | skeleton | Schwert flog mit dem Schädel mit (Bug 1) | **behoben** |
| skelettschuetze | skel_archer | Bogen löst sich jetzt lose | behoben (Fix 1) |
| skelettwache | skel_guard | Dolch flog mit Körperteil mit (33 Frames) | **behoben** |
| nekromant | necro | Stab fällt als Trümmer, ok | – |
| zombie | tiny_zombie | Giftpfütze bleibt nach dem Tod etwa 2 s liegen (gewollter Rückstand) | ok |
| eiszombie | ice_zombie | starb in der Probe nach 1,1 s am Auto-Schwung des Helden (Bogen im Bild), bevor er angriff: Probe-Artefakt | ok |
| leerenbomber | bomber | keine Trümmer beim Tod (gewollt: die Familie zerplatzt violett); 2 Attacken in 3,3 s ohne Treffer am Helden | offen: nicht geklärt, ob die Explosion verfehlt oder nur die i-Frames greifen |
| mimik | mimic | ok | – |
| knochenwaechter | – (Atlas) | kein Teil-Rig: das Riesenschwert ist ins Atlasbild gemalt und stirbt mit der Atlas-Todesanimation, ohne Trümmer | **offen** (braucht Rig-Art in `rigs.json` und `rig` im Generator `krypta_monsters.js`; die JSON-Datei ist generiert) |
| grabmutter | – (Atlas) | kein Teil-Rig, Tod ohne Trümmer | **offen** (wie oben) |
| moderkoloss | big_zombie | Arm und Kopf fallen ab, der Rumpf spielt die Todespose, ok | – |
| nekromantenfuerst | – (Atlas) | kein Teil-Rig | **offen** (wie oben) |
| truhenfresser | – (Atlas) | kein Teil-Rig; starb in der Probe früh am Schwung des Helden | **offen** (wie oben) |
| frostleiche | frost_corpse | Eis splittert, Teile fallen, ok | – |
| archivar | – (Atlas) | kein Teil-Rig | **offen** (wie oben) |
| leerenbrut | – (Atlas) | kein Teil-Rig | **offen** (wie oben) |
| knochenkoloss | bone_colossus | ok, zerfällt | – |
| leerenrufer | void | Klauen fallen ab, Leerenflamme, ok | – |

Hinweis zur Probe (nicht untersucht): Die großen Gegner, die außerhalb von `populate()` per
`spawn()` gesetzt wurden, standen nach dem Kampf alle bei genau 1 HP. Das kann an der
Etagen-Skalierung liegen, die nur `populate()` setzt. Ein Bug ist damit nicht belegt.
