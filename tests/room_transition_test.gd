extends SceneTree
## Presentation-only transition state; no game, files, audio device or peers.
var checked := 0
var failures: Array[String] = []

func check(condition: bool, description: String) -> void:
	checked += 1
	if not condition:
		failures.append(description)
		printerr("ROOM_TRANSITION_FAIL: ",description)

func state(room_id: String, token: int = -1, kind: String = "door", from_id: String = "", elapsed: float = 0.0) -> Dictionary:
	var result := {"phase":"explore","room_layout":{"id":room_id},"players":{1:{"x":80,"y":100}}}
	if token >= 0: result.transition = {"token":token,"kind":kind,"from_id":from_id,"elapsed":elapsed}
	return result

func _initialize() -> void:
	var path := "res://src/room_transition.gd"
	check(FileAccess.file_exists(path),"transition presenter exists")
	if not FileAccess.file_exists(path):
		finish()
		return
	var fade = load(path).new()
	var sounds: Array[String] = []
	fade.sound_requested.connect(func(kind: String): sounds.append(kind))
	check(fade.configure({"fade_out":0.22,"black_hold":0.08,"fade_in":0.22}),"external transition timings are accepted")
	fade.apply_state(state("a"))
	check(not fade.is_active() and fade.opacity == 0 and fade.display_state().room_layout.id == "a","initial room appears without a fake transition")
	fade.apply_state(state("a",1,"door","a"))
	check(fade.is_active() and fade.opacity == 0 and sounds == ["door"],"a new door token starts once and requests its sound")
	fade.apply_state(state("a",1,"door","a",0.1))
	check(sounds.size() == 1,"duplicate transition snapshots do not replay sound")
	fade.update(0.11)
	check(fade.opacity > 0 and fade.opacity < 1 and fade.display_state().room_layout.id == "a","fade-out still shows the old room")
	fade.apply_state(state("b",1,"door","a",0.24))
	check(fade.display_state().room_layout.id == "a","an early target snapshot cannot expose the next room")
	fade.update(0.11)
	check(fade.opacity == 1 and fade.display_state().room_layout.id == "a","the old room reaches a fully black frame before swapping")
	fade.update(0.08)
	check(fade.opacity == 1 and fade.display_state().room_layout.id == "b","the target is swapped only under full black")
	fade.update(0.11)
	check(fade.opacity > 0 and fade.opacity < 1 and fade.display_state().room_layout.id == "b","fade-in reveals only the new room")
	fade.update(0.11)
	check(not fade.is_active() and fade.opacity == 0,"a complete transition releases the overlay")
	fade.apply_state(state("b",1,"door","a",0.52))
	check(not fade.is_active() and sounds.size() == 1,"a completed token is never restarted")
	fade.apply_state(state("a",1,"door","a",0.0))
	check(fade.display_state().room_layout.id == "b","stale metadata for the completed source room is ignored")
	# First observed packet arrives after the host already changed rooms.
	fade.apply_state(state("c",2,"stairs","b",0.48))
	check(fade.display_state().room_layout.id == "b" and sounds == ["door","stairs"],"a late stairs packet still begins from the currently shown room")
	fade.update(0.6)
	check(fade.opacity == 1 and fade.display_state().room_layout.id == "b","a large frame step cannot skip the black source frame")
	fade.update(0.08)
	check(fade.opacity == 1 and fade.display_state().room_layout.id == "c","late target data is buffered through black")
	fade.update(0.22)
	check(not fade.is_active() and fade.display_state().room_layout.id == "c","late stairs presentation finishes cleanly")
	# A missing target packet holds black, including after metadata ended.
	fade.apply_state(state("c",3,"door","c"))
	fade.update(0.22)
	fade.update(2.0)
	check(fade.opacity == 1 and fade.is_active() and fade.display_state().room_layout.id == "c","black is held while waiting for target geometry")
	var target := state("d")
	fade.apply_state(target)
	target.room_layout.id = "mutated"
	fade.update(0.0)
	check(fade.opacity == 1 and fade.display_state().room_layout.id == "d","metadata-free target packets are copied and swapped under black")
	fade.update(0.22)
	check(not fade.is_active() and sounds.size() == 3,"network recovery needs no second sound")
	fade.apply_state(state("d",4,"door","d"))
	fade.update(NAN)
	check(is_finite(fade.opacity) and fade.opacity == 0,"invalid frame delta cannot corrupt opacity")
	check(not fade.configure({"fade_out":-1,"black_hold":0.08,"fade_in":0.22}),"invalid timings are rejected without corrupting configuration")
	fade.reset()
	check(not fade.is_active() and fade.opacity == 0 and fade.display_state().is_empty(),"reset clears presentation, input shield and buffered rooms")
	fade.apply_state(state("a",1,"door","a"))
	fade.update(0.22)
	check(fade.opacity == 1,"a fresh session can reuse token numbers")
	fade.apply_state({"phase":"lobby","room_layout":{}})
	check(not fade.is_active() and fade.opacity == 0,"leaving the run cancels an unfinished fade")
	fade.apply_state(state("a",9,"unknown","a"))
	check(not fade.is_active() and sounds.size() == 5,"unsupported transition kinds never request audio")
	# A very late client can observe the next transition before its old fade ends.
	fade.apply_state(state("a",10,"door","a"))
	fade.update(0.11)
	var previous_opacity: float = fade.opacity
	fade.apply_state(state("c",11,"stairs","b",0.4))
	check(fade.opacity >= previous_opacity and fade.display_state().room_layout.id == "a","a superseding token cannot flash the old room back into view")
	fade.update(0.22)
	check(fade.opacity == 1 and fade.display_state().room_layout.id == "a","superseded presentation still covers its shown source frame")
	fade.update(0.08)
	check(fade.opacity == 1 and fade.display_state().room_layout.id == "c" and sounds.size() == 7,"the newest target swaps under black with one sound per token")
	fade.free()
	finish()

func finish() -> void:
	print("ROOM_TRANSITION checked=%d failures=%d" % [checked,failures.size()])
	quit(0 if failures.is_empty() else 1)
