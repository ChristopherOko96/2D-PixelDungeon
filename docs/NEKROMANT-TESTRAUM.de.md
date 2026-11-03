# Nekromant – Kampflabor

Stand: 2026-11-02. Separater spielbarer Offline-Testraum, keine Änderung der Kampagne.

Ergänzung 03.11.: Shift ist jetzt bei allen Klassen ein Dash. Aktuelle Fluchfähigkeiten und der zusätzliche `Waldmeister-Testraum.cmd` sind im [Umbauleitfaden](NEKROMANT-WALDMEISTER-REWORK.de.md) beschrieben.

## Start und Bedienung

`Nekromant-Testraum.cmd` doppelklicken oder `./scripts/Dev.ps1 NecroLab` aufrufen.
Der Raum startet direkt mit dem Nekromanten und sechs echten Gegnern.

- **WASD:** bewegen. **Auto** greift sichtbare Gegner innerhalb von acht Metern mit dem normalen Standardangriff an; beim Zielen pausiert dieser Angriff.
- **1–4:** die vier angezeigten Fähigkeiten. **R:** aktuelle Ultimate. **5/6:** Begleiterbefehle. **Shift:** Schutzfähigkeit. Die normalen Ladefähigkeiten behalten ihre vorhandene Tastenbedienung.
- Im oberen Fähigkeitsmenü eine Fähigkeit auswählen. **Rechte Maustaste halten:** Zielvorschau; **loslassen:** einmal ausführen. Auch hierbei gelten echte Seelenkosten, Abklingzeiten und Wandprüfungen. Die Vorschau für platzierte Felder verwendet dieselbe Positionsberechnung wie der Angriff.
- **DIENER / FLUCH / SEELE:** wechseln den vollständigen Trainingsbuild. Daneben lassen sich je zwei Belegungen wählen, um sämtliche aktiven Zweigfähigkeiten auszuprobieren. Zweigwechsel setzt den Kampf zurück; Belegungswechsel erhält laufende Ressourcen und Abklingzeiten.
- **Gegner +6 / Zielpuppe:** echte Gegner ergänzen, bis maximal zwölf lebende Ziele. Die Puppe hat 10.000 Lebenspunkte und greift nicht an.
- **Seelen +:** auffüllen. **Blut +4:** vier echte Blutlachen erzeugen, die der Knochenkrieger nach den vorhandenen Regeln aufnehmen kann.
- **Üben:** Unverwundbarkeit, anfangs eingeschaltet. **Ringe:** eigene Bodenmarkierungen und Ziel-/Angriffsvorschauen ein-/ausschalten.
- **Leeren:** Gegner und Geschosse entfernen. **Reset:** Kampf, Felder und Begleiter zurücksetzen, Ressourcen auffüllen und sechs Gegner erzeugen.
- **Escape:** pausieren; das obere Laborpanel verschwindet. Der Trainingsbuild bleibt fest, K/B öffnen hier keinen anderen Klassen- oder Talentbuild.

Automatische Basisangriffe, platzierbare Zielflächen, Fußmarkierungen und sichtbare gegnerische Nahkampf-/Explosionswarnungen sind die untersuchten PokéDive-Anleihen. Die eigentlichen Nekromantenangriffe, Bodenmaterialien und gegliederten Figuren verwenden die vorhandenen Spielsysteme und freigegebenen Grafiken. Es wurden keine Pokémon-Grafiken übernommen und keine neuen Akteursgrafiken aktiviert.

## Quellen und Grenzen

Kampfausschnitte aus vier Videos wurden stichprobenartig betrachtet; das ist keine vollständige Sichtung aller Videos. Beim vom Nutzer genannten Video wurde zusätzlich das verfügbare Transkript ausgewertet:

- [Nutzerreferenz: PokéDive – Pokémon trifft Cult of the Lamb](https://www.youtube.com/watch?v=ADPKIacCenk)
- [PokéDive Gameplay Español](https://www.youtube.com/watch?v=PQhFthfMzdA)
- [So Many Playable Pokemon / Dungeon Crawling ARPG](https://www.youtube.com/watch?v=SpVhPCla38k)
- [Mejora tu base – PokéDive Gameplay Español](https://www.youtube.com/watch?v=_iryXMIMcGA)

Dies ist eine bedienbare Vergleichsfläche für Kampflesbarkeit und vorhandene Animationen. Subjektive Spielgefühl-Abnahme bleibt beim Nutzer. Kein neuer Kampagnen-, LAN- oder Leistungstest wird daraus abgeleitet.

## Umsetzung und Nachweise

`assets/data/debug_necro_lab.json` enthält Raumgröße, Spawnposition, Trainingswerte, Reichweite, Obergrenze, Zweige, Belegungen und Beschriftungen. `src/debug/necro_lab_game.gd` erweitert das echte Spiel nur für diesen Startmodus. Panel und Darstellung sind getrennte Dateien. Das Labor verwendet `user://necro_lab_profile.json`, einen frischen Trainingsstand und keinen Kampagnen-Speicherslot; der normale Start bleibt unverändert.

Die gemeinsame Bodenabfrage für PoolPaint/Gas hält jetzt einen unveränderlichen Raum-Snapshot statt eines Szenenknoten-Zugriffs. Das behebt einen bei den echten GPU-Aufnahmen beobachteten Worker-Callback-Fehler nach Raum-/Buildwechseln. Normale Boden- und Wandzellen bleiben gleich.

Nachweise: `production/qa/evidence/necro-lab/README.md`. Die vier PNGs zeigen den echten Renderer in nativen 1280×720 Pixeln. Insbesondere muss der Seelenring seine fertig berechnete, hohle Bodenfläche zeigen; bloße Geisterpartikel wären dafür kein ausreichender Nachweis.
