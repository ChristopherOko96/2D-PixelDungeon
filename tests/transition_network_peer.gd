extends SceneTree
## Real ENet peer: ordinary bots win two floors; a late-priority observer checks
## the displayed-room/fade contract after Game._process updated presentation.

class PresentationProbe extends Node:
	var visit: Callable
	func _process(_delta: float) -> void:
		if visit.is_valid(): visit.call()

var game
var failed := false
var failures: Array[String] = []
var sounds: Dictionary = {}
var kinds: Array[String] = []
var black_frames: Dictionary = {}
var swaps: Dictionary = {}
var sequence_progress: Dictionary = {}
var last_sequences: Dictionary = {}
var last_displayed := ""
var displayed_rooms: Array[String] = []
var observed_audio := 0
var observed_frames := 0

func fail(message: String) -> void:
	if message in failures: return
	failed = true
	failures.append(message)
	printerr("TRANSITION_NET_FAIL: ",message)

func _initialize() -> void:
	_run.call_deferred()

func _on_sound(kind: String) -> void:
	var token: int = game.transition_view.current_token
	sounds[token] = int(sounds.get(token,0))+1
	kinds.append(kind)
	if sounds[token] != 1: fail("sound repeated for token%d" % token)
	if game.view._sfx == null or game.view._sfx.last_effect != kind:
		fail("transition%d requested %s but its audio player did not receive it" % [token,kind])
	elif int(game.view._sfx.play_count) <= observed_audio:
		fail("audio play counter did not advance for token%d" % token)
	else:
		observed_audio = int(game.view._sfx.play_count)
	print("FADE_SOUND token=%d kind=%s count=%d" % [token,kind,sounds[token]])

func _observe_frame() -> void:
	observed_frames += 1
	if paused: fail("SceneTree was globally paused")
	var presenter = game.transition_view
	var snapshot: Dictionary = presenter.display_state()
	var room_id: String = str(snapshot.get("room_layout",{}).get("id",""))
	var token: int = presenter.current_token
	var opacity: float = presenter.opacity
	if not is_finite(opacity) or opacity < 0.0 or opacity > 1.0: fail("opacity left its finite0..1 range")
	if room_id.is_empty():
		last_displayed = ""
		return
	if room_id != last_displayed:
		if not last_displayed.is_empty():
			if opacity < 1.0: fail("display changed %s to %s before full black" % [last_displayed,room_id])
			if int(black_frames.get(token,0)) < 1: fail("room swap had no prior black frame for token%d" % token)
			swaps[token] = int(swaps.get(token,0))+1
			if swaps[token] != 1: fail("token%d exposed multiple room swaps" % token)
			print("FADE_SWAP token=%d black_before=%d from=%s to=%s opacity=%.3f" % [token,black_frames.get(token,0),last_displayed,room_id,opacity])
		last_displayed = room_id
		if room_id not in displayed_rooms: displayed_rooms.append(room_id)
	if token >= 0 and presenter.is_active():
		if opacity >= 1.0: black_frames[token] = int(black_frames.get(token,0))+1
		var sequence: int = game.received_sequence
		if last_sequences.has(token) and sequence > int(last_sequences[token]):
			sequence_progress[token] = true
		last_sequences[token] = sequence

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var host := "--test-host" in args
	var port_index := args.find("--test-port")
	if port_index < 0 or port_index+1 >= args.size():
		fail("--test-port is required")
		quit(1)
		return
	game = load("res://src/game.gd").new()
	root.add_child(game)
	await process_frame
	var probe := PresentationProbe.new()
	probe.process_priority = 100
	probe.visit = _observe_frame
	root.add_child(probe)
	game.transition_view.sound_requested.connect(_on_sound)
	game.session_bind_ip = "127.0.0.1"
	game.port_input.text = args[port_index+1]
	game.requested_seed = 24680
	game.smoke_floor_limit = 2
	game.smoke_role = "host" if host else "client"
	if host: game._host_session()
	else: game._join_session()
	var started := Time.get_ticks_msec()
	var completed_at := -1
	while Time.get_ticks_msec()-started < 65000:
		await process_frame
		if failed: break
		if host and game.phase == "lobby" and game.players.size() == 2: game._begin_run()
		if game.phase == "dead":
			fail("ordinary bot combat ended in a team wipe")
			break
		var complete: bool = game.phase == "explore" and int(game.state.get("floor_index",0)) == 2 and game.room == 3 and not game.is_transitioning()
		if complete and completed_at < 0: completed_at = Time.get_ticks_msec()
		if completed_at >= 0 and Time.get_ticks_msec()-completed_at >= (1500 if host else 500): break
	probe.set_process(false)
	if completed_at < 0: fail("two floors did not finish freely exploring before the65s deadline")
	if kinds != ["door","door","stairs","door","door"]: fail("expected door,door,stairs,door,door; received%s" % str(kinds))
	if sounds.size() != 5 or black_frames.size() != 5 or swaps.size() != 5 or displayed_rooms.size() != 6:
		fail("six displayed rooms must have five sounded and black-covered swaps")
	for token: Variant in sounds:
		if int(sounds[token]) != 1 or int(black_frames.get(token,0)) < 1 or int(swaps.get(token,0)) != 1:
			fail("token%d lacks an exactly-once sound/swap or a black frame" % token)
		if not sequence_progress.get(token,false): fail("snapshots did not progress during token%d" % token)
	print("FADE_PEER role=%s transitions=%d black_tokens=%d swaps=%d rooms=%d sounds=%d stairs=%d frames=%d explored=%s result=%s" % ["host" if host else "client",sounds.size(),black_frames.size(),swaps.size(),displayed_rooms.size(),kinds.size(),kinds.count("stairs"),observed_frames,completed_at>=0,"FAIL" if failed else "PASS"])
	game._leave_session()
	probe.queue_free()
	game.queue_free()
	await process_frame
	quit(1 if failed else 0)
