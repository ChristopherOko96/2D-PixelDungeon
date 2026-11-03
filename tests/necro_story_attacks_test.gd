extends "res://tests/hell_talents_test.gd"
## The actual Hell and Frost adapters, with real mobs, paid soul costs and
## shared charged-shot simulation. Controlled encounters, not campaigns.
func _run() -> void:
	for scene: PackedScene in [HellScene, FrostScene]:
		var game := await _new("necromancer", "soul", scene)
		var adapter = game.talents
		var ranks := {}
		for id: String in adapter.data.classes.necromancer.specs[2].talents: ranks[id] = 1
		var remaining: int = adapter.tc.Rules.points_total(adapter.data, 30) - ranks.size()
		for id: String in adapter.data.classes.necromancer.specs[2].talents:
			var extra := mini(remaining, int(adapter.data.talents[id].ranks) - 1)
			ranks[id] = int(ranks[id]) + extra
			remaining -= extra
		adapter.tc.set_build(1, {"class": "necromancer", "level": 30, "ranks": ranks, "bar": ["soul_9", "soul_1", "soul_3"]})
		var rt: Dictionary = adapter.tc.runtime(1)
		rt.res = 80.0
		var enemy := _mob(game, Vector2(60, 0))
		var before := float(enemy.hp)
		check(adapter.press(0) and rt.has("soul_charge") and adapter.bullets.is_empty(), "story key starts held lance in " + scene.resource_path)
		adapter.tc.step(0.8)
		check(float(rt.res) < 58.0, "story charge spends additional souls")
		adapter.tc.SoulCharge.hold(adapter.tc, 1, false, Vector2.RIGHT)
		adapter._step_bullets(0.5)
		check(float(enemy.hp) < before and adapter.bullets.is_empty(), "story lance hits first real mob and ends")
		check(adapter.tc.events.any(func(e: Dictionary) -> bool: return str(e.kind) == "soul_impact"), "story host supplies impact for same spirit rigs")
		var actor := {"owner": 1, "pos": Vector2(enemy.pos) - Vector2(30, 0), "target": -1}
		adapter.tc._pet_prey(actor, adapter.players[1])
		check(int(actor.target) == int(enemy.tid), "story companion retains actual mob tid")
		game.breakables.append({"type": "crate", "x": game.player.x + 80.0, "y": game.player.y + 30.0, "broken": false})
		var hidden := _mob(game, Vector2(160, 0))
		before = float(hidden.hp)
		adapter.tc.runtime(1).gcd = 0.0
		check(adapter.press(1), "story bolt can be cast")
		# Remove the nearer live enemy: only the crate and hidden target remain.
		enemy.hp = 0.0
		adapter._step_bullets(0.6)
		check(float(hidden.hp) == before and adapter.bullets.is_empty(), "story enlarged bolt stops at solid prop")
		var route: PackedVector2Array = adapter.talent_path(Vector2(game.player.x, game.player.y), hidden.p, 10.0)
		check(not route.is_empty(), "story navigation finds route around actual crate")
		adapter.tc._spawn_pet(1, rt, "soul_1", {"pet_kind": "bone_warrior", "hp": 50, "every": 1.0, "dmg": 1.0}, Vector2(game.player.x, game.player.y), false, 30.0)
		for tick in range(80):
			adapter._sync_mobs()
			adapter.tc.step(0.05)
		check(float(hidden.hp) < before, "story companion independently routes around crate and attacks")
		adapter.tc.runtime(1).gcd = 0.0
		check(adapter.tc.cast(1, "soul_7", {"aim": Vector2.LEFT}) and adapter.tc.runtime(1).has("soul_leap"), "story begins authoritative rig leap")
		_tick(game, 0.9)
		check(not adapter.tc.runtime(1).has("soul_leap") and is_equal_approx(float(game.player.x), Vector2(adapter.players[1].pos).x), "story hero position follows completed leap")
		game.mobs.clear()
		game.breakables.clear()
		var tethered := _mob(game,Vector2(150,0))
		adapter._sync_mobs()
		adapter.tc.runtime(1).gcd = 0.0
		adapter.tc.runtime(1).res = 100.0
		check(adapter.tc.cast(1,"soul_14",{"aim":Vector2.RIGHT}),"story guardian is actually summoned")
		_tick(game,0.7)
		adapter.tc.guardians.actors[0].autos = [false,false]
		check(adapter.tc.guardians.command(adapter.tc,1,0,Vector2.RIGHT),"story guardian beam casts through shared host kernel")
		_tick(game,0.5)
		before = float(tethered.hp)
		tethered.p = Vector2(tethered.p)+Vector2(0,45)
		adapter._sync_mobs()
		_tick(game,0.3)
		var link: Dictionary = adapter.tc.guardians.snapshot()[0]
		check(float(tethered.hp)<before and int(link.beam_target_id)==int(tethered.tid),"story moving mob keeps beam damage and stable tid")
		check(Vector2(link.beam_tx,link.beam_ty).is_equal_approx(tethered.p),"story beam endpoint follows actual Hölle/Frost mob")
		await _free(game)
	print("NECRO_STORY_ATTACKS checked=%d failures=%d" % [checked, failures.size()])
	quit(0 if failures.is_empty() else 1)
