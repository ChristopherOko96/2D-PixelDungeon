extends RefCounted
## Client art of the talents (snapshot "talents", src/combat/talent_combat.gd):
## poison clouds and set traps on the floor, the wolves, the talent shots and
## short effects. Effects play the pixel-art sheets of scripts/make_fx_sprites.gd
## (fire, frost and arcane rings, the inferno column, absolute zero, shield
## bubble, target mark, spike trap, claws, slashes) over each event's life.
## The 0x72 pack has no wolf, so the wolf is a small pixel figure drawn here
## in the pack's palette. Presentation only.

const FxSprites = preload("res://src/vfx/fx_sprites.gd")
const FX_COLORS := {"fire": Color("ff7a2a"), "ice": Color("8fd8e6"), "arcane": Color("b07bff"), "steel": Color("d8dce6"), "poison": Color("8fd65a")}
## Nova rings per element.
const RINGS := {"fire": "fire_ring", "ice": "frost_ring", "arcane": "arcane_ring", "steel": "steel_ring"}
## Bursts at the start and end of a blink per element.
const BLINKS := {"fire": "fire_burst", "arcane": "blink", "ice": "frost_burst"}
## Shots per talent style: sheet and pixel scale.
const SHOTS := {"frost_lance": ["ice_lance", 1.4], "arcane": ["arcane_orb", 1.3], "fireball": ["fireball", 1.3]}
const INK := Color("1a1414")

var sprites := FxSprites.new()


## Floor layer: zones and traps (under the actors).
func draw_ground(canvas: CanvasItem, state: Dictionary, clock: float) -> void:
	for zone: Dictionary in state.get("zones", []):
		var at := Vector2(float(zone.x), float(zone.y))
		var r := float(zone.r)
		canvas.draw_circle(at, r, Color(0.45, 0.8, 0.25, 0.10))
		if sprites.has("poison_cloud"):
			# a ring of churning clouds and one in the middle
			var cloud := sprites.frame_size("poison_cloud").x * FxSprites.PIXEL
			var scale := clampf(r / cloud, 0.5, 1.2)
			sprites.draw_loop(canvas, "poison_cloud", at, 0.0, scale, clock)
			for i in range(6):
				var spot := at + Vector2.from_angle(TAU * i / 6.0 + clock * 0.15) * r * 0.62
				sprites.draw_loop(canvas, "poison_cloud", spot, 0.0, scale * 0.8, clock + i * 0.37)
		else:
			canvas.draw_arc(at, r, 0.0, TAU, 48, Color(0.55, 0.9, 0.3, 0.6), 2.0)
	for trap: Dictionary in state.get("traps", []):
		var at := Vector2(float(trap.x), float(trap.y))
		var boom := bool(trap.get("boom", false))
		if sprites.has("spike_trap"):
			sprites.draw_at(canvas, "spike_trap", at, 0.0, 1.0, 0.0, Color("ffc890") if boom else Color.WHITE)
		else:
			canvas.draw_arc(at, 12.0, 0.0, TAU, 16, Color("c87a3a") if boom else Color("8a8a96"), 2.0)
		if boom: canvas.draw_rect(Rect2(at - Vector2(3, 4), Vector2(6, 6)), Color(1.0, 0.6, 0.2, 0.6 + 0.4 * sin(clock * 10.0)))


