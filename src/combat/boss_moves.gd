extends RefCounted
## Extra moves of bosses and crypt enemies (data: assets/data/combat_boss_moves.json,
## design: docs/BOSS-FAEHIGKEITEN.de.md). Between its own attacks an enemy
## with a move set picks a move now and then; every move warns first
## (telegraph zones the clients draw) and can be dodged. Moves run through the
## enemy's attack phases (windup -> active -> recovery), so the figure plays
## its clip. Also kept here: zones on the floor (warning circles, pools,
## lanes, cones, the vortex, flying globs), armour and shields, the rage at
## low HP and the Knochenkoloss rising once from its bones. Host only;
## clients draw `snapshot()`.

const Dungeon = preload("res://src/dungeon/dungeon_generator.gd")
const FxSprites = preload("res://src/vfx/fx_sprites.gd")
const PoolPaint = preload("res://src/vfx/pool_paint.gd")
const DATA_PATH := "res://assets/data/combat_boss_moves.json"
## World px per art pixel in the crypt: pools are shaped on this grid.
const ART := 2.0

var game: Node
var data: Dictionary = {}
## Zones: {id, kind, style, pos, radius, state (warn/burst/live/fly), timer,
## length, damage, effect, hit, ...}.
var zones: Array = []
var _next_id := 1
var _rng := RandomNumberGenerator.new()
## The floor cells of the current room (FxSprites.walkable_cells), for the pools' shapes.
var _walk: Dictionary = {}
var _walk_of: Dictionary = {}


func bind(owner: Node, path: String = DATA_PATH) -> void:
	game = owner
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	data = parsed if parsed is Dictionary else {}
	_rng.seed = 4711


## A new room: no zones left over.
func reset() -> void:
	zones.clear()


func move(id: String) -> Dictionary:
	return data.get("moves", {}).get(id, {})


## The move set of an enemy ({} when it has none).
func set_for(enemy: Dictionary) -> Dictionary:
	var sets: Dictionary = data.get("sets", {})
	if bool(enemy.get("boss", false)) and str(enemy.get("rig", "")) == "void": return sets.get("void", {})
	return sets.get(str(enemy.get("kind", "")), {})


# --- Choosing and running moves -----------------------------------------------------

## One host tick of an enemy's move set. True when a move ran (the caller's
## own AI then waits this tick).
func step(enemy: Dictionary, target_id: int, delta: float) -> bool:
	var moves := set_for(enemy)
	if moves.is_empty() or float(enemy.get("hp", 0)) <= 0: return false
	if float(enemy.get("collapsed", 0.0)) > 0.0: return true
	var cooldowns: Dictionary = enemy.get("move_cooldowns", {})
	for key: String in cooldowns.keys(): cooldowns[key] = float(cooldowns[key]) - delta
	enemy.move_cooldowns = cooldowns
	if enemy.has("move"):
		_run(enemy, delta)
		return true
	if not str(enemy.get("attack", "")).is_empty(): return false
	var target := _target(target_id)
	if target.is_empty(): return false
	# Rage: once, below its threshold, a roar; moves come faster from then on.
	if moves.has("rage_below") and not bool(enemy.get("rage", false)) and float(enemy.hp) < float(enemy.max_hp) * float(moves.rage_below):
		enemy.rage = true
		_begin(enemy, "rage", {"type": "rage", "anim": "roar", "windup": float(data.get("rage", {}).get("roar", 1.2)), "recovery": 0.2}, target_id, target)
		game.add_fx("rage", Vector2(enemy.pos), 60.0)
		return true
	if not enemy.has("move_timer"): enemy.move_timer = _rng.randf_range(float(moves.every[0]), float(moves.every[1])) * 0.6
	enemy.move_timer = float(enemy.move_timer) - delta
	if float(enemy.move_timer) > 0.0: return false
	var choice := choose(enemy, Vector2(target.pos))
	var scale := float(data.get("rage", {}).get("cooldown_scale", 0.6)) if bool(enemy.get("rage", false)) else 1.0
	enemy.move_timer = _rng.randf_range(float(moves.every[0]), float(moves.every[1])) * scale
	if choice.is_empty(): return false
	if bool(choice.get("once", false)): enemy.moves_done = Array(enemy.get("moves_done", [])) + [str(choice.move)]
	cooldowns[str(choice.move)] = float(choice.get("cooldown", 0.0)) * scale
	_begin(enemy, str(choice.move), move(str(choice.move)), target_id, target)
	return true


## The next move by weight among those whose conditions hold ({} for none).
func choose(enemy: Dictionary, target_pos: Vector2) -> Dictionary:
	var moves := set_for(enemy)
	var distance := Vector2(enemy.pos).distance_to(target_pos)
	var options: Array = []
	var total := 0.0
	for entry: Dictionary in moves.get("moves", []):
		var id := str(entry.move)
		if move(id).is_empty(): continue
		if float(enemy.get("move_cooldowns", {}).get(id, 0.0)) > 0.0: continue
		if entry.has("near") and distance > float(entry.near): continue
		if entry.has("far") and distance < float(entry.far): continue
		if entry.has("hp_below") and float(enemy.hp) >= float(enemy.max_hp) * float(entry.hp_below): continue
		if bool(entry.get("once", false)) and Array(enemy.get("moves_done", [])).has(id): continue
		if bool(entry.get("rage", false)) and not bool(enemy.get("rage", false)): continue
		if not _parts_allow(enemy, move(id)): continue
		options.append(entry)
		total += float(entry.get("weight", 1.0))
	if options.is_empty(): return {}
	# A move that only just became possible (hp_below) comes first.
	for entry: Dictionary in options:
		if entry.has("hp_below"): return entry
	var roll := _rng.randf() * total
	for entry: Dictionary in options:
		roll -= float(entry.get("weight", 1.0))
		if roll <= 0.0: return entry
	return options.back()


