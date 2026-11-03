# Custom-Story-Bereich mit gemeinsamen Spielsystemen

Stand: 03.11.2026. Die aktuelle Nutzerklärung legt einen eigenen Bereich für
selbstgemachte Storys und den zugehörigen Editor fest. Umgesetzt, siehe „Umsetzung“ am Ende.

## Festgelegtes Ziel

Der Nutzer möchte einen eigenen Custom-Story-Bereich, in dem selbstgemachte
Geschichten und Dungeons erstellt, ausgewählt und gespielt werden. Der Editor
gehört zu diesem Bereich. Die bestehenden Hauptstorys behalten ihre eigenen
Inhalte und ihren bisherigen Generierungsweg; ihre Umstellung auf Editor-Räume
ist durch diesen Auftrag nicht gefordert.

Innerhalb eigener Storys können gestaltete Raumvorlagen prozedural zu
unterschiedlichen Etagen zusammengesetzt werden, entsprechend der vorherigen
Klärung. Die neue Bereichsaufteilung verlangt keine feste Raumreihenfolge.

Eigene Geschichten und die Hauptstories sollen dieselben Spielsysteme nutzen:
Charaktere, Talente, Inventar, Gegner, Sounds und Effekte. Der Editor erstellt
Inhalte für dieses gemeinsame Story-System; er begründet keinen zusätzlichen
Spielkern mit eigenen Kampf- oder Fortschrittsregeln.

Gewünschter Ablauf:

Custom-Story-Bereich → eigene Geschichte erstellen/bearbeiten → Raumeditor
und Raumbibliothek → prozedurale Etage → gemeinsame Story-Laufzeit.

Damit wird die frühere Auslegung präzisiert: gemeinsam sind die Spielsysteme;
eigene Geschichten erhalten einen eigenen Inhalts- und Menübereich. Weder ein
zusätzlicher Spielkern noch die automatische Verwendung persönlicher Räume in
den Hauptstorys ist das Ziel. Die genaue technische Umsetzung bleibt auszuarbeiten.

## Aktueller Code und Unterschied zum Ziel

- `src/world_kit/world_core.gd` erzeugt zunächst einen Plan aus groben
  Rasterpositionen, gruppiert sie zu Räumen und baut daraus Grundrisse,
  Verbindungen und Ausstattung. Der Story-Generator verwendet derzeit keine
  Bibliothek der im Raumeditor gestalteten Räume.
- `src/world_kit/world_pack.gd` liefert Weltregeln und leitet Etagen-Seeds aus
  einer Weltnummer ab. Diese prozedurale Arbeitsweise ist die Grundlage.
- `src/hell/hell_game.gd` ist die gemeinsame Story-Laufzeit für Krypta,
  Frostgruft und Hölle. Die bestehenden Story-Systeme sollen weiterverwendet werden.
- `src/editor/room_doc.gd` und `src/editor/room_editor.gd` bearbeiten bisher
  Raumvorlagen für `assets/data/dungeon_rooms.json`. Ihr Testspiel führt über
  `src/game.gd`, nicht über die aktuelle Story-Laufzeit.
- Die Formate unterscheiden sich: Editor-Zellen verwenden 32 Welteinheiten,
  der Story-Weltgenerator verwendet 96. Die Abbildung ist ausdrücklich zu
  definieren; eine einfache Dateiumbenennung verbindet die Systeme nicht.
- Die neuen Story-Welten haben aktuell keinen LAN-Koop. Gemeinsame Inhalte
  allein implementieren noch keinen Koop-Anschluss.

## Vorgeschlagener erster Umsetzungsschritt

Zunächst den Custom-Story-Bereich mit einer eigenen Geschichtenliste und dem
Zugang zum Raumeditor vorsehen. Als erster durchgängiger Ablauf soll eine eigene
Krypta-Geschichte ihre gestalteten Räume prozedural zusammensetzen und mit den
bestehenden Story-Spielsystemen spielbar werden. Diese erste Geschichte ist
ein eigenes Inhaltspaket, kein Austausch der Hauptstory „Krypta der Verdammten“.

