# Dungeon-Werkstatt: Räume für den Story-Modus bauen

Die Dungeon-Werkstatt baut die Räume, aus denen der Story-Modus seine Ebenen
zusammensetzt. Jede Ebene zieht 6 Räume aus dem Raum-Pool: zuerst einen
Eingang (falls einer passt), am Ende einen Boss-Raum mit dem Boss, Nebenboss
oder der starken Gruppe und der Treppe nach unten. Du baust Räume, das Spiel
mischt sie.

## Öffnen

- Im Hauptmenü auf **EDITOR** klicken, oder
- `Dungeon-Editor.cmd` doppelklicken (startet das Spiel direkt in der Werkstatt;
  `./scripts/Dev.ps1 DungeonEditor` macht dasselbe).

**ZURÜCK** oder **ESC** führt zurück ins Hauptmenü. Ungespeicherte Änderungen
werden dabei gespeichert.

## Der Bildschirm

- **Oben:** die Raumauswahl (Name · Rolle · Ebenen), **NEU**, **KOPIE**,
  **LÖSCHEN**, **STRG+Z** (rückgängig) und **STRG+Y** (wiederholen).
- **Links:** die Werkzeuge 1 bis 9, die Pinselgröße, **RASTER**, **EINPASSEN**
  und die Vorschläge **GRUNDRISS** und **DEKORIEREN**.
- **Mitte:** der Raum so, wie er im Spiel aussieht: 0x72-Krypta mit Wänden,
  Toren, Kerzen und deiner Deko.
- **Rechts:** zwei Reiter (Taste **TAB** wechselt):
  - **RAUM:** Name, Rolle, auf welchen Ebenen der Raum vorkommt, Größe, die
    **PRÜFUNG** und der **TEST-HELD**. Steht dort **RAUM !!** in Rot, ist eine
    Prüfung rot.
  - **DEKO:** die Deko-Bibliothek (siehe unten).
  - Immer sichtbar: **TESTSPIELEN**, **SPEICHERN**, **ZURÜCK**.
- **Unten:** ein Hinweis zum gewählten Werkzeug und das Feld unter der Maus.
  In Rot steht dort, warum etwas an dieser Stelle nicht geht.

Mausrad zoomt, die mittlere Maustaste (oder Leertaste + linke Maustaste)
verschiebt die Ansicht. **EINPASSEN** zeigt wieder den ganzen Raum.

## Werkzeuge (Tasten 1 bis 9)

**1 bis 8 bauen den Raum, 9 macht ihn schön.**

| Taste | Werkzeug | Linke Maustaste | Rechte Maustaste |
|---|---|---|---|
| 1 | BODEN | Boden malen | Boden entfernen |
| 2 | RADIERER | Boden entfernen | Boden malen |
| 3 | RECHTECK | Ziehen füllt Boden | Ziehen leert die Fläche |
| 4 | START | Hier kommen die Helden an | Markierung entfernen |
| 5 | GEGNER | Startplatz der ersten Gegner | Markierung entfernen |
| 6 | TRUHE | Truhenplatz; nochmal klicken = **MIMIK**, nochmal = Truhe | Markierung entfernen |
| 7 | KERZE | Kerzensäule als Licht (höchstens 16) | Markierung entfernen |
| 8 | TREPPE | Nur im Boss-Raum: Treppe nach unten | Markierung entfernen |
| 9 | DEKO | Gewähltes Deko-Teil setzen oder malen | Deko entfernen |

Pinselgröße 1, 3 oder 5 Felder gilt für BODEN, RADIERER und Bodenarten.

Was du **nicht** malen musst:

- **Wände** entstehen von selbst um jeden Boden herum. Der äußerste Rand des
  Raums bleibt immer Wand.
- **Tore** setzt das Spiel selbst in passende Wände (oben liegende Wandstücke
  mit Boden davor). Die Torbögen im Bild zeigen, wo sie hinkommen können.
- **Spielerplätze**: aus deinem START werden vier Plätze für bis zu vier Helden.
- **Gegner**: setzt du weniger als fünf Startplätze, ergänzt das Spiel den Rest
  weit weg vom Start (blass im Bild). Die Horden kommen sowieso dazu.
- **Truhen**: ohne Truhenplätze sucht das Spiel selbst Plätze an den Wänden.

## Truhen und Mimiks

Im Spiel öffnet man eine Truhe mit **E**, wenn man direkt davor steht (über
der Truhe erscheint „E ÖFFNEN“). Zerschlagen lässt sie sich nicht mehr, Kisten
dagegen schon. In der Truhe liegt ein Perk, später auch Gegenstände aus deiner
Liste.

Ein **Mimik** sieht genau aus wie eine Truhe. Wer ihn mit E öffnet, wird
gebissen; dann springt er als Gegner hinter den Helden her. Besiegt lässt er
zwei Perks fallen. Ab Ebene 2 ist etwa jede sechste zufällige Truhe ein Mimik.
Im Editor machst du eine Truhe zum Mimik, indem du sie mit **6 TRUHE** noch
einmal anklickst (rot umrandet, mit Zähnen). Ein gesetzter Mimik ist in jedem
Lauf da.

