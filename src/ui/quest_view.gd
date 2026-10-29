extends Control
## The Auftragsliste, the same page in every story: the "Auftrag" section of
## the pause menu (src/pause_menu.gd). Main goals in order (the first open one
## is the current goal), side goals below; done goals are ticked and struck
## through. The crypt builds its goals from the snapshot (crypt_goals), the
## Frostgruft and the Hölle from their world (src/hell/frost_hud.gd goals).

const CryptUI = preload("res://src/ui/crypt_ui.gd")
const PixelStyle = preload("res://src/pixel_style.gd")

var goals: Array = []
var title := ""
var _font: Font = PixelStyle.create_font()


## The floor's goals of a crypt run from an authoritative snapshot:
## clear the rooms, defeat the floor's boss, take the stairs; the room's horde
## and chests as side goals.
static func crypt_goals(snapshot: Dictionary) -> Array:
	var rooms: Array = snapshot.get("floor_map", [])
	var victory := str(snapshot.get("phase", "")) == "victory"
	var cleared := rooms.filter(func(room: Dictionary): return bool(room.get("cleared", false))).size()
	var out: Array = []
	out.append({"text": "Säubere die Räume (%d/%d)" % [cleared, rooms.size()], "done": victory or (rooms.size() > 0 and cleared == rooms.size()), "main": true})
	for room: Dictionary in rooms:
		if bool(room.get("boss", false)):
			# "DER LEERENRUFER" -> "Besiege den Leerenrufer"
			var boss := str(snapshot.get("boss_name", "den Boss")).capitalize()
			if boss.begins_with("Der "): boss = "den " + boss.substr(4)
			out.append({"text": "Besiege %s" % boss, "done": victory or bool(room.get("cleared", false)), "main": true})
			break
	out.append({"text": "Steig die Treppe hinab zu Ebene %d" % (int(snapshot.get("floor_index", 1)) + 1), "done": victory, "main": true})
	var horde: Dictionary = snapshot.get("horde", {})
	if not horde.is_empty() and int(horde.get("total", 0)) > 0:
		var beaten := int(horde.total) - int(horde.get("left", 0))
		out.append({"text": "Halte die Horde auf (%d/%d)" % [beaten, int(horde.total)], "done": int(horde.get("left", 0)) <= 0, "main": false})
	var chests: Array = snapshot.get("loot_chests", {}).get("chests", [])
	var boxes := chests.filter(func(chest: Dictionary): return str(chest.get("kind", "chest")) == "chest")
	if not boxes.is_empty():
		var opened := boxes.filter(func(chest: Dictionary): return bool(chest.get("open", false))).size()
		out.append({"text": "Öffne die Truhen im Raum (%d/%d)" % [opened, boxes.size()], "done": opened == boxes.size(), "main": false})
	return out


## Shows `list` ({text, done, main}) under the heading `heading`.
func set_goals(list: Array, heading: String) -> void:
	if list == goals and heading == title: return
	goals = list.duplicate(true)
	title = heading
	queue_redraw()


func _draw() -> void:
	var mains := goals.filter(func(goal: Dictionary): return bool(goal.get("main", false)))
	var sides := goals.filter(func(goal: Dictionary): return not bool(goal.get("main", false)))
	var finished := mains.filter(func(goal: Dictionary): return bool(goal.get("done", false))).size()
	_line("AUFTRAG · " + title, Vector2(0, 16), 24, CryptUI.GOLD)
	_line("%d von %d Hauptzielen erfüllt" % [finished, mains.size()], Vector2(0, 44), 16, CryptUI.SAND)
	var y := 84.0
	_line("HAUPTZIELE", Vector2(0, y), 16, CryptUI.BONE)
	y += 30.0
	var current_set := false
	for goal: Dictionary in mains:
		var current := not bool(goal.done) and not current_set
		if current: current_set = true
		_goal(goal, y, current)
		y += 32.0
	if sides.is_empty(): return
	y += 10.0
	_line("NEBENZIELE", Vector2(0, y), 16, CryptUI.BONE)
	y += 30.0
	for goal: Dictionary in sides:
		_goal(goal, y, false)
		y += 32.0


## One row: a box (ticked when done, gold arrow for the current goal, small
## diamond for side goals) and the text, struck through when done.
func _goal(goal: Dictionary, y: float, current: bool) -> void:
	var done := bool(goal.get("done", false))
	var box := Rect2(8, y - 14, 16, 16)
	if current:
		draw_rect(Rect2(0, y - 22, size.x, 30), Color(CryptUI.GOLD, 0.12))
		draw_colored_polygon(PackedVector2Array([box.position, box.position + Vector2(14, 8), box.position + Vector2(0, 16)]), CryptUI.GOLD)
	elif bool(goal.get("main", false)) or done:
		draw_rect(box, CryptUI.INK)
		draw_rect(box, CryptUI.STONE_LIGHT, false, 2.0)
		if done:
			draw_polyline(PackedVector2Array([box.position + Vector2(3, 8), box.position + Vector2(7, 12), box.position + Vector2(14, 2)]), CryptUI.GOLD, 3.0)
	else:
		var c := box.get_center()
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, -6), c + Vector2(6, 0), c + Vector2(0, 6), c + Vector2(-6, 0)]), CryptUI.SAND)
	var colour: Color = Color(CryptUI.BONE, 0.45) if done else (CryptUI.GOLD if current else (CryptUI.BONE if bool(goal.get("main", false)) else CryptUI.SAND))
	var text := str(goal.get("text", ""))
	_line(text, Vector2(36, y), 16, colour)
	if done:
		var width := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		draw_line(Vector2(36, y - 6), Vector2(36 + width, y - 6), Color(CryptUI.BONE, 0.45), 2.0)


func _line(text: String, at: Vector2, font_size: int, colour: Color) -> void:
	draw_string(_font, at, text, HORIZONTAL_ALIGNMENT_LEFT, size.x - at.x, font_size, colour)
