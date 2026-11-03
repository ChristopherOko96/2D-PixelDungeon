# Fluchnekromant und Waldmeister – Stand 03.11.2026

Umgesetzt auf `codex/port-0x72-onto-main`, ohne Commit, Push oder Merge. Diese Fassung ersetzt die älteren Regeln „Ulti wartet auf Gegner-Tod“, „kreisende Fluchgeister“ und die alte Waldmeister-Ulti mit Geisterwölfen.

## Direkt testen

- **Nekromant-Testraum.cmd**: FLUCH, Belegung **Gift & Blut**. **1** Knochenball, **2** Fluch im Umkreis, **3** Seuchenfeld, **4** Blutstrahl, **R** Seuchengrube mit sofortigem Koloss. Der Koloss führt **5 Knochenwelle** und **6 Totenbrut** aus. Rechtsklick auf sein 5-Symbol schaltet die automatische Benutzung um.
- **Waldmeister-Testraum.cmd**: WALD, **Begleiter & Fallen**. **1** Begleiter neu rufen, falls gestorben; **2** Fass!, **3** Dornenköder, **4** Glutdruckfalle, **R** beide Würmer. In **Jagdgebiet** liegen Dornenköder auf 2, Glutdruckfalle auf 3 und Wurzelgrund auf 4. Der gelernte dauerhafte Begleiter beginnt bereits neben dir.
- **Seelenring**: Im Nekromanten-Labor SEELE / Ring & Lanze, **2**. Er wächst eine Sekunde vom Charakter nach außen; anschließend bleibt fünf Sekunden der hohle äußere Feldsaum. Die Mitte bleibt frei. Der vorhandene zehn Meter große Außendurchmesser bleibt erhalten.
- In beiden Laboren: WASD, **Shift Dash**, Gegner +6, Zielpuppe, Ressourcen auffüllen und Reset. **Üben** aktiviert Unverwundbarkeit. Die Labore sind offline und verwenden getrennte Trainingsprofile statt Kampagnen-Speicherslots.

## Fluchnekromant

**Fluch der Schwäche** wirkt auf alle sichtbaren Gegner in sechs Metern um den Spieler. Die Maus bestimmt kein Einzelziel. Dauer 8/10/12 Sekunden, eigener Schadensbonus 10/15/20 %. Drei eigenständige Fluch-Rigs steigen gestaffelt an jedem betroffenen Gegner empor: feste seitliche Bahnen, geringe Pendelbewegung, weiches Ein-/Ausblenden und unabhängig animierter Kiefer/Schweif. Keine Seelengeist-Quelle und keine Kreisbahn.

**Seuchengrube** legt weiter das echte große Giftfeld und ruft den vorhandenen Fluchkoloss unmittelbar. Höchstens ein lebender Koloss pro Besitzer; die verbrauchte Grube ruft nach seinem Tod keinen neuen. Normale Gegner-Tode in der Grube erzeugen weiterhin sofortige Knochenexplosionen. Das gewöhnliche Seuchenfeld behält seine jagenden Skelettläufer.

Der Koloss hat seinen normalen Angriff und zwei Befehle. **5 Knochenwelle**: 0,65 Sekunden Ausholen, danach 90 % Heldengrundschaden sowie die bisherigen Flüche/Schwächung in acht Metern; fünf Sekunden Abklingzeit. Die Knochen breiten sich sichtbar vom Koloss aus. **6 Totenbrut** bleibt das begrenzte Erwecken echter eigener Leichen. Seine bestätigten eigenen Treffer setzen als Passive einen Fluch für sechs Sekunden mit 15 % Verwundbarkeit. Tote Ziele, Nullschaden und fremde Begleiter lösen diese Passive nicht aus.

**Knochenball** behält die bezahlte 0,65-Sekunden-Ladephase und die vorhandenen Kosten/Abklingzeiten. Knochen strömen an der Hand/Stabspitze in einen sichtbaren Energiekern, die Kugel zieht eine längere artikulierte Spur und zerplatzt am ersten Gegner oder an der ersten Wand in einen Knochen-Burst. Ein Treffer setzt zusätzlich einen vier Sekunden langen Fluch mit 10 % Verwundbarkeit. Verfall und begrenzte kleine Giftlache bleiben. Die Ladezeichnung liegt nun über der Figur und verwendet die Stabposition des aktuellen Bildes.

Der Blutstrahl behält seine freigegebene Reichweite 5/6,5/8 Meter und seine bestehenden Ziel-, Heil- und Wandgrenzen.

## Waldmeister

Der bisherige Bestienmeister-Zweig heißt jetzt **Waldmeister**. IDs und investierte Talentpunkte bleiben gültig. Scharfschütze und Fallensteller bleiben eigene Zweige.

