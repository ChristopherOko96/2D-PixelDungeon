# Original 32 × 32 pixel sprites

Current actors are the native32 chibi revision under `assets/actors/chibi32/`,
including the blue-green eldritch boss. [Current art and source prompts](../../docs/CHIBI32-ELDRITCH.de.md).
This directory preserves fallback/legacy material and the original quiet terrain.

The eight top-level PNGs are **32 × 32 RGBA fallback images**, generated from
[generate_pixel_assets.gd](../../scripts/generate_pixel_assets.gd). The active
renderer uses the new directional actor bank under `assets/actors/`, with
48 action sequences per character. The original idle/run/hit frames under
`0x72/`, transferred from the brother's Godot `main` at65c72a9, remain preserved
as references and fallback art. These retain their source dimensions
(for example16×28 actors) and render at integer2×. Preserve
[their license/source note](0x72/LICENSE-NOTE.md).

Current actor sources, rig, animation studio and rebuild steps:
[ACTOR-ANIMATIONS.de.md](../../docs/ACTOR-ANIMATIONS.de.md).

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

Regenerating overwrites the eight fallback PNGs, never the0x72 frames. Retain
manual fallback changes in the generator. Fire uses the supplied item animation
sheet; the live renderer includes character idle/run/hit frames and feedback.
