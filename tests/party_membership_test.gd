extends SceneTree
## Pure lobby-membership fixture: no ready(), transport, files or scene polling.
const Game = preload("res://src/game.gd")
var checked := 0
var failures: Array[String] = []

func _initialize() -> void:
	var game := Game.new()
	game.balance = {"player":{"hp":8,"damage":2,"speed":190,"shot_interval":0.2}}
	for id: int in [1,2,3,4]: game._add_player(id)
	var original_host_color: Color = game.players[1].color
	var old_second_color: Color = game.players[2].color
	var original_fourth_color: Color = game.players[4].color
	check(_colors(game).size() == 4,"four initial members have distinct colors")
	game.players.erase(2)
	game._add_player(5)
	check(game.players.size() == 4,"replacement returns the party to four players")
	check(_colors(game).size() == 4,"rejoining after a middle departure does not duplicate a remaining color")
	check(game.players[5].color == old_second_color,"replacement uses the actually vacant color")
	check(game.players[1].color == original_host_color and game.players[4].color == original_fourth_color,"existing members keep their colors")
	game.free()
	print("PARTY_MEMBERSHIP checked=%d failures=%d" % [checked,failures.size()])
	for failure in failures: printerr("MEMBERSHIP_FAIL ",failure)
	quit(0 if failures.is_empty() else 1)

func _colors(game: Node) -> Dictionary:
	var unique: Dictionary = {}
	for player: Dictionary in game.players.values(): unique[player.color] = true
	return unique

func check(condition: bool, description: String) -> void:
	checked += 1
	if not condition: failures.append(description)
