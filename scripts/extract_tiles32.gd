extends SceneTree
## Reproducible slicing of user-provided sheets; originals remain unchanged.
func _initialize() -> void:
	var output := "res://assets/tilesets/cells32"
	DirAccess.make_dir_recursive_absolute(output)
	var count := 0
	for group: String in ["violet","rose","moss","amber","items"]:
		var source := "res://assets/items/item_sheet_items.png" if group == "items" else "res://assets/tilesets/dungeon_%s.png" % group
		var sheet := Image.load_from_file(source)
		if sheet == null or sheet.is_empty():
			printerr("Missing sheet: ",source)
			quit(1)
			return
		var columns := sheet.get_width()/16
		for index in range(56):
			var cell := sheet.get_region(Rect2i((index%columns)*16,(index/columns)*16,16,16))
			cell.resize(32,32,Image.INTERPOLATE_NEAREST)
			if cell.save_png(output.path_join("%s_%03d.png" % [group,index])) != OK:
				quit(1)
				return
			count += 1
	print("EXTRACTED_TILES32 count=",count)
	quit()
