extends SceneTree
## Captures the item system from the real windowed game: the inventory with a
## cursed weapon in hand and unknown finds in the bag, found items glowing in
## their rarity on the floor next to a gold crate, a thrown fire potion
## burning foes, a thrown ice potion, and the archer and mage holding found
## weapons. Usage:
##   godot --path . --resolution 1280x720 -s res://scripts/capture_items.gd -- <output_dir>
const Game = preload("res://src/game.gd")
const Dungeon = preload("res://src/dungeon/dungeon_generator.gd")

var _out := "res://production/qa/evidence/items"
var _game: Node


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty(): _out = args[0]
	_run.call_deferred()


func _wait(frames: int) -> void:
	for i in range(frames):
		if _game != null and _game.players.has(1):
			_game.players[1].invulnerable = 5.0
			_game.players[1].hp = maxi(6, int(_game.players[1].hp))
		await process_frame


func _shot(name: String) -> void:
	await _wait(2)
	var image := root.get_texture().get_image()
	print("CAPTURED %s result=%d" % [name, image.save_png(_out.path_join(name + ".png"))])


## A calm room: the biggest of the floor, no horde, the hero in its most open spot.
func _arena() -> Dictionary:
	var best := 0
	for index in range(_game.floor_layouts.size()):
		var a: Array = _game.floor_layouts[index].world_size
		var b: Array = _game.floor_layouts[best].world_size
		if float(a[0]) * float(a[1]) > float(b[0]) * float(b[1]): best = index
	_game.room = best + 1
	_game._spawn_room()
	_game.enemies.clear()
	_game.bullets.clear()
	_game.chests.loot[str(_game.current_layout.id)] = []
	_game.hordes.enabled = false
	_game.phase = "explore"
	var hero: Dictionary = _game.players[1]
	var open := Vector2.ZERO
	var room := 0.0
	for entry: Dictionary in _game.current_layout.painted_tiles:
		if str(entry.get("layer", "")) != "floor": continue
		var point := Vector2(float(entry.x) * 32.0 + 16.0, float(entry.y) * 32.0 + 16.0)
		var free := 0.0
		for direction: Vector2 in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
			var reach := 0.0
			while reach < 320.0 and not Dungeon.segment_blocked(point, point + direction * (reach + 16.0), 30.0, _game.current_layout): reach += 16.0
			free += minf(reach, 220.0)
		if free > room:
			room = free
			open = point
	hero.pos = open
	return hero


func _foe(kind: String, offset: Vector2) -> Dictionary:
	var enemy: Dictionary = _game._create_enemy(kind, Vector2(_game.players[1].pos) + offset)
	enemy.move_timer = 99.0
	enemy.shot_timer = 99.0
	enemy.speed = 0.0
	_game.enemies.append(enemy)
	return enemy


func _class(class_id: String) -> Dictionary:
	_game.player_classes[1] = class_id
	var hero: Dictionary = _game.players[1]
	_game.HeroClass.apply(hero, class_id, _game.balance)
	_game.inventory.start_kit(hero)
	return hero


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	_game = Game.new()
	root.add_child(_game)
	_game.session_bind_ip = "127.0.0.1"
	await _wait(20)
	_game.player_classes[1] = "swordsman"
	_game._start_solo()
	await _wait(60)
	var inv = _game.inventory
	# 1. Inventory: a cursed knight sword in hand, finds in the bag.
	var hero := _arena()
	_class("swordsman")
	inv.add(hero, inv.make_weapon("knight_sword", false, "burning_blade"))
	inv.act(1, "inv_equip", 0, Vector2.INF)
	for entry: Array in [["katana", false, ""], ["sun_blade", false, "thorns"], ["waraxe", true, ""], ["star_edge", false, "sealed"]]:
		inv.add(hero, inv.make_weapon(str(entry[0]), bool(entry[1]), str(entry[2])))
	var kinds: Array = inv.data.potions.keys()
	for index in range(5): inv.add(hero, inv.make_stack("potion", str(kinds[index]), 1 + index % 2))
	inv.add(hero, inv.make_stack("crystal", "", 2))
	inv.add(hero, inv.make_stack("stone", "", 1))
	await _wait(10)
	_game.inventory_panel.selected = 99
	_game.inventory_panel.set_open(true)
	await _wait(20)
	await _shot("01-inventar-verfluchte-klinge-in-der-hand")
	_game.inventory_panel.selected = 5
	_game.inventory_panel.set_open(true)
	await _wait(6)
	await _shot("02-inventar-unbekannter-trank")
	_game.inventory_panel.set_open(false)
	# 2. Loot on the floor in its rarity colours, a gold crate beside it.
	hero = _arena()
	var room_id := str(_game.current_layout.id)
	var placed: Array = []
	var spots := [Vector2(70, -30), Vector2(-70, -30), Vector2(0, 70), Vector2(110, 40), Vector2(-110, 40)]
	var finds := [inv.make_weapon("sun_blade", false, ""), inv.make_weapon("frost_bow", false, ""), inv.make_weapon("void_staff", false, ""), inv.make_stack("potion", str(kinds[2])), inv.make_stack("crystal")]
	for index in range(finds.size()):
		var point: Vector2 = Vector2(hero.pos) + spots[index]
		if Dungeon.segment_blocked(point, point, 12.0, _game.current_layout): continue
		_game.chests.drop_item(finds[index], point)
		placed.append(point)
	var crate_at: Vector2 = Vector2(hero.pos) + Vector2(0, -95)
	var list: Array = _game.chests.chests.get(room_id, [])
	list.append({"id": 9901, "kind": "gold_crate", "pos": crate_at, "hits": 0, "max": 4, "open": false})
	_game.chests.chests[room_id] = list
	await _wait(50)
	await _shot("03-beute-am-boden-und-goldkiste")
	# 3. Potions thrown: fire burns a group, ice freezes one.
	hero = _arena()
	_class("mage")
	_game.phase = "combat"
	for offset: Vector2 in [Vector2(150, -20), Vector2(175, 25), Vector2(140, 40)]: _foe("skeleton", offset)
	inv.add(hero, inv.make_stack("potion", "fire"))
	inv.act(1, "inv_throw", hero.inventory.bag.size() - 1, Vector2(hero.pos) + Vector2(155, 15))
	await _wait(40)
	await _shot("04-feuertrank-geworfen")
	var frozen := _foe("skeleton_guard", Vector2(-150, 0))
	inv.add(hero, inv.make_stack("potion", "ice"))
	inv.act(1, "inv_throw", hero.inventory.bag.size() - 1, Vector2(frozen.pos))
	await _wait(14)
	await _shot("05-eistrank-geworfen")
	# 4. Archer and mage with found weapons in hand.
	hero = _arena()
	_game.enemies.clear()
	_class("archer")
	inv.add(hero, inv.make_weapon("ember_bow", true, ""))
	inv.act(1, "inv_equip", 0, Vector2.INF)
	await _wait(30)
	await _shot("06-bogenschuetze-gluthbogen")
	_class("mage")
	inv.add(hero, inv.make_weapon("sun_staff", true, ""))
	inv.act(1, "inv_equip", 0, Vector2.INF)
	await _wait(30)
	await _shot("07-magier-sonnenstab")
	_game._leave_session()
	await _wait(10)
	quit(0)
