extends SceneTree
## Captures the crypt's bloom and darkness in the story worlds
## (src/hero/story_glow.gd) from the real windowed game, each bright thing with
## the same frame once more without the bloom (darkness and lights stay):
## - the fires of the map (Hell-Dungeon orange, Frostgruft blue), the same spot
##   with the light switched off, a lava bank;
## - a hell fight (the monsters' glowing parts, the mage's spells), the monsters'
##   parts, the guardians and the soul shepherd's lantern up close;
## - enemy shots: a fire ring, a soul spiral, void bolts, breath flames, a lob and
##   a falling meteor (the crypt's bullet bloom);
## - the monsters' attacks: a meteor's impact, a lava wave, a swing, a slam line,
##   a scream, a magma puddle; a transformation; Ignaroth 4's void beams;
## - the map's magic: an awake portal, the vault, seals, rune plates, a key, a
##   gem and a heart, a gate held by a fight;
## - the hero's meteor rain and its impact (the world's own zones and blasts);
## - the Frostgruft: ice crystals charging, a frost whirl, ice slimes, a dashing
##   frost imp, ice armour, a crystal bound to its guardian, Hrimgar's icicles,
##   chill fields and an icicle's strike, Hrimgar's core in phases 2 and 3.
## Scenes with attacks are frozen (the world stands still, its picture and its
## lights are redrawn every frame), so each shot shows the moment it names.
## Usage:
##   godot --path . --windowed --resolution 1280x720 -s res://scripts/capture_story_glow.gd -- <output_dir> [scene ...]
## (scenes: hell_map hell_fight hell_beams hell_shots hell_attacks hell_magic hell_hero_meteor frost; none: all)
const FrostScene = preload("res://src/hell/frost_dungeon.tscn")
const HellScene = preload("res://src/hell/hell_dungeon.tscn")
const BossKit = preload("res://src/hell/boss_kit.gd")
const StoryGlow = preload("res://src/hero/story_glow.gd")
const SAVE := "user://capture_story_glow.cfg"
## The capture's own graphics choice (never the player's settings).
const GRAPHICS := "user://capture_story_glow_graphics.cfg"

var _out := "res://production/qa/evidence/vfx-story-glow"
var _game: Node
## True while the world stands still (freeze()).
var _frozen := false
## The scenes to capture (empty: all).
var _only: Array = []


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		_out = args[0]
		_only = args.slice(1)
	_run.call_deferred()


## Lets the world run (or, frozen, redraws its still picture); the hero stays
## unhurt (and its blink is off for the shot).
func _wait(frames: int) -> void:
	for i in range(frames):
		if _game != null and not _game.state.is_empty():
			_game.state.inv = 99.0
			_game.state.hp = maxi(int(_game.state.hp), 6)
			_game.state.banner.t = 99.0
			_game.state.toasts = []
		if _frozen:
			_still()
		await process_frame


## The world stands still: no update, its picture and lights redrawn each frame.
func _freeze() -> void:
	_frozen = true
	_game.set_process(false)


func _thaw() -> void:
	_frozen = false
	_game.set_process(true)


func _still() -> void:
	_game.actors.queue_redraw()
	_game.glow.queue_redraw()
	_game.hud.queue_redraw()
	_game.story_glow.frame()


## Saves the frame; with `focus` (a world point) also a 2x close-up around it.
func _shot(name: String, focus := Vector2.INF) -> void:
	if _game != null:
		_game.state.inv = 0.0
	for i in range(2):
		if _frozen:
			_still()
		await process_frame
	var image := root.get_texture().get_image()
	var path := _out.path_join(name + ".png")
	print("CAPTURED %s result=%d" % [path, image.save_png(path)])
	if focus.is_finite() and _game != null:
		var screen: Vector2 = _game.get_viewport().get_canvas_transform() * focus
		var box := Rect2i(Vector2i(clampi(int(screen.x) - 240, 0, image.get_width() - 480), clampi(int(screen.y) - 150, 0, image.get_height() - 270)), Vector2i(480, 270))
		var crop := image.get_region(box)
		crop.resize(960, 540, Image.INTERPOLATE_NEAREST)
		var close := _out.path_join(name + "-nah.png")
		print("CAPTURED %s result=%d" % [close, crop.save_png(close)])


