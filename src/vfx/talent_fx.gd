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
## The Frostmagier's language (§4b): the Frostlanze a faceted lance with a
## glinting tip and a frost-mist trail, every ice impact a shatter in pushes
## (TalentPixels.shatter: white flash, a star of ice, cold pressure rings,
## shards flung out that lie as rime; in the particles shards that skid, rime
## growing and liquids freezing) leaving an ice pool; the Blizzard snow and
## slivers in a swirl over frost pools that spread, rime and frost gas, melting
## to water at its end; the Frostsprung an ice trail with rime crystals; the
## Kristallschild a crystal dome that cracks where it is hit and shatters at
## its end; Gletschergrab ice spires breaking out of the floor in waves over
## Glatteis. The Leerenmagier's language (§4c): a dark core whose trail is
## drawn in towards it, every void impact an implosion (the pull first, then
## the burst; TalentPixels.implosion, particles.implode) leaving a void stain;
## the Leerenriss a tear that opens into a ring; the Raumsprung a fold in
## space at both ends; Magisches Echo a darker ghost of the last spell; the
## Manaschild a dark dome with motes drifting in, rippling inwards; the
## Singularität a black core with an accretion ring and a well in the
## particles (the host swallows the puddles and the gas). Values in
## vfx_talents.json "frost" and "void".
## The Leerenmagier's Arkanes Gefüge (§4c, the pocket of swallowed elements;
## the gauge is src/ui/talent_bar.gd's): a "swallow" streams the eaten matter
## from the spot into his mouth as motes in its colours (TalentPixels.stream;
## the particles' well sucks the dust there); an "eject" bursts the units out
## as comet pixels on a spiral (TalentPixels.comets) with their matter in the
## particles (the pools are the host's); the Singularität's caught enemies
## hang on dark violet tethers with their essence flowing into the core
## (TalentPixels.tether); a "splat" (an enemy flung against a wall at the
## Urknall) bursts in its material (particles.splat_burst, vfx_gore.json
## "splat") and a rigged one comes apart along the rebound (rigs.fling_near).
## Values in vfx_talents.json "void" (swallow, eject, tether, splat).
## Matter, not paint (review 2026-10-31, BEFUND.md 5, 7, 9, 10): with the
## host's particles every flying bit of the mages' effects is a particle that
## falls, bounces, slides and lies (TalentPixels.paint_matter off: the
## painters keep the shapes). A nova's rim throws its element's matter when
## the front gets there (_rim), the boom's sparks are ember_sparks, the
## shatter's shards and mist the particles' shards and frost, the Leerenriss
## and the swallow pull motes in through a well, the caught enemies' essence
## drifts into the Singularität's well, the Blizzard's flakes fall and lie as
## frost in a wind (particles.snow), the crater's tongues are rising flames
## and embers, the Glutkette's sparks fly when each link strikes, the
## Gletschergrab's slivers break off each spire's foot as it comes up. The
## Urknall's Gefuege units are comets (particles.comet) that fly to the spots
## the host lands them on and splash there into the pool layer. The glow is
## tight and short (vfx_talents.json glow: per tier its time, radius and
## alpha), the white flash a hard pixel frame. The small talents weigh a
## little (talent_events: Raumsprung, Leerenschild, Kristallschild): the
## Raumsprung kicks the floor and flings motes where he lands, the shields
## draw their matter in as they form, chip where they are struck and burst
## into shards or motes when they go (void.fold, void.shield, frost.shield).
## Presentation only.

const FxSprites = preload("res://src/vfx/fx_sprites.gd")
const PerfMarks = preload("res://src/debug/perf_marks.gd")
const PixelPaint = preload("res://src/vfx/pixel_paint.gd")
const Glow = preload("res://src/vfx/glow.gd")
const Pal = preload("res://src/vfx/talent_palette.gd")
const TalentPixels = preload("res://src/vfx/talent_pixels.gd")
const TalentUlts = preload("res://src/vfx/talent_ults.gd")
const TalentDome = preload("res://src/vfx/talent_dome.gd")
const PoolPaint = preload("res://src/vfx/pool_paint.gd")
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
## "KRIT" over a critical hit (vfx_talents.json "crit_text" overrides): at least
## min_px screen px tall, one art cell size bigger for the first pop s.
const CRIT_TEXT := {"min_px": 16.0, "pop": 0.09}
## The gore table (assets/data/vfx_gore.json): an enemy kind's material and the splat classes.
const GORE_PATH := "res://assets/data/vfx_gore.json"
## The gore table, read on first use.
static var _gore: Dictionary = {}

var sprites := FxSprites.new()
## The companions as part rigs (src/vfx/companion_rigs.gd); `rigs` is the view's rig renderer (debris, clocks), set by the host.
var companion_rigs := CompanionRigs.new()
var rigs: RefCounted = null
## The host's lookup of an enemy by id (the Singularität's caught list): a
## Dictionary with x, y (and kind) or a Vector2; unset, an entry's own x and
## y, the zone's caught_at or the view's rigs stand in.
var enemy_at: Callable = Callable()
## The poison zones (Todeszone), burning ground (Feuersturm) and the residue
## the talents leave as physics pools that run out and stop at the walls
## (src/vfx/pool_paint.gd, set by the host with its art pixel); null draws
## dithered discs and leaves no residue.
var pools: RefCounted = null
## False when the pools are a world layer its host draws (the Hell's).
var draw_pools := true
## The talents' residue as a picture only (physics plan R4, decision D1): its own pool layer
## beside `pools`, so residue made by the drawing code never hurts, trips or freezes anyone
## (the gameplay pool layer stays deterministic).
var _residue_layer: RefCounted = null
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
## The element each hero's shield dome is drawn in, from the cast that raised
## it (Kristallschild ice, Manaschild void; the snapshot's shield has no talent): owner -> element.
var _shield_el: Dictionary = {}
## Where each hero's dome stood last and in what element (it breaks there when it goes): owner -> {at, element}.
var _dome_last: Dictionary = {}
## The heroes' last casts (Magisches Echo shows a ghost of the one it repeats): [{at, talent, angle, t}].
var _last_casts: Array = []
## The bought stage of each ultimate as last cast (its zone does not carry it): talent -> stage.
var _stages: Dictionary = {}
## When each zone was first seen and how long it had then (its age; the
## snapshot's total is its time left for zones without one): id -> [clock, left].
var _zone_born: Dictionary = {}
## Client-side impacts a moment later (a companion's lance landing): [{t, at, dir, size}].
var _later: Array = []
## Once-per-tick keys of the zones' lasting matter (Blizzard rime and frost gas): key -> when.
var _ticked: Dictionary = {}
## Particle matter that comes a moment after its event's first sight: a
## nova's rim debris when the front gets there, a chain link's sparks when it
## strikes, Gletschergrab's slivers as each spire breaks through, the
## Urknall's comets in their launch order: {t, kind, ...} (_run_deferred).
var _deferred: Array = []
## Gefüge blobs thrown into each Singularität's well so far (zone id -> count; _feed_gefuege).
var _fed: Dictionary = {}
## Keys done once (a Gletschergrab block's spires thrown): key -> when.
var _once: Dictionary = {}


func _init() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH)) if FileAccess.file_exists(DATA_PATH) else null
	cfg = parsed if parsed is Dictionary else {}
	TalentUlts.cfg = cfg
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
		# the shared, kept talents.json (src/core/data_cache.gd): the world's first cast
		# no longer parses the 112 KB file again
		var parsed: Variant = DataCache.load_json(TALENTS_PATH)
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
	# with particles the painters keep the shapes, the matter flies here
	TalentPixels.paint_matter = particles == null
	PerfMarks.begin()
	_settle_shots(clock, state)
	_observe(state, clock)
	for i in range(_later.size() - 1, -1, -1):
		var later: Dictionary = _later[i]
		if float(later.t) > clock: continue
		_later.remove_at(i)
		_shatter_at(later.at, later.dir, int(later.size), clock, 0.0)
	_run_deferred(clock)
	PerfMarks.add("tg.observe")
	var zones: Array = state.get("zones", [])
	if pools != null:
		var entries: Array = []
		for zone: Dictionary in zones:
			var length := maxf(0.3, float(zone.get("total", zone.get("time", 1.0))))
			var p := clampf(1.0 - float(zone.get("time", length)) / length, 0.0, 1.0)
			if _own_look(zone):
				_fire_look_pools(entries, zone, p, length, clock)
				_mage_look_pools(entries, zone, clock)
				continue
			entries.append({"id": int(zone.get("id", 0)), "k": "pool", "st": "fire" if str(zone.get("status", "")) == "burn" else "poison",
				"x": float(zone.x), "y": float(zone.y), "r": float(zone.r), "p": p, "L": length})
		for id: int in _ult_pools.keys():
			if float(_ult_pools[id].until) < clock: _ult_pools.erase(id)
			else: entries.append(_ult_pools[id].entry)
		pools.sync(entries, clock, "talent")
		if _residue_layer == null and pools.get("open") is Callable:
			_residue_layer = PoolPaint.new(float(pools.art), pools.open)
			_residue_layer.particles = pools.get("particles")
			_residue_layer.to_particles = float(pools.get("to_particles"))
		(_residue_layer if _residue_layer != null else pools).sync(_residue_entries(clock), clock, "talent_residue")
		PerfMarks.add("tg.pools_sync")
		if draw_pools: pools.draw(canvas, clock)
		if _residue_layer != null: _residue_layer.draw(canvas, clock)
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
	for zone: Dictionary in zones:
		_zone_matter(zone, clock)
	for drawing: Dictionary in state.get("drawings", []):
		_draw_line_preview(canvas, drawing, clock)
	_draw_looks(canvas, zones, clock)
	_draw_churns(canvas, state, clock)
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


## The frost and void mages' zones as real pools (their element's physics
## apply): the Blizzard's frost pools spreading as it blows (one more every
## frost.blizzard.grow s, round its middle), Gletschergrab's block on a big
## Glatteis pool (frost.glacier.pool_share of its radius). The Singularität
## leaves none: it swallows (the host drains the puddles round it).
func _mage_look_pools(entries: Array, zone: Dictionary, clock: float) -> void:
	var look := str(zone.get("look", ""))
	if look != "snow" and look != "ice": return
	var id := int(zone.get("id", 0))
	var at := Vector2(float(zone.x), float(zone.y))
	var r := float(zone.r)
	var life := _zone_life(zone, clock)
	var left := maxf(0.3, life.y - life.x)
	if look == "snow":
		var bz: Dictionary = cfg.get("frost", {}).get("blizzard", {})
		var n := int(bz.get("pools", 6))
		var grow := float(bz.get("grow", 0.6))
		for j in range(n):
			if life.x < float(j) * grow: break
			var spot := at if j == 0 else at + Vector2.from_angle(float(j) * 2.39996) * r * 0.55 * sqrt(float(j) / float(n)) * Vector2(1.0, 0.75)
			entries.append({"id": -(id * 64 + j + 1), "k": "pool", "st": str(bz.get("st", "frost")), "x": spot.x, "y": spot.y,
				"r": r * float(bz.get("pool_share", 0.3)) * (1.0 if j == 0 else 0.75), "p": 0.0, "L": left})
	else:
		var gl: Dictionary = cfg.get("frost", {}).get("glacier", {})
		entries.append({"id": -(id * 64 + 1), "k": "pool", "st": "ice", "x": at.x, "y": at.y, "r": r * float(gl.get("pool_share", 0.75)), "p": 0.0, "L": left})


