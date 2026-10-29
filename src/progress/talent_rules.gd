extends RefCounted
## Rules of the talent trees (assets/data/talents.json): talent points per
## level, tier requirements, ranks, the single ultimate bought with soul
## shards, soul tiers, the gold reset and character EXP. Pure static functions
## on the profile (src/progress/profile.gd); every change returns "" or the
## reason it was refused, so menus and the host share one set of checks.

const Profile = preload("res://src/progress/profile.gd")


## Talent points a character of `level` has in total (one per level from 2).
static func points_total(d: Dictionary, level: int) -> int:
	return clampi(level - int(d.get("first_point_level", 2)) + 1, 0, int(d.get("max_level", 30)) - 1)


static func spent(state: Dictionary) -> int:
	var total := 0
	for rank: Variant in state.ranks.values(): total += int(rank)
	return total


static func free_points(d: Dictionary, state: Dictionary) -> int:
	return maxi(0, points_total(d, int(state.level)) - spent(state))


## Points in `spec`, optionally only in tiers below `below_tier`.
static func spec_points(d: Dictionary, state: Dictionary, spec: String, below_tier: int = 99) -> int:
	var total := 0
	for talent: String in state.ranks:
		var info: Dictionary = d.talents.get(talent, {})
		if str(info.get("spec", "")) == spec and int(info.tier) < below_tier: total += int(state.ranks[talent])
	return total


static func rank(state: Dictionary, talent: String) -> int:
	return int(state.ranks.get(talent, 0))


## Why `talent` cannot gain one rank now, or "".
static func check_rank_up(d: Dictionary, profile: Dictionary, class_id: String, talent: String) -> String:
	var info: Dictionary = d.talents.get(talent, {})
	if info.is_empty() or str(info["class"]) != class_id: return "Dieses Talent gehört nicht zu deiner Klasse."
	var state := Profile.class_state(profile, class_id)
	if rank(state, talent) >= int(info.ranks): return "Maximalrang erreicht."
	var tier: Dictionary = d.tiers[str(int(info.tier))]
	if int(state.level) < int(tier.level): return "Benötigt Charakterlevel %d." % int(tier.level)
	if spec_points(d, state, str(info.spec), int(info.tier)) < int(tier.points):
		return "Benötigt %d Punkte im Zweig (jetzt %d)." % [int(tier.points), spec_points(d, state, str(info.spec), int(info.tier))]
	if free_points(d, state) <= 0: return "Kein freier Talentpunkt."
	if str(info.kind) == "ultimate":
		if not str(state.ultimate).is_empty() and str(state.ultimate) != talent: return "Es ist schon eine andere Ultimate freigeschaltet."
		var cost := int(d.soul_shards.ultimate_cost)
		if int(profile.shards.have) < cost: return "Benötigt %d Seelensplitter (du hast %d)." % [cost, int(profile.shards.have)]
	return ""


## Adds one rank (an ultimate also spends its soul shards). "" on success.
static func rank_up(d: Dictionary, profile: Dictionary, class_id: String, talent: String) -> String:
	var reason := check_rank_up(d, profile, class_id, talent)
	if not reason.is_empty(): return reason
	var state := Profile.class_state(profile, class_id)
	state.ranks[talent] = rank(state, talent) + 1
	var info: Dictionary = d.talents[talent]
	if str(info.kind) == "ultimate":
		var cost := int(d.soul_shards.ultimate_cost)
		_spend(profile, cost)
		state.ultimate = talent
		state.soul_tier = 0
		state.soul_paid = cost
	if str(info.kind) != "passive" and not state.bar.has(talent) and str(info.kind) != "ultimate" and state.bar.size() < int(d.get("bar_slots", 4)):
		state.bar.append(talent)
	return ""


## Whether removing one rank of `talent` keeps every other rank valid.
static func can_rank_down(d: Dictionary, profile: Dictionary, class_id: String, talent: String) -> bool:
	var state := Profile.class_state(profile, class_id)
	if rank(state, talent) <= 0: return false
	var trial := state.duplicate(true)
	trial.ranks[talent] = rank(state, talent) - 1
	if int(trial.ranks[talent]) == 0: trial.ranks.erase(talent)
	return valid_build(d, trial)


