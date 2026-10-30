extends RefCounted
## Per-frame poses of the part rigs, ported 1:1 from the approved review page
## (production/art-proof/0x72-style/full.template.html, POSES). A pose moves
## the whole figure and each part/item; values are in source pixels and
## radians. `a` is the presentation state of one actor (see RigRenderer):
## t (seconds), moving, clip, u (0..1 clip progress), lost, regrowing; the
## drake (Ignaroth) also reads flying, cycle and windows.

## A neutral pose.
static func blank() -> Dictionary:
	return {"whole": {"dx": 0.0, "dy": 0.0, "rot": 0.0, "sx": 1.0, "sy": 1.0, "pivot": null}, "parts": {}, "items": {}, "trail": false, "pull": 0.0, "nock": false}


static func P(pose: Dictionary, id: String) -> Dictionary:
	if not pose.parts.has(id): pose.parts[id] = {"dx": 0.0, "dy": 0.0, "rot": 0.0, "sx": 1.0, "sy": 1.0, "alpha": 1.0}
	return pose.parts[id]


static func I(pose: Dictionary, id: String) -> Dictionary:
	if not pose.items.has(id): pose.items[id] = {"dx": 0.0, "dy": 0.0, "rot": 0.0}
	return pose.items[id]


static func seg(u: float, a: float, b: float) -> float:
	return clampf((u - a) / (b - a), 0.0, 1.0)


static func ease_out(k: float) -> float:
	return 1.0 - pow(1.0 - clampf(k, 0.0, 1.0), 3.0)


static func ease_in(k: float) -> float:
	return pow(clampf(k, 0.0, 1.0), 2.0)


static func ease_in_out(k: float) -> float:
	k = clampf(k, 0.0, 1.0)
	return 4.0 * k * k * k if k < 0.5 else 1.0 - pow(-2.0 * k + 2.0, 3.0) / 2.0


static func _walk_legs(pose: Dictionary, l: String, r: String, ph: float, stride: float, lift: float) -> void:
	P(pose, l).dx = sin(ph) * stride
	P(pose, l).dy = -maxf(0.0, cos(ph)) * lift
	P(pose, r).dx = -sin(ph) * stride
	P(pose, r).dy = -maxf(0.0, -cos(ph)) * lift


## Wind up, strike, recover; returns the lunge (0..1) and sets the item turn.
static func _strike(pose: Dictionary, u: float, a0: float, a1: float, wind_end: float, hit_end: float, id: String = "weapon") -> float:
	var w := I(pose, id)
	if u < wind_end:
		var k := ease_in_out(u / wind_end)
		w.rot = a0 * k
		return -0.3 * k
	if u < hit_end:
		var k := ease_out(seg(u, wind_end, hit_end))
		w.rot = lerpf(a0, a1, k)
		pose.trail = true
		return -0.3 + 1.3 * k
	var k := ease_in_out(seg(u, hit_end, 1.0))
	w.rot = a1 * (1.0 - k)
	return 1.0 - k


## Pull the string, release, let it vibrate.
static func _bow_draw(pose: Dictionary, u: float, release: float = 0.62) -> void:
	if u < release:
		pose.pull = ease_out(u / release) * 5.0
		pose.nock = true
	else:
		var k := seg(u, release, 1.0)
		pose.pull = -1.2 * sin(k * 30.0) * (1.0 - k)


## The pose of rig `rig` for actor state `a`.
static func pose(rig: Dictionary, a: Dictionary) -> Dictionary:
	var out := _family_pose(rig, a)
	if bool(rig.get("layered", false)) or bool(rig.get("item_parts", false)): _layered_extras(rig, a, out)
	_sway(rig, a, out)
	return out


## Parts that sway on their own whatever the family does (rigs.json part
## "sway": [rest, amplitude, period, phase] in rad, rad, s, rad): turned by
## rest plus a sine. Hung one on another with growing phases they move like a
## tentacle, a wave running down to the tip (the Klagender Hüter's chains).
static func _sway(rig: Dictionary, a: Dictionary, out: Dictionary) -> void:
	var t := float(a.get("t", 0.0))
	for part: Dictionary in rig.get("parts", []):
		var sw: Variant = part.get("sway", [])
		if not sw is Array or (sw as Array).size() < 4:
			continue
		P(out, str(part.id)).rot += float(sw[0]) + float(sw[1]) * sin(t * TAU / maxf(0.1, float(sw[2])) + float(sw[3]))


## Hell mobs reuse the crypt families on layered rigs (assets/data/hell_rigs.json):
## a held weapon is a part there, so the family's item motion moves that part;
## flame flipbooks the family does not drive flicker at 8 frames a second.
static func _layered_extras(rig: Dictionary, a: Dictionary, out: Dictionary) -> void:
	var by_id: Dictionary = rig.get("by_id", {})
	for id: String in out.items:
		if not by_id.has(id) or bool(by_id[id].get("is_item", false)): continue
		var item: Dictionary = out.items[id]
		var part := P(out, id)
		part.dx += float(item.get("dx", 0.0))
		part.dy += float(item.get("dy", 0.0))
		part.rot += float(item.get("rot", 0.0))
	if not out.has("frames"): out.frames = {}
	for part: Dictionary in rig.get("parts", []):
		if part.get("frames") is Array and (part.frames as Array).size() > 1 and not out.frames.has(part.id):
			out.frames[part.id] = int(floor(float(a.get("t", 0.0)) * 8.0 + float(int(part.get("z", 0)) * 3))) % (part.frames as Array).size()


static func _family_pose(rig: Dictionary, a: Dictionary) -> Dictionary:
	match str(rig.get("family", "")):
		"hero": return hero(rig, a)
		"skeleton": return skeleton(rig, a)
		"necro": return necro(rig, a)
		"biped": return biped(rig, a)
		"brute": return brute(rig, a)
		"golem": return golem(rig, a)
		"void": return void_lord(rig, a)
		"bomber": return bomber(rig, a)
		"mimic": return mimic(rig, a)
		"drake": return drake(rig, a)
		"slime": return slime(rig, a)
		"spirit": return spirit(rig, a)
	return blank()


## Slime (the Frostgruft's Eisschleim): a jelly that breathes by squashing from
## the floor up, its top ("top") lagging behind its base so it wobbles. It
## moves in hops (stretched in the air, squashed on landing); "attack" swells
## and splats wide, "roar" quivers, "hit" squashes it flat for a moment and
## "death" melts it into the floor.
static func slime(rig: Dictionary, a: Dictionary) -> Dictionary:
	var pose := blank()
	var t: float = a.t
	var b := sin(t * TAU / 1.3)
	pose.whole.pivot = Vector2(rig.ground)
	pose.whole.sy = 1.0 + 0.05 * b
	pose.whole.sx = 1.0 - 0.04 * b
	var top := P(pose, "top")
	top.dx = 0.7 * sin(t * TAU / 1.3 + 0.9)
	if a.moving:
		var ph := t * TAU / 0.55
		var hop := absf(sin(ph))
		pose.whole.dy = -hop * 4.0
		pose.whole.sy += 0.12 * hop - 0.1 * (1.0 - hop)
		pose.whole.sx += -0.08 * hop + 0.1 * (1.0 - hop)
		top.dx += 1.2 * sin(ph + 1.2)
	var u: float = a.u
	match str(a.clip):
		"attack":
			var swell := ease_in_out(seg(u, 0.0, 0.45))
			var splat := ease_out(seg(u, 0.45, 0.6))
			var back := ease_in_out(seg(u, 0.65, 1.0))
			var keep := 1.0 - back
			pose.whole.sy += (0.2 * swell - 0.32 * splat) * keep
			pose.whole.sx += (-0.1 * swell + 0.3 * splat) * keep
			pose.whole.dy -= 3.0 * swell * (1.0 - splat) * keep
			top.dy = -1.5 * swell * keep
		"roar", "summon":
			var k := sin(PI * u)
			pose.whole.sx += 0.1 * k + 0.05 * sin(float(a.ct) * 40.0) * k
			pose.whole.sy += 0.08 * k
			top.dx += 1.5 * sin(float(a.ct) * 30.0) * k
		"hit":
			var k := 1.0 - ease_out(u)
			pose.whole.sx += 0.22 * k
			pose.whole.sy -= 0.2 * k
			top.dx -= 2.0 * k
		"death":
			var k := ease_in(seg(u, 0.0, 0.8))
			pose.whole.sy = 1.0 - 0.85 * k
			pose.whole.sx = 1.0 + 0.5 * k
			for p: Dictionary in rig.parts: P(pose, p.id).alpha = 1.0 - seg(u, 0.6, 1.0)
	return pose


