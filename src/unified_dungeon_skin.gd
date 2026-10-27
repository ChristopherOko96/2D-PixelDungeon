@tool
extends RefCounted
## Generated stone surfaces on the exact authored tile silhouettes.
## Saved IDs, alpha masks, placements and collision are never rewritten.
const THEMES := ["violet","rose","moss","amber"]
const MATERIAL_ROOT := "res://assets/crypt/unified/materials/material_%03d.png"
const SOURCE_ROOT := "res://assets/tilesets/cells32/%s_%03d.png"
const FLOOR_IDS := [9,11,17,18,19,24,25,26,30,32,39]
const SIDE_IDS := [1,3,4,5,7,13,14,20,21,27,28,34,36,38,40,47]
const STAIR_IDS := [0,6,41,46]
const TINTS := {"violet":Color(1,1,1),"rose":Color(1,0.96,0.98),"moss":Color(0.96,1,0.97),"amber":Color(1,0.98,0.94)}
## Rejected dense stone experiment is retained for reference, never enabled by default.
static var active := false
static var _materials: Dictionary = {}
static var _images: Dictionary = {}
static var _textures: Dictionary = {}
static var _atlases: Dictionary = {}
static var _ready := false

## The visual replacement is active only after every generated material exists.
static func enabled() -> bool:
	return active and is_ready()

## Imported resources work in both the editor and a later exported resource pack.
static func is_ready() -> bool:
	if _ready: return true
	for index in range(16):
		if not ResourceLoader.exists(MATERIAL_ROOT % index): return false
	_ready = true
	return true

## Strict IDs ensure drafts cannot cause arbitrary resource reads.
static func supports(id: String) -> bool:
	var bits := id.rsplit("_",true,1)
	return bits.size() == 2 and bits[0] in THEMES and bits[1].is_valid_int() and int(bits[1]) >= 0 and int(bits[1]) < 56 and bits[1] == "%03d" % int(bits[1])

## Returns a native32 surface with exactly the source cell's alpha silhouette.
static func texture(id: String) -> Texture2D:
	if not enabled() or not supports(id): return null
	if not _textures.has(id):
		var image := _image(id)
		if image == null: return null
		_textures[id] = ImageTexture.create_from_image(image)
	return _textures[id]

## Legacy renderer keeps16-coordinate regions while sampling full32px detail.
## Only this atlas carries the scale metadata; item sheets remain unscaled.
static func atlas(theme_name: String) -> Texture2D:
	if not enabled() or theme_name not in THEMES: return null
	if not _atlases.has(theme_name):
		var image := Image.create(224,256,false,Image.FORMAT_RGBA8)
		image.fill(Color.TRANSPARENT)
		for index in range(56):
			var cell := _image("%s_%03d" % [theme_name,index])
			if cell == null: return null
			image.blit_rect(cell,Rect2i(0,0,32,32),Vector2i((index%7)*32,(index/7)*32))
		var result := ImageTexture.create_from_image(image)
		result.set_meta("unified_atlas_scale",2.0)
		_atlases[theme_name] = result
	return _atlases[theme_name]

static func _material(index: int) -> Image:
	if not _materials.has(index):
		var image := _resource_image(MATERIAL_ROOT % index)
		if image == null or image.is_empty(): return null
		image.convert(Image.FORMAT_RGBA8)
		if image.get_size() != Vector2i(32,32): image.resize(32,32,Image.INTERPOLATE_NEAREST)
		_materials[index] = image
	return _materials[index]

static func _image(id: String) -> Image:
	if _images.has(id): return _images[id]
	var parts := id.rsplit("_",true,1)
	var theme_name: String = parts[0]
	var index := int(parts[1])
	var source := _resource_image(SOURCE_ROOT % [theme_name,index])
	if source == null or source.is_empty(): return null
	source.convert(Image.FORMAT_RGBA8)
	var output := Image.create(32,32,false,Image.FORMAT_RGBA8)
	output.fill(Color.TRANSPARENT)
	var bounds := source.get_used_rect()
	if bounds.size == Vector2i.ZERO:
		_images[id] = output
		return output
	var material_index := _material_index(index,theme_name)
	var surface := _material(material_index)
	if surface == null: return null
	var mean := _mean_light(source)
	var tint: Color = TINTS[theme_name]
	for y in range(32):
		for x in range(32):
			var original := source.get_pixel(x,y)
			if original.a <= 0: continue
			var u := x
			var v := y
			if index in SIDE_IDS:
				# Stretch the new edge material across the original narrow mask,
				# never across the whole cell or into its transparent neighbor.
				u = clampi(int(float(x-bounds.position.x)*32/maxi(1,bounds.size.x)),0,31)
				v = clampi(int(float(y-bounds.position.y)*32/maxi(1,bounds.size.y)),0,31)
			var color := surface.get_pixel(u,v)
			var shade := clampf(_light(original)/maxf(0.02,mean),0.48,1.30)
			# Old outlines/crown highlights retain their directional relief,
			# while generated stone replaces the original flat color surface.
			var strength := 0.22 if index in FLOOR_IDS else 0.48
			var lighting := lerpf(1.0,shade,strength)
			color = Color(color.r*tint.r*lighting,color.g*tint.g*lighting,color.b*tint.b*lighting,original.a)
			if index in [16,23] and _light(original) < 0.13:
				color = Color(0.035,0.022,0.055,original.a)
			output.set_pixel(x,y,color)
	_images[id] = output
	return output

static func _material_index(index: int, theme_name: String) -> int:
	if index in FLOOR_IDS:
		if theme_name == "moss" and index in [18,24,30]: return 2
		if index in [18,26]: return 1
		if index in [19,30]: return 2 if theme_name == "moss" else 0
		if index in [25,32]: return 3
		return 0
	if index in SIDE_IDS: return 9
	if index in STAIR_IDS: return 12
	if index in [15,22,31,35]: return 7
	if index in [42,43,44,45]: return 14
	if index in [49,50,51]: return 13
	if index in [52,53,54,55]: return 6
	return 5 if index in [8,10,12,29,33,37] else 4

static func _mean_light(image: Image) -> float:
	var total := 0.0
	var count := 0
	for y in range(32):
		for x in range(32):
			var value := image.get_pixel(x,y)
			if value.a <= 0: continue
			total += _light(value)
			count += 1
	return total/maxi(1,count)

static func _resource_image(path: String) -> Image:
	if not ResourceLoader.exists(path): return null
	var texture: Texture2D = load(path)
	if texture == null: return null
	var image := texture.get_image()
	if image == null: return null
	if image.is_compressed(): image.decompress()
	if image.get_format() != Image.FORMAT_RGBA8: image.convert(Image.FORMAT_RGBA8)
	return image

static func _light(color: Color) -> float:
	return color.r*0.2126+color.g*0.7152+color.b*0.0722
