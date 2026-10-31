# Befund: Die drei Magier im Testraum, visuell geprüft (2026-10-31)

Prüfer: technical-artist (nur Aufnahme und Urteil, kein Spielcode und keine Daten geändert).
Maßstab: der Satz des Nutzers „alles physikalisch, jeder Pixel, der Gegner als Ragdoll“,
dazu `docs/ZAUBER-SPRACHE.de.md`, `docs/ELEMENT-PHYSIK.de.md` und die Game-Feel-Regeln
(Rückmeldung in Schichten, Gewicht nach Wichtigkeit, kurze Übertreibung, dann Ruhe).

## Wie aufgenommen

- Testraum der Krypta (`game.start_test_arena("mage")`), Leiste: Spezialisierung Feuer / Frost /
  Leere, Ultimate STUFE 3, alle Talente auf vollem Rang. Fenster 1280x720, `--fixed-fps 60`, damit
  die Bilder in gleichen Spielzeit-Abständen liegen.
- Je Talent: Gruppe aus 2 Skeletten, Mini-Zombie und Mimik (3 mit 1 LP, damit sie sterben, ein
  Skelett mit 400 LP als Überlebender). Der Grundschuss jeder Spezialisierung je einmal in eine
  Gift- und eine Wasserpfütze (Leere: beide Pfützen in einem Schuss). Schilde: 2 Skelette direkt
  am Helden. Die Singularität: 4 Gegner mit 400 LP (sterben erst am Urknall).
- Bilder: alle 3 Frames über 1,2 s (Ultimates und Zonen alle 5 Frames über 2,5 s, Singularität
  alle 7 über 7 s) plus späte Bilder bei 2,5 s / 4 s. Gemessen: die Rig-Trümmer jedes toten Gegners
  4 und 60 Frames nach dem Tod, die Partikelzahl und die Frame-Zeit.
- Zwei Läufe. Lauf 1 war verschmutzt (Beute der Mimik leuchtete unter dem Ziel, Perk-Wörter,
  alte Lachen). Lauf 2 räumt zwischen den Takes ab (Beute, Mana-Kugeln, Talent-Reste,
  Lachen-Ebenen). **Die Bilder hier stammen alle aus Lauf 2.**

| Datei | Inhalt |
|---|---|
| `kontakt-feuer.png` | 11 Reihen: Zuordnung nur Zombie / nur Mimik, Feuerball (Gruppe, Gift, Wasser), Infernospeer, Glutkette, Flammenmeer, Phönixschritt, Pyro-Monster, Meteor |
| `kontakt-frost.png` | 9 Reihen: Frostlanze (Gruppe, Wasser, Gift), Splittersalve, Blizzard, Frostsprung, Kristallschild, Wasserelementar, Gletschergrab |
| `kontakt-leere.png` | 8 Reihen: Leerengeschoss (Gruppe, Gift + Wasser), Leerenlanze, Leerenriss, Raumsprung, Nachhall, Leerenschild, Singularität (ganzes Bild, halbe Größe) |
| `zoom-schluesselbilder.png` | 20 Schlüsselbilder 2x vergrößert (Reihen A–E, unten zitiert als „Zoom A2“ usw.) |
| `bild-*.png` | einzelne Bilder in voller Größe, unten zitiert |
| `lauf2-messungen.log` | die Messzeilen (`RAG` Trümmer, `TAKE`, `BENCH`) |

Jede Reihe eines Kontaktbogens: 6 Takte ab dem Cast (Beschriftung `fN t=…`) und 2 späte Bilder.

## Urteil je Spezialisierung

**Feuermagier.** Am weitesten: der Feuerball hat Blitz-Frame, Druckringe und Glut, die liegen
bleibt. Die Gift-Explosion und der Dampf aus Wasser lesen sich sofort (Feuer-Bogen Reihe 4/5),
der Meteor ist das größte Bild der Klasse. Was fliegt, ist aber zu einem guten Teil gemalt
(Funken-Bögen, Zungen, weicher weißer Glow-Fleck). Die Körper reagieren auf einen Meteor genauso
wie auf einen Feuerball: 5 Skelett-Teile hüpfen etwa 40 px weit und sind nach 3 s weg.

