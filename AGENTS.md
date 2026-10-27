# Basement Run — development notes

- Work on a feature branch (`codex/…` by default); never edit or merge directly on `main`.
- The user explicitly requested publication to `codex_v2` in the brother's
  `ChristopherOko96/2D-PixelDungeon` repository on 2026-10-25. Remote `origin`
  is this publication target. Preserve that exact branch name for this delivery.
  The earlier `v2` remote / `codex/v2` fork remains historical. Do not merge into main.
- Product scope lives in `design/game-brief.md`. The multiplayer requirement from
  2026-10-24 supersedes the original single-player exclusion. The user's later
  engine correction explicitly selects Godot and rules out downloading Unity.
- The latest user correction caps the current game at four total participants
  (host plus three clients). Eight is a future option, not the current scope.
- Start with `docs/PROJECT-REVIEW.de.md`, `docs/DEVELOPMENT.de.md` and
  `production/development-plan.md`. Distinguish historical findings, current
  implementation, verified behavior and proposed future rules.
- Engine: Godot 4.7.2 standard, GDScript, Compatibility renderer, Godot Physics 2D.
  Exact requirements: `scripts/godot-environment.json`. Entry: `project.godot`
  → `src/main.tscn`; the initial slice lives in `src/game.gd`.
- Read applicable `CLAUDE.md` files and the Godot engine references before using
  engine APIs. Existing Unity/Unreal references are historical template material,
  not a reason to install either engine or add their packages.
- Project settings: `project.yaml` and `project.godot`. Machine-specific settings:
  ignored `project.local.yaml`, `scripts/godot.local.json`, and `GODOT_PATH`.
  Never commit portable engine binaries, `.godot` caches or machine paths.
- Native network model: authoritative host with ENet high-level multiplayer,
  separate clients, up to four total players (host plus three). Prove two real
  processes first. Validate sender, ownership, input range, action rate and phase;
  never trust client damage, item grants or room completion claims.
- Local commands: `./scripts/Dev.ps1 Doctor`, `Open`, `Run`, `Host`, `Join`, `Check`, `DungeonEditor`.
  The wrapper's `Check` imports and loads scripts; it is not a gameplay test.
- Do not report a working game, passing tests or four-player performance from
  studio templates, successful import alone, or zero discovered tests. Check
  Godot output for `SCRIPT ERROR` even when its process returns exit code 0.
- Real game tests belong under `tests/`. The built-in SceneTree suite
  `tests/game_rules.gd` checks rules; `tests/network_smoke.ps1` checks real peers.
  Export builds require matching Godot export templates and a real export preset.
  No placeholder Test/Build command should pretend those prerequisites exist.
- LAN is the initial target. Internet play needs actual reachability/UDP/router
  testing or a separately implemented relay solution. No hosting service is
  implicitly configured by ENet or by these setup notes.
- Latest visual requirement (2026-10-26): restore the 32×32 world grid, nearest
  filtering and no smoothing. Keep four players distinct, enemies separate from
  friendly bullets, and combat readable in the Isaac/Vampire Survivors direction.
  This supersedes the 16×16 revision. Default rooms are896×480; individual
  templates may override world_size/play_bounds. A local smooth camera follows
  the own player with bounded mouse look in a clipped896×480 viewport at1×.
  Convert aiming through view.to_local(), never subtract a fixed screen offset.
  Keep the supplied dungeon/UI/item atlases under
  `assets/tilesets/`, `assets/ui/` and `assets/items/` intact. Current terrain
  presentation follows the latest classic-quiet override below.
  Walls need visible top caps and vertical faces in the top-down style.
  Doors follow generated exits; stairs are separate interior descents.
  The eight generated fallback PNGs under `assets/sprites/` are 32×32;
  the generator is `scripts/generate_pixel_assets.gd`. The transferred 0x72
  animation frames under `assets/sprites/0x72/` retain their original sizes
  (including 16×28 actors) and render at integer 2× on this grid. Preserve their
  license. Current room fire uses the original32px orange torch; hit effects
  may still use the supplied animation sheet.
- Art direction remains under review. Use `src/art_reference.tscn` (editor/F6)
  to inspect room, actors/effects and HUD separately. The reference is an art
  preview, not a gameplay test. `assets/data/art_style_reference.tres` controls
  presentation; preserve authoritative collision footprints while tuning it.
  User references: Brotato (corrected from Bravetail), Binding of Isaac and the
  supplied dungeon pack. See `docs/ART-DIRECTION.de.md` for sources and controls.
  Hearts are composed into one cached transparent image by `health_strip.gd`.
