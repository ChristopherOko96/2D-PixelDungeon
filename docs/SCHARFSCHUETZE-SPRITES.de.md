# Scharfschütze: neue Angriffssprites

**Nachtrag 05.11.2026:** Der Himmelsspeer verwendet jetzt einen Neun-Teile-Rig,
zwei geriggte Nachlaufketten und zusätzliche physische Lade-/Flugpartikel.
Das ersetzt seine nachfolgend dokumentierte Vier-Teile-Fassung.
Aktueller Ablauf und Parameter: [HIMMELSSPEER-RIG.de.md](HIMMELSSPEER-RIG.de.md).

04.11.2026, `codex/port-0x72-onto-main`. Der Nutzer hat nach der gezeigten
Angriffstafel ausdrücklich die Umsetzung im aktuellen Spiel beauftragt.

Die sieben vorhandenen Fähigkeiten verwenden neue native Effektgrafiken und
Bewegungen der vorhandenen 0x72-Elfe. Die Tafel ist eine Stilvorlage; ihre
grüne Kapuzenfigur ersetzt nicht stillschweigend die aktuelle Spielfigur.
Keine neuen Schadenswerte, Reichweiten, Abklingzeiten oder Netzwerkfelder.

| Fähigkeit | Aktuelle Darstellung |
| --- | --- |
| Gezielter Schuss | Eigener heller Pfeil, Körper-/Kopfrückstoß, gespannter Bogen |
| Durchschuss | Verstärkte goldene Pfeilspitze, stärkerer Rückstoß |
| Jägermal | Native goldene Zielmarke an tatsächlich markierten Gegnern, kurze Zielhaltung |
| Salve | Drei eigenständige Pfeile mit eigener Befiederung entlang der echten Flugbahnen |
| Rückwärtssalto | Körperdrehung mit angehobenem Schwerpunkt, Staub an den vom Host bestimmten Endpunkten |
| Pfeilhagel | Bogen hebt sich, fallende Pfeile und kurze Treffer-/Splitterbilder, einschließlich Schlusswelle |
| Himmelsspeer | Neuer goldener Pfeil im bestehenden Vier-Teile-Rig, bezahlte Ladung, Wandkontakt und getrennte fallende Teile |

Die Bewegungen sind Gelenk-/Körpertransformationen vorhandener Quellteile,
keine neue handgezeichnete Helden-Animationsserie. Der Rückwärtssalto bleibt
die bestehende Host-Bewegung; die Körperdrehung ist lokale Darstellung.
Bewegung und Halten einer Waffe verwenden gemeinsame Darstellung in Krypta
und Story-Welten. Neue Texturen entstehen nicht pro Bild.

## Dateien und Wiederherstellung

`assets/sprites/marksman/source/approved_attack_board.png` ist die freigegebene
Tafel, `attack_effects.png` der separat generierte transparente Effektmaster.
Quellen und exakte Prompts: `assets/sprites/marksman/PROVENANCE.md` und
`source/attack_effects_prompt.txt`. Originale 0x72-PNGs bleiben erhalten.

`scripts/import_marksman_sprites.gd` schneidet den Master proportional in vier
Spalten und drei Reihen. Es entfernt Alpha unter 0,65, schneidet auf den
sichtbaren Inhalt, skaliert mit Nearest und quantisiert auf die dokumentierte
18-Farben-Palette. Pfeile werden nativ 7×21, die übrigen Bilder 16×16.
Alle verbleibenden Pixel haben Alpha 1. Die erzeugte Speergrafik verwendet
unverändert die inklusiven Rechtecke, Eltern und Pivots in `marksman_rig.json`.

Aufruf: Godot mit `--headless --path . --script res://scripts/import_marksman_sprites.gd`,
danach regulärer Assetimport. Maschinenabhängige Enginepfade stehen nicht in
den Assets. Runtime-Cache und Zeichnen: `src/vfx/marksman_sprites.gd`.

## Animationszustand

`src/hero/marksman_motion.gd` beobachtet nur bestätigte `cast`-Ereignisse für
den jeweiligen Besitzer. Das Alter kommt aus `span-life`, der lokale Takt
füllt zwischen Snapshots auf. Wiederholte Pakete starten keine neue Bewegung.
Tod, Ablauf, fehlendes Ereignis und explizites Run-Reset entfernen die Pose;
Himmelsspeer-Ladung folgt `player.talents.charge`.

Die lokalen Darstellungszeiten in `DURATIONS` sind Sekunden: 0,36/0,40/0,45/
0,42/0,50/0,48/0,42 für Schuss/Durchschuss/Mal/Salve/Salto/Hagel/Speer.
Sie ändern weder die sofortige Host-Auslösung noch Aktionskosten oder Sperren.
Neue Daten verlassen die lokale Darstellung nicht.

## Prüfen und ausprobieren

`Waldmeister-Testraum.cmd` → **FERN**. **Präzision** zeigt Schuss, Durchschuss,
Mal und Salve auf 1–4. **Fernkampf** zeigt Schuss, Mal, Salto und Hagel.
In beiden Belegungen R halten und loslassen für den Himmelsspeer.

Die Aufnahmen unter `production/qa/evidence/marksman-sprites/` zeigen alle
sieben echten Casts durch den aktuellen Renderer in vorbereiteten Trainingszuständen.
Sie sind keine erspielte Kampagne, LAN-Abnahme oder Leistungsmessung.
Prüfergebnisse und Einschränkungen stehen dort in `README.md`.
