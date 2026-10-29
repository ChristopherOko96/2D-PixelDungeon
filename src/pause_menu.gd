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

const CryptUI = preload("res://src/ui/crypt_ui.gd")
const PerkIcons = preload("res://src/perk_icons.gd")
const ClassPerks = preload("res://src/player/class_perks.gd")
const QuestView = preload("res://src/ui/quest_view.gd")
## A save slot button (1..3): the host saves the start of the current floor.
signal save_requested(slot: int)

const SECTIONS := ["overview","quest","map","party","reward","controls","display","session","save","cheats"]
const TITLES := ["Übersicht","Auftrag","Karte","Gruppe & Perks","Belohnung","Steuerung","Anzeige","Sitzung","Speichern","Cheats"]
## Pages each mode shows: the crypt run, and the story worlds (Hölle, Frostgruft).
const MODE_SECTIONS := {
	"crypt": ["overview","quest","map","party","reward","controls","display","session","save","cheats"],
	"story": ["overview","quest","map","controls","display","save"],
}
## Returns the save slot lines (SaveStore.summaries); set by the game.
var save_rows := Callable()
var save_buttons: Array[Button] = []
var save_note: Label
var save_hint: Label
var _save_enabled := false
## "crypt" or "story" (use_story_mode).
var mode := "crypt"
var controls_label: Label
## The Auftragsliste page (src/ui/quest_view.gd), the same in every story.
var quest_view: QuestView
## Story map: a page-sized canvas the world draws its big map on (story_map_draw(canvas)).
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
var main_action_button: Button
var shade: ColorRect
var display_mode_button: Button
var display_status: Label
var graphics_status: Label
var graphics_button: Button
var _definitions: Array = []
var cheat_buttons: Array[Button] = []
var _cheat_data: Dictionary = {}
var _cheats_enabled := false
var _definition_by_id: Dictionary = {}

func _ready() -> void:
	size = Vector2(1280,720)
	mouse_filter = Control.MOUSE_FILTER_STOP
	shade = ColorRect.new()
	shade.color = Color(CryptUI.INK,0.82)
	shade.size = size
	add_child(shade)
	var panel := Panel.new()
	panel.position = Vector2(160,64)
	panel.size = Vector2(960,592)
	add_child(panel)
	# The page area sits in its own inset, apart from the section list.
	var inset := Panel.new()
	inset.position = Vector2(420,164)
	inset.size = Vector2(680,398)
	inset.add_theme_stylebox_override("panel",CryptUI.box("inset"))
	inset.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(inset)
	var heading := CryptUI.heading("PAUSE",32)
	heading.position = Vector2(192,84)
	add_child(heading)
	pause_note = _text(self,"",Vector2(432,128),Vector2(656,26),13)
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
	controls_label = _text(pages.controls,"Bewegen: WASD\nZielen: Maus\nAngreifen: Linksklick\nFähigkeiten: 1 2 3 4 (2 ab Level 3, 3 ab 6, 4 ab 10)\nBallistapfeil, Photoneneis: Taste halten\nTür / Treppe nutzen: E\nMenü öffnen / schließen: Esc\nVollbild / Fenster: F11 oder Alt + Enter\n\nGegner lassen grüne EXP fallen; das Team\nlevelt gemeinsam. Karten rechts per Klick.\n\nFür den Raumwechsel das lebende Team\nam Ausgang sammeln.",Vector2.ZERO,Vector2(640,378),16)
	display_status = _text(pages.display,"",Vector2.ZERO,Vector2(640,64),24)
	display_mode_button = _button(pages.display,"Vollbild einschalten",Vector2(0,96),Vector2(416,44),func(): display_mode_requested.emit())
	graphics_status = _text(pages.display,"Grafik: PIXEL",Vector2(0,164),Vector2(640,40),16)
	graphics_button = _button(pages.display,"Zu HD wechseln",Vector2(0,196),Vector2(416,44),func(): graphics_mode_requested.emit())
	_text(pages.display,"F11 oder Alt + Enter wechseln die Ansicht.\nEsc öffnet weiterhin das Pausenmenü.\n\nDie Spielansicht nutzt die gesamte Fläche.\nHerzen und Menü bleiben am Bildschirmrand.",Vector2(0,264),Vector2(640,128),16)
	session_details = _text(pages.session,"",Vector2.ZERO,Vector2(640,378),16)
	save_hint = _text(pages.save,"Ein Klick speichert den Beginn dieser Ebene.\nLaden und Löschen: Hauptmenü, SPIELSTÄNDE.",Vector2.ZERO,Vector2(640,52),16)
	for slot in range(1,4):
		var button := _button(pages.save,"PLATZ %d" % slot,Vector2(0,64+(slot-1)*54),Vector2(640,44),func(): save_requested.emit(slot))
		button.clip_text = true
		save_buttons.append(button)
	save_note = _text(pages.save,"",Vector2(0,232),Vector2(640,60),16)
	save_note.add_theme_color_override("font_color",CryptUI.GOLD)
	resume_button = _button(self,"Weiterspielen",Vector2(192,528),Vector2(208,42),func(): resume_pressed.emit())
	_button(self,"Zum Hauptmenü",Vector2(192,582),Vector2(208,34),func(): leave_pressed.emit())
	main_action_button = _button(self,"",Vector2(432,574),Vector2(656,42),func(): main_action_pressed.emit())
	_text(self,"ESC · Zurück zum Spiel",Vector2(432,626),Vector2(656,22),12)
	_layout_navigation()
	select_section("overview")
	visible = false
	set_display_state(false,Vector2(1280,720))