**Frostmagier.** Die Frostlanze zerspringt sauber, Wasser friert sichtbar zu Glatteis, auf dem die
Knochen liegen (Frost-Bogen Reihe 2). Das Gletschergrab ist das stärkste Ultimate-Bild. Zwei
Brüche: Die Gegner sterben beim Gletschergrab schon im Cast-Frame, eine halbe Sekunde vor der
Landung. Und die Splitter des Bilds sind gemalt (Flugbahn als Formel); nur die Partikel-Splitter
darunter sind echte Physik.

**Leerenmagier.** Die Implosion liest sich (dunkler Kern, Sog), und das Schlucken von Gift und
Wasser funktioniert (Leere-Bogen Reihe 2: beide Lachen verschwinden in violettem Rest). Das
Urknall-Ragdoll ist aber kaputt: Die Körper fliegen an die Wände, ihre Teile bleiben in der Mitte
liegen. Die ausgestoßenen Gefüge-Lachen sitzen wie Aufkleber im ganzen Raum. Im Kollaps fällt die
Bildrate sichtbar ein (Overlay „5 FPS“). Raumsprung und Leerenschild sind die schwächsten
Rückmeldungen der Klasse.

## Verbesserungen, nach Wirkung sortiert

Physik der Pixel und Ragdoll stehen zuerst. Aufwand: S = bis ½ Tag, M = 1–2 Tage, L = mehr.

### 1. Urknall: Die Körperteile fliegen nicht mit an die Wand (Ragdoll greift nicht) — M

- **Gesehen:** `bild-urknall-teile-bleiben-mitte-f287.png` (0,8 s nach dem Kollaps): Schädel,
  Rumpf und Schwerter von zwei Skeletten liegen mitten auf dem Leerenfleck, während die Körper an
  die Wände geschleudert wurden. Gemessen (`RAG 08-singularitaet`): Die Trümmer liegen 532–546 px
  vom Körper entfernt. Alle vier Gegner sterben im Kollaps-Frame (`died_at=240`).
- **Warum zu wenig:** Das ist der Moment, den der Nutzer meint: ein Gegner als Ragdoll, der an
  die Wand klatscht. Gerade dort fallen die Teile aber auf der Stelle zusammen.
- **Ursache im Code:** `rig_renderer._start_death` läuft, sobald die LP im Kollaps auf 0 fallen,
  und löst die Teile dort (`_detach` aus `a.world`). Danach zeichnet `draw_enemy` sterbende
  Skelette nicht mehr (`return NAN`), also bleibt `a.feet` in der Mitte. Der `splat` an der Wand
  ruft `fling_near(punkt, dir, power, 48)`, sucht im Umkreis von 48 px um den Wandpunkt, findet
  das Rig nicht und schleudert deshalb nichts.
- **Fix:** (a) Host: Ein geschleuderter Gegner stirbt erst beim Wandtreffer (`wall_kill` setzt
  `hp = 0` beim Aufprall, nicht beim Kollaps). Bis dahin fliegt er ganz, mit Drehung. (b) `splat`
  trägt die Gegner-ID; `fling_near` sucht über den Schlüssel `e<id>` statt über die Nähe.
  (c) Sterbende Rigs, deren Snapshot-Position sich bewegt, nehmen ihre frischen Trümmer mit
  (`vx/vy` = Snapshot-Geschwindigkeit). Werte aus `vfx_gore.json splat.fling` (speed 150 × power,
  lift 120–220) passen, sobald der Treffer stimmt.

### 2. Rig-Trümmer: kein Treffer-Impuls, keine Wände, gleiches Gewicht für jeden Zauber — M

- **Gesehen:** Feuer-Bogen Reihe 3 (Feuerball) und Reihe 11 (Meteor), Zoom B1–B3: Die Teile hüpfen
  ein Stück und liegen. Gemessen über alle 26 Takes für Skelette: Start-Geschwindigkeit am Boden
  12–45 px/s, Flughöhe immer 17–18 px, Weg 37–50 px. Die Richtung ist zufällig (`dir_dot` zur
  Schussrichtung zwischen −0,6 und +1,0). Meteor (huge) und Feuerball (medium) sehen gleich aus.