## How long zone `zone` has lain and how long it lasts in all, s (x, y): from
## when this client first saw it, so a zone without a total still ages.
func _zone_life(zone: Dictionary, clock: float) -> Vector2:
	var id := int(zone.get("id", 0))
	var left := float(zone.get("time", 1.0))
	if not _zone_born.has(id): _zone_born[id] = [clock, maxf(left, float(zone.get("total", left)))]
	var born: Array = _zone_born[id]
	return Vector2(clock - float(born[0]), maxf(0.3, float(born[1])))


## True once every `every` s for `key` (the zones' lasting matter).
func _tick(key: String, every: float, clock: float) -> bool:
	var full := "%s:%d" % [key, int(clock / maxf(0.1, every))]
	if _ticked.has(full): return false
	_ticked[full] = clock
	if _ticked.size() > 128:
		for k: String in _ticked.keys():
			if float(_ticked[k]) < clock - 10.0: _ticked.erase(k)
	return true


## The lasting matter of the mages' zones, every frame: the Blizzard's rime
## growing over the floor at a new spot every frost.blizzard.rime_every s and
## its frost mist in the gas layer every mist_every s; the Singularität's well
## in the particles (the floor's dust, loose pixels and embers swirl in and
## are swallowed; the puddles and the gas are the host's).
func _zone_matter(zone: Dictionary, clock: float) -> void:
	var look := str(zone.get("look", ""))
	if not look in ["snow", "arcane", "crater", "ice", "souls", "plague"]: return
	var id := int(zone.get("id", 0))
	var at := Vector2(float(zone.x), float(zone.y))
	var r := float(zone.r)
	var s := to_particles
	if look == "crater":
		_crater_matter(zone, id, at, r, clock)
		return
	if look == "plague":
		# Seuchenfeld: poison fumes well up all over it and drift (motes and smoke as matter, R14;
		# no gameplay gas, so its caster is not poisoned by it)
		if particles != null and _tick("plague:%d" % id, 0.08, clock):
			var n := int(clock / 0.08)
			var spot := at + Vector2.from_angle(_h(id * 29 + n) * TAU) * r * 0.85 * sqrt(_h(id * 31 + n * 7)) * Vector2(1.0, 0.75)
			var cols := Pal.ramp_hot("poison")
			particles.motes(spot * s, 1, [cols[1], cols[2]], 18.0, 2.0, 0.5)
			if n % 3 == 0: particles.smoke(spot * s, 1, 4.0)
		return
	if look == "souls":
		# Seelensturm: a storm of souls, motes swirled round on a well that leaves the floor alone
		# (physics plan R14; its sprite loop stays as the shape)
		if particles != null:
			particles.well("souls:%d" % id, at * s, r * s, 40.0, 220.0, 1.0, 0.2, 26.0, Pal.ramp_hot("soul"), false)
		return
	if look == "ice":
		_glacier_matter(zone, id, at, r, clock)
		return
	if look == "snow":
		var bz: Dictionary = cfg.get("frost", {}).get("blizzard", {})
		_snow_matter(zone, bz, id, at, r, clock)
		var every := float(bz.get("rime_every", 1.2))
		if particles != null and _tick("bz_rime:%d" % id, every, clock):
			var n := int(clock / maxf(0.1, every))
			var spot := at + Vector2.from_angle(_h(id * 31 + n) * TAU) * r * 0.6 * _h(id * 17 + n * 3) * Vector2(1.0, 0.75)
			particles.rime_grow(spot * s, 3, r * s * float(bz.get("rime_reach", 0.35)))
			particles.frost(spot * s, r * s * 0.4, 10, Pal.ramp("ice")[3])
			particles.freeze_liquids(spot * s, r * s * 0.5)
		var mist := float(bz.get("mist_every", 1.0))
		if gas != null and _tick("bz_mist:%d" % id, mist, clock):
			gas.emit("talent_frost:%d:%d" % [id, int(clock / maxf(0.1, mist))], "frost", at, r * float(bz.get("mist_share", 0.6)), mist * 1.6, clock, Vector2.ZERO, float(bz.get("mist_dense", 0.5)))
	elif particles != null:
		var sg: Dictionary = cfg.get("void", {}).get("singularity", {})
		particles.well("talent_sing:%d" % id, at * s, r * s * float(sg.get("reach", 1.2)), float(sg.get("pull", 260)), float(sg.get("swirl", 180)),
			r * s * float(sg.get("core", 0.12)), 0.2, float(sg.get("mote_rate", 30)), [])
		_feed_gefuege(zone, id, at, r, clock)


## The Singularität's Gefüge as matter (user 2026-11-01: everything simulated, its particles fuse
## in the whirl): the units it holds (zone.mix, at most void.fuse feed_max) are thrown into its
## well from feed_rim of its radius, a blob each, over feed_share of the whirl's life, along the
## swirl at feed_throw px/s; there they circle in and fuse (particles.gd fuse_feed, _step_fusion).
## Units it swallows later are thrown in as they come.
func _feed_gefuege(zone: Dictionary, id: int, at: Vector2, r: float, clock: float) -> void:
	var held := _mix_counts(zone.get("mix", []))
	if held.is_empty(): return
	var fz: Dictionary = cfg.get("void", {}).get("fuse", {})
	var units := _unit_list(held, 1, int(fz.get("feed_max", 24)))
	var life := _zone_life(zone, clock)
	var due := mini(units.size(), ceili(float(units.size()) * clampf(life.x / maxf(0.1, life.y * float(fz.get("feed_share", 0.45))), 0.0, 1.0)))
	var fed := int(_fed.get(id, 0))
	if fed >= due: return
	if _fed.size() > 32: _fed.clear()
	var s := to_particles
	while fed < due:
		var el := str(units[fed])
		var out := Vector2.from_angle(_h(id * 13 + fed * 7) * TAU)
		var rim := at + out * r * float(fz.get("feed_rim", 0.85)) * Vector2(1.0, 0.75)
		particles.fuse_feed("talent_sing:%d" % id, rim * s - Vector2(0.0, 8.0), (-out).orthogonal() * float(fz.get("feed_throw", 60.0)) * s, el, Pal.ramp_hot(el))
		fed += 1
	_fed[id] = fed


## The Blizzard's snow: flakes fall all over it (frost.blizzard flake_rate per
## s at its strength, every snow_every s) driven round by a wind (a well that
## leaves the floor alone: wind_spin round, wind_pull in) and lie as frost
## that melts, ice slivers whirled along now and then (sliver_every s) that
## skid and lie.
func _snow_matter(zone: Dictionary, bz: Dictionary, id: int, at: Vector2, r: float, clock: float) -> void:
	if particles == null: return
	var s := to_particles
	var life := _zone_life(zone, clock)
	var k := clampf(life.x / 0.5, 0.0, 1.0) * clampf((life.y - life.x) / 0.6, 0.0, 1.0)
	if k <= 0.0: return
	var spin := float(bz.get("flake_spin", 70))
	particles.well("bz_wind:%d" % id, at * s, r * s * 1.1, float(bz.get("wind_pull", 10)), float(bz.get("wind_spin", 40)), 1.0, 0.2, 0.0, [], false)
	var every := float(bz.get("snow_every", 0.05))
	if _tick("bz_snow:%d" % id, every, clock):
		particles.snow(at * s, r * s, int(round(float(bz.get("flake_rate", 60)) * every * k)), spin * s)
	if _tick("bz_sliver:%d" % id, float(bz.get("sliver_every", 0.25)), clock):
		var n := int(clock / maxf(0.05, float(bz.get("sliver_every", 0.25))))
		var off := Vector2.from_angle(_h(id * 11 + n) * TAU) * r * 0.7 * Vector2(1.0, 0.75)
		particles.shatter((at + off) * s, 1, off.orthogonal().normalized(), float(bz.get("sliver_speed", 140)), [], 2, _u(10.0) * s)


## The meteor's crater cooling: flames licking up at a spot of it every
## fire.meteor flame_every s (buoyant, they run down the fire ramp and smoke)
## and embers rising off it now and then (ember_chance), fewer as it cools.
func _crater_matter(zone: Dictionary, id: int, at: Vector2, r: float, clock: float) -> void:
	if particles == null: return
	var me: Dictionary = cfg.get("fire", {}).get("meteor", {})
	var left := float(zone.get("time", 1.0))
	var total := maxf(0.3, float(zone.get("total", left)))
	var k := clampf(left / 1.0, 0.0, 1.0) * clampf((total - left) / 0.2, 0.0, 1.0)
	var every := float(me.get("flame_every", 0.08))
	if k <= 0.0 or not _tick("crater:%d" % id, every, clock): return
	var s := to_particles
	var n := int(clock / maxf(0.02, every))
	var spot := at + Vector2.from_angle(_h(id * 13 + n) * TAU) * r * (0.15 + 0.5 * _h(id * 7 + n * 3)) * Vector2(1.0, 0.75)
	particles.flames(spot * s, maxi(1, int(round(float(me.get("flames", 2)) * k))), [], _u(3.0) * s, 0.0)
	if _h(id + n * 5) < k * float(me.get("ember_chance", 0.6)):
		var ember: Dictionary = particles.emit(spot * s, Vector2((_h(n * 3 + id) - 0.5) * 30.0, 0.0), Pal.ramp_hot("fire")[1], 1.2, "ember", 2.0, 2.0, 40.0, 0.8)
		ember.seed = n % 997


## Gletschergrab's block comes up: as each spire breaks through the floor
## (TalentUlts.glacier_spires, the same as drawn) two slivers fly off its
## foot into the particles (frost.glacier slivers, sliver_speed) and frost
## puffs there; queued once per block.
func _glacier_matter(zone: Dictionary, id: int, at: Vector2, r: float, clock: float) -> void:
	if particles == null or _once.has("spires:%d" % id): return
	_once["spires:%d" % id] = clock
	if _once.size() > 64:
		for key: String in _once.keys():
			if float(_once[key]) < clock - 30.0: _once.erase(key)
	var age := _zone_life(zone, clock).x
	for spire: Dictionary in TalentUlts.glacier_spires(at, r, art, id):
		var when := clock + float(spire.appear) - age
		if when < clock - 0.1: continue
		_defer(maxf(clock, when), {"kind": "spire", "at": spire.pos, "out": spire.out})


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
	_shed_flight(bullet, at, aim, element, clock)
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
	TalentPixels.shot(canvas, at, aim, element, art, int(tier.get("core", 1)), int(tier.get("trail", 5)), clock, talent.hash() & 0xffff, _shot_look(tier_name, style, element, talent))
	return true


