extends RefCounted
## Companions as part rigs (user decision 2026-10-31): wolf, bear, falcon,
## water elemental, Pyro-Monster and bone warrior are drawn like the crypt's
## skeletons, every body part its own texture with its own HP
## (assets/data/companion_rigs.json, built by src/rig/rig_library.gd), posed
## here and put on the canvas through src/rig/rig_renderer.gd's draw_enemy
## path. The host (src/combat/talent_combat.gd) lands hits on the parts with
## src/combat/body_parts.gd and reports `rig`, `parts_lost`, `hits`, `wind`,
## `bite`, `cast` and `dying_p` in its pet snapshot; draw() turns one pet
## snapshot into the renderer's enemy dict (rig, lost parts, attack phase,
## hurt flash, death) and registers the companion pose families (beast, bird,
## elemental, demon) with the renderer. The bone warrior and the raised
## skeletons wear the skeleton family, the colossus the brute family.
## talent_fx.draw_pets calls draw() for every kind draws() accepts; the rest
## keep their frames. Tuning: assets/data/talents.json "pet" (kinds[kind].rig,
## .tempo, .portrait; "rig" {bite_s, cast_s, hurt_s, ...}).

const RigLibrary = preload("res://src/rig/rig_library.gd")
const RigRenderer = preload("res://src/rig/rig_renderer.gd")
const RigPoses = preload("res://src/rig/rig_poses.gd")
const TALENTS_PATH := "res://assets/data/talents.json"
## The pack's spirits: brightened to pale blue-white, like talent_fx draws them.
const SPIRIT_TINT := Color(1.45, 1.75, 2.1)
## Share of a bite's or cast's shown time that is the strike itself (the rest
## is the recovery): the renderer's attack windows run over it.
const STRIKE_SHARE := 0.3
## The renderer's hurt flash runs 0.16 s; a pet's hurt timer is mapped onto it.
const FLASH_TIME := 0.16
## A companion not drawn for this long is forgotten by the renderer.
const FORGET_AFTER := 2.0
## Ability types that read as a shout or burst (the "roar" clip), and as a
## cast from the hands (the "cast" clip); everything else is a strike.
const ROAR_TYPES := ["nova", "taunt"]
const CAST_TYPES := ["lance"]

static var _pet: Dictionary = {}
static var _pet_loaded := false
static var _portraits: Dictionary = {}
static var _tempos: Dictionary = {}

## The renderer used when the caller hands none (then stepped here too).
var renderer: RefCounted
var _registered: Dictionary = {}
var _seen: Dictionary = {}
var _last_clock := -1.0


func _init(rig_renderer: RefCounted = null) -> void:
	renderer = rig_renderer


# ---------------------------------------------------------------- static data

## talents.json "pet" (kinds, rig timings), read once; `path` for tests.
static func pet_config(path: String = TALENTS_PATH) -> Dictionary:
	if not _pet_loaded or path != TALENTS_PATH:
		_pet_loaded = true
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
		_pet = parsed.get("pet", {}) if parsed is Dictionary and parsed.get("pet") is Dictionary else {}
		_tempos.clear()
		_portraits.clear()
	return _pet


## The rig a companion kind wears (talents.json pet.kinds[kind].rig), "" for none.
static func rig_of(kind: String) -> String:
	return str(pet_config().get("kinds", {}).get(kind, {}).get("rig", ""))


## True when `kind` is drawn as a part rig here (it names a rig the library built).
static func draws(kind: String) -> bool:
	var name := rig_of(kind)
	return not name.is_empty() and not RigLibrary.shared().rig(name).is_empty()


## The companion's idle frame for the companion bar (talents.json
## pet.kinds[kind].portrait), null for an unknown kind or a missing file.
static func portrait(kind: String) -> Texture2D:
	if _portraits.has(kind): return _portraits[kind]
	var path := str(pet_config().get("kinds", {}).get(kind, {}).get("portrait", ""))
	var texture: Texture2D = null
	if not path.is_empty():
		if ResourceLoader.exists(path):
			texture = load(path)
		elif FileAccess.file_exists(path):
			# a generated frame the editor has not imported yet (the Pyro-Monster's)
			var image := Image.load_from_file(ProjectSettings.globalize_path(path))
			if image != null and not image.is_empty(): texture = ImageTexture.create_from_image(image)
	_portraits[kind] = texture
	return texture


