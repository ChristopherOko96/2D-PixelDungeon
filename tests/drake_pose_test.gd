extends SceneTree
## Ignaroth's part poses (src/rig/rig_poses.gd, family "drake") against the
## researched feel criteria of docs/HOELLE-RIGS.de.md, per form, on a synthetic
## rig in the hell_rigs.json shape AND on the real rigs drache1-4
## (assets/data/hell_rigs.json through RigLibrary): ANIM-01 no lockstep (idle,
## walk, flight), ANIM-02 whip chains (idle, walk), ANIM-04 readable windup as
## the player sees it (raw movement, idle included), ANIM-05 volume-keeping
## squash and planted feet (idle and walk), ANIM-06 living idle; the tail whirl
## stays above the floor; every clip stays finite, lost and regrowing parts are
## handled, flying is not walking, flipbooks follow rig.fps. Poses are sampled
## at 120 Hz; a part's motion signal is its strongest own channel (rotation
## times its lever from pivot to rest centre, dx, dy, or scale times 4 px).

const RigPoses = preload("res://src/rig/rig_poses.gd")
const RigLibrary = preload("res://src/rig/rig_library.gd")
const HZ := 120.0
## Shortest lever (source px) a rotation is weighed with.
const MIN_LEVER := 2.0
## A part moves when its own signal and its rest centre in the figure's frame
## both vary by more than this standard deviation (source px).
const MOVING := 0.05
const TAIL: Array[String] = ["tail_1", "tail_2", "tail_3", "tail_4", "tail_5"]
## The parts that carry each attack clip (ANIM-04). A part hanging on one of
## them (horns, mouth flame, tail flame) counts as that part, except below the
## root body.
const BOUND := {"bite": ["jaw", "head"], "swing": ["tail_1", "tail_2", "tail_3", "tail_4", "tail_5"], "flight": ["wing_far", "wing_near"],
	"beam": ["crystal_1", "crystal_2", "crystal_3", "body"], "sweep": ["head", "throat"]}
const CLIPS: Array[String] = ["", "bite", "slam", "dash", "burrow", "swing", "sweep", "roar", "beam", "flight", "hit", "death"]
## Idle moments (s) the windups start from: the bound part must lead from each.
const WINDUP_STARTS: Array[float] = [0.0, 0.9, 1.8, 3.0, 4.3]
## Seconds one sampled attack clip lasts (u 0..1).
const CLIP_SECONDS := 1.2
## Pairs that move together by design: the hind legs in the gait (half a cycle
## apart, so their signals are anti-phase), and the two wings beating in
## flight. They are exempt from the r check; the flight wing pair also counts
## as one mover for the peak gap and bins.
const PAIRED := {"idle": [], "walk": [["leg_far", "leg_near"]], "fly": [["wing_far", "wing_near"]]}

var checked := 0
var failures: Array[String] = []


func check(condition: bool, description: String) -> void:
	checked += 1
	if not condition:
		failures.append(description)
		printerr("DRAKE_POSE_FAIL: ", description)


func _initialize() -> void:
	var rigs: Array[Dictionary] = []
	for variant: String in ["1", "2", "3", "4"]: rigs.append(_rig(variant))
	var library := RigLibrary.new()
	library.load_data()
	for variant: String in ["1", "2", "3", "4"]:
		var real: Dictionary = library.rig("drache" + variant)
		check(not real.is_empty() and str(real.get("family", "")) == "drake" and str(real.get("variant", "")) == variant, "the real rig drache%s loads (assets/data/hell_rigs.json)" % variant)
		if not real.is_empty(): rigs.append(real)
	check(RigPoses.pose(rigs[3], _actor(0.0)).has("glow"), "the drake family is dispatched by RigPoses.pose")
	for rig: Dictionary in rigs:
		_test_no_lockstep(rig, "idle")
		_test_no_lockstep(rig, "walk")
		if rig.by_id.has("wing_far"): _test_no_lockstep(rig, "fly")
		_test_chains(rig, "idle")
		_test_chains(rig, "walk")
		_test_windups(rig)
		_test_living_idle(rig)
		_test_feet(rig)
		_test_swing_above_floor(rig)
		# the real art (part images): joints, the head's layer, the wings' geometry
		if rig.get("layered", false):
			_test_joints_hold(rig)
			_test_nothing_over_the_head(rig)
			_test_wings_clear_the_head(rig)
	_test_wing_data(library)
	_test_volume()
	_test_finite_lost_regrowing()
	_test_flying_is_not_walking(_rig("3"))
	_test_flipbook_rate()
	print("DRAKE_POSE checked=%d failures=%d" % [checked, failures.size()])
	quit(1 if failures.size() > 0 else 0)


# ------------------------------------------------------------------ fixtures

## A synthetic drake rig, rest pose facing right, 100x64 source frame: the part
## ids, parents and pivots of the contract; forms 3/4 add wings, throat and
## horns, form 4 the crystals and the mouth flame. `force_wings` adds wings to
## any form (to prove only forms 3/4 move them).
func _rig(variant: String, force_wings := false) -> Dictionary:
	var form := variant.to_int()
	# [id, pivot, parent, z, rest centre]
	var specs: Array = [
		["body", Vector2(50, 44), "", 10, Vector2(50, 38)],
		["neck", Vector2(66, 36), "body", 12, Vector2(71, 28)],
		["head", Vector2(74, 20), "neck", 14, Vector2(80, 18)],
		["jaw", Vector2(76, 23), "head", 13, Vector2(82, 25)],
		["arm", Vector2(64, 46), "body", 15, Vector2(66, 54)],
		["leg_far", Vector2(40, 48), "body", 5, Vector2(40, 55)],
		["leg_near", Vector2(45, 49), "body", 16, Vector2(45, 56)],
		["tail_1", Vector2(34, 44), "body", 8, Vector2(30, 45)],
		["tail_2", Vector2(26, 46), "tail_1", 8, Vector2(23, 47)],
		["tail_3", Vector2(20, 48), "tail_2", 8, Vector2(17, 49)],
		["tail_4", Vector2(14, 50), "tail_3", 8, Vector2(11.5, 51)],
		["tail_5", Vector2(9, 52), "tail_4", 8, Vector2(7, 53)],
		["tail_flame", Vector2(5, 53), "tail_5", 9, Vector2(3, 53)],
	]
	if form >= 3 or force_wings:
		specs.append(["wing_far", Vector2(52, 30), "body", 4, Vector2(44, 16)])
		specs.append(["wing_near", Vector2(55, 31), "body", 18, Vector2(47, 17)])
	if form >= 3:
		specs.append(["throat", Vector2(70, 30), "neck", 13, Vector2(72, 31)])
		specs.append(["horns", Vector2(74, 15), "head", 15, Vector2(71, 11)])
	if form >= 4:
		# the void crystals' centres stand 7 px over their bases: the real art's 11-14 px
		# (drache4, body 76 px wide) scaled to this body (40 px)
		specs.append(["crystal_1", Vector2(44, 30), "body", 11, Vector2(43, 23)])
		specs.append(["crystal_2", Vector2(50, 29), "body", 11, Vector2(49, 22)])
		specs.append(["crystal_3", Vector2(56, 30), "body", 11, Vector2(56, 23)])
		specs.append(["mouth_flame", Vector2(88, 23), "jaw", 17, Vector2(91, 23)])
	var parts: Array[Dictionary] = []
	var by_id: Dictionary = {}
	for spec: Array in specs:
		var part := {"id": spec[0], "pivot": spec[1], "parent": spec[2], "z": spec[3], "center": spec[4], "hp": 10.0}
		if str(spec[0]).ends_with("flame"): part.frames = [{}, {}, {}, {}]
		parts.append(part)
		by_id[spec[0]] = part
	return {"name": "synthetic" + variant, "family": "drake", "variant": variant, "ground": Vector2(48, 62), "width": 40.0, "size": Vector2(100, 64),
		"material": "obsidian" if form == 4 else "ember", "parts": parts, "items": [], "by_id": by_id}


