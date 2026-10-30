extends RefCounted
## Client drawing of the bosses' extra moves (boss_moves.gd snapshot
## "boss_zones"): warning circles that fill up before they strike, lanes of a
## charge, breath cones, rings around a whirl or a grab, the vortex, flying
## globs and the pools they leave, the Knochenkoloss's skull; the new enemy
## shots (soul chain, bone spears, bouncing skulls, ice shards, fire arrows,
## spit); and the conditions on heroes and bosses (poison, burns, ice, slow,
## armour, rage). Pure drawing, no game state. With `pools` (src/vfx/pool_paint.gd,
## set by the host) the pools are opaque pixel materials shaped by the splat's
## physics instead of circles.

const SKULL := preload("res://assets/sprites/0x72/skull.png")
const PixelPaint = preload("res://src/vfx/pixel_paint.gd")
## World px per art pixel of the canvas (the crypt's; the story worlds draw it in crypt units).
const ART := 2.0
## The pools as pixel materials (src/vfx/pool_paint.gd); null draws the old circles.
var pools: RefCounted = null
const INK := Color("1a1414")
const COLORS := {
	"void": Color("c06bd8"), "poison": Color("8fc84a"), "ice": Color("9fe3ee"), "frost": Color("bff0f7"),
	"quake": Color("b08a5a"), "spikes": Color("e6dcc6"), "bone": Color("e6dcc6"), "flesh": Color("c8323a"),
	"fire": Color("f7883a"), "curse": Color("8a6be0"), "charge": Color("e5c58a"), "grab": Color("e5c58a"), "dust": Color("a99d93"),
}


func _color(style: String) -> Color:
	return COLORS.get(style, Color("e5c58a"))


# --- Floor zones ---------------------------------------------------------------------

## Telegraphs and pools on the floor, under the actors.
func draw_ground(canvas: CanvasItem, snapshot: Dictionary, clock: float) -> void:
	if pools != null:
		pools.sync(snapshot.get("boss_zones", []), clock)
		pools.draw(canvas, clock)
	for zone: Dictionary in snapshot.get("boss_zones", []):
		var at := Vector2(float(zone.x), float(zone.y))
		var radius := float(zone.r)
		var progress := float(zone.p)
		var color := _color(str(zone.st))
		match str(zone.k):
			"strike", "lob": _draw_strike(canvas, zone, at, radius, progress, color, clock)
			"pool":
				if pools == null or not pools.handles(str(zone.st)):
					_draw_pool(canvas, at, radius, progress, color, str(zone.st), clock, int(zone.id))
			"lane":
				PixelPaint.lane(canvas, at, Vector2(float(zone.tx), float(zone.ty)), radius, progress, color, INK, ART, clock)
			"cone":
				PixelPaint.cone(canvas, at, radius, float(zone.a), float(zone.w), progress, color, INK, ART, clock)
			"ring":
				PixelPaint.warning(canvas, at, radius, radius, progress, color, INK, ART, clock)
			"vortex":
				# five arms of pixels spiralling in, the eye filling by the dither
				for arm in range(5):
					for step in range(int(radius / ART * 0.9)):
						var k := float(step) / maxf(1.0, radius / ART * 0.9)
						if posmod(step + int(clock * PixelPaint.FPS), 4) == 3:
							continue
						var angle := -floorf(clock * PixelPaint.FPS) / PixelPaint.FPS * 3.0 + float(arm) * TAU / 5.0 + k * 2.6
						var q := PixelPaint.at(at + Vector2.from_angle(angle) * radius * (1.0 - k * 0.85), ART)
						PixelPaint.cell(canvas, q + Vector2i(0, 1), INK, ART)
						PixelPaint.cell(canvas, q, color if k < 0.6 else color.lightened(0.3), ART)
				PixelPaint.disc(canvas, at, radius * 0.25, radius * 0.25, color.darkened(0.4), ART, 0.5)
			"skull":
				var pulse := int(floorf(clock * 10.0)) % 2
				var shrink := 1.0 - progress * 0.5
				PixelPaint.ellipse(canvas, at + Vector2(0, ART), radius * shrink, radius * shrink, INK, ART, 2, int(floorf(clock * PixelPaint.FPS)))
				PixelPaint.ellipse(canvas, at, radius * shrink, radius * shrink, color, ART, 2, int(floorf(clock * PixelPaint.FPS)))
				canvas.draw_texture_rect(SKULL, Rect2((at - Vector2(16, 24) - Vector2(0, float(pulse) * ART)).snapped(Vector2(ART, ART)), Vector2(32, 32)), false, Color(1.0, 1.0 - 0.4 * pulse, 1.0 - 0.4 * pulse))


