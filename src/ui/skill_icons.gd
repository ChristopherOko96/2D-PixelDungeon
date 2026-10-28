extends RefCounted
## Class-matching icons for skills, level-up cards and boss perks, 32x32 pixel
## images: the class's own 0x72 weapon (sword, bow, arrow, staff) plus a drawn
## effect glyph (skills) or a small corner badge (upgrades, passives, perks).
## So a swordsman's card never shows a bow. Specs come from hero_skills.json
## ({base, glyph, badge}); general perks map their category to a badge on the
## class weapon. Cached per spec.

const ClassPerks = preload("res://src/player/class_perks.gd")
const PerkIcons = preload("res://src/perk_icons.gd")
const SPRITES := "res://assets/sprites/0x72/"
const OUTLINE := Color("1a1414")
const SIZE := 32
## General perk categories that are about the weapon get the class weapon.
const WEAPON_CATEGORIES := {"Kraft": "up", "Tempo": "clock", "Geschosse": "pierce", "Präzision": "crit", "Schussmuster": "fan", "Flugbahn": "return", "Feuer": "fire", "Gift": "poison", "Frost": "snow", "Blitz": "bolt", "Elemente": "burst", "Risiko": "skull", "Schutz": "shield", "Heilung": "drop", "Bewegung": "wind", "Rast": "shield"}
const BADGE_COLORS := {"plus": "f4d383", "double": "f4d383", "magnet": "b0a4ff", "fire": "f39a3c", "wide": "f4d383", "fan": "f4d383", "return": "9fd8ff", "up": "ff7a5c", "range": "9fd8ff", "ring": "dfe6ff", "clock": "f4d383", "push": "e6dcc6", "skull": "e6dcc6", "crit": "ffe66b", "shards": "bfeaf2", "poison": "8fdc4a", "target": "ff6a5c", "burst": "ffb04a", "wind": "c8f0ff", "snow": "bfeaf2", "wall": "c9b49a", "mirror": "b38cf0", "shield": "8fb8ff", "heart": "ff5a6a", "drop": "e0404a", "eye": "8fdcff", "pierce": "e6dcc6", "bolt": "ffe66b"}

static var _cache: Dictionary = {}
static var _sprites: Dictionary = {}


## Icon of a skill, upgrade or passive card ({base, glyph, badge}).
static func icon(spec: Dictionary) -> Texture2D:
	var key := "%s|%s|%s" % [spec.get("base", ""), spec.get("glyph", ""), spec.get("badge", "")]
	if _cache.has(key): return _cache[key]
	var image := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var base := str(spec.get("base", ""))
	var glyph := str(spec.get("glyph", ""))
	if not base.is_empty():
		var sprite := _sprite(base)
		if sprite != null:
			# With a glyph the weapon stands left; alone it is centred.
			var x := 2 if not glyph.is_empty() else (SIZE - sprite.get_width()) / 2
			_blit(image, sprite, Vector2i(x, (SIZE - sprite.get_height()) / 2))
	if not glyph.is_empty(): _glyph(image, glyph, Vector2i(14, 8))
	var badge := str(spec.get("badge", ""))
	if not badge.is_empty(): _badge(image, badge)
	_outline(image)
	var texture := ImageTexture.create_from_image(image)
	_cache[key] = texture
	return texture


## Icon of a skill slot (class, slot 0-3).
static func skill(class_id: String, index: int) -> Texture2D:
	return icon(ClassPerks.skill_at(class_id, index).get("icon", {}))


## Icon of any offered card. General perks (boss loot) show the hero's own
## weapon with a category badge when they are about the weapon.
static func card(card_data: Dictionary, class_id: String) -> Texture2D:
	if card_data.has("icon") and card_data.icon is Dictionary: return icon(card_data.icon)
	var category := str(card_data.get("category", ""))
	if WEAPON_CATEGORIES.has(category):
		var weapon := str(ClassPerks.class_data(class_id).get("weapon_icon", "weapon_knight_sword"))
		return icon({"base": weapon, "badge": WEAPON_CATEGORIES[category]})
	return PerkIcons.texture(str(card_data.get("id", "")), card_data)


static func _sprite(name: String) -> Image:
	if _sprites.has(name): return _sprites[name]
	var path := SPRITES + name + ".png"
	var image: Image = null
	if ResourceLoader.exists(path):
		var texture: Texture2D = load(path)
		image = texture.get_image().duplicate()
		if image.is_compressed(): image.decompress()
		image.convert(Image.FORMAT_RGBA8)
		# Fit into the icon: anything taller than 28 px is halved.
		if image.get_height() > 28: image.resize(maxi(1, image.get_width() * 28 / image.get_height()), 28, Image.INTERPOLATE_NEAREST)
	_sprites[name] = image
	return image


