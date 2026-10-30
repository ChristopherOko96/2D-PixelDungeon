extends RefCounted
## Client art of the talents (snapshot "talents", src/combat/talent_combat.gd)
## on the art grid of the world it is drawn in (`art` world px per art pixel:
## the crypt 2, the story worlds 3): zones as physics pools with gas or flames
## over them, set traps, the wolves, the talent shots and the short events.
## Rings, waves, trails, shields and rage auras are pixels with the exact hit
## radius (src/vfx/talent_pixels.gd); the nine ultimates have their own forms,
## lasting auras and stage layers (src/vfx/talent_ults.gd). The sheets of
## scripts/make_fx_sprites.gd that read well (slash, whirl, claw, spike trap,
## crit spark, the shots) stay, cut at walls and dithered out. Nothing is
## see-through: everything fades by the ordered dither and stops at walls (the
## host sets PixelPaint.clip and the sprites' floor). The weight on the view
## (shake, a held picture, a bloom flash in the element's colour) comes by
## importance from assets/data/vfx_talents.json. The companions (wolf, bear)
## come from the 0x72 companion pack "Enchanted Forest Characters".
## Presentation only.

const FxSprites = preload("res://src/vfx/fx_sprites.gd")
const PixelPaint = preload("res://src/vfx/pixel_paint.gd")
const Glow = preload("res://src/vfx/glow.gd")
const Pal = preload("res://src/vfx/talent_palette.gd")
const TalentPixels = preload("res://src/vfx/talent_pixels.gd")
const TalentUlts = preload("res://src/vfx/talent_ults.gd")
const TalentDome = preload("res://src/vfx/talent_dome.gd")
const DATA_PATH := "res://assets/data/vfx_talents.json"
## Shots per talent style: sheet, element and the length of its dithered trail (art cells).
const SHOTS := {"frost_lance": ["ice_lance", "ice", 9], "arcane": ["arcane_orb", "arcane", 7], "fireball": ["fireball", "fire", 9]}
## Lasting buffs drawn as a shield dome: [size, element], the first one a hero has wins.
const DOMES := [["unbreakable", 2, "gold"], ["bulwark", 1, "gold"], ["oath", 1, "steel"], ["shield", 1, "ice"]]
## Element of each lasting buff on a hero.
const BUFF_ELEMENT := {"frenzy": "blood", "bloodlust": "blood", "bulwark": "gold", "oath": "steel", "unbreakable": "gold",
	"timebreak": "arcane", "shield": "ice", "channel": "steel"}

var sprites := FxSprites.new()
## The poison zones (Todeszone), burning ground (Feuersturm) and the ultimates'
## own pools (ice under Absoluter Nullpunkt, blood under Blutrausch) as physics
## pools that run out and stop at the walls (src/vfx/pool_paint.gd, set by the
## host with its art pixel); null draws dithered discs.
var pools: RefCounted = null
## False when the pools are a world layer its host draws (the Hell's).
var draw_pools := true
## The host's particles (src/vfx/particles.gd) fire bursts into, null without;
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
var _frames: Dictionary = {}
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


## The dome of hero `owner`, made on first use.
func _dome(owner: int) -> RefCounted:
	if not _domes.has(owner): _domes[owner] = TalentDome.new(cfg.get("dome", {}))
	return _domes[owner]


## The arcane ramp for the particles: spec, lite, body, shade, deep.
static func _arcane() -> Array:
	var r: Array = Pal.ramp("arcane")
	return [r[4], r[3], r[2], r[1], r[0]]


## A crypt size in world px of this world (the story worlds are 1.5 times larger).
func _u(crypt_px: float) -> float:
	return crypt_px * art / 2.0


func _snap(p: Vector2) -> Vector2:
	return (p / art).round() * art


