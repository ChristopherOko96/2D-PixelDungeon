extends Node2D
## Hell-Dungeon mode (single player): plays the ten baked hell floors from
## assets/data/hell_floors.json. Combat rooms lock until every enemy is down,
## colour keys open their own gates, spread fire braziers open the vault,
## sequence plates conjure a reward chest, a skull heap shot three times opens
## a secret corridor, demon seals bless the hero or release demons, pits throw
## the hero back to the start, the floor-9 boss grants the clone skill (Q), and
## the portal leads one floor deeper.
## Enemies and hero are placeholders; values come from hell_balance.json.

const FloorData = preload("res://src/hell/hell_floor_data.gd")
const Walls = preload("res://src/hell/hell_walls.gd")
const Rules = preload("res://src/hell/hell_rules.gd")
const DARKNESS_SHADER := preload("res://assets/shaders/canvas_vfx_darkness.gdshader")
const FONT := preload("res://assets/fonts/pixel_operator8.ttf")
const BALANCE_PATH := "res://assets/data/hell_balance.json"
const SPRITES := "res://assets/sprites/hell/"
const HERO := "res://assets/sprites/0x72/knight_m_%s_anim_f%d.png"
const MENU_SCENE := "res://src/main.tscn"
const C := 96.0
const CHUNK := Vector2i(14, 11)
const KEY_TINT := {"A": Color(1, 1, 1), "B": Color(1.55, 1.5, 1.4), "C": Color(0.75, 0.5, 1.7)}
const KEY_COLOR := {"A": Color("#ff8a3c"), "B": Color("#e8dccb"), "C": Color("#b07cff")}
const KEY_NAME := {"A": "Glutschlüssel", "B": "Knochenschlüssel", "C": "Dämonenschlüssel"}
const KEY_HINT := {"A": "fällt in einem Seitenraum vor dem Tor.", "B": "liegt auf einem Altar oder fällt in einem Seitenraum.", "C": "fällt in einem Kampfraum nahe dem Bosstor."}
const INK := Color("#f1e4d8")
const EMBER := Color("#ff6b2c")
const GOLD := Color("#ffd2a8")

## Floor to open first; set before the node enters the tree (debug starts).
@export var start_floor := 1

var balance: Dictionary = {}
var floors_raw: Array = []
var tex: Dictionary = {}
var hero_frames: Dictionary = {}
var W: Dictionary = {}
var walls: Dictionary = {}
var state: Dictionary = {}
var player: Dictionary = {}
var mobs: Array = []
var shots: Array = []
var eshots: Array = []
var embers: Array = []
var breakables: Array = []
var pits: Array = []
var clone: Dictionary = {}
var solid_grid: Dictionary = {}
var door_at: Dictionary = {}
var minimap: Array = []
var camera: Camera2D
var actors: Layer
var dark: Layer
var hud: Hud
var _chunk_nodes: Array = []
var _dark_material: ShaderMaterial
var _vignette: GradientTexture2D


## One drawing layer of the world; the game draws into it by kind.
class Layer extends Node2D:
	var game: Node
	var kind := ""
	var area := Rect2()
	func _draw() -> void:
		game.draw_layer(self)


## Screen-space HUD: hearts, keys, banners, prompts, minimap and big map.
class Hud extends Control:
	var game: Node
	func _draw() -> void:
		game.draw_hud(self)


func _ready() -> void:
	balance = JSON.parse_string(FileAccess.get_file_as_string(BALANCE_PATH))
	floors_raw = FloorData.load_all()
	var names: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SPRITES + "manifest.json"))
	for n: String in names:
		tex[n] = load(SPRITES + n + ".png")
	for kind in ["idle", "run"]:
		var frames: Array = []
		for f in range(4):
			frames.append(load(HERO % [kind, f]))
		hero_frames[kind] = frames
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	camera = Camera2D.new()
	camera.zoom = Vector2.ONE * float(balance.view.base_width) / float(balance.view.width)
	add_child(camera)
	camera.make_current()
	actors = _layer("actors", 10)
	dark = _layer("dark", 30)
	_dark_material = ShaderMaterial.new()
	_dark_material.shader = DARKNESS_SHADER
	dark.material = _dark_material
	# soft red rim for deeper floors: clear centre, opaque white edge, tinted when drawn
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0))
	ramp.set_color(1, Color(1, 1, 1, 1))
	ramp.add_point(0.55, Color(1, 1, 1, 0))
	_vignette = GradientTexture2D.new()
	_vignette.gradient = ramp
	_vignette.fill = GradientTexture2D.FILL_RADIAL
	_vignette.fill_from = Vector2(0.5, 0.5)
	_vignette.fill_to = Vector2(1.05, 1.05)
	_vignette.width = 256
	_vignette.height = 144
	var ui := CanvasLayer.new()
	add_child(ui)
	hud = Hud.new()
	hud.game = self
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(hud)
	load_floor(clampi(start_floor, 1, floors_raw.size()), false)


func _layer(kind: String, z: int, area := Rect2()) -> Layer:
	var l := Layer.new()
	l.game = self
	l.kind = kind
	l.area = area
	l.z_index = z
	add_child(l)
	return l


# ---------- floors ----------

## Builds floor n (1-10). With carry the hero keeps hearts, rune stones, seal
## blessings and the paused clone skill.
func load_floor(n: int, carry: bool) -> void:
	W = FloorData.prepare(floors_raw[n - 1])
	walls = Walls.build(W.grid, W.cols, W.rows, C)
	_index_solids()
	minimap = []
	for r: Dictionary in W.rooms:
		minimap.append(_minimap_shape(r))
	for node: Node in _chunk_nodes:
		node.queue_free()
	_chunk_nodes = []
	for cy in range(0, W.rows, CHUNK.y):
		for cx in range(0, W.cols, CHUNK.x):
			var area := Rect2(cx * C, cy * C, CHUNK.x * C, CHUNK.y * C)
			_chunk_nodes.append(_layer("back", 0, area))
			_chunk_nodes.append(_layer("front", 20, area))
	var start := _room_of_type("start")
	var keep := {"hp": int(balance.player.hp), "max_hp": int(balance.player.hp), "gems": 0, "dmg": 1.0,
		"rate": float(balance.shot.cooldown), "speed_mul": 1.0, "range": float(balance.shot.life), "buffs": [],
		"skill": {"owned": false, "active": false, "left": float(balance.clone.duration)}}
	if carry and not state.is_empty():
		keep = {"hp": state.hp, "max_hp": state.max_hp, "gems": state.gems, "dmg": state.dmg, "rate": state.rate,
			"speed_mul": state.speed_mul, "range": state.range, "buffs": state.buffs, "skill": state.skill}
		keep.skill.active = false
	state = {"floor": n, "keys": {"A": false, "B": false, "C": false}, "used": {"A": false, "B": false, "C": false},
		"visited": {start.index: true}, "room": start.index, "banner": {"text": W.title, "sub": "Etage %d · %s" % [n, W.circle], "t": 0.0},
		"toasts": [], "inv": 0.0, "dead": 0.0, "map": false, "light": state.get("light", true), "t": 0.0, "won": false, "won_t": 0.0,
		"cool": 0.0, "flash": 0.0, "boss_dead": false}
	state.merge(keep)
	mobs = []
	shots = []
	eshots = []
	embers = []
	clone = {}
	breakables = W.ents.filter(func(e: Dictionary) -> bool: return e.type == "seal" or e.type == "skullheap")
	pits = W.ents.filter(func(e: Dictionary) -> bool: return e.type == "pit")
	for e: Dictionary in breakables:
		e.max_hp = int(e.hp)
	_respawn()
	camera.position = Vector2(player.x, player.y)


func _room_of_type(kind: String) -> Dictionary:
	for r: Dictionary in W.rooms:
		if r.type == kind:
			return r
	return W.rooms[0]


func _respawn() -> void:
	var s := _room_of_type("start")
	var spawn: Array = s.spawn if s.spawn != null else [s.bw / 2.0, s.bh / 2.0]
	player = {"x": (s.bx + float(spawn[0])) * C, "y": (s.by + float(spawn[1])) * C, "face": 1.0, "anim": 0.0, "moving": false}


func _index_solids() -> void:
	solid_grid = {}
	for p: Dictionary in W.props:
		if p.solid != null:
			_add_solid(Rect2(p.solid[0], p.solid[1], p.solid[2] - p.solid[0], p.solid[3] - p.solid[1]))
	for e: Dictionary in W.ents:
		match e.type:
			"chest": _add_solid(Rect2(e.x - 40, e.y - 32, 80, 32))
			"vault": _add_solid(Rect2(e.x - 70, e.y - 50, 140, 50))
			"portal": _add_solid(Rect2(e.x - 72, e.y - 40, 144, 40))
			"brazier": _add_solid(Rect2(e.x - 28, e.y - 30, 56, 30))
	door_at = {}
	for d: Dictionary in W.doors:
		for c: Vector2i in d.cells:
			door_at[c.y * W.cols + c.x] = d.index


func _add_solid(r: Rect2) -> void:
	for cy in range(int(floor(r.position.y / C)), int(floor(r.end.y / C)) + 1):
		for cx in range(int(floor(r.position.x / C)), int(floor(r.end.x / C)) + 1):
			var k: int = cy * W.cols + cx
			if not solid_grid.has(k):
				solid_grid[k] = []
			solid_grid[k].append(r)


