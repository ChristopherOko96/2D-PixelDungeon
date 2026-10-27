# Ruhiger erster Prototyp und frühere Tile-Restaurierung

## Aktuell: ruhiger 32px-Boden, klare Mauerkanten, orange Feuer

Die jüngste Nutzerkorrektur vom 26.10.2026 wählt ausdrücklich den **ersten
Godot-Prototyp 44c9b80**. Die zwischenzeitliche Rückkehr zu den kräftigen Farben
des gelieferten Dungeon-Packs ist damit ebenfalls abgelöst. Aktiv sind der
ursprüngliche ruhige Schieferboden `assets/sprites/floor_stone.png`, eine
begrenzte grau-violette Mauerpalette mit klaren Kronen und Vorderflächen sowie
das warme orange Feuer aus `assets/sprites/torch.png`. Nearest und32px-Raster
bleiben erhalten. Die ursprünglichen PNGs werden nicht überschrieben.

`render_style=classic_quiet` schaltet diese Darstellung ein. Die bestehende
Wandkontur und ihre Zellmasken bleiben die Formvorlage; die gesättigten Farben
und dichten generierten Materialtexturen werden dafür nicht gezeichnet.
`UnifiedSkin.active=false` bleibt bestehen.

**Derzeit keine Raumdekoration:** Möbel, Pflanzen, Grabobjekte, Truhen,
Belohnungssockel und Nebel/Hintergrundpartikel sind ausgeblendet. Gameplay-Türen,
der Innenabstieg, Fackeln, Figuren und die automatisch erscheinenden
Belohnungskarten bleiben. Spätere Requisiten müssen denselben ruhigen Pixelstil
aufnehmen. Vorhandene Asset-Dateien bleiben als Quellen erhalten.

Alle zehn Karten und die vorhandene Wand-/Kollisionslogik bleiben erhalten;
Raum10 ist weiterhin der Bossraum. Der persönliche gespeicherte Entwurf wird
nicht verändert. Editor, Erkundung, Belohnungskarten und Schwarzblenden bleiben
Teil des Prototyps. Dies ist keine Rückkehr zum alten Drei-Raum-Spielstand.

Für die Ruckler wurden statische Flächen aus der laufenden Zeichenarbeit
genommen: ein vorbereiteter Boden und vorbereitete Wandzeilen werden bei
Raumänderung aufgebaut. Die Wandzeilen bleiben mit Figuren nach Tiefe sortiert.
Zusätzlich werden Kollisions-/Navigationsdaten wiederverwendet und unveränderte
Raumgeometrie in Netzwerk-Snapshots zwischengespeichert.

Gezielte CPU-Profile verwenden dieselbe Gartenkarte mit 1769 Tiles, einem Spieler
und sechs Gegnern in einer isolierten tatsächlichen GPU-DungeonView. Jeweils
120 Zeichenvorgänge wurden vor und nach der Änderung gemessen:

| Aufwand | Vorher | Nachher |
| --- | --- | --- |
| CPU-Zeit in `_draw`, Median | 15,343 ms | 0,353 ms |
| CPU-Zeit in `_draw`, 95. Perzentil | 17,079 ms | 0,386 ms |
| Zehn identische blockierte Garten-Pfadanfragen, gesamt | 1878,081 ms | 11,223 ms |

Die einmalige Vorbereitung der Darstellungsdaten betrug 38,466 ms; der erste
Navigationsgraph benötigte 50,327 ms. Alle zehn ausgegebenen Pfade hatten beim
Abgleich mit der ursprünglichen Kollision keine blockierten Segmente. Dies sind
gezielte Render-/Navigationsprofile, keine breite Testserie und keine Messung
der gesamten Spiel-Frametime oder GPU-Zeit.

Eine zusätzliche sichtbare Solo-Messung im normalen Prototyp mit sechs Gegnern
auf der Gartenkarte ergab über sechs Sekunden 143,98 FPS, 6,95 ms mediane
Bildzeit und 8,29 ms im95.Perzentil (RX6600, VSync,864Frames). Die tatsächlichen
Game-Callbacks lagen bei0,16 ms Prozess-/1,48 ms Physikzeit im95.Perzentil.
Die erste versteckte Aufnahme lag dagegen bei50FPS und ist als eigener
Messzustand dokumentiert. Die Hostdarstellung erhält Positionen jetzt pro
Physiktick; Netzwerkpakete bleiben bei20Hz. Vier-Spieler-Leistung, längere
Durchläufe und die manuelle Bild-/Spielabnahme bleiben offen.
[Messdaten](../production/qa/evidence/classic-quiet/performance.json),
[Story017](../production/epics/dungeon-rooms/story-017-quiet-classic-performance.md).

## Historisch: Original-Pack-Restaurierung vor dieser Korrektur

