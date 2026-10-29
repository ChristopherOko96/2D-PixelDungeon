extends RefCounted
## Runtime of the hell monsters for hell_game.gd: spawning a floor's roster and
## boss, movement per AI, every attack kind with its floor warning, enemy shots,
## and Ignaroth's four phases (arrival by flight or from the floor, burrowing,
## flights in which he cannot be hit, breath sweeps, the echoes of his earlier
## forms, the change into his next form on floors 3, 6 and 9, and his death on 10).
## Monster data and sprite atlases come from tools/hell_dungeon/export_monsters.js.

const Rules = preload("res://src/hell/hell_monster_rules.gd")
const HeroKit = preload("res://src/hell/hero_kit.gd")
const DATA_PATH := "res://assets/data/hell_monsters.json"
const SPRITE_DIR := "res://assets/sprites/hell/monsters/"
## Shot colours: core, middle, rim.
const SHOT_COL := {
	"fire": [Color8(255, 200, 200), Color8(230, 40, 30), Color8(120, 0, 0)],
	"void": [Color8(240, 200, 255), Color8(170, 70, 230), Color8(60, 10, 120)],
	"soul": [Color8(220, 255, 200), Color8(90, 200, 70), Color8(10, 70, 20)],
	"lava": [Color8(255, 240, 180), Color8(255, 140, 30), Color8(140, 40, 0)],
	"chain": [Color8(230, 240, 255), Color8(120, 150, 190), Color8(40, 50, 70)],
}
const LAVA_LOBBERS := ["kesselbrut", "glutwaechter"]
const PUDDLE_SLAMMERS := ["magmaschleim", "glutwaechter"]

var g: Node
var defs: Dictionary = {}
var floors: Dictionary = {}
var cfg: Dictionary = {}
var atlas: Dictionary = {}
var zones: Array = []
var lobs: Array = []
var corpses: Array = []


## game: the hell game node; cfg: the "monsters" block of hell_balance.json.
func _init(game: Node, monster_cfg: Dictionary) -> void:
	g = game
	cfg = monster_cfg
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	defs = data.defs
	floors = data.floors
	# experience per kill for the hero's levels (hero_kit.gd reads def.exp)
	var exp: Dictionary = cfg.get("exp", {})
	for id: String in defs:
		defs[id].exp = int(exp.get(id, 0))
	for id: String in defs:
		atlas[id] = load(SPRITE_DIR + id + ".png")


## Drops every attack effect (death, pit, new floor).
func reset() -> void:
	zones = []
	lobs = []
	corpses = []


## Monster id of the boss on floor n.
func boss_id(n: int) -> String:
	return String(floors[str(n)].boss)


## True while the monster cannot be hit.
func immune(m: Dictionary) -> bool:
	return Rules.is_immune(m, float(cfg.immune_altitude))


## Health-bar text for a boss: its name and what it is doing.
func boss_label(m: Dictionary) -> String:
	return String(m.def.name) + Rules.boss_status(m, float(cfg.immune_altitude))


# ---------- spawning ----------

## Adds monster id at pos to room; a boss takes the floor's boss HP.
func spawn(room: int, pos: Vector2, id: String, boss := false) -> Dictionary:
	var def: Dictionary = defs[id]
	var st: Dictionary = def.stats
	var hp := Rules.spawn_hp(st, boss, float(g.W.boss.hp), float(g.W.diff.hp))
	var cds: Array = []
	for a: Dictionary in st.attacks:
		cds.append(Rules.first_cooldown(a, randf()))
	var m := {"room": room, "id": id, "def": def, "st": st, "boss": boss, "kind": "boss" if boss else "mob", "p": pos,
		"hp": hp, "max": hp, "sp": float(st.speed) * (1.0 if boss else float(g.W.diff.speed)), "s": float(def.scale),
		"r": float(st.r), "cy": float(def.h) * float(def.scale) * 0.45, "seed": randf() * 9.0, "k": Vector2.ZERO,
		"hit": 0.0, "spawn": float(cfg.spawn_grow), "act": null, "anim": "idle", "at": 0.0, "face": 1.0, "alpha": 1.0,
		"hop_t": randf(), "cds": cds, "alt": 0.0, "sink": 0.0, "burrowed": false, "intro": null, "trans": null,
		"dying": null, "circ": 1.0, "landed": false, "trail": 0.0}
	g.mobs.append(m)
	return m


## A free floor spot of room between min_d and max_d from near; near itself if none is found.
func free_spot(room: int, near: Vector2, min_d: float, max_d: float) -> Vector2:
	for k in range(40):
		var p := near + Vector2.from_angle(randf() * TAU) * randf_range(min_d, max_d)
		if g._room_at_world(p.x, p.y) == room and g._cell(int(floor(p.x / g.C)), int(floor(p.y / g.C))) == 1 \
				and not g.box_blocked(Rect2(p.x - 30, p.y - 30, 60, 30), true):
			return p
	return near


## Fills a room whose fight starts: the floor's roster on the given free cells,
## and in the boss room the floor's boss (Ignaroth arrives with his intro).
func populate(r: Dictionary, cells: Array) -> void:
	var roster: Array = floors[str(g.state.floor)].mobs
	var first := randi() % roster.size()
	var count: int = int(r.mobs if r.mobs > 0 else 3) + int(g.W.diff.extra)
	for k in range(mini(count, cells.size())):
		spawn(r.index, cells[k], roster[(first + k) % roster.size()])
	if r.type != "boss":
		g._toast("Die Gitter fallen. Besiege alle Gegner.")
		return
	var b := spawn(r.index, Vector2((r.bx + r.bw / 2.0) * g.C, (r.by + r.bh / 2.0 + 1.0) * g.C), boss_id(g.state.floor), true)
	if Rules.is_lord(b.def):
		b.spawn = 0.0
		start_intro(b)
		g._toast("Ein Schatten über der Arena …" if b.st.get("intro", "") == "flyin" else "Der Boden glüht …")
	else:
		g._toast("%s erwacht. Die Tore sind verriegelt." % b.def.name)


# ---------- update ----------

func _me() -> Vector2:
	return Vector2(g.player.x, g.player.y)


func _hurt_by(m: Dictionary, n: int, how: String) -> void:
	g._hurt("von %s %s" % [m.def.name, how], n)


func _shake(n: float) -> void:
	g.state.shake = maxf(float(g.state.get("shake", 0.0)), n)


func _shot(from: Vector2, dir: Vector2, speed: float, extra := {}) -> void:
	var s := {"p": from, "v": dir.normalized() * speed, "t": 2.6, "c": "fire"}
	s.merge(extra, true)
	g.eshots.append(s)


func _zone(z: Dictionary) -> void:
	var base := {"t": 0.0, "tele": 0.0, "dmg": 0, "done": false}
	base.merge(z, true)
	zones.append(base)


