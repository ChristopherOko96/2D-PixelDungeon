# UX-Befund · Delve Disaster (Story-Welten + Hauptmenü)

Stand 2026-11-01 · Branch codex_v2 · 1280x720 · Aufnahmen über die eigenen Funktionen des Spiels
(`_open_stories`, `_choose_story`, `_open_talents`, `open_pause`, Tasten K/I/C/B/M/Esc als
echte Eingabe, `enter_boss_room`, `_lose_hp`). Spielcode und -daten wurden nicht geändert.

## Urteil

Die Grundbausteine passen: ein einheitliches HUD-Kit, eine klare Skill-Leiste und ein ruhiges Pausenmenü.
Kaputt machen es drei Dinge. Im Bosskampf überdeckt die Bossleiste den Helden-Streifen, und bis zu fünf
Textmeldungen stapeln sich über dem Helden. Das Hauptmenü hat acht Einträge, darunter drei Sackgassen
(Endlos, Mehrspieler, Editor), und Esc bzw. Pad-B führt in keinem Untermenü zurück. Außerdem heißen dieselben
Dinge auf jedem Bildschirm anders: Herzen und LP, drei Arten „Level“, Runensteine und Eissplitter.

## Rangliste der Änderungen (wirksamste zuerst)

| # | Bildschirm · Beleg | Problem | Konkrete Änderung | Aufwand |
|---|---|---|---|---|
| 1 | HUD Bosskampf · `35-krypta-boss.png`, `41-frost-boss.png`, `51-hoelle-boss.png` | Die Bossleiste (x 360–920) liegt **über** dem Helden-Streifen (bis x≈410). LP-Zahl und LV-Abzeichen sind verdeckt, im Tod auch „GEFALLEN“ (`36`). Das passiert in jedem Bosskampf. | `HudKit.boss_bar()`: nicht mehr aus `map_panel_width` rechnen, sondern aus dem Rechteck, das `hero_panel()` zurückgibt. Also `left = hero_rect.end.x + 16`, `right = floor_rect.position.x - 16`, Leiste zwischen diesen beiden Kanten zentrieren. `hell_game.draw_hud` reicht `hero_rect` durch. | S |
| 2 | HUD Meldungen · `35`, `41`, `24`, `25` | Im Bosskampf stehen gleichzeitig: Raum-Banner, „DEBUG-START BEIM BOSS“, „WÄCHTER DER ETAGE“, drei Toasts und ein Prompt. Die Toasts liegen unten mittig über dem Helden (`41`: Held unter dem Stapel, auf Schnee kaum lesbar) und verdecken das Mana-Label (`24`). | Es gibt nur noch einen Meldekanal. `hell_game._toast()`: höchstens **1** sichtbarer Toast, der Rest wartet in einer Schlange (2,0 s je Toast). Position unten links (x 16, über der Skill-Leiste), nicht mittig. `FrostHud.track()`: Ziele, die beim Sprung schon erledigt waren, bleiben stumm (`state.t > 0.5` reicht nicht). Mehrere Erfolge zusammenfassen („2 Ziele erfüllt“). Der Untertitel von `enter_boss_room()` entfällt im echten Spiel, ebenso das Tag „WÄCHTER DER ETAGE“, solange das Banner den Boss nennt. | M |
| 3 | Menüfluss · Log der Menü-Aufnahme, `03-heldenwahl-story.png` | Esc und Pad-B schließen weder Story-Wahl noch Heldenwahl, Spielstände oder Optionen (nur der Talent-Bildschirm reagiert). In der Heldenwahl bleibt der Fokus auf dem **verdeckten** Knopf STORY-MODUS, Enter öffnet also wieder die Story-Wahl. Mit Tastatur oder Pad lässt sich kein Held wählen. | `main_menu.gd`: `_unhandled_input` mit `ui_cancel` geht genau eine Ebene zurück (Held → Story → Titel; Welt → Level-Auswahl → Hub). `_open_classes()` setzt den Fokus auf die erste Heldenkarte. Karten und ZURÜCK bekommen `focus_neighbor_*`. Der Titel-Knopf ENDLOS (deaktiviert) bekommt `focus_mode = FOCUS_NONE` (`01b`: das Pad landet heute darauf). | S |
| 4 | Titel · `01-titel-hauptmenue.png`, `11-editor-werkstatt.png`, `12-mehrspieler.png` | Acht Einträge, davon drei Sackgassen. ENDLOS · BALD ist deaktiviert. MEHRSPIELER öffnet die **alte** Lobby („Crypt of the Damned · 6 Räume · 48 Perks“, anderes Layout). EDITOR öffnet ein Entwickler-Werkzeug. SPIELSTÄNDE steht getrennt von der Story. | Der Titel zeigt nur noch SPIELEN · TALENTE · OPTIONEN · BEENDEN. Endlos fällt weg, bis es existiert. MEHRSPIELER und EDITOR wandern in den DEBUG-Hub (`_build_debug_hub`). Die Spielstände ziehen in die Story-Karten: jede Karte bekommt „FORTSETZEN · ETAGE n“ und „NEU“ (`_build_story_panel`, `saves.summaries`). | M |
| 5 | Überlagerungen im Lauf · `29b-krypta-inventar-dann-esc.png`, `31-krypta-karte-M.png`, `32` | Esc bei offenem Inventar öffnet die Pause **zusätzlich**, zwei Fenster liegen übereinander. Der Chip „INVENTAR · I 0/12“ liegt über Pause, großer Karte und Legende. | `hell_game._unhandled_input` KEY_ESCAPE schließt zuerst das oberste Fenster (Inventar → Lauf-Talente → Status → Karte), erst danach öffnet es die Pause. Der Inventar-Chip in `inventory_panel._draw` wird ausgeblendet, solange Pause, Karte oder ein Fenster offen ist. | S |
| 6 | HUD Ressource · `20`, `40-frost-hud-erkunden.png`, `51` | Die leere Gefüge-Kugel des Leerenmagiers erscheint bei **jeder** Klasse: Bogenschütze, Schwertkämpfer und Magier ohne Leeren-Talent. Für sie ist das reines Rauschen. | `talent_bar.draw_resource()`: Kugel nur zeichnen, wenn `gefuege.cap > 0` ist. Besser noch: `hell_talents.hud_state()` liefert `gefuege` nur für den Leeren-Pfad. | S |
| 7 | Helden-Streifen und Etagen-Panel · `21-krypta-hud-erkunden.png`, `40` | Rauschen: „P1 ·“ im Solo-Spiel, drei Schlüssel-Symbole mit 25 % Deckkraft (unlesbar), Zähler ohne Beschriftung (✦ 0, 0/3). Der Etagenname läuft rechts aus dem Panel heraus. „ETAGE 1 · VORHALLE …“ steht doppelt (Banner und Panel), „ERKUNDEN“ sagt nichts aus, die Minimap bleibt winzig. | `hell_game.draw_hud`: „P1 ·“ nur im Mehrspieler. Ein Schlüssel erscheint erst, wenn er gefunden ist. Die Ressourcenzeile blendet 4 s nach der letzten Änderung aus. `HudKit.floor_panel`: Untertitel mit Ellipse kürzen, „ERKUNDEN“ weglassen (nur „VERRIEGELT · n“ in Rot zeigen), dafür die Kartenfläche vergrößern. | S |
| 8 | Fortschritt · `26-krypta-levelup-karten.png`, `27-krypta-lauftalente-B.png`, `30-krypta-talente-K.png`, `37-krypta-lauf-beendet.png` | Drei verschiedene „Level“: HUD „LV 2 +1“ (Lauf, Taste B), Talentbildschirm „MAGIER · Level 3“ (Profil, Taste K), Ergebnis „PROFIL: LEVEL 1“. Dazu Reste der Level-Karten: „Karte wählen 7 8 9“ in der Steuerung, „KARTEN noch keine“ im Status. In der Krypta erscheinen gar keine Karten. | Benennung festlegen, z. B. „Laufstufe“ und „Heldenstufe“ (**Designentscheidung**, Frage an ux-designer/Nutzer). Die Lauf-Talente (B) werden ein Reiter im K-Bildschirm, dann gibt es nur eine Talent-Taste. Kartenzeilen in `STORY_CONTROLS` und `FrostHud.status` nur zeigen, wenn die Welt Karten hat. | M |
| 9 | Begriffe · `32-pause-uebersicht.png`, `34`, `28-krypta-status-C.png`, `03`, `04`, `60` | Leben heißt „10 / 10“ (HUD), „5 von 5 Herzen“ (Pause) und „HERZEN 5“ (Etagenergebnis). Die Währung heißt ✦, „Runensteine“ und im Status der **Krypta** „Eissplitter“. Die Klasse heißt „SCHWERTKÄMPFER“ (Heldenwahl, HUD) und „KRIEGER“ (Talent-Reiter). Der Testraum-Toast zeigt die interne ID „mage“. | Ein Glossar: überall LP (`pause_info`, Zeilen im Etagenergebnis, Heldenwahl). `FrostHud.status` nutzt `g.say("Runensteine")`. `talent_screen.CLASS_NAMES` kommt aus den Klassendaten. Der Testraum-Toast zeigt `hero.name`. | S |
| 10 | Schriftgrößen · `21`, `40`, `28`, `04`, `29` | Viele Texte unter 16 px: `font_small` 12 (Panel-Titel, LP-Zahl, Etagenzeilen, ESC-Chip, Begleitername), Ressourcen-Label **8 px** („MANA 150 / 150“, „ZORN“), Tastenbeschriftung der Skill-Leiste und der Begleiter 10, Status 14/12, Talent-Reiter 12, Inventar-Knöpfe 12. Bei Pixel Operator 8 sind 12 und 10 außerdem keine Vielfachen von 8 und werden matschig. | `ui_hud_style.json`: `font_small` 16, `pet_key_size` 16. `ui_run_hud.json` `skill_bar.key_size` 16. `talent_bar.draw_resource`: Label 16 px oder die Zahl nur bei Hover bzw. unter 25 % zeigen. `talent_screen` Reiter 16. `FrostHud.status` Zeilen 16. Danach die Abstände prüfen. | M |
| 11 | Pause · `32`, `33-pause-*.png` | Im Spiel gibt es keine Lautstärke (nur im Titel-Menü), und die Seite „Anzeige“ wiederholt einen Teil der Titel-Optionen. Talente und Inventar sind für Maus und Pad nicht erreichbar. Die Steuerungsseite ist eine 14-zeilige Textwand, ohne „Inventar: I“, aber mit „Karte wählen 7 8 9“. Die Karte sitzt klein links oben im Feld. | Abschnitte: Weiterspielen · Etage (Auftrag und Karte zusammen) · Talente · Inventar · Optionen (**dieselbe** Optionsszene wie im Titel, mit Lautstärke, Wackeln, HD und Schadenszahlen) · Speichern · Hauptmenü. Steuerung in Gruppen (Bewegen/Kampf/Fenster). `story_map_draw` füllt das Feld aus. | M |
| 12 | Titel-Panels · `02-story-wahl.png`, `05-spielstaende.png`, `06-optionen.png`, `07-debug-hub.png` | Die Panels sind durchscheinend, die Titelknöpfe schimmern durch („STORY-MODUS“, „TALENTE“ hinter Optionen und Spielständen). Story-Wahl und Heldenwahl schneiden den Spieltitel. Nur Debug-Panels dunkeln den Hintergrund ab, die Spieler-Panels nicht. | `_debug_dim` für **jedes** Panel nutzen (`_debug_open()` → `_panel_open()`), die Titelkarte samt `_buttons` ausblenden, solange ein Panel offen ist. Panels unterhalb von y 190 setzen oder den Titel ausblenden. | S |
| 13 | Heldenwahl · `03-heldenwahl-story.png` | Die Werte stammen aus der alten Krypta-Balance („5 HERZEN · SCHADEN 5 · NAHKAMPF 64 · TEMPO 148“) und passen nicht zur Story: HUD 10 LP, Status „1.8 je Treffer · Lauftempo 350“. Die Zeile TEMPO stößt an den Kartenrand. Der Magier wird als „Arkane Kugeln“ beschrieben, obwohl er drei Element-Pfade hat. | `game.gd _build_main_menu` füllt die Karten aus den Story-Klassen (Theme/`hell_balance`) und `talents.json`. Drei Zeilen: Rolle, LP, Ressource (Mana/Ausdauer/Zorn), dazu „Pfade: Feuer · Frost · Leere“. | M |
| 14 | Talente · `04-talente-mage.png`, `30` | Der **gewählte** Klassen-Reiter sieht deaktiviert aus (dunkler als die anderen). „Schwierigkeit“ und „Zurücksetzen · 25 Gold“ stehen in der Kopfzeile. Mitten im Lauf (K) bietet der Bildschirm andere Klassen und die Schwierigkeit an. | Aktiver Reiter in Gold und hervorgehoben. `open(..., from_run := true)` blendet die Klassen-Reiter und die Schwierigkeit aus. Die Schwierigkeit gehört zum Story-Start. | S |
| 15 | Ergebnis · `34-krypta-etage-geschafft.png`, `37` | Nur Tastenhinweise in 12 px („E · NEUER LAUF   ESC · MENÜ“). Maus und Pad haben keine Knöpfe. | `HudKit.result_panel` bekommt echte Buttons in einer Control-Ebene: NEUER LAUF bzw. WEITER als Hauptknopf mit Fokus, HAUPTMENÜ als zweiten. | M |
| 16 | Prompt · `25`, `26`, `28` | „E · Erst die Gegner be…“ wird am rechten Bildrand abgeschnitten. | `HudKit.prompt`: `rect.position.x` in `[margin, screen.x − margin − width]` begrenzen. | S |
| 17 | Spielstände · `05` | Die Reiter-Reihenfolge Krypta · Hölle · Frostgruft · ENDLOS weicht von der Story-Reihenfolge ab. ENDLOS gibt es nicht. | `SAVE_MODES = ["krypta","frost","hell"]`. Entfällt mit #4, wenn die Stände in die Story-Karten wandern. | S |
| 18 | Große Karte (M) · `31` | Die Legende „Hell: besucht“ ist mehrdeutig (Hell wie Hölle), der Titel liegt über dem Etagen-Panel, der Inventar-Chip über der Legende. | Legende auf „Hell = besucht“ → „Heller Raum: besucht“ ändern. Bei offener Karte HUD-Panels und Chips ausblenden (`draw_hud` mit `state.map`). | S |
| 19 | Inventar · `29-krypta-inventar-I.png` | Acht Aktionsknöpfe sind immer sichtbar und fast alle grau (12 px). Es fehlt ein Hinweis zum Schließen. Der Stil (flaches Schwarz) unterscheidet sich vom Pausen-Panel. | Nur die 2–3 Aktionen zeigen, die für das gewählte Teil gelten. Fußzeile „I / Esc schließt“. Panel-Stil wie in `CryptUI.box("panel")`. | M |
| 20 | Gamepad · alle Lauf-Bildschirme | Weder Story-Welten noch Menüs haben eigene Gamepad-Abfragen (0 Treffer für Joypad in `hell_game`, `story_hero`, `pause_menu`, `talent_screen`, `inventory_panel`). Bewegung läuft über physische Tasten. | InputMap-Aktionen anlegen (move_*, attack, skill_1..4, ult, dash, interact, pause, inventory, talents). `_unhandled_input` und `_axis` stellen von Keycodes auf Aktionen um. | L |

