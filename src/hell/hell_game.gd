extends Node2D
## Hell-Dungeon mode (single player): plays the ten baked hell floors from
## assets/data/hell_floors.json. Combat rooms lock until every enemy is down,
## colour keys open their own gates, spread fire braziers open the vault,
## sequence plates conjure a reward chest, a skull heap shot three times opens
## a secret corridor, demon seals bless the hero or release demons, pits throw
## the hero back to the start, the floor-9 boss grants the clone skill (Q), and
## the portal leads one floor deeper.
## The hero is a placeholder. Without a theme of their own enemies, monsters, bosses
## and Ignaroth run in hell_monsters.gd; values come from hell_balance.json and
## hell_monsters.json.

const FloorData = preload("res://src/hell/hell_floor_data.gd")
const Walls = preload("res://src/hell/hell_walls.gd")
const Rules = preload("res://src/hell/hell_rules.gd")
const Monsters = preload("res://src/hell/hell_monsters.gd")
const MobRules = preload("res://src/hell/mob_rules.gd")
const BossKit = preload("res://src/hell/boss_kit.gd")
const HeroKit = preload("res://src/hell/hero_kit.gd")
const RelicKit = preload("res://src/hell/relic_kit.gd")
const CardKit = preload("res://src/hell/card_kit.gd")
const FrostHud = preload("res://src/hell/frost_hud.gd")
const HEART := "res://assets/sprites/0x72/ui_heart_%s.png"
const Sfx = preload("res://src/vfx/sfx.gd")
const Music = preload("res://src/audio/music.gd")
const DARKNESS_SHADER := preload("res://assets/shaders/canvas_vfx_darkness.gdshader")
const FONT := preload("res://assets/fonts/pixel_operator8.ttf")
const BALANCE_PATH := "res://assets/data/hell_balance.json"
const HERO := "res://assets/sprites/0x72/%s_%s_anim_f%d.png"
const WEAPON := "res://assets/sprites/0x72/%s.png"
const MENU_SCENE := "res://src/main.tscn"
const C := 96.0
const CHUNK := Vector2i(14, 11)
## The hell look and wording. A theme file (theme_path, e.g. assets/data/frost_theme.json)
## overrides any top-level key; colours are "#rrggbb" or [r, g, b(, a)] (above 1 brightens).
const THEME_DEFAULT := {
	"floors": "res://assets/data/hell_floors.json", "sprites": "res://assets/sprites/hell/", "balance": BALANCE_PATH,
	"pixel": false, "hero_scale": 3.6, "key_in_chest": false, "placeholder_note": true,
	"liquid": {"hurt": true, "slow": -1.0, "slide": false, "grip": 1.0},
	"keys": {
		"A": {"name": "Glutschlüssel", "hint": "fällt in einem Seitenraum vor dem Tor.", "color": "#ff8a3c", "tint": [1, 1, 1], "sprite": "key"},
		"B": {"name": "Knochenschlüssel", "hint": "liegt auf einem Altar oder fällt in einem Seitenraum.", "color": "#e8dccb", "tint": [1.55, 1.5, 1.4], "sprite": "key"},
		"C": {"name": "Dämonenschlüssel", "hint": "fällt in einem Kampfraum nahe dem Bosstor.", "color": "#b07cff", "tint": [0.75, 0.5, 1.7], "sprite": "key"}},
	"words": [],
	"colors": {"ink": "#f1e4d8", "accent": "#ff6b2c", "gold": "#ffd2a8", "sub": [1, 0.6, 0.35], "warn": "#ff6b4a", "prompt_key": "#ffb36b",
		"shot_glow": [1, 0.55, 0.2, 0.45], "shot_core": [1, 0.95, 0.75], "eshot_glow": [0.8, 0.1, 0.08, 0.5], "eshot_core": [1, 0.75, 0.7],
		"ember": "#ffb347", "ember_big": "#ff7a2a", "ember_gold": "#ffe28a", "shade": [0.05, 0.01, 0.02], "shade_grade": [0.32, 0, 0],
		"grade": [0.55, 0.04, 0.0], "vignette": [0.35, 0, 0], "vignette_glow": [0.4, 0, 0], "boss_back": "#3a1210", "boss_bar": "#e8432a",
		"map_here": "#7a2e1c", "map_cleared": "#3d262a", "map_seen": "#5a1f1a", "map_edge_seen": "#9a6a5c", "map_edge": "#6d4c52", "door": "#7a5552",
		"mob_gross": [0.9, 0.6, 0.5], "mob_spucker": [0.75, 0.55, 1.6], "mob_boss": [1.2, 0.55, 0.45], "mob_boss_final": [0.6, 0.45, 1.6]},
}

## Floor to open first; set before the node enters the tree (debug starts).
@export var start_floor := 1
## Debug start right inside the boss room of start_floor; the fight begins at once.
@export var start_at_boss := false
## Theme JSON over THEME_DEFAULT; empty keeps the hell look.
@export var theme_path := ""
## Hero class from theme.classes (menu choice); empty takes theme.default_class.
@export var class_id := ""

var theme: Dictionary = {}
var key_name: Dictionary = {}
var key_hint: Dictionary = {}
var key_color: Dictionary = {}
var key_tint: Dictionary = {}
var key_sprite: Dictionary = {}
var ink := Color.WHITE
var accent := Color.WHITE
var gold := Color.WHITE
## The chosen class (theme.classes entry) and its weapon; empty in hell.
var hero: Dictionary = {}
var weapon: Dictionary = {}
var weapon_tex: Texture2D
var arrow_tex: Texture2D
## The sword's last swing for drawing: angle, time left.
var swing := {"a": 0.0, "t": 0.0}

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
## Telegraphed boss areas: icicle targets, chill fields, landing marks, safe circles.
var zones: Array = []
## Class skills (hero_skills.json, scaled) and their running parts: a held skill,
## a dash, short effects, the level-up flash, gravity walls and bars.
var skills: Array = []
var hold: Dictionary = {}
var dash: Dictionary = {}
var fx: Array = []
var levelfx: Dictionary = {}
var gwalls: Array = []
var gbars: Array = []
var bar_drag: Dictionary = {}
## Fixed aim point for skills instead of the mouse (tests, debug); null = mouse.
var aim_at: Variant = null
var relic_tex: Texture2D
## Relic summons and timed relic blows (rock lifts, rock spikes, meteors, quakes).
var allies: Array = []
var pending: Array = []
## Hearts of the HUD (0x72 full, half, empty).
var hearts: Dictionary = {}
var sfx: Node
var music: Node
var _music_state := ""
var breakables: Array = []
var pits: Array = []
var clone: Dictionary = {}
var solid_grid: Dictionary = {}
var door_at: Dictionary = {}
var minimap: Array = []
var camera: Camera2D
var actors: Layer
var dark: Layer
## Additive layer for attack glows and enemy shots of the hell monsters.
var glow: Layer
## The hell monsters (hell_monsters.gd); null in a themed world with its own enemies.
var monsters: Monsters
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
	_load_theme()
	balance = JSON.parse_string(FileAccess.get_file_as_string(theme.balance))
	floors_raw = FloorData.load_all(theme.floors)
	var sprites: String = theme.sprites
	var names: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(sprites + "manifest.json"))
	for n: String in names:
		tex[n] = load(sprites + n + ".png")
	var classes: Dictionary = theme.get("classes", {})
	if not classes.has(class_id):
		class_id = str(theme.get("default_class", ""))
	hero = classes.get(class_id, {})
	weapon = hero.get("weapon", {})
	if not weapon.is_empty():
		weapon_tex = load(WEAPON % weapon.sprite)
		arrow_tex = load(WEAPON % "weapon_arrow")
	for kind in ["idle", "run"]:
		var frames: Array = []
		for f in range(4):
			frames.append(load(HERO % [hero.get("sprite", "knight_m"), kind, f]))
		hero_frames[kind] = frames
	skills = HeroKit.load_skills(self, class_id)
	for k in ["full", "half", "empty"]:
		hearts[k] = load(HEART % k)
	if not (theme.get("sounds", {}) as Dictionary).is_empty():
		sfx = Sfx.new()
		add_child(sfx)
	if theme.get("music", false):
		music = Music.new()
		add_child(music)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if theme.pixel else CanvasItem.TEXTURE_FILTER_LINEAR
	camera = Camera2D.new()
	camera.zoom = Vector2.ONE * float(balance.view.base_width) / float(balance.view.width)
	add_child(camera)
	camera.make_current()
	if not theme.has("mobs"):
		monsters = Monsters.new(self, balance.monsters)
	actors = _layer("actors", 10)
	glow = _layer("glow", 11)
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = add
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
	if start_at_boss:
		enter_boss_room()


## THEME_DEFAULT with the theme file's keys on top, then the key and colour lookups.
func _load_theme() -> void:
	theme = THEME_DEFAULT.duplicate(true)
	if theme_path != "" and FileAccess.file_exists(theme_path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(theme_path))
		if parsed is Dictionary:
			for k: String in parsed:
				if parsed[k] is Dictionary and theme.get(k) is Dictionary:
					(theme[k] as Dictionary).merge(parsed[k], true)
				else:
					theme[k] = parsed[k]
	for k: String in theme.keys:
		var spec: Dictionary = theme.keys[k]
		key_name[k] = spec.name
		key_hint[k] = spec.hint
		key_color[k] = _color(spec.color)
		key_tint[k] = _color(spec.tint)
		key_sprite[k] = spec.sprite
	ink = col("ink")
	accent = col("accent")
	gold = col("gold")


static func _color(v: Variant) -> Color:
	if v is String:
		return Color(v)
	var a: Array = v
	return Color(a[0], a[1], a[2], a[3] if a.size() > 3 else 1.0)


## Plays the sound the theme maps to a game event (theme.sounds); silent without sounds.
func _sound(event: String) -> void:
	var name := str(theme.get("sounds", {}).get(event, ""))
	if name != "":
		_sound_raw(name)


## Plays an audio_sfx.json event directly (skills name their own).
func _sound_raw(name: String) -> void:
	if sfx != null and name != "" and sfx.has_effect(name):
		sfx.play(name)


## The weapon damage the hero's multiples are measured against.
func base_damage() -> float:
	return maxf(0.01, float(weapon.get("damage", 1.0)))


