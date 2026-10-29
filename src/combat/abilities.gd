extends RefCounted
## Host-side attacks beyond the demon boss: the stone golem's moves and the
## abilities of the deeper floors' mobs (imp dash, skeleton fan, necromancer
## summon), plus timed floor hazards (quake eruptions, thorns, the thrown
## boulder, the boomerang axe). Every move runs through the game's shared
## attack phases (windup → active → recovery); this module only supplies what
## each pattern does in them. Hazards warn before they hurt, so all of them can
## be dodged. Clients draw them from `snapshot()`.

const Dungeon = preload("res://src/dungeon/dungeon_generator.gd")

## The host: the game, or an object with the same members (src/combat/sheet_monsters.gd).
var game: Object
## Active hazards: {id, kind, pos, state ("warn"/"fly"/"burst"/"out"/"back"),
## timer, length, radius, damage, hit (peer ids already hurt), ...}.
var hazards: Array = []
var _next_id := 0
var _rng := RandomNumberGenerator.new()


func _init(owner: Object) -> void:
	game = owner
	_rng.seed = 11


func clear() -> void:
	hazards.clear()


## Windup start: first aim, so the telegraph points somewhere at once.
func begin(enemy: Dictionary, attack: Dictionary, target_pos: Vector2) -> void:
	var toward: Vector2 = target_pos - enemy.pos
	enemy.aim_dir = toward.normalized() if toward.length_squared() > 1.0 else Vector2(enemy.get("face", -1.0), 0.0)
	enemy.aim_point = target_pos
	if str(attack.pattern) == "spiral":
		enemy.spiral = toward.angle()


## Windup: dash, cleave and axe track the target until `lock` seconds remain.
func windup(enemy: Dictionary, attack: Dictionary, target_pos: Vector2, _delta: float) -> void:
	if enemy.attack_time > float(attack.get("lock", 0.0)) and enemy.pos.distance_squared_to(target_pos) > 1.0:
		enemy.aim_dir = (target_pos - enemy.pos).normalized()
		enemy.aim_point = target_pos


