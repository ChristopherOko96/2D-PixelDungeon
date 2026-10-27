# Story 010: Ork-Animationen, Debug-Levelliste, Klassenwaffen, Truhen

> **Epic**: Dungeon aus Raumvorlagen
> **Status**: In Progress
> **Type**: Feature + Visual/Feel + UI
> **Last Updated**: 2026-10-26

## Context

Wünsche des Projektinhabers vom 26.10.2026:
- Goblins und Orks brauchen mehr Animationsbilder, damit sie sich flüssiger anfühlen.
- Eine Liste aller Level, um direkt hineinzuspielen und selbst zu debuggen.
- Jede Klasse bleibt bei ihrer Waffe.
- Statt „Spaltung“ eine sinnvolle Fähigkeit: zwei Geschosse hintereinander.
- Die Werte sollen angezeigt werden.
- Manchmal sollen Truhen mit kleinen Werte-Erhöhungen auftauchen, zum Beispiel „Angriff +1“.

Firebase folgt später, wenn der Projektinhaber seinen Code schickt.

## Acceptance Criteria

- [x] **Ork-Animationen:** `scripts/animate_orc_figures.py` leitet aus jedem Standbild Einzelbilder ab. Die Ausschläge wachsen mit der Größe der Figur.
  - Stehen, 4 Bilder: der Oberkörper atmet.
  - Laufen, 4 Bilder: die Beine heben sich abwechselnd, der Körper wippt.
  - Ausholen, 2 Bilder: zurücklehnen.
  - Zuschlagen, 2 Bilder: nach vorn stoßen.

  Im Spiel laufen die Bilder mit 5 bzw. 10 Bildern pro Sekunde, dazu kommen weiterhin Squash, Drehung und Treffer-Reaktion.
- [x] **Debug-Levelliste** (Menü unten links: „LEVEL-AUSWAHL (DEBUG)“): Story-Start, Story-Boss, Start und Boss jedes Endlos-Stockwerks 1–5 mit Bossnamen sowie die tiefen Stockwerke 8 und 12. Danach kommt die Heldenwahl, dann geht es direkt dorthin.
- [x] **Klassenwaffen fest:** Jede Klasse behält ihre Waffe. Fremde Waffen, Aufheben (E) und Wechseln (Q) sind entfernt, ebenso Langbogen, Prunkklinge und Glutstab.
- [x] **Doppelzauber** (Magier, statt Spaltung): Jedem Zauber folgt 0,12 s später ein zweiter, mit 2 Stufen bis zu drei. Er wirkt auch, wenn die Taste schon losgelassen ist.
- [x] **Truhen:** Nach dem Räumen steht mit 35 % Chance eine Truhe im Raum (0x72-Truhe). Wer hineinläuft, öffnet sie und bekommt einen kleinen Dauer-Bonus, zum Beispiel +0,5 oder +1 Schaden, +10 % Angriffstempo, +12 % Reichweite oder Schusstempo, +12 Bewegung, +1 Glück, +1 Herz oder 1 Herz Heilung. Der Bonus steigt als grüner Text über dem Helden auf, und die Werte-Spalte leuchtet beim geänderten Wert.
- [x] **Werte sichtbar:**
  - Heldenkarten zeigen Herzen, Waffe, Schaden, Angriffe pro Sekunde, Reichweite bzw. Nahkampf und Tempo.
  - Im Spiel steht die Werte-Spalte rechts. Änderungen durch Truhen, Level oder Perks werden markiert.

## Test Evidence

Ausgeführt am 26.10.2026:
- `GAME_RULES checked=222 failures=0`, darin: Doppelzauber schickt den zweiten Zauber, eine Truhe öffnet bei Berührung und ändert einen Wert, eine offene Truhe gibt nichts mehr, Truhen erscheinen in manchen Räumen.
- `LOADOUT checked=15`: Truhen-Boni auf die Klassenwaffe; es liegen keine fremden Waffen mehr herum.
- `ONLINE checked=26`: Debug-Liste öffnet, fragt nach dem Helden und übergibt Stockwerk und Raum genau einmal.
- Alle übrigen Testsammlungen sind grün.
- Bilder in `production/qa/evidence/story-010-debug-list-chests-animation/`: Levelliste, Heldenkarten mit Werten, Truhen-Bonus im Spiel, Ork-Bilder im Spiel und Laufbilder.

**Offen:**
- Die Ork-Animationen sind aus Standbildern abgeleitet. Echte gezeichnete Animationsreihen würden noch flüssiger wirken.
- Firebase-Anbindung live, sobald der Code vorliegt.