## The frame with the bloom and the same frame without it (darkness and lights
## stay); with `focus` also what the bloom adds to the close-up, 4x brighter.
func _pair(name: String, focus := Vector2.INF) -> void:
	await _shot(name, focus)
	await _shot_without_bloom(name + "-ohne-bloom", focus)
	if focus.is_finite():
		_difference(name)


## <name>-bloom-anteil.png: the close-up with the bloom minus the one without, 4x.
func _difference(name: String) -> void:
	var a := Image.load_from_file(_out.path_join(name + "-nah.png"))
	var b := Image.load_from_file(_out.path_join(name + "-ohne-bloom-nah.png"))
	if a == null or b == null or a.get_size() != b.get_size():
		return
	a.convert(Image.FORMAT_RGB8)
	b.convert(Image.FORMAT_RGB8)
	var out := Image.create_empty(a.get_width(), a.get_height(), false, Image.FORMAT_RGB8)
	for y in range(0, a.get_height(), 2):
		for x in range(0, a.get_width(), 2):
			var d := a.get_pixel(x, y) - b.get_pixel(x, y)
			out.fill_rect(Rect2i(x, y, 2, 2), Color(absf(d.r) * 4.0, absf(d.g) * 4.0, absf(d.b) * 4.0))
	var path := _out.path_join(name + "-bloom-anteil.png")
	print("CAPTURED %s result=%d" % [path, out.save_png(path)])


## The same frame once more without the bloom (darkness and lights stay): the comparison.
func _shot_without_bloom(name: String, focus := Vector2.INF) -> void:
	var was := _frozen
	_game.story_glow.glow.enabled = false
	_freeze()
	await _shot(name, focus)
	_game.story_glow.glow.enabled = true
	if not was:
		_thaw()


func _open(scene: PackedScene, floor_n: int, class_id := "mage", at_boss := false) -> void:
	_game = scene.instantiate()
	_game.class_id = class_id
	_game.start_floor = floor_n
	_game.start_at_boss = at_boss
	_game.meta_path = SAVE
	_game.graphics_path = GRAPHICS
	root.add_child(_game)
	await _wait(5)
	_game.state.offer = []


func _close() -> void:
	_frozen = false
	_game.queue_free()
	_game = null
	await process_frame


## Puts the hero on the floor cell nearest `p` (inside a room) and the camera on it.
func _place(p: Vector2) -> void:
	var best := Vector2i(-1, -1)
	var c := float(_game.C)
	for y in range(int(_game.W.rows)):
		for x in range(int(_game.W.cols)):
			if int(_game.W.grid[y * int(_game.W.cols) + x]) != 1 or _game._room_at_world((x + 0.5) * c, (y + 0.8) * c) < 0:
				continue
			if best.x < 0 or Vector2((x + 0.5) * c, (y + 0.8) * c).distance_squared_to(p) < Vector2((best.x + 0.5) * c, (best.y + 0.8) * c).distance_squared_to(p):
				best = Vector2i(x, y)
	_game.player.x = (best.x + 0.5) * c
	_game.player.y = (best.y + 0.8) * c
	_game.state.room = _game._room_at_world(_game.player.x, _game.player.y - 12.0)
	_game.camera.position = Vector2(_game.player.x, _game.player.y - 40)


## A light of the floor of radius `r` (and colour `c` when given).
func _light(r: float, c := "") -> Dictionary:
	for li: Dictionary in _game.W.lights:
		if is_equal_approx(float(li.r), r) and (c == "" or str(li.c) == c):
			return li
	return _game.W.lights[0]


## A floor point of the hero's room `reach` px from `me` with open floor above it
## (for a tall monster), searched around the circle from the right.
func _open_spot(me: Vector2, reach: float) -> Vector2:
	for k in range(16):
		var p := me + Vector2.from_angle(k * TAU / 16.0) * reach
		var c := float(_game.C)
		if _game._room_at_world(p.x, p.y) == _game.state.room and _game._cell(int(p.x / c), int(p.y / c)) == 1 \
				and _game._cell(int(p.x / c), int((p.y - 200.0) / c)) == 1:
			return p
	return me + Vector2(reach, 0)