## First frame of the active phase.
func fire(enemy: Dictionary, attack: Dictionary, target: int) -> void:
	var players: Dictionary = game.players
	match str(attack.pattern):
		"cleave":
			_cleave_hit(enemy, attack)
			var base: float = Vector2(enemy.aim_dir).angle()
			var count := int(attack.count)
			for i in range(count):
				var angle: float = base - float(attack.spread) * 0.5 + float(attack.spread) * float(i) / float(maxi(count - 1, 1))
				var aim := Vector2.RIGHT.rotated(angle)
				game._add_bullet(enemy.pos + aim * enemy.radius, aim * float(attack.bullet_speed), 0, float(attack.damage) * 0.5, -1.0, str(attack.get("projectile", "slash")))
		"barrage", "stream":
			enemy.thrown = 0
			enemy.throw_timer = 0.0
		"quake":
			var base: float = Vector2(enemy.aim_dir).angle()
			var lines := int(attack.lines)
			for line in range(lines):
				var angle: float = base + (float(line) - float(lines - 1) * 0.5) * float(attack.angle)
				for step in range(int(attack.steps)):
					var point: Vector2 = enemy.pos + Vector2.RIGHT.rotated(angle) * float(attack.spacing) * float(step + 1)
					if Dungeon.segment_blocked(enemy.pos, point, 0.0, game.current_layout): break
					_add_hazard("quake", point, float(attack.warn) + float(attack.step_delay) * step, float(attack.radius), int(attack.damage))
		"axe":
			var reach: float = minf(enemy.pos.distance_to(enemy.aim_point), float(attack.reach))
			var goal: Vector2 = enemy.pos + Vector2(enemy.aim_dir) * reach
			goal = Dungeon.move_actor(enemy.pos, goal - enemy.pos, float(attack.radius), game.current_layout)
			var axe := _add_hazard("axe", enemy.pos, 0.0, float(attack.radius), int(attack.damage))
			axe.state = "out"
			axe.from = Vector2(enemy.pos)
			axe.goal = goal
			axe.owner_id = int(enemy.id)
			axe.length = float(attack.active) * 0.5
			axe.timer = axe.length
			enemy.axe_out = true
		"boulder":
			var speed: float = enemy.pos.distance_to(players[target].pos) / maxf(float(attack.flight), 0.01)
			var goal: Vector2 = game._lead_point(enemy.pos, target, speed, float(attack.lead))
			goal = Dungeon.move_actor(enemy.pos, goal - enemy.pos, 8.0, game.current_layout)
			var rock := _add_hazard(str(attack.get("hazard", "boulder")), enemy.pos, float(attack.flight), float(attack.radius), int(attack.damage))
			rock.state = "fly"
			rock.from = Vector2(enemy.pos) + Vector2(0, -float(attack.get("lift", 40.0)))
			rock.goal = goal
			rock.count = int(attack.count)
			rock.speed = float(attack.bullet_speed)
			rock.blast = str(attack.get("blast", "blast"))
			rock.shard = str(attack.get("shard", "bolt"))
		"spiral":
			enemy.spiral_timer = 0.0
		"thorns":
			enemy.wave = 0
			enemy.wave_timer = 0.0
		"dash":
			enemy.dashing = true
			enemy.dash_damage = int(attack.damage)
		"orb":
			# A slow orb that bends toward the nearest player: outrun it or cut across.
			var aim: Vector2 = (players[target].pos - enemy.pos).normalized()
			game._add_bullet(enemy.pos + aim * enemy.radius, aim * float(attack.bullet_speed), 0, float(attack.damage), float(attack.life), "void")
			game.bullets.back().homing = float(attack.homing)
		"pillar":
			_add_hazard(str(attack.hazard), players[target].pos, float(attack.warn), float(attack.radius), int(attack.damage))
		"pound":
			# Ground pound: hurts close by and throws a ring of debris.
			_hurt_area({"radius": float(attack.radius), "damage": int(attack.damage), "hit": {}}, enemy.pos)
			enemy.impacts = int(enemy.get("impacts", 0)) + 1
			var count := int(attack.count)
			for i in range(count):
				var aim := Vector2.RIGHT.rotated(TAU * i / count + _rng.randf() * 0.4)
				game._add_bullet(enemy.pos + aim * enemy.radius, aim * float(attack.bullet_speed), 0, 1.0, float(attack.get("life", -1.0)), str(attack.get("projectile", "rock")))
		"voidcast":
			game._fire_fan(enemy, attack, target, false)
			_add_hazard("void", players[target].pos, float(attack.warn), float(attack.radius), int(attack.damage))
		"torch":
			var aim: Vector2 = (game._lead_point(enemy.pos, target, float(attack.bullet_speed), float(attack.lead)) - enemy.pos).normalized()
			game._add_bullet(enemy.pos + aim * enemy.radius, aim * float(attack.bullet_speed), 0, float(attack.damage), -1.0, "fireball")
			var ring := int(attack.ring)
			for i in range(ring):
				var spoke := Vector2.RIGHT.rotated(TAU * i / ring + _rng.randf() * 0.5)
				game._add_bullet(enemy.pos + spoke * enemy.radius, spoke * float(attack.ring_speed), 0, 1.0, -1.0, "flame")
		"eruption":
			# Rings of lava (or spikes) burst outward from the boss, one after another.
			for ring in range(int(attack.rings)):
				var distance: float = float(attack.ring_gap) * float(ring + 1)
				var count := int(attack.per_ring) + ring * 2
				var turn := _rng.randf() * TAU
				for i in range(count):
					var point: Vector2 = enemy.pos + Vector2.RIGHT.rotated(turn + TAU * i / count) * distance
					if Dungeon.segment_blocked(enemy.pos, point, 0.0, game.current_layout): continue
					_add_hazard(str(attack.get("hazard", "lava")), point, float(attack.warn) + float(attack.ring_delay) * ring, float(attack.radius), int(attack.damage))
		"void":
			for id in players:
				if players[id].hp > 0: _add_hazard("void", players[id].pos, float(attack.warn), float(attack.radius), int(attack.damage))
			_summon(enemy, attack)
		"summon":
			_summon(enemy, attack)
		"trap":
			# A bear trap halfway to the player; it waits, armed, until stepped on.
			var mine := 0
			for hazard in hazards:
				if hazard.kind == "trap" and int(hazard.get("owner_id", -1)) == int(enemy.id): mine += 1
			if mine < int(attack.max_traps):
				var spot: Vector2 = Dungeon.move_actor(enemy.pos, (players[target].pos - enemy.pos) * 0.6, 10.0, game.current_layout)
				var trap := _add_hazard("trap", spot, float(attack.life), float(attack.radius), int(attack.damage))
				trap.state = "armed"
				trap.owner_id = int(enemy.id)
				trap.root = float(attack.root)
		"heal":
			# Mends hurt allies nearby; with nobody hurt it throws a seeking orb.
			var healed := false
			for other in game.enemies:
				if other == enemy or other.hp <= 0 or other.hp >= other.max_hp: continue
				if other.pos.distance_to(enemy.pos) < float(attack.reach):
					other.hp = mini(int(other.max_hp), int(other.hp) + int(attack.amount))
					other.healed = int(other.get("healed", 0)) + 1
					healed = true
			if not healed:
				var aim: Vector2 = (players[target].pos - enemy.pos).normalized()
				game._add_bullet(enemy.pos + aim * enemy.radius, aim * float(attack.bullet_speed), 0, 1.0, 4.0, "void")
				game.bullets.back().homing = 1.5
		"rally":
			# War cry: nearby allies hurry for a while; reinforcements join.
			for other in game.enemies:
				if other.hp > 0 and other.pos.distance_to(enemy.pos) < float(attack.reach):
					other.haste = float(attack.haste)
			if attack.has("summon"): _summon(enemy, attack)


