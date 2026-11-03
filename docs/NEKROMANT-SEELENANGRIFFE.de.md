# Nekromant: großer Seelenring und geladene Seelenlanze

**Aktuelle Folgekorrektur:** [Schattensprung](NEKROMANT-SCHATTENSPRUNG.de.md)
setzt Ring/Seelenfeld auf fünf Sekunden und legt im Seele-Testraum den Sprung
auf Platz 3. Die Lanze bleibt gelernt und kann über die aktive Leiste zugewiesen werden.

01.11.2026, aktuelle Nutzerkorrektur. Die **Seelenlanze** wird aufladbar;
der normale Angriff bleibt erhalten. Seelenblitz wird zusätzlich größer.
Die bestätigten Wächterbefehle 5/6 und seine Umwandlung bleiben bestehen.
Neue Art verwendet die bereits angenommenen Geister-Cutouts und deren Rig.

## Spielregeln

| Fähigkeit | Aktuelles Verhalten |
|---|---|
| Seelenring (`soul_3`) | 10 m Außendurchmesser, 2 m breiter Feldsaum, freie Mitte mit 6 m Durchmesser. Nova 90/110/130 %, 22 Seelen, 11 s Abklingzeit. Normale Gegner werden 1,5 m über 0,3 s nach außen geschoben; Wände stoppen sie. |
| Feld danach | Erscheint nach 0,65 s, bleibt 4 s am ursprünglichen Ort. Gleiche Seelenmaterial-Pfütze und Rig-Geister; kein Material in der Mitte oder hinter Wänden. Festhalten weiterhin 0,45 s mit gemeinsamer 1,6-s-Sperre. |
| Seelenlanze (`soul_9`) | Fähigkeitstaste halten, beim Loslassen schießen. Nach spätestens 1,6 s automatischer Schuss. 22 Seelen beim Beginn, zusätzlich bis zu 20 während des Ladens. Kein Durchbohren mehr: endet am ersten Gegner, an einer Wand oder einem festen Hindernis. |
| Lanzenstärke | Bei Ladung q=0…1: Schaden=(100/120/140 %)×(1+2,5q); Kollisionsradius=8+11q Weltpixel. Voll geladen maximal 350/420/490 %. Beim Gegnerkontakt 50 % des direkten Schadens im Umkreis von 0,8+q Metern, mit eigener Wandprüfung. Kein Flächenschaden durch Wandkontakt. |
| Seelenblitz (`soul_1`) | 10 Weltpixel Kollisionsradius, 480 px/s, 120/140/160 % Schaden; weiterhin 8 Seelen und 4 s Abklingzeit. Großer artikulierter Geist statt kleinem Standardgeschoss. Endet beim ersten Kontakt. |

Eine Ladung wächst nur, soweit der Host zusätzliche Seelen bezahlen kann.
Bei Erschöpfung wird die bezahlte Teilladung ausgelöst. Kein negativer Vorrat,
keine Kraft-/Schadenswerte vom Client. Bewegung und Zielen bleiben möglich;
der Standardangriff und andere aktive Fähigkeiten warten während der Ladung.
Die volle 12-s-Lanzenabklingzeit beginnt beim Schuss. Tod, Raumwechsel,
Buildwechsel und Menüs brechen die Vorbereitung ab; bereits bezahlte Seelen
bleiben verbraucht. Abbruch hält weder Schild noch Angriff gedrückt.

## Begleiter

Alle acht Begleiterarten nehmen erreichbare Gegner in ihrer Nähe selbstständig
auf. Sichtkontakt ist keine Voraussetzung, wenn ein Weg um Deckung existiert.
Der erste Angriff folgt nach der vorhandenen Rig-Ausholzeit (0,2 s), statt erst
nach einer zusätzlichen 0,6-s-Startwartezeit. Normale Angriffstakte bleiben gleich.

Die Zielbindung nutzt überall die eindeutige numerische Gegnerkennung `tid`
(in der Krypta `id`). Der Artname eines Storygegners wird nicht mehr zu einer
ungültigen Zahl umgewandelt. Begleiter verfolgen ihr lebendes Ziel, auch wenn
der Besitzer in die Gegenrichtung läuft. Danach bekämpfen sie weitere nahe
Gegner und folgen erst bei beendetem Kampf wieder dem Besitzer.

Krypta nutzt die vorhandene Navigation. Hölle/Frostgruft erhalten für Begleiter
begrenzte lokale Rasterwege um tatsächliche Wände/Kisten. Wegprüfungen werden
kurz gepuffert; Relikt- und Unterklassen-Untergebene nutzen dieselbe Verfolgung.
Treffer benötigen weiterhin freie Sicht, auch wenn ein Gegner um eine Ecke
verfolgt wird. Bosse werden vom Seelenring weder geschoben noch festgehalten.

## Darstellung und Integration

`soul_projectile_art.gd` setzt Kopf/Körper/Schweif aus dem bestehenden Geisterrig
zusammen. Beim Laden sammeln sich Seelen an der Hand; der Geist und seine
Satelliten wachsen mit bezahlter Ladung. Aufpralle verwenden auslaufende
Pixelpartikel und entweichende Rig-Geister, an der vom Host bestimmten Position.
Die Einschlagsanimation läuft auf Clients lokal flüssig zwischen Snapshots.
Texturen bleiben ungefiltert. Kein neuer Actor-Katalog und keine Bildgenerierung.

`soul_projectiles.gd` prüft kurze Flugsegmente in Reihenfolge. So trifft selbst
ein langer Spielschritt den Gegner vor einer Wand; er verwirft den Treffer
nicht wegen einer weiter hinten liegenden Wand. Die Krypta verwendet weiterhin
die echten Körperteilmasken, Storywelten ihre Hittable-Regeln. Ladung und
Kontaktpositionen sind Anzeigezustand in Snapshots. Regeln/Protokoll: **14/4**.

## Testen

Testraum → **Nekromant → Seele anwenden**:

1. **2** erzeugt den großen Ring und stößt nahe normale Gegner zurück.
2. **3 halten**, auf einen Gegner zielen, **loslassen**: Seelenlanze. Die
   Seelenanzeige sinkt beim Laden; ohne ausreichenden Vorrat fällt sie kleiner aus.
3. **1** schießt den größeren Seelenblitz. Kisten, Wände und Gegner stoppen ihn.
4. **R** beschwört den Wächter; Gegner holen und selbst weggehen. Er verfolgt
   seinen Gegner weiter. **5 Seelenstrahl, 6 Seelenwelle** bleiben erhalten.

Für dauerhafte Begleiter den jeweiligen Diener-/Tier-/Magierzweig anwenden.
Der aktuelle Baum erlaubt nur einen Spezialisierungszweig je Figur.

Aktuelle Testbelege und Spielaufnahme:
[Seelenangriffe-Nachweis](../production/qa/evidence/necro-soul-attacks/README.md).
