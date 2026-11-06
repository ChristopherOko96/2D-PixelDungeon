extends SceneTree
## Plays Story 1 (the Krypta, chapter 1) from floor 1 to the end in the real game and reports, per floor,
## whether the hero gets through and what he met. It moves the hero only to places a walk from where he
## stands reaches (cell search over the live floor: walls, closed gates and solid pieces block, breakable
## urns and crates do not, pits do), so a floor it finishes is one a player can finish:
## - every reachable room is entered; its fight starts as in play, its monsters are struck with the hero's
##   own hits until they fall (one that stays up a long time is ended and reported);
## - keys lying about are picked up, chests that hold one are opened, locked gates are opened with it;
## - a riddle gate on the way is solved by its pieces (fire bowls lit, plates stepped in order);
## - the boss falls, the portal is used, the next floor loads; the last portal ends the chapter.
## The hero cannot die (life refilled every frame); the run counts the hits he would have taken.
##
##   godot --headless --path . -s tools/krypta_dungeon/playthrough.gd            (4 classes, 1 run each)
##   PT_RUNS=3 PT_SEED=5 PT_CLASSES=swordsman,mage godot --headless --path . -s tools/krypta_dungeon/playthrough.gd
##   PT_SCENE=res://src/hell/frost_dungeon.tscn ...   plays Story 2 (the Frostgruft) the same way

const KryptaScene = preload("res://src/hell/krypta_dungeon.tscn")
const C := 96.0
## Frames a fight may take before its last monsters are ended and reported.
const FIGHT_FRAMES := 900
## Rounds of "find something to do" per floor before the floor counts as stuck.
const ROUNDS := 400

var game: Node
var stuck := 0
var report: Array[String] = []
var hits_taken := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var classes := (OS.get_environment("PT_CLASSES") if OS.get_environment("PT_CLASSES") != "" else "swordsman,archer,mage,necromancer").split(",")
	var runs := maxi(1, int(OS.get_environment("PT_RUNS")) if OS.get_environment("PT_RUNS") != "" else 1)
	var k := 0
	for cid: String in classes:
		for i in range(runs):
			k += 1
			seed(int(OS.get_environment("PT_SEED")) * 7919 + 1000 + k * 37)
			await _play(cid)
	print("PLAYTHROUGH done stuck=%d" % stuck)
	for line in report:
		print(line)
	quit(1 if stuck > 0 else 0)


## Keeps the hero at the place _go put him while a talent move still running (a charge of the
## swordsman) would carry him back to where he was: the bot moves him, a player never could.
var _hold_at := Vector2.INF
var _hold_left := 0


func _frames(n: int) -> void:
	for i in range(n):
		if _hold_left > 0 and game != null:
			_hold_left -= 1
			game.player.x = _hold_at.x
			game.player.y = _hold_at.y
		if game != null and not game.state.is_empty():
			if int(game.state.hp) < int(game.state.max_hp):
				hits_taken += 1
			game.state.hp = game.state.max_hp
			game.state.dead = 0.0
		await process_frame


func _play(cid: String) -> void:
	var scene: PackedScene = load(OS.get_environment("PT_SCENE")) if OS.get_environment("PT_SCENE") != "" else KryptaScene
	game = scene.instantiate()
	game.class_id = cid
	game.graphics_path = "user://playthrough_graphics.cfg"
	root.add_child(game)
	await _frames(20)
	# PT_RUN (and PT_FROM): run PT_RUN from floor 1 (or PT_FROM), to look again at one run
	if OS.get_environment("PT_RUN") != "":
		game.state.world_run = int(OS.get_environment("PT_RUN"))
		game.load_floor(maxi(1, int(OS.get_environment("PT_FROM"))), true)
		await _frames(20)
	var run := int(game.state.get("world_run", 0))
	var floors := 0
	var t0 := Time.get_ticks_msec()
	while true:
		var n := int(game.state.floor)
		var f := await _floor()
		floors += 1
		report.append("%s run %d E%d: %s" % [cid, run, n, f.text])
		print("PT %s run %d E%d: %s" % [cid, run, n, f.text])
		if not f.ok:
			stuck += 1
			break
		if f.final:
			report.append("%s run %d: KAPITEL 1 GESCHAFFT nach %d Etagen (%.0f s Rechenzeit), Lebensgrenze %d, Treffer eingesteckt %d" % [cid, run, floors, (Time.get_ticks_msec() - t0) / 1000.0, int(game.state.max_hp), hits_taken])
			break
		# the portal's result screen: act goes on to the next floor
		game.act()
		for i in range(400):
			await _frames(1)
			if int(game.state.floor) == n + 1 and not game.state.won and not game.W.is_empty():
				break
		await _frames(10)
		if int(game.state.floor) != n + 1:
			report.append("%s run %d: Etage %d lädt nicht" % [cid, run, n + 1])
			stuck += 1
			break
	game.queue_free()
	await process_frame
	await process_frame


