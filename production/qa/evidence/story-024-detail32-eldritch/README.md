# Story024 — native32-Chibis und Lovecraft-Boss

Aktueller Stand27.10.2026, codex_v2, Godot4.7.2 Compatibility/RX6600.

- `01-eight-actors.png`: alle acht neuen Figuren bei4× Quellpixelansicht.
- `02-animation-studio.png`: aktueller Tentakelboss in der Werkstatt.
- `03-crypt-reference.png`: neue Spieler/Gegner in der bisherigen ruhigen Krypta.
- `04-prototype-solo.png`: normaler Solo-Start, Seed42026, keine Testwerte.
- `07-eight-actors-animation.gif`: sechs ausgewählte Aktionen für alle Figuren;
  unveränderte GPU-Aufnahmen aus `frames/`, native Clipzeiten auf10ms gerundet,
 300ms Lesepause zwischen Aktionen. Keine vollständige Timing-/Stilabnahme.
- `sampling-comparison.png`: links die gewählte scharfe Punktabtastung,
  rechts die verworfene weichere Alternative; beide mit hartem Alpha.
- `independent-contact/`: unabhängige Kontrolle von1.152 ausgewählten Frames
  mit Eingangshashes, Boss-/Nekromantenfokus und schriftlichem Befund.
- `detail-red.log`, `crop-red.log`: vor Implementierung/Korrektur beobachtete
  Fehler. Grüne Logs zeigen Assets691/0, Crop33/0, Bank21.597/0, Rig8/0,
  Motion14/0, Studio1.965/0, Game38/0, Kryptaintegration127/0.
- `import.log`, `bake.log`, `gpu-capture.log`: Engineimport, tatsächlicher Bake
  und GPU-Ausführung. Import ersetzt keinen Parse-/Spieltest.

Alle128 aktiven Key-PNGs sind exakt32×32 mit64-Farben-Limit und harter Alpha.
Große Master sind getrennte Vorlagen. Spieler/NPC2×, Boss3×; Atlaszellen haben
transparentes Bewegungspadding. Ruhe, Räume,48Perks, vier Teilnehmer und Boss10
bleiben erhalten. Die infernalen Nutzerreferenzen bestimmen nur Pixeldichte.

Kein neuer LAN-, Last-, FPS- oder vollständiger Kampagnennachweis. Figurenstil
und Bewegungsgefühl bewertet der Nutzer. Kein Commit/Push/Merge.

Persönlicher Dungeon SHA256 unverändert:
B8AFDCE111E0005407E1CE0BCF4427276EFED51CC987C65099671C82701BBF16.
