extends SceneTree
## Boss and enemy moves (src/combat/boss_moves.gd, data combat_boss_moves.json):
## every boss has at least 7 moves and every crypt enemy new ones; each move
## type does what it warns of (strikes hit inside the circle and spare those
## who left it, pools hurt over time, charges move, vortices pull, cones
## poison, grabs throw, summons call, armour halves damage then shatters,
## walls and cages block and break); rage comes once at low HP; the
## Knochenkoloss rises from its bones unless its skull is smashed; the
## Leerenrufer's beam runs to the wall and splits in two in rage; heroes slow,
## freeze, slide and suffer poison.

const Game = preload("res://src/game.gd")
const Dungeon = preload("res://src/dungeon/dungeon_generator.gd")
const DT := 1.0 / 60.0
var checked := 0
var failures: Array[String] = []
var game


func check(condition: bool, label: String) -> void:
	checked += 1
	if not condition:
		failures.append(label)
		printerr("BOSS_MOVES_FAIL: ", label)


func _initialize() -> void:
	_run.call_deferred()


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
	game.player_classes[1] = "swordsman"
	game._host_session()
	game.requested_seed = 4242
	game._begin_run()
	_test_data_gives_every_boss_seven_moves()
	_test_strikes_hit_inside_and_spare_who_left()
	_test_projectile_moves()
	_test_ground_and_body_moves()
	_test_blocks_and_summons()
	_test_rage_and_rebuild()
	_test_beam_runs_to_the_wall()
	_test_hero_conditions()
	print("BOSS_MOVES checked=%d failures=%d" % [checked, failures.size()])
	game.queue_free()
	await process_frame
	quit(1 if failures.size() > 0 else 0)


# --- Helpers -------------------------------------------------------------------------

## A fresh fight in the biggest room of the floor, the hero healed and ready.
func _arena() -> Dictionary:
	var best := 0
	for index in range(game.floor_layouts.size()):
		var world: Array = game.floor_layouts[index].world_size
		var own: Array = game.floor_layouts[best].world_size
		if float(world[0]) * float(world[1]) > float(own[0]) * float(own[1]): best = index
	game.room = best + 1
	game._spawn_room()
	game.enemies.clear()
	game.bullets.clear()
	game.chests.chests.erase(str(game.current_layout.id))
	game.boss_moves.reset()
	game.phase = "combat"
	var hero: Dictionary = game.players[1]
	hero.hp = 200
	hero.max_hp = 200
	hero.invulnerable = 0.0
	hero.knockback = Vector2.ZERO
	hero.effects = {}
	hero.pos = _open_spot(game.current_layout)
	return hero


func _open_spot(layout: Dictionary) -> Vector2:
	var best := Vector2.ZERO
	var room := 0.0
	for entry: Dictionary in layout.painted_tiles:
		if str(entry.get("layer", "")) != "floor": continue
		var point := Vector2(float(entry.x) * 32.0 + 16.0, float(entry.y) * 32.0 + 16.0)
		var free := 0.0
		for direction: Vector2 in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
			var reach := 0.0
			while reach < 320.0 and not Dungeon.segment_blocked(point, point + direction * (reach + 16.0), 14.0, layout): reach += 16.0
			free += minf(reach, 200.0)
		if free > room:
			room = free
			best = point
	return best


## An enemy of `kind` placed `distance` px beside the hero (towards open floor).
func _foe(kind: String, distance: float, boss: bool = false, wide_path: bool = false) -> Dictionary:
	var hero: Dictionary = game.players[1]
	var enemy: Dictionary = game._create_enemy("boss" if boss else kind, Vector2.ZERO)
	if boss:
		enemy.rig = "void"
		enemy.kind = "boss"
		game.body_parts.attach(enemy, "void")
	enemy.pos = Vector2.INF
	for scale: float in [1.0, 0.75, 0.5, 1.4]:
		for index in range(8):
			var spot: Vector2 = Vector2(hero.pos) + Vector2.from_angle(index * TAU / 8.0) * distance * scale
			if Dungeon.segment_blocked(spot, spot, float(enemy.radius), game.current_layout): continue
			if Dungeon.segment_blocked(Vector2(hero.pos), spot, float(enemy.radius) * 0.5 if wide_path else 4.0, game.current_layout): continue
			enemy.pos = spot
			break
		if Vector2(enemy.pos).is_finite(): break
	check(Vector2(enemy.pos).is_finite(), "room for a %s beside the hero" % kind)
	if not Vector2(enemy.pos).is_finite(): enemy.pos = Vector2(hero.pos) + Vector2(distance, 0)
	enemy.move_cooldowns = {}
	game.enemies.append(enemy)
	return enemy


