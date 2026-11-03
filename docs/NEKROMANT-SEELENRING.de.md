# Nekromant: Seelenring mit äußerem Feldsaum

**Aktuelle Folgekorrektur:** [Seelenangriffe](NEKROMANT-SEELENANGRIFFE.de.md)
vergrößert den Ring erneut auf 10 m mit 2 m breitem Feld und Rückstoß.
Die folgende 7-m-Beschreibung dokumentiert den vorherigen Stand.

01.11.2026: Nach Integration von `origin/main` (`b178a185`) wurde der Ring auf
Nutzerwunsch von 5 auf **7 m Gesamtdurchmesser** vergrößert. Der Durchmesser
ist weiterhin gemeint. Die bisherigen Feldgeister und der Partikelschweif wurden
vom Nutzer zur Beibehaltung angenommen und werden hier unverändert verwendet.

## Verhalten

Der bisherige Talentplatz `soul_3` heißt jetzt **Seelenring**. Beim Auslösen
trifft die bisherige Nova einmalig innerhalb von 3,5 m Radius mit 90/110/130 %
Basisschaden. Sechs Rig-Geister laufen als Seelenwelle um den Nekromanten nach
außen. Nach 0,65 s bleibt für 4 s ein echter ringförmiger Seelensaum zurück.
Er liegt am Ort des Auslösens und folgt einem weggehenden Spieler nicht.

Außenradius 3,5 m, Breite 0,75 m, freier Innenradius 2,75 m. Bei 32 Weltpixeln
je Spielmeter sind das 112/24/88 px. Der Saum verwendet dasselbe detaillierte
PoolPaint-Seelenmaterial wie das gesetzte Feld; seine Fläche wird direkt als
Ring aufgebaut. Keine überlappenden Kreisflächen, die die Mitte füllen würden.
Die Mitte ist für dieses Folgefeld frei. Eine separat dorthin gesetzte andere
Fähigkeit wird dadurch nicht gelöscht.

Geister am Rand halten normale Gegner 0,45 s fest. Die gemeinsame 1,6-s-Sperre
mit Seelensturm und Wächter verhindert gestapelte Dauerbetäubungen. Bosse und
Minibosse bleiben gegen das Festhalten immun. Der Saum fügt keinen zusätzlichen
Dauerschaden hinzu: Die bisherigen 90/110/130 % Novaschaden, **22 Seelen** und
**11 s Abklingzeit** bleiben. Der Durchmesser ist gegenüber dem ersten Ring
um 40 % auf 7 m gewachsen. Die auslaufende Animation ist
kosmetisch; der unveränderte einmalige Novatreffer erfolgt beim Auslösen.

Host-Prüfung bezieht den Gegnerkörper ein: Berührt sein Radius den Saum, gilt
er als im Ring; ein vollständig im Loch stehender Gegner wird dort nicht
festgehalten. Nova und Folgefeld wirken nicht durch Wände. Festhalte-Geister
kommen aus dem äußeren Saum, nicht aus dessen freier Mitte. Raumwechsel und
Neustart entfernen auch einen noch wartenden Folgeeffekt.

## Daten und Implementierung

`assets/data/talents.json`, `soul_3`, bestehender Typ `nova`, neue Felder:

| Feld | Wert | Einheit |
|---|---:|---|
| radius_m | 3,5 | äußerer Radius in Spielmetern |
| ring_width_m | 0,75 | radiale Saumbreite in Spielmetern |
| ring_expand | 0,65 | Sekunden bis der Saum aktiv wird |
| ring_time | 4 | aktive Sekunden des Saums |
| bind_stun | 0,45 | Sekunden Festhalten, nur normale Gegner |
| bind_cooldown | 1,6 | gemeinsame Sperrzeit pro Gegner in Sekunden |
| bind_visual_time | 1,2 | kosmetische Dauer des Umschlingens |
| bind_visual_cap | 16 | vorhandenes Limit gleichzeitiger Festhalte-VFX |

`talent_combat.gd` erzeugt eine verzögerte Zone mit `inner_r`, `delay` und
`look=souls_ring`. Während `delay>0` ist sie nicht aktiv und wird nicht als
Feld im Snapshot übertragen. Aktive Zeit läuft erst nach der Verzögerung.
`soul_ring_shape.gd` definiert Kreisringkontakt und die Materialzellen; jede
Materialzelle liegt vollständig zwischen den beiden Radien. Sichtprüfung
gegen den Boden verhindert eine Ausbreitung hinter Wände. Größere Flächen
verwenden die vorhandenen PoolPaint-Arbeiter und Bake-Budgets.

Snapshot `talents.zones` enthält zusätzlich `owner` und `inner_r` (0 für alte
Kreis-/Linienfelder). **Regelversion 12**, Protokollschema weiterhin 4; ältere
Regelstände werden am bestehenden Sitzungszugang zurückgewiesen. Form,
Schaden, Kontrolle, Verzögerung und Ablauf bleiben ausschließlich hostseitig.
Weder clientseitiges Rig noch Texturen werden übertragen.

`src/vfx/soul_ring.gd` verbindet die bestehende Seelenwelle mit den angenommenen
kleinen Cutout-Rigs und Partikeln. Die Geister starten auf dem Saum, ihre Köpfe
bleiben klar und ihre Schweife schwingen nach. Neue Bildgeneration entfällt.
Eine bei nach oben gezeichneten Geistern auftretende doppelte Boden-Ecke in
Clip-Polygonen wird vor der Triangulation bereinigt; kollabierte Flächen bleiben
unsichtbar und werden nicht versehentlich unbeschnitten gezeichnet.

## Selbst testen

**Testraum → Klasse Nekromant → Spezialisierung Seele**. **2** löst den
Seelenring aus. **4** bleibt das frei platzierte Seelenfeld, **R** der große
Seelenwächter. Falls das Panel fehlt, **F1**. **KEIN WERKZEUG** gibt Linksklick
wieder für den Standardangriff frei. Das gültige Testpreset hat den Ring jetzt
auf Taste 2 statt des Seelenschilds; andere erlernte Fähigkeiten bleiben im Baum.

Im normalen Baum: **Nekromant → Seele → Reihe II → Seelenring** (`soul_3`),
ab Level 5 und zwei vorher investierten Punkten. Auf einen Platz 1–4 legen;
die gewählte Taste löst ihn aus. 50 Startseelen reichen für einen Ring.

Nachweise: `production/qa/evidence/soul-ring/README.md`. Echte GPU-Spielaufnahme,
Testraum-Oberfläche, fokussierte Tests und zwei reale lokale ENet-Prozesse.
Testbegegnungen sind keine erspielte Kampagne; keine neue LAN-/WAN-/Leistungs-
oder langfristige Balanceabnahme.
