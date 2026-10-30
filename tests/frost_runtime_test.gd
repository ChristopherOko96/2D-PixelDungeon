extends SceneTree
## Frostgruft on the Hell-Dungeon runtime (src/hell/frost_dungeon.tscn with
## assets/data/frost_theme.json): the theme loads the frost floors and skin with
## sharp pixels, floor keys wait in chests and opening one hands over the key,
## glaze ice (grid cell 2) lets the hero slide on without hurting, plain floor
## stops at once, the three hero classes bring their own sprite, hearts, speed
## and weapon (sword arc in front only, arrows, magic splash), the frost monsters
## fill rooms by floor and act their part (zombie chills, slime splits, knight
## blocks from the front, crystal stands and fires a fan, whirl pulls, imp
## dashes), guardians wear their floor's look, and the hell scene without a
## theme keeps its own look, hero, enemies and lava.

const FrostScene = preload("res://src/hell/frost_dungeon.tscn")
const HellScene = preload("res://src/hell/hell_dungeon.tscn")
var checked := 0
var failures: Array[String] = []


func check(condition: bool, description: String) -> void:
	checked += 1
	if not condition:
		failures.append(description)
		printerr("FROST_RUNTIME_FAIL: ", description)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await _test_theme_loads_frost_floors_and_skin()
	await _test_key_room_key_lies_loose_and_walking_over_it_takes_it()
	await _test_glaze_ice_slides_and_plain_floor_stops()
	await _test_each_class_brings_its_hero_hearts_and_weapon()
	await _test_sword_hits_in_front_but_not_behind()
	await _test_bow_shoots_arrows()
	await _test_magic_bursts_on_everyone_nearby()
	await _test_rooms_fill_with_the_floors_monsters()
	await _test_zombie_touch_chills_the_hero()
	await _test_slime_splits_into_smaller_slimes()
	await _test_knight_blocks_from_the_front_only()
	await _test_crystal_stands_and_fires_a_fan()
	await _test_whirl_pulls_and_imp_dashes()
	await _test_guardians_wear_their_floors_look()
	await _test_hell_scene_keeps_its_look_with_hero_systems()
	print("FROST_RUNTIME checked=%d failures=%d" % [checked, failures.size()])
	quit(1 if failures.size() > 0 else 0)


## The worlds open in their pixel set here, whatever the player chose (src/core/graphics_settings.gd).
const GRAPHICS := "user://frost_runtime_test.cfg"


func _new(scene: PackedScene, floor_n := 1, class_id := "") -> Node:
	var cfg := ConfigFile.new()
	cfg.set_value("options", "graphics", "pixel")
	cfg.save(GRAPHICS)
	var game: Node = scene.instantiate()
	game.graphics_path = GRAPHICS
	game.start_floor = floor_n
	game.class_id = class_id
	root.add_child(game)
	await process_frame
	return game


func _free(game: Node) -> void:
	game.queue_free()
	await process_frame


func _test_theme_loads_frost_floors_and_skin() -> void:
	# Arrange / Act
	var game := await _new(FrostScene)
	# Assert
	check(game.floors_raw.size() == 10 and str(game.W.title) == "Frostpforte", "the frost scene plays the ten frost floors (got %s)" % game.W.get("title", "?"))
	check(game.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST and is_equal_approx(float(game.theme.hero_scale), 3.0), "frost draws sharp pixels and the hero at x3")
	check(game.tex.has("key_crystal") and game.tex.has("boss_golem_p1_f0"), "the frost skin is loaded")
	check(str(game.key_name.C) == "Kristallschlüssel" and game.say("Feuerschale entzünden") == "Frostflamme entzünden", "keys and wording are frost")
	await _free(game)


