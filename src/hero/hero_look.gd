extends RefCounted
## How a class hero moves with its weapon, shared by every world (the crypt view
## and the story worlds). Pure presentation: it reads a hero's view state (the
## crypt snapshot's player fields) and draws.
## - Sword: the body leans into each swing, the blade sweeps a filled crescent;
##   Rage holds a blade in each hand and its second swing crosses back with the
##   other blade; the whirl sends the blade around the hero.
## - Charge (and the archer's backflip): fading afterimages along the path.
## - Bow: the string is pulled back with a nocked arrow before each shot and
##   snaps forward on release; Ballistapfeil holds a full draw.
## - Staff: a short recoil when a spell leaves it.
## `px` is world pixels per art pixel (crypt 2, story worlds 3).

const SWING_TIME := 0.2
const AFTERIMAGE_TIME := 0.22
const STRING_COLOR := Color("#d3bfa9")
const SMEAR := Color("#eaf8ff")
const SMEAR_RAGE := Color("#ff6a4a")

var px := 2.0
## Off-hand blade drawn in Rage (and by the second swing).
var off_blade: Texture2D
var nocked_arrow: Texture2D
var _swing: Dictionary = {}
var _shot: Dictionary = {}
var _trail: Dictionary = {}
var _bows: Dictionary = {}


func _init(pixel: float = 2.0, sword: Texture2D = null, arrow: Texture2D = null) -> void:
	px = pixel
	off_blade = sword
	nocked_arrow = arrow


## Call once per frame per hero, before drawing: tracks swings, shots and the dash path.
func observe(key: String, player: Dictionary, point: Vector2, clock: float) -> void:
	var swings := int(player.get("swings", 0))
	var swing: Dictionary = _swing.get(key, {"seen": swings, "start": -INF})
	if swings < int(swing.seen): swing.seen = swings
	if swings > int(swing.seen):
		swing.seen = swings
		swing.start = clock
		swing.dir = int(player.get("swing_dir", 1))
		swing.angle = float(player.get("swing_angle", 0.0))
		swing.arc = minf(float(player.get("swing_arc", 2.0)), TAU)
	_swing[key] = swing
	var shots := int(player.get("shots", 0))
	var shot: Dictionary = _shot.get(key, {"seen": shots, "start": -INF})
	if shots < int(shot.seen): shot.seen = shots
	if shots > int(shot.seen):
		shot.seen = shots
		shot.start = clock
	_shot[key] = shot
	var trail: Array = _trail.get(key, [])
	if (player.get("skills", {}) as Dictionary).has("dash"):
		if trail.is_empty() or Vector2(trail[-1].pos).distance_to(point) >= 3.0 * px:
			trail.append({"pos": point, "t": clock})
	while not trail.is_empty() and clock - float(trail[0].t) > AFTERIMAGE_TIME:
		trail.pop_front()
	_trail[key] = trail


## 0..1 progress of the running swing, or -1.
func swing_progress(key: String, clock: float) -> float:
	var elapsed := clock - float(_swing.get(key, {}).get("start", -INF))
	return elapsed / SWING_TIME if elapsed >= 0.0 and elapsed < SWING_TIME else -1.0


## Which way the hero faces (+1 right, -1 left): the aim, or turning with the blade while it whirls.
func face(player: Dictionary, aim: Vector2, clock: float) -> float:
	if (player.get("skills", {}) as Dictionary).has("whirl_time"):
		return 1.0 if cos(fmod(clock * TAU * 2.6, TAU)) >= 0.0 else -1.0
	return -1.0 if aim.x < -0.1 else 1.0


## The hero sprite leans into a sword swing: forward with the blade, then back.
func body_offset(key: String, player: Dictionary, aim: Vector2, clock: float) -> Vector2:
	var p := swing_progress(key, clock)
	if p < 0.0 or not bool(player.get("melee", false)): return Vector2.ZERO
	return (aim * sin(p * PI) * 3.0 * px).round()


