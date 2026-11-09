extends RefCounted
## The Frostgruft's puzzle pieces, placed in the Weltbauer (src/world_editor) and played on a floor
## built from room files (room_floor.gd) or in a room tried on its own. Every piece is one cell:
##
## - thin_ice: holds `holds` steps (2 or 1). Leaving it the last time breaks it into a hole; whoever
##   steps into the hole falls and stands again where he last stood on firm ground, all unsolved ice
##   of the room mended (Brüchiges Eis). With an ice_goal of the same group the group is solved when
##   the hero reaches the goal and every ice of the group is broken (Eisgang: each plate once).
## - ice_block: leaned into it slides until something stops it, into a crevasse (pit) it fills it.
## - snowball: leaned into it rolls one cell, grows on deep_snow (which it takes up), from fill_size
##   on it fills a crevasse, a smaller one falls in and is lost until the frost_rune resets the room.
## - ember_source: a hearth that never goes out. Its ember lasts `steps` cells (cold_fog costs more)
##   and lights a cold brazier (a brazier with cold set), which then gives ember itself.
## - beam_source, prism, beam_seal: the aurora light runs from the source, a prism ("/" turn 0, "\"
##   turn 1) turns it, a seal it reaches lights. All seals of a group lit solve it.
## - mirror_ghost, ghost_plate: the ghost steps each of the hero's steps mirrored left-right where its
##   way is free. The hero on his plate and the ghost on its plate at once solve the group. After
##   ghost.hint_after seconds in its room the mirror_lever wakes and shows the way once per pull.
## - crystal, bell_statue, bell_plate: the statue sings its melody (crystal numbers), the crystals
##   sound their notes; only after stepping on the bell plate do the strikes count.
## - frost_core, core_altar: the heart of ice carried to its altar solves the group.
## - frost_rune: puts every piece of its room back as it was; solved groups stay solved.
## Values: assets/data/world_frost_puzzles.json.

const DATA_PATH := "res://assets/data/world_frost_puzzles.json"
const C := 96.0
## Pieces lying on the floor: they never stop anyone.
const FLAT := ["thin_ice", "deep_snow", "cold_fog", "ice_goal", "ghost_plate", "bell_plate", "frost_rune"]
## Pieces standing in their cell: nobody walks through them, the light stops at them (a prism turns it).
const SOLID := ["ice_block", "snowball", "prism", "beam_source", "beam_seal", "crystal", "bell_statue", "ember_source", "core_altar", "mirror_lever"]
## Every piece of the Frostgruft's puzzles.
const KINDS := ["thin_ice", "deep_snow", "cold_fog", "ice_goal", "ghost_plate", "bell_plate", "frost_rune", "ice_block", "snowball", "prism", "beam_source",
	"beam_seal", "crystal", "bell_statue", "ember_source", "core_altar", "mirror_lever", "mirror_ghost", "frost_core"]
const DIRS := {"n": Vector2i(0, -1), "e": Vector2i(1, 0), "s": Vector2i(0, 1), "w": Vector2i(-1, 0)}

var g: Node
var cfg: Dictionary = {}
## The floor's pieces (W.ents entries of KINDS).
var pieces: Array = []
## Cell index -> the solid piece standing there.
var solid_at: Dictionary = {}
## Cell index -> the flat pieces lying there.
var flat_at: Dictionary = {}
## Rooms holding pieces.
var rooms: Dictionary = {}
## What the hero carries: {} or {"kind": "ember", "left": n} or {"kind": "core", "e": core}.
var carry: Dictionary = {}
## The hero's cell last frame; where he last stood on firm ground per room.
var last_cell := Vector2i(-99999, -99999)
## More cells than this between two frames is a teleport, not a step (update).
const TELEPORT_CELLS := 2
var firm: Dictionary = {}
## The lean into a block or ball: {"e", "t"}.
var lean: Dictionary = {}
## The light's ways this frame: [[world from, world to], ...].
var beams: Array = []
## Bell groups: group -> {"armed", "got"}.
var bells: Dictionary = {}
## Notes still to sing: [{"at": s, "note": n, "e": crystal or {}}].
var song: Array = []
## Seconds the hero spent in a room with a ghost whose group is open.
var ghost_time: Dictionary = {}
## The mirror's show while it runs: {} else {"ghost", "path", "i", "t", "back", "back_ghost", "wait"}.
var show: Dictionary = {}
## Holes and crevasses filled: cell index -> "block" or "snow".
var filled: Dictionary = {}
var _clock := 0.0
var _players: Array = []
var _tones: Dictionary = {}


func _init(game: Node, data: Dictionary = {}) -> void:
	g = game
	cfg = data if not data.is_empty() else load_config()


## The puzzle values from the data file.
static func load_config() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))


# ---------- the rules, without a game ----------

## The way the light goes on after meeting a prism of `turn` (0 "/", 1 "\") coming in along `dir`.
static func reflect(dir: Vector2i, turn: int) -> Vector2i:
	return Vector2i(-dir.y, -dir.x) if turn == 0 else Vector2i(dir.y, dir.x)


## The light from `start` along `dir`: `what` (Callable(cell) -> String) says what a cell holds:
## "wall" or "stop" ends it, "prism0"/"prism1" turn it, "seal" ends it there lit, anything else lets
## it through. {"cells": every cell it crosses, "turns": cells where it turned, "seal": the lit cell or null}.
static func trace(start: Vector2i, dir: Vector2i, what: Callable, most: int = 400) -> Dictionary:
	var cells: Array[Vector2i] = []
	var turns: Array[Vector2i] = []
	var c := start
	var d := dir
	var seen := {}
	for k in range(most):
		c += d
		var here: String = what.call(c)
		if here == "wall" or here == "stop":
			return {"cells": cells, "turns": turns, "seal": null, "end": c}
		cells.append(c)
		if here == "seal":
			return {"cells": cells, "turns": turns, "seal": c, "end": c}
		if here == "prism0" or here == "prism1":
			var key := [c, d]
			if seen.has(key):
				break
			seen[key] = true
			d = reflect(d, 0 if here == "prism0" else 1)
			turns.append(c)
	return {"cells": cells, "turns": turns, "seal": null, "end": c}


## Where an ice block from `from` slides along `dir`: `what` (Callable(cell) -> String) says "free",
## "pit" or "block". {"to": its last cell, "fill": true when it drops into a crevasse there}.
static func slide(from: Vector2i, dir: Vector2i, what: Callable, most: int = 200) -> Dictionary:
	var c := from
	for k in range(most):
		var next := c + dir
		var here: String = what.call(next)
		if here == "pit":
			return {"to": next, "fill": true}
		if here != "free":
			break
		c = next
	return {"to": c, "fill": false}


## One roll of a snowball of `size` from `from` along `dir`: {"to", "size", "fill", "lost", "moved"}.
## Deep snow on the new cell (`snow`: Callable(cell) -> bool) makes it one bigger, up to `most`; into a
## crevasse it fills it from `fill_size` on, else it is lost.
static func roll(from: Vector2i, dir: Vector2i, size: int, what: Callable, snow: Callable, most: int = 3, fill_size: int = 3) -> Dictionary:
	var next := from + dir
	var here: String = what.call(next)
	if here == "pit":
		return {"to": next, "size": size, "fill": size >= fill_size, "lost": size < fill_size, "moved": true}
	if here != "free":
		return {"to": from, "size": size, "fill": false, "lost": false, "moved": false}
	return {"to": next, "size": mini(most, size + (1 if bool(snow.call(next)) else 0)), "fill": false, "lost": false, "moved": true}


