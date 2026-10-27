# Story 005: Hauptmenü mit Benutzerkonto (Firebase) und Fortschritt

> **Epic**: Dungeon aus Raumvorlagen
> **Status**: In Progress
> **Type**: UI + Integration
> **Last Updated**: 2026-10-26

## Context

Wunsch des Projektinhabers vom 26.10.2026: ein schlichtes Hauptmenü mit Anmeldung
per Benutzerkonto über Firebase. Der Firebase-Schlüssel soll hinterlegbar sein,
damit jedes Konto seinen Fortschritt behält. Dazu Optionen, unten rechts die
Version, eine kleine Pixel-Animation, oben Story-Modus und darunter Endlos-Modus.
Die Nachricht brach beim Endlos-Modus ab („den Endless-Mod wollte ich …“).

**Entscheidungen:**
- Firebase läuft über die REST-Schnittstellen per `HTTPRequest`, ohne SDK oder Plugin.
- Die Schlüssel stehen in `firebase.local.json`, die gitignored ist.
- Ohne Einrichtung spielt man als Gast mit lokalem Speicher.
- Fortschritt besteht nur aus Zählern und Bestwerten. Deshalb ist der Abgleich konfliktfrei: Pro Feld gewinnt der größere Wert.

## Acceptance Criteria

- [x] **Hauptmenü:** Titel, STORY-MODUS (oben, groß), ENDLOS-MODUS, MEHRSPIELER, OPTIONEN, BEENDEN; Tastaturfokus auf Story.
- [x] **Pixel-Animation:** fackelbeleuchtete Wand, Steinboden, vier Helden auf der Flucht vor Kobolden und Schamane, Staubpartikel.
- [x] **Version unten rechts**, aus `application/config/version` (0.4.0).
- [x] **Konto oben rechts:** „Gast“ oder „Angemeldet: E-Mail“ mit Fortschritts-Zeile und ANMELDEN- bzw. ABMELDEN-Knopf.
- [x] **Anmeldefenster:** E-Mail und Passwort, ANMELDEN und KONTO ERSTELLEN. Firebase-Fehler erscheinen als verständliche deutsche Meldung. Fehlt die Einrichtung, wird das erklärt.
- [x] **Angemeldet bleiben:** Ein verschlüsselter Refresh-Token ermöglicht die Anmeldung beim nächsten Start ohne Passwort.
- [x] **Fortschritt pro Konto:** Läufe, Siege, Tode, Gegner, Bosse, bestes Level, gesammelte EXP, meiste Räume, Spielzeit. Nach jedem Lauf wird lokal gespeichert, mit Konto zusätzlich in Firestore. Beim Anmelden werden beide Stände zusammengeführt. Testbots schreiben nicht in den echten Fortschritt.
- [x] **Optionen:** Lautstärke, Vollbild, Bildschirmwackeln an oder aus; gespeichert in `user://settings.cfg`.
- [x] **Firestore-Regeln:** Jedes Konto darf nur sein eigenes Dokument lesen und schreiben (`firebase/firestore.rules`).
- [x] **Einrichtungsanleitung:** `docs/firebase-setup.md`.
- [x] **Endlos-Modus** (Entscheidung des Projektinhabers: Nach dem Boss folgt automatisch ein neues, schwereres Stockwerk, bis man stirbt; der Fortschritt speichert das beste Stockwerk):
  - Nach Bosssieg und Perk-Wahl geht es mit „TIEFER HINAB“ auf ein neu erzeugtes Stockwerk.
  - Level, Werte, Perks und EXP bleiben erhalten. Pro Stockwerk heilt die Gruppe ein Herz, Gefallene stehen mit halben Herzen wieder auf.
  - Pro Stockwerk bekommen Gegner +30 % Leben und +5 % Tempo (höchstens 1,4×), und der Boss pausiert 8 % kürzer (höchstens halb so lang). Alle zwei Stockwerke kommt ein Raum dazu, höchstens 12.
  - Das HUD zeigt „ENDLOS · STOCKWERK n“, und beim Abstieg erscheint ein Banner. Nach dem Tod wird der Lauf mit Stockwerk und Räumen zusammengefasst.
  - Der Fortschritt speichert `best_floor`; das Menü zeigt „Endlos: Stockwerk n“.
- [ ] **Live-Test mit echtem Firebase-Projekt:** Er steht aus, weil noch kein Schlüssel vorliegt.

## Test Evidence

Ausgeführt am 26.10.2026:
- `ONLINE checked=20 failures=0` (inkl. bestes Stockwerk):
  - Fortschritt aufzeichnen und zusammenführen, bereinigte Cloud-Werte
  - Firestore-Feldkodierung hin und zurück, deutsche Fehlermeldungen
  - Gast-Speicher in einem Testpfad
  - Menü: Story über Endlos, Gast-Anzeige, Version unten rechts, Hinweis bei fehlender Einrichtung
- `GAME_RULES 106` (inkl. Endlos: neues Stockwerk statt Sieg, Werte bleiben, Heilung, stärkere Gegner, Grenzen der Steigerung, Story unverändert), `FEEDBACK 27`, `PROGRESSION 48`, `DUNGEON_INTEGRATION 26`, alle ohne Fehler. Der Netzwerklauf mit zwei Prozessen bleibt PASS.
- Bilder aus dem echten Fenster: `production/qa/evidence/story-005-main-menu-accounts/01-main-menu.png`, `02-login.png`, `03-options.png`, `04-endless-floor-banner.png`, `05-endless-death.png` (Solo-Bot im Endlos-Modus: Boss auf Stockwerk 1 besiegt, Abstieg, Tod auf Stockwerk 2).
- **Nicht getestet:** echte Anmeldung, Registrierung und Speicherung gegen Firebase.
