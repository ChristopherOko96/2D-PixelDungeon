extends SceneTree
## Regression: overkill uses resolved post-shield damage and requires a kill.
var game: Node
var checked: int = 0
var failed: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _enemy(id: int, point: Vector2, hp: float, guard: bool) -> Dictionary:
	return {"id":id,"pos":point,"hp":hp,"max_hp":hp,"radius":13.0,"kind":"skeleton_guard" if guard else "skeleton_archer","boss":false,"attack":"","hitstun":0.0,"hits":0,"hit_flash":0.0,"stun_cooldown":0.0,"knockback":Vector2.ZERO,"facing_dir":Vector2.LEFT,"dying":0.0}

func _run() -> void:
	game = load("res://src/game.gd").new()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	game.players.clear()
	game._add_player(1)
	game.current_layout = {"id":"guard-overkill","world_size":[768,512],"play_bounds":[32,32,704,448],"obstacles":[],"exits":[]}
	game._grant_perk(1,game.PerkRules.find(game.balance,"overkill"))
	for hp: float in [10.0,3.0]:
		# Arrange: a direct12-damage frontal hit, plus a nearby splash candidate.
		var guard: Dictionary = _enemy(20,Vector2(240,240),hp,true)
		var neighbor: Dictionary = _enemy(21,Vector2(280,240),100,false)
		game.enemies = [guard,neighbor]
		var bullet: Dictionary = {"owner":1,"damage":12.0,"velocity":Vector2.RIGHT*600,"primary":true,"distance":0.0}
		# Act through the actual perk/damage/shield boundary.
		game.perk_combat.hit(bullet,guard)
		var resolved: float = 12.0*float(game.balance.enemy_roster.definitions.skeleton_guard.guard_multiplier)
		var expected: float = maxf(0.0,resolved-hp)*float(game.players[1].build.overkill)
		# Assert no splash without a kill and only the real post-shield surplus.
		check(is_equal_approx(float(guard.hp),maxf(0.0,hp-resolved)),"front shield resolves the expected direct damage")
		check(is_equal_approx(float(neighbor.hp),100.0-expected),"overkill uses only actual lethal post-shield surplus at hp="+str(hp))
	game.queue_free()
	await process_frame
	print("CRYPT_GUARD_PERK checked=%d failures=%d" % [checked,failed])
	quit(1 if failed else 0)

func check(ok: bool, label: String) -> void:
	checked += 1
	if not ok:
		failed += 1
		printerr("GUARD_PERK_FAIL: ",label)
