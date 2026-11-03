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
## Pieces turn on their own pixel grid (RotSprite-like, ragdoll.turn_steps) with
## a dark rim on their cut edges, never as smoothly turned cards.
## Readability in a crowd: a held item of body proportion (rigs.json item
## "scale"), an "outline" rim round a figure, held weapons of enemies in front
## of the hero that overlap him drawn behind the actors (guard_hero) and a ring
## round a hidden hero (draw_ring).
## Held items (src/rig_kit/rig_held.gd): an item with a "held" block holds art
## the host picks at run time (the hero's equipped weapon, draw_hero's `held`);
## it is drawn in the item's z slot and moves with its parent part.
## This file is the drawing facade of the rig kit (its public API is what every
## host uses): the debris physics run in RigDebris (src/rig_kit/rig_debris.gd,
## `debris`), the particles and boss effects in RigFx (src/rig_kit/rig_fx.gd,
## `fx`), both on this renderer's random numbers, so a fixed seed draws the same
## picture. What each pose family does (attack clips, death, crumbling,
## material, chips, shadow) is data: assets/data/rig_families.json.

const RigLibrary = preload("res://src/rig/rig_library.gd")
const RigPoses = preload("res://src/rig/rig_poses.gd")
## Hero element skins: a hero rig's parts drawn in his main spec's colours (hero_skins.json).
const ElementSkin = preload("res://src/hero/element_skin.gd")
const S := RigLibrary.PIXEL_SCALE
const SHADOW := Color(0.05, 0.04, 0.09, 0.45)
const VIOLET := RigFx.VIOLET
const VIOLET_DARK := RigFx.VIOLET_DARK
## Pixel flames of a burning rig (rigs.json "burn"), hot to cool: white, yellow, orange, red, crimson.
const FLAME := [Color("fdf7ed"), Color("facb3e"), Color("ee8e2e"), Color("da4e38"), Color("9f294e")]
## Soul fire (a flame's 6th entry "soul") and void fire ("void"), hot to cool.
const SOUL_FLAME := [Color("fdf7ed"), Color("cfe86b"), Color("97da3f"), Color("4ba747"), Color("235d3a")]
## Pixel slash palettes (rigs.json "slash"): RigFx.SLASH.
const SLASH := RigFx.SLASH
const SLASH_LIFE := RigFx.SLASH_LIFE
const VOID_FLAME := [Color("fdf7ed"), Color("f0b3dd"), Color("c278d0"), Color("8156aa"), Color("473579")]
const VIOLET_HOT := RigFx.VIOLET_HOT
const VOID_CORE := RigFx.VOID_CORE
const INK := RigFx.INK
## What each pose family does (see its _note).
const FAMILIES_PATH := "res://assets/data/rig_families.json"
## The attack clip when rig_families.json is missing: "attack" over the whole move.
const NEUTRAL_CLIP := ["attack", 0.0, 1.0]
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
const HIT_TIME := 0.3
## A hell rig staggers this long when one of its parts is cut off.
const STAGGER_TIME := 1.0
const BLOCK_TIME := 0.9
const RISE_TIME := 1.1
const REGROW_TIME := 1.2

var library: RefCounted
## The fallen and cut parts on the floor (RigDebris on vfx_gore.json "ragdoll"):
## pieces {key (actor), id (part), texture, layer, material, el, look, ...}.
var debris: RigDebris
## Particles, summoning pools, flashes, beams and fx events of the rigs.
var fx: RigFx
var _actors: Dictionary = {}
var _fx_seen: Dictionary = {}
var _clock := 0.0
## The debris pieces (debris.pieces), kept for tests and capture checks.
var _debris: Array[Dictionary]:
	get: return debris.pieces
## The particles (fx.particles), kept for tests and capture checks.
var _particles: Array[Dictionary]:
	get: return fx.particles
## Beams drawn in the last draw_over (for tests and capture checks).
var beams_drawn: int:
	get: return fx.beams_drawn
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
## vfx_gore.json "ragdoll": the detached parts' physics (RigDebris), tiers, cap,
## split and element looks. One dictionary, reloaded in place by load_gore, so
## every renderer's debris sees the reload.
static var _ragdoll: Dictionary = {}
static var _looks: Dictionary = {}
static var _band_cache: Dictionary = {}
static var _dither_cache: Dictionary = {}
static var _talent_read := false
static var _talent_tiers: Dictionary = {}
static var _kind_tiers: Dictionary = {}
static var _talent_types: Dictionary = {}
## rig_families.json, read on first use (load_families).
static var _family_table: Dictionary = {}
static var _families_loaded := false
## Read for a kill's feel tier (kill_tier), as src/vfx/talent_fx.gd weighs a cast.
const TALENTS_PATH := "res://assets/data/talents.json"
const VFX_TALENTS_PATH := "res://assets/data/vfx_talents.json"
## 4x4 Bayer order: a crumbling piece drops its pixels in this order.
const BAYER := [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]
## The host's walls for the debris: solid.call(world point) -> true inside a
## wall (story worlds: src/hell/drake_rig_host.gd bind_world). Unset: no walls.
var solid: Callable = Callable()
## The hero's body (world px) this frame, set by guard_hero(): an enemy standing
## in front of him (feet lower) draws a held item that overlaps it behind the
## host's actors, so his figure stays readable. Empty: off.
var hero_box := Rect2()
## True once an enemy drawn in front of the hero this frame covers hero_box with
## its body (the host then outlines the hero, src/hero/story_hero.gd).
var hero_covered := false
## The parts of those enemies that cover hero_box this frame, as drawn:
## [{xform (world transform), image (its frame's Image), bounds (Rect2i of its
## pixels in the image)}], for the hero's x-ray (draw_xray); cleared by guard_hero().
var hero_cover: Array = []
## The canvas item under the host's actors that held items behind the hero go on
## (a child of the actors canvas, drawn behind it); cleared by guard_hero().
var _back := RID()
var _back_parent := RID()
## The 1-source-px ring of an outline (under a figure, around a fallen piece).
const RING := [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]
## Pixel-grid turns of debris (_turned): upscaled sources and turned images,
## by texture; new turns built per frame are capped (the rest draw as before).
static var _up_cache: Dictionary = {}
static var _turn_cache: Dictionary = {}
var _turn_budget := 0
static var _palettes: Dictionary = {}
## Pose families the renderer does not know itself (the companions' beast,
## bird, elemental and demon, src/vfx/companion_rigs.gd): family -> {"pose":
## Callable(rig, a) -> pose, "attacks": Callable(rig, kind) -> [clip, end of
## windup, end of active]}. A registered family crumbles on death like a
## skeleton: every part falls off as debris and nothing is left to draw.
var families: Dictionary = {}


## The rig look as RigDebris' world: walls from the renderer's `solid`, the
## element matter of a fresh corpse, dust off walls and frozen parts shattering
## at their first hard landing. Holds the renderer weakly (it owns the debris).
class DebrisLook extends RigDebrisHost:
	var _view: WeakRef

	func _init(view: RefCounted) -> void:
		_view = weakref(view)

	## True inside a wall of the renderer's world (its `solid`; unset: never).
	func solid(point: Vector2) -> bool:
		var view: Variant = _view.get_ref()
		return view != null and (view.solid as Callable).is_valid() and bool(view.solid.call(point))

	## The element matter a fresh corpse piece gives off (RigFx.matter).
	func on_tick(piece: Dictionary, delta: float) -> void:
		var view: Variant = _view.get_ref()
		if view == null: return
		var clock: float = view.debris.clock
		view.fx.matter(piece, clock - float(piece.get("born", clock)), delta)

	## Dust of its chips off the wall (RigFx.wall_dust).
	func on_wall(piece: Dictionary) -> void:
		var view: Variant = _view.get_ref()
		if view != null: view.fx.wall_dust(piece)

	## A frozen piece breaks into shards (RigRenderer._shatter).
	func on_land(piece: Dictionary) -> Array[Dictionary]:
		var view: Variant = _view.get_ref()
		if view == null: return []
		return view._shatter(piece)