## The ghost's cell after the hero stepped `step` (any length): each step mirrored left-right, the
## sideways part first, one cell at a time, where `free` (Callable(cell) -> bool) lets it.
static func ghost_step(ghost: Vector2i, step: Vector2i, free: Callable) -> Vector2i:
	var c := ghost
	for k in range(absi(step.x)):
		var next := c + Vector2i(-signi(step.x), 0)
		if bool(free.call(next)):
			c = next
	for k in range(absi(step.y)):
		var next := c + Vector2i(0, signi(step.y))
		if bool(free.call(next)):
			c = next
	return c


## A strike of crystal `note` after `got` right ones of `melody`: "right", "done" or "wrong".
static func bell_strike(melody: Array, got: int, note: int) -> String:
	if got >= melody.size() or int(melody[got]) != note:
		return "wrong"
	return "done" if got + 1 == melody.size() else "right"


## A melody as numbers, from "5,4,2" or an array.
static func melody_of(v: Variant) -> Array:
	var out: Array = []
	if v is Array:
		for n: Variant in v:
			out.append(int(n))
		return out
	for part: String in str(v).split(",", false):
		if part.strip_edges().is_valid_int():
			out.append(int(part.strip_edges()))
	return out


## Steps of ember a cell costs.
static func ember_cost(fog: bool, data: Dictionary) -> int:
	return int((data.get("ember", {}) as Dictionary).get("fog_cost", 2)) if fog else 1


# ---------- the floor ----------

func _cols() -> int:
	return int(g.W.cols)


func _key(c: Vector2i) -> int:
	return c.y * _cols() + c.x


static func cell_of(e: Dictionary) -> Vector2i:
	return Vector2i(int(floor(float(e.x) / C)), int(floor(float(e.y) / C)))


static func centre(c: Vector2i) -> Vector2:
	return (Vector2(c) + Vector2(0.5, 0.5)) * C


## Takes up the floor's pieces (after a floor is loaded).
func setup() -> void:
	pieces = (g.W.ents as Array).filter(func(e: Dictionary) -> bool: return KINDS.has(str(e.type)))
	carry = {}
	lean = {}
	beams = []
	bells = {}
	song = []
	ghost_time = {}
	show = {}
	filled = {}
	firm = {}
	rooms = {}
	last_cell = Vector2i(-99999, -99999)
	for e: Dictionary in pieces:
		e.home = cell_of(e)
		e.size0 = int(e.get("size", 1))
		rooms[int(e.get("room", 0))] = true
		match str(e.type):
			"thin_ice":
				e.left = int(e.get("holds", (cfg.get("ice", {}) as Dictionary).get("holds", 2)))
			"bell_statue", "bell_plate", "crystal":
				bells[str(e.get("group", ""))] = {"armed": false, "got": 0}
	_index()


## Rebuilds the cells the pieces take.
func _index() -> void:
	solid_at = {}
	flat_at = {}
	for e: Dictionary in pieces:
		if e.get("gone", false):
			continue
		var k := _key(cell_of(e))
		if SOLID.has(str(e.type)):
			solid_at[k] = e
		elif FLAT.has(str(e.type)):
			if not flat_at.has(k):
				flat_at[k] = []
			flat_at[k].append(e)


func _flat(c: Vector2i, type: String) -> Dictionary:
	for e: Dictionary in flat_at.get(_key(c), []):
		if str(e.type) == type:
			return e
	return {}


## True when room `r` holds puzzle pieces.
func puzzle_room(r: int) -> bool:
	return rooms.has(r)


## True while the mirror shows its way: the hero is walked, no key moves him.
func showing() -> bool:
	return not show.is_empty()


## A broken ice or a crevasse at cell c that has not been filled.
func _hole(c: Vector2i) -> bool:
	var k := _key(c)
	if filled.has(k):
		return false
	var ice := _flat(c, "thin_ice")
	if not ice.is_empty() and int(ice.left) <= 0:
		return true
	return (g.W.get("pit_cells", {}) as Dictionary).has(k)


## What a moving block meets at cell c: "free", "pit" or "block".
func _ground(c: Vector2i) -> String:
	if c.x < 0 or c.y < 0 or c.x >= _cols() or c.y >= int(g.W.rows):
		return "block"
	var k := _key(c)
	if solid_at.has(k) or g._cell_blocked(c.x, c.y, false) or _prop_at(c):
		return "block"
	if _hole(c):
		return "pit"
	# a block never runs into the hero
	if g.player_cell() == c:
		return "block"
	return "free"


## True when a solid prop stands in cell c.
func _prop_at(c: Vector2i) -> bool:
	var mid := centre(c) + Vector2(0, 10)
	for r: Rect2 in g.solid_grid.get(_key(c), []):
		if r.grow(6.0).has_point(mid):
			return true
	return false


## True when a box (world px) touches a piece that stands in its cell.
func box_blocked(box: Rect2) -> bool:
	if solid_at.is_empty():
		return false
	for cy in range(int(floor(box.position.y / C)), int(floor((box.end.y - 1.0) / C)) + 1):
		for cx in range(int(floor(box.position.x / C)), int(floor((box.end.x - 1.0) / C)) + 1):
			var e: Variant = solid_at.get(cy * _cols() + cx)
			if e != null and _body(e).intersects(box):
				return true
	return false


## The part of its cell a piece blocks: nearly all of it, so the hero's feet never stand in its cell
## (his feet are 6 px over the foot of his box, hell_game player_cell).
func _body(e: Dictionary) -> Rect2:
	var c := cell_of(e)
	return Rect2(Vector2(c) * C + Vector2(8, 4), Vector2(C - 16, C - 8))


# ---------- each frame ----------

func update(dt: float) -> void:
	_clock += dt
	_sing(dt)
	if pieces.is_empty():
		return
	if showing():
		return
	var here: Vector2i = g.player_cell()
	if here != last_cell:
		# a walk moves a cell or a slant at a time; a jump of more cells is a teleport (a fall back
		# to the start, a door): nothing was walked, so no ember burns and no ice plate was left
		var jump := maxi(absi(here.x - last_cell.x), absi(here.y - last_cell.y))
		if last_cell.x > -99999 and jump <= TELEPORT_CELLS:
			_stepped(last_cell, here)
		last_cell = here
	var room := int(g.state.room)
	if rooms.has(room):
		_lean(dt)
		_count_ghost(room, dt)
	_light()


