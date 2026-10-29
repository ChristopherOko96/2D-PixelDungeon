extends RefCounted
## Lasting progress of the Frostgruft between runs: soul crystals earned at
## the stairs and the talent trees bought with them (assets/data/frost_talents.json).
## Rules are pure functions on a plain dictionary
##   {crystals, classes: {class_id: {sub, owned: [sub ids], ranks: {node id: n}}}}
## so they test without files; load / save keep it in user://frost_meta.cfg.

const DATA_PATH := "res://assets/data/frost_talents.json"
const SAVE_PATH := "user://frost_meta.cfg"


static func data() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))


## A fresh store: no crystals, every class on its standard subclass.
static func fresh(d: Dictionary) -> Dictionary:
	var classes := {}
	for id: String in d.classes:
		var std: String = d.classes[id].standard
		classes[id] = {"sub": std, "owned": [std], "ranks": {}}
	return {"crystals": 0, "classes": classes}


static func load_store(d: Dictionary, path := SAVE_PATH) -> Dictionary:
	var store := fresh(d)
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return store
	store.crystals = int(cfg.get_value("meta", "crystals", 0))
	var saved: Variant = cfg.get_value("meta", "classes", {})
	if saved is Dictionary:
		for id: String in saved:
			if store.classes.has(id):
				(store.classes[id] as Dictionary).merge(saved[id], true)
	return store


static func save_store(store: Dictionary, path := SAVE_PATH) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "crystals", int(store.crystals))
	cfg.set_value("meta", "classes", store.classes)
	cfg.save(path)


# ---------- crystals ----------

## Crystals a floor gives at its stairs: the floor itself, its guardian and finished side goals.
static func floor_award(d: Dictionary, floor_n: int, kind: String, side_goals: int) -> int:
	var c: Dictionary = d.currency
	var n := int(c.floor_base) + int(floor(floor_n * float(c.per_floor)))
	n += int(c.get(kind, 0))
	n += side_goals * int(c.side_goal)
	return n


# ---------- trees ----------

static func _sub(d: Dictionary, class_id: String, sub: String) -> Dictionary:
	return d.classes[class_id].subs.get(sub, {})


## Where a node sits: {tier, node} or {} when it is not in that subclass.
static func find(d: Dictionary, class_id: String, sub: String, node_id: String) -> Dictionary:
	var tiers: Array = _sub(d, class_id, sub).get("tiers", [])
	for t in range(tiers.size()):
		for n: Dictionary in tiers[t]:
			if str(n.id) == node_id:
				return {"tier": t, "node": n}
	return {}


## Ranks spent in a class's active tree below a tier (all tiers when below = 5).
static func spent(d: Dictionary, store: Dictionary, class_id: String, below := 5) -> int:
	var c: Dictionary = store.classes[class_id]
	var total := 0
	for id: String in c.ranks:
		var at := find(d, class_id, str(c.sub), id)
		if not at.is_empty() and int(at.tier) < below:
			total += int(c.ranks[id])
	return total


## Why a node cannot be bought now ("" when it can).
static func why_not(d: Dictionary, store: Dictionary, class_id: String, node_id: String) -> String:
	var c: Dictionary = store.classes[class_id]
	var at := find(d, class_id, str(c.sub), node_id)
	if at.is_empty():
		return "nicht in diesem Baum"
	var t: int = at.tier
	var n: Dictionary = at.node
	if int(c.ranks.get(node_id, 0)) >= int(n.max):
		return "voll"
	if spent(d, store, class_id, t) < int(d.need[t]):
		return "ab %d Punkten" % int(d.need[t])
	if t == 4:
		for other: Dictionary in _sub(d, class_id, str(c.sub)).tiers[4]:
			if str(other.id) != node_id and int(c.ranks.get(str(other.id), 0)) > 0:
				return "andere Meisterfähigkeit gewählt"
	if int(store.crystals) < int(d.cost[t]):
		return "zu wenig Kristalle"
	return ""


## Buys one rank; false when the rules say no.
static func buy(d: Dictionary, store: Dictionary, class_id: String, node_id: String) -> bool:
	if why_not(d, store, class_id, node_id) != "":
		return false
	var c: Dictionary = store.classes[class_id]
	var t: int = find(d, class_id, str(c.sub), node_id).tier
	store.crystals = int(store.crystals) - int(d.cost[t])
	c.ranks[node_id] = int(c.ranks.get(node_id, 0)) + 1
	return true


## Gives every crystal of the class's tree back.
static func refund(d: Dictionary, store: Dictionary, class_id: String) -> int:
	var c: Dictionary = store.classes[class_id]
	var back := 0
	for id: String in c.ranks:
		var at := find(d, class_id, str(c.sub), id)
		if not at.is_empty():
			back += int(c.ranks[id]) * int(d.cost[int(at.tier)])
	store.crystals = int(store.crystals) + back
	c.ranks = {}
	return back


## Buys (once) or switches to a subclass; only one is active per class, so the
## old tree's crystals come back. "" on success, else why not.
static func choose_sub(d: Dictionary, store: Dictionary, class_id: String, sub: String) -> String:
	var s := _sub(d, class_id, sub)
	if s.is_empty():
		return "unbekannt"
	if not s.get("ready", false):
		return "kommt bald"
	var c: Dictionary = store.classes[class_id]
	if str(c.sub) == sub:
		return ""
	if not (c.owned as Array).has(sub):
		if int(store.crystals) < int(s.price):
			return "zu wenig Kristalle"
		store.crystals = int(store.crystals) - int(s.price)
		c.owned.append(sub)
	refund(d, store, class_id)
	c.sub = sub
	return ""


# ---------- what a run gets ----------

## The talents a run starts with: stat shares, card levels and the master skill.
## The run tree nodes this class's talent trees name (any subclass): they stay
## locked in the run until a lasting talent opens them (src/progress/run_tree.gd).
static func gated_cards(d: Dictionary, class_id: String) -> Dictionary:
	var out := {}
	if not d.get("classes", {}).has(class_id):
		return out
	for sub: Dictionary in (d.classes[class_id].subs as Dictionary).values():
		for tier: Array in sub.get("tiers", []):
			for n: Dictionary in tier:
				if n.has("card"):
					out[str(n.card)] = true
	return out


static func run_bonus(d: Dictionary, store: Dictionary, class_id: String) -> Dictionary:
	var out := {"damage": 0.0, "rate": 0.0, "speed": 0.0, "hearts": 0, "cards": {}, "master": "", "sub": "", "mods": []}
	if not store.classes.has(class_id):
		return out
	var c: Dictionary = store.classes[class_id]
	out.sub = c.sub
	for id: String in c.ranks:
		var at := find(d, class_id, str(c.sub), id)
		if at.is_empty():
			continue
		var n: Dictionary = at.node
		var r := int(c.ranks[id])
		if n.has("stat"):
			if str(n.stat) == "hearts":
				out.hearts = int(out.hearts) + int(n.value) * r
			else:
				out[str(n.stat)] = float(out[str(n.stat)]) + float(n.value) * r
		elif n.has("card"):
			out.cards[str(n.card)] = int(out.cards.get(str(n.card), 0)) + r
		elif n.has("mod") and r > 0:
			# a subclass skill value: add per rank, mul as share per rank (sub_kit.gd applies it)
			out.mods.append({"to": str(n.mod), "add": float(n.get("add", 0.0)) * r, "mul": float(n.get("mul", 0.0)) * r})
		elif n.has("master") and r > 0:
			out.master = str(n.master)
	return out
