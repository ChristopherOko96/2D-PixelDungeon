extends RefCounted
## Ignaroth's part rig on the hell game's side (docs/HOELLE-RIGS.de.md): the
## crypt's body parts (src/combat/body_parts.gd) and part rigs
## (src/rig/rig_renderer.gd) for a hell monster dict `m` as
## src/hell/hell_monsters.gd spawn() builds it. One module, no node, no
## singleton: the game hands in the monster dicts and draws through it.
## - attach: HP per part of the form's rig (assets/data/hell_rigs.json, rig
##   name = m.id), an int m.uid for the rig's keys, m.pos = body centre;
##   every new form starts complete (on_form_changed), Ignaroth regrows
##   nothing, other hell bosses later regrow after `regrow` s.
## - hits: shots are tested as a swept segment, the sword as its arc, blasts
##   as their radius, all against the pose last drawn (RigRenderer
##   part_transforms; the rest pose while he was not drawn; nothing below the
##   floor while he sinks). A hit on the tail beyond tail_2 counts on tail_2
##   (BodyParts.carrier), one on the throat outside the breath on the body,
##   one without an impact point (burns, zones) on the body. Every hit counts
##   fully against the HP bar (PART-05).
## - attacks: prepare() at the start returns a weakened COPY of the attack
##   (or {} while it is impossible or he staggers), cancels() at every tick of
##   the act drops an attack when any part fell in its windup (PART-01) and a
##   channelled one whose part fell later, echo_forms() picks the echoes,
##   flights are capped and followed by a time on the ground (BOSS-04).
## - a severed part raises EVENT_SEVER (hitstop, flash, debris material,
##   wound colours, its own sound) and a stagger without a new attack
##   (PART-02/03); hold()/frozen()/freeze() keep the hitstop without the feel.
## - draw: through RigRenderer with tint/alpha, size, flight altitude (the
##   foot), the burrow's sink cut, the death; the glow record goes to
##   glow_mark (src/hero/story_glow.gd mark()), never into the monster dict.
## Tuning comes from hell_balance.json monsters.rigs, deep-merged over
## DEFAULTS (every key optional, nested tables key by key).

const BodyParts = preload("res://src/combat/body_parts.gd")
const RigLibrary = preload("res://src/rig/rig_library.gd")
const RigRenderer = preload("res://src/rig/rig_renderer.gd")

## A part was cut off. Payload: see _sever().
const EVENT_SEVER := "rig_sever"
## A running attack was dropped: a part fell in its windup, or the part of a
## channelled attack fell while it ran. Payload: uid, monster, action, kind,
## part (the cut), released, at.
const EVENT_CANCEL := "rig_cancel"
## A lost part grew back (bosses with regrow; never Ignaroth).
const EVENT_REGROW := "rig_regrow"

## [windup, active, recover] s of each hell act kind, as hell_monsters.gd
## times them (release at the end of the windup). They map the act onto the
## rig's attack clip; the attack's own duration, waves or range replace the
## active time where it has one (_times). Default of DEFAULTS.act_times.
const ACT_TIMES := {
	"bolt": [0.35, 0.12, 0.18], "breath": [0.3, 0.12, 0.18], "homing": [0.35, 0.12, 0.18],
	"dash": [0.5, 0.45, 0.05], "slam": [0.75, 0.15, 0.15], "swing": [0.35, 0.2, 0.05],
	"ring": [0.45, 0.35, 0.1], "burrow": [0.55, 0.3, 0.4], "flight": [0.7, 4.0, 0.7],
	"sweep": [0.45, 1.7, 0.1], "echoes": [0.8, 0.2, 0.4], "beam": [0.8, 3.6, 0.1],
	"lob": [0.45, 0.1, 0.15], "spiral": [0.4, 2.0, 0.1], "summon": [0.6, 0.1, 0.2],
	"meteors": [0.5, 0.1, 0.2], "hands": [0.5, 0.1, 0.2], "chain": [0.35, 0.1, 0.25],
	"scream": [0.1, 0.6, 0.3], "teleport": [0.35, 0.1, 0.25],
}
## Fallbacks for hell_balance.json monsters.rigs: seconds unless noted.
## stagger: no new attack after a sever (PART-03); hitstop, flash: the
## picture holds, the figure flashes white; shake: screen shake px; minor:
## the same four for a cut on a monster that is not the boss (an echo), so
## three echoes under multishot do not chain hitstops; own_break_sound: the
## cut sounds its own `sound` (the game plays the first of `sounds` that
## exists) and BodyParts' part_breaks count moves to m.rig_breaks, so
## feedback.gd's generic break_<crypt material> stays silent for these rigs;
## break_sounds: {material: sound names, own first, then an audio_sfx.json
## event that exists today}; regrow: {rig family: s} (0 = never; "default"
## for the rest); unaimed: where a hit without an impact point lands ("body":
## the rig's root, "random": BodyParts' seeded pick); flight_max: longest
## flight (BOSS-04), measured on flight_basis "air" (all the time he is out
## of reach, rise and landing above immune_altitude included), "total"
## (take-off to touch-down) or "circle" (the attack's own duration over the
## arena); ground_min: time on the ground after a landing before he may rise
## or burrow again; flight_rise/flight_land: hell_monsters.gd's rise and
## landing; immune_kinds: acts that take him out of reach; channel_kinds:
## acts a lost part still stops after their release; count_params: weakened
## params that are counts (rounded, min 1); muzzles: {act kind: rig point the
## act starts from ("default" for the rest)}; death_start, death_end: when
## the form-4 death starts shedding parts and when the monster is removed
## (hell_monsters.gd _update_lord_end); corpse_time: the corpse's life
## (hell_monsters.gd); foot_drop: world px the feet are drawn below m.p
## (hell_monsters.gd _draw_lord); act_times: see ACT_TIMES.
const DEFAULTS := {
	"stagger": 1.0, "hitstop": 0.09, "flash": 0.16, "shake": 6.0,
	"minor": {"stagger": 1.0, "hitstop": 0.0, "flash": 0.16, "shake": 2.0},
	"own_break_sound": true,
	"break_sounds": {"ember": ["break_ember", "break_flesh"], "obsidian": ["break_obsidian", "break_void"]},
	"regrow": {"drake": 0.0, "default": 12.0},
	"unaimed": "body",
	"flight_max": 4.6, "flight_basis": "air", "ground_min": 2.0, "flight_rise": 0.7, "flight_land": 0.7,
	"immune_kinds": ["flight", "burrow"], "channel_kinds": ["sweep", "beam"],
	"count_params": ["count", "ring", "beams", "forms", "heads", "waves", "arms"],
	"muzzles": {"bolt": "mouth", "breath": "mouth", "homing": "mouth", "lob": "mouth", "sweep": "mouth", "default": "core"},
	"death_start": 2.6, "death_end": 2.8, "corpse_time": 0.75, "foot_drop": 4.0,
	"act_times": ACT_TIMES,
}
## Search radius of a melee hit's nearest part in world px (like RigLibrary).
const MELEE_REACH := 48.0
## A melee point within this many world px of a part's pixels is on it (the frontmost such part wins).
const MELEE_TOUCH := 2.0
## World px between two samples of a sword's arc (about one source px at scale 5).
const SWING_STEP := 5.0
## Source px a fully sunk figure lies below the floor beyond its own height.
const SINK_MARGIN := 2.0

