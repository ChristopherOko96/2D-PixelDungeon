# Weltbauer: eigene Räume bauen

Der Weltbauer ist ein eigenes Fenster neben dem Spiel, aber im selben Projekt: gleiche Grafiken,
gleiche Mauern, gleicher Code. Du baust Räume, das Spiel spielt sie mit echten Helden, Monstern und
Kämpfen. Die Etagen der Krypta bestehen aus genau diesen Räumen, siehe „Räume der Krypta“.

## Starten

- `Weltbauer.cmd` doppelklicken (oder `./scripts/Dev.ps1 WorldEditor`).
- Oben wählst du Welt und Raum, **NEU**, **VORLAGE**, **KOPIE**, **LÖSCHEN**, **SPEICHERN**.
- **ANSICHT** schaltet zwischen Pixel und HD um. Das ist dieselbe Einstellung wie im Spiel.
- **TESTEN (F5)** speichert und öffnet das Spiel in einem eigenen Fenster direkt in deinem Raum.
  Lass es offen: Nach dem nächsten Speichern lädt **F9** im Spiel den Raum neu.
- Im Spiel selbst: **DEBUG → WELTBAUER-RÄUME**, Raum und Held wählen.

## Bedienen

| Eingabe | Wirkung |
|---|---|
| Teil links anklicken | Es wird zum Pinsel oder zum Stempel |
| Linke Maustaste | Malen oder setzen |
| Rechte Maustaste | Zurücknehmen oder Teil löschen |
| Umschalt + Ziehen | Ein Rechteck malen |
| Alt beim Setzen | Frei ohne Raster setzen |
| Mausrad, mittlere Maustaste | Zoomen, Ansicht verschieben. Die Ansicht bleibt, bis du EINPASSEN drückst oder einen anderen Raum öffnest |
| Esc | Zurück zu AUSWÄHLEN |
| Strg+Z, Strg+Y | Rückgängig, wiederholen |
| Strg+S, Strg+D, Entf, F | Speichern, Kopie, Löschen, Spiegeln |

Beim Wechseln des Raums, der Welt oder beim Schließen wird automatisch gespeichert.

## Was zusammenwächst

- **Mauer:** Boden oder Mauer malen, die Wände, Ecken und Pfeiler entstehen von selbst.
- **Lava, Moder, Eis:** Felder nebeneinander werden ein See mit einem Rand nur außen.
- **Grube:** Felder nebeneinander werden ein Loch.
- **Flächen:** Jede Grafik aus „Boden und Flächen“ malt eine Fläche, ohne Kanten zwischen den Feldern.

## Teile einstellen

Rechts stehen die Einstellungen des gewählten Teils.

- **Größe, Breite, Höhe:** Größe ändert das Bild gleichmäßig, Breite und Höhe nur in eine Richtung (1 ist das Original, 2 doppelt so groß).
- **Ebene:** Boden (unter allem), Normal (nach Tiefe), Vordergrund (über dem Spieler).
- **Blockiert den Weg:** begehbar oder nicht. Der rote Rahmen zeigt die Kollisionsfläche.
- **Inhalt beim Zerbrechen:** gilt für zerbrechliche Teile wie Vasen und Fässer: Gold, Herz, Schlüssel,
  bestimmter Trank, bestimmte Waffe, oder **Zufällig**: Dann entscheidet die Etage. Ein gelber Punkt markiert gefüllte Teile.
- **Truhe:** **Inhalt** wie oben. **Wie die Etage** zahlt, was die Etage in dieser Raumart zahlt, die Truhe kann dann aber
  auch fehlen. **Schatz (Belohnung für ein Rätsel)** ist die große Truhe: viel Gold (mehr auf tieferen Etagen), ein Herz,
  eine seltene Waffe oder Rüstung mit Kristall und Stein und zwei weitere Funde. Die Werte stehen in
  `assets/data/world_room_contents.json` (`hoard`). **Mimik** ist Nein, Ja oder Zufällig, dazu wählst du das Monster. Den eingestellten Inhalt gibt es,
  wenn das Monster besiegt ist. Ein rotes M markiert die Falle, M? die zufällige.
