extends SceneTree
## Builds the item sprites in assets/sprites/items/ from the 0x72 originals:
## bows and staffs recoloured into new designs (the wood or the gem takes a new
## hue), twelve potion colours from the red flask, the gold crate, and two
## small drawn icons (identification crystal, curse-breaker stone).
## Usage: godot --headless --path . -s res://scripts/make_item_sprites.gd

const SOURCE := "res://assets/sprites/0x72/"
const OUT := "res://assets/sprites/items/"

## [name, source, hue (0..1, -1 = keep), saturation factor, value factor, only the gem]
const RECOLOURS := [
	["bow_bone", "weapon_bow", -1.0, 0.15, 1.6, false],
	["bow_frost", "weapon_bow", 0.53, 0.8, 1.25, false],
	["bow_ember", "weapon_bow_2", 0.02, 1.4, 1.15, false],
	["bow_void", "weapon_bow", 0.78, 1.1, 1.05, false],
	["bow_gold", "weapon_bow_2", 0.13, 1.3, 1.35, false],
	["bow_moss", "weapon_bow", 0.3, 0.9, 1.0, false],
	["bow_blood", "weapon_bow_2", 0.98, 1.3, 0.85, false],
	["staff_sapphire", "weapon_green_magic_staff", 0.6, 1.2, 1.1, true],
	["staff_amethyst", "weapon_green_magic_staff", 0.78, 1.1, 1.1, true],
	["staff_amber", "weapon_red_magic_staff", 0.1, 1.2, 1.2, true],
	["staff_frost", "weapon_green_magic_staff", 0.52, 0.6, 1.4, true],
	["staff_void", "weapon_red_magic_staff", 0.8, 1.2, 0.9, false],
	["staff_sun", "weapon_red_magic_staff", 0.14, 1.4, 1.4, false],
	["staff_bone", "weapon_green_magic_staff", -1.0, 0.1, 1.7, false],
]
## Potion colours: [name, hue, saturation factor, value factor].
const POTIONS := [
	["red", 0.0, 1.0, 1.0], ["orange", 0.07, 1.0, 1.1], ["yellow", 0.15, 1.0, 1.25], ["lime", 0.25, 1.0, 1.1],
	["green", 0.36, 1.0, 0.95], ["teal", 0.47, 1.0, 1.0], ["sky", 0.55, 0.9, 1.2], ["blue", 0.63, 1.1, 1.0],
	["violet", 0.76, 1.0, 1.0], ["pink", 0.9, 0.8, 1.3], ["white", -1.0, 0.05, 1.8], ["black", -1.0, 0.25, 0.35],
]


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for entry: Array in RECOLOURS:
		var image := _load(str(entry[1]))
		_recolour(image, float(entry[2]), float(entry[3]), float(entry[4]), bool(entry[5]))
		_save(image, str(entry[0]))
	for entry: Array in POTIONS:
		var flask := _load("flask_big_red")
		_recolour(flask, float(entry[1]), float(entry[2]), float(entry[3]), true)
		_save(flask, "potion_" + str(entry[0]))
	var crate := _load("crate")
	_recolour(crate, 0.12, 1.5, 1.35, false)
	_save(crate, "crate_gold")
	_save(_crystal(), "crystal_identify")
	_save(_stone(), "stone_curse")
	# item system 2 (docs/ITEM-SYSTEM-V2.de.md): armour, rings, amulets, new consumables
	for entry: Array in ARMOURS:
		_save(_mask(ARMOUR_MASK, {"a": Color(str(entry[1])), "b": Color(str(entry[2])), "h": Color(str(entry[3]))}), "armor_" + str(entry[0]))
	for entry: Array in GEMS:
		_save(_mask(RING_MASK, {"a": Color("c9a24a"), "b": Color("8a6a2a"), "h": Color("f4e3a1"), "g": Color(str(entry[1])), "s": Color(str(entry[2]))}), "ring_" + str(entry[0]))
		_save(_mask(AMULET_MASK, {"a": Color("b9b4ad"), "b": Color("6f6a64"), "h": Color("ece7df"), "g": Color(str(entry[1])), "s": Color(str(entry[2]))}), "amulet_" + str(entry[0]))
	_save(_mask(SEAL_MASK, {"a": Color("b33a3a"), "b": Color("6e1f24"), "h": Color("e57a6a"), "g": Color("f2d8b0")}), "seal_clone")
	_save(_mask(STONE_UP_MASK, {"a": Color("8a8f98"), "b": Color("5d626b"), "h": Color("c9ced6"), "g": Color("7ed66f")}), "stone_upgrade")
	_save(_mask(DICE_MASK, {"a": Color("e9e2d4"), "b": Color("a79f92"), "h": Color("ffffff"), "g": Color("1a1414")}), "stone_dice")
	_save(_mask(MIRROR_MASK, {"a": Color("b38cf0"), "b": Color("6a4aa8"), "h": Color("efe3ff"), "g": Color("8a6a2a")}), "crystal_mirror")
	print("ITEM_SPRITES written to ", OUT)
	quit()


