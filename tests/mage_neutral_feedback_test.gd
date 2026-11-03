extends SceneTree
## A basic mage impact stays neutral at walls and on splash in every shared view.
const Feedback = preload("res://src/vfx/feedback.gd")
const Attack = preload("res://src/vfx/attack_fx.gd")
class Effects extends RefCounted:
	var names: Array[String] = []
	func clear() -> void:
		names.clear()
	func spawn(name: String, _point: Vector2, _rotation: float, _scale: float, _tint: Color, _speed: float, _floor: bool) -> void:
		names.append(name)
func _initialize() -> void:
	var view := Feedback.new()
	var effects := Effects.new()
	view.fx = effects
	var state := {"room_layout": {"id": "neutral"}, "players": {1: {"class_id": "mage", "glow": "", "x": 100, "y": 100, "hp": 6}}, "enemies": []}
	view.observe(state, 1)
	state.fx_events = [{"id": 1, "kind": "wall_hit", "style": "magic", "o": 1, "x": 150, "y": 100}]
	view.observe(state, 1)
	# Current main uses real particles instead of an obsolete magic_burst sheet.
	var wall_ok := view.particles._particles.any(func(p: Dictionary) -> bool: return Color(p.color).g > Color(p.color).r * 1.3 and Color(p.color).g > Color(p.color).b * 1.15) and not view.particles._particles.any(func(p: Dictionary) -> bool: return str(p.mode) in ["glut", "flame", "smoke"])
	wall_ok = wall_ok and not effects.names.any(func(s: String) -> bool: return s.begins_with("fire"))
	effects.names.clear()
	state.fx_events = []
	state.perk_events = [{"kind": "blast", "o": 1, "x": 180, "y": 100}]
	view.observe(state, 1)
	var attacks := Attack.new()
	attacks.particles = view.particles
	var bullet := {"id": 42, "owner": 1, "style": "magic", "element": "", "x": 180.0, "y": 100.0, "vx": 400.0, "vy": 0.0}
	attacks.observe({"players": state.players, "bullets": [bullet]}, 0.0)
	attacks.observe({"players": state.players, "bullets": []}, 0.05)
	var splash_ok := Attack.element_for(bullet, state.players[1]) != "fire" and attacks._flashes.any(func(f: Dictionary) -> bool: return str(f.kind) == "blast")
	splash_ok = splash_ok and not view.particles._particles.any(func(p: Dictionary) -> bool: return str(p.mode) in ["glut", "flame", "smoke"])
	print("MAGE_NEUTRAL_FEEDBACK checked=2 failures=%d" % [int(not wall_ok) + int(not splash_ok)])
	if not wall_ok: printerr("MAGE_NEUTRAL_FAIL: wall colour/matter")
	if not splash_ok: printerr("MAGE_NEUTRAL_FAIL: splash colour/matter")
	quit(0 if wall_ok and splash_ok else 1)