func _init(rig_library: RefCounted = null) -> void:
	library = rig_library if rig_library != null else RigLibrary.shared()
	_rng.seed = 90210
	fx = RigFx.new(_rng)
	debris = RigDebris.new(ragdoll_table(), DebrisLook.new(self), _rng)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and _back.is_valid():
		RenderingServer.free_rid(_back)


## Starts a frame of the host's actors drawn on `canvas` (call it before them):
## `box` is the hero's body in world px (empty: off). Held items of enemies in
## front of him that overlap it go on a canvas item behind `canvas`, and
## hero_covered tells afterwards whether such an enemy's body covered him.
func guard_hero(canvas: CanvasItem, box: Rect2) -> void:
	hero_box = box
	hero_covered = false
	hero_cover = []
	if canvas == null or not canvas.is_inside_tree():
		return
	var parent := canvas.get_canvas_item()
	if not _back.is_valid():
		_back = RenderingServer.canvas_item_create()
		RenderingServer.canvas_item_set_draw_behind_parent(_back, true)
	if parent != _back_parent:
		_back_parent = parent
		RenderingServer.canvas_item_set_parent(_back, parent)
		RenderingServer.canvas_item_set_default_texture_filter(_back, _filter_of(canvas) as RenderingServer.CanvasItemTextureFilter)
		# the back item goes with the actors canvas (a new world or floor builds another)
		if not canvas.tree_exiting.is_connected(_drop_back): canvas.tree_exiting.connect(_drop_back)
	RenderingServer.canvas_item_clear(_back)


## Frees the canvas item behind the actors (their canvas left the tree).
func _drop_back() -> void:
	if _back.is_valid(): RenderingServer.free_rid(_back)
	_back = RID()
	_back_parent = RID()


## The texture filter `item` really draws with (its own, else the nearest
## ancestor's that sets one), as a RenderingServer filter.
static func _filter_of(item: CanvasItem) -> int:
	var at: Node = item
	while at is CanvasItem:
		var f := (at as CanvasItem).texture_filter
		if f != CanvasItem.TEXTURE_FILTER_PARENT_NODE:
			return int(f)
		at = at.get_parent()
	return RenderingServer.CANVAS_ITEM_TEXTURE_FILTER_DEFAULT


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
	# reloaded in place: every renderer's debris runs on this very dictionary
	_ragdoll.clear()
	if ragdoll is Dictionary: _ragdoll.merge(ragdoll)
	_looks.clear()
	_gore_loaded = true


## vfx_gore.json "ragdoll" (loaded on first use): the physics every renderer's
## RigDebris runs on, plus tiers, split and element looks; {} without the table.
static func ragdoll_table() -> Dictionary:
	if not _gore_loaded: load_gore()
	return _ragdoll


## Loads rig_families.json (what each pose family does, see its _note); a
## missing or broken file leaves every family on neutral behaviour. Runs on
## first use; tests call it with another path.
static func load_families(path: String = FAMILIES_PATH) -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
	_family_table = parsed if parsed is Dictionary else {}
	_families_loaded = true


## What pose family `family` does for `key` (rig_families.json): its own
## entry's value, else the "default" entry's, else `neutral`.
static func family_value(family: String, key: String, neutral: Variant = null) -> Variant:
	if not _families_loaded: load_families()
	var listed: Variant = _family_table.get("families", {})
	var own: Variant = listed.get(family, {}) if listed is Dictionary else {}
	if own is Dictionary and (own as Dictionary).has(key): return own[key]
	var base: Variant = _family_table.get("default", {})
	if base is Dictionary and (base as Dictionary).has(key): return base[key]
	return neutral


## What a family added through register_family (the companions') does for
## `key` (rig_families.json "registered"), else `neutral`.
static func registered_value(key: String, neutral: Variant = null) -> Variant:
	if not _families_loaded: load_families()
	var spec: Variant = _family_table.get("registered", {})
	return spec.get(key, neutral) if spec is Dictionary else neutral


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
	debris.reset()
	fx.reset()
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
		fx.play(event)
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
			debris.pieces = debris.pieces.filter(func(d: Dictionary) -> bool: return not (d.key == a.key and d.id == id))
			var regrow_color: Color = colors.glow if not colors.is_empty() else VIOLET if rig_name in ["void", "bomber"] else Color("97da3f")
			fx.burst(Vector2(a.get("feet", Vector2(float(enemy.get("x", 0)), float(enemy.get("y", 0))))) - Vector2(0, 24), regrow_color, 12, 60.0)
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
	for d: Dictionary in debris.pieces:
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
	debris.step(delta)
	fx.step(delta)


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
	a.blood_morph = float(enemy.get("blood_morph", 0.0))
	a.curse_command = str(enemy.get("curse_command",""))
	a.curse_left = float(enemy.get("curse_left",0))
	a.bone_whirl = enemy.get("bone_whirl",{})
	a.flying = bool(enemy.get("flying", false))
	a.tint = _color_of(enemy.get("tint", Color.WHITE))
	a.alpha_mul = float(enemy.get("alpha", 1.0))
	a.hit_part = str(enemy.get("hit_part", ""))
	a.size_mul = maxf(0.0, float(enemy.get("size", 1.0)))
	a.cut = maxf(0.0, float(enemy.get("cut", 0.0)))
	a.no_shadow = not bool(enemy.get("shadow", true))
	# "outline": a dark rim one source px round the figure (the Frostgruft: pale figures on snow)
	a.outline = _color_of(enemy.get("outline", Color(0, 0, 0, 0)), Color(0, 0, 0, 0))
	# an enemy minds the hero's box (guard_hero): its weapon over him goes behind
	a.guard = true
	var face := -1.0 if float(enemy.get("face", -1.0)) < 0.0 else 1.0
	var dying_p := float(enemy.get("dying_p", -1.0))
	var family: String = str(rig.family)
	# a flung figure turns over as it flies (snapshot "tumble", the Urknall)
	a.tumble = float(enemy.get("tumble", 0.0))
	# Skeletons (and the companions' registered families) crumble and bombers burst (rig_families.json
	# "crumble"): nothing is left to draw; nor of a figure that came apart as a ragdoll (_start_death)
	if dying_p >= 0.0 and (_crumbles(family) or bool(a.get("ragdoll", false))): return NAN
	_clip_from_snapshot(a, rig, enemy, dying_p)
	var flash := clampf(float(enemy.get("hit_flash", 0.0)) / 0.16, 0.0, 1.0)
	# An escaping or fading figure takes its shadow along.
	return _draw_rig(canvas, a, rig, point, face, flash, true, float(a.alpha_mul))


## True when a dead figure of `family` leaves nothing to draw (its parts fell as
## debris): rig_families.json "crumble", or "registered" for a family added
## through register_family.
func _crumbles(family: String) -> bool:
	if families.has(family): return bool(registered_value("crumble", false))
	return bool(family_value(family, "crumble", false))


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


## Draws a hero-class player's body. `size` scales the rig (the story worlds
## draw heroes larger than the crypt), `tint` colours it (a subclass colour,
## stealth; the held art keeps its colours and takes only the alpha). With
## `held` (src/rig_kit/rig_held_host.gd) the rig's items that have a "held"
## block hold the host's art (the equipped weapon) in their z slot and carry it
## with their parent part; without it no item is drawn (the crypt view draws
## the weapon on top itself).
func draw_hero(canvas: CanvasItem, key: String, player: Dictionary, point: Vector2, rig_name: String, face: float, alpha: float = 1.0, size: float = 1.0, tint: Color = Color.WHITE, held: RigHeldHost = null) -> void:
	var rig: Dictionary = library.rig(rig_name)
	if rig.is_empty(): return
	var a := track_steps(key, player)
	a.rig = rig_name
	a.alpha_mul = alpha
	a.size_mul = size
	a.tint = tint
	a.soul_leap = player.get("leap", player.get("talents", {}).get("leap", {}))
	a.held = held
	# the element skin (src/hero/element_skin.gd): the mage's parts in his main spec's colours;
	# the story worlds give the element with the player, the crypt's comes from its talents
	a.skin = ElementSkin.class_for_rig(rig_name)
	a.element = ElementSkin.element_for_player(player) if not str(a.skin).is_empty() else ""
	# player "outline": a dark rim round the hero (the Frostgruft); the hero never hides behind himself
	a.outline = _color_of(player.get("outline", Color(0, 0, 0, 0)), Color(0, 0, 0, 0))
	a.guard = false
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


