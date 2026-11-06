# Himmelsspeer: Rig und Partikel überarbeitet

## Visuelle Revision: Himmelslanze (05.11.2026)

Nach Nutzerkritik am Pfeil ersetzt eine eigene 11×41-Pixel-Himmelslanze die
7×21-Quelle ausschließlich beim Ultimate. Breite Kristallspitze, weißgoldener
Kern, goldene Fassungen und gespreizte Energieschwingen ersetzen Holz und
Pfeilfedern. Die neun bestehenden Gelenke besitzen neue Masken und Drehpunkte.
Die native Breite und der Mittelpunkt kommen aus dem Rig; die sichtbare Breite
bleibt an denselben Trefferkorridor gebunden. Ladung verwendet den kosmetischen
Faktor `charge_art_scale` (0,62), damit die längere Lanze am Bogen lesbar bleibt.
Zehn Ladelichter und stärker auslaufende Nachlaufketten begleiten die neue Form.
Partikelraten und Ausstoß bleiben begrenzt. Die ursprüngliche Pfeilgrafik und der
Vier-Teile-Helfer sind erhalten. Keine Änderung an Kampfwerten oder Netzwerk.

Quelle: `scripts/generate_celestial_lance.cjs` schreibt das hard-alpha PNG aus
einem expliziten Pixelraster mit fünf Farben. Keine neue Bildgenerierung.
Aktuelle Laboraufnahmen: `production/qa/evidence/himmelsspeer-lance/`.
Die folgenden Abschnitte beschreiben den vorherigen Stand des Rig-Aufbaus.

05.11.2026, `codex/port-0x72-onto-main`. Nutzerauftrag: die ultimative
Scharfschützen-Fähigkeit besser riggen und mit Partikeln aufwerten.

Der aktive Himmelsspeer verwendet jetzt neun echte Quellmasken: zwei
Spitzenhälften, einen Spitzenkern, drei Schaftstücke, zwei Federn und eine
Nocke. Die Spitzenhälften öffnen sich beim Laden, die Schaftgelenke bewegen
sich nur leicht, Federn und Nocke reagieren zeitlich versetzt. Die vorhandene
freigegebene 7×21-Grafik bleibt die Quelle; kein neues Figuren-/Artpaket.

## Ablauf

- **Laden:** physische goldene Partikel ziehen sich zum Bogen. Die sichtbare
  Speergrafik sitzt am tatsächlich gezeichneten Nockpunkt, nachdem die Waffe
  der Körperpose gefolgt ist. Der einfache aufgelegte Pfeil wird währenddessen
  ausgeblendet; es liegen keine zwei Pfeile übereinander.
- **Abschuss:** eigener kurzer Körperrückstoß, geriggter Kernimpuls und ein
  einmaliger Funkenstoß. Ladung und Ressourcen kommen weiterhin vom Host.
- **Flug:** zwei geriggte Nachlaufketten mit je fünf Gelenken beginnen hinter
  dem Speerende. Die früheren verkleinerten Komplettpfeil-Kopien entfallen.
  Eine begrenzte physische Partikelspur bleibt zurück.
- **Wandkontakt:** ein zusätzlicher neungeteilter Impuls und die vorhandenen
  physischen Holzsplitter/Funken. Alle neun Speerteile lösen sich voneinander,
  drehen sich und fallen. Die Gelenkpose wird beim Bruch eingefroren; danach
  folgen die einzelnen Stücke ihrer ballistischen Bewegung.

Der hostbestimmte Wandkontakt und seine Normale begrenzen alle rotierenden
Teile. Die Größenabbildung folgt unverändert dem tatsächlichen Trefferkorridor.
Gegner behalten den gemeinsamen Treffer-Rig aus `TREFFER-RIG.de.md`.

**Unverändert:** Schaden, kritische Treffer, Kosten, Nachladezeit, Ladungszeit,
Reichweite, Anpinnen, Boss-Ausnahmen, Treffer-/Wandprüfung und Protokoll.
Keine neuen RPC-Felder und keine stärkeren Kameraruckler oder zusätzlichen
Spielpausen. Der alte Vier-Teile-Helfer bleibt für bestehende Darstellungen
vorhanden; nur die ultimative Fähigkeit nutzt den neuen Speer-Rig.

## Zuständigkeiten und Einstellungen

`marksman_rig.json` ergänzt `marksman_spear` im bestehenden inklusiven
Masken-/Eltern-/Pivot-Schema. Jedes sichtbare Quellpixel gehört genau einem
Teil. Der echte `RigRenderer.solve_pose` löst auch beide Nachlaufketten.
Texturen und Quellmasken werden einmal vorbereitet, nicht während jedes Bilds.

`marksman_ultimate_fx.json` enthält ausschließlich Präsentation:

- `fin_open`, `feather_open`, `shaft_bend`: Gelenkwinkel in Radiant;
  `flutter_hz`: Schwingungen pro Sekunde.
- `charge_orbits`: sichtbare einwärts laufende Lichtstücke; `charge_radius`:
  Radius in nativen Kunstpixeln; `charge_rate`: Partikel pro Sekunde;
  `charge_speed`: Kunstpixel pro Sekunde.
- `wake_links`: Gelenke je Kette; `wake_spacing`, `wake_width`, `wake_wave`:
  Abstand, Seitenversatz und Wellenauslenkung in Kunstpixeln.
- `trail_rate`, `trail_cap`: Partikel pro Sekunde und Obergrenze pro Speer;
  `trail_speed`: Kunstpixel pro Sekunde.
- `charge_particle_life_s`, `trail_life_s`, `release_life_s`: Sekunden.
- `release_sparks`: einmalige Funkenzahl; `*_cap_per_frame`: maximale neue
  Teilchen je Update; `particle_soft_cap`: Schwelle für zusätzliche Emission.
- `max_extrapolate_s`: maximaler visueller Vorlauf gegenüber dem zuletzt
  bestätigten Ereignisalter, derzeit 50 ms.

Die bisherige `vfx_talents.json.ranger.arrow` steuert weiterhin Breitenabbildung,
Bruchgeschwindigkeit, Schwerkraft, Drehung und Wandpartikel. Die historischen
Komplettpfeil-Spurparameter werden vom neuen Nachlauf nicht verwendet.

`marksman_matter.gd` besitzt je Darstellungsinstanz Lade-/Flugzähler und
Emissionsreste. Wiederholte Zeichnungen derselben Zeit emittieren nichts.
Kumulierte Ausstoßraten sind bei 60 und 144 Bildern/s vergleichbar, nicht
pro Draw festgelegt. Abbruch, Raumwechsel und zurückgesetzte Zeit entfernen
alte Zähler. Gesättigte Partikelsysteme erhalten keine weiteren Zusatzpartikel.

Der zusätzliche Vorlauf ist begrenzt, damit ein stockender manueller Simulations-
takt oder ein altes Netzwerkpaket den Speer nicht beliebig vorauslaufen lässt.
Die Schadensentscheidung wird dabei nie neu berechnet.

## Prüfen

`Waldmeister-Testraum.cmd` → **FERN**, R halten und loslassen. Die Story-Welten
verwenden dieselben Effekte über ihre vorhandenen Adapter.

Aktuelle Ergebnisse, zwölf echte GPU-Aufnahmen, wiederholbare Befehle und
Einschränkungen stehen in `production/qa/evidence/himmelsspeer-rig/README.md`.
Aufnahmen sind vorbereitete Trainingszustände und keine erspielten Kampagnen.
Keine neue LAN-/Leistungsabnahme oder subjektive Spielgefühl-Freigabe.
