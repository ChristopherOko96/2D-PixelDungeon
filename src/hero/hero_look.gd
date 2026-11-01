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
## - Staff: held upright at the side, orb above the hand; a spell lifts it
##   and tips it toward the target.
## - A weapon of an element (items.json element, src/item_art.gd) glows in its
##   colour at the blade's tip, the bow's grip or the staff's orb and sheds a
##   few of its motes now and then: embers, drips, rime glints, zaps.
## `px` is world pixels per weapon art pixel; `hero_px` per hero art pixel
## (crypt 2 / 2, story worlds 2 / 3).
## The weapon is a list of pieces (hold): the art with its hand, angle and
## rect, and the effects that go with it (crescent, string, arrow, glow). The
## story worlds hand them to the hero's part rig as its held weapon item
## (src/rig_kit/rig_held.gd, the rig data's "held" block: grip, tip, rest,
## scale, shoulder), which carries them with his body; draw_weapon draws them
## where they are (the crypt view, a hero without a rig figure).

const SWING_TIME := 0.2
## Where the hand holds a blade and where its point is, as shares of the art
## (it points up): the rig data's held grip and tip replace them.
const SWORD_GRIP := Vector2(0.5, 0.9)
const SWORD_TIP := Vector2(0.5, 0.0)
## Where the hand holds a bow (share of its art): its middle.
const BOW_GRIP := Vector2(0.5, 0.5)
## The orb sits this many hero art pixels below the staff's top.
const STAFF_ORB := 2.0
## Staff length in hero art pixels (a 0x72 hero's figure is about 22 of its
## 28 rows tall): a bit shorter than the hero, so the orb sits near the hat.
const STAFF_LENGTH := 18.0
## Where the hand grips the staff, as a share of its length from the orb end.
const STAFF_GRIP := 0.35
## How far (radians) the resting staff may lean toward the aim, and a casting one.
const STAFF_LEAN := 0.5
const STAFF_CAST_LEAN := 0.9
## A cast lifts the staff this many hero art pixels and settles in this many seconds.
const STAFF_LIFT := 3.0
const STAFF_CAST_TIME := 0.28
const AFTERIMAGE_TIME := 0.22
const STRING_COLOR := Color("#d3bfa9")
const SMEAR := Color("#eaf8ff")
const SMEAR_RAGE := Color("#ff6a4a")
const ItemArt = preload("res://src/item_art.gd")
## How many motes a held weapon of an element sheds at a time (src/item_art.gd).
const WEAPON_MOTES := 3
## A fallen hero's weapon (drop_weapon) falls by the shared debris physics
## (src/rig_kit/rig_debris.gd) with assets/data/vfx_gore.json ragdoll.hero_weapon,
## in weapon pixels (px) per second: thrown forward at `speed` and up at `lift`,
## turning at `spin` rad/s, one bounce, then it lies still on its flat side.
const GORE_PATH := "res://assets/data/vfx_gore.json"
static var _drop_phys: Dictionary = {}

var px := 2.0
## World pixels per hero art pixel (the staff is sized and placed by the body).
var hero_px := 2.0
## The staff hand relative to the hero's anchor point, in hero art pixels
## (x toward the facing side), about halfway up the figure.
var staff_hand := Vector2(5, 0)
## Off-hand blade drawn in Rage (and by the second swing).
var off_blade: Texture2D
var nocked_arrow: Texture2D
var _swing: Dictionary = {}
var _shot: Dictionary = {}
var _trail: Dictionary = {}
var _bows: Dictionary = {}
## The weapon each hero last held: key -> {texture, hand, angle, rect} (draw_weapon).
var _held: Dictionary = {}
## A fallen hero's weapon on its own path: key -> {t0, texture, rect, debris
## (a RigDebris with the one piece), steps (fixed steps done)} (drop_weapon).
var _dropped: Dictionary = {}


func _init(pixel: float = 2.0, sword: Texture2D = null, arrow: Texture2D = null) -> void:
	px = pixel
	hero_px = pixel
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


## The weapon in hand, drawn where hold() places it (nothing carries it after:
## the crypt view, a hero drawn without his rig figure). The arguments are
## hold()'s, without the rig's held block.
func draw_weapon(canvas: CanvasItem, key: String, player: Dictionary, point: Vector2, aim: Vector2, clock: float, texture: Texture2D, glow: Color = Color(1, 0.95, 0.8), element: String = "") -> void:
	for piece: Dictionary in hold(key, player, point, aim, clock, texture, glow, element):
		RigHeld.draw(canvas, piece, Transform2D.IDENTITY)


