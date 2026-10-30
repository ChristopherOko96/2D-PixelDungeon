# VFX-System: ein Effekt-System für alle Welten

**Stand:** 2026-10-29 · Etappe 1 umgesetzt (Treffer-Gefühl wie in der Krypta in Hölle und Frostgruft)

## Entscheidung (Nutzer, 2026-10-29)

- **Ein System mit Weltfarben:** Alle drei Welten reagieren gleich stark und auf dieselbe Weise. Nur Material und Farbe passen zur Welt (Knochen, Eis, Glut, Seele …).
- **Maßstab ist die Krypta:** „Das Treffergefühl eher so wie bei der Krypta.“ Hölle und Frostgruft nutzen deshalb das echte Krypta-Modul `src/vfx/feedback.gd`, keine Nachbildung.
- **Umfang:** Mob-Effekte, Spieler-Effekte und Figuren-Animationen. Ein Regler „Effekte reduzieren“ war nicht gewünscht.
- **Reihenfolge:** Erst den Hell-Dungeon angleichen, dann Mobs, dann Spieler, dann Animationen.

## Aufbau

```
Hölle / Frostgruft (src/hell/hell_game.gd, src/hell/hell_monsters.gd)
   │  Treffer, Tod, Schild, Schaden am Helden, Schüsse, Hiebe, Erscheinen, Level-up
   ▼
src/hero/story_feel.gd      übersetzt in einen Krypta-Snapshot (Krypta-Einheiten = Welt-px / scale)
   ▼
src/vfx/feedback.gd         die Krypta-Reaktionen (unverändert in der Krypta)
   ├─ src/vfx/particles.gd  Partikel mit Physik, Lachen, Tropfen, Bodenpixel (eigene Ebenen, z 5/12/11)
   └─ src/vfx/fx_sprites.gd Effekt-Sprites (geteilt mit story_skill_fx, an Wänden geschnitten)
```

`story_feel.gd` gibt der Welt die Krypta-Pose jeder Figur zurück: Stauchen, Kippen, Atmen, Hüpfen beim Laufen, Umfallen und Ausblenden. Dazu kommt der Treffer-Blitz als Silhouette in der Blitzfarbe, wie `dungeon_view.gd`.

| Ereignis | Reaktion (Werte aus `feedback.gd`) |
|---|---|
| Normaler Treffer | rote Silhouette 0,08 s, Stauchen und Kippen mit Federnachschwingen, Funken, Treffer-Sprite, Tropfen fallen zu Boden; Flüssiges spritzt, Knochen splittert; **kein Hitstop**, leichtes Wackeln |
| Tod | weiße Silhouette, Bodenpixel springen auf, Ausbruch im Material, Staub, Lache am Boden, Tod-Sprite des Materials, Wackeln, Hitstop 0,07 s (Boss 0,18 s); Monster ohne eigene Todesanimation fallen um und blassen aus |
| Verwundet (unter 60 %) | Tropfspur beim Laufen (Flüssigkeiten) |
| Schild blockt | helle Silhouette, Funken |
| Erscheinen | Staubwolke |
| Held getroffen | rote Silhouette, Blut und Lache, Wackeln, Hitstop 0,05 s |
| Held schießt / schlägt | Rückstoß-Stauchen / Lehnen in den Hieb, Hieb-Sprite |
| Level-up | Level-up-Sprite |
| Boss-Angriff schlägt ein (`frost_moves.gd`) | Krypta-Ausbruch des Stils (Eis, Leere, Gift, Feuer, Erde) |

Schritte und Knurren kommen aus `theme.feel` (`step_every`, `idle_gap`, `idle_range`). Hitstop und Wackeln übernimmt die Welt: `hell_game._process` hält das Bild, die Kamera übernimmt das Wackeln wie `dungeon_view.gd` (Trauma² × 9 Krypta-px).

## Materialien (`assets/data/vfx_gore.json`)

Eine Tabelle für alle Welten. `kinds` ordnet Gegner-Arten oder Höllen-Monster-IDs einem Material zu. Ein Gegner darf sein Material auch direkt nennen (Frostgruft: `def.material`).

