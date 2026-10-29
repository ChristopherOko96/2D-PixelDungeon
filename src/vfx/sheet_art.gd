extends RefCounted
## Client art of the sheet monsters (src/combat/sheet_monsters.gd), ported from
## codex/0x72-dungeon: 0x72 mobs from their idle/run frames, orcs and bosses
## from full five-row sheets (idle, run, attack, hit, death; attack, hit and
## death were derived from the 0x72 frames, the bosses add pixel parts), the
## mobs' attack telegraphs, the floor hazards and the special projectiles.
## Presentation only; it draws on the dungeon view and uses its sprite helpers.

const SPRITE_ROOT := "res://assets/sprites/0x72/"
const GOLEM_ROOT := "res://assets/sprites/golem/"
const INFERNAL_ROOT := "res://assets/sprites/infernal/"
const ARROW_TEXTURE := preload("res://assets/sprites/0x72/weapon_arrow.png")
## Mobs drawn from 0x72 idle/run frames (kind -> 0x72 sprite name).
const MOB_SPRITES := {"chaser": "goblin", "imp": "imp", "skelet": "skelet", "chort": "chort", "wogol": "wogol",
	"doc": "doc", "pumpkin_dude": "pumpkin_dude", "big_zombie": "big_zombie", "angel": "angel"}
## Kinds drawn from five-row sheets: kind -> [folder under assets/sprites, sheet, pixel scale].
const SHEET_KINDS := {"shooter": ["orcs_0x72", "orc_shaman", 2.0], "o_brute": ["orcs_0x72", "orc_warrior", 2.0],
	"o_berserker": ["orcs_0x72", "masked_orc", 2.0], "o_chieftain": ["orcs_0x72", "ogre", 2.0],
	"seraph": ["bosses_0x72", "seraph", 3.0], "rot_king": ["bosses_0x72", "rot_king", 2.0], "hell_prince": ["bosses_0x72", "hell_prince", 2.0],
	"ogre_warchief": ["bosses_0x72", "ogre_warchief", 2.0], "winged_chort": ["bosses_0x72", "winged_chort", 3.0],
	"soul_caller": ["bosses_0x72", "soul_caller", 3.0], "crystal_wogol": ["bosses_0x72", "crystal_wogol", 3.0],
	"golden_angel": ["bosses_0x72", "golden_angel", 3.0]}
## Burst frames per hazard kind: [frame set, animation, scale].
const HAZARD_BURSTS := {"quake": ["golem", "quake_burst", 0.55], "blast": ["golem", "blast", 0.63], "thorns": ["golem", "thorns", 0.63],
	"fire": ["glutling", "fire_patch", 0.7], "lava": ["fackelteufel", "flame_pillar", 0.8], "flame": ["fackelteufel", "flame_pillar", 0.9],
	"blood": ["blutqualle", "blood_pillar", 0.9], "spike": ["krabbenteufel", "spikes", 0.7], "void": ["schattling", "void_cloud", 0.8]}
const HAZARD_COLORS := {"quake": Color("#7fe8e0"), "fire": Color("#ff8a3c"), "lava": Color("#ff6a2a"), "flame": Color("#ff9a3c"),
	"blood": Color("#d8484f"), "spike": Color("#b8a89a"), "void": Color("#a77be8")}
## Projectile styles this module draws (the view keeps its own for the rest).
const SHOT_STYLES := ["spear", "flail", "wave", "fireball", "bigfire", "flame", "void", "slash", "rock", "bolt", "magic", "shard", "orc_arrow"]
const INK := Color("#10101c")
const WARN := Color("#ff4a4a")

## kind -> {"idle", "walk", "windup", "strike", "hit", "death": Array[Texture2D]}.
var _frames: Dictionary = {}
## kind -> pixel scale of its art.
var _scales: Dictionary = {}
var _golem: Dictionary = {}
var _infernal: Dictionary = {}
var ready := false


