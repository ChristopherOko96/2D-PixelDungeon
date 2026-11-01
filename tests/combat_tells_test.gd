extends SceneTree
## Fair monster combat (VORSCHLAEGE.md B1, B2, A12, A13) on the Krypta scene:
## windups come from assets/data/combat_tells.json, an attack's aim locks once
## aim_lock of its windup has run (the crypt's swing and bolt, the Frostgruft's
## plain shots), never more than tokens.max_melee monsters swing at once with 8
## skeletons round the hero (the others keep circling), the lanes are counted
## apart, a hit flashes white for its first frames, and a beam ends at a wall.

const KryptaScene = preload("res://src/hell/krypta_dungeon.tscn")
const FrostMoves = preload("res://src/hell/frost_moves.gd")
const TELLS_PATH := "res://assets/data/combat_tells.json"
const STEP := 1.0 / 60.0
var game: Node
var tells: Dictionary = {}
var checked := 0
var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	checked += 1
	if not condition:
		failures.append(label)
		printerr("COMBAT_TELLS_FAIL: ", label)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	seed(7)
	tells = JSON.parse_string(FileAccess.get_file_as_string(TELLS_PATH))
	game = KryptaScene.instantiate()
	game.class_id = "swordsman"
	game.settings_path = "user://settings_test.cfg"
	root.add_child(game)
	for i in range(2):
		await process_frame
	_test_windups_come_from_data()
	_test_rig_windup_peaks_at_release()
	_test_swing_aim_locks_after_share()
	_test_bolt_aim_locks_after_share()
	_test_frost_shot_aim_locks_after_share()
	_test_at_most_three_swing_at_once()
	_test_lanes_are_counted_apart()
	_test_hit_flashes_white_first_frames()
	_test_beam_stops_at_wall()
	game.queue_free()
	await process_frame
	for path: String in ["user://profile_test.json", "user://settings_test.cfg"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("COMBAT_TELLS checked=%d failures=%d" % [checked, failures.size()])
	quit(1 if failures.size() > 0 else 0)


## No fight, no monsters, the hero whole and alive.
func _calm() -> void:
	for r: Dictionary in game.W.rooms:
		r.fight = false
		r.cleared = true
	game.mobs = []
	game.eshots = []
	game.monsters.zones = []
	game.state.hp = game.state.max_hp
	game.state.dead = 0.0


func _hero() -> Vector2:
	return Vector2(game.player.x, game.player.y)


func _put_hero(p: Vector2) -> void:
	game.player.x = p.x
	game.player.y = p.y


## Runs the monsters for `seconds`; the hero is never invulnerable, so any blow shows.
func _step(seconds: float) -> void:
	for k in range(int(round(seconds / STEP))):
		game.state.inv = 0.0
		game.monsters.update(STEP)


func _index(m: Dictionary, value: String, field := "kind") -> int:
	var attacks: Array = m.st.attacks
	for k in range(attacks.size()):
		if str((attacks[k] as Dictionary).get(field, "")) == value:
			return k
	return -1


## Monster `id` at the hero + `off`, grown in, its attacks far off.
func _spawn(id: String, off: Vector2) -> Dictionary:
	var m: Dictionary = game.monsters.spawn(int(game.state.room), _hero() + off, id)
	m.spawn = 0.0
	for k in range(m.cds.size()):
		m.cds[k] = 99.0
	return m


func _start(m: Dictionary, kind: String) -> Dictionary:
	var to: Vector2 = _hero() - m.p
	game.monsters._start_act(m, _index(m, kind), to, to.length())
	return m.act


## The arc zone a swing of `m` left, {} if none.
func _arc_of(m: Dictionary) -> Dictionary:
	for z: Dictionary in game.monsters.zones:
		if str(z.kind) == "arc" and is_same(z.m, m):
			return z
	return {}


func _test_windups_come_from_data() -> void:
	# Arrange: a skeleton about to swing, an archer about to shoot
	_calm()
	var swing_tell := float(tells.tells.swing)
	var bolt_tell := float(tells.tells.bolt)
	var skel := _spawn("skelett", Vector2(100, 0))
	var archer := _spawn("skelettschuetze", Vector2(300, 0))
	# Act
	var swing := _start(skel, "swing")
	var bolt := _start(archer, "bolt")
	# Assert: the windups are the data's (B1: swing 0.5, bolt 0.45)
	check(is_equal_approx(float(swing.wind), swing_tell), "a swing winds up for the data's %.2f s (act %.2f)" % [swing_tell, float(swing.wind)])
	check(is_equal_approx(float(bolt.wind), bolt_tell), "a bolt winds up for the data's %.2f s (act %.2f)" % [bolt_tell, float(bolt.wind)])
	check(is_equal_approx(FrostMoves.tell_time("swing", true), float(tells.boss_tells.swing)), "a boss's swing takes boss_tells")
	# Act: through most of the swing's windup
	_step(swing_tell - 0.05)
	# Assert: not struck yet
	check(int(swing.n) == 0 and _arc_of(skel).is_empty(), "no blow before the windup ends (t %.2f)" % float(swing.t))
	# Act: past its end
	_step(0.1)
	# Assert
	check(not _arc_of(skel).is_empty(), "the blow lands right after the windup")


## B1 gap (nacharbeit L3): a rigged figure's attack clip (src/hell/drake_rig_host.gd
## act_phase) runs its windup over the act's own windup from combat_tells.json,
## so it peaks at the release, not at the old 0.35 s.
func _test_rig_windup_peaks_at_release() -> void:
	# Arrange: a skeleton and an archer start their acts
	_calm()
	var host: RefCounted = game.drake_rig
	check(host != null, "the Krypta has its rig host")
	if host == null:
		return
	var skel := _spawn("skelett", Vector2(100, 0))
	var archer := _spawn("skelettschuetze", Vector2(300, 0))
	var swing := _start(skel, "swing")
	var bolt := _start(archer, "bolt")
	for pair: Array in [[skel, swing, float(tells.tells.swing)], [archer, bolt, float(tells.tells.bolt)]]:
		var m: Dictionary = pair[0]
		var act: Dictionary = pair[1]
		var wind: float = pair[2]
		# Act: at the old fixed windup (0.35 s) and just before the release
		act.t = 0.35
		var early: Dictionary = host.act_phase(m)
		act.t = wind - STEP
		var late: Dictionary = host.act_phase(m)
		# Assert: still winding up at 0.35 s, at its peak only at the release
		check(str(early.attack) == "windup" and float(early.attack_p) < 0.9, "%s: no windup peak at 0.35 s of %.2f (p %.2f)" % [str(act.kind), wind, float(early.attack_p)])
		check(str(late.attack) == "windup" and float(late.attack_p) > 0.95, "%s: the windup peaks at the release (p %.2f)" % [str(act.kind), float(late.attack_p)])
		# an act without its own windup (an old save, a test) takes the data's for its kind
		var bare := act.duplicate()
		bare.erase("wind")
		bare.t = wind - STEP
		m.act = bare
		check(float(host.act_phase(m).attack_p) > 0.95, "%s: without act.wind the clip follows combat_tells.json" % str(act.kind))
		m.act = act


func _test_swing_aim_locks_after_share() -> void:
	# Arrange: a skeleton east of the hero starts its swing (it aims west)
	_calm()
	var skel := _spawn("skelett", Vector2(100, 0))
	var A := _start(skel, "swing")
	var wind := float(A.wind)
	check(is_equal_approx(FrostMoves.aim_lock(), 0.6), "the aim locks at 60 %% of a windup (data %.2f)" % FrostMoves.aim_lock())
	# Act: at 30 % of the windup the hero steps north of it: the aim follows
	_step(wind * 0.3)
	var north: Vector2 = skel.p + Vector2(0, -100)
	_put_hero(north)
	_step(wind * 0.4)
	# Assert: at 70 % it is locked, on the hero's new place, and has not struck yet
	check(A.has("lock") and int(A.n) == 0, "the swing's aim is locked at 70 %% of its windup, before the blow (t %.2f)" % float(A.t))
	# Act: after the lock he steps back behind it (east); the blow comes
	_put_hero(skel.p + Vector2(100, 0))
	var hp := int(game.state.hp)
	_step(wind - float(A.t) + 0.05)
	# Assert: the blade went north, where he stood at the lock, and missed him
	var z := _arc_of(skel)
	check(not z.is_empty(), "the swing struck")
	if not z.is_empty():
		var want := (north - (skel.p as Vector2)).angle()
		check(absf(angle_difference(float(z.ang), want)) < 0.15, "the blow goes where he stood at the lock (%.2f, want %.2f)" % [float(z.ang), want])
	check(int(game.state.hp) == hp, "a hero who stepped away after the lock is not hit (%d -> %d)" % [hp, int(game.state.hp)])


func _test_bolt_aim_locks_after_share() -> void:
	# Arrange: an archer east of the hero starts a single shot
	_calm()
	var archer := _spawn("skelettschuetze", Vector2(320, 0))
	var A := _start(archer, "bolt")
	var wind := float(A.wind)
	var at := _hero()
	# Act: at 70 % of the windup (past the lock) the hero runs north; the arrow leaves
	_step(wind * 0.7)
	check(game.eshots.is_empty(), "no arrow before the windup ends")
	_put_hero(at + Vector2(0, -220))
	_step(wind * 0.3 + 0.05)
	# Assert: the arrow flies at where he stood at the lock
	check(not game.eshots.is_empty(), "the archer shot")
	if not game.eshots.is_empty():
		var s: Dictionary = game.eshots[-1]
		var want := (at - Vector2(0, 30) - (s.p as Vector2)).angle()
		check(absf(angle_difference((s.v as Vector2).angle(), want)) < 0.05, "the arrow flies at the locked aim (%.2f, want %.2f)" % [(s.v as Vector2).angle(), want])


func _test_frost_shot_aim_locks_after_share() -> void:
	# Arrange: a Frostgruft shooter (a themed mob) ready to shoot; the hero moves three times
	_calm()
	var m := {"room": int(game.state.room), "kind": "frost_skeleton", "hp": 4.0, "p": _hero() + Vector2(260, 0)}
	game.mobs = [m]
	var T := FrostMoves.tell_time("bolt")
	var early := _hero() + Vector2(0, -150)
	var locked := _hero() + Vector2(0, 150)
	var late := _hero() + Vector2(-150, 0)
	var t := 0.0
	var got := Vector2.INF
	# Act: early target before 40 % of the windup, the locked one around the lock, the late one after
	for k in range(int(ceil(T / STEP)) + 4):
		var target := early if t < T * 0.4 else (locked if t < T * 0.7 else late)
		got = FrostMoves.basic_tell(game, m, "bolt", target, STEP, true)
		t += STEP
		if got.is_finite():
			break
	# Assert
	check(got.is_finite(), "the Frostgruft's shot is let go after its windup")
	check(got.is_equal_approx(locked), "the Frostgruft's shot goes where the hero stood at the lock (%s, want %s)" % [got, locked])
	check(t >= T - STEP * 0.5, "it held its shot for the data's %.2f s (%.2f)" % [T, t])
	check(not m.has("tell") and not bool(m.get("tele", false)), "the windup is over once it shot")


func _test_at_most_three_swing_at_once() -> void:
	# Arrange: 8 skeletons round the hero, all ready to swing
	_calm()
	var room := int(game.state.room)
	var ring: Array = []
	for k in range(8):
		var m := _spawn("skelett", Vector2.from_angle(TAU * float(k) / 8.0) * 100.0)
		for i in range(m.cds.size()):
			m.cds[i] = 0.0
		ring.append(m)
	var start: Array = ring.map(func(m: Dictionary) -> Vector2: return m.p)
	var most := 0
	var moved := 0
	var struck := {}
	# the waiting ones (m.wait) circle at tokens.keep plus their radius, out of touching reach
	var wait_dist := 0.0
	var wait_samples := 0
	var touching := 0
	var reach := float(game.monsters.cfg.contact_reach)
	# Act: 3 s of fighting (the hero cannot be hurt, so nobody stops)
	for f in range(int(round(3.0 / STEP))):
		game.state.inv = 1.0
		game.state.hp = game.state.max_hp
		game.monsters.update(STEP)
		most = maxi(most, FrostMoves.attackers(game, room, "melee"))
		for i in range(ring.size()):
			if ring[i].act != null:
				struck[i] = true
			elif f >= int(round(1.5 / STEP)) and ring[i].has("wait"):
				var dist: float = (ring[i].p as Vector2).distance_to(_hero())
				wait_dist += dist
				wait_samples += 1
				if dist < float(ring[i].r) + reach:
					touching += 1
		if f == int(round(1.0 / STEP)):
			for i in range(ring.size()):
				if (ring[i].p as Vector2).distance_to(start[i]) > 12.0:
					moved += 1
	var cap := int(tells.tokens.max_melee)
	# Assert
	check(most <= cap, "never more than %d skeletons swing at once (most %d)" % [cap, most])
	check(most == cap, "the tokens are used: %d swing at once (most %d)" % [cap, most])
	check(moved >= 5, "the waiting ones keep moving (%d of 8 moved in 1 s)" % moved)
	check(struck.size() >= 5, "the turns go round (%d of 8 attacked in 3 s)" % struck.size())
	var keep := float(tells.tokens.keep)
	var mean := wait_dist / maxf(1.0, float(wait_samples))
	check(wait_samples > 60 and mean >= keep * 0.75, "the waiting ones keep their distance (mean %.0f px over %d samples, keep %.0f + r)" % [mean, wait_samples, keep])
	check(touching <= wait_samples / 10, "the waiting ones stay out of touching reach (%d of %d samples)" % [touching, wait_samples])


func _test_lanes_are_counted_apart() -> void:
	# Arrange: three themed shooters winding up their shots
	_calm()
	var room := int(game.state.room)
	var busy: Array = []
	for k in range(3):
		busy.append({"room": room, "kind": "frost_skeleton", "hp": 4.0, "p": _hero() + Vector2(200 + 40 * k, 0), "tell": {"kind": "bolt", "t": 0.1, "T": 0.45}})
	var next := {"room": room, "kind": "frost_skeleton", "hp": 4.0, "p": _hero() + Vector2(0, 200)}
	game.mobs = busy + [next]
	# Act / Assert: no ranged token is left, a melee one is
	check(FrostMoves.attackers(game, room, "ranged", next) == 3, "three shooters winding up count as ranged attackers")
	check(not FrostMoves.token_free(game, next, "bolt"), "a fourth shooter waits for its token")
	check(FrostMoves.token_free(game, next, "swing"), "the melee lane is counted apart from the ranged one")
	# Arrange: a boss in the room: its adds are never held back
	game.mobs.append({"room": room, "kind": "boss", "hp": 50.0, "p": _hero() + Vector2(-300, 0)})
	check(FrostMoves.token_free(game, next, "bolt"), "a boss's add is never held back by the tokens")


func _test_hit_flashes_white_first_frames() -> void:
	# Arrange: monsters hit one frame and six frames ago, and a boss hit one frame ago
	var fresh := {"hit": FrostMoves.HIT_SET - STEP}
	var older := {"hit": FrostMoves.HIT_SET - 6.0 * STEP}
	var boss := {"hit": FrostMoves.HIT_SET - STEP, "boss": true}
	var pose := {"flash": 0.4, "flash_color": Color.RED}
	# Act
	var a := FrostMoves.white_hit(fresh, pose)
	var b := FrostMoves.white_hit(older, pose)
	var c := FrostMoves.white_hit(boss, pose)
	# Assert
	check(bool(a.get("hit_white", false)) and float(a.flash) >= 1.0 and (a.flash_color as Color).is_equal_approx(Color.WHITE), "a fresh hit flashes the whole figure white")
	check(not b.has("hit_white") and float(b.flash) == 0.4, "after 2-3 frames the feel's own flash runs on")
	check(not c.has("hit_white"), "a boss keeps the feel's softer flash")
	check(not pose.has("hit_white"), "the feel's pose itself is never changed")


func _test_beam_stops_at_wall() -> void:
	# Arrange: rays from the hero in eight directions
	_calm()
	var from := _hero() - Vector2(0, 30)
	var C := float(game.C)
	var stopped := 0
	for k in range(8):
		var ang := TAU * float(k) / 8.0 + 0.1
		# Act
		var len: float = game.monsters._wall_len(from, ang, 3000.0)
		if len >= 3000.0:
			continue
		stopped += 1
		var dir := Vector2.from_angle(ang)
		var before := from + dir * maxf(0.0, len - 2.0)
		var after := from + dir * (len + 2.0)
		# Assert: open floor just before the end, a wall or closed gate just past it
		check(not game._cell_blocked(int(floor(before.x / C)), int(floor(before.y / C)), false) or len < 2.0, "a beam runs over open floor up to its end (dir %d)" % k)
		check(game._cell_blocked(int(floor(after.x / C)), int(floor(after.y / C)), false), "a beam ends at a wall or closed gate (dir %d)" % k)
	check(stopped >= 4, "the room's walls stop beams (%d of 8)" % stopped)