func _fight_room(min_w := 16) -> Dictionary:
	for r: Dictionary in _game.W.rooms:
		if r.type == "combat" and r.bw >= min_w:
			_place(Vector2(r.bx + r.bw / 2.0, r.by + r.bh / 2.0) * float(_game.C))
			_game.state.room = r.index
			_game._start_fight(r)
			return r
	return {}


## A lava cell with floor right below it.
func _bank() -> Vector2:
	for y in range(int(_game.W.rows) - 2):
		for x in range(int(_game.W.cols)):
			if _game._cell(x, y) == 2 and _game._cell(x, y + 1) == 1 and _game._cell(x, y + 2) == 1 and _game._room_at_world((x + 0.5) * _game.C, (y + 1.8) * _game.C) >= 0:
				return Vector2((x + 0.5) * _game.C, (y + 1.8) * _game.C)
	return Vector2.INF


func _fire_at_nearest(frames: int) -> void:
	for i in range(frames):
		var me := Vector2(_game.player.x, _game.player.y - 40)
		var best: Dictionary = {}
		for m: Dictionary in _game.mobs:
			if float(m.get("spawn", 0.0)) <= 0.0 and float(m.hp) > 0.0 and (best.is_empty() or (m.p as Vector2).distance_to(me) < (best.p as Vector2).distance_to(me)):
				best = m
		# at the weapon's own rate (_fire waits for its cooldown)
		if not best.is_empty():
			_game._fire((((best.p as Vector2) - Vector2(0, best.cy)) - me).normalized())
		await _wait(1)


## The first entity of `type` on the floor ({} when none).
func _ent(type: String) -> Dictionary:
	for e: Dictionary in _game.W.ents:
		if str(e.type) == type:
			return e
	return {}


## A hell monster standing still in the hero's room.
func _monster(id: String, at: Vector2, boss := false) -> Dictionary:
	var m: Dictionary = _game.monsters.spawn(_game.state.room, at, id, boss)
	m.spawn = 0.0
	m.cds = m.cds.map(func(_c: Variant) -> float: return 99.0)
	return m


## A Frostgruft enemy in the hero's room.
func _frost_mob(kind: String, at: Vector2) -> Dictionary:
	_game._spawn_mob(_game.state.room, at, kind)
	var m: Dictionary = _game.mobs[_game.mobs.size() - 1]
	m.spawn = 0.0
	return m


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	for scene: Array in [["hell_map", _hell_map], ["hell_fight", _hell_fight], ["hell_beams", _hell_beams], ["hell_shots", _hell_shots], ["hell_attacks", _hell_attacks],
			["hell_magic", _hell_magic], ["hell_hero_meteor", _hell_hero_meteor], ["frost", _frost]]:
		if _only.is_empty() or _only.has(scene[0]):
			await (scene[1] as Callable).call()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GRAPHICS))
	quit()


func _hell_map() -> void:
	# the hell's fires: standing braziers, wall torches, their flicker and colour
	await _open(HellScene, 1)
	var li := _light(300.0, "255,140,60")
	_place(Vector2(li.x, li.y + 260.0))
	await _wait(60)
	await _pair("hell-1-feuer", Vector2(li.x, li.y))
	# the same spot without light: no darkness and no bloom (the switch L)
	_game.state.light = false
	await _wait(3)
	await _shot("hell-1-feuer-licht-aus")
	_game.state.light = true
	await _close()
	# a lava bank: its glow and light where the river meets the floor
	for n in range(1, 11):
		await _open(HellScene, n)
		var bank := _bank()
		if bank.is_finite():
			_place(bank + Vector2(0, 120))
			await _wait(60)
			await _shot("hell-lava-ufer", bank)
			await _close()
			break
		await _close()


