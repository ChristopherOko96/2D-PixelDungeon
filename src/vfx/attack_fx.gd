extends RefCounted
## The heroes' basic attacks and the crypt's enemy spells as every client sees
## them, in the one pixel language of the effects: a spell is pixel matter of
## its element on the art pixel (2 world px in the crypt, a scaled layer in the
## story worlds; src/vfx/pixel_paint.gd), in the ramp of its element
## (src/vfx/talent_palette.gd; FALLBACK_RAMPS for ramps the palette lacks), with
## a dark ink outline, fading by the ordered dither and stopped at walls. Its
## beats: CAST (a magic circle flares at the staff or claw, a few sparks leave
## it), FLIGHT (a ball of the ramp with a hot core of two or three spec pixels
## and one white one, and an ember tail of dithered pixels that cool down the
## ramp towards its end, hop sideways on the 12 fps beat and drift up as hot gas
## does), IMPACT (one or two white-hot frames, then a ring of the element
## running out with short rays, and a pixel-physics burst: embers, motes, drops,
## shards, splinters or rubble thrown out with gravity that bounce once and lie
## as glowing residue dying over about 1.5 s, with a scorch, splat, crack or
## rime where it hit) and RESIDUE (the living floor of src/vfx/particles.gd).
## Critical shots burn brighter and throw more. Arrows keep their light streak
## and spark on walls only, no residue (auto-attacks). Which shots: the heroes'
## arrows and spells, and the enemy spells with no authored pixel look of their
## own (ENEMY_STYLES); the bone shots, ice shards and skulls keep their flight
## (src/vfx/boss_fx.gd, the view) and end here (ENEMY_WATCHED). The shared
## drawers (`ramp_for`, `fireball`, `blast`, `element_burst`) serve the skills
## too (src/vfx/skill_fx.gd). Tinted by a found weapon's glow (items.json
## "glow", sent as the player's "glow") or by the element of the hero's build.
## Pure presentation: it only reads snapshots.

const Glow = preload("res://src/vfx/glow.gd")
const PixelPaint = preload("res://src/vfx/pixel_paint.gd")
const Pal = preload("res://src/vfx/talent_palette.gd")
## World px per art pixel.
const ART := 2.0
const INK := Color("1a1414")
const ARROW := preload("res://assets/sprites/0x72/weapon_arrow.png")
const ELEMENT_TINTS := {"cinder": Color("f7b46b"), "venom": Color("b8d878"), "frost": Color("9bdde6"), "storm": Color("baabe9")}
## The build's shot element (bullet "element") -> palette element.
const BUILD_ELEMENTS := {"cinder": "fire", "venom": "poison", "frost": "ice", "storm": "arcane"}
const ARROW_TINT := Color("f3e3b5")
const ORB_TINT := Color("6fe3a0")
const CRIT_TINT := Color("ffd75a")
## Trail lengths in pixels: arrow, critical arrow, orb.
const STREAK := 64.0
const CRIT_STREAK := 104.0
const ORB_TRAIL := 48.0
## Hero shot styles drawn here.
const STYLES := ["arrow", "magic"]
## Enemy shot styles drawn here as element orbs: the plain shooter's shot ("")
## and the spells with no authored pixel look of their own.
const ENEMY_STYLES := ["", "magic", "fireball", "fire", "flame", "bigfire", "void", "soul", "poison", "frost", "shard"]
## Enemy shot styles that end here though their flight is drawn elsewhere.
const ENEMY_WATCHED := ["bone", "bone_spear", "skull", "flesh", "ice", "soul_chain", "void_skull", "rock", "bolt"]
## Enemy shot style -> palette element.
const ENEMY_ELEMENTS := {"": "magic", "magic": "magic", "fireball": "fire", "fire": "fire", "flame": "fire", "bigfire": "fire",
	"void": "void", "void_skull": "void", "soul": "soul", "soul_chain": "soul", "poison": "poison", "frost": "ice", "ice": "ice",
	"shard": "ice", "bone": "bone", "bone_spear": "bone", "skull": "bone", "flesh": "blood", "rock": "stone", "bolt": "arcane"}
## What an element's matter does when it bursts (element_burst).
const MATTER := {"fire": "ember", "gold": "ember", "steel": "ember", "ice": "shard", "bone": "splinter", "poison": "drop", "blood": "drop",
	"water": "drop", "stone": "rubble", "beast": "rubble", "void": "mote", "soul": "mote", "arcane": "mote", "magic": "mote", "spirit": "mote", "curse": "mote"}