## Spirit (the Frostgruft's whirl and crystal): a floating body that bobs and
## swirls (its sway parts turn on their own, rigs.json "sway"). "attack" leans
## back and lashes forward, "roar" (a ring, a call) swells it, "hit" knocks it
## back, "death" spins it down to nothing and fades it.
static func spirit(rig: Dictionary, a: Dictionary) -> Dictionary:
	var pose := blank()
	var t: float = a.t
	pose.whole.dy = -3.0 - 2.0 * sin(t * TAU / 2.0)
	pose.whole.sx = 1.0 + 0.05 * sin(t * TAU / 0.7)
	pose.whole.rot = 0.04 * sin(t * TAU / 1.6)
	if a.moving:
		pose.whole.rot += 0.12
	var u: float = a.u
	match str(a.clip):
		"attack":
			var pull := ease_in_out(seg(u, 0.0, 0.45))
			var lash := ease_out(seg(u, 0.45, 0.6))
			var back := ease_in_out(seg(u, 0.65, 1.0))
			var keep := 1.0 - back
			pose.whole.rot += (-0.14 * pull + 0.28 * lash) * keep
			pose.whole.dx = (-1.5 * pull + 3.5 * lash) * keep
			pose.whole.sy += (0.08 * pull - 0.06 * lash) * keep
		"roar", "summon":
			var k := ease_out(seg(u, 0.0, 0.4)) * (1.0 - ease_in_out(seg(u, 0.7, 1.0)))
			pose.whole.sx += 0.15 * k + 0.03 * sin(float(a.ct) * 60.0) * k
			pose.whole.sy += 0.12 * k
		"hit":
			var k := 1.0 - ease_out(u)
			pose.whole.dx = -2.5 * k
			pose.whole.sx += 0.15 * k
			pose.whole.sy -= 0.1 * k
		"death":
			var k := ease_in(seg(u, 0.1, 0.9))
			pose.whole.sx = 1.0 - 0.9 * k
			pose.whole.sy = 1.0 - 0.9 * k
			pose.whole.rot = 2.0 * TAU * k * k
			for p: Dictionary in rig.parts: P(pose, p.id).alpha = 1.0 - seg(u, 0.5, 1.0)
	return pose


static func hero(rig: Dictionary, a: Dictionary) -> Dictionary:
	var pose := blank()
	var t: float = a.t
	var b := sin(t * TAU / 1.3)
	var has := func(id: String) -> bool: return rig.by_id.has(id)
	pose.whole.sy = 1.0 + 0.025 * b
	pose.whole.sx = 1.0 - 0.018 * b
	if has.call("plume"): P(pose, "plume").rot = 0.06 * sin(t * TAU / 1.3 + 0.8)
	if has.call("hat"): P(pose, "hat").rot = 0.05 * sin(t * TAU / 1.3 + 0.6)
	if has.call("head"): P(pose, "head").dy = -0.4 * b
	if has.call("robe"): P(pose, "robe").sx = 1.0 + 0.03 * sin(t * TAU / 0.9)
	if a.moving:
		# One full stride (both feet) per cycle; set from the hero's speed.
		var ph := t * TAU / float(a.get("cycle", 0.42))
		pose.whole.dy = -absf(sin(ph)) * 1.6
		pose.whole.rot = 0.07
		pose.whole.sy = 1.0
		pose.whole.sx = 1.0
		if has.call("foot_l"): _walk_legs(pose, "foot_l", "foot_r", ph, 2.2, 1.4)
		if has.call("plume"): P(pose, "plume").rot = -0.28 - 0.1 * sin(ph * 2.0)
		if has.call("hat"): P(pose, "hat").rot = -0.2 - 0.08 * sin(ph * 2.0)
		if has.call("robe"): P(pose, "robe").rot = -0.08 + 0.06 * sin(ph)
	var u: float = a.u
	match str(a.clip):
		"hit":
			var k := 1.0 - ease_out(u)
			pose.whole.dx = -3.0 * k
			pose.whole.rot = -0.18 * k
			if has.call("plume"): P(pose, "plume").rot = 0.6 * sin(u * 22.0) * k
			if has.call("hat"): P(pose, "hat").rot = 0.5 * sin(u * 22.0) * k
		"death":
			var fall := ease_in(seg(u, 0.25, 0.62))
			pose.whole.rot = -0.12 * sin(u * 40.0) * (1.0 - seg(u, 0.0, 0.25)) - (PI / 2.0) * fall
			pose.whole.pivot = Vector2(3, float(rig.ground.y))
			pose.whole.dy = 2.0 * fall
			if has.call("plume"): P(pose, "plume").rot = 0.5 * fall
			if has.call("hat"): P(pose, "hat").dx = -3.0 * fall
	return pose


static func skeleton(rig: Dictionary, a: Dictionary) -> Dictionary:
	var pose := blank()
	var t: float = a.t
	var lost: Dictionary = a.lost
	var head := "skull" if rig.by_id.has("skull") else "head"
	var legs: bool = not lost.has("leg_l") or not lost.has("leg_r")
	var torso: bool = not lost.has("torso")
	var variant: String = str(rig.variant)
	P(pose, head).dy = -0.5 * sin(t * TAU / 1.1)
	if sin(t * 0.9) > 0.985: P(pose, head).rot = 0.09 * sin(t * 70.0)
	I(pose, "weapon").rot = 0.06 * sin(t * TAU / 1.1)
	if not torso:
		var hop := absf(sin(t * TAU / 0.9))
		var s := P(pose, head)
		s.dy = 5.0 - hop * (4.0 if a.moving else 1.2)
		s.sy = 1.0 - 0.18 * (1.0 - hop)
		s.sx = 1.0 + 0.12 * (1.0 - hop)
		s.rot = 0.15 * sin(t * TAU / 0.9) if a.moving else 0.0
		return pose
	if not legs:
		var ph := t * TAU / 0.9
		var tr := P(pose, "torso")
		tr.dy = 2.0
		tr.rot = (0.16 if a.moving else 0.05) * sin(ph)
		tr.dx = (1.0 if a.moving else 0.3) * sin(ph)
		P(pose, head).rot = 0.08 * sin(ph + 1.0)
		I(pose, "weapon").rot = 0.3 * sin(ph)
	elif a.moving:
		var ph := t * TAU / 0.5
		_walk_legs(pose, "leg_l", "leg_r", ph, 1.4, 1.1)
		if lost.has("leg_l") or lost.has("leg_r"):
			pose.whole.rot = 0.18 * sin(ph)
			pose.whole.dy = -absf(sin(ph)) * 2.0
		P(pose, "torso").rot = 0.06 * sin(ph)
		P(pose, head).dy = -absf(sin(ph))
		P(pose, head).rot = 0.05 * sin(ph + 1.0)
		I(pose, "weapon").rot = 0.25 * sin(ph)
	if variant == "guard" and not lost.has("shield"): I(pose, "shield").dy = -0.4 * sin(t * TAU / 1.1)
	var u: float = a.u
	match str(a.clip):
		"attack":
			if variant == "bow":
				_bow_draw(pose, u, 0.7)
				P(pose, head).rot = -0.08 * (ease_out(u / 0.7) if u < 0.7 else 1.0 - seg(u, 0.7, 1.0))
			elif variant == "guard":
				var s := ease_out(seg(u, 0.45, 0.6))
				var back := ease_in_out(seg(u, 0.65, 1.0))
				I(pose, "weapon").dx = 5.0 * s * (1.0 - back)
				I(pose, "weapon").rot = (-0.3 + 1.9 * s) * (1.0 - back)
				I(pose, "shield").dx = -1.0 * s * (1.0 - back)
				if s > 0.0 and s < 1.0: pose.trail = true
			elif u < 0.6:
				var k := ease_out(u / 0.6)
				I(pose, "weapon").rot = -1.9 * k + 0.05 * sin(float(a.ct) * 60.0) * k
				P(pose, head).rot = -0.12 * k
				P(pose, head).dx = -1.0 * k
			elif u < 0.75:
				var k := ease_out(seg(u, 0.6, 0.75))
				I(pose, "weapon").rot = -1.9 + 3.4 * k
				P(pose, head).rot = -0.12 + 0.25 * k
				P(pose, head).dx = -1.0 + 2.0 * k
				pose.trail = true
			else:
				var k := ease_in_out(seg(u, 0.75, 1.0))
				I(pose, "weapon").rot = 1.5 * (1.0 - k)
				P(pose, head).rot = 0.13 * (1.0 - k)
				P(pose, head).dx = 1.0 - k
		"block":
			var k := sin(PI * clampf(u * 1.2, 0.0, 1.0))
			I(pose, "shield").dx = 2.0 * k
			I(pose, "shield").dy = -1.0 * k
			P(pose, head).dx = -1.0 * k
			P(pose, "torso").rot = -0.06 * k
		"hit":
			var k := 1.0 - ease_out(u)
			P(pose, head).rot = 0.25 * sin(u * 30.0) * k
			P(pose, head).dx = -2.0 * k
			P(pose, "torso").dx = -1.0 * k
		"rise":
			var from: Dictionary = a.get("rise_from", {})
			for part: Dictionary in rig.parts + rig.items:
				if not from.has(part.id): continue
				var start: Dictionary = from[part.id]
				var is_item: bool = bool(part.is_item)
				var k := ease_in_out(seg(u, 0.35 if part.id == head else 0.5 if is_item else 0.05, 1.0 if part.id == head or is_item else 0.7))
				var p := I(pose, part.id) if is_item else P(pose, part.id)
				p.dx += (1.0 - k) * float(start.dx)
				p.dy += (1.0 - k) * float(start.dy) - sin(PI * k) * 6.0
				p.rot += (1.0 - k) * float(start.rot)
	return pose


