extends SceneTree
## Bosses and lava (docs/BEUTEORDNUNG.de.md 8, user wish 07.11.2026): the lava's own bosses (hell_balance.json
## monsters.lava_bosses: Glutwächter, Kesselbrut) walk through it; every other walking boss (Kerkermeister,
## Klagender Hüter, Ignaroth ...) never stands in lava: it stops at the edge or leaps over a narrow stream.
## Usage:
##   godot --headless --path . --script res://tests/hell_boss_lava_test.gd
const HellScene = preload("res://src/hell/hell_dungeon.tscn")
const ROOM := "res://assets/data/world_rooms/hell/h_boss_glutbecken_b.json"

var _checked := 0
var _failed := 0
var game: Node


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	_checked += 1
	if not ok:
		_failed += 1
		printerr("HELL_BOSS_LAVA_FAIL: ", what)


func _run() -> void:
	game = HellScene.instantiate()
	game.class_id = "swordsman"
	game.graphics_path = "user://hell_boss_lava_test_graphics.cfg"
	game.world_room_path = ROOM
	root.add_child(game)
	for i in range(30):
		await process_frame
	var mon: RefCounted = game.monsters
	_check(mon != null, "the hell has its monsters")
	if mon == null:
		quit(1)
		return
	# Arrange: the lava floor's cells; one lava cell with firm ground on both sides along x
	var lava := Vector2i(-1, -1)
	for y in range(int(game.W.rows)):
		for x in range(2, int(game.W.cols) - 3):
			if lava.x < 0 and game._cell(x, y) == 1 and game._cell(x + 1, y) == 2 and game._cell(x + 2, y) == 2 and game._cell(x + 3, y) == 2 and game._cell(x + 4, y) == 1:
				lava = Vector2i(x + 1, y)
	_check(lava.x >= 0, "the basin has a narrow lava stream")
	var kerker: Dictionary = mon.spawn(int(game.state.room), Vector2((lava.x - 1 + 0.5) * game.C, (lava.y + 0.5) * game.C), "kerkermeister", true)
	var brood: Dictionary = mon.spawn(int(game.state.room), Vector2((lava.x - 1 + 0.5) * game.C, (lava.y + 0.5) * game.C), "kesselbrut", true)
	_check(mon.keeps_dry(kerker), "the Kerkermeister keeps out of the lava")
	_check(not mon.keeps_dry(brood), "the Kesselbrut is a creature of the lava")
	# Act: the hero waits beyond the stream; the Kerkermeister comes for him
	var wet := 0
	var leaped := false
	for i in range(360):
		game.state.hp = game.state.max_hp
		game.state.inv = 5.0
		game.place_player(Vector2((lava.x + 4 + 0.5) * game.C, (lava.y + 0.5) * game.C + 10.0))
		await process_frame
		if kerker.has("leap"):
			leaped = true
		elif mon.lava_at(kerker.p):
			wet += 1
	# Assert
	_check(wet == 0, "the Kerkermeister never stands in lava (%d frames)" % wet)
	_check(leaped, "it leaps over the narrow stream")
	_check((kerker.p as Vector2).x > (lava.x + 2) * game.C, "it reached the far side (x %.0f)" % float(kerker.p.x))
	print("HELL_BOSS_LAVA checked=%d failures=%d" % [_checked, _failed])
	game.queue_free()
	quit(1 if _failed > 0 else 0)
