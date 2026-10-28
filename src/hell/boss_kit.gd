extends RefCounted
## Guardians with their own fight (theme.boss_kits, e.g. the Frostgruft): phases
## with their own hit points (Hrimgar's three bars), an attack cycle per phase
## with telegraphed attacks, a break between phases, crystals that guard the
## boss and a last stand. Works on the boss mob dictionary and calls back into
## the game (src/hell/hell_game.gd) for shots, summons, zones and the hero.


## Turns a freshly spawned boss mob into a kit boss. base_hp is the floor's boss hp.
static func setup(m: Dictionary, kit: Dictionary, base_hp: float) -> void:
	var hps: Array = []
	if kit.has("hp"):
		hps = (kit.hp as Array).map(func(v: Variant) -> float: return float(v))
	else:
		for ph: Dictionary in kit.phases:
			hps.append(round(base_hp * float(ph.get("share", 1.0 / kit.phases.size()))))
	m.kit = kit
	m.phase = 0
	m.phase_hp = hps
	m.hp = float(hps[0])
	m.max = float(hps[0])
	m.atk_i = 0
	m.atk_t = 1.5
	m.inv = 0.0
	m.rest = 0.0
	m.busy = {}
	m.hold = false
	m.stand_done = false
	_apply_look(m)


## The current phase's data.
static func phase(m: Dictionary) -> Dictionary:
	return m.kit.phases[int(m.phase)]


static func _apply_look(m: Dictionary) -> void:
	var ph := phase(m)
	if ph.has("look"):
		m.look = ph.look
	m.tint = ph.get("tint", [1, 1, 1])


## Damage factor right now: 0 while invulnerable, guard while its crystals stand, more while resting.
static func damage_factor(game: Node, m: Dictionary) -> float:
	if float(m.inv) > 0.0:
		return 0.0
	var f := 1.0
	var ph := phase(m)
	if ph.has("guard"):
		for o: Dictionary in game.mobs:
			if o.get("guard_of", null) == m:
				f = float(ph.guard)
				break
	if float(m.rest) > 0.0:
		f *= float(ph.get("last_stand", {}).get("rest_damage", 1.0))
	return f


## Called when the boss's hp reached 0: starts the next phase and returns true,
## or returns false when this was the last bar.
static func next_phase(game: Node, m: Dictionary) -> bool:
	if int(m.phase) + 1 >= m.kit.phases.size():
		return false
	m.phase = int(m.phase) + 1
	m.hp = float(m.phase_hp[m.phase])
	m.max = m.hp
	m.atk_i = 0
	m.atk_t = 1.0
	m.busy = {}
	m.hold = false
	var br: Dictionary = game.theme.get("phase_break", {})
	m.inv = float(br.get("inv", 2.0))
	_apply_look(m)
	# the armour bursts: a shard ring and the heroes are pushed back
	var n := int(br.get("ring", 18))
	for k in range(n):
		var a := TAU * k / n
		game.eshots.append({"p": m.p - Vector2(0, m.cy), "v": Vector2(cos(a), sin(a)) * float(br.get("ring_speed", 420)), "t": 1.6})
	_push_hero(game, m.p, float(br.get("push", 160)))
	game._burst(m.p - Vector2(0, m.cy), 60, true)
	_sound(game, "boss_phase")
	var ph := phase(m)
	game._toast(str(ph.get("title", "%s: Phase %d" % [game.W.boss.name, int(m.phase) + 1])))
	game.state.storm = bool(ph.get("storm", false))
	return true


static func _push_hero(game: Node, from: Vector2, dist: float) -> void:
	var me := Vector2(game.player.x, game.player.y)
	var dir := (me - from).normalized() if me != from else Vector2.DOWN
	for step in range(int(dist / 16.0)):
		var nx: float = game.player.x + dir.x * 16.0
		var ny: float = game.player.y + dir.y * 16.0
		if not game.box_blocked(game._player_box(nx, game.player.y)):
			game.player.x = nx
		if not game.box_blocked(game._player_box(game.player.x, ny)):
			game.player.y = ny


