extends Control
## Read-only session pages and action signals; the game retains all authority.
signal resume_pressed
signal leave_pressed
signal main_action_pressed
signal reward_requested
signal display_mode_requested
## Pixel / HD graphics switch (src/core/graphics_settings.gd); the game applies it.
signal graphics_mode_requested
## A debug cheat button (index into debug_cheats.json "order").
signal cheat_requested(index: int)
## Story mode: "Talente" was chosen. The pause has hidden itself; the host opens its talent screen.
signal talents_requested
## Story mode: "Inventar" was chosen. The pause has hidden itself; the host opens the inventory.
signal inventory_requested
## Story mode: an option on the Optionen page changed (OptionsPanel.changed, passed on).
## Fullscreen and graphics also still come as display_mode_requested / graphics_mode_requested.
signal option_changed(key: String, value: Variant)

const CryptUI = preload("res://src/ui/crypt_ui.gd")
const PerkIcons = preload("res://src/perk_icons.gd")
const ClassPerks = preload("res://src/player/class_perks.gd")
const QuestView = preload("res://src/ui/quest_view.gd")
const TalentScreen = preload("res://src/ui/talent_screen.gd")
const OptionsPanel = preload("res://src/ui/options_panel.gd")
## A save slot button (1..3): the host saves the start of the current floor.
signal save_requested(slot: int)

const SECTIONS := ["overview","quest","map","floor","party","reward","talents","inventory","elements","options","controls","display","session","save","cheats"]
const TITLES := ["Übersicht","Auftrag","Karte","Etage","Gruppe & Perks","Belohnung","Talente","Inventar","Elemente","Optionen","Steuerung","Anzeige","Sitzung","Speichern","Cheats"]
## Pages each mode shows: the crypt run, and the story worlds (Krypta, Frostgruft, Hölle).
## Story: Weiterspielen sits above these buttons and Hauptmenü below them.
const MODE_SECTIONS := {
	"crypt": ["overview","quest","map","party","reward","controls","display","session","save","cheats"],
	"story": ["floor","talents","inventory","elements","options","controls","save"],
}
## Elemente page (story): the reactions lexicon and its pixel signs (src/hell/story_elements.gd).
const StoryElements = preload("res://src/hell/story_elements.gd")
## Elemente page: one sign's pixel size, the gap between the two columns and between rows.
const REACTION_CELL := 4.0
const REACTION_GAP := Vector2(24,14)
## Elemente page rows as last shown: [{id, seen}] in the lexicon's order.
var reaction_rows: Array = []
var _reaction_box: Control
## Older page names the story mode answers with its own pages.
const STORY_ALIASES := {"overview": "floor", "quest": "floor", "map": "floor", "display": "options"}
## Story layout (design px): frame, page inset, page, first section button.
const STORY_PANEL := Rect2(40,24,1200,672)
const STORY_INSET := Rect2(304,104,912,544)
const STORY_PAGE := Rect2(320,116,880,520)
const STORY_NAV := Rect2(72,112,216,40)
const STORY_STEP := 48.0
## Extra space above Hauptmenü, apart from the pages.
const STORY_GAP := 24.0
## Etage page: width of the goal column; the map fills the rest.
const STORY_QUEST_W := 480.0
## Steuerung page: space between the two columns. Each column is as wide as its
## longest action plus its longest key (the free width split evenly on top), so
## the keys do not wrap; only when both together do not fit does a column shrink
## and its tab stop (action | key) stay at most this share of its width.
const CONTROLS_GAP := 24.0
const CONTROLS_TAB_SHARE := 0.55
## Space between the action and the key of one row.
const CONTROLS_CELL_GAP := 12.0
## Story pause: how dark the shade over the whole screen is (the HUD's corners
## must not show beside the frame; the crypt keeps its lighter shade).
const STORY_SHADE_ALPHA := 0.95
## Returns the save slot lines (SaveStore.summaries); set by the game.
var save_rows := Callable()
var save_buttons: Array[Button] = []
var save_note: Label
var save_hint: Label
var _save_enabled := false
## "crypt" or "story" (use_story_mode).
var mode := "crypt"
var controls_label: Label
## The Auftragsliste (src/ui/quest_view.gd), the same in every story.
var quest_view: QuestView
## The soul shards of the profile, top right in every story (set_shards).
var shard_label: Label
var _shard_icon: Control
var _shard_clock := 0.0
## Story map: a canvas the world draws its big map on (story_map_draw(canvas)).
## In story mode it fills the right column of the Etage page.
var story_map: Control
var story_map_draw := Callable()
var section := "overview"
var pages: Dictionary = {}
var navigation: Dictionary = {}
var pause_note: Label
var overview_label: Label
var party_details: Label
var session_details: Label
var map_view: Control
var map_note: Label
var resume_button: Button
## "Zum Hauptmenü" (story: "Hauptmenü", the last section button).
var leave_button: Button
var main_action_button: Button
var shade: ColorRect
var display_mode_button: Button
var display_status: Label
var graphics_status: Label
var graphics_button: Button
## The shared options (src/ui/options_panel.gd) on the story Optionen page.
var options_panel: Control
var _definitions: Array = []
var cheat_buttons: Array[Button] = []
var _cheat_data: Dictionary = {}
var _cheats_enabled := false
var _definition_by_id: Dictionary = {}
var _frame: Panel
var _inset: Panel
var _heading: Label
var _hint: Label
var _controls_grid: HBoxContainer
var _fullscreen := false
var _graphics_mode := "pixel"
## Story section buttons top to bottom (Weiterspielen ... Hauptmenü).
var _nav_order: Array[Button] = []