func _stepped(from: Vector2i, to: Vector2i) -> void:
	var ice := _flat(from, "thin_ice")
	if not ice.is_empty() and int(ice.left) > 0:
		ice.left = int(ice.left) - 1
		if int(ice.left) <= 0:
			_effect("ice_break", centre(from))
	if _flat(to, "thin_ice").is_empty() and not _hole(to):
		firm[int(g.state.room)] = to
	if not carry.is_empty() and str(carry.kind) == "ember":
		var fog := not _flat(to, "cold_fog").is_empty()
		# every cell crossed counts, a slant step too
		carry.left = int(carry.left) - ember_cost(fog, cfg) * maxi(1, absi(to.x - from.x) + absi(to.y - from.y))
		# ember.steps steps are walked with it; one more and it is out
		if int(carry.left) < 0:
			carry = {}
			g.toast("Die Glut ist erloschen. Hol neue am Herd.")
			_effect("ember_out", centre(to))
	for gh: Dictionary in pieces:
		if str(gh.type) == "mirror_ghost" and int(gh.room) == int(g.state.room) and not _solved(gh):
			_move_ghost(gh, to - from)
	var plate := _flat(to, "bell_plate")
	if not plate.is_empty() and not _solved(plate):
		var b: Dictionary = bells.get(str(plate.group), {})
		b.armed = true
		b.got = 0
		bells[str(plate.group)] = b
		g.toast("Die Kristalle lauschen. Schlag die Melodie der Statue nach.")
		_effect("plate", centre(to))
	var goal := _flat(to, "ice_goal")
	if not goal.is_empty() and not _solved(goal):
		var open := pieces.filter(func(e: Dictionary) -> bool: return str(e.type) == "thin_ice" and str(e.get("group", "")) == str(goal.group) and int(e.left) > 0).size()
		if open == 0:
			_solve(str(goal.group), "Jede Eisplatte ist gebrochen. Der Weg ist frei!")
		else:
			g.toast("Noch %d Eisplatte%s ganz. Jede muss einmal brechen." % [open, "" if open == 1 else "n"])
	_check_ghost_plates()
	if _hole(to):
		g.fall_into_pit()


func _solved(e: Dictionary) -> bool:
	var group := str(e.get("group", ""))
	return group != "" and bool((g.W.groups.get(group, {}) as Dictionary).get("solved", false))


func _solve(group: String, text: String) -> void:
	if group == "" or not g.W.groups.has(group) or bool(g.W.groups[group].get("solved", false)):
		return
	g.toast(text)
	g.solve_group(group)


## The hero leaning into a block or a ball moves it after push.hold seconds.
func _lean(dt: float) -> void:
	var want := Vector2(g.input_axis(KEY_A, KEY_D), g.input_axis(KEY_W, KEY_S))
	if want == Vector2.ZERO:
		lean = {}
		return
	var d := Vector2i(int(signf(want.x)), 0) if absf(want.x) >= absf(want.y) else Vector2i(0, int(signf(want.y)))
	var me: Vector2i = g.player_cell()
	var e: Variant = solid_at.get(_key(me + d))
	if e == null or str(e.type) not in ["ice_block", "snowball"] or e.has("move"):
		lean = {}
		return
	var box: Rect2 = g.player_box(float(g.player.x) + d.x * 10.0, float(g.player.y) + d.y * 10.0)
	if not _body(e).intersects(box):
		lean = {}
		return
	if not is_same(lean.get("e"), e):
		lean = {"e": e, "t": 0.0}
	lean.t = float(lean.t) + dt
	if float(lean.t) >= float((cfg.get("push", {}) as Dictionary).get("hold", 0.16)):
		lean = {}
		push(e, d)


## Moves block or ball `e` one push along `d`.
func push(e: Dictionary, d: Vector2i) -> void:
	var from := cell_of(e)
	var p: Dictionary = cfg.get("push", {})
	if str(e.type) == "ice_block":
		var res := slide(from, d, _ground)
		if res.to == from:
			return
		_move_to(e, res.to, float(p.get("slide", 10.0)))
		_effect("slide", centre(from))
		if res.fill:
			_fill(e, res.to, "block")
	else:
		var res := roll(from, d, int(e.get("size", 1)), _ground, func(c: Vector2i) -> bool: return not _flat(c, "deep_snow").is_empty() and not _flat(c, "deep_snow").get("gone", false),
			int(p.get("max_size", 3)), int(p.get("fill_size", 3)))
		if not res.moved:
			return
		_move_to(e, res.to, float(p.get("roll", 6.0)))
		if int(res.size) > int(e.get("size", 1)):
			var snow := _flat(res.to, "deep_snow")
			snow.gone = true
			e.size = int(res.size)
			_effect("snow", centre(res.to))
		if res.fill:
			_fill(e, res.to, "snow")
		elif res.lost:
			e.gone = true
			_index()
			g.toast("Der Schneeball ist zu klein und versinkt in der Spalte. Die Rune setzt alles zurück.")
			_effect("lost", centre(res.to))


func _move_to(e: Dictionary, to: Vector2i, speed: float) -> void:
	var from := cell_of(e)
	e.move = {"from": centre(from), "t": 0.0, "time": maxf(0.05, float((to - from).length()) / maxf(0.1, speed))}
	e.x = centre(to).x
	e.y = centre(to).y
	_index()


## A block or a big ball drops into the crevasse at `c` and makes it ground.
func _fill(e: Dictionary, c: Vector2i, how: String) -> void:
	filled[_key(c)] = how
	e.gone = true
	e.fill_at = c
	g.pit_filled(c)
	_index()
	_effect("fill", centre(c))
	g.toast("Die Spalte ist gefüllt." if how == "snow" else "Der Eisblock friert in der Spalte fest.")


func _move_ghost(gh: Dictionary, step: Vector2i) -> void:
	var at := ghost_step(cell_of(gh), step, func(c: Vector2i) -> bool: return _ground(c) == "free" and _room_of(c) == int(gh.room))
	if at != cell_of(gh):
		gh.move = {"from": Vector2(float(gh.x), float(gh.y)), "t": 0.0, "time": 0.14}
		gh.x = centre(at).x
		gh.y = centre(at).y
		gh.stirred = true


func _room_of(c: Vector2i) -> int:
	return int(g.room_at_cell(c))


func _check_ghost_plates() -> void:
	for gh: Dictionary in pieces:
		if str(gh.type) != "mirror_ghost" or _solved(gh):
			continue
		var hero := _flat(g.player_cell(), "ghost_plate")
		var its := _flat(cell_of(gh), "ghost_plate")
		if hero.is_empty() or its.is_empty() or str(hero.group) != str(gh.group) or str(its.group) != str(gh.group):
			continue
		if str(hero.get("who", "hero")) == "hero" and str(its.get("who", "hero")) == "ghost":
			_solve(str(gh.group), "Held und Spiegelbild stehen auf ihren Platten. Der Spiegel bricht auf!")


## Time in a ghost's room while its group is open: after ghost.hint_after the mirror's lever wakes.
func _count_ghost(room: int, dt: float) -> void:
	for gh: Dictionary in pieces:
		if str(gh.type) != "mirror_ghost" or int(gh.room) != room or _solved(gh):
			continue
		var before := float(ghost_time.get(room, 0.0))
		ghost_time[room] = before + dt
		var due := float((cfg.get("ghost", {}) as Dictionary).get("hint_after", 300.0))
		if before < due and float(ghost_time[room]) >= due:
			g.toast("Am Spiegel taut ein Hebel auf. Zieh ihn, und der Spiegel zeigt dir den Weg.")


func hint_ready(lever: Dictionary) -> bool:
	return float(ghost_time.get(int(lever.room), 0.0)) >= float((cfg.get("ghost", {}) as Dictionary).get("hint_after", 300.0))


