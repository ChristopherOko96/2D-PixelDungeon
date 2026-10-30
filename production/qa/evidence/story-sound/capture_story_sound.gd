extends SceneTree
## Windowed play log of the story worlds' sounds (src/hero/story_sound.gd,
## src/hero/story_feel.gd running src/vfx/feedback.gd). The game runs its own
## _process (its _update order, the kits under as_source, the hell monsters'
## release hooks, the feel); this script only starts fights, aims the archer,
## starts a few attacks and takes the pictures. Every played event is logged
## with its bus and level by the real sfx.gd (audible). Pictures: a hell fight,
## a Frostgruft enemy mid-windup (the crypt's lean-back) with a close-up, and
## the death timer twice (particles keep moving while the hero falls).
## Usage (production/ is ignored by Godot's importer, the script runs by path):
##   godot --path . --windowed --resolution 1280x720 -s <this file> -- <out dir>
## The run uses its own save file (user://capture_story_sound.cfg).

const HellScene = preload("res://src/hell/hell_dungeon.tscn")
const FrostScene = preload("res://src/hell/frost_dungeon.tscn")
const FrostMoves = preload("res://src/hell/frost_moves.gd")
const SAVE := "user://capture_story_sound.cfg"

var out_dir := ""
var lines: PackedStringArray = []
var world := ""
var game: Node
## While true the hero cannot be hurt (and keeps its hearts).
var safe := true
var frames := 0


class LoggingSfx extends "res://src/vfx/sfx.gd":
	var log_to: Callable
	func play(name: String, pitch_spread: float = 0.08, category: String = "") -> void:
		var before := play_count
		super.play(name, pitch_spread, category)
		if play_count > before:
			var player: AudioStreamPlayer = _players[(_next - 1 + _players.size()) % _players.size()]
			var layer := str(_meta.get(name, {}).get("with", ""))
			var group := category if category != "" else str(_meta.get(name, {}).get("category", ""))
			log_to.call("%-15s group=%-8s bus=%-6s level=%6.1f dB%s" % [name, group, last_bus, player.volume_db, (" +layer " + layer) if layer != "" else ""])
		else:
			log_to.call("%-15s (throttled or unknown)" % name)


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else ProjectSettings.globalize_path("res://production/qa/evidence/story-sound")
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()


func _log(text: String) -> void:
	var line := "[%s %6.2fs] %s" % [world, frames / 60.0, text]
	lines.append(line)
	print(line)


func _note(text: String) -> void:
	lines.append("")
	lines.append("== %s: %s" % [world, text])
	print("== ", text)


## Lets the game run `n` of its own frames.
func _wait(n: int) -> void:
	for i in range(n):
		if game != null and safe and not game.state.is_empty():
			game.state.inv = 99.0
			game.state.hp = maxi(int(game.state.hp), 6)
		await process_frame
		frames += 1


## Saves the frame; with `focus` (a world point) also a 2x close-up around it.
## The hero stays unhurt: the picture waits for a frame its invulnerability
## blink drew it in (hell_game._draw_hero hides it on odd 1/20 s of state.t).
func _shot(name: String, focus := Vector2.INF) -> Image:
	await _wait(1)
	var tries := 0
	while float(game.state.inv) > 0.0 and int(float(game.state.t) * 20.0) % 2 == 1 and tries < 6:
		await _wait(1)
		tries += 1
	var image := root.get_texture().get_image()
	var path := out_dir.path_join(name + ".png")
	_log("SCREENSHOT %s (%d)" % [name, image.save_png(path)])
	if focus.is_finite():
		var screen: Vector2 = game.get_viewport().get_canvas_transform() * focus
		var box := Rect2i(Vector2i(clampi(int(screen.x) - 240, 0, image.get_width() - 480), clampi(int(screen.y) - 150, 0, image.get_height() - 270)), Vector2i(480, 270))
		var crop := image.get_region(box)
		crop.resize(960, 540, Image.INTERPOLATE_NEAREST)
		crop.save_png(out_dir.path_join(name + "-nah.png"))
	return image


## Pixels that differ between two pictures inside `box` (the play field without the HUD).
func _changed(a: Image, b: Image, box: Rect2i) -> int:
	var n := 0
	for y in range(box.position.y, box.end.y):
		for x in range(box.position.x, box.end.x):
			if not a.get_pixel(x, y).is_equal_approx(b.get_pixel(x, y)):
				n += 1
	return n