## Elements whose tail drifts up as it cools (hot gas rises).
const RISING := ["fire"]
## Ramps (dark to light: deep, shade, body, lite, spec) used only for an element
## the palette lacks (its names and aliases win, ramp_for; "magic" is the void's
## there): the void's from vfx_particles.json, bone and soul from the crypt's
## bone and soul shots, stone from the skills' stone tint, magic from the orb tint.
const FALLBACK_RAMPS := {
	"void": [Color("1a0d2a"), Color("3a1f5c"), Color("7a3fb8"), Color("c27bff"), Color("f2d9ff")],
	"bone": [Color("4a4036"), Color("8a7c66"), Color("b8ab92"), Color("e6dcc6"), Color("fdf7ed")],
	"soul": [Color("1e3a38"), Color("3a6a64"), Color("6ca9a1"), Color("a6d6c8"), Color("e0f4ea")],
	"stone": [Color("3a3028"), Color("6a5a4a"), Color("9a8a78"), Color("c9b49a"), Color("ece0cc")],
	"magic": [Color("1e4a32"), Color("3a8a5c"), Color("6fe3a0"), Color("a8f0c4"), Color("e0ffe8")],
}
## Seconds a burst flash lasts; its white-hot frames are the first BLAST_HOT share of it.
const BLAST_LIFE := 0.3
const BLAST_HOT := 0.34

## Shared with the other effects (set by the view each frame).
var particles: RefCounted = null
var fx: RefCounted = null
var _tracks: Dictionary = {}
var _flashes: Array[Dictionary] = []
var _clock := 0.0
var _rng := RandomNumberGenerator.new()
## Dice of the shared static drawers.
static var _dice := RandomNumberGenerator.new()


## True for the shots this file draws: the heroes' arrows and spells, and the
## enemy element orbs (ENEMY_STYLES).
static func handles(bullet: Dictionary) -> bool:
	var style := str(bullet.get("style", ""))
	if int(bullet.get("owner", 0)) > 0: return style in STYLES
	return style in ENEMY_STYLES


## True for the shots whose end this file bursts: every drawn shot and the
## enemy spells drawn elsewhere (ENEMY_WATCHED).
static func watches(bullet: Dictionary) -> bool:
	return handles(bullet) or (int(bullet.get("owner", 0)) <= 0 and str(bullet.get("style", "")) in ENEMY_WATCHED)


## The colour of a shot: a found weapon's own glow first (its look), then the
## element of the build, then the class default.
static func tint_for(bullet: Dictionary, player: Dictionary) -> Color:
	var glow := str(player.get("glow", ""))
	if not glow.is_empty(): return Color(glow)
	# the mage's shots are fireballs (user wish 30.10.2026): their light and trail burn orange
	if str(player.get("class_id", "")) == "mage" and str(bullet.get("style", "")) == "magic": return Color("ff8a2a")
	var element := str(bullet.get("element", ""))
	if ELEMENT_TINTS.has(element): return ELEMENT_TINTS[element]
	return ORB_TINT if str(bullet.get("style", "")) == "magic" else ARROW_TINT


## The palette element a shot is made of: an enemy's by its style
## (ENEMY_ELEMENTS), the mage's spells fire, a build's by its element, arrows
## steel, the rest magic.
static func element_for(bullet: Dictionary, player: Dictionary) -> String:
	var style := str(bullet.get("style", ""))
	if int(bullet.get("owner", 0)) <= 0: return str(ENEMY_ELEMENTS.get(style, "magic"))
	if style == "arrow": return "steel"
	if str(player.get("class_id", "")) == "mage": return "fire"
	return str(BUILD_ELEMENTS.get(str(bullet.get("element", "")), "magic"))


## The ramp (dark to light: deep, shade, body, lite, spec) of `element`: a
## weapon's own glow `tint` when given, else the palette's, else FALLBACK_RAMPS,
## else magic. Returned by reference: never changed.
static func ramp_for(element: String, tint := Color(0, 0, 0, 0)) -> Array:
	if tint.a > 0.0: return ramp_from(tint)
	var key: String = Pal.resolve(element)
	if Pal.RAMPS.has(key): return Pal.RAMPS[key]
	if FALLBACK_RAMPS.has(key): return FALLBACK_RAMPS[key]
	return FALLBACK_RAMPS.magic


## A ramp shaded from one `tint` (a found weapon's glow).
static func ramp_from(tint: Color) -> Array:
	return [tint.darkened(0.7), tint.darkened(0.4), tint, tint.lightened(0.35), tint.lightened(0.7)]


