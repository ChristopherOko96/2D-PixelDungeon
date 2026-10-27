# Test-Fixtures

Feste Eingabedaten für Tests, unabhängig von den aktiven Spieldaten.

- `dungeon_rooms_rect4.json`: die ursprüngliche Bibliothek mit vier rechteckigen
  32-px-Vorlagen (split_pillars, broken_gallery, buried_crossing, Boss
  heart_of_stone) aus Commit a71387d, nur `generator_version` auf 4 gesetzt. Die
  Vorlagen hatten bereits das heutige Rechteck-Format. Genutzt von
  `dungeon_editor_integration_test.gd`, dessen Malkoordinaten auf diese
  Geometrie abgestimmt sind. Die aktive Bibliothek `assets/data/dungeon_rooms.json`
  enthält seit Story015 die zehn Krypta-Räume und eignet sich dafür nicht.
