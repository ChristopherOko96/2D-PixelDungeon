# Nekromant: Diener und Blut-/Fluchwirker

**Aktueller Vorrang, 03.11.2026:** [Fluchnekromant-/Waldmeister-Umbau](NEKROMANT-WALDMEISTER-REWORK.de.md). Fluch der Schwäche wirkt im 6-m-Umkreis, Fluchgeister steigen auf, R ruft den Koloss sofort, 5 ist die Knochenwelle und Shift ein Dash. Ältere Abschnitte zur Todes-Beschwörung/Fluchwelle unten sind historische Nachweise.

Umgesetzt am 01.11.2026 auf `codex/port-0x72-onto-main`. Grundlage sind die
freigegebenen zwei Konzepte und die anschließende Vorgabe: vorhandene echte
Pfützen verwenden, echte Körperteil-Rigs und ein blutaufnehmendes Skelett.
Der Seele-Zweig mit Wächter, Sprung, Ring und aufladbarer Lanze bleibt erhalten.

## Diener: Blut aufnehmen und zum großen Skelett werden

Der Knochenkrieger wird über seine eigene aktive Fähigkeit beschworen und bleibt
bis zum Tod. Allein das Lernen des Talents beschwört ihn noch nicht. Nach dem
Kampf sucht er sichtbare Blutquellen in sieben Metern Entfernung und läuft
dorthin; im Kampf behält sein Gegner Vorrang. Berührt er eine **echte
Blutpfütze**, reserviert der Host zunächst diese echte Quelle. Die vorhandene
Blutlache bleibt zuerst 0,65 Sekunden sichtbar liegen. Danach wandern geriggte
Blutpartikel aus ihrer Oberfläche in den aktuellen Brustkorb des Kriegers;
kleine Wellen bewegen das vorhandene Flüssigkeitsmaterial. Erst nach vollständiger
Aufnahme verschwindet die Quelle mit ihrem normalen Pfützen-Auslauf. Kein
zusätzlicher Ring und keine zweite gezeichnete Blutfläche.

Eine Quelle enthält 25 Blut, aufgenommen mit 14 Einheiten pro Sekunde.
Blutversorgung beschleunigt dies um 15/30/45 % und heilt pro vollständig
aufgenommener Quelle 1/2/3 % Begleiterleben. Mehrere Spieler können dieselbe
Quelle nicht mehrfach abrechnen. Tod, Wand, entfernte/abgelaufene Pfütze,
Raumwechsel oder mehr als drei Meter Abstand vom Pfützenrand beenden die
Verbindung. Bereits aufgenommenes Blut bleibt erhalten; ein noch vorhandener
Rest bleibt in derselben echten Pfütze. Dekorative Blutspritzer
und reine Partikel sind keine Blutquelle.

Die zusätzliche rote Leiste steht über dem Begleiter und im Begleiter-HUD;
eine Prozentzahl und vier Abschnitte machen den Stand unabhängig von der Farbe
lesbar. Ein voller Balken bleibt gespeichert. Erst **R** löst ab **50 Blut**
die gegliederte Verwandlung aus. Die Grundform verbraucht fünf Blut pro Sekunde:
**50 Blut reichen zehn Sekunden, 100 Blut zwanzig Sekunden**. Währenddessen
wird kein weiteres Blut gesammelt. Danach kehrt derselbe normale Krieger mit
leerer Blutleiste zurück. Ohne lebenden Krieger oder unter 50 Blut bezahlt R
weder Seelen noch Abklingzeit. Die erste Ultimate-Aufwertung verlängert die
Dauer bei 100 Blut auf 30 Sekunden, bei 50 Blut auf 15 Sekunden.

