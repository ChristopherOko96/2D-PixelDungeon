extends SceneTree
## Layered hell rigs (src/rig/rig_library.gd, assets/data/hell_rigs.json):
## every part is its own full-frame PNG or flipbook, part fields carry attack
## lists, weakens and groups, the rig carries groups, points and its material,
## it is drawn at 5 world px per source px, hits map onto the layered parts,
## a half-written hell file is ignored, and the crypt rigs load exactly as
## before. Uses tests/fixtures/hell_rigs_fixture.json, painted into user://.

const RigLibrary = preload("res://src/rig/rig_library.gd")
const FIXTURE := "res://tests/fixtures/hell_rigs_fixture.json"
const FIXTURE_DIR := "user://hell_rigs_fixture/"
const WORK_DIR := "user://hell_rigs_fixture_library"
const DRAKE := "fixture_drake"
const DRAKE_IDS := ["body", "neck", "head", "jaw", "throat", "horns", "arm", "leg_far", "leg_near", "tail_1", "tail_2", "tail_3", "tail_flame", "wing_far", "wing_near", "mouth_flame"]
const CRYPT := ["knight", "skeleton", "necro", "big_zombie", "bone_colossus", "frost_corpse", "void", "bomber"]

# DATA CONTRACT of the generated hell_rigs.json (docs/HOELLE-RIGS.de.md).
const HELL_FORMS := ["drache1", "drache2", "drache3", "drache4"]
## PART IDS: the same id for the same body part in every form (BOSS-03).
const BASE_IDS := ["body", "neck", "head", "jaw", "arm", "leg_far", "leg_near", "tail_1", "tail_2", "tail_3", "tail_4", "tail_5", "tail_flame"]
const WINGED_IDS := ["wing_far", "wing_near", "throat", "horns"]
const VOID_IDS := ["crystal_1", "crystal_2", "crystal_3", "mouth_flame"]
const TAIL_REST := ["tail_3", "tail_4", "tail_5", "tail_flame"]
## SEVERABLE MAP: form -> part -> {disables, weakens, also_detach, exposed}
## (absent = none). Every other part must be unbreakable.
const SEVERABLE := {
	"drache1": {
		"jaw": {"disables": ["spucke"]},
		"arm": {"weakens": {"graben": {"ring": 0.5}}},
		"tail_2": {"weakens": {"huschen": {"speed": 0.6}, "satz": {"radius": 0.6}}, "also_detach": TAIL_REST},
	},
	"drache2": {
		"jaw": {"weakens": {"salve": {"count": 0.34}}},
		"tail_2": {"disables": ["schwanz"], "also_detach": TAIL_REST},
		"arm": {"weakens": {"lavabruch": {"ring": 0.5, "lava": 0.0}}},
	},
	"drache3": {
		"wing_far": {"weakens": {"bombenflug": {"duration": 0.5}}},
		"wing_near": {"weakens": {"bombenflug": {"duration": 0.5}}},
		"throat": {"exposed": "atem", "disables": ["atem"]},
		"horns": {"weakens": {"faecher": {"count": 0.43}}},
	},
	"drache4": {
		"crystal_1": {"weakens": {"strahlen": {"beams": 0.667}}},
		"crystal_2": {"weakens": {"strahlen": {"beams": 0.667}}},
		"crystal_3": {"weakens": {"strahlen": {"beams": 0.667}}},
		"wing_far": {"weakens": {"leerenregen": {"duration": 0.5}}},
		"wing_near": {"weakens": {"leerenregen": {"duration": 0.5}}},
		"throat": {"exposed": "atem", "disables": ["atem"]},
		"horns": {"weakens": {"echos": {"forms": 0.34}}},
	},
}
## Rig groups per form: all members lost -> these attacks are disabled.
const GROUPS := {
	"drache1": {},
	"drache2": {},
	"drache3": {"wings": {"parts": ["wing_far", "wing_near"], "disables": ["bombenflug"]}},
	"drache4": {"wings": {"parts": ["wing_far", "wing_near"], "disables": ["leerenregen"]},
		"crystals": {"parts": ["crystal_1", "crystal_2", "crystal_3"], "disables": ["strahlen"]}},
}
## Named points -> the part they sit on.
const POINTS := {"mouth": "jaw", "throat": "neck", "hand": "arm", "tail_tip": "tail_5", "core": "body"}

var checked := 0
var failures: Array[String] = []


func check(condition: bool, description: String) -> void:
	checked += 1
	if not condition:
		failures.append(description)
		printerr("HELL_RIG_LIBRARY_FAIL: ", description)


