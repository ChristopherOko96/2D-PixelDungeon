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
## come from the 0x72 companion pack "Enchanted Forest Characters"; the water
## elemental, bone warrior, falcon and Pyro-Monster are drawn in the archive's
## style (scripts/make_companion_sprites.py, scripts/make_falcon.py). On top of
## that (user wish lists 30.10.2026): every active talent its own sheet (shots,
## rings, blinks, casts), the zone looks of the ultimates and the drawn
## Flammenmeer, the line being drawn with its fill bar, mana orbs, the Shift
## guards (block bubble, dodge) and the new events (meteor, chain, explosion,
## spear, net, companions' strikes and dives, Pfeilhagel's last volley).
## Presentation only.

const FxSprites = preload("res://src/vfx/fx_sprites.gd")
const PerfMarks = preload("res://src/debug/perf_marks.gd")
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
const FX_COLORS := {"fire": Color("ff7a2a"), "ice": Color("8fd8e6"), "arcane": Color("b07bff"), "steel": Color("d8dce6"), "poison": Color("8fd65a")}
## Nova rings per element.
const RINGS := {"fire": "fire_ring", "ice": "frost_ring", "arcane": "arcane_ring", "steel": "steel_ring"}
## Bursts at the start and end of a blink per element.
const BLINKS := {"fire": "fire_burst", "arcane": "blink", "ice": "frost_burst"}
## Every active talent its own look (user decision 30.10.2026). Shots per
## talent (they win over the style), then rings, blinks, dashes, swings, marks
## and cast flashes per talent.
const TALENT_SHOTS := {"fire_11": ["magma_bolt", 1.3], "frost_9": ["ice_shard", 1.4], "arcane_9": ["arcane_lance", 1.4], "trapper_1": ["poison_dart", 1.3],
	"minion_3": ["bone_spear", 1.3], "soul_9": ["soul_lance", 1.4], "curse_9": ["blood_orb", 1.4], "soul_1": ["soul_bolt", 1.3], "blade_9": ["knife", 1.2],
	"curse_1": ["curse_skull", 1.3], "fire_9": ["fire_spear", 1.5], "fire_1": ["fireball_big", 1.5]}
const TALENT_RINGS := {"berserk_11": "blood_ring", "guard_7": "quake_ring", "curse_5": "curse_ring", "soul_3": "soul_ring", "guard_4": "shout_ring"}
const TALENT_BURSTS := {"minion_7": "bone_burst", "berserk_11": "blood_burst", "guard_7": "stone_burst", "curse_5": "poison_burst", "soul_3": "void_burst", "arcane_7": "arcane_burst"}
const TALENT_BLINKS := {"sniper_9": "smoke_puff", "trapper_11": "smoke_puff", "blade_11": "shadow_burst", "curse_11": "shadow_burst", "minion_11": "bone_burst", "soul_7": "void_burst"}
const TALENT_DASHES := {"berserk_7": "stone_burst", "guard_11": "gold_bubble", "beast_11": "claw", "blade_5": "slash"}
const TALENT_SWINGS := {"berserk_1": ["slash_rage", ""], "berserk_9": ["slash_rage", "stone_burst"], "guard_1": ["slash", "gold_bubble"], "blade_1": ["slash", "blood_burst"], "blade_7": ["slash", "blood_burst"]}
const TALENT_CASTS := {"fire_1": ["fire_charge", 1.2], "fire_9": ["fire_charge", 1.5], "fire_11": ["fire_charge", 1.2], "fire_3": ["fire_burst", 0.9], "fire_7": ["fire_charge", 1.0],
	"frost_5": ["shield_bubble", 1.0], "arcane_11": ["mana_bubble", 1.1], "soul_5": ["soul_bubble", 1.1], "guard_9": ["gold_bubble", 1.2],
	"minion_9": ["bone_burst", 1.0], "sniper_6": ["star_burst", 1.0], "trapper_6": ["poison_burst", 2.0], "berserk_5": ["rage_aura", 1.0]}
