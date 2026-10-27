extends SceneTree
## Asset authoring only. Decorates generated samples without starting a game.
const Generator = preload("res://src/dungeon/crypt_generator.gd")
const PATH := "res://assets/data/custom_dungeons/dungeon_crypt_of_the_damned.json"

func _initialize() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	var catalog: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/crypt_decoration_catalog.json"))
	if not parsed is Dictionary or not catalog is Dictionary:
		printerr("Krypta-Vorlagen oder Dekorationskatalog fehlen.")
		quit(1)
		return
	var config: Dictionary = parsed
	config.crypt_decoration_catalog = catalog.themes
	for index in range(config.templates.size()):
		var room: Dictionary = config.templates[index]
		# Remove only the discarded generic props in these generated samples.
		# The user's own dungeon and hand-authored neighboring files are untouched.
		room.painted_tiles = room.painted_tiles.filter(func(cell: Dictionary): return not str(cell.tile).begins_with("crypt_") or cell.get("crypt_dressing",false))
		var dressed := Generator.dress_template(room,config,42026+index*1301)
		if not dressed.has("decoration_summary"):
			printerr("Dekorationsaufbau abgebrochen: ",room.id)
			quit(1)
			return
		config.templates[index] = dressed
	var file := FileAccess.open(PATH,FileAccess.WRITE)
	if file == null:
		printerr("Krypta-Kandidat ist nicht beschreibbar.")
		quit(1)
		return
	file.store_string(JSON.stringify(config,"",true)+"\n")
	file.close()
	print("CRYPT_SAMPLES_DRESSED ",config.templates.size()," templates")
	quit()