## Armour colours: [name, main, shade, highlight].
const ARMOURS := [["leather", "8a5a3a", "5a3a26", "b98a5e"], ["chain", "9aa3ad", "5f6670", "d6dde4"], ["bone", "d9cfbf", "9b8f7c", "f4eee4"],
	["shadow", "4a3f63", "2b2440", "7d6fa3"], ["dragon", "b8402f", "6e2018", "f08a5d"]]
## Gem colours for rings and amulets: [name, gem, gem shine].
const GEMS := [["haste", "6fd3e0", "d8fbff"], ["might", "e05a4a", "ffc2b0"], ["focus", "7a6ff0", "d6d0ff"], ["blood", "9e1f3a", "f07a90"],
	["storm", "f0d050", "fff6c0"]]
## 16x16 masks: '#' outline, letters are palette keys, '.' empty.
const ARMOUR_MASK := [
	"................",
	"....###..###....",
	"...#hha##ahh#...",
	"..#haaaaaaaaa#..",
	"..#haaaaaaaab#..",
	"..##aaaaaaab##..",
	"...#haaaaaab#...",
	"...#haaaaaab#...",
	"...#bbbbbbbb#...",
	"...#haaaaaab#...",
	"...#haaaaaab#...",
	"...#haaaaaab#...",
	"...#bbbbbbbb#...",
	"....########....",
	"................",
	"................"]
const RING_MASK := [
	"................",
	"................",
	"......####......",
	".....#sgsg#.....",
	".....#gggg#.....",
	"....##a##a##....",
	"...#ha#..#ab#...",
	"..#ha#....#ab#..",
	"..#h#......#b#..",
	"..#h#......#b#..",
	"..#ha#....#ab#..",
	"...#ha####ab#...",
	"....#hhaaab#....",
	".....######.....",
	"................",
	"................"]
const AMULET_MASK := [
	"..#..........#..",
	"..#h........b#..",
	"...#h......b#...",
	"...#h......b#...",
	"....#h....b#....",
	"....#h....b#....",
	".....#h..b#.....",
	"......####......",
	".....#aaab#.....",
	"....#asggab#....",
	"....#agggab#....",
	"....#aggggb#....",
	".....#aggb#.....",
	"......#bb#......",
	".......##.......",
	"................"]
const SEAL_MASK := [
	"................",
	".....######.....",
	"...##hhaaaa##...",
	"..#hhaaaaaaab#..",
	"..#haaaggaaab#..",
	".#haaagggaaaab#.",
	".#haaaaggaaaab#.",
	".#haaaggggaaab#.",
	".#haagggggaaab#.",
	".#haaagagaaabb#.",
	"..#haagaagaabb#.",
	"..#bbaaaaaabb#..",
	"...##bbbbbb##...",
	".....######.....",
	"................",
	"................"]
const STONE_UP_MASK := [
	"................",
	"................",
	".....######.....",
	"...##hhhaaa##...",
	"..#hhaagaaaab#..",
	".#haaagggaaaab#.",
	".#haaggggga.ab#.",
	".#haaaagaaaabb#.",
	".#haaaagaaaabb#.",
	".#haaaagaaabbb#.",
	"..#baaaaaaabb#..",
	"...##bbbbbbb#...",
	".....#######....",
	"................",
	"................",
	"................"]
const DICE_MASK := [
	"................",
	"................",
	"...##########...",
	"..#hhhhhhhhha#..",
	"..#hgaaaaaaga#..",
	"..#haaaaaaaab#..",
	"..#haaaaaaaab#..",
	"..#haaagaaaab#..",
	"..#haaaaaaaab#..",
	"..#haaaaaaaab#..",
	"..#hgaaaaaagb#..",
	"..#abbbbbbbbb#..",
	"...##########...",
	"................",
	"................",
	"................"]