const INK := Color("1a1414")
## Zone looks drawn here as their own art (not as a pool or gas).
const LOOKS := ["flames", "firewall", "lava", "ice", "arcane", "snow", "arrows", "crater", "souls", "plague"]

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
	PerfMarks.begin()
	_observe(state, clock)
	PerfMarks.add("tg.observe")
	var zones: Array = state.get("zones", [])
	if pools != null:
		var entries: Array = []
		for zone: Dictionary in zones:
			if _own_look(zone): continue
			var length := maxf(0.3, float(zone.get("total", zone.get("time", 1.0))))
			entries.append({"id": int(zone.get("id", 0)), "k": "pool", "st": "fire" if str(zone.get("status", "")) == "burn" else "poison",
				"x": float(zone.x), "y": float(zone.y), "r": float(zone.r), "p": clampf(1.0 - float(zone.get("time", length)) / length, 0.0, 1.0), "L": length})
		for id: int in _ult_pools.keys():
			if float(_ult_pools[id].until) < clock: _ult_pools.erase(id)
			else: entries.append(_ult_pools[id].entry)
		pools.sync(entries, clock, "talent")
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
	PerfMarks.add("tg.zones")
	_draw_orbs(canvas, state, clock)
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
		# the falcon flies: drawn above its shadow, bobbing with the wing beats
		var lift := _snap(Vector2(0, _u(-22.0 - 3.0 * sin(clock * 3.0)))) if kind == "falcon" else Vector2.ZERO
		if kind == "falcon":
			canvas.draw_set_transform(at, 0.0, Vector2(1.0, 0.4))
			canvas.draw_circle(Vector2.ZERO, 12.0, Color(0, 0, 0, 0.3))
			canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# Wildes Erwachen: the companion grows; the colossus is big anyway
		var grow := art * (1.5 if bool(pet.get("awake", false)) else 1.0)
		if bool(pet.get("awake", false)): sprites.draw_loop(canvas, "rage_aura", at + Vector2(0, -24), 0.0, 1.3, clock)
		var lunge := 3.0 * art if float(pet.get("bite", 0.0)) > 0.0 and kind != "water_elemental" else 0.0
		# a spirit of the pack: brightened to pale blue-white (opaque, not see-through)
		var spirit := bool(pet.get("pack", false))
		var tint := Color(1.45, 1.75, 2.1) if spirit else Color.WHITE
		if float(pet.get("hurt", 0.0)) > 0.0: tint = Color(1.0, 0.55, 0.5)
		var casting := float(pet.get("cast", 0.0))
		if casting > 0.0:
			# casting: a bright flash and a ring of its element under the feet
			tint = tint.lerp(Color(1.6, 1.6, 1.6), clampf(casting / 0.45, 0.0, 1.0) * 0.6)
			_ring(canvas, "frost_ring" if kind == "water_elemental" else "fire_ring" if kind == "pyro" else "shout_ring", at, 26.0, 1.0 - clampf(casting / 0.45, 0.0, 1.0))
		if kind == "pyro":
			# the ground glows under the Pyro-Monster, embers rise off it
			canvas.draw_circle(at + Vector2(0, -1), 11.0 + sin(clock * 7.0), Color(1.0, 0.45, 0.12, 0.2))
			for k in range(3):
				var age := fmod(clock * 1.5 + k * 0.33, 1.0)
				canvas.draw_rect(Rect2((at + Vector2(sin(k * 2.3 + clock) * 10.0, -10.0 - age * 40.0)).round(), Vector2(2, 2)), Color(1.0, 0.75, 0.3, 1.0 - age))
		if kind == "water_elemental":
			# a wet shimmer on the floor under the gliding whirl
			canvas.draw_circle(at + Vector2(0, -1), 10.0 + sin(clock * 5.0), Color(0.4, 0.75, 1.0, 0.18))
		if frame != null:
			# feet on the point whatever the frame size (32 px forest beasts, 16 px skeletons)
			var frame_size := frame.get_size()
			canvas.draw_set_transform(at + lift + Vector2(lunge * face, 0), 0.0, Vector2(grow * face, grow))
			canvas.draw_texture(frame, Vector2(-frame_size.x * 0.5, 1.0 - frame_size.y), tint)
			canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if spirit: TalentUlts.spirit(canvas, at, art, clock, int(pet.get("id", 0)))
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


