# Diener: Beschwörungen, Blutmal und Blut-Ulti

01.11.2026, `codex/port-0x72-onto-main`; Godot 4.7.2 Compatibility.
Diese Nutzerkorrektur ersetzt die automatische Verwandlung bei 100 Blut und
den frei beschworenen Ersatzkoloss durch eine blutabhängige aktive Ulti.

## Aktueller Ablauf

1. **1 Knochenkrieger:** eigene bezahlte dauerhafte Beschwörung; Lernen allein
   beschwört ihn nicht mehr. Er trägt das vorhandene Schwert-/Schild-Rig.
2. **2 Knochenschützen:** genau zwei separate Bogenschützen für 15 Sekunden,
   neben dem Krieger. Tod oder Ablauf löst einmalig eine tatsächliche
   Leichenexplosion aus: 60 % Grundschaden in 1,8 m, mit Wandprüfung. Die
   Rig-Fragmente stammen aus dem vorhandenen Skelett.
3. **3 Blutmal:** markiert Gegner im Zielgebiet acht Sekunden. Markierte
   normale Tote erzeugen große echte Blutpfützen (2,5 m Radius, zwölf Sekunden,
   maximal sechs aktive markierte Quellen pro Besitzer). Eine Quelle liefert
   einmalig 25 Blut. Bosse/feindliche Beschwörungen erzeugen keine Quellen;
   ein mehrfach gemeldeter Tod bezahlt nur einmal. Mehrere Spieler können
   denselben Toten nicht in mehrere Blutquellen verwandeln.
4. **4 Leichenexplosion:** vorhandene aktive Leichenexplosion bleibt verfügbar.
5. **R Knochenkoloss:** braucht einen lebenden Krieger und mindestens 50 Blut.
   100 Blut allein verwandeln ihn nicht. Die große Form verbraucht ihren
   vorhandenen Vorrat: 50 Blut = zehn Sekunden, 100 Blut = zwanzig Sekunden.
   Danach derselbe normale Krieger mit leerem Balken. Die erste Aufwertung
   verlängert diese Zeiten auf 15/30 Sekunden. Die Schützen bleiben erhalten.
6. **5/6:** normal Schildschlag/Knochenschrei, groß Stampfen/Klingensturm.

Der Krieger absorbiert echte Quellen automatisch und geht zwischen Kämpfen
zu sichtbarem Blut innerhalb von sieben Metern. Seine Kampfziele behalten
Vorrang. Keine neue Pfützendarstellung: `PoolPaint` und bestehende Medien
bleiben zuständig. Keine neuen Spritebilder oder Actor-Kataloge.

## Gezielte Prüfungen

| Test | Ergebnis | Log |
| --- | --- | --- |
| `necro_blood_cycle_test.gd` | 25 / 0 | `Logs/necro-cycle-green.log` |
| `necro_blood_curse_test.gd` | 39 / 0 | `Logs/necro-cycle-core.log` |
| `necro_branches_story_test.gd` | 34 / 0 | `Logs/necro-cycle-story.log` |
| `talent_combat_test.gd` | 360 / 0 | `Logs/necro-cycle-catalog.log` |
| `talent_pet_test.gd` | 40 / 0 | `Logs/necro-cycle-pets.log` |
| `necro_souls_aggro_test.gd` | 69 / 0 | `Logs/necro-cycle-aggro.log` |
| `necro_rig_link_test.gd` | 19 / 0 | `Logs/necro-cycle-link.log` |
| `soul_guardian_commands_test.gd` | 27 / 0 | `Logs/necro-cycle-guardian.log` |
| `necro_spell_rig_test.gd` | 43 / 0 | `Logs/necro-cycle-spellrig.log` |
| `session_protocol_test.gd` | 20 / 0 | `Logs/necro-cycle-protocol.log` |

Die neue Ablaufprüfung wurde vor den Änderungen ausgeführt:
`Logs/necro-cycle-red.log` meldete 14 fehlgeschlagene Anforderungen. Die
geänderten Tests für vorhandene Systeme beschwören ihren benötigten Krieger
jetzt ausdrücklich; der eigentliche Beschwörungstest beginnt ohne Begleiter.