func _minimap_shape(r: Dictionary) -> Dictionary:
	# fill as row runs (few rects per room), outline as cell edges for one multiline call
	var rects: Array[Rect2] = []
	var edges := PackedVector2Array()
	var cols: int = W.cols
	var run := Rect2()
	for c: Vector2i in r.cells:
		if run.size.x > 0.0 and int(run.position.y) == c.y and int(run.end.x) == c.x:
			run.size.x += 1.0
		else:
			if run.size.x > 0.0:
				rects.append(run)
			run = Rect2(c.x, c.y, 1, 1)
	if run.size.x > 0.0:
		rects.append(run)
	for c: Vector2i in r.cells:
		for side: Vector2i in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
			var n := c + side
			var outside: bool = n.x < 0 or n.y < 0 or n.x >= cols or n.y >= W.rows or W.room_at[n.y * cols + n.x] != r.index
			if not outside:
				continue
			var a := Vector2(c.x + (1 if side.x > 0 else 0), c.y + (1 if side.y > 0 else 0))
			var b := a + (Vector2(1, 0) if side.y != 0 else Vector2(0, 1))
			edges.append(a)
			edges.append(b)
	return {"rects": rects, "edges": edges}


# ---------- queries ----------

func _cell(x: int, y: int) -> int:
	if x < 0 or y < 0 or x >= W.cols or y >= W.rows:
		return 0
	return W.grid[y * W.cols + x]


func _walkable(t: int) -> bool:
	return t == 1 or t == 2 or t == 3


func _door_closed(d: Dictionary) -> bool:
	return Rules.door_closed(d, W.rooms, W.groups, state.boss_dead)


func _cell_blocked(cx: int, cy: int, avoid_lava: bool) -> bool:
	var t := _cell(cx, cy)
	if not _walkable(t) or (avoid_lava and t == 2):
		return true
	var k := cy * int(W.cols) + cx
	return door_at.has(k) and _door_closed(W.doors[door_at[k]])


## True when an axis-aligned box (world pixels) touches a wall, closed gate or solid prop.
func box_blocked(box: Rect2, avoid_lava := false) -> bool:
	for cy in range(int(floor(box.position.y / C)), int(floor((box.end.y - 1.0) / C)) + 1):
		for cx in range(int(floor(box.position.x / C)), int(floor((box.end.x - 1.0) / C)) + 1):
			if _cell_blocked(cx, cy, avoid_lava):
				return true
			for s: Rect2 in solid_grid.get(cy * int(W.cols) + cx, []):
				if s.intersects(box):
					return true
	for e: Dictionary in breakables:
		if not e.get("broken", false) and _breakable_box(e).intersects(box):
			return true
	return false


func _breakable_box(e: Dictionary) -> Rect2:
	var hw := 42.0 if e.type == "seal" else 48.0
	return Rect2(e.x - hw, e.y - 40.0, hw * 2.0, 40.0)


func _player_box(x: float, y: float) -> Rect2:
	var hw := float(balance.player.half_width)
	var h := float(balance.player.height)
	return Rect2(x - hw, y - h, hw * 2.0, h)


func _room_at_world(x: float, y: float) -> int:
	var cx := int(floor(x / C))
	var cy := int(floor(y / C))
	if cx < 0 or cy < 0 or cx >= W.cols or cy >= W.rows:
		return -1
	return W.room_at[cy * W.cols + cx]


func _near_door(r: Dictionary, p: Vector2, dist: float) -> bool:
	for i: int in r.doors:
		var d: Dictionary = W.doors[i]
		if p.distance_to(Vector2(d.cx, d.cy)) < dist * C:
			return true
	return false


# ---------- input ----------

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_E, KEY_SPACE, KEY_ENTER:
			act()
		KEY_Q:
			use_skill()
		KEY_M:
			state.map = not state.map
		KEY_L:
			state.light = not state.light
		KEY_R:
			load_floor(state.floor, false)
		KEY_ESCAPE:
			get_tree().change_scene_to_file(MENU_SCENE)
		_:
			var k: int = event.keycode
			if k >= KEY_0 and k <= KEY_9:
				load_floor(10 if k == KEY_0 else k - KEY_0, false)


func _axis(neg: Key, pos: Key) -> float:
	return (1.0 if Input.is_physical_key_pressed(pos) else 0.0) - (1.0 if Input.is_physical_key_pressed(neg) else 0.0)


# ---------- gameplay ----------

func _toast(text: String) -> void:
	state.toasts.append({"text": text, "t": 3.6})
	if state.toasts.size() > 3:
		state.toasts.pop_front()


func _hurt(why: String) -> void:
	if state.inv > 0.0 or state.dead > 0.0:
		return
	state.hp = maxi(0, state.hp - 1)
	state.inv = float(balance.player.invulnerable)
	state.flash = 0.25
	if state.hp == 0:
		state.dead = 1.8
		_toast("Gestorben: %s. Zurück zum Abstieg." % why)


func _interactables() -> Array:
	var out: Array = []
	for e: Dictionary in W.ents:
		match e.type:
			"chest":
				if e.get("state", "") != "empty":
					out.append({"e": e, "label": "Beute nehmen" if e.get("state", "") == "open" else "Truhe öffnen", "p": Vector2(e.x, e.y - 20), "r": 120.0})
			"vault":
				if not e.get("opened", false):
					out.append({"e": e, "label": "Riesentresor öffnen", "p": Vector2(e.x, e.y - 30), "r": 170.0})
			"portal":
				var label := "Portal erloschen"
				if e.get("active", false):
					label = "Die Hölle verlassen" if W.final else "Portal zu Etage %d" % (state.floor + 1)
				out.append({"e": e, "label": label, "p": Vector2(e.x, e.y - 20), "r": 230.0})
			"brazier":
				if not e.get("lit", false):
					out.append({"e": e, "label": "Erst die Gegner besiegen" if W.rooms[e.room].fight else "Feuerschale entzünden", "p": Vector2(e.x, e.y - 30), "r": 115.0})
	for d: Dictionary in W.doors:
		var p := Vector2(d.cx, d.cy)
		if d.kind == "lock" and not d.unlocked:
			out.append({"e": d, "label": ("%s benutzen" if state.keys[d.key] else "Verschlossen: %s fehlt") % KEY_NAME[d.key], "p": p, "r": 190.0})
		elif d.kind == "puzzle" and _door_closed(d) and not W.rooms[d.a].fight and not W.rooms[d.b].fight:
			var g: Dictionary = W.groups[d.group]
			out.append({"e": d, "label": "Gittertor: alle Feuerschalen der Etage entzünden" if g.get("spread", false) else ("Rätseltor: alle Feuerschalen entzünden" if g.kind == "braziers" else "Rätseltor: alle Runenplatten betreten"), "p": p, "r": 190.0})
		elif d.kind == "boss" and _door_closed(d):
			out.append({"e": d, "label": "Versiegelt bis %s fällt" % W.boss.name, "p": p, "r": 190.0})
	return out


func _nearest() -> Dictionary:
	var best: Dictionary = {}
	var bd := INF
	var me := Vector2(player.x, player.y - 20)
	for it: Dictionary in _interactables():
		var dd := me.distance_to(it.p)
		if dd < it.r and dd < bd:
			bd = dd
			best = it
	return best


## Uses whatever stands next to the hero (E / Space / Enter).
func act() -> void:
	if state.dead > 0.0:
		return
	if state.won:
		load_floor(state.floor + 1 if state.floor < floors_raw.size() else 1, state.floor < floors_raw.size())
		return
	var n := _nearest()
	if n.is_empty():
		return
	var e: Dictionary = n.e
	if e.has("type"):
		match e.type:
			"chest":
				if e.get("state", "") == "":
					e.state = "open"
					_toast("Truhe geöffnet: %d Runensteine%s" % [e.loot.gems, " und ein Herz" if e.loot.get("heart", false) else ""])
				else:
					e.state = "empty"
					state.gems += int(e.loot.gems)
					if e.loot.get("heart", false):
						state.hp = mini(state.max_hp, state.hp + 2)
			"vault":
				e.opened = true
				var gems: int = int(balance.vault.gems_base) + state.floor * int(balance.vault.gems_per_floor)
				state.gems += gems
				state.max_hp = mini(int(balance.player.max_hp_cap), state.max_hp + 2 * int(balance.vault.heart_containers))
				state.hp = state.max_hp
				_burst(Vector2(e.x, e.y - 60), 60, true)
				_toast("Riesentresor! +1 Herzcontainer, volle Gesundheit, +%d Runensteine" % gems)
			"portal":
				if e.get("active", false):
					state.won = true
					state.won_t = 0.0
					# the clone waits with its time left until Q on the next floor
					state.skill.active = false
					clone = {}
				else:
					_toast("Das Portal erwacht erst, wenn %s fällt." % W.boss.name)
			"brazier":
				if W.rooms[e.room].fight:
					_toast("Erst alle Gegner im Raum besiegen.")
					return
				e.lit = true
				W.lights.append({"x": e.x, "y": e.y - 70, "r": 280, "c": "255,140,60"})
				var prog := Rules.group_progress(W.ents, e.group)
				if prog.x == prog.y:
					_solve_group(e.group)
				else:
					_toast("Feuerschale %d von %d entzündet." % [prog.x, prog.y])
		return
	if e.kind == "lock":
		if state.keys[e.key]:
			state.keys[e.key] = false
			state.used[e.key] = true
			e.unlocked = true
			_toast("Das Tor öffnet sich.")
		else:
			_toast("%s %s" % [KEY_NAME[e.key], KEY_HINT[e.key]])


func _open_secret(d: Dictionary) -> void:
	d.broken = true
	for c: Vector2i in d.cells:
		W.grid[c.y * W.cols + c.x] = 1
	walls = Walls.build(W.grid, W.cols, W.rows, C)
	for node: Layer in _chunk_nodes:
		node.queue_redraw()


