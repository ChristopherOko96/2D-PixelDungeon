extends SceneTree
## Hell body parts (src/combat/body_parts.gd on a layered rig): the parts add
## up to the HP, a severed part disables the attacks it lists, a group (both
## wings) disables only once every member is gone, lost parts weaken attacks
## (factors multiply), the throat is only hittable during its breath, pending
## hits are keyed by uid, alsoDetach drops the tail's tip, unbreakable parts
## never break and a regrown part returns after 12 s with half its HP. The
## crypt's single-string disables keep working. Fixture:
## tests/fixtures/hell_rigs_fixture.json, painted into a folder of its own in
## the OS temp directory (never the player's user:// data) and removed.

const RigLibrary = preload("res://src/rig/rig_library.gd")
const BodyParts = preload("res://src/combat/body_parts.gd")
const FIXTURE := "res://tests/fixtures/hell_rigs_fixture.json"
## The fixture's own image folder token, rewritten to the work folder.
const FIXTURE_DIR := "user://hell_rigs_fixture/"
const DRAKE := "fixture_drake"
## OS temp folder of this run (per process, so parallel runs never meet).
var WORK_DIR := OS.get_temp_dir().path_join("pixeldungeon_hell_rigs_fixture_weakens_%d" % OS.get_process_id())
## Sum of the fixture drake's hp weights: every part's share equals its weight.
const DRAKE_TOTAL := 159.0
var checked := 0
var failures: Array[String] = []
var library
var parts


func check(condition: bool, description: String) -> void:
	checked += 1
	if not condition:
		failures.append(description)
		printerr("BODY_PARTS_WEAKENS_FAIL: ", description)


func _enemy(uid: int, rig: String = DRAKE, max_hp: float = DRAKE_TOTAL) -> Dictionary:
	var enemy := {"id": rig, "uid": uid, "pos": Vector2(400, 300), "hp": max_hp, "max_hp": max_hp, "face": 1.0, "radius": 13.0}
	parts.attach(enemy, rig)
	return enemy


func _initialize() -> void:
	_clean(WORK_DIR)
	library = RigLibrary.new()
	library.load_data(RigLibrary.DATA_PATH, _write_fixture(WORK_DIR))
	parts = BodyParts.new(library)
	parts.reset(99)
	check(not library.rig(DRAKE).is_empty(), "the fixture drake is loaded")
	if not library.rig(DRAKE).is_empty():
		_test_attach_splits_hp_by_weight()
		_test_severed_jaw_disables_its_attack()
		_test_group_disables_only_when_all_lost()
		_test_alsodetach_and_weakens_the_tail()
		_test_unbreakable_parts_never_break()
		_test_exposed_throat_only_during_its_breath()
		_test_pending_hits_are_keyed_by_uid()
		_test_regrow_returns_half_hp_after_12s()
		_test_group_from_part_fields_and_string_disables()
		_test_fallback_never_hits_a_hidden_part()
		_test_fallback_skips_parts_without_pixels()
		_test_group_ignores_members_that_cannot_be_lost()
		_test_carrier_and_enemy_regrow()
	_test_crypt_fallback_sequence_unchanged()
	_test_crypt_string_disables_still_work()
	_test_enemies_without_parts()
	_clean(WORK_DIR)
	print("BODY_PARTS_WEAKENS checked=%d failures=%d" % [checked, failures.size()])
	quit(1 if failures.size() > 0 else 0)


func _test_attach_splits_hp_by_weight() -> void:
	var drake := _enemy(1)
	check(parts.has_parts(drake) and is_equal_approx(float(drake.hp), DRAKE_TOTAL), "attached parts add up to the drake's HP")
	check(drake.parts.size() == 15 and not drake.parts.has("mouth_flame"), "15 parts carry HP, the decorative mouth flame none")
	check(is_equal_approx(float(drake.parts.jaw.max), 15.0) and is_equal_approx(float(drake.parts.body.max), 40.0), "each part gets its weight's share")
	check(Array(drake.parts_lost).is_empty() and parts.can(drake, "spucke") and is_equal_approx(parts.scale(drake, "graben", "ring"), 1.0), "an intact drake can do everything at full strength")


func _test_severed_jaw_disables_its_attack() -> void:
	var drake := _enemy(2)
	var hit: Dictionary = parts.damage(drake, 15.0, "jaw")
	check(hit.destroyed and not hit.killed and "jaw" in drake.parts_lost, "the jaw is severed by its share")
	check(not parts.can(drake, "spucke") and parts.can(drake, "graben") and parts.can(drake, "atem"), "without its jaw the drake cannot spit, everything else still works")
	check(is_equal_approx(float(drake.hp), DRAKE_TOTAL - 15.0), "the hit counts against the total")