func _initialize() -> void:
	_clean(WORK_DIR)
	var fixture := _write_fixture(WORK_DIR)
	var library = RigLibrary.new()
	check(library.load_data(RigLibrary.DATA_PATH, fixture), "rigs.json and the hell fixture load together")
	_test_layered_rig_fields(library)
	_test_part_fields(library)
	_test_flipbook_frames(library)
	_test_groups_and_points(library)
	_test_scale_and_hits(library)
	_test_missing_images_are_tolerated(library)
	_test_crypt_rigs_unchanged(library)
	_test_broken_hell_file_is_ignored()
	_test_disabled_actions_normalises()
	_test_flawed_data_is_reported(library)
	_test_nearest_part_skips_parts_without_pixels(library)
	_test_hell_rig_never_replaces_a_crypt_rig()
	_test_real_hell_file()
	_clean(WORK_DIR)
	print("HELL_RIG_LIBRARY checked=%d failures=%d" % [checked, failures.size()])
	quit(1 if failures.size() > 0 else 0)


func _test_layered_rig_fields(library) -> void:
	var rig: Dictionary = library.rig(DRAKE)
	check(not rig.is_empty(), "the layered fixture rig is built")
	if rig.is_empty(): return
	check(str(rig.family) == "drake" and str(rig.variant) == "3" and str(rig.material) == "ember", "family drake, variant 3, material ember")
	check(bool(rig.get("layered", false)) and Array(rig.missing).is_empty(), "every fixture image loaded")
	check(Vector2(rig.size) == Vector2(16, 12), "the source frame is 16x12 (%s)" % str(rig.size))
	check(is_equal_approx(float(rig.scale), 5.0), "hell scale 2.5 x PIXEL_SCALE 2 = 5 world px per source px (%s)" % str(rig.scale))
	check(Vector2(rig.ground) == Vector2(7, 10) and is_equal_approx(float(rig.width), 10.0), "ground anchor and shadow width from the data")
	check(rig.parts.size() == DRAKE_IDS.size() and rig.items.is_empty(), "16 parts, no items")
	var all_ids := true
	for id: String in DRAKE_IDS: all_ids = all_ids and rig.by_id.has(id)
	check(all_ids, "by_id knows every part id")
	check(is_equal_approx(float(rig.top), 0.0), "top is the horns' row (union of all part images)")
	check(Vector2(rig.center).x > 4.0 and Vector2(rig.center).x < 12.0 and Vector2(rig.center).y > 2.0 and Vector2(rig.center).y < 9.0, "center lies inside the figure (%s)" % str(rig.center))
	check(is_equal_approx(float(rig.fps), 12.0) and is_equal_approx(float(rig.hover), 0.0), "fps from the data, no hover for drakes")
	for part: Dictionary in rig.parts:
		check(part.texture is Texture2D and part.white is Texture2D, "%s has a texture and a flash silhouette" % part.id)
		check(Rect2(part.bounds).has_area() and (part.image as Image).get_size() == Vector2i(16, 12), "%s owns pixels in a full-frame image" % part.id)


func _test_part_fields(library) -> void:
	var by_id: Dictionary = library.rig(DRAKE).get("by_id", {})
	if by_id.is_empty(): return
	var jaw: Dictionary = by_id.jaw
	check(jaw.disables is Array and _same(jaw.disables, ["spucke"]), "jaw disables is the array [spucke] (%s)" % str(jaw.disables))
	check(str(jaw.parent) == "head" and Vector2(jaw.pivot) == Vector2(11, 4) and int(jaw.z) == 16 and str(jaw.label) == "Kiefer", "jaw: parent, pivot, z and label")
	check(Rect2(jaw.bounds) == Rect2(11, 4, 3, 1), "jaw bounds come from its own PNG (%s)" % str(jaw.bounds))
	check(by_id.body.disables is Array and Array(by_id.body.disables).is_empty(), "a part without disables has an empty array")
	check(str(by_id.body.parent) == "" and bool(by_id.body.unbreakable), "body is the unbreakable root")
	check(is_equal_approx(float(by_id.arm.weakens.graben.ring), 0.5) and is_equal_approx(float(by_id.arm.weakens.lavabruch.lava), 0.0), "arm weakens graben.ring 0.5 and turns lavabruch.lava off")
	check(is_equal_approx(float(by_id.arm.regrow), 12.0), "arm regrows after 12 s")
	check(_same(by_id.tail_2.also_detach, ["tail_3", "tail_flame"]), "tail_2 takes tail_3 and the flame with it")
	check(str(by_id.throat.exposed) == "atem" and _same(by_id.throat.disables, ["atem"]), "throat is exposed during atem and disables it")
	check(str(by_id.wing_far.group) == "wings" and str(by_id.head.group) == "", "wing_far belongs to the wings group, the head to none")
	check(Dictionary(by_id.head.weakens).is_empty(), "a part without weakens has an empty dictionary")
	var weights: Dictionary = library.weights(DRAKE)
	var total := 0.0
	for weight: float in weights.values(): total += weight
	check(weights.size() == 15 and not weights.has("mouth_flame") and is_equal_approx(total, 159.0), "weights: 15 parts with hp > 0, decorative mouth flame left out, sum 159 (%d, %.1f)" % [weights.size(), total])