static func necro(_rig: Dictionary, a: Dictionary) -> Dictionary:
	var pose := blank()
	var t: float = a.t
	var f := sin(t * TAU / 1.8)
	pose.whole.dy = -3.0 - 1.5 * f
	var robe := P(pose, "robe")
	robe.sx = 1.0 + 0.05 * sin(t * TAU / 0.9)
	robe.rot = 0.05 * sin(t * TAU / 0.9 + 0.5)
	I(pose, "weapon").dy = -0.8 * sin(t * TAU / 1.8 + 0.4)
	I(pose, "weapon").rot = 0.05 * sin(t * TAU / 2.2)
	if a.moving:
		pose.whole.rot = 0.08
		robe.rot -= 0.12
	var u: float = a.u
	match str(a.clip):
		"attack":
			var raise := ease_out(seg(u, 0.0, 0.5))
			var drop := ease_in_out(seg(u, 0.62, 1.0))
			I(pose, "weapon").rot = -0.5 * raise * (1.0 - drop)
			I(pose, "weapon").dy += -4.0 * raise * (1.0 - drop)
			pose.whole.rot = -0.06 * raise * (1.0 - drop)
			P(pose, "hood").dy = -raise * (1.0 - drop)
		"summon":
			var raise := ease_out(seg(u, 0.0, 0.3))
			var slam := ease_in(seg(u, 0.3, 0.38))
			var back := ease_in_out(seg(u, 0.6, 1.0))
			I(pose, "weapon").dy += (-5.0 * raise + 8.0 * slam) * (1.0 - back)
			pose.whole.dy += 2.0 * slam * (1.0 - back)
		"hit":
			var k := 1.0 - ease_out(u)
			pose.whole.dx = -2.5 * k
			pose.whole.rot = -0.15 * k
		"death":
			var k := ease_in_out(seg(u, 0.1, 0.8))
			pose.whole.dy = lerpf(float(pose.whole.dy), 0.0, k)
			pose.whole.pivot = Vector2(7, 22)
			pose.whole.sy = 1.0 - 0.75 * k
			P(pose, "hood").alpha = 1.0 - ease_in(seg(u, 0.4, 1.0))
			P(pose, "robe").alpha = 1.0 - ease_in(seg(u, 0.55, 1.0))
	return pose


static func biped(rig: Dictionary, a: Dictionary) -> Dictionary:
	var pose := blank()
	var t: float = a.t
	var b := sin(t * TAU / 1.2)
	var lost: Dictionary = a.lost
	var has := func(id: String) -> bool: return rig.by_id.has(id)
	var legs: bool = not lost.has("foot_l") or not lost.has("foot_r")
	pose.whole.sy = 1.0 + 0.03 * b
	pose.whole.sx = 1.0 - 0.02 * b
	if has.call("head"): P(pose, "head").rot = 0.04 * sin(t * TAU / 1.2 + 1.0)
	I(pose, "weapon").rot = 0.06 * b
	if not legs: pose.whole.dy = 2.0
	if a.moving:
		var ph := t * TAU / 0.46
		if legs:
			pose.whole.dy = -absf(sin(ph)) * 1.4
			if has.call("foot_l"): _walk_legs(pose, "foot_l", "foot_r", ph, 1.6, 1.2)
		pose.whole.rot = 0.06 + 0.04 * sin(ph)
		I(pose, "weapon").rot = 0.25 * sin(ph)
		if has.call("head"): P(pose, "head").dy = -absf(sin(ph)) * 0.8
	var u: float = a.u
	match str(a.clip):
		"attack":
			var coil := ease_in_out(seg(u, 0.0, 0.45))
			var snap := ease_out(seg(u, 0.45, 0.6))
			var back := ease_in_out(seg(u, 0.65, 1.0))
			pose.whole.dx = (-1.5 * coil + 5.0 * snap) * (1.0 - back)
			pose.whole.rot = (-0.12 * coil + 0.2 * snap) * (1.0 - back)
			if not rig.items.is_empty():
				I(pose, "weapon").rot = (-1.8 * coil + 3.2 * snap) * (1.0 - back)
				if snap > 0.0 and snap < 1.0: pose.trail = true
			if has.call("head"): P(pose, "head").rot += (-0.15 * coil + 0.25 * snap) * (1.0 - back)
		"hit":
			var k := 1.0 - ease_out(u)
			pose.whole.dx = -3.0 * k
			pose.whole.rot = -0.2 * k
		"death":
			var k := ease_in(seg(u, 0.0, 0.6))
			pose.whole.rot = -(PI / 2.0) * k
			pose.whole.pivot = Vector2(float(rig.ground.x) - 5.0, float(rig.ground.y))
			pose.whole.dy = 1.0 * k
			for part: Dictionary in rig.parts: P(pose, part.id).alpha = 1.0 - ease_in(seg(u, 0.6, 1.0))
	return pose


## Golem (the Glutwächter): a rock body on two stubby legs with its fists
## floating free beside it. Body, head and shoulders breathe on one 1.4 s
## period a little apart; each fist bobs on its own (1.9 s, 0.7 rad behind
## the other). Walking stomps and swings the fists. Clips: "slam" both fists
## rise high and smash down, "attack" the right fist pulls back and hurls,
## "roar" the fists spread wide and the body swells (its core bursts), "hit"
## knocks it back. A lost fist regrows growing from nothing.
static func golem(_rig: Dictionary, a: Dictionary) -> Dictionary:
	var pose := blank()
	var t: float = a.t
	var breath := TAU / 1.4
	P(pose, "torso").dy = -0.4 * sin(t * breath)
	P(pose, "head").dy = -0.6 * sin(t * breath - 0.4)
	P(pose, "shoulder_l").dy = -0.5 * sin(t * breath - 0.2)
	P(pose, "shoulder_r").dy = -0.5 * sin(t * breath - 0.6)
	var fl := P(pose, "fist_l")
	var fr := P(pose, "fist_r")
	fl.dy = -1.2 * sin(t * TAU / 1.9)
	fr.dy = -1.2 * sin(t * TAU / 1.9 + 0.7)
	if a.moving:
		var ph := t * TAU / 0.9
		_walk_legs(pose, "leg_l", "leg_r", ph, 1.2, 1.4)
		pose.whole.dy = -absf(sin(ph)) * 1.2
		pose.whole.rot = 0.04 * sin(ph)
		fl.dx = 1.5 * sin(ph)
		fr.dx = -1.5 * sin(ph)
	var regrowing: Dictionary = a.regrowing
	for id: String in ["fist_l", "fist_r"]:
		if regrowing.has(id):
			var k := ease_out(1.0 - float(regrowing[id]) / 1.2)
			P(pose, id).sx = lerpf(0.15, 1.0, k)
			P(pose, id).sy = lerpf(0.15, 1.0, k)
	var u: float = a.u
	match str(a.clip):
		"slam":
			var raise := ease_out(seg(u, 0.0, 0.55))
			var smash := ease_in(seg(u, 0.55, 0.68))
			var back := ease_in_out(seg(u, 0.75, 1.0))
			var keep := 1.0 - back
			fl.dy += (-12.0 * raise + 16.0 * smash) * keep
			fr.dy += (-12.0 * raise + 16.0 * smash) * keep
			fl.dx += (-2.0 * raise + 5.0 * smash) * keep
			fr.dx += (2.0 * raise - 5.0 * smash) * keep
			pose.whole.sy += (0.05 * raise - 0.12 * smash) * keep
			pose.whole.sx += 0.1 * smash * keep
			P(pose, "head").dy -= 1.5 * raise * keep
			if u > 0.55 and u < 0.72: pose.trail = true
		"attack":
			var pull := ease_out(seg(u, 0.0, 0.45))
			var fling := ease_out(seg(u, 0.45, 0.6))
			var back := ease_in_out(seg(u, 0.7, 1.0))
			var keep := 1.0 - back
			fr.dx += (-5.0 * pull + 11.0 * fling) * keep
			fr.dy += (-7.0 * pull + 3.0 * fling) * keep
			fr.rot = (-0.6 * pull + 1.2 * fling) * keep
			pose.whole.rot = (-0.06 * pull + 0.09 * fling) * keep
			if u > 0.45 and u < 0.62: pose.trail = true
		"roar":
			var k := ease_out(seg(u, 0.0, 0.4)) * (1.0 - ease_in_out(seg(u, 0.7, 1.0)))
			fl.dx -= 5.0 * k
			fr.dx += 5.0 * k
			fl.dy -= 4.0 * k
			fr.dy -= 4.0 * k
			pose.whole.sx += 0.07 * k + 0.02 * sin(float(a.ct) * 60.0) * k
			pose.whole.sy += 0.06 * k
			P(pose, "head").dy -= 1.0 * k
		"hit":
			var k := 1.0 - ease_out(u)
			pose.whole.dx = -1.5 * k
			pose.whole.sx += 0.08 * k
			pose.whole.sy -= 0.06 * k
			fl.dx -= 1.5 * k
			fr.dx -= 1.5 * k
	return pose


static func brute(_rig: Dictionary, a: Dictionary) -> Dictionary:
	var pose := blank()
	var t: float = a.t
	var b := sin(t * TAU / 1.6)
	var lost: Dictionary = a.lost
	var legs: bool = not lost.has("leg_l") or not lost.has("leg_r")
	pose.whole.sy = 1.0 + 0.03 * b
	pose.whole.sx = 1.0 - 0.02 * b
	P(pose, "head").rot = 0.04 * sin(t * TAU / 1.6 + 1.0)
	P(pose, "arm").rot = 0.08 * sin(t * TAU / 1.6 + 0.4)
	if not legs: P(pose, "torso").dy = 7.0
	if a.moving:
		var ph := t * TAU / 0.8
		if legs:
			pose.whole.dy = -absf(sin(ph)) * 2.0
			_walk_legs(pose, "leg_l", "leg_r", ph, 2.5, 1.6)
		pose.whole.rot = 0.06 * sin(ph)
		P(pose, "arm").rot = 0.3 * sin(ph)
		P(pose, "head").dy = -absf(sin(ph))
		if not legs: P(pose, "torso").rot = 0.1 * sin(ph)
	var regrowing: Dictionary = a.regrowing
	if regrowing.has("arm"):
		var k := 1.0 - float(regrowing.arm) / 1.2
		var arm := P(pose, "arm")
		arm.sx = lerpf(0.15, 1.0, ease_out(k))
		arm.sy = arm.sx
	var u: float = a.u
	match str(a.clip):
		"attack":
			var up := ease_in_out(seg(u, 0.0, 0.45))
			var down := ease_in(seg(u, 0.45, 0.56))
			var back := ease_in_out(seg(u, 0.7, 1.0))
			P(pose, "arm").rot = (-2.3 * up + 3.0 * down) * (1.0 - back)
			pose.whole.rot = (-0.1 * up + 0.2 * down) * (1.0 - back)
			pose.whole.dx = 3.0 * down * (1.0 - back)
			P(pose, "head").rot = (-0.15 * up + 0.2 * down) * (1.0 - back)
			if u > 0.45 and u < 0.62: pose.trail = true
		"roar":
			var k := sin(PI * u)
			P(pose, "head").rot = -0.3 * k + 0.05 * sin(float(a.ct) * 50.0) * k
			P(pose, "head").dy = -2.0 * k
			pose.whole.sx = 1.0 + 0.06 * k
		"hit":
			var k := 1.0 - ease_out(u)
			pose.whole.dx = -2.0 * k
			P(pose, "head").rot = -0.2 * k
		"death":
			var fall := ease_in(seg(u, 0.2, 0.7))
			pose.whole.pivot = Vector2(26, 35)
			pose.whole.rot = (PI / 2.2) * fall
			pose.whole.dy = 3.0 * fall
	return pose