## The aurora light of every source, and the seals it lights.
func _light() -> void:
	beams = []
	var lit := {}
	var groups := {}
	for e: Dictionary in pieces:
		if str(e.type) == "beam_seal":
			groups[str(e.group)] = true
			e.lit = false
	for e: Dictionary in pieces:
		if str(e.type) != "beam_source":
			continue
		var start := cell_of(e)
		var res := trace(start, DIRS.get(str(e.get("dir", "e")), Vector2i(1, 0)), _what_light)
		var at := centre(start)
		for c: Vector2i in res.turns:
			beams.append([at, centre(c)])
			at = centre(c)
		var tip := Vector2.ZERO
		if res.seal != null:
			tip = centre(res.seal)
		else:
			var last: Vector2i = res.cells[res.cells.size() - 1] if not res.cells.is_empty() else start
			tip = centre(last) + Vector2(Vector2i(res.end) - last) * C * 0.5
		beams.append([at, tip])
		if res.seal != null:
			var s: Variant = solid_at.get(_key(res.seal))
			if s != null:
				s.lit = true
				lit[str(s.group)] = true
	for group: String in groups:
		if not lit.has(group):
			continue
		var all := pieces.filter(func(e: Dictionary) -> bool: return str(e.type) == "beam_seal" and str(e.group) == group)
		if all.all(func(e: Dictionary) -> bool: return bool(e.get("lit", false))):
			_solve(group, "Das Polarlicht trifft %s. Ein Tor hebt sich!" % ("das Siegel" if all.size() == 1 else "alle Siegel"))


func _what_light(c: Vector2i) -> String:
	if c.x < 0 or c.y < 0 or c.x >= _cols() or c.y >= int(g.W.rows):
		return "wall"
	if g._cell_blocked(c.x, c.y, false):
		return "wall"
	var e: Variant = solid_at.get(_key(c))
	if e != null:
		match str(e.type):
			"prism": return "prism%d" % int(e.get("turn", 0))
			"beam_seal": return "seal"
			_: return "stop"
	if _prop_at(c):
		return "stop"
	return "free"


# ---------- using pieces ----------

## The pieces the hero can use now, as hell_game _interactables entries.
func interactables() -> Array:
	var out: Array = []
	var reach := float(cfg.get("reach", 120.0))
	for e: Dictionary in pieces:
		if e.get("gone", false) or int(e.get("room", -1)) != int(g.state.room):
			continue
		var p := Vector2(float(e.x), float(e.y) + 10.0)
		match str(e.type):
			"prism":
				if not bool(e.get("fixed", false)):
					out.append({"e": e, "label": "Prisma drehen", "p": p, "r": reach})
			"crystal":
				out.append({"e": e, "label": "Kristall anschlagen (%s)" % crystal_name(int(e.get("note", 1))), "p": p, "r": reach})
			"bell_statue":
				out.append({"e": e, "label": "Der Statue lauschen", "p": p, "r": reach + 30.0})
			"ember_source":
				if carry.is_empty():
					out.append({"e": e, "label": "Glut nehmen", "p": p, "r": reach})
			"frost_core":
				if carry.is_empty():
					out.append({"e": e, "label": "Frostherz nehmen", "p": p, "r": reach})
			"core_altar":
				if not _solved(e):
					out.append({"e": e, "label": "Frostherz einsetzen" if not carry.is_empty() and str(carry.kind) == "core" else "Altar: das Frostherz fehlt", "p": p, "r": reach + 20.0})
			"frost_rune":
				out.append({"e": e, "label": "Rune berühren: den Raum zurücksetzen", "p": p, "r": 80.0})
			"mirror_lever":
				if not _solved(e):
					out.append({"e": e, "label": "Spiegelhebel ziehen: der Spiegel zeigt den Weg" if hint_ready(e) else "Der Hebel ist noch eingefroren", "p": p, "r": reach})
	for e: Dictionary in g.W.ents:
		if str(e.type) == "brazier" and bool(e.get("cold", false)) and int(e.get("room", -1)) == int(g.state.room):
			var p := Vector2(float(e.x), float(e.y) - 30.0)
			if not bool(e.get("lit", false)):
				var label := "Glut in die Schale legen (%d)" % int(carry.left) if not carry.is_empty() and str(carry.kind) == "ember" else "Kalte Schale: hier fehlt Glut"
				out.append({"e": e, "label": label, "p": p, "r": 150.0})
			elif carry.is_empty():
				out.append({"e": e, "label": "Glut nehmen", "p": p, "r": 150.0})
	return out


## Uses piece `e`; false when it is none of these.
func use(e: Dictionary) -> bool:
	var type := str(e.get("type", ""))
	if type == "brazier" and bool(e.get("cold", false)):
		if bool(e.get("lit", false)):
			_take_ember(e)
		elif not carry.is_empty() and str(carry.kind) == "ember":
			carry = {}
			g.light_brazier(e)
		else:
			g.toast("Die Schale ist kalt. Trag Glut vom Herd hierher.")
		return true
	if not KINDS.has(type):
		return false
	match type:
		"prism":
			e.turn = 1 - int(e.get("turn", 0))
			e.spin = 0.25
			_effect("prism", Vector2(float(e.x), float(e.y)))
		"crystal":
			_strike(e)
		"bell_statue":
			_sing_melody(e)
		"ember_source":
			if carry.is_empty():
				_take_ember(e)
		"frost_core":
			if carry.is_empty():
				carry = {"kind": "core", "e": e}
				e.gone = true
				_index()
				g.toast("Du trägst das Frostherz. Bring es zum Altar.")
		"core_altar":
			if not carry.is_empty() and str(carry.kind) == "core":
				carry = {}
				e.filled = true
				_solve(str(e.group), "Das Frostherz sitzt im Altar. Das Eis gibt den Weg frei!")
			else:
				g.toast("Hier gehört das Frostherz hinein.")
		"frost_rune":
			reset_room(int(e.room))
			g.toast("Die Rune leuchtet auf. Alles im Raum steht wieder wie am Anfang.")
		"mirror_lever":
			if hint_ready(e):
				_start_show(e)
			else:
				g.toast("Der Hebel ist eingefroren. Versuch es erst selbst mit dem Spiegelbild.")
	return true


func _take_ember(from: Dictionary) -> void:
	carry = {"kind": "ember", "left": int((cfg.get("ember", {}) as Dictionary).get("steps", 14))}
	g.toast("Du trägst Glut: %d Schritte, im Kältenebel doppelt so schnell verbraucht." % int(carry.left))
	_effect("ember", Vector2(float(from.x), float(from.y) - 40.0))


func _strike(e: Dictionary) -> void:
	var note := int(e.get("note", 1))
	e.ring = 1.0
	_tone(note)
	var group := str(e.get("group", ""))
	var b: Dictionary = bells.get(group, {})
	if not bool(b.get("armed", false)) or _solved(e):
		return
	var melody := _melody(group)
	match bell_strike(melody, int(b.got), note):
		"right":
			b.got = int(b.got) + 1
		"done":
			b.armed = false
			_solve(group, "Die Melodie ist vollständig. Die Kristalle singen, ein Tor hebt sich!")
		"wrong":
			b.armed = false
			b.got = 0
			_tone(-1)
			g.toast("Ein falscher Ton. Tritt wieder auf die Platte und beginne von vorn.")


func _melody(group: String) -> Array:
	for e: Dictionary in pieces:
		if str(e.type) == "bell_statue" and str(e.get("group", "")) == group:
			return melody_of(e.get("melody", ""))
	return []


func _sing_melody(statue: Dictionary) -> void:
	if not song.is_empty():
		return
	var gap := float((cfg.get("bells", {}) as Dictionary).get("gap", 0.62))
	var at := 0.3
	statue.ring = 1.0
	for n: int in melody_of(statue.get("melody", "")):
		var crystal: Dictionary = {}
		if bool(statue.get("glow", false)):
			for e: Dictionary in pieces:
				if str(e.type) == "crystal" and str(e.get("group", "")) == str(statue.get("group", "")) and int(e.get("note", 1)) == n:
					crystal = e
		song.append({"at": at, "note": n, "e": crystal, "statue": statue})
		at += gap
	g.toast("Die Statue singt. Hör genau hin.")


