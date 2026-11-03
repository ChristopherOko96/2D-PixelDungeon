# Nekromant: Ruf des Seelenwächters

31.10.2026. Nutzer hat den konkreten Entwurf gutgeheißen und Animationen sowie
Spielintegration angefordert. Er ersetzt die bisherige Seele-Ultimate
Seelenernte (`soul_14`). Derselbe gemeinsame Talentcode gilt in Krypta, Hölle
und Frostgruft. Knochenkoloss im Diener-Zweig bleibt unverändert.

## Neue Befehle und Seelenmal — 01.11.2026

Vom Nutzer bestätigte Belegung: **5 Seelenstrahl, 6 Seelenwelle**. Nach R
übernimmt der Wächter die Begleiterleiste. Nach seinem Ende kehrt die Leiste
eines vorhandenen dauerhaften Begleiters mit dessen eigenen Auto-Einstellungen
zurück. Rechtsklick auf ein Symbol schaltet nur die angezeigte Fähigkeit um.
Der Strahl beginnt manuell; die bisherige automatische Welle bleibt aktiv.

Alle Wächtertreffer setzen vor der Schadensauflösung ein **8 s Seelenmal**.
Stirbt ein markierter normaler Gegner, entsteht am Todesort ein freundlicher
Untergebener für **bis zu 15 s**, auch wenn ein anderer Spieler ihn tötet.
Er behält sein bekanntes Gegnerrig und erhält einen mintfarbenen Schein samt
Bodenring. Bogenschützen bleiben Fernkämpfer. Unbekannte Rigs verwenden das
Skelettrig. Eigene Gefallene gewähren keine weiteren Tötungsbelohnungen und
setzen selbst keine Seelenmale. Das verhindert endlose Beschwörungsketten.

Grenzen für den ersten Balance-Stand: vier lebende Untergebene je Spieler,
zwölf insgesamt. Bosse, Minibosse und feindliche Beschwörungen sind ausgenommen.
Die Untergebenen haben eigene, begrenzte Begleiterwerte (Basis 8 HP,
40 % Spielerschaden vor bestehenden Begleiterboni, 1,4 s Angriffstakt), keine
kopierten Bosswerte. Sie können sterben; Raumwechsel und Tod ihres Besitzers
beenden sie. Sie belegen keine lebenden Gegnerplätze und halten Räume nicht offen.

Der Strahl lädt 0,45 s auf, kanalisiert 1,6 s, schwingt 0,25 s aus und hat
8 s Abklingzeit. Reichweite 8 m, Breite 0,7 m; alle 0,2 s 20 % Wächter-Schaden.
Zielrichtung wird beim Auslösen fixiert. Wände begrenzen den Strahl und seine
Treffer ausschließlich auf dem Host. Er durchdringt sichtbare Gegner.
Die Welle behält ihre bisherigen Treffer-, Stufen- und Festhalteregeln.
Beide Befehle verbrauchen keine zusätzlichen Seelen; R kostet weiterhin 40.

Arme, Hände, Kopf und Körper erhalten eine eigene Kanalpose im vorhandenen
Neunteile-Rig. Der Strahl beginnt an der tatsächlich berechneten Hand und
verwendet bewegte Seelenbänder, Lichtknoten, Aufladung und Auslauf. Aura und
Partikelschweif bleiben erhalten. Keine neue Bildgenerierung oder Actor-Katalogänderung.
Snapshots enthalten nur Anzeigezustand; Kompatibilitätsregeln sind jetzt 13/4
(Regeln/Protokoll).

**Testen:** Testraum → Klasse Nekromant → Spezialisierung Seele anwenden.
Gegner holen, mit R beschwören (40 Seelen), auf Gegner zielen und 5 drücken.
6 löst seine Seelenwelle aus. Markierte Gegner töten; ihre mintfarbenen
Untergebenen kämpfen anschließend mit. Der normale Talentbaum führt die
Beschwörung weiterhin unter Seele → Ruf des Seelenwächters (`soul_14`).
Aktuelle Messungen und Spielaufnahme: [Befehlsnachweis](../production/qa/evidence/guardian-commands/README.md).

## Regeln und Abstimmung