## Moves, aims and attacks every monster, ends Ignaroth's phases, removes the dead
## and clears a room when its last monster falls.
func update(dt: float) -> void:
	var me := _me()
	for m: Dictionary in g.mobs:
		if m.spawn > 0.0:
			m.spawn -= dt
			continue
		m.hit = maxf(0.0, m.hit - dt)
		m.at += dt
		if m.has("echo"):
			m.echo -= dt
			if m.echo <= 0.0 and m.hp > 0.0:
				m.hp = 0.0
				m.quiet = true
				g._burst(m.p - Vector2(0, m.cy), 24)
		var lord := Rules.is_lord(m.def)
		if lord and m.boss and m.hp <= 0.0 and m.trans == null and m.dying == null:
			_start_lord_end(m)
		if m.intro != null:
			_update_intro(m, dt)
			continue
		if m.trans != null or m.dying != null:
			_update_lord_end(m, dt)
			if m.anim != m.get("last_anim", ""):
				m.last_anim = m.anim
				m.at = 0.0
			continue
		for i in range(m.cds.size()):
			m.cds[i] -= dt
		# hero skills: slows, burns and stuns tick here; a stunned or held monster waits
		var pace := HeroKit.tick_mob(g, m, dt)
		var held: bool = pace <= 0.0 or m.get("hold", false)
		var to: Vector2 = me - m.p
		var d := maxf(to.length(), 1.0)
		var v := Vector2.ZERO
		if m.act != null:
			_run_act(m, dt)
			if m.act != null:
				v = m.act.get("v", Vector2.ZERO)
		else:
			var i := -1 if g.state.dead > 0.0 or held else Rules.pick_attack(m.st.attacks, m.cds, d)
			if i >= 0:
				_start_act(m, i, to, d)
			else:
				v = _move(m, dt, to, d)
		var act = m.act
		var locked: bool = act != null and ((act.kind == "dash" and not act.get("warn", false)) or act.kind == "sweep")
		if not locked and absf(to.x) > (float(cfg.lord_face_deadzone) if lord else 10.0):
			m.face = signf(to.x)
		for o: Dictionary in g.mobs:
			if o != m:
				var off: Vector2 = m.p - o.p
				var od := off.length()
				if od > 0.0 and od < (m.r + o.r) * 0.8:
					v += off / od * 120.0
		v *= 0.0 if held else pace
		v += m.k
		m.k *= 0.86
		var moved_from: Vector2 = m.p
		var rr := minf(m.r * 0.7, 40.0)
		var avoid: bool = not m.boss and m.st.ai != "hover" and m.st.ai != "drift"
		var nx: float = m.p.x + v.x * dt
		if not g.box_blocked(Rect2(nx - rr, m.p.y - rr, rr * 2.0, rr), avoid) and not HeroKit.wall_blocks(g, Vector2(nx, m.p.y), rr):
			m.p = Vector2(nx, m.p.y)
		var ny: float = m.p.y + v.y * dt
		if not g.box_blocked(Rect2(m.p.x - rr, ny - rr, rr * 2.0, rr), avoid) and not HeroKit.wall_blocks(g, Vector2(m.p.x, ny), rr):
			m.p = Vector2(m.p.x, ny)
		# a body thrown by Rage slams into the wall it meets (src/hero/story_hero.gd)
		if g.story_hero != null:
			g.story_hero.check_slam(m, moved_from, dt)
		act = m.act
		var airborne: bool = act != null and float(act.get("air", 0.0)) > 20.0
		if d < m.r + float(cfg.contact_reach) and m.alpha > 0.6 and not immune(m) and not airborne:
			_hurt_by(m, 1, "erschlagen" if m.boss else "erwischt")
		var want: String = act.anim if act != null else ("run" if v.length() > 20.0 else "idle")
		if want != m.anim:
			m.anim = want
			m.at = 0.0
	for m: Dictionary in g.mobs.duplicate():
		var lord_boss: bool = Rules.is_lord(m.def) and m.boss
		if not ((m.hp <= 0.0 and not lord_boss) or m.get("remove", false)):
			continue
		if m.dying != null or (m.trans == null and not m.has("echo")):
			corpses.append({"id": m.id, "p": m.p, "s": m.s, "face": m.face, "t": 0.0})
		if m.trans == null and not m.get("quiet", false):
			g._burst(m.p - Vector2(0, m.cy), 80 if m.boss else 18)
		# experience: felled monsters and a defeated boss form; echoes and swept-away adds give none
		if not m.get("quiet", false) and not m.has("echo"):
			HeroKit.gain(g, HeroKit.exp_for(g, m))
			g._sound("kill_" + str(m.def.get("material", "void")))
		g.mobs.erase(m)
		var rest: Array = g.mobs.filter(func(o: Dictionary) -> bool: return o.room == m.room and o.hp > 0.0 and not o.get("remove", false))
		if rest.is_empty():
			if m.boss:
				g.eshots.clear()
				zones.clear()
				lobs.clear()
			g._clear_room(g.W.rooms[m.room], m.p)
	_update_zones(dt)


func _move(m: Dictionary, dt: float, to: Vector2, d: float) -> Vector2:
	var n := to / d
	var side := Vector2(-n.y, n.x)
	var t: float = g.state.t
	var wob: float = sin(t * 3.0 + m.seed) * 0.7
	var v := Vector2.ZERO
	match String(m.st.ai):
		"hover":
			var a: float = t * 1.6 + m.seed
			var aim: Vector2 = _me() + Vector2(cos(a) * 190.0, -40.0 + sin(a) * 140.0) - m.p
			v = aim.normalized() * m.sp
		"keep":
			var k := float(m.st.get("keep", 380.0))
			var dir := -1.0 if d < k * 0.8 else (1.0 if d > k * 1.2 else 0.0)
			v = (n * dir + side * (wob * 0.4 if dir != 0.0 else 1.0)) * m.sp
		"hop":
			m.hop_t += dt
			var ph := fmod(float(m.hop_t), 1.1)
			if ph < 0.45:
				v = n * m.sp * 2.3
			elif ph < 0.45 + dt and not m.landed:
				m.landed = true
				_zone({"kind": "puddle", "p": m.p, "r": 40.0, "T": 1.6, "dmg": 1, "m": m})
			if ph > 0.5:
				m.landed = false
		"skirmish":
			if randf() < dt * 0.5:
				m.circ = -m.circ
			var k := 1.0 if d > 230.0 else (-1.0 if d < 230.0 * 0.7 else 0.0)
			v = (n * k + side * m.circ * (0.5 if k != 0.0 else 1.0)) * m.sp
		"drift":
			v = (n * 0.7 + side * sin(t + m.seed)) * m.sp
		_:
			v = (n + side * wob) * m.sp
	if m.boss and d < m.r * 0.9:
		v *= 0.2
	return v


func _start_act(m: Dictionary, i: int, to: Vector2, d: float) -> void:
	var a: Dictionary = m.st.attacks[i]
	m.cds[i] = Rules.next_cooldown(a, m.boss, randf())
	var act := {"a": a, "kind": a.kind, "t": 0.0, "dir": to / d, "n": 0, "anim": Rules.act_anim(a.kind, m.def), "v": Vector2.ZERO}
	if a.kind == "slam" and a.get("leap", false):
		act.leap = {"from": m.p, "to": _me()}
	if a.kind == "beam":
		var b0 := to.angle()
		var beams: Array = []
		for k in range(int(a.beams)):
			beams.append(b0 + float(k) / float(a.beams) * TAU)
		act.beams = beams
	m.act = act


