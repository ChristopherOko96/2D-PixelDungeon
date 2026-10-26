extends RefCounted
## Central rules for player stats, EXP and levels. Pure static functions: the host
## changes a player dictionary through them and the snapshot sends what they
## compute, so gameplay and HUD always read the same numbers. A level-up goes
## through `add_exp`, which reports how many levels were gained; the host applies
## the per-level reward (today a small heal) and later upgrade choices plug in
## at the same place.


## EXP needed to go from `level` to `level + 1`: base × level^exponent, rounded.
static func exp_to_next(level: int, config: Dictionary) -> int:
	return maxi(1, roundi(float(config.get("base", 100)) * pow(float(maxi(1, level)), float(config.get("exponent", 1.5)))))


## Adds EXP to a player ({level, exp}) and processes every level-up it causes.
## Surplus carries into the next level; one big pickup can gain several levels.
## Returns the number of levels gained.
static func add_exp(player: Dictionary, amount: int, config: Dictionary) -> int:
	if amount <= 0:
		return 0
	player.level = maxi(1, int(player.get("level", 1)))
	player.exp = int(player.get("exp", 0)) + amount
	var gained := 0
	# The cap only guards against a broken config (base 0); real values never hit it.
	while int(player.exp) >= exp_to_next(int(player.level), config) and gained < 100:
		player.exp = int(player.exp) - exp_to_next(int(player.level), config)
		player.level = int(player.level) + 1
		gained += 1
	return gained


## Splits a kill's EXP into orb values that add up to `value` exactly. Bigger
## kills drop more orbs (about 1.2 × √value, at most `max_orbs`).
static func split_exp(value: int, max_orbs: int) -> Array[int]:
	var orbs: Array[int] = []
	if value <= 0:
		return orbs
	var count: int = clampi(roundi(sqrt(float(value)) * 1.2), 1, mini(maxi(1, max_orbs), value))
	var base: int = floori(float(value) / float(count))
	for i in range(count):
		orbs.append(base + (1 if i < value - base * count else 0))
	return orbs


## The stats the HUD shows, computed from the player's real values in the
## Isaac convention: tears = shots per second, speed and shot speed relative to
## the starting values, range = shot reach in hundreds of pixels.
static func display_stats(player: Dictionary, balance: Dictionary) -> Dictionary:
	var shot_speed: float = float(player.get("shot_speed", balance.bullet.speed))
	return {
		"damage": float(player.get("damage", balance.player.damage)),
		"tears": 1.0 / maxf(float(player.get("shot_interval", balance.player.shot_interval)), 0.01),
		"speed": float(player.get("speed", balance.player.speed)) / float(balance.player.speed),
		# Melee weapons show their reach; projectiles how far a shot flies.
		"range": float(player.get("reach", 0.0)) / 100.0 if player.get("melee", false) else shot_speed * float(player.get("range", balance.bullet.lifetime)) / 100.0,
		"shot_speed": shot_speed / float(balance.bullet.speed),
		"luck": float(player.get("luck", 0.0)),
		"level": int(player.get("level", 1)),
	}
