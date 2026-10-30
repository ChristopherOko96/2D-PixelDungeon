extends SceneTree
## The 0x72 enemy and boss variants (candidates, not in the game):
## production/qa/evidence/0x72-variants/rigs_variants.json, written by
## `node production/art-proof/0x72-style/export_rigs.js --variants`. Every
## roster rig loads through RigLibrary with positive part weights in a pose
## family the game has; every opaque source pixel lands in exactly one part;
## the recolour is an exact palette swap (alpha mask unchanged, each pixel
## either kept or mapped by the declared hex map, outline untouched); every
## part and item moves on its own in some clip; the part rules hold in
## BodyParts (vital head, unbreakable boss body, weapons/arms/staffs that
## disable and regrow); the renderer draws them. And the game's own rigs.json
## is unchanged: part ids, pivots, weights and flags as before the variants.

const RigLibrary = preload("res://src/rig/rig_library.gd")
const RigPoses = preload("res://src/rig/rig_poses.gd")
const RigRenderer = preload("res://src/rig/rig_renderer.gd")
const BodyParts = preload("res://src/combat/body_parts.gd")
const VARIANTS := "res://production/qa/evidence/0x72-variants/rigs_variants.json"
const RIGS := "res://assets/data/rigs.json"
const HELL_MONSTERS := "res://assets/data/hell_monsters.json"
const HELL_RIGS := "res://assets/data/hell_rigs.json"
const ROSTER: Array[String] = ["crypt_zombie", "crypt_bone_lancer", "crypt_cultist", "crypt_plague_doctor", "crypt_corpse_ogre", "crypt_soul_eater",
	"frost_ice_elf", "frost_ice_elf_f", "frost_frostling", "frost_ice_goblin", "frost_shaman", "frost_necro", "frost_giant", "frost_demon",
	"hell_chort", "hell_wogol", "hell_orc", "hell_pumpkin", "hell_glutkoloss", "hell_ogre", "hell_archdemon"]
## Pose families of src/rig/rig_poses.gd the variants may use (no new family).
const FAMILIES: Array[String] = ["skeleton", "necro", "biped", "brute"]
## rigs.json before the variants (29.10.2026): family, variant, then per part
## (items last) "id|pivot or hand|hp|flags" (v vital, u unbreakable,
## d:<action> disables, r<s> regrow, a takes the legs along).
const EXPECTED := {
	"knight": ["hero", "", "foot_l|5,25|0|", "foot_r|10,25|0|", "plume|6,12|0|", "body|8,25|0|", "weapon|13,21|0|"],
	"elf": ["hero", "", "foot_l|4,26|0|", "foot_r|9,26|0|", "body|7,25|0|", "head|7,21|0|", "weapon|14,22|0|"],
	"wizard": ["hero", "", "robe|8,27|0|", "head|8,23|0|", "hat|8,16|0|", "weapon|14,22|0|"],
	"skeleton": ["skeleton", "sword", "leg_l|6,14|2|", "leg_r|10,14|2|", "torso|8,13|3|a", "skull|8,10|3|v", "weapon|11,13|1|d:attack"],
	"skel_archer": ["skeleton", "bow", "leg_l|6,14|2|", "leg_r|10,14|2|", "torso|8,13|3|a", "skull|8,10|3|v", "weapon|12,12|1|d:attack"],
	"skel_guard": ["skeleton", "guard", "leg_l|6,14|2|", "leg_r|10,14|2|", "torso|8,13|3|a", "skull|8,10|3|v", "weapon|5,13|1|d:attack", "shield|12,11|3|d:block"],
	"necro": ["necro", "", "robe|7,22|6|v", "hood|7,19|6|v", "weapon|14,17|2|d:cast"],
	"tiny_zombie": ["biped", "", "foot_l|6,13|1|", "foot_r|10,13|1|", "head|8,13|2|v"],
	"ice_zombie": ["skeleton", "", "leg_l|6,14|2|", "leg_r|10,14|2|", "torso|8,13|3|a", "skull|8,10|3|v"],
	"big_zombie": ["brute", "", "arm|12,17|20|d:attackr6", "leg_l|11,29|15|u", "leg_r|20,29|15|u", "head|18,21|30|u", "torso|16,28|40|u"],
	"frost_corpse": ["brute", "", "arm|12,17|20|d:attackr6", "leg_l|11,29|15|u", "leg_r|20,29|15|u", "head|18,21|30|u", "torso|16,28|40|u"],
	"bone_colossus": ["brute", "", "arm|12,17|20|d:attackr6", "leg_l|11,29|15|u", "leg_r|20,29|15|u", "head|18,21|30|u", "torso|16,28|40|u"],
	"void": ["core||90|u", "eye||20|d:beamr12", "claw_l||15|d:summonr8", "claw_r||15|d:castr8"],
	"bomber": ["skull||1|v"],
	"mimic": ["body||1|v"],
}

