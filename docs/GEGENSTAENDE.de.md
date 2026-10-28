# Gegenstände: Waffen, Flüche, Tränke (umgesetzt, 28.10.2026)

Wunsch: Man startet mit einer gewöhnlichen Waffe und findet bessere bis
legendär in Kisten und Truhen. Gefundenes ist oft unbekannt und verflucht.
Kristalle zeigen, was es ist; Fluchbrechersteine machen den Fluch zum Segen.
Tränke heißen nur nach ihrer Farbe, bis man sie erkennt, und die Farben werden
jeden Lauf neu gemischt.

Entscheidungen: Waffen je Klasse; eine verfluchte Waffe klebt an der Hand, bis
der Fluch gebrochen ist; Kristall oder Ausprobieren (Trinken, Werfen) erkennt
Tränke für das ganze Team; das Inventar hält das Spiel nicht an.

## Seltenheiten

GEWÖHNLICH (grau), UNGEWÖHNLICH (grün), SELTEN (blau), EPISCH (violett),
LEGENDÄR (gold). Je tiefer die Etage, desto öfter seltene Funde
(`rarity_weights` in `items.json`, Etage 1 bis 10). Epische und legendäre Funde
strahlen am Boden.

## Waffen (37, jede mit eigenem Bild)

| Klasse | Gewöhnlich | Ungewöhnlich | Selten | Episch | Legendär |
|---|---|---|---|---|---|
| Schwertkämpfer | Kurzschwert (Start), Rostschwert, Dolch, Machete | Hackebeil, Axt, Streitkolben | Ritterschwert, Katana, Speer, Sägeschwert | Duellklinge, Kriegsaxt, Großhammer, Prunkschwert | Rubinklinge, Sonnenklinge, Sternenschneide, Doppelaxt |
| Bogenschütze | Kurzbogen (Start), Jagdbogen | Waldbogen, Knochenbogen | Frostbogen, Glutbogen | Blutbogen, Leerenbogen | Sonnenbogen |
| Magier | Smaragdstab (Start), Rubinstab | Bernsteinstab, Saphirstab | Knochenstab, Amethyststab | Eiszepter, Leerenstab | Sonnenstab |

Jede Waffe bringt Schaden und Tempo mit, Nahkampfwaffen Reichweite und Bogen,
Bogen und Stäbe Geschossgeschwindigkeit und Flugzeit, Stäbe Explosionsradius.
Viele haben Wirkungen (Gift, Frost, Brand, Blitz, Durchschuss, Zielsuche,
Lebensraub …). Gefundene Bogen und Stäbe färben ihre Schüsse in ihrer eigenen
Leuchtfarbe (`glow`).

## Flüche und Segen

60 % der gefundenen Waffen sind verflucht. Man sieht es erst beim Anlegen oder
mit einem Kristall. Eine verfluchte Waffe lässt sich nicht ablegen oder
tauschen, bis ein Fluchbrecherstein den Fluch bricht; dann wird er zum Segen.

| Fluch | Wirkung | Segen danach |
|---|---|---|
| Dornenfluch | Alle paar Sekunden ein Dornenspieß unter dir (mit Warnung) | Dornenwacht: Dornen spießen den nächsten Gegner auf |
| Brennende Klinge | Die Waffe verbrennt dich manchmal beim Angriff | Flammenklinge: Treffer setzen in Brand |
| Bleierne Hand | Angriffe 40 % langsamer | Flinke Hand: 20 % schneller |
| Siegel der Stille | Eine Fähigkeit ist versiegelt | Entfesselt: Fähigkeiten laden 25 % schneller |
| Blutzoll | Alle 25 s 1 Schaden | Lebensraub: jeder fünfte Kill heilt |
| Zerbrechlich | Jeder Treffer gegen dich wiegt ein halbes Herz mehr | Gehärtet: ein Treffer pro Kampfraum wird abgewehrt |
| Schwerfällig | 20 % langsamer gehen | Leichtfuß: 15 % schneller |
| Fluch der Nacht | Dein Licht wird schwach | Mondlicht: 12 % mehr kritische Treffer |

## Tränke (12)

Unbekannt heißen sie nur „Roter Trank“, „Gelber Trank“ usw. Die Zuordnung
Farbe → Trank wird jeden Lauf neu gemischt. Ein Kristall, Trinken oder Werfen
verrät den Trank, und dann kennt ihn das ganze Team.