## [clip, end of windup, end of active] in clip progress, per figure and move:
## a registered family's own mapping, else rig_families.json "attacks" of its
## family (by the rig's variant, the drake's pose table, by the attack's kind,
## else the family's default).
func _attack_mapping(rig: Dictionary, kind: String) -> Array:
	var registered: Dictionary = families.get(str(rig.family), {})
	if not registered.is_empty() and (registered.attacks as Callable).is_valid():
		var mapped: Variant = registered.attacks.call(rig, kind)
		if mapped is Array and (mapped as Array).size() >= 3: return mapped
	if str(rig.family)=="skeleton":
		if kind=="bone_stomp": return ["stomp",0.45,0.6]
		if kind=="bone_whirl": return ["bonecast",0.35,0.5]
	var spec: Variant = family_value(str(rig.family), "attacks", {})
	var attacks: Dictionary = spec if spec is Dictionary else {}
	var variants: Variant = attacks.get("variants", {})
	var variant := str(rig.get("variant", ""))
	if variants is Dictionary and (variants as Dictionary).has(variant): return _clip_of(variants[variant])
	if str(attacks.get("pose_table", "")) == "drake":
		# bolt->bite, slam, dash, burrow, swing, sweep, ring/echoes->roar, beam, flight
		var clip := str(RigPoses.DRAKE_KINDS.get(kind, ""))
		if not clip.is_empty():
			var windows: Array = RigPoses.DRAKE_WINDOWS[clip]
			return [clip, float(windows[0]), float(windows[1])]
	var kinds: Variant = attacks.get("kinds", {})
	if kinds is Dictionary and (kinds as Dictionary).has(kind): return _clip_of(kinds[kind])
	return _clip_of(attacks.get("default", NEUTRAL_CLIP))


## A [clip, end of windup, end of active] of rig_families.json as a new array; NEUTRAL_CLIP when malformed.
static func _clip_of(value: Variant) -> Array:
	if value is Array and (value as Array).size() >= 3: return [str(value[0]), float(value[1]), float(value[2])]
	return NEUTRAL_CLIP.duplicate()


func _start_rise(a: Dictionary, rig: Dictionary, enemy: Dictionary) -> void:
	a.rise = RISE_TIME
	var from: Dictionary = {}
	for part: Dictionary in rig.parts + rig.items: from[part.id] = {"dx": _rng.randf_range(-3, 3), "dy": _rng.randf_range(8, 13), "rot": _rng.randf_range(-1.2, 1.2)}
	a.rise_from = from
	var feet := Vector2(float(enemy.get("x", 0)), float(enemy.get("y", 0))) + Vector2(0, (float(rig.ground.y) - float(rig.center.y)) * _scale(rig))
	fx.pool(feet, 18.0, 2.6)


## The death of actor `a` by its family's rig_families.json "death": every part
## flies with the blow (ragdoll; a brute only under a tearing blow, else it
## sheds its weapon, arm and head), named parts fall off (shed), bursts and
## flashes; a registered family (companion) comes apart like a skeleton. Cut in
## two by Rage (snapshot "slice"), the slice effect shows it instead.
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
	var tears: bool = bool(kill.wall) or impulse >= float(Dictionary(_rag("tiers", {})).get("huge", INF))
	# A companion (registered family) falls apart like a skeleton: every part drops.
	if families.has(family):
		_ragdoll_all(a, rig, kill, float(Dictionary(registered_value("death", {})).get("ragdoll", 1.0)) * impulse)
		return
	var spec: Variant = family_value(family, "death", {})
	var death: Dictionary = spec if spec is Dictionary else {}
	var material := str(rig.get("material", ""))
	if death.has("ragdoll"): _ragdoll_all(a, rig, kill, float(death.ragdoll) * impulse)
	elif death.has("tear_ragdoll") and tears: _ragdoll_all(a, rig, kill, float(death.tear_ragdoll) * impulse)
	else:
		# a held weapon (the Knochenkoloss' hammer) leaves the hand on its own path; what flies
		# off and hides is shed, so the falling body no longer draws it as well
		for shed: Dictionary in death.get("shed", []):
			var ids: Array = []
			if str(shed.get("ids", "")) == "items":
				for item: Dictionary in rig.items: ids.append(str(item.id))
			else: ids = shed.get("ids", [])
			for id: Variant in ids:
				if bool(shed.get("skip_gone", false)) and (not rig.by_id.has(str(id)) or a.lost.has(str(id))): continue
				_detach(a, rig, str(id), float(shed.get("impulse", 1.0)) * impulse, kill)
				if bool(shed.get("hide", false)): a.shed[str(id)] = true
	for spec_burst: Dictionary in death.get("bursts", []):
		if spec_burst.has("when") and not bool(enemy.get(str(spec_burst.when), false)): continue
		if spec_burst.has("unless") and bool(enemy.get(str(spec_burst.unless), false)): continue
		var color := Color.WHITE
		if spec_burst.has("palette"):
			var colors := palette(material)
			if colors.is_empty() and spec_burst.has("fallback_material"): colors = palette(str(spec_burst.fallback_material))
			if colors.is_empty(): continue
			color = colors[str(spec_burst.palette)]
		else: color = _hex(spec_burst.get("color"), Color.WHITE)
		fx.burst(feet - Vector2(0, float(spec_burst.get("at", 0.0))), color, int(spec_burst.get("count", 0)), float(spec_burst.get("speed", 0.0)))
	for flash: Dictionary in death.get("flashes", []):
		if flash.has("material") and str(flash.material) != material: continue
		fx.flash(feet.x, feet.y - float(flash.get("at", 0.0)), float(flash.get("r", 0.0)), float(flash.get("max", 0.0)), _hex(flash.get("color"), VIOLET))
	# flung against a wall a moment ago (fling_near) without a wall kill of its own: it comes apart along the rebound
	var fling: Dictionary = a.get("fling", {})
	if not bool(kill.wall) and not fling.is_empty() and _clock - float(fling.get("t", -100.0)) <= _fling_value("time"): _fling_apart(a)


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
	var tiers: Dictionary = _rag("tiers", {})
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
	var map: Dictionary = _rag("talent_element", {})
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


## A value of vfx_gore.json "ragdoll", else `neutral`.
static func _rag(key: String, neutral: Variant = 0.0) -> Variant:
	if not _gore_loaded: load_gore()
	return _ragdoll.get(key, neutral)


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
	var split: Dictionary = _rag("split", {})
	var pieces := 1
	if str(rig.family) in Array(split.get("families", [])):
		var tall := float(Rect2(layer.get("bounds", Rect2())).size.y)
		pieces = clampi(ceili(tall / maxf(1.0, float(split.get("piece_px", 7)))), 1, int(split.get("most", 4)))
	# a weapon or shield (rig.items carry a "hand"; a weapon drawn into the figure a "tip") comes loose from the hand
	var held := part.has("hand") or part.has("tip")
	for piece: Dictionary in _bands(layer, pieces):
		debris.add(_piece(a, rig, id, piece, xform, impulse, kill, body, material, held))
	var chips: Array = cut_colors(rig)
	for i in range(6): fx.add({"x": center.x, "y": center.y, "vx": _rng.randf_range(-60, 60), "vy": _rng.randf_range(-60, 20), "life": 0.0, "max": _rng.randf_range(0.25, 0.5),
		"color": chips[i % chips.size()], "grav": 240.0})
	# Glowing rigs spit embers (or void sparks) from the cut.
	var colors := palette(material)
	if not colors.is_empty(): fx.burst(center, colors.glow, 8, 70.0)


