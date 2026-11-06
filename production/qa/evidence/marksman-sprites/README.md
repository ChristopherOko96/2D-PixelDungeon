# Scharfschützen-Angriffssprites — 04.11.2026

Implementierung auf `codex/port-0x72-onto-main`, ohne Commit/Push.

## Nachweise

| Prüfung | Ergebnis | Aussage |
| --- | --- | --- |
| marksman_sprites_test | 73 / 0 | Zwölf native Assets, harte Alpha, Texture-Cache, verschiedene Pfeile, Cast-Alter/Besitzer/Ablauf/Tod/Reset und tatsächlich vorhandene Gelenke |
| ranger_vfx_test | 21 / 0 | Native Speerteile, Bewegung, Wandebene und einmalige Splitterauslösung |
| ranger_fields_test | 27 / 0 | Bestehende echte Host-Casts, breite Pfeillinie/Wände, Giftfalle und Rankensog |
| ranger_story_fields_test | 10 / 0 | Bestehende Medien-/Eigentümerintegration in beiden Story-Welten |
| GDScript Parse | 13 / 0 | Alle geänderten Runtime-Skripte und beide neuen Aufnahmeskripte laden |
| capture_marksman_sprites | 7 erfolgreiche Casts, 9 GPU-Bilder | Alle sieben Fähigkeiten im echten aktuellen Spielrenderer, getrennte Charge/Flug/Wandbilder für die Ulti |
| capture_marksman_story | 2 erfolgreiche Casts, 2 GPU-Bilder | Neue Salvenpfeile und Heldenbewegung im tatsächlichen Höllen- und Frostgruft-Renderer |

Die elf Bilder sind rohe 1280×720-Viewportaufnahmen aus vorbereiteten,
isolierten Trainingszuständen. Keine erspielte Kampagne, keine Netzwerk-,
LAN- oder Leistungsabnahme. Die Story-Aufnahmen benutzen die vorhandenen
Testbuild-Helfer und eigene `user://`-Profile; sie verändern keine Spielstände.
Die Laboraufnahme benutzt die vorhandenen Maximalrang-Trainingsbuilds und
stationäre Zielpuppen. Kampfreichweiten/-kosten stammen aus echten Casts.

Die Logs enthalten keine `SCRIPT ERROR`/Parse-Fehler. Die bestehenden
Game-Fixtures melden beim Beenden ObjectDB-/Resource-Warnungen; der
headless Story-Test zusätzlich RID-Ressourcen. Diese Beendewarnungen werden
nicht als behoben ausgegeben. Die neue Asset-/Pose-Suite und die Speer-VFX-
Suite melden diese Warnungen nicht. Die sichtbare Story-Aufnahme meldet beim
Beenden ebenfalls GL-Textur-, ObjectDB- und Resource-Freigabewarnungen.
Diese letzten Meldungen kamen im Prozess-Stderr nach dem Bildnachweis an;
Godots eigene Logdatei enthält sie nicht. Ein Auszug ist separat festgehalten.
Eine behobene Ressourcenfreigabe wird daraus nicht abgeleitet.

## Bilder

- `sniper_1.png`: Gezielter Schuss
- `sniper_3.png`: Durchschuss
- `sniper_5.png`: Jägermal
- `sniper_7.png`: Salve
- `sniper_9.png`: Rückwärtssalto
- `sniper_11.png`: Pfeilhagel
- `sniper_14-charge.png`, `sniper_14-flight.png`, `sniper_14-impact.png`: Himmelsspeer
- `story-hell.png`, `story-frost.png`: Salve in den Story-Welten

## Wiederholen

Godot 4.7.2, Projektwurzel als Arbeitsverzeichnis. Die vier Suiten werden
jeweils mit `--headless --path . --script res://tests/<Name>.gd` ausgeführt.
Für isolierte Profile `APPDATA` auf einen eigenen beschreibbaren Prüfpfad
setzen. Absolute `--log-file`-Pfade vermeiden Godots user://-Logumleitung.

Die GPU-Aufnahmen benötigen einen echten Renderer, ohne `--headless`:

```
godot --path . --script res://scripts/capture_marksman_sprites.gd
godot --path . --script res://scripts/capture_marksman_story.gd
```

Quellen, Importverfahren und Grenzen: `docs/SCHARFSCHUETZE-SPRITES.de.md` und
`assets/sprites/marksman/PROVENANCE.md`. `receipt.json` enthält SHA256-Werte der
neuen Assets und der relevanten Skripte zum Zeitpunkt dieser Aufnahme.