## Floor layer: zones and traps (under the actors).
func draw_ground(canvas: CanvasItem, state: Dictionary, clock: float) -> void:
	_clock = clock
	_observe(state, clock)
	var zones: Array = state.get("zones", [])
	if pools != null:
		var entries: Array = []
		for zone: Dictionary in zones:
			var length := maxf(0.3, float(zone.get("total", zone.get("time", 1.0))))
			entries.append({"id": int(zone.get("id", 0)), "k": "pool", "st": "fire" if str(zone.get("status", "")) == "burn" else "poison",
				"x": float(zone.x), "y": float(zone.y), "r": float(zone.r), "p": clampf(1.0 - float(zone.get("time", length)) / length, 0.0, 1.0), "L": length})
		for id: int in _ult_pools.keys():
			if float(_ult_pools[id].until) < clock: _ult_pools.erase(id)
			else: entries.append(_ult_pools[id].entry)
		pools.sync(entries, clock, "talent")
		if draw_pools: pools.draw(canvas, clock)
	if gas != null:
		# the poison zones' clouds: they spread, gather in corners, part round heroes
		var clouds: Array = []
		for zone: Dictionary in zones:
			if str(zone.get("status", "")) == "burn": continue
			var length := maxf(0.3, float(zone.get("total", zone.get("time", 1.0))))
			clouds.append({"id": int(zone.get("id", 0)), "k": "gas", "st": "poison", "x": float(zone.x), "y": float(zone.y), "r": float(zone.r),
				"p": clampf(1.0 - float(zone.get("time", length)) / length, 0.0, 1.0), "L": length, "d": 1.0})
		gas.sync(clouds, clock, "talent")
	for zone: Dictionary in zones:
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
				TalentUlts.zone(canvas, "fire_6", at, r, left, total, stage, every, art, clock, id)
			continue
		if pools == null: PixelPaint.disc(canvas, at, r, r, Pal.ramp("poison")[1], art, 0.3)
		if gas == null: TalentPixels.puffs(canvas, at, r, art, clock, id)
		if talent == "trapper_6":
			TalentUlts.zone(canvas, talent, at, r, left, total, stage, every, art, clock, id)
		else:
			var crawl := int(clock * PixelPaint.FPS)
			PixelPaint.ellipse(canvas, at + Vector2(0, art), r, r, Pal.INK, art, 3, crawl)
			PixelPaint.ellipse(canvas, at, r, r, Pal.ramp("poison")[3], art, 3, crawl)
	for trap: Dictionary in state.get("traps", []):
		var at := Vector2(float(trap.x), float(trap.y))
		var boom := bool(trap.get("boom", false))
		if sprites.has("spike_trap"):
			sprites.draw_at(canvas, "spike_trap", at, 0.0, 1.0, 0.0, Color("ffc890") if boom else Color.WHITE, true)
		else:
			PixelPaint.ellipse(canvas, at, _u(12.0), _u(12.0), Color("c87a3a") if boom else Color("8a8a96"), art)
		if boom and posmod(int(clock * PixelPaint.FPS), 2) == 0:
			# a glowing fuse: a blinking pixel spark
			var q := PixelPaint.at(at - Vector2(0, art), art)
			PixelPaint.cell(canvas, q, Pal.ramp("fire")[3], art)
			PixelPaint.cell(canvas, q + Vector2i(0, -1), Pal.ramp("fire")[4], art)


## Actor layer: the companions (wolf or bear) with the "Enchanted Forest
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
		var lunge := 3.0 * art if float(pet.get("bite", 0.0)) > 0.0 else 0.0
		var spirit := bool(pet.get("pack", false))
		if frame != null:
			canvas.draw_set_transform(at + Vector2(lunge * face, 0), 0.0, Vector2(art * face, art))
			# a spirit: the wolf brightened to pale blue-white (opaque, not see-through)
			canvas.draw_texture(frame, Vector2(-16, -31), Color(1.45, 1.75, 2.1) if spirit else Color.WHITE)
			canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if spirit: TalentUlts.spirit(canvas, at, art, clock, int(pet.get("id", 0)))
		if lunge > 0.0 and sprites.has("claw"):
			sprites.draw_loop(canvas, "claw", at + Vector2(_u(22.0) * face, _u(-20.0)), 0.0, 1.0, clock, Color.WHITE, true)


func _companion_frame(kind: String, motion: String, index: int) -> Texture2D:
	var path := "res://assets/sprites/forest_0x72/%s_%s_f%d.png" % [kind, motion, index]
	if not _frames.has(path): _frames[path] = load(path) if ResourceLoader.exists(path) else null
	return _frames[path]


## A talent shot ({x, y, vx, vy, style, talent, stage}) as its sheet with a
## dithered trail, the Letzter Pfeil as its own big arrow; false when the shot
## has neither (the caller draws it its own way).
func draw_bullet(canvas: CanvasItem, bullet: Dictionary, clock: float) -> bool:
	var flight := Vector2(float(bullet.get("vx", 1.0)), float(bullet.get("vy", 0.0)))
	var aim := flight.normalized() if flight.length() > 0.1 else Vector2.RIGHT
	var at := _snap(Vector2(float(bullet.x), float(bullet.y)))
	if str(bullet.get("talent", "")) == "sniper_6":
		TalentUlts.arrow(canvas, at, aim, int(bullet.get("stage", 0)), art, clock)
		return true
	var shot: Array = SHOTS.get(str(bullet.get("style", "")), [])
	if shot.is_empty() or not sprites.has(str(shot[0])): return false
	TalentPixels.shot_trail(canvas, at, aim, str(shot[1]), art, int(shot[2]), clock)
	sprites.draw_loop(canvas, str(shot[0]), at, aim.angle(), 1.0, clock, Color.WHITE, true)
	return true


