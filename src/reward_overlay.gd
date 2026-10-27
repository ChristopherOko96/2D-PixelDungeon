extends Control
## Floating reward cards. Choice and readiness are requests, never local grants.
signal perk_selected(index: int)
signal ready_requested
signal close_requested
signal menu_requested

const PixelStyle = preload("res://src/pixel_style.gd")
const PerkIcons = preload("res://src/perk_icons.gd")
const KINDS := {"damage":"Kraft","speed":"Bewegung","max_hp":"Vitalität","shot_interval":"Tempo","heal":"Heilung"}
var cards: Array[Button] = []
var shade: ColorRect
var ready_button: Button
var close_button: Button
var heading: Label
var subtitle: Label
var pause_note: Label
var selected_index := -1
var _pending_index := -1
var _pending_at := 0
var _offer_key := ""
var _picked_before := false
var _snapshot: Dictionary = {}
var _local_id := 0
var _entrance_time := 0.0
var _entrance_active := false
var _entrance_duration := 0.4
var _entrance_stagger := 0.08


## Covers the whole display while cards remain centered at their design size.
func set_canvas_size(dimensions: Vector2, design_origin: Vector2) -> void:
	if shade == null: return
	shade.position = -design_origin
	shade.size = dimensions

## Presentation timings come from balance, independently from host reward grants.
func configure(settings: Dictionary) -> void:
	_entrance_duration = maxf(0.1,float(settings.get("card_duration",0.4)))
	_entrance_stagger = maxf(0,float(settings.get("card_stagger",0.08)))

## Cards slide in once when a new authoritative offer arrives.
func play_entrance() -> void:
	_entrance_time = 0
	_entrance_active = true
	for index in range(cards.size()):
		cards[index].position = Vector2(152+index*336,760)
		cards[index].pivot_offset = Vector2(152,200)
		cards[index].rotation = -0.05
		cards[index].modulate.a = 0

func _process(delta: float) -> void:
	if not _entrance_active or not visible: return
	_entrance_time += delta
	for index in range(cards.size()):
		var progress := clampf((_entrance_time-index*_entrance_stagger)/_entrance_duration,0,1)
		var ease_out := 1.0-pow(1.0-progress,3)
		cards[index].position = Vector2(152+index*336,lerpf(760,176,ease_out)).round()
		cards[index].rotation = lerpf(-0.05,0,ease_out)
		cards[index].modulate.a = progress
	if _entrance_time >= _entrance_duration+cards.size()*_entrance_stagger:
		_entrance_active = false

func _ready() -> void:
	size = Vector2(1280,720)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = PixelStyle.create_theme()
	shade = ColorRect.new()
	shade.color = Color(0.025,0.01,0.055,0.32)
	shade.size = size
	add_child(shade)
	heading = _label(self,"Deine Belohnung",Vector2(240,60),Vector2(800,48),32,Color("ffe2ac"))
	subtitle = _label(self,"Wähle einen Segen für deinen Lauf.",Vector2(240,112),Vector2(800,32),16)
	pause_note = _label(self,"",Vector2(240,148),Vector2(800,28),16,Color("c6b4d7"))
	for index in range(3):
		var card := Button.new()
		card.name = "Card%d" % index
		card.position = Vector2(152+index*336,176)
		card.size = Vector2(304,400)
		card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		card.add_theme_stylebox_override("normal",_card_style(Color("c5a6d2"),0.53))
		card.add_theme_stylebox_override("hover",_card_style(Color("ffe2ac"),0.70))
		card.add_theme_stylebox_override("pressed",_card_style(Color("ffe2ac"),0.78))
		card.add_theme_stylebox_override("focus",_card_style(Color("ffe2ac"),0.0))
		card.pressed.connect(_choose.bind(index))
		add_child(card)
		cards.append(card)
		_label(card,"",Vector2(16,14),Vector2(272,24),16).name = "Kind"
		_label(card,"",Vector2(16,40),Vector2(272,36),16,Color("c6b4d7")).name = "Meta"
		var icon := TextureRect.new()
		icon.name = "Icon"
		icon.position = Vector2(104,72)
		icon.size = Vector2(96,96)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(icon)
		_label(card,"",Vector2(16,176),Vector2(272,40),24,Color("fff2d8")).name = "Title"
		_label(card,"",Vector2(16,216),Vector2(272,112),16).name = "Effect"
		var tags: Label = _label(card,"",Vector2(16,332),Vector2(272,36),16,Color("c6b4d7"))
		tags.name = "Tags"
		tags.max_lines_visible = 2
		tags.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		_label(card,"",Vector2(16,372),Vector2(272,24),16,Color("f4d383")).name = "Choice"
	for index in range(cards.size()):
		cards[index].focus_neighbor_left = cards[posmod(index-1,cards.size())].get_path()
		cards[index].focus_neighbor_right = cards[(index+1)%cards.size()].get_path()
	ready_button = _button("Weiter erkunden",Vector2(432,584),Vector2(416,44),_ready_action)
	close_button = _button("Zurück zum Spiel",Vector2(448,640),Vector2(384,36),func(): close_requested.emit())
	_button("Pause",Vector2(48,64),Vector2(128,36),func(): menu_requested.emit())
	_label(self,"Links / Rechts wählen · Enter bestätigen · Esc schließen",Vector2(160,688),Vector2(960,24),16,Color("c6b4d7"))
	visible = false