## The rig data (src/rig/rig_library.gd): parts, images, points, groups.
var library: RigLibrary
## Host-side body parts (src/combat/body_parts.gd): HP per part, cuts, gating, weakening.
var parts: BodyParts
## The rig view or null: without it hits use the rest pose and nothing is drawn.
var renderer: RigRenderer
## Effective tuning (DEFAULTS deep-merged with monsters.rigs).
var cfg: Dictionary = {}
## Flight altitude and the altitude above which he cannot be hit (hell_balance.json monsters).
var flight_altitude := 320.0
var immune_altitude := 30.0
## Glow hook, called as glow_mark.call(body, record) for every figure drawn
## here (hell_game.gd sets it to story_glow.mark). record: {foot, size, src,
## face, lean, cut, alpha} as hell_monsters.gd _mark() gives it (the atlas
## frame, so vfx_glow.json's `at` anchors keep their meaning), plus rig and
## points {mouth, throat, hand, tail_tip, core: world px where this pose put
## them, INF while sunk}. Unset: no glow.
var glow_mark: Callable = Callable()
## Counts frame() calls: a pose drawn in this or the last frame is current.
var frame_index := 0
## Seconds the picture still holds after a cut (hold(); the game's hitstop without the feel).
var hitstop_left := 0.0
var _events: Array[Dictionary] = []
var _next_uid := 1
var _snapshot: Dictionary = {"enemies": []}
## uid -> parts lost when last seen (a corpse keeps its wounds).
var _last_lost: Dictionary = {}
## uid -> the glow record of its last draw (point() reads its rig points).
var _records: Dictionary = {}
## uid -> atlas frame size of the form last drawn alive (the corpse's glow box).
var _atlas: Dictionary = {}


## monster_cfg: hell_balance.json "monsters" (flight_altitude, immune_altitude
## and the optional "rigs" block). The game passes its rig library; the body
## parts and view default to a BodyParts and a RigRenderer on it (the
## library to RigLibrary.shared() when none is given); with_view = false
## makes a host without drawing (rest-pose hits).
func _init(monster_cfg: Dictionary = {}, rig_library: RigLibrary = null, body_parts: BodyParts = null, rig_renderer: RigRenderer = null, with_view := true) -> void:
	if rig_library != null: library = rig_library
	else: library = RigLibrary.shared()
	if body_parts != null: parts = body_parts
	else: parts = BodyParts.new(library)
	if rig_renderer != null: renderer = rig_renderer
	elif with_view: renderer = RigRenderer.new(library)
	var own: Variant = monster_cfg.get("rigs", {})
	cfg = merged(DEFAULTS, own if own is Dictionary else {})
	flight_altitude = float(monster_cfg.get("flight_altitude", flight_altitude))
	immune_altitude = float(monster_cfg.get("immune_altitude", immune_altitude))


## `base` with `over` laid on it key by key: nested dictionaries merge (a
## partial {"regrow": {"default": 10}} keeps "drake"), everything else is
## replaced. Neither argument changes.
static func merged(base: Dictionary, over: Dictionary) -> Dictionary:
	var out: Dictionary = base.duplicate(true)
	for key: Variant in over:
		var value: Variant = over[key]
		if out.get(key) is Dictionary and value is Dictionary: out[key] = merged(out[key], value)
		elif value is Dictionary or value is Array: out[key] = value.duplicate(true)
		else: out[key] = value
	return out


## A new floor or run: no events, effects, wounds or held picture linger;
## seeds BodyParts' pick for hits without an impact point ("unaimed": "random").
func reset(seed_value: int = 0) -> void:
	_events.clear()
	_last_lost.clear()
	_records.clear()
	_atlas.clear()
	_snapshot = {"enemies": []}
	hitstop_left = 0.0
	parts.reset(seed_value)
	if renderer != null: renderer.reset()


# ------------------------------------------------------------------ parts

## The layered rig monster `m` (or a corpse) is drawn with: its id when
## hell_rigs.json has that rig, else "".
func rig_of(m: Dictionary) -> String:
	var name := str(m.get("id", ""))
	if name.is_empty(): return ""
	var rig: Dictionary = library.rig(name)
	# a layered hell rig (hell_rigs.json) or a crypt rig named like the monster (rigs.json "brandskelett")
	return name if not rig.is_empty() else ""


## True once `m` carries body parts of its rig.
func has_rig(m: Dictionary) -> bool:
	return parts.has_parts(m) and not rig_of(m).is_empty()


## Gives `m` the body parts of its form's rig: the HP (m.max) split by the
## part weights, every part attached, an int m.uid when it has none, its
## regrow delay (Ignaroth: none), no stagger, lock or pending hit, and m.pos =
## body centre. Keeps m.hp. False when its form has no rig (the atlas sprite stays).
func attach(m: Dictionary) -> bool:
	var name := rig_of(m)
	if name.is_empty(): return false
	if not m.has("uid"):
		m.uid = _next_uid
		_next_uid += 1
	var hp := float(m.get("hp", m.get("max", 0.0)))
	m.max_hp = float(m.get("max", hp))
	parts.attach(m, name)
	m.hp = hp
	var rig: Dictionary = library.rig(name)
	var regrow: Dictionary = cfg.regrow if cfg.regrow is Dictionary else {}
	m.regrow_after = float(regrow.get(str(rig.get("family", "")), regrow.get("default", 0.0)))
	m.rig_stagger = 0.0
	m.rig_flash = 0.0
	m.rig_ground = 0.0
	m.rig_flying = false
	m.rig_hits = int(m.get("rig_hits", 0))
	m.rig_hit_part = ""
	m.exposed_action = ""
	m.erase("rig_pending")
	m.erase("rig_pending_frame")
	m.pos = centre(m)
	return true


## hell_monsters.gd _set_form swapped `m` to its next form: the new form's
## rig, complete, with the same uid and HP; no stagger, lock or pending hit
## carries over.
func on_form_changed(m: Dictionary) -> void:
	if rig_of(m).is_empty():
		for key: String in ["parts", "parts_lost", "regrow", "rig"]: m.erase(key)
		return
	attach(m)


