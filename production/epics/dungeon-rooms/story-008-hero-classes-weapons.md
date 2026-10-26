# Story 008: Heldenklassen, Klassen-Fähigkeiten und Waffen

> **Epic**: Dungeon aus Raumvorlagen
> **Status**: In Progress
> **Type**: Feature + UI
> **Last Updated**: 2026-10-26

## Context

Wunsch des Projektinhabers vom 26.10.2026:
- Vor dem Lauf wählt man einen Helden: Bogenschütze, Magier oder Schwertkämpfer.
- Der Schwertkämpfer kann nur Schwerthiebe machen.
- Die Fähigkeiten aus dem EXP-Sammeln richten sich nach der Klasse.
- In manchen Räumen liegen Waffen. Auch ein Schwertkämpfer kann zum Beispiel einen Stab nehmen und wechseln, aber nur, wenn er selbst wählt.

Die Regeln liegen zentral in `src/player/loadout.gd`, alle Werte in `balance.json` (`classes`, `weapons`, `abilities`, `loot`).

## Acceptance Criteria

- [x] **Heldenwahl:** Nach Story- oder Endlos-Modus erscheinen drei Heldenkarten mit animiertem Sprite, Name, Beschreibung, Herzen und Startwaffe. Im Mehrspieler-Lobby gibt es den Knopf „KLASSE: … ►“.
- [x] **Klassen:**

  | Klasse | Herzen | Startwaffe | Angriff |
  |---|---|---|---|
  | Schwertkämpfer | 5 | Schwert | Nahkampf-Hieb im Kegel vor sich, mit sichtbarem Schwung |
  | Bogenschütze | 4 | Kurzbogen | Pfeile; Werte wie der bisherige Standardschuss |
  | Magier | 3 | Smaragdstab | Kugeln, die beim Aufprall explodieren (halber Schaden im Umkreis) |

- [x] **Klassen-Fähigkeiten:** Bei jedem Level-Up erscheinen drei Karten aus dem eigenen Klassen-Pool. Gewählt wird mit 1, 2, 3 oder per Klick, mehrere Level-Ups stauen sich. Maximal ausgebaute Fähigkeiten werden nicht mehr angeboten.
  - **Schwertkämpfer:** Schwerer Hieb, Flinke Klinge, Wirbelklinge (trifft rundum), Klingenwelle, Parade (zerschlägt Geschosse), Eiserne Haut, Blutdurst.
  - **Bogenschütze:** Mehrfachschuss, Durchschlag, Schnellfeuer, Adlerauge, Präzision (kritische Treffer), Leichtfuß, Abpraller.
  - **Magier:** Fokus, Arkane Eile, Nova (größere Explosion), Suchende Kugeln, Spaltung, Arkanschild (blockt alle 12 s einen Treffer).
- [x] **Waffen:** Schwert, Prunkklinge, Kurzbogen, Langbogen (durchbohrt), Smaragdstab und Glutstab, jeweils mit 0x72-Sprite in der Hand.
  - **Wo:** In jeder Schatzkammer liegt eine Waffe, in geräumten Räumen mit 30 % Chance.
  - **Aufheben (E):** Die Waffe kommt in einen freien Platz (2 Plätze). Sind beide voll, tauscht man die gehaltene Waffe gegen die vom Boden; die alte bleibt dort liegen.
  - **Wechseln (Q):** zwischen den beiden getragenen Waffen.
  - **Ohne Zwang:** Nichts wird automatisch aufgehoben.
- [x] **Fähigkeiten bleiben beim Waffenwechsel erhalten.** Sie wirken auf passende Waffen: Schwert-Fähigkeiten auf Nahkampf, Schuss-Fähigkeiten auf Projektile. Perks ändern jetzt Modifikatoren und gehen beim Wechsel ebenfalls nicht verloren.
- [x] **HUD:** Waffenplätze unter den Herzen, die gehaltene Waffe ist gold umrandet. Die Werte-Spalte folgt der gehaltenen Waffe, Nahkampf zeigt die Reichweite. Am Boden zeigt eine Waffe in der Nähe „[E] NAME“.

## Test Evidence

Ausgeführt am 26.10.2026:
- `LOADOUT checked=15 failures=0`:
  - Startwerte der Klassen
  - Aufheben in den freien Platz, Tausch bei vollen Händen, Wechsel mit Q
  - Angebote nur aus dem eigenen Pool, nie über das Maximum
  - Wirkung von Fokus, Flinker Klinge und Eiserner Haut; Fähigkeiten bleiben beim Wechsel
  - Kein Angebot mehr, wenn alles ausgebaut ist
- `GAME_RULES checked=176`, darin:
  - Der Schwerthieb trifft vorn, aber nicht hinten oder zu weit weg; Wirbelklinge trifft rundum, Parade zerschlägt Geschosse.
  - Ein Durchschlag-Pfeil trifft zwei Gegner; Mehrfachschuss feuert einen Extrapfeil; die Magierkugel explodiert.
  - Aufheben, Tausch und Wechsel; Schatzkammer-Waffe; Level-Up-Angebot und Wahl; Arkanschild.
- `ONLINE checked=22` (Heldenwahl startet den gewählten Modus). Alle übrigen Testsammlungen sind grün.
- Bilder im echten Spiel: Heldenwahl, Schwerthieb, Level-Up-Karten, Magierkugeln, Waffen am Boden und aufgehobener Langbogen in `production/qa/evidence/story-008-hero-classes-weapons/`.

**Offen:**
- Die Balance der Klassen ist nicht angespielt.
- Es gibt keine eigene Grafik für die Hiebe; Schwung und Bogen sind gezeichnet.
- Eigene Angriffsanimationen der Helden fehlen, weil die 0x72-Helden keine Angriffsbilder haben.
