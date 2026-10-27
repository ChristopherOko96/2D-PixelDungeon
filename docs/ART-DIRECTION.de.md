# Artstyle getrennt abstimmen

**Jüngste Nutzervorgabe27.10.2026:**32×32-Chibis mit größeren Köpfen, sichtbaren
kurzen Beinen, kräftigen Händen und niedlicherer Ausstrahlung. Lovecraft-
Tentakelboss ersetzt den gehörnten Dämon. Die gelieferten Höllenreferenzen
bestimmen nur Pixeldichte; Welt/Material/Palette werden nicht übernommen.
[Aktuelle Bilder und Quellen](CHIBI32-ELDRITCH.de.md).

**Aktuelle Figurenrevision Story023:** Vier neu generierte Spieler und die
vier Gegner-/Bossidentitäten besitzen je48 eigene Animationsabläufe in vier
Ansichten. Die [Animationswerkstatt](ACTOR-ANIMATIONS.de.md) erlaubt den direkten
Vergleich; Richtungen zählen nicht als zusätzliche Aktionen. Quellen und alte
Grafiken bleiben erhalten. Die persönliche Bewertung dieser Revision ist offen.
Raummaterial, warme Fackeln und32px-Welt bleiben unverändert.

**Verbindliche Grundlage vom26.10.2026:** Der Nutzer legt den vorhandenen
ruhigen Krypta-Stil für die weitere Arbeit fest. Story022 ergänzt dazu
Skelettbogenschütze, Nekromant und kleinen Schildkrieger mit gemeinsamer
Pixelgröße/Palette sowie Idle-, Lauf-, Angriffs- und Trefferreaktionen.
[Aktueller Stilstandard, Gegner und animierte Ansicht](CRYPT-ENEMIES.de.md).
Die Werkstatt ist auf diesen Stand aktualisiert. Die folgenden älteren
Vergleiche sind historische Einordnung, kein Auftrag für weitere Materialwechsel.

**Aktuelle Fortschreibung:** Die aktive Krypta verwendet den ruhigen32px-Stil
des ersten Prototyps, klare Mauerkanten und orange Fackeln ohne Raumdekoration.
Pixel Operator8 und die volle Fensterfläche ergänzen diese Richtung.
[Stilstand](ORIGINAL-TILE-RESTORE.de.md),
[Schrift/Vollbild/Review](UI-VOLLBILD-REVIEW.de.md).
Die Werkstatt und älteren Bilder unten dokumentieren frühere Vergleichsstände.

Stand: 26.10.2026. Die Nutzerkorrektur lautet **Brotato**, nicht Bravetail.
Raumfarben/Wände, Figuren/Animationen und HUD sollen getrennt beurteilt werden.
Die Herzen bilden dabei eine zusammenhängende Grafik. Native Quellen und
Spielraster sind wieder32×32. Die gelieferten Atlanten bleiben unverändert;
ihre16-Pixel-Regionen werden ganzzahlig auf das32-Pixel-Raster projiziert.

## Online-Referenzen und unsere Ableitung

