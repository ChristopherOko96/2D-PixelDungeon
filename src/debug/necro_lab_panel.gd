extends Control
## Compact lab controls. Emits requests to the offline host; never changes combat.
const FONT := preload("res://assets/fonts/pixel_operator8.ttf")
var lab: Node
var box: VBoxContainer
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	box = VBoxContainer.new()
	box.position = Vector2(420,12)
	box.add_theme_constant_override("separation",5)
	add_child(box)
	rebuild()

func _button(row: HBoxContainer, text: String, action: String, arg: Variant = null) -> void:
	var button := Button.new()
	button.text = text
	button.add_theme_font_override("font",FONT)
	button.add_theme_font_size_override("font_size",16)
	button.custom_minimum_size.y = 30
	button.pressed.connect(func(): lab.lab_action(action,arg))
	row.add_child(button)

func _check(row: HBoxContainer, label: String, action: String, on: bool) -> void:
	var button := CheckBox.new()
	button.text = label
	button.button_pressed = on
	button.add_theme_font_override("font",FONT)
	button.add_theme_font_size_override("font_size",16)
	button.toggled.connect(func(value:bool): lab.lab_action(action,value))
	row.add_child(button)

## Rebuild only after a choice, keeping the actual ability names in the selector.
func rebuild() -> void:
	if box==null: return
	for child: Node in box.get_children():
		box.remove_child(child)
		child.queue_free()
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation",6)
	box.add_child(header)
	var title := Label.new()
	title.text = str(lab.lab_cfg.short_title)
	title.add_theme_font_override("font",FONT)
	title.add_theme_font_size_override("font_size",16)
	header.add_child(title)
	for spec: String in lab.lab_cfg.specs:
		_button(header,str(lab.lab_cfg.specs[spec].name),"spec",spec)
	var kits := OptionButton.new()
	kits.add_theme_font_override("font",FONT)
	kits.add_theme_font_size_override("font_size",16)
	for kit: Dictionary in lab.lab_cfg.specs[lab.lab_spec].kits: kits.add_item(str(kit.name))
	kits.select(int(lab.lab_kit))
	kits.item_selected.connect(func(index:int):lab.lab_action("kit",index))
	header.add_child(kits)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation",5)
	box.add_child(actions)
	for action: String in lab.lab_cfg.get("actions",["group","dummy","clear","souls","blood","reset"]): _button(actions,str(lab.lab_cfg.labels[action]),action)
	var toggles := HBoxContainer.new()
	toggles.add_theme_constant_override("separation",6)
	box.add_child(toggles)
	_check(toggles,str(lab.lab_cfg.labels.auto),"auto",bool(lab.lab_auto))
	_check(toggles,str(lab.lab_cfg.labels.god),"god",bool(lab.lab_god))
	_check(toggles,str(lab.lab_cfg.labels.rings),"rings",bool(lab.lab_rings))
	var choices := OptionButton.new()
	choices.add_theme_font_override("font",FONT)
	choices.add_theme_font_size_override("font_size",16)
	var rt: Dictionary = lab.talent_combat.runtime(1)
	var ids: Array = Array(rt.get("bar",[])).duplicate()
	if not str(rt.get("ultimate","")).is_empty(): ids.append(str(rt.ultimate))
	for index in range(ids.size()):
		var id := str(ids[index])
		var key := "R" if id==str(rt.get("ultimate","")) else str(index+1)
		choices.add_item(key+" · "+str(lab.talent_combat.data.talents[id].name))
		if id==lab.lab_preview: choices.select(index)
	choices.item_selected.connect(func(index:int): lab.lab_action("preview",str(ids[index])))
	toggles.add_child(choices)

func _process(_delta: float) -> void:
	visible = not lab.pause_open and not lab.inventory_panel.open