## The style that moves the weapon of `player` (a hero view state): "sword"
## for a melee weapon, "bow" for the archer's, "staff" for every other.
static func style_of(player: Dictionary) -> String:
	if bool(player.get("melee", false)): return "sword"
	return "bow" if str(player.get("class_id", "")) == "archer" else "staff"


## The weapon in hand as held pieces (src/rig_kit/rig_held_host.gd: texture,
## hand, angle, rect, under/over effects; the hero's own weapon carries "main"),
## placed for the hero standing still, `point` being his shoulder: the sword
## swung round it, the bow drawn before it, the staff held at its side.
## `texture` is the weapon art (pointing up); `glow` the shot colour; `element`
## the weapon's element (items.json; "" takes the held weapon's from the
## player's inventory view, none for an unknown or plain weapon). `held` is the
## rig item's held block (RigHeld.spec): its grip, tip, rest and scale (the
## staff's side and length too) replace the look's own when its style is the
## weapon's (style_of). [] without a texture.
func hold(key: String, player: Dictionary, point: Vector2, aim: Vector2, clock: float, texture: Texture2D, glow: Color = Color(1, 0.95, 0.8), element: String = "", held: Dictionary = {}) -> Array[Dictionary]:
	var none: Array[Dictionary] = []
	if texture == null: return none
	var skills: Dictionary = player.get("skills", {})
	if element.is_empty():
		var carried: Dictionary = (player.get("inventory", {}) as Dictionary).get("weapon", {})
		element = str(carried.get("element", ""))
	var style := style_of(player)
	var spec: Dictionary = held if str(held.get("style", "")) == style else {}
	match style:
		"sword": return _sword(key, player, point, aim, clock, texture, skills, glow, element, spec)
		"bow": return _bow_held(key, player, point, aim, clock, texture, skills, glow, element, spec)
	return _staff(key, point, aim, clock, texture, glow, element, spec)


## Where the hero's weapon was really drawn (a piece of hold() as the rig placed
## it, RigHeldHost.drawn): a fall throws it from there.
func held_at(key: String, piece: Dictionary) -> void:
	if piece.get("texture") is Texture2D:
		_hold(key, piece.texture, Vector2(piece.get("hand", Vector2.ZERO)), float(piece.get("angle", 0.0)), Rect2(piece.get("rect", Rect2())))


## The world point of a piece at `share` of its art (0..1 of its rect).
static func art_point(piece: Dictionary, share: Vector2) -> Vector2:
	var rect: Rect2 = piece.rect
	return Transform2D(float(piece.angle), Vector2(piece.hand)) * (rect.position + share * rect.size)


# --- sword -------------------------------------------------------------------------