## Lost body parts take their moves away (no arm, no grab or charge; no eye, no beam).
func _parts_allow(enemy: Dictionary, spec: Dictionary) -> bool:
	var parts: RefCounted = game.body_parts
	if parts == null or not parts.has_parts(enemy): return true
	match str(spec.get("type", "")):
		"grab", "dash", "spin": return parts.can(enemy, "attack")
		"twin_beam": return parts.can(enemy, "beam")
		"bullets", "lob", "cone": return parts.can(enemy, "cast") or parts.can(enemy, "attack")
	return true


func _target(id: int) -> Dictionary:
	var player: Dictionary = game.players.get(id, {})
	return player if not player.is_empty() and int(player.get("hp", 0)) > 0 else {}


func _begin(enemy: Dictionary, id: String, spec: Dictionary, target_id: int, target: Dictionary) -> void:
	var aim := (Vector2(target.pos) - Vector2(enemy.pos)).normalized()
	if aim.is_zero_approx(): aim = Vector2(float(enemy.get("face", 1.0)), 0.0)
	enemy.move = {"id": id, "spec": spec, "phase": "windup", "timer": float(spec.get("windup", 0.5)), "target": target_id, "aim": aim, "point": Vector2(target.pos), "hit": {}, "emit": 0.0, "turn": aim.angle()}
	enemy.attack_aim = aim
	enemy.attack_point = Vector2(target.pos)
	if absf(aim.x) > 0.01: enemy.face = signf(aim.x)
	enemy.facing_dir = aim
	_present(enemy)
	_telegraph(enemy, enemy.move)


## The figure's clip follows the move's phase.
func _present(enemy: Dictionary) -> void:
	var state: Dictionary = enemy.move
	var spec: Dictionary = state.spec
	enemy.attack = str(state.phase)
	enemy.attack_kind = str(spec.get("anim", "attack"))
	enemy.attack_length = maxf(0.01, float(spec.get(str(state.phase), 0.1)))
	enemy.attack_time = float(state.timer)


func _run(enemy: Dictionary, delta: float) -> void:
	var state: Dictionary = enemy.move
	var spec: Dictionary = state.spec
	state.timer = float(state.timer) - delta
	if str(state.phase) == "active": _active(enemy, state, spec, delta)
	if not enemy.has("move"): return
	if float(state.timer) <= 0.0:
		match str(state.phase):
			"windup":
				_release(enemy, state, spec)
				if not enemy.has("move"): return
				state.phase = "active"
				state.timer = float(Dictionary(state.spec).get("active", 0.1))
				enemy.attacks = int(enemy.get("attacks", 0)) + 1
			"active":
				_finish_active(enemy, state, spec)
				state.phase = "recovery"
				state.timer = float(spec.get("recovery", 0.4))
			_:
				enemy.erase("move")
				enemy.attack = ""
				enemy.attack_time = 0.0
				enemy.shot_timer = maxf(float(enemy.get("shot_timer", 0.0)), 0.5)
				return
	_present(enemy)


# --- Telegraphs (move start) ---------------------------------------------------------

func _telegraph(enemy: Dictionary, state: Dictionary) -> void:
	var spec: Dictionary = state.spec
	var windup := float(spec.get("windup", 0.5))
	var from: Vector2 = enemy.pos
	match str(spec.get("type", "")):
		"strikes":
			var points := _strike_points(enemy, state, spec)
			for index in range(points.size()):
				var delay := float(spec.get("step_delay", 0.0)) * index
				var zone := _zone("strike", str(spec.get("style", "void")), points[index], float(spec.get("radius", 30)), windup + float(spec.get("warn", 0.8)) + delay)
				zone.damage = int(spec.get("damage", 1))
				zone.effect = spec.get("effect", {})
				if spec.has("pool"): zone.pool = spec.pool
		"dash":
			if bool(spec.get("away", false)): return
			var zone := _zone("lane", str(spec.get("style", "charge")), from, float(spec.get("width", 40)) * 0.5, windup)
			zone.to = from + Vector2(state.aim) * _free_run(from, state.aim, float(spec.get("distance", 300)), float(enemy.radius))
			zone.follow = int(enemy.id)
		"cone":
			var zone := _zone("cone", str(spec.get("style", "poison")), from, float(spec.get("reach", 150)), windup)
			zone.angle = float(spec.get("angle", 1.0))
			zone.aim = Vector2(state.aim).angle()
			zone.follow = int(enemy.id)
		"grab", "spin":
			var zone := _zone("ring", str(spec.get("style", "grab")), from, float(spec.get("reach", spec.get("radius", 90))), windup)
			zone.follow = int(enemy.id)
		"vortex":
			var zone := _zone("ring", str(spec.get("style", "void")), from, float(spec.get("burst", 90)), windup)
			zone.follow = int(enemy.id)
		"lob":
			var points := _around(Vector2(state.point), int(spec.get("count", 3)), float(spec.get("spread", 80)))
			state.points = points
			for point: Vector2 in points:
				var zone := _zone("lob", str(spec.get("style", "poison")), point, float(spec.get("radius", 30)), windup + float(spec.get("flight", 1.0)))
				zone.from = from + Vector2(0, -30)
				zone.flight = float(spec.get("flight", 1.0))
				zone.damage = int(spec.get("damage", 1))
				zone.pool = spec.get("pool", {})