## Removes one rank (the menu's "Punkt zurücknehmen"); an ultimate refunds its shards.
static func rank_down(d: Dictionary, profile: Dictionary, class_id: String, talent: String) -> String:
	if not can_rank_down(d, profile, class_id, talent): return "Andere Talente bauen auf diesem Punkt auf."
	var state := Profile.class_state(profile, class_id)
	state.ranks[talent] = rank(state, talent) - 1
	if int(state.ranks[talent]) == 0:
		state.ranks.erase(talent)
		state.bar.erase(talent)
		if str(state.ultimate) == talent: _refund_ultimate(profile, state)
	return ""


## Every ranked talent meets its tier, the points fit the level, at most one ultimate.
static func valid_build(d: Dictionary, state: Dictionary) -> bool:
	if spent(state) > points_total(d, int(state.level)): return false
	var ultimates := 0
	for talent: String in state.ranks:
		var info: Dictionary = d.talents.get(talent, {})
		if info.is_empty() or int(state.ranks[talent]) > int(info.ranks): return false
		var tier: Dictionary = d.tiers[str(int(info.tier))]
		if int(state.level) < int(tier.level): return false
		if spec_points(d, state, str(info.spec), int(info.tier)) < int(tier.points): return false
		if str(info.kind) == "ultimate": ultimates += 1
	return ultimates <= 1


## Drops ranks until the build is valid (a received or hand-edited profile):
## the highest tiers go first. Returns how many ranks were removed.
static func repair(d: Dictionary, profile: Dictionary, class_id: String) -> int:
	var state := Profile.class_state(profile, class_id)
	var removed := 0
	while not valid_build(d, state) and not state.ranks.is_empty():
		var worst := ""
		for talent: String in state.ranks:
			if worst.is_empty() or int(d.talents.get(talent, {"tier": 99}).tier) > int(d.talents.get(worst, {"tier": 99}).tier): worst = talent
		state.ranks[worst] = int(state.ranks[worst]) - 1
		if int(state.ranks[worst]) <= 0:
			state.ranks.erase(worst)
			state.bar.erase(worst)
		removed += 1
	if not str(state.ultimate).is_empty() and not state.ranks.has(state.ultimate): _refund_ultimate(profile, state)
	return removed


## Buys the next stage of the owned ultimate (Stufe 2, then 3; each changes
## the ability, talents.json "stages"). "" on success.
static func soul_up(d: Dictionary, profile: Dictionary, class_id: String) -> String:
	var state := Profile.class_state(profile, class_id)
	if str(state.ultimate).is_empty(): return "Erst eine Ultimate freischalten."
	var tier := int(state.soul_tier)
	var costs: Array = d.soul_shards.tier_costs
	if tier >= costs.size(): return "Höchste Stufe erreicht."
	if int(profile.shards.have) < int(costs[tier]): return "Benötigt %d Seelensplitter." % int(costs[tier])
	_spend(profile, int(costs[tier]))
	state.soul_tier = tier + 1
	state.soul_paid = int(state.soul_paid) + int(costs[tier])
	return ""


## Gold a reset of `class_id` costs now.
static func reset_cost(d: Dictionary, profile: Dictionary, class_id: String) -> int:
	return int(Profile.class_state(profile, class_id).level) * int(d.get("reset_gold_per_level", 25))


## Resets every talent of the class for gold: points come back, spent soul
## shards come back in full, soul tiers end. "" on success.
static func reset(d: Dictionary, profile: Dictionary, class_id: String) -> String:
	var state := Profile.class_state(profile, class_id)
	if state.ranks.is_empty(): return "Es sind keine Punkte verteilt."
	var cost := reset_cost(d, profile, class_id)
	if int(profile.gold) < cost: return "Zu wenig Gold: %d nötig." % cost
	profile.gold = int(profile.gold) - cost
	_refund_ultimate(profile, state)
	state.ranks = {}
	state.bar = []
	return ""


