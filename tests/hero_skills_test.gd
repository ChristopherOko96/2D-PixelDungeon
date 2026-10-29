extends SceneTree
## Hero skills, team EXP and class cards on the host (src/combat/hero_skills.gd,
## src/player/team_progress.gd, src/player/class_perks.gd, wall_breaker.gd):
## kills drop orbs that fill one shared team level, every hero gets a card
## choice per level, cards change stats and skills, keys 1-4 cast with
## cooldowns and level locks, and ultimates break inner walls only.

const Game = preload("res://src/game.gd")
const Dungeon = preload("res://src/dungeon/dungeon_generator.gd")
const ClassPerks = preload("res://src/player/class_perks.gd")
const RunTree_ = preload("res://src/progress/run_tree.gd")
const WallBreaker = preload("res://src/dungeon/wall_breaker.gd")
var checked := 0
var failures: Array[String] = []
var game
var _sequence := 0

func check(condition: bool, label: String) -> void:
	checked += 1
	if not condition:
		failures.append(label)
		printerr("HERO_SKILLS_FAIL: ", label)

func _initialize() -> void:
	_run.call_deferred()

## Holds keys (bitmask) with the mouse at `target` for one simulated step.
func _input(keys: int, target: Vector2, fire: bool = false) -> void:
	var player: Dictionary = game.players[1]
	_sequence += 1
	game.commands[1] = {"move": Vector2.ZERO, "aim": (target - Vector2(player.pos)).normalized(), "fire": fire, "sequence": _sequence, "time": Time.get_ticks_msec() / 1000.0, "skills": keys, "target": target}

func _step(seconds: float) -> void:
	var steps := maxi(1, int(seconds * 60.0))
	for i in range(steps):
		game.commands[1].time = Time.get_ticks_msec() / 1000.0
		game._simulate_players(1.0 / 60.0)
		game.hero_skills.step(1.0 / 60.0)
		game.team_progress.step(1.0 / 60.0)
		game._simulate_bullets(1.0 / 60.0)
		game.perk_combat.step_statuses(1.0 / 60.0)

## A clear spot `distance` px from `origin` (no wall in between).
func _clear(origin: Vector2, distance: float) -> Vector2:
	for offset: Vector2 in [Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP]:
		var spot := origin + offset * distance
		if not Dungeon.segment_blocked(origin, spot, 16.0, game.current_layout): return spot
	return origin

func _dummy(point: Vector2, hp: float = 400.0) -> Dictionary:
	var enemy: Dictionary = game._create_enemy("skeleton", point)
	enemy.hp = hp
	enemy.max_hp = hp
	enemy.erase("parts")
	enemy.erase("rig")
	game.enemies.append(enemy)
	return enemy

func _fresh(class_id: String) -> void:
	game.player_classes[1] = class_id
	game.requested_seed = 4242
	game._begin_run()
	game.enemies.clear()
	game.bullets.clear()
	game.players[1].invulnerable = 999.0