func _strike_points(enemy: Dictionary, state: Dictionary, spec: Dictionary) -> Array[Vector2]:
	var points: Array[Vector2] = []
	match str(spec.get("pattern", "under_players")):
		"under_players":
			for id: int in game.players:
				var player: Dictionary = game.players[id]
				if int(player.hp) > 0: points.append(Vector2(player.pos))
		"under_target": points.append(Vector2(state.point))
		"self": points.append(Vector2(enemy.pos))
		"near_players":
			var living: Array = game.players.values().filter(func(player: Dictionary) -> bool: return int(player.hp) > 0)
			for index in range(int(spec.get("count", 4))):
				var player: Dictionary = living[index % living.size()] if not living.is_empty() else {}
				var centre: Vector2 = Vector2(player.pos) if not player.is_empty() else Vector2(state.point)
				var spot := centre + Vector2.from_angle(_rng.randf() * TAU) * (_rng.randf() * float(spec.get("spread", 100)) if index > 0 else 0.0)
				if not Dungeon.segment_blocked(spot, spot, 4.0, game.current_layout): points.append(spot)
		"line":
			var spacing := float(spec.get("spacing", 40))
			for index in range(int(spec.get("count", 6))):
				var spot := Vector2(enemy.pos) + Vector2(state.aim) * (float(enemy.radius) + spacing * (index + 1))
				if Dungeon.segment_blocked(Vector2(enemy.pos), spot, 2.0, game.current_layout): break
				points.append(spot)
	return points


func _around(centre: Vector2, count: int, spread: float) -> Array[Vector2]:
	var points: Array[Vector2] = [centre]
	for index in range(1, count):
		for attempt in range(6):
			var spot := centre + Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(spread * 0.4, spread)
			if not Dungeon.segment_blocked(spot, spot, 6.0, game.current_layout):
				points.append(spot)
				break
	return points


## How far an enemy can run along `aim` before a wall (up to `limit`). Big
## bodies slide along walls when they move, so the core half of the body counts.
func _free_run(from: Vector2, aim: Vector2, limit: float, body: float) -> float:
	var radius := body * 0.5
	var travelled := 0.0
	while travelled < limit:
		var next := from + aim * minf(travelled + 16.0, limit)
		if Dungeon.segment_blocked(from + aim * travelled, next, radius, game.current_layout): break
		travelled = minf(travelled + 16.0, limit)
	return travelled


# --- Release (end of windup) ---------------------------------------------------------

func _release(enemy: Dictionary, state: Dictionary, spec: Dictionary) -> void:
	var target := _target(int(state.target))
	if not target.is_empty() and str(spec.get("type", "")) in ["bullets", "cone", "twin_beam"]:
		state.aim = (Vector2(target.pos) - Vector2(enemy.pos)).normalized()
		if Vector2(state.aim).is_zero_approx(): state.aim = Vector2.RIGHT
	match str(spec.get("type", "")):
		"bullets":
			if str(spec.get("pattern", "")) != "spiral": _fire(enemy, state, spec)
		"cone": _cone(enemy, state, spec)
		"dash":
			state.dash_left = _free_run(Vector2(enemy.pos), (-Vector2(state.aim) if bool(spec.get("away", false)) else Vector2(state.aim)), float(spec.get("distance", 300)), float(enemy.radius))
			state.timer = maxf(0.05, float(state.dash_left) / maxf(1.0, float(spec.get("speed", 400))))
			spec = spec.duplicate()
			spec.active = state.timer
			state.spec = spec
		"blink": _blink(enemy, state, spec)
		"grab": _grab(enemy, state, spec)
		"summon": _summon(enemy, spec)
		"armor":
			enemy.armor_scale = float(spec.get("scale", 0.5))
			enemy.armor_time = float(spec.get("time", 4.0))
			enemy.armor_spec = spec
			game.add_fx("armor", Vector2(enemy.pos), float(enemy.radius) + 10.0)
		"shield": _shield(enemy, spec)
		"barrier": _barrier(enemy, state, spec)
		"cage": _cage(enemy, state, spec)
		"twin_beam":
			enemy.twin_beam = float(spec.get("spread", 0.35))
			enemy.erase("move")
			enemy.attack = ""
			enemy.shot_timer = 0.0
			enemy.beam_cooldown = 0.0
			enemy.force_beam = true
			return