func _open(scene: PackedScene, floor_n: int) -> void:
	game = scene.instantiate()
	game.class_id = "archer"
	game.start_floor = floor_n
	game.meta_path = SAVE
	root.add_child(game)
	await process_frame
	var sfx := LoggingSfx.new()
	sfx.log_to = _log
	game.add_child(sfx)
	await process_frame
	if game.sfx != null:
		game.sfx.queue_free()
	game.sfx = sfx
	game.state.offer = []
	await _wait(5)


## Walks the hero into the middle of a room of `type` and starts its fight.
func _enter(type: String) -> Dictionary:
	for r: Dictionary in game.W.rooms:
		if r.type == type and (type == "boss" or r.bw >= 20):
			var mid := Vector2(r.bx + r.bw / 2.0, r.by + r.bh / 2.0)
			var best: Vector2i = r.cells[0]
			for c: Vector2i in r.cells:
				if game.W.grid[c.y * game.W.cols + c.x] == 1 and Vector2(c).distance_to(mid) < Vector2(best).distance_to(mid):
					best = c
			game.player.x = (best.x + 0.5) * game.C
			game.player.y = (best.y + 0.8) * game.C
			game.camera.position = Vector2(game.player.x, game.player.y)
			game.state.room = r.index
			game._start_fight(r)
			return r
	return {}


func _foes() -> Array:
	var me := Vector2(game.player.x, game.player.y)
	var out: Array = game.mobs.filter(func(m: Dictionary) -> bool: return float(m.get("spawn", 0.0)) <= 0.0 and float(m.hp) > 0.0)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return (a.p as Vector2).distance_to(me) < (b.p as Vector2).distance_to(me))
	return out


## The archer shoots at the nearest foe for `n` frames.
func _shoot(n: int) -> void:
	for i in range(n):
		var foes := _foes()
		if not foes.is_empty() and i % 6 == 0:
			var m: Dictionary = foes[0]
			game.state.cool = 0.0
			game._fire((((m.p as Vector2) - Vector2(0, m.cy)) - Vector2(game.player.x, game.player.y - 40)).normalized())
		await _wait(1)


## A hell monster of `id` in the room (spawned near the hero when none is there).
func _hell(id: String, offset: Vector2, boss := false) -> Dictionary:
	for m: Dictionary in game.mobs:
		if str(m.get("id", "")) == id and float(m.get("spawn", 0.0)) <= 0.0 and bool(m.boss) == boss:
			return m
	var m: Dictionary = game.monsters.spawn(game.state.room, Vector2(game.player.x, game.player.y) + offset, id, boss)
	m.spawn = 0.0
	return m


## Starts hell monster `m`'s attack of `kind`; the game runs it.
func _act(m: Dictionary, kind: String) -> void:
	for k in range((m.st.attacks as Array).size()):
		if str(m.st.attacks[k].kind) == kind:
			var to: Vector2 = Vector2(game.player.x, game.player.y) - (m.p as Vector2)
			game.monsters._start_act(m, k, to, maxf(to.length(), 1.0))
			_log("start %s %s (%s)" % ["guardian" if m.boss else "monster", m.id, kind])
			return


