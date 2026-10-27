extends SceneTree
## Deterministic client presentation checks; no game/clock/peers or external data.
const Buffer = preload("res://src/snapshot_interpolator.gd")
var checked := 0
var failures: Array[String] = []

func _initialize() -> void:
	test_midpoint_smooths_positions_without_delaying_authoritative_values()
	test_geometry_and_inputs_remain_immutable_and_shared()
	test_jitter_and_stale_packets_do_not_rewind_presentation()
	test_removed_dead_revived_and_new_entities_do_not_ghost()
	test_teleports_and_large_packet_gaps_snap_instead_of_crossing_the_map()
	test_latency_change_rebuffers_without_replaying_old_motion()
	test_identity_reuse_and_future_teleport_cut_delayed_history()
	test_equal_timestamps_replace_and_prior_room_packets_remain_stale()
	test_blocked_corner_pair_snaps_once_and_clear_following_pair_smooths()
	test_validator_change_cuts_history_without_readmitting_old_packets()
	test_fade_room_revision_floor_and_run_changes_cut_history()
	test_missing_packets_hold_latest_without_extrapolation()
	test_bounded_history_and_invalid_input_are_safe()
	print("SNAPSHOT_INTERPOLATION checked=%d failures=%d" % [checked,failures.size()])
	quit(0 if failures.is_empty() else 1)

func check(condition: bool, message: String) -> void:
	checked += 1
	if not condition:
		failures.append(message)
		printerr("SNAPSHOT_INTERPOLATION_FAIL: ",message)

func state(sequence: int, timestamp: float, x: float) -> Dictionary:
	return {"seq":sequence,"server_time":timestamp,"run_seed":42,"floor_index":1,"room_layout_revision":1,"room_layout":{"id":"room-a","painted_tiles":[{"x":0,"y":0,"tile":"violet_017","layer":"floor","solid":false}]},"phase":"combat","players":{1:{"x":x,"y":40.0,"hp":8,"max_hp":8,"perks":["heart"]}},"enemies":[{"id":2,"x":x+20,"y":60.0,"hp":8,"kind":"chaser","dying_p":-1.0}],"bullets":[{"id":3,"x":x+40,"y":80.0,"owner":1}]}

func new_buffer() -> Buffer:
	var buffer: Buffer = Buffer.new()
	buffer.configure({"interpolation_delay":0.05,"interpolation_max_snapshots":4,"interpolation_max_gap":0.25,"interpolation_teleport_distance":128.0})
	return buffer

func pair(buffer: Buffer) -> Dictionary:
	buffer.push(state(1,10.0,0))
	buffer.advance(0.05)
	var newest := state(2,10.05,10)
	buffer.push(newest)
	buffer.advance(0.025)
	return newest

func test_midpoint_smooths_positions_without_delaying_authoritative_values() -> void:
	var buffer: Buffer = new_buffer()
	var newest := pair(buffer)
	newest.players[1].hp = 5
	newest.phase = "reward"
	var render: Dictionary = buffer.sample(newest)
	check(is_equal_approx(float(render.players[1].x),5.0),"player gets a sub-snapshot midpoint rather than a20Hz step")
	check(is_equal_approx(float(render.enemies[0].x),25.0),"enemy uses its stable ID for midpoint interpolation")
	check(is_equal_approx(float(render.bullets[0].x),45.0),"bullet uses its stable ID for midpoint interpolation")
	check(render.players[1].hp == 5 and render.phase == "reward" and render.players[1].perks == ["heart"],"HP, perks and phase remain the latest authoritative values")
	check(render.seq == newest.seq and int(render.get("local_visual_tick",-1)) >= 0,"render keeps sequence and supplies a presentation-only visual tick")
	var again: Dictionary = buffer.sample(newest)
	check(again == render,"camera and View sampling the same frame get the same state")
	buffer.advance(0.01)
	var next: Dictionary = buffer.sample(newest)
	check(float(next.players[1].x) > float(render.players[1].x) and next.local_visual_tick != render.get("local_visual_tick",-1),"a later render frame advances between unchanged network packets")

