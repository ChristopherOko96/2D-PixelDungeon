extends SceneTree
## The hero's weapon as a rig item (M2d; src/rig_kit/rig_held.gd, rig_held_host.gd,
## src/rig/rig_renderer.gd draw_hero `held`, src/hero/hero_look.gd hold,
## src/hero/story_weapon_host.gd): every hero rig's weapon item carries a held
## block in the rig data; the rig asks its host for the pieces, placed for the
## figure standing still, draws them in the item's z slot after the body parts
## and carries them with the parent part (a hit recoil moves and turns the
## blade), rigidly; a figure at rest draws them exactly where they were placed;
## the hero look's pieces keep their geometry and take the rig data's grip and
## side; the drawn place reaches the look for a fall. Fake hosts, the real rig
## library, one canvas; no world.

const RigLibrary = preload("res://src/rig/rig_library.gd")
const RigRenderer = preload("res://src/rig/rig_renderer.gd")
const HeroLook = preload("res://src/hero/hero_look.gd")
const StoryWeaponHost = preload("res://src/hero/story_weapon_host.gd")
const ElementSkin = preload("res://src/hero/element_skin.gd")
## The hero rigs and the style each one's weapon item holds (story_hero.gd CLASS_RIGS).
const HEROES := {"knight": "sword", "elf": "bow", "wizard": "staff", "necro_hero": "staff"}
const AT := Vector2(240, 200)
const SIZE := 1.5
## A rig clock where the hero pose's breathing (1.3 s) and robe sway (0.9 s) both rest.
const REST_T := 5.85
const SWORD := "res://assets/sprites/0x72/weapon_knight_sword.png"
const BOW := "res://assets/sprites/0x72/weapon_bow.png"
const STAFF := "res://assets/sprites/0x72/weapon_green_magic_staff.png"

var checked := 0
var failures: Array[String] = []
var _canvas: Node2D
var _draw_fn := Callable()


## A host that holds one piece at the item's held hand and remembers what it saw.
class FakeHost extends RigHeldHost:
	var texture: Texture2D
	var asked: Array = []
	var placed: Array = []
	func pieces(key: String, item: Dictionary, rest: Transform2D) -> Array[Dictionary]:
		asked.append({"key": key, "item": str(item.id), "rest": rest})
		var hand: Vector2 = rest * Vector2(RigHeld.spec(item).hand)
		var size := texture.get_size() * 2.0
		var out: Array[Dictionary] = [{"texture": texture, "hand": hand, "angle": 0.4, "rect": Rect2(-size * 0.5, size), "main": true}]
		return out
	func drawn(_key: String, _id: String, list: Array[Dictionary]) -> void:
		placed = list.duplicate()


func check(condition: bool, label: String) -> void:
	checked += 1
	if not condition:
		failures.append(label)
		printerr("HERO_WEAPON_RIG_FAIL: ", label)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_canvas = Node2D.new()
	root.add_child(_canvas)
	_canvas.draw.connect(func() -> void: if _draw_fn.is_valid(): _draw_fn.call())
	var library: RefCounted = RigLibrary.shared()
	_test_rig_data(library)
	_test_follow_and_slot()
	await _test_rest_draws_in_place_after_the_body(library)
	await _test_recoil_carries_the_weapon(library)
	await _test_no_host_no_weapon(library)
	await _test_enemy_items_stay_their_own(library)
	_test_look_pieces()
	await _test_story_host_and_fall(library)
	_canvas.queue_free()
	print("HERO_WEAPON_RIG checked=%d failures=%d" % [checked, failures.size()])
	quit(1 if failures.size() > 0 else 0)


func _draw(fn: Callable) -> void:
	_draw_fn = fn
	_canvas.queue_redraw()
	await process_frame
	await process_frame
	_draw_fn = Callable()


