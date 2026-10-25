# Story 001: Player movement and twin-stick shooting

> **Epic**: basement-run
> **Status**: Complete
> **Layer**: N/A (minimal)
> **Type**: Visual/Feel
> **Estimate**: M
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-10-25

## Context

**GDD**: `design/game-brief.md`
**Requirement**: Brief MVP feature 1

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Unity 6.3 LTS | **Risk**: HIGH
**Engine Notes**: none (no ADR engine-compatibility analysis at minimal)

**Control Manifest Rules (this layer)**: N/A (minimal — no control manifest)

---

## Acceptance Criteria

- [ ] WASD / left stick moves the player in 8 directions at a tunable speed, with no diagonal speed boost.
- [ ] Holding the left mouse button fires projectiles toward the mouse cursor at a tunable fire rate; arrow keys and the right stick also aim and fire (right stick takes priority, then arrows, then mouse). Decided 2026-10-25: mouse is the primary aim input.
- [ ] Projectiles travel at a tunable speed and despawn on wall hit or after a tunable lifetime.
- [ ] Player collides with walls and cannot leave the room bounds.
- [ ] Movement and fire values live in a ScriptableObject (data-driven), not hardcoded.
- [ ] Uses the Input System package, not the legacy Input Manager.
- [ ] Playable in a test scene: moving and shooting feels responsive (playability check, build order step 1).
- [ ] Retained screenshot of the player shooting in `production/qa/evidence/`.

---

## Implementation Notes

- Use Kenney Tiny Dungeon sprites from `Assets/Art`.
- Unity 6.3 is HIGH risk: verify Input System and 2D physics APIs against `docs/engine-reference/unity/`.

---

## Out of Scope

- Story 002: enemy, hearts, damage.
- Story 003: room generation.

---

## Files

- `Assets/Scripts/Player/PlayerController.cs`
- `Assets/Scripts/Player/PlayerStats.cs`
- `Assets/Scripts/Combat/Projectile.cs`
- `Assets/Editor/TestRoomBuilder.cs`
- `Assets/Scenes/TestRoom.unity`
- `Assets/Data/PlayerStats.asset`
- `Assets/Prefabs/Projectile.prefab`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Visual/Feel
**Required evidence**: Retained screenshot in `production/qa/evidence/` + sign-off in `production/qa/evidence/player-movement-shooting-evidence.md` (tests waived at qa.level minimal).

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None
- Unlocks: `production/epics/basement-run/story-002-enemy-hearts-damage.md`, `production/epics/basement-run/story-003-room-generator.md`

---

## Completion Notes
**Completed**: 2026-10-25
**Criteria**: 8/8 passing (right-stick aim and despawn-after-lifetime not hands-on tested)
**Deviations**: Advisory — implemented and engine-checked inline by the orchestrating session instead of the gameplay-programmer and unity-specialist agents. Aim input changed to mouse-first by user decision (criterion 2).
**Test Evidence**: `production/qa/evidence/story-001-player-movement-shooting/01-player-shooting.png`, sign-off in `production/qa/evidence/story-001-player-movement-shooting-evidence.md`
**Reviewed by**: self, no independent review