## Call once per frame: starts a flash for every new shot, keeps each shot's
## recent path (so trails bend with homing and bounces and never cross a wall)
## and bursts every shot that ended this frame.
func observe(snapshot: Dictionary, clock: float) -> void:
	_clock = clock
	var alive := {}
	var players: Dictionary = snapshot.get("players", {})
	for bullet: Dictionary in snapshot.get("bullets", []):
		if not watches(bullet): continue
		var id := int(bullet.get("id", -1))
		alive[id] = true
		var point := Vector2(float(bullet.x), float(bullet.y))
		var aim := Vector2(float(bullet.get("vx", 1.0)), float(bullet.get("vy", 0.0))).normalized()
		if aim.is_zero_approx(): aim = Vector2.RIGHT
		if not _tracks.has(id):
			var track := _track(bullet, players.get(int(bullet.get("owner", 0)), {}), point, aim, clock)
			_tracks[id] = track
			if bool(track.drawn): _release(track, point)
			continue
		var track: Dictionary = _tracks[id]
		var path: PackedVector2Array = track.path
		var moved := path[path.size() - 1].distance_to(point)
		if moved > 2.0:
			path.append(point)
			track.shed = float(track.shed) + moved
		track.path = _trim(path, CRIT_STREAK + 24.0)
		track.aim = aim
		track.seen = clock
	for id: int in _tracks.keys():
		if alive.has(id): continue
		var track: Dictionary = _tracks[id]
		if clock - float(track.seen) < 0.25: _impact(track)
		_tracks.erase(id)
	_flashes = _flashes.filter(func(flash: Dictionary) -> bool: return clock - float(flash.born) < float(flash.life))


## A new shot's record: its element and ramp (brighter on a critical shot),
## whether it is drawn here, and the colour its light and flashes take.
func _track(bullet: Dictionary, player: Dictionary, point: Vector2, aim: Vector2, clock: float) -> Dictionary:
	var owner := int(bullet.get("owner", 0))
	var style := str(bullet.get("style", ""))
	var crit := bool(bullet.get("critical", false))
	var element: String = Pal.resolve(element_for(bullet, player))
	var glow := str(player.get("glow", "")) if owner > 0 and style == "magic" else ""
	var ramp := ramp_for(element, Color(glow) if not glow.is_empty() else Color(0, 0, 0, 0))
	if crit and style != "arrow":
		ramp = [ramp[0], ramp[1], (ramp[2] as Color).lerp(CRIT_TINT, 0.35), (ramp[3] as Color).lerp(CRIT_TINT, 0.5), (ramp[4] as Color).lerp(CRIT_TINT, 0.5)]
	var tint: Color = tint_for(bullet, player) if style == "arrow" else ramp[3]
	return {"path": PackedVector2Array([point]), "aim": aim, "style": style, "tint": tint, "crit": crit, "seen": clock,
		"element": element, "ramp": ramp, "drawn": handles(bullet), "enemy": owner <= 0, "shed": 0.0}


## Forgets every shot (room change).
func reset() -> void:
	_tracks.clear()
	_flashes.clear()


## The newest part of a path, `keep` pixels long (packed arrays are copies, so it returns one).
func _trim(path: PackedVector2Array, keep: float) -> PackedVector2Array:
	var total := 0.0
	for index in range(path.size() - 1, 0, -1):
		total += path[index].distance_to(path[index - 1])
		if total > keep: return path.slice(index - 1)
	return path


## Points every 6 px from the head back along the shot's path, `length` long
## at most (shorter while the shot is young).
func _trail(id: int, head: Vector2, length: float) -> PackedVector2Array:
	var result := PackedVector2Array([head])
	var path: PackedVector2Array = _tracks.get(id, {}).get("path", PackedVector2Array())
	var left := length
	var cursor := head
	var since := 0.0
	for index in range(path.size() - 1, -1, -1):
		var target := path[index]
		while left > 0.0:
			var gap := cursor.distance_to(target)
			if gap <= 0.001: break
			var step := minf(minf(6.0 - since, gap), left)
			cursor = cursor.move_toward(target, step)
			since += step
			left -= step
			if since >= 5.999 or left <= 0.0:
				result.append(cursor)
				since = 0.0
		if left <= 0.0: break
	if since > 0.0: result.append(cursor)
	return result


## CAST: the string snaps or a magic circle flares, a few sparks leave the
## weapon. A volley of enemy spells from one point flares once.
func _release(track: Dictionary, point: Vector2) -> void:
	var tint: Color = track.tint
	var aim: Vector2 = track.aim
	if str(track.style) == "arrow":
		_flashes.append({"kind": "bow", "pos": point, "aim": aim, "tint": tint, "born": _clock, "life": 0.2, "crit": track.crit})
		if particles != null: particles.burst(point, tint.lightened(0.4), 6, 170.0, 0.22, aim, 0.35, 2.0, 6.0, "spark", 12.0)
		return
	for flash: Dictionary in _flashes:
		if str(flash.kind) == "cast" and _clock - float(flash.born) < 0.06 and (flash.pos as Vector2).distance_to(point) < 16.0: return
	_flashes.append({"kind": "cast", "pos": point, "aim": aim, "tint": tint, "born": _clock, "life": 0.34, "crit": track.crit})
	if particles != null: particles.burst(point, tint, 4 if bool(track.enemy) else 8, 110.0, 0.4, aim, 1.0, 2.0, 4.0, "spark", 12.0)