func _test_rig_data(library: RefCounted) -> void:
	for rig_name: String in HEROES:
		var rig: Dictionary = library.rig(rig_name)
		var weapon: Dictionary = rig.get("by_id", {}).get("weapon", {})
		var spec := RigHeld.spec(weapon)
		check(not spec.is_empty() and str(spec.get("style", "")) == str(HEROES[rig_name]), "%s: the weapon item holds a %s (rig data held block)" % [rig_name, HEROES[rig_name]])
		check(spec.get("hand") is Vector2 and spec.get("grip") is Vector2, "%s: its hand and grip are points" % rig_name)
		check(rig.by_id.has(str(weapon.get("parent", ""))) and int(weapon.get("z", 0)) > 3, "%s: it hangs on a body part and is drawn over the parts" % rig_name)
		check(RigHeld.holds(rig), "%s: the rig holds run-time art" % rig_name)
	check(not RigHeld.holds(library.rig("skeleton")), "an enemy's own item holds nothing at run time")
	check(ElementSkin.class_for_rig("wizard") == "mage", "the mage still wears the wizard rig's element skin")


func _test_follow_and_slot() -> void:
	var rest := Transform2D(0.0, Vector2(10, 20)) * Transform2D(Vector2(3, 0), Vector2(0, 3), Vector2.ZERO)
	check(RigHeld.follow(rest, rest, Vector2(5, 5)) == Transform2D.IDENTITY, "a part that did not move carries nothing")
	var moved := Transform2D(0.0, Vector2(4, -2)) * rest
	var f := RigHeld.follow(rest, moved, Vector2(30, 40))
	check((f * Vector2(30, 40)).is_equal_approx(Vector2(34, 38)), "a moved part takes the hand along")
	var pivot := Vector2(16, 0)
	var turned := Transform2D(0.3, Vector2.ZERO) * rest
	var g := RigHeld.follow(rest, turned, pivot)
	check(is_equal_approx(g.get_rotation(), 0.3) and (g * pivot).is_equal_approx(Transform2D(0.3, Vector2.ZERO) * pivot), "a turned part turns the art about the hand")
	var squashed := rest * Transform2D(Vector2(1.0, 0), Vector2(0, 0.9), Vector2.ZERO)
	var h := RigHeld.follow(rest, squashed, Vector2(10, 50))
	check(is_equal_approx(h.x.length(), 1.0) and is_equal_approx(h.y.length(), 1.0), "a squashed part moves the hand but never stretches the art")
	var placed := RigHeld.place({"hand": pivot, "angle": 0.1}, g)
	check(is_equal_approx(float(placed.angle), 0.4) and Vector2(placed.hand).is_equal_approx(g * pivot), "a placed piece is moved and turned")
	var layers := [{"z": 1}, {"z": 2}, {"z": 2}, {"z": 5}]
	check(RigHeld.slot(layers, 2) == 3 and RigHeld.slot(layers, 0) == 0 and RigHeld.slot(layers, 9) == 4, "a held item goes in its z slot, after its equals")


## Draws the knight with `host` once (rig clock set to `t`, a hit when `hurt`).
func _knight(renderer: RefCounted, host: RigHeldHost, t: float, hurt := false) -> void:
	renderer.record_draws = true
	renderer.draw_log.clear()
	await _draw(func() -> void: renderer.draw_hero(_canvas, "hero", {"hp": 1, "hurts": 0}, AT, "knight", 1.0, 1.0, SIZE, Color.WHITE, host))
	renderer._actors.hero.t = t
	renderer.draw_log.clear()
	await _draw(func() -> void: renderer.draw_hero(_canvas, "hero", {"hp": 1, "hurts": 1 if hurt else 0}, AT, "knight", 1.0, 1.0, SIZE, Color.WHITE, host))