## Pace of a rig's idle and walk (talents.json pet.kinds[kind].tempo of the
## kind wearing it; 1.0 when none does).
static func tempo_of(rig_name: String) -> float:
	if _tempos.is_empty():
		for kind: Variant in pet_config().get("kinds", {}):
			var info: Dictionary = pet_config().kinds[kind]
			if info.has("rig"): _tempos[str(info.rig)] = float(info.get("tempo", 1.0))
	return float(_tempos.get(rig_name, 1.0))


## The renderer clip a companion ability shows: "roar" for a shout or burst,
## "cast" for a lance, "bite" for a strike (talents.json pet.abilities[].type).
static func cast_kind(kind: String, slot: int) -> String:
	var cfg := pet_config()
	var names: Array = cfg.get("kinds", {}).get(kind, {}).get("abilities", [])
	if slot < 0 or slot >= names.size(): return "bite"
	var type := str(cfg.get("abilities", {}).get(str(names[slot]), {}).get("type", ""))
	if type in ROAR_TYPES: return "roar"
	if type in CAST_TYPES: return "cast"
	return "bite"


# ---------------------------------------------------------------- drawing

## Registers the companion pose families with `rig_renderer` (once per renderer).
func register(rig_renderer: RefCounted) -> void:
	if rig_renderer == null or _registered.has(rig_renderer.get_instance_id()): return
	_registered[rig_renderer.get_instance_id()] = true
	rig_renderer.register_family("beast", Callable(self, "beast"), Callable(self, "attacks"))
	rig_renderer.register_family("bird", Callable(self, "bird"), Callable(self, "attacks"))
	rig_renderer.register_family("elemental", Callable(self, "elemental"), Callable(self, "attacks"))
	rig_renderer.register_family("demon", Callable(self, "demon"), Callable(self, "attacks"))


## Draws one companion from its pet snapshot (talent_combat.snapshot().pets[])
## with its feet at `at`, facing `face` (+1 right), `art` world px per art
## pixel (talent_fx.art), through `rigs` (the view's RigRenderer, so its debris
## and clocks are shared; null: an own renderer, stepped by `clock`). Returns
## the screen y of the figure's top (for the life bar) or NAN when nothing was
## drawn (unknown rig, or the companion has crumbled).
func draw(canvas: CanvasItem, pet: Dictionary, at: Vector2, face: float, art: float, clock: float, rigs: RefCounted = null) -> float:
	var r := _renderer(rigs, clock)
	if r == null or not r.is_ready(): return NAN
	var kind := str(pet.get("kind", ""))
	var rig_name := str(pet.get("rig", ""))
	if rig_name.is_empty(): rig_name = rig_of(kind)
	var rig: Dictionary = r.library.rig(rig_name)
	if rig.is_empty(): return NAN
	var key := "p%d" % int(pet.get("id", 0))
	var enemy := snapshot_enemy(pet, rig_name, at, face, art, key)
	r.observe_one(enemy)
	var scale := float(rig.get("scale", RigLibrary.PIXEL_SCALE)) * float(enemy.size)
	# draw_enemy takes the body centre; the pet stands with its feet on `at`
	var point := at - Vector2(0.0, (float(rig.ground.y) - float(rig.center.y)) * scale)
	var top: float = r.draw_enemy(canvas, enemy, point)
	_seen[key] = clock
	for seen_key: String in _seen.keys():
		if clock - float(_seen[seen_key]) > FORGET_AFTER:
			r.forget(seen_key)
			_seen.erase(seen_key)
	return top