## Runs one move to its end (and its zones a little longer).
func _play(enemy: Dictionary, id: String, extra: float = 0.0, keep_still: bool = true) -> void:
	var hero: Dictionary = game.players[1]
	var anchor: Vector2 = hero.pos
	game.boss_moves._begin(enemy, id, game.boss_moves.move(id), 1, hero)
	var time := 0.0
	while (enemy.has("move") or time < extra) and time < 12.0:
		if enemy.has("move"): game.boss_moves.step(enemy, 1, DT)
		game.boss_moves.update(DT)
		game._simulate_bullets(DT)
		game.player_effects.step(DT)
		hero.invulnerable = 0.0
		if keep_still: hero.pos = anchor
		time += DT


func _settle(seconds: float) -> void:
	var time := 0.0
	while time < seconds:
		game.boss_moves.update(DT)
		game._simulate_bullets(DT)
		game.player_effects.step(DT)
		game.chests.step(DT)
		game.players[1].invulnerable = 0.0
		time += DT


# --- Tests ---------------------------------------------------------------------------

func _test_data_gives_every_boss_seven_moves() -> void:
	var data: Dictionary = game.boss_moves.data
	var missing: Array[String] = []
	var types := ["strikes", "bullets", "lob", "dash", "blink", "vortex", "cone", "grab", "spin", "summon", "armor", "barrier", "cage", "shield", "twin_beam"]
	for key: String in data.sets:
		for entry: Dictionary in data.sets[key].moves:
			var spec: Dictionary = data.moves.get(str(entry.move), {})
			if spec.is_empty() or str(spec.get("type", "")) not in types: missing.append("%s/%s" % [key, str(entry.move)])
	check(missing.is_empty(), "every move of every set exists and has a known type (%s)" % str(missing))
	for boss: String in ["void", "moderkoloss", "frostleiche", "knochenkoloss"]:
		var count: int = Array(data.sets[boss].moves).size() + (1 if data.sets[boss].has("rebuild") else 0)
		check(count >= 7, "%s has at least 7 abilities (%d)" % [boss, count])
	for kind: String in ["skeleton", "skeleton_archer", "skeleton_guard", "necromancer", "tiny_zombie", "ice_zombie", "void_bomber"]:
		check(data.sets.has(kind) and not Array(data.sets[kind].moves).is_empty(), "%s has new moves" % kind)


func _test_strikes_hit_inside_and_spare_who_left() -> void:
	var hero := _arena()
	var foe := _foe("necromancer", 160)
	var before := int(hero.hp)
	_play(foe, "soul_curse", 2.0)
	check(int(hero.hp) < before and game.player_effects.has(hero, "slow"), "a curse circle under the hero hurts and slows")
	# The same move, but the hero walks out of the circle in time.
	hero = _arena()
	foe = _foe("necromancer", 160)
	game.boss_moves._begin(foe, "soul_curse", game.boss_moves.move("soul_curse"), 1, hero)
	var zones: Array = game.boss_moves.snapshot()
	check(zones.any(func(zone: Dictionary) -> bool: return str(zone.k) == "strike" and str(zone.s) == "warn"), "the strike warns first (a circle clients draw)")
	hero.pos = Vector2(hero.pos) + Vector2(0, 90)
	if Dungeon.segment_blocked(Vector2(hero.pos), Vector2(hero.pos), 12.0, game.current_layout): hero.pos = Vector2(hero.pos) - Vector2(0, 180)
	before = int(hero.hp)
	var time := 0.0
	while time < 2.5:
		if foe.has("move"): game.boss_moves.step(foe, 1, DT)
		game.boss_moves.update(DT)
		time += DT
	check(int(hero.hp) == before, "who leaves the circle is spared")
	# A line of strikes runs out from the brute.
	hero = _arena()
	foe = _foe("moderkoloss", 120)
	game.boss_moves._begin(foe, "quake_line", game.boss_moves.move("quake_line"), 1, hero)
	check(game.boss_moves.zones.filter(func(zone: Dictionary) -> bool: return str(zone.kind) == "strike").size() >= 2, "the quake runs as a line of warnings")