func _sing(dt: float) -> void:
	for e: Dictionary in pieces:
		if float(e.get("ring", 0.0)) > 0.0:
			e.ring = maxf(0.0, float(e.ring) - dt * 1.6)
		if float(e.get("spin", 0.0)) > 0.0:
			e.spin = maxf(0.0, float(e.spin) - dt)
		if e.has("move"):
			e.move.t = float(e.move.t) + dt
			if float(e.move.t) >= float(e.move.time):
				e.erase("move")
	if song.is_empty():
		return
	for s: Dictionary in song:
		s.at = float(s.at) - dt
	while not song.is_empty() and float(song[0].at) <= 0.0:
		var s: Dictionary = song.pop_front()
		_tone(int(s.note))
		(s.statue as Dictionary).ring = 1.0
		if not (s.e as Dictionary).is_empty():
			(s.e as Dictionary).ring = 1.0


## Puts every piece of room `room` back; solved groups stay solved.
func reset_room(room: int) -> void:
	for e: Dictionary in pieces:
		if int(e.get("room", -1)) != room:
			continue
		match str(e.type):
			"ice_block", "snowball":
				if e.has("fill_at") and not _solved_room_fill(e):
					filled.erase(_key(e.fill_at))
					g.pit_restored(e.fill_at)
				if not e.has("fill_at") or not _solved_room_fill(e):
					e.erase("fill_at")
					e.gone = false
					e.erase("move")
					e.x = centre(e.home).x
					e.y = centre(e.home).y
					e.size = int(e.size0)
			"deep_snow":
				e.gone = false
			"thin_ice":
				if not _solved(e):
					e.left = int(e.get("holds", 2))
			"mirror_ghost":
				e.x = centre(e.home).x
				e.y = centre(e.home).y
				e.erase("move")
			"frost_core":
				if not _solved_altar(e):
					e.gone = false
	if not carry.is_empty() and str(carry.kind) == "core" and int((carry.e as Dictionary).room) == room:
		(carry.e as Dictionary).gone = false
	carry = {}
	for group: String in bells:
		bells[group].armed = false
		bells[group].got = 0
	_index()


## A filled crevasse stays filled once the room's way it made is not needed back: never, it goes too.
func _solved_room_fill(_e: Dictionary) -> bool:
	return false


func _solved_altar(core: Dictionary) -> bool:
	for e: Dictionary in pieces:
		if str(e.type) == "core_altar" and int(e.room) == int(core.room) and bool(e.get("filled", false)):
			return true
	return false


## The hero fell (hell_game _fall_into_pit). In a puzzle room he stands again on the firm ground he
## last left, the unsolved ice mended and what he carried back in its place: true then.
func catch_fall() -> bool:
	var room := int(g.state.room)
	if not rooms.has(room):
		return false
	# back to the start of the puzzle: its rune, else the firm ground he last left
	var back: Vector2i = firm.get(room, g.player_cell())
	for e: Dictionary in pieces:
		if str(e.type) == "frost_rune" and int(e.room) == room:
			back = cell_of(e)
	for e: Dictionary in pieces:
		if int(e.get("room", -1)) == room and str(e.type) == "thin_ice" and not _solved(e):
			e.left = int(e.get("holds", 2))
	if not carry.is_empty():
		if str(carry.kind) == "core":
			(carry.e as Dictionary).gone = false
		carry = {}
	_index()
	g.place_player(centre(back) + Vector2(0, 10))
	last_cell = back
	# the hero stands at the puzzle's rune again (above), so the note names the rune, not "the edge"
	g.toast("Eingebrochen! Zurück an der Rune. Das Eis ist wieder ganz.")
	return true


func fall_hurts() -> bool:
	return bool((cfg.get("ice", {}) as Dictionary).get("hurt", false))


# ---------- the mirror's show ----------

func _start_show(lever: Dictionary) -> void:
	var gh: Dictionary = {}
	for e: Dictionary in pieces:
		if str(e.type) == "mirror_ghost" and int(e.room) == int(lever.room):
			gh = e
	var rel: Array = gh.get("show", []) if not gh.is_empty() else []
	if rel.is_empty():
		g.toast("Der Spiegel bleibt stumm.")
		return
	var path: Array[Vector2i] = []
	for p: Variant in rel:
		path.append(Vector2i(gh.home) + Vector2i(int(p[0]), int(p[1])))
	show = {"ghost": gh, "path": path, "i": 0, "t": 0.0, "back": Vector2(float(g.player.x), float(g.player.y)), "back_ghost": cell_of(gh), "wait": 0.0}
	gh.x = centre(gh.home).x
	gh.y = centre(gh.home).y
	g.place_player(centre(path[0]) + Vector2(0, 10))
	g.toast("Der Spiegel zeigt den Weg. Sieh genau hin.")


## One frame of the show: the hero walks the way, the ghost follows; then both are put back.
func drive(dt: float) -> void:
	_sing(dt)
	var path: Array[Vector2i] = show.path
	var gh: Dictionary = show.ghost
	var step := float((cfg.get("ghost", {}) as Dictionary).get("show_step", 0.26))
	if int(show.i) >= path.size() - 1:
		show.wait = float(show.wait) + dt
		if float(show.wait) > 1.2:
			g.place_player(show.back)
			gh.x = centre(show.back_ghost).x
			gh.y = centre(show.back_ghost).y
			gh.erase("move")
			last_cell = g.player_cell()
			show = {}
			g.toast("So geht es. Jetzt du.")
		return
	show.t = float(show.t) + dt
	var a := centre(path[int(show.i)])
	var b := centre(path[int(show.i) + 1])
	var u := clampf(float(show.t) / step, 0.0, 1.0)
	g.place_player(a.lerp(b, u) + Vector2(0, 10))
	g.player.moving = true
	if u >= 1.0:
		_move_ghost(gh, path[int(show.i) + 1] - path[int(show.i)])
		show.i = int(show.i) + 1
		show.t = 0.0


# ---------- sound ----------

## Rings note n of the crystals (-1: the wrong, low clang).
func _tone(n: int) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var stream := _tone_stream(n)
	if _players.is_empty():
		for k in range(4):
			var p := AudioStreamPlayer.new()
			p.volume_db = -6.0
			g.add_child(p)
			_players.append(p)
	for p: AudioStreamPlayer in _players:
		if not p.playing:
			p.stream = stream
			p.play()
			return
	(_players[0] as AudioStreamPlayer).stream = stream
	(_players[0] as AudioStreamPlayer).play()


## A bell's tone, made from its partials (bells.voice) and kept.
func _tone_stream(n: int) -> AudioStreamWAV:
	if _tones.has(n):
		return _tones[n]
	var b: Dictionary = cfg.get("bells", {})
	var notes: Array = b.get("notes", [0, 2, 4, 7, 9, 12, 14, 16])
	var hz := float(b.get("base_hz", 523.25)) * (pow(2.0, float(notes[clampi(n - 1, 0, notes.size() - 1)]) / 12.0) if n > 0 else 0.42)
	_tones[n] = bell_wave(hz, float(b.get("length", 1.6)), float(b.get("decay", 3.2)), b.get("voice", [[1.0, 1.0]]))
	return _tones[n]


