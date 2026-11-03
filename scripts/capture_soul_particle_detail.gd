extends SceneTree
## GPU close-up of the actual shared VFX renderer; sustained presentation
## fixture, no game state, combat, inventory or profile changes.
const OUT := "res://output/soul-field-particles/detail-frames"
const EVIDENCE := "res://production/qa/evidence/soul-field-particles"

class Stage extends Node2D:
	const Field = preload("res://src/vfx/soul_field.gd")
	const Guardian = preload("res://src/vfx/soul_guardian_art.gd")
	const Sprites = preload("res://src/vfx/fx_sprites.gd")
	const Pools = preload("res://src/vfx/pool_paint.gd")
	var clock := 1.0
	var sprites := Sprites.new()
	var pools: RefCounted
	var cfg: Dictionary
	var floor_texture: Texture2D = preload("res://assets/sprites/floor_stone.png")
	func _ready() -> void:
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		Field.prepare()
		Guardian.prepare()
		cfg = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/vfx_talents.json")).soul_motion
		sprites.floor_open = func(_point: Vector2) -> bool: return true
		pools = Pools.new(2.0, sprites.floor_open)
		pools.add(1, "soul", Vector2(215, 330), Vector2.ZERO, 110, 0, 1000, "detail")
	func _draw() -> void:
		for y in range(0, 448, 32):
			for x in range(0, 768, 32): draw_texture(floor_texture, Vector2(x, y), Color(0.58, 0.52, 0.60))
		pools.draw(self, clock)
		Field.draw(self, Vector2(215, 330), 110, clock * float(cfg.field_playback), sprites, "detail", true, 1.0, cfg)
		Guardian.draw(self, {"id": 1, "x": 570.0, "y": 330.0, "face": 1.0, "motion": "hover", "duration": 1.6, "left": 12.0}, fposmod(clock, 1.6), 3.0, sprites, clock, cfg)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(EVIDENCE))
	root.size = Vector2i(768, 448)
	root.content_scale_size = Vector2i(768, 448)
	var stage := Stage.new()
	root.add_child(stage)
	for i in range(65): await process_frame
	for frame in range(192):
		stage.clock = 1.0 + float(frame) / 30.0
		stage.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		var picture := root.get_texture().get_image()
		picture.save_png(OUT.path_join("frame-%03d.png" % frame))
		if frame in [0, 32, 64, 96, 128, 160, 191]: picture.save_png(EVIDENCE.path_join("detail-%03d.png" % frame))
	print("SOUL_PARTICLE_DETAIL frames=192 simulated_seconds=6.4")
	stage.queue_free()
	await process_frame
	quit()
