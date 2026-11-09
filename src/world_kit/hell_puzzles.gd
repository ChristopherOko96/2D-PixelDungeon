extends RefCounted
## The hell's puzzle pieces (docs/HOELLE-RAETSEL.de.md), placed in Weltbauer rooms of the world "hell".
## Everything lies on plain floor: this module decides which cells are hot (a raised bridge over a shaft,
## a wet lava channel, a firing vent, a flood, a demon eye's sight) and burns a hero standing there: one
## hit of the depth (hell_game _hurt) and back to the room's rune. Pieces of one riddle share a group.
##   hell_bridge  nr, up          a chain bridge over a shaft: hot while up
##   hell_winch   sets: [nr ...]  E toggles every bridge and shield of its group whose nr it lists
##   hell_shield  nr, down        an iron shield on a chain: while down it hides the cells behind it from eyes
##   hell_vent    period?         a flame vent of the Flammentakt: fires on beat 0, glows on the last
##   hell_flood   (none)          flood floor: hot in the flood of the room's ebb-warn-flood round
##   hell_stone   (none)          basalt: always safe (drawn only)
##   hell_channel wet: "!A|B"     a lava channel: wet (hot) by the valves of its group; a lowered bridge carries
##   hell_valve   label: "A"      E opens or shuts valve A of the group
##   hell_eye     dir, open, closed, off, always   a demon eye in a wall: sees its row or column up to cover
##   hell_thorns  (none)          first step costs one thorn heart (thorns.hits x dmg LP, never below 1 LP)
##   hell_blood_gate              solid until E pays one thorn heart
##   hell_blood_bowl              counts the room's paid hearts; the Schatz shifts its tier by the blood paths
##   hell_pipe    shape I/L, rot   a turning channel of the Lavaschleusen (E turns the one under the hero)
##   hell_spout   dir             the demon mouth the lava leaves by
##   hell_forge   (none)          the forge the lava must reach; then the group is solved
##   hell_sluice  (none)          E lets the lava run
##   hell_rune    (none)          where a burnt hero stands again; E sets the room's riddle back
## The price rooms of the Beuteordnung (docs/BEUTEORDNUNG.de.md 6):
##   hell_sacrifice                Opferstein: each sacrifice costs two hits of LP and pays more than the last
##   hell_pact    offer 0/1/2      Teufelspakt: one of three altars, paid with life cap for good
##   hell_pit_altar                Opfergrube: E calls a wave; after each one the Schatz rises a tier

const DATA_PATH := "res://assets/data/world_hell_puzzles.json"
const RewardRules = preload("res://src/progress/reward_rules.gd")
const C := 96.0
const FLAT := ["hell_bridge", "hell_vent", "hell_flood", "hell_stone", "hell_channel", "hell_thorns", "hell_pipe", "hell_rune"]
const SOLID := ["hell_winch", "hell_valve", "hell_shield", "hell_blood_gate", "hell_blood_bowl", "hell_spout", "hell_forge", "hell_sluice",
	"hell_sacrifice", "hell_pact", "hell_pit_altar"]
const KINDS := ["hell_bridge", "hell_vent", "hell_flood", "hell_stone", "hell_channel", "hell_thorns", "hell_pipe", "hell_rune",
	"hell_winch", "hell_valve", "hell_shield", "hell_blood_gate", "hell_blood_bowl", "hell_spout", "hell_forge", "hell_sluice", "hell_eye",
	"hell_sacrifice", "hell_pact", "hell_pit_altar"]
## What the three altars of a Teufelspakt offer.
const PACT_OFFERS := ["Ein episches Stück deiner Klasse, nie verflucht", "Zwei Dämonensegen", "Drei Runen und ein Aufwertungsstein"]
## n, e, s, w as direction numbers 0..3.
const DV := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
const DIR_OF := {"n": 0, "e": 1, "s": 2, "w": 3}
## The openings of a pipe by kind and turn.
const OPEN := {"I": [[1, 3], [0, 2]], "L": [[0, 1], [1, 2], [2, 3], [3, 0]]}

var g: Node
var cfg: Dictionary = {}
var pieces: Array = []
var solid_at: Dictionary = {}
var flat_at: Dictionary = {}
var rooms: Dictionary = {}
## Valves by group: {group: {label: open}}.
var valves: Dictionary = {}
## Thorn hearts paid by room.
var paid: Dictionary = {}
## The lava's way through the pipes after a sluice, by group: {cells: [Vector2i], left: s, ok: bool}.
var flows: Dictionary = {}
var last_cell := Vector2i(-99999, -99999)
var _clock := 0.0
var _burn_wait := 0.0


func _init(game: Node, data: Dictionary = {}) -> void:
	g = game
	cfg = data if not data.is_empty() else load_config()


static func load_config() -> Dictionary:
	if not FileAccess.file_exists(DATA_PATH):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	return parsed if parsed is Dictionary else {}


## True when `wet` (OR of AND terms, "!" negates: "!A", "A|B", "A&!B") holds for `open` {label: bool}.
static func wet_of(wet: String, open: Dictionary) -> bool:
	if wet.strip_edges() == "":
		return true
	for term: String in wet.split("|"):
		var all := true
		for lit: String in term.split("&"):
			var s := lit.strip_edges()
			var neg := s.begins_with("!")
			var name := s.trim_prefix("!")
			if bool(open.get(name, false)) == neg:
				all = false
		if all:
			return true
	return false


## The openings (direction numbers) of a pipe.
static func pipe_open(kind: String, rot: int) -> Array:
	var turns: Array = OPEN.get(kind, OPEN.I)
	return turns[posmod(rot, turns.size())]


