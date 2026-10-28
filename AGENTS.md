# Basement Run — development notes

- Work on a feature branch (`codex/…` by default); never edit `main` directly.
- The user explicitly requested publication to `codex_v2` in the brother's
  `ChristopherOko96/2D-PixelDungeon` repository on 2026-10-25. Remote `origin`
  is this publication target. Preserve that exact branch name for this delivery.
  The earlier `v2` remote / `codex/v2` fork remains historical.
- 2026-10-27, user decision: codex_v2 BECAME main. It was merged into main with
  "our version wins" (a merge commit with main's 357d509 as first parent and the
  codex_v2 tree as content; no force push, the brother's commits stay in the
  history). Unported main features (Firebase login, deferred balance keys) are
  only in the history. From now on: keep working on codex_v2 and bring it to main
  only when the user asks.
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

## Feature decisions: merging main into the target design (2026-10-27)

Recorded with Claude Code after comparing `origin/main` (brother, up to 357d509)
with `codex_v2` (1c3ed6b). This is the agreed TARGET design, not implemented
yet: main's features are NOT merged into codex_v2. Where this section conflicts
with earlier sections or `design/game-brief.md`, this section wins. The art
approval gate above still applies to every new actor/boss art.

- Dungeon per floor: Isaac-style branching, loop-free room tree (main's generator
  idea), treasure room, minimap. Rooms come from the user's editor / crypt room
  library, so templates must expose compatible door ports per side. Replaces the
  fixed linear ten-room chain.
- Doors: a player presses E at an open door and goes to a waiting screen
  ("waiting for party", countdown). Others have ~10 s (data-driven in
  balance.json) to press E themselves; when all have pressed or the timer ends,
  the host moves everyone and the next room loads for all at once. Replaces both
  "E with party gathered nearby" and main's "walk through and drag the party".
- Modes: Story = 4 worlds x 10 floors = 40 floors, once downwards. Endless is a
  separate main-menu mode that mixes the worlds with rising difficulty.
- Worlds change every 10 floors. Floors 1-10: undead only (no demons, orcs or
  goblins). Then main's worlds (stone, orc, infernal) with their enemies,
  decor and lava. Exact world order after the crypt is still open.
- Bosses: not every floor has a boss. Stronger/elite enemies may appear on any
  floor; roughly every 3rd floor a mini-boss (larger HP bar, special moves);
  floor 10 of each world has the big boss. Crypt mini-bosses are NEW undead
  designs (main's demon mini-bosses belong to other worlds). Crypt big boss is
  now Der Leerenrufer (void creature from the user's sheet, user decision
  2026-10-27: void beam, necromantic magic, summons skeleton archers); Der
  Schläfer der Tiefe is parked for later. Use main's phase/telegraph/ultimate
  boss framework.
- Crypt decor: light decor is now allowed (main's crypt set: chains, bones,
  skulls, altar in boss rooms). Supersedes "quiet first prototype, no room
  dressing"; quiet 32px materials and warm torches otherwise remain.
- Classes: main's swordsman (melee sword cone), archer (bow) and mage (staff,
  exploding orbs) with main's 0x72 figures. Lizard is a later 4th class.
  Duplicate classes per party are allowed. Replaces the four look-only
  player skins.
- Skills: each class has 4 active skills on keys 1-4, cooldowns only, no mana.
  Left click stays the basic attack. Key 1 is available from the start; keys
  2/3/4 unlock at levels 3/6/10. Key 4 is always the class ultimate (long
  cooldown). Pattern: 1 main skill, 2 ranged/area, 3 movement, 4 ultimate.
  All 12 skills, their values and level-up perks are agreed with the user in
  `docs/KLASSEN-FAEHIGKEITEN.de.md` (source of truth, values = starting points):
  swordsman Wirbelklinge / Klingenwelle / Ansturm / Rage;
  archer Salve / Ballistapfeil / Rückwärtssprung / Pfeilfaust-Schuss;
  mage Feuerball / Kettenblitz / Blinzeln / Fusionsmagie: Photoneneis (5 s channel).
  The three ultimates are the user's own designs; keep their core behavior.
  Level-up pool also contains main's passive class perks. Skill damage scales
  as a multiple of weapon damage; one shared crit system (Rage + Präzision).
- Progression: EXP orbs and level-ups (main). A level-up offers class perks
  that modify that class's skills (e.g. 2 fireballs instead of 1); keys 1-4
  pick the offered card. Bosses drop a general perk (e.g. more skill damage,
  faster attacks). NO perk cards after normal rooms any more. The existing 48
  perks are to be re-sorted into general boss perks and class skill modifiers;
  projectile-pattern perks must not be offered to melee.
