# Story019: Client presentation and compatible session admission

**Status:** Implemented and locally verified
**Last Updated:** 2026-10-26
**Type:** Integration
**Layer:** Feature
**ADR:** N/A — minimal workflow, existing host-authoritative model retained
**Depends on:** Story018 implementation (manual visual acceptance remains separate)

The user requested execution of all next steps in the GameDev review. Clients
previously rendered20Hz snapshots directly and peers joined without a protocol/content
comparison. Smooth only presentation and admit only compatible peers before
they receive player or gameplay rights.

## Acceptance criteria

- Host remains authoritative for combat, movement, HP, perks and transitions.
- Clients interpolate stable player/enemy/bullet IDs using a bounded buffer and
  configurable delay; no extrapolation through dropped-packet gaps or geometry.
- New rooms, floors, runs, transitions and teleport/death boundaries do not blend
  unrelated positions. Static room geometry is shared, never deep-copied per frame.
- Admission compares explicit protocol/ruleset, engine, generator and canonical
  balance/dungeon content. Pending/mismatching/timed-out peers cannot send valid
  gameplay actions or receive ordinary snapshots. Mismatch is readable in German.
- Unit/boundary cases and real-process compatible/mismatched admissions are
  exercised; actual client GPU presentation is captured and observed.

## Scope and validation

No prediction/rollback, matchmaking, relay, authentication identity service,
host migration, visual redesign or new game content. Source code lives in src/;
real tests in tests/. Godot4.7.2 GDScript specialist and network-programmer briefs
apply through docs/codex/runtime.md. Minimal QA normally waives new tests; the
current explicit network-verification task warrants targeted tests and processes.
The user's instruction authorizes these implementation/status edits.

## Files

- src/game.gd — admission, timestamp/IDs/radii and presentation wiring
- src/session_protocol.gd — canonical compatibility manifest and bounded codec
- src/snapshot_interpolator.gd — bounded client positional presentation
- src/data/balance.json — documented network timing/queue limits
- src/vfx/feedback.gd — run/floor/revision feedback reset
- tests/session_protocol_test.gd, session_protocol_peer.gd, session_protocol_smoke.ps1
- tests/snapshot_interpolation_test.gd, party_membership_test.gd, session_feedback_reset_test.gd
- tests/client_render_probe.gd, client_render_probe.ps1 — real visible client evidence

## Completion notes

Acceptance criteria verified by targeted units, six real admission roles,
current four-peer/impairment runs and actual GPU observation. Independent
network/GDScript and harness review findings were addressed. No prediction,
identity authentication or WAN/LAN-hardware claim was added.
[Results and limits](../../../docs/GAMEDEV-UMSETZUNG.de.md).

Run result: OBSERVED — real1080p client throughout ten rooms/boss/stairs;
`production/qa/evidence/story-020-ten-room-coop-acceptance/visible-four-campaign/`.
