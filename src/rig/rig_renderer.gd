extends RefCounted
## Presentation of the part rigs in the dungeon view. Reads only snapshot
## fields (attack phase and progress, hit/block counters, dying progress, lost
## parts, beam, fx events) and owns no game decisions. Keeps per-actor clip
## state, falling debris of detached parts, particles, summoning pools and
## void effects, and reports the lights they cast for the dark crypt. Hell
## rigs (rig.material) add glowing parts, a glowing wound at every severed
## joint, debris and chips in their material (vfx_gore.json, see palette),
## a stagger when a part is cut off and the tail whirl's spin (whole.turn).
## Ignaroth (src/hell/drake_rig_host.gd) also draws grown or shrunk (size),
## sunk into the floor (cut) and without the rig's shadow, and tests his hits
## against the pose last drawn (part_transforms).

const RigLibrary = preload("res://src/rig/rig_library.gd")
const RigPoses = preload("res://src/rig/rig_poses.gd")
const S := RigLibrary.PIXEL_SCALE
const SHADOW := Color(0.05, 0.04, 0.09, 0.45)
const VIOLET := Color("a46fe0")
const VIOLET_DARK := Color("5f2d56")
## Pixel flames of a burning rig (rigs.json "burn"), hot to cool: white, yellow, orange, red, crimson.
const FLAME := [Color("fdf7ed"), Color("facb3e"), Color("ee8e2e"), Color("da4e38"), Color("9f294e")]
## Soul fire (a flame's 6th entry "soul") and void fire ("void"), hot to cool.
const SOUL_FLAME := [Color("fdf7ed"), Color("cfe86b"), Color("97da3f"), Color("4ba747"), Color("235d3a")]
## Pixel slash palettes (rigs.json "slash"), newest to oldest: the band a
## swinging blade sweeps, and how long its pixels stay (s).
const SLASH := {
	"fire": [Color("fdf7ed"), Color("facb3e"), Color("ee8e2e"), Color("da4e38")],
	"void": [Color("fdf7ed"), Color("f0b3dd"), Color("c278d0"), Color("8156aa")],
	"soul": [Color("fdf7ed"), Color("cfe86b"), Color("97da3f"), Color("4ba747")],
	"steel": [Color("fdf7ed"), Color("b6cbcf"), Color("7b8994"), Color("414859")],
}
const SLASH_LIFE := 0.2
const VOID_FLAME := [Color("fdf7ed"), Color("f0b3dd"), Color("c278d0"), Color("8156aa"), Color("473579")]
const VIOLET_HOT := Color("f2b8ff")
const INK := Color("222222")
## The gore table (src/vfx/feedback.gd): a hell rig's material (rig.material)
## names one of its materials, whose color and stain are the cut chips, so a
## part cut off sprays what a hit on the same monster sprays.
const GORE_PATH := "res://assets/data/vfx_gore.json"
## What a hell material's palette takes from here when vfx_gore.json does not
## give it (optional keys there: glow, wound [3 hex], burst): the glow of
## glowing parts, cut embers and hot debris, the wound left at a severed joint
## (dark rim, hot rim, core) and the death burst; color and stain stand in when
## the table is missing. Obsidian glows hot violet-pink so the void crystals'
## flare reads over their dark violet.
const MATERIALS := {
	"ember": {"color": Color("ff8a3d"), "stain": Color("3a2418"), "glow": Color("ffb347"),
		"wound": [Color("3a1408"), Color("ff7a1c"), Color("ffe08a")], "burst": Color("ff8a3c")},
	"obsidian": {"color": Color("2a1240"), "stain": Color("5f2d56"), "glow": Color("f2b8ff"),
		"wound": [Color("1a0b2a"), Color("a46fe0"), Color("f4c64e")], "burst": Color("a46fe0")},
}
## Ignaroth's parts that fall off as debris when the dragon dies.
const DRAKE_SHED: Array[String] = ["wing_far", "wing_near", "horns", "jaw", "crystal_1", "crystal_2", "crystal_3", "tail_2", "tail_3", "tail_4", "tail_5", "tail_flame"]
const HIT_TIME := 0.3
## A hell rig staggers this long when one of its parts is cut off.
const STAGGER_TIME := 1.0
const BLOCK_TIME := 0.9
const RISE_TIME := 1.1
const REGROW_TIME := 1.2

var library: RefCounted
var _actors: Dictionary = {}
var _debris: Array[Dictionary] = []
var _particles: Array[Dictionary] = []
var _pools: Array[Dictionary] = []
var _flashes: Array[Dictionary] = []
var _beams: Array[Dictionary] = []
var _fx_seen: Dictionary = {}
var _clock := 0.0
## Beams drawn in the last draw_over (for tests and capture checks).
var beams_drawn := 0
## Hero walk cycle in seconds when a snapshot has no step_time (two footfalls).
const WALK_CYCLE := 0.42
## Actor keys of heroes whose foot touched down since the view last took them.
var footfalls: Array[String] = []
## Test and capture spy: while true, every texture and box an actor is drawn
## with is appended to draw_log as {what, id, color} with the very colour
## handed to the canvas (what: shadow, part, glow, flash, aura, stump).
var record_draws := false
## See record_draws; the caller clears it.
var draw_log: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()
static var _gore_materials: Dictionary = {}
static var _gore_loaded := false
static var _palettes: Dictionary = {}


func _init(rig_library: RefCounted = null) -> void:
	library = rig_library if rig_library != null else RigLibrary.shared()
	_rng.seed = 90210


## True when the rig data loaded; otherwise the view keeps its old sprites.
func is_ready() -> bool:
	return library != null and library.ready


## Loads the gore table's materials (vfx_gore.json) and forgets the palettes
## built so far; a missing or broken file leaves the MATERIALS fallbacks.
## Runs on first use; tests call it with another path.
static func load_gore(path: String = GORE_PATH) -> void:
	_palettes.clear()
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
	var materials: Variant = parsed.get("materials", {}) if parsed is Dictionary else {}
	_gore_materials = materials if materials is Dictionary else {}
	_gore_loaded = true


## The colours of a hell rig material: chips [color, stain, glow] sprayed by
## a cut, glow (glowing parts, cut embers, hot debris), wound [dark rim, hot
## rim, core] at a severed joint and the death burst. vfx_gore.json
## materials[material] gives color and stain and may give glow, wound and
## burst; MATERIALS fills the rest, else they derive from the table colours.
## Empty for a material that neither knows (crypt rigs have none).
static func palette(material: String) -> Dictionary:
	if material.is_empty(): return {}
	if not _gore_loaded: load_gore()
	if _palettes.has(material): return _palettes[material]
	var table: Dictionary = _gore_materials.get(material, {}) if _gore_materials.get(material) is Dictionary else {}
	var fallback: Dictionary = MATERIALS.get(material, {})
	if table.is_empty() and fallback.is_empty(): return {}
	var color := _hex(table.get("color"), fallback.get("color", Color.WHITE))
	var stain := _hex(table.get("stain"), fallback.get("stain", color.darkened(0.6)))
	var glow := _hex(table.get("glow"), fallback.get("glow", color.lightened(0.35)))
	var wound: Array = fallback.get("wound", [stain.darkened(0.4), color, glow])
	var listed: Variant = table.get("wound")
	if listed is Array and listed.size() >= 3: wound = [_hex(listed[0], wound[0]), _hex(listed[1], wound[1]), _hex(listed[2], wound[2])]
	var result := {"chips": [color, stain, glow], "glow": glow, "wound": wound, "burst": _hex(table.get("burst"), fallback.get("burst", color))}
	_palettes[material] = result
	return result


## A colour from the gore table: a Color, or a hex string ("e0603a"); else `fallback`.
static func _hex(value: Variant, fallback: Color) -> Color:
	if value is Color: return value
	if value is String and Color.html_is_valid(value): return Color.html(value)
	return fallback


