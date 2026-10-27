# Independent baked-actor visual review

Reviewed on 2026-10-26. This is a static visual review of the baked atlas version identified by `contact_metadata.json`, not a game playthrough, animation-timing acceptance, network test, or user art approval. Production keys, catalog, bank and baker were not changed by this review.

Each `{actor}_six_actions.png` contains four panels: south upper-left, east upper-right, north lower-left, west lower-right. Within each panel, rows are idle_breathe, walk_forward, attack_primary, hit_front, death_fall, charge_release; columns are frames 0 through 5. All eight actor contact sheets were inspected. This covers 1,152 selected frame images out of 9,216 total baked images. The contacts use nearest-neighbour 2× enlargement, with larger 4× diagnostic crops.

## Visible defects in this reviewed version

1. **Boss raised hands separate from the arms.** In `boss_focus.png`, row 1 is south attack_primary, row 2 north attack_primary, row 3 south charge_release, row 4 south hit_front. Columns are frames 0–5. South/north attack frames 0 and 1 clearly show pale hand/claw fragments floating above the corresponding outer arm. The defect is inside the frame; it is not atlas-edge clipping. A likely cause in `_split_layers` is the rule that places very high pixels in the head layer, even when far to the side. Raised attack hands lie higher than the idle head reference, so those fragments receive the head transform while the arm receives a different transform. Use pose-aware anatomy masks or actor-specific head/arm regions; keep horn exceptions narrow. Recheck the same frames after changing the rig.

2. **Necromancer staff changes sides within a single attack.** In `necromancer_focus.png`, rows are south idle_breathe, south attack_primary, south hit_front, north attack_primary. South attack frames 0–2 hold the staff on the image's left, frame 3 uses hurt with the staff on the right, frame 4 returns left, frame 5 uses idle on the right. North has the opposite side change. The authored attack keys hold the staff on the opposite side from the idle/hurt keys. Per-actor casting sequences that retain the attack pose through the cast can remove the in-clip jump. A separate weapon layer with a consistent hand anchor is the stronger fix for action transitions. Do not mirror the entire east/west character to move the staff.

The reviewed version should not receive an unqualified visual PASS until these two defects are addressed.

## Other observations

- The remaining six actors have recognisable front, side and rear views in the inspected selection. No comparable detached hand/weapon fragments were apparent in these contact sheets.
- Archer bows, guard swords/shields and the four player silhouettes remain present in the selected attacks and reactions. No obvious atlas-edge truncation was visible in the inspected frames.
- Walk rows visibly alternate authored moving and idle poses. Hit rows bend the body and head, and death rows progressively tilt and compress the body. Death is a rig deformation of the hurt key, not a separately authored collapse sequence.
- Charge and attack reuse the same authored casting/attack silhouette, so their visual vocabulary remains similar despite different motion tracks. Forty-eight distinct baked clips should not be described as forty-eight fully hand-drawn action sets per actor.
- Static contacts cannot determine whether six-frame timing feels smooth at the selected durations. A native-speed animation review and user feel feedback remain separate.

The bank/catalog structurally declare eight actors, 48 action identifiers, four directions and six frames per clip. The baker's `quality_validated` flag checks technical bounds and sequence uniqueness; it does not establish the visual correctness of anatomy or weapon continuity shown here.

## Reproduction

The read-only extraction helper is outside the project in `work/qa_baked_actor_contact.gd` in the task workspace. It uses Godot Image APIs to copy existing atlas regions. The JSON metadata records the input atlas SHA256 values. These evidence files preserve the reviewed version even if the production atlases are subsequently corrected.
