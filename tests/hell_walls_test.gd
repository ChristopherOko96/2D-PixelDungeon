extends SceneTree
## Hell wall builder (src/hell/hell_walls.gd) on a small fixture: a 3x2 room
## gets one strip above and below, columns on both sides with caps at both ends,
## a door gap in the top row splits the north strip and adds glowing posts, and
## lava counts as floor for walls.

const Walls = preload("res://src/hell/hell_walls.gd")
var checked := 0
var failures: Array[String] = []


func check(condition: bool, description: String) -> void:
	checked += 1
	if not condition:
		failures.append(description)
		printerr("HELL_WALLS_FAIL: ", description)


func _grid(rows: Array[String]) -> PackedByteArray:
	var g := PackedByteArray()
	for row in rows:
		for ch in row:
			g.append(int(ch))
	return g


func _initialize() -> void:
	# 5x4 cells, a 3x2 room in the middle
	var room := _grid(["00000", "01110", "01110", "00000"])
	var w := Walls.build(room, 5, 4, 96.0)
	check(w.north.size() == 1 and is_equal_approx(w.north[0].x0, 96.0) and is_equal_approx(w.north[0].x1, 384.0), "one north strip spans the room width")
	check(is_equal_approx(w.north[0].y, 96.0 - 74.0), "the north strip sits on top of the first floor row")
	check(w.south.size() == 1 and is_equal_approx(w.south[0].y, 288.0), "one south strip starts at the room's bottom edge")
	var plain: Array = w.side.filter(func(s: Dictionary) -> bool: return not s.glow)
	check(plain.size() == 2, "the room has a west and an east column")
	check(w.caps.size() == 4, "each column gets a cap at both ends")
	# a door gap: a corridor leaves the top row at column 2
	var door := _grid(["00100", "01110", "01110", "00000"])
	var d := Walls.build(door, 5, 4, 96.0)
	var room_north: Array = d.north.filter(func(s: Dictionary) -> bool: return is_equal_approx(s.y, 96.0 - 74.0))
	check(room_north.size() == 2, "a door gap splits the north strip in two")
	check(d.posts.size() >= 2, "the gap is framed by glowing posts")
	# lava is floor for walls
	var lava := _grid(["000", "020", "000"])
	var l := Walls.build(lava, 3, 3, 96.0)
	check(l.north.size() == 1 and l.south.size() == 1, "a lava cell is walled like floor")
	print("HELL_WALLS checked=%d failures=%d" % [checked, failures.size()])
	quit(1 if failures.size() > 0 else 0)
