extends Control
## Bird's-eye view of one generated Custom floor. It runs the same generator as the
## story run (custom_story_world.gd), tints rooms by type and names them, so an author
## sees how the modules join up before playing.

const World = preload("res://src/custom/custom_story_world.gd")
const COLORS := {"start": Color("5f9e4f"), "combat": Color("a8473b"), "shop": Color("c98f2e"),
	"treasure": Color("d8c04e"), "boss": Color("8240a8")}
const LABELS := [["start", "Eingang"], ["combat", "Kampf"], ["shop", "Shop"], ["treasure", "Schatz"], ["boss", "Boss"]]
## The generated floor in hell_floor_data's raw form; empty when generation failed.
var raw: Dictionary = {}
## Why the last generation failed ("" on success).
var error: String = ""


func _ready() -> void:
	clip_contents = true
	custom_minimum_size = Vector2(360, 330)


## Builds floor `n` of `story` with run number `run`; returns the error text ("" on success).
func show_floor(story: Dictionary, run: int, n: int = 1) -> String:
	var world := World.new(story)
	raw = world.build_raw(n, run)
	error = world.error_message
	queue_redraw()
	return error


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("11131b"))
	var font := get_theme_default_font()
	if raw.is_empty():
		var text := error if not error.is_empty() else tr("Noch keine Vorschau.")
		draw_multiline_string(font, Vector2(16, 34), text, HORIZONTAL_ALIGNMENT_LEFT, size.x - 32, 14, -1, Color("edbf75"))
		return
	var cols := int(raw.cols)
	var rows := int(raw.rows)
	var cell := floorf(minf((size.x - 24.0) / cols, (size.y - 48.0) / rows) * 4.0) / 4.0
	var origin := ((size - Vector2(cols, rows) * cell) * 0.5 + Vector2(0, 12)).floor()
	var grid: String = raw.grid
	var room_at: Array = raw.room_at
	var rooms: Array = raw.rooms
	for y in range(rows):
		for x in range(cols):
			var i := y * cols + x
			if grid[i] != "1": continue
			var color := Color("4b4756")
			var r := int(room_at[i])
			# corridor cells carry their child room's index but lie outside its box
			if r >= 0 and r < rooms.size() and Rect2i(int(rooms[r].bx) - 1, int(rooms[r].by) - 1, int(rooms[r].bw) + 2, int(rooms[r].bh) + 2).has_point(Vector2i(x, y)):
				color = COLORS.get(str(rooms[r].type), color)
			draw_rect(Rect2(origin + Vector2(x, y) * cell, Vector2.ONE * cell), color)
	for door: Dictionary in raw.get("doors", []):
		for c: Array in door.cells:
			draw_rect(Rect2(origin + Vector2(float(c[0]), float(c[1])) * cell, Vector2.ONE * cell), Color("edbf75"))
	var marks := {"shop": "$", "well": "o", "chest": "T", "portal": "P"}
	for ent: Dictionary in raw.get("ents", []):
		if not marks.has(str(ent.type)): continue
		var at := origin + Vector2(float(ent.x), float(ent.y)) / float(raw.cell) * cell
		draw_circle(at, maxf(5.0, cell * 0.7), Color("11131b"))
		draw_string(font, at + Vector2(-5, 5), str(marks[ent.type]), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
	for room: Dictionary in rooms:
		var center := origin + (Vector2(float(room.bx), float(room.by)) + Vector2(float(room.bw), float(room.bh)) * 0.5) * cell
		var name := str(room.name)
		var width := font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		draw_string_outline(font, center + Vector2(-width * 0.5, -cell), name, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 4, Color("11131b"))
		draw_string(font, center + Vector2(-width * 0.5, -cell), name, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
	var x := 12.0
	for entry: Array in LABELS:
		draw_rect(Rect2(x, 10, 12, 12), COLORS[entry[0]])
		draw_string(font, Vector2(x + 16, 21), tr(str(entry[1])), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("d8d2c4"))
		x += 28.0 + font.get_string_size(tr(str(entry[1])), HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