- User-authored rooms: `Dungeon-Editor.cmd` / `src/dungeon_editor.tscn` (F6).
  Authoring model, persistence and UI are separate. Draft JSON may be unfinished;
  only validated Apply replaces the active dungeon, with a prior backup. Never
  let Save As bypass that gate. Generator4 supports fixed
  palettes, paired door lanes and prop/stair positions. Defaults preserve the
  existing geometry. The editor publishes a room library for seeded generation;
  no fixed dungeon sequence UI. Legacy 16-pixel drafts migrate in memory on load,
  without overwriting their source files. Guide: `docs/DUNGEON-EDITOR.de.md`; authoring tests and the
  disposable-file editor integration test belong under `tests/`.
- Latest authoring revision: LEERER RAUM has no inherited furnishings. Per-room
  size is12..64 by10..48 whole32px tiles; shrinking never silently crops art.
  The cells32 palette contains280 extracted PNGs, preserving original sheets.
  Q/E rotates the brush through four quarter-turns. Painted cell IDs/rotations
  are whitelisted and persisted; solid cells contribute authoritative collision.
  Tests: free_room_editor_test, free_room_ui_test, room_camera_test and the
  synthetic two-process custom_room_network_smoke (transport, not combat).
- Superseding freeform correction: new rooms use layout_mode=freeform and full
  canvas bounds [0,0,w,h]. No automatic floor, perimeter, four entrances, stairs
  or spawn slots. Only explicitly painted floor is walkable; merged void
  rectangles are authoritative collision and never rendered as masonry.
  Floor/structure may coexist. Doors carry authored coordinates, art and side;
  generation and selected-room tests must find compatible existing ports.
  Preserve legacy rectangular templates. White/black background and grid are
  local editor presentation. Incomplete drafts can save; Apply/Test require
  complete reachable spawns/ports. Tests: freeform_model/geometry/editor_ui/render.
- Editor repair: same-cell painting deduplicates only inside a live stroke with
  the same full brush settings. Palette/rotation/collision changes must apply
  immediately, including Q/E while dragging. ERSETZEN defaults on and replaces
  visible tile/door/stair overlays atomically; off edits one explicit layer.
  Preserve spawns/fire/chest and unrelated neighboring wall cells. Raster shows
  green walkable, red/X walls, gray-hatched void using cached read-only actual
  layout occupancy. Hidden grid hides this visualization; never alter game data.
- Area editing: tool9 selects an inclusive clipped rectangle without painting;
  Ctrl+A selects the whole canvas. Palette changes preserve selection. Explicit
  replace/delete buttons and Delete/Backspace apply one batch Undo transaction;
  Escape/right-click clears only selection. Text fields, dialogs and hidden
  playtests guard shortcuts. Full replace erases both tile layers/door/stairs,
  layer-only keeps other layers. Preserve authored starts/fire/chest/outside cells.
  Do not autosave or modify a saved draft when opening it for editing.
- Live gameplay UI: centered 1x world at (192,120), compact hearts upper-left.
  Room/boss/map/party/perk/session information belongs in `pause_menu.gd` behind
  Escape. Solo menu freezes world stepping, never the whole tree; multiplayer
  menu sends neutral local input while peers keep playing. Reward selection and
  restart remain normal validated actions. Keep the lobby UI separate. Guide:
  `docs/SPIELMENUE.de.md`; pause integration and real host/client tests are under
  `tests/`. Editor canvas retains offset (32,156).
- Latest reward/typography revision: reward choices live in the independent
  translucent `reward_overlay.gd`, never inside the opaque pause panel. Both
  use the same local modal/input protections. Choice/Ready remain host validated;
  focus follows authoritative acknowledgement. `pixel_style.gd` supplies locally
  bundled Pixelify Sans to every game/tool UI. Preserve its OFL and German glyph
  coverage. New generated16px perk icons live under `assets/items/perks/` with
  originals/prompts/provenance. Guide: `docs/BELOHNUNGEN.de.md`.
- Cleared rooms remain walkable and revisitable. Perk readiness unlocks
  exploration; a nearby living player uses E at a physical exit with the living
  party gathered nearby. No automatic teleport on Ready and no reward/revive
  farming on backtracking. Boss clearance opens interior stairs to a new seeded
  floor while preserving builds. Verify this with `exploration_rules_test.gd`
  and the two/four-peer `dungeon_network_smoke.ps1`.
