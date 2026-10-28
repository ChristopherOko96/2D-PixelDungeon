# Boss-Fähigkeiten (umgesetzt, 28.10.2026)

Wunsch des Nutzers: Jeder Boss bekommt mindestens 7 neue Fähigkeiten. Bestehend:
Leerenrufer (Strahl, Seelensalve, Beschwörung), Nebenbosse (Stampfer, Brüll-Ring).
Jede Fähigkeit hat eine Vorwarnung (Telegraph) und einen Weg, ihr auszuweichen.
Schaden in Halbherzen (2 = ein Herz). Kennungen für dein Feedback, z. B. „L3: länger“.

## Leerenrufer (Etage 10)

| Kennung | Name | Was passiert | Ausweichen |
|---|---|---|---|
| L1 | Leerenriss | Unter jedem Spieler öffnet sich ein violetter Riss (0,8 s Warnung), dann schießt eine Leerensäule hoch. 2 Schaden. | Aus dem Riss laufen. |
| L2 | Seelenfessel | Eine Kette aus Seelen schnappt nach dem nächsten Spieler: 1,5 s verlangsamt und zum Boss gezogen. | Kette ist ein Geschoss, Wände blocken sie. |
| L3 | Schattenschritt | Der Boss löst sich in Leere auf und taucht an anderer Stelle im Raum auf; am alten Platz bleibt 4 s eine Leerenpfütze (1 Schaden/s). | Pfütze meiden. |
| L4 | Leerenspirale | Drei Arme aus Seelenschädeln drehen sich 4 s lang aus ihm heraus. | Mit der Drehung mitlaufen. |
| L5 | Knochenkreis | Ein Ring aus Knochenspitzen wächst nach außen, mit einer Lücke. 2 Schaden. | Durch die Lücke. |
| L6 | Verschlingen | Er saugt 2 s lang alle Spieler an, dann Explosion im Nahbereich. 4 Schaden. | Gegen den Sog weglaufen. |
| L7 | Zorn der Leere | Unter 50 % LP: einmal Brüllen, danach schnellere Angriffe und ein Doppelstrahl (zwei Strahlen im 40°-Winkel). | Zwischen den Strahlen bleiben. |

## Moderkoloss (Etage 3)

| Kennung | Name | Was passiert | Ausweichen |
|---|---|---|---|
| M1 | Faulatem | Giftkegel nach vorn, Gift 3 s (1 Schaden/s). | Hinter ihn laufen. |
| M2 | Moderklumpen | Wirft 3 Klumpen im Bogen; wo sie landen, bleibt 5 s eine Giftlache. | Markierte Landestellen meiden. |
| M3 | Sturmlauf | Rote Vorwarnlinie, dann rennt er quer durch den Raum (3 Schaden). Trifft er eine Wand, ist er 1,5 s benommen. | Seitlich ausweichen, dann zuschlagen. |
| M4 | Erdbeben | Stampfer schickt eine Linie aus Erdstößen in Blickrichtung. 2 Schaden. | Nicht in der Linie stehen. |
| M5 | Madenbrut | Ruft 3 Mini-Zombies. | Brut früh erledigen. |
| M6 | Packen | Packt einen Spieler in Reichweite und wirft ihn gegen die Wand. 3 Schaden. | Abstand halten, wenn er die Arme hebt. |
| M7 | Fleischregen | Unter 30 % LP platzt Fleisch von ihm ab: ein Ring aus Brocken. 2 Schaden. | Ring mit Lücken, rauslaufen. |

## Frostleiche (Etage 6)