## Leerenrufer: the 8 sheet frames play as a flickering body; claws, eye,
## aura and beam are layered on top. The front claw (claw_r) casts the soul
## salvo, the back claw (claw_l) summons.
static func void_lord(rig: Dictionary, a: Dictionary) -> Dictionary:
	var pose := blank()
	var t: float = a.t
	var frame := int(floor(t * float(rig.get("fps", 9.0)))) % 8
	var eye := 0
	pose.whole.dy = -5.0 - 2.0 * sin(t * TAU / 2.2)
	pose.whole.sx = 1.0 + 0.025 * sin(t * TAU / 1.1)
	pose.whole.sy = 1.0 - 0.02 * sin(t * TAU / 1.1)
	pose.aura = 0.5 + 0.2 * sin(t * TAU / 1.6)
	pose.glitch = fmod(t, 3.7) < 0.1
	var cl := P(pose, "claw_l")
	var cr := P(pose, "claw_r")
	cl.rot = 0.12 * sin(t * TAU / 1.9)
	cr.rot = -0.12 * sin(t * TAU / 1.9 + 0.7)
	if a.moving:
		pose.whole.rot = 0.07
		cl.rot += 0.3
		cr.rot += 0.3
	var regrowing: Dictionary = a.regrowing
	for id: String in ["claw_l", "claw_r"]:
		if regrowing.has(id):
			var k := 1.0 - float(regrowing[id]) / 1.2
			var c := P(pose, id)
			c.sx = lerpf(0.15, 1.0, ease_out(k))
			c.sy = c.sx
	if regrowing.has("eye"): P(pose, "eye").alpha = 1.0 - float(regrowing.eye) / 1.2
	var u: float = a.u
	match str(a.clip):
		"attack":
			var raise := ease_out(seg(u, 0.0, 0.45))
			var fling := ease_out(seg(u, 0.5, 0.6))
			var back := ease_in_out(seg(u, 0.68, 1.0))
			cr.rot += (-2.5 * raise + 1.3 * fling) * (1.0 - back)
			pose.whole.rot = (-0.08 * raise + 0.16 * fling) * (1.0 - back)
			pose.whole.dx = 2.5 * fling * (1.0 - back)
			pose.aura += 0.3 * raise * (1.0 - back)
			if u > 0.3 and u < 0.6: eye = 1
		"beam":
			var charge := ease_in_out(seg(u, 0.0, 0.3))
			var fire: bool = u >= 0.3 and u < 0.86
			var rest := ease_in_out(seg(u, 0.86, 1.0))
			eye = 0 if u < 0.12 else 1 if u < 0.22 else 2 if u < 0.88 else 1 if u < 0.94 else 0
			pose.whole.sx -= 0.07 * charge * (1.0 - rest)
			pose.whole.sy += 0.06 * charge * (1.0 - rest)
			cl.rot += 0.9 * charge * (1.0 - rest)
			cr.rot -= 0.9 * charge * (1.0 - rest)
			if fire:
				pose.whole.dx = (0.5 if sin(float(a.ct) * 90.0) > 0.0 else -0.5) - 1.5 * ease_out(seg(u, 0.3, 0.36))
				cl.rot += 0.08 * sin(float(a.ct) * 70.0)
				cr.rot += 0.08 * sin(float(a.ct) * 77.0)
				frame = int(floor(float(a.ct) * 18.0)) % 8
			pose.aura += 0.45 * charge * (1.0 - rest)
			pose.beam = {"warn": seg(u, 0.04, 0.3) if u < 0.3 else 0.0, "k": ease_out(seg(u, 0.3, 0.35)) * (1.0 - ease_in(seg(u, 0.8, 0.86))) if fire else 0.0}
		"summon":
			var raise := ease_out(seg(u, 0.0, 0.32))
			var slam := ease_in(seg(u, 0.32, 0.4))
			var back := ease_in_out(seg(u, 0.62, 1.0))
			cl.rot += (2.6 * raise - 2.3 * slam) * (1.0 - back)
			cr.rot += -0.6 * raise * (1.0 - back)
			pose.whole.dy += (-3.0 * raise + 5.0 * slam) * (1.0 - back)
			pose.whole.sy += (0.05 * raise - 0.12 * slam) * (1.0 - back)
			pose.whole.sx += 0.1 * slam * (1.0 - back)
			pose.aura += 0.5 * raise * (1.0 - back)
			eye = 1 if u > 0.2 and u < 0.7 else 0
		"hit":
			var k := 1.0 - ease_out(u)
			pose.whole.dx = -2.0 * k
			pose.whole.sx += 0.12 * k
			pose.whole.sy -= 0.1 * k
			frame = (frame + 3) % 8
			if k > 0.5: pose.glitch = true
		"death":
			var implode := ease_in(seg(u, 0.55, 0.85))
			pose.whole.pivot = Vector2(22, 22)
			pose.whole.dx = (0.7 if sin(float(a.ct) * 80.0) > 0.0 else -0.7) * (1.0 - implode)
			pose.whole.sx = lerpf(float(pose.whole.sx) + 0.08 * sin(u * 30.0), 0.05, implode)
			pose.whole.sy = lerpf(float(pose.whole.sy), 0.05, implode)
			pose.whole.rot = 2.0 * TAU * implode * implode
			eye = 2 if u < 0.85 else 0
			pose.aura = 1.1 * (1.0 - implode)
			frame = int(floor(float(a.ct) * 24.0)) % 8
			for id: String in ["core", "eye", "claw_l", "claw_r"]: P(pose, id).alpha = 1.0 - seg(u, 0.82, 0.88)
	pose.frames = {"core": frame, "eye": eye}
	return pose


## Leerenbomber: the sheet's skull frames bob at 10 fps; on the fuse it swells
## and flashes faster and faster.
static func bomber(rig: Dictionary, a: Dictionary) -> Dictionary:
	var pose := blank()
	var t: float = a.t
	pose.whole.dy = -3.0 - 1.5 * sin(t * TAU / 0.8)
	pose.whole.rot = 0.12 * sin(t * TAU / 1.3) + (0.15 if a.moving else 0.0)
	pose.frames = {"skull": int(floor(t * float(rig.get("fps", 10.0)))) % 8}
	pose.aura = 0.45 + 0.2 * sin(t * TAU / 0.7)
	var u: float = a.u
	match str(a.clip):
		"attack":
			var k := ease_in(u)
			pose.whole.sx = 1.0 + 0.35 * k + 0.05 * sin(float(a.ct) * 60.0) * k
			pose.whole.sy = pose.whole.sx
			pose.whole.pivot = Vector2(8, 8)
			pose.aura += 0.6 * k
			pose.fuse = k
		"hit":
			var k := 1.0 - ease_out(u)
			pose.whole.dx = -2.0 * k
			pose.whole.sx = 1.0 + 0.2 * k
			pose.whole.sy = 1.0 - 0.15 * k
	return pose


## Mimik: a chest that hops after the heroes and chomps (frame 0 shut, 1 teeth,
## 2 wide open). Each hop squashes on landing; the bite opens the lid wide,
## lunges and snaps shut on the strike.
static func mimic(_rig: Dictionary, a: Dictionary) -> Dictionary:
	var pose := blank()
	var t: float = a.t
	pose.whole.pivot = Vector2(8, 15)
	pose.frames = {"body": 0}
	if a.moving:
		var hop := fmod(t, 0.42) / 0.42
		var air := sin(hop * PI)
		pose.whole.dy = -7.0 * air
		pose.whole.sy = 1.0 + 0.12 * air - (0.18 * (1.0 - air) if hop > 0.85 or hop < 0.12 else 0.0)
		pose.whole.sx = 2.0 - pose.whole.sy
		pose.whole.rot = 0.08 * sin(hop * TAU)
		pose.frames = {"body": 1 if air > 0.35 else 0}
	else:
		# Waiting: a slow, hungry breath with the teeth showing now and then.
		pose.whole.sy = 1.0 + 0.04 * sin(t * TAU / 1.1)
		pose.whole.sx = 2.0 - pose.whole.sy
		pose.frames = {"body": 1 if fmod(t, 2.4) < 0.5 else 0}
	var u: float = a.u
	match str(a.clip):
		"attack":
			var coil := ease_in_out(seg(u, 0.0, 0.45))
			var snap := ease_out(seg(u, 0.45, 0.6))
			var back := ease_in_out(seg(u, 0.65, 1.0))
			pose.whole.dx = (-2.0 * coil + 7.0 * snap) * (1.0 - back)
			pose.whole.dy = -4.0 * coil * (1.0 - snap)
			pose.whole.sy = 1.0 + 0.2 * coil - 0.25 * snap * (1.0 - back)
			pose.whole.sx = 2.0 - pose.whole.sy
			pose.frames = {"body": 2 if coil > 0.2 and snap < 0.6 else 0 if snap >= 0.6 and back < 0.5 else 1}
		"hit":
			var k := 1.0 - ease_out(u)
			pose.whole.dx = -3.0 * k
			pose.whole.sy = 1.0 - 0.2 * k
			pose.whole.sx = 1.0 + 0.15 * k
			pose.frames = {"body": 2}
		"death":
			var k := ease_in(seg(u, 0.0, 0.5))
			pose.whole.rot = -(PI / 2.0) * k
			pose.whole.dy = 2.0 * k
			pose.frames = {"body": 2}
			P(pose, "body").alpha = 1.0 - ease_in(seg(u, 0.55, 1.0))
	return pose


