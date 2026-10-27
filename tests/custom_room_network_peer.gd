extends SceneTree
## Synthetic geometry transport fixture, not a combat or performance test.
var game
var hosting := false
var started := false
var elapsed := 0.0
var passed := false
var freeform := false
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var args := OS.get_cmdline_user_args()
	hosting = "--host" in args
	freeform = "--freeform" in args
	game = load("res://src/game.gd").new()
	root.add_child(game)
	game.session_bind_ip = "127.0.0.1"
	game.port_input.text = args[args.find("--port")+1]
	if hosting:
		var model = load("res://src/dungeon_editor_model.gd").new(game.dungeon_config)
		for index in range(model.config.templates.size()):
			model.selected = index
			model.template().brazier_spawns = []
			model.template().obstacles_tiles = []
			if freeform: model.template().layout_mode = "freeform"
			model.resize_room(Vector2i(40,24))
			for y in range(2,23):
				for x in range(1,39): model.paint_tile(Vector2i(x,y),"violet_017",(x+y)%4,false,"floor" if freeform else "structure")
			model.paint_tile(Vector2i(32,18),"violet_007",3,true)
			if freeform:
				model.set_authored_door(Vector2i(1,11),"west","items_002",3)
				if not model.template().boss: model.set_authored_door(Vector2i(38,11),"east","items_002",1)
				else: model.template().stairs_spawn = [960,416]
		game.dungeon_config = model.config
		game._host_session()
		game.set_physics_process(false)
		print("CUSTOM_ROOM_HOST_READY")
	else:
		game.address_input.text = "127.0.0.1"
		game._join_session()
func _process(delta: float) -> bool:
	elapsed += delta
	if game == null: return false
	if hosting and game.players.size() == 2:
		if not started:
			started = true
			game.requested_seed = 24680
			game._begin_run()
		game._broadcast_state(true)
	var layout: Dictionary = game.state.get("room_layout",{})
	var expected := 799 if freeform else 798
	if not hosting and not passed and layout.get("painted_tiles",[]).size() == expected:
		var point := Vector2(1040,592)
		var valid: bool = Vector2(layout.world_size[0],layout.world_size[1]) == Vector2(1280,768)
		valid = valid and load("res://src/dungeon/dungeon_generator.gd").segment_blocked(point,point,12,layout)
		valid = valid and layout.painted_tiles[-1].rotation == 3 and layout.painted_tiles[-1].tile == "violet_007"
		if freeform:
			valid = valid and layout.get("layout_mode","") == "freeform" and layout.exits.size() == 1
			valid = valid and game.Dungeon.segment_blocked(Vector2(16,16),Vector2(16,16),12,layout)
			valid = valid and not game.Dungeon.segment_blocked(Vector2(400,400),Vector2(400,400),12,layout)
			valid = valid and layout.exits[0].rect == [1216.0,352.0,32.0,32.0]
		if not valid:
			printerr("CUSTOM_ROOM_NET_FAIL geometry/art mismatch")
			quit(1)
			return false
		passed = true
		print("CUSTOM_ROOM_NET_PASS cells=%d world=1280x768 collision=true rotation=3 peers=2 freeform=%s" % [expected,freeform])
		game._leave_session()
		quit()
	if hosting and started and game.players.size() < 2:
		print("CUSTOM_ROOM_NET_HOST_DONE")
		game._leave_session()
		quit()
	if elapsed > 12:
		printerr("CUSTOM_ROOM_NET_FAIL timeout")
		quit(1)
	return false
