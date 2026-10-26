# Firebase einrichten (Konten und Online-Fortschritt)

Das Spiel spricht Firebase direkt über die REST-Schnittstellen an und braucht dafür weder ein SDK noch ein Plugin. Ohne Einrichtung läuft es als **Gast**, und der Fortschritt wird nur lokal gespeichert.

## 1. Firebase-Projekt anlegen
1. <https://console.firebase.google.com> öffnen und ein Projekt anlegen. Google Analytics ist nicht nötig.
2. **Authentication → Anmeldemethode → E-Mail/Passwort** aktivieren.
3. **Firestore Database → Datenbank erstellen**: Produktionsmodus wählen, Region z. B. `europe-west3` (Frankfurt).
4. **Firestore → Regeln**: Den Inhalt von [`firebase/firestore.rules`](../firebase/firestore.rules) einfügen und veröffentlichen. Danach darf jedes Konto nur sein eigenes Dokument `users/{uid}` lesen und schreiben.

## 2. Schlüssel eintragen
1. **Projekteinstellungen → Allgemein**: Dort stehen die **Projekt-ID** und der **Web-API-Schlüssel**. Erscheint dort noch kein Schlüssel, unter „Meine Apps“ einmal eine Web-App (`</>`) hinzufügen.
2. `firebase.example.json` im Projektordner zu **`firebase.local.json`** kopieren und die beiden Werte eintragen:
   ```json
   { "api_key": "AIza…", "project_id": "basement-run-12345" }
   ```
3. Das Spiel neu starten. Im Hauptmenü oben rechts auf **ANMELDEN** klicken und **KONTO ERSTELLEN** wählen.

`firebase.local.json` steht in `.gitignore` und kommt nicht nach GitHub. Der Web-API-Schlüssel ist kein Geheimnis im engeren Sinn, denn er steckt in jedem ausgelieferten Spiel. Geschützt sind die Daten durch die Firestore-Regeln, nicht durch den Schlüssel.

Für ein exportiertes Spiel kann die Datei alternativ als `firebase.json` im Benutzerordner liegen (`user://`, unter Windows `%APPDATA%\Godot\app_userdata\Basement Run\`).

## 3. Was gespeichert wird
- **Dokument `users/{uid}`:** `runs`, `wins`, `deaths`, `kills`, `bosses`, `best_level`, `total_exp`, `best_rooms`, `play_seconds`, `updated`.
- **Lokale Kopie:** `user://progress_<uid>.json`, für Gäste `progress_guest.json`.
- **Abgleich:** Beim Anmelden werden lokale und Online-Werte zusammengeführt, jeweils der größere Wert gewinnt. Nach jedem Lauf wird beides gespeichert.
- **Angemeldet bleiben:** Ein Refresh-Token liegt verschlüsselt in `user://session.cfg`. **ABMELDEN** löscht ihn.

## Grenzen
- Der Spieler schreibt seinen Fortschritt selbst, also kann er ihn manipulieren. Für Bestenlisten bräuchte es eine Prüfung auf dem Server, z. B. Cloud Functions.
- Bisher gibt es nur E-Mail und Passwort. Google-Login und „Passwort vergessen“ sind möglich, aber noch nicht gebaut.
