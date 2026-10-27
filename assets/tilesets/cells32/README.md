# Separate32-Pixel-Zellen

280 PNG-Dateien, jeweils32×32 RGBA. Aus den vier vom Nutzer gelieferten
Dungeon-Sheets und `assets/items/item_sheet_items.png` ausgeschnitten:
jeweils56 Zellen in Zeilenreihenfolge. Dungeon-Sheets:7 Spalten ×8 Zeilen;
Item-Sheet:8 Spalten ×7 Zeilen. Nummerierung beginnt bei000.

Die ursprünglichen16×16-Zellen werden mit Nearest auf32×32 vergrößert.
Die Dateien sind keine neu gezeichneten höher aufgelösten Grafiken. Transparenz
und Pixelstruktur bleiben erhalten; die vollständigen Originale liegen unverändert
in den übergeordneten Grafikordnern. Deren Herkunfts-/Lizenzhinweise gelten weiter.

Reproduzieren vom Projektordner:

```powershell
& $godot --headless --path . --script res://scripts/extract_tiles32.gd
./scripts/Dev.ps1 Check
```

ID-Format: `violet_017`, `rose_017`, `moss_017`, `amber_017`, `items_017`.
`src/tile_palette.gd` akzeptiert ausschließlich bekannte Gruppen und000..055.
Drehung und Kollision sind Eigenschaften der platzierten Raumzelle, nicht der PNG.