## A dash ended (charge with shockwave card, hammer leap): its landing blow.
func on_dash_land(what: String) -> void:
	if what == "shockwave":
		var s: Dictionary = theme.cards.swordsman.filter(func(c: Dictionary) -> bool: return c.id == "shockwave")[0]
		RelicKit._area(self, Vector2(player.x, player.y), float(s.radius), float(s.damage), 0.0)
		for m: Dictionary in mobs:
			if Vector2(player.x, player.y).distance_to(m.p) < float(s.radius) + m.r:
				m.stun = maxf(float(m.get("stun", 0.0)), float(s.stun))
		fx.append({"kind": "quake", "p": Vector2(player.x, player.y), "r": float(s.radius), "t": 0.35, "max": 0.35})
		return
	RelicKit.land(self, what)


## The relic's look: the wielded one, else the run's (for its shrine).
func _relic_texture() -> void:
	var item := str(state.relic) if str(state.relic) != "" else str(state.get("relic_item", ""))
	relic_tex = tex.get(str(theme.get(item, {}).get("sprite", "")), null) if item != "" else null


## True while the hero wields a found relic instead of the class skills (gravity staff).
func relic_on() -> bool:
	return bool(state.get("relic_on", false)) and str(state.get("relic", "")) != ""


## A theme colour by name.
func col(name: String) -> Color:
	return _color(theme.colors[name])


## The theme's wording: hell phrases swapped for the theme's own (theme.words pairs).
func say(text: String) -> String:
	for pair: Array in theme.words:
		text = text.replace(pair[0], pair[1])
	return text


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
	if theme.key_in_chest:
		# keys on the floor (key rooms) wait in a chest instead; dropped keys stay drops
		for e: Dictionary in W.ents:
			if e.type == "key":
				e.type = "chest"
				e.loot = {"gems": 0, "key": e.key}
				e.magic = false
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
	var start_hp := int(hero.get("hp", balance.player.hp))
	var keep := {"hp": start_hp, "max_hp": start_hp, "gems": 0, "dmg": float(weapon.get("damage", 1.0)),
		"rate": float(weapon.get("cooldown", balance.shot.cooldown)), "speed_mul": 1.0, "range": float(weapon.get("life", balance.shot.life)), "buffs": [],
		"skill": {"owned": false, "active": false, "left": float(balance.clone.duration)},
		"level": 1, "exp": 0, "skill_cd": {}, "relic": "", "relic_on": false, "upgrades": {}, "offer": [], "cards_due": 0,
		"relic_floor": 0, "relic_item": ""}
	if carry and not state.is_empty():
		keep = {"hp": state.hp, "max_hp": state.max_hp, "gems": state.gems, "dmg": state.dmg, "rate": state.rate,
			"speed_mul": state.speed_mul, "range": state.range, "buffs": state.buffs, "skill": state.skill,
			"level": state.level, "exp": state.exp, "skill_cd": {}, "relic": state.relic, "relic_on": state.relic_on, "upgrades": state.upgrades,
			"offer": state.offer, "cards_due": state.cards_due, "relic_floor": state.relic_floor, "relic_item": state.relic_item}
		keep.skill.active = false
	state = {"floor": n, "keys": {"A": false, "B": false, "C": false}, "used": {"A": false, "B": false, "C": false},
		"visited": {start.index: true}, "room": start.index, "banner": {"text": W.title, "sub": "Etage %d · %s" % [n, W.circle], "t": 0.0},
		"toasts": [], "inv": 0.0, "dead": 0.0, "map": false, "light": state.get("light", true), "t": 0.0, "won": false, "won_t": 0.0,
		"cool": 0.0, "flash": 0.0, "chill": 0.0, "storm": false, "rage": 0.0, "boss_dead": false,
		"shake": 0.0, "white": 0.0, "slow": 0.0, "pull": null}
	state.merge(keep)
	if not carry:
		RelicKit.choose_run(self)
	RelicKit.place(self)
	_relic_texture()
	mobs = []
	shots = []
	eshots = []
	zones = []
	if monsters != null:
		monsters.reset()
	allies = []
	pending = []
	hold = {}
	dash = {}
	fx = []
	gwalls = []
	gbars = []
	embers = []
	clone = {}
	breakables = W.ents.filter(func(e: Dictionary) -> bool: return e.type == "seal" or e.type == "skullheap")
	pits = W.ents.filter(func(e: Dictionary) -> bool: return e.type == "pit")
	for e: Dictionary in breakables:
		e.max_hp = int(e.hp)
	_respawn()
	camera.position = Vector2(player.x, player.y)


## Debug jump: puts the hero inside the boss room, two cells past the gate it
## is reached through, with that gate open. The fight starts on the next frame.
func enter_boss_room() -> void:
	var boss := _room_of_type("boss")
	var gate: Dictionary = {}
	for i: int in boss.doors:
		var d: Dictionary = W.doors[i]
		if d.kind != "boss" and d.kind != "secret":
			gate = d
			if d.kind == "lock":
				break
	if gate.get("kind", "") == "lock":
		gate.unlocked = true
		state.used[gate.key] = true
	var at := Vector2((boss.bx + boss.bw / 2.0) * C, (boss.by + boss.bh / 2.0) * C)
	if not gate.is_empty():
		var door := Vector2(gate.cx, gate.cy)
		var best := INF
		for c: Vector2i in boss.cells:
			var p := Vector2((c.x + 0.5) * C, (c.y + 0.8) * C)
			var score := absf(p.distance_to(door) - 2.5 * C)
			if W.grid[c.y * W.cols + c.x] == 1 and score < best and _fully_inside(boss, p.x, p.y) and not box_blocked(_player_box(p.x, p.y).grow(48)):
				best = score
				at = p
	player.x = at.x
	player.y = at.y
	state.room = boss.index
	state.visited[boss.index] = true
	state.banner = {"text": boss.name, "sub": "Debug-Start beim Boss", "t": 0.0}
	camera.position = Vector2(player.x, player.y)


func _room_of_type(kind: String) -> Dictionary:
	for r: Dictionary in W.rooms:
		if r.type == kind:
			return r
	return W.rooms[0]


func _respawn() -> void:
	var s := _room_of_type("start")
	var spawn: Array = s.spawn if s.spawn != null else [s.bw / 2.0, s.bh / 2.0]
	player = {"x": (s.bx + float(spawn[0])) * C, "y": (s.by + float(spawn[1])) * C, "face": 1.0, "anim": 0.0, "moving": false, "vel": Vector2.ZERO, "aim": Vector2.RIGHT}


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
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and not (state.get("offer", []) as Array).is_empty():
		var picked := FrostHud.card_at(self, get_viewport().get_mouse_position(), get_viewport_rect().size)
		if picked >= 0:
			CardKit.choose(self, picked)
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and relic_on() and RelicKit.wielded(self).has("ball"):
		# the gravity bar: drag with the right mouse, release to set it
		if event.pressed:
			bar_drag = {"a": get_global_mouse_position()}
		elif not bar_drag.is_empty():
			HeroKit.gravity_bar(self, bar_drag.a, get_global_mouse_position())
			bar_drag = {}
		return
	if not (event is InputEventKey) or event.echo:
		return
	var skill_keys := {KEY_1: "1", KEY_2: "2", KEY_3: "3", KEY_4: "4"}
	if not skills.is_empty() and skill_keys.has(event.keycode):
		var key: String = skill_keys[event.keycode]
		if event.pressed:
			if not RelicKit.press(self, key):
				HeroKit.press(self, key)
		elif not RelicKit.release(self, key):
			HeroKit.release(self, key)
		return
	var card_keys := {KEY_7: 0, KEY_8: 1, KEY_9: 2}
	if event.pressed and card_keys.has(event.keycode) and not (state.get("offer", []) as Array).is_empty():
		CardKit.choose(self, card_keys[event.keycode])
		return
	if not event.pressed:
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
		KEY_T:
			if str(state.relic) != "":
				state.relic_on = not state.relic_on
				_relic_texture()
				_toast(("%s in der Hand." % theme[state.relic].name) if state.relic_on else ("%s in der Hand." % weapon.get("name", "Waffe")))
		KEY_C, KEY_TAB:
			state.status = not state.get("status", false)
		KEY_PAGEUP:
			# debug: one level up
			if not skills.is_empty():
				HeroKit.gain(self, HeroKit.need(theme.leveling, int(state.level)) - int(state.exp))
		_:
			var k: int = event.keycode
			if not skills.is_empty() and k >= KEY_F1 and k <= KEY_F10:
				# debug floor jumps keep the hero's progress where 1-4 are skills
				load_floor(k - KEY_F1 + 1, true)
			elif skills.is_empty() and k >= KEY_0 and k <= KEY_9:
				load_floor(10 if k == KEY_0 else k - KEY_0, false)


func _axis(neg: Key, pos: Key) -> float:
	return (1.0 if Input.is_physical_key_pressed(pos) else 0.0) - (1.0 if Input.is_physical_key_pressed(neg) else 0.0)


# ---------- gameplay ----------

func _toast(text: String) -> void:
	state.toasts.append({"text": say(text), "t": 3.6})
	if state.toasts.size() > 3:
		state.toasts.pop_front()


## Costs the hero n half hearts unless he is still invulnerable from the last hit.
func _hurt(why: String, n := 1) -> void:
	if state.inv > 0.0 or state.dead > 0.0:
		return
	state.hp = maxi(0, state.hp - n)
	state.inv = float(balance.player.invulnerable)
	state.flash = 0.25
	_sound("hurt")
	_sound("hurt_voice")
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
			"relic":
				if not e.get("taken", false):
					var label := "Versiegelt: die vier Platten in ihrer Reihenfolge betreten"
					if W.groups[e.seal].get("solved", false):
						label = ("%s nehmen" % theme[e.item].name) if HeroKit.can_wield(self, e.item) else "Nur ein Magier kann diesen Stab führen"
					out.append({"e": e, "label": label, "p": Vector2(e.x, e.y - 30), "r": 150.0})
	for d: Dictionary in W.doors:
		var p := Vector2(d.cx, d.cy)
		if d.kind == "lock" and not d.unlocked:
			out.append({"e": d, "label": ("%s benutzen" if state.keys[d.key] else "Verschlossen: %s fehlt") % key_name[d.key], "p": p, "r": 190.0})
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
			"relic":
				if not W.groups[e.seal].get("solved", false) or not HeroKit.can_wield(self, e.item):
					_sound("no_cooldown")
					return
				e.taken = true
				state.relic = e.item
				state.relic_on = true
				_relic_texture()
				_burst(Vector2(e.x, e.y - 50), 60, true)
				_sound("relic")
				var names: Array = (theme[e.item].skills as Array).map(func(s: Dictionary) -> String: return "%s (%s, ab LV %d)" % [s.short, s.key, int(s.unlock)])
				state.banner = {"text": str(theme[e.item].name), "sub": " · ".join(PackedStringArray(names)) + " · T wechselt", "t": 0.0}
			"chest":
				_sound("chest")
				if e.loot.has("key"):
					e.state = "empty"
					state.keys[e.loot.key] = true
					_burst(Vector2(e.x, e.y - 40), 30, true)
					_toast("Truhe geöffnet: %s genommen!" % key_name[e.loot.key])
				elif e.get("state", "") == "":
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
					_sound("stairs")
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
			_sound("gate_open")
			_toast("Das Tor öffnet sich.")
		else:
			_sound("gate_locked")
			_toast("%s %s" % [key_name[e.key], key_hint[e.key]])


