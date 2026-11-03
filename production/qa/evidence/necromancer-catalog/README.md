# Nekromant — vollständige Angriffsauswahl und Fluch-Umbau

Stand 01.11.2026, Branch `codex/port-0x72-onto-main`. Der Nutzer hat den
konkreten Fluchgeist-Entwurf freigegeben und die Umsetzung sowie eine einzige
gemeinsame Angriffsvorschau des Nekromanten beauftragt.

**Spätere Qualitätskorrektur:** Der Nutzer konnte die stark verkleinerte
Videovorschau nicht beurteilen. Sie ist als Darstellung verworfen. Aktuell sind
alle 38 Aufnahmen erneut in 640×360 Originalpixeln bei 30 Bildern/s vorhanden,
ohne Skalierung, Farbquantisierung oder Videocodec. Die gemeinsame Auswahl
liegt unter `output/necromancer-catalog/nekromant-original.html`, startbar über
`Nekromant-Angriffe.cmd`. Nachweise: `../necromancer-catalog-hq/README.md`.
Die Beschreibungen der kompakten 15-FPS-Vorschau unten sind historisch.

## Tatsächlich integriert

- Eigener Fluchgeist: acht native Teile aus der freigegebenen Tafel,
  bestehender RigLibrary/RigRenderer, kontinuierliche Kiefer-/Klauen-/Schweifposen.
- Sichtbare Fluchumkreisung und gegliederte Flug-/Treffereffekte.
- Echte vorhandene Giftpfützen: normale Tote im eigenen Seuchenfeld oder in der
  Seuchengrube werden zu freundlichen Skelettläufern. Maximal sechs pro Besitzer,
  acht Sekunden Lebensdauer, Verfolgung und einmalige Kontakt-/Todesexplosion.
- Blutstrahl: bis zu vier sichtbare Ziele, Rangreichweite 3/4/5 m, gemeinsames
  Heilbudget. Tote Verbindungsziele senden einen begrenzten Fluchflug weiter.
  Keine rekursiven Armeen oder Todesfluchketten; Wände bleiben maßgeblich.
- Vorhandene Diener-/Blutaufnahme und der komplette Seele-Zweig bleiben erhalten.
  Nekromantenregelschema 5, Sitzungsregelsatz 20, Protokoll 4.

## Aufnahmen und gemeinsame Auswahl

`scripts/capture_necromancer_catalog.gd` zeichnet tatsächlich gerenderte
Godot-Spielbilder auf. `catalog.json` enthält 38 abgeschlossene Fälle samt
aktuellen Talentdefinitionen: 21 aktive Talente/Ultimates, sechs Begleiterbefehle,
Grundangriff, Shift-Verteidigung, zwei Todesauslöser, sechs Ultimate-Aufwertungen
und eine zusätzliche kurze Seelenlanzenladung. Alle 21 passiven Talente sind in
der gemeinsamen Auswahl zusätzlich als aktuelle Texte verfügbar.

Die drei Zweige und alle Begleiterbefehle werden in **einer** interaktiven
Ansicht ausgewählt. Originale Einzelbilder: `<Fall>/frame-NNN.png`, 320×180,
15 Bilder/s; ausgewählte vollständige GPU-Aufnahmen: `full-NNN.png`, 1280×720.
Die Simulation läuft in 60-Hz-Schritten; die Vorschauabtastung ist keine
Messung der Spielgeschwindigkeit. Die platzsparende VP9-Vorschau ist 256×144
bei denselben 15 Bildern/s. Keine neu erfundene Canvas-Kampfsimulation.
Beim Pausieren zeigt die Auswahl einen klaren echten Schlüsselmoment in
320×180 mit kompakter 64-Farb-Palette; er ist ausdrücklich als Standbild
beschriftet und stellt nicht den genauen pausierten Videoframe dar.
Das Video ist für die Inline-Größengrenze stärker komprimiert; die vollständigen
PNG-Aufnahmen bleiben daneben erhalten. Alle 38 Auswahlen, Seek, Wiedergabe,
Pause und Layoutbreiten 900/360/320 wurden im echten Chrome geprüft, ohne
JavaScript-Ausnahmen; Ergebnis `output/necromancer-catalog/browser-review.json`.