## IMPACT: an arrow strikes with a star and sparks (no residue); a spell shows
## its white-hot frames and ring (blast flash) and bursts into the matter of
## its element, which lands and lies (element_burst).
func _impact(track: Dictionary) -> void:
	var path: PackedVector2Array = track.path
	var point := path[path.size() - 1]
	var crit := bool(track.crit)
	var aim: Vector2 = track.aim
	if str(track.style) == "arrow":
		var tint: Color = CRIT_TINT if crit else track.tint
		_flashes.append({"kind": "pierce", "pos": point, "aim": aim, "tint": tint, "born": _clock, "life": 0.22, "crit": crit})
		if particles != null: particles.burst(point, tint.lightened(0.3), 8, 150.0, 0.3, -aim, 1.0, 2.0, 6.0, "spark", 12.0)
		return
	var ramp: Array = track.ramp
	_flashes.append({"kind": "blast", "pos": point, "aim": aim, "tint": track.tint, "ramp": ramp, "born": _clock, "life": BLAST_LIFE, "crit": crit, "enemy": track.enemy})
	if particles == null:
		# without a living floor the scorch is a flash of its own (dithered, fading)
		_flashes.append({"kind": "scorch", "pos": point + Vector2(0, 12), "aim": aim, "tint": ramp[0], "born": _clock, "life": 2.0, "crit": false})
		return
	var count := 14 if bool(track.enemy) else 16
	if crit: count = 24
	element_burst(particles, point, -aim, str(track.element), ramp, count, 12.0)


## The burst of an element's matter at `point` (seen `height` px above the
## floor), thrown mostly `back` (the way the shot came; zero: all round),
## `count` pieces, each with gravity, one bounce and a rest: fire, gold and
## steel throw glowing embers that lie as embers cooling and dying, with
## flames, smoke and a soot scorch; ice throws rigid shards that clink, skid
## and lie as frost, with a fleck of rime growing where it struck; bone throws
## heavy splinters that stop hard and lie; poison and blood throw drops that
## splash to a stop and dry away over a stain; stone throws rubble and cracks
## the floor; the void, souls and arcane throw motes (short streaks) that lie
## glowing before they go out, over a dark scatter. Fewer pieces while the
## floor is busy (a ring of 28 shots ending at once). Everything stays in the
## budget of src/vfx/particles.gd (max_particles), which evicts the oldest.
static func element_burst(particles: RefCounted, point: Vector2, back: Vector2, element: String, ramp: Array, count: int, height: float = 12.0) -> void:
	if particles == null or count <= 0 or ramp.size() < 5: return
	var load := int(particles.count())
	if load > 520: count = maxi(3, count / 4)
	elif load > 380: count = maxi(4, count / 2)
	var rng := _dice
	var floor_point := point + Vector2(0, height)
	var dir := back.normalized() if back.length() > 0.01 else Vector2.UP
	var arc := 1.6 if back.length() > 0.01 else PI
	match str(MATTER.get(element, "mote")):
		"ember":
			# glowing embers fly out, fall, bounce once and lie as embers that cool, smoke a little and die
			for i in range(count):
				var out := dir.rotated(rng.randf_range(-arc, arc)) * rng.randf_range(50.0, 190.0)
				var ember: Dictionary = particles.emit(point, out, ramp[4] if i % 3 == 0 else ramp[3], rng.randf_range(1.0, 1.6), "glut", 2.0, height, rng.randf_range(60.0, 170.0), 1.6)
				ember.ember_life = rng.randf_range(0.9, 1.7)
				ember.soot = 0.4
			# flames lick up from the hit for a moment, smoke rolls off, the floor is scorched
			var hot := ramp.duplicate()
			hot.reverse()
			particles.flames(point, maxi(3, count / 4), hot, 4.0, height)
			particles.smoke(point, 2, 4.0)
			particles.stain(floor_point, (ramp[0] as Color).darkened(0.5), 6.0)
			particles.embers(floor_point, 5.0, 3)
		"shard":
			# rigid shards clink off the walls, skid over the stones and lie as frost; rime grows where the cold struck
			var cold := ramp.duplicate()
			cold.reverse()
			particles.shatter(point, count, dir if arc < PI else Vector2.ZERO, 170.0, cold, 3)
			particles.frost(floor_point, 8.0, 5, Color(ramp[3], 0.8))
			particles.rime_grow(floor_point, 2, 16.0, ramp[2])
		"splinter":
			# bone splinters are heavy: one low bounce, they stop hard and lie; bone dust settles round them
			for i in range(count):
				var out := dir.rotated(rng.randf_range(-arc, arc)) * rng.randf_range(50.0, 160.0)
				var bit: Dictionary = particles.emit(point, out, ramp[3], 3.0, "rock", 2.0 if i % 2 == 0 else 4.0, height, rng.randf_range(40.0, 120.0), 0.5)
				bit.rock = [ramp[4], ramp[3], ramp[1]]
			particles.scatter(floor_point, Color(ramp[2], 0.6), 7.0, 5)
		"drop":
			# drops arc down heavier than sparks, splash to a stop and dry away by the dither over a stain
			for i in range(count):
				var out := dir.rotated(rng.randf_range(-arc, arc)) * rng.randf_range(40.0, 150.0)
				var drop: Dictionary = particles.emit(point, out, ramp[2] if i % 2 == 0 else ramp[3], rng.randf_range(1.0, 1.5), "spark", 2.0, height, rng.randf_range(50.0, 150.0), 2.0)
				drop.erase("streak")
				drop.gravity = float(drop.gravity) * 2.2
			particles.stain(floor_point, ramp[1], 5.0)
		"rubble":
			particles.rubble(point, maxi(3, count / 2), dir if arc < PI else Vector2.ZERO, 130.0)
			particles.dust_flat(floor_point, 10.0, 4)
			particles.floor_crack(floor_point, 10.0, 3)
		_:
			# motes: short streaks that fall slowly, bounce and lie glowing before they go out
			for i in range(count):
				var out := dir.rotated(rng.randf_range(-arc, arc)) * rng.randf_range(40.0, 170.0)
				particles.emit(point, out, ramp[4] if i % 3 == 0 else ramp[3], rng.randf_range(1.0, 1.6), "spark", 2.0, height, rng.randf_range(40.0, 130.0), 2.0)
			particles.scatter(floor_point, Color(ramp[0], 0.55), 6.0, 5)