func _test_rest_draws_in_place_after_the_body(library: RefCounted) -> void:
	var renderer: RefCounted = RigRenderer.new(library)
	var host := FakeHost.new()
	host.texture = load(SWORD)
	await _knight(renderer, host, REST_T)
	check(not host.asked.is_empty() and str(host.asked[-1].item) == "weapon" and str(host.asked[-1].key) == "hero", "the rig asks its host for the weapon item's pieces")
	var rest: Transform2D = host.asked[-1].rest
	var rig: Dictionary = library.rig("knight")
	check((rest * Vector2(rig.ground)).distance_to(renderer.actor_feet("hero")) < 0.51, "the rest transform stands the figure on its feet")
	check(host.placed.size() == 1 and Vector2(host.placed[0].hand) == rest * Vector2(RigHeld.spec(rig.by_id.weapon).hand) and float(host.placed[0].angle) == 0.4,
		"at rest the weapon is drawn exactly where it was placed")
	var whats: Array = renderer.draw_log.map(func(e: Dictionary) -> String: return str(e.what))
	var held_at := whats.find("held")
	var last_part := whats.rfind("part")
	check(held_at > last_part and last_part >= 0, "the weapon is drawn in its z slot, over every body part")
	var drawn: Dictionary = renderer.last_drawn("hero")
	check((drawn.get("held", {}) as Dictionary).has("weapon") and not (drawn.get("shown", {}) as Dictionary).has("weapon"), "the drawn weapon is noted apart from the parts (x-ray and hits see the body only)")


func _test_recoil_carries_the_weapon(library: RefCounted) -> void:
	var renderer: RefCounted = RigRenderer.new(library)
	var host := FakeHost.new()
	host.texture = load(SWORD)
	await _knight(renderer, host, REST_T, true)
	var rest: Transform2D = host.asked[-1].rest
	var rest_hand: Vector2 = rest * Vector2(RigHeld.spec(library.rig("knight").by_id.weapon).hand)
	check(not host.placed.is_empty(), "a recoiling hero still holds his weapon")
	if host.placed.is_empty(): return
	var hand: Vector2 = host.placed[0].hand
	var body: Vector2 = renderer.world_point("hero", "body", Vector2(RigHeld.spec(library.rig("knight").by_id.weapon).hand))
	check(hand.distance_to(rest_hand) > 3.0, "the hit recoil moves the weapon with the body (%.1f px)" % hand.distance_to(rest_hand))
	check(hand.distance_to(body) < 0.01, "the hand stays on the body part's point")
	check(float(host.placed[0].angle) < 0.4 - 0.1, "and the blade turns with the recoil (%.2f rad)" % float(host.placed[0].angle))


func _test_no_host_no_weapon(library: RefCounted) -> void:
	var renderer: RefCounted = RigRenderer.new(library)
	renderer.record_draws = true
	await _draw(func() -> void: renderer.draw_hero(_canvas, "hero", {"hp": 1}, AT, "knight", 1.0, 1.0, SIZE))
	var whats: Array = renderer.draw_log.map(func(e: Dictionary) -> String: return str(e.what))
	check(not whats.has("held") and not (renderer.last_drawn("hero").get("held", {}) as Dictionary).has("weapon"), "without a host the rig draws no weapon (the crypt view draws its own)")
	var empty := RigHeldHost.new()
	renderer.draw_log.clear()
	await _draw(func() -> void: renderer.draw_hero(_canvas, "hero", {"hp": 1}, AT, "knight", 1.0, 1.0, SIZE, Color.WHITE, empty))
	check(not renderer.draw_log.any(func(e: Dictionary) -> bool: return str(e.what) == "held"), "a bare host holds nothing")


func _test_enemy_items_stay_their_own(library: RefCounted) -> void:
	# Arrange: an enemy whose sword is a plain rig item (no held block)
	var renderer: RefCounted = RigRenderer.new(library)
	renderer.record_draws = true
	# Act
	await _draw(func() -> void: renderer.draw_enemy(_canvas, {"rig": "skeleton", "uid": 3}, AT))
	# Assert
	var sword: Array = renderer.draw_log.filter(func(e: Dictionary) -> bool: return str(e.what) == "part" and str(e.id) == "weapon")
	check(sword.size() == 1 and not renderer.draw_log.any(func(e: Dictionary) -> bool: return str(e.what) == "held"), "an enemy's sword is still drawn as its own rig item")


