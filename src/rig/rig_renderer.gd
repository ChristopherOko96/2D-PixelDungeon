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
## A splat (src/vfx/talent_fx.gd: an enemy flung against a wall at the
## Leerenmagier's Urknall) tears the rigged actor nearest it apart: every
## part flies off along the rebound with its material's chips (fling_near;
## vfx_gore.json splat.fling).
## Ragdoll (vfx_gore.json "ragdoll"): a dying enemy's snapshot "kill" (the
## blow's direction, feel tier or force, element) throws its parts: they fly
## with the blow, spin, bounce off the floor and the host's walls (solid),
## slide with friction and settle; settled parts stay as floor debris (the
## oldest above ragdoll.cap crumble away by dither, never by transparency).
## The kill's element marks them: charred with cooling embers and smoke,
## frozen with rime (shattering at the first hard landing), drained violet
## with motes, poisoned with drips. A held item (weapon, shield: rig.items or a
## part with a "tip") comes loose from the hand (ragdoll.loose): off the blow's
## axis to its hand's side, slower and lower than the body, always turning
## over, so it never rides along with the body pieces at its held angle. Figures of few parts (ragdoll.split:
## zombie, mimic) break into textured pieces. A flung figure (snapshot
## "tumble", the Urknall) turns over as it flies and comes apart where it dies.

const RigLibrary = preload("res://src/rig/rig_library.gd")
const RigPoses = preload("res://src/rig/rig_poses.gd")
## Hero element skins: a hero rig's parts drawn in his main spec's colours (hero_skins.json).
const ElementSkin = preload("res://src/hero/element_skin.gd")
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
## The core of a void beam: nothing, darker than the floor (vfx_pools.json void outline).
const VOID_CORE := Color("120a1c")
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
## vfx_gore.json splat.fling: time, speed, lift, spread of a splat's parts.
static var _gore_fling: Dictionary = {}
## vfx_gore.json "ragdoll": the detached parts' physics, tiers, cap, split and element looks (RAGDOLL fills gaps).
static var _ragdoll: Dictionary = {}
static var _looks: Dictionary = {}
static var _band_cache: Dictionary = {}
static var _dither_cache: Dictionary = {}
static var _talent_read := false
static var _talent_tiers: Dictionary = {}
static var _kind_tiers: Dictionary = {}
static var _talent_types: Dictionary = {}
## Read for a kill's feel tier (kill_tier), as src/vfx/talent_fx.gd weighs a cast.
const TALENTS_PATH := "res://assets/data/talents.json"
const VFX_TALENTS_PATH := "res://assets/data/vfx_talents.json"
## 4x4 Bayer order: a crumbling piece drops its pixels in this order.
const BAYER := [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]
## Fallbacks of vfx_gore.json "ragdoll" (see its _ragdoll_note).
const RAGDOLL := {"speed": 90.0, "spread": 0.6, "jitter": [0.6, 1.2], "pop": 24.0, "depth": 0.7, "lift": [70.0, 140.0], "spin": 10.0,
	"tiers": {"small": 1.0, "medium": 1.6, "large": 2.4, "huge": 3.5, "splat": 3.2},
	"gravity": 520.0, "bounce": 0.35, "wall_bounce": 0.4, "ground_keep": 0.6, "spin_keep": 0.5, "friction": 9.0, "rest_speed": 6.0, "rest_vz": 30.0,
	"radius": 4.0, "cap": 60, "dither_time": 0.6, "split": {"families": ["biped", "mimic", "bomber", "necro"], "piece_px": 5, "most": 4},
	"loose": {"side": 0.9, "speed": 0.8, "lift": 0.5, "spin": [9.0, 15.0]},
	"talent_element": {"fire": "fire", "frost": "ice", "arcane": "void"}, "elements": {}}
## The host's walls for the debris: solid.call(world point) -> true inside a
## wall (story worlds: src/hell/drake_rig_host.gd bind_world). Unset: no walls.
var solid: Callable = Callable()
static var _palettes: Dictionary = {}
## Pose families the renderer does not know itself (the companions' beast,
## bird, elemental and demon, src/vfx/companion_rigs.gd): family -> {"pose":
## Callable(rig, a) -> pose, "attacks": Callable(rig, kind) -> [clip, end of
## windup, end of active]}. A registered family crumbles on death like a
## skeleton: every part falls off as debris and nothing is left to draw.
var families: Dictionary = {}


func _init(rig_library: RefCounted = null) -> void:
	library = rig_library if rig_library != null else RigLibrary.shared()
	_rng.seed = 90210


## Adds (or replaces) a pose family: `pose` builds the RigPoses-style pose of
## a rig for an actor state, `attacks` maps an attack kind to its clip and
## windows (an invalid Callable keeps the default attack clip).
func register_family(name: String, pose: Callable, attacks: Callable = Callable()) -> void:
	families[name] = {"pose": pose, "attacks": attacks}


## Drops the clip state of actor `key` (a companion that is gone); its debris
## stays on the floor until it fades.
func forget(key: String) -> void:
	_actors.erase(key)


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
	var splat: Variant = parsed.get("splat", {}) if parsed is Dictionary else {}
	var fling: Variant = splat.get("fling", {}) if splat is Dictionary else {}
	_gore_fling = fling if fling is Dictionary else {}
	var ragdoll: Variant = parsed.get("ragdoll", {}) if parsed is Dictionary else {}
	_ragdoll = ragdoll if ragdoll is Dictionary else {}
	_looks.clear()
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
		var key := observe_one(enemy)
		if not key.is_empty(): seen[key] = true
	for key: String in _actors.keys():
		if str(key).begins_with("e") and not seen.has(key): _actors.erase(key)
	for event: Dictionary in snapshot.get("fx_events", []):
		var id := int(event.get("id", 0))
		if _fx_seen.has(id): continue
		_fx_seen[id] = true
		_play_fx(event)
	if _fx_seen.size() > 256: _fx_seen.clear()


## Reads one entity's snapshot (an enemy of observe(), or a companion handed
## in by src/vfx/companion_rigs.gd before it is drawn): see observe(). Returns
## the actor key, "" for an entity without a rig. Keys not starting with "e"
## (a companion's "actor_key") are never swept by observe(); the caller drops
## them with forget().
func observe_one(enemy: Dictionary) -> String:
	if not is_ready(): return ""
	var rig_name := str(enemy.get("rig", ""))
	if rig_name.is_empty(): return ""
	var key := _key(enemy)
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
	return key