## The lava's way from `start` (first pipe cell) entering from direction `from_dir` through `pipe_at`
## (Vector2i -> {shape, rot}) to `goal`: {cells, ok}. ok when it enters the goal cell.
static func trace_flow(start: Vector2i, from_dir: int, pipe_at: Callable, goal: Vector2i, most: int = 200) -> Dictionary:
	var at := start
	var from := from_dir
	var cells: Array = []
	for i in range(most):
		if at == goal:
			return {"cells": cells, "ok": true}
		var p: Dictionary = pipe_at.call(at)
		if p.is_empty():
			return {"cells": cells, "ok": false}
		var o := pipe_open(str(p.get("shape", "I")), int(p.get("rot", 0)))
		if not o.has(from):
			return {"cells": cells, "ok": false}
		cells.append(at)
		var out: int = o[0] if int(o[1]) == from else o[1]
		at += DV[out]
		from = (out + 2) % 4
	return {"cells": cells, "ok": false}


## Phase of a vent at cell c on beat `tick`: 0 fires, period - 1 glows.
static func vent_phase(c: Vector2i, tick: int, period: int) -> int:
	return posmod(tick - c.x - c.y, maxi(2, period))


## "ebb", "warn" or "flood" at time t of a flood round.
static func flood_phase(t: float, cycle: float, ebb: float, warn: float) -> String:
	var p := fposmod(t, maxf(0.1, cycle))
	return "ebb" if p < ebb else ("warn" if p < warn else "flood")


## Whether an eye is open (2), about to open (1) or shut (0) on beat `tick`.
static func eye_state(tick: int, open: int, closed: int, off: int) -> int:
	var p := posmod(tick + off, open + closed)
	return 2 if p < open else (1 if p == open + closed - 1 else 0)


func _cols() -> int:
	return int(g.W.cols)


func _key(c: Vector2i) -> int:
	return c.y * _cols() + c.x


static func cell_of(e: Dictionary) -> Vector2i:
	return Vector2i(int(floor(float(e.x) / C)), int(floor((float(e.y) - 8.0) / C)))


static func centre(c: Vector2i) -> Vector2:
	return (Vector2(c) + Vector2(0.5, 0.5)) * C


# ---------- the floor ----------

## Takes up the floor's pieces (after a floor is loaded).
func setup() -> void:
	pieces = (g.W.ents as Array).filter(func(e: Dictionary) -> bool: return KINDS.has(str(e.type)))
	valves = {}
	paid = {}
	flows = {}
	rooms = {}
	last_cell = Vector2i(-99999, -99999)
	for e: Dictionary in pieces:
		e.home = cell_of(e)
		rooms[int(e.get("room", 0))] = true
		e.start_up = bool(e.get("up", false))
		e.start_down = bool(e.get("down", false))
		e.start_rot = int(e.get("rot", 0))
		if str(e.type) == "hell_valve":
			var vg: Dictionary = valves.get(str(e.get("group", "")), {})
			vg[str(e.get("label", "A"))] = bool(e.get("open", false))
			valves[str(e.get("group", ""))] = vg
	_index()


func _index() -> void:
	solid_at = {}
	flat_at = {}
	for e: Dictionary in pieces:
		if e.get("gone", false):
			continue
		var k := _key(cell_of(e))
		if SOLID.has(str(e.type)):
			if str(e.type) == "hell_blood_gate" and bool(e.get("open", false)):
				continue
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


## True when room `r` holds hell puzzle pieces.
func puzzle_room(r: int) -> bool:
	return rooms.has(r)


## True when a box (world px) touches a solid piece in its cell.
func box_blocked(box: Rect2) -> bool:
	if solid_at.is_empty():
		return false
	for cy in range(int(floor(box.position.y / C)), int(floor((box.end.y - 1.0) / C)) + 1):
		for cx in range(int(floor(box.position.x / C)), int(floor((box.end.x - 1.0) / C)) + 1):
			var e: Variant = solid_at.get(cy * _cols() + cx)
			if e != null:
				var c := Vector2i(cx, cy)
				if Rect2(Vector2(c) * C + Vector2(8, 4), Vector2(C - 16, C - 8)).intersects(box):
					return true
	return false


# ---------- what is hot ----------

func _vent_tick() -> int:
	return int(floor(_clock / maxf(0.05, float((cfg.get("vent", {}) as Dictionary).get("beat", 0.62)))))


func _eye_tick() -> int:
	return int(floor(_clock / maxf(0.05, float((cfg.get("eye", {}) as Dictionary).get("beat", 0.7)))))


func _flood_now() -> String:
	var f: Dictionary = cfg.get("flood", {})
	return flood_phase(_clock, float(f.get("cycle", 3.2)), float(f.get("ebb", 1.1)), float(f.get("warn", 1.6)))


func _bridge_down_at(c: Vector2i) -> bool:
	var b := _flat(c, "hell_bridge")
	return not b.is_empty() and not bool(b.get("up", false))


func _channel_wet(e: Dictionary) -> bool:
	return wet_of(str(e.get("wet", "")), valves.get(str(e.get("group", "")), {}))


## True when cell c burns the hero now, and why.
func hot(c: Vector2i) -> String:
	var b := _flat(c, "hell_bridge")
	var ch := _flat(c, "hell_channel")
	if not ch.is_empty() and _channel_wet(ch) and (b.is_empty() or bool(b.get("up", false))):
		return "von der Lava in der Rinne verbrannt"
	if ch.is_empty() and not b.is_empty() and bool(b.get("up", false)):
		return "in den Lavaschacht gestürzt"
	var v := _flat(c, "hell_vent")
	if not v.is_empty() and vent_phase(c, _vent_tick(), int(v.get("period", (cfg.get("vent", {}) as Dictionary).get("period", 3)))) == 0:
		return "vom Flammenschlot verbrannt"
	if not _flat(c, "hell_flood").is_empty() and _flood_now() == "flood":
		return "von der Lavaflut verschlungen"
	if seen(c):
		return "vom Dämonenauge entzündet"
	return ""