| Material | Wo | Tod-Sprite |
|---|---|---|
| bone | Skelette, Frost-Skelett, Eisritter, Brandskelett | stone_burst |
| blood | Nekromant, Held, Höllenhund, Dreischlund, Glutimp, Kettenschinder, Kerkermeister | blood_burst |
| slime | Mini-Zombie, Moderkoloss | poison_burst |
| frost | Eis-Zombie, Frostleiche, Eisschleim, Frostkobold, Frostwirbel, Eiskristall | frost_burst |
| void | Leerenbomber, Krypta-Boss | void_burst |
| ember | Glutschädel, Ignaroth 1–3 | fire_burst |
| magma | Magmaschleim, Kesselbrut | fire_burst |
| ash | Aschenpriester | dust |
| soul | Peingeist, Seelenhirte, Klagender Hüter | arcane_burst |
| obsidian | Glutwächter, Ignaroth Obsidianform | stone_burst |

## Element-Reaktionen mit Wirkung (Nutzer, 2026-10-30)

Bis hierher zeigt die Elementphysik Reaktionen nur an. Am 30.10.2026 hat der Nutzer entschieden, dass fünf davon auch im Spiel wirken. Sie treffen nur Gegner, nie Helden. Die Werte stehen in `src/data/balance.json` unter `element`.

| Reaktion | Wirkung | Code |
|---|---|---|
| Blitz + Wasser, Gift oder Blut | Die Pfütze ist 3 s geladen. Gegner darin bekommen alle 0,5 s Schaden und werden betäubt. Die Pfütze knistert überall. | `boss_moves.gd` `electrify` |
| Feuer + Gift (Pfütze oder Gas) | Explosion mit Flächenschaden. Das Gift ist danach weg, Gift daneben geht mit hoch. | `elements.gd` `fire_at` |
| Frost + Wasser | Glatteis für 8 s: Gegner werden langsamer und rutschen. Es leitet keinen Blitz. Feuer taut es wieder auf. | `elements.gd` `frost_at` |
| Feuer oder Lava + Wasser | Dampfwolke: verbrüht und blendet die Gegner (sie schießen nicht). | `elements.gd` `_boil` |
| Wasser + Lava | Die Lava ist 4 s lang Kruste und harmlos, das Wasser verdampft. | `elements.gd` `_lava_meets_water` |

Auslöser sind die Testraum-Werkzeuge, Feuer- und Frost-Talente (`talent_combat.gd` `_element`), die Lava-Spur und der Kettenblitz (`hero_skills.gd`) sowie Feuer- und Eisschläge der Bosse. Die Clients sehen die Reaktionen über `fx_events` vom Typ `element`, über die Felder `ch` und `cr` der Pfützen im Snapshot und über `element_gas`. Tests: `tests/element_charge_test.gd`, `tests/element_reactions_test.gd`. Bilder: `production/qa/evidence/wasser-blitz/`.

## Was beim Umbau wegfiel

Die Frostgruft-Schicht aus Commit 2386478 (`src/hell/frost_feel.gd`) ist durch `story_feel.gd` ersetzt:
- Ihre Pfeilspuren, Zauberkugeln, Mündungsblitze und Hieb-Sicheln lagen doppelt über denen der Krypta (`story_hero.gd` mit `attack_fx.gd` und `hero_look.gd`).
- Ihre Treffer wichen von der Krypta ab: Hitstop bei jedem Treffer, weißer Blitz, runde Flecken.

Übernommen wurden Schritte, Knurren und die Ausbrüche der Boss-Angriffe.

## Etappen

1. **Hell-Dungeon und Frostgruft wie Krypta** – umgesetzt (siehe oben).
2. **Mob-Effekte:** Aufladen vor dem Angriff (Krypta-Pose „windup“, Angriffs-Stauchen und Staub), Zustände an Mobs (brennt, vergiftet, gefroren, verlangsamt), Boss-Aura, Effekte je Höllen-Angriffsart. Offen.
3. **Spieler-Effekte:** Warnung bei wenig Leben, Schritte je Welt (Staub, Schnee, Asche), Aufsammeln, Ausweichen. Offen.
4. **Figuren-Animationen:** Bewegungen für jede Klasse und jeden Mob. Die Krypta-Posen gibt es jetzt überall; eigene Animationen fehlen. Offen.

## Prüfung

- Test `tests/frost_combat_test.gd`: Krypta-Treffer ohne Hitstop, rote Silhouette, Stauchen und Kippen, Lache und Hitstop beim Tod, Umfallen, Held getroffen; Höllen-Monster im eigenen Material, mit eigener Todesanimation.
- Aufnahmen `scripts/capture_story_feel.gd` → `production/qa/evidence/vfx-story-feel/`: je Welt Treffer, Tod, Boden danach und Held getroffen, jeweils mit Nahaufnahme (`-nah`).
