extends SceneTree
## Captures the deep talent trees (8 rows, one branch per character), the
## necromancer and the talents on keys 1-4 (user decisions 29.10.2026):
## the talent screen of a fire mage, a locked branch, the necromancer's Diener
## tree, the hero choice with four heroes, a crypt run as necromancer with a
## skeleton, the skill bar on 1-4 / R and mana on the ground, and the
## necromancer in the Frostgruft. Uses the test profile file, never the player's.
##   godot --path . --windowed --resolution 1280x720 -s res://scripts/capture_deep_trees.gd
const Game = preload("res://src/game.gd")
const Profile = preload("res://src/progress/profile.gd")
const TalentCombat = preload("res://src/combat/talent_combat.gd")
const FrostScene = preload("res://src/hell/frost_dungeon.tscn")

var _out := "res://production/qa/evidence/deep-trees"
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


func _cast(bits: int, frames: int) -> void:
	_game.scripted_skills = bits
	await _wait(3)
	_game.scripted_skills = 0
	await _wait(frames)


## A build of `spec`: `points` points from row I down in branch order, the
## first four actives on the bar, and the ultimate when `ultimate` is set.
func _build(state: Dictionary, d: Dictionary, spec: String, points: int, ultimate: bool) -> void:
	state.ranks = {}
	state.bar = []
	var spent := 0
	for id: String in d.talents:
		var info: Dictionary = d.talents[id]
		if str(info.spec) != spec: continue
		if str(info.kind) == "ultimate":
			if ultimate:
				state.ranks[id] = 1
				state.ultimate = id
				state.soul_tier = 1
			continue
		if spent >= points: continue
		state.ranks[id] = mini(int(info.ranks), points - spent)
		spent += int(state.ranks[id])
		if str(info.kind) == "active" and state.bar.size() < 4: state.bar.append(id)


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	_game = Game.new()
	root.add_child(_game)
	_game.session_bind_ip = "127.0.0.1"
	await _wait(30)
	var profile: Dictionary = _game.progress.profile
	var d: Dictionary = _game.progress.data
	profile.gold = 900
	profile.shards = {"have": 3, "earned": 6, "spent": 3}
	var mage := Profile.class_state(profile, "mage")
	mage.level = 26
	_build(mage, d, "fire", 22, true)
	var necro := Profile.class_state(profile, "necromancer")
	necro.level = 14
	_build(necro, d, "minion", 13, false)
	# 1) The fire mage's tree, the ultimate selected.
	_game.main_menu._open_talents()
	var screen: Control = _game.main_menu._talent_screen
	screen.selected = "fire_14"
	screen._refresh()
	await _wait(20)
	await _shot("01-feuermagier-baum.png")
	# 2) The frost branch: locked for a fire mage.
	screen._show_spec("frost")
	screen.selected = "frost_3"
	screen._refresh()
	await _wait(10)
	await _shot("02-frostzweig-gesperrt.png")
	# 3) The necromancer's Diener tree.
	screen._pick_class("necromancer")
	screen.selected = "minion_9"
	screen._refresh()
	await _wait(10)
	await _shot("03-nekromant-diener.png")
	screen.visible = false
	# 4) The hero choice with four heroes.
	_game.main_menu._open_classes(false)
	await _wait(20)
	await _shot("04-heldenwahl-vier.png")
	_game.main_menu._close_panels()
	# 5) A crypt run as necromancer: key 1 raises a skeleton, mana lies on the ground.
	_game.requested_seed = 4242
	_game._start_solo(false, "necromancer")
	await _wait(60)
	# the talent itself (key 1 goes through the same cast; the scripted key can arrive while the room still fades in)
	_game.talent_combat.cast(1, "minion_1", {"aim": Vector2.RIGHT})
	await _wait(40)
	var hero: Dictionary = _game.players[1]
	_game.talent_combat.enemy_killed({"pos": Vector2(hero.pos) + Vector2(70, 10), "kind": "skeleton"}, 1)
	_game.talent_combat.enemy_killed({"pos": Vector2(hero.pos) + Vector2(-60, 30), "boss": true, "kind": "boss"}, 1)
	_game.talent_combat.runtime(1).res = 30.0
	await _wait(20)
	await _shot("05-krypta-nekromant-skelett-mana.png")
	_game._leave_session()
	await _wait(20)
	# 6) The necromancer in the Frostgruft with the same talents.
	_game.queue_free()
	_game = null
	var frost: Node = FrostScene.instantiate()
	frost.class_id = "necromancer"
	root.add_child(frost)
	await _wait(30)
	var frost_state := Profile.class_state(frost.profile, "necromancer")
	frost_state.level = 14
	_build(frost_state, d, "minion", 13, false)
	frost.talents.bind(frost, frost.profile, frost.profile_path, "necromancer")
	await _wait(10)
	frost.talents.press(0)
	await _wait(40)
	await _shot("06-frostgruft-nekromant.png")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Profile.default_path()))
	quit(0)