| Quelle | Beobachtung / gestalterische Ableitung für Basement Run |
| --- | --- |
| [Brotato, offizielle Storebilder](https://store.steampowered.com/app/1942280/Brotato/) | Starke Figurenkonturen und deutlich getrennte Kampf-/Pickupfarben als Lesbarkeitsreferenz. Unsere Übertragung bleibt im vorhandenen Pixelstil. |
| [The Binding of Isaac: Rebirth, offizielle PlayStation-Galerie](https://store.playstation.com/it-ch/product/EP2103-CUSA01344_00-BINDINGOFISAACP4) | Kompakte Herzgruppe und räumlich getrennte Karten-/Ressourceninformationen. Daraus leiten wir eine geschlossene HP-Grafik und getrennte Zusatzinformationen ab. |
| [Heroes of Hammerwatch II, offizieller Store](https://store.steampowered.com/app/619820/Heroes_of_Hammerwatch_II/) | Ergänzende Referenz für Top-down-Pixelräume und unterscheidbare Koop-Figuren. |
| [Children of Morta, offizieller Store](https://store.steampowered.com/app/330020/Children_of_Morta/) | Ergänzende Referenz für Licht, Figurensilhouetten und kurze Treffer-Effekte. |

Die rechte Spalte beschreibt unsere Designableitung. Die Projektgrafiken stammen
weiterhin aus den gelieferten Sheets, unserem Sprite-Generator und den aus
`main` übernommenen0x72-Animationen samt Lizenz.

## Godot-Werkstatt öffnen

1. Im Godot-Dateisystem **`src/art_reference.tscn`** öffnen.
2. Die Szene ist direkt im 2D-Editor sichtbar. **F6** startet ihre Bedienelemente;
   **F5** startet weiterhin das eigentliche Spiel.
3. Zwischen **GESAMTBILD**, **NUR RAUM**, **FIGUREN / FX** und **NUR HUD** wechseln.
4. Die Palette und den LP-Zustand rechts ändern. Animationen und Effekte lassen
   sich zum Vergleichen einfrieren beziehungsweise ausblenden. Der Türzustand
   ist separat umschaltbar.
5. Am Wurzelknoten im Inspector **Style Profile** aufklappen: Boden-/Wandfarbe,
   Wandhöhe, Säulenhöhe und Umgebungsschatten lassen sich unmittelbar ändern.

Die feste Komposition enthält Nischen, Säulen, Türen, einen eigenen Abstieg,
vier Figurenfarben, zwei Gegnersilhouetten, Feuer, Truhe, Perkicons und HUD.
Sie ist eine **Designvorschau**. Die Figureneffekte demonstrieren bestehendes
Trefferfeedback; die Szene ist kein weiterer Multiplayer-/Kampfnachweis.
Idle-/Lauf-/Trefferframes der Figuren sowie Treffer- und Todesfeedback sind
inzwischen aus dem Godot-Stand von `main` übernommen. Originalfiguren mit16×28
Pixeln werden bei2× gezeichnet; das sind keine neu gezeichneten32×32-Frames.

## Eine HP-Grafik

`src/health_strip.gd` setzt volle, halbe und leere Herzen aus dem Original-UI-Sheet
auf ein gemeinsames transparentes Bild. Bei 8 LP sind das vier Herzplätze;
7 LP erscheinen als drei volle und ein halbes Herz. Der native Abstand beträgt
3 Pixel zwischen 9×8-Pixel-Symbolen, die Anzeige skaliert ganzzahlig.

Das Live-HUD zeichnet die komplette Zeile mit einer ImageTexture. Es erzeugt
sie nur bei Änderung von LP, Kapazität, sichtbarer Herzanzahl oder Quelltextur
neu. Das aktuelle Live-HUD verwendet den kompakten Modus mit3×-Herzen oben links.
Zahlen, Raumfortschritt und Karte liegen im [Esc-Menü](SPIELMENUE.de.md).
Die ausführliche Artstyle-Referenz behält ihre getrennten Darstellungselemente.

- [Einzelne Herzgrafik, 7/8 LP](../production/qa/evidence/hearts-7-of-8.png)
- [Volle, teilweise und leere Zustände in einem Bild](../production/qa/evidence/health-strip-states.png)

## Gemeinsame Darstellung, austauschbares Profil

`src/art_reference.tscn` verwendet dieselben `dungeon_view.gd`,
`dungeon_tiles.gd` und `dungeon_hud.gd` wie das Spiel. Die Vorschau ist keine
zweite Grafikimplementierung. Ihre Ebenenfilter sind optionale
`presentation_layers`: `room`, `actors`, `props`, `effects`. Ohne Filter zeichnet
das Spiel wie bisher alle Ebenen. Feuerständer und Flamme liegen im selben
Originalframe; beim Ausblenden der Effekte bleibt in der Raumsicht Frame0 sichtbar.

`assets/data/art_style_reference.tres` ist das gemeinsame Präsentationsprofil.
Das Spiel übernimmt es lokal im Renderer. Die Referenzszene überträgt dessen
Werte zusätzlich als `room_layout.art_style`, um Änderungen direkt zu zeigen.
Geometrie, Treffer und Netzwerkautorität werden von diesen Einstellungen nicht
verändert. Eine andere Rastergröße oder echte neue Raumsilhouette benötigt
weiterhin einen eigenen Schritt für Kollisionen, Spawns und Wegsuche.

| Profilwert | Einheit / Standard |
| --- | --- |
| `floor_tint`, `wall_tint` | Farbmodulation, Weiß erhält die gelieferten Farben |
| `pillar_height` | Native Weltpixel,24; zulässiger Vorschaubereich8–40 |
| `north_wall_height` | Native Weltpixel,48; Bereich24–48 passend zum freien Rand |
| `shadow_strength` | Faktor1; Bereich0–1,5 für Umgebungsschatten |

## Nachweise und nächster Schritt

Alle vier Modi wurden in einem echten Godot-Fenster gerendert und angesehen.
Die Szene lädt auch im Editor ohne Netzwerkstart. Profiländerungen aktualisieren
die Darstellung und lassen die Hindernisrechtecke unverändert.

- [Gesamtbild](../production/qa/evidence/art-reference-overview.png)
- [Raum](../production/qa/evidence/art-reference-room.png)
- [Figuren/Effekte](../production/qa/evidence/art-reference-actors.png)
- [HUD](../production/qa/evidence/art-reference-hud.png)

Die vier oben verlinkten Aufnahmen zeigen die historische16-Pixel-Abstimmung.
Der aktuelle32-Pixel-Stand ist bei [Animationen und Übergängen](ANIMATIONEN-UEBERGAENGE.de.md)
abgebildet. Die Werkstatt ist die Grundlage für den nächsten gemeinsamen Stilentscheid.
Anschließend werden die gewählten Proportionen/Farben auf zusätzliche
Raumvorlagen übertragen und die übernommenen Charakteranimationen weiter poliert.
Die bisher offene LAN-/Latenzabnahme bleibt ein eigener Entwicklungsschritt.
