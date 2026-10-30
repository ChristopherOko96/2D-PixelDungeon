extends RefCounted
## The archer's and the mage's basic attacks as every client sees them: a
## light streak behind each arrow (longer and golden on a critical hit), a
## burning orb with orbiting motes and a turning rune ring for each spell, a
## flash where a shot leaves the bow or staff, a burst where it ends, light in
## the dark along its path and a soft, small bloom in the glow layer. Drawn on
## the crypt's art pixel (2 world px, src/vfx/pixel_paint.gd): opaque pixels
## with a dark outline, fading by the ordered dither, cores never whiter than
## a pixel or two (art review, production/qa/evidence/crypt-vfx-review). Tinted by the weapon's
## glow colour (items.json "glow", sent as the player's "glow") or by the
## element of the hero's build. Pure presentation: it only reads snapshots.

const Glow = preload("res://src/vfx/glow.gd")
const PixelPaint = preload("res://src/vfx/pixel_paint.gd")
## World px per art pixel.
const ART := 2.0
const INK := Color("1a1414")
const ARROW := preload("res://assets/sprites/0x72/weapon_arrow.png")
const ELEMENT_TINTS := {"cinder": Color("f7b46b"), "venom": Color("b8d878"), "frost": Color("9bdde6"), "storm": Color("baabe9")}
const ARROW_TINT := Color("f3e3b5")
const ORB_TINT := Color("6fe3a0")
const CRIT_TINT := Color("ffd75a")
## Trail lengths in pixels: arrow, critical arrow, orb.
const STREAK := 64.0
const CRIT_STREAK := 104.0
const ORB_TRAIL := 48.0
const STYLES := ["arrow", "magic"]

## Shared with the other effects (set by the view each frame).
var particles: RefCounted = null
var fx: RefCounted = null
var _tracks: Dictionary = {}
var _flashes: Array[Dictionary] = []
var _clock := 0.0
var _rng := RandomNumberGenerator.new()


## True for the shots this file draws (heroes' arrows and spells).
static func handles(bullet: Dictionary) -> bool:
	return int(bullet.get("owner", 0)) > 0 and str(bullet.get("style", "")) in STYLES


## The colour of a shot: a found weapon's own glow first (its look), then the
## element of the build, then the class default.
static func tint_for(bullet: Dictionary, player: Dictionary) -> Color:
	var glow := str(player.get("glow", ""))
	if not glow.is_empty(): return Color(glow)
	var element := str(bullet.get("element", ""))
	if ELEMENT_TINTS.has(element): return ELEMENT_TINTS[element]
	return ORB_TINT if str(bullet.get("style", "")) == "magic" else ARROW_TINT


## Call once per frame: starts a flash for every new shot, keeps each shot's
## recent path (so trails bend with homing and bounces and never cross a wall)
## and bursts every shot that ended this frame.
func observe(snapshot: Dictionary, clock: float) -> void:
	_clock = clock
	var alive := {}
	var players: Dictionary = snapshot.get("players", {})
	for bullet: Dictionary in snapshot.get("bullets", []):
		if not handles(bullet): continue
		var id := int(bullet.get("id", -1))
		alive[id] = true
		var point := Vector2(float(bullet.x), float(bullet.y))
		var aim := Vector2(float(bullet.get("vx", 1.0)), float(bullet.get("vy", 0.0))).normalized()
		if aim.is_zero_approx(): aim = Vector2.RIGHT
		if not _tracks.has(id):
			var track := {"path": PackedVector2Array([point]), "aim": aim, "style": str(bullet.style), "tint": tint_for(bullet, players.get(int(bullet.owner), {})), "crit": bool(bullet.get("critical", false)), "seen": clock}
			_tracks[id] = track
			_release(track, point)
			continue
		var track: Dictionary = _tracks[id]
		var path: PackedVector2Array = track.path
		if path[path.size() - 1].distance_to(point) > 2.0: path.append(point)
		track.path = _trim(path, CRIT_STREAK + 24.0)
		track.aim = aim
		track.seen = clock
	for id: int in _tracks.keys():
		if alive.has(id): continue
		var track: Dictionary = _tracks[id]
		if clock - float(track.seen) < 0.25: _impact(track)
		_tracks.erase(id)
	_flashes = _flashes.filter(func(flash: Dictionary) -> bool: return clock - float(flash.born) < float(flash.life))


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


func _release(track: Dictionary, point: Vector2) -> void:
	var tint: Color = track.tint
	var aim: Vector2 = track.aim
	if str(track.style) == "arrow":
		_flashes.append({"kind": "bow", "pos": point, "aim": aim, "tint": tint, "born": _clock, "life": 0.2, "crit": track.crit})
		if particles != null: particles.burst(point, tint.lightened(0.4), 6, 170.0, 0.22, aim, 0.35, 2.0, 6.0, "spark", 12.0)
	else:
		_flashes.append({"kind": "cast", "pos": point, "aim": aim, "tint": tint, "born": _clock, "life": 0.34, "crit": track.crit})
		if particles != null: particles.burst(point, tint.lightened(0.25), 10, 110.0, 0.4, aim, 1.0, 2.0, 4.0, "spark", 12.0)


