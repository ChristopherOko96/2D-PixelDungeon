# Story 003: Kampfgefühl, Animationen, schießende Gegner und Hauptmenü

> **Epic**: Dungeon aus Raumvorlagen
> **Status**: In Progress
> **Layer**: Presentation + Feature
> **Type**: Visual/Feel
> **Estimate**: L
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-10-25

## Context

**GDD**: `design/game-brief.md`
**Requirement**: Spielgefühl in Richtung The Binding of Isaac: lebendige Figuren, Treffer mit Gewicht, kraftvolle Angriffe, befriedigende Tode; Hauptmenü.
**ADR Governing Implementation**: N/A (minimal — no ADRs)
**Engine**: Godot 4.7.2 | **Risk**: HIGH (4.7 timeline rating in `docs/engine-reference/godot/VERSION.md`)

Wünsche des Projektinhabers vom 25.10.2026: Figuren animieren beim Laufen,
Gegner animiert, Rückstoß bei Treffern, schießende Gegner, Hauptmenü; danach
eine ausführliche Vorgabe für ein Kampfanimationssystem (Squash & Stretch,
Anticipation, Hit-Flash, Partikel, Screen Shake, Hitstop, Sounds,
Windup/Active/Recovery, Todesanimation mit verzögertem Entfernen, modulare
Komponenten). Ausdrücklich gewünscht: in die bestehende Struktur integrieren
statt parallel neu bauen.

**Architekturentscheidung.** Das Spiel ist host-autoritativ vernetzt und zeichnet
alles in `dungeon_view.gd::_draw()`; es gibt keine CharacterBody2D-Szenen pro
Gegner. Die Vorgabe wird deshalb auf diese Struktur abgebildet, nicht als
Szenenbaum nachgebaut:

| Vorgabe | Umsetzung |
|---|---|
| HealthComponent | `Health` / Gegner-HP im Host (`game.gd`) |
| AttackComponent | `_update_attack` + `_fire_pattern` (Windup → Active → Recovery, Muster `aimed`/`ring` aus `balance.json: attacks`) |
| DeathComponent | Sterbezustand im Host (`dying`), Darstellung in `vfx/feedback.gd` |
| HitFeedbackComponent | `src/vfx/feedback.gd` (Blitz, Feder-Squash, Lean, Hitstop, Shake) |
| VFXManager | `src/vfx/particles.gd` (Partikel-Pool, Bodenflecken) |
| Sounds | `src/vfx/sfx.gd` (zur Laufzeit synthetisiert, Player-Pool) |
| ShaderMaterial-Blitz | weiße Silhouetten-Texturen pro Frame (einmal erzeugt), da ein Draw-Call-Renderer keine Material-Instanz pro Gegner hat — es kann nichts geteilt werden |

Mechanik (Host) und Darstellung (Client) sind getrennt; die Darstellung reagiert
auf Zähler im Snapshot (`hits`, `attacks`, `shots`, `hurts`) und ist damit robust
gegen verlorene Pakete und doppelte Auslösung.

## Acceptance Criteria

- [x] Spielfiguren (vier 0x72-Helden) und Gegner (Kobold, Ork-Schamane, Big Demon) laufen/stehen animiert, 2× auf dem 32er-Raster, und schauen zur Maus bzw. zum Ziel.
- [x] Treffer erzeugen Rückstoß in Trefferrichtung (Gegner, Boss schwächer, Spieler); Rückstoß schiebt nie durch Wände und klingt ab.
- [x] Ork-Schamanen halten Abstand und schießen; Angriffe laufen in Phasen Ausholen → Schuss → Erholung, das Projektil erscheint im aktiven Moment, beim Ausholen bleibt der Schütze stehen. Der Boss nutzt dasselbe System mit Ring-Muster.
- [x] Treffer-Rückmeldung: kurzer roter Blitz (Boss halbe Stärke), Squash & Stretch mit Nachschwingen, Funken- und Blutpartikel, leichtes Bildschirmwackeln, Treffer-Sound; schnelle Mehrfachtreffer stapeln sich nicht.
- [x] Tod: Gegner greift nicht mehr an, ist nicht treffbar, macht keinen Berührungsschaden; weißer Blitz, letzter Stoß, Plattdrücken/Umkippen/Ausblenden, Partikel, Bodenfleck, Sound, Hitstop und Wackeln (Boss stärker); erst danach entfernt. Partikel überdauern den Gegner. Der Raum öffnet erst nach der Animation.
- [x] Hauptmenü mit „Spiel starten“ (Solo), „Mehrspieler“ (bisherige Lobby, mit Rückweg) und „Beenden“; ein Solo-Lauf kehrt danach ins Menü zurück.
- [x] Bestehende Tests, Netzwerkläufe und Vierer-Lobby bleiben grün.
- [x] Bildbelege aus dem echten Spiel in `production/qa/evidence/story-003-combat-feel/`.

