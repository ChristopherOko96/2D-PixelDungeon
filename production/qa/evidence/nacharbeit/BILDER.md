# Bilder zur Nacharbeit L1–L7 · Delve Disaster

**Datum**: 2026-11-01 · **Build**: Arbeitsstand `codex_v2` (uncommitted) · **Engine**: Godot 4.7.2, Fenster 1280×720, Compatibility
**Vorher-Bilder**: `production/qa/evidence/umsetzung/` (08d, 01c, 11, 12) und hier die Dateien mit „-vorher“

## Methode
Eine temporäre SceneTree-Probe (`scripts/_tmp_nacharbeit_probe.gd`, danach gelöscht) mit `--fixed-fps 60`, festem Seed,
festen Zufallsgeneratoren der Welt, fester Zielrichtung (`aim_at`) und ruhiger Kamera (`camera_calm`, ohne Vorlauf zur echten Maus).
`settings_path` und `graphics_path` = `user://settings_test.cfg`, Profil `user://profile_test.json`; beide sind gelöscht.
Zwei Läufe mit demselben Code ergeben 0 abweichende Pixel. So sind Vorher und Nachher derselbe Moment.
Dateien mit „-zoom“ sind 3×- (L1) bzw. 2×-Ausschnitte (L2).

## Pixelvergleich Vorher / Nachher (ganzes Bild 1280×720)
| Bild | abweichende Pixel | Erklärung |
|---|---|---|
| l1-krypta-held-verdeckt | 1353 | Röntgenbild des Helden über den Skeletten (~1250 px) und die Flasche im leeren H/G-Feld (L5, ~100 px). Sonst gleich. |
| l2 0,05 s | 92011 | Bodenblitz, Staubwolken, Splitter, Risse; der Bodenblitz hellt kurz den Raum auf (Licht über `story_glow`). |
| l2a 0,15 s | 16054 | Risse laufen aus, Staubwolken, Splitter |
| l2b 0,6 s | 20304 | dicke glühende Risse, Staub setzt sich, Splitter liegen |
| l2c 2 s | 13997 | abgekühlte dunkle Risse, Grus am Boden |

## Bilder
| Datei | Punkt | Was zu sehen ist | Urteil |
|---|---|---|---|
| l1-krypta-held-verdeckt(-zoom).png | L1 / A3 | 3 Skelette stehen vor dem Helden. Wo ihre Körper ihn verdecken, liegt seine Silhouette in Gold (72 %) mit dunkler 1-px-Kontur über den Knochen. Wo er frei ist, bleibt er unverändert. | ok |
| l1-krypta-held-verdeckt-vorher-zoom.png | L1 | derselbe Moment vorher: nur der helle/dunkle Ring, der Held selbst ist hinter den Schädeln verschwunden | Vorher |
| l1-frost-held-verdeckt(-zoom).png | L1 | Frostgruft: dasselbe auf Schnee mit Frostskeletten (der Held steht auf einer Druckplatte des Rätsels) | ok |
| l2-krypta-boss-einschlag-0_05s(-zoom).png | L2 / A10 | Knochenwächter, 0,05 s nach dem Stampfer: Bodenblitz, Staubballen, Splitter fliegen | ok |
| l2a-krypta-boss-einschlag-0_15s(-zoom).png | L2 | Die Risse sind ausgelaufen, der Schockwellenring, Staubballen | ok |
| l2a-krypta-boss-einschlag-0_15s-vorher-zoom.png | L2 | vorher: Funkenring und dünne blasse Risse | Vorher |
| l2b-krypta-boss-einschlag-0_6s(-zoom).png | L2 | Dicke verzweigte Risse (3 px nahe am Einschlag, dann 2 und 1) mit glühendem Kern, dunkle Ränder; Staub verweht, Splitter und Grus liegen | ok |
| l2b-krypta-boss-einschlag-0_6s-vorher-zoom.png | L2 | vorher: kaum noch etwas zu sehen | Vorher |
| l2c-krypta-boss-einschlag-2s(-zoom).png | L2 | Die Risse sind abgekühlt und dunkel, die Delle bleibt | ok |
| l5-frost-inventar.png | L5 | Das Inventar beginnt unter der Heldenleiste und endet über „MANA“: LAUFSTUFE ist frei | ok |
| l5b-frost-schnelltrank-leer.png | L5 | Leeres H/G-Feld mit gedimmter Flasche. Der Hover-Text (nicht im Bild, die Probe bewegt die Maus nicht) erklärt: Trank kommt von selbst, Heiltrank zuerst, Rechtsklick im Inventar, H trinken, G werfen | ok |
| l6-krypta-lauftalente-lebensgrenze.png | L6 | Lauf-Talente bei 18/18 LP: EISERNE HAUT gedimmt mit „LEBEN VOLL“; beim Überfahren steht der Grund ausgeschrieben unten | ok |

## Nicht im Bild geprüft
- L3 (Ausholzeiten der Rigs), L4 (perfekter Block gegen Geschosse), L6 (Riesentresor-Meldung) und L7 (Siegelwerte der Krypta) sind Regeln und Zahlen. Sie sind durch Tests belegt.
- Die Kamera-Erschütterung „slam“ beim Stampfer ist unverändert und auf einem Standbild nicht zu sehen.