## One floor: works until the portal is used. {ok, final, text}
func _floor() -> Dictionary:
	var W: Dictionary = game.W
	var fights := 0
	var mobs_seen := 0
	var ended := 0
	var keys := 0
	var gates := 0
	var riddles := 0
	var forced_riddles := 0
	var kinds := {}
	for r: Dictionary in W.rooms:
		kinds[str(r.get("gtype", r.type))] = int(kinds.get(str(r.get("gtype", r.type)), 0)) + 1
	for round in range(ROUNDS):
		var reach := _reach()
		# the portal, once the boss fell
		var portal := _ent_where(func(e: Dictionary) -> bool: return str(e.type) == "portal" and e.get("active", false))
		if not portal.is_empty() and _near_reach(reach, Vector2(portal.x, portal.y), 2):
			_stand_by(reach, Vector2(portal.x, portal.y))
			await _frames(4)
			var final: bool = W.final
			game.act()
			await _frames(6)
			if final or game.state.won or not (game.state.get("over", {}) as Dictionary).is_empty():
				return {"ok": true, "final": final, "text": _floor_text(fights, mobs_seen, ended, keys, gates, riddles, forced_riddles, kinds)}
		# a key on the floor
		var key := _ent_where(func(e: Dictionary) -> bool: return str(e.type) == "key" and not e.get("taken", false) and reach.has(_cell_of(Vector2(e.x, e.y))))
		if not key.is_empty():
			_go(Vector2(key.x, key.y))
			await _frames(4)
			if not key.get("taken", false):
				_note_moved(Vector2(key.x, key.y), "Schlüssel " + str(key.key))
				await _trace(Vector2(key.x, key.y))
			keys += 1
			continue
		# a chest holding a key
		var kchest := _ent_where(func(e: Dictionary) -> bool: return str(e.type) == "chest" and str(e.get("state", "")) == "" and (e.get("loot", {}) as Dictionary).has("key") and _near_reach(reach, Vector2(e.x, e.y), 1))
		if not kchest.is_empty():
			_stand_by(reach, Vector2(kchest.x, kchest.y))
			await _frames(3)
			game.act()
			await _frames(8)
			if str(kchest.get("state", "")) == "":
				kchest.state = "empty"
			keys += 1
			continue
		# a locked gate we hold the key for
		var opened := false
		for d: Dictionary in W.doors:
			if str(d.kind) == "lock" and not d.unlocked and bool(game.state.keys.get(d.key, false)) and _near_reach(reach, Vector2(d.cx, d.cy), 2):
				_stand_by(reach, Vector2(d.cx, d.cy))
				await _frames(3)
				game.act()
				await _frames(4)
				if not d.unlocked:
					report.append("  Tor %s ging mit Schlüssel nicht auf" % str(d.key))
					d.unlocked = true
				gates += 1
				opened = true
				break
		if opened:
			continue
		# a room not yet cleared that we can walk into
		var room := _room_to_enter(reach)
		if not room.is_empty():
			var spot: Vector2 = room.spot
			_go(spot)
			await _frames(6)
			var r: Dictionary = room.room
			if r.fight:
				fights += 1
				var res := await _fight(r)
				mobs_seen += int(res.mobs)
				ended += int(res.ended)
			elif not r.cleared:
				# a room that starts no fight (no monsters): it counts as seen
				r.cleared = true
			continue
		# a riddle gate in the way
		var solved := await _solve_a_riddle(reach)
		if solved > 0:
			riddles += 1
			forced_riddles += solved - 1
			continue
		break
	_explain_stuck()
	var boss_room: Dictionary = {}
	for r: Dictionary in W.rooms:
		if str(r.type) == "boss":
			boss_room = r
	return {"ok": false, "final": false, "text": "STECKT FEST (Boss %s, Portal %s, Räume frei %d von %d)" % [
		"besiegt" if game.state.boss_dead else ("nicht erreichbar" if not boss_room.is_empty() and not _room_in_reach(boss_room, _reach()) else "lebt"),
		"offen" if game.state.boss_dead else "zu", W.rooms.filter(func(r: Dictionary) -> bool: return r.cleared).size(), W.rooms.size()]}