| Trank | Trinken | Werfen |
|---|---|---|
| Heiltrank | Heilt 2 Herzen | Heilt Verbündete im Umkreis um 1 Herz |
| Stärketrank | 20 s 40 % mehr Schaden | Zerplatzt wirkungslos |
| Eiltrank | 15 s 35 % schneller | Zerplatzt wirkungslos |
| Schutztrank | Wehrt die nächsten 2 Treffer ab | Zerplatzt wirkungslos |
| Trank der Erholung | 18 s lang alle 3 s ein halbes Herz | Verbündete im Umkreis erholen sich |
| Trank der Nachbeben | Für diesen Lauf: Treffer lösen kleine Explosionen aus | Drei Explosionen am Ziel |
| Trank der Kettenblitze | Für diesen Lauf: Treffer springen als Blitz über | Blitz springt zwischen Gegnern |
| Feuertrank | Du brennst 4 s | Flammenmeer, Gegner darin brennen |
| Eistrank | 6 s langsam | Friert Gegner im Umkreis 2,5 s ein |
| Blendtrank | 10 s fast blind | Gegner im Umkreis taumeln 4 s |
| Gifttrank | Gift 5 s | Giftwolke vergiftet Gegner |
| Sprengtrank | Explodiert in deinen Händen | Große Explosion am Ziel |

Die zwei Lauf-Tränke (Nachbeben, Kettenblitze) werten die eigenen Treffer bis
zum Ende des Laufs auf.

## Kristalle und Steine

- **Identifizierungskristall**: zeigt Name, Werte und Fluch einer Waffe oder
  den Namen eines Tranks.
- **Fluchbrecherstein**: bricht den Fluch der Waffe in der Hand; der Fluch wird
  zum Segen.

## Wo man Gegenstände findet

| Quelle | Chance | Was |
|---|---|---|
| Kiste (zerschlagen) | 14 % auf Etage 1 bis 24 % auf Etage 10 | Waffe, Trank, Kristall oder Stein |
| Truhe (mit E öffnen) | 70 bis 90 % | Waffe, Trank, Kristall oder Stein, dazu ein Perk |
| Mimik (besiegt) | immer | eine Waffe, mindestens selten, dazu zwei Perks |
| Goldkiste (selten, 4 Schläge) | immer | eine Waffe, mindestens selten, plus Kristall und Stein |

Pro Etage gibt es mit 60 % Chance eine Goldkiste. Gegenstände liegen leuchtend
am Boden; der nächste zeigt seinen Namen. Darüberlaufen hebt sie auf, solange
der Rucksack (12 Plätze) nicht voll ist. Gleiche Tränke, Kristalle und Steine
stapeln sich.

## Bedienung

- **I** oder **Tab** öffnet das Inventar, ebenso der Knopf unten rechts. Das
  Spiel läuft weiter.
- Klick wählt einen Platz; die Knöpfe zeigen, was geht: ANLEGEN,
  IDENTIFIZIEREN, FLUCH BRECHEN, TRINKEN, WERFEN, ABLEGEN.
- Doppelklick: Waffe anlegen oder Trank trinken.
- WERFEN: das Fenster schließt, der nächste Klick in die Welt ist das Ziel
  (bis 320 Pixel weit, an Wänden endet der Wurf). ESC bricht ab.
- Funde und Ereignisse erscheinen kurz als Hinweis oben.

## Technik

- Daten: `assets/data/items.json` (Waffen, Flüche, Tränke, Farben, Fundraten).
- Regeln: `src/items/item_rules.gd` (Waffe → Werte, Fluch/Segen anwenden, nach
  `PerkRules.rebuild`), `src/items/inventory.gd` (Host: Rucksack, Aktionen,
  Würfe, Funde, Flüche über die Zeit, Farben pro Lauf).
- Oberfläche: `src/ui/inventory_panel.gd`; Bodenfunde in `src/vfx/skill_fx.gd`.
- Bilder: `assets/sprites/items/` (erzeugt von `scripts/make_item_sprites.gd`)
  und kopierte 0x72-Waffen/-Flaschen in `assets/sprites/0x72/`.
- Test: `tests/items_test.gd`. Belege: `production/qa/evidence/items/`
  (`scripts/capture_items.gd`).

## Angriffe von Bogenschütze und Magier

- Pfeile ziehen eine Lichtspur (bei kritischen Treffern länger und golden mit
  Stern), der Bogen blitzt beim Abschuss, am Ziel blitzt ein Stern.
- Zauber fliegen als leuchtende Kugel mit Runenring, kreisenden Funken und
  Leuchtspur; am Stab erscheint ein kleiner Zauberkreis, am Ziel eine Nova.
- Schüsse erhellen die dunkle Krypta, während sie fliegen.
- Farbe: Leuchtfarbe der gefundenen Waffe, sonst Element des Builds, sonst
  Standard.
- Technik: `src/vfx/attack_fx.gd`, neutrale Bilder `spell_orb` und
  `spell_burst` (`scripts/make_fx_sprites.gd`). Test: `tests/attack_fx_test.gd`.
  Belege: `production/qa/evidence/attacks/` (`scripts/capture_attacks.gd`).