func _open_secret(d: Dictionary) -> void:
	d.broken = true
	_sound("secret")
	for c: Vector2i in d.cells:
		W.grid[c.y * W.cols + c.x] = 1
	walls = Walls.build(W.grid, W.cols, W.rows, C)
	for node: Layer in _chunk_nodes:
		node.queue_redraw()


func _solve_group(group: String) -> void:
	var g: Dictionary = W.groups[group]
	g.solved = true
	_sound("puzzle_solved")
	if g.get("reward", "") == "relic":
		for e: Dictionary in W.ents:
			if e.type == "relic" and e.seal == group:
				_burst(Vector2(e.x, e.y - 50), 50, true)
		_toast("Das Gravitationssiegel bricht. Ein Stab liegt frei!")
		return
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
	if state.cool > 0.0 or dir == Vector2.ZERO or not hold.is_empty():
		return
	state.cool = float(state.rate) * HeroKit.rate_scale(self) * CardKit.rate_mult(self)
	player.aim = dir.normalized()
	if absf(dir.x) > 0.01:
		player.face = signf(dir.x)
	if RelicKit.attack(self, dir.normalized()):
		return
	if weapon.get("type", "") == "melee":
		_swing(dir.normalized())
		_sound("swing")
		return
	var v := dir.normalized() * float(weapon.get("speed", balance.shot.speed))
	shots.append({"p": Vector2(player.x, player.y - 40), "v": v, "t": float(state.range), "kind": str(weapon.get("shot", "")), "splash": float(weapon.get("splash", 0.0)), "hits": []})
	_sound("shot_arrow" if weapon.get("shot", "") == "arrow" else "shot_magic")


## Sword: hits every enemy and breakable within reach whose direction lies inside the arc.
func _swing(dir: Vector2) -> void:
	var from := Vector2(player.x, player.y - 40)
	var reach := float(weapon.reach)
	var half := float(weapon.arc) / 2.0
	swing = {"a": dir.angle(), "t": 0.16}
	for m: Dictionary in mobs:
		var to: Vector2 = m.p - Vector2(0, m.cy) - from
		if _hittable(m) and to.length() < reach + m.r and absf(angle_difference(dir.angle(), to.angle())) <= half:
			_damage_mob(m, dir * 600.0)
	for e: Dictionary in breakables:
		var to := Vector2(e.x, e.y - 40) - from
		if not e.get("broken", false) and to.length() < reach + 40.0 and absf(angle_difference(dir.angle(), to.angle())) <= half:
			_hit_breakable(e, Vector2(e.x, e.y - 40))


## Deals the hero's damage (times mult, e.g. a skill's multiple); a shield bearer
## facing the hit blocks it (returns false).
func _damage_mob(m: Dictionary, push: Vector2, mult := 1.0) -> bool:
	var def: Dictionary = m.def
	var arc := float(def.shield_arc) if def.get("behavior", "") == "shield" else float(m.get("kit", {}).get("shield_arc", 0.0))
	if arc > 0.0 and push != Vector2.ZERO and MobRules.shield_blocks(m.face, push, arc):
		_burst(m.p - Vector2(0, m.cy), 6, true)
		_sound("block")
		return false
	var factor := BossKit.damage_factor(self, m) if m.has("kit") else 1.0
	if factor <= 0.0:
		return false
	m.hp -= float(state.dmg) * factor * mult * HeroKit.crit(self) * CardKit.damage_mult(self)
	_sound("hit_" + str(def.get("material", "void")))
	m.hit = 0.12
	# kit bosses stand firm: no knockback
	m.k = Vector2.ZERO if m.has("kit") else push * (0.05 if m.kind == "boss" else 0.25)
	return true


## True when an enemy can take a hit now: grown in, not faded out, and (hell monsters)
## not arriving, flying, burrowed, transforming or dying.
func _hittable(m: Dictionary) -> bool:
	return m.spawn <= 0.0 and float(m.get("alpha", 1.0)) > 0.5 and (monsters == null or not monsters.immune(m))


## An enemy kind's values: the theme's own kinds first (theme.mobs), else hell_balance.json.
func _mob_def(kind: String) -> Dictionary:
	var themed: Dictionary = theme.get("mobs", {})
	return themed[kind] if themed.has(kind) else balance.mobs[kind]


func _spawn_mob(room: int, pos: Vector2, kind: String) -> void:
	var def := _mob_def(kind)
	var diff: Dictionary = W.diff
	var hp: float = float(W.boss.hp) if kind == "boss" else round(float(def.hp) * float(diff.hp))
	var scale := float(def.get("scale", 1.0))
	if kind == "boss" and (W.boss.get("mini", false) or W.final):
		scale *= 1.25 if W.final else 1.05
	# themed look: the kind's sprite, or the floor's guardian (theme.bosses) for the boss
	var look: Dictionary = theme.get("bosses", {}).get(str(state.floor), {}) if kind == "boss" else (def if def.has("sprite") else {})
	var draw_scale := float(look.get("scale", 1.0))
	var cy := 30.0 * scale
	if look.has("sprite") and tex.has(MobRules.frame_name(look, 0)):
		cy = (tex[MobRules.frame_name(look, 0)] as Texture2D).get_height() * draw_scale * 0.5
	mobs.append({"room": room, "kind": kind, "p": pos, "hp": hp, "max": hp, "sp": float(def.speed) * float(diff.speed),
		"s": scale, "r": float(def.radius), "seed": randf() * 9.0, "k": Vector2.ZERO, "hit": 0.0, "spawn": 0.5,
		"summon": 2.5, "shoot": 1.0 + randf() * 2.0, "ring_t": float(W.boss.get("ring", 0.0)), "spin": 0.0,
		"def": def, "look": look, "ds": draw_scale, "cy": cy, "face": Vector2.RIGHT,
		"dash": 0.0, "dash_t": float(def.get("dash_every", 0.0)) * randf(), "dash_dir": Vector2.ZERO})
	var kits: Dictionary = theme.get("boss_kits", {})
	if kind == "boss" and kits.has(str(state.floor)):
		var m: Dictionary = mobs[mobs.size() - 1]
		BossKit.setup(m, kits[str(state.floor)], hp)
		var first := MobRules.frame_name(m.look, 0)
		if tex.has(first):
			m.cy = (tex[first] as Texture2D).get_height() * float(m.look.get("scale", 1.0)) * 0.5
			m.ds = float(m.look.get("scale", 1.0))


func _start_fight(r: Dictionary) -> void:
	r.fight = true
	var me := Vector2(player.x, player.y)
	var cells: Array = []
	for c: Vector2i in r.cells:
		var p := Vector2((c.x + 0.5) * C, (c.y + 0.7) * C)
		if W.grid[c.y * W.cols + c.x] == 1 and p.distance_to(me) > 4.5 * C and not _near_door(r, p, 2.0) and solid_grid.get(c.y * W.cols + c.x, []).is_empty():
			cells.append(p)
	cells.shuffle()
	if monsters != null:
		monsters.populate(r, cells)
		_sound("boss_intro" if r.type == "boss" else "fight_start")
		return
	var count: int = int(r.mobs if r.mobs > 0 else 3) + int(W.diff.extra)
	var rolls: Array = []
	for k in range(count):
		rolls.append(randf())
	var themed := MobRules.pick_kinds(theme.get("roster", []), state.floor, rolls)
	for k in range(mini(count, cells.size())):
		var kind := "glut"
		if not themed.is_empty():
			kind = themed[k]
		elif W.diff.get("shooters", false) and k % 4 == 1:
			kind = "spucker"
		elif k % 3 == 2:
			kind = "gross"
		_spawn_mob(r.index, cells[k], kind)
	if r.type == "boss":
		_spawn_mob(r.index, Vector2((r.bx + r.bw / 2.0) * C, (r.by + r.bh / 2.0 + 1.0) * C), "boss")
		_toast("%s erwacht. Die Tore sind verriegelt." % W.boss.name)
		_sound("boss_intro")
	else:
		_toast("Die Gitter fallen. Besiege alle Gegner.")
		_sound("fight_start")


func _clear_room(r: Dictionary, at: Vector2) -> void:
	r.fight = false
	r.cleared = true
	# a room cleared a second time (seal demons) gives no second key or reward
	var again: bool = r.get("rewarded", false)
	r.rewarded = true
	_sound("boss_dead" if r.type == "boss" else "room_clear")
	if r.drop != "" and not again:
		_drop("key", r.index, at, {"key": r.drop})
		_toast("Raum gesäubert. %s gefallen!" % key_name[r.drop])
	elif r.type == "boss":
		state.boss_dead = true
		eshots = []
		zones = []
		state.storm = false
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
		var at := Vector2(e.x + (k - (n - 1) / 2.0) * 90.0, e.y + 60.0 + (50.0 if k == 1 else 0.0))
		if monsters != null:
			monsters.spawn(r.index, at, String(balance.monsters.seal_demon))
		else:
			_spawn_mob(r.index, at, String(cfg.demon_kind))
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
	zones = []
	state.storm = false
	if monsters != null:
		monsters.reset()
	state.pull = null
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
		if _hittable(m) and m.p.distance_to(clone.p) < bd:
			bd = m.p.distance_to(clone.p)
			best = m
	if not best.is_empty() and clone.cool <= 0.0:
		clone.cool = float(cfg.fire_every)
		var from: Vector2 = clone.p - Vector2(0, 40)
		var aim: Vector2 = best.p - Vector2(0, best.cy) - from
		shots.append({"p": from, "v": aim.normalized() * float(balance.shot.speed), "t": float(state.range)})


