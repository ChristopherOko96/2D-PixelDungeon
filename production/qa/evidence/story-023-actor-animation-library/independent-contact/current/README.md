# Independent visual recheck after rig fixes

Reviewed on 2026-10-26 after the corrected atlases were baked and imported. The exact reviewed atlas SHA256 values are in `contact_metadata.json`. No production keys, bank, catalog or baker were changed by this independent review.

All eight current `{actor}_six_actions.png` contacts were visually inspected at original image resolution. Each contact shows south/east above north/west; rows are idle_breathe, walk_forward, attack_primary, hit_front, death_fall, charge_release. Each row has frames 0–5 at nearest-neighbour 2×. The two focus sheets use 4×.

## Result

The two defects recorded in `../initial/README.md` are resolved in this reviewed version:

- **Boss hand continuity:** `boss_focus.png`, rows 1 and 2, columns 1 and 2 show south/north attack_primary frames 0 and 1. The pale hands now follow the raised forearms rather than floating above them. Row 3, south charge_release, also preserves the hand-to-arm relationship. Horns remain attached to the head in the inspected poses.
- **Necromancer weapon continuity:** `necromancer_focus.png` shows south idle, south attack, south hit, north attack. The staff stays on the same image side through the attack/hurt/idle transitions. The full contact also shows stable east/west weapon sides. The actor-specific attack-to-idle source remap removes the prior hand swap while the rig still moves the body and limbs.

No new conspicuous limb/weapon separation or atlas-edge truncation was apparent in the inspected selection. The remaining six actor contacts were rechecked after the shared mask change: the players' helmets/hats, lizard silhouette, archer bow and guard shield/sword remain recognisable and present.

## Scope and limits

This review inspects 1,152 selected frame images out of 9,216 total: eight actors × six actions × four directions × six frames. It is a static anatomy/continuity review, not a visual inspection of every action, a native-speed timing review, a played campaign, performance measurement or user art approval.

Death is visibly a progressive tilt/compression of an authored hurt pose. Charge and attack still share authored silhouettes and differ through rig motion; these are 48 distinct baked motion clips per actor, not 48 fully hand-drawn action sets. Whether those motions feel sufficiently varied and smooth belongs to the user's next animation/feel review.

The read-only bank/catalog inspection found the expected eight actors, 48 actions, four directions and six frames, with dynamic frame dimensions used by the bank. That structural check is separate from the visual findings above.

The original defect contacts remain under `../initial/` for comparison. The extraction helper is `work/qa_baked_actor_contact.gd` outside the project root.