func _floor_text(fights: int, mobs: int, ended: int, keys: int, gates: int, riddles: int, forced: int, kinds: Dictionary) -> String:
	var jump: Array = []
	for r: Dictionary in game.W.rooms:
		if str(r.get("gtype", "")) == "jump":
			jump.append(str(r.name))
	return "durch: %d Kämpfe, %d Gegner%s, %d Schlüssel, %d Tore, %d Rätseltore%s, Rätselräume %s" % [fights, mobs,
		(" (%d nach langer Zeit beendet)" % ended) if ended > 0 else "", keys, gates, riddles, (" (%d per Hand)" % forced) if forced > 0 else "", str(jump)]


## Strikes the room's monsters with the hero's own hits until they fall. {mobs, ended}
func _fight(r: Dictionary) -> Dictionary:
	var seen := 0
	var ended := 0
	for i in range(FIGHT_FRAMES):
		var here: Array = (game.mobs as Array).filter(func(m: Dictionary) -> bool: return int(m.room) == int(r.index) and float(m.hp) > 0.0)
		for m: Dictionary in here:
			if not m.has("_pt_seen"):
				m["_pt_seen"] = true
				seen += 1
		if not r.fight and here.is_empty():
			break
		if i % 2 == 0:
			for m: Dictionary in here:
				if game._hittable(m):
					game._damage_mob(m, Vector2.ZERO, 12.0)
		await _frames(1)
	var left: Array = (game.mobs as Array).filter(func(m: Dictionary) -> bool: return int(m.room) == int(r.index) and float(m.hp) > 0.0)
	if r.fight:
		for m: Dictionary in left:
			m.hp = 0.0
			ended += 1
		await _frames(30)
		if r.fight:
			game._clear_room(r, Vector2(game.player.x, game.player.y))
			report.append("  Raum %s (%s) blieb verriegelt, von Hand freigegeben" % [r.name, str((r.get("file", {}) as Dictionary).get("id", ""))])
	return {"mobs": seen, "ended": ended}


## Solves one closed riddle gate next to the reach by its pieces; 1 = solved by them, 2 = had to be
## set solved, 0 = none found.
func _solve_a_riddle(reach: Dictionary) -> int:
	for d: Dictionary in game.W.doors:
		if str(d.kind) != "puzzle" or not game._door_closed(d) or not _near_reach(reach, Vector2(d.cx, d.cy), 2):
			continue
		var gid := str(d.group)
		var pieces: Array = (game.W.ents as Array).filter(func(e: Dictionary) -> bool: return str(e.get("group", "")) == gid)
		pieces.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("order", 0)) < int(b.get("order", 0)))
		var seq: Array = (game.W.groups.get(gid, {}) as Dictionary).get("sequence", [])
		if not seq.is_empty():
			var ordered: Array = []
			for idx: Variant in seq:
				for e: Dictionary in pieces:
					if int(e.get("index", -1)) == int(idx) or int(e.get("order", -1)) == int(idx):
						ordered.append(e)
			if ordered.size() == pieces.size():
				pieces = ordered
		for e: Dictionary in pieces:
			if not _near_reach(_reach(), Vector2(e.x, e.y), 2):
				continue
			match str(e.type):
				"brazier", "torch":
					_stand_by(_reach(), Vector2(e.x, e.y))
					await _frames(2)
					game.fire_hits_brazier(Vector2(e.x, e.get("wy", e.y)))
					game.act()
					await _frames(3)
				"plate":
					_go(Vector2(e.x, e.y))
					await _frames(6)
					_go(Vector2(e.x, e.y + 140.0))
					await _frames(3)
		await _frames(4)
		if not game._door_closed(d):
			return 1
		game._solve_group(gid)
		await _frames(2)
		report.append("  Rätseltor (Gruppe %s, %s) musste von Hand gelöst werden" % [gid, (game.W.groups.get(gid, {}) as Dictionary).get("kind", "?")])
		return 2
	return 0


