extends Node
## Item system 2 in the story worlds (src/hell/hell_game.gd: Hell-Dungeon and
## Frostgruft; docs/ITEM-SYSTEM-V2.de.md). The crypt's item rules run here
## unchanged (src/items/inventory.gd, item_rules.gd): this node stands in for
## the crypt game they expect. It keeps a "shadow" crypt hero that carries the
## bag and the four equipment slots, and translates what the rules do into the
## story world:
## - stats: the shadow hero's damage, attack pause and speed against a clean
##   one of the same class become factors on the world's own values; extra HP
##   from gear raise the hearts; the stage, curses and blessings count too;
## - weapon effects on hits: burning (cinder), poison (venom), slow (frost),
##   critical hits (crit), healing kills (vampire); a sealed skill, heavier
##   hits (fragile) and a dim light (night);
## - potions: healing, timed strength / haste / regeneration and the bad ones
##   on the hero; thrown potions hurt, burn, freeze or daze monsters; thrown
##   good ones also reach the clone and the companions (bless_allies); a drunk
##   harmful one leaves an after-effect (immune: no harm from its element for a
##   while, read by hell_game.gd; lose_track: monsters lose the hero's track);
## - curse damage (blood toll, thorns) always leaves the hero 1 LP;
## - the clone seal calls the world's own clone for its time;
## - finds: chests, the vault, broken seals, guardians and mini guardians roll
##   loot (the first chest of a floor holds its fixed finds); finds go into the
##   bag, or wait on the floor when it is full and are picked up on contact.
## Saved with the run (state.items). Presentation of the bag: the shared
## inventory window (src/ui/inventory_panel.gd), key I.

const Inventory = preload("res://src/items/inventory.gd")
const ItemRules = preload("res://src/items/item_rules.gd")
const PerkRules = preload("res://src/perk_rules.gd")
const HeroClass = preload("res://src/player/hero_class.gd")
const ArmorPowers = preload("res://src/hero/armor_powers.gd")
const RewardRules = preload("res://src/progress/reward_rules.gd")
const TalentBar = preload("res://src/ui/talent_bar.gd")
const BALANCE_PATH := "res://src/data/balance.json"
## Effect strengths in the story worlds (shares of the world's own values).
const EFFECTS := {"burn_dps": 0.6, "burn_time": 3.0, "slow": 0.35, "slow_time": 2.5, "crit_mult": 2.0}

var g: Node
## The crypt balance the item rules read (classes, perks, perk rules).
var balance: Dictionary = {}
## The crypt hero standing in for the story hero (id 1).
var players: Dictionary = {}
var inventory := Inventory.new()
## The world's "objects" the rules call into are this node.
var chests: Node = self
var boss_moves: Node = self
var perk_combat: Node = self
var player_effects: Node = self
## Items waiting on the floor (bag full): {item, p (world px)}.
var floor_items: Array = []
## Thrown pools that hurt monsters: {p, r, t, dps, status}.
var pools: Array = []
## Timed effects on the hero: kind -> {t, value, tick}.
var effects: Dictionary = {}
var _clean: Dictionary = {}
## The story hero's life when it went into the shadow hero (_sync_in), to pass on only the rules' own change.
var _hp_in := 0
var _kills := 0
## True while an aftershock or chain lightning deals its follow-up hits: those hits do not start
## a new aftershock or chain (two monsters side by side bounced them back and forth forever).
var _proc := false
var _first_chest_floor := -1
var _scale := 2.4


## Finds on the floor and thrown pools have their own layer, under the figures.
class FloorLayer extends Node2D:
	var items: Node
	func _draw() -> void:
		items.draw(self, float(items.g.state.get("t", 0.0)))


var _layer: FloorLayer
## Item sprites held while they are drawn (a texture loaded and dropped inside
## _draw is freed before the frame renders and shows white).
var _textures: Dictionary = {}
## The worn armour's ability on key F and the passives the rules do not know
## (src/hero/armor_powers.gd, assets/data/armor_powers.json).
var powers: RefCounted


func _init(game: Node) -> void:
	g = game
	name = "StoryItems"
	_layer = FloorLayer.new()
	_layer.items = self
	_layer.z_index = 9
	g.add_child.call_deferred(_layer)
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(BALANCE_PATH))
	balance = parsed if parsed is Dictionary else {}
	_scale = float(g.theme.get("leveling", {}).get("scale", 2.4))
	inventory.bind(self)
	powers = ArmorPowers.new(g, self)


## A new run, or the run a save brings back (state.items).
func start(run_seed: int) -> void:
	var saved: Dictionary = g.state.get("items", {})
	_clean = _hero()
	players = {1: _hero()}
	if saved.is_empty():
		inventory.new_run(run_seed)
		inventory.start_kit(players[1])
	else:
		inventory.new_run(int(saved.get("seed", run_seed)))
		inventory.colors = saved.get("colors", inventory.colors).duplicate(true)
		inventory.known = saved.get("known", {}).duplicate(true)
		inventory._next_uid = int(saved.get("next_uid", 1))
		players[1].inventory = saved.get("inventory", {}).duplicate(true)
		players[1].augments = saved.get("augments", {}).duplicate(true)
		inventory.equip_apply(players[1])
	powers.rng.seed = run_seed + 17
	_store(run_seed)
	_apply_stats()


## A clean crypt hero of the story hero's class (start values, no items).
func _hero() -> Dictionary:
	var hero := {"pos": Vector2.ZERO, "hp": 6, "max_hp": 6, "perks": [], "damage": float(balance.get("player", {}).get("damage", 1.0)),
		"speed": float(balance.get("player", {}).get("speed", 190.0)), "shot_interval": float(balance.get("player", {}).get("shot_interval", 0.4)),
		"aim": Vector2.RIGHT, "effects": {}}
	PerkRules.initialize_player(hero, balance)
	HeroClass.apply(hero, str(g.class_id), balance)
	inventory.start_kit(hero)
	return hero