## One debris piece of part `id` (its drawable `layer`, posed by `xform`),
## launched by RigDebris.launch from the blow `kill` (impulse, its direction
## out of `body`, the figure's scale). `held`: a weapon or shield coming loose
## from the hand (ragdoll.loose): it leaves the blow's cone to the side its hand
## is on and turns over - it never keeps its held angle next to the skull,
## which read as a sword still carried by a flying body.
func _piece(a: Dictionary, rig: Dictionary, id: String, layer: Dictionary, xform: Transform2D, impulse: float, kill: Dictionary, body: Vector2, material: String, held := false) -> Dictionary:
	var center: Vector2 = xform * Vector2(layer.center)
	var ground: float = Vector2(a.get("feet", center)).y
	# a bigger figure (story worlds) throws in proportion: the same flight in its own source px
	var k := _scale(rig) / S
	var flight := debris.launch(kill.get("dir", Vector2.ZERO), center - body, impulse, k, held)
	var el := str(kill.get("el", ""))
	var look := _look(el)
	return {"key": a.key, "id": id, "texture": layer.texture, "white": layer.get("white"), "layer": layer, "center": layer.center,
		"x": center.x, "y": ground + _rng.randf_range(-4, 6), "z": maxf(0.0, ground - center.y),
		"vx": flight.vx, "vy": flight.vy, "vz": flight.vz, "k": k, "held": held,
		"ang": xform.get_rotation(), "spin": flight.spin,
		"face": signf(xform.x.x) if absf(xform.x.x) > 0.01 else 1.0, "scale": _scale(rig) * (RigLibrary.item_factor(rig.by_id.get(id, {}), _scale(rig)) if held else 1.0), "life": 0.0, "max": INF, "rest": false,
		"material": material, "el": el, "look": look, "born": _clock, "spots": _spots_for(layer, look)}


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
	var spec: Variant = Dictionary(_rag("elements", {})).get(el, {})
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


## A frozen piece (look "shatter": pieces) breaks at its first hard landing
## into that many shards that fly on, with ice chips; returns the shards and
## marks the piece broken. [] for every other piece. RigDebris calls it through
## DebrisLook.on_land.
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
	fx.burst(Vector2(float(d.x), float(d.y) - 2.0), look.get("chip_c", Color("cfefff")), int(look.get("chips", 8)), 70.0)
	d.broken = true
	return out


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
## A piece turned on its pixel grid (`turn` from _turned) moves its spots along.
func _draw_look(canvas: CanvasItem, d: Dictionary, look: Dictionary, turn: Dictionary = {}) -> void:
	var spots: Array = d.get("spots", [])
	if spots.is_empty(): return
	var age := _clock - float(d.get("born", _clock))
	var heat := 1.0 - clampf(age / maxf(0.01, float(look.get("ember_time", 3.0))), 0.0, 1.0)
	for i in range(spots.size()):
		var spot: Dictionary = spots[i]
		var at := Vector2(spot.p)
		if not turn.is_empty(): at = ((at + Vector2(0.5, 0.5) - Vector2(turn.c)).rotated(float(turn.theta)) + Vector2(turn.half)).floor()
		if str(spot.kind) == "ember":
			if heat <= 0.0: continue
			var hot := heat * (0.6 + 0.4 * (0.5 + 0.5 * sin(_clock * 9.0 + float(i) * 2.1)))
			var color: Color = FLAME[1] if hot > 0.7 else FLAME[2] if hot > 0.4 else FLAME[3] if hot > 0.15 else FLAME[4]
			canvas.draw_rect(Rect2(at, Vector2.ONE), color)
		else:
			canvas.draw_rect(Rect2(at, Vector2.ONE), look.rime_c)


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


## The gore material of actor `key`: its rig's material, else its family's
## (rig_families.json "material": bone for the skeletons, void for void
## figures, blood for the rest), "" unknown.
func actor_material(key: String) -> String:
	var a: Dictionary = _actors.get(key, {})
	if a.is_empty() or library == null: return ""
	var rig: Dictionary = library.rig(str(a.get("rig", "")))
	if not str(rig.get("material", "")).is_empty(): return str(rig.material)
	if rig.is_empty(): return ""
	return str(family_value(str(rig.get("family", "")), "material", ""))


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
	for d: Dictionary in debris.pieces:
		if str(d.key) == str(a.key): fallen[str(d.id)] = true
	for part: Dictionary in rig.items + rig.parts:
		var id := str(part.id)
		if fallen.has(id) or a.lost.has(id) or a.shed.has(id): continue
		_detach(a, rig, id, 1.0)
		a.shed[id] = true
	if not _gore_loaded: load_gore()
	for d: Dictionary in debris.pieces:
		if str(d.key) != str(a.key) or float(d.life) > _fling_value("time") or bool(d.get("flung", false)): continue
		# a loose weapon or shield leaves the rebound's line and turns over (ragdoll.loose, see _piece)
		debris.fling(d, Vector2(fling.dir), float(fling.power), _gore_fling)
		d.flung = true
	a.fling = {}


## A number of vfx_gore.json splat.fling, else `neutral`.
static func _fling_value(key: String, neutral: float = 0.0) -> float:
	if not _gore_loaded: load_gore()
	return float(_gore_fling.get(key, neutral))


## Colours of the chips cut from a rig: its material's (hell rigs), else its
## family's (rig_families.json "chips": violet for void figures, bone white for
## the rest).
static func cut_colors(rig: Dictionary) -> Array:
	var material := str(rig.get("material", ""))
	var colors := palette(material)
	if not colors.is_empty(): return colors.chips
	var out: Array = []
	for c: Variant in family_value(str(rig.get("family", "")), "chips", []): out.append(_hex(c, Color.WHITE))
	return out if not out.is_empty() else [Color.WHITE]


## The pose of a rig for an actor state: a registered family's own, else RigPoses'.
func _pose(rig: Dictionary, a: Dictionary) -> Dictionary:
	var registered: Dictionary = families.get(str(rig.get("family", "")), {})
	if not registered.is_empty() and (registered.pose as Callable).is_valid():
		var pose: Variant = registered.pose.call(rig, a)
		if pose is Dictionary and pose.has("whole") and pose.has("parts"): return pose
	return RigPoses.pose(rig, a)


## Held items of actor `a` (src/rig_kit/rig_held.gd): asks `host` for the pieces
## of every rig item with a "held" block (placed for the figure standing still
## at `feet`, `face` and its size), carries each with its parent part's motion
## in `world` and puts the item into `layers` (sorted by z) in its z slot.
func _hold(rig: Dictionary, a: Dictionary, host: RigHeldHost, feet: Vector2, face: float, world: Dictionary, layers: Array) -> void:
	var scale := _actor_scale(rig, a)
	# the figure standing still: _solve's base for a neutral pose (every part's rest)
	var rest := _t(feet) * _s(Vector2(face * scale, scale)) * _t(-Vector2(rig.ground))
	rest.origin = rest.origin.round()
	for item: Dictionary in rig.items:
		if RigHeld.spec(item).is_empty() or a.lost.has(item.id) or (a.get("shed", {}) as Dictionary).has(item.id): continue
		var pieces: Array[Dictionary] = host.pieces(str(a.key), item, rest)
		if pieces.is_empty(): continue
		var parent := str(item.get("parent", ""))
		var posed: Transform2D = world[parent] if world.has(parent) and not a.lost.has(parent) else world.base
		var held: Array[Dictionary] = []
		for piece: Dictionary in pieces: held.append({"piece": piece, "follow": RigHeld.follow(rest, posed, Vector2(piece.get("hand", Vector2.ZERO)))})
		layers.insert(RigHeld.slot(layers, int(item.get("z", 0))), {"id": str(item.id), "z": int(item.get("z", 0)), "holding": held})


