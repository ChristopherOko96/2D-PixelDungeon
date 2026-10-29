# Nachweis: 0x72-Gegner- und Boss-Varianten (Kandidaten, 29.10.2026)

**Nicht im Spiel.** Diese 21 Varianten sind Vorschläge zur Abnahme
(AGENTS.md, Abnahme neuer Grafik). `assets/data/rigs.json` ist unverändert;
die Kandidaten stehen nur in `rigs_variants.json` in diesem Ordner.

Alle Figuren sind unveränderte Einzelbilder aus 0x72 DungeonTileset II v1.7
(CC0). Neue Farben entstehen nur per Pipette: Jede Farbe wird exakt gegen eine
andere getauscht (hex→hex, ein Durchgang, die Umrisslinie #222222 bleibt).
Jedes Pixel bleibt an seinem Platz. Gegenstände wie Waffen und Schild werden nie
umgefärbt. Jede Figur ist im Krypta-Standard zerlegt: Jeder Körperteil hat ein
eigenes Rechteck und einen Drehpunkt und bewegt sich mit den Posen der
vorhandenen Familien (skeleton, necro, biped, brute) für sich.

## Bilder

- `roster.png`: alle Varianten nach Welt, jeweils Ruhe und Angriff.
- `<id>.png` je Variante, mit 4 Bildpunkten je Quellpixel. Oben stehen
  Original, Spiel-Umfärbung, Ruhe-Pose und die einzeln gezeigten Teile mit
  rotem Drehpunkt. Darunter folgen je 8 Bilder Stehen, Gehen und Angriff
  (Ausholen, Treffen, Zurück). Danach kommen Beschwören (Nekro-Familie) oder
  Brüllen und nachwachsender Arm (Bosse) oder der Schild-Block, dann Treffer.
  Bei „Teile ab“ wird jedes zerstörbare Teil abgetrennt, mit den echten
  Trümmern des Renderers; außerdem Kriechen ohne Beine und der hüpfende Kopf,
  wo die Figur das erlaubt. Zum Schluss der Tod.

Gezeichnet mit der echten `RigLibrary` und dem echten `RigRenderer` des Spiels.

## Liste

| ID | Name | Welt / Rolle | Quelle | Familie | Teile (HP-Gewicht) |
|---|---|---|---|---|---|
| crypt_zombie | Grabzombie | Krypta, Gegner | zombie_anim_f10 | skeleton | Beine 2/2, Rumpf 3 (+Beine), Kopf 3 tödlich |
| crypt_bone_lancer | Knochenlanzer | Krypta, Gegner | skelet | skeleton/sword | wie Skelett, Lanze 1 (kein Angriff) |
| crypt_cultist | Kultist | Krypta, Elite | masked_orc | skeleton/sword | Beine 2/2, Rumpf 4 unzerstörbar, Maske 3 tödlich, Opferdolch 1 |
| crypt_plague_doctor | Pestdoktor | Krypta, Elite | doc | necro | Mantel 6, Kopf mit Schnabel 6 (tödlich), Giftstab 2 (kein Zauber) |
| crypt_corpse_ogre | Leichenoger | Krypta, Mini-Boss | ogre | brute | Arm 20 (kein Angriff, wächst in 6 s nach), Rest unzerstörbar |
| crypt_soul_eater | Seelenfresser | Krypta, Mini-Boss | big_demon | brute | Klaue 20 (kein Angriff, 6 s), Rest unzerstörbar |
| frost_ice_elf | Eiself | Frostgruft, Gegner | elf_m | skeleton/bow | Beine und Rumpf unzerstörbar, Kopf 3 tödlich, Bogen 1 |
| frost_ice_elf_f | Eiselfe | Frostgruft, Elite | elf_f | skeleton/sword | Beine und Rumpf unzerstörbar, Kopf 3 tödlich, Eisdolch 1 |
| frost_frostling | Frostling | Frostgruft, Gegner | tiny_zombie | biped | Füße 1/1, Kopf 2 tödlich |
| frost_ice_goblin | Eisgoblin | Frostgruft, Gegner | goblin | skeleton/guard | Beine 2/2, Rumpf 3 (+Beine), Kopf 3, Dolch 1, Schild 3 (kein Block) |
| frost_shaman | Frostschamane | Frostgruft, Elite | orc_shaman | necro | Kutte 6, Kopf 6 (tödlich), Eisstab 2 (kein Zauber) |
| frost_necro | Frostnekromant | Frostgruft, Mini-Boss | necromancer | necro | Kutte und Kopf unzerstörbar, Stab 2 (kein Zauber, wächst in 8 s nach) |
| frost_giant | Frostriese | Frostgruft, Boss | ogre | brute | wie Leichenoger |
| frost_demon | Frostdämon | Frostgruft, Boss | big_demon | brute | wie Seelenfresser |
| hell_chort | Hornteufel | Hölle, Gegner | chort | skeleton/sword | Beine 2/2, Rumpf 4 unzerstörbar, Kopf 3 tödlich, Speer 1 |
| hell_wogol | Glutwanst | Hölle, Gegner | wogol | skeleton | Beine 2/2, Glutbauch 4 unzerstörbar, Kopf 3 tödlich |
| hell_orc | Höllenork | Hölle, Elite | orc_warrior | skeleton/sword | Beine 2/2, Rumpf 4 unzerstörbar, Kopf 3, Kriegsaxt 1 |
| hell_pumpkin | Glutkürbis | Hölle, Gegner | pumpkin_dude | skeleton | Beine 2/2, Rumpf 3 unzerstörbar, Kürbiskopf 4 tödlich |
| hell_glutkoloss | Glutkoloss | Hölle, Mini-Boss | big_zombie | brute | wie Moderkoloss |
| hell_ogre | Höllenoger | Hölle, Mini-Boss | ogre | brute | wie Leichenoger |
| hell_archdemon | Erzdämon | Hölle, Boss | big_demon | brute | wie Seelenfresser |

Die Pipette jeder Figur steht oben auf ihrem Bild. In der Frostgruft werden
nur kalte 0x72-Farben verwendet, in der Hölle die Werte aus
`scripts/make_hell_skin.gd` (r0–r3, l0–l4).

## Bitte beim Ansehen prüfen

- **Eiself:** weißes Haar, eisblauer Kittel, die Augen bleiben im 0x72-Blau
  #5698cc (wie gewünscht). Kittel und Augen haben dadurch dasselbe Blau.
  Variante B auf dem Bild: leuchtende Augen #72d6ce.
- **Pestdoktor und Frostschamane** nutzen die Nekromanten-Pose. Diese schwebt
  3 ± 1,5 Pixel über dem Boden, und man sieht ihre Füße schweben. Ohne Schweben
  bräuchte es eine neue Posen-Familie (Änderung in src/rig).
- **Oger:** Im 0x72-Bild hält der Oger keine Keule (die Diagonale ist ein
  Tragegurt), daher heißt das Teil „Arm“ statt „Keulenarm“.
- **Großer Dämon:** Er ist ein laufendes Maul ohne Arme. Als „Klaue“ dient der
  Lappen mit Krallen oben links. Der Kopf ist der Oberkiefer: Beim Angriff und
  beim Brüllen öffnet sich das Maul.
- Große 0x72-Waffen (Speer 30 px, Stäbe 30 px) wirken an 16-px-Figuren groß,
  so wie der Stab des Krypta-Nekromanten.
- Die Größen-Faktoren für Frostgruft (1,5 / 2,4) und Hölle (1,7 / 2,1) sind
  Vorschläge. Geprüft werden sie erst beim Einbau.

## Erzeugen

```
node production/art-proof/0x72-style/export_rigs.js --variants
godot --path . --resolution 1280x720 -s res://scripts/preview_0x72_variants.gd -- res://production/qa/evidence/0x72-variants
godot --headless --path . -s tests/rig_variants_test.gd
```