- **Warum zu wenig:** Ohne Impuls aus der Trefferrichtung gibt es kein Ragdoll, nur ein
  Auseinanderfallen. Gewicht nach Wichtigkeit fehlt ganz.
- **Code:** `rig_renderer._detach`: `vx = rand(-56, 56) * impulse`, `vz = rand(70, 140) * impulse`,
  kein `vy`. `_start_death` ruft für Skelette immer `impulse 1.0`. `step()` bewegt `x/y` ohne
  Wandtest (es gibt keine `solid()`-Abfrage), es gibt keine Reibung beim Rutschen, nur beim
  Aufprall, und keine Kollision der Teile untereinander.
- **Fix:** Snapshot-Feld je sterbendem Gegner `kill = {dir, tier}` (der Host kennt Talent und
  Richtung). `_start_death` gibt Richtung und Impuls weiter: small 1,0 / medium 1,6 / large 2,4 /
  huge 3,5. `v = dir · 90 px/s · impulse · rand(0,6–1,2)`, gestreut um ±0,6 rad, `vz` mit
  √impulse, Drehung proportional zum Impuls. In `step()` wie `particles._move`: Wand-Reflexion
  über `particles.solid()` (wall_bounce 0,4), Bodenreibung ≈ 9/s beim Rutschen, einfache
  Kreis-Trennung der Teile (r ≈ 6 px), damit sie sich stoßen und stapeln. Budget: höchstens
  ~60 Trümmer je Raum, das kostet weit unter 0,1 ms.

### 3. Liegengebliebene Teile verschwinden nach 3 s per Transparenz — S/M

- **Gesehen:** `bild-feuerball-teile-weg-nach-4s-l240.png` und Zoom B3 → B4: Nach 2,5 s liegen
  Knochen noch, nach 4 s ist alles weg. Übrig bleiben Schleim und Ruß.
- **Warum zu wenig:** Der Nutzer will Teile, die liegen bleiben. Außerdem bricht es die eigene
  Regel „Ausblenden nur per 4x4-Dither, nie Transparenz“ (ZAUBER-SPRACHE §1).
- **Code:** `_detach` setzt `max = 3.0` für Krypta-Skelette; `draw_under` blendet mit
  `Color(1, 1, 1, fade)` aus.
- **Fix:** Ein ruhendes Teil wird in die Bodenmarken von `particles.gd` eingebacken (Textur des
  Teils, mit Drehung, in den Chunk-Image blitten, wie `_settle` es mit Pixeln macht). Dann
  bleibt es bis zum Raumwechsel und kann von `kick`/`blow` wieder als lose Pixel aufgewirbelt
  werden. Wenn das zu teuer ist: höchstens 40 ruhende Teile je Raum, das älteste wird
  eingebacken, und ausblenden nur per `PixelPaint.shown`-Dither.

### 4. Mini-Zombie und Mimik: kein Ragdoll, dafür flache graue Platzhalter-Vierecke — M

- **Gesehen:** Feuer-Bogen Reihen 1/2 (nur Zombie, nur Mimik), Zoom A1–A4,
  `bild-mimik-tod-graue-vierecke-f036.png`: Beim Tod fliegen hellgraue, untexturierte Vierecke
  und Dreiecke von 20–40 px weg, weich, ohne Kontur, nicht im 2-px-Raster. Sie erscheinen in jedem
  Take, in dem ein Zombie oder eine Mimik stirbt, nie bei einem einzelnen Skelett. Rig-Trümmer
  sind es nicht (alle geloggten Trümmer-Texturen sind normale 16x16-Teile). **Woher sie kommen,
  ist nicht geklärt.**
- **Ragdoll:** Der Zombie verliert 1 Teil (Fuß), der Körper spielt seine Todespose und ist weg.
  Die Mimik hinterlässt nur `_burst_at`-Funken: 2-px-Quadrate ohne Boden, die per Alpha
  ausblenden.
- **Warum zu wenig:** Der Zombie ist der „fleischige“ Gegner, an dem Ragdoll am meisten auffiele.
  Die grauen Flächen sind sichtbar Platzhalter.
