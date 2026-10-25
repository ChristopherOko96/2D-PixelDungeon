# Story 005: Boss at the end of the floor

> **Epic**: basement-run
> **Status**: Ready
> **Layer**: N/A (minimal)
> **Type**: Integration
> **Estimate**: L
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: —

## Context

**GDD**: `design/game-brief.md`
**Requirement**: Brief MVP feature 6

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Unity 6.3 LTS | **Risk**: HIGH
**Engine Notes**: none (no ADR engine-compatibility analysis at minimal)

**Control Manifest Rules (this layer)**: N/A (minimal — no control manifest)

---

## Acceptance Criteria

- [ ] The last room contains a boss with higher HP and at least two attack patterns.
- [ ] The boss shows a health bar.
- [ ] Defeating the boss ends the run with a win screen, then a new run can start.
- [ ] Player death in the boss fight follows the normal fail state (new run).
- [ ] Boss values are data-driven (ScriptableObject).
- [ ] Retained screenshot of the boss fight in `production/qa/evidence/`.

---

## Implementation Notes

- Reuse Health and Projectile from stories 001-002.

---

## Out of Scope

- Multiple floors and meta-progression (out of scope in the brief).

---

## Files

- `Assets/Scripts/Enemies/BossController.cs`
- `Assets/Scripts/Enemies/BossStats.cs`
- `Assets/Scripts/UI/BossHealthBar.cs`
- `Assets/Scripts/UI/WinScreen.cs`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: Playtest: full run to boss kill; retained screenshot in `production/qa/evidence/`.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/basement-run/story-004-items-pickups.md`
- Unlocks: None