## Effect layer: short events over everything, each played over its life
## (span). `clock` defaults to the one of the last draw_ground.
func draw_events(canvas: CanvasItem, state: Dictionary, clock: float = -1.0) -> void:
	if clock >= 0.0: _clock = clock
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
			"shout":
				TalentPixels.waves(canvas, at, r, p, "gold", art, id)
			"blink", "dash", "leap":
				var to := Vector2(float(event.get("tx", at.x)), float(event.get("ty", at.y)))
				var kind := str(event.kind)
				TalentPixels.trail(canvas, at, to, p, element if kind == "blink" else ("beast" if kind == "leap" else "steel"), art, id)
				match kind:
					"blink":
						TalentPixels.burst(canvas, at + body, 7, p, element, art, id)
						sprites.draw_at(canvas, "blink", to + body, 0.0, 1.0, p, Color.WHITE, true, fade)
					"dash":
						sprites.draw_at(canvas, "slash", to, (to - at).angle(), 1.0, p, Color.WHITE, true, fade)
					"leap":
						sprites.draw_at(canvas, "claw", to + body * 0.85, 0.0, 1.0, p, Color.WHITE, true, fade)
			"swing":
				if sprites.has("slash"):
					sprites.draw_at(canvas, "slash", at, float(event.get("angle", 0.0)), maxf(1.0, r / 52.0), p, Color.WHITE, true, fade)
				else:
					TalentPixels.nova(canvas, at, r, p, "steel", art, id)
			"crit":
				sprites.draw_at(canvas, "crit_spark", at + body * 1.15, 0.0, 1.0, p, Color.WHITE, true, fade)
				TalentPixels.text(canvas, at + body * 2.1 + Vector2(0, -7.0 * art * p), "KRIT", Pal.ramp("gold")[3], art, fade)
			"guard":
				# a wolf takes part of a blow: a short dome flash round the hero
				_flash_dome.draw(canvas, _snap(at) + feet, clampf(p * 4.0, 0.0, 1.0), fade, "gold", art, _clock)
			"parry":
				TalentPixels.burst(canvas, at + body, 7, p, "steel", art, id)
				sprites.draw_at(canvas, "crit_spark", at + body, 0.0, 1.0, p, Color.WHITE, true, fade)
			"mark":
				TalentPixels.reticle(canvas, at + body * 1.6, p, 1.0 - smoothstep(0.85, 1.0, p), art, _clock)
			"trap":
				if bool(event.get("boom", false)):
					TalentPixels.nova(canvas, at, r, p, "fire", art, id)
					TalentPixels.burst(canvas, at, int(clampf(r / art * 0.45, 5.0, 16.0)), p, "fire", art, id)
				else:
					sprites.draw_at(canvas, "spike_trap", at, 0.0, 1.0, p, Color.WHITE, true, fade)
					TalentPixels.burst(canvas, at, 5, p, "steel", art, id)
			"echo":
				TalentPixels.nova(canvas, at, maxf(r, _u(26.0)), p, "arcane", art, id)
			"buff":
				_buff(canvas, str(event.get("buff", "")), at, p, id)
			"cast":
				if ult:
					# the ultimate's own form and its stage layers (src/vfx/talent_ults.gd)
					TalentUlts.cast(canvas, talent, at, body, r, p, stage, float(event.get("angle", 0.0)), art, _clock, id, feet)
					match talent:
						"beast_6": TalentPixels.waves(canvas, at, _u(96.0), p, "spirit", art, id)
						"blade_6": TalentPixels.nova(canvas, at, r if r > 0.0 else _u(110.0), p, "steel", art, id, true)
				elif talent == "frost_5":
					# Kristallschild: the lasting dome is its aura; here the frost it forms from
					TalentPixels.burst(canvas, at + body, 8, p, "ice", art, id)


## The flash of a buff when it starts (the buff itself lasts as an aura).
func _buff(canvas: CanvasItem, buff: String, at: Vector2, p: float, id: int) -> void:
	match buff:
		"frenzy": TalentPixels.burst(canvas, at + body, 8, p, "blood", art, id)
		"bloodlust": TalentPixels.nova(canvas, at, _u(70.0), p, "blood", art, id, true)
		"bulwark", "oath": TalentPixels.burst(canvas, at + body, 8, p, str(BUFF_ELEMENT[buff]), art, id)
		"unbreakable": TalentPixels.nova(canvas, at, _u(80.0), p, "gold", art, id, true)
		"timebreak": TalentPixels.nova(canvas, at, _u(90.0), p, "arcane", art, id, true)
		_: sprites.draw_at(canvas, "level_up", at, 0.0, 1.0, p, Color.WHITE, true)


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
				if str(aura.get("talent", "")) == "blade_6":
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
## of weighty events in their element's colour and a faint light of the
## lasting buffs; small, never a white-hot core.
func draw_glow(canvas: CanvasItem, state: Dictionary, level: float, clock: float, where: Callable) -> void:
	if level <= 0.0: return
	for i in range(_flashes.size() - 1, -1, -1):
		var flash: Dictionary = _flashes[i]
		var k := (clock - float(flash.t0)) / maxf(0.01, float(flash.T))
		if k >= 1.0 or k < 0.0:
			_flashes.remove_at(i)
			continue
		Glow.dot(canvas, flash.at, float(flash.r) * (0.7 + 0.3 * k), Color(flash.col, float(flash.strength) * (1.0 - k) * (1.0 - k) * level))
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