## Loads every frame once; `flash_textures` (texture -> white silhouette) and
## `silhouette` (Callable(texture) -> Texture2D) come from the view, so hit
## flashes work like on every other sprite.
func prepare(flash_textures: Dictionary, silhouette: Callable) -> void:
	if ready: return
	for kind: String in MOB_SPRITES:
		var name: String = MOB_SPRITES[kind]
		var sets := {"idle": [], "walk": []}
		for state: String in ["idle", "run"]:
			for frame in range(4):
				var path := "%s%s_%s_anim_f%d.png" % [SPRITE_ROOT, name, state, frame]
				if ResourceLoader.exists(path): sets["idle" if state == "idle" else "walk"].append(load(path))
		if sets.idle.is_empty(): continue
		_frames[kind] = sets
		_scales[kind] = 2.0
	var manifests := {}
	for kind: String in SHEET_KINDS:
		var folder: String = "res://assets/sprites/%s/" % SHEET_KINDS[kind][0]
		var sheet: String = SHEET_KINDS[kind][1]
		if not manifests.has(folder):
			manifests[folder] = JSON.parse_string(FileAccess.get_file_as_string(folder + "manifest.json")) if FileAccess.file_exists(folder + "manifest.json") else {}
		var sheets: Variant = manifests[folder]
		if not (sheets is Dictionary and sheets.has(sheet)): continue
		var anims := {}
		for row: Array in sheets[sheet].rows:
			var list: Array = []
			for frame in range(int(row[1])):
				list.append(load("%sframes/%s_%s_anim_f%d.png" % [folder, sheet, row[0], frame]))
			anims[row[0]] = list
		_frames[kind] = {"idle": anims.idle, "walk": anims.run, "windup": anims.attack.slice(0, 2),
			"strike": anims.attack.slice(2, 4), "hit": anims.hit, "death": anims.death}
		_scales[kind] = float(SHEET_KINDS[kind][2])
	for sets: Dictionary in _frames.values():
		for list: Array in sets.values():
			for texture: Texture2D in list:
				if not flash_textures.has(texture): flash_textures[texture] = silhouette.call(texture)
	var golem: Variant = JSON.parse_string(FileAccess.get_file_as_string(GOLEM_ROOT + "manifest.json")) if FileAccess.file_exists(GOLEM_ROOT + "manifest.json") else null
	if golem is Dictionary:
		for animation: String in golem:
			var frames: Array = []
			for frame in range(int(golem[animation].frames)): frames.append(load("%s%s_f%d.png" % [GOLEM_ROOT, animation, frame]))
			_golem[animation] = frames
	var infernal: Variant = JSON.parse_string(FileAccess.get_file_as_string(INFERNAL_ROOT + "manifest.json")) if FileAccess.file_exists(INFERNAL_ROOT + "manifest.json") else null
	if infernal is Dictionary:
		for creature: String in infernal:
			var sets := {}
			for animation: String in infernal[creature]:
				var frames: Array = []
				for frame in range(int(infernal[creature][animation].frames)): frames.append(load("%s%s/%s_f%d.png" % [INFERNAL_ROOT, creature, animation, frame]))
				sets[animation] = frames
			_infernal[creature] = sets
	ready = true


## Whether this module has art for `kind`.
func has_kind(kind: String) -> bool:
	return _frames.has(kind)