func _draw_rig(canvas: CanvasItem, a: Dictionary, rig: Dictionary, point: Vector2, face: float, flash: float, with_items: bool, shadow_alpha: float) -> float:
	var pose: Dictionary = _pose(rig, a)
	var leap: Dictionary = a.get("soul_leap", {})
	var shadow_drop := 0.0
	if not leap.is_empty():
		var p := clampf(float(leap.age) / float(leap.duration), 0.0, 1.0)
		var tuck := sin(p * PI)
		RigPoses.P(pose, "robe").rot += tuck * 0.2
		RigPoses.P(pose, "robe").sx *= 1.0 + tuck * 0.1
		RigPoses.P(pose, "robe").sy *= 1.0 - tuck * 0.12
		RigPoses.P(pose, "hood").rot -= tuck * 0.12
		RigPoses.P(pose, "hood").dy -= tuck
		RigPoses.P(pose, "torso").rot += tuck * 0.12
		RigPoses.P(pose, "head").rot -= tuck * 0.09
		RigPoses.P(pose, "arm_l").rot -= tuck * 0.5
		RigPoses.P(pose, "arm_r").rot += tuck * 0.45
		RigPoses.P(pose, "leg_l").rot += tuck * 0.65
		RigPoses.P(pose, "leg_r").rot -= tuck * 0.55
		shadow_drop = preload("res://src/combat/soul_leap.gd").lift(leap)
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
	var family := str(rig.family)
	# rig_families.json: void figures and necromancers lose their shadow as they die
	if (not dying or bool(family_value(family, "dying_shadow", true))) and not bool(a.get("no_shadow", false)):
		var shadow := float(rig.width) * S
		# A flying dragon's shadow shrinks below it (rig_families.json "flight_shadow").
		var lift: Variant = family_value(family, "flight_shadow", null)
		if lift is Array and (lift as Array).size() >= 2: shadow *= 1.0 - clampf(-float(pose.whole.dy) / float(lift[0]), 0.0, float(lift[1]))
		_rect(canvas, Rect2(feet.x - shadow * 0.5, feet.y - S + shadow_drop, shadow, 3.0 * S), Color(SHADOW, SHADOW.a * shadow_alpha), "shadow", "")
	var layers: Array = []
	for part: Dictionary in rig.parts:
		if not world.has(part.id): continue
		# Hell rigs: a part hangs on its parent, so it goes with a lost one.
		if (_hidden(rig, a, part.id) if layered else (a.lost.has(part.id) or (a.get("shed", {}) as Dictionary).has(part.id))): continue
		layers.append(part)
	if with_items:
		for item: Dictionary in rig.items:
			if not a.lost.has(item.id) and not (a.get("shed", {}) as Dictionary).has(item.id) and world.has(item.id): layers.append(item)
	layers.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return int(p.z) < int(q.z))
	# held items (src/rig_kit/rig_held.gd): the host's art in an item's hand, in the item's z slot
	var held_host: Variant = a.get("held")
	if held_host is RigHeldHost: _hold(rig, a, held_host, feet + Vector2(0, cut), face, world, layers)
	var frames: Dictionary = pose.get("frames", {})
	# a summoned figure fades in as it rises, a skeleton climbs out opaque (rig_families.json "rise_fade")
	var rise_fade := bool(family_value(family, "rise_fade", true))
	var alpha_of := func(part: Dictionary) -> float:
		var state: Dictionary = pose.parts.get(part.id, {})
		var alpha: float = float(state.get("alpha", 1.0))
		if float(a.rise) > 0.0 and rise_fade: alpha *= 1.0 - float(a.rise) / RISE_TIME
		alpha *= float(a.get("alpha_mul", 1.0))
		return alpha
	var layer_of := func(part: Dictionary) -> Dictionary:
		if part.get("frames") is Array and not part.frames.is_empty():
			var index: int = int(frames.get(part.id, 0)) % int(part.frames.size())
			a["frame_" + str(part.id)] = index
			return part.frames[index]
		return part
	# An enemy standing in front of the hero (guard_hero): a held weapon over his body goes on the
	# canvas item behind the actors, so it passes behind him; its body over him is noted (hero_covered)
	var behind: Dictionary = {}
	if bool(a.get("guard", false)) and hero_box.has_area() and feet.y > hero_box.end.y:
		for part: Dictionary in layers:
			if part.has("holding"): continue
			var item := bool(part.get("is_item", false))
			# a held item's bounds are its box in the figure (rig_library.gd _item_bounds): test its own image
			var box := Rect2(Vector2.ZERO, Vector2(part.get("size", Vector2.ZERO))) if item else Rect2(part.bounds)
			if not _world_box(Transform2D(world[part.id]), box).intersects(hero_box): continue
			if item and not bool(part.get("bow", false)) and _back.is_valid(): behind[part.id] = true
			else:
				hero_covered = true
				# the covering part as drawn, for the hero's x-ray (draw_xray)
				var shape: Dictionary = layer_of.call(part)
				if shape.get("image") is Image and float(alpha_of.call(part)) > 0.01:
					hero_cover.append({"xform": Transform2D(world[part.id]), "image": shape.image,
						"bounds": Rect2i(box) if item else Rect2i(Rect2(shape.get("bounds", part.bounds)))})
	# Void figures: a violet rim around the whole silhouette.
	var aura := float(pose.get("aura", 0.0))
	if aura > 0.0:
		var offsets := [Vector2(2, 0), Vector2(-2, 0), Vector2(0, 1), Vector2(0, -1)] if bool(pose.get("glitch", false)) else [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]
		for part: Dictionary in layers:
			if part.has("holding"): continue
			var alpha: float = alpha_of.call(part)
			if alpha <= 0.01: continue
			var layer: Dictionary = layer_of.call(part)
			for offset: Vector2 in offsets: _put(canvas, behind.has(part.id), world[part.id], layer.white, Color(VIOLET_DARK, clampf(aura, 0.0, 1.0) * alpha), "aura", part.id, offset)
	# An outlined figure (a.outline): its silhouette one source px out on every side, under all its parts
	var outline: Color = a.get("outline", Color(0, 0, 0, 0))
	if outline.a > 0.0:
		for part: Dictionary in layers:
			var alpha: float = alpha_of.call(part)
			if part.has("holding"):
				for h: Dictionary in part.holding: RigHeld.draw_outline(canvas, h.piece, h.follow, Color(outline, outline.a * alpha), RING)
				continue
			var layer: Dictionary = layer_of.call(part)
			if alpha <= 0.01 or layer.get("white") == null: continue
			var rows := _rows_above(part, Transform2D(world[part.id]), clip_y)
			if rows <= float(Rect2(part.bounds).position.y): continue
			for offset: Vector2 in RING: _put(canvas, behind.has(part.id), world[part.id], layer.white, Color(outline, outline.a * alpha), "outline", part.id, offset, rows)
	var fuse := float(pose.get("fuse", 0.0))
	if fuse > 0.0: flash = maxf(flash, 0.8 * fuse if sin(float(a.ct) * (20.0 + 50.0 * fuse)) > 0.0 else 0.0)
	var shown: Dictionary = {}
	for part: Dictionary in layers:
		if not part.has("holding"): shown[part.id] = true
	# The hit flash lights only the struck part while it is drawn.
	var flash_part := str(a.get("hit_part", ""))
	if not shown.has(flash_part): flash_part = ""
	var tint: Color = a.get("tint", Color.WHITE)
	var glow: Dictionary = pose.get("glow", {})
	var glow_color: Color = colors.glow if layered else Color("ffb347")
	var flashed: Array[String] = []
	# Parts actually put on the canvas (visible, not wholly below the floor): what a hit can land on.
	var hittable: Dictionary = {}
	# where each held item's pieces went (item id -> placed pieces)
	var held_drawn: Dictionary = {}
	for part: Dictionary in layers:
		var alpha: float = alpha_of.call(part)
		if alpha <= 0.01: continue
		if part.has("holding"):
			var placed: Array[Dictionary] = []
			for h: Dictionary in part.holding: placed.append(RigHeld.draw(canvas, h.piece, h.follow, alpha))
			held_drawn[part.id] = placed
			(held_host as RigHeldHost).drawn(str(a.key), str(part.id), placed)
			if record_draws: draw_log.append({"what": "held", "id": part.id, "color": Color(1, 1, 1, alpha)})
			continue
		var layer: Dictionary = layer_of.call(part)
		var back: bool = behind.has(part.id)
		canvas.draw_set_transform_matrix(world[part.id])
		# Below the floor line (a sinking figure) nothing of the part is drawn.
		var rows := _rows_above(part, Transform2D(world[part.id]), clip_y)
		if rows <= float(Rect2(part.bounds).position.y): continue
		hittable[part.id] = true
		_put(canvas, back, world[part.id], _skinned(layer.texture, a), Color(tint.r, tint.g, tint.b, tint.a * alpha), "part", part.id, Vector2.ZERO, rows)
		var heat := clampf(float(glow.get(part.id, 0.0)), 0.0, 1.0)
		if heat > 0.0 and layer.get("white") != null: _put(canvas, back, world[part.id], layer.white, Color(glow_color, 0.55 * heat * alpha), "glow", part.id, Vector2.ZERO, rows)
		if flash > 0.0 and (flash_part.is_empty() or flash_part == part.id):
			_put(canvas, back, world[part.id], layer.white, Color(1, 1, 1, flash * alpha), "flash", part.id, Vector2.ZERO, rows)
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
	a.drawn = {"shown": shown, "hittable": hittable, "flashed": flashed, "stumps": stumps, "glow": glow.duplicate(), "tint": tint, "alpha": float(a.get("alpha_mul", 1.0)),
		"held": held_drawn}
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
		RigFx.draw_slash(canvas, a.trail, maxf(2.0, roundf(S)), slash)
	else:
		for i in range(1, a.trail.size()):
			canvas.draw_line(a.trail[i - 1].p, a.trail[i].p, Color(0.92, 0.97, 1.0, 0.65 * (1.0 - float(a.trail[i].age) / 0.12)), 2.0)
	if pose.has("beam"): fx.beams.append({"key": a.key, "eye": world.get("eye", world.base) * Vector2(rig.get("eye_center", Vector2(22, 23))), "beam": pose.beam, "t": a.t, "ct": a.ct})
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


