# Seelen, Begleiter-Aggro und ruhigere Geister

31.10.2026: Nutzerauftrag umgesetzt. Keine neue Figur oder Bildgenerierung;
das angenommene Design und die vorhandenen Sprites bleiben.

## Begleiter bleiben im Kampf

Die gemeinsame Zielsuche `src/combat/companion_targets.gd` gilt für Talent-
Begleiter aller Klassen, den Seelenwächter sowie Story-Unterklassen-/Relikt-
Begleiter in Hölle und Frostgruft.

- Neue sichtbare Gegner werden innerhalb 10 m **um den Begleiter** erfasst,
  unabhängig davon, wen der Gegner selbst angreift. Er braucht keinen vorherigen
  Treffer oder Aggro des Besitzers.
- Ein nahes sichtbares befohlenes Ziel kann Vorrang haben. Sonst bleibt das
  bestehende lebende Ziel auch außerhalb des Erfassungsradius erhalten.
- Tod des Ziels: lokale Überlebende angreifen. Erst ohne lokale Kampfziele
  zum Besitzer zurückkehren. Besitzerentfernung erzeugt keinen Rückruf.
- Wege/Wandkollision und Sicht für Treffer bleiben gültig; auch Begleiter-
  Fähigkeiten schießen nicht durch Wände. Krypta-Pfade werden zwischengespeichert.
- Begrenzte Beschwörungen behalten ihre bisherige Lebensdauer. Der Wächter
  läuft weiterhin nach 12/16 s aus. Raumwechsel und gültige Abbruchbedingungen
  bleiben erhalten; dauerhafte Begleiter reisen wie zuvor mit.

## Seelen statt Mana

Seelen sind eine **Kampfressource**, Seelensplitter weiterhin die dauerhafte
Freischaltungswährung. Alle drei Nekromanten-Zweige nutzen dieselbe Ökonomie.
Magier, Ausdauer und Zorn bleiben bei ihren eigenen Regeln.

| Quelle / Grenze | Basiswert |
|---|---:|
| Grundkapazität / Start | 100 / 50 |
| Eigener Kill, auch durch eigene Begleiter | 8 |
| Miniboss / Boss | 20 / 30 |
| Naher verbündeter Kill | Hälfte des Grundwerts, kein eigener Kill-Bonus |
| Angeborene Passive **Seelensog**, im Kampf | 2 pro Sekunde |
| Außerhalb des Kampfes | 1 pro Sekunde, nur bis 40 Reserve |

Ein bereits höherer Vorrat wird nicht abgezogen. Tote Nekromanten erhalten
weder passive noch Kill-Seelen. Beschworene Gegner erzeugen keine Seelen;
eine echte Todesmeldung zahlt höchstens einmal. Eigene Begleiter-Kills geben
ihrem Besitzer auch dann Seelen, wenn er weggelaufen ist. Verbündeten-Erträge
brauchen einen lebenden Spieler-Killer sowie Nähe (12 m) und Sicht zum Tod.
Als Kampfnähe zählen sichtbare lebende Gegner innerhalb 12 m; Seelensog zählt
auch den fortgesetzten Kampf eigener Begleiter, wenn der Besitzer weiter weg ist.

Seelenhunger/Totenbeschwörer geben wie bisher zusätzliche Kill-Ressourcen,
jetzt explizit +2/4/6 Seelen. Seelenspeicher erweitert die Grundkapazität um
15/30/45 und steigert Seelensog um 5/10/15 %. Daher kann ein ausgebauter
Seele-Build mehr als 100 Seelen fassen. Umskillen im Lauf füllt nichts auf.
Mana-Kugeln/Tränke bleiben für Mana-Spieler und füllen keine Seelen auf.

| Fähigkeit | Seelenkosten |
|---|---:|
| Seelenblitz / Fluchgeschoss | 8 |
| Knochenspeer / Befehl | 10 |
| Fluch der Schwäche / Blutfluch | 12 |
| Flucht-/Sprungtalente | 16 |
| Lähmender Fluch | 20 |
| Seelennova / Seelenlanze | 22 |
| Seelensturm / Seelenschild / Seuchenfeld / Leichenexplosion | 24 |
| Knochenkrieger wiederbeschwören / Skelettwache | 25 / 28 |
| Jede Nekromanten-Ultimate | 40 |

Die normalen Abklingzeiten bleiben. Standardangriffe verbrauchen keine Seelen.
Die Leiste zeigt **SEELEN · SEELENSOG** in Türkis; darüberfahren erklärt die
angeborene Passive. Talenttexte und Kostenanzeigen verwenden Seelen.

## Balance-Check: erster Abstimmungsstand

