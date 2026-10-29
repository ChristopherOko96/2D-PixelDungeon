extends RefCounted
## Sheet monsters of the themed endless floors (assets/data/themed_monsters.json,
## ported from codex/0x72-dungeon): 0x72 mobs, orcs, mini-bosses and floor
## bosses that are drawn from sprite sheets instead of part rigs. Each kind has
## one attack (mobs) or a move sequence with an ultimate (bosses); every move
## runs through windup -> active -> recovery, and src/combat/abilities.gd
## supplies what each pattern does. Kinds that also exist as crypt rigs
## (balance.enemy_roster) stay with the crypt AI.
## Host only; the game owns the enemy dictionaries and passes them in. This
## object also stands in for the game towards the abilities module (players,
## enemies, bullets and the helpers it calls), so that module stays unchanged.

const Dungeon = preload("res://src/dungeon/dungeon_generator.gd")
const Aggro = preload("res://src/combat/aggro.gd")
const Abilities = preload("res://src/combat/abilities.gd")
const DATA_PATH := "res://assets/data/themed_monsters.json"
## Half size of the area a boss's room-wide moves (thorns waves) cover around it.
const ARENA_HALF := Vector2(360, 240)

var game: Node
var data: Dictionary = {}
var abilities: Abilities

## The abilities module reads these as if they were the game's own.
var players: Dictionary:
	get: return game.players
var enemies: Array:
	get: return game.enemies
var bullets: Array:
	get: return game.bullets
var current_layout: Dictionary:
	get: return game.current_layout


## Reads the monster data from `path`; an empty Dictionary when it is missing.
static func load_data(path: String = DATA_PATH) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


## Injects the host game (no singleton) and loads the data once.
func bind(owner: Node, monster_data: Dictionary = {}) -> void:
	game = owner
	if not monster_data.is_empty(): data = monster_data
	elif data.is_empty(): data = load_data()
	if abilities == null: abilities = Abilities.new(self)


## Clears the floor hazards (new room, new floor, new run).
func reset() -> void:
	if abilities != null: abilities.clear()


## Whether `kind` is a sheet monster of this module.
func has_kind(kind: String) -> bool:
	return data.get("base", {}).has(kind) or data.get("mobs", {}).has(kind) or is_boss(kind)


## Floor bosses and mini-bosses: always angry once awake, a move sequence.
func is_boss(kind: String) -> bool:
	return data.get("bosses", {}).has(kind) or data.get("minibosses", {}).has(kind)


## Stats of a sheet kind (hp, hp_per_extra_player, speed, radius, ...).
func definition(kind: String) -> Dictionary:
	for section: String in ["minibosses", "bosses", "mobs", "base"]:
		if data.get(section, {}).has(kind): return data[section][kind]
	return {}


## The attack an enemy uses right now: a boss's current move, else its kind's attack.
func attack_for(enemy: Dictionary) -> Dictionary:
	var kind := str(enemy.get("kind", ""))
	if is_boss(kind): return definition(kind).get("moves", {}).get(str(enemy.get("move", "")), {})
	return data.get("attacks", {}).get(kind, {})


## Theme of endless floor `number`: a seeded pick among `themes` that never
## repeats the previous floor's theme. Pure, so every peer gets the same list.
static func theme_for(themes: Array, seed_value: int, number: int) -> String:
	if themes.is_empty(): return ""
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("themes:%d" % seed_value)
	var previous := ""
	var picked := ""
	for floor_number in range(1, maxi(1, number) + 1):
		var choices: Array = themes.filter(func(name: String) -> bool: return name != previous)
		if choices.is_empty(): choices = themes
		picked = str(choices[rng.randi_range(0, choices.size() - 1)])
		previous = picked
	return picked


## What endless floor `number` looks like and who lives there: {"name",
## "look" (balance colours, banner, detail), "roster" (melee, ranged, boss,
## miniboss)}. Empty without data.
func floor_theme(seed_value: int, number: int) -> Dictionary:
	var rosters: Dictionary = {}
	for entry: Dictionary in data.get("floors", []): rosters[str(entry.get("theme", ""))] = entry
	var name := theme_for(rosters.keys(), seed_value, number)
	if name.is_empty(): return {}
	var look: Dictionary = data.get("themes", {}).get(name, {}).duplicate()
	look.name = name
	return {"name": name, "look": look, "roster": rosters[name].duplicate(true)}


## The kind for slot `index` of a group of `count` on a themed floor: the first
## two are melee, then every third is ranged.
static func group_kind(roster: Dictionary, index: int, rng: RandomNumberGenerator) -> String:
	var ranged: bool = index >= 2 and index % 3 == 2
	var pool: Array = roster.get("ranged" if ranged else "melee", [])
	if pool.is_empty(): pool = roster.get("melee", [])
	return str(pool[rng.randi_range(0, pool.size() - 1)])