func _solve_group(group: String) -> void:
	var g: Dictionary = W.groups[group]
	g.solved = true
	var opened := false
	for d: Dictionary in W.doors:
		if d.kind == "secret" and d.group == group:
			_open_secret(d)
			opened = true
	if opened:
		_toast("Ein verborgener Gang öffnet sich. Ein Geheimraum ist erreichbar.")
	elif g.get("reward", "") == "chest":
		var at: Dictionary = {}
		for e: Dictionary in W.ents:
			if e.get("group", "") == group and (at.is_empty() or int(e.get("order", 0)) == 5):
				at = e
		var loot := {"gems": int(balance.sequence_chest.gems_base) + state.floor, "heart": bool(balance.sequence_chest.heart)}
		var chest := {"type": "chest", "x": at.x, "y": at.y + 10.0, "room": at.room, "loot": loot, "magic": true}
		W.ents.append(chest)
		_add_solid(Rect2(chest.x - 40, chest.y - 32, 80, 32))
		_burst(Vector2(at.x, at.y - 40), 40, true)
		_toast("Die Platten glühen auf. Eine Belohnungstruhe erscheint!")
	elif g.kind == "braziers":
		_toast("Alle Feuerschalen brennen. Das Gitter zum Riesentresor hebt sich!" if g.get("spread", false) else "Alle Schalen brennen. Das Tor hebt sich.")
	else:
		_toast("Alle Runen leuchten. Das Tor öffnet sich.")


func _fire(dir: Vector2) -> void:
	if state.cool > 0.0 or dir == Vector2.ZERO:
		return
	var v := dir.normalized() * float(balance.shot.speed)
	shots.append({"p": Vector2(player.x, player.y - 40), "v": v, "t": float(state.range)})
	state.cool = float(state.rate)
	if absf(dir.x) > 0.01:
		player.face = signf(dir.x)


func _spawn_mob(room: int, pos: Vector2, kind: String) -> void:
	var def: Dictionary = balance.mobs[kind]
	var diff: Dictionary = W.diff
	var hp: float = float(W.boss.hp) if kind == "boss" else round(float(def.hp) * float(diff.hp))
	var scale := float(def.scale)
	if kind == "boss" and (W.boss.get("mini", false) or W.final):
		scale *= 1.25 if W.final else 1.05
	mobs.append({"room": room, "kind": kind, "p": pos, "hp": hp, "max": hp, "sp": float(def.speed) * float(diff.speed),
		"s": scale, "r": float(def.radius), "seed": randf() * 9.0, "k": Vector2.ZERO, "hit": 0.0, "spawn": 0.5,
		"summon": 2.5, "shoot": 1.0 + randf() * 2.0, "ring_t": float(W.boss.get("ring", 0.0)), "spin": 0.0})


func _start_fight(r: Dictionary) -> void:
	r.fight = true
	var me := Vector2(player.x, player.y)
	var cells: Array = []
	for c: Vector2i in r.cells:
		var p := Vector2((c.x + 0.5) * C, (c.y + 0.7) * C)
		if W.grid[c.y * W.cols + c.x] == 1 and p.distance_to(me) > 4.5 * C and not _near_door(r, p, 2.0) and solid_grid.get(c.y * W.cols + c.x, []).is_empty():
			cells.append(p)
	cells.shuffle()
	var count: int = int(r.mobs if r.mobs > 0 else 3) + int(W.diff.extra)
	for k in range(mini(count, cells.size())):
		var kind := "glut"
		if W.diff.get("shooters", false) and k % 4 == 1:
			kind = "spucker"
		elif k % 3 == 2:
			kind = "gross"
		_spawn_mob(r.index, cells[k], kind)
	if r.type == "boss":
		_spawn_mob(r.index, Vector2((r.bx + r.bw / 2.0) * C, (r.by + r.bh / 2.0 + 1.0) * C), "boss")
		_toast("%s erwacht. Die Tore sind verriegelt." % W.boss.name)
	else:
		_toast("Die Gitter fallen. Besiege alle Gegner.")


func _clear_room(r: Dictionary, at: Vector2) -> void:
	r.fight = false
	r.cleared = true
	# a room cleared a second time (seal demons) gives no second key or reward
	var again: bool = r.get("rewarded", false)
	r.rewarded = true
	if r.drop != "" and not again:
		_drop("key", r.index, at, {"key": r.drop})
		_toast("Raum gesäubert. %s gefallen!" % KEY_NAME[r.drop])
	elif r.type == "boss":
		state.boss_dead = true
		eshots = []
		for e: Dictionary in W.ents:
			if e.type == "portal":
				e.active = true
		if state.floor == int(balance.clone.floor) and not state.skill.owned:
			state.skill = {"owned": true, "active": false, "left": float(balance.clone.duration)}
			_toast("Neuer Skill: Klon rufen (Q) – 2 Minuten Kampfgefährte.")
		else:
			_toast("%s fällt. Die Portalkammer ist offen." % W.boss.name)
	else:
		_toast("Raum gesäubert. Die Gitter heben sich.")
	if again:
		return
	if r.reward != null:
		if r.reward.get("heart", false):
			_drop("heart", r.index, at)
		for k in range(int(r.reward.get("gems", 0))):
			_drop("gem", r.index, at)
	elif randf() < float(balance.drops.heart):
		_drop("heart", r.index, at)
	elif randf() < float(balance.drops.gem):
		_drop("gem", r.index, at)


func _drop(kind: String, room: int, at: Vector2, extra := {}) -> void:
	var e := {"type": kind, "x": at.x + randf_range(-30, 30), "y": at.y + randf_range(-20, 20), "room": room}
	e.merge(extra)
	W.ents.append(e)


func _enemy_shot(from: Vector2, dir: Vector2, speed: float) -> void:
	eshots.append({"p": from, "v": dir.normalized() * speed, "t": float(balance.enemy_shot.life)})


func _burst(at: Vector2, n: int, gold := false) -> void:
	for k in range(n):
		embers.append({"p": at, "v": Vector2(randf_range(-150, 150), randf_range(-210, 90)), "t": randf_range(0.35, 0.85), "big": n > 20, "gold": gold})


# ---------- seals, skull heaps, pits and the clone ----------

func _hit_breakable(e: Dictionary, at: Vector2) -> void:
	e.hit = 0.15
	_burst(at, 8)
	if not Rules.hit_breakable(e):
		return
	_burst(Vector2(e.x, e.y - 40), 40)
	if e.type == "skullheap":
		_open_secret(W.doors[int(e.door)])
		_toast("Der Schädelhaufen zerfällt. Ein versteckter Gang öffnet sich!")
	else:
		_break_seal(e)


## A broken seal blesses the hero (bless_chance) or releases demons that lock the room again.
func _break_seal(e: Dictionary) -> void:
	var cfg: Dictionary = balance.seal
	if randf() < float(cfg.bless_chance):
		var id: String = Rules.BLESSINGS[randi() % Rules.BLESSINGS.size()]
		var text := Rules.apply_blessing(state, id, balance.blessings, int(balance.player.max_hp_cap))
		_burst(Vector2(e.x, e.y - 60), 50, true)
		_toast("Das Siegel bricht: %s!" % text)
		return
	var r: Dictionary = W.rooms[e.room]
	r.fight = true
	r.cleared = false
	var n := int(cfg.demons)
	for k in range(n):
		_spawn_mob(r.index, Vector2(e.x + (k - (n - 1) / 2.0) * 90.0, e.y + 60.0 + (50.0 if k == 1 else 0.0)), String(cfg.demon_kind))
	_toast("Das Siegel bricht: drei Dämonen springen heraus! Die Gitter fallen.")


func _fall_into_pit() -> void:
	state.hp = maxi(0, state.hp - int(balance.pit.damage))
	state.flash = 0.4
	_burst(Vector2(player.x, player.y - 30), 24)
	if state.hp == 0:
		state.dead = 1.8
		_toast("In die Grube gestürzt. Zurück zum Abstieg.")
		return
	for r: Dictionary in W.rooms:
		if r.fight:
			r.fight = false
			mobs = mobs.filter(func(m: Dictionary) -> bool: return m.room != r.index)
	eshots = []
	_respawn()
	state.inv = 1.2
	var s := _room_of_type("start")
	state.room = s.index
	camera.position = Vector2(player.x, player.y)
	state.banner = {"text": s.name, "sub": "Aus der Grube zurück zum Start", "t": 0.0}
	_toast("In die Grube gestürzt: −1 Herz, zurück im Startraum.")


## Calls the clone (Q). Once started it runs until its time is spent.
func use_skill() -> void:
	match Rules.start_skill(state.skill):
		"none":
			_toast("Noch kein Skill. Besiege den Boss auf Etage %d." % int(balance.clone.floor))
		"running":
			_toast("Der Klon kämpft bereits und lässt sich nicht abbrechen.")
		"spent":
			_toast("Der Klon ist aufgebraucht.")
		"started":
			clone = {"p": Vector2(player.x - 60, player.y + 20), "cool": 0.0, "seed": randf() * 9.0}
			_burst(Vector2(player.x, player.y - 40), 30, true)
			_toast("Klon gerufen: %d Sekunden." % ceili(state.skill.left))