## One texture of an actor under `xform`: on `canvas`, or with `back` on the
## canvas item behind the host's actors (guard_hero; logged with "behind").
func _put(canvas: CanvasItem, back: bool, xform: Transform2D, texture: Texture2D, color: Color, what: String, id: String, offset := Vector2.ZERO, rows := INF) -> void:
	if not back or not _back.is_valid():
		canvas.draw_set_transform_matrix(xform)
		_tex(canvas, texture, color, what, id, offset, rows)
		return
	var size := texture.get_size()
	RenderingServer.canvas_item_add_set_transform(_back, xform)
	if rows < size.y:
		var keep := Rect2(Vector2.ZERO, Vector2(size.x, maxf(0.0, rows)))
		RenderingServer.canvas_item_add_texture_rect_region(_back, Rect2(offset, keep.size), texture.get_rid(), keep, color)
	else:
		RenderingServer.canvas_item_add_texture_rect(_back, Rect2(offset, size), texture.get_rid(), false, color)
	if record_draws: draw_log.append({"what": what, "id": id, "color": color, "behind": true})


## The world box of source rect `box` under `xform` (its four corners).
static func _world_box(xform: Transform2D, box: Rect2) -> Rect2:
	var out := Rect2(xform * box.position, Vector2.ZERO)
	for corner: Vector2 in [Vector2(box.end.x, box.position.y), box.end, Vector2(box.position.x, box.end.y)]:
		out = out.expand(xform * corner)
	return out


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
		fx.add({"x": c.x, "y": c.y, "vx": _rng.randf_range(-8, 8), "vy": _rng.randf_range(-50, -25), "life": 0.0, "max": _rng.randf_range(0.3, 0.6), "color": colors[2]})


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


## Rings round the figure actor `key` showed in its last draw, on its own pixel
## grid, drawn over whatever stands in front of it: `inner` one source px round
## its silhouette, `outer` one px further out (alpha 0 leaves a ring out). The
## hero hidden behind an enemy keeps his outline (src/hero/story_hero.gd).
## Returns the number of ring pixels drawn (0 for an unknown or undrawn actor).
func draw_ring(canvas: CanvasItem, key: String, inner: Color, outer: Color) -> int:
	var figure := _silhouette(key)
	if figure.is_empty(): return 0
	var base: Transform2D = figure.base
	var mask: Dictionary = figure.mask
	var first: Dictionary = {}
	for cell: Vector2i in mask:
		for step: Vector2 in RING:
			var n := cell + Vector2i(step)
			if not mask.has(n): first[n] = true
	var second: Dictionary = {}
	if outer.a > 0.0:
		for cell: Vector2i in first:
			for step: Vector2 in RING:
				var n := cell + Vector2i(step)
				if not mask.has(n) and not first.has(n): second[n] = true
	canvas.draw_set_transform_matrix(base)
	var drawn := 0
	for ring: Array in [[second, outer], [first, inner]]:
		var color: Color = ring[1]
		if color.a <= 0.0: continue
		for cell: Vector2i in ring[0]:
			canvas.draw_rect(Rect2(Vector2(cell), Vector2.ONE), color)
			drawn += 1
	canvas.draw_set_transform_matrix(Transform2D.IDENTITY)
	return drawn


## The x-ray of actor `key` (the hero) where the figures in front of him hide
## him: every source px of his last drawn silhouette that lies under an opaque
## pixel of one of `covers` (hero_cover of the enemies' renderers: {xform,
## image, bounds}) is drawn in `fill`, and the px round those cells outside his
## silhouette in `rim` (his dark one-pixel outline), on his own pixel grid, over
## whatever stands in front of him. Where he is visible nothing is drawn.
## Returns the number of x-ray px drawn (0: nothing of him is hidden).
func draw_xray(canvas: CanvasItem, key: String, covers: Array, fill: Color, rim: Color) -> int:
	if covers.is_empty() or fill.a <= 0.0: return 0
	var figure := _silhouette(key)
	if figure.is_empty(): return 0
	var base: Transform2D = figure.base
	var mask: Dictionary = figure.mask
	# each cover's opaque pixels, found from a world point through its inverse placement
	var tests: Array = []
	for c: Dictionary in covers:
		var image: Variant = c.get("image")
		if not image is Image: continue
		var xform: Transform2D = c.get("xform", Transform2D.IDENTITY)
		var box := Rect2i(c.get("bounds", Rect2i(Vector2i.ZERO, (image as Image).get_size())))
		box = box.intersection(Rect2i(Vector2i.ZERO, (image as Image).get_size()))
		if not box.has_area(): continue
		tests.append({"inv": xform.affine_inverse(), "image": image, "box": box, "world": _world_box(xform, Rect2(box))})
	if tests.is_empty(): return 0
	var hidden: Dictionary = {}
	for cell: Vector2i in mask:
		var at := base * (Vector2(cell) + Vector2(0.5, 0.5))
		for t: Dictionary in tests:
			if not (t.world as Rect2).has_point(at): continue
			var q := Vector2i(((t.inv as Transform2D) * at).floor())
			if (t.box as Rect2i).has_point(q) and (t.image as Image).get_pixelv(q).a >= 0.5:
				hidden[cell] = true
				break
	if hidden.is_empty(): return 0
	var edge: Dictionary = {}
	if rim.a > 0.0:
		for cell: Vector2i in hidden:
			for step: Vector2 in RING:
				var n := cell + Vector2i(step)
				if not mask.has(n): edge[n] = true
	canvas.draw_set_transform_matrix(base)
	for cell: Vector2i in edge:
		canvas.draw_rect(Rect2(Vector2(cell), Vector2.ONE), rim)
	for cell: Vector2i in hidden:
		canvas.draw_rect(Rect2(Vector2(cell), Vector2.ONE), fill)
	canvas.draw_set_transform_matrix(Transform2D.IDENTITY)
	return hidden.size()


