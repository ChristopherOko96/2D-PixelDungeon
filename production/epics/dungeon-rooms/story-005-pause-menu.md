# Story 005: Aufgeräumte Spielansicht und Esc-Menü

> **Epic**: Dungeon aus Raumvorlagen
> **Status**: Done
> **Layer**: Presentation / Input / Simulation
> **Type**: UI / Integration
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-10-25

## Context

Nutzerauftrag: Herzen oben links, Raum-/Bossdetails und Karte als Menüpunkte;
Esc öffnet das Pausenmenü. Die Spielansicht soll weniger Informationen zeigen.
Engine Godot4.7.2; höchstens vier Teilnehmer; native16-Pixel-Geometrie bleibt.

## Acceptance Criteria

- [x] Herzen als gemeinsame Grafik oben links, mittige Spielwelt mit2×-Zoom.
- [x] Keine dauerhafte Spiel-Seitenleiste, Raumtexte, Karte oder Spieler-LP-Balken.
- [x] Esc/Mouse öffnen und schließen ein Menü mit Übersicht, Karte, Gruppe/Perks,
  Belohnung, Steuerung und Sitzung; Tastaturfokus ist benutzbar.
- [x] Solo friert nur die Simulation ein; Mehrspieler läuft für andere weiter.
  Menüstatus erklärt den Unterschied. Netzwerkpolling bleibt aktiv.
- [x] Lokale Bewegung/Schüsse/Interaktion werden bei offenem Menü unterdrückt.
  Kein Schuss durch den Klick zum Schließen.
- [x] Perkauswahl, Bereitschaft, Erkundung, Neustart und Verlassen bleiben erreichbar.
- [x] Bossname/-raum/-status und Fortschritt kommen aus echten Laufdaten.
- [x] Regel-/Integrationsprüfungen, echter Host/Client-Menütest, Vierer-Regression,
  Import und grafische Prüfung aller sechs Seiten bestanden.

## Implementation

`pause_menu.gd` zeigt Hostsnapshots und emittiert normale Aktionswünsche.
`game.gd` trennt Lobby und Live-HUD, neutralisiert Menüeingaben und überspringt
World-Stepping nur im pausierten Ein-Teilnehmer-Host. Kein `SceneTree.paused`
und keine neue Clientbefugnis. Die regulären Hostprüfungen vergeben Perks.

Der Herz-HUD hat einen kompakten Modus. `dungeon_view.gd` blendet im Hauptspiel
redundante Spieler-LP/Ready-Marken aus; Editor/Artreferenz behalten sie.
Der Boss-Arbeitsname steht als `boss.display_name` in der externen Balance-Datei.
Neue Snapshotfelder `boss_name`/`max_players` dienen der Darstellung.
Der Editor-Rückkehrbutton sitzt unterhalb des neu zentrierten Spielfelds.

## Evidence

- Neue Prüfung vor Implementierung rot1/1; Belohnungsseite in Erkundung vor
  Korrektur rot23/1, danach erweitert auf `PAUSE_MENU checked=25 failures=0`.
- Bestehende Spielregeln22/0, Erkundung51/0, Dungeon-Integration23/0 und
  Editor-Integration25/0 bestanden. Geometriealgorithmus nicht verändert.
- `Dev.ps1 Check`:14 Spielskripte importiert/geparst.
- Zwei echte Prozesse mit geöffneten Menüs: PASS,
  `Logs/pause-network-smoke/20261025-224126-f979bb47`. Gegner und Snapshots
  schreiten weiter; Host erhält neutrale Clientbefehle.
- Vier echte Prozesse über zwei Ebenen/sechs Layouts/24 Perks: PASS,
  `Logs/dungeon-network-smoke/20261025-223618-d53490ff`,76,7s.
- Hauptansicht, alle sechs Menüseiten und Editor-Testansicht mit OpenGL gerendert
  und angesehen. Anleitung/Bilder: `docs/SPIELMENUE.de.md`.

## Limits

Keine globale Mehrspieler-Pause oder Abstimmung, keine Hostmigration, keine
neue LAN-/WAN-/Latenz- oder Leistungsabnahme. Hauptspiel und Spielgeometrie
bleiben von der ausführlicheren Artstyle-Referenz unterscheidbar.
