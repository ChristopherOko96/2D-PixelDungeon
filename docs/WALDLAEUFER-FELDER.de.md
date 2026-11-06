# Waldläufer: Himmelsspeer, Giftfalle und Rankensog

03.11.2026, Implementierung auf `codex/port-0x72-onto-main`. Dieser Nachtrag
ersetzt die entsprechenden älteren Zahlen und Namen im Schützenbericht.
Keine neue Figurenkunst, kein Enginewechsel. Der vorhandene Rig-Solver,
die nativen Teile und die bestehenden Flüssigkeits-/Gasschichten bleiben aktiv.

## Himmelsspeer — Treffsicherheit

R bis 1,5 s halten, loslassen zum Schuss. Der Treffbereich ist nun **2,4 m
breit**: bei 32 Pixeln pro Meter 76,8 Pixel, Radius 38,4 Pixel. Das ist doppelt
so breit wie zuvor. Die technische Reichweite von 96 m reicht über die
Diagonale der maximal vorgesehenen 64×48-Kachelräume; der erste Wandkontakt
begrenzt den tatsächlichen Weg. Die Gerade wird durch Segmentprüfungen
ermittelt, ohne die Wandgleitbewegung von Figuren zu verwenden.

Der Host behält Kosten, Ladung, kritischen Schaden und Anpinnen bei:
50 Ausdauer plus höchstens 25 für Zusatzladung, 350–700 % Grundschaden vor
Krit, 60 s Abklingzeit. Bosse und Minibosse werden nicht mitgerissen.
Treffer hinter Wänden bleiben ausgeschlossen.

Der sichtbare Pfeil wächst passend zum echten Treffradius. Seine Spitze,
Schaft und Federn verwenden die vorhandenen ausgeschnittenen Pixelteile.
Nach 0,28 s erreicht er das vom Host bestimmte Ende. Beim Wandkontakt
zerfallen diese Teile mit unabhängiger Drehung und Fallbewegung; zusätzlich
entstehen physische Holzsplitter und Funken. Ein vom Host ermittelter
Kontaktnormalenvektor hält auch rotierende Teile vor der Wand. Wiederholte
Snapshots lösen keinen zweiten Partikelstoß aus. Partikeldichte und Zeiten
sind begrenzt; es wird kein neues Ganzbild pro Animationsframe erzeugt.

## Giftfalle — Fallensteller, Reihe IV

Die bisher sofort gesetzte Giftwolke (`trapper_7`) ist nun eine **Falle**.
Nach 0,5 s ist sie scharf; ein sichtbarer Gegner in 1,3 m zuzüglich seines
Körperradius löst sie genau einmal aus. Drei Ladungen, 14 s Basisnachladezeit
pro Ladung, 25 Ausdauer, gemeinsames Limit von sechs eigenen Fallen.

Auslösung erzeugt **eine vorhandene Giftpfütze und eine vorhandene
Giftwolke**, 3 m Feldradius und 6 s Dauer. Die Wolke hat 2,25 m Radius,
damit der äußere Flüssigkeitssaum sichtbar bleibt. Der Fähigkeitstick verursacht
pro Sekunde 20/25/30 % Grundschaden plus bestehende Boni und Gift. Die native
Elementlogik der Medien bleibt wirksam. Die zusätzliche Tickzone zeichnet
kein zweites Feld und verursacht keinen zweiten eigenen Pool-DPS-Tick.
Eigene Wolken schaden der Gruppe nicht; feindliches überlappendes Gas bleibt
gefährlich. Der neue Wolkenpfad und der Fähigkeitstick respektieren Wände.

Die Fallenzähne bewegen sich durch ihre vorhandenen unabhängigen Gelenke.
Flüssigkeit und Wolke verwenden ihre kontinuierliche bestehende Partikel-
und Feldsimulation, keine neu gezeichnete Ersatzpfütze. Auch die Giftköder-
Aufwertung des Jagdgrunds nutzt diese realen Medien.

## Rankensog — Fallensteller, Reihe VI

`trapper_11` ersetzt den zusätzlichen Rauchsprung. Shift bleibt der normale
Dash. Rankensog wird bis 7 m entfernt auf den Boden gesetzt. Für 1,5 s zieht
er sichtbare normale Gegner in 5 m Radius mit höchstens 4,5 m/s zum Zentrum.
Alle 0,5 s verursacht er 15/20/25 % Schaden und kurz 35 % Verlangsamung.
20 Ausdauer, 14 s Abklingzeit.

Bosse und Minibosse nehmen Schaden und Verlangsamung, werden jedoch nicht
bewegt. Kein Ziehen oder Fähigkeitsschaden durch eine Wand, keine Bewegung
des Spielers und kein fortwirkender Sog nach Ablauf. Bewegungen verwenden
die vorhandene Kollisionsprüfung. Neun bestehende Rig-Teile bilden den
beweglichen Kern mit acht einwärts laufenden Teilen; das vorhandene
Partikelsystem zieht lose Materie ein. Kein zusätzliches Giftfeld.

## Direkt testen

`Waldmeister-Testraum.cmd` öffnen:

- **FERN → Präzision:** R halten und Richtung einer Wand loslassen.
  Gegner leicht neben der Schusslinie und weit im Raum werden getroffen;
  an der Wand zerspringt der Pfeil.
- **FALLEN → Gift & Dornen:** **4 = Giftfalle**. Auf den Boden setzen und
  einen Gegner hineinlaufen lassen. Feld und Wolke entstehen nach Auslösung.
- **FALLEN → Netz & Rankensog:** **3 = Rankensog**. Zwischen mehrere Gegner
  zielen. Sie werden zum Zentrum gezogen; der Spieler bleibt stehen.

Im normalen Talentbaum: Bogenschütze → Treffsicherheit für die Ulti,
Bogenschütze → Fallensteller für Giftfalle und Rankensog. Laborhilfen wie
Ausdauer+ sind Testwerkzeuge und ändern keine Fähigkeitskosten im Spiel.

## Daten und Prüfung

`scripts/apply_ranger_fields_data.cjs` ist die idempotente Datenmigration.
Die vorherige Schützenmigration ruft sie zuletzt auf. `talents.json`:
`sniper_14.length_m/width_m/wall_radius/flight_s/impact_s`, `trapper_7.cloud`
mit `time/every/dmg/radius_m/gas_radius_m/status`, `trapper_11.pull_mps/look/reach_m`.
`vfx_talents.json.ranger.arrow` enthält die begrenzte Spur, Splitterbewegung
und Partikelzahlen; `.lure` enthält Tempo und Aussehen des Sogs. Im
Labor-Datensatz heißt die zweite Fallenbelegung jetzt „Netz & Rankensog“.
Protokoll 4, Regelstand **27**.

Die neuen Hostprüfungen wurden vor Implementierung mit acht fehlenden
Anforderungen gesehen; anschließend bestehen die Szenarien. Die zusätzlich
in einer echten Aufnahme gefundene Splitter-Wandüberschreitung wurde vor
ihrer Korrektur mit zwei fehlgeschlagenen geometrischen Prüfungen reproduziert.
Aktuelle Ergebnisse und Quellhashes liegen in
`production/qa/evidence/ranger-fields/receipt.json`.

Acht tatsächliche 1280×720-Spielaufnahmen zeigen vorbereitete Trainingszustände,
keinen erspielten Durchlauf. Netzwerkprüfungen sind lokale getrennte Prozesse,
keine LAN-/WAN- oder Leistungsmessung. Bekannte Fixture-Warnungen zu Ressourcen
beim Beenden bleiben getrennt dokumentiert; Nutzerabnahme des Spielgefühls steht aus.