## A struck bell of `hz` as 16 bit sound: each partial [ratio, loudness] dies away by `decay`.
static func bell_wave(hz: float, length: float, decay: float, voice: Array) -> AudioStreamWAV:
	var rate := 22050
	var count := int(rate * length)
	var data := PackedByteArray()
	data.resize(count * 2)
	var total := 0.0
	for v: Variant in voice:
		total += float(v[1])
	for i in range(count):
		var t := float(i) / rate
		var s := 0.0
		for v: Variant in voice:
			s += float(v[1]) * sin(TAU * hz * float(v[0]) * t) * exp(-decay * t * (0.7 + float(v[0]) * 0.3))
		s = s / maxf(1.0, total) * minf(1.0, t * 400.0)
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 30000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = data
	return w


func _effect(kind: String, at: Vector2) -> void:
	if g.has_method("puzzle_effect"):
		g.puzzle_effect(kind, at)


# ---------- drawing ----------

## The flat pieces, the filled crevasses and the light, under everyone.
func draw_under(l: CanvasItem, view: Rect2, t: float) -> void:
	for k: int in filled:
		var c := Vector2i(k % _cols(), k / _cols())
		if view.has_point(centre(c)):
			draw_filled(l, centre(c), str(filled[k]))
	for e: Dictionary in pieces:
		if FLAT.has(str(e.type)) and view.grow(C).has_point(Vector2(float(e.x), float(e.y))):
			draw_flat(l, str(e.type), e, centre(cell_of(e)), t, g.tex)
	var beam: Dictionary = cfg.get("beam", {})
	for seg: Array in beams:
		draw_beam(l, seg[0], seg[1], t, beam)


## The standing pieces for the game's depth list: [depth, "frost", piece].
func sort_into(list: Array, view: Rect2) -> void:
	for e: Dictionary in pieces:
		var type := str(e.type)
		if e.get("gone", false) or FLAT.has(type) or not view.grow(C).has_point(Vector2(float(e.x), float(e.y))):
			continue
		list.append([float(e.y) + C * 0.36, "frost", e])


## One standing piece of the depth list.
func draw_piece(l: CanvasItem, e: Dictionary, t: float) -> void:
	var at := Vector2(float(e.x), float(e.y))
	if e.has("move"):
		var u := clampf(float(e.move.t) / float(e.move.time), 0.0, 1.0)
		at = (e.move.from as Vector2).lerp(at, u)
	if str(e.type) == "mirror_lever":
		e.awake = hint_ready(e)
	# the mirror ghost is the hero's own figure, mirrored and faint (hell_game.gd draw_mirror_hero)
	if str(e.type) == "mirror_ghost" and g.has_method("draw_mirror_hero"):
		var ghost: Dictionary = cfg.get("ghost", {})
		var feet := at + Vector2(0, 10)
		l.draw_set_transform(feet, 0.0, Vector2(1.0, 0.4))
		l.draw_circle(Vector2.ZERO, 44.0, Color(0.55, 0.9, 1.0, 0.16 + 0.06 * sin(t * 2.0)))
		l.draw_arc(Vector2.ZERO, 44.0, 0.0, TAU, 28, Color(0.75, 0.95, 1.0, 0.5), 3.0)
		l.draw_set_transform(Vector2.ZERO)
		if bool(g.draw_mirror_hero(l, feet, t, float(ghost.get("alpha", 0.55)), Color(str(ghost.get("tint", "bfeaff"))))):
			return
	draw_standing(l, str(e.type), e, at, t, g.tex)


var _zoom := 1.0


## The mirror needs the wider ghost.zoom to show both puzzle fields. Pixel
## cameras select that scale at the room boundary; other skins ease into it.
func view_zoom(dt: float, fixed_pixel_zoom := false) -> float:
	var ghost: Dictionary = cfg.get("ghost", {})
	var want := float(ghost.get("zoom", 0.72)) if not room_ghost().is_empty() else 1.0
	_zoom = want if fixed_pixel_zoom else move_toward(_zoom, want, dt * float(ghost.get("zoom_speed", 0.8)))
	return _zoom


## The mirror ghost of the hero's room ({} for none).
func room_ghost() -> Dictionary:
	for e: Dictionary in pieces:
		if str(e.type) == "mirror_ghost" and int(e.get("room", -1)) == int(g.state.room):
			return e
	return {}


## What the hero carries and the mirror's show, over the picture.
func draw_hud(h: Control, size: Vector2) -> void:
	var font := ThemeDB.fallback_font
	if not carry.is_empty():
		var text := "Glut: %d Schritte" % int(carry.left) if str(carry.kind) == "ember" else "Du trägst das Frostherz"
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
		var box := Rect2(size.x * 0.5 - w * 0.5 - 18.0, size.y - 128.0, w + 36.0, 38.0)
		h.draw_rect(box, Color(0.05, 0.08, 0.13, 0.82))
		h.draw_rect(box, Color("f0a05a") if str(carry.kind) == "ember" else Color("8fe6ff"), false, 2.0)
		h.draw_string(font, box.position + Vector2(18, 27), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE)
	if showing():
		var band := Rect2(0, 0, size.x, 70)
		h.draw_rect(band, Color(0.02, 0.05, 0.1, 0.7))
		h.draw_string(font, Vector2(0, 46), "Der Spiegel zeigt den Weg", HORIZONTAL_ALIGNMENT_CENTER, size.x, 30, Color("bdf3ff"))


# ---------- pictures, shared with the Weltbauer ----------

static func _cell_hash(c: Vector2i, k: int) -> float:
	var h := int(c.x * 73856093) ^ int(c.y * 19349663) ^ int(k * 83492791)
	return float(absi(h) % 1000) / 1000.0


## A flat piece at cell middle `m`: `e` holds its settings (and its state in the game).
static func draw_flat(l: CanvasItem, type: String, e: Dictionary, m: Vector2, t: float, tex: Dictionary) -> void:
	var c := Vector2i(int(floor(m.x / C)), int(floor(m.y / C)))
	var box := Rect2(m - Vector2(C, C) * 0.5, Vector2(C, C))
	match type:
		"thin_ice":
			var holds := int(e.get("holds", 2))
			var left := int(e.get("left", holds))
			if left <= 0:
				l.draw_rect(box.grow(-4.0), Color("06131f"))
				l.draw_rect(box.grow(-14.0), Color("0d2a40"))
				for k in range(7):
					var a := TAU * k / 7.0 + _cell_hash(c, k)
					var p := m + Vector2(cos(a), sin(a)) * 40.0
					l.draw_colored_polygon(PackedVector2Array([p, p + Vector2(cos(a + 1.9), sin(a + 1.9)) * 12.0, m + Vector2(cos(a), sin(a)) * 30.0]), Color("cdeeff"))
				return
			l.draw_rect(box.grow(-3.0), Color(0.72, 0.9, 1.0, 0.55 if holds >= 2 else 0.42))
			l.draw_rect(box.grow(-3.0), Color(0.9, 0.98, 1.0, 0.7), false, 2.0)
			var cracks := 2 if left >= 2 else 6
			for k in range(cracks):
				var a := TAU * _cell_hash(c, k + 11)
				var p := m + Vector2(cos(a), sin(a)) * (6.0 + 10.0 * _cell_hash(c, k))
				var q := p + Vector2(cos(a + 0.6), sin(a + 0.6)) * (22.0 + 16.0 * _cell_hash(c, k + 3))
				l.draw_line(p, q, Color(1, 1, 1, 0.85), 2.0)
				l.draw_line(q, q + Vector2(cos(a - 0.5), sin(a - 0.5)) * 12.0, Color(1, 1, 1, 0.7), 1.5)
			if holds == 1 or left == 1:
				l.draw_rect(box.grow(-12.0), Color(0.2, 0.4, 0.6, 0.25))
		"deep_snow":
			if e.get("gone", false):
				return
			for k in range(5):
				var p := m + Vector2((_cell_hash(c, k) - 0.5) * 54.0, (_cell_hash(c, k + 5) - 0.5) * 50.0)
				l.draw_circle(p, 20.0 + 8.0 * _cell_hash(c, k + 9), Color(0.96, 0.98, 1.0, 0.9))
			l.draw_circle(m + Vector2(-8, -6), 14.0, Color(1, 1, 1, 1))
		"cold_fog":
			for k in range(4):
				var a := t * 0.4 + k * 1.7 + _cell_hash(c, k) * 6.0
				l.draw_circle(m + Vector2(cos(a) * 22.0, sin(a * 0.8) * 16.0), 30.0, Color(0.6, 0.78, 1.0, 0.16))
			l.draw_rect(box, Color(0.55, 0.72, 0.95, 0.12))
		"ice_goal", "ghost_plate", "bell_plate", "frost_rune":
			var tint: Color = {"ice_goal": Color("bfefff"), "bell_plate": Color("c7a6ff"), "frost_rune": Color("7fffd4")}.get(type, Color("ffd27a") if str(e.get("who", "hero")) == "hero" else Color("8fe6ff"))
			var plate: Texture2D = tex.get("rune_plate")
			if plate != null:
				l.draw_texture(plate, m - plate.get_size() * 0.5, tint)
			else:
				l.draw_rect(box.grow(-16.0), tint * Color(1, 1, 1, 0.6))
			var pulse := 0.5 + 0.5 * sin(t * 3.0 + m.x)
			l.draw_arc(m, 30.0, 0.0, TAU, 24, Color(tint, 0.35 + 0.4 * pulse), 3.0)
			if type == "frost_rune":
				l.draw_arc(m, 18.0, t, t + 4.0, 16, Color(tint, 0.9), 3.0)


