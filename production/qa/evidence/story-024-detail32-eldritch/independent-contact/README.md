# Independent Chibi32 visual and engine-path review

Reviewed on27.10.2026. This review changed no production source, catalog,
profile, keys or atlases. The read-only extraction helper is
`work/qa_chibi32_baked_contact.gd` outside the project. The exact reviewed
atlas SHA256 values are recorded in `contact_metadata.json`.

## Inspected surface

All eight `{actor}_six_actions.png` contacts were inspected at original image
resolution. Panels are south/east above north/west; rows are idle_breathe,
walk_forward, attack_primary, hit_front, death_fall and charge_release.
Columns are frames0–5. This is1,152 selected frame images, not a visual review
of every one of the9,216 baked frames. The contacts use nearest2x enlargement;
Boss and Necromancer diagnostic focus sheets use4x.

Native key contacts for Warden, Arcanist, Necromancer, Guard and Boss were also
inspected, followed by the root agent's GPU eight-actor comparison, attack
frame10 and quiet room reference. The generated adult masters were used only
for historical comparison; the active revision is the subsequent Chibi32 art.

## Concrete result

- The revised head/body proportions read more like chibi characters than the
  adult intermediate designs. Short separated legs, boots and hand/equipment
  silhouettes remain identifiable at this scale.32px limits fine facial detail;
  subjective eye/face readability still belongs to the user's visual review.
- The new blue-green boss reads as a cephalopod/tentacle creature. Front/rear
  and profile silhouettes differ correctly. No old horns, red demon body or
  infernal fire design appears in the inspected boss frames.
- No conspicuous newly detached boss hand/tentacle, missing boot or clipped
  weapon edge was apparent in the selected frames. The enlarged Boss focus
  includes south/north attacks, south charge and south hit.
- Necromancer staff remains on the same hand side through the inspected
  idle/attack/hurt changes. Jade crystal and pale skull highlights are visible
  after the root agent's rare-accent palette correction. The initial
  frequency-only palette had visibly lost those accents; that initial version
  was not the final reviewed atlas.
- Each source key is32x32; baked cells contain additional transparent movement
  padding. Ordinary actors use2x world scale and the Boss3x. Those scales do
  not fabricate extra source detail. GPU composites show no opaque white
  rectangles; some native PNG transparent pixels carry white RGB at alpha0.

## Engine-path review

Reviewed importer, current Baker, Bank and View against the local Godot4.7
rendering/current-practices references. The substantive finding was that the
candidate actor-specific rig values initially were not passed to `_rig_model`.
The root agent corrected this: `_bake_actor` now passes `actor.get("rig",{})`,
and `_rig_model` reads per-actor head/waist/core values with global defaults.
That current handoff was confirmed before inspecting the final contacts.

The importer now extracts whole connected silhouettes instead of fixed quarter
cells, avoiding the observed uneven-row boot cuts. Current profiles retain hard
alpha, a bounded64-color palette and integer world scales. Foot placement and
View footer compensation are mathematically consistent with the declared
anchors. Bank sampling reuses atlas regions and performs no per-frame Image
copies. No additional blocking Godot API or integration issue was found in the
reviewed path.

## Limits

This is a selected static anatomy/continuity review and inspection of retained
GPU stills. It is not native-speed timing acceptance, a full playthrough,
performance/LAN measurement, a review of all48 actions or user style approval.
Death remains an articulated tilt/compression of key art; the48 actions are
distinct baked motion clips, not48 fully hand-drawn action sets per character.
