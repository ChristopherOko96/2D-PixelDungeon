# Polish-Audit: Delve Disaster, Story-Welten (Krypta, Frostgruft, Hölle)

**Story-Typ**: Visual/Feel + UI (Audit, kein Story-Abschluss) · **Ablage**: `production/qa/evidence/polish/` · **Gate**: ADVISORY (reiner Befund, nichts freigegeben)
**Datum**: 2026-11-01 · **Build**: Arbeitsstand `codex_v2` (uncommitted Änderungen enthalten) · **Engine**: Godot 4.7.2, Fenster 1280×720, Compatibility/OpenGL, AMD RX 6600
**Tester**: qa-tester (Agent) · **Spielcode**: nicht verändert

## Methode
Ich habe eine temporäre SceneTree-Probe zweimal laufen lassen und danach wieder gelöscht. Sie hat jede Welt-Szene direkt instanziiert, mit
`settings_path`/`graphics_path` = `user://settings_test.cfg`, eigener Meta-Datei und eigenem Save-Ordner. Der Held war unverwundbar (`state.inv`)
bis auf die Tod-Aufnahme. Bilder: `force_draw` + Viewport-Textur. Klassen: Krypta = Schwertkämpfer, Frostgruft = Magier,
Hölle = Nekromant, Hölle = Bogenschütze (Tod), Hölle = Schwertkämpfer (Optionen/Steuerung). Die echte `settings.cfg`, `profile.json` und
`frost_meta.cfg` sind unverändert (Zeitstempel geprüft). Die Testdateien sind gelöscht.
Schriftgrößen habe ich am 1280×720-Bild geschätzt, nicht gemessen. Ton lässt sich mit Screenshots nicht prüfen.

## Rangliste

