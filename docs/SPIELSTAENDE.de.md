# Spielstände (umgesetzt, 29.10.2026)

Wunsch: den Spielstand lokal zwischenspeichern, laden und löschen.
Entscheidungen des Nutzers: Krypta und Story-Welten (Hölle, Frostgruft) mit
eigenen Plätzen; gespeichert wird der Beginn der Etage; drei Plätze je Modus.

## Bedienung

- **Krypta:** ESC → Seite **Speichern** → Platz 1, 2 oder 3. Nur der Host (oder
  der Solo-Spieler) kann speichern.
- **Hölle und Frostgruft:** Esc öffnet dasselbe Pausenmenü wie in der Krypta (Seite
  **Speichern**); die Welt steht still, solange es offen ist. Esc schließt es wieder.
- **Hauptmenü → SPIELSTÄNDE:** Reiter KRYPTA, HÖLLE und FROSTGRUFT, je drei
  Plätze mit Klasse, Level, Etage, Datum. **LADEN** startet dort, **LÖSCHEN**
  fragt einmal nach („SICHER?“), dann ist der Platz leer.

## Was gespeichert wird

Immer der Stand beim Betreten der aktuellen Etage, nicht der Moment des
Speicherns (kein Speichern mitten im Kampf).

| Modus | Inhalt | Laden |
| --- | --- | --- |
| Krypta | Lauf-Seed, Ebene, Story/Endlos, Held des Hosts (Klasse, Leben, Perks, Klassenkarten, Fähigkeiten, Inventar, Waffe, Flüche), Team-Level und EXP, erkannte Tränke | Solo-Lauf mit demselben Seed; die Ebene entsteht neu und gleich. Mitspieler werden nicht gespeichert. |
| Hölle, Frostgruft | Etage, Klasse, alles, was das Portal mitnimmt (Herzen, Runensteine, Segen, Level, Fähigkeiten, Relikt, Karten, Talentbonus, Klon-Skill) | Die Welt öffnet auf dieser Etage mit diesen Werten. |

## Technik

- `src/save/save_store.gd`: Plätze in `user://saves/<modus>_<platz>.save`, mit Kennung
  `DELVESAVE1` und `store_var` ohne Objekte, also nur reine Daten. Fremde oder kaputte
  Dateien gelten als leer. Der Ordner ist einstellbar (Tests).
- `src/save/crypt_save.gd`: Abbild und Wiederherstellung der Krypta. `game.gd` hält
  `floor_save` beim Betreten jeder Ebene fest (`_begin_run`, `_enter_next_floor`).
  Dazu kommen `save_slot()` und `_load_save()`.
- `src/save/story_save.gd`: Abbild für `hell_game.gd` (`floor_save` in `load_floor`).
  Geladen wird über `resume`. Gespeichert wird über das gemeinsame Pausenmenü (`pause_menu.gd`).
- Menüs: `pause_menu.gd` (Seite „Speichern“), `main_menu.gd` (SPIELSTÄNDE,
  Signal `save_load_requested`).
- Test: `tests/save_slots_test.gd` (Speicher, Krypta Ebene 3 hin und zurück, Hölle Etage 2
  fortsetzen, Pause, Laden und Löschen im Hauptmenü). Belege:
  `production/qa/evidence/save-slots/` (`scripts/capture_saves.gd`).