- **Mimik und Truhenfresser als Gegner gesetzt:** Sie stehen im Spiel als gewöhnliche Truhe da und werden beim Öffnen zum Monster.
- **Gegner 1 und 2:** Truhen und zerbrechliche Teile lassen bis zu zwei Gegner heraus, jeder einzeln wählbar oder zufällig
  von der Etage. Die Gitter fallen, bis sie besiegt sind. Ein roter Punkt markiert solche Teile.
- **Öffnet Gruppe:** Zerbricht das Teil, öffnet sich alles aus dieser Gruppe.

## Rätsel bauen

Auslöser und Ziel bekommen dieselbe **Gruppe** (A bis F):

| Auslöser | Ziel |
|---|---|
| Druckplatten (Reihenfolge 0 = egal, 1, 2, 3 … = genau so) | Tor |
| Hebel-Fackel | Geheimgang (sieht aus wie Mauer) |
| Feuerschalen (alle entzünden) | Tor oder Geheimgang |
| Schädelhaufen (zerschlagen) | Geheimgang |
| Zerbrechliches Teil mit „Öffnet Gruppe“ | Tor oder Geheimgang |

Ein Tor kann stattdessen einen Schlüssel A, B oder C verlangen. Ein Schlüssel zerbricht im Schloss: Zwei Tore mit
demselben Schlüssel und nur einem Schlüssel im Raum sind eine echte Wahl. In Sprungrätseln gehören Schlüssel und Schlösser
dem Raum selbst: Auf der Etage öffnen sie keine Etagentore und zählen nicht als Etagenschlüssel.

Weitere Teile für Rätsel:

| Teil | Wirkung |
|---|---|
| **Inschrift** | Ein Stein mit Text. Steht der Held davor, liest er ihn oben im Bild. Zeilenumbrüche bleiben. |
| **Sprungplatte „Wacht auf mit“** | Die Platte liegt dunkel und wirft nicht, bis die Gruppe gelöst ist. Dann bebt der Raum und sie erwacht. |
| **Druckplatte mit Reihenfolge, Gegner 1 und 2** | Wird sie in falscher Reihenfolge betreten, kommen die Gegner heraus, einmal. |
| **Fallenplatte** | Eine Druckplatte einer eigenen Gruppe mit einer Nummer, die nie dran ist (etwa 9). Wer sie betritt, löst die Falle aus. |

## Tore setzen

Alle Tore stehen unter **Tore und Durchgänge**. Teil anklicken, dann **auf eine Mauer klicken**:

- Ein Tor sitzt auf zwei Mauerfeldern nebeneinander. Die Stelle wird beim Zeigen grün markiert, rot heißt: keine Mauer in Reichweite.
- **Die Mauer läuft geradeaus weiter**, das Tor sitzt in einer Lücke in ihrer Linie, im Editor genauso wie im Spiel. Entfernst du das Tor, ist die Lücke wieder zu.
- Ist hinter der Mauer Boden, führt das Tor durch: Es gräbt bis dorthin durch (höchstens 8 Felder). Ohne Boden dahinter bleibt es ein Tor in der Mauer.
- **Die Lage ergibt sich aus der Mauer:** in Mauern oben und unten steht das gewählte Tor, in Mauern links und rechts der Steinschieber. Zum Verlegen auf eine andere Mauer ziehen.
- Die **Art** lässt sich rechts ändern. Fallgitter, Bosstor und Holztür bleiben zu, bis sie geöffnet werden. Bossbogen, Durchgang, Dämonensturz und Treppentor sind offene Durchgänge.
- **In Seitenmauern ist jedes Tor ein Steinschieber:** eine Platte aus dem Stein der Mauer, die in der Mitte zusammenfährt. Offene Durchgänge zeigen nur die eingefahrenen Enden.

Den Steinschieber baut `tools/world_kit/build_side_gates.gd` aus der Mauergrafik jedes Grafiksatzes. Die Tor-Arten stehen in `assets/data/world_gates.json`.

Die Prüfung rechts meldet zum Beispiel Sprungplatten, die nicht auf Boden landen, oder Gruppen ohne Ziel.

## Sprungplatten