## The look a shot carries beyond its element: the Frostlanze's lance and
## frost mist (vfx_talents.json frost.lance), the void's drawn-in core with the
## Leerenlanze's tear (void.lance.crack per talent), else fire's (_fire_shot).
func _shot_look(tier: String, style: String, element: String, talent: String) -> Dictionary:
	var res := Pal.resolve(element)
	if style == "frost_lance" and res == "ice":
		var fl: Dictionary = cfg.get("frost", {}).get("lance", {})
		return {"style": "lance", "length": int(fl.get("length", {}).get(tier, 5)), "mist": float(fl.get("mist", 0.8))}
	if style == "arcane" and res == "void":
		return {"style": "void", "crack": int(cfg.get("void", {}).get("lance", {}).get("crack", {}).get(talent, 0))}
	return _fire_shot(tier, style)


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
				if not carried: _impact(at, _off_wall(at, v), str(old.element), str(old.tier), clock, str(old.talent))
	_shots_live = _shots_pass
	_live_clock = _pass_clock
	_shots_pass = []


## IMPACT of a shot of `tier` at `at` (its floor point) flying along `v`: the
## painted burst, the element's matter in the particles with a crack or
## scorch, its residue and its weight (shake and a bloom flash by tier).
## A shot that ended on a wall bursts off the wall's face (physics plan R1): its flight `v`
## mirrored on the wall's normal (found by probing the floor cells ahead of it on each axis), so
## its chips, sparks and embers fly back into the room, not into the stone; `v` unchanged in the
## open or without particles.
func _off_wall(at: Vector2, v: Vector2) -> Vector2:
	if particles == null or v.length() < 0.1: return v
	var s := to_particles
	var ahead := v.normalized() * _u(10.0)
	if not particles.solid((at + ahead) * s): return v
	var n := Vector2.ZERO
	if absf(ahead.x) > 0.01 and particles.solid((at + Vector2(ahead.x, 0.0)) * s): n.x = -signf(ahead.x)
	if absf(ahead.y) > 0.01 and particles.solid((at + Vector2(0.0, ahead.y)) * s): n.y = -signf(ahead.y)
	if n == Vector2.ZERO: n = -v.normalized()
	return v.bounce(n.normalized())


func _impact(at: Vector2, v: Vector2, element: String, tier_name: String, clock: float, talent := "") -> void:
	var tier := _shot_tier(tier_name)
	var dir := v.normalized() if v.length() > 0.1 else Vector2.RIGHT
	var size := int(tier.get("burst", 6))
	var key := _residue_key(talent, element)
	var res := Pal.resolve(element)
	var k := float(TIER_K.get(tier_name, 0.0))
	if res == "fire":
		# fire: the fat explosion (TalentPixels.boom) and its bouncing sparks
		_boom(at, dir, size, clock, k)
		if key == "lava" and particles != null:
			# the spear cracks the floor where it strikes
			particles.floor_crack(at * to_particles, _u(float(size) * 2.4) * to_particles, int(cfg.get("fire", {}).get("spear", {}).get("crack", 3)))
	elif res == "ice":
		# ice: the shatter in pushes, shards that skid, rime, liquids freezing
		_shatter_at(at, dir, size, clock, k)
	elif res == "void":
		# the void: the implosion (the pull first, then the burst)
		_implode_at(at, dir, size, clock, k, int(cfg.get("void", {}).get("lance", {}).get("crack", {}).get(talent, 0)))
	else:
		_impacts.append({"at": at, "dir": dir, "element": element, "size": size, "t0": clock, "seed": _local_id(), "kind": "", "T": IMPACT_TIME})
	if res != "ice" and res != "void":
		_matter(at, dir, element, int(tier.get("parts", 8)), int(tier.get("crack", 0)), _u(float(size) * 2.0))
	var spec: Dictionary = cfg.get("residue", {}).get(key, {})
	if not spec.is_empty():
		var cells: Array = spec.get("cells", [4, 9])
		_leave(at, dir, element, lerpf(float(cells[0]), float(cells[1]), float(TIER_K.get(tier_name, 0.0))), clock, -1.0, key)
	var feel := str(cfg.get("shots", {}).get("talent_feel", {}).get(talent, cfg.get("shots", {}).get("feel", {}).get(tier_name, "")))
	if feel != "":
		var weight: Dictionary = cfg.get("tiers", {}).get(feel, {})
		_pending_feel.append({"owner": -1, "trauma": float(weight.get("trauma", 0.0)), "shake_px": float(weight.get("shake_px", 0.0)), "hitstop": float(weight.get("hitstop", 0.0))})
		_flashes.append({"at": at + body, "col": Pal.ramp(element)[3], "t0": clock, "T": float(weight.get("flash", 0.12)), "r": float(weight.get("flash_r", 16.0)) * art, "strength": 0.5, "tier": feel})


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


## A frost impact at `at` (its floor point) reaching `size` art cells: the
## painted shatter in pushes and, in the particles, shards that skid and lie
## as frost, rime growing out of the spot, frost flecks and the liquids
## there freezing (vfx_talents.json frost.shatter: parts, rime, rime_reach,
## freeze); `k` 0..1 the weight between the smallest and the biggest.
func _shatter_at(at: Vector2, dir: Vector2, size: int, clock: float, k: float) -> void:
	var spec: Dictionary = cfg.get("frost", {}).get("shatter", {})
	_impacts.append({"at": at, "dir": dir, "element": "ice", "size": size, "t0": clock, "seed": _local_id(), "kind": "shatter", "T": float(spec.get("time", 0.7))})
	if particles == null: return
	var s := to_particles
	var p := at * s
	var r := float(size) * art * s
	var parts: Array = spec.get("parts", [8, 20])
	particles.shatter(p, int(lerpf(float(parts[0]), float(parts[1]), k)), dir * 0.5, 150.0 + 90.0 * k, [], 3)
	var rime: Array = spec.get("rime", [2, 5])
	particles.rime_grow(p, int(lerpf(float(rime[0]), float(rime[1]), k)), r * float(spec.get("rime_reach", 1.0)))
	particles.frost(p, r * 0.6, 6 + int(k * 10.0), Pal.ramp("ice")[3])
	particles.freeze_liquids(p, r * float(spec.get("freeze", 1.4)))


## A void impact at `at` reaching `size` art cells: the painted implosion
## (the pull first, then the burst; `crack` > 0 a tear across it) and, in the
## particles, the implosion that drags dust and loose pixels in before it
## throws them out, the Leerenlanze's floor crack (vfx_talents.json
## void.implode: time, pull, motes, reach); `k` 0..1 the weight.
func _implode_at(at: Vector2, dir: Vector2, size: int, clock: float, k: float, crack := 0) -> void:
	var spec: Dictionary = cfg.get("void", {}).get("implode", {})
	_impacts.append({"at": at, "dir": dir, "element": "void", "size": size, "t0": clock, "seed": _local_id(), "kind": "implode", "T": float(spec.get("time", 0.6)), "crack": crack})
	if particles == null: return
	var p := at * to_particles
	var r := float(size) * art * to_particles
	particles.implode(p, r * float(spec.get("reach", 1.4)) * (1.0 + 0.3 * k), [])
	if crack > 0: particles.floor_crack(p, r * 1.4, 2 + crack)


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


# "KRIT" over a critical hit at `at`: pixel letters on the art grid in whole
# multiples of the art cell, big enough for CRIT_TEXT.min_px on screen; one
# cell size bigger for the first CRIT_TEXT.pop s (the pop), then it rises a
# little and dithers out with `fade`.
func _crit_word(canvas: CanvasItem, at: Vector2, p: float, span: float, fade: float) -> void:
	var c: Dictionary = CRIT_TEXT.duplicate()
	c.merge(cfg.get("crit_text", {}), true)
	var screen_scale := absf(canvas.get_global_transform_with_canvas().get_scale().y)
	var cell_px := maxf(0.01, art * screen_scale)
	var mult := maxi(2, ceili(float(c.min_px) / (5.0 * cell_px)))
	if p * span < float(c.pop): mult += 1
	var cell := art * float(mult)
	TalentPixels.text(canvas, at + Vector2(0, -7.0 * art * p - 2.0 * cell), "KRIT", Pal.ramp("gold")[3], cell, fade)


# ---------- events ----------

## Effect layer: short events over everything, each played over its life
## (span), and the shots' impacts. `clock` defaults to the one of the last draw_ground.
func draw_events(canvas: CanvasItem, state: Dictionary, clock: float = -1.0) -> void:
	if clock >= 0.0: _clock = clock
	TalentPixels.paint_matter = particles == null
	PerfMarks.begin()
	for guard: Dictionary in state.get("guards", []):
		_draw_guard(canvas, guard)
	for i in range(_impacts.size() - 1, -1, -1):
		var hit: Dictionary = _impacts[i]
		var k := (_clock - float(hit.t0)) / float(hit.get("T", IMPACT_TIME))
		if k >= 1.0 or k < 0.0:
			_impacts.remove_at(i)
			continue
		match str(hit.get("kind", "")):
			"boom": TalentPixels.boom(canvas, hit.at, hit.dir, k, art, int(hit.size), int(hit.seed), cfg.get("fire", {}).get("boom", {}))
			"shatter": TalentPixels.shatter(canvas, hit.at, hit.dir, k, art, int(hit.size), int(hit.seed), cfg.get("frost", {}).get("shatter", {}))
			"implode": TalentPixels.implosion(canvas, hit.at, k, art, int(hit.size), int(hit.seed), cfg.get("void", {}).get("implode", {}), int(hit.get("crack", 0)))
			_: TalentPixels.impact(canvas, hit.at, hit.dir, k, str(hit.element), art, int(hit.size), int(hit.seed))
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
		var p := 1.0 - clampf(float(event.get("life", 0.0)) / span, 0.0, 1.0)
		var fade := 1.0 - smoothstep(0.55, 1.0, p)
		var id := int(event.get("id", 0))
		var talent := str(event.get("talent", ""))
		var element := Pal.element_of(talent, str(event.get("fx", "steel")))
		var ult := bool(event.get("ult", false))
		var stage := int(event.get("stage", 0))
		var r := float(event.get("r", 0.0))
		match str(event.kind):
			"nova":
				# the exact hit radius as a shock ring; an ultimate's is heavier;
				# the Leerenriss tears the floor open and ends in its pressure ring
				if talent == "arcane_7": TalentPixels.rift(canvas, at, r, p, art, id, cfg.get("void", {}).get("rift", {}))
				else: TalentPixels.nova(canvas, at, r, p, element, art, id, ult)
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
				if kind == "blink" and (talent == "frost_11" or talent == "arcane_5"):
					_mage_blink(canvas, talent, at, to, p, id)
					kind = ""
				else:
					TalentPixels.trail(canvas, at, to, p, element if kind == "blink" else ("beast" if kind == "leap" else element), art, id)
				match kind:
					"blink":
						TalentPixels.burst(canvas, at + body, 7, p, element, art, id)
						if talent == "fire_5": _phoenix(canvas, at, to, p, 1.0 - p, id)
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
				_crit_word(canvas, at + body * 2.1, p, span, fade)
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
				_echo(canvas, at, r, p, id)
			"swallow":
				# the Arkanes Gefüge eats: the matter streams from the spot into his mouth
				var sw: Dictionary = cfg.get("void", {}).get("swallow", {})
				var mouth := Vector2(float(event.get("tx", at.x)), float(event.get("ty", at.y))) + body * float(sw.get("mouth_lift", 1.0))
				TalentPixels.stream(canvas, at, mouth, maxf(r, _u(8.0)), _unit_list(event.get("els", {}), int(sw.get("per_unit", 2)), int(sw.get("cap", 32))), p, art, id, sw)
			"eject":
				# the Urknall empties the pocket: comet pixels on a spiral
				var ej: Dictionary = cfg.get("void", {}).get("eject", {})
				TalentPixels.comets(canvas, at, maxf(r, _u(30.0)), _unit_list(event.get("els", []), int(ej.get("per_unit", 1)), int(ej.get("cap", 40))), p, art, id, ej)
			"spit":
				# the Singularität spits the mixture from its core into every corner: globs that
				# are all the same mixture, each leaving at its own launch time (talent_combat.gd
				# _collapse)
				var sp: Dictionary = cfg.get("void", {}).get("spit", {})
				var now := p * span
				var g := 0
				for glob: Variant in event.get("globs", []):
					if not glob is Dictionary: continue
					var launch := float(glob.get("d", 0.0))
					var land := maxf(launch + 0.05, float(glob.get("t", 0.4)))
					var spot := Vector2(float(glob.get("tx", at.x)), float(glob.get("ty", at.y)))
					TalentPixels.glob(canvas, at, spot, _mix_units(glob.get("els", []), float(sp.get("per_unit", 2.0)), int(sp.get("cap", 24))), (now - launch) / (land - launch), art, _clock, id + g * 31, sp)
					g += 1
			"mix_land":
				# the mixture bursts where it lands: bits of every element's own matter thrown out
				# all round at once
				TalentPixels.splash_mix(canvas, at, r, _mix_counts(event.get("els", [])).keys(), p, art, _clock, id, int(cfg.get("void", {}).get("spit", {}).get("burst", 4)))
			"splat":
				# an enemy flung against a wall: the smack of its matter where it struck
				TalentPixels.burst(canvas, at, int(cfg.get("void", {}).get("splat", {}).get("smack", 9)), clampf(p * 2.0, 0.0, 1.0), _splat_element(str(event.get("material", "flesh"))), art, id)
			"buff":
				_buff(canvas, str(event.get("buff", "")), at, p, id)
			"cast":
				var tier := _cast_tier(talent, ult)
				if ult:
					# the ultimate's own form and its stage layers (src/vfx/talent_ults.gd)
					TalentUlts.cast(canvas, talent, at, body, r, p, stage, float(event.get("angle", 0.0)), art, _clock, id, feet)
				elif talent == "frost_5" and particles == null:
					# Kristallschild: the lasting dome is its aura; here the frost it forms from
					# (with particles: chips crystallising out of the air, _shield_cast_physics)
					TalentPixels.burst(canvas, at + body, 8, p, "ice", art, id)
				_gather(canvas, at, float(event.get("angle", 0.0)), p, span, element, tier, id)
			_:
				_extra_event(canvas, event, at, p, 1.0 - p)
		PerfMarks.add("te." + str(event.kind) + ("-ult" if ult else ""))