func _ready() -> void:
	size = Vector2(1280,720)
	mouse_filter = Control.MOUSE_FILTER_STOP
	shade = ColorRect.new()
	shade.color = Color(CryptUI.INK,0.82)
	shade.size = size
	add_child(shade)
	_frame = Panel.new()
	_frame.position = Vector2(160,64)
	_frame.size = Vector2(960,592)
	add_child(_frame)
	# The page area sits in its own inset, apart from the section list.
	_inset = Panel.new()
	_inset.position = Vector2(420,164)
	_inset.size = Vector2(680,398)
	_inset.add_theme_stylebox_override("panel",CryptUI.box("inset"))
	_inset.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_inset)
	_heading = CryptUI.heading("PAUSE",32)
	_heading.position = Vector2(192,84)
	add_child(_heading)
	pause_note = _text(self,"",Vector2(432,128),Vector2(656,26),13)
	_shard_icon = Control.new()
	_shard_icon.position = Vector2(836,88)
	_shard_icon.size = Vector2(36,36)
	_shard_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shard_icon.draw.connect(func() -> void: TalentScreen.draw_crystal(_shard_icon, Vector2(18,18), 0.75, _shard_clock))
	add_child(_shard_icon)
	shard_label = _text(self,"",Vector2(874,96),Vector2(220,24),16)
	shard_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	shard_label.add_theme_color_override("font_color",Color("e2d4ff"))
	pause_note.add_theme_color_override("font_color",CryptUI.SAND)
	for index in range(SECTIONS.size()):
		var key: String = SECTIONS[index]
		navigation[key] = _button(self,TITLES[index],Vector2(192,160+index*36),Vector2(208,32),select_section.bind(key))
		var page := Control.new()
		page.position = Vector2(432,176)
		page.size = Vector2(656,378)
		page.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(page)
		pages[key] = page
	overview_label = _text(pages.overview,"",Vector2.ZERO,Vector2(640,378),16)
	map_view = load("res://src/dungeon/dungeon_map.gd").new()
	map_view.position = Vector2(16,28)
	map_view.size = Vector2(148,52)
	map_view.scale = Vector2(4,4)
	pages.map.add_child(map_view)
	map_note = _text(pages.map,"",Vector2(0,258),Vector2(640,118),15)
	var party_scroll := ScrollContainer.new()
	party_scroll.size = Vector2(656,378)
	party_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pages.party.add_child(party_scroll)
	party_details = _text(party_scroll,"",Vector2.ZERO,Vector2(620,378),15)
	party_details.custom_minimum_size = Vector2(620,378)
	party_details.add_theme_constant_override("line_spacing",4)
	quest_view = QuestView.new()
	quest_view.size = Vector2(656,378)
	quest_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pages.quest.add_child(quest_view)
	story_map = Control.new()
	story_map.size = Vector2(656,378)
	story_map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	story_map.visible = false
	story_map.draw.connect(func() -> void: if story_map_draw.is_valid(): story_map_draw.call(story_map))
	pages.map.add_child(story_map)
	controls_label = _text(pages.controls,"Bewegen: WASD\nZielen: Maus\nAngreifen: Linksklick\nTalente: 1 2 3 4 (im Talentmenü gelernt), Ultimate: R\nBegleiter: 5 6, Rechtsklick aufs Symbol: Auto an / aus\nAusweichen / Block: Shift\nTalentmenü (auch im Lauf): K\nTür / Treppe nutzen: E\nMenü öffnen / schließen: Esc\nVollbild / Fenster: F11 oder Alt + Enter\n\nGegner lassen grüne EXP fallen; das Team\nlevelt gemeinsam. Karten rechts per Klick.\n\nFür den Raumwechsel das lebende Team\nam Ausgang sammeln.",Vector2.ZERO,Vector2(640,378),16)
	display_status = _text(pages.display,"",Vector2.ZERO,Vector2(640,64),24)
	display_mode_button = _button(pages.display,"Vollbild einschalten",Vector2(0,96),Vector2(416,44),func(): display_mode_requested.emit())
	graphics_status = _text(pages.display,"Grafik: PIXEL",Vector2(0,164),Vector2(640,40),16)
	graphics_button = _button(pages.display,"Zu HD wechseln",Vector2(0,196),Vector2(416,44),func(): graphics_mode_requested.emit())
	_text(pages.display,"F11 oder Alt + Enter wechseln die Ansicht.\nEsc öffnet weiterhin das Pausenmenü.\n\nDie Spielansicht nutzt die gesamte Fläche.\nHerzen und Menü bleiben am Bildschirmrand.",Vector2(0,264),Vector2(640,128),16)
	# Story Optionen: the same panel the title menu uses.
	options_panel = OptionsPanel.new()
	options_panel.size = STORY_PAGE.size
	pages.options.add_child(options_panel)
	options_panel.changed.connect(_on_option_changed)
	options_panel.set_exit_focus(navigation.options)
	session_details = _text(pages.session,"",Vector2.ZERO,Vector2(640,378),16)
	save_hint = _text(pages.save,"Ein Klick speichert den Beginn dieser Ebene.\nLaden und Löschen: Hauptmenü, SPIELSTÄNDE.",Vector2.ZERO,Vector2(640,52),16)
	for slot in range(1,4):
		var button := _button(pages.save,"PLATZ %d" % slot,Vector2(0,64+(slot-1)*54),Vector2(640,44),func(): save_requested.emit(slot))
		button.clip_text = true
		save_buttons.append(button)
	save_note = _text(pages.save,"",Vector2(0,232),Vector2(640,60),16)
	save_note.add_theme_color_override("font_color",CryptUI.GOLD)
	resume_button = _button(self,"Weiterspielen",Vector2(192,528),Vector2(208,42),func(): resume_pressed.emit())
	leave_button = _button(self,"Zum Hauptmenü",Vector2(192,582),Vector2(208,34),func(): leave_pressed.emit())
	main_action_button = _button(self,"",Vector2(432,574),Vector2(656,42),func(): main_action_pressed.emit())
	_hint = _text(self,"ESC · Zurück zum Spiel",Vector2(432,626),Vector2(656,22),12)
	_layout_navigation()
	select_section("overview")
	visible = false
	set_display_state(false,Vector2(1280,720))


