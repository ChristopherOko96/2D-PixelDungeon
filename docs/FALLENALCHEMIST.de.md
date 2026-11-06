# Fallenalchemist

## Nachbesserung: Flüssigkeit, Sichtverlust und Begleiter (05.11.2026)

Giftpfützen werden jetzt als zusammenhängende, deckende Flüssigkeit mit
Flüssigkeitsrand/Glanz gezeichnet; die zuvor absichtlich neblige Miasma-Darstellung
gilt nicht mehr für normales Gift. Giftgas bleibt ein eigener Gaszustand.
Auch Zündfallen hinterlassen echte Feuerflächen (4 s, 20 % Grundschaden/s plus
Brennen), Frostfallen echte Eisflächen (5 s, Verlangsamung und Frostreaktion auf
nasse normale Gegner). Beide nutzen dieselben begrenzten, besitzereigenen Medien
und tatsächlichen Pool-Zellen. Splitter bleiben Glassplitter.

Dichter Dampf und Rauch erneuern `gases.<material>.blind_sight_s` aus
`element_rules.json` auf 3 s. Währenddessen verlieren Gegner Aggro-/Bedrohungs-
und Lockziele, verfolgen niemanden und starten keine neuen gezielten Angriffe.
Das hält bis 3 s nach dem letzten dichten Kontakt an; danach gelten wieder die
normalen Wahrnehmungsregeln. Auch Hitzewiderstand erlaubt kein Sehen durch dichten
Dampf. Schaden, DOT, Körperkräfte und bereits freigesetzte Projektile bleiben
aktiv; Helden behalten die bisherige Gas-Sichtdarstellung. Sichtverlust ist kein
Einfrierstatus und ändert keine Treffer-/Unverwundbarkeitsregeln.

Der Waldmeister behält beim Ändern der Auswahl seinen bisherigen lebenden
Begleiter. Erneutes bezahltes Wirken von Tiergefährte ersetzt ihn durch die
gewählte andere Art; Kosten, globale und normale Abklingzeit bleiben erhalten.
Dieselbe lebende Art lässt sich nicht zum kostenlosen Heilen neu beschwören.
Die beiden Ultimate-Würmer sind korrekt `summon_only` und nicht mehr versehentlich
im normalen Auswahlzyklus. Der Talentmenütext erklärt den nötigen erneuten Cast.

`alchemist_rules.fire_tick` ist der Feuerflächen-Schadensfaktor je Impuls;
`shatter_thaw_s` verhindert 1 s lang das sofortige Wiederanlegen von Alchemie-
Frost nach einem Splitterbruch. Andere Schadensquellen werden dadurch nicht
abgeschirmt. Ruleset ist jetzt 29. Neue reale Krypta-Aufnahmen und fokussierte
Nachweise: `production/qa/evidence/alchemist-followup/`.

Die folgenden Abschnitte halten den vorherigen Erststand fest; diese
Nachbesserung hat bei Lebensdauern, Bodenflächen und Ruleset Vorrang.

05.11.2026. Nutzerentscheidung: den bisherigen Fallensteller als Alchemisten
mit Gift, Feuer und Frost umbauen. Wasser ist das Kombinationsmedium. Keine
Blitz- oder Rankenfähigkeiten. Die zuvor ergänzten Gegner-Statuspartikel werden
gemeinsam weiterverwendet.

## Spielablauf und Fähigkeiten

Pfützen vorbereiten, Gegner zum Giftköder locken, passende Kapseln auslösen.
Eigene Pfeile können scharfe Kapseln treffen; Gegnerkontakt löst ebenfalls aus.
Der Kettenzünder aktiviert eigene scharfe Fallen im Zielbereich in der Reihenfolge
Wasser → Gift → Frost → Splitter → Feuer. Fremde Kapseln, unscharfe Fallen und
Fallen hinter einer trennenden Wand bleiben davon unberührt.