## The mages' blinks in their element's language: the Frostsprung an ice
## trail with rime crystals along the path and shards bursting at both ends
## (frost.sprung), the Raumsprung a fold in space at both ends (a dark ring
## collapsing where he leaves, one opening where he lands) over a dotted void
## trail (void.fold).
func _mage_blink(canvas: CanvasItem, talent: String, at: Vector2, to: Vector2, p: float, id: int) -> void:
	if talent == "frost_11":
		var fs: Dictionary = cfg.get("frost", {}).get("sprung", {})
		var size := int(fs.get("end_size", 7))
		var shatter: Dictionary = cfg.get("frost", {}).get("shatter", {})
		TalentPixels.ice_trail(canvas, at, to, p, art, id, float(fs.get("every", 4)))
		TalentPixels.shatter(canvas, at + body * 0.5, (at - to).normalized() if at != to else Vector2.ZERO, clampf(p * 1.4, 0.0, 1.0), art, size - 2, id, shatter)
		TalentPixels.shatter(canvas, to + body * 0.5, Vector2.ZERO, (p - 0.15) * 1.4, art, size, id + 1, shatter)
	else:
		var vf: Dictionary = cfg.get("void", {}).get("fold", {})
		var size := int(vf.get("size", 9))
		TalentPixels.void_dots(canvas, at, to, p, art, id, int(vf.get("dots", 3)))
		TalentPixels.fold(canvas, at + body, p / 0.45, true, size, art, id)
		TalentPixels.fold(canvas, to + body, (p - 0.2) / 0.6, false, size, art, id + 1)


## Magisches Echo: a darker violet ghost of the spell it repeats (the hero's
## last cast near `at`): a ghost shot along its aim for a shot, a ghost ring
## for a nova or zone, else a ghost gather; and a faint ghost ring at his feet.
func _echo(canvas: CanvasItem, at: Vector2, r: float, p: float, id: int) -> void:
	var last := {}
	for cast: Dictionary in _last_casts:
		if Vector2(cast.at).distance_to(at) < _u(90.0) and (last.is_empty() or float(cast.t) > float(last.t)): last = cast
	var kind := "gather"
	if not last.is_empty():
		match _type_of(str(last.talent)):
			"projectile": kind = "shot"
			"nova", "zone": kind = "ring"
	TalentPixels.echo(canvas, at + body, float(last.get("angle", 0.0)), kind, _u(float(cfg.get("void", {}).get("echo", {}).get("ring", 60))), p, art, id)
	TalentPixels.echo(canvas, at, 0.0, "ring", maxf(r, _u(26.0)), p, art, id + 1)


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
			# a shield dome is its own talent's element (Schildwall stone, Seelenschild soul); the mage's
			# two shields are remembered at their cast (physics plan F27)
			var element := str(_shield_el.get(owner, Pal.element_of(str(aura.get("talent", "")), str(spec[2])))) if str(spec[0]) == "shield" else str(spec[2])
			_dome_last[owner] = {"at": _snap(at), "element": element}
			dome.draw(canvas, _snap(at) + feet, clampf((total - left) / 0.3, 0.0, 1.0), clampf(left / 0.6, 0.0, 1.0), element, art, clock)
	for owner: int in _domes.keys():
		if not shown.has(owner):
			_domes.erase(owner)
			_dome_end(owner, clock)


## A shield dome that just went (it ran out or broke): the crystal one
## shatters (a painted shatter at the hero's chest, shards and frost in the
## particles; frost.shield), the void one folds in on itself (an implosion; void.shield).
func _dome_end(owner: int, clock: float) -> void:
	var last: Dictionary = _dome_last.get(owner, {})
	_dome_last.erase(owner)
	if last.is_empty(): return
	var foot: Vector2 = last.at
	match Pal.resolve(str(last.element)):
		"ice":
			var fs: Dictionary = cfg.get("frost", {}).get("shield", {})
			_impacts.append({"at": foot + body, "dir": Vector2.ZERO, "element": "ice", "size": int(fs.get("end_size", 10)), "t0": clock, "seed": _local_id(), "kind": "shatter",
				"T": float(cfg.get("frost", {}).get("shatter", {}).get("time", 0.7))})
			if particles != null:
				# the dome bursts at chest height: its shards fall, skid and lie as frost
				var s := to_particles
				particles.shatter((foot + body * 0.5) * s, int(fs.get("shards", 16)), Vector2.ZERO, float(fs.get("shard_speed", 150)), [], 3, -body.y * 0.5 * s)
				particles.frost(foot * s, _u(18.0) * s, 12, Pal.ramp("ice")[3])
		"void":
			var vs: Dictionary = cfg.get("void", {}).get("shield", {})
			_implode_at(foot + body * 0.5, Vector2.ZERO, int(vs.get("end_size", 8)), clock, 0.3)
			if particles != null:
				# the dome folds in, then its motes are thrown out and the floor kicked
				var s := to_particles
				var vo := Pal.ramp("void")
				particles.motes(foot * s, int(vs.get("end_motes", 16)), [vo[3], vo[4], vo[2]], 3.0, -body.y * 0.5 * s, float(vs.get("end_speed", 2.4)))
				particles.kick(foot * s, _u(float(vs.get("cast_r", 30))) * s, 0.6)


