# Nekromant: Ausbaukonzepte für Diener und Fluch

01.11.2026. Freigegebenes Konzept. Aktuelle Umsetzung mit Blutaufnahme,
großem Skelett-Rig und vorhandenen Materialfeldern:
[Diener und Blut-/Fluchwirker](NEKROMANT-DIENER-FLUCH.de.md).
Optionale Erweiterungen und frühe Beispielwerte unten bleiben Entwurf.
Die zwei anderen Spezialisierungen sind die vorhandenen Zweige **Diener** und
**Fluch**. Der bereits überarbeitete Seele-Zweig bleibt ihre Vergleichsbasis.
Die neueste Vorgabe ersetzt die früher vorgeschlagenen zusätzlichen Sprünge:
kein verpflichtendes Bewegungs-/Projektil-/Ring-/Feld-Schema je Spezialisierung.

## Gemeinsamer Rahmen

| Zweig | Spielerentscheidung | Schwerpunkt |
|---|---|---|
| Seele, bestehend | Gegner mit Geistern kontrollieren und Seelenenergie bündeln | Seelenmaterial, Ring/Spur, Seelenwächter |
| Diener → Grabrufer, Vorschlag | Diener kommandieren, Leichen verwerten, Armee erhalten | Knochen, Blutboden als Versorgung, einzelne Giftkombinationen |
| Fluch → Blut-/Fluchwirker, Vorschlag | Ziele verfluchen, Giftflächen vorbereiten, Verfall auslösen oder zum Heilen nutzen | Verfallsfluch, echtes Gift, Blut und Entzug |

Seelen bleiben die gemeinsame Klassenressource. Der normale Angriff bleibt
ressourcenfrei; keine zusätzlichen Manabalken. Vier aktive Plätze erfordern
eine Auswahl aus dem Baum. Die vorhandene Shift-Verteidigung bleibt Grundlage.
Ein weiterer Sprung ist für Diener und Fluch nicht vorgesehen. Der Fluchzweig
soll keine dauerhafte Armee erhalten; der Grabrufer keine zweite Seelenlanze.

## Konzept 1: Grabrufer — eine kleine, kommandierbare Armee

### Kampfidee

Der Knochenkrieger nimmt Gegner selbstständig auf und hält sie beschäftigt.
Der Spieler legt das wichtige Ziel fest, greift mit Knochenspeeren ein und
entscheidet, ob er einen Leichnam sofort sprengt oder für die Armee nutzt.
Seine Stärke entsteht aus Befehlen und erhaltenen Dienern. Die Kontrolle über
das eigene Überleben entsteht durch einen Pakt mit der Armee.

### Fähigkeiten

| Fähigkeit | Vorgeschlagenes Verhalten |
|---|---|
| **Knochenkrieger** | Dauerhafter Hauptdiener mit Schild. Freischaltung im Baum; soll keinen ständig belegten Platz 1–4 verlangen. Seine Befehle bleiben auf 5/6. Wiederkehr nach Niederlage mit klarer Wartezeit und Seelenkosten. |
| **Knochenspeer** | Physischer Speer durch wenige Gegner. Beim Endtreffer bleiben kurze Knochenstacheln zurück, die einen engen Bereich behindern. Eigenes Verhalten statt einer zweiten aufladbaren Seelenlanze. |
| **Belagerungsbefehl** | Diener konzentrieren sich auf das markierte Ziel. Der Knochenkrieger bindet dessen Aufmerksamkeit und erhöht kurz seinen Schutz; Fernkämpfer suchen Schusspositionen. Kein Sprung des Helden, keine Rückrufleine. |
| **Leichenexplosion** | Ein ausgewählter Leichnam bricht in Knochen und Blut auseinander. Verbraucht die Leichenmarke einmalig. Ohne verfügbare Leiche bleibt ein schwächerer Knochenbruch nutzbar, damit die Fähigkeit auch gegen einen einzelnen Boss funktioniert. |
| **Skelettwache** | Zwei zeitweilige Knochenbogenschützen verstärken den Hauptdiener. Ein Befehl lenkt ihr Feuer, sie bekämpfen ansonsten eigenständig erreichbare Gegner. |
| **Totenpakt** | Ersetzt Grabessprung. Leitet kurz einen begrenzten Anteil eingehenden Schadens auf den Hauptdiener um. Überschreitet der Schaden dessen Schutzbudget, trifft der Rest den Spieler. Kein unbegrenzter Schutz und kein erzwungenes Festkleben des Dieners am Helden. |
| **Ultimate: Knochenkoloss** | Ein schwerer körperlicher Untoter mit Stoß, Flächendruck und langer Erholung zwischen Schlägen. Er ersetzt während seiner Dauer die beiden zeitweiligen Wachen. 5/6 steuern vorübergehend Stampfen und Knochenhagel; danach wieder den Hauptdiener. |