| Wert | Grundform | Zweck |
|---|---|---|
| Kosten / Abklingzeit | 40 Seelen / 60 s | Eigene Nekromanten-Ressource |
| Gesamtdauer | 12 s | Kurze Beschwörung mit mehreren lesbaren Angriffen |
| Erscheinen / Auflösen | 0,64 s / 0,8 s | Währenddessen kein Schaden |
| Greifen | 100 % Basisschaden alle frühestens 1,6 s, 1,7 m | Naher Einzelzielangriff |
| Ausholen / gesamter Angriff | 0,32 s / 0,64 s | Treffen passt zum ausgestreckten Arm |
| Seelenwelle | Bei bereitstehendem Angriff nach 4,8 s statt Greifen | 60 % in 1,2-rad-Kegel bis 4 m |
| Festhalten | 0,45 s, gemeinsame 1,6-s-Sperre mit dem Feld | Keine gestapelten Dauerbetäubungen |
| Bewegung / Körperradius | 175 px/s / 12 px | Schneller Begleiter mit echter Wandkollision |
| Suchbereich | 10 m um den Begleiter zum Erfassen neuer Ziele | Kein Rückruf eines lebenden Kampfziels durch Besitzerentfernung |
| Stufe 2 / Stufe 3 | 16 s / Welle 100 % bis 5 m | Längere Präsenz, stärkere Gruppenwirkung |

Werte sind ein erster spielbarer Abstimmungsstand. Vorhandene Seele-Passive und
Seelensplitter-Schadensboni gelten über die bisherigen Talent-Schadenswege.
Die frühere sofortige Hinrichtung, Heilung/Mana pro Treffer und Nachlade-Welle
von Seelenernte entfallen. Stabile ID erhält die Freischaltung gespeicherter Builds.
Das Seelenfeld wurde in diesem Schritt nicht verlängert; seine 4 s bleiben.

Priorität: nahes sichtbares befohlenes Ziel, vorhandenes lebendes Kampfziel,
danach neue Gegner im eigenen Seelenfeld oder das nächste sichtbare Ziel.
Neue Ziele werden um den Begleiter erfasst. Ein bestehender Kampf wird durch
Weglaufen des Besitzers nicht abgebrochen. Nach dem Tod des Ziels kämpft er
gegen lokale Überlebende weiter; erst danach folgt er dem Nekromanten.
Die bestehende Beschwörungsdauer von 12/16 s begrenzt den Geist weiterhin.
Der Krypta-Pfadfinder führt ihn um Ecken, Storywelten verwenden deren bestehende
Kollision. Keine Treffer durch Wände, hinter dem Kegel oder nach Beginn des
Auflösens. Tote/getrennte Besitzer, Zweigwechsel, Raumwechsel und Neustart
entfernen ihn. Höchstens ein Wächter pro Besitzer, also vier insgesamt.
Er hat als Geist keine Lebenspunkte; seine Dauer begrenzt ihn.

## Code, Daten und Animation

- `assets/data/talents.json`, `soul_14.type=soul_guardian`. Neue numerische Felder:
  `time`, `spawn_time`, `hover_time`, `attack_time`, `hit_time`, `dissolve_time`,
  `every`, `reach_m`, `grasp_arc`, `wave_every`, `wave_range_m`, `wave_arc`,
  `wave_damage`, `wave_visual_time`, `bind_stun`, `bind_cooldown`,
  `bind_visual_time`, `bind_visual_cap`, `body_radius`, `spawn_offset`, `speed`,
  `follow_offset`, `follow_y`, `follow_stop`, `acquire_range_m`, `route_every`,
  `route_retarget`, `route_near`. Sekunden, px bzw. Meter, Winkel in rad;
  `dmg` und `wave_damage` sind Schadensmultiplikatoren. `stages.add` nutzt die
  vorhandene Stufenauswertung. 1 m = `meter_px` = 32 px.
- `src/combat/soul_guardian.gd`: Host-Zustand und Treffer. `talent_combat.gd`
  bindet Lebenszyklus/Schaden/Status ein. Gemeinsame Sperre in `soul_grasp_wait`.
- Snapshot `talents.guardians`: `id`, `owner`, `x/y`, `face`, `radius`, `motion`,
  `age`, `duration`, `phase_seq`, `left`, `total`. Nur Darstellung; keine Texturen,
  Pfade oder änderbaren Kampfwerte. Regelversion 10, Protokollschema weiterhin 4.
- `snapshot_interpolator.gd` glättet ausschließlich Positionen mit Wandprüfung;
  Entfernung und Angriffsphase bleiben aktuell. VFX überbrücken höchstens 0,1 s
  bis zum nächsten Snapshot; keine lokale Schadenssimulation.