## Distance from a point along a direction until a wall, at most max_len.
func _wall_len(from: Vector2, ang: float, max_len: float) -> float:
	var l := 0.0
	while l < max_len:
		var p := from + Vector2.from_angle(ang) * l
		if not g._walkable(g._cell(int(floor(p.x / g.C)), int(floor(p.y / g.C)))):
			return l
		l += 24.0
	return max_len


func _run_act(m: Dictionary, dt: float) -> void:
	var A: Dictionary = m.act
	var a: Dictionary = A.a
	A.t += dt
	var t: float = A.t
	var head: Vector2 = m.p - Vector2(0, m.cy)
	var me := _me()
	var dmg := int(cfg.hit_boss) if m.boss else int(cfg.hit_mob)
	var color := Rules.shot_color(m.id, m.has("echo"))
	if A.kind in Rules.DRAGON_KINDS:
		_run_dragon_act(m, dt)
		return
	match String(A.kind):
		"dash":
			if t < 0.5:
				var aim: Vector2 = me - m.p
				if aim.length() > 0.0:
					A.dir = aim.normalized()
				A.v = Vector2.ZERO
				A.warn = true
				return
			A.warn = false
			A.v = A.dir * float(a.speed)
			if t > 0.5 + minf(0.55, float(a.get("range", 500.0)) / float(a.speed)):
				if int(A.get("rep", 1)) < int(a.get("repeat", 1)):
					A.rep = int(A.get("rep", 1)) + 1
					A.t = 0.3
				else:
					m.act = null
			return
		"lob":
			if t >= 0.45 and A.n == 0:
				A.n = 1
				for k in range(int(a.get("count", 1))):
					var aim := me + (Vector2(randf_range(-130, 130), randf_range(-100, 100)) if k > 0 else Vector2.ZERO)
					lobs.append({"from": head, "to": aim, "t": 0.0, "T": 0.8 + k * 0.12, "r": float(a.get("radius", 70.0)),
						"dmg": dmg, "m": m, "c": "lava" if m.id in LAVA_LOBBERS else "fire", "done": false})
			if t > 0.7:
				m.act = null
			return
		"bolt", "breath", "homing":
			var wind := 0.3 if A.kind == "breath" else 0.35
			if t >= wind and A.n == 0:
				A.n = 1
				var base := (me - Vector2(0, 30) - head).angle()
				var heads := int(a.get("heads", 1))
				var count := int(a.get("count", 1))
				var spread := 0.7 if A.kind == "breath" else float(a.get("spread", 0.3))
				for h in range(heads):
					for k in range(count):
						var ang := base + ((h - 1) * 0.45 if heads > 1 else 0.0) + ((float(k) / (count - 1) - 0.5) * spread if count > 1 else 0.0)
						if A.kind == "breath":
							ang += randf_range(-0.075, 0.075)
							_shot(head + Vector2(m.face * m.r * 0.6, 0), Vector2.from_angle(ang), 380.0 + randf() * 140.0,
								{"t": float(a.get("range", 260.0)) / 450.0, "small": true})
						elif A.kind == "homing":
							var fan := (k - (count - 1) / 2.0) * 0.6
							_shot(head - Vector2(0, 20), Vector2.from_angle(ang + fan), float(a.get("speed", 250.0)), {"t": 4.5, "homing": 2.2, "c": color})
						else:
							_shot(head, Vector2.from_angle(ang), float(a.get("speed", 500.0)), {"c": color})
			if t > wind + 0.3:
				m.act = null
			return
		"ring":
			var waves := int(a.get("waves", 1))
			if t >= 0.45 + A.n * 0.35 and A.n < waves:
				var off: float = A.n * PI / float(a.count) + g.state.t * 0.2
				for k in range(int(a.count)):
					_shot(head, Vector2.from_angle(off + float(k) / float(a.count) * TAU), float(a.get("speed", 280.0)),
						{"c": "void" if a.get("void", false) else color})
				A.n += 1
			if t > 0.55 + waves * 0.35:
				m.act = null
			return
		"spiral":
			A.spin = float(A.get("spin", randf() * 6.0)) + dt * 2.4
			A.acc = float(A.get("acc", 0.0)) + dt
			var arms := int(a.arms)
			while A.acc > float(a.rate) and t > 0.4:
				A.acc -= float(a.rate)
				for k in range(arms):
					var turn := (-1.0 if k % 2 == 1 else 1.0) * (-1.0 if arms > 2 and k >= 2 else 1.0)
					_shot(head, Vector2.from_angle(turn * A.spin + float(k) / arms * TAU), float(a.get("speed", 280.0)), {"c": color})
			if t > 0.4 + float(a.duration):
				m.act = null
			return
		"slam":
			var leap: bool = A.has("leap")
			if leap:
				var L: Dictionary = A.leap
				var k := minf(1.0, t / 0.7)
				if k < 1.0:
					A.air = sin(k * PI) * 120.0
					var np: Vector2 = L.from.lerp(L.to, k)
					if not g.box_blocked(Rect2(np.x - m.r * 0.5, np.y - m.r * 0.5, m.r, m.r * 0.5), false):
						m.p = np
					A.warn_at = L.to
					return
				A.air = 0.0
			if A.n == 0 and t >= (0.7 if leap else 0.75):
				A.n = 1
				if a.get("line", false):
					_zone({"kind": "line", "p": m.p, "ang": (me - m.p).angle(), "len": float(a.radius) * 2.6, "w": 70.0, "tele": 0.45, "T": 0.8, "dmg": dmg, "m": m})
				else:
					_zone({"kind": "wave", "p": m.p, "r": float(a.radius), "T": 0.5, "dmg": dmg, "m": m, "c": "lava" if m.id == "magmaschleim" else "fire"})
				g._burst(m.p - Vector2(0, 10), 50 if m.boss else 16)
				if m.id in PUDDLE_SLAMMERS:
					_zone({"kind": "puddle", "p": m.p, "r": 120.0 if m.boss else 52.0, "T": 2.6, "dmg": 1, "m": m})
			if A.n == 0 and not leap:
				A.warn_at = m.p
			if t > (1.1 if leap else 1.05):
				if leap and int(A.get("rep", 1)) < int(a.get("repeat", 1)):
					A.rep = int(A.get("rep", 1)) + 1
					A.t = 0.0
					A.n = 0
					A.leap = {"from": m.p, "to": me}
				else:
					m.act = null
			return
		"swing":
			if t >= 0.35 and A.n == 0:
				A.n = 1
				_zone({"kind": "arc", "p": m.p - Vector2(0, m.cy * 0.5), "r": float(a.radius), "ang": (me - m.p).angle(), "arc": float(a.arc), "T": 0.25, "dmg": dmg, "m": m})
			if t > 0.6:
				m.act = null
			return
		"summon":
			if t >= 0.6 and A.n == 0:
				A.n = 1
				var here: int = g.mobs.filter(func(o: Dictionary) -> bool: return o.room == m.room and not o.boss).size()
				for id: String in a.mobs:
					if here < int(a.get("max", 4)) + 1:
						var p := free_spot(m.room, m.p, 90, 200)
						var s := spawn(m.room, p, id)
						s.spawn = 0.8
						g._burst(p - Vector2(0, 20), 14)
			if t > 0.9:
				m.act = null
			return
		"teleport":
			if t < 0.35:
				m.alpha = 1.0 - t / 0.35
				return
			if A.n == 0:
				A.n = 1
				g._burst(head, 18)
				m.p = free_spot(m.room, me, 170, 260)
			m.alpha = minf(1.0, (t - 0.35) / 0.3)
			if t > 0.7:
				m.alpha = 1.0
				m.act = null
			return
		"meteors", "hands":
			if t >= 0.5 and A.n == 0:
				A.n = 1
				var meteor: bool = A.kind == "meteors"
				for k in range(int(a.count)):
					var p := me if k == 0 else me + Vector2(randf_range(-260, 260), randf_range(-190, 190))
					_zone({"kind": "meteor" if meteor else "hand", "p": p, "r": float(a.radius), "t": -k * 0.12,
						"tele": 1.0 if meteor else 0.85, "T": 1.35 if meteor else 1.25, "dmg": dmg, "m": m})
			if t > 0.8:
				m.act = null
			return
		"chain":
			if t >= 0.35 and A.n == 0:
				A.n = 1
				var sp := float(a.get("speed", 700.0))
				_shot(head, me - Vector2(0, 30) - head, sp, {"chain": m, "c": "chain", "t": float(a.get("range", 600.0)) / sp})
			if t > 0.7:
				m.act = null
			return
		"scream":
			if A.n == 0 and t > 0.1:
				A.n = 1
				_zone({"kind": "cone", "p": head + Vector2(0, 20), "ang": (me - head).angle(), "r": float(a.range), "arc": float(a.arc),
					"tele": 0.55, "T": 0.9, "dmg": 1, "slow": 2.0, "m": m})
			if t > 1.0:
				m.act = null
			return
		"beam":
			if t < 0.8:
				A.warn = true
				return
			A.warn = false
			for k in range(A.beams.size()):
				A.beams[k] += float(a.turn) * dt
			var rel: Vector2 = me - Vector2(0, 30) - head
			for b: float in A.beams:
				var dir := Vector2.from_angle(b)
				var along := rel.dot(dir)
				if along > 0.0 and along < _wall_len(head, b, 1100.0) and absf(dir.cross(rel)) < 36.0:
					_hurt_by(m, 1, "verbrannt")
			if t > 0.8 + float(a.duration):
				m.act = null
			return
	m.act = null