# --- Drawing ---------------------------------------------------------------------------

## An arrow: a streak of light pixels behind it (bright at the arrow, thinning
## out by the dither towards its end, a pixel wide, two on a critical shot),
## the 0x72 arrow on the pixel grid and a white pixel at its head.
func draw_arrow(canvas: CanvasItem, bullet: Dictionary, point: Vector2, clock: float) -> void:
	var id := int(bullet.get("id", -1))
	var track: Dictionary = _tracks.get(id, {})
	var crit := bool(bullet.get("critical", false))
	var tint: Color = CRIT_TINT if crit else track.get("tint", ARROW_TINT)
	var aim := Vector2(float(bullet.get("vx", 1.0)), float(bullet.get("vy", 0.0))).normalized()
	if aim.is_zero_approx(): aim = Vector2.RIGHT
	var trail := _trail(id, point, CRIT_STREAK if crit else STREAK)
	_streak(canvas, trail, tint, 2 if crit else 1)
	var size := Vector2(ARROW.get_width(), ARROW.get_height()) * 2.0
	canvas.draw_set_transform(point.snapped(Vector2(ART, ART)), aim.angle() + PI * 0.5, Vector2.ONE)
	canvas.draw_texture_rect(ARROW, Rect2(-size * 0.5, size), false)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	PixelPaint.cell(canvas, PixelPaint.at(point + aim * 9.0, ART), Color(1, 1, 1), ART)
	if crit:
		# a four-point star at its head, turning in steps: plus, then cross
		var head := PixelPaint.at(point + aim * 9.0, ART)
		var diag := posmod(int(floorf(clock * PixelPaint.FPS)) / 2, 2) == 1
		for r in range(1, 4):
			for d: Vector2i in ([Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)] if diag else [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]):
				PixelPaint.cell(canvas, head + d * r, CRIT_TINT if r < 3 else CRIT_TINT.darkened(0.2), ART)
	if particles != null and _rng.randf() < 0.35:
		var side := aim.orthogonal()
		var drift := -aim * _rng.randf_range(20.0, 60.0) + side * _rng.randf_range(-25.0, 25.0)
		particles.emit(point - aim * 10.0, drift, tint.lightened(0.35), _rng.randf_range(0.18, 0.32), "spark", 1.5, 12.0)


