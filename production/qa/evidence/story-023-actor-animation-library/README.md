# Story023 — Figuren und Animationswerkstatt

Stand27.10.2026, Branch codex_v2, Godot4.7.2 Compatibility/RX6600.

- `01-eight-actors.png`: acht Figuren,4× effektive Quellpixel.
- `02-animation-studio.png`: Werkstatt mit pausiertem Hauptangriff.
- `03-crypt-reference.png`: Figuren im ruhigen Stilreferenzraum.
- `04-prototype-solo.png`: echter normaler Solo-Start, Seed42026, ohne Cheats.
- `05-foot-anchor-regression.png`: tatsächlicher GPU-Test mit farbigen
  Fußmarkern; Scale/Lean/Offset und Legacyanker.10/0 nach3Renderfehlern.
- `06-boss-preview-6x.png`: großer Boss bleibt im Clip-Bereich der Werkstatt.
- `07-eight-actors-animation.gif`: sechs beispielhafte Abläufe für alle acht
  Figuren; unveränderte GPU-Aufnahmen aus `frames/`, nur als GIF codiert.
  Native Clipzeiten auf10ms gerundet,300ms Lesepause zwischen Aktionen.
- `independent-contact/initial/` und `current/`: statische Vorher-/Nachher-
  Prüfung von1.152 ausgewählten Frames mit Eingangshashes. Krallen und Stab
  korrigiert; übrige Frames nicht pauschal visuell abgenommen.
- `two-process-summary.json`: kontrollierter lokaler Replikationsvergleich,
  keine gespielte Kampagne, kein LAN auf zwei Rechnern oder Performancebeleg.
- RED-/GREEN-Logs behalten konkrete Fehlschläge und erfolgreiche Prüfungen.
  Der Import ist zusätzlich vom Parsecheck zu unterscheiden.
- `capture_actor_animations.gd.txt` und `encode_actor_preview.py.txt` sind
  Quellen der technischen Aufnahme/Encodierung; Artquellen bleiben in assets/actors/.

48 eigenständige Bewegungsclips pro Figur entstehen aus generierten
Richtungs-Keyposen und separaten Körperteilkurven. Das sind keine48 vollständig
handgezeichneten Aktionssets.35 IDs besitzen rollenabhängige Spielanbindungen,
13 sind für spätere Mechaniken vorbereitet. Nutzer beurteilt Art und Timing.

Bank21.597/0; Motion14/0; Rig8/0; Gameintegration38/0; Studio1.965/0 bzw
GPU1.966/0; Fußanker10/0; Host/Client2/0. Bestehende fokussierte Regressionen
sind in den jeweiligen Logs und der Story aufgeführt. Keine neue FPS-Freigabe.

Persönlicher Entwurf SHA256:
B8AFDCE111E0005407E1CE0BCF4427276EFED51CC987C65099671C82701BBF16.
Keine Raum-/Materialüberarbeitung und kein Commit/Push/Merge.
