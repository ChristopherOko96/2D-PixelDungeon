extends RefCounted
## The Beuteordnung der Welten (docs/BEUTEORDNUNG.de.md): every rule of drops, hearts, hit damage and
## chapter depth as pure functions over assets/data/reward_rules.json, so they test without a scene.
## Life is counted in LP (1 heart = 2 LP). Depth T = floor + 10 x the chapters the hero already finished.

const DATA_PATH := "res://assets/data/reward_rules.json"
const RARITIES := ["common", "uncommon", "rare", "epic", "legendary"]
const RARITY_NAMES := {"common": "gewöhnlich", "uncommon": "ungewöhnlich", "rare": "selten", "epic": "episch", "legendary": "legendär"}

static var _cfg: Dictionary = {}


## The rules (read once and kept).
static func cfg() -> Dictionary:
	if _cfg.is_empty() and FileAccess.file_exists(DATA_PATH):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
		if parsed is Dictionary:
			_cfg = parsed
	return _cfg


## Depth of floor `floor_number` for a hero who finished `chapters_done` chapters before this one.
static func depth(floor_number: int, chapters_done: int = 0) -> int:
	return maxi(1, floor_number) + int(cfg().get("chapter_depth", 10)) * maxi(0, chapters_done)


## LP one hit is worth at depth `t`: the steps of the file, past the last step 1 + floor((t - 1) / 3).
static func dmg(t: int) -> int:
	var steps: Array = (cfg().get("dmg", {}) as Dictionary).get("steps", [])
	for step: Dictionary in steps:
		if t <= int(step.to):
			return int(step.lp)
	return 1 + int(floor(float(maxi(1, t) - 1) / 3.0))


## The life cap at depth `t` (cap_hits hits).
static func cap(t: int) -> int:
	return int(cfg().get("cap_hits", 20)) * dmg(t)


## What a heal heart heals at depth `t`.
static func heal(t: int) -> int:
	return int(cfg().get("heal_hits", 2)) * dmg(t)


## The life heart of a floor or mini guardian.
static func guardian_life() -> int:
	return int((cfg().get("life_heart", {}) as Dictionary).get("guardian", 4))


## The life heart of a puzzle chest of `tier` at depth `t` (0 below tier 3).
static func puzzle_life(t: int, tier: int) -> int:
	if tier < 3:
		return 0
	return int(ceil(float(t) / 2.0)) + (tier - 3)


## A monster's and boss's HP factor for a hero who finished `chapters_done` chapters.
static func chapter_hp(chapters_done: int) -> float:
	return 1.0 + float(cfg().get("chapter_hp", 0.6)) * float(maxi(0, chapters_done))


## Loot value of a puzzle chest of `tier` at depth `t`.
static func value(t: int, tier: int) -> int:
	return t + int(cfg().get("tier_step", 2)) * (clampi(tier, 1, 5) - 1)


## Gold of a chest of loot value `w`.
static func gold(w: int) -> int:
	return int(cfg().get("gold_base", 10)) + int(cfg().get("gold_per_value", 4)) * w


## The least rarity of a chest's guaranteed piece at loot value `w` (never legendary).
static func min_rarity(w: int) -> String:
	for band: Dictionary in cfg().get("min_rarity", []):
		if w <= int(band.to):
			return str(band.rarity)
	return "epic"


## One rarity up from `rarity`, at most epic (legendary only comes from the map).
static func rarity_up(rarity: String) -> String:
	return RARITIES[mini(RARITIES.find(rarity) + 1, 3)]


## The parts of a puzzle chest of `tier` (reward_rules.json tiers).
static func tier(tier_number: int) -> Dictionary:
	return (cfg().get("tiers", {}) as Dictionary).get(str(clampi(tier_number, 1, 5)), {})