func _bullet_meta(enemy: Dictionary, spec: Dictionary) -> Dictionary:
	var meta := {"style": str(spec.get("style", "void_skull")), "radius": float(spec.get("radius", 6)), "life": float(spec.get("life", 3.0)), "caster_id": int(enemy.id)}
	for key: String in ["bounces", "effect", "end_pool"]:
		if spec.has(key): meta[key] = spec[key] if not spec[key] is Dictionary else Dictionary(spec[key]).duplicate(true)
	if bool(spec.get("pierce_players", false)): meta.pierce_players = true
	return meta


func _fire(enemy: Dictionary, state: Dictionary, spec: Dictionary) -> void:
	var origin := Vector2(enemy.pos) + Vector2(state.aim) * float(enemy.radius) * 0.6
	var speed := float(spec.get("speed", 200))
	var damage := float(spec.get("damage", 1))
	var angles: Array[float] = []
	var base := Vector2(state.aim).angle()
	match str(spec.get("pattern", "single")):
		"single": angles.append(base)
		"fan":
			var count := int(spec.get("count", 3))
			for index in range(count): angles.append(base + (float(index) - float(count - 1) * 0.5) * float(spec.get("spread", 0.25)))
		"ring":
			# A full ring with one gap; the gap is set beside the aim, so it must be found.
			var count := int(spec.get("count", 24))
			var gap := float(spec.get("gap", 0.8))
			var gap_at := base + _rng.randf_range(-1.2, 1.2)
			for index in range(count):
				var angle := TAU * float(index) / float(count)
				if absf(wrapf(angle - gap_at, -PI, PI)) < gap * 0.5: continue
				angles.append(angle)
			origin = Vector2(enemy.pos)
	for angle: float in angles:
		game._add_bullet(origin, Vector2.from_angle(angle) * speed, 0, damage, _bullet_meta(enemy, spec))


func _cone(enemy: Dictionary, state: Dictionary, spec: Dictionary) -> void:
	var reach := float(spec.get("reach", 150))
	var half := float(spec.get("angle", 1.0)) * 0.5
	game.add_fx("zone_burst", Vector2(enemy.pos) + Vector2(state.aim) * reach * 0.5, reach * 0.5, {"style": str(spec.get("style", "poison"))})
	for id: int in game.players:
		var player: Dictionary = game.players[id]
		if int(player.hp) <= 0: continue
		var offset: Vector2 = Vector2(player.pos) - Vector2(enemy.pos)
		if offset.length() > reach + float(game.balance.player.radius) or absf(Vector2(state.aim).angle_to(offset)) > half: continue
		if Dungeon.segment_blocked(Vector2(enemy.pos), Vector2(player.pos), 0.0, game.current_layout): continue
		game._damage_player(id, int(spec.get("damage", 1)), offset.normalized())
		game.player_effects.apply_spec(player, spec.get("effect", {}))


func _blink(enemy: Dictionary, state: Dictionary, spec: Dictionary) -> void:
	var from: Vector2 = enemy.pos
	var target := _target(int(state.target))
	var centre: Vector2 = Vector2(target.pos) if bool(spec.get("toward", false)) and not target.is_empty() else from
	var best := from
	for attempt in range(24):
		var spot := centre + Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(float(spec.get("min", 120)), float(spec.get("max", 300)))
		if Dungeon.segment_blocked(spot, spot, float(enemy.radius), game.current_layout): continue
		if Dungeon.find_path(from, spot, float(enemy.radius), game.current_layout).is_empty(): continue
		best = spot
		break
	if best == from: return
	if spec.has("pool"): _pool(from, spec.pool, best - from)
	game.add_fx("blink", from, float(enemy.radius) + 8.0)
	enemy.pos = best
	game.add_fx("blink", best, float(enemy.radius) + 8.0)


func _grab(enemy: Dictionary, state: Dictionary, spec: Dictionary) -> void:
	var reach := float(spec.get("reach", 96)) + float(enemy.radius)
	var best := -1
	var distance := INF
	for id: int in game.players:
		var player: Dictionary = game.players[id]
		if int(player.hp) <= 0: continue
		var gap: float = Vector2(player.pos).distance_to(enemy.pos)
		if gap <= reach and gap < distance:
			best = id
			distance = gap
	game.add_fx("slam", Vector2(enemy.pos) + Vector2(state.aim) * reach * 0.5, reach * 0.5)
	if best < 0: return
	var player: Dictionary = game.players[best]
	var away: Vector2 = (Vector2(player.pos) - Vector2(enemy.pos)).normalized()
	if away.is_zero_approx(): away = Vector2(state.aim)
	game._damage_player(best, int(spec.get("damage", 3)), away)
	player.knockback = away * float(spec.get("throw", 500))


func _summon(enemy: Dictionary, spec: Dictionary) -> void:
	var kinds: Array = spec.get("kinds", [])
	for index in range(kinds.size()):
		var angle := TAU * float(index) / float(maxi(1, kinds.size())) + _rng.randf() * 0.4
		for distance: float in [float(spec.get("offset", 70)), float(spec.get("offset", 70)) * 1.5, float(spec.get("offset", 70)) * 0.7]:
			if game.spawn_crypt_minion(int(enemy.id), Vector2(enemy.pos) + Vector2.from_angle(angle) * distance, str(kinds[index]), true): break


