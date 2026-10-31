extends Node
## Debug Testraum of the three story worlds (Krypta, Frostgruft, Hölle; user
## decision 2026-10-31). It replaces the old crypt Testraum
## (src/debug/test_arena.gd) behind TESTRAUM in the DEBUG hub of src/main_menu.gd.
##
## Boot: start() instances the world's scene (src/hell/*_dungeon.tscn) with
## hell_game.gd's `testraum` settings set before _ready. hell_game.gd calls
## prepare() first (the Testraum's own profile and soul-crystal files, never the
## player's) and mount() once its floor stands: this node rebuilds floor 1 on a
## fixed run number, puts the hero into the floor's biggest open room, counts
## every room as cleared (no fight starts, the doors stay open), keeps the
## story's toasts, floor banners and card offers out, lets a fallen hero stand
## up again (no run end, no new story run) and mounts the panel.
##
## Panel (RoomPanel): a small arrow chip under "ESC · MENÜ" folds it out (F1
## too; collapsed by default); its sections fold on their headers and the
## column scrolls with the mouse wheel.
##
## Spawning: the Krypta's and the Hölle's monster sets (hell_monsters.gd defs)
## are merged into the running monster runtime, so both spawn in either of the
## two worlds. The Frostgruft runs its enemies as theme mobs (hell_game.gd
## _update_mobs) and has no hell_monsters runtime: its mobs and guardians spawn
## only there, and the hell_monsters sets are greyed out there.
## Values: assets/data/debug_story_testraum.json.

const CONFIG_PATH := "res://assets/data/debug_story_testraum.json"
const SELF_PATH := "res://src/debug/story_testraum.gd"
const Profile = preload("res://src/progress/profile.gd")
const HudKit = preload("res://src/ui/hud_kit.gd")
const HudStyle = preload("res://src/ui/hud_style.gd")
const MonsterRules = preload("res://src/hell/hell_monster_rules.gd")
const FONT := preload("res://assets/fonts/pixel_operator8.ttf")

static var _config_cache: Dictionary = {}

## The story game (src/hell/hell_game.gd) this Testraum runs in.
var g: Node
## The HUD layer the panel lives in.
var ui: CanvasLayer
var cfg: Dictionary = {}
var panel: Control
## W.rooms index of the test room (spawned monsters belong to it).
var room_index := -1
## The armed element tool ({} for none): a kind of assets/data/debug_story_testraum.json
## elements plus its "group" (puddle, gas, react).
var tool: Dictionary = {}
## The live readout line (frame time, FPS, enemies).
var stat := ""
var _tdata: Dictionary = {}
var _json_cache: Dictionary = {}
var _serial := 0
var _later: Array = []
var _frame_ms := 0.0
var _was_frozen := false


# ---------- boot ----------

## The Testraum's values, read once per run of the game.
static func config() -> Dictionary:
	if _config_cache.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
		if parsed is Dictionary:
			_config_cache = parsed
	return _config_cache


## Opens the Testraum in `world` ("" = the default world) with hero `class_id`
## ("" = the default class) in place of the current scene. `keep`: panel
## settings carried over a world or class switch.
static func start(tree: SceneTree, world: String, class_id: String, keep: Dictionary = {}) -> void:
	var conf := config()
	var worlds: Dictionary = conf.get("worlds", {})
	if not worlds.has(world):
		world = str(conf.get("default_world", "krypta"))
	var packed: PackedScene = load(str(worlds[world].scene))
	var scene: Node = packed.instantiate()
	var settings: Dictionary = keep.duplicate(true)
	settings.world = world
	scene.set("class_id", class_id if class_id != "" else str(conf.get("default_class", "swordsman")))
	scene.set("testraum", settings)
	Engine.time_scale = 1.0
	var old: Node = tree.current_scene
	tree.root.add_child(scene)
	tree.current_scene = scene
	if old != null and old != scene:
		old.queue_free()


## Called by hell_game.gd before anything loads: the Testraum's own profile and
## soul-crystal files (the player's are never read or written).
static func prepare(game: Node) -> void:
	var conf := config()
	game.set("profile_path", str(conf.get("profile_path", "user://profile_story_testraum.json")))
	game.set("meta_path", str(conf.get("meta_path", "user://meta_story_testraum.json")))


## Called by hell_game.gd at the end of _ready: adds the Testraum node (it
## builds the room and the panel in its _ready).
static func mount(game: Node, hud_layer: CanvasLayer) -> void:
	var own: GDScript = load(SELF_PATH)
	var room: Node = own.new()
	room.name = "StoryTestraum"
	room.set("g", game)
	room.set("ui", hud_layer)
	game.add_child(room)


func _ready() -> void:
	cfg = config()
	_tdata = Profile.data()
	var o := opts()
	o.merge((cfg.get("defaults", {}) as Dictionary).duplicate(true), false)
	if not o.has("closed"):
		var closed := {}
		for sec: Dictionary in cfg.get("sections", []):
			closed[str(sec.id)] = bool(sec.get("closed", false))
		o.closed = closed
	_build_room()
	_merge_monster_sets()
	_apply_build()
	if g.get("pause_menu") != null:
		g.pause_menu.set_save_enabled(false)
	var p := RoomPanel.new()
	p.host = self
	panel = p
	ui.add_child(p)
	_say("Testraum · %s · %s" % [str(cfg.worlds[str(o.world)].name), str(g.class_id)])


func _exit_tree() -> void:
	Engine.time_scale = 1.0


