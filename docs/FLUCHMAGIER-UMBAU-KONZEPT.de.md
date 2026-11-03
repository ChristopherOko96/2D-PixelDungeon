# Fluchmagier: freigegebener Fluchgeist und umgesetzter Umbau

Konkreter Entwurf vom 01.11.2026 auf `codex/port-0x72-onto-main`.
Nach Ansicht der konkreten Tafel hat der Nutzer mit „Bau das mal bitte.
Genau so“ die Übernahme freigegeben. Der eigenständige Fluchgeist und die
unten beschriebenen Mechaniken sind jetzt integriert. Aktuelle Regeln und
Testanleitung: `docs/NEKROMANT-DIENER-FLUCH.de.md`.

## Fluchgeist, Kandidat 1

Tafel: [Fluchgeist-Konzept](../production/qa/evidence/curse-spirit-concept-v1/fluchgeist-konzept-v1.png).
Kantige, gesprungene Knochenmaske mit violettem Fluchzeichen, schmalen grünen
Augenschlitzen, beweglichem Fangkiefer, zwei vorgezogenen Greifklauen und
einem dunklen Kern. Der Schweif besteht aus zerrissenen violetten Bändern
mit kleinen giftgrünen Ausströmungen. Eigene Silhouette und Anatomie;
vorhandene Seelengeister werden dafür nicht umgefärbt oder wiederverwendet.

Implementiert sind acht Teile für das vorhandene Rig-System: Maske/Kopf,
Unterkiefer, Torso/Kern, linke Klaue, rechte Klaue sowie Schweifwurzel,
Schweifmitte und Schweifspitze. Kiefer und Hände führen die Bewegung an,
die drei Schweifgelenke folgen verzögert. Schweben, Umkreisen und gerichteter
Fluchflug laufen durch kontinuierliche Gelenkposen.

`scripts/import_curse_spirit_rig.gd` schneidet die acht Teile aus der
freigegebenen Tafel aus. Native Ebenen liegen unter `assets/vfx/curse_spirit/rig/`,
die Gelenkdefinition unter `assets/data/curse_spirit_rig.json`. Der neue Zeichner
nutzt das bestehende `RigLibrary`/`RigRenderer`-System, keine Seelengeistbilder.

## Übernommene Nutzerwünsche

| Fähigkeit | Gewünschtes Verhalten | Vorschlag für die Darstellung |
| --- | --- | --- |
| Seuchenfeld | Vorhandene Giftpfütze. Sterben Gegner darin, entstehen eigene Skelettdiener, die Gegner verfolgen und Leichenexplosionen auslösen. | Echtes Giftmaterial; vorhandenes Skelett-/Körperteil-Rig für die Läufer und Explosionen aus dessen Teilen. |
| Fluch der Schwäche | Verfluchte Gegner sollen deutlich erkennbar sein. | Kleine Fluchgeister umkreisen den betroffenen Gegner; dessen Körper bleibt sichtbar. |
| Fluchgeschoss | Mehrteiliger, aufwendiger und flüssig animierter Fluchangriff. | Maskenfragment, Giftkern und violette Schweifbänder bewegen sich gegliedert; Treffer zerfällt in dieselben Materialien. |
| Blutstrahl | Verbindet sich mit mehreren Gegnern im Umkreis von fünf bis acht Metern und saugt Blut. Sterben verbundene Gegner, fliegen Flüche zu weiteren Gegnern. | Bestehende geriggte Blutketten zu mehreren Körper-Sockeln; beim Tod löst sich ein eigenständiger Fluchgeist zum nächsten Ziel. |

Grenzen der Umsetzung: höchstens sechs Skelettläufer pro Besitzer, acht Sekunden
Lebensdauer, Kontaktzündung nach 0,35 Sekunden und Explosion in zwei Metern.
Blutstrahl verbindet höchstens vier sichtbare Ziele in 3/4/5 Metern nach Rang.
Höchstens acht Todesflüche pro Besitzer; diese fliegen maximal 2,5 Sekunden.
Begleiter-/Sekundärtötungen erzeugen keine rekursive Armee oder Todesfluchkette.
Wände, gültige Ziele und Schaden bleiben hostautoritativ.

## Herkunft und Status

Ein Aufruf des eingebauten Bildgenerators über den Skill `imagegen`.
Referenzen der ursprünglichen Tafel: tatsächliches Spielbild `necro-rig-upgrade/curse-180.png` und
die vorhandenen Effekte `assets/sprites/fx/curse_skull.png` sowie
`assets/sprites/fx/poison_cloud.png`. Keine Internetbilder. Nach der Freigabe
wurde die vorhandene Tafel deterministisch ausgeschnitten; kein zweiter
Bildgenerierungsaufruf für diese Umsetzung.
Der vollständige Generierungsprompt liegt neben der Tafel.

Die ursprüngliche Konzeptphase enthielt keine Spieltests. Die anschließende
Implementierung besitzt tatsächliche Kampf-/Rigprüfungen und einen lokalen
Zweiprozess-Nachweis; siehe `production/qa/evidence/necromancer-catalog/README.md`.
Kein Commit, Push oder Merge.