**Beispiel:** Knochenkrieger bindet eine Gruppe → Belagerungsbefehl auf den
Bogenschützen dahinter → erster Gegner fällt → Leichenexplosion legt Blutboden
frei → Diener kämpfen darin länger durch. Gegen den Boss stehen Befehl,
Knochenspeer und Totenpakt auch ohne frische Leichen zur Verfügung.

### Blut, Gift und vorhandene Materialien

- **Blut als Versorgung:** Ein späteres Talent lässt eigene Diener auf dem
  Blutboden eigener Leichenexplosionen langsam regenerieren. Ein gegnerisches
  Blutbecken wird dadurch nicht automatisch freundlich. Blut heilt derzeit
  nicht von selbst; diese Versorgung wäre eine neue gezielte Fertigkeitswirkung.
- **Knochen als Kontrolle:** Kurze Knochenstacheln und Skeletthände geben der
  Armee Zeit, statt jedes Feld mit zusätzlichen Geistern zu füllen.
- **Gift als optionale Kombination:** Eine spätere Giftaufwertung der
  Leichenexplosion nutzt das bereits vorhandene Giftmaterial. Das ermöglicht
  Zusammenspiel mit einem Feuermagier, ohne den ganzen Dienerzweig auf Gift
  angewiesen zu machen.

### Zuordnung zum bestehenden Baum

Die IDs dienen nur der späteren Migration; dies sind vorgeschlagene Änderungen.

| Platz | Ausbau |
|---|---|
| `minion_1` | Knochenkrieger als Begleiter-Freischaltung ohne Pflichtplatz 1–4 |
| `minion_2` | Knochenband: Leben/Schaden der Diener |
| `minion_3` | Knochenspeer |
| `minion_4` | Untote Härte: bestehende Grundverteidigung |
| `minion_5` | Belagerungsbefehl statt eines weiteren Sprungangriffs |
| `minion_6` | Grabkälte: Kontrolle durch Speerstacheln verbessern |
| `minion_7` | Leichenexplosion tatsächlich an Leichen binden, mit Ersatzwirkung |
| `minion_8` | Totenbeschwörer: bisherige zusätzliche Seelen aus echten Kills |
| `minion_9` | Zwei zeitweilige Skelettbogenschützen |
| `minion_10` | Unheilige Kraft: bestehender Grundschaden |
| `minion_11` | Totenpakt statt Grabessprung |
| `minion_12` | Meister der Toten: bestehende Abklingzeitverbesserung |
| `minion_13` | Dunkle Gnade: Blutboden versorgt eigene Diener statt generischer Kritchance |
| `minion_14` | Knochenkoloss |

**Beispielleiste:** Knochenspeer · Belagerungsbefehl · Leichenexplosion · Totenpakt.
Für mehr Armee die Skelettwache gegen eine dieser Fähigkeiten austauschen.

### Grenzen und Inszenierung

Als erster Entwurf höchstens ein Hauptdiener plus zwei zeitweilige Wachen pro
Spieler. Der Koloss ersetzt die Wachen. Gemeinsame Beschwörungsbudgets müssen
bei einer Umsetzung auch mit den bereits vorhandenen Seelen-Untergebenen
geprüft werden; deren Regeln werden durch dieses Konzept nicht überschrieben.

Leichenmarken wären ein neues hostseitiges System: etwa acht Sekunden nutzbar,
höchstens sechs auf Vorrat je Besitzer. Sie überdauern als kleine Knochen-/
Blutreste die normale kurze Todesanimation, zählen nicht als lebende Gegner und
blockieren keinen Raumabschluss. Jede Marke wird höchstens einmal verbraucht;
keine neuen Killbelohnungen durch Explosionen bereits bezahlter Leichen.

Helle Knochen, dunkle Eisenbeschläge, schwere Schläge, Blut nahe am Boden.
Rigs für Schildarm, Kopf, Kiefer und Waffen; Knochenkoloss mit deutlich schwererer
Bewegung als der schwebende Seelenwächter. Blut dient hier der Armee, der
eigentliche Lebensentzug am Spieler bleibt das Kennzeichen des Fluchzweigs.