## Clears every actor, debris piece and effect (new run or room).
func reset() -> void:
	_actors.clear()
	_debris.clear()
	_particles.clear()
	_pools.clear()
	_flashes.clear()
	_beams.clear()
	_fx_seen.clear()


## Reads one snapshot: lost parts become debris (a hell rig staggers),
## regrown parts scale back in, counters start hit/block clips, new summons
## rise, fx events play once. The same uid in another rig (Ignaroth's next
## form) or back from dying starts complete: nothing lost, shed or regrowing.
func observe(snapshot: Dictionary) -> void:
	if not is_ready(): return
	var seen: Dictionary = {}
	for enemy: Dictionary in snapshot.get("enemies", []):
		var rig_name := str(enemy.get("rig", ""))
		if rig_name.is_empty(): continue
		var key := _key(enemy)
		seen[key] = true
		var fresh := not _actors.has(key)
		var a := _actor(key, enemy)
		var rig: Dictionary = library.rig(rig_name)
		var dying_now := float(enemy.get("dying_p", -1.0)) >= 0.0
		var seen_rig := str(a.get("rig_seen", ""))
		var renewed := (not seen_rig.is_empty() and seen_rig != rig_name) or (bool(a.dying) and not dying_now)
		if renewed: _renew(a)
		a.rig_seen = rig_name
		if fresh and bool(enemy.get("summoned", false)) and not dying_now: _start_rise(a, rig, enemy)
		var staggering: bool = str(a.clip) == "hit" and float(a.clip_len) - float(a.ct) > HIT_TIME
		if int(enemy.get("hits", 0)) > int(a.hits) and str(enemy.get("attack", "")).is_empty() and not dying_now and not staggering: _play(a, "hit", HIT_TIME)
		if int(enemy.get("blocks", 0)) > int(a.blocks): _play(a, "block", BLOCK_TIME)
		a.hits = int(enemy.get("hits", 0))
		a.blocks = int(enemy.get("blocks", 0))
		var lost: Dictionary = {}
		for id: Variant in enemy.get("lost", []): lost[str(id)] = true
		var severed := false
		for id: String in lost:
			if not a.lost.has(id) and not fresh and not renewed:
				_detach(a, rig, id, 1.0)
				severed = true
		var colors := palette(str(rig.get("material", "")))
		for id: String in a.lost:
			if not lost.has(id):
				a.regrowing[id] = REGROW_TIME
				_debris = _debris.filter(func(d: Dictionary) -> bool: return not (d.key == a.key and d.id == id))
				var regrow_color: Color = colors.glow if not colors.is_empty() else VIOLET if rig_name in ["void", "bomber"] else Color("97da3f")
				_burst_at(Vector2(a.get("feet", Vector2(float(enemy.get("x", 0)), float(enemy.get("y", 0))))) - Vector2(0, 24), regrow_color, 12, 60.0)
		a.lost = lost
		# A hell rig reels for a moment when a part is cut off (PART-03).
		if severed and not dying_now and not colors.is_empty(): _play(a, "hit", STAGGER_TIME)
		if dying_now and not bool(a.dying): _start_death(a, rig, enemy)
	for key: String in _actors.keys():
		if str(key).begins_with("e") and not seen.has(key): _actors.erase(key)
	for event: Dictionary in snapshot.get("fx_events", []):
		var id := int(event.get("id", 0))
		if _fx_seen.has(id): continue
		_fx_seen[id] = true
		_play_fx(event)
	if _fx_seen.size() > 256: _fx_seen.clear()


func _actor(key: String, entity: Dictionary) -> Dictionary:
	if not _actors.has(key):
		_actors[key] = {"key": key, "t": _rng.randf_range(0.0, 3.0), "clip": "", "ct": 0.0, "clip_len": 0.0, "hits": int(entity.get("hits", 0)), "blocks": int(entity.get("blocks", 0)),
			"hurts": int(entity.get("hurts", 0)), "lost": {}, "regrowing": {}, "dying": false, "rise": 0.0, "rise_from": {}, "world": {}, "trail": [], "dead_at": -1.0,
			"shed": {}, "drawn": {}}
	return _actors[key]


## Actor key of an enemy: "e" + its uid (hell monsters carry a string id and an
## int uid), else its int id (crypt enemies).
static func _key(enemy: Dictionary) -> String:
	return "e%d" % int(enemy.get("uid", enemy.get("id", 0)))


## The view's actor key of `enemy` (part_transforms, world_point, last_drawn,
## debris_of take it): "e" + its uid, else its int id.
static func key_of(enemy: Dictionary) -> String:
	return _key(enemy)