## Once per game update after the monsters moved (not during a hitstop):
## timers (stagger, flash, ground lock), a landing starting the ground lock,
## the throat closing after the breath, regrowth, the view's clock and what
## it shows (lost parts fall as debris, a new form starts complete).
## `corpses` are hell_monsters.gd's (a dead form's body, with its uid).
func frame(mobs: Array, corpses: Array = [], dt: float = 0.0) -> void:
	frame_index += 1
	for m: Variant in mobs:
		if m is Dictionary and not rig_of(m).is_empty(): _step(m, dt)
	if renderer == null: return
	renderer.step(dt)
	_snapshot = _view_snapshot(mobs, corpses)
	renderer.observe(_snapshot)


## Events since the last call (EVENT_SEVER, EVENT_CANCEL, EVENT_REGROW), oldest first.
func take_events() -> Array[Dictionary]:
	var out := _events.duplicate()
	_events.clear()
	return out


## True while `m` reels from a severed part: no new attack starts.
func staggered(m: Dictionary) -> bool:
	return float(m.get("rig_stagger", 0.0)) > 0.0


## Holds the picture for at least `seconds` (a cut's hitstop when no feel
## holds it: hell_game.gd _process asks frozen() and calls freeze()).
func hold(seconds: float) -> void:
	hitstop_left = maxf(hitstop_left, seconds)


## True while a cut holds the picture (hold()).
func frozen() -> bool:
	return hitstop_left > 0.0


## One frame of the hold: only the hold runs down.
func freeze(dt: float) -> void:
	hitstop_left = maxf(0.0, hitstop_left - dt)


# ---------------------------------------------------------------- attacks

## The attack `a` (a dict of m.st.attacks, shared with every monster of its
## kind: never changed here) as it starts now: `a` itself without a rig; {}
## while he staggers, a lost part or group disables it (BodyParts.can) or a
## flight or burrow would follow a landing too soon (BOSS-04); else a deep
## copy with every weakened parameter scaled (counts rounded, min 1; a flag
## turned off by a factor 0) and a flight capped at max_flight(). The copy
## carries rig_prepared, rig_base {param: unweakened value} and rig_lost (the
## parts already gone at its start: cancels() drops it on any later cut in
## its windup).
func prepare(m: Dictionary, a: Dictionary) -> Dictionary:
	if not has_rig(m): return a
	if staggered(m): return {}
	var action := str(a.get("id", ""))
	if not parts.can(m, action): return {}
	if str(a.get("kind", "")) in cfg.immune_kinds and float(m.get("rig_ground", 0.0)) > 0.0: return {}
	var copy: Dictionary = a.duplicate(true)
	var base: Dictionary = {}
	var weakened: Dictionary = parts.weakened(m, action)
	for param: String in weakened:
		if not copy.has(param): continue
		var value: Variant = copy[param]
		var factor := float(weakened[param])
		base[param] = value
		if value is bool: copy[param] = bool(value) and factor > 0.0
		elif param in cfg.count_params: copy[param] = maxi(1, roundi(float(value) * factor))
		else: copy[param] = float(value) * factor
	if str(copy.get("kind", "")) == "flight" and copy.has("duration"):
		base.duration = base.get("duration", copy.duration)
		copy.duration = minf(float(copy.duration), max_flight())
	copy.rig_prepared = true
	copy.rig_base = base
	copy.rig_lost = Array(m.parts_lost).duplicate()
	return copy


## Every tick of a running act, before it runs (hell_monsters.gd _run_act):
## true when it must stop now. Before its release any part severed since the
## attack started stops it (PART-01: he reels, the windup breaks off); after
## the release only a channelled act (the breath, the beams) stops, when the
## part (or group) carrying it is gone. An act that already took him out of
## reach is never stopped; one that was rising or sinking is put back on the
## ground. Lost crystals take their beams out of a running beam. Raises
## EVENT_CANCEL. An act whose attack did not come from prepare() falls back
## to the carrier check alone.
func cancels(m: Dictionary) -> bool:
	if not has_rig(m) or not m.get("act") is Dictionary: return false
	var act: Dictionary = m.act
	var a: Dictionary = act.get("a", {})
	var action := str(a.get("id", ""))
	var kind := str(act.get("kind", ""))
	var out := _released(act)
	var gone := not parts.can(m, action)
	var cut := "" if out else _cut_since(m, a)
	var channelled: bool = kind in cfg.channel_kinds
	var stop: bool = (gone and (not out or channelled)) or not cut.is_empty()
	if stop:
		if kind in cfg.immune_kinds:
			if float(m.get("alt", 0.0)) > immune_altitude or bool(m.get("burrowed", false)): return false
			m.alt = 0.0
			m.sink = 0.0
		m.exposed_action = ""
		_events.append({"name": EVENT_CANCEL, "uid": int(m.uid), "monster": str(m.id), "action": action, "kind": kind,
			"part": cut if not cut.is_empty() else _disabling_part(m, action), "released": out, "at": point(m, "core", centre(m))})
		return true
	if act.get("beams") is Array:
		var beams: Array = act.beams
		var total := float(a.get("rig_base", {}).get("beams", a.get("beams", beams.size())))
		var keep := maxi(1, roundi(total * parts.scale(m, action, "beams")))
		if beams.size() > keep: beams.resize(keep)
	return false


## Sound hook of hell_monsters.gd (_released): the running act releases now.
## From here until it ends its action is the exposed one (the throat opens
## for the breath, BodyParts exposed parts). Monsters without a rig are left alone.
func on_release(m: Dictionary) -> void:
	if not has_rig(m) or not m.get("act") is Dictionary: return
	var act: Dictionary = m.act
	act.rig_out = true
	act.rig_out_t = float(act.get("t", 0.0))
	m.exposed_action = str(act.get("a", {}).get("id", ""))


## The earlier forms the echo attack `a` calls up: the first
## round(forms x the horns' factor) of `earlier` (3 -> 1 without horns,
## none while the attack is disabled); `earlier` unchanged without a rig.
func echo_forms(m: Dictionary, a: Dictionary, earlier: Array) -> Array:
	if not has_rig(m): return earlier
	var action := str(a.get("id", "echos"))
	if not parts.can(m, action): return []
	var total := float(a.get("rig_base", {}).get("forms", a.get("forms", earlier.size())))
	var count := clampi(roundi(total * parts.scale(m, action, "forms")), 0, earlier.size())
	return earlier.slice(0, count)


## The longest flight duration (the attack's circling over the arena) BOSS-04
## allows: flight_max less what the rise and the landing spend out of reach
## ("air"), less the whole rise and landing ("total"), or flight_max itself
## ("circle").
func max_flight() -> float:
	var limit := float(cfg.flight_max)
	var rise := float(cfg.flight_rise)
	var land := float(cfg.flight_land)
	match str(cfg.flight_basis):
		"air": return maxf(0.0, limit - air_time(0.0, flight_altitude, immune_altitude, rise, land))
		"total": return maxf(0.0, limit - rise - land)
	return limit