## True when an open demon eye sees cell c (its row or column, up to the first cover).
func seen(c: Vector2i) -> bool:
	for e: Dictionary in pieces:
		if str(e.type) != "hell_eye":
			continue
		if not bool(e.get("always", false)):
			var ec: Dictionary = cfg.get("eye", {})
			if eye_state(_eye_tick(), int(e.get("open", ec.get("open", 2))), int(e.get("closed", ec.get("closed", 2))), int(e.get("off", 0))) != 2:
				continue
		var at := cell_of(e)
		var d: Vector2i = DV[int(DIR_OF.get(str(e.get("dir", "e")), 1))]
		if (d.x != 0 and at.y != c.y) or (d.y != 0 and at.x != c.x):
			continue
		var p := at + d
		for i in range(64):
			if _covers(p):
				break
			if p == c:
				return true
			p += d
	return false


## True when cell p hides what lies behind it from an eye: a wall, a solid prop or piece, a lowered shield.
func _covers(p: Vector2i) -> bool:
	if p.x < 0 or p.y < 0 or p.x >= _cols() or p.y >= int(g.W.rows):
		return true
	if g._cell_blocked(p.x, p.y, false):
		return true
	var s: Variant = solid_at.get(_key(p))
	if s != null:
		return str(s.type) != "hell_shield" or bool(s.get("down", false))
	var mid := centre(p) + Vector2(0, 10)
	for r: Rect2 in g.solid_grid.get(_key(p), []):
		if r.grow(6.0).has_point(mid):
			return true
	return false


# ---------- each frame ----------

func update(dt: float) -> void:
	_clock += dt
	_burn_wait = maxf(0.0, _burn_wait - dt)
	for group: String in flows.keys():
		var f: Dictionary = flows[group]
		if not bool(f.ok):
			f.left = float(f.left) - dt
			if float(f.left) <= 0.0:
				flows.erase(group)
	if pieces.is_empty():
		return
	_watch_pits()
	var room := int(g.state.room)
	if not rooms.has(room) or float(g.state.get("dead", 0.0)) > 0.0:
		return
	var here: Vector2i = g.player_cell()
	if here != last_cell:
		if last_cell.x > -99999:
			_stepped(here)
		last_cell = here
	var why := hot(here)
	if why != "" and _burn_wait <= 0.0:
		_burn(why)


func _stepped(to: Vector2i) -> void:
	var thorn := _flat(to, "hell_thorns")
	if not thorn.is_empty() and not bool(thorn.get("trod", false)):
		thorn.trod = true
		_pay("Die Dornen reißen dich")


## One thorn heart: thorns.hits hits of the depth, never below 1 LP; the room's blood bowl counts it.
func _pay(text: String) -> void:
	var cost := int((cfg.get("thorns", {}) as Dictionary).get("hits", 2)) * int(g.hit_scale())
	var take := mini(cost, maxi(0, int(g.state.hp) - 1))
	if take > 0:
		g.state.hp = int(g.state.hp) - take
		g.state.flash = 0.2
	var room := int(g.state.room)
	paid[room] = int(paid.get(room, 0)) + 1
	_shift_hoards(room)
	g.toast("%s. Blutpreis bisher: %d Herz%s." % [text, int(paid[room]), "" if int(paid[room]) == 1 else "en"])


## The Schatz of a blood room counts the paid hearts by the Beuteordnung's paths: cheap -1, middle 0, dear +1.
func _shift_hoards(room: int) -> void:
	if not pieces.any(func(e: Dictionary) -> bool: return str(e.type) == "hell_blood_bowl" and int(e.get("room", -1)) == room):
		return
	var paths: Array = (RewardRules.cfg().get("blood", {}) as Dictionary).get("paths", [])
	var shift := -1
	for p: Dictionary in paths:
		if int(paid.get(room, 0)) >= int(p.hearts):
			shift = int(p.shift)
	for c: Dictionary in g.W.ents:
		if str(c.type) == "chest" and c.has("hoard_tier") and int(c.get("room", -1)) == room:
			c.hoard_shift = shift
			c.legendary_twice = int(c.hoard_tier) >= 5 and shift > 0


## Burnt: one hit, back to the room's rune.
func _burn(why: String) -> void:
	_burn_wait = 0.9
	var hits := int((cfg.get("burn", {}) as Dictionary).get("hits", 1))
	g.state.inv = 0.0
	g._hurt(why, hits)
	var room := int(g.state.room)
	if float(g.state.get("dead", 0.0)) > 0.0:
		return
	for e: Dictionary in pieces:
		if str(e.type) == "hell_rune" and int(e.get("room", -1)) == room:
			g.place_player(centre(cell_of(e)) + Vector2(0, 10))
			last_cell = cell_of(e)
			g.toast("Verbrannt! Zurück an die Rune.")
			return


# ---------- using pieces ----------

