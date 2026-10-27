extends Control
## Offline animation inspection. Preview actions never execute gameplay abilities.
const PixelStyle = preload("res://src/pixel_style.gd")
const Motion = preload("res://src/actor_motion_controller.gd")
const DESIGN := Vector2(1280,720)
var bank: RefCounted
var catalog: Dictionary = {}
var actor_ids: Array[String] = []
var actions: Array = []
var visible_ids: Array[String] = []
var actor_id: String = ""
var clip_id: String = "idle_breathe"
var direction: String = "south"
var elapsed: float = 0.0
var playing: bool = true
var speed: float = 1.0
var zoom: float = 2.0
var _design: Control
var _preview: Control
var _preview_canvas: Control
var _origin := Vector2.ZERO
var _search: LineEdit
var _list: ItemList
var _actor_menu: OptionButton
var _direction_menu: OptionButton
var _description: Label
var _status: Label
var _play: Button
var _timeline: HSlider
var _record: Dictionary = {}

func _ready() -> void:
	theme = PixelStyle.create_theme()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_design = Control.new()
	_design.size = DESIGN
	add_child(_design)
	_preview = Control.new()
	_preview.name = "PreviewBounds"
	_preview.position = Vector2(348,244)
	_preview.size = Vector2(900,304)
	_preview.clip_contents = true
	_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_design.add_child(_preview)
	_preview_canvas = Control.new()
	_preview_canvas.name = "ActorCanvas"
	_preview_canvas.size = _preview.size
	_preview_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preview_canvas.draw.connect(_draw_preview)
	_preview.add_child(_preview_canvas)
	_label("ANIMATIONSWERKSTATT",Vector2(28,22),Vector2(920,48),32)
	_label("32×32 Chibis · 8 Figuren · je48 Abläufe · 4 Blickrichtungen",Vector2(28,74),Vector2(1200,32),16)
	_button("Zum Spiel",Vector2(1076,24),Vector2(176,42),func(): get_tree().change_scene_to_file("res://src/main.tscn"))
	_actor_menu = OptionButton.new()
	_actor_menu.position = Vector2(28,120)
	_actor_menu.size = Vector2(304,40)
	_design.add_child(_actor_menu)
	_actor_menu.item_selected.connect(func(index: int): choose_actor(actor_ids[index]))
	_search = LineEdit.new()
	_search.placeholder_text = "Aktion suchen..."
	_search.position = Vector2(28,172)
	_search.size = Vector2(304,38)
	_design.add_child(_search)
	_search.text_changed.connect(func(_text: String): _refresh_list())
	_list = ItemList.new()
	_list.position = Vector2(28,222)
	_list.size = Vector2(304,454)
	_list.add_theme_font_size_override("font_size",16)
	_design.add_child(_list)
	_list.item_selected.connect(func(index: int): choose_clip(visible_ids[index]))
	_direction_menu = OptionButton.new()
	_direction_menu.position = Vector2(360,120)
	_direction_menu.size = Vector2(192,40)
	for label: String in ["Vorne","Rechts","Hinten","Links"]: _direction_menu.add_item(label)
	_design.add_child(_direction_menu)
	_direction_menu.item_selected.connect(func(index: int): direction = ["south","east","north","west"][index]; _refresh_sample())
	var speed_menu := OptionButton.new()
	speed_menu.position = Vector2(568,120)
	speed_menu.size = Vector2(168,40)
	for label: String in ["0,25× Tempo","0,5× Tempo","1× Tempo","2× Tempo"]: speed_menu.add_item(label)
	speed_menu.select(2)
	speed_menu.item_selected.connect(func(index: int): speed = [0.25,0.5,1.0,2.0][index])
	_design.add_child(speed_menu)
	var zoom_menu := OptionButton.new()
	zoom_menu.position = Vector2(752,120)
	zoom_menu.size = Vector2(168,40)
	for label: String in ["2× Ansicht","4× Ansicht","6× Ansicht"]: zoom_menu.add_item(label)
	zoom_menu.select(0)
	zoom_menu.item_selected.connect(func(index: int): zoom = [2.0,4.0,6.0][index]; _preview_canvas.queue_redraw())
	_design.add_child(zoom_menu)
	_description = _label("",Vector2(360,174),Vector2(876,64),24)
	_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_play = _button("Pause",Vector2(360,568),Vector2(160,40),_toggle_playback)
	_button("Neustart",Vector2(536,568),Vector2(160,40),func(): elapsed = 0.0; _refresh_sample())
	_button("Bild zurück",Vector2(712,568),Vector2(192,40),func(): _step(-1))
	_button("Bild weiter",Vector2(920,568),Vector2(192,40),func(): _step(1))
	_timeline = HSlider.new()
	_timeline.position = Vector2(360,628)
	_timeline.size = Vector2(876,24)
	_timeline.min_value = 0
	_timeline.max_value = 1
	_timeline.step = 0.001
	_timeline.value_changed.connect(func(value: float): if bank != null: elapsed = value*bank.duration(clip_id); playing = false; _play.text = "Abspielen"; _refresh_sample())
	_design.add_child(_timeline)
	_status = _label("Lade Animationspaket...",Vector2(360,664),Vector2(876,40),16)
	if not FileAccess.file_exists("res://src/actor_animation_bank.gd"):
		_status.text = "Das Animationspaket wird noch vorbereitet."
		return
	bank = load("res://src/actor_animation_bank.gd").new()
	if not bank.prepare():
		_status.text = "Animationsdaten fehlen. Bitte das vollständige Paket importieren."
		bank = null
		return
	catalog = bank.catalog()
	actions = catalog.get("actions",[])
	for actor: Dictionary in catalog.get("actors",[]):
		actor_ids.append(str(actor.id))
		_actor_menu.add_item(str(actor.name))
	if not actor_ids.is_empty(): choose_actor(actor_ids[0])
	_resized()
	resized.connect(_resized)