## Seconds a flight of `duration` keeps him out of reach (altitude above
## `immune`) when he rises to `top` over `rise` s and lands over `land` s on
## hell_monsters.gd's smoothstep curves.
static func air_time(duration: float, top: float, immune: float, rise: float, land: float) -> float:
	if top <= immune: return 0.0
	# smoothstep reaches immune/top at k; the landing mirrors the rise
	var share := clampf(immune / top, 0.0, 1.0)
	var lo := 0.0
	var hi := 1.0
	for _i in range(40):
		var k := (lo + hi) * 0.5
		if k * k * (3.0 - 2.0 * k) < share: lo = k
		else: hi = k
	return duration + (rise + land) * (1.0 - lo)


## The running act's phase for the rig's attack clip: {attack: "windup",
## "active", "recover" or "", attack_kind, attack_p 0..1}.
func act_phase(m: Dictionary) -> Dictionary:
	var act: Variant = m.get("act")
	if not act is Dictionary: return {"attack": "", "attack_kind": "", "attack_p": 0.0}
	var kind := str(act.get("kind", ""))
	var times := _times(act)
	var t := float(act.get("t", 0.0))
	if not _released(act) or t < float(act.get("rig_out_t", 0.0)):
		return {"attack": "windup", "attack_kind": kind, "attack_p": clampf(t / maxf(0.01, times.x), 0.0, 1.0)}
	var since := t - float(act.get("rig_out_t", times.x))
	if since < times.y: return {"attack": "active", "attack_kind": kind, "attack_p": clampf(since / maxf(0.01, times.y), 0.0, 1.0)}
	return {"attack": "recover", "attack_kind": kind, "attack_p": clampf((since - times.y) / maxf(0.01, times.z), 0.0, 1.0)}


# ------------------------------------------------------------------- hits

## The part a projectile flying from `from` to `to` (world px, `radius` world
## px) hits, or "" for a miss; routed (tail tip -> tail_2, a closed throat ->
## body). Tested against the pose last drawn, else the rest pose; while he
## sinks nothing below the floor line is hit.
func shot_part(m: Dictionary, from: Vector2, to: Vector2, radius: float) -> String:
	if not has_rig(m): return ""
	var candidates := _candidates(m)
	if candidates.is_empty(): return ""
	var box := _reach_box(candidates).grow(radius)
	if not box.intersects(Rect2(from, Vector2.ZERO).expand(to).grow(0.5)): return ""
	var floor_y := _floor_y(m)
	var steps := maxi(1, int(ceil(from.distance_to(to) / 2.0)))
	for step in range(steps + 1):
		var p := from.lerp(to, float(step) / float(steps))
		if p.y > floor_y: continue
		for c: Dictionary in candidates:
			if _touches(c, p, radius, floor_y): return _route(m, str(c.id))
	return ""


## shot_part, and on a hit it becomes the part the next damage() of this
## frame lands on. True on a hit (the game's shot test for a rigged drake).
func shot_hits(m: Dictionary, from: Vector2, to: Vector2, radius: float) -> bool:
	var part := shot_part(m, from, to, radius)
	if part.is_empty(): return false
	aim(m, part)
	return true


## The part a sword swung from `from` along `dir` (an arc of +-`half_arc`
## rad, `reach` world px) meets first: the blade is sampled from the hilt
## outward across the arc against the drawn parts (the frontmost part at the
## first sample that touches one), routed; "" when the blade misses him.
## Replaces the old `reach + m.r` test for rigged dragons, so wings, horns
## and tail are hit where they are drawn.
func swing_part(m: Dictionary, from: Vector2, dir: Vector2, reach: float, half_arc: float) -> String:
	if not has_rig(m) or reach <= 0.0: return ""
	var candidates := _candidates(m)
	if candidates.is_empty(): return ""
	var box := _reach_box(candidates).grow(MELEE_TOUCH)
	if from.distance_to(from.clamp(box.position, box.end)) > reach: return ""
	var floor_y := _floor_y(m)
	var base := dir.angle()
	var rings := maxi(1, int(ceil(reach / SWING_STEP)))
	for i in range(1, rings + 1):
		var distance := reach * float(i) / float(rings)
		var spokes := maxi(1, int(ceil(2.0 * half_arc * distance / SWING_STEP)))
		for j in range(spokes + 1):
			var p := from + Vector2.from_angle(base - half_arc + 2.0 * half_arc * float(j) / float(spokes)) * distance
			if p.y > floor_y or not box.has_point(p): continue
			for c: Dictionary in candidates:
				if _touches(c, p, MELEE_TOUCH, floor_y): return _route(m, str(c.id))
	return ""


## swing_part, and on a hit it becomes the next damage's part. True when the
## blade meets him (the game's sword test for a rigged drake).
func swing_hits(m: Dictionary, from: Vector2, dir: Vector2, reach: float, half_arc: float) -> bool:
	var part := swing_part(m, from, dir, reach, half_arc)
	if part.is_empty(): return false
	aim(m, part)
	return true


## The part a blast at `center` with `radius` world px reaches: the frontmost
## part at the centre, else the one with the nearest pixel within the radius,
## routed; "" when no drawn pixel is that close.
func blast_part(m: Dictionary, center: Vector2, radius: float) -> String:
	if not has_rig(m): return ""
	var candidates := _candidates(m)
	if candidates.is_empty() or not _reach_box(candidates).grow(radius).has_point(center): return ""
	var floor_y := _floor_y(m)
	for c: Dictionary in candidates:
		if _touches(c, center, MELEE_TOUCH, floor_y): return _route(m, str(c.id))
	var best := ""
	var best_distance := INF
	for c: Dictionary in candidates:
		var distance := _pixel_distance(c, center, radius, floor_y)
		if distance < best_distance - 0.01:
			best = str(c.id)
			best_distance = distance
	return _route(m, best)


## blast_part, and on a hit it becomes the next damage's part. True when the
## blast reaches him (the game's explosion test for a rigged drake).
func blast_hits(m: Dictionary, center: Vector2, radius: float) -> bool:
	var part := blast_part(m, center, radius)
	if part.is_empty(): return false
	aim(m, part)
	return true


