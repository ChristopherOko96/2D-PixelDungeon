# Räumliche Gegnersuche der Story-Welten

04.11.2026, auf Basis `7c39036e`. Lokale Optimierung auf `codex_v2`.

## Synchronisierung

`HellTalents.chase_goal` und `basic_hit` aktualisieren jetzt nur den betroffenen
Gegner über `_sync_mob`. Die eindeutige `tid`, Statusfelder und die Aliasfelder
`pos`/`radius` bleiben erhalten. Die vollständige Synchronisierung findet weiter
an den notwendigen Talent-Phasengrenzen statt. Eine einzelne Zielabfrage läuft
nicht mehr erneut über sämtliche Gegner.

## Räumlicher Index

`src/physics_kit/story_enemy_index.gd` ist eine konservative Vorauswahl. Eine
Welt besitzt einen Index; seine Zellgröße entspricht dem vorhandenen `C` der
Welt. Körper werden mit Radius sowie ihrer erhöhten Treffermitte eingetragen.
Mehrzellige Körper werden dedupliziert. Ergebnislisten behalten die Reihenfolge
der ursprünglichen Gegnerliste und sind **nur zum Lesen** bestimmt.

Die Story-Laufzeit aktualisiert ihn vor der Gegnerbewegung und, wenn vorhanden,
vor normalen beziehungsweise Talentprojektilen. Bewegung und Spawns aktualisieren
die betroffenen Einträge unmittelbar. `_shove` meldet Talentverschiebungen über
den optionalen `talent_moved`-Adapter zurück. Tod und Despawn entfernen Einträge;
Etagenwechsel, Run-Ende und ein geänderter Gegnerbestand verwerfen alte Einträge.

Angeschlossen sind Krypta, Hölle, Frostgruft und Custom Storys auf derselben
Laufzeit. Gegnerabstand und Gravitation fragen Nachbarn ab. Normale Geschosse,
Talentgeschosse und die kurzen Segmente der Seelen-/Knochenprojektile verwenden
die Vorauswahl für ihren Flugbereich. Die bisherigen genauen Radius-, Segment-,
Wand- und Maskenprüfungen entscheiden weiterhin über Treffer. Der ältere
ENet-Spielkern verwendet bei gemeinsamen Seelengeschossen seinen bisherigen
Suchweg, wenn der Adapter keine räumliche Abfrage anbietet.

## Konservative Fälle und Grenzen

- Bosse und Körper mit mehr als 64 belegten Rasterzellen bleiben vollständige
  Kandidaten. Eine große Abfrage fällt auf einen vollständigen Durchlauf zurück,
  statt sehr viele leere Zellen abzulaufen.
- Animierte Körperteile können weit außerhalb des normalen Radius liegen.
  Geschossabfragen behalten deshalb alle Figuren mit `parts` als Kandidaten für
  die bestehende Maskenprüfung. Bei gewöhnlichen Körper-Nachbarn gilt dieser
  zusätzliche Fallback nicht. Eine zuverlässige dynamische Rig-Bounding-Box
  wäre Voraussetzung, um auch diese Maskenkandidaten weiter einzuschränken.
- Aufeinanderfolgende kurze Geschosssegmente dürfen die Kandidaten derselben
  Zellen wiederverwenden. Eine Änderung der Zellbelegung oder des Bestands
  invalidiert den Cache. Die enthaltenen Körper-Dictionaries bleiben aktuell.
- Bei vielen Körpern in derselben Zelle bleibt der ungünstigste Fall groß.
  Nicht alle weiteren Ziel- und Flächeneffekt-Suchwege wurden umgestellt.
- Es gibt keine Änderung an Schadenswerten, Gegnerzahl, Simulationstakt oder
  Grafikqualität. Eine geringere CPU-Schrittzeit ist keine gemessene FPS-Zahl.

## Nachweise

### Erweiterung für Talente (05.11.2026)

Begrenzte Zielwahl, kreisförmiger Flächenschaden, Projektil-Splash,
Fallenauslösung und -explosion, Begleiter-Nova/-Cleave/-Taunt, Heranziehen,
Meteor-Folgezielwahl und Einfrieren bei der Landung verwenden jetzt ebenfalls
den Index. Die genauen Reichweiten, Körperradien, Wandprüfungen und die
ursprüngliche Reihenfolge bleiben erhalten. Bei gleicher Zieldistanz gewinnt
weiter der letzte passende Gegner der ursprünglichen Liste.

Unter 24 Gegnern, bei unbegrenzten Abfragen und ohne Story-Adapter bleibt die
vollständige Suche aktiv. Enthält eine Rasterzelle mindestens die Hälfte der
Gegner, verwendet die Talentphase die aktuelle vollständige Liste. Dieser
Kostenhinweis stammt aus dem letzten Indexaufbau; ein veralteter Hinweis kann
nur mehr Kandidaten prüfen, keine Treffer auslassen. Für verteilte Gruppen
wird der Index erst bei der ersten benötigten Talentabfrage erneut aufgebaut.
Weitere Abfragen derselben Phase verwenden ihn weiter. Seelenschub meldet
seine Bewegung jetzt ebenfalls über `_shove` unmittelbar zurück.

Globale Suchen, ID-Abfragen und Bodenfelder mit eigener tatsächlicher
Ausdehnung bleiben unverändert. Ein nomineller Effektradius wäre für diese
Felder keine sichere Begrenzung.

`tests/talent_spatial_queries_test.gd` vergleicht Ergebnisse und Trefferfolge
mit einer vollständigen Referenzsuche und prüft den dichten Rückfallpfad.
Der Integrationstest verwendet jetzt 32 Gegner je Story-Welt und prüft die
begrenzte Zielsuche auch nach einem Teleport. Messung und vollständige Logs:
`production/qa/evidence/talent-spatial/README.md`. Die dortigen 60–68 % weniger
CPU-Zeit beziehen sich auf isolierte Suchvorgänge bei großen verteilten Gruppen,
nicht auf die Bildrate des gesamten Spiels.

### Ursprünglicher Indexnachweis

`tests/story_enemy_index_test.gd` prüft Vollständigkeit, Reihenfolge, Grenzen,
Bewegung, Entfernen, Körperteile und die lokale Synchronisierung.
`tests/story_enemy_index_integration_test.gd` prüft die drei echten Story-Welten,
erste Projektiltreffer, Spawns, Teleports, Verschiebungen, Run-Ende und Bewegung
gegen eine vollständige Such-Referenz.

`scripts/bench_story_enemies.gd` misst alte und neue Fassung abwechselnd im
selben Prozess auf einer identisch erzeugten Krypta-Karte. Alte Quelldateien
werden dafür separat aus Git rekonstruiert; der Checkout wird nicht ersetzt.
Ergebnisse, Reproduktion und Einschränkungen stehen in
`production/qa/evidence/enemy-index/README.md`.
