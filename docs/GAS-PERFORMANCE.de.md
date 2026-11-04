# Gasabfragen bei vielen Gegnern

Die gemeinsame `GasField`-Simulation prüft bei Kontakt- und Dichteabfragen zuerst
die tatsächliche Ausdehnung einer Wolke. Entfernte Wolken gelangen dadurch nicht
mehr in die Schleifen über ihre einzelnen Partikel. Das gilt für Atemluft,
Verdrängung durch Figuren, Geschossschneisen, Explosionen, Sog, Sichtweite und
räumliche Reaktionsabfragen.

## Erhaltung der Spielregeln

- Die Begrenzung umfasst die aktuellen Partikel einschließlich ihrer Radien,
  nicht nur den Ursprung einer Wolke. Verwehtes oder fortgeschleudertes Gas
  bleibt deshalb auffindbar.
- Beim Erzeugen existiert die Begrenzung sofort. Nach jedem Simulationsschritt
  wird sie anhand der verbleibenden Partikel neu gebildet. Verdrängt eine Figur
  Gas, wächst sie sofort mit: Die nächste Figur im selben Schritt sieht bereits
  die verschobenen Partikel.
- Der Sicherheitsabstand berücksichtigt auch gedrehte rechteckige
  Geschossschneisen. Kontakt an der Grenze bleibt eingeschlossen.
- Eine Atemluftabfrage wählt ihre Wolken einmal für den gesamten Probenring.
  Materialwahl, Probenanzahl, Dichteaddition, Begrenzung auf 0..1 und die
  Reihenfolge bei Gleichstand bleiben erhalten.
- Die bisherigen Formeln für Kräfte, Schaden, Verblassen, Wandkontakt und
  Zündung bleiben unverändert. Auch Partikelzahl, Zeichenstil, Simulationsrate
  und Zufallsreihenfolge ändern sich nicht.

`clouds()` liefert weiterhin eine **nur lesbare** Sicht für den Renderer.
Positionsänderungen müssen über die Feldmethoden erfolgen; direkte Änderungen
an den zurückgegebenen Partikeln würden die internen Grenzen umgehen.

## Aufwand und Grenzen

Die Vorprüfung läuft über Wolken, die genaue Prüfung nur über nahe Partikel.
Die bisher besonders teure Multiplikation aus Figuren, Atemluftproben und allen
Partikeln entfällt bei entfernten Wolken. Kleine Felder brauchen dafür keinen
zusätzlichen räumlichen Baum oder ein Raster mit laufender Umsortierung.

Stehen alle Figuren in überlappenden Wolken, bleiben die meisten Kontakte nötig.
Dann kann die Verwaltung der Grenzen etwas zusätzliche CPU-Zeit benötigen.
Die gegenseitige Abstoßung der Partikel innerhalb einer Wolke bleibt unverändert;
die aktuelle Konfiguration begrenzt eine Wolke auf 22 Partikel.

Diese Änderung senkt weder die Effektqualität noch das Gegnerlimit. Sie ersetzt
keine Messung der Darstellung, der übrigen Simulation oder des Mehrspielermodus.
Messdaten und reproduzierbare Prüfungen stehen unter
[QA: Gasabfragen](../production/qa/evidence/gas-queries/README.md).
