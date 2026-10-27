extends Control
## Read-only session pages and action signals; the game retains all authority.
signal resume_pressed
signal leave_pressed
signal main_action_pressed
signal reward_requested
signal display_mode_requested

const Hud = preload("res://src/dungeon_hud.gd")
const PerkIcons = preload("res://src/perk_icons.gd")
const SECTIONS := ["overview","map","party","reward","controls","display","session"]
const TITLES := ["Übersicht","Karte","Gruppe & Perks","Belohnung","Steuerung","Anzeige","Sitzung"]
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
var _definitions: Array = []
var _definition_by_id: Dictionary = {}

func _ready() -> void:
	size = Vector2(1280,720)
	mouse_filter = Control.MOUSE_FILTER_STOP
	shade = ColorRect.new()
	shade.color = Color(0.025,0.008,0.04,0.83)
	shade.size = size
	add_child(shade)
	var panel := Panel.new()
	panel.position = Vector2(160,64)
	panel.size = Vector2(960,592)
	panel.add_theme_stylebox_override("panel",Hud.panel_style(Color("291538"),Color("9564a5")))
	add_child(panel)
	_text(self,"Pause",Vector2(192,86),Vector2(620,38),32)
	pause_note = _text(self,"",Vector2(432,128),Vector2(656,26),13)
	for index in range(SECTIONS.size()):
		var key: String = SECTIONS[index]
		navigation[key] = _button(self,TITLES[index],Vector2(192,160+index*50),Vector2(208,38),select_section.bind(key))
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
	_text(pages.controls,"Bewegen: WASD\nZielen: Maus\nSchießen: Linksklick\nTür / Treppe nutzen: E\nMenü öffnen / schließen: Esc\nVollbild / Fenster: F11 oder Alt + Enter\n\nNach einem Kampf: Einen Segen auswählen,\ndann weiter erkunden.\n\nFür den Raumwechsel das lebende Team\nam Ausgang sammeln.",Vector2.ZERO,Vector2(640,378),16)
	display_status = _text(pages.display,"",Vector2.ZERO,Vector2(640,64),24)
	display_mode_button = _button(pages.display,"Vollbild einschalten",Vector2(0,96),Vector2(416,44),func(): display_mode_requested.emit())
	_text(pages.display,"F11 oder Alt + Enter wechseln die Ansicht.\nEsc öffnet weiterhin das Pausenmenü.\n\nDie Spielansicht nutzt die gesamte Fläche.\nHerzen und Menü bleiben am Bildschirmrand.",Vector2(0,172),Vector2(640,198),16)
	session_details = _text(pages.session,"",Vector2.ZERO,Vector2(640,378),16)
	resume_button = _button(self,"Weiterspielen",Vector2(192,528),Vector2(208,42),func(): resume_pressed.emit())
	_button(self,"Zum Hauptmenü",Vector2(192,582),Vector2(208,34),func(): leave_pressed.emit())
	main_action_button = _button(self,"",Vector2(432,574),Vector2(656,42),func(): main_action_pressed.emit())
	_text(self,"ESC · Zurück zum Spiel",Vector2(432,626),Vector2(656,22),12)
	select_section("overview")
	visible = false
	set_display_state(false,Vector2(1280,720))


## Covers expanded aspect ratios while the menu keeps its centered design size.
func set_canvas_size(dimensions: Vector2, design_origin: Vector2) -> void:
	if shade == null: return
	shade.position = -design_origin
	shade.size = dimensions


## Reflects the local window mode; changing it never sends a gameplay action.
func set_display_state(fullscreen: bool, _logical_size: Vector2) -> void:
	if display_status == null or display_mode_button == null: return
	display_status.text = "Ansicht: Vollbild" if fullscreen else "Ansicht: Fenster"
	display_mode_button.text = "Zum Fenster wechseln" if fullscreen else "Vollbild einschalten"

## Uses the existing data-driven perk definitions for names and atlas icons.
func configure(definitions: Array) -> void:
	_definitions = definitions
	_definition_by_id.clear()
	for definition: Dictionary in definitions:
		_definition_by_id[str(definition.get("id",""))] = definition

## Selects one information page, keeping every other page out of the playfield.
func select_section(key: String) -> void:
	if key not in SECTIONS: return
	if key == "reward":
		reward_requested.emit()
		return
	section = key
	for id: String in pages:
		pages[id].visible = id == key
		navigation[id].add_theme_color_override("font_color",Color("ffcf68") if id == key else Color("cbb3dc"))

## Displays authoritative snapshots. Buttons only request ordinary game actions.
func set_state(snapshot: Dictionary, local_id: int, host: bool, port: int, solo_paused: bool) -> void:
	pause_note.text = "SOLO · SPIEL ANGEHALTEN" if solo_paused else "MEHRSPIELER · DIE WELT LÄUFT WEITER"
	var rooms: Array = snapshot.get("floor_map",[])
	var layout: Dictionary = snapshot.get("room_layout",{})
	var players: Dictionary = snapshot.get("players",{})
	var player: Dictionary = players.get(local_id,{})
	var maximum_players := int(snapshot.get("max_players",4))
	var cleared := rooms.filter(func(room: Dictionary): return room.get("cleared",false)).size()
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
		party_text += "Spieler %d%s · %s\n%s\n\n" % [index," · Du" if int(id) == local_id else "",condition,_inventory_text(member.get("perks",[]))]
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
	session_details.text = "%s · Port %d\n%d / %d Wanderer\n\nLauf-Seed: %s\nEbenen-Seed: %s\nGenerator: %s\n\nWenn der Host geht, endet der Lauf für alle.\n\nZum Hauptmenü beendet deine Verbindung." % ["Host" if host else "Client",port,players.size(),maximum_players,snapshot.get("run_seed","—"),snapshot.get("seed","—"),snapshot.get("generator_version","—")]

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
	label.add_theme_color_override("font_color",Color("cbb3dc"))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _button(parent: Control, value: String, point: Vector2, dimensions: Vector2, action: Callable) -> Button:
	var button := Button.new()
	button.text = value
	button.position = point
	button.size = dimensions
	button.add_theme_font_size_override("font_size",16)
	button.add_theme_stylebox_override("normal",Hud.panel_style(Color("35203f"),Color("674374")))
	button.add_theme_stylebox_override("hover",Hud.panel_style(Color("553163"),Color("ffcf68")))
	button.add_theme_stylebox_override("pressed",Hud.panel_style(Color("472340"),Color("edbc81")))
	button.pressed.connect(action)
	parent.add_child(button)
	return button
