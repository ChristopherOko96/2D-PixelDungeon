# Nekromant: bewegte Rig-Zauber und Klingensturm

01.11.2026, `codex/port-0x72-onto-main`, Godot 4.7.2 Compatibility.
Umgesetzt auf ausdrücklichen Nutzerwunsch mit dem vorhandenen Rig-System und
vorhandenen Spritepixeln. Keine Bildgenerierung, keine Aktivierung eines neuen
Actor-Katalogs. Vorhandene Originalbilder und Lizenzen bleiben erhalten.

## Tatsächliche Spielaufnahmen

- `minion-animation.gif`: 451 GPU-Frames, 30 FPS, etwa 15 Sekunden. Vier echte
  Blutquellen füllen die normale Blutleiste und lösen die gegliederte große
  Skelettform aus. Enthält Totenpakt, Skelettwache, Stampfen auf 5 und den
  anhaltenden Klingensturm auf 6 mit getrennt bewegten Waffenteilen.
- `curse-animation.gif`: 451 GPU-Frames, 30 FPS, etwa 15 Sekunden. Enthält
  Fluchgeschoss, Zielmarke, Blutstrahl, Seuchenfeld, Aderfessel, Fluchernte und
  Seuchengrube. Das verbundene Ziel bewegt sich während des Blutstrahls; die
  Aufnahme prüft dessen konkrete Gegnerkennung.
- Beide GIFs sind 640×360-Ausschnitte des tatsächlichen 1280×720-Game-Viewports.
  Alle 451 Frames je GIF wurden nach dem Encodieren wieder decodiert. Rohe
  PNG-Folgen bleiben unter `minion-frames/` und `curse-frames/`; ausgewählte
  vollständige Viewports liegen als `minion-*.png` und `curse-*.png` daneben.
- Visuell geprüft: große Form und Sturm (`minion-330.png`), Stabspitze und
  verschiedene Positionen des verbundenen Gegners (`curse-120.png`,
  `curse-180.png`), vorhandenes Giftmaterial und Ritual.
- Aufnahme: `scripts/capture_necro_rigs.gd`, Log `Logs/necro-rigs-gpu.log`.
  Zusammenbau: `output/necro-rigs/assemble.ps1`, Windows PowerShell 5.

Die Aufnahmen verwenden kontrollierte Präsentationsbedingungen: gültiger
Level-30-Build, definierte Geometrie, Gegner mit 500 Leben, anfängliche Seelen
und Debug-Schutz. Alle dargestellten Fähigkeiten durchlaufen die tatsächliche
Kosten-/Abklingzeitprüfung. Das ist keine erspielte Kampagne, Abnahme des
Geschmacks, LAN/WAN-Prüfung oder Leistungs-/Lastmessung.

## Fokussierte Prüfungen

| Test | Ergebnis | Log |
| --- | --- | --- |
| `necro_rig_link_test.gd` | 19 / 0 | `Logs/necro-rig-link-final.log` |
| `necro_spell_rig_test.gd` | 43 / 0 | `Logs/necro-spell-rig.log` |
| `companion_actor_namespace_test.gd` | beide Bedingungen wahr | `Logs/necro-namespace-green.log` |
| `necro_blood_curse_test.gd` | 38 / 0 | `Logs/necro-rigs-regression.log` |
| `necro_branches_story_test.gd` | 28 / 0 | `Logs/necro-rigs-story.log` |
| `talent_combat_test.gd` | 358 / 0 | `Logs/necro-rigs-catalog.log` |
| `necro_soul_attacks_test.gd` | 45 / 0 | `Logs/necro-rigs-soul-regression.log` |
| `soul_guardian_commands_test.gd` | 26 / 0 | `Logs/necro-rigs-guardian-regression.log` |
| `hell_rig_renderer_test.gd` | 73 / 0 | `Logs/necro-rigs-renderer-regression.log` |
| `session_protocol_test.gd` | 20 / 0 | `Logs/necro-rigs-protocol-regression.log` |

Die Rigprüfung prüft vollständige, exklusive Zuordnung der undurchsichtigen
Quellpixel zu Körperteilen, echte bewegte Gelenktransformationen, alle 14
aktiven Zauberbindungen und beide Enden der gelösten 16-Gelenk-Kette bei
mehreren bewegten Positionen. Keine Löcher oder doppelt zugeordneten Pixel.

Die Integrationsprüfung prüft bewegten Helden und Gegner, unveränderte
Zielidentität, Wände, Ziel-Tod, Reichweitenabbruch, Raumwechsel, Schaden nur am
verbundenen Ziel, vorbereiteten/anhaltenden Sturm mit Ende und Replikationsphase
sowie einen echten Geschosstreffer vor einer weiter entfernten Wand. Der
Story-Test prüft zusätzlich den tatsächlichen Hölle-/Frost-Adapter und die
DEBUG-Testraum-Belegung.

Vor der Korrektur beobachtete Fehler:

- `Logs/necro-rig-link-red.log`: fehlende Zielverbindung und Sturmmechanik.
- `Logs/necro-namespace-red.log`: Begleiter 1 überschrieb die Animationspose
  von Spieler 1. Getrennte Animationskennungen (`pet:1` / `p1`) beheben dies,
  ohne autoritative Akteurskennungen zu verändern.

Alle erfolgreichen Logs wurden auf `SCRIPT ERROR` und fehlgeschlagene
Assertions geprüft. Die bestehenden Game-Fixtures melden beim Beenden
weiterhin 6 ObjectDB-Instanzen / 2 verwendete Ressourcen. Sauberer Teardown
wird damit nicht behauptet.

## Zwei echte Prozesse

`tests/necro_blood_network_smoke.ps1` startet Host und Client als separate
lokale ENet-Prozesse. Beide bestanden:
`Logs/necro-blood/20261101-183005-f6541ba2/summary.json`.
Beide sahen Teilblut, große Form, Befehl 5, echtes Gift, den Klingensturm und
den bewegten Gegner der Blutverbindung. Clientaktionen wurden über normale
validierte Eingaben ausgelöst. Regelsatz 17, Protokoll 4. Dies ist Loopback
auf einem PC, keine Zwei-Rechner-LAN-Prüfung.

## Umsetzung und Wiederholung

`RigLibrary` schneidet vorhandene Schädel-, Blut-, Speer- und Schwertpixel
einmalig aus; `RigRenderer.solve_pose` löst die Elternknochen. Der Strahl
verwendet 16 gegliederte Segmente mit lokalen affinen Posen und dargestellten
Stab-/Körpersockeln. Die Bodenfelder bleiben in `PoolPaint`.

Manuelle Schritte, alle Fähigkeiten und aktuelle Regeln:
`docs/NEKROMANT-DIENER-FLUCH.de.md`. Fluch-Standardleiste: **4 Blutstrahl**;
großer Diener: **5 Stampfen, 6 Klingensturm**.

Beispiel für einen gezielten Lauf (Godot-Pfad lokal über die üblichen
Umgebungseinstellungen auflösen): `godot --headless --path . --script
tests/necro_rig_link_test.gd`. Netzwerk: `powershell -File
tests/necro_blood_network_smoke.ps1`.

`source-hashes.json` hält SHA256 der finalen Quellen fest. Frühere Aufnahmen
unter `necro-branches/` dokumentieren die vorherige Umsetzung. Keine Commits,
Pushes oder Merges in dieser Überarbeitung.