- `src/vfx/soul_guardian_art.gd` zeichnet seit der Rig-Revision echte Körperteile.
  `src/rig/soul_guardian_rig.gd` verwendet **RigLibrary und den Gelenklöser von
  RigRenderer**, genau wie die Skelette. Neun ausgeschnittene Ebenen: Kopf,
  Rumpf, zwei Arme, zwei Hände und drei gekoppelte Schweifsegmente. Hände folgen
  den Armen, Kopf und Schweif dem Rumpf. Kleine Gelenküberlappungen aus denselben
  Originalpixeln verhindern offene Schnittkanten. Schweben und zeitversetztes
  Nachschwingen laufen kontinuierlich über die Lebenszeit, auch beim Wechsel
  einer Host-Angriffsphase. Greifen holt aus, streckt bei 0,32 s die rechte Hand
  aus und führt sie zurück. Erscheinen/Auflösen verwenden dasselbe Rig.
  Keine Ganzkörper-Überblendung mehr im Live-Renderer. Originalatlas mit
  32 Timeline-Keys/31 sichtbaren Posen bleibt erhalten. Links wird gespiegelt;
  harte Pixel, 18 Farben und Staubaura bleiben. Texturen einmal cachen.
- Originalquelle, exakter Imagegen-Prompt und Importdetails:
  `assets/vfx/soul_guardian/PROVENANCE.md`. Rebuild:
  `--headless --path . --script scripts/import_soul_guardian.gd`, danach Import.
  Rig danach separat erzeugen:
  `--headless --path . --script scripts/import_soul_guardian_rig.gd`, danach Import.

### Rig-Datenformat

`assets/data/soul_guardian_rig.json`, `schema_version=1`, verwendet das bestehende
Layer-Schema von RigLibrary: `rigs.soul_guardian.size` (128×80 Quellpixel),
`ground` (48,64), `scale` (1 entspricht 2×, Storywelten zeichnen 3×), `parts`.
Pro Teil: `id`, `parent`, `pivot` in gemeinsamen Quellpixel-Koordinaten, `z` für
Zeichenreihenfolge und `img` für die vollständige transparente Ebene. Zusätzliche
Importfelder: `cut_rects` sind inklusive Rechtecke `[x0,y0,x1,y1]` mit erster
passender Zuweisung, `joint_radius=3` kopiert einen kleinen Kreis unveränderter
Bindepixel in Kind und Elternteil. Der Rumpf fängt die übrigen Pixel auf.
Bindepose ist Hover-Key 0 des erhaltenen Atlas; nur abgetrennte Partikel werden
entfernt, da die eigene Staubaura sie unabhängig vom Körper bewegt.

Der neue öffentliche `RigRenderer.solve_pose()` nutzt denselben hierarchischen
Löser wie Skelette. Er lässt beim schwebenden Effekt die Ganzpixel-Rundung der
Position weg; bisherige Akteure verwenden weiter den unveränderten Standard.
`FxSprites.draw_external_rig()` begrenzt die zusammengesetzten, gedrehten und
gespiegelten Teile an einer gemeinsamen Sichtgrenze vom Bodenanker. Keine
Texturerzeugung pro Bild, keine Rig-Daten oder zusätzlichen Zustände im Netzwerk.

## Selbst testen

Seit 31.10.2026 kosten alle Nekromantenfähigkeiten Seelen. Startkapazität,
Kill-Einkommen, Seelensog, langsamere Geister und Staubaura sind in
[Seelenökonomie und Begleiter](NEKROMANT-SEELEN-BEGLEITER.de.md) beschrieben.

Schnell im vorhandenen **Testraum**: mit **F1** die rechte Leiste einblenden,
**Klasse → Nekromant**, **Spezialisierung → Seele**, **Ultimate → Stufe 1**.
Ein normales Skelett über **HOLEN** setzen. **R** beschwört den Seelenwächter,
**4** legt das Seelenfeld. Als Elementwerkzeug **KEIN WERKZEUG** wählen, wenn
Linksklick wieder normal angreifen soll. Der Testraum verwendet jetzt ein
gültiges Level-30-Preset; zuvor filterte die normale Buildprüfung die Ultimate
aus dem überfüllten Alle-Ränge-Preset heraus. Keine Aufweichung der Hostprüfung.

Über das normale Talentmenü:

1. Hauptmenü **TALENT-TEST** einschalten, falls dein normales Profil die Ultimate
   noch nicht freigeschaltet hat. Das getrennte Testprofil hält Level 30 und
   Seelensplitter bereit; dein normales Profil bleibt getrennt.