## A crevasse filled by a block (ice) or a snowball (snow).
static func draw_filled(l: CanvasItem, m: Vector2, how: String) -> void:
	var box := Rect2(m - Vector2(C, C) * 0.5, Vector2(C, C))
	if how == "snow":
		l.draw_rect(box.grow(-2.0), Color("e8f2fb"))
		l.draw_circle(m + Vector2(-14, -10), 22.0, Color(1, 1, 1))
		l.draw_circle(m + Vector2(16, 8), 26.0, Color("dbe9f5"))
	else:
		l.draw_rect(box.grow(-2.0), Color("8fd0f0"))
		l.draw_rect(box.grow(-2.0), Color("dff6ff"), false, 3.0)
		l.draw_line(box.position + Vector2(14, 20), box.position + Vector2(50, 70), Color(1, 1, 1, 0.6), 2.0)


## The aurora light from a to b.
static func draw_beam(l: CanvasItem, a: Vector2, b: Vector2, t: float, beam: Dictionary) -> void:
	var w := float(beam.get("width", 9.0))
	var lift := Vector2(0, -34)
	var shimmer := 0.85 + 0.15 * sin(t * 9.0)
	l.draw_line(a + lift, b + lift, Color(str(beam.get("edge", "0b2a44")), 0.85), w + 6.0)
	l.draw_line(a + lift, b + lift, Color(str(beam.get("glow", "5fe3ff")), 0.75 * shimmer), w + 2.0)
	l.draw_line(a + lift, b + lift, Color(str(beam.get("core", "eafcff"))), maxf(2.0, w * 0.4))


