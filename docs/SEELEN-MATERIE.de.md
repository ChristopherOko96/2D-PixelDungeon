# Seelen und reagierende Materialoberflächen

04.11.2026, auf Basis `ab181e4a`. Die bisherige Seelenaufnahme mit Rig wurde
durch simulierte Pixel ersetzt. Keine neuen Bilder oder Sprite-Sheets.

## Im Spiel

- Seelensog emittiert einmal pro bestätigter Belohnung einen Schwarm aus
  einzelnen Pixeln. Diese haben eigene Position, Geschwindigkeit und
  Lebensdauer im vorhandenen `Particles`-Löser. Der Stab aktualisiert ihr Ziel.
  Wind, Wände, andere Sogfelder und Druckwellen wirken auf diese Pixel.
  Die Aufnahme besitzt jetzt einen kleinen Seelenkopf mit zwei dunklen Augen
  und kurzem Blinzeln. Sein 7×7-Pixel-Gesicht wird am tatsächlich simulierten
  Kopfteilchen gezeichnet. Sechs weitere Partikel bilden einen durch Federn
  gekoppelten, nachlaufenden Schweif; lose Pixel bleiben daneben bestehen.
  Der Schweif folgt Geschwindigkeiten und äußeren Kräften, keiner Bildkurve.
- Beim Tod sammeln sich die Aufnahme-Pixel zunächst aus einem kleinen Bereich
  des Leichnams. Sie steigen über 0,42 Sekunden um 18 Partikelpixel auf;
  zwischen 0,20 und 0,42 Sekunden bildet sich der Seelenkopf. Erst nach
  0,48 Sekunden beginnt der Zug zum aktuellen Stab, weich über 0,16 Sekunden.
  Die lokale Darstellung dauert 1,4 Sekunden und überlebt das vorhandene
  0,7-Sekunden-Hostereignis. Die Seelengutschrift erfolgt weiterhin beim Kill.
- Seelenring, Seelenfeld und Seelenspur emittieren Teilchen auf ihrer tatsächlichen
  Materialfläche. Die Ringmitte bleibt frei; Wände begrenzen die Emission.
  Aufprall, Festhalten, Aufladung und die Geschosse der Seele verwenden ebenfalls
  Teilchen. Geschosse behalten einen kleinen lesbaren Pixelkern und die
  Aufladung ihre Leistungsanzeige. Beschworene Wächter bleiben animierte
  Spielfiguren; ihre Staubaura läuft jetzt im Partikellöser.
- Die vorhandene Boss-Druckfront (`HellMonsters._blow_front → Particles.blow`)
  wirkt auch auf die Materialoberfläche. Sie wird lokal verschoben, schwingt
  durch benachbarte Massepunkte nach und kehrt gedämpft zurück. Explosionen
  über `kick` erreichen dieselbe Verbindung.
- Der Oberflächenanschluss ist gemeinsam für flüssige Bodenmaterialien aller
  Klassen: unter anderem Seele, Gift, Blut, Wasser, Lava, Feuer und Leere.
  Eis behält seine vorhandene Bruchdarstellung. Die bisherigen Materialpartikel
  anderer Klassen bleiben im selben Partikelraum und empfangen dieselben Kräfte.

Dies ist physikalisch berechnete **Darstellung pro Client**. Der Host entscheidet
weiterhin über Treffer, Seelengewinn und Kontrolle. Die kleinen Verformungen
ändern keine Schadenszellen, Reichweiten, Kosten oder Betäubungsdauer. Freie
Seelenpixel können vom Wind abgetrieben oder von einem Sog gefressen werden;
das bucht die bereits bestätigte Belohnung nicht erneut oder zurück. Ein
Seelenring wird dadurch kein frei verschiebbarer neuer Gameplay-Collider.

## Umsetzung und Grenzen

`soul_matter.gd` verwaltet einmalige Emissionen und laufende Quellen;
`soul_absorption.gd` verwendet für die Aufnahme jetzt `Particles.release_soul`.
`TalentFx.soul_pickup_frames` hält höchstens 24 Aufnahmen pro Client vor,
entfernt sie nach Ablauf und verhindert doppelte Emissionen aus wiederholten
Snapshots. Ein neuer Boden oder zurückgesetzter Spieltakt leert die Vormerkung.
Das Hostereignis und das Netzwerkformat bleiben unverändert.
Es werden keine Teilchen auf einer vorgegebenen Bildkurve neu positioniert.
Die Zielkraft addiert Beschleunigung; der bestehende Löser bewegt die Pixel
mit Wind, Wandkontakt und fremden Kräften. Schnelle Aufnahme-Pixel verwenden
kurze Bewegungsschritte gegen das Durchtunneln von Wänden.