## The debris pieces actor `key` left on the floor ({id, key, material, ...},
## copies): what tests and capture checks read of the cut parts.
func debris_of(key: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for d: Dictionary in _debris:
		if str(d.get("key", "")) == key: out.append(d.duplicate())
	return out


## A Color from a snapshot field: a Color, or an [r, g, b(, a)] array.
static func _color_of(value: Variant, fallback: Color = Color.WHITE) -> Color:
	if value is Color: return value
	if value is Array and value.size() >= 3: return Color(float(value[0]), float(value[1]), float(value[2]), float(value[3]) if value.size() > 3 else 1.0)
	return fallback


func _play(a: Dictionary, clip: String, length: float) -> void:
	a.clip = clip
	a.ct = 0.0
	a.clip_len = length


## A figure that comes back whole (new form, back from dying): forget lost,
## regrowing and shed parts, the death and any clip, and the old placement.
func _renew(a: Dictionary) -> void:
	a.lost = {}
	a.regrowing = {}
	a.shed = {}
	a.dying = false
	a.clip = ""
	a.ct = 0.0
	a.clip_len = 0.0
	a.u = 0.0
	a.world = {}
	a.drawn = {}
	a.trail = []


## Advances clocks, clips, regrowth, debris physics and effects.
func step(delta: float) -> void:
	_clock += delta
	for a: Dictionary in _actors.values():
		a.t = float(a.t) + delta
		a.ct = float(a.ct) + delta
		if not str(a.clip).is_empty() and float(a.clip_len) > 0.0 and float(a.ct) >= float(a.clip_len): a.clip = ""
		if float(a.rise) > 0.0: a.rise = maxf(0.0, float(a.rise) - delta)
		for id: String in a.regrowing.keys():
			a.regrowing[id] = float(a.regrowing[id]) - delta
			if float(a.regrowing[id]) <= 0.0: a.regrowing.erase(id)
		for point: Dictionary in a.trail: point.age = float(point.age) + delta
		a.trail = a.trail.filter(func(p: Dictionary) -> bool: return float(p.age) < float(p.get("life", 0.12)))
	for d: Dictionary in _debris:
		d.life = float(d.life) + delta
		if bool(d.rest): continue
		d.vz = float(d.vz) - 520.0 * delta
		d.z = float(d.z) + float(d.vz) * delta
		d.x = float(d.x) + float(d.vx) * delta
		d.ang = float(d.ang) + float(d.spin) * delta
		if float(d.z) <= 0.0:
			d.z = 0.0
			d.vz = -float(d.vz) * 0.35
			d.vx = float(d.vx) * 0.55
			d.spin = float(d.spin) * 0.45
			if absf(float(d.vz)) < 24.0:
				d.rest = true
				d.vz = 0.0
	_debris = _debris.filter(func(d: Dictionary) -> bool: return float(d.life) < float(d.max))
	for p: Dictionary in _particles:
		p.life = float(p.life) + delta
		p.x = float(p.x) + float(p.vx) * delta
		p.y = float(p.y) + float(p.vy) * delta
		p.vy = float(p.vy) + float(p.get("grav", 0.0)) * delta
	_particles = _particles.filter(func(p: Dictionary) -> bool: return float(p.life) < float(p.max))
	if _particles.size() > 900: _particles = _particles.slice(_particles.size() - 900)
	for pool: Dictionary in _pools: pool.life = float(pool.life) + delta
	_pools = _pools.filter(func(p: Dictionary) -> bool: return float(p.life) < float(p.max))
	for flash: Dictionary in _flashes: flash.life = float(flash.life) + delta
	_flashes = _flashes.filter(func(f: Dictionary) -> bool: return float(f.life) < float(f.max))


# ------------------------------------------------------------------ actors

## Draws one rigged enemy whose body centre is at `point`. Returns the screen
## y of the figure's top (for the health bar) or NAN when nothing was drawn.
## Optional enemy fields: "flying" (bool, the pose's flight), "tint" (Color or
## [r, g, b] multiplier on every part), "alpha" (multiplier on every part and
## the shadow), "hit_part" (the hit flash lights only that part while it
## is drawn), "size" (multiplier on the rig's scale: growing in, a new form
## swelling; `point` stays the body centre at that size), "cut" (world px:
## the figure sinks that far into the floor, shifted down and clipped at the
## feet, like a burrowing sprite) and "shadow" (false: the caller draws its own).
func draw_enemy(canvas: CanvasItem, enemy: Dictionary, point: Vector2) -> float:
	var rig_name := str(enemy.get("rig", ""))
	var rig: Dictionary = library.rig(rig_name)
	if rig.is_empty(): return NAN
	var a := _actor(_key(enemy), enemy)
	a.rig = rig_name
	a.moving = bool(enemy.get("moving", false))
	a.flying = bool(enemy.get("flying", false))
	a.tint = _color_of(enemy.get("tint", Color.WHITE))
	a.alpha_mul = float(enemy.get("alpha", 1.0))
	a.hit_part = str(enemy.get("hit_part", ""))
	a.size_mul = maxf(0.0, float(enemy.get("size", 1.0)))
	a.cut = maxf(0.0, float(enemy.get("cut", 0.0)))
	a.no_shadow = not bool(enemy.get("shadow", true))
	var face := -1.0 if float(enemy.get("face", -1.0)) < 0.0 else 1.0
	var dying_p := float(enemy.get("dying_p", -1.0))
	var family: String = str(rig.family)
	# Skeletons crumble and bombers burst: nothing is left to draw.
	if dying_p >= 0.0 and (family in ["skeleton", "bomber", "golem"]): return NAN
	_clip_from_snapshot(a, rig, enemy, dying_p)
	var flash := clampf(float(enemy.get("hit_flash", 0.0)) / 0.16, 0.0, 1.0)
	# An escaping or fading figure takes its shadow along.
	return _draw_rig(canvas, a, rig, point, face, flash, true, float(a.alpha_mul))


## The hero's walk cycle follows its speed: one foot touches down every
## step_time (snapshot), the legs swing over two of them, and every
## touch-down is reported once in `footfalls` for the step sound.
func track_steps(key: String, player: Dictionary) -> Dictionary:
	var a := _actor(key, player)
	a.moving = bool(player.get("moving", false))
	var step_time := clampf(float(player.get("step_time", WALK_CYCLE * 0.5)), 0.08, 0.6)
	a.cycle = step_time * 2.0
	var touch := floori(float(a.t) / step_time)
	if a.moving and touch != int(a.get("touch", touch)): footfalls.append(key)
	a.touch = touch
	return a


## Draws a hero-class player's body (the view draws the held weapon on top).
## `size` scales the rig (the story worlds draw heroes larger than the crypt),
## `tint` colours it (a subclass colour, stealth).
func draw_hero(canvas: CanvasItem, key: String, player: Dictionary, point: Vector2, rig_name: String, face: float, alpha: float = 1.0, size: float = 1.0, tint: Color = Color.WHITE) -> void:
	var rig: Dictionary = library.rig(rig_name)
	if rig.is_empty(): return
	var a := track_steps(key, player)
	a.rig = rig_name
	a.alpha_mul = alpha
	a.size_mul = size
	a.tint = tint
	if int(player.get("hurts", 0)) > int(a.hurts): _play(a, "hit", HIT_TIME)
	a.hurts = int(player.get("hurts", 0))
	if float(player.get("hp", 1)) <= 0.0:
		if float(a.dead_at) < 0.0: a.dead_at = _clock
		a.clip = "death"
		a.u = clampf((_clock - float(a.dead_at)) / 1.4, 0.0, 1.0)
	else:
		a.dead_at = -1.0
		if str(a.clip) == "death": a.clip = ""
		a.u = clampf(float(a.ct) / maxf(0.001, float(a.clip_len)), 0.0, 1.0) if not str(a.clip).is_empty() else 0.0
	_draw_rig(canvas, a, rig, point, face, 0.0, false, 1.0)


## Attack clips follow the host's attack phase so the strike lands on the
## active phase; death follows dying progress; hit/block/rise are local timers.
func _clip_from_snapshot(a: Dictionary, rig: Dictionary, enemy: Dictionary, dying_p: float) -> void:
	if dying_p >= 0.0:
		a.clip = "death"
		a.u = dying_p
		a.ct = float(a.ct)
		return
	if float(a.rise) > 0.0:
		a.clip = "rise"
		a.u = 1.0 - float(a.rise) / RISE_TIME
		return
	var phase := str(enemy.get("attack", ""))
	if not phase.is_empty():
		var mapping := _attack_mapping(rig, str(enemy.get("attack_kind", "")))
		var p := clampf(float(enemy.get("attack_p", 0.0)), 0.0, 1.0)
		var w_end: float = mapping[1]
		var a_end: float = mapping[2]
		a.u = w_end * p if phase == "windup" else lerpf(w_end, a_end, p) if phase == "active" else lerpf(a_end, 1.0, p)
		if str(a.clip) != str(mapping[0]): a.ct = 0.0
		a.clip = mapping[0]
		a.clip_len = 0.0
		a.windows = [w_end, a_end]
		return
	if str(a.clip) in ["hit", "block"]:
		a.u = clampf(float(a.ct) / maxf(0.001, float(a.clip_len)), 0.0, 1.0)
		return
	a.clip = ""
	a.u = 0.0


## Pixel flames on a burning rig, in each part's source pixels so they follow
## it (rigs.json "burn": "flames" [[part, x0, base_y, width, height], ...] rise
## from base_y; "glow" [[part, x, y], ...] are embers such as the eyes). The
## flames flicker at 12 frames a second, column by column, like hand-drawn pixel fire.
func _draw_burn(canvas: CanvasItem, rig: Dictionary, a: Dictionary, world: Dictionary, shown: Dictionary, alpha_of: Callable) -> void:
	var burn: Dictionary = rig.burn
	var tq := floorf(float(a.t) * 12.0) / 12.0
	var seed := float(int(a.get("seed", 0)) % 97) if a.has("seed") else float(hash(str(a.get("rig", ""))) % 97)
	for flame: Variant in burn.get("flames", []):
		if not flame is Array or (flame as Array).size() < 5: continue
		var id := str(flame[0])
		if not shown.has(id) or not world.has(id): continue
		var alpha: float = alpha_of.call(id)
		if alpha <= 0.01: continue
		canvas.draw_set_transform_matrix(world[id])
		var x0 := float(flame[1])
		var base := float(flame[2])
		var w := int(flame[3])
		var h := float(flame[4])
		var kind := str(flame[5]) if (flame as Array).size() > 5 else ""
		var pal: Array = SOUL_FLAME if kind == "soul" else VOID_FLAME if kind == "void" else FLAME
		for i in range(w):
			var edge := 1.0 - absf((float(i) + 0.5) / float(w) * 2.0 - 1.0)
			var wave := 0.62 + 0.38 * sin(tq * 11.0 + float(i) * 2.3 + seed)
			var col_h := maxf(1.0, roundf(h * (0.3 + 0.7 * edge) * wave))
			for j in range(int(col_h)):
				var k := float(j) / col_h
				# the flame's foot starts yellow (no white rim on the figure)
				var c: Color = pal[1 if k < 0.4 else 2 if k < 0.68 else 3 if k < 0.9 else 4]
				_rect(canvas, Rect2(x0 + float(i), base - float(j) - 1.0, 1.0, 1.0), Color(c, alpha), "burn", id)
			# a tongue of fire breaking off above the column now and then
			if sin(tq * 7.0 + float(i) * 3.1 + seed * 1.7) > 0.72:
				_rect(canvas, Rect2(x0 + float(i), base - col_h - 2.0, 1.0, 1.0), Color(pal[3], alpha * 0.85), "burn", id)
	for ember: Variant in burn.get("glow", []):
		if not ember is Array or (ember as Array).size() < 3: continue
		var id := str(ember[0])
		if not shown.has(id) or not world.has(id): continue
		var alpha: float = alpha_of.call(id)
		if alpha <= 0.01: continue
		canvas.draw_set_transform_matrix(world[id])
		var hot := sin(tq * 9.0 + float(ember[1]) * 1.3 + seed) > 0.2
		_rect(canvas, Rect2(float(ember[1]), float(ember[2]), 1.0, 1.0), Color(FLAME[1] if hot else FLAME[2], alpha), "burn", id)
	canvas.draw_set_transform_matrix(Transform2D.IDENTITY)


## A swing's slash on the pixel grid (`px` world px per block): the band the
## blade swept between its inner point (q) and its tip (p) over the last
## frames, filled block by block. The newest edge is white-hot, older parts
## cool through yellow and orange to red, and every block fades with its age;
## the inner part of older segments drops out, so it tapers like a crescent.
func _draw_pixel_slash(canvas: CanvasItem, trail: Array, px: float, pal: Array) -> void:
	var n := trail.size()
	if n < 2: return
	for i in range(1, n):
		var a0: Dictionary = trail[i - 1]
		var a1: Dictionary = trail[i]
		if not a0.has("q") or not a1.has("q"): continue
		var age := clampf(float(a1.age) / maxf(0.01, float(a1.get("life", SLASH_LIFE))), 0.0, 1.0)
		var newest := float(i) / float(n - 1)
		var col: Color = pal[0] if newest > 0.88 else pal[1] if newest > 0.6 else pal[2] if newest > 0.3 else pal[3]
		col.a = 1.0 - age
		var p0: Vector2 = a0.p
		var p1: Vector2 = a1.p
		var q0: Vector2 = a0.q
		var q1: Vector2 = a1.q
		var steps := clampi(int(maxf(p0.distance_to(p1), q0.distance_to(q1)) / px) + 1, 1, 40)
		var across := clampi(int(p1.distance_to(q1) / px) + 1, 1, 30)
		var keep_from := 0.0 if newest > 0.7 else 0.45
		for s in range(steps + 1):
			var f := float(s) / float(steps)
			var tip := p0.lerp(p1, f)
			var inner := q0.lerp(q1, f)
			for c in range(across + 1):
				var u := float(c) / float(across)
				if u < keep_from: continue
				canvas.draw_rect(Rect2((inner.lerp(tip, u) / px).floor() * px, Vector2(px, px)), col)


## [clip, end of windup, end of active] in clip progress, per figure and move.
func _attack_mapping(rig: Dictionary, kind: String) -> Array:
	match str(rig.family):
		"skeleton":
			match str(rig.variant):
				"bow": return ["attack", 0.7, 0.8]
				"guard": return ["attack", 0.45, 0.6]
			return ["attack", 0.6, 0.75]
		"necro": return ["summon", 0.3, 0.4] if kind == "summon" else ["attack", 0.55, 0.62]
		# a burst all round (a ring) or a call (summon) swells the body like a roar; blows swing the arm
		"brute": return ["roar", 0.4, 0.6] if kind in ["roar", "ring", "summon"] else ["attack", 0.45, 0.56]
		"golem":
			# the stomp smashes both fists down, a throw hurls the right fist, a ring or a call bursts the core
			match kind:
				"slam": return ["slam", 0.55, 0.68]
				"ring", "roar", "summon": return ["roar", 0.4, 0.6]
			return ["attack", 0.45, 0.6]
		"void":
			match kind:
				"beam": return ["beam", 0.3, 0.86]
				"summon": return ["summon", 0.38, 0.5]
			return ["attack", 0.55, 0.62]
		"bomber": return ["attack", 1.0, 1.0]
		# the Frostgruft's slime and whirl/crystal: a ring or a call swells them, everything else lashes out
		"slime", "spirit": return ["roar", 0.4, 0.6] if kind in ["roar", "ring", "summon"] else ["attack", 0.45, 0.6]
		"drake":
			# bolt->bite, slam, dash, burrow, swing, sweep, ring/echoes->roar, beam, flight
			var clip := str(RigPoses.DRAKE_KINDS.get(kind, ""))
			if clip.is_empty(): return ["bite", 0.5, 0.65]
			var windows: Array = RigPoses.DRAKE_WINDOWS[clip]
			return [clip, float(windows[0]), float(windows[1])]
	return ["attack", 0.45, 0.6]


func _start_rise(a: Dictionary, rig: Dictionary, enemy: Dictionary) -> void:
	a.rise = RISE_TIME
	var from: Dictionary = {}
	for part: Dictionary in rig.parts + rig.items: from[part.id] = {"dx": _rng.randf_range(-3, 3), "dy": _rng.randf_range(8, 13), "rot": _rng.randf_range(-1.2, 1.2)}
	a.rise_from = from
	var feet := Vector2(float(enemy.get("x", 0)), float(enemy.get("y", 0))) + Vector2(0, (float(rig.ground.y) - float(rig.center.y)) * _scale(rig))
	_pools.append({"x": feet.x, "y": feet.y, "r": 18.0, "life": 0.0, "max": 2.6})


func _start_death(a: Dictionary, rig: Dictionary, enemy: Dictionary) -> void:
	a.dying = true
	# cut in two by Rage: the slice effect (src/vfx/slice_fx.gd) shows the halves
	if enemy.has("slice"): return
	var family: String = str(rig.family)
	var feet: Vector2 = a.get("feet", Vector2(float(enemy.get("x", 0)), float(enemy.get("y", 0))))
	match family:
		"skeleton":
			for part: Dictionary in rig.items + rig.parts: _detach(a, rig, part.id, 1.0)
			if bool(enemy.get("summoned", false)): _burst_at(feet - Vector2(0, 14), VIOLET_DARK, 14, 50.0)
		"golem":
			# the golem breaks into its boulders, its glow spills out
			for part: Dictionary in rig.items + rig.parts: _detach(a, rig, part.id, 1.0)
			var colors := palette(str(rig.get("material", "")))
			if not colors.is_empty(): _burst_at(feet - Vector2(0, 30), colors.burst, 22, 110.0)
		"bomber":
			if not bool(enemy.get("exploded", false)): _burst_at(feet - Vector2(0, 16), VIOLET, 18, 90.0)
		"mimic":
			# Splinters and a glint of gold when the chest beast falls.
			_burst_at(feet - Vector2(0, 12), Color("b8743a"), 14, 80.0)
			_burst_at(feet - Vector2(0, 14), Color("f4c64e"), 6, 60.0)
		"biped", "hero", "necro":
			for item: Dictionary in rig.items: _detach(a, rig, item.id, 0.8)
		"brute":
			for id: String in ["arm", "head"]: _detach(a, rig, id, 0.5)
		"void":
			for id: String in ["claw_l", "claw_r"]: _detach(a, rig, id, 0.7)
			_flashes.append({"x": feet.x, "y": feet.y - 40.0, "r": 150.0, "life": 0.0, "max": 1.8, "color": VIOLET})
		"drake":
			# Wings, horns, jaw, crystals and the tail beyond its root fall off;
			# body, neck and head stay and the death pose collapses them.
			for id: String in DRAKE_SHED:
				if not rig.by_id.has(id) or a.lost.has(id): continue
				_detach(a, rig, id, 0.6)
				a.shed[id] = true
			var colors := palette(str(rig.get("material", "")))
			if colors.is_empty(): colors = palette("ember")
			_burst_at(feet - Vector2(0, 24), colors.burst, 20, 90.0)
			if str(rig.get("material", "")) == "obsidian": _flashes.append({"x": feet.x, "y": feet.y - 40.0, "r": 150.0, "life": 0.0, "max": 1.8, "color": VIOLET})


## Turns a part into falling debris from where it was last drawn.
func _detach(a: Dictionary, rig: Dictionary, id: String, impulse: float) -> void:
	var part: Dictionary = rig.by_id.get(id, {})
	if part.is_empty() or a.lost.has(id): return
	var world: Dictionary = a.world
	if not world.has(id): return
	var xform: Transform2D = world[id]
	var center: Vector2 = xform * Vector2(part.center)
	var ground: float = Vector2(a.get("feet", center)).y
	var texture: Texture2D = part.texture
	var white: Texture2D = part.get("white")
	if part.get("frames") is Array and not part.frames.is_empty():
		var layer: Dictionary = part.frames[int(a.get("frame_" + id, 0)) % part.frames.size()]
		texture = layer.texture
		white = layer.get("white")
	var material := str(rig.get("material", ""))
	_debris.append({"key": a.key, "id": id, "texture": texture, "center": part.center, "x": center.x, "y": ground + _rng.randf_range(-4, 6), "z": ground - center.y,
		"vx": _rng.randf_range(-56, 56) * impulse, "vz": _rng.randf_range(70, 140) * impulse, "ang": xform.get_rotation(), "spin": _rng.randf_range(-10, 10) * impulse,
		"face": signf(xform.x.x) if absf(xform.x.x) > 0.01 else 1.0, "scale": _scale(rig), "life": 0.0, "max": 3.0 if str(a.key).begins_with("e") and str(rig.family) == "skeleton" else 5.0, "rest": false,
		"material": material, "white": white})
	var chips: Array = cut_colors(rig)
	for i in range(6): _particles.append({"x": center.x, "y": center.y, "vx": _rng.randf_range(-60, 60), "vy": _rng.randf_range(-60, 20), "life": 0.0, "max": _rng.randf_range(0.25, 0.5),
		"color": chips[i % chips.size()], "grav": 240.0})
	# Glowing rigs spit embers (or void sparks) from the cut.
	var colors := palette(material)
	if not colors.is_empty(): _burst_at(center, colors.glow, 8, 70.0)


## Colours of the chips cut from a rig: its material's (hell rigs), violet for
## void figures, bone white for the rest.
static func cut_colors(rig: Dictionary) -> Array:
	var material := str(rig.get("material", ""))
	var colors := palette(material)
	if not colors.is_empty(): return colors.chips
	return [VIOLET_DARK] if str(rig.get("family", "")) in ["void", "bomber"] else [Color("fdf7ed")]


func _draw_rig(canvas: CanvasItem, a: Dictionary, rig: Dictionary, point: Vector2, face: float, flash: float, with_items: bool, shadow_alpha: float) -> float:
	var pose: Dictionary = RigPoses.pose(rig, a)
	var S: float = _actor_scale(rig, a)
	var feet := point + Vector2(0, (float(rig.ground.y) - float(rig.center.y)) * S)
	a.feet = feet
	# Sinking (a.cut world px): the figure is drawn that far lower and clipped at the feet.
	var cut := float(a.get("cut", 0.0))
	var clip_y := feet.y if cut > 0.0 else INF
	var world := _solve(rig, a, pose, feet + Vector2(0, cut), face, with_items)
	a.world = world
	var dying: bool = str(a.clip) == "death"
	var material := str(rig.get("material", ""))
	var colors := palette(material)
	var layered := not colors.is_empty()
	if (not dying or not (str(rig.family) in ["void", "necro"])) and not bool(a.get("no_shadow", false)):
		var shadow := float(rig.width) * S
		# A flying dragon's shadow shrinks below it.
		if str(rig.family) == "drake": shadow *= 1.0 - clampf(-float(pose.whole.dy) / 40.0, 0.0, 0.45)
		_rect(canvas, Rect2(feet.x - shadow * 0.5, feet.y - S, shadow, 3.0 * S), Color(SHADOW, SHADOW.a * shadow_alpha), "shadow", "")
	var layers: Array = []
	for part: Dictionary in rig.parts:
		if not world.has(part.id): continue
		# Hell rigs: a part hangs on its parent, so it goes with a lost one.
		if (_hidden(rig, a, part.id) if layered else a.lost.has(part.id)): continue
		layers.append(part)
	if with_items:
		for item: Dictionary in rig.items:
			if not a.lost.has(item.id) and world.has(item.id): layers.append(item)
	layers.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return int(p.z) < int(q.z))
	var frames: Dictionary = pose.get("frames", {})
	var alpha_of := func(part: Dictionary) -> float:
		var state: Dictionary = pose.parts.get(part.id, {})
		var alpha: float = float(state.get("alpha", 1.0))
		if float(a.rise) > 0.0 and str(rig.family) != "skeleton": alpha *= 1.0 - float(a.rise) / RISE_TIME
		alpha *= float(a.get("alpha_mul", 1.0))
		return alpha
	var layer_of := func(part: Dictionary) -> Dictionary:
		if part.get("frames") is Array and not part.frames.is_empty():
			var index: int = int(frames.get(part.id, 0)) % int(part.frames.size())
			a["frame_" + str(part.id)] = index
			return part.frames[index]
		return part
	# Void figures: a violet rim around the whole silhouette.
	var aura := float(pose.get("aura", 0.0))
	if aura > 0.0:
		var offsets := [Vector2(2, 0), Vector2(-2, 0), Vector2(0, 1), Vector2(0, -1)] if bool(pose.get("glitch", false)) else [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]
		for part: Dictionary in layers:
			var alpha: float = alpha_of.call(part)
			if alpha <= 0.01: continue
			var layer: Dictionary = layer_of.call(part)
			canvas.draw_set_transform_matrix(world[part.id])
			for offset: Vector2 in offsets: _tex(canvas, layer.white, Color(VIOLET_DARK, clampf(aura, 0.0, 1.0) * alpha), "aura", part.id, offset)
	var fuse := float(pose.get("fuse", 0.0))
	if fuse > 0.0: flash = maxf(flash, 0.8 * fuse if sin(float(a.ct) * (20.0 + 50.0 * fuse)) > 0.0 else 0.0)
	var shown: Dictionary = {}
	for part: Dictionary in layers: shown[part.id] = true
	# The hit flash lights only the struck part while it is drawn.
	var flash_part := str(a.get("hit_part", ""))
	if not shown.has(flash_part): flash_part = ""
	var tint: Color = a.get("tint", Color.WHITE)
	var glow: Dictionary = pose.get("glow", {})
	var glow_color: Color = colors.glow if layered else Color("ffb347")
	var flashed: Array[String] = []
	# Parts actually put on the canvas (visible, not wholly below the floor): what a hit can land on.
	var hittable: Dictionary = {}
	for part: Dictionary in layers:
		var alpha: float = alpha_of.call(part)
		if alpha <= 0.01: continue
		var layer: Dictionary = layer_of.call(part)
		canvas.draw_set_transform_matrix(world[part.id])
		# Below the floor line (a sinking figure) nothing of the part is drawn.
		var rows := _rows_above(part, Transform2D(world[part.id]), clip_y)
		if rows <= float(Rect2(part.bounds).position.y): continue
		hittable[part.id] = true
		_tex(canvas, layer.texture, Color(tint.r, tint.g, tint.b, tint.a * alpha), "part", part.id, Vector2.ZERO, rows)
		var heat := clampf(float(glow.get(part.id, 0.0)), 0.0, 1.0)
		if heat > 0.0 and layer.get("white") != null: _tex(canvas, layer.white, Color(glow_color, 0.55 * heat * alpha), "glow", part.id, Vector2.ZERO, rows)
		if flash > 0.0 and (flash_part.is_empty() or flash_part == part.id):
			_tex(canvas, layer.white, Color(1, 1, 1, flash * alpha), "flash", part.id, Vector2.ZERO, rows)
			flashed.append(part.id)
		if bool(part.get("bow", false)): _draw_bow_string(canvas, pose)
	# a burning figure (rigs.json "burn"): pixel flames and glowing eyes on its parts, fading as it dies
	if not (rig.get("burn", {}) as Dictionary).is_empty():
		var fade := 1.0 - clampf(float(a.u), 0.0, 1.0) if dying else 1.0
		_draw_burn(canvas, rig, a, world, shown, func(id: String) -> float: return float(alpha_of.call(rig.by_id[id])) * fade if rig.by_id.has(id) else 0.0)
	canvas.draw_set_transform_matrix(Transform2D.IDENTITY)
	# Hell rigs: a glowing wound at every severed joint, fading with its parent.
	var stumps: Array[Dictionary] = []
	if layered:
		for id: String in a.lost:
			var cut_part: Dictionary = rig.by_id.get(id, {})
			if cut_part.is_empty() or not shown.has(str(cut_part.parent)): continue
			var parent: Dictionary = rig.by_id[str(cut_part.parent)]
			var at: Vector2 = Transform2D(world[parent.id]) * Vector2(cut_part.pivot)
			if at.y > clip_y: continue
			_draw_stump(canvas, at, material, S, id, alpha_of.call(parent))
			stumps.append({"id": id, "at": at})
	a.drawn = {"shown": shown, "hittable": hittable, "flashed": flashed, "stumps": stumps, "glow": glow.duplicate(), "tint": tint, "alpha": float(a.get("alpha_mul", 1.0))}
	# Weapon swing trail from the blade tip (a rig with a "slash" palette: the
	# blade's swept band on the pixel grid, following the swing as it goes).
	var weapon: Dictionary = rig.by_id.get("weapon", {})
	var slash: Array = SLASH.get(str(rig.get("slash", "")), [])
	if bool(pose.trail) and not weapon.is_empty() and world.has("weapon") and not a.lost.has("weapon"):
		var xf := Transform2D(world.weapon)
		var grip := Vector2(weapon.get("grip", weapon.get("pivot", Vector2.ZERO)))
		# a weapon drawn into the figure (a part, rigs.json "tip") swings like a held one
		var tip := Vector2(weapon.get("tip", grip))
		a.trail.append({"p": xf * tip, "q": xf * grip.lerp(tip, 0.4), "age": 0.0, "life": SLASH_LIFE if not slash.is_empty() else 0.12})
	if not slash.is_empty():
		_draw_pixel_slash(canvas, a.trail, maxf(2.0, roundf(S)), slash)
	else:
		for i in range(1, a.trail.size()):
			canvas.draw_line(a.trail[i - 1].p, a.trail[i].p, Color(0.92, 0.97, 1.0, 0.65 * (1.0 - float(a.trail[i].age) / 0.12)), 2.0)
	if pose.has("beam"): _beams.append({"key": a.key, "eye": world.get("eye", world.base) * Vector2(rig.get("eye_center", Vector2(22, 23))), "beam": pose.beam, "t": a.t, "ct": a.ct})
	return feet.y + cut - (float(rig.ground.y) - float(rig.top) + 1.0) * S + float(pose.whole.dy) * S


