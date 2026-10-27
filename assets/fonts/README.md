# Aktuelle Spielschrift: Pixel Operator8

**Pixel Operator8** von Jayvee Enaguas (HarvettFox96) ist die aktuelle lokale
Spiel-/Editor-Schrift. Ihre klaren Kleinbuchstaben, Ziffern und offenen
Zeichenformen passen zum ruhigen32px-Dungeon. Es ist die proportionale8px-
Variante der Pixel-Operator-Familie, keine breit laufende Arcade-Versalschrift.

- Native Pixelgröße: **8px**; UI-Größen **16/24/32px** entsprechen2×/3×/4×.
  Für Fließtext16px, Zwischenüberschriften24px, Titel32px nutzen.20px möglichst
  vermeiden, da es kein ganzzahliges Vielfaches des Quellrasters ist.
- Unveränderte Original-TTF, lediglich in `pixel_operator8.ttf` umbenannt;
 19.944Bytes. Keine Systeminstallation und keine Laufzeitdownloads.
- **CC0 1.0 Universal**, vollständiger Originaltext lokal in
  [PIXEL-OPERATOR-LICENSE.txt](PIXEL-OPERATOR-LICENSE.txt).
- Quelle ist die vom Autor veröffentlichte
  [Schriftseite](https://www.dafont.com/pixel-operator.font), mit Autorbeschreibung
  und Versions-/Lizenzangabe; ergänzend
  [Font Library](https://fontlibrary.org/en/font/pixel-operator).
- [Herkunft, Prüfsumme und Download](PROVENANCE.md).

`src/pixel_style.gd` behält `create_font()` und `create_theme()` bei und stellt
zusätzlich BASE_SIZE/BODY_SIZE/HEADING_SIZE/TITLE_SIZE bereit. Antialiasing,
MSDF, Hinting und Subpixelpositionierung sind aus; Oversampling1. Kein
automatischer Systemfont-Fallback: fehlende Zeichen müssen bewusst als Wörter,
ASCII oder Icons dargestellt werden.

Die echte Godot-Glyphprobe enthält **ÄÖÜäöüß € · — …**. Die Pfeile **←→**
fehlen, wie schon in der bisherigen Schrift. Aktuelle GDScript-UI-Texte verwenden
sie nicht; künftig ASCII `<-`/`->`, Wörter oder eigene Pixelicons nutzen.
Längere Beschreibungen benötigen Wortumbruch; die neuen Glyphen sind bei gleicher
nomineller Größe größer und breiter als Pixelify Sans. Ganzzahliges Skalieren
bleibt ideal; bei Bildschirmformaten mit anderen Faktoren verhindert Nearest
Unschärfe, kann jedoch unterschiedlich breite Bildschirmpixel ergeben.

## Historisch: Pixelify Sans

Die lokale UI-Schrift ersetzt die zuvor verwendete Systemschrift Consolas.
Pixelify Sans hat sichtbare Pixelkonturen und proportionale Buchstabenbreiten;
Groß-/Kleinbuchstaben sowie deutsche Umlaute und ß/ẞ sind enthalten.

- Schrift: **Pixelify Sans**, Stefie Justprince / Pixelify Sans Project Authors.
- Unveränderte variable TTF (Gewichte400–700), lokal nur umbenannt in
  `pixelify_sans.ttf`;79.160Bytes. Keine Laufzeit-Downloads oder Systeminstallation.
- Lizenz: **SIL Open Font License1.1**, unverändert als [OFL.txt](OFL.txt) beigelegt.
- Offizielle [Google-Fonts-Metadaten](https://github.com/google/fonts/blob/main/ofl/pixelifysans/METADATA.pb),
  [Original-TTF](https://github.com/google/fonts/blob/main/ofl/pixelifysans/PixelifySans%5Bwght%5D.ttf),
  [Original-Lizenz](https://github.com/google/fonts/blob/main/ofl/pixelifysans/OFL.txt)
  und [Schriftprojekt](https://github.com/eifetx/Pixelify-Sans).
- Bezogen am25.10.2026. SHA256 der unveränderten Schriftdatei:
  `9ba86cd010a4de309d263ceff8e8044092c9db7efda869620cb9ff1c4389e8a5`.

`src/pixel_style.gd` erstellt die gemeinsam verwendete Schrift und das UI-Theme.
Runtime-Rasterung: kein Antialiasing, kein MSDF, kein Hinting, kein Subpixel-
Positionieren, Oversampling1 und kein automatischer Systemschrift-Fallback.
16/24/32Pixel Schriftgröße passen besonders gut zum Pixelraster.

Die Zeichen `·`, `—` und `…` sind vorhanden. Häkchen, Pfeil und großer Kreis
(`✓`, `→`, `●`) sind nicht enthalten; dafür Wörter, ASCII oder Pixelicons nutzen.
Godot-Glyphprüfung und eine OpenGL-Schriftprobe bestätigen die deutschen Zeichen
und unterschiedliche Breiten von `iiii` und `WWWW`. Die OFL ist beim Weitergeben
der Schrift mitzuführen.
