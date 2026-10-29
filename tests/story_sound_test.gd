extends SceneTree
## The crypt's sound standard in the story worlds (src/hero/story_sound.gd,
## src/hero/story_feel.gd, src/hell/hell_game.gd, src/hell/hell_monsters.gd):
## the crypt's feedback.gd plays every combat moment once, in the monster's
## crypt material (hell monsters, Frostgruft enemies and guardians all name
## one); the hell monsters' acts (fired by hell_monsters' release hook), the
## Frostgruft's moves, basic enemies and guardian kits wind up and fire with
## the crypt's attack sounds, regular monsters never with a crypt boss sound;
## the hero's skills play at the hero's mix level; a guardian's landings
## blast, forms roar; room clear, a guardian's fall, defeat, level-up,
## pickups, secret walls, plates and the music follow the crypt. A recording
## sound player stands in for sfx.gd (headless runs never start playback), so
## nothing here depends on audio.

const HellScene = preload("res://src/hell/hell_dungeon.tscn")
const FrostScene = preload("res://src/hell/frost_dungeon.tscn")
const StorySound = preload("res://src/hero/story_sound.gd")
const HeroKit = preload("res://src/hell/hero_kit.gd")
const BossKit = preload("res://src/hell/boss_kit.gd")
const FrostMoves = preload("res://src/hell/frost_moves.gd")
const Sfx = preload("res://src/vfx/sfx.gd")
const AudioMix = preload("res://src/audio/audio_mix.gd")
const DT := 1.0 / 60.0
## The synthesized fallbacks of sfx.gd.
const SYNTH := ["shoot", "swing", "enemy_shoot", "windup", "hit", "boss_hit", "kill", "boss_kill", "hurt", "door", "stairs"]

var checked := 0
var failures: Array[String] = []
var table: Dictionary = {}


class FakeSfx extends Node:
	## Records every play with its category override; knows the table's events and materials.
	var played: Array[String] = []
	var cats: Array[String] = []
	var known: Dictionary = {}
	var rig_materials: Dictionary = {}
	func has_effect(name: String) -> bool:
		return known.has(name)
	func play(name: String, _spread: float = 0.0, category: String = "") -> void:
		played.append(name)
		cats.append(category)
	func reset() -> void:
		played.clear()
		cats.clear()
	func count(name: String) -> int:
		return played.count(name)
	func starting(prefix: String) -> Array:
		return Array(played).filter(func(n: String) -> bool: return n.begins_with(prefix))


func check(condition: bool, description: String) -> void:
	checked += 1
	if not condition:
		failures.append(description)
		printerr("STORY_SOUND_FAIL: ", description)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	table = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/audio_sfx.json"))
	test_every_story_monster_has_a_crypt_material()
	test_every_story_attack_names_a_crypt_sound()
	test_regular_monsters_never_take_a_boss_sound()
	await test_hell_combat_sounds_once_in_crypt_materials()
	await test_hell_acts_wind_up_and_fire()
	await test_hell_acts_sound_when_they_release()
	await test_hell_landings_forms_and_parts()
	await test_hell_world_moments_are_crypt_fx_events()
	await test_hell_room_death_and_music()
	await test_hell_guardian_fall_stings_like_the_crypt()
	await test_frost_enemies_moves_and_kits()
	await test_frost_room_clear_and_music()
	await test_frost_hero_skills_at_hero_level()
	print("STORY_SOUND checked=%d failures=%d" % [checked, failures.size()])
	quit(1 if failures.size() > 0 else 0)


# --- helpers ------------------------------------------------------------------------------

func _open(scene: PackedScene, class_id: String, floor_n := 1) -> Node:
	var game: Node = scene.instantiate()
	game.start_floor = floor_n
	game.class_id = class_id
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.mobs.clear()
	var fake := FakeSfx.new()
	for name: String in table.events:
		fake.known[name] = true
	for name: String in SYNTH:
		fake.known[name] = true
	fake.rig_materials = table.rig_materials
	if game.sfx != null:
		game.sfx.queue_free()
	game.add_child(fake)
	game.sfx = fake
	# no stray hits on the hero while monsters act (each test lowers it where it wants one)
	game.state.inv = 99.0
	game.feel.update(DT)
	fake.reset()
	return game


func _free(game: Node) -> void:
	game.queue_free()
	await process_frame


func _hell_mob(game: Node, id: String, offset: Vector2, boss := false) -> Dictionary:
	var m: Dictionary = game.monsters.spawn(game.state.room, Vector2(game.player.x, game.player.y) + offset, id, boss)
	m.spawn = 0.0
	m.hp = 9999.0
	m.max = 9999.0
	for i in range(m.cds.size()):
		m.cds[i] = 99.0
	return m


func _frost_mob(game: Node, kind: String, offset: Vector2) -> Dictionary:
	game._spawn_mob(game.state.room, Vector2(game.player.x, game.player.y) + offset, kind)
	var m: Dictionary = game.mobs[game.mobs.size() - 1]
	m.spawn = 0.0
	m.hp = 9999.0
	m.max = 9999.0
	m.shoot = 99.0
	return m


func _frames(game: Node, n: int) -> void:
	for i in range(n):
		game.feel.update(DT)


## Starts hell monster `m`'s attack of `kind`; false when it has none.
func _start(game: Node, m: Dictionary, kind: String) -> bool:
	for k in range((m.st.attacks as Array).size()):
		if str(m.st.attacks[k].kind) == kind:
			var to: Vector2 = Vector2(game.player.x, game.player.y) - (m.p as Vector2)
			game.monsters._start_act(m, k, to, maxf(to.length(), 1.0))
			return true
	return false


## Runs one act of hell monster `m` (its attack of `kind`) to its end; returns what played.
func _act(game: Node, m: Dictionary, kind: String) -> Array:
	var fake: FakeSfx = game.sfx
	game.feel.update(DT)
	fake.reset()
	if not _start(game, m, kind):
		return ["missing attack " + kind]
	var t := 0.0
	while m.act != null and t < 8.0:
		game.monsters._run_act(m, DT)
		game.monsters._update_zones(DT)
		game.feel.update(DT)
		t += DT
	for k in range(20):
		game.monsters._update_zones(DT)
		game.feel.update(DT)
	return Array(fake.played)


