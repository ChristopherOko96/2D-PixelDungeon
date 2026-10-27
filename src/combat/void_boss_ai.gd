extends RefCounted
## Host AI of Der Leerenrufer, the crypt boss on floor 10. It keeps its
## distance and rotates three moves (values in balance.json "void_boss"):
## - beam: the eye opens (telegraph line), then a beam turns slowly after its
##   target, stops at walls and hurts every player it crosses;
## - salve: three soul skulls in a fan from the front claw;
## - summon: two skeleton archers or void bombers (bounded, see limits).
## Body parts gate the moves: eye -> beam, front claw -> salve, back claw ->
## summon. The eye can only be hit while the beam runs ("exposed_action").

const Dungeon = preload("res://src/dungeon/dungeon_generator.gd")
var _game: Node


## Inject the authoritative game instead of using an autoload.
func bind(game: Node) -> void:
	_game = game


func _cfg() -> Dictionary:
	return _game.balance.get("void_boss", {})


func _attack(kind: String) -> Dictionary:
	return _cfg().get("attacks", {}).get(kind, {})


## True for the Leerenrufer; other bosses keep their own logic.
func handles(enemy: Dictionary) -> bool:
	return bool(enemy.get("boss", false)) and str(enemy.get("rig", "")) == "void"


## One host tick for a living Leerenrufer. Returns false for other enemies.
func step(enemy: Dictionary, target_id: int, delta: float) -> bool:
	if not handles(enemy): return false
	if float(enemy.get("hp", 0)) <= 0: return true
	var target: Dictionary = _game.players.get(target_id, {})
	enemy.beam_cooldown = maxf(0.0, float(enemy.get("beam_cooldown", 0.0)) - delta)
	if not str(enemy.get("attack", "")).is_empty():
		_step_attack(enemy, target, delta)
		return true
	if target.is_empty() or int(target.get("hp", 0)) <= 0: return true
	var offset: Vector2 = Vector2(target.pos) - Vector2(enemy.pos)
	_face(enemy, offset)
	enemy.shot_timer = maxf(0.0, float(enemy.get("shot_timer", 0.0)) - delta)
	var visible: bool = not Dungeon.segment_blocked(enemy.pos, target.pos, 0.0, _game.current_layout)
	if float(enemy.shot_timer) <= 0.0 and visible and offset.length() <= float(_cfg().get("attack_range", 520)):
		var move := choose_move(enemy)
		if not move.is_empty():
			_begin(enemy, target_id, Vector2(target.pos), move)
			return true
	_game.crypt_ai._move(enemy, target.pos, {"range_min": float(_cfg().get("keep_min", 150)), "range_max": float(_cfg().get("keep_max", 250))}, visible, delta)
	return true


## The next move: salve and beam twice as likely as summoning; the beam has
## its own cooldown; lost parts remove their move. Seeded by the attack count.
func choose_move(enemy: Dictionary) -> String:
	var parts: RefCounted = _game.body_parts
	var options: Array[String] = []
	if parts.can(enemy, "cast"): options.append_array(["salve", "salve"])
	if parts.can(enemy, "beam") and float(enemy.get("beam_cooldown", 0.0)) <= 0.0: options.append_array(["beam", "beam"])
	if parts.can(enemy, "summon") and _active_summons(enemy) < int(_cfg().get("summon_when_below", 2)): options.append("summon")
	if options.is_empty(): return ""
	var rng := RandomNumberGenerator.new()
	rng.seed = int(enemy.get("id", 0)) * 7919 + int(enemy.get("attacks", 0)) * 104729 + int(_game.floor_seed)
	return options[rng.randi_range(0, options.size() - 1)]


func _face(enemy: Dictionary, vector: Vector2) -> void:
	if vector.length_squared() <= 0.00001: return
	enemy.facing_dir = vector.normalized()
	if absf(vector.x) > 0.01: enemy.face = signf(vector.x)


func _begin(enemy: Dictionary, target_id: int, target_point: Vector2, kind: String) -> void:
	enemy.attack_target = target_id
	enemy.attack_point = target_point
	enemy.attack_aim = (target_point - Vector2(enemy.pos)).normalized()
	if Vector2(enemy.attack_aim).is_zero_approx(): enemy.attack_aim = Vector2.RIGHT
	enemy.attack_kind = kind
	if kind == "beam":
		enemy.beam_angle = Vector2(enemy.attack_aim).angle()
		enemy.beam_cooldown = float(_cfg().get("beam_cooldown", 7.0))
		enemy.beam_tick = 0.0
		enemy.exposed_action = "beam"
		_update_beam(enemy)
	_set_phase(enemy, "windup")


func _set_phase(enemy: Dictionary, phase: String) -> void:
	enemy.attack = phase
	enemy.attack_length = float(_attack(str(enemy.attack_kind)).get(phase, 0.1))
	enemy.attack_time = enemy.attack_length