## Konzept 2: Blut-/Fluchwirker — vorbereiten, zersetzen, Leben zurückholen

### Kampfidee

Flüche bereiten den Schaden vor. Gift beeinflusst den Kampfplatz. Blutmagie
verwandelt erfolgreiches Verfluchen in Lebensentzug. Der Spieler entscheidet,
ob er weiter Schaden ansammelt oder seine Vorbereitung für eine Entladung
verbraucht. Seine Defensive ist Entzug und Schwächung, statt noch eines Blinks.

### Fähigkeiten

| Fähigkeit | Vorgeschlagenes Verhalten |
|---|---|
| **Fluchgeschoss** | Ein dunkles Geschoss legt magischen Verfall auf das getroffene Ziel. Ein kleines Giftbecken am Einschlag schafft zusätzlich eine echte Materialfläche. Verfall und Gift sind getrennte Wirkungen. |
| **Fluch der Schwäche** | Markiert ein wichtiges Ziel und verstärkt den eigenen Fluchschaden daran. Sein Tod kann die Markierung auf wenige nahe Gegner übertragen; keine endlose Ausbreitung. |
| **Aderfessel** | Baut den bisherigen Lähmenden Fluch zu einer gezielten Kontrolle aus: Blutadern umschlingen Gegner auf einer kurzen Bodenlinie und erschweren ihre Angriffe. Bosse erhalten eine schwächere Wirkung. |
| **Seuchenfeld** | Eine Giftpfütze mit aufsteigender Giftwolke. Gegner bleiben auch nach dem Verlassen kurz von Verfall gezeichnet; echtes Gift folgt weiterhin den Materialregeln. Kein türkis umgefärbtes Seelenfeld. |
| **Blutfluch / Aderlass** | Trifft verfluchte Ziele, verursacht Blutung bei passenden Gegnern und führt einen Teil des tatsächlich verursachten Schadens als Leben zurück. An blutlosen Gegnern trägt die Fluchbindung den Entzug; eine echte biologische Blutung bleibt davon getrennt. |
| **Fluchernte** | Ersetzt Schattenflucht. Verbraucht einen begrenzten Teil eigener Verfallswirkung für einen sofortigen Schadensimpuls. Giftbecken unter betroffenen Gegnern werden mitverbraucht und verstärken die Entladung. Die Vorbereitung lässt sich entweder für anhaltenden Schaden oder für diesen Abschluss nutzen. |
| **Ultimate: Seuchengrube / Blutgericht** | Ein stationäres Ritual mit mehreren schlagenden Fluchknoten. Es schwächt Gegner und verstärkt Verfall. Bereits vorhandene eigene Giftflächen speisen das Ritual einmalig; Blutentzug bleibt gedeckelt. Keine zusätzliche dauerhafte Beschwörung. |

**Beispiel:** Schwächezeichen auf einen starken Gegner → Giftfeld unter seine
Gruppe → Blutfluch, wenn Heilung gebraucht wird → Fluchernte für den Abschluss.
Wer die Vorbereitung sofort verbraucht, verzichtet auf einen Teil des weiteren
Schadens und Entzugs. Das schafft eine echte Entscheidung.

### Zuordnung zum bestehenden Baum

| Platz | Ausbau |
|---|---|
| `curse_1` | Fluchgeschoss mit Verfall und kleiner Giftfläche |
| `curse_2` | Verfall: magischen Verfall und zusätzlich Gift verbessern |
| `curse_3` | Fluch der Schwäche |
| `curse_4` | Bösartigkeit: Schaden gegen eigene verfluchte Ziele |
| `curse_5` | Aderfessel statt einer weiteren Nova um den Spieler |
| `curse_6` | Fluchkunde: Fluchgeschoss verbessern |
| `curse_7` | Seuchenfeld mit echtem Giftmedium und begrenzter Wolke |
| `curse_8` | Finstere Haut: Schutz während eigener Flucharbeit, statt höherer Giftimmunität |
| `curse_9` | Blutfluch als aktiver Lebensentzug |
| `curse_10` | Verderbnis: bestehender Grundschaden |
| `curse_11` | Fluchernte statt Schattenflucht |
| `curse_12` | Fluchmeister: bestehende Seelenkostensenkung |
| `curse_13` | Unheil: bestehende Abklingzeitverbesserung, später ggf. Fluchübertragung |
| `curse_14` | Ritual-Ultimate, Arbeitstitel Seuchengrube / Blutgericht |