| ID | Fähigkeit | Rangwerte und Verhalten |
|---|---|---|
| trapper_1 | Giftköder | Öffnung 20/25/30 % Schaden; 7 s echte Giftpfütze in 2,5 m, je Sekunde 15/20/25 % und Gift. Lockt sichtbare normale Gegner in 5 m zum scharfen Köder. 15 Ausdauer, 10 s Nachladung. |
| trapper_3 | Wasserkapsel | 10/15/20 % Schaden, 4 s nass; 8 s echte Wasserpfütze in 3 m. 15 Ausdauer, 10 s Nachladung. Wasser löscht Brennen, entfernt kein Gift. |
| trapper_5 | Zündfalle | 110/135/160 % Schaden in 3 m und 3 s Brennen. Reagiert über vorhandene Elementregeln mit Gift, Wasser und Eis. 25 Ausdauer, 16 s Nachladung. |
| trapper_7 | Frostfalle | 45/60/75 % Schaden in 3 m, 35 % langsamer für 2 s. Nasse normale Gegner frieren 1/1,3/1,6 s ein. Wasser wird zu Eis. Bosse bleiben bei Verlangsamung. 20 Ausdauer, 14 s Nachladung. |
| trapper_9 | Splitterfalle | 100/125/150 % Schaden in 2,5 m. Tatsächlich eingefrorene normale Gegner nehmen zusätzlich 50/75/100 % Schaden; Einfrieren wird verbraucht. 20 Ausdauer, 12 s Nachladung. |
| trapper_11 | Kettenzünder | Eigene scharfe Kapseln in 5 m um das Ziel geordnet aktivieren. 10 Ausdauer, 8 s Abklingzeit. |
| trapper_14 | Alchemistischer Jagdgrund | Apparat am Ziel in bis zu 7 m: Wasser nach 0,5 s, Gift nach 0,7 s, Frost nach 1,5 s, Zündung nach 2,5 s. Sechs echte Kapselpfützen; direkter Abschluss 220 % Schaden und Brennen. 55 Ausdauer, 60 s Abklingzeit. |

Alle fünf normalen Kapseltypen besitzen drei Ladungen und brauchen 0,5 s zum
Scharfwerden. Maximal sechs Bodenfallen je Besitzer, älteste zuerst ersetzt.
Vier aktive Hotbarplätze bleiben erhalten: der Spieler wählt seinen Aufbau aus
den sechs erlernbaren Fähigkeiten. R bleibt die eigene Ultimate.

**Ultimate-Stufen:** Großes Labor vergrößert den tatsächlichen Bereich um 25 %;
Meisterreaktion verstärkt den direkten Abschlussschaden um 50 %. Die vorhandenen
Elementexplosionen verwenden ihre bestehenden Reaktionswerte; diese werden nicht
noch einmal als Fallenschaden multipliziert. Kein kostenfreies Nachladen durch R.

**Passiven:** Giftmischer bleibt Giftschadensbonus; Hinterhalt verstärkt Fallen.
Konzentriertes Gift verstärkt den Giftköder und dessen Impulse. Fallenkunde senkt
Kosten. Reaktionsfenster verstärkt direkte Treffer gegen Gift/Brennen/Frost.
Schutzkleidung senkt erlittenen Schaden; Meisteralchemist verstärkt Gesamtschaden.

## Echte Medien und Grenzen

Die Pfützen gehören dem bisherigen Boss-/Elementruntime bzw. dem Story-
Elementadapter. Es gibt keine zweite, unabhängige Schadenfläche über dem Bild.
Der Alchemist merkt sich Referenzen auf die tatsächlich angelegten Medien.
Zusätzliche Giftimpulse enden mit Verbrauch/Ablauf dieses Mediums. Wasserimpulse
machen nur auf den tatsächlichen Flüssigkeitszellen nass; gefrorenes Wasser
erzeugt diese Impulse nicht. Alte Felder werden niemals nach einer Explosion
aus einem dauerhaften Talentzustand neu angelegt. Maximal sechs eigene
Alchemiepfützen; andere Klassen und feindliche Medien werden nicht gelöscht.

Gift + Feuer verbraucht Gift zur vorhandenen Explosion. Wasser + Frost gefriert.
Wasser + Feuer kocht zu Dampf; bereits gefrorenes Wasser taut zuerst. Wet blockiert
Brennen nach den bestehenden Regeln. Direkte Kapseltreffer, Lockziele und
manuelle Aktivierung prüfen Sichtlinien. Die Elementreaktionen selbst verwenden
weiterhin die bestehenden weltabhängigen Reichweiten-/Schadensregeln.

