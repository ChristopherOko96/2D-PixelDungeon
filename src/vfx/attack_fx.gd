extends RefCounted
## The archer's and the mage's basic attacks as every client sees them: a
## light streak behind each arrow (longer and golden on a critical hit), a
## burning orb with orbiting motes and a turning rune ring for each spell, a
## flash where a shot leaves the bow or staff, a burst where it ends, light in
## the dark along its path and bloom in the glow layer. Tinted by the weapon's
## glow colour (items.json "glow", sent as the player's "glow") or by the
## element of the hero's build. Pure presentation: it only reads snapshots.

const Glow = preload("res://src/vfx/glow.gd")
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
	# the mage's shots are fireballs (user wish 30.10.2026): their light and trail burn orange
	if str(player.get("class_id", "")) == "mage" and str(bullet.get("style", "")) == "magic": return Color("ff8a2a")
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

## An arrow: soft outer streak, bright inner streak and a white-hot core
## behind the 0x72 arrow; the air parts in a thin cone at its head.
func draw_arrow(canvas: CanvasItem, bullet: Dictionary, point: Vector2, clock: float) -> void:
	var id := int(bullet.get("id", -1))
	var track: Dictionary = _tracks.get(id, {})
	var crit := bool(bullet.get("critical", false))
	var tint: Color = CRIT_TINT if crit else track.get("tint", ARROW_TINT)
	var aim := Vector2(float(bullet.get("vx", 1.0)), float(bullet.get("vy", 0.0))).normalized()
	if aim.is_zero_approx(): aim = Vector2.RIGHT
	var trail := _trail(id, point, CRIT_STREAK if crit else STREAK)
	var count := trail.size()
	for index in range(count - 1):
		var fade := 1.0 - float(index) / float(maxi(1, count - 1))
		canvas.draw_line(trail[index], trail[index + 1], Color(tint, 0.22 * fade), 7.0 * fade + 1.0)
		canvas.draw_line(trail[index], trail[index + 1], Color(tint.lightened(0.25), 0.6 * fade), 3.0 * fade + 0.5)
		if fade > 0.45: canvas.draw_line(trail[index], trail[index + 1], Color(1, 1, 1, 0.85 * fade), 1.5)
	var side := aim.orthogonal()
	canvas.draw_line(point + aim * 8.0, point - aim * 6.0 + side * 7.0, Color(tint.lightened(0.4), 0.45), 1.0)
	canvas.draw_line(point + aim * 8.0, point - aim * 6.0 - side * 7.0, Color(tint.lightened(0.4), 0.45), 1.0)
	canvas.draw_circle(point + aim * 8.0, 6.0 + sin(clock * 30.0 + float(id)) * 1.0, Color(tint, 0.3))
	var size := Vector2(ARROW.get_width(), ARROW.get_height()) * 2.0
	canvas.draw_set_transform(point.round(), aim.angle() + PI * 0.5, Vector2.ONE)
	canvas.draw_texture_rect(ARROW, Rect2(-size * 0.5, size), false)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	canvas.draw_circle(point + aim * 9.0, 2.0, Color(1, 1, 1, 0.9))
	if crit:
		# A spinning four-point star rides the head of a critical arrow.
		var spin := clock * 14.0
		for ray in range(4):
			var direction := Vector2.from_angle(spin + float(ray) * PI * 0.5)
			canvas.draw_line(point + aim * 9.0 - direction * 3.0, point + aim * 9.0 + direction * 11.0, Color(CRIT_TINT, 0.9), 2.0)
	if particles != null and _rng.randf() < 0.35:
		var drift := -aim * _rng.randf_range(20.0, 60.0) + side * _rng.randf_range(-25.0, 25.0)
		particles.emit(point - aim * 10.0, drift, tint.lightened(0.35), _rng.randf_range(0.18, 0.32), _mode_for(bullet), 1.5, 12.0)


## A spell: a pulsing halo, a trail of shrinking glows, a turning rune ring,
## the orb itself with a white core and three motes circling it.
func draw_orb(canvas: CanvasItem, bullet: Dictionary, point: Vector2, clock: float) -> void:
	var id := int(bullet.get("id", -1))
	var track: Dictionary = _tracks.get(id, {})
	var crit := bool(bullet.get("critical", false))
	var tint: Color = track.get("tint", ORB_TINT)
	if crit: tint = tint.lerp(CRIT_TINT, 0.5)
	var pulse := 0.5 + 0.5 * sin(clock * 18.0 + float(id))
	var trail := _trail(id, point, ORB_TRAIL)
	var count := trail.size()
	for index in range(count - 1, 0, -1):
		var fade := 1.0 - float(index) / float(maxi(1, count - 1))
		canvas.draw_circle(trail[index], 2.0 + 7.0 * fade, Color(tint, 0.3 * fade))
	canvas.draw_circle(point, 18.0 + pulse * 3.0, Color(tint, 0.12))
	canvas.draw_circle(point, 11.0 + pulse * 1.5, Color(tint, 0.3))
	var turn := clock * 4.0 + float(id)
	for rune in range(6):
		var start := turn + float(rune) * TAU / 6.0
		canvas.draw_arc(point, 16.0, start, start + 0.45, 4, Color(tint.lightened(0.35), 0.75), 1.5)
	# A neutral pixel orb (make_fx_sprites.gd) takes the weapon colour exactly.
	if fx != null and fx.has("spell_orb"):
		fx.draw_loop(canvas, "spell_orb", point, 0.0, 1.6, clock + float(id) * 0.1, tint.lightened(0.15), true)
	else:
		canvas.draw_circle(point, 7.0, tint)
	canvas.draw_circle(point, 3.5, Color(1, 1, 1, 0.95))
	for mote in range(3):
		var angle := clock * 10.0 + float(mote) * TAU / 3.0 + float(id)
		var at := point + Vector2(cos(angle) * 13.0, sin(angle) * 6.0)
		canvas.draw_rect(Rect2(at - Vector2(1.5, 1.5), Vector2(3, 3)), Color(tint.lightened(0.55), 0.95))
	if particles != null and _rng.randf() < 0.5:
		var aim := Vector2(float(bullet.get("vx", 1.0)), float(bullet.get("vy", 0.0))).normalized()
		var drift := -aim * _rng.randf_range(10.0, 40.0) + Vector2(_rng.randf_range(-20.0, 20.0), _rng.randf_range(-30.0, 0.0))
		particles.emit(point - aim * 6.0, drift, tint.lightened(0.3), _rng.randf_range(0.25, 0.45), _mode_for(bullet), 2.0, 12.0)


