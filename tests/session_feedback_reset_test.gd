extends SceneTree
## A fixed seed may reuse room IDs; session revisions still clear old feedback.
const Feedback = preload("res://src/vfx/feedback.gd")
var checked := 0
var failures := 0

func _initialize() -> void:
	var feedback := Feedback.new()
	var state := {"room_layout":{"id":"same-seeded-room"},"room_layout_revision":1,"run_seed":42,"floor_index":1,"players":{},"enemies":[]}
	feedback.observe(state,1)
	feedback.particles.stain(Vector2.ONE,Color.RED,8)
	feedback.observe(state,1)
	check(feedback.particles._stains.size() == 1,"ordinary snapshots preserve this room's stains")
	feedback.shake = 1.0
	feedback.hitstop = 0.2
	state.room_layout_revision = 2
	feedback.observe(state,1)
	check(feedback.particles._stains.is_empty() and feedback.shake == 0 and feedback.hitstop == 0,"fixed-seed restart clears previous-room feedback by revision")
	feedback.particles.stain(Vector2.ONE,Color.RED,8)
	state.floor_index = 2
	feedback.observe(state,1)
	check(feedback.particles._stains.is_empty(),"floor epoch cannot retain previous-floor stains")
	print("SESSION_FEEDBACK checked=%d failures=%d" % [checked,failures])
	quit(0 if failures == 0 else 1)

func check(value: bool, message: String) -> void:
	checked += 1
	if not value:
		failures += 1
		printerr("FEEDBACK_RESET_FAIL ",message)
