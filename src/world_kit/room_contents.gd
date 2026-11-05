extends RefCounted
## What a chest or a breakable piece of a Weltbauer room holds, beyond a fixed item: a monster hiding in
## the chest, content the floor chooses, enemies that come out. A single room and a floor both use it;
## they differ only in the dice they pass (a floor's are seeded). Values: assets/data/world_room_contents.json.

const PATH := "res://assets/data/world_room_contents.json"


## The file's values.
static func cfg() -> Dictionary:
	return DataCache.load_dict(PATH)


## True for a monster that waits as a chest when placed (Mimik, Truhenfresser).
static func is_chest_mob(mob: String) -> bool:
	return mob in Array(cfg().get("chest_mobs", []))


## The chest a placed Mimik or Truhenfresser stands as, at world place x, y.
static func hiding_chest(mob: String, x: float, y: float) -> Dictionary:
	return {"type": "chest", "x": x, "y": y, "state": "", "magic": false, "mimic": true, "mimic_mob": mob, "loot": {"gems": 0}}


## The enemies part `o` lets out, at most max_enemies.
static func enemies_of(o: Dictionary) -> Array:
	var out: Array = []
	for id: Variant in o.get("enemies", []):
		if str(id) != "" and out.size() < int(cfg().get("max_enemies", 2)):
			out.append(str(id))
	return out


## Applies a chest's settings to its floor piece `e`: content "random", Mimik "yes", "no" or "random",
## its enemies. `floor_number` scales the gold, `roll` gives a number from 0 to 1. A chest without a
## Mimik setting keeps what `e` already says.
static func finish_chest(e: Dictionary, o: Dictionary, floor_number: int, roll: Callable) -> void:
	var c := cfg()
	if str((o.get("loot", {}) as Dictionary).get("type", "")) == "random":
		var paid: Dictionary = c.get("random_chest", {})
		e.loot = {"gems": int(paid.get("gems_base", 3)) + int(paid.get("gems_per_floor", 1)) * floor_number,
			"heart": float(roll.call()) < float(paid.get("heart_chance", 0.25))}
		e.erase("exact")
		e.erase("give")
	if str((o.get("loot", {}) as Dictionary).get("type", "")) == "hoard":
		# the Schatz of a solved puzzle: much gold, a heart, several of the game's item rolls
		var hoard: Dictionary = c.get("hoard", {})
		e.loot = {"gems": int(hoard.get("gems_base", 14)) + int(hoard.get("gems_per_floor", 3)) * floor_number, "heart": true}
		e.hoard = (hoard.get("rolls", ["gold_crate"]) as Array).duplicate()
		e.magic = true
		e.erase("exact")
		e.erase("give")
	match str(o.get("mimic", "")):
		"yes":
			e.mimic = true
		"no":
			e.erase("mimic")
			# a floor's mimic chest holds nothing: as a real chest it pays a coin
			if not e.has("give") and not (e.loot as Dictionary).has("key"):
				e.loot.gems = maxi(int((e.loot as Dictionary).get("gems", 0)), 1)
		"random":
			if float(roll.call()) < float(c.get("mimic_chance", 0.35)):
				e.mimic = true
			else:
				e.erase("mimic")
	if e.get("mimic", false) and str(o.get("mimic_mob", "")) != "":
		e.mimic_mob = str(o.mimic_mob)
	var out := enemies_of(o)
	if not out.is_empty():
		e.enemies = out


## The stone an Inschrift (part `tablet` at x, y in room px) stands as: a blocking prop of the file's
## picture, so a floor and a single room draw and block it like any other piece.
static func tablet_prop(o: Dictionary) -> Dictionary:
	var look: Dictionary = cfg().get("tablet", {})
	return {"kind": "prop", "asset": str(o.get("asset", look.get("asset", "obelisk"))), "x": float(o.x), "y": float(o.y),
		"layer": "normal", "block": true, "foot": look.get("foot", [56, 24]), "flip": false, "scale": 1}


## What a chest holds as drops of hell_game.world_room_drop, for when its Mimik falls.
static func drops_of(e: Dictionary) -> Array:
	var out: Array = []
	var loot: Dictionary = e.get("loot", {})
	if loot.has("key"):
		out.append({"type": "key", "id": str(loot.key)})
	if int(loot.get("gems", 0)) > 0:
		out.append({"type": "gold", "amount": int(loot.gems)})
	if loot.get("heart", false):
		out.append({"type": "heart"})
	if e.has("give"):
		out.append(e.give)
	return out


## What a broken piece with content "random" drops: "none", "gold" or "heart", for `v` from 0 to 1.
static func piece_drop(v: float) -> String:
	var chances: Dictionary = cfg().get("random_piece", {})
	var nothing := float(chances.get("nothing", 0.35))
	if v < nothing:
		return "none"
	return "gold" if v < nothing + float(chances.get("gold", 0.45)) else "heart"
