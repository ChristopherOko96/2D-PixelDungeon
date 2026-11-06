extends "res://scripts/capture_ranger_fields.gd"
## Real paid laboratory casts; prepared build, not an earned campaign.
func _start() -> void:
	capture_out = "res://production/qa/evidence/alchemist"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(capture_out))
	await _make(true)
	game.view.set_process(false)
	game.lab_action("spec","trapper")
	game.lab_action("auto",false)
	game.lab_action("clear",null)
	game.players[1].pos = Vector2(600,380)
	for id: String in ["trapper_1","trapper_3","trapper_5","trapper_7","trapper_9","trapper_11"]: game.talent_combat.runtime(1).ranks[id] = 3
	var ids := ["trapper_1","trapper_3","trapper_5","trapper_7","trapper_9"]
	var points := [Vector2(720,300),Vector2(800,330),Vector2(800,440),Vector2(700,500),Vector2(610,520)]
	for n in range(ids.size()):
		_ready_cast(ids[n],points[n])
	await _advance(0.55)
	await _photo("01-five-capsules")
	game.talent_combat.alchemist.detonate(game.talent_combat,1,Vector2(760,310),70)
	await _advance(0.15)
	await _photo("02-water-poison")
	game.lab_action("clear",null)
	game.talent_combat.traps.clear()
	game.boss_moves.zones.clear()
	game.talent_combat.alchemist.clear()
	for at: Vector2 in [Vector2(770,350),Vector2(840,360),Vector2(810,420)]: _foe(at)
	_ready_cast("trapper_14",Vector2(800,380))
	await _advance(0.25)
	await _photo("03-apparatus")
	await _advance(0.6)
	await _photo("04-deployed")
	await _advance(0.85)
	await _photo("05-frozen")
	await _advance(0.95)
	await _photo("06-ignition")
	await _tree("trapper_14","07-talent-tree")
	print("ALCHEMIST_CAPTURE images=7 training=true paid_casts=true")
	game.queue_free()
	await process_frame
	quit()

func _ready_cast(id: String, at: Vector2) -> void:
	var rt: Dictionary = game.talent_combat.runtime(1)
	rt.gcd = 0
	rt.res = rt.res_max
	rt.cds[id] = 0.0
	if rt.get("ability_charges",{}).has(id): rt.ability_charges[id].left = 3
	if not game.talent_combat.cast(1,id,{"target":at}): printerr("ALCHEMIST_CAPTURE_FAIL cast ",id)

func _advance(seconds: float) -> void:
	for frame in range(ceili(seconds*60)):
		_step(1.0/60)
		_sync_view()
		game.view._process_view(1.0/60)
		await process_frame
