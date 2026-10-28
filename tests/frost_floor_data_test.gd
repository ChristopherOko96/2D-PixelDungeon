extends SceneTree
## Baked Frostgruft floors (assets/data/frost_floors.json, tools/frost_dungeon):
## ten floors load through the hell loader, each has one start, boss and
## stairs room, the quickest way skips rooms, every locked gate's key exists,
## bosses sit on 3/6/9 (mini) and 10 (Hrimgar, final), no hell wording is left
## in room texts, and every sprite a floor draws exists in the frost skin
## (assets/sprites/frost) together with the skin's monsters and boss phases.

const FloorData = preload("res://src/hell/hell_floor_data.gd")
const DATA_PATH := "res://assets/data/frost_floors.json"
const SKIN := "res://assets/sprites/frost/"
const HELL_WORDS := ["Glut", "Lava", "Dämon", "Feuer", "Hölle", "Asche", "Schädel", "Knochen", "Portal", "Rune"]
var checked := 0
var failures: Array[String] = []


func check(condition: bool, description: String) -> void:
	checked += 1
	if not condition:
		failures.append(description)
		printerr("FROST_FLOOR_DATA_FAIL: ", description)


func _count(rooms: Array, kind: String) -> int:
	var n := 0
	for r: Dictionary in rooms:
		if r.type == kind:
			n += 1
	return n


func _initialize() -> void:
	var raw := FloorData.load_all(DATA_PATH)
	check(raw.size() == 10, "ten frost floors are baked")
	var skin: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SKIN + "manifest.json"))
	var hell: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/sprites/hell/manifest.json"))
	var missing: Array[String] = []
	for name: String in hell:
		if not skin.has(name):
			missing.append(name)
	check(missing.is_empty(), "the frost skin covers every hell sprite name (missing: %s)" % ", ".join(missing))
	var files_ok := true
	for name: String in skin:
		if not ResourceLoader.exists(SKIN + name + ".png"):
			files_ok = false
	check(files_ok, "every frost manifest entry has its PNG")
	for name: String in ["key_gold", "key_ice", "key_crystal", "mob_ice_zombie_f0", "mob_ice_slime_0", "mob_frost_whirl_0", "mob_ice_knight_f0", "mob_frost_imp_f0", "mob_ice_crystal_0", "mob_frost_necromancer_f0", "mob_frost_corpse_f0", "mob_frost_commander", "boss_golem_p1_f0", "boss_golem_p2_f0", "boss_golem_p3_f0", "boss_golem_walk_f0"]:
		check(skin.has(name), "frost skin has %s" % name)
	for f: Dictionary in raw:
		var W := FloorData.prepare(f)
		var n: int = W.n
		check(_count(W.rooms, "start") == 1 and _count(W.rooms, "boss") == 1 and _count(W.rooms, "portal") == 1, "floor %d has one start, boss and stairs room" % n)
		check(W.quick > 0 and W.quick < W.rooms.size(), "floor %d: the quickest way (%d rooms) skips some of the %d rooms" % [n, W.quick, W.rooms.size()])
		var keys := {}
		for r: Dictionary in W.rooms:
			if r.drop != "":
				keys[r.drop] = true
		for e: Dictionary in W.ents:
			if e.type == "key":
				keys[e.key] = true
		var locks_ok := true
		for d: Dictionary in W.doors:
			if d.kind == "lock" and not keys.has(d.key):
				locks_ok = false
		check(locks_ok, "floor %d: every locked gate's key exists" % n)
		var boss: Dictionary = W.boss
		check(bool(boss.get("mini", false)) == (n in [3, 6, 9]), "floor %d: mini boss only on 3, 6 and 9" % n)
		check(bool(boss.get("final", false)) == (n == 10), "floor %d: the final boss only on 10" % n)
		var words_ok := true
		for r: Dictionary in W.rooms:
			for word: String in HELL_WORDS:
				if word in str(r.name) or word in str(r.info) or word in str(r.kind):
					words_ok = false
		check(words_ok, "floor %d: room texts use frost wording" % n)
		var names_ok := true
		for p: Dictionary in W.props:
			if p.name != "" and not skin.has(p.name):
				names_ok = false
		for d: Dictionary in W.decals + W.wall_decor:
			if not skin.has(d.name):
				names_ok = false
		for t: String in W.tile_names:
			if not skin.has(t):
				names_ok = false
		check(names_ok, "floor %d: every drawn sprite exists in the frost skin" % n)
	check(str(raw[9].boss.name).begins_with("Hrimgar"), "floor 10 boss is Hrimgar")
	print("FROST_FLOOR_DATA checked=%d failures=%d" % [checked, failures.size()])
	quit(1 if failures.size() > 0 else 0)
