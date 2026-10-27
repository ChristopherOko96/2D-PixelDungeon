# Figurenanimationen: Katalog, Rig und Wiedergabe

**Aktueller Artstand ist Story024:** [32×32-Chibis und Lovecraft-Boss](CHIBI32-ELDRITCH.de.md).
Alle aktiven Schlüsselbilder sind jetzt32×32; normale Figuren2×, Boss3×.
Die48 Aktionen und die Wiedergabe-API gelten weiter. Nachfolgende Quellgrößen,
Tabellen und Attack→Idle-Remap beschreiben die historische Story023-Art;
die aktuellen Maße und neuen stabilen Zauberposen stehen im verlinkten Dokument.

Jede der acht Figuren besitzt **48 eigenständige Animationsabläufe mit je sechs Bildern**. Jeder Ablauf liegt zusätzlich in vier Ansichten vor: Süden, Osten, Norden und Westen. Die Richtungen zählen nicht als zusätzliche Aktionen. Das ergibt 192 gerichtete Clips beziehungsweise 1.152 Bilder pro Figur und 9.216 Bilder im gesamten Katalog.

Die Figuren sind `player_warden`, `player_ranger`, `player_arcanist`, `player_lizard`, `skeleton_archer`, `necromancer`, `skeleton_guard` und `boss`. Die Quelldarstellungen sind generierte Pixelgrafiken mit jeweils vier eigenständigen Ansichten und vier Schlüsselposen. Herkunft und Import stehen in [PLAYER-PROVENANCE.md](../assets/actors/PLAYER-PROVENANCE.md) und [ENEMY-PROVENANCE.md](../assets/actors/ENEMY-PROVENANCE.md).

## Selbst ansehen

Im Projektordner **Animation-Studio.cmd** doppelklicken. Alternativ in PowerShell
`./scripts/Dev.ps1 AnimationStudio` starten oder in Godot
`src/animation_studio.tscn` öffnen und F6 drücken.

1. Links eine Figur und darunter einen der48 Abläufe auswählen. Das Suchfeld
   findet deutsche Namen sowie die technischen Aktionskennungen.
2. Oben Blickrichtung, Tempo und Ansicht wählen. Norden zeigt eine echte
   Rückansicht. Die Figur bleibt im Vorschaufeld; starker Zoom kann sie beschneiden.
3. Mit Pause und Bild zurück/vor die sechs Bilder einzeln betrachten. Die
   Zeitleiste springt direkt an die gewünschte Stelle, Neustart beginnt bei0.
4. Die Beschreibung unterscheidet aktuelle Spielzustände und vorbereitete
   Animationen. Zum Spiel öffnet den normalen Prototypen.

Die vier Spielerfarben wählen Wächter, Späherin, Arkanist und Echsenjäger.
Eine nachträglich wieder belegte Lobbyposition sowie Laufneustarts behalten
die Identität des jeweiligen Teilnehmers. Ihre Spielwerte bleiben gleich;
die sichtbaren Waffen erzeugen keine neuen Klassenregeln.

## Einbindung ins Spiel

Der Host liefert Figurenkennung, tatsächlichen Bewegungsvektor, Blickrichtung,
Trefferseite/-stärke, Schussabstand und monotone Schuss-/Block-/Interaktionszähler.
`ActorMotionController` beobachtet nur neue Zustandskanten und startet dadurch
keine Animation wegen eines wiederholt empfangenen Pakets erneut. Eine eigene
Laufseriennummer trennt auch Neustarts mit identischem Seed. Wechselnde Räume
räumen alte Gegnerzustände auf; zuvor gefallene Spieler erhalten beim regulären
Wiederbeleben ihre Wiederkehranimation.

Im Spiel sind35 Aktionskennungen erreichbar, rollenabhängig über Atmen/Zielen,
Bewegung vorwärts/rückwärts/seitwärts, Anlaufen/Anhalten/Drehen, Angriffsphasen,
Aufladen, Richtungstreffer, Betäubung, Schildblock, Spawn/Wiederkehr, Interaktion,
Belohnungsreaktion und drei Todesphasen. Die übrigen13 sind in der Werkstatt
vorbereitet. Ein einzelner Charakter verwendet während eines Laufs jeweils
die zu seiner vorhandenen Rolle passenden Zustände.