- Chests: treasure room holds a guaranteed large chest; normal rooms keep main's
  small chance of a small chest (run-only stat boosts).
- Keep from codex_v2: dungeon editor, animation studio, art reference, ENet
  session protocol/interpolation, ESC pause menu, Pixel Operator 8, fullscreen.
  Take from main: main menu (story/endless, options, debug level list), boss
  phases/ultimate and HP bars, newer feedback/VFX, EXP, classes, chests.
- Still open: floors without a boss - what sits in the farthest dead end
  (stairs down?); whether mini-bosses also drop a general perk; how level-up
  cards on 1-4 interact with casting skills while the offer is open; world
  order after the crypt; whether main's Firebase accounts are wanted.
- Integration method (user decision): NO big `git merge origin/main`. A test
  merge-tree showed 14 conflicting files (game.gd ~2150 conflict lines,
  balance.json, dungeon_view.gd, generator, vfx, tests). Base stays codex_v2;
  port main's features module by module, keeping the game playable and tested
  after every step. The brother keeps working on main: after each step, fetch
  origin/main and port new commits too. Ported from main up to: 357d509.
- Implementation order (user approved):
  0 prep: copy main's standalone modules (player/progression, player/loadout,
    combat/abilities, ui/hud, main_menu, newer vfx), sprites/monster art, and
    merge balance.json key by key, without wiring;
  1 main menu with story/endless frame and debug level list;
  2 classes + basic attacks (sword melee, bow, staff) with main's 0x72 figures;
  3 EXP + level-ups (cards on keys 1-4), remove per-room perk cards;
  4 skills 1-4 per docs/KLASSEN-FAEHIGKEITEN.de.md, shared crit system:
    all key-1 skills, then 2+3, then ultimates;
  5 Isaac floors from editor rooms, door timer + waiting screen, minimap,
    treasure room + chests;
  6 floor structure: 40 floors, worlds every 10, mini-boss ~every 3rd floor,
    boss on 10, endless mode, main's boss phases/worlds/enemies/decor, crypt decor;
  7 new art via the art gate (Schläfer 0x72, undead mini-bosses), boss perks
    from the 48, level curve retuned for 40 floors.
- Step 0 DONE (2026-10-27, uncommitted): copied unchanged from origin/main
  357d509, NOT wired: src/player/{progression,loadout}.gd, src/combat/abilities.gd,
  src/ui/hud.gd, src/main_menu.gd, src/online/progress.gd, tests
  progression_test/loadout_test, 44 missing 0x72 images (skelet, necromancer,
  tiny_zombie, imp, weapons, hearts, chest), sprite folders golem/infernal/
  nebenbosse/orcs/props, 5 slicing/animation scripts, main's stories 002-011 in
  production/epics/main-port/ (reference only). Firebase (account.gd, firebase.gd,
  config, rules, .gitignore entry) deliberately NOT copied - decision pending.
  balance.json: only main's 24 NEW top-level sections added; existing local
  values unchanged. DEFERRED to the wiring steps: main's 37 keys inside existing
  sections (boss.name/move_pause/sequence/ultimate - boss.name would rename the
  local boss because game.gd reads definition.name first; rooms.min_count/
  max_count/enemies_min/enemies_max/shooters_max; attacks.* for main's enemy
  kinds) and 6 differing values kept local (bullet.max_count 48 vs 140,
  boss.hp 70 vs 160, boss.hp_per_extra_player 24 vs 60, death.duration 0.8 vs
  0.45, death.boss_duration 1.6 vs 1.2, perks text punctuation). Checks: Godot
  import 0 errors, new scripts parse, progression 48/0, loadout 15/0,
  game_rules 24/0, perk_rules 667/0. Not a gameplay run (nothing wired yet).
