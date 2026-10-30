extends SceneTree
## The beast master's companion is a wolf or a bear (talents.json "pet.kinds",
## chosen in the talent menu and kept in the profile); the bear has more life,
## bites harder and slower and walks slower. The talent test profile (debug
## builds) casts without cost and reloads in half a second. The pause menu
## shows the profile's soul shards.

const Game = preload("res://src/game.gd")
const Profile = preload("res://src/progress/profile.gd")
const PauseMenu = preload("res://src/pause_menu.gd")
const TalentFx = preload("res://src/vfx/talent_fx.gd")
var checked := 0
var failures: Array[String] = []
var game
var tc
var d: Dictionary


func check(condition: bool, label: String) -> void:
	checked += 1
	if not condition:
		failures.append(label)
		printerr("TALENT_COMPANION_FAIL: ", label)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	test_profile_keeps_the_companion()
	await _start()
	test_bear_is_tougher_and_slower()
	test_test_profile_casts_cost_mana_and_ultimate_keeps_its_minute()
	test_companion_sprites_exist()
	await test_pause_menu_shows_shards()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.progress.save_path))
	game.queue_free()
	print("TALENT_COMPANION checked=%d failures=%d" % [checked, failures.size()])
	quit(0 if failures.is_empty() else 1)


func test_profile_keeps_the_companion() -> void:
	# Arrange
	var data := Profile.data()
	var raw := Profile.fresh(data)
	raw.classes.archer.companion = "bear"
	raw.classes.mage.companion = "dragon"
	# Act
	var loaded := Profile.sanitize(JSON.parse_string(JSON.stringify(raw)), data)
	# Assert
	check(str(loaded.classes.archer.companion) == "bear", "the profile keeps the chosen bear")
	check(str(loaded.classes.mage.companion) == "wolf", "an unknown companion falls back to the wolf")
	check(str(Profile.build_of(loaded, "archer").companion) == "bear", "the build carries the companion into the run")
	check(Profile.fresh(data).classes.archer.companion == "wolf", "a fresh profile starts with the wolf")


func _start() -> void:
	game = Game.new()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	game.view.set_audio_enabled(false)
	game.progress.save_path = "user://talent_companion_test_profile.json"
	var probe := PacketPeerUDP.new()
	probe.bind(0, "127.0.0.1")
	game.port_input.text = str(probe.get_local_port())
	probe.close()
	game.session_bind_ip = "127.0.0.1"
	game._host_session()
	game.requested_seed = 4242
	game._begin_run()
	game.phase = "combat"
	tc = game.talent_combat
	d = tc.data
	game.players[1].max_hp = 999
	game.players[1].hp = 999


## A beast master with Tiergefährte at rank 1 and `companion`; returns the summoned pet.
func _summon(companion: String) -> Dictionary:
	var player: Dictionary = game.players[1]
	player.class_id = "archer"
	player.pos = Vector2(300, 240)
	tc.reset(7)
	tc.set_build(1, {"class": "archer", "level": 30, "ranks": {"beast_1": 1}, "bar": ["beast_1"], "companion": companion})
	game.enemies.clear()
	tc.runtime(1).res = 100.0
	tc.cast(1, "beast_1")
	return tc.pets[0] if not tc.pets.is_empty() else {}


func test_bear_is_tougher_and_slower() -> void:
	# Arrange / Act
	var wolf := _summon("wolf")
	var bear := _summon("bear")
	var traits: Dictionary = d.pet.kinds.bear
	# Assert
	check(str(wolf.get("kind", "")) == "wolf" and str(bear.get("kind", "")) == "bear", "the talent summons the chosen companion")
	check(is_equal_approx(float(bear.hp), float(wolf.hp) * float(traits.hp)), "the bear has %.1fx the wolf's life" % float(traits.hp))
	check(is_equal_approx(float(bear.dmg), float(wolf.dmg) * float(traits.dmg)), "the bear bites %.1fx harder" % float(traits.dmg))
	check(float(bear.every) > float(wolf.every) and float(bear.speed) < float(wolf.speed), "the bear bites less often and walks slower")
	check(str(tc.snapshot().pets[0].get("kind", "")) == "bear", "clients see which companion it is")


func test_test_profile_casts_cost_mana_and_ultimate_keeps_its_minute() -> void:
	# Arrange: the talent test profile spends mana like a real run (user decision 30.10.2026)
	tc.reset(7)
	tc.set_build(1, {"class": "mage", "level": 30, "ranks": {"fire_1": 3}, "bar": ["fire_1"], "free": true})
	game.players[1].class_id = "mage"
	var rt: Dictionary = tc.runtime(1)
	rt.res = 0.0
	# Act / Assert
	check(not tc.cast(1, "fire_1"), "the test profile needs mana too")
	rt.res = float(rt.res_max)
	check(tc.cast(1, "fire_1") and float(rt.res) < float(rt.res_max), "a cast in the test profile spends mana")
	check(float(rt.cds.fire_1) >= 3.0, "the test profile keeps the real cooldown")
	var ult_rt := _ultimate_build()
	check(is_equal_approx(float(ult_rt.cds.get("fire_14", 0.0)), 60.0), "the ultimate reloads in a full minute, cooldown talents left aside")


## A fire mage with the ultimate and a cooldown passive maxed, after casting it.
func _ultimate_build() -> Dictionary:
	var ranks := {}
	for k in range(1, 7):
		ranks["fire_%d" % k] = 3
	ranks["fire_13"] = 2 # Feuerseele: shorter cooldowns, never for the ultimate
	ranks["fire_14"] = 1
	tc.set_build(1, {"class": "mage", "level": 30, "ranks": ranks, "bar": [], "ultimate": "fire_14", "soul_tier": 1})
	var rt: Dictionary = tc.runtime(1)
	rt.res = float(rt.res_max)
	tc.cast(1, "fire_14")
	return rt


func test_companion_sprites_exist() -> void:
	for kind: String in d.pet.kinds:
		if bool(d.pet.kinds[kind].get("summon_only", false)): continue
		for motion: String in ["idle", "walk"]:
			for i in range(4):
				# wolf and bear from the forest pack, the falcon drawn for the game (scripts/make_falcon.py)
				var folder := "companions" if kind == "falcon" else "forest_0x72"
				var path := "res://assets/sprites/%s/%s_%s_f%d.png" % [folder, kind, motion, i]
				check(ResourceLoader.exists(path), "sprite %s exists" % path)
	var fx := TalentFx.new()
	check(fx._companion_frame("bear", "walk", 2) != null, "the companion art loads the bear's walk frames")
	check(fx._companion_frame("falcon", "idle", 1) != null, "the falcon's wing beats load")
	check(fx._companion_frame("skeleton", "walk", 2) != null and fx._companion_frame("skeleton", "idle", 0) != null, "the necromancer's skeletons use the 0x72 skeleton frames")


func test_pause_menu_shows_shards() -> void:
	# Arrange
	var menu: Control = PauseMenu.new()
	root.add_child(menu)
	await process_frame
	# Act
	menu.set_shards(7)
	# Assert
	check(menu.shard_label.text.contains("7") and menu.shard_label.text.contains("SEELENSPLITTER"), "the pause menu shows the soul shards")
	game.progress.profile.shards = {"have": 4, "earned": 4, "spent": 0}
	game.set_pause_open(true, "overview")
	game._refresh_ui()
	check(game.pause_menu.shard_label.text.contains("4"), "the crypt's pause menu shows the profile's shards")
	game.set_pause_open(false)
	menu.queue_free()
	await process_frame