func _test_flipbook_frames(library) -> void:
	var by_id: Dictionary = library.rig(DRAKE).get("by_id", {})
	if by_id.is_empty(): return
	var flame: Dictionary = by_id.tail_flame
	check(flame.get("frames") is Array and flame.frames.size() == 4, "tail_flame is a 4-frame flipbook")
	if not flame.get("frames") is Array: return
	var textured := true
	for layer: Dictionary in flame.frames: textured = textured and layer.texture is Texture2D and layer.white is Texture2D
	check(textured, "every flame frame has a texture and a silhouette")
	check(Rect2(flame.frames[1].bounds) == Rect2(0, 3, 1, 2), "frame 1 keeps its own bounds (%s)" % str(flame.frames[1].bounds))
	check(Rect2(flame.bounds) == Rect2(0, 1, 2, 4), "the part's bounds are the union of all frames (%s)" % str(flame.bounds))
	var image: Image = flame.image
	check(image.get_pixel(0, 4).a > 0.5 and image.get_pixel(1, 2).a > 0.5 and image.get_pixel(0, 1).a > 0.5, "the hit image is the union of all frames")
	check(by_id.mouth_flame.frames.size() == 2 and is_equal_approx(float(by_id.mouth_flame.hp), 0.0), "mouth_flame: 2 frames, decorative (hp 0)")


func _test_groups_and_points(library) -> void:
	var rig: Dictionary = library.rig(DRAKE)
	if rig.is_empty(): return
	var wings: Dictionary = rig.groups.get("wings", {})
	check(_same(wings.get("parts", []), ["wing_far", "wing_near"]) and _same(wings.get("disables", []), ["bombenflug"]), "group wings: both wings, disables bombenflug (%s)" % str(wings))
	check(rig.points.size() == 5, "five named points")
	check(str(rig.points.mouth.part) == "jaw" and rig.points.mouth.at is Vector2 and Vector2(rig.points.mouth.at) == Vector2(13, 4), "points.mouth sits on the jaw at (13, 4) as a Vector2")
	check(str(rig.points.tail_tip.part) == "tail_3" and Vector2(rig.points.core.at) == Vector2(7, 6), "tail tip and core points")
	# foot_offset: world px from the feet (ground (7, 10), scale 5), facing right
	check(library.foot_offset(DRAKE, "mouth") == Vector2(30, -30) and library.foot_offset(DRAKE, "core") == Vector2(0, -20), "foot_offset: mouth (30, -30), core (0, -20) (%s, %s)" % [library.foot_offset(DRAKE, "mouth"), library.foot_offset(DRAKE, "core")])
	check(library.foot_offset(DRAKE, "feet") == Vector2.ZERO and library.foot_offset(DRAKE, "top") == Vector2(0, -50), "foot_offset: feet zero, top 50 px up (%s)" % library.foot_offset(DRAKE, "top"))
	check(library.foot_offset(DRAKE, "nose") == Vector2.INF and library.foot_offset("nobody", "mouth") == Vector2.INF, "foot_offset: unknown point or rig -> INF")


func _test_scale_and_hits(library) -> void:
	var rig: Dictionary = library.rig(DRAKE)
	if rig.is_empty(): return
	var origin := Vector2(400, 300)
	var shifted: Vector2 = library.to_source(DRAKE, origin, 1.0, origin + Vector2(5, 10))
	check(is_equal_approx(shifted.x, 8.0) and is_equal_approx(shifted.y, float(rig.center.y) + 2.0), "5 world px are one source px (%s)" % str(shifted))
	var alive: Dictionary = {}
	for id: String in DRAKE_IDS: alive[id] = true
	var jaw_world := _world(library, DRAKE, origin, 1.0, rig.by_id.jaw.center)
	check(library.part_at(DRAKE, origin, 1.0, jaw_world, alive) == "jaw", "a hit at the jaw's centre is a jaw hit")
	var mirrored := _world(library, DRAKE, origin, -1.0, rig.by_id.jaw.center)
	check(mirrored.x < origin.x and library.part_at(DRAKE, origin, -1.0, mirrored, alive) == "jaw", "facing left mirrors the layered part areas")
	var wing_world := _world(library, DRAKE, origin, 1.0, rig.by_id.wing_near.center)
	check(library.part_at(DRAKE, origin, 1.0, wing_world, alive) == "wing_near", "the near wing is hit at its centre")
	var throat_world := _world(library, DRAKE, origin, 1.0, rig.by_id.throat.center)
	check(library.part_at(DRAKE, origin, 1.0, throat_world, alive) != "throat", "outside its breath the throat cannot be hit")
	check(library.part_at(DRAKE, origin, 1.0, throat_world, alive, "atem") == "throat", "during atem the throat is hit")
	var far := origin + Vector2(400, -300)
	check(library.part_at(DRAKE, origin, 1.0, far, alive) == "", "a point far away hits nothing")
	check(library.nearest_part(DRAKE, origin, 1.0, far, alive) != "", "the nearest living part is found for area damage")
	check(library.nearest_part(DRAKE, origin, 1.0, far, {"arm": true}) == "arm", "only living parts are candidates")


