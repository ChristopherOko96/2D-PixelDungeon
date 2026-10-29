extends RefCounted
## Client art of the talents (snapshot "talents", src/combat/talent_combat.gd):
## poison zones and set traps on the floor, the wolves, and short effects
## (nova rings, teleport trails, sword arcs, crits, shields, parries, marks).
## The 0x72 pack has no wolf, so the wolf is a small pixel figure drawn here
## in the pack's palette. Presentation only.

const FX_COLORS := {"fire": Color("ff7a2a"), "ice": Color("8fd8e6"), "arcane": Color("b07bff"), "steel": Color("d8dce6"), "poison": Color("8fd65a")}
const INK := Color("1a1414")


## Floor layer: zones and traps (under the actors).
func draw_ground(canvas: CanvasItem, state: Dictionary, clock: float) -> void:
	for zone: Dictionary in state.get("zones", []):
		var at := Vector2(float(zone.x), float(zone.y))
		var r := float(zone.r)
		canvas.draw_circle(at, r, Color(0.45, 0.8, 0.25, 0.14 + 0.04 * sin(clock * 3.0)))
		canvas.draw_arc(at, r, 0.0, TAU, 48, Color(0.55, 0.9, 0.3, 0.6), 2.0)
		for i in range(10):
			var a := clock * 0.7 + i * 0.63
			var bubble := at + Vector2(cos(a), sin(a * 1.3)) * r * (0.25 + 0.6 * fmod(i * 0.37, 1.0))
			canvas.draw_rect(Rect2(bubble.round(), Vector2(3, 3)), Color(0.75, 1.0, 0.5, 0.7))
	for trap: Dictionary in state.get("traps", []):
		var at := Vector2(float(trap.x), float(trap.y))
		var boom := bool(trap.get("boom", false))
		canvas.draw_arc(at, 12.0, 0.0, TAU, 16, INK, 5.0)
		canvas.draw_arc(at, 12.0, 0.0, TAU, 16, Color("c87a3a") if boom else Color("8a8a96"), 2.0)
		for k in range(6):
			var tooth := at + Vector2.RIGHT.rotated(TAU * k / 6.0) * 8.0
			canvas.draw_rect(Rect2(tooth - Vector2(1, 1), Vector2(3, 3)), Color("ffb46a") if boom else Color("d8d8e0"))
		if boom: canvas.draw_rect(Rect2(at - Vector2(2, 2), Vector2(4, 4)), Color(1.0, 0.6, 0.2, 0.6 + 0.4 * sin(clock * 10.0)))


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


## Effect layer: short events over everything.
func draw_events(canvas: CanvasItem, state: Dictionary) -> void:
	for event: Dictionary in state.get("events", []):
		var at := Vector2(float(event.x), float(event.y))
		var p := 1.0 - clampf(float(event.life) / 0.5, 0.0, 1.0)
		var fade := 1.0 - p
		match str(event.kind):
			"nova", "shout":
				var color: Color = FX_COLORS.get(str(event.get("fx", "steel")), Color("f3ce7d"))
				var r := float(event.r) * (0.3 + 0.7 * p)
				canvas.draw_circle(at, r, Color(color, 0.18 * fade))
				canvas.draw_arc(at, r, 0.0, TAU, 48, Color(color, fade), 3.0)
			"blink", "dash", "leap":
				var to := Vector2(float(event.get("tx", at.x)), float(event.get("ty", at.y)))
				var color: Color = FX_COLORS.get(str(event.get("fx", "steel")), Color("d8dce6"))
				for i in range(8):
					var dot := at.lerp(to, i / 7.0)
					canvas.draw_rect(Rect2(dot - Vector2(2, 2), Vector2(4, 4)), Color(color, fade * (0.3 + i * 0.09)))
			"swing":
				var angle := float(event.get("angle", 0.0))
				var arc := float(event.get("arc", 1.8))
				canvas.draw_arc(at, float(event.r), angle - arc * 0.5, angle + arc * 0.5, 16, Color(1, 1, 1, fade), 3.0)
			"crit":
				canvas.draw_string(ThemeDB.fallback_font, at + Vector2(-10, -30 - 14 * p), "KRIT", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1.0, 0.85, 0.3, fade))
			"shield", "guard", "parry":
				var color := Color("8fd8e6") if str(event.kind) == "shield" else Color("9fe08a") if str(event.kind) == "guard" else Color("fff2a8")
				canvas.draw_arc(at + Vector2(0, -10), 20.0 + 6.0 * p, 0.0, TAU, 24, Color(color, fade), 2.0)
			"mark":
				canvas.draw_arc(at + Vector2(0, -6), 14.0, 0.0, TAU, 16, Color(1.0, 0.8, 0.3, fade), 2.0)
				canvas.draw_line(at + Vector2(-18, -6), at + Vector2(18, -6), Color(1.0, 0.8, 0.3, fade), 1.0)
				canvas.draw_line(at + Vector2(0, -24), at + Vector2(0, 12), Color(1.0, 0.8, 0.3, fade), 1.0)
			"trap":
				var r := float(event.r) * (0.4 + 0.6 * p)
				var color := Color("ff9a3c") if bool(event.get("boom", false)) else Color("d8d8e0")
				canvas.draw_circle(at, r, Color(color, 0.25 * fade))
				canvas.draw_arc(at, r, 0.0, TAU, 32, Color(color, fade), 3.0)
			"buff", "echo", "cast":
				if str(event.kind) == "cast": continue
				canvas.draw_arc(at + Vector2(0, -14), 18.0 + 10.0 * p, 0.0, TAU, 24, Color(1.0, 0.9, 0.6, fade * 0.8), 2.0)
