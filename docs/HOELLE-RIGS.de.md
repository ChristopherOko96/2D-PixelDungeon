# Höllen-Rigs: Körperteile wie in der Krypta

**Stand:** 2026-10-29 · vom Nutzer freigegeben: Zuordnung wie unten, Ignaroth zuerst, andere Bosse wachsen nach 12 s nach (VFX-Etappe 4 „Figuren-Animationen“, zuerst Hölle)

## Auftrag (Nutzer, 2026-10-29)

- Das Krypta-System mit den Skeletten, Untoten und dem Leeren-Boss kommt in die Figuren der Hölle.
- Die Teile sind **nicht gleichzeitig animiert**: jedes Teil auf eigener Kurve, wie beim Leerenrufer.
- Bestimmte Körperteile lassen sich **abtrennen**. Das **unterbindet oder schwächt** den Angriff, an dem sie hängen.
- Das **wankige Gefühl** des Leeren-Bosses wird übertragen.
- Ignaroth darf optisch neu werden, **bleibt aber ein Drache mit seinen vier Formen**: Salamander (Etage 3), Jungdrache (6), Glutdrache (9), Obsidianform (10). Die Formen 1–3 verwandeln sich bei 0 LP und fliehen, nur Form 4 stirbt.
- Erst die Hölle, dann prüfen, dann gegen recherchierte Kriterien abgleichen.

## Technischer Weg

```
tools/hell_dungeon/hell_monsters.js   jede Zeichengruppe bekommt einen Teilnamen (P.part) und Gelenke (P.joint)
        │  export_monsters.js --rigs
        ▼
assets/sprites/hell/rigs/<id>_<teil>.png  (+ Flammen-Teile als 4er-Flipbook)
assets/data/hell_rigs.json             Teile, Drehpunkte, Eltern, z, LP-Gewicht, sperrt/schwächt
        ▼
src/rig/rig_library.gd   lädt hell_rigs.json (Schichten-Rig, Teile als eigene Bilder)
src/rig/rig_poses.gd     neue Familien (Drache …): eigene Perioden je Teil, Peitschen-Nachziehen
src/rig/rig_renderer.gd  zeichnet wie in der Krypta (Splitter beim Abtrennen, Nachwachsen)
src/combat/body_parts.gd LP je Teil, abtrennen, sperren (+ neu: schwächen)
        ▼
src/hell/hell_monsters.gd / hell_game.gd   Treffer auf das getroffene Teil, Angriffe prüfen das Teil
```

Gleiche Module wie in der Krypta, keine Kopie.

## Bewegung: das wankige Gefühl, aber nicht im Gleichschritt

Die Werte orientieren sich am Leerenrufer (`rig_poses.gd` `void_lord`):
- Schwebe- oder Atembewegung des Körpers auf Perioden, die nie zusammenfallen: 2,2 s Heben, 1,1 s Atmen, 1,9 s Gliedmaßen.
- Gespiegelte Gliedmaßen laufen mit Versatz (0,7 rad).
- Hals- und Schwanzglieder laufen als Kette, Glied i mit A·sin(ωt − i·Δ). Die Spitze schwingt nach und weiter aus als die Wurzel.
- Angriffe in drei Abschnitten: Ausholen, Zuschlagen, Zurückfedern. Das Teil, das den Angriff trägt, bewegt sich beim Ausholen am stärksten.
- Treffer: Rückstoß mit Stauchen. Tod: Teile fallen als Splitter, der Rest kippt.

## Ignaroth: Teile und was das Abtrennen bewirkt (Vorschlag)

Kopf, Rumpf und Beine sind **nicht abtrennbar**: Nur die Lebensleiste beendet eine Form, wie bei den großen Krypta-Gegnern. Jedes abtrennbare Teil hat 8–20 % der Lebenspunkte der Form, alle zusammen höchstens 60 %. Jeder Treffer zählt voll gegen die Lebensleiste.