- Step 1 DONE (2026-10-27, uncommitted): the game opens on main's title screen
  (src/main_menu.gd, adapted: Pixel Operator 8 sizes 16/24/32/64, inherits the
  game theme, centered on any canvas, skeleton/necromancer chasers, account row
  hidden without an account, hero choice skipped while class_order is empty,
  Endless shown disabled "ENDLOS · BALD" until step 6, fullscreen applied via
  game.toggle_fullscreen, shake via dungeon_view.shake_scale). Story = solo run
  of the current crypt; Mehrspieler = existing lobby (solo button hidden, new
  HAUPTMENÜ button); every ended session returns to the menu; CLI sessions and
  the editor preview skip it. Debug list: crypt rooms 1..N (earlier rooms marked
  cleared) and floor 2. Bug fixed: the port field read "7777.0" (JSON float),
  so _port() returned 0 and solo/story could not start outside tests; regression
  test watched failing first. Tests: main_menu_flow_test 20/0; pause_menu_test's
  leave check now expects the main menu. Evidence: production/qa/evidence/
  main-menu-step1/ (scripts/capture_main_menu.gd, real windowed run).
- Test repair (2026-10-27, uncommitted): five suites failing in committed
  1c3ed6b were OUTDATED TESTS, not game bugs, and now pass:
  pause_menu 26/0 (reward cards open automatically since Story021; Escape now
  hides/reopens them), reward_cards 20/0 (font is Pixel Operator 8; cards show and
  grant personal perk_offers), dungeon_integration 23/0 (ten rooms, boss last,
  per-template 32 px sizes, seeded crypt spawns checked for clear cells and
  spawn_min_distance), session_presentation 20/0 (WORLD_SIZE == DESIGN_SIZE; boss
  and stairs in the final room; the 'rect' SCRIPT ERROR came from the test passing
  an empty exit), dungeon_editor_integration 32/0 (reads the fixed four-template
  fixture tests/fixtures/dungeon_rooms_rect4.json instead of the live crypt
  library; preview check now expects no socket at all - OfflineMultiplayerPeer).
- STILL FAILING, also identical in 1c3ed6b, not yet analysed: dungeon_generator
  17 (16x "authored floor is fully connected for boss-sized actors", 1x "normal
  room obstacles differ"), dungeon_ports 48 (west/east door meets wall),
  editor_tile_replacement 2 (legacy pillar fixture), freeform_geometry 2 (boss
  test, compatible ports), editor_grid_render 2 (green/red overlay not visible,
  GPU). The four *_render tests are GPU tests: run them WITH a window
  (`--path . --resolution 1280x720 -s ...`); headless they wait forever.
  Windowed: actor_render_anchor 10/0, freeform_render 4/0, walkability_render 3/0.
  All other 40 suites pass headless.
- Step 2 DONE (2026-10-27, uncommitted): hero classes and basic attacks.
  src/player/hero_class.gd applies balance.classes/weapons and sets the PERK BASE
  (damage, speed, shot_interval, max_hp), so all 48 perks still stack on top.
  default_class = archer equals the old player values (unchanged for tests/CLI).
  Swordsman: perk_combat.melee() - cone reach 64 / arc 2 rad, wall-checked,
  same modifiers and hit path as shots (crit, elements, on-hit perks). Mage:
  orbs 380 px/s, 1.5 s, splash 40 px at half damage via perk_combat.splash()
  whenever the orb ends (hit, wall, flight time); not budget-limited. Archer:
  bow == old shot. 11 perks carry `projectile_only` and are never offered to
  melee players (user decision): piercer, ricochet, scatter, twin, backshot,
  sidewinder, homing, orbit, longshot, echo, split. Class choice: solo via the
  menu hero cards (16 px layout), multiplayer via the lobby button "< NAME >"
  (host-validated "class" action, lobby phase only, own player only).
  game.player_classes survives run restarts, cleared on leave/disconnect.
  Rendering: classed players use main's 0x72 figures (knight/elf/wizard) with
  weapon sprites, sword swing crescent from the snapshot swing counter, colour
  ring per player; chibi actor bank stays for enemies and unclassed actors.
  Bullets: player "arrow" = 0x72 arrow sprite, "magic" = emerald orb. New "swing"
  sound. RULESET_VERSION 4 -> 5. Tests: hero_class_test 24/0, main_menu_flow
  22/0. Evidence (STAGED scenes): production/qa/evidence/hero-classes-step2/.
- Art approval (user, 2026-10-27): activating main's existing 0x72 figures
  (knight, elf, wizard) as the three class figures in step 2 is APPROVED.
  Chibi32 art stays in the repo, inactive. This approval covers only these
  existing figures; new generated art still needs the style-proof gate.

## Art direction: everything in the 0x72 style, part-rigged (2026-10-27)

- User request: heroes, ALL enemies and the crypt tiles must match the main
  menu's 0x72 DungeonTileset II look. Smooth, many animations (display refresh,
  60/144 Hz). Later combat: break body parts piece by piece (skeletons), aim at
  boss parts (part HP sums to total HP; head = instant death; destroyed arm
  disables its attack; parts may regrow). Art first, combat after approval.