## Story worlds (Krypta, Frostgruft, Hölle): a wider pause with the sections
## Weiterspielen · Etage (goals and map) · Talente · Inventar · Optionen ·
## Steuerung · Speichern · Hauptmenü. `controls_text` fills Steuerung (see
## set_controls_text). Call once after adding.
func use_story_mode(controls_text: String) -> void:
	mode = "story"
	shade.color = Color(CryptUI.INK,STORY_SHADE_ALPHA)
	map_view.visible = false
	map_note.visible = false
	main_action_button.visible = false
	# "PAUSE" already says it; no second title line
	pause_note.visible = false
	_frame.position = STORY_PANEL.position
	_frame.size = STORY_PANEL.size
	_inset.position = STORY_INSET.position
	_inset.size = STORY_INSET.size
	_heading.position = Vector2(STORY_NAV.position.x,36)
	_shard_icon.position = Vector2(952,40)
	shard_label.position = Vector2(990,48)
	shard_label.size = Vector2(230,24)
	_hint.position = Vector2(STORY_PAGE.position.x,656)
	_hint.size = Vector2(STORY_PAGE.size.x,24)
	_hint.add_theme_color_override("font_color",CryptUI.MUTED)
	for key: String in pages:
		pages[key].position = STORY_PAGE.position
		pages[key].size = STORY_PAGE.size
	# Etage: the goals on the left, the map filling the right column.
	quest_view.reparent(pages.floor,false)
	quest_view.position = Vector2(0,8)
	quest_view.size = Vector2(STORY_QUEST_W,STORY_PAGE.size.y-8)
	var divider := ColorRect.new()
	divider.color = CryptUI.STONE
	divider.position = Vector2(STORY_QUEST_W+10,0)
	divider.size = Vector2(2,STORY_PAGE.size.y)
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pages.floor.add_child(divider)
	story_map.reparent(pages.floor,false)
	story_map.position = Vector2(STORY_QUEST_W+24,0)
	story_map.size = Vector2(STORY_PAGE.size.x-STORY_QUEST_W-24,STORY_PAGE.size.y)
	story_map.visible = true
	leave_button.text = "Hauptmenü"
	save_hint.text = "Ein Klick speichert den Beginn dieser Etage.\nLaden und Löschen: Hauptmenü, SPIELSTÄNDE."
	# Elemente: the lexicon at once; the world marks the discovered ones (set_story_state)
	set_reactions([])
	set_controls_text(controls_text)
	_layout_navigation()
	select_section("floor")


