# Grafik-Schalter Pixel ↔ HD (Stand 29.10.2026)

Auftrag (Dwayne): Schalter HD ↔ Pixel. Entscheidung: eine Einstellung für alle
Welten, umschaltbar im Hauptmenü (Optionen → „HD-Grafik (Hölle)“) und im
Pausenmenü (Anzeige → „Zu HD wechseln“ / „Zu Pixel wechseln“). Gespeichert in
`user://settings.cfg` (`[options] graphics`), wirkt sofort.

## Was es je Welt gibt

| Welt | Pixel | HD |
| --- | --- | --- |
| Hölle | 0x72-Stil (`assets/sprites/hell_0x72/`) | Dwaynes gemalter Satz (`assets/sprites/hell/`), weich gefiltert, Held 3,6-fach |
| Frostgruft | eigener Pixel-Satz | noch keiner – das Pausenmenü sagt „diese Welt hat nur PIXEL-Grafik“ |
| Krypta | 0x72 | noch keiner – derselbe Hinweis |

Jede Welt nennt ihre Sätze in ihren Daten (`"skins": {"pixel": {...}, "hd": {...}}`,
Schlüssel, die die Standardwerte ersetzen). Ein HD-Satz für Frostgruft oder
Krypta braucht nur Bilder und einen Eintrag dort.

## Technik
- `src/core/graphics_settings.gd`: Wahl lesen und speichern, Satz einer Welt, Hinweistext.
- `src/hell/hell_game.gd`: `THEME_DEFAULT.skins`, Satz beim Laden anwenden,
  `apply_graphics(mode)` lädt Bilder neu, setzt die Filterung und baut das
  Helden-Modul in der neuen Größe neu.
- `src/pause_menu.gd`: Grafik-Zeile und Knopf auf der Seite Anzeige.
- `src/main_menu.gd`: Schalter in den Optionen; schreibt nie eine veraltete Wahl zurück.
- Test: `tests/graphics_switch_test.gd` (eigene Einstellungsdatei).
  Belege: `production/qa/evidence/graphics-switch` (`scripts/capture_graphics_switch.gd`).