## A talent shot ({x, y, vx, vy, style, talent, stage}) as its sheet with a
## dithered trail, the Letzter Pfeil as its own big arrow; false when the shot
## has neither (the caller draws it its own way).
func draw_bullet(canvas: CanvasItem, bullet: Dictionary, clock: float) -> bool:
	var flight := Vector2(float(bullet.get("vx", 1.0)), float(bullet.get("vy", 0.0)))
	var aim := flight.normalized() if flight.length() > 0.1 else Vector2.RIGHT
	var at := _snap(Vector2(float(bullet.x), float(bullet.y)))
	var own: Array = TALENT_SHOTS.get(str(bullet.get("talent", "")), [])
	if not own.is_empty() and sprites.has(str(own[0])):
		if str(own[0]) == "fireball_big":
			# embers peel off behind the Feuerball and sink as they cool
			for k in range(8):
				var age := fmod(clock * 3.0 + k * 0.125, 1.0)
				var spot := at - aim * _u(14.0 + age * 46.0) + aim.orthogonal() * sin(k * 2.3 + clock * 7.0) * _u(4.0 + age * 8.0) + Vector2(0, _u(age * 6.0))
				canvas.draw_rect(Rect2(_snap(spot), Vector2(art, art)), Color(1.0, 0.85 - age * 0.5, maxf(0.0, 0.3 - age * 0.25)))
		TalentPixels.shot_trail(canvas, at, aim, Pal.element_of(str(bullet.get("talent", "")), "fire"), art, 7, clock)
		sprites.draw_loop(canvas, str(own[0]), at, aim.angle(), float(own[1]), clock, Color.WHITE, true)
		return true
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
	PerfMarks.begin()
	for guard: Dictionary in state.get("guards", []):
		_draw_guard(canvas, guard)
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
				_nova_extra(canvas, event, at, p, talent)
			"shout":
				TalentPixels.waves(canvas, at, r, p, "gold", art, id)
			"blink", "dash", "leap":
				var to := Vector2(float(event.get("tx", at.x)), float(event.get("ty", at.y)))
				var kind := str(event.kind)
				TalentPixels.trail(canvas, at, to, p, element if kind == "blink" else ("beast" if kind == "leap" else "steel"), art, id)
				match kind:
					"blink":
						TalentPixels.burst(canvas, at + body, 7, p, element, art, id)
						if talent == "fire_5": _phoenix(canvas, at, to, p, 1.0 - p)
						else: sprites.draw_at(canvas, str(TALENT_BLINKS.get(talent, "blink")), to + body, 0.0, 1.0, p, Color.WHITE, true, fade)
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
				else:
					_cast(canvas, talent, at, p)
			_:
				_extra_event(canvas, event, at, p, 1.0 - p)
		PerfMarks.add("te." + str(event.kind) + ("-ult" if ult else ""))


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

## A zone with a look of its own (drawn by _draw_looks, not as a pool or gas).
func _own_look(zone: Dictionary) -> bool:
	return str(zone.get("look", "")) in LOOKS or not (zone.get("path", []) as Array).is_empty()