# ---------- Ignaroth ----------

## Starts the boss arrival: a long swoop from the sky, or a burst out of the floor.
func start_intro(m: Dictionary) -> void:
	var kind := String(m.st.get("intro", "burrow"))
	m.intro = {"kind": kind, "t": 0.0}
	if kind == "flyin":
		m.intro.to = m.p
		m.alt = 900.0
		m.p = m.p - Vector2(700, 0)
		m.anim = "fly"
	else:
		m.burrowed = true
		m.sink = 1.0


func _update_intro(m: Dictionary, dt: float) -> void:
	var I: Dictionary = m.intro
	I.t += dt
	var t: float = I.t
	if I.kind == "flyin":
		# a long swoop in from above; the shadow grows on the floor, then a heavy landing
		var k := Rules.smooth(minf(1.0, t / 2.4))
		m.p = Vector2(I.to.x - 700.0 * (1.0 - k), I.to.y - 140.0 * sin(k * PI) * (1.0 - k))
		m.alt = 900.0 * pow(1.0 - k, 1.6)
		m.anim = "fly"
		if t > 0.2 and randf() < 0.3:
			g.embers.append({"p": m.p + Vector2(randf_range(-60, 60), -m.alt - m.cy), "v": Vector2(-80, 40), "t": 0.8, "big": true, "gold": false})
		if t >= 2.4 and not I.get("landed", false):
			I.landed = true
			m.alt = 0.0
			_shake(14)
			g._burst(m.p, 60)
			_zone({"kind": "wave", "p": m.p, "r": 380.0, "T": 0.6, "m": m, "c": "void" if m.id == "drache4" else "fire"})
		if t >= 2.4:
			m.anim = "cast"
		if t >= 3.4:
			m.intro = null
			m.anim = "idle"
			m.at = 0.0
			g._toast("%s greift an!" % m.def.name)
		return
	# phase 1 and 2: a glowing crack, then he bursts out of the floor
	if t < 1.1:
		m.burrowed = true
		if randf() < 0.5:
			g._burst(m.p + Vector2(randf_range(-30, 30), 0), 2)
		return
	if not I.get("out", false):
		I.out = true
		m.burrowed = false
		_shake(10)
		g._burst(m.p - Vector2(0, 10), 50)
		_zone({"kind": "wave", "p": m.p, "r": 260.0, "T": 0.45, "m": m, "c": "lava"})
	m.sink = maxf(0.0, 1.0 - (t - 1.1) / 0.35)
	m.anim = "cast"
	if t >= 2.2:
		m.intro = null
		m.sink = 0.0
		m.anim = "idle"
		m.at = 0.0
		g._toast("%s greift an!" % m.def.name)