func _step_attack(enemy: Dictionary, target: Dictionary, delta: float) -> void:
	var kind: String = str(enemy.attack_kind)
	if kind == "beam" and str(enemy.attack) == "active": _channel(enemy, target, delta)
	enemy.attack_time = maxf(0.0, float(enemy.get("attack_time", 0.0)) - delta)
	if float(enemy.attack_time) > 0.0: return
	match str(enemy.attack):
		"windup":
			if _release(enemy): enemy.attacks = int(enemy.get("attacks", 0)) + 1
			_set_phase(enemy, "active")
		"active":
			enemy.erase("exposed_action")
			enemy.erase("beam_to")
			_set_phase(enemy, "recovery")
		_:
			enemy.attack = ""
			enemy.attack_time = 0.0
			enemy.attack_length = 0.0
			enemy.shot_timer = float(_attack(kind).get("cooldown", 1.0))


## Windup end. The beam starts its channel; salve and summon happen here.
func _release(enemy: Dictionary) -> bool:
	var kind: String = str(enemy.attack_kind)
	var data: Dictionary = _attack(kind)
	if kind == "beam": return true
	var aim: Vector2 = enemy.attack_aim
	if kind == "salve":
		var claw: Vector2 = Vector2(enemy.pos) + Vector2(float(enemy.get("face", 1.0)) * float(data.get("claw_x", 22)), float(data.get("claw_y", -8)))
		var spread: float = float(data.get("spread", 0.3))
		var fired := false
		for index in range(int(data.get("count", 3))):
			var angle: float = aim.angle() + (float(index) - (float(data.get("count", 3)) - 1.0) * 0.5) * spread
			var bullet: Dictionary = _game._add_bullet(claw, Vector2.from_angle(angle) * float(data.get("bullet_speed", 170)), 0, float(data.get("damage", 1)),
				{"style": "void_skull", "radius": float(data.get("bullet_radius", 6)), "life": float(data.get("bullet_lifetime", 3.5)), "caster_id": int(enemy.id)})
			fired = fired or not bullet.is_empty()
		return fired
	if kind == "summon":
		var kinds: Array = data.get("kinds", ["skeleton_archer", "void_bomber"])
		var spawned := 0
		var side := Vector2(aim).orthogonal()
		for index in range(int(data.get("count", 2))):
			var minion_kind: String = str(kinds[(int(enemy.get("summons_cast", 0)) + index) % kinds.size()])
			var sign := -1.0 if index % 2 == 0 else 1.0
			for distance: float in [float(data.get("offset", 72)), float(data.get("offset", 72)) * 0.6, float(data.get("offset", 72)) * 1.4]:
				if _game.spawn_crypt_minion(int(enemy.id), Vector2(enemy.pos) + side * sign * distance + aim * 24.0, minion_kind):
					spawned += 1
					break
		return spawned > 0
	return false


## Beam channel: turn toward the target at a bounded rate, clip at walls and
## hurt players near the beam every tick.
func _channel(enemy: Dictionary, target: Dictionary, delta: float) -> void:
	var data: Dictionary = _attack("beam")
	if not target.is_empty() and int(target.get("hp", 0)) > 0:
		var want: float = (Vector2(target.pos) - Vector2(enemy.pos)).angle()
		var turn: float = float(data.get("turn_rate", 0.55)) * delta
		enemy.beam_angle = float(enemy.beam_angle) + clampf(wrapf(want - float(enemy.beam_angle), -PI, PI), -turn, turn)
	_update_beam(enemy)
	enemy.beam_tick = float(enemy.get("beam_tick", 0.0)) - delta
	if float(enemy.beam_tick) > 0.0: return
	enemy.beam_tick = float(data.get("tick", 0.25))
	var from: Vector2 = enemy.pos
	var to: Vector2 = enemy.beam_to
	var width: float = float(data.get("width", 22)) * 0.5 + float(_game.balance.player.radius)
	for id in _game.players:
		var player: Dictionary = _game.players[id]
		if int(player.hp) <= 0: continue
		if _distance_to_segment(Vector2(player.pos), from, to) <= width:
			_game._damage_player(id, int(data.get("damage", 1)), Vector2.from_angle(float(enemy.beam_angle)))


## The beam's end: the first wall along its direction, or its range.
func _update_beam(enemy: Dictionary) -> void:
	var data: Dictionary = _attack("beam")
	var direction := Vector2.from_angle(float(enemy.beam_angle))
	var from: Vector2 = enemy.pos
	var end := from
	var length := float(data.get("range", 560))
	var step := 8.0
	var travelled := 0.0
	while travelled < length:
		var next := end + direction * step
		if Dungeon.segment_blocked(end, next, 2.0, _game.current_layout): break
		end = next
		travelled += step
	enemy.beam_to = end


func _active_summons(enemy: Dictionary) -> int:
	var count := 0
	for other: Dictionary in _game.enemies:
		if float(other.get("hp", 0)) > 0 and int(other.get("caster_id", -1)) == int(enemy.id): count += 1
	return count


static func _distance_to_segment(point: Vector2, from: Vector2, to: Vector2) -> float:
	var segment := to - from
	var along := clampf((point - from).dot(segment) / maxf(segment.length_squared(), 0.00001), 0.0, 1.0)
	return point.distance_to(from + segment * along)