## Bloom (the host's additive glow layer, `level` its strength): the flashes
## of weighty events in their element's colour, the shots in flight and their
## impacts, and a faint light of the lasting buffs; small, never a white-hot core.
## The light is tight and short so it never washes the pixels out (review
## 2026-10-31; vfx_talents.json glow): a flash lasts at most glow.flash_s of
## its tier, reaches at most glow.flash_r art cells at glow.flash_alpha; an
## impact's light (boom, shatter, implode, other) lives glow.<kind>.s, r x its
## size, alpha; a shot's glow.shot.r x its tier glow cells at its alpha.
func draw_glow(canvas: CanvasItem, state: Dictionary, level: float, clock: float, where: Callable) -> void:
	if level <= 0.0: return
	var gl: Dictionary = cfg.get("glow", {})
	for i in range(_flashes.size() - 1, -1, -1):
		var flash: Dictionary = _flashes[i]
		var tier := str(flash.get("tier", "small"))
		var length := minf(float(flash.T), float(gl.get("flash_s", {}).get(tier, 0.06)))
		var k := (clock - float(flash.t0)) / maxf(0.01, length)
		if k >= 1.0 or k < 0.0:
			_flashes.remove_at(i)
			continue
		var reach := minf(float(flash.r), float(gl.get("flash_r", {}).get(tier, 10)) * art)
		var alpha := minf(float(flash.strength), float(gl.get("flash_alpha", {}).get(tier, 0.2)))
		Glow.dot(canvas, flash.at, reach, Color(flash.col, alpha * (1.0 - k) * level))
	var shot_spec: Dictionary = gl.get("shot", {})
	for shot: Dictionary in (_shots_pass if not _shots_pass.is_empty() else _shots_live):
		Glow.dot(canvas, shot.at, float(shot.glow) * art * float(shot_spec.get("r", 0.6)), Color(Pal.ramp(str(shot.element))[3], float(shot_spec.get("alpha", 0.18)) * level))
	for hit: Dictionary in _impacts:
		var age := clock - float(hit.t0)
		var hit_kind := str(hit.get("kind", ""))
		var spec: Dictionary = gl.get(hit_kind if hit_kind in ["boom", "shatter", "implode"] else "impact", {})
		var start := 0.0
		if hit_kind == "implode":
			# the void swallows light while it pulls; only its burst glows, faintly
			start = float(cfg.get("void", {}).get("implode", {}).get("pull", 0.25)) * float(hit.get("T", IMPACT_TIME))
		var k := (age - start) / maxf(0.01, float(spec.get("s", 0.05)))
		if k < 0.0 or k >= 1.0: continue
		var col: Color = Pal.ramp("fire")[4] if hit_kind == "boom" else (Pal.ramp("ice")[4] if hit_kind == "shatter" else Pal.ramp(str(hit.element))[3])
		Glow.dot(canvas, hit.at, float(hit.size) * art * float(spec.get("r", 1.0)), Color(col, float(spec.get("alpha", 0.25)) * (1.0 - k) * level))
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
	# a talent's own weight for one of its events (the small mage talents)
	var own: Dictionary = cfg.get("talent_events", {})
	var key := "%s:%s" % [str(event.get("talent", "")), kind]
	if own.has(key): return str(own[key])
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
		if kind == "swallow" or kind == "eject" or kind == "spit": element = "void"
		elif kind == "mix_land" and not _mix_counts(event.get("els", [])).is_empty(): element = str(_mix_counts(event.get("els", [])).keys()[-1])
		elif kind == "splat": element = _splat_element(str(event.get("material", "flesh")))
		if tier != "":
			var spec: Dictionary = cfg.get("tiers", {}).get(tier, {})
			_flashes.append({"at": at + body, "col": Pal.ramp(element)[3], "t0": clock,
				"T": float(spec.get("flash", 0.15)) * _boost(event), "r": float(spec.get("flash_r", 20.0)) * art * _boost(event), "strength": 0.5, "tier": tier})
		if bool(event.get("ult", false)): _ult_pool(event, state, clock)
		match kind:
			"cast":
				# the mages remember what they cast: the shield's element, the echo's spell, the ultimate's stage
				var owner := int(event.get("owner", -1))
				if talent == "frost_5": _shield_el[owner] = "ice"
				elif talent == "arcane_11": _shield_el[owner] = "void"
				if talent != "arcane_3":
					_last_casts.append({"at": at, "talent": talent, "angle": float(event.get("angle", 0.0)), "t": clock})
					if _last_casts.size() > 8: _last_casts.pop_front()
				if bool(event.get("ult", false)): _stages[talent] = int(event.get("stage", 0))
				# the shields draw their matter in as they form
				if talent == "frost_5": _shield_cast_physics(at, "ice")
				elif talent == "arcane_11": _shield_cast_physics(at, "void")
				elif talent == "frost_14" and bool(event.get("ult", false)): _glacier_throw(event, at, clock)
			"pet_lance":
				# the companion's ice lance lands halfway through the event: it shatters there
				var to := Vector2(float(event.get("tx", at.x)), float(event.get("ty", at.y)))
				_later.append({"t": clock + maxf(0.05, float(event.get("span", 0.5))) * 0.5, "at": to, "dir": (to - at).normalized() if to != at else Vector2.ZERO,
					"size": int(cfg.get("frost", {}).get("pet_lance", 5))})
			"nova":
				if talent == "frost_14" and not bool(event.get("wave", false)):
					# Gletschergrab lands: a cold white flash over the block
					var big: Dictionary = cfg.get("tiers", {}).get("large", {})
					_flashes.append({"at": at, "col": Pal.ramp("ice")[4], "t0": clock, "T": float(big.get("flash", 0.28)), "r": float(big.get("flash_r", 40)) * art, "strength": 0.6, "tier": "large"})
				if bool(event.get("impact", false)):
					# the meteor's landing: the huge boom, rock and lava
					var me: Dictionary = cfg.get("fire", {}).get("meteor", {})
					var size: Array = me.get("size", [12, 24])
					_boom(at, Vector2.ZERO, int(clampf(r / art * float(me.get("size_share", 0.4)), float(size[0]), float(size[1]))), clock, 1.0)
				_burst_physics(at, r, element, bool(event.get("ult", false)), bool(event.get("impact", false)), clock, talent)
				# the rim's matter when the front gets there; the Leerenriss pulls motes in
				if talent == "arcane_7": _rift_physics(event, at, r)
				else: _defer_rim(at, r, element, bool(event.get("ult", false)), event, clock)
			"explosion":
				# the Feuerball's splash: the fat explosion over the hit radius
				var bo: Dictionary = cfg.get("fire", {}).get("boom", {})
				var size: Array = bo.get("size", [8, 16])
				_boom(at, Vector2.ZERO, int(clampf(r / art * float(bo.get("size_share", 0.5)), float(size[0]), float(size[1]))), clock, 0.6)
				_burst_physics(at, r, "fire", false, false, clock, talent)
				_defer_rim(at, r, "fire", false, event, clock)
			"buff":
				# the buffs that ring out (bloodlust, unbreakable, timebreak): their rim's matter
				var ring := {"bloodlust": [70.0, "blood"], "unbreakable": [80.0, "stone"], "timebreak": [90.0, "void"]}
				var buff := str(event.get("buff", ""))
				if ring.has(buff): _defer_rim(at, _u(float(ring[buff][0])), str(ring[buff][1]), true, event, clock)
			"chain":
				# every link's hit when the chain gets there: sparks off the target, it burns for a while
				var ch: Dictionary = cfg.get("fire", {}).get("chain", {})
				var points: Array = event.get("points", [])
				var links := points.size() - 1
				var span := maxf(0.05, float(event.get("span", 0.5)))
				for i in range(1, points.size()):
					var hit := Vector2(float(points[i][0]), float(points[i][1]))
					var prev := Vector2(float(points[i - 1][0]), float(points[i - 1][1]))
					var strikes := (float(i - 1) / maxf(1.0, float(links)) * 0.6 + 0.6 / maxf(1.0, float(links))) * span
					var entry := {"kind": "link", "at": hit, "prev": prev, "element": element, "n": int(ch.get("sparks", 6)), "burn": float(ch.get("burn", 0.6)), "seed": id + i, "sparks": int(ch.get("link_sparks", 3))}
					if particles == null: _link_hit(entry, clock)
					else: _defer(clock + strikes, entry)
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
				_defer_rim(Vector2(float(event.get("tx", at.x)), float(event.get("ty", at.y))), r, "stone", true, event, clock)
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
				# the blow dents the hero's dome on the side it came from, chips fly off there
				_dome(int(event.get("owner", 1))).hit(Vector2(float(event.get("dx", 0.0)), float(event.get("dy", 1.0))), float(event.get("power", 1.0)), clock)
				_dome_hit_physics(event, at)
			"summon":
				_defer_rim(at, _u(46.0), "ice" if str(event.get("kind", "")) == "water_elemental" else "bone", false, event, clock)
			"pet_cleave":
				_defer_rim(at, r, "steel", false, event, clock)
			"arrow_finale":
				_defer_rim(at, r, "stone", true, event, clock)
			"drawn":
				_defer_rim(at, r * 0.4, "fire", false, event, clock)
			"swallow":
				_swallow_physics(event, at, r)
			"eject":
				_eject_physics(event, at, clock)
			"spit":
				_spit_physics(event, at, clock)
			"churn":
				_churn_physics(event, at, r, clock)
			"splat":
				_splat_physics(event, at, r)
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
	if talent == "frost_11" and particles != null:
		# Frostsprung: shards at both ends, frost and rime along the path, the landing's liquids freeze
		var s := to_particles
		var ice := Pal.ramp("ice")
		particles.shatter(to * s, 14, Vector2.ZERO, 160.0, [], 3)
		var every := _u(float(cfg.get("frost", {}).get("sprung", {}).get("frost_every", 12)))
		var n := maxi(1, int(at.distance_to(to) / maxf(1.0, every)))
		for i in range(n + 1):
			particles.frost(at.lerp(to, float(i) / float(n)) * s, _u(6.0) * s, 4, ice[3])
		particles.rime_grow(to * s, 3, _u(22.0) * s)
		particles.freeze_liquids(to * s, _u(30.0) * s)
		_leave(to, Vector2.ZERO, "ice", float(cfg.get("residue", {}).get("ice", {}).get("cells", [4, 10])[0]), clock)
	if talent == "arcane_5" and particles != null:
		# Raumsprung: space opens where he lands: a shove that kicks the floor's
		# loose pixels up and pushes what flies, motes flung out, dust rolling
		# off (void.fold); where he left the implosion drags it all in (below)
		var vf: Dictionary = cfg.get("void", {}).get("fold", {})
		var vo := Pal.ramp("void")
		var s := to_particles
		var reach := _u(float(vf.get("kick_r", 24))) * s
		particles.kick(to * s, reach, float(vf.get("kick", 0.8)))
		particles.blow(to * s, 0.0, reach * 1.6, 0.0, TAU, float(vf.get("blow_speed", 220)))
		particles.motes(to * s, int(vf.get("motes_out", 14)), [vo[3], vo[4], vo[2]], 4.0, -body.y * s * 0.6, float(vf.get("mote_speed", 2.2)))
		particles.dust_flat(to * s, reach * 0.5, int(vf.get("dust", 6)))
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
		_zone_born.erase(id)
		if str(zone.get("look", "")) == "ice":
			# Gletschergrab's spires break as the block goes
			_shatter_at(Vector2(float(zone.x), float(zone.y)), Vector2.ZERO, int(cfg.get("frost", {}).get("glacier", {}).get("end_size", 14)), clock, 1.0)
		# a zone lying as a pool of its own leaves none: its pool goes rim first by itself
		if str(zone.get("pool", "")) != "": continue
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