func _run_dragon_act(m: Dictionary, dt: float) -> void:
	var A: Dictionary = m.act
	var a: Dictionary = A.a
	var t: float = A.t
	var me := _me()
	var dmg := int(cfg.hit_boss)
	match String(A.kind):
		"burrow":
			if t < 0.55:
				A.anim = "cast"
				m.sink = Rules.smooth(t / 0.55)
				if randf() < 0.6:
					g._burst(m.p + Vector2(randf_range(-25, 25), 0), 2)
				return
			if not A.get("under", false):
				A.under = true
				m.burrowed = true
				A.anim = "idle"
			if not A.has("warn_t"):
				var to: Vector2 = me - m.p
				var d := maxf(to.length(), 1.0)
				A.v = to / d * float(cfg.burrow_speed)
				m.trail += dt
				if m.trail > 0.05:
					m.trail = 0.0
					g._burst(m.p, 1)
				if d < 40.0 or t > 2.6:
					A.warn_t = t
					A.v = Vector2.ZERO
					_zone({"kind": "erupt", "p": m.p, "r": float(a.radius), "tele": 0.5, "T": 0.75, "dmg": dmg, "m": m})
				return
			A.v = Vector2.ZERO
			if t - A.warn_t >= 0.5 and not A.get("out", false):
				A.out = true
				m.burrowed = false
				_shake(12)
				g._burst(m.p - Vector2(0, 20), 40)
				for k in range(int(a.ring)):
					_shot(m.p - Vector2(0, m.cy), Vector2.from_angle(float(k) / float(a.ring) * TAU), 330.0)
				if a.get("lava", false):
					for k in range(4):
						var ang := k / 4.0 * TAU + 0.4
						_zone({"kind": "puddle", "p": m.p + Vector2(cos(ang) * 120.0, sin(ang) * 80.0), "r": 60.0, "T": 3.0, "dmg": 1, "m": m})
			if A.get("out", false):
				A.anim = "cast"
				m.sink = maxf(0.0, 1.0 - (t - A.warn_t - 0.5) / 0.3)
			if t - A.warn_t > 1.2:
				m.sink = 0.0
				m.act = null
		"flight":
			var top := float(cfg.flight_altitude)
			var T := float(a.duration)
			A.anim = "fly"
			if t < 0.7:
				m.alt = top * Rules.smooth(t / 0.7)
				A.v = Vector2.ZERO
				if t < 0.1:
					_shake(5)
				return
			if t < 0.7 + T:
				# circle above the hero and drop bombs on where he stands
				var ang: float = g.state.t * 1.3
				var aim: Vector2 = me + Vector2(cos(ang) * 260.0, sin(ang) * 160.0) - m.p
				var l := maxf(aim.length(), 1.0)
				A.v = aim / l * minf(520.0, l * 3.0)
				m.alt = top + sin(t * 3.0) * 20.0
				A.drop = float(A.get("drop", 0.0)) + dt
				if A.drop > float(a.drop):
					A.drop = 0.0
					_zone({"kind": "meteor", "p": me + Vector2(randf_range(-60, 60), randf_range(-45, 45)), "r": float(a.radius),
						"tele": 0.85, "T": 1.15, "dmg": dmg, "m": m, "void": a.get("void", false)})
				return
			if not A.has("land"):
				A.land = {"from": m.p, "to": me + Vector2(0, 10), "t0": t}
				_zone({"kind": "land", "p": me + Vector2(0, 10), "r": 260.0, "tele": 0.7, "T": 0.7, "m": m})
			var L: Dictionary = A.land
			var k := Rules.smooth((t - L.t0) / 0.7)
			A.v = Vector2.ZERO
			m.p = L.from.lerp(L.to, k)
			m.alt = top * (1.0 - k)
			if k >= 1.0:
				m.alt = 0.0
				_shake(14)
				g._burst(m.p, 50)
				_zone({"kind": "wave", "p": m.p, "r": 300.0, "T": 0.55, "dmg": dmg, "m": m, "c": "void" if a.get("void", false) else "fire"})
				m.act = null
		"sweep":
			A.anim = "attack"
			A.v = Vector2.ZERO
			if not A.has("base"):
				A.base = (me - (m.p - Vector2(0, m.cy))).angle()
				A.sign = 1.0 if randf() < 0.5 else -1.0
			if t < 0.45:
				return
			var k := minf(1.0, (t - 0.45) / float(a.duration))
			var ang: float = A.base + (k - 0.5) * float(a.arc) * A.sign
			m.face = 1.0 if cos(ang) >= 0.0 else -1.0
			A.acc = float(A.get("acc", 0.0)) + dt
			var mouth: Vector2 = m.p + Vector2(m.face * m.r * 0.95, -m.cy * 1.35)
			while A.acc > float(a.rate):
				A.acc -= float(a.rate)
				_shot(mouth, Vector2.from_angle(ang + randf_range(-0.04, 0.04)), float(a.speed) * randf_range(0.85, 1.15),
					{"c": "void" if a.get("void", false) else "fire", "small": true, "t": 1.6})
			if k >= 1.0:
				m.act = null
		"echoes":
			A.anim = "cast"
			A.v = Vector2.ZERO
			if t >= 0.8 and A.n == 0:
				A.n = 1
				_shake(8)
				var k := 0
				for id: String in _earlier_forms(m.id):
					var p := free_spot(m.room, m.p, 200, 340)
					var e := spawn(m.room, p, id, false)
					e.echo = float(a.life)
					e.hp = round(float(g.W.boss.hp) * float(cfg.echo_hp_share))
					e.max = e.hp
					e.spawn = 0.7 + k * 0.2
					var st: Dictionary = e.st.duplicate()
					st.ai = "chase"
					st.attacks = Rules.echo_attacks(st.attacks, cfg.echo_kinds)
					e.st = st
					var cds: Array = []
					for x: Dictionary in st.attacks:
						cds.append(float(x.every) * randf_range(0.4, 1.0))
					e.cds = cds
					g._burst(p - Vector2(0, 40), 30)
					k += 1
				g._toast("Ignaroth ruft die Echos seiner früheren Formen!")
			if t > 1.4:
				m.act = null
		_:
			m.act = null


## Ignaroth's forms before this one, first phase first.
func _earlier_forms(id: String) -> Array:
	var phase := int(defs[id].phase)
	var out: Array = []
	for other: String in defs:
		if Rules.is_lord(defs[other]) and int(defs[other].phase) < phase:
			out.append(other)
	out.sort_custom(func(x: String, y: String) -> bool: return int(defs[x].phase) < int(defs[y].phase))
	return out


func _set_form(m: Dictionary, id: String) -> void:
	var def: Dictionary = defs[id]
	m.id = id
	m.def = def
	m.st = def.stats
	m.s = float(def.scale)
	m.r = float(def.stats.r)
	m.cy = float(def.h) * float(def.scale) * 0.45


# At 0 HP on floors 3, 6 and 9 he changes into his next form and escapes; on 10 he dies.
func _start_lord_end(m: Dictionary) -> void:
	g.eshots.clear()
	zones = zones.filter(func(z: Dictionary) -> bool: return z.kind == "puddle")
	lobs.clear()
	m.act = null
	m.alt = 0.0
	m.sink = 0.0
	m.burrowed = false
	m.hp = 1.0
	for o: Dictionary in g.mobs:
		if o != m and o.room == m.room:
			o.hp = 0.0
			o.quiet = true
	var next := Rules.next_form(defs, m.id)
	if next != "":
		m.trans = {"t": 0.0, "next": next, "glow": 0.0, "grow": 1.0, "swapped": false}
		g._toast("%s verwandelt sich!" % m.def.name)
	else:
		m.dying = {"t": 0.0, "glow": 0.0}
		g._toast("%s wankt!" % m.def.name)