## A streak along `trail` (head first): pixels of the ramp from near-white at
## the head to the tint, `width` pixels across, thinning out by the dither.
func _streak(canvas: CanvasItem, trail: PackedVector2Array, tint: Color, width: int) -> void:
	var count := trail.size()
	if count < 2: return
	var seen := {}
	var total := 0.0
	for index in range(count - 1): total += trail[index].distance_to(trail[index + 1])
	var run := 0.0
	for index in range(count - 1):
		var a := trail[index]
		var b := trail[index + 1]
		var length := a.distance_to(b)
		var steps := maxi(1, int(length / ART))
		var side := (b - a).normalized().orthogonal()
		for s in range(steps):
			var p := a.lerp(b, float(s) / float(steps))
			var k := (run + length * float(s) / float(steps)) / maxf(1.0, total)
			for w in range(width):
				var q := PixelPaint.at(p + side * float(w) * ART, ART)
				if seen.has(q) or not PixelPaint.shown(q, 1.0 - k * 0.9): continue
				seen[q] = true
				PixelPaint.cell(canvas, q, Color(1, 1, 1) if k < 0.12 else tint.lightened(0.35) if k < 0.45 else tint, ART)
		run += length


## FLIGHT: a spell is a fireball of its element (fireball), with its tail along
## the path it flew; every few pixels of flight it sheds a piece of its matter
## (fewer the more shots fly). The ball grows with the shot's radius and on a
## critical shot.
func draw_orb(canvas: CanvasItem, bullet: Dictionary, point: Vector2, clock: float) -> void:
	var id := int(bullet.get("id", -1))
	var track: Dictionary = _tracks.get(id, {})
	var crit := bool(bullet.get("critical", false))
	var ramp: Array = track.get("ramp", FALLBACK_RAMPS.magic)
	var element := str(track.get("element", "magic"))
	var radius := float(bullet.get("radius", 6.0))
	var r := clampi(roundi(radius * 0.4), 2, 4) + (1 if crit else 0)
	var trail := _trail(id, point, ORB_TRAIL)
	fireball(canvas, point, trail, ramp, r, int(floorf(clock * PixelPaint.FPS)), id, ART, element in RISING)
	if particles == null or track.is_empty(): return
	var every := 8.0 + 1.5 * float(_tracks.size())
	if float(track.shed) < every: return
	track.shed = 0.0
	var aim := Vector2(float(bullet.get("vx", 1.0)), float(bullet.get("vy", 0.0))).normalized()
	_shed(point - aim * 6.0, aim, element, ramp)


## One piece of a flying spell's matter left behind it: an ember that rises
## (fire), a crystal or drop that falls (ice, bone, poison), a mote streak (the
## rest); all short-lived, no residue from flight.
func _shed(point: Vector2, aim: Vector2, element: String, ramp: Array) -> void:
	var drift := -aim * _rng.randf_range(10.0, 40.0) + Vector2(_rng.randf_range(-16.0, 16.0), _rng.randf_range(-20.0, 0.0))
	match str(MATTER.get(element, "mote")):
		"ember":
			particles.emit(point, drift, ramp[3], _rng.randf_range(0.25, 0.45), "ember", 2.0, 12.0, _rng.randf_range(10.0, 50.0), 2.0)
		"shard", "splinter", "drop":
			var piece: Dictionary = particles.emit(point, drift, ramp[3], _rng.randf_range(0.3, 0.5), "spark", 2.0, 12.0, 0.0, 2.0)
			piece.erase("streak")
		_:
			particles.emit(point, drift, ramp[3], _rng.randf_range(0.3, 0.5), "spark", 2.0, 12.0, 0.0, 1.0)