func _hell_fight() -> void:
	# a hell fight on floor 5: glowing eyes and flames, the mage's spells
	await _open(HellScene, 5)
	_fight_room()
	await _wait(90)
	await _fire_at_nearest(70)
	await _shot("hell-kampf-etage5", Vector2(_game.player.x, _game.player.y - 40))
	await _close()
	# the hell monsters' glowing parts: eyes, flames, lava and soul fire
	await _open(HellScene, 5)
	_fight_room()
	await _wait(5)
	_game.mobs.clear()
	var centre := Vector2(_game.player.x, _game.player.y)
	var ids := ["glutschaedel", "hoellenhund", "brandskelett", "blutfledermaus", "aschenpriester", "peingeist", "kettenschinder", "glutimp"]
	for k in range(ids.size()):
		var m: Dictionary = _game.monsters.spawn(_game.state.room, centre + Vector2.from_angle(k * TAU / ids.size()) * (250.0 + 40.0 * (k % 2)), ids[k])
		m.spawn = 0.0
		m.cds = m.cds.map(func(_c: Variant) -> float: return 2.0)
	await _wait(25)
	await _pair("hell-monster-glut", centre + Vector2(0, -60))
	await _close()
	# the guardians of floors 2, 5 and 8: the three hounds' manes, the lantern, the void fire
	await _open(HellScene, 5)
	_fight_room()
	await _wait(5)
	_game.mobs.clear()
	centre = Vector2(_game.player.x, _game.player.y)
	for spec: Array in [["dreischlund", Vector2(-330, -40)], ["klagender_hueter", Vector2(330, -40)]]:
		_monster(spec[0], centre + spec[1], true)
	var shepherd := _monster("seelenhirte", centre + Vector2(0, -150), true)
	await _wait(20)
	await _shot("hell-waechter-glut", centre + Vector2(0, -120))
	# the soul shepherd's lantern up close (where the world drew it)
	var drawn: Dictionary = _game.story_glow.drawn_of(shepherd)
	var lantern: Vector2 = StoryGlow.anchor(drawn, [23, 10.5]) if not drawn.is_empty() else (shepherd.p as Vector2) - Vector2(0, 150)
	await _pair("hell-seelenhirte-laterne", lantern)
	await _close()


## Ignaroth 4 burns his void beams (the world stands still mid-beam).
func _hell_beams() -> void:
	await _open(HellScene, 5)
	_fight_room()
	await _wait(5)
	_game.mobs.clear()
	var me := Vector2(_game.player.x, _game.player.y)
	var drake: Dictionary = _game.monsters.spawn(_game.state.room, _open_spot(me, 360.0), "drache4", true)
	drake.spawn = 0.0
	for a: Dictionary in drake.st.attacks:
		if str(a.kind) == "beam":
			drake.act = {"a": a, "kind": "beam", "t": 0.8, "warn": false, "dir": Vector2.LEFT, "n": 0, "anim": "cast", "v": Vector2.ZERO,
				"beams": [PI + 0.2, PI + 0.2 + TAU / 3.0, PI + 0.2 + TAU * 2.0 / 3.0]}
			drake.cds = drake.cds.map(func(_c: Variant) -> float: return 99.0)
	# where the dragon's head is free of the walls, so its beams burn far across the room
	var best := -1.0
	var spot: Vector2 = drake.p
	for k in range(24):
		drake.p = me + Vector2.from_angle(k * TAU / 24.0) * (220.0 + 60.0 * (k % 4))
		var reach := 0.0
		for seg: Array in _game.story_glow.beam_segments(drake):
			reach += (seg[0] as Vector2).distance_to(seg[1])
		if _game._room_at_world(drake.p.x, drake.p.y) == _game.state.room and reach > best:
			best = reach
			spot = drake.p
	drake.p = spot
	await _wait(2)
	_freeze()
	await _wait(4)
	await _pair("hell-ignaroth4-strahlen", (drake.p as Vector2) - Vector2(0, drake.cy))
	await _close()


