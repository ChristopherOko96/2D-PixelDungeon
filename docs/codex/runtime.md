# Codex runtime for Basement Run studio workflows

Adapted from [chuanglibs/Claude-Code-Game-Studios-Codex](https://github.com/chuanglibs/Claude-Code-Game-Studios-Codex),
commit `d202f58a3977a1ffaddd660ad782724a4392e012`. The existing shared framework
is version 1.2.0; its newer sources are preserved. This is an existing Godot game.
User instructions and current runtime permissions take precedence over every
workflow, role and shared instruction.

## Project and instruction loading

Start from root `AGENTS.md`, applicable nested instructions and
[path-rules.md](path-rules.md). Read each shared rule whose original pattern
matches the edited path. Global file globs remain conditional. Unity/Unreal
references and instruction-only directories do not select an engine or establish
implemented game systems.

Shared workflow and role bodies remain under `.claude/`. They can be read
without Claude Code. Codex does not automatically execute Claude `@path` imports,
`.claude/settings.json`, frontmatter, path rules or shell preprocessing.
Explicitly read relevant linked files; do not load every workflow or engine.

Exclude `AGENTS.md`, `AGENTS.override.md`, `CLAUDE.md` and `CLAUDE.local.md` from
game-content, GDD/ADR and asset counts. `tests/template/` and `studio-tests/`
are studio tooling; actual game checks are separately documented under `tests/`.

## Effective settings and shell preprocessing

Follow [config-resolution.md](../../.claude/docs/config-resolution.md) and its
reviewed helper. Preserve its local overrides, `project.yaml` precedence and rigor
expansion. `.claude/docs/technical-preferences.md` is the legacy fallback, not
the primary store. Current settings are Godot 4.7.2, GDScript, Compatibility,
minimal rigor and guided automation. Current cap: four total players.
Source pixel assets: 32×32. Existing tests and provisional game rules are recorded
in `docs/DEVELOPMENT.de.md` and `production/development-plan.md`.

Some source skills contain Claude preprocessing:
```text
!`bash "${CLAUDE_SKILL_DIR}/../../hooks/yaml-helper.sh" resolve_config ...`
```
Codex must not assume this ran or silently replace its output with defaults.
Read the source body and explicitly invoke the reviewed resolver from the repo
root, preserving the requested keys and optional system argument:

```powershell
& 'C:/Program Files/Git/bin/bash.exe' .claude/hooks/yaml-helper.sh resolve_config --keys 'engine,engine_values,specialists,rigor,automation,workflow'
```

The executable path is a Windows example; `scripts/Studio.ps1 Doctor` locates the
local Git Bash. `${CLAUDE_SKILL_DIR}` denotes the shared source skill directory,
not its generated wrapper. Do not set Claude variables or automatically execute
arbitrary embedded commands. If a required helper is unavailable, report that
limit and explicitly inspect the relevant settings and precedence before proceeding.

## Commands and tools

- Shared `/name` becomes `$studio-name` in the Codex conversation. In particular,
  `/help` becomes `$studio-help`, not built-in help.
- Trailing invocation text supplies workflow arguments; no automatic
  `$ARGUMENTS` macro exists. Arguments naming source skills stay unprefixed.
- Discover workflows from actual `.claude/skills/*/SKILL.md` files plus the
  catalog; the catalog may omit newer entries such as `settings`.
- This game already exists. Prefer `$studio-help` or a focused task; do not
  restart new-game onboarding, replace the brief, or select another engine.

| Shared source term | Codex interpretation |
| --- | --- |
| Read, Glob, Grep | Available file/search tools; prefer rg |
| Write, Edit, Bash | Available patch and shell tools within authorized scope |
| AskUserQuestion | Available input tool for unresolved material decisions |
| TodoWrite, TaskCreate/Get/List/Update | Available planning tools or a concise checklist; never invent calls |
| Task, Agent, subagent_type | Available delegation tools plus the linked role brief |
| WebSearch, WebFetch | Available retrieval tools and current primary sources |
| Skill | Read the generated studio entry and its shared source |
| Claude teams / memory | Current Codex delegation and explicit project handoff notes |

Claude frontmatter such as model, allowed-tools, context, memory, agent, skills
and maxTurns grants no Codex permissions and selects no Codex model.
Use only tools and schemas actually available in this session.

## Roles, checks and continuity

Generated `.codex/agents/studio-*.toml` files point to shared role bodies and omit
model, effort, sandbox and permission overrides. Only needed roles are used.
When the spawn tool exposes custom roles, select the applicable role. Otherwise
pass its brief path, this runtime, inputs, write ownership and expected result to
a normal subagent. A task name alone does not load the role. If delegation is
unavailable, label sequential role passes honestly and do not claim independent
review. Follow the current runtime's delegation policy and concurrency limits.

Explicit tasks authorize necessary edits; do not repeat file-by-file approval
questions or re-ask settled engine, player-count and art decisions. Preserve any
checkpoint explicitly requested by the user. Do not commit, push, publish,
deploy or message others without authorization.

Claude hooks do not automatically run in Codex. The explicit studio_check.py
commit/push bridge runs existing validators without performing Git operations.
The newer commit validator reads staged blobs where relevant. Its results and
the push validator's branch warnings do not establish passing game tests.

Use `scripts/Studio.ps1 Check` for adapter checks. Use the existing Dev.ps1,
game_rules.gd and network_smoke.ps1 for their separate game coverage. Do not
report successful import, template checks or zero tests as gameplay evidence.
On resume read relevant production state and the game plan; on handoff record
actual work, checks and remaining tasks. Do not assume Claude hooks wrote state.