# ------------------------------------------------------------------ drake

## Ignaroth's periods in seconds. Idle follows the Leerenrufer's recipe (2.2 s
## bob, 1.1 s breath, 1.9 s limbs, 1.6 s wings) plus own periods for neck, jaw,
## tail and crystals; apart from bob/breath no two of them divide evenly, so
## the parts never fall into lockstep (ANIM-01, ANIM-06).
const DRAKE_BOB := 2.2
## Idle body bob in source px (ANIM-06: 1-3 px).
const DRAKE_BOB_PX := 1.2
## Breathing squash of the whole figure and the throat's pulse.
const DRAKE_BREATH := 1.1
## Phase (rad) of the fire gland's pulse against the breath: it swells about
## 0.19 s before each breath, clear of the body, neck, jaw and wing peaks
## (ANIM-01; 1.0-1.17 rad all pass in every form and gait).
const DRAKE_GLAND_PHASE := 1.09
## Neck sway; the head follows on the same period, DRAKE_NECK_LAG later.
const DRAKE_NECK := 1.7
## Neck sway (rad) standing or flying; the head swings 0.005 rad wider.
const DRAKE_SWAY := 0.06
## Neck sway (rad) while walking. The neck/head whip keeps running in the gait
## (no step-locked nod), so the head still trails the neck (ANIM-02).
const DRAKE_WALK_SWAY := 0.04
## Idle jaw: the mouth parts a little now and then.
const DRAKE_JAW := 2.9
## Front arm sway.
const DRAKE_ARM := 1.9
## Idle sway of the front arm (rad). Ignaroth stands on its hind legs, so the
## arm hangs from the shoulder: it rides the body's bob and swings on its own
## period instead of countering the bob (which tied it to the body, ANIM-01).
const DRAKE_ARM_SWAY := 0.12
## Idle wing breathing (forms 3 and 4).
const DRAKE_WING := 1.6
## Idle tail whip; walking uses DRAKE_WALK_TAIL, flying DRAKE_FLAP_TAIL.
const DRAKE_TAIL := 2.45
## Walking tail whip (s): no simple ratio to any gait cycle, the jaw, neck, wings or crystals.
const DRAKE_WALK_TAIL := 1.2
## Phase of the walking tail whip (rad), keeps its peaks clear of the others.
const DRAKE_WALK_TAIL_PHASE := 0.4
## Void crystals bobbing on the back (form 4).
const DRAKE_CRYSTAL := 1.3
## One wing beat in flight.
const DRAKE_FLAP := 0.42
## Tail whip period in flight (the tail streams behind): no simple ratio to the
## crystals (1.3 s), wings (1.6 s), neck (1.7 s) or jaw (2.9 s).
const DRAKE_FLAP_TAIL := 1.37
## On the ground the near wing breathes this far (rad) ahead of the far wing: a
## mirrored pair. In flight both wings beat almost together, as a flying
## creature's wings do; that pair is the one lockstep the drake allows.
const DRAKE_MIRROR := 0.7
## Head behind the neck (rad).
const DRAKE_NECK_LAG := 0.9
## Each tail segment behind its parent (rad).
const DRAKE_TAIL_LAG := 0.6
## Walking: the body's bob follows the legs this late (s).
const DRAKE_BODY_LAG := 0.1
## Walking: each hind leg swings this far (rad) about the hip.
const DRAKE_STRIDE := 0.38
## Walking: a swinging foot lifts this high (source px).
const DRAKE_STEP_PX := 1.0
## Walking: the body rises this much (source px) at mid-stance.
const DRAKE_WALK_BOB_PX := 0.6
## Walking: the figure leans forward this far (rad); the planted foot is
## corrected for it.
const DRAKE_LEAN := 0.03
## Share of the idle layers (bob, sway, tail, wings, crystals, arm, jaw) that
## calms down while an attack winds up and strikes, so the part carrying the
## attack is the one that reads (ANIM-04). The gait and wing beats keep going.
const DRAKE_CALM := 0.8
## Walk cycle (both hind feet) per form when the actor has no `cycle`; tuned
## with the rest of the walk so no three parts peak in one 1/30 s (ANIM-01).
## That bin rule is a matter of chance with 12-18 moving parts on unrelated
## periods: in a 0.62-1.10 s sweep forms 1/2 pass at 0.70-0.74 / 0.62-0.74,
## form 3 at 0.94-1.00 and form 4 only at 1.00, so retune with
## tests/drake_pose_test.gd after any change to the walk.
const DRAKE_CYCLES := {"1": 0.7, "2": 0.74, "3": 0.94, "4": 1.0}
## Share of a backward (rearing) neck turn the neck keeps in a rig whose wing
## fans out above the head (a wing with flap -1, form 4's far wing); the head
## takes the rest as its own turn about its pivot, so the head rears just as
## far but swings past the wing instead of being carried up into it by the
## neck's long lever (measured on drache4: a neck turn of -0.3 rad pushes 190
## more head px into the wing, a head turn of -0.3 rad none).
const DRAKE_NECK_UNDER_WING := 0.3
## Share of the (kept) backward neck turn such a wing follows: it lifts with
## the neck, so the head under it stays clear.
const DRAKE_WING_REAR := 1.0
## Share of the head's own backward turn such a wing follows: little, because
## the head turning about its own pivot barely reaches the wing, and the wing's
## long lever would otherwise outrun the head and jaw in a bite's or breath's
## windup (ANIM-04).
const DRAKE_WING_HEAD_REAR := 0.25
## A wing whose swing toward the head is below this (rad) rests against the
## head: its breath and beat only lift it off (form 4's far wing, 0.03).
const DRAKE_WING_TOUCH := 0.1
## Extra phase (rad, a quarter breath) of the ground breath of a wing with flap
## -1: its turn is mirrored, which moves its peaks by half a breath onto other
## parts' peaks (form 4 walking: far wing, tail_2 and far leg in one 1/30 s,
## ANIM-01). A tuned value like DRAKE_CYCLES (see there and the retune note in
## tests/drake_pose_test.gd).
const DRAKE_FLIP_PHASE := 1.57
## Extra phase (rad) of a flap -1 wing's beat in flight, which only lifts off
## the head (see _drake_beat): its lowest point is its turn's peak and fell
## with tail_4 and crystal_2 into one 1/30 s (ANIM-01). 0.1-0.3 pass; the two
## wings stay 0.15 rad apart, so they still beat together. Tuned like
## DRAKE_FLIP_PHASE.
const DRAKE_FLIP_BEAT := 0.2
## Take-off (clip "flight"): share of the clip, from the end of the windup,
## the push-off downstroke takes (raised wings -> bottom of a beat); the beat
## then blends in over 1.5x as long.
const DRAKE_PUSH := 0.08
## Beam windup: how far (source px) the void crystals rise out of the back.
const DRAKE_CRYSTAL_RISE := 2.0
## The tail chain, root to tip.
const DRAKE_TAIL_IDS: Array[String] = ["tail_1", "tail_2", "tail_3", "tail_4", "tail_5"]
## Attack kind (hell_monsters.json attacks[].kind) -> drake clip.
const DRAKE_KINDS := {"bolt": "bite", "slam": "slam", "dash": "dash", "burrow": "burrow", "swing": "swing", "sweep": "sweep",
	"ring": "roar", "echoes": "roar", "beam": "beam", "flight": "flight"}
## [end of windup, end of strike] in clip progress per drake clip; RigRenderer
## maps the host's attack phases onto them and passes them on as a.windows.
const DRAKE_WINDOWS := {"bite": [0.55, 0.7], "slam": [0.4, 0.6], "dash": [0.35, 0.6], "burrow": [0.5, 0.7], "swing": [0.3, 0.8],
	"sweep": [0.3, 0.9], "roar": [0.45, 0.65], "beam": [0.3, 0.9], "flight": [0.15, 0.9]}