## One frame of the boss fight: invulnerability, the running attack, the next attack, the last stand.
static func update(game: Node, m: Dictionary, dt: float) -> void:
	m.inv = maxf(0.0, float(m.inv) - dt)
	m.rest = maxf(0.0, float(m.rest) - dt)
	var ph := phase(m)
	var stand: Dictionary = ph.get("last_stand", {})
	if not stand.is_empty() and not m.stand_done and float(m.hp) <= float(m.max) * float(stand.below) and (m.busy as Dictionary).is_empty():
		m.stand_done = true
		start(game, m, {"do": "last_stand"}.merged(stand))
	if not (m.busy as Dictionary).is_empty():
		_run(game, m, dt)
		return
	if float(m.rest) > 0.0 or float(m.inv) > 0.0:
		return
	m.atk_t = float(m.atk_t) - dt
	if float(m.atk_t) > 0.0:
		return
	var attacks: Array = ph.attacks
	var atk: Dictionary = attacks[int(m.atk_i) % attacks.size()]
	m.atk_i = int(m.atk_i) + 1
	m.atk_t = float(ph.every)
	start(game, m, atk)


const ATTACK_SOUNDS := {"summon": "boss_summon", "ring": "boss_ring", "fan": "boss_ring", "fist": "boss_charge", "fist_hunt": "boss_summon",
	"icicles": "boss_windup", "chill_zones": "boss_windup", "stomp": "boss_stomp", "breath": "boss_breath", "spiral": "boss_breath",
	"charge": "boss_charge", "teleport_center": "boss_windup", "last_stand": "boss_windup"}


## The game's sound for a boss event (theme.sounds), when the game plays sounds.
static func _sound(game: Node, event: String) -> void:
	if game.has_method("_sound"):
		game._sound(event)


## Starts one attack; instant ones happen now, timed ones run in m.busy.
static func start(game: Node, m: Dictionary, atk: Dictionary) -> void:
	_sound(game, str(ATTACK_SOUNDS.get(str(atk.do), "")))
	var me := Vector2(game.player.x, game.player.y - 30)
	var from: Vector2 = m.p - Vector2(0, m.cy)
	var aim := (me - from).normalized()
	match str(atk.do):
		"summon":
			var n := int(atk.count)
			for k in range(n):
				var a := TAU * k / n
				var around := float(atk.get("around", 110))
				game._spawn_mob(m.room, m.p + Vector2(cos(a), sin(a)) * around, str(atk.kind))
				if atk.get("guard", false):
					game.mobs[game.mobs.size() - 1].guard_of = m
		"ring":
			_ring(game, from, int(atk.count), float(atk.speed), 0.0, -1.0, float(atk.get("chill", 0.0)))
		"fan":
			var n := int(atk.count)
			for k in range(n):
				var a := aim.angle() + (float(k) / maxf(1.0, n - 1.0) - 0.5) * float(atk.spread)
				_shot(game, from, Vector2(cos(a), sin(a)) * float(atk.speed), float(atk.get("chill", 0.0)))
		"fist":
			game.eshots.append({"p": from, "v": aim * float(atk.speed), "t": float(atk.back) * 2.0, "back": float(atk.back), "home_to": m, "fist": true})
		"fist_hunt":
			for k in range(int(atk.count)):
				var side := Vector2(-aim.y, aim.x) * (1.0 if k % 2 == 0 else -1.0)
				game.eshots.append({"p": from + side * 60.0, "v": side * float(atk.speed), "t": float(atk.time), "home": float(atk.speed), "fist": true})
		"icicles":
			for k in range(int(atk.count)):
				var off := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * float(atk.spread) if k > 0 else Vector2.ZERO
				game.zones.append({"kind": "icicle", "p": Vector2(game.player.x, game.player.y) + off, "r": float(atk.radius), "t": float(atk.delay), "max": float(atk.delay)})
		"chill_zones":
			for k in range(int(atk.count)):
				var a := randf() * TAU
				game.zones.append({"kind": "chill", "p": m.p + Vector2(cos(a), sin(a)) * randf_range(120, 420), "r": float(atk.radius), "t": float(atk.time), "max": float(atk.time)})
		_:
			m.busy = atk.duplicate()
			m.busy.e = 0.0
			m.busy.k = 0
			m.busy.dir = aim
			m.busy.spin = aim.angle()
			m.hold = str(atk.do) in ["charge", "teleport_center", "last_stand", "breath"]
			if str(atk.do) == "teleport_center":
				var r: Dictionary = game.W.rooms[m.room]
				m.busy.to = Vector2((r.bx + r.bw / 2.0) * 96.0, (r.by + r.bh / 2.0 + 0.5) * 96.0)
				game.zones.append({"kind": "telegraph", "p": m.busy.to, "r": 150.0, "t": float(atk.windup), "max": float(atk.windup)})
			if str(atk.do) == "last_stand":
				for k in range(int(atk.safe)):
					var a := TAU * k / int(atk.safe) + randf()
					game.zones.append({"kind": "safe", "p": m.p + Vector2(cos(a), sin(a)) * 330.0, "r": float(atk.radius), "t": float(atk.windup), "max": float(atk.windup)})
				game._toast("Ewiger Frost! Rettet euch in die leuchtenden Kreise.")