## The living part at a world point (the frontmost one there), else the
## nearest one, routed; "" without a rig.
func melee_part(m: Dictionary, point: Vector2) -> String:
	if not has_rig(m): return ""
	var candidates := _candidates(m)
	var floor_y := _floor_y(m)
	for c: Dictionary in candidates:
		if _touches(c, point, MELEE_TOUCH, floor_y): return _route(m, str(c.id))
	var best := ""
	var best_distance := INF
	var best_z := -999
	for c: Dictionary in candidates:
		var distance := _pixel_distance(c, point, MELEE_REACH, floor_y)
		if distance < best_distance - 0.01 or (distance < best_distance + 0.01 and is_finite(distance) and int(c.z) > best_z):
			best = str(c.id)
			best_distance = distance
			best_z = int(c.z)
	if best.is_empty():
		# out of reach of every pixel: the part whose box is nearest
		for c: Dictionary in candidates:
			var local: Vector2 = Transform2D(c.inv) * point
			var area: Rect2 = c.part.bounds
			var distance := local.distance_to(local.clamp(area.position, area.end)) * float(c.scale)
			if distance < best_distance:
				best = str(c.id)
				best_distance = distance
	return _route(m, best)


## A thrust from `from` along `dir` (reach world px): the part nearest to
## where it meets him becomes the next damage's part.
func aim_melee(m: Dictionary, from: Vector2, dir: Vector2, reach: float) -> String:
	if not has_rig(m): return ""
	var along := dir.normalized() * minf(from.distance_to(centre(m)), reach)
	var part := melee_part(m, from + along)
	aim(m, part)
	return part


## The part nearest to a world point (a zone, a burst) becomes the next damage's part.
func aim_at(m: Dictionary, point: Vector2) -> String:
	var part := melee_part(m, point)
	aim(m, part)
	return part


## The part the next damage() of `m` in this frame lands on.
func aim(m: Dictionary, part: String) -> void:
	if part.is_empty(): return
	m.rig_pending = part
	m.rig_pending_frame = frame_index


## Takes the part aimed at `m` in this frame out of it ("" when none):
## hell_game.gd _damage_mob calls it first, so a hit it refuses (immune,
## shield) leaves no aim behind for the next damage.
func take_aim(m: Dictionary) -> String:
	var part := str(m.get("rig_pending", "")) if int(m.get("rig_pending_frame", -9)) == frame_index else ""
	m.erase("rig_pending")
	m.erase("rig_pending_frame")
	return part


## The hero's damage on `m`. With a rig the struck part (`part`, else the one
## aimed at this frame, else the body / BodyParts' seeded pick by
## cfg.unaimed) takes it and all of it counts against m.hp; a part that
## breaks is severed (EVENT_SEVER, stagger, flash). Without a rig m.hp just
## drops. Returns BodyParts' {part, destroyed, killed} ({} without a rig).
func damage(m: Dictionary, amount: float, part: String = "") -> Dictionary:
	if rig_of(m).is_empty():
		m.hp = float(m.hp) - amount
		return {}
	_ensure(m)
	if part.is_empty(): part = take_aim(m)
	else: take_aim(m)
	part = _route(m, part)
	if part.is_empty() and str(cfg.unaimed) == "body": part = _root(library.rig(rig_of(m)), m)
	var lost_before: Array = Array(m.parts_lost).duplicate()
	var breaks_before := int(m.get("part_breaks", 0))
	var result: Dictionary = parts.damage(m, amount, part)
	if str(result.get("part", "")).is_empty(): return result
	m.rig_hits = int(m.get("rig_hits", 0)) + 1
	m.rig_hit_part = str(result.part)
	if bool(result.destroyed):
		if bool(cfg.own_break_sound):
			# the cut sounds its own break (EVENT_SEVER sound), not feedback.gd's generic one
			m.rig_breaks = int(m.get("rig_breaks", 0)) + int(m.get("part_breaks", 0)) - breaks_before
			m.part_breaks = breaks_before
		var gone: Array[String] = []
		for id: Variant in m.parts_lost:
			if not id in lost_before: gone.append(str(id))
		_sever(m, str(result.part), gone, bool(result.killed))
	return result


## Body centre of `m` in world px (BodyParts' m.pos): above the drawn feet,
## else above m.p lifted by its altitude.
func centre(m: Dictionary) -> Vector2:
	var rig: Dictionary = library.rig(rig_of(m))
	var foot := _foot(m)
	if rig.is_empty(): return foot
	return foot - Vector2(0, (float(rig.ground.y) - float(rig.center.y)) * float(rig.scale))


# ---------------------------------------------------------------- drawing

## True when `m` (a monster, or a corpse with a uid) is drawn by its rig.
func draws(m: Dictionary) -> bool:
	if renderer == null or not renderer.is_ready() or rig_of(m).is_empty(): return false
	return has_rig(m) or (m.has("uid") and not m.has("hp"))


## Draws `m` with its feet at `foot` (hell_monsters.gd _draw_lord: m.p lifted
## by the altitude), `size` x its rig scale (growing in, the new form
## swelling), `tint` (rgb multiplier: the transformation glow, an echo's
## violet; alpha fades the figure) and `sink` 0..1 of its height under the
## floor (burrowing). Hit flash, attack clip, lost parts and the death follow
## m. Hands the glow record to glow_mark. Returns the figure's top y or NAN.
func draw(l: CanvasItem, m: Dictionary, foot: Vector2, size: float = 1.0, tint: Color = Color.WHITE, sink: float = 0.0, pose: Dictionary = {}) -> float:
	if not draws(m): return NAN
	var rig: Dictionary = library.rig(rig_of(m))
	var S := float(rig.scale) * size
	# the full height plus SINK_MARGIN, so breathing and bobbing never lift a sliver out of the floor
	var cut := clampf(sink, 0.0, 1.0) * (float(rig.ground.y) - float(rig.top) + 1.0 + SINK_MARGIN) * S
	var phase := act_phase(m)
	var whole_flash := float(m.get("rig_flash", 0.0)) > 0.0
	var flash := maxf(float(m.get("rig_flash", 0.0)), maxf(float(m.get("hit", 0.0)), float(pose.get("flash", 0.0)) * 0.16))
	var e := {"rig": rig_of(m), "uid": int(m.uid), "face": float(m.get("face", 1.0)), "moving": str(m.get("anim", "")) == "run",
		"flying": str(m.get("anim", "")) == "fly", "tint": Color(tint.r, tint.g, tint.b, 1.0), "alpha": tint.a, "size": size, "cut": cut,
		"shadow": false, "hit_part": "" if whole_flash else str(m.get("rig_hit_part", "")), "hit_flash": flash,
		"hits": int(m.get("rig_hits", 0)), "lost": Array(m.get("parts_lost", [])).duplicate(), "dying_p": _dying_p(m)}
	e.merge(phase, true)
	var top: float = renderer.draw_enemy(l, e, foot - Vector2(0, (float(rig.ground.y) - float(rig.center.y)) * S))
	m.rig_drawn = frame_index
	m.rig_foot = foot
	m.rig_cut = cut
	var def: Variant = m.get("def")
	if def is Dictionary and def.has("w") and def.has("h"): _atlas[int(m.uid)] = Vector2(float(def.w), float(def.h))
	_mark(m, rig, foot, S, cut, tint.a)
	return top


