# Technical Preferences

<!-- project.yaml at the repo root is the machine-readable source of truth for
     engine, specialists, naming, performance, platform, and testing.framework.
     This file is the human-readable LEGACY FALLBACK: agents and skills resolve
     each key from project.yaml first and fall back here only when the
     project.yaml key is absent. /setup-engine dual-writes both.
     Forbidden patterns and allowed libraries are NOT migrated — they live only
     in this file. Populated by /setup-engine; updated as decisions are made. -->

## Engine & Language

- **Engine**: Godot 4.7.2 (explicit user override, 2026-10-24)
- **Language**: GDScript
- **Rendering**: Compatibility (OpenGL), 2D pixel art
- **Physics**: Godot Physics 2D
- **Networking**: Godot high-level multiplayer with ENet; host authoritative

## Input & Platform

<!-- Written by /setup-engine. Read by /ux-design, /ux-review, /test-setup, /team-ui, and /dev-story -->
<!-- to scope interaction specs, test helpers, and implementation to the correct input methods. -->

- **Target Platforms**: PC (Steam / Epic)
- **Input Methods**: Keyboard/Mouse, Gamepad
- **Primary Input**: Keyboard/Mouse
- **Gamepad Support**: Partial
- **Touch Support**: None
- **Platform Notes**: Twin-stick scheme: WASD to move, mouse to aim. Gamepad is secondary.

## Naming Conventions

- **Classes**: PascalCase (e.g., `PlayerController`)
- **Variables**: snake_case; private fields/functions may use an underscore prefix
- **Signals/Events**: snake_case (e.g., `health_changed`)
- **Files**: snake_case (e.g., `player_controller.gd`)
- **Scenes/Prefabs**: PascalCase (e.g., `Player.prefab`)
- **Constants**: UPPER_SNAKE_CASE

## Performance Budgets

- **Target Framerate**: 60 fps
- **Frame Budget**: 16.6 ms
- **Draw Calls**: 300 (suggested default for 2D on PC)
- **Memory Ceiling**: 1 GB (suggested default for 2D on PC)

## Testing

- **Framework**: Godot headless import/parse plus separate-process ENet smoke tests;
  a gameplay unit-test addon is not configured yet
- **Minimum Coverage**: [TO BE CONFIGURED]
- **Required Tests**: Balance formulas, gameplay systems, networking (if applicable)

## Forbidden Patterns

<!-- Add patterns that should never appear in this project's codebase -->
- [None configured yet — add as architectural decisions are made]

## Allowed Libraries / Addons

<!-- Add approved third-party dependencies here -->
- [None configured yet — add as dependencies are approved]

## Architecture Decisions Log

<!-- Quick reference linking to full ADRs in docs/architecture/ -->
- [No ADRs yet — use /architecture-decision to create one]

## Engine Specialists

<!-- Written by /setup-engine when engine is configured. -->
<!-- Read by /code-review, /architecture-decision, /architecture-review, and team skills -->
<!-- to know which specialist to spawn for engine-specific validation. -->

- **Primary**: godot-specialist
- **Language/Code Specialist**: godot-gdscript-specialist
- **Shader Specialist**: godot-shader-specialist
- **UI Specialist**: godot-specialist (Control nodes and themes)
- **Additional Specialists**: None required for the initial GDScript slice
- **Routing Notes**: Use the Godot references. Unity and Unreal references remain
  historical studio resources and do not define the current engine.

### File Extension Routing

<!-- Skills use this table to select the right specialist per file type. -->
<!-- If a row says [TO BE CONFIGURED], fall back to Primary for that file type. -->

| File Extension / Type | Specialist to Spawn |
|-----------------------|---------------------|
| Game code (.gd files) | godot-gdscript-specialist |
| Shader / material files (.gdshader, .tres) | godot-shader-specialist |
| UI / scene files (.tscn, Control nodes) | godot-specialist |
| Native extension / plugin files | godot-gdextension-specialist when introduced |
| General architecture review | godot-specialist |
