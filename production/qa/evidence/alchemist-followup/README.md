# Flüssige Fallen, Dampfblindheit, Begleiterwechsel — 05.11.2026

Nutzerauftrag: Glaskapseln sollen echte erkennbare Pfützen erzeugen; Gegner im
Dampf sollen etwa drei Sekunden Sicht, Fokus und Verfolgung verlieren; erneutes
Wirken soll nach einer Wahl im Skillbaum wirklich den neuen Begleiter bringen.

## Fertiger Stand

- Gift ist eine deckende grüne Flüssigkeitsoberfläche mit Rand/Glanz. Die
  bisherige explizite Miasma-Darstellung von normalem Gift ist überschrieben;
  Gas bleibt ein getrenntes Medium. Wasser nutzt seine echte Flüssigkeit.
- Zündfallen legen zusätzlich reale Feuerflächen für vier Sekunden an,
  Frostfallen reale Eisflächen für fünf Sekunden. Tick/Frost/Wasser nutzen die
  vorhandenen besitzereigenen Medien, begrenzte Anzahl und tatsächliche Zellen.
  Nach Splitterbruch verhindert eine Sekunde Alchemie-Auftauzeit das sofortige
  Wiederanlegen desselben Frosts aus der darunterliegenden Eisfläche.
- Dampf und Rauch erneuern drei Sekunden `sight_blind_s`: Fokus, Threat und
  Tauntziele werden verworfen. Keine Verfolgung/neue gezielte Angriffe, bis der
  Timer endet. Danach wieder normale Wahrnehmung; kein allwissendes altes Ziel.
  Hitzewiderstand macht Augen nicht durchsichtig. Schäden, DOT und externe
  Körperkräfte laufen weiter. Bereits freigesetzte Angriffe bleiben bestehen.
- Lebender Wolf bleibt nach der Menüauswahl zunächst Wolf. Erneutes normales
  Beschwören ersetzt ihn durch den gewählten Bären, mit echten Kosten/CD.
  Gleiche Art erneut beschwören bleibt gesperrt, ebenso Beschwören ohne Kosten
  oder während der Abklingzeit. Die Ultimate-Würmer waren versehentlich nicht
  `summon_only`; das ist korrigiert. UI und Laufzeit bieten normale Begleiter.
- Ruleset 29; keine Änderung an der primitiven Protokollhülle.

Details/Schema: docs/FALLENALCHEMIST.de.md. Lokal, kein Commit/Push/Merge.

## Ergebnisse

| Suite | Prüfungen | Fehler |
|---|---:|---:|
| alchemist_followup_test | 15 | 0 |
| alchemist_followup_story_test | 24 | 0 |
| alchemist_traps_test | 57 | 0 |
| pool_field_test | 58 | 0 |
| element_exposure_test | 49 | 0 |
| aggro_test | 15 | 0 |
| talent_companion_test | 42 | 0 |
| talent_combat_test | 358 | 0 |
| session_protocol_test | 20 | 0 |

638 fokussierte Prüfungen bestanden. GPU-Fixture zusätzlich 9/0 Assertions.
Storychecks nutzen die tatsächlichen Hölle-/Frostgruft-/Krypta-Szenen, deren
Gasphysik und Bewegungsschritte. Die Begleiterprüfung öffnet den echten
Talentbildschirm und ruft dessen Auswahlhandler auf: Speichern, Signal,
Buildübernahme und bezahlter Cast; nicht bloß direktes Ersetzen eines Pet-Dicts.

Die finalen positiven Logs enthalten keine SCRIPT ERROR-/Parse-Fehler. Die
bekannten Headless-SceneTree-Abbaumeldungen bleiben: unter anderem 2251
ObjectDB-Instanzen, sechs Ressourcen und 887 Dummy-Renderer-Texturen in der
sechsfachen Story-Fixture. Keine Behauptung, diese alten Ressourcenprobleme
behoben zu haben. Die ältere bekannte Fortschrittssuite wurde hier nicht als
bestanden gezählt (ihre zwei Nekromantenfehler sind im Erststand dokumentiert).

## Gegenproben und Fixture-Korrekturen

Vor den Änderungen: Follow-up 13 Checks, 9 fehlgeschlagen; die neuen
Oberflächen, Verfolgungsunterbrechung und lebender Begleiterwechsel fehlten.
Die erste Wolf-Fixture nahm außerdem einen manuellen Erstcast an, obwohl der
Waldmeister in diesem Datenstand bereits beim Build einen Wolf erhält.
Die Ablaufprüfung führte den Helden danach ausdrücklich wieder in die normale
Wahrnehmungsreichweite: außerhalb dieser Reichweite darf ein entblindeter
Gegner weiterhin kein neues Ziel erkennen.

Ein früher Parse-Aufruf traf eine zwischenzeitlich falsch eingerückte
Reaktionszeile; korrigiert, neu geladen und final geprüft. Die zuerst ergänzten
Feuerflächen machten die alte Assertion „keine Impulse mehr“ zu weit: sie
prüft jetzt gezielt keine Giftimpulse des verbrauchten Gifts; echte Feuerimpulse
dürfen weiterlaufen. Die bestehende Splitterprüfung zeigte außerdem sofortiges
Wiedereinfrieren aus dem neuen Eis: Auftauzeit ergänzt, dieselbe Prüfung 57/0.

Die erste Story-Fixture benutzte ihren Scratch-Profilpfad mehrfach und erbte
dadurch die vorher gewählte Begleiterart. Sie setzt nun ausschließlich ihre
isolierte Testprofildatei vor jedem Szenario zurück. Beim Durchlaufen der
Auswahl wurde dabei auch der echte, oben behobene Würmer-Auswahlfehler sichtbar.

Die erste GPU-Dampfaufnahme ließ den Gegner bereits vor dem Aufkochen loslaufen;
er war bei Entstehung der Wolke nicht mehr im dichten Dampf. Die finale
Trainingsaufnahme stellt den Gegner in einen echten, von Wasser/Feuer erzeugten
Dampfpuff und prüft den normalen Exposure-/AI-Pfad. Kein künstlicher Blindtimer.

## Echte GPU-Bilder

Sechs rohe 1280×720-Krypta-Viewportbilder, kontrollierte Trainingszustände:

1. 01-poison-puddle: sichtbare echte Giftflüssigkeit.
2. 02-four-ground-surfaces: links Wasser, rechts Gift, oben Eis, unten Feuer.
3. 03-steam-blind: echte Kochreaktion und darin geblendeter Gegner.
4. 04-wolf: ursprünglicher lebender Wolf.
5. 05-bear-selected: tatsächlicher Talentbildschirm mit neuer Auswahl.
6. 06-bear-summoned: neuer Bär nach bezahlter Reaktivierung.

Die Aufnahme vergibt Ränge/Ressourcen nur in ihrer Fixture und schreitet
Simulation/Präsentation gemeinsam in 1/60 s fort. Keine erspielte Kampagne,
keine LAN-/FPS- oder subjektive Spielgefühl-Abnahme. Kein neuer Netzwerkspiel-
Nachweis; der Protokolltest prüft ausschließlich die Kompatibilitätsregeln.

Wiederholung: Godot 4.7.2 --path . --script res://tests/<Name>.gd, headless für
die Suiten. GPU: res://scripts/capture_alchemist_followup.gd. APPDATA jeweils
isoliert unter Logs/followup-*-user. receipt.json enthält finale Quellen/Bildhashes.
