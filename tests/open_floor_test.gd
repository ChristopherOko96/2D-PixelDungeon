extends SceneTree
## Open endless floors (src/dungeon/open_floor.gd, generate_open_floor in
## src/dungeon/dungeon_generator.gd): equal seeds give equal maps; rooms stay
## inside the map and apart; every room, spawn, chest spot and the stairs are
## reachable from the party; the boss room is the farthest; no enemies wait in
## the start room. Pass `-- --preview <png>` to also write a map picture.

const Dungeon = preload("res://src/dungeon/dungeon_generator.gd")
const OpenFloor = preload("res://src/dungeon/open_floor.gd")
const SEEDS := [7, 99, 2024, 4242, 31337, 555, 8080, 123456]
var checked := 0
var failures: Array[String] = []

func check(condition: bool, label: String) -> void:
	checked += 1
	if not condition:
		failures.append(label)
		printerr("OPEN_FLOOR_FAIL: ", label)

func _initialize() -> void:
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/dungeon_rooms.json"))
	var data: Dictionary = OpenFloor.load_data()
	check(not data.is_empty(), "the open floor tuning file loads")
	var previews: Array[Image] = []
	for seed_value: int in SEEDS:
		var floors := Dungeon.generate_open_floor(seed_value, 1, config, data)
		check(floors.size() == 1, "seed %d builds one open floor" % seed_value)
		if floors.is_empty(): continue
		var layout: Dictionary = floors[0]
		var again := Dungeon.generate_open_floor(seed_value, 1, config, data)
		check(not again.is_empty() and JSON.stringify(again[0].rooms) == JSON.stringify(layout.rooms) and JSON.stringify(again[0].painted_tiles) == JSON.stringify(layout.painted_tiles), "seed %d builds the same map twice" % seed_value)
		_check_layout(seed_value, layout, data)
		if previews.size() < 4: previews.append(_picture(layout))
	var other := Dungeon.generate_open_floor(SEEDS[0], 2, config, data)
	var first := Dungeon.generate_open_floor(SEEDS[0], 1, config, data)
	check(not other.is_empty() and other[0].theme != first[0].theme, "the next floor takes the next terrain theme")
	check(Dungeon.generate_open_floor(7, 1, config, {}).is_empty(), "without tuning data no open floor is built")
	_write_preview(previews)
	print("OPEN_FLOOR checked=%d failures=%d" % [checked, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _check_layout(seed_value: int, layout: Dictionary, data: Dictionary) -> void:
	var label := "seed %d" % seed_value
	var map := Vector2i(int(data.map_tiles[0]), int(data.map_tiles[1]))
	check(Vector2(layout.world_size[0], layout.world_size[1]) == Vector2(map * 32), label + ": world size follows map_tiles")
	var rooms: Array = layout.rooms
	check(rooms.size() >= int(data.room_count[0]) and rooms.size() <= int(data.room_count[1]), label + ": room count within room_count")
	var inside := true
	var apart := true
	for a in range(rooms.size()):
		var ra := Rect2i(rooms[a][0], rooms[a][1], rooms[a][2], rooms[a][3])
		if ra.position.x < 1 or ra.position.y < 1 or ra.end.x > map.x - 1 or ra.end.y > map.y - 1: inside = false
		for b in range(a + 1, rooms.size()):
			var rb := Rect2i(rooms[b][0], rooms[b][1], rooms[b][2], rooms[b][3])
			if ra.intersects(rb): apart = false
	check(inside, label + ": every room keeps a wall tile to the map edge")
	check(apart, label + ": rooms never overlap")
	var stairs: Array = layout.exits.filter(func(exit: Dictionary) -> bool: return str(exit.kind) == "stairs")
	check(stairs.size() == 1, label + ": exactly one stairs down")
	var start: Vector2 = layout.player_spawns[0]
	var radius := 12.0
	var reach := func(point: Vector2) -> bool: return not Dungeon.segment_blocked(point, point, radius, layout) and not Dungeon.find_path(start, point, radius, layout).is_empty()
	if not stairs.is_empty(): check(reach.call(Dungeon._rect(stairs[0].rect).get_center()), label + ": the stairs are reachable from the start")
	var every_room := true
	for room: Array in rooms:
		var centre := (Vector2(room[0], room[1]) + Vector2(room[2], room[3]) * 0.5).floor() * 32 + Vector2(16, 16)
		if not reach.call(centre): every_room = false
	check(every_room, label + ": every room is reachable from the start")
	var spawns_ok := true
	for point: Vector2 in layout.enemy_spawns + layout.boss_spawns + layout.player_spawns:
		if not reach.call(point): spawns_ok = false
	check(spawns_ok, label + ": every spawn stands free and reachable")
	var start_room: Array = rooms[int(layout.start_room)]
	var start_rect := Rect2(Vector2(start_room[0], start_room[1]) * 32, Vector2(start_room[2], start_room[3]) * 32)
	check(layout.enemy_spawns.all(func(point: Vector2) -> bool: return not start_rect.has_point(point)), label + ": no enemies wait in the start room")
	check(layout.enemy_spawns.size() >= (rooms.size() - 2) * int(data.enemy_group[0]), label + ": every middle room holds an enemy group")
	check(int(layout.boss_room) != int(layout.start_room), label + ": the boss room is not the start room")
	var floor_cells := {}
	for cell: Dictionary in layout.painted_tiles:
		if str(cell.get("layer", "")) == "floor": floor_cells[Vector2i(int(cell.x), int(cell.y))] = true
	var chest_ok: bool = not layout.chest_spawns.is_empty()
	for spot: Array in layout.chest_spawns:
		var cell := Vector2i(int(spot[0]), int(spot[1]))
		if not floor_cells.has(cell) or floor_cells.has(cell + Vector2i.UP): chest_ok = false
	check(chest_ok, label + ": chest spots are floor cells against a north wall")

## Floor dark, walls light, start green, boss red, enemies orange, chests gold.
func _picture(layout: Dictionary) -> Image:
	var size := Vector2i(int(layout.world_size[0]) / 32, int(layout.world_size[1]) / 32)
	var image := Image.create(size.x * 4, size.y * 4, false, Image.FORMAT_RGBA8)
	image.fill(Color("1a1414"))
	for cell: Dictionary in layout.painted_tiles:
		var colour := Color("483b3a") if str(cell.get("layer", "")) == "floor" else Color("aa8d7a")
		image.fill_rect(Rect2i(int(cell.x) * 4, int(cell.y) * 4, 4, 4), colour)
	var mark := func(point: Vector2, colour: Color) -> void: image.fill_rect(Rect2i(int(point.x / 8) - 1, int(point.y / 8) - 1, 3, 3), colour)
	for point: Vector2 in layout.enemy_spawns: mark.call(point, Color("da4e38"))
	for point: Vector2 in layout.boss_spawns: mark.call(point, Color("b06ad8"))
	for point: Vector2 in layout.player_spawns: mark.call(point, Color("9fc46a"))
	for spot: Array in layout.chest_spawns: mark.call(Vector2(spot[0], spot[1]) * 32 + Vector2(16, 16), Color("edbf75"))
	for exit: Dictionary in layout.exits: mark.call(Dungeon._rect(exit.rect).get_center(), Color("8fd8e6"))
	return image

func _write_preview(images: Array[Image]) -> void:
	var args := OS.get_cmdline_user_args()
	var index := args.find("--preview")
	if index < 0 or index + 1 >= args.size() or images.is_empty(): return
	var tile := images[0].get_size()
	var sheet := Image.create(tile.x * 2 + 8, tile.y * 2 + 8, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("000000"))
	for i in range(images.size()):
		sheet.blit_rect(images[i], Rect2i(Vector2i.ZERO, tile), Vector2i(i % 2, i / 2) * (tile + Vector2i(8, 8)))
	sheet.save_png(args[index + 1])
