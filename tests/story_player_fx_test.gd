extends SceneTree
## The hero's effects in the story worlds are the crypt's (src/hero/story_feel.gd,
## docs/VFX-SYSTEM.de.md): in the Hell-Dungeon and the Frostgruft a hit, a block
## and a Frostgruft kill raise no world embers next to the crypt's reaction; a
## level-up is the crypt's sheet, pillar and bloom; the mage's splash is the
## crypt's area perk; potions are the crypt's item events in their colours and
## thrown pools the crypt's pools; chests, the vault and pickups open and chime
## like the crypt's; shots and blades meeting a wall chip, crack and clang by the
## crypt's wall hit (bisected contact, normal, at most 8 fresh); a pit hurts like
## a hit without a red screen; heals, revives, shields and crits show the crypt's
## markers; conditions are the crypt's boss_fx.gd; the shockwave, charge hits and
## wall slams are the crypt's skill events; heaps and seals chip and break like
## the crypt's; the clone appears in a cleanse; a dead hero falls; casts kick.
## The crypt values kept inline in its own code (blink, shadow, markers, wall-hit
## limits, chest shake) are read from its source. Sounds go to a recording player.

const HellScene = preload("res://src/hell/hell_dungeon.tscn")
const FrostScene = preload("res://src/hell/frost_dungeon.tscn")
const HeroKit = preload("res://src/hell/hero_kit.gd")
const HeroFx = preload("res://src/hell/hero_fx.gd")
const StoryFeel = preload("res://src/hero/story_feel.gd")
const BossFx = preload("res://src/vfx/boss_fx.gd")
const DT := 1.0 / 60.0
const SAVE := "user://story_player_fx_meta.cfg"
const GRAPHICS := "user://story_player_fx_graphics.cfg"

var checked := 0
var failures: Array[String] = []
var table: Dictionary = {}


class FakeSfx extends Node:
	## Records every play; knows the sound table's events.
	var played: Array[String] = []
	var known: Dictionary = {}
	var rig_materials: Dictionary = {}
	func has_effect(name: String) -> bool:
		return known.has(name)
	func play(name: String, _spread: float = 0.0, _category: String = "") -> void:
		played.append(name)
	func reset() -> void:
		played.clear()
	func count(name: String) -> int:
		return played.count(name)


func check(condition: bool, label: String) -> void:
	checked += 1
	if not condition:
		failures.append(label)
		printerr("STORY_PLAYER_FX_FAIL: ", label)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	table = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/audio_sfx.json"))
	test_crypt_parity()
	for spec: Array in [[HellScene, "hell"], [FrostScene, "frost"]]:
		await test_combat_has_no_world_embers(spec[0], spec[1])
		await test_level_up(spec[0], spec[1])
		await test_mage_splash(spec[0], spec[1])
		await test_potions_and_pools(spec[0], spec[1])
		await test_chests_and_pickups(spec[0], spec[1])
		await test_wall_hits(spec[0], spec[1])
		await test_hurts_pits_and_markers(spec[0], spec[1])
		await test_conditions_casts_death_and_clone(spec[0], spec[1])
		await test_swordsman(spec[0], spec[1])
		await test_heaps_and_seals(spec[0], spec[1])
	await test_frost_kill()
	for path: String in [SAVE, GRAPHICS]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("STORY_PLAYER_FX checked=%d failures=%d" % [checked, failures.size()])
	quit(1 if failures.size() > 0 else 0)


# --- helpers ------------------------------------------------------------------------------

func _open(scene: PackedScene, class_id: String) -> Node:
	var game: Node = scene.instantiate()
	game.start_floor = 2
	game.class_id = class_id
	game.meta_path = SAVE
	game.graphics_path = GRAPHICS
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.mobs.clear()
	game.eshots.clear()
	game.state.offer = []
	var fake := FakeSfx.new()
	for name: String in table.events:
		fake.known[name] = true
	fake.rig_materials = table.get("rig_materials", {})
	if game.sfx != null:
		game.sfx.queue_free()
	game.add_child(fake)
	game.sfx = fake
	game.state.inv = 99.0
	game.feel.update(DT)
	game.embers.clear()
	fake.reset()
	return game


func _free(game: Node) -> void:
	game.queue_free()
	await process_frame


func _frames(game: Node, n: int, dt := DT) -> void:
	for i in range(n):
		game.feel.update(dt)


