# Magier / Feuerball – erster implementierter Schritt

31.10.2026. Bestätigte Vergleichstafel und Feuerball-Posen als Richtung;
Umsetzung auf der vorhandenen 0x72-Magierfigur, keine Aktivierung eines neuen
Figurenkatalogs und kein Imagegen-Aufruf in diesem Implementierungsschritt.

## Verhalten

- Nur das aktive Talent `fire_1` erhält 0,18 s Vorbereitung (`cast_time` in
  `assets/data/talents.json`). Bewegung bleibt möglich. Richtung beim Wirken
  festgelegt; Abschuss erfolgt einmalig vom aktuellen Standort aus.
- Mana und Abklingzeit beginnen beim angenommenen Wirken. 14 Mana, 4 s
  Abklingzeit, Ränge 125/145/165 %, Brennen und 50 % Flächenschaden in 1,5 m
  bleiben erhalten. Abgebrochene Vorbereitung erstattet keine Ressourcen.
- Tod und Raumwechsel verwerfen den vorbereiteten Feuerball. Magisches Echo
  wiederholt ihn 0,35 s nach dem eigentlichen Auslösen, einmalig; Tod und
  Raumwechsel verwerfen das noch nicht ausgelöste Feuerball-Echo.
- Die bestehende Stabdarstellung bekommt Ausholen, Glut, Auslösen und Rückkehr
  mit festem Griff und festgehaltener Blickrichtung. Kleine Körperverlagerung;
  kein neuer kompletter handgezeichneter Charakteratlas.
- Flugkern bleibt in vier nativen Effektbildern gleich groß, nur der Schweif
  wechselt. Vier Einschlagbilder: Aufblitzen, Explosion, Zerfall, Restglut.
  Effekte sind lokal erzeugte/cached Pixelgrafiken; Originaldateien bleiben.
  Vorhandenes Wand-Clipping gilt auch für diese Effekte.
- Krypta und gemeinsames Heldenmodul für Hölle/Frostgruft verwenden dieselbe
  Bewegung. Frost, Arkan, Grundangriff und sonstige Talente bleiben erhalten.
- Regelversion auf 7 angehoben; alte Clients werden vor Spielaufnahme
  abgewiesen. Vorhandene Talent-Ereignisse tragen zusätzlich die Vorbereitung.

## Prüfung und Wiederholung

- `tests/mage_fireball_test.gd`: 42 Prüfungen, 0 Fehler. Timing, einmalige
  Kosten/Auslösung, Abbruch, Echo, spätes Anzeigeereignis, feste Griffseite,
  identischer Flugkern. Der Test des Flugkerns scheiterte vor der Korrektur
  in drei Bildern, weil Schweifpixel in den Kern hineinragten; danach bestanden.
- `tests/talent_combat_test.gd`: 339 Prüfungen, 0 Fehler (echte vorhandene
  Kampfregeln inklusive Treffer/Brennen/Flächenwirkung).
- `tests/story_hero_test.gd`: 13/0; `tests/hell_talents_test.gd`: 14/0;
  `tests/session_protocol_test.gd`: 20/0.
- GPU: `scripts/capture_mage_fireball.gd`, Godot 4.7.2, Compatibility,
  sichtbares 1280×720-Fenster. `01-idle` bis `05-impact` zeigen eingerichtete
  Zustände des echten Spiels, keine regulär gespielte Kampagne. Der Capture
  verwendet einen kurzlebigen lokalen Host, keinen zweiten Netzwerkprozess.
- Logs unter `Logs/mage-fireball-*.log` (lokal). Keine SCRIPT ERROR bei den
  erfolgreichen Läufen. Der GPU-Lauf meldet fehlenden Zugriff auf den
  Shadercache unter user://; Darstellung funktioniert ohne diesen Cache.
  Die Game-Fixtures melden beim Beenden zudem 6 ObjectDB-Instanzen und
  2 noch verwendete Ressourcen. Diese Exit-Meldungen sind nicht als sauberer
  Ressourcen-/Soak-Test zu bewerten.

Wiederholen: vorhandene gepinnte Godot-EXE mit `--headless --path . --script
res://tests/mage_fireball_test.gd`, die übrigen Tests entsprechend. GPU-Capture
ohne `--headless`: `--path . --windowed --resolution 1280x720 --script
res://scripts/capture_mage_fireball.gd`. Bei eingeschränktem user:// ein
beschreibbares absolutes `--log-file` im Projekt angeben.

Keine neue LAN-, Mehrspielerlast-, Kampagnen- oder subjektive Stilabnahme.
Kein Commit, Push oder Merge. Nächster gestalterischer Schritt: Frostlanze.

## Ergänzung: Standardangriff / linke Maustaste

**Überholt durch die folgende Nutzerkorrektur:** Standardangriff soll kein
Feuerball sein. Aktuell wieder neutrales Magiegeschoss mit neutralem Stabstoß,
ohne Flammenflug oder Feuerball-Einschlag. Der Feuerball bleibt ausschließlich
Talent `fire_1`. Dies gilt in Krypta, Hölle und Frostgruft. Waffen-/Perkeffekte
bleiben erhalten; keine neuen Werte oder Manakosten. `attack_fx_test`: 23/0,
`mage_fireball_test`: 42/0. Die folgenden Absätze beschreiben den verworfenen
Zwischenstand; neu erzeugte Bilder 06–09 zeigen die korrigierte neutrale Magie.

Nachprüfung „überall“: Auch die alten Magier-Sonderfälle für Wandtreffer und
Flächentreffer in `feedback.gd` entfernt. Verwaiste Standard-Feuerball-
Hilfen und `pyro`-Schussdarstellung der Story-Welten entfernt; Pyro-Monster
aus dem Talentbaum bleibt erhalten. Gemeinsame Darstellung gilt auch für
andere Mitspieler. Neue Prüfung `mage_neutral_feedback_test`: 2/0 für Wand
und Flächentreffer; vorhandene `feedback_test`: 19/0. Beide Story-Szenen
werden zusätzlich mit dem echten Magier-Standardangriff und unverändertem
Mana geprüft (`hell_talents_test`, jetzt 18 Prüfungen).

Auf Nutzerwunsch nutzt jetzt auch der normale Magier-Angriff die neue
Feuerballgrafik, kleiner dargestellt, mit kurzem Stabstoß/Abschussblitz
und kleinem Pixeleinschlag. Kein zusätzlicher Windup, keine neuen Manakosten,
keine Änderung an Grundschaden, Angriffstempo oder Treffern. Gedrückte linke
Maustaste schießt weiter gemäß vorhandener Angriffsrate. Das Talent `fire_1`
bleibt separat mit seinen Kosten und seiner stärkeren Explosion.

Gemeinsame Integration über `talent_fx.draw_basic_fireball` (Krypta),
`attack_fx` und `story_hero` (Story-Welten). Andere Klassen behalten ihre
Darstellung. GPU-Fixture: Capture-Script zusätzlich mit `-- --basic` starten.
`06-basic-idle` bis `09-basic-impact` sind eingerichtete Zustände des echten
Standardangriffs, kein gespielter Lauf. Grafik geprüft, Mana bleibt 120/120.
`attack_fx_test`: 22/0, `mage_fireball_test`: 42/0, `story_hero_test`: 13/0.
Die oben genannten lokalen Cache-/Exit-Meldungen treten auch hier auf.
