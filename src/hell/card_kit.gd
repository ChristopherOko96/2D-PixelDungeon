extends RefCounted
## Level-up upgrade cards of themed runs (theme.cards): each level-up offers
## three cards from the hero's class, the wielded relic and the shared list;
## a card can be taken up to its max, cards for skills only once that skill is
## open. Taken cards are counted in state.upgrades; skills and stats read them
## through level / value and the stat factors below. Small steps on purpose,
## so stacking cards never turns the hero into a one-shot machine.


## How often a card was taken.
static func level(g: Node, id: String) -> int:
	return int(g.state.get("upgrades", {}).get(id, 0))


## A value of a card's data (theme.cards), e.g. "damage" of "mg_focus".
static func value(g: Node, id: String, key: String, fallback: Variant) -> Variant:
	for c: Dictionary in _all(g):
		if str(c.id) == id:
			return c.get(key, fallback)
	return fallback


static func _all(g: Node) -> Array:
	var cards: Dictionary = g.theme.get("cards", {})
	var out: Array = []
	for set: String in cards:
		for c: Dictionary in cards[set]:
			var cc := c.duplicate()
			cc.set = set
			out.append(cc)
	return out


## Cards that may be offered now: shared, class and wielded relic, below max, skill open.
static func pool(g: Node) -> Array:
	var out: Array = []
	for c: Dictionary in _all(g):
		var set := str(c.set)
		if set != "all" and set != g.class_id and set != str(g.state.get("relic", "")):
			continue
		if level(g, str(c.id)) >= int(c.max):
			continue
		if c.has("skill") and not _skill_open(g, set, str(c.skill)):
			continue
		out.append(c)
	return out


static func _skill_open(g: Node, set: String, key: String) -> bool:
	var list: Array = g.theme.get(set, {}).get("skills", []) if set != g.class_id else g.skills
	for s: Dictionary in list:
		if str(s.key) == key:
			return int(g.state.level) >= int(s.unlock)
	return false


## A level-up: one more choice waits; shows three cards when none are open.
static func on_level_up(g: Node) -> void:
	if g.theme.get("cards", {}).is_empty():
		return
	g.state.cards_due = int(g.state.get("cards_due", 0)) + 1
	if (g.state.get("offer", []) as Array).is_empty():
		offer(g)


## Draws up to three different cards from the pool.
static func offer(g: Node) -> void:
	var p := pool(g)
	p.shuffle()
	g.state.offer = p.slice(0, mini(3, p.size()))
	g.state.offer_t = 0.0
	if (g.state.offer as Array).is_empty():
		g.state.cards_due = 0


## Takes card i of the offer; the next waiting choice follows.
static func choose(g: Node, i: int) -> void:
	var offer: Array = g.state.get("offer", [])
	if i < 0 or i >= offer.size():
		return
	var c: Dictionary = offer[i]
	var ups: Dictionary = g.state.get("upgrades", {})
	ups[str(c.id)] = level(g, str(c.id)) + 1
	g.state.upgrades = ups
	if c.has("hearts"):
		g.state.max_hp = mini(int(g.balance.player.max_hp_cap), int(g.state.max_hp) + int(c.hearts))
		g.state.hp = mini(int(g.state.max_hp), int(g.state.hp) + int(c.hearts))
	g._sound("level_up")
	g._toast("%s (Stufe %d)" % [c.name, level(g, str(c.id))])
	g.state.offer = []
	g.state.cards_due = maxi(0, int(g.state.get("cards_due", 0)) - 1)
	if int(g.state.cards_due) > 0:
		offer(g)


# ---------- stat factors from the shared and class cards ----------

## Damage factor of the damage cards (+15 % each).
static func damage_mult(g: Node) -> float:
	var f := 1.0
	for id: String in ["sw_heavy", "mg_focus"]:
		f += float(value(g, id, "damage", 0.0)) * level(g, id)
	return f


## Attack pause factor of the rate cards (10 % faster each).
static func rate_mult(g: Node) -> float:
	var f := 1.0
	for id: String in ["sw_swift", "ar_rapid", "mg_haste"]:
		f *= pow(1.0 - float(value(g, id, "rate", 0.0)), level(g, id))
	return f


## Running speed factor (archer's light foot).
static func speed_mult(g: Node) -> float:
	return 1.0 + float(value(g, "ar_fleet", "speed", 0.0)) * level(g, "ar_fleet")