## Rows of a part's full-frame texture (from its top) that lie above the floor
## line `clip_y` (world y) under `xform`, measured at the part's centre column:
## INF without a clip, 0 when the part is entirely below it. Parts only lean
## a little, so one column stands for the whole width.
static func _rows_above(part: Dictionary, xform: Transform2D, clip_y: float) -> float:
	if not is_finite(clip_y) or xform.y.y <= 0.001: return INF
	var center_x := float(Vector2(part.get("center", Vector2.ZERO)).x)
	return (clip_y - xform.origin.y - xform.x.y * center_x) / xform.y.y


## World pixels per source pixel of an actor: its rig's scale times the
## actor's size (a figure growing in or swelling into a new form).
static func _actor_scale(rig: Dictionary, a: Dictionary) -> float:
	return _scale(rig) * float(a.get("size_mul", 1.0))


## World transforms of the parts actor `key` put on the canvas in its last
## draw ({part id: Transform2D}, source px of the full frame -> world px): the
## pose a hit is tested against. Lost, shed and hidden parts, invisible ones
## and parts of a sinking figure that lie wholly below the floor are left
## out; empty before the first draw or for an unknown actor.
func part_transforms(key: String) -> Dictionary:
	var a: Dictionary = _actors.get(key, {})
	var result: Dictionary = {}
	if a.is_empty(): return result
	var world: Dictionary = a.get("world", {})
	var drawn: Dictionary = a.get("drawn", {})
	for id: Variant in drawn.get("hittable", drawn.get("shown", {})):
		if world.has(id): result[str(id)] = Transform2D(world[id])
	return result