## What stays of the Singularität's mixture in its explosion zone (events "churn",
## talent_combat.gd _collapse): its clump churning on the ground over its field, under the heroes
## and enemies, drops of it jumping out (TalentPixels.churn, void.churn).
func _draw_churns(canvas: CanvasItem, state: Dictionary, clock: float) -> void:
	var ch: Dictionary = cfg.get("void", {}).get("churn", {})
	for event: Dictionary in state.get("events", []):
		if str(event.get("kind", "")) != "churn": continue
		var span := maxf(0.05, float(event.get("span", 0.5)))
		var p := 1.0 - clampf(float(event.get("life", 0.0)) / span, 0.0, 1.0)
		TalentPixels.churn(canvas, Vector2(float(event.x), float(event.y)), float(event.get("r", 0.0)), _mix_units(event.get("els", []), float(ch.get("per_unit", 2.0)), int(ch.get("cap", 30))), p, art, clock, int(event.get("id", 0)), ch)


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
				# Gletschergrab: ice spires breaking out of the floor in waves over its Glatteis (draw_ground)
				var life := _zone_life(zone, clock)
				TalentUlts.glacier_field(canvas, at, r, life.y - life.x, life.y, int(_stages.get(str(zone.get("talent", "")), int(zone.get("stage", 0)))), art, clock, int(zone.get("id", 0)))
			"arcane":
				# Singularität: a black core with its accretion ring, the floor drawn in (the well is the particles')
				var life := _zone_life(zone, clock)
				var k := clampf(life.x / 0.4, 0.0, 1.0) * clampf((life.y - life.x) / 0.3, 0.0, 1.0)
				TalentPixels.singularity(canvas, at, r, k, art, clock, int(zone.get("id", 0)), int(_stages.get(str(zone.get("talent", "")), int(zone.get("stage", 0)))), cfg.get("void", {}).get("singularity", {}))
				_draw_caught(canvas, zone, at, k, clock)
				# the Gefüge's elements swirl round the core and run together into one mixture (zone.mix)
				var held := _mix_counts(zone.get("mix", []))
				if not held.is_empty():
					var mx: Dictionary = cfg.get("void", {}).get("mix", {})
					TalentPixels.mixing(canvas, at, r, _unit_list(held, 1, int(mx.get("cap", 30))), life.x / life.y, k, art, clock, int(zone.get("id", 0)), mx)
			"snow":
				# Blizzard: snow and slivers driven in a swirl over its frost pools (draw_ground)
				var life := _zone_life(zone, clock)
				var k := clampf(life.x / 0.5, 0.0, 1.0) * clampf((life.y - life.x) / 0.6, 0.0, 1.0)
				TalentPixels.blizzard(canvas, at, r, k, art, clock, int(zone.get("id", 0)), cfg.get("frost", {}).get("blizzard", {}))
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
				# Seuchengrube: sickly green-violet clouds over bubbling ground; the Seuchenfeld lies as
				# its own plague pool (the pool layer draws it), so no painted ground there
				if str(zone.get("pool", "")) == "" or pools == null:
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
func _phoenix(canvas: CanvasItem, at: Vector2, to: Vector2, p: float, fade: float, id := 0) -> void:
	var flight := minf(1.0, p * 1.3)
	var bird := at.lerp(to, flight) - Vector2(0, 22)
	var fire := Pal.ramp("fire")
	if particles != null and flight < 1.0:
		# real embers off the bird, per second, falling from its height (physics plan R17)
		var hot := Pal.ramp_hot("fire")
		var back := (at - to).normalized() if to != at else Vector2.ZERO
		for k in range(_shed_count(910000 + id, 50.0)):
			particles.emit((bird + back * 6.0) * to_particles, (back * randf_range(10.0, 40.0) + Vector2(randf_range(-12.0, 12.0), 0.0)) * to_particles,
				hot[1 + k % 2], randf_range(0.4, 0.8), "ember", 2.0, 22.0 * to_particles, randf_range(4.0, 14.0), 2.0)
	elif particles == null:
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
		var size := int(clampf(r / art * 0.25, 4.0, 10.0))
		match Pal.resolve(element):
			"ice":
				# frost novas (the Wasserelementar's Frostnova, Gletschergrab's landing) shatter
				if talent == "frost_14": size = int(cfg.get("frost", {}).get("glacier", {}).get("burst_size", 16))
				TalentPixels.shatter(canvas, at, Vector2.ZERO, p, art, size, id, cfg.get("frost", {}).get("shatter", {}))
			"void":
				if talent != "arcane_7": TalentPixels.implosion(canvas, at, p, art, size, id, cfg.get("void", {}).get("implode", {}))
			_:
				TalentPixels.impact(canvas, at, Vector2.ZERO, p, element, art, size, id)


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
			if lance:
				# the Wasserelementar's ice lance: a small Frostlanze; it shatters where it lands (_later)
				if flight < 1.0: TalentPixels.shot(canvas, _snap(spot), to - from, "ice", art, 1, 4, _clock, id, {"style": "lance", "length": 4, "mist": 0.7})
			elif flight < 1.0: TalentPixels.shot(canvas, _snap(spot), to - from, "void", art, 1, 4, _clock, id)
			else: TalentPixels.burst(canvas, to, 5, (p - 0.5) * 2.0, "void", art, id)
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
			# embers streaming off the rock: real embers shed per second where there are particles
			# (physics plan R17), else painted
			if particles != null:
				var key := 900000 + id
				var last: Vector2 = _shed_due.get(key, Vector2(_clock, 0.0))
				var carry := last.y + clampf(_clock - last.x, 0.0, 0.1) * 40.0
				var n := int(carry)
				_shed_due[key] = Vector2(_clock, carry - float(n))
				var hot := Pal.ramp_hot("fire")
				for k in range(n):
					particles.emit((rock + fall.normalized() * 10.0) * to_particles, fall.normalized().rotated(randf_range(-0.5, 0.5)) * randf_range(20.0, 60.0) * to_particles, hot[1 + k % 2], randf_range(0.4, 0.8), "ember", 2.0, 0.0, randf_range(10.0, 30.0), 2.0)
			else:
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
			if particles != null:
				# real feathers in its wake that flutter down (flake: air drag, wind) and a puff where it
				# strikes (physics plan R17)
				var dive := clampf(p * 2.0, 0.0, 1.0)
				var head := high.lerp(to - Vector2(0, 10), dive)
				var n := _shed_count(930000 + id, 26.0) if dive < 1.0 else (0 if _puffed.has(id) else 7)
				if dive >= 1.0: _puffed[id] = true
				if _puffed.size() > 64: _puffed.clear()
				for k in range(n):
					var lift := maxf(0.0, to.y - head.y)
					particles.emit(head * to_particles, Vector2(randf_range(-40.0, 40.0), randf_range(-30.0, 10.0)) * to_particles,
						beast[2 + k % 2], randf_range(1.2, 2.2), "flake", 2.0, lift * to_particles, 0.0, float(_mode_drag("flake")))
			else:
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
			# with particles its shards are theirs (_matter; physics plan R17/F31)
			for i in range(8 if particles == null else 0):
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
				for i in range(5 if particles == null else 0):
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


# ---------- the Arkanes Gefüge ----------

## The gore table (assets/data/vfx_gore.json), read once.
static func gore() -> Dictionary:
	if _gore.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(GORE_PATH)) if FileAccess.file_exists(GORE_PATH) else null
		_gore = parsed if parsed is Dictionary else {"materials": {}, "kinds": {}}
	return _gore


## The element a splat of `material` is drawn in: its class (vfx_gore.json
## splat.class: flesh, bone, void, gold) to void.splat.element of vfx_talents.json.
func _splat_element(material: String) -> String:
	var cls := str(gore().get("splat", {}).get("class", {}).get(material, material))
	return str(cfg.get("void", {}).get("splat", {}).get("element", {}).get(cls, "blood"))


## The units of a Gefüge event as element names, `per` per unit, at most
## `cap`, mixed round-robin so the colours interleave: `els` a {el: n} of a
## swallow or a [el, ...] of an eject.
static func _unit_list(els: Variant, per: int, cap: int) -> Array:
	var groups: Array = []
	if els is Dictionary:
		for el: Variant in els: groups.append([str(el), maxi(0, int(els[el])) * maxi(1, per)])
	elif els is Array:
		for el: Variant in els: groups.append([str(el), maxi(1, per)])
	var out: Array = []
	var left := true
	while left and out.size() < cap:
		left = false
		for group: Array in groups:
			if int(group[1]) <= 0: continue
			out.append(group[0])
			group[1] = int(group[1]) - 1
			left = true
			if out.size() >= cap: break
	return out


## SWALLOW's physics: a short well at the eaten spot sucks the loose dust and
## pixels in (void.swallow well_*), and void motes puff at the mouth.
func _swallow_physics(event: Dictionary, at: Vector2, r: float) -> void:
	if particles == null: return
	var sw: Dictionary = cfg.get("void", {}).get("swallow", {})
	var s := to_particles
	var reach := maxf(r, _u(float(sw.get("well_r", 20)))) * s
	particles.well("swallow:%d" % int(event.get("id", 0)), at * s, reach, float(sw.get("well_pull", 300)), float(sw.get("well_swirl", 160)), reach * 0.15, float(sw.get("well_time", 0.35)))
	var mouth := Vector2(float(event.get("tx", at.x)), float(event.get("ty", at.y))) + body * float(sw.get("mouth_lift", 1.0))
	var vo := Pal.ramp("void")
	particles.motes(mouth * s, int(sw.get("mouth_motes", 5)), [vo[3], vo[4], vo[2]], 4.0)
	# the eaten matter streams to him: motes in its colours rise off the spot,
	# thrown towards him, and a well at his feet pulls them round and in
	var feet_at := Vector2(float(event.get("tx", at.x)), float(event.get("ty", at.y)))
	var high := -body.y * float(sw.get("mouth_lift", 1.0)) * s
	var id := int(event.get("id", 0))
	var far := maxf(_u(30.0), feet_at.distance_to(at) * 1.3)
	particles.well("gulp:%d" % id, feet_at * s, far * s, float(sw.get("mouth_pull", 380)), float(sw.get("mouth_swirl", 160)), _u(4.0) * s,
		maxf(0.3, float(event.get("span", 0.6))), 0.0, [], false)
	var els := _unit_list(event.get("els", {}), int(sw.get("per_unit", 2)), int(sw.get("cap", 32)))
	var spread := maxf(r, _u(8.0))
	for i in range(particles.room(els.size())):
		var cols := Pal.ramp_hot(str(els[i]))
		var start := at + Vector2.from_angle(_h(id + i * 13) * TAU) * spread * sqrt(_h(id + i * 17)) * Vector2(1.0, 0.75)
		var toward := (feet_at - start).normalized().rotated((_h(id + i * 29) - 0.5) * 1.6) if feet_at != start else Vector2.UP
		var mote: Dictionary = particles.emit(start * s - Vector2(0.0, 2.0), toward * float(sw.get("mote_speed", 70)) * s, cols[0] if i % 3 == 0 else cols[1], float(sw.get("mote_life", 1.2)), "mote", 2.0, 2.0, 0.0, 0.2)
		mote.streak = true
		mote.z_to = high


## EJECT's physics: every bolt of the Gefuege (event els: {el, n, tx, ty, t})
## is a comet in the particles (particles.comet) that leaves the core in
## its launch order and flies a ballistic arc onto the very spot the host
## lands it on, arriving when the host's landing happens (t s after the
## collapse; void.eject fly_share of it in the air, at least fly_min). How it
## lands is its element's (void.eject kind: liquids and fire splash into the
## pool layer as pool_mat, ice breaks, bone and gold bounce, souls puff); the
## lasting pool there is the host's. A few bolts, a few landings (gefuege
## eject_max in madness_rules.json gefuege).
func _eject_physics(event: Dictionary, at: Vector2, clock: float) -> void:
	if particles == null: return
	var ej: Dictionary = cfg.get("void", {}).get("eject", {})
	var bolts: Variant = event.get("els", [])
	if not bolts is Array: return
	for bolt: Variant in bolts:
		if not bolt is Dictionary or not (bolt as Dictionary).has("tx"): continue
		var t := float(bolt.get("t", 0.4))
		var fly := clampf(t * float(ej.get("fly_share", 0.85)), minf(t, float(ej.get("fly_min", 0.18))), maxf(t, 0.05))
		_defer(clock + t - fly, {"kind": "comet", "from": at, "to": Vector2(float(bolt.tx), float(bolt.ty)), "fly": fly, "el": Pal.resolve(str(bolt.get("el", "void"))), "n": int(bolt.get("n", 1))})


## SPIT's physics (the Singularität's mixture): for every glob, one comet per element of the
## mixture (particles.comet), leaving at the glob's launch time on its path, a little apart
## (void.spit.spread crypt px), so each glob flies as one mass; each lands as its element into
## the pool layer (void.eject kind and pool_mat), where the host's pools then react.
func _spit_physics(event: Dictionary, at: Vector2, clock: float) -> void:
	if particles == null: return
	# the fused Gefüge leaves the air: its matter flies from where the clump floats
	var zone := int(event.get("zone", -1))
	var held: Dictionary = particles.fuse_take("talent_sing:%d" % zone) if zone >= 0 else {}
	_fed.erase(zone)
	var from := at
	if not held.is_empty(): from = Vector2(held.pos) / to_particles
	var spread := _u(float(cfg.get("void", {}).get("spit", {}).get("spread", 6)))
	for glob: Variant in event.get("globs", []):
		if not glob is Dictionary: continue
		var launch := float(glob.get("d", 0.0))
		var fly := maxf(0.05, float(glob.get("t", 0.4)) - launch)
		var to := Vector2(float(glob.get("tx", at.x)), float(glob.get("ty", at.y)))
		var parts := _mix_counts(glob.get("els", []))
		var j := 0
		for part: String in parts:
			var off := Vector2.from_angle(TAU * float(j) / float(maxi(1, parts.size()))) * spread
			_defer(clock + launch, {"kind": "comet", "from": from, "to": to + off, "fly": fly, "el": Pal.resolve(part), "n": maxi(1, ceili(float(parts[part])))})
			j += 1


