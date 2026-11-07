extends RefCounted
## Upgrade cards of themed runs (theme.cards). A level-up gives one point for
## the run talent tree (src/progress/run_tree.gd, docs/LAUF-DESIGN.de.md): the
## cards are its nodes, a branch per skill, one for the basics, one for a carried
## relic; `tree` builds it, `take_node` spends a point. (Earlier: three cards
## per level-up; `offer` / `choose` remain for that flow.) Cards come from the
## hero's class, the carried relic and the shared list; a card can be taken up
## to its max, cards for skills only once that skill is open. Taken cards are counted in state.upgrades; skills and stats read them
## through level / value and the stat factors below. Small steps on purpose,
## so stacking cards never turns the hero into a one-shot machine.

const RunTree = preload("res://src/progress/run_tree.gd")
const ClassPerks = preload("res://src/player/class_perks.gd")
const SkillIcons = preload("res://src/ui/skill_icons.gd")
const MetaStore = preload("res://src/hell/meta_store.gd")
const Rules = preload("res://src/hell/hell_rules.gd")
## The hell's seal values (balance package D1) for a world balance without them.
const SEAL_DEFAULTS := "res://assets/data/hell_balance.json"
static var _seal_defaults: Dictionary = {}


## How often a card was taken in this run. (Lasting talents no longer add
## levels: they open the card's node in the run tree, see `tree`.)
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
		# a subclass (sub_kit.gd) has its own skills: the class cards widen the standard ones
		if set == g.class_id and not g.sub_kit.is_empty():
			continue
		if level(g, str(c.id)) >= int(c.max):
			continue
		if c.has("skill") and not _skill_open(g, set, str(c.skill)):
			continue
		# a heart card at the life cap would give nothing
		if c.has("hearts") and not Rules.heart_room(g.state, int(g.life_cap())):
			continue
		out.append(c)
	return out


static func _skill_open(g: Node, set: String, key: String) -> bool:
	var list: Array = g.theme.get(set, {}).get("skills", []) if set != g.class_id else g.skills
	for s: Dictionary in list:
		if str(s.key) == key:
			return int(g.state.level) >= int(s.unlock)
	return false


## True when this run hands out level-up cards to pick (7 8 9 or a click).
## The story worlds give run talent points instead, so their help and status
## sheet leave the card lines out.
static func offers_cards(g: Node) -> bool:
	return not (g.state.get("offer", []) as Array).is_empty() or int(g.state.get("cards_due", 0)) > 0


## A level-up: one more point for the run talent tree (the level itself counts it).
static func on_level_up(g: Node) -> void:
	if g.theme.get("cards", {}).is_empty():
		return
	g._toast("+1 Talentpunkt · %s öffnet die Lauf-Talente" % str(RunTree.settings().key))


## The run talent tree of this hero: the basics (class cards without a skill
## and the shared ones) and the carried relic's cards. A subclass keeps only the basics
## and the relic, as before (its own skills have no cards).
static func tree(g: Node) -> Dictionary:
	var cards := _all(g)
	var branches: Array = []
	var own_class: bool = g.sub_kit.is_empty()
	# No branch per class skill any more: the talent trees took keys 1-4
	# (user decision 29.10.2026), so the old skill upgrade cards are not offered.
	var basics := cards.filter(func(c: Dictionary) -> bool: return (str(c.set) == "all" or (own_class and str(c.set) == str(g.class_id))) and not c.has("skill"))
	branches.append({"key": "basis", "title": "GRUNDWERTE", "unlock": 1, "nodes": basics.map(_node.bind(g))})
	var relic := str(g.state.get("relic", ""))
	if relic != "":
		var held := cards.filter(func(c: Dictionary) -> bool: return str(c.set) == relic)
		branches.append({"key": relic, "title": str(g.theme.get(relic, {}).get("name", "RELIKT")), "unlock": 1, "nodes": held.map(_node.bind(g))})
	# No node waits for a lasting talent: the lasting talents of
	# docs/LAUF-DESIGN.de.md 3.3 are replaced by the shared talent profile
	# (docs/TALENTE-SEELENSPLITTER.de.md, decision 29.10.2026).
	return RunTree.build(branches)