var checked := 0
var failures: Array[String] = []
var _canvas: Node2D
var _pending: Dictionary = {}


func check(condition: bool, description: String) -> void:
	checked += 1
	if not condition:
		failures.append(description)
		printerr("RIG_VARIANTS_FAIL: ", description)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(VARIANTS))
	check(data is Dictionary and data.get("rigs") is Dictionary, "the variant candidates file parses")
	if not data is Dictionary:
		_finish()
		return
	var library = RigLibrary.new()
	check(library.load_data(VARIANTS, ""), "RigLibrary loads the variant candidates")
	_test_existing_rigs_unchanged()
	_test_roster(library, data)
	_test_pixels_and_recolour(library, data)
	_test_every_part_moves(library)
	_test_part_rules(library)
	await _test_renderer_draws(library)
	_finish()


func _finish() -> void:
	print("RIG_VARIANTS checked=%d failures=%d" % [checked, failures.size()])
	quit(1 if failures.size() > 0 else 0)


# ------------------------------------------------------------------ rigs.json

static func _signature(spec: Dictionary) -> String:
	var at: Variant = spec.get("pivot", spec.get("hand", []))
	var place := "%d,%d" % [int(at[0]), int(at[1])] if at is Array and at.size() >= 2 else ""
	var flags := ("v" if bool(spec.get("vital", false)) else "") + ("u" if bool(spec.get("unbreakable", false)) else "")
	if spec.get("disables") != null and not str(spec.get("disables", "")).is_empty(): flags += "d:" + str(spec.disables)
	if float(spec.get("regrow", 0)) > 0.0: flags += "r%d" % int(spec.regrow)
	if spec.has("alsoDetach"): flags += "a"
	return "%s|%s|%d|%s" % [str(spec.get("id", "")), place, int(spec.get("hp", 0)), flags]


func _test_existing_rigs_unchanged() -> void:
	var game: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(RIGS))
	var found: Dictionary = {}
	for name: String in game.rigs:
		var rig: Dictionary = game.rigs[name]
		var row: Array = [str(rig.get("family", "")), str(rig.get("variant", ""))]
		for spec: Dictionary in Array(rig.get("parts", [])) + Array(rig.get("items", [])): row.append(_signature(spec))
		found[name] = row
	for extra: String in ["void", "bomber", "mimic"]:
		var row: Array = []
		for id: String in game[extra].parts:
			var spec: Dictionary = Dictionary(game[extra].parts[id]).duplicate()
			spec.id = id
			row.append(_signature(spec))
		found[extra] = row
	check(found.keys().size() == EXPECTED.keys().size(), "rigs.json still holds exactly the %d game rigs (%s)" % [EXPECTED.size(), found.keys()])
	for name: String in EXPECTED:
		check(found.get(name, []) == EXPECTED[name], "rigs.json %s is unchanged: %s" % [name, found.get(name, [])])
	for name: String in ROSTER: check(not game.rigs.has(name), "candidate %s is not in the game's rigs.json (proof gate)" % name)
	var shipped = RigLibrary.new()
	check(shipped.load_data(RIGS, ""), "the game's rigs.json still loads")
	for name: String in EXPECTED: check(not shipped.rig(name).is_empty(), "game rig %s still builds" % name)


# ------------------------------------------------------------------ roster

