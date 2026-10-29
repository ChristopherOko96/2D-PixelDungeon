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
##   on the hero; thrown potions hurt, burn, freeze or daze monsters;
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
var _notes := 0
var _kills := 0
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
	return float(hero.shot_interval) / maxf(0.01, float(_clean.shot_interval))


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
		g.state.glow = str(spec.get("glow", ""))
	elif not spec.is_empty():
		g.state.glow = ""


# --- the item window (I) ------------------------------------------------------------

## The bag as the inventory window shows it.
func view() -> Dictionary:
	var hero: Dictionary = players.get(1, {})
	return inventory.snapshot(hero) if not hero.is_empty() else {}


## An action from the window: equip, identify, use, throw (at \`target\`, world px) ...
func act(action: String, value: int, target: Vector2 = Vector2.INF) -> void:
	var hero: Dictionary = players[1]
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


## Healing and harm back into the story hero.
func _sync_out() -> void:
	var hero: Dictionary = players[1]
	g.state.hp = clampi(int(hero.hp), 0, int(g.state.max_hp))
	inventory.equip_apply(hero)


# --- finds --------------------------------------------------------------------------

## A source drops its loot (chest, crate, gold_crate, mimic) at world point \`at\`;
## the first chest of a floor adds the floor's fixed finds.
func loot(source: String, at: Vector2) -> void:
	var items: Array = inventory.roll(source, int(g.state.floor), str(g.class_id))
	if source == "chest" and _first_chest_floor != int(g.state.floor):
		_first_chest_floor = int(g.state.floor)
		items.append_array(inventory.floor_finds(int(g.state.floor)))
	for item: Dictionary in items: give(item, at)


## A mini guardian's rare piece.
func guardian_drop(at: Vector2) -> void:
	give(inventory.guardian_drop(int(g.state.floor), str(g.class_id)), at)


## Into the bag, or onto the floor when it is full.
func give(item: Dictionary, at: Vector2) -> void:
	var hero: Dictionary = players[1]
	if hero.inventory.bag.size() < int(inventory.data.get("bag", 12)) or str(item.type) not in ["weapon", "gear"] and hero.inventory.bag.any(func(h: Dictionary) -> bool: return str(h.type) == str(item.type) and str(h.get("potion", "")) == str(item.get("potion", ""))):
		inventory.add(hero, item)
	else:
		floor_items.append({"item": item, "p": at})
		inventory.note(hero, "Rucksack voll: %s liegt am Boden." % inventory.name_of(item))
	_store()


# --- per frame ----------------------------------------------------------------------

## Effects run out, potions tick, pools burn, curses act, notes become toasts,
## floor items are picked up on contact.
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
			_store()
	_layer.queue_redraw()
	var notes := int(hero.get("item_notes", 0))
	if notes != _notes:
		_notes = notes
		if not str(hero.get("item_note", "")).is_empty(): g._toast(str(hero.item_note))
	_sync_out()


## A hero hit on monster \`m\`: the equipped pieces' effects (burn, poison,
## slow, critical, healing kills).
func on_hit(m: Dictionary) -> void:
	var build: Dictionary = players.get(1, {}).get("build", {})
	if build.is_empty() or m.has("kit"): return
	if float(build.get("cinder", 0.0)) > 0.0 or float(build.get("venom", 0.0)) > 0.0:
		g.HeroKit.burn_mob(m, float(EFFECTS.burn_dps) * (1.0 + float(build.get("cinder", 0.0)) + float(build.get("venom", 0.0))), float(EFFECTS.burn_time))
	if float(build.get("frost", 0.0)) > 0.0:
		g.HeroKit.slow_mob(g, m, minf(0.6, float(build.frost) + float(EFFECTS.slow) * 0.5), float(EFFECTS.slow_time))
	# run potions: hits shake the ground nearby (aftershock) or jump on as lightning (chain)
	if float(build.get("blast", 0.0)) > 0.0:
		for other: Dictionary in g.mobs:
			if other != m and g._hittable(other) and (other.p as Vector2).distance_to(m.p) < 70.0 * _scale:
				g._damage_mob(other, Vector2.ZERO, float(build.blast) * 0.5)
	if float(build.get("storm", 0.0)) > 0.0:
		var next: Dictionary = {}
		var near := 160.0 * _scale
		for other: Dictionary in g.mobs:
			var gap: float = (other.p as Vector2).distance_to(m.p)
			if other != m and g._hittable(other) and gap < near:
				near = gap
				next = other
		if not next.is_empty():
			g.fx.append({"kind": "bolt", "p": (m.p as Vector2) - Vector2(0, float(m.cy)), "q": (next.p as Vector2) - Vector2(0, float(next.cy)), "t": 0.25, "max": 0.25})
			g._damage_mob(next, Vector2.ZERO, float(build.storm))
	if float(m.hp) <= 0.0 and float(build.get("vampire", 0.0)) > 0.0:
		_kills += 1
		if _kills % maxi(1, int(build.vampire)) == 0: g.state.hp = mini(int(g.state.max_hp), int(g.state.hp) + 1)