- **Fix:** In `_start_death`: `biped` löst alle Teile mit Impuls (wie Punkt 2), dazu Fleisch über
  `particles.splat_burst(.., "slime")` bzw. „blood“ und Tropfen (`particles.drops`). Die `mimic`
  zerlegt sich in Deckel, Zahnreihe und Kasten als 3 Trümmer, dazu Holzsplitter
  (`particles.chips`) und springende Münzen (gold aus `splat_burst`). Die Quelle der grauen
  Flächen suchen: der Todespfad der Nicht-Skelett-Rigs bzw. Sprites für `tiny_zombie`/`mimic` in
  `dungeon_view.gd` (`dying`-Zweige um Zeile 1057/1095), `feedback.gd` (Kill-Gore) oder eine
  fehlende Textur.

### 5. Gemalte statt simulierte Materie in den Einschlägen — L (in vielen S-Schritten)

Diese Pixel sind Formeln über die Zeit `p` (`pos = at + v·t − Parabel`). Sie prallen nicht ab,
treffen keine Wand (werden dort nur abgeschnitten), landen nicht und dithern weg, statt zu liegen:

| Effekt | Code | Gesehen |
|---|---|---|
| Funken-Bögen des Booms | `talent_pixels.gd boom` (sparks) | Feuer Reihe 3, f24–f36 |
| Rand-Trümmer jeder Nova (Glut steigt per `sin`, Eis-Chips linear, Motten) | `talent_pixels._debris` | Leerenriss, Novas |
| Eissplitter des Shatter, „liegen als Reif“ per smoothstep-Ausblenden | `talent_pixels.shatter` (shards, mist) | Zoom D1/D2 |
| Motten der Implosion (Spirale per Formel, dann Ausbruch per Formel) | `talent_pixels.implosion` | Leere Reihe 1, f24–f36 |
| Motten des Leerenrisses, Kometen des Urknalls, Strom beim Schlucken, Fesseln | `rift`, `comets`, `stream` (Bezier), `tether` | Leere Reihe 4 und 8 |
| Flocken und Splitter im Blizzard (Umlaufbahnen) | `talent_pixels.blizzard` | Frost Reihe 5 |
| Starre Flammen-Kegel im Meteorkrater (wie Pylonen) | `talent_pixels.crater` / `_tongue` | Zoom C3/C4, `bild-meteor-einschlag-f065.png` |
| Chips beim Abtrennen, Tod-Funken, Slam-Staub der Rigs (2-px-Quadrate, Alpha, kein Boden) | `rig_renderer._particles` / `_burst_at` | Zoom A, alle Tode |
| Große Todeswolken (beige Blumenkohl-Wolke beim Skelett, grüne beim Zombie), in jeder Spezialisierung gleich | Todes-/Gore-Effekt | Frost Reihe 2 f24, Leere Reihe 1 f24, Feuer Reihe 6 f24 |

- **Warum zu wenig:** Das ist genau „jeder Pixel“. Die echte Physik steht schon in
  `particles.gd` (Schwerkraft, Wandprall, Rutschen, Liegenbleiben, Einbacken), wird aber
  zusätzlich zur gemalten Kopie benutzt statt an ihrer Stelle.
- **Fix:** Gemalt bleibt nur, was keine Materie ist: der Blitz-Frame, die Druckringe, der Kern,
  die Schockfront. Jede Materie-Zelle geht über `particles.emit`:
  - Boom-Funken → `particles.ember_sparks(at, 6 + size, dir, scale)` (existiert), die gemalten
    Funken weg.
  - Shatter-Splitter → `particles.shatter(at, n, dir, speed)` (existiert, rutscht und liegt).
  - Implosionsmotten → `particles.implode` und `well` (ziehen physikalisch).
  - `rig_renderer._particles` → auf `feedback.particles` umleiten, damit Chips landen und
    liegen.
  - Kometen → Tropfen mit `land_ref`, sodass die Lache aus den gelandeten Tropfen wächst (siehe
    Punkt 7).
  - Todeswolken → Knochenstaub (`dust_flat`) bzw. Schleimtropfen in der Farbe des Materials.
  - Kraterzungen → `particles.flames` (auftreibende Flammen-Partikel) statt fester Dreiecke.

  Budget: `MAX_PARTICLES` 600 wird schon heute im Urknall erreicht (`particles_peak=600`). Mit dem
  Umbau braucht es eine Abstufung nach Entfernung bzw. Wichtigkeit (Ultimates zuerst) und eher
  ein höheres Limit (800–1000) mit Einbacken beim Verdrängen (`_evict` macht das schon).

