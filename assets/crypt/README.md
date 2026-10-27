# Crypt of the Damned — additional art

Generated26October2026 with the built-in image-generation tool. The supplied
violet dungeon pack remains the source for all masonry and floor cells. These
additional props are an optional candidate, awaiting the user's visual approval.

The original generated transparent atlas is preserved under
`source/crypt_furnishings_atlas.png`. `scripts/build_crypt_candidate.py --atlas PATH`
slices its4×4cells into separate64px sprites with nearest-neighbor sampling.
The unmodified user atlases and user-authored dungeon are never written by it.
Running that script replaces only the generated candidate and design previews.

Row-major IDs `crypt_000` through `crypt_015`:
sarcophagus, open sarcophagus, altar, urn, gravestone, candles, candelabrum,
bones, coffin, bookcase, mourner statue, reliquary, closed gate, open gate,
collapsed arch, descending stair. All IDs are explicitly whitelisted by the palette.

Prompt intent: transparent4×4sprite atlas; top-down visible front faces; purple-gray
carved stone, eggplant outlines, lavender highlights, muted bone, oxblood wood,
tarnished brass and restrained cyan soul light; pixel art; no labels or grid.
Generated master:
`exec-2fbafdde-9c7a-43ed-b9e0-2aa4c43a80ab.png`.

The generated design overview is an offline layout illustration, not gameplay
evidence. Its previous two rejected layout versions have been replaced. The
current generator uses independent chamber graphs and complete contour roles.