## The shield potion's charges: true when one stops this hit.
func consume_shield() -> bool:
	var runtime: Dictionary = players.get(1, {}).get("perk_runtime", {})
	if int(runtime.get("shield", 0)) <= 0: return false
	runtime.shield = int(runtime.shield) - 1
	g._burst(Vector2(float(g.player.x), float(g.player.y) - 40.0), 16, true)
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


func add_fx(kind: String, at: Vector2, radius: float, _extra: Dictionary = {}) -> void:
	var p := at * _scale
	match kind:
		"potion_blast", "potion_throw": g.fx.append({"kind": "blast", "p": p, "r": radius * _scale, "t": 0.3, "max": 0.3, "gravity": false})
		"curse": g._burst(p, 20)
		_: g._burst(p, 12, true)


func _damage_player(_id: int, amount: int, _direction: Vector2) -> void:
	g.state.inv = 0.0
	g._hurt("vom Sprengtrank zerrissen", amount)


func dot_player(_id: int, amount: int, _kind: String) -> void:
	g.state.inv = 0.0
	g._hurt("vom Blutzoll ausgezehrt", amount)


func _damage_enemy(enemy: Dictionary, damage: float, direction: Vector2, _owner: int) -> float:
	var m: Dictionary = enemy.get("ref", {})
	if m.is_empty(): return 0.0
	g._damage_mob(m, direction * 300.0, damage / maxf(0.01, float(_clean.damage)))
	return damage


## Timed effects of potions on the hero (strength, haste, regeneration, burn, slow ...).
func apply(_player: Dictionary, kind: String, time: float, value: float) -> void:
	match kind:
		"regen": effects.regen = {"t": time, "every": value, "tick": value}
		"burn", "poison": effects[kind] = {"t": time, "every": 1.5, "tick": 1.5}
		_: effects[kind] = {"t": time, "value": value}


## A thrown fire or poison pool that hurts monsters for a while.
func hero_pool(at: Vector2, spec: Dictionary, _owner: int) -> void:
	pools.append({"p": at * _scale, "r": float(spec.get("radius", 60)) * _scale, "t": float(spec.get("time", 5)), "dps": float(spec.get("dps", 2)), "status": str(spec.get("status", ""))})


## The thorn ward blessing: a spike under the monster.
func hero_strike(at: Vector2, radius: float, _delay: float, damage: float, _style: String, _owner: int) -> void:
	for m: Dictionary in g.mobs:
		if g._hittable(m) and (m.p as Vector2).distance_to(at * _scale) < radius * _scale + float(m.r):
			g._damage_mob(m, Vector2.ZERO, damage / maxf(0.01, float(_clean.damage)))
			break


## The thorn curse: a spike under the hero.
func strike_at(at: Vector2, _radius: float, _warn: float, damage: int, _style: String) -> void:
	g._burst(at * _scale, 10)
	g.state.inv = 0.0
	g._hurt("von Dornen durchbohrt", damage)


## Freezing or dazing a monster (thrown ice and blinding potions).
func _status(enemy: Dictionary, _kind: String, _stacks: int, time: float, _owner: int) -> void:
	var m: Dictionary = enemy.get("ref", {})
	if not m.is_empty() and not m.has("kit"): m.stun = maxf(float(m.get("stun", 0.0)), time)


func _event(_kind: String, from: Vector2, to: Vector2) -> void:
	g.fx.append({"kind": "bolt", "p": from * _scale, "q": to * _scale, "t": 0.25, "max": 0.25})


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
	floor_items.append({"item": item, "p": at * _scale})


## Draws the items waiting on the floor and the thrown pools (world layer).
func draw(l: CanvasItem, t: float) -> void:
	for pool: Dictionary in pools:
		var tint := Color(1.0, 0.5, 0.15, 0.25) if str(pool.status) == "burn" else Color(0.5, 0.9, 0.3, 0.22)
		l.draw_circle(pool.p, float(pool.r), tint)
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