## Runs one act of `m` and returns [the frame `sound` first plays, the frame
## `shown` (a check of the world) first holds]; -1 when never.
func _release_frames(game: Node, m: Dictionary, kind: String, sound: String, shown: Callable) -> Array:
	var fake: FakeSfx = game.sfx
	game.feel.update(DT)
	fake.reset()
	if not _start(game, m, kind):
		return [-2, -2]
	var heard := -1
	var seen := -1
	var frame := 0
	while m.act != null and frame < 480:
		game.monsters._run_act(m, DT)
		if seen < 0 and shown.call():
			seen = frame
		game.feel.update(DT)
		if heard < 0 and fake.played.has(sound):
			heard = frame
		frame += 1
	_frames(game, 10)
	return [heard, seen]


## Runs one Frostgruft move of `m` (frost_moves.gd) through its windup, release and recovery.
func _move(game: Node, m: Dictionary, move_id: String) -> Array:
	var fake: FakeSfx = game.sfx
	m.mv = {"next": 99.0, "cd": {}, "used": {}, "rage": false, "run": {}}
	game.feel.update(DT)
	fake.reset()
	game.as_source("moves", func() -> void: FrostMoves._begin(game, m, {"move": move_id}))
	var t := 0.0
	while not (m.mv.run as Dictionary).is_empty() and t < 6.0:
		game.as_source("moves", func() -> void: FrostMoves._run(game, m, m.mv.run, DT))
		game.feel.update(DT)
		t += DT
	_frames(game, 5)
	return Array(fake.played)


func _no_synth(played: Array) -> bool:
	return not played.has("windup") and not played.has("enemy_shoot") and not played.has("hit") and not played.has("kill")


## The crypt boss sounds (attack_ and windup_ events of category boss) among
## `played`, the summon (the crypt necromancer's too) aside.
func _boss_sounds(played: Array) -> Array:
	return played.filter(func(n: String) -> bool:
		return (n.begins_with("attack_") or n.begins_with("windup_")) and not n.ends_with("_summon") \
			and str((table.events.get(n, {}) as Dictionary).get("category", "")) == "boss")


func _fight_room(game: Node) -> Dictionary:
	for r: Dictionary in game.W.rooms:
		if str(r.type) != "boss" and str(r.get("drop", "")) == "" and int(r.index) != int(game.state.room):
			return r
	return {}


func _boss_room(game: Node) -> Dictionary:
	for r: Dictionary in game.W.rooms:
		if str(r.type) == "boss":
			return r
	return {}


# --- data ---------------------------------------------------------------------------------

func test_every_story_monster_has_a_crypt_material() -> void:
	var rigs: Dictionary = table.rig_materials
	var events: Dictionary = table.events
	var sounds_ok := func(name: String) -> bool:
		var mat := str(rigs.get(name, ""))
		return mat != "" and events.has("hit_" + mat) and events.has("break_" + mat) and events.has("kill_" + mat)
	var hell: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/hell_monsters.json"))
	var missing: Array = (hell.defs as Dictionary).keys().filter(func(id: String) -> bool: return not sounds_ok.call(id))
	check(missing.is_empty(), "every hell monster sounds in a crypt material with hit, break and kill (%s)" % str(missing))
	var frost: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/frost_theme.json"))
	missing = (frost.mobs as Dictionary).keys().filter(func(kind: String) -> bool: return not sounds_ok.call(kind))
	check(missing.is_empty(), "every Frostgruft enemy sounds in a crypt material (%s)" % str(missing))
	var looks: Array = (frost.bosses as Dictionary).values()
	for kit: Dictionary in (frost.boss_kits as Dictionary).values():
		for ph: Dictionary in kit.phases:
			if ph.has("look"):
				looks.append(ph.look)
	missing = looks.filter(func(look: Dictionary) -> bool: return not sounds_ok.call(StorySound.rig({"kind": "boss", "look": look})))
	check(missing.is_empty(), "every Frostgruft guardian look sounds in a crypt material (%s)" % str(missing))
	check(StorySound.rig({"kind": "boss", "look": {"sprite": "mob_frost_necromancer_f"}}) == "frost_necromancer" and StorySound.rig({"kind": "boss", "look": {"sprite": "boss_golem_p1_f"}}) == "golem",
		"a guardian's look names its rig without prefix and frame suffix")
	check(StorySound.rig({"id": "drache1", "rig": "drache1", "kind": "boss"}) == "drache1" and StorySound.rig({"id": "peingeist"}) == "peingeist" and StorySound.rig({"kind": "ice_slime_m"}) == "ice_slime_m",
		"a real rig first, then the hell id, then the Frostgruft kind")
	if FileAccess.file_exists("res://assets/data/hell_rigs.json"):
		var rig_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/hell_rigs.json"))
		missing = (rig_data.get("rigs", {}) as Dictionary).keys().filter(func(name: String) -> bool: return not sounds_ok.call(name))
		check(missing.is_empty(), "every hell rig sounds in a crypt material (%s)" % str(missing))
	# the crypt's own enemies keep their materials
	check(rigs.skeleton == "bone" and rigs.ice_zombie == "bone" and rigs.tiny_zombie == "flesh" and rigs.void == "void" and rigs.bomber == "void", "the crypt's rig materials are unchanged")
	check(events.has("kill_void") and str(events.kill_void.category) == "enemy" and not events.has("idle_void"), "void beings die with a recorded sound and stay silent at idle like the crypt's")


