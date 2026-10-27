# Story014: Selected-room play and a coherent living crypt

Status: Implemented; manual play/visual acceptance pending.26October2026.

The editor's old play action validated the whole library and forced a3-room
sequence. It now starts the exact selected unsaved room through an offline
preview session, before any active-library initialization or procedural
regeneration. Missing safe starts are temporary copied-layout data. No usable
floor produces an actionable message. Return/restart preserve the editor draft.

Sixteen animated environment types and theme-specific dressing add garden beds,
books, candles, graves and rituals without closing central aisles. Environment
animation is visible on the authoring canvas while its actors remain frozen.

User correction: generated furniture defined the new art direction. New native32
stone materials reskin all four terrain palettes while preserving source alpha,
wall geometry and collisions. Frame0 bodies and explicit effect masks replace
whole-image animation swaps; vessels, stone and metal no longer use varying
generated bodies. Only their effects or designated natural parts animate.

Verified through source review, syntax-only parsing, asset import and presentation
cache authoring. No gameplay, unit, network or performance tests were run, per
standing user instruction. Actual play and visual acceptance remain open.