## A monster of the world `offset` from the hero, ready to be hit.
func _mob(game: Node, offset: Vector2) -> Dictionary:
	var at := Vector2(game.player.x, game.player.y) + offset
	if game.monsters != null:
		var m: Dictionary = game.monsters.spawn(game.state.room, at, "glutschaedel", false)
		m.spawn = 0.0
		m.hp = 9999.0
		m.max = 9999.0
		for i in range(m.cds.size()):
			m.cds[i] = 99.0
		return m
	game._spawn_mob(game.state.room, at, str(game.theme.mobs.keys().filter(func(k: String) -> bool: return not k.begins_with("_"))[0]))
	var f: Dictionary = game.mobs[game.mobs.size() - 1]
	f.spawn = 0.0
	f.hp = 9999.0
	f.max = 9999.0
	f.shoot = 99.0
	return f


func _shot(game: Node, kind: String, at: Vector2, v: Vector2, splash := 0.0) -> Dictionary:
	var s := {"p": at, "v": v, "t": 2.0, "kind": kind, "splash": splash, "hits": []}
	game.shots.append(s)
	return s


func _raised(game: Node, kind: String) -> Array:
	return (game.feel._events as Array).filter(func(e: Dictionary) -> bool: return str(e.kind) == kind)


func _gold(game: Node) -> int:
	return (game.embers as Array).filter(func(e: Dictionary) -> bool: return bool(e.gold)).size()


func _index(game: Node, type: String, id: String = "") -> int:
	var bag: Array = game.story_items.players[1].inventory.bag
	for i in range(bag.size()):
		if str(bag[i].type) == type and (id == "" or str(bag[i].get("id", bag[i].get("potion", ""))) == id): return i
	return -1


## A floor cell with a straight wall right of it (wall above and below too) and no props: [cx, cy].
func _wall_cell(game: Node) -> Vector2i:
	var best := Vector2i(-1, -1)
	var me: Vector2 = Vector2(game.player.x, game.player.y) / float(game.C)
	for cy in range(1, int(game.W.rows) - 1):
		for cx in range(1, int(game.W.cols) - 1):
			var ok: bool = game._cell(cx, cy) == 1 and game._cell(cx - 1, cy) == 1 and game._cell(cx, cy - 1) == 1 and game._cell(cx, cy + 1) == 1
			ok = ok and game._cell(cx + 1, cy) == 0 and game._cell(cx + 1, cy - 1) == 0 and game._cell(cx + 1, cy + 1) == 0
			ok = ok and (game.solid_grid as Dictionary).get(cy * int(game.W.cols) + cx, []).is_empty() and not game.door_at.has(cy * int(game.W.cols) + cx + 1)
			if ok and (best.x < 0 or Vector2(cx, cy).distance_to(me) < Vector2(best).distance_to(me)):
				best = Vector2i(cx, cy)
	return best


# --- the crypt's inline values --------------------------------------------------------------