func test_geometry_and_inputs_remain_immutable_and_shared() -> void:
	var buffer: Buffer = new_buffer()
	var newest := pair(buffer)
	var before := var_to_bytes(newest)
	var render: Dictionary = buffer.sample(newest)
	check(var_to_bytes(newest) == before,"rendering never edits the authoritative snapshot")
	check(is_same(render.room_layout,newest.room_layout),"the full immutable room geometry stays shared")
	check(not is_same(render.players[1],newest.players[1]),"interpolated actor positions use a distinct small dictionary")
	check(render.players[1].get("max_hp") == newest.players[1].get("max_hp"),"non-position metadata remains unchanged")

func test_jitter_and_stale_packets_do_not_rewind_presentation() -> void:
	var buffer: Buffer = new_buffer()
	var newest := pair(buffer)
	var prior_x := float(buffer.sample(newest).players[1].x)
	check(not buffer.push(state(1,10.0,-100)),"out-of-order sequence is dropped")
	check(not buffer.push(state(2,10.06,-100)),"duplicate sequence is dropped")
	check(not buffer.push(state(3,10.04,-100)),"backwards server clock is dropped")
	buffer.advance(0.025)
	var late := state(4,10.10,20)
	buffer.push(late)
	var render: Dictionary = buffer.sample(late)
	check(float(render.players[1].x) >= prior_x,"late packet arrival cannot move the presentation timeline backwards")
	check(float(render.players[1].x) < 20.0,"late packet still has buffered movement rather than an immediate step")

func test_removed_dead_revived_and_new_entities_do_not_ghost() -> void:
	var buffer: Buffer = new_buffer()
	var newest := pair(buffer)
	newest.players[2] = {"x":99.0,"y":40.0,"hp":8}
	newest.enemies = []
	newest.bullets.append({"x":123.0,"y":1.0,"owner":1})
	var render: Dictionary = buffer.sample(newest)
	check(render.players[2].x == 99.0,"new player is shown at its actual spawn")
	check(render.enemies.is_empty(),"removed enemies are never resurrected from history")
	check(render.bullets[1].x == 123.0,"ID-less projectile is never paired by array index")
	buffer = new_buffer()
	newest = pair(buffer)
	newest.players[1].hp = 0
	newest.enemies[0].hp = 0
	newest.enemies[0].dying_p = 0.4
	render = buffer.sample(newest)
	check(render.players[1].x == newest.players[1].x and render.enemies[0].x == newest.enemies[0].x,"dead and dying actors stay at their authoritative death positions")
	buffer = new_buffer()
	var dead := state(1,10.0,0)
	dead.players[1].hp = 0
	buffer.push(dead)
	buffer.advance(0.05)
	newest = state(2,10.05,10)
	buffer.push(newest)
	buffer.advance(0.025)
	render = buffer.sample(newest)
	check(render.players[1].x == 10.0,"revived player does not slide from its former dead position")

func test_teleports_and_large_packet_gaps_snap_instead_of_crossing_the_map() -> void:
	var buffer: Buffer = new_buffer()
	buffer.push(state(1,10.0,0))
	buffer.advance(0.05)
	var newest := state(2,10.05,1000)
	buffer.push(newest)
	buffer.advance(0.025)
	check(buffer.sample(newest).players[1].x == 1000.0,"teleport snaps rather than interpolating through intervening walls")
	buffer = new_buffer()
	buffer.push(state(1,10.0,0))
	buffer.advance(0.5)
	newest = state(2,10.5,50)
	buffer.push(newest)
	check(buffer.sample(newest).players[1].x == 50.0,"a long network outage does not create a slow catch-up slide")

