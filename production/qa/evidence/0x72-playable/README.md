# Nachweis: spielbare 0x72-Krypta (27.10.2026)

Aufgenommen aus dem echten Spiel im Fenster mit
`godot --path . --resolution 1280x720 -s res://scripts/capture_crypt_0x72.gd -- <Ordner>`
(Seed 4242). Der Held ist für die Aufnahme unverwundbar; die Gegner handeln
selbst. „Inszeniert“ heißt: Der Held oder ein Gegner wurde für das Bild an eine
Stelle gesetzt.

| Bild | Inhalt |
|---|---|
| `01-kryptaraum-dunkel.png` | Krypta-Raum im 0x72-Stil: Boden, Ziegelwände, Bannerreihen, Fackeln, Kerzensäulen, Gitter vor dem Seitenausgang im Kampf; Dunkelheit mit Lichtkreisen; zerlegte Skelette. |
| `02-teile-abgeschlagen.png` | Inszeniert: Einem Schildskelett wurden Dolch und Bein abgeschlagen. |
| `03-leerenbomber-zuendet.png` | Inszeniert: Ein Leerenbomber zündet neben dem Helden (schwillt an, blinkt). |
| `04-leerenbomber-platzt.png` | Die Leeren-Explosion (violetter Ring). |
| `05-ebene3-moderkoloss.png` | Etage 3, letzter Raum: der Moderkoloss mit Boss-Balken (Held inszeniert in der Nähe). |
| `06-leerenrufer-strahl.png` | Etage 10: der Leerenstrahl aus dem Auge, er erhellt den Raum (Held inszeniert in der Nähe). |
| `07-leerenrufer-beschwoerung.png` | Beschworene Skelett-Bogenschützen um den Leerenrufer, ein Bomber fliegt heran. |

Nicht abgedeckt: echtes Mehrspieler-Spiel über zwei Rechner (der Host-Ablauf und
die Snapshot-Felder sind in `tests/crypt_bosses_test.gd` und
`tests/session_presentation_test.gd` geprüft).
