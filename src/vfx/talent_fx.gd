extends RefCounted
## Client art of the talents (snapshot "talents", src/combat/talent_combat.gd)
## on the art grid of the world it is drawn in (`art` world px per art pixel:
## the crypt 2, the story worlds 3): zones as physics pools with gas or flames
## over them, set traps, the companions, the talent shots and the short events.
##
## The Elementsprache (docs/ZAUBER-SPRACHE.de.md, user decision 2026-10-31):
## a spell is pixel matter of its element, never a sheet-frame explosion. Every
## active talent has four beats. CAST: element pixels gather at the caster's
## hand (TalentPixels.gather; weight by tier). FLIGHT: a core ball with a
## dithered trail sized by tier that lights the glow layer (TalentPixels.shot).
## IMPACT: a painted burst (TalentPixels.impact) and pixel physics in the
## host's particles (src/vfx/particles.gd: sparks for fire, gold and steel,
## shards for ice and bone, drops for poison, blood and water, motes for the
## void and the souls, chips for stone and beast) with a crack or scorch where
## it hit, and shake, hitstop and a bloom flash by tier. RESIDUE: the element
## stays on the floor as a small pool (fire, ice, poison, blood, void, water;
## src/vfx/pool_paint.gd, synced as source "talent_residue") or as settled
## chips; zones leave theirs when they end. A shot's impact has no event of
## its own: it is inferred from the shot vanishing between two drawing passes
## (draw_bullet records every talent shot it is shown). Sheets stay only for
## shapes that read (slash, whirl, claw, the arrows and the knife, the phoenix,
## the meteors and the spear). Rings, waves, trails, shields and rage auras are
## pixels with the exact hit radius (src/vfx/talent_pixels.gd); the ultimates'
## legacy forms live in src/vfx/talent_ults.gd. Nothing is see-through:
## everything fades by the ordered dither and stops at walls (the host sets
## PixelPaint.clip and the sprites' floor). All sizes, tiers, residue radii and
## times come from assets/data/vfx_talents.json. The companions (wolf, bear)
## come from the 0x72 companion pack "Enchanted Forest Characters"; the water
## elemental, bone warrior, falcon and Pyro-Monster are drawn in the archive's
## style (scripts/make_companion_sprites.py, scripts/make_falcon.py).
## The Feuermagier's own language (user feedback 2026-10-31, "zu lasch"):
## fire shots carry a white-hot heart and an ember tail, every fire impact is
## a fat explosion in pushes (TalentPixels.boom: flash frame, pressure rings,
## sparks that bounce and lie as embers, a scorch), the Flammenmeer is real
## fire pools along its stroke with pixel tongues and smoke that burn down to
## ash, the Infernospeer an ember spear with heat shimmer that cracks the
## floor and leaves lava, the Glutkette a chain of ember sparks whose targets
## burn, the Meteor a growing shadow, a huge boom and a lava crater that
## cools, the Phönixschritt a fire trail with ember wings. Every fire residue
## is a real pool (the host's element physics apply to what stands in it);
## values in vfx_talents.json "fire".
## Presentation only.

const FxSprites = preload("res://src/vfx/fx_sprites.gd")
const PerfMarks = preload("res://src/debug/perf_marks.gd")
const PixelPaint = preload("res://src/vfx/pixel_paint.gd")
const Glow = preload("res://src/vfx/glow.gd")
const Pal = preload("res://src/vfx/talent_palette.gd")
const TalentPixels = preload("res://src/vfx/talent_pixels.gd")
const TalentUlts = preload("res://src/vfx/talent_ults.gd")
const TalentDome = preload("res://src/vfx/talent_dome.gd")
const CompanionRigs = preload("res://src/vfx/companion_rigs.gd")
const DATA_PATH := "res://assets/data/vfx_talents.json"
const TALENTS_PATH := "res://assets/data/talents.json"
## Shot styles drawn here as element matter (talents.json "style"); arrows are the host's.
const SHOT_STYLES := {"frost_lance": "ice", "arcane": "void", "fireball": "fire", "infernospear": "fire", "blade": "steel"}
## Shots that keep a sheet because its shape reads (a knife, a dart): sheet and scale.
const TALENT_SHOTS := {"blade_9": ["knife", 1.2], "trapper_1": ["poison_dart", 1.3]}
## Lasting buffs drawn as a shield dome: [size, element], the first one a hero has wins.
const DOMES := [["unbreakable", 2, "stone"], ["bulwark", 1, "stone"], ["oath", 1, "stone"], ["shield", 1, "ice"]]
## Element of each lasting buff on a hero.
const BUFF_ELEMENT := {"frenzy": "blood", "bloodlust": "blood", "bulwark": "stone", "oath": "stone", "unbreakable": "stone",
	"timebreak": "void", "shield": "ice", "channel": "steel"}
## Element of a Shift block's look (block_break).
const LOOK_ELEMENT := {"mana_bubble": "void", "gold_bubble": "gold", "soul_bubble": "soul", "shield_bubble": "ice"}
## Residue tier weights: where a shot tier sits between the small and the huge residue.
const TIER_K := {"small": 0.0, "medium": 0.34, "large": 0.67, "huge": 1.0}
const INK := Color("1a1414")
## Zone looks drawn here as their own art (not as a pool or gas).
const LOOKS := ["flames", "firewall", "lava", "ice", "arcane", "snow", "arrows", "crater", "souls", "plague"]
## How long a shot's painted impact plays (s).
const IMPACT_TIME := 0.45

var sprites := FxSprites.new()
## The companions as part rigs (src/vfx/companion_rigs.gd); `rigs` is the view's rig renderer (debris, clocks), set by the host.
var companion_rigs := CompanionRigs.new()
var rigs: RefCounted = null
## The poison zones (Todeszone), burning ground (Feuersturm) and the residue
## the talents leave as physics pools that run out and stop at the walls
## (src/vfx/pool_paint.gd, set by the host with its art pixel); null draws
## dithered discs and leaves no residue.
var pools: RefCounted = null
## False when the pools are a world layer its host draws (the Hell's).
var draw_pools := true
## The host's particles (src/vfx/particles.gd) the impacts burst into, null without;
## their units are this canvas's world px times to_particles (story worlds 1 / 1.5).
var particles: RefCounted = null
var to_particles := 1.0
## The world's gas layer (src/vfx/gas.gd): poison zones are clouds in it; null paints puffs.
var gas: RefCounted = null
## World px per art pixel of the canvas (crypt 2, story worlds 3).
var art := 2.0
## From a hero's ground point to his chest, world px (crypt, story worlds: set_art).
var body := Vector2(0, -14)
## From a hero's ground point to his feet, world px (the crypt draws him standing 16 px lower).
var feet := Vector2(0, 16)
## How far over a shot's floor point the host draws it (the story worlds lift
## their shots 30 px: src/hell/hell_talents.gd draw_world); impacts and
## residue land this far below the drawn shot. set_art guesses it by the grid.
var shot_lift := Vector2.ZERO
## assets/data/vfx_talents.json
var cfg: Dictionary = {}

var _clock := 0.0
## Event ids already seen by the drawing (pools, flashes) and by take_feel.
var _seen: Dictionary = {}
var _felt: Dictionary = {}
## Bloom flashes of weighty events: {at, col, t0, T, r, strength}.
var _flashes: Array = []
## Pools the ultimates leave on the client: id -> {until, entry}.
var _ult_pools: Dictionary = {}
## The residue the talents leave: id -> {until, entry} (source "talent_residue").
var _residue: Dictionary = {}
## Shots recorded in the drawing pass being drawn and in the pass before it
## ({at, v, talent, element, tier, glow}): a shot in the last pass but not in
## this one struck something (or ran out).
var _shots_pass: Array = []
var _shots_live: Array = []
var _pass_clock := -1.0
var _live_clock := -1.0
## The shots' impacts playing: {at, dir, element, size, t0, seed, kind ("" painted
## impact, "boom" the fire explosion), T its length s}.
var _impacts: Array = []
## Chain targets burning on the client (the snapshot has no enemy statuses): {at, until, seed}.
var _burning: Array = []
## Smoke puffs the Flammenmeer and the crater sent into the gas: key -> when.
var _smoked: Dictionary = {}
## Zones seen last frame (they leave their residue when they end): id -> zone.
var _zones_seen: Dictionary = {}
## The weight of client-side impacts waiting for take_feel.
var _pending_feel: Array = []
## Ids of client-side things (residue, impacts), never the server's event ids.
var _next_local := 1
## talents.json: the type of each talent (for the tier of its cast), read on first use.
var _types: Dictionary = {}
var _types_read := false
var _frames: Dictionary = {}
var _flask_texture: Texture2D
## The rubber shield dome of each hero (src/vfx/talent_dome.gd): owner -> dome.
var _domes: Dictionary = {}
## A dome for one-off flashes (a guard), never dented.
var _flash_dome: RefCounted


func _init() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH)) if FileAccess.file_exists(DATA_PATH) else null
	cfg = parsed if parsed is Dictionary else {}
	_flash_dome = TalentDome.new(cfg.get("dome", {}))
	_flash_dome.size = 0


## Puts the art on a world's grid: `px` world px per art pixel, `lift` from a
## hero's ground point to his chest, `foot` to his feet. Sprites follow the grid.
func set_art(px: float, lift: Vector2, foot: Vector2 = Vector2.ZERO) -> void:
	art = px
	body = lift
	feet = foot
	sprites.pixel = px
	shot_lift = Vector2(0, 30.0) if px > 2.0 else Vector2.ZERO


## The dome of hero `owner`, made on first use.
func _dome(owner: int) -> RefCounted:
	if not _domes.has(owner): _domes[owner] = TalentDome.new(cfg.get("dome", {}))
	return _domes[owner]


## A crypt size in world px of this world (the story worlds are 1.5 times larger).
func _u(crypt_px: float) -> float:
	return crypt_px * art / 2.0


func _snap(p: Vector2) -> Vector2:
	return (p / art).round() * art


## A deterministic 0..1 value for `seed` (client-side timings).
static func _h(seed: int) -> float:
	var h := seed * 374761393 + 1013904223
	h = (h ^ (h >> 13)) * 1274126177
	return float((h ^ (h >> 16)) & 0xffff) / 65535.0


func _local_id() -> int:
	_next_local += 1
	return _next_local


# ---------- tiers ----------

## The shot tier name of a talent (assets/data/vfx_talents.json shots.talent_tier).
func _shot_tier_name(talent: String) -> String:
	return str(cfg.get("shots", {}).get("talent_tier", {}).get(talent, "small"))


## The shot tier spec (core, trail, burst, parts, crack, glow) of a tier name.
func _shot_tier(name: String) -> Dictionary:
	var tiers: Dictionary = cfg.get("shots", {}).get("tiers", {})
	return tiers.get(name, tiers.get("small", {"core": 1, "trail": 5, "burst": 5, "parts": 6, "crack": 0, "glow": 7}))


## The talents.json type of a talent ("projectile", "nova", ...; "" unknown).
func _type_of(talent: String) -> String:
	if not _types_read:
		_types_read = true
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(TALENTS_PATH)) if FileAccess.file_exists(TALENTS_PATH) else null
		if parsed is Dictionary:
			for id: String in parsed.get("talents", {}):
				_types[id] = str(parsed.talents[id].get("type", ""))
	return str(_types.get(talent, ""))


## The tier of a talent's cast: an ultimate huge, a shot its shot tier, the rest by type.
func _cast_tier(talent: String, ult: bool) -> String:
	if ult: return "huge"
	var shots: Dictionary = cfg.get("shots", {}).get("talent_tier", {})
	if shots.has(talent): return str(shots[talent])
	return str(cfg.get("cast", {}).get("kind_tier", {}).get(_type_of(talent), "small"))