## The world kit rule (docs/WELT-BAUKASTEN.de.md): the boss key lies loose in the middle of the key
## room's rug, as in the crypt and the hell (the Frostgruft no longer hides keys in chests).
func _test_key_room_key_lies_loose_and_walking_over_it_takes_it() -> void:
	# Arrange
	var game := await _new(FrostScene)
	var key: Dictionary = {}
	for e: Dictionary in game.W.ents:
		if e.type == "key" and str(e.key) == "C":
			key = e
	check(not key.is_empty() and str(game.W.rooms[int(key.room)].gtype) == "key", "the boss key lies loose in the key room")
	if key.is_empty():
		await _free(game)
		return
	for r: Dictionary in game.W.rooms:
		r.fight = false
		r.cleared = true
	game.player.x = key.x
	game.player.y = key.y
	# Act
	for i in range(4):
		await process_frame
	# Assert
	check(bool(game.state.keys.C), "walking over it hands over the %s" % game.key_name.C)
	await _free(game)


func _glaze_cell(game: Node) -> Vector2i:
	for y in range(game.W.rows):
		for x in range(1, game.W.cols - 3):
			var i: int = y * game.W.cols + x
			if game.W.grid[i] == 2 and game.W.grid[i + 1] == 2 and game.W.grid[i + 2] == 2:
				return Vector2i(x, y)
	return Vector2i(-1, -1)


func _test_glaze_ice_slides_and_plain_floor_stops() -> void:
	# Arrange: floor 5, the frozen lake, has wide glaze ice
	var game := await _new(FrostScene, 5)
	var c := _glaze_cell(game)
	check(c.x >= 0, "floor 5 has glaze ice")
	if c.x < 0:
		await _free(game)
		return
	game.player.x = (c.x + 0.5) * 96.0
	game.player.y = (c.y + 0.6) * 96.0
	game.player.vel = Vector2(300, 0)
	var hp: int = game.state.hp
	var x0: float = game.player.x
	# Act: no key held, a tenth of a second
	game._update_player(0.1)
	# Assert
	check(game.player.x > x0 + 5.0, "on glaze ice the hero slides on without input (%.1f px)" % (game.player.x - x0))
	check(game.state.hp == hp, "glaze ice does not hurt")
	# Arrange / Act: plain floor of the start room
	game._respawn()
	game.player.vel = Vector2(300, 0)
	var x1: float = game.player.x
	game._update_player(0.1)
	# Assert
	check(is_equal_approx(game.player.x, x1), "on plain floor the hero stops at once")
	await _free(game)


func _test_each_class_brings_its_hero_hearts_and_weapon() -> void:
	var expect := {"swordsman": ["knight_m", "melee"], "archer": ["elf_f", "projectile"], "mage": ["wizzard_m", "projectile"]}
	var hearts := {}
	for id: String in expect:
		# Arrange / Act
		var game := await _new(FrostScene, 1, id)
		# Assert
		var frame: Texture2D = game.hero_frames.idle[0]
		check(frame.resource_path.contains(expect[id][0]) and game.weapon.type == expect[id][1] and game.weapon_tex != null, "%s plays %s with a %s weapon" % [id, expect[id][0], expect[id][1]])
		hearts[id] = game.state.max_hp
		await _free(game)
	check(hearts.swordsman > hearts.archer and hearts.archer > hearts.mage, "hearts: swordsman > archer > mage (%s)" % hearts)
	var game := await _new(FrostScene, 1, "")
	check(game.class_id == "archer", "no choice falls back to the default class")
	await _free(game)


func _mob_at(game: Node, offset: Vector2, kind := "ice_zombie") -> Dictionary:
	var p := Vector2(game.player.x, game.player.y) + offset
	game._spawn_mob(game.state.room, p, kind)
	var m: Dictionary = game.mobs[game.mobs.size() - 1]
	m.spawn = 0.0
	return m


func _test_sword_hits_in_front_but_not_behind() -> void:
	# Arrange
	var game := await _new(FrostScene, 1, "swordsman")
	var front := _mob_at(game, Vector2(100, 0))
	var back := _mob_at(game, Vector2(-100, 0))
	var hp: float = front.hp
	# Act
	game._fire(Vector2.RIGHT)
	# Assert
	check(front.hp < hp and back.hp == hp, "the sword hits the enemy in front, not the one behind")
	check(game.shots.is_empty(), "the sword fires no shot")
	await _free(game)


