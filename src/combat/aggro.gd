extends RefCounted
## Aggro: enemies stay put until a living player comes within their notice
## range with a clear line of sight, or hurts them. Then they lock onto that
## player and keep chasing until the player falls; only then do they switch to
## the nearest living player. A newly angered enemy calls idle allies nearby
## onto the same player. Summoned creatures start angry; bosses are always
## angry and always face the nearest hero.
## Pure functions over the host's enemy and player dictionaries, so the rules
## can be tested without a running game.


## The peer id `enemy` hunts this frame, or -1 while it is still unaware.
## `sees` is a Callable(from: Vector2, to: Vector2) -> bool for line of sight;
## `config` is balance.aggro (`range`).
static func pick_target(enemy: Dictionary, players: Dictionary, sees: Callable, config: Dictionary) -> int:
	# Bosses fight the whole party: always angry, always on the nearest hero,
	# so their arena patterns keep reading the closest threat.
	if bool(enemy.get("boss", false)):
		return _nearest(enemy.pos, players, INF)
	var locked: int = int(enemy.get("aggro_target", -1))
	if locked >= 0 and players.has(locked) and int(players[locked].hp) > 0:
		return locked
	if bool(enemy.get("aggro", false)):
		# The locked player fell or left: stay angry, hunt the nearest one.
		var nearest: int = _nearest(enemy.pos, players, INF)
		enemy.aggro_target = nearest
		return nearest
	var reach: float = float(enemy.get("aggro_range", config.range))
	var candidate: int = _nearest(enemy.pos, players, reach)
	if candidate >= 0 and sees.call(enemy.pos, players[candidate].pos):
		lock(enemy, candidate)
		return candidate
	return -1


## Locks `enemy` onto `target` (a peer id). An enemy hurt by a player locks
## onto that player even when it was hunting someone else.
static func lock(enemy: Dictionary, target: int) -> void:
	enemy.aggro = true
	enemy.aggro_target = target
	enemy.aggro_fresh = true


## Idle enemies within `config.call_range` of a freshly angered `enemy` join
## the hunt on the same player. Returns how many were called.
static func alert_pack(enemy: Dictionary, enemies: Array, config: Dictionary) -> int:
	if not bool(enemy.get("aggro_fresh", false)):
		return 0
	enemy.aggro_fresh = false
	var called := 0
	for other: Dictionary in enemies:
		if other == enemy or bool(other.get("aggro", false)) or int(other.get("hp", 0)) <= 0:
			continue
		if Vector2(other.pos).distance_to(enemy.pos) <= float(config.call_range):
			other.aggro = true
			other.aggro_target = int(enemy.aggro_target)
			called += 1
	return called


## Whether `enemy` may start an attack on a target `distance` away: its own
## attack `range` when it has one, otherwise `config.attack_range`. Bosses
## fight their whole arena.
static func in_attack_range(enemy: Dictionary, attack: Dictionary, distance: float, config: Dictionary) -> bool:
	if bool(enemy.get("boss", false)):
		return true
	return distance <= float(attack.get("range", config.attack_range))


static func _nearest(from: Vector2, players: Dictionary, reach: float) -> int:
	var best := -1
	var best_distance := reach * reach if reach < INF else INF
	for id: Variant in players:
		if int(players[id].hp) <= 0:
			continue
		var candidate: float = from.distance_squared_to(players[id].pos)
		if candidate <= best_distance:
			best_distance = candidate
			best = int(id)
	return best