# ---------- ground ----------

## Floor layer: zones, residue and traps (under the actors).
func draw_ground(canvas: CanvasItem, state: Dictionary, clock: float) -> void:
	_clock = clock
	PerfMarks.begin()
	_settle_shots(clock, state)
	_observe(state, clock)
	PerfMarks.add("tg.observe")
	var zones: Array = state.get("zones", [])
	if pools != null:
		var entries: Array = []
		for zone: Dictionary in zones:
			var length := maxf(0.3, float(zone.get("total", zone.get("time", 1.0))))
			var p := clampf(1.0 - float(zone.get("time", length)) / length, 0.0, 1.0)
			if _own_look(zone):
				_fire_look_pools(entries, zone, p, length, clock)
				continue
			entries.append({"id": int(zone.get("id", 0)), "k": "pool", "st": "fire" if str(zone.get("status", "")) == "burn" else "poison",
				"x": float(zone.x), "y": float(zone.y), "r": float(zone.r), "p": p, "L": length})
		for id: int in _ult_pools.keys():
			if float(_ult_pools[id].until) < clock: _ult_pools.erase(id)
			else: entries.append(_ult_pools[id].entry)
		pools.sync(entries, clock, "talent")
		pools.sync(_residue_entries(clock), clock, "talent_residue")
		PerfMarks.add("tg.pools_sync")
		if draw_pools: pools.draw(canvas, clock)
	if gas != null:
		# the poison zones' clouds: they spread, gather in corners, part round heroes
		var clouds: Array = []
		for zone: Dictionary in zones:
			if str(zone.get("status", "")) == "burn" or _own_look(zone): continue
			var length := maxf(0.3, float(zone.get("total", zone.get("time", 1.0))))
			clouds.append({"id": int(zone.get("id", 0)), "k": "gas", "st": "poison", "x": float(zone.x), "y": float(zone.y), "r": float(zone.r),
				"p": clampf(1.0 - float(zone.get("time", length)) / length, 0.0, 1.0), "L": length, "d": 1.0})
		gas.sync(clouds, clock, "talent")
	PerfMarks.add("tg.gas_sync")
	for drawing: Dictionary in state.get("drawings", []):
		_draw_line_preview(canvas, drawing, clock)
	_draw_looks(canvas, zones, clock)
	for zone: Dictionary in zones:
		if _own_look(zone): continue
		var at := Vector2(float(zone.x), float(zone.y))
		var r := float(zone.r)
		var id := int(zone.get("id", 0))
		var left := float(zone.get("time", 1.0))
		var total := maxf(0.3, float(zone.get("total", left)))
		var stage := int(zone.get("stage", 0))
		var every := float(zone.get("every", 1.0))
		var talent := str(zone.get("talent", ""))
		if str(zone.get("status", "")) == "burn":
			# burning ground (Feuersturm): its pool burns and lets the flames rise
			# (src/vfx/pool_paint.gd); without one, painted flames over a disc
			if pools == null or particles == null:
				if pools == null: PixelPaint.disc(canvas, at, r, r, Pal.ramp("fire")[1], art, 0.35)
				TalentUlts.zone(canvas, "fire_14", at, r, left, total, stage, every, art, clock, id)
			continue
		if pools == null: PixelPaint.disc(canvas, at, r, r, Pal.ramp("poison")[1], art, 0.3)
		if gas == null: TalentPixels.puffs(canvas, at, r, art, clock, id)
		if talent in ["trapper_6", "trapper_14"]:
			TalentUlts.zone(canvas, "trapper_14", at, r, left, total, stage, every, art, clock, id)
		else:
			var crawl := int(clock * PixelPaint.FPS)
			PixelPaint.ellipse(canvas, at + Vector2(0, art), r, r, Pal.INK, art, 3, crawl)
			PixelPaint.ellipse(canvas, at, r, r, Pal.ramp("poison")[3], art, 3, crawl)
	PerfMarks.add("tg.zones")
	_draw_orbs(canvas, state, clock)
	var traps: Dictionary = cfg.get("traps", {})
	for trap: Dictionary in state.get("traps", []):
		var kind := _trap_kind(trap)
		TalentPixels.trap(canvas, Vector2(float(trap.x), float(trap.y)), kind, float(traps.get("radius", {}).get(kind, 7)),
			float(traps.get("pulse", {}).get(kind, 1.0)), art, clock, int(trap.get("id", 0)))
	PerfMarks.add("tg.traps")


## The Flammenmeer and the meteor's crater as real pools (user feedback
## 2026-10-31: no drawn lines, the host's element physics apply to what
## stands in them): a fire pool at every pool_every-th point of a drawn
## stroke, a lava pool of lava_share of the crater's radius; and their smoke
## into the gas layer every smoke_every s (ids negative: never a zone's).
func _fire_look_pools(entries: Array, zone: Dictionary, p: float, length: float, clock: float) -> void:
	var look := str(zone.get("look", ""))
	var id := int(zone.get("id", 0))
	var path: Array = zone.get("path", [])
	if look == "flames" and not path.is_empty():
		var fm: Dictionary = cfg.get("fire", {}).get("flammenmeer", {})
		var every := maxi(1, int(fm.get("pool_every", 2)))
		var r := float(zone.get("w", 18.0)) * float(fm.get("pool_share", 1.1))
		for i in range(0, path.size(), every):
			entries.append({"id": -(id * 64 + i / every + 1), "k": "pool", "st": "fire", "x": float(path[i][0]), "y": float(path[i][1]), "r": r, "p": p, "L": length})
		_smoke_along(path, int(fm.get("smoke_stride", 8)), float(fm.get("smoke_every", 1.5)), _u(float(fm.get("smoke_r", 16))), id, clock, 1.0 - clampf(float(zone.get("time", 1.0)) / float(fm.get("ash", 0.8)), 0.0, 1.0))
	elif look == "crater":
		var me: Dictionary = cfg.get("fire", {}).get("meteor", {})
		entries.append({"id": -(id * 64 + 1), "k": "pool", "st": "lava", "x": float(zone.x), "y": float(zone.y), "r": float(zone.r) * float(me.get("lava_share", 0.5)), "p": p, "L": length})
		var at := Vector2(float(zone.x), float(zone.y))
		_smoke_along([[at.x - float(zone.r) * 0.3, at.y], [at.x + float(zone.r) * 0.3, at.y]], 1, float(me.get("smoke_every", 1.2)), float(zone.r) * 0.35, id, clock, 0.0)


## Smoke puffs rising off burning ground: a cloud of the gas layer (material
## "smoke") at every `stride`-th point of `path` every `every` s, pushed
## upwards; without a gas layer the particles' smoke. `ash` 0..1 near the end
## thickens it (the fire chokes).
func _smoke_along(path: Array, stride: int, every: float, r: float, id: int, clock: float, ash: float) -> void:
	var tick := int(clock / maxf(0.2, every))
	var key := "%d:%d" % [id, tick]
	if _smoked.has(key): return
	_smoked[key] = clock
	if _smoked.size() > 128:
		for k: String in _smoked.keys():
			if float(_smoked[k]) < clock - 10.0: _smoked.erase(k)
	var offset := tick % maxi(1, stride)
	for i in range(offset, path.size(), maxi(1, stride)):
		var at := Vector2(float(path[i][0]), float(path[i][1]))
		if gas != null:
			gas.emit("talent_smoke:%s:%d" % [key, i], "smoke", at + Vector2(0, -r * 0.5), r * (1.0 + 0.6 * ash), every * 1.3, clock, Vector2(0, -_u(22.0)), 0.45 + 0.35 * ash)
		elif particles != null:
			particles.smoke(at * to_particles, 2 + int(ash * 3.0), r * 0.4 * to_particles)


## The kind of a set trap from what the snapshot tells ({r, boom}): a trap
## without a root (boom) is an iron trap (Explosionsfalle, Jagdgrund), a wide
## one with a root the Netzfalle, a small one the Dornenfalle.
func _trap_kind(trap: Dictionary) -> String:
	if bool(trap.get("boom", false)): return "iron"
	return "net" if float(trap.get("r", 0.0)) > _u(float(cfg.get("traps", {}).get("net_over", 40))) else "thorn"


# ---------- companions ----------

## Actor layer: the companions with the "Enchanted Forest
## Characters" frames (assets/sprites/forest_0x72, the 0x72 companion pack),
## one frame pixel per art pixel like every 0x72 actor; walk frames while
## moving, idle otherwise. The pack summoned by the ultimate shows as pale
## spirits with wisps rising round them (opaque, never see-through).
func draw_pets(canvas: CanvasItem, state: Dictionary, clock: float) -> void:
	for pet: Dictionary in state.get("pets", []):
		var at := _snap(Vector2(float(pet.x), float(pet.y)))
		var face := -1.0 if float(pet.get("face", 1.0)) < 0.0 else 1.0
		var kind := str(pet.get("kind", "wolf"))
		var moving := bool(pet.get("moving", false))
		var frame := _companion_frame(kind, "walk" if moving else "idle", int(clock * (10.0 if moving else 6.0)) % 4)
		var id := int(pet.get("id", 0))
		# the falcon flies: drawn above its shadow, bobbing with the wing beats
		var lift := _snap(Vector2(0, _u(-22.0 - 3.0 * sin(clock * 3.0)))) if kind == "falcon" else Vector2.ZERO
		if kind == "falcon":
			PixelPaint.disc(canvas, at, 6.0 * art, 2.5 * art, INK, art, 0.4)
		# Wildes Erwachen: the companion grows, its rage flickers round it
		var awake := bool(pet.get("awake", false))
		var grow := art * (1.5 if awake else 1.0)
		if awake: TalentPixels.flames(canvas, at, Vector2(0, -12.0 * art / 2.0), 0.6, "beast", art, clock, id)
		var lunge := 3.0 * art if float(pet.get("bite", 0.0)) > 0.0 and kind != "water_elemental" else 0.0
		# a spirit of the pack: brightened to pale blue-white (opaque, not see-through)
		var spirit := bool(pet.get("pack", false))
		var tint := Color(1.45, 1.75, 2.1) if spirit else Color.WHITE
		if float(pet.get("hurt", 0.0)) > 0.0: tint = Color(1.0, 0.55, 0.5)
		var casting := float(pet.get("cast", 0.0))
		if casting > 0.0:
			# casting: a bright flash and a ring of its element under the feet
			var k := 1.0 - clampf(casting / 0.45, 0.0, 1.0)
			tint = tint.lerp(Color(1.6, 1.6, 1.6), (1.0 - k) * 0.6)
			TalentPixels.nova(canvas, at, _u(26.0), k, "ice" if kind == "water_elemental" else "fire" if kind == "pyro" else "beast", art, id)
		if kind == "pyro":
			# the ground glows under the Pyro-Monster, embers rise off it
			PixelPaint.disc(canvas, at + Vector2(0, -1), _u(11.0 + sin(clock * 7.0)), _u(5.0), Pal.ramp("fire")[1], art, 0.35)
			for k in range(3):
				var age := fmod(clock * 1.5 + k * 0.33, 1.0)
				var q := PixelPaint.at(at + Vector2(sin(k * 2.3 + clock) * _u(10.0), -_u(10.0 + age * 40.0)), art)
				if PixelPaint.shown(q, 1.0 - age): PixelPaint.cell(canvas, q, Pal.ramp("fire")[3 if age < 0.5 else 2], art)
		if kind == "water_elemental":
			# a wet shimmer on the floor under the gliding whirl
			PixelPaint.disc(canvas, at + Vector2(0, -1), _u(10.0 + sin(clock * 5.0)), _u(4.0), Pal.ramp("water")[2], art, 0.3)
		if CompanionRigs.draws(kind):
			# a rigged companion: its parts, poses and lost pieces (src/vfx/companion_rigs.gd)
			companion_rigs.draw(canvas, pet, at + lift + Vector2(lunge * face, 0), face, art * (1.5 if awake else 1.0), clock, rigs)
		elif frame != null:
			# feet on the point whatever the frame size (32 px forest beasts, 16 px skeletons)
			var frame_size := frame.get_size()
			canvas.draw_set_transform(at + lift + Vector2(lunge * face, 0), 0.0, Vector2(grow * face, grow))
			canvas.draw_texture(frame, Vector2(-frame_size.x * 0.5, 1.0 - frame_size.y), tint)
			canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if spirit: TalentUlts.spirit(canvas, at, art, clock, id)
		if lunge > 0.0 and sprites.has("claw"):
			sprites.draw_loop(canvas, "claw", at + Vector2(_u(22.0) * face, _u(-20.0)), 0.0, 1.0, clock, Color.WHITE, true)
		if bool(pet.get("permanent", false)) and frame != null:
			var bar := Rect2(at + lift + Vector2(-14, -frame.get_size().y * grow - 8.0), Vector2(28, 4))
			canvas.draw_rect(bar.grow(1), INK)
			canvas.draw_rect(Rect2(bar.position, Vector2(roundf(bar.size.x * clampf(float(pet.get("hp", 1.0)), 0.0, 1.0)), bar.size.y)), Color("8fd6a5") if float(pet.get("hp", 1.0)) > 0.35 else Color("e2584a"))