## Raises up to `count` creatures of `summon`, never more than `max_summons` alive.
func _summon(enemy: Dictionary, attack: Dictionary) -> void:
	var alive := 0
	for other in game.enemies:
		if other.get("summoner", -1) == enemy.id and other.hp > 0: alive += 1
	for i in range(mini(int(attack.count), int(attack.max_summons) - alive)):
		var offset: Vector2 = Vector2.RIGHT.rotated(TAU * float(i) / float(attack.count) + _rng.randf() * 0.5) * (float(enemy.radius) + 18.0)
		var spot: Vector2 = Dungeon.move_actor(enemy.pos, offset, 10.0, game.current_layout)
		var minion: Dictionary = game._spawn_enemy(str(attack.summon), spot, 0)
		minion.summoner = enemy.id
		minion.shot_timer = 0.8
		# Summoned creatures arrive angry, hunting their summoner's target.
		minion.aggro = true
		minion.aggro_target = int(enemy.get("aggro_target", -1))


func active(enemy: Dictionary, attack: Dictionary, target: int, delta: float) -> void:
	var players: Dictionary = game.players
	match str(attack.pattern):
		"cleave":
			# The swing carries the golem a step forward.
			enemy.pos = Dungeon.move_actor(enemy.pos, Vector2(enemy.aim_dir) * float(attack.lunge) * delta, enemy.radius, game.current_layout)
		"barrage", "stream":
			enemy.throw_timer = float(enemy.throw_timer) - delta
			if enemy.throw_timer <= 0.0 and int(enemy.thrown) < int(attack.count):
				enemy.throw_timer = float(attack.active) / float(attack.count)
				enemy.thrown = int(enemy.thrown) + 1
				var speed := float(attack.bullet_speed)
				var aim: Vector2 = (game._lead_point(enemy.pos, target, speed, float(attack.lead)) - enemy.pos).normalized().rotated(_rng.randf_range(-1.0, 1.0) * float(attack.jitter))
				game._add_bullet(enemy.pos + aim * enemy.radius + Vector2(0, -float(attack.get("lift", 20.0))), aim * speed, 0, float(attack.damage), -1.0, str(attack.get("projectile", "rock")))
				enemy.attacks = int(enemy.get("attacks", 0)) + 1
		"spiral":
			# Rotating arms of toxic bolts; the gaps between arms are the way through.
			enemy.spiral = float(enemy.spiral) + float(attack.turn) * delta
			enemy.spiral_timer = float(enemy.spiral_timer) - delta
			if enemy.spiral_timer <= 0.0:
				enemy.spiral_timer = float(attack.rate)
				var arms := int(attack.arms)
				for arm in range(arms):
					var aim := Vector2.RIGHT.rotated(float(enemy.spiral) + TAU * arm / arms)
					game._add_bullet(enemy.pos + aim * enemy.radius + Vector2(0, -18), aim * float(attack.bullet_speed), 0, float(attack.damage), -1.0, str(attack.get("projectile", "bolt")))
		"thorns":
			enemy.wave_timer = float(enemy.wave_timer) - delta
			if enemy.wave_timer <= 0.0 and int(enemy.wave) < int(attack.waves):
				enemy.wave_timer = float(attack.wave_every)
				enemy.wave = int(enemy.wave) + 1
				enemy.attacks = int(enemy.get("attacks", 0)) + 1
				# Thorns rise under every living player and at random spots; the
				# warning is long enough to step out at walking speed.
				var bounds: Rect2 = (game.arena_rect(enemy) if game.has_method("arena_rect") else Rect2(game.current_layout.play_bounds[0], game.current_layout.play_bounds[1], game.current_layout.play_bounds[2], game.current_layout.play_bounds[3])).grow(-30.0)
				for id in players:
					if players[id].hp > 0: _add_hazard(str(attack.get("hazard", "thorns")), players[id].pos, float(attack.warn), float(attack.radius), int(attack.damage))
				for i in range(int(attack.random)):
					var spot := Vector2(_rng.randf_range(bounds.position.x, bounds.end.x), _rng.randf_range(bounds.position.y, bounds.end.y))
					_add_hazard(str(attack.get("hazard", "thorns")), spot, float(attack.warn), float(attack.radius), int(attack.damage))
		"dash":
			var before: Vector2 = enemy.pos
			var step: Vector2 = Vector2(enemy.aim_dir) * float(attack.speed) * delta
			enemy.pos = Dungeon.move_actor(enemy.pos, step, enemy.radius, game.current_layout)
			enemy.moving = true
			if enemy.pos.distance_to(before) < step.length() * 0.5: enemy.attack_time = 0.0