## Draws a dead form's corpse (hell_monsters.gd corpses, with the monster's
## uid) collapsed and fading over corpse_time. False when it has no rig.
func draw_corpse(l: CanvasItem, c: Dictionary) -> bool:
	if not c.has("uid") or not draws(c): return false
	var rig: Dictionary = library.rig(rig_of(c))
	var S := float(rig.scale)
	var fade := 1.0 - clampf(float(c.get("t", 0.0)) / maxf(0.01, float(cfg.corpse_time)), 0.0, 1.0)
	var foot: Vector2 = Vector2(c.p) + Vector2(0, float(cfg.foot_drop))
	var e := {"rig": rig_of(c), "uid": int(c.uid), "face": float(c.get("face", 1.0)), "alpha": fade, "shadow": false,
		"lost": Array(_last_lost.get(int(c.uid), [])).duplicate(), "dying_p": _corpse_p(c)}
	renderer.draw_enemy(l, e, foot - Vector2(0, (float(rig.ground.y) - float(rig.center.y)) * S))
	_mark(c, rig, foot, S, 0.0, fade)
	return true


## Debris of severed parts on the floor (under the actors).
func draw_under(l: CanvasItem) -> void:
	if renderer != null: renderer.draw_under(l)


## Chips, embers and flashes of the cuts (over the actors).
func draw_over(l: CanvasItem) -> void:
	if renderer != null: renderer.draw_over(l, _snapshot)


## World position of rig point `id` (mouth, throat, hand, tail_tip, core) as
## `m` was last drawn, or `fallback` while it was not (or the point is sunk).
func point(m: Dictionary, id: String, fallback: Vector2) -> Vector2:
	if not _fresh(m): return fallback
	var at: Variant = _records.get(int(m.uid), {}).get("points", {}).get(id)
	return at if at is Vector2 and (at as Vector2).is_finite() else fallback


## Where source point `at` of part `id` of `m` was last drawn (world px): a
## mouth of a many-headed beast (hell_monsters.gd "mouths"); `fallback` while
## it was not drawn this frame.
func part_point(m: Dictionary, id: String, at: Vector2, fallback: Vector2) -> Vector2:
	if renderer == null or not _fresh(m): return fallback
	var p: Vector2 = renderer.world_point(RigRenderer.key_of(m), id, at)
	return p if p.is_finite() and p != Vector2.ZERO else fallback


## Where an act of `kind` starts (cfg.muzzles: bolts, breath and sweep from
## the mouth, rings, beams and bursts from the core) as `m` was last drawn,
## else `fallback` (hell_monsters.gd's m.p - (0, m.cy) and friends).
func muzzle(m: Dictionary, kind: String, fallback: Vector2) -> Vector2:
	var muzzles: Dictionary = cfg.muzzles if cfg.muzzles is Dictionary else {}
	return point(m, str(muzzles.get(kind, muzzles.get("default", "core"))), fallback)


# ------------------------------------------------------------------ inside

func _step(m: Dictionary, dt: float) -> void:
	_ensure(m)
	if not has_rig(m): return
	for key: String in ["rig_stagger", "rig_flash", "rig_ground"]:
		m[key] = maxf(0.0, float(m.get(key, 0.0)) - dt)
	var act: Variant = m.get("act")
	var flying_act: bool = act is Dictionary and str(act.get("kind", "")) == "flight"
	# BOSS-04: a landing leaves him on the ground for ground_min
	if bool(m.get("rig_flying", false)) and not flying_act and m.get("trans") == null and m.get("dying") == null:
		m.rig_ground = float(cfg.ground_min)
	m.rig_flying = flying_act
	if not act is Dictionary or not _released(act): m.exposed_action = ""
	var lost_before: Array = Array(m.parts_lost).duplicate()
	var regrows := int(m.get("part_regrows", 0))
	parts.step(m, dt)
	if int(m.get("part_regrows", 0)) > regrows:
		for id: Variant in lost_before:
			if not id in m.parts_lost:
				_events.append({"name": EVENT_REGROW, "uid": int(m.uid), "monster": str(m.id), "part": str(id), "at": centre(m)})
	m.pos = centre(m)
	_last_lost[int(m.uid)] = Array(m.parts_lost).duplicate()


## Attaches parts on first sight (or on a new form) and splits them again
## when m.max changed after spawn (an echo gets its own small HP).
func _ensure(m: Dictionary) -> void:
	if not has_rig(m) or str(m.get("rig", "")) != rig_of(m):
		attach(m)
	elif not is_equal_approx(float(m.get("max_hp", 0.0)), float(m.get("max", m.get("max_hp", 0.0)))):
		_resplit(m)


## Splits m.max over the parts again; lost parts stay lost and the stagger,
## flash, ground lock, flight, hit counters, open throat and regrow timers
## carry over (only the HP shares change).
func _resplit(m: Dictionary) -> void:
	var keep: Dictionary = {}
	for key: String in ["uid", "rig_stagger", "rig_flash", "rig_ground", "rig_flying", "rig_hits", "rig_hit_part", "exposed_action", "rig_pending", "rig_pending_frame"]:
		if m.has(key): keep[key] = m[key]
	var lost: Array = Array(m.parts_lost).duplicate()
	var timers: Dictionary = Dictionary(m.get("regrow", {})).duplicate()
	attach(m)
	m.merge(keep, true)
	for id: Variant in lost:
		if not m.parts.has(id): continue
		m.parts[id].hp = 0.0
		if not id in m.parts_lost: m.parts_lost.append(id)
		if timers.has(id): m.regrow[id] = timers[id]


func _released(act: Dictionary) -> bool:
	return bool(act.get("rig_out", act.get("feel_out", false))) and not bool(act.get("warn", false))


## The first part lost since the attack `a` was prepared (its rig_lost), "" when none or unprepared.
func _cut_since(m: Dictionary, a: Dictionary) -> String:
	if not a.get("rig_lost") is Array: return ""
	var before: Array = a.rig_lost
	for id: Variant in m.parts_lost:
		if not id in before: return str(id)
	return ""


## A lost part whose loss disables `action` (directly or as the last of its group), else "".
func _disabling_part(m: Dictionary, action: String) -> String:
	var rig: Dictionary = library.rig(rig_of(m))
	for id: Variant in m.parts_lost:
		if action in RigLibrary.disabled_actions(rig.by_id.get(str(id), {}).get("disables", [])): return str(id)
	for group: Variant in rig.get("groups", {}).values():
		if group is Dictionary and action in RigLibrary.disabled_actions(group.get("disables", [])):
			var members: Array = group.get("parts", [])
			if not members.is_empty(): return str(members[-1])
	return ""