func _process(delta: float) -> void:
	var dt := minf(delta, 0.05)
	_update(dt)
	actors.queue_redraw()
	glow.queue_redraw()
	dark.queue_redraw()
	hud.queue_redraw()


func _update(dt: float) -> void:
	state.t += dt
	for k in ["inv", "flash", "cool", "chill", "slow"]:
		state[k] = maxf(0.0, state[k] - dt)
	state.shake = maxf(0.0, state.shake - dt * 30.0)
	state.white = maxf(0.0, state.white - dt * 1.6)
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
			zones = []
			state.storm = false
			if monsters != null:
				monsters.reset()
			state.pull = null
			_respawn()
			state.hp = state.max_hp
			state.inv = 1.2
			state.room = _room_of_type("start").index
		return
	swing.t = maxf(0.0, swing.t - dt)
	HeroKit.update(self, dt)
	RelicKit.update(self, dt)
	if not (state.get("offer", []) as Array).is_empty():
		state.offer_t = float(state.get("offer_t", 0.0)) + dt
	_update_music()
	_update_player(dt)
	if state.dead > 0.0:
		return
	_update_clone(dt)
	_update_shots(dt)
	_update_mobs(dt)
	_update_zones(dt)
	_update_hazards(dt)
	_update_rooms()
	_update_embers(dt)
	_update_camera(dt)


## Explore, combat or boss music by what happens in the hero's room.
func _update_music() -> void:
	if music == null:
		return
	var want := "explore"
	var r: Dictionary = W.rooms[state.room]
	if r.fight:
		want = "boss" if r.type == "boss" else "combat"
	if want != _music_state:
		_music_state = want
		music.request(want)


func _update_player(dt: float) -> void:
	var move := Vector2(_axis(KEY_A, KEY_D), _axis(KEY_W, KEY_S))
	if not dash.is_empty():
		move = Vector2.ZERO
	var here := _cell(int(floor(player.x / C)), int(floor((player.y - 6.0) / C)))
	var liquid: Dictionary = theme.liquid
	var slow: float = float(balance.player.lava_slow) if float(liquid.slow) < 0.0 else float(liquid.slow)
	var chill := float(theme.get("chill_speed", 1.0)) if state.chill > 0.0 else 1.0
	var speed := float(hero.get("speed", balance.player.speed)) * float(state.speed_mul) * chill * HeroKit.move_scale(self) * CardKit.speed_mult(self) * (slow if here == 2 else 1.0) * (0.5 if state.slow > 0.0 else 1.0)
	player.moving = move != Vector2.ZERO
	var want := move.normalized() * speed if player.moving else Vector2.ZERO
	if here == 2 and liquid.slide:
		# glaze ice: the hero keeps sliding; grip = share of the old speed left after one second
		player.vel = (player.vel as Vector2).lerp(want, 1.0 - pow(float(liquid.grip), dt))
	else:
		player.vel = want
	var v: Vector2 = player.vel * dt
	if v != Vector2.ZERO:
		if not box_blocked(_player_box(player.x + v.x, player.y)):
			player.x += v.x
		else:
			player.vel.x = 0.0
		if not box_blocked(_player_box(player.x, player.y + v.y)):
			player.y += v.y
		else:
			player.vel.y = 0.0
	if absf(move.x) > 0.0:
		player.face = signf(move.x)
	player.anim += dt * (10.0 if player.moving else 5.0)
	var aim := Vector2(_axis(KEY_LEFT, KEY_RIGHT), _axis(KEY_UP, KEY_DOWN))
	if aim != Vector2.ZERO:
		_fire(aim)
	elif Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_fire(get_global_mouse_position() - Vector2(player.x, player.y - 40))
	if here == 2 and liquid.hurt:
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
		if s.get("kind", "") == "gravity":
			# the gravity ball drags enemies towards itself while it flies
			var ball: Dictionary = RelicKit.wielded(self).get("ball", theme.gravity_staff.ball)
			for m: Dictionary in mobs:
				var to: Vector2 = s.p - m.p
				if m.spawn <= 0.0 and not m.has("kit") and m.kind != "boss" and to.length() < float(ball.pull_radius) and to.length() > 10.0:
					var step: Vector2 = to.normalized() * float(ball.pull) * dt
					if not box_blocked(Rect2(m.p.x + step.x - m.r * 0.7, m.p.y + step.y - m.r * 0.7, m.r * 1.4, m.r * 0.7), true):
						m.p += step
		var big := float(s.get("big", 1.0))
		for m: Dictionary in mobs:
			if _hittable(m) and not (s.get("hits", []) as Array).has(m) and s.p.distance_to(m.p - Vector2(0, m.cy)) < m.r + 12.0 * big:
				_burst(s.p, 6)
				var mult := float(s.get("mult", 1.0))
				if s.get("pierce", false):
					# piercing shots (blade wave, ballista, arrow fist) go on through everyone
					s.hits.append(m)
					_damage_mob(m, s.v, mult)
					if s.get("push", false) and not m.has("kit"):
						m.k = (s.v as Vector2) * 0.6
					if s.has("slow"):
						HeroKit.slow_mob(self, m, float(s.slow), float(s.slow_time))
					continue
				s.t = 0.0
				var splash: float = s.get("splash", 0.0)
				if splash <= 0.0 and not s.has("burst"):
					_damage_mob(m, s.v, mult)
					break
				_explode(s, m)
				break
		if s.t <= 0.0 and s.has("burst") and not s.get("done", false):
			_explode(s, {})
	shots = shots.filter(func(s: Dictionary) -> bool: return s.t > 0.0)
	if monsters != null:
		monsters.update_shots(dt)
		return
	var me := Vector2(player.x, player.y - 34)
	for s: Dictionary in eshots:
		HeroKit.catch_shot(self, s, dt)
		if s.has("home"):
			s.v = (s.v as Vector2).lerp((me - s.p).normalized() * float(s.home), 1.0 - pow(0.08, dt))
		if s.has("back") and s.t < float(s.back) and s.has("home_to"):
			var owner: Dictionary = s.home_to
			s.v = ((owner.p - Vector2(0, owner.cy)) - s.p).normalized() * (s.v as Vector2).length()
		s.p += s.v * dt
		s.t -= dt
		if not s.get("fist", false) and _cell_blocked(int(floor(s.p.x / C)), int(floor(s.p.y / C)), false):
			s.t = 0.0
			_burst(s.p, 4)
		elif s.p.distance_to(me) < float(balance.enemy_shot.hit_radius) * (1.6 if s.get("fist", false) else 1.0):
			s.t = 0.0 if not s.get("fist", false) else s.t
			if s.has("chill"):
				state.chill = maxf(state.chill, float(s.chill))
			_hurt("von Feuer getroffen")
	eshots = eshots.filter(func(s: Dictionary) -> bool: return s.t > 0.0)


func _update_mobs(dt: float) -> void:
	if monsters != null:
		monsters.update(dt)
		return
	var me := Vector2(player.x, player.y)
	for m: Dictionary in mobs:
		if m.spawn > 0.0:
			m.spawn -= dt
			continue
		m.hit = maxf(0.0, m.hit - dt)
		var to: Vector2 = me - m.p
		var d := maxf(to.length(), 1.0)
		var dir := to / d
		var def: Dictionary = m.def
		var beh: String = def.get("behavior", "")
		m.face = dir
		var wob := sin(state.t * 3.0 + m.seed) * 0.7
		var shy: bool = (m.kind == "spucker" or beh == "shooter") and d < float(def.get("keep_away", 0.0))
		var away := -1.0 if shy else 1.0
		var v: Vector2 = (dir * away + Vector2(-dir.y, dir.x) * wob) * m.sp
		match beh:
			"turret":
				v = Vector2.ZERO
			"dasher":
				# runs like the others, now and then a straight dash at the hero
				m.dash_t -= dt
				if m.dash > 0.0:
					m.dash -= dt
					v = m.dash_dir * float(def.dash_speed)
				elif m.dash_t <= 0.0:
					m.dash_t = float(def.dash_every)
					m.dash = float(def.dash_time)
					m.dash_dir = dir
			"puller":
				if d < float(def.pull_radius):
					var pull: Vector2 = -dir * float(def.pull) * dt
					if not box_blocked(_player_box(player.x + pull.x, player.y)):
						player.x += pull.x
					if not box_blocked(_player_box(player.x, player.y + pull.y)):
						player.y += pull.y
		for o: Dictionary in mobs:
			if o != m:
				var off: Vector2 = m.p - o.p
				var od := off.length()
				if od > 0.0 and od < m.r + o.r:
					v += off / od * 120.0
		if m.get("hold", false):
			v = Vector2.ZERO
		v *= HeroKit.tick_mob(self, m, dt)
		v += m.k
		m.k *= 0.86
		var rr: float = m.r * 0.7
		var avoid: bool = m.kind != "boss"
		var nx: Vector2 = m.p + Vector2(v.x * dt, 0)
		if not box_blocked(Rect2(nx.x - rr, nx.y - rr, rr * 2, rr), avoid) and not HeroKit.wall_blocks(self, nx, rr):
			m.p = nx
		var ny: Vector2 = m.p + Vector2(0, v.y * dt)
		if not box_blocked(Rect2(ny.x - rr, ny.y - rr, rr * 2, rr), avoid) and not HeroKit.wall_blocks(self, ny, rr):
			m.p = ny
		if d < m.r + 22.0:
			var who: String = ("von %s erwischt" % def.name) if def.has("name") else "von Glutlingen verbrannt"
			_hurt("von %s erschlagen" % W.boss.name if m.kind == "boss" else who)
			if def.has("chill"):
				state.chill = float(def.chill)
		if m.kind == "spucker" or beh == "shooter":
			m.shoot -= dt
			if m.shoot <= 0.0:
				m.shoot = float(def.fire_every)
				_enemy_shot(m.p - Vector2(0, 40), to - Vector2(0, 30), float(def.get("shot_speed", balance.enemy_shot.speed)))
				_sound("enemy_shot")
		elif beh == "turret":
			m.shoot -= dt
			if m.shoot <= 0.0:
				m.shoot = float(def.fire_every)
				var fan := int(def.fan)
				for k in range(fan):
					var a: float = dir.angle() + (float(k) / maxf(1.0, fan - 1.0) - 0.5) * float(def.spread)
					_enemy_shot(m.p - Vector2(0, m.cy), Vector2(cos(a), sin(a)), float(def.shot_speed))
		elif m.kind == "boss" and m.has("kit"):
			BossKit.update(self, m, dt)
		elif m.kind == "boss":
			m.summon -= dt
			var adds := 0
			for o: Dictionary in mobs:
				if o.room == m.room and o.kind != "boss":
					adds += 1
			if m.summon <= 0.0 and adds < int(balance.mobs.boss.max_adds):
				m.summon = float(W.boss.summon)
				var adds_kinds: Array = theme.get("boss_adds", ["glut", "spucker" if W.final else "glut"])
				_spawn_mob(m.room, m.p + Vector2(-100, 30), adds_kinds[0])
				_spawn_mob(m.room, m.p + Vector2(100, 30), adds_kinds[1 % adds_kinds.size()])
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
		if m.hp > 0.0 or (m.has("kit") and BossKit.next_phase(self, m)):
			continue
		_burst(m.p - Vector2(0, 30), 70 if m.kind == "boss" else 16)
		mobs.erase(m)
		_sound("kill_" + str((m.def as Dictionary).get("material", "void")))
		HeroKit.gain(self, HeroKit.exp_for(self, m))
		# a splitting enemy (e.g. ice slime) leaves smaller ones behind
		var kids := MobRules.split_children(m.def)
		for i in range(kids.size()):
			var a: float = TAU * float(i) / kids.size() + float(m.seed)
			_spawn_mob(m.room, m.p + Vector2(cos(a), sin(a)) * 40.0, kids[i])
			mobs[mobs.size() - 1].spawn = 0.15
		var rest := mobs.filter(func(o: Dictionary) -> bool: return o.room == m.room)
		if rest.is_empty():
			_clear_room(W.rooms[m.room], m.p)


