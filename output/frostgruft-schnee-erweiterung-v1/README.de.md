# Frostgruft – Schnee-Erweiterung v1

Dieses Paket **erweitert** das vorhandene Frostgruft-Set. Keine bestehende
Datei wird ersetzt. Alle Varianten verwenden die unveränderte Grundgrafik aus
`assets/sprites/frost/` und ergänzen ausschließlich Schnee am Fuß sowie – bei
geeigneten Objekten – kleine Schneeauflagen auf Oberkanten oder Schädeln.

## Inhalt

- `assets/props/`: Fässer, Kisten, Urnen, Tische, Bank, Regal, Schädelobjekte,
  Geröll und Kandelaber.
- `assets/structures/`: Altar, waagerechte/senkrechte Mauer sowie zwei
  Schädelmauer-Varianten.
- `preview/`: Übersicht aller enthaltenen Einzelgrafiken.
- `manifest.json`: Herkunft und Behandlung jeder PNG-Datei.
- `source-reference/`: zusätzliche generierte Schnee-Formreferenz und der
  genaue Prompt. Diese Referenz ist kein Ersatz für die spielbereiten PNGs.
- `build-package.ps1`: reproduzierbarer, verlustfreier Aufbau aus den
  vorhandenen Projektassets.

## Technische Eigenschaften

- transparente PNGs mit harter Alpha-Kante;
- Nearest-Neighbor-kompatibel, keine Glättung;
- vorhandene 3-Pixel-Blöcke und Farbpalette bleiben erhalten;
- additive Dateinamen mit `_snowfoot`;
- keine Godot-Importdateien und keine Änderung an aktiven Tilesets.

Die Canvas-Abmessungen sind bewusst etwas größer als die Originale, damit der
Schnee rund um den Fuß nicht abgeschnitten wird. Beim Einbau daher den visuellen
Versatz beziehungsweise den Fußanker ausgleichen; die ursprüngliche Kollisions-
und Navigationsfläche sollte unverändert bleiben.

## Erstellung

Vom Repository-Stamm aus:

```powershell
./output/frostgruft-schnee-erweiterung-v1/build-package.ps1
```

Die Schneeform orientiert sich an der vom Nutzer gelieferten Vergleichsgrafik
vom 30.10.2026. Die Grundobjekte stammen aus dem vorhandenen Frostgruft-Set.