## Draws one sheet monster: the frame for its state, rage/haste marks, the
## telegraph and (for ordinary monsters) a small health bar.
func draw_enemy(view: CanvasItem, enemy: Dictionary, clock: float) -> void:
	var kind := str(enemy.get("kind", ""))
	if not _frames.has(kind): return
	var sets: Dictionary = _frames[kind]
	var point: Vector2 = view._position(enemy).round()
	var id: int = int(enemy.get("id", 0))
	var attack := str(enemy.get("attack", ""))
	var dying_p: float = float(enemy.get("dying_p", -1.0))
	var dying: bool = dying_p >= 0.0
	var texture: Texture2D
	if dying and sets.has("death"):
		texture = _pick(sets.death, dying_p / 0.7)
	elif sets.has("hit") and bool(enemy.get("hit", false)): texture = sets.hit[int(clock * 12.0) % sets.hit.size()]
	elif attack == "windup" and sets.has("windup"): texture = _pick(sets.windup, float(enemy.get("attack_p", 0.0)))
	elif attack == "active" and sets.has("strike"): texture = sets.strike[0]
	elif attack == "recovery" and sets.has("strike"): texture = sets.strike[sets.strike.size() - 1]
	elif bool(enemy.get("moving", false)) or bool(enemy.get("dash", false)): texture = sets.walk[(int(clock * 10.0) + id) % sets.walk.size()]
	else: texture = sets.idle[(int(clock * 5.0) + id) % sets.idle.size()]
	if not dying: _draw_telegraph(view, enemy, point, clock)
	var pose: Dictionary = view._feedback.pose("e%d" % id, enemy, clock)
	var radius: float = float(enemy.get("radius", 14.0))
	if bool(enemy.get("raging", false)) and not dying:
		view.draw_circle(point, radius + 4.0, Color(1.0, 0.2, 0.1, 0.22))
	if bool(enemy.get("hasted", false)) and not dying:
		view._box(point.x - 10 + roundf(sin(clock * 30.0 + id) * 8.0), point.y + 10, 3, 3, Color("#ffd76a"))
	var pixel_scale: float = float(_scales.get(kind, 2.0))
	var feet: float = radius * 0.6 + 6.0
	view._draw_sprite(texture, point, float(enemy.get("face", -1.0)), feet, pose, pixel_scale)
	var hp: float = float(enemy.get("hp", 1.0))
	var max_hp: float = maxf(float(enemy.get("max_hp", hp)), 1.0)
	# Bosses and mini-bosses show their health in the run HUD's top bar.
	var big: bool = bool(enemy.get("boss", false)) or bool(enemy.get("miniboss", false))
	if not dying and hp < max_hp and not big:
		var bar_y: float = point.y + feet - float(texture.get_height()) * pixel_scale * float(Vector2(pose.get("scale", Vector2.ONE)).y) - 6.0
		view._box(point.x - 15, bar_y - 2, 30, 7, INK)
		view._box(point.x - 13, bar_y, 26, 3, Color("#5e354d"))
		view._box(point.x - 13, bar_y, floorf(26.0 * clampf(hp / max_hp, 0.0, 1.0)), 3, Color("#ef8a9a"))


## Windup warnings of dash, cleave and pound, and the necromancer's circle.
func _draw_telegraph(view: CanvasItem, enemy: Dictionary, point: Vector2, clock: float) -> void:
	if str(enemy.get("attack", "")) != "windup": return
	var p: float = float(enemy.get("attack_p", 0.0))
	var aim := Vector2(float(enemy.get("aim_x", 1.0)), float(enemy.get("aim_y", 0.0))).normalized()
	var blink: float = 0.2 if p > 0.7 and fmod(clock, 0.1) < 0.05 else 0.0
	var big: bool = bool(enemy.get("boss", false)) or bool(enemy.get("miniboss", false))
	match str(enemy.get("pattern", "")):
		"dash":
			var width: float = float(enemy.get("radius", 12.0)) * 0.9 if big else 10.0
			view.draw_line(point + Vector2(0, 8), point + Vector2(0, 8) + aim * (220.0 if big else 140.0), Color(WARN, 0.15 + 0.35 * p + blink), width)
		"cleave":
			var reach: float = 90.0 if big else 72.0
			var cone := PackedVector2Array([point])
			for k in range(9): cone.append(point + aim.rotated(-1.0 + 2.0 * k / 8.0) * reach)
			view.draw_colored_polygon(cone, Color(WARN, 0.08 + 0.22 * p + blink))
		"pound":
			view.draw_arc(point + Vector2(0, 8), 60.0, 0.0, TAU, 40, Color(WARN, 0.25 + 0.45 * p + blink), 2.0)
			view.draw_circle(point + Vector2(0, 8), 60.0 * p, Color(WARN, 0.1))
		"summon":
			view.draw_arc(point + Vector2(0, 12), 16.0 + 14.0 * p, 0.0, TAU, 24, Color("#a77be8", 0.3 + 0.5 * p), 2.0)
			view.draw_arc(point + Vector2(0, 12), 30.0 - 10.0 * p, clock * 3.0, clock * 3.0 + PI, 12, Color("#d6b3ff", 0.6 * p), 2.0)