func test_fade_room_revision_floor_and_run_changes_cut_history() -> void:
	var buffer: Buffer = new_buffer()
	var newest := pair(buffer)
	check(buffer.sample(newest,true) == newest,"active fade returns the exact room selected by the black-frame fence")
	check(buffer.sample(newest).players[1].x == 10.0,"first frame after a fade starts at the shown room, without replaying old motion")
	for field: String in ["room_layout_revision","floor_index","run_seed","room"]:
		buffer = new_buffer()
		newest = pair(buffer)
		var changed := state(3,10.10,500)
		if field == "room": changed.room_layout.id = "room-b"
		else: changed[field] = 2
		buffer.push(changed)
		check(buffer.buffered_snapshots() == 1 and buffer.sample(changed).players[1].x == 500.0,"%s change cuts all earlier movement" % field)
	buffer = new_buffer()
	newest = pair(buffer)
	var old_shown := newest
	var target := state(3,10.10,500)
	target.room_layout.id = "room-b"
	buffer.push(target)
	check(buffer.sample(old_shown,true).room_layout.id == "room-a","new room data cannot leak ahead of the transition's old-room display")

func test_latency_change_rebuffers_without_replaying_old_motion() -> void:
	var buffer: Buffer = new_buffer()
	var newest := pair(buffer)
	buffer.advance(0.5)
	newest = state(3,10.55,110)
	buffer.push(newest)
	var after_gap: float = float(buffer.sample(newest).players[1].x)
	buffer.advance(0.05)
	newest = state(4,10.60,120)
	buffer.push(newest)
	check(float(buffer.sample(newest).players[1].x) >= after_gap,"first ordinary packets after an outage cannot replay older motion backwards")
	buffer = new_buffer()
	newest = pair(buffer)
	buffer.advance(0.25)
	newest = state(3,10.10,20)
	buffer.push(newest)
	check(buffer.buffered_snapshots() == 1,"a sustained latency increase discards the obsolete clock estimate")
	buffer.advance(0.05)
	newest = state(4,10.15,30)
	buffer.push(newest)
	buffer.advance(0.025)
	check(is_equal_approx(float(buffer.sample(newest).players[1].x),25.0),"smoothing resumes after latency settles instead of remaining20Hz forever")

func test_identity_reuse_and_future_teleport_cut_delayed_history() -> void:
	var buffer: Buffer = new_buffer()
	buffer.configure({"interpolation_delay":0.1,"interpolation_max_snapshots":8})
	buffer.push(state(1,10.0,0))
	buffer.advance(0.05)
	buffer.push(state(2,10.05,10))
	buffer.advance(0.05)
	var absent := state(3,10.10,20)
	absent.enemies = []
	absent.bullets = []
	absent.players[1].hp = 0
	buffer.push(absent)
	buffer.advance(0.05)
	var newest := state(4,10.15,30)
	buffer.push(newest)
	var render: Dictionary = buffer.sample(newest)
	check(render.players[1].x == 30.0 and render.enemies[0].x == 50.0 and render.bullets[0].x == 70.0,"ID reuse/revival after a disappearance cannot borrow older delayed positions")
	buffer.advance(0.05)
	newest = state(5,10.20,1000)
	buffer.push(newest)
	check(buffer.sample(newest).players[1].x == 1000.0,"teleport invalidates all delayed brackets, including those preceding the teleport")

func test_equal_timestamps_replace_and_prior_room_packets_remain_stale() -> void:
	var buffer: Buffer = new_buffer()
	var newest := pair(buffer)
	newest = state(3,10.05,12)
	check(buffer.push(newest) and buffer.buffered_snapshots() == 2,"extra reliable snapshot in the same server instant replaces the zero-duration sample")
	check(is_equal_approx(float(buffer.sample(newest).players[1].x),6.0),"equal timestamp replacement still has a finite valid interpolation bracket")
	var next_room := state(4,10.10,500)
	next_room.room_layout.id = "room-b"
	buffer.push(next_room)
	check(not buffer.push(state(3,10.05,12)) and buffer.buffered_snapshots() == 1,"prior-room packets remain stale after the room buffer is cut")

func test_missing_packets_hold_latest_without_extrapolation() -> void:
	var buffer: Buffer = new_buffer()
	var newest := pair(buffer)
	buffer.advance(2.0)
	check(buffer.sample(newest).players[1].x == 10.0,"packet loss holds the last authoritative endpoint instead of extrapolating indefinitely")
	buffer.reset()
	check(buffer.buffered_snapshots() == 0 and buffer.sample(newest) == newest,"disconnect reset has no previous-session movement")

