extends SceneTree
## Saves whole open endless floors as the 0x72 crypt renderer bakes them
## (src/crypt_0x72_art.gd, 16 px per tile) for review:
## godot --headless --path . --script res://scripts/capture_open_floor.gd -- <out_dir> <seed> [<seed> ...]

const Dungeon = preload("res://src/dungeon/dungeon_generator.gd")
const OpenFloor = preload("res://src/dungeon/open_floor.gd")
const Crypt0x72Art = preload("res://src/crypt_0x72_art.gd")

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		printerr("usage: -- <out_dir> <seed> [<seed> ...]")
		quit(2)
		return
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/dungeon_rooms.json"))
	var data := OpenFloor.load_data()
	for index in range(1, args.size()):
		var seed_value := int(args[index])
		var floors := Dungeon.generate_open_floor(seed_value, index, config, data)
		if floors.is_empty():
			printerr("no floor for seed %d" % seed_value)
			continue
		var art := Crypt0x72Art.new()
		art.bake(floors[0], seed_value)
		var path := "%s/open-floor-%d.png" % [args[0], seed_value]
		art.texture.get_image().save_png(path)
		print("SAVED %s rooms=%d" % [path, floors[0].rooms.size()])
	quit(0)