## The renderer's enemy dict of a pet snapshot: rig, lost parts, hit count,
## crumbling progress, size (art over the rigs' 2x), hurt flash, the pack's
## spirit tint, and the attack phase of a bite, a cast or a wind-up.
static func snapshot_enemy(pet: Dictionary, rig_name: String, at: Vector2, face: float, art: float, key: String) -> Dictionary:
	var cfg: Dictionary = pet_config().get("rig", {})
	var hurt_s := maxf(0.01, float(cfg.get("hurt_s", 0.2)))
	var enemy := {"actor_key": key, "uid": int(pet.get("id", 0)), "rig": rig_name, "x": at.x, "y": at.y, "face": face,
		"moving": bool(pet.get("moving", false)), "lost": pet.get("parts_lost", []), "hits": int(pet.get("hits", 0)),
		"dying_p": float(pet.get("dying_p", -1.0)), "size": art / RigLibrary.PIXEL_SCALE,
		"hit_flash": clampf(float(pet.get("hurt", 0.0)) / hurt_s, 0.0, 1.0) * FLASH_TIME,
		# raised skeletons rise out of the floor (the skeleton family's rise clip)
		"summoned": bool(pet.get("pack", false)) and str(pet.get("kind", "")) == "skeleton"}
	if bool(pet.get("pack", false)): enemy.tint = SPIRIT_TINT
	var bite := float(pet.get("bite", 0.0))
	var cast := float(pet.get("cast", 0.0))
	var wind := float(pet.get("wind", 0.0))
	if bite > 0.0:
		_phase(enemy, 1.0 - bite / maxf(0.01, float(cfg.get("bite_s", 0.25))), "bite")
	elif cast > 0.0:
		_phase(enemy, 1.0 - cast / maxf(0.01, float(cfg.get("cast_s", 0.45))), cast_kind(str(pet.get("kind", "")), int(pet.get("cast_slot", 0))))
	elif wind > 0.0:
		enemy.attack = "windup"
		enemy.attack_p = clampf(wind, 0.0, 1.0)
		enemy.attack_kind = "bite"
	return enemy


## A strike that already landed: its first STRIKE_SHARE is the active phase
## (the renderer runs the clip's strike window over it), the rest the recovery.
static func _phase(enemy: Dictionary, p: float, kind: String) -> void:
	p = clampf(p, 0.0, 1.0)
	enemy.attack_kind = kind
	if p < STRIKE_SHARE:
		enemy.attack = "active"
		enemy.attack_p = p / STRIKE_SHARE
	else:
		enemy.attack = "recover"
		enemy.attack_p = (p - STRIKE_SHARE) / (1.0 - STRIKE_SHARE)


## The renderer to draw with: the caller's, else an own one that this file
## steps itself (the view steps its own renderer).
func _renderer(rigs: RefCounted, clock: float) -> RefCounted:
	var r := rigs
	if r == null:
		if renderer == null: renderer = RigRenderer.new()
		r = renderer
		if _last_clock >= 0.0 and clock > _last_clock: r.step(clock - _last_clock)
		_last_clock = clock
	register(r)
	return r


# ---------------------------------------------------------------- poses

## [clip, end of windup, end of active] of a companion attack kind (the
## renderer's _attack_mapping asks): a shout or burst swells ("roar"), a lance
## is thrown ("cast"), everything else strikes ("attack").
func attacks(_rig: Dictionary, kind: String) -> Array:
	match kind:
		"roar": return ["roar", 0.4, 0.6]
		"cast": return ["cast", 0.45, 0.6]
	return ["attack", 0.45, 0.6]


static func _part(pose: Dictionary, id: String) -> Dictionary:
	return RigPoses.P(pose, id)


## Coil, snap and spring back of a strike over clip progress `u`:
## [coil 0..1, snap 0..1, keep 1..0] (keep fades the strike out).
static func _strike(u: float) -> Array:
	var coil := RigPoses.ease_in_out(RigPoses.seg(u, 0.0, 0.45))
	var snap := RigPoses.ease_out(RigPoses.seg(u, 0.45, 0.6))
	var back := RigPoses.ease_in_out(RigPoses.seg(u, 0.65, 1.0))
	return [coil, snap, 1.0 - back]


## A swell that rises fast and settles over clip progress `u` (roar, nova).
static func _swell(u: float) -> float:
	return RigPoses.ease_out(RigPoses.seg(u, 0.0, 0.4)) * (1.0 - RigPoses.ease_in_out(RigPoses.seg(u, 0.7, 1.0)))