## The zone looks of the talents and ultimates: the drawn Flammenmeer, ice,
## the whirl, snow, Pfeilhagel, the meteor's crater, souls and plague.
func _draw_looks(canvas: CanvasItem, zones: Array, clock: float) -> void:
	for zone: Dictionary in zones:
		if not _own_look(zone): continue
		var at := Vector2(float(zone.x), float(zone.y))
		var r := float(zone.r)
		match str(zone.get("look", "")):
			"flames":
				# Flammenmeer: glowing cracked ground along the drawn line, flames standing on it
				var path: Array = zone.get("path", [])
				var fade := clampf(float(zone.get("time", 1.0)) / 0.6, 0.0, 1.0)
				var width := float(zone.get("w", 18.0))
				for i in range(path.size() - 1):
					var a := Vector2(float(path[i][0]), float(path[i][1]))
					var b := Vector2(float(path[i + 1][0]), float(path[i + 1][1]))
					canvas.draw_line(a, b, Color(0.35, 0.08, 0.04, 0.45 * fade), width * 2.2)
					canvas.draw_line(a, b, Color(1.0, 0.42, 0.1, 0.35 * fade), width * 1.3)
					canvas.draw_line(a, b, Color(1.0, 0.8, 0.35, 0.7 * fade), 3.0)
				var walked := 0.0
				for i in range(path.size() - 1):
					var a := Vector2(float(path[i][0]), float(path[i][1]))
					var b := Vector2(float(path[i + 1][0]), float(path[i + 1][1]))
					var length := a.distance_to(b)
					var spot_at := fmod(16.0 - fmod(walked, 16.0), 16.0)
					while spot_at <= length:
						var k := int((walked + spot_at) / 16.0)
						sprites.draw_loop(canvas, "flame_tongue", a.lerp(b, spot_at / maxf(0.01, length)) + Vector2(0, 4), 0.0, (0.5 + 0.12 * float(k % 3)) * (0.4 + 0.6 * fade), clock + k * 0.23)
						spot_at += 16.0
					walked += length
			"firewall":
				# Flammenwall: glowing ground along the line, tall flames flickering on it
				var a := Vector2(float(zone.get("ax", at.x)), float(zone.get("ay", at.y)))
				var b := Vector2(float(zone.get("bx", at.x)), float(zone.get("by", at.y)))
				canvas.draw_line(a, b, Color(1.0, 0.45, 0.1, 0.25), 22.0)
				canvas.draw_line(a, b, Color(1.0, 0.75, 0.3, 0.5), 4.0)
				var count := maxi(2, int(a.distance_to(b) / 14.0))
				for i in range(count + 1):
					var spot := a.lerp(b, float(i) / count) + Vector2(0, 6)
					sprites.draw_loop(canvas, "flame_tongue", spot, 0.0, 1.0 + 0.15 * float(i % 3), clock + i * 0.23)
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
				# the meteor's crater: scorched rock, lava pooling, glowing cracks, flames and smoke
				canvas.draw_circle(at, r, Color(0.12, 0.07, 0.05, 0.45))
				sprites.draw_loop(canvas, "lava_pool", at, 0.0, clampf(r / 96.0, 0.5, 1.8), clock)
				for i in range(6):
					var a := TAU * i / 6.0 + 0.3
					var from := at + Vector2.from_angle(a) * r * 0.25
					var bend := at + Vector2.from_angle(a + 0.2) * r * 0.6
					var to := at + Vector2.from_angle(a - 0.1) * r * 0.95
					var glow := 0.55 + 0.35 * sin(clock * 3.0 + i)
					canvas.draw_line(from, bend, Color(1.0, 0.55, 0.15, glow), 3.0)
					canvas.draw_line(bend, to, Color(1.0, 0.45, 0.1, glow * 0.7), 2.0)
				for i in range(3):
					sprites.draw_loop(canvas, "flame_tongue", at + Vector2.from_angle(TAU * i / 3.0 + 1.0) * r * 0.55, 0.0, 0.8, clock + i * 0.5)
					sprites.draw_loop(canvas, "smoke_puff", at + Vector2.from_angle(TAU * i / 3.0) * r * 0.4 - Vector2(0, 20), 0.0, 1.0, clock * 0.6 + i * 0.4, Color(1, 1, 1, 0.5))
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
## ember trail along the points so far and, at its tip, the fill bar of the
## length still left.
func _draw_line_preview(canvas: CanvasItem, drawing: Dictionary, clock: float) -> void:
	var points: Array = drawing.get("points", [])
	if points.is_empty(): return
	for i in range(points.size() - 1):
		var a := Vector2(float(points[i][0]), float(points[i][1]))
		var b := Vector2(float(points[i + 1][0]), float(points[i + 1][1]))
		canvas.draw_line(a, b, Color(1.0, 0.45, 0.1, 0.35), 10.0)
		canvas.draw_line(a, b, Color(1.0, 0.85, 0.4, 0.5 + 0.3 * sin(clock * 12.0 + i)), 3.0)
	var tip := Vector2(float(points[-1][0]), float(points[-1][1]))
	sprites.draw_loop(canvas, "fire_charge", tip, 0.0, 0.9, clock)
	var share := clampf(float(drawing.get("left", 0.0)) / maxf(1.0, float(drawing.get("max", 1.0))), 0.0, 1.0)
	var bar := Rect2((tip + Vector2(-22, -34)).round(), Vector2(44, 6))
	canvas.draw_rect(bar.grow(1), INK)
	canvas.draw_rect(Rect2(bar.position, Vector2(roundf(bar.size.x * share), bar.size.y)), Color("ff8a2a") if share > 0.25 else Color("e2584a"))
	canvas.draw_rect(Rect2(bar.position, Vector2(roundf(bar.size.x * share), 2)), Color("ffd060"))


## The mage's left-click (crypt and Hölle): a small fireball that sheds embers.
func draw_basic_fireball(canvas: CanvasItem, at: Vector2, velocity: Vector2, clock: float) -> void:
	var aim := velocity.normalized() if velocity.length() > 0.1 else Vector2.RIGHT
	for k in range(5):
		var age := fmod(clock * 4.0 + k * 0.2, 1.0)
		var spot := at - aim * (8.0 + age * 26.0) + aim.orthogonal() * sin(k * 2.1 + clock * 9.0) * (2.0 + age * 5.0) + Vector2(0, age * 4.0)
		canvas.draw_rect(Rect2(spot.round() - Vector2(1, 1), Vector2(2, 2)), Color(1.0, 0.8 - age * 0.45, maxf(0.0, 0.3 - age * 0.3), 1.0 - age))
	canvas.draw_circle(at, 14.0, Color(1.0, 0.5, 0.15, 0.18))
	if sprites.has("fireball"): sprites.draw_loop(canvas, "fireball", at, aim.angle(), 1.25, clock)
	else: canvas.draw_circle(at, 6.0, Color("ffd060"))


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


