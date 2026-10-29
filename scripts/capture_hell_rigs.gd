extends SceneTree
## Captures Ignaroth's four forms (drache1..4, assets/data/hell_rigs.json) in two
## ways (needs a window: the renderer draws real textures).
##
## Mode "rig" (RIG PREVIEWS, not the game's draw path): RigLibrary loads the
## parts, RigPoses poses them, RigRenderer draws them (shadow, glow, hit flash,
## stumps, debris, particles) on tiles of the hell floor (darkened like the
## dungeon) beside the hero sprite (knight, the hell's hero_scale 3) for scale.
## The game draws Ignaroth from these only once DrakeRigHost is wired into
## hell_monsters.gd. No game state is used: no save, settings or meta
## (user://) is read or written. Per form, into the output folder:
##   rig-drache<N>-idle.png     standing at three moments
##   rig-drache<N>-walk.png     walking: far foot in the air, stride, near foot
##                              in the air (the stance foot on the floor line)
##   rig-drache<N>-attacks.png  end of the windup and the strike of every
##                              attack a severable part carries
##   rig-drache<N>-flight.png   forms 3/4: flying, top, bottom and middle of a
##                              wing beat
##   rig-drache<N>-hit.png      the hit flash on one struck part, the whole
##                              body, and the hit clip's first frame (u = 0,
##                              the head's strongest jerk)
##   rig-drache<N>-sever.png    after each severable part is cut off: the
##                              glowing stump, the stagger, debris and chips
##
## Mode "game" (THE GAME'S DRAW PATH): the real hell scene, debug-started in the
## boss room of floors 3, 6, 9 and 10 (start_at_boss), the hero kept alive.
## Ignaroth is drawn by hell_monsters.gd from its atlas (hell_monsters.json);
## a cyan cross marks where the rig puts the mouth (RigLibrary.foot_offset)
## and a yellow one the game's own breath origin (hell_monsters.gd: feet +
## (r * 0.95, -cy * 1.35)), so the two can be compared. The graphics choice
## and the meta progress go to this script's own user:// files, which it
## deletes again (the player's settings, meta and saves are never touched):
##   game-drache<N>-steht.png    after the arrival, facing the hero
##   game-drache<N>-schuss.png   a bolt (forms 1-3) or the star rings (4)
##                               right after release
##   game-drache<N>-atem.png     forms 3/4: the breath sweep
##   game-drache4-hd.png         the HD set (linear filtering) on floor 10
##
## Usage:
##   godot --path . --resolution 960x600 -s res://scripts/capture_hell_rigs.gd -- [output_dir] [forms, e.g. 1,4] [rig|game|all]

const RigLibrary = preload("res://src/rig/rig_library.gd")
const RigRenderer = preload("res://src/rig/rig_renderer.gd")
const RigPoses = preload("res://src/rig/rig_poses.gd")
const HellScene = preload("res://src/hell/hell_dungeon.tscn")
const HERO := preload("res://assets/sprites/0x72/knight_m_idle_anim_f0.png")
const FLOORS: Array[String] = ["res://assets/sprites/hell_0x72/floor_00.png", "res://assets/sprites/hell_0x72/floor_01.png",
	"res://assets/sprites/hell_0x72/floor_02.png", "res://assets/sprites/hell_0x72/floor_05.png"]
## This script's own graphics and meta files (never the player's).
const GRAPHICS_FILE := "user://capture_hell_rigs_graphics.cfg"
const META_FILE := "user://capture_hell_rigs_meta.cfg"
## The hell's hero_scale (src/hell/hell_game.gd, pixel set).
const HERO_SCALE := 3.0
## World px between the dragon's snout (its frame's edge) and the hero's feet (the hero stands left).
const HERO_GAP := 120.0
## The dungeon's darkness over the floor tiles.
const FLOOR_TINT := Color(0.42, 0.33, 0.33)
const PANEL := Vector2i(960, 600)
const COLUMNS := 3
## The attacks each form's severable parts carry (docs/HOELLE-RIGS.de.md):
## [attack id, attack kind (hell_monsters.json), carrying part].
const ATTACKS := {
	1: [["spucke", "bolt", "jaw"], ["graben", "burrow", "arm"], ["huschen", "dash", "tail_2"], ["satz", "slam", "tail_2"]],
	2: [["salve", "bolt", "jaw"], ["schwanz", "swing", "tail_2"], ["lavabruch", "burrow", "arm"]],
	3: [["bombenflug", "flight", "wing_near"], ["atem", "sweep", "throat"], ["faecher", "bolt", "horns"]],
	4: [["strahlen", "beam", "crystal_1"], ["leerenregen", "flight", "wing_far"], ["atem", "sweep", "throat"], ["echos", "echoes", "horns"]],
}
## The part each form's hit-flash panel lights.
const HIT_PART := {1: "jaw", 2: "arm", 3: "horns", 4: "crystal_2"}
## Game mode: per form [boss floor, shot attack id, breath attack id or ""].
const GAME := {1: [3, "spucke", ""], 2: [6, "salve", ""], 3: [9, "faecher", "atem"], 4: [10, "sterne", "atem"]}