func _run() -> void:
	game = Game.new()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	game.view.set_audio_enabled(false)
	var probe := PacketPeerUDP.new()
	probe.bind(0, "127.0.0.1")
	game.port_input.text = str(probe.get_local_port())
	probe.close()
	game.session_bind_ip = "127.0.0.1"
	game._host_session()
	# Skills and cards are tested on single encounters (hordes: tests/hordes_test.gd).
	game.hordes.enabled = false

	# --- Team EXP and level-up cards ---
	_fresh("swordsman")
	var hero: Dictionary = game.players[1]
	check(int(game.team_progress.team.level) == 1 and game.team_progress.next_level_exp() == 30, "a run starts at team level 1 with 30 EXP to level 2")
	var victim := _dummy(_clear(hero.pos, 90.0), 1.0)
	game._damage_enemy(victim, 5.0, Vector2.RIGHT, 1)
	check(not game.team_progress.orbs.is_empty(), "a kill drops EXP orbs")
	game.enemies.clear()
	_input(0, Vector2(hero.pos) + Vector2(50, 0))
	_step(2.0)
	check(game.team_progress.orbs.is_empty() and int(game.team_progress.team.exp) == 10, "the orbs fly to the hero and fill the team bar (10 EXP for a skeleton)")
	game.team_progress.add_exp(25)
	# a level-up gives a run talent point, no cards (docs/LAUF-DESIGN.de.md)
	var tree := RunTree_.build(ClassPerks.run_tree("swordsman").branches)
	check(int(game.team_progress.team.level) == 2 and Array(hero.offer).is_empty() and RunTree_.points_left(tree, ClassPerks.ranks(hero), 2) == 1, "a team level-up gives the hero a run talent point")
	var open_ids: Array = ClassPerks.run_tree_ids("swordsman").filter(func(id: String) -> bool: return RunTree_.can_take(tree, ClassPerks.ranks(hero), 2, id))
	var open_skills: Array = open_ids.map(func(id: String) -> String: return str(ClassPerks.find("swordsman", id).get("skill", "passive")))
	check(not open_ids.is_empty() and open_skills.all(func(skill: String) -> bool: return skill in ["whirl", "passive"]), "level 2 opens only passives and the first skill's upgrades (%s)" % str(open_skills))
	check(ClassPerks.run_tree_ids("swordsman").all(func(id: String) -> bool: return str(ClassPerks.find("swordsman", id).get("icon", {}).get("base", "")) != "weapon_bow"), "no swordsman node shows a bow")
	# Card effects: Schwerer Hieb raises damage on every rebuild without healing.
	var before_damage := float(hero.damage)
	hero.offer = [ClassPerks.find("swordsman", "sw_heavy")]
	hero.offer[0].kind = "passive"
	hero.offer_queue = ["level"]
	check(game.team_progress.pick(hero, 0) and is_equal_approx(float(hero.damage), before_damage * 1.25), "Schwerer Hieb: +25 % damage")
	hero.hp = 4
	hero.offer = [ClassPerks.find("swordsman", "sw_vigor")]
	hero.offer[0].kind = "passive"
	hero.offer_queue = ["level"]
	var max_before := int(hero.max_hp)
	game.team_progress.pick(hero, 0)
	check(int(hero.max_hp) == max_before + 2 and int(hero.hp) == 4, "Eiserne Haut adds a heart of capacity and keeps current HP")
	check(not ClassPerks.grant(hero, "sw_parry") or not ClassPerks.grant(hero, "sw_parry"), "a card cannot exceed its maximum")
	# Two players level together (shared team bar).
	game._add_player(2)
	game.players[2].class_perks = []
	game.players[2].offer_queue = []
	game.players[2].offer = []
	var level_before := int(game.team_progress.team.level)
	game.team_progress.add_exp(game.team_progress.next_level_exp())
	var level_now := int(game.team_progress.team.level)
	check(level_now == level_before + 1 and RunTree_.points_left(tree, ClassPerks.ranks(game.players[2]), level_now) == level_now - 1, "one shared bar: both heroes level up at once and gain the point")
	game.players.erase(2)

	# --- Swordsman skills ---
	_fresh("swordsman")
	hero = game.players[1]
	var enemy := _dummy(_clear(hero.pos, 60.0))
	_input(1, Vector2(enemy.pos))
	_step(1.0 / 60.0)
	check(float(enemy.hp) < 400.0 and float(hero.skill_cd[0]) > 5.0, "key 1: Wirbelklinge hits around the hero and starts its 6 s cooldown")
	var hp_after := float(enemy.hp)
	_input(0, Vector2(enemy.pos))
	_step(1.0 / 60.0)
	_input(1, Vector2(enemy.pos))
	_step(1.0 / 60.0)
	check(is_equal_approx(float(enemy.hp), hp_after), "the cooldown blocks a second cast")
	_input(2, Vector2(enemy.pos))
	_step(0.1)
	check(game.bullets.is_empty(), "key 2 stays locked below level 3")
	game.team_progress.add_exp(5000)
	check(int(game.team_progress.team.level) >= 10, "enough EXP unlocks every skill (level %d)" % int(game.team_progress.team.level))
	var start := Vector2(hero.pos)
	var charge_target := _clear(start, 160.0)
	_input(0, charge_target)
	_step(1.0 / 60.0)
	_input(4, charge_target)
	_step(0.4)
	check(Vector2(hero.pos).distance_to(start) > 60.0, "key 3: Ansturm dashes towards the mouse")
	_input(0, charge_target)
	_step(1.0 / 60.0)
	_input(8, charge_target)
	_step(1.0 / 60.0)
	check(float(hero.skill.get("rage", 0.0)) > 5.0 and float(hero.skill_rate) <= 0.51, "key 4: Rage doubles the attack speed")

	# --- Archer skills ---
	_fresh("archer")
	hero = game.players[1]
	game.team_progress.add_exp(5000)
	hero.offer_queue = []
	hero.offer = []
	var aim_point := _clear(hero.pos, 200.0)
	_input(1, aim_point)
	_step(1.0 / 60.0)
	check(game.bullets.filter(func(b: Dictionary) -> bool: return str(b.get("skill", "")) == "volley").size() == 5, "key 1: Salve fires a fan of 5 arrows")
	game.bullets.clear()
	_input(0, aim_point)
	_step(1.0 / 60.0)
	_input(2, aim_point)
	_step(0.6)
	check(hero.skill.has("ballista"), "key 2 held: the Ballistapfeil charges")
	_input(0, aim_point)
	_step(1.0 / 60.0)
	var bolts: Array = game.bullets.filter(func(b: Dictionary) -> bool: return str(b.get("skill", "")) == "ballista")
	check(bolts.size() == 1 and float(bolts[0].charge) > 0.4 and float(hero.skill_cd[1]) > 6.0, "released: one piercing bolt with its charge, cooldown from the release")
	game.bullets.clear()

	# --- Mage skills ---
	_fresh("mage")
	hero = game.players[1]
	game.team_progress.add_exp(5000)
	# Regression: key 2 pressed with no target in sight, then held while a target
	# appears -> the held key still casts (the press is not used up).
	_input(2, Vector2(hero.pos) + Vector2(100, 0))
	_step(0.1)
	check(float(hero.skill_cd[1]) == 0.0, "Kettenblitz without a target does nothing")
	var late := _dummy(_clear(hero.pos, 120.0))
	_input(2, Vector2(late.pos))
	_step(0.1)
	check(float(hero.skill_cd[1]) > 0.0 and float(late.hp) < 400.0, "a held key casts once a target is in sight")
	game.enemies.clear()
	hero.skill_cd = [0.0, 0.0, 0.0, 0.0]
	_input(0, Vector2(hero.pos))
	_step(1.0 / 60.0)
	var first := _dummy(_clear(hero.pos, 150.0))
	var second := _dummy(Vector2(first.pos) + Vector2(0, 60))
	if Dungeon.segment_blocked(first.pos, second.pos, 0.0, game.current_layout): second.pos = Vector2(first.pos) + Vector2(0, -60)
	_input(2, Vector2(first.pos))
	_step(1.0 / 60.0)
	check(float(first.hp) < 400.0 and float(second.hp) < 400.0, "key 2: Kettenblitz hits the target and jumps on")
	# Blink never passes a wall: the landing point keeps a clear line to the start.
	start = Vector2(hero.pos)
	_input(0, start)
	_step(1.0 / 60.0)
	var far := start + Vector2(2000, 0)
	_input(4, far)
	_step(1.0 / 60.0)
	check(not Dungeon.segment_blocked(start, hero.pos, 0.0, game.current_layout) and Vector2(hero.pos).distance_to(start) <= 181.0, "key 3: Blinzeln stops before walls and at 180 px")
	# Photoneneis: held channel hurts what the beam touches, then cools down.
	game.enemies.clear()
	var beam_target := _dummy(_clear(hero.pos, 140.0))
	_input(0, Vector2(beam_target.pos))
	_step(1.0 / 60.0)
	hero.aim = (Vector2(beam_target.pos) - Vector2(hero.pos)).normalized()
	_input(8, Vector2(beam_target.pos))
	_step(1.0)
	check(hero.skill.has("photon") and float(beam_target.hp) < 400.0 and beam_target.get("statuses", {}).has("burn"), "key 4 held: Photoneneis burns what the beam touches")
	_input(0, Vector2(beam_target.pos))
	_step(1.0 / 60.0)
	check(not hero.skill.has("photon") and float(hero.skill_cd[3]) > 19.0, "releasing ends the beam and starts its 20 s cooldown")

	# --- Walls: inner dividers break, outer walls never ---
	var layout: Dictionary = {}
	var inner_cell := Vector2i(-1, -1)
	var outer_cell := Vector2i(-1, -1)
	for candidate: Dictionary in game.floor_layouts:
		var grid := WallBreaker._grid(candidate)
		for cell: Vector2i in grid:
			if inner_cell.x < 0 and WallBreaker.inner(candidate, cell, grid): inner_cell = cell
			# An outer wall cell: wall with nothing painted on one side.
			if outer_cell.x < 0 and str(grid[cell]) == "wall" and not grid.has(cell + Vector2i.LEFT) and grid.get(cell + Vector2i.RIGHT, "") == "floor": outer_cell = cell
		if inner_cell.x >= 0:
			layout = candidate
			break
		outer_cell = Vector2i(-1, -1)
	check(not layout.is_empty(), "the crypt has rooms with inner divider walls")
	if not layout.is_empty():
		game.room = game.floor_layouts.find(layout) + 1
		game._spawn_room()
		game.enemies.clear()
		var center := Vector2(inner_cell) * 32.0 + Vector2(16, 16)
		var across := Vector2(inner_cell.x * 32.0 - 20.0, center.y) if WallBreaker._grid(layout).get(inner_cell + Vector2i.LEFT, "") == "floor" else Vector2(center.x, inner_cell.y * 32.0 - 20.0)
		var across_end := center + (center - across)
		check(Dungeon.segment_blocked(across, across_end, 0.0, layout), "before: the divider blocks the way")
		var revision := int(game._room_layout_revision)
		var broken := WallBreaker.break_circle(layout, center, 8.0)
		game.walls_broken(broken)
		check(broken.size() == 1 and not Dungeon.segment_blocked(across, across_end, 0.0, layout), "after: the broken cell can be walked through")
		check(int(game._room_layout_revision) == revision + 1 and game.current_layout == layout, "the new layout goes to clients and stays in the floor")
		if outer_cell.x >= 0:
			check(WallBreaker.break_circle(layout, Vector2(outer_cell) * 32.0 + Vector2(16, 16), 8.0).is_empty(), "an outer wall cell never breaks")
		# The archer's Pfeilfaust breaks a divider it hits (end to end, as in play).
		var hit_cell := Vector2i(-1, -1)
		var grid_now := WallBreaker._grid(layout)
		for cell: Vector2i in grid_now:
			if WallBreaker.inner(layout, cell, grid_now) and grid_now.get(cell + Vector2i.LEFT, "") == "floor" and grid_now.get(cell + Vector2i.LEFT * 4, "") == "floor":
				hit_cell = cell
				break
		if hit_cell.x >= 0:
			game.player_classes[1] = "archer"
			game.HeroClass.apply(game.players[1], "archer", game.balance)
			hero = game.players[1]
			hero.class_perks = []
			hero.skill = {}
			hero.skill_cd = [0.0, 0.0, 0.0, 0.0]
			hero.skill_second = [0.0, 0.0, 0.0, 0.0]
			hero.pos = Vector2(hit_cell) * 32.0 + Vector2(16 - 120, 16)
			var wall_target := Vector2(hit_cell) * 32.0 + Vector2(16, 16)
			_input(0, wall_target)
			_step(1.0 / 60.0)
			_input(8, wall_target)
			_step(1.5)
			check(not WallBreaker._grid(layout).get(hit_cell, "") == "wall", "Pfeilfaust breaks the inner wall it hits")

	# --- Bosses add a perk choice; rooms no longer stop for cards ---
	_fresh("archer")
	hero = game.players[1]
	var boss := _dummy(_clear(hero.pos, 120.0), 1.0)
	boss.miniboss = true
	game._damage_enemy(boss, 5.0, Vector2.RIGHT, 1)
	check(Array(hero.offer_queue).has("boss") and str(hero.offer_kind) == "boss" and Array(hero.offer).all(func(card: Dictionary) -> bool: return str(card.kind) in ["perk", "fallback"]), "a mini-boss kill offers general perks")
	game.enemies.clear()
	game.phase = "combat"
	game._check_room_end()
	check(game.phase == "explore", "a cleared room opens at once (no per-room cards)")
	print("HERO_SKILLS checked=%d failures=%d" % [checked, failures.size()])
	game.queue_free()
	await process_frame
	quit(1 if failures.size() > 0 else 0)