## Fills the sheet fields of a freshly created enemy of `kind`; the game has
## already set position, ids and the common fields.
func setup(enemy: Dictionary) -> void:
	var kind := str(enemy.kind)
	enemy.sheet = true
	enemy.boss = data.get("bosses", {}).has(kind)
	if data.get("minibosses", {}).has(kind): enemy.miniboss = true
	enemy.aggro = false
	enemy.move = ""
	enemy.move_index = 0
	enemy.attack_length = 1.0
	enemy.shot_timer = 0.6 + 0.35 * float(int(enemy.id) % 4)


## One host tick of a sheet enemy that already has a living `target` (peer id).
## Returns true once handled, so the caller skips the crypt AI.
func step(enemy: Dictionary, target: int, delta: float) -> bool:
	if not bool(enemy.get("sheet", false)) or not players.has(target): return false
	var kind := str(enemy.kind)
	var stats := definition(kind)
	var target_pos: Vector2 = players[target].pos
	var big: bool = is_boss(kind)
	enemy.nav_timer = float(enemy.get("nav_timer", 0.0)) - delta
	if enemy.nav_timer <= 0.0:
		enemy.nav_path = Dungeon.find_path(enemy.pos, target_pos, enemy.radius, current_layout)
		enemy.nav_timer = 0.3
	var path: PackedVector2Array = enemy.get("nav_path", PackedVector2Array())
	while not path.is_empty() and enemy.pos.distance_to(path[0]) < 6.0:
		path.remove_at(0)
	enemy.nav_path = path
	var direction: Vector2 = (path[0] - enemy.pos).normalized() if not path.is_empty() else Vector2.ZERO
	var in_sight: bool = not Dungeon.segment_blocked(enemy.pos, target_pos, float(game.balance.bullet.radius), current_layout)
	if stats.has("keep_min") and in_sight:
		# Ranged kinds hold a firing range: back off when crowded, close in when far.
		var gap: float = enemy.pos.distance_to(target_pos)
		var away: Vector2 = (enemy.pos - target_pos).normalized()
		direction = away if gap < float(stats.keep_min) else -away if gap > float(stats.keep_max) else Vector2.ZERO
	# Attackers plant their feet while winding up and striking; bosses also
	# while recovering, which is the heroes' opening.
	var attack_phase := str(enemy.get("attack", ""))
	if attack_phase in ["windup", "active"] or (big and not attack_phase.is_empty()): direction = Vector2.ZERO
	enemy.haste = maxf(0.0, float(enemy.get("haste", 0.0)) - delta)
	if bool(stats.get("rage", false)) and enemy.hp * 2 < enemy.max_hp: enemy.raging = true
	var pace: float = (1.4 if enemy.haste > 0.0 else 1.0) * (1.5 if bool(enemy.get("raging", false)) else 1.0)
	var before: Vector2 = enemy.pos
	if direction != Vector2.ZERO:
		enemy.pos = Dungeon.move_actor(enemy.pos, direction * float(enemy.speed) * pace * delta, enemy.radius, current_layout)
		enemy.facing_dir = direction
	enemy.moving = enemy.pos.distance_squared_to(before) > 0.001
	_turn_toward(enemy, target_pos, delta)
	# Contact: a dashing creature hits hard, everyone else lightly.
	var contact: int = int(attack_for(enemy).get("damage", 1)) if bool(enemy.get("dashing", false)) else int(data.get("base", {}).get("chaser", {}).get("damage", 1))
	if not bool(enemy.get("airborne", false)) and enemy.pos.distance_to(target_pos) < float(enemy.radius) + float(game.balance.player.radius) and not Dungeon.segment_blocked(enemy.pos, target_pos, 0.0, current_layout):
		game._damage_player(target, contact, (target_pos - enemy.pos).normalized())
	if big or data.get("attacks", {}).has(kind):
		_update_attack(enemy, delta, target, in_sight)
	return true


## Floor hazards and homing shots; call once per host tick.
func update(delta: float) -> void:
	if abilities == null: return
	abilities.update(delta)
	for bullet: Dictionary in bullets:
		var turn: float = float(bullet.get("homing", 0.0))
		if turn <= 0.0 or int(bullet.owner) != 0: continue
		var hunted := _nearest_player(bullet.pos)
		if hunted < 0: continue
		var speed: float = Vector2(bullet.velocity).length()
		var angle: float = rotate_toward(Vector2(bullet.velocity).angle(), (players[hunted].pos - bullet.pos).angle(), turn * delta)
		bullet.velocity = Vector2.RIGHT.rotated(angle) * speed


## Hazards for the snapshot (kind, position, state, progress).
func snapshot() -> Array:
	return abilities.snapshot() if abilities != null else []


