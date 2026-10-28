extends RefCounted
## Client drawing of the bosses' extra moves (boss_moves.gd snapshot
## "boss_zones"): warning circles that fill up before they strike, lanes of a
## charge, breath cones, rings around a whirl or a grab, the vortex, flying
## globs and the pools they leave, the Knochenkoloss's skull; the new enemy
## shots (soul chain, bone spears, bouncing skulls, ice shards, fire arrows,
## spit); and the conditions on heroes and bosses (poison, burns, ice, slow,
## armour, rage). Pure drawing, no game state.

const SKULL := preload("res://assets/sprites/0x72/skull.png")
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
	for zone: Dictionary in snapshot.get("boss_zones", []):
		var at := Vector2(float(zone.x), float(zone.y))
		var radius := float(zone.r)
		var progress := float(zone.p)
		var color := _color(str(zone.st))
		match str(zone.k):
			"strike", "lob": _draw_strike(canvas, zone, at, radius, progress, color, clock)
			"pool": _draw_pool(canvas, at, radius, progress, color, str(zone.st), clock, int(zone.id))
			"lane":
				var to := Vector2(float(zone.tx), float(zone.ty))
				var side := (to - at).normalized().orthogonal() * radius
				var alpha := 0.12 + 0.28 * progress
				canvas.draw_colored_polygon(PackedVector2Array([at + side, to + side, to - side, at - side]), Color(color, alpha))
				for edge: Vector2 in [side, -side]: _dashed(canvas, at + edge, to + edge, Color(color, 0.5 + 0.5 * progress), clock)
			"cone":
				var points := PackedVector2Array([at])
				for index in range(13):
					var angle := float(zone.a) - float(zone.w) * 0.5 + float(zone.w) * float(index) / 12.0
					points.append(at + Vector2.from_angle(angle) * radius)
				canvas.draw_colored_polygon(points, Color(color, 0.1 + 0.3 * progress))
				canvas.draw_polyline(points + PackedVector2Array([at]), Color(color, 0.7), 2.0)
			"ring":
				_circle(canvas, at, radius, Color(color, 0.35 + 0.5 * progress), 2.0)
				canvas.draw_circle(at, radius, Color(color, 0.06 + 0.14 * progress))
			"vortex":
				for arm in range(5):
					var points := PackedVector2Array()
					for step in range(14):
						var k := float(step) / 13.0
						var angle := -clock * 3.0 + float(arm) * TAU / 5.0 + k * 2.6
						points.append(at + Vector2.from_angle(angle) * radius * (1.0 - k * 0.85))
					canvas.draw_polyline(points, Color(color, 0.45), 3.0)
				canvas.draw_circle(at, radius * 0.25, Color(color, 0.18))
			"skull":
				var pulse := 0.5 + 0.5 * sin(clock * 10.0)
				_circle(canvas, at, radius * (1.0 - progress * 0.5), Color(color, 0.6), 2.0)
				canvas.draw_texture_rect(SKULL, Rect2(at - Vector2(16, 24) - Vector2(0, pulse * 3.0), Vector2(32, 32)), false, Color(1.0, 1.0 - 0.4 * pulse, 1.0 - 0.4 * pulse))


func _draw_strike(canvas: CanvasItem, zone: Dictionary, at: Vector2, radius: float, progress: float, color: Color, clock: float) -> void:
	if str(zone.s) == "burst":
		var k := progress
		canvas.draw_circle(at, radius * (0.6 + 0.6 * k), Color(color.lightened(0.4), 0.55 * (1.0 - k)))
		_circle(canvas, at, radius * (1.0 + 0.5 * k), Color(color, 1.0 - k), 3.0)
		return
	# Warning: the circle fills from the middle; the rim blinks faster near the end.
	var blink := 0.6 + 0.4 * sin(clock * (8.0 + 20.0 * progress))
	canvas.draw_circle(at, radius, Color(color, 0.08))
	canvas.draw_circle(at, radius * progress, Color(color, 0.22))
	_circle(canvas, at, radius, Color(color, 0.55 * blink + 0.2), 2.0)
	if str(zone.k) == "lob" and zone.has("fx"):
		# The glob in flight during its last part of the warning.
		var total := float(zone.get("L", 1.0))
		var flight := float(zone.get("fl", 1.0))
		var elapsed := progress * total
		var k := clampf((elapsed - (total - flight)) / maxf(0.01, flight), 0.0, 1.0)
		if k > 0.0:
			var from := Vector2(float(zone.fx), float(zone.fy))
			var point := from.lerp(at, k) + Vector2(0, -sin(k * PI) * 90.0)
			canvas.draw_circle(point, 9.0, INK)
			canvas.draw_circle(point, 7.0, color)
			canvas.draw_circle(point + Vector2(-2, -2), 3.0, color.lightened(0.4))


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


