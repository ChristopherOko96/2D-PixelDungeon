# Seelenwaechter

31.10.2026: Nutzer hat den konkreten Entwurf ausdruecklich gutgeheissen und
Animationen sowie Spielintegration angefordert. Aktive Seele-Ultimate `soul_14`.

- Freigegebene Tafel: `output/necromancer-soul-guardian-v1/soul-guardian-concept.png`.
- Basis: bestehender Nekromant aus `assets/sprites/0x72/` und freigegebene Geister
  aus `assets/vfx/soul_field/approved_sheet.png`. Deren Quellen/Lizenzen bleiben.
- `source_sheet.png`: ein neuer eingebauter Imagegen-Aufruf fuer diese Animation.
  Unveraenderte Quelle, 1536x1024, 8x4 Raster. Exakter Prompt: `animation_prompt.txt`.
- `scripts/import_soul_guardian.gd`: rein mechanischer Import. Nearest auf Viertel,
  harte Alpha-Schwelle 0,5, 18 Farben, identischer Massstab fuer alle Posen.
  Der lange Arm aus Reihe 3 belegt zwei Quellzellen; er wird zusammen ausgeschnitten
  und waehrend des Trefferzeitpunkts bewusst gehalten. Keine abgeschnittene Hand.
  Ein fremdes Armfragment am linken Rand der Erholung wird entfernt.
- `guardian_atlas.png`: 1024x320, 8x4 Zellen je 128x80 inklusive Bewegungspadding.
  Das vollstaendige schwebende Motiv ist etwa 48x64 native Pixel, der ausgestreckte
  Arm braucht mehr Breite. Dies sind VFX-Beschwoerungsframes, keine Aenderung des
  32px-Weltrasters oder der vorhandenen Heldenauflosung. Anchor (48,64).
- 32 Timeline-Keys in vier Clips, **31 unabhaengige sichtbare Posen**, ein
  bewusster Impact-Hold. Keine versteckten Marker/Farbtricks fuer mehr Frames.
  Spawn 0,64 s, Hover-Schleife seit der Bewegungsrevision 1,6 s (vorher 0,96 s), Greifen 0,64 s mit Treffer bei 0,32 s,
  Aufloesen 0,8 s. Timing in `assets/data/talents.json`.
- Darstellung Krypta 2x, Hölle/Frostgruft 3x, nearest. Linksansicht wird gespiegelt,
  keine Behauptung von vier separat gezeichneten Richtungen.

## Aktive Rig-Revision, 31.10.2026

Auf ausdruecklichen Nutzerwunsch wird der freigegebene Geist wie die Skelette
in Koerperteile geschnitten und ueber dieselbe Gelenkhierarchie animiert.
Kein neuer Imagegen-Aufruf, keine neue Illustration. Originale bleiben erhalten.

Nachfolgende Partikelrevision: mittlerer Schweif und Spitze geben kleine
Fragmente ihrer eigenen Quellpixel ab. `src/vfx/soul_fragments.gd` bereitet
die maximal 2x2 grossen Texturen einmal vor und setzt sie an die bewegten
Schweifknochen. `tail_mid` behaelt einen Kern; die Spitze laeuft in Partikel
aus. Keine Aenderung der Kopf-/Arm-Cutouts oder Spielregeln. Details:
`docs/NEKROMANT-SEELENPARTIKEL.de.md`.

- `rig/bind.png`: erster Hover-Key aus `guardian_atlas.png`, unveraenderte
  Koerperpixel; isolierte Blatt-Partikel entfernt, da die Staubaura diese bewegt.
- `rig/{head,torso,arm_l,arm_r,hand_l,hand_r,tail_root,tail_mid,tail_tip}.png`:
  neun transparente Cutouts, alle 128x80, gleiche Palette. Originalpixel an den
  Gelenken ueberlappen in einem 3px-Kreis. Keine neu erfundenen Koerperteile.
- Reproduzierbar: `scripts/import_soul_guardian_rig.gd`; Masken/Pivots/Eltern/Z
  aus `assets/data/soul_guardian_rig.json`. Schema in
  `docs/NEKROMANT-SEELENWAECHTER.de.md`.
- Live: `src/rig/soul_guardian_rig.gd`, bestehende RigLibrary und RigRenderer.
  Kontinuierliche Gelenkrotationen, verzoegertes Schweifschwingen, Ausholen,
  Greifen und Erholung. Der Original-Flipbook bleibt als Quelle erhalten,
  die fruehere Ganzkoerper-Ueberblendung ist durch das Rig ersetzt.

Internetquellen fuer die vorherige Stilprobe:
https://0x72.itch.io/dungeontileset-ii
https://nitie.itch.io/0x72-dungeon-animations
https://itch.io/t/1836676/pixel-tutorial-wraith
Es wurden keine fremden Internet-Sprites heruntergeladen oder als Assets importiert.