func _actor(t: float, moving := false, flying := false, clip := "", u := 0.0, lost: Dictionary = {}, regrowing: Dictionary = {}) -> Dictionary:
	return {"t": t, "moving": moving, "flying": flying, "clip": clip, "u": u, "ct": u * CLIP_SECONDS, "lost": lost, "regrowing": regrowing, "cycle": 0.0}


func _label(rig: Dictionary, mode := "") -> String:
	return "%s%s" % [rig.name, (" " + mode) if not mode.is_empty() else ""]


# ------------------------------------------------------------------ geometry

func _state(pose: Dictionary, id: String) -> Dictionary:
	return pose.parts.get(id, {"dx": 0.0, "dy": 0.0, "rot": 0.0, "sx": 1.0, "sy": 1.0, "alpha": 1.0})


## The part's own transform about its pivot (as RigRenderer._part_world).
func _local(part: Dictionary, p: Dictionary) -> Transform2D:
	var pivot: Vector2 = part.pivot
	var scale := Transform2D(Vector2(float(p.get("sx", 1.0)), 0), Vector2(0, float(p.get("sy", 1.0))), Vector2.ZERO)
	return Transform2D(0.0, pivot + Vector2(float(p.get("dx", 0.0)), float(p.get("dy", 0.0)))) * Transform2D(float(p.get("rot", 0.0)), Vector2.ZERO) * scale * Transform2D(0.0, -pivot)