Die große Form besitzt ein eigenes `blood_colossus`-Rig aus den **vorhandenen
Pixelteilen des Knochenwächters**: Schädel, Brustkorb, zwei Arme, zwei Beine
und ein am rechten Arm befestigtes Schwert. Keine vergrößerte Zombieform und
keine neu generierte Bildtafel. Waffen- und Armbewegung teilen denselben
Elternknochen. Aufbau, Gang, Hieb, Stampfen, Klingensturm und Zerfall verwenden
das bestehende Rig-System. Das schnelle historische Kopfzittern ist bei diesen
Begleitern ausgeschaltet. Die ursprüngliche Boss-Rigdefinition bleibt erhalten.

Die Blutform erhält 1,5-faches Maximalleben, 1,75-fachen normalen Dienerschaden
und einen 1,8-m-Flächenschlag. Der bisherige Lebensanteil bleibt beim Wechsel
erhalten; die Verwandlung füllt kein Leben auf und stellt verlorene Gliedmaßen
nicht kostenlos wieder her. Permanente Diener, Blutstand und laufende Form
bleiben bei einem normalen Raumwechsel erhalten. Ein neuer Lauf beginnt frisch.

| Fähigkeit | Verhalten |
| --- | --- |
| Knochenkrieger | Eigene bezahlte Beschwörung eines dauerhaften Schwert-/Schildkriegers. Kein zweiter Krieger, solange er lebt. |
| Knochenspeer | Durchschlägt drei Gegner, kurze Verlangsamung getroffener Ziele. |
| Blutmal | Ersetzt Belagerungsbefehl. Markiert Gegner im Zielgebiet (3 m Radius, 8 m Reichweite) für acht Sekunden. Markierte Tote hinterlassen eine echte große Blutpfütze mit 2,5 m Radius für zwölf Sekunden. Maximal sechs solcher Quellen pro Besitzer; keine Quellen durch Bosse oder feindliche Beschwörungen. |
| Leichenexplosion | Nächste eigene erreichbare Leiche am Ziel verbrauchen, Knochenexplosion und echte Blutpfütze. Ohne Leiche halber Schaden ohne Blut. |
| Knochenschützen | Separate Beschwörung von genau zwei Bogenschützen mit Körperteil- und Bogen-Rig für 15 Sekunden. Tod und Zeitablauf lösen einmalig eine Leichenexplosion aus: 60 % Begleiter-Grundschaden in 1,8 m, mit Wandprüfung. Keine zusätzlichen Blutquellen allein durch den Begleitertod. |
| Totenpakt | Fünf Sekunden lang 25/30/35 % Schaden an den lebenden Krieger übertragen, maximal acht Meter Entfernung. Nicht bezahlbarer Schaden bleibt beim Helden. |
| R: Knochenkoloss | Verwandelt den lebenden Krieger ab mindestens halber Blutleiste. Die Bogenschützen bleiben erhalten. Kein Ersatzkoloss ohne Krieger. |

Eigene Leichenmarker bleiben acht Sekunden, höchstens sechs pro Besitzer.
Bosse, Minibosse und feindliche Beschwörungen liefern dafür keine Marker.
Ein wiederholter Todescallback erzeugt weder eine zweite Leiche noch weitere
Belohnungen. Die Marker sind keine lebenden Gegner.

**5/6 normal:** Schildschlag und Knochenschrei.
**5/6 in großer Form:** Stampfen und Klingensturm. Der Sturm dauert insgesamt
2,4 Sekunden, mit 0,35 Sekunden Vorbereitung und 2,8 m Radius um den Begleiter;
seine Treffer folgen dessen Position und prüfen Wände. Danach erscheinen die
normalen Befehle wieder; die Ulti kann keinen gestorbenen Krieger ersetzen.

## Blut-/Fluchwirker

Dieser Zweig nutzt weiterhin **Seelen**, echte Gift-/Blutmaterialien und
magischen Verfall. Biologisches Gift behält seine vorhandenen Immunitäten;
Verfall funktioniert zusätzlich gegen giftimmune Untote.

