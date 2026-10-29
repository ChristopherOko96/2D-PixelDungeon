extends SceneTree
## Captures the Hell-Dungeon level art at fixed spots, for a before/after
## comparison of the sprite skin: start room, lava with a bridge, a lava
## stream, the vault, a demon seal, a skull heap, a locked gate, the boss
## gate and a deep floor. All rooms are cleared first, so no monsters cover
## the level; the hero stands in each shot for scale.
## `old` as second argument shows the first painted hell set (assets/sprites/hell)
## with its old settings, for the "before" pictures.
## Usage:
##   godot --path . --windowed --resolution 1280x720 -s res://scripts/capture_hell_skin.gd -- <output_dir> [old]
const HellScene = preload("res://src/hell/hell_dungeon.tscn")
const OLD_LOOK := {"sprites": "res://assets/sprites/hell/", "pixel": false, "pixel_tiles": false, "hero_scale": 3.6}

var _out := "res://production/qa/evidence/hell-skin/after"
var _old_look := false
var _game: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		_out = args[0]
	_old_look = args.size() > 1 and args[1] == "old"
	_run.call_deferred()


func _wait(frames: int) -> void:
	for i in range(frames):
		if _game != null and not _game.state.is_empty():
			_game.state.inv = 5.0
		await process_frame


func _shot(name: String) -> void:
	await _wait(3)
	# the hero blinks while invulnerable; let it stand still and visible for the picture
	_game.state.inv = 0.0
	await process_frame
	await process_frame
	var image := root.get_texture().get_image()
	var path := _out.path_join(name + ".png")
	print("CAPTURED %s result=%d" % [path, image.save_png(path)])


## Loads floor `n` with every room cleared, so the shots show the level, not a fight.
func _floor(n: int) -> void:
	_game.load_floor(n, false)
	await _wait(3)
	for r: Dictionary in _game.W.rooms:
		r.cleared = true
	_game.mobs.clear()


func _look(p: Vector2) -> void:
	_game.player.x = p.x
	_game.player.y = p.y
	_game.camera.position = p


func _ent(kind: String) -> Dictionary:
	for e: Dictionary in _game.W.ents:
		if e.type == kind:
			return e
	return {}


func _door(kind: String) -> Dictionary:
	for d: Dictionary in _game.W.doors:
		if d.kind == kind:
			return d
	return {}


## Centre of the first cell of grid type `cell` (2 lava, 3 bridge), or of the
## room with the most cells of that type when `room_wise` is set.
func _cell_spot(cell: int, room_wise := false) -> Vector2:
	var cols: int = _game.W.cols
	var best := -1
	var count := {}
	for i in range(_game.W.grid.size()):
		if int(_game.W.grid[i]) != cell:
			continue
		if not room_wise:
			return Vector2((i % cols + 0.5) * 96.0, (i / cols + 0.5) * 96.0)
		var r: int = _game.W.room_at[i]
		if r < 0:
			continue
		count[r] = int(count.get(r, 0)) + 1
		if best < 0 or count[r] > count[best]:
			best = r
	if best < 0:
		return Vector2.ZERO
	var room: Dictionary = _game.W.rooms[best]
	return Vector2((room.bx + room.bw / 2.0) * 96.0, (room.by + room.bh / 2.0) * 96.0)


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	_game = HellScene.instantiate()
	if _old_look:
		var theme: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(_game.theme_path))
		theme.merge(OLD_LOOK, true)
		var f := FileAccess.open("user://hell_old_look.json", FileAccess.WRITE)
		f.store_string(JSON.stringify(theme))
		f.close()
		_game.theme_path = "user://hell_old_look.json"
	root.add_child(_game)
	await _wait(40)
	await _floor(1)
	await _wait(30)
	await _shot("01-etage1-eingang")
	_look(_cell_spot(3))
	await _wait(30)
	await _shot("02-etage1-lava-bruecke")
	var gate := _door("lock")
	_look(Vector2(gate.cx, gate.cy + 150.0))
	await _wait(30)
	await _shot("03-etage1-verschlossenes-tor")
	var heap := _ent("skullheap")
	_look(Vector2(heap.x + 120.0, heap.y + 60.0))
	await _wait(30)
	await _shot("04-etage1-schaedelhaufen")
	var boss_gate := _door("boss")
	_look(Vector2(boss_gate.cx, boss_gate.cy + 170.0))
	await _wait(30)
	await _shot("05-etage1-bosstor")
	await _floor(2)
	var vault := _ent("vault")
	_look(Vector2(vault.x - 160.0, vault.y + 140.0))
	await _wait(60)
	await _shot("06-etage2-riesentresor")
	await _floor(4)
	var seal := _ent("seal")
	_look(Vector2(seal.x - 140.0, seal.y + 40.0))
	await _wait(30)
	await _shot("07-etage4-daemonensiegel")
	await _floor(5)
	_look(_cell_spot(2, true))
	await _wait(30)
	await _shot("08-etage5-lavastrom")
	await _floor(10)
	var deep := Vector2.ZERO
	var size := 0
	for r: Dictionary in _game.W.rooms:
		if r.type == "combat" and r.bw * r.bh > size:
			size = r.bw * r.bh
			deep = Vector2((r.bx + r.bw / 2.0) * 96.0, (r.by + r.bh / 2.0 + 0.9) * 96.0)
	_look(deep)
	await _wait(30)
	await _shot("09-etage10-tiefe")
	print("HELL_SKIN_CAPTURE done")
	quit(0)
