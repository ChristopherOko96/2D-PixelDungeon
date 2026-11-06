# Krypta (Kapitel 1) durchgespielt, 06.11.2026

Werkzeug: `tools/krypta_dungeon/playthrough.gd` spielt im echten Spiel von Etage 1 bis zum letzten Portal. Der Held
geht nur dorthin, wohin ein Weg führt (Wände, geschlossene Tore, feste Teile und Gruben sperren), betritt jeden
erreichbaren Raum, besiegt die Gegner mit eigenen Treffern, nimmt Schlüssel, öffnet Tore, besiegt den Boss und nimmt
das Portal. Er kann nicht sterben. Rätselräume lässt er aus (sie sind freiwillig), damit geprüft ist, dass man ohne
sie durchkommt.

## Letzte Runde (alle Fehlerbehebungen drin, 4 Spiele gleichzeitig)

```
archer run 163865085: KAPITEL 1 GESCHAFFT nach 10 Etagen (99 s Rechenzeit), Lebensgrenze 12, Treffer eingesteckt 1
archer run 1897044480: KAPITEL 1 GESCHAFFT nach 10 Etagen (100 s Rechenzeit), Lebensgrenze 12, Treffer eingesteckt 1
mage run 1199431815: KAPITEL 1 GESCHAFFT nach 10 Etagen (90 s Rechenzeit), Lebensgrenze 10, Treffer eingesteckt 0
mage run 813384216: KAPITEL 1 GESCHAFFT nach 10 Etagen (97 s Rechenzeit), Lebensgrenze 10, Treffer eingesteckt 0
necromancer run 1244732004: KAPITEL 1 GESCHAFFT nach 10 Etagen (81 s Rechenzeit), Lebensgrenze 11, Treffer eingesteckt 0
necromancer run 608242626: KAPITEL 1 GESCHAFFT nach 10 Etagen (106 s Rechenzeit), Lebensgrenze 11, Treffer eingesteckt 2
swordsman run 1984809553: KAPITEL 1 GESCHAFFT nach 10 Etagen (109 s Rechenzeit), Lebensgrenze 14, Treffer eingesteckt 0
swordsman run 300823804: KAPITEL 1 GESCHAFFT nach 10 Etagen (86 s Rechenzeit), Lebensgrenze 14, Treffer eingesteckt 0
```

## Etagen der letzten Runde

