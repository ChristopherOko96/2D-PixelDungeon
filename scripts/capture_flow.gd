extends SceneTree
## Captures evidence of the floor route, chests and the new effect animations
## from the real windowed game: the open onward gate in a wall, a chest being
## smashed and its perk loot, sword slashes with hit sparks and gore, the
## mage's orbs and explosions, the whirl, the Rage aura, the beam and the boss
## room's stairs. Input is scripted (game.scripted_*). Usage:
##   godot --path . --resolution 1280x720 -s res://scripts/capture_flow.gd -- <output_dir>
const Game = preload("res://src/game.gd")
const Dungeon = preload("res://src/dungeon/dungeon_generator.gd")

var _out := "res://production/qa/evidence/flow-chests-fx"
var _game: Node

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty(): _out = args[0]
	_run.call_deferred()

func _wait(frames: int) -> void:
	for i in range(frames):
		if _game != null and _game.players.has(1):
			_game.players[1].invulnerable = 5.0
			_game.players[1].hp = maxi(2, int(_game.players[1].hp))
		await process_frame

func _shot(name: String) -> void:
	await _wait(2)
	var image := root.get_texture().get_image()
	print("CAPTURED %s result=%d" % [name, image.save_png(_out.path_join(name))])

func _entry(label: String) -> Dictionary:
	for entry: Dictionary in _game.main_menu.debug_entries:
		if str(entry.label).contains(label): return entry
	return {}

func _start(entry: Dictionary, class_id: String, level_exp: int) -> void:
	_game.requested_seed = 4242
	_game.main_menu._pick_debug(entry)
	_game.main_menu._choose_class(class_id)
	await _wait(20)
	if level_exp > 0:
		_game.team_progress.add_exp(level_exp)
		_game.players[1].offer_queue = []
		_game.players[1].offer = []

func _nearest_enemy() -> Dictionary:
	var best: Dictionary = {}
	var distance := INF
	for enemy: Dictionary in _game.enemies:
		if float(enemy.hp) <= 0.0: continue
		var d := Vector2(enemy.pos).distance_to(_game.players[1].pos)
		if d < distance:
			distance = d
			best = enemy
	return best

func _face(enemy: Dictionary, distance: float) -> void:
	for angle in [PI, 0.0, PI * 0.5, -PI * 0.5, PI * 0.75, -PI * 0.75]:
		var spot: Vector2 = Vector2(enemy.pos) + Vector2.from_angle(angle) * distance
		if not Dungeon.segment_blocked(enemy.pos, spot, 16.0, _game.current_layout):
			_game.players[1].pos = spot
			return

