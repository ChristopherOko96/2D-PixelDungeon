extends SceneTree
## The run talent tree (src/progress/run_tree.gd, docs/LAUF-DESIGN.de.md 3.4)
## in every world: one point per level; a branch per skill (open from the
## skill's level) and one for passives; the first two nodes of a branch are
## free, the rest need 2 points in it; nodes stop at their max. In the crypt a
## level-up no longer offers cards (boss perks stay) and the host spends points
## through the "talent" action; in the Hell-Dungeon and the Frostgruft the
## theme cards are the nodes, a level-up gives a point instead of three cards,
## B opens the tree and a click there spends a point instead of firing.

const RunTree = preload("res://src/progress/run_tree.gd")
const ClassPerks = preload("res://src/player/class_perks.gd")
const CardKit = preload("res://src/hell/card_kit.gd")
const HeroKit = preload("res://src/hell/hero_kit.gd")
const RunTreeView = preload("res://src/ui/run_tree_view.gd")
const MetaStore = preload("res://src/hell/meta_store.gd")
const Game = preload("res://src/game.gd")
const HellScene = preload("res://src/hell/hell_dungeon.tscn")
const FrostScene = preload("res://src/hell/frost_dungeon.tscn")

var checked := 0
var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	checked += 1
	if not condition:
		failures.append(label)
		printerr("RUN_TREE_FAIL: ", label)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_model()
	await _test_crypt()
	await _test_story(HellScene, "hell")
	await _test_story(FrostScene, "frost")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(META))
	print("RUN_TREE checked=%d failures=%d" % [checked, failures.size()])
	quit(1 if failures.size() > 0 else 0)


func _test_model() -> void:
	var tree := RunTree.build([
		{"key": "a", "title": "A", "unlock": 1, "nodes": [{"id": "a1", "name": "A1", "max": 2}, {"id": "a2", "name": "A2"}, {"id": "a3", "name": "A3"}]},
		{"key": "b", "title": "B", "unlock": 5, "nodes": [{"id": "b1", "name": "B1"}]}])
	check(RunTree.points_total(1) == 0 and RunTree.points_total(6) == 5, "one point per level-up, none at level 1")
	check(RunTree.state_of(tree, {}, 1, "a1") == "no_points", "no point at level 1")
	check(RunTree.can_take(tree, {}, 2, "a1"), "a tier-1 node is open with a point")
	check(RunTree.state_of(tree, {}, 3, "a3") == "tier_locked", "a tier-2 node needs points in its branch")
	check(RunTree.can_take(tree, {"a1": 1, "a2": 1}, 4, "a3"), "two points in the branch open tier 2")
	check(RunTree.state_of(tree, {"a1": 2}, 9, "a1") == "maxed", "a node stops at its max")
	check(RunTree.state_of(tree, {}, 4, "b1") == "skill_locked" and RunTree.can_take(tree, {}, 5, "b1"), "a skill branch opens at the skill's level")
	check(RunTree.points_left(tree, {"a1": 2, "a2": 1}, 3) == 0, "points never go below zero")


