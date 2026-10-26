# Story 011: Nebenbosse, Raum-Deko, Lava und Portal

> **Epic**: Dungeon aus Raumvorlagen
> **Status**: In Progress
> **Type**: Feature + Visual/Feel
> **Last Updated**: 2026-10-26

## Context

Der Projektinhaber hat am 26.10.2026 das Paket „Monster Nebenbosse“ geschickt, 8 Bilder:
- Bilder 5–8 waren schon im Spiel: Goblins, Orks, die Infernal-Monster und Molgrax.
- Bilder 1–3 zeigen die Infernal-Monster und ihre Angriffs-Effekte.
- Bild 4 zeigt Bodenplatten, Säulen, Deko, Lava, ein Portal und vier Dämonen-Varianten.

Seine Wahl:
- Die vier Dämonen-Varianten werden Nebenbosse.
- Deko, Lava-Pfützen und das Portal kommen gleich mit.

## Acceptance Criteria

- [x] **Schnitt:** `scripts/slice_nebenbosse_sheet.py` schneidet aus Bild 4 die 4 Dämonen (`assets/sprites/nebenbosse/`) und 20 Requisiten (`assets/sprites/props/`).
  - Entfernt wird nur der flache Hintergrund, damit dunkle Steine erhalten bleiben.
  - Die Dämonen bekommen mit `scripts/animate_orc_figures.py nebenbosse` dieselben Animationsbilder wie die Orks: Stehen, Laufen, Ausholen, Zuschlagen.
- [x] **Ein Nebenboss pro Stockwerk:** Ein normaler Raum (seeded) wird zum Nebenboss-Raum, sofern danach noch ein normaler Raum übrig bleibt.
  - Der Dämon steht allein im Raum.
  - Oben erscheint eine kürzere, violette Leiste „NEBENBOSS · NAME“.
  - Besiegt hinterlässt er immer eine Truhe.
- [x] **Vier Nebenbosse mit je 4 Angriffen und einem Ultimate** (ab 50 % Leben, danach alle 5 Züge). Alle sind schwächer als der Stockwerk-Boss.

  | Nebenboss | Leben | Angriffe | Ultimate |
  |---|---|---|---|
  | VARGOTH, DER AXTSCHLÄCHTER | 110 | Hieb mit Klingenfächer, Ansturm, Axtwurf, Stampfer | Klingenwirbel |
  | ZYRA, DIE SEELENHEXE | 95 | Hexblitz mit Leere-Feld, Suchkugel, Leere-Säule, Wirbel | Seelensturm mit Leere unter allen Helden und 2 Schattlingen |
  | KRAGGAR, DIE PANZERKRABBE | 130 | Scherensprung mit Stachelreihe, Stampfen, Steinhagel, Stachelfeld | Stachelringe |
  | AZRAEL, DER SCHWINGENTEUFEL | 120 | Feuerbrand, Sturzflug, Flammenhieb, Feuerbombe | Feuersturm |

  - Zyra hält Abstand.
  - Story: Vargoth. Endlos 1–5: Zyra, Kraggar, Vargoth, Azrael, Kraggar.
- [x] **Warnzeichen nach Angriffsart** für Mobs und Nebenbosse: Sprung- und Sprintspur, Hiebkegel, Stampfring.
- [x] **Raum-Deko je Stockwerk-Thema** (`balance.decor`: crypt, infernal, stone, orc):
  - 1–2 schwingende Wandbehänge oben (Ketten, Käfig, Banner).
  - Lose Deko am Boden (Runensteine, Knochen, Schädel, Kristalle, Totem, Spitze).
  - In Nebenboss- und Bossräumen ein Prunkstück (Altar oder Kessel).

  Die Deko ist reine Kulisse und hält Abstand zu Deckung, Türen, Startpunkten und zur Raummitte.
- [x] **Lava-Pfützen** in Kampfräumen auf Infernal- und Stein-Stockwerken. Sie glühen, Funken steigen auf, und wer drinsteht, verliert ein halbes Herz. Die übliche Unverwundbarkeit nach einem Treffer verteilt den Schaden.
- [x] **Portal:** Nach einem Endlos-Boss öffnet sich über dem Podest ein Portal.
  - Helden können sich während der Perk-Wahl bewegen.
  - Wer gewählt hat und ins Portal tritt, ist bereit. Wenn alle drin sind, geht es ein Stockwerk tiefer.
  - Der Knopf „TIEFER HINAB“ funktioniert weiterhin.
- [x] **Debug-Levelliste** um „NEBENBOSS …“ für Story und jedes Endlos-Stockwerk erweitert.

## Test Evidence

Ausgeführt am 26.10.2026:
- `GAME_RULES checked=241 failures=0`. Neu geprüft wird:
  - genau ein Nebenboss-Raum pro Stockwerk;
  - Nebenboss allein, mit Name auf der Nebenboss-Leiste und schwächer als der Boss;
  - sichere Truhe, auch bei Truhen-Chance 0;
  - jeder der 4 Dämonen nutzt alle Angriffe und sein Ultimate;
  - Deko außerhalb von Deckung und Türen, gleicher Seed ergibt gleiche Deko;
  - Lava nur in Kampfräumen, sie brennt, daneben ist es sicher;
  - Portal öffnet, wartet auf alle und führt auf Stockwerk 2;
  - Debug-Liste mit allen Nebenbossen.
- **Gegenprobe:** Mit absichtlich kaputtem Portal und ohne sichere Truhe schlagen die neuen Tests an.
- Übrige Sammlungen grün: LOADOUT 15, FEEDBACK 28, PROGRESSION 48, ONLINE 26, DUNGEON_INTEGRATION 26, DUNGEON_GENERATOR 9508.
- Netzwerk: zwei echte Peers, Seed 24680 (2 Kampfräume inklusive Boss) und Seed 84329 (5 Kampfräume inklusive Boss); 4-Spieler-Lobby. Alles PASS.
- Bilder in `production/qa/evidence/story-011-minibosses-props-portal/`: Vargoth mit Sprintspur und Äxten, Zyra mit Lava und Kessel, Kraggar, Azrael mit Lava und Deko, das Portal nach dem Boss, der Held geht hinein, sowie alle geschnittenen Figuren und Requisiten.

**Offen:**
- Die Angriffs-Effekte aus den Bildern 2 und 3 sind nicht eingebaut. Die Angriffe nutzen die vorhandenen gezeichneten Effekte.
- Ungenutzt aus Bild 4: Bodenplatten, Säulen, Torbogen und die Stachelfalle (sah zu sehr nach echter Falle aus).
