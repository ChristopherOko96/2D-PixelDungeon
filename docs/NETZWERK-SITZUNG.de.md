# Sitzungsabgleich und Clientdarstellung

Stand:26.10.2026. Autoritativer Godot4.7.2-Host, ENet, maximal vier Teilnehmer.
Spielregeln, Treffer, Perks, Bewegung und Raumwechsel werden weiterhin allein
vom Host bestätigt. Die folgenden Änderungen betreffen Aufnahme und Darstellung.

## Aufnahme vor Spielrechten

Eine rohe Transportverbindung ist zunächst nur pending. Ein zuverlässiges,
höchstens512Byte großes JSON-Hello vergleicht:

- `protocol`: Protokollversion4 (zusätzlich Figurenkennung, Bewegungsvektoren,
  Trefferseite/-stärke, Block-/Interaktionszähler und Laufseriennummer).
- `rules`: Regelversion4 (Tod bleibt für normale Gegner0,8s, beim Boss1,6s sichtbar;
  danach erfolgt wie bisher die Raumabschlussprüfung).
- `engine`: genau4.7.2.
- `generator`: aktuelle Generatorversion4.
- `content`: SHA256 über kanonisch normalisierte Balance- und aktive Dungeon-Daten.
  Andere Schlüsselreihenfolge oder äquivalente Integer/Floatwerte ändern ihn nicht.

Erst nach erfolgreichem Abgleich wird ein Spieler angelegt und erhält normale
Snapshots sowie Eingabe-/Aktionsrechte. Unbekannte, fehlerhafte, zu große,
abweichende oder zu späte Meldungen werden abgewiesen. Mismatch und Timeout
zeigen eine deutsche Meldung. Das ist ein Kompatibilitätsabgleich, keine
Benutzeridentitäts-Authentifizierung oder kryptografische Prüfung beliebigen Codes.

## Snapshot und Darstellung

Der Host überträgt weiterhin20 Zustände pro Sekunde. Monotone `server_time`,
Sequenznummern, stabile Spieler-/Gegner-/Projektilkennungen und Kollisionsradien
erlauben eine getrennte Darstellung. Raumgeometrie wird einmal pro Peer und
Raumrevision zuverlässig gesendet und danach lokal wiederverwendet.

Clients puffern ausschließlich kleine Positionszusammenfassungen. HP, Perks,
Entitätenbestand, Ereigniszähler und Geometrie bleiben der aktuelle autoritative
Zustand. Kamera und Welt verwenden denselben einmal je Frame berechneten Zustand.
Der Host behält seine direkte lokale Physiktakt-Darstellung.

`run_serial` steigt auch bei einem Neustart mit gleichem Seed. Spieler übertragen
ihre stabile `skin`, tatsächliche Bewegung `mx/my`, aktuelle `shot_interval`,
`blocks`, `interacts`, `last_hit_damage` und `hit_dx/hit_dy`. Gegner übertragen
zusätzlich `facing_x/facing_y`, `mx/my` und `last_hit_damage`. Der lokale
Animationscontroller liest diese Werte und die bisherigen Angriffs-/Lebensdaten.
Animationen erzeugen weder Treffer noch Bewegung oder neue Fähigkeiten.
Atlanten, Framecache und Rigparameter werden nicht über das Netzwerk gesendet.

`perk_offers` ordnet jedem Spieler sein bestätigtes Angebot zu. Die lokale
Oberfläche zeigt daraus `perk_options` an; ein Auswahlindex wird auf dem Host
ausschließlich gegen das eigene Angebot geprüft. Builds, Schutzladungen,
Statussymbole und begrenzte Perk-Ereignisse sind Hostdaten. Clients berechnen
keinen Schaden oder Heilung aus den Symbolen. [Perkschema](PERKS.de.md).

Raum-/Ebenen-/Laufwechsel, Raumrevision, Fade, Tod/Wiederbelebung, Teleports und
lange Paketlücken schneiden die passende Historie ab. Es gibt keine endlose
Extrapolation. Ein lokaler Motionvalidator prüft neue Positionspaare einmal gegen
die vorhandene Hostgeometrie; an einer geschnittenen Wandecke wird die Darstellung
für dieses Paar gesetzt statt durch die Mauer interpoliert. Keine Simulation
wird dadurch verschoben. Hitstop und schwarze Raumfreigabe bleiben erhalten.

## Konfiguration in `src/data/balance.json`, Block `network`

| Schlüssel | Wert | Zweck |
| --- | --- | --- |
| `input_hz` / `snapshot_hz` |20 /20 | Bisherige Eingabe-/Netzrate |
| `admission_timeout` |8s | Ende einer unbeantworteten Verbindungs-/Versionsprüfung |
| `admission_reject_grace` |0,3s | Zeit zur Zustellung der Ablehnungsnachricht |
| `interpolation_delay` |0,1s | Darstellungsverzögerung, etwa zwei Netzintervalle |
| `interpolation_max_snapshots` |8 | Begrenzter Positionspuffer |
| `interpolation_max_gap` |0,25s | Bei größeren Lücken neu puffern statt weit verbinden |
| `interpolation_teleport_distance` |256px | Sprunggrenze von acht32px-Tiles |

Quellen: `src/session_protocol.gd`, `src/snapshot_interpolator.gd`, `src/game.gd`.
Es wurden keine neuen Waffen-/Schadens-/Lebenswerte oder Karten verändert.

## Geprüft und Grenzen

53 Interpolations-,20 Protokoll-,5 Mitgliedschafts- und3 Feedbackreset-Prüfungen
bestanden. Sechs reale Aufnahme-Rollen einschließlich malformed Hello und
Host-Timeout bestanden. Eine Lobby-Farbduplizierung nach mittlerem Abgang und
Wiederbeitritt sowie alte Effekte bei festem Seed-Neustart wurden mit zuvor
fehlgeschlagenen Regressionen behoben.

Aktuelle Kampagnen-/Koopnachweise und Bildzeitbedingungen:
[GameDev-Umsetzung](GAMEDEV-UMSETZUNG.de.md).
Die Hardware-Abnahme auf zwei Rechnern bleibt separat:
[LAN-Ablauf](LAN-ABNAHME.de.md).