Trefferfedern, Flash, Hitstop, Partikel und vorhandene Sounds bleiben zusätzlich
aktiv. Das alte kontinuierliche Ganzkörperwippen entfällt bei den neuen Clips,
damit es die Körperteilanimation nicht doppelt überlagert. Die Weltfußanker und
Kollisionsradien bleiben erhalten. Der Tod eines normalen Gegners dauert jetzt
0,8s, beim Boss1,6s; der Raum wartet wie bisher auf den Abschluss dieser Phase.
Protokoll und Regeln stehen deshalb auf4/4.

## Was die 48 Aktionen darstellen

| Gruppe | Eigenständige Aktionen |
| --- | --- |
| Ruhe | `idle_breathe`, `idle_look`, `idle_alert`, `idle_relaxed` |
| Bewegung | `walk_forward`, `walk_backward`, `strafe_left`, `strafe_right`, `run_forward`, `run_backward`, `sprint`, `start_moving`, `stop_moving`, `turn_left`, `turn_right` |
| Zielen | `aim_enter`, `aim_hold`, `aim_adjust` |
| Angriff | `attack_windup`, `attack_primary`, `attack_followthrough`, `attack_recover`, `attack_secondary` |
| Aufladen | `charge_start`, `charge_loop`, `charge_release` |
| Treffer | `hit_front`, `hit_back`, `hit_left`, `hit_right`, `heavy_hit`, `stagger`, `stun_loop`, `knockback` |
| Deckung | `guard_raise`, `guard_block`, `guard_break` |
| Ausweichen | `dodge_left`, `dodge_right`, `dodge_back`, `dash_forward` |
| Lebenszyklus | `death_start`, `death_fall`, `death_settle`, `spawn`, `revive` |
| Interaktion | `interact`, `celebrate` |

**Vorbereitet bedeutet nicht als neue Spielmechanik eingebaut.** Die Bank kann alle Aktionen wiedergeben; das Animationsstudio kann alle Aktionen vorführen. Der Spielcontroller verwendet passende Clips für tatsächlich vorhandene Zustände. Die aktuelle Liste steht in `ActorMotionController.bound_actions()`. Insbesondere gewähren Ausweich-, Sprint- oder Deckungsclips einem Spieler keine zusätzlichen Fähigkeiten, Unverwundbarkeit oder Eingaben. `runtime_binding: "prepared"` kennzeichnet im Datenkatalog derzeit ungebundene Abläufe.

## Wie die Bilder entstehen

`scripts/bake_actor_animations.gd` liest pro Figur die 16 Schlüsselbilder aus `assets/actors/keys/{actor}/{direction}_{idle|move|attack|hurt}.png`. Alle Schlüsselbilder einer Figur müssen dieselbe Canvasgröße besitzen. Die tatsächlichen PNG-Abmessungen werden gelesen: Spieler, Bogenschütze und Nekromant 24×32; Schildkrieger 28×32; Boss 48×48. Die unterschiedliche Breite bewahrt ausgestreckte Waffen und die größere Bosssilhouette.

Das Rig ermittelt Körpermitte, Hals und Hüfte aus dem sichtbaren Idle-Körper. Es teilt jede Pose in Kopf, Rumpf, zwei Arm-/Waffenbereiche und zwei Beine auf. Kopf, Beine, Arme und Rumpf werden mit den im Katalog angegebenen Einzelkurven versetzt, gedreht oder gestaucht. Die vier Schlüsselposen wechseln je nach Aktion. Ein Bogenschütze oder Stabträger erhält eine geringere Armrotation als ein Nahkämpfer. Der Boss erhält größere, proportional zur Quellhöhe skalierte Bewegungswege. Die Westansicht verwendet die echte Westgrafik und gespiegelte Bewegungsrichtungen; die Nordansicht besitzt eigene Schlüsselgrafiken.