Nebenbefunde: Die Lauf-Talente (B, `27`) zeigen drei Zeilen in einem Fenster über 75 % des Bildes, und die Welt läuft dahinter weiter. Besser wäre eine kompakte Seitenleiste oder eine Pause, solange das Fenster offen ist. Der Status (C, `28`) wiederholt den Helden-Streifen und gehört in die Pause-Übersicht oder in die Charakterspalte von K.

## Vorgeschlagene Menükarte (Spieler-Tiefe ≤ 2, Debug ≤ 3)

```
TITEL (0)
├─ SPIELEN ──────────► STORY-WAHL (1)  Karte je Welt: [FORTSETZEN · Etage n] [NEU]
│                         └─ NEU ─────► HELDENWAHL (2) ──► Lauf
├─ TALENTE (1)          Klassen-Reiter · Pfade · Lauf-Talente als Reiter
├─ OPTIONEN (1)         Ton · Anzeige · Steuerung   (gleiche Szene wie in der Pause)
├─ BEENDEN
└─ [DEBUG] (Ecke, nur Debug-Build)
     ├─ LEVEL-AUSWAHL (2) ─► WELT (3) ─► Heldenwahl
     ├─ TESTRAUM ─► Heldenwahl
     ├─ TALENT-TEST · KLANGWERKSTATT · EDITOR · MEHRSPIELER (alt)

IM LAUF: Esc ─► PAUSE (1): Weiterspielen · Etage (Auftrag + Karte) · Talente · Inventar
                           · Optionen · Speichern · Hauptmenü
         K / I / M öffnen dieselben Seiten direkt. Esc schließt immer zuerst das oberste Fenster.
```

