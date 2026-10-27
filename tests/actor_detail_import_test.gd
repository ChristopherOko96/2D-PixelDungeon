extends "res://scripts/import_actor_detail_keys.gd"
## Uneven generated rows must retain full boots instead of quarter-sheet cuts.
func _initialize() -> void:
	if not has_method("_source_crops"):
		printerr("DETAIL_CROP_FAIL: importer needs silhouette extraction for uneven generated rows")
		print("DETAIL_CROP checked=1 failures=1")
		quit(1)
		return
	profile = {"alpha_threshold":0.6}
	var fixture := Image.create(160,120,false,Image.FORMAT_RGBA8)
	for row: int in range(4):
		for column: int in range(4):
			var y: int = [3,41,65,90][row]
			var height: int = 32 if row == 0 else 18
			fixture.fill_rect(Rect2i(column*40+8,y,12,height),Color(0.2+column*0.2,0.3,0.3+row*0.15,1))
			fixture.fill_rect(Rect2i(column*40+8,y+height-1,12,1),Color.MAGENTA)
	var extracted: Array = call("_source_crops",fixture)
	var failures: int = 0
	if extracted.size() != 16: failures += 1
	for index: int in range(extracted.size()):
		var expected_height: int = 32 if index < 4 else 18
		if extracted[index].get_height() != expected_height or extracted[index].get_width() != 12: failures += 1
		if extracted[index].get_pixel(0,expected_height-1) != Color.MAGENTA: failures += 1
	print("DETAIL_CROP checked=%d failures=%d"%[1+extracted.size()*2,failures])
	quit(0 if failures == 0 else 1)
