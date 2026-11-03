# Nekromant — scharfe Originalanimationen

Aktualisierung 02.11.2026: **40 Fälle, 5150 native PNG-Frames**. Knochenball,
alle drei Fluch-Ulti-Stufen und die neuen Koloss-Befehle Fluchwelle/Totenbrut
wurden direkt neu aufgenommen. Aktuelle Regeln und Nachweise:
`production/qa/evidence/curse-evolution/README.md`. Die folgenden Zahlen von
38 Fällen dokumentieren den ursprünglichen Qualitätswechsel; die aktuelle
gemeinsame Ansicht und Browserprüfung umfassen alle 40 Fälle.

Der Nutzer konnte die verkleinerte, stark komprimierte Vorschau nicht beurteilen.
Diese Fassung ersetzt sie zur visuellen Prüfung. Kein neuer Artentwurf und keine
Änderung an Talent-/Kampfregeln; ausschließlich Aufnahme und Darstellung.

## Quelle und Qualität

`scripts/capture_necromancer_catalog.gd -- --hq` hat alle 38 Fälle erneut aus
dem tatsächlichen Godot-GPU-Viewport aufgenommen: **4786 PNG-Einzelbilder,
640×360, 30 Bilder/s**. Die Simulation verwendet weiterhin 60-Hz-Schritte.
Das Rechteck (320,210,640,360) wird aus dem 1280×720-Viewport ausgeschnitten;
kein Resize und kein Videocodec. Die PNGs bewahren Farben und Pixelpositionen.
Zusätzliche Verkleinerung, verschmierte Videoblöcke und reduzierte Farbpaletten
entfallen; die ursprüngliche Spiel-Pixelgrafik bleibt erkennbar.

Es gelten dieselben kontrollierten Vorbedingungen wie beim früheren Katalog:
gültige Level-30-Builds, vorbereitete stationäre Gegner, Seelen-/Blutvorrat
und gezielte Todesauslöser. Keine verdiente Kampagne, kein Leistungstest und
keine neue Nutzerabnahme. Log: `Logs/necromancer-catalog-hq-gpu.log`;
38 vollständige Fälle, keine SCRIPT ERROR/Assertions. Die vorhandenen
6 ObjectDB-/2 Ressourcen-Aufräumdiagnosen der Game-Fixture bleiben vermerkt.
Die laufende Konsolenausgabe nennt noch die 15-Hz-Basisbildzahl;
`catalog.json` und die Frame-Dateien enthalten die korrekte doppelte 30-Hz-Zahl.

## Gemeinsame Ansicht

`output/necromancer-catalog/nekromant-original.html` zeigt alle drei Zweige,
38 Animationen und 21 passive Talente in **einem** lokalen Browserfenster.
Start: `Nekromant-Angriffe.cmd`. Abspielen/Pause, einzelne Frames, Zeitachse
und Vollbild; der tatsächlich pausierte Frame bleibt stehen. Es werden die
Original-PNGs geladen, kein Ersatzvideo. Pro Auswahl werden nur deren Bilder
vorgeladen; vorherige Decoderbilder werden freigegeben.

Die begleitende Inline-Auswahl zeigt für jede Fähigkeit einen unveränderten
640×360-Frame derselben Aufnahmen. Sie ist ausdrücklich eine Bildauswahl;
die vollständigen Animationen stehen im lokalen Fenster. Eingebettete PNGs
sind bytegleich mit `output/necromancer-catalog/original-stills/`, ohne
Skalierung oder Umfärbung. So bleibt die Inline-Größengrenze erhalten,
ohne dafür die Animationen erneut unkenntlich zu komprimieren.

Builder: `scripts/build_necromancer_original.cjs`; Literalvorlage und lokale
Hülle: `output/necromancer-catalog/*original*.html`. Eine zusätzliche
verlustfreie APNG-Verpackung des Seelenblitzes liegt unter
`output/necromancer-catalog/seelenblitz-original.png`, 92 Frames/30 Bilder/s,
erzeugt durch `scripts/necro_original_apng.cjs` ohne Videokompression.

## Verifikation

`scripts/check_necromancer_original.cjs` prüft im tatsächlichen Chrome:
alle 38 Auswahlen laden die vollständigen Framezahlen, keine duplizierten
Optionen, Wiedergabe verändert den Frame, Pause hält ihn an, Einzelbildschritte
und Layoutbreiten 1360/736/360/320 funktionieren. Inline-PNGs werden bytegenau
mit den Original-Dateien verglichen (640×360). Keine JavaScript-Ausnahmen.
Ergebnis: `output/necromancer-catalog/original-browser-review.json`, Screenshots
`original-review-*.png`. Kein neuer breiter Gameplaytest für diese reine
Präsentationskorrektur. Bisherige Kampf-/Netzwerkbelege bleiben erhalten.
Kein Commit, Push oder Merge.