## HUD-Layout (1280x720)

```
┌────────────────────────────────────────────────────────────────────────────────┐
│[HELD  ▬▬▬▬▬▬▬▬ 10/10 LP │LV 2│+1]   [BOSS · NAME ▬▬▬│▬▬▬│▬▬▬ 100%]   [ETAGE 1  ]│
│[BEGLEITER ▣ ▬▬▬ 21/21  [5][6]]        (nur im Bosskampf,              [ ▢ Map   ]│
│[✦ 3  🗝  (blendet nach 4 s aus)]       zwischen den Panels)           [VERRIEGELT·4]│
│                         [RAUM-BANNER 2 s, nur bei neuem Raum / neuer Etage]    [ESC]│
│                                                                                │
│                                   SPIELFELD                                    │
│                              (frei, keine Meldungen)        [E · Truhe öffnen]  │
│                                                              (am Objekt, begrenzt) │
│                                                                                │
│[TOAST · 1 Zeile, unten links,                                                  │
│ Schlange, je 2 s]                 MANA ▬▬▬▬▬▬▬▬ (◎ Gefüge nur Leere)             │
│                                   [1][2][3][4] [R] [SH]                  [I 0/12]│
└────────────────────────────────────────────────────────────────────────────────┘
```

Ausblendregeln:
- **Immer sichtbar:** Lebensbalken und LV, Skill-Leiste, Ressourcenbalken.
- **Ausblenden nach Ruhe:** Ressourcenzeile (Schlüssel, ✦, Schalen) 4 s nach der letzten Änderung. Die Begleiterleiste sinkt auf 60 %, solange er volle LP hat und keine Abklingzeit läuft. Das Etagen-Panel sinkt außerhalb von Kämpfen auf 70 %. Der ESC-Chip steht auf 50 %, bei Hover auf 100 %. Der Inventar-Chip erscheint nur 3 s nach einer Änderung im Beutel oder bei Hover.
- **Nur im Moment selbst:** Bossleiste (Bosskampf), Raum-Banner (2 s), Prompt (in Reichweite), Toast (immer nur einer).
- **Bei offenem Fenster** (Pause, Karte, Inventar, K): alle Chips und Toasts aus.

