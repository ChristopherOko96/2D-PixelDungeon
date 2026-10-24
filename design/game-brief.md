# Game Brief: Basement Run

**One-sentence pitch:** Du kämpfst dich per Twin-Stick-Schießen durch zufällig erzeugte Dungeon-Räume und baust aus Item-Funden einen absurd starken Build.

## Core loop
- Einen Raum betreten, die Gegner mit Schüssen und Ausweichen besiegen.
- Eine Belohnung bekommen (Item, Pickup), die deine Werte oder Schüsse verändert.
- Zum nächsten Raum weitergehen, bis der Boss kommt.

## Player goal & fail state — what "working" looks like
- Du erreichst den Boss am Ende des Stockwerks und besiegst ihn.
- Der Lauf endet, wenn deine Herzen auf null fallen, danach beginnt ein neuer Lauf.

## MVP — what must exist to be the game
- Spielfigur mit Bewegung und Twin-Stick-Schießen
- Ein Gegnertyp mit einfacher KI
- Zufällig zusammengesetzter Dungeon aus Raumvorlagen
- Herzen-Leben, Schaden und Tod
- Item-Pickups, die Schuss oder Werte verändern (etwa 5 Stück)
- Ein Boss am Ende des einen Stockwerks

## Out of scope — not building this
- Multiplayer
- Meta-Progression und Freischaltungen
- Mehrere Stockwerke
- Shop und Spezialräume
- Speichersystem
- Story und Dialoge

## Build order
1. Bewegung und Schießen (die Spielbarkeit zuerst prüfen)
2. Ein Raum mit Gegner und Schaden
3. Raumgenerator
4. Items
5. Boss

---
**Who it's for / what they feel:** Spieler, die kurze Läufe lieben und bei jedem Fund denken „was passiert, wenn ich das kombiniere?“.

**Art & audio direction:** Düsterer Cartoon-Look in 2D, einfache Sprites, trockene Soundeffekte.

**Reference game:** The Binding of Isaac. Der MVP übernimmt nur den Kern: Raum-Roguelike mit Twin-Stick-Schießen und Item-Builds, ohne die Meta-Ebene.