## A fireball of `ramp` (dark to light) at `head`, `r` art px round, its tail
## along `trail` (head first, a point every few px, as _trail gives them): the
## ball of the ramp with an ink rim and the spec pixels lit up-left as its hot
## core (two or three on a ball of 3), one white pixel hopping on the beat; the
## tail as dithered pixels, thick and lite near the ball, cooling down the ramp
## to its deep colour at the end and thinning by the dither, each hopping
## sideways on the 12 fps `beat` (a flame's flicker, never a brightness pulse)
## and, when `rises`, drifting up as hot gas does. `seed` varies the hops per
## shot. Cells stop at walls (PixelPaint.clip).
static func fireball(canvas: CanvasItem, head: Vector2, trail: PackedVector2Array, ramp: Array, r: int, beat: int, seed: int, art: float, rises: bool) -> void:
	var count := trail.size()
	for index in range(count - 1, 0, -1):
		var fade := 1.0 - float(index) / float(maxi(1, count - 1))
		var p := trail[index]
		var side := (trail[index - 1] - p).normalized().orthogonal()
		var hop := float(posmod(beat * 7 + index * 5 + seed, 3) - 1) * (1.0 - fade) * art
		if rises: p.y -= (1.0 - fade) * 3.0 * art
		var q := PixelPaint.at(p + side * hop, art)
		if not PixelPaint.shown(q, 0.1 + 0.9 * fade): continue
		var col: Color = ramp[3] if fade > 0.8 else (ramp[2] if fade > 0.55 else (ramp[1] if fade > 0.3 else ramp[0]))
		PixelPaint.cell(canvas, q, col, art)
		if fade > 0.55:
			# the tail is thick near the ball: a darker pixel under each
			PixelPaint.cell(canvas, q + Vector2i(0, 1), ramp[1] if fade > 0.8 else ramp[0], art)
	PixelPaint.ball(canvas, head, r, [ramp[4], ramp[3], ramp[2], ramp[1]], INK, art)
	var hot := PixelPaint.at(head, art) + Vector2i(-1, -1) * maxi(1, r - 1)
	PixelPaint.cell(canvas, hot + Vector2i(posmod(beat + seed, 2), 0), Color(1, 1, 1), art)


## A spell's burst at `point`, `k` running 1 (just struck) to 0 (gone): for its
## first frame or two a white-hot disc of the spec colour with an ink rim and a
## white heart of a pixel or two; then a ring of the element running out over a
## dark underlay and thinning by its dashes, a dithered core shrinking in the
## middle and six short rays dying before the ring. `scale` 1 is a shot's
## burst; the skills' blasts are wider. Cells stop at walls (PixelPaint.clip);
## `canvas` may be a PixelPaint.Recorder (for baking).
static func blast(canvas: Object, point: Vector2, k: float, ramp: Array, scale: float, art: float, seed: int) -> void:
	if ramp.size() < 5 or k <= 0.0: return
	var grow := 1.0 - k
	if k > 1.0 - BLAST_HOT:
		var r := (5.0 + 5.0 * grow) * scale
		PixelPaint.ellipse(canvas, point, r + art, r + art, INK, art)
		PixelPaint.disc(canvas, point, r, r, ramp[4], art)
		PixelPaint.disc(canvas, point, art, art, Color(1, 1, 1), art)
		return
	var reach := (10.0 + 30.0 * grow) * scale
	var every := 1 if k > 0.4 else (2 if k > 0.2 else 3)
	PixelPaint.ellipse(canvas, point + Vector2(0, art), reach, reach, INK, art, every, seed)
	PixelPaint.ellipse(canvas, point, reach, reach, ramp[3] if k > 0.4 else ramp[2], art, every, seed)
	PixelPaint.disc(canvas, point, 6.0 * scale * k, 6.0 * scale * k, ramp[2], art, k)
	if k > 0.3:
		for ray in range(6):
			var direction := Vector2.from_angle(float(ray) * TAU / 6.0 + float(seed) * 0.37)
			for i in range(3):
				var q := PixelPaint.at(point + direction * (reach * 0.55 + float(i) * art), art)
				if PixelPaint.shown(q, k): PixelPaint.cell(canvas, q, ramp[4] if i == 0 else ramp[3], art)