func _test_projectile_moves() -> void:
	for pair: Array in [["frostleiche", "ice_fan", "ice", 5], ["knochenkoloss", "bone_spears", "bone_spear", 3], ["knochenkoloss", "skull_hail", "skull", 4], ["moderkoloss", "flesh_rain", "flesh", 15]]:
		_arena()
		var foe := _foe(str(pair[0]), 140)
		game.boss_moves._begin(foe, str(pair[1]), game.boss_moves.move(str(pair[1])), 1, game.players[1])
		while str(foe.move.phase) == "windup": game.boss_moves.step(foe, 1, DT)
		var shots: Array = game.bullets.filter(func(bullet: Dictionary) -> bool: return str(bullet.get("style", "")) == str(pair[2]))
		check(shots.size() >= int(pair[3]), "%s fires %d %s shots (%d)" % [pair[1], int(pair[3]), pair[2], shots.size()])
	# Ring with a gap: there is a way through.
	var ring: Array = game.bullets.filter(func(bullet: Dictionary) -> bool: return str(bullet.get("style", "")) == "flesh")
	check(ring.size() < int(game.boss_moves.move("flesh_rain").count), "the ring of flesh leaves a gap")
	# Spears fly through heroes; ice slows.
	var hero := _arena()
	var foe := _foe("frostleiche", 140)
	_play(foe, "ice_fan", 1.5)
	check(game.player_effects.has(hero, "slow") or int(hero.hp) < 200, "ice shards hit and slow")
	hero = _arena()
	foe = _foe("knochenkoloss", 140)
	_play(foe, "bone_spears", 0.6)
	var spears: Array = game.bullets.filter(func(bullet: Dictionary) -> bool: return str(bullet.get("style", "")) == "bone_spear" and Array(bullet.get("player_hits", [])).has(1))
	check(not spears.is_empty() or game.bullets.any(func(bullet: Dictionary) -> bool: return bool(bullet.get("pierce_players", false))), "bone spears fly on through a hero")
	# The spiral keeps firing while it lasts.
	hero = _arena()
	foe = _foe("", 200, true)
	game.boss_moves._begin(foe, "void_spiral", game.boss_moves.move("void_spiral"), 1, hero)
	var time := 0.0
	while foe.has("move") and time < 3.0:
		game.boss_moves.step(foe, 1, DT)
		time += DT
	check(game.bullets.filter(func(bullet: Dictionary) -> bool: return str(bullet.get("style", "")) == "void_skull").size() >= 15, "the void spiral pours out skulls")
	# A fire arrow leaves a blaze where it ends.
	hero = _arena()
	foe = _foe("skeleton_archer", 150)
	_play(foe, "fire_arrow", 2.0)
	check(game.boss_moves.zones.any(func(zone: Dictionary) -> bool: return str(zone.kind) == "pool" and str(zone.style) == "fire"), "a fire arrow leaves burning ground")