## Ignaroth, the dragon (family "drake", rig.variant = form 1-4): the
## Leerenrufer's swaying feel in ember. Every part runs on its own period;
## neck->head and the tail are whip chains (segment i turns A_i*sin(w*t - i*lag),
## so each child follows its parent late and the tip swings widest). Walking
## alternates the hind legs about the hip with the stance foot planted, flying
## beats the wings (forms 3/4). Attack clips coil (the part that carries the
## attack leads, against the strike, while the idle calms down), snap and
## spring back over a.windows (default DRAKE_WINDOWS). Flipbooks run at
## rig.fps (hell_rigs.json, default 10). Returns the usual pose plus `glow`
## {part: 0..1}, flipbook `frames` and, in the tail whirl, whole.turn (1 ->
## -1 -> 1: the figure spins about its vertical axis, RigRenderer mirrors it).
static func drake(rig: Dictionary, a: Dictionary) -> Dictionary:
	var pose := blank()
	var by_id: Dictionary = rig.get("by_id", {})
	var lost: Dictionary = a.get("lost", {})
	var has := func(id: String) -> bool: return by_id.has(id) and not lost.has(id)
	var add := func(id: String, key: String, value: float) -> void:
		if by_id.has(id) and not lost.has(id):
			var p := P(pose, id)
			p[key] = float(p[key]) + value
	var form := clampi(str(rig.get("variant", "1")).to_int(), 1, 4)
	var t := float(a.get("t", 0.0))
	var ct := float(a.get("ct", 0.0))
	var u := clampf(float(a.get("u", 0.0)), 0.0, 1.0)
	var clip := str(a.get("clip", ""))
	var mode := "fly" if bool(a.get("flying", false)) else "walk" if bool(a.get("moving", false)) else "idle"
	var whole: Dictionary = pose.whole
	var glow: Dictionary = {}
	var fps := maxf(1.0, float(rig.get("fps", 10.0)))
	var frames: Dictionary = {"tail_flame": int(floor(t * fps)), "mouth_flame": int(floor(t * fps * 1.2)) + 2}
	var cycle := float(a.get("cycle", 0.0))
	if cycle <= 0.0: cycle = float(DRAKE_CYCLES.get(str(form), 0.85))
	var gait := TAU / cycle
	var ph := t * gait
	var flap_w := TAU / DRAKE_FLAP
	var calm := 1.0 - DRAKE_CALM * _drake_focus(a, clip, u)
	var wings: Array[String] = []
	if form >= 3: wings.assign(["wing_far", "wing_near"])
	# Breathing: the whole figure swells about the feet (ANIM-05: sx*sy ~ 1).
	var breath := sin(t * TAU / DRAKE_BREATH)
	whole.sy = 1.0 + 0.022 * breath
	whole.sx = 1.0 - 0.018 * breath
	match mode:
		"idle":
			# The torso bobs; the legs stay planted, the hanging arm rides along.
			var bob := -DRAKE_BOB_PX * calm * sin(t * TAU / DRAKE_BOB)
			add.call("body", "dy", bob)
			add.call("leg_far", "dy", -bob)
			add.call("leg_near", "dy", -bob)
			add.call("arm", "rot", DRAKE_ARM_SWAY * calm * sin(t * TAU / DRAKE_ARM + 0.4))
		"walk":
			# Hind legs half a cycle apart, rotating about the hip; the body is
			# highest at mid-stance and follows the legs DRAKE_BODY_LAG late. The
			# stance foot stays on the floor through the body's lift, the leg's
			# arc about the hip and the lean; the swinging foot lifts on top.
			var lag := DRAKE_BODY_LAG * gait
			var lift := -DRAKE_WALK_BOB_PX * pow(cos(ph - lag), 2.0)
			add.call("body", "dy", lift)
			whole.rot = DRAKE_LEAN
			var ground: Vector2 = rig.get("ground", Vector2.ZERO)
			var strides := {"leg_far": [-DRAKE_STRIDE * sin(ph), DRAKE_STEP_PX * maxf(0.0, cos(ph))], "leg_near": [DRAKE_STRIDE * sin(ph), DRAKE_STEP_PX * maxf(0.0, -cos(ph))]}
			for id: String in strides:
				if not has.call(id): continue
				var rot := float(strides[id][0])
				var up := float(strides[id][1])
				var pivot: Vector2 = by_id[id].pivot
				# The foot's heel and toe (RigLibrary "sole"; else the point under
				# the hip on the ground line): the lower of the two, turned about
				# the hip and tipped by the lean, stays where it rests.
				var sole: Array = by_id[id].get("sole", [Vector2(pivot.x, ground.y)])
				var rest_low := -INF
				var low := -INF
				for p: Vector2 in sole:
					var d := p - pivot
					var turned := pivot + Vector2(d.x * cos(rot) - d.y * sin(rot), d.x * sin(rot) + d.y * cos(rot))
					rest_low = maxf(rest_low, p.y)
					low = maxf(low, turned.y + tan(DRAKE_LEAN) * (turned.x - ground.x) * float(whole.sx) / float(whole.sy))
				add.call(id, "rot", rot)
				# The planted share of the foot (1 in stance, 0 at mid-swing) holds
				# against the body's lift; a swinging foot rides part of it.
				var planted := 1.0 - up / DRAKE_STEP_PX
				add.call(id, "dy", -lift * planted - (low - rest_low) - up)
			var arm_ph := ph - (PI + lag * 0.5)
			add.call("arm", "rot", 0.26 * cos(arm_ph))
			add.call("arm", "dy", -1.0 * maxf(0.0, sin(arm_ph)))
		"fly":
			# Lifted, legs and claw tucked, neck stretched forward.
			whole.dy = -(8.0 + 2.0 * form) - 1.5 * sin(t * flap_w - 0.8)
			whole.rot = -0.05
			add.call("leg_far", "rot", -0.5)
			add.call("leg_far", "dy", -1.0)
			add.call("leg_near", "rot", -0.6)
			add.call("leg_near", "dy", -1.2)
			add.call("arm", "rot", -0.55)
			add.call("neck", "rot", 0.1)
			add.call("tail_1", "rot", 0.15)
	# Neck -> head chain, the jaw on its own slow period.
	var sway := (DRAKE_WALK_SWAY if mode == "walk" else DRAKE_SWAY) * calm
	var neck_w := TAU / DRAKE_NECK
	add.call("neck", "rot", sway * sin(t * neck_w))
	add.call("head", "rot", (sway + 0.005 * calm) * sin(t * neck_w - DRAKE_NECK_LAG))
	add.call("jaw", "rot", 0.03 * calm * (1.0 + sin(t * TAU / DRAKE_JAW + 1.3)))
	# Fire gland: pulses after each breath.
	var gland := sin(t * TAU / DRAKE_BREATH + DRAKE_GLAND_PHASE)
	add.call("throat", "sx", 0.02 * gland)
	if has.call("throat"): glow.throat = 0.2 + 0.12 * gland
	# Tail whip.
	match mode:
		"walk": _drake_chain(pose, has, DRAKE_TAIL_IDS, t, DRAKE_WALK_TAIL, 0.06 * calm, 0.012 * calm, DRAKE_TAIL_LAG, DRAKE_WALK_TAIL_PHASE)
		"fly": _drake_chain(pose, has, DRAKE_TAIL_IDS, t, DRAKE_FLAP_TAIL, 0.04 * calm, 0.012 * calm, DRAKE_TAIL_LAG)
		_: _drake_chain(pose, has, DRAKE_TAIL_IDS, t, DRAKE_TAIL, 0.05 * calm, 0.01 * calm, DRAKE_TAIL_LAG)
	# Wings: a slow mirrored breath on the ground, wing beats in the air.
	var wings_left := 0
	for id: String in wings:
		if has.call(id): wings_left += 1
	for i in range(wings.size()):
		if not has.call(wings[i]): continue
		var wing := P(pose, wings[i])
		var part: Dictionary = by_id[wings[i]]
		var flipped := float(part.get("flap", 1.0)) < 0.0
		if mode == "fly":
			var beat := t * flap_w * (1.25 if wings_left == 1 else 1.0) + 0.35 * i + (DRAKE_FLIP_BEAT if flipped else 0.0)
			wing.rot += _drake_beat(part, 0.55, sin(beat))
			wing.sy += 0.06 * cos(beat)
		else:
			var shift := DRAKE_FLIP_PHASE if flipped else 0.0
			wing.rot += _drake_beat(part, 0.07 * calm, sin(t * TAU / DRAKE_WING + DRAKE_MIRROR * i + shift))
	if mode == "fly" and wings.size() == 2 and wings_left == 1: whole.rot += 0.08 * sin(t * TAU / 0.9)
	# Void crystals (form 4) bob out of step and glow.
	var crystals: Array[String] = []
	if form >= 4: crystals.assign(["crystal_1", "crystal_2", "crystal_3"])
	for i in range(crystals.size()):
		var phase := t * TAU / DRAKE_CRYSTAL + 1.1 * i
		add.call(crystals[i], "dy", -0.6 * calm * sin(phase))
		if has.call(crystals[i]): glow[crystals[i]] = 0.35 + 0.2 * sin(phase)
	_drake_clip(rig, pose, a, clip, u, t, ct, form, mode, crystals, wings, has, add, glow, frames, fps)
	if _drake_wing_over_head(by_id, wings): _drake_neck_to_head(pose, has)
	_drake_wings(pose, by_id, wings, has)
	# A severed tail's stump twitches.
	if by_id.has("tail_2") and lost.has("tail_2"): add.call("tail_1", "rot", 0.09 * sin(t * TAU / 0.37))
	# Regrowing parts scale back in from a glowing bud.
	var regrowing: Dictionary = a.get("regrowing", {})
	for id: String in regrowing:
		if not has.call(id): continue
		var k := clampf(1.0 - float(regrowing[id]) / 1.2, 0.0, 1.0)
		var p := P(pose, id)
		p.sx = lerpf(0.15, 1.0, ease_out(k))
		p.sy = p.sx
		glow[id] = maxf(float(glow.get(id, 0.0)), 1.0 - k)
	pose.glow = glow
	pose.frames = frames
	return pose


## True when the rig has a wing fanned out above the head (flap -1 in
## hell_rigs.json: its membrane lies right of its pivot, beside the head).
static func _drake_wing_over_head(by_id: Dictionary, wings: Array[String]) -> bool:
	for id: String in wings:
		if by_id.has(id) and float(by_id[id].get("flap", 1.0)) < 0.0: return true
	return false


