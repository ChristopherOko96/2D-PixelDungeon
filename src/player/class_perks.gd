extends RefCounted
## Class skills, their upgrades and the class passives (assets/data/hero_skills.json).
## Pure static rules on player dictionaries, used by the host: which skills a
## team level unlocks, which cards a level-up offers, what a picked card does to
## the player's stats, and the current value of any skill parameter after its
## upgrades. Owned class cards live in `player.class_perks` (one id per stack).

const DATA_PATH := "res://assets/data/hero_skills.json"
const RunTree = preload("res://src/progress/run_tree.gd")
static var _data: Dictionary = {}


## The whole skill table (cached). Tests and tools may pass their own via `override`.
static func data(override: Dictionary = {}) -> Dictionary:
	if not override.is_empty(): return override
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH)) if FileAccess.file_exists(DATA_PATH) else null
		_data = parsed if parsed is Dictionary else {"classes": {}}
	return _data


## One class block ({skills, passives, weapon_icon, color}); {} when unknown.
static func class_data(class_id: String) -> Dictionary:
	return data().get("classes", {}).get(class_id, {})


## The class's skills on keys 1-4: none any more. The talent trees took those
## keys (user decision 29.10.2026, docs/TALENTE-SEELENSPLITTER.de.md); the old
## skill definitions stay in hero_skills.json only as reference.
static func skills(_class_id: String) -> Array:
	return []


## Skill definition by slot index 0-3 ({} when missing).
static func skill_at(class_id: String, index: int) -> Dictionary:
	var list := skills(class_id)
	return list[index] if index >= 0 and index < list.size() else {}


## How many of a card id the player owns.
static func rank(player: Dictionary, id: String) -> int:
	return Array(player.get("class_perks", [])).count(id)


## The class's run talent tree (src/progress/run_tree.gd): the passives. The
## class skills and their upgrade branches are gone; the talent trees took keys
## 1-4 (user decision 29.10.2026, docs/TALENTE-SEELENSPLITTER.de.md).
static func run_tree(class_id: String, meta: Dictionary = {}) -> Dictionary:
	var branches: Array = []
	var passives: Array = []
	for entry: Dictionary in class_data(class_id).get("passives", []):
		passives.append({"id": str(entry.id), "name": str(entry.name), "text": str(entry.get("description", "")), "max": int(entry.get("max", 1))})
	branches.append({"key": "passive", "title": "PASSIV", "unlock": 1, "nodes": passives})
	# the hero's lasting talents (player.meta: gated ids, unlocked ranks) open nodes
	if not meta.is_empty():
		branches = RunTree.gate(branches, meta.get("gated", {}), meta.get("unlocked", {}))
	return RunTree.build(branches)


## The hero's ranks in the run tree: how often each class card was taken.
static func ranks(player: Dictionary) -> Dictionary:
	var out := {}
	for id: Variant in player.get("class_perks", []):
		out[str(id)] = int(out.get(str(id), 0)) + 1
	return out


## The run tree's node ids in drawing order (the network sends an index).
static func run_tree_ids(class_id: String) -> Array:
	var ids: Array = []
	for b: Dictionary in run_tree(class_id).branches:
		for n: Dictionary in b.nodes:
			ids.append(str(n.id))
	return ids


## True when the team level has unlocked skill slot `index`.
static func unlocked(class_id: String, index: int, level: int) -> bool:
	var skill := skill_at(class_id, index)
	return not skill.is_empty() and level >= int(skill.get("unlock", 1))


## `key` of upgrade `id` times the owned rank (0 when not owned). Skill code
## combines these explicitly, e.g. radius × (1 + bonus("wide_swing", "radius")).
static func bonus(player: Dictionary, skill: Dictionary, id: String, key: String) -> float:
	var owned := rank(player, id)
	if owned <= 0: return 0.0
	return float(upgrade(skill, id).get(key, 0.0)) * owned


## True when the player owns upgrade `id`.
static func has(player: Dictionary, id: String) -> bool:
	return rank(player, id) > 0


## An upgrade definition of a skill by id ({} when missing).
static func upgrade(skill: Dictionary, id: String) -> Dictionary:
	for entry: Dictionary in skill.get("upgrades", []):
		if str(entry.id) == id: return entry
	return {}