## The bag and the potion knowledge into the run state (carried and saved).
func _store(run_seed: int = -1) -> void:
	var hero: Dictionary = players.get(1, {})
	if hero.is_empty(): return
	var old: Dictionary = g.state.get("items", {})
	g.state.items = {"inventory": hero.inventory.duplicate(true), "augments": hero.get("augments", {}).duplicate(true),
		"colors": inventory.colors.duplicate(true), "known": inventory.known.duplicate(true), "next_uid": inventory._next_uid,
		"seed": run_seed if run_seed >= 0 else int(old.get("seed", 0)), "hp_bonus": int(old.get("hp_bonus", 0))}


# --- what the items do to the story hero --------------------------------------------

## Damage factor of the equipped pieces and running potions.
func damage_mult() -> float:
	var hero: Dictionary = players.get(1, {})
	if hero.is_empty(): return 1.0
	var f := float(hero.damage) / maxf(0.01, float(_clean.damage))
	if effects.has("strength"): f *= float(effects.strength.value)
	if effects.has("weak"): f *= float(effects.weak.value)
	return f


## Attack pause factor (below 1 attacks faster).
func rate_mult() -> float:
	var hero: Dictionary = players.get(1, {})
	if hero.is_empty(): return 1.0
	# a running Blutzorn (armor_powers.gd rate_factor) swings faster still
	var f := float(hero.shot_interval) / maxf(0.01, float(_clean.shot_interval)) * float(powers.rate_factor())
	# a haste potion also shortens the attack pause (items.json potions.haste.rate)
	if effects.has("haste"): f *= float(_potion("haste").get("rate", 1.0))
	return f


## Running speed factor.
func speed_mult() -> float:
	var hero: Dictionary = players.get(1, {})
	if hero.is_empty(): return 1.0
	var f := float(hero.speed) / maxf(1.0, float(_clean.speed))
	if effects.has("haste"): f *= float(effects.haste.value)
	if effects.has("slow"): f *= float(effects.slow.value)
	return f


## Skill cooldown factor (rings, cloaks, blessings).
func cooldown_scale() -> float:
	return float(players.get(1, {}).get("cooldown_scale", 1.0))


## Extra half hearts every hit costs (the fragile curse).
func extra_damage() -> int:
	return int(players.get(1, {}).get("item_extra_damage", 0))


## True when the skill on \`key\` is sealed by a curse (1..4).
func sealed(key: String) -> bool:
	var hero: Dictionary = players.get(1, {})
	return hero.has("sealed_skill") and str(int(hero.sealed_skill) + 1) == key


## True when a curse or a potion dims the hero's light.
func dim() -> bool:
	return bool(players.get(1, {}).get("dim", false)) or effects.has("blind")


## After every change of the equipment: hearts and the weapon's look follow.
func _apply_stats() -> void:
	var hero: Dictionary = players[1]
	var bonus := int(hero.max_hp) - int(_clean.max_hp)
	var before := int(g.state.items.get("hp_bonus", 0))
	if bonus != before:
		g.state.max_hp = maxi(2, int(g.state.max_hp) + bonus - before)
		g.state.hp = clampi(int(g.state.hp) + maxi(0, bonus - before), 1, int(g.state.max_hp))
		g.state.items.hp_bonus = bonus
	var spec := ItemRules.weapon(str(hero.inventory.weapon.get("id", "")))
	if not spec.is_empty() and not bool(spec.get("start", false)):
		var path := "res://assets/sprites/" + str(spec.sprite) + ".png"
		if ResourceLoader.exists(path) and not g.relic_on(): g.weapon_tex = load(path)
		# its glow (own, else its element's) and its element: the held weapon shows them (hero_look.gd)
		g.state.glow = ItemRules.glow_of(spec)
		g.state.weapon_element = ItemRules.element_of(spec)
	elif not spec.is_empty():
		g.state.glow = ""
		g.state.weapon_element = ItemRules.element_of(spec)
	# the worn armour's power takes key F (none: the F slot goes)
	powers.wear(hero.inventory.get("armor", {}))


# --- the item window (I) ------------------------------------------------------------

## The bag as the inventory window shows it.
func view() -> Dictionary:
	var hero: Dictionary = players.get(1, {})
	if hero.is_empty(): return {}
	var snap: Dictionary = inventory.snapshot(hero)
	# power armour: the class lock, its passives and its F ability (armor_powers.gd describe)
	var names := class_names()
	var cid := str(g.class_id)
	ArmorPowers.describe(snap.get("armor", {}), hero.inventory.get("armor", {}), cid, names)
	var bag: Array = snap.get("bag", [])
	for i in range(mini(bag.size(), (hero.inventory.bag as Array).size())):
		ArmorPowers.describe(bag[i], hero.inventory.bag[i], cid, names)
	return snap


## Class id -> its shown name (balance classes), for the class lock.
func class_names() -> Dictionary:
	var out: Dictionary = {}
	for key: String in balance.get("classes", {}):
		out[key] = str(balance.classes[key].get("name", key))
	return out


## An action from the window: equip, identify, use, throw (at \`target\`, world px) ...
func act(action: String, value: int, target: Vector2 = Vector2.INF) -> void:
	var hero: Dictionary = players[1]
	# a piece bound to another class stays in the bag ("Nur für Magier.")
	if action == "inv_equip" and value >= 0 and value < (hero.inventory.bag as Array).size():
		var why := ArmorPowers.equip_block(hero.inventory.bag[value], str(g.class_id), class_names())
		if not why.is_empty():
			inventory.note(hero, why)
			return
	_sync_in()
	var aim: Vector2 = g.HeroKit._aim(g)
	hero.aim = aim
	inventory.act(1, action, value, target / _scale if target.is_finite() else Vector2.INF)
	_sync_out()
	_apply_stats()
	_store()


## The hero's place and hearts into the shadow hero.
func _sync_in() -> void:
	var hero: Dictionary = players[1]
	hero.pos = Vector2(float(g.player.x), float(g.player.y) - 20.0) / _scale
	hero.hp = int(g.state.hp)
	hero.max_hp = maxi(int(hero.max_hp), int(g.state.max_hp))
	_hp_in = int(hero.hp)