func finish(enemy: Dictionary, attack: Dictionary, _target: int) -> void:
	match str(attack.pattern):
		"dash":
			enemy.dashing = false
			# The crab's lunge ends in a line of spikes ahead of it.
			for i in range(int(attack.get("spikes", 0))):
				var point: Vector2 = enemy.pos + Vector2(enemy.aim_dir) * float(attack.spacing) * float(i + 1)
				if Dungeon.segment_blocked(enemy.pos, point, 0.0, game.current_layout): break
				_add_hazard("spike", point, float(attack.warn) + 0.08 * i, float(attack.radius), 1)


## Advances every hazard: warnings count down and burst, the boulder flies and
## explodes, the axe flies out and back to its owner.
func update(delta: float) -> void:
	for i in range(hazards.size() - 1, -1, -1):
		var hazard: Dictionary = hazards[i]
		hazard.timer = float(hazard.timer) - delta
		match str(hazard.state):
			"armed":
				# A set trap snaps shut on the first player who steps in.
				for id in game.players:
					var player: Dictionary = game.players[id]
					if player.hp > 0 and player.pos.distance_to(hazard.pos) < float(hazard.radius) + 8.0:
						hazard.state = "burst"
						hazard.timer = 0.5
						hazard.length = 0.5
						_hurt_area(hazard, hazard.pos)
						player.rooted = float(hazard.get("root", 0.8))
						break
				if hazard.state == "armed" and hazard.timer <= 0.0: hazards.remove_at(i)
			"warn":
				if hazard.timer <= 0.0:
					hazard.state = "burst"
					hazard.timer = 0.3
					hazard.length = 0.3
					_hurt_area(hazard, hazard.pos)
			"burst":
				if hazard.timer <= 0.0: hazards.remove_at(i)
			"fly":
				hazard.pos = Vector2(hazard.from).lerp(hazard.goal, clampf(1.0 - hazard.timer / maxf(float(hazard.length), 0.01), 0.0, 1.0))
				if hazard.timer <= 0.0:
					hazard.pos = hazard.goal
					hazard.state = "burst"
					hazard.kind = str(hazard.get("blast", "blast"))
					hazard.timer = 0.4
					hazard.length = 0.4
					_hurt_area(hazard, hazard.pos)
					for k in range(int(hazard.count)):
						var aim := Vector2.RIGHT.rotated(TAU * k / int(hazard.count) + _rng.randf() * 0.3)
						game._add_bullet(hazard.pos + aim * 12.0, aim * float(hazard.speed), 0, 1.0, -1.0, str(hazard.get("shard", "bolt")))
			"out", "back":
				var owner := _enemy(int(hazard.owner_id))
				if hazard.state == "out":
					hazard.pos = Vector2(hazard.from).lerp(hazard.goal, ease(clampf(1.0 - hazard.timer / maxf(float(hazard.length), 0.01), 0.0, 1.0), 0.5))
					if hazard.timer <= 0.0:
						hazard.state = "back"
						hazard.timer = hazard.length
						hazard.from = Vector2(hazard.pos)
						hazard.hit = {}
				else:
					var home: Vector2 = owner.pos if not owner.is_empty() else hazard.from
					hazard.pos = Vector2(hazard.from).lerp(home, ease(clampf(1.0 - hazard.timer / maxf(float(hazard.length), 0.01), 0.0, 1.0), 2.0))
					if hazard.timer <= 0.0:
						if not owner.is_empty(): owner.axe_out = false
						hazards.remove_at(i)
						continue
				_hurt_area(hazard, hazard.pos)