## Steuerung text. Groups are split by a blank line; the first line of a group is
## its header (capitals), then "Aktion: Taste" lines. Groups show as headed blocks
## in two columns; text without a blank line stays one plain label.
func set_controls_text(text: String) -> void:
	controls_label.text = text
	if _controls_grid != null:
		_controls_grid.queue_free()
		_controls_grid = null
	var groups := control_groups(text)
	controls_label.visible = groups.is_empty()
	if groups.is_empty(): return
	_controls_grid = HBoxContainer.new()
	_controls_grid.size = pages.controls.size
	_controls_grid.add_theme_constant_override("separation",int(CONTROLS_GAP))
	_controls_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pages.controls.add_child(_controls_grid)
	# Groups keep their order; the left column takes about half of the rows.
	var total := 0
	for group: Dictionary in groups: total += (group.rows as Array).size()+1
	var split: Array = [[],[]]
	var used := 0
	var right := false
	for group: Dictionary in groups:
		var count: int = (group.rows as Array).size()+1
		right = right or used*2+count > total and used > 0
		split[1 if right else 0].append(group)
		used += count
	var font: Font = get_theme_font("font","Label")
	# each column: its longest action (the tab stop) and its longest key
	var tabs: Array[float] = [96.0,96.0]
	var keys: Array[float] = [0.0,0.0]
	for side in range(2):
		for group: Dictionary in split[side]:
			for row: Array in group.rows:
				if str(row[1]).is_empty(): continue
				tabs[side] = maxf(tabs[side],ceilf(font.get_string_size(str(row[0]),HORIZONTAL_ALIGNMENT_LEFT,-1,16).x))
				keys[side] = maxf(keys[side],ceilf(font.get_string_size(str(row[1]),HORIZONTAL_ALIGNMENT_LEFT,-1,16).x))
	var room: float = pages.controls.size.x-CONTROLS_GAP
	var needs: Array[float] = [tabs[0]+CONTROLS_CELL_GAP+keys[0],tabs[1]+CONTROLS_CELL_GAP+keys[1]]
	var widths: Array[float] = []
	for side in range(2):
		if needs[0]+needs[1] <= room: widths.append(needs[side]+(room-needs[0]-needs[1])*0.5)
		else: widths.append(room*needs[side]/(needs[0]+needs[1]))
	for side in range(2):
		var column := VBoxContainer.new()
		column.custom_minimum_size = Vector2(floorf(widths[side]),0)
		column.add_theme_constant_override("separation",8)
		_controls_grid.add_child(column)
		# the tab stop: the longest action in this column (capped only when it must shrink)
		var tab: float = tabs[side] if needs[0]+needs[1] <= room else minf(tabs[side],widths[side]*CONTROLS_TAB_SHARE)
		for group: Dictionary in split[side]:
			if column.get_child_count() > 0:
				var gap := Control.new()
				gap.custom_minimum_size = Vector2(0,12)
				column.add_child(gap)
			column.add_child(_row_label(str(group.header),CryptUI.GOLD,0.0))
			for row: Array in group.rows:
				if str(row[1]).is_empty():
					column.add_child(_row_label(str(row[0]),CryptUI.BONE,0.0))
					continue
				var line := HBoxContainer.new()
				line.add_theme_constant_override("separation",int(CONTROLS_CELL_GAP))
				line.add_child(_row_label(str(row[0]),CryptUI.BONE,tab))
				var key := _row_label(str(row[1]),CryptUI.CREAM,0.0)
				key.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				line.add_child(key)
				column.add_child(line)


## Splits a controls text into [{header, rows: [[action, key]]}]; [] when it has
## no blank line. A line without ": " keeps its text as the action, key "".
static func control_groups(text: String) -> Array:
	var clean := text.replace("\r","").strip_edges()
	if not clean.contains("\n\n"): return []
	var out: Array = []
	for block: String in clean.split("\n\n",false):
		var lines := block.strip_edges().split("\n",false)
		if lines.is_empty(): continue
		var rows: Array = []
		for index in range(1,lines.size()):
			var line := lines[index].strip_edges()
			var cut := line.find(": ")
			rows.append([line.substr(0,cut),line.substr(cut+2)] if cut > 0 else [line,""])
		out.append({"header": lines[0].strip_edges(), "rows": rows})
	return out


## Story worlds feed their pages: {overview: text, quest_title: "ETAGE 3",
## quests: [{text, done, main}], reactions: [discovered reaction ids]}.
func set_story_state(info: Dictionary) -> void:
	overview_label.text = str(info.get("overview", ""))
	quest_view.set_goals(info.get("quests", []), str(info.get("quest_title", "")))
	story_map.queue_redraw()
	if info.get("reactions") is Array: set_reactions(info.reactions)