class Stage extends Node2D:
	var paint: Callable

	func _draw() -> void:
		if paint.is_valid(): paint.call(self)


## Draws the two mouth markers over the game's actors (world coordinates).
class Marks extends Node2D:
	var marks: Array = []

	func _draw() -> void:
		for mark: Array in marks:
			var at: Vector2 = mark[0]
			var color: Color = mark[1]
			draw_line(at - Vector2(14, 0), at + Vector2(14, 0), color, 4.0)
			draw_line(at - Vector2(0, 14), at + Vector2(0, 14), color, 4.0)


var _out := "res://production/qa/evidence/hell-rigs"
var _forms: Array[int] = [1, 2, 3, 4]
var _mode := "all"
var _library: RefCounted
var _renderer: RefCounted
var _stage: Stage
var _camera: Camera2D
var _floors: Array[Texture2D] = []
var _uid := 100
var _saved: Array[String] = []
var _game: Node
var _marks: Marks


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0 and not args[0].is_empty(): _out = args[0]
	if args.size() > 1 and not args[1].is_empty():
		_forms.clear()
		for f: String in args[1].split(","): _forms.append(int(f))
	if args.size() > 2: _mode = args[2]
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out) if _out.begins_with("res://") else _out)
	_library = RigLibrary.new()
	if not _library.load_data():
		printerr("HELL_RIGS_CAPTURE: rig data did not load")
		quit(1)
		return
	if _mode in ["rig", "all"]:
		await _rig_previews()
	if _mode in ["game", "all"]:
		await _game_captures()
	print("HELL_RIGS_CAPTURE done: %d files" % _saved.size())
	for path: String in _saved: print("  ", path)
	quit(0)


# ------------------------------------------------------------------ rig previews

func _rig_previews() -> void:
	for path: String in FLOORS: _floors.append(load(path))
	# one canvas unit per window px (the project stretches its 1280x720 base otherwise)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = PANEL
	_stage = Stage.new()
	_stage.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	root.add_child(_stage)
	_camera = Camera2D.new()
	_stage.add_child(_camera)
	_camera.make_current()
	for form: int in _forms: await _capture_form(form)
	_stage.queue_free()
	_stage = null
	await process_frame


func _capture_form(form: int) -> void:
	var name := "drache%d" % form
	var rig: Dictionary = _library.rig(name)
	if rig.is_empty():
		printerr("HELL_RIGS_CAPTURE: no rig ", name)
		return
	_frame_camera(rig)
	var panels: Array[Image] = []
	for t: float in [0.35, 1.3, 2.45]:
		panels.append(await _panel(rig, "%s idle t=%.2f s" % [name, t], {"t": t}))
	_save("rig-%s-idle" % name, panels)
	# walking: one cycle (both hind feet) is RigPoses.DRAKE_CYCLES[form] s; at
	# 0 the far foot swings (lifted), at a quarter the stride is widest, at a
	# half the near foot swings
	panels = []
	var cycle := float(RigPoses.DRAKE_CYCLES[str(form)])
	for entry: Array in [[0.0, "ferner Fuß in der Luft"], [0.25, "weitester Schritt"], [0.5, "naher Fuß in der Luft"]]:
		panels.append(await _panel(rig, "%s Gehen, %s" % [name, entry[1]], {"t": 4.0 * cycle + float(entry[0]) * cycle, "moving": true}))
	_save("rig-%s-walk" % name, panels)
	panels = []
	for attack: Array in ATTACKS[form]:
		for phase: String in ["windup", "active"]:
			var label := "%s %s (%s, %s) %s" % [name, attack[0], attack[1], attack[2], "Ausholen" if phase == "windup" else "Zuschlag"]
			panels.append(await _panel(rig, label, {"t": 1.1, "attack": phase, "attack_kind": attack[1], "attack_p": 1.0 if phase == "windup" else 0.3}))
	_save("rig-%s-attacks" % name, panels)
	if rig.by_id.has("wing_far"):
		panels = []
		# One beat is RigPoses.DRAKE_FLAP s; the near wing (phase + 0.35 rad)
		# is highest about 0.19 of a beat in and lowest about 0.69 in; the far
		# wing beats with it (0.15 rad ahead, form 4's only lifts off the head).
		var beat := RigPoses.DRAKE_FLAP
		for entry: Array in [[0.194, "Flügel oben"], [0.694, "Flügel unten"], [0.444, "Flügel mitte, abwärts"]]:
			panels.append(await _panel(rig, "%s Flug, %s" % [name, entry[1]], {"t": 2.0 * beat + float(entry[0]) * beat, "flying": true}))
		_save("rig-%s-flight" % name, panels)
	panels = [await _panel(rig, "%s Treffer auf %s (Blitz nur auf dem Teil)" % [name, HIT_PART[form]], {"t": 0.8, "hit_flash": 0.11, "hit_part": HIT_PART[form]})]
	panels.append(await _panel(rig, "%s Treffer (ganzer Körper)" % name, {"t": 0.8, "hit_flash": 0.11}))
	panels.append(await _panel(rig, "%s Treffer-Clip u=0 (stärkster Kopfruck)" % name, {"t": 0.8, "clip": "hit", "clip_len": 0.4}))
	_save("rig-%s-hit" % name, panels)
	panels = []
	for part: Dictionary in rig.parts:
		if bool(part.unbreakable) or float(part.hp) <= 0.0: continue
		panels.append(await _sever_panel(rig, str(part.id)))
	_save("rig-%s-sever" % name, panels)


