extends SceneTree
## Pure enemy rules (src/hell/mob_rules.gd): the roster only offers kinds whose
## first floor is reached and picks by weight, a shield blocks hits from the
## front but not from behind or the side, splits name their children, and
## animated sprites cycle their frame names.

const MobRules = preload("res://src/hell/mob_rules.gd")
const ROSTER := [{"kind": "a", "from": 1, "weight": 1}, {"kind": "b", "from": 1, "weight": 3}, {"kind": "c", "from": 5, "weight": 4}]
var checked := 0
var failures: Array[String] = []


func check(condition: bool, description: String) -> void:
	checked += 1
	if not condition:
		failures.append(description)
		printerr("MOB_RULES_FAIL: ", description)


func _initialize() -> void:
	test_roster_hides_kinds_before_their_floor()
	test_pick_follows_weights()
	test_shield_blocks_front_only()
	test_split_and_frames()
	print("MOB_RULES checked=%d failures=%d" % [checked, failures.size()])
	quit(1 if failures.size() > 0 else 0)


func test_roster_hides_kinds_before_their_floor() -> void:
	# Act
	var early := MobRules.floor_roster(ROSTER, 1)
	var late := MobRules.floor_roster(ROSTER, 5)
	# Assert
	check(early.size() == 2 and late.size() == 3, "kind c joins on floor 5")
	check(MobRules.pick_kinds([], 3, [0.5]).is_empty(), "an empty roster picks nothing")


func test_pick_follows_weights() -> void:
	# Arrange: on floor 1 weights a=1, b=3 cover 0..0.25 and 0.25..1
	var rolls := [0.0, 0.2, 0.26, 0.99]
	# Act
	var kinds := MobRules.pick_kinds(ROSTER, 1, rolls)
	# Assert
	check(kinds == ["a", "a", "b", "b"], "rolls map onto the weights (%s)" % [kinds])
	check(not ("c" in MobRules.pick_kinds(ROSTER, 4, [0.99, 0.7])), "no c before floor 5")


func test_shield_blocks_front_only() -> void:
	# Arrange: the knight faces left (towards a hero on its left)
	var facing := Vector2.LEFT
	# Act / Assert: a shot from the hero flies right, into the shield
	check(MobRules.shield_blocks(facing, Vector2.RIGHT, 1.6), "a hit from the front is blocked")
	check(not MobRules.shield_blocks(facing, Vector2.LEFT, 1.6), "a hit from behind gets through")
	check(not MobRules.shield_blocks(facing, Vector2.DOWN, 1.6), "a hit from the side gets through")


func test_split_and_frames() -> void:
	# Act / Assert
	check(MobRules.split_children({"split": {"into": "s", "count": 2}}) == ["s", "s"], "a split names its children")
	check(MobRules.split_children({}).is_empty(), "no split, no children")
	check(MobRules.frame_name({"sprite": "mob_x_f", "frames": 4}, 5) == "mob_x_f1", "animated sprites cycle frames")
	check(MobRules.frame_name({"sprite": "mob_y", "frames": 1}, 7) == "mob_y", "single sprites keep their name")