## {p, sure}: the chance that the best piece of a puzzle chest of `tier` on floor `floor_number` of its
## chapter turns legendary, and whether such a piece is clean for sure.
static func legendary(floor_number: int, tier_number: int) -> Dictionary:
	var cells: Dictionary = (cfg().get("legendary", {}) as Dictionary).get("cells", {})
	var cell: Dictionary = cells.get("%d-%d" % [floor_number, tier_number], {})
	return {"p": float(cell.get("p", 0.0)), "sure": bool(cell.get("sure", false))}


## The curse chance of a legendary piece that is not clean for sure, `roll` 0..1 picks it in curse_range.
static func legendary_curse_chance(roll: float) -> float:
	var span: Array = (cfg().get("legendary", {}) as Dictionary).get("curse_range", [0.75, 0.9])
	return lerpf(float(span[0]), float(span[1]), clampf(roll, 0.0, 1.0))


## The tier of a puzzle room on floor `floor_number` (of its chapter) for `roll` 0..1 (tier_share).
static func tier_for_floor(floor_number: int, roll: float) -> int:
	var share: Array = [100, 0, 0, 0, 0]
	for band: Dictionary in cfg().get("tier_share", []):
		var floors: Array = band.floors
		if floor_number >= int(floors[0]) and floor_number <= int(floors[1]):
			share = band.share
	if floor_number > 10 and not (cfg().get("tier_share", []) as Array).is_empty():
		share = (cfg().tier_share as Array).back().share
	var total := 0.0
	for v: Variant in share: total += float(v)
	var left := clampf(roll, 0.0, 0.999999) * total
	for i in range(share.size()):
		left -= float(share[i])
		if left < 0.0:
			return i + 1
	return 1


## The chance a puzzle room of `tier` has on floor `floor_number` (0..1).
static func tier_chance(floor_number: int, tier_number: int) -> float:
	var share: Array = [100, 0, 0, 0, 0]
	for band: Dictionary in cfg().get("tier_share", []):
		var floors: Array = band.floors
		if clampi(floor_number, 1, 10) >= int(floors[0]) and clampi(floor_number, 1, 10) <= int(floors[1]):
			share = band.share
	var total := 0.0
	for v: Variant in share: total += float(v)
	return float(share[clampi(tier_number, 1, 5) - 1]) / maxf(1.0, total)


## The normal rarity weights [floor 1, floor 10] (no legendary).
static func rarity_weights() -> Dictionary:
	return cfg().get("rarity_weights", {})


## The rarity of an armour with a power found on the side (the map and the final boss give legendary ones).
static func armor_power_rarity() -> String:
	return str(cfg().get("armor_power_rarity", "epic"))


## The values of a special source (secret, hidden, vault, guardian, final).
static func special(id: String) -> Dictionary:
	return (cfg().get("special", {}) as Dictionary).get(id, {})


## The fixed line at the end of a puzzle inscription: difficulty diamonds and what the chest pays.
static func reward_line(t: int, floor_number: int, tier_number: int) -> String:
	var spec := tier(tier_number)
	var w := value(t, tier_number)
	var pieces := int(spec.get("guaranteed", 1)) + int(spec.get("extra", 0))
	var parts: Array = ["%s oder besser" % RARITY_NAMES[min_rarity(w)], "%d Stück%s" % [pieces, "e" if pieces > 1 else ""]]
	var life := puzzle_life(t, tier_number)
	if life > 0:
		parts.append("Lebensherz +%d" % life)
	var rune := float(spec.get("rune", 0.0))
	if rune >= 1.0:
		parts.append("eine Rune")
	elif rune > 0.0:
		parts.append("Rune möglich")
	var leg := legendary(floor_number, tier_number)
	if bool(leg.sure):
		parts.append("ein legendäres Stück")
	elif float(leg.p) > 0.0:
		parts.append("Legendär-Chance")
	return "Schwierigkeit %s%s · Lohn: %s" % ["◆".repeat(tier_number), "◇".repeat(5 - tier_number), ", ".join(parts)]
