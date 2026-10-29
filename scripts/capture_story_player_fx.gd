extends SceneTree
## Captures the hero's crypt effects in the story worlds (src/hero/story_feel.gd,
## docs/VFX-SYSTEM.de.md) from the real windowed game, in the Frostgruft and the
## Hell-Dungeon: the level-up (sheet, pillar, ring, bloom), the mage's splash
## (magic burst, gold ring), a thrown fire potion and its pool, a chest opening,
## magic shots, arrows and a blade meeting a wall (chips, cracks, splash, sparks,
## clang), a heap breaking a secret wall, the heal marker, the hero's conditions
## (ice block, poison), the invulnerability blink with the hit frame, the dead
## hero, and the hero's shadow (a 4x close-up, and throughout).
## Usage:
##   godot --path . --windowed --resolution 1280x720 -s res://scripts/capture_story_player_fx.gd -- <output_dir>
const FrostScene = preload("res://src/hell/frost_dungeon.tscn")
const HellScene = preload("res://src/hell/hell_dungeon.tscn")
const HeroKit = preload("res://src/hell/hero_kit.gd")
const HeroFx = preload("res://src/hell/hero_fx.gd")
const SAVE := "user://capture_story_player_fx.cfg"

var _out := "res://production/qa/evidence/vfx-story-player"
var _game: Node
var _safe := true


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		_out = args[0]
	_run.call_deferred()


func _wait(frames: int) -> void:
	for i in range(frames):
		if _game != null and not _game.state.is_empty() and _safe:
			_game.state.inv = 99.0
			_game.state.hp = maxi(_game.state.hp, 6)
		await process_frame


## Saves the frame; with `focus` (a world point) also a close-up around it
## (`zoom` 2: 480 x 270 screen px, 4: 240 x 135, scaled to 960 x 540).
## The hero's invulnerability blink is switched off for the frame unless `blink`.
func _shot(name: String, focus := Vector2.INF, blink := false, zoom := 2) -> void:
	if _game != null and _safe and not blink:
		_game.state.inv = 0.0
	await process_frame
	var image := root.get_texture().get_image()
	var path := _out.path_join(name + ".png")
	print("CAPTURED %s result=%d" % [path, image.save_png(path)])
	if focus.is_finite() and _game != null:
		var screen: Vector2 = _game.get_viewport().get_canvas_transform() * focus
		var w := 960 / zoom
		var h := 540 / zoom
		var box := Rect2i(Vector2i(clampi(int(screen.x) - w / 2, 0, image.get_width() - w), clampi(int(screen.y) - h / 2, 0, image.get_height() - h)), Vector2i(w, h))
		var crop := image.get_region(box)
		crop.resize(960, 540, Image.INTERPOLATE_NEAREST)
		var close := _out.path_join(name + "-nah.png")
		print("CAPTURED %s result=%d" % [close, crop.save_png(close)])


func _open(scene: PackedScene, class_id: String) -> void:
	_game = scene.instantiate()
	_game.class_id = class_id
	_game.start_floor = 2
	_game.meta_path = SAVE
	root.add_child(_game)
	await _wait(5)
	_game.state.offer = []
	_game.state.toasts = []
	await _wait(60)


func _close() -> void:
	_game.queue_free()
	_game = null
	await process_frame


func _hero() -> Vector2:
	return Vector2(_game.player.x, _game.player.y - 40)


## Moves the hero (and the camera) to world point `p` (its feet).
func _place(p: Vector2) -> void:
	_game.player.x = p.x
	_game.player.y = p.y
	_game.camera.position = p - Vector2(0, 40)
	var r: int = _game._room_at_world(p.x, p.y - 12.0)
	if r >= 0:
		_game.state.room = r
		_game.state.visited[r] = true


## A floor cell next to a straight wall on its right, nearest the hero.
func _wall_cell() -> Vector2i:
	var best := Vector2i(-1, -1)
	var me: Vector2 = Vector2(_game.player.x, _game.player.y) / float(_game.C)
	for cy in range(2, int(_game.W.rows) - 2):
		for cx in range(2, int(_game.W.cols) - 2):
			var ok: bool = _game._cell(cx, cy) == 1 and _game._cell(cx - 1, cy) == 1 and _game._cell(cx - 2, cy) == 1 and _game._cell(cx, cy - 1) == 1 and _game._cell(cx, cy + 1) == 1
			ok = ok and _game._cell(cx + 1, cy) == 0 and _game._cell(cx + 1, cy - 1) == 0 and _game._cell(cx + 1, cy + 1) == 0
			ok = ok and (_game.solid_grid as Dictionary).get(cy * int(_game.W.cols) + cx, []).is_empty() and _game._room_at_world((cx + 0.5) * _game.C, (cy + 0.5) * _game.C) >= 0
			if ok and (best.x < 0 or Vector2(cx, cy).distance_to(me) < Vector2(best).distance_to(me)):
				best = Vector2i(cx, cy)
	return best