func _resized() -> void:
	_origin = ((get_viewport_rect().size-DESIGN)*0.5).floor()
	_design.position = _origin
	queue_redraw()
	_refresh_sample()

## Select a real actor without changing any player class or encounter.
func choose_actor(value: String) -> void:
	if value not in actor_ids: return
	actor_id = value
	_actor_menu.select(actor_ids.find(value))
	_refresh_list()
	choose_clip(clip_id)

## Select one of the48 independent tracks; directions do not inflate the count.
func choose_clip(value: String) -> void:
	if bank == null or value not in bank.animations(actor_id): return
	clip_id = value
	elapsed = 0.0
	for action: Dictionary in actions:
		if str(action.id) == clip_id:
			var bound: bool = clip_id in Motion.bound_actions()
			_description.text = str(action.name)+"\n"+("An Spielzustände angebunden" if bound else "Vorbereitete Animation · Spielmechanik noch nicht vorhanden")
			break
	if clip_id in visible_ids:
		_list.select(visible_ids.find(clip_id))
		_list.ensure_current_is_visible()
	_refresh_sample()

func _refresh_list() -> void:
	if _list == null: return
	_list.clear()
	visible_ids.clear()
	var query: String = _search.text.to_lower()
	for action: Dictionary in actions:
		if query != "" and query not in (str(action.name)+" "+str(action.id)).to_lower(): continue
		visible_ids.append(str(action.id))
		_list.add_item(str(action.name))

func _step(sign_value: int) -> void:
	if bank == null: return
	_refresh_sample()
	if _record.is_empty(): return
	var frames: int = int(catalog.get("frames_per_clip",6))
	var frame: int = clampi(int(_record.frame)+sign_value,0,frames-1)
	playing = false
	_play.text = "Abspielen"
	elapsed = float(frame)*bank.duration(clip_id)/frames
	_refresh_sample()

func _toggle_playback() -> void:
	if bank == null: return
	var duration: float = bank.duration(clip_id)
	if playing and _looping(): elapsed = fposmod(elapsed,duration)
	elif not playing and not _looping() and elapsed >= duration: elapsed = 0.0
	playing = not playing
	_play.text = "Pause" if playing else "Abspielen"
	_refresh_sample()

func _looping() -> bool:
	for action: Dictionary in actions:
		if str(action.id) == clip_id: return bool(action.get("loop",true))
	return true

func _process(delta: float) -> void:
	if bank == null or actor_id == "": return
	if playing:
		var duration: float = bank.duration(clip_id)
		elapsed = maxf(0,elapsed+delta*speed)
		if _looping(): elapsed = fposmod(elapsed,duration)
		elif elapsed >= duration:
			elapsed = duration
			playing = false
			_play.text = "Abspielen"
	_refresh_sample()

func _refresh_sample() -> void:
	if bank == null or actor_id == "": return
	var loop: bool = _looping()
	_record = bank.sample(actor_id,clip_id,direction,elapsed,loop and playing)
	if _record.is_empty(): return
	var duration: float = bank.duration(clip_id)
	_timeline.set_value_no_signal(fmod(elapsed,duration)/duration if loop and playing else minf(1,elapsed/duration))
	_status.text = "Bild %d / %d · %.2f s · %d Abläufe · Vorschau steuert keine Spielfigur" % [int(_record.frame)+1,int(catalog.get("frames_per_clip",6)),duration,bank.animations(actor_id).size()]
	_preview_canvas.queue_redraw()

func _draw() -> void:
	draw_rect(get_viewport_rect(),Color("101019"))

func _draw_preview() -> void:
	_preview_canvas.draw_rect(Rect2(Vector2.ZERO,_preview.size),Color("1d1926"))
	for x: int in range(8,900,32): _preview_canvas.draw_line(Vector2(x,0),Vector2(x,304),Color("25202f"),1)
	for y: int in range(16,304,32): _preview_canvas.draw_line(Vector2(0,y),Vector2(900,y),Color("25202f"),1)
	_preview_canvas.draw_line(Vector2(32,272),Vector2(868,272),Color("61586b"),2)
	if not _record.is_empty():
		var scale_value: float = float(_record.scale)*zoom
		var image_size: Vector2 = Vector2(float(_record.width),float(_record.height))*scale_value
		var anchor: Vector2 = _record.anchor
		_preview_canvas.draw_texture_rect(_record.texture,Rect2(Vector2(452,272)-anchor*scale_value,image_size),false)

func _label(value: String, point: Vector2, dimensions: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.text = value
	label.position = point
	label.size = dimensions
	label.add_theme_font_size_override("font_size",font_size)
	_design.add_child(label)
	return label

func _button(value: String, point: Vector2, dimensions: Vector2, callback: Callable) -> Button:
	var button := Button.new()
	button.text = value
	button.position = point
	button.size = dimensions
	button.pressed.connect(callback)
	_design.add_child(button)
	return button
