# Seelenfeld und Partikelschweif

Aktueller Stand 04.11.2026: Die aktive Darstellung verwendet jetzt echte
simulierte Pixel für Seelen-VFX und reagierende Bodenoberflächen. Der frühere
Rig-/Sprite-Ansatz unten ist historisch bzw. Vorschau-Fallback. Siehe
[Seelen-Materie](SEELEN-MATERIE.de.md) für den aktuellen Anschluss.

31.10.2026. Nutzerwunsch: fließend aufsteigende Feldgeister mit Rig und
Partikelcharakter; entsprechender Schweif am großen Seelenwächter aus der
vorherigen Vorschau. Dieser Schritt bearbeitet diesen beschworenen Geist.

Der Nutzer hat diese Feld- und Schweifdarstellung anschließend ausdrücklich
zur Beibehaltung angenommen. Der nächste [Seelenring](NEKROMANT-SEELENRING.de.md)
verwendet dieselben Geister und ergänzt ein Feld ausschließlich am äußeren Saum.

## Aktive Darstellung

Die Bodenfläche bleibt das vorhandene gemeinsame PoolPaint-Material `soul`
mit der bekannten Lava-Plattenstruktur. Darüber werden fünf kleine Geister
einzeln animiert. Ihr Ausgangspunkt liegt innerhalb der Fläche. Neue Geister
beginnen an der Oberfläche, wachsen beim Aufsteigen aus ihr heraus und
verblassen oben. Die Starts sind zeitversetzt; kein gemeinsames Ganzkörper-
Flipbook und keine vorgealterten Geister beim Anlegen eines neuen Feldes.

Jeder kleine Geist besitzt vier Original-Cutouts: Kopf, Körper und zwei
Schweifglieder. RigLibrary und derselbe RigRenderer-Gelenklöser wie bei den
Skeletten bewegen diese Teile kontinuierlich. Kopf und dunkle Augen bleiben
zusammen. Die Schweifglieder schwingen verzögert und geben kleine Teile ihrer
eigenen Quellpixel ab. Die Festhalte-Geister um einen Gegner verwenden dasselbe
Rig; ihre vorherigen dicken Linien werden durch bewegte Partikelspuren ersetzt.

Am großen Seelenwächter bleiben Kopf, Rumpf, Arme und Hände als feste Cutouts
erhalten. Der mittlere Schweif hat einen zusammenhängenden Kern und bewegte
Fragmente; die Spitze besteht aus einzelnen Quellpixelstücken. Diese hängen
an den tatsächlichen animierten Schweifgelenken und treiben von dort weg.
Die bestehende Staubaura läuft zusätzlich weiter. Das betrifft die lokale
Darstellung in Krypta, Hölle und Frostgruft über den gemeinsamen Talentcode.

Es gibt keine neuen Collider, Treffer, Seelenkosten, Betäubungsregeln oder
Snapshotfelder. Feldreichweite und Dauer bleiben unverändert. Der Partikellook
verwendet harte, nearest-gefilterte Pixel und kontinuierliche Positionen.

## Quellen und Daten

Keine neue Bildgeneration. `scripts/import_soul_spirit_rig.gd` nimmt den schon
verwendeten Einzelgeist aus `soul_field.gd`: Ausschnitt (122,44,42,86) des
freigegebenen ersten Frames von `smooth_sheet_24.png`, danach nearest auf
21×43. Nur die größte zusammenhängende Silhouette bleibt, Alpha wird hart.
Die ursprünglichen PNGs, Prompts und 24 Frames bleiben erhalten.

`assets/data/soul_spirit_rig.json`, Schema 1: bestehendes RigLibrary-Layerformat
mit `size=[21,43]`, `ground=[10,40]`, `parts`. Je Teil `id`, `parent`, `pivot`
in gemeinsamen Quellpixeln, `z`, `img` und inklusive `cut_rects=[x0,y0,x1,y1]`.
Erste passende Maske besitzt den Pixel. Originalpixel im 2px-Kreis am Gelenk
werden auf Eltern- und Kindteil überlappt. Rebuild: Godot
`--headless --path . --script scripts/import_soul_spirit_rig.gd`, danach Import.

Kosmetische Einstellungen in `assets/data/vfx_talents.json`, einmaliger
Abschnitt `soul_motion`:

| Feld | Wert | Einheit / Bedeutung |
|---|---:|---|
| field_ghost_count | 5 | Gleichzeitig gesampelte Geister, höchstens 6 |
| field_ghost_cycle | 3,4 | Sekunden der durch field_playback verlangsamten visuellen Zeit |
| field_ghost_rise | 0,32 | Aufstieg als Anteil des Feldradius |
| field_ghost_scale | 1,35 | Native Pixelgröße bei Radius 112, proportional zum Radius |
| field_mote_count | 42 | Oberflächenpartikel, höchstens 64 |
| field_mote_cycle | 2,6 | Visuelle Sekunden je Aufstiegszyklus |
| field_mote_rise | 0,42 | Partikelaufstieg als Anteil des Radius |
| fragment_cycle | 1,8 | Sekunden bis zum Recycling eines Schweiffragments |
| fragment_spread | 4 | Seitliches Driften in nativen Rigpixeln |
| fragment_travel | 8 | Driften vom Schweif in nativen Rigpixeln |