func _update_clone(dt: float) -> void:
	if not state.skill.active or clone.is_empty():
		return
	if Rules.tick_skill(state.skill, dt):
		_burst(clone.p - Vector2(0, 40), 30)
		clone = {}
		_toast("Der Klon zerfällt. Zeit abgelaufen.")
		return
	# follows behind the hero, weaving to dodge; enemies never target it
	var cfg: Dictionary = balance.clone
	var weave := sin(state.t * 5.0 + clone.seed) * float(cfg.weave)
	var target_p := Vector2(player.x - player.face * float(cfg.follow), player.y + 26.0 + weave)
	clone.p = clone.p.lerp(target_p, 1.0 - pow(0.004, dt))
	clone.cool -= dt
	var best: Dictionary = {}
	var bd := float(cfg.range)
	for m: Dictionary in mobs:
		if m.spawn <= 0.0 and m.p.distance_to(clone.p) < bd:
			bd = m.p.distance_to(clone.p)
			best = m
	if not best.is_empty() and clone.cool <= 0.0:
		clone.cool = float(cfg.fire_every)
		var from: Vector2 = clone.p - Vector2(0, 40)
		var aim: Vector2 = best.p - Vector2(0, 30.0 * best.s) - from
		shots.append({"p": from, "v": aim.normalized() * float(balance.shot.speed), "t": float(state.range)})


func _process(delta: float) -> void:
	var dt := minf(delta, 0.05)
	_update(dt)
	actors.queue_redraw()
	dark.queue_redraw()
	hud.queue_redraw()


func _update(dt: float) -> void:
	state.t += dt
	for k in ["inv", "flash", "cool"]:
		state[k] = maxf(0.0, state[k] - dt)
	for t: Dictionary in state.toasts:
		t.t -= dt
	state.toasts = state.toasts.filter(func(t: Dictionary) -> bool: return t.t > 0.0)
	state.banner.t += dt
	if state.won:
		state.won_t += dt
		return
	if state.dead > 0.0:
		state.dead -= dt
		if state.dead <= 0.0:
			for r: Dictionary in W.rooms:
				if r.fight:
					r.fight = false
			mobs = []
			eshots = []
			_respawn()
			state.hp = state.max_hp
			state.inv = 1.2
			state.room = _room_of_type("start").index
		return
	_update_player(dt)
	if state.dead > 0.0:
		return
	_update_clone(dt)
	_update_shots(dt)
	_update_mobs(dt)
	_update_hazards(dt)
	_update_rooms()
	_update_embers(dt)
	_update_camera(dt)


func _update_player(dt: float) -> void:
	var move := Vector2(_axis(KEY_A, KEY_D), _axis(KEY_W, KEY_S))
	var here := _cell(int(floor(player.x / C)), int(floor((player.y - 6.0) / C)))
	var speed := float(balance.player.speed) * float(state.speed_mul) * (float(balance.player.lava_slow) if here == 2 else 1.0)
	player.moving = move != Vector2.ZERO
	if player.moving:
		var v := move.normalized() * speed * dt
		if not box_blocked(_player_box(player.x + v.x, player.y)):
			player.x += v.x
		if not box_blocked(_player_box(player.x, player.y + v.y)):
			player.y += v.y
		if absf(move.x) > 0.0:
			player.face = signf(move.x)
	player.anim += dt * (10.0 if player.moving else 5.0)
	var aim := Vector2(_axis(KEY_LEFT, KEY_RIGHT), _axis(KEY_UP, KEY_DOWN))
	if aim != Vector2.ZERO:
		_fire(aim)
	elif Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_fire(get_global_mouse_position() - Vector2(player.x, player.y - 40))
	if here == 2:
		_hurt("in der Lava verbrannt")
	for e: Dictionary in pits:
		if absf(player.x - e.x) < float(balance.pit.reach_x) and absf(player.y - 8.0 - e.y) < float(balance.pit.reach_y):
			_fall_into_pit()
			return


func _update_shots(dt: float) -> void:
	for s: Dictionary in shots:
		s.p += s.v * dt
		s.t -= dt
		var struck: Dictionary = {}
		for e: Dictionary in breakables:
			if not e.get("broken", false) and absf(s.p.x - e.x) < 50.0 and s.p.y > e.y - 90.0 and s.p.y < e.y + 10.0:
				struck = e
		if not struck.is_empty():
			s.t = 0.0
			_hit_breakable(struck, s.p)
			continue
		var c := Vector2i(int(floor(s.p.x / C)), int(floor(s.p.y / C)))
		var hit_solid := false
		for r: Rect2 in solid_grid.get(c.y * int(W.cols) + c.x, []):
			if r.grow_individual(0, 50, 0, 0).has_point(s.p):
				hit_solid = true
		if _cell_blocked(c.x, c.y, false) or hit_solid:
			s.t = 0.0
			_burst(s.p, 5)
			continue
		for m: Dictionary in mobs:
			if m.spawn <= 0.0 and s.p.distance_to(m.p - Vector2(0, 30.0 * m.s)) < m.r + 12.0:
				m.hp -= float(state.dmg)
				m.hit = 0.12
				m.k = s.v * (0.05 if m.kind == "boss" else 0.25)
				s.t = 0.0
				_burst(s.p, 6)
				break
	shots = shots.filter(func(s: Dictionary) -> bool: return s.t > 0.0)
	var me := Vector2(player.x, player.y - 34)
	for s: Dictionary in eshots:
		s.p += s.v * dt
		s.t -= dt
		if _cell_blocked(int(floor(s.p.x / C)), int(floor(s.p.y / C)), false):
			s.t = 0.0
			_burst(s.p, 4)
		elif s.p.distance_to(me) < float(balance.enemy_shot.hit_radius):
			s.t = 0.0
			_hurt("von Feuer getroffen")
	eshots = eshots.filter(func(s: Dictionary) -> bool: return s.t > 0.0)


func _update_mobs(dt: float) -> void:
	var me := Vector2(player.x, player.y)
	for m: Dictionary in mobs:
		if m.spawn > 0.0:
			m.spawn -= dt
			continue
		m.hit = maxf(0.0, m.hit - dt)
		var to: Vector2 = me - m.p
		var d := maxf(to.length(), 1.0)
		var dir := to / d
		var wob := sin(state.t * 3.0 + m.seed) * 0.7
		var away := -1.0 if m.kind == "spucker" and d < float(balance.mobs.spucker.keep_away) else 1.0
		var v: Vector2 = (dir * away + Vector2(-dir.y, dir.x) * wob) * m.sp
		for o: Dictionary in mobs:
			if o != m:
				var off: Vector2 = m.p - o.p
				var od := off.length()
				if od > 0.0 and od < m.r + o.r:
					v += off / od * 120.0
		v += m.k
		m.k *= 0.86
		var rr: float = m.r * 0.7
		var avoid: bool = m.kind != "boss"
		var nx: Vector2 = m.p + Vector2(v.x * dt, 0)
		if not box_blocked(Rect2(nx.x - rr, nx.y - rr, rr * 2, rr), avoid):
			m.p = nx
		var ny: Vector2 = m.p + Vector2(0, v.y * dt)
		if not box_blocked(Rect2(ny.x - rr, ny.y - rr, rr * 2, rr), avoid):
			m.p = ny
		if d < m.r + 22.0:
			_hurt("von %s erschlagen" % W.boss.name if m.kind == "boss" else "von Glutlingen verbrannt")
		if m.kind == "spucker":
			m.shoot -= dt
			if m.shoot <= 0.0:
				m.shoot = float(balance.mobs.spucker.fire_every)
				_enemy_shot(m.p - Vector2(0, 40), to - Vector2(0, 30), float(balance.enemy_shot.speed))
		elif m.kind == "boss":
			m.summon -= dt
			var adds := 0
			for o: Dictionary in mobs:
				if o.room == m.room and o.kind != "boss":
					adds += 1
			if m.summon <= 0.0 and adds < int(balance.mobs.boss.max_adds):
				m.summon = float(W.boss.summon)
				_spawn_mob(m.room, m.p + Vector2(-100, 30), "glut")
				_spawn_mob(m.room, m.p + Vector2(100, 30), "spucker" if W.final else "glut")
			if float(W.boss.get("ring", 0.0)) > 0.0:
				m.ring_t -= dt
				if m.ring_t <= 0.0:
					m.ring_t = float(W.boss.ring)
					m.spin += 0.3
					var n := 16 if W.final else 10
					for k in range(n):
						var a: float = m.spin + float(k) / n * TAU
						_enemy_shot(m.p - Vector2(0, 70), Vector2(cos(a), sin(a)), float(balance.enemy_shot.ring_speed))
	for m: Dictionary in mobs.duplicate():
		if m.hp > 0.0:
			continue
		_burst(m.p - Vector2(0, 30), 70 if m.kind == "boss" else 16)
		mobs.erase(m)
		var rest := mobs.filter(func(o: Dictionary) -> bool: return o.room == m.room)
		if rest.is_empty():
			_clear_room(W.rooms[m.room], m.p)