func _test_missing_images_are_tolerated(library) -> void:
	var partial: Dictionary = library.rig("fixture_partial")
	check(not partial.is_empty(), "a rig with one missing image still builds")
	if not partial.is_empty():
		check(_same(partial.missing, ["ghost"]) and not Rect2(partial.by_id.ghost.bounds).has_area(), "the missing part is listed and has no pixels")
		check(_same(partial.by_id.ghost.disables, ["biss"]), "a single-string disables becomes a one-entry array in layered rigs")
		check(str(partial.material) == "obsidian" and is_equal_approx(float(partial.scale), 5.0), "material obsidian, scale 5")
		var crystals: Dictionary = partial.groups.get("crystals", {})
		check(_same(crystals.get("parts", []), ["crystal_1"]) and _same(crystals.get("disables", []), ["strahlen"]), "a part's group field joins the group's list (%s)" % str(crystals))
		check(Dictionary(partial.points).is_empty(), "no points: an empty dictionary")
	check(library.rig("fixture_empty").is_empty(), "a rig without any loadable image is skipped")
	check(library.rig("fixture_junk").is_empty(), "a malformed rig entry is skipped")


func _test_crypt_rigs_unchanged(library) -> void:
	var crypt_only = RigLibrary.new()
	check(crypt_only.load_data(RigLibrary.DATA_PATH, ""), "the crypt loads without any hell file")
	for name: String in CRYPT:
		var mine: Dictionary = library.rig(name)
		var theirs: Dictionary = crypt_only.rig(name)
		check(not mine.is_empty() and not theirs.is_empty(), "%s is still present" % name)
		if mine.is_empty() or theirs.is_empty(): continue
		check(is_equal_approx(float(mine.scale), float(theirs.scale)) and Vector2(mine.center) == Vector2(theirs.center) and is_equal_approx(float(mine.top), float(theirs.top)), "%s: scale, center and top unchanged by the hell file" % name)
		check(mine.parts.size() == theirs.parts.size() and not bool(mine.get("layered", false)), "%s: same parts, not layered" % name)
	check(str(library.rig("skeleton").by_id.weapon.disables) == "attack", "crypt disables stay the legacy string")
	check(not crypt_only.rigs.has(DRAKE), "a crypt-only load has no hell rigs")
	var hell_only = RigLibrary.new()
	check(hell_only.load_data("", _fixture_path(WORK_DIR)) and hell_only.rig("skeleton").is_empty() and not hell_only.rig(DRAKE).is_empty(), "an empty crypt path loads only the hell file")


func _test_broken_hell_file_is_ignored() -> void:
	var broken := WORK_DIR + "/broken.json"
	var file := FileAccess.open(broken, FileAccess.WRITE)
	file.store_string("{\"rigs\": {\"drache1\": {\"family\": \"drake\", \"parts\": [")
	file.close()
	var library = RigLibrary.new()
	check(library.load_data(RigLibrary.DATA_PATH, broken), "a half-written hell file does not fail the crypt")
	check(not library.rig("skeleton").is_empty() and library.rig("drache1").is_empty(), "crypt rigs load, the broken hell rig does not")
	var missing = RigLibrary.new()
	check(missing.load_data(RigLibrary.DATA_PATH, WORK_DIR + "/no_such_file.json") and not missing.rig("void").is_empty(), "a missing hell file adds nothing")


func _test_disabled_actions_normalises() -> void:
	check(_same(RigLibrary.disabled_actions("attack"), ["attack"]), "a string becomes one entry")
	check(RigLibrary.disabled_actions("").is_empty() and RigLibrary.disabled_actions(null).is_empty() and RigLibrary.disabled_actions([]).is_empty(), "empty, null and [] disable nothing")
	check(_same(RigLibrary.disabled_actions(["atem", "atem", "satz"]), ["atem", "satz"]), "duplicates collapse")