```
PT archer run 1897044480 E1: durch: 9 Kämpfe, 72 Gegner, 3 Schlüssel, 3 Tore, 0 Rätseltore, Rätselräume []
PT archer run 1897044480 E2: durch: 3 Kämpfe, 22 Gegner, 2 Schlüssel, 2 Tore, 0 Rätseltore, Rätselräume ["Staubkammer"]
PT archer run 1897044480 E3: durch: 3 Kämpfe, 23 Gegner, 2 Schlüssel, 2 Tore, 0 Rätseltore, Rätselräume ["Gebeinkammer", "Gruftkrypta"]
PT archer run 1897044480 E4: durch: 9 Kämpfe, 62 Gegner, 3 Schlüssel, 3 Tore, 0 Rätseltore, Rätselräume []
PT archer run 1897044480 E5: durch: 7 Kämpfe, 48 Gegner, 3 Schlüssel, 3 Tore, 0 Rätseltore, Rätselräume ["Seelensaal"]
PT archer run 1897044480 E6: durch: 11 Kämpfe, 111 Gegner, 2 Schlüssel, 2 Tore, 0 Rätseltore, Rätselräume []
PT archer run 1897044480 E7: durch: 7 Kämpfe, 52 Gegner, 3 Schlüssel, 3 Tore, 0 Rätseltore, Rätselräume ["Totenwachtkrypta"]
PT archer run 1897044480 E8: durch: 10 Kämpfe, 112 Gegner, 3 Schlüssel, 3 Tore, 0 Rätseltore, Rätselräume ["Grabeshof"]
PT archer run 1897044480 E9: durch: 13 Kämpfe, 123 Gegner, 3 Schlüssel, 3 Tore, 0 Rätseltore, Rätselräume []
PT archer run 1897044480 E10: durch: 15 Kämpfe, 142 Gegner, 3 Schlüssel, 3 Tore, 0 Rätseltore, Rätselräume []
PT archer run 163865085 E1: durch: 7 Kämpfe, 59 Gegner, 3 Schlüssel, 3 Tore, 0 Rätseltore, Rätselräume ["Kerzengalerie"]
PT archer run 163865085 E2: durch: 9 Kämpfe, 73 Gegner, 2 Schlüssel, 2 Tore, 0 Rätseltore, Rätselräume ["Schädelkrypta"]
PT archer run 163865085 E3: durch: 10 Kämpfe, 81 Gegner, 4 Schlüssel, 4 Tore, 0 Rätseltore, Rätselräume ["Staubsaal"]
PT archer run 163865085 E4: durch: 9 Kämpfe, 58 Gegner, 2 Schlüssel, 2 Tore, 0 Rätseltore, Rätselräume ["Moderkrypta"]
PT archer run 163865085 E5: durch: 7 Kämpfe, 48 Gegner, 2 Schlüssel, 2 Tore, 0 Rätseltore, Rätselräume ["Sargzelle", "Aschekammer"]
PT archer run 163865085 E6: durch: 10 Kämpfe, 98 Gegner, 3 Schlüssel, 3 Tore, 0 Rätseltore, Rätselräume ["Moderpforte", "Sarghalle"]
PT archer run 163865085 E7: durch: 9 Kämpfe, 68 Gegner, 3 Schlüssel, 3 Tore, 0 Rätseltore, Rätselräume []
PT archer run 163865085 E8: durch: 7 Kämpfe, 68 Gegner, 2 Schlüssel, 2 Tore, 0 Rätseltore, Rätselräume ["Totenwachtstiege"]
PT archer run 163865085 E9: durch: 9 Kämpfe, 104 Gegner, 3 Schlüssel, 3 Tore, 0 Rätseltore, Rätselräume ["Trauerhalle", "Gebeinhof"]
PT archer run 163865085 E10: durch: 10 Kämpfe, 86 Gegner, 3 Schlüssel, 3 Tore, 0 Rätseltore, Rätselräume ["Seelenkrypta", "Thronsaal"]
PT mage run 1199431815 E1: durch: 8 Kämpfe, 61 Gegner, 2 Schlüssel, 2 Tore, 0 Rätseltore, Rätselräume []
PT mage run 1199431815 E2: durch: 4 Kämpfe, 30 Gegner, 2 Schlüssel, 2 Tore, 0 Rätseltore, Rätselräume ["Schädelkreuz"]
PT mage run 1199431815 E3: durch: 10 Kämpfe, 81 Gegner, 3 Schlüssel, 3 Tore, 0 Rätseltore, Rätselräume ["Gebeingalerie"]
PT mage run 1199431815 E4: durch: 13 Kämpfe, 96 Gegner, 3 Schlüssel, 3 Tore, 0 Rätseltore, Rätselräume []
PT mage run 1199431815 E5: durch: 9 Kämpfe, 62 Gegner, 2 Schlüssel, 2 Tore, 0 Rätseltore, Rätselräume []
PT mage run 1199431815 E6: durch: 8 Kämpfe, 67 Gegner, 3 Schlüssel, 3 Tore, 0 Rätseltore, Rätselräume ["Sargsaal", "Kapellengruft"]
PT mage run 1199431815 E7: durch: 5 Kämpfe, 34 Gegner, 2 Schlüssel, 2 Tore, 0 Rätseltore, Rätselräume ["Kettensaal", "Trauergrube"]
PT mage run 1199431815 E8: durch: 9 Kämpfe, 97 Gegner, 4 Schlüssel, 4 Tore, 0 Rätseltore, Rätselräume ["Gebeingruft", "Gebeinhalle"]
PT mage run 1199431815 E9: durch: 13 Kämpfe, 135 Gegner, 3 Schlüssel, 3 Tore, 0 Rätseltore, Rätselräume ["Trauerstiege"]
PT mage run 1199431815 E10: durch: 3 Kämpfe, 22 Gegner, 2 Schlüssel, 2 Tore, 0 Rätseltore, Rätselräume ["Verdammnisgruft", "Schattengruft"]
PT mage run 813384216 E1: durch: 10 Kämpfe, 78 Gegner, 3 Schlüssel, 3 Tore, 0 Rätseltore, Rätselräume ["Grabhalle"]
PT mage run 813384216 E2: durch: 9 Kämpfe, 82 Gegner, 3 Schlüssel, 3 Tore, 0 Rätseltore, Rätselräume ["Gebeinhof"]
PT mage run 813384216 E3: durch: 8 Kämpfe, 63 Gegner, 3 Schlüssel, 3 Tore, 0 Rätseltore, Rätselräume []
PT mage run 813384216 E4: durch: 8 Kämpfe, 52 Gegner, 2 Schlüssel, 2 Tore, 0 Rätseltore, Rätselräume []
PT mage run 813384216 E5: durch: 9 Kämpfe, 60 Gegner, 3 Schlüssel, 3 Tore, 0 Rätseltore, Rätselräume ["Weihesaal"]
PT mage run 813384216 E6: durch: 8 Kämpfe, 82 Gegner, 4 Schlüssel, 4 Tore, 0 Rätseltore, Rätselräume ["Urnengang", "Gebetgruft"]
PT mage run 813384216 E7: durch: 6 Kämpfe, 50 Gegner, 3 Schlüssel, 3 Tore, 0 Rätseltore, Rätselräume []
PT mage run 813384216 E8: durch: 13 Kämpfe, 132 Gegner, 3 Schlüssel, 3 Tore, 0 Rätseltore, Rätselräume []
PT mage run 813384216 E9: durch: 13 Kämpfe, 133 Gegner, 3 Schlüssel, 3 Tore, 0 Rätseltore, Rätselräume ["Gebeingalerie"]
PT mage run 813384216 E10: durch: 6 Kämpfe, 61 Gegner, 2 Schlüssel, 2 Tore, 0 Rätseltore, Rätselräume ["Seelengalerie", "Thronkrypta"]
PT necromancer run 1244732004 E1: durch: 7 Kämpfe, 57 Gegner, 4 Schlüssel, 4 Tore, 0 Rätseltore, Rätselräume ["Staubgalerie"]
PT necromancer run 1244732004 E2: durch: 5 Kämpfe, 45 Gegner, 3 Schlüssel, 3 Tore, 0 Rätseltore, Rätselräume ["Gruftgewölbe"]
PT necromancer run 1244732004 E3: durch: 3 Kämpfe, 20 Gegner, 2 Schlüssel, 2 Tore, 0 Rätseltore, Rätselräume ["Knochenkammer"]
PT necromancer run 1244732004 E4: durch: 8 Kämpfe, 53 Gegner, 2 Schlüssel, 2 Tore, 0 Rätseltore, Rätselräume []
PT necromancer run 1244732004 E5: durch: 7 Kämpfe, 46 Gegner, 2 Schlüssel, 2 Tore, 0 Rätseltore, Rätselräume []
PT necromancer run 1244732004 E6: durch: 7 Kämpfe, 65 Gegner, 2 Schlüssel, 2 Tore, 0 Rätseltore, Rätselräume ["Aschegewölbe"]
PT necromancer run 1244732004 E7: durch: 15 Kämpfe, 119 Gegner, 3 Schlüssel, 3 Tore, 0 Rätseltore, Rätselräume []
PT necromancer run 1244732004 E8: durch: 3 Kämpfe, 29 Gegner, 2 Schlüssel, 2 Tore, 0 Rätseltore, Rätselräume ["Gebeinkreuz"]
PT necromancer run 1244732004 E9: durch: 12 Kämpfe, 130 Gegner, 3 Schlüssel, 3 Tore, 0 Rätseltore, Rätselräume ["Grabesgalerie", "Grabesgrube"]
PT necromancer run 1244732004 E10: durch: 6 Kämpfe, 51 Gegner, 2 Schlüssel, 2 Tore, 0 Rätseltore, Rätselräume []
PT necromancer run 608242626 E1: durch: 9 Kämpfe, 75 Gegner, 3 Schlüssel, 3 Tore, 0 Rätseltore, Rätselräume ["Moderzelle"]
PT necromancer run 608242626 E2: durch: 8 Kämpfe, 68 Gegner, 2 Schlüssel, 2 Tore, 0 Rätseltore, Rätselräume []
PT necromancer run 608242626 E3: durch: 9 Kämpfe, 68 Gegner, 3 Schlüssel, 3 Tore, 0 Rätseltore, Rätselräume ["Knochenkapelle", "Moderkammer"]
PT necromancer run 608242626 E4: durch: 7 Kämpfe, 42 Gegner, 3 Schlüssel, 3 Tore, 0 Rätseltore, Rätselräume ["Gebetgrube", "Sargsaal"]
PT necromancer run 608242626 E5: durch: 8 Kämpfe, 60 Gegner, 3 Schlüssel, 3 Tore, 0 Rätseltore, Rätselräume []
PT necromancer run 608242626 E6: durch: 12 Kämpfe, 113 Gegner, 3 Schlüssel, 3 Tore, 0 Rätseltore, Rätselräume []
PT necromancer run 608242626 E7: durch: 9 Kämpfe, 69 Gegner, 2 Schlüssel, 2 Tore, 0 Rätseltore, Rätselräume ["Klagegang"]
PT necromancer run 608242626 E8: durch: 10 Kämpfe, 102 Gegner, 2 Schlüssel, 2 Tore, 0 Rätseltore, Rätselräume ["Totenwachtstiege", "Kettennische"]
PT necromancer run 608242626 E9: durch: 13 Kämpfe, 131 Gegner, 3 Schlüssel, 3 Tore, 0 Rätseltore, Rätselräume ["Runensaal", "Reliquiengewölbe"]
PT necromancer run 608242626 E10: durch: 14 Kämpfe, 125 Gegner, 3 Schlüssel, 3 Tore, 0 Rätseltore, Rätselräume ["Verdammnisstiege"]
PT swordsman run 1984809553 E1: durch: 9 Kämpfe, 75 Gegner, 3 Schlüssel, 3 Tore, 0 Rätseltore, Rätselräume ["Moderkreuz"]
PT swordsman run 1984809553 E2: durch: 9 Kämpfe, 73 Gegner, 3 Schlüssel, 3 Tore, 0 Rätseltore, Rätselräume []
PT swordsman run 1984809553 E3: durch: 8 Kämpfe, 65 Gegner, 3 Schlüssel, 3 Tore, 0 Rätseltore, Rätselräume ["Gruftkammer", "Gruftgruft"]
PT swordsman run 1984809553 E4: durch: 12 Kämpfe, 86 Gegner, 3 Schlüssel, 3 Tore, 0 Rätseltore, Rätselräume []
PT swordsman run 1984809553 E5: durch: 10 Kämpfe, 68 Gegner, 3 Schlüssel, 3 Tore, 0 Rätseltore, Rätselräume ["Seelengang"]
PT swordsman run 1984809553 E6: durch: 13 Kämpfe, 129 Gegner, 3 Schlüssel, 3 Tore, 0 Rätseltore, Rätselräume []
PT swordsman run 1984809553 E7: durch: 3 Kämpfe, 20 Gegner, 2 Schlüssel, 2 Tore, 0 Rätseltore, Rätselräume []
PT swordsman run 1984809553 E8: durch: 14 Kämpfe, 141 Gegner, 4 Schlüssel, 4 Tore, 0 Rätseltore, Rätselräume ["Grabeskrypta", "Trauerkreuz"]
PT swordsman run 1984809553 E9: durch: 16 Kämpfe, 162 Gegner, 3 Schlüssel, 3 Tore, 0 Rätseltore, Rätselräume []
PT swordsman run 1984809553 E10: durch: 12 Kämpfe, 109 Gegner, 3 Schlüssel, 3 Tore, 0 Rätseltore, Rätselräume ["Schattenzelle"]
PT swordsman run 300823804 E1: durch: 8 Kämpfe, 57 Gegner, 3 Schlüssel, 3 Tore, 0 Rätseltore, Rätselräume []
PT swordsman run 300823804 E2: durch: 11 Kämpfe, 91 Gegner, 3 Schlüssel, 3 Tore, 0 Rätseltore, Rätselräume []
PT swordsman run 300823804 E3: durch: 5 Kämpfe, 35 Gegner, 4 Schlüssel, 4 Tore, 0 Rätseltore, Rätselräume ["Schädelgalerie", "Grabgalerie"]
PT swordsman run 300823804 E4: durch: 4 Kämpfe, 25 Gegner, 2 Schlüssel, 2 Tore, 0 Rätseltore, Rätselräume ["Kapellenkapelle", "Moderhof"]
PT swordsman run 300823804 E5: durch: 9 Kämpfe, 58 Gegner, 4 Schlüssel, 4 Tore, 0 Rätseltore, Rätselräume ["Seelenkreuz"]
PT swordsman run 300823804 E6: durch: 10 Kämpfe, 96 Gegner, 3 Schlüssel, 3 Tore, 0 Rätseltore, Rätselräume ["Weihesaal"]
PT swordsman run 300823804 E7: durch: 16 Kämpfe, 117 Gegner, 3 Schlüssel, 3 Tore, 0 Rätseltore, Rätselräume []
PT swordsman run 300823804 E8: durch: 9 Kämpfe, 98 Gegner, 5 Schlüssel, 5 Tore, 0 Rätseltore, Rätselräume ["Gebeingruft", "Gebeinkrypta"]
PT swordsman run 300823804 E9: durch: 4 Kämpfe, 43 Gegner, 2 Schlüssel, 2 Tore, 0 Rätseltore, Rätselräume ["Trauerkrypta", "Runennische"]
PT swordsman run 300823804 E10: durch: 7 Kämpfe, 70 Gegner, 2 Schlüssel, 2 Tore, 0 Rätseltore, Rätselräume ["Fluchhalle"]
```