func _companion_frame(kind: String, motion: String, index: int) -> Texture2D:
	var path := "res://assets/sprites/forest_0x72/%s_%s_f%d.png" % [kind, motion, index]
	if kind in ["water_elemental", "bone_warrior", "falcon", "pyro"]: path = "res://assets/sprites/companions/%s_%s_f%d.png" % [kind, motion, index]
	if kind == "colossus": path = "res://assets/sprites/0x72/big_zombie_%s_anim_f%d.png" % ["run" if motion == "walk" else "idle", index]
	if kind == "skeleton": path = "res://assets/sprites/0x72/skelet_%s_anim_f%d.png" % ["run" if motion == "walk" else "idle", index]
	if not _frames.has(path): _frames[path] = load(path) if ResourceLoader.exists(path) else null
	return _frames[path]


# ---------- shots: flight and impact ----------

## FLIGHT: a talent shot ({x, y, vx, vy, style, talent, stage}) as the matter
## of its element with a dithered trail sized by tier; the knife and the dart
## keep their sheets; false when the shot is the host's (arrows). Every talent
## shot shown is recorded, so its vanishing becomes its impact.
func draw_bullet(canvas: CanvasItem, bullet: Dictionary, clock: float) -> bool:
	var flight := Vector2(float(bullet.get("vx", 1.0)), float(bullet.get("vy", 0.0)))
	var aim := flight.normalized() if flight.length() > 0.1 else Vector2.RIGHT
	var at := _snap(Vector2(float(bullet.x), float(bullet.y)))
	var talent := str(bullet.get("talent", ""))
	var style := str(bullet.get("style", ""))
	var element := Pal.element_of(talent, str(SHOT_STYLES.get(style, "steel")))
	var tier_name := _shot_tier_name(talent)
	var tier := _shot_tier(tier_name)
	if not talent.is_empty(): _track_shot(at, flight, talent, element, tier_name, float(tier.get("glow", 7)), clock)
	var own: Array = TALENT_SHOTS.get(talent, [])
	if not own.is_empty() and sprites.has(str(own[0])):
		TalentPixels.shot_trail(canvas, at, aim, element, art, int(tier.get("trail", 5)), clock)
		sprites.draw_loop(canvas, str(own[0]), at, aim.angle(), float(own[1]), clock, Color.WHITE, true)
		return true
	if talent in ["sniper_6", "sniper_14"] and style != "arrow":
		TalentUlts.arrow(canvas, at, aim, int(bullet.get("stage", 0)), art, clock)
		return true
	if not SHOT_STYLES.has(style): return false
	TalentPixels.shot(canvas, at, aim, element, art, int(tier.get("core", 1)), int(tier.get("trail", 5)), clock, talent.hash() & 0xffff, _fire_shot(tier_name, style))
	return true


## What a fire shot of `tier` carries beyond its element (vfx_talents.json
## "fire": heart, tail; the Infernospeer its spear form), empty for other elements.
func _fire_shot(tier: String, style: String) -> Dictionary:
	var fire: Dictionary = cfg.get("fire", {})
	var out := {"heart": int(fire.get("heart", {}).get(tier, 0)), "tail": int(fire.get("tail", {}).get(tier, 0))}
	if style == "infernospear":
		out.merge(fire.get("spear", {}))
		out.style = "spear"
	return out


## Records a shot shown in this drawing pass (once per shot and pass).
func _track_shot(at: Vector2, v: Vector2, talent: String, element: String, tier: String, glow: float, clock: float) -> void:
	if not _shots_pass.is_empty():
		var last: Dictionary = _shots_pass[-1]
		if last.at == at and last.talent == talent: return
	_shots_pass.append({"at": at, "v": v, "talent": talent, "element": element, "tier": tier, "glow": glow})
	_pass_clock = clock


## Closes the last drawing pass: every shot of the pass before it that no shot
## of this pass continues (same talent, near where it was heading) has struck
## something and bursts there (fizzle_tol: how far off "near" may be).
func _settle_shots(clock: float, state: Dictionary = {}) -> void:
	if not _shots_live.is_empty():
		# an explosion event of this frame carries the impact of the fire shot that caused it
		var booms: Array = []
		for event: Dictionary in state.get("events", []):
			if str(event.get("kind", "")) == "explosion" and not _seen.has(int(event.get("id", 0))):
				booms.append(Vector2(float(event.x), float(event.y)))
		var dt := clampf(_pass_clock - _live_clock, 0.0, 0.2) if _live_clock >= 0.0 and _pass_clock > _live_clock else 1.0 / 60.0
		var tol := _u(float(cfg.get("shots", {}).get("fizzle_tol", 24)))
		var left: Array = _shots_pass.duplicate()
		for old: Dictionary in _shots_live:
			var v: Vector2 = old.v
			var guess: Vector2 = old.at + v * dt
			var best := -1
			var best_d := tol + v.length() * dt
			for i in range(left.size()):
				var now: Dictionary = left[i]
				if str(now.talent) != str(old.talent): continue
				var d := guess.distance_to(now.at)
				if d < best_d:
					best_d = d
					best = i
			if best >= 0: left.remove_at(best)
			else:
				var at: Vector2 = old.at + v * dt * 0.5 + shot_lift
				var carried := false
				for boom: Vector2 in booms:
					if boom.distance_to(at) < tol * 3.0: carried = true
				if not carried: _impact(at, v, str(old.element), str(old.tier), clock, str(old.talent))
	_shots_live = _shots_pass
	_live_clock = _pass_clock
	_shots_pass = []


## IMPACT of a shot of `tier` at `at` (its floor point) flying along `v`: the
## painted burst, the element's matter in the particles with a crack or
## scorch, its residue and its weight (shake and a bloom flash by tier).
func _impact(at: Vector2, v: Vector2, element: String, tier_name: String, clock: float, talent := "") -> void:
	var tier := _shot_tier(tier_name)
	var dir := v.normalized() if v.length() > 0.1 else Vector2.RIGHT
	var size := int(tier.get("burst", 6))
	var key := _residue_key(talent, element)
	if Pal.resolve(element) == "fire":
		# fire: the fat explosion (TalentPixels.boom) and its bouncing sparks
		_boom(at, dir, size, clock, float(TIER_K.get(tier_name, 0.0)))
		if key == "lava" and particles != null:
			# the spear cracks the floor where it strikes
			particles.floor_crack(at * to_particles, _u(float(size) * 2.4) * to_particles, int(cfg.get("fire", {}).get("spear", {}).get("crack", 3)))
	else:
		_impacts.append({"at": at, "dir": dir, "element": element, "size": size, "t0": clock, "seed": _local_id(), "kind": "", "T": IMPACT_TIME})
	_matter(at, dir, element, int(tier.get("parts", 8)), int(tier.get("crack", 0)), _u(float(size) * 2.0))
	var spec: Dictionary = cfg.get("residue", {}).get(key, {})
	if not spec.is_empty():
		var cells: Array = spec.get("cells", [4, 9])
		_leave(at, dir, element, lerpf(float(cells[0]), float(cells[1]), float(TIER_K.get(tier_name, 0.0))), clock, -1.0, key)
	var feel := str(cfg.get("shots", {}).get("talent_feel", {}).get(talent, cfg.get("shots", {}).get("feel", {}).get(tier_name, "")))
	if feel != "":
		var weight: Dictionary = cfg.get("tiers", {}).get(feel, {})
		_pending_feel.append({"owner": -1, "trauma": float(weight.get("trauma", 0.0)), "shake_px": float(weight.get("shake_px", 0.0)), "hitstop": float(weight.get("hitstop", 0.0))})
		_flashes.append({"at": at + body, "col": Pal.ramp(element)[3], "t0": clock, "T": float(weight.get("flash", 0.12)), "r": float(weight.get("flash_r", 16.0)) * art, "strength": 0.5})


## The residue key of a talent's impact: its own (vfx_talents.json
## residue.talent_residue: the spear's and the meteor's lava), else its element's.
func _residue_key(talent: String, element: String) -> String:
	return str(cfg.get("residue", {}).get("talent_residue", {}).get(talent, Pal.resolve(element)))


## A fire explosion at `at` (its floor point) reaching `size` art cells: the
## painted boom in pushes and, in the particles, sparks that bounce and lie as
## embers, a scorch star and soot (vfx_talents.json fire.boom); `k` 0..1 the
## weight between the smallest and the biggest (how many sparks).
func _boom(at: Vector2, dir: Vector2, size: int, clock: float, k: float) -> void:
	var spec: Dictionary = cfg.get("fire", {}).get("boom", {})
	_impacts.append({"at": at, "dir": dir, "element": "fire", "size": size, "t0": clock, "seed": _local_id(), "kind": "boom", "T": float(spec.get("time", 0.65))})
	if particles == null: return
	var s := to_particles
	var p := at * s
	var sparks: Array = spec.get("sparks", [8, 22])
	particles.ember_sparks(p, int(lerpf(float(sparks[0]), float(sparks[1]), clampf(k, 0.0, 1.0))), dir, 0.8 + 0.5 * k)
	particles.scorch_star(p, float(size) * art * s * float(spec.get("scorch", 0.7)))


## The matter of `element` bursting out of a hit at `at` along `dir` into the
## host's particles: `n` sparks, shards, drops, motes or chips (by the
## element's kind) within `r` world px, `cracks` floor cracks (fire scorches).
func _matter(at: Vector2, dir: Vector2, element: String, n: int, cracks: int, r: float) -> void:
	if particles == null: return
	var s := to_particles
	var p := at * s
	var cols := Pal.ramp(element)
	var hot := Pal.ramp_hot(element)
	match Pal.kind(element):
		"spark":
			particles.sparks(p, -dir, n, [cols[4], cols[3], cols[2]])
			if element == "fire":
				particles.flames(p, maxi(2, n / 2), [], r * s * 0.3, 2.0, -dir * 30.0)
				particles.embers(p, r * s * 0.4, maxi(2, n / 3))
				particles.ember_sparks(p, maxi(2, n / 3), -dir, 0.7)
				particles.stain(p, Color(str(particles.settings().get("ember", {}).get("soot", "1c1416"))), r * s * 0.35)
			else:
				particles.chips(p, maxi(2, n / 3), -dir, [cols[2], cols[3]])
		"shard":
			particles.shatter(p, n, -dir * 0.6, 150.0 + 6.0 * float(n), [] if element == "ice" else hot, 3)
			if element == "ice": particles.frost(p, r * s * 0.5, n, cols[3])
		"drop":
			particles.drops(p, n, -dir, [cols[2], cols[2], cols[3], cols[1]])
		"mote":
			if element == "void": particles.implode(p, r * s, [])
			else: particles.motes(p, n, [cols[3], cols[4], cols[2]])
		_:
			particles.chips(p, n, -dir, [cols[2], cols[1], cols[3]])
			particles.dust_flat(p, r * s * 0.5, maxi(2, n / 3))
	if cracks > 0:
		if element == "fire": particles.scorch_star(p, r * s * 0.6)
		else: particles.floor_crack(p, r * s * (0.8 + 0.4 * float(cracks)), cracks + 1)


