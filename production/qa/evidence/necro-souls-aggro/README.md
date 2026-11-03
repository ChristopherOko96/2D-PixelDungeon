# Seelenressource, Begleiter-Aggro, langsamere Geister und Staubaura

31.10.2026. Expliziter Nutzerauftrag. Implementiert auf
`codex/port-0x72-onto-main`, keine Commits/Pushes/Merges.

## Umsetzung und Grenzen

- Talent-Begleiter aller Klassen, Seelenwaechter, Story-/Relikt-Begleiter
  erfassen Gegner um sich herum, behalten ein lebendes Kampfziel unabhaengig
  von der Besitzerentfernung und kaempfen auf lokale Ueberlebende weiter.
  Begrenzte Beschwoerungszeiten bleiben. Neue Zielsuche und native Routen
  gemeinsam in `src/combat/companion_targets.gd`.
- Keine Treffer durch Waende, auch nicht durch Begleiter-Spezialfaehigkeiten.
  Ein Fernkaempfer bewegt sich bei verdeckter Sicht trotz ausreichender
  Waffenreichweite weiter. Natives Routing gecacht, Story-Kollision bleibt.
- Nekromant: 100 Basis-Seelen, Start 50, Seelensog 2/s im Kampf, ausserhalb
  1/s bis 40 Reserve. Eigene/Begleiter-Kills 8, Mini-/Boss 20/30, nahe eigene
  Mitspieler-Kills halber Grundwert. Tote/beschworene Gegner erzeugen keine
  wiederholt farmbaren Ertraege. Mana-Items fuellen keine Seelen.
- Alle Nekromanten-Kosten neu abgestimmt (8..40), Texte/HUD in allen Welten
  zeigen Seelen. Angeborene Passive sichtbar und ueber der Ressourcenleiste
  erklaert. Seelensplitter bleiben getrennte dauerhafte Freischaltungen.
- Griff-Geister 0,55 statt 1,6 Drehungen ueber 1,2 statt 0,8 s; Stun bleibt
  0,45 s, Sperre 1,6 s. Feldtempo 70 %, Waechter-Hover 1,6 s statt 0,96 s.
  24 stetig bewegte, weiche Staubpartikel, die beim Angreifen nicht neu starten.
  Keine neue Bildgenerierung oder Texturfilterung, vorhandene Art unveraendert.

Regeln/Daten/Quellen/Testanleitung:
`docs/NEKROMANT-SEELEN-BEGLEITER.de.md`.

## Fokussierte automatische Nachweise

| Suite | Checks | Fehler |
|---|---:|---:|
| necro_souls_aggro_test | 60 | 0 |
| soul_motion_test | 54 | 0 |
| talent_mana_test | 18 | 0 |
| talent_pet_test | 39 | 0 |
| hell_talents_test | 36 | 0 |
| talent_combat_test | 361 | 0 |
| soul_guardian_test | 51 | 0 |
| soul_guardian_art_test | 93 | 0 |
| soul_field_test | 79 | 0 |
| soul_detail_test | 91 | 0 |
| snapshot_interpolation_test | 57 | 0 |
| session_protocol_test | 20 | 0 |
| Gesamt | 959 | 0 |

Ausgaben unter `logs/`, Aufruf `--headless --path . --script tests/<suite>.gd`.
Neue Tests pruefen Start/Reserve, Boss ohne Adds, echte Host-Kills, genau
einmalige Zahlung, Beschwoerungs-/Leichen-Farming, Boss/Miniboss, Gruppenanteil,
Kapazitaet und Umskillen. Ein echter Knochenkrieger toetet im Host-Kampfcode
und fuellt seinen Besitzer. Jeder der acht Pet-Arttypen sowie Guardian und
Legacy-Story-Ziele werden auf autonome Zielsuche/Beibehaltung geprueft.

Regressionsfehler vor der Korrektur beobachtet und erhalten:
- `before.log`: bisherige Mana-/Besitzer-Aggro-Annahmen, 36 Checks / 20 Fehler.
  Der erste Entwurf der Fixture nutzte eine ungueltige leere Talent-ID; diese
  wurde vor der behaltenen roten Probe durch frost_3 ersetzt.
- `wall-before.log`: Begleiter-Lanze konnte das gehaltene Ziel durch eine Wand
  treffen, 57/1; danach 57/0.