## Healing and harm back into the story hero: only what the item rules changed on the
## shadow hero (a drunk healing potion) is added. Harm the world dealt meanwhile through
## g._hurt (a burning or poisoned drinker, the blasting potion, curses) or healing it gave
## (regeneration ticks) stays; writing the shadow's old value back used to undo it.
func _sync_out() -> void:
	var hero: Dictionary = players[1]
	var change := int(hero.hp) - _hp_in
	if change != 0:
		g.state.hp = clampi(int(g.state.hp) + change, 0, int(g.state.max_hp))
	hero.hp = int(g.state.hp)
	_hp_in = int(hero.hp)
	inventory.equip_apply(hero)


# --- finds --------------------------------------------------------------------------

## A source drops its loot (chest, crate, gold_crate, mimic) at world point \`at\`;
## the first chest of a floor adds the floor's fixed finds.
func loot(source: String, at: Vector2) -> void:
	var items: Array = inventory.roll(source, int(g.state.floor), str(g.class_id))
	if source == "chest" and _first_chest_floor != int(g.state.floor):
		_first_chest_floor = int(g.state.floor)
		items.append_array(inventory.floor_finds(int(g.state.floor)))
	_weigh_armor(items)
	if powers.rng.randf() < float(ArmorPowers.data().get("drops", {}).get(source, 0.0)):
		var extra := _power_armor()
		if not extra.is_empty(): items.append(extra)
	for item: Dictionary in items: give(item, at)


## Power armours of another class among `items` turn into one of the hero's
## class with the share armor_powers.json drops.own_class.
func _weigh_armor(items: Array) -> void:
	var cid := str(g.class_id)
	var own := ArmorPowers.armor_ids(cid)
	if own.is_empty(): return
	for item: Dictionary in items:
		if ArmorPowers.power_of(item).is_empty() or ArmorPowers.class_of(item) == cid: continue
		if powers.rng.randf() < float(ArmorPowers.data().get("drops", {}).get("own_class", 0.8)):
			# the same rarity: an epic find never turns into a legendary armour of the class
			var same := own.filter(func(id: String) -> bool: return str(ItemRules.gear(id).get("rarity", "")) == str(ItemRules.gear(str(item.id)).get("rarity", "")))
			if not same.is_empty(): item.id = str(same[powers.rng.randi_range(0, same.size() - 1)])


## A found power armour (class-weighted, unknown, sometimes cursed); {} when there are none.
func _power_armor() -> Dictionary:
	var id := ArmorPowers.pick_armor(str(g.class_id), powers.rng, RewardRules.armor_power_rarity())
	if id.is_empty(): return {}
	var curse := ""
	if powers.rng.randf() < float(ArmorPowers.data().get("drops", {}).get("curse_chance", 0.2)):
		var curses: Array = inventory.data.get("curses", {}).keys()
		curses.erase("burning_blade")
		if not curses.is_empty(): curse = str(curses[powers.rng.randi_range(0, curses.size() - 1)])
	return inventory.make_gear(id, false, curse)


## Debug and tools (story Testraum): power armour `id` known, clean, stage 0,
## into the bag (or onto the floor when it is full). False for an unknown id.
func give_armor(id: String) -> bool:
	if ItemRules.gear(id).is_empty(): return false
	give(inventory.make_gear(id, true, "", 0), Vector2(float(g.player.x), float(g.player.y) + 30.0))
	inventory.note(players[1], ArmorPowers.text("given", "%s ins Inventar") % str(ItemRules.gear(id).get("name", id)))
	return true


## Key F: the worn armour's power at world point `target` (the mouse). False
## when none is worn or it still cools down.
func press_power(target: Vector2 = Vector2.INF) -> bool:
	return powers != null and powers.press(target)


## The skill bar's F slot while a power armour is worn ([] otherwise).
func power_slots() -> Array:
	var v: Dictionary = powers.slot_view() if powers != null else {}
	return [] if v.is_empty() else [TalentBar.power_slot(v)]


## A guardian's piece (docs/BEUTEORDNUNG.de.md section 5): rare or better, epic from floor epic_from on
## (mini guardians mini_epic_from), never legendary; a power armour on the side is epic.
func guardian_drop(at: Vector2, mini := true) -> void:
	var spec := RewardRules.special("guardian")
	var floor_number := int(g.state.floor)
	var epic_from := int(spec.get("mini_epic_from" if mini else "epic_from", 99))
	var minimum := "epic" if floor_number >= epic_from else str(spec.get("min_rarity", "rare"))
	var items: Array = [inventory.reward_piece(int(g.call("depth")) if g.has_method("depth") else floor_number, str(g.class_id), minimum, false, false)]
	_weigh_armor(items)
	if powers.rng.randf() < float(ArmorPowers.data().get("drops", {}).get("boss", 0.0)):
		var extra := _power_armor()
		if not extra.is_empty(): items.append(extra)
	for item: Dictionary in items: give(item, at)


## The final guardian's one legendary piece (weapon, armour, ring or amulet of the hero's class, clean).
func final_drop(at: Vector2) -> void:
	var item := inventory.legendary_piece(str(g.class_id), 0.0)
	if not item.is_empty(): give(item, at)


## A piece of a reward chest at `at`: at least `minimum`, of the hero's class with `own`, clean with `clean`;
## with chance `legendary_p` it turns legendary instead (clean when `sure`, else cursed with a chance of the
## Beuteordnung's curse range). Returns the rarity given.
func reward_item(at: Vector2, minimum: String, own: bool, clean: bool, legendary_p := 0.0, sure := false) -> String:
	var t := int(g.call("depth")) if g.has_method("depth") else int(g.state.floor)
	if legendary_p > 0.0 and inventory.roll01() < legendary_p:
		var leg := inventory.legendary_piece(str(g.class_id), 0.0 if sure else RewardRules.legendary_curse_chance(inventory.roll01()))
		if not leg.is_empty():
			give(leg, at)
			return "legendary"
	var item := inventory.reward_piece(t, str(g.class_id), minimum, own, clean)
	if item.is_empty(): return ""
	give(item, at)
	return str(ItemRules.weapon(str(item.id)).get("rarity", ItemRules.gear(str(item.id)).get("rarity", ""))) if item.type == "weapon" else str(ItemRules.gear(str(item.id)).get("rarity", ""))


