# Story 002: Enemy with simple AI, hearts, damage and death

> **Epic**: basement-run
> **Status**: Ready
> **Layer**: N/A (minimal)
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: —

## Context

**GDD**: `design/game-brief.md`
**Requirement**: Brief MVP feature 2 (enemy) and 4 (hearts, damage, death)

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Unity 6.3 LTS | **Risk**: HIGH
**Engine Notes**: none (no ADR engine-compatibility analysis at minimal)

**Control Manifest Rules (this layer)**: N/A (minimal — no control manifest)

---

## Acceptance Criteria

- [ ] Player has a tunable number of hearts (default 3) shown on a HUD.
- [ ] One enemy type chases the player and deals contact damage with a tunable cooldown.
- [ ] Player projectiles damage the enemy; the enemy dies at 0 HP.
- [ ] Player takes damage with brief invulnerability frames after a hit.
- [ ] Player at 0 hearts dies and the run ends, then a new run starts (scene reload).
- [ ] Enemy and health values are data-driven (ScriptableObject).
- [ ] Health/damage logic is unit-testable independent of MonoBehaviours.
- [ ] Retained screenshot of the HUD hearts and an enemy in `production/qa/evidence/`.

---

## Implementation Notes

- Keep a plain C# Health class with injected data so it can be tested in EditMode (`Assets/Tests/EditMode/`).

---

## Out of Scope

- Story 003: generated rooms.
- Story 005: boss behaviour.

---

## Files

- `Assets/Scripts/Combat/Health.cs`
- `Assets/Scripts/Enemies/ChaserEnemy.cs`
- `Assets/Scripts/Enemies/EnemyStats.cs`
- `Assets/Scripts/UI/HeartsHud.cs`
- `Assets/Scripts/Core/RunController.cs`
- `Assets/Tests/EditMode/HealthTests.cs`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `Assets/Tests/EditMode/HealthTests.cs` recommended but waived at qa.level minimal.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/basement-run/story-001-player-movement-shooting.md`
- Unlocks: `production/epics/basement-run/story-003-room-generator.md`, `production/epics/basement-run/story-004-items-pickups.md`, `production/epics/basement-run/story-005-boss.md`