func _test_ground_and_body_moves() -> void:
	# Poison globs land and leave pools.
	var hero := _arena()
	var foe := _foe("moderkoloss", 160)
	_play(foe, "rot_globs", 1.6)
	check(game.boss_moves.zones.any(func(zone: Dictionary) -> bool: return str(zone.kind) == "pool" and str(zone.style) == "poison"), "rot globs leave poison pools")
	# The breath poisons in front.
	hero = _arena()
	foe = _foe("moderkoloss", 110)
	_play(foe, "rot_breath")
	check(game.player_effects.has(hero, "poison"), "the rot breath poisons the hero in front")
	var before := int(hero.hp)
	_settle(2.2)
	check(int(hero.hp) < before, "poison eats away at the hero over time")
	# A charge crosses the room.
	hero = _arena()
	foe = _foe("moderkoloss", 200, false, true)
	var start: Vector2 = foe.pos
	_play(foe, "charge")
	check(Vector2(foe.pos).distance_to(start) > 100.0, "the charge carries the brute across the room")
	# The vortex pulls, then bursts.
	hero = _arena()
	foe = _foe("", 200, true)
	var gap_before: float = Vector2(hero.pos).distance_to(foe.pos)
	_play(foe, "devour", 0.0, false)
	check(Vector2(hero.pos).distance_to(foe.pos) < gap_before - 40.0, "the vortex drags the hero in")
	# The grab throws.
	hero = _arena()
	foe = _foe("moderkoloss", 80)
	before = int(hero.hp)
	game.boss_moves._begin(foe, "grab", game.boss_moves.move("grab"), 1, hero)
	while foe.has("move") and str(foe.move.phase) == "windup": game.boss_moves.step(foe, 1, DT)
	check(int(hero.hp) < before and Vector2(hero.knockback).length() > 200.0, "the grab hurts and throws the hero")
	# The whirl hurts around the colossus.
	hero = _arena()
	foe = _foe("knochenkoloss", 70)
	before = int(hero.hp)
	_play(foe, "bone_whirl")
	check(int(hero.hp) < before, "the bone whirl hurts those close by")
	# The shadow step leaves a void pool behind.
	hero = _arena()
	foe = _foe("", 200, true)
	start = foe.pos
	_play(foe, "shadow_step")
	check(Vector2(foe.pos) != start and game.boss_moves.zones.any(func(zone: Dictionary) -> bool: return str(zone.kind) == "pool" and str(zone.style) == "void"), "the shadow step moves the boss and leaves a void pool")


func _test_blocks_and_summons() -> void:
	var hero := _arena()
	var foe := _foe("frostleiche", 200)
	_play(foe, "ice_wall")
	var blocks: Array = Array(game.chests.chests.get(str(game.current_layout.id), [])).filter(func(item: Dictionary) -> bool: return str(item.kind) == "ice_block")
	check(blocks.size() >= 2, "the ice wall raises blocks (%d)" % blocks.size())
	if not blocks.is_empty():
		var block: Dictionary = blocks[0]
		check(Dungeon.segment_blocked(block.pos, block.pos, 0.0, game.current_layout), "ice blocks stand in the way")
		for hit in range(int(block.max)): game.chests._hit(block, 1, Vector2.RIGHT)
		check(not Dungeon.segment_blocked(block.pos, block.pos, 0.0, game.current_layout), "hits break an ice block")
	hero = _arena()
	foe = _foe("knochenkoloss", 200)
	_play(foe, "bone_cage")
	var cage: Array = Array(game.chests.chests.get(str(game.current_layout.id), [])).filter(func(item: Dictionary) -> bool: return str(item.kind) == "bone_cage")
	check(cage.size() >= 3, "the bone cage closes around the hero (%d bars)" % cage.size())
	_settle(3.0)
	check(Array(game.chests.chests.get(str(game.current_layout.id), [])).filter(func(item: Dictionary) -> bool: return str(item.kind) == "bone_cage").is_empty(), "the cage falls apart by itself")
	hero = _arena()
	foe = _foe("moderkoloss", 200)
	_play(foe, "maggot_brood")
	check(game.enemies.filter(func(enemy: Dictionary) -> bool: return str(enemy.kind) == "tiny_zombie").size() >= 2, "the brute breeds maggots (mini zombies)")
	# Armour: half damage, then shards.
	hero = _arena()
	foe = _foe("frostleiche", 200)
	_play(foe, "ice_armor")
	check(game.boss_moves.damage_scale(foe) < 1.0, "the ice armour halves damage")
	_settle(4.5)
	check(game.boss_moves.damage_scale(foe) == 1.0 and game.bullets.any(func(bullet: Dictionary) -> bool: return str(bullet.get("style", "")) == "ice"), "the armour bursts into shards")
	# A necromancer shields an ally.
	hero = _arena()
	var ally := _foe("skeleton", 120)
	foe = _foe("necromancer", 200)
	_play(foe, "bone_shield")
	check(game.boss_moves.damage_scale(ally) < 1.0, "the bone shield protects a nearby ally")