## The tier of an event's weight ("" for none): an ultimate's cast and its
## waves weigh most (its own nova or buff in the same moment adds nothing).
func _tier(event: Dictionary) -> String:
	var kind := str(event.get("kind", ""))
	if bool(event.get("ult", false)):
		if kind == "cast": return str(cfg.get("ult_cast", "huge"))
		if bool(event.get("wave", false)): return str(cfg.get("ult_wave", "large"))
		return ""
	var events: Dictionary = cfg.get("events", {})
	if kind == "trap": return str(events.get("trap_boom", "")) if bool(event.get("boom", false)) else ""
	return str(events.get(kind, ""))


func _boost(event: Dictionary) -> float:
	return 1.0 + float(cfg.get("stage_bonus", 0.0)) * float(event.get("stage", 0))


## First sight of each event: its bloom flash and the pool an ultimate leaves.
func _observe(state: Dictionary, clock: float) -> void:
	var now := {}
	for event: Dictionary in state.get("events", []):
		var id := int(event.get("id", 0))
		now[id] = true
		if _seen.has(id): continue
		var tier := _tier(event)
		var element := Pal.element_of(str(event.get("talent", "")), str(event.get("fx", "steel")))
		if tier != "":
			var spec: Dictionary = cfg.get("tiers", {}).get(tier, {})
			_flashes.append({"at": Vector2(float(event.x), float(event.y)) + body, "col": Pal.ramp(element)[3], "t0": clock,
				"T": float(spec.get("flash", 0.15)) * _boost(event), "r": float(spec.get("flash_r", 20.0)) * art * _boost(event), "strength": 0.5})
		if bool(event.get("ult", false)): _ult_pool(event, state, clock)
		# fire bursts into flames that rise, embers and smoke (src/vfx/particles.gd fire_burst)
		if particles != null and str(event.get("kind", "")) in ["nova", "trap"] and (element == "fire" or bool(event.get("boom", false))):
			particles.fire_burst(Vector2(float(event.x), float(event.y)) * to_particles, minf(float(event.get("r", 40.0)), _u(70.0)) * to_particles)
		# arcane: a blink tears the space it leaves (a small implosion), an arcane wave implodes first
		if particles != null and element == "arcane":
			var at := Vector2(float(event.x), float(event.y)) * to_particles
			if str(event.get("kind", "")) == "blink":
				particles.implode(at, _u(30.0) * to_particles, _arcane())
			elif str(event.get("kind", "")) == "nova" and bool(event.get("wave", false)):
				particles.implode(at, minf(float(event.get("r", 60.0)), _u(80.0)) * to_particles, _arcane())
		# frost: shards burst and slide, rime grows out, liquid in reach freezes
		if particles != null and str(event.get("kind", "")) == "nova" and element == "ice":
			var at := Vector2(float(event.x), float(event.y)) * to_particles
			var reach := float(event.get("r", 60.0)) * to_particles
			var heavy := bool(event.get("ult", false))
			particles.shatter(at, 18 if heavy else 10, Vector2.ZERO, minf(reach * 1.4, 260.0), [], 4 if heavy else 3)
			particles.rime_grow(at, 7 if heavy else 5, reach * (0.4 if heavy else 0.32))
			particles.freeze_liquids(at, reach)
		if str(event.get("kind", "")) == "dome_hit":
			# the blow dents the hero's dome on the side it came from
			_dome(int(event.get("owner", 1))).hit(Vector2(float(event.get("dx", 0.0)), float(event.get("dy", 1.0))), float(event.get("power", 1.0)), clock)
	_seen = now


## The pool an ultimate leaves where it struck (assets/data/vfx_talents.json "pools").
func _ult_pool(event: Dictionary, state: Dictionary, clock: float) -> void:
	var wave := bool(event.get("wave", false))
	if str(event.get("kind", "")) != ("nova" if wave else "cast"): return
	var talent := str(event.get("talent", ""))
	var spec: Dictionary = cfg.get("pools", {}).get(talent + ("_wave" if wave else ""), {})
	if spec.is_empty(): return
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
## trauma, shake_px, hitstop}) by importance (assets/data/vfx_talents.json);
## each event once. The host shakes its view and holds the picture for its own hero.
func take_feel(state: Dictionary) -> Array:
	var out: Array = []
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