Kontrollierte Aufnahmebedingungen: gültiger Level-30-Talentbuild mit
unterschiedlichen verfügbaren Rängen, vorbereitete stationäre Gegner mit
5000 Leben, geschützter Held und anfänglicher Seelenvorrat. Koloss-Aufnahmen
starten mit vorbereitetem Blutbalken. Fähigkeiten selbst verwenden die echten
bezahlten Casts und Kollisionen. Todesauslöser werden gezielt ausgelöst.
Dies ist weder ein verdienter Kampagnendurchlauf noch LAN-/Leistungsevidenz.

Der erste Gesamtlauf fand einen zu weit entfernten Schildschlag-Gegner.
Die Fixture wurde korrigiert und dieser Fall erfolgreich neu aufgenommen
(`Logs/necromancer-catalog-shield-gpu.log`). Varianten und volle Lanze wurden
anschließend erfolgreich ergänzt (`*-variants-gpu.log`, `*-lance-gpu.log`).
Der abschließende Katalog enthält 38 erfolgreich ausgeführte Fälle. Das erste
Gesamtlauflog wird wegen seiner damaligen Assertion nicht als fehlerfrei bezeichnet.

Reproduktion: Godot mit `--path . --script scripts/capture_necromancer_catalog.gd`;
danach Node `scripts/encode_necromancer_catalog.cjs` und
`scripts/build_necromancer_artifact.cjs`. Der Kodierer verwendet ausschließlich
einen eigenen unsichtbaren Chrome-Prozess und einen lokalen HTTP-Server;
die fertige Vorschau selbst benötigt keine Netzaufrufe. Die Fragmentvorlage
liegt unter `output/necromancer-catalog/nekromant-angriffe.template.html`.
Browserprüfung: `scripts/check_necromancer_artifact.cjs`.

## Gezielte Prüfungen

| Prüfung | Ergebnis | Log |
| --- | --- | --- |
| Neuer tatsächlicher Kampfablauf | 19/0 | `Logs/curse-rework-final.log` |
| Achtteiliger neuer Rig | 25/0 | `Logs/curse-spirit-rig.log` |
| Talentkampf-Katalog | 360/0 | `Logs/curse-rework-catalog.log` |
| Hölle/Frost einschließlich neuem Skelettläufer | 38/0 | `Logs/curse-rework-story-final.log` |
| Zielgebundene Rigverbindungen | 19/0 | `Logs/curse-rework-links.log` |
| Vorhandene Seele-Angriffe | 47/0 | `Logs/curse-rework-souls.log` |
| Sichtbare echte Blutaufnahme | 12/0 | `Logs/curse-rework-absorption.log` |
| Sitzungsprüfung | 20/0 | `Logs/curse-rework-protocol.log` |

Der neue Kampftest zeigte vor der Umsetzung sechs erwartete Fehlschläge
(`Logs/curse-rework-red.log`). Jetzt werden Mehrfachkosten, Wandprüfung,
Todesfluchtreffer, doppelte Todescallbacks, echte Giftquellen, Verfolgung,
Explosion, Besitzergrenze, Sekundärrekursion und Bossausschluss überprüft.
Bestehende Game-Fixtures melden weiterhin sechs ObjectDB-/zwei Ressourcen-
Aufräumdiagnosen beim Beenden. Diese werden nicht als neue Laufzeitfehler
verschwiegen; SCRIPT ERROR/Assertions sind in den finalen Prüfungen nicht vorhanden.

Zwei **reale lokale ENet-Prozesse** haben Mehrfachverbindungen und Todesflüche
auf Host und Client sowie bewegliche Zielenden, sichtbare Blutaufnahme,
Koloss und Klingensturm bestätigt:
`Logs/necro-blood/20261101-220258-a6a51651/summary.json`, Kopie `network-summary.json`.
Dies ist Loopback, keine Zwei-Rechner-LAN-, WAN- oder Leistungsaussage.
Keine neue komplette Kampagne oder subjektive Nutzerabnahme behauptet.
Kein Commit, Push oder Merge.