- Chosen approach (user): original 0x72 pixels, each figure split into parts and
  animated per frame (cutout rig), plus other packs in the same style for props.
  Small 0x72 figures have NO visible arms (knight/necromancer/skeleton): their
  breakable parts are weapon, legs, torso and head; real arms exist on big
  figures (big_zombie). Missing roles (skeleton archer/guard, undead mini-bosses)
  are kitbashed from pack parts; Der Schläfer der Tiefe has no template.
- Style proof, NOT approved yet, nothing wired into the game: production/
  art-proof/0x72-style/ (README there), review page
  https://claude.ai/artifact/75dUCYWVttCgPT5eE6UMHg (F1-F4 figures, R1 room,
  P1 props). APPROVED by the user on 2026-10-27 ("F1-F4, R1, P1: Ja"):
  the 0x72 part-rig look, breakable parts and the room rendering are the
  accepted direction. Next: the complete set (all heroes, all enemies incl.
  mini-bosses and boss, all crypt rooms/props) as a second review before
  anything is imported into the game.
- Complete set built (2026-10-27), WAITING for per-item review:
  https://claude.ai/artifact/R4sftXCTQZFXXN4VQhdYAZ (H1-H4 heroes, K1-K6 crypt
  enemies, N1-N3 mini-bosses Moderkoloss/Frostleiche/Knochenkoloss = big_zombie
  palette swaps, B1 Der Schläfer der Tiefe = NEW pixel art from sleeper.json with
  procedural breakable/regrowing tentacles, W1-W3 later-world 0x72 enemies
  auto-split, R1-R10 all rooms of seed 4242, P1 props). Kitbashed: skeleton
  archer (skelet + bow, string drawn per frame), skeleton guard (skelet + knife +
  NEW 9x11 shield). Sources/scripts: production/art-proof/0x72-style/README.md.
- Boss swap (user, 2026-10-27): B1 is now Der Leerenrufer, the black void
  creature from the bottom-left of a sheet the user sent
  (production/art-proof/0x72-style/sources/user_sheet_void.png, 8 frames).
  The Schläfer (tentacle boss) is parked: sleeper.json and its code stay, it is
  just not shown. make_void.gd cuts the frames, aligns them on their centre of
  mass and adds a ragged veil (the sheet cuts the figure off at the bottom);
  void.json holds the new parts (claws, 3-state void eye, soul-skull
  projectile). Moves: Leerenstrahl (eye beam, warning line, slow tracking,
  stops at walls), Seelensalve (3 soul skulls from the front claw), Beschwörung
  (2 skeleton archers rise from void pools, max 4, crumble with the boss).
  Parts: core 90 vital, eye 20 (only open during the beam; no beam while lost,
  regrows 12 s), front claw 15 (no salvo), back claw 15 (no summoning), claws
  regrow 8 s. Shown on the same review page (version 2). Sheet origin and
  licence are UNKNOWN. On 2026-10-27 the user decided to push everything to the
  public repo anyway, including this sheet, the dungeontiles-extended torches
  and the built review pages (production/art-proof/0x72-style/out/ is now
  tracked). Clarify or replace them before the game is released.
- Licences: 0x72 DungeonTileset II = CC0. dungeontiles-extended (torches,
  candle columns), "16x16 dungeon ii wall reconfig", the fan sheets and the
  Enchanted Forest / Fantasy RPG NPC packs in the user's download folder have no
  licence note; clarify before committing any of them to the repo.
- The user's reference folder moved to `C:\Users\Cylor\Desktop\Sprite Sheet 0x72`
  (same contents). On 2026-10-27 the user sent the 0x72 pack's sample map as the
  target look for rooms (dark grey outside, columns, banner rows, arched doors,
  wall fountains).

## Playable 0x72 crypt (2026-10-27, user-approved plan, one push)

- Scope: the review set is now in the game for crypt floors 1-10. W1-W3
  (later worlds) and the lizard stay preview-only.
- Rigs: `assets/data/rigs.json` is generated from the review page by
  `production/art-proof/0x72-style/export_rigs.js` (never edit by hand);
  `src/rig/rig_library.gd` cuts parts (shared instance), `rig_poses.gd` is the
  1:1 port of the page's POSES, `rig_renderer.gd` draws rigs, debris, beams,
  pools and void effects from snapshot fields only.