func interactables() -> Array:
	var out: Array = []
	var reach := float(cfg.get("reach", 120.0))
	var room := int(g.state.room)
	var here: Vector2i = g.player_cell()
	for e: Dictionary in pieces:
		if int(e.get("room", -1)) != room:
			continue
		var p := Vector2(float(e.x), float(e.y) + 10.0)
		match str(e.type):
			"hell_winch":
				out.append({"e": e, "label": "Winde drehen", "p": p, "r": reach})
			"hell_valve":
				var open := bool((valves.get(str(e.get("group", "")), {}) as Dictionary).get(str(e.get("label", "A")), false))
				out.append({"e": e, "label": "Ventil %s %s" % [str(e.get("label", "A")), "schließen" if open else "öffnen"], "p": p, "r": reach})
			"hell_sluice":
				if not _solved(e):
					out.append({"e": e, "label": "Schleusenhebel ziehen", "p": p, "r": reach})
			"hell_blood_gate":
				if not bool(e.get("open", false)):
					out.append({"e": e, "label": "Blutgitter: ein Herz zahlen", "p": p, "r": reach})
			"hell_pipe":
				if cell_of(e) == here and not _solved(e):
					out.append({"e": e, "label": "Rinne drehen", "p": p, "r": float(cfg.get("pipe_reach", 70.0))})
			"hell_rune":
				out.append({"e": e, "label": "Rune berühren: das Rätsel zurücksetzen", "p": p, "r": 80.0})
			"hell_sacrifice":
				var step := int(e.get("step", 0))
				if step < 4:
					out.append({"e": e, "label": "Opfern (%d LP): %s" % [_price(), ["Gold", "ein Stück", "ein besseres Stück", "ein Stück und ein Lebensherz"][step]], "p": p, "r": reach})
			"hell_pact":
				if not _pact_done(int(e.get("room", -1))):
					out.append({"e": e, "label": "Pakt (−%d LP Lebensgrenze): %s" % [_price(), PACT_OFFERS[clampi(int(e.get("offer", 0)), 0, 2)]], "p": p, "r": reach})
			"hell_pit_altar":
				if not bool(e.get("fighting", false)) and not bool(e.get("spent", false)):
					var wave := int(e.get("wave", 0))
					if wave < 5:
						out.append({"e": e, "label": "Welle %d rufen" % (wave + 1), "p": p, "r": reach})
					if wave > 0:
						out.append({"e": {"type": "hell_pit_altar", "take": true, "ref": e}, "label": "Schatz der Stufe %d nehmen" % wave, "p": p + Vector2(0, 60), "r": reach})
	return out


func use(e: Dictionary) -> bool:
	var type := str(e.get("type", ""))
	if not KINDS.has(type):
		return false
	var group := str(e.get("group", ""))
	match type:
		"hell_winch":
			var sets: Array = e.get("sets", [])
			for q: Dictionary in pieces:
				if str(q.get("group", "")) == group and sets.has(int(q.get("nr", -1))):
					if str(q.type) == "hell_bridge":
						q.up = not bool(q.get("up", false))
					elif str(q.type) == "hell_shield":
						q.down = not bool(q.get("down", false))
			e.pulled = _clock
			var raised := pieces.filter(func(q: Dictionary) -> bool: return str(q.type) == "hell_bridge" and str(q.get("group", "")) == group and bool(q.get("up", false))).size()
			g.toast("Ketten rasseln. %s" % ("Alle Brücken liegen unten." if raised == 0 else "%d Brücke%s hängt noch oben." % [raised, "" if raised == 1 else "n"]))
		"hell_valve":
			var vg: Dictionary = valves.get(group, {})
			var label := str(e.get("label", "A"))
			vg[label] = not bool(vg.get(label, false))
			valves[group] = vg
			e.turned = _clock
			g.toast("Ventil %s %s. Die Lava sucht sich einen neuen Weg." % [label, "auf" if bool(vg[label]) else "zu"])
		"hell_sluice":
			_run_sluice(group)
		"hell_blood_gate":
			if not bool(e.get("open", false)):
				e.open = true
				_index()
				_pay("Das Gitter trinkt dein Blut und hebt sich")
		"hell_pipe":
			e.rot = int(e.get("rot", 0)) + 1
			flows.erase(group)
		"hell_rune":
			reset_room(int(e.get("room", -1)))
			g.toast("Die Rune glüht auf. Ketten, Ventile und Rinnen stehen wieder wie am Anfang.")
		"hell_sacrifice":
			_sacrifice(e)
		"hell_pact":
			_pact(e)
		"hell_pit_altar":
			if bool(e.get("take", false)):
				var altar: Dictionary = e.ref
				if int(altar.get("wave", 0)) > 0 and not bool(altar.get("spent", false)):
					_pit_chest(altar, int(altar.wave))
			else:
				_pit(e)
	return true


# ---------- the price rooms (docs/BEUTEORDNUNG.de.md 6) ----------

## The price of one sacrifice or pact: price_hits hits of the depth.
func _price() -> int:
	return int((RewardRules.cfg().get("sacrifice", {}) as Dictionary).get("price_hits", 2)) * int(g.hit_scale())


func _at(e: Dictionary, k: int) -> Vector2:
	return Vector2(float(e.x) - 60.0 + 60.0 * (k % 3), float(e.y) + 50.0 + 30.0 * floorf(k / 3.0))


## Opferstein: four sacrifices of current life, each paying more; never one that would kill.
func _sacrifice(e: Dictionary) -> void:
	var step := int(e.get("step", 0))
	if step >= 4:
		return
	if int(g.state.hp) <= _price():
		g.toast("Der Stein will %d LP. So viel Leben hast du nicht mehr." % _price())
		return
	g.state.hp = int(g.state.hp) - _price()
	g.state.flash = 0.2
	e.step = step + 1
	var t := int(g.depth())
	var items: Variant = g.get("story_items")
	match step:
		0:
			g.gold_loot.spew(Vector2(float(e.x), float(e.y) - 10.0), RewardRules.gold(RewardRules.value(t, 2)))
		1:
			if items != null: items.reward_item(_at(e, 0), RewardRules.min_rarity(RewardRules.value(t, 3)), true, true)
		2:
			if items != null:
				items.reward_item(_at(e, 0), RewardRules.min_rarity(RewardRules.value(t, 4)), true, true)
				items.reward_stack(_at(e, 1), "upgrade_stone")
		3:
			if items != null: items.reward_item(_at(e, 0), RewardRules.rarity_up(RewardRules.min_rarity(RewardRules.value(t, 5))), true, true)
			g.drop_life_heart(RewardRules.puzzle_life(t, 5), int(e.get("room", g.state.room)), _at(e, 2))
	g.toast(["Der Stein trinkt. Gold quillt hervor.", "Der Stein trinkt. Er gibt ein Stück heraus.", "Der Stein trinkt tiefer. Ein besseres Stück und ein Aufwertungsstein.", "Das letzte Opfer. Der Stein zerspringt und gibt sein Herz frei."][step])


