# Entwicklungsplan: Basement Run mit Godot und Multiplayer

Status: **Entwurf**, Stand 24.10.2026. Zukünftige Spielregeln und Messziele sind
Vorschläge. Der vorhandene kleine Entwicklungsstand ersetzt keinen Nachweis eines
vollständigen Dungeon-Spiels oder belastbarer Vier-Spieler-Performance.

Aktuelles Veröffentlichungsziel auf ausdrücklichen Nutzerwunsch vom 25.10.2026:
`codex_v2` in `ChristopherOko96/2D-PixelDungeon`. Der vorherige V2-Fork bleibt
erhalten; die Unity-Linie auf `main` bleibt getrennt.
Details: [Veröffentlichung](../docs/V2-PUBLISH.de.md).

## Ziel und Herkunft der Anforderungen

Ein 2D-Pixel-Dungeon-Crawler mit Twin-Stick-Kampf, zufällig zusammengesetzten
Räumen und Perks nach Raumerfolgen. Mehrere eigenständige Spielclients sollen
gemeinsam spielen können. The Binding of Isaac ist die spielmechanische Referenz.

| Herkunft | Inhalt | Einordnung |
| --- | --- | --- |
| Erster Nutzerauftrag | 2D-Pixel-Spiel, Raum-Perks, verbundene separate Clients, anfangs bis zu acht Spieler; kleinere Grenze möglich | Ursprünglicher Multiplayer-Rahmen |
| Nutzerkorrektur im selben Auftrag | Godot verwenden; Unity nicht herunterladen | Maßgebliche Engineentscheidung für diese Arbeit |
| Jüngste Nutzerkorrektur | Höchstens vier Spieler jetzt; acht nur als spätere Option. Echte 32×32-Pixelgrafik und gut lesbarer Kampf in Richtung Isaac/Vampire Survivors | Aktueller verbindlicher Umfang |
| Ausgangscommit `e6204688157dbbb6d10faa7906ace5fa482d016d` | @design/game-brief.md: Arbeitstitel Basement Run; Bewegung, Schießen, Gegner, Herzen, Raumvorlagen, etwa fünf Items, ein Stockwerk und Boss | Ursprüngliche Spielidee des Bruders |
| Derselbe Ausgangscommit | Multiplayer im Spielbrief ausgeschlossen; Unity 6.3 LTS in @project.yaml und @CLAUDE.md konfiguriert | Historischer Stand; durch den neuen Auftrag geändert |
| Dieser Entwurf | Kooperativer Hostbetrieb, konkrete Loot-, Todes- und Übergangsregeln sowie Messziele | Vorschläge, keine behaupteten Entscheidungen des Bruders |

Am Ausgangscommit existierten Studio-Anweisungen und Referenzdokumente, aber kein
implementiertes Spiel. `studio-tests/` prüft dieses Studio-Gerüst und enthält keine
ausgeführten Spieltests. Die aktuelle Godot-Grundlage wurde neu im eigenen Branch
angelegt; die folgenden Umsetzungsnachweise gelten für diesen Entwicklungsstand.

## Aktueller Umsetzungsstand