## A consumable of the chest (crystal, stone, upgrade_stone, dice_stone; crystal_or_stone picks one).
func reward_stack(at: Vector2, kind: String) -> void:
	var pick := kind
	if kind == "crystal_or_stone": pick = "crystal" if inventory.roll01() < 0.5 else "stone"
	give(inventory.make_stack(pick), at)


## Into the bag, or onto the floor when it is full.
func give(item: Dictionary, at: Vector2) -> void:
	var hero: Dictionary = players[1]
	if hero.inventory.bag.size() < int(inventory.data.get("bag", 12)) or str(item.type) not in ["weapon", "gear"] and hero.inventory.bag.any(func(h: Dictionary) -> bool: return str(h.type) == str(item.type) and str(h.get("potion", "")) == str(item.get("potion", ""))):
		inventory.add(hero, item)
	else:
		floor_items.append({"item": item, "p": at, "born": float(g.state.get("t", 0.0))})
		inventory.note(hero, "Inventar voll: %s liegt am Boden." % inventory.name_of(item))
	_store()


# --- per frame ----------------------------------------------------------------------

## Effects run out, potions tick, pools burn, curses act, floor items are
## picked up on contact. Item notes are shown by the inventory window alone,
## as in the crypt.
func update(dt: float) -> void:
	var hero: Dictionary = players.get(1, {})
	if hero.is_empty(): return
	_sync_in()
	inventory.step(dt)
	for kind: String in effects.keys():
		var e: Dictionary = effects[kind]
		e.t = float(e.t) - dt
		if kind in ["regen", "burn", "poison"]:
			e.tick = float(e.get("tick", 0.0)) - dt
			if float(e.tick) <= 0.0:
				e.tick = float(e.get("every", 1.0))
				if kind == "regen": g.state.hp = mini(int(g.state.max_hp), int(g.state.hp) + 1)
				else: g._hurt("vom Trank verbrannt" if kind == "burn" else "vom Trank vergiftet")
		if float(e.t) <= 0.0: effects.erase(kind)
	_guard_immune()
	_step_allies(dt)
	for pool: Dictionary in pools:
		pool.t = float(pool.t) - dt
		pool.tick = float(pool.get("tick", 0.0)) - dt
		if float(pool.tick) <= 0.0:
			pool.tick = 0.5
			for m: Dictionary in g.mobs:
				if g._hittable(m) and (m.p as Vector2).distance_to(pool.p) < float(pool.r) + float(m.r):
					g._damage_mob(m, Vector2.ZERO, float(pool.dps) * 0.5 / maxf(0.01, float(_clean.damage)))
					if str(pool.status) == "burn": g.HeroKit.burn_mob(m, float(EFFECTS.burn_dps), float(EFFECTS.burn_time))
	pools = pools.filter(func(p: Dictionary) -> bool: return float(p.t) > 0.0)
	var me := Vector2(float(g.player.x), float(g.player.y))
	for drop: Dictionary in floor_items.duplicate():
		if (drop.p as Vector2).distance_to(me) < 70.0 and hero.inventory.bag.size() < int(inventory.data.get("bag", 12)):
			floor_items.erase(drop)
			inventory.add(hero, drop.item)
			# effect hook: the crypt's pickup (loot_taken: its sheet and chime)
			if g.get("feel") != null: g.feel.fx_event("loot_taken", drop.p)
			_store()
	powers.update(dt)
	_layer.queue_redraw()
	_sync_out()


## A hero hit on monster \`m\`: the equipped pieces' effects (burn, poison,
## slow, critical, healing kills).
func on_hit(m: Dictionary) -> void:
	if powers != null and not m.has("kit"): powers.on_hit(m)
	var build: Dictionary = players.get(1, {}).get("build", {})
	if build.is_empty() or m.has("kit"): return
	# a fire weapon sets it alight (fire_t: the burning look, wet blocks it), a poison weapon
	# poisons it (poison_mob: its own damage over time, wet does not stop it) — each its element
	if float(build.get("cinder", 0.0)) > 0.0:
		g.HeroKit.burn_mob(m, float(EFFECTS.burn_dps) * (1.0 + float(build.get("cinder", 0.0))), float(EFFECTS.burn_time))
		if float(m.get("wet_t", 0.0)) <= 0.0:
			m.fire_t = maxf(float(m.get("fire_t", 0.0)), float(EFFECTS.burn_time))
	if float(build.get("venom", 0.0)) > 0.0:
		g.HeroKit.poison_mob(m, float(EFFECTS.burn_dps) * (1.0 + float(build.get("venom", 0.0))), float(EFFECTS.burn_time))
	if float(build.get("frost", 0.0)) > 0.0:
		g.HeroKit.slow_mob(g, m, minf(0.6, float(build.frost) + float(EFFECTS.slow) * 0.5), float(EFFECTS.slow_time))
	# run potions: hits shake the ground nearby (aftershock) or jump on as lightning (chain);
	# their own follow-up hits start no new aftershock or chain
	if _proc:
		return
	_proc = true
	if float(build.get("blast", 0.0)) > 0.0:
		# effect hook: the crypt's area perk where the ground shakes (perk_events blast)
		if g.get("feel") != null: g.feel.mob_perk("blast", m)
		for other: Dictionary in g.mobs.duplicate():
			if not is_same(other, m) and g._hittable(other) and (other.p as Vector2).distance_to(m.p) < 70.0 * _scale:
				g._damage_mob(other, Vector2.ZERO, float(build.blast) * 0.5)
	if float(build.get("storm", 0.0)) > 0.0:
		var next: Dictionary = {}
		var near := 160.0 * _scale
		for other: Dictionary in g.mobs:
			var gap: float = (other.p as Vector2).distance_to(m.p)
			if not is_same(other, m) and g._hittable(other) and gap < near:
				near = gap
				next = other
		if not next.is_empty():
			g.fx.append({"kind": "bolt", "p": (m.p as Vector2) - Vector2(0, float(m.cy)), "q": (next.p as Vector2) - Vector2(0, float(next.cy)), "t": 0.25, "max": 0.25})
			g._damage_mob(next, Vector2.ZERO, float(build.storm))
	_proc = false
	if float(m.hp) <= 0.0 and float(build.get("vampire", 0.0)) > 0.0:
		_kills += 1
		if _kills % maxi(1, int(build.vampire)) == 0:
			var before := int(g.state.hp)
			g.state.hp = mini(int(g.state.max_hp), int(g.state.hp) + 1)
			# effect hook: the crypt's heal marker (perk_combat.gd _heal: only when it heals)
			if int(g.state.hp) > before and g.get("feel") != null: g.feel.hero_perk("heal")


