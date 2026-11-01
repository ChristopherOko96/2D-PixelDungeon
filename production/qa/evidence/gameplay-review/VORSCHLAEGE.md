# Vorschläge zur Freigabe · Delve Disaster

Stand 2026-11-01. Grundlage: drei Prüfungen von heute.
- `production/qa/evidence/polish/POLISH.md`: 29 Bilder, 26 Befunde
- `production/qa/evidence/gameplay-review/MECHANIK.md`: Literatur und Entwicklerquellen
- `production/qa/evidence/gameplay-review/BALANCE.md`: Zahlen aus den Daten

Dazu kommt die Item-Bewertung `BEWERTUNG.md`, die schon umgesetzt ist.

Jeder Punkt hat eine Kennung. Du kannst ganze Pakete oder einzelne Punkte freigeben.

Korrektur zum Mechanik-Bericht: Er schreibt, es gebe kein Ausweichen ab Stufe 1. Das stimmt nicht: Jede Klasse hat von Anfang an Shift. Der Bogenschütze rollt (2 Ladungen, 0,4 s unverwundbar), die anderen drei blocken (2 Treffer). Punkt B3 ersetzt darum den dortigen Vorschlag M1.

---

## Paket A · Feinschliff (sicher, ändert keine Regeln)

| ID | Was | Warum | Aufwand |
|---|---|---|---|
| A1 | Der Frostgruft-Schneesturm liegt unter der UI statt über Talentfenster, Inventar und Karte | Der Schnee zieht durch alle Fenster (Polish #1) | S |
| A2 | Nekromanten-Stab: Pfad korrigieren (`assets/sprites/items/staff_necro.png` existiert, `sub_kit.gd` lädt `0x72/items/…`) | Der Nekromant hat keine Waffe in der Hand (#2) | S |
| A3 | Der Held ist immer lesbar: Gegnerwaffen hinter dem Helden zeichnen, bei Verdeckung eine dünne Kontur; die Skelettschwerter auf Körpermaß bringen | Der Held geht im Getümmel unter (#3) | M |
| A4 | Frostgruft-Kontrast: Bodenhelligkeit senken, dunkle 1-px-Kontur für Held und Gegner | Weiß auf Weiß (#4) | S–M |
| A5 | Talentfenster mindestens 16 px, „5“ und „S“ eindeutig | 9–11 px Schrift, „S0 Gold“ (#5) | M |
| A6 | Gift, Eis, Explosion, Blut, Lava und Knochenteile als Pixelmaterie mit Körnung und Alpha, Gegner im Gas sichtbar | Gezeichnete Flächen verdecken Gegner (#6, #10); Ziel Elementphysik | M |
| A7 | Großbuchstaben Ä/Ö/Ü in der UI-Schrift reparieren | „RüSTUNG“, „HAUPTMENü“ (#7) | S |
| A8 | Begriffe vereinheitlichen: Laufstufe / Heldenstufe überall erklärt, „Inventar“ statt „Rucksack“, „1 Talentpunkt“, „Steige …“ | Uneinheitlich (#8, #22) | S |
| A9 | Steuerung: F (Rüstungskraft) ergänzen, breitere Wertespalte | F fehlt, Texte brechen (#9, #18) | S |
| A10 | Boss-Ansage lesbar: rot gefüllter Ring mit Lade-Rampe, beim Einschlag Staub und Risse | Dünne weiße Ringe (#11) | S |
| A11 | HUD ruhiger: feste Höhe des Heldenpanels, Minimap deckend, Abstand der Kamera zur unteren Leiste, „SH“ als Shift-Symbol mit Klartext | Springt, schimmert durch, verdeckt (#12–#15) | S |
| A12 | Treffer-Feedback: 2–3 Frames Weißblitz auf Gegnern, KRIT mit 16 px und kurzem Aufploppen | Schwach (#17, #24) | S |
| A13 | Kleinkram: Strahlen an Wänden kappen, Fundmeldungen zusammenfassen, Pausen-Fokus auf der aktiven Seite, LAUF-Kopf nur einmal | #16, #20, #21, #23, #25, #26 | S |

## Paket B · Faire Kämpfe (Mechanik, mit Belegen)

| ID | Was | Beleg | Wirkung | Aufwand |
|---|---|---|---|---|
| B1 | Vorwarnzeiten in die Daten: Nahkampfhieb 0,35 s → 0,5 s, Bolzen 0,45 s; das Ziel friert bei 60 % der Vorwarnung ein | Krypta und Hölle 0,35 s mit Nachzielen, Frostgruft 0,6–0,7 s. Reaktion ~250 ms plus Weg. Quellen: Dead Cells „fairness tricks“ (80.lv), Telegraph-Leitfaden (bugnet), Reaktionszeit-Studie (Carleton GI 2025) | Treffer fühlen sich verdient an; alle drei Welten gleich fair | S |
| B2 | Höchstens 3 gleichzeitige Angreifer (Angriffsmarken, Nah- und Fernkampf getrennt) | 9 Skelette ergeben ~7 Angriffe pro Sekunde. Das Prinzip „attack tokens“ nutzen viele Action-Spiele (K) | Große Räume bleiben fordernd, aber lesbar | M |
| B3 | Perfekter Block / perfekte Rolle: Shift im Moment des Treffers (Fenster 0,15 s) lässt den Angreifer taumeln (Schwertkämpfer, Magier, Nekromant) bzw. gibt einen Konterbonus (Bogenschütze) | Belohnt Timing statt Halten (Sekiro, Hades-Dash, K). Ersetzt M1 aus MECHANIK.md | Mehr Können-Tiefe ohne neue Taste | M |

## Paket C · Balance (Zahlen, aus BALANCE.md)

Alle Werte sind Startwerte für einen Spieltest; sie stehen danach in den Daten und lassen sich nachstellen.

| ID | Was | Alt → neu | Warum |
|---|---|---|---|
| C1 | Boss-LP (alle drei Welten) | 46/60/90/105/120/160/175/190/240/340 → 115/150/225/260/300/400/440/475/600/1200 | Bosse fallen in 7–21 s, Ziel 30–60 s (Hüter) bzw. 60–120 s (Endboss) |
| C2 | Gegner-LP-Zuwachs je Etage als Datenwert | 0,16 → 0,30 (neuer Schlüssel statt Code) | Die Kurve wird nach hinten flacher statt steiler |
| C3 | LP-Obergrenze des Helden | 24 → 18 | Späte Etagen sind sonst zu sicher |
| C4 | Verfolger schneller | Skelett 140→175, Zombie 150→180, Eiszombie 110→140, Frost-Eiszombie 90→120, Eisschleim 100→125 | Weglaufen ist trivial (dein Wunsch: „leicht unfair“) |
| C5 | Bogenschütze stärker | Bogenschaden 1,0→1,25; Gezielter Schuss [1,5/1,75/2,0]→[2,6/3,0/3,4]; sniper_3 [1,15/1,35/1,55]→[1,8/2,1/2,4] | Im Raum am schwächsten, der Talentschuss bringt nur +5,5 % |
| C6 | Schwertkämpfer etwas schwächer | Schaden 2,5→2,3, Reichweite 150→125 | Dominiert mit 1,64× der Nekromanten-DPS |
| C7 | Nekromant schneller | Abklingzeit 0,42→0,38 | Niedrigste DPS |
| C8 | Heldenstufen-Kurve | levels.base 50→65 | Stufe 30 nach ~2 Läufen statt der geplanten ~3 |
| C9 | Eliten zäher | Kettenschinder 16→22, Skelettwache 9→12, Eisritter 8→11 | Fallen in 2–4 s statt 5–10 s |

Empfehlung des Balance-Berichts für den ersten Test: C1 + C2 + C3 + C5 + C6 (+ C4).

## Paket D · Tiefere Entscheidungen

| ID | Was | Beleg | Aufwand |
|---|---|---|---|
| D1 | Dämonensiegel als echte Wahl: zwei Segen zur Auswahl, ein sicherer Preis | Heute ist der Erwartungswert immer positiv, also keine Entscheidung (Sid Meier „interesting decisions“, K) | M |
| D2 | Seitenräume zeigen an Tür und Karte, was dort wartet (Truhe, Siegel, Schale) | Erkunden mit Erwartung statt Zufall (Hades zeigt Türbelohnungen, K) | M |
| D3 | Element-Reaktionen lesbar und belohnt: Symbol am Reaktionspunkt, kleines Lexikon in der Pause, +25 % EXP für bewusste Reaktionen | Systemische Chemie wirkt nur, wenn sie lesbar ist (Breath of the Wild, GDC 2017) | M |
| D4 | Begleiter angleichen: Falke 0,8→0,95 s, Bär 1,3→1,4 und sein Brüllen bindet Gegner | Falke ~1,44 DPS gegen ~1,0, der Bär hat keine Rolle | S |
| D5 | Segen deckeln: Tempo höchstens ×1,3, Reichweite höchstens ×1,6 | Unbegrenzt stapelbar | S |
| D6 | Eigene Schwierigkeitskurve je Welt (Krypta sanft, Frostgruft mittel, Hölle steil) | Heute sind alle drei zahlenmäßig gleich | S–M |

## Paket E · Größere Schritte (Entscheidung nötig)

| ID | Was | Hinweis |
|---|---|---|
| E1 | Lokale Lauf-Messung: Todesursache, Schaden je Angriff, Boss-Dauer und Reaktionen in eine Datei pro Lauf | Damit lassen sich alle Werte oben mit echten Zahlen nachstellen (Slay the Spire, GDC 2019: Balance aus Metriken). Nur lokal, nichts geht ins Netz |
| E2 | Meisterleiter nach dem Sieg: freiwillige Erschwernisse mit Belohnung | Wie Hitze (Hades) oder Aufstieg (Slay the Spire); gibt Gründe für weitere Läufe |
| E3 | Etappen-Start: nach einem Sieg darf ein neuer Lauf auf Etage 3 oder 6 beginnen | Weicht deine Regel „Tod = Zone von vorn“ (29.10.) auf, deshalb nur auf deinen Wunsch |