## Any class card (upgrade or passive) by id, with `kind` and `skill` filled in.
static func find(class_id: String, id: String) -> Dictionary:
	var block := class_data(class_id)
	for skill: Dictionary in block.get("skills", []):
		for entry: Dictionary in skill.get("upgrades", []):
			if str(entry.id) == id:
				var card: Dictionary = entry.duplicate(true)
				card.kind = "upgrade"
				card.skill = str(skill.id)
				card.skill_name = str(skill.name)
				card.icon = skill.get("icon", {}).duplicate()
				card.icon.badge = str(entry.get("badge", "plus"))
				return card
	for entry: Dictionary in block.get("passives", []):
		if str(entry.id) == id:
			var card: Dictionary = entry.duplicate(true)
			card.kind = "passive"
			return card
	return {}


## Up to `count` distinct level-up cards for a player: upgrades of unlocked
## skills and class passives below their maximum. An exhausted pool returns
## the heal/shield fallback from balance.perk_rules.
static func offer(player: Dictionary, level: int, rng: RandomNumberGenerator, balance: Dictionary, count: int = 3) -> Array:
	var class_id := str(player.get("class_id", ""))
	var pool: Array = []
	for index in range(skills(class_id).size()):
		if not unlocked(class_id, index, level): continue
		for entry: Dictionary in skill_at(class_id, index).get("upgrades", []):
			if rank(player, str(entry.id)) < int(entry.get("max", 1)): pool.append(str(entry.id))
	for entry: Dictionary in class_data(class_id).get("passives", []):
		if rank(player, str(entry.id)) < int(entry.get("max", 1)): pool.append(str(entry.id))
	var result: Array = []
	while not pool.is_empty() and result.size() < count:
		var pick := rng.randi_range(0, pool.size() - 1)
		var card := find(class_id, str(pool[pick]))
		card.rank = rank(player, str(pool[pick]))
		result.append(card)
		pool.remove_at(pick)
	if result.is_empty():
		var fallback: Dictionary = balance.get("perk_rules", {}).get("fallback", {})
		if not fallback.is_empty():
			var card: Dictionary = fallback.duplicate(true)
			card.kind = "fallback"
			result.append(card)
	return result


## Takes one class card. Returns false for unknown or maxed cards. Stats are
## rebuilt by the caller (PerkRules.rebuild applies passives through `apply`).
static func grant(player: Dictionary, id: String) -> bool:
	var card := find(str(player.get("class_id", "")), id)
	if card.is_empty() or rank(player, id) >= int(card.get("max", 1)): return false
	if not player.has("class_perks"): player.class_perks = []
	player.class_perks.append(id)
	return true


## Applies owned passives on top of the perk-derived stats. Called at the end of
## PerkRules.rebuild, so every rebuild yields the same numbers.
static func apply(player: Dictionary) -> void:
	# lasting talents of the main menu (damage, attack rate, speed, hearts) first
	var bonus: Dictionary = player.get("meta", {}).get("bonus", {})
	if not bonus.is_empty():
		player.damage = float(player.damage) * (1.0 + float(bonus.get("damage", 0.0)))
		player.shot_interval = float(player.shot_interval) * (1.0 - float(bonus.get("rate", 0.0)))
		player.speed = float(player.speed) * (1.0 + float(bonus.get("speed", 0.0)))
		player.max_hp = int(player.max_hp) + int(bonus.get("hearts", 0))
	var class_id := str(player.get("class_id", ""))
	if class_id.is_empty() or Array(player.get("class_perks", [])).is_empty(): return
	var build: Dictionary = player.get("build", {})
	for entry: Dictionary in class_data(class_id).get("passives", []):
		var owned := mini(rank(player, str(entry.id)), int(entry.get("max", 1)))
		if owned <= 0: continue
		var amount := float(entry.get("amount", 0.0))
		match str(entry.get("stat", "")):
			"damage_mult": player.damage = float(player.damage) * pow(amount, owned)
			"rate_mult": player.shot_interval = float(player.shot_interval) * pow(amount, owned)
			"max_hp": player.max_hp = int(player.max_hp) + int(amount) * owned
			"speed": player.speed = float(player.speed) + amount * owned
			"shot_speed_mult": player.shot_speed = float(player.get("_class_shot_speed", player.get("shot_speed", 0.0))) * pow(amount, owned)
			"splash_mult": player.splash = float(player.get("_class_splash", player.get("splash", 0.0))) * pow(amount, owned)
			"build":
				var values: Array = entry.get("values", [1])
				build[str(entry.key)] = maxf(float(build.get(str(entry.key), 0.0)), float(values[mini(owned, values.size()) - 1]))
			"build_add": build[str(entry.key)] = float(build.get(str(entry.key), 0.0)) + amount * owned
			"flag": build[str(entry.key)] = 1.0
	player.build = build