### 6. Leichen sehen nicht nach ihrem Element aus — M

- **Gesehen:** Die Knochen nach Feuerball, Frostlanze, Leerengeschoss und Meteor sind dieselben
  elfenbeinweißen Teile (Zoom B2, C4, D3; Leere Reihe 3). Nur der Boden darunter unterscheidet sich.
- **Fix:** Snapshot `kill.el` (siehe Punkt 2). In `_detach` färbt das Element die Trümmer:
  - Feuer: verkohlt (dunkel ×0,55) plus Glutpixel auf dem Teil, die über 1,5 s abkühlen. Die
    `white`-Überlagerung mit `palette("ember").glow` gibt es schon für Höllen-Rigs.
  - Frost: eisblau getönt mit Reif-Kante; beim ersten harten Aufprall zerspringt das Teil in
    `particles.shatter`.
  - Leere: Teile dithern vom Rand her zu Motten, die in den Leerenfleck gezogen werden
    (`well`).

  Gewicht nach Wichtigkeit bleibt gewahrt: Nur ein Kill durch ein Ultimate zerreißt alle Teile.

### 7. Urknall: Aufkleber-Lachen im ganzen Raum, Bildraten-Einbruch im Kollaps — M

- **Gesehen:** Leere-Bogen Reihe 8, f266 bis spät, `bild-urknall-teile-bleiben-mitte-f287.png`:
  9 und mehr glatte blaue und grüne Lachen mit Ring-Muster verteilen sich über den ganzen Raum,
  auch fern jeder Flugbahn. `bild-urknall-kollaps-f245.png`: Das Overlay zeigt im Kollaps-Frame
  „5 FPS“. Der Take kostet im Mittel 90 ms gegen 40 ms Grundlast im selben Aufbau
  (p95 197 ms), Partikel am Limit 600.
- **Fix:** Kometen als Partikel mit Geschwindigkeit, Schwerkraft und Wandprall. Gelandete Tropfen
  speisen über `pool_paint.drop_landed` eine Lache, deren Größe der Einheitenzahl entspricht.
  Höchstens 1 Lache je Element-Einheit, an der Landestelle. Die Erzeugung im Kollaps über 3–4
  Frames verteilen. `bench_vfx.gd` um die Singularität erweitern (Budget aus §6: ≤ 18 ms im
  Mittel).

### 8. Gletschergrab: Die Gegner sterben vor dem Bild — S/M

- **Gesehen:** `bild-gletschergrab-tod-vor-landung-f005.png` und Frost-Bogen Reihe 9 f5
  (t = 0,08 s): Todeswolke und Trümmer an der Gruppe, während der Kristall noch in der Hand
  wächst. Die Spitzen brechen erst ab f30 aus. Gemessen: `died_at=0`. Zum Vergleich der Meteor:
  Tod bei f59 = Einschlag, richtig.
- **Fix:** Der Schaden des Hosts kommt mit der Landung (`glacier.throw` als Verzögerung in
  `talent_combat`), oder der Wurf im Cast wird auf ≤ 0,1 s verkürzt. Ursache vor Wirkung ist
  Grundregel des Game-Feels.

### 9. Glow-Flecken überstrahlen die Pixel — S

- **Gesehen:** Zoom C1 (Gift-Explosion f24), Zoom A1/A4, Zoom E1: Ein weicher weißgelber Fleck von
  ca. 120 px liegt für etwa 0,2 s über dem Einschlag. Darunter verschwinden Blitz-Frame,
  Druckring und Teile. Beim Meteor-Einschlag (f065) dasselbe in groß.
