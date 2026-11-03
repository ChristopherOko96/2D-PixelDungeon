extends "res://tests/hell_talents_test.gd"
## Real Hölle/Frost adapters share finite media and skeletal form rules.
func _run() -> void:
	for scene: PackedScene in [HellScene, FrostScene]:
		var game := await _new("necromancer", "minion", scene)
		var adapter = game.talents
		var tc = adapter.tc
		var rt: Dictionary = tc.runtime(1)
		var arena_minion = preload("res://src/debug/story_testraum.gd").new()
		arena_minion.g = game
		arena_minion.cfg = arena_minion.config()
		arena_minion._tdata = adapter.data
		game.testraum = {"spec":"minion","level":30,"stage":1,"companion":"wolf"}
		arena_minion._apply_build()
		check(tc.runtime(1).bar==["minion_1","minion_9","minion_5","minion_7"],"actual DEBUG Diener bar has warrior archers blood mark and explosion")
		arena_minion.free()
		rt = tc.runtime(1)
		check(tc.permanent_pet(1).is_empty() and tc.cast(1,"minion_1",{"aim":Vector2.RIGHT}),"story warrior requires explicit summon")
		var pet: Dictionary = tc.permanent_pet(1)
		check(not pet.is_empty(), "permanent bone warrior present: " + scene.resource_path)
		game.mobs.clear()
		for i in range(4):
			adapter.talent_pool("blood", Vector2(pet.pos), 64, 20, 1)
			for j in range(45): tc.step(0.05)
		rt.gcd = 0.0
		rt.res = 100.0
		check(tc.cast(1,"minion_14"),"story full blood activates R")
		check(str(pet.get("rig", "")) == "blood_colossus", "story real blood transforms actual skeleton")
		check(adapter.talent_media().filter(func(z: Dictionary) -> bool: return str(z.get("st", "")) == "blood").all(func(z: Dictionary) -> bool: return float(z.t) >= float(z.T)), "story blood atomically spent")
		check(tc.player_state(1).pet.abilities[0].id == "bone_stomp", "story HUD owns large-form command 5")
		# Shared actual curse hit and material on a fresh legal specialization.
		var ranks := {}
		for id: String in adapter.data.classes.necromancer.specs[1].talents: ranks[id] = 1
		var remaining: int = tc.Rules.points_total(adapter.data, 30) - ranks.size()
		for id: String in adapter.data.classes.necromancer.specs[1].talents:
			var extra := mini(remaining, int(adapter.data.talents[id].ranks) - 1)
			ranks[id] = int(ranks[id]) + extra
			remaining -= extra
		tc.set_build(1, {"class": "necromancer", "level": 30, "ranks": ranks, "bar": ["curse_1", "curse_7", "curse_9", "curse_11"]})
		check(int(tc.runtime(1).ranks.get("curse_11", 0)) > 0, "legal story build really retains harvest")
		var mob := _mob(game, Vector2(60, 0))
		adapter._sync_mobs()
		tc.bullet_hit({"owner": 1, "talent": "curse_1", "damage": 1.0, "style": "curse_bolt"}, mob)
		check(mob.get("necro_curses", {}).has("1"), "story target receives magical decay")
		check(adapter.talent_media().any(func(z: Dictionary) -> bool: return str(z.get("st", "")) == "poison" and float(z.t) < float(z.T)), "story curse leaves existing poison puddle")
		check(game.story_elements.safe_medium(Vector2(mob.pos), "poison"), "friendly poison keeps hero safe")
		game.story_elements.add_pool({"kind": "puddle", "p": Vector2(mob.pos), "r": 40, "T": 3, "st": "poison", "friend": false})
		check(not game.story_elements.safe_medium(Vector2(mob.pos), "poison"), "hostile overlapping poison remains dangerous")
		var hp := float(mob.hp)
		tc.step(0.6)
		check(float(mob.hp) < hp, "story decay actually deals resolved damage")
		tc.runtime(1).res = 100.0
		tc.runtime(1).gcd = 0.0
		check(tc.cast(1,"curse_9",{"target":Vector2(mob.pos)}),"story blood beam starts")
		mob.p = Vector2(mob.p)+Vector2(20,15)
		_tick(game,0.1)
		var links: Array = tc.snapshot().get("blood_links",[])
		check(not links.is_empty() and int(links[0].target_id)==int(mob.tid) and Vector2(links[0].tx,links[0].ty).is_equal_approx(Vector2(mob.p)),"story beam follows actual mob tid and updated position")
		var arena = preload("res://src/debug/story_testraum.gd").new()
		arena.g = game
		arena.cfg = arena.config()
		arena._tdata = adapter.data
		game.testraum = {"spec":"curse", "level":30, "stage":1, "companion":"wolf"}
		arena._apply_build()
		check(tc.runtime(1).bar == ["curse_1", "curse_3", "curse_7", "curse_9"], "actual DEBUG Testraum offers curse field and blood drain together")
		check(arena._tool_ok("puddle", {"st":"blood"}), "actual DEBUG Testraum permits blood tool in this world")
		arena.free()
		# Exercise the new raise path through each real world's killed adapter.
		var field_victim := _mob(game, Vector2(60, 0))
		adapter._sync_mobs()
		tc.runtime(1).res = 100.0
		tc.runtime(1).gcd = 0.0
		tc.runtime(1).cds.erase("curse_7")
		check(tc.cast(1,"curse_7",{"target":Vector2(field_victim.pos)}),"story real poison field casts for skeletal conversion")
		field_victim.hp = 0.0
		adapter.killed(field_victim)
		check(tc.pets.any(func(p:Dictionary)->bool:return bool(p.get("plague_runner",false)) and str(p.rig)=="skeleton"),"story killed adapter raises actual rigged skeletal runner inside own poison")
		tc.runtime(1).res = 100.0
		tc.runtime(1).gcd = 0.0
		check(tc.cast(1,"curse_14",{"target":Vector2(field_victim.pos)}),"story R creates the real poison ritual")
		var ritual_victim := _mob(game,Vector2(60,0))
		adapter._sync_mobs()
		ritual_victim.hp = 0.0
		adapter.killed(ritual_victim)
		tc._step_pets(0.05)
		check(tc.pets.any(func(p:Dictionary)->bool:return str(p.kind)=="curse_colossus" and str(p.rig)=="curse_colossus"),"story enemy death in real poison manifests eight-part curse monster")
		await _free(game)
	print("NECRO_BRANCHES_STORY checked=%d failures=%d" % [checked, failures.size()])
	quit(0 if failures.is_empty() else 1)
