extends SceneTree
## Cached glass masks, real joint separation and distinct element icon palettes.
const Art = preload("res://src/vfx/alchemist_art.gd")
const Icons = preload("res://src/ui/talent_icons.gd")
var checked := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checked += 1
	if not ok:
		failures += 1
		printerr("ALCHEMIST_ART_FAIL ",label)
func _initialize() -> void:
	var signatures: Dictionary = {}
	for recipe: String in ["poison","water","fire","frost","shatter"]:
		var closed := Art.parts(Vector2.ZERO,recipe,2,0)
		var opening := Art.parts(Vector2.ZERO,recipe,2,0.1,0.4)
		check(closed.size()==5,"five real masks for "+recipe)
		var pixels := 0
		for n in range(closed.size()):
			var part: Dictionary = closed[n]
			check(part.texture == opening[n].texture,"posing reuses cached glass texture")
			var image: Image = part.texture.get_image()
			for y in range(image.get_height()):
				for x in range(image.get_width()):
					if image.get_pixel(x,y).a>0.5: pixels += 1
		check(pixels>50,"real nonempty glass source masks")
		check(closed[0].transform!=opening[0].transform and closed[1].transform!=opening[1].transform,"cork and shell move independently")
		var icon := Icons.make({"id":"trapper","color":"7cc23a","color2":"e2ff9e"},"alchemy_"+recipe,true)
		signatures[icon.get_image().get_data().hex_encode().sha256_text()] = true
	check(signatures.size()==5,"all five capsule icons are visibly distinct")
	print("ALCHEMIST_ART checked=%d failures=%d" % [checked,failures])
	quit(1 if failures else 0)
