# Aktuelle Figuren:32×32-Chibis und der Schläfer der Tiefe

Stand27.10.2026. Die jüngsten Nutzerkorrekturen bestimmen **32×32-Pixel-Sprites
mit niedlicheren Chibi-Proportionen**. Größere Köpfe, gut getrennte kurze Beine,
kräftige kleine Hände und Stiefel ersetzen den anatomischeren Zwischenentwurf.
Die vier Spielerfarben, Waffen und grundlegenden Gegnerrollen bleiben erkennbar.

Die drei gelieferten Höllenbilder dienen ausschließlich als Referenz für die
Pixeldichte. Ihr Höllen-/Lava-Thema, ihre Materialien und ihre Raumgeometrie
werden nicht übernommen. Die ruhige32px-Krypta mit orangefarbenen Fackeln bleibt.

Der frühere rote gehörnte Hüter ist durch **Der Schläfer der Tiefe** ersetzt:
ein blaugrünes Lovecraft-artiges Wesen mit großem Tentakelkopf, Jadeaugen,
kurzen kräftigen Gliedmaßen und gefalteten Rückenflossen. Sein bisheriger
Kampfablauf und sein Auftritt ausschließlich in Raum10 bleiben erhalten.

## Tatsächliche Pixelgrößen

Alle128 gerichteten Schlüsselbilder in `assets/actors/chibi32/keys/` sind
**exakt32×32 RGBA-Pixel**. Ihre Alpha ist0 oder255. Die sichtbare Körperhöhe
liegt etwa bei26px, beim Boss28px; der Fuß endet vor der letzten transparenten
Bildzeile. Spieler und normale Gegner erscheinen im Spiel bei2×, der Boss3×.
Jeder Quellpixel bleibt dadurch ein scharfes ganzzahliges Quadrat.

Die großen generierten Master-Sheets sind Bearbeitungsvorlagen, keine angeblichen
32×32-Dateien. Der Offline-Importer liest vollständige Alpha-Silhouetten aus
ihnen, statt ungleichmäßige Reihen mit starren Viertelzuschnitten abzuschneiden.
Pro Figur gilt ein gemeinsamer Maßstab für alle16 Posen, eine64-Farben-Palette
mit reservierten hellen/Jadeakzenten und ein fester Fußanker. Kein Arm oder
Stiefel wird separat gestaucht. Der native32px-Export wird im Spiel mit
Nearest-Filterung dargestellt. Der weichere Downsample-Vergleich wurde verworfen.

Die Animationszellen sind wegen ihres transparenten Bewegungsrands größer als
32×32: normal36×44–46, beim Boss39×46. Diese Reserve bewahrt ausgestreckte Hände
und Waffen; sie erhöht weder Körperauflösung noch Kollisionsradius.

## Animationen und Werkstatt

**Animation-Studio.cmd** öffnet den aktuellen Stand. Alternativ
`./scripts/Dev.ps1 AnimationStudio` oder `src/animation_studio.tscn` mit F6.
Figur, Aktion, Richtung, Tempo und Zoom sind wählbar; Pause und Einzelbilder
erleichtern den Vergleich. Die Standardansicht ist2×, damit auch der neue Boss
vollständig sichtbar bleibt. Zum Spiel öffnet den normalen Prototypen.

Alle acht Figuren behalten ihre48 Bewegungsabläufe in vier Richtungen mit je
sechs Bildern:9.216 Frames. Sie entstehen aus den neuen Richtungs-Keyposen und
getrennten Körperteilkurven. Das sind keine48 vollständig handgezeichneten
Aktionssets.35 Aktionskennungen sind rollenabhängig an vorhandene Spielzustände
angebunden,13 vorbereitet. Die neuen Zauber-Keyposen halten den Stab stabil;
der historische Attack→Idle-Remap ist in dieser neuen Art nicht nötig.

Der Boss besitzt einen eigenen Kopf-/Taillenschnitt, damit die längeren
Gesichtstentakel beim Kopf bleiben. Die16 vorberechneten Farb-/Flashatlanten
benötigen zusammen122.038.272 RGBA-Bytes (etwa116,38MiB). Alle Atlanten bleiben
unter4096px je Achse. Die Bank erzeugt im Spiel keine Bilder; Frameobjekte werden
begrenzt wiederverwendet. Das ist keine neue FPS-/LAN-/Lastfreigabe.

## Quellen und Wiederaufbau

Erzeugung und Stilüberarbeitung erfolgten mit dem eingebauten Imagegen-Tool.
[Alle Quellen, exakten Prompts und native Exporte](../assets/actors/chibi32/PROVENANCE.md).
Die realistischeren Zwischenentwürfe unter `assets/actors/detail32/` sowie die
früheren Story023-Quellen bleiben als Historie erhalten und sind nicht aktiv.

`assets/data/actor_detail_profile.json` beschreibt `schema_version`,
`visual_revision`, `source_root`, `key_root`, `report_path`, `alpha_threshold`,
`palette_limit`, `directions`, `poses` und die acht `actors`. Je Figur gelten
`id`, `name`, `canvas`, `idle_height`, `render_scale`, `base_feet` und `source`.
Die Werte32/26/28 bestimmen Canvas/Körperreserve;2/3 sind Integer-Weltmaßstäbe;
0,6 begrenzt transparenten Quellsaum;64 begrenzt die Palette. Diese Angaben
ändern keine HP, Geschwindigkeit, Reichweite oder Spielfähigkeiten.

```powershell
& '../tools/godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script res://scripts/import_actor_detail_keys.gd
& '../tools/godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script res://scripts/bake_actor_animations.gd
& '../tools/godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe' --headless --path . --import
```

Der Baker akzeptiert optional `-- --catalog res://assets/actors/...json` für
eine getrennte Kandidatenbibliothek. Erst nach erfolgreichem Bake wurde die
aktuelle `assets/data/actor_animations.json` umgestellt. Der historische Katalog
bleibt als `assets/actors/legacy_actor_animations_story023.json` erhalten.
Schema1 erhält optionale `visual_revision`/`profile_path` und
`actors[].rig`-Overrides; fehlende Overrides verwenden bisherige Rigwerte.

## Geprüfter Umfang

Native Assets691/0, Zuschnittregression33/0, vollständige Bank21.597/0,
Rig8/0, Controller14/0, Studio1.965/0 und Gameintegration38/0 bestanden.
Vorher sah der aktive Assetvertrag noch die alte Revision (RED1/1); der Test
für ungleichmäßige Reihen fehlte (RED1/1). Import und Parse sind erfolgreich.
GPU-Aufnahmen zeigen sechs Beispielaktionen, die Werkstatt und einen normalen
Solo-Start. Das ist kein vollständiger Playthrough und keine pauschale
ästhetische Abnahme aller Frames. Dein Feedback bestimmt weiteres Polishing.

[Animierte Vorschau](../production/qa/evidence/story-024-detail32-eldritch/07-eight-actors-animation.gif),
[Werkstatt/Boss](../production/qa/evidence/story-024-detail32-eldritch/02-animation-studio.png),
[Krypta](../production/qa/evidence/story-024-detail32-eldritch/03-crypt-reference.png).

Persönlicher Dungeon unverändert:
SHA256 B8AFDCE111E0005407E1CE0BCF4427276EFED51CC987C65099671C82701BBF16.
Vier Spieler,48Perks, zehn Karten, Hostsicherheit und Raumabschluss bleiben.