func _test_flawed_data_is_reported(library) -> void:
	var rig: Dictionary = library.rig("fixture_flawed")
	check(not rig.is_empty(), "a rig with data mistakes still builds")
	if rig.is_empty(): return
	check(str(rig.variant) == "4", "a numeric variant (JSON 4 parses as 4.0) becomes \"4\", not \"4.0\" (%s)" % str(rig.variant))
	var flame: Dictionary = rig.by_id.flame
	check(_same(rig.get("missing_frames", null), ["flame"]) and Array(flame.frames).size() == 1 and Array(rig.missing).is_empty(), "a flipbook with 1 of 3 frames is listed in missing_frames, not in missing (%s, %d frames)" % [str(rig.get("missing_frames", null)), Array(flame.frames).size()])
	check(_same(rig.get("clipped", null), ["oversized"]) and (rig.by_id.oversized.image as Image).get_size() == Vector2i(8, 8), "a 10x9 image in an 8x8 frame is clipped and listed in clipped (%s)" % str(rig.get("clipped", null)))
	var pair: Dictionary = rig.groups.get("pair", {})
	check(_same(pair.get("parts", []), ["wing_a"]) and _same(pair.get("disables", []), ["flug"]), "group members that can never be lost (hp 0, unknown id) are dropped (%s)" % str(pair))
	check(_same(rig.get("invalid_group_members", null), ["pair:wing_b", "pair:no_such_part"]), "and listed in invalid_group_members (%s)" % str(rig.get("invalid_group_members", null)))
	var clean: Dictionary = library.rig(DRAKE)
	check(_same(clean.get("missing_frames", null), []) and _same(clean.get("clipped", null), []) and _same(clean.get("invalid_group_members", null), []), "the clean fixture drake reports no flaw")
	check(str(clean.variant) == "3", "a string variant stays as it is")


func _test_nearest_part_skips_parts_without_pixels(library) -> void:
	if library.rig("fixture_partial").is_empty(): return
	var origin := Vector2(400, 300)
	var far := origin + Vector2(-400, -300)
	# The ghost's image is missing: its empty box sits at (0, 0), nearer to `far` than the body's box.
	check(library.nearest_part("fixture_partial", origin, 1.0, far, {"ghost": true, "body": true}) == "body", "area damage far away never picks a part nobody can see (missing image)")
	check(library.nearest_part("fixture_partial", origin, 1.0, far, {"ghost": true}) == "", "an invisible part alone offers no area target")


func _test_hell_rig_never_replaces_a_crypt_rig() -> void:
	var clash := WORK_DIR + "/clash.json"
	var entry := {"family": "drake", "variant": "1", "size": [16, 12], "scale": 2.5, "parts": [{"id": "body", "img": WORK_DIR + "/body.png", "hp": 10, "unbreakable": true}]}
	var file := FileAccess.open(clash, FileAccess.WRITE)
	file.store_string(JSON.stringify({"rigs": {"skeleton": entry, "clash_drake": entry}}))
	file.close()
	var library = RigLibrary.new()
	check(library.load_data(RigLibrary.DATA_PATH, clash), "a hell file with a crypt rig's name still loads")
	var skeleton: Dictionary = library.rig("skeleton")
	check(str(skeleton.get("family", "")) == "skeleton" and not bool(skeleton.get("layered", false)) and Dictionary(skeleton.get("by_id", {})).has("weapon"), "the crypt skeleton wins over a hell rig named skeleton (family %s)" % str(skeleton.get("family", "")))
	check(bool(library.rig("clash_drake").get("layered", false)), "the file's other rigs load")
	check(library.load_data(RigLibrary.DATA_PATH, clash) and bool(library.rig("clash_drake").get("layered", false)) and str(library.rig("skeleton").family) == "skeleton", "loading again refreshes hell rigs and still never replaces crypt rigs")


## The generated assets/data/hell_rigs.json against the DATA CONTRACT
## (docs/HOELLE-RIGS.de.md). Skipped only while the file does not exist; once
## it does, every form must build completely from imported PNGs (an export has
## no PNG files, only imports) with the contract's part ids, severable map,
## groups, points and HP shares. tools/hell_dungeon/check_rigs.js checks the
## same file from the generator's side (pixels, pivots, attack ids against
## hell_monsters.json); this test checks what the game builds from it.
func _test_real_hell_file() -> void:
	if not FileAccess.file_exists(RigLibrary.HELL_PATH):
		print("HELL_RIG_LIBRARY info: %s not generated yet, contract checks skipped" % RigLibrary.HELL_PATH)
		return
	var json := JSON.new()
	var parsed := json.parse(FileAccess.get_file_as_string(RigLibrary.HELL_PATH)) == OK and json.data is Dictionary and json.data.get("rigs") is Dictionary
	check(parsed, "hell_rigs.json parses and has rigs")
	if not parsed: return
	var raw: Dictionary = json.data.rigs
	var library = RigLibrary.new()
	library.load_data("", RigLibrary.HELL_PATH)
	for index in range(HELL_FORMS.size()):
		var name: String = HELL_FORMS[index]
		var rig: Dictionary = library.rig(name)
		check(not rig.is_empty() and raw.get(name) is Dictionary, "hell_rigs.json: %s is built" % name)
		if rig.is_empty() or not raw.get(name) is Dictionary: continue
		_check_form(name, index + 1, raw[name], rig, library.weights(name))
		_check_atlas_feet(name, rig, library)
		for leg: String in ["leg_far", "leg_near"]:
			var sole: Variant = rig.by_id[leg].get("sole")
			var image: Image = rig.by_id[leg].image
			check(sole is Array and sole.size() == 2 and Vector2(sole[0]).x < Vector2(sole[1]).x and is_equal_approx(Vector2(sole[0]).y, float(image.get_used_rect().end.y - 1)),
				"%s.%s: heel and toe on the foot's lowest row (%s)" % [name, leg, str(sole)])