func test_every_story_attack_names_a_crypt_sound() -> void:
	var map: Dictionary = table.story_attacks
	var events: Dictionary = table.events
	var bad: Array = []
	for block: Dictionary in [map, map.mob]:
		for group: String in ["hell", "moves", "behaviors", "kits", "any"]:
			for name: String in block.get(group, {}):
				var kind := str(block[group][name])
				if kind != "" and not events.has("attack_" + kind):
					bad.append("%s.%s" % [group, name])
		for group: String in block.get("many", {}):
			for name: String in block.many[group]:
				if not events.has("attack_" + str(block.many[group][name])):
					bad.append("many.%s.%s" % [group, name])
	for kind: String in (map.move_fx as Dictionary).values():
		if kind == "":
			bad.append("move_fx")
	check(bad.is_empty(), "every story attack kind names a recorded crypt attack sound (%s)" % str(bad))
	var hell: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/hell_monsters.json"))
	var unmapped: Array = []
	for def: Dictionary in (hell.defs as Dictionary).values():
		for a: Dictionary in def.stats.attacks:
			if not (map.hell as Dictionary).has(str(a.kind)) and not unmapped.has(str(a.kind)):
				unmapped.append(str(a.kind))
	check(unmapped.is_empty(), "every hell monster attack kind has a crypt sound kind (%s)" % str(unmapped))
	var frost: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/frost_theme.json"))
	unmapped = []
	for set: Dictionary in (frost.moves.sets as Dictionary).values():
		for e: Dictionary in set.moves:
			var spec := FrostMoves.move(str(e.move))
			if not (map.moves as Dictionary).has(str(e.move)) and not (map.moves as Dictionary).has(str(spec.get("type", ""))):
				unmapped.append(str(e.move))
	for kit: Dictionary in (frost.boss_kits as Dictionary).values():
		for ph: Dictionary in kit.phases:
			for atk: Dictionary in ph.attacks:
				if not (map.kits as Dictionary).has(str(atk.do)):
					unmapped.append(str(atk.do))
	check(unmapped.is_empty(), "every Frostgruft move and guardian attack has a crypt sound kind (%s)" % str(unmapped))


func test_regular_monsters_never_take_a_boss_sound() -> void:
	var sound := StorySound.new(null)
	var events: Dictionary = table.events
	var enemy_level := func(kind: String) -> bool:
		return kind == "" or kind == "summon" or str((events.get("attack_" + kind, {}) as Dictionary).get("category", "")) == "enemy"
	var bad: Array = []
	# every hell monster as a regular monster (floor mobs, summoned adds, Ignaroth's echoes)
	var hell: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/hell_monsters.json"))
	for id: String in hell.defs:
		for a: Dictionary in hell.defs[id].stats.attacks:
			var kind := sound.attack_kind("hell", [str(a.kind)], int(a.get("count", 1)), false)
			if not enemy_level.call(kind):
				bad.append("%s.%s=%s" % [id, a.kind, kind])
	# the Frostgruft's regular enemies: their move sets and basic behaviours
	var frost: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/frost_theme.json"))
	for set_id: String in frost.moves.sets:
		if set_id == "guardian":
			continue
		for e: Dictionary in frost.moves.sets[set_id].moves:
			var spec := FrostMoves.move(str(e.move))
			var count := int(spec.get("count", 1)) if str(spec.get("pattern", "")) in ["fan", "ring"] else 1
			var kind := sound.attack_kind("moves", [str(e.move), str(spec.type)], count, false)
			if not enemy_level.call(kind):
				bad.append("%s.%s=%s" % [set_id, e.move, kind])
	for kind_id: String in frost.mobs:
		var def: Dictionary = frost.mobs[kind_id]
		var behavior := str(def.get("behavior", ""))
		if behavior in ["shooter", "turret", "dasher"]:
			var kind := sound.attack_kind("behaviors", [behavior], int(def.get("fan", 1)), false)
			if not enemy_level.call(kind):
				bad.append("%s.%s=%s" % [kind_id, behavior, kind])
	check(bad.is_empty(), "no regular story monster attacks with a crypt boss sound, only at the crypt's enemy level (%s)" % str(bad))
	# guardians and bosses keep the crypt's boss sounds
	check(sound.attack_kind("hell", ["ring"], 14, true) == "salve" and sound.attack_kind("hell", ["breath"], 15, true) == "roar" and sound.attack_kind("hell", ["slam"], 1, true) == "slam",
		"hell guardians keep the crypt's salve, roar and slam")
	check(sound.attack_kind("moves", ["ice_fan", "bullets"], 5, true) == "salve" and sound.attack_kind("moves", ["frost_nova", "strikes"], 1, true) == "roar",
		"Frostgruft guardians keep the crypt's salve and roar")
	check(sound.attack_kind("hell", ["summon"], 1, false) == "summon", "a regular summoner keeps the summon, like the crypt's necromancer")


# --- Hell-Dungeon -------------------------------------------------------------------------

func test_hell_combat_sounds_once_in_crypt_materials() -> void:
	var game: Node = await _open(HellScene, "swordsman")
	var fake: FakeSfx = game.sfx
	check(game.feel.feedback.sfx == fake, "hell: the crypt's feedback plays on the world's sound player")
	# a monster far off keeps the room from clearing while others fall
	_hell_mob(game, "glutwaechter", Vector2(1200, 0))
	for case: Array in [["brandskelett", "hit_bone"], ["glutschaedel", "hit_bone"], ["hoellenhund", "hit_flesh"], ["magmaschleim", "hit_flesh"], ["peingeist", "hit_void"], ["glutwaechter", "hit_bone"]]:
		var m := _hell_mob(game, str(case[0]), Vector2(320, 0))
		game.feel.update(DT)
		fake.reset()
		game._damage_mob(m, Vector2.RIGHT * 600.0)
		game.feel.update(DT)
		check(fake.starting("hit") == [case[1]], "hell: a hit on %s sounds once as %s (%s)" % [case[0], case[1], str(fake.played)])
		game.mobs.erase(m)
		_frames(game, 20)
	# kills: one sound in the material, the void beings' recorded fade
	for case: Array in [["brandskelett", "kill_bone"], ["hoellenhund", "kill_flesh"], ["peingeist", "kill_void"]]:
		var m := _hell_mob(game, str(case[0]), Vector2(320, 0))
		game.feel.update(DT)
		fake.reset()
		m.hp = 0.0
		game.monsters.update(DT)
		game.feel.update(DT)
		var kills: Array = Array(fake.played).filter(func(n: String) -> bool: return n.begins_with("kill") or n.begins_with("break") or n == "boss_kill")
		check(kills == [case[1]], "hell: %s dies once as %s (%s)" % [case[0], case[1], str(fake.played)])
		_frames(game, 30)
	# the hero's hurt: the punch with its groan layer, played once
	fake.reset()
	game.state.inv = 0.0
	game._hurt("im Test")
	game.state.inv = 99.0
	game.feel.update(DT)
	check(fake.count("hurt") == 1 and fake.count("hurt_voice") == 0, "hell: a hurt plays the crypt's hurt once, its groan only as the event's layer (%s)" % str(fake.played))
	_frames(game, 30)
	# the sword: one swing per swing
	fake.reset()
	game.state.cool = 0.0
	game._attack(Vector2.LEFT)
	game.feel.update(DT)
	check(fake.count("swing") == 1, "hell: one sword swing sounds once (%s)" % str(fake.played))
	_frames(game, 30)
	# footsteps at the world's step_every, from the crypt's step timer
	fake.reset()
	game.player.moving = true
	_frames(game, 60)
	game.player.moving = false
	game.feel.update(DT)
	var steps := fake.count("step")
	check(steps >= 3 and steps <= 4, "hell: one second of walking plays 3-4 footsteps at step_every 0.3, not the crypt's 5 (%d)" % steps)
	# a block: the crypt's block once
	var shield := _hell_mob(game, "brandskelett", Vector2(320, 0))
	game.feel.update(DT)
	fake.reset()
	game.feel.on_block(shield)
	game.feel.update(DT)
	check(fake.played == ["block"], "hell: a shield turns a hit with one block (%s)" % str(fake.played))
	game.mobs.clear()
	_frames(game, 5)
	# the guardian's room: the doors lock once, the guardian stings once
	fake.reset()
	game._start_fight(_boss_room(game))
	_frames(game, 3)
	check(fake.count("doors_lock") == 1 and fake.count("boss_intro") == 1, "hell: a guardian's fight locks the doors once and stings once (%s)" % str(fake.played))
	await _free(game)

	# the mage's orb: one shot sound per shot
	game = await _open(HellScene, "mage")
	fake = game.sfx
	game.state.cool = 0.0
	game._attack(Vector2.LEFT)
	game.feel.update(DT)
	check(fake.count("shoot_magic") == 1, "hell: one magic shot sounds once (%s)" % str(fake.played))
	await _free(game)