- Room changes use a host-authorized queue and local black fade. Freeze combat
  during the host handoff; swap the rendered room only after full black on every
  peer. Door and stairs sounds fire once per transition token. Timings, boss
  windup/recovery and death retention are data-driven in `src/data/balance.json`.
  Guide: `docs/ANIMATIONEN-UEBERGAENGE.de.md`; dedicated transition unit/session
  checks and a two-process fade observer are under `tests/`.

## Crypt candidate revision (2026-10-26)

- The user's saved room defines wall depth/joins, not a reusable room stamp.
  Both earlier generated layout batches were rejected. Never restore those
  rectangles or copied-room motifs as the accepted design.
- `crypt_generator.gd` now builds independent chamber graphs, a connected floor
  mask and deterministic complete8-neighbor contour roles. Each wall cell has
  exactly one role, with original violet art and unchanged lighting direction.
- Candidate only: `assets/data/custom_dungeons/dungeon_crypt_of_the_damned.json`.
  Dedicated `Crypt-of-the-Damned.cmd` and `Crypt-Editor.cmd`; preserve the user's
  saved draft and the normal active room library until explicit acceptance.
- The user explicitly requested no automated tests or gameplay runs for this
  revision. Only asset import and syntax-only parsing were performed. Manual
  visual/play acceptance and multiplayer validation remain outstanding.
- See `docs/CRYPT-OF-THE-DAMNED.de.md` for schema, contour roles, generated art,
  fog, seeded enemy placement and automatic reward-card entrance. Do not claim
  the visual standard or seed coverage has been accepted.

## Earlier editor/art revision (2026-10-26; material direction superseded)

- Selected-room play must work directly on the unsaved chosen layout, independently
  of library validation, neighboring ports and procedural crypt regeneration.
  Configure the game before add_child; offline preview opens no network sockets.
  Temporary starts stay in a copied layout. Return/restart preserve the draft.
- At this stage the user chose the detailed generated furniture style for all dungeon
  terrain too. Unified32px materials remap all four original terrain palettes,
  preserving exact source alpha, wall joins, cell IDs and collision. This
  supersedes retaining the old bright-purple surface colors. Preserve originals.
- Generated animation frames must never wobble entire vessels or stone/metal.
  Frame0 supplies fixed body pixels; manifest effect masks alone animate fire,
  water, light, leaves, pages or drips. Free particles may move intentionally.
- Theme dressing is grouped, with planted garden beds, book rows and memorial/
  altar arrangements, safe starts and clear center aisles. LIVING palette uses
  non-solid structure with full replacement OFF to preserve existing floor.
- No automated gameplay/unit/network tests were requested for this revision.
  Asset import, syntax and asset-presentation authoring are separate from play
  evidence. Manual acceptance remains pending. Guide: docs/CRYPT-OF-THE-DAMNED.de.md.

## Active ten-room prototype (2026-10-26)

- The user now explicitly authorized integration into the ordinary prototype.
  `assets/data/dungeon_rooms.json` is the active10-template crypt library; F5,
  Dev Run and Crypt-of-the-Damned.cmd use it. This supersedes the candidate-only
  gate above. Keep the personal source dungeon unchanged and keep backups.
- Room1 is the entrance. Rooms2–9 use distinct seeded normal templates, with
  no repeats. Room10 alone is the boss room. encounter.boss_enemies3 means
  one boss plus two normal companions, not three bosses.
- User explicitly requested actual current-game photos. A normal-game capture
  session directly opened rooms1/8/9/10 and captured raw GPU viewports plus the
 10-node map. See production/qa/evidence/current-prototype/README.md and metadata.
  Do not describe those direct loads as a completed playthrough or multiplayer
  validation. Broad unit/network/performance suites were not run.

## Historical visual correction: original pack restored (2026-10-26)

- The user explicitly REJECTED the dense generated gray stone and asked for
  the supplied original tiles / warmth of the first committed prototype.
  This supersedes the earlier unified-material preference. UnifiedSkin.active
  stays FALSE. Never re-enable that rejected skin just because its files exist.
- Supplied atlases came later than first Godot commit44c9b80. This intermediate
  restoration used their original colors. It is superseded by the quiet first-
  prototype direction below; do not restore the saturated pack as active terrain.
