# Krieger – drei Spezialisierungen

**Konzept vom 03.11.2026, noch nicht implementiert.** Grundlage sind die vorhandenen Zweige Berserker, Schildwächter und Klingenmeister. Der Auftrag ist hier zunächst ein Konzept; bestehende Krieger-Fähigkeiten werden dadurch nicht ersetzt.

## Gemeinsamer Kern

Der Krieger kämpft tatsächlich im Nahkampf. Er erzeugt **Wut** durch bestätigte eigene Treffer und erlittenen Schaden. Vorschlag zum ersten Abstimmen: 100 Wut Maximum, acht Wut je eigenem Nahkampftreffer mit begrenzter Vergabe pro Sekunde; zehn Wut bei einem wirklichen eingehenden Treffer, höchstens einmal pro Sekunde. Nach vier Sekunden ohne Kampf sinkt Wut langsam. Keine Wut durch Luftschläge, eigenes Blut, Pfützen oder bloße Trefferanimationen.

Alle drei Zweige behalten den gemeinsamen **Shift-Dash**: drei Meter, eine Ladung, vier Sekunden Wiederaufladung, kurze Unverwundbarkeit. Schildheben liegt auf einer eigenen Fähigkeit. Ultimates setzen den Dash nicht zurück. Vier aktive Leistenplätze und R bleiben erhalten; Alternativfähigkeiten werden im Baum ausgetauscht.

| Zweig | Schwerpunkt | Ultimate |
| --- | --- | --- |
| **Berserker / Koloss** | Große Nahkampftreffer, Gruppen zerschlagen, Wut bewusst ausgeben | **Koloss der Raserei**: vorübergehend größer, breitere Hiebe und mächtiger Abschluss |
| **Schildwächter / Bastion** | Gegner binden, frontale Treffer abfangen, Verbündete schützen | **Lebende Festung**: bewegliche Schutzstellung mit klarer Vorderseite |
| **Klingenmeister / Duellant** | Präzise Trefferketten, Paraden und gezieltes Ausschalten | **Klingenrausch**: kurze kontrollierte Schlagfolge mit schwerem Abschluss |

## 1. Berserker – Koloss der Raserei

Er soll sich wie ein schwerer, aggressiver Frontkämpfer anfühlen. Die Verwandlung verändert seine Angriffe, statt nur Schadenszahlen zu erhöhen.

- **Spalter:** schwerer Hieb im breiten Bogen; trifft mehrere erreichbare Gegner.
- **Blutspalt:** Schlag mit Blutung. Erfolgreiche Nahkampftreffer verlängern die selbst verursachte Blutung am Gegner begrenzt, ohne endlos stapelnde DoTs.
- **Erdbruch:** kurzes Ausholen, Stampfen und eine sichtbare Bodenwelle; normale Gegner taumeln, Bosse werden nicht festgesetzt.
- **Kriegsschrei:** Gegner im Umkreis auf sich ziehen und kurz robuster werden; keine Schadensimmunität.
- **R: Koloss der Raserei:** Vorschlag 60 Wut, acht Sekunden, 60 Sekunden Abklingzeit. Größere Silhouette und Reichweite, rund 40 % mehr Nahkampfschaden, dafür etwas langsamer. Spalter wird zum beidhändigen Flächenschlag, Erdbruch zum schweren Stampfer. Am Ende ein vorbereiteter Schlussstoß statt einer automatischen zweiten Ulti.

Passive Richtung: Wut bei mehreren tatsächlich getroffenen Gegnern, begrenzter Schaden gegen blutende Ziele, kurze Zähigkeit nach einem schweren Treffer. Kein pauschales permanentes Lebenssaugen, keine Unverwundbarkeit während der gesamten Verwandlung. Gegnerangriffe bleiben sichtbar und müssen weiter ausgewichen werden.

**Rig-Idee:** vorhandene Hand-, Arm-, Waffen- und Rumpfgelenke. Gewicht durch Schultervorbereitung, verzögerten Armzug, Rückstoß und Erholung. Keine starre Ganzbild-Vergrößerung als fertige Animation. Eine konkrete Koloss-Grafik würde vor Aktivierung wie vereinbart separat gezeigt und freigegeben.

## 2. Schildwächter – Bastion der Gruppe