## The physics of a burst over a hit radius `r` at `at` (novas, explosions,
## slams): the element's matter all round, heavier for an ultimate's, a
## meteor's `impact` breaking the floor; and its residue by share of `r`.
func _burst_physics(at: Vector2, r: float, element: String, heavy: bool, impact: bool, clock: float, talent := "") -> void:
	element = Pal.resolve(element)
	if particles != null:
		var s := to_particles
		var p := at * s
		var cols := Pal.ramp(element)
		var hot := Pal.ramp_hot(element)
		var n := clampi(int(r / art * 0.3), 6, 24 if heavy else 16)
		match Pal.kind(element):
			"spark":
				if element == "fire": particles.fire_burst(p, minf(r, _u(70.0)) * s)
				else:
					particles.sparks(p, Vector2.UP, n, [cols[4], cols[3], cols[2]])
					particles.chips(p, n / 2, Vector2.ZERO, [cols[2], cols[3]])
			"shard":
				particles.shatter(p, 18 if heavy else 10, Vector2.ZERO, minf(r * s * 1.4, 260.0), [] if element == "ice" else hot, 4 if heavy else 3)
				if element == "ice":
					particles.rime_grow(p, 7 if heavy else 5, r * s * (0.4 if heavy else 0.32))
					particles.freeze_liquids(p, r * s)
			"drop":
				particles.drops(p, n, Vector2.ZERO, [cols[2], cols[2], cols[3], cols[1]])
			"mote":
				if element == "void": particles.implode(p, minf(r, _u(80.0)) * s, [])
				else: particles.motes(p, n, [cols[3], cols[4], cols[2]])
			_:
				particles.rubble(p, n, Vector2.ZERO, 120.0 + r * s * 0.5)
				particles.dust_flat(p, r * s * 0.5, n / 2)
				if heavy: particles.floor_crack(p, r * s * 0.5, 4)
		if impact:
			particles.rubble(p, int(cfg.get("fire", {}).get("meteor", {}).get("chips", 14)), Vector2.ZERO, 200.0)
			particles.floor_crack(p, r * s * 0.6, 5)
	var key := _residue_key(talent, element)
	var spec: Dictionary = cfg.get("residue", {}).get(key, {})
	if not spec.is_empty():
		_leave(at, Vector2.ZERO, element, minf(float(spec.get("share", 0.3)) * r / art, float(spec.get("cap", 40))) * (1.3 if heavy else 1.0), clock, -1.0, key)


## RESIDUE: a small pool of the `element`'s material `cells` art cells round,
## landing at `at` along `dir`, lying `length` s (the residue table's when
## negative). Elements without a pool material leave settled chips only (the
## particles' work), nothing here.
func _leave(at: Vector2, dir: Vector2, element: String, cells: float, clock: float, length := -1.0, key := "") -> void:
	var spec: Dictionary = cfg.get("residue", {}).get(key if key != "" else Pal.resolve(element), {})
	if spec.is_empty() or pools == null: return
	var r := cells * art
	if r < art * 2.0: return
	var id := _local_id()
	var times: Array = spec.get("time", [1.5, 2.5])
	var t := length if length > 0.0 else lerpf(float(times[0]), float(times[1]), _h(id))
	_residue[id] = {"until": clock + t, "entry": {"id": id, "k": "pool", "st": str(spec.get("st", "poison")), "x": at.x, "y": at.y, "r": r, "dx": dir.x, "dy": dir.y, "p": 0.0, "L": t}}


## The residue pools still lying (expired ones go).
func _residue_entries(clock: float) -> Array:
	var out: Array = []
	for id: int in _residue.keys():
		if float(_residue[id].until) < clock: _residue.erase(id)
		else: out.append(_residue[id].entry)
	return out


# ---------- events ----------

## Effect layer: short events over everything, each played over its life
## (span), and the shots' impacts. `clock` defaults to the one of the last draw_ground.
func draw_events(canvas: CanvasItem, state: Dictionary, clock: float = -1.0) -> void:
	if clock >= 0.0: _clock = clock
	PerfMarks.begin()
	for guard: Dictionary in state.get("guards", []):
		_draw_guard(canvas, guard)
	for i in range(_impacts.size() - 1, -1, -1):
		var hit: Dictionary = _impacts[i]
		var k := (_clock - float(hit.t0)) / float(hit.get("T", IMPACT_TIME))
		if k >= 1.0 or k < 0.0:
			_impacts.remove_at(i)
			continue
		if str(hit.get("kind", "")) == "boom":
			TalentPixels.boom(canvas, hit.at, hit.dir, k, art, int(hit.size), int(hit.seed), cfg.get("fire", {}).get("boom", {}))
		else:
			TalentPixels.impact(canvas, hit.at, hit.dir, k, str(hit.element), art, int(hit.size), int(hit.seed))
	# chain targets burning (TalentPixels.flames round them for fire.chain.burn s)
	for i in range(_burning.size() - 1, -1, -1):
		var burn: Dictionary = _burning[i]
		var left := float(burn.until) - _clock
		if left <= 0.0:
			_burning.remove_at(i)
			continue
		TalentPixels.flames(canvas, burn.at, body, 0.7 * clampf(left / 0.25, 0.0, 1.0), "fire", art, _clock, int(burn.seed))
	PerfMarks.add("te.impacts")
	for event: Dictionary in state.get("events", []):
		var at := Vector2(float(event.x), float(event.y))
		var span := maxf(0.05, float(event.get("span", 0.5)))
		var p := 1.0 - clampf(float(event.life) / span, 0.0, 1.0)
		var fade := 1.0 - smoothstep(0.55, 1.0, p)
		var id := int(event.get("id", 0))
		var talent := str(event.get("talent", ""))
		var element := Pal.element_of(talent, str(event.get("fx", "steel")))
		var ult := bool(event.get("ult", false))
		var stage := int(event.get("stage", 0))
		var r := float(event.get("r", 0.0))
		match str(event.kind):
			"nova":
				# the exact hit radius as a shock ring; an ultimate's is heavier
				TalentPixels.nova(canvas, at, r, p, element, art, id, ult)
				if bool(event.get("wave", false)):
					TalentUlts.wave(canvas, talent, at, r, p, stage, art, _clock, id)
				elif talent == "berserk_3" and sprites.has("whirl"):
					sprites.draw_at(canvas, "whirl", at, p * TAU, r / 72.0, p, Color.WHITE, true, fade)
				_nova_extra(canvas, event, at, p, talent, element)
			"shout":
				TalentPixels.waves(canvas, at, r, p, "beast" if bool(event.get("pet", false)) else element, art, id)
			"blink", "dash", "leap":
				var to := Vector2(float(event.get("tx", at.x)), float(event.get("ty", at.y)))
				var kind := str(event.kind)
				TalentPixels.trail(canvas, at, to, p, element if kind == "blink" else ("beast" if kind == "leap" else element), art, id)
				match kind:
					"blink":
						TalentPixels.burst(canvas, at + body, 7, p, element, art, id)
						if talent == "fire_5": _phoenix(canvas, at, to, p, 1.0 - p)
						else: TalentPixels.burst(canvas, to + body, 9, p, element, art, id + 1)
					"dash":
						if talent == "beast_11": sprites.draw_at(canvas, "claw", to + body * 0.85, 0.0, 1.0, p, Color.WHITE, true, fade)
						else: sprites.draw_at(canvas, "slash", to, (to - at).angle(), 1.0, p, Color.WHITE, true, fade)
						TalentPixels.burst(canvas, at, 5, p, element, art, id)
					"leap":
						sprites.draw_at(canvas, "claw", to + body * 0.85, 0.0, 1.0, p, Color.WHITE, true, fade)
			"swing":
				if sprites.has("slash"):
					sprites.draw_at(canvas, "slash", at, float(event.get("angle", 0.0)), maxf(1.0, r / 52.0), p, Color.WHITE, true, fade)
				else:
					TalentPixels.nova(canvas, at, r, p, element, art, id)
			"crit":
				TalentPixels.burst(canvas, at + body * 1.15, 6, p, "gold", art, id)
				TalentPixels.text(canvas, at + body * 2.1 + Vector2(0, -7.0 * art * p), "KRIT", Pal.ramp("gold")[3], art, fade)
			"guard":
				# a wolf takes part of a blow: a short dome flash round the hero
				_flash_dome.draw(canvas, _snap(at) + feet, clampf(p * 4.0, 0.0, 1.0), fade, "gold", art, _clock)
			"parry":
				TalentPixels.burst(canvas, at + body, 7, p, "steel", art, id)
			"mark":
				TalentPixels.reticle(canvas, at + body * 1.6, p, 1.0 - smoothstep(0.85, 1.0, p), art, _clock)
			"trap":
				_sprung_trap(canvas, event, at, r, p, id)
			"echo":
				TalentPixels.nova(canvas, at, maxf(r, _u(26.0)), p, "void", art, id)
			"buff":
				_buff(canvas, str(event.get("buff", "")), at, p, id)
			"cast":
				var tier := _cast_tier(talent, ult)
				if ult:
					# the ultimate's own form and its stage layers (src/vfx/talent_ults.gd)
					TalentUlts.cast(canvas, talent, at, body, r, p, stage, float(event.get("angle", 0.0)), art, _clock, id, feet)
				elif talent == "frost_5":
					# Kristallschild: the lasting dome is its aura; here the frost it forms from
					TalentPixels.burst(canvas, at + body, 8, p, "ice", art, id)
				_gather(canvas, at, float(event.get("angle", 0.0)), p, span, element, tier, id)
			_:
				_extra_event(canvas, event, at, p, 1.0 - p)
		PerfMarks.add("te." + str(event.kind) + ("-ult" if ult else ""))


## CAST: the element gathering at the caster's hand (chest plus `hand` cells
## along the aim) over the cast tier's span, then its flash; `p` runs over the
## event's `span` s.
func _gather(canvas: CanvasItem, at: Vector2, angle: float, p: float, span: float, element: String, tier: String, seed: int) -> void:
	var c: Dictionary = cfg.get("cast", {})
	var window := float(c.get("span", {}).get(tier, 0.12)) * 1.6
	var k := p * span / maxf(0.05, window)
	if k >= 1.0: return
	var hand := at + body + Vector2.from_angle(angle) * float(c.get("hand", 5)) * art
	TalentPixels.gather(canvas, hand, k, element, art, int(c.get("cells", {}).get(tier, 8)), float(c.get("reach", {}).get(tier, 8)), int(c.get("flash", {}).get(tier, 4)), seed)


