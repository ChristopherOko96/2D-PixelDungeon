# Freigegebenes Seelenfeld

## Aktuell: 24 Bilder

Auf ausdrücklichen Nutzerwunsch nach mehr Zwischenbildern am 31.10.2026
mit Imagegen erweitert: `smooth_sheet_24.png`, 1536×1024, sechs Spalten,
vier Zeilen, 24 verschiedene Bilder à 256×256. Exakter Folgeprompt:
`smooth_prompt.txt`; Referenz war die unveränderte freigegebene Originaltafel.
Aktiv: 0,055 s pro Bild, weiterhin 1,32 s pro Loop. Vorschau-GIF unter
`output/necromancer-soul-field-v2/soul-field-preview.gif`.
Die frühere Sechs-Bilder-Version bleibt für Herkunft und Vergleich erhalten.

## Ursprüngliche Freigabe und Quelle

Imagegen-Vorschau erstellt und vom Nutzer am 31.10.2026 ausdrücklich zur
Implementierung freigegeben, mit derselben Animation. Exakter Prompt:
`prompt.txt`. Unveränderte Originaltafel: `approved_sheet.png` (1536×1024,
3 Spalten × 2 Zeilen, sechs 512×512-Bilder, zeilenweise). Keine neue
Bildgenerierung für die Integration. Referenz-GIF unter
`output/necromancer-soul-field-v1/soul-field-preview.gif`.

Runtime: `src/vfx/soul_field.gd`, sechs Phasen à 0,22 s, 1,32 s pro Loop.
Beim einmaligen Laden wird nur der vom äußeren Rand erreichbare dunkle
Vorschauhintergrund transparent gesetzt; eingeschlossene dunkle Geisteraugen
bleiben erhalten. Originaldatei unverändert. Keine Systempfade im Asset.

Integration als bestehender Look `souls` des Talents `soul_11` (Seelensturm).
Treffer, Kosten, Lebensdauer und Reichweite bleiben hostseitig unverändert.
# Rig- und Partikelrevision, 31.10.2026

Der Nutzer fordert aufsteigende, partikelartige Geister mit Rig. Keine neue
Bildgeneration: `scripts/import_soul_spirit_rig.gd` schneidet den bereits im
Spiel genutzten Einzelgeist (122,44,42,86) aus dem ersten bereinigten Frame von
`smooth_sheet_24.png`, skaliert nearest auf 21x43, entfernt getrennte Partikel
und erstellt Kopf, Koerper und zwei Schweifteile. Originale bleiben erhalten.
Bindepose/Teile: `assets/vfx/soul_field/rig/`; Daten:
`assets/data/soul_spirit_rig.json`. Kleine Gelenkueberlappungen bestehen aus
denselben Quellpixeln. Die unteren Teile geben zwischengespeicherte 2x2-
Quellpixelstuecke ab; Augen und Kopf bleiben zusammen. Keine neuen Zeichnungen.
Aktive Regeln/Schema/Einheiten: `docs/NEKROMANT-SEELENPARTIKEL.de.md`.
Die bisherigen 24 Frames bleiben als historische Quelle erhalten; im aktiven
Pool-Overlay ersetzen einzeln animierte Rig-Geister das Ganzkoerper-Flipbook.