| # | Schwere | Bildschirm · Bild | Was ist falsch | Vorschlag (vermutliche Datei/Funktion) | Aufwand |
|---|---|---|---|---|---|
| 1 | **Hoch** | Frostgruft · Talente, Inventar, Minimap · 14, 15, 11, 09 | Schneesturm-Partikel (weiße Striche und Punkte) liegen **über** allen UI-Fenstern. Der Talentbaum und die Beschreibungen sind durchzogen, die Minimap hat Querstriche. | Schnee-Layer (`snowstorm`/`frost_snow`, `src/hell/frost_fx.gd`, Aufbau in `hell_game.gd`) auf einen CanvasLayer **unter** HUD/Fenstern legen oder in `_sync_overlays()` ausblenden, solange ein Fenster offen ist. | S |
| 2 | **Hoch** | Hölle · Nekromant · 16 (Log) | `ERROR: Resource file not found: res://assets/sprites/0x72/items/staff_necro.png` aus `sub_kit.gd:96 apply()` (über `load_floor`). Das Zepter des Nekromanten fehlt; im Bild ist der Held zwischen den Gegnern nicht zu finden. | Asset anlegen oder Pfad im Klassen-/Sub-Kit-Eintrag korrigieren (`src/hell/sub_kit.gd` `apply`, Theme-JSON). Fehlende Waffentextur mit Fallback + Warnung abfangen. | S |
| 3 | **Hoch** | Krypta · Nahkampf · 01, 03, 04 | Der Held geht im Getümmel unter. Die Skelett-Schwerter sind etwa doppelt so groß wie die Körper und werden **über** dem kleinen, dunkel-türkisen Helden gezeichnet. In 04 ist er völlig verdeckt. | Held immer über Mob-Waffen zeichnen oder bei Verdeckung eine Silhouette/Outline (Actor-Zeichenreihenfolge in `hell_game.gd`, `actors`-Layer). Skelett-Waffen kleiner skalieren (`assets/data/krypta_monsters.json`). | M |
| 4 | **Hoch** | Frostgruft · Kampf · 09, 10, 12, 13 | Weiß auf Weiß: Schneeboden, blassblaue Eis-Skelette und ein weißer Magier. Gegner und Held haben kaum Kontrast, der Boden überstrahlt alles. | Bodenhelligkeit und Grading in `assets/data/frost_theme.json` (`grade`/`shade`) senken. In der Frostgruft dunkle Kontur oder Schlagschatten für Actors (`src/hell/frost_rigs.gd`). | M |
| 5 | **Hoch** | Talentfenster · 14, 23 | Viel Text liegt bei etwa 9–11 px: „noch frei wählbar“, „Aktiv/Passiv“, Spalte „ST 2 · 2 P“, Beschreibungen, Voraussetzung. In der kleinen Schrift sehen **5 und S gleich aus**: „30/40/S0 %“, „Zurücksetzen · S0 Gold“, „ST 2S“, „Fähigkeiten auf S und 6“. | Talentfenster (`run_talents`, Aufbau in `open_run_talents()`): mindestens 16 px. Glyphe „5“ in der kleinen Pixelschrift unterscheidbar machen (`src/pixel_style.gd` `create_font` bzw. Font-Asset). | M |
| 6 | **Hoch** | Hölle · Giftgas · 17 | Die Giftwolke ist eine **opake** grüne Fläche mit Blasenrand. Ein Gegner darin ist vollständig verdeckt. Sie liest sich als gezeichnete Form, nicht als Gas. | Gas mit Dither/Alpha in Pixelkörnung zeichnen und Mobs darüber oder mit Kontur (`src/hell/story_elements.gd`, Gas-Zeichnung). | M |
| 7 | Mittel | Inventar, Talente, Ergebnis · 11, 14, 15, 27 | In Großbuchstaben-Texten erscheinen die Umlaute klein: „RüSTUNG“, „GEWöHNLICH“, „ZURüCK“, „VERFäLLT“, „HAUPTMENü“, „HöLLE“. Der HUD-Font („SCHWERTKÄMPFER“, „KNOCHENWÄCHTER“) ist korrekt. | Großbuchstaben Ä/Ö/Ü in der UI-Pixelschrift ergänzen bzw. die Fallback-Glyphe prüfen (`src/pixel_style.gd`). | S |
| 8 | Mittel | HUD, Talente, Ergebnis · 01, 15, 27 | Uneinheitliche Begriffe: HUD „STUFE“, Talente „Heldenstufe“, LAUF „LAUFSTUFE“, Spalte „ST“. Das Ergebnis zeigt **„STUFE 1“ und „HELDENSTUFE 1“** nebeneinander, ohne den Unterschied zu erklären. Der Schnelltrank-Tooltip sagt „Rucksack“, sonst heißt es überall „Inventar“. | Glossar festlegen (z. B. „Laufstufe“ vs. „Heldenstufe“) und in `hell_game.gd` `_draw_result`, HUD-Heldenleiste und Tooltip vereinheitlichen. | S |
| 9 | Mittel | Pause · Steuerung · 29 | Die **F-Taste fehlt** in der Liste. `KEY_F` wird in `hell_game.gd` abgefragt (Rüstungskraft laut Auftrag). Alle aufgelisteten Tasten gibt es im Code (siehe unten). | Zeile „Rüstungskraft · F“ in der Steuerungsliste ergänzen (`src/pause_menu.gd`, Abschnitt `controls`). | S |
| 10 | Mittel | Hölle/Frost · Element-Rückstände · 13, 16, 17, 18, 26 | Mehrere Rückstände sehen gezeichnet aus statt nach Pixelmaterie: Eis-Splash = flache graue Ellipsen; Explosion/Blut = weiche rosa/rote Kreisscheiben, die liegen bleiben; Lava = Rechteck mit Rahmen; Ragdoll-Schädelteile = weiße Quadrate („Karten“). Das widerspricht dem Ziel „Element-Physik“. | Pfützen und Flecken als Pixelraster mit unregelmäßigem Rand und Körnung (`src/hell/story_elements.gd`), Lava-Becken mit organischer Kante (Floor-Bau Hölle), Ragdoll-Teile mit Sprite statt Fläche (`src/hell/story_wreck.gd`). | L |
| 11 | Mittel | Krypta · Boss-Telegraph · 07, 08 | Das Telegraph des Knochenwächters besteht aus zwei dünnen, weiß gepunkteten Ringen. Auf dem Steinboden liest sich das kaum als Gefahr. Beim Schlag (08) ist kein Bodeneinschlag (Staub/Risse) zu sehen. | Rot gefüllter Ring mit Lade-Rampe plus Staub/Risse beim Einschlag (`src/hell/boss_kit.gd` bzw. Telegraph-Zeichnung in `src/hell/hell_monsters.gd`). | M |
| 12 | Mittel | HUD Heldenleiste · 01→03, 16→17 | Das Heldenpanel ändert seine Höhe: Die dritte Zeile (Währung „✦0 ⟂0/3“ bzw. Status „GIFT · 3 s“) verschwindet und erscheint, und das Panel springt von etwa 120 auf 90 px. | Feste Zeilenhöhe im Heldenpanel (`src/ui/hud_kit.gd` `hero_panel`). | S |
| 13 | Mittel | Minimap · 01, 02, 03, 09 | Das Minimap-Panel ist halb durchsichtig. Weltsprites (Skelettkopf, Schleim) und Schneestriche scheinen durch und sehen aus wie Karten-Icons. | Deckender Hintergrund hinter der Karte (`hell_game.gd`, Minimap-/`_draw_floor_panel`-Zeichnung). | S |
| 14 | Mittel | HUD Fähigkeitenleiste · 13, 01 | Die Leiste unten (etwa 70 px) verdeckt das Spielfeld. Gegner darunter sind unsichtbar (13: Gegner bei y≈712), und der Tooltip „SCHNELLTRANK“ legt sich über Gegner (01). | Kamera-Sicherheitsrand nach unten (`src/hell/story_camera.gd`), Tooltip über der Leiste verankern. | M |
| 15 | Mittel | HUD Fähigkeitenleiste · 01, 09 | Auf Stufe 1 sind 5 leere Slots (1–4, R) zu sehen, dazu die Kürzel „SH“ und „H/G“ ohne Erklärung. Ein neuer Spieler versteht „SH“ = Shift nicht. | Leere Slots dimmen und „gesperrt“ anzeigen; „SH“ → Shift-Symbol oder „⇧“; Tooltip mit Klartext. | S |
| 16 | Mittel | Hölle · Nekromant · 16 | Der Feuer-Strahl eines Gegners läuft quer durch den ganzen Raum bis in die untere Wand. Er ist ein glatter, vektorartiger Strich und überdeckt das Getümmel. | Strahl an Wänden kappen, in Pixelkörnung zeichnen (Strahl-Zeichnung in `src/hell/hell_monsters.gd`). | M |
| 17 | Mittel | Krypta · Treffer · 02 | Das Treffer-Feedback auf normalen Gegnern ist schwach. 3 Frames nach `_damage_mob` sind nur kleine Funken zu sehen, kein Weißblitz und keine Zahl. *(Geringe Sicherheit: nur ein Zeitpunkt)* | Weißblitz der Mob-Sprites für 2–3 Frames und etwas Rückstoß-Staub prüfen (`hell_game.gd` `_damage_mob`, Feel-Hook). | M |
| 18 | Niedrig | Pause · Steuerung · 29 | Die Wertespalte ist zu schmal, deshalb brechen die Texte mehrfach um („Linksklick / oder / Pfeiltasten“, „Esc (schließt / zuerst das / oberste / Fenster)“), während rechts Platz frei bleibt. | Spaltenbreiten der Steuerungsseite anpassen (`src/pause_menu.gd`). | S |
| 19 | Niedrig | Pause · Optionen · 28 | Der Aus-Zustand der Schalter (grauer Punkt auf Dunkel) ist kaum sichtbar, und die Schalter sind sehr klein (etwa 30×12 px). | Kontrast und Größe der Toggles erhöhen (Options-Panel in `src/pause_menu.gd`). | S |
| 20 | Niedrig | Pause · Etage · 20 | Zwei Hervorhebungen gleichzeitig: Fokusrahmen auf „Weiterspielen“ und aktive Sektion „Etage“. Die Karte rechts zeigt 2 winzige Räume in einer großen leeren Fläche. | Fokus auf die aktive Sektion legen (`open_pause()` → `grab_focus`). Karte zoomen oder zentrieren. | S |
| 21 | Niedrig | Talente · LAUF · 15 | Dreifacher Titel (Tab „LAUF“, Kopf „LAUF“, „LAUF-TALENTE · MAGIER“), „PUNKTE 0“ steht doppelt, darunter viel Leerraum. | Kopfzeile entfernen, Punkte nur einmal zeigen. | S |
| 22 | Niedrig | Texte · 23, 20 | „1 Talentpunkte frei“ → „1 Talentpunkt frei“. „Steig die Treppe hinab“ → „Steige …“. | Pluralregel im Talent-Kopf, Zieltext im Floor-JSON. | S |
| 23 | Niedrig | Boss-Leiste · 06 | Der Untertitel „WÄCHTER DER ETAGE“ hat keinen Hintergrund und wenig Kontrast auf der Wand. | Unterlegen oder in den Balkenrahmen ziehen (`hell_game.gd` `_draw_boss_bar`). | S |
| 24 | Niedrig | Kampf-Popups · 17 | „KRIT“ ist etwa 8 px groß und kaum lesbar. | Mindestens 16 px, kurzer Scale-Pop. | S |
| 25 | Niedrig | Funde · 10 | Mehrere Funde im selben Moment: Der Toast zeigt nur den letzten („Gefunden: ROTER TRANK“). | Toasts stapeln oder zusammenfassen („6 Tränke gefunden“). | S |
| 26 | Niedrig | Pause · 20, 28 | Das Pause-Panel deckt die HUD-Leiste links nicht ganz ab, ihre Kante blitzt am Rand durch. | Abdunkelung über den ganzen Bildschirm oder HUD in der Pause ausblenden. | S |