func _pact_done(room: int) -> bool:
	return pieces.any(func(q: Dictionary) -> bool: return str(q.type) == "hell_pact" and int(q.get("room", -1)) == room and bool(q.get("taken", false)))


## Teufelspakt: the life cap sinks for good (never below the Beuteordnung's least), one offer is given.
func _pact(e: Dictionary) -> void:
	var room := int(e.get("room", -1))
	if _pact_done(room):
		return
	var least := int((RewardRules.cfg().get("pact", {}) as Dictionary).get("min_lp", 12))
	if int(g.state.max_hp) - _price() < least:
		g.toast("Der Pakt will %d LP deiner Lebensgrenze. Unter %d LP geht kein Dämon." % [_price(), least])
		return
	g.state.max_hp = int(g.state.max_hp) - _price()
	g.state.hp = mini(int(g.state.hp), int(g.state.max_hp))
	e.taken = true
	var items: Variant = g.get("story_items")
	match clampi(int(e.get("offer", 0)), 0, 2):
		0:
			if items != null: items.reward_item(_at(e, 0), "epic", true, true)
		1:
			var rng := RandomNumberGenerator.new()
			rng.randomize()
			var rules: GDScript = load("res://src/hell/hell_rules.gd")
			var ids: Array = rules.seal_offer(g.state, g.balance.blessings, 2, rng, int(g.life_cap()))
			var said: Array = []
			for id: Variant in ids:
				said.append(rules.apply_blessing(g.state, str(id), g.balance.blessings, int(g.life_cap())))
			g.toast("Zwei Segen: " + ", ".join(said))
		2:
			g.gold_loot.spew_runes(Vector2(float(e.x), float(e.y) - 10.0), 3)
			if items != null: items.reward_stack(_at(e, 1), "upgrade_stone")
	g.toast("Der Pakt ist geschlossen. Deine Lebensgrenze sinkt um %d LP." % _price())


## Opfergrube: E calls the next wave (the fight closes the room); after each one the Schatz rises a tier.
func _pit(e: Dictionary) -> void:
	if bool(e.get("spent", false)) or bool(e.get("fighting", false)):
		return
	var wave := int(e.get("wave", 0))
	if wave >= 5:
		return
	var room := int(e.get("room", g.state.room))
	var n := 2 + wave
	var at := Vector2(float(e.x), float(e.y))
	for k in range(int(ceil(n / 2.0))):
		g.release_room_enemies(["random", "random"] if k * 2 + 1 < n else ["random"], at + Vector2(0, 40), room)
	e.fighting = true
	g.toast("Welle %d steigt aus der Grube!" % (wave + 1))


func _pit_chest(e: Dictionary, tier: int) -> void:
	e.spent = true
	var chest := {"type": "chest", "x": float(e.x), "y": float(e.y) + 110.0, "room": int(e.get("room", g.state.room)),
		"loot": {"gems": 0, "heart": false}, "magic": true, "hoard": [], "hoard_tier": clampi(tier, 1, 5), "tier": clampi(tier, 1, 5), "state": ""}
	g.W.ents.append(chest)
	g._add_solid(Rect2(float(chest.x) - 40, float(chest.y) - 32, 80, 32))
	g.toast("Die Grube gibt ihren Schatz frei: Stufe %d." % tier)


## The hero fell out of the fight (hell_game _fall_into_pit clears every fight): a running pit
## wave ends unfought, so it does not count as survived and the Schatz keeps its tier.
func abort_waves() -> void:
	for e: Dictionary in pieces:
		if str(e.type) == "hell_pit_altar" and bool(e.get("fighting", false)):
			e.fighting = false
			g.toast("Die Welle verebbt ungeschlagen. E am Altar ruft sie erneut.")


## The pit's wave ends when its room is clear again.
func _watch_pits() -> void:
	for e: Dictionary in pieces:
		if str(e.type) != "hell_pit_altar" or not bool(e.get("fighting", false)):
			continue
		var i := int(e.get("room", 0))
		if i < 0 or i >= (g.W.rooms as Array).size():
			continue
		if not bool((g.W.rooms[i] as Dictionary).get("fight", false)):
			e.fighting = false
			e.wave = int(e.get("wave", 0)) + 1
			g.toast("Welle %d überstanden. E am Altar: die nächste Welle oder den Schatz der Stufe %d." % [int(e.wave), int(e.wave)])


func _solved(e: Dictionary) -> bool:
	var group := str(e.get("group", ""))
	return group != "" and bool((g.W.groups.get(group, {}) as Dictionary).get("solved", false))


func _run_sluice(group: String) -> void:
	var spout: Dictionary = {}
	var forge: Dictionary = {}
	var pipe_at := {}
	for q: Dictionary in pieces:
		if str(q.get("group", "")) != group:
			continue
		match str(q.type):
			"hell_spout": spout = q
			"hell_forge": forge = q
			"hell_pipe": pipe_at[_key(cell_of(q))] = q
	if spout.is_empty() or forge.is_empty():
		return
	var d := int(DIR_OF.get(str(spout.get("dir", "e")), 1))
	var start: Vector2i = cell_of(spout) + DV[d]
	var way := trace_flow(start, (d + 2) % 4, func(c: Vector2i) -> Dictionary: return pipe_at.get(_key(c), {}), cell_of(forge))
	flows[group] = {"cells": way.cells, "ok": bool(way.ok), "left": float((cfg.get("flow", {}) as Dictionary).get("show", 1.4))}
	if bool(way.ok):
		forge.lit = true
		g.toast("Die Lava erreicht die Schmiede. Sie glüht auf, das Eisengitter schmilzt!")
		if g.W.groups.has(group):
			g.solve_group(group)
	else:
		g.toast("Die Lava läuft nach %d Rinne%s aus. Die Schleuse schließt sich wieder." % [(way.cells as Array).size(), "" if (way.cells as Array).size() == 1 else "n"])