## Puts `talent` into bar slot `slot` (actives only), swapping if it sat elsewhere.
static func set_bar(d: Dictionary, profile: Dictionary, class_id: String, talent: String, slot: int) -> String:
	var state := Profile.class_state(profile, class_id)
	var info: Dictionary = d.talents.get(talent, {})
	if rank(state, talent) <= 0 or str(info.get("kind", "")) != "active": return "Nur gelernte aktive Talente passen auf die Leiste."
	slot = clampi(slot, 0, int(d.get("bar_slots", 4)) - 1)
	state.bar.erase(talent)
	while state.bar.size() <= slot: state.bar.append("")
	state.bar.insert(slot, talent)
	state.bar = state.bar.filter(func(v: String) -> bool: return not v.is_empty()).slice(0, int(d.get("bar_slots", 4)))
	return ""


## EXP from `level` to the next one.
static func exp_to_next(d: Dictionary, level: int) -> int:
	return maxi(1, roundi(float(d.levels.base) * pow(float(maxi(1, level)), float(d.levels.exponent))))


## Adds character EXP; returns the levels gained (no EXP is kept at the cap).
static func add_exp(d: Dictionary, state: Dictionary, amount: int) -> int:
	if amount <= 0: return 0
	var cap := int(d.get("max_level", 30))
	var gained := 0
	state.exp = int(state.exp) + amount
	while int(state.level) < cap and int(state.exp) >= exp_to_next(d, int(state.level)):
		state.exp = int(state.exp) - exp_to_next(d, int(state.level))
		state.level = int(state.level) + 1
		gained += 1
	if int(state.level) >= cap: state.exp = 0
	return gained


## The stage bonus of the ultimate as a factor (1.0 at Stufe 1).
static func soul_scale(d: Dictionary, state: Dictionary) -> float:
	var bonus: Array = d.soul_shards.tier_bonus_pct
	var tier := mini(int(state.get("soul_tier", 0)), bonus.size())
	return 1.0 + (float(bonus[tier - 1]) / 100.0 if tier > 0 else 0.0)


## The talent as it plays at `tier` bought stages (0 = Stufe 1): the stages'
## "add" numbers summed in, "set" values replaced, and their "after" waves,
## "ground", "fan" and "reset_cds" collected (talents.json soul_shards._stages_note).
## Returns the talent itself when nothing changes.
static func staged(d: Dictionary, talent: String, tier: int) -> Dictionary:
	var info: Dictionary = d.talents.get(talent, {})
	var stages: Array = info.get("stages", [])
	if tier <= 0 or stages.is_empty(): return info
	var out := info.duplicate(true)
	var after: Array = []
	for stage: Dictionary in stages.slice(0, mini(tier, stages.size())):
		for key: String in stage.get("add", {}):
			var plus := float(stage.add[key])
			var raw: Variant = out.get(key, 0.0)
			if raw is Array:
				var list: Array = (raw as Array).duplicate()
				for i in range(list.size()): list[i] = float(list[i]) + plus
				out[key] = list
			else: out[key] = float(raw) + plus
		for key: String in stage.get("set", {}): out[key] = stage.set[key]
		after.append_array(stage.get("after", []))
		for key: String in ["ground", "fan", "reset_cds"]:
			if stage.has(key): out[key] = stage[key]
	if not after.is_empty(): out.after = after
	return out


static func _spend(profile: Dictionary, amount: int) -> void:
	profile.shards.have = int(profile.shards.have) - amount
	profile.shards.spent = int(profile.shards.spent) + amount


static func _refund_ultimate(profile: Dictionary, state: Dictionary) -> void:
	var paid := int(state.soul_paid)
	profile.shards.have = int(profile.shards.have) + paid
	profile.shards.spent = maxi(0, int(profile.shards.spent) - paid)
	state.ultimate = ""
	state.soul_tier = 0
	state.soul_paid = 0
