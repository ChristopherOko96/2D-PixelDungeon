# Seelenfeld – Umsetzung der bestätigten Animation

31.10.2026. Die sechs bestätigten Imagegen-Bilder werden in derselben
Reihenfolge und mit denselben 0,22 s pro Phase abgespielt. Keine Neugenerierung.
Aktiv am vorhandenen Talent **Seelensturm**, `soul_11`, Look `souls`.
Gemeinsamer `talent_fx`-Renderer für Krypta, Hölle und Frostgruft.

Die Geister sind animierte Darstellung des bestehenden Schadensfeldes,
keine zusätzlichen KI-Begleiter oder neuen Treffereinheiten. Unverändert:
30 Mana, 16 s Abklingzeit, 4 s Dauer, 3 m autoritativer kreisförmiger
Schadensradius, alle 0,8 s 30/35/40 % Schaden. Die sichtbare elliptische
Ritualfläche bewahrt die freigegebene Zeichnung, ist keine neue Kollisionsform.

Sechs alpha-freigestellte Texturen einmalig im Cache; keine Bildbearbeitung
pro Draw oder Wirken. Phasen aus `total-time`, sodass späte Snapshots die
laufende Phase anzeigen. Keine Grafikdaten im Netzwerk. Nearest-Filterung
der Spielansicht bleibt erhalten. Wandbegrenzung über den bestehenden
gecachten Ray-Polygon-Clip in `fx_sprites`, auch für diese externen Frames.

## Nachweise

- `tests/soul_field_test.gd`: 22/0; Reihenfolge, 0,22-s-Takt, Loop, spätere
  Phase, transparenter Rand, Originalmaße und Texturwiederverwendung.
- Bestehende `talent_combat_test`: 339/0; `hell_talents_test`: 18/0.
- GPU-Fixture: `scripts/capture_mage_fireball.gd -- --soul`. Sichtbarer
  Godot-4.7.2-Compatibility-Lauf, 1280×720, eingerichteter Nekromant mit
  gültigem Talentbuild; tatsächliches Wirken von Seelensturm. Sechs PNGs
  `soul-field-00` bis `05` zeigen die Phasen im echten Renderer. Sichtgeprüft:
  Geister/Runen entsprechen der Vorlage, Hintergrund transparent, Rand an
  rechter Raumwand geclippt. Kein gespielter Lauf und kein Mehrspielernachweis.
- Keine SCRIPT ERROR in den Test-/Capture-Logs unter `Logs/soul-field-*`.
  Der lokale Editorimport meldet nicht beschreibbare Editor-Einstellungen;
  PNG-Import erfolgreich. GPU ohne beschreibbaren user://-Shadercache.
  Die Game-Fixtures melden weiterhin 6 ObjectDB-Instanzen und 2 Ressourcen
  beim Beenden; keine Behauptung eines sauberen Ressourcen-/Soak-Tests.

Keine zusätzlichen Elementreaktionen eingeführt: Ein Seelenfeld wird durch
die neue Darstellung nicht automatisch zu Wasser, Gift oder leitender Pfütze.
Keine neue LAN-/Last-/Geschmacksabnahme. Kein Commit, Push oder Merge.