## The shield potion's charges: true when one stops this hit.
## Also the worn armour: a running Schildwall (a blow from the front, `from`:
## where it came from, ZERO when unknown), a Eispanzer charge, or the armour's
## own chance to shrug a hit off (armor_powers.gd absorb).
func consume_shield(from := Vector2.ZERO) -> bool:
	if powers != null and powers.absorb(from): return true
	var runtime: Dictionary = players.get(1, {}).get("perk_runtime", {})
	if int(runtime.get("shield", 0)) <= 0: return false
	runtime.shield = int(runtime.shield) - 1
	# effect hook: with the feel the crypt's shield marker (perk_combat.gd _absorb)
	if g.get("feel") != null: g.feel.hero_perk("shield")
	else: g._burst(Vector2(float(g.player.x), float(g.player.y) - 40.0), 16, true)
	return true


## Thrown blinding potion: the monster reels for a while.
func daze(enemy: Dictionary, time: float) -> void:
	_status(enemy, "daze", 1, time, 1)


## Critical hit factor from the pieces' crit chance.
func crit_mult() -> float:
	var chance := float(players.get(1, {}).get("build", {}).get("crit", 0.0))
	return float(EFFECTS.crit_mult) if chance > 0.0 and randf() < chance else 1.0


# --- the crypt game the item rules call into ----------------------------------------

## Monsters as the rules see them (crypt units; \`ref\` is the world's monster).
var enemies: Array:
	get:
		var out: Array = []
		for m: Dictionary in g.mobs:
			if g._hittable(m):
				out.append({"pos": ((m.p as Vector2) - Vector2(0, float(m.cy))) / _scale, "hp": float(m.hp), "radius": float(m.r) / _scale,
					"boss": m.kind == "boss", "miniboss": false, "ref": m})
		return out


## The rules' item effects (inventory.gd add_fx: potion_throw, potion_blast, drink,
## curse, cleanse, identify). With the feel they are the crypt's own fx events
## (feedback.gd: the potion's colour, its splash, the sound; src/hero/story_feel.gd)
## at the world point, radius in the feel's crypt units.
func add_fx(kind: String, at: Vector2, radius: float, _extra: Dictionary = {}) -> void:
	var p := at * _scale
	var feel: RefCounted = g.get("feel")
	if feel != null:
		var extra := _extra.duplicate()
		extra.r = radius * _scale / float(feel.scale)
		feel.fx_event(kind, p, extra)
		return
	match kind:
		"potion_blast", "potion_throw": g.fx.append({"kind": "blast", "p": p, "r": radius * _scale, "t": 0.3, "max": 0.3, "gravity": false})
		"curse": g._burst(p, 20)
		_: g._burst(p, 12, true)


func _damage_player(_id: int, amount: int, _direction: Vector2) -> void:
	g.state.inv = 0.0
	g._hurt("vom Sprengtrank zerrissen", amount)


## The blood toll: never lethal, it always leaves 1 LP (gameplay review R6). It
## takes its LP straight (g.dot_hurt), so no talent, difficulty or fragile curse
## can push it past that last LP, and no shield charge is spent on it.
func dot_player(_id: int, amount: int, _kind: String) -> void:
	var n := _curse_cap(amount)
	if n > 0: g.dot_hurt(n, "vom Blutzoll ausgezehrt")


## What a curse may still take: at most the life above 1 LP.
func _curse_cap(amount: int) -> int:
	return mini(amount, int(g.state.hp) - 1)


func _damage_enemy(enemy: Dictionary, damage: float, direction: Vector2, _owner: int) -> float:
	var m: Dictionary = enemy.get("ref", {})
	if m.is_empty(): return 0.0
	g._damage_mob(m, direction * 300.0, damage / maxf(0.01, float(_clean.damage)))
	return damage


## Timed effects of potions on the hero (strength, haste, regeneration, burn, slow ...).
func apply(_player: Dictionary, kind: String, time: float, value: float) -> void:
	match kind:
		"regen": effects.regen = {"t": time, "every": value, "tick": value}
		# 1 LP every items.json potions.fire / poison "tick" s
		"burn", "poison":
			var tick := maxf(0.1, float(_potion("fire" if kind == "burn" else "poison").get("tick", 1.5)))
			effects[kind] = {"t": time, "every": tick, "tick": tick}
		# a thrown (weaker) strength or haste does not replace a stronger running one
		"strength", "haste":
			var cur: Dictionary = effects.get(kind, {})
			if cur.is_empty() or value > float(cur.value) + 0.001 or (absf(value - float(cur.value)) <= 0.001 and time > float(cur.t)):
				effects[kind] = {"t": time, "value": value}
		_: effects[kind] = {"t": time, "value": value}


## The potion rules of `kind` (items.json potions).
func _potion(kind: String) -> Dictionary:
	return inventory.data.get("potions", {}).get(kind, {})


## A drunk harmful potion's after-effect (inventory.gd _drink): `elements` (fire,
## ice, poison) cannot harm the hero for `time` s, starting in `delay` s (when the
## potion's own harm is over). Kept as effects immune_<element> = {t: delay + time,
## on: time}, counted down with the others: active while t <= on.
func immunity(elements: Array, time: float, delay: float) -> void:
	for element: Variant in elements:
		var key := "immune_" + str(element)
		var cur: Dictionary = effects.get(key, {})
		var total := delay + time
		# a running immunity is only lengthened, never paused
		if not cur.is_empty() and float(cur.t) <= float(cur.on):
			effects[key] = {"t": maxf(float(cur.t), total), "on": maxf(float(cur.t), total)}
		else:
			effects[key] = {"t": total, "on": time}


