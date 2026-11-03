# Ein Seelenfeld im Lava-Stil, ohne doppelte Bodenfläche

31.10.2026. Nutzer zeigt den verbliebenen waagerechten Rand der früheren
Bildtafel und verlangt den tatsächlichen Lavafeld-Stil.

## Korrektur

- `materials.soul.style` jetzt **lava**, derselbe PoolPaint-Pfad wie beim
  Lavafeld: driftende Schollen/Krusten, helle bewegte Risse, wachsende und
  platzende Blasen, Spritzer und lokales Leuchten. Eigene bestehende
  Türkis/Violett-Farbrampe, eigene Materialkennung `soul`.
- Ein fester Geister-Crop bei Quellzeile 151 ließ in allen 24 Bildern Teile
  des alten Feldrands stehen. Die Oberkante des zusammenhängenden breiten
  Feldes wird nun pro Quellbild erkannt; der Boden inklusive Rand wird mit
  Sicherheitsabstand vollständig aus der Geisterebene entfernt.
- Die 24 Geisterbilder und ihre hellen Köpfe bleiben erhalten. Unter ihnen
  zeichnet allein der Pfützen-Renderer die Bodenfläche. Die unveränderten
  Bildtafeln/GIFs bleiben Herkunft und Fallback bei fehlendem PoolPaint.
- Keine Änderungen an Talent-Schaden, Kosten, Dauer, Reichweite oder
  autoritativer Geometrie. Lava ist hier die Darstellungsart, keine neue
  Schadensart des Seelensturms. Geteilte PoolPaint-Materialreaktionen betreffen
  die Darstellung; die Host-Elementregeln werden nicht erweitert.

## Prüfung

`soul_detail_test`: vor Korrektur 25 Fehler (Materialstil plus alle 24
verbliebenen Feldränder); nach Korrektur **91/0**, einschließlich erhaltener
Geisterköpfe in allen Bildern. `soul_field_test`: **77/0**, Animation und
Cache unverändert. Keine breite Kampfsuite wiederholt: reine Präsentation.

Sichtbarer Godot-4.7.2-Compatibility-Lauf über
`scripts/capture_mage_fireball.gd -- --soul --soul-lava`: 24 echte GPU-Bilder
in diesem Ordner, eingerichteter gültiger Talentbuild, kein gespielter Lauf.
Sichtprüfung: nur eine gerissene Bodenfläche, kein alter horizontaler
Runenrand; Geister steigen unmittelbar über dieser Fläche auf.

Logs `Logs/soul-lava-*.log`. Die bekannten user://-Shadercache- und Exit-
Ressourcenmeldungen der Fixtures bleiben bestehen; keine SCRIPT ERROR in den
erfolgreichen Test-/Capture-Läufen. Keine LAN-, Last- oder Geschmacksabnahme.
Kein Commit/Push/Merge.