## Floor hazards. `over` false draws warnings, armed traps and boulder shadows
## on the floor; true draws bursts, the flying boulder and the spinning axe.
func draw_hazards(view: CanvasItem, hazards: Array, over: bool, clock: float) -> void:
	for value: Variant in hazards:
		var hazard: Dictionary = value
		var point := Vector2(float(hazard.get("x", 0.0)), float(hazard.get("y", 0.0)))
		var kind := str(hazard.get("k", ""))
		var state := str(hazard.get("s", ""))
		var p: float = float(hazard.get("p", 0.0))
		var radius: float = float(hazard.get("r", 30.0))
		if not over:
			if state == "warn":
				var color: Color = HAZARD_COLORS.get(kind, Color("#9be05a"))
				view.draw_circle(point, radius, Color(color, 0.08 + 0.22 * p))
				view.draw_arc(point, radius, 0.0, TAU, 28, Color(color, 0.5 + 0.4 * p), 2.0)
				view.draw_arc(point, maxf(3.0, radius * (1.0 - p)), 0.0, TAU, 20, Color(1, 1, 1, 0.5 * p), 1.5)
			elif state == "armed":
				# A set trap: a dark iron ring with teeth.
				view.draw_arc(point, radius * 0.7, 0.0, TAU, 16, INK, 4.0)
				view.draw_arc(point, radius * 0.7, 0.0, TAU, 16, Color("#8a8a96"), 2.0)
				for k in range(6):
					var tooth := point + Vector2.RIGHT.rotated(TAU * k / 6.0) * radius * 0.5
					view._box(tooth.x - 1, tooth.y - 1, 2, 2, Color("#c8c8d2"))
			elif state == "fly":
				var goal := Vector2(float(hazard.get("gx", point.x)), float(hazard.get("gy", point.y)))
				view.draw_circle(goal, radius, Color(WARN, 0.06 + 0.2 * p))
				view.draw_arc(goal, radius, 0.0, TAU, 32, Color(WARN, 0.6), 2.0)
				view.draw_arc(goal, maxf(4.0, radius * (1.0 - p)), 0.0, TAU, 28, Color("#ffd2a0", 0.7), 2.0)
				view._box(point.x - 10, point.y + 4, 20, 5, Color(0.05, 0.04, 0.09, 0.4))
			continue
		match state:
			"burst":
				if kind in ["arcane", "fire_burst"] or kind == "trap":
					var color: Color = Color("#7ff0a0") if kind == "arcane" else Color("#ff9a3c") if kind == "fire_burst" else Color("#c8c8d2")
					view.draw_circle(point, radius * (0.4 + 0.6 * p), Color(color, 0.25 * (1.0 - p)))
					view.draw_arc(point, radius * (0.4 + 0.6 * p), 0.0, TAU, 24, Color(color, 1.0 - p), 3.0)
					continue
				var spec: Array = HAZARD_BURSTS.get(kind, HAZARD_BURSTS.thorns)
				var source: Dictionary = _golem if spec[0] == "golem" else _infernal.get(spec[0], {})
				var frames: Array = source.get(spec[1], [])
				if frames.is_empty(): continue
				var texture: Texture2D = frames[mini(int(p * frames.size()), frames.size() - 1)]
				var size := Vector2(texture.get_width(), texture.get_height()) * float(spec[2])
				# Bursts rise out of the floor: a quick grow, then fade.
				size *= Vector2(1.0, 0.6 + 0.4 * smoothstep(0.0, 0.25, p))
				view.draw_texture_rect(texture, Rect2(point - Vector2(size.x * 0.5, size.y * (0.5 if kind == "blast" else 0.85)), size), false, Color(1, 1, 1, 1.0 - smoothstep(0.6, 1.0, p)))
			"fly":
				var lift: float = sin(PI * p) * 70.0
				var frames: Array = _golem.get("boulder", [])
				if frames.is_empty(): continue
				var texture: Texture2D = frames[mini(int(p * frames.size()), frames.size() - 1)]
				var size := Vector2(texture.get_width(), texture.get_height()) * 0.8
				view.draw_set_transform(point - Vector2(0, lift), clock * 8.0, Vector2.ONE)
				view.draw_texture_rect(texture, Rect2(-size * 0.5, size), false)
				view.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			"out", "back":
				var spin: Array = _golem.get("axe_spin", [])
				if spin.is_empty(): continue
				var texture: Texture2D = spin[0]
				var size := Vector2(texture.get_width(), texture.get_height()) * 0.7
				view.draw_circle(point, 20.0, Color("#7fe8e0", 0.15))
				view.draw_set_transform(point, clock * 18.0, Vector2.ONE)
				view.draw_texture_rect(texture, Rect2(-size * 0.5, size), false)
				view.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Draws an enemy projectile of one of SHOT_STYLES; false for other styles.