## Bridges, shields, valves and pipes of room `room` back to how they began (paid thorns stay paid).
func reset_room(room: int) -> void:
	for e: Dictionary in pieces:
		if int(e.get("room", -1)) != room or _solved(e):
			continue
		match str(e.type):
			"hell_bridge": e.up = bool(e.start_up)
			"hell_shield": e.down = bool(e.start_down)
			"hell_pipe": e.rot = int(e.start_rot)
			"hell_valve":
				var vg: Dictionary = valves.get(str(e.get("group", "")), {})
				vg[str(e.get("label", "A"))] = bool(e.get("open", false))
				valves[str(e.get("group", ""))] = vg
	_index()


# ---------- drawing ----------

func _col(name: String, fallback: String) -> Color:
	return Color(str((cfg.get("look", {}) as Dictionary).get(name, fallback)))


func _tex(name: String) -> Texture2D:
	var t: Variant = g.tex.get(name) if g.get("tex") is Dictionary else null
	return t as Texture2D


## Lava over cell rect `r`: the hell's own lava tiles (lava_00 / lava_01, glowing in turns), else a colour.
func _lava(l: CanvasItem, r: Rect2, t: float, alpha: float = 1.0) -> void:
	var tile := _tex("lava_01" if fposmod(t * 1.5 + (r.position.x + r.position.y) / 300.0, 2.0) > 1.0 else "lava_00")
	var glow := 0.85 + 0.15 * sin(t * 3.0 + (r.position.x + r.position.y) / 140.0)
	if tile != null:
		l.draw_texture_rect(tile, r, false, Color(glow, glow, glow, alpha))
	else:
		l.draw_rect(r, Color(_col("lava", "ff6a1a"), alpha * glow))


func _sprite(l: CanvasItem, name: String, foot: Vector2, scale: float = 1.0, tint := Color.WHITE) -> bool:
	var t := _tex(name)
	if t == null:
		return false
	var size := t.get_size() * scale
	l.draw_texture_rect(t, Rect2(foot - Vector2(size.x * 0.5, size.y), size), false, tint)
	return true


## The flat pieces under everyone: lava, bridges, vents, the flood, channels, thorns, pipes, runes, sight.
func draw_under(l: CanvasItem, view: Rect2, t: float) -> void:
	if pieces.is_empty():
		return
	var lava := _col("lava", "ff6a1a")
	var lava_dark := _col("lava_dark", "8a2410")
	var tick := _vent_tick()
	var flood := _flood_now()
	for e: Dictionary in pieces:
		var type := str(e.type)
		if not FLAT.has(type):
			continue
		var c := cell_of(e)
		var r := Rect2(Vector2(c) * C, Vector2(C, C))
		if not view.grow(C).intersects(r):
			continue
		var glow := 0.75 + 0.25 * sin(t * 3.0 + float(c.x + c.y))
		match type:
			"hell_bridge":
				_lava(l, r, t)
				if not bool(e.get("up", false)):
					if not _sprite(l, "bridge_v", r.position + Vector2(C * 0.5, C), C / 96.0):
						l.draw_rect(r.grow(-10), _col("chain", "b9a58a"))
				else:
					l.draw_line(r.position + Vector2(24, 0), r.position + Vector2(24, C * 0.4), _col("chain", "b9a58a"), 4.0)
					l.draw_line(r.position + Vector2(C - 24, 0), r.position + Vector2(C - 24, C * 0.4), _col("chain", "b9a58a"), 4.0)
			"hell_channel":
				var wet := _channel_wet(e)
				if wet:
					_lava(l, r, t)
				else:
					l.draw_rect(r, _col("dry", "2a1a16"))
					l.draw_rect(r.grow(-10), Color(lava_dark, 0.5), false, 3.0)
				if not _flat(c, "hell_bridge").is_empty() and not bool(_flat(c, "hell_bridge").get("up", false)):
					_sprite(l, "bridge_h", r.position + Vector2(C * 0.5, C * 0.8), C / 96.0)
			"hell_vent":
				var period := int(e.get("period", (cfg.get("vent", {}) as Dictionary).get("period", 3)))
				var ph := vent_phase(c, tick, period)
				if not _sprite(l, "grate", r.position + Vector2(C * 0.5, C * 0.9), 0.9):
					l.draw_rect(r.grow(-14), Color(0.15, 0.1, 0.09))
				if ph == period - 1:
					l.draw_circle(r.get_center(), 30.0, Color(lava, 0.35 * glow))
				elif ph == 0:
					for k in range(3):
						var up := fposmod(t * 2.2 + k * 0.33, 1.0)
						l.draw_circle(r.get_center() + Vector2((k - 1) * 14.0, -up * 60.0), 22.0 * (1.0 - up * 0.6), Color(1.0, 0.55 + 0.3 * up, 0.15, 0.85 - up * 0.5))
			"hell_flood":
				var a := 0.0 if flood == "ebb" else (0.35 + 0.15 * sin(t * 14.0) if flood == "warn" else 0.92)
				if flood == "flood":
					_lava(l, r, t, a)
				elif a > 0.0:
					l.draw_rect(r, Color(lava_dark, a))
			"hell_stone":
				l.draw_rect(r.grow(-8), _col("stone", "3a302c"))
				l.draw_rect(r.grow(-8), Color(0, 0, 0, 0.35), false, 3.0)
			"hell_thorns":
				if not _sprite(l, "spike_trap_b" if bool(e.get("trod", false)) else "spike_trap", r.position + Vector2(C * 0.5, C * 0.92), 0.95):
					l.draw_rect(r.grow(-20), _col("blood", "b0182a"))
			"hell_pipe":
				_draw_pipe(l, e, r, t)
			"hell_rune":
				if not _sprite(l, "rune_plate", r.position + Vector2(C * 0.5, C * 0.92), 0.9):
					l.draw_circle(r.get_center(), 26.0, Color(1.0, 0.5, 0.2, 0.5 * glow))
	_draw_sight(l, view, t)