- Body parts (host, `src/combat/body_parts.gd`): part HP = weight share of the
  enemy's max HP. Every hit counts fully against the total HP (big hits stay
  lethal); the hit part breaks when its own HP is gone; a broken vital part
  kills at once; lost parts disable "attack"/"cast"/"block"/"beam"/"summon";
  legs slow (0.6 / 0.35), a skeleton torso 0.7; regrow returns half HP.
  Projectiles hit the part whose rest-pose pixels they cross (precise test after
  a broad phase); melee/splash/area hit the nearest part; statuses pick a seeded
  part. The Leerenrufer's eye is only hittable during its beam.
- Roster and floor plan (balance.json `enemy_roster`): skeleton, shield
  skeleton, archer, necromancer, tiny/ice zombie, Leerenbomber (fuse, burst
  radius 72, 2 damage; shot down = harmless pop). Final rooms per 10-floor cycle:
  3/6/9 mini-bosses (Moderkoloss/Frostleiche/Knochenkoloss: slam + roar ring),
  10 Der Leerenrufer (`src/combat/void_boss_ai.gd`, balance `void_boss`: beam,
  salve, summon archers + bombers, max 4), other floors a strong group of 6.
  `balance.boss` is now the Leerenrufer ("rig": "void"); the old radial burst
  only remains for unrigged bosses.
- Dark crypt (`src/vfx/darkness.gd`, `assets/shaders/canvas_vfx_darkness.gdshader`,
  balance `lighting`): live runs only. Player radius 150, torches 120, beam,
  pools, bursts, magic shots light up.
- 0x72 rooms (`src/crypt_0x72_art.gd`): live crypt rooms are baked with the
  review rules plus the sample-map look (dark grey outside, columns on single
  obstacle cells, banner pairs, lava wall fountains, arched doors on north/south
  exits closed during combat, bars across side exits). Editor and previews keep
  the classic look. Debug list: floor 3/6/9 mini-bosses and floor 10 Leerenrufer.
- Snapshot: enemies carry rig, lost, exposed, beam, miniboss, summoned,
  exploded; root `fx_events`. RULESET_VERSION 6.
- Tests: rig_library, body_parts, crypt_bosses (+ updated main_menu_flow and
  session_presentation). Evidence: production/qa/evidence/0x72-playable/.

## Sound pass (2026-10-27)

- Recorded effects replace most synthesized beeps. Table:
  `assets/data/audio_sfx.json` (event -> source, variants, volume_db, spread,
  pitch, min_interval, max_seconds; rig -> material bone/flesh/void). Files:
  `assets/audio/sfx/<event>_<n>.wav`, cut by `scripts/prepare_sfx.js` from the
  user's folder `C:\Users\Cylor\Desktop\Sound Pixel Combat` (Pixel Combat
  files hold 6 takes every 4 s). Godot imports them as QOA.
- `src/vfx/sfx.gd` picks a random variant (never twice in a row), throttles
  fast hits and falls back to the synthesized sounds for unknown events.
  `src/vfx/feedback.gd` maps snapshot changes to events: material hits/kills/
  part breaks, block, regrow, per-move attack and telegraph sounds (beam, fuse,
  summon), void burst (fx event), blast (perk event), boss sting once per room,
  doors lock / room clear / team wipe / boss and mini-boss defeated, class shots
  (bow, magic), local footsteps every 0.3 s, perk chime. Menu buttons click via
  `game._hook_button_sound` -> `view.play_ui_sound`.
- Licence of the sound packs is unknown (see assets/audio/sfx/license_note.md);
  the user decided on 2026-10-27 to push them to the public repo anyway.
  Clarify or replace them before a release.
- Tests: `tests/audio_sfx_test.gd`; `animation_feedback_test` accepts recorded
  (QOA) door/stairs streams.

## Delve Disaster UI and build feedback (2026-10-28)

- User feedback after testing the build: camera zoom 1.5 (`camera.zoom`), a
  lighter crypt with a soft edge vignette (`lighting`,
  `assets/shaders/canvas_post_vignette.gdshader`), much stronger monsters and
  bosses (balance.json), bosses and mini-bosses drawn 3x (export_rigs.js
  `scales`).
- Name: **Delve Disaster** (project name, title, lobby, window). The user://
  folder follows the project name, so old local settings start fresh.