func _run() -> void:
	world = "hell"
	await _open(HellScene, 2)
	_note("a fight room of floor 2: doors lock, monsters rise, the archer shoots (hits and kills in the crypt materials)")
	var room := _enter("combat")
	await _wait(90)
	await _shoot(120)
	_note("regular monsters' attacks at the crypt's enemy level: hellhound bite and fire breath, magma slime slam (no boss blast)")
	var hound := _hell("hoellenhund", Vector2(320, -60))
	hound.hp = 999.0
	_act(hound, "breath")
	await _wait(60)
	_act(hound, "dash")
	await _wait(90)
	var slime := _hell("magmaschleim", Vector2(260, 60))
	slime.hp = 999.0
	_act(slime, "slam")
	await _wait(90)
	await _shot("hoelle-1-kampf")
	_note("a heart dropped at the hero: the crypt's loot_taken")
	game.state.hp = 4
	safe = false
	game.state.inv = 99.0
	game.W.ents.append({"type": "heart", "x": game.player.x, "y": game.player.y, "room": room.index})
	await _wait(30)
	safe = true
	_note("the guardian's room: its arrival, its breath (boss level), its fall: boss kill and room clear only")
	game.mobs.clear()
	await _wait(10)
	_enter("boss")
	await _wait(30)
	var guardian: Dictionary = {}
	for m: Dictionary in game.mobs:
		if bool(m.boss):
			guardian = m
	if not guardian.is_empty():
		# its arrival runs to its end
		var t := 0
		while guardian.intro != null and t < 600:
			await _wait(1)
			t += 1
		await _wait(30)
		guardian.hp = 999.0
		_act(guardian, "breath")
		await _wait(90)
		_act(guardian, "summon")
		await _wait(90)
		await _shot("hoelle-2-waechter")
		_note("the guardian falls")
		guardian.hp = 0.0
		await _wait(120)
	game.queue_free()
	await process_frame
	game = null

	world = "frost"
	await _open(FrostScene, 2)
	_note("a fight room of floor 2")
	_enter("combat")
	await _wait(90)
	await _shoot(90)
	_note("an ice zombie winds up its frost breath (the crypt's lean-back) and breathes a soul shot")
	var zombie: Dictionary = {}
	game._spawn_mob(game.state.room, Vector2(game.player.x + 150, game.player.y + 10), "ice_zombie")
	zombie = game.mobs[game.mobs.size() - 1]
	zombie.spawn = 0.0
	zombie.hp = 999.0
	zombie.max = 999.0
	await _wait(20)
	zombie.mv = {"next": 99.0, "cd": {}, "used": {}, "rage": false, "run": {}}
	game.as_source("moves", func() -> void: FrostMoves._begin(game, zombie, {"move": "frost_breath"}))
	var windup := float(FrostMoves.move("frost_breath").get("windup", 0.6))
	while not (zombie.mv.run as Dictionary).is_empty() and str(zombie.mv.run.phase) == "windup" and float(zombie.mv.run.t) > windup * 0.5:
		await _wait(1)
	var pose: Dictionary = game.feel.pose(zombie)
	_log("windup pose: lean %.3f scale %s attack %s" % [float(pose.lean), str(pose.scale), str((zombie.get("feel_e", {}) as Dictionary).get("attack", ""))])
	await _shot("frost-1-ausholen", (zombie.p as Vector2) - Vector2(0, 40))
	await _wait(60)
	_note("an ice crystal's five-shot fan: a soul shot at the enemy level")
	game._spawn_mob(game.state.room, Vector2(game.player.x - 300, game.player.y - 80), "ice_crystal")
	var crystal: Dictionary = game.mobs[game.mobs.size() - 1]
	crystal.spawn = 0.0
	crystal.hp = 999.0
	await _wait(20)
	crystal.shoot = 0.01
	await _wait(60)
	_note("the hero falls while a foe bursts: the crypt keeps moving its particles through the death timer")
	safe = false
	var foe: Array = _foes()
	for m: Dictionary in foe.slice(0, 3):
		m.hp = 0.01
		game._damage_mob(m, ((m.p as Vector2) - Vector2(game.player.x, game.player.y)).normalized() * 600.0)
	# the kills land (bursts, drops and dust in their materials), then the killing blow
	await _wait(3)
	game.state.hp = 1
	game.state.inv = 0.0
	game._hurt("im Test")
	await _wait(12)
	var before: Image = await _shot("frost-2-tod-a")
	var dead_a := float(game.state.dead)
	var live: Array = (game.feel.feedback.particles._particles as Array).duplicate()
	var was: Array = live.map(func(p: Dictionary) -> Vector2: return p.pos)
	await _wait(14)
	var after: Image = await _shot("frost-2-tod-b")
	var moved := 0
	for i in range(live.size()):
		if (live[i].pos as Vector2).distance_to(was[i]) > 0.5:
			moved += 1
	_log("death timer %.2fs -> %.2fs: %d of %d crypt particles moved, %d play-field pixels changed between the two pictures" % [dead_a, float(game.state.dead), moved, live.size(), _changed(before, after, Rect2i(320, 130, 640, 460))])
	await _wait(120)
	var file := FileAccess.open(out_dir.path_join("story_sound_play_log.txt"), FileAccess.WRITE)
	file.store_string("\n".join(lines) + "\n")
	file.close()
	print("STORY_SOUND_CAPTURE lines=%d -> %s" % [lines.size(), out_dir])
	quit(0)
