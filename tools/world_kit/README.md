# Welt-Baukasten

`world_core.js` ist der gemeinsame Etagen-Generator für alle Welten. Eine Welt bringt nur Daten mit:
zehn Etagen (Titel, fester Boss, Werte), Raumnamen, Wortwahl und einen Skin. Jeder Lauf würfelt
eine Weltnummer; aus ihr und der Etagennummer entsteht der Seed jeder Etage (siehe
`tools/krypta_dungeon/krypta_floors.js`, `forRun`).

Abgezweigt von `tools/hell_dungeon/hell_core.js`. Der Hell-Kern bleibt unverändert, solange
Hölle und Frostgruft ihre gebackenen Etagen daraus beziehen.

## Feste Regeln auf jeder Etage

- Kampfräume sind mittel oder groß (2 bis 3 Felder). Kleine Räume (1 Feld) gibt es nur für den
  Start, die Schlüsselkammer, Tresore, Beutekammer, Geheimräume und die Abstiegskammer.
- Das Bosstor öffnet nur mit dem Bossschlüssel. Der liegt in einer kleinen Schlüsselkammer in der
  Mitte; an der Nordwand der Manabrunnen (einmal benutzbar), daneben der Ladentisch (später ein
  Laden).
- In den Bossraum geht es immer von unten. Das Tor hat zwei Banner, zwei Fackeln und einen
  kurzen Teppich davor. Die Welt bestimmt Bannerfarbe und Fackelfarbe pro Etage
  (Krypta: rot auf 3, 6, 9, 10, sonst je eine andere Farbe; Etage 10 blau).
- Vier bis sechs Druckplatten in einem Kampfraum, nummeriert in Leserichtung. Pro Etage gilt eine
  feste Reihenfolge, nie die Leserichtung, ihre Umkehrung oder (bei vier) ein Lauf um das Quadrat.
  Jede richtige Platte leuchtet, eine falsche löscht alle. Gelöst öffnet sich ein Riesentresor
  (goldene Truhe) oder ein verborgener Gang; mehr Platten geben mehr Belohnung.
- Kein Weg ist versperrt: In jedem Raum erreicht man jede Tür und alles Benutzbare, ohne in
  Moder/Lava oder eine Grube zu treten und ohne an Möbeln zu scheitern. `clearWays` läuft nach
  aller Ausstattung und legt dort Brücken bzw. nimmt Hindernisse heraus; `blockedWays` prüft es.
- Schlüsselkammer: eine obere Ecke ist der Laden (Ladentisch zwischen zwei Bücherregalen, Fässer,
  Urnen), die andere der Manabrunnen; Statuen in den unteren Ecken; nichts zerbrechlich.
  Bücherregale gibt es nur dort.
- Ab Etage 2 manchmal eine versteckte Treppe zurück in eine frühere Etage nach Wahl, mit neu
  gewürfelter Welt.
- Dazu wie bisher: Hauptweg-Schloss mit Schlüssel davor, Beutekammer mit eigenem Schlüssel,
  Feuer- bzw. Seelenschalen, manchmal ein Geheimraum hinter einem Schädelhaufen.

`tools/krypta_dungeon/check_runs.js` prüft diese Regeln über beliebig viele zufällige Läufe.

## In Godot

`src/world_kit/world_core.gd` ist die GDScript-Fassung dieses Generators und baut aus derselben
Weltnummer dieselbe Etage (Gleichheitstest `tests/world_kit_parity_test.gd`, Referenzdaten aus
`node tools/world_kit/dump_floors.js assets/sprites/krypta/manifest.json`). Wer hier etwas ändert,
ändert es in beiden Dateien und schreibt danach die Referenzdaten neu. Überblick:
`docs/WELT-BAUKASTEN.de.md`.