- One theme for every screen: `src/ui/crypt_ui.gd` (0x72 palette, bevelled
  pixel frames drawn in code; the 0x72 pack has only hearts, coins and four
  buttons). Run HUD `src/ui/run_hud.gd` + `assets/data/ui_run_hud.json`:
  hearts top left, boss / mini-boss bar with name top centre (replaces the
  bars over bosses), floor, room and mini-map top right, team level, skill
  slots 1-4 and EXP bar bottom centre. The HUD hides while pause or reward
  screens are open. Evidence: `production/qa/evidence/ui-delve-disaster/`
  (`scripts/capture_ui.gd`). Test: `tests/run_hud_test.gd`.

## Hero skills, team EXP, perks, walls and gore (2026-10-28)

- User decisions: level-up cards hold class cards only, bosses and mini-bosses
  drop general perks, no cards after normal rooms; cards are picked by mouse
  during the fight; the Ultimate (level 10) arrives around floor 5; all three
  Ultimates break inner walls. Details: `docs/KLASSEN-FAEHIGKEITEN.de.md`
  "Umsetzungsstand".
- Data: `assets/data/hero_skills.json` (skills, upgrades, passives, icons,
  sounds, leveling 48 x L^1.2, EXP per kind, orbs, wall and status values).
  `perk_rules.room_rewards` (default false) switches the old per-room cards
  back on; tests of the reward overlay set it.
- Host: `src/combat/hero_skills.gd` (keys as an input bitmask plus mouse
  point; cooldowns, second charges, dashes, channels, zones, delayed casts,
  skill projectiles), `src/player/class_perks.gd` (catalog, offers, passives
  applied inside `PerkRules.rebuild`), `src/player/team_progress.gd` (orbs,
  one team level, per-hero card queues), `src/dungeon/wall_breaker.gd`
  (inner wall = wall cell with floor on both sides within 2 cells; rebuilds
  the void mask; `game.walls_broken` bumps the layout revision).
  Mirror-image decoys: `game.decoys`, read by `crypt_enemy_ai`.
- Client: `src/vfx/skill_fx.gd`, `src/ui/level_cards.gd`,
  `src/ui/skill_icons.gd` (class weapon + glyph/badge, so no bow on sword
  cards). Gore: `assets/data/vfx_gore.json` (bone chips, slime, frost,
  blood, void ichor; splats on hits and deaths, drip trails below 60 % HP).
  Visual resets follow `room_serial` (room entries), not wall breaks.
- Capture tools may set `game.scripted_skills` / `scripted_target`; never in
  play. Evidence: `production/qa/evidence/hero-skills/`
  (`scripts/capture_skills.gd`). Test: `tests/hero_skills_test.gd`.
- Still open: the 28 boss abilities (`docs/BOSS-FAEHIGKEITEN.de.md`,
  approved), then the editor rework.

## Floor route, chests and effect sprites (2026-10-28)

- User decisions: 6 rooms per floor (`campaign_room_count` in
  dungeon_rooms.json; EXP curve 30 x L^1.2 keeps the Ultimate near floor 5,
  measured ~450 EXP per floor); doors only in walls; 3-5 chests per floor at
  random, in rooms ("pre-built" rooms via the editor later); chest perks are
  active at once; consumable items wait for the user's own item list
  ("Beides", items still to come); effects built directly, reviewed by
  screenshot.