func test_hell_acts_wind_up_and_fire() -> void:
	var game: Node = await _open(HellScene, "swordsman")
	_hell_mob(game, "glutwaechter", Vector2(1400, 0))
	var all: Array = []
	var regular: Array = []
	var played := _act(game, _hell_mob(game, "aschenpriester", Vector2(300, 0)), "summon")
	regular.append_array(played)
	check(played.count("windup_summon") == 1 and played.count("attack_summon") == 1 and played.find("windup_summon") < played.find("attack_summon"),
		"hell: the ash priest's summon winds up and fires once (%s)" % str(played))
	played = _act(game, _hell_mob(game, "peingeist", Vector2(300, 60)), "bolt")
	regular.append_array(played)
	check(played.count("attack_soul") == 1 and played.count("attack_salve") == 0 and played.filter(func(n: String) -> bool: return n.begins_with("windup")).is_empty(),
		"hell: the torment ghost's triple bolt is one soul shot, not the void boss's salve (%s)" % str(played))
	played = _act(game, _hell_mob(game, "brandskelett", Vector2(200, 0)), "swing")
	regular.append_array(played)
	check(played.count("attack_slash") == 1, "hell: the burning skeleton's swing slashes once (%s)" % str(played))
	var hound := _hell_mob(game, "hoellenhund", Vector2(300, -60))
	var dash: Dictionary = {}
	for a: Dictionary in hound.st.attacks:
		if str(a.kind) == "dash":
			dash = a
	played = _act(game, hound, "dash")
	regular.append_array(played)
	check(played.count("attack_bite") == int(dash.get("repeat", 1)), "hell: the hellhound bites once per dash (%s)" % str(played))
	played = _act(game, hound, "breath")
	regular.append_array(played)
	check(played.count("attack_soul") == 1 and played.count("attack_roar") == 0, "hell: the hellhound's fire breath is a soul shot, not a miniboss roar (%s)" % str(played))
	played = _act(game, _hell_mob(game, "glutimp", Vector2(260, 40)), "lob")
	regular.append_array(played)
	check(played.count("attack_soul") == 1 and played.count("attack_arrow") == 0, "hell: the fire imp's lob is a soul shot, not a bow twang (%s)" % str(played))
	played = _act(game, _hell_mob(game, "magmaschleim", Vector2(250, 0)), "slam")
	regular.append_array(played)
	check(played.count("attack_bite") == 1 and played.count("attack_slam") == 0 and played.count("blast") == 0,
		"hell: the magma slime's slam is an enemy's crunch, its wave lands without the boss blast (%s)" % str(played))
	check(_boss_sounds(regular).is_empty(), "hell: regular monsters never play a crypt boss sound (%s)" % str(_boss_sounds(regular)))
	all.append_array(regular)
	# guardians and Ignaroth keep the crypt's boss sounds
	played = _act(game, _hell_mob(game, "glutwaechter", Vector2(250, 0), true), "slam")
	all.append_array(played)
	check(played.count("attack_slam") == 1 and played.count("blast") >= 1 and played.find("attack_slam") <= played.find("blast"),
		"hell: the ember guardian's slam stamps, then its wave lands with the crypt's blast (%s)" % str(played))
	played = _act(game, _hell_mob(game, "kesselbrut", Vector2(300, 0), true), "ring")
	all.append_array(played)
	check(played.count("attack_salve") == 1, "hell: a guardian's ring is one crypt salve (%s)" % str(played))
	played = _act(game, _hell_mob(game, "drache4", Vector2(400, 0), true), "beam")
	all.append_array(played)
	check(played.count("windup_beam") == 1 and played.count("attack_beam") == 1, "hell: Ignaroth's beams charge and fire once (%s)" % str(played))
	var drake := _hell_mob(game, "drache3", Vector2(400, 0), true)
	played = _act(game, drake, "sweep")
	all.append_array(played)
	check(played.count("attack_beam") == 1, "hell: Ignaroth's fire sweep fires once (%s)" % str(played))
	played = _act(game, drake, "flight")
	all.append_array(played)
	check(played.count("attack_roar") == 1, "hell: Ignaroth roars once as he takes to the air (%s)" % str(played))
	check(_no_synth(all), "hell: no act falls back to the crypt's synthesized beeps (%s)" % str(all))
	await _free(game)


