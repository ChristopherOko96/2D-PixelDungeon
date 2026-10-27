# Nutzer-Tilesets

Die vier unveränderten PNG-Dateien wurden vom Nutzer am 25.10.2026 als
Arbeitsmaterial für dieses Projekt bereitgestellt. Ein externer Urheber oder
eine zusätzliche Lizenz wurde in der Nachricht nicht angegeben.

| Datei | Ursprünglicher Anhang |
| --- | --- |
| `dungeon_rose.png` | `codex-clipboard-1e50b961-e928-4ce4-a9ad-edeb9a6621cd.png` |
| `dungeon_moss.png` | `codex-clipboard-5b0f366b-f732-4043-9c6e-8505699a4774.png` |
| `dungeon_amber.png` | `codex-clipboard-f0145d21-368c-4422-9b5b-f3b12231526a.png` |
| `dungeon_violet.png` | `codex-clipboard-4b287659-e1e7-4529-844d-73ee4f8a2db2.png` |

Jede Quelle ist **112×128 Pixel**, RGBA, mit 16-Pixel-Bausteinen. Der Renderer
projiziert diese seit der Korrektur vom26.10.2026 ganzzahlig auf das32-Pixel-
Weltraster; die Welt selbst bleibt bei1×-Zoom. Die Originale bleiben erhalten.
Unter [cells32/](cells32/README.md) liegen zusätzlich280 separat auswählbare
32×32-PNGs aus den vier Dungeon-Sheets und dem Item-Sheet. Das Extraktionsskript
vergrößert jede Originalzelle mit Nearest. Die frühere16-Pixel-Spielwelt ist
historisch; aktuelle Figurenanimationen stehen unter `assets/sprites/0x72/`.

`src/dungeon_tiles.gd` ordnet ausgewählte Atlasregionen explizit Bodenmitte,
Wandflächen, Randstreifen, Ecken, Säulen und Leiter zu. Die komplette PNG wird
nirgends als fertiger Raum auf die Karte geklebt. Randmauerwerk folgt ausschließlich
`play_bounds`, Säulen folgen `obstacles`, Türen und Treppen ausschließlich `exits`
aus dem autoritativen Layout. Die Farbvariante wählt `room_layout.theme`.

## Atlasregionen und räumliche Darstellung

Alle folgenden Angaben sind native Quellpixel `[x,y,w,h]` und werden ohne
Glättung oder Verzerrung gezeichnet. Die Dachfarbe der Säulen stammt aus dem
opaken Kronenpixel `(34,1)` derselben Palette.

| Verwendung | Region |
| --- | --- |
| Bodenmitte und Varianten | `[48,32,16,16]`, `[64,32,16,16]`, `[48,48,16,16]`, `[64,48,16,16]` |
| `CAP`: helle Mauerkrone | `[32,1,16,3]` |
| `BRICK`: senkrechte Backsteinfläche | `[32,4,16,12]` |
| `SIDE_LEFT`: echte linke Mauerkante | `[12,48,4,16]` |
| `SIDE_RIGHT`: echte rechte Mauerkante | `[96,48,4,16]` |
| `STAIRS`: diagonale Abwärtstreppe im Bossraum | `[0,0,16,16]` |

Die schwarze, diagonal gestufte Region und die ähnlichen Atlas-Außenteile sind
Treppen-/Durchgangsmotive, keine allgemeinen Mauerecken. Sie erscheinen deshalb
nicht als zufällige Randstücke. Mauerecken entstehen aus zusammengeführten
Kronen, Backsteinflächen und Seitenkanten. Leere Atlaszellen enthalten teilweise
farbige RGB-Werte bei Alpha null; sie sind kein Material für massive Dächer.

Die Nordwand ist insgesamt 24 Pixel hoch: sichtbare Krone und eine bis zum
Boden reichende Backstein-Innenfläche. Seitliche Innenschatten und die südliche Frontwand
geben Tiefe. Säulendächer werden zwölf Pixel nach Norden projiziert, ihre
Backsteinfront endet am unveränderten Kollisionsfuß. Die Reihenfolge nach
Bodentiefe verdeckt Figuren hinter erhöhten Säulen; Figuren davor bleiben davor.
Die Südwand wird als Vordergrund gezeichnet. Türen schneiden passende Öffnungen
in diese Mauerflächen, während die einzige echte Treppe innerhalb des Bossraums
liegt. Diese Projektion ändert keine Bewegungs- oder Treffergeometrie.