## Under a wing above the head, a backward neck turn is mostly handed to the
## head (DRAKE_NECK_UNDER_WING): the head's world turn stays the same, the head
## just is not lifted into the wing on the neck's lever.
static func _drake_neck_to_head(pose: Dictionary, has: Callable) -> void:
	if not has.call("neck") or not pose.parts.has("neck"): return
	var neck: Dictionary = pose.parts.neck
	var back := minf(0.0, float(neck.rot))
	if back >= 0.0: return
	neck.rot = float(neck.rot) - back * (1.0 - DRAKE_NECK_UNDER_WING)
	if has.call("head"):
		var head := P(pose, "head")
		head.rot = float(head.rot) + back * (1.0 - DRAKE_NECK_UNDER_WING)


## The lift (rad, positive raises the wing in the flap 1 sense) of a wing
## beating `amp` each way at phase value s (-1..1). A wing that may lower less
## than amp before covering the head (its swing on the lowering side: -lo for
## flap 1, hi for flap -1) beats over the range it has instead, from that limit
## up to amp, so it moves through the whole beat rather than parking at the
## limit for half of it.
static func _drake_beat(part: Dictionary, amp: float, s: float) -> float:
	var swing: Variant = part.get("swing")
	if not swing is Vector2: return amp * s
	var room: float = -swing.x if float(part.get("flap", 1.0)) > 0.0 else swing.y
	# a wing resting against the head (hardly any room) only lifts off it
	room = 0.0 if room < DRAKE_WING_TOUCH else room
	if room >= amp: return amp * s
	return 0.5 * (amp + room) * s + 0.5 * (amp - room)


## Wings on their real geometry (hell_rigs.json "flap", "swing", read by
## RigLibrary): every turn above is written for a wing spreading left of its
## pivot (a clockwise turn lifts it), so a wing with flap -1 (form 4's far
## wing, spread out above the head) takes the opposite turn and both wings
## beat up together. Such a wing also lifts with the head's rearing
## (DRAKE_WING_REAR of the neck's backward turn, DRAKE_WING_HEAD_REAR of the
## head's), and no wing turns past its swing [lo, hi]: the turns at which it
## would cover more of the head, horns and jaw than at rest. Rigs without these
## fields (crypt-style or synthetic) keep their turns.
static func _drake_wings(pose: Dictionary, by_id: Dictionary, wings: Array[String], has: Callable) -> void:
	var neck: Dictionary = pose.parts.get("neck", {})
	var head: Dictionary = pose.parts.get("head", {})
	var neck_back := minf(0.0, float(neck.get("rot", 0.0)))
	var head_back := minf(0.0, float(head.get("rot", 0.0)))
	for id: String in wings:
		if not has.call(id): continue
		var part: Dictionary = by_id[id]
		var flap := float(part.get("flap", 1.0))
		var rear := DRAKE_WING_REAR * neck_back + (DRAKE_WING_HEAD_REAR if flap < 0.0 else 1.0) * head_back
		var wing := P(pose, id)
		var rot := float(wing.rot) * flap
		var swing: Variant = part.get("swing")
		if swing is Vector2:
			rot = _drake_limit(rot, swing.x, swing.y)
			# The head lies on the side of the smaller limit (rest-pose data);
			# a head on the clockwise side comes toward the wing as it rears
			# (turns counter-clockwise), so that limit recedes with it.
			if swing.y < -swing.x: rot = minf(rot, maxf(swing.x, swing.y + rear))
		wing.rot = rot


## A turn kept inside [lo, hi] (lo <= 0 <= hi): unchanged up to 60 % of the
## limit on its side, then it eases into the limit without passing it.
static func _drake_limit(x: float, lo: float, hi: float) -> float:
	if x > 0.0: return _drake_ease(x, hi)
	if x < 0.0: return -_drake_ease(-x, -lo)
	return x


static func _drake_ease(x: float, limit: float) -> float:
	if limit <= 0.0: return 0.0
	var knee := 0.6 * limit
	if x <= knee: return x
	return knee + (limit - knee) * tanh((x - knee) / (limit - knee))


## Whip chain: segment i turns (amp0 + grow*i)*sin(w*t - i*lag); children add
## their parent's turn, so each one peaks later and the tip swings widest.
static func _drake_chain(pose: Dictionary, has: Callable, ids: Array[String], t: float, period: float, amp0: float, grow: float, lag: float, phase := 0.0) -> void:
	var w := TAU / period
	for i in range(ids.size()):
		if not has.call(ids[i]): return
		var p := P(pose, ids[i])
		p.rot = float(p.rot) + (amp0 + grow * i) * sin(t * w - i * lag + phase)


## [end of windup, end of strike] of a drake clip: a.windows when the renderer
## mapped an attack, else DRAKE_WINDOWS, kept in order inside 0..1.
static func _drake_windows(a: Dictionary, clip: String) -> Vector2:
	var windows: Array = a.get("windows", DRAKE_WINDOWS.get(clip, [0.5, 0.65]))
	var w_end := clampf(float(windows[0]), 0.01, 0.98)
	return Vector2(w_end, clampf(float(windows[1]), w_end + 0.01, 0.99))


## How far an attack has wound up (0..1): rises over the windup, holds through
## the strike and eases off in the recovery; 0 outside the attack clips.
static func _drake_focus(a: Dictionary, clip: String, u: float) -> float:
	if not DRAKE_WINDOWS.has(clip): return 0.0
	var windows := _drake_windows(a, clip)
	return ease_in_out(seg(u, 0.0, windows.x)) * (1.0 - ease_in_out(seg(u, windows.y, 1.0)))