## Snapshot extras of a sheet enemy: aim, pattern, rage and haste for the art.
func snapshot_entry(enemy: Dictionary, entry: Dictionary) -> void:
	var attack := str(enemy.get("attack", ""))
	entry.sheet = true
	entry.move = str(enemy.get("move", ""))
	entry.pattern = str(attack_for(enemy).get("pattern", "")) if not attack.is_empty() else ""
	entry.hasted = float(enemy.get("haste", 0.0)) > 0.0
	entry.raging = bool(enemy.get("raging", false))
	entry.dash = bool(enemy.get("dashing", false))
	entry.healed = int(enemy.get("healed", 0))
	entry.hit = float(enemy.get("hit_flash", 0.0)) > 0.0
	if enemy.has("aim_dir"):
		entry.aim_x = Vector2(enemy.aim_dir).x
		entry.aim_y = Vector2(enemy.aim_dir).y


## Phases shared by every sheet attack: idle (cooldown) -> windup (aims and
## telegraphs) -> active (the pattern fires on its first frame) -> recovery.
func _update_attack(enemy: Dictionary, delta: float, target: int, in_sight: bool) -> void:
	var target_pos: Vector2 = players[target].pos
	var big: bool = is_boss(str(enemy.kind))
	enemy.attack_time = float(enemy.get("attack_time", 0.0)) - delta
	match str(enemy.get("attack", "")):
		"":
			enemy.shot_timer = float(enemy.get("shot_timer", 1.0)) - delta * (1.5 if float(enemy.get("haste", 0.0)) > 0.0 else 1.0) * (1.6 if bool(enemy.get("raging", false)) else 1.0)
			var range_ok: bool = Aggro.in_attack_range(enemy, attack_for(enemy), enemy.pos.distance_to(target_pos), game.balance.aggro)
			if enemy.shot_timer <= 0.0 and (in_sight or big) and range_ok and not bool(enemy.get("axe_out", false)):
				if big: enemy.move = _next_boss_move(enemy)
				var attack := attack_for(enemy)
				if attack.is_empty(): return
				_set_phase(enemy, "windup", float(attack.windup))
				abilities.begin(enemy, attack, target_pos)
		"windup":
			var attack := attack_for(enemy)
			abilities.windup(enemy, attack, target_pos, delta)
			if enemy.attack_time <= 0.0:
				_fire_pattern(enemy, attack, target)
				_set_phase(enemy, "active", float(attack.active))
		"active":
			var attack := attack_for(enemy)
			abilities.active(enemy, attack, target, delta)
			if enemy.attack_time <= 0.0:
				abilities.finish(enemy, attack, target)
				_set_phase(enemy, "recovery", float(attack.recovery))
		"recovery":
			if enemy.attack_time <= 0.0:
				var attack := attack_for(enemy)
				enemy.attack = ""
				enemy.shot_timer = float(attack.interval) if attack.has("interval") else float(definition(str(enemy.kind)).get("move_pause", 1.0))


func _set_phase(enemy: Dictionary, phase: String, length: float) -> void:
	enemy.attack = phase
	enemy.attack_time = length
	enemy.attack_length = maxf(length, 0.001)


## The boss's next move: its authored sequence, interrupted by the ultimate
## once below `ultimate.hp_ratio` health and again every `ultimate.every` moves.
func _next_boss_move(enemy: Dictionary) -> String:
	var config := definition(str(enemy.kind))
	var ultimate: Dictionary = config.get("ultimate", {})
	var since := int(enemy.get("since_ultimate", 0))
	if not ultimate.is_empty() and float(enemy.hp) <= float(enemy.max_hp) * float(ultimate.hp_ratio) and (not bool(enemy.get("ultimate_used", false)) or since >= int(ultimate.every)):
		enemy.ultimate_used = true
		enemy.since_ultimate = 0
		return str(ultimate.move)
	enemy.since_ultimate = since + 1
	var sequence: Array = config.get("sequence", [])
	if sequence.is_empty(): return ""
	var index := int(enemy.get("move_index", 0))
	enemy.move_index = index + 1
	return str(sequence[index % sequence.size()])


func _fire_pattern(enemy: Dictionary, attack: Dictionary, target: int) -> void:
	var speed := float(attack.get("bullet_speed", 0.0))
	match str(attack.pattern):
		"aimed":
			var aim_at: Vector2 = (_lead_point(enemy.pos, target, speed, float(attack.get("lead", 0.0))) - enemy.pos).normalized()
			_add_bullet(enemy.pos + aim_at * (enemy.radius + 4.0), aim_at * speed, 0, float(attack.damage), -1.0, str(attack.get("projectile", "")))
		"fan":
			_fire_fan(enemy, attack, target, false)
		"ring":
			# Each volley turns a little, so the gaps move between attacks.
			enemy.volley = int(enemy.get("volley", 0)) + 1
			_fire_ring(enemy, int(attack.count), speed, float(attack.damage), enemy.volley * 0.35)
		_:
			abilities.fire(enemy, attack, target)
	enemy.attacks = int(enemy.get("attacks", 0)) + 1


