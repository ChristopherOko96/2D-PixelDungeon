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


## Returns {north, south, side, caps, posts}; positions are world pixels.
static func build(grid: PackedByteArray, cols: int, rows: int, cell: float = 96.0) -> Dictionary:
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