| Fähigkeit | Verhalten |
| --- | --- |
| Knochenball (1) | 0,65 s bezahlte Ladephase: Schädel, Rippen und Beinknochen sammeln sich an der Stabspitze. Sieben echte Gelenke, Abschuss, Knochenspur und Knochen-Splash. Der erste Gegner bzw. die erste Wand beendet den Flug. Direkttreffer, Verfall und kleine echte Giftpfütze; höchstens drei eigene kleine Quellen. |
| Fluch der Schwäche | Alle sichtbaren Gegner in sechs Metern um den Spieler werden verflucht. Drei geriggte Geister steigen gestaffelt an jedem Ziel auf, ohne Kreisbahn. Eigene Schadensverstärkung; mit Unheil nach Tod bis zu drei begrenzte Weitergaben. |
| Aderfessel | Gezielte, an Wänden endende Linie, kurze Fessel und Schwächung. Die sichtbare Verbindung folgt drei Sekunden den getroffenen Gegnern. Bosse erhalten nur Verlangsamung. |
| Seuchenfeld | Eine eigene echte Giftpfütze mit zusätzlichem Verfall. Normale Gegner, die darin sterben, werden zu freundlichen Skelettläufern: höchstens sechs pro Besitzer, acht Sekunden Lebensdauer. Sie verfolgen Gegner und explodieren nach 0,35 s Kontaktzündung in 2 m mit 80 % Heldengrundschaden. Begleiter-/Sekundärtötungen erzeugen keine neue Läuferarmee. |
| Blutstrahl | Drei Sekunden Verbindung zu bis zu vier sichtbaren Gegnern um den Helden, Reichweite 5/6,5/8 m nach Rang. Alle Ketten folgen ihren eigenen Zielen. Tote an einer Verbindung senden einen geriggten Fluchgeist zu einem weiteren sichtbaren Gegner bis 5 m; höchstens acht Flugflüche pro Besitzer und keine rekursive Todesfluchkette. Aderlass und echte Blutpfütze bleiben erhalten; Heilung teilt weiterhin ein gemeinsames Budget. |
| Fluchernte | Eigene Flüche und bis zu drei eigene Giftquellen für einen begrenzten Burst ernten. Keine weitere Schattenflucht. |
| R: Seuchengrube | Großes stationäres Giftfeld mit Verfall und Schwächung. Ein normaler Gegner-Tod in der aktiven echten Giftpfütze ruft einmal einen Fluchkoloss für zwölf Sekunden. Toten-Skelette aus dieser Ulti explodieren sofort; das normale Seuchenfeld behält seine laufenden Skelette. Bis zu drei eigene Giftquellen verstärken das Feld einmalig. |
| Koloss: Fluchwelle (5) | 0,65 s Vorbereitung, dann Schwächung, Verwundbarkeit (je 25 %, sechs Sekunden) und Verfall auf alle sichtbaren Gegner in acht Metern. Fünf Sekunden Abklingzeit; normale automatische Begleitersteuerung möglich. |
| Koloss: Totenbrut (6) | 0,8 s Vorbereitung; bis zu drei eigene erreichbare echte Leichen im Umkreis von sechs Metern werden zu kleinen Fluchmonstern. Acht Sekunden Lebensdauer, zwölf Grundleben, 40 % Heldengrundschaden alle 1,1 s. Jede Leiche einmal, maximal drei lebende Minis pro Besitzer. Acht Sekunden Abklingzeit, manueller Befehl. |

Heilung rechnet nur aufgelösten eigenen Schaden ab: keine Überkill-Zahlen,
keine immunen Treffer, keine Begleiter- oder fremden Treffer. Der gemeinsame
Heilvorrat fasst 2 % Maximalleben und erneuert sich mit 2 % pro Sekunde;
mehrere Ziele vervielfachen diese Grenze nicht. Die rote Rückströmung zeigt
bezahlten Blutentzug. Eigene freundliche Felder gefährden die Gruppe nicht;
überlappende feindliche Felder bleiben gefährlich.