## Boss areas: icicles strike at the end of their warning, chill fields slow while
## stood in, telegraph and safe marks just fade (the boss reads them).
func _update_zones(dt: float) -> void:
	var me := Vector2(player.x, player.y)
	for z: Dictionary in zones:
		z.t -= dt
		var inside := me.distance_to(z.p) < float(z.r)
		match z.kind:
			"icicle":
				if z.t <= 0.0:
					_burst(z.p, 14)
					if inside:
						_hurt("von einem Eiszapfen getroffen")
			"chill":
				if inside:
					state.chill = maxf(state.chill, 0.3)
	zones = zones.filter(func(z: Dictionary) -> bool: return z.t > 0.0)


## A bursting hero shot (magic splash, fireball, arrow fist): everyone in the radius
## takes the burst multiple; fire sets them burning, the fist slows.
func _explode(s: Dictionary, first: Dictionary) -> void:
	s.done = true
	s.t = 0.0
	var radius := float(s.get("burst", s.get("splash", 0.0)))
	var mult := float(s.get("burst_mult", s.get("mult", 1.0)))
	for o: Dictionary in mobs:
		if _hittable(o) and s.p.distance_to(o.p - Vector2(0, o.cy)) < radius + o.r:
			_damage_mob(o, (o.p - s.p).normalized() * 500.0, mult)
			if s.has("burn"):
				HeroKit.burn_mob(o, float(s.burn), float(s.burn_time))
			if s.has("slow"):
				HeroKit.slow_mob(self, o, float(s.slow), float(s.slow_time))
	fx.append({"kind": "blast", "p": s.p, "r": radius, "t": 0.3, "max": 0.3, "gravity": s.get("kind", "") in ["gravity", "rock"]})
	if int(s.get("split", 0)) > 0:
		RelicKit.split_rock(self, s)
	_burst(s.p, 18)
	_sound("blast")


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
					_sound("plate_wrong" if res == "wrong" else "plate")
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
					_sound("key")
					_toast("%s aufgehoben." % key_name[e.key])
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
	if _fully_inside(r, player.x, player.y):
		_start_fight(r)


## True when the hero at x, y stands inside room r with a margin on every side
## (the point where a fight starts and the gates may close behind them).
func _fully_inside(r: Dictionary, x: float, y: float) -> bool:
	var hw := float(balance.player.half_width) + 40.0
	for o: Vector2 in [Vector2(-hw, -60), Vector2(hw, -60), Vector2(-hw, 30), Vector2(hw, 30)]:
		if _room_at_world(x + o.x, y + o.y) != r.index:
			return false
	return true


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
	camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * state.shake


# ---------- world drawing ----------

## Draws one layer: static chunks (back/front), live actors, or the darkness.
func draw_layer(l: Layer) -> void:
	match l.kind:
		"back": _draw_back(l)
		"front": _draw_front(l)
		"actors": _draw_actors(l)
		"glow":
			if monsters != null:
				monsters.draw_fx(l)
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
	_draw_zones(l, t)
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
	if monsters != null:
		monsters.draw_warnings(l)
	var list: Array = []
	for p: Dictionary in W.props:
		if p.name != "" and view.has_point(Vector2(p.x, p.y)):
			list.append([p.y - (200.0 if p.low else 0.0), "prop", p])
	for e: Dictionary in W.ents:
		if view.has_point(Vector2(e.x, e.y)) and e.type in ["chest", "vault", "portal", "brazier", "key", "heart", "gem", "relic"] and not e.get("taken", false):
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
		if view.grow(300 if monsters != null else 0).has_point(m.p):
			list.append([m.p.y, "mob", m])
	if monsters != null:
		for c: Dictionary in monsters.corpses:
			if view.has_point(c.p):
				list.append([c.p.y, "corpse", c])
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
			"mob":
				if monsters != null:
					monsters.draw_mob(l, item[2])
				else:
					_draw_mob(l, item[2], t)
			"corpse": monsters.draw_corpse(l, item[2])
			"breakable": _draw_breakable(l, item[2], t)
			"clone": _draw_clone(l, t)
			"hero": _draw_hero(l, t)
	_draw_skill_fx(l, t)
	RelicKit.draw(self, l, t)
	for s: Dictionary in shots:
		if s.get("kind", "") == "gravity":
			var sp := sin(t * 14.0)
			l.draw_circle(s.p, 26.0, Color(0.35, 0.2, 0.8, 0.35))
			l.draw_circle(s.p, 14.0, Color(0.08, 0.02, 0.18, 0.95))
			l.draw_arc(s.p, 22.0 + sp * 3.0, t * 6.0, t * 6.0 + 4.0, 16, Color(0.75, 0.6, 1.0, 0.9), 3.0)
			continue
		if s.get("kind", "") == "rock":
			var rock: Texture2D = tex.rock_throw
			l.draw_set_transform(s.p, t * 8.0)
			l.draw_texture_rect(rock, Rect2(-rock.get_size(), rock.get_size() * 2.0), false)
			l.draw_set_transform(Vector2.ZERO)
			continue
		if s.get("kind", "") == "shard":
			l.draw_circle(s.p, 9.0, Color(0.75, 0.6, 1.0, 0.8))
			continue
		if s.get("kind", "") == "fireball":
			l.draw_circle(s.p, 22.0, Color(1.0, 0.45, 0.15, 0.5))
			l.draw_circle(s.p, 11.0, Color(1.0, 0.9, 0.6))
			continue
		if s.get("kind", "") == "wave":
			var wa := (s.v as Vector2).angle()
			l.draw_arc(s.p, 60.0, wa - 1.1, wa + 1.1, 18, Color(col("shot_core"), 0.85), 10.0)
			continue
		if s.get("kind", "") == "arrow" and arrow_tex != null:
			var asz := arrow_tex.get_size() * float(theme.get("weapon_scale", theme.hero_scale))
			asz *= float(s.get("big", 1.0))
			l.draw_set_transform(s.p, (s.v as Vector2).angle() + PI / 2.0)
			l.draw_texture_rect(arrow_tex, Rect2(-asz / 2.0, asz), false)
			l.draw_set_transform(Vector2.ZERO)
			continue
		var big := (1.5 if s.get("kind", "") == "magic" else 1.0) * float(s.get("big", 1.0))
		l.draw_circle(s.p, 16.0 * big, col("shot_glow"))
		l.draw_circle(s.p, 8.0 * big, col("shot_core"))
	# hell monster shots glow on the additive layer instead
	for s: Dictionary in (eshots if monsters == null else []):
		var r := 30.0 if s.get("fist", false) else 15.0
		l.draw_circle(s.p, r, col("eshot_glow"))
		l.draw_circle(s.p, r * 0.47, col("eshot_core"))
	for p: Dictionary in embers:
		var c := col("ember_gold") if p.gold else (col("ember_big") if p.big else col("ember"))
		c.a = minf(1.0, p.t * 2.0)
		var s := 9.0 if p.big else 5.0
		l.draw_rect(Rect2(p.p - Vector2(s, s) / 2.0, Vector2(s, s)), c)


## Boss areas on the floor and the warning line of a coming charge.
func _draw_zones(l: Layer, t: float) -> void:
	for z: Dictionary in zones:
		var k: float = 1.0 - float(z.t) / maxf(0.01, float(z.max))
		match z.kind:
			"icicle":
				l.draw_circle(z.p, float(z.r), Color(0.75, 0.9, 1.0, 0.12 + 0.3 * k))
				l.draw_arc(z.p, float(z.r), 0.0, TAU, 32, Color(0.85, 0.95, 1.0, 0.9), 3.0)
				l.draw_circle(z.p, float(z.r) * k, Color(1, 1, 1, 0.25))
			"chill":
				l.draw_circle(z.p, float(z.r), Color(0.3, 0.6, 1.0, 0.22))
				l.draw_arc(z.p, float(z.r), 0.0, TAU, 32, Color(0.5, 0.8, 1.0, 0.6), 2.0)
			"telegraph":
				l.draw_arc(z.p, float(z.r), 0.0, TAU, 40, Color(1, 1, 1, 0.4 + 0.5 * k), 4.0)
			"caltrop":
				for i in range(7):
					var q: Vector2 = z.p + Vector2(cos(i * 2.4), sin(i * 2.4)) * float(z.r) * (0.3 + 0.1 * i)
					l.draw_rect(Rect2(q - Vector2(4, 4), Vector2(8, 8)), Color(0.8, 0.85, 0.95, 0.8))
			"safe":
				l.draw_circle(z.p, float(z.r), Color(0.5, 1.0, 0.85, 0.18 + 0.12 * sin(t * 8.0)))
				l.draw_arc(z.p, float(z.r), 0.0, TAU, 40, Color(0.6, 1.0, 0.9, 0.95), 4.0)
	for m: Dictionary in mobs:
		var b: Dictionary = m.get("busy", {})
		if str(b.get("do", "")) == "charge" and float(b.e) < float(b.windup):
			var from: Vector2 = m.p - Vector2(0, 10)
			l.draw_line(from, from + (b.dir as Vector2) * float(b.speed) * float(b.time), Color(1, 0.4, 0.5, 0.35 + 0.4 * sin(t * 20.0)), 18.0)