func test_hell_acts_sound_when_they_release() -> void:
	var game: Node = await _open(HellScene, "swordsman")
	_hell_mob(game, "glutwaechter", Vector2(1400, 0))
	var mons: RefCounted = game.monsters
	# each act sounds in the very frame it releases (hell_monsters' sound hook), whatever its timing
	var shots: int = game.eshots.size()
	var spinner := _hell_mob(game, "seelenhirte", Vector2(300, 0), true)
	var at := _release_frames(game, spinner, "spiral", "attack_soul", func() -> bool: return game.eshots.size() > shots)
	check(at[0] >= 0 and at[0] == at[1], "hell: a spiral sounds in the frame its first shot flies (heard %d, shot %d)" % [at[0], at[1]])
	var lobs: int = mons.lobs.size()
	at = _release_frames(game, _hell_mob(game, "glutimp", Vector2(260, 0)), "lob", "attack_soul", func() -> bool: return mons.lobs.size() > lobs)
	check(at[0] >= 0 and at[0] == at[1], "hell: a lob sounds in the frame it is thrown (heard %d, thrown %d)" % [at[0], at[1]])
	var zones: int = mons.zones.size()
	at = _release_frames(game, _hell_mob(game, "glutwaechter", Vector2(260, 0), true), "slam", "attack_slam", func() -> bool: return mons.zones.size() > zones)
	check(at[0] >= 0 and at[0] == at[1], "hell: a slam sounds in the frame its wave starts (heard %d, wave %d)" % [at[0], at[1]])
	shots = game.eshots.size()
	at = _release_frames(game, _hell_mob(game, "kesselbrut", Vector2(300, 0), true), "ring", "attack_salve", func() -> bool: return game.eshots.size() > shots)
	check(at[0] >= 0 and at[0] == at[1], "hell: a ring sounds in the frame its first wave flies (heard %d, wave %d)" % [at[0], at[1]])
	var skull := _hell_mob(game, "glutschaedel", Vector2(300, 0))
	at = _release_frames(game, skull, "dash", "attack_bite", func() -> bool: return skull.act != null and skull.act.has("warn") and not bool(skull.act.warn))
	check(at[0] >= 0 and at[0] == at[1], "hell: a dash bites in the frame it lunges (heard %d, lunge %d)" % [at[0], at[1]])
	await _free(game)


func test_hell_landings_forms_and_parts() -> void:
	var game: Node = await _open(HellScene, "swordsman")
	var fake: FakeSfx = game.sfx
	# Ignaroth changes form: one roar when the new form appears
	var lord := _hell_mob(game, "drache1", Vector2(400, 0), true)
	lord.trans = {"t": 0.0, "next": "drache2", "glow": 0.0, "grow": 1.0, "swapped": false}
	game.feel.update(DT)
	fake.reset()
	lord.trans.swapped = true
	_frames(game, 3)
	check(fake.played == ["attack_roar"], "hell: Ignaroth roars once as he changes form (%s)" % str(fake.played))
	lord.trans = null
	# plumbing only: the feel passes a dragon's part counters on to the crypt (nothing in the
	# story worlds counts parts yet; the rig agent's body parts would)
	fake.reset()
	lord.part_breaks = 1
	game.feel.update(DT)
	lord.part_regrows = 1
	game.feel.update(DT)
	check(fake.played == ["break_flesh", "regrow"], "hell: part counters on a dragon reach the crypt as tear and regrowth (%s)" % str(fake.played))
	# landings: a guardian's meteor blasts once; a crypt burst already raised there plays through feedback instead
	fake.reset()
	game.monsters._zone({"kind": "meteor", "p": lord.p + Vector2(0, 200), "r": 80.0, "tele": 0.0, "T": 0.5, "m": lord})
	game.monsters._update_zones(DT)
	_frames(game, 2)
	check(fake.count("blast") == 1, "hell: a guardian's meteor lands with the crypt's blast once (%s)" % str(fake.played))
	_frames(game, 10)
	fake.reset()
	var at: Vector2 = lord.p + Vector2(0, -200)
	game.feel.on_blast(at, 80.0, "fire")
	game.monsters._zone({"kind": "wave", "p": at, "r": 80.0, "tele": 0.0, "T": 0.5, "m": lord})
	game.monsters._update_zones(DT)
	_frames(game, 2)
	check(fake.count("blast") == 1, "hell: a landing with its own crypt burst blasts once, not twice (%s)" % str(fake.played))
	_frames(game, 10)
	fake.reset()
	var slime := _hell_mob(game, "magmaschleim", Vector2(-300, 0))
	game.monsters._zone({"kind": "wave", "p": slime.p, "r": 60.0, "tele": 0.0, "T": 0.5, "m": slime})
	game.monsters._update_zones(DT)
	_frames(game, 2)
	check(fake.count("blast") == 0, "hell: a regular monster's landing stays without the crypt boss blast (%s)" % str(fake.played))
	# the hero's rage slam plays at the hero's level
	fake.reset()
	game.as_source("hero", func() -> void: game._sound_raw("attack_slam"))
	check(fake.played == ["attack_slam"] and fake.cats == ["hero"], "hell: the hero's own slam sounds at the hero's mix level (%s)" % str(fake.cats))
	await _free(game)