Bossregeln: kein Locken, kein Einfrieren, kein Splitterbonus aus einem
Boss-Frostzustand. Frost bremst Bosse. Ein bloßer Stun ist kein Einfrieren.
Beim Splittern bleibt eine nachweislich längere unabhängige Story-Betäubung
erhalten. Raumwechsel und neue Läufe löschen ausstehende Kapsel-/Ultimate-
Scheduler. Ressourcen, Käufe und Auslösung bleiben hostseitig.

## Darstellung

Neue native 9×13-Glaskapsel aus explizitem Pixelraster, ohne neue Bildgenerierung.
Fünf echte Masken: Korken, linke/rechte Glasschale, Flüssigkeitskern, Boden.
Die bestehenden Eltern-/Pivot-Transformationen lösen Öffnung, Abheben und
auseinanderfliegende Schalen. Texturen entstehen einmal je Element.
Farben und Zeichen unterscheiden Gift, Wasser, Feuer, Frost und Splitter.
Die Hotbar verwendet dazu passende Farbrampen und Motive. Der Jagdgrund
entfaltet sechs Kapseln um einen größeren Kern; echte Hostphasen lösen die
zugehörigen Medien und Partikel aus. Keine neuen HUD-Panels.

## Dateien und Schema

- `src/combat/alchemist_traps.gd`: bezahlte Casts, Scharfwerden, Lockziel,
  eigene Pfeilsegmente, geordnete Auslösung, Medienreferenzen, Ultimate-Takt.
- `src/vfx/alchemist_art.gd`: gecachte native Masken und Gelenkposen.
- `assets/data/talents.json`: dieselben 14 IDs, Ränge und Tierplätze. Gespeicherte
  Builds behalten ihre IDs/Belegung, erhalten deren neue Funktion. Kein Profilreset.
- `assets/data/alchemist_rules.json`, Schema 1: `arrow_trigger_m` ist seitlicher
  Trefferradius, `arrow_height_m` die sichtbare Kapselhöhe; Meter über `meter_px`.
  `pulse_s` in Sekunden; `poison_tick` sind drei Rang-Schadensfaktoren;
  `pool_limit` die eigene Mediengrenze; `boss_slow` Verlangsamungsanteil und
  `boss_slow_s` Sekunden. `field` enthält Kapselzahl, Verteilungsradius als Anteil,
  Pfützenradius in Metern, Zeiten in Sekunden, Frostzeit und Abschlussschaden-
  Multiplikator. `art` enthält nativen Größenfaktor, Öffnungszeit in Sekunden
  sowie Schalenflug/Korkenhub in Kunstpixeln. `colours` sind RGB-Hexfarben.
- Neue Casttypen: `alchemy_trap`, `alchemy_detonate`, `alchemy_field`.
  Neue Talentfelder: `recipe`, `pool_time`, `wet_time`, `lure_m`,
  `freeze_wet`, `shatter_bonus`, `field_power`, `field_radius`.
- Kapselsnapshot ergänzt `recipe` und `armed`; Ereignisse `alchemy_burst`,
  `alchemy_trigger`, `alchemy_field` nutzen die vorhandene primitive Ereignishülle.
  Keine Client-Schadens-/Medienangaben werden akzeptiert.
- Ruleset 28 verhindert gemeinsames Spielen mit den alten Fallenregeln.
  Protokoll bleibt 4; die generische Ereignishülle ist unverändert.

## Prüfen

`Waldmeister-Testraum.cmd` → FALLEN: „Gift, Wasser & Elemente“ bzw.
„Splitter & Kettenzünder“. Normales Lernen/Ausrüsten funktioniert im Talentbaum.
Reale Host-, Story-, Rig-, Katalog- und lokale Zweiprozess-Belege sowie echte
GPU-Trainingsaufnahmen: `production/qa/evidence/alchemist/README.md`.
Manuelle Balance-/Spielgefühlbewertung bleibt beim Nutzer. Keine neue LAN-,
Kampagnen- oder Leistungsabnahme und keine Veröffentlichung.
