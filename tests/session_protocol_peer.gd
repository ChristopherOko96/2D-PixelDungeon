extends SceneTree
## Real-process admission probe; fixtures alter only the advertised identity.
const Game = preload("res://src/game.gd")
class FixtureGame extends Game:
	var fixture_mode := "valid"
	func _build_session_identity() -> Dictionary:
		var identity := super._build_session_identity()
		if fixture_mode == "protocol": identity.protocol += 1
		elif fixture_mode == "content": identity.content = "a".repeat(64)
		return identity
	func _connected() -> void:
		if fixture_mode == "malformed": _session_hello.rpc_id(1,"{bad".to_utf8_buffer())
		elif fixture_mode != "silent": super._connected()
	func _poll_session_admission() -> void:
		# A noncompliant client does not police itself: exercise the host deadline.
		if fixture_mode != "silent": super._poll_session_admission()

var game: FixtureGame
var mode := "valid"
var port := 18992
var result_path := ""
var duration := 8.0

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	for index in range(args.size()-1):
		match args[index]:
			"--protocol-mode": mode = args[index+1]
			"--protocol-port": port = int(args[index+1])
			"--protocol-result": result_path = args[index+1]
	_run.call_deferred()

func _run() -> void:
	if mode == "host": duration = 20.0
	game = FixtureGame.new()
	game.fixture_mode = mode
	game.name = "Main"
	root.add_child(game)
	current_scene = game
	game.port_input.text = str(port)
	game.balance.network.admission_timeout = 2.0
	if mode == "host":
		game.session_bind_ip = "127.0.0.1"
		game._host_session()
	else:
		game.address_input.text = "127.0.0.1"
		game._join_session()
	var started := Time.get_ticks_msec()
	var max_players := game.players.size()
	var max_pending := 0
	var unauthorized_member := false
	var passed := false
	while Time.get_ticks_msec()-started < duration*1000:
		await process_frame
		max_players = maxi(max_players,game.players.size())
		max_pending = maxi(max_pending,game._pending_hello.size())
		for id: int in game.players:
			if id != 1 and not game._admitted_peers.has(id): unauthorized_member = true
		if mode == "valid" and game._client_admitted and game.seen_snapshot:
			passed = game.state.players.has(game.multiplayer.get_unique_id())
			break
		if mode in ["protocol","content","silent","malformed"] and not game.active:
			passed = not game._client_admitted and not game.seen_snapshot and ("abgelehnt" in game.status_message if mode != "silent" else "zu lange" in game.status_message)
			break
	if mode == "host": passed = max_players == 2 and max_pending >= 1 and not unauthorized_member
	var report := {"mode":mode,"passed":passed,"max_players":max_players,"max_pending":max_pending,"unauthorized_member":unauthorized_member,"client_admitted":game._client_admitted,"seen_snapshot":game.seen_snapshot,"status":game.status_message}
	if not result_path.is_empty():
		var file := FileAccess.open(result_path,FileAccess.WRITE)
		file.store_string(JSON.stringify(report,"\t",true)+"\n")
		file.close()
	print("PROTOCOL_PEER ",JSON.stringify(report))
	game._leave_session()
	quit(0 if passed else 1)