func test_hell_world_moments_are_crypt_fx_events() -> void:
	var game: Node = await _open(HellScene, "swordsman")
	var fake: FakeSfx = game.sfx
	var me := Vector2(game.player.x, game.player.y)
	var raised := func(kind: String) -> bool:
		return (game.feel._events as Array).any(func(e: Dictionary) -> bool: return str(e.kind) == kind)
	# a rune plate of a sequence, stepped on through the world's hazards: it clicks in the world group
	game.W.groups["sound_test"] = {"kind": "sequence", "solved": false, "next": 0}
	game.W.ents.append({"type": "plate", "group": "sound_test", "order": 0, "x": me.x, "y": me.y - 10.0})
	game.W.ents.append({"type": "plate", "group": "sound_test", "order": 1, "x": me.x + 2000.0, "y": me.y})
	fake.reset()
	game._update_hazards(DT)
	check(fake.played == ["ui_click"] and fake.cats == ["world"], "hell: a rune plate clicks once in the world group (%s %s)" % [str(fake.played), str(fake.cats)])
	game.W.groups.erase("sound_test")
	game.W.ents = (game.W.ents as Array).filter(func(e: Dictionary) -> bool: return str(e.get("group", "")) != "sound_test")
	_frames(game, 10)
	# pickups: the crypt's loot_taken, one chime each, the key too
	game.state.hp = int(game.state.max_hp) - 2
	for kind: String in ["heart", "gem", "key"]:
		var e := {"type": kind, "x": me.x, "y": me.y, "room": int(game.state.room)}
		if kind == "key":
			e.key = str(game.key_name.keys()[0])
		game.W.ents.append(e)
		fake.reset()
		game._update_hazards(DT)
		game.feel.update(DT)
		check(fake.count("perk") == 1 and fake.played.size() == 1 and raised.call("loot_taken"), "hell: picking up a %s is the crypt's loot_taken with one chime (%s)" % [kind, str(fake.played)])
		_frames(game, 70)
	# a skull heap: each blow clacks like bone, its fall is the crypt's wall_break (rubble, shake, its sound)
	var cell := Vector2i(int(me.x / game.C), int(me.y / game.C))
	game.W.doors.append({"cells": [cell], "broken": false})
	var heap := {"type": "skullheap", "x": me.x + 120.0, "y": me.y, "hp": 2, "door": game.W.doors.size() - 1}
	fake.reset()
	game._hit_breakable(heap, Vector2(heap.x, heap.y))
	game.feel.update(DT)
	check(fake.played == ["hit_bone"], "hell: a blow on a skull heap clacks once like bone (%s)" % str(fake.played))
	fake.reset()
	game._hit_breakable(heap, Vector2(heap.x, heap.y))
	game.feel.update(DT)
	check(fake.count("hit_bone") == 1 and fake.count("break_bone") == 1 and fake.count("collapse_bone") == 0 and raised.call("wall_break"),
		"hell: the heap's fall opens the wall with the crypt's wall_break sound once (%s)" % str(fake.played))
	check(float(game.feel.feedback.shake) > 0.0, "hell: the secret wall shakes the picture like the crypt's wall break")
	await _free(game)


func test_hell_room_death_and_music() -> void:
	var game: Node = await _open(HellScene, "swordsman")
	var fake: FakeSfx = game.sfx
	# a cleared fight room: one room-clear sting from the crypt's phase change
	var room := _fight_room(game)
	game.state.room = int(room.index)
	room.fight = true
	_frames(game, 2)
	check(StorySound.phase(game) == "combat" and StorySound.music_state(game) == "explore", "hell: a fight room without monsters is combat, its music explore")
	var add := _hell_mob(game, "brandskelett", Vector2(400, 0))
	add.room = int(room.index)
	check(StorySound.music_state(game) == "combat", "hell: a fight with monsters plays the combat music")
	game.mobs.clear()
	fake.reset()
	game._clear_room(room, Vector2(game.player.x, game.player.y))
	_frames(game, 2)
	check(fake.count("room_clear") == 1, "hell: a cleared room stings once (%s)" % str(fake.played))
	check(StorySound.phase(game) == "reward" and StorySound.music_state(game) == "explore", "hell: a cleared room is the crypt's reward phase, explore music")
	var boss := _hell_mob(game, "glutwaechter", Vector2(600, 0), true)
	check(StorySound.music_state(game) == "boss", "hell: a living guardian plays the boss music")
	game.mobs.erase(boss)
	# the hero's level-up: the crypt's stinger instead of the theme's chime
	_frames(game, 2)
	fake.reset()
	HeroKit.gain(game, HeroKit.need(game.theme.leveling, int(game.state.level)) - int(game.state.exp))
	var direct := Array(fake.played)
	_frames(game, 2)
	check(not direct.has("perk") and fake.count("room_clear") == 1, "hell: a level-up plays the crypt's level-up sting once (%s)" % str(fake.played))
	fake.reset()
	game._sound("level_up")
	check(fake.played == ["perk"], "hell: a card or the phoenix keeps its chime (%s)" % str(fake.played))
	# a pit fall hurts like a hit
	_frames(game, 30)
	fake.reset()
	game._fall_into_pit()
	game.feel.update(DT)
	check(fake.count("hurt") == 1, "hell: a pit fall sounds the hero's hurt (%s)" % str(fake.played))
	_frames(game, 30)
	# death: the killing blow, the defeat sting once, no groan from the run's end, the menu music
	fake.reset()
	game.state.hp = 1
	game.state.inv = 0.0
	game._hurt("im Test")
	for i in range(3):
		game._update(DT)
	check(fake.count("hurt") == 1 and fake.count("team_wipe") == 1, "hell: the killing blow hurts and the defeat stings once (%s)" % str(fake.played))
	check(StorySound.music_state(game) == "menu" and game._music_state == "menu", "hell: a fallen hero hears the menu theme")
	game.state.dead = 0.001
	fake.reset()
	game._update(DT)
	check(not (game.state.over as Dictionary).is_empty() and fake.count("hurt_voice") == 0 and fake.count("team_wipe") == 0, "hell: the run's end adds no second groan or sting (%s)" % str(fake.played))
	await _free(game)


func test_hell_guardian_fall_stings_like_the_crypt() -> void:
	var game: Node = await _open(HellScene, "swordsman")
	var fake: FakeSfx = game.sfx
	var room := _boss_room(game)
	game.state.room = int(room.index)
	for final: bool in [false, true]:
		game.W.final = final
		room.fight = true
		room.cleared = false
		var guardian := _hell_mob(game, "glutwaechter", Vector2(300, 0), true)
		_frames(game, 3)
		fake.reset()
		var level := int(game.state.level)
		guardian.hp = 0.0
		game.monsters.update(DT)
		_frames(game, 3)
		# a level-up from the guardian's experience adds the crypt's level-up sting (also room_clear)
		var clears := 1 + (1 if int(game.state.level) > level else 0)
		if final:
			check(fake.count("boss_kill") == 1 and fake.count("room_clear") == clears and fake.count("boss_defeated") == 1,
				"hell: the last guardian falls with the boss kill, the room clear and the victory tune, like the crypt's void boss (%s)" % str(fake.played))
		else:
			check(fake.count("boss_kill") == 1 and fake.count("room_clear") == clears and fake.count("boss_defeated") == 0,
				"hell: a floor guardian falls with the boss kill and the room clear only, like the crypt's floor bosses (%s)" % str(fake.played))
		_frames(game, 90)
	game.W.final = false
	await _free(game)


