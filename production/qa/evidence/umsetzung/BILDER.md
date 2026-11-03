# Bilder zur Umsetzung der Vorschläge A–D · Delve Disaster

**Datum**: 2026-11-01 · **Build**: Arbeitsstand `codex_v2` (uncommitted) · **Engine**: Godot 4.7.2, Fenster 1280×720, Compatibility
**Grundlage**: `production/qa/evidence/gameplay-review/VORSCHLAEGE.md` · **Spielcode**: nicht verändert

## Methode
Eine temporäre SceneTree-Probe (`scripts/_tmp_umsetzung_probe.gd`, danach gelöscht) hat jede Welt-Szene direkt instanziiert:
Krypta mit dem Schwertkämpfer, Frostgruft mit dem Magier (zweiter Lauf auch mit dem Schwertkämpfer), Hölle mit dem Nekromanten.
`settings_path` und `graphics_path` = `user://settings_test.cfg`, Profil `user://profile_test.json`; beide Dateien sind gelöscht.
Die echte `settings.cfg` und `profile.json` sind unverändert (Zeitstempel 31.10.). Der Held war unverwundbar (`state.inv`).
Gewartet wurde auf Spielzeit (`state.t`). Bilder: `force_draw` + Viewport-Textur. Dateien mit „-zoom“ sind 2×- bzw. 3×-Ausschnitte desselben Bildes.
Der Held wurde jeweils in die Mitte des größten Raums gesetzt. In der Frostgruft liegt dort eine Druckplatte des Rätsels.
Das Quadrat unter dem Helden in 05/06 ist also diese Platte und kein Effekt. Geprüft ist das am Hinweis „Falsche Reihenfolge. Die Platten erlöschen.“.

Log der Angriffsmarken (B2): `TOKENS skeletons=8 frames=291 max_melee=3 max_ranged=0 max_waiting=5 histogram_melee={0: 43, 1: 13, 2: 18, 3: 217}`.
Es haben also nie mehr als 3 Skelette gleichzeitig angegriffen, und bis zu 5 haben auf eine freie Marke gewartet.
Log des perfekten Blocks (B3): `reel=1.00 stun=1.00 charges 2 -> 2 hp=14`. Der Angreifer taumelt, die Ladung bleibt, kein Schaden.

## Bilder