## True while a potion's after-effect keeps `what` (a condition, a pool style or a
## gas material: "burn", "lava", "poison", "freeze" ...) off the hero: items.json
## immunity lists the words each element covers. Read by src/hell/hell_game.gd for
## the lava floor, pools, gas and the conditions they put on.
func immune(what: String) -> bool:
	var word := what.to_lower()
	if word.is_empty(): return false
	var table: Dictionary = inventory.data.get("immunity", {})
	for element: String in table:
		var e: Dictionary = effects.get("immune_" + element, {})
		if e.is_empty() or float(e.t) > float(e.on): continue
		for key: Variant in table[element]:
			if word.contains(str(key)): return true
	return false


## An immune hero shakes off what any source put on him meanwhile: the conditions
## of src/hell/hero_fx.gd (state.effects), the Frostgruft's chill and a potion's own
## burn or poison (the ice potion puts out a drunk fire potion's burn at once).
func _guard_immune() -> void:
	var held: Variant = g.state.get("effects")
	var fx: Dictionary = held if held is Dictionary else {}
	if immune("burn"):
		fx.erase("burn")
		effects.erase("burn")
		if g.state.has("burn"): g.state.burn = 0.0
	if immune("poison"):
		fx.erase("poison")
		effects.erase("poison")
	if immune("freeze"):
		fx.erase("freeze")
		fx.erase("slow")
		if g.state.has("chill"): g.state.chill = 0.0


## A drunk blinding potion: monsters near the hero lose his track and stand for
## items.json blind.lost s, bosses for boss_share of it (like the shadow leap,
## armor_powers.gd: stun plus the _lost_t mark).
func lose_track(_player: Dictionary, spec: Dictionary) -> void:
	var me := Vector2(float(g.player.x), float(g.player.y))
	var lost := float(spec.get("lost", 3.0))
	for m: Dictionary in g.mobs:
		if not g._hittable(m) or m.has("kit") or (m.p as Vector2).distance_to(me) > float(spec.get("lost_radius", 460.0)): continue
		var t := lost * (float(spec.get("boss_share", 0.5)) if str(m.get("kind", "")) == "boss" else 1.0)
		m.stun = maxf(float(m.get("stun", 0.0)), t)
		m["_lost_t"] = t


## Timed potion buffs on allies: {who, kind, t, value, every, tick}; one per ally and
## kind, a new throw renews the time. "dmg", "speed", "every" scale that field of a
## companion and set it back at the end; "regen" heals a share of its life per tick;
## "clone_haste" shortens the clone's shot pause.
var ally_buffs: Array = []


## A thrown good potion on the allies in its radius besides the heroes (inventory.gd
## _throw; crypt point and radius): the companions of the talents (talent_combat.gd
## pets of hero 1, world px) and the world's clone. The clone has no life and shoots
## with the hero's damage (a hero in the radius takes his strength along), so of the
## potions only haste reaches it. Companions: healing gives throw_ally_heal of their
## life, regeneration throw_ally_regen per tick, strength their bite (dmg), haste
## their pace (speed) and bite pause (every, haste.rate), shield charges that give
## back the next loss of life.
func bless_allies(kind: String, spec: Dictionary, point: Vector2, radius: float) -> void:
	var at := point * _scale
	var reach := radius * _scale
	var clone: Variant = g.get("clone")
	if kind == "haste" and clone is Dictionary and (clone as Dictionary).has("p") and ((clone as Dictionary).p as Vector2).distance_to(at) <= reach:
		_buff(clone, "clone_haste", float(spec.get("throw_time", 10)), float(spec.get("rate", 1.0)))
	for pet: Dictionary in _companions():
		if (pet.pos as Vector2).distance_to(at) > reach: continue
		match kind:
			"healing": _heal_pet(pet, float(pet.get("hp_max", 1.0)) * float(spec.get("throw_ally_heal", 0.2)))
			"regeneration": _buff(pet, "regen", float(spec.get("time", 18)), float(spec.get("throw_ally_regen", 0.05)), float(spec.get("every", 3)))
			"strength": _buff(pet, "dmg", float(spec.get("throw_time", 12)), float(spec.get("throw_value", 1.25)))
			"haste":
				_buff(pet, "speed", float(spec.get("throw_time", 10)), float(spec.get("throw_value", 1.25)))
				_buff(pet, "every", float(spec.get("throw_time", 10)), float(spec.get("rate", 1.0)))
			"shield":
				pet.potion_shield = mini(int(spec.get("max_charges", 99)), int(pet.get("potion_shield", 0)) + int(spec.get("throw_charges", 1)))
				pet.potion_hp = float(pet.hp)


## Hero 1's companions that still stand ([] in a world without talents).
func _companions() -> Array:
	var talents: Variant = g.get("talents")
	if talents == null: return []
	var tc: Variant = talents.get("tc")
	if tc == null: return []
	return (tc.pets as Array).filter(func(p: Dictionary) -> bool: return int(p.get("owner", 0)) == 1 and not p.has("dying") and float(p.get("hp", 0.0)) > 0.0)


## Heals a companion through the talents (its rig parts share the life).
func _heal_pet(pet: Dictionary, amount: float) -> void:
	var talents: Variant = g.get("talents")
	var tc: Variant = talents.get("tc") if talents != null else null
	if tc != null and tc.has_method("_heal_pet"): tc._heal_pet(pet, amount)
	else: pet.hp = minf(float(pet.get("hp_max", pet.hp)), float(pet.hp) + amount)


func _buff(who: Dictionary, kind: String, time: float, value: float, every := 0.0) -> void:
	for b: Dictionary in ally_buffs:
		if is_same(b.who, who) and str(b.kind) == kind:
			b.t = maxf(float(b.t), time)
			return
	if kind in ["dmg", "speed", "every"]: who[kind] = float(who.get(kind, 1.0)) * value
	ally_buffs.append({"who": who, "kind": kind, "t": time, "value": value, "every": every, "tick": every})