## Every part's transform in the figure's frame (whole pose left out).
func _frames(rig: Dictionary, pose: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for id: String in rig.by_id: _frame_of(rig, pose, id, out)
	return out


func _frame_of(rig: Dictionary, pose: Dictionary, id: String, out: Dictionary) -> Transform2D:
	if out.has(id): return out[id]
	var parent := str(rig.by_id[id].parent)
	var above := _frame_of(rig, pose, parent, out) if rig.by_id.has(parent) else Transform2D.IDENTITY
	out[id] = above * _local(rig.by_id[id], _state(pose, id))
	return out[id]


## The whole figure's transform (source px, feet anchored as in RigRenderer._solve).
func _whole(rig: Dictionary, pose: Dictionary) -> Transform2D:
	var whole: Dictionary = pose.whole
	var pivot: Vector2 = whole.pivot if whole.pivot is Vector2 else rig.ground
	var scale := Transform2D(Vector2(float(whole.sx), 0), Vector2(0, float(whole.sy)), Vector2.ZERO)
	return Transform2D(0.0, Vector2(float(whole.dx), float(whole.dy))) * Transform2D(0.0, pivot) * Transform2D(float(whole.rot), Vector2.ZERO) * scale * Transform2D(0.0, -pivot)


func _world_rot(rig: Dictionary, pose: Dictionary, id: String) -> float:
	var total := 0.0
	var at := id
	while rig.by_id.has(at):
		total += float(_state(pose, at).rot)
		at = str(rig.by_id[at].parent)
	return total


func _lever(part: Dictionary) -> float:
	return maxf(MIN_LEVER, Vector2(part.center).distance_to(part.pivot))


## True when `id` is one of `bound` or hangs on one of them (not counting the root).
func _carries(rig: Dictionary, id: String, bound: Array) -> bool:
	if id in bound: return true
	var at := str(rig.by_id[id].parent)
	while rig.by_id.has(at) and not str(rig.by_id[at].parent).is_empty():
		if at in bound: return true
		at = str(rig.by_id[at].parent)
	return false


# ------------------------------------------------------------------ signals

func _mode_actor(t: float, mode: String) -> Dictionary:
	return _actor(t, mode == "walk", mode == "fly")


## `seconds` of poses from t0: per part its own channels, the rest centre in the
## figure's frame, the world rotation and the foot (pivot x on the ground line,
## whole pose included); and the whole figure's sy and dy.
func _sample(rig: Dictionary, t0: float, seconds: float, mode: String) -> Dictionary:
	var n := int(seconds * HZ)
	var parts: Dictionary = {}
	for id: String in rig.by_id: parts[id] = {"rot": PackedFloat64Array(), "dx": PackedFloat64Array(), "dy": PackedFloat64Array(), "sx": PackedFloat64Array(),
		"sy": PackedFloat64Array(), "cx": PackedFloat64Array(), "cy": PackedFloat64Array(), "wrot": PackedFloat64Array(), "foot": PackedFloat64Array()}
	var whole_sy := PackedFloat64Array()
	var whole_dy := PackedFloat64Array()
	for i in range(n):
		var t := t0 + float(i) / HZ
		var pose: Dictionary = RigPoses.pose(rig, _mode_actor(t, mode))
		whole_sy.append(float(pose.whole.sy))
		whole_dy.append(float(pose.whole.dy))
		var whole := _whole(rig, pose)
		var frames := _frames(rig, pose)
		for id: String in rig.by_id:
			var part: Dictionary = rig.by_id[id]
			var p := _state(pose, id)
			var row: Dictionary = parts[id]
			for key: String in ["rot", "dx", "dy", "sx", "sy"]: row[key].append(float(p.get(key, 1.0 if key.begins_with("s") else 0.0)))
			var framed: Transform2D = frames[id]
			var c := framed * Vector2(part.center)
			row.cx.append(c.x)
			row.cy.append(c.y)
			row.wrot.append(_world_rot(rig, pose, id))
			# the foot: its lower sole point (heel/toe of the real art), minus where it rests
			var low := -INF
			for sole_point: Vector2 in _sole(rig, part):
				low = maxf(low, (whole * framed * sole_point).y - sole_point.y)
			row.foot.append(float(rig.ground.y) + low)
	return {"t0": t0, "parts": parts, "whole_sy": whole_sy, "whole_dy": whole_dy}


## A leg's sole points: the real art's heel and toe (RigLibrary "sole"), else
## the point under its pivot on the ground line.
func _sole(rig: Dictionary, part: Dictionary) -> Array:
	return part.get("sole", [Vector2(Vector2(part.pivot).x, float(rig.ground.y))])


func _mean(values: PackedFloat64Array) -> float:
	var total := 0.0
	for v in values: total += v
	return total / maxf(1.0, float(values.size()))


func _std(values: PackedFloat64Array) -> float:
	var m := _mean(values)
	var total := 0.0
	for v in values: total += (v - m) * (v - m)
	return sqrt(total / maxf(1.0, float(values.size())))


func _span(values: PackedFloat64Array) -> float:
	var lo := INF
	var hi := -INF
	for v in values:
		lo = minf(lo, v)
		hi = maxf(hi, v)
	return hi - lo


func _scaled(values: PackedFloat64Array, factor: float, offset := 0.0) -> PackedFloat64Array:
	var out := PackedFloat64Array()
	for v in values: out.append((v - offset) * factor)
	return out


## The part's strongest own channel in source px.
func _signal(rig: Dictionary, row: Dictionary, id: String) -> PackedFloat64Array:
	var options: Array = [_scaled(row.rot, _lever(rig.by_id[id])), row.dx, row.dy, _scaled(row.sx, 4.0, 1.0), _scaled(row.sy, 4.0, 1.0)]
	var best: PackedFloat64Array = options[0]
	for option: PackedFloat64Array in options:
		if _std(option) > _std(best): best = option
	return best


## Times of the prominent local maxima (parabolic refinement between samples).
func _peaks(values: PackedFloat64Array, t0: float) -> PackedFloat64Array:
	var out := PackedFloat64Array()
	var floor_value := _mean(values) + 0.25 * _std(values)
	for i in range(1, values.size() - 1):
		if values[i] > values[i - 1] and values[i] >= values[i + 1] and values[i] > floor_value:
			var denom := values[i - 1] - 2.0 * values[i] + values[i + 1]
			var off := 0.5 * (values[i - 1] - values[i + 1]) / denom if absf(denom) > 1e-12 else 0.0
			out.append(t0 + (float(i) + off) / HZ)
	return out


func _median(values: Array) -> float:
	if values.is_empty(): return INF
	var sorted := values.duplicate()
	sorted.sort()
	return float(sorted[sorted.size() / 2])


## Median gap between the peaks of two parts: every peak of either part to the
## nearest peak of the other, pooled (a sparse slow signal cannot skew it).
func _nearest(a: PackedFloat64Array, b: PackedFloat64Array) -> float:
	var gaps: Array = []
	for pair: Array in [[a, b], [b, a]]:
		for x in pair[0]:
			var best := INF
			for y in pair[1]: best = minf(best, absf(x - y))
			gaps.append(best)
	return _median(gaps)


func _pearson(a: PackedFloat64Array, b: PackedFloat64Array) -> float:
	var ma := _mean(a)
	var mb := _mean(b)
	var num := 0.0
	var da := 0.0
	var db := 0.0
	for i in range(a.size()):
		num += (a[i] - ma) * (b[i] - mb)
		da += (a[i] - ma) * (a[i] - ma)
		db += (b[i] - mb) * (b[i] - mb)
	return num / maxf(1e-12, sqrt(da * db))


## Median time from each child peak back to the latest parent peak before it.
func _lag(parent: PackedFloat64Array, child: PackedFloat64Array) -> float:
	var lags: Array = []
	for c in child:
		var latest := -INF
		for p in parent:
			if p <= c: latest = maxf(latest, p)
		if latest > -INF: lags.append(c - latest)
	return _median(lags)


## Parts that visibly move on their own: id -> signal.
func _moving(rig: Dictionary, sample: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for id: String in rig.by_id:
		var row: Dictionary = sample.parts[id]
		var own := _signal(rig, row, id)
		if _std(own) > MOVING and (_std(row.cx) > MOVING or _std(row.cy) > MOVING): out[id] = own
	return out


func _paired(mode: String, p: String, q: String) -> bool:
	for pair: Array in PAIRED[mode]:
		if (p == pair[0] and q == pair[1]) or (p == pair[1] and q == pair[0]): return true
	return false


# ------------------------------------------------------------------ criteria

## ANIM-01: moving parts peak >= 0.08 s apart (median nearest-peak gap per
## pair), |Pearson r| < 0.9 between every pair (anti-phase lockstep counts too;
## PAIRED pairs are exempt), <= 2 parts peak in one 1/30 s bin.
## Retuning: the bin check is a matter of chance with 12-18 parts on unrelated
## periods. When a pose change fails only it, the crowded bin is printed with
## its parts; sweep the tuned constant of that gait in rig_poses.gd
## (DRAKE_CYCLES walk, DRAKE_FLIP_PHASE ground breath of a flap -1 wing,
## DRAKE_FLIP_BEAT its flight beat) in steps of 0.1, keep a value in the middle
## of a passing band and write the band next to the constant.
func _test_no_lockstep(rig: Dictionary, mode: String) -> void:
	var label := _label(rig, mode)
	var sample := _sample(rig, 0.0, 12.0, mode)
	var moving := _moving(rig, sample)
	var ids: Array = moving.keys()
	var peaks: Dictionary = {}
	for id: String in ids: peaks[id] = _peaks(moving[id], 0.0)
	var worst_gap := INF
	var worst_gap_pair := ""
	var worst_r := 0.0
	var worst_r_pair := ""
	for i in range(ids.size()):
		for j in range(i + 1, ids.size()):
			var p: String = ids[i]
			var q: String = ids[j]
			if _paired(mode, p, q): continue
			var gap := _nearest(peaks[p], peaks[q])
			if gap < worst_gap:
				worst_gap = gap
				worst_gap_pair = "%s/%s" % [p, q]
			var r := absf(_pearson(moving[p], moving[q]))
			if r > worst_r:
				worst_r = r
				worst_r_pair = "%s/%s" % [p, q]
	var bins: Dictionary = {}
	for id: String in ids:
		if mode == "fly" and id == "wing_near" and ids.has("wing_far"): continue
		for at in peaks[id]:
			var b := int(floor(at * 30.0))
			if not bins.has(b): bins[b] = []
			bins[b].append(id)
	var crowd := 0
	for b: int in bins:
		crowd = maxi(crowd, bins[b].size())
		if bins[b].size() > 2: print("  crowded bin at %.3f s: %s" % [b / 30.0, bins[b]])
	print("ANIM-01 %s: %d moving parts, min median peak gap %.3f s (%s), max |r| %.3f (%s), max peaks per 1/30 s bin %d" % [label, ids.size(), worst_gap, worst_gap_pair, worst_r, worst_r_pair, crowd])
	var enough := 5 if mode == "fly" or str(rig.variant).to_int() < 3 else 8
	check(ids.size() >= enough, "ANIM-01 %s: enough parts move (%d)" % [label, ids.size()])
	check(worst_gap >= 0.08, "ANIM-01 %s: moving parts peak >= 0.08 s apart (%s: %.3f s)" % [label, worst_gap_pair, worst_gap])
	check(worst_r < 0.9, "ANIM-01 %s: no pair moves in lockstep, in or against phase (%s |r|=%.3f)" % [label, worst_r_pair, worst_r])
	check(crowd <= 2, "ANIM-01 %s: at most 2 parts peak in one 1/30 s bin (%d)" % [label, crowd])


## ANIM-02: neck->head and tail_1..tail_5 (world rotation along the parent
## chain), standing and walking: each child peaks 0.04-0.30 s after its
## parent, the lag grows to the tip, and the tip swings at least 1.2x as wide
## as the base.
func _test_chains(rig: Dictionary, mode: String) -> void:
	var label := _label(rig, mode)
	var sample := _sample(rig, 0.0, 10.0, mode)
	for chain: Array in [["neck", "head"], TAIL]:
		var peaks: Array = []
		var amps: Array = []
		for id: String in chain:
			var wrot: PackedFloat64Array = sample.parts[id].wrot
			peaks.append(_peaks(wrot, 0.0))
			amps.append(_span(wrot) * 0.5)
		var lags: Array = []
		var from_base: Array = []
		for k in range(1, chain.size()):
			lags.append(_lag(peaks[k - 1], peaks[k]))
			from_base.append(_lag(peaks[0], peaks[k]))
		var ratio := float(amps[-1]) / maxf(1e-9, float(amps[0]))
		print("ANIM-02 %s %s: child lags %s s, lag from base %s s, tip/base amplitude %.2f" % [label, "->".join(chain), _fmt(lags), _fmt(from_base), ratio])
		for k in range(lags.size()):
			check(float(lags[k]) >= 0.04 and float(lags[k]) <= 0.30, "ANIM-02 %s: %s peaks 0.04-0.30 s after %s (%.3f s)" % [label, chain[k + 1], chain[k], lags[k]])
		for k in range(1, from_base.size()):
			check(float(from_base[k]) > float(from_base[k - 1]), "ANIM-02 %s: the lag grows towards %s" % [label, chain[k + 1]])
		check(ratio >= 1.2, "ANIM-02 %s: %s swings >= 1.2x as wide as %s (%.2f)" % [label, chain[-1], chain[0], ratio])


## ANIM-04 as the player sees it: over the windup [0, end of windup] the part
## that carries the attack (or a part hanging on it) shows the largest raw
## movement of its rest centre in the figure's frame from where the clip
## started, the idle that keeps running included, from several idle moments;
## and its windup runs against the strike (30 % into the strike window; for
## the take-off, at the end of its push-off downstroke, RigPoses.DRAKE_PUSH).
func _test_windups(rig: Dictionary) -> void:
	var clips: Array[String] = ["bite", "swing", "sweep"]
	if rig.by_id.has("wing_far"): clips.append("flight")
	if rig.by_id.has("crystal_1"): clips.append("beam")
	for clip: String in clips:
		var windows: Array = RigPoses.DRAKE_WINDOWS[clip]
		var w_end := float(windows[0])
		var s_end := float(windows[1])
		var bound: Array = BOUND[clip]
		var worst_margin := INF
		var worst_note := ""
		var worst_against := -INF
		for t0: float in WINDUP_STARTS:
			var centre := func(id: String, u: float) -> Vector2:
				var pose: Dictionary = RigPoses.pose(rig, _actor(t0 + u * CLIP_SECONDS, false, false, clip, u))
				return _frame_of(rig, pose, id, {}) * Vector2(rig.by_id[id].center)
			var start := _frames(rig, RigPoses.pose(rig, _actor(t0, false, false, clip, 0.0)))
			var move: Dictionary = {}
			for id: String in rig.by_id: move[id] = 0.0
			for i in range(1, 41):
				var u := w_end * float(i) / 40.0
				var frames := _frames(rig, RigPoses.pose(rig, _actor(t0 + u * CLIP_SECONDS, false, false, clip, u)))
				for id: String in rig.by_id:
					var c := Vector2(rig.by_id[id].center)
					move[id] = maxf(float(move[id]), (Transform2D(frames[id]) * c - Transform2D(start[id]) * c).length())
			var best := ""
			var best_other := ""
			for id: String in rig.by_id:
				if _carries(rig, id, bound):
					if best.is_empty() or float(move[id]) > float(move[best]): best = id
				elif best_other.is_empty() or float(move[id]) > float(move[best_other]): best_other = id
			var margin := float(move[best]) / maxf(1e-6, float(move[best_other]))
			if margin < worst_margin:
				worst_margin = margin
				worst_note = "t0 %.1f: %s %.2f px vs %s %.2f px" % [t0, best, move[best], best_other, move[best_other]]
			check(margin > 1.0, "ANIM-04 %s %s from t0 %.1f s: the bound part leads the windup (%s %.2f px, %s %.2f px)" % [_label(rig), clip, t0, best, move[best], best_other, move[best_other]])
			var wind: Vector2 = Vector2(centre.call(best, w_end)) - Vector2(centre.call(best, 0.0))
			# the strike: 30 % into it; the take-off's is its push-off downstroke
			var probe := w_end + (RigPoses.DRAKE_PUSH if clip == "flight" else 0.3 * (s_end - w_end))
			var strike: Vector2 = Vector2(centre.call(best, probe)) - Vector2(centre.call(best, w_end))
			var against := wind.normalized().dot(strike.normalized())
			worst_against = maxf(worst_against, against)
			check(against < 0.0, "ANIM-04 %s %s from t0 %.1f s: the windup moves against the strike (%.2f)" % [_label(rig), clip, t0, against])
		print("ANIM-04 %s %s: lead margin >= %.2f (%s), windup . strike <= %.2f" % [_label(rig), clip, worst_margin, worst_note, worst_against])


## ANIM-05: sx*sy within 0.92-1.08 and |sx-1|, |sy-1| <= 0.15 for the whole
## figure and every part in every clip, form and gait (whole.turn, the tail
## whirl's spin about the vertical axis, is a turn, not a squash); the slam
## lands with a squash on the floor.
func _test_volume() -> void:
	var lo := INF
	var hi := -INF
	var worst := 0.0
	var bad: Array = []
	for variant: String in ["1", "2", "3", "4"]:
		var rig := _rig(variant)
		for mode in range(3):
			if mode == 2 and variant.to_int() < 3: continue
			for clip: String in CLIPS:
				for i in range(51):
					var u := float(i) / 50.0
					var pose: Dictionary = RigPoses.pose(rig, _actor(2.0 + u, mode == 1, mode == 2, clip, u))
					var scales: Array = [["whole", pose.whole]]
					for id: String in pose.parts: scales.append([id, pose.parts[id]])
					for entry: Array in scales:
						var sx := float(entry[1].get("sx", 1.0))
						var sy := float(entry[1].get("sy", 1.0))
						lo = minf(lo, sx * sy)
						hi = maxf(hi, sx * sy)
						worst = maxf(worst, maxf(absf(sx - 1.0), absf(sy - 1.0)))
						if sx * sy < 0.92 or sx * sy > 1.08 or absf(sx - 1.0) > 0.15 or absf(sy - 1.0) > 0.15:
							if bad.size() < 6: bad.append("%s/%s/%s u=%.2f %s sx=%.3f sy=%.3f" % [variant, mode, clip, u, entry[0], sx, sy])
	print("ANIM-05: sx*sy in [%.3f, %.3f], max |s-1| %.3f" % [lo, hi, worst])
	check(bad.is_empty(), "ANIM-05: squash keeps the volume everywhere %s" % [bad])
	# The slam lands with a squash on the floor.
	var rig4 := _rig("4")
	var windows: Array = RigPoses.DRAKE_WINDOWS.slam
	var squash := 1.0
	var squash_sx := 1.0
	for i in range(101):
		var u := lerpf(float(windows[1]) - 0.05, 0.85, float(i) / 100.0)
		var pose: Dictionary = RigPoses.pose(rig4, _actor(2.0, false, false, "slam", u))
		if absf(float(pose.whole.dy)) <= 0.5 and float(pose.whole.sy) < squash:
			squash = float(pose.whole.sy)
			squash_sx = float(pose.whole.sx)
	print("ANIM-05 slam landing: sy %.3f sx %.3f on the floor" % [squash, squash_sx])
	check(squash <= 0.94 and squash_sx >= 1.04, "ANIM-05: the slam lands with a squash (sy %.3f, sx %.3f)" % [squash, squash_sx])


## ANIM-05 feet: standing, both feet stay on the floor; walking, the lower
## (stance) foot does, within 0.35 source px of the ground line.
func _test_feet(rig: Dictionary) -> void:
	var ground := float(rig.ground.y)
	var idle := _sample(rig, 0.0, 6.0, "idle")
	var drift := 0.0
	for id: String in ["leg_far", "leg_near"]:
		for y in idle.parts[id].foot: drift = maxf(drift, absf(y - ground))
	var walk := _sample(rig, 0.0, 4.0, "walk")
	var far: PackedFloat64Array = walk.parts.leg_far.foot
	var near: PackedFloat64Array = walk.parts.leg_near.foot
	var stance := 0.0
	var swing := 0.0
	for i in range(far.size()):
		stance = maxf(stance, absf(maxf(far[i], near[i]) - ground))
		swing = maxf(swing, ground - minf(far[i], near[i]))
	print("ANIM-05 %s feet: idle max %.3f src px off the floor, walking stance foot max %.3f px off, swing foot lifts %.2f px" % [_label(rig), drift, stance, swing])
	check(drift <= 0.35, "ANIM-05 %s: standing feet stay on the floor (%.3f px)" % [_label(rig), drift])
	check(stance <= 0.35, "ANIM-05 %s: walking, the stance foot stays on the floor (%.3f px)" % [_label(rig), stance])
	check(swing >= 0.6, "ANIM-05 %s: walking, the swinging foot lifts (%.2f px)" % [_label(rig), swing])


## The tail whirl keeps the tail above the floor: every tail segment's rest
## centre (whole pose included) stays at or above ground.y + 1, from several
## idle moments, and the figure spins once about its vertical axis.
func _test_swing_above_floor(rig: Dictionary) -> void:
	var ground := float(rig.ground.y)
	var lowest := -INF
	var lowest_at := ""
	var turn_lo := INF
	var turn_end := 0.0
	var ids: Array[String] = TAIL.duplicate()
	if rig.by_id.has("tail_flame"): ids.append("tail_flame")
	for t0: float in [0.0, 1.3, 2.6]:
		for i in range(101):
			var u := float(i) / 100.0
			var pose: Dictionary = RigPoses.pose(rig, _actor(t0 + u * CLIP_SECONDS, false, false, "swing", u))
			var whole := _whole(rig, pose)
			var frames := _frames(rig, pose)
			for id: String in ids:
				var y := (whole * Transform2D(frames[id]) * Vector2(rig.by_id[id].center)).y
				if y > lowest:
					lowest = y
					lowest_at = "%s u=%.2f" % [id, u]
			var turn := float(pose.whole.get("turn", 1.0))
			turn_lo = minf(turn_lo, turn)
			if i == 100: turn_end = turn
	print("tail whirl %s: lowest tail centre %.2f src px above the ground line (%s), turn down to %.2f" % [_label(rig), ground - lowest, lowest_at, turn_lo])
	check(lowest <= ground + 1.0, "the tail whirl of %s keeps the tail above the floor (%s %.2f px below)" % [_label(rig), lowest_at, lowest - ground])
	check(turn_lo < -0.95 and absf(turn_end - 1.0) < 1e-6, "the tail whirl of %s spins the figure once about its vertical axis (turn %.2f .. %.2f)" % [_label(rig), turn_lo, turn_end])


## ANIM-06: body bob 1-3 src px on 1.0-2.5 s, breathing squash 1.5-3 %, at
## least 3 parts on at least 2 periods whose ratio is not a whole number.
func _test_living_idle(rig: Dictionary) -> void:
	var label := _label(rig)
	var sample := _sample(rig, 0.0, 12.0, "idle")
	var bob: PackedFloat64Array = sample.parts.body.dy
	var bob_amp := _span(bob) * 0.5
	var bob_peaks := _peaks(bob, 0.0)
	var bob_period := (bob_peaks[-1] - bob_peaks[0]) / maxf(1.0, float(bob_peaks.size() - 1)) if bob_peaks.size() > 1 else INF
	var breath := _span(sample.whole_sy) * 0.5
	print("ANIM-06 %s: body bob %.2f src px every %.2f s, breathing squash +-%.1f %%" % [label, bob_amp, bob_period, breath * 100.0])
	check(bob_amp >= 1.0 and bob_amp <= 3.0 and bob_period >= 1.0 and bob_period <= 2.5, "ANIM-06 %s: the body bobs 1-3 px on 1.0-2.5 s (%.2f px, %.2f s)" % [label, bob_amp, bob_period])
	check(breath >= 0.015 and breath <= 0.03, "ANIM-06 %s: breathing squash of 1.5-3 %% (%.1f %%)" % [label, breath * 100.0])
	var moving := _moving(rig, sample)
	var periods: Dictionary = {}
	for id: String in moving:
		var peaks := _peaks(moving[id], 0.0)
		if peaks.size() < 3: continue
		periods[id] = (peaks[-1] - peaks[0]) / float(peaks.size() - 1)
	var on_pair: Dictionary = {}
	var ids: Array = periods.keys()
	for i in range(ids.size()):
		for j in range(ids.size()):
			var ratio := maxf(float(periods[ids[i]]), float(periods[ids[j]])) / minf(float(periods[ids[i]]), float(periods[ids[j]]))
			if absf(ratio - roundf(ratio)) > 0.1:
				on_pair[ids[i]] = true
				on_pair[ids[j]] = true
	var listed: Array = []
	for id: String in periods: listed.append("%s %.2f" % [id, periods[id]])
	print("ANIM-06 %s periods: %s" % [label, ", ".join(listed)])
	check(on_pair.size() >= 3, "ANIM-06 %s: >= 3 parts on periods with non-integer ratios (%d)" % [label, on_pair.size()])
	if periods.has("arm"): check(absf(float(periods.arm) - RigPoses.DRAKE_BOB) > 0.15, "ANIM-06 %s: the arm moves on its own period, not the body's (%.2f s)" % [label, periods.arm])


## Every clip in every form and gait returns finite numbers; lost parts get no
## pose and the tail stump twitches; regrowing parts scale in with a glow;
## only forms 3/4 move wings.
func _test_finite_lost_regrowing() -> void:
	var broken: Array = []
	for variant: String in ["1", "2", "3", "4"]:
		var rig := _rig(variant)
		for mode in range(3):
			for clip: String in CLIPS:
				for i in range(21):
					var u := float(i) / 20.0
					var pose: Dictionary = RigPoses.pose(rig, _actor(1.3 + u, mode == 1, mode == 2, clip, u))
					if not _finite(pose) and broken.size() < 4: broken.append("%s/%d/%s u=%.2f" % [variant, mode, clip, u])
	check(broken.is_empty(), "every clip, form and gait gives finite numbers %s" % [broken])
	var rig4 := _rig("4")
	var lost := {"tail_2": true, "tail_3": true, "tail_4": true, "tail_5": true, "tail_flame": true, "jaw": true, "wing_far": true}
	var twitch := 0.0
	var gone := true
	for i in range(60):
		var t := 0.5 + float(i) / HZ
		var whole_pose: Dictionary = RigPoses.pose(rig4, _actor(t))
		var cut: Dictionary = RigPoses.pose(rig4, _actor(t, false, false, "", 0.0, lost))
		twitch = maxf(twitch, absf(float(_state(cut, "tail_1").rot) - float(_state(whole_pose, "tail_1").rot)))
		for id: String in lost: if cut.parts.has(id): gone = false
		if not _finite(cut): gone = false
	check(gone, "lost parts get no pose and the rest stays finite")
	check(twitch > 0.03, "the tail stump twitches after the tail is cut (%.3f rad)" % twitch)
	var one_wing := 0.0
	var two_wings := 0.0
	for i in range(120):
		var t := float(i) / HZ
		one_wing = maxf(one_wing, absf(float(RigPoses.pose(rig4, _actor(t, false, true, "", 0.0, {"wing_far": true})).whole.rot) + 0.05))
		two_wings = maxf(two_wings, absf(float(RigPoses.pose(rig4, _actor(t, false, true)).whole.rot) + 0.05))
	check(one_wing > two_wings + 0.03, "flying on one wing wobbles (%.3f vs %.3f rad)" % [one_wing, two_wings])
	var regrow: Dictionary = RigPoses.pose(rig4, _actor(1.0, false, false, "", 0.0, {}, {"horns": 0.6}))
	check(float(_state(regrow, "horns").sx) < 0.95 and float(regrow.glow.get("horns", 0.0)) > 0.3, "a regrowing part scales in with a glow")
	var form2 := _rig("2", true)
	var still := true
	for i in range(30):
		var pose: Dictionary = RigPoses.pose(form2, _actor(float(i) / 10.0, false, i % 2 == 0, "roar" if i > 15 else "", 0.5))
		for id: String in ["wing_far", "wing_near"]:
			if absf(float(_state(pose, id).rot)) > 1e-6: still = false
	check(still, "only forms 3 and 4 move wings")


## Flying lifts the figure, beats the wings and tucks the legs; walking does not.
func _test_flying_is_not_walking(rig: Dictionary) -> void:
	var flying := _sample(rig, 0.0, 2.0, "fly")
	var walking := _sample(rig, 0.0, 2.0, "walk")
	var lift := _mean(flying.whole_dy)
	var beat := _span(flying.parts.wing_near.rot)
	var stroll := _span(walking.parts.wing_near.rot)
	var tuck := _mean(flying.parts.leg_near.rot)
	var stride := _span(walking.parts.leg_near.rot)
	print("flight vs walk: lift %.1f px, wing range %.2f vs %.2f rad, legs tucked %.2f rad, walking stride %.2f rad" % [lift, beat, stroll, tuck, stride])
	check(lift < -8.0 and _mean(walking.whole_dy) > -1.0, "flying lifts the dragon off the floor (%.1f px)" % lift)
	check(beat >= 0.9 and stroll <= 0.2, "flying beats the wings, walking only breathes them (%.2f vs %.2f)" % [beat, stroll])
	check(tuck < -0.3 and _span(flying.parts.leg_near.rot) < 0.05 and stride > 0.4, "flying tucks the legs, walking swings them")


## The flipbooks (tail and mouth flame) run at rig.fps (hell_rigs.json), 10
## fps without one, the mouth flame 1.2x as fast.
func _test_flipbook_rate() -> void:
	var rig := _rig("4")
	var plain: Dictionary = RigPoses.pose(rig, _actor(1.05)).frames
	rig.fps = 20.0
	var fast: Dictionary = RigPoses.pose(rig, _actor(1.05)).frames
	print("flipbooks at t=1.05 s: tail flame frame %d at 10 fps, %d at 20 fps; mouth flame %d / %d" % [plain.tail_flame, fast.tail_flame, plain.mouth_flame, fast.mouth_flame])
	check(int(plain.tail_flame) == 10 and int(fast.tail_flame) == 21, "the tail flame flips at rig.fps (%d, %d)" % [plain.tail_flame, fast.tail_flame])
	check(int(fast.mouth_flame) - 2 == int(floor(1.05 * 20.0 * 1.2)), "the mouth flame flips at 1.2x rig.fps (%d)" % fast.mouth_flame)


# ------------------------------------------------------------------ real art

## Poses the joint and wing checks sample: idle, walking, flying (forms 3/4)
## and every clip from start to end.
func _art_poses(rig: Dictionary) -> Array:
	var out: Array = []
	for i in range(30): out.append(["idle t=%.2f" % (i * 0.2), _actor(i * 0.2)])
	for i in range(20): out.append(["walk t=%.2f" % (i * 0.1), _actor(i * 0.1, true)])
	if rig.by_id.has("wing_far"):
		for i in range(20): out.append(["fly t=%.3f" % (i * 0.021), _actor(i * 0.021, false, true)])
	for clip: String in CLIPS:
		if clip.is_empty(): continue
		for i in range(11):
			var u := float(i) / 10.0
			out.append(["%s u=%.1f" % [clip, u], _actor(1.3 + u * CLIP_SECONDS, false, false, clip, u)])
	return out


## Opaque pixel centres of a part's image (the union of a flipbook's frames).
func _pixels_of(part: Dictionary) -> PackedVector2Array:
	var out := PackedVector2Array()
	var image: Image = part.image
	var used := image.get_used_rect()
	for y in range(used.position.y, used.end.y):
		for x in range(used.position.x, used.end.x):
			if image.get_pixel(x, y).a > 0.5: out.append(Vector2(x + 0.5, y + 0.5))
	return out


## How many of `pixels` (source px under `xform`) land on opaque pixels of `part` at rest.
func _cover(pixels: PackedVector2Array, xform: Transform2D, part: Dictionary) -> int:
	var image: Image = part.image
	var n := 0
	for c: Vector2 in pixels:
		var p := xform * c
		var x := int(floor(p.x))
		var y := int(floor(p.y))
		if x >= 0 and y >= 0 and x < image.get_width() and y < image.get_height() and image.get_pixel(x, y).a > 0.5: n += 1
	return n


## No gaps at the joints: in every sampled pose each part (flames aside) still
## overlaps its parent with at least JOINT_HOLD of the pixels it overlaps at
## rest (and at least one), so no joint opens and nothing floats off; the tail
## club (tail_5) stays on the tail.
const JOINT_HOLD := 0.45
## Joints that by design keep less: part id -> share.
const JOINT_HOLD_EXCEPT := {}
func _test_joints_hold(rig: Dictionary) -> void:
	var label := _label(rig)
	var rest: Dictionary = {}
	var pixels: Dictionary = {}
	for part: Dictionary in rig.parts:
		if str(part.parent).is_empty() or part.has("frames"): continue
		pixels[part.id] = _pixels_of(part)
		rest[part.id] = _cover(pixels[part.id], Transform2D.IDENTITY, rig.by_id[str(part.parent)])
	var worst: Dictionary = {}
	for entry: Array in _art_poses(rig):
		var frames := _frames(rig, RigPoses.pose(rig, entry[1]))
		for id: String in rest:
			if int(rest[id]) <= 0: continue
			var parent := str(rig.by_id[id].parent)
			var kept := _cover(pixels[id], Transform2D(frames[parent]).affine_inverse() * Transform2D(frames[id]), rig.by_id[parent])
			var share := float(kept) / float(rest[id])
			if not worst.has(id) or share < float(worst[id][0]): worst[id] = [share, kept, entry[0]]
	var listed: Array = []
	for id: String in worst: listed.append("%s %.2f" % [id, worst[id][0]])
	print("joints %s: lowest share of the rest overlap kept: %s" % [label, ", ".join(listed)])
	for id: String in rest:
		check(int(rest[id]) > 0, "%s: %s overlaps its parent at rest (%d px)" % [label, id, rest[id]])
		if worst.has(id): check(float(worst[id][0]) >= float(JOINT_HOLD_EXCEPT.get(id, JOINT_HOLD)) and int(worst[id][1]) >= 1, "%s: the %s joint holds (%.2f of %d px kept at %s)" % [label, id, worst[id][0], rest[id], worst[id][2]])
	check(rest.has("tail_5") and worst.has("tail_5") and float(worst.tail_5[0]) >= 0.5, "%s: the tail club stays on the tail (tail_5 keeps %.2f)" % [label, float(worst.get("tail_5", [0.0])[0])])


## Nothing but the head's own parts is layered over the head (and its eye):
## every part above the head's z hangs on the head.
func _test_nothing_over_the_head(rig: Dictionary) -> void:
	var head_z := int(rig.by_id.head.z)
	var over: Array = []
	for part: Dictionary in rig.parts:
		if int(part.z) <= head_z: continue
		var at := str(part.parent)
		var on_head := false
		while rig.by_id.has(at):
			if at == "head": on_head = true
			at = str(rig.by_id[at].parent)
		if not on_head: over.append(part.id)
	check(over.is_empty(), "%s: only the head's own parts lie over the head (%s)" % [_label(rig), over])


## Share of a wing's pixels it may cover of the head beyond its rest overlap.
## The pixel grid alone moves the count by about 1 % (drache4's far wing lifted
## 0.15 rad off a head at rest covers 14 px more, 1.1 %), so 2 % is the
## smallest bound above that noise; the rearing head this check exists for
## pushed 547 px (+193, 15 %) into that wing before the fix.
const WING_COVER := 0.02
## The wings never swing into the head: in every sampled pose a wing's own
## turn stays inside its swing range, and the posed wing covers no more of the
## POSED head, horns and jaw (each sampled in its own frame, so a rearing or
## nodding head counts) than the rest pose does (+WING_COVER of its pixels, at
## least 4). In flight both wings lift together (their centres rise and fall
## in step), whichever side of its pivot each membrane spreads to.
func _test_wings_clear_the_head(rig: Dictionary) -> void:
	if not rig.by_id.has("wing_far"): return
	var label := _label(rig)
	var head_parts: Array = []
	for id: String in ["head", "horns", "jaw"]:
		if rig.by_id.has(id): head_parts.append(rig.by_id[id])
	var poses: Array = []
	for entry: Array in _art_poses(rig):
		var pose: Dictionary = RigPoses.pose(rig, entry[1])
		poses.append([entry[0], pose, _frames(rig, pose)])
	for id: String in ["wing_far", "wing_near"]:
		var wing: Dictionary = rig.by_id[id]
		var pixels := _pixels_of(wing)
		var rest := 0
		for part: Dictionary in head_parts: rest += _cover(pixels, Transform2D.IDENTITY, part)
		var allowed: int = rest + maxi(4, roundi(pixels.size() * WING_COVER))
		var swing: Vector2 = wing.get("swing", Vector2(-PI, PI))
		var lo := INF
		var hi := -INF
		var most := 0
		var most_at := ""
		for entry: Array in poses:
			var turn := float(_state(entry[1], id).rot)
			lo = minf(lo, turn)
			hi = maxf(hi, turn)
			var frames: Dictionary = entry[2]
			var n := 0
			for part: Dictionary in head_parts:
				n += _cover(pixels, Transform2D(frames[part.id]).affine_inverse() * Transform2D(frames[id]), part)
			if n > most:
				most = n
				most_at = entry[0]
		print("wings %s %s: turns %.2f..%.2f rad (swing %.2f..%.2f), covers at most %d px of the posed head (rest %d, allowed %d, %s)" % [label, id, lo, hi, swing.x, swing.y, most, rest, allowed, most_at])
		check(lo >= swing.x - 1e-4 and hi <= swing.y + 1e-4, "%s: %s turns inside its swing (%.3f..%.3f in %.3f..%.3f)" % [label, id, lo, hi, swing.x, swing.y])
		check(most <= allowed, "%s: %s never swings into the posed head (%d px over it at %s, rest %d, %d allowed)" % [label, id, most, most_at, rest, allowed])
	var flying := _sample(rig, 0.0, 2.0, "fly")
	var r := _pearson(flying.parts.wing_far.cy, flying.parts.wing_near.cy)
	print("wings %s: in flight the wing centres rise and fall together (r %.2f)" % [label, r])
	check(r > 0.5, "%s: in flight both wings lift together (r %.2f)" % [label, r])
	_test_full_beat(rig, flying)
	_test_wings_lift(rig)


## In flight every wing moves through its whole beat: its turn spans at least
## 0.45 rad and it spends at most 25 % of the time within 0.01 rad of either
## end of that span (a sine of 0.275 rad, form 4's far wing, dwells there 17 %
## of a beat; one half-clipped at a swing limit parks there for half of it).
func _test_full_beat(rig: Dictionary, flying: Dictionary) -> void:
	for id: String in ["wing_far", "wing_near"]:
		var rot: PackedFloat64Array = flying.parts[id].rot
		var lo := INF
		var hi := -INF
		for v in rot:
			lo = minf(lo, v)
			hi = maxf(hi, v)
		var parked := 0
		for v in rot:
			if v - lo < 0.01 or hi - v < 0.01: parked += 1
		var share := float(parked) / float(rot.size())
		print("wings %s %s in flight: turn %.2f..%.2f rad, %.0f %% of the time within 0.01 rad of an end" % [_label(rig), id, lo, hi, share * 100.0])
		check(hi - lo >= 0.45 and share <= 0.25, "%s: %s beats through its whole range in flight (span %.2f rad, parked %.0f %%)" % [_label(rig), id, hi - lo, share * 100.0])


## The take-off's windup ("crouch with the wings raised high") lifts every
## wing: its tip (the wing pixel farthest from the pivot) ends the windup
## higher in the figure's frame than it starts, from every idle moment, and
## the take-off pushes off with a downstroke (the tip drops right after the
## windup). The roar's windup ("rear up with the wings raised") lifts the near
## wing and lowers none: form 3's far wing rises behind the head, which rears
## into exactly that space, so it holds there.
func _test_wings_lift(rig: Dictionary) -> void:
	for id: String in ["wing_far", "wing_near"]:
		var wing: Dictionary = rig.by_id[id]
		var tip: Vector2 = wing.pivot
		for c: Vector2 in _pixels_of(wing):
			if c.distance_to(wing.pivot) > tip.distance_to(wing.pivot): tip = c
		for clip: String in ["roar", "flight"]:
			var w_end := float(RigPoses.DRAKE_WINDOWS[clip][0])
			var worst := INF
			for t0: float in WINDUP_STARTS:
				var at := func(u: float) -> float:
					var pose: Dictionary = RigPoses.pose(rig, _actor(t0 + u * CLIP_SECONDS, false, false, clip, u))
					return (_frame_of(rig, pose, id, {}) * tip).y
				worst = minf(worst, float(at.call(0.0)) - float(at.call(w_end)))
				if clip == "flight":
					var drop := float(at.call(w_end + RigPoses.DRAKE_PUSH)) - float(at.call(w_end))
					check(drop > 2.0, "%s: the take-off pushes off with a downstroke of %s from t0 %.1f s (tip drops %.1f px)" % [_label(rig), id, t0, drop])
			print("wings %s %s: the %s windup lifts the tip by at least %.1f src px" % [_label(rig), id, clip, worst])
			if clip == "roar" and id == "wing_far":
				check(worst > -0.5, "%s: the roar windup does not lower %s (tip rises %.1f px)" % [_label(rig), id, worst])
			else:
				check(worst > 2.0, "%s: the %s windup lifts %s (tip rises %.1f px)" % [_label(rig), clip, id, worst])


## The data the wing poses rest on (hell_rigs.json via RigLibrary): form 4's
## far wing spreads right of its pivot beside the head (flap -1) and may barely
## turn toward it; every other wing lifts with a clockwise turn (flap 1).
func _test_wing_data(library) -> void:
	for variant: String in ["3", "4"]:
		var rig: Dictionary = library.rig("drache" + variant)
		if rig.is_empty(): continue
		for id: String in ["wing_far", "wing_near"]:
			var wing: Dictionary = rig.by_id.get(id, {})
			var expected := -1.0 if variant == "4" and id == "wing_far" else 1.0
			check(is_equal_approx(float(wing.get("flap", 0.0)), expected) and wing.get("swing") is Vector2 and Vector2(wing.swing).x <= 0.0 and Vector2(wing.swing).y >= 0.0,
				"drache%s %s: flap %s and a swing range around 0 (%s, %s)" % [variant, id, expected, wing.get("flap"), wing.get("swing")])
	var far4: Dictionary = library.rig("drache4").by_id.get("wing_far", {})
	check(far4.get("swing") is Vector2 and Vector2(far4.swing).y <= 0.1 and Vector2(far4.swing).x <= -0.6, "drache4 wing_far: barely any turn toward the head, a full lift away from it (%s)" % far4.get("swing"))


func _finite(pose: Dictionary) -> bool:
	for key: String in pose.whole:
		if key != "pivot" and not is_finite(float(pose.whole[key])): return false
	for id: String in pose.parts:
		for key: String in pose.parts[id]:
			if not is_finite(float(pose.parts[id][key])): return false
	for id: String in pose.get("glow", {}):
		if not is_finite(float(pose.glow[id])): return false
	for id: String in pose.get("frames", {}):
		if not (pose.frames[id] is int): return false
	return true


func _fmt(values: Array) -> String:
	var out: Array = []
	for v in values: out.append("%.3f" % float(v))
	return "[" + ", ".join(out) + "]"
