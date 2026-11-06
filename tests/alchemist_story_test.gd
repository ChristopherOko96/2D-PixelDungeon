extends "res://tests/hell_talents_test.gd"
## Same host alchemy in all three real story adapters, including media consumption.
const KryptaScene = preload("res://src/hell/krypta_dungeon.tscn")
func _run() -> void:
	for scene: PackedScene in [HellScene,FrostScene,KryptaScene]:
		var game := await _new("archer","trapper",scene)
		var hero_hp := float(game.state.hp)
		var tc: RefCounted = game.talents.tc
		var rt: Dictionary = tc.runtime(1)
		for id: String in ["trapper_1","trapper_3","trapper_5","trapper_7","trapper_9","trapper_11"]: rt.ranks[id] = 3
		var at := Vector2(game.player.x+90,game.player.y)
		var target := _mob(game,Vector2(90,0))
		game.talents._sync_mobs()
		cast_in(game,"trapper_3",at)
		game.talents._with_sync(func(): tc.alchemist.step(tc,0.51))
		check(float(target.get("wet_t",0))>0, "story water wets actual monster in "+scene.resource_path)
		check(game.story_elements.media().any(func(z: Dictionary) -> bool: return str(z.get("st","")) == "water" and float(z.t)<float(z.T)), "story water is actual shared medium")
		cast_in(game,"trapper_7",at)
		game.talents._with_sync(func(): tc.alchemist.step(tc,0.51))
		check(float(target.get("frozen",0))>0, "story frost freezes actual wet normal target")
		cast_in(game,"trapper_9",at)
		var hp := float(target.hp)
		game.talents._with_sync(func(): tc.alchemist.step(tc,0.51))
		check(float(target.hp)<hp and float(target.get("frozen",0))<=0, "story shatter damages target and consumes real frost")
		cast_in(game,"trapper_1",at)
		game.talents._with_sync(func(): tc.alchemist.step(tc,0.51))
		check(game.story_elements.media().any(func(z: Dictionary) -> bool: return str(z.get("st","")) == "poison" and float(z.t)<float(z.T)), "story poison capsule creates live liquid")
		cast_in(game,"trapper_5",at)
		game.talents._with_sync(func(): tc.alchemist.step(tc,0.51))
		check(game.story_elements.media().filter(func(z: Dictionary) -> bool: return str(z.get("st","")) == "poison").all(func(z: Dictionary) -> bool: return float(z.t)>=float(z.T)), "story ignition consumes poison once")
		game.mobs.clear()
		game.talents._sync_mobs()
		cast_in(game,"trapper_14",at)
		game.talents._with_sync(func(): tc.alchemist.step(tc,0.8))
		check(tc.alchemist.fields.size()==1 and game.story_elements.media().filter(func(z: Dictionary) -> bool: return z.has("alchemy_owner") and float(z.t)<float(z.T)).size()<=6, "ultimate has bounded real story media")
		game.talents._with_sync(func(): tc.alchemist.step(tc,2.0))
		check(tc.alchemist.fields.is_empty(), "story ultimate finishes scheduler")
		cast_in(game,"trapper_3",at)
		game.talents._with_sync(func(): tc.alchemist.step(tc,0.51))
		var aim := (at-Vector2(game.player.x,game.player.y-40)).normalized()
		game._attack(aim)
		for frame in range(16): game._update_shots(0.05)
		check(tc.traps.is_empty(),"actual story basic arrow opens capsule through normal shot loop")
		check(float(game.state.hp) == hero_hp, "own alchemy sequence never damages hero")
		await _free(game)
	print("ALCHEMIST_STORY checked=%d failures=%d" % [checked,failures.size()])
	quit(1 if not failures.is_empty() else 0)

func cast_in(game: Node, id: String, at: Vector2) -> void:
	var rt: Dictionary = game.talents.tc.runtime(1)
	rt.res = rt.res_max
	rt.gcd = 0.0
	rt.cds[id] = 0.0
	game.talents._with_sync(func(): check(game.talents.tc.cast(1,id,{"target":at}),"story accepts paid "+id))
