extends RefCounted
## Small cached pieces of approved tail pixels. Only the lower rig parts shed;
## heads/eyes stay intact. All recycling fades out before position wraps.
static var _pieces: Dictionary = {}
static var _pixel: Texture2D

## Tiny source-pixel textures are created once, never during a draw or sample.
static func prepare_part(key: String, part: Dictionary) -> void:
	if _pieces.has(key): return
	var image: Image = part.image
	var area := image.get_used_rect()
	var pieces: Array = []
	for y in range(area.position.y, area.end.y, 2):
		for x in range(area.position.x, area.end.x, 2):
			var rect := Rect2i(x, y, mini(2, area.end.x - x), mini(2, area.end.y - y))
			if not image.get_region(rect).get_used_rect().has_area(): continue
			var texture := ImageTexture.create_from_image(image.get_region(rect))
			pieces.append({"texture": texture, "at": Vector2(rect.position), "bounds": Rect2(Vector2.ZERO, Vector2(rect.size)), "seed": fposmod(float(pieces.size()) * 0.6180339, 1.0)})
	_pieces[key] = pieces
	if _pixel == null:
		var white := Image.create(1, 1, false, Image.FORMAT_RGBA8)
		white.fill(Color.WHITE)
		_pixel = ImageTexture.create_from_image(white)

## Turn sampled motes into the same wall-clipped batch as the rig cutouts.
static func mote_parts(samples: Array, art: float, opacity: float) -> Array:
	var result: Array = []
	var colors := [Color("286d83"), Color("47b6bd"), Color("b9f1ed")]
	for i in range(samples.size()):
		var mote: Dictionary = samples[i]
		var size := float(mote.get("size", 1.0)) * art
		var tint: Color = colors[i % colors.size()]
		tint.a = float(mote.alpha) * opacity
		var xform := Transform2D(Vector2(size, 0), Vector2(0, size), Vector2(mote.at))
		result.append({"id": "dust:%d" % i, "texture": _pixel, "bounds": Rect2(0, 0, 1, 1), "transform": xform, "tint": tint})
	return result

## Native local offsets, deterministic across render rates and late snapshots.
static func sample(age: float, seed: float, cycle: float, spread: float, travel: float) -> Dictionary:
	var p := fposmod(maxf(0.0, age) / maxf(0.2, cycle) + seed, 1.0)
	return {"offset": Vector2(sin(p * PI * 1.4 + seed * TAU) * spread * p, travel * p),
		"alpha": smoothstep(0.0, 0.12, p) * (1.0 - smoothstep(0.6, 1.0, p))}

## Keep a coherent upper strand; replace the tip with moving original pixels.
static func parts(source: Array, age: float, family: String, cfg: Dictionary = {}) -> Array:
	var result: Array = []
	var size_factor := 0.55 if family == "spirit" else 1.0
	for part: Dictionary in source:
		var key := family + ":" + str(part.id)
		if not _pieces.has(key):
			result.append(part)
			continue
		var amount := 1.0 if str(part.id) == "tail_tip" else 0.55
		var index := 0
		for piece: Dictionary in _pieces[key]:
			var motion := sample(age, float(piece.seed), float(cfg.get("fragment_cycle", 1.8)), float(cfg.get("fragment_spread", 4.0)) * size_factor, float(cfg.get("fragment_travel", 8.0)) * size_factor)
			var tint: Color = part.tint
			var xform: Transform2D = part.transform
			if amount < 1.0:
				result.append({"id": "%s:core:%d" % [part.id, index], "texture": piece.texture, "bounds": piece.bounds,
					"transform": xform * Transform2D(0.0, piece.at), "tint": Color(tint, tint.a * (1.0 - amount))})
			result.append({"id": "%s:mote:%d" % [part.id, index], "texture": piece.texture, "bounds": piece.bounds,
				"transform": xform * Transform2D(0.0, Vector2(piece.at) + Vector2(motion.offset)), "tint": Color(tint, tint.a * amount * float(motion.alpha))})
			index += 1
	return result