const MIRROR_MASK := [
	"................",
	".....######.....",
	"....#hhhaab#....",
	"...#hhhaaaab#...",
	"...#hhaaaaab#...",
	"...#haaaaaab#...",
	"...#haaaaabb#...",
	"....#aaabbb#....",
	".....######.....",
	"......#gg#......",
	"......#gg#......",
	"......#gg#......",
	"......#gg#......",
	".......##.......",
	"................",
	"................"]


## Draws a 16x16 icon from a mask: '#' the 0x72 outline, letters from `palette`.
func _mask(rows: Array, palette: Dictionary) -> Image:
	var image := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	for y in range(rows.size()):
		var row := str(rows[y])
		for x in range(mini(16, row.length())):
			var key := row[x]
			if key == "#": image.set_pixel(x, y, Color("1a1414"))
			elif palette.has(key): image.set_pixel(x, y, palette[key])
	return image


func _load(name: String) -> Image:
	var image := Image.load_from_file(ProjectSettings.globalize_path(SOURCE + name + ".png"))
	image.convert(Image.FORMAT_RGBA8)
	return image


func _save(image: Image, name: String) -> void:
	image.save_png(ProjectSettings.globalize_path(OUT + name + ".png"))


## New hue for coloured pixels (outlines and greys stay); `gem_only` changes
## only strongly coloured pixels (the gem of a staff, the potion's liquid).
func _recolour(image: Image, hue: float, saturation: float, value: float, gem_only: bool) -> void:
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var colour := image.get_pixel(x, y)
			if colour.a < 0.1: continue
			var limit := 0.45 if gem_only else 0.18
			if colour.s < limit or colour.v < 0.12: continue
			if gem_only and _woody(colour): continue
			var shifted := Color.from_hsv(colour.h if hue < 0.0 else hue, clampf(colour.s * saturation, 0.0, 1.0), clampf(colour.v * value, 0.0, 1.0), colour.a)
			image.set_pixel(x, y, shifted)


## Wood is brown: orange hues with low value; staffs keep their wood.
func _woody(colour: Color) -> bool:
	return colour.h > 0.03 and colour.h < 0.12 and colour.v < 0.6


## A blue identification crystal: a faceted diamond with a white glint.
func _crystal() -> Image:
	var image := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	var outline := Color("1a1414")
	var rows := [[7, 8], [6, 9], [5, 10], [4, 11], [3, 12], [3, 12], [4, 11], [5, 10], [6, 9], [7, 8]]
	for index in range(rows.size()):
		var y := 3 + index
		var left: int = rows[index][0]
		var right: int = rows[index][1]
		for x in range(left - 1, right + 2): image.set_pixel(x, y, outline)
	for index in range(rows.size()):
		var y := 3 + index
		var left: int = rows[index][0]
		var right: int = rows[index][1]
		for x in range(left, right + 1):
			var light := Color("8fd8e6") if x < (left + right) / 2 else Color("3f8fb8")
			if index < 3: light = light.lightened(0.25)
			image.set_pixel(x, y, light)
	image.set_pixel(6, 6, Color.WHITE)
	image.set_pixel(7, 5, Color.WHITE)
	image.set_pixel(6, 5, Color("e8fbff"))
	return image


## The curse-breaker stone: a grey river stone with a golden rune.
func _stone() -> Image:
	var image := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	var centre := Vector2(7.5, 8.5)
	for y in range(16):
		for x in range(16):
			var offset := (Vector2(x, y) - centre) / Vector2(6.5, 5.5)
			var distance := offset.length()
			if distance <= 1.0: image.set_pixel(x, y, Color("8a8f98").darkened(0.25 * maxf(0.0, offset.y)) if distance < 0.82 else Color("1a1414"))
	for point: Vector2i in [Vector2i(7, 5), Vector2i(7, 6), Vector2i(7, 7), Vector2i(7, 8), Vector2i(7, 9), Vector2i(7, 10), Vector2i(8, 7), Vector2i(9, 6), Vector2i(6, 9), Vector2i(5, 10), Vector2i(8, 11)]:
		image.set_pixel(point.x, point.y, Color("edbf75"))
	image.set_pixel(5, 6, Color("c9ced6"))
	image.set_pixel(4, 7, Color("c9ced6"))
	return image