## True when a part or one of the parts it hangs on is lost or shed.
func _hidden(rig: Dictionary, a: Dictionary, id: String) -> bool:
	var at := id
	for _depth in range(32):
		if at.is_empty(): return false
		if a.lost.has(at) or a.shed.has(at): return true
		at = str(rig.by_id.get(at, {}).get("parent", ""))
	return false


## One texture of an actor, logged in draw_log while record_draws is on;
## `rows` (from _rows_above) keeps only that many rows from its top.
func _tex(canvas: CanvasItem, texture: Texture2D, color: Color, what: String, id: String, offset := Vector2.ZERO, rows := INF) -> void:
	var size := texture.get_size()
	if rows < size.y:
		var keep := Rect2(Vector2.ZERO, Vector2(size.x, maxf(0.0, rows)))
		canvas.draw_texture_rect_region(texture, Rect2(offset, keep.size), keep, color)
	else:
		canvas.draw_texture(texture, offset, color)
	if record_draws: draw_log.append({"what": what, "id": id, "color": color})


## One box of an actor (shadow, wound), logged in draw_log while record_draws is on.
func _rect(canvas: CanvasItem, rect: Rect2, color: Color, what: String, id: String) -> void:
	canvas.draw_rect(rect, color)
	if record_draws: draw_log.append({"what": what, "id": id, "color": color})