## Actor layer: the wolves.
func draw_pets(canvas: CanvasItem, state: Dictionary, clock: float) -> void:
	for pet: Dictionary in state.get("pets", []):
		var at := Vector2(float(pet.x), float(pet.y)).round()
		var face := -1.0 if float(pet.get("face", 1.0)) < 0.0 else 1.0
		var step := int(clock * 10.0) % 2 if bool(pet.get("moving", false)) else 0
		var lunge := 4.0 if float(pet.get("bite", 0.0)) > 0.0 else 0.0
		var body := Color("8f9cab") if bool(pet.get("pack", false)) else Color("9a9488")
		var dark := body.darkened(0.35)
		canvas.draw_set_transform(at + Vector2(lunge * face, 0), 0.0, Vector2(2.0 * face, 2.0))
		canvas.draw_rect(Rect2(-7, -9, 12, 5), body)
		canvas.draw_rect(Rect2(4, -12, 5, 5), body)
		canvas.draw_rect(Rect2(5, -14, 2, 2), dark)
		canvas.draw_rect(Rect2(8, -14, 1, 2), dark)
		canvas.draw_rect(Rect2(7, -11, 1, 1), Color("ffd34d"))
		canvas.draw_rect(Rect2(9, -9, 1, 1), INK)
		canvas.draw_rect(Rect2(-6, -4, 2, 4 - step), dark)
		canvas.draw_rect(Rect2(2, -4, 2, 3 + step), dark)
		canvas.draw_rect(Rect2(-10, -10, 3, 2), body)
		canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if lunge > 0.0 and sprites.has("claw"):
			sprites.draw_loop(canvas, "claw", at + Vector2(18.0 * face, -16.0), 0.0, 0.7, clock)


## A talent shot ({x, y, vx, vy, style}) as its sheet; false when the style
## has none (the caller draws it its own way).
func draw_bullet(canvas: CanvasItem, bullet: Dictionary, clock: float) -> bool:
	var shot: Array = SHOTS.get(str(bullet.get("style", "")), [])
	if shot.is_empty() or not sprites.has(str(shot[0])): return false
	var at := Vector2(float(bullet.x), float(bullet.y)).round()
	var flight := Vector2(float(bullet.get("vx", 1.0)), float(bullet.get("vy", 0.0)))
	var aim := flight.normalized() if flight.length() > 0.1 else Vector2.RIGHT
	for ghost in range(1, 3):
		sprites.draw_loop(canvas, str(shot[0]), at - aim * ghost * 8.0, aim.angle(), float(shot[1]) - ghost * 0.25, clock - ghost * 0.05, Color(1, 1, 1, 0.4 - ghost * 0.12))
	sprites.draw_loop(canvas, str(shot[0]), at, aim.angle(), float(shot[1]), clock)
	return true