Die erste echte Aufnahme entdeckte zusätzlich die 50-Blut-Grenze bei
beschleunigter Aufnahme in 60-Hz-Schritten: zwei Quellen ergaben intern
49,9999999999998 Blut. `Logs/necro-cycle-gpu-threshold-red.log` und der
nachgestellte fehlschlagende Test `Logs/necro-cycle-threshold-red.log` halten
das fest. Endlich verbrauchte Quellen werden nun auf die numerische
Meterpräzision abgeschlossen. Der gleiche Test besteht danach.

Erfolgreiche Logs wurden auf `SCRIPT ERROR` und fehlgeschlagene Assertions
geprüft. Game-Fixtures melden weiterhin die vorhandenen Teardown-Diagnosen
(6 ObjectDB-Instanzen / 2 verwendete Ressourcen); sauberer Teardown wird
nicht behauptet.

## Echte Darstellung

`scripts/capture_necro_blood_cycle.gd` nimmt den tatsächlichen Game-Viewport
und die tatsächliche Talentansicht auf. Log: `Logs/necro-cycle-gpu.log`.
Alle Aktionen bezahlen ihre normalen Kosten und beachten Abklingzeiten.
Die Fixture stellt einen legalen Level-30-Build, 100 anfängliche Seelen,
500-HP-Gegner, feste Geometrie und Debug-Schutz bereit. Sie tötet zwei markierte
Gegner gezielt über den echten Schadens-/Todespfad; keine Blutpunkte werden
direkt gutgeschrieben. Dies ist eine kontrollierte Präsentation, kein
erspielter Lauf oder Leistungs-/Abnahmetest.

- `game-0000.png`: anfangs kein kostenloser Krieger, neue vier Plätze.
- `game-0030.png`: eigener beschworener Krieger.
- `game-0090.png`: Krieger und genau zwei Bogenschützen.
- `game-0150.png`: Blutmal an realen Gegnern.
- `game-0181.png`, `game-0240.png`: markierte Tote und beginnende Blutaufnahme.
- `game-0440.png`: gespeicherte 50 Blut, weiterhin normale Form.
- `game-0480.png`, `game-0640.png`: R-Verwandlung und abnehmender Vorrat;
  beide Bogenschützen bleiben dabei bestehen.
- `game-0980.png`: beide Bogenschützen abgelaufen, ausgeschnittene Knochen
  ihrer einmaligen Explosion.
- `game-1080.png`: derselbe normale Krieger, Blut null.
- `talent-minion_1.png`, `talent-minion_5.png`, `talent-minion_9.png`,
  `talent-minion_14.png`: aktuelle Talentnamen, Texte und Belegung.

Die Titel der langen Schützenfähigkeit werden mit dem kurzen, vollständig
lesbaren Namen **Knochenschützen** angezeigt; der Beschreibungstext benennt
ausdrücklich die zwei Knochenbogenschützen.

## Netzwerk und Daten

Regelsatz **18**, Protokoll **4**, Nekromantenregelschema **3**. Talent- und
Nekromantendaten sind Teil der bestehenden Aufnahme-Fingerabdrücke. Host
prüft Beschwörung, Blutminimum und Aktivierung vor Seelen-/Cooldownausgaben.
Die bestehenden primitiven Begleitersnapshots übertragen den fallenden Balken.

`tests/necro_blood_network_smoke.ps1` startet zwei echte lokale ENet-Prozesse.
Beide prüfen gespeicherten vollen Balken in Normalform, Verwandlung durch
normale R-Eingabe, abnehmendes Blut sowie vorhandene Befehle/Blutstrahl.
Der aktuelle Lauf steht in `network-result.json`. Dies ist Loopback auf einem
PC, keine Zwei-Rechner-LAN-/WAN- oder Leistungsprüfung.

Vollständige Spielanleitung: `docs/NEKROMANT-DIENER-FLUCH.de.md`.
Quellstände: `source-hashes.json`. Kein Commit, Push oder Merge.