static func _blit(target: Image, source: Image, at: Vector2i) -> void:
	target.blend_rect(source, Rect2i(Vector2i.ZERO, source.get_size()), at)


static func _px(image: Image, x: int, y: int, color: Color) -> void:
	if x >= 0 and y >= 0 and x < SIZE and y < SIZE: image.set_pixel(x, y, color)


static func _line(image: Image, a: Vector2i, b: Vector2i, color: Color) -> void:
	var steps := maxi(absi(b.x - a.x), absi(b.y - a.y))
	for i in range(steps + 1):
		var t := float(i) / float(maxi(steps, 1))
		_px(image, roundi(lerpf(a.x, b.x, t)), roundi(lerpf(a.y, b.y, t)), color)


static func _rect(image: Image, at: Vector2i, size: Vector2i, color: Color) -> void:
	for y in range(size.y):
		for x in range(size.x): _px(image, at.x + x, at.y + y, color)


static func _disc(image: Image, center: Vector2, radius: float, color: Color) -> void:
	for y in range(int(center.y - radius) - 1, int(center.y + radius) + 2):
		for x in range(int(center.x - radius) - 1, int(center.x + radius) + 2):
			if Vector2(x + 0.5, y + 0.5).distance_to(center) <= radius: _px(image, x, y, color)


static func _arc(image: Image, center: Vector2, radius: float, from: float, to: float, color: Color) -> void:
	var steps := int(absf(to - from) * radius * 1.5) + 2
	for i in range(steps + 1):
		var angle := lerpf(from, to, float(i) / float(steps))
		var point := center + Vector2.from_angle(angle) * radius
		_px(image, int(floor(point.x)), int(floor(point.y)), color)


## Effect glyphs in a 16x16 box at `o` (skills).
static func _glyph(image: Image, name: String, o: Vector2i) -> void:
	var c := Vector2(o) + Vector2(8, 8)
	match name:
		"swirl":
			_arc(image, c, 6.5, 0.3, 5.6, Color("f2f2f2"))
			_arc(image, c, 5.5, 0.3, 5.6, Color("bcc6d0"))
			_line(image, Vector2i(c + Vector2(6, -2)), Vector2i(c + Vector2(3, -5)), Color("f2f2f2"))
		"crescent":
			for r in [7.0, 6.0, 5.0]: _arc(image, c + Vector2(-2, 0), r, -1.3, 1.3, Color("f2f8ff") if r > 5.5 else Color("a8c4dc"))
		"dash":
			for row in [-4, 0, 4]: _line(image, Vector2i(o.x + 1, int(c.y) + row), Vector2i(o.x + 9 - absi(row), int(c.y) + row), Color("e6dcc6"))
			_line(image, Vector2i(o.x + 10, int(c.y) - 5), Vector2i(o.x + 15, int(c.y)), Color("ffffff"))
			_line(image, Vector2i(o.x + 10, int(c.y) + 5), Vector2i(o.x + 15, int(c.y)), Color("ffffff"))
		"rage":
			_disc(image, c, 6.5, Color("a8241c"))
			_disc(image, c + Vector2(0, 1), 4.0, Color("ff5a3a"))
			_line(image, Vector2i(c + Vector2(-5, 5)), Vector2i(c + Vector2(5, -5)), Color("f2f2f2"))
			_line(image, Vector2i(c + Vector2(-5, -5)), Vector2i(c + Vector2(5, 5)), Color("f2f2f2"))
		"fan":
			for angle in [-0.5, 0.0, 0.5]:
				var tip := c + Vector2.from_angle(angle - PI * 0.5) * 7.0
				_line(image, Vector2i(c + Vector2(0, 6)), Vector2i(tip), Color("e6dcc6"))
				_px(image, int(tip.x), int(tip.y), Color("ffffff"))
		"pierce":
			_arc(image, c, 5.0, 0.0, TAU, Color("ff6a5c"))
			_line(image, Vector2i(o.x, int(c.y)), Vector2i(o.x + 15, int(c.y)), Color("f2f2f2"))
			_line(image, Vector2i(o.x + 12, int(c.y) - 3), Vector2i(o.x + 15, int(c.y)), Color("f2f2f2"))
			_line(image, Vector2i(o.x + 12, int(c.y) + 3), Vector2i(o.x + 15, int(c.y)), Color("f2f2f2"))
		"leap":
			_arc(image, c + Vector2(2, 4), 6.0, PI, TAU - 0.4, Color("c8f0ff"))
			_line(image, Vector2i(c + Vector2(-4, 4)), Vector2i(c + Vector2(-7, 1)), Color("c8f0ff"))
			_line(image, Vector2i(c + Vector2(-4, 4)), Vector2i(c + Vector2(-1, 1)), Color("c8f0ff"))
		"fist":
			for row in range(-5, 6):
				_line(image, Vector2i(o.x + 6 + absi(row), int(c.y) + row), Vector2i(o.x + 15 - absi(row) / 2, int(c.y) + row), Color("bfeaf2") if absi(row) > 2 else Color("ffffff"))
			_rect(image, Vector2i(o.x, int(c.y) - 1), Vector2i(7, 3), Color("c9a27a"))
		"fireball":
			_disc(image, c + Vector2(1, 1), 6.0, Color("d8461c"))
			_disc(image, c + Vector2(1, 1), 4.0, Color("f39a3c"))
			_disc(image, c + Vector2(2, 0), 2.0, Color("ffe7a8"))
			_line(image, Vector2i(c + Vector2(-6, 5)), Vector2i(c + Vector2(-2, 2)), Color("f39a3c"))
		"bolt":
			var bolt := [Vector2i(9, 0), Vector2i(4, 7), Vector2i(9, 7), Vector2i(5, 15)]
			for i in range(bolt.size() - 1):
				_line(image, o + bolt[i], o + bolt[i + 1], Color("ffe66b"))
				_line(image, o + bolt[i] + Vector2i(1, 0), o + bolt[i + 1] + Vector2i(1, 0), Color("fff7c2"))
		"blink":
			_line(image, Vector2i(c + Vector2(0, -7)), Vector2i(c + Vector2(0, 7)), Color("d6c2ff"))
			_line(image, Vector2i(c + Vector2(-7, 0)), Vector2i(c + Vector2(7, 0)), Color("d6c2ff"))
			_disc(image, c, 2.5, Color("b38cf0"))
			_px(image, int(c.x), int(c.y), Color("ffffff"))
		"beam":
			_rect(image, Vector2i(o.x, int(c.y) - 4), Vector2i(16, 9), Color("8fd8e6"))
			_rect(image, Vector2i(o.x, int(c.y) - 2), Vector2i(16, 5), Color("f39a3c"))
			_rect(image, Vector2i(o.x, int(c.y)), Vector2i(16, 1), Color("ffffff"))