func draw_bullet(view: CanvasItem, bullet: Dictionary, point: Vector2, clock: float) -> bool:
	var kind := str(bullet.get("style", ""))
	if int(bullet.get("owner", 0)) != 0 or kind not in SHOT_STYLES: return false
	var angle: float = Vector2(float(bullet.get("vx", 1)), float(bullet.get("vy", 0))).angle()
	match kind:
		"magic", "shard":
			var core := Color("#7ff0a0")
			var radius: float = 3.0 if kind == "shard" else 6.0 + sin(clock * 20.0)
			view.draw_circle(point, radius * 2.2, Color(core, 0.2))
			view.draw_circle(point, radius, core)
			view.draw_circle(point, radius * 0.45, Color.WHITE)
			return true
		"orc_arrow":
			var size := Vector2(ARROW_TEXTURE.get_width(), ARROW_TEXTURE.get_height()) * 1.4
			view.draw_set_transform(point, angle + PI * 0.5, Vector2.ONE)
			view.draw_texture_rect(ARROW_TEXTURE, Rect2(-size * 0.5, size), false, Color(1.0, 0.75, 0.6))
			view.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			return true
		"spear":
			var along := Vector2.RIGHT.rotated(angle)
			view.draw_line(point - along * 16.0, point + along * 6.0, INK, 4.0)
			view.draw_line(point - along * 16.0, point + along * 6.0, Color("#8a5a32"), 2.0)
			view.draw_colored_polygon(PackedVector2Array([point + along * 12.0, point + along * 4.0 + along.orthogonal() * 4.0, point + along * 4.0 - along.orthogonal() * 4.0]), Color("#d8dce6"))
			return true
		"flail":
			view._box(point.x - 4, point.y - 4, 8, 8, INK)
			view._box(point.x - 3, point.y - 3, 6, 6, Color("#6a6a74"))
			view._box(point.x - 1, point.y - 5, 2, 10, Color("#9a9aa4"))
			view._box(point.x - 5, point.y - 1, 10, 2, Color("#9a9aa4"))
			return true
		"wave":
			var along := Vector2.RIGHT.rotated(angle)
			view.draw_arc(point - along * 8.0, 18.0, angle - 1.0, angle + 1.0, 12, Color("#bff6ff", 0.9), 4.0)
			view.draw_arc(point - along * 10.0, 18.0, angle - 0.8, angle + 0.8, 10, Color.WHITE, 2.0)
			return true
		"bolt":
			view.draw_circle(point, 8.0, Color("#9be05a", 0.25))
			view._box(point.x - 4, point.y - 4, 8, 8, INK)
			view._box(point.x - 3, point.y - 3, 6, 6, Color("#9be05a"))
			view._box(point.x - 1, point.y - 2, 2, 2, Color("#eaffd0"))
			return true
	var sprite: Array = []
	match kind:
		"fireball": sprite = ["fackelteufel", "fireball", 0.5]
		"bigfire": sprite = ["molgrax", "fireball", 0.45]
		"flame": sprite = ["fackelteufel", "fireball", 0.32]
		"void": sprite = ["schattling", "void_orb", 0.6]
	if not sprite.is_empty() and _infernal.has(sprite[0]) and _infernal[sprite[0]].has(sprite[1]):
		var texture: Texture2D = _infernal[sprite[0]][sprite[1]][0]
		var size := Vector2(texture.get_width(), texture.get_height()) * float(sprite[2])
		# The art flies to the right with its tail behind; turn it along the flight.
		view.draw_set_transform(point, angle, Vector2.ONE)
		view.draw_texture_rect(texture, Rect2(Vector2(-size.x * 0.8, -size.y * 0.5), size), false)
		view.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return true
	var frames: Array = _golem.get("slash" if kind == "slash" else "spike", [])
	if kind in ["slash", "rock"] and not frames.is_empty():
		var texture: Texture2D = frames[0]
		var size := Vector2(texture.get_width(), texture.get_height()) * (0.55 if kind == "slash" else 0.45)
		view.draw_set_transform(point, angle if kind == "slash" else clock * 10.0, Vector2.ONE)
		view.draw_texture_rect(texture, Rect2(-size * 0.5, size), false)
		view.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return true
	view._box(point.x - 3, point.y - 3, 6, 6, Color("#f19791"))
	return true


func _pick(frames: Array, progress: float) -> Texture2D:
	return frames[clampi(int(progress * frames.size()), 0, frames.size() - 1)]
