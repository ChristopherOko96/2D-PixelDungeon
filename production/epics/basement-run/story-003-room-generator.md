# Story 003: Random dungeon from room templates

> **Epic**: basement-run
> **Status**: Ready
> **Layer**: N/A (minimal)
> **Type**: Integration
> **Estimate**: L
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: —

## Context

**GDD**: `design/game-brief.md`
**Requirement**: Brief MVP feature 3

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Unity 6.3 LTS | **Risk**: HIGH
**Engine Notes**: none (no ADR engine-compatibility analysis at minimal)

**Control Manifest Rules (this layer)**: N/A (minimal — no control manifest)

---

## Acceptance Criteria

- [ ] Room templates are prefabs with a defined size, doors and enemy spawn points.
- [ ] A generator assembles a connected floor from templates with a tunable room count (about 6-10), using a seed.
- [ ] The same seed always produces the same layout.
- [ ] Every room is reachable from the start room; the last room is reserved for the boss.
- [ ] Doors lock while enemies live and open when the room is cleared.
- [ ] Entering a room spawns its enemies; moving between rooms works (camera snaps to the room).
- [ ] Retained screenshot of a generated floor or a room transition in `production/qa/evidence/`.

---

## Implementation Notes

- Use a seeded System.Random (not UnityEngine.Random global state) so layouts are reproducible.

---

## Out of Scope

- Story 004: reward drops.
- Story 005: boss room content.

---

## Files

- `Assets/Scripts/Dungeon/RoomTemplate.cs`
- `Assets/Scripts/Dungeon/DungeonGenerator.cs`
- `Assets/Scripts/Dungeon/RoomController.cs`
- `Assets/Prefabs/Rooms/`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: Playtest: generate with 3 seeds and walk the floor; retained screenshot in `production/qa/evidence/`.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/basement-run/story-002-enemy-hearts-damage.md`
- Unlocks: `production/epics/basement-run/story-004-items-pickups.md`, `production/epics/basement-run/story-005-boss.md`