Kleine Geistfragmente verwenden 55 % der großen Driftwerte. Quellstücke sind
höchstens 2×2 Pixel groß. Die Mini-Texturen werden einmal vorbereitet und
wiederverwendet. Ein stehender Kern des mittleren Schweifs verhindert Lücken
beim Recycling; bewegte Stücke werden vor dem Zurücksetzen unsichtbar.
Keine Ganzkörper-Überblendung und keine Texturerzeugung pro Renderbild.
`FxSprites.draw_external_rig()` begrenzt Teile, Fragmente und Staub gemeinsam
an der Sichtgrenze zum Bodenanker. Partikel verleihen keine Wirkung hinter Wänden.

## Beobachtung und Nachweis

`production/qa/evidence/soul-field-particles/README.md` enthält Prüfungen und
rohe GPU-Bilder. Zwei getrennte Aufnahmen: echte kontrollierte Spielbegegnung
und Nahansicht des gemeinsamen VFX-Renderers mit absichtlich dauerhafter
Präsentationsfläche. Die Nahansicht ist kein Kampf oder Beleg für Felddauer.

Selbst ansehen: **Testraum → Nekromant → Seele**, **4** für das Feld und **R**
für den großen Seelenwächter. Gegner auf das Feld locken, um die kleinen
Festhalte-Geister zu sehen. Benötigte Seelen wie zuvor sammeln.

## Seelensog: Aufnahme im Stab (04.11.2026)

Ausgangspunkt ist der Klassen-Revamp auf `ab181e4a`. Bestätigte Seelenbelohnungen
(`souls`-Event) zeigen jetzt den vorhandenen kleinen Seelengeist: Er steigt am
gefallenen Gegner auf, fliegt mit kurzem Pixelschweif zum Stab, schrumpft in die
Kugel und löst dort einen kurzen grünen Aufnahmeblitz aus. Es werden vorhandene
Cutouts und Texturcaches verwendet; keine neuen generierten Bilder.

Der Endpunkt stammt aus `HeroLook.staff_socket()` nach dem Zeichnen des Helden.
Damit folgt er Bewegung, Blickrichtung und der aktuellen Stabpose. In der
Story-Laufzeit heißt der Socket `hero`, im bisherigen Koop-Renderer `p<owner>`.
Fehlt die aktuelle Pose, dient die aktuelle Brustposition des empfangenden
Helden als Ersatz, zuletzt die im Event gespeicherte Position. Die gemeinsame
Darstellung gilt für Krypta, Frostgruft und Hölle sowie Custom Storys mit
derselben Laufzeit. Andere Klassen und die Effekte des Leerenmagiers bleiben
unverändert.

`src/vfx/soul_absorption.gd` zeichnet ausschließlich. Der Host schreibt die
Seelen wie zuvor unmittelbar beim bestätigten Tod gut. Die Leiste, Obergrenze,
Beute-/Assistregeln und das bestehende 0,7-Sekunden-Event bleiben erhalten.
Die kurze Flugdarstellung verschiebt keine Ressourcenbuchung. Passive
Seelenregeneration erzeugt keinen Gegnergeist.

Einstellungen: `assets/data/vfx_talents.json`, Abschnitt `soul_absorption`:

| Feld | Bedeutung |
|---|---|
| arrival = 0,76 | Ankunft als Anteil der 0,7 Sekunden; Rest ist Aufnahmeblitz |
| shrink_start = 0,62 | Schrumpfen ab diesem Anteil der Flugphase |
| source_lift = 5 | Abstand des Startpunkts über dem Todesort in Kunstpixeln |
| bend = 3, rise = 8 | Seitliche Kurve und Bogenhöhe in Kunstpixeln |
| spirit_scale = 0,28 | Native Geistpixel je Kunstpixel vor dem Schrumpfen |
| trail_count = 5 | Schweifpunkte, technisch auf 0–8 begrenzt |
| pulse_radius = 3 | Maximaler Aufnahmeblitz-Radius in Kunstpixeln |
| max_visible = 24 | Gleichzeitige Aufnahmeeffekte je Bild, technisch höchstens 32 |

Prüfung: `tests/soul_absorption_test.gd` prüft bewegte und veraltete Sockets,
Empfängerzuordnung, Ankunft, Ausblenden und unveränderte tatsächliche
Seelenbuchung. `scripts/capture_soul_absorption.gd` zeichnet eine kontrollierte
Todesbelohnung auf einer aktuellen Krypta-Karte mit bewegtem Nekromanten auf.
Das ist eine Darstellungsprobe, kein vollständiger Kampagnen- oder Netzwerktest.