func test_crypt_parity() -> void:
	var view := FileAccess.get_file_as_string("res://src/dungeon_view.gd")
	check(view.contains("pose.alpha *= 0.45 if fmod(_clock, 0.16) < 0.08 else 1.0") and view.contains("fmod(_clock, 0.24) < 0.12")
		and is_equal_approx(StoryFeel.INVULN_ALPHA, 0.45) and is_equal_approx(StoryFeel.INVULN_BLINK, 0.16) and is_equal_approx(StoryFeel.HIT_FRAME, 0.24),
		"the invulnerability blink and hit frame match dungeon_view.gd (0.45 every 0.08 of 0.16 s, the hit frame 0.12 of 0.24 s)")
	check(view.contains("_box(point.x-half_width,point.y+12,half_width*2,8,Color(0.05,0.04,0.09,0.55))") and view.contains("_draw_shadow(_position(player), 14.0)")
		and StoryFeel.SHADOW_COLOR == Color(0.05, 0.04, 0.09) and is_equal_approx(StoryFeel.SHADOW_HALF, 14.0), "the hero's shadow matches dungeon_view.gd _draw_shadow")
	check(view.contains("Color(\"f6cf85\") if kind in [\"blast\",\"crit\"] else Color(\"a7ddaa\") if kind in [\"heal\",\"poison\"] else Color(\"a7cce8\")")
		and view.contains("var radius: float = 16 if kind in [\"shield\",\"crit\"] else 28")
		and StoryFeel.PERK_GOLD == Color("f6cf85") and StoryFeel.PERK_GREEN == Color("a7ddaa") and StoryFeel.PERK_BLUE == Color("a7cce8"), "the perk markers match dungeon_view.gd _draw_perk_events")
	var crypt := FileAccess.get_file_as_string("res://src/game.gd")
	check(crypt.contains("if recent >= 8: return") and crypt.contains("\"life\":0.6") and StoryFeel.WALL_HITS == 8 and is_equal_approx(StoryFeel.EVENT_LIFE, 0.6),
		"the wall-hit limit and the fx event life match game.gd (8 fresh, 0.6 s)")
	check(crypt.contains("if skill == \"fireball\": return \"fire\"") and crypt.contains("if skill == \"fist\": return \"frost\"") and crypt.contains("if skill == \"wave\": return \"metal\"")
		and crypt.contains("\"magic\": return \"magic\"") and crypt.contains("\"roar\": return \"stone\""), "the shot wall styles follow game.gd _shot_style")
	check(StoryFeel.shot_wall_style({"kind": "fireball"}) == "fire" and StoryFeel.shot_wall_style({"kind": "fist"}) == "frost" and StoryFeel.shot_wall_style({"kind": "wave"}) == "metal"
		and StoryFeel.shot_wall_style({"kind": "magic"}) == "magic" and StoryFeel.shot_wall_style({"kind": "arrow"}) == "arrow" and StoryFeel.shot_wall_style({}) == "arrow",
		"story shots take the crypt's wall styles")
	var skill := FileAccess.get_file_as_string("res://src/vfx/skill_fx.gd")
	check(skill.contains("sin(since * 60.0) * 3.0 * maxf(0.0, 1.0 - since * 4.0)") and is_equal_approx(StoryFeel.hit_shake(0.0), 0.0)
		and absf(StoryFeel.hit_shake(0.02)) > 0.5 and is_equal_approx(StoryFeel.hit_shake(0.3), 0.0) and is_equal_approx(StoryFeel.hit_shake(0.02, false), 0.0),
		"a struck heap shakes like skill_fx.gd draw_chest (gone after 0.25 s)")
	# the blink at three moments: 45 % with the hit frame, full with the hit frame, full without
	var a := StoryFeel.invulnerable_look(0.05)
	var b := StoryFeel.invulnerable_look(0.1)
	var c := StoryFeel.invulnerable_look(0.13)
	var d := StoryFeel.invulnerable_look(0.17)
	check(is_equal_approx(float(a.alpha), 0.45) and bool(a.hit) and is_equal_approx(float(b.alpha), 1.0) and bool(b.hit)
		and is_equal_approx(float(c.alpha), 1.0) and not bool(c.hit) and is_equal_approx(float(d.alpha), 0.45) and not bool(d.hit), "the blink runs at the crypt's periods")


# --- hits, blocks and kills ---------------------------------------------------------------

func test_combat_has_no_world_embers(scene: PackedScene, world: String) -> void:
	var game: Node = await _open(scene, "archer")
	var m := _mob(game, Vector2(220, -10))
	# the feel sees the monster before the blow (as every frame in the game)
	_frames(game, 1)
	var target: Vector2 = (m.p as Vector2) - Vector2(0, float(m.cy))
	_shot(game, "arrow", target - Vector2(30, 0), Vector2(900, 0))
	var hp := float(m.hp)
	game._update_shots(DT)
	check(float(m.hp) < hp, "%s: the arrow hits the monster" % world)
	check(game.embers.is_empty(), "%s: a hit raises no world embers next to the crypt's reaction (%d)" % [world, game.embers.size()])
	_frames(game, 1)
	check(game.feel.feedback.particles.count() > 0, "%s: the crypt's sparks and drops fly" % world)
	# a shield bearer's block: the crypt's sparks only
	m.def = (m.def as Dictionary).duplicate()
	m.def.behavior = "shield"
	m.def.shield_arc = 3.0
	m.face = Vector2.LEFT
	game.embers.clear()
	var blocked: bool = not game._damage_mob(m, Vector2(600, 0))
	check(blocked and game.embers.is_empty() and int(m.get("feel_blocks", 0)) >= 1, "%s: a block is the crypt's alone (no gold embers)" % world)
	await _free(game)