func _circle(canvas: CanvasItem, at: Vector2, radius: float, color: Color, width: float) -> void:
	canvas.draw_arc(at, radius, 0.0, TAU, maxi(16, int(radius / 3.0)), color, width)


func _dashed(canvas: CanvasItem, from: Vector2, to: Vector2, color: Color, clock: float) -> void:
	var length := from.distance_to(to)
	var direction := (to - from) / maxf(1.0, length)
	var offset := fposmod(clock * 60.0, 16.0)
	var travelled := offset - 16.0
	while travelled < length:
		var a := maxf(0.0, travelled)
		var b := minf(length, travelled + 8.0)
		if b > a: canvas.draw_line(from + direction * a, from + direction * b, color, 2.0)
		travelled += 16.0


# --- Enemy shots ---------------------------------------------------------------------

## Draws the new enemy shot styles; false for styles drawn elsewhere.
func draw_bullet(canvas: CanvasItem, bullet: Dictionary, point: Vector2, clock: float) -> bool:
	var aim := Vector2(float(bullet.get("vx", 1)), float(bullet.get("vy", 0))).normalized()
	match str(bullet.get("style", "")):
		"soul_chain":
			for index in range(6):
				var link := point - aim * float(index) * 7.0
				canvas.draw_rect(Rect2(link - Vector2(2, 2), Vector2(4, 4)), Color(COLORS.void, 1.0 - index * 0.14))
			canvas.draw_circle(point, 8.0, INK)
			canvas.draw_circle(point, 6.0, COLORS.void)
			canvas.draw_circle(point, 3.0, Color("f2d8ff"))
		"bone", "flesh":
			var color: Color = COLORS[str(bullet.style)]
			canvas.draw_colored_polygon(PackedVector2Array([point + aim * 8.0, point + aim.orthogonal() * 4.0, point - aim * 6.0, point - aim.orthogonal() * 4.0]), INK)
			canvas.draw_colored_polygon(PackedVector2Array([point + aim * 6.0, point + aim.orthogonal() * 2.5, point - aim * 4.0, point - aim.orthogonal() * 2.5]), color)
		"bone_spear":
			canvas.draw_line(point - aim * 18.0, point + aim * 10.0, INK, 5.0)
			canvas.draw_line(point - aim * 17.0, point + aim * 8.0, COLORS.bone, 3.0)
			canvas.draw_colored_polygon(PackedVector2Array([point + aim * 15.0, point + aim * 6.0 + aim.orthogonal() * 4.0, point + aim * 6.0 - aim.orthogonal() * 4.0]), Color("fdf7ed"))
		"skull":
			canvas.draw_set_transform(point, clock * 9.0, Vector2(1.6, 1.6))
			canvas.draw_texture(SKULL, -Vector2(8, 10))
			canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"ice":
			canvas.draw_colored_polygon(PackedVector2Array([point + aim * 9.0, point + aim.orthogonal() * 4.0, point - aim * 7.0, point - aim.orthogonal() * 4.0]), Color("3d7c8c"))
			canvas.draw_colored_polygon(PackedVector2Array([point + aim * 7.0, point + aim.orthogonal() * 2.0, point - aim * 5.0, point - aim.orthogonal() * 2.0]), COLORS.ice)
		"fire_arrow":
			canvas.draw_line(point - aim * 8.0, point + aim * 7.0, INK, 4.0)
			canvas.draw_line(point - aim * 7.0, point + aim * 6.0, Color("b89b73"), 2.0)
			for index in range(4):
				var ember := point + aim * 6.0 - aim * float(index) * 4.0 + aim.orthogonal() * sin(clock * 30.0 + index) * 2.0
				canvas.draw_rect(Rect2(ember - Vector2(1.5, 1.5), Vector2(3, 3)), Color("ffd36b") if index % 2 == 0 else COLORS.fire)
		"spit":
			canvas.draw_circle(point, 6.0, INK)
			canvas.draw_circle(point, 4.5, COLORS.poison)
			canvas.draw_circle(point - aim * 7.0, 2.5, Color(COLORS.poison, 0.6))
		_: return false
	return true


