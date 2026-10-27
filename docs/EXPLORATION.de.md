# 32-Pixel-Dungeons und freie Erkundung

Aktuelle Nutzeranforderung vom 26.10.2026: wieder **32×32 statt 16×16** als
Spielraster. Die native Spielgeometrie beträgt 896×480 Pixel bei 1×-Zoom.
Die gelieferten Dungeon-, UI-, Item- und Animationssheets bleiben unverändert;
ihre Regionen werden passend zur Welt ganzzahlig gezeichnet. Figuren und Gegner
nutzen jetzt die aus `main` übernommenen 0x72-Animationen. Diese Originalframes
haben unterschiedliche Größen und werden 2× dargestellt, etwa 16×28 für Figuren.

## Spielen

1. `Spielen.cmd` starten; Solo wählen oder Host und bis zu drei Clients verbinden.
2. WASD bewegt, Maus zielt, Linksklick schießt. Das Herz-HUD zeigt die eigenen LP;
   ein Herz entspricht zwei LP, halbe und leere Herzen sind eigene Atlasregionen.
3. Nach jedem Kampf **Esc** öffnen, einen persönlichen Perk wählen und
   **ERKUNDUNG FREIGEBEN** bestätigen. Solo pausiert das offene Menü; mit
   geschlossenem Menü bleibt Bewegung auch in der Belohnungsphase möglich.
4. Der Raum bleibt frei begehbar. An einer Tür **E** verwenden.
   Alle lebenden Mitspieler müssen in der Nähe sein. Auch ein Client
   darf den gemeinsamen Übergang auslösen.
   Eine kurze schwarze Aus-/Einblendung deckt den Raumtausch ab. Bewegung,
   Schüsse und Kampf pausieren während des gemeinsamen Übergangs.
5. Zurückgehen ist möglich: gesäuberte Räume behalten ihren Zustand. Es gibt
   weder neue Belohnungen noch wiederholte Heilung/Wiederbelebung beim Zurückgehen.
6. Nach Boss und Belohnung frei weiter erkunden oder gemeinsam die separate
   Innentreppe mit E benutzen. Sie führt in eine neu erzeugte Drei-Raum-Ebene.
   Perks und aktuelle LP bleiben erhalten; die bestehende Prototypregel für
   gefallene Spieler gilt erst beim ersten Eintritt in einen neuen Kampfraum.

Die Karte liegt im **Esc-Menü** und zeigt wirkliche Raumverbindungen und
gesäuberte Räume. Raumfortschritt, Boss, genaue LP und Gruppe stehen ebenfalls
im Menü; dauerhaft bleiben die eigenen Herzen oben links. Solo hält Esc die
Welt an, im Mehrspieler läuft sie weiter. [Menübedienung](SPIELMENUE.de.md).
Der Tod aller Teilnehmer beendet weiterhin den Lauf. Ein Hostverlust beendet die
Sitzung; Hostmigration oder Reconnect während eines Laufs sind nicht implementiert.

## Daten und Zustände

`assets/data/dungeon_rooms.json` und [DUNGEON.de.md](DUNGEON.de.md) beschreiben
Geometrie, Vorlagen, Themes und gegenseitige Türen. Die Hostsimulation entscheidet
über Bewegung, Treffer, Belohnungen, Übergänge und den neuen Floor. Snapshots
enthalten `floor_index`, den aktuellen `seed`, den ursprünglichen `run_seed`,
`cleared_room_ids`, Layout und Karte. Kein Client darf Zielraum, Schaden oder
Raumabschluss vorgeben; `interact` enthält nur die Aktion, kein gewähltes Ziel.

Die neuen Bereiche in `src/data/balance.json` verwenden native Weltpixel und
Sekunden. Die Darstellung übernimmt Weltpixel ohne zusätzlichen Weltzoom:

| Parameter | Bedeutung und Wert |
| --- | --- |
| `player.radius` | 12 Pixel; Körpergröße für Bewegung, Kontakt und Treffer |
| `exploration.interaction_radius` | 56 Pixel um den nächstgelegenen Ausgang für den Auslöser |
| `exploration.party_radius` | 112 Pixel um diesen Ausgang für alle lebenden Teilnehmer |
| `exploration.seed_stride` | 7919: pro Ebene zum Basis-Seed addierter Schritt, modulo 2147483647 |
| `exploration.floor_hp_step` | +15 % Basis-Gegner-LP je weiterer Ebene |
| `exploration.max_hp_multiplier` | Obergrenze 3× für diese LP-Skalierung; Gegnerzahl bleibt begrenzt |
| `feedback.player_hitstun` | 0,18 s Unterbrechung eigener Bewegung und Schüsse nach Schaden |
| `feedback.enemy_hitstun` / `boss_hitstun` | 0,12 / 0,06 s Pause für Bewegung und Boss-Schussvorbereitung |
| `feedback.hit_flash` | 0,16 s sichtbarer Trefferblitz und Original-Treffereffekt |
| `feedback.player_knockback` / `enemy_knockback` / `boss_knockback` | Anfangsgeschwindigkeit 95 / 60 / 18 Pixel/s; Bewegung bleibt durch Wände begrenzt |
| `feedback.knockback_decay` | Rückstoßabbau: Normalgeschwindigkeit ×12 je Sekunde |
| `feedback.enemy_stun_cooldown` / `boss_stun_cooldown` | 0,2 / 0,65 s bis zum nächsten Stun; weitere Treffer verursachen weiterhin Schaden |

Die schon vorhandene Spieler-Unverwundbarkeit von 0,85 s verhindert mehrfachen
Schaden im selben Kontakt. Der Boss-Stun-Cooldown verhindert, dass vier Schützen
seinen Angriff dauerhaft unterdrücken. Projektil-, Lauf- und Rückstoßgeschwindigkeiten
wurden gegenüber der 16-Pixel-Welt verdoppelt; das sichtbare Spieltempo bleibt
dadurch vergleichbar. Fünf vorhandene Perks werden mit separaten Pixelicons
gezeigt. Die gezeichnete Truhe und die drei Angebote erzeugen keine zusätzlichen
physikalischen Pickups oder eine neue Inventarmechanik.

Übergangszeiten, Boss-Angriffsphasen und kurze Todesanimationen stehen ebenfalls
in den Balance-Daten. Tür- und Treppensounds unterscheiden sich. Details und
Prüfbefehle: [Animationen und Übergänge](ANIMATIONEN-UEBERGAENGE.de.md).

## Grafikquellen

- [Vier Dungeon-Tilesets](../assets/tilesets/README.md)
- [UI und Herzen](../assets/ui/README.md)
- [Items, Feuer und Trefferanimationen](../assets/items/README.md)

Wände bestehen aus Oberkante, senkrechter Fläche und Innen-/Außenecken.
Durchgänge liegen an den generierten Wandseiten. Treppensymbole werden nicht
als seitliche Wandtür eingesetzt. Die finale Sichtprüfung ist im
[Prüfbericht](../production/qa/verification.md) dokumentiert.

## Prüfen

```powershell
./scripts/Dev.ps1 Check
$godot = '../tools/godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe'
& $godot --headless --path . --script res://tests/game_rules.gd
& $godot --headless --path . --script res://tests/dungeon_generator_test.gd
& $godot --headless --path . --script res://tests/dungeon_ports_test.gd
& $godot --headless --path . --script res://tests/dungeon_integration_test.gd
& $godot --headless --path . --script res://tests/exploration_rules_test.gd
./tests/dungeon_network_smoke.ps1 -Players 2
./tests/dungeon_network_smoke.ps1 -Players 4
```

Der Prozess-Smoke verwendet echte Bot-Eingaben und wartet mit `--wait-players`
auf die vollständige Gruppe. `--smoke-floors 2` lässt Bots nach dem zweiten
Boss bewusst im Erkundungszustand bleiben. Es werden keine Gegner künstlich
gelöscht. LAN/WAN, Latenz/Paketverlust, Auslastung und Langzeitbetrieb bleiben
separate Abnahmen. Der lokale Vier-Spieler-Lauf ist eine Funktionsprüfung.