## Phönixschritt: a bird of flame flies the way, a trail of embers behind it.
func _phoenix(canvas: CanvasItem, at: Vector2, to: Vector2, p: float, fade: float) -> void:
	# Phönixschritt: a bird of flame flies the way, flames at both ends
	# the bird flies the way, a trail of embers behind it
	var flight := minf(1.0, p * 1.3)
	var bird := at.lerp(to, flight) - Vector2(0, 22)
	for k in range(6):
		var ember := at.lerp(to, maxf(0.0, flight - k * 0.06)) - Vector2(0, 22 - k * 2)
		canvas.draw_rect(Rect2(ember - Vector2(2, 2), Vector2(4, 4)), Color(1.0, 0.6 - k * 0.06, 0.2, fade * (1.0 - k / 6.0)))
	if flight < 1.0: sprites.draw_loop(canvas, "phoenix", bird, (to - at).angle(), 1.8, p * 2.0)
	sprites.draw_at(canvas, "fire_burst", at, 0.0, 0.6, p)
	if flight >= 0.9: sprites.draw_at(canvas, "fire_burst", to, 0.0, 0.9, (flight - 0.9) * 4.0 + p * 0.5)


## The meteor's impact, the shower's bursts and the talents' own ring sheets on a nova.
func _nova_extra(canvas: CanvasItem, event: Dictionary, at: Vector2, p: float, talent: String) -> void:
	var fx := str(event.get("fx", "steel"))
	if bool(event.get("impact", false)):
		# a meteor lands: a flash over the field, the fire dome rising into a
		# mushroom, the dust shockwave, sparks and rock flying
		if p < 0.12: canvas.draw_circle(at, float(event.r) * 1.3, Color(1.0, 0.95, 0.8, (0.12 - p) * 5.0))
		sprites.draw_at(canvas, "meteor_impact", at, 0.0, float(event.r) / 150.0, p)
		sprites.draw_at(canvas, "fire_sparks", at - Vector2(0, 30), 0.0, float(event.r) / 50.0, minf(1.0, p * 1.4))
		sprites.draw_at(canvas, "stone_burst", at, 0.0, float(event.r) / 70.0, p)
	elif talent == "fire_14":
		# the small meteors of the shower burst like big fireballs
		sprites.draw_at(canvas, "fire_explosion", at - Vector2(0, 8), 0.0, float(event.r) / 44.0, p)
		sprites.draw_at(canvas, "fire_sparks", at - Vector2(0, 8), 0.0, float(event.r) / 40.0, p)
	if TALENT_BURSTS.has(talent): sprites.draw_at(canvas, str(TALENT_BURSTS[talent]), at, 0.0, clampf(float(event.r) / 60.0, 0.6, 2.0), p, Color.WHITE, true)
	elif TALENT_RINGS.has(talent): _ring(canvas, str(TALENT_RINGS[talent]), at, float(event.r), p)