## A trap going off: the trap itself springing and thinning away, its burst
## in its matter (the iron trap's fire with the hit ring, the thorns' poison,
## the net's rope) over the event.
func _sprung_trap(canvas: CanvasItem, event: Dictionary, at: Vector2, r: float, p: float, id: int) -> void:
	var kind := _trap_kind(event)
	var traps: Dictionary = cfg.get("traps", {})
	var spring := clampf(p / float(traps.get("spring", 0.45)), 0.0, 1.0)
	if spring < 1.0:
		TalentPixels.trap(canvas, at, kind, float(traps.get("radius", {}).get(kind, 7)), float(traps.get("pulse", {}).get(kind, 1.0)), art, _clock, id, spring)
	match kind:
		"iron":
			TalentPixels.nova(canvas, at, r, p, "fire", art, id)
			TalentPixels.impact(canvas, at, Vector2.ZERO, p, "fire", art, int(clampf(r / art * 0.4, 6.0, 14.0)), id)
		"thorn":
			TalentPixels.impact(canvas, at, Vector2.ZERO, p, "poison", art, 6, id)
		_:
			TalentPixels.burst(canvas, at, 7, p, "beast", art, id)


## The flash of a buff when it starts (the buff itself lasts as an aura).
func _buff(canvas: CanvasItem, buff: String, at: Vector2, p: float, id: int) -> void:
	match buff:
		"frenzy": TalentPixels.burst(canvas, at + body, 8, p, "blood", art, id)
		"bloodlust": TalentPixels.nova(canvas, at, _u(70.0), p, "blood", art, id, true)
		"bulwark", "oath": TalentPixels.burst(canvas, at + body, 8, p, str(BUFF_ELEMENT[buff]), art, id)
		"unbreakable": TalentPixels.nova(canvas, at, _u(80.0), p, "stone", art, id, true)
		"timebreak": TalentPixels.nova(canvas, at, _u(90.0), p, "void", art, id, true)
		_: TalentPixels.burst(canvas, at + body, 8, p, "gold", art, id)


# ---------- auras ----------

## Over the actors: what lasts on each hero (snapshot "auras": buffs, shields,
## channels), round where.call(owner) (his ground point; a non-finite point
## skips him). Shields and rage pop in and dither out at their end.
func draw_auras(canvas: CanvasItem, state: Dictionary, clock: float, where: Callable) -> void:
	_draw_domes(canvas, state.get("auras", []), clock, where)
	for aura: Dictionary in state.get("auras", []):
		var at: Vector2 = where.call(int(aura.get("owner", 1)))
		if not at.is_finite(): continue
		at = _snap(at)
		var left := float(aura.get("left", 0.0))
		var total := maxf(0.05, float(aura.get("total", left)))
		var stage := int(aura.get("stage", 0))
		var grow := clampf((total - left) / 0.3, 0.0, 1.0)
		var fade := clampf(left / 0.6, 0.0, 1.0)
		var kind := str(aura.get("kind", ""))
		var owner := int(aura.get("owner", 1))
		match kind:
			"unbreakable":
				TalentUlts.aura(canvas, kind, at, body, left, total, stage, art, clock, {}, feet)
			"frenzy":
				TalentPixels.flames(canvas, at, body, 0.6 * fade * grow, "blood", art, clock, owner)
			"bloodlust":
				TalentPixels.flames(canvas, at, body, fade * grow, "blood", art, clock, owner)
				TalentUlts.aura(canvas, kind, at, body, left, total, stage, art, clock, {}, feet)
			"timebreak":
				TalentUlts.aura(canvas, kind, at, body, left, total, stage, art, clock, {}, feet)
			"channel":
				if str(aura.get("talent", "")) in ["blade_6", "blade_14"]:
					TalentUlts.aura(canvas, "blade_dance", at, body, left, total, stage, art, clock, {"radius": float(aura.get("radius", _u(128.0)))}, feet)


## One rubber dome per shielded hero (the biggest of his shields), run and
## drawn standing on his feet; it pops in, gives where blows land and dithers
## out at its end. Heroes without a shield lose theirs.
func _draw_domes(canvas: CanvasItem, auras: Array, clock: float, where: Callable) -> void:
	var shown := {}
	for spec: Array in DOMES:
		for aura: Dictionary in auras:
			var owner := int(aura.get("owner", 1))
			if shown.has(owner) or str(aura.get("kind", "")) != str(spec[0]): continue
			var at: Vector2 = where.call(owner)
			if not at.is_finite(): continue
			shown[owner] = true
			var left := float(aura.get("left", 0.0))
			var total := maxf(0.05, float(aura.get("total", left)))
			var dome: RefCounted = _dome(owner)
			dome.size = int(spec[1])
			dome.step(clock)
			dome.draw(canvas, _snap(at) + feet, clampf((total - left) / 0.3, 0.0, 1.0), clampf(left / 0.6, 0.0, 1.0), str(spec[2]), art, clock)
	for owner: int in _domes.keys():
		if not shown.has(owner): _domes.erase(owner)


## Bloom (the host's additive glow layer, `level` its strength): the flashes
## of weighty events in their element's colour, the shots in flight and their
## impacts, and a faint light of the lasting buffs; small, never a white-hot core.
func draw_glow(canvas: CanvasItem, state: Dictionary, level: float, clock: float, where: Callable) -> void:
	if level <= 0.0: return
	for i in range(_flashes.size() - 1, -1, -1):
		var flash: Dictionary = _flashes[i]
		var k := (clock - float(flash.t0)) / maxf(0.01, float(flash.T))
		if k >= 1.0 or k < 0.0:
			_flashes.remove_at(i)
			continue
		Glow.dot(canvas, flash.at, float(flash.r) * (0.7 + 0.3 * k), Color(flash.col, float(flash.strength) * (1.0 - k) * (1.0 - k) * level))
	for shot: Dictionary in (_shots_pass if not _shots_pass.is_empty() else _shots_live):
		Glow.dot(canvas, shot.at, float(shot.glow) * art, Color(Pal.ramp(str(shot.element))[3], 0.3 * level))
	for hit: Dictionary in _impacts:
		var k := (clock - float(hit.t0)) / float(hit.get("T", IMPACT_TIME))
		if str(hit.get("kind", "")) == "boom" and k < 0.2:
			# the explosion's white flash lights the floor
			Glow.dot(canvas, hit.at, float(hit.size) * art * 2.6, Color(Pal.ramp("fire")[4], 0.7 * (1.0 - k * 5.0) * level))
		if k < 0.5: Glow.dot(canvas, hit.at, float(hit.size) * art * 1.5, Color(Pal.ramp(str(hit.element))[3], 0.4 * (1.0 - k * 2.0) * level))
	var strengths: Dictionary = cfg.get("aura_glow", {})
	for aura: Dictionary in state.get("auras", []):
		var kind := str(aura.get("kind", ""))
		var strength := float(strengths.get(kind, 0.0))
		if strength <= 0.0: continue
		var at: Vector2 = where.call(int(aura.get("owner", 1)))
		if not at.is_finite(): continue
		var fade := clampf(float(aura.get("left", 0.0)) / 0.6, 0.0, 1.0)
		var colour: Color = Pal.ramp(str(BUFF_ELEMENT.get(kind, "steel")))[3]
		Glow.dot(canvas, at + body, 18.0 * art, Color(colour, strength * fade * level))


# ---------- weight and first sight ----------

## The tier of an event's weight ("" for none): an ultimate's cast and its
## waves weigh most (its own nova or buff in the same moment adds nothing).
func _tier(event: Dictionary) -> String:
	var kind := str(event.get("kind", ""))
	if bool(event.get("ult", false)):
		if kind == "cast": return str(cfg.get("ult_cast", "huge"))
		if bool(event.get("impact", false)): return str(cfg.get("ult_impact", cfg.get("ult_wave", "large")))
		if bool(event.get("wave", false)): return str(cfg.get("ult_wave", "large"))
		return ""
	var events: Dictionary = cfg.get("events", {})
	if kind == "trap": return str(events.get("trap_boom", "")) if bool(event.get("boom", false)) else ""
	return str(events.get(kind, ""))


func _boost(event: Dictionary) -> float:
	return 1.0 + float(cfg.get("stage_bonus", 0.0)) * float(event.get("stage", 0))


## First sight of each event: its bloom flash, the pool an ultimate leaves and
## the physics of its matter (particles, residue); and the residue of the
## zones that ended since the last frame.
func _observe(state: Dictionary, clock: float) -> void:
	var now := {}
	for event: Dictionary in state.get("events", []):
		var id := int(event.get("id", 0))
		now[id] = true
		if _seen.has(id): continue
		var tier := _tier(event)
		var talent := str(event.get("talent", ""))
		var element := Pal.element_of(talent, str(event.get("fx", "steel")))
		var at := Vector2(float(event.x), float(event.y))
		var r := float(event.get("r", 0.0))
		var kind := str(event.get("kind", ""))
		if tier != "":
			var spec: Dictionary = cfg.get("tiers", {}).get(tier, {})
			_flashes.append({"at": at + body, "col": Pal.ramp(element)[3], "t0": clock,
				"T": float(spec.get("flash", 0.15)) * _boost(event), "r": float(spec.get("flash_r", 20.0)) * art * _boost(event), "strength": 0.5})
		if bool(event.get("ult", false)): _ult_pool(event, state, clock)
		match kind:
			"nova":
				if bool(event.get("impact", false)):
					# the meteor's landing: the huge boom, rock and lava
					var me: Dictionary = cfg.get("fire", {}).get("meteor", {})
					var size: Array = me.get("size", [12, 24])
					_boom(at, Vector2.ZERO, int(clampf(r / art * float(me.get("size_share", 0.4)), float(size[0]), float(size[1]))), clock, 1.0)
				_burst_physics(at, r, element, bool(event.get("ult", false)), bool(event.get("impact", false)), clock, talent)
			"explosion":
				# the Feuerball's splash: the fat explosion over the hit radius
				var bo: Dictionary = cfg.get("fire", {}).get("boom", {})
				var size: Array = bo.get("size", [8, 16])
				_boom(at, Vector2.ZERO, int(clampf(r / art * float(bo.get("size_share", 0.5)), float(size[0]), float(size[1]))), clock, 0.6)
				_burst_physics(at, r, "fire", false, false, clock, talent)
			"chain":
				# every link's hit: sparks off the target, and it burns for a while
				var ch: Dictionary = cfg.get("fire", {}).get("chain", {})
				var points: Array = event.get("points", [])
				for i in range(1, points.size()):
					var hit := Vector2(float(points[i][0]), float(points[i][1]))
					var prev := Vector2(float(points[i - 1][0]), float(points[i - 1][1]))
					_matter(hit + body, (hit - prev).normalized() if hit != prev else Vector2.UP, element, int(ch.get("sparks", 6)), 0, _u(12.0))
					_burning.append({"at": hit, "until": clock + float(ch.get("burn", 0.6)), "seed": id + i})
			"trap":
				match _trap_kind(event):
					"iron": _burst_physics(at, r, "fire", false, false, clock)
					"thorn":
						_matter(at, Vector2.ZERO, "poison", 10, 0, _u(14.0))
						_leave(at, Vector2.ZERO, "poison", float(cfg.get("residue", {}).get("poison", {}).get("cells", [4, 10])[0]), clock)
					_: _matter(at, Vector2.ZERO, "beast", 8, 0, _u(14.0))
			"blink":
				_blink_physics(at, Vector2(float(event.get("tx", at.x)), float(event.get("ty", at.y))), element, talent, clock)
			"dash":
				var to := Vector2(float(event.get("tx", at.x)), float(event.get("ty", at.y)))
				_matter(at, (to - at).normalized() if to != at else Vector2.ZERO, element, 5, 0, _u(16.0))
			"leap_slam":
				_burst_physics(Vector2(float(event.get("tx", at.x)), float(event.get("ty", at.y))), r, "stone", true, false, clock)
			"parry":
				_matter(at + body, Vector2.UP, "steel", 5, 0, _u(10.0))
			"crit":
				_matter(at + body, Vector2.UP, "gold", 4, 0, _u(10.0))
			"pet_strike":
				var wound := str(event.get("wound", ""))
				if wound == "burn": _matter(at, Vector2.ZERO, "fire", 5, 0, _u(12.0))
				elif wound == "blood":
					_matter(at, Vector2.ZERO, "blood", 6, 0, _u(12.0))
					_leave(at, Vector2.ZERO, "blood", float(cfg.get("residue", {}).get("blood", {}).get("cells", [3, 8])[0]), clock)
			"block_break":
				_matter(at + body, Vector2.UP, str(LOOK_ELEMENT.get(str(event.get("look", "")), "ice")), 8, 0, _u(14.0))
			"pet_fell":
				_matter(at, Vector2.UP, "ice" if str(event.get("kind", "")) == "water_elemental" else "bone", 6, 0, _u(12.0))
			"dome_hit":
				# the blow dents the hero's dome on the side it came from
				_dome(int(event.get("owner", 1))).hit(Vector2(float(event.get("dx", 0.0)), float(event.get("dy", 1.0))), float(event.get("power", 1.0)), clock)
	_seen = now
	_zone_residue(state.get("zones", []), clock)