## The Frostgruft's own monsters die in the world's update: the crypt's kill alone.
func test_frost_kill() -> void:
	var game: Node = await _open(FrostScene, "archer")
	var m := _mob(game, Vector2(220, 0))
	_mob(game, Vector2(-400, 0))
	_frames(game, 1)
	m.hp = 0.0
	game.embers.clear()
	game._update_mobs(DT)
	check(not game.mobs.has(m) and game.embers.is_empty(), "frost: a kill raises no world embers (%d)" % game.embers.size())
	_frames(game, 1)
	check(game.feel.frozen() and game.feel.feedback.particles.count() > 0, "frost: the crypt's kill bursts and holds the picture")
	await _free(game)


# --- level-up -----------------------------------------------------------------------------

func test_level_up(scene: PackedScene, world: String) -> void:
	var game: Node = await _open(scene, "mage")
	var kit: RefCounted = game.story_hero.skill_fx
	var level := int(game.state.level)
	var fx_before: int = kit.fx.count()
	HeroKit.gain(game, HeroKit.need(game.theme.leveling, level) - int(game.state.exp))
	check(int(game.state.level) == level + 1 and not game.levelfx.is_empty(), "%s: the hero levels up" % world)
	check(_gold(game) == 0, "%s: the level-up raises none of the world's gold embers" % world)
	_frames(game, 1)
	var ups: Array = (kit.snapshot.get("fx_events", []) as Array).filter(func(e: Dictionary) -> bool: return str(e.kind) == "level_up")
	check(ups.size() == 1 and float(ups[0].life) > 0.0 and float(ups[0].life) <= StoryFeel.EVENT_LIFE, "%s: the skill kit sees the level-up with its life (pillar, ring, bloom)" % world)
	var at := Vector2(float(ups[0].x), float(ups[0].y)) if ups.size() == 1 else Vector2.ZERO
	check(at.is_equal_approx(Vector2(game.player.x, game.player.y + StoryFeel.SPRITE_DROP) / game.feel.scale - Vector2(0, StoryFeel.HERO_POINT)), "%s: at the crypt's hero point (16 px over the drawn feet)" % world)
	check(kit.fx.count() > fx_before, "%s: the crypt's level-up sheet plays" % world)
	# the shadow lies around the drawn feet like the crypt's (4 px over them to 4 px under)
	var shadow: Vector2 = game.feel.hero_world() / float(game.feel.scale) + Vector2(0, 16)
	check(is_equal_approx(shadow.y * game.feel.scale, float(game.player.y) + StoryFeel.SPRITE_DROP), "%s: the shadow centres on the drawn feet" % world)
	_frames(game, 50)
	check((kit.snapshot.get("fx_events", []) as Array).filter(func(e: Dictionary) -> bool: return str(e.kind) == "level_up").is_empty(), "%s: the pillar is gone after its life" % world)
	await _free(game)


# --- the mage's splash --------------------------------------------------------------------

func test_mage_splash(scene: PackedScene, world: String) -> void:
	var game: Node = await _open(scene, "mage")
	var m := _mob(game, Vector2(240, -10))
	var target: Vector2 = (m.p as Vector2) - Vector2(0, float(m.cy))
	var fx_before: int = game.story_hero.skill_fx.fx.count()
	_shot(game, "magic", target - Vector2(30, 0), Vector2(900, 0), 110.0)
	game._update_shots(DT)
	var blasts: Array = (game.feel.perk_events() as Array).filter(func(e: Dictionary) -> bool: return str(e.kind) == "blast")
	check(blasts.size() == 1 and int(blasts[0].o) == 1, "%s: the splash is the crypt's area perk of the hero" % world)
	check((game.fx as Array).filter(func(f: Dictionary) -> bool: return str(f.kind) == "blast").is_empty() and game.embers.is_empty(), "%s: no world circle and no embers" % world)
	(game.sfx as FakeSfx).reset()
	_frames(game, 1)
	check(game.story_hero.skill_fx.fx.count() > fx_before and (game.sfx as FakeSfx).count("blast") == 1, "%s: feedback.gd bursts it (magic burst) with one blast" % world)
	await _free(game)


# --- potions and pools --------------------------------------------------------------------

