# Stilprobe 0x72 (zur Abnahme, nicht im Spiel)

Stand 27.10.2026. Wunsch des Nutzers: Figuren, Gegner und Krypta-Kacheln im Stil
der Hauptmenü-Figuren (0x72), mit vielen flüssigen Animationen und
zerstörbaren Körperteilen. Erst nach der Freigabe wird etwas ins Spiel übernommen.

- **Vorschau-Seite:** https://claude.ai/artifact/75dUCYWVttCgPT5eE6UMHg (privat),
  gebaut aus `review.template.html` mit `build_review.js` nach `out/stilprobe.html`.
  Kennungen für das Feedback: F1 Ritter, F2 Skelett, F3 Nekromant,
  F4 Riesen-Zombie (Boss-Beispiel), R1 Krypta-Raum, P1 Requisiten.
- **Raum:** `render_room.gd` zeichnet einen echten Generator-Raum (Seed 4242,
  Raum 2, Vorlage crypt_03) mit Original-0x72-Kacheln. Wandteile ergeben sich aus
  Front/linkem/rechtem Streifen je nach Bodennachbarn; Deko ohne Kollision.
- **Teile-Animation:** Jede Figur wird pixelgenau in Körperteile zerlegt
  (Rechtecke in `DEFS` der Vorlage); Bewegung wird pro Bild berechnet. Das ist der
  Prototyp für das spätere Godot-System.
- **Quellen:** Original-Dateien liegen außerhalb des Projekts unter
  `C:\Users\Cylor\Desktop\Project referenzen Dungeon Basement`.
  Lizenz: 0x72 DungeonTileset II ist CC0. Für dungeontiles-extended (Fackeln,
  Kerzensäulen in `out/props/`), den Wand-Umbau, die Fan-Blätter und die Wald-
  und NPC-Pakete fehlt ein Lizenzhinweis. Vor einer Übernahme ins Repo klären.
- **Freigabe Stilprobe:** 27.10.2026, F1–F4, R1, P1: Ja.
- **Gesamtsatz (zweite Abnahme):** https://claude.ai/artifact/R4sftXCTQZFXXN4VQhdYAZ
  (privat), gebaut aus `full.template.html` mit `build_full.js` nach
  `out/gesamtsatz.html`. Kennungen: H1–H4 Helden, K1–K6 Krypta-Gegner,
  N1–N3 Nebenbosse, B1 Leerenrufer, W1–W3 Welten 2–4, R1–R10 Räume,
  P1 Requisiten. Räume: `out/rooms/room_N.png` + `_props.json` (Seed 4242).
  Schläfer (zurückgestellt, nicht mehr auf der Seite): `sleeper.json` →
  `make_sleeper.gd` → `out/sleeper/`. Neu gezeichnet: der Schild (SHIELD in der
  Vorlage) und die Ergänzungen am Leerenrufer.
- **Leerenrufer (B1, ab 27.10.2026):** Körper aus dem Blatt des Nutzers
  (`sources/user_sheet_void.png`, unten links, 8 Bilder; Herkunft und Lizenz
  offen). `make_void.gd` schneidet die Bilder aus, richtet sie am Schwerpunkt
  aus und ergänzt den abgeschnittenen Unterteil. Aufruf:
  `godot --headless --path . -s res://production/art-proof/0x72-style/make_void.gd -- <Blatt.png> <out/void>`.
  Neue Teile (Klauen, Leerenauge, Seelenschädel) stehen in `void.json`.
- **Ohne Link ansehen:** `out/gesamtsatz.html` (Gesamtsatz) oder
  `out/stilprobe.html` (Stilprobe) einfach im Browser öffnen. Alle Bilder sind
  eingebettet, nur die Schriften kommen aus dem Netz.
- **Lizenz-Entscheidung:** Am 27.10.2026 hat der Nutzer entschieden, alles
  öffentlich ins Repo zu pushen, auch das Blatt mit dem Leeren-Wesen und die
  Fackeln/Kerzensäulen aus dungeontiles-extended, obwohl deren Lizenz offen ist.
  Vor einer Veröffentlichung des Spiels klären oder ersetzen.
- **Hilfsskripte:** `slice_frames.gd` (Einzelbilder ausschneiden), `serve.js`
  (lokaler Server für die Vorschau auf Port 8765).