Der Kopf besitzt eine aus der zusammenhängenden Idle-Silhouette ermittelte Maske mit einem Pixel Toleranz. Verbundene Hörner und Hüte bleiben am Kopf; angehobene äußere Klauen und separate Stabspitzen gehören zu den Armen. Dadurch folgt eine gehobene Bosskralle ihrer Armbewegung vollständig. Beim Nekromanten verwendet `pose_remap: {"attack": "idle"}` bewusst die stabile Idle-Handhaltung als Ausgangsbild für die Angriffsbewegung: Die generierte Attackschlüsselpose wechselte die Stabseite. Das originale Schlüsselbild bleibt erhalten. Die unabhängigen Arm-, Rumpf-, Kopf- und Beinkurven erzeugen weiterhin alle 48 unterschiedlichen Abläufe; der Remap ersetzt nur die instabile Basispose.

Alle Transformationen werden offline mit nächster Pixelabtastung auf ein festes Pixelraster gebacken. Es gibt keine zufälligen Farbpunkte, Markierungspixel, Farbänderungen zur Erzeugung eindeutiger Hashes oder versteckten Framekennungen. Eine Aktionsfolge unterscheidet sich durch sichtbare Körperteilbewegung und ihre gewählten Schlüsselposen. Ein Hashvergleich prüft diese Eigenschaft zusätzlich; er ersetzt keine visuelle Beurteilung im Studio.

Jede Figur bekommt ein gemeinsames transparentes Bewegungspadding für sämtliche Aktionen. Dieses Padding wird aus der Vereinigung aller Framegrenzen berechnet, damit ausgestreckte Waffen oder Fallbewegungen nicht am Cliprand abgeschnitten werden. Der Fußanker bleibt innerhalb einer Figur über alle Frames gleich. Quellen bleiben unverändert. Die Rendergröße beträgt durchgehend **2 Weltpixel pro Quellpixel**; die größeren Atlaszellen ändern nicht den Körpermaßstab.

| Figur | Quellcanvas | Gebackene Framezelle | Atlas |
| --- | --- | --- | --- |
| Wächter | 24×32 | 29×44 | 696×2112 |
| Späherin | 24×32 | 30×43 | 720×2064 |
| Arkanist | 24×32 | 34×44 | 816×2112 |
| Echsenjäger | 24×32 | 32×45 | 768×2160 |
| Skelettbogenschütze | 24×32 | 31×45 | 744×2160 |
| Nekromant | 24×32 | 29×44 | 696×2112 |
| Schildkrieger | 28×32 | 33×46 | 792×2208 |
| Boss | 48×48 | 55×69 | 1320×3312 |

Diese Werte stammen aus dem aktuellen Bake; nach Änderungen sind die Werte im erzeugten Index maßgeblich. Pro Figur existieren ein Farbatlas und ein vorab erzeugter weißer Trefferatlas mit identischem Alpha. Die 16 Texturen enthalten zusammen 124.286.976 rohe RGBA-Bytes, ungefähr **118,53 MiB**. PNG-Dateigröße, Importdateien und zusätzliche Texture-Objekte sind separate Größen. Der größte Atlas bleibt unter 4096 Pixeln je Achse. Die Messung ist eine Speicherberechnung, kein FPS-Benchmark.

## Datenvertrag, Schema 1

`assets/data/actor_animations.json` enthält die bearbeitbaren Angaben:

- `schema_version`: aktuell 1; bei inkompatiblen Änderungen erhöhen.
- `frames_per_clip`: 6. `directions` legt Reihenfolge und zulässige Ansichten fest.
- `actors`: `id`, Anzeigename, `source_root`, tatsächliche `source_size`, `render_scale` (2), `base_feet` (bestehender Weltanker: 16, Boss 24), erzeugte Atlaspfade, `frame_size`, `anchor`, `arm_rotation_scale` (0,65 für Bogen/Stab, sonst 1).
- `actors[].pose_remap`: optionale Zuordnung einer Schlüsselpose zu einer anderen (`idle`, `move`, `attack` oder `hurt`); Standard `{}` erhält alle Originalposen. Aktuell ersetzt nur der Nekromant seine Attackbasis durch `idle`, um dieselbe Stabhand beizubehalten.
- `actions`: `id`, Anzeigename, Kategorie, `duration` in Sekunden, `loop`, `runtime_binding`, sechs `poses` sowie sechs `frames`. Richtungen verändern die Anzahl der Aktionen nicht.
- Jedes Frame besitzt `root`, `head`, `torso`, `arm_l`, `arm_r`, `leg_l`, `leg_r`. Jeder Kanal enthält `[x, y, winkel_grad, scale_x, scale_y]`; Verschiebungen sind native Quellpixel. Nullverschiebung/-rotation und Skalierung 1 bilden die unveränderte Pose. `root` transformiert das zusammengesetzte Rig zusätzlich um die Hüfte.
- `rig`: `head_end` 0,42 und `waist` 0,78 sind Höhenanteile der sichtbaren Idle-Bounds; `torso_half_width` 0,24 ist ein Breitenanteil. `arm_overlap` und `neck_overlap` stehen für 1 Pixel Gelenküberlappung. `padding` `[2,4]` beschreibt zunächst zwei Pixel horizontalen Rand und vier Pixel oberen Rand; die gemeinsame Bewegungserweiterung wird anschließend berechnet.
- `controller`: optionale Präsentationswerte `run_speed_threshold` in Weltpixeln/Sekunde (160) und `heavy_hit_fraction` als Anteil der maximalen HP (0,35). Diese Werte ändern weder Schaden noch Bewegungsgeschwindigkeit.