func test_potions_and_pools(scene: PackedScene, world: String) -> void:
	var game: Node = await _open(scene, "mage")
	var items: Node = game.story_items
	items.give(items.inventory.make_stack("potion", "fire"), Vector2.ZERO)
	items.act("inv_throw", _index(game, "potion", "fire"), Vector2(game.player.x + 240, game.player.y))
	var thrown := _raised(game, "potion_throw")
	check(thrown.size() == 1 and str(thrown[0].get("color", "")) != "" and float(thrown[0].get("r", 0.0)) > 10.0, "%s: a thrown potion is the crypt's potion_throw in its colour" % world)
	check((game.fx as Array).filter(func(f: Dictionary) -> bool: return str(f.kind) == "blast").is_empty() and _gold(game) == 0, "%s: no world circle, no gold embers" % world)
	check(items.pools.size() == 1 and str(items.pools[0].get("style", "")) == "fire" and float(items.pools[0].get("max", 0.0)) > 0.0, "%s: the fire pool keeps its style and time" % world)
	var zones: Array = game.feel.condition_snapshot().boss_zones
	check(zones.size() == 1 and str(zones[0].k) == "pool" and str(zones[0].st) == "fire" and float(zones[0].p) >= 0.0 and float(zones[0].p) <= 1.0, "%s: the pool is the crypt's boss_fx pool" % world)
	_frames(game, 1)
	check(game.feel.feedback.particles.count() > 0, "%s: the potion bursts in the crypt's particles" % world)
	items.give(items.inventory.make_stack("potion", "healing"), Vector2.ZERO)
	game.state.hp = 2
	items.act("inv_use", _index(game, "potion", "healing"))
	check(_raised(game, "drink").size() == 1 and _gold(game) == 0, "%s: drinking is the crypt's drink" % world)
	await _free(game)


# --- chests, the vault, pickups -----------------------------------------------------------

func test_chests_and_pickups(scene: PackedScene, world: String) -> void:
	var game: Node = await _open(scene, "mage")
	var fake: FakeSfx = game.sfx
	var chest := {"type": "chest", "x": game.player.x, "y": game.player.y, "room": int(game.state.room), "loot": {"gems": 3, "heart": true}, "magic": false}
	game.W.ents.append(chest)
	game.state.hp = int(game.state.max_hp) - 2
	game.act()
	check(str(chest.get("state", "")) == "open" and _raised(game, "chest_open").size() == 1 and _gold(game) == 0, "%s: a chest opens like the crypt's (chest_open)" % world)
	fake.reset()
	_frames(game, 1)
	check(fake.count("chest_open") == 1, "%s: it sounds once, the crypt's chest_open (%s)" % [world, str(fake.played)])
	game.act()
	check(str(chest.get("state", "")) == "empty" and _raised(game, "loot_taken").size() == 1, "%s: taking its loot is the crypt's loot_taken" % world)
	check((game.feel.perk_events() as Array).any(func(e: Dictionary) -> bool: return str(e.kind) == "heal"), "%s: its heart heals with the crypt's marker" % world)
	game.W.ents.erase(chest)
	var vault := {"type": "vault", "x": game.player.x, "y": game.player.y, "room": int(game.state.room)}
	game.W.ents.append(vault)
	game.act()
	check(bool(vault.get("opened", false)) and _raised(game, "chest_open").size() == 2 and _gold(game) == 0, "%s: the vault opens like the crypt's chests" % world)
	game.W.ents.erase(vault)
	# a find lying on the floor (full bag) is picked up like the crypt's loot
	var items: Node = game.story_items
	items.floor_items.append({"item": items.inventory.make_stack("potion", "healing"), "p": Vector2(game.player.x + 20, game.player.y), "born": 0.0})
	items.update(DT)
	check(items.floor_items.is_empty() and _raised(game, "loot_taken").size() == 2, "%s: a find on the floor is the crypt's pickup" % world)
	await _free(game)


# --- wall hits ----------------------------------------------------------------------------