func _test_group_disables_only_when_all_lost() -> void:
	var drake := _enemy(3)
	check(parts.damage(drake, 12.0, "wing_far").destroyed, "the far wing is severed")
	check(parts.can(drake, "bombenflug"), "one wing lost: the bombing run still flies")
	check(is_equal_approx(parts.scale(drake, "bombenflug", "duration"), 0.5), "one wing lost: half the flight duration")
	check(parts.damage(drake, 12.0, "wing_near").destroyed, "the near wing is severed")
	check(not parts.can(drake, "bombenflug"), "both wings lost: the group disables the bombing run")
	check(is_equal_approx(parts.scale(drake, "bombenflug", "duration"), 0.25), "the two wing factors multiply: 0.5 x 0.5")
	var weakened: Dictionary = parts.weakened(drake, "bombenflug")
	check(weakened.size() == 1 and is_equal_approx(float(weakened.get("duration", 0.0)), 0.25), "weakened() lists duration 0.25 (%s)" % str(weakened))
	check(is_equal_approx(parts.scale(drake, "bombenflug", "count"), 1.0) and parts.weakened(drake, "atem").is_empty(), "unrelated params and attacks stay at 1.0")


func _test_alsodetach_and_weakens_the_tail() -> void:
	var drake := _enemy(4)
	var hit: Dictionary = parts.damage(drake, 15.0, "tail_2")
	check(hit.destroyed and "tail_2" in drake.parts_lost, "tail_2 is severed")
	check("tail_3" in drake.parts_lost and "tail_flame" in drake.parts_lost and not "tail_1" in drake.parts_lost, "alsoDetach drops the unbreakable tip and the flame, the base stays")
	check(parts.can(drake, "huschen") and parts.can(drake, "satz"), "a lost tail weakens, it does not disable")
	check(is_equal_approx(parts.scale(drake, "huschen", "speed"), 0.6) and is_equal_approx(parts.scale(drake, "satz", "radius"), 0.6), "huschen.speed and satz.radius drop to 60 %")
	check(_same_keys(parts.weakened(drake, "satz"), ["radius"]), "weakened(satz) names only the radius")


func _test_unbreakable_parts_never_break() -> void:
	var drake := _enemy(5)
	var body: Dictionary = parts.damage(drake, 60.0, "body")
	check(not body.destroyed and not body.killed and not "body" in drake.parts_lost, "the body takes more than its share but never breaks")
	var tip: Dictionary = parts.damage(drake, 20.0, "tail_3")
	check(not tip.destroyed and not "tail_3" in drake.parts_lost, "an unbreakable tail tip is not severed by a direct hit")
	var leg: Dictionary = parts.damage(drake, 20.0, "leg_far")
	check(not leg.destroyed and is_equal_approx(parts.speed_scale(drake), 1.0), "drake legs never break and never slow it")
	check(is_equal_approx(float(drake.hp), DRAKE_TOTAL - 100.0), "every hit still counts against the HP bar (%.1f)" % float(drake.hp))
	check(parts.damage(drake, DRAKE_TOTAL - 100.0, "head").killed and float(drake.hp) == 0.0, "only the empty HP bar kills")


func _test_exposed_throat_only_during_its_breath() -> void:
	var drake := _enemy(6)
	var rig: Dictionary = library.rig(DRAKE)
	var throat: Vector2 = rig.by_id.throat.center
	var at := Vector2(400.0 + (throat.x - float(rig.ground.x)) * float(rig.scale), 300.0 + (throat.y - float(rig.center.y) - float(rig.hover)) * float(rig.scale))
	check(parts.segment_part(drake, at - Vector2(1, 0), at + Vector2(1, 0), 2.0) != "throat", "outside the breath a shot at the throat misses it")
	check(parts.part_near(drake, at) != "throat", "outside the breath area damage skips the throat")
	drake.exposed_action = "atem"
	check(parts.segment_part(drake, at - Vector2(1, 0), at + Vector2(1, 0), 2.0) == "throat", "during atem the throat is hit")
	check(parts.part_near(drake, at) == "throat", "during atem area damage finds the throat")
	check(parts.damage(drake, 14.0, "throat").destroyed and not parts.can(drake, "atem"), "a severed throat ends the breath")