Skill: `studio-balance-check`, Domäne Ressourcenökonomie.
FOUND: `assets/data/talents.json`, `assets/data/vfx_talents.json`, tatsächlicher
Talent-/Begleiter-Code und fokussierte Tests. Registry FOUND, aber
`constants/formulas` leer; passendes System-GDD und Langzeit-Telemetrie ABSENT.
Unabhängige numerische Zielbereiche, DPS/TTK- und Langzeit-Progressionsurteil:
**NOT ASSESSED — NO DATA**. Kein allgemeines „fertig ausbalanciert“.

Nachvollziehbare Ressourcenrechnung (`scripts/analyze_necro_souls.ps1`):

- Start 50 plus 2 normale Kills = 66; Wächter plus Feld kosten 64. Die
  Eröffnungs-Kombination muss erst erarbeitet werden.
- Boss ohne Adds: Grundbudget in 60 s 50 + 120 = 170. Eine gültige zeitliche
  Folge mit **1 Wächter, 3 Feldern, 6 Blitzen** verbraucht 160 und lässt 10
  übrig. Das Modell prüft auch reale Kosten und Abklingzeiten. Kein Bosskill-
  oder Schadensnachweis, sondern Ressourcenarithmetik ohne Talentboni.
- Rein hypothetisch alle aktiven Talente eines Zweigs auf Abklingzeit:
  Diener 8,67, Fluch 9,17, Seele 10,16 Seelen/s. Das sind Obergrenzen mit mehr
  als vier aktiven Leistenplätzen, keine spielbaren Rotationen. Passive 2/s
  deckt dies nicht; Kill-Einkommen und Fähigkeitswahl bleiben relevant.
- Reserve-Limit verhindert volles Aufladen durch Warten. Passive verhindert
  eine reine Kill-Ressourcen-Sackgasse am Einzelboss. Halbe nahe Gruppen-
  Belohnung entschärft den Wettlauf um den letzten Treffer.

Vorbilder als **Gestaltungsprinzipien**, keine übernommenen Balancezahlen:
[Guild Wars 2](https://www.guildwars2.com/en/the-game/professions/necromancer/)
beschreibt Lebenskraft aus Angriffen und besonders Toden in der Nähe;
[Diablo III](https://eu.diablo3.blizzard.com/en-gb/class/necromancer/active/)
trennt Essenz-Erzeuger und -Verbraucher. Blizzard erläuterte außerdem eine
langsame Grundregeneration und alternative Erzeugung gegen Ressourcenmangel
im [Diablo-IV-Entwurfsartikel von 2022](https://news.blizzard.com/en-us/article/23816542/diablo-iv-quarterly-updatejune-2022).

## Ruhigere Geister und Staubaura

Die Griff-Geister drehen 0,55 statt 1,6 Umdrehungen pro Effekt, verteilt auf
1,2 statt 0,8 s. Der Stun bleibt **0,45 s** mit derselben 1,6-s-Sperre.
Feldanimation mit 70 % Tempo; Wächter-Schwebeschleife 1,6 statt 0,96 s und
kontinuierlicher Hub. Nearest-Texturen und Weltraster bleiben erhalten.

24 kleine Staubpartikel umkreisen den Wächter, steigen auf und blenden ein/
aus. Vor-/Hintergrundschichten, versetzte Phasen je Wächter, kein Neustart
bei jedem Angriff. Zeittakt aus der gesamten Beschwörungsdauer, keine neue
Bildtextur pro Frame. Langsames Ein-/Ausblenden beim Erscheinen/Ablauf.

## Daten und Testweg

`resources.necromancer`: `kind=souls`, `start/max/regen`, `rest_rate/rest_cap`,
`per_kill/per_miniboss/per_boss`, `ally_share`, `collect_range_m`,
`passive_name/passive_text`. `rest_rate` multipliziert Seelensog; alle Raten
pro Sekunde. `pet` und Guardian: `acquire_range_m`, `route_every` (s),
`route_retarget/route_near` (px). `vfx_talents.soul_motion`: `grasp_turns`,
`field_playback`, `aura_count/radius/height/cycle/opacity` (native Pixel bzw. s).
Regelversion 10, Protokoll 4; inkompatible ältere Clients werden abgewiesen.

Testraum → Nekromant → Seele. R Wächter, 4 Feld. Mit 50 Startseelen erst Gegner
besiegen, bevor beides zusammen möglich ist. Weglaufen, solange ein Gegner
lebt: der Begleiter bleibt im Kampf. Auf die türkise Seelenleiste zeigen,
um Seelensog zu erklären. Eigenes normales Profil bleibt im Testraum getrennt.

Fokussierte Nachweise: `production/qa/evidence/necro-souls-aggro/README.md`.
Keine neue LAN/WAN-, Vier-Spieler-, Leistungs- oder Langzeit-Balanceabnahme.
