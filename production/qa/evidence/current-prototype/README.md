# Aktueller Prototyp —26.10.2026

**Historischer, verworfener Materialstand.** Die aktive Darstellung verwendet
wieder die Original-Tiles. Aktuelle Bilder: [Original-Pack](../restored-original-pack/README.md).


Echte1280×720-Aufnahmen aus Godots laufender Spielszene `src/game.gd`, mit der
normalen aktiven Bibliothek `assets/data/dungeon_rooms.json`. Keine generierten
Illustrationen und kein separater Editor-Spielmodus.

Die Räume wurden für die Fotos direkt geladen; die Simulation war während der
Aufnahmen angehalten. Kamera/Spieler wurden für Garten, Archiv und Boss passend
positioniert. Es wurde kein vollständiger Durchlauf vorgespielt. Bilder sind
unveränderte GPU-Viewport-Aufnahmen.

| Ansicht | Aufnahme |
| --- | --- |
| Einstieg, Raum1 | [Foto](01-einstieg.png) |
| Garten, in diesem Seed Raum8 | [Foto](08-garten.png) |
| Archiv, in diesem Seed Raum9 | [Foto](09-archiv.png) |
| Bosskammer, Raum10 | [Foto](10-boss.png) |
| Zehn Räume im Esc-Kartenmenü | [Foto](zehn-raumkarte.png) |

Seed42026. Folge: `crypt_01, crypt_09, crypt_04, crypt_05, crypt_03, crypt_08,
crypt_02, crypt_06, crypt_07, crypt_10`. Alle zehn Vorlagen sind verschieden.
Raum10 erzeugte tatsächlich drei Gegner: einen Boss und zwei normale Begleiter.
Die protokollierten Raum-/Gegnerdaten stehen in [capture_details.json](capture_details.json).

Das Spiel blieb anschließend wieder im normalen Hauptmenü geöffnet; eine neue
Sitzung verwendet wieder einen zufälligen Seed und die normalen Port-Einstellungen.
Es wurden keine Unit-, Netzwerk- oder Leistungssuiten gestartet.