func _mob(offset: Vector2) -> Dictionary:
	var at := Vector2(_game.player.x, _game.player.y) + offset
	var m: Dictionary
	if _game.monsters != null:
		m = _game.monsters.spawn(_game.state.room, at, "glutschaedel", false)
		for i in range(m.cds.size()):
			m.cds[i] = 99.0
	else:
		_game._spawn_mob(_game.state.room, at, "frost_skeleton" if (_game.theme.mobs as Dictionary).has("frost_skeleton") else str(_game.theme.mobs.keys()[1]))
		m = _game.mobs[_game.mobs.size() - 1]
		m.shoot = 99.0
	m.spawn = 0.0
	m.hp = 9999.0
	m.max = 9999.0
	m.sp = 0.0
	return m


func _index(type: String, id: String) -> int:
	var bag: Array = _game.story_items.players[1].inventory.bag
	for i in range(bag.size()):
		if str(bag[i].type) == type and str(bag[i].get("id", bag[i].get("potion", ""))) == id: return i
	return -1


func _mage(scene: PackedScene, prefix: String) -> void:
	await _open(scene, "mage")
	# level-up: the crypt's sheet, its pillar and ring, the bloom
	HeroKit.gain(_game, HeroKit.need(_game.theme.leveling, int(_game.state.level)) - int(_game.state.exp))
	_game.state.offer = []
	await _wait(9)
	await _shot(prefix + "-1-levelup", _hero())
	_game.state.offer = []
	_game.state.toasts = []
	await _wait(60)
	# the mage's splash on a monster: the crypt's magic burst and gold ring
	var m := _mob(Vector2(300, -10))
	await _wait(20)
	for i in range(120):
		if (_game.feel.perk_events() as Array).any(func(e: Dictionary) -> bool: return str(e.kind) == "blast"):
			break
		if i % 30 == 0:
			_game.state.cool = 0.0
			_game._fire((((m.p as Vector2) - Vector2(0, m.cy)) - _hero()).normalized())
		await _wait(1)
	await _wait(2)
	await _shot(prefix + "-2-magierspritzer", (m.p as Vector2) - Vector2(0, 40))
	_game.shots.clear()
	m.hp = 0.0
	await _wait(80)
	# a thrown fire potion: its splash in its colour, then the crypt's pool
	var items: Node = _game.story_items
	items.give(items.inventory.make_stack("potion", "fire"), Vector2.ZERO)
	var target := Vector2(_game.player.x + 230, _game.player.y + 20)
	items.act("inv_throw", _index("potion", "fire"), target)
	await _wait(3)
	await _shot(prefix + "-3-feuertrank", target)
	await _wait(50)
	await _shot(prefix + "-4-feuerlache", target)
	# a chest: the crypt's splinters and pickup sheet; heal and shield markers on the hero
	var chest := {"type": "chest", "x": _game.player.x - 90.0, "y": _game.player.y - 10.0, "room": int(_game.state.room), "loot": {"gems": 3, "heart": false}, "magic": false}
	_game.W.ents.append(chest)
	_game.player.x -= 20.0
	await _wait(2)
	_game.act()
	_game.feel.hero_perk("heal")
	await _wait(4)
	await _shot(prefix + "-5-truhe-heilung", Vector2(chest.x, chest.y - 30))
	_game.state.toasts = []
	await _wait(40)
	# conditions: the crypt's ice block and poison bubbles
	HeroFx.apply(_game, "freeze", 9.0, 1.0)
	HeroFx.apply(_game, "poison", 9.0, 1.0)
	await _wait(20)
	await _shot(prefix + "-6-zustaende", _hero())
	HeroFx.clear(_game)
	await _wait(20)
	# the invulnerability blink: 45 % and the hit frame (dungeon_view.gd)
	_game.state.inv = 1.0
	_game.state.t = 4.83
	await _shot(prefix + "-7-unverwundbar", _hero(), true)
	await _wait(20)
	# magic shots into a wall: chips, a crack, the magic splash along the wall
	var cell := _wall_cell()
	if cell.x >= 0:
		var C: float = _game.C
		_place(Vector2((cell.x - 0.6) * C, (cell.y + 0.5) * C + 40.0))
		await _wait(30)
		# the hero's shadow on the plain floor (dungeon_view.gd _draw_shadow), close up
		await _shot(prefix + "-0-schatten", Vector2(_game.player.x, _game.player.y - 20), false, 4)
		for i in range(14):
			_game.state.cool = 0.0
			_game._fire(Vector2.RIGHT)
			await _wait(4)
		await _shot(prefix + "-8-wandtreffer", Vector2((cell.x + 1) * C, (cell.y + 0.5) * C))
		await _wait(40)
		# a skull heap's fall opens the wall: the crypt's wall break
		var room := int(_game.state.room)
		_game.W.doors.append({"kind": "secret", "cells": [Vector2i(cell.x + 1, cell.y)], "broken": false, "a": room, "b": room, "cx": (cell.x + 1.5) * C, "cy": (cell.y + 0.5) * C, "dir": "v", "group": "", "x0": cell.x + 1, "x1": cell.x + 1, "y0": cell.y, "y1": cell.y})
		var heap := {"type": "skullheap", "x": (cell.x + 0.5) * C, "y": (cell.y + 0.95) * C, "hp": 2, "max_hp": 2, "door": _game.W.doors.size() - 1, "room": int(_game.state.room)}
		_game.breakables.append(heap)
		_game._hit_breakable(heap, Vector2(heap.x, heap.y - 40))
		await _wait(3)
		await _shot(prefix + "-9-schaedel-schlag", Vector2(heap.x, heap.y - 40))
		await _wait(10)
		_game._hit_breakable(heap, Vector2(heap.x, heap.y - 40))
		await _wait(4)
		await _shot(prefix + "-10-mauerbruch", Vector2((cell.x + 1) * C, (cell.y + 0.5) * C))
		await _wait(30)
	# the dead hero: it falls and lies, like the crypt's fallen actors
	_safe = false
	_game.state.inv = 0.0
	_game.state.hp = 0
	_game.state.dead = 1.8
	_game.state.death_why = "Test"
	await _wait(45)
	await _shot(prefix + "-11-tot", _hero())
	_safe = true
	await _close()


