# Scharfschütze, Fallen und Standard-Dash – 03.11.2026

Implementiert auf `codex/port-0x72-onto-main`, Regelsatz 25 / Protokoll 4. Kein Commit, Push oder Merge. Bedienung: [Schützen-Leitfaden](../../../../docs/SCHUETZE-FALLEN-REWORK.de.md). [Krieger-Konzept](../../../../docs/KRIEGER-KONZEPT.de.md) ist ausdrücklich noch nicht umgesetzt.

## Beobachtete Prüfungen

| Suite | Prüfungen / Fehler | Log |
| --- | --- | --- |
| Jägermal, R-Eingabe, Kosten, Pin, Wand, Ladungen, Build-Erhalt | 37 / 0 | `Logs/archer-rework-final.log` |
| Gesamter vorhandener Talentkampf-Katalog einschließlich Ulti-Stufen | 360 / 0 | `Logs/archer-all-talents.log` |
| Shift, Eingaben, Wiederaufladung, Wand für alle vier Klassen; Begleiter | 40 / 0 | `Logs/archer-talent_defense_test.log` |
| Gemeinsame Seelen-Aufladelogik, Abbruch, Aggro, Kontakte | 57 / 0 | `Logs/archer-necro_soul_attacks_test.log` |
| Tatsächlicher Perk-/Pfeilkampf einschließlich Fake-Host-Kompatibilität | 100 / 0 | `Logs/archer-perk_combat_test.log` |
| Vier Quellmasken, vollständige Pixelzuordnung, Cache und Gelenkbewegung | 9 / 0 | `Logs/archer-marksman_rig_test.log` |
| **Gesamt** | **603 / 0** | |

Die neue Kampffunktion wurde zunächst rot beobachtet (`Logs/archer-rework-red.log`, 25/14). Ein Zwischenfehler beim Sechs-Fallen-Test war eine über 30 Sekunden lange Fixture, in der Fallen bereits abliefen. Der finale Test nutzt drei bezahlte Ladungen zweier Fähigkeiten innerhalb der Lebensdauer. Ein alter generischer Begleitertest erwartete sofortigen Würmer-Trefferschaden; er prüft jetzt realen Spuckflug und anschließenden Pfützenschaden.

## Zwei echte Netzwerkprozesse

`tests/archer_network_smoke.ps1`: **Host und Client bestanden**, native ENet-Prozesse über Loopback. Erfolgreiche Ergebnisse: `Logs/archer-rework/20261103-135355-360eaf95/summary.json` und beide Peer-JSONs.

Der Host erhält normale R-Halten-/Loslassen-Eingaben und erzeugt bezahlte Ladezustände, Schaden sowie zwei angepinnte normale Ziele. Der Boss erhält keinen Pin. Normale Client-Eingaben legen drei Fallen; beide Prozesse beobachten Ladungen 3 → 2 → 1 → 0, Markierungen und Pins. Keine clientbestimmten Schadens-/Ladewerte. Die Gegner/Builds sind kontrollierte Netzwerk-Fixtures, keine erspielte Kampagne.

Frühere fehlgeschlagene Fixtures bleiben erhalten: `20261103-135120-53555534` verwendete fälschlich ein Spieler-Array statt Dictionary; `20261103-135238-b686b6e5` drückte die Fallen schneller als die bestehende globale 1-s-Abklingzeit. Der erfolgreiche Lauf respektiert diese Abklingzeit unverändert.

## Aktuelle GPU-Aufnahmen

Sechs native **1280×720**-PNG aus dem tatsächlichen Compatibility-Renderer, `scripts/capture_archer_rework.gd`, Log `Logs/archer-capture.log`. Alle sechs wurden visuell angesehen. Vorhandene 0x72-Pfeile, Körperteil-Solver und Fallenmasken; keine neue Akteursgrafik. Szenen sind ausdrücklich hergestellte Laborzustände mit hohem Zielpuppenleben und vollem Talentbaum.

- `01-jaegermal.png`: drei getrennte goldene Zielklammern.
- `02-himmelsspeer-laden.png`: Pfeil am Bogen und reale Ladeanzeige.
- `03-himmelsspeer-anpinnen.png`: Schuss, mitgerissene Gegner und befestigte Pfeile.
- `04-scharfschuetzen-baum.png`: aktualisierte Ulti-Beschreibung und bestehende Salve/Pfeilhagel.
- `05-sechs-grosse-fallen.png`: drei Dornen- und drei Explosionsfallen, Ladungsanzeige.
- `06-fallensteller-baum.png`: neue Radien und Ladungen im Talentbaum.

Kein `SCRIPT ERROR` in den erfolgreichen Logs. Bekannte Game-Fixture-Abschlussdiagnose: sechs ObjectDB-Instanzen / zwei Ressourcen; dies ist keine bestandene Speicherbereinigung. Der reine Rig-Quellpixeltest lädt absichtlich die lokale PNG und meldet die Godot-Warnung für Quellbild-Lesen im Export; der Laufzeit-Rig lädt importierte Texturen.

Keine neue vollständige Kampagnen-, LAN-, WAN-, FPS- oder subjektive Spielgefühl-Abnahme. Quell-/Bild-/Log-Hashes und wiederholbare Befehle: `receipt.json`, erzeugt durch `scripts/receipt_archer_rework.cjs`.
