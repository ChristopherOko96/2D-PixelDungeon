# Fallenalchemist — 05.11.2026

Umsetzung des gewählten Konzepts: Gift/Feuer/Frost mit Wasser als Medium.
Giftköder, Wasserkapsel, Zündfalle, Frostfalle, Splitterfalle, Kettenzünder und
Alchemistischer Jagdgrund. Details, Werte, Schema, Bedienung und Grenzen:
`docs/FALLENALCHEMIST.de.md`.

## Positive Prüfungen

| Suite | Prüfungen | Fehler |
|---|---:|---:|
| alchemist_traps_test | 57 | 0 |
| alchemist_story_test | 51 | 0 |
| alchemist_art_test | 41 | 0 |
| talent_combat_test (aktueller Gesamtkatalog) | 358 | 0 |
| archer_rework_test | 37 | 0 |
| session_protocol_test | 20 | 0 |

564 fokussierte Prüfungen bestanden. Hostregeln prüfen Scharfwerden, eigene
Pfeile, fremde Pfeile, Wände, Wiederholungen, Sechsergrenze, Locken ohne Bosse,
echte Medien, vorhandene Wasser-/Gift-/Feuer-/Frostreaktionen, Splitterschaden,
verbrauchte Pfützen ohne Restimpulse, realen Host-Projektilhook und Ultimate-Takt.
Die drei echten Story-Adapter prüfen auch ihre echten Grundpfeile durch den
normalen Schussloop. Rig und Icons prüfen echte getrennte Bewegung und Cache.

Zwei echte lokale ENet-Prozesse bestanden zusätzlich den vorhandenen Archer-
Smoke-Test inklusive neuer Prüfung auf client-eigene, scharfe Wasserkapseln.
Snapshotfelder `recipe` und `armed` erreichen beide Rollen; drei Eingabedrücke
verbrauchen echte Ladungen. Die bestehenden Scharfschützen-Netzprüfungen
(Markieren, Aufladen, Anpinnen, Bossausnahme, Wandnormale) bestanden mit.
Erfolgreicher Lauf: `Logs/archer-rework/20261105-160945-1e49c4ae/`;
Summary/Peer-Belege hier unter `network/` kopiert. Loopback, kein LAN/WAN/FPS.

## Ehrliche Fehl-/Vergleichsläufe

- Vor Implementierung schlugen drei von vier neuen Basisprüfungen erwartbar
  fehl: Giftpfeil statt Giftköder, fehlender Kettenzünder, keine Kapsel.
- Erster Modulparse: fehlender expliziter Float-Typ, danach behoben.
- Erster ausführlicher Regellauf: Fixture griff auf noch nicht angelegte
  `ability_charges` zu; auf optionales Dictionary korrigiert.
- Die erste Story-Sicherheitsprüfung fragte nach Giftimmunität, nachdem das
  Gift bereits verbraucht war und der Held außerhalb der Pfütze stand. Die
  korrigierte Fixture prüft tatsächliche unveränderte Helden-HP der Sequenz.
- Die Rigprüfung zeigte fünf echte Fehler: Translationen standen fälschlich
  unter `pos`, der Solver liest `dx`/`dy`. Auf dessen tatsächliche Posefelder
  korrigiert, dieselbe Prüfung anschließend 41/0.
- Drei Sandbox-Netzläufe erreichten keine gemeinsame Sitzung. Die ergänzte
  Diagnose zeigte beide Prozesse in der Verbindungsphase. Derselbe Test
  außerhalb der Netzwerksandbox bestand mit beiden Rollen; kein Produktions-
  Netzwerkcode wurde dafür geändert. Startup und Combat haben getrennte
  begrenzte Fixture-Fristen. Die ersten Logs bleiben unter Logs/archer-rework/.
- `talent_progress_test`: 427 Checks, 2 Fehler, beide Nekromant-alt: Array
  `soul_14.commands` passe nicht zu den Rängen und Nekromant müsse Mana nutzen.
  Isolierte Kontrolle mit unveränderten HEAD-Talentdaten: 428 Checks, dieselben
  beiden Fehler. Nicht im Fallensteller-Auftrag repariert oder als bestanden
  gerechnet. Produktionsdaten wurden für die Kontrolle nicht zurückgesetzt.

Die positiven finalen Läufe enthalten keine SCRIPT ERROR-/Parse-Fehler.
Bekannte SceneTree-Abbauwarnungen bleiben: Labor sechs ObjectDB-Instanzen/zwei
Ressourcen; dreifache Story-Fixture 2244 ObjectDB-Instanzen/sechs Ressourcen
und 887 Renderer-Texturen. Die Stderr-Dateien werden gesondert aufbewahrt.
Keine Behauptung, diese bestehenden Ressourcenprobleme repariert zu haben.

## Bilder

Sieben rohe 1280×720-GPU-Aufnahmen aus dem aktuellen Laborrenderer:

1. `01-five-capsules.png`: fünf neue Elementkapseln.
2. `02-water-poison.png`: öffnende Wasser-/Giftkapseln, die echten Pfützen beginnen sich aufzubauen.
3. `03-apparatus.png`: Ultimate entfaltet sich.
4. `04-deployed.png`: tatsächliche Wasser-/Giftmedien.
5. `05-frozen.png`: Frostphase.
6. `06-ignition.png`: abschließende Zündung.
7. `07-talent-tree.png`: neue Fähigkeiten, Passiven und Icons im Talentbaum.

Alle sind vorbereitete Trainingszustände mit bezahlten Host-Casts; zusätzliche
Ränge/Ressourcen werden ausschließlich von der Aufnahmefixture eingerichtet.
Simulation und Präsentationsbesitzer schreiten gemeinsam in 1/60 s voran.
Keine erspielte Kampagne, subjektive Balance-/Spielgefühl- oder Lastabnahme.
Keine neuen KI-generierten Bilder; die Kapselgrafik ist ein explizites natives
Pixelraster mit fünf gecachten Gelenkmasken. Kein Commit/Push/Merge.

## Wiederholen

Godot 4.7.2 aus Projektwurzel, APPDATA auf eigenen Scratchpfad unter Logs setzen.
Tests: `--headless --path . --script res://tests/<Name>.gd`.
Aufnahmen: `--path . --script res://scripts/capture_alchemist.gd` (GPU).
Netz: `tests/archer_network_smoke.ps1 -GodotPath <Godot-Konsole>`; benötigt lokale
Loopback-Kommunikation zwischen beiden Prozessen. Receipt hält finale Hashes.
