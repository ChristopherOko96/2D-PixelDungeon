# Größeres Seelenfeld mit echten Geistergriffen

31.10.2026. Nutzerwunsch: etwas größeres Feld, flüssiges Auflösen der Geister,
Geister greifen Gegner im Feld an, umschlingen und betäuben sie.

## Regeln und Darstellung

- `soul_11.radius_m`: **3 → 3,6 m**, also 20 % mehr Radius. 4 s Felddauer,
  30 Mana, 16 s Abklingzeit und 30/35/40 % Schaden alle 0,8 s bleiben.
- Normale Gegner werden beim Betreten und danach frühestens alle **1,6 s**
  von den Geistern gegriffen und **0,45 s** betäubt. Die Sperrzeit sitzt am
  Gegner und wird von allen überlappenden Feldern geteilt. Geisterangriffe
  verwenden den bestehenden Feldschaden; keine zusätzlichen rekursiven Treffer.
- `soul_bind` ist ein eigener Host-Status. Er stoppt Bewegung/Angriffe in der
  Krypta sowie über `m.stun` in Hölle/Frostgruft; dort endet auch die aktuelle
  Gegneraktion. Kein Froststatus, keine unbeabsichtigten Eis-Perk-Synergien.
  Bosse und Minibosse nehmen Feldschaden, sind aber gegen den Griff-Stun immun.
- Reichweite, lebende Ziele, Wandverdeckung, Sperrzeiten und Schaden werden
  hostseitig geprüft. Hinter Wänden oder außerhalb keine Wirkung. Abgelaufene
  Felder erzeugen keine neuen Treffer/Griffe. Maximal 16 aktive Griff-Ereignisse;
  diese folgen der tatsächlichen Zielposition und verschwinden bei Tod/Raumwechsel.
- Visuell bewegen sich zwei kleine Geister zur betroffenen Kreatur, ziehen
  Seelenbänder um sie und lösen sich am Ende weich auf. Die Geistergrafik stammt
  aus der bereits bestätigten Tafel. Kein neuer Imagegen-Aufruf.
- Die 24 großen aufsteigenden Geisterphasen werden zeitlich überblendet und
  in den letzten 0,5 s ausgeblendet. Zwischen Host-Snapshots wird nur die lokale
  Animationszeit kurz extrapoliert; Schaden/Stun bleiben unverändert hostgetaktet.
  Nearest-Texturfilterung bleibt; Alpha-Übergänge sind kein bilineares Filtern.
- Regelversion **8** verhindert Aufnahme alter Clients mit anderen Kontrollregeln.
  Neue Ereignisfelder: `soul_grasp`, `target_id`, `from_x/from_y`, `owner`,
  vorhandene Weltposition/Radius/Life/Span. Keine Texturen oder clientbestimmten
  Stuns über RPC.

## Prüfung

- `talent_combat_test`: **359/0**, davon neue Fälle für den vergrößerten Rand,
  sofortigen Griff zwischen Schadensticks, echten Schaden und Kontrollstatus,
  Ablauf, gemeinsame Sperrzeit, Boss-/Miniboss-Immunität, Zielverfolgung,
  tote/entfernte Ziele, Wandverdeckung, Ereignisbudget und Snapshot-Roundtrip.
- `soul_field_test`: **79/0**, einschließlich kontinuierlicher Zwischenbild-
  Gewichte und kombinierter Ausblendung. `soul_detail_test`: **91/0**.
- `hell_talents_test`: **22/0**, echte Hölle- und Frostgruft-Szenen; Kontrolle
  unterbricht die Gegneraktion und erzeugt keinen Eisstatus.
- `session_protocol_test`: **20/0**. Zusammen **571 Prüfungen**.
- Sichtbarer Godot-4.7.2-Compatibility-Fixture mit zwei echten Gegnern,
  manuellen Host-, KI-, Status- und Geschossschritten über die vollständige
  Laufzeit: `scripts/capture_mage_fireball.gd -- --soul --soul-bind`.
  96 GPU-Phasen plus Schlussbild; Animations-/Pfützenuhr im Fixture an den
  Simulationsschritt gebunden, damit PNG-Schreibzeit die Fläche nicht früh
  verschwinden lässt. Kein normal gespielter Lauf und kein Zwei-Prozess-/LAN-Test.

## Bei der Sichtprüfung gefundene Fehler

- Die alte Dither-Route erzeugte beim Überblenden kurzlebige Texturen für
  externe Sprite-Polygone; nach deren Freigabe erschien eine weiße Fläche.
  `before-white-polygon.png` hält den Fehler fest. Externe Frames verwenden
  jetzt echte Alpha-Überblendung ihrer persistenten Texturen. Der GPU-Fixture
  prüft auf großflächiges Weiß und hat alle 96 Phasen erfolgreich aufgenommen.
- Die neue Nekromanten-Prüfung der Story-Welten deckte einen älteren falschen
  Stabpfad in `sub_kit.gd` auf. Pfade mit Unterordner werden jetzt wie im
  Haupt-Loader aus `assets/sprites/` geladen; bestehendes `items/staff_necro`
  bleibt dieselbe Originalgrafik. Finaler Hölle/Frostgruft-Test ohne fehlende Datei.

Logs: `Logs/soul-bind-*.log`. Bekannte Einschränkungen der Game-Fixtures:
nicht beschreibbarer user://-Shadercache, beim Beenden 6 ObjectDB-Instanzen
und 2 Ressourcen. Keine SCRIPT ERROR in den finalen Läufen. Keine neue
LAN-/Last-/Kampagnen- oder subjektive Feel-Abnahme. Kein Commit/Push/Merge.