## GLOW-4: enemy shots, a lob and a falling meteor bloom like the crypt's bullets.
func _hell_shots() -> void:
	await _open(HellScene, 5)
	_fight_room()
	await _wait(5)
	_game.mobs.clear()
	_freeze()
	var me := Vector2(_game.player.x, _game.player.y)
	var ring := me + Vector2(-330, -120)
	for k in range(14):
		_game.eshots.append({"p": ring + Vector2.from_angle(k * TAU / 14.0) * 110.0, "v": Vector2.from_angle(k * TAU / 14.0) * 280.0, "t": 9.0, "c": "fire"})
	var spiral := me + Vector2(330, -110)
	for k in range(12):
		var a := k * 0.55
		_game.eshots.append({"p": spiral + Vector2.from_angle(a) * (30.0 + k * 9.0), "v": Vector2.from_angle(a) * 200.0, "t": 9.0, "c": "soul"})
	for k in range(3):
		_game.eshots.append({"p": me + Vector2(-80 + k * 80, -300), "v": Vector2(0, 260), "t": 9.0, "c": "void"})
		_game.eshots.append({"p": me + Vector2(150 + k * 40, 130 + k * 12), "v": Vector2(-260, 0), "t": 9.0, "c": "fire", "small": true})
	_game.monsters.lobs.append({"from": me + Vector2(-500, 150), "to": me + Vector2(-150, 200), "t": 0.4, "T": 0.8, "r": 70.0, "dmg": 0, "m": {}, "c": "lava", "done": false})
	_game.monsters.zones.append({"kind": "meteor", "p": me + Vector2(150, 230), "r": 80.0, "T": 1.35, "t": 0.6, "tele": 1.0, "dmg": 0, "done": true, "m": {}})
	await _wait(4)
	await _pair("hell-gegner-schuesse", ring)
	await _shot_without_bloom("hell-gegner-schuesse-spirale-ohne-bloom", spiral)
	await _shot("hell-gegner-schuesse-spirale", spiral)
	await _close()


## GLOW-5: the monsters' attacks bloom (impact, wave, swing, slam, scream, puddle)
## and a transformation glows.
func _hell_attacks() -> void:
	await _open(HellScene, 5)
	_fight_room()
	await _wait(5)
	_game.mobs.clear()
	_freeze()
	var me := Vector2(_game.player.x, _game.player.y)
	var zones: Array = _game.monsters.zones
	zones.append({"kind": "meteor", "p": me + Vector2(-380, -150), "r": 90.0, "T": 1.35, "t": 1.05, "tele": 1.0, "dmg": 0, "done": true, "m": {}})
	zones.append({"kind": "wave", "c": "lava", "p": me + Vector2(0, -200), "r": 260.0, "T": 1.2, "t": 0.45, "tele": 0.0, "dmg": 0, "done": true, "m": {}})
	zones.append({"kind": "arc", "p": me + Vector2(330, -170), "r": 150.0, "ang": PI * 0.75, "arc": 1.6, "T": 0.25, "t": 0.04, "tele": 0.0, "dmg": 0, "done": true, "m": {}})
	zones.append({"kind": "line", "p": me + Vector2(-480, 160), "ang": 0.0, "len": 330.0, "w": 70.0, "T": 0.8, "t": 0.5, "tele": 0.45, "dmg": 0, "done": true, "m": {}})
	zones.append({"kind": "cone", "p": me + Vector2(420, 120), "ang": PI * 0.85, "r": 260.0, "arc": 0.9, "T": 0.9, "t": 0.62, "tele": 0.55, "dmg": 0, "slow": 0.0, "done": true, "m": {}})
	zones.append({"kind": "puddle", "p": me + Vector2(140, 210), "r": 60.0, "T": 2.6, "t": 0.6, "tele": 0.0, "dmg": 0, "done": true, "m": {}})
	await _wait(4)
	await _pair("hell-angriffe", me + Vector2(0, -60))
	await _shot("hell-angriffe-einschlag-welle", me + Vector2(-200, -170))
	zones.clear()
	# a dragon lord transforming
	var lord := _monster("drache1", _open_spot(me, 300.0), true)
	lord.trans = {"glow": 0.9, "grow": 1.0, "swapped": false}
	await _wait(4)
	await _pair("hell-verwandlung", (lord.p as Vector2) - Vector2(0, lord.cy))
	await _close()


