extends RefCounted
## Per-frame poses of the part rigs, ported 1:1 from the approved review page
## (production/art-proof/0x72-style/full.template.html, POSES). A pose moves
## the whole figure and each part/item; values are in source pixels and
## radians. `a` is the presentation state of one actor (see RigRenderer):
## t (seconds), moving, clip, u (0..1 clip progress), lost, regrowing.

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
	match str(rig.get("family", "")):
		"hero": return hero(rig, a)
		"skeleton": return skeleton(rig, a)
		"necro": return necro(rig, a)
		"biped": return biped(rig, a)
		"brute": return brute(rig, a)
		"void": return void_lord(rig, a)
		"bomber": return bomber(rig, a)
	return blank()


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
		var ph := t * TAU / 0.42
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