func _test_rage_and_rebuild() -> void:
	var hero := _arena()
	var foe := _foe("moderkoloss", 200)
	foe.move_timer = 99.0
	foe.hp = float(foe.max_hp) * 0.2
	game.boss_moves.step(foe, 1, DT)
	check(bool(foe.get("rage", false)) and foe.has("move"), "low on HP the brute rages (roar)")
	# Knochenkoloss: falls apart, rises unless the skull breaks.
	hero = _arena()
	foe = _foe("knochenkoloss", 200)
	game._damage_enemy(foe, float(foe.max_hp) * 3.0, Vector2.RIGHT, 1)
	check(float(foe.hp) > 0.0 and float(foe.get("collapsed", 0.0)) > 0.0, "the bone colossus falls apart instead of dying")
	_settle(3.2)
	check(float(foe.get("collapsed", 0.0)) <= 0.0 and float(foe.hp) >= float(foe.max_hp) * 0.25, "untouched, it rises again with part of its HP")
	game._damage_enemy(foe, float(foe.max_hp) * 3.0, Vector2.RIGHT, 1)
	check(float(foe.hp) <= 0.0, "the second fall is final")
	hero = _arena()
	foe = _foe("knochenkoloss", 200)
	game._damage_enemy(foe, float(foe.max_hp) * 3.0, Vector2.RIGHT, 1)
	game._damage_enemy(foe, float(foe.max_hp), Vector2.RIGHT, 1)
	check(float(foe.hp) <= 0.0, "smashing its skull ends it for good")


func _test_beam_runs_to_the_wall() -> void:
	var hero := _arena()
	var foe := _foe("", 120, true)
	foe.beam_angle = 0.0
	var longest := 0.0
	for angle: float in [0.0, PI * 0.5, PI, PI * 1.5]:
		foe.beam_angle = angle
		game.void_ai._update_beam(foe)
		var end: Vector2 = foe.beam_to
		longest = maxf(longest, end.distance_to(foe.pos))
		var beyond: Vector2 = end + Vector2.from_angle(angle) * 12.0
		check(Dungeon.segment_blocked(end, beyond, 2.0, game.current_layout), "the beam ends at a wall (angle %.1f)" % angle)
	check(longest > 0.0, "the beam reaches out (%.0f px)" % longest)
	foe.twin_beam = 0.35
	game.void_ai._update_beam(foe)
	check(foe.has("beam_to_b") and Vector2(foe.beam_to).distance_to(foe.beam_to_b) > 20.0, "in rage the beam splits in two")


func _test_hero_conditions() -> void:
	var hero := _arena()
	var effects = game.player_effects
	effects.apply(hero, "slow", 2.0, 0.5)
	check(is_equal_approx(effects.move_scale(hero), 0.5), "slow halves the walking speed")
	effects.apply(hero, "freeze", 1.0, 1.0)
	check(effects.move_scale(hero) == 0.0 and not effects.can_act(hero), "a frozen hero can neither move nor attack")
	effects.clear(hero)
	effects.apply(hero, "burn", 3.0, 1.0)
	var before := int(hero.hp)
	_settle(2.1)
	check(int(hero.hp) <= before - 2, "burning hurts once a second")
	_settle(1.5)
	check(not effects.has(hero, "burn"), "conditions wear off")
	var snapshot: Dictionary = game._make_snapshot()
	check(snapshot.has("boss_zones") and snapshot.players[1].has("effects"), "clients see zones and hero conditions")