Die folgenden Angaben und die Aufnahmen unter `restored-original-pack/`
beschreiben den abgelösten Zwischenstand, nicht die aktuelle Art Direction.

Stand:26.10.2026. Der Nutzer hat die dichte, graue Material-Neugestaltung
verworfen und die Rückkehr zu seinen Tiles beziehungsweise der Stimmung des
ersten eingecheckten Prototyps verlangt.

## Tatsächlich verglichene Referenzen

- Erster Godot-Prototyp: Commit `44c9b80`, vorhandene Aufnahme
  `production/qa/evidence/godot-prototype.png`. Ruhige32px-Flächen, klare erhöhte
  Mauern, sparsame Details, orange Fackeln und warme Akzente.
- Erster Seed-Prototyp: `a71387d`, `godot-seeded-dungeon.png`.
- Die vier später gelieferten Original-Atlanten unter `assets/tilesets/` und
  der eigene Raum `dungeon_mein_entwurf.json`. Diese Atlanten waren noch nicht
  im ersten Godot-Commit enthalten; die Referenzen werden nicht gleichgesetzt.

## Damalige Darstellung

`UnifiedSkin.active=false` deaktiviert die abgelehnte Materialprojektion global.
Editor und Spiel laden wieder die unveränderten Originalzellen. Die experimentellen
Quellen bleiben als Archiv erhalten und werden nicht automatisch aktiviert.

Die zehn vorhandenen Karten sind auf die Original-Paletten umgestellt:

| Vorlage | Palette |
| --- | --- |
| Vorhalle | amber |
| Ossarium | violet |
| Sarkophaghof | rose |
| Kapelle | amber |
| Katakomben | moss |
| Garten | moss |
| Archiv | amber |
| Grab der Namenlosen | moss |
| Trauerhallen | rose |
| Bosskrypta | violet |

Explizit gemalte Tile-IDs **und** neu erzeugte Boden-/Wand-/Eingangs-Tiles
verwenden die jeweilige Palette. Ein bloßer Wechsel des `theme`-Felds würde bei
freien Karten nicht ausreichen. Die Konturrollen und32px-Koordinaten bleiben
erhalten, seltene Bodenvariation bleibt bei1/30. Türen verwenden `items_002`,
der Innenabstieg in der Bosskrypta `violet_000`.

Die echte Fackelgrafik aus dem ersten Commit (`assets/sprites/torch.png`) ersetzt
die neue Seelenfeuerschale an den klassischen Feuerpositionen. Oberes Flammenlicht
und Funken flackern; der untere Halter bleibt fest. Räumliche Kontaktschatten und
Nearest-Filter bleiben erhalten. Keine neue Steintextur wurde erzeugt.

Statische Krypta-Deko verwendet passende Original-Pack-Ersatzgrafiken, etwa
Grabtruhen, Altartische, Fässer, Schädel, Knochen, Archivrollen und Gedenkbanner.
Die Palette benennt diese tatsächlichen Entsprechungen. Eine genaue Sarkophag-
oder Statuenzeichnung ist im gelieferten ItemSheet nicht vorhanden.

Die Pflanzen-/Effektanimationen bleiben für die Raumthemen nutzbar. Nach ihren
festen Körper-/Effektmasken werden alle Frames einschließlich Frame0 auf dasselbe
Raster aus zwei Weltpixeln projiziert. So passen sie zur16px-auf32px-Darstellung,
ohne dass Töpfe oder Sockel wieder zwischen Frames verrutschen. Originalbilder
werden dabei nicht überschrieben.

## Erhaltene Funktionen und Sicherungen

Zehn unterschiedliche Vorlagen, gemischte Zwischenräume, Boss nur in Raum10,
Belohnungskarten, freie Erkundung, Schwarzblenden, Multiplayer-Grundlage und
direktes Spielen der Editor-Auswahl bleiben erhalten. Es gab keinen Git-Reset
und keine Rückkehr zur alten Drei-Raum-Spielmechanik oder zum alten vollen HUD.

Vor dem Umstellen wurden aktive Bibliothek und Kandidat über den Editor-Store
gesichert. Dateinamen unter `user://dungeon_editor/backups/`:
`dungeon_1793035287_40894690.json` und `dungeon_1793035287_41197175.json`.
Die Migration vergleicht alle nichtgrafischen Raumdaten auf Unverändertheit.
Der persönliche Originalentwurf behält SHA256
`b8afdce111e0005407e1ce0bcf4427276efed51cc987c65099671c82701bbf16`.

Import, Syntax und authoringseitige Konfigurations-/Zehnerfolgen-Prüfung waren
für diesen Zwischenstand abgeschlossen. [Historische Ansichten](../production/qa/evidence/restored-original-pack/README.md)
sind direkte Raumaufnahmen, kein gespielter Komplettlauf. Keine breite Unit-,
Netzwerk- oder Performance-Testserie gestartet. Visuelle Nutzerabnahme bleibt offen.
