extends RefCounted
## Soul shard drops from dungeon bosses (assets/data/talents.json
## "soul_shards" and "difficulties"). Only a real floor boss can drop one:
## never ordinary enemies, elites, mini-bosses or chests. One roll per boss
## completion and player, on the host; at most one shard per completion.
##   - chance by difficulty (Normal 8 %, Schwer 15 %, Albtraum 25 %)
##   - pity: after `pity_after - 1` eligible kills without a shard the next is guaranteed
##   - first Albtraum kill of a boss: guaranteed, once per boss and profile, resets pity
##   - no reward when the boss is more than `farm_level_gap` levels below the
##     character (pity does not count either), when the player left the fight,
##     was idle (too little damage share) or the fight was too short
##   - a completion id is rewarded once; repeats are ignored
## Pure static functions on the profile; the random source is passed in.

const Profile = preload("res://src/progress/profile.gd")


## Level of a boss on `floor_number` at `difficulty`.
static func boss_level(d: Dictionary, floor_number: int, difficulty: String) -> int:
	var bonus := int(d.difficulties.get(difficulty, d.difficulties.normal).get("boss_level_bonus", 0))
	return maxi(1, floor_number * int(d.get("boss_level_per_floor", 2)) + bonus)


## Why this boss completion cannot reward a shard (and does not count for
## pity), or "". `fight`: {present, seconds, damage_share}.
static func ineligible(d: Dictionary, profile: Dictionary, completion_id: String, char_level: int, boss_lv: int, fight: Dictionary) -> String:
	var rules: Dictionary = d.soul_shards
	if completion_id.is_empty() or profile.rewarded.has(completion_id): return "Dieser Bosssieg wurde schon gewertet."
	if not bool(fight.get("present", false)): return "Du warst beim Sieg nicht im Kampf."
	if float(fight.get("seconds", 0.0)) < float(rules.min_fight_seconds): return "Der Kampf war zu kurz."
	if float(fight.get("damage_share", 0.0)) < float(rules.min_damage_share): return "Du hast zu wenig zum Sieg beigetragen."
	if boss_lv < char_level - int(rules.farm_level_gap): return "Der Boss ist mehr als %d Level unter dir." % int(rules.farm_level_gap)
	return ""


## Rolls one boss completion for a profile and applies the result (shard,
## pity, first-kill memory, completion id). `roll` is a float in [0, 1) from
## the host's random source. Returns {shard: bool, reason: String, counted: bool}.
static func resolve(d: Dictionary, profile: Dictionary, boss_id: String, difficulty: String, completion_id: String,
		char_level: int, boss_lv: int, fight: Dictionary, roll: float) -> Dictionary:
	var why := ineligible(d, profile, completion_id, char_level, boss_lv, fight)
	if not why.is_empty():
		if not completion_id.is_empty() and not profile.rewarded.has(completion_id) and why != "Dieser Bosssieg wurde schon gewertet.":
			_remember(d, profile, completion_id)
		return {"shard": false, "reason": why, "counted": false}
	_remember(d, profile, completion_id)
	var rules: Dictionary = d.soul_shards
	var shard := false
	var reason := ""
	var first: bool = difficulty == "nightmare" and not profile.nightmare_firsts.has(boss_id)
	if first:
		profile.nightmare_firsts.append(boss_id)
		shard = true
		reason = "Erster Sieg auf Albtraum gegen diesen Boss."
	elif int(profile.pity) >= int(rules.pity_after) - 1:
		shard = true
		reason = "Pechschutz."
	elif roll * 100.0 < float(d.difficulties.get(difficulty, d.difficulties.normal).drop_pct):
		shard = true
		reason = "Glück."
	if shard:
		profile.pity = 0
		profile.shards.have = int(profile.shards.have) + 1
		profile.shards.earned = int(profile.shards.earned) + 1
	else:
		profile.pity = int(profile.pity) + 1
		reason = "Kein Splitter."
	return {"shard": shard, "reason": reason, "counted": true}


## Whether an enemy can drop soul shards at all: real floor bosses only.
static func can_drop(enemy: Dictionary) -> bool:
	return bool(enemy.get("boss", false)) and not bool(enemy.get("miniboss", false)) and not bool(enemy.get("elite", false)) and not bool(enemy.get("summoned", false))


static func _remember(d: Dictionary, profile: Dictionary, completion_id: String) -> void:
	profile.rewarded.append(completion_id)
	var keep := int(d.soul_shards.get("reward_memory", 200))
	if profile.rewarded.size() > keep: profile.rewarded = profile.rewarded.slice(-keep)