## A severed joint: a dark rim, a hot rim and a pulsing core, one source pixel
## each, in the rig material's colours; now and then an ember rises from it.
func _draw_stump(canvas: CanvasItem, at: Vector2, material: String, pixel: float, id: String, alpha: float) -> void:
	if alpha <= 0.01: return
	var colors: Array = palette(material).wound
	var pulse := 0.65 + 0.35 * sin(_clock * 7.0 + float(absi(id.hash()) % 7))
	var px := maxf(1.0, roundf(pixel))
	var c := at.round()
	_rect(canvas, Rect2(c - Vector2(1.5, 1.5) * px, Vector2(3, 3) * px), Color(colors[0], 0.9 * alpha), "stump", id)
	_rect(canvas, Rect2(c - Vector2(1, 1) * px, Vector2(2, 2) * px), Color(colors[1], (0.55 + 0.45 * pulse) * alpha), "stump", id)
	_rect(canvas, Rect2(c - Vector2(0.5, 0.5) * px, Vector2(1, 1) * px), Color(colors[2], pulse * alpha), "stump", id)
	if _rng.randf() < 0.06:
		_particles.append({"x": c.x, "y": c.y, "vx": _rng.randf_range(-8, 8), "vy": _rng.randf_range(-50, -25), "life": 0.0, "max": _rng.randf_range(0.3, 0.6), "color": colors[2]})


## World position of `source_point` (source px of the rig's full frame, rest
## pose) on part `part_id` of actor `key` ("e%d" % uid) as last drawn. A part
## that was not drawn (lost, shed) hands the point to its nearest drawn
## ancestor; otherwise the actor's feet, Vector2.ZERO for an unknown actor.
func world_point(key: String, part_id: String, source_point: Vector2) -> Vector2:
	var a: Dictionary = _actors.get(key, {})
	if a.is_empty(): return Vector2.ZERO
	var world: Dictionary = a.get("world", {})
	var shown: Dictionary = a.get("drawn", {}).get("shown", {})
	var by_id: Dictionary = library.rig(str(a.get("rig", ""))).get("by_id", {}) if library != null else {}
	var at := part_id
	for _depth in range(32):
		if not by_id.has(at): break
		if world.has(at) and shown.has(at): return Transform2D(world[at]) * source_point
		at = str(by_id[at].get("parent", ""))
	return a.get("feet", Vector2.ZERO)


