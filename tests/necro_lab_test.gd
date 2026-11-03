extends SceneTree
## Dedicated offline Necromancer room, real talents and input isolation.
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; printerr("NECRO_LAB_FAIL: ",label)
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	if not ResourceLoader.exists("res://src/debug/necro_lab_game.gd"):
		check(false,"dedicated playable Necromancer room is implemented")
		quit(1)
		return
	var lab = load("res://src/debug/necro_lab_game.gd").new()
	root.add_child(lab)
	await process_frame
	lab.set_process(false)
	lab.set_physics_process(false)
	lab.view.set_audio_enabled(false)
	check(lab.active and lab.hosting and lab.multiplayer.multiplayer_peer is OfflineMultiplayerPeer,"actual offline game without network sockets")
	check(str(lab.players[1].class_id)=="necromancer","only Necromancer class")
	check(lab.current_layout.world_size==[1600,960],"dedicated spacious arena")
	check(lab.progress.save_path=="user://necro_lab_profile.json" and lab.run_slot==0,"separate disposable profile and no campaign save slot")
	check(lab.enemies.size()==6,"real initial enemy group")
	check(lab.view.round_actor_markers,"lab enables readable round hero marker")
	lab._update_camera(0)
	var hero_screen: Vector2 = lab.view.to_global(lab.players[1].pos)
	check(hero_screen.distance_to(root.get_visible_rect().size*0.5)<70,"hero framed near screen center")
	for branch: String in ["minion","curse","soul"]:
		lab.lab_action("spec",branch)
		var rt: Dictionary = lab.talent_combat.runtime(1)
		check(rt["class"]=="necromancer" and str(rt.ultimate)==str(lab.lab_cfg.specs[branch].ultimate),"real ultimate for "+branch)
		for kit in range(2):
			lab.lab_action("kit",kit)
			check(lab.talent_combat.runtime(1).bar==lab.lab_cfg.specs[branch].kits[kit].bar,"all real attack kits selectable "+branch+str(kit))
	lab.lab_action("spec","curse")
	lab.scripted_target = Vector2(lab.players[1].pos)+Vector2(600,0)
	var preview: Dictionary = lab.lab_art.preview()
	lab.talent_combat.cast(1,"curse_7",{"target":lab.scripted_target})
	check(Vector2(lab.talent_combat.zones[-1].pos).is_equal_approx(Vector2(preview.center)),"aim ring center exactly matches actual zone placement")
	lab.scripted_target = Vector2.INF
	lab.lab_action("reset",null)
	lab.lab_action("auto",false)
	lab.lab_action("clear",null)
	var before: int = lab.bullets.size()
	lab.lab_step(0.2)
	check(lab.bullets.size()==before,"no phantom autofire when off")
	lab.lab_action("group",null)
	lab.lab_action("auto",true)
	lab.lab_step(0.2)
	check(lab.bullets.size()>before,"autofire uses actual basic attack")
	lab.pause_open = true
	before = lab.bullets.size()
	lab.lab_step(1)
	check(lab.bullets.size()==before,"solo pause suppresses autofire")
	lab.pause_open = false
	lab.lab_action("reset",null)
	check(lab.talent_combat.zones.is_empty() and lab.talent_combat.pets.is_empty(),"reset clears real fields and companions")
	check(lab.phase=="combat" and not lab.reward_open,"training does not generate reward screens")
	lab.queue_free()
	await process_frame
	print("NECRO_LAB checked=%d failures=%d"%[checks,failures])
	quit(1 if failures else 0)
