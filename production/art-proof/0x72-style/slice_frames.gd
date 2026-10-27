extends SceneTree
## Style proof helper: cuts a row of equally sized frames out of a sheet,
## unchanged, and saves them as <prefix>_f<i>.png. Usage:
##   godot --headless -s slice_frames.gd -- <sheet.png> <x> <y> <w> <h> <count> <out_dir> <prefix>
func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	var sheet := Image.load_from_file(a[0])
	var origin := Vector2i(int(a[1]), int(a[2]))
	var size := Vector2i(int(a[3]), int(a[4]))
	for index in range(int(a[5])):
		var frame := sheet.get_region(Rect2i(origin + Vector2i(size.x * index, 0), size))
		var path := a[6].path_join("%s_f%d.png" % [a[7], index])
		frame.save_png(path)
		print("FRAME ", path, " used=", frame.get_used_rect())
	quit()