Sein Vorteil ist kontrollierte Sicherheit. Er kann Räume ordnen, verliert aber Angriffstempo und Ressourcen, wenn er jeden Treffer stehen bleibt.

- **Schildschlag:** kurzer Nahkampftreffer, unterbricht normale Gegner. Bosse erhalten nur den Schaden.
- **Schildhaltung:** eine gehaltene Fähigkeit mit klarer Front, kurzer Höchstdauer und eigener Abklingzeit. Von hinten und durch Bodenfelder bleibt er verwundbar. Abfangen kostet Wut; echte blockierte Treffer können begrenzt Wut zurückgeben.
- **Herausforderung:** sichtbarer Ruf, der normale Gegner im Umkreis bindet. Kein blindes Teleportieren und keine erzwungene Boss-Starre.
- **Schutzstoß:** Schildschub, der Platz schafft und eine begrenzte Schutzreserve für nahe Verbündete erzeugt. Keine beliebig erneuerbare Vollheilung.
- **R: Lebende Festung:** Vorschlag 60 Wut, acht Sekunden, 60 Sekunden Abklingzeit. Breitere Frontabwehr und begrenzte gemeinsame Schadensabfangreserve für nahe Gruppenmitglieder; eigener Schaden und Bewegung sinken. Die Reserve ist endlich und zerbricht sichtbar.

Passive Richtung: zusätzliche Wut für echte Blocks, längere Bedrohungsbindung, begrenzte Schutzreserve nach erfolgreicher Parade. Der Schild muss als eigenes Rig-Teil reagieren: Handgelenk federt, Schulter nimmt den Treffer auf, Schild kippt beim Brechen. Keine unsichtbare Rundum-Schutzblase als Hauptlesbarkeit.

## 3. Klingenmeister – präziser Duellant

Er setzt einzelne Ziele unter Druck und lebt von gutem Timing. Seine Identität ist keine zweite Koloss-Verwandlung und kein dauerhafter Wirbel.

- **Kreuzhieb:** zwei klar erkennbare Schnitte; der zweite trifft bei korrekter Position besonders gut.
- **Parade:** kurzes aktives Zeitfenster. Ein wirklich abgewehrter frontaler Treffer schaltet einen Gegenstoß frei; bloßes Drücken gibt keinen Bonus.
- **Durchstoß:** schmaler Nahkampfangriff mit begrenzter Rüstungsdurchdringung.
- **Hinrichtung:** hoher Schaden gegen angeschlagene normale Ziele; Bosse bekommen einen begrenzten Schadensbonus und werden nicht automatisch getötet.
- **R: Klingenrausch:** Vorschlag 50 Wut, 60 Sekunden Abklingzeit. Drei vorbereitete Nahkampfaktionen über wenige Sekunden, dann ein schwerer Abschluss. Ziele und Bewegungen bleiben kollisionsgeprüft; kein unkontrollierter Sprung durch eine Wand. Ein fehlender oder toter Gegner beendet die betreffende Aktion sauber.

Passive Richtung: begrenzte Kombostufen, Wut-Rückgabe nach einer echten Parade, Präzisionsbonus beim Wechsel von schwachem zu schwerem Angriff. Trefferketten enden bei Untätigkeit; kein endloser Krit-Bonus auf allen Schadensquellen.

## Was vor Umsetzung festzulegen wäre

Die Zahlen oben sind **Startvorschläge für einen späteren Prototyp**, keine bereits gültigen Balanceregeln. Zuerst den Berserker mit normalen Hieben und achtsekündigem Koloss prüfen, danach Schildfront/Parade, anschließend den Duellanten. Neue Umrissgrafik erst als kleine freizugebende Art-Probe. Zustandsdauer, Wutkosten, Abfangreserven und Treffergrenzen kommen in Daten statt in UI-Logik.

Abnahmekriterien: Gegner vor und hinter der Figur unterscheiden sich, Wände begrenzen jeden Angriff, Bosse werden nicht dauerhaft kontrolliert, kein Wutgewinn durch Nullschaden und keine Gratis-Ulti durch Menüwechsel. Im Koop rechnet allein der Host Treffer, Wut, Schutz und Bedrohung ab. Zwei lokale Prozesse wären ein Techniknachweis, keine LAN- oder Spielgefühl-Abnahme.