# --- Frostgruft ---------------------------------------------------------------------------

func test_frost_enemies_moves_and_kits() -> void:
	var game: Node = await _open(FrostScene, "archer")
	var fake: FakeSfx = game.sfx
	_frost_mob(game, "ice_knight", Vector2(1400, 0))
	# materials of the crypt's table, not the theme's
	for case: Array in [["frost_skeleton", "hit_bone"], ["ice_zombie", "hit_bone"], ["ice_slime", "hit_flesh"], ["frost_imp", "hit_void"]]:
		var m := _frost_mob(game, str(case[0]), Vector2(320, 0))
		game.feel.update(DT)
		fake.reset()
		game._damage_mob(m, Vector2.RIGHT * 600.0)
		game.feel.update(DT)
		check(fake.starting("hit") == [case[1]], "frost: a hit on %s sounds once as %s (%s)" % [case[0], case[1], str(fake.played)])
		game.mobs.erase(m)
		_frames(game, 20)
	var imp := _frost_mob(game, "frost_imp", Vector2(320, 0))
	game.feel.update(DT)
	fake.reset()
	imp.hp = 0.0
	game._update_mobs(DT)
	game.feel.update(DT)
	check(fake.count("kill_void") == 1 and fake.count("kill") == 0 and fake.count("break_void") == 0, "frost: a frost imp fades with the void's recorded death once (%s)" % str(fake.played))
	_frames(game, 30)
	# the archer's arrow
	fake.reset()
	game.state.cool = 0.0
	game._attack(Vector2.LEFT)
	game.feel.update(DT)
	check(fake.count("shoot_arrow") == 1, "frost: one arrow sounds once (%s)" % str(fake.played))
	# a frost skeleton's shot: the crypt archer's arrow, not the theme's plus a synth
	var skeleton := _frost_mob(game, "frost_skeleton", Vector2(400, 0))
	game.feel.update(DT)
	fake.reset()
	skeleton.shoot = 0.0001
	game._update_mobs(DT)
	game.feel.update(DT)
	check(fake.count("attack_arrow") == 1 and fake.count("enemy_shoot") == 0, "frost: a frost skeleton's shot sounds like the crypt's skeleton archer (%s)" % str(fake.played))
	game.mobs.erase(skeleton)
	# the ice crystal's five-shot fan: a soul shot at the enemies' level, not the void boss's salve
	var crystal := _frost_mob(game, "ice_crystal", Vector2(420, -80))
	game.feel.update(DT)
	fake.reset()
	crystal.shoot = 0.0001
	game._update_mobs(DT)
	game.feel.update(DT)
	check(fake.count("attack_soul") == 1 and fake.count("attack_salve") == 0, "frost: an ice crystal's fan is one soul shot, not the boss salve (%s)" % str(fake.played))
	game.mobs.erase(crystal)
	# moves of regular enemies: the windup stays quiet, the release sounds once at the enemies' level
	var regular: Array = []
	var zombie := _frost_mob(game, "ice_zombie", Vector2(110, 0))
	var played := _move(game, zombie, "frost_breath")
	regular.append_array(played)
	check(played.count("windup_fuse") == 0 and played.count("windup_beam") == 0 and played.count("attack_soul") == 1 and played.count("attack_roar") == 0 and played.count("attack_beam") == 0,
		"frost: the ice zombie's frost breath is one soul shot at its release, no roar, fuse or laser charge (%s)" % str(played))
	game.mobs.erase(zombie)
	var knight := _frost_mob(game, "ice_knight", Vector2(90, 0))
	played = _move(game, knight, "whirl_slash")
	regular.append_array(played)
	check(played.count("attack_slash") == 1 and played.count("attack_slam") == 0, "frost: the ice knight's whirl slashes once, no miniboss stamp (%s)" % str(played))
	game.mobs.erase(knight)
	var archer := _frost_mob(game, "frost_skeleton", Vector2(300, 0))
	played = _move(game, archer, "arrow_volley")
	regular.append_array(played)
	check(played.count("attack_arrow") == 1 and played.count("attack_salve") == 0, "frost: a frost skeleton's arrow volley twangs once, no boss salve (%s)" % str(played))
	game.mobs.erase(archer)
	var pouncer := _frost_mob(game, "frost_imp", Vector2(300, 0))
	played = _move(game, pouncer, "pounce")
	regular.append_array(played)
	check(played.count("attack_bite") == 1 and played.count("windup_fuse") == 0, "frost: the frost imp's pounce bites once (%s)" % str(played))
	played = _move(game, pouncer, "void_blink")
	regular.append_array(played)
	check(played.count("void_burst") == 0 and played.filter(func(n: String) -> bool: return n.begins_with("attack_")).is_empty(),
		"frost: the frost imp's blink stays silent like the crypt's (%s)" % str(played))
	game.mobs.erase(pouncer)
	check(_boss_sounds(regular).is_empty(), "frost: regular enemies' moves never play a crypt boss sound (%s)" % str(_boss_sounds(regular)))
	check(_no_synth(regular), "frost: moves never fall back to the synthesized beeps (%s)" % str(regular))
	# the moves' own attack sounds give way to the crypt routing; outside a move they play
	fake.reset()
	game.as_source("moves", func() -> void: game._sound_raw("attack_roar"))
	check(fake.played.is_empty(), "frost: a move's own attack sound gives way to the crypt routing")
	game._sound_raw("attack_roar")
	check(fake.played == ["attack_roar"], "frost: outside a move a direct sound plays")
	# rage: a regular enemy stays quiet, a guardian roars once
	var raging := _frost_mob(game, "frost_skeleton", Vector2(500, 0))
	raging.mv = {"next": 99.0, "cd": {}, "used": {}, "rage": false, "run": {}}
	game.feel.update(DT)
	fake.reset()
	raging.mv.rage = true
	_frames(game, 3)
	check(fake.count("attack_roar") == 0, "frost: a regular enemy that rages does not take the miniboss roar (%s)" % str(fake.played))
	game.mobs.erase(raging)
	# a guardian without its own kit (frost_moves' guardian set) keeps the crypt's boss sounds
	var guard := _frost_mob(game, "ice_knight", Vector2(300, 0))
	guard.kind = "boss"
	_frames(game, 2)
	played = _move(game, guard, "ice_fan")
	check(played.count("attack_salve") == 1, "frost: a guardian's ice fan is the crypt's salve (%s)" % str(played))
	played = _move(game, guard, "ice_armor")
	check(played.count("block") == 0 and played.count("perk") == 1, "frost: the ice armour sounds as the crypt's armour fx, not a parry (%s)" % str(played))
	guard.mv.rage = false
	game.feel.update(DT)
	fake.reset()
	guard.mv.rage = true
	_frames(game, 3)
	check(fake.played == ["attack_roar"], "frost: a guardian that starts raging roars once (%s)" % str(fake.played))
	game.mobs.erase(guard)
	await _free(game)

	# a guardian kit (floor 3): its attacks sound through the crypt routing, once each
	game = await _open(FrostScene, "archer", 3)
	fake = game.sfx
	game._spawn_mob(game.state.room, Vector2(game.player.x + 500, game.player.y), "boss")
	var boss: Dictionary = game.mobs[game.mobs.size() - 1]
	boss.spawn = 0.0
	game.feel.update(DT)
	check(fake.count("boss_intro") == 1, "frost: the guardian stings once on arrival (%s)" % str(fake.played))
	game.feel.update(DT)
	check(fake.count("boss_intro") == 1, "frost: the guardian's sting does not repeat")
	fake.reset()
	boss.atk_t = 0.0
	game.as_source("kit", func() -> void: BossKit.update(game, boss, DT))
	check(fake.played.is_empty(), "frost: the kit's own attack sound gives way to the crypt routing (%s)" % str(fake.played))
	game.feel.update(DT)
	check(fake.count("attack_summon") == 1, "frost: the guardian's summon sounds once (%s)" % str(fake.played))
	fake.reset()
	boss.atk_t = 0.0
	game.as_source("kit", func() -> void: BossKit.update(game, boss, DT))
	game.feel.update(DT)
	check(fake.count("attack_salve") == 1, "frost: the guardian's three-shot fan is one volley (%s)" % str(fake.played))
	# while the kit runs only its own attack sounds give way: a blow the subclass absorbs still sounds
	fake.reset()
	game.as_source("kit", func() -> void:
		game._sound("block")
		game._sound("boss_summon"))
	check(fake.played == ["block"], "frost: while a kit runs, other sounds (a block) still play, its attack sound does not (%s)" % str(fake.played))
	_frames(game, 5)
	fake.reset()
	game.as_source("kit", func() -> void: BossKit.start(game, boss, {"do": "charge", "windup": 0.3, "speed": 300.0, "time": 0.3}))
	var during: Array = []
	var t := 0.0
	while not (boss.busy as Dictionary).is_empty() and t < 3.0:
		game.as_source("kit", func() -> void: BossKit.update(game, boss, DT))
		game.feel.update(DT)
		if t < 0.25:
			during.append_array(Array(fake.played))
		t += DT
	_frames(game, 3)
	check(fake.count("attack_bite") == 1 and not during.has("attack_bite"), "frost: the guardian's charge winds up quietly and bites once when it runs (%s)" % str(fake.played))
	await _free(game)