- All10maps remain active; original themes by template are amber,violet,rose,
  amber,moss,moss,amber,moss,rose,violet. Remap explicit cellIDs and fresh
  generator output, not merely template.theme. Boss remains only in room10.
- At that historical stage, pack-compatible props/doors/stairs replaced cold decoration.
  Living sprites keep fixed bodies and use a common2-world-pixel projection.
  Preserve all originalPNG files, saved user room, geometry/collision/editor
  and gameplay improvements. No blanket Git revert/reset or old3-room rollback.
- Guide: docs/ORIGINAL-TILE-RESTORE.de.md. Raw viewport captures under
  production/qa/evidence/restored-original-pack/ show this intermediate stage.
  Earlier current-prototype/ photos show the rejected material experiment.

## Latest override: quiet first prototype, no room dressing (2026-10-26)

- The latest user clarification selects the FIRST Godot prototype44c9b80:
  original32px slate floor (`assets/sprites/floor_stone.png`), restrained
  masonry with clear crowns/faces and warm orange `assets/sprites/torch.png`.
  This supersedes both generated cold materials and the saturated supplied-pack
  restoration. Preserve sourcePNG files and exact authored wall silhouettes.
- Active crypt rooms use `render_style=classic_quiet` and
  `decoration_enabled=false`. No furniture, decorative props, chest, reward
  pedestal, plants or background fog/motes. Keep gameplay doors/interior stairs,
  fire, actors and automatic reward cards. Add future art only in this same style.
- Preserve the personal saved dungeon, all ten active maps, their contour/
  collision logic and the boss exclusively in room10. Do not blanket revert
  the branch, remove editor tools or reduce the game to the first three rooms.
- Performance changes cache the static floor, wall rows with actor depth sorting,
  collision/navigation data and room geometry in snapshots. Prepare terrain on
  room/editor changes, not every draw; avoid repeated copies/hashes of all tiles.
  Texture caches remain local presentation data and never enter RPC layouts.
- Focused CPU profiling requested for the stutter investigation is recorded in
  Story017. It is distinct from broad unit/gameplay/network suites. A focused
  six-second visible solo garden profile reached144FPS on this RX6600 with
  frame p95=8.29ms. Manual acceptance and multiplayer load remain pending;
  this single scene is not an FPS, four-player or playthrough guarantee.
- Current implementation and outstanding acceptance: Story017 and
  docs/ORIGINAL-TILE-RESTORE.de.md. Older screenshots are historical references.

## Latest typography/display revision (2026-10-26)

- Active typography is bundled Pixel Operator8, replacing Pixelify Sans while
  preserving its historical files/license. Use native8px multiples16/24/32,
  no system fallback or font antialiasing. License/provenance live in assets/fonts/.
- Live world_clip fills the logical viewport, with1280x720 as the design base.
  canvas_items/expand preserves proportions and extends the visible area on
  other aspect ratios. Hearts/menu sit at screen edges. Camera/aim clipping,
  menu dimmers/input guard and transition black must use the actual view size.
- F11, Alt+Enter and ESC->Anzeige toggle fullscreen; ESC remains pause. Preserve
  the prior window rectangle on return. Editor authoring geometry stays unchanged.
- Long card names use a common native font size per offer; compact lobby/editor
  labels have tooltips where needed. Interactive UI over the world blocks fire
  until mouse release. Current review and next steps: docs/UI-VOLLBILD-REVIEW.de.md.
- Story018 has focused GPU/UI evidence, no new complete-run or multiplayer
  performance claim. Next are manual ten-room acceptance, client smoothing and
  version checks, then current two/four-player LAN/frame-time evidence.

## Current GameDev execution authorization (2026-10-26)

- The user explicitly requested executing all next steps from the latest GameDev
  review. Implement client snapshot interpolation and admission version/content
  checks, then verify the actual ten-room campaign and two/four real processes.
  Necessary focused logic/integration/network runs are now authorized; older
  no-test instructions applied to the earlier visual-only revision.
- The user confirmed only this PC is available. Multiple local processes and
  artificial latency/loss must be labeled local/loopback, never two-machine LAN.
  Prepare the real LAN procedure and retain its hardware-dependent acceptance.
- Preserve quiet32px art/no dressing, fonts/fullscreen, authoring, ten maps and
  boss10. Do not replace user geometry, grant test-only stats or force room clears
  and call them a played campaign. Technical runs cannot sign off user taste.