Der Held betritt die Platte und wird eine eingestellte Zahl Felder in eine Richtung geschleudert, auch
über Mauern, Lava und Gruben. Während des Flugs kann ihm nichts passieren. Landet er auf der nächsten
Sprungplatte, schleudert die ihn weiter. So entstehen Wege aus mehreren Sprüngen. Wäre die Landestelle
blockiert, landet er davor, er bleibt also nie stecken. Der Bogen im Editor ist grün, wenn das Ziel Boden ist,
und rot, wenn nicht. Die Werte stehen in `assets/data/world_launch_pads.json`.

## Alle Assets

Der Reiter jeder Welt zeigt Gelände, Spielteile, Fallen, Monster und alle Grafiken dieser Welt und der ihr
zugeordneten Ordner. **Weitere Assets** enthält alles andere unter `assets/`. Die Zuordnung und die Kategorien
stehen in `assets/data/world_editor.json` (`rules`: nach Ansicht jedes Bilds sortiert, die erste passende Regel gilt). Nummerierte Einzelbilder laufen als eine Animation (grüner Punkt), Feuer
und Brunnen bewegen sich wie im Spiel, Filmstreifen aus Effektordnern werden erkannt.

## Pixel und HD

Für jede Welt gibt es zwei Grafiksätze. Ein Raum speichert den Namen eines Teils, nicht den Satz, und zeigt in
jeder Ansicht die passende Grafik. Hat ein Teil nur eine HD-Fassung, wird sie in der Pixel-Ansicht
automatisch aufs Pixelraster gebracht. Hat es nur eine Pixel-Fassung, bleibt es in HD unverändert. Grafiken aus
fremden Ordnern, die zu keinem Satz gehören, sehen in beiden Ansichten gleich aus.

## Dateien

- Räume: `assets/data/world_rooms/<welt>/<id>.json` mit Sicherung `.bak`, lesbar und in Git.
- Der Raum heißt `beispiel_sprungraetsel` in der Krypta: ein fertiges Beispiel mit Sprungweg und Tor.

## Räume der Krypta

Jede Etage der Krypta wird aus den Räumen mit dem Haken **In Etagen verwenden** gebaut. Das sind die Dateien
`k_*.json` im Raumordner, du findest sie oben in der Raumliste. Öffne einen, ändere ihn, speichere: Beim nächsten
Spielstart nutzt das Spiel die neue Fassung.

**Was fest bleibt:** Der Bauplan der Etage (welche Räume, Schlüssel, Schlösser, Rätsel) kommt weiter vom Generator.
In den Bossraum geht es immer von unten. Der Raum davor bekommt seine Banner, Fackeln und den Teppich automatisch,
was dort sonst steht, wird weggeräumt.

**Korridore:** Jeder Raum behält seine Mauern und Tore. Zwischen zwei Toren entsteht beim Bauen der Etage ein kurzer
Gang, zwei Felder breit. Liegen die Türstellen nicht gegenüber, macht er einen Knick.

**Plätze und Größe:** Ein Raum belegt Plätze im Raster der Etage (`slots` in der Datei). Die Größe muss dazu passen:

| Plätze | Größe in Feldern |
|---|---|
| 1 | 14 x 11 |
| 2 breit, 2 hoch | 31 x 11, 14 x 25 |
| 3 lang, 3 hoch | 48 x 11, 14 x 39 |
| Winkel | 31 x 25 |
| 2 x 2 (nur Bossraum) | 31 x 25 |

Das ist die **Leinwand**, nicht die Raumgröße: Der Boden muss sie nicht füllen. Die Kampfräume nutzen nur einen Teil
davon (2 Plätze rund 21 x 9, 3 Plätze rund 32 x 9, Winkel rund 23 x 20), der Rest bleibt Mauer, der Korridor läuft
dann bis zum Raum weiter. Einen neuen Raum beginnst du am einfachsten mit **KOPIE** eines Raums derselben Form. Passt
die Leinwand nicht, bleibt der Raum draußen, die Prüfung rechts sagt, was fehlt.