## A blink's matter where the hero vanished: smoke for the Rauchsprung and the
## Rückwärtssalto, shadow for the Schattenschritt, else the element's own
## small burst; fire, ice and the void leave a little of themselves there.
func _blink_physics(at: Vector2, to: Vector2, element: String, talent: String, clock: float) -> void:
	if talent == "fire_5":
		# Phönixschritt: a trail of fire pools along the dash, burning for a while
		var ph: Dictionary = cfg.get("fire", {}).get("phoenix", {})
		var every := _u(float(ph.get("trail_every", 14)))
		var n := maxi(1, int(at.distance_to(to) / maxf(1.0, every)))
		for i in range(n + 1):
			_leave(at.lerp(to, float(i) / float(n)), (to - at).normalized() if to != at else Vector2.ZERO, "fire", float(ph.get("trail_cells", 5)), clock, float(ph.get("trail", 1.5)))
		_matter(to, Vector2.ZERO, "fire", 8, 0, _u(16.0))
	if particles != null:
		var s := to_particles
		var p := at * s
		match talent:
			"trapper_11", "sniper_9": particles.smoke(p, 8, _u(12.0) * s)
			"blade_11", "curse_11": particles.shadow(p, 3, _u(26.0) * s)
			_:
				if element == "void": particles.implode(p, _u(30.0) * s, [])
				else: _matter(at, Vector2.ZERO, element, 7, 0, _u(14.0))
	if Pal.resolve(element) in ["fire", "ice", "void"]:
		_leave(at, Vector2.ZERO, element, float(cfg.get("residue", {}).get(Pal.resolve(element), {}).get("cells", [4, 9])[0]), clock)


## The element of a zone's residue: burning ground fire, the looks their
## element (ice and snow, the void, lava and flames, the plague's poison, the
## souls), a plain zone poison; "" for none (Pfeilhagel).
func _zone_element(zone: Dictionary) -> String:
	if str(zone.get("status", "")) == "burn": return "fire"
	var look := str(zone.get("look", ""))
	if look == "arrows": return ""
	if look == "": return "poison" if (zone.get("path", []) as Array).is_empty() else "fire"
	var named := Pal.resolve(look)
	return named if Pal.RAMPS.has(named) else ""


## RESIDUE of the zones that ended since the last frame: a pool of their
## element by share of their radius (zone_time s); a drawn line leaves one
## every path_every points.
func _zone_residue(zones: Array, clock: float) -> void:
	var now := {}
	for zone: Dictionary in zones: now[int(zone.get("id", 0))] = zone
	var table: Dictionary = cfg.get("residue", {})
	var times: Array = table.get("zone_time", [2.0, 4.0])
	for id: int in _zones_seen:
		if now.has(id): continue
		var zone: Dictionary = _zones_seen[id]
		var element := _zone_element(zone)
		if element == "": continue
		var key := _residue_key(str(zone.get("talent", "")), element)
		if not table.has(key): continue
		var spec: Dictionary = table[key]
		var length := lerpf(float(times[0]), float(times[1]), _h(id))
		var path: Array = zone.get("path", [])
		if path.is_empty():
			_leave(Vector2(float(zone.x), float(zone.y)), Vector2.ZERO, element, minf(float(spec.get("share", 0.3)) * float(zone.r) / art, float(spec.get("cap", 40))), clock, length, key)
		elif str(zone.get("look", "")) == "flames":
			# the Flammenmeer has burnt down: embers that die to soot and ash along the stroke
			if particles != null:
				for i in range(0, path.size(), 2):
					var at := Vector2(float(path[i][0]), float(path[i][1])) * to_particles
					particles.embers(at, float(zone.get("w", 18.0)) * 0.6 * to_particles, 3)
					particles.scatter(at, TalentPixels.ASH[1], float(zone.get("w", 18.0)) * 0.7 * to_particles, 3)
		else:
			var every := maxi(1, int(table.get("path_every", 3)))
			for i in range(0, path.size(), every):
				_leave(Vector2(float(path[i][0]), float(path[i][1])), Vector2.ZERO, element, float(zone.get("w", 18.0)) * 0.8 / art, clock, length, key)
	_zones_seen = now


## The pool an ultimate leaves where it struck (assets/data/vfx_talents.json "pools";
## legacy: the renumbered ultimates leave theirs through the residue table).
func _ult_pool(event: Dictionary, state: Dictionary, clock: float) -> void:
	var wave := bool(event.get("wave", false))
	if str(event.get("kind", "")) != ("nova" if wave else "cast"): return
	var talent := str(event.get("talent", ""))
	var spec: Variant = cfg.get("pools", {}).get(talent + ("_wave" if wave else ""), {})
	if not spec is Dictionary or spec.is_empty(): return
	var r := float(event.get("r", 0.0)) * float(spec.share) if spec.has("share") else float(spec.get("cells", 12)) * art
	var length := float(spec.get("time", 3.0))
	if int(event.get("stage", 0)) >= 2 and spec.has("time_stage2"): length = float(spec.time_stage2)
	if length <= 0.0:
		# as long as the ultimate's buff on its hero
		length = 4.0
		for aura: Dictionary in state.get("auras", []):
			if int(aura.get("owner", -1)) == int(event.get("owner", -2)) and str(aura.get("talent", "")) == talent: length = float(aura.get("total", length))
	if r < art * 2.0: return
	var id := int(event.get("id", 0))
	_ult_pools[id] = {"until": clock + length, "entry": {"id": id, "k": "pool", "st": str(spec.get("st", "blood")), "x": float(event.x), "y": float(event.y), "r": r, "p": 0.0, "L": length}}


## The weight of the events seen for the first time ({owner (-1 unknown),
## trauma, shake_px, hitstop}) by importance (assets/data/vfx_talents.json),
## each event once, and of the shots' impacts since the last call. The host
## shakes its view and holds the picture for its own hero.
func take_feel(state: Dictionary) -> Array:
	var out: Array = _pending_feel
	_pending_feel = []
	var now := {}
	for event: Dictionary in state.get("events", []):
		var id := int(event.get("id", 0))
		now[id] = true
		if _felt.has(id): continue
		var tier := _tier(event)
		if tier == "": continue
		var spec: Dictionary = cfg.get("tiers", {}).get(tier, {})
		out.append({"owner": int(event.get("owner", -1)), "trauma": float(spec.get("trauma", 0.0)) * _boost(event),
			"shake_px": float(spec.get("shake_px", 0.0)) * _boost(event), "hitstop": float(spec.get("hitstop", 0.0))})
	_felt = now
	return out

## A zone with a look of its own (drawn by _draw_looks, not as a pool or gas).
func _own_look(zone: Dictionary) -> bool:
	return str(zone.get("look", "")) in LOOKS or not (zone.get("path", []) as Array).is_empty()


# ---------- zone looks ----------

## The zone looks of the talents and ultimates: the drawn Flammenmeer, ice,
## the whirl, snow, Pfeilhagel, the meteor's crater, souls and plague.
func _draw_looks(canvas: CanvasItem, zones: Array, clock: float) -> void:
	for zone: Dictionary in zones:
		if not _own_look(zone): continue
		var at := Vector2(float(zone.x), float(zone.y))
		var r := float(zone.r)
		match str(zone.get("look", "")):
			"flames":
				# Flammenmeer: real fire pools along the stroke (draw_ground), an ember
				# core with pixel tongues over them, burning down to ash at the end
				var fm: Dictionary = cfg.get("fire", {}).get("flammenmeer", {})
				var burn := 1.0 - clampf(float(zone.get("time", 1.0)) / maxf(0.1, float(fm.get("ash", 0.8))), 0.0, 1.0)
				TalentPixels.fire_line(canvas, zone.get("path", []), float(zone.get("w", 18.0)), art, clock, int(zone.get("id", 0)), burn, fm.get("tongue", [3, 5]), float(fm.get("every", 8)))
			"firewall":
				# Flammenwall: the same fire along its line, taller
				var fm: Dictionary = cfg.get("fire", {}).get("flammenmeer", {})
				var burn := 1.0 - clampf(float(zone.get("time", 1.0)) / maxf(0.1, float(fm.get("ash", 0.8))), 0.0, 1.0)
				var tongue: Array = fm.get("tongue", [3, 5])
				var line: Array = [[float(zone.get("ax", at.x)), float(zone.get("ay", at.y))], [float(zone.get("bx", at.x)), float(zone.get("by", at.y))]]
				TalentPixels.fire_line(canvas, line, float(zone.get("w", 18.0)), art, clock, int(zone.get("id", 0)), burn, [float(tongue[0]) + 2.0, float(tongue[1]) + 3.0], float(fm.get("every", 8)))
			"lava":
				# Lavafeld: a pool of magma with flames licking up here and there
				sprites.draw_loop(canvas, "lava_pool", at, 0.0, r / 64.0, clock)
				for i in range(4):
					var spot := at + Vector2.from_angle(TAU * i / 4.0 + 0.6) * r * 0.45
					sprites.draw_loop(canvas, "flame_tongue", spot, 0.0, 0.7, clock + i * 0.4)
			"ice":
				# Gletschergrab: frozen ground with crystal clusters, the middle the tallest
				canvas.draw_circle(at, r, Color(0.55, 0.85, 1.0, 0.16))
				canvas.draw_arc(at, r, 0.0, TAU, 48, Color(0.8, 0.95, 1.0, 0.45), 2.0)
				for i in range(7):
					var spot := at + Vector2.from_angle(TAU * i / 7.0 + 0.4) * r * 0.62
					sprites.draw_loop(canvas, "ice_block", spot, 0.0, 0.55, clock + i * 0.21)
				sprites.draw_loop(canvas, "ice_block", at + Vector2(0, 10), 0.0, 1.0, clock)
			"arcane":
				# Singularität: the whirl turns over a dark disc, motes stream inwards
				canvas.draw_circle(at, r, Color(0.25, 0.12, 0.45, 0.22))
				sprites.draw_loop(canvas, "vortex", at, -clock * 2.5, clampf(r / 64.0, 0.6, 2.2), clock)
				for i in range(10):
					var k := fmod(clock * 0.8 + i * 0.1, 1.0)
					var mote := at + Vector2.from_angle(i * 2.4 + clock) * r * (1.0 - k)
					canvas.draw_rect(Rect2(mote - Vector2(1.5, 1.5), Vector2(3, 3)), Color(0.85, 0.75, 1.0, k))
			"snow":
				# Blizzard: a cold haze with snow driving across it
				canvas.draw_circle(at, r, Color(0.7, 0.9, 1.0, 0.14))
				for i in range(6):
					var spot := at + Vector2.from_angle(TAU * i / 6.0) * r * 0.5
					sprites.draw_loop(canvas, "snowfall", spot, 0.0, clampf(r / 40.0, 0.8, 2.0), clock + i * 0.17)
				sprites.draw_loop(canvas, "snowfall", at, 0.0, clampf(r / 40.0, 0.8, 2.0), clock)
			"arrows":
				# Pfeilhagel: the field darkens under the volley, big arrows plunge in all
				# over it and every one strikes with dust, splinters and a quivering shaft
				canvas.draw_circle(at, r, Color(0.1, 0.08, 0.06, 0.18))
				canvas.draw_arc(at, r, 0.0, TAU, 48, Color(0.95, 0.85, 0.6, 0.45), 2.0)
				var count := clampi(int(r / 7.0), 10, 24)
				for i in range(count):
					var cycle := clock * 1.6 + float(i) / count * 3.0
					var round_index := floori(cycle)
					var u := cycle - float(round_index)
					var seed_value := absi(hash(Vector3i(i, round_index, int(zone.get("id", 0)))))
					var spot := at + Vector2.from_angle(float(seed_value % 628) / 100.0) * r * sqrt(float((seed_value / 628) % 100) / 100.0) * 0.92
					if u < 0.3: sprites.draw_loop(canvas, "hail_arrow", spot + Vector2(18, -150) * (1.0 - u / 0.3), 0.12, 1.0, clock + i * 0.1)
					else: sprites.draw_at(canvas, "arrow_impact", spot, 0.0, 1.0, (u - 0.3) / 0.7)
			"crater":
				# the meteor's crater: a lava pool (draw_ground) with glowing cracks,
				# tongues and rising embers over it, cooling towards its end
				var left := float(zone.get("time", 1.0))
				var total := maxf(0.3, float(zone.get("total", left)))
				TalentPixels.crater(canvas, at, r, clampf(left / 1.0, 0.0, 1.0) * clampf((total - left) / 0.2, 0.0, 1.0), art, clock, int(zone.get("id", 0)))
			"souls":
				# Seelensturm: souls circle the field
				canvas.draw_circle(at, r, Color(0.45, 0.2, 0.7, 0.14))
				for i in range(8):
					var spot := at + Vector2.from_angle(TAU * i / 8.0 + clock * 1.6) * r * (0.45 + 0.35 * sin(clock + i))
					sprites.draw_loop(canvas, "soul_wisp", spot, 0.0, 1.1, clock + i * 0.2)
			"plague":
				# Seuchengrube: sickly green-violet clouds over bubbling ground
				canvas.draw_circle(at, r, Color(0.35, 0.6, 0.2, 0.16))
				if sprites.has("poison_cloud"):
					for i in range(7):
						var spot := at + Vector2.from_angle(TAU * i / 7.0 + clock * 0.1) * r * (0.2 + 0.5 * float(i % 3) / 2.0)
						sprites.draw_loop(canvas, "poison_cloud", spot, 0.0, clampf(r / 90.0, 0.6, 1.3), clock + i * 0.3, Color(0.85, 0.7, 1.0))


