extends RefCounted
## Shared team experience on the host. Killed enemies drop EXP orbs; they burst
## out, settle, then fly to the nearest living hero (or to anyone once the room
## is clear). Every collected orb fills one team bar, so all heroes level up at
## the same moment. Each level gives every hero a small heal and one point for
## the run talent tree (ClassPerks.run_tree, docs/LAUF-DESIGN.de.md), spent with
## take_talent; bosses and mini-bosses add a choice of general perks. Choices queue per hero and are picked by mouse while
## the fight goes on. Values: assets/data/hero_skills.json (leveling, exp, orbs).

const Progression = preload("res://src/player/progression.gd")
const ClassPerks = preload("res://src/player/class_perks.gd")
const PerkRules = preload("res://src/perk_rules.gd")
const Dungeon = preload("res://src/dungeon/dungeon_generator.gd")
const RunTree = preload("res://src/progress/run_tree.gd")

var game: Node
## Team level and the EXP collected towards the next one.
var team := {"level": 1, "exp": 0}
## Orbs on the floor: {id, pos, vel, value, age}.
var orbs: Array = []
var _next_id := 1
var _rng := RandomNumberGenerator.new()


func bind(owner: Node) -> void:
	game = owner


func _config(key: String) -> Dictionary:
	return ClassPerks.data().get(key, {})


## A fresh run: level 1, no orbs, no class cards or open choices.
func reset(seed_value: int) -> void:
	team = {"level": 1, "exp": 0}
	orbs.clear()
	_next_id = 1
	_rng.seed = seed_value + 7349
	for player: Dictionary in game.players.values():
		player.class_perks = []
		player.offer_queue = []
		player.offer = []
		player.offer_kind = ""


## EXP still needed for the next team level.
func next_level_exp() -> int:
	return Progression.exp_to_next(int(team.level), _config("leveling"))


## EXP an enemy is worth (summons less), from hero_skills.json "exp".
func exp_value(enemy: Dictionary) -> int:
	var table := _config("exp")
	var value := float(table.get(str(enemy.get("kind", "")), table.get("default", 8)))
	if bool(enemy.get("summoned", false)): value *= float(table.get("summoned_scale", 0.5))
	# Large hordes give less per kill, so the level pace stays the same.
	if game != null and game.get("hordes") != null: value *= float(game.hordes.exp_scale())
	return maxi(1, roundi(value))


## A kill drops its EXP as orbs; a boss or mini-boss also brings a perk choice.
func enemy_killed(enemy: Dictionary) -> void:
	var settings := _config("orbs")
	var values := Progression.split_exp(exp_value(enemy), int(settings.get("max_orbs", 8)))
	for value: int in values:
		var angle := _rng.randf() * TAU
		var speed := _rng.randf_range(float(settings.get("burst_speed_min", 90)), float(settings.get("burst_speed_max", 190)))
		orbs.append({"id": _next_id, "pos": Vector2(enemy.pos), "vel": Vector2.from_angle(angle) * speed, "value": value, "age": 0.0})
		_next_id += 1
	if bool(enemy.get("boss", false)) or bool(enemy.get("miniboss", false)):
		for player: Dictionary in game.players.values():
			_queue(player, "boss")


## Orb flight and pickup; call once per host step.
func step(delta: float) -> void:
	var settings := _config("orbs")
	var room_clear: bool = game.enemies.is_empty()
	for index in range(orbs.size() - 1, -1, -1):
		var orb: Dictionary = orbs[index]
		orb.age = float(orb.age) + delta
		var target := _nearest_hero(Vector2(orb.pos))
		if float(orb.age) < float(settings.get("settle", 0.45)) or target.is_empty():
			orb.vel = Vector2(orb.vel) * exp(-float(settings.get("friction", 5.0)) * delta)
			orb.pos = Dungeon.move_actor(orb.pos, Vector2(orb.vel) * delta, float(settings.get("radius", 4)), game.current_layout)
			continue
		var to_hero: Vector2 = Vector2(target.pos) - Vector2(orb.pos)
		var vacuum := room_clear and float(orb.age) >= float(settings.get("vacuum_after", 0.8))
		if to_hero.length() <= float(settings.get("magnet_radius", 130)) or vacuum or bool(orb.get("drawn", false)):
			orb.drawn = true
			orb.vel = (Vector2(orb.vel) + to_hero.normalized() * float(settings.get("magnet_accel", 1700)) * delta).limit_length(float(settings.get("max_speed", 600)))
			# Drawn orbs fly straight to the hero, even around a pillar.
			orb.pos = Vector2(orb.pos) + Vector2(orb.vel) * delta
		else:
			orb.vel = Vector2(orb.vel) * exp(-float(settings.get("friction", 5.0)) * delta)
		if Vector2(orb.pos).distance_to(target.pos) <= float(settings.get("collect_radius", 18)) + float(game.balance.player.radius):
			orbs.remove_at(index)
			add_exp(int(orb.value))