func _update_hazards(dt: float) -> void:
	var me := Vector2(player.x, player.y)
	var cr: Dictionary = W.rooms[state.room]
	var hz: Dictionary = balance.hazards
	for e: Dictionary in W.ents:
		match e.type:
			"spikes":
				e.up = int(state.t / float(hz.spike_period)) % 2 == int(e.phase)
				if e.up and absf(me.x - e.x) < 42 and absf(me.y - 12 - e.y) < 40:
					_hurt("von Stacheln getroffen")
			"vent":
				e.burst = fmod(state.t + float(e.offset), float(hz.vent_period)) < float(hz.vent_burst)
				if e.burst and me.distance_to(Vector2(e.x, e.y)) < float(hz.vent_radius):
					_hurt("vom Glutschlot verbrannt")
				if e.burst and randf() < 0.6:
					embers.append({"p": Vector2(e.x + randf_range(-20, 20), e.y - 10), "v": Vector2(randf_range(-20, 20), randf_range(-280, -160)), "t": 0.8, "big": true, "gold": false})
			"plate":
				if e.get("on", false) or absf(me.x - e.x) > 44 or absf(me.y - 10 - e.y) > 44:
					continue
				var g: Dictionary = W.groups[e.group]
				if g.solved:
					continue
				if g.kind == "sequence":
					if cr.fight or e.get("wrong", 0.0) > 0.0:
						continue
					var res := Rules.step_sequence(W.ents, W.groups, e)
					if res == "solved":
						_solve_group(e.group)
					elif res == "right":
						var p := Rules.group_progress(W.ents, e.group)
						_toast("Platte %d von %d richtig." % [p.x, p.y])
					elif res == "wrong":
						e.wrong = 0.8
						_toast("Falsche Reihenfolge. Die Platten erlöschen.")
				else:
					e.on = true
					var p := Rules.group_progress(W.ents, e.group)
					if p.x == p.y:
						_solve_group(e.group)
					else:
						_toast("Runenplatte %d von %d aktiviert." % [p.x, p.y])
			"key", "heart", "gem":
				if e.get("taken", false) or me.distance_to(Vector2(e.x, e.y)) > 52:
					continue
				if e.type == "heart" and state.hp >= state.max_hp:
					continue
				e.taken = true
				if e.type == "key":
					state.keys[e.key] = true
					_toast("%s aufgehoben." % KEY_NAME[e.key])
				elif e.type == "heart":
					state.hp = mini(state.max_hp, state.hp + 2)
					_toast("+1 Herz")
				else:
					state.gems += 1
		if e.get("wrong", 0.0) > 0.0:
			e.wrong = maxf(0.0, e.wrong - dt)
		if e.get("hit", 0.0) > 0.0:
			e.hit = maxf(0.0, e.hit - dt)


func _update_rooms() -> void:
	var ri := _room_at_world(player.x, player.y - 12.0)
	if ri >= 0 and ri != state.room:
		state.room = ri
		state.visited[ri] = true
		state.banner = {"text": W.rooms[ri].name, "sub": W.rooms[ri].kind, "t": 0.0}
	var r: Dictionary = W.rooms[state.room]
	if r.cleared or r.fight:
		return
	var hw := float(balance.player.half_width) + 40.0
	for o: Vector2 in [Vector2(-hw, -60), Vector2(hw, -60), Vector2(-hw, 30), Vector2(hw, 30)]:
		if _room_at_world(player.x + o.x, player.y + o.y) != r.index:
			return
	_start_fight(r)


func _update_embers(dt: float) -> void:
	if state.light:
		for k in range(int(W.theme.embers)):
			var x := camera.position.x + randf_range(-900, 900)
			var y := camera.position.y + randf_range(-500, 500)
			if _cell(int(floor(x / C)), int(floor(y / C))) == 2:
				embers.append({"p": Vector2(x, y), "v": Vector2(randf_range(-10, 10), randf_range(-90, -40)), "t": randf_range(1.2, 2.2), "big": false, "gold": false})
	for p: Dictionary in embers:
		p.p += p.v * dt
		p.t -= dt
	embers = embers.filter(func(p: Dictionary) -> bool: return p.t > 0.0)
	if embers.size() > 360:
		embers = embers.slice(embers.size() - 360)


func _update_camera(dt: float) -> void:
	var r: Dictionary = W.rooms[state.room]
	var target := Vector2(player.x, player.y - 40)
	var view := Vector2(float(balance.view.width), float(balance.view.width) * 9.0 / 16.0)
	if _room_at_world(player.x, player.y - 12.0) >= 0:
		var lo := Vector2(r.bx * C - 70, r.by * C - 110)
		var hi := Vector2((r.bx + r.bw) * C + 70, (r.by + r.bh) * C + 80)
		for axis in [0, 1]:
			if hi[axis] - lo[axis] <= view[axis]:
				target[axis] = (lo[axis] + hi[axis]) / 2.0
			else:
				target[axis] = clampf(target[axis], lo[axis] + view[axis] / 2.0, hi[axis] - view[axis] / 2.0)
	camera.position = camera.position.lerp(target, 1.0 - pow(0.0015, dt))


# ---------- world drawing ----------

## Draws one layer: static chunks (back/front), live actors, or the darkness.
func draw_layer(l: Layer) -> void:
	match l.kind:
		"back": _draw_back(l)
		"front": _draw_front(l)
		"actors": _draw_actors(l)
		"dark": _draw_dark(l)


func _tex(ci: CanvasItem, name: String, pos: Vector2, flip := false, tint := Color.WHITE, scale := 1.0) -> void:
	var t: Texture2D = tex.get(name)
	if t == null:
		return
	var size := t.get_size() * scale
	if flip:
		ci.draw_set_transform(pos + Vector2(size.x, 0), 0.0, Vector2(-1, 1))
		ci.draw_texture_rect(t, Rect2(Vector2.ZERO, size), false, tint)
		ci.draw_set_transform(Vector2.ZERO)
	else:
		ci.draw_texture_rect(t, Rect2(pos, size), false, tint)


func _strip(ci: CanvasItem, w: Dictionary, area: Rect2) -> void:
	var wh: Texture2D = tex.wall_h
	var x0: float = maxf(w.x0, area.position.x)
	var x1: float = minf(w.x1, area.end.x)
	var x := x0
	while x < x1:
		var off := fmod(x - w.x0, wh.get_width())
		var sw := minf(wh.get_width() - off, x1 - x)
		ci.draw_texture_rect_region(wh, Rect2(x, w.y, sw, wh.get_height()), Rect2(off, 0, sw, wh.get_height()))
		x += sw


func _draw_back(l: Layer) -> void:
	var a := l.area
	var cols: int = W.cols
	var x0 := int(a.position.x / C)
	var y0 := int(a.position.y / C)
	var lava: Texture2D = tex.lava_00
	var hole_tint := Color(0.75, 0.68, 0.7)
	for y in range(y0, mini(y0 + CHUNK.y, W.rows)):
		for x in range(x0, mini(x0 + CHUNK.x, cols)):
			var i := y * cols + x
			var t: int = W.grid[i]
			var r := Rect2(x * C, y * C, C + 0.5, C + 0.5)
			if t == 0:
				if W.holes[i] == 1:
					l.draw_texture_rect(tex.wall_v, r, true, hole_tint)
				continue
			if t == 2 or t == 3:
				l.draw_texture_rect_region(tex.lava_01 if (x * 7 + y * 13) % 10 > 6 else lava, r, Rect2(14, 14, 68, 68))
			else:
				l.draw_texture(tex[W.tile_names[W.tiles[i]]], Vector2(x * C, y * C))
	var rim: Texture2D = tex.lava_edge_top
	for y in range(y0, mini(y0 + CHUNK.y, W.rows)):
		for x in range(x0, mini(x0 + CHUNK.x, cols)):
			var t := _cell(x, y)
			if t != 2 and t != 3:
				continue
			for side: Array in [[Vector2i(0, -1), Vector2(x * C, y * C), 0.0], [Vector2i(0, 1), Vector2(x * C + C, y * C + C), PI], [Vector2i(-1, 0), Vector2(x * C, y * C + C), -PI / 2], [Vector2i(1, 0), Vector2(x * C + C, y * C), PI / 2]]:
				var n := _cell(x + side[0].x, y + side[0].y)
				if n == 1 or n == 0:
					l.draw_set_transform(side[1], side[2])
					l.draw_texture_rect_region(rim, Rect2(-2, -18, 50, 36), Rect2(0, 0, 48, 36))
					l.draw_texture_rect_region(rim, Rect2(46, -18, 52, 36), Rect2(6, 0, 48, 36))
					l.draw_set_transform(Vector2.ZERO)
	for d: Dictionary in W.decals:
		if not a.has_point(Vector2(d.x, d.y)):
			continue
		var t: Texture2D = tex[d.name]
		var size := Vector2(d.w, d.h) if float(d.w) > 0.0 else t.get_size()
		l.draw_texture_rect(t, Rect2(Vector2(d.x, d.y) - size / 2.0, size), false, Color(1, 1, 1, float(d.a)))
	for w: Dictionary in walls.north:
		if w.y + 74.0 >= a.position.y and w.y + 74.0 < a.end.y and w.x1 > a.position.x and w.x0 < a.end.x:
			l.draw_rect(Rect2(maxf(w.x0, a.position.x), w.y + 74.0, minf(w.x1, a.end.x) - maxf(w.x0, a.position.x), 40.0), Color(0, 0, 0, 0.35))
			_strip(l, w, a)
	var wv: Texture2D = tex.wall_v
	for s: Dictionary in walls.side:
		if s.glow:
			if a.has_point(Vector2(s.x + 31, s.y)):
				var g: Texture2D = tex.wall_v_glow
				_tex(l, "wall_v_glow", Vector2(s.x + 31 - g.get_width() / 2.0, s.y - g.get_height() / 2.0), s.flip)
			continue
		if s.x + 31 < a.position.x or s.x + 31 >= a.end.x:
			continue
		var yy: float = maxf(s.y0, a.position.y)
		var y_end: float = minf(s.y1, a.end.y)
		while yy < y_end:
			var off := fmod(yy - s.y0, wv.get_height())
			var sh := minf(wv.get_height() - off, y_end - yy)
			if s.flip:
				l.draw_set_transform(Vector2(s.x + wv.get_width(), yy), 0.0, Vector2(-1, 1))
				l.draw_texture_rect_region(wv, Rect2(0, 0, wv.get_width(), sh), Rect2(0, off, wv.get_width(), sh))
				l.draw_set_transform(Vector2.ZERO)
			else:
				l.draw_texture_rect_region(wv, Rect2(s.x, yy, wv.get_width(), sh), Rect2(0, off, wv.get_width(), sh))
			yy += sh
	for p: Vector2 in walls.posts:
		if a.has_point(p - Vector2(0, 1)):
			var g: Texture2D = tex.wall_h_glowpost
			l.draw_texture(g, p - Vector2(g.get_width() / 2.0, g.get_height()))
	for c: Vector2 in walls.caps:
		if a.has_point(c):
			l.draw_texture(tex.corner_cap, c - Vector2(38, 38))
	for w: Dictionary in W.wall_decor:
		if a.has_point(Vector2(w.x, w.y + 74)):
			var t: Texture2D = tex[w.name]
			_tex(l, w.name, Vector2(w.x - t.get_width() / 2.0, w.y), w.flip)