## carrier(): a hit on an unbreakable part that falls with a severable one
## (tail_3 with tail_2) counts on that part; regrow_after: an enemy-level
## delay (a hell boss) when the rig gives none, the tip returning with it.
func _test_carrier_and_enemy_regrow() -> void:
	# Arrange
	var drake := _enemy(31)
	# Act / Assert: routing
	check(parts.carrier(drake, "tail_3") == "tail_2" and parts.carrier(drake, "tail_flame") == "tail_2", "the tail tip and flame count on tail_2")
	check(parts.carrier(drake, "body") == "body" and parts.carrier(drake, "jaw") == "jaw" and parts.carrier(drake, "") == "", "other parts count on themselves")
	parts.damage(drake, 15.0, "tail_2")
	check(parts.carrier(drake, "tail_3") == "tail_3", "with tail_2 gone nothing carries the tip")
	check(drake.regrow.is_empty(), "without regrow_after the tail stays gone")
	# Act: the same cut on an enemy that regrows after 12 s
	var boss := _enemy(32)
	boss.regrow_after = 12.0
	parts.damage(boss, 15.0, "tail_2")
	check(is_equal_approx(float(boss.regrow.get("tail_2", 0.0)), 12.0), "regrow_after sets the delay of a part without its own")
	parts.step(boss, 11.9)
	check("tail_2" in boss.parts_lost and "tail_3" in boss.parts_lost, "not before 12 s")
	parts.step(boss, 0.2)
	# Assert
	check(not "tail_2" in boss.parts_lost and not "tail_3" in boss.parts_lost and not "tail_flame" in boss.parts_lost, "the tail grows back with its tip and flame")
	check(is_equal_approx(float(boss.parts.tail_3.hp), float(boss.parts.tail_3.max) * 0.5), "the tip returns with half its HP")
	var claw := _enemy(33)
	claw.regrow_after = 3.0
	parts.damage(claw, 15.0, "arm")
	check(is_equal_approx(float(claw.regrow.get("arm", 0.0)), 12.0), "the rig's own regrow (the claw's 12 s) wins over regrow_after")


func _test_pending_hits_are_keyed_by_uid() -> void:
	var first := {"id": DRAKE, "uid": 17}
	var second := {"id": DRAKE, "uid": 18}
	parts.set_pending(first, "jaw")
	check(parts.take_pending(second) == "", "two drakes with the same string id do not share a pending hit")
	check(parts.take_pending(first) == "jaw" and parts.take_pending(first) == "", "the pending hit belongs to its uid and is used once")
	parts.set_pending({"id": DRAKE, "uid": 21}, "arm")
	check(parts.take_pending({"id": DRAKE, "uid": 21.0}) == "arm", "a float uid is the same enemy as the int uid")
	parts.set_pending({"id": "imp_a"}, "head")
	check(parts.take_pending({"id": "imp_b"}) == "" and parts.take_pending({"id": "imp_a"}) == "head", "without a uid a string id is the key")
	parts.set_pending({"id": 5}, "skull")
	check(parts.take_pending({"id": 5}) == "skull", "crypt enemies stay keyed by their int id")


func _test_regrow_returns_half_hp_after_12s() -> void:
	var drake := _enemy(7)
	parts.damage(drake, 15.0, "arm")
	check("arm" in drake.parts_lost and is_equal_approx(parts.scale(drake, "graben", "ring"), 0.5), "without its claw the dig ring is half as wide")
	check(is_equal_approx(parts.scale(drake, "lavabruch", "ring"), 0.5) and is_equal_approx(parts.scale(drake, "lavabruch", "lava"), 0.0), "lavabruch: ring halved, lava factor 0 turns it off")
	parts.step(drake, 11.9)
	check("arm" in drake.parts_lost, "the claw is still gone after 11.9 s")
	parts.step(drake, 0.2)
	check(not "arm" in drake.parts_lost and is_equal_approx(float(drake.parts.arm.hp), 7.5), "after 12 s the claw is back with half its HP")
	check(is_equal_approx(parts.scale(drake, "graben", "ring"), 1.0) and parts.weakened(drake, "lavabruch").is_empty(), "a regrown claw restores full strength")
	check(is_equal_approx(float(drake.hp), DRAKE_TOTAL - 15.0 + 7.5), "regrown HP returns to the total")


func _test_group_from_part_fields_and_string_disables() -> void:
	# fixture_partial: body 10, ghost 5 (no image, disables "biss"), crystal_1 3 (group crystals)
	var boss := _enemy(8, "fixture_partial", 18.0)
	check(parts.damage(boss, 3.0, "crystal_1").destroyed and not parts.can(boss, "strahlen"), "the only crystal of its group lost: the beams are disabled")
	check(is_equal_approx(parts.scale(boss, "strahlen", "beams"), 0.667), "and the beam factor is listed")
	check(parts.can(boss, "biss") and parts.damage(boss, 5.0, "ghost").destroyed and not parts.can(boss, "biss"), "a single-string disables on a layered part still disables")