## What the last draw of actor `key` showed (tests and capture checks):
## shown {part: true}, flashed [part], stumps [{id, at}], glow {part: 0..1},
## tint and alpha. Empty before the first draw.
func last_drawn(key: String) -> Dictionary:
	return _actors.get(key, {}).get("drawn", {})


func _draw_bow_string(canvas: CanvasItem, pose: Dictionary) -> void:
	var pull: float = float(pose.get("pull", 0.0))
	var top := Vector2(7.5, 3.5)
	var bottom := Vector2(7.5, 22.5)
	var middle := Vector2(7.5 - pull, 13)
	var color := Color("d3bfa9")
	canvas.draw_line(top, middle, color, 0.5)
	canvas.draw_line(middle, bottom, color, 0.5)
	if bool(pose.get("nock", false)):
		canvas.draw_line(middle, middle + Vector2(13, 0), Color("b89b73"), 0.5)
		canvas.draw_line(middle + Vector2(11, -1), middle + Vector2(13, 0), Color("eee0b9"), 0.5)
		canvas.draw_line(middle + Vector2(11, 1), middle + Vector2(13, 0), Color("eee0b9"), 0.5)


func _solve(rig: Dictionary, a: Dictionary, pose: Dictionary, feet: Vector2, face: float, with_items: bool) -> Dictionary:
	var S: float = _actor_scale(rig, a)
	var whole: Dictionary = pose.whole
	var ground: Vector2 = rig.ground
	var pivot: Vector2 = whole.pivot if whole.pivot is Vector2 else ground
	# whole.turn (the drake's tail whirl): the figure spins about its vertical
	# axis, 1 -> -1 -> 1, mirrored about the feet.
	var turn := float(whole.get("turn", 1.0))
	var base := _t(feet + Vector2(float(whole.dx) * face * S, float(whole.dy) * S)) * _s(Vector2(face * turn * S, S)) * _t(-ground) * _t(pivot) * Transform2D(float(whole.rot), Vector2.ZERO) * _s(Vector2(float(whole.sx), float(whole.sy))) * _t(-pivot)
	base.origin = base.origin.round()
	var world: Dictionary = {"base": base}
	for part: Dictionary in rig.parts: _part_world(rig, a, pose, world, part.id)
	if with_items:
		for item: Dictionary in rig.items:
			if a.lost.has(item.id): continue
			var parent: String = str(item.parent)
			var parent_world: Transform2D = world[parent] if world.has(parent) and not a.lost.has(parent) else base
			var o: Dictionary = pose.items.get(item.id, {"dx": 0.0, "dy": 0.0, "rot": 0.0})
			world[item.id] = parent_world * _t(Vector2(item.hand) + Vector2(float(o.dx), float(o.dy))) * Transform2D(float(item.rest) + float(o.rot), Vector2.ZERO) * _t(-Vector2(item.grip))
	return world


func _part_world(rig: Dictionary, a: Dictionary, pose: Dictionary, world: Dictionary, id: String) -> Transform2D:
	if world.has(id): return world[id]
	var part: Dictionary = rig.by_id[id]
	var p: Dictionary = pose.parts.get(id, {"dx": 0.0, "dy": 0.0, "rot": 0.0, "sx": 1.0, "sy": 1.0})
	var parent: String = str(part.parent)
	var parent_world: Transform2D = _part_world(rig, a, pose, world, parent) if not parent.is_empty() and rig.by_id.has(parent) and not a.lost.has(parent) else world.base
	var pivot: Vector2 = part.pivot
	var local := _t(pivot + Vector2(float(p.dx), float(p.dy))) * Transform2D(float(p.rot), Vector2.ZERO) * _s(Vector2(float(p.get("sx", 1.0)), float(p.get("sy", 1.0)))) * _t(-pivot)
	world[id] = parent_world * local
	return world[id]


## World pixels per source pixel of a rig (bosses are drawn 3x larger).
static func _scale(rig: Dictionary) -> float:
	return float(rig.get("scale", S))


static func _t(offset: Vector2) -> Transform2D:
	return Transform2D(0.0, offset)


static func _s(scale: Vector2) -> Transform2D:
	return Transform2D(Vector2(scale.x, 0), Vector2(0, scale.y), Vector2.ZERO)


# ------------------------------------------------------------------ effects

## Debris and summoning pools lie on the floor, under every actor.
func draw_under(canvas: CanvasItem) -> void:
	for pool: Dictionary in _pools: _draw_pool(canvas, pool)
	for d: Dictionary in _debris:
		var fade := clampf(float(d.max) - float(d.life), 0.0, 1.0)
		canvas.draw_rect(Rect2(float(d.x) - 8, float(d.y) - 2, 16, 4), Color(SHADOW, 0.3 * fade))
		var xform := _t(Vector2(float(d.x), float(d.y) - float(d.z)).round()) * Transform2D(float(d.ang), Vector2.ZERO) * _s(Vector2(float(d.face) * float(d.get("scale", S)), float(d.get("scale", S)))) * _t(-Vector2(d.center))
		canvas.draw_set_transform_matrix(xform)
		canvas.draw_texture(d.texture, Vector2.ZERO, Color(1, 1, 1, fade))
		# Hell debris glows in its material's colour and cools down.
		var heat := 1.0 - clampf(float(d.life) / 1.5, 0.0, 1.0)
		var hot := palette(str(d.get("material", "")))
		if heat > 0.0 and not hot.is_empty() and d.get("white") != null:
			canvas.draw_texture(d.white, Vector2.ZERO, Color(hot.glow, 0.6 * heat * fade))
	canvas.draw_set_transform_matrix(Transform2D.IDENTITY)


## Beams, particles and flashes are drawn over the actors. The beams list is
## rebuilt each frame by draw_enemy.
func draw_over(canvas: CanvasItem, snapshot: Dictionary) -> void:
	var beams_by_key: Dictionary = {}
	for beam: Dictionary in _beams: beams_by_key[beam.key] = beam
	beams_drawn = 0
	for enemy: Dictionary in snapshot.get("enemies", []):
		var key := _key(enemy)
		if beams_by_key.has(key) and enemy.get("beam") is Array:
			_draw_beam(canvas, beams_by_key[key], enemy.beam)
			beams_drawn += 1
			# Rage: a second beam beside the first (the gap between them is safe).
			if enemy.get("beam_b") is Array: _draw_beam(canvas, beams_by_key[key], enemy.beam_b)
	_beams.clear()
	for p: Dictionary in _particles:
		var k := 1.0 - float(p.life) / float(p.max)
		canvas.draw_rect(Rect2(Vector2(float(p.x), float(p.y)).round(), Vector2(2, 2)), Color(p.color, k))
	for flash: Dictionary in _flashes:
		var k := float(flash.life) / float(flash.max)
		if str(flash.get("kind", "")) == "ring":
			var radius := lerpf(6.0, float(flash.r), RigPoses.ease_out(k))
			for i in range(48):
				var angle := TAU * i / 48.0
				canvas.draw_rect(Rect2(Vector2(float(flash.x), float(flash.y)) + Vector2(cos(angle), sin(angle) * 0.55) * radius, Vector2(2, 2)), Color(flash.color, 1.0 - k))