Die Pfützen nutzen `PoolPaint`/`PuddleRenderer` und die bestehenden
Elementarregeln. Feuer kann echtes Gift entzünden; vorhandene Leere kann
Flüssigkeiten verschlingen. Eine neue universelle Blut-plus-Gift-Reaktion
wurde nicht erfunden. Verbraucht Fluchernte ein Seuchenfeld, endet auch seine
zugehörige Schadenszone; kein unsichtbarer Restschaden. Beim Aufsaugen einer
überlappenden Blutquelle bleiben andere noch aktive Quellen sichtbar.

Die Frostgruft besitzt für diese Felder jetzt ebenfalls echte zeitliche
Materialzonen. Hölle und Frost nutzen denselben Talentkern; die normalen
Raum- und Gegnerdarstellungen bleiben erhalten.

## Direkt testen

1. `Spielen.cmd` starten, unten links **DEBUG → TESTRAUM** und als Figur
   **NEKROMANT** wählen. Mit **F1** das Testmenü ausklappen.
2. Abschnitt **HELD** öffnen und **SPEZIALISIERUNG → DIENER** wählen;
   **LEVEL · ALLE TALENTE → 30**. Der separate Testraum verwendet absichtlich
   volle Talentränge, ohne den normalen Spielstand zu ändern.
3. Diener-Testleiste: **1 Knochenkrieger**, **2 Knochenschützen**,
   **3 Blutmal**, **4 Leichenexplosion**. Zuerst mit **1** den Krieger rufen.
   Mit **2** die beiden Bogenschützen beschwören; sie bleiben 15 Sekunden.
4. Gegner erzeugen, mit **3** im Zielgebiet markieren und töten. Die große
   Blutpfütze beobachten; der Krieger saugt sie selbstständig auf. Alternativ
   unter **ELEMENTE → PFÜTZEN → BLUT** Quellen platzieren, das Werkzeug danach
   mit **Escape** ablegen. Zwei Quellen ergeben 50 Blut, vier 100 Blut.
5. Ab mindestens 50 Blut **R** drücken. **5 = Stampfen, 6 = Klingensturm**.
   Balken und Rückverwandlung beobachten. Bei 100 Blut ohne R bleibt er klein.
   Knochenspeer und Totenpakt lassen sich im Talentmenü zusätzlich auf die
   Leiste legen. Für **4** zuerst einen normalen Gegner töten und auf dessen
   Leichenmarker zielen. Bogenschützen explodieren bei Tod oder Ablauf einmal.
6. Für den anderen Zweig **Spezialisierung → FLUCH** wählen:
   **1 Knochenball**, **2 Schwäche**, **3 Seuchenfeld**, **4 Blutstrahl**,
   **R Seuchengrube**. Aderfessel und Fluchernte können im Talentmenü auf die
   Leiste gelegt werden. Auch Skelette nehmen magischen Verfallsschaden.
7. Für den **Fluchkoloss** mit **R** die Giftgrube auf mehrere Gegner legen.
   Einen normalen Gegner darin töten: Der große Fluchkoloss entsteht sofort,
   und das Toten-Skelett platzt. **5** verbreitet Flüche; **6** erweckt die
   noch vorhandenen eigenen Leichen als kleine Fluchmonster. Zuerst seine
   einsekündige Entstehung abwarten. Die Leichen bleiben acht Sekunden liegen.
   Er kämpft zwölf Sekunden mit Klauen-/Flächenangriffen; pro R-Pfütze einmal.
   Dienertode, Tode außerhalb, Bosse, feindliche Beschwörungen und
   Begleiter-/Sekundärtötungen lösen keine neue Koloss-/Leichenkette aus.

Der Testbuild bezahlt Fähigkeiten mit Seelen und R behält seine Abklingzeit,
solange unter **WERKZEUGE** die Optionen für unendliche Ressourcen und fehlende
Abklingzeiten ausgeschaltet sind. Der alte native Testraum besitzt dieselbe
Grundbelegung, verwendet jedoch einen gültigen Level-30-Punktebuild statt
der absichtlichen Vollrang-Vorschau des neuen DEBUG-Testraums.

## Daten, Code und Prüfung

