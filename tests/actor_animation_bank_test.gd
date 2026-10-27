extends SceneTree
## Catalog/runtime integration: actual atlas frames, never aliases counted as actions.
var checked: int = 0
var failed: int = 0

func check(ok: bool, label: String) -> void:
	checked += 1
	if not ok:
		failed += 1
		printerr("ACTOR_BANK_FAIL: ",label)

func _initialize() -> void:
	if not FileAccess.file_exists("res://src/actor_animation_bank.gd"):
		check(false,"actor animation bank exists")
		_finish()
		return
	var bank: RefCounted = load("res://src/actor_animation_bank.gd").new()
	check(bank.prepare(),"all eight real actor atlases and manifests are ready")
	check(bank.actors().size() == 8,"catalog includes four players, three crypt enemies and boss")
	for actor: String in bank.actors():
		var actions: Array = bank.animations(actor)
		check(actions.size() == 48,"48 separate actions for "+actor)
		for direction: String in ["south","east","north","west"]:
			var clip_hashes: Dictionary = {}
			for clip: String in actions:
				var hashes: Dictionary = {}
				var combined: PackedByteArray = PackedByteArray()
				for frame: int in range(6):
					var record: Dictionary = bank.sample(actor,clip,direction,float(frame)*bank.duration(clip)/6.0,false)
					check(not record.is_empty(),"frame exists "+actor+"/"+clip+"/"+direction+"/"+str(frame))
					if record.is_empty(): continue
					var pixels: PackedByteArray = record.texture.get_image().get_data()
					hashes[pixels.hex_encode().sha256_text()] = true
					combined.append_array(pixels)
					check(record.flash_texture != null,"cached flash frame exists")
				check(hashes.size() >= 3,"action contains at least three actual pixel poses: "+actor+"/"+clip+"/"+direction)
				var digest: String = combined.hex_encode().sha256_text()
				check(not clip_hashes.has(digest),"actions do not alias the same frame sequence: "+actor+"/"+clip+"/"+direction)
				clip_hashes[digest] = true
		var first: Dictionary = bank.sample(actor,"walk_forward","east",0.0)
		var repeated: Dictionary = bank.sample(actor,"walk_forward","east",0.0)
		check(not first.is_empty() and first.texture == repeated.get("texture"),"sampling reuses cached frame objects")
		var last: Dictionary = bank.sample(actor,"death_fall","east",999.0,false)
		check(not last.is_empty() and int(last.frame) == 5,"nonlooping clips hold final frame")
		var wrapped: Dictionary = bank.sample(actor,"walk_forward","east",bank.duration("walk_forward")*3.0,true)
		check(not wrapped.is_empty() and int(wrapped.frame) == 0,"looping clips wrap by their own duration")
		check(bank.sample(actor,"missing","east",0.0).is_empty(),"unknown clips return no guessed animation")
		check(bank.sample(actor,"walk_forward","invalid",0.0).is_empty(),"unknown directions return no incorrect mirror")
		check(bank.sample(actor,"walk_forward","east",NAN).is_empty(),"nonfinite playback times are rejected")
		check(bank.sample(actor,"walk_forward","east",INF).is_empty(),"infinite playback times are rejected")
		var huge: Dictionary = bank.sample(actor,"walk_forward","east",1.0e100)
		check(not huge.is_empty() and int(huge.frame) in range(6),"finite but enormous times wrap before integer conversion")
		var negative: Dictionary = bank.sample(actor,"walk_forward","east",-100.0)
		check(not negative.is_empty() and int(negative.frame) == 0,"negative playback starts at first frame")
		var mask_source: PackedByteArray = first.texture.get_image().get_data()
		var mask: PackedByteArray = first.flash_texture.get_image().get_data()
		var mask_correct: bool = mask.size() == mask_source.size()
		for offset: int in range(0,mask.size(),4):
			mask_correct = mask_correct and mask[offset+3] == mask_source[offset+3]
			if mask[offset+3] > 0: mask_correct = mask_correct and mask[offset] == 255 and mask[offset+1] == 255 and mask[offset+2] == 255
		check(mask_correct,"prebaked white hitflash preserves exact alpha")
	check(bank.cache_size() == 8*48*4*6,"frame cache bounded by real roster × clips × directions × frames")
	var cached_count: int = bank.cache_size()
	for time: int in range(1000): bank.sample("player_warden","walk_forward","south",float(time))
	check(bank.cache_size() == cached_count,"elapsed time cannot grow the frame cache")
	check(bank.prepare(),"repeated prepare keeps existing shared textures")
	_finish()

func _finish() -> void:
	print("ACTOR_BANK checked=%d failures=%d" % [checked,failed])
	quit(1 if failed else 0)