func _clear_room() -> void:
	for enemy: Dictionary in _game.enemies: enemy.hp = 0.0
	_game.enemies.clear()
	_game._check_room_end()

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	_game = Game.new()
	root.add_child(_game)
	_game.session_bind_ip = "127.0.0.1"
	await _wait(30)
	# 1) Sword: slashes, hit sparks and bone bursts on floor 1.
	await _start(_entry("RAUM 02"), "swordsman", 0)
	var target := _nearest_enemy()
	if not target.is_empty():
		_face(target, 44.0)
		await _wait(30)
		_game.scripted_target = Vector2(target.pos)
		_game.scripted_fire = true
		await _wait(30)
		# The shot just as a swing reaches the picture.
		var seen := int(_game.state.get("players", {}).get(1, {}).get("swings", 0))
		for i in range(60):
			await process_frame
			if int(_game.state.get("players", {}).get(1, {}).get("swings", 0)) != seen: break
		await _shot("01-schwert-hieb.png")
		await _wait(30)
		await _shot("02-schwert-treffer.png")
		_game.scripted_fire = false
	# 2) The cleared room: the onward gate stands open in the wall.
	_clear_room()
	await _wait(10)
	for exit: Dictionary in _game.current_layout.exits:
		if bool(exit.get("forward", false)):
			var rect: Array = exit.rect
			_game.players[1].pos = Vector2(rect[0] + 16, rect[1] + 90)
	await _wait(50)
	await _shot("03-tor-in-der-wand.png")
	# The way back: steps going up towards the light.
	for exit: Dictionary in _game.current_layout.exits:
		if str(exit.kind) == "door" and not bool(exit.get("forward", false)):
			var back: Array = exit.rect
			_game.players[1].pos = Vector2(back[0] + 16, back[1] + 90)
	await _wait(60)
	await _shot("03b-tor-zurueck.png")
	_game._leave_session()
	await _wait(10)
	# 3) A chest: smashed by sword swings, then its perk loot.
	_game.requested_seed = 4242
	await _start(_entry("RAUM 01"), "swordsman", 0)
	var chest_room := -1
	for index in range(_game.floor_layouts.size()):
		if _game.chests.chests.has(str(_game.floor_layouts[index].id)) and chest_room < 0: chest_room = index + 1
	if chest_room > 0:
		_game._debug_jump(1, chest_room)
		await _wait(10)
		_clear_room()
		var chest: Dictionary = _game.chests.chests[str(_game.current_layout.id)][0]
		_game.players[1].pos = Vector2(chest.pos) + Vector2(-46, 0)
		await _wait(40)
		await _shot("04-truhe.png")
		_game.scripted_target = Vector2(chest.pos)
		_game.scripted_fire = true
		for i in range(90):
			await _wait(1)
			if int(chest.hits) >= 2: break
		_game.scripted_fire = false
		await _wait(2)
		await _shot("05-truhe-getroffen.png")
		_game.scripted_fire = true
		for i in range(60):
			await _wait(1)
			if bool(chest.open): break
		_game.scripted_fire = false
		await _wait(40)
		_game.players[1].pos = Vector2(chest.pos) + Vector2(-60, 26)
		await _wait(10)
		await _shot("06-truhe-beute.png")
	_game._leave_session()
	await _wait(10)
	# 4) Mage on floor 2: orbs, magic bursts, a fireball explosion, slime.
	await _start(_entry("EBENE 2"), "mage", 4000)
	target = _nearest_enemy()
	if not target.is_empty():
		_face(target, 150.0)
		await _wait(30)
		_game.scripted_target = Vector2(target.pos)
		_game.scripted_fire = true
		await _wait(40)
		await _shot("07-magier-kugeln.png")
		_game.scripted_fire = false
		_game.scripted_skills = 1
		for i in range(40):
			await _wait(1)
			if _game.hero_skills.events.any(func(e: Dictionary) -> bool: return str(e.kind) == "burst"): break
		_game.scripted_skills = 0
		await _wait(4)
		await _shot("08-feuerball-explosion.png")
		target = _nearest_enemy()
		if not target.is_empty():
			_game.scripted_target = Vector2(target.pos)
			_game.scripted_skills = 8
			await _wait(40)
			await _shot("09-photoneneis.png")
			_game.scripted_skills = 0
	_game._leave_session()
	await _wait(10)
	# 5) Sword at level 10: whirl and the Rage aura.
	await _start(_entry("EBENE 2"), "swordsman", 4000)
	target = _nearest_enemy()
	if not target.is_empty():
		_face(target, 50.0)
		await _wait(30)
		_game.scripted_target = Vector2(target.pos)
		_game.scripted_skills = 8
		await _wait(10)
		_game.scripted_skills = 1
		await _wait(10)
		await _shot("10-wirbel-rage.png")
		_game.scripted_skills = 0
		_game.scripted_fire = true
		await _wait(30)
		await _shot("11-rage-hiebe.png")
		_game.scripted_fire = false
	_game._leave_session()
	await _wait(10)
	# 6) The boss room of floor 1 after the fight: stairs down.
	await _start(_entry("ENDRAUM"), "archer", 0)
	_clear_room()
	for exit: Dictionary in _game.current_layout.exits:
		if str(exit.kind) == "stairs":
			_game.players[1].pos = Vector2(exit.rect[0] - 60, exit.rect[1] + 16)
	await _wait(50)
	await _shot("12-treppe-naechste-ebene.png")
	_game._leave_session()
	await _wait(10)
	# 7) A horde closing in (floor 2), the hero holding the middle.
	await _start(_entry("EBENE 2"), "swordsman", 0)
	var near := 0
	for i in range(1800):
		await _wait(1)
		near = _game.enemies.filter(func(e: Dictionary) -> bool: return float(e.hp) > 0 and Vector2(e.pos).distance_to(_game.players[1].pos) < 260.0).size()
		if near >= 9: break
	print("HORDE_NEAR ", near, " frames")
	await _shot("14-horde.png")
	_game._leave_session()
	await _wait(10)
	# 8) Wall hits: magic splashing along a wall, then a sword clanging off it.
	await _start(_entry("RAUM 02"), "mage", 0)
	_clear_room()
	var wall_spot := _below_north_wall(110.0)
	if wall_spot.is_finite():
		_game.scripted_target = wall_spot + Vector2(0, -400)
		_game.scripted_fire = true
		await _wait(50)
		await _shot("15-magie-an-wand.png")
		_game.scripted_fire = false
	_game._leave_session()
	await _wait(10)
	await _start(_entry("RAUM 02"), "swordsman", 0)
	_clear_room()
	wall_spot = _below_north_wall(40.0)
	if wall_spot.is_finite():
		_game.scripted_target = wall_spot + Vector2(0, -200)
		_game.scripted_fire = true
		await _wait(40)
		await _shot("16-schwert-an-wand.png")
		_game.scripted_fire = false
	# 9) A crate smashed: splinters, then the planks it leaves.
	var crate: Dictionary = {}
	for item: Dictionary in _game.chests.chests.get(str(_game.current_layout.id), []):
		if str(item.kind) == "crate" and crate.is_empty(): crate = item
	if not crate.is_empty():
		_game.players[1].pos = Vector2(crate.pos) + Vector2(-48, 0)
		await _wait(30)
		await _shot("17-kiste-steht.png")
		_game.scripted_target = Vector2(crate.pos)
		_game.scripted_fire = true
		for i in range(90):
			await _wait(1)
			if bool(crate.open): break
		await _wait(4)
		_game.scripted_fire = false
		await _shot("18-kiste-zerschlagen.png")
	_game._leave_session()
	await _wait(10)
	quit(0)


## Puts the hero `distance` px below a north wall face; returns the spot.
func _below_north_wall(distance: float) -> Vector2:
	var layout: Dictionary = _game.current_layout
	var floor_cells := {}
	var walls := {}
	for entry: Dictionary in layout.painted_tiles:
		var cell := Vector2i(int(entry.x), int(entry.y))
		if bool(entry.get("solid", false)): walls[cell] = true
		elif str(entry.get("layer", "")) == "floor": floor_cells[cell] = true
	for cell: Vector2i in floor_cells:
		if walls.has(cell) or not walls.has(cell + Vector2i.UP): continue
		var spot := Vector2(cell) * 32.0 + Vector2(16, distance)
		var clear := true
		for step in range(int(distance / 32.0) + 2):
			if not floor_cells.has(cell + Vector2i(0, step)) or not floor_cells.has(cell + Vector2i(1, step)) or not floor_cells.has(cell + Vector2i(-1, step)): clear = false
		if not clear: continue
		_game.players[1].pos = spot
		return spot
	return Vector2.INF
