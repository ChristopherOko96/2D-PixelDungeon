# Aktuelles main übernehmen, Seelenring vergrößern

01.11.2026. Angefordert: zuerst aktuellen `main` pullen, danach den bisherigen
5-m-Seelenring größer machen. Neuer Durchmesser **7 m**, 40 % größer; Außenradius
112 px, Innenradius 88 px, Breite unverändert 24 px / 0,75 m. Vier Sekunden,
22 Seelen, 11 s Abklingzeit, Schaden und gemeinsame Betäubungssperre bleiben.

## Git-Integration und Sicherung

Remote: `origin`, ChristopherOko96/2D-PixelDungeon. `git fetch origin main`,
danach tatsächlicher `git pull --ff-only origin main`. Fünf Commits von
`51066c11` bis **`b178a185647ed9bd2db0f0ce57c041e4731febe8`** übernommen.
Auch der lokale main-Zeiger wurde per Fast-forward auf diesen Stand gebracht;
gearbeitet wird weiter auf `codex/port-0x72-onto-main`. Kein Push, kein neuer
Projektcommit und keine Entwicklung direkt auf main.

32 tatsächliche lokale Dateidifferenzen vor dem Pull gesichert: Git-Stash
**`82f7f990`**, zusätzlich Binärpatch und 1.519 physische Dateikopien (überwiegend
Importdateien mit Zeilenendunterschieden) unter `.scratch/main-sync-20261101/`.
Die 32 Kopien gegen den Stash normalisiert geprüft: 0 Abweichungen.
2.231 neue Dateien vor/nach dem Pull über SHA256 geprüft: keine verloren oder
verändert; anschließend bewusst bearbeitete Ringtests sind davon getrennt.
Stash/Sicherungen bleiben erhalten. Kein ungelöster Git-Konflikt, Index leer.

Neun Konfliktdateien zusammengeführt: neue Main-Elementphysik, Gefüge,
Begleiter-Rig-/Körperteilregeln, Story-Skalierung/Follow-Verhalten, Rag-Doll-
Transformationen, Sound, HUD und Kamera beibehalten. Lokale Seelenökonomie,
Kampfbindung, Felder, Ring, Wächter und freigegebene Cutout-Animationen erhalten.
Magier-Standardangriff wird weiter als neutrale Magie behandelt; Feuerball
bleibt die aktive Baumfähigkeit. Die bestehende türkisfarbene Seelenpalette
bleibt erhalten. Eine leere Gefüge-Anzeige wird am Nekromanten nicht gezeichnet.

## Geprüft auf dem integrierten Stand

| Suite | Checks | Fehler |
|---|---:|---:|
| soul_ring_test | 19 | 0 |
| soul_ring_shape_test | 18 | 0 |
| soul_guardian_rig_test | 58 | 0 |
| soul_guardian_test | 51 | 0 |
| necro_souls_aggro_test | 60 | 0 |
| hell_talents_test | 36 | 0 |
| talent_combat_test | 362 | 0 |
| mage_fireball_test | 42 | 0 |
| mage_neutral_feedback_test | 2 | 0 |
| attack_fx_test | 23 | 0 |
| story_camera_test | 13 | 0 |
| audio_sfx_test | 1726 | 0 |
| session_protocol_test | 20 | 0 |
| snapshot_interpolation_test | 57 | 0 |
| Gesamt | 2487 | 0 |

Alte Tests beim Import der aktuellen Main-Mechanik angepasst: Der Gletscher
friert jetzt ausdrücklich erst beim Landen; vier neue Gefüge-Passivtypen werden
an tatsächlichem Manaertrag, Speicherkapazität, Landeschaden und ausgehendem
Schaden geprüft. Neue Pixel-/Partikeleinschläge verwenden `blast` statt alter
Nova-/Burst-Sheets; Neutralitätsprüfungen prüfen ihre tatsächliche Farbe und
Materie und schließen Flammen/Glut aus. Die Fehler vorher waren beobachtet;
keine unbekannten Talenttypen pauschal übersprungen. Neue Main-Kampfregeln
wurden dafür nicht auf das alte Verhalten zurückgesetzt.

## Tatsächliche GPU-Aufnahme

`scripts/capture_soul_ring_wide.gd`: echte aktuelle Game-/HUD-/VFX-Darstellung,
kontrollierter Build und drei Gegner, normaler Taste-2-Befehl mit tatsächlichem
50-Seelen-Start. 181 Bilder / sechs Sekunden Simulation, 30 FPS Vorschau.
Spieler geht später aus der ursprünglichen Mitte; der Ring bleibt liegen.
Rohbilder hier, alle Frames und `game-preview.gif` in `output/soul-ring-wide/`.
GIF nach Kodierung vollständig dekodiert; PNGs bleiben farbgetreu.
Der vorherige 5-m-Nachweis unter `soul-ring/` ist historisch und unverändert.
Kein erspielter vollständiger Lauf oder subjektiver Bewegungsentscheid.

Zwei echte lokale ENet-Prozesse prüfen normale Inputs beider Besitzer,
112/88-px-Grenzen, Novaschaden und Ablauf. **Regelversion 12 / Protokoll 4**
trennt den integrierten erweiterten Stand von älteren Builds. Aktuelle
Zusammenfassung in `network-summary.json`. Loopback, kein Zwei-PC-LAN/WAN-
oder Leistungstest. Import ist separat vom Spiel-/Netzwerknachweis.

In der aktuellen GPU-Ausgabe keine SCRIPT ERROR oder Triangulationsfehler.
Bekannte Sandbox-Log-/Shadercache-/Editor-Einstellungsdiagnostik und die
bestehenden sechs ObjectDB-/zwei Ressourcenmeldungen am Game-Fixture-Ende
bleiben. Kein fehlerfreier Prozessabbau oder neue Vier-Spieler-Leistungsabnahme.
Quellenstand: `stamp.json`. Bedienung/aktuelle Zahlen:
`docs/NEKROMANT-SEELENRING.de.md`; Testraum Nekromant/Seele, **2**.