static func _shot(game: Node, from: Vector2, v: Vector2, chill: float) -> void:
	var s := {"p": from, "v": v, "t": float(game.balance.enemy_shot.life)}
	if chill > 0.0:
		s.chill = chill
	game.eshots.append(s)


static func _ring(game: Node, from: Vector2, n: int, speed: float, turn: float, gap_at: float, chill: float, gap := 0.0) -> void:
	for k in range(n):
		var a := turn + TAU * k / n
		if gap_at >= 0.0 and absf(angle_difference(a, gap_at)) < gap / 2.0:
			continue
		_shot(game, from, Vector2(cos(a), sin(a)) * speed, chill)


## Advances the timed attack in m.busy.
static func _run(game: Node, m: Dictionary, dt: float) -> void:
	var b: Dictionary = m.busy
	b.e = float(b.e) + dt
	var from: Vector2 = m.p - Vector2(0, m.cy)
	var done := false
	match str(b.do):
		"stomp":
			var pause := float(b.pause)
			while int(b.k) < int(b.rings) and float(b.e) >= int(b.k) * pause:
				_ring(game, Vector2(m.p.x, m.p.y - 10), int(b.count), float(b.speed), randf() * TAU, randf() * TAU, 0.0, float(b.gap))
				b.k = int(b.k) + 1
			done = int(b.k) >= int(b.rings)
		"breath", "spiral":
			var rate := float(b.rate)
			var arms := int(b.get("arms", 1))
			var turn := float(b.get("turn", TAU)) / float(b.duration)
			while float(b.k) * rate < float(b.e):
				var a: float = float(b.spin) + turn * float(b.k) * rate
				for arm in range(arms):
					var aa := a + TAU * arm / arms
					_shot(game, from, Vector2(cos(aa), sin(aa)) * float(b.speed), float(b.get("chill", 0.0)))
				b.k = int(b.k) + 1
			done = float(b.e) >= float(b.duration)
		"charge":
			if float(b.e) >= float(b.windup):
				var step: Vector2 = b.dir * float(b.speed) * dt
				var rr: float = m.r * 0.7
				var nx: Vector2 = m.p + step
				if game.box_blocked(Rect2(nx.x - rr, nx.y - rr, rr * 2, rr), false):
					done = true
				else:
					m.p = nx
			done = done or float(b.e) >= float(b.windup) + float(b.time)
		"teleport_center":
			if float(b.e) >= float(b.windup):
				m.p = b.to
				game._burst(m.p - Vector2(0, m.cy), 40, true)
				if Vector2(game.player.x, game.player.y).distance_to(m.p) < 160.0:
					_push_hero(game, m.p, float(b.push))
				done = true
		"last_stand":
			if float(b.e) >= float(b.windup):
				var me := Vector2(game.player.x, game.player.y)
				var safe := false
				for z: Dictionary in game.zones:
					if z.kind == "safe" and me.distance_to(z.p) < float(z.r):
						safe = true
				if not safe:
					game._hurt("vom ewigen Frost erfasst")
				game._burst(m.p - Vector2(0, m.cy), 80, true)
				m.rest = float(b.rest)
				done = true
		_:
			done = true
	if done:
		m.busy = {}
		m.hold = false
