# Story011: Ganze Flächen auswählen, löschen und ersetzen

Status: Done ·26.10.2026 · Workflow minimal · lokale Änderungen auf `codex_v2`.

Nutzerklärung: Gemeint ist eine komplette Fläche löschen/ersetzen. Neuer Modus
**Bereich auswählen** markiert mit Mausklick/Drag ein inklusives Rechteck.
Palettewahl erhält die Auswahl. Zwei sichtbare Buttons füllen oder löschen.
STRG+A wählt die ganze Fläche; Entf/Rücktaste löscht; Esc/Rechtsklick hebt auf.

Das Modell verarbeitet die ausgewählten Zellen als Batch, ohne pro Zelle tiefe
Kopien. Die gesamte Aktion belegt einen Undo-Eintrag; identische Aktionen keinen.
Grenzen werden vor32-Bit-Rechtecküberlauf als64-Bit-Werte beschnitten. Layer-only
und sichtbares Ersetzen entsprechen dem vorhandenen Pinsel. Startplätze, Feuer,
Truhe, Nachbarfelder und andere Räume bleiben erhalten. Keine automatische Speicherung.

- Modeltest vor API rot1/1; jetzt **EDITOR_AREA24/0**, einschließlich maximaler
 64×48-Zeichenfläche, zwei Ebenen, Void, No-op, Undo/Redo und Legacy-Säulen.
- UI vor Umsetzung rot1/1; jetzt **EDITOR_AREA_UI20/0** mit echten Drag/Release-
 Ereignissen, Rückwärtsauswahl bei0,5×Zoom, Palette, Buttons und Shortcutguards.
- OpenGL-Bilder: Auswahl, Ersetzen, Löschen und Undo gerendert und angesehen.
 `production/qa/evidence/editor-area-{selected,replaced,erased,undo}.png`.

Anleitung: [Flächen bearbeiten](../../../docs/DUNGEON-EDITOR.de.md).