func _impact(track: Dictionary) -> void:
	var path: PackedVector2Array = track.path
	var point := path[path.size() - 1]
	var tint: Color = CRIT_TINT if bool(track.crit) else track.tint
	var aim: Vector2 = track.aim
	if str(track.style) == "arrow":
		_flashes.append({"kind": "pierce", "pos": point, "aim": aim, "tint": tint, "born": _clock, "life": 0.22, "crit": track.crit})
		if particles != null: particles.burst(point, tint.lightened(0.3), 8, 150.0, 0.3, -aim, 1.0, 2.0, 6.0, "spark", 12.0)
	else:
		_flashes.append({"kind": "nova", "pos": point, "aim": aim, "tint": tint, "born": _clock, "life": 0.4, "crit": track.crit})
		if particles != null:
			particles.burst(point, tint.lightened(0.2), 16, 190.0, 0.45, Vector2.ZERO, PI, 2.5, 4.0, "spark", 12.0)
			particles.burst(point, Color(1, 1, 1), 5, 90.0, 0.25, Vector2.ZERO, PI, 2.0, 4.0, "spark", 12.0)


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
		particles.emit(point - aim * 10.0, drift, tint.lightened(0.35), _rng.randf_range(0.18, 0.32), _mode_for(bullet), 1.5, 12.0)


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


## A spell: a ball of the tint's ramp with a dark outline and one white pixel,
## a trail of shrinking pixels behind it, a ring of rune dashes turning round
## it in steps and three motes circling it.
func draw_orb(canvas: CanvasItem, bullet: Dictionary, point: Vector2, clock: float) -> void:
	var id := int(bullet.get("id", -1))
	var track: Dictionary = _tracks.get(id, {})
	var crit := bool(bullet.get("critical", false))
	var tint: Color = track.get("tint", ORB_TINT)
	if crit: tint = tint.lerp(CRIT_TINT, 0.5)
	var tq := int(floorf(clock * PixelPaint.FPS))
	var trail := _trail(id, point, ORB_TRAIL)
	var count := trail.size()
	for index in range(count - 1, 0, -1):
		var fade := 1.0 - float(index) / float(maxi(1, count - 1))
		var q := PixelPaint.at(trail[index], ART)
		if PixelPaint.shown(q, fade):
			PixelPaint.cell(canvas, q, tint if fade > 0.5 else tint.darkened(0.3), ART)
			if fade > 0.7:
				PixelPaint.cell(canvas, q + Vector2i(0, 1), tint.darkened(0.3), ART)
	# the rune ring: dashes on a pixel ellipse, turning in steps
	PixelPaint.ellipse(canvas, point, 16.0, 16.0, Color(tint.lightened(0.35)), ART, 4, tq / 2)
	# a neutral pixel orb (make_fx_sprites.gd) at the art pixel (scale 1) takes the tint exactly
	if fx != null and fx.has("spell_orb"):
		fx.draw_loop(canvas, "spell_orb", point.snapped(Vector2(ART, ART)), 0.0, 1.0, clock + float(id) * 0.1, tint.lightened(0.15), true)
	else:
		PixelPaint.ball(canvas, point, 3, [tint.lightened(0.6), tint.lightened(0.3), tint, tint.darkened(0.3)], INK, ART)
	PixelPaint.cell(canvas, PixelPaint.at(point - Vector2(2, 2), ART), Color(1, 1, 1), ART)
	for mote in range(3):
		var angle := floorf(clock * PixelPaint.FPS) / PixelPaint.FPS * 10.0 + float(mote) * TAU / 3.0 + float(id)
		var q := PixelPaint.at(point + Vector2(cos(angle) * 13.0, sin(angle) * 6.0), ART)
		PixelPaint.cell(canvas, q + Vector2i(0, 1), INK, ART)
		PixelPaint.cell(canvas, q, tint.lightened(0.55), ART)
	if particles != null and _rng.randf() < 0.5:
		var aim := Vector2(float(bullet.get("vx", 1.0)), float(bullet.get("vy", 0.0))).normalized()
		var drift := -aim * _rng.randf_range(10.0, 40.0) + Vector2(_rng.randf_range(-20.0, 20.0), _rng.randf_range(-30.0, 0.0))
		particles.emit(point - aim * 6.0, drift, tint.lightened(0.3), _rng.randf_range(0.25, 0.45), _mode_for(bullet), 2.0, 12.0)


func _mode_for(bullet: Dictionary) -> String:
	match str(bullet.get("element", "")):
		"cinder": return "ember"
		"frost": return "frost"
	return "spark"


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
			"nova":
				# the spell bursts: a core of pixels, a ring running out, short rays
				PixelPaint.disc(canvas, point, 8.0 + 10.0 * grow, 8.0 + 10.0 * grow, tint, ART, 0.8 * k)
				PixelPaint.ellipse(canvas, point, 10.0 + 34.0 * grow, 10.0 + 34.0 * grow, tint.lightened(0.3), ART, 1 if k > 0.5 else 2)
				for ray in range(8):
					var direction := Vector2.from_angle(float(ray) * TAU / 8.0 + float(flash.born))
					for i in range(3):
						var q := PixelPaint.at(point + direction * (14.0 + 30.0 * grow + float(i) * ART), ART)
						if PixelPaint.shown(q, k): PixelPaint.cell(canvas, q, tint.lightened(0.4), ART)
				if k > 0.5:
					var c := PixelPaint.at(point, ART)
					for d: Vector2i in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
						PixelPaint.cell(canvas, c + d, Color(1, 1, 1), ART)


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
		var k := 1.0 - clampf((clock - float(flash.born)) / float(flash.life), 0.0, 1.0)
		var radius := 40.0 if str(flash.kind) == "nova" else 22.0
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
		else: result.append(Vector4(point.x, point.y, 72.0, 0.95))
	for flash: Dictionary in _flashes:
		var k := 1.0 - clampf((_clock - float(flash.born)) / float(flash.life), 0.0, 1.0)
		var point: Vector2 = flash.pos
		result.append(Vector4(point.x, point.y, (110.0 if str(flash.kind) == "nova" else 60.0) * k, k))
	return result