func _update_lord_end(m: Dictionary, dt: float) -> void:
	if m.trans != null:
		var T: Dictionary = m.trans
		T.t += dt
		var t: float = T.t
		m.anim = "cast" if t < 3.0 or not defs[m.id].anims.has("fly") else "fly"
		if t < 1.5:
			T.glow = 0.4 + 0.6 * absf(sin(t * (4.0 + t * 6.0)))
			if randf() < 0.8:
				var ang := randf() * TAU
				var r := 260.0
				g.embers.append({"p": m.p + Vector2(cos(ang) * r, -m.cy + sin(ang) * r * 0.6), "v": Vector2(-cos(ang) * r * 1.6, -sin(ang) * r),
					"t": 0.6, "big": false, "gold": true})
			_shake(3)
			return
		if not T.swapped:
			T.swapped = true
			_set_form(m, T.next)
			T.grow = 0.0
			g.state.white = 0.9
			_shake(18)
			g._burst(m.p - Vector2(0, m.cy), 90, true)
			_zone({"kind": "wave", "p": m.p, "r": 420.0, "T": 0.7, "m": m, "c": "void" if m.id == "drache4" else "fire"})
			g._toast("… zu %s!" % m.def.name)
		T.glow = maxf(0.0, 1.0 - (t - 1.5) * 1.5)
		T.grow = Rules.smooth((t - 1.5) / 0.6)
		if t < 3.0:
			if randf() < 0.3:
				g._burst(m.p + Vector2(randf_range(-m.r, m.r), -randf() * m.cy * 2.0), 3)
			return
		# escape: wingless forms sink into the floor, winged forms fly off upwards
		if not T.get("left", false):
			T.left = true
			g._toast("%s flieht in die Tiefe. Er kehrt zurück." % m.def.name)
		if defs[m.id].anims.has("fly"):
			m.alt = 1300.0 * pow(Rules.smooth((t - 3.0) / 1.6), 1.3)
			m.p = m.p + Vector2(160.0 * dt, 0)
		else:
			m.sink = Rules.smooth((t - 3.0) / 0.9)
			if randf() < 0.6:
				g._burst(m.p + Vector2(randf_range(-40, 40), 0), 2)
		if t > 4.7:
			m.remove = true
		return
	var D: Dictionary = m.dying
	D.t += dt
	var t: float = D.t
	m.anim = "cast"
	if t < 2.6:
		_shake(6)
	if randf() < 0.5:
		g._burst(m.p + Vector2(randf_range(-1.1, 1.1) * m.r, -randf() * m.cy * 2.2), 14, randf() < 0.4)
	D.glow = 0.3 + 0.5 * absf(sin(t * 9.0))
	if t > 2.6 and not D.get("boom", false):
		D.boom = true
		g.state.white = 1.0
		_shake(24)
		g._burst(m.p - Vector2(0, m.cy), 160, true)
		_zone({"kind": "wave", "p": m.p, "r": 600.0, "T": 1.0, "m": m, "c": "void"})
	if t > 2.8:
		m.remove = true


# ---------- zones, lobs and enemy shots ----------

func _update_zones(dt: float) -> void:
	var me := _me() - Vector2(0, 20)
	for z: Dictionary in zones:
		z.t += dt
		if z.t < z.tele or (z.done and z.kind != "puddle"):
			continue
		var d := me.distance_to(z.p)
		var hit := false
		match String(z.kind):
			"wave":
				if z.dmg > 0 and absf(d - z.r * minf(1.0, z.t / z.T)) < 40.0:
					hit = true
			"puddle":
				hit = d < z.r and g.state.inv <= 0.0
			"erupt", "land":
				hit = z.dmg > 0 and d < z.r
				z.done = true
			"arc", "cone":
				if d < z.r and Rules.angle_gap((me - z.p).angle(), z.ang) < z.arc / 2.0:
					hit = true
					if z.kind == "cone":
						g.state.slow = z.slow
				z.done = true
			"line":
				var rel: Vector2 = me - z.p
				var dir := Vector2.from_angle(z.ang)
				var along := rel.dot(dir)
				hit = along > 0.0 and along < z.len and absf(dir.cross(rel)) < z.w / 2.0
				var k := 0.0
				while k < z.len:
					g._burst(z.p + dir * k, 4)
					k += 60.0
				z.done = true
			_:
				hit = d < z.r
				g._burst(z.p - Vector2(0, 20), 26 if z.kind == "meteor" else 10)
				z.done = true
		if hit and g.state.dead <= 0.0:
			_hurt_by(z.m, int(z.dmg), "niedergeschrien" if z.kind == "cone" else "getroffen")
	zones = zones.filter(func(z: Dictionary) -> bool: return z.t < z.T)
	for L: Dictionary in lobs:
		L.t += dt
		if L.t >= L.T and not L.done:
			L.done = true
			g._burst(L.to - Vector2(0, 10), 22)
			_zone({"kind": "wave", "p": L.to, "r": L.r, "T": 0.3, "dmg": L.dmg, "m": L.m, "c": L.c})
			if L.c == "lava":
				_zone({"kind": "puddle", "p": L.to, "r": L.r * 0.6, "T": 2.2, "dmg": 1, "m": L.m})
	lobs = lobs.filter(func(L: Dictionary) -> bool: return not L.done)
	for c: Dictionary in corpses:
		c.t += dt
	corpses = corpses.filter(func(c: Dictionary) -> bool: return c.t < 0.75)


## Moves enemy shots (homing ones turn toward the hero), stops them at walls,
## hurts the hero, and drags him toward a chain's thrower.
func update_shots(dt: float) -> void:
	var me := Vector2(g.player.x, g.player.y - 34)
	for s: Dictionary in g.eshots:
		# gravity walls swallow shots, gravity bars hold them (hero_kit.gd)
		if HeroKit.catch_shot(g, s, dt) and float(s.get("held", 0.0)) > 0.0:
			continue
		if s.has("homing"):
			var a0: float = s.v.angle()
			var turn := clampf(wrapf((me - s.p).angle() - a0, -PI, PI), -s.homing * dt, s.homing * dt)
			s.v = Vector2.from_angle(a0 + turn) * s.v.length()
		s.p += s.v * dt
		s.t -= dt
		if g._cell_blocked(int(floor(s.p.x / g.C)), int(floor(s.p.y / g.C)), false):
			s.t = 0.0
			g._burst(s.p, 4)
		elif s.p.distance_to(me) < (26.0 if s.get("small", false) else float(g.balance.enemy_shot.hit_radius)):
			s.t = 0.0
			if s.has("chain"):
				g.state.pull = {"m": s.chain, "t": 0.6}
				g._hurt("von der Kette gepackt")
			else:
				g._hurt({"void": "von Leerenfeuer getroffen", "soul": "von Seelenfeuer getroffen"}.get(s.get("c", ""), "von Feuer getroffen"))
	g.eshots = g.eshots.filter(func(s: Dictionary) -> bool: return s.t > 0.0)
	var P = g.state.get("pull")
	if P != null:
		var to: Vector2 = P.m.p - Vector2(g.player.x, g.player.y)
		var dl := maxf(to.length(), 1.0)
		var step := minf(dl - P.m.r - 30.0, 1100.0 * dt)
		if step > 0.0:
			var mv := to / dl * step
			if not g.box_blocked(g._player_box(g.player.x + mv.x, g.player.y)):
				g.player.x += mv.x
			if not g.box_blocked(g._player_box(g.player.x, g.player.y + mv.y)):
				g.player.y += mv.y
		P.t -= dt
		if P.t <= 0.0 or step <= 0.0:
			g.state.pull = null


# ---------- drawing ----------

func _ellipse(l: CanvasItem, c: Vector2, rx: float, ry: float, col: Color) -> void:
	if rx <= 0.0:
		return
	l.draw_set_transform(c, 0.0, Vector2(1.0, ry / rx))
	l.draw_circle(Vector2.ZERO, rx, col)
	l.draw_set_transform(Vector2.ZERO)


func _ellipse_line(l: CanvasItem, c: Vector2, rx: float, ry: float, col: Color, width: float) -> void:
	if rx <= 0.0:
		return
	var pts := PackedVector2Array()
	for k in range(49):
		var a := k / 48.0 * TAU
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	l.draw_polyline(pts, col, width)