- `route-before-valid-layout.log`: Fernkampf-Begleiter blieb in Waffenreichweite
  hinter Deckung stehen, 60/1; nach Korrektur 60/0. Die erste Deckungsfixture
  hatte das fuer Navigation erforderliche tile_size nicht gesetzt. Diese wurde
  korrigiert und die alte Abstandsbedingung nochmals absichtlich eingesetzt:
  auch mit gueltiger Navigation beobachtet rot, danach die Korrektur restauriert.
- Der bestehende Falken-Reichweitentest platzierte sein Ziel im Void der
  schmalen Kampagnenfixture. Er verwendet jetzt explizit offenen Boden fuer
  die Reichweitenpruefung; die neue Wandprobe erzwingt separat echte Kollision.
- Mana-Drop-Fixtures melden bereits gefallene Minimalgegner ohne hp-Feld;
  diese bleiben als Mana-Drop-Ereignisse unterstuetzt. Seelenzahlung verlangt
  dagegen ein tatsaechliches hp-Feld und einen bestaetigten Tod.

## Echte lokale Host-/Client-Probe

`./tests/soul_guardian_network_smoke.ps1`, Regelversion 10, Protokoll 4.
Erfolgreich: `Logs/soul-guardian/20261031-191600-9bbad62b/summary.json`, Kopien
unter `network/`. Zwei echte ENet-Prozesse, normale zugelassene R-Inputs:
beide empfangen Seelenressource, zwei Waechter, alle Animationen, Hostschaden,
Wellen und Ablauf. Besitzer werden im kontrollierten Host-Aufbau ueber ihre
alte Leash hinaus versetzt; beide Prozesse sehen die Waechter weiterkaempfen.
`retained=true`, `souls=true` auf beiden. Kein erspielter Lauf, kein LAN/WAN.
Spaetere Deckungsbewegung betrifft normale Pets und ist im 60-Check-Test
abgedeckt; keine Aenderung des Netzwerktransports.

## GPU und Ressourcenmodell

`scripts/capture_necro_souls.gd`: echte 1280x720-Game-Renderer-Sequenz, normale
Gegner-KI, kontrollierter legaler Build und explizit voller Demo-Vorrat.
Letzteres ist keine Behauptung erspielter Seelen; 50 Startseelen und Einkommen
werden separat im echten Host-Regeltest geprueft. Der Spieler bewegt sich
waehrend des Kampfes. Ausgewaehlte Rohbilder hier; alle 153 Frames unter
`output/necro-souls-aggro/game-frames/`. `testraum-seele.png` ist die echte
Testraum-UI mit Seelen/Seelensog sowie beschworenem Geist/Feld. PNGs angesehen.

Animierter 480x480-Ausschnitt derselben GPU-Frames:
`output/necro-souls-aggro/game-preview.gif`, alle 153 Frames vollstaendig
dekodiert (ca. 12,7 s). Nur Zuschnitt/Formatkonvertierung der Spielaufnahme.

`scripts/analyze_necro_souls.ps1` produziert `resource-model.json`:
konservativer Basis-Bosszeitplan ohne Kills, 60 s, 1 Ultimate + 3 Felder +
6 Blitze, 10 Seelen Rest, keine Kosten-/Cooldownverletzung. Ressourcen-
arithmetik, kein Bosskill-/DPS-/TTK-Beleg. Unabhaengige numerische Zielbereiche,
System-GDD und Langzeit-Spieltelemetrie fehlen: langfristige Balance
**NOT ASSESSED — NO DATA**, erster Abstimmungsstand statt allgemeinem Guetesiegel.

Bekannte schon vorher vorhandene Game-Fixture-Exitdiagnostik: sechs ObjectDB-
Instanzen/zwei Ressourcen; Sandbox-Log-/Shadercache-Schreibrechte. Ein relativer
--log-file-Versuch produzierte zusaetzlich user://E:-Pfaddiagnostik; spaetere
Proben nutzen die vorhandene Standardausgabe. Finale Checks ohne SCRIPT ERROR.

Keine neue Vier-Spieler-, LAN/WAN-, Vollrun- oder Leistungsabnahme. FPS in der
angehaltenen Capture-UI ist kein Performancewert. Persoenliches Feedback und
laengere echte Runs werden fuer weiteres Balancing gebraucht.
