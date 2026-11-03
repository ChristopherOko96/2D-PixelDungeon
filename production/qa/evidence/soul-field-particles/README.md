# Feldgeister und Seelenwächter: Rig mit Partikelcharakter

31.10.2026, Godot 4.7.2 / Compatibility. Nutzerwunsch umgesetzt auf den kleinen
Seelenfeld-/Festhalte-Geistern und dem großen beschworenen Seelenwächter.
Keine neue Bildgeneration oder Änderung der Kampfregeln.

## Ergebnis

Vier echte Cutouts je kleinem Geist, über RigLibrary/RigRenderer gekoppelt.
Fünf zeitversetzte Aufstiege vom vorhandenen PoolPaint-Feld, Kopf bleibt intakt,
Schweif bewegt sich verzögert und gibt Quellpixelpartikel ab. 42 kleine
aufsteigende Oberflächenpartikel; ebenfalls Partikelspuren beim Festhalten.
Am großen Geist zerfallen mittlerer Schweif und Spitze in bewegte 2×2-
Quellpixelstücke. Texturen einmal vorbereitet, Bewegungen kontinuierlich.
Feldoberfläche/-geometrie, Host-Treffer, Dauer, Stun, Kosten, Ressource und
Snapshotformat unverändert. Schema und Einheiten:
`docs/NEKROMANT-SEELENPARTIKEL.de.md`.

## Geprüft

| Suite | Prüfungen | Fehler |
|---|---:|---:|
| soul_particles_test | 41 | 0 |
| soul_motion_test | 55 | 0 |
| soul_field_test | 79 | 0 |
| soul_guardian_art_test | 93 | 0 |
| soul_guardian_rig_test | 58 | 0 |
| soul_detail_test | 91 | 0 |
| soul_guardian_test | 51 | 0 |
| hell_talents_test | 36 | 0 |
| Gesamt | 504 | 0 |

Neue Prüfungen: vier sichtbare Geistteile, gemeinsamer Bodenanker, harte Pixel,
erhaltene dunkle Augen, begrenzte und zeitversetzte Aufstiege, Ursprung innerhalb
des Feldes, Bewegung zwischen Renderbildern, deterministische Zeit-Samples,
unveränderter Kopf beim Schweifzerfall, Wiederverwendung der Texturen und
Recycling nur bei unsichtbaren Fragmenten.

Zwei gezielte Vorher-/Nachher-Prüfungen wurden beim Fehlschlagen beobachtet:
`config-before.log` zeigt den zuvor doppelt vorhandenen Abschnitt `soul_motion`
in vfx_talents.json; bereinigt auf einen Abschnitt mit unveränderten bisherigen
Werten plus neuen Kosmetikfeldern. `birth-before.log` zeigt vorgealterte Geister
beim Anlegen des Feldes; jetzt beginnen alle an ihrer Oberfläche und starten
zeitversetzt. Beide aktuellen Suites bestehen.

Kein SCRIPT ERROR in aktuellen Tests/Renderaufnahmen. Bestehende Sandbox-
Meldungen zu user://-Log/Shadercache und Editor-Einstellungen bleiben. Das
Game-Fixture meldet beim Prozessende wie zuvor sechs ObjectDB-Instanzen und
zwei Ressourcen in Benutzung. Kein sauberer Prozessabbau behauptet.
Der im vorigen Rig-Schritt dokumentierte alte rig_variants-Kandidatentest
wurde hier nicht erneut ausgeführt oder verändert.

## GPU-Beobachtung

1. **Echter Spielrenderer**, `scripts/capture_soul_particles.gd`: normaler
   R-Befehl, Seelenfeld ab 2,5 s, echte Gegner-KI, Treffer, Festhalten und
   Besitzerbewegung. Kontrollierter Level-30-Build mit explizitem Vorrat und
   Testgegnern; kein erspielter Lauf. 381 GPU-Bilder mit jeweils 2×1/60 s
   Simulation. Wächter ist ab Bild 365 (12,167 s) nicht mehr aktiv.
2. **Nahansicht**, `scripts/capture_soul_particle_detail.gd`: derselbe gemeinsame
   VFX-Renderer auf stiller Bodenreferenz. Links bestehendes PoolPaint mit
   Geistern, rechts Wächter samt unbedecktem Schweif bei 3×. Feld absichtlich
   dauerhaft für die Betrachtung, keine Aussage über echte Felddauer oder
   Kampffähigkeit. 192 GPU-Bilder / 6,4 s, 768×448.

Ausgewählte rohe Bilder liegen hier. Alle Einzelbilder und die mit 30 FPS
kodierten GIFs liegen in `output/soul-field-particles/`: `game-preview.gif`
und `detail-preview.gif`. GIF-Palette auf 256 Farben begrenzt; rohe PNGs exakt.
Die Encoder dekodieren nach dem Schreiben jedes Bild zur Vollständigkeitsprüfung.
Sichtprüfung der Nahbilder 64/96 sowie der Spielbilder 33/155/350: einzelne
lesbare Augen/Köpfe, angehängte obere Schweifteile und auslaufende Pixelpartikel.

Wiederholung: Godot ohne headless mit einem der beiden Aufnahmeskripte starten;
Tests mit `--headless --path . --script tests/<suite>.gd`. GIFs mit Windows
PowerShell und `assemble_game_preview.ps1` / `assemble_detail_preview.ps1`
im genannten Output-Verzeichnis erstellen. `stamp.json` enthält SHA256 der
wesentlichen aktuellen Quellen/Assets. Keine neue LAN-/WAN-/Vier-Spieler-,
Leistungs- oder Kampagnenabnahme. Nutzer beurteilt Bewegungsgefühl.