## World x of the hero's feet: HERO_GAP in front of the dragon's snout (it faces
## left, so the frame's right part, beyond the feet, reaches toward the hero).
func _hero_x(rig: Dictionary) -> float:
	return -(float(rig.size.x) - float(rig.ground.x)) * float(rig.scale) - HERO_GAP


## Camera per form: hero and dragon (with room for a raised wing and flight) fill a panel.
func _frame_camera(rig: Dictionary) -> void:
	var S := float(rig.scale)
	var left := _hero_x(rig) - 60.0
	var right := float(rig.ground.x) * S + 30.0
	# headroom: flight lifts the figure up to 16 source px and a raised wing reaches ~30 px higher
	var span := Vector2(right - left, (float(rig.size.y) + 50.0) * S + 70.0)
	var zoom := minf(float(PANEL.x) / span.x, float(PANEL.y) / span.y)
	_camera.zoom = Vector2.ONE * zoom
	# feet of the dragon at the origin; the view's bottom 50 screen px below them
	var view := Vector2(PANEL) / zoom
	_camera.position = Vector2((left + right) * 0.5, 50.0 / zoom - view.y * 0.5)


func _enemy(rig: Dictionary, extra: Dictionary) -> Dictionary:
	_uid += 1
	var enemy := {"uid": _uid, "rig": rig.name, "x": 0.0, "y": 0.0, "face": -1.0, "hits": 0, "lost": []}
	enemy.merge(extra, true)
	for key: String in ["t", "clip", "clip_len"]: enemy.erase(key)
	return enemy


## Body centre for feet at the origin (RigRenderer.draw_enemy takes the body centre).
func _centre(rig: Dictionary) -> Vector2:
	return Vector2(0.0, -(float(rig.ground.y) - float(rig.center.y)) * float(rig.scale))


