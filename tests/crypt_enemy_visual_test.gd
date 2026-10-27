extends SceneTree
## Asset/feedback integration fixture, not a performance or played-run test.
const Sprites = preload("res://src/crypt_enemy_sprites.gd")
const Feedback = preload("res://src/vfx/feedback.gd")
var checked: int = 0
var failed: int = 0

func _initialize() -> void:
	var library := Sprites.new()
	var textures: Array[Texture2D] = library.prepare()
	check(textures.size() == 36,"three crypt roles each load twelve real animation frames")
	for texture: Texture2D in textures:
		check(texture.get_size() == Vector2(32,48),"each native canvas is32x48 without distortion")
		var image: Image = texture.get_image()
		check(image.get_used_rect().has_area(),"animation frame contains visible pixels")
	var entity: Dictionary = {"id":7,"kind":"skeleton_guard","x":120.0,"y":160.0,"hp":11,"max_hp":11,"hits":0,"attacks":0,"blocks":0,"face":1.0,"dying_p":-1.0,"attack":"","moving":false}
	for kind: String in Sprites.KINDS:
		entity.kind = kind
		check(library.frame(kind,entity,0.0) != null,"idle frame is available for "+kind)
		entity.attack = "windup"
		entity.attack_p = 0.8
		var windup: Texture2D = library.frame(kind,entity,0.0)
		entity.attack = "active"
		check(library.frame(kind,entity,0.0) != windup,"release uses a different authored frame for "+kind)
		entity.attack = ""
	entity.kind = "skeleton_guard"
	var feedback := Feedback.new()
	var snapshot: Dictionary = {"room_layout":{"id":"visual-fixture"},"enemies":[entity],"players":{}}
	feedback.observe(snapshot,1)
	entity.blocks = 1
	feedback.observe(snapshot,1)
	check(float(feedback.pose("e7",entity,0.0).flash) > 0,"a shield block creates visible feedback even without a flesh hit")
	var first: float = float(feedback.pose("e7",entity,0.0).flash)
	feedback.update(0.2)
	feedback.observe(snapshot,1)
	check(float(feedback.pose("e7",entity,0.0).flash) < first,"repeated snapshots cannot replay the same block flash")
	entity.hits = 1
	feedback.observe(snapshot,1)
	check(float(feedback.pose("e7",entity,0.0).flash) > 0,"ordinary hit feedback remains connected for the new role")
	print("CRYPT_ENEMY_VISUAL checked=%d failures=%d" % [checked,failed])
	quit(1 if failed else 0)

func check(condition: bool, label: String) -> void:
	checked += 1
	if not condition:
		failed += 1
		printerr("CRYPT_VISUAL_FAIL: ",label)
