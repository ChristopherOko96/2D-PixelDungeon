# Menüführung: Befund und Arbeitsgrundlage

09.11.2026 · Basis `676af43a` plus lokale Kamerakorrekturen · Branch `main`.

## Auftrag und Grenzen

Die Menüführung wird anhand von Fachliteratur, etablierten Richtlinien und
vergleichbaren Spielen überarbeitet. Dungeonfehler werden getrennt davon
behoben: Rätselregeln, Lösungen, Belohnungen und Schwierigkeitsparameter bleiben
erhalten. Beim Labyrinth ist das vorzeitige Einsehen der Wege der Fehler,
nicht die grundsätzliche Sichtweitenmechanik.

Dies ist eine heuristische Prüfung mit Codeinspektion und Aufnahmen der echten
Krypta-Menüs. Sie ist keine Studie mit Spielern und keine UX-Zertifizierung.
Die folgenden Zielwerte und Layoutentscheidungen sind projektspezifische
Ableitungen; die Quellen schreiben dieses konkrete Layout nicht vor.

## Quellen und ihre Verwendung

- **Celia Hodent (2016): Cognitive Psychology Applied to User Experience in
  Video Games.** Beitrag zur Springer-Enzyklopädie, von der Autorin öffentlich
  wiedergegeben. Wahrnehmung, Aufmerksamkeit und Gedächtnis begrenzen die
  Bedienung; unnötige Verwirrung ist von beabsichtigter Spielherausforderung zu
  unterscheiden. Grundlage für die Trennung zwischen anspruchsvollem Kampf und
  unkomplizierter Verwaltung. [Autorenfassung](https://celiahodent.com/cognitive-psychology-applied-to-user-experience-in-video-games/).
- **Desurvire & Wiberg (2009): Game Usability Heuristics (PLAY)**, OCSC,
  LNCS 5621, S. 557–566, DOI 10.1007/978-3-642-02774-1_60.
  Wissenschaftlich publizierte Grundlage für eine frühzeitige heuristische
  Bewertung. Hier wurden Abstract und bibliografische Angaben geprüft; der
  kostenpflichtige Volltext wird nicht als gelesen ausgegeben.
  [Verlag](https://link.springer.com/chapter/10.1007/978-3-642-02774-1_60).
- **Jakob Nielsen: 10 Usability Heuristics.** Konsistente Bedienung,
  erkennbare Zustände, Fehlervermeidung und sichtbare Wahlmöglichkeiten bilden
  den allgemeinen Prüfrahmen. Eine übersichtliche Oberfläche darf relevante
  Informationen nicht unauffindbar machen.
  [Original](https://www.nngroup.com/articles/ten-usability-heuristics/).
- **Microsoft Xbox Accessibility Guidelines 112 und 113.** Vorhersehbare
  Navigation per Tastatur und digitalem Controller, konsistente Positionen,
  sichtbarer Fokus und auf den aktiven Dialog begrenzter Fokus. Diese
  Branchenrichtlinien sind keine Behauptung, das Projekt erfülle bereits alle
  Anforderungen. [Navigation](https://learn.microsoft.com/en-us/xbox/accessibility/xbox-accessibility-guidelines/112),
  [Fokus](https://learn.microsoft.com/en-us/xbox/accessibility/xbox-accessibility-guidelines/113).
- **XAG 101: Text display.** Text muss anpassbar bleiben, ohne Inhalt oder
  Bedienbarkeit zu verlieren. Gemessene Glyphenhöhe ist maßgeblich; Godots
  `font_size` allein belegt keine Lesbarkeit. Skalierung bis 200 Prozent und
  vertikales Scrollen bei langen Inhalten dienen als Prüfziele.
  [Textdarstellung](https://learn.microsoft.com/en-us/xbox/accessibility/xbox-accessibility-guidelines/101).

## Vergleichbare Spiele: gezielt übertragbare Muster

**Brotato:** Der Entwickler beschreibt kurze Kampfwel­len und Einkäufe zwischen
den Wellen. Daraus leiten wir eine klare Trennung zwischen Kampfaufmerksamkeit
und Build-Entscheidungen ab. Wir übernehmen keine Shop-Pflicht für diese
Dungeon-Kampagne. [Offizielle Produktbeschreibung](https://store.steampowered.com/app/1942280/Brotato/).

**Shattered Pixel Dungeon:** Im Entwicklerbericht vom 31.01.2022 werden
Gegenstandsfenster unmittelbar am Inventar angeordnet, um Mauswege zu verkürzen;
ausblendbare Inventaransichten und kontextbezogene Hinweise werden beschrieben.
Das ist ein historisch dokumentiertes Gestaltungsmuster, keine Prüfung der
aktuellsten Spielversion. Für uns: Auswahl, Erklärung und Aktion gehören
räumlich zusammen. [Entwicklerbericht](https://www.patreon.com/ShatteredPixel/posts/inventory-weekly-61868286).

## Reproduzierter Ist-Zustand

Echte GPU-Aufnahmen mit unverändertem Menücode, 1280×720, Schwertkämpfer,
isolierte Speicherpfade. Keine Benutzer-Spielstände verändert.
[Aufnahmen](../production/qa/evidence/menu-ux-2026-11-09/03-status-and-inventory.png).

| Priorität | Befund | Beleg | Konsequenz |
| --- | --- | --- | --- |
| P0 | Pause → Inventar hebt die Pause auf. | `pause_menu.gd:607` versteckt die Pause; `hell_game.gd:_simulation_paused` berücksichtigt das Inventar nicht. Laufzeitprobe: `paused=true` → `false`. | Spieler können beim Lesen unbemerkt gefährdet werden. |
| P0 | Status und Inventar lassen sich gleichzeitig öffnen und verdecken sich. | `C`/`Tab` ändern `state.status`, `I` öffnet separat das Inventar. Aufnahme 03 zeigt abgeschnittene Statuswerte. | Zusammengehörige Informationen sind nicht gemeinsam lesbar. |
| P1 | Inventaraktionen sind mausgebunden. | `inventory_panel.gd:_button` verwendet `FOCUS_NONE`; Slotauswahl in `_gui_input` nur per Maus. | Die vorhandene gute Fokusnavigation der Pause endet beim Inventar. |
| P1 | Detailtext hat keine vertikale Begrenzung. | `_draw_details` bricht Zeilen um, erhöht `y` unbegrenzt, hat aber keinen Scrollbereich. Aktionszeilen liegen unabhängig davon am unteren Rand. | Längere Affix-/Fluch-/Effekttexte können Aktionen überdecken. Codebefund, im Startinventar noch kein langer Gegenstand. |
| P1 | Statusfenster reserviert bei Karten zusätzliche Höhe, unabhängig von der Bildschirmhöhe. | `frost_hud.gd:status`: Unterkante mit Karten bei y=728 in einer 720er Fläche; Kartenliste auf sechs Einträge beschnitten. | Footer und vollständiger Build können verloren gehen. |
| P1 | HUD zeigt dauerhaft breite Verwaltungsflächen. | Aufnahme 01: großer Klassen-/LP-/Stufenblock, Geldzeile und Kartenblock. | Weniger nutzbare Sichtfläche im Dungeon; widerspricht der Nutzerpriorität. |
| P2 | Werte wirken ohne Bezugsgröße widersprüchlich. | Aufnahme 03: Status-Schaden 2,3, Gegenstandsschaden 5,0. | Berechnung und Bedeutung prüfen; Basiswert, effektiver Wert und Bedingungen kenntlich machen, nicht Zahlen willkürlich angleichen. |
| P2 | Reihenfolge beim Schließen ist nur intern definiert. | Nach C → I → Esc bleibt Status offen. | Ein gemeinsames Menü mit klarer Rückkehr ersetzt den verdeckten Fensterstapel. |

Positiv: Die Pause hat bereits sichtbaren Fokus, eine geordnete Navigation und
eine gemeinsame Seite für Etagenziele und Karte. Haupt- und Nebenaufgaben sind
unterscheidbar. Diese Struktur bleibt als Grundlage erhalten. Die Hauptmenü-
Quellprüfung zeigt getrennte Wege für Spielen und Custom Storys sowie einen
separaten Debug-Bereich; deren vollständiger Bedienungstest steht noch aus.

## Zielbild und Reihenfolge

1. **Ein aktives Verwaltungsfenster.** C und Tab führen zur gleichen Ansicht
   „Charakter & Inventar“. I bleibt als vertrauter Direktzugang erhalten.
   Links Charakterwerte und Ausrüstung, mittig das Inventarraster, rechts
   Details und passende Aktionen. Größere Inhalte scrollen innerhalb ihrer
   Spalte. Keine Texte dürfen in Aktionsflächen wachsen.
2. **Vorhersehbare Rückkehr.** Aus der Pause geöffnetes Inventar bleibt im
   Solo-Lauf pausiert und kehrt zur Pause zurück. Direkt geöffnetes Inventar
   kehrt zum Spiel zurück. Esc schließt nur die aktive Ebene; kein Eingabe-
   Durchschlag in Angriff, Bewegung oder Trankverbrauch. Andere Menüziele
   dürfen keinen unsichtbaren Fensterstapel hinterlassen.
3. **Ruhiges HUD.** LP und kampfrelevante Zustände bleiben sichtbar, aber
   kompakt. Karte, Rauminformationen, Ziele und ausführliche Buildwerte liegen
   in den Menüs. Boss-LP nur im tatsächlichen Bosskampf. Relevante Meldungen
   dürfen kurz erscheinen, ohne dauerhaft Flächen zu belegen.
4. **Eine Bedienlogik.** Sichtbare Beschriftung plus Symbol; Maus, Pfeiltasten
   und Controller erreichen die gleichen Aktionen. Details auch bei Fokus,
   nicht ausschließlich bei Hover. Wiederöffnen behält eine sinnvolle Auswahl.
   Gefährliche Aktionen sind vom Ausrüsten räumlich getrennt.
5. **Begriffe und Darstellung.** Laufboni und dauerhafte Talente eindeutig
   kennzeichnen. Die vorhandene Pixelart bleibt; Lesbarkeit, Kontrast und
   ausreichend Platz haben Vorrang vor zusätzlichen Animationen.

Die Story-Runtime ist derzeit solo. Diese Pausenregel darf nicht blind auf den
separaten autoritativen Mehrspielermodus übertragen werden. Dort muss ein
lokales Menü seinen Zustand „Spiel läuft weiter“ sichtbar machen, ohne die
Sitzung anderer Spieler anzuhalten.

## Prüfkriterien für die Umsetzung

- C und Tab öffnen dieselbe Ansicht; keine überlappenden Status-/Inventarfenster.
- Pause → Inventar → Zurück hält den Solo-Simulationstakt durchgehend an.
- Jeder Eingabeweg erreicht Ausrüsten, Benutzen, Details und Zurück; der aktive
  Fokus bleibt sichtbar und kann keine Elemente hinter dem Menü aktivieren.
- Lange Namen, mindestens zwölf Effektzeilen, voller Rucksack und viele
  Laufboni bleiben erreichbar. Keine Text-/Buttonüberschneidung.
- Aufnahmen bei 1280×720, 1920×1080, 2560×1080 und 1024×768 sowie größerem Text;
  Screenshots prüfen Layout, Zustandsprüfungen prüfen die Bedienlogik.
- Der anschließende persönliche Playtest nutzt konkrete Aufgaben:
  Waffenvergleich, Ausrüsten, Laufbonus finden, Kartenansicht öffnen, zum Spiel
  zurückkehren. Zeit, Irrwege und Fehlaktionen erfassen. Erst danach lässt sich
  eine tatsächliche Verbesserung der Spielerfahrung bewerten.

## Umsetzung (09.11.2026, zweiter Schritt)

Weitere Quellen für die HUD-Entscheidungen:

- **Nielsen, Heuristik 8 „Aesthetic and minimalist design“** (Quelle oben):
  Jede zusätzliche Information konkurriert mit der relevanten. Begründet,
  warum Gold, Runen und Karte nicht dauerhaft im Kampfbild stehen.
- **Fagerholt & Lorentzon (2009): Beyond the HUD**, Masterarbeit, Chalmers.
  Unterscheidet diegetische und nicht-diegetische Anzeigen; dauerhafte
  Overlays sollen nur tragen, was der Spieler im Moment braucht. Hier nur als
  Begriffsrahmen verwendet.
- **Hodent (2017): The Gamer's Brain**, CRC Press. Aufmerksamkeit ist begrenzt;
  Verwaltung (Werte, Ausrüstung) gehört getrennt von der Kampfaufmerksamkeit.
  Begründet die Pause im Charakterfenster.
- **Genre-Vorbilder:** Diablo II zeigt Charakterwerte (C) und Inventar (I)
  nebeneinander auf einem Bildschirm; daraus das eine Fenster „Charakter &
  Inventar“. Hades kommt ohne dauerhafte Minikarte aus; Enter the Gungeon
  macht die Karte abrufbar. Daraus: Karte auf M und in der Pause, nicht in der
  Ecke. Nur die Muster werden übernommen, kein Aussehen.

| Befund | Umsetzung | Beleg |
| --- | --- | --- |
| P0 Pause → Inventar hebt Pause auf | Das Fenster pausiert selbst (`_simulation_paused`); aus der Pause geöffnet kehrt es beim Schließen in die Pause zurück (Signal `closed`). Werfen geht in die Welt, nicht zurück. | `tests/story_menu_flow_test.gd` 18/18 |
| P0 Status und Inventar überlagern sich | C, Tab und I öffnen dasselbe Fenster: links CHARAKTER (Name, Laufstufe, Werte rechtsbündig, Karten mit „+n weitere“), rechts INVENTAR. Talente (K/B) ersetzen es, statt sich zu stapeln. Tasten hinter dem Fenster lösen keine Fähigkeiten aus. | Aufnahme `after/03-character-window.png` |
| P1 Aktionen nur per Maus | Aktionsknöpfe sind fokussierbar (Enter). Pfeiltasten-Navigation über die Fächer steht noch aus. | Testprüfung `focus_mode` |
| P1 Detailtext ohne Grenze | Details enden über den Aktionsknöpfen mit „...“. | Code `_details_end` |
| P1 Status-Höhe über 720 px | Kartenliste endet am Fensterrand mit „+n weitere“. | Code `_draw_character` |
| P1 Breite Verwaltungsflächen | Heldenleiste einzeilig (Leiste 180 px, LP, Stufe), Name nur im Charakterfenster; Gold und Runen in der ausblendenden Ressourcenzeile; keine Minikarte in der Ecke (`ui_hud_style.json` `story_minimap`), nur ein Chip „VERRIEGELT · n“ im Kampfraum. | Aufnahme `after/01-hud-labyrinth-outside.png` |
| P2 Schaden 2,3 vs. 5,0 | Geprüft: 2,3 ist der echte Trefferschaden (Basis × Karten × Talente × Ausrüstung über `CardKit.damage_mult`). Die 5,0 im Gegenstand ist die eigene Skala des Item-Systems. Statuszeile heißt jetzt „Treffer“. Eine gemeinsame Einheit braucht eine Designentscheidung. | Code `frost_hud.gd status_sheet` |
| Labyrinth von außen einsehbar | Die Labyrinthzone ist von außen so dunkel wie das Ungesehene innen (`world_maze.json` `outside_cover`); beim Betreten blendet die Abdeckung aus und die Sichtstrahlen übernehmen. | `tests/maze_rooms_test.gd` 12/12, Aufnahmen `after/01`, `after/02` |

## Dungeon- und Rätsellogik (Prüfung 09.11.2026)

Codeprüfung von `frost_puzzles.gd`, `hell_puzzles.gd` (Teile) und den Sturz-,
Lösungs- und Feuerschalen-Pfaden in `hell_game.gd`. Regeln bleiben, nur
Widersprüche zwischen Regel und Umsetzung werden behoben.

| Befund | Bewertung | Umsetzung |
| --- | --- | --- |
| Labyrinth vor dem Betreten einsehbar | Widerspricht der Dunkel-Regel | behoben (siehe oben) |
| Frostgruft: Nach dem Einbruch steht der Held an der Rune, die Meldung sagt „Zurück an den Rand“ | Text widerspricht dem bewusst gewählten Code | Meldung sagt jetzt „Zurück an der Rune“ |
| Frostgruft: Ein Teleport (Sturz zurück zum Start) wird als Laufweg über alle Zellen verrechnet; Glut erlischt sofort, eine Eisplatte verliert einen Halt, ohne dass jemand sie verlassen hat | Widerspricht „Glut hält *Schritte*“ und „Eis zählt beim Verlassen“ | Sprünge über mehr als 2 Zellen gelten als Teleport, nicht als Schritt (`TELEPORT_CELLS`) |
| Hölle: Sturz in eine Grube während einer Opfergruben-Welle löscht den Kampf; die Welle zählt als überstanden, der Schatz steigt eine Stufe | Belohnung ohne Leistung | Die Welle verebbt ungeschlagen (`abort_waves`), am Altar neu rufbar |
| HUD-Zähler der Feuerschalen kennt nur die Gruppe „feuer“; Glut-Räume der Frostgruft mit eigenen Gruppen zeigen keinen Zähler | Nur Anzeige, Toasts melden den Fortschritt | offen, nicht geändert |
| Hölle: Gehobene Brücke über trockenem Kanal ist nicht heiß | Nur relevant, wenn ein Raum beides auf eine Zelle legt; nicht belegt | offen, nicht geändert |

Geprüft und schlüssig: Jeder Frost-Rätselraum mit Schneeball, Eisblock, Glut,
Frostherz oder dünnem Eis hat eine Frostrune; jeder Höllen-Rätselraum mit
Brücke, Ventil, Rohr, Schlot, Auge oder Flut hat eine Höllenrune. Ein
verlorener Schneeball sperrt also keinen ausgelieferten Raum. Rätselzustand
wird beim Laden einer Etage neu aufgebaut. Nicht geprüft: Wiederherstellung
von Rätselzuständen aus Spielständen, `room_weather.gd`.

Status: Menü- und HUD-Befunde umgesetzt; offen sind Pfeiltasten-Navigation im
Inventar, die gemeinsame Schadenseinheit und ein Spielertest mit Aufgaben.