# --- Conditions on actors ------------------------------------------------------------

## Over the actors: conditions on heroes, armour and rage on enemies.
func draw_over(canvas: CanvasItem, snapshot: Dictionary, clock: float, position: Callable) -> void:
	for key: Variant in snapshot.get("players", {}):
		var player: Dictionary = snapshot.players[key]
		var effects: Array = player.get("effects", [])
		if effects.is_empty() or float(player.get("hp", 0)) <= 0: continue
		var at: Vector2 = position.call(player)
		if "freeze" in effects:
			canvas.draw_rect(Rect2(at + Vector2(-15, -30), Vector2(30, 36)), Color(COLORS.ice, 0.45))
			canvas.draw_rect(Rect2(at + Vector2(-15, -30), Vector2(30, 36)), Color("e8fbff", 0.9), false, 2.0)
		if "slow" in effects or "slip" in effects:
			for index in range(3):
				var angle := clock * 4.0 + float(index) * TAU / 3.0
				canvas.draw_rect(Rect2(at + Vector2(cos(angle) * 14.0, 6.0 + sin(angle) * 5.0) - Vector2(1.5, 1.5), Vector2(3, 3)), Color(COLORS.ice, 0.8))
		if "poison" in effects:
			for index in range(3):
				var phase := fposmod(clock * 1.4 + float(index) * 0.33, 1.0)
				canvas.draw_circle(at + Vector2(-8.0 + index * 8.0, -26.0 - phase * 14.0), 2.0 + phase, Color(COLORS.poison, 1.0 - phase))
		if "burn" in effects:
			for index in range(4):
				var phase := fposmod(clock * 2.0 + float(index) * 0.25, 1.0)
				canvas.draw_rect(Rect2(at + Vector2(-10.0 + index * 6.0, -10.0 - phase * 22.0), Vector2(3, 5)), Color(Color("ffd36b") if index % 2 == 0 else COLORS.fire, 1.0 - phase))
	for enemy: Dictionary in snapshot.get("enemies", []):
		if float(enemy.get("dying_p", -1.0)) >= 0.0: continue
		var at: Vector2 = position.call(enemy)
		var size := float(enemy.get("radius", 14))
		if bool(enemy.get("armor", false)):
			for index in range(16):
				var angle := clock * 2.0 + float(index) * TAU / 16.0
				canvas.draw_rect(Rect2(at + Vector2(cos(angle), sin(angle) * 0.7) * (size + 10.0) - Vector2(0, size * 0.5) - Vector2(1.5, 1.5), Vector2(3, 3)), Color(COLORS.ice, 0.85))
		if bool(enemy.get("rage", false)):
			var pulse := 0.5 + 0.5 * sin(clock * 6.0)
			_circle(canvas, at - Vector2(0, size * 0.4), size + 8.0 + pulse * 4.0, Color("ff4a3a", 0.35 + 0.3 * pulse), 2.0)


## Light from glowing zones (void, fire and poison pools, strikes) for the dark crypt.
func lights(snapshot: Dictionary) -> Array:
	var result: Array = []
	for zone: Dictionary in snapshot.get("boss_zones", []):
		if str(zone.st) in ["void", "fire", "poison", "frost", "ice"] and str(zone.k) in ["pool", "strike", "vortex"]:
			result.append(Vector4(float(zone.x), float(zone.y), maxf(40.0, float(zone.r) * 1.3), 0.6))
	return result
