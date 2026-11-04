extends RefCounted
## Stateful cosmetic surface mass. Fixed-step damped springs share force fronts
## with the particle world; the authoritative PoolField is never written here.
var nodes: Dictionary = {}
var cfg: Dictionary
var open: Callable
var art: float
var spacing: float
var time := -1.0
var debt := 0.0
var revision := 0
var active := false
var _next_prune := 0.0
var _wall_band: Dictionary = {}

func _init(pixel: float, floor_open: Callable, settings: Dictionary) -> void:
	art = pixel
	open = floor_open
	cfg = settings
	spacing = art * float(cfg.get("spacing_art", 12.0))

## Bilinear material offset; touching a surface keeps only its local mass alive.
func offset(point: Vector2) -> Vector2:
	var grid := point / spacing
	var cell := Vector2i(grid.floor())
	var t := grid - Vector2(cell)
	var values: Array[Vector2] = []
	for side: Vector2i in [Vector2i.ZERO, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.ONE]:
		var q := cell + side
		if not nodes.has(q) and nodes.size() < int(cfg.get("max_nodes", 2048)):
			nodes[q] = {"d":Vector2.ZERO,"v":Vector2.ZERO,"seen":time}
		var node: Dictionary = nodes.get(q, {})
		if node.is_empty(): values.append(Vector2.ZERO)
		else:
			node.seen = time
			values.append(node.d)
	return _safe(point, values[0].lerp(values[1], t.x).lerp(values[2].lerp(values[3], t.x), t.y))

## Register only the coarse support of a resting field, without building a mesh.
func touch_box(rect: Rect2) -> void:
	var low := Vector2i((rect.position/spacing).floor())
	var high := Vector2i((rect.end/spacing).ceil())
	for y in range(low.y,high.y+1):
		for x in range(low.x,high.x+1):
			var q := Vector2i(x,y)
			if nodes.has(q): nodes[q].seen = time
			elif nodes.size() < int(cfg.get("max_nodes",2048)):
				nodes[q] = {"d":Vector2.ZERO,"v":Vector2.ZERO,"seen":time}

## A real expanding force band, respecting its cone, squash and wall visibility.
func pressure(origin: Vector2, r0: float, r1: float, angle: float, arc: float, speed: float, squash: float) -> void:
	if r1 <= r0 or speed <= 0: return
	for q: Vector2i in nodes:
		var point := Vector2(q) * spacing
		var off := point - origin
		var d := Vector2(off.x, off.y / maxf(0.05,squash)).length()
		# The sampled mass spans a coarse cell; include that support in a thin front.
		if d < maxf(0,r0-spacing*0.5) or d > r1+spacing*0.5 or d <= 0: continue
		if arc < TAU and absf(wrapf(off.angle()-angle,-PI,PI)) > arc*0.5: continue
		if not _visible(origin,point): continue
		var node: Dictionary = nodes[q]
		node.v = (Vector2(node.v) + off.normalized()*speed*float(cfg.get("pressure_share",0.3))).limit_length(art*float(cfg.get("max_speed_art",70)))
		active = true
	revision += 1

## Physical time is independent of render count; repeated draws cannot step twice.
func advance(now: float) -> void:
	if time < 0 or now < time:
		time = now
		debt = 0
		return
	debt += minf(now-time,0.25)
	time = now
	if time >= _next_prune:
		_next_prune = time+0.5
		for q: Vector2i in nodes.keys():
			if time-float(nodes[q].seen)>float(cfg.get("idle_ttl",4)): nodes.erase(q)
	var dt := 1.0 / 60.0
	while debt + 0.0000001 >= dt:
		debt -= dt
		_step(dt)

func _step(dt: float) -> void:
	if not active: return
	var accelerations := {}
	for q: Vector2i in nodes:
		var n: Dictionary = nodes[q]
		var mean := Vector2.ZERO
		var count := 0
		for side: Vector2i in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			if nodes.has(q+side):
				mean += Vector2(nodes[q+side].d)
				count += 1
		var acceleration := -Vector2(n.d)*float(cfg.get("spring",75))-Vector2(n.v)*float(cfg.get("damping",9))
		if count > 0: acceleration += (mean/count-Vector2(n.d))*float(cfg.get("coupling",35))
		accelerations[q] = acceleration
	var moved := false
	for q: Vector2i in nodes.keys():
		var n: Dictionary = nodes[q]
		if time-float(n.seen) > float(cfg.get("idle_ttl",4)):
			nodes.erase(q)
			continue
		n.v = Vector2(n.v) + Vector2(accelerations[q])*dt
		var next := (Vector2(n.d)+Vector2(n.v)*dt).limit_length(minf(spacing*0.3,art*float(cfg.get("max_offset_art",4))))
		n.d = _safe(Vector2(q)*spacing,next)
		if Vector2(n.d).length_squared() < 0.0001 and Vector2(n.v).length_squared() < 0.0001:
			n.d = Vector2.ZERO
			n.v = Vector2.ZERO
		if not Vector2(n.d).is_zero_approx() or not Vector2(n.v).is_zero_approx(): moved = true
	if moved: revision += 1
	active = moved

func _safe(point: Vector2, displacement: Vector2) -> Vector2:
	if displacement.is_zero_approx() or not open.is_valid(): return displacement
	# Pin a band along solid geometry: a warped textured triangle cannot bleed
	# across the wall between its vertices. No material crosses a door or prop.
	var pin: Dictionary = _wall_band.get(point,{})
	if pin.is_empty() or time>=float(pin.until):
		pin = {"until":time+0.15,"blocked":false}
		for side: Vector2 in [Vector2.ZERO,Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN,Vector2(-1,-1),Vector2(1,-1),Vector2(-1,1),Vector2.ONE]:
			if not open.call(point+side*spacing*1.5):
				pin.blocked = true
				break
		if _wall_band.size()>int(cfg.get("max_nodes",2048))*2: _wall_band.clear()
		_wall_band[point] = pin
	if bool(pin.blocked) or not open.call(point+displacement): return Vector2.ZERO
	return displacement

func _visible(from: Vector2, to: Vector2) -> bool:
	if not open.is_valid(): return true
	var steps := maxi(1,ceili(from.distance_to(to)/maxf(art*2,1)))
	for i in range(steps+1):
		if not open.call(from.lerp(to,float(i)/steps)): return false
	return true

## Forget every force and node on a room change.
func clear() -> void:
	nodes.clear()
	_wall_band.clear()
	active = false
	time = -1
	debt = 0
	revision += 1