## Beast (wolf "bite", bear "swipe"; parts head, body, paws, hind, wolf tail):
## breathes about the feet, the head bobs against it and the tail wags.
## Walking swings the leg pairs against each other about the hips with a body
## bob and lean; a lost pair tilts it, both lost put its belly on the floor.
## "attack": the wolf crouches, lunges and snaps its head down into the bite;
## the bear rears and slams a paw. "roar": the head goes up for the howl.
## "hit" knocks it back. The pace follows the kind's tempo (the bear slower).
func beast(rig: Dictionary, a: Dictionary) -> Dictionary:
	var pose := RigPoses.blank()
	var tempo := tempo_of(str(rig.get("name", "")))
	var t := float(a.get("t", 0.0)) * tempo
	var lost: Dictionary = a.get("lost", {})
	var by_id: Dictionary = rig.get("by_id", {})
	var has := func(id: String) -> bool: return by_id.has(id) and not lost.has(id)
	var breath := sin(t * TAU / 1.3)
	pose.whole.pivot = Vector2(rig.ground)
	pose.whole.sy = 1.0 + 0.03 * breath
	pose.whole.sx = 1.0 - 0.015 * breath
	var head := _part(pose, "head")
	head.dy = -0.6 * sin(t * TAU / 1.3 + 0.5)
	head.rot = 0.03 * sin(t * TAU / 2.9)
	var tail := _part(pose, "tail")
	tail.rot = 0.3 * sin(t * TAU / 0.7)
	var paws := _part(pose, "paws")
	var hind := _part(pose, "hind")
	var legs_lost := int(lost.has("paws")) + int(lost.has("hind"))
	if legs_lost == 2:
		pose.whole.dy = 3.0
	elif legs_lost == 1:
		pose.whole.rot = 0.14 if lost.has("paws") else -0.14
	if bool(a.get("moving", false)):
		var ph := t * TAU / 0.45
		paws.rot = 0.35 * sin(ph)
		hind.rot = -0.35 * sin(ph)
		pose.whole.dy += -absf(sin(ph)) * 1.2
		pose.whole.rot += 0.04 * sin(ph)
		head.dy -= 0.6 * absf(sin(ph))
		tail.rot = -0.25 + 0.3 * sin(ph)
	var u := float(a.get("u", 0.0))
	match str(a.get("clip", "")):
		"attack", "cast":
			var s := _strike(u)
			var coil: float = s[0]
			var snap: float = s[1]
			var keep: float = s[2]
			if str(rig.get("variant", "")) == "swipe":
				# the bear rears and brings a paw down
				paws.rot += (-1.1 * coil + 1.4 * snap) * keep
				pose.whole.dx += (-1.0 * coil + 3.0 * snap) * keep
				pose.whole.sy += 0.06 * coil * keep
				pose.whole.rot += (-0.1 * coil + 0.08 * snap) * keep
				head.rot += (-0.15 * coil + 0.2 * snap) * keep
			else:
				# the wolf crouches, lunges and snaps its jaws down
				pose.whole.dx += (-2.0 * coil + 5.0 * snap) * keep
				pose.whole.rot += (-0.08 * coil + 0.1 * snap) * keep
				head.rot += (-0.25 * coil + 0.35 * snap) * keep
				head.dx += (-1.0 * coil + 2.5 * snap) * keep
				head.dy += (1.0 * coil - 1.5 * snap) * keep
				hind.rot += -0.3 * coil * keep
		"roar":
			var k := _swell(u)
			head.rot -= 0.45 * k
			head.dy -= 2.0 * k
			pose.whole.sx += 0.05 * k
			pose.whole.sy += 0.04 * k
		"hit":
			var k := 1.0 - RigPoses.ease_out(u)
			pose.whole.dx += -2.5 * k
			pose.whole.rot -= 0.08 * k
			head.rot += 0.3 * sin(u * 30.0) * k
	if not has.call("tail"): pose.parts.erase("tail")
	return pose


