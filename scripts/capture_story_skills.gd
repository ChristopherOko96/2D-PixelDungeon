extends SceneTree
## Captures the hero skills in the story worlds (Hell-Dungeon, Frostgruft) in a
## fight: whirl, blade wave and Rage; backflip caltrops, arrow fist and the
## ballista draw; fireball, chain lightning, blink and the photon beam. The
## skill bar sits at the bottom of every picture. The hero stays unhurt.
## Usage:
##   godot --path . --windowed --resolution 1280x720 -s res://scripts/capture_story_skills.gd -- <output_dir>
const HellScene = preload("res://src/hell/hell_dungeon.tscn")
const FrostScene = preload("res://src/hell/frost_dungeon.tscn")
const HeroKit = preload("res://src/hell/hero_kit.gd")

## [world, class, key, frames to wait after the press, file name, hold]
const SHOTS := [
	["hell", "swordsman", "1", 5, "01-hoelle-wirbelklinge", false],
	["hell", "swordsman", "2", 9, "02-hoelle-klingenwelle", false],
	["hell", "swordsman", "4", 8, "03-hoelle-raserei", false],
	["hell", "archer", "3", 24, "04-hoelle-ruecksprung-kraehenfuesse", false],
	["hell", "archer", "4", 10, "05-hoelle-pfeilfaust", false],
	["hell", "archer", "2", 40, "06-hoelle-ballista-spannen", true],
	["hell", "mage", "1", 10, "07-hoelle-feuerball-flug", false],
	["hell", "mage", "1", 26, "08-hoelle-feuerball-explosion", false],
	["hell", "mage", "2", 4, "09-hoelle-kettenblitz", false],
	["hell", "mage", "3", 4, "10-hoelle-blinzeln", false],
	["hell", "mage", "4", 24, "11-hoelle-photoneneis", true],
	["frost", "mage", "4", 24, "12-frost-photoneneis", true],
	["frost", "mage", "2", 4, "13-frost-kettenblitz", false],
	["frost", "swordsman", "1", 5, "14-frost-wirbelklinge", false],
]

var _out := "res://production/qa/evidence/story-skills"
var _game: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		_out = args[0]
	_run.call_deferred()


func _wait(frames: int) -> void:
	for i in range(frames):
		if _game != null and not _game.state.is_empty():
			_game.state.inv = 0.0
			_game.state.hp = _game.state.max_hp
		await process_frame


func _shot(name: String) -> void:
	var image := root.get_texture().get_image()
	var path := _out.path_join(name + ".png")
	print("CAPTURED %s result=%d" % [path, image.save_png(path)])


func _start(world: String, class_id: String) -> void:
	if _game != null:
		_game.queue_free()
		await process_frame
	_game = (HellScene if world == "hell" else FrostScene).instantiate()
	_game.class_id = class_id
	_game.start_floor = 2
	root.add_child(_game)
	await _wait(5)
	while int(_game.state.level) < 10:
		HeroKit.gain(_game, HeroKit.need(_game.theme.leveling, int(_game.state.level)) - int(_game.state.exp))
	_game.state.offer = []
	_game.state.cards_due = 0
	await _wait(40)
	# the largest combat room, hero in its middle, the fight running
	var best: Dictionary = {}
	for r: Dictionary in _game.W.rooms:
		if str(r.type) == "combat" and (best.is_empty() or int(r.bw) * int(r.bh) > int(best.bw) * int(best.bh)):
			best = r
	if not best.is_empty():
		# the open floor cell nearest the room's middle (all eight neighbours open)
		var middle := Vector2(best.bx + best.bw / 2.0, best.by + best.bh / 2.0)
		var spot := Vector2i(int(middle.x), int(middle.y))
		var near := INF
		for c: Vector2i in best.cells:
			var open := true
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					if _game._cell_blocked(c.x + dx, c.y + dy, true): open = false
			if open and Vector2(c).distance_to(middle) < near:
				near = Vector2(c).distance_to(middle)
				spot = c
		_game.player.x = (spot.x + 0.5) * 96.0
		_game.player.y = (spot.y + 0.7) * 96.0
		_game.camera.position = Vector2(_game.player.x, _game.player.y)
		_game.state.room = best.index
		_game._start_fight(best)
	await _wait(170)
	_game.state.offer = []


func _target() -> Vector2:
	var me := Vector2(_game.player.x, _game.player.y - 40.0)
	var best := me + Vector2(320.0, 0.0)
	var near := INF
	for m: Dictionary in _game.mobs:
		var p: Vector2 = m.p - Vector2(0, m.cy)
		if m.spawn <= 0.0 and p.distance_to(me) < near and p.distance_to(me) > 120.0:
			near = p.distance_to(me)
			best = p
	return best


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	for spec: Array in SHOTS:
		await _start(spec[0], spec[1])
		_game.aim_at = _target()
		_game.state.skill_cd.clear()
		HeroKit.press(_game, spec[2])
		await _wait(int(spec[3]))
		await _shot(spec[4])
		if spec[5]:
			HeroKit.release(_game, spec[2])
	quit()