## The settings of this Testraum (hell_game.gd testraum; carried over reloads).
func opts() -> Dictionary:
	return g.testraum


## Floor 1 again on the fixed run number; the hero into its biggest open room,
## every room cleared and quiet.
func _build_room() -> void:
	if g.get("world") != null:
		g.state.world_run = int(cfg.get("seed", 1))
		g.load_floor(1, true)
	var W: Dictionary = g.W
	var cols := int(W.cols)
	var skip: Array = (cfg.get("room", {}) as Dictionary).get("exclude_types", [])
	var best: Dictionary = {}
	var best_n := -1
	for r: Dictionary in W.rooms:
		if str(r.type) in skip:
			continue
		var n := 0
		for c: Vector2i in r.cells:
			if int(W.grid[c.y * cols + c.x]) == 1:
				n += 1
		if n > best_n:
			best_n = n
			best = r
	if best.is_empty():
		best = W.rooms[0]
	room_index = int(best.index)
	for r: Dictionary in W.rooms:
		r.cleared = true
		r.fight = false
		r.rewarded = true
	best.drop = ""
	(g.mobs as Array).clear()
	var cell := float(g.C)
	var centre := Vector2((float(best.bx) + float(best.bw) / 2.0) * cell, (float(best.by) + float(best.bh) / 2.0) * cell)
	var at := centre
	var near := INF
	for c: Vector2i in best.cells:
		if int(W.grid[c.y * cols + c.x]) != 1:
			continue
		var p := Vector2((c.x + 0.5) * cell, (c.y + 0.8) * cell)
		var box: Rect2 = g._player_box(p.x, p.y)
		if bool(g.box_blocked(box.grow(48.0))):
			continue
		if p.distance_to(centre) < near:
			near = p.distance_to(centre)
			at = p
	g.player.x = at.x
	g.player.y = at.y
	g.state.room = room_index
	g.state.visited[room_index] = true
	g.camera.position = at
	(g.state.toasts as Array).clear()
	g.state.banner.t = 99.0


## Both hell_monsters.gd sets in the running monster runtime (Krypta, Hölle):
## the defs this world lacks, their atlas and kill EXP, and the rig looks.
func _merge_monster_sets() -> void:
	var mons: Variant = g.get("monsters")
	if mons == null:
		return
	var defs: Dictionary = mons.defs
	var atlas: Dictionary = mons.atlas
	var sets: Dictionary = cfg.get("monster_sets", {})
	for set_id: String in sets:
		var spec: Dictionary = sets[set_id]
		var data := _json(str(spec.data))
		var exp_map: Dictionary = (_json(str(spec.balance)).get("monsters", {}) as Dictionary).get("exp", {})
		var more: Dictionary = data.get("defs", {})
		for id: String in more:
			if defs.has(id):
				continue
			var png := str(spec.sprites) + id + ".png"
			if not ResourceLoader.exists(png):
				continue
			var def: Dictionary = (more[id] as Dictionary).duplicate(true)
			def.exp = int(exp_map.get(id, 0))
			defs[id] = def
			atlas[id] = load(png)
	if g.get("drake_rig") != null:
		g.drake_rig.adopt_looks(defs)


## The hero's build from the panel: the chosen spec with every talent at full
## rank, the level, the ultimate stage (soul tier) and the companion; written
## to the Testraum profile and set on the talent runtime at once.
func _apply_build() -> void:
	var talents: Variant = g.get("talents")
	if talents == null:
		return
	var cls := str(g.class_id)
	var spec := _spec(cls)
	if spec.is_empty():
		return
	var o := opts()
	o.spec = str(spec.id)
	var info_all: Dictionary = _tdata.get("talents", {})
	var ranks := {}
	var bar: Array = []
	var ult := ""
	for id: String in spec.get("talents", []):
		var info: Dictionary = info_all.get(id, {})
		var kind := str(info.get("kind", ""))
		ranks[id] = 1 if kind == "ultimate" else int(info.get("ranks", 1))
		if kind == "ultimate":
			ult = id
		elif kind == "active" and bar.size() < int(_tdata.get("bar_slots", 4)):
			bar.append(id)
	var tier := clampi(int(o.stage) - 1, 0, 2)
	var level := int(o.level)
	var profile: Dictionary = g.profile
	var state: Dictionary = Profile.class_state(profile, cls)
	state.level = level
	state.ranks = ranks.duplicate()
	state.ultimate = ult
	state.soul_tier = tier
	state.bar = bar.duplicate()
	state.companion = str(o.companion)
	Profile.save_profile(profile, str(g.profile_path))
	talents.tc.set_build(1, Profile.build_of(profile, cls))
	# like the talent probes: the full ranks even where the level would not pay for them
	var rt: Dictionary = talents.tc.runtime(1)
	if rt.is_empty():
		return
	for id: String in ranks:
		rt.ranks[id] = ranks[id]
	rt.ultimate = ult
	rt.soul_tier = tier
	rt.level = level
	rt.bar = bar.duplicate()


func _spec(cls: String) -> Dictionary:
	var specs: Array = ((_tdata.get("classes", {}) as Dictionary).get(cls, {}) as Dictionary).get("specs", [])
	for s: Dictionary in specs:
		if str(s.id) == str(opts().get("spec", "")):
			return s
	return specs[0] if not specs.is_empty() else {}