## Leaving a room collects whatever is still on the floor.
func collect_all() -> void:
	var total := 0
	for orb: Dictionary in orbs: total += int(orb.value)
	orbs.clear()
	if total > 0: add_exp(total)


## Adds team EXP; every level gained heals each living hero and queues a card choice.
func add_exp(amount: int) -> int:
	var leveling := _config("leveling")
	if int(team.level) >= int(leveling.get("max_level", 40)): return 0
	var before := int(team.level)
	var gained := Progression.add_exp(team, amount, leveling)
	if int(team.level) > int(leveling.get("max_level", 40)):
		team.level = int(leveling.get("max_level", 40))
		team.exp = 0
	gained = int(team.level) - before
	for step_index in range(gained):
		for player: Dictionary in game.players.values():
			# the level is the point: spent in the run talent tree (take_talent)
			if int(player.hp) > 0: player.hp = mini(int(player.max_hp), int(player.hp) + int(leveling.get("heal", 2)))
	if gained > 0:
		for player: Dictionary in game.players.values(): game.add_fx("level_up", player.pos, 48.0)
		print("TEAM_LEVEL level=%d" % int(team.level))
	return gained


## Spends one run talent point of the hero on class card `id` when the tree
## allows it (its skill open, its tier reached, a point left). True on success.
func take_talent(player: Dictionary, id: String) -> bool:
	var tree := ClassPerks.run_tree(str(player.get("class_id", "")), player.get("meta", {}))
	if not RunTree.can_take(tree, ClassPerks.ranks(player), int(team.level), id): return false
	if not ClassPerks.grant(player, id): return false
	PerkRules.rebuild(player, game.balance)
	player.last_card = id
	return true


## Picks card `index` of the hero's open choice. Returns false when invalid.
func pick(player: Dictionary, index: int) -> bool:
	_ensure_offer(player)
	var cards: Array = player.get("offer", [])
	if index < 0 or index >= cards.size(): return false
	var card: Dictionary = cards[index]
	var ok := false
	match str(card.get("kind", "")):
		"upgrade", "passive": ok = ClassPerks.grant(player, str(card.id))
		_: ok = PerkRules.grant(player, card, game.balance)
	if not ok: return false
	PerkRules.rebuild(player, game.balance)
	if str(card.get("kind", "")) == "perk": game.perk_combat.granted(_peer_of(player), PerkRules.find(game.balance, str(card.id)))
	player.last_card = str(card.id)
	player.offer_queue.pop_front()
	player.offer = []
	player.offer_kind = ""
	_ensure_offer(player)
	return true


## Fills the hero's current card choice from the head of its queue.
func _ensure_offer(player: Dictionary) -> void:
	if not Array(player.get("offer", [])).is_empty(): return
	var queue: Array = player.get("offer_queue", [])
	if queue.is_empty():
		player.offer = []
		player.offer_kind = ""
		return
	var kind := str(queue[0])
	var count := int(_config("leveling").get("cards", 3))
	if kind == "boss":
		var cards := PerkRules.offer(player, game.balance, _rng, int(_config("boss_perks").get("cards", 3)))
		for card: Dictionary in cards: card.kind = "perk" if str(card.get("stat", "")) != "reserve" else "fallback"
		player.offer = cards
	else:
		player.offer = ClassPerks.offer(player, int(team.level), _rng, game.balance, count)
	player.offer_kind = kind


func _queue(player: Dictionary, kind: String) -> void:
	if not player.has("offer_queue"): player.offer_queue = []
	player.offer_queue.append(kind)
	_ensure_offer(player)


func _nearest_hero(point: Vector2) -> Dictionary:
	var best: Dictionary = {}
	var distance := INF
	for player: Dictionary in game.players.values():
		if int(player.hp) <= 0: continue
		var d := point.distance_squared_to(player.pos)
		if d < distance:
			distance = d
			best = player
	return best


func _peer_of(player: Dictionary) -> int:
	for id: int in game.players:
		if is_same(game.players[id], player): return id
	return 0


## What clients draw: team level and bar, and the orbs.
func snapshot() -> Dictionary:
	var visible: Array = []
	for orb: Dictionary in orbs: visible.append({"id": int(orb.id), "x": Vector2(orb.pos).x, "y": Vector2(orb.pos).y, "v": int(orb.value)})
	return {"level": int(team.level), "exp": int(team.exp), "next": next_level_exp(), "orbs": visible}
