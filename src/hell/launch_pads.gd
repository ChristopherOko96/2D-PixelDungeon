extends RefCounted
## Sprungplatten: a pad on the floor throws the hero a set number of cells in its direction, over
## walls, lava and pits, as a puzzle piece (placed in the Weltbauer, src/world_editor). The hero
## does not jump by a key: stepping on the pad fires it, and a pad at the landing spot throws on,
## so paths of several throws can be built. Values: assets/data/world_launch_pads.json.

const DATA_PATH := "res://assets/data/world_launch_pads.json"
const STEPS := {"n": Vector2i(0, -1), "e": Vector2i(1, 0), "s": Vector2i(0, 1), "w": Vector2i(-1, 0)}

var g: Node
var cfg: Dictionary = {}
## The throw under way: {"from", "to", "t", "time", "height", "pad"}; {} on the ground.
var flight: Dictionary = {}


func _init(game: Node, data: Dictionary = {}) -> void:
	g = game
	cfg = data if not data.is_empty() else load_config()


## The pad values from the data file.
static func load_config() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))


## The spot `cells` cells from `from` in direction `dir` ("n", "e", "s", "w").
static func target_of(from: Vector2, dir: String, cells: int, cell_px: float) -> Vector2:
	return from + Vector2(STEPS.get(dir, Vector2i.ZERO)) * float(cells) * cell_px


## How high the hero is over the floor at `u` (0..1 of the throw), for an arc of `height`.
static func arc(u: float, height: float) -> float:
	return 4.0 * height * u * (1.0 - u)


## False while pad `e` sleeps: a pad with `wake` throws only once that group of `groups` is solved
## (a plate, lever or fire bowl of its room wakes it). A pad without `wake` is always awake.
static func awake(e: Dictionary, groups: Dictionary) -> bool:
	var group := str(e.get("wake", ""))
	return group == "" or bool((groups.get(group, {}) as Dictionary).get("solved", false))


## True while the hero is in the air: nothing on the floor touches him.
func flying() -> bool:
	return not flight.is_empty()


## His height over the floor now, in world px.
func lift() -> float:
	if flight.is_empty():
		return 0.0
	return arc(clampf(float(flight.t) / float(flight.time), 0.0, 1.0), float(flight.height))


## One pad of the world this frame (hell_game _update_hazards): it arms once the hero has stepped
## off it, and fires a short moment after he stands on an armed one.
func update_pad(e: Dictionary, me: Vector2, dt: float) -> void:
	var reach := float(cfg.reach)
	var on := absf(me.x - float(e.x)) <= reach and absf(me.y - 10.0 - float(e.y)) <= reach
	e.press = move_toward(float(e.get("press", 0.0)), 1.0 if on or flying() and is_same(flight.get("pad"), e) else 0.0, dt / 0.08)
	if flying():
		return
	if not on:
		e.armed = true
		e.wait = 0.0
		return
	if not bool(e.get("armed", true)):
		return
	e.wait = float(e.get("wait", 0.0)) + dt
	if float(e.wait) >= float(cfg.windup):
		throw_from(e)


## Throws the hero from pad `e`; a blocked landing spot gives way back along the path.
func throw_from(e: Dictionary) -> void:
	var from := Vector2(float(g.player.x), float(g.player.y))
	var cells := int(e.get("cells", cfg.default_cells))
	var start := Vector2(float(e.x), float(e.y) + 10.0)
	var to := landing(start, target_of(start, str(e.get("dir", "n")), cells, float(g.C)))
	e.armed = false
	e.wait = 0.0
	last_pad = e
	var thrown := from.distance_to(to) / float(g.C)
	flight = {"from": from, "to": to, "t": 0.0, "time": float(cfg.air_base) + float(cfg.air_per_cell) * thrown,
		"height": float(cfg.height_base) + float(cfg.height_per_cell) * thrown, "pad": e}
	g.player.vel = Vector2.ZERO
	g.player.moving = false
	if absf(to.x - from.x) > 1.0:
		g.player.face = signf(to.x - from.x)
	if g.sound != null:
		g.sound.hero("dash_land")
	if g.feel != null:
		g.feel.feedback.particles.dust_flat(from / float(g.feel.scale), 14.0, 10)


## The free spot nearest to `to` on the straight line from `from`.
func landing(from: Vector2, to: Vector2) -> Vector2:
	var length := from.distance_to(to)
	var back := float(cfg.step)
	var along := 0.0
	while along < length:
		var at := to.move_toward(from, along)
		if not g.box_blocked(g._player_box(at.x, at.y)):
			return at
		along += back
	return from


## The hero in the air (hell_game _update_player): he flies the arc and lands; every floor rule
## waits until he is down.
func step(dt: float) -> void:
	flight.t = float(flight.t) + dt
	var u := clampf(float(flight.t) / float(flight.time), 0.0, 1.0)
	var at: Vector2 = (flight.from as Vector2).lerp(flight.to, u)
	g.player.x = at.x
	g.player.y = at.y
	g.player.vel = Vector2.ZERO
	g.player.moving = false
	if u >= 1.0:
		_land(at)


func _land(at: Vector2) -> void:
	flight = {}
	# a pad under the landing spot throws on (it counts as armed)
	for e: Dictionary in g.W.ents:
		if e.type == "launch":
			e.armed = true
	if g.sound != null:
		g.sound.hero("dash_land")
	if g.feel != null:
		g.feel.feedback.particles.dust_flat(at / float(g.feel.scale), 22.0, 16)
	g.state.shake = maxf(float(g.state.get("shake", 0.0)), float(cfg.shake))


## Near a pad the hero sees where it throws: a dotted arc and a ring at the landing spot, so a throw
## into a trap can be seen before it is taken.
func draw_preview(layer: CanvasItem, e: Dictionary, me: Vector2) -> void:
	var c := float(g.C)
	var start := Vector2(float(e.x), float(e.y) + 10.0)
	if flying() or start.distance_to(me) > float(cfg.preview_cells) * c:
		return
	var to := landing(start, target_of(start, str(e.get("dir", "n")), int(e.get("cells", cfg.default_cells)), c))
	var thrown := start.distance_to(to) / c
	var color := Color(str(cfg.preview_color))
	var dots := maxi(2, int(thrown / float(cfg.preview_dot_cells)))
	var height := float(cfg.height_base) + float(cfg.height_per_cell) * thrown
	for k in range(1, dots):
		var u := float(k) / float(dots)
		layer.draw_circle(start.lerp(to, u) - Vector2(0.0, arc(u, height)), 5.0, color)
	layer.draw_arc(to, float(cfg.preview_mark), 0.0, TAU, 24, color, 4.0)


## Where a hero stands again who fell into a pit in a jump puzzle: on the pad he was thrown from.
var last_pad: Dictionary = {}


## Puts the hero back on the pad of the last throw. False when there was none on this floor.
func back_on_pad() -> bool:
	if last_pad.is_empty():
		return false
	g.player.x = float(last_pad.x)
	g.player.y = float(last_pad.y) + 10.0
	last_pad.armed = false
	return true


## A new floor: nobody is in the air.
func reset() -> void:
	flight = {}
	last_pad = {}
