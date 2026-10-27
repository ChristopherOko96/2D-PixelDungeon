extends SceneTree
## UI fixtures cover long offers, distinct glyphs and large stacked inventories.
const RewardOverlay = preload("res://src/reward_overlay.gd")
const PauseMenu = preload("res://src/pause_menu.gd")
const IDS: Array[String] = ["ember","shadow","heart","quick","mend","piercer","ricochet","scatter","heavy","twin","backshot","sidewinder","homing","orbit","crit","focus","momentum","execution","mark","longshot","cinder","venom","frost","storm","shatter","plague","combustion","conductor","permafrost","catalyst","shield","thorns","vampire","second_wind","soul_guard","renewal","adrenaline","berserk","stone_skin","close_quarters","echo","split","blast","leech","overkill","convergence","first_strike","desperation"]
var checked: int = 0
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	checked += 1
	if not condition:
		failures.append(message)
		printerr("PERK_UI_FAIL: ",message)

func _definition(id: String) -> Dictionary:
	return {"id":id,"name":"SCHATTEN FUNKEN","description":"Treffer entzünden Gegner. Brennende Ziele erleiden zusätzlichen Schaden durch deine nächsten Treffer.","stat":"build","amount":1,"category":"elements","rarity":"rare","tags":["fire","projectile"],"max_stacks":3}

func _run() -> void:
	# Arrange: every public ID, independently of mutable balance data.
	var icons: Script
	if FileAccess.file_exists("res://src/perk_icons.gd"):
		icons = load("res://src/perk_icons.gd")
	_check(icons != null,"the expanded catalogue has a shared icon provider")
	if icons != null:
		var hashes: Dictionary = {}
		for id: String in IDS:
			var texture: Texture2D = icons.texture(id,_definition(id))
			_check(texture != null,"icon exists for "+id)
			if texture == null: continue
			var image: Image = texture.get_image()
			_check(image != null and image.get_width() > 0,"icon has real pixels for "+id)
			if image != null: hashes[hash(image.get_data())] = true
			_check(texture == icons.texture(id,_definition(id)),"icon cache is stable for "+id)
		_check(hashes.size() == IDS.size(),"all48 perk icons have different pixels")
	# Arrange: a long description, existing stacks and a delayed host response.
	var overlay: Control = RewardOverlay.new()
	root.add_child(overlay)
	overlay.visible = true
	var offer: Array = [_definition("cinder"),_definition("frost"),_definition("storm")]
	var fixture: Dictionary = {"phase":"reward","floor_index":1,"room_layout":{"id":"perk-ui-fixture"},"players":{1:{"hp":8,"max_hp":8,"picked":false,"ready":false,"perks":["cinder","cinder"]}},"perk_options":offer}
	overlay.set_state(fixture,1,true)
	await process_frame
	await process_frame
	var first: Button = overlay.cards[0]
	_check(first.tooltip_text.contains("Selten") and first.tooltip_text.contains("2 / 3"),"tooltip explains rarity and current stacks")
	var meta: Label = first.get_node_or_null("Meta")
	_check(meta != null and meta.text.contains("Selten"),"rarity is visible without hovering")
	var tags: Label = first.get_node_or_null("Tags")
	_check(tags != null and tags.text.contains("Feuer"),"synergy tags are translated and visible")
	var effect: Label = first.get_node("Effect")
	_check(effect.get_minimum_size().y <= effect.size.y and effect.position.y+effect.size.y < first.size.y,"a realistic long effect fits inside the card")
	_check(first.get_node("Icon").size.x >= 80,"the centered sprite remains large")
	overlay.focus_initial()
	_check(root.gui_get_focus_owner() == first,"first eligible card retains keyboard focus")
	first.pressed.emit()
	overlay.set_state(fixture,1,true)
	_check(overlay.cards.all(func(card: Button): return card.disabled),"unacknowledged input cannot grant another selection")
	fixture.players[1].picked = true
	fixture.players[1].perks.append("cinder")
	overlay.set_state(fixture,1,true)
	_check(overlay.selected_index == 0 and not overlay.ready_button.disabled,"host-confirmed choice unlocks readiness")
	# Consumable fallback is acknowledged separately from persistent ownership.
	fixture.perk_options = [{"id":"respite","name":"SEELENRAST","description":"Ein Schutztreffer bis zum nächsten Raum.","stat":"reserve","amount":1,"max_stacks":0,"rarity":"common","category":"Rast","tags":["guard"]}]
	fixture.players[1].last_perk = "respite"
	fixture.players[1].reserve_shield = 2
	overlay.set_state(fixture,1,true)
	_check(overlay.selected_index == 0,"consumable fallback uses the host last_perk acknowledgement")
	_check(overlay.cards[0].get_node("Meta").text.contains("Reserve 2"),"fallback shows the actual temporary reserve")
	# Arrange:48 separate definitions plus three copies of one ID.
	var menu: Control = PauseMenu.new()
	root.add_child(menu)
	var definitions: Array = []
	for id: String in IDS: definitions.append(_definition(id))
	menu.configure(definitions)
	fixture.players[1].perks = IDS.duplicate()
	fixture.players[1].perks.append("cinder")
	fixture.players[1].perks.append("cinder")
	fixture["floor_map"] = []
	fixture["enemies"] = []
	menu.set_state(fixture,1,true,7777,true)
	menu.select_section("party")
	menu.visible = true
	await process_frame
	await process_frame
	_check(menu.party_details.text.contains("×3"),"inventory combines duplicate IDs into a stack count")
	_check(menu.party_details.custom_minimum_size.y > 378,"large inventory creates actual scrollable height")
	_check(menu.party_details.text.contains("Elemente"),"inventory groups perks by translated category")
	menu.queue_free()
	overlay.queue_free()
	await process_frame
	print("PERK_UI checked=%d failures=%d" % [checked,failures.size()])
	quit(0 if failures.is_empty() else 1)