## Deko: Teppiche, Möbel, Wandschmuck

Reiter **DEKO** (oder Taste **9**) öffnet die Bibliothek. Oben sechs Sorten,
darunter die Teile der gewählten Sorte mit Bild und Namen. Ein Klick auf ein
Teil wählt es und schaltet auf Werkzeug 9. Im Raum folgt ihm dann ein
Vorschaubild: **weiß umrandet** heißt „passt hier“, **rot gestreift** heißt
„geht nicht“, und unten steht warum.

| Sorte | Was | So legst du es |
|---|---|---|
| BODEN | Bodenarten: glatt, Steine, Risse, dunkel, Moos | Felder malen wie Boden (Pinsel 1/3/5) |
| TEPPICH | roter und heller Teppich, Läufer | Teppich: Rechteck ziehen, der Rand entsteht von selbst, auch bei L- oder T-Formen |
| WAND | Banner, Mauerloch, Eisenring, Gitter, Schleim, Schild, Brunnen (Lava, Wasser) | Klick auf eine Wand mit Boden direkt darunter |
| MÖBEL | Säule, Kiste, Schrank | Klick auf Boden; **IM WEG**: Helden und Gegner kommen nicht hindurch |
| LICHT | Fackel (an der Wand), Feuer (auf dem Boden), Lichtstrahl (fällt von der Decke, Staub rieselt) | Klick; leuchtet in der dunklen Krypta |
| KRAM | Schädel, Wegweiser | Klick auf Boden, steht nicht im Weg |

- **Verschieben:** ein gesetztes Teil anklicken und ziehen. Ein ungültiger
  Platz schickt es zurück.
- **Entfernen:** rechte Maustaste (ziehen entfernt mehrere). Bei Bodenarten
  und Teppichen radiert die rechte Maustaste dieselbe Sorte.
- **MUSTER** (Taste **R**): nächste Farbe oder Form, z. B. die vier Banner.
  Mit der Maus über einem gesetzten Teil wechselt R dessen Muster.
- **ZUFALL:** jedes neue Teil bekommt ein zufälliges Muster (für Risse und
  Schädel schon an).
- **PIPETTE** (oder ALT + Klick): übernimmt ein Teil aus dem Raum samt Muster.
- **ZULETZT:** die letzten sechs Teile, egal aus welcher Sorte.
- **PINSEL / RECHTECK:** bei Bodenarten und Teppichen malen oder Fläche ziehen.

Was das Spiel verhindert, damit der Raum spielbar bleibt:

- Wandteile nur an Wänden mit Boden darunter, nicht dort, wo ein Tor hinkommt.
- Möbel, die im Weg stehen, nicht auf oder direkt neben dem Start, direkt
  neben einem Gegner-Startplatz, vor einem Tor, auf Markierungen und nicht
  so, dass der Raum in zwei Teile zerfällt.
- Wird Boden entfernt, geht die Deko darauf mit (und das Wandteil darüber).
  STRG+Z holt alles zurück.

**AUTO-DEKO:** Ohne eigene Deko schmückt das Spiel jeden Raum selbst (Fackeln,
Banner, Lavabrunnen, Mauerlöcher, Schädel), bei jedem Lauf etwas anders.
Sobald du das erste Deko-Teil setzt, wird diese Deko deine: Sie bleibt genau
so stehen und lässt sich verschieben oder entfernen, und das Spiel ändert
nichts mehr daran. Der Knopf **AUTO-DEKO: AN/AUS** schaltet das auch von
Hand. **DEKO LEEREN** (zweimal drücken) entfernt alle Deko des Raums.

Ein Krypta-Raum mit Rezept (siehe unten) bleibt mit der ersten Deko fest so,
wie er gerade aussieht, denn die Deko hängt an seinen Wänden.

## Vorschläge: GRUNDRISS und DEKORIEREN

Links unter **VORSCHLAG** stehen zwei Knöpfe. Jeder Klick gibt einen neuen
Vorschlag; **STRG+Z** holt den alten Stand zurück. Gezeigt wird nur, was das
Spiel annimmt.

- **GRUNDRISS** baut einen neuen Raum zum Erkunden: kleine und große Kammern im
  Wechsel, verbunden durch schmale Gänge (2 Felder, damit große Gegner
  durchpassen), ein bis zwei Abzweige in Sackgassen mit Truhe, manchmal eine
  Abkürzung. Ist die **Rolle Boss-Raum**, entsteht ein **Thronsaal**: kleiner
  Vorraum im Süden, Gang, große symmetrische Halle mit zwei Nischen; Thron
  (Startplatz des Bosses) und Treppe liegen auf der Mittelachse unter der
  Nordwand. Ist der Raum zu klein, wird er dafür vergrößert. Der Vorschlag
  ersetzt Boden, Markierungen und Deko.
