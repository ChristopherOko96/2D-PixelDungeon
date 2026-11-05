extends SceneTree
## Cuts the key chamber out of a generated floor as a room file of the Weltbauer, so floors built from
## room files (src/world_kit/room_floor.gd) keep it exactly as the generator lays it out. Overwrites
## assets/data/world_rooms/<world>/k_schluesselkammer.json.
## Usage: godot --headless --path . --script res://tools/world_kit/export_key_room.gd -- krypta
const Templates = preload("res://src/world_editor/world_room_templates.gd")
const Data = preload("res://src/world_editor/world_room_data.gd")


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var world: String = args[0] if not args.is_empty() else "krypta"
	var room := Templates.make(world, "key", "Schlüsselkammer")
	if room.is_empty():
		printerr("no key room found")
		quit(1)
		return
	room.id = "k_schluesselkammer"
	room.in_floors = true
	room.slots = [[0, 0]]
	room.floor_tile = "floor_00"
	room.auto_mobs = 0
	# the banners take the floor's colour on every floor, as on generated floors
	for o: Dictionary in room.objects:
		if str(o.get("asset", "")).begins_with("boss_banner"):
			o.asset = "banner_1"
	var trouble := Data.save(room)
	print("KEY_ROOM ", trouble if trouble != "" else "saved ports=" + str(room.ports))
	quit(0 if trouble == "" else 1)