## Aufnahmen (dieser Ordner)

Menü: `01-titel-hauptmenue`, `01b-titel-fokus-gamepad`, `02-story-wahl`, `03-heldenwahl-story`, `04-talente-{mage,archer,swordsman,necromancer}`, `05-spielstaende`, `06-optionen`, `07-debug-hub`, `08-debug-levelauswahl`, `09-debug-welt-etagen`, `10-debug-testraum-heldenwahl`, `11-editor-werkstatt`, `12-mehrspieler`.
Lauf: `20-krypta-start-banner`, `21-krypta-hud-erkunden`, `22-krypta-skillbar-hover`, `23-krypta-prompt`, `24-krypta-toasts`, `25-krypta-kampf`, `26-krypta-levelup-karten` (Level-Up ohne Karten), `27-krypta-lauftalente-B`, `28-krypta-status-C`, `29-krypta-inventar-I`, `29b-krypta-inventar-dann-esc`, `30-krypta-talente-K`, `31-krypta-karte-M`, `32-pause-uebersicht`, `33-pause-{quest,map,controls,display,save}`, `34-krypta-etage-geschafft`, `35-krypta-boss`, `36-krypta-tod`, `37-krypta-lauf-beendet`, `40-frost-hud-erkunden`, `41-frost-boss`, `50-hoelle-boss-start-banner`, `51-hoelle-boss`, `60-testraum-zu`, `61-testraum-offen`.

Nicht aufgenommen:
- **Level-Up-Karten (7/8/9):** In der Krypta erscheinen nach dem Aufstieg keine Karten (`offer` blieb leer).
- **Vergessene Stiege, Login-Panel** (kein Konto), **Klangwerkstatt**.
- **Schadenszahlen im normalen Spiel:** nur der Testraum-Schalter, der hier nicht ausgelöst wurde.
- **Begleiterleiste in der Krypta:** Die Leeren-Probe hatte keinen Begleiter. Die Leiste ist in `40`, `41` und `60` zu sehen.
- **Echte Pad-Eingabe im Lauf:** Es gibt keine.
