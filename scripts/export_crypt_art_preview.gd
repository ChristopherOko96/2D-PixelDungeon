extends SceneTree
## Exports presentation caches for the asset contact sheet, without a game scene.
const Living = preload("res://src/living_sprite_library.gd")
const UnifiedSkin = preload("res://src/unified_dungeon_skin.gd")
const Palette = preload("res://src/tile_palette.gd")

func _initialize() -> void:
	var output := "res://.godot/art_preview/living"
	DirAccess.make_dir_recursive_absolute(output)
	for index in range(16):
		var id := "living_%03d" % index
		var fps := float(Living.definition(id).get("fps",4))
		for frame in range(4):
			var texture := Living.texture(id,(float(frame)+0.25)/fps,0)
			if texture == null:
				printerr("Animationsgrafik fehlt: ",id)
				quit(1)
				return
			texture.get_image().save_png(output.path_join("%s_f%d.png" % [id,frame]))
	var props_output := "res://.godot/art_preview/props"
	DirAccess.make_dir_recursive_absolute(props_output)
	for index in range(16):
		var id := "crypt_%03d" % index
		var texture := Palette.texture(id)
		if texture != null: texture.get_image().save_png(props_output.path_join(id+".png"))
	if UnifiedSkin.enabled():
		for group: String in ["violet","rose","moss","amber"]:
			UnifiedSkin.atlas(group).get_image().save_png("res://assets/crypt/unified/preview_atlas_%s.png" % group)
	print("CRYPT_ART_PRESENTATION_EXPORTED")
	quit()
