extends RefCounted
## Talent icons: an 8x8 pixel motif on a 16x16 tile in the branch colours
## (talents.json "classes"), drawn scaled with nearest filtering. Shared by
## the talent screen and the run HUD; textures are built once per look.

## 8x8 pixel motifs of the talent icons, painted in the branch colours.
const MOTIF := {"bolt": ["....##..", "...##...", "..####..", ".######.", "..####..", "...##...", "..##....", ".##....."],
	"flame": ["...#....", "..##....", "..###.#.", ".#####..", ".######.", "########", "########", ".######."],
	"ring": ["..####..", ".#....#.", "#......#", "#..##..#", "#..##..#", "#......#", ".#....#.", "..####.."],
	"blink": ["##......", "##..#...", "...###..", "..#####.", "...###..", "....#.##", "......##", "........"],
	"shield": ["########", "#.####.#", "#.####.#", "#.####.#", ".#.##.#.", ".#.##.#.", "..#..#..", "...##..."],
	"shard": ["...#....", "..###...", ".#####..", "..###.#.", "...#.###", "....####", ".....###", "......#."],
	"drop": ["...##...", "...##...", "..####..", ".######.", ".######.", "########", ".######.", "..####.."],
	"echo": ["#..#..#.", ".#..#..#", ".#..#..#", "#..#..#.", "#..#..#.", ".#..#..#", ".#..#..#", "#..#..#."],
	"clock": ["..####..", ".#....#.", "#...#..#", "#...#..#", "#...###.", "#......#", ".#....#.", "..####.."],
	"arrow": ["......##", ".....###", "....###.", "#..###..", ".####...", "..##....", ".#.#....", "#..#...."],
	"eye": ["........", "..####..", ".#....#.", "#..##..#", "#..##..#", ".#....#.", "..####..", "........"],
	"mark": ["#.#..#.#", "........", "#..##..#", "..####..", "..####..", "#..##..#", "........", "#.#..#.#"],
	"trap": ["#.#..#.#", "########", "#......#", "#.####.#", "#.####.#", "#......#", "########", "#.#..#.#"],
	"paw": [".#...#..", "###.###.", ".#...#..", "...#....", "..###...", ".#####..", ".#####..", "..#.#..."],
	"sword": [".......#", "......##", ".....##.", "....##..", "#..##...", ".###....", "..##....", ".#.#...."],
	"burst": ["#..#..#.", ".#.#.#..", "..###...", "#######.", "..###...", ".#.#.#..", "#..#..#.", "........"]}
static var _cache: Dictionary = {}


## The icon of a talent `motif` for a branch `spec` ({id, color, color2}); grey when not `on`.
static func make(spec: Dictionary, motif: String, on: bool) -> Texture2D:
	var key := "%s:%s:%s" % [spec.get("id", ""), motif, on]
	if _cache.has(key): return _cache[key]
	var base := Color(str(spec.get("color", "#777777"))) if on else Color("4a4550")
	var image := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	image.fill(base)
	image.fill_rect(Rect2i(0, 12, 16, 4), base.darkened(0.28))
	var ink := Color(str(spec.get("color2", "#ffffff"))) if on else Color("8f8896")
	var rows: Array = MOTIF.get(motif, MOTIF.burst)
	for y in range(8):
		for x in range(8):
			if str(rows[y])[x] == "#": image.set_pixel(4 + x, 4 + y, ink)
	var texture := ImageTexture.create_from_image(image)
	_cache[key] = texture
	return texture