## Notes once per spot when the hero did not stay where he was put (a fall, a push): where and what was there.
var _moved_noted := {}
func _note_moved(want: Vector2, what: String) -> void:
	var now := Vector2(game.player.x, game.player.y)
	var c := _cell_of(want)
	if _moved_noted.has(c):
		return
	_moved_noted[c] = true
	var around: Array = []
	for dy in range(-1, 2):
		var row := ""
		for dx in range(-1, 2):
			row += str(game._cell(c.x + dx, c.y + dy))
		around.append(row)
	report.append("  %s nicht genommen: Held sollte bei %s stehen, steht bei %s (Abstand %.0f), Felder ringsum %s, Fußkasten frei %s, tot %s" % [what, str(want), str(now), now.distance_to(want), "/".join(PackedStringArray(around)), not game.box_blocked(Rect2(want.x - 22.0, want.y - 12.0, 44.0, 24.0), true), str(game.state.dead)])


## Puts the hero at p once more and notes where he goes frame by frame, and what lies around p.
var _traced := {}
func _trace(p: Vector2) -> void:
	if _traced.has(_cell_of(p)):
		return
	_traced[_cell_of(p)] = true
	var near: Array = []
	for e: Dictionary in game.W.ents:
		if Vector2(e.x, e.y).distance_to(p) < 150.0:
			near.append("%s%s" % [e.type, ("(" + str(e.get("dir", "")) + str(e.get("cells", "")) + ")") if str(e.type) == "launch" else ""])
	game.player.x = p.x
	game.player.y = p.y
	var way: Array = []
	for i in range(8):
		await process_frame
		way.append("%s:%s" % [str(_cell_of(Vector2(game.player.x, game.player.y))), str(game.state.room)])
	report.append("    Spur: Raum %s (%s), daneben %s, Weg %s, Wurf %s" % [str(game._room_at_world(p.x, p.y)), str(game.W.rooms[maxi(0, game._room_at_world(p.x, p.y))].type), str(near), " ".join(PackedStringArray(way)), str(game.launch_pads.flying()) if game.launch_pads != null else "-"])


## What closes the way when the hero is stuck: gates next to his reach, keys, rooms, the boss room.
func _explain_stuck() -> void:
	var reach := _reach()
	var keys: Array = []
	for k: Variant in game.state.keys:
		if game.state.keys[k]:
			keys.append(str(k))
	report.append("  Schlüssel in der Hand: %s, Held bei %s, Raum %d, tot %s, Ende %s, Angebot %d" % [str(keys), str(_cell_of(Vector2(game.player.x, game.player.y))), int(game.state.room), str(game.state.dead), str(game.state.get("over", {})), (game.state.get("offer", []) as Array).size()])
	for d: Dictionary in game.W.doors:
		if not game._door_closed(d):
			continue
		var near := _near_reach(reach, Vector2(d.cx, d.cy), 2)
		report.append("  zu: Tür %s %s->%s (%s/%s) Schlüssel %s, neben dem Weg: %s, Kampf %s/%s" % [d.kind, str(game.W.rooms[d.a].name), str(game.W.rooms[d.b].name), str(game.W.rooms[d.a].type), str(game.W.rooms[d.b].type), str(d.get("key", "")), near, game.W.rooms[d.a].fight, game.W.rooms[d.b].fight])
	for e: Dictionary in game.W.ents:
		if str(e.type) == "key" and not e.get("taken", false):
			report.append("  Schlüssel %s liegt bei %s, erreichbar: %s, %s" % [str(e.key), str(_cell_of(Vector2(e.x, e.y))), reach.has(_cell_of(Vector2(e.x, e.y))), str(e)])
		if str(e.type) == "chest" and (e.get("loot", {}) as Dictionary).has("key") and str(e.get("state", "")) == "":
			report.append("  Schlüsseltruhe %s bei %s, erreichbar: %s, Mimik %s" % [str(e.loot.key), str(_cell_of(Vector2(e.x, e.y))), _near_reach(reach, Vector2(e.x, e.y), 1), e.get("mimic", false)])
	for r: Dictionary in game.W.rooms:
		if not r.cleared:
			report.append("  nicht frei: %s (%s), erreichbar: %s, Kampf %s, Gegner %d, drop %s" % [str(r.name), str(r.get("gtype", r.type)), _room_in_reach(r, reach), r.fight, (game.mobs as Array).filter(func(m: Dictionary) -> bool: return int(m.room) == int(r.index)).size(), str(r.get("drop", ""))])


