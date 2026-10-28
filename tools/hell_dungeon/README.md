# Hell-Dungeon tools

One source of truth for the ten hell floors: `hell_core.js` holds floor 1 (handmade, user-approved) and
the seeded generator for floors 2-10. The browser preview and the Godot game both use its output.

| File | Purpose |
| --- | --- |
| `hell_core.js` | Floor data, generator, dressing rules, quickest-path check. Pure JS (node and browser). |
| `bake_floors.js` | `node tools/hell_dungeon/bake_floors.js` writes `assets/data/hell_floors.json` for Godot. |
| `check_floors.js` | `node tools/hell_dungeon/check_floors.js ./tools/hell_dungeon/hell_core.js ./assets/sprites/hell/manifest.json` prints rooms, quickest path, doors and entities per floor. |
| `preview_template.html` | The playable browser preview (all floors, floor picker, minimap). |
| `build_preview.py` | Inlines sprites, sizes and the core into one HTML file: `py -3 -I build_preview.py preview_template.html ../../assets/sprites/hell ../../assets/sprites/0x72 hell_core.js <out.html>` |
| `img.py`, `extract.py`, `world.py`, `contact.py` | Dependency-free PNG tools: cut and clean the source sheets (`extract.py <rooms_dir> <clean_dir>`), resample to world scale (`world.py <clean_dir> assets/sprites/hell`), contact sheet for review. |

After changing `hell_core.js`: run `bake_floors.js`, then the tests `tests/hell_floor_data_test.gd`,
and rebuild the preview if it should match.
