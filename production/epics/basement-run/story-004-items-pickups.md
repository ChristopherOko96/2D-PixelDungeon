# Story 004: Item pickups that change shots or stats

> **Epic**: basement-run
> **Status**: Ready
> **Layer**: N/A (minimal)
> **Type**: Integration
> **Estimate**: L
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: —

## Context

**GDD**: `design/game-brief.md`
**Requirement**: Brief MVP feature 5

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Unity 6.3 LTS | **Risk**: HIGH
**Engine Notes**: none (no ADR engine-compatibility analysis at minimal)

**Control Manifest Rules (this layer)**: N/A (minimal — no control manifest)

---

## Acceptance Criteria

- [ ] A cleared room drops one pickup, chosen from a data-driven item pool.
- [ ] About 5 items exist, each modifying shots (e.g. count, size, piercing) or stats (e.g. speed, damage, fire rate, hearts).
- [ ] Picking up an item applies its effect immediately and removes the pickup.
- [ ] Effects stack when several items are collected.
- [ ] Items are defined as ScriptableObjects; adding an item needs no code change in the pickup logic.
- [ ] Collected items are shown on the HUD or as on-pickup text.
- [ ] Retained screenshot of a pickup and its effect in `production/qa/evidence/`.

---

## Implementation Notes

- Route all effects through a stat-modifier list on the player so stacking is predictable.

---

## Out of Scope

- Story 005: boss and win state.

---

## Files

- `Assets/Scripts/Items/ItemData.cs`
- `Assets/Scripts/Items/Pickup.cs`
- `Assets/Scripts/Items/ItemPool.cs`
- `Assets/Scripts/Player/PlayerStats.cs` (modifiers)

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: Playtest: collect all items in one run; retained screenshot in `production/qa/evidence/`.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/basement-run/story-003-room-generator.md`
- Unlocks: `production/epics/basement-run/story-005-boss.md`