## The events of the newer talents (src/combat/talent_combat.gd): companions'
## shots, strikes and dives, the meteor's fall, chain, explosion, spear, net,
## Erdspalter, souls, Pfeilhagel's last volley, dodge and block, "Wenig Mana".
func _extra_event(canvas: CanvasItem, event: Dictionary, at: Vector2, p: float, fade: float) -> void:
	var fx := str(event.get("fx", "steel"))
	match str(event.kind):
		"shield":
			sprites.draw_at(canvas, "shield_bubble", at + Vector2(0, -14), 0.0, 1.0, p, Color(1, 1, 1, fade))
		"pet_bolt", "pet_lance":
			# the companion's shot flies to its target over the event's first half
			var to := Vector2(float(event.get("tx", at.x)), float(event.get("ty", at.y))) - Vector2(0, 14)
			var from := at - Vector2(0, 20)
			var flight := clampf(p * 2.0, 0.0, 1.0)
			var spot := from.lerp(to, flight)
			if flight < 1.0:
				if str(event.kind) == "pet_lance" and sprites.has("ice_lance"):
					sprites.draw_loop(canvas, "ice_lance", spot, (to - from).angle(), 1.3, p)
				else:
					canvas.draw_circle(spot, 5.0, Color(0.35, 0.65, 1.0, 0.5))
					canvas.draw_circle(spot, 3.0, Color("9fdcff"))
					canvas.draw_rect(Rect2(spot - Vector2(1, 2), Vector2(2, 2)), Color.WHITE)
			else:
				sprites.draw_at(canvas, "frost_burst" if str(event.kind) == "pet_lance" else "blink", to, 0.0, 0.7, (p - 0.5) * 2.0)
		"no_res":
			# "Wenig Mana" rises over the hero and fades
			var tint: Color = {"mana": Color("7fb0ff"), "stamina": Color("9fe07a"), "rage": Color("ff7a5a")}.get(str(event.get("res", "mana")), Color.WHITE)
			var label := str(event.get("text", ""))
			var font := ThemeDB.fallback_font
			var spot := at + Vector2(-font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x * 0.5, -46 - 18 * p)
			canvas.draw_string_outline(font, spot, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 4, Color(0, 0, 0, fade))
			canvas.draw_string(font, spot, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(tint, fade))
		"explosion":
			# the Feuerball's impact: the big explosion sheet, a ring of flame and a flash
			canvas.draw_circle(at, float(event.r) * 0.6, Color(0.1, 0.06, 0.04, 0.35 * fade))
			if p < 0.15: canvas.draw_circle(at, float(event.r) * 0.9, Color(1.0, 0.9, 0.6, (0.15 - p) * 3.0))
			sprites.draw_at(canvas, "fire_explosion", at - Vector2(0, 8), 0.0, float(event.r) / 44.0, p)
			sprites.draw_at(canvas, "fire_sparks", at - Vector2(0, 8), 0.0, float(event.r) / 40.0, p)
			if p > 0.4: sprites.draw_at(canvas, "smoke_puff", at - Vector2(0, 20 + 20 * p), 0.0, float(event.r) / 36.0, (p - 0.4) / 0.6, Color(1, 1, 1, 0.7))
			_ring(canvas, "fire_ring", at, float(event.r) * 1.2, p)
		"chain":
			# Glutkette: a crackling line of embers runs from link to link, each hit flares
			var points: Array = event.get("points", [])
			var links := points.size() - 1
			for i in range(links):
				var from := Vector2(float(points[i][0]), float(points[i][1])) - Vector2(0, 14)
				var to := Vector2(float(points[i + 1][0]), float(points[i + 1][1])) - Vector2(0, 14)
				var start := float(i) / links * 0.6
				var reach := clampf((p - start) / (0.6 / links), 0.0, 1.0)
				if reach <= 0.0: continue
				var end := from.lerp(to, reach)
				var steps := maxi(3, int(from.distance_to(end) / 10.0))
				var last := from
				for k in range(1, steps + 1):
					var spot := from.lerp(end, float(k) / steps)
					if k < steps: spot += (to - from).orthogonal().normalized() * (6.0 * sin(float(k * 7 + i * 3 + int(event.id))))
					canvas.draw_line(last, spot, Color(1.0, 0.45, 0.1, fade), 4.0)
					canvas.draw_line(last, spot, Color(1.0, 0.9, 0.5, fade), 2.0)
					last = spot
				if reach >= 1.0: sprites.draw_at(canvas, "fire_burst", to + Vector2(0, 14), 0.0, 0.6, clampf((p - start) * 2.0, 0.0, 1.0))
		"meteor_fall":
			# the rune circle glows, the shadow grows while the rock falls in from the top right
			var r := float(event.r)
			sprites.draw_loop(canvas, "rune_circle", at, p * 1.5, r / 60.0, p, Color(1, 1, 1, 0.4 + 0.5 * p))
			canvas.draw_circle(at, r * (0.3 + 0.7 * p), Color(0, 0, 0, 0.18 + 0.25 * p))
			canvas.draw_arc(at, r, 0.0, TAU, 40, Color(1.0, 0.45, 0.15, 0.25 + 0.5 * p), 2.0)
			canvas.draw_circle(at, r * 0.5 * p, Color(1.0, 0.5, 0.1, 0.18 * p))
			if bool(event.get("big", false)) and sprites.has("meteor_big"):
				sprites.draw_loop(canvas, "meteor_big", at + Vector2(150, -320) * (1.0 - p), 0.0, 1.3, p * 2.0)
			else:
				sprites.draw_loop(canvas, "meteor", at + Vector2(110, -260) * (1.0 - p), 0.0, 0.9, p * 2.0)
		"spear":
			# Himmelsspeer: the golden arrow streaks to the end of its line, a bright trail behind it
			var to := Vector2(float(event.get("tx", at.x)), float(event.get("ty", at.y)))
			var head := at.lerp(to, clampf(p * 2.5, 0.0, 1.0))
			canvas.draw_line(at - Vector2(0, 14), head - Vector2(0, 14), Color(1.0, 0.9, 0.5, 0.6 * fade), 6.0)
			canvas.draw_line(at - Vector2(0, 14), head - Vector2(0, 14), Color(1, 1, 1, 0.8 * fade), 2.0)
			sprites.draw_loop(canvas, "sky_spear", head - Vector2(0, 14), (to - at).angle(), 1.4, p, Color(1, 1, 1, minf(1.0, fade * 2.0)))
		"net":
			sprites.draw_at(canvas, "net", at, 0.0, float(event.r) / 68.0, minf(1.0, p * 1.6), Color(1, 1, 1, minf(1.0, fade * 3.0)))
		"leap_slam":
			# Erdspalter: an arc through the air, then the ground breaks
			var to := Vector2(float(event.get("tx", at.x)), float(event.get("ty", at.y)))
			for i in range(10):
				var k := i / 9.0
				var dot := at.lerp(to, k) - Vector2(0, sin(k * PI) * 60.0)
				canvas.draw_rect(Rect2(dot - Vector2(2, 2), Vector2(4, 4)), Color(0.9, 0.85, 0.75, fade * (0.2 + k * 0.6)))
			sprites.draw_at(canvas, "stone_burst", to, 0.0, float(event.r) / 50.0, p)
			_ring(canvas, "steel_ring", to, float(event.r), p)
		"soul":
			# a soul flies from the enemy to the hero
			var to := Vector2(float(event.get("tx", at.x)), float(event.get("ty", at.y))) - Vector2(0, 16)
			var spot := (at - Vector2(0, 12)).lerp(to, p * p) - Vector2(0, sin(p * PI) * 30.0)
			sprites.draw_loop(canvas, "soul_wisp", spot, 0.0, 1.2, p, Color(1, 1, 1, fade))
		"pet_cleave":
			sprites.draw_at(canvas, "claw", at + Vector2(0, -14), 0.0, float(event.r) / 40.0, p)
			_ring(canvas, "steel_ring", at, float(event.r), p)
		"arrow_finale":
			# Pfeilhagel's last volley: the whole field strikes at once, dust bursting across it
			var r := float(event.r)
			for i in range(12):
				var spot := at + Vector2.from_angle(i * 2.39996) * r * sqrt((i + 0.5) / 12.0) * 0.9
				var start := float(i % 4) * 0.08
				var k := clampf((p - start) / (1.0 - start), 0.0, 1.0)
				if k <= 0.0: sprites.draw_loop(canvas, "hail_arrow", spot + Vector2(18, -150) * (1.0 - p / start), 0.12, 1.0, p)
				else: sprites.draw_at(canvas, "arrow_impact", spot, 0.0, 1.2, k)
			_ring(canvas, "quake_ring", at, r, p)
			sprites.draw_at(canvas, "wood_burst", at, 0.0, r / 50.0, p)
			sprites.draw_at(canvas, "stone_burst", at, 0.0, r / 60.0, p)
		"dive":
			# Sturzflug: the falcon drops out of the sky onto its prey, feathers in its wake
			var to := Vector2(float(event.get("tx", at.x)), float(event.get("ty", at.y)))
			var high := at - Vector2(0, 70)
			for i in range(9):
				var k := i / 8.0
				var dot := high.lerp(to - Vector2(0, 10), k)
				canvas.draw_line(dot, dot + Vector2(-3, -6), Color(0.85, 0.82, 0.78, fade * (0.2 + k * 0.7)), 2.0)
			sprites.draw_at(canvas, "claw", to + Vector2(0, -12), 0.0, 1.0, p)
		"dodge":
			# Ausweichen: afterimages along the roll, dust where it starts
			var to := Vector2(float(event.get("tx", at.x)), float(event.get("ty", at.y)))
			for i in range(5):
				var k := i / 4.0
				canvas.draw_circle(at.lerp(to, k) - Vector2(0, 14), 9.0 - i, Color(0.85, 0.95, 0.8, fade * (0.15 + k * 0.25)))
			sprites.draw_at(canvas, "dust", at, 0.0, 1.2, p)
		"dodged":
			var font := ThemeDB.fallback_font
			var spot := at + Vector2(-20, -50 - 16 * p)
			canvas.draw_string_outline(font, spot, "AUSGEWICHEN", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, 4, Color(0, 0, 0, fade))
			canvas.draw_string(font, spot, "AUSGEWICHEN", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.75, 1.0, 0.7, fade))
		"block_hit":
			# a hit stopped by the block: the shield flashes white
			canvas.draw_arc(at - Vector2(0, 16), float(event.r) * (1.0 + 0.2 * p), 0.0, TAU, 32, Color(1, 1, 1, fade), 3.0)
			sprites.draw_at(canvas, "hit_spark", at - Vector2(0, 16), 0.0, 1.4, p)
		"block_break":
			# the last hit breaks the block: it bursts into shards
			var look := str(event.get("look", "mana_bubble"))
			var shards: String = {"mana_bubble": "arcane_burst", "gold_bubble": "star_burst", "soul_bubble": "bone_burst"}.get(look, "frost_burst")
			sprites.draw_at(canvas, str(shards), at - Vector2(0, 16), 0.0, 0.75, p)
			for i in range(8):
				var dir := Vector2.from_angle(TAU * i / 8.0 + 0.3)
				var bit := at - Vector2(0, 16) + dir * float(event.r) * (0.8 + p * 1.2) + Vector2(0, 30.0 * p * p)
				canvas.draw_rect(Rect2(bit.round() - Vector2(2, 2), Vector2(4, 3)), Color(0.85, 0.9, 1.0, fade))
		"drawn":
			# the drawn line catches fire along its length
			_ring(canvas, "fire_ring", at, float(event.r) * 0.4, p)
		"pet_strike":
			# a companion's wound: blood for bleeding, dizzy stars for a blinding blow
			if str(event.get("wound", "")) == "burn":
				sprites.draw_at(canvas, "fire_burst", at - Vector2(0, 12), 0.0, 0.7, p)
			elif str(event.get("wound", "")) == "blood":
				sprites.draw_at(canvas, "blood_burst", at - Vector2(0, 12), 0.0, 0.9, p)
				for i in range(5):
					var drop := at - Vector2(0, 14) + Vector2.from_angle(PI * (1.1 + i * 0.2)) * 18.0 * p + Vector2(0, 30.0 * p * p)
					canvas.draw_rect(Rect2(drop.round(), Vector2(3, 3)), Color(0.75, 0.1, 0.12, fade))
			else:
				for i in range(4):
					var star := at - Vector2(0, 34) + Vector2(cos(p * 9.0 + i * TAU / 4.0) * 12.0, sin(p * 9.0 + i * TAU / 4.0) * 4.0)
					canvas.draw_rect(Rect2(star.round() - Vector2(2, 2), Vector2(4, 4)), Color(1.0, 0.92, 0.4, fade))
				sprites.draw_at(canvas, "crit_spark", at - Vector2(0, 16), 0.0, 1.0, p)
		"summon":
			_ring(canvas, "frost_ring" if str(event.get("kind", "")) == "water_elemental" else "arcane_ring", at, 46.0, p)
			sprites.draw_at(canvas, "level_up", at, 0.0, 1.0, p)
		"pet_fell":
			sprites.draw_at(canvas, "frost_burst" if str(event.get("kind", "")) == "water_elemental" else "crit_spark", at + Vector2(0, -12), 0.0, 1.2, p)