## The atlas (hell_monsters.json drache<N>, its PNG read as a file) stands on
## the rig's feet: same scale, the idle frame's lowest opaque row is the
## frame's bottom row, and the rig's points from foot_offset land inside the
## frame around its bottom centre; so a host can aim from either one.
func _check_atlas_feet(name: String, rig: Dictionary, library) -> void:
	var monsters: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/hell_monsters.json"))
	if not monsters is Dictionary or not monsters.defs.has(name): return
	var def: Dictionary = monsters.defs[name]
	var px := int(def.px)
	var image := Image.load_from_file(ProjectSettings.globalize_path("res://assets/sprites/hell/monsters/%s.png" % name))
	check(image != null and not image.is_empty(), "%s: the atlas PNG loads" % name)
	if image == null or image.is_empty(): return
	var fw := int(def.w) * px
	var fh := int(def.h) * px
	var frame := image.get_region(Rect2i(0, int(def.anims.idle.row) * fh, fw, fh))
	var used := frame.get_used_rect()
	check(is_equal_approx(float(def.scale), float(rig.scale)) and used.end.y == fh, "%s: atlas scale %s = rig scale %s, the idle frame's feet on its bottom row (%d of %d)" % [name, def.scale, rig.scale, used.end.y, fh])
	var half := Vector2(float(def.w) * float(def.scale) * 0.5, float(def.h) * float(def.scale))
	for id: String in ["mouth", "core", "top"]:
		var at: Vector2 = library.foot_offset(name, id)
		check(absf(at.x) <= half.x and at.y <= 0.0 and -at.y <= half.y, "%s: %s at %s px from the feet lies inside the %dx%d world px atlas frame" % [name, id, at, int(half.x * 2.0), int(half.y)])


