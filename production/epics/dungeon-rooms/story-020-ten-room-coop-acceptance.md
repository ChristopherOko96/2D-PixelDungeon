# Story020: Current ten-room campaign and local coop evidence

**Status:** Local verification passed; real LAN hardware and subjective acceptance pending
**Last Updated:** 2026-10-26
**Type:** Integration
**Layer:** Feature
**ADR:** N/A — minimal workflow, no new gameplay rules
**Depends on:** Story019 implementation before final network runs

Execute the next GameDev verification steps against the actual ten-room crypt,
not the historical three/six-room test fixture. No test-only damage, invulnerability,
forced completion or spatial teleport may count as a completed campaign.

## Acceptance criteria

- Real solo combat/input flow traverses ten distinct rooms, automatic cards,
  choices/readiness, physical E doors, black transitions, boss only in10 and stairs.
- Two and four independent processes agree on rooms/layouts, party/perks and
  run/floor changes. Gain/loss/restart lifecycle is covered separately and honestly.
- A local100ms round-trip/1%UDP-loss run records actual proxy conditions and
  diagnostics. It is not called a real WAN or LAN-hardware test.
- Visible GPU frame-time evidence names hardware, resolution and workload;
  headless server rates are not labeled graphical FPS.
- Real two-machine LAN acceptance stays open: the user confirmed only this PC.
  Provide reproducible start/evidence instructions for a future second machine.
- Subjective art/feel acceptance remains with the user.

## Files

- tests/ten_room_campaign_peer.gd, ten_room_campaign_smoke.ps1
- tests/ten_room_impaired_smoke.ps1, net_udp_proxy.py
- tests/client_render_probe.gd, client_render_probe.ps1
- tests/game_rules.gd, exploration_rules_test.gd — current-data fixtures
- docs/GAMEDEV-UMSETZUNG.de.md, NETZWERK-SITZUNG.de.md, LAN-ABNAHME.de.md
- production/qa/evidence/story-019-client-smoothing-admission/
- production/qa/evidence/story-020-ten-room-coop-acceptance/

## Results and remaining acceptance

Solo/two/four full campaigns, no-farm backtracking, boss10, stairs, stronger
earned-perk/wipe/restart cases and final impaired four-peer run passed. Actual
view ID/revision, black frame, one sound call and one room swap are checked.
190 scoped logic checks and six admission roles passed. Visible full-campaign
client averaged143.68FPS at1080p; every room's combat-p95 met16.667ms after
transparent testbot-only navigation warmup. Original failed measurement retained.

The user confirmed only this PC. Two-machine LAN,30-minute LAN and subjective
feel acceptance remain open; a repeatable LAN procedure is prepared. This story
is not marked universally complete. [Report](../../../docs/GAMEDEV-UMSETZUNG.de.md).

Run result: OBSERVED — real four-peer boss/campaign and scoped local data retained.