Vor der Umsetzung sind insbesondere folgende Details auszuarbeiten:

- Gemeinsames Raumformat mit Größe, Weltzuordnung, Raumrolle und Türanschlüssen.
- Einbau in den Etagenplan mit passenden Größen, Anschlüssen und freien Wegen.
- Erhalt der gestalteten Wände und Ausstattung; explizite Regeln für zufällige
  Gegner, Beute und zulässige Varianten. Keine ungefragten Drehungen der Wandgrafik.
- Erreichbarer Start und Abschluss; Schlüssel vor ihrem verschlossenen Tor.
- Versionierung der Inhalte und Verhalten bestehender Spielstände.
- Eigene Speicherung und eindeutige Zuordnung von Geschichten, Raumvorlagen und
  Spielständen, damit persönliche Entwürfe und Hauptstory-Inhalte sich nicht ersetzen.
- Übereinstimmung von Vorschau und Spiel, solange JS- und Godot-Generator parallel bestehen.

Diese Punkte waren die Vorgaben für die Umsetzung.

## Arbeitsstand und Grenzen

Die Planung oben ist umgesetzt; den Stand beschreibt „Umsetzung“ unten. Die separat
freigegebenen Timing-Tests sind in [Fester Simulationstakt](FESTER-SIMULATIONSTAKT.de.md) dokumentiert.

Weiterlesen: [bestehender Welt-Baukasten](WELT-BAUKASTEN.de.md),
[bestehender Raumeditor](DUNGEON-EDITOR.de.md).

## Umsetzung (Stand 03.11.2026)

| Teil | Datei | Was es tut |
| --- | --- | --- |
| Format, Prüfungen, Speichern, Löschen | `src/custom/custom_story_data.gd` | Geschichte v1 mit Raumbibliothek in 96er-Zellen; Rollen Eingang, Kampf, Shop, Schatz, Boss; Entwürfe dürfen unvollständig sein, Spielen verlangt verbundene Böden und Türen. Dateien unter `user://custom_stories/` (+ `.bak`). |
| Generator | `src/custom/custom_story_world.gd` | Hängt Module an gegenüberliegenden Türanschlüssen an (kurze Gänge, keine Überlappung), Eingang und Boss fest, Shop und Schatz eingestreut. Shop wie im Hauptspiel: Händler, Tisch, Brunnen. Schatz: Truhe (Edelsteine + Herz). Boss: Wächter der Welt-Etage, danach Portal. |
| Bibliothek und Editor | `src/custom/custom_story_panel.gd`, `custom_room_canvas.gd` | Neu, Bearbeiten, Löschen (samt Spielständen), Spielen, Fortsetzen; Raumeditor mit Grafiken der gewählten Welt, Werkzeuge Boden/Radieren/Rechteck/Tür/Gegner/Ausstattung, Undo, Raum testen. |
| Etagen-Vorschau | `src/custom/custom_floor_preview.gd` | Zeigt Etage 1 des Entwurfs mit derselben Erzeugung wie im Lauf; Welt-Nr. und „Würfeln“ zeigen andere Zusammensetzungen. |
| Laufzeit | `src/hell/hell_game.gd`, `src/save/story_save.gd`, `src/game.gd`, `src/main_menu.gd` | Custom-Läufe nutzen die Story-Szene ihrer Welt, eigene Slots (`user://custom_story_saves/<id>/`) und eine eigene Profilkopie; Spielstände tragen die gespielte Fassung der Geschichte mit. |

Tests: `tests/custom_story_{data,save,runtime,menu,ui}_test.gd`. Bilder: `production/qa/evidence/custom-story/`.
Der Shop selbst ist wie in den Hauptstorys noch ein Platzhalter („Der Laden öffnet später“).
