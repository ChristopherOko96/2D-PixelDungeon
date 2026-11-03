# Fluchnekromant / Waldmeister – 03.11.2026

Realer Godot-4.7.2-Compatibility-Renderer, native 1280×720-Aufnahmen. Die Szenen sind kontrollierte Trainings-/Darstellungsfixtures, kein gespielter Kampagnendurchlauf.

## Funktionsprüfungen

| Suite | Checks/Fehler | Log unter Logs/ |
| --- | --- | --- |
| Fluch im Umkreis, vier Dash-Klassen, Zielbindung, direkte Ulti, Passive/Knochenwelle | 29/0 | necro-forest-green.log |
| Waldmeister-Fallen, Scharfschaltung, Hindernisse und echtes Feuerfeld | 7/0 | forest-traps-green.log |
| Würmer, echte Körperteil-HP, verzögerte Landung, große Felder, Quellengrenze, Wände, Tod und Ablauf | 13/0 | forest-worms-green.log |
| Native Masken, vollständige eindeutige Pixelzuweisung, achtteilige Rigs, Aufsteigen, Iconcache und Fallengelenke | 27/0 | forest-necro-art.log |
| Waldmeister-Labor: offline, getrenntes Profil, sechs Belegungen und echte Ulti | 11/0 | forest-lab.log |
| Vorhandenes Nekromanten-Labor | 22/0 | necro-forest-lab-regression.log |
| Vorhandener Vollblut-/Verwandlungszyklus | 25/0 | necro-forest-blood-cycle.log |
| Direkter Koloss, einmalige Beschwörung, Befehle, echte Leichen, Knochenball | 57/0 | necro-forest-giant.log |
| Gesamter bestehender Talent-Kampfkatalog | 361/0 | necro-forest-talents.log |
| Shift-Ladungen/Unverwundbarkeit/Erholung und Begleiter | 28/0 | necro-forest-defense.log |
| Unveränderliche Worker-Bodenabfrage, dünne Wand und Raumgrenzen | 6/0 | forest-floor-snapshot.log |

Zusammen **586 gezielte Checks ohne fehlgeschlagene Assertion**. Neue Anforderungen wurden vor der Implementierung rot beobachtet: `necro-forest-red.log` 8/25 fehlgeschlagen, `forest-traps-red.log` 2/3, `forest-worms-red.log` 1/2. Alte Erwartungen an Blocks, Todes-Beschwörung und Geisterwölfe wurden auf den ausdrücklich geänderten Regeln aktualisiert.

Die erweiterte Wurmprüfung zeigte zunächst echten Feldschaden hinter einer schmalen Wand. Diagnose: Räume ohne bemalte Bodenzellen lieferten der vorhandenen Flüssigkeitsphysik eine uneingeschränkt offene Fläche. Host-Poolabfrage und unveränderlicher Render-/Partikel-Snapshot berücksichtigen jetzt auch exakte Raumgrenzen und Hindernisrechtecke. Vorher in der Werkzeugausgabe: `in=true blocked=true`, danach im finalen Log `in=false blocked=true`. Keine Testgrenze gelockert; die Schadensfreiheit hinter der Wand wird weiter tatsächlich geprüft.

## Lokale Replikation

`tests/necro_blood_network_smoke.ps1` verwendet zwei echte lokale ENet-Prozesse mit normaler Eingabe für R/5/6. Die anfängliche Fixture erwartete bei der nun raumweiten Begleiterjagd zwingend einen vollen Blutbalken vor R. Aktuelle Spielregel erlaubt die Aktivierung bereits ab 50 Blut; die Transportassertion prüft nun diese unveränderte Mindestschwelle, gespeichertes Blut bis zum Tastendruck und anschließenden Abbau. Vollblut-Speicherung bleibt zusätzlich durch den eigenen Zyklustest abgedeckt. Ein verworfener Versuch mit unnötig riesigen Testquellen lief in ein Zeitlimit; normale Quellen wurden wiederhergestellt.

Finale Nekromantenrunde: `Logs/necro-blood/20261103-112114-fbf73637/summary.json`. Zusätzlich prüft `tests/forest_worms_network_smoke.ps1` beide neuen Wurmarten, beide großen Materialien, Spuckereignisse, lokale Rig-Auflösung und normale R-Eingaben beider Besitzer: `Logs/forest-worms/20261103-112958-a1a562a2/summary.json`, zwei Prozesse bestanden. Ein anfänglich zu früh gestarteter Wurm-Testaufbau wurde um dieselbe Profil-Austausch-Wartephase wie die vorhandene Nekromantenfixture ergänzt; die fehlgeschlagene Runde bleibt erhalten. Alle Runden sind lokale Loopback-Fixtures, keine Zwei-Rechner-LAN- und keine Leistungsabnahme. Finale Quell-Hashes stehen in `receipt.json`.

## GPU-Sichtung

`scripts/capture_necro_forest.gd` erzeugt zehn Bilder:

1. `01-aufsteigende-flueche.png`: mehrere markierte Gegner mit bestehenden, aufwärts bewegten Fluch-Rigs.
2. `02-knochenkern.png`: bezahlter Ladezustand, Energie und einströmende Knochen an der Stabposition.
3. `03-knochenspur.png`: geriggte Kugel und Spur im Flug.
4. `04-knochenburst.png`: echte Treffer-/Knochenfragmente.
5. `05-knochenwelle.png`: unmittelbar gerufener Koloss und sein 5-Befehl.
6. `06-seelenring.png`: freier Innenraum und vorhandenes äußeres Seelenmaterial.
7. `07-wuermer-spucken.png`: zwei freigegebene, tatsächlich geriggte Begleiter.
8. `08-wuermer-felder.png`: echte große Flüssigkeitsquellen und vorhandene Elementreaktionen.
9. `09-geriggte-falle.png`: acht bewegliche Fallenzähne plus Hub.
10. `10-waldmeister-baum.png`: neue Belegung, Beschreibungen und native 48-Pixel-Icons. Explizite Maximalrang-Darstellungsfixture, kein verdienter Build.

Log: `Logs/necro-forest-capture.log`, keine finale `SCRIPT ERROR`. Bekannte Teardown-Diagnose: sechs ObjectDB-Instanzen/zwei Ressourcen bei einzelnen Game-Fixtures, neun/zwei beim kombinierten GPU-Programm mit Talentfenster. Keine Behauptung vollständiger Speicherfreigabe.

Der Starter `Waldmeister-Testraum.cmd` wurde über den echten Dev-Wrapper gestartet; sein Fenster wurde in der Windows-Inventur gefunden. Die native Zugänglichkeitsansicht war beim Live-Versuch nicht verfügbar, ein anderes Vollbildspiel lag davor; es wurde nicht angeklickt oder verdrängt. Sichtprüfung daher anhand der echten GPU-Fixtures, keine behauptete manuelle Spielgefühl-Abnahme.

## Art-Freigabe

`worm-concept-v1.png`: konkreter Imagegen-Vergleich. Nutzerantwort: **„Ja, beide so übernehmen“**. Danach zwei Produktionsquellen erstellt; alle drei exakten Prompts, Herkunft, Import und native Auflösung in `assets/sprites/companions/forest_worms/PROVENANCE.md`. Die native Originalgrafik, die ruhige Krypta und die persönliche Karte wurden nicht ersetzt. Kein Commit/Push/Merge.