func _draw_front(l: Layer) -> void:
	for w: Dictionary in walls.south:
		if w.y - 1.0 >= l.area.position.y and w.y - 1.0 < l.area.end.y and w.x1 > l.area.position.x and w.x0 < l.area.end.x:
			_strip(l, w, l.area)


func _view_rect() -> Rect2:
	var size := Vector2(float(balance.view.width), float(balance.view.width) * 9.0 / 16.0)
	return Rect2(camera.position - size / 2.0, size)


func _draw_actors(l: Layer) -> void:
	var view := _view_rect().grow(220)
	var t: float = state.t
	for e: Dictionary in W.ents:
		if not view.has_point(Vector2(e.x, e.y)):
			continue
		match e.type:
			"spikes":
				var im: Texture2D = tex.spike_trap
				var up: bool = e.get("up", false)
				var size := im.get_size() - Vector2(0, 0 if up else 16)
				l.draw_texture_rect(im, Rect2(Vector2(e.x, e.y + (0 if up else 8)) - im.get_size() / 2.0, size), false, Color(1, 1, 1, 1.0 if up else 0.3))
			"vent":
				l.draw_texture(tex.vent, Vector2(e.x, e.y) - tex.vent.get_size() / 2.0)
			"plate":
				_draw_plate(l, e, t)
	var list: Array = []
	for p: Dictionary in W.props:
		if p.name != "" and view.has_point(Vector2(p.x, p.y)):
			list.append([p.y - (200.0 if p.low else 0.0), "prop", p])
	for e: Dictionary in W.ents:
		if view.has_point(Vector2(e.x, e.y)) and e.type in ["chest", "vault", "portal", "brazier", "key", "heart", "gem"] and not e.get("taken", false):
			list.append([e.y, "ent", e])
	for e: Dictionary in breakables:
		if view.has_point(Vector2(e.x, e.y)):
			list.append([e.y - (200.0 if e.get("broken", false) else 0.0), "breakable", e])
	if not clone.is_empty():
		list.append([clone.p.y, "clone", clone])
	for d: Dictionary in W.doors:
		if d.kind != "secret" and view.has_point(Vector2(d.cx, d.cy)) and _door_closed(d):
			list.append([d.cy + 60.0, "gate", d])
	for m: Dictionary in mobs:
		if view.has_point(m.p):
			list.append([m.p.y, "mob", m])
	list.append([player.y, "hero", player])
	list.sort_custom(func(x: Array, y: Array) -> bool: return x[0] < y[0])
	for item: Array in list:
		match item[1]:
			"prop":
				var p: Dictionary = item[2]
				var im: Texture2D = tex[p.name]
				_tex(l, p.name, Vector2(p.x - im.get_width() / 2.0, p.y - im.get_height()), p.flip)
			"ent": _draw_ent(l, item[2], t)
			"gate": _draw_gate(l, item[2], t)
			"mob": _draw_mob(l, item[2], t)
			"breakable": _draw_breakable(l, item[2], t)
			"clone": _draw_clone(l, t)
			"hero": _draw_hero(l, t)
	for s: Dictionary in shots:
		l.draw_circle(s.p, 16.0, Color(1, 0.55, 0.2, 0.45))
		l.draw_circle(s.p, 8.0, Color(1, 0.95, 0.75))
	for s: Dictionary in eshots:
		l.draw_circle(s.p, 15.0, Color(0.8, 0.1, 0.08, 0.5))
		l.draw_circle(s.p, 7.0, Color(1, 0.75, 0.7))
	for p: Dictionary in embers:
		var col := Color("#ffe28a") if p.gold else (Color("#ff7a2a") if p.big else Color("#ffb347"))
		col.a = minf(1.0, p.t * 2.0)
		var s := 9.0 if p.big else 5.0
		l.draw_rect(Rect2(p.p - Vector2(s, s) / 2.0, Vector2(s, s)), col)


func _draw_plate(l: Layer, e: Dictionary, t: float) -> void:
	var im: Texture2D = tex.rune_plate
	var r := Rect2(Vector2(e.x, e.y) - im.get_size() / 2.0, im.get_size())
	var g: Dictionary = W.groups[e.group]
	l.draw_texture_rect(im, r, false)
	var glow := 0.0
	if e.get("on", false):
		glow = 0.55 + 0.2 * sin(t * 5.0)
	elif g.kind == "sequence" and not g.solved and e.room == state.room and not W.rooms[state.room].fight:
		var parts := Rules.group_progress(W.ents, e.group).y
		var cyc := fmod(t, parts * 0.75 + 1.4) / 0.75
		if int(cyc) + 1 == int(e.order):
			glow = 0.9
	if e.get("wrong", 0.0) > 0.0:
		l.draw_rect(r, Color(1, 0.12, 0.08, 0.4))
	if glow > 0.0:
		l.draw_texture_rect(im, r, false, Color(1.8, 1.2, 0.8, glow))
	else:
		l.draw_rect(r.grow(-6), Color(0, 0, 0, 0.45))


func _draw_ent(l: Layer, e: Dictionary, t: float) -> void:
	match e.type:
		"chest":
			var n := "chest_closed"
			if e.get("state", "") == "open":
				n = "chest_open" if e.get("magic", false) else "chest_gold"
			elif e.get("state", "") == "empty":
				n = "chest_empty"
			var im: Texture2D = tex[n]
			l.draw_texture(im, Vector2(e.x - im.get_width() / 2.0, e.y - im.get_height()))
		"vault":
			var im: Texture2D = tex.chest_empty if e.get("opened", false) else tex.chest_gold
			var size := im.get_size() * 1.9
			if not e.get("opened", false):
				var c := Vector2(e.x, e.y - size.y * 0.55)
				for k in range(10):
					var ang := t * 0.5 + k * TAU / 10.0
					var tip := c + Vector2(cos(ang), sin(ang)) * 250.0
					var side := Vector2(-sin(ang), cos(ang)) * 30.0
					l.draw_colored_polygon(PackedVector2Array([c - side * 0.3, tip - side, tip + side, c + side * 0.3]), Color(1, 0.72, 0.22, 0.2))
				if randf() < 0.3:
					embers.append({"p": Vector2(e.x + randf_range(-70, 70), e.y - randf() * 120), "v": Vector2(0, -30), "t": 0.9, "big": false, "gold": true})
			l.draw_texture_rect(im, Rect2(Vector2(e.x - size.x / 2.0, e.y - size.y), size), false)
		"portal":
			var im: Texture2D = tex.portal if e.get("active", false) else tex.portal_dark
			l.draw_texture(im, Vector2(e.x - im.get_width() / 2.0, e.y - im.get_height()))
		"brazier":
			var im: Texture2D = tex.brazier_bowl
			if e.get("lit", false):
				l.draw_texture(im, Vector2(e.x - im.get_width() / 2.0, e.y - im.get_height()))
			else:
				var cut := 46.0
				l.draw_texture_rect_region(im, Rect2(e.x - im.get_width() / 2.0, e.y - im.get_height() + cut, im.get_width(), im.get_height() - cut), Rect2(0, cut, im.get_width(), im.get_height() - cut))
		"key", "heart", "gem":
			var name: String = "rune_gem" if e.type == "gem" else e.type
			var im: Texture2D = tex[name]
			var s := 0.9 if e.type == "key" else (0.55 if e.type == "gem" else 0.7)
			var bob := sin(t * 3.0 + e.x) * 6.0
			var size := im.get_size() * s
			l.draw_texture_rect(im, Rect2(Vector2(e.x - size.x / 2.0, e.y - size.y - 10 + bob), size), false, KEY_TINT.get(e.get("key", ""), Color.WHITE))


func _draw_gate(l: Layer, d: Dictionary, t: float) -> void:
	var im: Texture2D = tex.portcullis
	l.draw_set_transform(Vector2(d.cx, d.cy), PI / 2 if d.dir == "h" else 0.0)
	var fight: bool = W.rooms[d.a].fight or W.rooms[d.b].fight
	var tint := Color.WHITE
	if fight or d.kind == "boss":
		tint = Color(1.0 + 0.4 * (0.5 + 0.5 * sin(t * 5.0)), 0.75, 0.7)
	l.draw_texture(im, -im.get_size() / 2.0, tint)
	l.draw_set_transform(Vector2.ZERO)
	if not fight and d.kind == "lock":
		l.draw_texture_rect(tex.key, Rect2(d.cx - 15, d.cy - 30, 30, 56), false, KEY_TINT[d.key])
	elif not fight and d.kind == "puzzle":
		var icon: Texture2D = tex.brazier_bowl if W.groups[d.group].kind == "braziers" else tex.icon_scroll
		l.draw_texture_rect(icon, Rect2(d.cx - 22, d.cy - 30, 44, 44 * icon.get_height() / icon.get_width()), false)