`assets/actors/baked/actor_animation_index.json` wird erzeugt. Es enthält `quality_validated`, `problems`, Reihenfolgen sowie je Figur `frame_size`, Fuß-`anchor`, `atlas_size`, `raw_pair_bytes`, Quell-SHA256 und `clips[action][direction]`. Jeder gerichtete Clip enthält sechs sichtbare `bounds` (x/y/Breite/Höhe), `distinct_frames` und `sequence_sha256`. Atlas-Spalte = Richtung×6 + Frame, Atlas-Zeile = Aktionsindex. Fehler bei fehlenden Quellen, unterschiedlichen Quellcanvases, abgeschnittenem Scratchbereich, weniger als drei verschiedenen Bildern oder identischen Aktionsfolgen verhindern einen erfolgreichen Bake.

## Wiedergabe-API

`src/actor_animation_bank.gd` stellt eine `RefCounted`-Bank bereit:

```gdscript
var bank: RefCounted = preload("res://src/actor_animation_bank.gd").new()
if bank.prepare():
    var frame: Dictionary = bank.sample("player_warden", "walk_forward", "south", elapsed, true)
```

`prepare() -> bool` lädt und validiert den Katalog, Index und alle acht Atlaspaare einmalig. Ein nicht erfolgreich gebackener Index wird abgewiesen; es gibt keine Ersatzgrafiken. `catalog()`, `actors()`, `animations(actor)` und `duration(clip)` liefern Metadaten. Katalog und zurückgegebene Frame-Dictionaries werden als schreibgeschützt behandelt.

`sample(actor, clip, direction, elapsed, loop=true)` liefert `texture`, `flash_texture`, `scale`, `feet`, `anchor`, `top_crop`, `clip`, `frame`, `width` und `height`. Die beiden Texturen sind gecachte `AtlasTexture`-Regionen. `width`/`height` bezeichnen die gepaddete native Framezelle. `anchor` ist der gemeinsame native Fußanker; horizontal muss der Renderer `anchor.x × scale` abziehen. `feet` ist die zum bisherigen Renderer passende Weltverschiebung einschließlich unterem Padding. `top_crop` ist die obere transparente Höhe in Weltpixeln. Die Werte verhindern, dass Padding den Körper oder Lebensbalken versetzt.

Auch der Transformationsdrehpunkt muss den Fuß verwenden: Weltanker =
`point + Vector2(0, feet - (height - anchor.y) * scale)`; der Bildursprung
relativ dazu ist `-anchor * scale`. Dadurch verschiebt Treffer-Squash oder
Lean keine Figur wegen transparentem Platz unter dem Fuß. Ein GPU-Test mit
einem sichtbaren Fußpixel reproduzierte zunächst drei Fehler bei zehn Prüfungen;
nach dem Fix bestehen alle zehn einschließlich des alten Spritepfads.