## CHURN's physics (what stays of the Singularität's mixture in its explosion zone): it drops onto
## the core at once (a comet per element, void.churn drop_fly s, each landing by what it is); over
## comet_share of its life its matter bubbles up in the field every bits_every s (_bits) and
## comets drops of its elements (particles.comet) hop out of the core into its field (comet_reach
## share of its radius, comet_fly s each), each landing as its element into the pool layer, where
## the host's pools then react.
func _churn_physics(event: Dictionary, at: Vector2, r: float, clock: float) -> void:
	if particles == null: return
	var ch: Dictionary = cfg.get("void", {}).get("churn", {})
	var shares := _mix_counts(event.get("els", []))
	var kinds := shares.keys()
	if kinds.is_empty(): return
	var id := int(event.get("id", 0))
	# what stays drops onto the core at once, each element landing by what it is
	for k in range(kinds.size()):
		var spot := at + Vector2.from_angle(TalentPixels._rnd(id, k + 60) * TAU) * r * 0.25 * TalentPixels._rnd(id, k + 70)
		_defer(clock, {"kind": "comet", "from": at, "to": spot, "fly": float(ch.get("drop_fly", 0.15)), "el": Pal.resolve(str(kinds[k])), "n": maxi(1, ceili(float(shares[kinds[k]])))})
	# and its matter goes on bubbling up in the field: flames, drops, slivers by its elements
	var every := float(ch.get("bits_every", 0.3))
	var steps := int(float(event.get("life", 2.5)) * float(ch.get("comet_share", 0.6)) / maxf(0.05, every))
	for k in range(steps):
		var spot := at + Vector2.from_angle(TalentPixels._rnd(id, k + 300) * TAU) * r * 0.7 * sqrt(TalentPixels._rnd(id, k + 310))
		_defer(clock + every * float(k + 1), {"kind": "bits", "at": spot, "el": str(kinds[k % kinds.size()])})
	var count := int(ch.get("comets", 8))
	var window := float(event.get("life", 2.5)) * float(ch.get("comet_share", 0.6))
	var reach: Array = ch.get("comet_reach", [0.45, 0.95])
	for i in range(count):
		var away := Vector2.from_angle(TAU * float(i) / float(maxi(1, count)) + TalentPixels._rnd(id, i) * 1.4)
		var to := at + away * r * lerpf(float(reach[0]), float(reach[1]), TalentPixels._rnd(id, i + 30))
		_defer(clock + window * float(i) / float(maxi(1, count)), {"kind": "comet", "from": at, "to": to, "fly": float(ch.get("comet_fly", 0.35)), "el": Pal.resolve(str(kinds[i % kinds.size()])), "n": 2})


## Bits of an element's own matter thrown up at entry.at (a deferred "bits", the churn): fire
## flames, water, poison and blood drops, ice slivers, bone and gold chips, the rest motes.
func _bits(entry: Dictionary) -> void:
	var el := str(entry.el)
	var at := Vector2(entry.at) * to_particles
	var cols := Pal.ramp_hot(el)
	match el:
		"fire", "lava": particles.flames(at, 2, cols, 3.0, 0.0)
		"water", "poison", "blood": particles.drops(at, 2, Vector2.ZERO, [cols[1], cols[2]])
		"ice": particles.shatter(at, 2, Vector2.ZERO, 60.0, cols, 1)
		"bone", "gold": particles.chips(at, 2, Vector2.ZERO, [cols[1], cols[2]])
		_: particles.motes(at, 2, [cols[0], cols[1]])


## Matter a flying talent shot sheds into the particles along its flight, per second (physics
## plan F30): a fire shot embers that tumble down and lie, a frost shot rime sparks that settle
## as frost, a void or soul shot motes; the shot's painted look keeps only its shape.
var _shed_due: Dictionary = {}
var _puffed: Dictionary = {}


## How many pieces source `key` sheds this frame at `rate` per second (the fraction carried).
func _shed_count(key: int, rate: float) -> int:
	var last: Vector2 = _shed_due.get(key, Vector2(_clock, 0.0))
	var carry := last.y + clampf(_clock - last.x, 0.0, 0.1) * rate
	var n := int(carry)
	_shed_due[key] = Vector2(_clock, carry - float(n))
	if _shed_due.size() > 128: _shed_due.clear()
	return n


## The air drag of a particle mode (vfx_particles.json), for matter thrown in by hand.
func _mode_drag(mode: String) -> float:
	return float(particles._mode(mode).get("drag", 1.2)) if particles != null else 1.2


func _shed_flight(bullet: Dictionary, at: Vector2, aim: Vector2, element: String, clock: float) -> void:
	if particles == null: return
	var key := int(bullet.get("id", hash(Vector2i(int(at.x) / 64, int(at.y) / 64))))
	var last: Vector2 = _shed_due.get(key, Vector2(clock, 0.0))
	var carry := last.y + clampf(clock - last.x, 0.0, 0.1) * 24.0
	var n := int(carry)
	_shed_due[key] = Vector2(clock, carry - float(n))
	if _shed_due.size() > 128: _shed_due.clear()
	var s := to_particles
	var back := (at - aim * _u(8.0)) * s
	var cols := Pal.ramp_hot(element)
	for k in range(n):
		match Pal.resolve(element):
			"fire": particles.emit(back, -aim.rotated(randf_range(-0.6, 0.6)) * randf_range(20.0, 60.0), cols[1 + k % 2], randf_range(0.4, 0.8), "ember", 2.0, 10.0, randf_range(10.0, 40.0), 2.0)
			"ice": particles.emit(back, -aim.rotated(randf_range(-0.8, 0.8)) * randf_range(10.0, 40.0), cols[k % 2], randf_range(0.3, 0.6), "frost", 2.0, 10.0, 0.0, 2.0)
			"void", "soul", "spirit":
				var mote: Dictionary = particles.emit(back, -aim.rotated(randf_range(-1.0, 1.0)) * randf_range(10.0, 40.0), cols[k % 2], randf_range(0.3, 0.6), "mote", 2.0, 10.0, 0.0, 1.0)
				mote.streak = true


## A mixture as {element: units}: from [{el, n}] (talent_combat.gd _mixture, gefuege_state units;
## a spat glob's n is a share and may be a fraction), a {el: n} dictionary or a plain list of
## element names.
static func _mix_counts(mix: Variant) -> Dictionary:
	if mix is Dictionary:
		return mix
	var out := {}
	if mix is Array:
		for part: Variant in mix:
			var el := str(part.get("el", "")) if part is Dictionary else str(part)
			if el.is_empty():
				continue
			out[el] = float(out.get(el, 0.0)) + (float(part.get("n", 1)) if part is Dictionary else 1.0)
	return out


## A spat glob's mixture as drawn units: every element at least once, `per` per unit of its share,
## interleaved, at most `cap` (void.spit per_unit and cap).
static func _mix_units(mix: Variant, per: float, cap: int) -> Array:
	var counts := {}
	var parts := _mix_counts(mix)
	for el: String in parts: counts[el] = maxi(1, ceili(float(parts[el]) * per))
	return _unit_list(counts, 1, cap)


## One Gefuege comet leaving the core now (_eject_physics).
func _comet(entry: Dictionary) -> void:
	var ej: Dictionary = cfg.get("void", {}).get("eject", {})
	var el := str(entry.el)
	var kind := str(ej.get("kind", {}).get(el, "drop"))
	var mat := str(ej.get("pool_mat", {}).get(el, el))
	var layer: Object = pools if _pool_has(mat) else null
	var s := to_particles
	particles.comet(Vector2(entry.from) * s, Vector2(entry.to) * s, float(entry.fly), Pal.ramp_hot(el), kind, int(entry.n), layer, mat, _u(float(ej.get("height", 10))) * s)


## True when the pool layer has a liquid of `mat` (its drops can land in it).
func _pool_has(mat: String) -> bool:
	if pools == null or not pools.has_method("drop_landed"): return false
	var ramps: Variant = pools.get("_ramps")
	return ramps is Dictionary and (ramps as Dictionary).has(mat)


## Queues `entry` (a dict with "kind") to happen at `t` (clock s); nothing
## without particles.
func _defer(t: float, entry: Dictionary) -> void:
	if particles == null: return
	entry.t = t
	_deferred.append(entry)


## The queued matter that is due by `clock` (_defer).
func _run_deferred(clock: float) -> void:
	if _deferred.is_empty() or particles == null: return
	var due: Array = []
	for i in range(_deferred.size() - 1, -1, -1):
		if float(_deferred[i].t) <= clock:
			due.append(_deferred[i])
			_deferred.remove_at(i)
	for entry: Dictionary in due:
		match str(entry.kind):
			"rim": _rim(entry.at, float(entry.r), str(entry.element), bool(entry.heavy))
			"link": _link_hit(entry, clock)
			"comet": _comet(entry)
			"bits": _bits(entry)
			"spire":
				var gl: Dictionary = cfg.get("frost", {}).get("glacier", {})
				var s := to_particles
				particles.shatter(Vector2(entry.at) * s, int(gl.get("slivers", 2)), entry.out, float(gl.get("sliver_speed", 110)), [], 2, 2.0)
				particles.frost(Vector2(entry.at) * s, _u(4.0) * s, 2, Pal.ramp("ice")[3])
			"throw":
				var s := to_particles
				particles.shatter(Vector2(entry.hand) * s, int(entry.n), entry.dir, float(entry.speed), [], 3, float(entry.h) * s)


## A nova's rim matter (_rim) queued for when its front gets there
## (matter.rim.front of its span).
func _defer_rim(at: Vector2, r: float, element: String, heavy: bool, event: Dictionary, clock: float) -> void:
	if particles == null or r < art * 2.0: return
	var front := float(cfg.get("matter", {}).get("rim", {}).get("front", 0.21))
	_defer(clock + maxf(0.05, float(event.get("span", 0.5))) * front, {"kind": "rim", "at": at, "r": r, "element": element, "heavy": heavy})


## A ring's matter on its rim at `r` round `at` (the painted debris of
## TalentPixels.nova as particles; matter.rim): fire throws glowing sparks
## that lie as embers, ice and bone shards that skid, liquids drops that
## splat, the void and the souls motes that drift and dissolve, steel and
## gold sparks, the rest dust creeping off; each outwards, more for an
## ultimate's (`heavy`).
func _rim(at: Vector2, r: float, element: String, heavy: bool) -> void:
	if particles == null or r < art * 2.0: return
	var spec: Dictionary = cfg.get("matter", {}).get("rim", {})
	var s := to_particles
	var res := Pal.resolve(element)
	var cols := Pal.ramp(res)
	var n := clampi(int(r / art / float(spec.get("every", 5.0))), int(spec.get("min", 8)), int(spec.get("max_heavy", 22)) if heavy else int(spec.get("max", 14)))
	var kind := Pal.kind(res)
	var seed := int(at.x * 7.0 + at.y * 13.0)
	for i in range(n):
		var out := Vector2.from_angle(TAU * (float(i) + _h(seed + i) * 0.6) / float(n))
		var p := (at + out * r * Vector2(1.0, 0.75)) * s
		match kind:
			"spark":
				if res == "fire": particles.ember_sparks(p, 1, out, float(spec.get("fire_speed", 0.45)))
				else: particles.sparks(p, out, 1, [cols[4], cols[3], cols[2]])
			"shard": particles.shatter(p, 1, out, float(spec.get("shard_speed", 90.0)), [] if res == "ice" else Pal.ramp_hot(res), 2)
			"drop": particles.drops(p, 1, out, [cols[2], cols[3]])
			"mote": particles.motes(p, 1, [cols[3], cols[4], cols[2]], 8.0)
			_: particles.dust_flat(p, 3.0, 1)