| Kennung | Name | Was passiert | Ausweichen |
|---|---|---|---|
| F1 | Eissplitter | Fächer aus 5 Eisspitzen, verlangsamen 2 s. 2 Schaden. | Zwischen die Spitzen. |
| F2 | Frostnova | Eisring um sie herum, friert Spieler im Nahbereich 1 s ein. | Bei blauem Leuchten weg. |
| F3 | Eiswand | Drei Eisblöcke wachsen als Hindernisse aus dem Boden (zerstörbar). | Umgehen oder zerschlagen. |
| F4 | Hagel | 5 markierte Kreise, nach 1 s fallen Eisbrocken. 2 Schaden. | Kreise verlassen. |
| F5 | Eisgleiten | Sie rutscht auf einer Eisbahn auf den Spieler zu; die Bahn bleibt 4 s rutschig. | Quer zur Bahn ausweichen. |
| F6 | Eispanzer | 4 s nur halber Schaden; danach platzt der Panzer in Splitter. | Abwarten, Splittern ausweichen. |
| F7 | Frosterweckung | 2 Eis-Zombies steigen aus dem Boden. | Früh erledigen. |

## Knochenkoloss (Etage 9)

| Kennung | Name | Was passiert | Ausweichen |
|---|---|---|---|
| K1 | Knochenspeere | Wirft 3 Speere, die durch Spieler hindurchfliegen. 2 Schaden. | Seitlich ausweichen. |
| K2 | Spitzenlinie | Knochenspitzen brechen in einer Linie aus dem Boden. 2 Schaden. | Linie verlassen. |
| K3 | Knochenwirbel | Dreht sich 2 s mit ausgestrecktem Arm. 2 Schaden. | Abstand halten. |
| K4 | Schädelhagel | Wirft 4 hüpfende Schädel, die an Wänden abprallen. 1 Schaden. | Prallbahn lesen. |
| K5 | Knochenkäfig | Ein Käfig sperrt einen Spieler 2 s ein (zerstörbar, Mitspieler können helfen). | Käfig zerschlagen. |
| K6 | Wiederaufbau | Einmal pro Kampf: Bei 0 LP fällt er auseinander und setzt sich nach 3 s mit 30 % LP wieder zusammen, wenn sein Schädel nicht zerstört wird. | Schädel zerschlagen, solange er liegt. |
| K7 | Knochenlegion | Ruft 4 Skelette (Schwert und Schild). | Früh erledigen. |

## Gemeinsame Regeln

- Bosse wechseln ihre Angriffe: jede Fähigkeit hat nach dem Einsatz eine eigene Abklingzeit, die Wahl ist gewichtet zufällig.
- Teile sperren passende Fähigkeiten (Arm ab: kein Packen, kein Sturmlauf, kein Wirbel; kein Auge: kein Doppelstrahl).
- Alle Werte stehen in `assets/data/combat_boss_moves.json`, damit wir sie nach dem Spielen nachstellen können.
- Wut: Unter der Wut-Schwelle brüllt der Boss einmal, danach laden seine Fähigkeiten 40 % schneller (`rage.cooldown_scale` 0,6).

## Umsetzungsstand

- Alle 28 Boss-Fähigkeiten oben sind eingebaut, dazu neue Angriffe für normale Gegner: Skelett (Ausweichsprung, Wirbelhieb), Skelettschütze (Pfeilsalve, Brandpfeil), Skelettwache (Schildstoß, Knochenwurf), Nekromant (Seelenfluch, Knochenschild), kleiner Zombie (Anspringen, Spucken), Eiszombie (Frostatem, Eisfläche), Leerenbomber (Leerensprung).
- Der Strahl des Leerenrufers geht jetzt quer über die Karte, bis er eine Wand trifft (`balance.json` beam `range` 0 = bis zur Wand).
- Spielerzustände (Gift, Brand, Frost, Verlangsamung, Ausrutschen, Stille) stehen in `src/combat/player_effects.gd`; Eiswände und Knochenkäfige sind zerschlagbare Blöcke (`src/dungeon/chests.gd` `add_block`).
- Technik: `src/combat/boss_moves.gd` (Host: Auswahl, Warnung, Auslösen, Zonen), `src/vfx/boss_fx.gd` (Zeichnen). Test: `tests/boss_moves_test.gd`. Belege: `production/qa/evidence/boss-moves/` (`scripts/capture_boss_moves.gd`).