- **Fix:** Die Glow-Ebene beim Einschlag auf 1–2 Frames begrenzen und ihre Deckkraft halbieren
  (`vfx_talents.json shots.tiers.*.glow`, `fire.boom.flash`). Der weiße Blitz soll ein harter
  Pixel-Frame sein (so steht es in §4a), kein weicher Bloom.

### 10. Gewicht und Rückmeldung der kleinen Talente — S

- **Raumsprung** (Leere Reihe 5): nur eine gepunktete Linie und ein kleiner Ring. Beim Ankommen
  stößt nichts weg, kein Staub, keine Motten wirbeln. Vorschlag: `particles.kick` am Ziel (Radius
  24) und eine Implosion am Start, dann fühlt sich der Sprung „gefaltet“ an.
- **Kristall- und Leerenschild** (Frost Reihe 7, Leere Reihe 7): In 6,7 s mit zwei schlagenden
  Skeletten kaum sichtbare Treffer-Risse bzw. Wellen. Am Ende ein paar verstreute Pixel. Der
  Splitterwurf am Ende sollte `particles.shatter` mit 12–16 Splittern sein, die rutschen.
- **Pixel-Wörter** von Perks („ADRENALIN“, „STEINHAUT“, „SCHNELLFEUER“) und „Ein neuer
  Talentpunkt“ stehen über 4 s mitten im Kampfbild (Feuer Reihe 9, Leere Reihe 4; durch
  Beute ausgelöst, im Spiel aber genauso). Kürzer (≈ 1,2 s), über dem Helden, per Dither aus.

### Einheitlichkeit und Reaktionen (geprüft)

| Reaktion | Ergebnis |
|---|---|
| Feuer auf Gift | Explosion ✓ (Feuer Reihe 4) |
| Feuer auf Wasser | Dampf als gedittherte Wolke ✓ (Reihe 5, Zoom C2) |
| Frost auf Wasser | Glatteis, Knochen liegen darauf ✓ (Frost Reihe 2) |
| Frost auf Gift | keine Regel, Raureif-Tönung ✓ |
| Leere auf Gift und Wasser | beide geschluckt ✓ (Leere Reihe 2) |

Bruch der Einheitlichkeit: Die Todeswolke ist in allen drei Spezialisierungen gleich beige bzw.
grün und nicht im Element. Frost und Leere bekommen also eine warme Rauchwolke (Punkt 5). Laut
§4a lösen Infernospeer, Glutkette und Phönixschritt kein `fire_at` aus. Das ist hier nicht neu
geprüft, weil keine Pfütze in ihrem Weg lag.

## Frame-Zeit

Das Overlay des Testraums zeigt unter `--fixed-fps` immer „16.7 MS“ und taugt dort nicht als
Messung. Gemessen wurde die Uhrzeit je Frame ohne Screenshot (`BENCH`). In diesem Aufbau liegt die
Grundlast bei ~38 ms je Frame, weil das Fenster beim Aufnehmen im Hintergrund lief. Diese Werte
sind also nicht mit dem Budget von 18 ms vergleichbar. Aussagekräftig sind nur die Aufschläge:

| Talent | Aufschlag im Mittel | p95 |
|---|---|---|
| Meteor | +13 ms | 67 ms |
| Gletschergrab | +10 ms | 58 ms |
| Singularität (Take) | +50 ms | ~200 ms, Overlay 5 FPS im Kollaps |

Eine echte Budget-Messung der drei Ultimates mit `scripts/bench_vfx.gd` steht aus.

## Nicht erfasst

- Shake, Hitstop und Ton sind in Standbildern nicht sicher zu beurteilen. Die Bildfolgen zeigen
  den Blitz-Frame, Shake ist nicht messbar.
- Die erste Aufnahme von Frost und Leere zeigt noch die Lava- bzw. Glatteis-Lache des vorigen
  Ultimates. Sie liegt in einer Host-Liste, die das Aufnahmeskript nicht leert. Die Takes
  danach sind sauber.
- Pyro-Monster und Wasserelementar wurden nur 2,5 s beobachtet. Ihre Angriffe sind im Bogen, aber
  nicht eigens bewertet.
- Story-Welten (3-px-Raster) wurden nicht geprüft, nur die Krypta.
