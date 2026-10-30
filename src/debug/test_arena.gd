extends Control
## The Testraum's test bar (debug builds; started from the main menu, see
## src/game.gd start_test_arena): over a crypt run in one big room it lets
## everything be tried by hand. An element tool (a left click on the floor
## sets it there instead of an attack: pools, gas, ice, void, lightning, fire,
## a blast, stone, holy light, shadow); enemies and bosses fetched from a list;
## the hero's class (the room starts again with it); a whole specialisation
## with every talent at full rank and its ultimate's stage; the debug cheats;
## and the live frame time (above the bar, also while F1 hides the bar).
## Presets: assets/data/debug_test_arena.json. It only calls the game's own
## moves and effects; the game decides what they do.

const DATA := "res://assets/data/debug_test_arena.json"
const TALENTS := "res://assets/data/talents.json"
## Where the bar and the frame line sit on the 1280 x 720 screen (under the
## map and its ESC line, above the inventory line).
const BAR := Rect2(924, 240, 340, 428)
const FRAME_LINE := Rect2(924, 214, 340, 22)

var game: Node
var data: Dictionary = {}
var _tools: Array = []
var _enemies: Array = []
var _specs: Array = []
var _tool := 0
var _placed := 0
var _bar: Panel
var _frame: Label
var _note: Label
var _class_pick: OptionButton
var _spec_pick: OptionButton
var _stage_pick: OptionButton
var _enemy_pick: OptionButton
var _times := PackedFloat32Array()
var _since := 0.0


## Binds the bar to the game (before it enters the tree).
func setup(owner: Node) -> void:
	game = owner
	data = _load(DATA)
	_tools = data.get("tools", [])
	_enemies = data.get("enemies", [])


static func _load(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
	return parsed if parsed is Dictionary else {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(1280, 720)
	_frame = Label.new()
	_frame.position = FRAME_LINE.position
	_frame.size = FRAME_LINE.size
	_frame.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_frame.add_theme_color_override("font_color", Color("f3ce7d"))
	_frame.add_theme_color_override("font_outline_color", Color("1a1414"))
	_frame.add_theme_constant_override("outline_size", 4)
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_frame)
	_bar = Panel.new()
	_bar.position = BAR.position
	_bar.size = BAR.size
	_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_bar)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(8, 8)
	scroll.size = BAR.size - Vector2(16, 16)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_bar.add_child(scroll)
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(BAR.size.x - 28, 0)
	column.add_theme_constant_override("separation", 4)
	scroll.add_child(column)
	_heading(column, "TESTRAUM (F1: AUS/EIN)")
	_heading(column, "ELEMENT · KLICK AUF BODEN")
	var tool_pick := _pick(column, _tools.map(func(t: Dictionary) -> String: return str(t.get("label", "?"))))
	tool_pick.item_selected.connect(func(index: int) -> void: _tool = index)
	_heading(column, "GEGNER UND BOSSE")
	_enemy_pick = _pick(column, _enemies.map(func(e: Dictionary) -> String: return str(e.get("label", "?"))))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	column.add_child(row)
	_button(row, "HOLEN", _fetch_enemy, true)
	_button(row, "ALLE WEG", _clear_enemies, true)
	_heading(column, "KLASSE (STARTET NEU)")
	var classes: Array = game.balance.get("class_order", [])
	var names: Array = classes.map(func(id: String) -> String: return str(game.balance.classes.get(id, {}).get("name", id)).to_upper())
	_class_pick = _pick(column, names)
	_class_pick.selected = maxi(0, classes.find(_class_id()))
	_class_pick.item_selected.connect(func(index: int) -> void:
		if str(classes[index]) != _class_id():
			game.restart_test_arena(str(classes[index])))
	_heading(column, "SPEZIALISIERUNG")
	_specs = (_load(TALENTS).get("classes", {}).get(_class_id(), {}) as Dictionary).get("specs", [])
	_spec_pick = _pick(column, _specs.map(func(s: Dictionary) -> String: return str(s.get("name", s.get("id", "?"))).to_upper()))
	_spec_pick.item_selected.connect(func(_index: int) -> void: apply_spec())
	_stage_pick = _pick(column, data.get("ultimate_stages", ["STUFE 1", "STUFE 2", "STUFE 3"]))
	_stage_pick.item_selected.connect(func(_index: int) -> void: apply_spec())
	_heading(column, "CHEATS")
	var cheats: Dictionary = game.cheats.data
	var order: Array = cheats.get("order", [])
	for index in range(order.size()):
		var label := str(cheats.get("labels", {}).get(str(order[index]), str(order[index]).to_upper()))
		_button(column, label, func() -> void: game._send_action("cheat", index))
	_note = Label.new()
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD
	_note.custom_minimum_size = Vector2(BAR.size.x - 28, 0)
	_note.add_theme_color_override("font_color", Color("a99d93"))
	column.add_child(_note)
	apply_spec()