func test_frost_room_clear_and_music() -> void:
	var game: Node = await _open(FrostScene, "archer")
	var fake: FakeSfx = game.sfx
	var room := _fight_room(game)
	game.state.room = int(room.index)
	room.fight = true
	var zombie := _frost_mob(game, "ice_zombie", Vector2(300, 0))
	_frames(game, 2)
	check(StorySound.phase(game) == "combat" and StorySound.music_state(game) == "combat", "frost: a fight with enemies is the crypt's combat, its music combat")
	fake.reset()
	var level := int(game.state.level)
	zombie.hp = 0.0
	game._update_mobs(DT)
	_frames(game, 2)
	var clears := 1 + (1 if int(game.state.level) > level else 0)
	check(fake.count("kill_bone") == 1 and fake.count("room_clear") == clears, "frost: the last enemy falls once in bone and the room stings clear once (%s)" % str(fake.played))
	check(StorySound.phase(game) == "reward" and StorySound.music_state(game) == "explore", "frost: a cleared room is the crypt's reward phase, explore music")
	await _free(game)


func test_frost_hero_skills_at_hero_level() -> void:
	var game: Node = await _open(FrostScene, "swordsman")
	var fake: FakeSfx = game.sfx
	while int(game.state.level) < 6:
		HeroKit.gain(game, HeroKit.need(game.theme.leveling, int(game.state.level)) - int(game.state.exp))
	_frames(game, 3)
	fake.reset()
	game.state.skill_cd = {}
	game.skill_key("3", true)
	var at := fake.played.find("attack_bite")
	check(at >= 0 and fake.cats[at] == "hero", "frost: the swordsman's charge borrows the bite at the hero's level (%s %s)" % [str(fake.played), str(fake.cats)])
	fake.reset()
	game.skill_key("1", true)
	at = fake.played.find("swing")
	check(at >= 0 and fake.cats[at] == "hero" and fake.count("swing") == 1, "frost: the whirl swings once at the hero's level (%s)" % str(fake.played))
	# the real player: the borrowed enemy sound sits at the hero's level, not the enemy's
	var real = Sfx.new()
	game.add_child(real)
	await process_frame
	game.sfx = real
	game.state.skill_cd = {}
	game.skill_key("2", true)
	var player: AudioStreamPlayer = real._players[(real._next - 1 + real._players.size()) % real._players.size()]
	var variant: Dictionary = real._files["attack_slash"][int(real._last_variant["attack_slash"])]
	var want: float = AudioMix.base_db() + float(AudioMix.category("hero").get("volume_db", 0.0)) + float(real._meta["attack_slash"].volume_db) + float(variant.gain_db)
	check(real.last_effect == "attack_slash" and real.last_bus == "SFX" and absf(player.volume_db - want) < 0.01,
		"frost: the wave skill's slash plays at base + hero level (%.1f dB, want %.1f)" % [player.volume_db, want])
	game.sfx = fake
	real.queue_free()
	await _free(game)
