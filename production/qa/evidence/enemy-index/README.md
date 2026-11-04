# Gegner-Synchronisierung und räumliche Suche

04.11.2026, Basis `7c39036e`, lokale Änderungen auf `codex_v2`. Nicht committed/gepusht.

## Umsetzung

Einzelne Zielabfragen und Basistreffer synchronisieren nur den betroffenen Gegner. Der gemeinsame StoryEnemyIndex liefert räumliche Kandidaten für Körperabstand, Gravitation und Projektile. Die ursprüngliche Gegnerreihenfolge, genaue Kollisionen, Wände und Trefferregeln bleiben maßgeblich. Bosse, große Körper und animierte Masken besitzen konservative Rückwege. Animierte Masken werden ausschließlich für Geschossabfragen zusätzlich berücksichtigt; die Körperabstände bleiben räumlich. Siehe `docs/GEGNER-SUCHE.de.md`.

## Gezielte Prüfungen

Vor der Umsetzung: neuer Test mit 6 Prüfungen und 2 erwarteten Fehlern (volle Synchronisierung bei 32 Zielabfragen, fehlender Index). Bei der Maskenprüfung: 208 Prüfungen, 1 erwarteter Fehler für ausladende animierte Körperteile; danach konservative Maskenkandidaten ergänzt. Beide roten Läufe stehen daneben.

| Suite | Bestanden | Fehler |
|---|---:|---:|
| story_enemy_index_test | 208 | 0 |
| story_enemy_index_integration_test | 27 | 0 |
| necro_story_attacks_test | 30 | 0 |
| hell_talents_test | 36 | 0 |
| Gesamt | 301 | 0 |

Die neue Integration lädt Krypta, Frostgruft und Hölle: Spawns, Teleports, Talentverschiebungen, erste Basistreffer bei überlappenden Gegnern und geänderter Listenreihenfolge, Mehrkörperbewegung gegen vollständige Such-Referenz sowie Freigabe beim Run-Ende. Die Unit-Suite prüft unter anderem 160 Körper gegen dieselbe vollständige Abstoßung, 30 Flugsegmente, negative Koordinaten, große Radien, Löschung und stabile IDs.

## Gepaarte CPU-Messung

`scripts/bench_story_enemies.gd` erzeugt zwei echte Krypta-Laufzeiten: Baseline aus Git und neue Fassung. Beide verwenden Seed 4242 und denselben Raum mit 355 freien Zellen. Je Fall 8 Aufwärmschritte, dann 60 gemessene Schritte zu 1/60 s. Die Ausführungsreihenfolge wechselt bei jedem Messpaar; der Zufallszustand wird identisch gesetzt. Skelettgegner mit erhöhten HP, unterdrückten Angriffen und unverwundbarem Helden sind ausschließlich Fixture-Einstellungen. Keine zusätzlichen Spielerzauber, keine automatischen Gameplay-Zeitkürzungen.

Alle acht Fälle ergeben dieselben abschließenden Gegnerpositionen. Getrennte frühere Prozessläufe schwankten stark; die folgenden Zahlen stammen aus dem abschließenden gepaarten Lauf. Die vorherige gepaarte Messung bleibt in `paired-initial.json` zum Vergleich erhalten.

| Gegner | Anordnung | CPU-Schritt vorher | nachher | weniger CPU-Zeit | p95 vorher / nachher |
|---:|---|---:|---:|---:|---:|
| 8 | verteilt | 13.26 ms | 13.75 ms | -3.7 % | 16.99 / 16.79 ms |
| 32 | verteilt | 30.55 ms | 30.45 ms | 0.3 % | 36.00 / 35.02 ms |
| 64 | verteilt | 57.19 ms | 50.08 ms | 12.4 % | 65.11 / 57.21 ms |
| 128 | verteilt | 144.80 ms | 95.29 ms | 34.2 % | 177.21 / 107.99 ms |
| 8 | dicht | 13.15 ms | 13.00 ms | 1.1 % | 16.04 / 16.58 ms |
| 32 | dicht | 29.15 ms | 29.58 ms | -1.5 % | 36.27 / 35.61 ms |
| 64 | dicht | 61.14 ms | 56.81 ms | 7.1 % | 70.07 / 66.83 ms |
| 128 | dicht | 152.32 ms | 115.57 ms | 24.1 % | 196.59 / 142.22 ms |

Bei 128 Gegnern sinkt die CPU-Schrittzeit um rund 24–34 %, bei 64 um rund 7–12 %. Bei 8 oder 32 Gegnern zeigt dieser Lauf keinen verlässlichen Gesamtgewinn; der Index hat feste Kosten und einzelne Mittelwerte liegen leicht über der Baseline. Die isolierte Zielwahl aller 128 Gegner sinkt von rund 21 ms auf rund 1 ms.

Dies sind Headless-CPU-Zeiten, keine Render-FPS. 60 Spielschritte/s erfordern unter 16,67 ms pro Schritt; die große Horde überschreitet dieses Budget weiterhin deutlich. Feedback, Materialsimulation, weitere globale Suchwege und Darstellung benötigen eigene Folgeschritte. Keine Release-, GPU-, Kampagnen- oder Vier-Spieler-Abnahme.

## Reproduktion

Im Checkout mit Godot 4.7.2:

```powershell
& ./production/qa/evidence/enemy-index/recreate-baseline.ps1
godot --headless --path . --script res://scripts/bench_story_enemies.gd
```

Der erste Befehl legt nur die drei historischen Scripts unter `output/enemy-index-baseline` an und biegt deren interne Adapterpfade auf diese Kopien um. Der aktuelle Checkout bleibt erhalten. Der Benchmark schreibt `output/enemy-index-bench/paired.json` und entfernt seine Scratch-Profile. Den Benchmark allein laufen lassen, keine parallelen Testprozesse.

## Einschränkungen

Die gezielten finalen Läufe und der gepaarte Benchmark enthalten keine Script-/Parserfehler. Die Umgebung verhindert das normale Engine-Log unter `user://`. Szenen-Fixtures melden beim Beenden weiterhin Texture-RID-, ObjectDB- und Ressourcenwarnungen (unter anderem 887 Texture-RIDs und 6 Ressourcen); diese sind damit nicht behoben. Der breite bestehende `frost_runtime_test` wurde ohne Abschlussmarker abgebrochen und zählt ausdrücklich nicht als bestanden. Die gezielten Drei-Welten-Prüfungen sind separat aufgeführt. Die vorhandenen lokalen Audio-/Raumänderungen und Importdateien gehören nicht zu dieser Änderung.