## Skill effects in the world: whirl and blast rings, lightning, blink trails, the
## photon beam, the ballista charge, gravity walls and bars, enemy health and level-up.
func _draw_skill_fx(l: Layer, t: float) -> void:
	for f: Dictionary in fx:
		var k: float = float(f.t) / maxf(0.01, float(f.max))
		match f.kind:
			"whirl":
				l.draw_arc(f.p, float(f.r) * (1.1 - k * 0.3), 0.0, TAU, 40, Color(col("shot_core"), k), 10.0)
			"blast":
				var bc := Color(0.6, 0.4, 1.0, 0.5 * k) if f.get("gravity", false) else Color(1.0, 0.7, 0.4, 0.45 * k)
				l.draw_circle(f.p, float(f.r) * (1.2 - k * 0.4), bc)
			"bolt":
				var a: Vector2 = f.p
				var b: Vector2 = f.q
				var pts := PackedVector2Array([a])
				for i in range(1, 6):
					pts.append(a.lerp(b, i / 6.0) + Vector2(randf_range(-14, 14), randf_range(-14, 14)))
				pts.append(b)
				l.draw_polyline(pts, Color(0.7, 0.85, 1.0, k), 4.0)
			"blink":
				l.draw_line(f.p, f.q, Color(0.6, 0.4, 1.0, 0.6 * k), 18.0)
	if str(hold.get("id", "")) == "photon":
		var s := HeroKit._skill(self, "photon")
		var me := Vector2(player.x, player.y - 40)
		var dir := Vector2(cos(float(hold.angle)), sin(float(hold.angle)))
		l.draw_line(me, me + dir * float(s.length), Color(1.0, 0.6, 0.3, 0.45), float(s.width))
		l.draw_line(me, me + dir * float(s.length), Color(0.8, 0.95, 1.0, 0.9), float(s.width) * 0.35)
	elif str(hold.get("id", "")) == "ballista":
		var share := clampf(float(hold.t) / float(HeroKit._skill(self, "ballista").charge), 0.0, 1.0)
		l.draw_arc(Vector2(player.x, player.y - 40), 60.0, -PI / 2.0, -PI / 2.0 + TAU * share, 32, Color(col("shot_core"), 0.9), 6.0)
	for w: Dictionary in gwalls:
		var wa := clampf(float(w.t) / 0.4, 0.0, 1.0)
		l.draw_line(w.a, w.b, Color(0.3, 0.15, 0.7, 0.55 * wa), float(w.w))
		l.draw_line(w.a, w.b, Color(0.75, 0.6, 1.0, 0.9 * wa), 4.0)
		for i in range(6):
			var q: Vector2 = (w.a as Vector2).lerp(w.b, fmod(t * 0.4 + i / 6.0, 1.0))
			l.draw_circle(q, 5.0, Color(0.85, 0.75, 1.0, 0.8 * wa))
	for b: Dictionary in gbars:
		var ba := clampf(float(b.t) / 0.4, 0.0, 1.0)
		l.draw_line(b.a, b.b, Color(0.5, 0.85, 1.0, 0.35 * ba), float(b.w))
		l.draw_line(b.a, b.b, Color(0.85, 0.75, 1.0, 0.95 * ba), 3.0)
	if not bar_drag.is_empty():
		var cfg: Dictionary = theme.gravity_staff.bar
		var to: Vector2 = get_global_mouse_position()
		if (to - bar_drag.a).length() > float(cfg.max_length):
			to = bar_drag.a + (to - bar_drag.a).normalized() * float(cfg.max_length)
		l.draw_dashed_line(bar_drag.a, to, Color(0.85, 0.75, 1.0, 0.8), 3.0, 14.0)
	for m: Dictionary in mobs:
		# health over every hurt enemy (the guardian has its bar at the top)
		if m.kind != "boss" and m.spawn <= 0.0 and m.hp < m.max:
			var w := 64.0
			var at: Vector2 = m.p - Vector2(w / 2.0, m.cy * 2.0 + 18.0)
			l.draw_rect(Rect2(at - Vector2(2, 2), Vector2(w + 4, 10)), Color(0.02, 0.03, 0.08, 0.85))
			l.draw_rect(Rect2(at, Vector2(w * clampf(m.hp / m.max, 0.0, 1.0), 6)), Color("#ff5d73") if float(m.get("burn_t", 0.0)) <= 0.0 else Color("#ffaa55"))
	if not levelfx.is_empty():
		var lt: float = levelfx.t
		var c := Vector2(player.x, player.y - 40)
		l.draw_arc(c, 40.0 + lt * 260.0, 0.0, TAU, 48, Color(1.0, 0.95, 0.6, maxf(0.0, 1.0 - lt / 1.4)), 8.0)
		l.draw_arc(c, 20.0 + lt * 160.0, 0.0, TAU, 48, Color(col("shot_core"), maxf(0.0, 1.0 - lt / 1.0)), 5.0)


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
		"relic":
			# the staff floats over its seal; sealed it lies dark, freed it glows and turns
			var free: bool = W.groups[e.seal].get("solved", false)
			if relic_tex == null:
				return
			var k := float(theme.get("weapon_scale", 2.0)) * 1.6
			var size := relic_tex.get_size() * k
			var c := Vector2(e.x, e.y - 40 + (sin(t * 2.0) * 8.0 if free else 0.0))
			l.draw_circle(Vector2(e.x, e.y), 70.0, Color(0.45, 0.3, 1.0, 0.18 + (0.12 * sin(t * 4.0) if free else 0.0)))
			l.draw_arc(Vector2(e.x, e.y), 70.0, 0.0, TAU, 40, Color(0.7, 0.55, 1.0, 0.8 if free else 0.35), 3.0)
			l.draw_set_transform(c, 0.35 + (sin(t) * 0.15 if free else 0.0))
			l.draw_texture_rect(relic_tex, Rect2(-size / 2.0, size), false, _color(theme[e.item].tint) if free else Color(0.35, 0.3, 0.5))
			l.draw_set_transform(Vector2.ZERO)
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
			var name: String = "rune_gem" if e.type == "gem" else (key_sprite[e.key] if e.type == "key" else e.type)
			var im: Texture2D = tex[name]
			var s := 0.9 if e.type == "key" else (0.55 if e.type == "gem" else 0.7)
			var bob := sin(t * 3.0 + e.x) * 6.0
			var size := im.get_size() * s
			l.draw_texture_rect(im, Rect2(Vector2(e.x - size.x / 2.0, e.y - size.y - 10 + bob), size), false, key_tint.get(e.get("key", ""), Color.WHITE))


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
		l.draw_texture_rect(tex[key_sprite[d.key]], Rect2(d.cx - 15, d.cy - 30, 30, 56), false, key_tint[d.key])
	elif not fight and d.kind == "puzzle":
		var icon: Texture2D = tex.brazier_bowl if W.groups[d.group].kind == "braziers" else tex.icon_scroll
		l.draw_texture_rect(icon, Rect2(d.cx - 22, d.cy - 30, 44, 44 * icon.get_height() / icon.get_width()), false)


func _draw_mob(l: Layer, m: Dictionary, t: float) -> void:
	if (m.look as Dictionary).has("sprite"):
		_draw_mob_sprite(l, m, t)
		return
	var im: Texture2D = tex.fire_orb
	var s: float = m.s * (1.0 - m.spawn * 1.6 if m.spawn > 0.0 else 1.0)
	if s <= 0.0:
		return
	var tint := Color.WHITE
	match m.kind:
		"gross": tint = col("mob_gross")
		"spucker": tint = col("mob_spucker")
		"boss": tint = col("mob_boss_final") if W.final else col("mob_boss")
	if m.hit > 0.0:
		tint = Color(3, 3, 3)
	var bob := sin(t * 6.0 + m.seed) * 6.0
	var size := im.get_size() * s
	l.draw_texture_rect(im, Rect2(m.p - Vector2(size.x / 2.0, size.y + 14 - bob), size), false, tint)
	if m.kind == "boss":
		var icon: Texture2D = tex.icon_demon_big if W.final else tex.icon_demon
		var k := s / 2.7
		l.draw_texture_rect(icon, Rect2(m.p.x - 46 * k, m.p.y - size.y - 4 + bob, 92 * k, 96 * k), false)


## A themed enemy: its animated skin sprite, turned towards the hero, grown in while spawning.
func _draw_mob_sprite(l: Layer, m: Dictionary, t: float) -> void:
	var look: Dictionary = m.look
	var grow: float = 1.0 - m.spawn * 1.6 if m.spawn > 0.0 else 1.0
	if grow <= 0.0:
		return
	var im: Texture2D = tex.get(MobRules.frame_name(look, int(t * float(look.get("fps", 8)) + m.seed)))
	if im == null:
		return
	var size := im.get_size() * float(m.ds) * grow
	var tint := Color(3, 3, 3) if m.hit > 0.0 else (Color(1.6, 1.8, 2.2) if m.dash > 0.0 else _color(m.get("tint", [1, 1, 1])))
	if float(m.get("inv", 0.0)) > 0.0:
		tint.a = 0.45 + 0.35 * sin(t * 30.0)
	var pos: Vector2 = m.p - Vector2(size.x / 2.0, size.y)
	if (m.face as Vector2).x < 0.0:
		l.draw_set_transform(pos + Vector2(size.x, 0), 0.0, Vector2(-1, 1))
		l.draw_texture_rect(im, Rect2(Vector2.ZERO, size), false, tint)
		l.draw_set_transform(Vector2.ZERO)
	else:
		l.draw_texture_rect(im, Rect2(pos, size), false, tint)


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
	var size := im.get_size() * float(theme.hero_scale)
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
	var size := im.get_size() * float(theme.hero_scale)
	var pos := Vector2(player.x, player.y - size.y + 6)
	if player.face < 0:
		l.draw_set_transform(pos + Vector2(size.x / 2.0, 0), 0.0, Vector2(-1, 1))
		l.draw_texture_rect(im, Rect2(Vector2.ZERO, size), false)
		l.draw_set_transform(Vector2.ZERO)
	else:
		l.draw_texture_rect(im, Rect2(pos - Vector2(size.x / 2.0, 0), size), false)
	_draw_weapon(l, size)