func _draw_mob(l: Layer, m: Dictionary, t: float) -> void:
	var im: Texture2D = tex.fire_orb
	var s: float = m.s * (1.0 - m.spawn * 1.6 if m.spawn > 0.0 else 1.0)
	if s <= 0.0:
		return
	var tint := Color.WHITE
	match m.kind:
		"gross": tint = Color(0.9, 0.6, 0.5)
		"spucker": tint = Color(0.75, 0.55, 1.6)
		"boss": tint = Color(0.6, 0.45, 1.6) if W.final else Color(1.2, 0.55, 0.45)
	if m.hit > 0.0:
		tint = Color(3, 3, 3)
	var bob := sin(t * 6.0 + m.seed) * 6.0
	var size := im.get_size() * s
	l.draw_texture_rect(im, Rect2(m.p - Vector2(size.x / 2.0, size.y + 14 - bob), size), false, tint)
	if m.kind == "boss":
		var icon: Texture2D = tex.icon_demon_big if W.final else tex.icon_demon
		var k := s / 2.7
		l.draw_texture_rect(icon, Rect2(m.p.x - 46 * k, m.p.y - size.y - 4 + bob, 92 * k, 96 * k), false)


func _draw_breakable(l: Layer, e: Dictionary, t: float) -> void:
	if e.get("broken", false):
		var rb: Texture2D = tex.rubble
		l.draw_texture(rb, Vector2(e.x - rb.get_width() / 2.0, e.y - rb.get_height()))
		return
	var seal: bool = e.type == "seal"
	var im: Texture2D = tex.demon_plate if seal else tex.skull_heap
	var size := im.get_size() * (1.15 if seal else 1.0)
	var shake := randf_range(-4, 4) if e.get("hit", 0.0) > 0.0 else 0.0
	var r := Rect2(Vector2(e.x - size.x / 2.0 + shake, e.y - size.y), size)
	l.draw_texture_rect(im, r, false, Color(2.4, 2.4, 2.4) if e.get("hit", 0.0) > 0.0 else Color.WHITE)
	if not seal:
		return
	l.draw_texture_rect(im, r, false, Color(1.6, 0.5, 0.3, 0.25 + 0.2 * sin(t * 4.0 + e.x)))
	var dmg: float = 1.0 - float(e.hp) / float(e.max_hp)
	if dmg > 0.0:
		var ink := Color(0.06, 0.02, 0.02, 0.9)
		l.draw_line(Vector2(e.x - 30, e.y - size.y * 0.3), Vector2(e.x - 30 + 60 * dmg, e.y - size.y * 0.3 - 20 * dmg), ink, 3.0)
		l.draw_line(Vector2(e.x + 10, e.y - size.y * 0.8), Vector2(e.x + 10 - 30 * dmg, e.y - size.y * 0.8 + 40 * dmg), ink, 3.0)


func _draw_clone(l: Layer, t: float) -> void:
	var im: Texture2D = hero_frames.run[int(t * 10.0) % 4]
	var size := im.get_size() * 3.6
	var pos: Vector2 = clone.p - Vector2(0, size.y - 6)
	var tint := Color(0.45, 1.25, 1.7, 0.55 + 0.2 * sin(t * 8.0))
	if player.face < 0:
		l.draw_set_transform(pos + Vector2(size.x / 2.0, 0), 0.0, Vector2(-1, 1))
		l.draw_texture_rect(im, Rect2(Vector2.ZERO, size), false, tint)
		l.draw_set_transform(Vector2.ZERO)
	else:
		l.draw_texture_rect(im, Rect2(pos - Vector2(size.x / 2.0, 0), size), false, tint)


func _draw_hero(l: Layer, t: float) -> void:
	if state.inv > 0.0 and int(t * 20.0) % 2 == 1:
		return
	var frames: Array = hero_frames["run" if player.moving else "idle"]
	var im: Texture2D = frames[int(player.anim) % 4]
	var size := im.get_size() * 3.6
	var pos := Vector2(player.x, player.y - size.y + 6)
	if player.face < 0:
		l.draw_set_transform(pos + Vector2(size.x / 2.0, 0), 0.0, Vector2(-1, 1))
		l.draw_texture_rect(im, Rect2(Vector2.ZERO, size), false)
		l.draw_set_transform(Vector2.ZERO)
	else:
		l.draw_texture_rect(im, Rect2(pos - Vector2(size.x / 2.0, 0), size), false)


func _draw_dark(l: Layer) -> void:
	if not state.light:
		return
	var view := _view_rect()
	var center := view.get_center()
	var cands: Array = [[0.0, Vector4(player.x, player.y - 40, float(balance.view.player_light), 1.0)]]
	var reach := view.grow(300)
	for li: Dictionary in W.lights:
		var p := Vector2(li.x, li.y)
		if reach.has_point(p):
			cands.append([p.distance_squared_to(center), Vector4(p.x, p.y, float(li.r), 0.95)])
	for e: Dictionary in W.ents:
		var p := Vector2(e.x, e.y)
		if not reach.has_point(p):
			continue
		if e.type == "portal" and e.get("active", false):
			cands.append([p.distance_squared_to(center), Vector4(p.x, p.y - 60, 330, 1.0)])
		elif e.type == "vault" and not e.get("opened", false):
			cands.append([p.distance_squared_to(center), Vector4(p.x, p.y - 80, 420, 1.0)])
		elif e.type == "vent" and e.get("burst", false):
			cands.append([p.distance_squared_to(center), Vector4(p.x, p.y - 30, 220, 0.9)])
		elif e.type == "seal" and not e.get("broken", false):
			cands.append([p.distance_squared_to(center), Vector4(p.x, p.y - 50, 200, 0.85)])
	if not clone.is_empty():
		cands.append([0.0, Vector4(clone.p.x, clone.p.y - 40, 240, 0.9)])
	for m: Dictionary in mobs:
		cands.append([m.p.distance_squared_to(center), Vector4(m.p.x, m.p.y - 40.0 * m.s, 120.0 * m.s, 0.8)])
	var lava_lights := 0
	for y in range(int(view.position.y / C), int(view.end.y / C) + 1, 2):
		for x in range(int(view.position.x / C), int(view.end.x / C) + 1, 2):
			if _cell(x, y) == 2 and lava_lights < 14:
				cands.append([1e12, Vector4((x + 1) * C, (y + 1) * C, 230, 0.75)])
				lava_lights += 1
	cands.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var lights: Array[Vector4] = []
	var max_lights := int(balance.view.max_lights)
	for c: Array in cands:
		if lights.size() >= max_lights:
			break
		lights.append(c[1])
	while lights.size() < max_lights:
		lights.append(Vector4.ZERO)
	_dark_material.set_shader_parameter("lights", lights)
	_dark_material.set_shader_parameter("light_count", mini(cands.size(), max_lights))
	_dark_material.set_shader_parameter("darkness", clampf(float(W.theme.dark) + 0.16, 0.0, 0.95))
	_dark_material.set_shader_parameter("shade_color", Color(0.05 + 0.08 * float(W.theme.grade) * 4.0, 0.01, 0.02, 1.0))
	_dark_material.set_shader_parameter("light_bands", float(balance.view.light_bands))
	l.draw_rect(view.grow(40), Color.WHITE)


# ---------- HUD ----------

