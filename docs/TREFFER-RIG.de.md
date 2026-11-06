# Geriggte Gegnertreffer

04.11.2026. Auf Nutzerwunsch ergänzt die gemeinsame Treffer-Rückmeldung einen
kurzen artikulierten Impuls am Gegner. Er funktioniert auch bei durchbohrenden
Pfeilen, deren Projektil nach einem Treffer weiterfliegt.

Ein heller Kern steht höchstens 55 ms. Vier Strahlen öffnen sich nach außen;
vier kleinere Teile drehen sich getrennt und fallen nach unten. Nach 340 ms
ist der Effekt vollständig verschwunden. Die vorhandenen materialabhängigen
Funken, Blut-/Knochenteile, Rückstöße, Sounds und Trefferblitze bleiben aktiv.
Es gibt kein zusätzliches Hitstop oder stärkeres Kamerawackeln.

Die gemeinsamen Host-Trefferzähler sind der Auslöser. Ein neuer Zählerstand
startet einen Impuls, auch beim tödlichen direkten Treffer. Wiederholte
Snapshots, erstmalig geladene Gegner und reine Blockmeldungen starten keinen.
Mehrere Treffer zwischen zwei Snapshots werden als ein Impuls dargestellt.
Maximal 24 Impulse bleiben gleichzeitig aktiv; der älteste wird verdrängt.
Raum-/Runwechsel und der Story-Reset entfernen alte Impulse.

Der Kontakt liegt auf der eingehenden Seite des vorhandenen Gegner-
Feedbackpunkts. Das ist eine lokale Kontaktannäherung anhand von Position und
Schlagrichtung, kein neu replizierter exakter Kollisionspunkt. Gameplay,
Schadensberechnung, Trefferprüfung und Netzwerkprotokoll bleiben unverändert.

## Tatsächlicher Rig-Pfad

`src/rig/hit_burst_rig.gd` lädt einmal die bereits freigegebene native
`assets/sprites/marksman/hit_large.png`. Es zerlegt deren Pixel über
`RigLibrary.cutout_frame` und die inklusiven Masken in neun Teile. Kein
Quellpixel gehört mehreren Teilen. Strahlen und Splitter haben den Kern als
Elternteil; ihre individuellen Posen laufen durch `RigRenderer.solve_pose`.
Die Texturen bleiben gecacht, pro Bild ändern sich nur Transformationen und
die abgestufte Deckkraft. Es werden keine neuen PNGs pro Bild erzeugt.

`Feedback.hit_rigs` besitzt die kurzlebigen Instanzen. Die Darstellung in
`dungeon_view.gd` und `story_feel.gd` nutzt denselben
`FxSprites.draw_external_rig`-Pfad samt Raum-/Wand-Clipping wie die anderen
artikulierten Effekte. Die Lebenszeit wird im Update weitergeschaltet, nicht
beim Zeichnen. Bestehendes Hitstop friert auch diesen Impuls ein.

## Konfiguration

`assets/data/hit_feedback.json` ist ausschließlich lokale Darstellung:

- `source`: unveränderte native Quellgrafik.
- `cap`: maximale gleichzeitig aktive Impulse.
- `life`, `core_s`: Sekunden für Gesamtleben und hellen Kern.
- `travel`, `lift`, `contact_inset`: native Quellpixel für Strahlenweg,
  Höhe und Kontaktnäherung auf der Eingangsseite.
- `chip_speed`, `chip_lift`: native Pixel pro Sekunde.
- `gravity`: native Pixel pro Sekunde²; `spin`: Radiant pro Sekunde.
- `rig`: bestehendes Masken-/Eltern-/Pivot-Schema, inklusive Rechtecke.

Die normale Kunstskalierung bleibt erhalten. Boss-/tödliche Treffer bekommen
20 % mehr Teilebewegung, ohne einen größeren weißen Kern.

## Prüfung

`tests/hit_burst_rig_test.gd`: 39 Checks, 0 Fehler. Zählergrenzen,
Erstsicht, Wiederholung, Block, direkte Tötung, Ablauf, Hitstop, Reset,
Teilebudget, echte Gelenkbewegung, Texturcache und vollständige eindeutige
Quellpixelzuordnung. Bestehendes `tests/feedback_test.gd`: 19/0.

`scripts/capture_hit_rig.gd` beobachtet eine tatsächliche Projektilkollision
mit Lebensverlust im aktuellen Laufzeit-Labor. Zwei Bilder zeigen Beginn
und Teilebewegung; für das zweite wird nur das Präsentationsalter gezielt
um 90 ms erhöht. `capture_hit_rig_story.gd` prüft zusätzlich tatsächliche
Schuss-/Gegnerkollisionen in Hölle und Frostgruft (vier Assertions, null Fehler).

Aufnahmen, Logs und Grenzen: `production/qa/evidence/hit-rig/README.md`.
Alle Aufnahmen nutzen isolierte Trainingszustände. Keine erspielte Kampagne,
Netzwerk-/LAN- oder Performanceabnahme und keine abgeschlossene Bewertung des
subjektiven Treffergefühls. Keine neue Bildgenerierung, kein Commit/Push.