## Corner badge (upgrades, passives, perks): a dark disc with a mark.
static func _badge(image: Image, name: String) -> void:
	var c := Vector2(25, 25)
	var color := Color(str(BADGE_COLORS.get(name, "f4d383")))
	_disc(image, c, 6.5, OUTLINE)
	_disc(image, c, 5.5, Color("3a2e2c"))
	var p := Vector2i(c)
	match name:
		"plus":
			_line(image, p + Vector2i(-3, 0), p + Vector2i(3, 0), color)
			_line(image, p + Vector2i(0, -3), p + Vector2i(0, 3), color)
		"double":
			_line(image, p + Vector2i(-3, -2), p + Vector2i(-1, 0), color)
			_line(image, p + Vector2i(-1, 0), p + Vector2i(-3, 2), color)
			_line(image, p + Vector2i(1, -2), p + Vector2i(3, 0), color)
			_line(image, p + Vector2i(3, 0), p + Vector2i(1, 2), color)
		"up", "range":
			_line(image, p + Vector2i(0, 3), p + Vector2i(0, -3), color)
			_line(image, p + Vector2i(-2, -1), p + Vector2i(0, -3), color)
			_line(image, p + Vector2i(2, -1), p + Vector2i(0, -3), color)
		"clock":
			_arc(image, c, 3.5, 0.0, TAU, color)
			_line(image, p, p + Vector2i(0, -2), color)
			_line(image, p, p + Vector2i(2, 0), color)
		"heart":
			_disc(image, c + Vector2(-1.5, -1), 1.8, color)
			_disc(image, c + Vector2(1.5, -1), 1.8, color)
			_line(image, p + Vector2i(-3, 0), p + Vector2i(0, 3), color)
			_line(image, p + Vector2i(3, 0), p + Vector2i(0, 3), color)
			_rect(image, p + Vector2i(-2, -1), Vector2i(5, 2), color)
		"drop", "poison":
			_disc(image, c + Vector2(0, 1), 2.5, color)
			_line(image, p + Vector2i(0, -3), p + Vector2i(-1, -1), color)
			_line(image, p + Vector2i(0, -3), p + Vector2i(1, -1), color)
		"fire":
			_disc(image, c + Vector2(0, 1), 2.5, Color("f39a3c"))
			_line(image, p + Vector2i(0, -3), p + Vector2i(0, 0), Color("ffe7a8"))
		"snow":
			for angle in [0.0, PI / 3.0, 2.0 * PI / 3.0]:
				var d := Vector2.from_angle(angle) * 3.5
				_line(image, Vector2i(c - d), Vector2i(c + d), color)
		"shield":
			_rect(image, p + Vector2i(-3, -3), Vector2i(7, 4), color)
			_line(image, p + Vector2i(-3, 1), p + Vector2i(0, 3), color)
			_line(image, p + Vector2i(3, 1), p + Vector2i(0, 3), color)
		"crit":
			_line(image, p + Vector2i(0, -3), p + Vector2i(0, 1), color)
			_px(image, p.x, p.y + 3, color)
		"target", "ring":
			_arc(image, c, 3.5, 0.0, TAU, color)
			if name == "target": _px(image, p.x, p.y, color)
		"burst":
			for angle in range(8):
				var d := Vector2.from_angle(float(angle) * PI / 4.0)
				_line(image, Vector2i(c + d * 1.5), Vector2i(c + d * 3.5), color)
		"shards":
			_px(image, p.x - 2, p.y - 2, color)
			_px(image, p.x + 2, p.y - 1, color)
			_px(image, p.x, p.y + 2, color)
			_px(image, p.x - 1, p.y + 1, color)
			_px(image, p.x + 1, p.y - 2, color)
		"skull":
			_disc(image, c + Vector2(0, -0.5), 3.0, color)
			_px(image, p.x - 1, p.y - 1, OUTLINE)
			_px(image, p.x + 1, p.y - 1, OUTLINE)
			_rect(image, p + Vector2i(-1, 2), Vector2i(3, 1), color)
		"wind", "push":
			for row in [-2, 0, 2]: _line(image, p + Vector2i(-3, row), p + Vector2i(2 - absi(row) / 2, row), color)
		"wall":
			_rect(image, p + Vector2i(-3, -3), Vector2i(7, 6), color)
			_line(image, p + Vector2i(-3, 0), p + Vector2i(3, 0), OUTLINE)
			_px(image, p.x, p.y - 2, OUTLINE)
			_px(image, p.x - 2, p.y + 1, OUTLINE)
			_px(image, p.x + 2, p.y + 1, OUTLINE)
		"mirror":
			_rect(image, p + Vector2i(-3, -3), Vector2i(3, 6), color)
			_rect(image, p + Vector2i(1, -3), Vector2i(3, 6), Color(color, 0.5))
		"magnet":
			_arc(image, c, 3.0, 0.0, PI, color)
			_line(image, p + Vector2i(-3, 0), p + Vector2i(-3, -3), color)
			_line(image, p + Vector2i(3, 0), p + Vector2i(3, -3), color)
		"wide", "fan":
			_line(image, p + Vector2i(-3, 0), p + Vector2i(3, 0), color)
			_line(image, p + Vector2i(-3, 0), p + Vector2i(-1, -2), color)
			_line(image, p + Vector2i(-3, 0), p + Vector2i(-1, 2), color)
			_line(image, p + Vector2i(3, 0), p + Vector2i(1, -2), color)
			_line(image, p + Vector2i(3, 0), p + Vector2i(1, 2), color)
		"return":
			_arc(image, c, 3.0, PI * 0.2, PI * 1.6, color)
			_line(image, p + Vector2i(2, -3), p + Vector2i(3, -1), color)
		"eye":
			_arc(image, c, 3.5, PI, TAU, color)
			_arc(image, c, 3.5, 0.0, PI, color)
			_px(image, p.x, p.y, color)
		"pierce":
			_line(image, p + Vector2i(-3, 0), p + Vector2i(3, 0), color)
			_line(image, p + Vector2i(1, -2), p + Vector2i(3, 0), color)
			_line(image, p + Vector2i(1, 2), p + Vector2i(3, 0), color)
		"bolt":
			_line(image, p + Vector2i(1, -3), p + Vector2i(-1, 0), color)
			_line(image, p + Vector2i(-1, 0), p + Vector2i(1, 0), color)
			_line(image, p + Vector2i(1, 0), p + Vector2i(-1, 3), color)


## Dark one-pixel outline around everything drawn, as in the 0x72 sprites.
static func _outline(image: Image) -> void:
	var source := image.duplicate()
	for y in range(SIZE):
		for x in range(SIZE):
			if source.get_pixel(x, y).a > 0.0: continue
			for offset: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var nx := x + offset.x
				var ny := y + offset.y
				if nx >= 0 and ny >= 0 and nx < SIZE and ny < SIZE and source.get_pixel(nx, ny).a > 0.5:
					image.set_pixel(x, y, OUTLINE)
					break
