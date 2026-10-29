# Einheitliches HUD (Stand 29.10.2026)

Wunsch des Nutzers: Die Oberfläche im Spiel ist in Krypta, Hölle und Frostgruft
gleich und **neutral**, nicht im Stil einer Welt. Die Krypta bekommt dabei
schon die Plätze für Mechaniken der Story-Welten (Schlüssel, Runensteine,
Rätsel-Fortschritt, Zeit-Kräfte), damit sie später ähnliche Etagen tragen kann.

## Aussehen

`src/ui/hud_style.gd` mit den Werten aus `assets/data/ui_hud_style.json`:
dunkle, halbtransparente Kästen mit einem feinen hellen Rand, gebrochenes Weiß
mit dunkler Kontur für Schrift, ein warmer Akzent für Bereites und Wichtiges,
Rot für Gefahr, Grün für Erfahrung. Keine Welt färbt ihr HUD.

## Teile (`src/ui/hud_kit.gd`)

| Teil | Ort | Inhalt |
| --- | --- | --- |
| Heldenleiste | oben links | Spieler und Klasse, LP-Zahl; Herzen mit dem Level direkt daneben; EXP-Linie; darunter Ressourcen (Schlüssel, Runensteine, Feuerschalen) und kurze Zustände (Klon, Segen, Schild) |
| Etagen-Kasten | oben rechts | Ebene/Etage, Raum oder Name, Zustand (KAMPF, HORDE, VERRIEGELT · n, ERKUNDEN), Minikarte darin |
| ESC · MENÜ | unter dem Etagen-Kasten | klickbar in allen Welten |
| Boss-Leiste | oben Mitte | Name, Prozent oder LP, Phasen als Segmente |
| Banner | oben Mitte | Etagen- und Level-Meldungen |
| Hinweise | über der Fähigkeitenleiste | gestapelt, Akzentkante links |
| Aktions-Hinweis | über dem Objekt | Tastenkappe „E“ und was passiert |
| Fähigkeitenleiste | unten Mitte | `src/ui/skill_bar.gd`, ohne Level (das steht jetzt oben bei den Herzen) |

Level-Karten, Statusseite (C/Tab) und Auftragsliste der Story-Welten
(`src/hell/frost_hud.gd`) nutzen dieselben Kästen und Farben.

## Wer was nutzt

- Krypta: `src/ui/run_hud.gd` (Heldenleiste mit Team-Level, Etagen-Kasten,
  Boss-Leiste, Leiste); Menü- und Inventar-Knopf über `HudStyle.style_button`.
- Hölle und Frostgruft: `draw_hud` und `_draw_skill_bar` in
  `src/hell/hell_game.gd`, Minikarte im Etagen-Kasten (`_draw_map(..., area)`).

## Noch nicht vereinheitlicht

- Die Level-Karten der Krypta (`src/level_cards.gd`) und das Pausenmenü tragen
  noch den Krypta-Stein-Stil.

Test: `tests/hud_unified_test.gd`. Belege: `production/qa/evidence/hud-unified/before`
und `after` (`scripts/capture_unified_hud.gd`; Krypta aus `scripts/capture_skills.gd`).