func test_wall_hits(scene: PackedScene, world: String) -> void:
	var game: Node = await _open(scene, "archer")
	var cell := _wall_cell(game)
	check(cell.x >= 0, "%s: a straight wall to shoot at" % world)
	if cell.x < 0:
		await _free(game)
		return
	var C: float = game.C
	var from := Vector2((cell.x + 0.4) * C, (cell.y + 0.5) * C)
	var to := Vector2((cell.x + 1.4) * C, (cell.y + 0.5) * C)
	check(game.feel.wall_hit(from, to, "arrow", 1), "%s: a wall hit is raised" % world)
	var hits := _raised(game, "wall_hit")
	var e: Dictionary = hits[0] if hits.size() == 1 else {}
	check(hits.size() == 1 and Vector2(float(e.nx), float(e.ny)).is_equal_approx(Vector2.LEFT), "%s: its normal points back to the floor (%s)" % [world, str(e)])
	check(absf(float(e.get("x", 0.0)) * game.feel.scale - (cell.x + 1) * C) < 2.0, "%s: at the wall's face, found by bisection" % world)
	var marks: int = game.feel.feedback.particles.stain_count()
	_frames(game, 1)
	check(game.feel.feedback.particles.stain_count() > marks, "%s: the crypt's crack stays on the wall" % world)
	# the world's own arrow: the crypt's wall hit, no embers
	_frames(game, 10, 0.05)
	game.feel._events.clear()
	_shot(game, "arrow", from, Vector2(1200, 0))
	for i in range(20):
		game._update_shots(DT)
	check(_raised(game, "wall_hit").size() == 1 and str(_raised(game, "wall_hit")[0].style) == "arrow" and int(_raised(game, "wall_hit")[0].get("o", 0)) == 1 and game.embers.is_empty(),
		"%s: an arrow into the wall is the crypt's wall hit of the hero, no embers" % world)
	# at most eight fresh ones at once
	for i in range(20):
		game.feel.wall_hit(from, to, "arrow", 1)
	check(_raised(game, "wall_hit").size() == StoryFeel.WALL_HITS, "%s: at most 8 fresh wall hits (%d)" % [world, _raised(game, "wall_hit").size()])
	# an enemy shot of the world's own style
	check(game.feel.enemy_wall_style({"style": "ice"}) == "frost" and game.feel.enemy_wall_style({}) == ("frost" if world == "frost" else "fire"), "%s: enemy shots splash in their style" % world)
	await _free(game)


# --- hurts, pits, markers -----------------------------------------------------------------

func test_hurts_pits_and_markers(scene: PackedScene, world: String) -> void:
	var game: Node = await _open(scene, "mage")
	var feel: RefCounted = game.feel
	game.state.inv = 0.0
	game.state.hp = int(game.state.max_hp)
	var hurts := int(feel._hurts)
	game._hurt("Test", 1, Vector2(game.player.x - 200, game.player.y))
	check(int(feel._hurts) == hurts + 1 and float(game.state.flash) == 0.0, "%s: a hurt is the crypt's, without a red screen" % world)
	check((feel._hurt_dir as Vector2).x > 0.5, "%s: its blood splats away from the blow" % world)
	_frames(game, 30, 0.05)
	game.state.inv = 0.0
	hurts = int(feel._hurts)
	game._fall_into_pit()
	check(int(feel._hurts) == hurts + 1 and float(game.state.flash) == 0.0 and game.embers.is_empty(), "%s: a pit hurts like a hit, without a red screen or embers" % world)
	_frames(game, 1)
	check(feel.frozen(), "%s: the fall holds the picture (the crypt's hitstop)" % world)
	_frames(game, 30, 0.05)
	# a heart on the floor: the crypt's heal marker for its event time
	game.state.hp = int(game.state.max_hp) - 2
	game.W.ents.append({"type": "heart", "x": game.player.x, "y": game.player.y, "room": int(game.state.room)})
	game._update_hazards(DT)
	var heals: Array = (feel.perk_events() as Array).filter(func(e: Dictionary) -> bool: return str(e.kind) == "heal")
	check(heals.size() == 1 and is_equal_approx(float(heals[0].time), 0.22), "%s: a heart heals with the crypt's marker (0.22 s)" % world)
	_frames(game, 1, 0.3)
	check((feel.perk_events() as Array).is_empty(), "%s: the marker goes after its time" % world)
	# the shield potion stops a hit: the crypt's shield marker
	var runtime: Dictionary = game.story_items.players[1].get("perk_runtime", {})
	runtime["shield"] = 1
	game.story_items.players[1]["perk_runtime"] = runtime
	game.state.inv = 0.0
	game._hurt("Test", 1)
	check((feel.perk_events() as Array).any(func(e: Dictionary) -> bool: return str(e.kind) == "shield") and _gold(game) == 0, "%s: a shield stops the hit with the crypt's marker" % world)
	# the phoenix: the crypt's revive marker
	game.state.inv = 0.0
	game.state.hp = 1
	game.state.phoenix_life = true
	game._hurt("Test", 2)
	check(int(game.state.hp) > 0 and (feel.perk_events() as Array).any(func(e: Dictionary) -> bool: return str(e.kind) == "revive") and _gold(game) == 0, "%s: the phoenix lifts the hero with the crypt's revive marker" % world)
	# a critical hit: the crypt's gold ring at the monster
	var m := _mob(game, Vector2(200, 0))
	game.story_items.players[1].build["crit"] = 1.0
	game._damage_mob(m, Vector2(500, 0))
	check((feel.perk_events() as Array).any(func(e: Dictionary) -> bool: return str(e.kind) == "crit"), "%s: a critical hit shows the crypt's crit marker" % world)
	game.story_items.players[1].build.erase("crit")
	await _free(game)