func _test_look_pieces() -> void:
	var look := HeroLook.new(2.0)
	look.hero_px = 3.0
	var sword: Texture2D = load(SWORD)
	var knight := {"melee": true, "swings": 0, "class_id": "swordsman"}
	var point := Vector2(100, 100)
	var pieces: Array[Dictionary] = look.hold("k", knight, point, Vector2.RIGHT, 1.0, sword)
	var size := sword.get_size() * 2.0
	# the guard from assets/data/hero_weapon_motion.json: low before the body, blade up and leaning forward
	var guard: Dictionary = HeroLook.sword_motion().get("guard", {})
	var guard_hand := Vector2(float(guard.hand[0]), float(guard.hand[1])) * look.hero_px
	var guard_turn := float(guard.tilt)
	check(pieces.size() == 1 and bool(pieces[0].get("main", false)), "a resting sword is one piece, the hero's own")
	check(Vector2(pieces[0].hand).is_equal_approx(point + guard_hand) and is_equal_approx(float(pieces[0].angle), guard_turn) and Rect2(pieces[0].rect) == Rect2(-size * HeroLook.SWORD_GRIP, size),
		"the resting sword is held low before the body, its blade up and leaning forward, gripped near its pommel")
	check(Vector2(pieces[0].hand).y > point.y and absf(float(pieces[0].angle)) < PI * 0.5, "the resting blade does not point at the aim from the shoulder")
	var facing_left: Array[Dictionary] = look.hold("k", knight, point, Vector2.LEFT, 1.0, sword)
	check(Vector2(facing_left[0].hand).is_equal_approx(point + Vector2(-guard_hand.x, guard_hand.y)) and is_equal_approx(float(facing_left[0].angle), -guard_turn), "facing left the guard is mirrored")
	var spec := {"style": "sword", "grip": Vector2(0.5, 0.5), "rest": 0.25}
	var moved: Array[Dictionary] = look.hold("k", knight, point, Vector2.RIGHT, 1.0, sword, Color.WHITE, "", spec)
	check(Rect2(moved[0].rect) == Rect2(-size * 0.5, size) and is_equal_approx(float(moved[0].angle), guard_turn + 0.25), "the rig data's grip and rest replace the look's own")
	# a stroke: lifted, cut down through the aim past the arc, then back to the guard
	look.observe("s", knight, point, 0.0)
	knight.swings = 1
	knight.swing_angle = 0.0
	knight.swing_arc = 2.0
	knight.swing_dir = 1
	look.observe("s", knight, point, 1.0)
	var time := HeroLook.swing_time()
	var cut: Dictionary = HeroLook.sword_motion().get("swing", {})
	var mid_cut: Array[Dictionary] = look.hold("s", knight, point, Vector2.RIGHT, 1.0 + time * (float(cut.lift) + float(cut.strike)) * 0.5, sword)
	var follow: Array[Dictionary] = look.hold("s", knight, point, Vector2.RIGHT, 1.0 + time * (float(cut.strike) + float(cut.settle)) * 0.5, sword)
	var back: Array[Dictionary] = look.hold("s", knight, point, Vector2.RIGHT, 1.0 + time * 1.2, sword)
	check(float(mid_cut[0].angle) > guard_turn and (mid_cut[0].get("under") as Callable).is_valid(), "mid-stroke the blade has cut down from the guard and leaves a smear")
	check(float(follow[0].angle) > PI * 0.5 + 1.0, "the follow-through carries the blade past the end of the arc")
	check(is_equal_approx(float(back[0].angle), guard_turn) and Vector2(back[0].hand).is_equal_approx(point + guard_hand), "after the stroke the blade is back in the guard")
	var knife := {"melee": true, "swings": 0, "class_id": "archer"}
	var other: Array[Dictionary] = look.hold("e", knife, point, Vector2.RIGHT, 1.0, sword, Color.WHITE, "", {"style": "bow", "grip": Vector2(0.1, 0.1)})
	check(Rect2(other[0].rect) == Rect2(-size * HeroLook.SWORD_GRIP, size), "a held block of another style (the elf's bow, a knife in hand) is not used")
	knight.skills = {"rage": 5.0}
	var rage: Array[Dictionary] = look.hold("k", knight, point, Vector2.RIGHT, 1.0, sword)
	check(rage.size() == 2 and not bool(rage[0].get("main", false)) and bool(rage[1].get("main", false)), "Rage holds a second blade, drawn first")
	knight.skills = {"whirl_time": 0.3}
	var whirl: Array[Dictionary] = look.hold("k", knight, point, Vector2.RIGHT, 1.0, sword)
	check(whirl.size() == 1 and not bool(whirl[0].get("main", false)) and (whirl[0].get("under") as Callable).is_valid(), "the whirl's blade carries its rings under it and is not the held place")
	var archer := {"class_id": "archer", "shots": 0, "shot_interval": 0.5}
	var bow: Array[Dictionary] = look.hold("b", archer, point, Vector2.RIGHT, 1.0, load(BOW))
	check(bow.size() == 1 and Vector2(bow[0].hand) == point + Vector2(8, -2) and (bow[0].get("over") as Callable).is_valid(), "the bow is held before the shoulder with its string over it")
	var mage := {"class_id": "mage", "shots": 0}
	var staff_spec := {"style": "staff", "side": Vector2(4, 0), "length": 18.0}
	var staff: Array[Dictionary] = look.hold("m", mage, point, Vector2.RIGHT, 0.0, load(STAFF), Color.WHITE, "", staff_spec)
	check(Vector2(staff[0].hand).is_equal_approx(point + Vector2(12, 0)) and is_equal_approx(Rect2(staff[0].rect).size.y, 54.0), "the staff stands at the rig data's side, as tall as its length")
	var left: Array[Dictionary] = look.hold("m", mage, point, Vector2.LEFT, 0.0, load(STAFF), Color.WHITE, "", staff_spec)
	check(Vector2(left[0].hand).is_equal_approx(point + Vector2(-12, 0)), "facing left it changes hands")


