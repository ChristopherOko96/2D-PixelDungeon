# Animationen: Rig-Abdeckung nach dem Pull

Stand: 2026-11-03. Arbeitsbranch `codex/port-0x72-onto-main`, Veröffentlichung
auf `origin/codex_v2`. Die 25 zwischenzeitlichen Remote-Commits bis `65a15a4a`
sind eingebunden. Kein Loading Screen, keine neue Figurenkunst und kein
Wechsel des aktiven Art-Katalogs.

## Gefundene und behobene Umgehungen

| Aktiver Pfad | Änderung |
|---|---|
| 82 ältere Effekt-Sheets, 544 Frames | Native Pixel werden einmal pro Frame in echte RigLibrary-Teile ausgeschnitten; RigRenderer löst ihre Gelenke zwischen den Sheet-Frames auf. |
| 21 ältere Monsterdarstellungen | Kopf, Rumpf, Arme beziehungsweise Flügel und Beine bewegen sich unabhängig. Angriffsphase, Schritte, Tod, Rückstoß und Trefferblitz bleiben angeschlossen. |
| Glutschädel | Beweglicher Kiefer im zentralen Rig-Quellbestand und passende Pose ergänzt. |
| Mimik und Leerenbomber im normalen Dungeon | Register an die vorhandenen vollständigen Krypta-Rigs gebunden, statt historische Einteil-Rigs zu verwenden. |
| Normale Helden und Story-Helden | Vorhandene Körper-Rigs bleiben aktiv; gehaltene Waffen folgen den tatsächlichen Gelenken und liefern den Stab-Ausgangspunkt. |
| Pfeile, Schädel, geworfene Waffen, Felsen, Fallen und beschworene Ersatzfiguren | Verbleibende native Sprite-Zeichenpfade in DungeonView, SheetArt, BossFx, SubKit und RelicKit über Teil-Rigs geführt. |
| Blutkrieger, Waldmeister-Würmer, Fluchkoloss und kleine Fluchmonster | Körperteil-Definitionen auch im zentralen Rig-Bauprozess verankert; ein Neubau verliert die Begleiter nicht mehr. |

`src/rig/cutout_motion.gd` nutzt die bestehende Maskenaufteilung und
Hierarchieauflösung. Es skaliert Originalpixel ohne Texturglättung. Der Test
vergleicht jede deckende Quellpixelposition und -farbe mit den ausgeschnittenen
Teilen und prüft doppelte Pixelbesitzer. Die Masken für alte Assets sind
rechteckbasierte Teilungen; sie sind keine neu gezeichneten Einzelanimationen.
Große native Begleiter behalten ihre bereits ausdrücklich angelegten Körperteile.

Stein, Metall und ruhende Fallen behalten ihre stabile Form. Flüssigkeiten,
Gas, Staub, Licht und einfache geometrische Wellen verwenden weiterhin ihre
vorhandene kontinuierliche Partikel-/Feldsimulation. Bewegliche Geister und
figürliche Effektteile laufen durch Gelenke; eine Flüssigkeitsoberfläche wird
nicht durch ein komplettes schwankendes Figurenbild ersetzt.

## Zusammenführung mit dem aktuellen Repository

Der neue gemeinsame PoolField-Kern, die ElementExposure-Schnittstelle,
Waffenhalter, der zentrale Rig-Bauprozess und die feste Story-Schrittzeit
bleiben erhalten. Die älteren privaten PoolPaint-Felder werden von den
angepassten Tests und Aufnahmehelfern nicht mehr vorausgesetzt.

Beim Zusammenführen wurden konkrete Regressionen korrigiert:

- Der normale Magier-Autohit bleibt neutral; Feuerball bleibt eine Fähigkeit.
- Eigene Giftfelder verletzen den Besitzer nicht, überlappende feindliche
  Felder bleiben gefährlich.
- Absaugen einer Blutlache entfernt keine andere überlappende Lache.
- Hohle Ringe und schmale Seelenspuren behalten ihre Form im PoolField-Modell.
  Diese eigens definierten Formen werden nach 0,1 s sichtbar; normale große
  Felder behalten die vorhandene deterministische Fertigstellungszeit.
- Beim Verlassen der DungeonView werden laufende Feldarbeiten abgeschlossen,
  bevor ihre Geometrie-Callbacks verschwinden.

Netzwerkprotokoll bleibt 4, Regelstand ist 26. Quell-Rigs unter
`tools/rig_kit/hand_rigs/` und Generatoren ändern; anschließend
`node tools/rig_kit/build_rigs.js` ausführen. `--check` muss ohne Drift enden.
Die Laufzeit-Spriteprofile stehen getrennt in `assets/data/cutout_motion.json`.

## Nachweise und Grenzen

Die aktuelle Abdeckungsprüfung besteht mit **1.250 Prüfungen** für die
Effektframes, alten Monster, aktiven Monsterregister, Begleiter, Gelenkbewegung
und Trefferblitze. Der zentrale Bauvergleich besteht mit **2.547 Prüfungen,
0 Fehlern und 0 Drift**. Weitere gezielte Kampf-, Feld-, Waffen-, Story- und
Netzwerkprüfungen sind einzeln in der Prüfquittung aufgeführt.

`production/qa/evidence/rig-audit/` enthält 26 native 1280×720-Aufnahmen:
zehn Darstellungsansichten, zehn Nekromanten-/Waldmeister-Zustände und sechs
Schützen-/Fallen-Zustände. Die beiden Ansichtsphasen zeigen tatsächliche
Renderer-Ausgaben; die Spielaufnahmen sind ausdrücklich vorbereitete Zustände.
Sie sind kein erspielter Kampagnendurchlauf und keine Geschmacksabnahme.

Die lokalen ENet-Tests betreiben echte getrennte Prozesse auf diesem PC.
Sie belegen keine Zwei-Rechner-LAN-, WAN- oder Leistungsabnahme. Kalte
Szenenaufbauten führten bei früheren Netzwerkläufen zu Zeitüberschreitungen;
der Schützenprüfer begrenzt Start und anschließende Kampfbeobachtung getrennt.
Die Assertions für Markierung, bezahltes Laden, Anpinnen, Bossschutz und alle
drei Fallenaufladungen bleiben bestehen.

Einige Testfixtures melden beim Beenden weiterhin ObjectDB-/Resource-Reste,
Mehrwelt-Fixtures auch DummyTexture-Reste. Diese Diagnose ist offen; ein
fehlerfreier Speicherabbau wird nicht behauptet. Erfolgreiche Läufe wurden
separat auf `SCRIPT ERROR` geprüft. Nachweise und Quellhashes:
`production/qa/evidence/rig-audit/receipt.json`.
