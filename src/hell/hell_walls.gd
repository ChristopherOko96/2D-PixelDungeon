extends RefCounted
## Builds the wall pieces of a hell floor from its cell grid (same rules as the
## browser preview): horizontal strips above and below floor runs, side columns
## beside them, corner caps at column ends and glowing posts at door gaps.

const NORTH_HEIGHT := 74.0
const SIDE_WIDTH := 62.0


static func _walkable(grid: PackedByteArray, cols: int, rows: int, x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= cols or y >= rows:
		return false
	var t := grid[y * cols + x]
	return t == 1 or t == 2 or t == 3


## Returns {north, south, side, caps, posts}; positions are world pixels. `doorways` are gates set in a
## wall, each {"cells": [Vector2i, ...], "dir": "v" or "h"}: the wall runs on straight past them as if
## they were wall, with a gap just where they stand, and never bends round them.
static func build(grid: PackedByteArray, cols: int, rows: int, cell: float = 96.0, doorways: Array = []) -> Dictionary:
	if not doorways.is_empty():
		var solid := grid.duplicate()
		for way: Dictionary in doorways:
			for c: Vector2i in way.cells:
				if c.x >= 0 and c.y >= 0 and c.x < cols and c.y < rows:
					solid[c.y * cols + c.x] = 0
		var whole := build(solid, cols, rows, cell)
		for way: Dictionary in doorways:
			_cut(whole, way, cell)
		return whole
	var north: Array = []
	var south: Array = []
	var side: Array = []
	var caps: Array[Vector2] = []
	var posts: Array[Vector2] = []
	for y in range(rows):
		for dy: int in [-1, 1]:
			var x := 0
			while x < cols:
				if _walkable(grid, cols, rows, x, y) and not _walkable(grid, cols, rows, x, y + dy):
					var e := x
					while e + 1 < cols and _walkable(grid, cols, rows, e + 1, y) and not _walkable(grid, cols, rows, e + 1, y + dy):
						e += 1
					var strip := {"x0": x * cell, "x1": (e + 1) * cell, "y": y * cell - NORTH_HEIGHT if dy < 0 else (y + 1) * cell}
					if dy < 0:
						north.append(strip)
						var k := x + 3
						while k < e:
							posts.append(Vector2(k * cell, y * cell))
							k += 4
						if _walkable(grid, cols, rows, e + 1, y) and _walkable(grid, cols, rows, e + 1, y - 1):
							posts.append(Vector2((e + 1) * cell, y * cell))
						if _walkable(grid, cols, rows, x - 1, y) and _walkable(grid, cols, rows, x - 1, y - 1):
							posts.append(Vector2(x * cell, y * cell))
					else:
						south.append(strip)
					x = e + 1
				else:
					x += 1
	for x in range(cols):
		for dx: int in [-1, 1]:
			var y := 0
			while y < rows:
				if _walkable(grid, cols, rows, x, y) and not _walkable(grid, cols, rows, x + dx, y):
					var e := y
					while e + 1 < rows and _walkable(grid, cols, rows, x, e + 1) and not _walkable(grid, cols, rows, x + dx, e + 1):
						e += 1
					var ext_top := not _walkable(grid, cols, rows, x, y - 1) and not _walkable(grid, cols, rows, x + dx, y - 1)
					var ext_bot := not _walkable(grid, cols, rows, x, e + 1) and not _walkable(grid, cols, rows, x + dx, e + 1)
					var bx: float = x * cell - SIDE_WIDTH if dx < 0 else (x + 1) * cell
					side.append({"x": bx, "y0": y * cell - (NORTH_HEIGHT if ext_top else 0.0), "y1": (e + 1) * cell + (NORTH_HEIGHT if ext_bot else 0.0), "flip": dx > 0, "glow": false})
					caps.append(Vector2(bx + 31.0, y * cell - 37.0 if ext_top else y * cell + 34.0))
					caps.append(Vector2(bx + 31.0, (e + 1) * cell + 37.0 if ext_bot else (e + 1) * cell - 34.0))
					var k := y + 3
					while k < e - 1:
						side.append({"x": bx, "y": k * cell, "flip": dx > 0, "glow": true})
						k += 4
					y = e + 1
				else:
					y += 1
	return {"north": north, "south": south, "side": side, "caps": caps, "posts": posts}


## Cuts one doorway's gap into the finished wall pieces; a post or cap closes each cut end.
static func _cut(walls: Dictionary, way: Dictionary, cell: float) -> void:
	var lo: Vector2i = way.cells[0]
	var hi: Vector2i = way.cells[way.cells.size() - 1]
	if str(way.dir) == "h":
		var y0 := lo.y * cell
		var y1 := (hi.y + 1) * cell
		var kept: Array = []
		for s: Dictionary in walls.side:
			var here := float(s.x) in [(lo.x + 1) * cell - SIDE_WIDTH, lo.x * cell]
			if not here:
				kept.append(s)
			elif bool(s.glow):
				if float(s.y) < y0 or float(s.y) >= y1:
					kept.append(s)
			elif float(s.y1) <= y0 or float(s.y0) >= y1:
				kept.append(s)
			else:
				if float(s.y0) < y0:
					var top: Dictionary = s.duplicate()
					top.y1 = y0
					kept.append(top)
				if float(s.y1) > y1:
					var bottom: Dictionary = s.duplicate()
					bottom.y0 = y1
					kept.append(bottom)
				walls.caps.append(Vector2(float(s.x) + SIDE_WIDTH * 0.5, y0 - 34.0))
				walls.caps.append(Vector2(float(s.x) + SIDE_WIDTH * 0.5, y1 + 34.0))
		walls.side = kept
		return
	var x0 := lo.x * cell
	var x1 := (hi.x + 1) * cell
	var line := (lo.y + 1) * cell
	walls.north = _split(walls.north, line - NORTH_HEIGHT, x0, x1)
	walls.south = _split(walls.south, lo.y * cell, x0, x1)
	var posts: Array[Vector2] = []
	for p: Vector2 in walls.posts:
		if not (p.y == line and p.x >= x0 and p.x <= x1):
			posts.append(p)
	posts.append(Vector2(x0, line))
	posts.append(Vector2(x1, line))
	walls.posts = posts


static func _split(strips: Array, y: float, x0: float, x1: float) -> Array:
	var out: Array = []
	for w: Dictionary in strips:
		if float(w.y) != y or float(w.x1) <= x0 or float(w.x0) >= x1:
			out.append(w)
			continue
		if float(w.x0) < x0:
			var left: Dictionary = w.duplicate()
			left.x1 = x0
			out.append(left)
		if float(w.x1) > x1:
			var right: Dictionary = w.duplicate()
			right.x0 = x1
			out.append(right)
	return out