# --- conditions, casts, death, the clone --------------------------------------------------

func test_conditions_casts_death_and_clone(scene: PackedScene, world: String) -> void:
	var game: Node = await _open(scene, "mage")
	var feel: RefCounted = game.feel
	HeroFx.apply(game, "poison", 5.0, 1.0)
	game.story_items.effects["slow"] = {"t": 5.0, "value": 0.5}
	var hero: Dictionary = feel.condition_snapshot().players[1]
	check("poison" in hero.effects and "slow" in hero.effects, "%s: the hero's conditions reach the crypt's boss_fx.gd (%s)" % [world, str(hero.effects)])
	check(feel.boss_fx.get_script() == BossFx, "%s: drawn by the crypt's boss_fx.gd" % world)
	HeroFx.clear(game)
	game.story_items.effects.clear()
	# a skill cast: the crypt's cast kick on the hero
	_frames(game, 30, 0.05)
	var casts := int(feel._casts)
	game.state.skill_cd["1"] = 5.0
	_frames(game, 1)
	check(int(feel._casts) == casts + 1 and (feel.hero_pose().scale as Vector2) != Vector2.ONE, "%s: a cast kicks the hero like the crypt's" % world)
	# the clone appears in the crypt's cleanse
	game.state.skill = {"owned": true, "active": false, "left": 20.0}
	game.use_skill()
	check(not (game.clone as Dictionary).is_empty() and _raised(game, "cleanse").size() == 1 and _gold(game) == 0, "%s: the clone appears in the crypt's cleanse" % world)
	game.state.skill.left = 0.01
	game._update_clone(0.05)
	check((game.clone as Dictionary).is_empty() and _raised(game, "blink").size() == 1 and game.embers.is_empty(), "%s: and fades like the crypt's blink" % world)
	# a dead hero falls and stays lying
	game.state.hp = 0
	game.state.dead = 1.8
	_frames(game, 6, 0.1)
	var pose: Dictionary = feel.hero_pose()
	check((pose.scale as Vector2).y < 0.7 and (pose.scale as Vector2).x > 1.0 and float(pose.alpha) > 0.9, "%s: the dead hero falls flat like the crypt's, still visible (%s)" % [world, str(pose.scale)])
	await _free(game)


# --- the swordsman: blade on walls, shockwave, charge, wall slam ---------------------------