func _test_roster(library: RefCounted, data: Dictionary) -> void:
	check(Array(data.rigs.keys()) == Array(ROSTER), "the candidates are exactly the 21 roster rigs, in order")
	var taken: Dictionary = {}
	var monsters: Variant = JSON.parse_string(FileAccess.get_file_as_string(HELL_MONSTERS)) if FileAccess.file_exists(HELL_MONSTERS) else {}
	if monsters is Dictionary and monsters.get("defs") is Dictionary:
		for id: String in monsters.defs: taken[id] = true
	var hell_rigs: Variant = JSON.parse_string(FileAccess.get_file_as_string(HELL_RIGS)) if FileAccess.file_exists(HELL_RIGS) else {}
	if hell_rigs is Dictionary and hell_rigs.get("rigs") is Dictionary:
		for id: String in hell_rigs.rigs: taken[id] = true
	for id: String in ["drache1", "drache2", "drache3", "drache4"]: taken[id] = true
	for name: String in ROSTER:
		var rig: Dictionary = library.rig(name)
		var meta: Dictionary = data.get("roster", {}).get(name, {})
		check(not rig.is_empty(), "%s builds" % name)
		if rig.is_empty(): continue
		check(str(rig.family) in FAMILIES, "%s uses an existing pose family (%s)" % [name, rig.family])
		check(name.begins_with(str(meta.get("world", "?")) + "_") and not str(meta.get("name", "")).is_empty(), "%s carries its world prefix and a German name" % name)
		check(not taken.has(name), "%s clashes with no hell monster or hell rig" % name)
		var weights: Dictionary = library.weights(name)
		var all_positive := not weights.is_empty()
		for id: String in weights: all_positive = all_positive and float(weights[id]) > 0.0
		check(all_positive and weights.size() == rig.parts.size() + rig.items.size(), "%s: every part and item has a positive HP weight %s" % [name, weights])
		var vital_or_boss := false
		for part: Dictionary in rig.parts: vital_or_boss = vital_or_boss or bool(part.vital) or bool(part.unbreakable)
		check(vital_or_boss, "%s has a vital part or an unbreakable boss body" % name)
		var factor := float(data.get("scales", {}).get(name, 1.0))
		check(is_equal_approx(float(rig.scale), RigLibrary.PIXEL_SCALE * factor), "%s is drawn at %.1f world px per source px" % [name, RigLibrary.PIXEL_SCALE * factor])
		if str(meta.get("role", "")) in ["miniboss", "boss"]:
			var rule := true
			for part: Dictionary in rig.parts + rig.items:
				var disables: Array[String] = RigLibrary.disabled_actions(part.disables)
				if disables.is_empty(): rule = rule and bool(part.unbreakable) and not bool(part.vital)
				else: rule = rule and float(part.regrow) > 0.0
			check(rule, "%s (boss): body unbreakable, only arm/staff breaks and regrows" % name)


# ------------------------------------------------------------------ pixels

func _source(data: Dictionary, key: String) -> Image:
	var image: Image = load(str(data.images[key])).get_image()
	image = image.duplicate()
	if image.is_compressed(): image.decompress()
	image.convert(Image.FORMAT_RGBA8)
	return image


func _test_pixels_and_recolour(library: RefCounted, data: Dictionary) -> void:
	for name: String in ROSTER:
		var rig: Dictionary = library.rig(name)
		var spec: Dictionary = data.rigs[name]
		if rig.is_empty(): continue
		var source := _source(data, str(spec.img))
		var mapping: Dictionary = {}
		var recolor: Variant = spec.get("recolor")
		if recolor is Dictionary:
			for from: String in recolor: mapping[from.trim_prefix("#").to_lower()] = str(recolor[from]).trim_prefix("#").to_lower()
		check(not mapping.has("222222"), "%s never recolours the outline" % name)
		var used: Dictionary = {}
		var mask_ok := true
		var colour_ok := true
		var once_ok := true
		var opaque := 0
		for y in range(source.get_height()):
			for x in range(source.get_width()):
				var original := source.get_pixel(x, y)
				var owners := 0
				var drawn := Color(0, 0, 0, 0)
				for part: Dictionary in rig.parts:
					var image: Image = part.image
					var pixel := image.get_pixel(x, y)
					if pixel.a >= 0.5:
						owners += 1
						drawn = pixel
				if original.a < 0.5:
					mask_ok = mask_ok and owners == 0
					continue
				opaque += 1
				once_ok = once_ok and owners == 1
				var key := original.to_html(false).to_lower()
				if mapping.has(key): used[key] = true
				var expected: String = mapping.get(key, key)
				colour_ok = colour_ok and owners == 1 and drawn.to_html(false).to_lower() == expected
		check(mask_ok, "%s: the parts draw no pixel where the 0x72 frame is transparent (alpha mask unchanged)" % name)
		check(once_ok and opaque > 0, "%s: each of the %d opaque source pixels lands in exactly one part" % [name, opaque])
		check(colour_ok, "%s: every pixel keeps its colour or takes the declared swap only" % name)
		check(used.size() == mapping.size(), "%s: every hex in the recolour map occurs in the frame (%s of %s)" % [name, used.keys(), mapping.keys()])


# ------------------------------------------------------------------ motion

