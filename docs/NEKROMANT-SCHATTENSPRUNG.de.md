# Schattensprung und fünf Sekunden Seelenfelder

01.11.2026. Der bisherige Seelensprung (`soul_7`, Seele-Zweig) heißt auf
Nutzerwunsch Schattensprung. Aktuelle Werte: 6/8/10 m Reichweite nach Rang,
0,65 s Sprungzeit, 48 Weltpixel Bogenhöhe (Storywelten skalieren die Höhe).
16 Seelen und 15 s Abklingzeit bleiben erhalten. Der einmalige Schaden von
60 % am Absprung bleibt bestehen. Kein zusätzlicher Schaden über die Spur.

Der Host bewegt den Bodenpunkt entlang der kollisionssicheren Strecke.
Wände begrenzen das Ziel und jede Bewegungsphase; es ist kein Hindurchspringen
durch Wände. Keine neue Unverwundbarkeit oder geänderte Kollisionsfläche.
Tod/Raumwechsel/Buildwechsel beenden den Sprung. Andere aktive Angriffe warten
auf die Landung; normale Bewegung verändert die festgelegte Sprungstrecke nicht.

Die Darstellung hebt Körper und Stab gemeinsam an. Der vorhandene Nekromanten-
Rig wird auch für den spielbaren Helden verwendet: Kutte und Kapuze bewegen
sich getrennt, die Kutte zieht sich zusammen und der Stab schwingt mit. Der Schatten
bleibt am Boden. Keine neue Figur oder neu generierter Actor-Katalog.

Nach der Landung bleibt **fünf Sekunden** eine zusammenhängende, 1,1 m breite
Seelenspur zurück. Die Oberfläche nutzt das gleiche Material wie Seelenfeld
und Seelenring. Sie folgt einer echten Kapsel entlang der Sprungbahn; das
umgebende Rechteck wird nicht gefüllt. Geister steigen mit eigenen Kopf-/Körper-/
Schweif-Rigs auf. Normale Gegner auf der Spur teilen sich die bestehende
Festhaltesperre: 0,45 s, frühestens alle 1,6 s. Bosse sind immun.

Seelenring und gesetztes Seelenfeld bleiben jetzt ebenfalls **fünf Sekunden**.
Der Ring behält 10 m Außendurchmesser, 2 m breiten Saum und Rückstoß.
Spur und andere Seelenfelder dürfen sich als ein Material verbinden; die Mitte
des Rings wird weiterhin nicht vom Ring selbst gefüllt.

**Testen:** Testraum → Nekromant → Seele anwenden. 1 Seelenblitz, 2 Seelenring,
**3 Schattensprung**, 4 Seelenfeld, R Wächter (5/6 unverändert). Die bereits
umgesetzte aufladbare Seelenlanze bleibt gelernt und kann im Talentmenü auf
einen der vier aktiven Plätze gelegt werden. Aktuell liegt der Fokusplatz 3
auf dem neu überarbeiteten Sprung.

Neue Snapshots enthalten nur Sprungalter, Dauer und Höhe für die Figur sowie
die begrenzte Feldspur; keine Rig-/Texturdaten. Regeln/Protokoll: 15/4.
Prüfungen und aktuelle Aufnahmen:
[Sprung-Nachweis](../production/qa/evidence/soul-leap/README.md).
