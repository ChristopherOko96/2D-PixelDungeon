extends SceneTree
## Captures evidence of the talent trees and soul shards from the real windowed
## game: the talent screen (a fire mage on level 20 with Inferno, and an archer
## on level 8 showing locked and available talents), the run HUD with the
## talent bar after casting, the Inferno ultimate, the soul shard banner and
## the beast master's wolf and bear, the pause menu with the soul shards and
## the companion choice in the talent screen. Uses the test profile file, never the player's.
##   godot --path . --resolution 1280x720 -s res://scripts/capture_talents.gd -- <output_dir>
const Game = preload("res://src/game.gd")
const Profile = preload("res://src/progress/profile.gd")
const TalentCombat = preload("res://src/combat/talent_combat.gd")
const FrostScene = preload("res://src/hell/frost_dungeon.tscn")

var _out := "res://production/qa/evidence/talents"
var _game: Node

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty(): _out = args[0]
	_run.call_deferred()

func _wait(frames: int) -> void:
	for i in range(frames):
		if _game != null and _game.players.has(1):
			_game.players[1].invulnerable = 5.0
			_game.players[1].hp = maxi(1, int(_game.players[1].hp))
		await process_frame

func _shot(name: String) -> void:
	await _wait(2)
	# Draw now even when the OS does not show the window (locked screen, remote session).
	RenderingServer.force_draw(false)
	var image := root.get_texture().get_image()
	var path := _out.path_join(name)
	print("CAPTURED %s result=%d" % [path, image.save_png(path)])

func _cast(bits: int, frames: int) -> void:
	_game.scripted_skills = bits
	await _wait(3)
	_game.scripted_skills = 0
	await _wait(frames)

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	_game = Game.new()
	root.add_child(_game)
	_game.session_bind_ip = "127.0.0.1"
	await _wait(30)
	var profile: Dictionary = _game.progress.profile
	var d: Dictionary = _game.progress.data
	profile.gold = 900
	profile.shards = {"have": 6, "earned": 9, "spent": 3}
	var mage := Profile.class_state(profile, "mage")
	mage.level = 20
	mage.ranks = {"fire_1": 3, "fire_2": 3, "fire_3": 3, "fire_4": 3, "fire_5": 1, "fire_6": 1, "frost_1": 2}
	mage.ultimate = "fire_6"
	mage.soul_paid = 3
	mage.bar = ["fire_1", "fire_3", "fire_5", "frost_1"]
	var archer := Profile.class_state(profile, "archer")
	archer.level = 8
	archer.ranks = {"beast_1": 3, "beast_2": 1}
	archer.bar = ["beast_1"]
	# 1) The talent screen: a fire mage with Inferno.
	_game.main_menu._open_talents()
	var screen: Control = _game.main_menu._talent_screen
	screen.selected = "fire_6"
	screen._refresh()
	await _wait(20)
	await _shot("01-talentmenue-feuermagier.png")
	# 2) The archer on level 8: learned, available and locked talents.
	screen._pick_class("archer")
	screen.selected = "beast_3"
	screen._refresh()
	await _wait(10)
	await _shot("02-talentmenue-bogenschuetze-stufen.png")
	screen.visible = false
	# 3) A run as the fire mage: the talent bar after Flammenpfeil and Feuerring.
	_game.requested_seed = 4242
	_game._start_solo(false, "mage")
	await _wait(60)
	await _cast(1 << TalentCombat.BAR_BIT, 70)
	await _cast(1 << (TalentCombat.BAR_BIT + 1), 4)
	await _shot("03-lauf-talentleiste-feuerring.png")
	# 4) Inferno (R), once the global cooldown is over.
	await _wait(60)
	await _cast(1 << TalentCombat.ULT_BIT, 3)
	await _shot("04-lauf-inferno.png")
	# 5) Staged: the soul shard banner as a boss drop shows it.
	_game.progress.local_event.emit({"kind": "shard", "have": 7})
	await _wait(40)
	await _shot("05-seelensplitter-erhalten.png")
	_game._leave_session()
	await _wait(20)
	# 6) The beast master's wolf in a run.
	_game.requested_seed = 4242
	_game._start_solo(false, "archer")
	await _wait(60)
	await _cast(1 << TalentCombat.BAR_BIT, 90)
	await _shot("06-lauf-wolfsgefaehrte.png")
	_game._leave_session()
	await _wait(10)
	# 6b) The same talent with the bear as companion, then the pause menu with the shards.
	archer.companion = "bear"
	_game.requested_seed = 4242
	_game._start_solo(false, "archer")
	await _wait(60)
	await _cast(1 << TalentCombat.BAR_BIT, 90)
	await _shot("08-lauf-baer.png")
	_game.set_pause_open(true, "overview")
	await _wait(10)
	await _shot("09-pausenmenue-seelensplitter.png")
	_game.set_pause_open(false)
	_game._leave_session()
	await _wait(10)
	# 6c) The talent screen on the beast master with the companion choice.
	_game.main_menu._open_talents()
	var beast_screen: Control = _game.main_menu._talent_screen
	beast_screen._pick_class("archer")
	beast_screen.selected = "beast_1"
	beast_screen._refresh()
	await _wait(10)
	await _shot("10-talentmenue-begleiter-baer.png")
	beast_screen.visible = false
	# 7) The same talents in the Frostgruft: the fire mage casts Feuerring there.
	_game.queue_free()
	_game = null
	var frost: Node = FrostScene.instantiate()
	frost.class_id = "mage"
	root.add_child(frost)
	await _wait(30)
	var frost_state := Profile.class_state(frost.profile, "mage")
	frost_state.level = 20
	frost_state.ranks = mage.ranks.duplicate()
	frost_state.ultimate = "fire_6"
	frost_state.bar = mage.bar.duplicate()
	frost.talents.bind(frost, frost.profile, frost.profile_path, "mage")
	await _wait(10)
	frost.talents.press(1)
	await _wait(6)
	await _shot("07-frostgruft-feuerring-talentleiste.png")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Profile.default_path()))
	quit(0)