| Form | Teil | Wirkung beim Abtrennen |
|---|---|---|
| **1 Salamander** | Kiefer | Spucke **unterbunden** |
| | Vorderklaue | Graben: Ring 10 → 5 Geschosse |
| | Schwanz | Huschen und Satz 40 % schwächer (Tempo, Radius) |
| **2 Jungdrache** | Kiefer | Salve 3 → 1 Geschoss |
| | Schwanz | Schwanzwirbel **unterbunden** |
| | Klauen | Lavabruch: Ring 16 → 8, keine Lava |
| **3 Glutdrache** | Flügel links / rechts | Bombenflug: ein Flügel −50 % Dauer, beide **unterbunden** (am Boden) |
| | Kehle (nur während des Atems treffbar) | Feueratem **unterbunden** |
| | Hörner | Fächer 7 → 3 Geschosse |
| **4 Obsidianform** | 3 Leerenkristalle | je ein Strahl weniger (3 → 0) |
| | Flügel links / rechts | Leerenregen: −50 % / **unterbunden** |
| | Kehle (nur während des Atems treffbar) | Leerenatem **unterbunden** |
| | Hörner | Echos: 3 → 1 frühere Form |

- **Nachwachsen:** Bei Ignaroth wächst innerhalb einer Form nichts nach. Jede neue Form kommt vollständig.
- **Rückmeldung beim Abtrennen:** kurzer Hitstop, Blitz, Splitter im Material (Glut, Obsidian), eigener Ton, eine glühende Wunde am Gelenk und 1 s Taumeln ohne neuen Angriff.

## Die anderen Höllen-Bosse und Monster (Vorschlag, danach)

| Figur | abtrennbar → Wirkung |
|---|---|
| Glutwächter | Fäuste → Stampfer schwächer · rechter Arm → Brocken unterbunden · Lavakern (nur beim Kernbruch treffbar) → Kernbruch unterbunden |
| Dreischlund | 2 Seitenköpfe → Atem 3 → 2 → 1 Kopf, Rudelruf schwächer |
| Kesselbrut | Arme → Brut unterbunden · Kesselrand → Überkochen schwächer |
| Seelenhirte | Laterne → Spirale schwächer · linke Hand → Seelenherde unterbunden · Hirtenstab → Ruf unterbunden |
| Kerkermeister | Hakenarm → Haken unterbunden · Hackbeil → Spalter schwächer |
| Klagender Hüter | Arme → Hände 5 → 2 · Ketten → Tränenring schwächer |
| kleine Monster | wie die Krypta-Skelette: Waffe oder Werkarm sperrt den Angriff (Brandskelett-Schwert, Imp-Wurfarm, Priester-Stab, Kettenkugel, Peingeist-Hände, Höllenhund-Kiefer); kleine dürfen einen tödlichen Kopf haben |

Andere Bosse lassen Teile nach 12 s nachwachsen, wie der Leerenrufer: mit 1 s Leuchten vorher und halben Lebenspunkten.

## Kriterien (Recherche, Auszug)

Geprüft wird per Test und Aufnahme:
- **ANIM-01:** Kein Gleichschritt. Bewegte Teile erreichen ihren Ausschlag mindestens 0,08 s versetzt.
- **ANIM-02:** Ketten ziehen nach. Jedes Kind kommt 0,04–0,30 s nach seinem Elternteil, die Spitze schwingt mindestens 1,2× so weit wie die Wurzel.
- **ANIM-04:** Lesbares Ausholen. Mindestens 0,45 s, bei Flächenangriffen 0,8 s, und das tragende Teil bewegt sich am meisten.
- **ANIM-05:** Stauchen hält das Volumen (sx·sy zwischen 0,92 und 1,08), die Füße bleiben am Boden.
- **ANIM-06:** Lebendiges Stehen. Mindestens 3 Teile auf mindestens 2 Perioden, die sich nicht ganzzahlig teilen.
- **PART-01:** Jedes Abtrennen hat Wirkung: Der Angriff entfällt oder ein Wert sinkt um mindestens 30 %. Ein im Ausholen abgetrenntes Teil bricht den Angriff ab.
- **PART-02:** Das Teil fällt als Splitter, eine Wunde bleibt.
- **PART-03:** Hitstop, Blitz, eigener Ton und Taumeln beim Abtrennen.
- **PART-05:** Teile-Anteile fair verteilt, jeder Treffer zählt zur Lebensleiste.
- **BOSS-01:** Genau 4 Formen mit ihren Etagen und Angriffen. Formen 1–3 fliehen, Form 4 stirbt.
- **BOSS-04:** Ein Flug dauert höchstens 4,6 s. Danach landet er, und man hat mindestens 2 s Zeit zu treffen.