func _check_form(name: String, form: int, def: Dictionary, rig: Dictionary, weights: Dictionary) -> void:
	check(str(rig.family) == "drake" and str(rig.variant) == str(form), "%s: family drake, variant \"%d\" (%s, %s)" % [name, form, str(rig.family), str(rig.variant)])
	check(bool(rig.get("layered", false)) and is_equal_approx(float(rig.scale), 5.0), "%s: layered, 5 world px per source px (%s)" % [name, str(rig.scale)])
	var material := "obsidian" if form == 4 else "ember"
	check(str(rig.material) == material, "%s: material %s (%s)" % [name, material, str(rig.material)])
	var size: Variant = def.get("size")
	check(size is Array and Vector2(rig.size) == Vector2(float(size[0]), float(size[1])), "%s: the frame is the file's size (%s)" % [name, str(rig.size)])
	check(_same(rig.missing, []) and _same(rig.get("missing_frames", null), []) and _same(rig.get("clipped", null), []) and _same(rig.get("invalid_group_members", null), []),
		"%s: every image loads at the frame size and every group member can be lost (missing %s, frames %s, clipped %s, groups %s)" % [name, str(rig.missing), str(rig.get("missing_frames")), str(rig.get("clipped")), str(rig.get("invalid_group_members"))])
	var not_imported: Array[String] = []
	var string_disables: Array[String] = []
	for spec: Variant in def.get("parts", []):
		if not spec is Dictionary: continue
		var paths: Array = spec.frames if spec.get("frames") is Array else [spec.get("img", "")]
		for path: Variant in paths:
			if not ResourceLoader.exists(str(path)): not_imported.append(str(path).get_file())
		if spec.has("disables") and not spec.disables is Array: string_disables.append(str(spec.get("id", "?")))
	check(not_imported.is_empty(), "%s: every part PNG is imported, so it exists in an export (%s)" % [name, ", ".join(not_imported)])
	check(string_disables.is_empty(), "%s: disables are arrays in the file (%s)" % [name, ", ".join(string_disables)])
	var expected: Array = BASE_IDS + (WINGED_IDS if form >= 3 else []) + (VOID_IDS if form == 4 else [])
	var ids: Array = []
	for part: Dictionary in rig.parts: ids.append(str(part.id))
	check(_same_set(ids, expected), "%s: part ids match the contract (extra %s, missing %s)" % [name, str(_minus(ids, expected)), str(_minus(expected, ids))])
	var severable: Dictionary = SEVERABLE[name]
	for id: String in severable:
		var part: Dictionary = rig.by_id.get(id, {})
		check(not part.is_empty(), "%s: severable part %s exists" % [name, id])
		if part.is_empty(): continue
		var want: Dictionary = severable[id]
		check(not bool(part.unbreakable) and float(part.hp) > 0.0, "%s.%s is severable: hp > 0, not unbreakable" % [name, id])
		check(_same_set(part.disables, want.get("disables", [])), "%s.%s disables %s (%s)" % [name, id, str(want.get("disables", [])), str(part.disables)])
		check(_same_weakens(part.weakens, want.get("weakens", {})), "%s.%s weakens %s (%s)" % [name, id, str(want.get("weakens", {})), str(part.weakens)])
		check(_same_set(part.also_detach, want.get("also_detach", [])), "%s.%s alsoDetach %s (%s)" % [name, id, str(want.get("also_detach", [])), str(part.also_detach)])
		check(str(part.exposed) == str(want.get("exposed", "")), "%s.%s exposed \"%s\" (%s)" % [name, id, str(want.get("exposed", "")), str(part.exposed)])
	var breakable: Array[String] = []
	for part: Dictionary in rig.parts:
		if not severable.has(str(part.id)) and not bool(part.unbreakable): breakable.append(str(part.id))
	check(breakable.is_empty(), "%s: every other part is unbreakable (%s)" % [name, ", ".join(breakable)])
	var groups: Dictionary = GROUPS[name]
	check(_same_set(Dictionary(rig.groups).keys(), groups.keys()), "%s: groups %s (%s)" % [name, str(groups.keys()), str(Dictionary(rig.groups).keys())])
	for group_id: String in groups:
		var group: Dictionary = rig.groups.get(group_id, {})
		check(_same_set(group.get("parts", []), groups[group_id].parts) and _same_set(group.get("disables", []), groups[group_id].disables), "%s: group %s = %s, all lost disables %s (%s)" % [name, group_id, str(groups[group_id].parts), str(groups[group_id].disables), str(group)])
	# Parts that must be able to leave the body need HP (weights() lists hp > 0 only).
	var unlosable: Array[String] = []
	for part: Dictionary in rig.parts:
		for extra: Variant in part.also_detach:
			if float(rig.by_id.get(str(extra), {}).get("hp", 0.0)) <= 0.0: unlosable.append("%s alsoDetach %s" % [part.id, str(extra)])
	var raw_groups: Variant = def.get("groups", {})
	if raw_groups is Dictionary:
		for group_id: Variant in raw_groups:
			var members: Variant = raw_groups[group_id].get("parts", []) if raw_groups[group_id] is Dictionary else []
			for member: Variant in members:
				if float(rig.by_id.get(str(member), {}).get("hp", 0.0)) <= 0.0: unlosable.append("group %s member %s" % [str(group_id), str(member)])
	check(unlosable.is_empty(), "%s: every alsoDetach target and group member has hp > 0 (%s)" % [name, ", ".join(unlosable)])
	for point_id: String in POINTS:
		var point: Dictionary = rig.points.get(point_id, {})
		var at: Vector2 = point.get("at", Vector2(-1, -1))
		var ok: bool = str(point.get("part", "")) == str(POINTS[point_id]) and rig.by_id.has(str(point.get("part", ""))) and Rect2(Vector2.ZERO, Vector2(rig.size)).has_point(at)
		check(ok, "%s: point %s lies on %s inside the frame (%s)" % [name, point_id, str(POINTS[point_id]), str(point)])
	var total := 0.0
	for weight: float in weights.values(): total += weight
	var off: Array[String] = []
	var severable_share := 0.0
	for id: String in severable:
		var share := float(weights.get(id, 0.0)) / maxf(total, 0.001)
		severable_share += share
		if share < 0.08 - 0.0001 or share > 0.20 + 0.0001: off.append("%s %.1f %%" % [id, share * 100.0])
	check(off.is_empty(), "%s: each severable part is 8-20 %% of the weight (%s)" % [name, ", ".join(off)])
	check(severable_share <= 0.60 + 0.0001, "%s: all severable parts together <= 60 %% (%.1f %%)" % [name, severable_share * 100.0])
	var body := float(weights.get("body", 0.0))
	var heavier: Array[String] = []
	for id: String in weights:
		if id != "body" and not severable.has(id) and float(weights[id]) >= body: heavier.append(id)
	check(body > 0.0 and heavier.is_empty(), "%s: the body is the largest unbreakable weight (%.1f; not below: %s)" % [name, body, ", ".join(heavier)])
	# Wings carry their flap sign and swing range (rig_poses.gd turns them by
	# both); every other part leaves them out.
	var wing_fields: Array[String] = []
	for spec: Variant in def.get("parts", []):
		if not spec is Dictionary: continue
		var part: Dictionary = rig.by_id.get(str(spec.get("id", "")), {})
		if str(spec.id) in ["wing_far", "wing_near"]:
			var swing: Variant = spec.get("swing")
			var ok: bool = spec.has("flap") and swing is Array and swing.size() == 2 and is_equal_approx(float(part.get("flap", 0.0)), signf(float(spec.flap))) \
				and part.get("swing") is Vector2 and Vector2(part.swing).is_equal_approx(Vector2(float(swing[0]), float(swing[1])))
			if not ok: wing_fields.append("%s (%s, %s)" % [spec.id, part.get("flap"), part.get("swing")])
		elif part.has("flap") or part.has("swing"): wing_fields.append("%s has wing fields" % spec.id)
	check(wing_fields.is_empty(), "%s: wings load flap and swing from the file, no other part has them (%s)" % [name, ", ".join(wing_fields)])