## Release flashes and impact bursts over the actors, on the pixel grid,
## thinning out by the dither as they end.
func draw_flashes(canvas: CanvasItem, clock: float) -> void:
	for flash: Dictionary in _flashes:
		var k := 1.0 - clampf((clock - float(flash.born)) / float(flash.life), 0.0, 1.0)
		var grow := 1.0 - k
		var point: Vector2 = flash.pos
		var aim: Vector2 = flash.aim
		var tint: Color = flash.tint
		match str(flash.kind):
			"bow":
				# the string snaps: a short crescent of air opens forward, a spark leaves the bow
				var r := 6.0 + 16.0 * grow
				var n := maxi(5, int(1.8 * r / ART))
				for i in range(n + 1):
					var q := PixelPaint.at(point + Vector2.from_angle(aim.angle() - 0.9 + 1.8 * float(i) / float(n)) * r, ART)
					if PixelPaint.shown(q, k): PixelPaint.cell(canvas, q, tint.lightened(0.3), ART)
				for i in range(int((6.0 + 14.0 * grow) / ART)):
					var q := PixelPaint.at(point + aim * float(i) * ART, ART)
					if PixelPaint.shown(q, k): PixelPaint.cell(canvas, q, Color(1, 1, 1) if i > 2 else tint.lightened(0.4), ART)
			"cast":
				# a small magic circle flares at the staff: two dashed rings and ticks
				var radius := 8.0 + 18.0 * grow
				var tq := int(floorf(clock * PixelPaint.FPS))
				if k > 0.15:
					PixelPaint.ellipse(canvas, point, radius, radius, tint, ART, 2 if k > 0.5 else 3, tq)
					PixelPaint.ellipse(canvas, point, radius * 0.62, radius * 0.62, tint.lightened(0.3), ART, 3, -tq)
				if k > 0.6:
					PixelPaint.cell(canvas, PixelPaint.at(point, ART), Color(1, 1, 1), ART)
			"pierce":
				# a four-point star where the arrow struck
				var reach := int(((8.0 + 8.0 * grow) * (1.5 if bool(flash.crit) else 1.0)) / ART)
				var c := PixelPaint.at(point, ART)
				for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					for r in range(1, reach + 1):
						if PixelPaint.shown(c + d * r, k * (1.0 - float(r) / float(reach + 1) * 0.5)):
							PixelPaint.cell(canvas, c + d * r, tint.lightened(0.4) if r > 1 else Color(1, 1, 1), ART)
				PixelPaint.cell(canvas, c, Color(1, 1, 1), ART)
				if bool(flash.crit) and k > 0.3:
					PixelPaint.ellipse(canvas, point, 8.0 + 22.0 * grow, 8.0 + 22.0 * grow, CRIT_TINT, ART, 2)
			"blast":
				# the spell bursts: white-hot frames, then the element's ring and rays (brighter and wider on a crit)
				blast(canvas, point, k, flash.ramp, 1.3 if bool(flash.crit) else 1.0, ART, int(float(flash.born) * 100.0))
			"scorch":
				# a scorch where a spell struck, fading by the dither (only without the living floor)
				PixelPaint.disc(canvas, point, 6.0, 4.0, tint, ART, 0.6 * k)


## A small, soft bloom for the glow layer, in the shot's colour only (no white
## burn-out): the pixel shapes stay readable under it.
func draw_glow(canvas: CanvasItem, snapshot: Dictionary, position: Callable, clock: float, level: float) -> void:
	if level <= 0.0: return
	for bullet: Dictionary in snapshot.get("bullets", []):
		if not handles(bullet): continue
		var id := int(bullet.get("id", -1))
		var track: Dictionary = _tracks.get(id, {})
		var point: Vector2 = position.call(bullet)
		var crit := bool(bullet.get("critical", false))
		var tint: Color = CRIT_TINT if crit and str(bullet.style) == "arrow" else track.get("tint", ARROW_TINT)
		if str(bullet.style) == "arrow":
			Glow.dot(canvas, point, _room(point, 12.0), Color(tint, 0.18 * level))
		else:
			Glow.dot(canvas, point, _room(point, 24.0), Color(tint, 0.28 * level))
	for flash: Dictionary in _flashes:
		if str(flash.kind) == "scorch": continue
		var k := 1.0 - clampf((clock - float(flash.born)) / float(flash.life), 0.0, 1.0)
		var radius := 40.0 if str(flash.kind) == "blast" else 22.0
		Glow.dot(canvas, flash.pos, _room(flash.pos, radius * (0.6 + 0.4 * k)), Color(flash.tint, 0.3 * k * level))


## The bloom's radius at `point`, cut back to the nearest wall so no glow
## shines through it (PixelPaint.clip, set by the host; else `radius`).
func _room(point: Vector2, radius: float) -> float:
	if not PixelPaint.clip.is_valid(): return radius
	var r := radius
	for i in range(8):
		var dir := Vector2.from_angle(TAU * float(i) / 8.0)
		var step := 4.0
		while step < r:
			if not PixelPaint.clip.call(point + dir * step):
				r = step
				break
			step += 4.0
	return r


## Light in the dark crypt (Vector4 x, y, radius, strength): every flying shot
## lights its surroundings; bursts flare.
func lights(snapshot: Dictionary, position: Callable) -> Array:
	var result: Array = []
	for bullet: Dictionary in snapshot.get("bullets", []):
		if not handles(bullet): continue
		var point: Vector2 = position.call(bullet)
		if str(bullet.style) == "arrow": result.append(Vector4(point.x, point.y, 40.0, 0.6))
		elif int(bullet.get("owner", 0)) <= 0: result.append(Vector4(point.x, point.y, 60.0, 0.85))
		else: result.append(Vector4(point.x, point.y, 72.0, 0.95))
	for flash: Dictionary in _flashes:
		if str(flash.kind) == "scorch": continue
		var k := 1.0 - clampf((_clock - float(flash.born)) / float(flash.life), 0.0, 1.0)
		var point: Vector2 = flash.pos
		result.append(Vector4(point.x, point.y, (110.0 if str(flash.kind) == "blast" else 60.0) * k, k))
	return result
