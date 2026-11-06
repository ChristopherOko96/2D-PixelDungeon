# Sichtbare Gegnerzustände

05.11.2026. Nutzerauftrag: Brennen, Gift und Nässe durch erkennbare Partikel
direkt an den Gegnern zeigen, als Grundlage für den Fallenalchemisten.

## Darstellung

- **Brennen:** orangegelbe Flammenzungen mit hellem Fuß und dunklerer Spitze,
  dazu aufsteigende glühende Pixel. Bestehender Flammenrenderer.
- **Vergiftet:** grüne hohle Bläschen steigen seitlich am Körper auf.
- **Nass:** hellblaue Tropfen mit heller Kappe fallen am Körper hinab.
- **Eingefroren:** helle blauweiße Kristallfunken; generische Betäubung oder
  Festhalten erzeugen diesen Effekt ausdrücklich nicht.

Mehrere Zustände können gleichzeitig sichtbar sein. Neue Partikel entstehen
an der aktuellen Gegnerposition; bereits freigesetzte Teilchen bewegen sich
im gemeinsamen Partikellöser weiter und reagieren auf dessen Kräfte und Wände.
Bei Heilung/Entfernung/Tod endet der Ausstoß sofort. Die letzten freien Partikel
verblassen innerhalb ihrer kurzen Lebensdauer. Keine neuen Texturen erforderlich.
Die bisherigen kleinen Farbbalken entfallen für diese vier Zustände im
Hauptdungeon. Andere Statusmarker bleiben erhalten.

## Technischer Vertrag

`src/vfx/enemy_status_fx.gd` gehört der bestehenden `Feedback`-Instanz.
`observe(enemies)` übernimmt nur bestätigte Zustände und Positionen und emittiert
nichts. `update(delta, particles)` verbraucht Zeitreste für jede aktive
Gegner-/Statuskombination. Wiederholte Snapshots setzen diese Reste nicht zurück.
Hitstop und Pausen folgen dem bestehenden Feedback-Takt. Raumwechsel und die
Story-Floor-/Resetpfade löschen die Emissionszähler.

Hauptdungeon: vorhandene replizierte `statuses`-Liste; keine Protokolländerung.
Live-Statusdictionaries werden ebenfalls unterstützt, aber abgelaufene `time`
Einträge ignoriert. Die Story-Adapter übersetzen ihre echten `fire_t`/`burn_t`,
`poison_t`, `wet_t` und `frozen`-Zeitfelder in lokale Darstellungsnamen. Nässe
unterdrückt eine bloß verbliebene `burn_t`-Darstellung. `bleed_t`, `stun` und
`rooted` werden nicht als Feuer oder Eis interpretiert. Eispartikel in Stories
folgen hier ausdrücklich `frozen`, nicht der allgemeinen `stun`-Variable.

Die Teilchen nutzen bestehende Modi des gemeinsamen Lösers. Kosmetische
`gravity`, `fade`, `settle=false` und Zeichenmerkmale werden nur an den neuen
Teilchen gesetzt. Giftbläschen und Wassertropfen haben unterscheidbare Formen.
Es entstehen keine schadenden Pfützen, Gase, dauerhaften Bodenablagerungen,
Statusanwendungen oder Ressourcenänderungen. Keine Kampf-/Immunitätsänderung.

## Konfiguration

`assets/data/enemy_status_fx.json`, Schema 1:

| Feld | Bedeutung |
|---|---|
| `soft_cap` | Ab dieser Belegung keine zusätzlichen Statuspartikel; globales bestehendes 900er-Budget bleibt erhalten. |
| `frame_budget` | Maximal neue Statuspartikel pro Update für alle Gegner zusammen. |
| `max_dt` | Maximal berücksichtigte Sekunden nach einem langen Frame; keine aufgeholte Emissionslawine. |
| `radius_min/max`, `height_min/max` | Kosmetische Körpergrenzen in Krypta-Pixeln. |
| `styles.<status>.rate` | Partikel pro Sekunde je Gegner. |
| `life`, `size`, `mode` | Lebensdauer in Sekunden, Größe in Pixeln und vorhandener Lösungsmodus. |
| `gravity`, `lift`, `speed` | Höhe-Beschleunigung in px/s², Höhen- und Seitengeschwindigkeit in px/s. |
| `colours` | Palette als RGB-Hexfarben. |

Die Startfigur wechselt bei jedem Update zyklisch, damit volle Budgets nicht
immer dieselben Gegner bevorzugen. Bei Überlast wird Zusatzemission verworfen,
statt sie für spätere Frames anzusammeln.

## Prüfen

`tests/enemy_status_fx_test.gd`: Lebenszyklus, Koexistenz, Bewegungsrichtungen,
60/144-Hz-Raten, Budget, Heilung, Tod, Hitstop, Raumwechsel und unveränderte
Hostdaten. Echte GPU-Trainingsaufnahmen und Story-Adapterchecks unter
`production/qa/evidence/enemy-status/`. Kein erspielter Lauf oder neue
Netzwerk-/Leistungsabnahme. Der Fallenalchemist selbst ist hier noch nicht
umgebaut; dies ist seine gemeinsam nutzbare Statusdarstellung.