## Current GameDev implementation and evidence (2026-10-26)

- Story019 is implemented and locally verified. `session_protocol.gd` gates
  gameplay admission by bounded compatibility hello; `snapshot_interpolator.gd`
  smooths positions only, with stable entity IDs, run/floor/room/revision and
  death/teleport/fade boundaries. A cached motion validator prevents wall-corner
  blending. Pixel textures remain nearest-filtered; positional interpolation
  does not mean texture filtering. Protocol schema: docs/NETZWERK-SITZUNG.de.md.
- Story020 passed current solo/two/four-process campaigns, genuine earned-perk
  wipe/restart cases, six admission roles,190 scoped logic checks and local
  four-process100ms RTT/1% UDP-loss simulation. No combat/teleport cheats count.
  Full visible1080p four-player campaign on this RX6600 averaged143.68FPS,
  p95=8.035ms; every room combat-p95 met16.667ms. The testbot alone prewarms its
  private navigation before joining; failed cold-bot evidence is retained.
  This is one local hardware/seed measurement, not a universal FPS guarantee.
- Results, exact retained evidence and repeat commands:
  docs/GAMEDEV-UMSETZUNG.de.md. Do not redo these completed implementation steps
  from historical pending paragraphs. User has only this PC: two-machine LAN,
 30-minute LAN and subjective art/feel acceptance remain open. Future procedure:
  docs/LAN-ABNAHME.de.md. Never infer WAN readiness from local impairment.

## Latest Core-Design revision:48 perks (2026-10-26)

- User prioritizes core gameplay and defers further LAN/online/load acceptance.
  Story021 is implemented:48 original definitions in balance.json, PerkRules
  for canonical grants/derived stats/personal eligible weighted offers and
  PerkCombat for actual host-only projectile, status, conditional and guard effects.
  Catalog/schema/build examples: docs/PERKS.de.md. Do not restore the five-only pool.
- Offers are per-player in perk_offers; local UI maps to perk_options. Only the
  sender's offered index may grant a perk once. Cap repeats, exclude full-HP
  healing and unmet combo prerequisites. Exhaustion grants bounded reserve
  protection. Protocol/rules are2/2. Combat bounds live in perk_rules.mechanics.
- Keep automatic translucent cards, distinct cached32px icons at integer3x,
  Pixel Operator8 and scrollable grouped inventory under ESC. No additional HUD
  panels. Quiet room art, personal source map and ten rooms/boss10 remain intact.
- Soul-guard shields persist separately across room changes; room shields/renewal
  never farm revisits. Damage/kill credit is host-owned, secondaries cannot
  recurse, projectile budgets reserve enemy capacity, no repeated target hit
  per projectile. Reset builds only on a fresh run, preserve at floor descent.
- Focused rules/catalog667/0, actual combat100/0, UI159/0, existing rules24/0,
  exploration85/0, protocol20/0, interpolation53/0 and controlled2-process
  reward transport passed. GPU images are explicit presentation/combat fixtures,
  not earned full campaigns. Long-term balance needs user feedback; prior
  four-player FPS measurements predate this perk implementation.

## Latest visual/content standard: crypt enemy family (2026-10-26)

- User fixes current quiet crypt direction before further balance/online/load
  acceptance. Story022 adds skeleton_archer, necromancer, skeleton_guard;
  shared warm-bone/violet20-color palette,2-world-pixel blocks and original
  wobble/flash/hitstun/recoil/death feedback. Style: docs/CRYPT-ENEMIES.de.md.
- Generated36native32x48frames render at1x with two transparent bottom rows
  compensated; existing0x72actors remain2x. Do not distort their aspect ratio,
  restore goblins as the active roster or replace the quiet room materials.
  Source sheets/exact Imagegen prompts/importer: assets/sprites/crypt_enemies/PROVENANCE.md.
- Host AI locks arrow/soul aim before windup, uses recoveries, a frontal guard
  and bounded summons. At most one necromancer from room3, max2summons per caster,
  max12living enemies; boss only10 with distinct adds. Spawn boundary validates
  geometry, reachability, player/actor distance and budgets. Guard bypasses
  DoT/area/rear/stun/freeze/attack phases. Overkill uses resolved lethal surplus.