func _actor(key: String, entity: Dictionary) -> Dictionary:
	if not _actors.has(key):
		_actors[key] = {"key": key, "t": _rng.randf_range(0.0, 3.0), "clip": "", "ct": 0.0, "clip_len": 0.0, "hits": int(entity.get("hits", 0)), "blocks": int(entity.get("blocks", 0)),
			"hurts": int(entity.get("hurts", 0)), "lost": {}, "regrowing": {}, "dying": false, "rise": 0.0, "rise_from": {}, "world": {}, "trail": [], "dead_at": -1.0,
			"shed": {}, "drawn": {}}
	return _actors[key]


## Actor key of an enemy: its own "actor_key" when it brings one (a companion,
## "p" + pet id), else "e" + its uid (hell monsters carry a string id and an
## int uid), else its int id (crypt enemies).
static func _key(enemy: Dictionary) -> String:
	if enemy.has("actor_key"): return str(enemy.actor_key)
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
	a.ragdoll = false
	a.kill = {}
	a.tumble = 0.0


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
	_step_debris(delta)
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
	# Skeletons (and the companions' registered families) crumble and bombers burst: nothing is left to draw.
	# a flung figure turns over as it flies (snapshot "tumble", the Urknall)
	a.tumble = float(enemy.get("tumble", 0.0))
	# ... and so does every figure that came apart as a ragdoll (_start_death)
	if dying_p >= 0.0 and (family in ["skeleton", "bomber", "golem"] or families.has(family) or bool(a.get("ragdoll", false))): return NAN
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
	# the element skin (src/hero/element_skin.gd): the mage's parts in his main spec's colours;
	# the story worlds give the element with the player, the crypt's comes from its talents
	a.skin = ElementSkin.class_for_rig(rig_name)
	a.element = ElementSkin.element_for_player(player) if not str(a.skin).is_empty() else ""
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
	var registered: Dictionary = families.get(str(rig.family), {})
	if not registered.is_empty() and (registered.attacks as Callable).is_valid():
		var mapped: Variant = registered.attacks.call(rig, kind)
		if mapped is Array and (mapped as Array).size() >= 3: return mapped
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
	# the blow that felled it (snapshot "kill"): direction, impulse by its feel tier, element
	var kill := _kill_of(enemy)
	a.kill = kill
	var impulse := float(kill.impulse)
	# only an ultimate's or a wall's blow tears a big body wholly apart (weight by importance)
	var tears: bool = bool(kill.wall) or impulse >= float(Dictionary(_rag("tiers")).get("huge", 3.5))
	# A companion (registered family) falls apart like a skeleton: every part drops.
	if families.has(family):
		_ragdoll_all(a, rig, kill, 0.8 * impulse)
		return
	match family:
		"skeleton":
			_ragdoll_all(a, rig, kill, impulse)
			if bool(enemy.get("summoned", false)): _burst_at(feet - Vector2(0, 14), VIOLET_DARK, 14, 50.0)
		"golem":
			# the golem breaks into its boulders, its glow spills out
			_ragdoll_all(a, rig, kill, impulse)
			var colors := palette(str(rig.get("material", "")))
			if not colors.is_empty(): _burst_at(feet - Vector2(0, 30), colors.burst, 22, 110.0)
		"bomber":
			if not bool(enemy.get("exploded", false)): _burst_at(feet - Vector2(0, 16), VIOLET, 18, 90.0)
		"mimic":
			# the chest beast breaks into lid, teeth and box (vfx_gore.json ragdoll.split), splinters and a glint of gold
			_ragdoll_all(a, rig, kill, impulse)
			_burst_at(feet - Vector2(0, 12), Color("b8743a"), 14, 80.0)
			_burst_at(feet - Vector2(0, 14), Color("f4c64e"), 6, 60.0)
		"biped", "hero", "necro":
			# the fleshy figures come apart like the skeletons: every part flies with the blow
			_ragdoll_all(a, rig, kill, impulse)
		"brute":
			if tears: _ragdoll_all(a, rig, kill, impulse)
			else:
				for id: String in ["arm", "head"]: _detach(a, rig, id, 0.5 * impulse, kill)
		"void":
			for id: String in ["claw_l", "claw_r"]: _detach(a, rig, id, 0.7 * impulse, kill)
			_flashes.append({"x": feet.x, "y": feet.y - 40.0, "r": 150.0, "life": 0.0, "max": 1.8, "color": VIOLET})
		"drake":
			# Wings, horns, jaw, crystals and the tail beyond its root fall off;
			# body, neck and head stay and the death pose collapses them.
			for id: String in DRAKE_SHED:
				if not rig.by_id.has(id) or a.lost.has(id): continue
				_detach(a, rig, id, 0.6 * impulse, kill)
				a.shed[id] = true
			var colors := palette(str(rig.get("material", "")))
			if colors.is_empty(): colors = palette("ember")
			_burst_at(feet - Vector2(0, 24), colors.burst, 20, 90.0)
			if str(rig.get("material", "")) == "obsidian": _flashes.append({"x": feet.x, "y": feet.y - 40.0, "r": 150.0, "life": 0.0, "max": 1.8, "color": VIOLET})
	# flung against a wall a moment ago (fling_near) without a wall kill of its own: it comes apart along the rebound
	var fling: Dictionary = a.get("fling", {})
	if not bool(kill.wall) and not fling.is_empty() and _clock - float(fling.get("t", -100.0)) <= _fling_value("time", 0.6): _fling_apart(a)


## Every part and item of actor `a` flies off as debris with the blow `kill`;
## nothing of the figure is drawn any more (draw_enemy).
func _ragdoll_all(a: Dictionary, rig: Dictionary, kill: Dictionary, impulse: float) -> void:
	for part: Dictionary in rig.items + rig.parts: _detach(a, rig, part.id, impulse, kill)
	a.ragdoll = true