2. Im Talentmenü **Nekromant → Seele** wählen. Falls dort ein anderer Zweig
   gelernt ist, im Testprofil zurücksetzen. 20 Punkte in unteren Reihen öffnen
   Reihe VIII; dort **Ruf des Seelenwächters** freischalten.
3. Mit Nekromant einen Lauf/Testkampf starten. **R** beschwört den Geist;
   mindestens 40 Seelen. Danach 60 s Abklingzeit. Nicht auf einer Taste 1–4 suchen.
4. Mit Standardangriff ein anderes Ziel treffen: der Wächter wechselt darauf.
   **Seelensturm** auf einen normalen Gegner legen: kleine Feldgeister und
   Wächter teilen sich die kurze Betäubungssperre. Bosse bleiben beweglich.
5. Nach 12 s zerfällt er; Stufe 2 verlängert auf 16 s. Raumwechsel beendet ihn.

## Tatsächlich geprüfter Umfang

Siehe `production/qa/evidence/necromancer-soul-guardian/README.md`: fokussierte
Kampf-, Asset-, Storywelt- und Interpolationsprüfungen, GPU-Sequenz im echten
Spielrenderer und zwei echte lokale ENet-Prozesse mit normalen R-Befehlen.
Die Begegnungen/Builds sind Testaufbau, kein erspielter Lauf. Kein neuer
Vier-Spieler-, LAN-, WAN- oder Leistungstest; persönliches Spielgefühl und
langfristige Balance bleiben vom Nutzer zu beurteilen.

Rig-Revision: `production/qa/evidence/soul-guardian-rig/README.md` enthält aktuelle
Prüfergebnisse und echte GPU-Aufnahmen. Die 30-FPS-Vorschau zeigt einen
kontrollierten Kampf im Spielrenderer, keinen erspielten Lauf.

Nachfolgende Feld-/Schweifrevision: [Seelenpartikel](NEKROMANT-SEELENPARTIKEL.de.md).
Der große Geist besitzt jetzt einen in Quellpixelpartikel auslaufenden Schweif;
auch die kleinen Feld- und Festhalte-Geister nutzen eigene Cutout-Rigs.

## Haftender Rig-Seelenstrahl — 01.11.2026

**R** ruft den Wächter, **5** löst seinen Seelenstrahl aus, **6** bleibt die
Seelenwelle. Der Strahl bindet den ersten sichtbaren Gegner auf seiner
Schusslinie bis acht Meter und behält dessen stabile Gegnerkennung.
Er folgt dessen Bewegung während Vorbereitung und Kanal; die Maus steuert
eine bestehende Verbindung nicht um. Gegner auf der Verbindung können
weiter getroffen werden. Der sichtbare Strahl endet am gebundenen Ziel.
Tod, neue Wand oder Überschreiten der acht Meter beenden diese Verbindung;
derselbe Kanal springt danach nicht auf einen anderen Gegner um. Ohne
anfängliches Ziel kann der freie Strahl weiterhin einen eintretenden Gegner
erfassen. Vorbereitung, Schadentakt, Seelenmale, 8-s-Abklingzeit und die
bezahlte Wächterbeschwörung bleiben unverändert.

`src/rig/soul_beam_rig.gd` baut zwei echte Elternketten mit je 24 Gelenken.
Sie verwenden vorhandene Schwanzteile des freigegebenen Wächter-Rigs und
werden mit `RigRenderer.solve_pose` gelöst. Die sichtbaren Enden sitzen auf
der gelösten Hand und dem aktuellen Körper-Rig des Gegners, auch auf Clients.
Innere Gelenke schwingen langsam; separat geriggte Seelengeister fließen
entlang der Verbindung und umschlingen das Ziel. Texturen werden einmalig
vorbereitet; keine zusätzlichen Atlasframes oder neuen Kunstquellen.

`assets/data/soul_beam_rig.json` Schema 1 enthält nur Darstellungswerte:
`segments` je Kette, `source_parts` bestehende Wächterteile, `width_px` und
`amplitude_px` in nativen Pixeln, `core_width` als Verhältnis, `wave_rate`
und `impact_orbit_rate` in Radiant/s, `travel_rate` in Umläufen/s sowie die
begrenzte Zahl `travelers`. Schadenswerte bleiben in `talents.json`.
Snapshotfelder `beam_target_id`, `beam_tx/ty`, `beam_attached` sind primitive
Hostdaten; Rigdefinitionen/Texturen werden nicht übertragen. Regelsatz **21**,
Protokoll weiterhin **4**.

Nachweise und scharfe Aufnahme am bewegten Ziel:
`production/qa/evidence/guardian-beam-adhesion/README.md`.