## A standing piece with its foot near the cell's middle `m`.
static func draw_standing(l: CanvasItem, type: String, e: Dictionary, m: Vector2, t: float, tex: Dictionary) -> void:
	var foot := m + Vector2(0, C * 0.34)
	var ring := float(e.get("ring", 0.0))
	match type:
		"ice_block":
			var r := Rect2(foot - Vector2(42, 78), Vector2(84, 78))
			l.draw_rect(Rect2(foot - Vector2(40, 6), Vector2(80, 10)), Color(0, 0, 0, 0.25))
			l.draw_rect(r, Color("7cc6ea"))
			l.draw_rect(Rect2(r.position, Vector2(r.size.x, 22)), Color("c9f0ff"))
			l.draw_rect(r, Color("e8fbff"), false, 3.0)
			l.draw_line(r.position + Vector2(12, 30), r.position + Vector2(30, 66), Color(1, 1, 1, 0.55), 3.0)
			l.draw_line(r.position + Vector2(58, 34), r.position + Vector2(70, 52), Color(1, 1, 1, 0.4), 2.0)
		"snowball":
			var size := int(e.get("size", 1))
			var rad: float = [0.0, 20.0, 30.0, 40.0][clampi(size, 1, 3)]
			var c := foot - Vector2(0, rad)
			l.draw_circle(foot + Vector2(0, -2), rad * 0.9, Color(0, 0, 0, 0.22))
			l.draw_circle(c, rad, Color("dfe9f3"))
			l.draw_circle(c + Vector2(-rad * 0.25, -rad * 0.3), rad * 0.62, Color("f8fbff"))
			l.draw_arc(c, rad, 0.0, TAU, 32, Color("9fb5cc"), 2.0)
		"prism":
			var turn := int(e.get("turn", 0))
			var c := foot - Vector2(0, 50)
			var spin := float(e.get("spin", 0.0)) * 4.0
			var gem := PackedVector2Array([c + Vector2(0, -46), c + Vector2(34, 0), c + Vector2(0, 40), c + Vector2(-34, 0)])
			l.draw_rect(Rect2(foot - Vector2(38, 14), Vector2(76, 18)), Color("33475e"))
			l.draw_colored_polygon(gem, Color(0.55, 0.88, 1.0, 0.92))
			l.draw_polyline(PackedVector2Array([gem[0], gem[1], gem[2], gem[3], gem[0]]), Color("e9fbff"), 2.0)
			var dir := Vector2(1, -1) if turn == 0 else Vector2(1, 1)
			dir = dir.rotated(spin)
			l.draw_line(c - dir.normalized() * 42.0, c + dir.normalized() * 42.0, Color("10263a"), 12.0)
			l.draw_line(c - dir.normalized() * 42.0, c + dir.normalized() * 42.0, Color("ffffff"), 6.0)
			if bool(e.get("fixed", false)):
				l.draw_circle(c, 5.0, Color("10263a"))
		"beam_source":
			var pillar: Texture2D = tex.get("rune_pillar_c")
			if pillar != null:
				l.draw_texture(pillar, foot - Vector2(pillar.get_width() * 0.5, pillar.get_height()))
			var c := foot - Vector2(0, 92)
			l.draw_circle(c, 18.0 + 3.0 * sin(t * 4.0), Color(0.4, 1.0, 0.85, 0.35))
			l.draw_circle(c, 10.0, Color("dcfff6"))
			var d: Vector2 = Vector2(DIRS.get(str(e.get("dir", "e")), Vector2i(1, 0)))
			l.draw_line(c, c + d * 26.0, Color("dcfff6"), 4.0)
		"beam_seal":
			var lit := bool(e.get("lit", false))
			var c := foot - Vector2(0, 40)
			l.draw_rect(Rect2(foot - Vector2(30, 70), Vector2(60, 70)), Color("2a3a52"))
			l.draw_rect(Rect2(foot - Vector2(30, 70), Vector2(60, 70)), Color("8aa4c4"), false, 2.0)
			l.draw_arc(c, 18.0, 0.0, TAU, 24, Color("7fffe0") if lit else Color("5d7391"), 4.0)
			if lit:
				l.draw_circle(c, 26.0 + 4.0 * sin(t * 6.0), Color(0.5, 1.0, 0.9, 0.3))
				l.draw_circle(c, 9.0, Color("eafff9"))
		"crystal":
			# the Frostgruft's ice spire in the note's colour (tools/frost_dungeon/make_bell_crystals.gd)
			var n := int(e.get("note", 1))
			var col := crystal_color(n)
			var im := crystal_tex(n)
			var c := foot - Vector2(0, 50)
			if ring > 0.0:
				l.draw_circle(c, 40.0 + 34.0 * (1.0 - ring), Color(col, 0.45 * ring))
			if im != null:
				l.draw_texture(im, foot + Vector2(-im.get_width() * 0.5, 8.0 - im.get_height()))
				if ring > 0.0:
					l.draw_texture(im, foot + Vector2(-im.get_width() * 0.5, 8.0 - im.get_height()), Color(1.6, 1.6, 1.6, 0.55 * ring))
			else:
				l.draw_colored_polygon(PackedVector2Array([foot + Vector2(-26, 0), foot + Vector2(0, -96), foot + Vector2(26, 0)]), col)
			if ring > 0.0:
				for k in range(5):
					var a := TAU * k / 5.0 + (1.0 - ring) * 2.0
					l.draw_circle(c + Vector2(cos(a), sin(a)) * (30.0 + 40.0 * (1.0 - ring)), 3.5, Color(col.lightened(0.5), ring))
		"bell_statue":
			var im: Texture2D = tex.get("statue_angel")
			if im != null:
				l.draw_texture(im, foot - Vector2(im.get_width() * 0.5, im.get_height()))
			else:
				l.draw_rect(Rect2(foot - Vector2(26, 110), Vector2(52, 110)), Color("9db2c9"))
			if ring > 0.0:
				for k in range(3):
					l.draw_arc(foot - Vector2(0, 90), 20.0 + k * 14.0 + 16.0 * (1.0 - ring), -0.8, 0.8, 10, Color(0.85, 0.75, 1.0, ring * 0.8), 2.0)
					l.draw_arc(foot - Vector2(0, 90), 20.0 + k * 14.0 + 16.0 * (1.0 - ring), PI - 0.8, PI + 0.8, 10, Color(0.85, 0.75, 1.0, ring * 0.8), 2.0)
		"ember_source":
			var im: Texture2D = tex.get("brazier_floor")
			if im != null:
				l.draw_texture(im, foot - Vector2(im.get_width() * 0.5, im.get_height()))
			var c := foot - Vector2(0, 52)
			for k in range(5):
				var a := t * 7.0 + k * 1.3
				var hgt := 18.0 + 10.0 * sin(a)
				l.draw_colored_polygon(PackedVector2Array([c + Vector2(-12 + k * 6, 6), c + Vector2(-6 + k * 6, -hgt), c + Vector2(k * 6, 6)]), Color(1.0, 0.45 + 0.1 * k, 0.12, 0.85))
			l.draw_circle(c, 10.0, Color("ffe27a"))
		"core_altar":
			var im: Texture2D = tex.get("altar")
			if im != null:
				l.draw_texture(im, foot - Vector2(im.get_width() * 0.5, im.get_height()))
			else:
				l.draw_rect(Rect2(foot - Vector2(44, 50), Vector2(88, 50)), Color("6c7f96"))
			if bool(e.get("filled", false)):
				_heart(l, foot - Vector2(0, 76), t, 1.0)
		"frost_core":
			_heart(l, foot - Vector2(0, 40 + 6.0 * sin(t * 2.5)), t, 1.0)
		"mirror_lever":
			var im: Texture2D = tex.get("rune_pillar_d")
			if im != null:
				l.draw_texture(im, foot - Vector2(im.get_width() * 0.5, im.get_height()))
			var awake := bool(e.get("awake", false))
			l.draw_line(foot - Vector2(0, 60), foot - Vector2(-30, 96), Color("c9d6e6"), 6.0)
			l.draw_circle(foot - Vector2(-30, 96), 8.0, Color("8fe6ff") if awake else Color("4a5a6e"))
		"mirror_ghost":
			var c := foot - Vector2(0, 50)
			var wob := sin(t * 3.0) * 4.0
			l.draw_circle(c + Vector2(0, -26 + wob), 17.0, Color(0.75, 0.97, 1.0, 0.9))
			l.draw_colored_polygon(PackedVector2Array([c + Vector2(-18, -12 + wob), c + Vector2(18, -12 + wob), c + Vector2(22, 30), c + Vector2(8, 22), c + Vector2(0, 34), c + Vector2(-8, 22), c + Vector2(-22, 30)]), Color(0.6, 0.9, 1.0, 0.82))
			l.draw_circle(c + Vector2(-5, -28 + wob), 3.0, Color("0b2a44"))
			l.draw_circle(c + Vector2(5, -28 + wob), 3.0, Color("0b2a44"))
			l.draw_circle(c, 52.0, Color(0.5, 0.9, 1.0, 0.12 + 0.06 * sin(t * 2.0)))
			l.draw_arc(c, 52.0, 0.0, TAU, 28, Color(0.7, 0.95, 1.0, 0.45 + 0.2 * sin(t * 2.0)), 3.0)


static var _crystal_pics: Dictionary = {}
static var _crystal_list: Array = []


## The picture of the crystal of note n (assets/sprites/frost_hd/bells), null when it is missing.
static func crystal_tex(n: int) -> Texture2D:
	if not _crystal_pics.has(n):
		var path := "res://assets/sprites/frost_hd/bells/bell_crystal_%d.png" % n
		_crystal_pics[n] = load(path) if ResourceLoader.exists(path) else null
	return _crystal_pics[n]


## The crystals' colours by note (world_frost_puzzles.json bells.crystals, note 1 first).
static func _crystals() -> Array:
	if _crystal_list.is_empty():
		_crystal_list = (load_config().get("bells", {}) as Dictionary).get("crystals", [])
	return _crystal_list


## The colour of the crystal of note n.
static func crystal_color(n: int) -> Color:
	var list := _crystals()
	return Color(str((list[(n - 1) % list.size()] as Dictionary).color)) if not list.is_empty() and n >= 1 else Color("8fe6ff")


## The colour name of the crystal of note n ("Rot", ...).
static func crystal_name(n: int) -> String:
	var list := _crystals()
	return str((list[(n - 1) % list.size()] as Dictionary).name) if not list.is_empty() and n >= 1 else str(n)


static func _heart(l: CanvasItem, c: Vector2, t: float, s: float) -> void:
	l.draw_circle(c, 30.0 * s + 4.0 * sin(t * 3.0), Color(0.5, 0.85, 1.0, 0.25))
	var gem := PackedVector2Array([c + Vector2(0, -24) * s, c + Vector2(18, -6) * s, c + Vector2(0, 22) * s, c + Vector2(-18, -6) * s])
	l.draw_colored_polygon(gem, Color("7fd9ff"))
	l.draw_polyline(PackedVector2Array([gem[0], gem[1], gem[2], gem[3], gem[0]]), Color("f2fdff"), 2.0)
	l.draw_line(c + Vector2(-6, -10) * s, c + Vector2(2, -18) * s, Color(1, 1, 1, 0.8), 3.0)
