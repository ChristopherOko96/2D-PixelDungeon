extends SceneTree
## Recorded sound effects (assets/data/audio_sfx.json, src/vfx/sfx.gd) and
## which game event plays which sound (src/vfx/feedback.gd): every table entry
## has variants, plays never repeat the same variant twice in a row, fast
## hits are throttled, and each snapshot change maps to its own sound once.

const Sfx = preload("res://src/vfx/sfx.gd")
const Feedback = preload("res://src/vfx/feedback.gd")
var checked := 0
var failures: Array[String] = []


class FakeSfx extends Node:
	## Records every play; knows the table's events and materials.
	var played: Array[String] = []
	var known: Dictionary = {}
	var rig_materials: Dictionary = {}
	func has_effect(name: String) -> bool:
		return known.has(name)
	func play(name: String, _spread: float = 0.0) -> void:
		played.append(name)


func check(condition: bool, description: String) -> void:
	checked += 1
	if not condition:
		failures.append(description)
		printerr("AUDIO_SFX_FAIL: ", description)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var table: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/audio_sfx.json"))
	# Arrange: the real sound player.
	var sfx = Sfx.new()
	root.add_child(sfx)
	await process_frame
	for name: String in table.events:
		var wanted := int(table.events[name].get("variants", 1))
		check(sfx.variant_count(name) == wanted, "%s loads all %d recorded variants (%d)" % [name, wanted, sfx.variant_count(name)])
	check(sfx.has_effect("windup") and sfx.variant_count("windup") == 0, "synthesized sounds stay as the fallback")
	var stream: AudioStreamWAV = sfx.effect_stream("door")
	check(stream != null and stream.mix_rate >= 44100 and not stream.stereo, "door is a recorded mono stream")
	# Act/assert: no variant twice in a row.
	var repeats := 0
	var previous := -1
	for i in range(30):
		sfx.play("step")
		var current := int(sfx._last_variant.get("step", -1))
		if current == previous: repeats += 1
		previous = current
	check(repeats == 0, "steps never repeat the same variant twice in a row")
	# Throttle: two bone hits within min_interval sound once.
	var count: int = sfx.play_count
	sfx.play("hit_bone")
	sfx.play("hit_bone")
	check(sfx.play_count == count + 1, "a second bone hit inside 40 ms is skipped")
	sfx.queue_free()

	# Arrange: feedback with a recording sound player.
	var fake := FakeSfx.new()
	root.add_child(fake)
	for name: String in table.events: fake.known[name] = true
	for name: String in ["shoot", "enemy_shoot", "windup", "hit", "boss_hit", "kill", "boss_kill", "hurt", "door", "stairs"]: fake.known[name] = true
	fake.rig_materials = table.rig_materials
	var feedback = Feedback.new()
	feedback.sfx = fake
	var room := {"id": "audio-room", "tile_size": 32}
	var skeleton := {"id": 1, "kind": "skeleton", "rig": "skeleton", "x": 100, "y": 100, "hits": 0, "attacks": 0, "attack": "", "attack_kind": "", "part_breaks": 0, "dying_p": -1.0}
	var zombie := {"id": 2, "kind": "tiny_zombie", "rig": "tiny_zombie", "x": 160, "y": 100, "hits": 0, "attacks": 0, "attack": "", "dying_p": -1.0}
	var hero := {"x": 50, "y": 50, "shots": 0, "swings": 0, "hurts": 0, "class_id": "archer", "moving": false, "hp": 8, "last_perk": ""}
	var snapshot := {"room_layout": room, "phase": "combat", "enemies": [skeleton, zombie], "players": {1: hero}}
	feedback.observe(snapshot, 1)
	check(fake.played == ["doors_lock"], "entering a fight locks the doors (%s)" % str(fake.played))
	fake.played.clear()
	skeleton.hits = 1
	zombie.hits = 1
	feedback.observe(snapshot, 1)
	check(fake.played == ["hit_bone", "hit_flesh"], "skeletons rattle, zombies thud (%s)" % str(fake.played))
	fake.played.clear()
	skeleton.part_breaks = 1
	feedback.observe(snapshot, 1)
	check(fake.played == ["break_bone"], "a lost part snaps like bone")
	fake.played.clear()
	skeleton.dying_p = 0.0
	feedback.observe(snapshot, 1)
	check(fake.played == ["kill_bone"], "a destroyed skeleton crumbles")
	fake.played.clear()
	hero.shots = 1
	feedback.observe(snapshot, 1)
	check(fake.played == ["shoot_arrow"], "the archer's shot is a bow string")
	hero.class_id = "mage"
	hero.shots = 2
	feedback.observe(snapshot, 1)
	check(fake.played[-1] == "shoot_magic", "the mage's shot is a magic orb")
	fake.played.clear()
	# Let the kill's hitstop pass; footsteps pause during it like everything else.
	feedback.update(0.5)
	fake.played.clear()
	hero.moving = true
	feedback.observe(snapshot, 1)
	feedback.update(0.06)
	feedback.update(0.31)
	check(fake.played.count("step") == 2, "walking plays footsteps every 0.3 s (%s)" % str(fake.played))
	hero.moving = false
	feedback.observe(snapshot, 1)
	fake.played.clear()
	feedback.update(1.0)
	check(fake.played.is_empty(), "standing still is silent")
	hero.last_perk = "quick"
	feedback.observe(snapshot, 1)
	check(fake.played == ["perk"], "a new perk chimes")
	fake.played.clear()

	# The Leerenrufer: one sting on arrival, beam telegraph and fire, then defeat.
	var boss := {"id": 9, "kind": "boss", "boss": true, "rig": "void", "x": 300, "y": 200, "hits": 0, "attacks": 0, "attack": "", "attack_kind": "", "dying_p": -1.0}
	snapshot.enemies = [boss]
	feedback.observe(snapshot, 1)
	feedback.observe(snapshot, 1)
	check(fake.played == ["boss_intro"], "the boss announces itself once per room")
	fake.played.clear()
	boss.attack = "windup"
	boss.attack_kind = "beam"
	feedback.observe(snapshot, 1)
	boss.attack = "active"
	boss.attacks = 1
	feedback.observe(snapshot, 1)
	check(fake.played == ["windup_beam", "attack_beam"], "the beam charges, then fires (%s)" % str(fake.played))
	fake.played.clear()
	boss.dying_p = 0.0
	feedback.observe(snapshot, 1)
	check(fake.played == ["boss_kill", "boss_defeated"], "the Leerenrufer's death ends with the victory jingle")
	fake.played.clear()

	# Bombers: the fuse has its sound; a burst plays once from its fx event; shot down it pops.
	var bomber := {"id": 20, "kind": "void_bomber", "rig": "bomber", "x": 200, "y": 200, "hits": 0, "attacks": 0, "attack": "", "attack_kind": "", "dying_p": -1.0}
	snapshot.enemies = [bomber]
	feedback.observe(snapshot, 1)
	bomber.attack = "windup"
	bomber.attack_kind = "fuse"
	feedback.observe(snapshot, 1)
	check(fake.played == ["windup_fuse"], "a lit fuse sizzles")
	fake.played.clear()
	bomber.attacks = 1
	bomber.dying_p = 0.0
	bomber.exploded = true
	snapshot.fx_events = [{"id": 5, "kind": "void_burst", "x": 200, "y": 200, "r": 72}]
	feedback.observe(snapshot, 1)
	feedback.observe(snapshot, 1)
	check(fake.played == ["void_burst"], "the burst sounds once, the fuse release adds nothing (%s)" % str(fake.played))
	fake.played.clear()
	var shot := {"id": 21, "kind": "void_bomber", "rig": "bomber", "x": 240, "y": 200, "hits": 0, "attacks": 0, "attack": "", "attack_kind": "", "dying_p": -1.0}
	snapshot.enemies = [shot]
	snapshot.fx_events = []
	feedback.observe(snapshot, 1)
	shot.dying_p = 0.0
	feedback.observe(snapshot, 1)
	check(fake.played == ["bomber_pop"], "a bomber shot down only pops")
	fake.played.clear()

	# Room flow: cleared and wiped.
	snapshot.enemies = []
	snapshot.phase = "reward"
	feedback.observe(snapshot, 1)
	check(fake.played == ["room_clear"], "a cleared room chimes")
	fake.played.clear()
	snapshot.phase = "dead"
	feedback.observe(snapshot, 1)
	check(fake.played == ["team_wipe"], "a team wipe plays the defeat jingle")
	fake.queue_free()
	await process_frame
	print("AUDIO_SFX checked=%d failures=%d" % [checked, failures.size()])
	quit(1 if failures.size() > 0 else 0)
