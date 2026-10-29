extends RefCounted
## Test cheats for the crypt, reached from the ESC menu (page "Cheats").
## Debug only: they work in a solo run of a debug build (editor or console
## Godot), never in multiplayer and never in an exported release game. Jump to level 10 (cards stay queued to pick, or are picked
## automatically), +1 level, invulnerable, no skill cooldowns, full health,
## clear the room, an item kit, and cycling through the class's legendary
## weapons. Each cheat answers with a short note (the inventory toast).
## Values and button order: assets/data/debug_cheats.json.

const ItemRules = preload("res://src/items/item_rules.gd")
const ClassPerks = preload("res://src/player/class_perks.gd")
const PerkRules = preload("res://src/perk_rules.gd")
const DATA := "res://assets/data/debug_cheats.json"

var game: Node
var data: Dictionary = {}


func bind(owner: Node) -> void:
	game = owner
	if data.is_empty(): data = load_data()


static func load_data() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA)) if FileAccess.file_exists(DATA) else null
	return parsed if parsed is Dictionary else {"order": []}


## The cheat ids in menu order.
func order() -> Array:
	return data.get("order", [])


## True when peer `id` may cheat: a debug build, a solo run, the host's own hero.
func allowed(id: int) -> bool:
	return enabled(game) and game.players.has(id) and id == 1


## Cheats exist at all: a debug build hosting a solo run (no other players).
static func enabled(owner: Node) -> bool:
	return OS.is_debug_build() and owner != null and bool(owner.get("hosting")) and owner.players.size() == 1


## Runs cheat number `index` (order in cheats.json) for peer `id`. Returns false when refused.
func act(id: int, index: int) -> bool:
	var list := order()
	if not allowed(id) or index < 0 or index >= list.size(): return false
	var player: Dictionary = game.players[id]
	match str(list[index]):
		"all_skills": _all_skills(player)
		"level_target": _level_to(int(data.get("target_level", 10)), player)
		"level_up": _level_to(int(game.team_progress.team.level) + 1, player)
		"auto_cards": _auto_cards(player)
		"god":
			player.cheat_god = not bool(player.get("cheat_god", false))
			_note(player, "CHEAT: Unverwundbar " + ("an" if player.cheat_god else "aus"))
		"no_cooldown":
			player.cheat_no_cooldown = not bool(player.get("cheat_no_cooldown", false))
			if player.cheat_no_cooldown and player.has("skill_cd"):
				for slot in range(Array(player.skill_cd).size()): player.skill_cd[slot] = 0.0
			_note(player, "CHEAT: Keine Abklingzeit " + ("an" if player.cheat_no_cooldown else "aus"))
		"heal":
			player.hp = int(player.max_hp)
			if "player_effects" in game: game.player_effects.clear(player)
			_note(player, "CHEAT: Volles Leben")
		"clear_room": _clear_room(id, player)
		"item_kit": _item_kit(player)
		"legendary": _legendary(player)
		_: return false
	return true


func _level_to(level: int, player: Dictionary) -> void:
	var progress: RefCounted = game.team_progress
	var maximum := int(progress._config("leveling").get("max_level", 40))
	level = mini(level, maximum)
	var guard := 0
	while int(progress.team.level) < level and guard < 100:
		progress.add_exp(maxi(1, progress.next_level_exp() - int(progress.team.get("exp", 0))))
		guard += 1
	_note(player, "CHEAT: Team-Level %d · Punkte mit B verteilen" % int(progress.team.level))


## Opens all four skills of the hero's class (team level up to the last
## unlock) and gives every upgrade of every skill at its full rank.
func _all_skills(player: Dictionary) -> void:
	var class_id := str(player.get("class_id", ""))
	var skills: Array = ClassPerks.skills(class_id)
	if skills.is_empty():
		_note(player, "CHEAT: Diese Klasse hat keine Fähigkeiten")
		return
	var last_unlock := 1
	for skill: Dictionary in skills: last_unlock = maxi(last_unlock, int(skill.get("unlock", 1)))
	if int(game.team_progress.team.level) < last_unlock: _level_to(last_unlock, player)
	var granted := 0
	for skill: Dictionary in skills:
		for upgrade: Dictionary in skill.get("upgrades", []):
			while ClassPerks.grant(player, str(upgrade.id)): granted += 1
	PerkRules.rebuild(player, game.balance)
	# The open level cards would only offer what is owned now; drop skill cards.
	player.offer_queue = []
	player.offer = []
	player.offer_kind = ""
	_note(player, "CHEAT: Alle %d Fähigkeiten offen · %d Verbesserungen" % [skills.size(), granted])


## Picks the open cards (boss perks) and spends every run talent point on the first open node.
func _auto_cards(player: Dictionary) -> void:
	var picked := 0
	while not Array(player.get("offer", [])).is_empty() and picked < 60:
		if not game.team_progress.pick(player, 0): break
		picked += 1
	var spent := 0
	var ids: Array = ClassPerks.run_tree_ids(str(player.get("class_id", "")))
	var guard := 0
	while guard < 200:
		guard += 1
		var taken := false
		for id: Variant in ids:
			if game.team_progress.take_talent(player, str(id)):
				spent += 1
				taken = true
				break
		if not taken: break
	_note(player, "CHEAT: %d Karten gewählt · %d Talentpunkte verteilt" % [picked, spent])


func _clear_room(id: int, player: Dictionary) -> void:
	var count := 0
	# Twice: a Knochenkoloss falls apart once before it dies.
	for round_index in range(2):
		for enemy: Dictionary in Array(game.enemies).duplicate():
			if float(enemy.get("hp", 0)) <= 0.0: continue
			game._damage_enemy(enemy, float(enemy.max_hp) * 10.0 + 9999.0, Vector2.RIGHT, id)
			count += 1
	_note(player, "CHEAT: Raum geleert (%d Treffer)" % count)


func _item_kit(player: Dictionary) -> void:
	var inventory: RefCounted = game.inventory
	var kit: Dictionary = data.get("kit", {})
	inventory.add(player, inventory.make_stack("crystal", "", int(kit.get("crystal", 5))))
	inventory.add(player, inventory.make_stack("stone", "", int(kit.get("stone", 3))))
	for kind: String in inventory.data.get("potions", {}):
		if Array(player.inventory.bag).size() >= int(inventory.data.get("bag", 12)): break
		inventory.add(player, inventory.make_stack("potion", kind, int(kit.get("potions", 1))))
	_note(player, "CHEAT: Kristalle, Steine und Tränke im Rucksack")


## Puts the class's next legendary weapon in hand (known, uncursed), even over a cursed one.
func _legendary(player: Dictionary) -> void:
	var class_id := str(player.get("class_id", ""))
	var choices: Array = ItemRules.data().get("weapons", []).filter(func(weapon: Dictionary) -> bool: return str(weapon["class"]) == class_id and str(weapon.rarity) == "legendary")
	if choices.is_empty():
		_note(player, "CHEAT: Keine legendäre Waffe für diese Klasse")
		return
	var index := int(player.get("cheat_legendary", -1)) + 1
	player.cheat_legendary = index % choices.size()
	var spec: Dictionary = choices[player.cheat_legendary]
	player.inventory.weapon = game.inventory.make_weapon(str(spec.id), true, "")
	game.inventory.equip_apply(player)
	_note(player, "CHEAT: " + str(spec.name))


func _note(player: Dictionary, text: String) -> void:
	game.inventory.note(player, text)
