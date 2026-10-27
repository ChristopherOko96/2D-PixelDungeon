# Original-Items und Animationen

Die Dateien wurden am 25.10.2026 vom Nutzer direkt aus seinem lokalen
Assetbestand bereitgestellt und unverändert übernommen:

- `animation_sheet_items.png`: Original `AnimationSheet_Items.png`, **128×96**, RGBA.
- `item_sheet_items.png`: Original `ItemSheet_Items.png`, **128×112**, RGBA.

Beide verwenden **16×16-Zellen**. Es gab keine Größenänderung, neue Zeichnung
oder KI-Bearbeitung dieser Originale. Eine zusätzliche Urheber-/Lizenzangabe lag
der Nutzernachricht nicht bei. `src/item_art.gd` dokumentiert feste Regionen:

| Zweck | Quelle, Pixelregion |
| --- | --- |
| Glut (`ember`) | Items `[0,48,16,16]`, rotes Flaschen-/Flammensymbol |
| Schatten (`shadow`) | Items `[32,64,16,16]`, violette Feder |
| Herz (`heart`) | Items `[16,80,16,16]`, rosa Herz |
| Schnell (`quick`) | Items `[64,48,16,16]`, goldenes Symbol |
| Heilung (`mend`) | Items `[80,48,16,16]`, grüner Trank |
| Offene Belohnungstruhe | Items `[64,16,16,16]` |
| Geschlossenes Tor | Items `[32,0,16,16]` |
| Feuer in Schale | Animationen, Zeile 3, Spalten 1–3, 8 FPS |
| Trefferwolke | Animationen, Zeile 2, Spalten 4–6 |
| Kurzer Stun-Funke | Animationen, Zeile 4, Spalten 0–3 |

Die Truhe und angebotenen Perks erscheinen nur als Belohnungsdarstellung auf
freier Fläche. Sie erzeugen keine zusätzlichen Hindernisse oder Itemmechaniken.
Die vorhandenen fünf Perks und deren Vergabe bleiben Sache der Hostsimulation.
