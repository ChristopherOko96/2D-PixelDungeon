# Scharfschütze und Fallensteller – 03.11.2026

Implementiert auf `codex/port-0x72-onto-main`. Der Krieger bleibt bis auf den gemeinsamen Standard-Dash unverändert; sein gesondertes Konzept steht in [KRIEGER-KONZEPT.de.md](KRIEGER-KONZEPT.de.md).

## Direkt ausprobieren

`Waldmeister-Testraum.cmd` starten. **FERN → Präzision**: 1 gezielter Schuss, 2 Durchschuss, **3 Jägermal**, 4 Salve. **FERN → Fernkampf**: 1 gezielter Schuss, 2 Jägermal, 3 Rückwärtssalto, **4 normaler Pfeilhagel**. In beiden Belegungen: **R halten zum Laden, loslassen zum Schuss**. Der Pfeilhagel und die vorhandenen Mehrfachschüsse bleiben.

**FALLEN → Gift & Dornen**: 2 Dornenfalle, 3 Explosionsfalle. **FALLEN → Netz & Rückzug**: 2 Netzfalle, 4 Explosionsfalle. Die Leiste zeigt die verfügbaren Ladungen. Ausdauer + und Gegner +6 sind reine Laborhilfen; Kampagnen-Speicherslots werden nicht verändert.

## Jägermal

Ein Einsatz markiert alle sichtbaren lebenden Gegner in acht Metern um den Schützen. Jedes Ziel erhält eine eigene Markierung je Besitzer. Dauer 8/10/12 Sekunden, nächster bestätigter eigener Pfeiltreffer **einmalig +40/60/80 % Schaden**. Danach verschwindet genau dieses Mal. Ein anderer Gegner bleibt weiter markiert. Begleiter, Schaden über Zeit, Sekundäreffekte und fremde Spieler verbrauchen es nicht; ein abgeblockter Treffer ohne aufgelösten Schaden ebenfalls nicht.

Die Markierung wird als goldene Zielklammer dargestellt. Sie verwendet keine Fluchgeister. Berechnung und Verbrauch passieren beim Host in einem kurz begrenzten direkten Pfeiltreffer-Kontext.

## R: Himmelsspeer

Bis zu **1,5 Sekunden** laden. Loslassen oder volle Ladung feuert genau einmal. 50 Ausdauer beim Beginn und bis zu 25 zusätzliche Ausdauer für die tatsächlich vom Host aufgebaute Ladung; normale Regeneration bleibt aktiv. 60 Sekunden Abklingzeit, Menü-/Tod-/Raumwechsel beenden eine unfertige Ladung ohne Erstattung oder nachträglichen Treffer.

Eine bis zur ersten Wand begrenzte **14-m-Linie**, 1,2 m breit, trifft alle sichtbaren Gegner darin. 350 bis 700 % Heldengrundschaden vor dem garantierten kritischen Treffer und bestehenden Talentboni. Normale lebende Gegner werden über 0,25 Sekunden bis zu zwei bis vier Meter in Schussrichtung mitgerissen und insgesamt eine bis zwei Sekunden angepinnt. Kollisionsbewegung stoppt an Hindernissen. Bosse und Minibosse nehmen Schaden, werden aber weder mitgerissen noch angepinnt. Die vorhandenen Aufwertungen Brandmal und Sternenfall bleiben.

Pfeilkopf, Schaft und zwei Federteile stammen aus der vorhandenen 7×21-Pfeilgrafik und laufen durch denselben Körperteil-Rig-Solver wie andere Effekte. Bogen-Sehne und Ladeanzeige folgen der tatsächlichen Host-Ladung; keine neue Akteursgrafik.

## Fallen und Ladungen

| Fähigkeit | Schadensradius | Ladungen | Basis-Nachladezeit je Ladung |
| --- | --- | --- | --- |
| Dornenfalle | 2 m | 3 | 12 s |
| Explosionsfalle | 4 m | 3 | 18 s |
| Netzfalle | 3 m | 3 | 14 s |

Alle drei Fallen werden nach 0,5 Sekunden scharf. Die geriggten Zähne stehen weiter auseinander, ihre Quellpixel behalten ihre Größe. Das sichtbare Modell, der Auslösebereich und der Schadensradius sind getrennte Werte. Auslösebereich 1,2/1,3/1,2 m; Schaden/Fessel respektieren Wände.

Bis zu **sechs eigene Fallen** gleichzeitig; auch die Ultimate zählt dazu. Bei einer weiteren erlaubten Platzierung verschwindet die älteste. Andere Besitzer haben eigene Grenzen. Die Waldmeister-Fallen behalten ihr bisheriges Limit. Fallen leben weiter maximal 30 Sekunden.

Ladungen laden **nacheinander**. Weitere Einsätze setzen den laufenden Nachladefortschritt nicht zurück. Kosten pro Einsatz, globales Aktionsintervall und normale Abklingzeit-Boni gelten weiter. Beim Bearbeiten derselben Klasse bleiben verbrauchte Ladungen und Fortschritt erhalten; Menüwechsel schenkt keine Ladungen.

## Gemeinsamer Dash

Alle vier Klassen haben jetzt identisch Shift: drei Meter, eine Ladung, vier Sekunden Wiederaufladung, 0,25 Sekunden kurze Unverwundbarkeit. Halten wiederholt ihn nicht, Hindernisse stoppen den Weg. Das ersetzt auch die frühere zweite Schützen-Ladung; separate Bewegungsfähigkeiten bleiben erhalten.

## Daten und Nachweise

`talents.json`: `marksman` mit Radius/Dauer/Bonus, `sniper_14.charge` mit Ladezeit/zusätzlichen Kosten/Schadensfaktor und `pin` mit maximalem Weg, Bewegungszeit und Haltedauer. Fallen: `charges`, `arm_s`, `trigger_m`, `visual_spread`; `trap_limits.trapper` begrenzt eigene Quellen. `marksman_rig.json` verwendet das bestehende inklusive Maskenrechteck-/Eltern-/Pivot-Schema. Die Migration steht in `scripts/apply_archer_rework_data.cjs`.

Regelsatz 25, Protokoll 4. Lokale Test- und GPU-Nachweise: `production/qa/evidence/archer-rework/README.md`. Keine neue Kampagnen-, LAN- oder Leistungsbehauptung. Die Zahlen sind implementiert; langfristiges Spielgefühl und Balance bleiben zu bewerten.