## The attack, hit and death clips of the drake on top of its idle/walk/flight.
static func _drake_clip(rig: Dictionary, pose: Dictionary, a: Dictionary, clip: String, u: float, t: float, ct: float, form: int, mode: String,
		crystals: Array[String], wings: Array[String], has: Callable, add: Callable, glow: Dictionary, frames: Dictionary, fps: float) -> void:
	if clip.is_empty(): return
	var whole: Dictionary = pose.whole
	var windows := _drake_windows(a, clip)
	var w_end := windows.x
	var s_end := windows.y
	var coil := ease_in_out(seg(u, 0.0, w_end))
	var snap := ease_out(seg(u, w_end, s_end))
	var back := ease_in_out(seg(u, s_end, 1.0))
	var keep := 1.0 - back
	var striking: bool = u >= w_end and u < s_end
	match clip:
		"bite":
			# Spit/bite: the head pulls back and up, the mouth opens, then the
			# head lunges and the jaw gapes on the release.
			add.call("neck", "rot", (-0.2 * coil + 0.45 * snap) * keep)
			add.call("head", "rot", (-0.34 * coil + 0.6 * snap) * keep)
			add.call("head", "dx", (-1.0 * coil + 2.2 * snap) * keep)
			add.call("jaw", "rot", (0.18 * coil + 0.32 * snap) * keep)
			add.call("body", "rot", (-0.03 * coil + 0.05 * snap) * keep)
			# The tail holds still against the body's turn (it would swing the tip widest).
			add.call("tail_1", "rot", (0.03 * coil - 0.03 * snap) * keep)
			whole.dx = (-1.0 * coil + 2.5 * snap) * keep
			if striking: frames.mouth_flame = int(floor(ct * fps * 2.0))
		"slam":
			# Crouch, leap with a stretch, land with a squash (feet on the floor).
			var air_end := s_end - 0.03
			var k := seg(u, w_end, air_end)
			var sy := 1.0
			if u < w_end:
				sy = 1.0 - 0.07 * coil
			elif u < air_end:
				sy = 1.0 + 0.075 * sin(PI * minf(1.0, k * 2.0)) - 0.07 * (1.0 - ease_out(minf(1.0, k * 4.0)))
				whole.dy = -(10.0 + 2.0 * form) * sin(PI * k)
			else:
				var land := seg(u, air_end, minf(1.0, air_end + 0.2))
				sy = 1.0 - 0.1 * (sin(PI * land) if land < 1.0 else 0.0)
			whole.sy = sy
			whole.sx = 1.0 / sy
			var air := sin(PI * k) if u >= w_end and u < air_end else 0.0
			add.call("leg_far", "rot", -0.25 * air)
			add.call("leg_near", "rot", -0.3 * air)
			add.call("arm", "rot", -0.35 * air)
			add.call("neck", "rot", -0.12 * coil * (1.0 - snap) + 0.15 * air)
			add.call("tail_1", "rot", 0.2 * coil * (1.0 - snap) - 0.2 * air)
		"dash":
			# Lean in low and scrabble; the tail streams straight back.
			whole.rot = (-0.05 * coil + 0.13 * snap) * keep
			whole.dx = (-1.5 * coil + 1.5 * snap) * keep
			var sy := 1.0 - 0.04 * coil * (1.0 - snap) - 0.05 * snap * keep
			whole.sy = sy
			whole.sx = 1.0 / sy
			var run := snap * keep
			var legs := TAU / 0.22 * ct
			add.call("leg_far", "rot", -0.35 * sin(legs) * run)
			add.call("leg_near", "rot", 0.35 * sin(legs) * run)
			add.call("arm", "rot", -0.2 * coil - 0.3 * run)
			add.call("neck", "rot", (-0.08 * coil + 0.15 * snap) * keep)
			for i in range(DRAKE_TAIL_IDS.size()):
				add.call(DRAKE_TAIL_IDS[i], "rot", (-0.05 * coil + 0.1 * ease_out(seg(u, w_end + 0.03 * i, s_end))) * keep)
			for id: String in wings: add.call(id, "rot", -0.25 * snap * keep)
		"burrow":
			# Dig: the claw rises, then rakes down while the body sinks in.
			add.call("arm", "rot", (-0.6 * coil + 1.0 * snap) * keep)
			add.call("arm", "dy", -1.2 * coil * keep)
			add.call("neck", "rot", (0.08 * coil + 0.25 * snap) * keep)
			var sy := 1.0 - 0.06 * coil * keep
			whole.sy = sy
			whole.sx = 1.0 / sy
			var sink := ease_in(seg(u, w_end, s_end)) * keep
			whole.dy = 6.0 * sink
			whole.dx = 0.4 * sin(ct * 55.0) * snap * keep
			for part: Dictionary in rig.get("parts", []):
				if has.call(str(part.id)): P(pose, str(part.id)).alpha = 1.0 - 0.6 * sink
		"swing":
			# Tail whirl, hitting all around: the tail curls up over the back
			# (windup), then Ignaroth spins once about its vertical axis
			# (whole.turn 1 -> -1 -> 1, mirrored by RigRenderer) while the tail
			# uncurls root first and streams out behind, every segment lagging
			# its parent. Every tail turn here is a lift (a positive turn raises
			# the left-pointing tail), so the tail never dips below the floor.
			var spin := ease_in_out(seg(u, w_end, s_end))
			whole.turn = cos(TAU * spin)
			var whirl := seg(u, w_end, s_end)
			for i in range(DRAKE_TAIL_IDS.size()):
				var release := ease_out(seg(u, w_end + 0.03 * i, w_end + 0.14 + 0.03 * i))
				var curl := (0.34 - 0.03 * i) * coil * (1.0 - release)
				var stream := (0.05 + 0.02 * i) * sin(PI * seg(u, w_end + 0.03 * i, s_end)) * keep
				add.call(DRAKE_TAIL_IDS[i], "rot", curl + stream)
			var sy := 1.0 - 0.05 * coil * (1.0 - spin) - 0.03 * sin(PI * whirl)
			whole.sy = sy
			whole.sx = 1.0 / sy
			add.call("body", "rot", 0.05 * coil * (1.0 - spin))
			add.call("neck", "rot", -0.08 * coil * (1.0 - spin) + 0.1 * sin(PI * whirl))
		"sweep":
			# Breath: the head rears back while the throat swells and glows, then
			# the open mouth pans across the floor.
			var open := ease_out(seg(u, w_end, w_end + 0.06))
			var pan := ease_in_out(seg(u, w_end, s_end))
			add.call("head", "rot", lerpf(-0.42 * coil, -0.15 + 0.5 * pan, open) * keep)
			add.call("head", "dx", -0.8 * coil * (1.0 - open) * keep)
			add.call("neck", "rot", lerpf(-0.12 * coil, -0.1 + 0.3 * pan, open) * keep)
			add.call("jaw", "rot", (0.45 + 0.03 * sin(ct * 40.0)) * open * keep)
			add.call("throat", "sx", 0.035 * coil * keep)
			add.call("body", "rot", -0.04 * coil * keep)
			add.call("tail_1", "rot", 0.04 * coil * keep)
			if has.call("throat"): glow.throat = lerpf(float(glow.throat), 1.0, maxf(coil, open) * keep)
			if striking: frames.mouth_flame = int(floor(ct * fps * 1.8))
		"roar":
			# Rings and echoes: rear up with the wings raised and spread (a lift,
			# positive in the flap 1 sense), roar with a shake, the wings
			# shuddering half-raised.
			whole.rot = (-0.1 * coil + 0.04 * snap) * keep
			add.call("neck", "rot", (-0.32 * coil + 0.12 * snap) * keep)
			add.call("head", "rot", (-0.22 * coil + 0.1 * snap) * keep + 0.05 * sin(ct * 50.0) * snap * keep)
			add.call("jaw", "rot", (0.15 * coil + 0.4 * snap) * keep)
			for id: String in wings:
				add.call(id, "rot", (0.5 * coil - 0.15 * snap + 0.04 * sin(ct * 47.0) * snap) * keep)
				if has.call(id): P(pose, id).sy = lerpf(float(P(pose, id).sy), 1.05, coil * keep)
			var sx := 1.0 + 0.05 * snap * keep
			whole.sx = sx
			whole.sy = 1.0 / sx
		"flight":
			# Take off: crouch with the wings raised high (a lift), push off with
			# one downstroke (DRAKE_PUSH of the clip), beat them in the air,
			# come down and land with a squash.
			var rise := ease_out(seg(u, w_end, w_end + 0.1))
			var fall := ease_in_out(seg(u, s_end - 0.08, s_end))
			var air := rise * (1.0 - fall)
			var land := seg(u, s_end, minf(1.0, s_end + 0.06))
			var squash := sin(PI * land) if u > s_end and land < 1.0 else 0.0
			var flap_w := TAU / DRAKE_FLAP
			if mode != "fly":
				whole.dy = -(8.0 + 2.0 * form) * air - 1.5 * sin(t * flap_w - 0.8) * air
				whole.rot = -0.05 * air
				add.call("leg_far", "rot", -0.5 * air)
				add.call("leg_near", "rot", -0.6 * air)
				add.call("arm", "rot", -0.55 * air)
				add.call("tail_1", "rot", 0.15 * air)
			var sy := 1.0 - 0.06 * coil * (1.0 - rise) - 0.08 * squash
			whole.sy = sy
			whole.sx = 1.0 / sy
			var push := ease_in_out(seg(u, w_end, w_end + DRAKE_PUSH))
			var into_beat := ease_in_out(seg(u, w_end + DRAKE_PUSH, w_end + 2.5 * DRAKE_PUSH))
			for i in range(wings.size()):
				if not has.call(wings[i]): continue
				var part: Dictionary = rig.by_id[wings[i]]
				var beat := t * flap_w + 0.35 * i + (DRAKE_FLIP_BEAT if float(part.get("flap", 1.0)) < 0.0 else 0.0)
				var wing := P(pose, wings[i])
				var stroke := lerpf(0.75 * coil, _drake_beat(part, 0.55, -1.0), push)
				wing.rot = lerpf(stroke, _drake_beat(part, 0.55, sin(beat)), into_beat) * (1.0 - fall)
				wing.sy = 1.0 + 0.06 * cos(beat) * air
		"beam":
			# Void beams: the crystals tilt back on their bases, rise a little
			# out of the back, stretch and flare, the body rears; then they snap
			# forward and the body leans into the beam with a recoil judder. The
			# rise stays within what the short crystals' bases afford (each keeps
			# at least half of its rest overlap with the body).
			var hold := ease_out(seg(u, w_end, w_end + 0.05))
			for i in range(crystals.size()):
				add.call(crystals[i], "dy", (-DRAKE_CRYSTAL_RISE * coil + DRAKE_CRYSTAL_RISE * 0.7 * hold) * keep)
				add.call(crystals[i], "rot", ((-0.45 - 0.05 * i) * coil + 0.6 * hold) * keep)
				add.call(crystals[i], "sy", 0.1 * coil * keep)
				add.call(crystals[i], "sx", -0.08 * coil * keep)
				if striking: add.call(crystals[i], "rot", 0.08 * sin(ct * 70.0 + 2.0 * i))
				if has.call(crystals[i]): glow[crystals[i]] = lerpf(float(glow[crystals[i]]), 1.0, maxf(coil, 1.0 if striking else 0.0) * keep)
			add.call("body", "rot", (-0.05 * coil + 0.08 * hold) * keep)
			add.call("tail_1", "rot", (0.05 * coil - 0.06 * hold) * keep)
			add.call("neck", "rot", 0.05 * coil * keep)
			add.call("jaw", "rot", (0.08 * coil + 0.27 * hold) * keep)
			if striking:
				whole.dx = (0.4 if sin(ct * 90.0) > 0.0 else -0.4) - 1.2 * ease_out(seg(u, w_end, w_end + 0.06))
				frames.mouth_flame = int(floor(ct * fps * 2.0))
		"hit":
			var k := 1.0 - ease_out(u)
			whole.dx = float(whole.dx) - 2.0 * k
			whole.sx = 1.0 + 0.06 * k
			whole.sy = 1.0 - 0.06 * k
			add.call("neck", "rot", -0.14 * k)
			add.call("head", "rot", 0.25 * sin(u * 22.0) * k)
			for i in range(DRAKE_TAIL_IDS.size()): add.call(DRAKE_TAIL_IDS[i], "rot", 0.12 * k * sin(u * 18.0 - 0.8 * i))
			for id: String in wings: add.call(id, "rot", -0.25 * k)
		"death":
			# Shudder, tip over the front feet, the neck and head drop, fade late.
			var shudder := 1.0 - seg(u, 0.0, 0.3)
			var fall := ease_in(seg(u, 0.2, 0.65))
			var drop := ease_in(seg(u, 0.3, 0.75))
			var ground: Vector2 = rig.get("ground", Vector2.ZERO)
			whole.pivot = Vector2(ground.x + float(rig.get("width", 10.0)) * 0.35, ground.y)
			whole.dx = float(whole.dx) + 0.6 * sin(ct * 60.0) * shudder
			whole.rot = (PI / 2.4) * fall
			whole.dy = 2.0 * fall
			whole.sx = 1.0 + 0.05 * fall
			whole.sy = 1.0 - 0.05 * fall
			add.call("neck", "rot", 0.35 * drop)
			add.call("head", "rot", 0.3 * drop)
			add.call("jaw", "rot", 0.3 * drop)
			add.call("leg_far", "rot", -0.4 * fall)
			add.call("leg_near", "rot", 0.35 * fall)
			add.call("arm", "rot", -0.5 * fall)
			add.call("tail_1", "rot", -0.3 * fall)
			var fade := 1.0 - ease_in(seg(u, 0.75, 1.0))
			for part: Dictionary in rig.get("parts", []):
				if has.call(str(part.id)): P(pose, str(part.id)).alpha = fade
			for id: String in glow: glow[id] = float(glow[id]) * fade