## A Glutkette link striking its target (queued for when the chain gets
## there): ember sparks off the target, a few sparks leaping off the link
## itself that fall and lie as embers, and the target burning for a while.
func _link_hit(entry: Dictionary, clock: float) -> void:
	var hit: Vector2 = entry.at
	var prev: Vector2 = entry.prev
	var dir := (hit - prev).normalized() if hit != prev else Vector2.UP
	_matter(hit + body, dir, str(entry.element), int(entry.n), 0, _u(12.0))
	_burning.append({"at": hit, "until": clock + float(entry.burn), "seed": int(entry.seed)})
	if particles == null: return
	for k in range(int(entry.get("sparks", 3))):
		var along := prev.lerp(hit, _h(int(entry.seed) * 5 + k))
		particles.ember_sparks(along * to_particles, 1, dir.orthogonal() * (1.0 if k % 2 == 0 else -1.0), 0.35)


## The Leerenriss: a well at the tear pulls motes in from past its hit
## radius for void.rift well_time of the event (motes streaking in on
## spirals; the floor's loose pixels are lifted into it).
func _rift_physics(event: Dictionary, at: Vector2, r: float) -> void:
	if particles == null: return
	var rf: Dictionary = cfg.get("void", {}).get("rift", {})
	var s := to_particles
	var span := maxf(0.05, float(event.get("span", 0.5)))
	particles.well("rift:%d" % int(event.get("id", 0)), at * s, r * s * float(rf.get("well_reach", 1.3)), float(rf.get("well_pull", 300)), float(rf.get("well_swirl", 200)),
		r * s * 0.12, span * float(rf.get("ring", 0.42)), float(rf.get("mote_rate", 40)))


## A shield forming round the hero at `at` (his floor point): the
## Leerenschild's motes drawn in from all round on spirals by a short well
## that leaves the floor alone (void.shield cast_*), the Kristallschild's
## frost crystallising out of the air as chips that fall and lie
## (frost.shield cast_chips).
func _shield_cast_physics(at: Vector2, element: String) -> void:
	if particles == null: return
	var s := to_particles
	var chest := -body.y * s * 0.6
	if element == "void":
		var vs: Dictionary = cfg.get("void", {}).get("shield", {})
		var vo := Pal.ramp("void")
		var reach := _u(float(vs.get("cast_r", 30))) * s
		particles.well("vshield:%d" % _local_id(), at * s, reach * 1.4, float(vs.get("cast_pull", 320)), float(vs.get("cast_swirl", 200)), reach * 0.12, float(vs.get("cast_time", 0.4)), 0.0, [], false)
		var n := int(vs.get("cast_motes", 16))
		for i in range(n):
			var a := TAU * float(i) / float(maxi(1, n))
			var spot := at * s + Vector2.from_angle(a) * reach * Vector2(1.0, 0.75)
			var mote: Dictionary = particles.emit(spot - Vector2(0.0, chest), Vector2.from_angle(a).orthogonal() * 50.0, vo[4] if i % 3 == 0 else vo[3], float(vs.get("cast_time", 0.4)) + 0.3, "mote", 2.0, chest, 0.0, 0.3)
			mote.streak = true
	else:
		var fs: Dictionary = cfg.get("frost", {}).get("shield", {})
		particles.shatter(at * s - Vector2(0.0, chest * 1.4), int(fs.get("cast_chips", 8)), Vector2.ZERO, 50.0, [], 2, chest * 1.4)
		particles.frost(at * s, _u(14.0) * s, 8, Pal.ramp("ice")[3])


## A blow on a hero's shield dome (event dome_hit {dx, dy, power}): where it
## dents, the crystal chips (frost.shield hit_shards) or the void throws motes
## (void.shield hit_motes), more for a harder blow.
func _dome_hit_physics(event: Dictionary, at: Vector2) -> void:
	if particles == null: return
	var owner := int(event.get("owner", 1))
	var element := Pal.resolve(str((_dome_last.get(owner, {}) as Dictionary).get("element", _shield_el.get(owner, "ice"))))
	var d := Vector2(float(event.get("dx", 0.0)), float(event.get("dy", 1.0)))
	d = d.normalized() if d.length() > 0.01 else Vector2.UP
	var s := to_particles
	var power := clampf(float(event.get("power", 1.0)), 0.0, 1.0)
	var dent := (at + d * _u(14.0)) * s
	var h := -body.y * s * 0.6
	if element == "void":
		var vo := Pal.ramp("void")
		var span: Array = cfg.get("void", {}).get("shield", {}).get("hit_motes", [3, 7])
		particles.motes(dent, int(lerpf(float(span[0]), float(span[1]), power)), [vo[3], vo[4], vo[2]], 2.0, h, 1.6)
	else:
		var span: Array = cfg.get("frost", {}).get("shield", {}).get("hit_shards", [2, 5])
		particles.shatter(dent - Vector2(0.0, h), int(lerpf(float(span[0]), float(span[1]), power)), d, 100.0, [], 2, h)


## Gletschergrab's throw: when the crystal leaves the hand (frost.glacier
## throw of the cast), it breaks there and its shards fly along the aim,
## fall and skid (the painted crystal is the shape).
func _glacier_throw(event: Dictionary, at: Vector2, clock: float) -> void:
	if particles == null: return
	var gl: Dictionary = cfg.get("frost", {}).get("glacier", {})
	var span := maxf(0.05, float(event.get("span", 0.5)))
	var hand := at + body + Vector2(0.0, -11.0 * art)
	var stage := int(event.get("stage", 0))
	_defer(clock + span * float(gl.get("throw", 0.35)), {"kind": "throw", "hand": hand, "h": at.y - hand.y, "dir": Vector2.from_angle(float(event.get("angle", 0.0))),
		"n": int(gl.get("throw_shards", 10)) + 3 * stage, "speed": float(gl.get("throw_speed", 150))})


## SPLAT's physics (an enemy flung against a wall at the Urknall, `dir` into
## the wall): the material's burst in the particles (particles.splat_burst:
## blood spray, chunks and splats on wall and floor; splinters, dust and a
## rolling skull; motes; coins) and a rigged enemy near it torn apart along
## the rebound (rigs.fling_near: every part flies off away from the wall).
func _splat_physics(event: Dictionary, at: Vector2, r: float) -> void:
	var sp: Dictionary = cfg.get("void", {}).get("splat", {})
	var raw: Variant = event.get("dir", [0.0, 0.0])
	var dir := Vector2(float(raw[0]), float(raw[1])) if raw is Array and raw.size() >= 2 else Vector2.ZERO
	if dir.length() > 0.01: dir = dir.normalized()
	var material := str(event.get("material", "flesh"))
	if rigs != null and rigs.has_method("fling_near"):
		rigs.fling_near(at, -dir if dir != Vector2.ZERO else Vector2.UP, float(sp.get("fling", 1.0)), _u(float(sp.get("fling_reach", 48))))
	if particles != null and particles.has_method("splat_burst"):
		particles.splat_burst(at * to_particles, dir, material, maxf(r, _u(float(sp.get("radius", 14)))) * to_particles)


## The Singularität's caught enemies (zone "caught": enemy ids): each on a
## dark violet tether into the core with its essence flowing in and the
## drain shimmer round it (TalentPixels.tether, void.tether).
func _draw_caught(canvas: CanvasItem, zone: Dictionary, core: Vector2, k: float, clock: float) -> void:
	var caught: Variant = zone.get("caught", [])
	if not caught is Array or (caught as Array).is_empty(): return
	var spec: Dictionary = cfg.get("void", {}).get("tether", {})
	var essence: Dictionary = spec.get("essence", {})
	for i in range((caught as Array).size()):
		var found := _caught_enemy(caught[i], i, zone)
		if found.is_empty(): continue
		var element := str(essence.get(str(found.material), spec.get("default", "soul")))
		TalentPixels.tether(canvas, Vector2(found.at), core, k, Pal.ramp(element), art, clock, int(zone.get("id", 0)) * 31 + i, spec)
		# its essence drifts off it into the core: motes the Singularitaet's well pulls in
		if particles != null and _tick("tether:%d:%d" % [int(zone.get("id", 0)), i], float(spec.get("emit_every", 0.15)), clock):
			var cols := Pal.ramp_hot(element)
			var lift := body * float(spec.get("chest", 0.6))
			var s := to_particles
			var floor_at := Vector2(found.at) - lift
			var mote: Dictionary = particles.emit(Vector2(found.at) * s, (core - floor_at).normalized() * 40.0 * s, cols[1] if posmod(i, 2) == 0 else cols[0], 1.4, "mote", 2.0, -lift.y * s, 0.0, 0.3)
			mote.streak = true
			mote.z_to = 2.0


## Where a caught enemy is and what it is made of ({at (its chest), material}),
## or {}: an entry carrying x and y, the zone's caught_at[index], the host's
## enemy_at(id), else the view's rigs (actor "e<id>" where last drawn).
func _caught_enemy(entry: Variant, index: int, zone: Dictionary) -> Dictionary:
	var lift := body * float(cfg.get("void", {}).get("tether", {}).get("chest", 0.6))
	if entry is Dictionary and entry.has("x"):
		return {"at": Vector2(float(entry.x), float(entry.get("y", 0.0))) + lift, "material": _material_of(str(entry.get("kind", "")), str(entry.get("material", "")))}
	var points: Variant = zone.get("caught_at", [])
	if points is Array and index < points.size() and points[index] is Array and points[index].size() >= 2:
		return {"at": Vector2(float(points[index][0]), float(points[index][1])) + lift, "material": ""}
	var id := int(entry.get("id", -1)) if entry is Dictionary else int(entry)
	if enemy_at.is_valid():
		var hit: Variant = enemy_at.call(id)
		if hit is Vector2 and (hit as Vector2).is_finite(): return {"at": hit + lift, "material": ""}
		if hit is Dictionary and not (hit as Dictionary).is_empty():
			return {"at": Vector2(float(hit.get("x", 0.0)), float(hit.get("y", 0.0))) + lift, "material": _material_of(str(hit.get("kind", "")), str(hit.get("gore", "")))}
	if rigs != null and rigs.has_method("actor_feet"):
		var feet: Vector2 = rigs.actor_feet("e%d" % id)
		if feet.is_finite(): return {"at": feet + body * 1.1, "material": str(rigs.actor_material("e%d" % id))}
	return {}


## The gore material of an enemy: `material` if given, else its kind's in
## vfx_gore.json (kinds), else "".
func _material_of(kind: String, material: String) -> String:
	if not material.is_empty(): return material
	return str(gore().get("kinds", {}).get(kind, ""))