- **DEKORIEREN** schmückt den Raum so, wie er gerade ist (auch deinen eigenen):
  - Teppich als Läufer längs durch die Mitte jeder Kammer, die größte rot,
  - Säulen paarweise gespiegelt an den langen Seiten,
  - Feuer in den Ecken großer Kammern,
  - Nordwand im Takt Fackel, Banner, Fackel, die Mitte betont (Brunnen),
  - Kisten, Schränke und Schädel in Ecken, Sackgassen alt (Risse, Moos),
  - Gänge mit Fackeln in gleichem Abstand.
  Im Boss-Raum führt der rote Teppich vom Eingang der Halle bis zum Thron,
  Säulenreihen säumen ihn, Feuer stehen links und rechts vom Thron, ein
  **Lichtstrahl** fällt auf ihn und die Stirnwand ist symmetrisch geschmückt.
  Alles bleibt danach verschieb- und löschbar.

Die Regeln und Zahlen stehen in `assets/data/dungeon_shapes.json` (Grundriss)
und `assets/data/dungeon_styling.json` (Deko).

## Rolle und Ebenen

- **Eingang (erster Raum)**: kommt nur als erster Raum einer Ebene vor.
- **Normaler Raum**: kommt irgendwo dazwischen vor.
- **Boss-Raum (letzter Raum)**: schließt die Ebene ab. Er braucht eine TREPPE.

**KOMMT VOR AUF EBENE** begrenzt, wo der Raum auftaucht, z. B. 1 bis 3 für
einfache Räume oder 7 bis 10 für schwere. Hat eine Ebene zu wenige passende
Räume (es braucht mindestens 5 andere Räume und einen Boss-Raum), nimmt das
Spiel dort den ganzen Pool.

## Die Prüfung

Rechts steht für jede Regel **OK** (grün) oder **!!** (rot):

- genug Boden, Spielerstart gesetzt, Boden hängt zusammen,
- genug mögliche Tore (2, für Eingang und Boss-Raum 1),
- im Boss-Raum: Treppe gesetzt,
- **Deko**: wie viele Teile gesetzt sind und wie viele im Weg stehen,
- **Spiel akzeptiert den Raum**: die Prüfung des Spiels selbst. Sie meldet
  z. B. Gänge, die für große Gegner zu schmal sind (Gänge mindestens 2 Felder
  breit, Möbel mit Abstand), oder Kerzen in Wänden.

## Speichern und Testspielen

- **SPEICHERN** (oder STRG+S) schreibt alle Räume nach
  `assets/data/dungeon_rooms.json`. Vorher wird der alte Stand gesichert
  (`user://dungeon_editor/backups`).
- Ein Raum mit grüner Prüfung kommt sofort in den Pool des Story-Modus. Ein
  Raum mit roter Prüfung wird als **ENTWURF** gespeichert. Er bleibt im Editor,
  kommt aber nicht ins Spiel, bis die Prüfung grün ist. So startet der
  Story-Modus immer.
- **TESTSPIELEN** speichert und startet einen echten Lauf auf der ersten Ebene
  des Raums, im Raum selbst (ein Boss-Raum als letzter Raum der Ebene), mit dem
  gewählten **TEST-HELD**. Über **MENÜ · ESC → Hauptmenü** kommst du zurück in
  die Werkstatt, genau zu diesem Raum.

## Die vorhandenen Krypta-Räume

Die zehn Räume der Krypta formen sich bei jedem Lauf leicht anders (Kammern und
Gänge aus einem Rezept). Markierungen kannst du ändern, ohne das zu stoppen.
Sobald du den **Boden** änderst oder **Deko** setzt, bleibt der Raum fest so,
wie er im Editor aussieht.

## Woher die Deko kommt

Die Bilder stammen aus dem 0x72-Ordner: DungeonTileset II von 0x72 und
DungeonTileset II Extended von Nijikokun (beide CC0, Nachweis in
`assets/sprites/decor/LICENSE-NOTE.md`). Welche Teile es gibt, in welcher
Sorte sie stehen, ob sie im Weg stehen oder leuchten, steht in
`assets/data/dungeon_decor.json`. Ein neues Teil braucht dort nur einen
Eintrag und sein Bild unter `assets/sprites/`.

## Neue Räume

**NEU** legt einen 40 × 26 Felder großen Raum mit Boden und Start an. **KOPIE**
dupliziert den gewählten Raum. **LÖSCHEN** (zweimal drücken) entfernt einen
Raum, aber nur, solange dem Story-Modus mindestens drei normale Räume und ein
Boss-Raum bleiben. **GRÖSSE IN FELDERN** (12 bis 64 × 10 bis 48) und
**ÄNDERN** passen die Fläche an; Boden außerhalb fällt weg.