func _shield(enemy: Dictionary, spec: Dictionary) -> void:
	var best: Dictionary = {}
	var distance := float(spec.get("reach", 260))
	for other: Dictionary in game.enemies:
		if other == enemy or float(other.hp) <= 0: continue
		var gap: float = Vector2(other.pos).distance_to(enemy.pos)
		if gap < distance:
			best = other
			distance = gap
	if best.is_empty(): best = enemy
	best.armor_scale = float(spec.get("scale", 0.5))
	best.armor_time = float(spec.get("time", 4.0))
	best.erase("armor_spec")
	game.add_fx("armor", Vector2(best.pos), float(best.radius) + 8.0)


## Ice blocks between the enemy and its target, across the line (breakable).
func _barrier(enemy: Dictionary, state: Dictionary, spec: Dictionary) -> void:
	var centre := Vector2(enemy.pos) + Vector2(state.aim) * float(spec.get("distance", 96))
	var across := Vector2(state.aim).orthogonal()
	var count := int(spec.get("count", 3))
	for index in range(count):
		var spot := centre + across * 32.0 * (float(index) - float(count - 1) * 0.5)
		game.chests.add_block(str(spec.get("block", "ice_block")), Vector2i(floori(spot.x / 32.0), floori(spot.y / 32.0)), int(spec.get("hits", 3)), float(spec.get("time", 8.0)))


## A cage of blocks around the target hero's cell (mates can break it too).
func _cage(enemy: Dictionary, state: Dictionary, spec: Dictionary) -> void:
	var target := _target(int(state.target))
	if target.is_empty(): return
	var cell := Vector2i(floori(Vector2(target.pos).x / 32.0), floori(Vector2(target.pos).y / 32.0))
	target.pos = Vector2(cell) * 32.0 + Vector2(16, 16)
	for offset: Vector2i in [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1)]:
		game.chests.add_block(str(spec.get("block", "bone_cage")), cell + offset, int(spec.get("hits", 2)), float(spec.get("time", 2.5)))


# --- Active phase --------------------------------------------------------------------

func _active(enemy: Dictionary, state: Dictionary, spec: Dictionary, delta: float) -> void:
	match str(spec.get("type", "")):
		"bullets":
			if str(spec.get("pattern", "")) != "spiral": return
			state.emit = float(state.emit) - delta
			state.turn = float(state.turn) + float(spec.get("turn", 1.5)) * delta
			if float(state.emit) > 0.0: return
			state.emit = float(spec.get("rate", 0.2))
			var arms := int(spec.get("arms", 3))
			for index in range(arms):
				var angle := float(state.turn) + TAU * float(index) / float(arms)
				game._add_bullet(Vector2(enemy.pos), Vector2.from_angle(angle) * float(spec.get("speed", 150)), 0, float(spec.get("damage", 1)), _bullet_meta(enemy, spec))
		"dash":
			var direction := -Vector2(state.aim) if bool(spec.get("away", false)) else Vector2(state.aim)
			var before: Vector2 = enemy.pos
			enemy.pos = Dungeon.move_actor(enemy.pos, direction * float(spec.get("speed", 400)) * delta, float(enemy.radius), game.current_layout)
			enemy.moving = true
			if spec.has("lane_pool") and Vector2(state.get("last_pool", Vector2.INF)).distance_to(enemy.pos) > 40.0:
				state.last_pool = Vector2(enemy.pos)
				_pool(Vector2(enemy.pos), spec.lane_pool, direction)
			if float(spec.get("damage", 0)) > 0.0:
				for id: int in game.players:
					var player: Dictionary = game.players[id]
					if int(player.hp) <= 0 or state.hit.has(id): continue
					if Vector2(player.pos).distance_to(enemy.pos) <= float(enemy.radius) + float(spec.get("width", 40)) * 0.3 + float(game.balance.player.radius):
						state.hit[id] = true
						game._damage_player(id, int(spec.damage), direction)
						if spec.has("knock"): player.knockback = direction * float(spec.knock)
			# A charge that runs into a wall leaves the brute dazed.
			if enemy.pos.distance_to(before) < float(spec.get("speed", 400)) * delta * 0.3 and float(state.timer) > 0.05:
				if float(spec.get("stun_on_wall", 0.0)) > 0.0:
					enemy.hitstun = float(spec.stun_on_wall)
					game.add_fx("slam", Vector2(enemy.pos) + direction * float(enemy.radius), 40.0)
				state.timer = 0.0
		"spin":
			state.emit = float(state.emit) - delta
			var target := _target(int(state.target))
			if float(spec.get("chase", 0)) > 0.0 and not target.is_empty():
				enemy.pos = Dungeon.move_actor(enemy.pos, (Vector2(target.pos) - Vector2(enemy.pos)).normalized() * float(spec.chase) * delta, float(enemy.radius), game.current_layout)
				enemy.moving = true
			if float(state.emit) > 0.0: return
			state.emit = float(spec.get("tick", 0.5))
			game.add_fx("zone_burst", Vector2(enemy.pos), float(spec.get("radius", 80)), {"style": str(spec.get("style", "bone"))})
			for id: int in game.players:
				var player: Dictionary = game.players[id]
				if int(player.hp) > 0 and Vector2(player.pos).distance_to(enemy.pos) <= float(spec.get("radius", 80)) + float(game.balance.player.radius):
					game._damage_player(id, int(spec.get("damage", 2)), (Vector2(player.pos) - Vector2(enemy.pos)).normalized())
		"vortex":
			if not state.has("vortex"):
				var zone := _zone("vortex", str(spec.get("style", "void")), Vector2(enemy.pos), float(spec.get("reach", 300)), float(spec.get("active", 2.0)))
				zone.state = "live"
				zone.follow = int(enemy.id)
				state.vortex = zone.id
			for id: int in game.players:
				var player: Dictionary = game.players[id]
				var offset: Vector2 = Vector2(enemy.pos) - Vector2(player.pos)
				if int(player.hp) <= 0 or offset.length() > float(spec.get("reach", 300)) or offset.length() < 4.0: continue
				player.pos = Dungeon.move_actor(player.pos, offset.normalized() * float(spec.get("pull", 110)) * delta, float(game.balance.player.radius), game.current_layout)


