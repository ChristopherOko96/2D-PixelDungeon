extends SceneTree
## Hell monsters in the real hell game (src/hell/hell_monsters.gd): every floor's
## boss fight spawns that floor's boss and roster, each boss uses every one of its
## attacks, Ignaroth cannot be hit in the air, changes into his next form at 0 HP
## on floors 3, 6 and 9 and leaves, dies on floor 10, and each victory opens the
## portal. The monster data and sprite atlases match each other.

const HellScene = preload("res://src/hell/hell_dungeon.tscn")
const DT := 1.0 / 30.0
## Seconds a boss fight runs before every attack must have been seen.
const FIGHT_TIME := 75.0
var checked := 0
var failures: Array[String] = []


func check(condition: bool, description: String) -> void:
	checked += 1
	if not condition:
		failures.append(description)
		printerr("HELL_MONSTERS_FAIL: ", description)


func _initialize() -> void:
	_run.call_deferred()


func _start(floor_number: int) -> Node:
	var hell: Node = HellScene.instantiate()
	hell.start_floor = floor_number
	hell.start_at_boss = true
	root.add_child(hell)
	hell.set_process(false)
	hell._update(DT)
	return hell


func _boss(hell: Node) -> Dictionary:
	for m: Dictionary in hell.mobs:
		if m.boss:
			return m
	return {}


## Steps the game with the hero kept invulnerable; returns the attack ids the boss used.
func _fight(hell: Node, seconds: float) -> Dictionary:
	var used := {}
	var hit_in_air := false
	for i in range(int(seconds / DT)):
		hell.state.inv = 5.0
		var b := _boss(hell)
		if not b.is_empty():
			b.hp = maxf(b.hp, b.max * 0.5)
			if b.act != null:
				used[b.act.a.id] = true
			if b.alt > 30.0:
				# a shot right at him while he flies must pass harmlessly
				var hp: float = b.hp
				hell.shots.append({"p": b.p - Vector2(0, b.cy), "v": Vector2(1, 0), "t": 0.5})
				hell._update_shots(0.0)
				hit_in_air = hit_in_air or b.hp < hp
		hell._update(DT)
	used["__hit_in_air"] = hit_in_air
	return used


func _finish(hell: Node, seconds: float) -> Array:
	var forms: Array = []
	# the room opens only when the boss and every add are down; Ignaroth takes his adds with him
	for m: Dictionary in hell.mobs:
		m.hp = 0.0
	hell.state.pull = null
	for i in range(int(seconds / DT)):
		hell.state.inv = 5.0
		var now := _boss(hell)
		if not now.is_empty() and not forms.has(now.id):
			forms.append(now.id)
		hell._update(DT)
	return forms


func _run() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/hell_monsters.json"))
	# the atlases hold every animation frame at the exported size
	for id: String in data.defs:
		var def: Dictionary = data.defs[id]
		var tex: Texture2D = load("res://assets/sprites/hell/monsters/%s.png" % id)
		var cols := 0
		for a: String in def.anims:
			cols = maxi(cols, int(def.anims[a].frames))
		check(tex != null and tex.get_width() == int(def.w) * int(def.px) * cols and tex.get_height() == int(def.h) * int(def.px) * def.anims.size(),
			"%s: the atlas matches its frames" % id)
		check(def.anims.has("death") and def.anims.has("idle"), "%s: has idle and death" % id)
	for n in range(1, 11):
		# Arrange
		var hell: Node = _start(n)
		var boss_id: String = data.floors[str(n)].boss
		var b := _boss(hell)
		# Assert: the right boss and roster
		check(not b.is_empty() and b.id == boss_id, "floor %d: the boss is %s" % [n, boss_id])
		var roster: Array = data.floors[str(n)].mobs
		var strangers: Array = hell.mobs.filter(func(m: Dictionary) -> bool: return not m.boss and not roster.has(m.id))
		check(strangers.is_empty(), "floor %d: every mob comes from the floor's roster" % n)
		# Act: fight
		var used := _fight(hell, FIGHT_TIME)
		# Assert: every attack seen
		for a: Dictionary in data.defs[boss_id].stats.attacks:
			check(a.kind == "trail" or used.has(a.id), "floor %d: %s uses %s" % [n, boss_id, a.name])
		check(not used.__hit_in_air, "floor %d: no shot hits the boss in the air" % n)
		# Act: bring him down
		var lord: bool = data.defs[boss_id].kind == "lord"
		var forms := _finish(hell, 7.0)
		# Assert
		check(_boss(hell).is_empty(), "floor %d: the boss is gone after his end" % n)
		check(hell.state.boss_dead, "floor %d: the boss room counts as won" % n)
		var portal_open := false
		for e: Dictionary in hell.W.ents:
			if e.type == "portal" and e.get("active", false):
				portal_open = true
		check(portal_open, "floor %d: the portal opens" % n)
		if lord and n < 10:
			var next: String = data.floors[str(n + 1 if n < 9 else 10)].boss if n == 9 else ""
			check(forms.size() == 2 and int(data.defs[forms[1]].phase) == int(data.defs[boss_id].phase) + 1,
				"floor %d: Ignaroth changes into his next form before he leaves (%s)" % [n, ", ".join(PackedStringArray(forms))])
			if n == 9:
				check(forms[1] == next, "floor 9: the third form becomes the final one")
		if n == 10:
			check(forms == [boss_id], "floor 10: the final form does not transform but dies")
		if n == 9:
			check(hell.state.skill.owned, "floor 9: the clone skill is granted")
		hell.queue_free()
		await process_frame
	print("HELL_MONSTERS checked=%d failures=%d" % [checked, failures.size()])
	quit(1 if failures.size() > 0 else 0)
