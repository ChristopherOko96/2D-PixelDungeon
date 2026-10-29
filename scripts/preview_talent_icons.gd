extends SceneTree
## Writes one sheet with every talent icon (rows = branches, 2x like in game)
## for a quick look: production/qa/evidence/attacks/talent-icons.png.
##   godot --headless --path . -s res://scripts/preview_talent_icons.gd
const TalentIcons = preload("res://src/ui/talent_icons.gd")
const Profile = preload("res://src/progress/profile.gd")

func _initialize() -> void:
	var d := Profile.data()
	var specs: Dictionary = {}
	for c: Dictionary in d.classes.values():
		for s: Dictionary in c.specs: specs[str(s.id)] = s
	var rows: Dictionary = {}
	for id: String in d.talents:
		var t: Dictionary = d.talents[id]
		if not rows.has(str(t.spec)): rows[str(t.spec)] = []
		rows[str(t.spec)].append(t)
	var cell := 40
	var sheet := Image.create(cell * 6 + 8, cell * rows.size() + 8, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("2a2430"))
	var y := 0
	for spec: String in rows:
		var list: Array = rows[spec]
		list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.index) < int(b.index))
		for x in range(list.size()):
			var t: Dictionary = list[x]
			var img := TalentIcons.make(specs[spec], str(t.icon), true, str(t.kind) == "ultimate").get_image()
			img.resize(36, 36, Image.INTERPOLATE_NEAREST)
			sheet.blit_rect(img, Rect2i(0, 0, 36, 36), Vector2i(4 + x * cell, 4 + y * cell))
		y += 1
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://production/qa/evidence/attacks"))
	sheet.resize(sheet.get_width() * 2, sheet.get_height() * 2, Image.INTERPOLATE_NEAREST)
	print("SAVED ", sheet.save_png("res://production/qa/evidence/attacks/talent-icons.png"))
	quit()