## The allies' potion buffs run out, regeneration ticks, the clone shoots faster,
## a companion's shield charge gives back what a hit took.
func _step_allies(dt: float) -> void:
	for b: Dictionary in ally_buffs:
		b.t = float(b.t) - dt
		var who: Dictionary = b.who
		match str(b.kind):
			"regen":
				b.tick = float(b.tick) - dt
				if float(b.tick) <= 0.0:
					b.tick = float(b.every)
					if float(who.get("hp", 0.0)) > 0.0 and not who.has("dying"): _heal_pet(who, float(who.get("hp_max", 1.0)) * float(b.value))
			# hell_game.gd _update_clone counts its cool down: it counts faster
			"clone_haste":
				if who.has("cool"): who.cool = float(who.cool) - dt * (1.0 / maxf(0.1, float(b.value)) - 1.0)
		if float(b.t) <= 0.0 and str(b.kind) in ["dmg", "speed", "every"]:
			who[str(b.kind)] = float(who.get(str(b.kind), 1.0)) / maxf(0.001, float(b.value))
	ally_buffs = ally_buffs.filter(func(b: Dictionary) -> bool: return float(b.t) > 0.0)
	for pet: Dictionary in _companions():
		if int(pet.get("potion_shield", 0)) <= 0: continue
		var was := float(pet.get("potion_hp", pet.hp))
		if float(pet.hp) < was - 0.001:
			_heal_pet(pet, was - float(pet.hp))
			pet.potion_shield = int(pet.potion_shield) - 1
		pet.potion_hp = float(pet.hp)


## A thrown fire or poison pool that hurts monsters for a while.
func hero_pool(at: Vector2, spec: Dictionary, _owner: int) -> void:
	# style and max: the crypt's pool look (boss_fx.gd through src/hero/story_feel.gd)
	var pool := {"p": at * _scale, "r": float(spec.get("radius", 60)) * _scale, "t": float(spec.get("time", 5)), "max": float(spec.get("time", 5)), "dps": float(spec.get("dps", 2)),
		"status": str(spec.get("status", "")), "style": str(spec.get("style", ""))}
	pools.append(pool)
	# in a world with the monster runtime the pool is also a puddle zone of its element
	# (src/hell/hell_monsters.gd): the puddle layer draws it, the element physics work on it
	# (monsters in it burn or are poisoned, fire boils water, the void eats it), the hero
	# who threw it is spared (friend). The feel's own drawing of it steps back (zoned).
	if g.get("monsters") != null:
		var style := str(spec.get("style", "")) if not str(spec.get("style", "")).is_empty() else ("fire" if str(spec.get("status", "")) == "burn" else "poison")
		g.monsters._zone({"kind": "puddle", "p": pool.p, "r": float(pool.r), "T": float(pool.t), "dmg": 0, "friend": true, "st": style,
			"m": {"id": "trank", "def": {"name": "Trank"}, "boss": false}, "dir": ((pool.p as Vector2) - Vector2(g.player.x, g.player.y)).normalized()})
		pool.zoned = true


## The thorn ward blessing: a spike under the monster.
func hero_strike(at: Vector2, radius: float, _delay: float, damage: float, _style: String, _owner: int) -> void:
	for m: Dictionary in g.mobs:
		if g._hittable(m) and (m.p as Vector2).distance_to(at * _scale) < radius * _scale + float(m.r):
			g._damage_mob(m, Vector2.ZERO, damage / maxf(0.01, float(_clean.damage)))
			break


## The thorn curse: a spike under the hero.
## Never lethal like the blood toll (leaves 1 LP); the spike still gives the short
## invulnerability after a hit.
func strike_at(at: Vector2, _radius: float, _warn: float, damage: int, _style: String) -> void:
	g._burst(at * _scale, 10)
	var n := _curse_cap(damage)
	if n <= 0: return
	g.dot_hurt(n, "von Dornen durchbohrt")
	g.state.inv = maxf(float(g.state.get("inv", 0.0)), float(g.balance.player.invulnerable))


## Freezing or dazing a monster (thrown ice and blinding potions).
func _status(enemy: Dictionary, _kind: String, _stacks: int, time: float, _owner: int) -> void:
	var m: Dictionary = enemy.get("ref", {})
	if not m.is_empty() and not m.has("kit"): m.stun = maxf(float(m.get("stun", 0.0)), time)


func _event(_kind: String, from: Vector2, to: Vector2) -> void:
	g.fx.append({"kind": "bolt", "p": from * _scale, "q": to * _scale, "t": 0.25, "max": 0.25})


## The rules' frost on the ground (a thrown ice potion: water it lands on turns to
## Glatteis): the story worlds' element physics take it (src/hell/story_elements.gd).
var elements: Object:
	get:
		return self if g.get("story_elements") != null else null


## Frost at a crypt point with a crypt radius, handed on in world units.
func frost_at(at: Vector2, radius: float, owner := 0) -> void:
	g.story_elements.frost_at(at * _scale, radius * _scale, owner)


## Lets the rules' thrown potions stop at the world's walls.
func segment_blocked(from: Vector2, to: Vector2) -> bool:
	var a := from * _scale
	var b := to * _scale
	var C: float = g.C
	var steps := maxi(1, int(a.distance_to(b) / 24.0))
	for step in range(steps + 1):
		var p := a.lerp(b, float(step) / float(steps))
		if g._cell_blocked(int(floor(p.x / C)), int(floor(p.y / C)), false): return true
	return false


## The clone seal: the world's own clone fights for \`time\` s.
func summon_clone(_id: int, hero: Dictionary, time: float) -> void:
	var skill: Dictionary = g.state.skill
	# a found clone skill keeps its own time and gets the seal's on top; else the seal's time alone
	skill.left = (float(skill.get("left", 0.0)) + time) if bool(skill.get("owned", false)) else time
	skill.owned = true
	if not bool(skill.get("active", false)): g.use_skill()
	inventory.note(hero, "Ein Klon kämpft %d s mit dir." % int(time))


## Floor items drop where the hero stands (the rules' "drop" action).
func drop_item(item: Dictionary, at: Vector2) -> void:
	floor_items.append({"item": item, "p": at * _scale, "born": float(g.state.get("t", 0.0))})