func _test_bow_shoots_arrows() -> void:
	# Arrange
	var game := await _new(FrostScene, 1, "archer")
	# Act
	game._fire(Vector2.UP)
	# Assert
	check(game.shots.size() == 1 and game.shots[0].kind == "arrow" and game.shots[0].splash == 0.0, "the bow fires one arrow without splash")
	await _free(game)


func _test_magic_bursts_on_everyone_nearby() -> void:
	# Arrange: two enemies side by side, the bolt meets the first
	var game := await _new(FrostScene, 1, "mage")
	game.mobs.clear()
	var a := _mob_at(game, Vector2(200, 0))
	var b := _mob_at(game, Vector2(200, 70))
	var hp: float = b.hp
	game.shots.clear()
	game.shots.append({"p": a.p - Vector2(0, 30.0 * a.s), "v": Vector2(700, 0), "t": 1.0, "kind": "magic", "splash": float(game.weapon.splash)})
	# Act
	game._update_shots(0.0)
	# Assert
	check(a.hp < hp and b.hp < hp, "the magic burst hurts both neighbouring enemies")
	await _free(game)


func _combat_room(game: Node) -> Dictionary:
	for r: Dictionary in game.W.rooms:
		if r.type == "combat" and not r.cleared:
			return r
	return {}


func _test_rooms_fill_with_the_floors_monsters() -> void:
	for n: int in [1, 6]:
		# Arrange
		var game := await _new(FrostScene, n, "archer")
		var r := _combat_room(game)
		game.player.x = (r.bx + r.bw / 2.0) * 96.0
		game.player.y = (r.by + r.bh / 2.0) * 96.0
		game.state.room = r.index
		# Act
		game._start_fight(r)
		# Assert
		var kinds := {}
		var drawn := true
		for m: Dictionary in game.mobs:
			kinds[m.kind] = true
			if not (m.look as Dictionary).has("sprite"):
				drawn = false
		var allowed: Array = game.MobRules.floor_roster(game.theme.roster, n).map(func(e: Dictionary) -> String: return e.kind)
		var ok := not kinds.is_empty()
		for k: String in kinds:
			if not (k in allowed):
				ok = false
		check(ok and drawn, "floor %d fights use only its frost monsters, all drawn as sprites (%s)" % [n, kinds.keys()])
		await _free(game)


func _test_zombie_touch_chills_the_hero() -> void:
	# Arrange
	var game := await _new(FrostScene, 1, "archer")
	var z := _mob_at(game, Vector2(10, 0), "ice_zombie")
	z.spawn = 0.0
	# Act
	game._update_mobs(0.01)
	# Assert
	check(game.state.chill > 0.0, "the ice zombie's touch chills the hero")
	await _free(game)


func _test_slime_splits_into_smaller_slimes() -> void:
	# Arrange
	var game := await _new(FrostScene, 2, "archer")
	game.mobs.clear()
	var big := _mob_at(game, Vector2(300, 0), "ice_slime")
	_mob_at(game, Vector2(-600, 0), "ice_zombie")
	big.hp = 0.0
	# Act
	game._update_mobs(0.01)
	# Assert
	var mids: Array = game.mobs.filter(func(m: Dictionary) -> bool: return m.kind == "ice_slime_m")
	check(mids.size() == 2 and not game.mobs.has(big), "a big ice slime splits into two medium ones")
	await _free(game)


func _test_knight_blocks_from_the_front_only() -> void:
	# Arrange: the knight stands right of the hero and faces him
	var game := await _new(FrostScene, 5, "archer")
	game.mobs.clear()
	var knight := _mob_at(game, Vector2(300, 0), "ice_knight")
	knight.face = Vector2.LEFT
	var hp: float = knight.hp
	# Act / Assert: an arrow flying right meets the shield
	check(not game._damage_mob(knight, Vector2.RIGHT * 900.0) and knight.hp == hp, "the shield blocks a hit from the front")
	check(game._damage_mob(knight, Vector2.LEFT * 900.0) and knight.hp < hp, "a hit from behind gets through")
	await _free(game)