func _finish_active(enemy: Dictionary, state: Dictionary, spec: Dictionary) -> void:
	if str(spec.get("type", "")) == "vortex":
		var radius := float(spec.get("burst", 90))
		game.add_fx("zone_burst", Vector2(enemy.pos), radius, {"style": str(spec.get("style", "void"))})
		for id: int in game.players:
			var player: Dictionary = game.players[id]
			if int(player.hp) > 0 and Vector2(player.pos).distance_to(enemy.pos) <= radius + float(game.balance.player.radius):
				game._damage_player(id, int(spec.get("damage", 4)), (Vector2(player.pos) - Vector2(enemy.pos)).normalized())


# --- Zones ---------------------------------------------------------------------------

func _zone(kind: String, style: String, pos: Vector2, radius: float, warn: float) -> Dictionary:
	var zone := {"id": _next_id, "kind": kind, "style": style, "pos": pos, "radius": radius, "state": "warn", "timer": warn, "length": maxf(0.01, warn), "damage": 0, "effect": {}, "hit": {}}
	_next_id += 1
	zones.append(zone)
	return zone


## A pool that stays a while: damage each second, slow or slippery ground.
## Thrown along `dir` it runs out that way and piles up against walls
## (src/vfx/splat_shape.gd); its cells, not its circle, are where it hurts.
func _pool(pos: Vector2, spec: Dictionary, dir := Vector2.ZERO) -> Dictionary:
	var zone := _zone("pool", str(spec.get("style", "poison")), pos, float(spec.get("radius", 36)), float(spec.get("time", 4.0)))
	zone.state = "live"
	zone.dir = dir.normalized() if dir.length() > 0.01 else Vector2.ZERO
	var paint_style := str(zone.style)
	if PoolPaint.settings().get("materials", {}).has(paint_style):
		zone.cells = PoolPaint.shape(pos, zone.dir, float(zone.radius), paint_style, ART, _open_floor, int(zone.id))
	zone.dps = int(spec.get("dps", 0))
	zone.slow = float(spec.get("slow", 0.0))
	zone.slip = bool(spec.get("slip", false))
	zone.tick = {}
	return zone


## A warning circle that strikes heroes (the thorn curse).
func strike_at(pos: Vector2, radius: float, warn: float, damage: int, style: String) -> void:
	var zone := _zone("strike", style, pos, radius, warn)
	zone.damage = damage


## A strike that hurts enemies instead (the thorn ward blessing).
func hero_strike(pos: Vector2, radius: float, warn: float, damage: float, style: String, owner: int) -> void:
	var zone := _zone("strike", style, pos, radius, warn)
	zone.hostile = owner
	zone.hero_damage = damage


## A pool from a thrown potion: it burns or poisons enemies, never heroes.
func hero_pool(pos: Vector2, spec: Dictionary, owner: int) -> void:
	var thrower: Dictionary = game.players.get(owner, {})
	var zone := _pool(pos, spec, pos - Vector2(thrower.pos) if not thrower.is_empty() else Vector2.ZERO)
	zone.hostile = owner
	zone.hero_dps = float(spec.get("dps", 1.0))
	zone.status = str(spec.get("status", ""))
	zone.dps = 0


## A bullet ended (wall, hit or time): a fire arrow leaves its blaze.
func bullet_end(bullet: Dictionary) -> void:
	if bullet.has("end_pool"): _pool(Vector2(bullet.pos), bullet.end_pool, Vector2(float(bullet.get("vx", 0.0)), float(bullet.get("vy", 0.0))))


## A boss bullet struck a hero: its effect (slow, poison, the soul chain's pull).
func bullet_hit(bullet: Dictionary, id: int) -> void:
	var player: Dictionary = game.players.get(id, {})
	if player.is_empty() or not bullet.has("effect"): return
	var effect: Dictionary = bullet.effect
	game.player_effects.apply_spec(player, effect)
	if effect.has("pull"):
		var caster := _enemy(int(bullet.get("caster_id", -1)))
		if not caster.is_empty():
			player.knockback = (Vector2(caster.pos) - Vector2(player.pos)).normalized() * float(effect.pull) * 2.0