| Datei | Punkt | Was zu sehen ist | Urteil |
|---|---|---|---|
| 01-krypta-boss-telegraph.png | A10, A13 | Knochenwächter-Stampfer bei 61 % der Vorwarnung: rot gefüllter Ring mit Lade-Scheibe und Rand. Die Boss-Leiste zeigt „WÄCHTER DER ETAGE“ auf einer dunklen Platte. | ok |
| 01b-krypta-boss-telegraph-zoom.png | A10 | Ausschnitt: Füllung, wachsende Ladung und Rand liegen auf dem 3-px-Raster | ok |
| 01c-krypta-boss-einschlag.png | A10 | 0,15 s nach dem Schlag: ein Staubring aus hellen Pixeln und dunkle Risslinien | ok · Die Risse sind dünn und blass, der Staub liest sich eher als Funkenring |
| 02-krypta-skelette-angriffsmarken.png | B2 | 8 Skelette um den Helden. Im Bild greifen 2 an, keins wartet. Höchstwert im Log: 3. | ok |
| 08-krypta-held-skelettschwerter-zoom.png | A3 | Getümmel aus der Nähe: Die Schwerter haben jetzt Körpergröße. Der Held steckt aber hinter den Skelettkörpern, nur Helmbusch und Schwert sind zu sehen. | **Problem** · Bei Verdeckung ist keine lesbare Kontur zu sehen |
| 08b-krypta-held-im-getuemmel.png | A3 | Dieselbe Gruppe 3,5 s später, auseinandergezogen | Problem · Der Held ist im Haufen schwer zu finden |
| 08c-krypta-held-verdeckt.png | A3 | 3 Skelette stehen direkt vor und neben dem Helden | Problem |
| 08d-krypta-held-verdeckt-zoom.png | A3 | 3×-Ausschnitt: Die Körper liegen über dem Helden, nur Busch und Klinge schauen heraus. Der helle/dunkle Verdeckungsring (story_hero.gd cover_inner/outer) ist auf den Knochen nicht zu sehen. In der Frostgruft (05d) sieht man ihn dagegen. | **Problem** |
| 03-hoelle-giftgas-gegner.png | A6, A2 | Giftwolke aus geditherten grünen Pixeln. Brandskelett und Glutschädel darin sind vollständig sichtbar. | ok |
| 03b-hoelle-giftgas-gegner-zoom.png | A6 | Ausschnitt: Körnung und Lücken, die Gegner liegen über dem Gas | ok |
| 03c-hoelle-nekromant-stab-zoom.png | A2 | Der Nekromant hält seinen Knochenstab | ok |
| 17-hoelle-reaktion-symbol.png | D3 | Feuer des Helden zündet das Gas. Über dem Punkt stehen das Pixel-Symbol, „Giftexplosion“, „NEU ENTDECKT“ und „+25 % EP“, dazu der Hinweis „Reaktion entdeckt … Menü > Elemente“. | ok |
| 17b-hoelle-reaktion-symbol-zoom.png | D3 | Ausschnitt des Schilds | ok · Die EP-Zeile sitzt sehr dicht auf dem Namen |
| 04-hoelle-rueckstand-3s.png | A6 | 3 s nach Explosion und Tod: keine weichen Scheiben. Es liegen nur Asche-Krümel, Schädelteile, ein Schwert und ein Herz. | ok |
| 04b-hoelle-rueckstand-3s-zoom.png | A6 | Ausschnitt | ok |
| 04c-krypta-blut-sofort.png | A6 | Zwei Zombies fallen: Blut als körniger Pixelfleck mit unregelmäßigem Rand | ok |
| 04d-krypta-blut-sofort-zoom.png | A6 | Ausschnitt | ok |
| 04e-krypta-blut-3s.png | A6 | 3 s später: Der Fleck liegt als Pixelmaterie, keine weiche Scheibe | ok |
| 04f-krypta-blut-3s-zoom.png | A6 | Ausschnitt | ok |
| 05-frost-eistrank-kruste.png | A6 | Eistrank geworfen: eine körnige Frostkruste mit Scherben in Trankfarbe | ok |
| 05b-frost-eistrank-kruste-zoom.png | A6 | Ausschnitt der Kruste | ok · Der Umriss ist eher ein gleichmäßiger Fleck |
| 05c-frost-eistrank-kruste-2s.png | A6 | 2 s später liegt die Kruste noch | ok |
| 05d-frost-eistrank-kruste-2s-zoom.png | A6, A3 | Ausschnitt. Rechts oben ist ein Eiszombie vor dem Helden, der helle Verdeckungsring ist sichtbar. | ok |
| 06-frost-kampf-kontrast.png | A4 | Frostgruft-Kampf: Der Boden ist dunkler als in polish/09. Eiszombies und Frostskelette haben eine dunkle 1-px-Kontur. | ok |
| 06b-frost-kampf-kontrast-zoom.png | A4 | Ausschnitt der Konturen. Der blaue Kasten unter dem Helden ist die Druckplatte. | ok |
| 06c-frost-held-allein-mage.png | A4 | Der Magier allein auf dem Schnee (auf einer Platte) | ok |
| 06d-frost-held-allein-mage-zoom.png | A4 | 3×-Ausschnitt: dunkler Rand um die Figur | ok · Der Rand ist schmal |
| 06c-frost-held-allein-swordsman.png | A4 | Der Schwertkämpfer allein (auf einer Platte) | ok |
| 06d-frost-held-allein-swordsman-zoom.png | A4 | 3×-Ausschnitt mit Rand | ok · Der Rand ist schmal |
| 07-frost-schnee-unter-fenster.png | A1, A8 | Frostgruft, Talentfenster auf dem LAUF-Reiter: kein Schnee über dem Fenster, Laufstufe und Heldenstufe sind erklärt | ok |
| 11-frost-inventar-umlaute.png | A7, A1, A8 | Inventar mit „RÜSTUNG“ und „GEWÖHNLICH“ in richtigen Großbuchstaben. Schnee nur außerhalb des Fensters, Titel „INVENTAR“. | ok · Das Fenster überdeckt rechts das „LAUFSTUFE“-Feld der Heldenleiste |
| 09-krypta-ragdoll-teile.png | POLISH #10 | 0,45 s nach dem Tod von 8 Skeletten: Teile mit Kontur und Pixel-Zerfall | ok · Die ersten Frames sind noch quadratische, stark gerasterte Platten. Die Schädel der Skelette sind aber auch quadratisch. |
| 09b-krypta-ragdoll-teile-zoom.png | POLISH #10 | Ausschnitt | ok |
| 09c-krypta-ragdoll-liegen.png | POLISH #10 | 2 s später: Schädel mit Augenhöhlen und Kontur, die Schwerter liegen am Boden | ok |
| 10-krypta-talentfenster.png | A5, A7, A8 | Heldentalente: Schrift ab 16 px, „50 Gold“ und „ab 5“ eindeutig, „1 Talentpunkt frei“, „ZURÜCK“ | ok |
| 10b-krypta-talentfenster-lauf.png | A13, A8 | LAUF-Reiter: ein Titel „LAUFSTUFE 1“, Punkte einmal genannt, Unterschied der beiden Stufen erklärt | ok |
| 12-krypta-hud-krit.png | A11, A12 | HUD: Heldenpanel mit fester Höhe (gleich hoch wie in 02 ohne Ressourcenzeile), deckende Minimap, Shift-Feld mit ⇧ und Schild, gesperrte Felder mit Schloss. Dazu „KRIT“ groß mit Pop und ein Weißblitz auf dem Skelett. | ok · „H/G“ steht leer ohne Erklärung, solange kein Trank da ist |
| 12b-krypta-krit-zoom.png | A12 | Ausschnitt: KRIT-Pixelschrift, weißer Treffer-Blitz | ok |
| 13-hoelle-pause-steuerung.png | A9, A13 | Steuerung mit „Rüstungskraft F“, breite Wertespalte ohne Umbruch, dunkle Abdeckung | ok · Der Fokusrahmen bleibt auf „Etage“, weil die Probe die Seite per Code gewechselt hat. Das ist kein Befund. |
| 14-hoelle-pause-elemente.png | D3 | Seite Elemente: „Entdeckt: 1 von 10“, Giftexplosion in Gold, die übrigen grau mit Ursache und Wirkung | ok |
| 15-hoelle-siegel-wahl.png | D1 | Siegel: zwei Segen mit festem Preis, [1]/[2] und „ESC · BEIDE LASSEN“, die Welt abgedunkelt | ok · Der Preis heißt „1 Herz“, die Heldenleiste zählt aber „LP“ (Preis 2 LP) |
| 16-krypta-tuer-inhalt.png | D2 | Tür in einen Seitenraum: eine Platte mit Herz-Symbol über der Öffnung. Die Minimap zeigt Truhen- und Herz-Symbole in den Räumen. | ok · Platten an Seitenwänden kommen erst nahe der Tür ins Bild |
| 16b-krypta-tuer-inhalt-zoom.png | D2 | Ausschnitt der Platte | ok |
| 18-krypta-perfekter-block.png | B3 | Shift im Fenster: „PERFEKT“ über dem Helden, der Angreifer blitzt auf, Knochensplitter | ok · Das „KRIT“ daneben stammt noch vom Bild davor |
| 18b-krypta-perfekter-block-zoom.png | B3 | Ausschnitt | ok |
| 18c-krypta-block-taumeln.png | B3 | 0,35 s später: Das Skelett steht taumelnd, kleine Goldsterne über ihm | ok · Die Sterne sind klein |
| 18d-krypta-block-taumeln-zoom.png | B3 | Ausschnitt | ok |

## Offene Befunde aus den Bildern
1. **A3 Held verdeckt (Krypta)**: Stehen Skelette vor dem Helden, verdecken ihre Körper ihn fast ganz (08, 08d). Der Verdeckungsring ist auf den weißen Knochen nicht zu sehen. Die Schwertgröße passt jetzt. In der Frostgruft ist der helle Ring sichtbar (05d).
2. **A10 Einschlag**: Staub und Risse sind da, aber schwach. Die Risse sind dünne, blasse Linien (01c).
3. Klein: Der Siegelpreis steht in „Herz“, das HUD zählt „LP“ (15). Das Inventar überdeckt das LAUFSTUFE-Feld (11). „H/G“ steht leer ohne Erklärung (12).

## Nicht im Bild geprüft
- B1 (Vorwarnzeiten) und C1–C9, D4–D6 sind Zahlen und Regeln. Die Bilder zeigen sie nicht.
- A13: Strahlen an Wänden kappen und Fundmeldungen zusammenfassen sind nicht aufgenommen. Es gab keinen Strahl-Gegner und keinen Mehrfachfund.
- A6: Lava-Kruste und Miasma sind nicht aufgenommen.
- Ton ist nicht prüfbar.