func _json(path: String) -> Dictionary:
	if not _json_cache.has(path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
		_json_cache[path] = parsed if parsed is Dictionary else {}
	return _json_cache[path]


# ---------- per frame ----------

func _process(delta: float) -> void:
	if g == null or (g.state as Dictionary).is_empty():
		return
	var st: Dictionary = g.state
	var o := opts()
	# the story stays out: floor banners, its toasts (the Testraum's own stay), card offers
	(st.banner as Dictionary).t = maxf(float(st.banner.t), 99.0)
	if not (st.toasts as Array).is_empty():
		st.toasts = (st.toasts as Array).filter(func(t: Dictionary) -> bool: return bool(t.get("tr", false)))
	var room_cfg: Dictionary = cfg.get("room", {})
	if bool(room_cfg.get("no_cards", true)):
		st.offer = []
		st.cards_due = 0
	# a fallen hero stands up again before the run would end (no new story run starts)
	if float(st.dead) > 0.0 and (bool(o.get("god", false)) or float(st.dead) <= float(room_cfg.get("revive_at", 1.0))):
		_revive()
	elif not (st.get("over", {}) as Dictionary).is_empty():
		_revive()
	_cheats()
	for i in range(_later.size() - 1, -1, -1):
		var job: Dictionary = _later[i]
		job.t = float(job.t) - delta
		if float(job.t) <= 0.0:
			_later.remove_at(i)
			_react(str(job.do), job.p, float(job.r))
	var want := float(o.get("scale", 1.0))
	if not is_equal_approx(Engine.time_scale, want):
		Engine.time_scale = want
	_frame_ms = lerpf(_frame_ms, float(Performance.get_monitor(Performance.TIME_PROCESS)) * 1000.0, 0.1)
	stat = "%.0f ms · %d FPS · %d Geg." % [_frame_ms, int(Engine.get_frames_per_second()), (g.mobs as Array).size()]


func _revive() -> void:
	var st: Dictionary = g.state
	st.dead = 0.0
	st.over = {}
	st.hp = int(st.max_hp)
	st.dot = 0.0
	st.inv = 1.0
	_say(str(cfg.texts.revived))


func _cheats() -> void:
	var o := opts()
	var st: Dictionary = g.state
	if bool(o.get("god", false)):
		st.hp = int(st.max_hp)
		st.dot = 0.0
	var talents: Variant = g.get("talents")
	if talents != null:
		var rt: Dictionary = talents.tc.runtime(1)
		if not rt.is_empty():
			if bool(o.get("mana", false)):
				rt.res = float(rt.res_max)
			if bool(o.get("nocd", false)):
				(rt.cds as Dictionary).clear()
				rt.gcd = 0.0
				if rt.get("pet_cds") is Dictionary:
					(rt.pet_cds as Dictionary).clear()
	if bool(o.get("nocd", false)):
		st.skill_cd = {}
	if bool(o.get("freeze", false)):
		_freeze()
	elif _was_frozen:
		_thaw()


## Enemies stand where they are and attack nothing (pinned each frame after
## they moved; hell monsters held without an act, theme mobs with their timers held).
func _freeze() -> void:
	_was_frozen = true
	for m: Dictionary in g.mobs:
		if not m.has("tr_pin"):
			m.tr_pin = m.p
		m.p = m.tr_pin
		m.k = Vector2.ZERO
		if m.has("cds"):
			m.hold = true
			m.act = null
		else:
			m.shoot = maxf(float(m.get("shoot", 0.0)), 0.5)
			m.summon = maxf(float(m.get("summon", 0.0)), 0.5)
			m.dash = 0.0
			m.dash_t = maxf(float(m.get("dash_t", 0.0)), 0.5)


func _thaw() -> void:
	_was_frozen = false
	for m: Dictionary in g.mobs:
		m.erase("tr_pin")
		if m.has("cds"):
			m.hold = false


## A Testraum message among the toasts (the story's own are kept out).
func _say(text: String) -> void:
	var toasts: Array = g.state.toasts
	toasts.append({"text": text, "t": float(cfg.get("toast_time", 2.6)), "tr": true})
	while toasts.size() > 3:
		toasts.pop_front()


## True while the panel must not show (pause menu, talent menu, big map).
func hidden_now() -> bool:
	var pm: Variant = g.get("pause_menu")
	if pm != null and bool(pm.visible):
		return true
	var tm: Variant = g.get("run_talents")
	if tm != null and bool(tm.visible):
		return true
	return bool((g.state as Dictionary).get("map", false))


# ---------- input ----------

func _input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo or hidden_now():
		return
	if key.keycode == KEY_F1:
		panel.call("toggle")
		get_viewport().set_input_as_handled()
	elif key.keycode >= KEY_F2 and key.keycode <= KEY_F10:
		# no debug floor jumps: they would leave the test room
		get_viewport().set_input_as_handled()


## An armed element tool: a left click on the floor places it, a right click lays it down.
func _unhandled_input(event: InputEvent) -> void:
	if tool.is_empty() or not (event is InputEventMouseButton) or hidden_now():
		return
	var mb := event as InputEventMouseButton
	if not mb.pressed:
		return
	if mb.button_index == MOUSE_BUTTON_LEFT:
		var at: Vector2 = g.get_global_mouse_position()
		_place(at)
		get_viewport().set_input_as_handled()
	elif mb.button_index == MOUSE_BUTTON_RIGHT:
		tool = {}
		panel.call("rebuild")
		get_viewport().set_input_as_handled()


# ---------- panel rows and actions ----------

func _opt(label: String, action: String, arg: Variant, on := false, off := false) -> Dictionary:
	return {"label": label, "act": action, "arg": arg, "on": on, "off": off}


## The panel's rows for the current state: headers, option lines, list items, notes.
func rows() -> Array:
	var out: Array = []
	var closed: Dictionary = opts().closed
	for sec: Dictionary in cfg.get("sections", []):
		var id := str(sec.id)
		var shut := bool(closed.get(id, false))
		out.append({"kind": "head", "label": str(sec.title), "act": "section", "arg": id, "open": not shut})
		if shut:
			continue
		match id:
			"welt":
				_rows_world(out)
			"held":
				_rows_hero(out)
			"monster":
				_rows_spawn(out, "mobs")
			"bosse":
				_rows_spawn(out, "bosses")
			"npcs":
				_rows_npcs(out)
			"elemente":
				_rows_elements(out)
			"cheats":
				_rows_cheats(out)
	return out


func _rows_world(out: Array) -> void:
	var choices: Array = []
	for w: String in cfg.world_order:
		choices.append(_opt(str(cfg.worlds[w].name), "world", w, w == str(opts().world)))
	out.append({"kind": "opts", "label": "", "opts": choices})
	out.append({"kind": "item", "label": "NEU LADEN", "act": "reload", "arg": null, "on": false, "off": false, "note": "Seed %d" % int(cfg.seed)})


func _rows_hero(out: Array) -> void:
	var o := opts()
	var cls := str(g.class_id)
	var choices: Array = []
	for c: Dictionary in cfg.classes:
		choices.append(_opt(str(c.name), "class", str(c.id), str(c.id) == cls))
	out.append({"kind": "opts", "label": "KLASSE", "opts": choices})
	if g.get("talents") == null:
		out.append({"kind": "text", "label": str(cfg.texts.no_talents)})
		return
	var specs: Array = []
	for s: Dictionary in ((_tdata.get("classes", {}) as Dictionary).get(cls, {}) as Dictionary).get("specs", []):
		specs.append(_opt(str(s.name), "spec", str(s.id), str(s.id) == str(o.spec)))
	out.append({"kind": "opts", "label": "SPEZIALISIERUNG", "opts": specs})
	var levels: Array = []
	for n: Variant in cfg.levels:
		levels.append(_opt(str(int(n)), "level", int(n), int(n) == int(o.level)))
	out.append({"kind": "opts", "label": "LEVEL · ALLE TALENTE", "opts": levels})
	var stages: Array = []
	for n: Variant in cfg.ult_stages:
		stages.append(_opt("STUFE %d" % int(n), "stage", int(n), int(n) == int(o.stage)))
	out.append({"kind": "opts", "label": "ULTIMATE", "opts": stages})
	if str(o.spec) in cfg.get("companion_specs", []):
		var pets: Array = []
		for p: Dictionary in cfg.companions:
			pets.append(_opt(str(p.name), "companion", str(p.id), str(p.id) == str(o.companion)))
		out.append({"kind": "opts", "label": "BEGLEITER", "opts": pets})


## True when entries of roster group `group` run in this world.
func _runs(group: Dictionary) -> bool:
	if str(group.runtime) == "monsters":
		return g.get("monsters") != null
	return g.get("monsters") == null and (g.theme as Dictionary).has("mobs")


func _rows_spawn(out: Array, key: String) -> void:
	var o := opts()
	if key == "mobs":
		var counts: Array = []
		for n: Variant in cfg.spawn.counts:
			counts.append(_opt("%dx" % int(n), "count", int(n), int(n) == int(o.count)))
		counts.append(_opt("ALLE WEG", "clear", null))
		out.append({"kind": "opts", "label": "ANZAHL", "opts": counts})
	else:
		out.append({"kind": "opts", "label": "", "opts": [_opt("ALLE WEG", "clear", null)]})
	var mons: Variant = g.get("monsters")
	for set_id: String in cfg.roster_order:
		var group: Dictionary = cfg.roster[set_id]
		var live := _runs(group)
		out.append({"kind": "text", "label": str(group.name) + ("" if live else " · " + str(group.grey)), "group": true})
		for e: Dictionary in group.get(key, []):
			var ok := live
			if ok and str(group.runtime) == "monsters":
				ok = (mons.defs as Dictionary).has(str(e.id))
			var arg := {"set": set_id, "id": str(e.get("id", "")), "floor": int(e.get("floor", 0)), "boss": key == "bosses", "name": str(e.name)}
			out.append({"kind": "item", "label": str(e.name), "act": "spawn", "arg": arg, "on": false, "off": not ok, "note": str(e.get("tag", ""))})


func _rows_npcs(out: Array) -> void:
	for e: Dictionary in cfg.npcs:
		var ok := (g.tex as Dictionary).has(str(e.tex))
		out.append({"kind": "item", "label": str(e.name), "act": "npc", "arg": e, "on": false, "off": not ok, "note": "" if ok else str(cfg.texts.npc_missing)})
	out.append({"kind": "item", "label": "NPCS WEG", "act": "npc_clear", "arg": null, "on": false, "off": false, "note": ""})


func _tool_ok(group: String, kind: Dictionary) -> bool:
	if group == "puddle" or str(kind.get("needs", "")) == "monsters":
		return g.get("monsters") != null
	return true


func _rows_elements(out: Array) -> void:
	out.append({"kind": "text", "label": str(cfg.texts.tool_hint)})
	if g.get("monsters") == null:
		out.append({"kind": "text", "label": str(cfg.texts.no_runtime)})
	for group: String in ["puddle", "gas", "react"]:
		var spec: Dictionary = cfg.elements[group]
		var choices: Array = []
		for k: Dictionary in spec.kinds:
			var armed := not tool.is_empty() and str(tool.group) == group and str(tool.name) == str(k.name)
			var arg: Dictionary = k.duplicate()
			arg.group = group
			choices.append(_opt(str(k.name), "tool", arg, armed, not _tool_ok(group, k)))
		out.append({"kind": "opts", "label": str(spec.title), "opts": choices})
	out.append({"kind": "opts", "label": "", "opts": [_opt("PFÜTZEN/GASE WEG", "wipe", null)]})


func _rows_cheats(out: Array) -> void:
	var o := opts()
	for c: Dictionary in cfg.cheats.toggles:
		var on := bool(o.get(str(c.id), false))
		out.append({"kind": "item", "label": str(c.name), "act": "cheat", "arg": str(c.id), "on": on, "off": false, "note": "AN" if on else "aus"})
	out.append({"kind": "opts", "label": "", "opts": [_opt("VOLLES LEBEN", "heal", null), _opt("VOLLE RESSOURCE", "fill", null),
		_opt("+%d SEELENSPLITTER" % int(cfg.cheats.shards), "shards", null)]})
	var scales: Array = []
	for s: Dictionary in cfg.cheats.time_scales:
		scales.append(_opt(str(s.name), "scale", float(s.v), is_equal_approx(float(s.v), float(o.get("scale", 1.0)))))
	out.append({"kind": "opts", "label": "ZEITLUPE", "opts": scales})


## A click on a panel entry.
func act(action: String, arg: Variant) -> void:
	var o := opts()
	match action:
		"section":
			var closed: Dictionary = o.closed
			closed[str(arg)] = not bool(closed.get(str(arg), false))
		"world":
			if str(arg) != str(o.world):
				_restart(str(arg), str(g.class_id))
				return
		"reload":
			_restart(str(o.world), str(g.class_id))
			return
		"class":
			if str(arg) != str(g.class_id):
				o.spec = ""
				_restart(str(o.world), str(arg))
				return
		"spec", "level", "stage", "companion":
			o[action] = arg
			_apply_build()
		"count":
			o.count = int(arg)
		"spawn":
			var a: Dictionary = arg
			var made := _spawn_set(a) if str(cfg.roster[str(a.set)].runtime) == "monsters" else _spawn_theme(a)
			_say(("%s ×%d" % [str(a.name), made]) if made > 0 else "%s: %s" % [str(a.name), str(cfg.texts.not_here)])
		"clear":
			_clear_mobs()
			_say(str(cfg.texts.cleared))
		"npc":
			var spec: Dictionary = arg
			var at := _spot(0, 1, float(cfg.spawn.get("npc_distance", 150.0)))
			(g.W.ents as Array).append({"type": str(spec.type), "x": at.x, "y": at.y, "room": room_index, "testraum": true})
			_say(str(spec.name))
		"npc_clear":
			var ents: Array = g.W.ents
			for i in range(ents.size() - 1, -1, -1):
				if bool((ents[i] as Dictionary).get("testraum", false)):
					ents.remove_at(i)
		"tool":
			var t: Dictionary = arg
			var same := not tool.is_empty() and str(tool.group) == str(t.group) and str(tool.name) == str(t.name)
			tool = {} if same else t
		"wipe":
			_wipe()
			_say(str(cfg.texts.wiped))
		"cheat":
			o[str(arg)] = not bool(o.get(str(arg), false))
		"heal":
			g.state.hp = int(g.state.max_hp)
			g.state.dot = 0.0
		"fill":
			var talents: Variant = g.get("talents")
			if talents != null:
				var rt: Dictionary = talents.tc.runtime(1)
				if not rt.is_empty():
					rt.res = float(rt.res_max)
		"shards":
			var profile: Dictionary = g.profile
			if profile.get("shards") is Dictionary:
				profile.shards.have = int(profile.shards.get("have", 0)) + int(cfg.cheats.shards)
				Profile.save_profile(profile, str(g.profile_path))
				_say("Seelensplitter: %d" % int(profile.shards.have))
		"scale":
			o.scale = float(arg)
	panel.call("rebuild")


func _restart(world: String, cls: String) -> void:
	var keep: Dictionary = opts().duplicate(true)
	keep.erase("world")
	start(get_tree(), world, cls, keep)


# ---------- spawning ----------

## A free floor spot for spawn k of n: `dist` px from the hero in his aim
## direction, the n fanned out; the hero's room first, then anywhere open.
func _spot(k: int, n: int, dist: float) -> Vector2:
	var hero := Vector2(float(g.player.x), float(g.player.y))
	var aim: Vector2 = g.player.get("aim", Vector2.RIGHT)
	var base := aim.angle() if aim.length() > 0.1 else 0.0
	var off := (float(k) - float(n - 1) / 2.0) * float(cfg.spawn.get("spread", 0.55))
	var room := int(g._room_at_world(hero.x, hero.y))
	for strict in [true, false]:
		for reach: float in [1.0, 0.75, 1.3, 0.5]:
			for j in range(13):
				var turn := floorf((j + 1) / 2.0) * 0.5 * (1.0 if j % 2 == 1 else -1.0)
				var p := hero + Vector2.from_angle(base + off + turn) * dist * reach
				if _open(p) and (not strict or int(g._room_at_world(p.x, p.y)) == room):
					return p
	return hero + Vector2(60, 0)


func _open(p: Vector2) -> bool:
	var cell := float(g.C)
	if int(g._cell(int(floor(p.x / cell)), int(floor(p.y / cell)))) != 1:
		return false
	return not bool(g.box_blocked(Rect2(p.x - 30.0, p.y - 30.0, 60.0, 30.0), true))


## Spawns a hell_monsters.gd figure (both sets merged); a boss with its own
## floor's guardian HP (its world pack), Ignaroth with his arrival.
func _spawn_set(a: Dictionary) -> int:
	var mons: Variant = g.get("monsters")
	var id := str(a.id)
	if mons == null or not (mons.defs as Dictionary).has(id):
		return 0
	var boss := bool(a.boss)
	var n := int(cfg.spawn.get("boss_count", 1)) if boss else int(opts().count)
	var info: Dictionary = g.W.boss
	var hp_was: Variant = info.get("hp", 1)
	if boss:
		var hp := _boss_hp(str(a.set), mons.defs[id])
		if hp > 0.0:
			info.hp = hp
	var dist := float(cfg.spawn.get("boss_distance" if boss else "distance", 260.0))
	for k in range(n):
		var m: Dictionary = mons.spawn(room_index, _spot(k, n, dist), id, boss)
		if boss and MonsterRules.is_lord(m.def):
			m.spawn = 0.0
			mons.start_intro(m)
	if boss:
		info.hp = hp_was
	return n


func _boss_hp(set_id: String, def: Dictionary) -> float:
	var fl := int(def.get("floor", 0))
	if fl <= 0:
		return 0.0
	var floors: Variant = _json(str((cfg.monster_sets[set_id] as Dictionary).get("world", ""))).get("floors", [])
	var entry: Variant = null
	if floors is Array and fl < (floors as Array).size():
		entry = floors[fl]
	elif floors is Dictionary:
		entry = (floors as Dictionary).get(str(fl))
	if entry is Dictionary and (entry as Dictionary).get("boss") is Dictionary:
		return float(entry.boss.get("hp", 0.0))
	return 0.0


## Spawns a Frostgruft theme mob, or the guardian of floor `a.floor` (its look,
## HP and boss kit as on that floor; the boss bar names it).
func _spawn_theme(a: Dictionary) -> int:
	if g.get("monsters") != null or not (g.theme as Dictionary).has("mobs"):
		return 0
	if bool(a.boss):
		var fl := int(a.floor)
		var floors: Variant = _json(str(cfg.roster.frost.world)).get("floors", [])
		var guard: Dictionary = {}
		if floors is Array and fl < (floors as Array).size() and floors[fl] is Dictionary:
			guard = (floors[fl] as Dictionary).get("boss", {})
		var W: Dictionary = g.W
		var b: Dictionary = (W.boss as Dictionary).duplicate(true)
		b.merge(guard, true)
		b.erase("final")
		W.boss = b
		var floor_was := int(g.state.floor)
		g.state.floor = fl
		g._spawn_mob(room_index, _spot(0, 1, float(cfg.spawn.get("boss_distance", 340.0))), "boss")
		g.state.floor = floor_was
		return 1
	var kind := str(a.id)
	if not (g.theme.mobs as Dictionary).has(kind):
		return 0
	var n := int(opts().count)
	for k in range(n):
		g._spawn_mob(room_index, _spot(k, n, float(cfg.spawn.get("distance", 260.0))), kind)
	return n


## ALLE WEG: every enemy, its shots, lobs, telegraphs and corpses (puddles stay).
func _clear_mobs() -> void:
	(g.mobs as Array).clear()
	(g.eshots as Array).clear()
	(g.zones as Array).clear()
	var mons: Variant = g.get("monsters")
	if mons != null:
		(mons.lobs as Array).clear()
		(mons.corpses as Array).clear()
		var zs: Array = mons.zones
		for i in range(zs.size() - 1, -1, -1):
			if str((zs[i] as Dictionary).kind) != "puddle":
				zs.remove_at(i)
		if g.get("drake_rig") != null:
			g.drake_rig.reset()
	if g.get("frost_rigs") != null:
		g.frost_rigs.reset()


# ---------- elements ----------

## Places the armed tool at world point `at`.
func _place(at: Vector2) -> void:
	var group := str(tool.group)
	var spec: Dictionary = cfg.elements[group]
	var r := float(spec.get("r", 60.0))
	var mons: Variant = g.get("monsters")
	match group:
		"puddle":
			if mons == null:
				_say(str(cfg.texts.no_runtime))
				return
			mons._zone({"kind": "puddle", "p": at, "r": r, "T": float(spec.time), "dmg": 0, "st": str(tool.st), "dir": Vector2.ZERO,
				"m": {"id": "testraum", "boss": false, "def": {"name": "Testraum"}}})
			if bool(tool.get("frozen", false)):
				_later.append({"t": float(spec.get("freeze_delay", 0.35)), "do": "frost", "p": at, "r": r})
		"gas":
			var gas: Variant = g.get("gas")
			if gas == null:
				_say(str(cfg.texts.not_here))
				return
			_serial += 1
			gas.emit("testraum:%d" % _serial, str(tool.mat), at, r, float(spec.time), float(g.state.t))
		"react":
			_react(str(tool.do), at, r)


## A reaction tool through the story element systems (src/hell/story_elements.gd).
func _react(what: String, at: Vector2, r: float) -> void:
	var el: Variant = g.get("story_elements")
	var mons: Variant = g.get("monsters")
	if el == null:
		return
	if mons == null and what in ["fire", "frost", "water"]:
		_say(str(cfg.texts.no_runtime))
		return
	match what:
		"fire":
			el.fire_at(at, r)
		"frost":
			el.frost_at(at, r)
		"water":
			el.water_at(at, r)
		"void":
			el.void_at(at, r, 0)
		"shadow":
			g.shadow_at(at)
	if mons != null:
		mons._impact(at, "small")


## PFÜTZEN/GASE WEG: the puddle zones, the pools drawn from them and every gas cloud.
func _wipe() -> void:
	var mons: Variant = g.get("monsters")
	if mons != null:
		var zs: Array = mons.zones
		for i in range(zs.size() - 1, -1, -1):
			if str((zs[i] as Dictionary).kind) == "puddle":
				zs.remove_at(i)
	if g.get("pools") != null:
		g.pools.clear()
	if g.get("gas") != null:
		g.gas.clear()
	_later.clear()


# ---------- the panel ----------

## The fold-out column under the mini-map: the arrow chip under "ESC · MENÜ"
## (src/ui/hud_kit.gd menu_rect), then the rows of StoryTestraum.rows(),
## culled to the column and scrolled by the wheel. Clicks outside it reach the world.
class RoomPanel extends Control:
	var host: Node
	var items: Array = []
	var scroll := 0.0
	var _content := 0.0
	## [Rect2 in content coordinates, action, arg, greyed out]
	var _hits: Array = []

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		_fit()
		rebuild()

	## Covers the whole screen: anchors set under the HUD's CanvasLayer left it 0 x 0
	## (probe 2026-10-31), so its size follows the viewport by hand.
	func _fit() -> void:
		var screen := get_viewport_rect().size
		if position != Vector2.ZERO or size != screen:
			position = Vector2.ZERO
			size = screen

	func _p(key: String, fallback: float) -> float:
		return float((host.cfg.get("panel", {}) as Dictionary).get(key, fallback))

	func _fs() -> int:
		return int(HudStyle.size("font_small"))

	func is_open() -> bool:
		return bool(host.opts().get("open", false))

	## Folds the column out or in (the chip, F1).
	func toggle() -> void:
		host.opts().open = not is_open()
		queue_redraw()

	## Takes the host's rows anew and lays them out.
	func rebuild() -> void:
		items = host.rows()
		_layout()
		scroll = clampf(scroll, 0.0, maxf(0.0, _content + _p("pad", 6.0) * 2.0 - body_rect().size.y))
		queue_redraw()

	func chip_rect() -> Rect2:
		var m := HudKit.menu_rect(size)
		return Rect2(m.position.x, m.end.y + _p("gap", 4.0), m.size.x, _p("chip_height", 22.0))

	func body_rect() -> Rect2:
		var chip := chip_rect()
		var top := chip.end.y + _p("gap", 4.0)
		var room := maxf(40.0, size.y - top - _p("bottom_margin", 92.0))
		return Rect2(chip.position.x, top, chip.size.x, clampf(_content + _p("pad", 6.0) * 2.0, 40.0, room))

	func _line_h() -> float:
		return float(_fs()) + _p("row_pad", 7.0)

	func _layout() -> void:
		_hits = []
		var w := chip_rect().size.x - _p("pad", 6.0) * 2.0
		var fs := _fs()
		var line := _line_h()
		var y := line
		for row: Dictionary in items:
			row.y = y
			match str(row.kind):
				"head":
					row.h = line + 2.0
					_hits.append([Rect2(0, y, w, row.h), row.act, row.arg, false])
				"item":
					row.h = line
					_hits.append([Rect2(0, y, w, line), row.act, row.arg, bool(row.off)])
				"text":
					row.lines = _wrap(str(row.label), w)
					row.h = float((row.lines as Array).size()) * (fs + 3.0) + 4.0
				"opts":
					var x := 0.0
					var yy := y
					if str(row.label) != "":
						yy += fs + 5.0
					var boxes: Array = []
					for o: Dictionary in row.opts:
						var bw := minf(HudStyle.width(FONT, str(o.label), fs) + 10.0, w)
						if x > 0.0 and x + bw > w:
							x = 0.0
							yy += line + 3.0
						var r := Rect2(x, yy, bw, line)
						boxes.append(r)
						_hits.append([r, o.act, o.arg, bool(o.off)])
						x += bw + 4.0
					row.boxes = boxes
					row.h = yy + line - y + 2.0
			y += float(row.h) + _p("row_gap", 2.0)
		_content = y

	func _wrap(text: String, width: float) -> Array:
		var lines: Array = []
		var cur := ""
		for word: String in text.split(" "):
			var test := word if cur == "" else cur + " " + word
			if cur != "" and HudStyle.width(FONT, test, _fs()) > width:
				lines.append(cur)
				cur = word
			else:
				cur = test
		if cur != "":
			lines.append(cur)
		return lines

	func _has_point(point: Vector2) -> bool:
		if not visible:
			return false
		return chip_rect().has_point(point) or (is_open() and body_rect().has_point(point))

	func _gui_input(event: InputEvent) -> void:
		if not (event is InputEventMouseButton):
			return
		var mb := event as InputEventMouseButton
		accept_event()
		if not mb.pressed:
			return
		var step := _p("scroll_step", 42.0)
		var most := maxf(0.0, _content + _p("pad", 6.0) * 2.0 - body_rect().size.y)
		match mb.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				scroll = clampf(scroll - step, 0.0, most)
			MOUSE_BUTTON_WHEEL_DOWN:
				scroll = clampf(scroll + step, 0.0, most)
			MOUSE_BUTTON_LEFT:
				if chip_rect().has_point(mb.position):
					toggle()
				elif is_open():
					_click(mb.position)
		queue_redraw()

	func _click(point: Vector2) -> void:
		var body := body_rect()
		var pad := _p("pad", 6.0)
		var q := point - (body.position + Vector2(pad, pad - scroll))
		for hit: Array in _hits:
			if (hit[0] as Rect2).has_point(q):
				if not bool(hit[3]):
					host.act(str(hit[1]), hit[2])
				return

	func _process(_delta: float) -> void:
		_fit()
		visible = not host.hidden_now()
		queue_redraw()

	func _arrow(at: Vector2, up: bool, tint: Color) -> void:
		var s := 4.0
		var pts := PackedVector2Array([at + Vector2(-s, -s * 0.5), at + Vector2(s, -s * 0.5), at + Vector2(0, s * 0.6)]) if not up \
			else PackedVector2Array([at + Vector2(-s, s * 0.5), at + Vector2(s, s * 0.5), at + Vector2(0, -s * 0.6)])
		draw_colored_polygon(pts, tint)

	func _label(at: Vector2, text: String, tint: Color) -> void:
		HudStyle.text(self, FONT, at, text, _fs(), tint)

	func _draw() -> void:
		var fs := _fs()
		var ink := HudStyle.color("text")
		var dim := HudStyle.color("text_dim")
		var accent := HudStyle.color("accent")
		var mouse := get_local_mouse_position()
		var chip := chip_rect()
		var hot := chip.has_point(mouse)
		HudStyle.panel(self, chip, 1.0)
		if hot or is_open():
			draw_rect(chip, Color(accent, 0.8), false, 1.0)
		var title := str(host.cfg.texts.chip)
		var tw := HudStyle.width(FONT, title, fs)
		var mid := chip.get_center()
		_label(Vector2(mid.x - tw / 2.0 - 6.0, mid.y + fs * 0.35), title, ink if hot or is_open() else dim)
		_arrow(Vector2(chip.end.x - 12.0, mid.y), is_open(), accent if hot or is_open() else dim)
		if not is_open():
			return
		var body := body_rect()
		HudStyle.panel(self, body, 0.96)
		var pad := _p("pad", 6.0)
		var origin := body.position + Vector2(pad, pad - scroll)
		var top := body.position.y + 2.0
		var bottom := body.end.y - 2.0
		var line := _line_h()
		var w := body.size.x - pad * 2.0
		var local := mouse - origin
		if origin.y >= top:
			_label(origin + Vector2(0, line * 0.5 + fs * 0.35), str(host.stat), accent)
		for row: Dictionary in items:
			var ry := origin.y + float(row.y)
			if ry < top or ry + float(row.h) > bottom:
				continue
			match str(row.kind):
				"head":
					var hr := Rect2(origin.x, ry, w, float(row.h))
					draw_rect(hr, Color(accent, 0.22 if hr.has_point(mouse) else 0.12))
					_arrow(Vector2(hr.position.x + 6.0, hr.get_center().y), not bool(row.open), accent)
					_label(Vector2(hr.position.x + 16.0, hr.get_center().y + fs * 0.35), str(row.label), accent)
				"item":
					var ir := Rect2(origin.x, ry, w, line)
					var off := bool(row.off)
					if bool(row.on):
						draw_rect(ir, Color(accent, 0.3))
					elif ir.has_point(mouse) and not off:
						draw_rect(ir, Color(ink, 0.08))
					var tint := Color(dim, 0.45) if off else (ink if bool(row.on) or ir.has_point(mouse) else Color(ink, 0.85))
					_label(Vector2(ir.position.x + 4.0, ir.get_center().y + fs * 0.35), str(row.label), tint)
					var note := str(row.get("note", ""))
					if note != "":
						var nw := HudStyle.width(FONT, note, fs)
						_label(Vector2(ir.end.x - nw - 4.0, ir.get_center().y + fs * 0.35), note, Color(dim, 0.45 if off else 0.9))
				"text":
					var ty := ry + fs + 1.0
					var tint := accent if bool(row.get("group", false)) else dim
					for t: String in row.lines:
						_label(Vector2(origin.x, ty), t, tint)
						ty += fs + 3.0
				"opts":
					if str(row.label) != "":
						_label(Vector2(origin.x, ry + fs + 1.0), str(row.label), dim)
					for i in range((row.opts as Array).size()):
						var o: Dictionary = row.opts[i]
						var box: Rect2 = row.boxes[i]
						var br := Rect2(origin + box.position, box.size)
						var off := bool(o.off)
						var over := box.has_point(local) and not off
						draw_rect(br, Color(accent, 0.35) if bool(o.on) else Color(0, 0, 0, 0.28))
						draw_rect(br, Color(accent, 0.9) if over or bool(o.on) else Color(dim, 0.4), false, 1.0)
						var lw := HudStyle.width(FONT, str(o.label), fs)
						_label(Vector2(br.get_center().x - lw / 2.0, br.get_center().y + fs * 0.35), str(o.label), Color(dim, 0.4) if off else ink)