## [windup, active, recover] of a running act (act_times with its own values).
func _times(act: Dictionary) -> Vector3:
	var kind := str(act.get("kind", ""))
	var a: Dictionary = act.get("a", {})
	var table: Dictionary = cfg.act_times if cfg.act_times is Dictionary else ACT_TIMES
	var spec: Array = table.get(kind, [0.4, 0.2, 0.2])
	var times := Vector3(float(spec[0]), float(spec[1]), float(spec[2]))
	match kind:
		"sweep", "beam", "spiral", "flight": times.y = float(a.get("duration", times.y))
		"ring": times.y = 0.35 * float(a.get("waves", 1))
		"dash": times.y = minf(0.55, float(a.get("range", 500.0)) / maxf(1.0, float(a.get("speed", 1000.0))))
		"slam": times.x = 0.7 if bool(a.get("leap", false)) else 0.75
	if kind == "flight": times.z = float(cfg.flight_land)
	return times


## A broken part: stagger, white flash and the event the game routes to its
## hitstop, flash, debris, sound and wound (the boss's values, cfg.minor's
## for any other monster). EVENT_SEVER payload: uid, monster (id), boss,
## part, label, also (parts that fell with it), at (the joint, world px: the
## wound), center (the part's centre, world px: the debris), material, chips
## [Color], wound [dark rim, hot rim, core], glow (Color), sound (own name),
## sounds (own first, then fallbacks: play the first that exists),
## own_sound (true: feedback.gd's generic break was silenced, the game plays
## `sounds`), hitstop, flash, shake, stagger (s), disabled [attack ids now
## impossible], weakened {attack id: {param: factor}}, killed.
func _sever(m: Dictionary, part: String, gone: Array[String], killed: bool) -> void:
	var name := rig_of(m)
	var rig: Dictionary = library.rig(name)
	var spec: Dictionary = rig.by_id.get(part, {})
	var material := str(rig.get("material", ""))
	var colors: Dictionary = RigRenderer.palette(material)
	var boss := bool(m.get("boss", false))
	var tier: Dictionary = cfg if boss or not cfg.get("minor") is Dictionary else merged(cfg, cfg.minor)
	m.rig_stagger = float(tier.stagger)
	m.rig_flash = float(tier.flash)
	m.exposed_action = "" if str(spec.get("exposed", "")) == str(m.get("exposed_action", "")) else str(m.get("exposed_action", ""))
	var disabled: Array[String] = []
	var weakened: Dictionary = {}
	for a: Variant in m.get("st", {}).get("attacks", []):
		if not a is Dictionary: continue
		var action := str(a.get("id", ""))
		if not parts.can(m, action): disabled.append(action)
		var factors: Dictionary = parts.weakened(m, action)
		if not factors.is_empty(): weakened[action] = factors
	var also: Array[String] = []
	for id: String in gone:
		if id != part: also.append(id)
	var sounds: Array = Array(cfg.break_sounds.get(material, [])) if cfg.break_sounds is Dictionary else []
	if sounds.is_empty(): sounds = ["break_" + material]
	_events.append({"name": EVENT_SEVER, "uid": int(m.uid), "monster": str(m.id), "boss": boss,
		"part": part, "label": str(spec.get("label", part)), "also": also,
		"at": _world_of(m, str(spec.get("parent", "")), Vector2(spec.get("pivot", Vector2.ZERO))),
		"center": _world_of(m, part, Vector2(spec.get("center", Vector2.ZERO))),
		"material": material, "chips": colors.get("chips", []), "wound": colors.get("wound", []), "glow": colors.get("glow", Color.WHITE),
		"sound": str(sounds[0]), "sounds": sounds, "own_sound": bool(cfg.own_break_sound),
		"hitstop": float(tier.hitstop), "flash": float(tier.flash), "shake": float(tier.shake),
		"stagger": float(tier.stagger), "disabled": disabled, "weakened": weakened, "killed": killed})


## A hit on a hidden exposed part (the throat outside its breath) lands on the
## body (the rig's root); one on the tail beyond tail_2 on tail_2.
func _route(m: Dictionary, part: String) -> String:
	if part.is_empty() or not m.get("parts", {}).has(part): return part
	var rig: Dictionary = library.rig(rig_of(m))
	var exposed := str(rig.by_id.get(part, {}).get("exposed", ""))
	if not exposed.is_empty() and exposed != str(m.get("exposed_action", "")): return _root(rig, m)
	return parts.carrier(m, part)


func _root(rig: Dictionary, m: Dictionary) -> String:
	for part: Dictionary in rig.get("parts", []):
		if str(part.parent).is_empty() and m.parts.has(part.id): return str(part.id)
	return ""


## True when `m` was drawn in this or the last frame (its pose is current).
func _fresh(m: Dictionary) -> bool:
	return renderer != null and int(m.get("rig_drawn", -9)) >= frame_index - 1


## The feet of `m`: where it was last drawn, else m.p lifted by its altitude.
func _foot(m: Dictionary) -> Vector2:
	if _fresh(m) and m.get("rig_foot") is Vector2: return m.rig_foot
	return Vector2(m.get("p", Vector2.ZERO)) + Vector2(0, float(cfg.foot_drop) - float(m.get("alt", 0.0)))


## The floor line (world y) of a figure drawn sunk into the floor; INF while it stands.
func _floor_y(m: Dictionary) -> float:
	if not _fresh(m) or float(m.get("rig_cut", 0.0)) <= 0.0 or not m.get("rig_foot") is Vector2: return INF
	return (m.rig_foot as Vector2).y


## The living parts a hit can land on, frontmost first: {id, part, xform, inv,
## scale, z}. The pose last drawn (parts it drew above the floor), else the
## rest pose (children of a lost part are gone with it).
func _candidates(m: Dictionary) -> Array[Dictionary]:
	var rig: Dictionary = library.rig(rig_of(m))
	var result: Array[Dictionary] = []
	if rig.is_empty(): return result
	var living: Dictionary = parts.alive(m)
	var drawn: Dictionary = renderer.part_transforms(RigRenderer.key_of(m)) if _fresh(m) else {}
	var rest := _rest_xform(m, rig)
	for part: Dictionary in rig.parts:
		var id := str(part.id)
		if not living.has(id) or not Rect2(part.bounds).has_area(): continue
		var xform: Transform2D
		if _fresh(m):
			if not drawn.has(id): continue
			xform = drawn[id]
		else:
			if _hidden(rig, m, id): continue
			xform = rest
		result.append({"id": id, "part": part, "xform": xform, "inv": xform.affine_inverse(), "scale": maxf(0.001, xform.x.length()), "z": int(part.z)})
	result.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return int(p.z) > int(q.z))
	return result