func _paint_scene(canvas: CanvasItem, rig: Dictionary, enemy: Dictionary, label: String) -> void:
	var view := Vector2(PANEL) / _camera.zoom.x
	var top_left := _camera.position - view * 0.5
	var tile := 96.0
	var y := floorf(top_left.y / tile) * tile
	while y < top_left.y + view.y:
		var x := floorf(top_left.x / tile) * tile
		while x < top_left.x + view.x:
			var k := absi(int(x / tile) * 7 + int(y / tile) * 13) % _floors.size()
			canvas.draw_texture_rect(_floors[k], Rect2(x, y, tile, tile), false, FLOOR_TINT)
			x += tile
		y += tile
	# the floor line under the dragon's feet (the stance foot belongs on it)
	canvas.draw_line(Vector2(-float(rig.width) * float(rig.scale), 0.5), Vector2(float(rig.width) * float(rig.scale), 0.5), Color(0.4, 0.9, 1.0, 0.35), 2.0 / _camera.zoom.x)
	# the hero, facing the dragon, with the game's oval shadow
	var hero_size := Vector2(HERO.get_size()) * HERO_SCALE
	var hero_feet := Vector2(_hero_x(rig), 0.0)
	canvas.draw_set_transform(hero_feet + Vector2(0, 2), 0.0, Vector2(1.0, 0.32))
	canvas.draw_circle(Vector2.ZERO, hero_size.x * 0.42, Color(0, 0, 0, 0.45))
	canvas.draw_set_transform(Vector2.ZERO)
	canvas.draw_texture_rect(HERO, Rect2(hero_feet - Vector2(hero_size.x * 0.5, hero_size.y), hero_size), false)
	_renderer.draw_under(canvas)
	_renderer.draw_enemy(canvas, enemy, _centre(rig))
	_renderer.draw_over(canvas, {"enemies": [enemy]})
	var font := ThemeDB.fallback_font
	var px := 15.0 / _camera.zoom.x
	canvas.draw_rect(Rect2(top_left, Vector2(view.x, px * 1.8)), Color(0.05, 0.03, 0.04, 0.85))
	canvas.draw_string(font, top_left + Vector2(px * 0.5, px * 1.3), "[Rig-Vorschau] " + label if not label.is_empty() else "", HORIZONTAL_ALIGNMENT_LEFT, -1, int(px), Color(0.93, 0.89, 0.84))


## One posed shot: a fresh renderer and actor at actor time extra.t (and, with
## extra.clip, that clip at its start).
func _panel(rig: Dictionary, label: String, extra: Dictionary) -> Image:
	_renderer = RigRenderer.new(_library)
	var enemy := _enemy(rig, extra)
	var actor: Dictionary = _renderer._actor("e%d" % int(enemy.uid), enemy)
	actor.t = float(extra.get("t", 0.0))
	if extra.has("clip"):
		actor.clip = str(extra.clip)
		actor.ct = 0.0
		actor.clip_len = float(extra.get("clip_len", 0.4))
	return await _grab(func(canvas: CanvasItem) -> void: _paint_scene(canvas, rig, enemy, label))


## Cuts `id` (and what it takes along) off a whole figure: one draw whole, the
## cut (the renderer's debris, chips and stagger), then 0.7 s of falling debris.
func _sever_panel(rig: Dictionary, id: String) -> Image:
	_renderer = RigRenderer.new(_library)
	var enemy := _enemy(rig, {})
	var actor: Dictionary = _renderer._actor("e%d" % int(enemy.uid), enemy)
	actor.t = 1.0
	await _grab(func(canvas: CanvasItem) -> void: _paint_scene(canvas, rig, enemy, ""))
	var lost: Array = [id]
	for other: Variant in rig.by_id[id].get("also_detach", []): lost.append(str(other))
	enemy.lost = lost
	_renderer.observe({"enemies": [enemy]})
	for i in range(14): _renderer.step(0.05)
	var label := "%s nach Abtrennen: %s (%s)" % [rig.name, id, rig.by_id[id].get("label", id)]
	return await _grab(func(canvas: CanvasItem) -> void: _paint_scene(canvas, rig, enemy, label))


func _grab(paint: Callable) -> Image:
	_stage.paint = paint
	_stage.queue_redraw()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.convert(Image.FORMAT_RGBA8)
	return image


## Panels in rows of COLUMNS, 4 px apart, saved as <name>.png.
func _save(name: String, panels: Array[Image]) -> void:
	if panels.is_empty(): return
	var w := panels[0].get_width()
	var h := panels[0].get_height()
	var columns := mini(COLUMNS, panels.size())
	var rows := ceili(float(panels.size()) / float(columns))
	var sheet := Image.create(columns * w + (columns - 1) * 4, rows * h + (rows - 1) * 4, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.08, 0.06, 0.07))
	for i in range(panels.size()):
		sheet.blit_rect(panels[i], Rect2i(Vector2i.ZERO, Vector2i(w, h)), Vector2i((i % columns) * (w + 4), (i / columns) * (h + 4)))
	var path := _out.path_join(name + ".png")
	var result := sheet.save_png(path)
	print("CAPTURED %s result=%d" % [path, result])
	_saved.append(path)


# ------------------------------------------------------------------ the game

func _game_captures() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	for form: int in _forms:
		if not GAME.has(form): continue
		await _game_form(form, false)
	if 4 in _forms: await _game_form(4, true)
	_close_game()
	for path: String in [GRAPHICS_FILE, META_FILE]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _close_game() -> void:
	if _game != null:
		_game.queue_free()
		_game = null


func _wait(frames: int) -> void:
	for i in range(frames):
		if _game != null and not _game.state.is_empty():
			_game.state.inv = 5.0
			_game.state.hp = maxi(int(_game.state.hp), 3)
		_mark()
		await process_frame