## The class of the hero in the room.
func _class_id() -> String:
	return str(game.player_classes.get(1, game.players.get(1, {}).get("class_id", "")))


func _heading(parent: Control, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Color("f3ce7d"))
	parent.add_child(label)


func _pick(parent: Control, items: Array) -> OptionButton:
	var pick := OptionButton.new()
	pick.custom_minimum_size = Vector2(BAR.size.x - 28, 30)
	pick.clip_text = true
	for item: Variant in items:
		pick.add_item(str(item))
	pick.focus_mode = Control.FOCUS_NONE
	parent.add_child(pick)
	return pick


func _button(parent: Control, text: String, callback: Callable, half := false) -> Button:
	var button := Button.new()
	button.text = text
	button.clip_text = true
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2((BAR.size.x - 32) * (0.5 if half else 1.0), 30)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F1:
		_bar.visible = not _bar.visible
		get_viewport().set_input_as_handled()


## True while an element tool is picked: the game's left click sets it then
## instead of an attack (src/game.gd, where it reads the mouse).
func has_tool() -> bool:
	return _tool > 0 and _tool < _tools.size() and str(_tools[_tool].get("kind", "")) != ""


## Sets the picked element at world point `at` (the floor under the mouse).
func place(at: Vector2) -> void:
	if not has_tool():
		return
	var tool: Dictionary = _tools[_tool]
	var r := float(tool.get("radius", 40.0))
	var time := float(tool.get("time", 10.0))
	var hero: Vector2 = game.players[1].pos if game.players.has(1) else at
	var particles: RefCounted = game.view._feedback.particles
	_placed += 1
	match str(tool.kind):
		"pool":
			var dir := (at - hero).normalized() if at.distance_to(hero) > 1.0 else Vector2.RIGHT
			game.boss_moves._pool(at, {"style": str(tool.mat), "radius": r, "time": time, "dps": 0}, dir)
		"gas":
			var gas: RefCounted = game.view.get("_gas")
			if gas != null:
				gas.emit("testraum%d" % _placed, str(tool.mat), at, r, time, float(game.view._clock))
		"ice":
			particles.shatter(at, 12, Vector2.ZERO, 170.0)
			particles.rime_grow(at, 5, r)
			particles.freeze_liquids(at, r)
		"implode":
			particles.implode(at, r)
		"vortex":
			game.boss_moves._zone("vortex", "void", at, r, time)
		"chain":
			var mid := hero.lerp(at, 0.5) + (at - hero).orthogonal().normalized() * 24.0
			game.hero_skills._event("chain", [hero, mid, at], 0.45)
		"storm":
			game.hero_skills._zone({"kind": "storm", "pos": at, "radius": r, "time": time, "owner": 1, "dps": 0.0, "tick": 0.0})
		"fire":
			particles.fire_burst(at, r)
			particles.embers(at, r * 0.6, 8)
		"kick":
			particles.kick(at, r, 1.0)
		"quake":
			game.add_fx("zone_burst", at, r, {"style": "quake"})
		"holy":
			game.add_fx("level_up", at, r)
		"shadow":
			particles.shadow(at, 6, r)
	_note.text = "%s gesetzt." % str(tool.get("label", ""))


