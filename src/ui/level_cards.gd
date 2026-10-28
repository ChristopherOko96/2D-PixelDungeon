extends Control
## The open card choice of the local hero, shown at the right edge while the
## fight goes on: three cards after a team level-up (class upgrades and
## passives) or after a boss (general perks). Picked by mouse click; the game
## sends the pick to the host. Display only: cards come from host snapshots.

signal picked(index: int)

const CryptUI = preload("res://src/ui/crypt_ui.gd")
const SkillIcons = preload("res://src/ui/skill_icons.gd")
const CARD_SIZE := Vector2(360, 104)
const GAP := 8.0

var _heading: Label
var _note: Label
var _cards: Array[Button] = []
var _key := ""
var _shown_at := 0.0
var _clock := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(CARD_SIZE.x, 48 + (CARD_SIZE.y + GAP) * 3)
	_heading = CryptUI.heading("", 24)
	_heading.position = Vector2(0, 0)
	_heading.size = Vector2(CARD_SIZE.x, 28)
	add_child(_heading)
	_note = Label.new()
	_note.position = Vector2(0, 26)
	_note.size = Vector2(CARD_SIZE.x, 20)
	_note.add_theme_font_size_override("font_size", 16)
	_note.add_theme_color_override("font_color", CryptUI.SAND)
	_note.add_theme_color_override("font_outline_color", CryptUI.INK)
	_note.add_theme_constant_override("outline_size", 4)
	_note.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_note)
	for index in range(3):
		var card := Button.new()
		card.name = "Card%d" % index
		card.size = CARD_SIZE
		card.position = Vector2(0, 48 + index * (CARD_SIZE.y + GAP))
		card.focus_mode = Control.FOCUS_NONE
		card.pressed.connect(func(): picked.emit(index))
		add_child(card)
		var icon := TextureRect.new()
		icon.name = "Icon"
		icon.position = Vector2(10, 20)
		icon.size = Vector2(64, 64)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(icon)
		card.add_child(_label("Title", Vector2(84, 8), Vector2(266, 20), 16, CryptUI.GOLD))
		card.add_child(_label("Kind", Vector2(84, 28), Vector2(266, 20), 16, CryptUI.SAND))
		var text := _label("Text", Vector2(84, 50), Vector2(266, 48), 16, CryptUI.BONE)
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.max_lines_visible = 2
		card.add_child(text)
		_cards.append(card)
	visible = false


func _label(node_name: String, at: Vector2, dimensions: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.name = node_name
	label.position = at
	label.size = dimensions
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.clip_text = true
	return label


## Shows the local hero's open choice from a snapshot (hidden when none).
func set_state(snapshot: Dictionary, local_peer: int) -> void:
	var player: Dictionary = snapshot.get("players", {}).get(local_peer, {})
	var offer: Array = player.get("offer", [])
	visible = not offer.is_empty() and int(player.get("hp", 0)) > 0
	if not visible:
		_key = ""
		return
	var key := JSON.stringify(offer) + str(player.get("offer_pending", 0))
	if key == _key: return
	if _key.is_empty(): _shown_at = _clock
	_key = key
	var boss := str(player.get("offer_kind", "")) == "boss"
	var level := int(snapshot.get("team", {}).get("level", 1))
	_heading.text = "BOSS-BEUTE" if boss else "LEVEL %d" % level
	var pending := int(player.get("offer_pending", 1))
	_note.text = "Karte anklicken" + (" · %d offen" % pending if pending > 1 else "")
	var class_id := str(player.get("class_id", ""))
	for index in range(_cards.size()):
		var card := _cards[index]
		card.visible = index < offer.size()
		if not card.visible: continue
		var data: Dictionary = offer[index]
		card.get_node("Icon").texture = SkillIcons.card(data, class_id)
		card.get_node("Title").text = str(data.get("name", "")).to_upper()
		card.get_node("Text").text = str(data.get("description", ""))
		var maximum := int(data.get("max", data.get("max_stacks", 1)))
		var owned := int(data.get("rank", 0))
		var kind := str(data.get("kind", ""))
		var label := str(data.get("skill_name", "")) if kind == "upgrade" else "PASSIV" if kind == "passive" else str(data.get("category", "PERK")).to_upper() if kind == "perk" else "ERSATZ"
		if maximum > 1: label += " · %d/%d" % [owned + 1, maximum]
		card.get_node("Kind").text = label


func _process(delta: float) -> void:
	_clock += delta
	if not visible: return
	# Slide in from the right once per new choice.
	var t := clampf((_clock - _shown_at) / 0.25, 0.0, 1.0)
	for index in range(_cards.size()):
		_cards[index].position.x = (1.0 - ease(t, 0.4)) * (CARD_SIZE.x + 40.0)
	var glow := 0.5 + 0.5 * sin(_clock * 4.0)
	_heading.modulate = Color(1, 1, 1, 0.8 + 0.2 * glow)