- Enemy flash masks and alpha bounds are prepared once. The updated F6
  art_reference.tscn uses current quiet materials/new actors and heart-only HUD.
  Network protocol/rules are3/3; snapshot attack/aim/blocks/summons/style/radius
  fields remain host-owned. Preserve all48perks, custom draft and ten-map geometry.
- Focused AI171/0, integration127/0, visual82/0, shield-perk4/0, existing perks100/0
  and feedback19/0; controlled two-process replication passed. GPU animation is
  a deliberate style demonstration at3x, not a played campaign/LAN/FPS result.
  Current old performance numbers predate these enemy roles. User evaluates feel.

## Latest actor animation revision (2026-10-27)

- Story023 implements the explicit request for40+ independent animation
  sequences per character, not40 frames. Eight actors have48 actions each,
  four actual directions and six frames per directed action (9,216 total).
  Four players are newly generated in the crypt family: warden/ranger/arcanist/
  lizard; three undead roles and the purple horned boss retain their identities.
  Exact source PNGs/prompts/importers: assets/actors/. Old art remains intact.
- These are articulated motion clips baked from directional key art, not48
  fully hand-drawn action sets. Head/torso/arms/weapons/legs have explicit curves.
  No hidden markers or color jitter inflate uniqueness. Boss horns use an idle
  head mask so raised hands stay with arms. Necromancer attack source remaps to
  idle to retain a consistent staff hand; generated attack original is preserved.
- Bank/index/16 atlases prepare once. Runtime sample() caches AtlasTexture
  regions, never images. Use both source anchor coordinates when drawing and
  pivot recoil at the real foot, excluding transparent padding. World pixels
  remain2x and native world grid32px. Quiet materials/no dressing remain.
- Animation-Studio.cmd / Dev.ps1 AnimationStudio / animation_studio.tscn F6
  inspect all8x48x4 tracks with pause/steps/search/tempo/zoom.35 action IDs have
  role-dependent gameplay bindings;13 are prepared. Do not claim that dodge,
  sprint or guard clips grant new player abilities. Identity survives slot reuse
  and restart. Perks and combat authority remain host-owned.
- Protocol/rules4/4 include skin/motion/hit/block/interact/run_serial data and
  legible enemy death durations0.8s/1.6s boss. No atlas/rig data goes over RPC.
  Bank21597/0, motion14/0, rig8/0, gameintegration38/0, Studio1966/0 GPU,
  foot-anchor GPU10/0 and controlled2-process replication passed. Static
  independent review covered1152 selected frames and corrected two visible
  defects. User feel/style acceptance remains open; no new LAN/load/FPS claim.
- Preserve the personal draft hash and ten-room/boss10 campaign. Source and
  scope: docs/ACTOR-ANIMATIONS.de.md; evidence Story023. No commit/push/merge.

## Latest accepted scope:32px chibis and eldritch boss (2026-10-27)

- Story024 supersedes the Story023 actor appearance. User first requested more
  detail with64px examples, then explicitly corrected to32×32 and cuter chibi
  proportions. Final active art uses big readable heads/eyes, short visible legs
  and chunky hands/boots. Never restore the adult intermediate art as current.
- The three supplied hell references demonstrate pixel density ONLY. Do not
  copy their infernal palette/materials/room or redesign the quiet crypt from
  them. Existing32px terrain, warm torches/no dressing and user geometry stay.
- All128 active key PNGs are exactly32×32, under assets/actors/chibi32/keys/.
  High-resolution source sheets/exact Imagegen prompts are preserved separately
  in chibi32/source/. Native sprites render at2x; the larger boss at3x. Movement
  padding makes atlas cells larger without changing native actor resolution.
- Boss is now Der Schläfer der Tiefe, a blue-green Lovecraft-like tentacle
  creature with jade eyes and folded fins, replacing the purple/red horned demon.
  This explicitly overrides the prior preserve-boss-identity instruction.
  Boss remains exclusively10, with identical combat stats/patterns. Display
  name now comes from balance.boss.display_name rather than a hardcoded label.
- Importer uses16 complete alpha silhouettes, not fixed quarter-sheet crops;
  common per-actor scale,64-color palettes with bright/jade reserves, hard alpha
  and fixed foot baseline31. Existing48x4x6 tracks per actor remain. The new
  stable casting art needs no historical Attack->Idle remap. Boss has per-actor
  head/waist rig overrides to keep face tentacles together. Baker supports a
  separate candidate catalog before activating a revision.