## A pose state of an actor (see RigRenderer._actor).
static func _state(t: float, moving: bool, clip: String, u: float, regrowing: Dictionary = {}) -> Dictionary:
	return {"t": t, "moving": moving, "clip": clip, "u": u, "ct": u, "lost": {}, "regrowing": regrowing, "rise_from": {}}


static func _moved(entry: Dictionary) -> bool:
	return absf(float(entry.get("dx", 0.0))) > 0.01 or absf(float(entry.get("dy", 0.0))) > 0.01 or absf(float(entry.get("rot", 0.0))) > 0.005 \
		or absf(float(entry.get("sx", 1.0)) - 1.0) > 0.005 or absf(float(entry.get("sy", 1.0)) - 1.0) > 0.005


func _test_every_part_moves(library: RefCounted) -> void:
	for name: String in ROSTER:
		var rig: Dictionary = library.rig(name)
		if rig.is_empty(): continue
		var states: Array = []
		for i in range(24):
			var t := 0.07 * float(i)
			states.append(_state(t, false, "", 0.0))
			states.append(_state(t, true, "", 0.0))
		var clips: Array[String] = ["attack", "hit"]
		match str(rig.family):
			"necro": clips.append("summon")
			"brute": clips.append("roar")
			"skeleton":
				if str(rig.variant) == "guard": clips.append("block")
		for clip in clips:
			for i in range(1, 20): states.append(_state(0.3, false, clip, 0.05 * float(i)))
		var whole_moves := false
		var moved: Dictionary = {}
		for a: Dictionary in states:
			var pose: Dictionary = RigPoses.pose(rig, a)
			whole_moves = whole_moves or _moved(pose.whole)
			for id: String in pose.parts:
				if _moved(pose.parts[id]): moved[id] = true
			for id: String in pose.items:
				if _moved(pose.items[id]): moved[id] = true
		# Skeletons move part by part only (like the crypt skeleton); the others also sway as a whole.
		check(whole_moves or str(rig.family) == "skeleton", "%s: the whole figure breathes, walks and strikes" % name)
		for part: Dictionary in rig.parts + rig.items:
			# A root part without its own entry rides the whole-body motion (brute torso).
			var own: bool = moved.has(part.id)
			check(own or (str(part.parent).is_empty() and whole_moves), "%s: part %s moves on its own" % [name, part.id])
			if str(rig.family) != "brute" or part.id != "torso": check(own, "%s: part %s has its own animation" % [name, part.id])


# ------------------------------------------------------------------ host rules

static func _enemy(id: int, max_hp: float) -> Dictionary:
	return {"id": id, "pos": Vector2(400, 300), "hp": max_hp, "max_hp": max_hp, "face": 1.0, "radius": 13.0}