`assets/data/necromancer_rules.json`, Schema 7:
`blood` definiert Kapazität, Quelle, Aufnahmegeschwindigkeit, Suchradius,
Mindestblut zur Aktivierung, Formwerte sowie `form_before_pull_s` für die
sichtbare Vorlaufzeit und `pull_radius_m` für die maximale Aufnahmeverbindung;
`blood_mark` definiert Radius,
Dauer und Besitzerbudget der durch markierte Tote erzeugten Blutquellen;
`corpses` definiert Ablauf, Besitzerbudget, Blutpfütze und Fallback;
`curse` definiert kleine Quellen, Verfallstakt, Heilbudget, Weitergabe,
Erntebudgets, Paktreichweite und die Zielkanäle unter `curse.beam` sowie
`curse.runners`, `curse.flight` und `curse.ultimate_monster`. Letzteres setzt
12 s Lebensdauer, 40 Grundleben, 90 % Heldengrundschaden alle 1,4 s, 2 m
Flächenreichweite sowie Bewegung und native Rig-Größe. Sein `brood`-Block
definiert die oben genannten Mini-Werte und 1×-Darstellung gegenüber 3× beim
Koloss. Fähigkeiten, Radien und Vorbereitungszeiten stehen unter
`talents.json → pet.abilities.curse_wave/curse_brood`.
Der Strahl erfasst bis zu vier Ziele in
5/6,5/8 m Reichweite; jede Verbindung reißt jenseits dieser Reichweite plus 0,5 m ab.
35 % des bisherigen direkten Schadensbudgets treffen sofort, 65 % werden über
den Kanal verteilt. Seelenkosten und Abklingzeit bleiben erhalten.
Meterwerte werden mit `talents.json.meter_px`
in Weltpixel umgerechnet. Fähigkeitsränge, Seelenkosten, Abklingzeiten und
Ultimate-Stufen bleiben in `talents.json`.

Hostlogik: `src/combat/necromancer_branches.gd`, eingebunden in `TalentCombat`.
Darstellung: `src/vfx/necro_art.gd`, `CompanionRigs`, `RigRenderer`, `RigPoses`.
Große Rigdefinition: `assets/data/krypta_boss_rigs.json → blood_colossus`,
mit unveränderten vorhandenen Quellpixeln. Bogenschütze:
`assets/data/companion_rigs.json → bone_archer`.

Regelsatz **23** (gegnerbasierter Fluchkoloss, Totenbrut und Knochenball), Protokoll weiterhin **4**. Talent- und Nekromantenregeln
gehen zusätzlich als Datenfingerabdruck in die Sitzungsprüfung ein. Blut,
Form, Gliedmaßen, Timer und Befehle bleiben hostautoritativ; Clients erhalten
nur Darstellungsdaten. Keine Texturen oder Rigobjekte im RPC.

## Rig-Überarbeitung vom 01.11.2026

Alle 14 aktiven Fähigkeiten inklusive Ultimates beider Zweige besitzen eine
explizite Rig-/Bewegungsbindung in `assets/data/necro_spell_rigs.json`. Die
vorhandenen Schädel-, Blutkugel-, Knochenspeer- und Schwertpixel werden einmalig
durch `RigLibrary` ausgeschnitten. Kiefer, Kopf, Schweif und Waffenteile bewegen
sich mit Elternknochen über den bestehenden `RigRenderer.solve_pose`. Die
Quellpixel der bisherigen Effekte gehören jeweils einem Teil; Originalbilder und
Lizenzen bleiben erhalten. Der separat freigegebene Fluchgeist verwendet acht
neue native Ausschnitte seiner Konzepttafel, siehe `assets/vfx/curse_spirit/PROVENANCE.md`.

