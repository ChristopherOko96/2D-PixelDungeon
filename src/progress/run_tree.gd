extends RefCounted
## The run talent tree (docs/LAUF-DESIGN.de.md 3.4), the same rules in every
## world: each level-up gives one point; a class tree has one branch per skill
## and one for passives; a branch opens at its skill's level; its first two
## nodes (tier 1) are free to take, the others (tier 2) need `tier_points` in
## that branch; a node can take as many points as its max. The tree dies with
## the run. Worlds hand in their own nodes (crypt: hero_skills.json upgrades and
## passives; Hell-Dungeon and Frostgruft: their theme cards) and keep the ranks
## where they always did. Pure static functions on plain data.
##
## Example:
##   var tree := RunTree.build([{"key": "1", "title": "FEUERBALL", "unlock": 1, "nodes": [...]}])
##   if RunTree.can_take(tree, ranks, level, "twin_fire"): ranks.twin_fire = int(ranks.get("twin_fire", 0)) + 1

const DATA_PATH := "res://assets/data/run_tree.json"
const DEFAULTS := {"points_per_level": 1, "tier_points": 2, "tier_one_nodes": 2, "key": "B"}

static var _settings: Dictionary = {}


## run_tree.json with defaults.
static func settings() -> Dictionary:
	if _settings.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH)) if FileAccess.file_exists(DATA_PATH) else null
		var data: Dictionary = parsed if parsed is Dictionary else {}
		for key: String in DEFAULTS:
			_settings[key] = data.get(key, DEFAULTS[key])
	return _settings


## A tree from branches [{key, title, unlock (level), nodes: [{id, name, text, max}]}]:
## every node gets its branch index and tier.
static func build(branches: Array) -> Dictionary:
	var out: Array = []
	var tier_one := int(settings().tier_one_nodes)
	for b: Dictionary in branches:
		var nodes: Array = []
		var index := 0
		for n: Dictionary in b.get("nodes", []):
			var node := n.duplicate(true)
			node.max = maxi(1, int(n.get("max", 1)))
			node.tier = 1 if index < tier_one else 2
			nodes.append(node)
			index += 1
		if nodes.is_empty():
			continue
		out.append({"key": str(b.get("key", "")), "title": str(b.get("title", "")), "unlock": int(b.get("unlock", 1)), "nodes": nodes})
	return {"branches": out}


## Points the level has given so far (level 1 has none).
static func points_total(level: int) -> int:
	return maxi(0, level - 1) * int(settings().points_per_level)


## Points spent in `ranks` (only on nodes of this tree).
static func spent(tree: Dictionary, ranks: Dictionary) -> int:
	var total := 0
	for b: Dictionary in tree.get("branches", []):
		total += branch_points(b, ranks)
	return total


## Points left to spend (never below 0).
static func points_left(tree: Dictionary, ranks: Dictionary, level: int) -> int:
	return maxi(0, points_total(level) - spent(tree, ranks))


## Points spent in one branch.
static func branch_points(branch: Dictionary, ranks: Dictionary) -> int:
	var total := 0
	for n: Dictionary in branch.get("nodes", []):
		total += mini(int(ranks.get(str(n.id), 0)), int(n.max))
	return total


## A node's state: "maxed", "open", "no_points", "skill_locked" (the branch's
## skill is not open yet), "tier_locked" (needs points in tier 1 first),
## "meta_locked" (a lasting talent must open it first) or "".
static func state_of(tree: Dictionary, ranks: Dictionary, level: int, id: String) -> String:
	for b: Dictionary in tree.get("branches", []):
		for n: Dictionary in b.nodes:
			if str(n.id) != id:
				continue
			if bool(n.get("meta_locked", false)):
				return "meta_locked"
			if int(ranks.get(id, 0)) >= int(n.max):
				return "maxed"
			if level < int(b.unlock):
				return "skill_locked"
			if int(n.tier) > 1 and branch_points(b, ranks) < int(settings().tier_points):
				return "tier_locked"
			if points_left(tree, ranks, level) <= 0:
				return "no_points"
			return "open"
	return ""


## The lasting talents (main menu TALENTE, src/hell/meta_store.gd) open nodes:
## a node in `gated` (ids the talent trees name) is locked until `unlocked`
## has a rank for it, and then takes at most that many points. Other nodes stay
## as they are. Returns the branches with that applied (docs/LAUF-DESIGN.de.md 3.3).
static func gate(branches: Array, gated: Dictionary, unlocked: Dictionary) -> Array:
	var out: Array = []
	for b: Dictionary in branches:
		var copy := b.duplicate(true)
		for n: Dictionary in copy.get("nodes", []):
			var id := str(n.id)
			if not gated.has(id):
				continue
			var rank := int(unlocked.get(id, 0))
			if rank <= 0:
				n.meta_locked = true
			else:
				n.max = mini(int(n.get("max", 1)), rank)
		out.append(copy)
	return out


## True when one more point may go into node `id` now.
static func can_take(tree: Dictionary, ranks: Dictionary, level: int, id: String) -> bool:
	return state_of(tree, ranks, level, id) == "open"


## The node by id ({} when the tree lacks it).
static func node(tree: Dictionary, id: String) -> Dictionary:
	for b: Dictionary in tree.get("branches", []):
		for n: Dictionary in b.nodes:
			if str(n.id) == id:
				return n
	return {}