| Talent | Aktuelles Verhalten |
| --- | --- |
| Tiergefährte / Fass! | Dauerhafter Wolf, Bär oder Falke und Ansprungbefehl bleiben. |
| Dornenköder, ehemals Doppelschuss | 0,5 s Scharfschaltung, 2 m, 60/80/100 % Schaden, 1/1,4/1,8 s Fessel, 18 Ausdauer, 9 s Abklingzeit. |
| Glutdruckfalle, ehemals Jagdruf | 0,5 s Scharfschaltung, 3,5 m, 100/120/140 % Schaden. Echtes Feuerfeld für 5 s mit 20 % Heldengrundschaden pro Sekunde; 25 Ausdauer, 16 s Abklingzeit. |
| Wurzelgrund, ehemals Raubtiersprung | 3,5 m, 6 s, 20/25/30 % Schaden pro Sekunde, Gift und 45 % Verlangsamung; 24 Ausdauer, 16 s Abklingzeit. |
| R Urwürmer | Giftschlund und Glutschlund für genau 15 s, 55 Ausdauer, 60 s Abklingzeit. Der dauerhafte Begleiter bleibt. |

Fallen erhalten acht echte bewegliche Holz-/Metallzähne aus vorhandener 0x72-Pfeilgrafik, einen Rig-Hub und eine Auslösepose. Auslösen und Schaden prüfen Wände. Sie erhalten keine neuen Akteursgrafiken.

Die Würmer wurden nach konkreter Entwurfsfreigabe des Nutzers am 03.11. übernommen. Je acht getrennte Masken, echte Körperteil-HP, vitaler Kopf/Rumpf, abtrennbarer Kiefer und verzögerte Segment-/Schwanzbewegung. Native Grafik **32×40**, hartes Alpha, zwanzig Farben und ganzzahlige 2×-Darstellung. Die Quellen bleiben erhalten.

Beide spucken alle 2,6 s auf ihr aktuelles Ziel bis sieben Meter. Der 0,45 s lange Flug endet vor Wänden. Erst die Landung erzeugt ein vorhandenes Gift- bzw. Feuerfeld: **3 m Radius**, fünf Sekunden, 20 % Heldengrundschaden pro Sekunde. Maximal drei lebende Quellen je Art/Besitzer; die älteste vergeht zuerst. Keine neue Pfützen-Zeichenlogik. Ultimate-Stufe 2 gibt 25 % mehr Wurmleben, Stufe 3 zusätzlich 25 % stärkere Felder.

## Dash, Aggro und Icons

Die bestehenden Elementreaktionen bleiben aktiv: Treffen etwa Gift- und Feuerfelder aufeinander, können sie reagieren und früher enden. Die fünf Sekunden gelten für eine ungestörte Quelle.

Shift weicht bei allen vier Klassen drei Meter in Lauf-/Blickrichtung aus; Wände stoppen den Weg. Magier, Schwertkämpfer und Nekromant: eine Ladung, vier Sekunden Wiederaufladung, 0,25 s Unverwundbarkeit. Der vorhandene Schützen-Dash behält seine zwei Ladungen und 0,4 s Unverwundbarkeit bei vier Sekunden Wiederaufladung pro Ladung. Halten wiederholt den Dash nicht. Die vorherigen Shift-Blocks der drei Klassen wurden gemäß Nutzerwunsch ersetzt.

Alle Begleiter halten ihr lebendes Ziel, auch wenn der Spieler etwas anderes angreift oder wegläuft. Nach dessen Tod wählen sie erreichbare wache Überlebende im aktuellen Kampf, bis kein Ziel bleibt. Schlafende Gegner werden nicht durch diese Suche geweckt; Wandnavigation und Wandprüfungen bleiben Pflicht. Dieselbe Regel gilt für die Story-/Relikt-Begleiter.

Die gemeinsamen Talenticons werden einmalig mit **48×48 nativen Pixeln** gebaut. Zusätzliche Facetten, Innenkanten, Schatten und Rahmen statt bloßer Vergrößerung der alten 18-Pixel-Textur; Weltgrafik und Nearest-Filter bleiben unverändert. Das Wurm-Ultimate-Icon verwendet beide freigegebenen Sprites.

## Daten und Grenzen

`talents.json`: bestehende Talentschemata plus `curse_aura`, `forest_worms`, Fallen-`arm_s` in Sekunden, `ground_pool` mit Stil/Radius in Metern/Lebensdauer/DPS/Status. `pet.forest_worms`: HP, Angriffsintervall, Flugzeit, Feldradius/-dauer/-DPS und Quellengrenze. `necromancer_rules.json`: `ultimate_monster.on_hit_curse` mit Dauer und Verwundbarkeit. `necro_spell_rigs.json.motion`: vertikale Fluchbewegung und begrenzte Knochen-Partikelzahlen. `companion_rigs.json`: inklusive Quellrechtecke, Eltern, Gelenke und HP-Gewichte. Neues `forest_trap_rig.json` nutzt dasselbe Maskenschema. Wiederholbare Migration: `scripts/apply_necro_forest_data.cjs`; nativer Import: `scripts/import_forest_worms.gd`.

Regelsatz **24**, Protokoll **4**. Kontrollen/Quellen und reale GPU-Aufnahmen unter `production/qa/evidence/necro-forest-rework/README.md`. Alte 40-Fähigkeiten-Galerie und frühere Netzwerk-/Leistungswerte dokumentieren ältere Revisionen. Diese Arbeit ist keine neue Kampagnen-, LAN- oder Leistungsabnahme; Spielgefühl und langfristige Balance bleiben vom Nutzer zu beurteilen.