- Gates: `Dungeon._crypt_wall_door` moves every crypt door into a north wall
  face (two wall cells with floor below; frame cells beside), chosen by the
  neighbour's side (`toward`), 5 cells from other exits. `door_cell` is the
  arch's left wall cell, `forward` marks the way on. The 0x72 renderer draws the
  arch there; an open gate shows a stairwell (`assets/sprites/fx/stairwell_down`
  for the way on, `stairwell_up` for the way back, user idea) and a gold
  chevron over the onward gate. The prompt names the target ("E · WEITER ZU
  RAUM 3 / 6", "E · ZURÜCK ...", "E · HINAB ZU EBENE 2").
  `tests/dungeon_ports_test.gd` checks gates in walls (its 48 old failures are
  gone with the old floor doors).
- Chests: `src/dungeon/chests.gd` + `assets/data/loot_chests.json` (template
  `chest_spawns` [x, y] cells first, else north-wall floor spots; 3 hits from
  any attack; drop = a general perk the breaker's class can use; walk over to
  take; state per room). 0x72 chest frames (CC0). Test `tests/chests_test.gd`.
- Effects: `scripts/make_fx_sprites.gd` draws 25 pixel-art strips into
  `assets/sprites/fx/` + `assets/data/vfx_sprites.json` (slash, rage slash,
  whirl, sparks, fire/frost/arcane/magic/stone/void/poison/blood bursts, orb,
  fireball, blade wave, dust, blink smoke, beam strip, level-up, pickup, rage
  aura, splinters). The 0x72 pack has no attack effects; the only one found (a
  bow hit in the "wall reconfig" pack) has no licence note and is not used.
  Player: `src/vfx/fx_sprites.gd`, used by feedback.gd (hits, kills, swings,
  chests, walls) and skill_fx.gd (skills, beam, aura, chests, loot).
- Evidence: `production/qa/evidence/flow-chests-fx/`
  (`scripts/capture_flow.gd`; capture-only `game.scripted_fire`).

## Hordes, solid breakables, wall hits, magic fades (2026-10-28)

- User decisions: rooms are no longer gates you must clear; doors work during
  fights; hordes "Groß" (floor 1: quota 25 per room, 15 alive at once; floor
  10: 50 / 25); waves until the quota is spent, then the room is quiet; stairs
  open at once except on boss floors (3, 6, 9, 10, ...) until the floor's boss
  or mini-boss falls.
- Hordes: `src/dungeon/hordes.gd` + `assets/data/combat_hordes.json` (waves in
  a 280-650 px ring around the heroes, out of sight first; leaving returns the
  living to the quota; a known room skips its opening group, a boss room whose
  boss lives spawns it again; `exp_scale` 0.25 keeps the level pace).
  `game.stairs_open()`, `game.floor_boss_down`. `hordes.enabled = false` gives
  the old single encounters; smoke-role network runs and the tests of the old
  reward flow (pause_menu, reward_cards, exploration_rules,
  crypt_enemy_integration, hero_skills) use that. Test `tests/hordes_test.gd`.
  Measured: 24 alive, 129 fps average, 74 minimum, host step at most 6.2 ms.
- Breakables: crates are host objects now (not baked into the floor image),
  3-7 per room in small groups along walls, 2 hits, no loot until the user's
  item list. Chests and crates are solid 32 px cells (`layout.obstacles`,
  `layout.breakable_obstacles`); a flood fill keeps doors, stairs and spawns
  connected; breaking one frees its cell (`game.layout_changed()`).
- Wall hits: `game.wall_hit` reports contact, normal and style (arrow, metal,
  magic, fire, frost, arcane, void, poison, stone) for shots into walls and
  sword swings against them; feedback.gd draws stone chips, a crack decal
  (`particles.crack`), sparks for metal and arrows, splashes along the wall for
  magic.
- Visual boundary: `FxSprites.spawn(..., clip = true)` cuts an effect where
  rays from its centre leave the room's floor cells, so effects never show
  through walls. Feedback and skill events clip by default.
- Magic fades: every animation eases out; magic (MAGIC list in fx_sprites.gd)
  lingers on its last frame with a soft glow; the Photoneneis beam fades and
  thins for 0.35 s after it ends; chain lightning eases out into an afterglow;
  magic orbs and fireballs leave fading trails.

## Spell look: Photoneneis, bloom, pixel physics (2026-10-28)

- User request (game feel): effects AND sprites stop at walls, a Noita-like
  pixel feel, the Photoneneis rebuilt from the Leerenrufer's beam as ice and
  fire, wider and scarier, bloom for spells, better spell sprites. HP bar
  instead of hearts is planned for later (not built).
- Photoneneis: `skill_fx.gd` `_draw_photon` / `_photon` draw it like
  `rig_renderer._draw_beam`: pixel squares every 2 px in 7 layers (navy
  outline, ice sheath, frost, fire, ember, white core), slow ice swell, fast
  fire flicker, surges running outwards, two fire threads winding through the
  ice, glinting crystals, an impact bulb with frost spikes that stops at walls
  (`fx.reach` + `FxSprites.clipped_disc`), a muzzle flare. It grows in 0.14 s,
  thins out over 0.35 s, sprays ice shards, embers and frost flakes, and
  leaves frost and soot pixels on the floor (`particles.scatter`). Hit width
  in `hero_skills.json` photon `width` 24 -> 36 to match. Local rumble while
  it burns (`feedback.BEAM_RUMBLE`). Drawing costs about 1.3 ms per beam.
- Bloom: `src/vfx/glow.gd`, a Node2D with BLEND_MODE_ADD above the darkness,
  shown only with the dark crypt (live runs, so editor and reference renders
  are unchanged). Soft dot and band textures; sources: beam, bullets, magic
  sprites and sparks (`FxSprites.draw_glow`), zones, chain lightning,
  level-ups, EXP orbs, loot, torches and braziers, glowing particles, void
  rigs. Strengths in `assets/data/vfx_glow.json`. Spells also add lights to
  the darkness (`skill_fx.lights`, `FxSprites.lights`, fireballs).
- Pixel physics: `src/vfx/particles.gd` rewritten. Particles have a height
  with gravity, bounce on the floor and off wall cells (never through a wall),
  and debris settles as floor pixels. Modes debris, spark, dust, ember, frost
  in `assets/data/vfx_particles.json`. Splats, drips, stains and cracks are
  painted into 128 px pixel chunks (2 world px per pixel) that last until the
  room changes: liquids only on floor cells, cracks into the wall struck. No
  stain cap any more (`max_stains` removed from vfx_gore.json);
  `particles.stain_count()` replaces `_stains` in tests. Test:
  `tests/particles_physics_test.gd` (12 checks).
- Sprites stop at walls: `FxSprites.draw_loop(..., clip = true)` for
  fireballs, magic orbs and blade waves near walls.
- Spell sprites (`scripts/make_fx_sprites.gd`): explosions are 9 frames of
  noise-edged puffs lit from the top left that cool and dither away, with
  smoke, ice shards and a crystal ring (frost), stars and a rune ring
  (arcane); new fireball (6 frames, flame tongues, embers), magic orb (lit,
  orbiting sparks) and blink (motes rush in, flash, scatter). The unused beam
  strip and `FxSprites.draw_strip` were removed.
- Evidence: `production/qa/evidence/spells-bloom/` via
  `scripts/capture_spells.gd` (prints frame times), plus 08-zauber-sprites-4x.png
  (the new spell sheets at 4x). Measured on floor 2 with a horde: before
  trimming the beam 8.3 ms per frame without it and 12.8 ms with it; after
  trimming (wide layers every 4 px, 1.3 ms per beam) 6.9 ms either way, worst
  frame 12.4 ms. Full suite: only the known old failures.

## Living floor, Noita stage 1 (2026-10-28)

- User question: can we simulate pixels like Noita? Answer given: a full
  falling-sand world is not sensible here (top-down instead of side view,
  GDScript speed, no compute shaders in the Compatibility renderer, tile walls
  carry collision, enemy navigation, wall breaking, the editor and co-op).
  Three stages offered; the user chose stage 1 (visual only, each client
  computes its own, nothing is sent over the network). Stage 2 (materials with
  gameplay: oil, water, poison, fire, ice reacting on a fine floor grid) is
  the recommended later step, after the user's item list. Stage 3 (all-pixel
  world) was advised against.
