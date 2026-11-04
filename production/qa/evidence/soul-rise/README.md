# Seele: Sammeln → Aufsteigen → Flug zum Stab

04.11.2026, lokal auf `codex_v2`, Basis `ab181e4a` mit den vorherigen
Seelen-VFX-Änderungen. Nicht committed oder gepusht.

## Sichtbarer Ablauf

`seele-sammeln-aufsteigen-fliegen.gif` zeigt eine tatsächliche Krypta-Aufnahme
mit 2,4-facher Zeitlupe, Ausschnitt 735×335, 126 Bilder und Pausen am Rand.
Keine neu generierten Bilder oder nachträglich eingezeichneten Effekte.
`ablauf.png` stellt sechs Zeitpunkte gegenüber; die Einzelbilder sind originale
vollständige Renderer-Aufnahmen.

Fixture: `scripts/capture_soul_from_corpse.gd`, echte Krypta-Szene und normaler
Nekromantenangriff auf ein echtes Skelett. Kontrolliert sind Gegner-Leben,
Bewegung und Kamera. Tod im Capture-Bild 52, genau ein `souls`-Ereignis und
ein Leichnam; Ressourcenwert am Ende 11,37. Das ist keine Balance-Abnahme.

- 0,05/0,22 s: Pixel sammeln sich im Leichnambereich; der normale Treffer-
  und Todeseffekt ist ebenfalls sichtbar.
- 0,47 s: Seelenkopf über dem Körper, noch vor dem horizontalen Zug.
- 0,73 s: Kopf mit Augen und gekoppeltem Schweif auf dem Weg zum Stab.
- 1,13 s: Aufnahme am Stab; 1,47 s: Darstellung beendet.

Die Daten steuern 0,48 s Sammelphase, 0,42 s Aufstieg um 18 Partikelpixel
und 0,16 s weichen Beginn des Zugs. 1,4 s lokale Darstellung überlebt das
unveränderte 0,7-s-Hostereignis. Ressourcen werden weiterhin sofort beim Kill
gebucht; Wind, Wände und Druck wirken im bestehenden Partikellöser.

## Geprüft

Vor der Umsetzung fehlten beide benötigten Einstiegspunkte (2/2 erwartete
Fehler im neuen Regressionstest). Danach:

| Prüfung | Erfolgreich | Fehlgeschlagen |
|---|---:|---:|
| `soul_release_test.gd` | 16 | 0 |
| `soul_matter_physics_test.gd` | 24 | 0 |
| `soul_face_test.gd` | 7 | 0 |
| `soul_absorption_test.gd` | 17 | 0 |
| Gesamt | 64 | 0 |

Der neue Test prüft die verzögerte Horizontalbewegung, Aufstieg, Sammeln,
bewegtes Stabziel, äußeren Druck, Ablauf, das Überleben des Hostereignisses,
Snapshot-Duplikate und Zurücksetzen beim neuen Boden. Die Aufnahme wurde
an den sechs gezeigten Zeitpunkten visuell geprüft. Logs liegen daneben.

Keine `SCRIPT ERROR`/Parserfehler in diesen Läufen. Bekannte Einschränkungen:
die Szenen-Fixture meldet beim Beenden 6 ObjectDB-Instanzen/2 Ressourcen,
die GPU-Capture meldet beim Beenden 905 Texture-RIDs, 1385 ObjectDB-Instanzen
und 29 Ressourcen sowie Shadercache-Schreibfehler. Diese Shutdown-/Cache-
Meldungen sind damit nicht behoben. Keine neue Netzwerk-, Vier-Spieler-
Performance- oder vollständige Kampagnenabnahme.
