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
- Local commands: `./scripts/Dev.ps1 Doctor`, `Open`, `Run`, `Host`, `Join`, `Check`.
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
- Visual requirement: real 32×32 PNG sprites on a 32-pixel base grid, nearest
  filtering and no smoothing. Keep four players distinct, enemies separate from
  friendly bullets, and combat readable in the Isaac/Vampire Survivors direction.
  Assets live under `assets/sprites/`; the generator is
  `scripts/generate_pixel_assets.gd`. Verify actual PNG dimensions before claiming
  them. Idle, firing and environment polish can be added in separate passes.

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