## Damage without an impact part (burn ticks, statuses) must not reach a part
## that is hidden outside its window: no DoT severs the throat between breaths.
func _test_fallback_never_hits_a_hidden_part() -> void:
	parts.reset(1)
	var hidden := 0
	for i in range(200):
		if str(parts.damage(_enemy(100 + i), 0.5).part) == "throat": hidden += 1
	check(hidden == 0, "200 hits without a part never land on the hidden throat (%d did)" % hidden)
	parts.reset(1)
	var exposed := 0
	for i in range(200):
		var drake := _enemy(300 + i)
		drake.exposed_action = "atem"
		if str(parts.damage(drake, 0.5).part) == "throat": exposed += 1
	check(exposed > 0, "during atem the throat is among the fallback targets (%d of 200)" % exposed)


## A part whose image is missing has no pixels: nobody can see it break.
func _test_fallback_skips_parts_without_pixels() -> void:
	parts.reset(2)
	var ghost := 0
	for i in range(120):
		if str(parts.damage(_enemy(500 + i, "fixture_partial", 18.0), 0.5).part) == "ghost": ghost += 1
	check(ghost == 0, "hits without a part never land on a part without pixels (%d did)" % ghost)
	var alone := _enemy(700, "fixture_partial", 18.0)
	alone.parts_lost = ["body", "crystal_1"]
	check(str(parts.damage(alone, 0.5).part) == "ghost", "when nothing else lives, the invisible part still takes the hit")


func _test_group_ignores_members_that_cannot_be_lost() -> void:
	# fixture_flawed: group pair lists wing_a (hp 5), wing_b (hp 0, never in parts_lost) and an unknown id.
	var boss := _enemy(9, "fixture_flawed", 20.0)
	check(parts.can(boss, "flug"), "an intact boss can fly")
	check(parts.damage(boss, 5.0, "wing_a").destroyed and not parts.can(boss, "flug"), "losing the only member that can be lost disables the group's attack")


## The crypt's fallback draws exactly the legacy sequence for the same seed
## (vital 1 in 4, sorted ids, exposed parts included): saved runs replay as before.
func _test_crypt_fallback_sequence_unchanged() -> void:
	var rng := RandomNumberGenerator.new()
	for rig_name: String in ["void", "skeleton"]:
		parts.reset(5)
		rng.seed = 5
		var same := true
		for i in range(80):
			var boss := {"id": 900 + i, "pos": Vector2(400, 300), "hp": 140.0, "max_hp": 140.0, "face": 1.0, "radius": 13.0}
			parts.attach(boss, rig_name)
			var expected := _legacy_fallback(rng, rig_name, boss)
			same = same and str(parts.damage(boss, 0.5).part) == expected
		check(same, "%s: the fallback sequence for seed 5 is the legacy one" % rig_name)


## The fallback as it was before hell rigs (the crypt's reference).
func _legacy_fallback(rng: RandomNumberGenerator, rig_name: String, enemy: Dictionary) -> String:
	var vitals: Array[String] = []
	var others: Array[String] = []
	for id: String in parts.alive(enemy):
		if bool(library.rig(rig_name).by_id.get(id, {}).get("vital", false)): vitals.append(id)
		else: others.append(id)
	vitals.sort()
	others.sort()
	if others.is_empty() or (not vitals.is_empty() and rng.randf() < 0.25): return vitals[rng.randi_range(0, vitals.size() - 1)]
	return others[rng.randi_range(0, others.size() - 1)]


func _test_crypt_string_disables_still_work() -> void:
	var skeleton := {"id": 1, "pos": Vector2(400, 300), "hp": 11.0, "max_hp": 11.0, "face": 1.0, "radius": 13.0}
	parts.attach(skeleton, "skeleton")
	parts.damage(skeleton, 1.0, "weapon")
	check(not parts.can(skeleton, "attack") and parts.can(skeleton, "block"), "the crypt skeleton without its sword cannot attack, it can still block")
	check(is_equal_approx(parts.scale(skeleton, "attack", "damage"), 1.0) and parts.weakened(skeleton, "attack").is_empty(), "crypt rigs have nothing to weaken")
	var boss := {"id": 2, "pos": Vector2(400, 300), "hp": 140.0, "max_hp": 140.0, "face": 1.0, "radius": 13.0}
	parts.attach(boss, "void")
	parts.damage(boss, 30.0, "claw_l")
	check(not parts.can(boss, "summon") and parts.can(boss, "beam"), "the Leerenrufer's claw still takes the summon with it")


func _test_enemies_without_parts() -> void:
	var plain := {"id": 3, "hp": 10.0, "max_hp": 10.0}
	check(parts.can(plain, "spucke") and is_equal_approx(parts.scale(plain, "satz", "radius"), 1.0) and parts.weakened(plain, "satz").is_empty(), "an enemy without parts is never disabled or weakened")


# --------------------------------------------------------------- helpers

func _same_keys(values: Dictionary, keys: Array) -> bool:
	if values.size() != keys.size(): return false
	for key: String in keys:
		if not values.has(key): return false
	return true


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
	var path := dir + "/hell_rigs.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()
	return path


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
