# Original 32 × 32 pixel sprites

Every PNG in this folder is a real **32 × 32 RGBA source image**, drawn on an integer pixel grid with a small palette. All eight images are original project assets generated from [generate_pixel_assets.gd](../../scripts/generate_pixel_assets.gd); no remote images or external art packages are required.

| Files | Display |
| --- | --- |
| `player_1.png` … `player_4.png` | Four distinct adventurer palettes, native 32 × 32 |
| `slime.png` | Native 32 × 32 |
| `boss.png` | 32 × 32 source, deliberately displayed at integer 2× / 64 × 64 |
| `torch.png` | Native 32 × 32 with renderer glow and brightness flicker |
| `floor_stone.png` | Native 32 × 32 tile, tinted for deterministic floor variation |

The renderer uses nearest-neighbor filtering. Dynamic shadows, weapon direction, the local-player marker, masonry and other chamber details are separate native drawing layers.

To regenerate, run the pinned Godot console executable from the repository root:

```powershell
Godot_v4.7.2-stable_win64_console.exe --headless --path . --script scripts/generate_pixel_assets.gd
Godot_v4.7.2-stable_win64_console.exe --headless --path . --editor --import --quit
```

Regenerating overwrites these PNGs; retain any manual sprite changes in the generator or remove the corresponding generation step first. Static character source frames are the current base; character idle and expanded fire/environment frame animation remain later polish.