## Draws the items waiting on the floor and the thrown pools (world layer).
func draw(l: CanvasItem, t: float) -> void:
	# effect hook: with the feel the pools are the crypt's (boss_fx.gd on the feel's ground layer) and the
	# finds on the floor the crypt's loot (skill_fx.gd draw_loot: rarity glow, rays, the name up close)
	var feel: RefCounted = g.get("feel")
	if feel != null and g.get("story_hero") != null:
		_draw_crypt_loot(l, t, float(feel.scale))
		return
	# without the feel: a pixel pool on the 3 px grid, see-through, thinning by the dither as it runs out
	for pool: Dictionary in pools:
		var tint := Color(1.0, 0.5, 0.15, 0.55) if str(pool.status) == "burn" else Color(0.5, 0.9, 0.3, 0.5)
		var left := clampf(float(pool.t) / maxf(0.01, float(pool.get("max", pool.t))), 0.0, 1.0)
		preload("res://src/vfx/pixel_paint.gd").disc(l, pool.p, float(pool.r), float(pool.r) * 0.75, tint, 3.0, 0.3 + 0.4 * left)
	for drop: Dictionary in floor_items:
		var v := inventory.view(drop.item)
		var path := str(v.get("sprite", ""))
		if ResourceLoader.exists(path):
			if not _textures.has(path): _textures[path] = load(path)
			var tex: Texture2D = _textures[path]
			var bob := sin(t * 3.0) * 4.0
			var size := tex.get_size() * 3.0
			l.draw_circle(drop.p + Vector2(0, 4), 18.0, Color(str(v.get("color", "ffffff")), 0.25))
			l.draw_texture_rect(tex, Rect2(drop.p - Vector2(size.x * 0.5, size.y - bob), size), false)


## The finds on the floor as the crypt's item loot (crypt units: world px / `k`);
## the nearest one within reach shows its name.
func _draw_crypt_loot(l: CanvasItem, t: float, k: float) -> void:
	var skill: RefCounted = g.story_hero.skill_fx.skill
	var me := Vector2(float(g.player.x), float(g.player.y))
	var best := 140.0
	skill.nearest_loot = -1
	for i in range(floor_items.size()):
		var gap := (floor_items[i].p as Vector2).distance_to(me)
		if gap < best:
			best = gap
			skill.nearest_loot = i
	l.draw_set_transform(Vector2.ZERO, 0.0, Vector2(k, k))
	for i in range(floor_items.size()):
		var drop: Dictionary = floor_items[i]
		var at := (drop.p as Vector2) / k
		skill.draw_loot(l, {"kind": "item", "view": inventory.view(drop.item), "x": at.x, "y": at.y, "id": i, "age": t - float(drop.get("born", t - 1.0))}, t)
	l.draw_set_transform(Vector2.ZERO)


# --- the quick potion (H drinks, G throws at the mouse) -------------------------------
# R4 of production/qa/evidence/gameplay-review/BEWERTUNG.md: a right-click in the inventory
# window marks a potion stack ("quick" on its bag entry, kept when more of it stacks on);
# without a mark, or once the marked stack is used up, the first known healing potion,
# else the first potion stack. Drinking and throwing are the window's own (inventory.gd).

## g.state.t when the quick potion was last used (its bar slot glows briefly).
var _quick_used := -10.0


## The bag slot of the quick potion, or -1 when the bag holds no potion.
func quick_slot() -> int:
	var hero: Dictionary = players.get(1, {})
	if hero.is_empty() or not hero.has("inventory"): return -1
	var bag: Array = hero.inventory.get("bag", [])
	var first := -1
	var healing := -1
	for i in range(bag.size()):
		var item: Dictionary = bag[i]
		if str(item.get("type", "")) != "potion" or int(item.get("count", 1)) <= 0: continue
		if bool(item.get("quick", false)): return i
		if first < 0: first = i
		if healing < 0 and str(item.get("potion", "")) == "healing" and inventory.known.has("healing"): healing = i
	return healing if healing >= 0 else first


## Right-click in the inventory window: bag slot `slot` (a potion) becomes the quick potion.
func set_quick(slot: int) -> void:
	var hero: Dictionary = players.get(1, {})
	if hero.is_empty() or not hero.has("inventory"): return
	var bag: Array = hero.inventory.bag
	if slot < 0 or slot >= bag.size() or str(bag[slot].get("type", "")) != "potion": return
	for item: Dictionary in bag: item.erase("quick")
	bag[slot].quick = true
	inventory.note(hero, "Schnelltrank: %s · H trinken · G werfen" % inventory.name_of(bag[slot]))
	g._sound_raw("ui_click")
	_store()


## H: drinks the quick potion (inventory.gd _drink: its effect, splash and sound).
## False without a potion (a short note says so).
func drink_quick() -> bool:
	var slot := quick_slot()
	if slot < 0: return _no_quick()
	act("inv_drink", slot)
	_quick_used = float(g.state.t)
	# with the feel the drink's fx event sounds (feedback.gd); without it the sound comes here
	if g.get("feel") == null: g._sound_raw("drink")
	return true


## G: throws the quick potion at world point `at` (inventory.gd _throw: its range, the
## walls, the burst); the draw sound first, then the break.
func throw_quick(at: Vector2) -> bool:
	var slot := quick_slot()
	if slot < 0: return _no_quick()
	g._sound_raw("throw_arm")
	act("inv_throw", slot, at)
	_quick_used = float(g.state.t)
	if g.get("feel") == null: g._sound_raw("potion_break")
	return true


func _no_quick() -> bool:
	var hero: Dictionary = players.get(1, {})
	if not hero.is_empty(): inventory.note(hero, "Kein Trank im Inventar.")
	return false


## The skill bar's quick-potion slot (src/ui/talent_bar.gd potion_slot), after the skills.
func quick_slots() -> Array:
	var hero: Dictionary = players.get(1, {})
	if hero.is_empty() or not hero.has("inventory"): return []
	var slot := quick_slot()
	var v: Dictionary = inventory.view(hero.inventory.bag[slot]) if slot >= 0 else {}
	return [TalentBar.potion_slot(v, float(g.state.t) - _quick_used)]