## The class weapon in the hero's hand: bow and staff held upright, the sword
## swept through its arc while a swing lasts; the gravity staff glows violet.
func _draw_weapon(l: Layer, hero_size: Vector2) -> void:
	if relic_on() and relic_tex != null:
		var rel := RelicKit.wielded(self)
		var rk := float(theme.get("weapon_scale", 2.0))
		var rsz := relic_tex.get_size() * rk
		var rhand := Vector2(player.x + float(player.face) * hero_size.x * 0.32, player.y - hero_size.y * 0.38)
		var tilt := 0.0
		if rel.has("attack") and swing.t > 0.0:
			# the hammer comes down through its arc
			tilt = float(swing.a) + PI / 2.0 + float(rel.attack.arc) * (0.5 - swing.t / 0.22)
			l.draw_set_transform(Vector2(player.x, player.y - 40), tilt)
			l.draw_texture_rect(relic_tex, Rect2(Vector2(-rsz.x / 2.0, -rsz.y - 10.0), rsz), false, _color(rel.tint))
			l.draw_set_transform(Vector2.ZERO)
			return
		l.draw_set_transform(rhand, 0.0, Vector2(float(player.face), 1))
		l.draw_texture_rect(relic_tex, Rect2(Vector2(-rsz.x / 2.0, -rsz.y * 0.7), rsz), false, _color(rel.tint))
		l.draw_set_transform(Vector2.ZERO)
		return
	if weapon_tex == null:
		return
	var k := float(theme.get("weapon_scale", theme.hero_scale))
	var wsz := weapon_tex.get_size() * k
	var hand := Vector2(player.x + float(player.face) * hero_size.x * 0.32, player.y - hero_size.y * 0.38)
	if weapon.type == "melee" and swing.t > 0.0:
		var a: float = swing.a + float(weapon.arc) * (0.5 - swing.t / 0.16)
		var tip := Vector2(cos(a), sin(a))
		l.draw_line(Vector2(player.x, player.y - 40) + tip * 30.0, Vector2(player.x, player.y - 40) + tip * float(weapon.reach), Color(col("shot_core"), 0.5), 6.0)
		l.draw_set_transform(Vector2(player.x, player.y - 40), a + PI / 2.0)
		l.draw_texture_rect(weapon_tex, Rect2(Vector2(-wsz.x / 2.0, -wsz.y - 12.0), wsz), false)
		l.draw_set_transform(Vector2.ZERO)
		return
	var tilt := 0.35 * float(player.face) if weapon.type == "melee" else 0.0
	l.draw_set_transform(hand, tilt, Vector2(float(player.face), 1))
	l.draw_texture_rect(weapon_tex, Rect2(Vector2(-wsz.x / 2.0, -wsz.y * 0.7), wsz), false)
	l.draw_set_transform(Vector2.ZERO)


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
		if monsters != null:
			var reach_light: float = 90.0 + m.r * 2.2 * (1.3 if m.def.kind == "lord" else 1.0)
			cands.append([m.p.distance_squared_to(center), Vector4(m.p.x, m.p.y - m.cy - m.alt, reach_light, 1.0)])
		else:
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
	_dark_material.set_shader_parameter("darkness", clampf(float(W.theme.dark) + 0.16 + (0.14 if state.storm else 0.0), 0.0, 0.95))
	var shade := col("shade") + col("shade_grade") * float(W.theme.grade)
	shade.a = 1.0
	_dark_material.set_shader_parameter("shade_color", shade)
	_dark_material.set_shader_parameter("light_bands", float(balance.view.light_bands))
	l.draw_rect(view.grow(40), Color.WHITE)


# ---------- HUD ----------