**Sprungrätsel und Labyrinthe** haben die Raumart „Sprungrätsel / Labyrinth“. Bis zu zwei freie Räume mit 3 Plätzen pro
Etage werden dazu, ohne Kampf und immer dort, wo die Etage keinen Kampf braucht. Sie nutzen die ganze Leinwand. Nahe
einer Sprungplatte siehst du im Spiel den Bogen und die Landestelle. Fällst du in einem solchen Raum nach einem Sprung
in eine Grube, kostet das Leben, du stehst aber wieder auf der Platte. Wichtig beim Nachbauen: Das Spiel räumt in
diesen Räumen nichts weg, also muss von jedem Bereich ein Weg zurück führen.

**Türstellen:** Mit **TÜRSTELLE** markierst du, wo ein Tor stehen darf (zwei Felder in der Mauer). Nur dort entstehen auf
der Etage Türen, unbenutzte bleiben Mauer. Ein Raum braucht mindestens eine. Daneben wählst du, was die nächste Stelle ist:

- **Ein- und Ausgang** (gelb): dient beidem.
- **Eingang** (grün, EIN): Hier soll man hereinkommen, also von der Seite des Etagenanfangs.
- **Ausgang** (rot, AUS): Hier soll es weitergehen.

Die Etage nimmt einen Raum so, dass die Zeichen stimmen. Passt keine Datei richtig herum, darf ein Raum auch andersherum
vorkommen, dann wird der Ausgang zum Eingang.

Für Sprungrätsel, Labyrinthe und Rätselräume mit sechs ET-Platten richtet sich die Etage nach dir: Sie legt ihre Türen auf
deine Stellen, verbindet die Nachbarräume anders und rückt eine Tresorkammer vor eine deiner Türen. Dafür braucht jede
Stelle auf der anderen Seite einen Raum, sonst bleibt sie Mauer. Wichtig bei Rätselräumen: Ihr Gitter zum Tresor braucht
eine eigene Türstelle, plane also eine Stelle mehr ein. Passt ein Sprungrätsel an keiner Stelle, bleibt der Raum ein
Kampfraum. Eine Tür kann ungenutzt bleiben, plane das Rätsel also auch als Sackgasse lösbar.

**Was die Etage einsetzt:**

- **Druckplatten mit der Gruppe „Rätsel der Etage“** (Zeichen ET): Ein gerader Raum mit sechs solcher Platten kann der
  Rätselraum werden. Die Etage wählt 4 bis 6 davon und legt die Reihenfolge fest. Gelöst öffnet sich das Gitter zu einem
  Riesentresor oder ein verborgener Gang zu einer versteckten Kammer nebenan. Sonst fehlen die Platten im Spiel.
- **Truhe mit Inhalt „auto“:** zahlt, was die Etage in dieser Raumart zahlt. In Kampfräumen steht sie nur manchmal da
  und kann ein Mimik sein. Jede andere Truhe enthält genau das Eingestellte.
- **Kisten mit `drop: random`:** Der Inhalt wird pro Lauf gewürfelt.
- Feuerschalen, Siegel, Schädelhaufen, die Herzplatte im Schrein und der Altar im letzten Bossraum.
- Etwas Blut und Moos auf dem Boden und Banner neben Toren in Nordmauern.

- **Truhe „auto“ im Sprungrätsel:** zahlt immer, keine Mimiks.

**Gegner:** Rechts bei **Gegner** wählst du für jeden Raum:

- **Zufällig im Raum:** Das Spiel verteilt die Gegner beim Betreten. **Zufallsgegner** ist ihre Anzahl, bei 0 bestimmt die Etage sie.
- **Von Hand gesetzt:** Es kommen genau die Gegner, die du setzt. Du findest sie in den Kategorien **Gegner** und **Bossgegner**, die Art lässt sich danach rechts ändern. Wählst du einen Gegner aus, stellt sich der Raum von selbst darauf um. Ohne gesetzte Gegner gibt es keinen Kampf, außer der Raum muss auf der Etage einen Schlüssel fallen lassen.

Im Bossraum setzt die Etage immer den Boss.

Die Treppenkammer zeigt ihre Treppe nur auf einer echten Etage, beim Einzeltest fehlt sie.