## Steuerung (Pause → Steuerung) gegen den Code geprüft
Aufgelistet sind: WASD, Shift, Linksklick/Pfeiltasten, 1–4, R, 5 6, T, Q, H, G, E/Leertaste, L, Esc, I, K, B, M, C/Tab, E (neuer Lauf).
**Jede dieser Tasten wird abgefragt**: `KEY_W/A/S/D`, Pfeile, `KEY_1…6`, `R T Q H G E SPACE L ESCAPE I K B M C TAB` in `hell_game.gd`, `KEY_SHIFT` in `hell_talents.gd`.
Geprüft habe ich nur per Grep, ob die Taste existiert, nicht ob sie tut, was der Text sagt.
**Abgefragt, aber nicht aufgelistet**: `F` (Rüstungskraft → Befund #9). `F1`, `F10`, `PAGEUP`, `ENTER`, `7–9`, `0` sind vermutlich Debug-Tasten und gehören nicht in die Liste.

## Was gut aussieht (nicht anfassen)
- Ergebnis-Panel (27): klar, Ursache steht drin, „NEUER LAUF (E)“ ist eindeutig. Der Tod-Moment (26) ist mit Rotfilter, „GEFALLEN“ und Toast gut lesbar.
- Pause, Seite Etage (20): Haupt- und Nebenziele sind sauber gegliedert und gut lesbar.
- Trank-Identifikation („SCHWARZER TRANK ist ein GIFTTRANK.“, 17) und unbekannte Tränke mit „?“ im Inventar (11) funktionieren.
- „TALENTE · K +1“ leuchtet nach dem Stufenaufstieg auf (18), ein gutes Signal.
- Giftwolke und Explosion klingen nach etwa 5 s ab (18). Nur die Flecken bleiben (#10).

## Abdeckungslücken (nicht geprüft)
- **F-Rüstungskraft**: `story_items.give_armor()` hat keine der probierten IDs angenommen (14 Kandidaten), und `story_items` hat keine Rüstungs-Property. Die Fähigkeit ist ungeprüft; dafür braucht es eine gültige Rüstungs-ID.
- **Begleiterleiste**: Auf Stufe 1 hatte keine Klasse einen Begleiter (Nekromant: erst „Knochenkrieger“ ab Heldenstufe 2).
- **Zerschlagenes Requisit / Wandabnutzung** (03): Die `wreck.hit_line`-Treffer sind im Bild kaum zu erkennen. Ob das am Effekt oder am Bildausschnitt liegt, ist offen.
- **Ton**: kein Audio-Mitschnitt, Sound-Feedback ist ungeprüft.
- Bilder 05 (Boss-Intro), 21/22/25 (Pause Talente/Inventar/Speichern) sind aufgenommen, aber nicht einzeln ausgewertet.
- 23/24 zeigen das Talentfenster statt Optionen/Steuerung. Das per `select_section("talents")` geöffnete Fenster lag über der Pause. Lauf 2 hat das ersetzt (28/29).
- Beim Beenden meldet das Log GL-Textur-Lecks und „24 resources still in use“. Das kommt vermutlich vom harten `quit()` der Probe und ist nicht als Befund gewertet.

## Bilder
01 krypta-kampf-gruppe · 02 krypta-trefferfeedback · 03 krypta-wandschaden-requisit · 04 krypta-6s-spaeter-ruhe · 05 krypta-boss-intro ·
06 krypta-boss-leiste · 07 krypta-boss-telegraph · 08 krypta-boss-angriff · 09 frost-kampf-schnee-eis · 10 frost-hud-schnellslot-trank ·
11 frost-inventar-unbekannt · 12 frost-trankwurf-flug · 13 frost-trank-splash-eis · 14 frost-talente-klasse · 15 frost-talente-lauf ·
16 hoelle-kampf-lava-begleiter · 17 hoelle-gas-feuer-explosion · 18 hoelle-elemente-5s-spaeter · 19/20 hoelle-pause-ueberblick/floor ·
21–25 hoelle-pause-* (21–24 zeigen das Talentfenster) · 26 hoelle-tod-moment · 27 hoelle-ergebnis-panel · 28 hoelle-pause-options · 29 hoelle-pause-controls