## Elemente page: every reaction of the lexicon (assets/data/reactions_lexicon.json,
## its order) in two columns with its pixel sign, name, cause and effect; the
## ones in `seen` (the profile's discovered ids) marked ENTDECKT in gold, the
## others greyed. Rebuilt on each call (the pause opens rarely).
func set_reactions(seen: Array) -> void:
	var lex: Dictionary = StoryElements.lexicon()
	var all: Dictionary = lex.get("reactions", {})
	var order: Array = lex.get("order", all.keys())
	var words: Dictionary = lex.get("page", {})
	var page: Control = pages.elements
	if _reaction_box != null:
		page.remove_child(_reaction_box)
		_reaction_box.queue_free()
	_reaction_box = Control.new()
	_reaction_box.size = page.size
	_reaction_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(_reaction_box)
	reaction_rows.clear()
	var found := 0
	for id: Variant in order:
		if all.has(str(id)) and seen.has(str(id)): found += 1
	var title := _text(_reaction_box,str(words.get("title","ELEMENT-REAKTIONEN")),Vector2.ZERO,Vector2(page.size.x*0.6,24),16)
	title.add_theme_color_override("font_color",CryptUI.GOLD)
	var count := _text(_reaction_box,str(words.get("count","%d / %d")) % [found,all.size()],Vector2(page.size.x*0.6,0),Vector2(page.size.x*0.4,24),16)
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var pct := roundi((float(lex.get("reward",{}).get("hero_exp_mul",1.0))-1.0)*100.0)
	var hint := _text(_reaction_box,str(words.get("hint","%d")) % pct,Vector2(0,26),Vector2(page.size.x,24),16)
	hint.add_theme_color_override("font_color",CryptUI.SAND)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(0,62)
	scroll.size = Vector2(page.size.x,page.size.y-62)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.focus_mode = Control.FOCUS_NONE
	_reaction_box.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation",int(REACTION_GAP.x))
	grid.add_theme_constant_override("v_separation",int(REACTION_GAP.y))
	scroll.add_child(grid)
	# two columns beside the scroll bar; the text beside the sign wraps
	var column := floorf((page.size.x-REACTION_GAP.x-16.0)*0.5)
	var badge := Vector2(9,9)*REACTION_CELL
	for id: Variant in order:
		var key := str(id)
		if not all.has(key): continue
		var info: Dictionary = all[key]
		var known := seen.has(key)
		reaction_rows.append({"id": key, "seen": known})
		var cell := HBoxContainer.new()
		cell.custom_minimum_size = Vector2(column,0)
		cell.add_theme_constant_override("separation",12)
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		grid.add_child(cell)
		var icon := Control.new()
		icon.custom_minimum_size = badge
		icon.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.draw.connect(func() -> void: StoryElements.draw_icon(icon,key,Vector2.ZERO,REACTION_CELL,1.0 if known else 0.6,not known))
		cell.add_child(icon)
		var lines := VBoxContainer.new()
		lines.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lines.add_theme_constant_override("separation",2)
		lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(lines)
		var text_w := column-badge.x-12.0
		var head := str(info.get("name",key))+"  ·  "+str(words.get("seen" if known else "unseen",""))
		lines.add_child(_wrap_label(head,CryptUI.GOLD if known else CryptUI.MUTED,text_w))
		lines.add_child(_wrap_label(str(words.get("cause",""))+str(info.get("cause","")),CryptUI.BONE if known else CryptUI.SAND,text_w))
		lines.add_child(_wrap_label(str(words.get("effect",""))+str(info.get("effect","")),CryptUI.BONE if known else CryptUI.SAND,text_w))


## One wrapped 16 px line block of the Elemente page, `width` px wide.
func _wrap_label(value: String, colour: Color, width: float) -> Label:
	var label := _row_label(value,colour,width)
	label.custom_minimum_size = Vector2(width,0)
	return label


## Stacks the section buttons of the current mode without gaps.
func _layout_navigation() -> void:
	var shown: Array = MODE_SECTIONS[mode]
	for key: String in SECTIONS:
		navigation[key].visible = key in shown and (key != "cheats" or _cheats_enabled)
	if mode == "story":
		_layout_story_navigation()
		return
	var row := 0
	for key: String in SECTIONS:
		if navigation[key].visible:
			navigation[key].position = Vector2(192,160+row*36)
			row += 1


## Story column: Weiterspielen, the page buttons, then Hauptmenü after a gap.
func _layout_story_navigation() -> void:
	_nav_order = [resume_button]
	for key: String in MODE_SECTIONS.story: _nav_order.append(navigation[key])
	_nav_order.append(leave_button)
	for index in range(_nav_order.size()):
		var button := _nav_order[index]
		var gap := STORY_GAP if button == leave_button else 0.0
		button.position = Vector2(STORY_NAV.position.x,STORY_NAV.position.y+index*STORY_STEP+gap)
		button.size = STORY_NAV.size
	_link_story_focus()