**Die Sprungrätsel der Krypta** (seit 05.11.2026): 14 Räume sind echte Rätsel mit Schatztruhe. Jeder hat einen freien Weg
zwischen seinen Türen, das Rätsel ist der Weg zum Schatz:

| Raum | Rätsel |
|---|---|
| Die vier Wächter | Rätselvers um vier Statuen gibt die Reihenfolge der Platten, der Wurfweg muss dazu passen |
| Drei Truhen | Nur eine von drei Inschriften sagt die Wahrheit, zwei Truhen sind Truhenfresser; eine schlafende Platte |
| Die Zählung der Toten (2 Fassungen) | Die Zahl der Schädel an jeder Platte gibt die Reihenfolge, gespiegelt anders gezählt |
| Die Schleusen | Drei Stufen wecken dunkle Platten: Druckplatte, Feuerschale, Druckplatte, dann Schlüssel |
| Das Mosaik | Ein Bodenbild in der Halle zeigt die vier richtigen von neun Platten, die anderen fünf sind Fallen |
| Feuer der Ahnen (2 Fassungen) | Vier Feuerschalen auf einem Einbahn-Kreis, mit oder gegen die Sonne |
| Der Kerkermeister (2 Fassungen) | Schlüssel hinter Stacheln, zwei Türen, eine Lügner-Inschrift, die falsche Tür kostet den Schatz |
| Die Prozession | Die Reihenfolge der Statuen an der Nordmauer gilt in der Schlucht |
| Vier Kammern | Feuerschale, Reihenfolge-Rätsel, Fackel auf einer Moderinsel, versteckter Gang |
| Der Abstieg | Sechs Platten auf drei Ebenen, gelesen in Schlangenlinien |
| Der Stufenturm | Stacheltakt, Reihenfolge, zwei Truhen von Lügner und Ehrlichem |

**Die Labyrinthe der Krypta** (`k_labyrinth_*`, seit 05.11.2026): Ein Rundgang außen verbindet alle Türen, man kann
vorbeigehen. Zwei Eingänge mit Inschrift führen in den Irrgarten: schmale Gänge, viele Sackgassen, kleine Kammern,
Knochen und Schädel, in der Mitte die Schatzkammer. In der Datei steht `"maze": true` und `maze_zone` (der Irrgarten
als Reihen von Feldern). Dort wird es im Spiel dunkel, Mauern verdecken die anderen Gänge, die Kamera kommt näher,
und die Karte zeigt den Irrgarten als einen Block. Kein Gegner steht dort von Anfang an: Die Untoten stecken in Vasen,
Kisten und Truhen, kommen genau in deren Gang heraus und jagen nur, was sie sehen. Die Werte stehen in
`assets/data/world_maze.json`. `tools/krypta_dungeon/mazes/build_mazes.js` baut die Labyrinthe, auch hier nur die genannten
Räume mit `--write`.

Die Pläne stehen in `tools/krypta_dungeon/jump_puzzles/rooms/`, `build.js` baut und prüft sie, `solver.js` spielt jeden
Raum durch (Würfe, Gruben, Platten, Tore, Schlüssel) und meldet Lösungsweg, Türen ohne freien Weg, Stellen ohne Rückweg
und Endlosschleifen. `node tools/krypta_dungeon/jump_puzzles/solver.js <raum.json>` prüft auch einen selbst gebauten Raum.
**`build.js` überschreibt Räume**, und nur die genannten, mit `--write`: Nach deinen Änderungen im Weltbauer nicht mehr für
diesen Raum ausführen.

Die Dateien haben `tools/krypta_dungeon/build_room_library.js` und die gezeichneten Grundrisse in `room_maps.js` einmalig erzeugt, die Schlüsselkammer
`tools/world_kit/export_key_room.gd`. **Beide überschreiben Räume**, führe sie nach eigenen Änderungen nicht mehr aus
oder gib beim JS-Werkzeug nur die Namen der gewünschten Räume an.

## Noch nicht fertig

- Hölle und Frostgruft bauen ihre Etagen noch mit dem Generator.
- Das Spiel liest die Räume beim Start. Nach einer Änderung also das Spiel neu starten.
