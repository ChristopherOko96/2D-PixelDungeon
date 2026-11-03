extends SceneTree
## Actual direct forest training entry remains offline and uses archer rules.
var failures := 0
var checked := 0
func check(ok: bool, label: String) -> void:
	checked+=1
	if not ok: failures+=1; printerr("FOREST_LAB_FAIL: ",label)
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var lab := preload("res://src/debug/necro_lab_game.gd").new()
	lab.lab_cfg=JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/debug_forest_lab.json"))
	root.add_child(lab)
	await process_frame
	lab.set_process(false)
	lab.set_physics_process(false)
	lab.view.set_audio_enabled(false)
	check(str(lab.players[1].class_id)=="archer","training really starts an archer")
	check(lab.multiplayer.multiplayer_peer is OfflineMultiplayerPeer,"forest training opens no sockets")
	check(lab.progress.save_path=="user://forest_lab_profile.json" and lab.run_slot==0,"separate profile and no campaign save")
	for spec: String in lab.lab_cfg.specs:
		lab.lab_action("spec",spec)
		for kit in range(2):
			lab.lab_action("kit",kit)
			check(lab.talent_combat.runtime(1).bar==lab.lab_cfg.specs[spec].kits[kit].bar,"real archer kit "+spec+str(kit))
	lab.lab_action("spec","beast")
	check(lab.talent_combat.cast(1,"beast_14"),"training ultimate uses actual worm summon")
	check(lab.talent_combat.pets.filter(func(p:Dictionary)->bool:return str(p.kind) in ["poison_worm","fire_worm"]).size()==2,"both worm rigs appear in playable lab")
	lab.queue_free()
	await process_frame
	print("FOREST_LAB checked=%d failures=%d"%[checked,failures])
	quit(1 if failures else 0)