# --------------------------------------------------------------- helpers

## Inverse of RigLibrary.to_source for a source point.
func _world(library, name: String, origin: Vector2, face: float, source: Vector2) -> Vector2:
	var rig: Dictionary = library.rig(name)
	return Vector2(origin.x + (source.x - rig.ground.x) * float(rig.scale) * (-1.0 if face < 0 else 1.0), origin.y + (source.y - rig.center.y - rig.hover) * float(rig.scale))


func _same(a: Variant, b: Array) -> bool:
	if not a is Array or Array(a).size() != b.size(): return false
	for i in range(b.size()):
		if str(a[i]) != str(b[i]): return false
	return true


## Same entries in any order (as strings); `a` must be an Array.
func _same_set(a: Variant, b: Array) -> bool:
	if not a is Array or Array(a).size() != b.size(): return false
	return _minus(a, b).is_empty() and _minus(b, a).is_empty()


## Entries of `a` missing from `b` (as strings).
func _minus(a: Array, b: Array) -> Array[String]:
	var names: Array[String] = []
	for entry: Variant in b: names.append(str(entry))
	var result: Array[String] = []
	for entry: Variant in a:
		if not str(entry) in names: result.append(str(entry))
	return result


## {attack: {param: factor}} equal to the expected one (factors to 0.001).
func _same_weakens(actual: Variant, expected: Dictionary) -> bool:
	if not actual is Dictionary or not _same_set(Dictionary(actual).keys(), expected.keys()): return false
	for action: String in expected:
		var params: Variant = actual[action]
		if not params is Dictionary or not _same_set(Dictionary(params).keys(), Dictionary(expected[action]).keys()): return false
		for param: String in expected[action]:
			if absf(float(params[param]) - float(expected[action][param])) > 0.001: return false
	return true


func _fixture_path(dir: String) -> String:
	return dir + "/hell_rigs.json"


## Copies the fixture into `dir` (paths rewritten) and paints its PNGs.
func _write_fixture(dir: String) -> String:
	DirAccess.make_dir_recursive_absolute(dir)
	var text := FileAccess.get_file_as_string(FIXTURE).replace(FIXTURE_DIR, dir + "/")
	var data: Variant = JSON.parse_string(text)
	if data is Dictionary:
		for name: String in data.rigs:
			var def: Variant = data.rigs[name]
			if not def is Dictionary: continue
			var size := Vector2i(int(def.size[0]), int(def.size[1]))
			for spec: Dictionary in def.get("parts", []):
				var color := Color(str(spec.get("_color", "#c0502a")))
				var own := Vector2i(int(spec._size[0]), int(spec._size[1])) if spec.has("_size") else size
				if spec.has("_rects"): _paint(str(spec.img), own, spec._rects, color)
				if spec.has("_frame_rects"):
					# Frames without rects stay unwritten (missing flipbook frames).
					for i in range(mini(spec.frames.size(), spec._frame_rects.size())): _paint(str(spec.frames[i]), own, spec._frame_rects[i], color)
	var file := FileAccess.open(_fixture_path(dir), FileAccess.WRITE)
	file.store_string(text)
	file.close()
	return _fixture_path(dir)


func _paint(path: String, size: Vector2i, rects: Array, color: Color) -> void:
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	for rect: Array in rects:
		for y in range(int(rect[1]), int(rect[3]) + 1):
			for x in range(int(rect[0]), int(rect[2]) + 1): image.set_pixel(x, y, color)
	image.save_png(path)


func _clean(dir: String) -> void:
	if not DirAccess.dir_exists_absolute(dir): return
	for name: String in DirAccess.get_files_at(dir): DirAccess.remove_absolute(dir + "/" + name)
	DirAccess.remove_absolute(dir)