func _test_crystal_stands_and_fires_a_fan() -> void:
	# Arrange
	var game := await _new(FrostScene, 6, "archer")
	game.mobs.clear()
	game.eshots.clear()
	var crystal := _mob_at(game, Vector2(400, 0), "ice_crystal")
	crystal.spawn = 0.0
	crystal.shoot = 0.0
	var p0: Vector2 = crystal.p
	# Act
	game._update_mobs(0.05)
	# Assert
	check(crystal.p.distance_to(p0) < 0.01, "the ice crystal does not move")
	check(game.eshots.size() == int(game.theme.mobs.ice_crystal.fan), "the ice crystal fires a fan of %d shards" % int(game.theme.mobs.ice_crystal.fan))
	await _free(game)


func _test_whirl_pulls_and_imp_dashes() -> void:
	# Arrange
	var game := await _new(FrostScene, 4, "archer")
	game.mobs.clear()
	var whirl := _mob_at(game, Vector2(250, 0), "frost_whirl")
	whirl.spawn = 0.0
	var x0: float = game.player.x
	# Act
	for i in range(10):
		game._update_mobs(0.05)
	# Assert
	check(game.player.x > x0 + 5.0, "the frost whirl pulls the hero towards it (%.1f px)" % (game.player.x - x0))
	game.mobs.clear()
	var imp := _mob_at(game, Vector2(-500, 0), "frost_imp")
	imp.spawn = 0.0
	imp.dash_t = 0.0
	game._update_mobs(0.01)
	check(imp.dash > 0.0 and (imp.dash_dir as Vector2).x > 0.9, "the frost imp dashes straight at the hero")
	await _free(game)


func _test_guardians_wear_their_floors_look() -> void:
	for n: int in [3, 10]:
		# Arrange
		var game := await _new(FrostScene, n, "archer")
		# Act
		game._spawn_mob(game.state.room, Vector2(game.player.x + 300, game.player.y), "boss")
		# Assert
		var boss: Dictionary = game.mobs[game.mobs.size() - 1]
		check(str(boss.look.sprite) == str(game.theme.bosses[str(n)].sprite), "the floor %d guardian looks like %s" % [n, game.theme.bosses[str(n)].sprite])
		await _free(game)


func _test_hell_scene_keeps_its_look_with_hero_systems() -> void:
	# Arrange / Act
	var game := await _new(HellScene)
	# Assert
	check(str(game.W.title) == "Aschenvorhof" and game.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST and str(game.theme.sprites) == "res://assets/sprites/hell_0x72/",
		"the hell scene still plays the hell floors, in its 0x72 pixel skin with sharp pixels")
	check(str(game.key_name.A) == "Glutschlüssel" and bool(game.theme.liquid.hurt) and not bool(game.theme.key_in_chest), "hell keeps its keys, burning lava and loose keys")
	check(game.say("Feuerschale entzünden") == "Feuerschale entzünden", "hell wording is unchanged")
	# Story 3: the hell shares the hero systems (hell_theme.json takes them from the frost theme)
	check(game.class_id == str(game.theme.default_class) and not game.hero.is_empty() and game.weapon_tex != null and not game.skills.is_empty(),
		"hell plays the default hero class with its weapon and skills")
	var r := _combat_room(game)
	game._start_fight(r)
	# hell fights draw from the hell monsters' floor roster (hell_monsters.json), never from the frost kinds
	var roster: Array = game.monsters.floors["1"].mobs
	var hell_kinds := true
	for m: Dictionary in game.mobs:
		if not roster.has(m.get("id", "")) or m.has("look"):
			hell_kinds = false
	check(hell_kinds and not game.mobs.is_empty(), "hell fights keep their own hell monsters")
	await _free(game)