func _draw_beam(canvas: CanvasItem, drawn: Dictionary, ends: Array) -> void:
	var eye: Vector2 = drawn.eye
	var end := Vector2(float(ends[2]), float(ends[3]) - 16.0)
	var beam: Dictionary = drawn.beam
	var t: float = drawn.t
	var length := maxf(1.0, eye.distance_to(end))
	var direction := (end - eye) / length
	var warn := float(beam.get("warn", 0.0))
	if warn > 0.0:
		var flick := 0.35 + 0.35 * sin(float(drawn.ct) * 40.0)
		var s := 8.0
		while s < length:
			if int(s / 4.0) % 3 != 0: canvas.draw_rect(Rect2((eye + direction * s).round(), Vector2(2, 2)), Color(VIOLET, flick * warn))
			s += 4.0
	var k := float(beam.get("k", 0.0))
	if k <= 0.0: return
	for layer: Array in [[7.0, INK], [5.2, VIOLET_DARK], [3.4, VIOLET], [1.6, VIOLET_HOT]]:
		var s := 0.0
		while s <= length:
			var wobble := 1.1 * sin(s * 0.16 - t * 38.0) + 0.7 * sin(s * 0.055 + t * 21.0) if float(layer[0]) > 2.0 else 0.0
			var radius := (float(layer[0]) + wobble) * k * (lerpf(0.5, 1.0, s / 12.0) if s < 12.0 else 1.0)
			if radius >= 0.9:
				var side := maxf(2.0, roundf(radius * 2.0 / 2.0) * 2.0)
				canvas.draw_rect(Rect2((eye + direction * s - Vector2(side, side) * 0.5).round(), Vector2(side, side)), layer[1])
			s += 2.0
	var flare := 6.0 + 2.0 * sin(t * 50.0)
	canvas.draw_circle(eye, (flare + 1.0) * k, VIOLET)
	canvas.draw_circle(eye, flare * 0.55 * k, VIOLET_HOT)
	canvas.draw_circle(end, (flare + 3.0) * k, VIOLET_DARK)
	canvas.draw_circle(end, flare * k, VIOLET)
	canvas.draw_circle(end, flare * 0.5 * k, VIOLET_HOT)
	if _rng.randf() < 0.6:
		_particles.append({"x": end.x, "y": end.y, "vx": -direction.x * _rng.randf_range(40, 140) + _rng.randf_range(-60, 60), "vy": -direction.y * _rng.randf_range(40, 140) + _rng.randf_range(-80, 20),
			"life": 0.0, "max": _rng.randf_range(0.2, 0.45), "color": [VIOLET_HOT, VIOLET, INK][_rng.randi_range(0, 2)], "grav": 180.0})


func _draw_pool(canvas: CanvasItem, pool: Dictionary) -> void:
	var k := float(pool.life) / float(pool.max)
	var grow := RigPoses.ease_out(RigPoses.seg(k, 0.0, 0.12)) * (1.0 - RigPoses.ease_in(RigPoses.seg(k, 0.7, 1.0)))
	var rx := float(pool.r) * grow
	var ry := rx * 0.45
	if rx < 2.0: return
	var rows := int(ceil(ry / 2.0))
	for row in range(-rows, rows + 1):
		var y := float(row) * 2.0
		var half := rx * sqrt(maxf(0.0, 1.0 - pow(y / (ry + 1.0), 2.0)))
		if half < 1.0: continue
		canvas.draw_rect(Rect2(Vector2(float(pool.x) - half, float(pool.y) + y).round(), Vector2(roundf(half * 2.0), 2)), VIOLET_DARK)
		if half > 3.0: canvas.draw_rect(Rect2(Vector2(float(pool.x) - half + 2.0, float(pool.y) + y).round(), Vector2(roundf(half * 2.0 - 4.0), 2)), Color("13111c"))
	for i in range(3):
		var angle := float(pool.life) * 2.0 + i * TAU / 3.0
		canvas.draw_rect(Rect2(Vector2(float(pool.x) + cos(angle) * rx * 0.6, float(pool.y) + sin(angle) * ry * 0.6).round(), Vector2(2, 2)), Color(VIOLET, 0.8))
	if _rng.randf() < 0.3:
		_particles.append({"x": float(pool.x) + _rng.randf_range(-rx, rx) * 0.7, "y": float(pool.y), "vx": _rng.randf_range(-6, 6), "vy": _rng.randf_range(-60, -28), "life": 0.0, "max": 0.55, "color": [Color("efe6d6"), VIOLET, VIOLET_DARK][_rng.randi_range(0, 2)]})


func _play_fx(event: Dictionary) -> void:
	var point := Vector2(float(event.get("x", 0)), float(event.get("y", 0)))
	var radius := float(event.get("r", 64))
	match str(event.get("kind", "")):
		"void_burst":
			_flashes.append({"kind": "ring", "x": point.x, "y": point.y, "r": radius, "life": 0.0, "max": 0.45, "color": VIOLET})
			_flashes.append({"kind": "ring", "x": point.x, "y": point.y, "r": radius * 0.6, "life": 0.0, "max": 0.35, "color": VIOLET_HOT})
			_flashes.append({"x": point.x, "y": point.y, "r": radius * 1.6, "life": 0.0, "max": 0.5, "color": VIOLET})
			_burst_at(point, VIOLET, 36, 220.0)
			_burst_at(point, INK, 18, 140.0)
		"slam":
			_flashes.append({"kind": "ring", "x": point.x, "y": point.y, "r": radius, "life": 0.0, "max": 0.4, "color": Color("a99d93")})
			for i in range(24): _particles.append({"x": point.x + _rng.randf_range(-radius, radius) * 0.5, "y": point.y, "vx": _rng.randf_range(-100, 100), "vy": _rng.randf_range(-90, -10), "life": 0.0, "max": _rng.randf_range(0.3, 0.6), "color": [Color("7b6a5e"), Color("a99d93")][_rng.randi_range(0, 1)], "grav": 280.0})


func _burst_at(point: Vector2, color: Color, count: int, speed: float) -> void:
	for i in range(count):
		var angle := TAU * float(i) / float(count) + _rng.randf_range(-0.2, 0.2)
		var velocity := Vector2(cos(angle), sin(angle)) * speed * _rng.randf_range(0.5, 1.0)
		_particles.append({"x": point.x, "y": point.y, "vx": velocity.x, "vy": velocity.y, "life": 0.0, "max": _rng.randf_range(0.3, 0.7), "color": color})


## Light sources from void effects for the dark crypt: [Vector3(x, y, radius)].
func lights(snapshot: Dictionary) -> Array[Vector3]:
	var result: Array[Vector3] = []
	for enemy: Dictionary in snapshot.get("enemies", []):
		if enemy.get("beam") is Array and str(enemy.get("attack", "")) == "active" and str(enemy.get("attack_kind", "")) == "beam":
			var ends: Array = enemy.beam
			var from := Vector2(float(ends[0]), float(ends[1]))
			var to := Vector2(float(ends[2]), float(ends[3]))
			var steps := maxi(1, int(from.distance_to(to) / 40.0))
			for i in range(steps + 1): result.append(Vector3(lerpf(from.x, to.x, float(i) / steps), lerpf(from.y, to.y, float(i) / steps) - 16.0, 68.0))
			if enemy.get("beam_b") is Array:
				var other := Vector2(float(enemy.beam_b[2]), float(enemy.beam_b[3]))
				for i in range(steps + 1): result.append(Vector3(lerpf(from.x, other.x, float(i) / steps), lerpf(from.y, other.y, float(i) / steps) - 16.0, 68.0))
		elif str(enemy.get("rig", "")) in ["void", "bomber"] and float(enemy.get("dying_p", -1.0)) < 0.0:
			result.append(Vector3(float(enemy.get("x", 0)), float(enemy.get("y", 0)) - 8.0, 72.0 if str(enemy.rig) == "void" else 40.0))
	for pool: Dictionary in _pools: result.append(Vector3(float(pool.x), float(pool.y), 44.0))
	for flash: Dictionary in _flashes:
		if str(flash.get("kind", "")) != "ring": result.append(Vector3(float(flash.x), float(flash.y), float(flash.r) * (1.0 - float(flash.life) / float(flash.max))))
	return result
