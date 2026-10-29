extends SceneTree
## The level a full run reaches (docs/LAUF-DESIGN.de.md 4.1): every fight room
## of floors 1-10 is started and its monsters are counted with their EXP, plus
## the guardians and mini-guardians; the sum, put through the world's level
## curve, must land on level 14 ± 2 at the final guardian, so the run talent
## tree is about 60 % full and every point is a choice. Hell-Dungeon and
## Frostgruft (one curve, theme leveling).

const HellScene = preload("res://src/hell/hell_dungeon.tscn")
const FrostScene = preload("res://src/hell/frost_dungeon.tscn")
const HeroKit = preload("res://src/hell/hero_kit.gd")
const TARGET := 14
const SPREAD := 2

var checked := 0
var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	checked += 1
	if not condition:
		failures.append(label)
		printerr("RUN_CURVE_FAIL: ", label)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for pair: Array in [[HellScene, "hell"], [FrostScene, "frost"]]:
		var level := await _simulate(pair[0])
		print("RUN_CURVE %s level_at_final=%d" % [pair[1], level])
		check(absi(level - TARGET) <= SPREAD, "%s: a full run reaches level %d (target %d ± %d)" % [pair[1], level, TARGET, SPREAD])
	print("RUN_CURVE checked=%d failures=%d" % [checked, failures.size()])
	quit(1 if failures.size() > 0 else 0)


## The level after the EXP of every fight room and guardian of floors 1..10.
func _simulate(scene: PackedScene) -> int:
	var game: Node = scene.instantiate()
	game.class_id = "mage"
	root.add_child(game)
	await process_frame
	game.set_process(false)
	var total := 0
	for n in range(1, game.floors_raw.size() + 1):
		game.load_floor(n, true)
		for r: Dictionary in game.W.rooms:
			if str(r.type) != "combat" and str(r.type) != "boss":
				continue
			game.mobs = []
			# stand far from the room so every spawn cell counts
			game.player.x = -10000.0
			game.player.y = -10000.0
			game._start_fight(r)
			for m: Dictionary in game.mobs:
				total += HeroKit.exp_for(game, m)
			if str(r.type) == "boss" and game.mobs.filter(func(m: Dictionary) -> bool: return m.kind == "boss").is_empty():
				total += HeroKit.exp_for(game, {"kind": "boss", "def": {}})
	game.mobs = []
	var cfg: Dictionary = game.theme.leveling
	var level := 1
	var left := total
	while level < int(cfg.get("max_level", 20)) and left >= HeroKit.need(cfg, level):
		left -= HeroKit.need(cfg, level)
		level += 1
	print("RUN_CURVE exp_total=%d" % total)
	game.queue_free()
	await process_frame
	return level