func _sword(key: String, player: Dictionary, point: Vector2, aim: Vector2, clock: float, texture: Texture2D, skills: Dictionary, glow: Color, element: String, spec: Dictionary) -> Array[Dictionary]:
	var rage := skills.has("rage")
	var reach := float(player.get("reach", 32.0 * px))
	var scale := float(spec.get("scale", 1.0))
	var grip: Vector2 = spec.get("grip", SWORD_GRIP)
	var turn := float(spec.get("rest", 0.0))
	var size := texture.get_size() * px * scale
	var rect := Rect2(-size * grip, size)
	if skills.has("whirl_time"):
		var whirl: Array[Dictionary] = [_whirl(point, reach, clock, texture, rage, rect, turn)]
		return whirl
	var hand := point + aim * 5.0 * px + Vector2(0, px)
	var off_hand := point - aim * 2.0 * px + aim.orthogonal() * 5.0 * px * (1.0 if aim.x >= 0.0 else -1.0) + Vector2(0, px)
	var p := swing_progress(key, clock)
	var main_angle := aim.angle()
	var off_angle := aim.angle() + (-0.9 if aim.x >= 0.0 else 0.9)
	var crescent := Callable()
	if p >= 0.0:
		var swing: Dictionary = _swing[key]
		var dir := int(swing.get("dir", 1))
		var arc := float(swing.get("arc", 2.0))
		var start := float(swing.angle) - arc * 0.5 * dir
		var now := start + arc * dir * ease(p, 0.4)
		var center := point + Vector2(0, -2.0 * px)
		var smear := SMEAR_RAGE if rage else SMEAR
		crescent = func(canvas: CanvasItem, _follow: Transform2D) -> void: _crescent(canvas, center, reach * 0.85, start, now, 1.0 - p, smear)
		if dir > 0:
			main_angle = now
			hand = point + Vector2.RIGHT.rotated(now) * 6.0 * px + Vector2(0, px)
		else:
			off_angle = now
			off_hand = point + Vector2.RIGHT.rotated(now) * 6.0 * px + Vector2(0, px)
	var out: Array[Dictionary] = []
	if rage:
		var blade := off_blade if off_blade != null else texture
		var blade_size := blade.get_size() * px * scale
		out.append({"texture": blade, "hand": off_hand, "angle": off_angle + PI * 0.5 + turn, "rect": Rect2(-blade_size * grip, blade_size), "tint": Color(1.0, 0.8, 0.75), "under": crescent})
		crescent = Callable()
	var main := {"texture": texture, "hand": hand, "angle": main_angle + PI * 0.5 + turn, "rect": rect, "under": crescent, "main": true}
	_hold(key, texture, hand, float(main.angle), rect)
	if not element.is_empty():
		# the element at the blade: its glow at the tip, its motes off the upper half
		var along := Vector2.RIGHT.rotated(main_angle + turn)
		var tip := art_point(main, spec.get("tip", SWORD_TIP))
		main.over = func(canvas: CanvasItem, _follow: Transform2D) -> void:
			ItemArt.draw_tip_glow(canvas, tip - along * px, glow, clock, px)
			ItemArt.draw_weapon_motes(canvas, tip, along, size.y * 0.5, element, clock, px, key.hash(), WEAPON_MOTES)
	out.append(main)
	return out


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


## Whirl: the blade circles the hero twice in the skill's time, inside a fading
## ring (the two crescents go under it). `rect` is the blade's in its hand, `turn`
## the held block's rest. Not the hero's own held place: a fall keeps the last.
func _whirl(point: Vector2, reach: float, clock: float, texture: Texture2D, rage: bool, rect: Rect2, turn: float) -> Dictionary:
	var center := point + Vector2(0, -3.0 * px)
	var angle := fmod(clock * TAU * 2.6, TAU)
	var tint := SMEAR_RAGE if rage else SMEAR
	var rings := func(canvas: CanvasItem, _follow: Transform2D) -> void:
		_crescent(canvas, center, reach * 0.8, angle - 2.6, angle, 1.0, tint)
		_crescent(canvas, center, reach * 0.8, angle - 2.6 + PI, angle + PI, 0.55, tint)
	return {"texture": texture, "hand": center + Vector2.RIGHT.rotated(angle) * 6.0 * px, "angle": angle + PI * 0.5 + turn, "rect": rect, "under": rings}


# --- bow ---------------------------------------------------------------------------