## Bird (the falcon; parts body, wing_near, wing_far, tail): flies at the
## family's hover height with a slow bob; the wings beat about the shoulders
## (far wing a little behind the near one), slow and shallow gliding, fast and
## deep when it moves (which also leans it forward). A lost wing tips it and
## makes it flutter. "attack" is the dive: it rises with the wings up, stoops
## to just above the floor with the wings folded back, and climbs again.
## "hit" knocks it back with the wings flailing. It has no ground pose.
func bird(rig: Dictionary, a: Dictionary) -> Dictionary:
	var pose := RigPoses.blank()
	var t := float(a.get("t", 0.0))
	var lost: Dictionary = a.get("lost", {})
	var moving := bool(a.get("moving", false))
	var hover := float(rig.get("hover", 11.0))
	pose.whole.pivot = Vector2(rig.ground)
	pose.whole.dy = -hover - 1.5 * sin(t * TAU / 2.0)
	var period := 0.45 if moving else 1.6
	var amp := 0.55 if moving else 0.25
	var ph := t * TAU / period
	var near := _part(pose, "wing_near")
	var far := _part(pose, "wing_far")
	near.rot = amp * sin(ph)
	far.rot = -amp * 0.8 * sin(ph - 0.5)
	pose.whole.dy += -1.0 * sin(ph) * (0.6 if moving else 0.3)
	_part(pose, "tail").rot = 0.1 * sin(t * TAU / 1.1)
	if moving: pose.whole.rot = 0.08
	if lost.has("wing_near") != lost.has("wing_far"):
		pose.whole.rot += 0.35 if lost.has("wing_near") else -0.35
		pose.whole.dy += 2.0 * sin(t * TAU / 0.3)
	var u := float(a.get("u", 0.0))
	match str(a.get("clip", "")):
		"attack", "cast":
			var s := _strike(u)
			var coil: float = s[0]
			var snap: float = s[1]
			var keep: float = s[2]
			pose.whole.dy += -3.0 * coil * (1.0 - snap) * keep
			near.rot += 0.9 * coil * (1.0 - snap) * keep
			far.rot -= 0.7 * coil * (1.0 - snap) * keep
			# the stoop: down to just above the floor, nose first, wings folded back
			pose.whole.dy += hover * 0.85 * snap * keep
			pose.whole.dx += 4.0 * snap * keep
			pose.whole.rot += 0.5 * snap * keep
			near.rot += -0.9 * snap * keep
			far.rot += 0.7 * snap * keep
		"roar":
			var k := _swell(u)
			near.rot += 0.8 * k
			far.rot -= 0.6 * k
			pose.whole.dy -= 2.0 * k
		"hit":
			var k := 1.0 - RigPoses.ease_out(u)
			pose.whole.dx += -3.0 * k
			pose.whole.rot -= 0.2 * k
			near.rot += 0.5 * sin(u * 40.0) * k
	return pose


## Water elemental (parts core, shard_top, shard_r, shard_low, shard_l): the
## crystal floats at the family's hover height and breathes sideways; the four
## shards circle it on small ellipses a quarter turn apart, turning as they
## go, faster when it moves. "attack" and "cast" are the drip: the core
## stretches up, the lower shard sags and swells like a drop, then it lashes
## forward and the drop falls. "roar" (the nova) flings the shards out and
## swells the core. "hit" knocks it back with the shards jittering.
func elemental(rig: Dictionary, a: Dictionary) -> Dictionary:
	var pose := RigPoses.blank()
	var t := float(a.get("t", 0.0))
	var moving := bool(a.get("moving", false))
	pose.whole.pivot = Vector2(rig.ground)
	pose.whole.dy = -float(rig.get("hover", 3.0)) - 1.2 * sin(t * TAU / 1.8)
	var core := _part(pose, "core")
	core.sx = 1.0 + 0.03 * sin(t * TAU / 1.1)
	var w := TAU / (1.2 if moving else 2.4)
	var shards := ["shard_top", "shard_r", "shard_low", "shard_l"]
	for i in range(shards.size()):
		var s := _part(pose, shards[i])
		var angle := t * w + float(i) * TAU / 4.0
		s.dx = 1.5 * cos(angle)
		s.dy = 0.8 * sin(angle)
		s.rot = 0.4 * sin(angle)
	if moving: pose.whole.rot = 0.08
	var low := _part(pose, "shard_low")
	var u := float(a.get("u", 0.0))
	match str(a.get("clip", "")):
		"attack", "cast":
			var s := _strike(u)
			var coil: float = s[0]
			var snap: float = s[1]
			var keep: float = s[2]
			pose.whole.sy += (0.12 * coil - 0.1 * snap) * keep
			pose.whole.sx += (-0.06 * coil + 0.1 * snap) * keep
			low.dy += (3.0 * coil + 2.0 * snap) * keep
			low.sy += 0.3 * coil * keep
			pose.whole.dx += 2.5 * snap * keep
		"roar":
			var k := _swell(u)
			_part(pose, "shard_top").dy -= 4.0 * k
			low.dy += 4.0 * k
			_part(pose, "shard_l").dx -= 4.0 * k
			_part(pose, "shard_r").dx += 4.0 * k
			pose.whole.sx += 0.12 * k
			pose.whole.sy += 0.06 * k
		"hit":
			var k := 1.0 - RigPoses.ease_out(u)
			pose.whole.dx += -2.0 * k
			for id: String in shards: _part(pose, id).dx += 1.5 * sin(u * 35.0 + float(id.hash() % 7)) * k
	return pose