## A tree node for card `c`. A heart card at the life cap (take_node refuses it)
## is closed with its reason (RunTree "closed": drawn locked, the reason shown).
static func _node(c: Dictionary, g: Node) -> Dictionary:
	var crypt := ClassPerks.find(str(g.class_id), str(c.id))
	var node := {"id": str(c.id), "name": str(c.name), "text": str(c.get("desc", "")), "max": int(c.max),
		"icon": SkillIcons.card(crypt if not crypt.is_empty() else {"id": str(c.id)}, str(g.class_id))}
	if c.has("hearts") and not Rules.heart_room(g.state, int(g.life_cap())):
		node.closed = "Leben am Höchstwert, mehr Herzen gehen nicht"
		node.closed_tag = "LEBEN VOLL"
	return node


## Ranks of the run tree's nodes: the cards taken in this run.
static func ranks(g: Node) -> Dictionary:
	return g.state.get("upgrades", {})


## Spends a point on card `id` when the tree allows it; true on success.
static func take_node(g: Node, id: String) -> bool:
	var t := tree(g)
	if not RunTree.can_take(t, ranks(g), int(g.state.level), id):
		g._sound("no_cooldown")
		return false
	for c: Dictionary in _all(g):
		if str(c.id) == id:
			# a heart card at the life cap would take the point for nothing
			if c.has("hearts") and not Rules.heart_room(g.state, int(g.life_cap())):
				g._sound("no_cooldown")
				g._toast("Mehr Herzen gehen nicht: das Leben ist am Höchstwert.")
				return false
			take(g, c)
			return true
	return false


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
	take(g, offer[i])
	g.state.offer = []
	g.state.cards_due = maxi(0, int(g.state.get("cards_due", 0)) - 1)
	if int(g.state.cards_due) > 0:
		offer(g)


## Takes card `c` once: counts it, adds its hearts, rings and notes it.
static func take(g: Node, c: Dictionary) -> void:
	var ups: Dictionary = g.state.get("upgrades", {})
	ups[str(c.id)] = level(g, str(c.id)) + 1
	g.state.upgrades = ups
	if c.has("hearts"):
		g.state.max_hp = Rules.raised_max_hp(g.state, int(c.hearts), int(g.life_cap()))
		g.state.hp = mini(int(g.state.max_hp), int(g.state.hp) + int(c.hearts))
	g._sound("level_up")
	g._toast("%s (Stufe %d)" % [c.name, level(g, str(c.id))])


# ---------- demon seals: two blessings, one safe price (balance package D1) ----------

## The seal values of this world's balance ("seal": offers, price_hp, arm_s:
## hell_balance.json and krypta_balance.json both name them); a world whose
## balance does not takes the hell's.
static func seal_cfg(g: Node) -> Dictionary:
	var cfg: Dictionary = g.balance.get("seal", {})
	if cfg.has("offers") and cfg.has("price_hp"):
		return cfg
	if _seal_defaults.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SEAL_DEFAULTS)) if FileAccess.file_exists(SEAL_DEFAULTS) else null
		_seal_defaults = (parsed as Dictionary).get("seal", {}) if parsed is Dictionary else {}
	var out: Dictionary = _seal_defaults.duplicate()
	for k: String in cfg:
		if not out.has(k): out[k] = cfg[k]
	return out


## True while a broken seal's blessings wait for a choice (the world waits too).
static func seal_open(g: Node) -> bool:
	return not (g.state.get("seal_pick", {}) as Dictionary).is_empty()


## Seal `e` broke: its blessings (Rules.seal_offer, drawn with `rng`, else from
## the global seed) and the price wait on cards (src/hell/frost_hud.gd
## seal_cards); hell_game.gd pauses the world until one is taken or both are left.
static func seal_offer(g: Node, e: Dictionary, rng: RandomNumberGenerator = null) -> void:
	var cfg := seal_cfg(g)
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.seed = randi()
	var ids := Rules.seal_offer(g.state, g.balance.blessings, int(cfg.get("offers", 2)), rng, int(g.life_cap()))
	if ids.is_empty():
		return
	# the cards say what taking each really gives: a dry run on a copy (a step shortened at its cap included)
	var texts: Array = []
	for id: Variant in ids:
		texts.append(Rules.apply_blessing(g.state.duplicate(true), str(id), g.balance.blessings, int(g.life_cap())))
	g.state.seal_pick = {"ids": ids, "texts": texts, "price": int(cfg.get("price_hp", 2)), "x": float(e.get("x", 0.0)), "y": float(e.get("y", 0.0)), "ms": Time.get_ticks_msec()}
	# nothing covers the cards: the map, the status sheet and the bag close
	g.state.map = false
	g.state.status = false
	var bag: Variant = g.get("inventory_panel")
	if bag != null and bool(bag.get("open")):
		bag.set_open(false)