## The bow drawn from the side: wood toward the target, string pulled toward
## the hero (string, nocked arrow and glow go over the bow, with its hand).
func _bow_held(key: String, player: Dictionary, point: Vector2, aim: Vector2, clock: float, texture: Texture2D, skills: Dictionary, glow: Color, element: String, spec: Dictionary) -> Array[Dictionary]:
	var bow: Dictionary = _bow(texture)
	var grip: Vector2 = spec.get("grip", BOW_GRIP)
	var k := px * float(spec.get("scale", 1.0))
	var angle := aim.angle() + float(spec.get("rest", 0.0))
	var hand := point + aim * 4.0 * px + Vector2(0, -1.0 * px)
	var size: Vector2 = bow.size * k
	var draw := _draw_amount(key, player, clock, skills)
	var snap := clock - float(_shot.get(key, {}).get("start", -INF))
	var shake := sin(snap * 90.0) * px * clampf(1.0 - snap / 0.12, 0.0, 1.0) if snap >= 0.0 and snap < 0.12 else 0.0
	var xf := Transform2D(angle, hand)
	var rect := Rect2(-size * grip, size)
	_hold(key, bow.texture, hand, angle, rect)
	var top: Vector2 = xf * ((Vector2(bow.tip_a) - bow.size * grip) * k)
	var bottom: Vector2 = xf * ((Vector2(bow.tip_b) - bow.size * grip) * k)
	var nock := (top + bottom) * 0.5 - aim * (draw * 6.0 * px) + aim.orthogonal() * shake
	var arrow := nocked_arrow
	var over := func(canvas: CanvasItem, follow: Transform2D) -> void:
		canvas.draw_line(top, nock, STRING_COLOR, maxf(1.0, px * 0.5))
		canvas.draw_line(nock, bottom, STRING_COLOR, maxf(1.0, px * 0.5))
		if draw > 0.15 and arrow != null:
			var length := arrow.get_size().y * px
			var center := nock + aim * (length * 0.5 - px)
			canvas.draw_set_transform_matrix(follow * Transform2D(angle + PI * 0.5, center))
			var arrow_size := arrow.get_size() * px
			canvas.draw_texture_rect(arrow, Rect2(-arrow_size * 0.5, arrow_size), false, Color(1, 1, 1, clampf(draw * 2.0, 0.0, 1.0)))
			canvas.draw_set_transform_matrix(follow)
			if draw >= 0.999:
				canvas.draw_circle(nock + aim * length, 2.0 * px + sin(clock * 30.0) * px * 0.5, Color(glow, 0.7))
		if not element.is_empty():
			# the element along the bow: its glow at the grip, its motes between the limb tips
			ItemArt.draw_tip_glow(canvas, hand + aim * px, glow, clock, px)
			ItemArt.draw_weapon_motes(canvas, top, (top - bottom).normalized(), top.distance_to(bottom), element, clock, px, key.hash(), WEAPON_MOTES)
	var out: Array[Dictionary] = [{"texture": bow.texture, "hand": hand, "angle": angle, "rect": rect, "over": over, "main": true}]
	return out


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

## The staff stands upright in the hand at the hero's side, orb up, like a
## wanderer's staff: a little shorter than the hero, gripped below the orb,
## leaning slightly toward the aim. A spell lifts it and tips it at the target,
## then it settles back.
## `spec` (the rig's held block) may give the side (hero art px from the
## shoulder `point` toward the facing side, else staff_hand), the length (hero
## art px, else STAFF_LENGTH), grip, tip (the orb), rest and scale.
func _staff(key: String, point: Vector2, aim: Vector2, clock: float, texture: Texture2D, glow: Color, element: String, spec: Dictionary) -> Array[Dictionary]:
	var side := -1.0 if aim.x < -0.1 else 1.0
	var since := clock - float(_shot.get(key, {}).get("start", -INF))
	var cast := (1.0 - clampf(since / STAFF_CAST_TIME, 0.0, 1.0)) if since >= 0.0 else 0.0
	var tall := float(spec.get("length", STAFF_LENGTH))
	var length := tall * hero_px * float(spec.get("scale", 1.0))
	var size := Vector2(texture.get_width() * length / texture.get_height(), length)
	var at: Vector2 = spec.get("side", staff_hand)
	var hand := point + Vector2(at.x * side, at.y) * hero_px
	hand.y -= (STAFF_LIFT * cast + sin(clock * 2.2) * 0.4) * hero_px
	# upright, leaning a little toward the aim; a cast tips it further at the target
	var toward := wrapf(aim.angle() + PI * 0.5, -PI, PI)
	var tilt := clampf(toward, -STAFF_LEAN, STAFF_LEAN) * 0.4 + clampf(toward, -STAFF_CAST_LEAN, STAFF_CAST_LEAN) * 0.6 * cast + float(spec.get("rest", 0.0))
	var grip: Vector2 = spec.get("grip", Vector2(0.5, STAFF_GRIP))
	var rect := Rect2(-size * grip, size)
	_hold(key, texture, hand, tilt, rect)
	var staff := {"texture": texture, "hand": hand, "angle": tilt, "rect": rect, "main": true}
	if not element.is_empty():
		# the element at the orb: its glow on the orb, its motes rising from it
		var orb := art_point(staff, spec.get("tip", Vector2(0.5, STAFF_ORB / tall)))
		staff.over = func(canvas: CanvasItem, _follow: Transform2D) -> void:
			ItemArt.draw_tip_glow(canvas, orb, glow, clock, px)
			ItemArt.draw_weapon_motes(canvas, orb + Vector2(0, -hero_px), Vector2.DOWN, 3.0 * hero_px, element, clock, px, key.hash(), WEAPON_MOTES)
	var out: Array[Dictionary] = [staff]
	return out