func _until(check: Callable, limit := 900) -> bool:
	for i in range(limit):
		if check.call(): return true
		await _wait(1)
	print("HELL_RIGS_CAPTURE timeout")
	return false


func _boss() -> Dictionary:
	if _game == null: return {}
	for m: Dictionary in _game.mobs:
		if m.boss: return m
	return {}


## The two mouth markers on the boss: cyan where the rig has the mouth, yellow
## where hell_monsters.gd starts the breath.
func _mark() -> void:
	if _marks == null or _game == null: return
	var m := _boss()
	_marks.marks = []
	if not m.is_empty() and float(m.get("alpha", 1.0)) > 0.0:
		var mouth: Vector2 = _library.foot_offset(str(m.id), "mouth")
		var feet: Vector2 = Vector2(m.p) + Vector2(0, 4.0 - float(m.act.get("air", 0.0) if m.act != null else 0.0))
		if mouth.is_finite(): _marks.marks.append([feet + Vector2(mouth.x * float(m.face), mouth.y), Color(0.3, 1.0, 1.0, 0.9)])
		_marks.marks.append([Vector2(m.p) + Vector2(float(m.face) * float(m.r) * 0.95, -float(m.cy) * 1.35), Color(1.0, 0.9, 0.2, 0.9)])
	_marks.queue_redraw()


func _force(id: String) -> void:
	var b := _boss()
	var attacks: Array = b.st.attacks
	for k in range(attacks.size()):
		b.cds[k] = -100.0 if attacks[k].id == id else maxf(float(b.cds[k]), 6.0)


## Floor GAME[form][0] in its boss room: waits out the arrival, puts the hero
## to the boss's left (so it faces left like the rig previews) and captures.
func _game_form(form: int, hd: bool) -> void:
	_close_game()
	await process_frame
	var file := ConfigFile.new()
	file.set_value("options", "graphics", "hd" if hd else "pixel")
	file.save(GRAPHICS_FILE)
	_game = HellScene.instantiate()
	_game.start_floor = int(GAME[form][0])
	_game.start_at_boss = true
	_game.graphics_path = GRAPHICS_FILE
	_game.meta_path = META_FILE
	root.add_child(_game)
	_marks = Marks.new()
	_marks.z_index = 40
	_game.add_child(_marks)
	await _wait(3)
	if _boss().is_empty():
		printerr("HELL_RIGS_CAPTURE: no boss on floor ", GAME[form][0])
		return
	await _until(func() -> bool: return _boss().get("intro") == null, 1200)
	var name := "drache%d" % form
	await _place_hero()
	await _wait(40)
	if hd:
		await _shot("game-%s-hd" % name)
		return
	await _shot("game-%s-steht" % name)
	var shots: int = _game.eshots.size()
	_force(str(GAME[form][1]))
	await _until(func() -> bool: return _game.eshots.size() > shots, 400)
	await _wait(4)
	await _shot("game-%s-schuss" % name)
	if not str(GAME[form][2]).is_empty():
		await _until(func() -> bool: return _boss().get("act") == null, 600)
		await _place_hero()
		_force(str(GAME[form][2]))
		await _until(func() -> bool: return _boss().get("act") != null and str(_boss().act.a.id) == str(GAME[form][2]), 400)
		await _until(func() -> bool: return _boss().get("act") == null or float(_boss().act.t) > 0.9, 300)
		await _shot("game-%s-atem" % name)


## The hero 2.6 boss radii left of the boss (clamped into the room), the
## camera between them.
func _place_hero() -> void:
	var b := _boss()
	var at: Vector2 = b.p
	for k: float in [2.6, 2.2, 1.8, 3.2]:
		for dy: float in [0.0, 120.0, -120.0]:
			var p := at + Vector2(-float(b.r) * k, dy)
			if _game._room_at_world(p.x, p.y) == int(b.room) and not _game.box_blocked(_game._player_box(p.x, p.y).grow(30)):
				_game.player.x = p.x
				_game.player.y = p.y
				_game.camera.position = at.lerp(p, 0.4) - Vector2(0, float(b.cy) * 0.6)
				await _wait(2)
				return


func _shot(name: String) -> void:
	_mark()
	var blink: float = _game.state.inv
	_game.state.inv = 0.0
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var path := _out.path_join(name + ".png")
	print("CAPTURED %s result=%d" % [path, image.save_png(path)])
	_saved.append(path)
	_game.state.inv = blink