**Beispielleiste:** Fluchgeschoss · Schwäche · Seuchenfeld · Blutfluch.
Für einen explosiveren Abschluss Fluchernte statt Schwäche oder Feld wählen.

### Elementverhalten: Bestand und neue Vorschläge sauber trennen

Bestand laut `assets/data/element_rules.json`, `src/combat/element_rules.gd`
und `src/combat/elements.gd`:

- Giftbecken/Giftgas sind vorhandene Medien. Feuer kann Gift entzünden und
  begrenzte Kettenexplosionen auslösen. Der Fluchzweig muss dafür kein eigenes
  Feuer bekommen; ein Mitspieler oder vorhandenes Umgebungsfeuer genügt.
- Viele Untote und Giftwesen sind gegen das vorhandene Giftmedium immun.
- Blut ist bereits leitfähiger, rutschiger Boden. Automatische Heilung durch
  Blut ist keine allgemeine bestehende Elementregel.
- Leere/Rifts besitzen bereits das Einsaugen anderer Medien, einschließlich
  Gift und Blut. Das Arkane Gefüge bleibt eine Mechanik des Leerenmagiers.

Neu vorgeschlagen sind der magische Verfall, Aderfessel, die gezielte
Blutentzug-Heilung und Fluchernte. Sie entstehen nicht automatisch daraus,
dass eine Pfütze rot oder grün aussieht. **Blut + Gift bekommt vorerst keine
neue universelle Reaktion**; die Talente verbinden die beiden Wirkungen.
Eine benachbarte Leere kann Material weiterhin nach ihren Regeln entfernen.

Eigene neue Talentflächen sollen der Gruppe eindeutig als verbündet angezeigt
werden und sie nicht versehentlich vergiften. Diese Eigentümerregel müsste
explizit umgesetzt werden; fremde/Umweltflächen bleiben ihren Regeln unterworfen.

### Balance und Inszenierung

Verfall hält den Zweig gegen giftimmune Gegner spielbar, ersetzt aber keine
vorhandenen Immunitäten. Für Blutentzug zählen nur eigener tatsächlich
aufgelöster Schaden und passende eigene Flüche, kein Überkill, keine Leichen
und kein fremder Schaden. Heilung wird über alle Ziele gemeinsam pro Sekunde
gedeckelt, damit eine große Gegnergruppe nicht automatisch unsterblich macht.
Das konkrete Herz-/Schadensmaß muss vor Prozentwerten geprüft werden; die alten
vorläufigen Entzugszahlen sind keine feste Balancevorgabe.

Als erste Testbudgets höchstens drei eigene kleine Giftbecken, eine größere
Seuchenfläche und drei Weitergaben je Fluchauslösung. Eine Giftfläche wird von
Feuer, Fluchernte oder Ritual jeweils nur einmal verbraucht. Keine automatische
Rekursionskette aus Fluchübertragung, Explosion, Heilung und Killbelohnung.

Violette Zeichen für Flüche, Grün für echtes Gift, Rot für Blut/Entzug. Gebundene
Runenteile und gegliederte Adern bewegen sich am Boden beziehungsweise am Ziel.
Der Blutstrom folgt einer klaren Richtung zurück zum Besitzer. Keine Geister-
Armee als Standardbild; die kleinen türkisfarbenen Geister gehören zur Seele.

## Empfohlene Reihenfolge für einen späteren Prototyp

1. Fluch: **Fluchgeschoss → Schwäche → Blutfluch**, anschließend Feld/Fluchernte.
   Damit werden Zielvorbereitung, Immunitäten und begrenzter Entzug zuerst prüfbar.
2. Diener: **Hauptdiener → Belagerungsbefehl → Totenpakt**, danach echte
   Leichenmarken/Explosion und Koloss. Kein Katalog voller neuer Beschwörungen
   vor Prüfung von Zielwahl und Befehlen.
3. Erst an diesen kleinen Ausschnitten Rig-/VFX-Lesbarkeit beurteilen, dann
   restliche Talente und Endwerte ergänzen. Neue Actor-/Bossgrafik erfordert
   weiterhin die vorhandene konkrete Art-Abnahme.

Dieses Dokument aktiviert keine Fähigkeiten, ändert keine Spielwerte und
ist kein Test- oder Balance-Nachweis.