## Zones, armour and the Knochenkoloss's rise; call once per host tick in fights.
func update(delta: float) -> void:
	for index in range(zones.size() - 1, -1, -1):
		var zone: Dictionary = zones[index]
		zone.timer = float(zone.timer) - delta
		if zone.has("follow"):
			var owner := _enemy(int(zone.follow))
			if owner.is_empty() and str(zone.kind) in ["lane", "cone", "ring", "vortex"]:
				zones.remove_at(index)
				continue
			if not owner.is_empty() and str(zone.kind) != "lane": zone.pos = Vector2(owner.pos)
		match str(zone.kind):
			"strike", "lob":
				if str(zone.state) == "warn" and float(zone.timer) <= 0.0:
					zone.state = "burst"
					zone.timer = 0.3
					zone.length = 0.3
					_strike(zone)
				elif str(zone.state) == "burst" and float(zone.timer) <= 0.0: zones.remove_at(index)
			"pool":
				if float(zone.timer) <= 0.0:
					zones.remove_at(index)
					continue
				_pool_tick(zone, delta)
			_:
				if float(zone.timer) <= 0.0: zones.remove_at(index)
	for enemy: Dictionary in game.enemies:
		if float(enemy.get("armor_time", 0.0)) > 0.0:
			enemy.armor_time = float(enemy.armor_time) - delta
			if float(enemy.armor_time) <= 0.0:
				enemy.erase("armor_scale")
				if enemy.has("armor_spec") and float(enemy.hp) > 0: _shatter(enemy, enemy.armor_spec)
				enemy.erase("armor_spec")
		if float(enemy.get("collapsed", 0.0)) > 0.0:
			enemy.collapsed = float(enemy.collapsed) - delta
			if float(enemy.collapsed) <= 0.0: _rise(enemy)


func _strike(zone: Dictionary) -> void:
	game.add_fx("zone_burst", Vector2(zone.pos), float(zone.radius), {"style": str(zone.style)})
	if zone.has("hostile"):
		for enemy: Dictionary in game.enemies.duplicate():
			if float(enemy.hp) > 0 and Vector2(enemy.pos).distance_to(zone.pos) <= float(zone.radius) + float(enemy.radius):
				game._damage_enemy(enemy, float(zone.hero_damage), (Vector2(enemy.pos) - Vector2(zone.pos)).normalized(), int(zone.hostile))
		return
	if int(zone.damage) > 0 or not Dictionary(zone.effect).is_empty():
		for id: int in game.players:
			var player: Dictionary = game.players[id]
			if int(player.hp) <= 0 or zone.hit.has(id): continue
			if Vector2(player.pos).distance_to(zone.pos) <= float(zone.radius) + float(game.balance.player.radius):
				zone.hit[id] = true
				if int(zone.damage) > 0: game._damage_player(id, int(zone.damage), (Vector2(player.pos) - Vector2(zone.pos)).normalized())
				game.player_effects.apply_spec(player, zone.effect)
	if zone.has("pool") and not Dictionary(zone.pool).is_empty(): _pool(Vector2(zone.pos), zone.pool, Vector2(zone.pos) - Vector2(zone.from) if zone.has("from") else Vector2.ZERO)


func _pool_tick(zone: Dictionary, delta: float) -> void:
	if zone.has("hostile"):
		var wait := float(zone.get("hero_tick", 0.0)) - delta
		if wait <= 0.0:
			wait = 1.0
			for enemy: Dictionary in game.enemies.duplicate():
				if float(enemy.hp) <= 0 or not _in_pool(zone, Vector2(enemy.pos), float(enemy.radius)): continue
				game._damage_enemy(enemy, float(zone.hero_dps), Vector2.ZERO, int(zone.hostile), true, false)
				if not str(zone.get("status", "")).is_empty(): game.perk_combat._status(enemy, str(zone.status), float(zone.hero_dps), 2.0, int(zone.hostile))
		zone.hero_tick = wait
		return
	for id: int in game.players:
		var player: Dictionary = game.players[id]
		if int(player.hp) <= 0 or not _in_pool(zone, Vector2(player.pos), 0.0): continue
		if bool(zone.slip): game.player_effects.apply(player, "slip", 0.25, 1.0)
		if float(zone.slow) > 0.0: game.player_effects.apply(player, "slow", 0.3, float(zone.slow))
		if int(zone.dps) <= 0: continue
		var wait := float(zone.tick.get(id, 0.0)) - delta
		if wait <= 0.0:
			wait = 1.0
			game.dot_player(id, int(zone.dps), str(zone.style))
		zone.tick[id] = wait


## True when an actor at `pos` (body radius `reach` beyond its feet) stands
## in the pool: on its cells when it has a shape, else inside its circle.
func _in_pool(zone: Dictionary, pos: Vector2, reach: float) -> bool:
	if not zone.has("cells"):
		return pos.distance_to(zone.pos) <= float(zone.radius) + reach
	var cells: Dictionary = zone.cells
	var r := maxf(4.0, reach * 0.5)
	for p: Vector2 in [pos, pos + Vector2(r, 0), pos - Vector2(r, 0), pos + Vector2(0, r * 0.6), pos - Vector2(0, r * 0.6)]:
		if cells.has(Vector2i((p / ART).floor())):
			return true
	return false


