extends SceneTree
## Captures the permanent companions and the new signature ultimates (user
## decisions 30.10.2026) in a crypt run: the frost mage's water elemental with
## its abilities on 5 and 6 (auto-cast glow) and its life under the hearts,
## Gletschergrab, the Meteor falling and its crater, Singularität, the
## necromancer's bone warrior with the Knochenkoloss, the beast master's
## Wildes Erwachen and the elemental in the Frostgruft. Uses the test profile
## file, never the player's.
##   godot --path . --windowed --resolution 1280x720 -s res://scripts/capture_pets_ultimates.gd
const Game = preload("res://src/game.gd")
const Profile = preload("res://src/progress/profile.gd")
const FrostScene = preload("res://src/hell/frost_dungeon.tscn")

var _out := "res://production/qa/evidence/pets-ultimates"
var _game: Node


func _initialize() -> void:
	_run.call_deferred()


func _wait(frames: int) -> void:
	for i in range(frames):
		if _game != null and _game.get("players") != null and _game.players.has(1):
			_game.players[1].invulnerable = 5.0
			_game.players[1].hp = maxi(1, int(_game.players[1].hp))
		await process_frame


func _shot(name: String) -> void:
	await _wait(2)
	RenderingServer.force_draw(false)
	var image := root.get_texture().get_image()
	var path := _out.path_join(name)
	print("CAPTURED %s result=%d" % [path, image.save_png(path)])


## A level 26 build of `spec`: 22 points from row I down, the first four
## actives on the bar, the ultimate at Stufe 3.
func _build(state: Dictionary, d: Dictionary, spec: String) -> void:
	state.level = 26
	state.ranks = {}
	state.bar = []
	var spent := 0
	for id: String in d.talents:
		var info: Dictionary = d.talents[id]
		if str(info.spec) != spec: continue
		if str(info.kind) == "ultimate":
			state.ranks[id] = 1
			state.ultimate = id
			state.soul_tier = 2
			continue
		if spent >= 22: continue
		state.ranks[id] = mini(int(info.ranks), 22 - spent)
		spent += int(state.ranks[id])
		if str(info.kind) == "active" and state.bar.size() < 4 and not bool(info.get("permanent", false)): state.bar.append(id)


## A crypt run as `class_id`, with a few skeletons in front of the hero.
func _crypt(class_id: String, foes: Array) -> Dictionary:
	_game.requested_seed = 4242
	_game._start_solo(false, class_id)
	await _wait(60)
	var hero: Dictionary = _game.players[1]
	for offset: Vector2 in foes:
		var enemy: Dictionary = _game._create_enemy("skeleton", Vector2(hero.pos) + offset)
		enemy.hp = 400.0
		enemy.max_hp = 400.0
		enemy.aggro = true
		enemy.aggro_target = 1
		_game.enemies.append(enemy)
	_game.talent_combat.runtime(1).res = 120.0
	return hero


func _leave() -> void:
	_game._leave_session()
	await _wait(20)


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	_game = Game.new()
	root.add_child(_game)
	_game.session_bind_ip = "127.0.0.1"
	await _wait(30)
	var profile: Dictionary = _game.progress.profile
	var d: Dictionary = _game.progress.data
	for pair: Array in [["mage", "frost"], ["necromancer", "minion"], ["archer", "beast"]]:
		_build(Profile.class_state(profile, pair[0]), d, pair[1])
	var tc: RefCounted = _game.talent_combat
	# 1) Frost mage: the elemental beside the hero, its abilities on 5 and 6, Gletschergrab
	var hero := await _crypt("mage", [Vector2(150, -20), Vector2(170, 30), Vector2(130, 50)])
	tc.toggle_pet_auto(1, 1)
	await _wait(40)
	tc.pet_cast(1, 0, true)
	tc.cast(1, "frost_14", {"aim": Vector2.RIGHT, "target": Vector2(hero.pos) + Vector2(150, 15)})
	await _wait(25)
	await _shot("01-frostmagier-elementar-gletschergrab.png")
	await _leave()
	# 2+3) Fire mage: the Meteor falls, then its crater burns
	_build(Profile.class_state(profile, "mage"), d, "fire")
	hero = await _crypt("mage", [Vector2(160, 0), Vector2(180, 40), Vector2(140, -40)])
	tc.cast(1, "fire_14", {"aim": Vector2.RIGHT, "target": Vector2(hero.pos) + Vector2(160, 0)})
	await _wait(38)
	await _shot("02-meteor-faellt.png")
	await _wait(30)
	await _shot("03-meteor-krater.png")
	await _leave()
	# 4) Arcane mage: the Singularität pulls a group together
	_build(Profile.class_state(profile, "mage"), d, "arcane")
	hero = await _crypt("mage", [Vector2(120, -60), Vector2(220, 40), Vector2(170, 70)])
	tc.cast(1, "arcane_14", {"aim": Vector2.RIGHT, "target": Vector2(hero.pos) + Vector2(170, 0)})
	await _wait(60)
	await _shot("04-singularitaet.png")
	await _leave()
	# 5) Necromancer: the bone warrior and the Knochenkoloss
	hero = await _crypt("necromancer", [Vector2(140, 0), Vector2(170, 40)])
	tc.cast(1, "minion_14", {"aim": Vector2.RIGHT})
	await _wait(50)
	await _shot("05-knochenkrieger-koloss.png")
	await _leave()
	# 6) Beast master: Wildes Erwachen with the spirit wolves
	hero = await _crypt("archer", [Vector2(140, 0), Vector2(170, 40), Vector2(120, -40)])
	tc.cast(1, "beast_14", {"aim": Vector2.RIGHT})
	await _wait(40)
	await _shot("06-wildes-erwachen.png")
	await _leave()
	# 7) The water elemental in the Frostgruft
	_build(Profile.class_state(profile, "mage"), d, "frost")
	Profile.save_profile(profile, Profile.default_path())
	_game.queue_free()
	_game = null
	var frost: Node = FrostScene.instantiate()
	frost.class_id = "mage"
	root.add_child(frost)
	await _wait(40)
	var frost_state := Profile.class_state(frost.profile, "mage")
	_build(frost_state, frost.profile.get("_data", d), "frost")
	frost.talents.bind(frost, frost.profile, frost.profile_path, "mage")
	await _wait(60)
	await _shot("07-frostgruft-elementar.png")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Profile.default_path()))
	quit(0)
