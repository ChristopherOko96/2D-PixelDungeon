extends "res://tests/hell_talents_test.gd"
## Real steam perception and actual talent-menu companion selection in three story runtimes.
const KryptaScene = preload("res://src/hell/krypta_dungeon.tscn")
func _run() -> void:
	for scene: PackedScene in [HellScene,FrostScene,KryptaScene]:
		remove_fixture_profile()
		var game := await _new("archer","trapper",scene)
		game._step_gas(0.01)
		var target := _mob(game,Vector2(150,0))
		target.k = Vector2.ZERO
		game.gas.emit("followup-steam","steam",target.p,180,5,float(game.state.t))
		for frame in range(50):
			game.state.t = float(game.state.t)+0.05
			game._step_gas(0.05)
			game._update_mobs(0.05)
			if float(target.get("sight_blind_s",0))>2.9: break
		check(float(target.get("sight_blind_s",0))>2.9,"real steam blinds story enemy in "+scene.resource_path)
		target.k = Vector2.ZERO
		var start: Vector2 = target.p
		game._update_mobs(0.05)
		check(Vector2(target.p).distance_to(start)<0.1 and int(target.get("aggro_target",-1))==-1,"steam interrupts story tracking and pursuit")
		game.gas.clear()
		for frame in range(20):
			game.state.t = float(game.state.t)+0.1
			game._update_mobs(0.1)
		check(float(target.get("sight_blind_s",0))>0.5 and Vector2(target.p).distance_to(start)<0.1,"story sight loss lasts after leaving gas")
		for frame in range(15): game._update_mobs(0.1)
		check(float(target.get("sight_blind_s",0))<=0,"story sight loss expires")
		await _free(game)
		remove_fixture_profile()
		game = await _new("archer","beast",scene)
		var tc: RefCounted = game.talents.tc
		check(str(tc.permanent_pet(1).get("kind",""))=="wolf","initial story companion is wolf")
		game.open_run_talents()
		game.run_talents._cycle_companion() # Actual UI handler, save and profile_changed signal.
		check(str(tc.runtime(1).companion)=="bear" and str(tc.permanent_pet(1).kind)=="wolf","real menu selects bear without a free replacement")
		game.run_talents.close()
		game.talents._with_sync(func(): check(tc.cast(1,"beast_1"),"normal reactivation applies selected story companion"))
		check(str(tc.permanent_pet(1).kind)=="bear" and tc.snapshot().pets.size()==1,"story owns and draws exactly one selected bear")
		await _free(game)
	print("ALCHEMIST_FOLLOWUP_STORY checked=%d failures=%d" % [checked,failures.size()])
	quit(1 if not failures.is_empty() else 0)

func remove_fixture_profile() -> void:
	var file := "user://hell_talents_test_profile.json"
	if FileAccess.file_exists(file): DirAccess.remove_absolute(ProjectSettings.globalize_path(file))