- Der nächste fehlende Kernschritt aus Baufolge 4 / Phase 3 ist umgesetzt:
  [Raumgenerator-Story](epics/dungeon-rooms/story-001-seeded-rooms.md).
  Drei normale Vorlagen plus Bossvorlage ergeben einen verbundenen Drei-Raum-Lauf
  mit Seed, Generatorversion und stabilen IDs. Der Host überträgt die gewählte
  Geometrie; Säulen blockieren Bewegung und beide Projektilarten. Gegner umgehen
  Deckung, eine kleine Raumkarte zeigt Fortschritt und Boss. 4146 Generator-
  und 22 Integrationsprüfungen sowie die bisherigen 21 Spielregeln bestehen.
  Zwei echte Prozesse beenden alle drei identischen Layouts mit sechs Perks;
  die Vierer-Lobby besteht weiterhin. Bild und genaue Prüfgrenzen stehen im
  [Prüfbericht](qa/verification.md#raumgenerator-vom-25102026).

- Phase 0 ist als lokale Entwicklungsgrundlage eingerichtet: portable Godot-
  Version geprüft, `Doctor` und Import-/Parseprüfung erfolgreich. Grafischer
  Spielstart mit Menü und Kampfszene geprüft; Bildbeleg unter
  @production/qa/evidence/godot-prototype.png (**NEU**).
- Die eingebaute Suite **NEU** @tests/game_rules.gd wurde ausgeführt:
  `GAME_RULES checked=21 failures=0`, Exitcode 0. Sie prüft Spielregeln direkt
  mit Godot, darunter finale Belohnung → Ready-Gate → Sieg, doppelte Perks,
  ungültige Eingaben, Wiederbelebung und Teamwipe. Sie ersetzt keine echten Peers.
- Phase 1 ist für zwei getrennte ENet-Prozesse über Loopback belegt. Ein erster
  automatisierter Rauchtest durchlief drei Räume einschließlich Boss bis zum
  Sieg; beide Prozesse endeten sauber mit Exitcode 0.
- Phasen 2–4 sind teilweise als kleiner Prototyp umgesetzt: gemeinsame Bewegung,
  Schießen, Gegner/Boss, fünf einfache datenbasierte Perks und Raumwechsel. Die
  persönliche Auswahl und das gemeinsame Ready-Gate wurden auch nach dem
  Bossraum erfolgreich durchlaufen. Vollständiger Zwei-Prozess-Nachweis:
  `RoomsCleared=3`, `PerksSelected=6`, `RUN_COMPLETED players=2`, Sieg auf beiden
  Seiten, Host-/Client-Exitcode 0, keine stderr-Ausgabe oder MTU-Warnung.
- Prototypregel: Gefallene kehren am nächsten Raum mit 50 % ihres maximalen
  Lebens zurück; nur lebende Teilnehmer müssen bereit bestätigen. Diese Regel
  ist implementiertes Versuchverhalten und noch keine bestätigte Release-Regel.
- Der aktuelle Viererstand besteht Import, 21 Regelprüfungen und die Verbindung
  von Host plus drei Clientprozessen mit sauberem gleichzeitigen Trennen.
  Ein fünfter Teilnehmer wurde im zehnsekündigen Testfenster nicht aufgenommen.
  Alle acht PNG-Quelldateien sind anhand ihrer Bildmaße als 32×32 verifiziert;
  Kampfszene und Vierer-Lobby wurden grafisch geprüft. Der Boss wird aus seiner
  32×32-Quelle bewusst zweifach dargestellt. Nachweise:
  **NEU** @production/qa/verification.md und @production/qa/evidence/godot-lobby-4.png.
- Phase 5 bleibt offen: keine Vier-Spieler-Leistungszusage aus dem konfigurierten
  Limit ableiten. Reales LAN, WAN und Belastung müssen gesondert belegt werden.
- Protokoll-/Inhaltsversionen, Interpolation und Bandbreitenmessung bleiben
  Ausbauaufgaben. Detaillierter Prüfstatus: **NEU** @docs/DEVELOPMENT.de.md.

## Technische Grundlage und Umfang

- **Godot 4.7.2 standard**, GDScript, Compatibility Renderer, Godot Physics 2D.
  Kein .NET-SDK und keine zusätzliche Netzwerkbibliothek für den ersten Stand.
- Einstieg über `project.godot` und `src/main.tscn`; native Godot-High-Level-
  Multiplayer-API mit ENet über UDP. Ein Host spielt mit und führt die
  maßgebliche Simulation aus. Zuerst lokale Verbindung/LAN.
- Aktuelle Obergrenze: **vier Teilnehmer insgesamt = ein Hostspieler plus drei
  Clients**. Zwei getrennte Spielprozesse zuerst prüfen, anschließend vier.
  Acht ist ausschließlich eine spätere Erweiterungsoption; es gehört nicht zur
  aktuellen Abnahme und rechtfertigt kein höheres aktives Sitzungslimit.
- Der kleine spielbare Entwicklungsstand umfasst drei Räume einschließlich Boss
  aus mehreren Vorlagen sowie fünf einfache Perks. Verzweigte Erkundung, ein
  vollständiges produktionsreifes Stockwerk und ausgearbeitete Perk-Kombinationen
  bleiben weitere Arbeitspakete.
- Vorschlag: Windows-PC und Koop im gemeinsamen Raum zuerst. Keine Konten,
  Metaprogression, laufenden Spielbeitritte oder automatische Hostmigration im
  ersten Stand. Gamepad, weitere Plattformen und Persistenz anschließend bewerten.

## Pixelgrafik und übersichtlicher Kampf

Verbindliche Gestaltungsrichtung: echte **32×32-PNG-Sprites** auf einem
32-Pixel-Grundraster, Nearest-Filterung und keine Glättung. NEU @assets/sprites/
enthält die Rasterdateien; NEU @scripts/generate_pixel_assets.gd ist der
Generator. Die tatsächlichen PNG-Maße werden vor einer Erfolgsaussage geprüft.
Vergrößerte primitive Formen allein erfüllen diese Anforderung nicht.

The Binding of Isaac und Vampire Survivors dienen der Kampflesbarkeit als
Referenz: vier klar unterscheidbare Spielerfarben, erkennbare Gegnersilhouetten,
eigene und feindliche Projektile visuell getrennt, sichtbare Treffer- und
Schadensrückmeldung. Im nächsten Grafikdurchgang Idle-/Schussanimationen und
Umgebungsdetails gezielt verbessern. Weitere Bodenvarianten sind für diesen
ersten Umfang nicht erforderlich.

**Abnahme:** PNG-Metadaten bestätigen 32×32 bei den Basissprites. Eine aktuelle
Spielaufnahme zeigt scharfe Pixelkanten und auch mit vier Teilnehmern erkennbare
Spieler, Gegner und Projektilrichtungen. Ein Rastermaß allein belegt noch keine
übersichtliche Kampfszene.

## Architekturvorschlag

Der Host entscheidet über gültige Bewegung, Schussfrequenz, Projektilentstehung,
Treffer, Schaden, Gegner, Raumabschluss und Belohnungen. Clients senden Eingaben
und zeigen den bestätigten Zustand an. Für jede Spielaktion werden Absender,
Besitz, Phase, Wertebereiche und Rate geprüft. Ein Client darf sich weder Schaden
noch Perks selbst verbindlich zuweisen. Wiederholte Auswahl- oder Ready-Anfragen
bewirken keinen zweiten Effekt. Hostautorität verhindert kein Cheating durch den
Host selbst; ein dedizierter Server wäre eine spätere eigene Ausbaustufe.

Raumfolge und Vorlagenwahl entstehen aus Seed und Generatorversion. Der Host
bestätigt Raumkennung und dynamischen Spielzustand. Derselbe Seed macht
Godot-Physik nicht deterministisch; Kampf und Gegner werden maßgeblich simuliert
und verteilt. Interpolation und bei Bedarf Vorhersage folgen einer funktionierenden
und gemessenen Grundverbindung.

Spielwerte und Perks werden als Daten gehalten. Netzwerk, Darstellung, Eingabe
und Spiellogik erhalten im weiteren Ausbau getrennte Module. Der kompakte
Prototyp darf diese Grenzen zunächst in wenigen Dateien abbilden; vor weiterem
Inhalt muss seine Aufteilung mit Tests abgesichert werden.

## Aufgaben nach Phasen

`@pfad` bezeichnet einen am Ausgangscommit vorgefundenen Projektpfad. **NEU**
bezeichnet ein neu angelegtes oder vorgeschlagenes Ziel dieses Entwicklungszweigs;
diese Pfade sind keine Belege für vorhandene Implementierung im Originalstand.

### Phase 0 — Godot-Umgebung und kleiner Einstieg

1. Eigene Arbeitskopie mit Branch `codex/development-environment-plan` verwenden;
   @.gitignore, @.gitattributes und @CONTRIBUTING.md berücksichtigen. Historische
   Unity-Einstellungen auf die vom Nutzer gewünschte Godot-Grundlage umstellen.
2. Godot 4.7.2 als portable Standardausgabe bereitstellen; vollständige Ausgabe
   von `--version` und Downloadprüfsumme festhalten. NEU
   @scripts/godot-environment.json und @scripts/Dev.ps1 pinnen und prüfen die
   Engine. Maschinenpfade bleiben in ignorierter lokaler Konfiguration.
3. NEU @project.godot, @src/main.tscn, @src/game.gd und @src/dungeon_view.gd:
   startbarer 2D-Raum, einfache Eingabe und erkennbare Platzhalterdarstellung.
   Godot-Ressourcen und Szenen im nativen Format pflegen; Cache nicht versionieren.
4. NEU @docs/DEVELOPMENT.de.md: Editorstart, Spielstart, Host/Join und Import-/
   Parseprüfung dokumentieren. Die eingebaute `SceneTree`-Suite NEU
   @tests/game_rules.gd und die unabhängigen Prozessprüfungen NEU
   @tests/network_smoke.ps1 gezielt ausführen und ausbauen. Ein erfolgreicher
   Parsecheck ist kein Gameplaytest. Exporte benötigen passende Export-Templates
   und Export-Presets.

**Abnahme:** `Doctor` bestätigt den tatsächlichen Enginepatch und Featurebranch.
`Check` importiert das Projekt und lädt die Spielskripte ohne Parse-/Scriptfehler;
auch Fehler bei Exitcode 0 müssen auffallen. `Run` zeigt den kleinen Spielstand.
Fehlende Exporte, Tests oder manuelle Sichtprüfung werden getrennt benannt.

### Phase 1 — zwei eigenständige Prozesse verbinden

1. NEU @src/game.gd: Hoststart, ENet-Verbindung, Lobby, Teilnehmerzuordnung,
   Kapazitätsgrenze und verständliche Fehlermeldungen. Standardport: UDP 7777.
2. Host und Client zuerst auf `127.0.0.1`, danach auf zwei Rechnern im LAN starten.
   Getrennte Prozesse beweisen mehr als zwei Ansichten einer Editorinstanz.
3. Beitritt, volle Sitzung, ungültige Adresse und Client-/Hosttrennung gezielt
   prüfen. Vor Freigabe Protokoll-/Inhaltsversionen beim Verbindungsaufbau abgleichen.

**Abnahme:** Zwei Spielprozesse sehen dieselben zwei Teilnehmer im selben Raum.
Ein Clientabbruch räumt seinen Teilnehmerzustand auf. Hostverlust wird erkennbar
gemeldet. Ein Loopback-Nachweis allein ist kein LAN- oder WAN-Nachweis. Diese
Phase wird vor einem vollständigen Solospiel bearbeitet.

### Phase 2 — gemeinsamer Kampf und geprüfte Eingaben

1. NEU @src/game.gd weiterentwickeln: Bewegung, getrenntes Zielen, Schießen,
   Gegner, Schaden und Tod aus @design/game-brief.md für zwei Spieler abbilden.
2. Absender, Eingabegrenzen, Feuerrate und Phase auf dem Host prüfen. Fremde
   Spielfiguren steuern oder beliebigen Schaden übertragen darf wirkungslos bleiben.
3. Vor Erweiterung in NEU @src/player/, @src/combat/ und @src/networking/
   aufteilen, wenn die wachsende Komplexität dies rechtfertigt. Tests sichern
   Formeln und Zustandswechsel, Prozessprüfungen sichern die Replikation.

**Abnahme:** Beide Spieler bewegen sich und treffen denselben Gegner.
Gegnerlebenspunkte, Spielerleben und Tod stimmen nach Zustandsabgleich überein.
Ungültige Eingaben verändern keinen unzulässigen Zustand. Sichtbares Verhalten
wird im laufenden Spiel geprüft und mit Bildbelegen dokumentiert.

### Phase 3 — Räume, Übergänge und Perks

1. NEU @src/dungeon/ und @assets/data/: zusammenhängende Raumfolge aus Vorlagen,
   Seed, Generatorversion und stabilen Kennungen. Der Host bestätigt den Raum-
   und Kampfzustand. NEU @src/perks/: stabile IDs, Effekte und Stapelregeln.
2. **Vorschlag:** Jeder berechtigte Spieler erhält nach jedem abgeschlossenen
   Kampfraum genau eine persönliche Perk-Auswahl. Der Host bestätigt Angebot und
   Auswahl genau einmal. Der erste Entwicklungsstand darf diesen Ablauf mit
   wenigen einfachen Perks erproben, ohne fünf fertige Perks vorzutäuschen.
3. **Vorschlag:** Gemeinsamer Raumwechsel erst nach Kampf, Auswahlphase und
   Bereitschaft aller verbundenen lebenden Spieler. Tote/getrennte Spieler
   blockieren den Übergang nicht. Abbrüche aktualisieren die Teilnehmermenge.
4. **Vorschlag:** Neue Beitritte nur in der Lobby, kein Reconnect in laufende
   Läufe. Aktuelle Prototypregel: Gestorbene beobachten bis zum nächsten Raum und
   kehren dann mit 50 % maximalem Leben zurück; als Produktregel noch abzustimmen.
   Teamwipe beendet den Lauf. Hostverlust beendet die Sitzung mit Meldung, ohne
   automatische Hostmigration.

**Abnahme:** Zwei Clients stimmen bei Raumkennung und Inventar überein. Doppelte
Auswahl gewährt keinen zusätzlichen Perk. Türkontakt vor Kampfabschluss wechselt
keinen Raum. Clienttrennung während der Auswahl, Teamwipe, Hostverlust und
unerlaubter später Beitritt werden geprüft. Einzelne bereits funktionierende
Prototypabläufe werden von noch offenen Regeln getrennt protokolliert.

### Phase 4 — vollständiger gemeinsamer Lauf

1. @design/game-brief.md mit den abgestimmten Multiplayer-Regeln und der
   Pixel-Art-Richtung pflegen. Historische Aussagen bleiben in der Bestandsaufnahme
   nachvollziehbar; neue Regeln müssen als solche erkennbar sein.
2. NEU @assets/data/, @assets/sprites/ und @src/rooms/: Raumvorlagen, ungefähr
   fünf unterscheidbare kombinierbare Perks und Boss ergänzen. Platzhalter durch
   eigene, lizenzierte Pixel-Assets und Audio ersetzen.
3. Lobby → mehrere Kampfräume mit Belohnungen → Boss → Ergebnis → neuer Lauf
   schließen. HUD für eigenes Leben, Team und Perks; Gamepad anschließend ergänzen.

**Abnahme:** Zwei Spieler beenden einen vollständigen Gewinn- und Verlustlauf.
Neustart übernimmt keine alten Gegner oder Perks. Fünf Perks wirken verschieden;
mindestens zwei Kombinationen werden anhand ihrer Daten geprüft. Ein unendlicher
Prototypraum mit Wellen gilt nicht als fertiges Stockwerk mit Boss.

### Phase 5 — Kapazität, LAN und Internet belegen

1. Sitzungen mit 2 und 4 Teilnehmern testen: Host plus 1 oder 3 Clients.
   Mindestens zwei reale Rechner einsetzen. Mehrere Prozesse auf einem Rechner
   zeigen Funktion, aber keine Performance auf der späteren Zielhardware.
2. **Vorgeschlagenes Netzwerktestziel:** 100 ms RTT und 1 % Paketverlust bei
   Bewegung, Schüssen, Kampfabschluss und Perkauswahl. Messmethode, Simulator,
   Dauer und Zustandskorrekturen dokumentieren. Zusätzlich mindestens 30 Minuten
   ungestörtes LAN ohne Absturz, doppelte Belohnung oder bleibende Abweichung.
3. **Vorgeschlagenes Darstellungsziel:** 60 FPS. Referenzhardware, Auflösung,
   Gegner-/Projektilzahl und Messmethode sind offen. Ohne dieses Szenario keine
   Performancezusage. Vier Spieler benötigen zusätzlich einen vollständigen
   Boss- und Belohnungsdurchlauf mit Netzwerk- und Framemessungen.
4. Nach LAN folgt ein Test über zwei echte Internetanschlüsse. ENet verwendet
   UDP; Router, NAT, Hostadresse und Firewall müssen tatsächliche Erreichbarkeit
   erlauben. Ein Relay ist ein gesondertes Architektur-/Betriebsprojekt und
   derzeit nicht konfiguriert. Keine Unity-Relay-Abhängigkeit hinzufügen.
5. CI für Import/Parsechecks und echte Spieltests einrichten. Windows-Exporte
   erst mit passenden Godot-Export-Templates und einem geprüften Preset
   automatisieren. Leere Tests oder Studio-Textprüfungen gelten nicht als Spieltest.

**Abnahme:** Die freigegebene Spielergrenze folgt den bestandenen Prüfungen.
Vier Spieler werden erst mit Nachweis unterstützt genannt. WAN bleibt ungeprüft,
solange kein echter WAN-Test vorliegt. Fehler führen zu weiterer Arbeit oder einer
ausdrücklich kleineren Grenze, nicht zu einer unbelegten Vier-Spieler-Zusage.
Eine spätere Erweiterung auf acht benötigt einen eigenen Umfangsentscheid und
erneute Kapazitäts-, Lesbarkeits- und Belastungsprüfungen.

## Abhängigkeiten und Risiken

Phase 0 → 1 → 2 → 3 → 4 → 5. Netzwerkprüfungen begleiten ab Phase 1 jede Änderung.
Frühe Vier-Teilnehmer-Checks sind sinnvoll; sie ersetzen keinen kompletten
Lauf mit gemessener Last. Benötigt werden die gepinnte portable Engine, später
Export-Templates, zwei Testrechner und für WAN zwei Internetanschlüsse.

| Offener Punkt | Vorschlag | Noch abzustimmen oder nachzuweisen |
| --- | --- | --- |
| Spielergrenze | Aktuell höchstens vier insgesamt, zwei zuerst belegen | Viererbetrieb mit vollständigem Lauf und Messungen; acht nur spätere Option |
| Koop | Gemeinsamer Raum | Friendly Fire, Spielerkollision, Schwierigkeitsskalierung |
| Perks | Persönliche Auswahl je erfolgreichem Kampfraum | Auswahlangebot, Stapelgrenzen, tote Spieler |
| Tod und Übergang | Prototyp: Rückkehr im nächsten Raum mit 50 % maximalem Leben; Ready-Gate nur für Lebende | Endgültige Wiederbelebungsregel, Timeout, Untätigkeit |
| Verbindung | Host/ENet/LAN zuerst | Reconnect, Relay, dedizierter Server |
| Darstellung | Echte 32×32-PNG-Sprites, Nearest, lesbarer Kampf | PNG-Metadaten, Vier-Spieler-Übersicht, Animation/Umgebung und Audio |
| Leistung | Vorgeschlagene 60 FPS | Referenzhardware, Lastszenario und Messwerte |

Die Nutzerkorrektur bestimmt Godot als Engine. Konkrete Detailregeln werden mit
dem Bruder vor ihrer endgültigen Umsetzung abgestimmt und im Spielbrief erfasst.

## Branch, Fork und spätere Zusammenführung

Arbeitsbranch: `codex/development-environment-plan`, abgeleitet von `origin/main`.
Die lokale Arbeitskopie ist kein neu angelegter GitHub-Fork. Weitere Änderungen
in überschaubaren `codex/<thema>`-Branches entwickeln. Vor Veröffentlichung Diff,
Status und tatsächliche Prüfungen kontrollieren. Bei Pushrechten ist ein Branch
im Ursprungsrepository mit PR gegen `main` möglich; alternativ ein persönlicher
Fork mit dem Original als `upstream`. Keine vorhandenen Remotes grundlos ändern.
Zusammenführung erfolgt nach Review; kein automatischer Merge oder direktes
Arbeiten auf `main`.
