# Prüfung des Story-Simulationstakts – 03.11.2026

Godot 4.7.2 Standard, headless, lokaler `codex_v2` auf Basis von
`cb145387b1825d2f4db63b64a4d32a9363431fda` mit dem lokalen Timing-Umbau.
Der Nutzer hat diese Tests ausdrücklich beauftragt. Profile, Einstellungen
und Speicher-Slots wurden auf eigene temporäre Pfade umgeleitet und die
Testdateien anschließend entfernt. Persönliche Räume und Audiodaten blieben erhalten.

## Ergebnis

| Lauf | Prüfungen | Fehlgeschlagen |
| --- | ---: | ---: |
| Zeitgeber isoliert | 18 | 0 |
| Neue Story-Laufzeit mit echten Szenen | 63 | 0 |
| Echte Engine-Callbacks, 15-/60-FPS-Limit | 6 | 0 |
| Alte Story-Datei als Regression-Gegenprobe | 60 | 21, erwartet |

Der neue Stand besteht damit 87 gezielte Prüfungen. Es wurden keine weiteren
Gameplay-/Netzwerk-Suites und keine langen Lasttests gestartet.

## Kontrollierte Bildzeiten

Für jede Welt werden dieselben normalen `_process`-Aufrufe mit einer Sekunde
Gesamtdauer bei 15, 30, 60, 144 und 240 FPS durchgeführt. Der Kampf läuft im
Startbereich ohne Benutzereingaben. Geprüft werden die tatsächliche Weltzeit
und eine mit 1,2 s beginnende Abklingzeit.

| Stand / Welten | FPS | Spielzeit nach einer Sekunde | Verbleibende Abklingzeit |
| --- | ---: | ---: | ---: |
| Alt, jeweils Krypta/Frostgruft/Hölle | 15 | 0,750000 s | 0,450000 s |
| Neu, jeweils Krypta/Frostgruft/Hölle | 15/30/60/144/240 | 1,000000 s | 0,200000 s |

Weitere Integrationsfälle: ESC-Pause, kein Nachholen der Menüzeit beim
Fortsetzen, 0,11 s Hitstop mit Wiederaufnahme ohne Vorspulen, reales Laden
der zweiten Etage und kein Übernehmen der alten Zeitschuld oder Ladezeit.

Die Gegenprobe verwendet den exakten alten Script-Inhalt aus `git show
cb145387:src/hell/hell_game.gd` in einer temporären Fixture-Datei. Dabei
werden die ursprünglichen Theme-Pfade der drei Szenen erhalten. Die Datei
wurde nach den Läufen entfernt. Der vorherige Hitstop wird vor dem unabhängigen
Ladetest ausdrücklich gelöscht, damit er keinen Fehler beim Laden verdeckt.

## Kurzer Echtzeitlauf

Hier ruft die Engine selbst `_process` auf. Das FPS-Limit wird gesetzt und
etwa zwei Sekunden lang reale Zeit gegen Spielzeit gemessen. Die Toleranz
von 0,1 s berücksichtigt die Abtastung an Render-Frame-Grenzen; sie ist
deutlich kleiner als der alte Verlust von ca. 0,5 s bei 15 FPS in zwei Sekunden.

| Welt | FPS-Limit | Beobachtete Frames | Reale Zeit | Spielzeit | Differenz |
| --- | ---: | ---: | ---: | ---: | ---: |
| Krypta | 15 | 31 | 2,000003 s | 2,050000 s | +0,049997 s |
| Krypta | 60 | 121 | 2,016611 s | 2,033333 s | +0,016722 s |
| Frostgruft | 15 | 31 | 2,052063 s | 2,000000 s | −0,052063 s |
| Frostgruft | 60 | 121 | 2,016592 s | 2,033333 s | +0,016741 s |
| Hölle | 15 | 31 | 2,047246 s | 1,983333 s | −0,063913 s |
| Hölle | 60 | 121 | 2,016582 s | 2,016667 s | +0,000085 s |

Das war ein headless Timing-Lauf, kein GPU-Benchmark oder sichtbarer Playtest.
Bewegung wird im isolierten Zeitgebertest durch einen konstant schnellen
Testkörper geprüft; die Integrationsfälle messen Weltzeit und Cooldown,
keine vollständige Kampfbalance oder Bewegung durch ganze Etagen.

## Offene Meldungen

Keine Script-/Parse-Fehler in den finalen Läufen. Beim Beenden der
Integrationsläufe meldet Godot jedoch Ressourcenlecks: 797 Dummy-Texture-RIDs,
2.019 ObjectDB-Instanzen und sechs Ressourcen noch in Benutzung. Alter und
neuer Script-Stand melden dieselben Zahlen. Dieser separate Befund wurde
nicht als Teil des Timing-Auftrags behoben; die Ausgaben sind deshalb
ausdrücklich nicht als vollständig fehlerfreier Gesamtstart zu bewerten.

Ein erster Unit-Aufruf mit relativem `--log-file` erzeugte eine Meldung zum
Log-Verzeichnis. Der finale Unit-Lauf mit absolutem Log-Pfad ist sauber;
die hier aufbewahrte Unit-Ausgabe stammt aus diesem korrigierten Aufruf.
Eine erste, anschließend korrigierte Legacy-Fixture verlor beim Script-Tausch
ihren Theme-Pfad; nur die korrigierte Gegenprobe ist hier dokumentiert.

## Reproduktion und Dateien

Vom Projektordner aus mit der gepinnten Godot-Konsole:

```text
godot --headless --path . -s res://tests/story_clock_test.gd
godot --headless --path . -s res://tests/story_clock_integration_test.gd
godot --headless --path . -s res://tests/story_clock_integration_test.gd -- --realtime
```

Für `--legacy` zuvor den oben genannten alten Script-Inhalt als
`tests/fixtures/story_clock_baseline.gd` schreiben und danach wieder entfernen.
Die Gegenprobe endet absichtlich mit Exitcode 1, die neuen Läufe mit Exitcode 0.

- [Zeitgeber-Ausgabe](unit.txt)
- [Integration, neuer Stand](integration.txt)
- [Integration, alter Stand](legacy.txt)
- [Echtzeit-Ausgabe](realtime.txt)
- [Quelltext-Hashes](source-sha256.txt)
- [Umsetzung und Grenzen](../../../../docs/FESTER-SIMULATIONSTAKT.de.md)