- Built in `src/vfx/particles.gd` (settings in `assets/data/vfx_particles.json`
  sections kick, liquid, ember, frost, smoke_color, mode smoke):
  - `kick(point, radius, strength)`: blasts lift loose debris pixels (all of
    them) and pool or stain pixels (a share) back into the air; frost stays
    frost when thrown, water splashes away.
  - Pools: every `splat` keeps creeping from its rim for a few seconds (more
    along the hit direction, never into walls, budgeted so it always stops),
    then dries darker.
  - `embers(point, radius, count)`: glowing floor pixels from fire that
    flicker yellow to dark red, glow in the bloom layer, puff smoke
    (`smoke()`) and leave soot.
  - `frost(point, radius, count, color)`: frost pixels (and settled frost
    particles) melt to water after 6-10 s; the water dries away. Frost is
    tracked per pixel (`_frozen`, colour at freezing), so frost lying on bone
    chips melts too, and frost painted over (soot, blood) stays as it is.
- Triggers: skill bursts kick (fire bursts also leave embers and smoke, frost
  bursts frost), whirl, charge and backflip kick (`skill_fx._floor_reaction`);
  wall breaks, crate breaks, bomber/void bursts and deaths kick, fire wall hits
  leave embers (`feedback.gd`); the Photoneneis leaves melting frost.
- Tests: `tests/particles_physics_test.gd` 26 checks, including two
  regression tests seen failing first (thrown frost never melted; frost on
  debris never melted). Evidence `production/qa/evidence/floor-life/` (full
  shots plus 4x close-ups) via `scripts/capture_floor_life.gd`, which prints
  frame times: 10.3 ms mean, 22 ms worst with 25 embers on a horde floor.

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