## GLOW-9: the map's magic (portal, vault, seals, plates, loot) and a gate held by a fight.
func _hell_magic() -> void:
	await _open(HellScene, 5)
	var portal := _ent("portal")
	if not portal.is_empty():
		portal.active = true
		_place(Vector2(portal.x, portal.y + 220.0))
		await _wait(30)
		await _pair("hell-portal", Vector2(portal.x, portal.y - 60.0))
	var vault := _ent("vault")
	if not vault.is_empty():
		_place(Vector2(vault.x, vault.y + 230.0))
		await _wait(30)
		await _pair("hell-tresor", Vector2(vault.x, vault.y - 80.0))
	var seal := _ent("seal")
	if not seal.is_empty():
		_place(Vector2(seal.x, seal.y + 220.0))
		await _wait(30)
		await _pair("hell-siegel", Vector2(seal.x, seal.y - 50.0))
	var plate := _ent("plate")
	if not plate.is_empty():
		for e: Dictionary in _game.W.ents:
			if str(e.type) == "plate" and e.get("group") == plate.get("group"):
				e.on = true
		_place(Vector2(plate.x, plate.y + 160.0))
		await _wait(30)
		await _pair("hell-runenplatten", Vector2(plate.x, plate.y))
	# loot: the floor's key with a gem and a heart beside it
	var key := _ent("key")
	if not key.is_empty():
		var gem := _ent("gem")
		var heart := _ent("heart")
		if not gem.is_empty():
			gem.x = float(key.x) - 110.0
			gem.y = float(key.y)
		if not heart.is_empty():
			heart.x = float(key.x) + 110.0
			heart.y = float(key.y)
		_place(Vector2(key.x, key.y + 200.0))
		await _wait(30)
		await _pair("hell-beute", Vector2(key.x, key.y - 30.0))
	await _close()
	# a gate held by a fight pulses
	await _open(HellScene, 5)
	var room := _fight_room()
	await _wait(10)
	for d: Dictionary in _game.W.doors:
		if str(d.kind) != "secret" and (int(d.a) == int(room.index) or int(d.b) == int(room.index)) and _game._door_closed(d):
			# the world stands still with the gate in the middle of the screen
			_freeze()
			_game.mobs.clear()
			_place(Vector2(d.cx, d.cy) + (Vector2(room.bx + room.bw / 2.0, room.by + room.bh / 2.0) * float(_game.C) - Vector2(d.cx, d.cy)).normalized() * 200.0)
			_game.camera.position = Vector2(d.cx, d.cy)
			await _wait(4)
			await _pair("hell-kampftor", Vector2(d.cx, d.cy))
			break
	await _close()


## GLOW-2: the hero's meteor rain lights the dark where it will strike; the impact flares.
func _hell_hero_meteor() -> void:
	await _open(HellScene, 5)
	_fight_room()
	await _wait(5)
	_game.mobs.clear()
	_freeze()
	var me := Vector2(_game.player.x, _game.player.y)
	# before: the same dark spot without the strikes (their light is the difference)
	await _wait(4)
	await _shot("hell-helden-meteor-vorher", me + Vector2(0, -60))
	for k in range(4):
		_game.zones.append({"kind": "meteor", "p": me + Vector2(-360 + k * 240, -170 + (k % 2) * 60), "r": 150.0, "t": 0.3 + k * 0.1, "max": 1.0})
	_game.fx.append({"kind": "quake", "p": me + Vector2(60, 200), "r": 150.0, "t": 0.35, "max": 0.5})
	await _wait(4)
	await _pair("hell-helden-meteor", me + Vector2(0, -60))
	await _close()


