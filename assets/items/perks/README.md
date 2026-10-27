# Perk-Symbole für die Kartenansicht

Neue, separat generierte Symbole für die fünf vorhandenen Perks. Die gelieferten
Item-/UI-Sheets bleiben unverändert. Die Original-Itemgrafik wurde als visuelle
Stilvorgabe angesehen; im Bildprompt sind ihre plumfarbenen Konturen, violetten
Mitteltöne und goldenen Highlights beschrieben. Es wurde kein Sheet übermalt.

| Datei | Perk | Motiv |
| --- | --- | --- |
| `ember.png` | Glutkern | Glühender Flammenkristall |
| `shadow.png` | Schattenschritt | Verzauberte violette Stiefel mit Tempoakzent |
| `heart.png` | Blutherz | Roter Herzkristall |
| `quick.png` | Schnellfeuer | Armbrust mit schnellem türkisfarbenem Projektil |
| `mend.png` | Mondtau | Heiltrank mit Mondsichel |

Alle fünf Laufzeitdateien sind **16×16 Pixel**, RGBA, mit tatsächlich transparentem
Hintergrund und binärer Alpha (`0/255`). Jede Datei verwendet höchstens24 Farben.
Im Spiel nur mit Nearest-Filter und ganzzahligem Zoom anzeigen.

## Erzeugung und Quelldateien

- Modus: eingebautes **image_gen**-Werkzeug, fünf getrennte Generierungen;
  kein CLI-/API-Fallback und kein eigener API-Schlüssel.
- Die unveränderten generierten Originalbilder liegen unter
  `originals/ember.png`, `originals/shadow.png`, `originals/heart.png`,
  `originals/quick.png` und `originals/mend.png` (je1254×1254 RGBA).
- `.gdignore` hält diese großen Quelldateien aus Godots Ressourcenimport heraus;
  die normalisierten Laufzeitdateien liegen direkt in diesem Ordner.
- Der vollständige tatsächlich verwendete Prompt je Motiv steht in
  [generation_prompts.json](generation_prompts.json).
- Die ursprünglichen Ausgaben im Codex-Bildordner wurden kopiert und nicht gelöscht.

## Vorbereitung und Prüfung

`prepare_icons.py` führt ausschließlich Asset-Vorbereitung aus: transparente
Ränder beschneiden, den Inhalt mit Nearest-Sampling in eine14×14-Fläche einpassen,
zentriert in16×16 platzieren, Alpha auf0/255 begrenzen und auf höchstens24 Farben
reduzieren. Es zeichnet keine Ersatzbilder. Voraussetzung: Python mit Pillow.

```powershell
python assets/items/perks/prepare_icons.py
```

Das erzeugte [Vorschaubild](preview_icons.png) zeigt alle fünf nativen Symbole
bei112×112 Pixeln auf violettem Hintergrund. Es wurde angesehen. Native Maße,
Alphawerte und Farbanzahl wurden zusätzlich aus den tatsächlichen PNGs geprüft.
Die originalen KI-Bilder sind keine handgezeichneten16-Pixel-Quellen; die
16×16-Dateien sind die für das Spiel normalisierten Ableitungen.