func _draw_strike(canvas: CanvasItem, zone: Dictionary, at: Vector2, radius: float, progress: float, color: Color, clock: float) -> void:
	if str(zone.s) == "burst":
		PixelPaint.burst(canvas, at, radius, radius, progress, color, ART)
		return
	# Warning on the pixel grid: the area fills by the dither, the rim crawls
	# over a dark underlay and blinks near the end, a ring grows to it.
	PixelPaint.warning(canvas, at, radius, radius, progress, color, INK, ART, clock)
	if str(zone.k) == "lob" and zone.has("fx"):
		# The glob in flight during its last part of the warning.
		var total := float(zone.get("L", 1.0))
		var flight := float(zone.get("fl", 1.0))
		var elapsed := progress * total
		var k := clampf((elapsed - (total - flight)) / maxf(0.01, flight), 0.0, 1.0)
		if k > 0.0:
			var from := Vector2(float(zone.fx), float(zone.fy))
			var point := from.lerp(at, k) + Vector2(0, -sin(k * PI) * 90.0)
			# its shadow on the floor grows as it falls, then the glob itself
			PixelPaint.disc(canvas, from.lerp(at, k), 7.0, 4.0, INK, ART, 0.35 + 0.5 * k)
			PixelPaint.ball(canvas, point, 3, [color.lightened(0.6), color.lightened(0.3), color, color.darkened(0.3)], INK, ART)


func _draw_pool(canvas: CanvasItem, at: Vector2, radius: float, progress: float, color: Color, style: String, clock: float, seed: int) -> void:
	var fade := clampf((1.0 - progress) * 4.0, 0.0, 1.0)
	canvas.draw_set_transform(at, 0.0, Vector2(1.0, 0.62))
	canvas.draw_circle(Vector2.ZERO, radius, Color(color.darkened(0.3), 0.32 * fade))
	canvas.draw_circle(Vector2.ZERO, radius * 0.7, Color(color, 0.28 * fade))
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if style in ["ice", "frost"]:
		for index in range(3):
			var glint := at + Vector2(sin(float(seed) + index * 2.1) * radius * 0.5, cos(float(seed) * 1.3 + index) * radius * 0.3)
			canvas.draw_rect(Rect2(glint, Vector2(6, 2)), Color(1, 1, 1, 0.5 * fade))
		return
	# Bubbles (poison, void) or flickering flames (fire).
	for index in range(5):
		var phase := fposmod(clock * 0.8 + float(index) * 0.21 + float(seed) * 0.37, 1.0)
		var spot := at + Vector2(sin(float(index) * 2.4 + float(seed)) * radius * 0.6, cos(float(index) * 1.7 + float(seed)) * radius * 0.35)
		if style == "fire":
			canvas.draw_rect(Rect2(spot + Vector2(-2, -phase * 14.0), Vector2(4, 6)), Color(Color("ffd36b") if index % 2 == 0 else color, (1.0 - phase) * fade))
		else:
			canvas.draw_circle(spot + Vector2(0, -phase * 6.0), 2.0 + phase * 2.0, Color(color.lightened(0.3), (1.0 - phase) * 0.8 * fade))


# --- Enemy shots ---------------------------------------------------------------------