## Gefunden und behoben

1. Die Karte und die Tore stürzten bei raumeigenen Schlüsseln ab ("15A" in Sprungrätseln mit Schlüssel):
   `hell_game.gd` `_door_color`, `_draw_gate`, Schlüssel am Boden. Test: `tests/room_key_map_test.gd`.
2. Ein Schlüssel aus einem gesäuberten Raum fiel dorthin, wo das letzte Monster starb: in die Wand, über eine Grube
   oder zwischen Fallgruben. Zwischen Fallgruben stürzte jeder, der ihn holen wollte, zurück an den Start: die Etage
   war nicht zu schaffen (Lauf 842885991, Etage 4). Jetzt liegt er immer auf freiem Boden des Raums, weg von
   Fallgruben. Test: `tests/room_key_drop_test.gd`.

## Frühere Runden

Vor Fix 2 saßen 9 von 29 Läufen fest, alle mit demselben Bild (der Held stürzte beim Schlüssel und stand wieder am
Etagenstart). Danach durchgespielt: jede dieser Etagen-Folgen ganz von Etage 1, nur die des Magiers (276847388) ab
Etage 10, wo er festsaß:

```
swordsman run 1553339370: KAPITEL 1 GESCHAFFT nach 10 Etagen (99 s Rechenzeit), Lebensgrenze 14, Treffer eingesteckt 0
swordsman run 336541885: KAPITEL 1 GESCHAFFT nach 10 Etagen (75 s Rechenzeit), Lebensgrenze 14, Treffer eingesteckt 0
swordsman run 688958066: KAPITEL 1 GESCHAFFT nach 10 Etagen (90 s Rechenzeit), Lebensgrenze 14, Treffer eingesteckt 0
swordsman run 842885991: KAPITEL 1 GESCHAFFT nach 10 Etagen (91 s Rechenzeit), Lebensgrenze 14, Treffer eingesteckt 0
necromancer run 2124718396: KAPITEL 1 GESCHAFFT nach 10 Etagen (92 s Rechenzeit), Lebensgrenze 11, Treffer eingesteckt 1
archer run 1309489921: KAPITEL 1 GESCHAFFT nach 10 Etagen (111 s Rechenzeit), Lebensgrenze 12, Treffer eingesteckt 0
swordsman run 1764638066: KAPITEL 1 GESCHAFFT nach 10 Etagen (100 s Rechenzeit), Lebensgrenze 14, Treffer eingesteckt 0
swordsman run 171385097: KAPITEL 1 GESCHAFFT nach 10 Etagen (81 s Rechenzeit), Lebensgrenze 14, Treffer eingesteckt 0
```