## Afterimages of a dash, oldest faintest. `draw_hero(position, alpha)` draws the hero.
func draw_afterimages(key: String, clock: float, draw_hero: Callable) -> void:
	var trail: Array = _trail.get(key, [])
	for i in range(trail.size()):
		var age := clock - float(trail[i].t)
		var alpha := clampf(1.0 - age / AFTERIMAGE_TIME, 0.0, 1.0) * 0.45
		if alpha > 0.02: draw_hero.call(Vector2(trail[i].pos), alpha)


## Speed lines behind a dashing hero (drawn under it).
func draw_dash_lines(canvas: CanvasItem, key: String, player: Dictionary, point: Vector2, clock: float) -> void:
	var trail: Array = _trail.get(key, [])
	if trail.size() < 2: return
	var back := (Vector2(trail[0].pos) - point)
	if back.length() < 4.0: return
	var dir := back.normalized()
	var side := dir.orthogonal()
	var rage := (player.get("skills", {}) as Dictionary).has("rage")
	for i in range(5):
		var offset := side * (float(i) - 2.0) * 4.0 * px + Vector2(0, -6.0 * px)
		var length := back.length() * (0.6 + 0.12 * float((i * 7 + int(clock * 30.0)) % 4))
		var tint := Color(1.0, 0.55, 0.4, 0.5) if rage else Color(1.0, 0.95, 0.85, 0.45)
		canvas.draw_line(point + offset + dir * 6.0 * px, point + offset + dir * length, tint, maxf(1.0, px * 0.5))


## The weapon in hand. `texture` is the weapon art (pointing up); `glow` the shot colour.
func draw_weapon(canvas: CanvasItem, key: String, player: Dictionary, point: Vector2, aim: Vector2, clock: float, texture: Texture2D, glow: Color = Color(1, 0.95, 0.8)) -> void:
	if texture == null: return
	var skills: Dictionary = player.get("skills", {})
	if bool(player.get("melee", false)):
		_draw_sword(canvas, key, player, point, aim, clock, texture, skills)
	elif str(player.get("class_id", "")) == "archer":
		_draw_bow(canvas, key, player, point, aim, clock, texture, skills, glow)
	else:
		_draw_staff(canvas, key, point, aim, clock, texture)


# --- sword -------------------------------------------------------------------------

func _draw_sword(canvas: CanvasItem, key: String, player: Dictionary, point: Vector2, aim: Vector2, clock: float, texture: Texture2D, skills: Dictionary) -> void:
	var rage := skills.has("rage")
	var reach := float(player.get("reach", 32.0 * px))
	var size := texture.get_size() * px
	var hand := point + aim * 5.0 * px + Vector2(0, px)
	var off_hand := point - aim * 2.0 * px + aim.orthogonal() * 5.0 * px * (1.0 if aim.x >= 0.0 else -1.0) + Vector2(0, px)
	var p := swing_progress(key, clock)
	if skills.has("whirl_time"):
		_draw_whirl(canvas, point, reach, clock, texture, rage)
		return
	var main_angle := aim.angle()
	var off_angle := aim.angle() + (-0.9 if aim.x >= 0.0 else 0.9)
	if p >= 0.0:
		var swing: Dictionary = _swing[key]
		var dir := int(swing.get("dir", 1))
		var arc := float(swing.get("arc", 2.0))
		var start := float(swing.angle) - arc * 0.5 * dir
		var now := start + arc * dir * ease(p, 0.4)
		_crescent(canvas, point + Vector2(0, -2.0 * px), reach * 0.85, start, now, 1.0 - p, SMEAR_RAGE if rage else SMEAR)
		if dir > 0:
			main_angle = now
			hand = point + Vector2.RIGHT.rotated(now) * 6.0 * px + Vector2(0, px)
		else:
			off_angle = now
			off_hand = point + Vector2.RIGHT.rotated(now) * 6.0 * px + Vector2(0, px)
	if rage:
		var blade := off_blade if off_blade != null else texture
		_blade(canvas, blade, off_hand, off_angle, blade.get_size() * px, Color(1.0, 0.8, 0.75))
	_blade(canvas, texture, hand, main_angle, size, Color.WHITE)