func _fan(l: CanvasItem, c: Vector2, r: float, ang: float, arc: float, col: Color) -> void:
	# a sweep all around (tail whirl, ball and chain) is a full disc, not a fan
	if arc >= TAU - 0.05:
		l.draw_circle(c, r, col)
		return
	var pts := PackedVector2Array([c])
	for k in range(25):
		pts.append(c + Vector2.from_angle(ang - arc / 2.0 + arc * k / 24.0) * r)
	l.draw_colored_polygon(pts, col)


func _orb(l: CanvasItem, c: Vector2, r: float, cols: Array, alpha := 1.0) -> void:
	l.draw_circle(c, r, Color(cols[2], 0.35 * alpha))
	l.draw_circle(c, r * 0.62, Color(cols[1], 0.75 * alpha))
	l.draw_circle(c, r * 0.3, Color(cols[0], alpha))


func _ring(l: CanvasItem, c: Vector2, r: float, k: float, col: Color) -> void:
	_ellipse(l, c, r, r * 0.62, Color(col, 0.12 + 0.18 * k))
	_ellipse_line(l, c, r, r * 0.62, Color(col, 0.8), 4.0)
	_ellipse(l, c, r * k, r * k * 0.62, Color(col, 0.35))


## Draws one atlas frame with its feet at foot; cut hides that many world pixels
## from the bottom (sinking into the floor). face -1 mirrors it.
func _sprite(l: CanvasItem, id: String, fr: Vector2i, foot: Vector2, sc: float, face: float, tint: Color, cut := 0.0) -> void:
	var def: Dictionary = defs[id]
	var px := float(def.px)
	var fw := float(def.w) * px
	var fh := float(def.h) * px
	var w := float(def.w) * sc
	var h := float(def.h) * sc
	var keep := h - cut
	if keep <= 0.0:
		return
	var src := Rect2(fr.x * fw, fr.y * fh, fw, fh * keep / h)
	l.draw_set_transform(Vector2(round(foot.x), round(foot.y - h + cut)), 0.0, Vector2(face, 1.0))
	l.draw_texture_rect_region(atlas[id], Rect2(-w / 2.0, 0, w, keep), src, tint)
	l.draw_set_transform(Vector2.ZERO)


## Draws a monster (sorted with the other actors by its feet).
func draw_mob(l: CanvasItem, m: Dictionary) -> void:
	if Rules.is_lord(m.def):
		_draw_lord(l, m)
		return
	var sc: float = m.s * (maxf(0.0, 1.0 - m.spawn * 1.6) if m.spawn > 0.0 else 1.0)
	if sc <= 0.0:
		return
	var air := float(m.act.get("air", 0.0)) if m.act != null else 0.0
	var w := float(m.def.w) * sc
	_ellipse(l, m.p, w * 0.34, w * 0.1 + 4.0, Color(0, 0, 0, 0.45))
	var hov := -10.0 + sin(g.state.t * 4.0 + m.seed) * 5.0 if m.st.ai in ["hover", "drift"] else 0.0
	var tint := Color(2.6, 2.6, 2.6, m.alpha) if m.hit > 0.0 else Color(1, 1, 1, m.alpha)
	_sprite(l, m.id, Rules.frame_of(m.def, m.anim, m.at), m.p + Vector2(0, 4.0 + hov - air), sc, m.face, tint)


func _draw_lord(l: CanvasItem, m: Dictionary) -> void:
	if m.burrowed and m.sink >= 1.0:
		_draw_mound(l, m)
		return
	var T = m.trans
	var D = m.dying
	var alt: float = m.alt
	var grow := 0.75 + 0.25 * float(T.grow) if T != null and T.swapped else 1.0
	var sc: float = m.s * grow * (maxf(0.0, 1.0 - m.spawn * 1.6) if m.spawn > 0.0 else 1.0)
	if sc <= 0.0:
		return
	var w := float(m.def.w) * sc
	var h := float(m.def.h) * sc
	var shade := maxf(0.25, 1.0 - alt / 900.0)
	_ellipse(l, m.p, w * 0.34 * shade, (w * 0.1 + 4.0) * shade, Color(0, 0, 0, 0.45 * shade))
	var glow := _glow(m)
	var tint := Color(1, 1, 1, m.alpha)
	if m.hit > 0.0:
		tint = Color(2.4, 2.4, 2.4, m.alpha)
	if glow > 0.0:
		tint = Color(1.0 + glow * 1.8, 1.0 + glow * 1.3, 1.0 + glow * 0.8, 1.0)
	if m.has("echo"):
		tint = Color(0.95, 0.6, 1.9, 0.55 + 0.15 * sin(g.state.t * 9.0 + m.seed))
	_sprite(l, m.id, Rules.frame_of(m.def, m.anim, m.at), m.p + Vector2(0, 4.0 - alt), sc, m.face, tint, m.sink * h)
	if m.sink > 0.0 and m.sink < 1.0:
		_draw_mound(l, m)


func _glow(m: Dictionary) -> float:
	if m.trans != null:
		return float(m.trans.glow)
	if m.dying != null:
		return float(m.dying.glow)
	return 0.0


## Dust mound of a burrowed dragon, drawn on the floor.
func _draw_mound(l: CanvasItem, m: Dictionary) -> void:
	var t: float = g.state.t
	var r: float = m.r * 0.9
	var bob := sin(t * 18.0) * 3.0
	_ellipse(l, m.p + Vector2(0, 4), r * 1.1, r * 0.4, Color(0, 0, 0, 0.4))
	for part: Array in [[Vector2(0, -6 + bob), r, r * 0.38, Color("#3b3332")], [Vector2(-r * 0.2, -10 + bob), r * 0.55, r * 0.2, Color("#483b3a")]]:
		var pts := PackedVector2Array()
		for k in range(17):
			var a := PI + k / 16.0 * PI
			pts.append(m.p + part[0] + Vector2(cos(a) * part[1], sin(a) * part[2]))
		l.draw_colored_polygon(pts, part[3])
	for k in range(4):
		var x: float = m.p.x + sin(t * 5.0 + k * 1.7) * r * 0.7
		l.draw_rect(Rect2(x - 3, m.p.y - 8 - (k % 2) * 6 + bob, 6, 4), Color(1, 0.6, 0.25, 0.8))


## Draws a crumbling dead monster.
func draw_corpse(l: CanvasItem, c: Dictionary) -> void:
	var def: Dictionary = defs[c.id]
	var n := int(def.anims.death.frames)
	var fr := Vector2i(mini(n - 1, int(c.t / 0.75 * n)), int(def.anims.death.row))
	_sprite(l, c.id, fr, c.p + Vector2(0, 4), c.s, c.face, Color.WHITE)