## Out of Scope

- Echte Hoch/Runter-Sprites (0x72 hat nur links/rechts).
- Simulations-Hitstop für alle Spieler (Hitstop ist bewusst reine Darstellung, damit vier vernetzte Spieler nicht gemeinsam einfrieren).
- Musik, Lautstärkeregler, Optionen-Menü.

## Files

- `src/game.gd`, `src/data/balance.json`, `src/dungeon_view.gd`, `src/main_menu.gd`
- `src/vfx/feedback.gd`, `src/vfx/particles.gd`, `src/vfx/sfx.gd`
- `assets/sprites/0x72/` (61 Einzelbilder, `LICENSE-NOTE.md`)
- `tests/game_rules.gd`, `tests/feedback_test.gd`
- `production/qa/evidence/story-003-combat-feel/01–07`

## Test Evidence

**Story Type**: Visual/Feel — Bildbelege und Abnahme durch den Projektinhaber.

Ausgeführt am 25.10.2026 (Godot 4.7.2, lokal):
- `GAME_RULES checked=59 failures=0` (Rückstoß, Wände, Schütze mit Windup/Active/Recovery, Sterbezustand, Raum erst nach Tod offen, Standard-Port).
- `FEEDBACK checked=19 failures=0` (keine Doppelauslösung, Nachschwingen, Hitstop friert ein, Mehrfachtreffer stapeln nicht, Tod blitzt weiß, Boss-Blitz halbe Stärke, Raumwechsel räumt auf, Zähler-Neustart nach neuem Lauf). Gegenprobe: überdämpfte Feder und doppelte Auslösung lassen den Test fehlschlagen.
- Unabhängige Prüfung durch den `godot-gdscript-specialist`: keine Abstürze, keine 4.7-API-Probleme, Sterbezustand dicht. Umgesetzt: Zähler-Rücksetzung nach Neustart, kein Hitstop bei normalen Boss-Treffern, `_apply_snapshot` mit Standardwerten, Division durch eine Dauer von 0 abgesichert. Offen (älter als diese Story): Jeder Snapshot enthält die volle Raumgeometrie und wird ab 1100 Byte zuverlässig statt verlustbehaftet gesendet.
- `DUNGEON_GENERATOR checked=9508`, `DUNGEON_INTEGRATION checked=26`, beide ohne Fehler.
- Zwei echte Prozesse bis zum Bosssieg (7 und 10 Räume), Vierer-Lobby PASS.
- Godot Movie Maker (20 fps, 700 Bilder) eines kompletten Laufs; Ausschnitte als Bildbelege 02–07; Hauptmenü aus dem echten Fenster (01).
- Beim Durchsehen gefunden und behoben: (1) Solo-Start aus dem Menü scheiterte, weil das Portfeld „7777.0“ enthielt (Fehler seit `codex_v2`); (2) der Boss blitzte unter Dauerbeschuss fast durchgehend weiß — Treffer blitzen jetzt rot und beim Boss mit halber Stärke.

**Status**: [x] Vorhanden; Abnahme des Spielgefühls durch den Projektinhaber steht aus.

## Dependencies

- Depends on: `story-002-isaac-floor.md`