## Draws the new enemy shot styles on the pixel grid; false for styles drawn elsewhere.
func draw_bullet(canvas: CanvasItem, bullet: Dictionary, point: Vector2, clock: float) -> bool:
	var aim := Vector2(float(bullet.get("vx", 1)), float(bullet.get("vy", 0))).normalized()
	var tq := int(floorf(clock * PixelPaint.FPS))
	match str(bullet.get("style", "")):
		"soul_chain":
			for index in range(1, 6):
				if posmod(index + tq, 2) == 0:
					PixelPaint.cell(canvas, PixelPaint.at(point - aim * float(index) * 7.0, ART), COLORS.void if index < 4 else Color("6a3f8a"), ART)
			PixelPaint.ball(canvas, point, 2, [Color("f2d8ff"), Color("e0a8f0"), COLORS.void, Color("7a3fb8")], INK, ART)
		"bone", "flesh":
			var color: Color = COLORS[str(bullet.style)]
			_shot(canvas, point, aim, 6, [Color("fdf7ed"), color, color, color.darkened(0.35)])
		"bone_spear":
			_shot(canvas, point + aim * 8.0, aim, 13, [Color("fdf7ed"), Color("fdf7ed"), COLORS.bone, COLORS.bone, Color("b8ab92")])
		"skull":
			# turns in quarter steps, drawn at a whole scale
			canvas.draw_set_transform(point.snapped(Vector2(ART, ART)), floorf(clock * 6.0) * PI * 0.5, Vector2(2, 2))
			canvas.draw_texture(SKULL, -Vector2(8, 10))
			canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"ice":
			_shot(canvas, point, aim, 7, [Color("ffffff"), Color("e6fbff"), Color("a6e3f7"), Color("6fbde8"), Color("3b84c4")])
		"fire_arrow":
			_shot(canvas, point, aim, 7, [Color("fdf7ed"), Color("b89b73"), Color("b89b73"), Color("8a6a4a")])
			for index in range(4):
				if posmod(index + tq, 3) != 0:
					var ember := point + aim * 6.0 - aim * float(index) * 4.0 + aim.orthogonal() * float(posmod(index + tq, 3) - 1) * ART
					PixelPaint.cell(canvas, PixelPaint.at(ember, ART), Color("ffd36b") if index % 2 == 0 else COLORS.fire, ART)
		"spit":
			PixelPaint.ball(canvas, point, 2, [Color("e8ff9a"), Color("a8e04a"), COLORS.poison, Color("3b6b2a")], INK, ART)
			if posmod(tq, 2) == 0:
				PixelPaint.cell(canvas, PixelPaint.at(point - aim * 8.0, ART), COLORS.poison, ART)
		_: return false
	return true


## A pointed shot of `n` art px along `aim`: its tip first in `cols` (tip to
## tail), a pixel wide, the middle half two wide, an outline round it.
func _shot(canvas: CanvasItem, point: Vector2, aim: Vector2, n: int, cols: Array) -> void:
	var side := aim.orthogonal()
	var cells := {}
	for i in range(n):
		var q := PixelPaint.at(point - aim * float(i) * ART, ART)
		var col: Color = cols[clampi(i * cols.size() / maxi(1, n), 0, cols.size() - 1)]
		cells[q] = col
		if i > n / 4 and i < n * 3 / 4:
			var w := PixelPaint.at(point - aim * float(i) * ART + side * ART, ART)
			if not cells.has(w):
				cells[w] = col.darkened(0.15)
	for q: Vector2i in cells:
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if not cells.has(q + d):
				PixelPaint.cell(canvas, q + d, INK, ART)
	for q: Vector2i in cells:
		PixelPaint.cell(canvas, q, cells[q], ART)


# --- Conditions on actors ------------------------------------------------------------

## Over the actors on the pixel grid: conditions on heroes (frozen in a block
## of ice, slowed, poisoned, burning), armour and rage on enemies.
func draw_over(canvas: CanvasItem, snapshot: Dictionary, clock: float, position: Callable) -> void:
	var tq := int(floorf(clock * PixelPaint.FPS))
	for key: Variant in snapshot.get("players", {}):
		var player: Dictionary = snapshot.players[key]
		var effects: Array = player.get("effects", [])
		if effects.is_empty() or float(player.get("hp", 0)) <= 0: continue
		var at: Vector2 = position.call(player)
		if "freeze" in effects:
			_ice_block(canvas, at, clock)
		if "slow" in effects or "slip" in effects:
			for index in range(3):
				var angle := floorf(clock * PixelPaint.FPS) / PixelPaint.FPS * 4.0 + float(index) * TAU / 3.0
				var q := PixelPaint.at(at + Vector2(cos(angle) * 14.0, 6.0 + sin(angle) * 5.0), ART)
				PixelPaint.cell(canvas, q + Vector2i(0, 1), INK, ART)
				PixelPaint.cell(canvas, q, Color("e6fbff") if index == 0 else COLORS.ice, ART)
		if "poison" in effects:
			# bubbles rising off the hero, swelling and popping
			for index in range(3):
				var phase := fposmod(clock * 1.4 + float(index) * 0.33, 1.0)
				var q := PixelPaint.at(at + Vector2(-8.0 + index * 8.0, -26.0 - floorf(phase * 7.0) * ART), ART)
				if phase < 0.75:
					PixelPaint.cell(canvas, q, Color("a8e04a"), ART)
					if phase > 0.4:
						for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1)]:
							PixelPaint.cell(canvas, q + d, Color("6fae3a"), ART)
				elif phase < 0.85:
					PixelPaint.cell(canvas, q + Vector2i(-1, -1), Color("e8ff9a"), ART)
					PixelPaint.cell(canvas, q + Vector2i(1, -1), Color("e8ff9a"), ART)
		if "burn" in effects:
			# little flames licking up, stepped, flickering at the pixel frame rate
			for index in range(4):
				var tall := 2 + posmod(tq + index * 2, 3)
				var base := PixelPaint.at(at + Vector2(-10.0 + index * 6.0, -6.0), ART)
				for j in range(tall):
					var col := Color("fff2a0") if j == 0 else Color("ffb03a") if j < tall - 1 else COLORS.fire
					PixelPaint.cell(canvas, base + Vector2i(posmod(j + tq + index, 3) - 1 if j > 1 else 0, -j), col, ART)
	for enemy: Dictionary in snapshot.get("enemies", []):
		if float(enemy.get("dying_p", -1.0)) >= 0.0: continue
		var at: Vector2 = position.call(enemy)
		var size := float(enemy.get("radius", 14))
		if bool(enemy.get("armor", false)):
			for index in range(12):
				var angle := floorf(clock * PixelPaint.FPS) / PixelPaint.FPS * 2.0 + float(index) * TAU / 12.0
				var q := PixelPaint.at(at + Vector2(cos(angle), sin(angle) * 0.7) * (size + 10.0) - Vector2(0, size * 0.5), ART)
				PixelPaint.cell(canvas, q + Vector2i(0, 1), INK, ART)
				PixelPaint.cell(canvas, q, Color("e6fbff") if posmod(index + tq / 2, 4) == 0 else COLORS.ice, ART)
				PixelPaint.cell(canvas, q + Vector2i(0, -1), Color("a6e3f7"), ART)
		if bool(enemy.get("rage", false)):
			var r := size + 8.0 + float(posmod(tq / 2, 2)) * 4.0
			PixelPaint.ellipse(canvas, at - Vector2(0, size * 0.4) + Vector2(0, ART), r, r, INK, ART, 2, tq)
			PixelPaint.ellipse(canvas, at - Vector2(0, size * 0.4), r, r, Color("ff4a3a"), ART, 2, tq)