## Floor warnings: where an attack will land, drawn under the actors.
func draw_warnings(l: CanvasItem) -> void:
	for z: Dictionary in zones:
		var k := clampf(z.t / z.tele, 0.0, 1.0) if z.tele > 0.0 else 1.0
		match String(z.kind):
			"meteor", "hand":
				if z.t >= 0.0 and z.t < z.tele:
					_ring(l, z.p, z.r, k, Color8(170, 80, 255) if z.kind == "hand" or z.get("void", false) else Color8(255, 90, 30))
			"erupt", "land":
				if z.t < z.tele:
					_ring(l, z.p, z.r, k, Color8(255, 60, 30) if z.kind == "land" else Color8(255, 140, 40))
			"puddle":
				var fade := minf(1.0, (z.T - z.t) * 1.5)
				_ellipse(l, z.p, z.r, z.r * 0.55, Color8(255, 120, 30, int(107 * fade)))
				_ellipse(l, z.p, z.r * 0.55, z.r * 0.3, Color8(255, 220, 120, int(90 * fade)))
			"line":
				if z.t < z.tele:
					l.draw_set_transform(z.p, z.ang)
					l.draw_rect(Rect2(0, -z.w / 2.0, z.len, z.w), Color(1, 0.24, 0.12, 0.15 + 0.3 * k))
					l.draw_rect(Rect2(0, -z.w / 2.0, z.len, z.w), Color(1, 0.35, 0.16, 0.8), false, 4.0)
					l.draw_set_transform(Vector2.ZERO)
			"cone":
				if z.t < z.tele:
					_fan(l, z.p, z.r, z.ang, z.arc, Color(0.47, 0.86, 1, 0.12 + 0.25 * k))
	for L: Dictionary in lobs:
		_ring(l, L.to, L.r, L.t / L.T, Color8(255, 140, 40))
	for m: Dictionary in g.mobs:
		var A = m.act
		if A == null:
			continue
		if A.kind == "dash" and A.get("warn", false):
			var from: Vector2 = m.p - Vector2(0, 10)
			l.draw_dashed_line(from, from + A.dir * float(A.a.get("range", 500.0)), Color(1, 0.24, 0.16, 0.75), 4.0, 16.0)
		if A.kind == "slam" and A.n == 0 and A.has("warn_at"):
			_ring(l, A.warn_at, float(A.a.radius), minf(1.0, A.t / 0.75), Color8(255, 70, 30))
		if A.kind == "beam" and A.get("warn", false):
			var head: Vector2 = m.p - Vector2(0, m.cy)
			for b: float in A.beams:
				l.draw_dashed_line(head, head + Vector2.from_angle(b) * 1000.0, Color(0.78, 0.47, 1, 0.55), 4.0, 10.0)


## Bright parts of attacks, enemy shots and the transformation glow; drawn on an additive layer.
func draw_fx(l: CanvasItem) -> void:
	var t: float = g.state.t
	for z: Dictionary in zones:
		match String(z.kind):
			"wave":
				var k := minf(1.0, z.t / z.T)
				var col: Color = {"lava": Color8(255, 150, 40), "void": Color8(180, 90, 255)}.get(z.get("c", ""), Color8(255, 90, 30))
				_ellipse_line(l, z.p, z.r * k, z.r * k * 0.62, Color(col, 1.0 - k), 26.0 * (1.0 - k) + 6.0)
			"arc":
				_fan(l, z.p, z.r, z.ang, z.arc, Color(1, 0.67, 0.31, 0.45 * (1.0 - z.t / z.T)))
			"line":
				if z.t >= z.tele:
					var k: float = (z.t - z.tele) / (z.T - z.tele)
					l.draw_set_transform(z.p, z.ang)
					l.draw_rect(Rect2(0, -z.w / 2.0 * (1.0 - k * 0.5), z.len, z.w * (1.0 - k * 0.5)), Color(1, 0.67, 0.24, 0.8 * (1.0 - k)))
					l.draw_set_transform(Vector2.ZERO)
			"cone":
				if z.t >= z.tele:
					var k: float = (z.t - z.tele) / (z.T - z.tele)
					_fan(l, z.p, z.r * (0.4 + 0.6 * k), z.ang, z.arc, Color(0.59, 0.9, 1, 0.5 * (1.0 - k)))
			"meteor", "hand":
				if z.kind == "meteor" and z.t >= 0.0 and z.t < z.tele:
					var my: float = z.p.y - 900.0 * (1.0 - z.t / z.tele)
					var void_fire: bool = z.get("void", false)
					l.draw_rect(Rect2(z.p.x - 8, my - 120, 16, 120), Color(1, 0.47, 0.16, 0.35))
					_orb(l, Vector2(z.p.x, my), 46.0, SHOT_COL.void if void_fire else SHOT_COL.lava)
				if z.t >= z.tele:
					var k: float = (z.t - z.tele) / (z.T - z.tele)
					var col: Color = Color8(190, 110, 255) if z.kind == "hand" else Color8(255, 160, 60)
					l.draw_circle(z.p - Vector2(0, 20), z.r * 1.3, Color(col, 0.3 * (1.0 - k)))
					l.draw_circle(z.p - Vector2(0, 20), z.r * 0.7, Color(col, 0.6 * (1.0 - k)))
					if z.kind == "hand":
						for f in range(-2, 3):
							var fl := 70.0 * (1.0 - absi(f) * 0.2)
							l.draw_rect(Rect2(z.p.x + f * 12 - 4, z.p.y - 30 - fl * sin(minf(1.0, k * 2.0) * PI / 2.0), 8, fl), Color(0.9, 0.78, 1, 1.0 - k))
	for L: Dictionary in lobs:
		var k: float = L.t / L.T
		_orb(l, L.from.lerp(L.to, k) - Vector2(0, sin(k * PI) * 220.0), 30.0, SHOT_COL[L.c])
	for m: Dictionary in g.mobs:
		var A = m.act
		if A != null and A.kind == "beam" and not A.get("warn", false):
			var head: Vector2 = m.p - Vector2(0, m.cy)
			for b: float in A.beams:
				var len := _wall_len(head, b, 1100.0)
				l.draw_set_transform(head, b)
				for part: Array in [[60.0, Color(0.35, 0.12, 0.63, 0.35)], [36.0, Color(0.67, 0.31, 1, 0.6)], [16.0, Color(0.94, 0.82, 1, 0.95)]]:
					l.draw_rect(Rect2(0, -part[0] / 2.0 + sin(t * 30.0) * 2.0, len, part[0]), part[1])
				l.draw_set_transform(Vector2.ZERO)
		var glow := _glow(m)
		if glow > 0.0:
			var c: Vector2 = m.p - Vector2(0, m.cy + m.alt)
			var r: float = float(m.def.w) * m.s * 0.9
			l.draw_circle(c, r, Color(1, 0.47, 0.16, 0.18 * glow))
			l.draw_circle(c, r * 0.55, Color(1, 0.9, 0.63, 0.35 * glow))
	for s: Dictionary in g.eshots:
		_orb(l, s.p, 18.0 if s.get("small", false) else 24.0, SHOT_COL.get(s.get("c", "fire"), SHOT_COL.fire))
		if s.has("chain"):
			l.draw_dashed_line(s.chain.p - Vector2(0, s.chain.cy), s.p, Color(0.59, 0.67, 0.78, 0.8), 4.0, 8.0)