`surface_motion.gd` berechnet gekoppelte, gedämpfte Federmassen mit 60 festen
Schritten/s. Druckfronten beachten Radiusband, Richtung, Öffnungswinkel,
Abflachung und Wände. Ein gerastertes, nearest-gefiltertes Texturmesh zeigt
diese Zustände. Ruhende Flächen nutzen den bisherigen einfachen Zeichenweg.
Wandnahe Bereiche bleiben befestigt; Verschiebung und Knotenzahl sind begrenzt.
Das ist kein vollständiger Flüssigkeitssimulator und keine neue Netzwerkphysik.
Verwendete Engine-Schnittstellen: [ArrayMesh](https://docs.godotengine.org/en/stable/classes/class_arraymesh.html)
und [CanvasItem.draw_mesh](https://docs.godotengine.org/en/stable/classes/class_canvasitem.html#class-canvasitem-method-draw-mesh).

## Einstellungen

| Datei / Abschnitt | Einheiten und Begrenzung |
|---|---|
| `vfx_particles.json` / `soul` | `spread` in Partikelpixeln; `launch_speed` und `max_speed` in px/s; `homing` in s⁻²; `damping` in s⁻¹; `colours` als Hexfarben |
| derselbe Abschnitt, Seelengesicht | `face_colours`: vier Hexfarben (Tiefe, Körper, Licht, Augen); `tail_count`: höchstens acht gekoppelte Teilchen; `tail_gap`, `head_tail_gap`: Partikelpixel; `tail_spring`: s⁻²; `tail_damping`: s⁻¹; `blink_at`, `blink_for`: Sekunden seit Emission bzw. Blinzeldauer |
| derselbe Abschnitt, Aufnahme | `release_gather_s`, `release_rise_s`, `release_pull_ramp`, `release_face_begin`, `release_face_end`: Sekunden; `release_rise`, `release_body_spread`: Partikelpixel; `release_height_ease`: s⁻¹ |
| `vfx_talents.json` / `soul_absorption` | `release_duration`: lokale Lebensdauer in Sekunden; `max_visible`: höchstens 32 gleichzeitige Aufnahmen, Standard 24 |
| `vfx_talents.json` / `soul_physics` | Intervalle, Lebensdauern und `burst_travel` in Sekunden; `field_drift` in Partikelpixeln/s; `*_lift`, `guardian_radius` in Partikelpixeln; `*_count` je Emission |
| `vfx_pools.json` / `surface_motion` | `spacing_art` Rasterabstand, `max_offset_art` maximale Auslenkung in Kunstpixeln; zusätzlich höchstens 30 % des Rasterabstands; `max_speed_art` Kunstpixel/s |
| derselbe Abschnitt | `spring`, `coupling` in s⁻²; `damping` in s⁻¹; `pressure_share` dimensionslos; `idle_ttl` Sekunden; `max_nodes` höchstens 2048 gespeicherte Knoten; `mesh_axis_max` höchstens 32 Unterteilungen je Achse |

Der bestehende gemeinsame Partikeldeckel bleibt **900**. Kosmetische Quellen
drosseln bereits vor diesem Deckel; es gibt kein unbegrenztes System pro Zauber.
Story-Weltpixel und Partikelpixel werden an den vorhandenen Weltanschlüssen
umgerechnet. Die Oberfläche wurde bei 30/60/144 Zeichenbildern pro Sekunde
auf denselben Zustand geprüft; das ist keine Vier-Spieler-FPS-Abnahme.

Zum Ansehen: **Testraum → Nekromant → Seele**, Seelenring auf die Leiste legen,
wirken und eine Boss-Druckwelle darüberlaufen lassen. Aufnahme durch einen
normalen Gegner-Kill ansehen. Nachweise und Einschränkungen stehen unter
`production/qa/evidence/soul-matter/README.md`.
Die Aufnahme nach einem echten Gegner-Kill mit Sammeln, Aufsteigen und Flug
steht unter `production/qa/evidence/soul-rise/README.md` samt verlangsamtem GIF.