## The blow that felled an enemy, from its snapshot "kill" ({dx, dy, tier,
## talent, ult, force, el, wall}; hosts: talent_combat _stamp, game.gd,
## hell_monsters.gd _kill_fx): dir (unit, ZERO unknown), impulse (ragdoll.tiers
## of its feel tier, or force), tier, el (its element look) and wall (flung
## against a wall: the splat tier).
static func _kill_of(enemy: Dictionary) -> Dictionary:
	var raw: Variant = enemy.get("kill", {})
	var fx: Dictionary = raw if raw is Dictionary else {}
	var dir := Vector2(float(fx.get("dx", 0.0)), float(fx.get("dy", 0.0)))
	var wall := bool(fx.get("wall", false))
	var tier := "splat" if wall else str(fx.get("tier", ""))
	if tier.is_empty(): tier = kill_tier(str(fx.get("talent", "")), bool(fx.get("ult", false)))
	var tiers: Dictionary = _rag("tiers")
	var impulse := float(fx.get("force", tiers.get(tier, 1.0)))
	return {"dir": dir.normalized() if dir.length() > 0.01 else Vector2.ZERO, "impulse": maxf(0.2, impulse), "tier": tier, "el": kill_element(fx), "wall": wall}


## The feel tier of a kill by `talent` as talent_fx.gd weighs its cast: an
## ultimate huge, a shot its vfx_talents.json shots.talent_tier, the rest by
## its type (cast.kind_tier); no talent (a basic blow) small.
static func kill_tier(talent: String, ult: bool) -> String:
	if talent.is_empty(): return "small"
	if ult: return "huge"
	_read_talents()
	if _talent_tiers.has(talent): return str(_talent_tiers[talent])
	return str(_kind_tiers.get(str(_talent_types.get(talent, "")), "small"))


## The element a kill shows on the corpse: the blow's own "el", else its
## talent's (vfx_gore.json ragdoll.talent_element by id or class prefix), "" none.
static func kill_element(fx: Dictionary) -> String:
	var el := str(fx.get("el", ""))
	if not el.is_empty(): return el
	var talent := str(fx.get("talent", ""))
	if talent.is_empty(): return ""
	var map: Dictionary = _rag("talent_element")
	if map.has(talent): return str(map[talent])
	return str(map.get(talent.get_slice("_", 0), ""))


static func _read_talents() -> void:
	if _talent_read: return
	_talent_read = true
	var vfx: Variant = _json(VFX_TALENTS_PATH)
	if vfx is Dictionary:
		var shots: Variant = vfx.get("shots", {})
		if shots is Dictionary and shots.get("talent_tier") is Dictionary: _talent_tiers = shots.talent_tier
		var cast: Variant = vfx.get("cast", {})
		if cast is Dictionary and cast.get("kind_tier") is Dictionary: _kind_tiers = cast.kind_tier
	var talents: Variant = _json(TALENTS_PATH)
	if talents is Dictionary and talents.get("talents") is Dictionary:
		for id: String in talents.talents:
			if talents.talents[id] is Dictionary: _talent_types[id] = str(talents.talents[id].get("type", ""))