## Displays host-confirmed choices and readiness, including after reopening.
func set_state(snapshot: Dictionary, local_id: int, solo_paused: bool) -> void:
	_snapshot = snapshot
	_local_id = local_id
	var player: Dictionary = snapshot.get("players",{}).get(local_id,{})
	var options: Array = snapshot.get("perk_options",[])
	# Keep offered names on one readable native pixel grid, including compounds.
	# The same size across the offer avoids splitting e.g. Schattenschritt midword.
	var title_size := PixelStyle.HEADING_SIZE
	var font := PixelStyle.create_font()
	for option: Dictionary in options:
		for word: String in str(option.get("name","")).capitalize().split(" "):
			if font.get_string_size(word,HORIZONTAL_ALIGNMENT_LEFT,-1,title_size).x > 272:
				title_size = PixelStyle.BODY_SIZE
	var rewarding: bool = snapshot.get("phase","") == "reward"
	var key := str(snapshot.get("floor_index",1))+":"+str(snapshot.get("room_layout",{}).get("id",""))+":"+JSON.stringify(options)+":"+str(rewarding)
	if key != _offer_key:
		_offer_key = key
		_pending_index = -1
		_picked_before = false
	if _pending_index >= 0 and Time.get_ticks_msec()-_pending_at > 1500: _pending_index = -1
	var picked: bool = rewarding and player.get("picked",false)
	var alive: bool = player.get("hp",0) > 0
	selected_index = -1
	if picked:
		_pending_index = -1
		var owned: Array = player.get("perks",[])
		var last_perk: String = str(player.get("last_perk",owned.back() if not owned.is_empty() else ""))
		if last_perk.is_empty() and not owned.is_empty(): last_perk = str(owned.back())
		for index in range(options.size()):
			if options[index].id == last_perk: selected_index = index
	for index in range(cards.size()):
		var card: Button = cards[index]
		card.visible = rewarding and index < options.size()
		card.disabled = not rewarding or not alive or picked or _pending_index >= 0
		if index >= options.size(): continue
		var option: Dictionary = options[index]
		var tint: Color = PerkIcons.tint(str(option.id))
		var stacks: int = player.get("perks",[]).count(option.id)
		var cap: int = int(option.get("max_stacks",0))
		var rarity: String = PerkIcons.rarity_name(str(option.get("rarity","common")))
		var stack_text: String = "%d / %d" % [stacks,cap] if cap > 0 else "Verbrauchbar" if option.get("stat","") == "heal" else "Wiederholbar"
		if option.get("stat","") == "reserve": stack_text = "Reserve %d" % int(player.get("reserve_shield",0))
		var chosen := index == selected_index
		card.add_theme_stylebox_override("normal",_card_style(tint,0.73 if chosen else 0.53))
		card.add_theme_stylebox_override("disabled",_card_style(tint if chosen else tint.darkened(0.4),0.73 if chosen else 0.42))
		card.get_node("Kind").text = PerkIcons.category_name(str(option.get("category",""))) if option.has("category") else KINDS.get(option.get("stat",""),"Segen")
		card.get_node("Kind").modulate = tint
		card.get_node("Meta").text = rarity+" · "+stack_text
		card.get_node("Tags").text = PerkIcons.tag_text(option.get("tags",[]),2)
		card.tooltip_text = str(option.name).capitalize()+"\n"+rarity+" · "+stack_text+"\n\n"+str(option.description)+"\n\n"+PerkIcons.tag_text(option.get("tags",[]))
		var title: Label = card.get_node("Title")
		title.text = str(option.name).capitalize()
		title.autowrap_mode = TextServer.AUTOWRAP_WORD
		title.add_theme_font_size_override("font_size",title_size)
		card.get_node("Effect").text = option.description
		card.get_node("Icon").texture = PerkIcons.texture(str(option.id),option)
		card.get_node("Icon").modulate = Color.WHITE if not picked or chosen else Color(0.6,0.6,0.6,0.65)
		card.get_node("Choice").text = "Gewählt" if chosen else "Wird gewählt..." if _pending_index == index else ""
	heading.text = "Deine Belohnung" if rewarding else "Die nächste Belohnung wartet"
	subtitle.text = "Wähle einen Segen für deinen Lauf." if rewarding and not picked else "Dein Segen ist gewählt." if rewarding else "Säubere den Raum, um einen Segen zu erhalten."
	if rewarding and not alive: subtitle.text = "Du bist gefallen. Deine Gruppe wählt ihre Belohnung."
	pause_note.text = "Solo · Spiel angehalten" if solo_paused else "Mehrspieler · Die Welt läuft weiter"
	ready_button.visible = rewarding
	ready_button.disabled = not picked or not alive or player.get("ready",false)
	ready_button.text = "Auf die Gruppe warten..." if player.get("ready",false) else "Weiter erkunden"
	if picked and not _picked_before and is_visible_in_tree() and not ready_button.disabled:
		ready_button.grab_focus()
	_picked_before = picked

