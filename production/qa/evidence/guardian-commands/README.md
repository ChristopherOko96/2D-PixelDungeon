# Wächterbefehle und Untergebene — 01.11.2026

Implementierung auf `codex/port-0x72-onto-main`, auf Basis des zuvor geholten
`origin/main` b178a185. Kein Commit, Push oder Merge dieser Revision.

## Aufnahmen

`scripts/capture_guardian_commands.gd` öffnet den echten Spielrenderer mit einem
kontrollierten legalen Seele-Build, einer offenen Testbegegnung und normalen
R-/5-Eingaben. 181 GPU-Bilder bei 30 simulierten Bildern/s über sechs Sekunden.
Zwei schwache Gegner (0,8 HP) machen die tatsächliche Todesumwandlung sichtbar;
ein widerstandsfähiger Gegner bleibt als Angriffsziel. Kein erspielter Lauf.
Der Start mit 50 Seelen genügt; kein Ressourcen-Refill.

Standbilder `guardian-000.png` bis `guardian-180.png`. Vollständige Rohbilder:
`output/guardian-commands/game-frames/`. Der dortige `game-preview.gif` ist ein
600×440-Ausschnitt aus diesen Bildern, keine Konzeptanimation. Alle 181
GIF-Bilder wurden wieder dekodiert. Aufnahme manuell visuell geprüft: Rig-Hand,
Strahlbogen, Todesrigs, mintfarbene Untergebene und separate Begleiterleiste.

Reproduktion der Aufnahme:

```powershell
./scripts/Dev.ps1 Doctor
# Lokalen, dort gefundenen Godot-4.7.2-Pfad verwenden:
& $GodotPath --path . --max-fps 120 --script scripts/capture_guardian_commands.gd
powershell.exe -NoProfile -ExecutionPolicy Bypass -File output/guardian-commands/assemble_game_preview.ps1
```

## Logik und Integration

`tests/soul_guardian_commands_test.gd`: 26/0. Tödlicher Treffer markiert rechtzeitig,
einmalige Umwandlung, echter Untergebenenangriff, unabhängige 15-s-Lebensdauer,
Markenablauf, Populationsgrenze, Boss-/Beschwörungsschutz, Raumwechsel,
5/6-Eingaben, Aufladezeit, feste Richtung, Breite, Wände, Cooldown und HUD.
Zusätzlich unveränderte Begleiter-Auto-Einstellungen und Wiederherstellung der
normalen Knochenbegleiterleiste nach legalem Wechsel zum Diener-Zweig. Der
aktuelle Talentbaum gestattet keinen gleichzeitig erlernten Seele-/Diener-Mischbuild.

`tests/soul_beam_visual_test.gd`: 1522/0 Prüfungen über die kontinuierlichen
Neunteile-Posen, endliche Transformationen, tatsächlichen Handanschluss,
gebundene Endposition und glatte Strahlkurve; maximaler Positionsschritt
3,871 Weltpixel bei 60 Hz in diesem Aufbau.

Weitere fokussierte Regressionen: Wächter 51/0, Wächterrig 58/0,
Talentkampf 362/0, Seelen/Aggro 60/0, Seelenring 19/0, Protokoll 20/0,
Interpolation 57/0 und dauerhafte Begleiter 39/0.
Der Begleiter-Test erwartete noch acht Slots in der alten Hauptleiste und
brach beim Zugriff auf Slot 6 ab. Er prüft jetzt die bereits auf main vorhandene
separate Begleiterleiste; keine Rücknahme der aktuellen UI.

## Zwei echte Prozesse

`tests/guardian_commands_network_smoke.ps1` bestand mit Host und Client über
lokales ENet. Befehle gehen über die normale validierte Eingabestrecke.
Beide Prozesse sahen zwei Besitzer, Strahl, Welle, Seelenmale, Untergebene,
Begleiter-HUD, Lebensdauerende und fortgesetzten Kampf nach Weglaufen des Helden.
Ergebnis: `Logs/guardian-commands/20261101-122230-ec491e93/summary.json`.
Regeln 13, Protokoll 4. Dies ist Loopback, kein LAN-/WAN-/Vier-Spieler- oder
Leistungsnachweis.

Die Spiel-Testaufbauten melden beim Schließen weiterhin die vorhandenen sechs
ObjectDB-/zwei Ressourcen-Diagnosen. Im Sandbox-GPU-Lauf ist der Benutzer-
Shadercache nicht beschreibbar. Keine neuen Skriptfehler im erfolgreichen Lauf.
Frühere abgebrochene Aufnahmeaufbauten (falsche Freischaltreihe, Gegner hinter
der schmalen Kampagnenwand, anschließend zu hohe Gegner-HP) wurden korrigiert;
die fertigen Aufnahmen stammen aus dem oben beschriebenen offenen Aufbau.