# ---------- where the hero can walk ----------

func _cell_of(p: Vector2) -> Vector2i:
	return Vector2i(int(floor(p.x / C)), int(floor((p.y - 10.0) / C)))


func _go(p: Vector2) -> void:
	game.player.x = p.x
	game.player.y = p.y
	_hold_at = p
	_hold_left = 3
	if game.player.has("vel"):
		game.player.vel = Vector2.ZERO


## True when the hero's foot box fits at the middle of cell c (breakable pieces do not count: he smashes them).
func _free(c: Vector2i) -> bool:
	if game._cell_blocked(c.x, c.y, false):
		return false
	var box := Rect2((c.x + 0.5) * C - 22.0, (c.y + 0.5) * C - 2.0, 44.0, 24.0)
	for s: Rect2 in game.solid_grid.get(c.y * int(game.W.cols) + c.x, []):
		if s.intersects(box):
			return false
	return true


## Every cell a walk from the hero reaches.
func _reach() -> Dictionary:
	var start := _cell_of(Vector2(game.player.x, game.player.y))
	var out := {start: true}
	var todo: Array[Vector2i] = [start]
	while not todo.is_empty():
		var c: Vector2i = todo.pop_back()
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n := c + d
			if out.has(n) or not _free(n):
				continue
			out[n] = true
			todo.append(n)
	return out


func _near_reach(reach: Dictionary, p: Vector2, r: int) -> bool:
	var c := _cell_of(p)
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if reach.has(c + Vector2i(dx, dy)):
				return true
	return false


## Puts the hero on the reachable cell nearest to `p` (below it when it can, to face it).
func _stand_by(reach: Dictionary, p: Vector2) -> void:
	var best := Vector2i(-1, -1)
	var bd := INF
	var c := _cell_of(p)
	for dy in range(-3, 4):
		for dx in range(-3, 4):
			var n := c + Vector2i(dx, dy)
			if not reach.has(n):
				continue
			var d := Vector2((n.x + 0.5) * C, (n.y + 0.5) * C).distance_to(p) + (0.0 if dy >= 0 else 30.0)
			if d < bd:
				bd = d
				best = n
	if best.x >= 0:
		_go(Vector2((best.x + 0.5) * C, (best.y + 0.5) * C + 10.0))


func _ent_where(f: Callable) -> Dictionary:
	for e: Dictionary in game.W.ents:
		if f.call(e):
			return e
	return {}


func _room_in_reach(r: Dictionary, reach: Dictionary) -> bool:
	for c: Vector2i in r.cells:
		if reach.has(c):
			return true
	return false


## The nearest room not yet cleared with a reachable spot well inside it: {room, spot}.
func _room_to_enter(reach: Dictionary) -> Dictionary:
	var me := Vector2(game.player.x, game.player.y)
	var best: Dictionary = {}
	var bd := INF
	for r: Dictionary in game.W.rooms:
		if r.cleared:
			continue
		for c: Vector2i in r.cells:
			if not reach.has(c):
				continue
			var p := Vector2((c.x + 0.5) * C, (c.y + 0.5) * C + 10.0)
			if not game._fully_inside(r, p.x, p.y):
				continue
			var d := p.distance_to(me)
			if d < bd:
				bd = d
				best = {"room": r, "spot": p}
			break
	return best
