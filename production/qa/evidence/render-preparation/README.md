# Gemeinsame Darstellungsdaten und vorbereitete Treffer-Materialien

04.11.2026, lokale Änderungen auf `codex_v2`, zusätzlich zu Gegnerindex und
Gasoptimierung. Nicht committed/gepusht.

## Änderung

Die drei Story-Talent-Zeichenschichten (Welt, über den Figuren, Bloom) teilen
einen `TalentCombat.snapshot()` pro Prozessbild und Simulationszeit. Ein neuer
Frame, eine geänderte Zeit, Update, synchronisierte Talentaktion, Bind oder
Release verwirft den Cache. Die Simulation und `take_feel()` behalten ihren
eigenen aktuellen Snapshot pro Spielschritt; Catch-up, Treffer und Sound werden
nicht gedrosselt. Die Zeichenschichten lesen die gemeinsame Kopie nur.

`Feedback._observe_enemy()` verwendet vorbereitete Materialdaten: einmal pro
angefragtem Typ eine Kopie der Materialdefinition und die ausgewerteten Farben.
Die bisherigen Treffer-/Todesereignisse und Zustandszähler laufen weiter pro
Gegner und Schritt. Die öffentliche Funktion `gore()` liefert weiterhin eine
unabhängige Kopie. Der Cache gehört der Feedback-Instanz; die Konfiguration ist
wie die bisherige Gore-Tabelle während der Laufzeit unveränderlich.

Die gesamte Gegnerliste wird weiterhin pro Simulationsschritt für Feedback
aufbereitet. Ein Überspringen dieser Arbeit wäre ein weiterer Eingriff mit
Auswirkungen auf Bewegungs-, Treffer- und Sounderkennung und ist nicht Teil
dieser Änderung.

### Fortsetzung am 05.11.2026: fallende Gegner

Die lebenden Gegner behalten die vollständige Aufbereitung. Bereits unter
`_fallen` vorhandene Körper werden dagegen vor `_enemy()` erkannt: Ihre
abgetrennte Todesansicht liegt schon vor und wird direkt verwendet. Zuvor wurde
für diese Körper zusätzlich eine lebende Ansicht erstellt und anschließend
verworfen. Dabei wurde jedoch `m.feel_e` überschrieben und dessen `dying_p`
für den Rig-Renderer entfernt. Die neue Sammlung erhält den Todesfortschritt.

`story_feedback_snapshot_test`: acht Prüfungen. Mit unverändertem altem
Sammlungsverfahren zwei erwartete Fehler beobachtet (129 statt einer
Aufbereitung; verlorener Todesfortschritt), nach Korrektur acht bestanden.
Abgedeckt sind 128 fallende Körper plus ein lebender Gegner, Treffer/Bewegung
des Lebenden, bereits aus der Gegnerliste entfernte Körper und Raum-Reset.
Das ist ein deterministischer Arbeitsnachweis; kein zusätzlicher FPS-Prozentwert.

Zusatzprüfung `story_sound_test`: Der Datenkatalog-Check meldet fehlende
Sound-Materialzuordnungen für `curse_colossus` und `curse_spawn`. Die gleiche
Abfrage gegen `git show HEAD:assets/data/audio_sfx.json` und
`HEAD:assets/data/hell_rigs.json` liefert exakt dieselben beiden Namen.
Die FPS-Änderung verändert diese Tabellen nicht; dieser Befund ist separat.
Der vollständige Zusatzlauf endet mit 110 Prüfungen und genau diesem einen
Fehler (109 bestanden), Exitcode 1; keine Script-/Parse-Fehler. Beim Beenden
meldet diese größere Suite 906 Texture-RIDs, 2333 ObjectDB-Instanzen und 31
noch verwendete Ressourcen. Protokoll: `sound-final.txt`. Zusammen sind die
89 gezielten Prüfungen der Optimierungen grün; die zusätzliche Sound-Suite
bleibt wegen des nachgewiesenen Datenkatalogfehlers rot.

Ein Versuch, alle lebenden Gegner-Dictionaries wiederzuverwenden, wurde nach
gepaarten CPU-Messungen verworfen: ohne Sound etwa 14–15 % günstiger, mit dem
Sound-Adapter in den beiden Versuchen etwa 7 bzw. 30 % langsamer. Die aktive
`_enemy()`-Implementierung bleibt deshalb unverändert. Die Messprotokolle
`views-rejected-*.txt` dokumentieren den verworfenen Versuch; er zählt nicht als
erfolgreiche Optimierung. Die zugehörigen experimentellen Dateien liegen nur
unter dem ignorierten `output/feedback-preparation-baseline`.

## Nachweis

- `talent_render_cache_test`: vor der Änderung erwarteter Fehler „render layers
  share a snapshot“. Danach acht Prüfungen für einmaligen Aufbau, unabhängige
  Ereigniskopie, Invalidierung bei Mutation, Zeitwechsel, Framewechsel bei
  pausierter Zeit und identische Nutzdaten.
- Der erste Framewechsel-Test wurde korrigiert: `process_frame` kann noch zum
  selben Prozessframe gehören. Er wartet jetzt tatsächlich auf einen geänderten
  `Engine.get_process_frames()`-Wert.
- `feedback_material_cache_test`: vor der Änderung erwarteter Fehler „repeated
  enemy material preparation“. Danach 18 Prüfungen für sechs Materialien,
  Farbgleichheit, Wiederverwendung und unabhängig veränderbare öffentliche Kopien.
- `feedback_test`: 19 Prüfungen bestanden.
- `hell_talents_test`: 36 Prüfungen bestanden, tatsächliche Höllen-/Frost-Szenen
  mit Nekromant, Magier, Bogenschütze und Ritter. Insgesamt 81 Prüfungen.

Der Cache-Test misst die echte `TalentCombat.snapshot()`-Serialisierung mit 256
verschachtelten synthetischen Ereignissen, drei Zeichenschichten und 40
abwechselnden Alt/Neu-Messpaaren. Mindestverbesserung dieser Aufbereitung: 20 %.
Im ersten erfolgreichen Lauf 1,322 ms -> 0,365 ms pro dreifacher Abfrage.
Im abschließenden gesicherten Lauf 3,787 ms -> 1,373 ms (rund 64 % weniger).
Die absoluten Laufzeiten schwanken deutlich; beide Vergleiche wechseln die
Reihenfolge innerhalb desselben Prozesses und bestehen das relative Budget.
Dies ist ein isolierter CPU-Nachweis, **kein FPS- oder Gesamtspiel-Benchmark**.
Der deterministische Nachweis ist die Reduktion von drei Aufbauten auf einen.

Aus dem Projektverzeichnis mit Godot 4.7.2:

```text
godot --headless --path . -s res://tests/talent_render_cache_test.gd
godot --headless --path . -s res://tests/feedback_material_cache_test.gd
godot --headless --path . -s res://tests/feedback_test.gd
godot --headless --path . -s res://tests/hell_talents_test.gd
```

Bekannt: Die Testumgebung kann `user://logs/godot.log` nicht öffnen; separate
Shell-Logs werden in diesem Verzeichnis gesichert. Keine GPU-/Mehrspieler-Abnahme.
Der Story-Test meldet beim Beenden außerdem die bereits bekannten 887 Texture-
RIDs, 2258 ObjectDB-Instanzen und sechs noch verwendeten Ressourcen. Seine
36 Prüfungen sind bestanden; diese Aufräumwarnungen sind nicht behoben.