func _test_crypt() -> void:
	var tree := ClassPerks.run_tree("mage")
	check((tree.branches as Array).size() == 5, "crypt: four skill branches and the passives")
	check(str(tree.branches[0].title) == "FEUERBALL" and int(tree.branches[1].unlock) > 1, "crypt: branches follow the skills and their unlock levels")
	var game: Node = Game.new()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	game.port_input.text = "18893"
	game._host_session()
	game.requested_seed = 4711
	game.player_classes[1] = "mage"
	game._begin_run()
	var hero: Dictionary = game.players[1]
	hero.class_id = "mage"
	game.team_progress.add_exp(game.team_progress.next_level_exp() + game.team_progress.next_level_exp() * 3)
	check(int(game.team_progress.team.level) >= 2, "crypt: the team levels up")
	check(Array(hero.get("offer_queue", [])).is_empty(), "crypt: a level-up offers no cards any more")
	var ids: Array = ClassPerks.run_tree_ids("mage")
	var before := ClassPerks.rank(hero, "twin_fire")
	game.action_times.clear()
	game._server_action(1, "talent", ids.find("twin_fire"))
	check(ClassPerks.rank(hero, "twin_fire") == before + 1, "crypt: the talent action spends a point")
	var level := int(game.team_progress.team.level)
	while RunTree.points_left(tree, ClassPerks.ranks(hero), level) > 0:
		var open := ids.filter(func(id: String) -> bool: return RunTree.can_take(tree, ClassPerks.ranks(hero), level, id))
		if open.is_empty():
			break
		game.team_progress.take_talent(hero, str(open[0]))
	check(not game.team_progress.take_talent(hero, "twin_fire"), "crypt: no points left, nothing more to take")
	# The shared talent profile replaces the lasting talents and soul crystals
	# (docs/TALENTE-SEELENSPLITTER.de.md, decision 29.10.2026): no node waits
	# for a lasting talent, a run adds no bonus and a floor banks no crystals.
	var d := MetaStore.data()
	var store := MetaStore.fresh(d)
	store.classes.mage.ranks = {"f_twin": 1, "f_core": 2}
	MetaStore.save_store(store, META)
	game.meta_path = META
	game.player_classes[1] = "mage"
	game._begin_run()
	hero = game.players[1]
	var open_tree := ClassPerks.run_tree("mage", hero.meta)
	check(str(hero.class_id) == "mage" and (hero.get("meta", {}).get("gated", {}) as Dictionary).is_empty(), "crypt: no node waits for a lasting talent")
	check(RunTree.state_of(open_tree, {}, 20, "wildfire") != "meta_locked", "crypt: every node of the tree is open to points")
	check(is_equal_approx(float(hero.meta.bonus.damage), 0.0), "crypt: old stat talents add nothing any more")
	var crystals_before := int(MetaStore.load_store(d, META).crystals)
	game._enter_next_floor()
	check(int(game.run_crystals) == 0 and int(MetaStore.load_store(d, META).crystals) == crystals_before, "crypt: a finished floor banks no soul crystals")
	game.queue_free()
	await process_frame


## Lasting talents of the tests: ZWILLINGSFEUER bought twice (opens twin_fire up to 2).
const META := "user://run_tree_test_meta.cfg"


func _open(scene: PackedScene) -> Node:
	var d := MetaStore.data()
	var store := MetaStore.fresh(d)
	store.classes.mage.ranks = {"f_twin": 2}
	MetaStore.save_store(store, META)
	var game: Node = scene.instantiate()
	game.class_id = "mage"
	game.meta_path = META
	root.add_child(game)
	await process_frame
	game.set_process(false)
	return game


func _test_story(scene: PackedScene, world: String) -> void:
	var game: Node = await _open(scene)
	var tree := CardKit.tree(game)
	var titles: Array = (tree.branches as Array).map(func(b: Dictionary) -> String: return str(b.title))
	check(titles.has("GRUNDWERTE") and (tree.branches as Array).size() == 5, "%s: four skill branches and the basics" % world)
	HeroKit.gain(game, HeroKit.need(game.theme.leveling, 1) + HeroKit.need(game.theme.leveling, 2))
	check(int(game.state.level) >= 3, "%s: the hero levels up" % world)
	check((game.state.get("offer", []) as Array).is_empty(), "%s: a level-up shows no cards any more" % world)
	check(RunTree.points_left(tree, CardKit.ranks(game), int(game.state.level)) == int(game.state.level) - 1, "%s: each level-up left a point" % world)
	check(CardKit.take_node(game, "twin_fire") and CardKit.level(game, "twin_fire") >= 1, "%s: a point goes into a node" % world)
	check(not CardKit.take_node(game, "long_breath"), "%s: a locked skill branch takes no point" % world)
	check(RunTree.state_of(CardKit.tree(game), CardKit.ranks(game), 20, "wildfire") != "meta_locked", "%s: no node waits for a lasting talent (the talent profile replaces them)" % world)
	check(int(RunTree.node(CardKit.tree(game), "twin_fire").max) == 2, "%s: the talent rank caps the node" % world)
	# B opens the tree; a click inside spends a point and never fires
	var key := InputEventKey.new()
	key.keycode = KEY_B
	key.pressed = true
	game._unhandled_input(key)
	check(bool(game.state.get("tree_open", false)), "%s: B opens the run talent tree" % world)
	var screen: Vector2 = game.get_viewport_rect().size
	var spot: Rect2 = RunTreeView.layout(screen, CardKit.tree(game)).nodes.get("mg_focus", Rect2())
	var shots := (game.shots as Array).size()
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = spot.get_center()
	game._unhandled_input(click)
	check(CardKit.level(game, "mg_focus") >= 1, "%s: a click on a node spends a point" % world)
	check((game.shots as Array).size() == shots, "%s: the click does not fire" % world)
	game.queue_free()
	await process_frame