func _frost() -> void:
	# the Frostgruft's fires burn blue
	await _open(FrostScene, 1)
	var li := _light(300.0)
	_place(Vector2(li.x, li.y + 260.0))
	await _wait(60)
	await _pair("frost-1-feuer", Vector2(li.x, li.y))
	await _close()
	# ice crystals charge before they fire; a fight around them
	await _open(FrostScene, 3)
	_fight_room()
	await _wait(10)
	var me := Vector2(_game.player.x, _game.player.y)
	for off: Vector2 in [Vector2(-260, -60), Vector2(260, -40), Vector2(0, -230)]:
		var crystal := _frost_mob("ice_crystal", me + off)
		crystal.shoot = 0.35 + off.x / 2000.0
	await _wait(14)
	await _pair("frost-eiskristall", me + Vector2(0, -120))
	await _close()
	# GLOW-7: a frost whirl, ice slimes, a dashing frost imp, ice armour, a crystal bound to its guardian
	await _open(FrostScene, 3)
	_fight_room()
	await _wait(10)
	_game.mobs.clear()
	_freeze()
	me = Vector2(_game.player.x, _game.player.y)
	_game.camera.position = me + Vector2(0, -120)
	_frost_mob("frost_whirl", me + Vector2(-250, -110))
	_frost_mob("ice_slime", me + Vector2(-90, -230))
	_frost_mob("ice_slime_s", me + Vector2(-10, -170))
	var imp := _frost_mob("frost_imp", me + Vector2(90, -250))
	imp.dash = 0.3
	imp.dash_dir = Vector2(1, 0.3).normalized()
	var knight := _frost_mob("ice_knight", me + Vector2(250, -60))
	knight.armor_t = 3.0
	var bound := _frost_mob("ice_crystal", me + Vector2(150, -10))
	bound.shoot = 3.0
	bound.guard_of = knight
	await _wait(4)
	await _pair("frost-gegner-glut", me + Vector2(0, -130))
	await _shot("frost-wirbel", me + Vector2(-250, -140))
	await _close()
	# Hrimgar's glacier core (phases 2 and 3), his icicles, chill fields and an icicle's strike
	await _open(FrostScene, 10, "mage", true)
	await _wait(30)
	for m: Dictionary in _game.mobs:
		if m.has("kit"):
			BossKit.next_phase(_game, m)
			m.inv = 0.0
	await _wait(60)
	var boss: Dictionary = {}
	for m: Dictionary in _game.mobs:
		if m.has("kit"): boss = m
	if boss.is_empty():
		await _close()
		return
	# Hrimgar in the middle of the hall beside the hero
	var hall: Dictionary = _game.W.rooms[boss.room]
	_place(Vector2(hall.bx + hall.bw / 2.0, hall.by + hall.bh * 0.7) * float(_game.C))
	boss.p = Vector2(_game.player.x + 330.0, _game.player.y + 40.0)
	boss.atk_t = 9.0
	await _wait(20)
	_freeze()
	_game.eshots.clear()
	_game.zones.clear()
	await _wait(3)
	await _pair("frost-hrimgar-kern", (boss.p as Vector2) - Vector2(0, boss.cy))
	me = Vector2(_game.player.x, _game.player.y)
	await _shot("frost-hrimgar-eiszapfen-vorher", me + Vector2(-200, -60))
	for off: Vector2 in [Vector2(-300, -150), Vector2(-120, -230), Vector2(60, -200)]:
		_game.zones.append({"kind": "icicle", "p": me + off, "r": 70.0, "t": 0.45, "max": 1.0})
	for off: Vector2 in [Vector2(-430, 120), Vector2(-150, 180)]:
		_game.zones.append({"kind": "chill", "p": me + off, "r": 110.0, "t": 3.0, "max": 3.0})
	# one icicle strikes: it leaves the world and flares
	var strike := {"kind": "icicle", "p": me + Vector2(-330, 30), "r": 70.0, "t": 0.02, "max": 1.0}
	_game.zones.append(strike)
	_still()
	await process_frame
	_game.zones.erase(strike)
	_game.state.t = float(_game.state.t) + 0.06
	await _wait(3)
	await _pair("frost-hrimgar-eiszapfen", me + Vector2(-200, -60))
	_game.zones.clear()
	_thaw()
	BossKit.next_phase(_game, boss)
	boss.inv = 0.0
	await _wait(40)
	boss.p = Vector2(_game.player.x + 330.0, _game.player.y + 40.0)
	boss.atk_t = 9.0
	_freeze()
	_game.eshots.clear()
	_game.zones.clear()
	await _wait(3)
	await _pair("frost-hrimgar-kern-phase3", (boss.p as Vector2) - Vector2(0, boss.cy))
	await _close()