## Arrows into a wall: the crypt's stone chips, sparks, hit spark and crack.
func _archer(scene: PackedScene, prefix: String) -> void:
	await _open(scene, "archer")
	var cell := _wall_cell()
	if cell.x >= 0:
		var C: float = _game.C
		_place(Vector2((cell.x - 0.8) * C, (cell.y + 0.5) * C + 40.0))
		await _wait(30)
		for i in range(5):
			_game.state.cool = 0.0
			_game._fire(Vector2(1.0, (i - 2) * 0.12))
			await _wait(12)
		_game.state.cool = 0.0
		_game._fire(Vector2.RIGHT)
		await _wait(5)
		await _shot(prefix + "-13-pfeile-wand", Vector2((cell.x + 1) * C, (cell.y + 0.5) * C))
		await _wait(40)
		await _shot(prefix + "-14-pfeile-wand-risse", Vector2((cell.x + 1) * C - 20, (cell.y + 0.5) * C), false, 4)
	await _close()


func _swordsman(scene: PackedScene, prefix: String) -> void:
	await _open(scene, "swordsman")
	var cell := _wall_cell()
	if cell.x >= 0:
		var C: float = _game.C
		_place(Vector2((cell.x + 0.6) * C, (cell.y + 0.5) * C + 40.0))
		await _wait(30)
		for i in range(3):
			_game.state.cool = 0.0
			_game._fire(Vector2.RIGHT)
			await _wait(14)
		_game.state.cool = 0.0
		_game._fire(Vector2.RIGHT)
		await _wait(3)
		await _shot(prefix + "-12-klinge-wand", Vector2((cell.x + 1) * C, (cell.y + 0.5) * C))
	await _close()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	await _mage(FrostScene, "frost")
	await _swordsman(FrostScene, "frost")
	await _archer(FrostScene, "frost")
	await _mage(HellScene, "hoelle")
	await _swordsman(HellScene, "hoelle")
	await _archer(HellScene, "hoelle")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	quit()