## The silhouette actor `key` showed in its last draw: {base (its base part's
## world transform), mask ({Vector2i source px in the base frame: true})}, or
## {} for an unknown or undrawn actor. Every shown part and item is placed by
## its pose; a pixel counts from alpha 0.5.
func _silhouette(key: String) -> Dictionary:
	var a: Dictionary = _actors.get(key, {})
	var world: Dictionary = a.get("world", {})
	var shown: Dictionary = a.get("drawn", {}).get("shown", {})
	var rig: Dictionary = library.rig(str(a.get("rig", ""))) if library != null else {}
	if rig.is_empty() or not world.has("base") or shown.is_empty(): return {}
	var base: Transform2D = world.base
	var to_base := base.affine_inverse()
	var mask: Dictionary = {}
	for part: Dictionary in rig.parts + rig.items:
		if not shown.has(part.id) or not world.has(part.id): continue
		var layer: Dictionary = part
		if part.get("frames") is Array and not part.frames.is_empty(): layer = part.frames[int(a.get("frame_" + str(part.id), 0)) % part.frames.size()]
		var image: Variant = layer.get("image")
		if not image is Image: continue
		var local: Transform2D = to_base * Transform2D(world[part.id])
		var box := Rect2i(Rect2(layer.get("bounds", Rect2())))
		for y in range(maxi(0, box.position.y), mini(box.end.y, (image as Image).get_height())):
			for x in range(maxi(0, box.position.x), mini(box.end.x, (image as Image).get_width())):
				if (image as Image).get_pixel(x, y).a < 0.5: continue
				var q := local * Vector2(x + 0.5, y + 0.5)
				mask[Vector2i(floori(q.x), floori(q.y))] = true
	return {"base": base, "mask": mask}


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


## Shared hierarchy solver for local effect rigs. They have no severable game
## parts and use continuous flight coordinates; ordinary actors keep snapping.
func solve_pose(rig: Dictionary, pose: Dictionary, feet: Vector2, face: float, world_scale: float) -> Dictionary:
	return _solve(rig, {"lost": {}, "size_mul": world_scale / _scale(rig)}, pose, feet, face, false, false)


func _solve(rig: Dictionary, a: Dictionary, pose: Dictionary, feet: Vector2, face: float, with_items: bool, snap_origin: bool = true) -> Dictionary:
	var S: float = _actor_scale(rig, a)
	var whole: Dictionary = pose.whole
	var ground: Vector2 = rig.ground
	var pivot: Vector2 = whole.pivot if whole.pivot is Vector2 else ground
	# whole.turn (the drake's tail whirl): the figure spins about its vertical
	# axis, 1 -> -1 -> 1, mirrored about the feet.
	var turn := float(whole.get("turn", 1.0))
	var base := _t(feet + Vector2(float(whole.dx) * face * S, float(whole.dy) * S)) * _s(Vector2(face * turn * S, S)) * _t(-ground) * _tumble(rig, a) * _t(pivot) * Transform2D(float(whole.rot), Vector2.ZERO) * _s(Vector2(float(whole.sx), float(whole.sy))) * _t(-pivot)
	if snap_origin: base.origin = base.origin.round()
	var world: Dictionary = {"base": base}
	for part: Dictionary in rig.parts: _part_world(rig, a, pose, world, part.id)
	if with_items:
		for item: Dictionary in rig.items:
			if a.lost.has(item.id): continue
			var parent: String = str(item.parent)
			var parent_world: Transform2D = world[parent] if world.has(parent) and not a.lost.has(parent) else base
			var o: Dictionary = pose.items.get(item.id, {"dx": 0.0, "dy": 0.0, "rot": 0.0})
			# an item of body proportion (rigs.json item "scale") is drawn smaller, still on the pixel grid
			var k := RigLibrary.item_factor(item, _scale(rig))
			world[item.id] = parent_world * _t(Vector2(item.hand) + Vector2(float(o.dx), float(o.dy))) * Transform2D(float(item.rest) + float(o.rot), Vector2.ZERO) * _s(Vector2(k, k)) * _t(-Vector2(item.grip))
	return world


func _part_world(rig: Dictionary, a: Dictionary, pose: Dictionary, world: Dictionary, id: String) -> Transform2D:
	if world.has(id): return world[id]
	var part: Dictionary = rig.by_id[id]
	var p: Dictionary = pose.parts.get(id, {"dx": 0.0, "dy": 0.0, "rot": 0.0, "sx": 1.0, "sy": 1.0})
	var parent: String = str(part.parent)
	var parent_world: Transform2D = _part_world(rig, a, pose, world, parent) if not parent.is_empty() and rig.by_id.has(parent) and not a.lost.has(parent) else world.base
	var pivot: Vector2 = part.pivot
	var local := _t(pivot + Vector2(float(p.dx), float(p.dy))) * Transform2D(float(p.rot), Vector2.ZERO) * _s(Vector2(float(p.get("sx", 1.0)), float(p.get("sy", 1.0)))) * _t(-pivot)
	# Continuous VFX skinning may need shear to meet two moving endpoints exactly.
	# It is still solved through this parent hierarchy; ordinary actor poses keep TRS.
	if p.get("local_transform") is Transform2D: local = p.local_transform
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
## ragdoll.cap) drops its pixels by a 4x4 dither, never by transparency. A
## piece turns on its own pixel grid (_turned: its sprite's pixels, a dark rim
## on its cut edge), so a falling skull reads as pixel matter, not a card.
func draw_under(canvas: CanvasItem) -> void:
	fx.draw_pools(canvas)
	_turn_budget = int(_rag("turn_new", 0))
	for d: Dictionary in debris.pieces:
		var texture: Texture2D = d.texture
		var gone := float(d.get("gone_at", -1.0))
		# crumbling (above ragdoll.cap): a quarter more of its pixels gone each dither_time / 4
		var level := debris.crumble_level(d)
		if level >= 4: continue
		if float(d.z) > 1.0: canvas.draw_rect(Rect2(float(d.x) - 8, float(d.y) - 2, 16, 4), Color(SHADOW, 0.3))
		var pos := Vector2(float(d.x), float(d.y) - float(d.z)).round()
		var scale := float(d.get("scale", S))
		var look: Dictionary = d.get("look", {})
		var tint: Color = look.get("tint_color", Color.WHITE) if not look.is_empty() else Color.WHITE
		var turn := _turned(d, level)
		var white: Variant = d.get("white")
		if not turn.is_empty():
			canvas.draw_set_transform_matrix(_t(pos) * _s(Vector2(float(d.face) * scale, scale)) * _t(-Vector2(turn.half)))
			texture = turn.tex
			white = turn.white
		else:
			# not turned yet (a few new turns per frame): drawn turned smoothly, as before
			if level > 0:
				texture = _dithered(d, level)
				if texture == null: continue
			canvas.draw_set_transform_matrix(_t(pos) * Transform2D(float(d.ang), Vector2.ZERO) * _s(Vector2(float(d.face) * scale, scale)) * _t(-Vector2(d.center)))
		canvas.draw_texture(texture, Vector2.ZERO, tint)
		if gone >= 0.0: continue
		if not look.is_empty(): _draw_look(canvas, d, look, turn)
		# Hell debris glows in its material's colour and cools down.
		var heat := 1.0 - clampf(float(d.life) / 1.5, 0.0, 1.0)
		var hot := palette(str(d.get("material", "")))
		if heat > 0.0 and not hot.is_empty() and white != null:
			canvas.draw_texture(white, Vector2.ZERO, Color(hot.glow, 0.6 * heat))
	canvas.draw_set_transform_matrix(Transform2D.IDENTITY)


