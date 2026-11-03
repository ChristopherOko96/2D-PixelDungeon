# Diener / Blut-Fluch — retained evidence

2026-11-01; branch `codex/port-0x72-onto-main`. Controlled fixtures in the
actual Godot 4.7.2 Compatibility renderer. Not an earned campaign, user taste
acceptance, LAN/WAN test or load/performance measurement.

## Actual GPU animation

- `minion-animation.gif`: 361 captured game frames at 30 FPS, 12 seconds.
  Four real blood sources are deliberately provided by the fixture. They
  feed the ordinary permanent skeleton, its real gauge fills, and its large
  source-part skeleton assembles. Command 5 triggers the rigged stomp.
- `curse-animation.gif`: 241 captured game frames at 30 FPS, 8 seconds.
  Curse projectile, own mark, blood drain, Seuchenfeld, Aderfessel and ritual
  use the shared combat runtime and existing real material pools.
- GIFs are cropped to a 640×360 world detail at native scale. Full 1280×720
  GPU screenshots remain as `minion-*.png` and `curse-*.png`, including the
  companion HUD. No image-generation model drew these game screenshots.
- Source frame sequences: `minion-frames/`, `curse-frames/`. Their file
  counts and every encoded GIF frame were decoded/checked by the assembler.
- Capture source: `scripts/capture_necro_branches.gd`. It uses a controlled
  legal level-30 build, fixed empty geometry, synthetic enemy health and a
  debug protection flag. These are presentation fixtures, not earned progress.
- Assembly recipe: `output/necro-branches/assemble.ps1` (Windows PowerShell 5,
  System.Drawing, local GIF encoder). Capture log: `Logs/necro-capture-final.log`.

Viewed: blood field/partial gauge, assembly/large skeleton and attached sword,
stomp/recovery, poison field/mark/drain and large ritual. The HUD percentage is
kept clear of the 5/6 buttons with the existing native-font ellipsis helper.
The original rough HTML concept animation was not imported into the game.

## Focused checks

| Check | Result | Current log |
| --- | --- | --- |
| `necro_blood_curse_test.gd` | 37 / 0 | `Logs/necro-blood-green.log` |
| `necro_branches_story_test.gd` | 24 / 0 | `Logs/necro-branches-story.log` |
| `talent_combat_test.gd` | 358 / 0 | `Logs/necro-catalog.log` |
| `talent_pet_test.gd` | 39 / 0 | `Logs/necro-pet-regression.log` |
| `element_reactions_test.gd` | 32 / 0 | `Logs/necro-elements-regression.log` |
| `soul_leap_test.gd` | 13 / 0 | `Logs/necro-soul-regression.log` |
| `session_protocol_test.gd` | 20 / 0 | `Logs/necro-protocol-regression.log` |
| `pool_consumption_overlap_test.gd` | 3 booleans true | `Logs/pool-consumption-green.log` |

Native tests cover actual finite consumption, full form, body parts, stomp
pose, room carry, expiry, corpse spending, undead decay, actual biological
poison immunity, paid/capped healing and overkill, damage transfer, owner-only
harvesting, linked field expiry, temporary ultimate commands and cooldowns.
Hölle/Frost exercise real media and targets, friendly/hostile overlap, shared
HUD commands and the **actual DEBUG Testraum** default bar/tool availability.

Failure evidence was observed before fixes:

- `Logs/necro-blood-red.log`: missing core mechanics, 10 failed assertions.
- `Logs/pool-consumption-red.log`: consuming one overlapping pool incorrectly
  erased the still-live source (`overlap_survives=false`). The fix preserves
  separate source timing when the presentation merges their material cells.
- `Logs/necro-poison-red.log`: real friendly poison lacked its biological
  condition in the native pool tick. Magical decay and poison are now separate.
- `Logs/necro-testraum-red.log`: old DEBUG bar omitted blood drain and Frost
  still disabled the blood tool. Corrected in `story_testraum.gd`.
- A bounded local identity diagnostic also exposed StringName keys from dot
  assignment being rejected by the strict JSON manifest normalizer. Explicit
  String keys preserve the normalizer and the new data fingerprints.

Successful logs were checked for `SCRIPT ERROR`. Game/capture fixtures still
report the pre-existing teardown diagnostics (6 ObjectDB instances / 2 resources
in use); this is not claimed as clean teardown. Focused tests are distinct from
an import check, a full campaign and subjective animation acceptance.

## Two real peers

`tests/necro_blood_network_smoke.ps1` launches two owned local ENet processes.
Latest result: **both passed**:
`Logs/necro-blood/20261101-160014-c48e2eac/summary.json`.
Host and client observed partial blood, the final `blood_colossus` rig/form,
normal key-5 command and actual poison from validated client skill input.
Rule version 16, protocol 4. This is local loopback, not a two-machine LAN test.

The fixture waits for profile admission before setting its controlled builds;
an initial fixture started too early and its late profile exchange replaced the
intended curse bar. Failed evidence remains in the earlier log directories.

## Data and provenance

Current mechanics/schema and exact manual testing:
`docs/NEKROMANT-DIENER-FLUCH.de.md`.
`blood_colossus` is an independent rig definition reusing the existing
`krypta_knochenwaechter` source parts; its sword is parented to `arm_r` at the
wrist. Existing original boss art/definition and 0x72 license remain intact.
No new raster generation, actor catalog activation, commit, push or merge.

`source-hashes.json` records the final reviewed code/data fingerprints.