func _blade(canvas: CanvasItem, texture: Texture2D, hand: Vector2, angle: float, size: Vector2, tint: Color) -> void:
	canvas.draw_set_transform(hand, angle + PI * 0.5, Vector2.ONE)
	canvas.draw_texture_rect(texture, Rect2(Vector2(-size.x * 0.5, -size.y * 0.9), size), false, tint)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## A filled crescent from `from` to `to` (radians): bright at the blade, fading to the tail.
func _crescent(canvas: CanvasItem, center: Vector2, radius: float, from: float, to: float, life: float, tint: Color) -> void:
	var steps := 12
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	var colors := PackedColorArray()
	var inner_colors := PackedColorArray()
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		var a := lerpf(from, to, t)
		outer.append(center + Vector2.RIGHT.rotated(a) * radius)
		inner.append(center + Vector2.RIGHT.rotated(a) * radius * (0.55 + 0.25 * (1.0 - t)))
		colors.append(Color(tint, life * t * 0.75))
		inner_colors.append(Color(tint, 0.0))
	var points := outer.duplicate()
	var all_colors := colors.duplicate()
	for i in range(steps, -1, -1):
		points.append(inner[i])
		all_colors.append(inner_colors[i])
	if absf(to - from) > 0.05:
		canvas.draw_polygon(points, all_colors)
		canvas.draw_polyline(outer, Color(1, 1, 1, life * 0.9), maxf(1.0, px))
	# the blade's tip sparkles where it is now
	var tip := center + Vector2.RIGHT.rotated(to) * radius
	canvas.draw_rect(Rect2(tip - Vector2(px, px), Vector2(2.0 * px, 2.0 * px)), Color(1, 1, 1, life))


## Whirl: the blade circles the hero twice in the skill's time, inside a fading ring.
func _draw_whirl(canvas: CanvasItem, point: Vector2, reach: float, clock: float, texture: Texture2D, rage: bool) -> void:
	var center := point + Vector2(0, -3.0 * px)
	var angle := fmod(clock * TAU * 2.6, TAU)
	var tint := SMEAR_RAGE if rage else SMEAR
	_crescent(canvas, center, reach * 0.8, angle - 2.6, angle, 1.0, tint)
	_crescent(canvas, center, reach * 0.8, angle - 2.6 + PI, angle + PI, 0.55, tint)
	var size := texture.get_size() * px
	_blade(canvas, texture, center + Vector2.RIGHT.rotated(angle) * 6.0 * px, angle, size, Color.WHITE)


# --- bow ---------------------------------------------------------------------------

## The bow drawn from the side: wood toward the target, string pulled toward the hero.
func _draw_bow(canvas: CanvasItem, key: String, player: Dictionary, point: Vector2, aim: Vector2, clock: float, texture: Texture2D, skills: Dictionary, glow: Color) -> void:
	var bow: Dictionary = _bow(texture)
	var angle := aim.angle()
	var hand := point + aim * 4.0 * px + Vector2(0, -1.0 * px)
	var size: Vector2 = bow.size * px
	var draw := _draw_amount(key, player, clock, skills)
	var snap := clock - float(_shot.get(key, {}).get("start", -INF))
	var shake := sin(snap * 90.0) * px * clampf(1.0 - snap / 0.12, 0.0, 1.0) if snap >= 0.0 and snap < 0.12 else 0.0
	var xf := Transform2D(angle, hand)
	canvas.draw_set_transform(hand, angle, Vector2.ONE)
	canvas.draw_texture_rect(bow.texture, Rect2(-size * 0.5, size), false)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var top: Vector2 = xf * ((Vector2(bow.tip_a) - bow.size * 0.5) * px)
	var bottom: Vector2 = xf * ((Vector2(bow.tip_b) - bow.size * 0.5) * px)
	var nock := (top + bottom) * 0.5 - aim * (draw * 6.0 * px) + aim.orthogonal() * shake
	canvas.draw_line(top, nock, STRING_COLOR, maxf(1.0, px * 0.5))
	canvas.draw_line(nock, bottom, STRING_COLOR, maxf(1.0, px * 0.5))
	if draw > 0.15 and nocked_arrow != null:
		var length := nocked_arrow.get_size().y * px
		var center := nock + aim * (length * 0.5 - px)
		canvas.draw_set_transform(center, angle + PI * 0.5, Vector2.ONE)
		var arrow_size := nocked_arrow.get_size() * px
		canvas.draw_texture_rect(nocked_arrow, Rect2(-arrow_size * 0.5, arrow_size), false, Color(1, 1, 1, clampf(draw * 2.0, 0.0, 1.0)))
		canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if draw >= 0.999:
			canvas.draw_circle(nock + aim * length, 2.0 * px + sin(clock * 30.0) * px * 0.5, Color(glow, 0.7))