## Facing flips toward the target, but not while an attack is aimed; bosses
## turn with weight (only when clearly on the other side, every 0.4 s at most).
func _turn_toward(enemy: Dictionary, target_pos: Vector2, delta: float) -> void:
	enemy.turn_cooldown = maxf(0.0, float(enemy.get("turn_cooldown", 0.0)) - delta)
	var attack := str(enemy.get("attack", ""))
	var big: bool = is_boss(str(enemy.kind))
	if attack == "active" or (attack == "windup" and not big) or bool(enemy.get("dashing", false)): return
	var dx: float = target_pos.x - enemy.pos.x
	if absf(dx) > (24.0 if big else 2.0) and signf(dx) != float(enemy.get("face", -1.0)) and enemy.turn_cooldown <= 0.0:
		enemy.face = signf(dx)
		enemy.turn_cooldown = 0.4 if big else 0.12


func _nearest_player(point: Vector2) -> int:
	var best := -1
	var best_distance := INF
	for id: Variant in players:
		if int(players[id].hp) <= 0: continue
		var distance: float = point.distance_squared_to(players[id].pos)
		if distance < best_distance:
			best_distance = distance
			best = int(id)
	return best


# --- Helpers the abilities module calls on its owner (old game signatures) ---

## Where a target will be when a shot of `speed` reaches it, scaled by `lead`.
func _lead_point(origin: Vector2, target: int, speed: float, lead: float) -> Vector2:
	var player: Dictionary = players[target]
	if lead <= 0.0 or speed <= 0.0: return player.pos
	var velocity: Vector2 = player.get("motion", Vector2.ZERO)
	return player.pos + velocity * (origin.distance_to(player.pos) / speed) * lead


## A spread of `count` shots around the lead point; `between` fills the gaps.
func _fire_fan(enemy: Dictionary, attack: Dictionary, target: int, between: bool) -> void:
	var speed := float(attack.bullet_speed)
	var base: float = (_lead_point(enemy.pos, target, speed, float(attack.get("lead", 0.0))) - enemy.pos).angle()
	var count := int(attack.count)
	var spread := float(attack.spread)
	for i in range(count - 1 if between else count):
		var angle: float = base - spread * 0.5 + spread * (float(i) + (0.5 if between else 0.0)) / float(maxi(count - 1, 1))
		var aim := Vector2.RIGHT.rotated(angle)
		_add_bullet(enemy.pos + aim * enemy.radius, aim * speed * (1.12 if between else 1.0), 0, float(attack.damage), -1.0, str(attack.get("projectile", "")))


func _fire_ring(enemy: Dictionary, count: int, speed: float, damage: float, offset: float) -> void:
	for i in range(count):
		var aim := Vector2.RIGHT.rotated(TAU * i / count + offset)
		_add_bullet(enemy.pos + aim * enemy.radius, aim * speed, 0, damage)


## Old signature (life, projectile kind) onto the game's bullets; the kind is
## the bullet's `style`, which the view draws.
func _add_bullet(position: Vector2, velocity: Vector2, owner: int, damage: float, life: float = -1.0, kind: String = "") -> Dictionary:
	var extra := {"style": kind, "sheet_shot": true}
	var bullet: Dictionary = game._add_bullet(position, velocity, owner, maxf(1.0, roundf(damage)), extra)
	if not bullet.is_empty() and life > 0.0: bullet.life = life
	return bullet


## The abilities module passes the hurting point; the game wants a push direction.
func _damage_player(id: int, damage: int, source: Vector2) -> void:
	if not players.has(id): return
	game._damage_player(id, damage, (Vector2(players[id].pos) - source).normalized())


## Summons: a creature of `kind` joins the room right away.
func _spawn_enemy(kind: String, pos: Vector2, _index: int) -> Dictionary:
	var minion: Dictionary = game._create_enemy(kind, pos)
	minion.summoned = true
	enemies.append(minion)
	return minion


## The area a boss's room-wide moves cover: around the boss, inside the floor.
func arena_rect(enemy: Dictionary) -> Rect2:
	var bounds: Array = current_layout.get("play_bounds", [0, 0, 896, 480])
	var floor_rect := Rect2(float(bounds[0]), float(bounds[1]), float(bounds[2]), float(bounds[3]))
	var around := Rect2(Vector2(enemy.pos) - ARENA_HALF, ARENA_HALF * 2.0)
	var inside := floor_rect.intersection(around)
	return inside if inside.has_area() else floor_rect
