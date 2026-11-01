extends SceneTree
## Combat regressions of the story worlds (src/hell/hell_monsters.gd on the
## Krypta scene): a teleporter whose fade is cut short comes back to full alpha
## and can be hit again (no see-through, unkillable figure); a mimic deals no
## contact damage and bites only after its windup, and only a hero still in
## front of it (assets/data/mimic_bite.json).

const KryptaScene = preload("res://src/hell/krypta_dungeon.tscn")
const STEP := 1.0 / 60.0
var game: Node
var checked := 0
var failures: Array[String] = []


func check(condition: bool, label: String) -> void:
	checked += 1
	if not condition:
		failures.append(label)
		printerr("COMBAT_FIXES_FAIL: ", label)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	seed(11)
	game = KryptaScene.instantiate()
	game.class_id = "swordsman"
	game.settings_path = "user://settings_test.cfg"
	root.add_child(game)
	for i in range(2):
		await process_frame
	_test_cut_teleport_fade_returns()
	_test_mimic_has_no_contact_damage()
	_test_mimic_bites_after_windup_only_in_front()
	game.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://profile_test.json"))
	print("COMBAT_FIXES checked=%d failures=%d" % [checked, failures.size()])
	quit(1 if failures.size() > 0 else 0)


## No fight, no monsters, the hero whole and alive.
func _calm() -> void:
	for r: Dictionary in game.W.rooms:
		r.fight = false
		r.cleared = true
	game.mobs = []
	game.eshots = []
	game.state.hp = game.state.max_hp
	game.state.dead = 0.0


func _hero() -> Vector2:
	return Vector2(game.player.x, game.player.y)


## Runs the monsters for `seconds`; the hero is never invulnerable, so any blow shows.
func _step(seconds: float) -> void:
	for k in range(int(round(seconds / STEP))):
		game.state.inv = 0.0
		game.monsters.update(STEP)


func _index(m: Dictionary, value: String, field := "kind") -> int:
	var attacks: Array = m.st.attacks
	for k in range(attacks.size()):
		if str((attacks[k] as Dictionary).get(field, "")) == value:
			return k
	return -1


## A monster of the crypt with an attack of `kind` (the Leerenbomber first).
func _with_attack(kind: String) -> String:
	var defs: Dictionary = game.monsters.defs
	var ids: Array = ["leerenbomber"] + defs.keys()
	for id: Variant in ids:
		if defs.has(id):
			for a: Dictionary in defs[id].stats.attacks:
				if str(a.kind) == kind:
					return str(id)
	return ""


func _spawn(id: String, off: Vector2) -> Dictionary:
	var m: Dictionary = game.monsters.spawn(int(game.state.room), _hero() + off, id)
	m.spawn = 0.0
	for k in range(m.cds.size()):
		m.cds[k] = 99.0
	return m


func _test_cut_teleport_fade_returns() -> void:
	# Arrange: a teleporter of the crypt, its teleport begun and half faded out
	_calm()
	var id := _with_attack("teleport")
	check(id != "", "the crypt has a teleporter")
	if id == "":
		return
	var m := _spawn(id, Vector2(160, 0))
	var to: Vector2 = _hero() - m.p
	game.monsters._start_act(m, _index(m, "teleport"), to, to.length())
	_step(0.25)
	check(float(m.alpha) < 0.5, "the teleport fades the figure (arrange, alpha %.2f)" % float(m.alpha))
	# Act: the act is cut short (the Testraum's dummy switch drops m.act like a falling part or a stun)
	m.ai_off = true
	_step(0.6)
	# Assert
	check(is_equal_approx(float(m.alpha), 1.0), "a cut teleport leaves the figure at full alpha (alpha %.2f)" % float(m.alpha))
	check(game._hittable(m), "the figure whose teleport was cut can be hit again")


func _test_mimic_has_no_contact_damage() -> void:
	# Arrange: a mimic pressed against the hero, its attacks far off
	_calm()
	var m := _spawn("mimik", Vector2(30, 0))
	var hp := int(game.state.hp)
	# Act
	_step(0.5)
	# Assert
	check(int(game.state.hp) == hp, "touching a mimic costs no heart (%d -> %d)" % [hp, int(game.state.hp)])
	check(m.act == null or str(m.act.kind) != "mimic_bite", "no bite starts while its attacks are off")


func _test_mimic_bites_after_windup_only_in_front() -> void:
	# Arrange: a mimic beside the hero starts its bite
	_calm()
	var m := _spawn("mimik", Vector2(70, 0))
	var hp := int(game.state.hp)
	game.monsters._start_act(m, _index(m, "biss", "id"), _hero() - m.p, 70.0)
	# Act: through most of the windup
	_step(0.4)
	# Assert: nothing yet, the windup reads
	check(int(game.state.hp) == hp, "no heart is lost during the bite's windup")
	check(m.act != null and str(m.act.kind) == "mimic_bite", "the mimic's bite is a windup act")
	# Act: the snap
	_step(0.5)
	# Assert
	check(int(game.state.hp) < hp, "the bite lands on a hero still in front of it")
	# Arrange: another bite; the hero steps behind the mimic during its windup
	_calm()
	var other := _spawn("mimik", Vector2(70, 0))
	hp = int(game.state.hp)
	game.monsters._start_act(other, _index(other, "biss", "id"), _hero() - other.p, 70.0)
	_step(0.2)
	var behind: Vector2 = other.p + Vector2(70, 0)
	game.player.x = behind.x
	game.player.y = behind.y
	# Act
	_step(0.8)
	# Assert
	check(int(game.state.hp) == hp, "a hero who stepped behind the mimic is not bitten (%d -> %d)" % [hp, int(game.state.hp)])