## Story worlds (Hölle, Frostgruft): their own controls text, a quest page, their big
## map on the map page; no party, reward, session or cheat pages. Call once after adding.
func use_story_mode(controls_text: String) -> void:
	mode = "story"
	controls_label.text = controls_text
	map_view.visible = false
	map_note.visible = false
	story_map.visible = true
	main_action_button.visible = false
	pause_note.text = "SPIEL ANGEHALTEN"
	save_hint.text = "Ein Klick speichert den Beginn dieser Etage.\nLaden und Löschen: Hauptmenü, SPIELSTÄNDE."
	_layout_navigation()
	select_section("overview")


## Story worlds feed their pages: {overview: text, quest_title: "ETAGE 3",
## quests: [{text, done, main}]}.
func set_story_state(info: Dictionary) -> void:
	overview_label.text = str(info.get("overview", ""))
	quest_view.set_goals(info.get("quests", []), str(info.get("quest_title", "")))
	story_map.queue_redraw()


## Stacks the section buttons of the current mode without gaps.
func _layout_navigation() -> void:
	var shown: Array = MODE_SECTIONS[mode]
	var row := 0
	for key: String in SECTIONS:
		var visible_here: bool = key in shown and (key != "cheats" or _cheats_enabled)
		navigation[key].visible = visible_here
		if visible_here:
			navigation[key].position = Vector2(192,160+row*36)
			row += 1


## Covers expanded aspect ratios while the menu keeps its centered design size.
func set_canvas_size(dimensions: Vector2, design_origin: Vector2) -> void:
	if shade == null: return
	shade.position = -design_origin
	shade.size = dimensions


## Reflects the local window mode; changing it never sends a gameplay action.
## The graphics line and button: `note` says what the mode means in this world.
func set_graphics_state(note: String, mode: String) -> void:
	if graphics_status == null or graphics_button == null: return
	graphics_status.text = note
	graphics_button.text = "Zu Pixel wechseln" if mode == "hd" else "Zu HD wechseln"


func set_display_state(fullscreen: bool, _logical_size: Vector2) -> void:
	if display_status == null or display_mode_button == null: return
	display_status.text = "Ansicht: Vollbild" if fullscreen else "Ansicht: Fenster"
	display_mode_button.text = "Zum Fenster wechseln" if fullscreen else "Vollbild einschalten"

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
func select_section(key: String) -> void:
	if key not in SECTIONS or key not in MODE_SECTIONS[mode]: return
	if key == "cheats" and not _cheats_enabled: return
	if key == "reward":
		reward_requested.emit()
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