## Floor a pool may cover: the room's floor cells (walls and obstacles stop it).
func _open_floor(point: Vector2) -> bool:
	var layout: Dictionary = game.current_layout if game != null else {}
	if not is_same(layout, _walk_of):
		_walk_of = layout
		_walk = FxSprites.walkable_cells(layout)
	return _walk.is_empty() or _walk.has(Vector2i(floori(point.x / 32.0), floori(point.y / 32.0)))


## The ice armour bursts into shards when it ends.
func _shatter(enemy: Dictionary, spec: Dictionary) -> void:
	var count := int(spec.get("shards", 12))
	game.add_fx("zone_burst", Vector2(enemy.pos), float(enemy.radius) + 20.0, {"style": str(spec.get("style", "ice"))})
	for index in range(count):
		var angle := TAU * float(index) / float(count)
		game._add_bullet(Vector2(enemy.pos), Vector2.from_angle(angle) * float(spec.get("speed", 200)), 0, float(spec.get("damage", 1)), {"style": str(spec.get("style", "ice")), "radius": 6.0, "life": 2.5, "caster_id": int(enemy.id)})


# --- Hooks from the game -------------------------------------------------------------

## Damage multiplier of an enemy (armour, a necromancer's bone shield).
func damage_scale(enemy: Dictionary) -> float:
	return float(enemy.get("armor_scale", 1.0)) if float(enemy.get("armor_time", 0.0)) > 0.0 else 1.0


## Called when an enemy would die. The Knochenkoloss falls apart instead (once):
## its skull lies there; hit it hard enough within `time` or it rises again.
## True when the death is held back.
func hold_death(enemy: Dictionary) -> bool:
	var rebuild: Dictionary = set_for(enemy).get("rebuild", {})
	if rebuild.is_empty() or bool(enemy.get("rebuilt", false)): return false
	enemy.rebuilt = true
	enemy.hp = 1.0
	enemy.collapsed = float(rebuild.get("time", 3.0))
	enemy.skull_hp = float(enemy.max_hp) * float(rebuild.get("skull_share", 0.2))
	enemy.erase("move")
	enemy.attack = ""
	var zone := _zone("skull", "bone", Vector2(enemy.pos), float(enemy.radius), float(enemy.collapsed))
	zone.state = "live"
	zone.follow = int(enemy.id)
	enemy.skull_zone = zone.id
	game.add_fx("collapse", Vector2(enemy.pos), float(enemy.radius) + 20.0)
	return true


## Damage to a collapsed Knochenkoloss goes to its skull. True when it is now dead for good.
func hit_skull(enemy: Dictionary, damage: float) -> bool:
	enemy.skull_hp = float(enemy.get("skull_hp", 0.0)) - damage
	enemy.hit_flash = float(game.balance.feedback.hit_flash)
	if float(enemy.skull_hp) > 0.0: return false
	enemy.collapsed = 0.0
	_remove_zone(int(enemy.get("skull_zone", -1)))
	return true


func _rise(enemy: Dictionary) -> void:
	var rebuild: Dictionary = set_for(enemy).get("rebuild", {})
	enemy.hp = maxf(1.0, float(enemy.max_hp) * float(rebuild.get("revive_share", 0.3)))
	_remove_zone(int(enemy.get("skull_zone", -1)))
	game.add_fx("rage", Vector2(enemy.pos), 60.0)


func _remove_zone(id: int) -> void:
	for index in range(zones.size() - 1, -1, -1):
		if int(zones[index].id) == id: zones.remove_at(index)


func _enemy(id: int) -> Dictionary:
	for enemy: Dictionary in game.enemies:
		if int(enemy.get("id", -1)) == id and float(enemy.get("hp", 0)) > 0: return enemy
	return {}


## Zones for clients: kind, style, position, radius, state and progress 0..1.
func snapshot() -> Array:
	var result: Array = []
	for zone: Dictionary in zones:
		var entry := {"id": int(zone.id), "k": str(zone.kind), "st": str(zone.style), "x": Vector2(zone.pos).x, "y": Vector2(zone.pos).y, "r": float(zone.radius), "s": str(zone.state),
			"p": clampf(1.0 - float(zone.timer) / maxf(float(zone.length), 0.01), 0.0, 1.0), "L": float(zone.length)}
		if zone.has("to"): entry.merge({"tx": Vector2(zone.to).x, "ty": Vector2(zone.to).y})
		if zone.has("from"): entry.merge({"fx": Vector2(zone.from).x, "fy": Vector2(zone.from).y, "fl": float(zone.get("flight", 1.0))})
		if zone.has("aim"): entry.merge({"a": float(zone.aim), "w": float(zone.angle)})
		if zone.has("dir"): entry.merge({"dx": Vector2(zone.dir).x, "dy": Vector2(zone.dir).y})
		result.append(entry)
	return result