## A hero frozen in a block of ice that holds all of him, head, weapon and
## feet (the crypt hero stands about 44 px above and 16 px below his point:
## his health bar and his ring): an outlined block, its top face lit, its
## inside half covered by the dither so the hero shows through, two gloss
## streaks and a crack.
func _ice_block(canvas: CanvasItem, at: Vector2, clock: float) -> void:
	var lo := PixelPaint.at(at + Vector2(-21, -48), ART)
	var hi := PixelPaint.at(at + Vector2(20, 18), ART)
	for y in range(lo.y - 1, hi.y + 2):
		for x in range(lo.x - 1, hi.x + 2):
			var q := Vector2i(x, y)
			if x < lo.x or x > hi.x or y < lo.y or y > hi.y:
				PixelPaint.cell(canvas, q, Color("0d1a38"), ART)
			elif y <= lo.y + 1:
				PixelPaint.cell(canvas, q, Color("e6fbff") if y == lo.y else Color("a6e3f7"), ART)
			elif y == hi.y or x == hi.x:
				PixelPaint.cell(canvas, q, Color("3b84c4"), ART)
			elif x == lo.x:
				PixelPaint.cell(canvas, q, Color("a6e3f7"), ART)
			elif PixelPaint.shown(q, 0.45):
				PixelPaint.cell(canvas, q, Color("6fbde8"), ART)
	for i in range(6):
		PixelPaint.cell(canvas, lo + Vector2i(2 + i, 8 - i), Color("ffffff") if i == 5 else Color("e6fbff"), ART)
	for i in range(3):
		PixelPaint.cell(canvas, lo + Vector2i(5 + i, 8 - i), Color("e6fbff"), ART)
	PixelPaint.cell(canvas, hi + Vector2i(-3, -4), Color("23599a"), ART)
	PixelPaint.cell(canvas, hi + Vector2i(-2, -5), Color("23599a"), ART)
	if posmod(int(floorf(clock * PixelPaint.FPS)), 24) < 2:
		PixelPaint.cell(canvas, lo + Vector2i(1, 2), Color("ffffff"), ART)


## Light from glowing zones (void, fire and poison pools, strikes) for the dark crypt.
func lights(snapshot: Dictionary) -> Array:
	var result: Array = []
	for zone: Dictionary in snapshot.get("boss_zones", []):
		if str(zone.st) in ["void", "fire", "poison", "frost", "ice"] and str(zone.k) in ["pool", "strike", "vortex"]:
			result.append(Vector4(float(zone.x), float(zone.y), maxf(40.0, float(zone.r) * 1.3), 0.6))
	return result