## Focuses cards once on open; network refreshes never steal navigation focus.
func focus_initial() -> void:
	for card: Button in cards:
		if card.visible and not card.disabled:
			card.grab_focus()
			return
	if ready_button.visible and not ready_button.disabled: ready_button.grab_focus()
	else: close_button.grab_focus()

func _choose(index: int) -> void:
	if index < 0 or index >= cards.size() or cards[index].disabled: return
	_pending_index = index
	_pending_at = Time.get_ticks_msec()
	for card: Button in cards: card.disabled = true
	perk_selected.emit(index)

func _ready_action() -> void:
	if not ready_button.disabled: ready_requested.emit()

func _icon(id: String) -> Texture2D:
	return PerkIcons.texture(id)

func _card_style(tint: Color, opacity: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10,0.045,0.15,opacity)
	style.border_color = Color(tint,0.82)
	style.set_border_width_all(2)
	style.shadow_color = Color(0.025,0.005,0.04,0.35 if opacity > 0 else 0)
	style.shadow_size = 0
	style.shadow_offset = Vector2(0,6)
	return style

func _label(parent: Control, value: String, point: Vector2, dimensions: Vector2, font_size: int, color: Color = Color("eadcf0")) -> Label:
	var label := Label.new()
	label.text = value
	label.position = point
	label.size = dimensions
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size",font_size)
	label.add_theme_color_override("font_color",color)
	label.add_theme_color_override("font_outline_color",Color("180b22"))
	label.add_theme_constant_override("outline_size",2)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _button(value: String, point: Vector2, dimensions: Vector2, action: Callable) -> Button:
	var button := Button.new()
	button.text = value
	button.position = point
	button.size = dimensions
	button.add_theme_font_size_override("font_size",24 if dimensions.y > 40 else 16)
	button.add_theme_color_override("font_color",Color("ffe2ac"))
	button.add_theme_stylebox_override("normal",_card_style(Color("ad88b9"),0.65))
	button.add_theme_stylebox_override("hover",_card_style(Color("ffe2ac"),0.8))
	button.add_theme_stylebox_override("pressed",_card_style(Color("ffe2ac"),0.9))
	button.pressed.connect(action)
	add_child(button)
	return button