func _test_part_rules(library: RefCounted) -> void:
	var parts = BodyParts.new(library)
	parts.reset(4242)
	# Grabzombie: crypt skeleton rules on the 0x72 zombie.
	var zombie := _enemy(1, 10.0)
	parts.attach(zombie, "crypt_zombie")
	var hit: Dictionary = parts.damage(zombie, 3.0, "torso")
	check(hit.destroyed and "leg_l" in zombie.parts_lost and "leg_r" in zombie.parts_lost, "Grabzombie: a broken torso takes both legs along")
	hit = parts.damage(zombie, 3.0, "skull")
	check(hit.killed, "Grabzombie: the head is vital")
	# Knochenlanzer: the lance disables the attack.
	var lancer := _enemy(2, 11.0)
	parts.attach(lancer, "crypt_bone_lancer")
	parts.damage(lancer, 1.0, "weapon")
	check(not parts.can(lancer, "attack"), "Knochenlanzer: without the lance no attack")
	# Kultist (16x23): legs break, the torso never does.
	var cultist := _enemy(3, 30.0)
	parts.attach(cultist, "crypt_cultist")
	parts.damage(cultist, 5.0, "leg_l")
	parts.damage(cultist, 5.0, "leg_r")
	check(is_equal_approx(parts.speed_scale(cultist), 0.35), "Kultist: without legs it crawls at 35 %")
	hit = parts.damage(cultist, 12.0, "torso")
	check(not hit.destroyed and not "torso" in cultist.parts_lost, "Kultist: the tall torso is unbreakable (no floating head hop)")
	# Eisgoblin: the crypt guard rule.
	var goblin := _enemy(4, 12.0)
	parts.attach(goblin, "frost_ice_goblin")
	parts.damage(goblin, 3.0, "shield")
	check(not parts.can(goblin, "block") and parts.can(goblin, "attack"), "Eisgoblin: a broken shield stops the block only")
	# Eiself: unbreakable legs, the bow disables the shot.
	var elf := _enemy(5, 11.0)
	parts.attach(elf, "frost_ice_elf")
	hit = parts.damage(elf, 4.0, "leg_l")
	check(not hit.destroyed, "Eiself: the 16x28 legs never break")
	parts.damage(elf, 2.0, "weapon")
	check(not parts.can(elf, "attack"), "Eiself: without the bow no shot")
	# Frostnekromant: the staff (an item) breaks, casting pauses and the staff regrows.
	var necro := _enemy(6, 140.0)
	parts.attach(necro, "frost_necro")
	hit = parts.damage(necro, 60.0, "hood")
	check(not hit.destroyed and not hit.killed, "Frostnekromant: the hood is unbreakable, only the total HP kills")
	hit = parts.damage(necro, 30.0, "weapon")
	check(hit.destroyed and not parts.can(necro, "cast"), "Frostnekromant: a broken staff stops the casting")
	parts.step(necro, 7.9)
	check(not parts.can(necro, "cast"), "Frostnekromant: the staff is still gone after 7.9 s")
	parts.step(necro, 0.2)
	check(parts.can(necro, "cast") and not "weapon" in necro.parts_lost, "Frostnekromant: the staff (an item) regrows after 8 s")
	# Bosses on the shared cuts: the arm breaks and regrows, the rest never breaks.
	for name: String in ["crypt_corpse_ogre", "frost_giant", "hell_ogre", "crypt_soul_eater", "frost_demon", "hell_archdemon", "hell_glutkoloss"]:
		var boss := _enemy(7, 120.0)
		parts.attach(boss, name)
		hit = parts.damage(boss, 50.0, "head")
		check(not hit.destroyed and not hit.killed and parts.can(boss, "attack"), "%s: the head takes damage but never breaks" % name)
		hit = parts.damage(boss, 30.0, "arm")
		check(hit.destroyed and not parts.can(boss, "attack"), "%s: a severed arm/claw stops the attack" % name)
		parts.step(boss, 6.1)
		check(parts.can(boss, "attack"), "%s: the arm/claw grows back after 6 s" % name)
		hit = parts.damage(boss, 500.0, "torso")
		check(hit.killed and not hit.destroyed, "%s: only the total HP kills" % name)


# ------------------------------------------------------------------ renderer

func _on_draw() -> void:
	if _pending.has("enemy"): _pending.top = _pending.renderer.draw_enemy(_canvas, _pending.enemy, Vector2(400, 300))


func _draw(renderer: RefCounted, enemy: Dictionary) -> float:
	_pending = {"renderer": renderer, "enemy": enemy, "top": NAN}
	_canvas.queue_redraw()
	await process_frame
	await process_frame
	var top: float = _pending.top
	_pending = {}
	return top


func _test_renderer_draws(library: RefCounted) -> void:
	_canvas = Node2D.new()
	root.add_child(_canvas)
	_canvas.draw.connect(_on_draw)
	var uid := 500
	for name: String in ROSTER:
		var rig: Dictionary = library.rig(name)
		if rig.is_empty(): continue
		var renderer = RigRenderer.new(library)
		uid += 1
		var enemy := {"uid": uid, "rig": name, "face": 1.0}
		var top: float = await _draw(renderer, enemy)
		var shown: Dictionary = renderer.last_drawn("e%d" % uid).get("shown", {})
		var all_shown := not is_nan(top)
		for part: Dictionary in rig.parts + rig.items: all_shown = all_shown and shown.has(part.id)
		check(all_shown, "%s: the renderer draws every part and item (%s)" % [name, shown.keys()])
		# The part that disables the attack or the cast, cut off.
		var cut := ""
		for part: Dictionary in rig.parts + rig.items:
			if not str(part.disables).is_empty() and not bool(part.unbreakable): cut = str(part.id)
		if cut.is_empty(): continue
		renderer.observe({"enemies": [{"uid": uid, "rig": name, "lost": [cut]}]})
		await _draw(renderer, enemy)
		shown = renderer.last_drawn("e%d" % uid).get("shown", {})
		check(not shown.has(cut) and shown.size() == rig.parts.size() + rig.items.size() - 1, "%s: without %s the rest is still drawn" % [name, cut])
	_canvas.queue_free()