`src/rig/necro_spell_rig.gd` baut den Blutstrahl als Kette aus 16 Gelenken mit
vorhandenen Blutpixeln auf. Lokale affine Gelenkposen halten die Segmente auch
bei Drehung und Dehnung zusammen. Der Anfang sitzt an der dargestellten
Stabspitze, jedes Ende am aktuellen Körper-Rig seines gewählten Gegners. Clients
verwenden ihre dargestellten Positionen; der Host prüft Zielidentität,
Treffer, Reichweite und Sichtlinie. Kein automatisches Umspringen des Strahls
auf einen anderen Gegner. Ein Tod kann stattdessen einen eigenen sichtbaren
Fluchflug auslösen, der dieselben schrittweisen Wand-/Körperprüfungen verwendet.

Fluchgeschoss und Knochenspeer verwenden außerdem die vorhandene schrittweise
Kontaktprüfung mit Körperteilmasken. Ihre ausgeschnittenen Teile animieren im
Flug und beim Aufprall; Gegner vor einer Wand werden zuverlässig berücksichtigt.
Feldzeichen, Aderfessel, Pakt, Ernte, Beschwörung und Begleiterbefehle verwenden
denselben Rig-Zeichner. Die Bodenmaterialien bleiben echte vorhandene Pfützen.
Held und Begleiter besitzen getrennte Animationskennungen; ein Begleiter kann
die Pose des eigenen Helden nicht mehr überschreiben.

Aktuelle vollständige Angriffsauswahl mit 40 echten Spielaufnahmen und
Prüfnachweisen: `production/qa/evidence/necromancer-catalog-hq/README.md`.
Sichtbare Pfützenaufnahme mit Spielanimation und Prüfungen:
`production/qa/evidence/necro-pool-uptake/README.md`. Blut-/Beschwörungsablauf
und Talentbilder: `production/qa/evidence/necro-blood-cycle/README.md`.
Frühere Rig-Animationen:
`production/qa/evidence/necro-rig-upgrade/README.md`; diese zeigen die damaligen
Regeln vor der aktuellen Blut-Ulti-Korrektur. Frühere Umsetzung und Aufnahmen:
`production/qa/evidence/necro-branches/README.md`.
Die HTML-Konzeptvorschauen sind historische Entwürfe; ihr vereinfachter
Canvas-Pfützen- und Figurenzeichner wurde nicht in das Spiel übernommen.

## Historisch: Gegner-Tod ruft den Fluchkoloss (02.11.2026; ersetzt am 03.11.)

`src/combat/necromancer_branches.gd → _raise_runner` und
`src/combat/curse_monster_host.gd` verarbeiten normale Gegner-Tode genau einmal.
Dies ersetzt die vorherige Diener-Opfer-Regel. Die reale Giftquelle muss vorhanden
und mit dieser eigenen aktiven Ultimate-Zone verbunden sein; Wandprüfung und
lebender Besitzer bleiben Pflicht. Pro Pfütze eine Manifestation, gleichzeitig
höchstens ein lebender Fluchkoloss pro Besitzer. Seine eigenen Tode erzeugen
keinen Nachfolger. Der Koloss ist ein freundlicher temporärer Begleiter mit
normaler selbstständiger Zielsuche und wird bei Raumwechsel entfernt.

`src/rig/curse_monster_rig.gd` übernimmt die acht bereits freigegebenen
Fluchgeist-Teile unverändert in die gemeinsame Kampfrig-Bibliothek. Native 3×-
Darstellung in der Krypta, getrennte Klauen, Fangkiefer und dreigliedriger
Schweif; bestehender RigRenderer und echte Körperteil-HP statt Ganzbildanimation.
Die Totenbrut verwendet dieselben acht Teile in kleiner Darstellung, dieselbe
Hierarchie, echte Körperteil-HP und selbstständige Gegnerverfolgung. Die
Klauen-/Kieferpose folgt während beider Befehle dem aktuellen Vorbereitungsstand.
Tote Zaubernde beenden ihre Beschwörung, reservierte Leichen werden freigegeben;
Raumwechsel entfernt die temporäre Armee. Keine neue Bildgenerierung.
Aktuelle Nachweise: `production/qa/evidence/curse-evolution/README.md`.