- Assets691/0,crop33/0,bank21597/0,rig8/0,motion14/0,Studio1965/0,Game38/0,
  cryptintegration127/0 passed; import/parse/GPU preview observed. Independent
  static review covered1152 selected frames with no blocking new anatomy/crop
  defects. No user art/timing sign-off or new LAN/FPS claim follows from this.
- Current directions/rebuild/schema/evidence: docs/CHIBI32-ELDRITCH.de.md.
  Adult candidates live inactive under assets/actors/detail32/; old Story023
  catalog/art remain for provenance. Active visual_revision is
  crypt_chibi32_eldritch_v1. Four players/48perks/ten rooms and personal draft
  SHA256 B8AFDCE111E0005407E1CE0BCF4427276EFED51CC987C65099671C82701BBF16
  remain intact. No commit/push/merge in this revision.

## Latest user art-review gate (2026-10-27)

- User rejects the current main-player appearance, is only partly satisfied
  with monsters, and requests ALL heroes and monsters in the original knight's
  style. This supersedes treating Story024 art as the desired final direction.
- User explicitly requires asking whether to KEEP a concrete art candidate
  BEFORE implementation. Do not activate another actor catalog, overwrite
  active sprites, or bulk-regenerate the roster without this art-review step.
  First settle the intended reference, then a small separately saved style
  proof, then explicit user approval before adopting it. Avoid repeated whole-
  roster generation costs. No new image generation until the reference/limited
  proof is authorized. A reference choice is not approval to activate art.
- Two exact existing references are shown in
  production/qa/evidence/style-reference-review/ritter-vergleich.png:
  A=44c9b80 assets/sprites/player_1.png (32x32),
  B=2adbc07 assets/sprites/0x72/knight_m_idle_anim_f0.png (16x28).
  These were extracted from local Git bytes and rendered with integer zoom;
  no Imagegen call or active game-art change was made for this comparison.
- User has now confirmed B, the original0x72 knight (not A). They also explicitly
  require unique gameplay roles: knight MUST use a sword in actual melee;
  wizard MUST cast spells through a staff. These are distinct combat behaviors,
  not color/weapon-image variants of the same crossbow shooter. No mana system
  or exact other-two-class mechanics were requested. Perks must respect attack
  type; retain host-authoritative damage and wall checks when later implemented.
- B confirmation authorizes the promised limited style proof, not implementation.
  One Imagegen comparison board has been prepared with knight/sword, wizard/staff
  and a skeleton enemy, idle/action. Reuse existing B assets where suitable to
  avoid unnecessary roster regeneration. Review docs/STYLE-B-CLASS-PREVIEW.de.md.
- Concrete pending proof: production/qa/evidence/style-reference-review/
  style-b-class-proof-v1.png with the exact saved prompt alongside. One
  Imagegen call only, no active art/combat implementation. It is a style/role
  concept, not production-ready native art: soft glows and a skeleton hand swap
  require correction before production. Do not silently import this board.
- Obtain approval of the small concrete candidate before implementation. Keep existing48 animation tracks,
  Lovecraft boss intent, quiet crypt, four-player cap,48perks and custom map.
  This approval gate originates directly from the user's latest request.

## Codex studio integration

- This game already exists. Read `docs/codex/runtime.md` before applying studio
  workflows or roles. Do not restart onboarding or replace the selected engine.
- Read applicable nested AGENTS.md and `docs/codex/path-rules.md` before editing.
  Apply indexed rules only to files matching their original path patterns.
- `.agents/skills/studio-*/SKILL.md` adapts shared `.claude/skills/` workflows;
  `.codex/agents/studio-*.toml` adapts shared role briefs. No model or permission
  overrides are installed. Use tools actually supported by the current runtime.
- Use the documented project.yaml/local-override/rigor resolution. Claude shell
  preprocessing is not automatically executed; explicitly run the reviewed
  config helper when a source workflow requires it.
- Exclude AGENTS/CLAUDE instruction files and instruction-only directories from
  game-content counts. `tests/template/` and `studio-tests/` are studio tooling,
  not evidence of implemented or tested gameplay.
- Edit generated files through their sources or scripts/sync_codex.py, then
  regenerate. Preserve custom files and this root AGENTS.md. Start and check
  commands are documented in `docs/codex/README.md`.
- Prefer `$studio-help` or a focused existing-game task. Global model, trust and
  permission changes are outside this setup.