func _draw_pipe(l: CanvasItem, e: Dictionary, r: Rect2, t: float) -> void:
	var group := str(e.get("group", ""))
	var lit := flows.has(group) and ((flows[group] as Dictionary).cells as Array).has(cell_of(e))
	var metal := _col("metal", "5a4a44")
	var mid := r.get_center()
	l.draw_rect(r.grow(-6), Color(0.1, 0.07, 0.06, 0.6))
	for d: int in pipe_open(str(e.get("shape", "I")), int(e.get("rot", 0))):
		var to := mid + Vector2(DV[d]) * C * 0.5
		l.draw_line(mid, to, metal, 26.0)
		l.draw_line(mid, to, Color(_col("lava", "ff6a1a"), 0.6 + 0.4 * sin(t * 6.0)) if lit else Color(0.08, 0.05, 0.04), 12.0)
	l.draw_circle(mid, 14.0, metal)


func _draw_sight(l: CanvasItem, view: Rect2, t: float) -> void:
	var sight := _col("sight", "ff2a1e")
	for e: Dictionary in pieces:
		if str(e.type) != "hell_eye" or not view.grow(C * 12).has_point(Vector2(float(e.x), float(e.y))):
			continue
		var ec: Dictionary = cfg.get("eye", {})
		var state := 2 if bool(e.get("always", false)) else eye_state(_eye_tick(), int(e.get("open", ec.get("open", 2))), int(e.get("closed", ec.get("closed", 2))), int(e.get("off", 0)))
		if state != 2:
			continue
		var d: Vector2i = DV[int(DIR_OF.get(str(e.get("dir", "e")), 1))]
		var p := cell_of(e) + d
		for i in range(64):
			if _covers(p):
				break
			l.draw_rect(Rect2(Vector2(p) * C + Vector2(0, 14), Vector2(C, C - 28)), Color(sight, 0.13 + 0.05 * sin(t * 8.0)))
			p += d


## The standing pieces for the game's depth list: [depth, "hellp", piece].
func sort_into(list: Array, view: Rect2) -> void:
	for e: Dictionary in pieces:
		var type := str(e.type)
		if FLAT.has(type) or not view.grow(C).has_point(Vector2(float(e.x), float(e.y))):
			continue
		if type == "hell_blood_gate" and bool(e.get("open", false)):
			continue
		list.append([float(e.y) + C * 0.36, "hellp", e])