## Mana on the ground: a small glowing orb, a boss's potion as the 0x72 blue flask.
func _draw_orbs(canvas: CanvasItem, state: Dictionary, clock: float) -> void:
	for orb: Dictionary in state.get("orbs", []):
		var at := Vector2(float(orb.x), float(orb.y))
		var bob := sin(clock * 4.0 + float(orb.id)) * 2.0
		var fade := clampf(float(orb.get("life", 5.0)) / 3.0, 0.25, 1.0)
		canvas.draw_circle(at + Vector2(0, 4), 7.0, Color(0, 0, 0, 0.3 * fade))
		if bool(orb.get("potion", false)) and _flask() != null:
			canvas.draw_circle(at - Vector2(0, 10 - bob), 15.0, Color(0.35, 0.55, 1.0, 0.18 * fade))
			canvas.draw_texture_rect(_flask(), Rect2(at - Vector2(16, 30 - bob), Vector2(32, 32)), false, Color(1, 1, 1, fade))
			continue
		var c := at - Vector2(0, 8 - bob)
		canvas.draw_circle(c, 9.0, Color(0.3, 0.5, 1.0, 0.2 * fade))
		canvas.draw_circle(c, 5.0, Color(0.32, 0.55, 1.0, fade))
		canvas.draw_circle(c, 3.0, Color(0.62, 0.8, 1.0, fade))
		canvas.draw_rect(Rect2(c + Vector2(-2, -3), Vector2(2, 2)), Color(1, 1, 1, fade))


## A line of fire being drawn (Flammenmeer while its key is held): the
## ember trail along the points so far and, at its tip, fire gathering in the
## hand and the fill bar of the length still left.
func _draw_line_preview(canvas: CanvasItem, drawing: Dictionary, clock: float) -> void:
	var points: Array = drawing.get("points", [])
	if points.is_empty(): return
	var fm: Dictionary = cfg.get("fire", {}).get("flammenmeer", {})
	TalentPixels.fire_line(canvas, points, art, art, clock, int(drawing.get("owner", 1)), 0.0, fm.get("tongue", [3, 5]), float(fm.get("every", 8)), true)
	var tip := Vector2(float(points[-1][0]), float(points[-1][1]))
	TalentPixels.gather(canvas, tip, fmod(clock * 2.5, 1.0), "fire", art, 8, 8.0, 3, 7)
	var share := clampf(float(drawing.get("left", 0.0)) / maxf(1.0, float(drawing.get("max", 1.0))), 0.0, 1.0)
	var bar := Rect2((tip + Vector2(-22, -34)).round(), Vector2(44, 6))
	canvas.draw_rect(bar.grow(1), INK)
	canvas.draw_rect(Rect2(bar.position, Vector2(roundf(bar.size.x * share), bar.size.y)), Color("ff8a2a") if share > 0.25 else Color("e2584a"))
	canvas.draw_rect(Rect2(bar.position, Vector2(roundf(bar.size.x * share), 2)), Color("ffd060"))


## The mage's left-click (crypt and Hölle): a small fireball in the shot
## language, a hot core with embers peeling off its tail (its impact is the host's).
func draw_basic_fireball(canvas: CanvasItem, at: Vector2, velocity: Vector2, clock: float) -> void:
	var aim := velocity.normalized() if velocity.length() > 0.1 else Vector2.RIGHT
	var tier := _shot_tier("small")
	TalentPixels.shot(canvas, _snap(at), aim, "fire", art, int(tier.get("core", 1)), int(tier.get("trail", 5)), clock, 7)


func _flask() -> Texture2D:
	if _flask_texture == null and ResourceLoader.exists("res://assets/sprites/0x72/flask_big_blue.png"):
		_flask_texture = load("res://assets/sprites/0x72/flask_big_blue.png")
	return _flask_texture


## A raised block (Shift): its bubble around the hero with one pip per hit
## left; a dodge: a faint shimmer while untouchable.
func _draw_guard(canvas: CanvasItem, guard: Dictionary) -> void:
	var at := Vector2(float(guard.x), float(guard.y)) - Vector2(0, 16)
	if bool(guard.get("dodge", false)):
		canvas.draw_circle(at, 18.0, Color(0.8, 1.0, 0.8, 0.12))
		return
	var look := str(guard.get("look", "mana_bubble"))
	var ticks := Time.get_ticks_msec() / 1000.0
	var whole := float(guard.get("left", 1.0)) >= float(guard.get("max", 1.0))
	if sprites.has(look): sprites.draw_loop(canvas, look, at, 0.0, 1.1, ticks, Color(1, 1, 1, 0.9 if whole else 0.6))
	else: canvas.draw_arc(at, 26.0, 0.0, TAU, 32, Color(0.6, 0.8, 1.0, 0.8), 3.0)
	if not whole:
		# cracks across a block that already took a hit
		for i in range(3):
			var a := Vector2.from_angle(1.0 + i * 2.1) * 22.0
			canvas.draw_line(at + a * 0.2, at + a, Color(1, 1, 1, 0.75), 1.0)
	var count := int(guard.get("max", 2))
	for i in range(count):
		var pip := Rect2((at + Vector2(-count * 4.0 + i * 8.0 + 1.0, -34)).round(), Vector2(6, 4))
		canvas.draw_rect(pip.grow(1), INK)
		canvas.draw_rect(pip, Color("8fd6ff") if i < int(floorf(float(guard.get("left", 0.0)))) else Color(0.25, 0.25, 0.3))


## Phönixschritt: a bird of flame flies the way, a trail of embers behind it,
## fire bursting where it left and where it lands.
func _phoenix(canvas: CanvasItem, at: Vector2, to: Vector2, p: float, fade: float) -> void:
	var flight := minf(1.0, p * 1.3)
	var bird := at.lerp(to, flight) - Vector2(0, 22)
	var fire := Pal.ramp("fire")
	for k in range(6):
		var ember := at.lerp(to, maxf(0.0, flight - k * 0.06)) - Vector2(0, 22 - k * 2)
		var q := PixelPaint.at(ember, art)
		if PixelPaint.shown(q, fade * (1.0 - k / 6.0)):
			PixelPaint.cell(canvas, q, fire[3] if k < 2 else fire[2], art)
	if flight < 1.0: sprites.draw_loop(canvas, "phoenix", bird, (to - at).angle(), 1.8, p * 2.0)
	# ember wings where he left and where he lands
	var span := int(cfg.get("fire", {}).get("phoenix", {}).get("wings", 9))
	TalentPixels.wings(canvas, at + body, span, clampf(p * 3.0, 0.0, 1.0), 1.0 - smoothstep(0.2, 0.6, p), art, _clock, 11)
	TalentPixels.burst(canvas, at + body, 6, p, "fire", art, 11)
	if flight >= 0.85:
		var land := (flight - 0.85) / 0.15
		TalentPixels.wings(canvas, to + body, span, land, fade, art, _clock, 12)
		TalentPixels.burst(canvas, to + body, 9, (flight - 0.9) * 4.0 + p * 0.5, "fire", art, 12)


## The painted impact over a nova: the meteor's landing (a flash over the
## field, fire and rock bursting), the shower's small meteors and, for every
## other talent's nova, its element bursting out of the middle.
func _nova_extra(canvas: CanvasItem, event: Dictionary, at: Vector2, p: float, talent: String, element: String) -> void:
	var r := float(event.get("r", 0.0))
	var id := int(event.get("id", 0))
	if bool(event.get("impact", false)):
		# the meteor's landing: the fire is the boom in _impacts (first sight); here the rock
		if p < 0.08: PixelPaint.disc(canvas, at, r * 1.2, r * 0.9, Pal.ramp("fire")[4], art, (0.08 - p) / 0.08 * 0.6)
		TalentPixels.impact(canvas, at, Vector2.ZERO, p * 0.8, "stone", art, int(clampf(r / art * 0.25, 6.0, 14.0)), id + 1)
	elif talent == "fire_14":
		TalentPixels.impact(canvas, at, Vector2.ZERO, p, "fire", art, int(clampf(r / art * 0.4, 6.0, 12.0)), id)
	elif r > 0.0 and not bool(event.get("wave", false)):
		TalentPixels.impact(canvas, at, Vector2.ZERO, p, element, art, int(clampf(r / art * 0.25, 4.0, 10.0)), id)


