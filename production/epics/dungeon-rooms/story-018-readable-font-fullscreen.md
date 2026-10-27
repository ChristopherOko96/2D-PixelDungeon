# Story018: Readable pixel typography and whole-screen play

Status: Implemented, focused visual review complete; manual play acceptance pending.
26 October2026.

Pixel Operator8 is bundled with its original CC0 license and provenance. Native
16/24/32px rendering replaces the previous face. German glyphs are verified;
long reward names and lobby text were adapted to its wider advances.

Live play fills the logical viewport. Canvas expand preserves proportions on
other screen shapes. Hearts/menu remain at screen edges; modal input guards,
shades and room-transition black cover the whole view. F11, Alt+Enter and the
pause Display page toggle fullscreen and restore the window rectangle. Camera
and firing bounds use the actual view size. Editor authoring geometry is unchanged.

Actual GPU views cover720p,1600×1000 and1080p fullscreen; ESC stays in fullscreen
and five black-frame samples are black. Overview, offers and lobby were inspected,
and discovered text overflows fixed. Still capture and UI fixtures are not a
completed room/run. No broad unit/gameplay/network suite was run.

[Implementation, review and next steps](../../../docs/UI-VOLLBILD-REVIEW.de.md).
Next: manual ten-room acceptance; client interpolation/version handshake; current
two-/four-player LAN and frame-time evidence. No new dressing before style feedback.