func draw_piece(l: CanvasItem, e: Dictionary, t: float) -> void:
	var c := cell_of(e)
	var foot := centre(c) + Vector2(0, C * 0.42)
	var lava := _col("lava", "ff6a1a")
	match str(e.type):
		"hell_winch":
			var spin := clampf((_clock - float(e.get("pulled", -9.0))) * 4.0, 0.0, 1.0)
			var hub := foot + Vector2(0, -44)
			l.draw_rect(Rect2(foot + Vector2(-34, -20), Vector2(68, 20)), Color(0.22, 0.14, 0.1))
			l.draw_circle(hub, 30.0, Color(0.45, 0.3, 0.18))
			for k in range(4):
				var a := spin * TAU + k * PI / 2.0
				l.draw_line(hub, hub + Vector2(cos(a), sin(a)) * 30.0, _col("chain", "b9a58a"), 5.0)
			l.draw_circle(hub, 8.0, _col("metal", "5a4a44"))
		"hell_valve":
			var vg: Dictionary = valves.get(str(e.get("group", "")), {})
			var open := bool(vg.get(str(e.get("label", "A")), false))
			var hub := foot + Vector2(0, -40)
			l.draw_rect(Rect2(foot + Vector2(-10, -40), Vector2(20, 40)), _col("metal", "5a4a44"))
			l.draw_arc(hub, 26.0, 0.0, TAU, 24, Color(0.75, 0.2, 0.12) if open else Color(0.45, 0.4, 0.38), 7.0)
			l.draw_line(hub + Vector2(-26, 0), hub + Vector2(26, 0), Color(0.6, 0.2, 0.12), 4.0)
			l.draw_line(hub + Vector2(0, -26), hub + Vector2(0, 26), Color(0.6, 0.2, 0.12), 4.0)
			l.draw_string(ThemeDB.fallback_font, hub + Vector2(-6, -34), str(e.get("label", "A")), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1.0, 0.85, 0.6))
		"hell_sluice":
			l.draw_rect(Rect2(foot + Vector2(-20, -16), Vector2(40, 16)), _col("metal", "5a4a44"))
			var up := _solved(e)
			l.draw_line(foot + Vector2(0, -16), foot + Vector2(-22 if up else 22, -70), Color(0.35, 0.22, 0.12), 8.0)
			l.draw_circle(foot + Vector2(-22 if up else 22, -70), 9.0, Color(0.85, 0.3, 0.15))
		"hell_spout":
			if not _sprite(l, "demon_head", foot, 0.9):
				l.draw_circle(foot + Vector2(0, -40), 30.0, Color(0.4, 0.1, 0.08))
			l.draw_circle(foot + Vector2(0, -34), 10.0, Color(lava, 0.7 + 0.3 * sin(t * 5.0)))
		"hell_forge":
			var lit := bool(e.get("lit", false)) or _solved(e)
			if not _sprite(l, "brazier_demon", foot, 1.0, Color.WHITE if lit else Color(0.45, 0.45, 0.5)):
				l.draw_rect(Rect2(foot + Vector2(-30, -60), Vector2(60, 60)), Color(0.3, 0.2, 0.15))
			if lit:
				l.draw_circle(foot + Vector2(0, -70), 24.0, Color(lava, 0.6 + 0.3 * sin(t * 7.0)))
		"hell_shield":
			var down := bool(e.get("down", false))
			l.draw_line(foot + Vector2(-20, -C), foot + Vector2(-20, -40 if down else -C * 0.7), _col("chain", "b9a58a"), 3.0)
			l.draw_line(foot + Vector2(20, -C), foot + Vector2(20, -40 if down else -C * 0.7), _col("chain", "b9a58a"), 3.0)
			var top := foot + Vector2(-34, -78 if down else -C * 0.98)
			l.draw_rect(Rect2(top, Vector2(68, 70 if down else 26)), Color(0.42, 0.38, 0.36))
			l.draw_rect(Rect2(top, Vector2(68, 70 if down else 26)), Color(0.18, 0.15, 0.14), false, 3.0)
		"hell_blood_gate":
			if not _sprite(l, "portcullis", foot, 1.0, Color(1.0, 0.55, 0.55)):
				l.draw_rect(Rect2(foot + Vector2(-40, -90), Vector2(80, 90)), Color(0.5, 0.1, 0.12))
		"hell_blood_bowl":
			if not _sprite(l, "brazier_bowl", foot, 1.0, Color(1.0, 0.5, 0.5)):
				l.draw_circle(foot + Vector2(0, -30), 26.0, Color(0.35, 0.08, 0.08))
			var n := int(paid.get(int(e.get("room", -1)), 0))
			l.draw_string(ThemeDB.fallback_font, foot + Vector2(-30, -82), "♥ %d" % n, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(1.0, 0.4, 0.4))
		"hell_sacrifice":
			var spent := int(e.get("step", 0)) >= 4
			if not _sprite(l, "skull_obelisk", foot, 1.0, Color(0.6, 0.6, 0.6) if spent else Color(1.0, 0.7, 0.7)):
				l.draw_rect(Rect2(foot + Vector2(-26, -90), Vector2(52, 90)), Color(0.3, 0.1, 0.1))
			if not spent:
				l.draw_circle(foot + Vector2(0, -60), 10.0 + 3.0 * sin(t * 4.0), Color(0.9, 0.1, 0.15, 0.6))
		"hell_pact":
			var done := _pact_done(int(e.get("room", -1)))
			if not _sprite(l, "altar", foot, 0.8, Color(0.5, 0.45, 0.45) if done else Color(1.0, 0.6, 0.5)):
				l.draw_rect(Rect2(foot + Vector2(-40, -40), Vector2(80, 40)), Color(0.35, 0.12, 0.1))
			if not done:
				l.draw_circle(foot + Vector2(0, -56), 14.0 + 4.0 * sin(t * 3.0 + float(e.get("offer", 0))), Color(1.0, 0.35, 0.15, 0.55))
		"hell_pit_altar":
			if not _sprite(l, "brazier_rune", foot, 1.0, Color.WHITE if not bool(e.get("spent", false)) else Color(0.5, 0.5, 0.5)):
				l.draw_rect(Rect2(foot + Vector2(-30, -60), Vector2(60, 60)), Color(0.3, 0.2, 0.15))
			l.draw_string(ThemeDB.fallback_font, foot + Vector2(-26, -96), "%d / 5" % int(e.get("wave", 0)), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1.0, 0.8, 0.5))
		"hell_eye":
			var ec: Dictionary = cfg.get("eye", {})
			var state := 2 if bool(e.get("always", false)) else eye_state(_eye_tick(), int(e.get("open", ec.get("open", 2))), int(e.get("closed", ec.get("closed", 2))), int(e.get("off", 0)))
			if not _sprite(l, "demon_head", foot, 0.9):
				l.draw_circle(foot + Vector2(0, -40), 30.0, Color(0.3, 0.08, 0.06))
			var eye_col := Color(1.0, 0.2, 0.12) if state == 2 else (Color(0.9, 0.4, 0.1, 0.6 + 0.4 * sin(t * 12.0)) if state == 1 else Color(0.2, 0.05, 0.04))
			l.draw_circle(foot + Vector2(-12, -46), 7.0, eye_col)
			l.draw_circle(foot + Vector2(12, -46), 7.0, eye_col)


## The flood's beat and the room's blood price on the screen while the hero is in such a room.
func draw_hud(h: Control, size: Vector2) -> void:
	var room := int(g.state.room)
	if not rooms.has(room):
		return
	var line := ""
	if pieces.any(func(e: Dictionary) -> bool: return str(e.type) == "hell_flood" and int(e.get("room", -1)) == room):
		var f := _flood_now()
		line = "EBBE · LAUF" if f == "ebb" else ("ES BRODELT" if f == "warn" else "FLUT · WARTE")
	elif pieces.any(func(e: Dictionary) -> bool: return str(e.type) == "hell_blood_bowl" and int(e.get("room", -1)) == room):
		line = "BLUTPREIS: %d HERZ%s" % [int(paid.get(room, 0)), "" if int(paid.get(room, 0)) == 1 else "EN"]
	if line == "":
		return
	h.draw_string(ThemeDB.fallback_font, Vector2(size.x * 0.5 - 90.0, 92.0), line, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(1.0, 0.7, 0.4))