## Fetches the picked enemy or boss beside the hero (on open floor).
func _fetch_enemy() -> void:
	if not game.players.has(1) or _enemies.is_empty():
		return
	var entry: Dictionary = _enemies[_enemy_pick.selected]
	var kind := str(entry.kind)
	var hero: Vector2 = game.players[1].pos
	var reach := float(data.get("spawn_distance", 170.0))
	# the first open floor round the hero: far first, then nearer
	var spot := hero
	var particles: RefCounted = game.view._feedback.particles
	var found := false
	for share: float in [1.0, 0.75, 0.5, 0.3]:
		for step in range(8):
			var dir := Vector2.from_angle(PI + float(step) * TAU / 8.0)
			if not particles.solid(hero + dir * reach * share) and not particles.solid(hero + dir * reach * share * 0.5):
				spot = hero + dir * reach * share
				found = true
				break
		if found:
			break
	var enemy: Dictionary = game._create_enemy(kind, spot)
	if kind == "boss":
		# the Leerenrufer's rig and body parts, as on his floor
		enemy.rig = "void"
		game.body_parts.attach(enemy, "void")
	game.enemies.append(enemy)
	game.phase = "combat"
	_note.text = "%s geholt." % str(entry.get("label", kind))


func _clear_enemies() -> void:
	game.enemies.clear()
	game.bullets.clear()
	game.boss_moves.reset()
	_note.text = "Alle Gegner und Boss-Felder entfernt."


## Gives the hero the picked specialisation whole: every talent at full rank,
## its actives on the bar, its ultimate at the picked stage, free casts.
func apply_spec() -> void:
	if _specs.is_empty() or not game.players.has(1):
		return
	var spec: Dictionary = _specs[clampi(_spec_pick.selected, 0, _specs.size() - 1)]
	var talents: Dictionary = _load(TALENTS).get("talents", {})
	var ranks := {}
	var bar: Array = []
	var ultimate := ""
	for id: String in spec.get("talents", []):
		var talent: Dictionary = talents.get(id, {})
		ranks[id] = int(talent.get("ranks", 3)) if str(talent.get("kind", "")) != "ultimate" else 1
		if str(talent.get("kind", "")) == "active" and bar.size() < 4:
			bar.append(id)
		elif str(talent.get("kind", "")) == "ultimate":
			ultimate = id
	var build := {"class": _class_id(), "level": 30, "ranks": ranks, "ultimate": ultimate, "soul_tier": _stage_pick.selected,
		"bar": bar, "companion": "wolf", "free": true, "difficulty": str(game.progress.profile.get("difficulty", "normal")), "nightmare_firsts": []}
	game.talent_combat.set_build(1, build)
	_note.text = "%s: alle Talente, Ultimate Stufe %d." % [str(spec.get("name", "")), _stage_pick.selected + 1]


func _process(delta: float) -> void:
	_times.append(delta * 1000.0)
	var window := int(data.get("frame_window", 120))
	if _times.size() > window:
		_times = _times.slice(_times.size() - window)
	_since += delta
	if _since < 0.25:
		return
	_since = 0.0
	var sorted := _times.duplicate()
	sorted.sort()
	var sum := 0.0
	for t: float in sorted:
		sum += t
	var avg := sum / maxf(1.0, float(sorted.size()))
	var p95: float = sorted[int(float(sorted.size() - 1) * 0.95)] if not sorted.is_empty() else 0.0
	_frame.text = "%.1f MS  P95 %.1f  %d FPS" % [avg, p95, int(Engine.get_frames_per_second())]
