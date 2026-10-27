# Stil B und unterschiedliche Klassen — Vorschlag zur Freigabe

Stand27.10.2026. **Noch nicht zur Übernahme freigegeben und nicht implementiert.**

Der Nutzer hat B gewählt: den originalen0x72-Ritter `knight_m` aus dem früheren
Godot-Stand. Entscheidend sind kleine, sparsame Pixelcluster, klare Silhouetten,
wenige flache Farbstufen und der geschlossene Visierhelm. Die zuletzt generierten
detaillierten Chibi-Figuren sind nicht die gewünschte endgültige Grundlage.
Alle späteren Helden und Monster sollen diese B-Stilsprache teilen.

## Bestätigte Spielabsicht

- **Ritter:** Schwert als tatsächlicher Nahkampfangriff. Er muss an Gegner heran;
  keine allgemeine Projektilwaffe hinter einer Schwertgrafik. Geplante Umsetzung:
  kurze gerichtete Trefferfläche, Angriffsphase und Erholungszeit, pro Schwung
  höchstens ein Treffer je Gegner, Wände und Hostprüfung gelten weiterhin.
- **Magier:** Stab als Zauberwaffe mit gerichteten Distanzzaubern. Eigene
  Zauber-/Vorbereitungsbilder und passende Trefferwirkung. Der Nutzer hat kein
  Mana-System beauftragt; kein zusätzliches Ressourcen-/Klassenmenü voraussetzen.
- **Weitere zwei Spielrollen:** sollen ebenfalls eigenständig sein; konkrete
  Waffen-/Mechanikentscheidungen werden noch nicht als beschlossen ausgegeben.
- **Perks:** müssen zum Angriffstyp passen. Projektilboni dürfen den Ritter
  nicht unbemerkt wieder zu derselben Fernkampfklasse wie alle anderen machen.
  Klassenfähigkeiten, Treffer und Schadenswerte werden auf dem Host entschieden.

## Kleine Artprobe statt neuer kompletter Serie

Ein einzelner eingebauter Imagegen-Aufruf erzeugte eine getrennte Vergleichstafel
mit Ritter/Schwert, Magier/Stab und einem Skelettgegner, je in Ruhe/Angriff.
Das ist ein Art-/Rollenentwurf, kein vollständiger Animationssatz oder Beleg für
bereits spielbaren Nahkampf/Zauberklassen. Der tatsächliche Prompt und erzeugte
Master wurden separat im Vorschauordner gespeichert:

- [Stilprobe v1](../production/qa/evidence/style-reference-review/style-b-class-proof-v1.png)
- [Exakter Prompt](../production/qa/evidence/style-reference-review/style-b-class-proof-v1-prompt.txt)

Links Ritter/Schwert, mittig Magier/Stabzauber, rechts Skelett/Schwert/Schild;
oben Ruhe, unten Aktionsidee. Die sparsame B-Pixelformensprache ist deutlich
erkennbar. Der generierte Master besitzt weiche Glow-/Hintergrundsäume und
wechselt beim Skelett zwischen den Posen die Waffenhand. Er ist deshalb eine
Freigabeprobe für Richtung/Rollen, kein direkt importfertiger Spriteatlas.
Vor Produktion sind harte Alpha, feste Waffenhand, native Raster und echte
Angriffsphasen zu sichern. Keine pauschale Animation-/Spielmechanikabnahme aus
diesen sechs Konzeptbildern ableiten. Kein weiterer Imagegen-Aufruf in diesem
Durchgang; keine Aktivierung des Entwurfs.

Originale Referenzgrafik (ohne Bildgenerierung):
`production/qa/evidence/style-reference-review/style-b-original-roles.png`.
Sie zeigt bestehende0x72-Figuren bei Integerzoom. Herkunft/Lizenzhinweis bleiben
in `assets/sprites/0x72/LICENSE-NOTE.md`. Wo passende Originalgrafiken vorhanden
sind, sollen sie bevorzugt wiederverwendet werden statt die ganze Reihe immer
neu zu generieren. Fehlende Posen/Monster gezielt nach freigegebener Probe.

## Verbindliche Übernahmeregel

Der Nutzer verlangt ausdrücklich vor der Implementierung die Frage, ob er den
konkreten Entwurf behalten möchte. B-Auswahl und Klassenwunsch autorisieren
diese kleine getrennte Vorschau, aber noch keine Aktivierung, kein komplettes
Neugenerieren und keinen Umbau der Kampflogik. Nach Vorliegen der Probe: zeigen,
gezielt nach Freigabe fragen und auf die Antwort warten.

Aktiver Katalog, aktuelle Spielfiguren, Kampfcode und persönliche Karte bleiben
während dieses Vorschlags unverändert. Die bestehende48-Animationsarchitektur,
vier Spieler,48Perks, zehn Karten/Boss10, ruhige Krypta und Lovecraft-Bossabsicht
sind Randbedingungen für eine spätere freigegebene Umsetzung.