## Effect layer: short events over everything, each sheet played over the
## event's life (span).
func draw_events(canvas: CanvasItem, state: Dictionary) -> void:
	for event: Dictionary in state.get("events", []):
		var at := Vector2(float(event.x), float(event.y))
		var span := maxf(0.05, float(event.get("span", 0.5)))
		var p := 1.0 - clampf(float(event.life) / span, 0.0, 1.0)
		var fade := 1.0 - p
		var fx := str(event.get("fx", "steel"))
		match str(event.kind):
			"nova":
				var talent := str(event.get("talent", ""))
				if talent == "fire_6" and sprites.has("inferno"):
					_ring(canvas, "fire_ring", at, float(event.r), p)
					sprites.draw_at(canvas, "inferno", at + Vector2(0, 10), 0.0, 1.0, p, Color(1, 1, 1, 0.9))
				elif talent == "frost_6" and sprites.has("zero_burst"):
					_ring(canvas, "frost_ring", at, float(event.r), p)
					sprites.draw_at(canvas, "zero_burst", at, 0.0, 1.1, p, Color(1, 1, 1, 0.9))
				elif talent == "berserk_3" and sprites.has("whirl"):
					sprites.draw_at(canvas, "whirl", at, p * TAU, float(event.r) / 72.0, p)
				elif not _ring(canvas, str(RINGS.get(fx, "fire_ring")), at, float(event.r), p):
					var color: Color = FX_COLORS.get(fx, Color("f3ce7d"))
					canvas.draw_arc(at, float(event.r) * (0.3 + 0.7 * p), 0.0, TAU, 48, Color(color, fade), 3.0)
			"shout":
				_ring(canvas, "shout_ring", at, float(event.r), p)
			"blink", "dash", "leap":
				var to := Vector2(float(event.get("tx", at.x)), float(event.get("ty", at.y)))
				var color: Color = FX_COLORS.get(fx, Color("d8dce6"))
				for i in range(8):
					var dot := at.lerp(to, i / 7.0)
					canvas.draw_rect(Rect2(dot - Vector2(2, 2), Vector2(4, 4)), Color(color, fade * (0.3 + i * 0.09)))
				match str(event.kind):
					"blink":
						var burst := str(BLINKS.get(fx, "blink"))
						sprites.draw_at(canvas, burst, at, 0.0, 0.9, p)
						sprites.draw_at(canvas, "blink", to, 0.0, 1.0, p)
					"dash":
						sprites.draw_at(canvas, "slash", to, (to - at).angle(), 1.2, p)
					"leap":
						sprites.draw_at(canvas, "claw", to + Vector2(0, -12), 0.0, 1.0, p)
			"swing":
				var angle := float(event.get("angle", 0.0))
				if sprites.has("slash"):
					sprites.draw_at(canvas, "slash", at, angle, maxf(0.8, float(event.r) / 52.0), p)
				else:
					var arc := float(event.get("arc", 1.8))
					canvas.draw_arc(at, float(event.r), angle - arc * 0.5, angle + arc * 0.5, 16, Color(1, 1, 1, fade), 3.0)
			"crit":
				sprites.draw_at(canvas, "crit_spark", at + Vector2(0, -16), 0.0, 1.2, p)
				canvas.draw_string(ThemeDB.fallback_font, at + Vector2(-10, -30 - 14 * p), "KRIT", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1.0, 0.85, 0.3, fade))
			"shield":
				sprites.draw_at(canvas, "shield_bubble", at + Vector2(0, -14), 0.0, 1.0, p, Color(1, 1, 1, fade))
			"guard":
				sprites.draw_at(canvas, "shield_bubble", at + Vector2(0, -14), 0.0, 1.0, p, Color(0.75, 1.0, 0.6, fade))
			"parry":
				sprites.draw_at(canvas, "crit_spark", at + Vector2(0, -14), 0.0, 1.4, p)
			"mark":
				sprites.draw_loop(canvas, "reticle", at + Vector2(0, -8), 0.0, 1.0, p * 0.75, Color(1, 1, 1, fade))
			"trap":
				if bool(event.get("boom", false)):
					sprites.draw_at(canvas, "fire_burst", at, 0.0, float(event.r) / 56.0, p)
				else:
					sprites.draw_at(canvas, "spike_trap", at, 0.0, 1.2, p)
			"echo":
				_ring(canvas, "arcane_ring", at, 40.0, p)
			"buff":
				_buff(canvas, str(event.get("buff", "")), at, p, fade)
			"cast":
				_cast(canvas, str(event.get("talent", "")), at, p)


## A nova ring scaled so its edge meets `radius` (world px); false without the sheet.
func _ring(canvas: CanvasItem, sheet: String, at: Vector2, radius: float, p: float) -> bool:
	if not sprites.has(sheet): return false
	var edge := sprites.frame_size(sheet).x * 0.47 * FxSprites.PIXEL
	sprites.draw_at(canvas, sheet, at, 0.0, radius / maxf(1.0, edge), p)
	return true


func _buff(canvas: CanvasItem, buff: String, at: Vector2, p: float, fade: float) -> void:
	match buff:
		"frenzy", "bloodlust":
			sprites.draw_at(canvas, "rage_aura", at + Vector2(0, -20), 0.0, 1.2 if buff == "bloodlust" else 1.0, p)
			if buff == "bloodlust": _ring(canvas, "fire_ring", at, 70.0, p)
		"bulwark", "oath":
			sprites.draw_at(canvas, "shield_bubble", at + Vector2(0, -14), 0.0, 1.1, p, Color(1.0, 0.92, 0.7, fade))
		"unbreakable":
			sprites.draw_at(canvas, "shield_bubble", at + Vector2(0, -14), 0.0, 1.4, p, Color(1.0, 0.85, 0.5, fade))
			_ring(canvas, "shout_ring", at, 80.0, p)
		"timebreak":
			_ring(canvas, "arcane_ring", at, 90.0, p)
			sprites.draw_at(canvas, "star_burst", at + Vector2(0, -16), 0.0, 0.8, p, Color(0.8, 0.7, 1.0))
		_:
			sprites.draw_at(canvas, "level_up", at, 0.0, 1.0, p)


## Cast flashes of talents without an event of their own.
func _cast(canvas: CanvasItem, talent: String, at: Vector2, p: float) -> void:
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