## Demon (the Pyro-Monster; parts horns, head, torso, arm_l, arm_r, leg_l,
## leg_r): the torso breathes about the feet, the head bobs against it (the
## horns ride along), the arms sway. Walking swings the legs about the hips
## and the arms against them with a bob. Both legs lost sit it down, one
## tilts it. "attack" is the ember fist: the right arm draws back, the body
## coils, then the fist punches forward with a lunge. "roar" (the fire ring)
## throws both arms up and swells the body. "hit" knocks it back.
func demon(_rig: Dictionary, a: Dictionary) -> Dictionary:
	var pose := RigPoses.blank()
	var t := float(a.get("t", 0.0))
	var lost: Dictionary = a.get("lost", {})
	var breath := TAU / 1.5
	var torso := _part(pose, "torso")
	torso.sy = 1.0 + 0.03 * sin(t * breath)
	var head := _part(pose, "head")
	head.dy = -0.6 * sin(t * breath - 0.4)
	var arm_l := _part(pose, "arm_l")
	var arm_r := _part(pose, "arm_r")
	arm_l.rot = 0.1 * sin(t * breath + 0.4)
	arm_r.rot = -0.1 * sin(t * breath + 0.9)
	var legs_lost := int(lost.has("leg_l")) + int(lost.has("leg_r"))
	if legs_lost == 2:
		pose.whole.dy = 4.0
	elif legs_lost == 1:
		pose.whole.rot = 0.15 if lost.has("leg_l") else -0.15
	if bool(a.get("moving", false)):
		var ph := t * TAU / 0.6
		var leg_l := _part(pose, "leg_l")
		var leg_r := _part(pose, "leg_r")
		leg_l.dx = sin(ph) * 1.5
		leg_l.dy = -maxf(0.0, cos(ph)) * 1.3
		leg_r.dx = -sin(ph) * 1.5
		leg_r.dy = -maxf(0.0, -cos(ph)) * 1.3
		pose.whole.dy += -absf(sin(ph)) * 1.4
		pose.whole.rot += 0.05 * sin(ph)
		arm_l.rot += 0.35 * sin(ph)
		arm_r.rot -= 0.35 * sin(ph)
		head.dy -= 0.5 * absf(sin(ph))
	var u := float(a.get("u", 0.0))
	match str(a.get("clip", "")):
		"attack", "cast":
			var s := _strike(u)
			var coil: float = s[0]
			var snap: float = s[1]
			var keep: float = s[2]
			# the hand hangs below the shoulder: a positive turn draws it back, a negative one punches
			arm_r.rot += (1.4 * coil - 2.2 * snap) * keep
			pose.whole.dx += (-1.5 * coil + 4.0 * snap) * keep
			pose.whole.rot += (-0.06 * coil + 0.1 * snap) * keep
			head.rot += (-0.1 * coil + 0.15 * snap) * keep
			torso.rot += (-0.05 * coil + 0.06 * snap) * keep
		"roar":
			var k := _swell(u)
			arm_l.rot += 2.2 * k
			arm_r.rot -= 2.2 * k
			pose.whole.sx += 0.08 * k
			pose.whole.sy += 0.06 * k
			head.dy -= 1.5 * k
			head.rot -= 0.2 * k
		"hit":
			var k := 1.0 - RigPoses.ease_out(u)
			pose.whole.dx += -2.0 * k
			head.rot -= 0.15 * k
			arm_l.rot += 0.4 * sin(u * 30.0) * k
			arm_r.rot -= 0.4 * sin(u * 30.0) * k
	return pose
