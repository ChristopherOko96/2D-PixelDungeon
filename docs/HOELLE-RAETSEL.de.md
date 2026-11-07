# Höllen-Rätsel im Weltbauer (Story 3)

Freigegeben vom Nutzer am 07.11.2026 (Vorschau „Hölle Ideenwerkstatt“, Fassung 2,
https://claude.ai/artifact/HxHGAhS489KrwgVaLodYrU). Die Hölle baut ihre Etagen wie Krypta und
Frostgruft aus Weltbauer-Raumdateien (`assets/data/world_rooms/hell/h_*.json`, gebaut von
`tools/hell_dungeon/rooms/build_hell_rooms.js`). Rätselräume haben die Rolle `jump`, sind
optional (ein freier Weg verbindet alle Türen), stehen an einer Inschrift und zahlen nach der
Beuteordnung (`docs/BEUTEORDNUNG.de.md`, Stufe 1–5 je Raumdatei). Von jedem Rätsel gibt es
mindestens fünf Räume, Stufe 1 bis 5. Nutzerwunsch: kniffliger und größer als in der Vorschau.

Mechaniken in `src/world_kit/hell_puzzles.gd` (Teile im Weltbauer, Welt „hell“). Ein Teil liegt in
einer Zelle; Teile derselben Gruppe (`group`) gehören zu einem Rätsel.

| Rätsel | Teile | Regel |
|---|---|---|
| **Kettenbrücken** | `hell_winch` (sets: Liste der Brücken-Nummern), `hell_bridge` (nr, up) über Lava | E an der Winde schaltet jede Brücke ihrer Liste (oben ↔ unten). Gehen geht nur über gesenkte Brücken. Lights-Out-artig; Löser prüft Lösbarkeit. |
| **Flammentakt** | `hell_vent` (Schlot; Takt beat s, Phase aus x+y) | Phase p = (Takt − x − y) mod n: p = 0 brennt, p = n−1 glüht (Warnung). Wer im Brand steht, verbrennt (1 Treffer) und steht an der Rune. |
| **Lavaflut** | `hell_flood` (Flutboden), `hell_stone` (Basalt), Zyklus cycle/ebb/warn | Flutboden ist in der Flut tödlich (1 Treffer, zurück zur Rune), Steine immer sicher. |
| **Blutpreis** | `hell_thorns` (Dorn), `hell_blood_gate`, `hell_blood_bowl` | Dorn kostet beim ersten Betreten ein Dornenherz (2 × dmg LP), danach flach. Blutgitter öffnet gegen ein Dornenherz. Die Schale zählt gezahlte Herzen: Pfad billig/mittel/teuer → hoard_shift −1/0/+1 (reward_rules.json blood). Stoppt bei 1 LP. |
| **Lavaschleusen** | `hell_pipe` (kind I/L, rot), `hell_spout` (Maul, dir), `hell_forge` (Schmiede, Gruppe), `hell_sluice` (Hebel) | E auf Rinne dreht sie. Hebel lässt die Lava vom Maul durch die Rinnen fließen; erreicht sie die Schmiede (richtige Seite), löst die Gruppe (Gitter/Truhe frei). Sonst läuft sie aus. |
| **Dämonenaugen** | `hell_eye` (dir, open, closed, off) in der Wand | Das Auge sieht seine Reihe bis zur ersten Deckung (Säule, Block). Echtzeit-Takt (beat s): open Takte offen, closed zu, letzter zu-Takt glimmt. Gesehen = 1 Treffer, zurück zur Rune. |
| **Schleusenwerk** | `hell_valve` (label A/B), `hell_channel` (Rinne, wet-Regel), Winde + Brücke | Rinnen sind nass/trocken nach Ventilformel je Rinne (`wet`: Ausdruck aus A/B), nasse Rinnen sind Lava. Brücke über einer Rinne trägt immer. |
| **Kettenwacht** | `hell_eye` (immer offen), `hell_shield` (chain), Winden mit chain, Brücke an Kette 1 | Kette k schaltet alle Schilde mit chain k (Schild unten = Deckung) und Brücken mit chain k (gegensinnig). |

Gemeinsam: Rune am Rätselanfang (`hell_rune`): Wer verbrennt, steht dort wieder (wie Frost-Rune).
Brand kostet einen Treffer (dmg(T) LP, nie tödlich unter 1 LP? nein: normaler Schaden).

Stufen je Rätsel (Größe und Härte): Stufe 1 klein und mit kurzem Weg, Stufe 5 groß, mehrere
Abschnitte, schnellerer Takt, mehr Winden/Ventile/Augen. Die Stufe steht in der Schatztruhe der
Raumdatei (`loot.tier`).

Weitere Räume der Hölle: Eingang, Kampfräume (kompakt, Lava, Schlote), Schlüsselkammer, Bossräume
(Boss nie in Lava), Portal, Geheimräume, Schatztresor, Opfergrube (Wellenkampf), Teufelspakt,
Opferstein (Preisräume nach Beuteordnung Abschnitt 6).