## Story focus: the section buttons top to bottom (no wrap); right enters the
## open page where it has controls (Optionen, Speichern), left leads back.
func _link_story_focus() -> void:
	if _nav_order.is_empty(): return
	var target: Control = null
	if section == "options": target = options_panel.first_focus()
	elif section == "save" and _save_enabled: target = save_buttons[0]
	for index in range(_nav_order.size()):
		var button := _nav_order[index]
		var above: Control = _nav_order[maxi(index-1,0)]
		var below: Control = _nav_order[mini(index+1,_nav_order.size()-1)]
		button.focus_neighbor_top = button.get_path_to(above)
		button.focus_neighbor_bottom = button.get_path_to(below)
		button.focus_previous = button.focus_neighbor_top
		button.focus_next = button.focus_neighbor_bottom
		button.focus_neighbor_left = button.get_path_to(button)
		button.focus_neighbor_right = button.get_path_to(target if target != null else button)
	for index in range(save_buttons.size()):
		var slot := save_buttons[index]
		slot.focus_neighbor_left = slot.get_path_to(navigation.save)
		slot.focus_neighbor_right = slot.get_path_to(slot)
		slot.focus_neighbor_top = slot.get_path_to(save_buttons[maxi(index-1,0)])
		slot.focus_neighbor_bottom = slot.get_path_to(save_buttons[mini(index+1,save_buttons.size()-1)])


## Gives the keyboard / pad focus to the open section's button (story), so the
## focus frame and the lit section are the same button; Weiterspielen otherwise.
func focus_section() -> void:
	var target: Button = resume_button
	if mode == "story" and navigation.has(section) and (navigation[section] as Button).visible:
		target = navigation[section]
	if target.is_inside_tree(): target.grab_focus()


## Shows the profile's soul shards (the same in the crypt, the Frostgruft and the Hölle).
func set_shards(have: int) -> void:
	shard_label.text = "SEELENSPLITTER %d" % have


func _process(delta: float) -> void:
	if not visible or _shard_icon == null: return
	_shard_clock += delta
	_shard_icon.queue_redraw()


## A pad's B closes the story pause like Esc does (the host handles the Esc key).
func _unhandled_input(event: InputEvent) -> void:
	if mode == "story" and visible and event is InputEventJoypadButton and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		resume_pressed.emit()


## Covers expanded aspect ratios while the menu keeps its centered design size.
func set_canvas_size(dimensions: Vector2, design_origin: Vector2) -> void:
	if shade == null: return
	shade.position = -design_origin
	shade.size = dimensions


## The graphics line and button, and the HD check on Optionen: `note` says what
## the mode means in this world, `value` is "pixel" or "hd".
func set_graphics_state(note: String, value: String) -> void:
	_graphics_mode = value
	if options_panel != null:
		options_panel.show_value("graphics",value)
		options_panel.set_graphics_note(note)
	if graphics_status == null or graphics_button == null: return
	graphics_status.text = note
	graphics_button.text = "Zu Pixel wechseln" if value == "hd" else "Zu HD wechseln"


## Reflects the local window mode; changing it never sends a gameplay action.
func set_display_state(fullscreen: bool, _logical_size: Vector2) -> void:
	_fullscreen = fullscreen
	if options_panel != null: options_panel.show_value("fullscreen",fullscreen)
	if display_status == null or display_mode_button == null: return
	display_status.text = "Ansicht: Vollbild" if fullscreen else "Ansicht: Fenster"
	display_mode_button.text = "Zum Fenster wechseln" if fullscreen else "Vollbild einschalten"


## Optionen changes: fullscreen and graphics also go out as the old requests,
## so a host that only knows those keeps working; everything goes out as option_changed.
func _on_option_changed(key: String, value: Variant) -> void:
	if key == "fullscreen" and bool(value) != _fullscreen:
		_fullscreen = bool(value)
		display_mode_requested.emit()
	elif key == "graphics" and str(value) != _graphics_mode:
		_graphics_mode = str(value)
		graphics_mode_requested.emit()
	option_changed.emit(key,value)

## Builds the debug cheat buttons from debug_cheats.json (labels, order).
func configure_cheats(data: Dictionary) -> void:
	_cheat_data = data
	for button: Button in cheat_buttons: button.queue_free()
	cheat_buttons.clear()
	var order: Array = data.get("order", [])
	for index in range(order.size()):
		var label := str(data.get("labels", {}).get(str(order[index]), str(order[index]).to_upper()))
		var button := _button(pages.cheats, label, Vector2((index % 2) * 328, 34 + (index / 2) * 52), Vector2(316, 44), func(): cheat_requested.emit(index))
		cheat_buttons.append(button)
	_text(pages.cheats, "NUR ZUM TESTEN · Debug-Build, Solo-Lauf", Vector2.ZERO, Vector2(640, 24), 14).add_theme_color_override("font_color", CryptUI.SAND)


## The Cheats page exists only in a debug build during a solo run.
func set_cheats_enabled(enabled: bool) -> void:
	if enabled == _cheats_enabled and navigation.cheats.visible == (enabled and "cheats" in MODE_SECTIONS[mode]): return
	_cheats_enabled = enabled
	_layout_navigation()
	if not enabled and section == "cheats": select_section("overview")

## Saving needs the host in a run; clients see the page with the buttons off.
func set_save_enabled(enabled: bool) -> void:
	if enabled == _save_enabled: return
	_save_enabled = enabled
	if section == "save": refresh_save()
	if mode == "story": _link_story_focus()