## A debris piece turned on its own pixel grid, RotSprite-like: its layer's
## pixels (a small piece first doubled twice by Scale2x, so edges stay clean)
## sampled at its angle quantised to ragdoll.turn_steps, mirrored by its face
## when drawn; a ring in ragdoll.outline where its edge has no dark pixel of its
## own (a cut edge); `level` 1..3 drops pixels by the 4x4 dither. Cached by
## texture, step and level: {tex, white, half (image centre = piece centre),
## theta, c (piece centre, source px)}. {} without image or when this frame's
## ragdoll.turn_new new turns are used up.
func _turned(d: Dictionary, level: int) -> Dictionary:
	var layer: Dictionary = d.get("layer", {}) if d.get("layer") is Dictionary else {}
	var image: Variant = layer.get("image")
	if not image is Image or not d.get("texture") is Texture2D: return {}
	var steps := maxi(4, int(_rag("turn_steps")))
	var step := posmod(roundi(float(d.ang) * float(d.face) / TAU * float(steps)), steps)
	var key := "%d:%d:%d:%d" % [(d.texture as Texture2D).get_instance_id(), steps, step, level]
	if _turn_cache.has(key): return _turn_cache[key]
	if _turn_budget <= 0: return {}
	_turn_budget -= 1
	# a held item's bounds are its box in the figure (rig_library.gd _item_bounds): its own pixels count
	var box := Rect2((image as Image).get_used_rect()) if bool(layer.get("is_item", false)) else Rect2(layer.get("bounds", Rect2()))
	var up := _upscaled(d.texture as Texture2D, image as Image, box)
	if up.is_empty(): return {}
	var theta := TAU * float(step) / float(steps)
	# turned about a pixel corner, so unturned every pixel is sampled at its centre (the piece
	# shifts by under half a source px)
	var c := Vector2(d.center).round()
	var reach := 0.0
	for corner: Vector2 in [box.position, Vector2(box.end.x, box.position.y), box.end, Vector2(box.position.x, box.end.y)]: reach = maxf(reach, corner.distance_to(c))
	var half := ceili(reach) + 2
	var size := half * 2
	var px: PackedInt32Array = up.px
	var w: int = up.w
	var h: int = up.h
	var f := float(up.f)
	var origin: Vector2 = up.origin
	var cs := cos(-theta)
	var sn := sin(-theta)
	var body := PackedInt32Array()
	body.resize(size * size)
	for j in range(size):
		var qy := float(j) + 0.5 - float(half)
		for i in range(size):
			var qx := float(i) + 0.5 - float(half)
			var u := floori((c.x + qx * cs - qy * sn - origin.x) * f)
			var v := floori((c.y + qx * sn + qy * cs - origin.y) * f)
			if u < 0 or v < 0 or u >= w or v >= h: continue
			body[j * size + i] = px[v * w + u]
	# the white silhouette (hot hell debris glows through it), before the ring
	var white := PackedInt32Array()
	white.resize(size * size)
	for k in range(size * size):
		if body[k] != 0: white[k] = -1
	var ink := _rgba_int(_hex(_rag("outline"), INK))
	var shape := body.duplicate()
	for j in range(size):
		for i in range(size):
			if shape[j * size + i] != 0: continue
			for n: Vector2i in [Vector2i(i + 1, j), Vector2i(i - 1, j), Vector2i(i, j + 1), Vector2i(i, j - 1)]:
				if n.x < 0 or n.y < 0 or n.x >= size or n.y >= size: continue
				var col := shape[n.y * size + n.x]
				if col != 0 and not _dark_int(col):
					body[j * size + i] = ink
					break
	if level > 0:
		for j in range(size):
			for i in range(size):
				if BAYER[(j % 4) * 4 + i % 4] < level * 4:
					body[j * size + i] = 0
					white[j * size + i] = 0
	var out := {"tex": ImageTexture.create_from_image(Image.create_from_data(size, size, false, Image.FORMAT_RGBA8, body.to_byte_array())),
		"white": ImageTexture.create_from_image(Image.create_from_data(size, size, false, Image.FORMAT_RGBA8, white.to_byte_array())),
		"half": Vector2(half, half), "theta": theta, "c": c}
	if _turn_cache.size() > 2048: _turn_cache.clear()
	_turn_cache[key] = out
	return out


## A piece's pixels (its bounds and a 1 px margin) as RGBA8 ints (transparent
## = 0), doubled by Scale2x twice for a piece up to 24 px, once up to 48 px:
## {px, w, h, f (upscale), origin (source px of px[0])}. Cached by texture.
func _upscaled(texture: Texture2D, image: Image, bounds: Rect2) -> Dictionary:
	var key := texture.get_instance_id()
	if _up_cache.has(key): return _up_cache[key]
	var box := Rect2i(bounds).grow(1).intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	if box.size.x <= 0 or box.size.y <= 0: return {}
	var crop := image.get_region(box)
	crop.convert(Image.FORMAT_RGBA8)
	var px := crop.get_data().to_int32_array()
	for k in range(px.size()):
		if (px[k] >> 24) & 0xFF < 128: px[k] = 0
	var w := box.size.x
	var h := box.size.y
	var f := 1
	var big := maxi(w, h)
	for _round in range(2 if big <= 26 else 1 if big <= 50 else 0):
		px = _scale2x(px, w, h)
		w *= 2
		h *= 2
		f *= 2
	var out := {"px": px, "w": w, "h": h, "f": f, "origin": Vector2(box.position)}
	if _up_cache.size() > 512: _up_cache.clear()
	_up_cache[key] = out
	return out


## Scale2x (EPX) of a `w` x `h` RGBA8 int image: each pixel becomes four that
## follow the diagonal edges of its neighbours, so a turned piece keeps clean steps.
static func _scale2x(src: PackedInt32Array, w: int, h: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	out.resize(w * h * 4)
	var w2 := w * 2
	for y in range(h):
		for x in range(w):
			var p := src[y * w + x]
			var up := src[(y - 1) * w + x] if y > 0 else 0
			var right := src[y * w + x + 1] if x < w - 1 else 0
			var left := src[y * w + x - 1] if x > 0 else 0
			var down := src[(y + 1) * w + x] if y < h - 1 else 0
			var o := y * 2 * w2 + x * 2
			out[o] = up if left == up and left != down and up != right else p
			out[o + 1] = right if up == right and up != left and right != down else p
			out[o + w2] = left if down == left and down != right and left != up else p
			out[o + w2 + 1] = down if right == down and right != up and down != left else p
	return out


## A colour as an RGBA8 int (little-endian r, g, b, a: Image data read as int32).
static func _rgba_int(c: Color) -> int:
	var v := c.r8 | (c.g8 << 8) | (c.b8 << 16) | (c.a8 << 24)
	return v - 0x100000000 if v >= 0x80000000 else v


## True for an RGBA8 int dark enough to be an outline already (the sprite's own ink).
static func _dark_int(v: int) -> bool:
	return float(v & 0xFF) * 0.3 + float((v >> 8) & 0xFF) * 0.59 + float((v >> 16) & 0xFF) * 0.11 < 72.0


## Beams, particles and flashes are drawn over the actors (RigFx.draw_over):
## the beams posed this frame by draw_enemy whose snapshot enemy carries
## "beam" (and Rage's second "beam_b"), in the snapshot's order.
func draw_over(canvas: CanvasItem, snapshot: Dictionary) -> void:
	var beams_by_key: Dictionary = {}
	for beam: Dictionary in fx.beams: beams_by_key[beam.key] = beam
	var posed: Array = []
	var count := 0
	for enemy: Dictionary in snapshot.get("enemies", []):
		var key := _key(enemy)
		if beams_by_key.has(key) and enemy.get("beam") is Array:
			posed.append([beams_by_key[key], enemy.beam])
			count += 1
			# Rage: a second beam beside the first (the gap between them is safe).
			if enemy.get("beam_b") is Array: posed.append([beams_by_key[key], enemy.beam_b])
	fx.beams_drawn = count
	fx.draw_over(canvas, posed)


## Light sources from void effects for the dark crypt: [Vector3(x, y, radius)] (RigFx.lights).
func lights(snapshot: Dictionary) -> Array[Vector3]:
	return fx.lights(snapshot)