static func _json(path: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null


## A value of vfx_gore.json "ragdoll", else RAGDOLL's.
static func _rag(key: String) -> Variant:
	if not _gore_loaded: load_gore()
	return _ragdoll.get(key, RAGDOLL.get(key))


## Turns a part into debris from where it was last drawn: it flies with the
## blow `kill` (direction x ragdoll.speed x `impulse`, spread, an outward pop
## from the body and an upward lift with the root of the impulse, spin by the
## impulse) or, without a direction, tumbles off at random. A part of a split
## family (ragdoll.split) breaks into textured pieces.
func _detach(a: Dictionary, rig: Dictionary, id: String, impulse: float, kill: Dictionary = {}) -> void:
	var part: Dictionary = rig.by_id.get(id, {})
	if part.is_empty() or a.lost.has(id): return
	var world: Dictionary = a.world
	if not world.has(id): return
	var xform: Transform2D = world[id]
	var layer: Dictionary = part
	if part.get("frames") is Array and not part.frames.is_empty():
		layer = part.frames[int(a.get("frame_" + id, 0)) % part.frames.size()]
	var material := str(rig.get("material", ""))
	var center: Vector2 = xform * Vector2(part.center)
	var body: Vector2 = Transform2D(world.base) * Vector2(rig.center) if world.has("base") else center
	var split: Dictionary = _rag("split")
	var pieces := 1
	if str(rig.family) in Array(split.get("families", [])):
		var tall := float(Rect2(layer.get("bounds", Rect2())).size.y)
		pieces = clampi(ceili(tall / maxf(1.0, float(split.get("piece_px", 7)))), 1, int(split.get("most", 4)))
	# a weapon or shield (rig.items carry a "hand"; a weapon drawn into the figure a "tip") comes loose from the hand
	var held := part.has("hand") or part.has("tip")
	for piece: Dictionary in _bands(layer, pieces):
		_debris.append(_piece(a, rig, id, piece, xform, impulse, kill, body, material, held))
	var chips: Array = cut_colors(rig)
	for i in range(6): _particles.append({"x": center.x, "y": center.y, "vx": _rng.randf_range(-60, 60), "vy": _rng.randf_range(-60, 20), "life": 0.0, "max": _rng.randf_range(0.25, 0.5),
		"color": chips[i % chips.size()], "grav": 240.0})
	# Glowing rigs spit embers (or void sparks) from the cut.
	var colors := palette(material)
	if not colors.is_empty(): _burst_at(center, colors.glow, 8, 70.0)


## One debris piece of part `id` (its drawable `layer`, posed by `xform`).
## `held`: a weapon or shield coming loose from the hand (ragdoll.loose): it
## leaves the blow's cone by loose.side rad to the side its hand is on (either
## side when the hand lies on the blow's axis), at loose.speed and loose.lift
## of a body part's flight, and turns over at loose.spin rad/s (times the root
## of the impulse) - it never keeps its held angle next to the skull, which
## read as a sword still carried by a flying body.
func _piece(a: Dictionary, rig: Dictionary, id: String, layer: Dictionary, xform: Transform2D, impulse: float, kill: Dictionary, body: Vector2, material: String, held := false) -> Dictionary:
	var center: Vector2 = xform * Vector2(layer.center)
	var ground: float = Vector2(a.get("feet", center)).y
	var dir: Vector2 = kill.get("dir", Vector2.ZERO)
	var loose: Dictionary = _loose() if held else {}
	var out := center - body
	var v := Vector2.ZERO
	if dir == Vector2.ZERO:
		v = Vector2(_rng.randf_range(-56, 56), _rng.randf_range(-16, 16)) * impulse
	else:
		var jitter: Array = _rag("jitter")
		var spread := float(_rag("spread"))
		var aim := dir.rotated(_rng.randf_range(-spread, spread))
		if held:
			var across := dir.cross(out.normalized()) if out.length() > 0.5 else 0.0
			var side := signf(across) if absf(across) > 0.15 else (1.0 if _rng.randf() < 0.5 else -1.0)
			aim = dir.rotated(side * float(loose.side) + _rng.randf_range(-spread, spread) * 0.5)
		v = aim * float(_rag("speed")) * impulse * _rng.randf_range(float(jitter[0]), float(jitter[1])) * (float(loose.speed) if held else 1.0)
		if out.length() > 0.5: v += out.normalized() * float(_rag("pop")) * sqrt(impulse)
	# a bigger figure (story worlds) throws in proportion: the same flight in its own source px
	var k := _scale(rig) / S
	v *= k
	var lift: Array = _rag("lift")
	var el := str(kill.get("el", ""))
	var look := _look(el)
	var vz := _rng.randf_range(float(lift[0]), float(lift[1])) * sqrt(maxf(0.1, impulse)) * k * (float(loose.lift) if held else 1.0)
	var spin := _rng.randf_range(-1.0, 1.0) * float(_rag("spin")) * impulse
	if held: spin = _loose_spin(loose, impulse)
	return {"key": a.key, "id": id, "texture": layer.texture, "white": layer.get("white"), "layer": layer, "center": layer.center,
		"x": center.x, "y": ground + _rng.randf_range(-4, 6), "z": maxf(0.0, ground - center.y),
		"vx": v.x, "vy": v.y * float(_rag("depth")), "vz": vz, "k": k, "held": held,
		"ang": xform.get_rotation(), "spin": spin,
		"face": signf(xform.x.x) if absf(xform.x.x) > 0.01 else 1.0, "scale": _scale(rig), "life": 0.0, "max": INF, "rest": false,
		"material": material, "el": el, "look": look, "born": _clock, "spots": _spots_for(layer, look)}


## vfx_gore.json ragdoll.loose over RAGDOLL's, key by key: how a held item
## comes loose (side rad, speed and lift factors, spin [min, max] rad/s).
static func _loose() -> Dictionary:
	var out: Dictionary = Dictionary(RAGDOLL.loose).duplicate()
	var over: Variant = _rag("loose")
	if over is Dictionary: out.merge(over, true)
	return out


## The turn of a loose item: loose.spin [min, max] rad/s either way, times the
## root of the impulse (never below the minimum).
func _loose_spin(loose: Dictionary, impulse: float) -> float:
	var turn: Array = loose.spin if loose.get("spin") is Array and (loose.spin as Array).size() >= 2 else RAGDOLL.loose.spin
	return (1.0 if _rng.randf() < 0.5 else -1.0) * _rng.randf_range(float(turn[0]), float(turn[1])) * maxf(1.0, sqrt(maxf(0.0, impulse)))


## A part's layer cut into `n` textured pieces along jagged rows (cached per
## texture): the layer itself when it cannot be cut.
func _bands(layer: Dictionary, n: int) -> Array:
	var image: Variant = layer.get("image")
	if n <= 1 or not image is Image or not layer.get("texture") is Texture2D or library == null: return [layer]
	var key := "%d:%d" % [(layer.texture as Texture2D).get_instance_id(), n]
	if _band_cache.has(key): return _band_cache[key]
	var src: Image = image
	var box := Rect2i(Rect2(layer.get("bounds", Rect2(Vector2.ZERO, Vector2(src.get_size())))))
	var images: Array[Image] = []
	for k in range(n): images.append(Image.create(src.get_width(), src.get_height(), false, Image.FORMAT_RGBA8))
	var h := maxf(1.0, float(box.size.y))
	for y in range(box.position.y, mini(box.end.y, src.get_height())):
		for x in range(box.position.x, mini(box.end.x, src.get_width())):
			var c := src.get_pixel(x, y)
			if c.a < 0.5: continue
			# the break runs jagged: the cut steps a row up or down from column to column
			var k := clampi(int(floorf((float(y - box.position.y) + float((x * 7) % 3) - 1.0) / h * float(n))), 0, n - 1)
			images[k].set_pixel(x, y, c)
	var out: Array = []
	for piece: Image in images:
		if piece.get_used_rect().size == Vector2i.ZERO: continue
		out.append(library._layer(piece))
	if out.is_empty(): out = [layer]
	_band_cache[key] = out
	return out


## The element look of a corpse (vfx_gore.json ragdoll.elements[el]) with its
## colours parsed: tint_color, rime_c, chip_c and every "matter" entry's cols; {} none.
static func _look(el: String) -> Dictionary:
	if el.is_empty(): return {}
	if _looks.has(el): return _looks[el]
	var spec: Variant = Dictionary(_rag("elements")).get(el, {})
	var look: Dictionary = (spec as Dictionary).duplicate(true) if spec is Dictionary else {}
	if not look.is_empty():
		look.tint_color = _hex(look.get("tint"), Color.WHITE)
		look.rime_c = _hex(look.get("rime_color"), Color("eaf6ff"))
		look.chip_c = _hex(look.get("chip_color"), Color("cfefff"))
		var matter: Array = []
		for entry: Variant in look.get("matter", []):
			if not entry is Dictionary: continue
			var m: Dictionary = (entry as Dictionary).duplicate()
			var colors: Array = []
			for c: Variant in m.get("colors", []): colors.append(_hex(c, Color.WHITE))
			if colors.is_empty(): colors = [Color.WHITE]
			m.cols = colors
			matter.append(m)
		look.matter = matter
	_looks[el] = look
	return look


## Pixels on a piece that carry its element look (source px): embers (look
## "embers": that many opaque pixels) and rime ("rime": pixels on its top edge).
func _spots_for(layer: Dictionary, look: Dictionary) -> Array:
	var spots: Array = []
	var embers := int(look.get("embers", 0))
	var rime := int(look.get("rime", 0))
	var image: Variant = layer.get("image")
	if (embers <= 0 and rime <= 0) or not image is Image: return spots
	var src: Image = image
	var box := Rect2i(Rect2(layer.get("bounds", Rect2())))
	var solid_px: Array[Vector2] = []
	var edge: Array[Vector2] = []
	for y in range(maxi(0, box.position.y), mini(box.end.y, src.get_height())):
		for x in range(maxi(0, box.position.x), mini(box.end.x, src.get_width())):
			if src.get_pixel(x, y).a < 0.5: continue
			solid_px.append(Vector2(x, y))
			if y == 0 or src.get_pixel(x, y - 1).a < 0.5: edge.append(Vector2(x, y))
	for i in range(mini(embers, solid_px.size())): spots.append({"p": solid_px[_rng.randi_range(0, solid_px.size() - 1)], "kind": "ember"})
	for i in range(mini(rime, edge.size())): spots.append({"p": edge[_rng.randi_range(0, edge.size() - 1)], "kind": "rime"})
	return spots


## Ragdoll physics of the debris: gravity and floor bounces that lose energy,
## the world's walls (solid, set by the host) reflecting them, friction while
## they slide, a shove between pieces so they knock and pile, settling at
## rest. A frozen part shatters at its first hard landing; element looks emit
## their matter (smoke, sparks, motes, drips). Settled parts stay; above
## ragdoll.cap the oldest crumble away by a 4x4 dither (never by transparency).
func _step_debris(delta: float) -> void:
	var g := float(_rag("gravity"))
	var bounce := float(_rag("bounce"))
	var wall := float(_rag("wall_bounce"))
	var keep := float(_rag("ground_keep"))
	var spin_keep := float(_rag("spin_keep"))
	var slide := maxf(0.0, 1.0 - float(_rag("friction")) * delta)
	var rest_speed := float(_rag("rest_speed"))
	var rest_vz := float(_rag("rest_vz"))
	var born: Array[Dictionary] = []
	for d: Dictionary in _debris:
		d.life = float(d.life) + delta
		_debris_matter(d, delta)
		if bool(d.rest): continue
		var k := float(d.get("k", 1.0))
		d.vz = float(d.vz) - g * k * delta
		d.z = float(d.z) + float(d.vz) * delta
		var at := Vector2(float(d.x), float(d.y))
		# a piece that starts inside a wall (cut at the wall) may leave it freely
		var inside := _solid_at(at)
		var nx := at.x + float(d.vx) * delta
		if not inside and _solid_at(Vector2(nx, at.y)):
			d.vx = -float(d.vx) * wall
			d.spin = -float(d.spin) * wall
			_wall_dust(d)
		else: d.x = nx
		var ny := at.y + float(d.get("vy", 0.0)) * delta
		if not inside and _solid_at(Vector2(float(d.x), ny)):
			d.vy = -float(d.get("vy", 0.0)) * wall
			d.spin = -float(d.spin) * wall
			_wall_dust(d)
		else: d.y = ny
		d.ang = float(d.ang) + float(d.spin) * delta
		if float(d.z) > 0.0: continue
		d.z = 0.0
		if float(d.vz) < -rest_vz * k:
			# a hard landing: it bounces back up and loses energy; a frozen part breaks
			d.vz = -float(d.vz) * bounce
			d.vx = float(d.vx) * keep
			d.vy = float(d.get("vy", 0.0)) * keep
			d.spin = float(d.spin) * spin_keep
			if not bool(d.get("landed", false)):
				d.landed = true
				born.append_array(_shatter(d))
		else:
			# on the floor: it slides with friction until it lies still
			d.vz = 0.0
			d.vx = float(d.vx) * slide
			d.vy = float(d.get("vy", 0.0)) * slide
			d.spin = float(d.spin) * slide
			if Vector2(float(d.vx), float(d.vy)).length() < rest_speed * k and absf(float(d.spin)) < 1.5:
				d.rest = true
				d.vx = 0.0
				d.vy = 0.0
				d.spin = 0.0
	_separate()
	if not born.is_empty(): _debris.append_array(born)
	var dither := float(_rag("dither_time"))
	_debris = _debris.filter(func(d: Dictionary) -> bool: return not bool(d.get("broken", false)) and not (float(d.get("gone_at", -1.0)) >= 0.0 and _clock - float(d.gone_at) > dither))
	_cap_debris()


## True when world point `p` lies in a wall of the host's world (solid unset: never).
func _solid_at(p: Vector2) -> bool:
	return solid.is_valid() and bool(solid.call(p))


## A piece knocking against a wall throws up a little dust of its chips.
func _wall_dust(d: Dictionary) -> void:
	if Vector2(float(d.vx), float(d.get("vy", 0.0))).length() < 40.0: return
	var look: Dictionary = d.get("look", {})
	var color: Color = look.get("chip_c", Color("a99d93")) if not look.is_empty() else Color("a99d93")
	for i in range(3): _particles.append({"x": float(d.x), "y": float(d.y) - float(d.z), "vx": _rng.randf_range(-30, 30), "vy": _rng.randf_range(-50, -10), "life": 0.0, "max": _rng.randf_range(0.2, 0.4), "color": color, "grav": 200.0})


## Pieces on the floor shove each other apart (circles of ragdoll.radius):
## a moving one is pushed out and bounces off, a resting one stays put, so
## they knock and pile up.
func _separate() -> void:
	var r2 := float(_rag("radius")) * 2.0
	if r2 <= 0.0: return
	for d: Dictionary in _debris:
		if bool(d.rest) or float(d.z) > r2: continue
		for o: Dictionary in _debris:
			if is_same(o, d) or float(o.z) > r2 or float(o.get("gone_at", -1.0)) >= 0.0: continue
			var gap := Vector2(float(d.x) - float(o.x), float(d.y) - float(o.y))
			var dist := gap.length()
			if dist >= r2 or dist < 0.01: continue
			var n := gap / dist
			var to := Vector2(float(d.x), float(d.y)) + n * (r2 - dist) * 0.5
			if not _solid_at(to):
				d.x = to.x
				d.y = to.y
			var v := Vector2(float(d.vx), float(d.get("vy", 0.0)))
			var into := v.dot(n)
			if into < 0.0:
				v -= n * into * 1.4
				d.vx = v.x
				d.vy = v.y


## Above ragdoll.cap standing pieces, the oldest resting ones start to crumble (gone_at).
func _cap_debris() -> void:
	var standing := 0
	for d: Dictionary in _debris:
		if float(d.get("gone_at", -1.0)) < 0.0: standing += 1
	var over := standing - int(_rag("cap"))
	if over <= 0: return
	for d: Dictionary in _debris:
		if over <= 0: break
		if float(d.get("gone_at", -1.0)) >= 0.0 or not bool(d.rest): continue
		d.gone_at = _clock
		over -= 1


## A frozen piece (look "shatter": pieces) breaks at its first hard landing
## into that many shards that fly on, with ice chips; returns the shards and
## marks the piece broken. [] for every other piece.
func _shatter(d: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var look: Dictionary = d.get("look", {})
	var n := int(look.get("shatter", 0))
	if n < 2 or bool(d.get("shard", false)) or not d.get("layer") is Dictionary: return out
	var bands := _bands(d.layer, n)
	if bands.size() < 2: return out
	var speed := float(look.get("shatter_speed", 60.0))
	for layer: Dictionary in bands:
		var piece: Dictionary = d.duplicate()
		var off := (Vector2(layer.center) - Vector2(d.center)) * float(d.scale)
		off = Vector2(off.x * float(d.face), off.y).rotated(float(d.ang))
		var side := Vector2.from_angle(_rng.randf() * TAU) * speed
		piece.merge({"layer": layer, "texture": layer.texture, "white": layer.get("white"), "center": layer.center, "x": float(d.x) + off.x,
			"z": maxf(0.0, float(d.z) - off.y), "vx": float(d.vx) + side.x, "vy": float(d.get("vy", 0.0)) + side.y * 0.6, "vz": float(d.vz) + _rng.randf_range(10.0, 40.0),
			"spin": _rng.randf_range(-12.0, 12.0), "shard": true, "spots": _spots_for(layer, look)}, true)
		out.append(piece)
	_burst_at(Vector2(float(d.x), float(d.y) - 2.0), look.get("chip_c", Color("cfefff")), int(look.get("chips", 8)), 70.0)
	d.broken = true
	return out


## The element matter a corpse piece gives off while it is fresh (look
## "matter": [{rate per s, until s, colors, vx, vy [lo, hi], grav, life [lo, hi]}]):
## smoke and sparks of a charred one, motes leaving a drained one, drips of a poisoned one.
func _debris_matter(d: Dictionary, delta: float) -> void:
	var look: Dictionary = d.get("look", {})
	if look.is_empty() or float(d.get("gone_at", -1.0)) >= 0.0: return
	var age := _clock - float(d.get("born", _clock))
	for m: Dictionary in look.get("matter", []):
		if age > float(m.get("until", 2.0)) or _rng.randf() >= float(m.get("rate", 1.0)) * delta: continue
		var vy: Array = m.get("vy", [-30, -15])
		var life: Array = m.get("life", [0.5, 0.9])
		var cols: Array = m.cols
		var spread := float(m.get("vx", 6.0))
		_particles.append({"x": float(d.x) + _rng.randf_range(-3.0, 3.0), "y": float(d.y) - float(d.z) - _rng.randf_range(1.0, 5.0), "vx": _rng.randf_range(-spread, spread),
			"vy": _rng.randf_range(float(vy[0]), float(vy[1])), "life": 0.0, "max": _rng.randf_range(float(life[0]), float(life[1])), "color": cols[_rng.randi_range(0, cols.size() - 1)],
			"grav": float(m.get("grav", 0.0))})


## A piece's texture with `level` (1..3) quarters of its pixels dropped by a
## 4x4 Bayer order: the dither a crumbling piece leaves by. Cached.
func _dithered(d: Dictionary, level: int) -> Texture2D:
	var layer: Dictionary = d.get("layer", {}) if d.get("layer") is Dictionary else {}
	var image: Variant = layer.get("image")
	if not image is Image: return null
	var key := "%d:%d" % [(d.texture as Texture2D).get_instance_id(), level]
	if _dither_cache.has(key): return _dither_cache[key]
	var img := (image as Image).duplicate() as Image
	for y in range(img.get_height()):
		for x in range(img.get_width()):
			if BAYER[(y % 4) * 4 + x % 4] < level * 4: img.set_pixel(x, y, Color(0, 0, 0, 0))
	var texture := ImageTexture.create_from_image(img)
	if _dither_cache.size() > 512: _dither_cache.clear()
	_dither_cache[key] = texture
	return texture


## A piece's element look on its pixels (in its transform, source px): embers
## glowing and cooling through the flame ramp over look ember_time, and rime.
func _draw_look(canvas: CanvasItem, d: Dictionary, look: Dictionary) -> void:
	var spots: Array = d.get("spots", [])
	if spots.is_empty(): return
	var age := _clock - float(d.get("born", _clock))
	var heat := 1.0 - clampf(age / maxf(0.01, float(look.get("ember_time", 3.0))), 0.0, 1.0)
	for i in range(spots.size()):
		var spot: Dictionary = spots[i]
		if str(spot.kind) == "ember":
			if heat <= 0.0: continue
			var hot := heat * (0.6 + 0.4 * (0.5 + 0.5 * sin(_clock * 9.0 + float(i) * 2.1)))
			var color: Color = FLAME[1] if hot > 0.7 else FLAME[2] if hot > 0.4 else FLAME[3] if hot > 0.15 else FLAME[4]
			canvas.draw_rect(Rect2(Vector2(spot.p), Vector2.ONE), color)
		else:
			canvas.draw_rect(Rect2(Vector2(spot.p), Vector2.ONE), look.rime_c)


## The turn of a flung figure (a.tumble rad, snapshot "tumble") about its body centre.
static func _tumble(rig: Dictionary, a: Dictionary) -> Transform2D:
	var spin := float(a.get("tumble", 0.0))
	if absf(spin) < 0.001: return Transform2D.IDENTITY
	var c := Vector2(rig.center)
	return _t(c) * Transform2D(spin, Vector2.ZERO) * _t(-c)


## The feet of actor `key` where it was last drawn (world px), INF unknown
## (src/vfx/talent_fx.gd finds the Singularität's caught enemies by it).
func actor_feet(key: String) -> Vector2:
	var a: Dictionary = _actors.get(key, {})
	return Vector2(a.feet) if a.has("feet") else Vector2.INF


## The gore material of actor `key`: its rig's material, bone for the
## skeletons, void for void figures, "" unknown.
func actor_material(key: String) -> String:
	var a: Dictionary = _actors.get(key, {})
	if a.is_empty() or library == null: return ""
	var rig: Dictionary = library.rig(str(a.get("rig", "")))
	if not str(rig.get("material", "")).is_empty(): return str(rig.material)
	match str(rig.get("family", "")):
		"skeleton", "golem": return "bone"
		"void", "bomber": return "void"
	return "blood" if not rig.is_empty() else ""


## A splat (src/vfx/talent_fx.gd "splat": an enemy flung against a wall at
## the Urknall): the rigged enemy actor nearest `point` within `radius`
## comes apart, every part flying off along `dir` (the rebound off the wall)
## at splat.fling speed times `power` with its chips. If its death has begun
## its fallen parts are flung that way; else the death that follows within
## splat.fling time uses the impulse (_start_death). Returns the actor key,
## "" when none was near. Purely visual.
func fling_near(point: Vector2, dir: Vector2, power: float = 1.0, radius: float = 48.0) -> String:
	var best := ""
	var best_d := radius
	for key: String in _actors:
		if not key.begins_with("e"): continue
		var a: Dictionary = _actors[key]
		if not a.has("feet"): continue
		var d := minf(Vector2(a.feet).distance_to(point), (Vector2(a.feet) - Vector2(0, 16)).distance_to(point))
		if d < best_d:
			best_d = d
			best = key
	if best.is_empty(): return ""
	var actor: Dictionary = _actors[best]
	# it died at that wall with its own wall kill (snapshot kill.wall): its parts already fly back off it
	if bool(Dictionary(actor.get("kill", {})).get("wall", false)): return best
	actor.fling = {"dir": dir.normalized() if dir.length() > 0.01 else Vector2.UP, "power": power, "t": _clock}
	if bool(actor.dying): _fling_apart(actor)
	return best


## Every part of actor `a` not yet fallen detaches (and stays hidden on the
## dying pose), then all its fresh debris is flung along a.fling.
func _fling_apart(a: Dictionary) -> void:
	var fling: Dictionary = a.get("fling", {})
	var rig: Dictionary = library.rig(str(a.get("rig", ""))) if library != null else {}
	if fling.is_empty() or rig.is_empty(): return
	var fallen: Dictionary = {}
	for d: Dictionary in _debris:
		if str(d.key) == str(a.key): fallen[str(d.id)] = true
	for part: Dictionary in rig.items + rig.parts:
		var id := str(part.id)
		if fallen.has(id) or a.lost.has(id) or a.shed.has(id): continue
		_detach(a, rig, id, 1.0)
		a.shed[id] = true
	var lift: Array = _gore_fling.get("lift", [120, 220])
	var spread := _fling_value("spread", 0.8)
	for d: Dictionary in _debris:
		if str(d.key) != str(a.key) or float(d.life) > _fling_value("time", 0.6) or bool(d.get("flung", false)): continue
		var out := Vector2(fling.dir).rotated(_rng.randf_range(-spread, spread)) * _fling_value("speed", 150.0) * float(fling.power) * _rng.randf_range(0.6, 1.2)
		d.vz = _rng.randf_range(float(lift[0]), float(lift[1])) * float(fling.power)
		d.spin = _rng.randf_range(-16.0, 16.0)
		# a loose weapon or shield leaves the rebound's line and turns over (ragdoll.loose, see _piece)
		if bool(d.get("held", false)):
			var loose := _loose()
			out = out.rotated((1.0 if _rng.randf() < 0.5 else -1.0) * float(loose.side)) * float(loose.speed)
			d.vz = float(d.vz) * float(loose.lift)
			d.spin = _loose_spin(loose, float(fling.power))
		d.vx = out.x
		d.vy = out.y * 0.5
		d.rest = false
		d.flung = true
	a.fling = {}


## A number of vfx_gore.json splat.fling, else `fallback`.
static func _fling_value(key: String, fallback: float) -> float:
	if not _gore_loaded: load_gore()
	return float(_gore_fling.get(key, fallback))


## Colours of the chips cut from a rig: its material's (hell rigs), violet for
## void figures, bone white for the rest.
static func cut_colors(rig: Dictionary) -> Array:
	var material := str(rig.get("material", ""))
	var colors := palette(material)
	if not colors.is_empty(): return colors.chips
	return [VIOLET_DARK] if str(rig.get("family", "")) in ["void", "bomber"] else [Color("fdf7ed")]


## The pose of a rig for an actor state: a registered family's own, else RigPoses'.
func _pose(rig: Dictionary, a: Dictionary) -> Dictionary:
	var registered: Dictionary = families.get(str(rig.get("family", "")), {})
	if not registered.is_empty() and (registered.pose as Callable).is_valid():
		var pose: Variant = registered.pose.call(rig, a)
		if pose is Dictionary and pose.has("whole") and pose.has("parts"): return pose
	return RigPoses.pose(rig, a)


func _draw_rig(canvas: CanvasItem, a: Dictionary, rig: Dictionary, point: Vector2, face: float, flash: float, with_items: bool, shadow_alpha: float) -> float:
	var pose: Dictionary = _pose(rig, a)
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
		_tex(canvas, _skinned(layer.texture, a), Color(tint.r, tint.g, tint.b, tint.a * alpha), "part", part.id, Vector2.ZERO, rows)
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


## A part texture in the actor's element colours (src/hero/element_skin.gd,
## cached there by texture and element); the texture itself for actors without
## a skin or element.
func _skinned(texture: Texture2D, a: Dictionary) -> Texture2D:
	var element := str(a.get("element", ""))
	if element.is_empty(): return texture
	return ElementSkin.texture(texture, element, str(a.get("skin", "")))


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
	var base := _t(feet + Vector2(float(whole.dx) * face * S, float(whole.dy) * S)) * _s(Vector2(face * turn * S, S)) * _t(-ground) * _tumble(rig, a) * _t(pivot) * Transform2D(float(whole.rot), Vector2.ZERO) * _s(Vector2(float(whole.sx), float(whole.sy))) * _t(-pivot)
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

## Debris and summoning pools lie on the floor, under every actor. A piece
## shows its kill's element look (tint, embers, rime); a crumbling one (above
## ragdoll.cap) drops its pixels by a 4x4 dither, never by transparency.
func draw_under(canvas: CanvasItem) -> void:
	for pool: Dictionary in _pools: _draw_pool(canvas, pool)
	var dither := maxf(0.01, float(_rag("dither_time")))
	for d: Dictionary in _debris:
		var texture: Texture2D = d.texture
		var gone := float(d.get("gone_at", -1.0))
		if gone >= 0.0:
			var level := int((_clock - gone) / dither * 4.0) + 1
			if level >= 4: continue
			texture = _dithered(d, level)
			if texture == null: continue
		if float(d.z) > 1.0: canvas.draw_rect(Rect2(float(d.x) - 8, float(d.y) - 2, 16, 4), Color(SHADOW, 0.3))
		var xform := _t(Vector2(float(d.x), float(d.y) - float(d.z)).round()) * Transform2D(float(d.ang), Vector2.ZERO) * _s(Vector2(float(d.face) * float(d.get("scale", S)), float(d.get("scale", S)))) * _t(-Vector2(d.center))
		canvas.draw_set_transform_matrix(xform)
		var look: Dictionary = d.get("look", {})
		var tint: Color = look.get("tint_color", Color.WHITE) if not look.is_empty() else Color.WHITE
		canvas.draw_texture(texture, Vector2.ZERO, tint)
		if gone >= 0.0: continue
		if not look.is_empty(): _draw_look(canvas, d, look)
		# Hell debris glows in its material's colour and cools down.
		var heat := 1.0 - clampf(float(d.life) / 1.5, 0.0, 1.0)
		var hot := palette(str(d.get("material", "")))
		if heat > 0.0 and not hot.is_empty() and d.get("white") != null:
			canvas.draw_texture(d.white, Vector2.ZERO, Color(hot.glow, 0.6 * heat))
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


## A beam of void from the eye to the far end of `ends` (where it stops at a
## wall): the warning before it a flickering dotted line; then a tube of
## nothing with the light torn bright round it, wavering, what it swallowed
## running back up its core; light and dust beside it are drawn into it and
## vanish, and where it strikes it tears a hole of void that sucks the floor's
## dust in, swirling. On the 2 px grid.
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
	# a tube of void: outside in the dark outline, the light torn bright at its
	# rim, the violet body and a core of nothing (darker than the floor); it wavers
	for layer: Array in [[8.0, INK], [6.6, VIOLET_HOT], [5.0, VIOLET], [3.0, VOID_CORE]]:
		var s := 0.0
		while s <= length:
			var wobble := 1.1 * sin(s * 0.16 - t * 38.0) + 0.7 * sin(s * 0.055 + t * 21.0)
			var radius := (float(layer[0]) + wobble) * k * (lerpf(0.5, 1.0, s / 12.0) if s < 12.0 else 1.0)
			if radius >= 0.9:
				var side := maxf(2.0, roundf(radius * 2.0 / 2.0) * 2.0)
				canvas.draw_rect(Rect2((eye + direction * s - Vector2(side, side) * 0.5).round(), Vector2(side, side)), layer[1])
			s += 2.0
	# what it swallowed runs back up its core to the eye
	if k > 0.5:
		var s := fposmod(-t * 260.0, 14.0)
		while s <= length:
			canvas.draw_rect(Rect2((eye + direction * s - Vector2(1, 1)).round(), Vector2(2, 2)), VIOLET)
			s += 14.0
	# the eye burns; where it strikes it tears a hole of void with the light torn round it
	var flare := 6.0 + 2.0 * sin(t * 50.0)
	_px_disc(canvas, eye, (flare + 1.0) * k, VIOLET)
	_px_disc(canvas, eye, flare * 0.55 * k, VIOLET_HOT)
	_px_disc(canvas, end, (flare + 3.0) * k, INK)
	_px_disc(canvas, end, (flare + 1.5) * k, VIOLET_HOT)
	_px_disc(canvas, end, flare * k, VOID_CORE)
	# light and dust beside it are drawn in and vanish in its core
	var across := Vector2(-direction.y, direction.x)
	for i in range(2):
		var off := _rng.randf_range(10.0, 24.0) * (1.0 if _rng.randf() < 0.5 else -1.0)
		var speed := _rng.randf_range(90.0, 160.0)
		var from := eye + direction * _rng.randf_range(12.0, length) + across * off
		_particles.append({"x": from.x, "y": from.y, "vx": -across.x * signf(off) * speed + direction.x * 20.0, "vy": -across.y * signf(off) * speed + direction.y * 20.0,
			"life": 0.0, "max": (absf(off) - 3.0) / speed, "color": [VIOLET_HOT, VIOLET, Color("a99d93")][_rng.randi_range(0, 2)], "grav": 0.0})
	# and the floor round the hole is sucked into it, swirling
	if _rng.randf() < 0.8:
		var out := Vector2.from_angle(_rng.randf() * TAU)
		var dist := _rng.randf_range(12.0, 26.0)
		var speed := _rng.randf_range(110.0, 180.0)
		var from := end + out * dist
		var pull := -out * speed + out.orthogonal() * speed * 0.35
		_particles.append({"x": from.x, "y": from.y, "vx": pull.x, "vy": pull.y,
			"life": 0.0, "max": (dist - 3.0) / speed, "color": [VIOLET_HOT, Color("7b6a5e"), Color("a99d93")][_rng.randi_range(0, 2)], "grav": 0.0})


## A filled disc on the 2 px grid (no smooth circle: the pixel look).
func _px_disc(canvas: CanvasItem, c: Vector2, r: float, col: Color) -> void:
	if r < 1.0:
		return
	var n := int(ceil(r / 2.0))
	for gy in range(-n, n + 1):
		for gx in range(-n, n + 1):
			var cell := (c / 2.0).floor() + Vector2(gx, gy)
			if ((cell + Vector2(0.5, 0.5)) * 2.0 - c).length() <= r:
				canvas.draw_rect(Rect2(cell * 2.0, Vector2(2, 2)), col)


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