func _test_story_host_and_fall(library: RefCounted) -> void:
	var renderer: RefCounted = RigRenderer.new(library)
	var look := HeroLook.new(2.0)
	look.hero_px = 3.0
	var host := StoryWeaponHost.new(look)
	var view := {"melee": true, "swings": 0, "class_id": "swordsman"}
	host.frame(view, Vector2.RIGHT, 1.0, load(SWORD), Color.WHITE, "", true)
	await _draw(func() -> void: renderer.draw_hero(_canvas, "hero", {"hp": 1, "hurts": 0}, AT, "knight", 1.0, 1.0, SIZE, Color.WHITE, host))
	renderer._actors.hero.t = REST_T
	await _draw(func() -> void: renderer.draw_hero(_canvas, "hero", {"hp": 1, "hurts": 1}, AT, "knight", 1.0, 1.0, SIZE, Color.WHITE, host))
	var drawn: Array = renderer.last_drawn("hero").get("held", {}).get("weapon", [])
	check(drawn.size() == 1, "the story host puts the hero's sword into the knight's hand")
	if drawn.is_empty(): return
	var held: Dictionary = look._held.get("hero", {})
	check(not held.is_empty() and Vector2(held.hand) == Vector2(drawn[0].hand) and float(held.angle) == float(drawn[0].angle), "the look keeps where the rig drew it")
	var throw: Dictionary = look._throw(held, 0.0, 300.0, 1.0)
	var piece: Dictionary = (throw.debris as RigDebris).pieces[0]
	var center: Vector2 = Vector2(held.hand) + Rect2(held.rect).get_center().rotated(float(held.angle))
	check(is_equal_approx(float(piece.x), center.x) and is_equal_approx(float(piece.y) - float(piece.z), center.y), "a fall throws the weapon from the hand the rig carried")
	host.frame(view, Vector2.RIGHT, 1.0, load(SWORD), Color.WHITE, "", false)
	await _draw(func() -> void: renderer.draw_hero(_canvas, "hero", {"hp": 0, "hurts": 1}, AT, "knight", 1.0, 1.0, SIZE, Color.WHITE, host))
	check(not (renderer.last_drawn("hero").get("held", {}) as Dictionary).has("weapon"), "a fallen hero's rig holds nothing (his weapon falls on its own)")