## Source px of the full frame -> world px in the rest pose (facing m.face).
func _rest_xform(m: Dictionary, rig: Dictionary) -> Transform2D:
	var S := float(rig.scale)
	var face := -1.0 if float(m.get("face", 1.0)) < 0.0 else 1.0
	var anchor := Vector2(float(rig.ground.x), float(rig.center.y) + float(rig.get("hover", 0.0)))
	return Transform2D(Vector2(face * S, 0), Vector2(0, S), centre(m) - Vector2(face * S * anchor.x, S * anchor.y))


func _hidden(rig: Dictionary, m: Dictionary, id: String) -> bool:
	var at := id
	for _depth in range(32):
		if at.is_empty(): return false
		if at in m.parts_lost: return true
		at = str(rig.by_id.get(at, {}).get("parent", ""))
	return false


## World box around every candidate part's bounds (the broad phase).
func _reach_box(candidates: Array[Dictionary]) -> Rect2:
	var box := Rect2()
	var first := true
	for c: Dictionary in candidates:
		var area: Rect2 = c.part.bounds
		var xform: Transform2D = c.xform
		for corner: Vector2 in [area.position, Vector2(area.end.x, area.position.y), area.end, Vector2(area.position.x, area.end.y)]:
			var p: Vector2 = xform * corner
			if first:
				box = Rect2(p, Vector2.ZERO)
				first = false
			else:
				box = box.expand(p)
	return box


## True when an opaque pixel of the candidate (above `floor_y`) lies within `radius` world px of `point`.
func _touches(c: Dictionary, point: Vector2, radius: float, floor_y: float = INF) -> bool:
	return is_finite(_pixel_distance(c, point, radius, floor_y))


## World distance from `point` to the candidate's nearest opaque pixel centre,
## INF beyond `radius` world px; pixels drawn below `floor_y` do not count.
func _pixel_distance(c: Dictionary, point: Vector2, radius: float, floor_y: float = INF) -> float:
	var part: Dictionary = c.part
	var image: Image = part.get("image")
	if image == null: return INF
	var local: Vector2 = Transform2D(c.inv) * point
	var scale := float(c.scale)
	var r := maxf(0.5, radius / scale)
	if not Rect2(part.bounds).grow(r + 1.0).has_point(local): return INF
	var xform: Transform2D = c.xform
	var best := INF
	var span := int(ceil(r))
	var base := Vector2i(floori(local.x), floori(local.y))
	for dy in range(-span, span + 1):
		for dx in range(-span, span + 1):
			var pixel := base + Vector2i(dx, dy)
			if pixel.x < 0 or pixel.y < 0 or pixel.x >= image.get_width() or pixel.y >= image.get_height(): continue
			if image.get_pixelv(pixel).a < 0.5: continue
			var centre_px := Vector2(pixel) + Vector2(0.5, 0.5)
			var distance := local.distance_to(centre_px)
			if distance > r + 0.71 or distance >= best: continue
			if is_finite(floor_y) and (xform * centre_px).y > floor_y: continue
			best = distance
	return best * scale if is_finite(best) else INF


## A source point on part `id` in world px: the pose last drawn when the part
## (or an ancestor) was drawn, else the rest pose.
func _world_of(m: Dictionary, id: String, source_point: Vector2) -> Vector2:
	if _fresh(m) and not id.is_empty():
		var at: Vector2 = renderer.world_point(RigRenderer.key_of(m), id, source_point)
		if at != Vector2.ZERO: return at
	return _rest_xform(m, library.rig(rig_of(m))) * source_point


func _dying_p(m: Dictionary) -> float:
	var dying: Variant = m.get("dying")
	if not dying is Dictionary: return -1.0
	var t := float(dying.get("t", 0.0)) - float(cfg.death_start)
	if t < 0.0: return -1.0
	return clampf(t / _death_len(), 0.0, 1.0)


func _corpse_p(c: Dictionary) -> float:
	return clampf((float(cfg.death_end) - float(cfg.death_start) + float(c.get("t", 0.0))) / _death_len(), 0.0, 1.0)


## The rig's death clip spans the end of dying and the corpse's life.
func _death_len() -> float:
	return maxf(0.01, float(cfg.death_end) - float(cfg.death_start) + float(cfg.corpse_time))


## The glow record of a figure drawn now (see glow_mark), kept for point()
## and handed to glow_mark. The box is the form's atlas frame (m.def w x h,
## a corpse's from its live draw) with the feet at its bottom centre, as
## hell_monsters.gd _mark() has it: the atlas is the same art at the same
## pixel scale, so vfx_glow.json's `at` anchors land on the rest pose. Without
## an atlas size the rig frame is placed so `at` in rig source px land on the
## rest pose instead.
func _mark(who: Dictionary, rig: Dictionary, foot: Vector2, S: float, cut: float, alpha: float) -> void:
	var face := -1.0 if float(who.get("face", 1.0)) < 0.0 else 1.0
	var src: Vector2 = _atlas.get(int(who.uid), Vector2.ZERO)
	var box_foot := foot
	if src == Vector2.ZERO:
		src = rig.size
		box_foot = foot + Vector2((src.x * 0.5 - float(rig.ground.x)) * S * face, (src.y - float(rig.ground.y)) * S)
	var points: Dictionary = {}
	var key := RigRenderer.key_of(who)
	for id: String in rig.get("points", {}):
		var spec: Dictionary = rig.points[id]
		var at: Vector2 = renderer.world_point(key, str(spec.part), Vector2(spec.at))
		points[id] = Vector2.INF if cut > 0.0 and at.y > foot.y else at
	var record := {"foot": box_foot.round(), "size": src * S, "src": src, "face": face, "lean": 0.0, "cut": cut,
		"alpha": alpha, "rig": rig_of(who), "points": points}
	_records[int(who.uid)] = record
	if glow_mark.is_valid(): glow_mark.call(who, record)


## What the view needs of every rigged monster and corpse this frame.
func _view_snapshot(mobs: Array, corpses: Array) -> Dictionary:
	var enemies: Array = []
	for m: Variant in mobs:
		if not m is Dictionary or not has_rig(m): continue
		var at := centre(m)
		var e := {"rig": rig_of(m), "uid": int(m.uid), "hits": int(m.get("rig_hits", 0)), "lost": Array(m.parts_lost).duplicate(),
			"dying_p": _dying_p(m), "x": at.x, "y": at.y}
		e.merge(act_phase(m), true)
		enemies.append(e)
	for c: Variant in corpses:
		if not c is Dictionary or not c.has("uid") or rig_of(c).is_empty(): continue
		var p: Vector2 = c.get("p", Vector2.ZERO)
		enemies.append({"rig": rig_of(c), "uid": int(c.uid), "lost": Array(_last_lost.get(int(c.uid), [])).duplicate(), "dying_p": _corpse_p(c), "x": p.x, "y": p.y})
	return {"enemies": enemies}