## Draws the HUD into the screen-space control.
func draw_hud(h: Control) -> void:
	var size := h.size
	var th: Dictionary = W.theme
	if float(th.grade) > 0.0:
		var grade := col("grade")
		grade.a = float(th.grade) * 0.45
		h.draw_rect(Rect2(Vector2.ZERO, size), grade)
	var vig := col("vignette") + col("vignette_glow") * float(th.wall_glow)
	vig.a = float(th.vignette)
	h.draw_texture_rect(_vignette, Rect2(Vector2.ZERO, size), false, vig)
	if state.flash > 0.0:
		h.draw_rect(Rect2(Vector2.ZERO, size), Color(0.8, 0.08, 0.08, state.flash))
	if state.white > 0.0:
		h.draw_rect(Rect2(Vector2.ZERO, size), Color(1, 0.925, 0.82, minf(1.0, state.white)))
	# hearts: two half hearts each, drawn with the 0x72 full / half / empty heart
	var hs := 32.0
	var hh := 32.0
	for i in range(state.max_hp / 2):
		var v: int = state.hp - i * 2
		var p := Vector2(20 + (i % 8) * (hs + 4), 18 + (i / 8) * (hh + 4))
		var pulse := 1.0 + (0.12 * sin(state.t * 8.0) if state.hp <= 2 and v > 0 else 0.0)
		var hr := Rect2(p + Vector2(hs, hh) * (1.0 - pulse) / 2.0, Vector2(hs, hh) * pulse)
		h.draw_texture_rect(hearts.full if v >= 2 else (hearts.half if v == 1 else hearts.empty), hr, false)
	var row := 92.0 if state.max_hp > 16 else 60.0
	var x := 22.0
	for k in ["A", "B", "C"]:
		var alpha := 1.0 if state.keys[k] else (0.14 if state.used[k] else 0.22)
		var tint: Color = key_tint[k]
		tint.a = alpha
		h.draw_texture_rect(tex[key_sprite[k]], Rect2(x, row, 18, 34), false, tint)
		x += 28.0
	h.draw_texture_rect(tex.rune_gem, Rect2(x + 8, row + 2, 22, 32), false)
	_text(h, "× %d" % state.gems, Vector2(x + 38, row + 26), 24, ink)
	var fire := Rules.group_progress(W.ents, "feuer")
	if fire.y > 0:
		h.draw_texture_rect(tex.brazier_bowl, Rect2(x + 110, row - 4, 26, 37), false)
		_text(h, "%d/%d" % [fire.x, fire.y], Vector2(x + 144, row + 26), 24, ink)
	var line := row + 60.0
	if not skills.is_empty():
		# level and experience under the keys
		var cfg: Dictionary = theme.leveling
		var need := HeroKit.need(cfg, int(state.level))
		_text(h, "LV %d" % int(state.level), Vector2(22, line - 4), 20, gold)
		h.draw_rect(Rect2(86, line - 18, 180, 12), Color(0.02, 0.04, 0.1, 0.85))
		h.draw_rect(Rect2(86, line - 18, 180 * clampf(float(state.exp) / need, 0.0, 1.0), 12), col("accent"))
		h.draw_rect(Rect2(86, line - 18, 180, 12), Color(ink, 0.5), false, 1.0)
		line += 26.0
	var sk: Dictionary = state.skill
	if sk.owned:
		var clock := "%d:%02d" % [int(sk.left) / 60, int(sk.left) % 60]
		var label := ("Klon aktiv · " + clock) if sk.active else (("Q: Klon rufen · " + clock) if sk.left > 0.0 else "Klon aufgebraucht")
		_text(h, label, Vector2(22, line), 16, Color("#7fe8ff") if sk.active else (gold if sk.left > 0.0 else Color(ink, 0.4)))
		line += 24.0
	if not (state.buffs as Array).is_empty():
		var names: Array = (state.buffs as Array).map(func(b: String) -> String: return b.get_slice(":", 0))
		_text(h, "Segen: " + ", ".join(PackedStringArray(names)), Vector2(22, line), 16, Color(1, 0.89, 0.55, 0.85))
	var who := "%s · %s · " % [hero.name, RelicKit.wielded(self).name if relic_on() else weapon.name] if not hero.is_empty() else ""
	var keys_hint := "F1-F10 Etage · T Waffe wechseln" if not skills.is_empty() else "1-0 Etage"
	_text(h, who + "Etage %d · %s · %s · Q Klon · M Karte · Esc Menü" % [state.floor, W.title, keys_hint], Vector2(20, size.y - 38), 16, Color(col("sub"), 0.7))
	if not skills.is_empty():
		_draw_skill_bar(h, size)
	var boss_mob: Dictionary = {}
	for m: Dictionary in mobs:
		if m.kind == "boss":
			boss_mob = m
	# the banner moves below the guardian's bar while it stands
	var b: Dictionary = state.banner
	var ba := clampf(b.t / 0.4, 0.0, 1.0) if b.t < 2.6 else maxf(0.0, 1.0 - (b.t - 2.6) / 0.8)
	var banner_y := 66.0 if boss_mob.is_empty() else 172.0
	if theme.get("styled_hud", false):
		FrostHud.banner(self, h, size, banner_y + 20.0)
	elif ba > 0.0:
		_text(h, b.text, Vector2(0, banner_y), 32, Color(gold, ba), size.x)
		_text(h, String(b.sub).to_upper(), Vector2(0, banner_y + 30), 16, Color(col("sub"), ba), size.x)
	if not boss_mob.is_empty():
		# the guardian's bar sits at the top, between hearts and minimap
		var bw := 600.0
		var bx := size.x / 2.0 - bw / 2.0
		var by := 46.0
		h.draw_rect(Rect2(bx - 10, by - 38, bw + 20, 68), Color(0.02, 0.03, 0.08, 0.92))
		h.draw_rect(Rect2(bx - 10, by - 38, bw + 20, 68), Color(col("boss_bar"), 0.6), false, 2.0)
		var bars: int = boss_mob.phase_hp.size() if boss_mob.has("kit") else 1
		var phase_i: int = int(boss_mob.phase) if boss_mob.has("kit") else 0
		var gap := 8.0
		var sw := (bw - gap * (bars - 1)) / bars
		for i in range(bars):
			# spent bars empty, the current one draining, later ones full
			var sx := bx + i * (sw + gap)
			var fill: float = 0.0 if i < phase_i else (1.0 if i > phase_i else clampf(boss_mob.hp / boss_mob.max, 0.0, 1.0))
			h.draw_rect(Rect2(sx, by, sw, 18), col("boss_back"))
			h.draw_rect(Rect2(sx, by, sw * fill, 18), col("boss_bar") if float(boss_mob.get("inv", 0.0)) <= 0.0 else Color(1, 1, 1, 0.85))
			h.draw_rect(Rect2(sx, by, sw, 18), Color(ink, 0.7), false, 1.5)
		var pname := str(BossKit.phase(boss_mob).get("name", "")) if boss_mob.has("kit") else ""
		var title: String = str(W.boss.name) + (" · " + pname if pname != "" else "") + ("" if boss_mob.has("kit") else " (Platzhalter)")
		if monsters != null:
			title = monsters.boss_label(boss_mob)
		_text(h, title, Vector2(bx, by - 12), 16, gold)
		var total := 0.0
		var left := maxf(0.0, boss_mob.hp)
		if boss_mob.has("kit"):
			for i in range(bars):
				total += float(boss_mob.phase_hp[i])
				if i > phase_i:
					left += float(boss_mob.phase_hp[i])
		else:
			total = boss_mob.max
		var pct := "%d %%" % int(ceil(left / maxf(1.0, total) * 100.0))
		_text(h, pct, Vector2(bx + bw - FONT.get_string_size(pct, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x, by - 12), 20, ink)
	var cr: Dictionary = W.rooms[state.room]
	if cr.fight:
		var left := 0
		for m: Dictionary in mobs:
			if m.room == cr.index:
				left += 1
		_text(h, "Verriegelt · noch %d Gegner" % left, Vector2(0, 128 if boss_mob.is_empty() else 112), 20, col("warn"), size.x)
	var n := _nearest()
	if not n.is_empty() and state.dead <= 0.0 and not state.won:
		var sp := _to_screen(n.p, size) - Vector2(0, 70)
		var label := say(n.label)
		var w := FONT.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x + 60.0
		h.draw_rect(Rect2(sp.x - w / 2.0, sp.y - 21, w, 42), Color(0.02, 0.03, 0.08, 0.92))
		h.draw_rect(Rect2(sp.x - w / 2.0, sp.y - 21, w, 42), accent, false, 2.0)
		h.draw_rect(Rect2(sp.x - w / 2.0 + 8, sp.y - 13, 26, 26), Color(accent, 0.25))
		_text(h, "E", Vector2(sp.x - w / 2.0 + 14, sp.y + 7), 18, col("prompt_key"))
		_text(h, label, Vector2(sp.x - w / 2.0 + 44, sp.y + 7), 18, ink)
	var toasts: Array = state.toasts
	for i in range(toasts.size()):
		var tt: Dictionary = toasts[i]
		# hints stack above the skill bar: bigger text, dark box, accent edge on the left
		var ty := size.y - 52.0 - (toasts.size() - 1 - i) * 48.0 - (124.0 if not skills.is_empty() else 0.0)
		var fade := minf(1.0, tt.t * 2.0)
		var w := FONT.get_string_size(tt.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x + 48.0
		h.draw_rect(Rect2(size.x / 2.0 - w / 2.0, ty - 21, w, 42), Color(0.02, 0.03, 0.08, 0.92 * fade))
		h.draw_rect(Rect2(size.x / 2.0 - w / 2.0, ty - 21, 5, 42), Color(accent, fade))
		_text(h, tt.text, Vector2(0, ty + 7), 20, Color(ink, fade), size.x)
	if theme.placeholder_note:
		_text(h, "Figur: Platzhalter" if monsters != null else "Figur und Gegner: Platzhalter", Vector2(20, size.y - 14), 16, Color(ink, 0.45))
	if state.dead > 0.0:
		h.draw_rect(Rect2(Vector2.ZERO, size), Color(0.12, 0, 0, 0.55))
	_draw_map(h, size, state.map)
	if theme.get("styled_hud", false) and not state.map and not state.won:
		FrostHud.mission(self, h, size)
		if state.get("status", false):
			FrostHud.status(self, h, size)
	if state.won:
		h.draw_rect(Rect2(Vector2.ZERO, size), Color(0.04, 0.01, 0.02, 0.8))
		_text(h, say("Die Hölle ist bezwungen") if W.final else "Etage %d geschafft" % state.floor, Vector2(0, size.y / 2.0 - 30), 32, gold, size.x)
		_text(h, say("%d von %d Räumen erkundet · %d Runensteine · %d Herzen" % [state.visited.size(), W.rooms.size(), state.gems, state.max_hp / 2]), Vector2(0, size.y / 2.0 + 16), 16, ink, size.x)
		_text(h, "E: von vorn beginnen" if W.final else "E: weiter zu Etage %d" % (state.floor + 1), Vector2(0, size.y / 2.0 + 52), 16, col("prompt_key"), size.x)


## The skill bar at the bottom: one slot per key with icon, key, cooldown shade
## and the level it opens at; with the gravity staff the slots turn dark violet
## and show the staff's three abilities instead.
func _draw_skill_bar(h: Control, size: Vector2) -> void:
	if not (state.get("offer", []) as Array).is_empty():
		FrostHud.cards(self, h, size)
	var slots: Array = []
	if relic_on():
		var rel := RelicKit.wielded(self)
		var atk: Dictionary = rel.get("ball", rel.get("attack", {}))
		slots = [{"key": "LMB", "name": atk.get("short", atk.get("name", "")), "cd": float(state.cool), "max": float(atk.get("cooldown", 1.0)), "open": true}]
		for s: Dictionary in rel.skills:
			slots.append({"key": str(s.key), "name": str(s.short), "cd": float(state.skill_cd.get(str(s.id), 0.0)), "max": float(s.cooldown),
				"open": int(state.level) >= int(s.unlock), "unlock": int(s.unlock)})
	else:
		for s: Dictionary in skills:
			slots.append({"key": str(s.key), "name": str(s.name), "cd": float(state.skill_cd.get(str(s.key), 0.0)), "max": float(s.cooldown),
				"open": HeroKit.unlocked(self, s), "unlock": int(s.unlock)})
	var sw := 64.0
	var cellw := 116.0
	var x0 := size.x / 2.0 - slots.size() * cellw / 2.0
	var y0 := size.y - 150.0
	var dark := relic_on()
	for i in range(slots.size()):
		var sl: Dictionary = slots[i]
		var r := Rect2(x0 + i * cellw + (cellw - sw) / 2.0, y0, sw, sw)
		h.draw_rect(r, Color(0.08, 0.02, 0.14, 0.95) if dark else Color(0.02, 0.04, 0.1, 0.9))
		var icon: Texture2D = relic_tex if dark else weapon_tex
		if icon != null:
			var isz := icon.get_size() * 2.0
			var tint := _color(RelicKit.wielded(self).tint) if dark else Color.WHITE
			if not sl.open:
				tint = Color(tint, 0.25)
			h.draw_texture_rect(icon, Rect2(r.get_center() - isz / 2.0, isz), false, tint)
		if sl.cd > 0.0:
			h.draw_rect(Rect2(r.position, Vector2(sw, sw * clampf(sl.cd / maxf(0.01, sl.max), 0.0, 1.0))), Color(0, 0, 0, 0.6))
			_text(h, "%.0f" % ceil(sl.cd), Vector2(r.position.x, r.position.y + 44), 20, ink, sw)
		if not sl.open:
			_text(h, "LV %d" % sl.unlock, Vector2(r.position.x, r.position.y + 44), 16, Color(ink, 0.7), sw)
		h.draw_rect(r, Color(0.75, 0.55, 1.0) if dark else (accent if sl.open else Color(ink, 0.3)), false, 2.0)
		_text(h, sl.key, Vector2(r.position.x + 4, r.position.y + 16), 16, col("prompt_key"))
		var fs := 12 if FONT.get_string_size(str(sl.name), HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x <= cellw - 6 else 10
		_text(h, sl.name, Vector2(x0 + i * cellw, r.position.y + sw + 18), fs, Color(ink, 0.9 if sl.open else 0.45), cellw)


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
		return key_color[d.key]
	if d.kind == "puzzle" and _door_closed(d):
		return Color("#f2c14e")
	if d.kind == "boss" and _door_closed(d):
		return Color("#d8382a")
	return col("door")


func _draw_map(h: Control, screen: Vector2, big: bool) -> void:
	var known := Rules.known_rooms(W.doors, state.visited)
	var s: float = minf((screen.x - 60.0) / W.cols, (screen.y - 110.0) / W.rows) if big else minf(250.0 / W.cols, 170.0 / W.rows)
	var mw: float = W.cols * s
	var mh: float = W.rows * s
	var origin := Vector2((screen.x - mw) / 2.0, (screen.y - mh) / 2.0 + 10.0) if big else Vector2(screen.x - mw - 16.0, 16.0)
	if big:
		h.draw_rect(Rect2(Vector2.ZERO, screen), Color(0.03, 0.01, 0.02, 0.93))
		_text(h, "%s · Etage %d" % [W.title, state.floor], Vector2(0, 40), 32, gold, screen.x)
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
		var fill := col("map_here") if here else (col("map_cleared") if seen and r.cleared else (col("map_seen") if seen else Color(0.18, 0.11, 0.13, 0.45)))
		for rect: Rect2 in minimap[r.index].rects:
			h.draw_rect(rect, fill)
		h.draw_multiline(minimap[r.index].edges, accent if here else (col("map_edge_seen") if seen else col("map_edge")), (2.4 if here else 1.2) / s)
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
		var im: Texture2D = tex[key_sprite[r.icon_key] if icon == "key" and key_sprite.has(r.icon_key) else icon]
		var c := origin + Vector2(r.bx + r.bw / 2.0, r.by + r.bh / 2.0) * s
		var sz := Vector2(isz, isz * im.get_height() / im.get_width())
		h.draw_texture_rect(im, Rect2(c - sz / 2.0, sz), false, key_tint.get(r.icon_key, Color.WHITE))
		var room_w: float = r.bw * s
		if big and FONT.get_string_size(r.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x < room_w:
			_text(h, r.name, Vector2(c.x - room_w / 2.0, c.y + isz * 0.9), 16, ink, room_w)
	if big:
		_text(h, "Hell: besucht · Türen rot: verriegelt · farbig: Schlüssel · gelb: Rätsel · M schließt", Vector2(0, screen.y - 12), 16, Color("#b89c8e"), screen.x)
	h.draw_circle(origin + Vector2(player.x, player.y - 20) / C * s, 6.0 if big else 3.0, Color("#fff1c2"))
