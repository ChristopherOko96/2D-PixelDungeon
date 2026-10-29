extends SceneTree
## Captures item system 2 (docs/ITEM-SYSTEM-V2.de.md): the inventory with the
## four equipment slots, a worn armour and ring, gear and the new consumables
## in the bag, a chosen piece's text; then a clone seal's clone in the fight.
## In the crypt and, when given "story", in the Hell-Dungeon and Frostgruft.
## Usage:
##   godot --path . --windowed --resolution 1280x720 -s res://scripts/capture_items_v2.gd -- <output_dir>
const Game = preload("res://src/game.gd")

var _out := "res://production/qa/evidence/items-v2"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		_out = args[0]
	_run.call_deferred()


func _wait(frames: int) -> void:
	for i in range(frames):
		await process_frame


func _shot(name: String) -> void:
	var image := root.get_texture().get_image()
	var path := _out.path_join(name + ".png")
	print("CAPTURED %s result=%d" % [path, image.save_png(path)])


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	var game: Node = Game.new()
	root.add_child(game)
	await _wait(40)
	var entry: Dictionary = {}
	for e: Dictionary in game.main_menu.debug_entries:
		if str(e.label).contains("RAUM 02"):
			entry = e
	game.requested_seed = 4242
	game.main_menu._pick_debug(entry)
	game.main_menu._choose_class("mage")
	await _wait(40)
	var hero: Dictionary = game.players[1]
	var inv: RefCounted = game.inventory
	inv.add(hero, inv.make_gear("bone_plate", true, "", 1))
	inv.act(1, "inv_equip", hero.inventory.bag.size() - 1)
	inv.add(hero, inv.make_gear("ring_focus", true, "night", -1))
	inv.act(1, "inv_equip", hero.inventory.bag.size() - 1)
	inv.add(hero, inv.make_gear("amulet_star", false, "", 2))
	inv.add(hero, inv.make_gear("shadow_cloak", true, "", 3))
	inv.add(hero, inv.make_weapon("ruby_staff" if not inv.data.get("weapons", []).filter(func(w: Dictionary) -> bool: return str(w.id) == "ruby_staff").is_empty() else "emerald_staff", false, "leaden"))
	for kind: String in ["clone_seal", "upgrade_stone", "dice_stone", "mirror_crystal", "crystal", "stone"]:
		inv.add(hero, inv.make_stack(kind, "", 2))
	inv.add(hero, inv.make_stack("potion", "healing", 2))
	for i in range(20):
		hero.invulnerable = 5.0
		await process_frame
	game.inventory_panel.set_open(true)
	game.inventory_panel.selected = 3
	game.inventory_panel._refresh_buttons()
	await _wait(10)
	await _shot("01-krypta-inventar-ausruestung")
	game.inventory_panel.selected = 96 + 2
	game.inventory_panel._refresh_buttons()
	await _wait(5)
	await _shot("02-krypta-ring-verflucht")
	game.inventory_panel.set_open(false)
	inv.summon_clone(1, hero, 20.0)
	for i in range(60):
		hero.invulnerable = 5.0
		await process_frame
	await _shot("03-krypta-klon")
	game.queue_free()
	await _wait(3)
	# the story worlds: the same window, finds from a chest, a find on the floor, the clone
	for pair: Array in [[load("res://src/hell/hell_dungeon.tscn"), "04-hoelle"], [load("res://src/hell/frost_dungeon.tscn"), "05-frost"]]:
		var world: Node = (pair[0] as PackedScene).instantiate()
		world.class_id = "archer"
		root.add_child(world)
		await _wait(5)
		world.state.offer = []
		await _wait(120)
		var items: Node = world.story_items
		items.loot("chest", Vector2(world.player.x, world.player.y))
		items.give(items.inventory.make_gear("chain_shirt", true, "", 2), Vector2.ZERO)
		items.act("inv_equip", items.players[1].inventory.bag.size() - 1)
		items.give(items.inventory.make_gear("amulet_frost", false, "sluggish", -1), Vector2.ZERO)
		items.give(items.inventory.make_weapon("frost_bow" if not items.inventory.data.weapons.filter(func(w: Dictionary) -> bool: return str(w.id) == "frost_bow").is_empty() else "hunting_bow", false, ""), Vector2.ZERO)
		for kind: String in ["clone_seal", "upgrade_stone", "mirror_crystal"]:
			items.give(items.inventory.make_stack(kind), Vector2.ZERO)
		items.give(items.inventory.make_stack("potion", "fire", 2), Vector2.ZERO)
		world.state.toasts = []
		world.inventory_panel.set_view(items.view())
		world.inventory_panel.set_open(true)
		world.inventory_panel.selected = 97 - 1
		world.inventory_panel.selected = 98
		world.inventory_panel._refresh_buttons()
		await _wait(10)
		await _shot(str(pair[1]) + "-inventar")
		world.inventory_panel.set_open(false)
		items.floor_items.append({"item": items.inventory.make_gear("dragon_scale", false, "", 0), "p": Vector2(world.player.x + 160, world.player.y)})
		var seal: Dictionary = items.inventory.make_stack("clone_seal")
		items.give(seal, Vector2.ZERO)
		var at: int = items.players[1].inventory.bag.find(seal)
		if at < 0:
			for i in range(items.players[1].inventory.bag.size()):
				if str(items.players[1].inventory.bag[i].type) == "clone_seal": at = i
		items.act("inv_use", at)
		for i in range(40):
			world.state.inv = 0.0
			await process_frame
		await _shot(str(pair[1]) + "-klon-und-fund")
		world.queue_free()
		await _wait(3)
	quit()
