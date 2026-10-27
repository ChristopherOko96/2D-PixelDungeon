# Original UI atlas

`asset_sheet_ui.png` is an unchanged copy of the user-provided
`AssetSheet_UI.png` (112×144 pixels, received 25 October 2026). It is separate
from the 16×16 world tile sheets. No authorship or licence beyond the supplied
file is inferred here. Import with nearest filtering, without mipmaps.

SHA256: `755b6d9ebd0bd8c296d515a75a47fccef96ec211ee5e700a0a6da4bae2a9b41e`.

The original contains icons and frames, but no alphabet. `src/dungeon_hud.gd`
uses the source artwork and the locally bundled Pixelify Sans font, with
antialiasing disabled. See [font provenance](../fonts/README.md).
Atlas coordinates below are native pixels, not display pixels.

| Meaning | Source rectangle `(x,y,w,h)` |
| --- | --- |
| Full heart, two HP | `(36,5,9,8)` |
| Half heart, one HP | `(52,5,9,8)` |
| Empty heart | `(68,5,9,8)` |
| Warm outlined progress frame | `(38,85,68,8)` |
| Frame left/right caps | `(38,85,4,8)` / `(102,85,4,8)` |
| Repeated middle frame column | `(60,85,1,8)` |
| Empty bar colours | `(96,88,1,2)` |
| Filled bar colours | `(60,88,1,2)` |

The bar's existing example fill is covered and redrawn from the host's actual
cleared-room count. It represents floor progress, not experience points.
Hearts render at integer 2× scaling. Two HP equal one full icon; odd HP use the
actual half-heart cell. At most twelve icons fit alongside the real numeric
health, so larger maximum HP cannot overflow the HUD.

The HUD reads `players[local_peer].hp/max_hp`, `floor_index` and
`floor_map[].cleared` through `set_state(snapshot, local_peer)`. It never grants
health, changes rooms or computes combat outcomes.

`src/health_strip.gd` now composes the complete heart row as one transparent
Image. The HUD caches one ImageTexture per health/capacity/visible-icon state
and invalidates it when the source texture changes. Numeric HP and floor
progress are separate. `get_health_image()` returns the same native graphic
for export; reference images include 8/8, 7/8, 4/8, 1/8 and 0/8 health.