# --- the fallen hero's weapon ------------------------------------------------------

## Remembers where the weapon of `key` is drawn this frame (its transform and
## texture rect), so a fall can throw it from there.
func _hold(key: String, texture: Texture2D, hand: Vector2, angle: float, rect: Rect2) -> void:
	_held[key] = {"texture": texture, "hand": hand, "angle": angle, "rect": rect}


## Draws the weapon of a fallen hero instead of draw_weapon: on the first call it
## leaves the hand where it was last drawn, flies forward (`face` +1 right, -1
## left) and up, turning over, falls to `floor_y` (the hero's feet), bounces once
## and comes to rest on its flat side, like an enemy's held item coming loose:
## one piece of RigDebris (src/rig_kit/rig_debris.gd) on vfx_gore.json
## ragdoll.hero_weapon. `clock` in seconds; the path runs in fixed steps
## (steps_per_s) from its start up to `clock`, so it never depends on frame
## times. Nothing is drawn for a hero who never held a weapon.
func drop_weapon(canvas: CanvasItem, key: String, clock: float, floor_y: float, face: float) -> void:
	if not _dropped.has(key):
		if not _held.has(key): return
		_dropped[key] = _throw(_held[key], clock, floor_y, face)
	var d: Dictionary = _dropped[key]
	var phys: Dictionary = (d.debris as RigDebris).phys
	var step := 1.0 / maxf(1.0, float(phys.get("steps_per_s", 1.0)))
	var due := int(clampf(clock - float(d.t0), 0.0, float(phys.get("settle", 0.0))) / step)
	# a clock that ran back (a new fall at an earlier time) throws it anew
	if due < int(d.steps):
		d = _throw(d.held, float(d.t0), floor_y, d.face)
		_dropped[key] = d
	while int(d.steps) < due:
		(d.debris as RigDebris).step(step)
		d.steps = int(d.steps) + 1
	var rect: Rect2 = d.rect
	var state := drop_state(key)
	var angle := float(state.angle)
	canvas.draw_set_transform(Vector2(state.center) - rect.get_center().rotated(angle), angle, Vector2.ONE)
	canvas.draw_texture_rect(d.texture, rect, false)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Where the fallen weapon of `key` is now: {center (world px), angle (rad)};
## {} when it has not fallen (for tests and capture checks).
func drop_state(key: String) -> Dictionary:
	if not _dropped.has(key): return {}
	var piece: Dictionary = (_dropped[key].debris as RigDebris).pieces[0]
	return {"center": Vector2(float(piece.x), float(piece.y) - float(piece.z)), "angle": float(piece.ang)}


## A weapon leaving the hand `held` ({texture, hand, angle, rect}) at `clock`:
## one RigDebris piece on its floor line (`floor_y` less half its thickness),
## its height above it, thrown along `face` with ragdoll.hero_weapon.
func _throw(held: Dictionary, clock: float, floor_y: float, face: float) -> Dictionary:
	if _drop_phys.is_empty():
		var found: Variant = RigDebris.load_physics(GORE_PATH, "ragdoll").get("hero_weapon", {})
		_drop_phys = found if found is Dictionary else {}
	var rect: Rect2 = held.rect
	var dir := 1.0 if face >= 0.0 else -1.0
	var center: Vector2 = Vector2(held.hand) + rect.get_center().rotated(float(held.angle))
	var rest_y := floor_y - minf(rect.size.x, rect.size.y) * 0.5
	var debris := RigDebris.new(_drop_phys)
	# k: gravity and the speeds are in weapon pixels, px world px each
	debris.add({"x": center.x, "y": rest_y, "z": maxf(0.0, rest_y - center.y), "vx": dir * float(_drop_phys.get("speed", 0.0)) * px, "vy": 0.0,
		"vz": float(_drop_phys.get("lift", 0.0)) * px, "ang": float(held.angle), "spin": dir * float(_drop_phys.get("spin", 0.0)), "k": px, "life": 0.0, "rest": false})
	return {"t0": clock, "texture": held.texture, "rect": rect, "held": held, "face": face, "debris": debris, "steps": 0}


## The hero of `key` stands again: his next fall throws the weapon anew.
func forget_drop(key: String) -> void:
	_dropped.erase(key)