## Rewrites the slot buttons from the save files; `message` reports the last save.
func refresh_save(message: String = "") -> void:
	var rows: Array = save_rows.call() if save_rows.is_valid() else []
	for index in range(save_buttons.size()):
		var text := "PLATZ %d" % (index + 1)
		if index < rows.size(): text = str(rows[index].get("short", rows[index].text))
		save_buttons[index].text = text
		save_buttons[index].disabled = not _save_enabled
	save_note.text = message if not message.is_empty() else ("" if _save_enabled else "Nur der Host kann speichern.")

## Uses the existing data-driven perk definitions for names and atlas icons.
func configure(definitions: Array) -> void:
	_definitions = definitions
	_definition_by_id.clear()
	for definition: Dictionary in definitions:
		_definition_by_id[str(definition.get("id",""))] = definition

## Selects one information page, keeping every other page out of the playfield.
## Story mode reads overview / quest / map as Etage and display as Optionen;
## Talente and Inventar hide the pause and emit their request.
func select_section(key: String) -> void:
	if mode == "story": key = STORY_ALIASES.get(key, key)
	if key not in SECTIONS or key not in MODE_SECTIONS[mode]: return
	if key == "cheats" and not _cheats_enabled: return
	if key == "reward":
		reward_requested.emit()
		return
	if key == "talents" or key == "inventory":
		visible = false
		if key == "talents": talents_requested.emit()
		else: inventory_requested.emit()
		return
	section = key
	if key == "save": refresh_save()
	for id: String in pages:
		pages[id].visible = id == key
		# The open section keeps the raised hover frame and gold text.
		var button: Button = navigation[id]
		if id == key:
			button.add_theme_color_override("font_color",CryptUI.GOLD)
			button.add_theme_stylebox_override("normal",CryptUI.box("button_hover"))
		else:
			button.remove_theme_color_override("font_color")
			button.remove_theme_stylebox_override("normal")
	if mode == "story": _link_story_focus()

## Displays authoritative snapshots. Buttons only request ordinary game actions.
func set_state(snapshot: Dictionary, local_id: int, host: bool, port: int, solo_paused: bool) -> void:
	pause_note.text = "SOLO · SPIEL ANGEHALTEN" if solo_paused else "MEHRSPIELER · DIE WELT LÄUFT WEITER"
	var rooms: Array = snapshot.get("floor_map",[])
	var layout: Dictionary = snapshot.get("room_layout",{})
	var players: Dictionary = snapshot.get("players",{})
	var player: Dictionary = players.get(local_id,{})
	var maximum_players := int(snapshot.get("max_players",4))
	var cleared := rooms.filter(func(room: Dictionary): return room.get("cleared",false)).size()
	quest_view.set_goals(QuestView.crypt_goals(snapshot),"EBENE %d" % int(snapshot.get("floor_index",1)))
	var phase: String = snapshot.get("phase","")
	var phase_name: String = {"combat":"Im Kampf","reward":"Belohnung wählen","explore":"Freie Erkundung","dead":"Gruppe gefallen","victory":"Geschafft"}.get(phase,phase.capitalize())
	var boss_room := "—"
	var boss_status := "Noch nicht besiegt"
	for room: Dictionary in rooms:
		if room.get("boss",false):
			boss_room = room.get("title","BOSSRAUM")
			if room.get("cleared",false): boss_status = "Besiegt"
	for enemy: Dictionary in snapshot.get("enemies",[]):
		if enemy.get("boss",false): boss_status = "Im Kampf · %d / %d LP" % [enemy.hp,enemy.max_hp]
	overview_label.text = "Ebene %d · Raum %d von %d\n%s\n\n%s · %d Gegner\nRäume frei: %d von %d\nLeben: %d / %d LP\n\nBoss: %s\nBossraum: %s\n%s" % [snapshot.get("floor_index",1),snapshot.get("room",1),rooms.size(),str(layout.get("title","")).capitalize(),phase_name,snapshot.get("enemies",[]).size(),cleared,rooms.size(),player.get("hp",0),player.get("max_hp",0),str(snapshot.get("boss_name","Boss")).capitalize(),boss_room.capitalize(),boss_status]
	map_view.set_floor(rooms,str(layout.get("id","")))
	map_note.text = "TÜRKIS  Dein Raum     GOLD  Gesäubert\nGRAU    Weiterer Raum    KRONE  Boss\n\n%s" % layout.get("title","")
	var party_text: String = "Deine Gruppe · %d / %d Wanderer\n\n" % [players.size(),maximum_players]
	var index := 1
	for id: Variant in players:
		var member: Dictionary = players[id]
		var condition := "%d/%d LP" % [member.hp,member.max_hp] if member.hp > 0 else "GEFALLEN"
		var shields: int = int(member.get("shield",member.get("shields",0)))
		var reserve: int = int(member.get("reserve_shield",0))
		if shields+reserve > 0: condition += " · Schutz %d + %d Reserve" % [shields,reserve]
		if member.get("ready",false) and phase == "reward": condition += " · BEREIT"
		party_text += "Spieler %d%s · %s\n%s\n%s\n\n" % [index," · Du" if int(id) == local_id else "",condition,_class_text(str(member.get("class_id","")),member.get("class_perks",[])),_inventory_text(member.get("perks",[]))]
		index += 1
	if party_details.text != party_text:
		party_details.text = party_text
		# ScrollContainer needs a real minimum height, not merely more label text.
		var font: Font = party_details.get_theme_font("font")
		var measured: Vector2 = font.get_multiline_string_size(party_text,HORIZONTAL_ALIGNMENT_LEFT,620,16)
		var explicit_lines: int = party_text.count("\n")+1
		party_details.custom_minimum_size = Vector2(620,maxf(378,measured.y+explicit_lines*4+24))
	main_action_button.visible = phase in ["dead","victory"]
	main_action_button.text = "Neuer Lauf" if host else "Der Host startet den nächsten Lauf"
	main_action_button.disabled = not host
	# Toggle cheats show their state on the button.
	var flags: Dictionary = player.get("cheats", {})
	var order: Array = _cheat_data.get("order", [])
	for slot in range(mini(order.size(), cheat_buttons.size())):
		var id := str(order[slot])
		var label := str(_cheat_data.get("labels", {}).get(id, id.to_upper()))
		if id in Array(_cheat_data.get("toggles", [])): label += " · AN" if bool(flags.get(id, false)) else " · AUS"
		cheat_buttons[slot].text = label
	session_details.text = "%s · Port %d\n%d / %d Wanderer\n\nLauf-Seed: %s\nEbenen-Seed: %s\nGenerator: %s\n\nWenn der Host geht, endet der Lauf für alle.\n\nZum Hauptmenü beendet deine Verbindung." % ["Host" if host else "Client",port,players.size(),maximum_players,snapshot.get("run_seed","—"),snapshot.get("seed","—"),snapshot.get("generator_version","—")]