## Snapshot entries for clients: kind, position, state and progress 0..1.
func snapshot() -> Array:
	var result: Array = []
	for hazard in hazards:
		var entry := {"id": hazard.id, "k": hazard.kind, "x": hazard.pos.x, "y": hazard.pos.y, "s": hazard.state, "r": hazard.radius,
			"p": clampf(1.0 - float(hazard.timer) / maxf(float(hazard.length), 0.01), 0.0, 1.0)}
		if hazard.has("goal"):
			entry.gx = hazard.goal.x
			entry.gy = hazard.goal.y
		result.append(entry)
	return result


## A creature's last act, e.g. the ember-blob's fire patch: a short warning,
## then a burst where it died.
func death_burst(enemy: Dictionary, config: Dictionary) -> void:
	_add_hazard(str(config.kind), enemy.pos, float(config.warn), float(config.radius), int(config.damage))


## A purely visual burst (e.g. a magic shot exploding); hurts nobody.
func effect(kind: String, pos: Vector2, radius: float) -> void:
	var burst := _add_hazard(kind, pos, 0.0, radius, 0)
	burst.state = "burst"
	burst.timer = 0.3
	burst.length = 0.3


func _add_hazard(kind: String, pos: Vector2, warn: float, radius: float, damage: int) -> Dictionary:
	var hazard := {"id": _next_id, "kind": kind, "pos": pos, "state": "warn", "timer": warn, "length": maxf(warn, 0.01), "radius": radius, "damage": damage, "hit": {}}
	_next_id += 1
	hazards.append(hazard)
	return hazard


func _hurt_area(hazard: Dictionary, point: Vector2) -> void:
	for id in game.players:
		var player: Dictionary = game.players[id]
		if player.hp <= 0 or hazard.hit.has(id) or int(hazard.damage) <= 0: continue
		if player.pos.distance_to(point) < float(hazard.radius) + 12.0:
			hazard.hit[id] = true
			game._damage_player(id, int(hazard.damage), point)


## The axe swing hits everyone in a cone in front of the golem.
func _cleave_hit(enemy: Dictionary, attack: Dictionary) -> void:
	var facing: Vector2 = enemy.aim_dir
	for id in game.players:
		var player: Dictionary = game.players[id]
		if player.hp <= 0: continue
		var offset: Vector2 = player.pos - enemy.pos
		if offset.length() < float(attack.reach) + 12.0 and absf(facing.angle_to(offset)) < float(attack.arc) * 0.5:
			game._damage_player(id, int(attack.damage), enemy.pos)


func _enemy(id: int) -> Dictionary:
	for enemy in game.enemies:
		if int(enemy.get("id", -1)) == id and enemy.hp > 0: return enemy
	return {}