func test_swordsman(scene: PackedScene, world: String) -> void:
	var game: Node = await _open(scene, "swordsman")
	var kit: RefCounted = game.story_hero.skill_fx
	var fake: FakeSfx = game.sfx
	var cell := _wall_cell(game)
	if cell.x >= 0:
		var C: float = game.C
		game.player.x = (cell.x + 0.75) * C
		game.player.y = (cell.y + 0.5) * C + 40.0
		game._swing(Vector2.RIGHT)
		var hits := _raised(game, "wall_hit")
		check(hits.size() == 1 and str(hits[0].style) == "metal", "%s: a blade meeting the wall is the crypt's metal wall hit" % world)
		fake.reset()
		_frames(game, 1)
		check(fake.count("block") == 1, "%s: it clangs once (%s)" % [world, str(fake.played)])
	# the charge's shockwave: the crypt's stone burst instead of the violet quake
	var events := func(kind: String) -> Array: return (kit._events as Array).filter(func(e: Dictionary) -> bool: return str(e.kind) == kind)
	game.fx.clear()
	game.on_dash_land("shockwave")
	check(events.call("burst").any(func(e: Dictionary) -> bool: return str(e.color) == "stone") and (game.fx as Array).filter(func(f: Dictionary) -> bool: return str(f.kind) == "quake").is_empty(),
		"%s: the shockwave lands as the crypt's stone burst" % world)
	# a charge striking through a monster: the crypt's charge_hit
	var m := _mob(game, Vector2(80, 0))
	game.dash = {"t": 0.2, "dir": Vector2.RIGHT, "speed": 900.0, "mult": 1.5, "hit": [m]}
	game._damage_mob(m, Vector2.RIGHT * 500.0, 1.5)
	check(events.call("charge_hit").size() == 1, "%s: a charge hit is the crypt's charge_hit" % world)
	game.dash = {}
	# a thrown body slamming into a wall: the crypt's wall slam instead of the quake ring
	m.slam = 0.4
	m.k = Vector2(900, 0)
	var slams: Dictionary = game._slams_before()
	m.erase("slam")
	game.fx.append({"kind": "quake", "p": m.p, "r": 48.0, "t": 0.3, "max": 0.3})
	game._slams_after(slams)
	var slam: Array = events.call("wall_slam")
	check(slam.size() == 1 and is_equal_approx(float(slam[0].angle), 0.0) and (game.fx as Array).filter(func(f: Dictionary) -> bool: return str(f.kind) == "quake").is_empty(),
		"%s: a wall slam is the crypt's wall_slam" % world)
	await _free(game)


# --- skull heaps and seals ----------------------------------------------------------------

func test_heaps_and_seals(scene: PackedScene, world: String) -> void:
	var game: Node = await _open(scene, "mage")
	var kit: RefCounted = game.story_hero.skill_fx
	var feel: RefCounted = game.feel
	var cell := _wall_cell(game)
	var wall := Vector2i(cell.x + 1, cell.y)
	var room := int(game.state.room)
	game.W.doors.append({"kind": "secret", "cells": [wall], "broken": false, "a": room, "b": room, "cx": (wall.x + 0.5) * float(game.C), "cy": (wall.y + 0.5) * float(game.C), "dir": "v", "group": "", "x0": wall.x, "x1": wall.x, "y0": wall.y, "y1": wall.y})
	var heap := {"type": "skullheap", "x": game.player.x + 120.0, "y": game.player.y, "hp": 2, "max_hp": 2, "door": game.W.doors.size() - 1}
	var sheets: int = kit.fx.count()
	game._hit_breakable(heap, Vector2(heap.x, heap.y - 40))
	check(kit.fx.count() > sheets and game.embers.is_empty(), "%s: a blow chips the heap with the crypt's stone burst, no embers" % world)
	check(absf(StoryFeel.hit_shake(0.15 - float(heap.hit))) < 0.01 and absf(StoryFeel.hit_shake(0.03)) > 0.0, "%s: the heap shakes by the crypt's chest shake" % world)
	game._hit_breakable(heap, Vector2(heap.x, heap.y - 40))
	check(bool(heap.get("broken", false)) and _raised(game, "wall_break").size() == 1 and game.embers.is_empty(), "%s: its fall opens the wall with one wall_break per cell, no embers" % world)
	var inside: Vector2 = Vector2((wall.x + 0.5) * float(game.C), (wall.y + 0.5) * float(game.C)) / float(feel.scale)
	check(not feel.feedback.particles.solid(inside) and not kit.particles.solid(inside), "%s: the opened cell is floor for the crypt's rubble" % world)
	_frames(game, 1)
	check(float(feel.feedback.shake) > 0.0, "%s: the wall break shakes the picture" % world)
	# a seal: a blessing shines (cleanse), released demons flare (curse)
	var seal := {"type": "seal", "x": game.player.x - 150.0, "y": game.player.y, "hp": 1, "max_hp": 1, "room": int(game.state.room)}
	game.breakables.append(seal)
	game._hit_breakable(seal, Vector2(seal.x, seal.y - 40))
	check(bool(seal.get("broken", false)) and _raised(game, "cleanse").size() + _raised(game, "curse").size() == 1 and _gold(game) == 0, "%s: a broken seal blesses or curses like the crypt's" % world)
	await _free(game)