func test_blocked_corner_pair_snaps_once_and_clear_following_pair_smooths() -> void:
	var buffer: Buffer = new_buffer()
	var calls: Array[int] = [0]
	var valid_arguments: Array[bool] = [false]
	buffer.set_motion_validator(func(from: Vector2,to: Vector2,entity: Dictionary,layout: Dictionary) -> bool:
		calls[0] += 1
		valid_arguments[0] = entity.get("radius",-1) == 12 and layout.has("obstacles")
		var values: Array = layout.get("obstacles",[[0,0,0,0]])[0]
		var clearance := Rect2(values[0],values[1],values[2],values[3]).grow(float(entity.get("radius",0)))
		return not clearance.has_point(from.lerp(to,0.5)))
	var first := state(1,10.0,18)
	first.players[1].y = 28.0
	first.players[1].radius = 12
	first.enemies = []
	first.bullets = []
	first.room_layout.obstacles = [[32.0,32.0,32.0,32.0]]
	buffer.push(first)
	buffer.advance(0.05)
	var newest := first.duplicate(true)
	newest.seq = 2
	newest.server_time = 10.05
	newest.players[1].x = 28.0
	newest.players[1].y = 18.0
	var clearance := Rect2(32,32,32,32).grow(12)
	check(not clearance.has_point(Vector2(18,28)) and not clearance.has_point(Vector2(28,18)) and clearance.has_point(Vector2(23,23)),"corner fixture has two safe endpoints but a blocked linear midpoint")
	buffer.push(newest)
	buffer.advance(0.025)
	var render: Dictionary = buffer.sample(newest)
	check(render.players[1].x == 28.0 and render.players[1].y == 18.0,"a clearance-blocked chord snaps to its latest authorized endpoint")
	check(calls[0] == 1 and valid_arguments[0],"motion predicate gets actor radius/current layout exactly once for the moving pair")
	for index in range(4):
		buffer.sample(newest)
		buffer.advance(0.001)
	check(calls[0] == 1,"camera/render frames never repeat pair collision work")
	buffer.advance(0.021)
	newest = newest.duplicate(true)
	newest.seq = 3
	newest.server_time = 10.10
	newest.players[1].x = 38.0
	buffer.push(newest)
	buffer.advance(0.025)
	render = buffer.sample(newest)
	check(is_equal_approx(float(render.players[1].x),33.0) and render.players[1].y == 18.0,"after the corner cut, a clear following pair resumes interpolation")
	check(calls[0] == 2,"each ordinary moving pair adds one validation, with none for initial spawn")

func test_validator_change_cuts_history_without_readmitting_old_packets() -> void:
	var buffer: Buffer = new_buffer()
	var newest := pair(buffer)
	buffer.set_motion_validator(func(_from: Vector2,_to: Vector2,_entity: Dictionary,_layout: Dictionary) -> bool: return true)
	check(buffer.buffered_snapshots() == 0 and buffer.sample(newest) == newest,"changing the local predicate cuts all previously unchecked movement")
	check(not buffer.push(state(1,10.0,0)),"validator replacement does not reset the accepted sequence boundary")

func test_bounded_history_and_invalid_input_are_safe() -> void:
	var buffer: Buffer = new_buffer()
	for index in range(20):
		buffer.advance(0.05)
		buffer.push(state(index+1,10+index*0.05,float(index)))
	check(buffer.buffered_snapshots() == 4,"history never exceeds configured snapshot bound")
	check(not buffer.push(state(30,NAN,3)),"non-finite server time is rejected")
	check(not buffer.push({"seq":31,"server_time":11.0}),"layout-free snapshot is not buffered as a playable room")
	var newest := state(20,10.95,19)
	var previous: Dictionary = buffer.sample(newest)
	buffer.advance(NAN)
	buffer.advance(-1)
	check(buffer.sample(newest) == previous,"invalid frame delta cannot corrupt render time")
	check(not buffer.configure({"interpolation_delay":-1}),"invalid presentation settings are rejected")