## How far the string is pulled (0..1): rising between shots while the hero keeps
## shooting, slack when idle, full while Ballistapfeil charges.
func _draw_amount(key: String, player: Dictionary, clock: float, skills: Dictionary) -> float:
	if skills.has("charge"): return 0.45 + 0.55 * clampf(float(skills.charge), 0.0, 1.0)
	var interval := maxf(0.08, float(player.get("shot_interval", 0.5)))
	var since := clock - float(_shot.get(key, {}).get("start", -INF))
	if since > interval * 2.5: return 0.0
	return clampf((since - 0.06) / (interval * 0.75), 0.0, 1.0)


## A bow's art without its string, plus the string's two tips (art pixels).
func _bow(texture: Texture2D) -> Dictionary:
	if _bows.has(texture): return _bows[texture]
	var image := texture.get_image()
	image.decompress()
	image.convert(Image.FORMAT_RGBA8)
	var w := image.get_width()
	var h := image.get_height()
	# the string is the long, thin, straight column on the side away from the wood
	var column := -1
	for x in range(w):
		var count := 0
		for y in range(h):
			if image.get_pixel(x, y).a > 0.5: count += 1
		if count >= int(h * 0.6):
			column = x
			break
	var tip_a := Vector2(0, 0)
	var tip_b := Vector2(0, h)
	if column >= 0:
		var top := -1
		var bottom := -1
		for y in range(h):
			if image.get_pixel(column, y).a > 0.5:
				if top < 0: top = y
				bottom = y
		# keep the dark tips (they belong to the wood), remove the light string between them
		for y in range(top + 1, bottom):
			var c := image.get_pixel(column, y)
			if c.a > 0.5 and c.get_luminance() > 0.5:
				image.set_pixel(column, y, Color(0, 0, 0, 0))
		tip_a = Vector2(column + 0.5, top + 1.5)
		tip_b = Vector2(column + 0.5, bottom - 0.5)
	var result := {"texture": ImageTexture.create_from_image(image), "size": Vector2(w, h), "tip_a": tip_a, "tip_b": tip_b}
	_bows[texture] = result
	return result


# --- staff -------------------------------------------------------------------------

func _draw_staff(canvas: CanvasItem, key: String, point: Vector2, aim: Vector2, clock: float, texture: Texture2D) -> void:
	var since := clock - float(_shot.get(key, {}).get("start", -INF))
	var recoil := (1.0 - clampf(since / 0.15, 0.0, 1.0)) * 2.0 * px if since >= 0.0 else 0.0
	var hand := point + aim * (5.0 * px - recoil) + Vector2(0, px)
	var size := texture.get_size() * px
	canvas.draw_set_transform(hand, aim.angle() + PI * 0.5, Vector2.ONE)
	canvas.draw_texture_rect(texture, Rect2(Vector2(-size.x * 0.5, -size.y * 0.5), size), false)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