## Takes the blessing on card `i` of the open seal: pays the price, applies it
## and lets it shine on the hero. False (a dull sound, a note) when he cannot pay.
static func seal_choose(g: Node, i: int) -> bool:
	var pick: Dictionary = g.state.get("seal_pick", {})
	var ids: Array = pick.get("ids", [])
	if i < 0 or i >= ids.size():
		return false
	var price := int(pick.get("price", 0))
	if not Rules.seal_affordable(g.state, price):
		g._sound("no_cooldown")
		g._toast("Zu wenig Leben für den Preis des Siegels.")
		return false
	var hero_at := Vector2(float(g.player.x), float(g.player.y))
	var text := Rules.take_seal_blessing(g.state, str(ids[i]), g.balance.blessings, int(g.life_cap()), price)
	g.state.seal_pick = {}
	# the blessing shines on the hero like the crypt's cleanse (gold motes, sheet, chime);
	# the price drips from him as a few drops of blood (src/hero/story_hero.gd matter)
	if g.get("feel") != null:
		g.feel.hero_event("cleanse")
	else:
		g._burst(hero_at - Vector2(0, 60), 50, true)
	if price > 0 and g.get("story_hero") != null:
		g.story_hero.matter("blood", hero_at - Vector2(0, 36), Vector2.DOWN, 4 + 2 * price)
	g._toast("Segen: %s · Preis: %s" % [text, Rules.price_text(price)])
	return true


## Leaves the open seal: no blessing, no price.
static func seal_leave(g: Node) -> void:
	if not seal_open(g):
		return
	g.state.seal_pick = {}
	g._toast("Die Segen bleiben ungenutzt.")


## True once the open seal's cards have been up for seal.arm_s (real time): a
## click or number key that was meant for the seal's last blow picks nothing.
static func seal_armed(g: Node) -> bool:
	var pick: Dictionary = g.state.get("seal_pick", {})
	var arm_ms := float(seal_cfg(g).get("arm_s", 0.0)) * 1000.0
	return float(Time.get_ticks_msec() - int(pick.get("ms", 0))) >= arm_ms


## Input while a seal's cards are open: 1 / 2 (or `pick`, the card under a
## click) takes that blessing once the cards are armed, Esc / E / Space leaves
## both at any time.
static func seal_input(g: Node, event: InputEvent, pick := -1) -> void:
	if pick >= 0:
		if seal_armed(g):
			seal_choose(g, pick)
		return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var key: int = event.keycode
	if key in [KEY_ESCAPE, KEY_E, KEY_SPACE, KEY_BACKSPACE]:
		seal_leave(g)
	elif not seal_armed(g):
		return
	elif key >= KEY_1 and key <= KEY_9:
		seal_choose(g, key - KEY_1)
	elif key >= KEY_KP_1 and key <= KEY_KP_9:
		seal_choose(g, key - KEY_KP_1)


# ---------- stat factors from the shared and class cards ----------

## Damage factor of the damage cards (+15 % each).
static func damage_mult(g: Node) -> float:
	var f := (1.0 + float(g.state.get("talent", {}).get("damage", 0.0))) * _items(g, "damage_mult")
	for id: String in ["sw_heavy", "mg_focus"]:
		f += float(value(g, id, "damage", 0.0)) * level(g, id)
	if str(g.state.get("relic", "")) == "shadow_dagger" and g.relic_on():
		f += float(value(g, "sharp_edge", "damage", 0.0)) * level(g, "sharp_edge")
	return f


## Attack pause factor of the rate cards (10 % faster each).
static func rate_mult(g: Node) -> float:
	var f := (1.0 - float(g.state.get("talent", {}).get("rate", 0.0))) * _items(g, "rate_mult")
	for id: String in ["sw_swift", "ar_rapid", "mg_haste"]:
		f *= pow(1.0 - float(value(g, id, "rate", 0.0)), level(g, id))
	return f


## Running speed factor (archer's light foot).
static func speed_mult(g: Node) -> float:
	return (1.0 + float(g.state.get("talent", {}).get("speed", 0.0)) + float(value(g, "ar_fleet", "speed", 0.0)) * level(g, "ar_fleet")) * _items(g, "speed_mult")


## A factor of the equipped items (src/hero/story_items.gd), 1 without them.
static func _items(g: Node, factor: String) -> float:
	var items: Variant = g.get("story_items")
	return float(items.call(factor)) if items != null else 1.0