Loopende Clips wickeln nach ihrer eigenen Dauer um; endliche Clips halten das letzte Bild. Negative Zeiten ergeben das erste Bild. Unbekannte IDs/Richtungen und nicht endliche Zeiten liefern ein leeres Dictionary. Große endliche Zeiten werden vor der Integerumwandlung reduziert. Wiederholte Abfragen erzeugen weder Bildkopien noch neue Texturen. Der lazy Framecache kann höchstens 9.216 Records beziehungsweise 18.432 kleine Atlasregion-Objekte erreichen; die Pixeldaten werden weiterhin nur von 16 Atlanten gehalten. `cache_size()` dient dieser Diagnose.

## Neu backen und gezielt prüfen

Im Projektordner, mit der vorhandenen Godot-Konsolenanwendung:

```powershell
& '../tools/godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script res://scripts/bake_actor_animations.gd
& '../tools/godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe' --headless --path . --import
& '../tools/godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script res://tests/actor_animation_bank_test.gd
& '../tools/godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script res://tests/actor_rig_quality_test.gd
```

Beobachtete Nachweise am 26.10.2026: Der Test schlug vor der Implementierung mit `checked=1 failures=1` fehl. Danach erzeugte der Baker alle acht Figuren mit **0 Fehlern**; der kleinste gerichtete Clip besitzt vier unterschiedliche Pixelbilder. Der Runtime-Test prüfte sämtliche 9.216 Bilder und meldete **21.597 Prüfungen, 0 Fehler**. Er prüft die tatsächlichen Atlaspixel auf mindestens drei unterschiedliche Bilder und eindeutige Aktionsfolgen für jede Figur/Richtung, außerdem Alpha der Flashbilder, Framecache, Loop-/Endverhalten und ungültige Zeiten. Dies bestätigt Daten und Wiedergabe; Spielgefühl und Animationsästhetik bleiben Gegenstand der visuellen Abnahme.

Die zusätzliche Rigregression reproduzierte die abgetrennten Klauen und fehlende Stabseitenkorrektur zunächst mit sechs Prüfungen und fünf Fehlern; nach der Korrektur bestehen acht Prüfungen ohne Fehler. Der fokussierte Spielintegrationstest besteht mit **38 Prüfungen, 0 Fehlern**: Skinplätze einschließlich Wiederbelegung und Neustart, tatsächliche Bewegung einschließlich Wandkontakt, Trefferseite/-stärke, drei Schildarten, Interaktionszähler sowie Gegnerbewegung/-blickrichtung. Der lokale Zweiprozess-Netzwerktest besteht für **Host und Client**; explizite transportbezogene Spielerwerte und `run_serial=2` sind auf beiden Seiten identisch. Der echte gleiche-Seed-Neustart wird separat im Spielintegrationstest geprüft. Diese kontrollierten Fixtures sind kein durchgespielter Dungeon, kein LAN-Test auf zwei Rechnern und kein Belastungs- oder FPS-Test.

## Aktuelle Ansichten und nächster GameDev-Schritt

[Animierte Figurenübersicht](../production/qa/evidence/story-023-actor-animation-library/07-eight-actors-animation.gif),
[Werkstatt](../production/qa/evidence/story-023-actor-animation-library/02-animation-studio.png),
[normaler Solo-Start](../production/qa/evidence/story-023-actor-animation-library/04-prototype-solo.png).
Die Übersicht zeigt sechs ausgewählte Aktionen im GPU-Renderer; die Zeiten
folgen den Clipdauern mit kurzen Lesepausen. Die unabhängige statische
[Nachprüfung](../production/qa/evidence/story-023-actor-animation-library/independent-contact/current/README.md)
umfasst1.152 ausgewählte Bilder; sie ersetzt keine persönliche Art-/Feel-Abnahme.

Am27.10.2026 sind außerdem Studio1.965/0 (mit GPU-Aufnahme1.966/0) und der
Fußanker-GPU-Test10/0 bestätigt. Pause nach mehreren Schleifen, Bildschritte,
Einmal-Clipende und Vorschauclipping sind korrigiert. Der persönliche Dungeon
bleibt SHA256-identisch. Import und Parse der beteiligten Skripte bestanden.

Jetzt folgt dein persönlicher Durchgang: Silhouetten in normaler Spielgröße,
Laufen/Zielen in vier Richtungen, Schuss- und Treffergewicht und die drei
Todesphasen ansehen. Daraus folgt der gezielte Polishing-Durchgang. Die technische
Umsetzung allein gibt weder Artgeschmack noch langfristige Balance frei.