## Class cards from level-ups, e.g. "Klasse: Schwerer Hieb x2, Doppelwirbel".
func _class_text(class_id: String, owned: Array) -> String:
	if owned.is_empty(): return "Klasse: noch keine Level-Karten"
	var counts: Dictionary = {}
	for value: Variant in owned: counts[str(value)] = int(counts.get(str(value),0))+1
	var names: Array[String] = []
	for id: String in counts:
		var card: Dictionary = ClassPerks.find(class_id,id)
		names.append(str(card.get("name",id)).capitalize()+(" x%d" % int(counts[id]) if int(counts[id]) > 1 else ""))
	return "Klasse: "+", ".join(names)

func _inventory_text(owned: Array) -> String:
	if owned.is_empty(): return "Noch keine Perks"
	var counts: Dictionary = {}
	for value: Variant in owned:
		var id: String = str(value)
		counts[id] = int(counts.get(id,0))+1
	var categories: Dictionary = {}
	for id: String in counts:
		var definition: Dictionary = _definition_by_id.get(id,{})
		var category: String = PerkIcons.category_name(str(definition.get("category","")))
		if not categories.has(category): categories[category] = []
		var name: String = str(definition.get("name",id)).capitalize()
		var cap: int = int(definition.get("max_stacks",0))
		var stacks: String = " ×%d" % int(counts[id]) if int(counts[id]) > 1 else ""
		var limit: String = " / %d" % cap if cap > 1 and int(counts[id]) > 1 else ""
		var entry: String = name+stacks+limit+"\n"+str(definition.get("description",""))
		var tags: String = PerkIcons.tag_text(definition.get("tags",[]))
		if not tags.is_empty(): entry += "\n"+tags
		categories[category].append(entry)
	var names: Array = categories.keys()
	names.sort()
	var sections: Array[String] = []
	for category: String in names:
		sections.append(category+"\n"+"\n\n".join(categories[category]))
	return "\n\n".join(sections)

func _text(parent: Control, value: String, point: Vector2, dimensions: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.text = value
	label.position = point
	label.size = dimensions
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size",16 if font_size < 20 else 24 if font_size < 28 else 32)
	label.add_theme_color_override("font_color",CryptUI.BONE)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

## One Steuerung cell at 16 px; `width` > 0 fixes the column (the tab stop).
func _row_label(value: String, colour: Color, width: float) -> Label:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(width,0)
	# wrapped cells start at the row's top line
	label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	label.add_theme_font_size_override("font_size",16)
	label.add_theme_color_override("font_color",colour)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _button(parent: Control, value: String, point: Vector2, dimensions: Vector2, action: Callable) -> Button:
	var button := Button.new()
	button.text = value
	button.position = point
	button.size = dimensions
	button.add_theme_font_size_override("font_size",16)
	# Frames and colours come from the shared crypt theme (CryptUI).
	button.pressed.connect(action)
	parent.add_child(button)
	return button