## Draws the HUD into the screen-space control.
func draw_hud(h: Control) -> void:
	var size := h.size
	var th: Dictionary = W.theme
	if float(th.grade) > 0.0:
		h.draw_rect(Rect2(Vector2.ZERO, size), Color(0.55, 0.04, 0.0, float(th.grade) * 0.45))
	h.draw_texture_rect(_vignette, Rect2(Vector2.ZERO, size), false, Color(0.35 + float(th.wall_glow) * 0.4, 0.0, 0.0, float(th.vignette)))
	if state.flash > 0.0:
		h.draw_rect(Rect2(Vector2.ZERO, size), Color(0.8, 0.08, 0.08, state.flash))
	var heart: Texture2D = tex.heart
	var hs := 30.0
	var hh := hs * heart.get_height() / heart.get_width()
	for i in range(state.max_hp / 2):
		var v: int = state.hp - i * 2
		var p := Vector2(20 + (i % 8) * (hs + 4), 18 + (i / 8) * (hh + 4))
		h.draw_texture_rect(heart, Rect2(p, Vector2(hs, hh)), false, Color(1, 1, 1, 0.22))
		if v >= 2:
			h.draw_texture_rect(heart, Rect2(p, Vector2(hs, hh)), false)
		elif v == 1:
			h.draw_texture_rect_region(heart, Rect2(p, Vector2(hs / 2.0, hh)), Rect2(0, 0, heart.get_width() / 2.0, heart.get_height()))
	var row := 92.0 if state.max_hp > 16 else 60.0
	var x := 22.0
	for k in ["A", "B", "C"]:
		var alpha := 1.0 if state.keys[k] else (0.14 if state.used[k] else 0.22)
		var tint: Color = KEY_TINT[k]
		tint.a = alpha
		h.draw_texture_rect(tex.key, Rect2(x, row, 18, 34), false, tint)
		x += 28.0
	h.draw_texture_rect(tex.rune_gem, Rect2(x + 8, row + 2, 22, 32), false)
	_text(h, "× %d" % state.gems, Vector2(x + 38, row + 26), 24, INK)
	var fire := Rules.group_progress(W.ents, "feuer")
	if fire.y > 0:
		h.draw_texture_rect(tex.brazier_bowl, Rect2(x + 110, row - 4, 26, 37), false)
		_text(h, "%d/%d" % [fire.x, fire.y], Vector2(x + 144, row + 26), 24, INK)
	var line := row + 60.0
	var sk: Dictionary = state.skill
	if sk.owned:
		var clock := "%d:%02d" % [int(sk.left) / 60, int(sk.left) % 60]
		var label := ("Klon aktiv · " + clock) if sk.active else (("Q: Klon rufen · " + clock) if sk.left > 0.0 else "Klon aufgebraucht")
		_text(h, label, Vector2(22, line), 16, Color("#7fe8ff") if sk.active else (GOLD if sk.left > 0.0 else Color(INK, 0.4)))
		line += 24.0
	if not (state.buffs as Array).is_empty():
		var names: Array = (state.buffs as Array).map(func(b: String) -> String: return b.get_slice(":", 0))
		_text(h, "Segen: " + ", ".join(PackedStringArray(names)), Vector2(22, line), 16, Color(1, 0.89, 0.55, 0.85))
	_text(h, "Etage %d · %s · 1-0 Etage · Q Klon · M Karte · Esc Menü" % [state.floor, W.title], Vector2(20, size.y - 38), 16, Color(1, 0.82, 0.66, 0.6))
	var b: Dictionary = state.banner
	var ba := clampf(b.t / 0.4, 0.0, 1.0) if b.t < 2.6 else maxf(0.0, 1.0 - (b.t - 2.6) / 0.8)
	if ba > 0.0:
		_text(h, b.text, Vector2(0, 66), 32, Color(GOLD, ba), size.x)
		_text(h, String(b.sub).to_upper(), Vector2(0, 96), 16, Color(1, 0.6, 0.35, ba), size.x)
	var boss_mob: Dictionary = {}
	for m: Dictionary in mobs:
		if m.kind == "boss":
			boss_mob = m
	if not boss_mob.is_empty():
		var bw := 560.0
		var bx := size.x / 2.0 - bw / 2.0
		var by := size.y - 120.0
		h.draw_rect(Rect2(bx - 4, by - 30, bw + 8, 48), Color(0.04, 0.02, 0.02, 0.85))
		h.draw_rect(Rect2(bx, by, bw, 12), Color("#3a1210"))
		h.draw_rect(Rect2(bx, by, bw * boss_mob.hp / boss_mob.max, 12), Color("#e8432a"))
		_text(h, "%s (Platzhalter)" % W.boss.name, Vector2(0, by - 10), 16, GOLD, size.x)
	var cr: Dictionary = W.rooms[state.room]
	if cr.fight:
		var left := 0
		for m: Dictionary in mobs:
			if m.room == cr.index:
				left += 1
		_text(h, "Verriegelt · noch %d Gegner" % left, Vector2(0, 128), 16, Color("#ff6b4a"), size.x)
	var n := _nearest()
	if not n.is_empty() and state.dead <= 0.0 and not state.won:
		var sp := _to_screen(n.p, size) - Vector2(0, 70)
		var w := FONT.get_string_size(n.label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 52.0
		h.draw_rect(Rect2(sp.x - w / 2.0, sp.y - 18, w, 36), Color(0.05, 0.02, 0.03, 0.86))
		h.draw_rect(Rect2(sp.x - w / 2.0, sp.y - 18, w, 36), EMBER, false, 1.5)
		_text(h, "E", Vector2(sp.x - w / 2.0 + 14, sp.y + 6), 16, Color("#ffb36b"))
		_text(h, n.label, Vector2(sp.x - w / 2.0 + 38, sp.y + 6), 16, INK)
	var toasts: Array = state.toasts
	for i in range(toasts.size()):
		var tt: Dictionary = toasts[i]
		var ty := size.y - 40.0 - (toasts.size() - 1 - i) * 44.0 - (90.0 if not boss_mob.is_empty() else 0.0)
		var w := FONT.get_string_size(tt.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 36.0
		h.draw_rect(Rect2(size.x / 2.0 - w / 2.0, ty - 18, w, 36), Color(0.05, 0.02, 0.03, 0.88 * minf(1.0, tt.t * 2.0)))
		_text(h, tt.text, Vector2(0, ty + 6), 16, Color(INK, minf(1.0, tt.t * 2.0)), size.x)
	_text(h, "Figur und Gegner: Platzhalter", Vector2(20, size.y - 14), 16, Color(INK, 0.45))
	if state.dead > 0.0:
		h.draw_rect(Rect2(Vector2.ZERO, size), Color(0.12, 0, 0, 0.55))
	_draw_map(h, size, state.map)
	if state.won:
		h.draw_rect(Rect2(Vector2.ZERO, size), Color(0.04, 0.01, 0.02, 0.8))
		_text(h, "Die Hölle ist bezwungen" if W.final else "Etage %d geschafft" % state.floor, Vector2(0, size.y / 2.0 - 30), 32, GOLD, size.x)
		_text(h, "%d von %d Räumen erkundet · %d Runensteine · %d Herzen" % [state.visited.size(), W.rooms.size(), state.gems, state.max_hp / 2], Vector2(0, size.y / 2.0 + 16), 16, INK, size.x)
		_text(h, "E: von vorn beginnen" if W.final else "E: weiter zu Etage %d" % (state.floor + 1), Vector2(0, size.y / 2.0 + 52), 16, Color("#ffb36b"), size.x)


func _text(h: CanvasItem, text: String, pos: Vector2, font_size: int, color: Color, center_width := -1.0) -> void:
	if center_width > 0.0:
		h.draw_string(FONT, pos, text, HORIZONTAL_ALIGNMENT_CENTER, center_width, font_size, color)
	else:
		h.draw_string(FONT, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _to_screen(world: Vector2, screen: Vector2) -> Vector2:
	return (world - camera.position) * camera.zoom + screen / 2.0


func _door_color(d: Dictionary) -> Color:
	if W.rooms[d.a].fight or W.rooms[d.b].fight:
		return Color("#d8382a")
	if d.kind == "lock" and not d.unlocked:
		return KEY_COLOR[d.key]
	if d.kind == "puzzle" and _door_closed(d):
		return Color("#f2c14e")
	if d.kind == "boss" and _door_closed(d):
		return Color("#d8382a")
	return Color("#7a5552")


func _draw_map(h: Control, screen: Vector2, big: bool) -> void:
	var known := Rules.known_rooms(W.doors, state.visited)
	var s: float = minf((screen.x - 60.0) / W.cols, (screen.y - 110.0) / W.rows) if big else minf(250.0 / W.cols, 170.0 / W.rows)
	var mw: float = W.cols * s
	var mh: float = W.rows * s
	var origin := Vector2((screen.x - mw) / 2.0, (screen.y - mh) / 2.0 + 10.0) if big else Vector2(screen.x - mw - 16.0, 16.0)
	if big:
		h.draw_rect(Rect2(Vector2.ZERO, screen), Color(0.03, 0.01, 0.02, 0.93))
		_text(h, "%s · Etage %d" % [W.title, state.floor], Vector2(0, 40), 32, GOLD, screen.x)
	else:
		h.draw_rect(Rect2(origin - Vector2(8, 8), Vector2(mw, mh) + Vector2(16, 16)), Color(0.04, 0.02, 0.02, 0.8))
	h.draw_set_transform(origin, 0.0, Vector2(s, s))
	for d: Dictionary in W.doors:
		if not (known.has(d.a) and known.has(d.b)) or (d.kind == "secret" and not d.broken):
			continue
		var hx := 0.5 if d.dir == "h" else 0.0
		var vy := 0.5 if d.dir == "v" else 0.0
		h.draw_rect(Rect2(d.x0 - hx, d.y0 - vy, d.x1 - d.x0 + 1 + hx * 2, d.y1 - d.y0 + 1 + vy * 2), _door_color(d))
	for r: Dictionary in W.rooms:
		if not known.has(r.index):
			continue
		var seen: bool = state.visited.has(r.index)
		var here: bool = r.index == state.room
		var fill := Color("#7a2e1c") if here else (Color("#3d262a") if seen and r.cleared else (Color("#5a1f1a") if seen else Color(0.18, 0.11, 0.13, 0.45)))
		for rect: Rect2 in minimap[r.index].rects:
			h.draw_rect(rect, fill)
		h.draw_multiline(minimap[r.index].edges, EMBER if here else (Color("#9a6a5c") if seen else Color("#6d4c52")), (2.4 if here else 1.2) / s)
	h.draw_set_transform(Vector2.ZERO)
	var isz := maxf(24.0, s * 4.5) if big else 13.0
	for r: Dictionary in W.rooms:
		if not known.has(r.index):
			continue
		var seen: bool = state.visited.has(r.index)
		var icon: String = r.icon
		if icon == "" and seen:
			for e: Dictionary in W.ents:
				if e.type == "brazier" and e.room == r.index and not e.get("lit", false):
					icon = "brazier_bowl"
			for e: Dictionary in breakables:
				if icon == "" and e.room == r.index and not e.get("broken", false):
					icon = "demon_plate" if e.type == "seal" else "skull_heap"
		if icon == "" or (not seen and r.type != "boss"):
			continue
		var im: Texture2D = tex[icon]
		var c := origin + Vector2(r.bx + r.bw / 2.0, r.by + r.bh / 2.0) * s
		var sz := Vector2(isz, isz * im.get_height() / im.get_width())
		h.draw_texture_rect(im, Rect2(c - sz / 2.0, sz), false, KEY_TINT.get(r.icon_key, Color.WHITE))
		var room_w: float = r.bw * s
		if big and FONT.get_string_size(r.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x < room_w:
			_text(h, r.name, Vector2(c.x - room_w / 2.0, c.y + isz * 0.9), 16, INK, room_w)
	if big:
		_text(h, "Hell: besucht · Türen rot: verriegelt · farbig: Schlüssel · gelb: Rätsel · M schließt", Vector2(0, screen.y - 12), 16, Color("#b89c8e"), screen.x)
	h.draw_circle(origin + Vector2(player.x, player.y - 20) / C * s, 6.0 if big else 3.0, Color("#fff1c2"))