## A nova ring scaled so its edge meets `radius` (world px); false without the sheet.
func _ring(canvas: CanvasItem, sheet: String, at: Vector2, radius: float, p: float) -> bool:
	if not sprites.has(sheet): return false
	var edge := sprites.frame_size(sheet).x * 0.47 * FxSprites.PIXEL
	sprites.draw_at(canvas, sheet, at, 0.0, radius / maxf(1.0, edge), p)
	return true


## Cast flashes of talents without an event of their own.
func _cast(canvas: CanvasItem, talent: String, at: Vector2, p: float) -> void:
	if TALENT_CASTS.has(talent):
		var look: Array = TALENT_CASTS[talent]
		sprites.draw_at(canvas, str(look[0]), at + Vector2(0, -14), 0.0, float(look[1]), p)
		return
	match talent:
		"frost_5":
			sprites.draw_at(canvas, "shield_bubble", at + Vector2(0, -14), 0.0, 1.0, p)
		"sniper_6":
			sprites.draw_at(canvas, "star_burst", at + Vector2(0, -12), 0.0, 1.0, p)
		"beast_6":
			_ring(canvas, "shout_ring", at, 90.0, p)
		"blade_6":
			_ring(canvas, "steel_ring", at, 110.0, p)
		"trapper_6":
			sprites.draw_at(canvas, "poison_burst", at, 0.0, 2.0, p)