## The events of the newer talents (src/combat/talent_combat.gd): companions'
## shots, strikes and dives, the meteor's fall, chain, explosion, spear, net,
## Erdspalter, souls, Pfeilhagel's last volley, dodge and block, "Wenig Mana".
func _extra_event(canvas: CanvasItem, event: Dictionary, at: Vector2, p: float, fade: float) -> void:
	var id := int(event.get("id", 0))
	var r := float(event.get("r", 0.0))
	match str(event.kind):
		"shield":
			_flash_dome.draw(canvas, _snap(at) + feet, clampf(p * 4.0, 0.0, 1.0), fade, "ice", art, _clock)
		"pet_bolt", "pet_lance":
			# the companion's shot flies to its target over the event's first half
			var lance := str(event.kind) == "pet_lance"
			var to := Vector2(float(event.get("tx", at.x)), float(event.get("ty", at.y))) - Vector2(0, 14)
			var from := at - Vector2(0, 20)
			var flight := clampf(p * 2.0, 0.0, 1.0)
			var spot := from.lerp(to, flight)
			if flight < 1.0: TalentPixels.shot(canvas, _snap(spot), to - from, "ice" if lance else "void", art, 1, 4, _clock, id)
			else: TalentPixels.burst(canvas, to, 5, (p - 0.5) * 2.0, "ice" if lance else "void", art, id)
		"no_res":
			# "Wenig Mana" rises over the hero and fades
			var tint: Color = {"mana": Color("7fb0ff"), "stamina": Color("9fe07a"), "rage": Color("ff7a5a")}.get(str(event.get("res", "mana")), Color.WHITE)
			var label := str(event.get("text", ""))
			var font := ThemeDB.fallback_font
			var spot := at + Vector2(-font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x * 0.5, -46 - 18 * p)
			canvas.draw_string_outline(font, spot, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 4, Color(0, 0, 0, fade))
			canvas.draw_string(font, spot, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(tint, fade))
		"explosion":
			# the Feuerball's impact: the hit ring; the fat explosion itself plays from _impacts (first sight)
			TalentPixels.nova(canvas, at, r, p, "fire", art, id)
		"chain":
			# Glutkette: a chain of ember sparks runs from link to link, each hit a small boom
			var points: Array = event.get("points", [])
			var links := points.size() - 1
			for i in range(links):
				var from := Vector2(float(points[i][0]), float(points[i][1])) + body
				var to := Vector2(float(points[i + 1][0]), float(points[i + 1][1])) + body
				var start := float(i) / maxf(1.0, float(links)) * 0.6
				var reach := clampf((p - start) / (0.6 / maxf(1.0, float(links))), 0.0, 1.0)
				if reach <= 0.0: continue
				TalentPixels.ember_chain(canvas, from, to, reach, fade, art, _clock, id + i * 7)
				if reach >= 1.0: TalentPixels.boom(canvas, to, (to - from).normalized(), clampf((p - start - 0.1) * 1.6, 0.0, 1.0), art, 5, id + i, cfg.get("fire", {}).get("boom", {}))
		"meteor_fall":
			# the warning fills, the shadow grows while the rock falls in from the top right
			var fire := Pal.ramp("fire")
			PixelPaint.warning(canvas, at, r, r * 0.75, p, fire[2], INK, art, _clock)
			# the shadow grows on the floor and darkens as the rock comes down
			var shade := float(cfg.get("fire", {}).get("meteor", {}).get("shadow", 0.85))
			var sr := r * (0.15 + 0.85 * p) * 0.9
			PixelPaint.disc(canvas, at, sr, sr * 0.75, INK, art, 0.2 + shade * p * p)
			var big := bool(event.get("big", false)) and sprites.has("meteor_big")
			var fall := Vector2(150, -320) if big else Vector2(110, -260)
			var rock := at + fall * (1.0 - p)
			# embers streaming off the rock
			for k in range(8):
				var q := PixelPaint.at(rock + fall.normalized() * (8.0 + float(k) * 7.0) * art * 0.5 + Vector2(sin(float(k) * 2.0 + _clock * 9.0) * 2.0 * art, 0.0), art)
				if PixelPaint.shown(q, 1.0 - float(k) / 8.0): PixelPaint.cell(canvas, q, fire[4] if k < 2 else (fire[3] if k < 5 else fire[2]), art)
			if big: sprites.draw_loop(canvas, "meteor_big", rock, 0.0, 1.3, p * 2.0)
			else: sprites.draw_loop(canvas, "meteor", rock, 0.0, 0.9, p * 2.0)
		"spear":
			# Himmelsspeer: the golden arrow streaks to the end of its line, a bright trail behind it
			var to := Vector2(float(event.get("tx", at.x)), float(event.get("ty", at.y)))
			var head := at.lerp(to, clampf(p * 2.5, 0.0, 1.0))
			TalentPixels.trail(canvas, at - Vector2(0, 14), head - Vector2(0, 14), p * 0.6, "gold", art, id)
			sprites.draw_loop(canvas, "sky_spear", head - Vector2(0, 14), (to - at).angle(), 1.4, p, Color(1, 1, 1, minf(1.0, fade * 2.0)))
		"net":
			# the thrown net comes down over the field and lies there
			TalentPixels.trap(canvas, at, "net", r / art, 0.5, art, _clock, id, 1.0 - minf(1.0, p * 1.6))
		"leap_slam":
			# Erdspalter: an arc through the air, then the ground breaks
			var to := Vector2(float(event.get("tx", at.x)), float(event.get("ty", at.y)))
			var stone := Pal.ramp("stone")
			for i in range(10):
				var k := i / 9.0
				var q := PixelPaint.at(at.lerp(to, k) - Vector2(0, sin(k * PI) * 60.0), art)
				if PixelPaint.shown(q, fade * (0.2 + k * 0.6)): PixelPaint.cell(canvas, q, stone[3], art)
			TalentPixels.nova(canvas, to, r, p, "stone", art, id)
			TalentPixels.impact(canvas, to, Vector2.ZERO, p, "stone", art, int(clampf(r / art * 0.3, 6.0, 12.0)), id)
		"soul":
			# a soul flies from the enemy to the hero
			var to := Vector2(float(event.get("tx", at.x)), float(event.get("ty", at.y))) - Vector2(0, 16)
			var spot := (at - Vector2(0, 12)).lerp(to, p * p) - Vector2(0, sin(p * PI) * 30.0)
			TalentPixels.shot(canvas, _snap(spot), to - spot, "soul", art, 1, 4, _clock, id)
		"pet_cleave":
			sprites.draw_at(canvas, "claw", at + Vector2(0, -14), 0.0, r / 40.0, p)
			TalentPixels.nova(canvas, at, r, p, "steel", art, id)
		"arrow_finale":
			# Pfeilhagel's last volley: the whole field strikes at once, dust bursting across it
			for i in range(12):
				var spot := at + Vector2.from_angle(i * 2.39996) * r * sqrt((i + 0.5) / 12.0) * 0.9
				var start := float(i % 4) * 0.08
				var k := clampf((p - start) / (1.0 - start), 0.0, 1.0)
				if k <= 0.0: sprites.draw_loop(canvas, "hail_arrow", spot + Vector2(18, -150) * (1.0 - p / start), 0.12, 1.0, p)
				else: sprites.draw_at(canvas, "arrow_impact", spot, 0.0, 1.2, k)
			TalentPixels.nova(canvas, at, r, p, "stone", art, id, true)
			TalentPixels.impact(canvas, at, Vector2.ZERO, p, "stone", art, int(clampf(r / art * 0.25, 6.0, 12.0)), id)
		"dive":
			# Sturzflug: the falcon drops out of the sky onto its prey, feathers in its wake
			var to := Vector2(float(event.get("tx", at.x)), float(event.get("ty", at.y)))
			var high := at - Vector2(0, 70)
			var beast := Pal.ramp("beast")
			for i in range(9):
				var k := i / 8.0
				var q := PixelPaint.at(high.lerp(to - Vector2(0, 10), k), art)
				if PixelPaint.shown(q, fade * (0.2 + k * 0.7)):
					PixelPaint.cell(canvas, q, beast[3], art)
					PixelPaint.cell(canvas, q + Vector2i(-1, -1), beast[2], art)
			sprites.draw_at(canvas, "claw", to + Vector2(0, -12), 0.0, 1.0, p)
		"dodge":
			# Ausweichen: afterimages along the roll, dust where it starts
			var to := Vector2(float(event.get("tx", at.x)), float(event.get("ty", at.y)))
			var beast := Pal.ramp("beast")
			for i in range(5):
				var k := i / 4.0
				PixelPaint.disc(canvas, at.lerp(to, k) - Vector2(0, 14), (9.0 - i) * art * 0.5, (9.0 - i) * art * 0.5, beast[2], art, fade * (0.15 + k * 0.25))
			TalentPixels.burst(canvas, at, 4, p, "stone", art, id)
		"dodged":
			var font := ThemeDB.fallback_font
			var spot := at + Vector2(-20, -50 - 16 * p)
			canvas.draw_string_outline(font, spot, "AUSGEWICHEN", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, 4, Color(0, 0, 0, fade))
			canvas.draw_string(font, spot, "AUSGEWICHEN", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.75, 1.0, 0.7, fade))
		"block_hit":
			# a hit stopped by the block: the shield's rim flashes, sparks fly
			PixelPaint.ellipse(canvas, at - Vector2(0, 16), r * (1.0 + 0.2 * p), r * (1.0 + 0.2 * p) * 0.8, Pal.ramp("steel")[4], art, 2, int(p * 20.0))
			TalentPixels.burst(canvas, at - Vector2(0, 16), 5, p, "steel", art, id)
		"block_break":
			# the last hit breaks the block: it bursts into shards of its element
			var element := str(LOOK_ELEMENT.get(str(event.get("look", "mana_bubble")), "ice"))
			TalentPixels.burst(canvas, at - Vector2(0, 16), 8, p, element, art, id)
			var cols := Pal.ramp(element)
			for i in range(8):
				var dir := Vector2.from_angle(TAU * i / 8.0 + 0.3)
				var q := PixelPaint.at(at - Vector2(0, 16) + dir * r * (0.8 + p * 1.2) + Vector2(0, 30.0 * p * p), art)
				if PixelPaint.shown(q, fade):
					PixelPaint.cell(canvas, q + Vector2i(0, 1), INK, art)
					PixelPaint.cell(canvas, q, cols[3], art)
		"drawn":
			# the drawn line catches fire along its length
			TalentPixels.nova(canvas, at, r * 0.4, p, "fire", art, id)
		"pet_strike":
			# a companion's wound: blood for bleeding, dizzy stars for a blinding blow
			var wound := str(event.get("wound", ""))
			if wound == "burn":
				TalentPixels.burst(canvas, at - Vector2(0, 12), 6, p, "fire", art, id)
			elif wound == "blood":
				TalentPixels.burst(canvas, at - Vector2(0, 12), 7, p, "blood", art, id)
				var blood := Pal.ramp("blood")
				for i in range(5):
					var q := PixelPaint.at(at - Vector2(0, 14) + Vector2.from_angle(PI * (1.1 + i * 0.2)) * 18.0 * p + Vector2(0, 30.0 * p * p), art)
					if PixelPaint.shown(q, fade): PixelPaint.cell(canvas, q, blood[2], art)
			else:
				var gold := Pal.ramp("gold")
				for i in range(4):
					var q := PixelPaint.at(at - Vector2(0, 34) + Vector2(cos(p * 9.0 + i * TAU / 4.0) * 12.0, sin(p * 9.0 + i * TAU / 4.0) * 4.0), art)
					if PixelPaint.shown(q, fade): PixelPaint.cell(canvas, q, gold[4], art)
				TalentPixels.burst(canvas, at - Vector2(0, 16), 5, p, "gold", art, id)
		"summon":
			var element := "ice" if str(event.get("kind", "")) == "water_elemental" else ("bone" if str(event.get("kind", "")) in ["skeleton", "bone_warrior", "colossus"] else "beast")
			TalentPixels.nova(canvas, at, _u(46.0), p, element, art, id)
			TalentPixels.burst(canvas, at + body, 7, p, element, art, id)
		"pet_fell":
			TalentPixels.burst(canvas, at + Vector2(0, -12), 8, p, "ice" if str(event.get("kind", "")) == "water_elemental" else "bone", art, id)