func _mode_for(bullet: Dictionary) -> String:
	match str(bullet.get("element", "")):
		"cinder": return "ember"
		"frost": return "frost"
	return "spark"


## Release flashes and impact bursts, over the actors.
func draw_flashes(canvas: CanvasItem, clock: float) -> void:
	for flash: Dictionary in _flashes:
		var k := 1.0 - clampf((clock - float(flash.born)) / float(flash.life), 0.0, 1.0)
		var grow := 1.0 - k
		var point: Vector2 = flash.pos
		var aim: Vector2 = flash.aim
		var tint: Color = flash.tint
		match str(flash.kind):
			"bow":
				# The string snaps: a crescent of air opens forward, a spark leaves the bow.
				canvas.draw_arc(point, 6.0 + 16.0 * grow, aim.angle() - 0.9, aim.angle() + 0.9, 10, Color(tint.lightened(0.3), 0.8 * k), 2.0)
				canvas.draw_line(point, point + aim * (10.0 + 26.0 * grow), Color(1, 1, 1, k), 3.0 * k + 0.5)
			"cast":
				# A small magic circle flares at the staff and turns away.
				var radius := 8.0 + 18.0 * grow
				canvas.draw_arc(point, radius, 0.0, TAU, 24, Color(tint, 0.8 * k), 2.0)
				canvas.draw_arc(point, radius * 0.62, 0.0, TAU, 18, Color(tint.lightened(0.3), 0.6 * k), 1.0)
				for tick in range(8):
					var angle := clock * 3.0 + float(tick) * TAU / 8.0
					canvas.draw_line(point + Vector2.from_angle(angle) * radius * 0.62, point + Vector2.from_angle(angle) * radius, Color(tint.lightened(0.4), 0.7 * k), 1.0)
				canvas.draw_circle(point, 6.0 * k, Color(1, 1, 1, 0.7 * k))
			"pierce":
				# A four-point star where the arrow struck.
				var reach := (10.0 + 10.0 * grow) * (1.5 if bool(flash.crit) else 1.0)
				for direction: Vector2 in [aim, -aim, aim.orthogonal(), -aim.orthogonal()]:
					canvas.draw_line(point, point + direction * reach, Color(tint.lightened(0.4), k), 2.0)
				canvas.draw_circle(point, 4.0 * k + 1.0, Color(1, 1, 1, k))
				if bool(flash.crit): canvas.draw_arc(point, 8.0 + 22.0 * grow, 0.0, TAU, 20, Color(CRIT_TINT, k), 2.0)
			"nova":
				# The spell bursts: a bright core, a double shock ring and short rays.
				canvas.draw_circle(point, 10.0 + 18.0 * grow, Color(tint, 0.22 * k))
				canvas.draw_arc(point, 10.0 + 34.0 * grow, 0.0, TAU, 28, Color(tint.lightened(0.3), 0.9 * k), 3.0 * k + 1.0)
				canvas.draw_arc(point, 6.0 + 20.0 * grow, 0.0, TAU, 20, Color(1, 1, 1, 0.6 * k), 1.5)
				for ray in range(8):
					var direction := Vector2.from_angle(float(ray) * TAU / 8.0 + float(flash.born))
					canvas.draw_line(point + direction * (12.0 + 26.0 * grow), point + direction * (18.0 + 36.0 * grow), Color(tint.lightened(0.4), k), 2.0)
				canvas.draw_circle(point, 7.0 * k, Color(1, 1, 1, 0.9 * k))


## Bloom for the glow layer: streaks, orbs, flashes.
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
			var trail := _trail(id, point, (CRIT_STREAK if crit else STREAK) * 0.7)
			Glow.line(canvas, point, trail[trail.size() - 1], 16.0, Color(tint, 0.3 * level))
			Glow.dot(canvas, point, 18.0, Color(tint, 0.4 * level))
		else:
			var pulse := 0.85 + 0.15 * sin(clock * 18.0 + float(id))
			var trail := _trail(id, point, ORB_TRAIL)
			Glow.line(canvas, point, trail[trail.size() - 1], 26.0, Color(tint, 0.25 * level))
			Glow.dot(canvas, point, 46.0 * pulse, Color(tint, 0.55 * level))
			Glow.dot(canvas, point, 16.0, Color(1, 1, 1, 0.35 * level))
	for flash: Dictionary in _flashes:
		var k := 1.0 - clampf((clock - float(flash.born)) / float(flash.life), 0.0, 1.0)
		var radius := 70.0 if str(flash.kind) == "nova" else 40.0
		Glow.dot(canvas, flash.pos, radius * (0.6 + 0.4 * k), Color(flash.tint, 0.5 * k * level))


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
