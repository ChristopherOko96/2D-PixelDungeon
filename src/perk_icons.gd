extends RefCounted
## Cached native pixel glyphs for perks; the five supplied icons stay unchanged.

const IDS: Array[String] = ["ember","shadow","heart","quick","mend","piercer","ricochet","scatter","heavy","twin","backshot","sidewinder","homing","orbit","crit","focus","momentum","execution","mark","longshot","cinder","venom","frost","storm","shatter","plague","combustion","conductor","permafrost","catalyst","shield","thorns","vampire","second_wind","soul_guard","renewal","adrenaline","berserk","stone_skin","close_quarters","echo","split","blast","leech","overkill","convergence","first_strike","desperation"]
const LEGACY: Array[String] = ["ember","shadow","heart","quick","mend"]
const CATEGORY_NAMES: Dictionary = {"ballistics":"Geschosse","projectile":"Geschosse","projectiles":"Geschosse","trajectory":"Flugbahn","precision":"Präzision","elements":"Elemente","element":"Elemente","survival":"Schutz","defense":"Schutz","mobility":"Bewegung","synergy":"Kombination","synergies":"Kombination","sustain":"Erholung","offense":"Angriff","power":"Kraft","recovery":"Erholung","risk":"Wagnis","vitality":"Vitalität","utility":"Taktik","patterns":"Schussmuster","pattern":"Schussmuster"}
const TAG_NAMES: Dictionary = {"fire":"Feuer","burn":"Brand","poison":"Gift","frost":"Frost","ice":"Frost","slow":"Verlangsamung","lightning":"Blitz","shock":"Blitz","projectile":"Geschosse","projectiles":"Geschosse","precision":"Präzision","crit":"Kritisch","critical":"Kritisch","damage":"Schaden","speed":"Tempo","movement":"Bewegung","mobility":"Bewegung","defense":"Schutz","shield":"Schild","shields":"Schild","health":"Leben","heal":"Heilung","healing":"Heilung","sustain":"Erholung","kill":"Tötungen","on_kill":"Tötungen","status":"Zustände","elemental":"Elemente","elements":"Elemente","multishot":"Mehrfachschuss","pierce":"Durchschlag","ricochet":"Abpraller","area":"Fläche","aoe":"Fläche","burst":"Salve","risk":"Wagnis","low_hp":"Wenig Leben","close":"Nahdistanz","close_range":"Nahdistanz","distance":"Distanz","ranged":"Distanz","attack_speed":"Feuerrate","rate":"Feuerrate","control":"Kontrolle","combo":"Kombination","chain":"Kette","death":"Tötungen","blood":"Blut","room":"Raumbeginn","stationary":"Stillstand","moving":"Bewegung","execute":"Vollstrecken","splinter":"Splitter","split":"Splitter","homing":"Zielsuchend","explosion":"Explosion","first_hit":"Ersttreffer","vampire":"Vampir","pattern":"Schussmuster","tradeoff":"Wagnis","recovery":"Erholung"}
const RARITY_NAMES: Dictionary = {"common":"Gewöhnlich","uncommon":"Ungewöhnlich","rare":"Selten","epic":"Episch","legendary":"Legendär"}
const BUILD_TAG_NAMES: Dictionary = {"motion":"Bewegung","guard":"Schutz","seek":"Zielsuchend","storm":"Blitz","strike":"Treffer","volley":"Salven"}
static var _cache: Dictionary = {}

## Returns one shared texture per stable ID; no texture is rebuilt per snapshot.
static func texture(id: String, _definition: Dictionary = {}) -> Texture2D:
	if _cache.has(id): return _cache[id]
	if id in LEGACY:
		var path: String = "res://assets/items/perks/"+id+".png"
		if ResourceLoader.exists(path):
			_cache[id] = load(path)
			return _cache[id]
	var image: Image = Image.create(32,32,false,Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	_draw_glyph(image,id,tint(id))
	var outlined: Image = image.duplicate()
	for y: int in range(1,31):
		for x: int in range(1,31):
			if image.get_pixel(x,y).a > 0.0: continue
			for offset: Vector2i in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
				if image.get_pixel(x+offset.x,y+offset.y).a > 0.0:
					outlined.set_pixel(x,y,Color("25142e"))
					break
	var result: Texture2D = ImageTexture.create_from_image(outlined)
	_cache[id] = result
	return result

## Stable family color keeps related effects legible without recoloring source art.
static func tint(id: String) -> Color:
	if id in ["ember","cinder","combustion","blast","berserk","overkill","desperation"]: return Color("f2ac65")
	if id in ["frost","shatter","permafrost","shield","stone_skin"]: return Color("8fd6cd")
	if id in ["venom","plague","catalyst","renewal","leech"]: return Color("b7d57c")
	if id in ["heart","vampire","second_wind","adrenaline","thorns"]: return Color("ee8ca2")
	if id in ["storm","conductor","crit","quick","first_strike","longshot","execution"]: return Color("f4d383")
	if id in ["shadow","momentum","homing","orbit","convergence","close_quarters"]: return Color("99cbd6")
	return Color("c5b1ee")

## Converts schema family names to short player-facing German labels.
static func category_name(value: String) -> String:
	return str(CATEGORY_NAMES.get(value,value.capitalize() if not value.is_empty() else "Segen"))

## Converts schema rarity to readable text.
static func rarity_name(value: String) -> String:
	return str(RARITY_NAMES.get(value,value.capitalize() if not value.is_empty() else "Gewöhnlich"))

## Returns translated, deduplicated synergy tags with an optional visible limit.
static func tag_text(tags: Array, limit: int = 0) -> String:
	var names: Array[String] = []
	for value: Variant in tags:
		var key: String = str(value)
		var name: String = str(BUILD_TAG_NAMES.get(key,TAG_NAMES.get(key,key.replace("_"," ").capitalize())))
		if name not in names: names.append(name)
	if limit > 0 and names.size() > limit: names.resize(limit)
	return " · ".join(names)

static func _draw_glyph(image: Image, id: String, color: Color) -> void:
	var bright: Color = color.lightened(0.35)
	var dark: Color = color.darkened(0.35)
	match id:
		"piercer":
			_rect(image,12,6,2,20,dark); _rect(image,21,6,2,20,dark)
			_arrow(image,Vector2i(4,16),Vector2i(27,16),bright,2)
		"ricochet":
			_line(image,Vector2i(5,25),Vector2i(16,6),color,2)
			_arrow(image,Vector2i(16,6),Vector2i(27,25),bright,2)
			_rect(image,4,4,24,2,dark)
		"scatter":
			for target: Vector2i in [Vector2i(9,5),Vector2i(16,3),Vector2i(23,5)]: _arrow(image,Vector2i(16,26),target,color,2)
		"heavy":
			_circle(image,16,12,7,color); _rect(image,9,12,15,11,color)
			_rect(image,11,23,11,3,dark); _rect(image,12,8,3,9,bright)
		"twin":
			_arrow(image,Vector2i(10,26),Vector2i(10,5),color,2)
			_arrow(image,Vector2i(22,26),Vector2i(22,5),bright,2)
		"backshot":
			_arrow(image,Vector2i(16,15),Vector2i(16,3),bright,2)
			_arrow(image,Vector2i(16,19),Vector2i(16,29),color,2)
			_rect(image,11,15,11,4,dark)
		"sidewinder":
			_arrow(image,Vector2i(16,25),Vector2i(16,4),bright,2)
			_arrow(image,Vector2i(16,19),Vector2i(4,19),color,2)
			_arrow(image,Vector2i(16,19),Vector2i(28,19),color,2)
		"homing":
			_line(image,Vector2i(5,25),Vector2i(5,15),color,2)
			_line(image,Vector2i(5,15),Vector2i(16,8),color,2)
			_arrow(image,Vector2i(16,8),Vector2i(27,8),bright,2)
			_ring(image,24,21,5,3,dark)
		"orbit":
			_ring(image,16,16,10,8,color); _circle(image,16,16,3,dark)
			_circle(image,23,9,4,bright)
		"crit":
			_star(image,Vector2i(16,15),11,color); _rect(image,15,6,2,19,bright)
		"focus":
			_ring(image,16,16,8,6,color)
			for pair: Array in [[Vector2i(16,3),Vector2i(16,10)],[Vector2i(16,22),Vector2i(16,29)],[Vector2i(3,16),Vector2i(10,16)],[Vector2i(22,16),Vector2i(29,16)]]: _line(image,pair[0],pair[1],bright,1)
		"momentum":
			_arrow(image,Vector2i(10,15),Vector2i(28,15),color,2)
			for row: int in [9,16,23]: _rect(image,3,row,7,2,dark)
			_rect(image,16,21,7,4,bright)
		"execution":
			_axe(image,color)
			_rect(image,5,26,22,3,dark); _rect(image,5,26,5,3,bright)
		"mark":
			_ring(image,16,16,11,9,color); _ring(image,16,16,6,4,bright); _circle(image,16,16,1,color)
		"longshot":
			_arrow(image,Vector2i(3,10),Vector2i(28,10),bright,2)
			_rect(image,4,21,24,3,dark)
			for x: int in [5,10,15,20,25]: _rect(image,x,18,1,6,color)
		"cinder": _flame(image,Vector2i(16,17),color)
		"venom":
			_vial(image,Vector2i(16,16),color); _circle(image,13,19,1,bright); _circle(image,19,16,1,bright)
		"frost": _snowflake(image,Vector2i(16,16),10,color)
		"storm": _bolt(image,Vector2i(16,15),color)
		"shatter":
			_snowflake(image,Vector2i(15,16),10,dark)
			_line(image,Vector2i(18,4),Vector2i(13,14),bright,2); _line(image,Vector2i(13,14),Vector2i(20,17),bright,2); _line(image,Vector2i(20,17),Vector2i(14,28),bright,2)
		"plague":
			_skull(image,Vector2i(16,13),color)
			for center: Vector2i in [Vector2i(6,25),Vector2i(16,26),Vector2i(26,25)]: _circle(image,center.x,center.y,3,dark)
		"combustion":
			_star(image,Vector2i(16,17),12,dark); _flame(image,Vector2i(16,16),color)
			_rect(image,3,5,3,3,bright); _rect(image,26,4,2,2,bright)
		"conductor":
			_line(image,Vector2i(5,23),Vector2i(26,8),dark,2)
			_bolt(image,Vector2i(10,16),color); _bolt(image,Vector2i(23,17),bright)
		"permafrost":
			_shield(image,dark); _snowflake(image,Vector2i(16,14),7,color)
		"catalyst":
			_vial(image,Vector2i(10,18),dark); _vial(image,Vector2i(22,14),color)
			_star(image,Vector2i(8,5),3,bright)
		"shield":
			_shield(image,color); _rect(image,14,8,3,12,bright); _rect(image,10,12,11,3,bright)
		"thorns":
			_shield(image,dark)
			for x: int in [6,16,26]: _line(image,Vector2i(x,9),Vector2i(x,2),color,2)
			_line(image,Vector2i(6,16),Vector2i(2,16),color,2); _line(image,Vector2i(26,16),Vector2i(30,16),color,2)
		"vampire":
			_rect(image,6,7,20,5,dark)
			_line(image,Vector2i(8,10),Vector2i(12,24),bright,2); _line(image,Vector2i(12,24),Vector2i(15,10),bright,2)
			_line(image,Vector2i(18,10),Vector2i(21,24),bright,2); _line(image,Vector2i(21,24),Vector2i(25,10),bright,2)
			_circle(image,17,27,2,color)
		"second_wind":
			for x: int in [4,7,10]: _line(image,Vector2i(x,9),Vector2i(15,21),bright,2)
			for x: int in [22,25,28]: _line(image,Vector2i(x,9),Vector2i(17,21),bright,2)
			_heart(image,Vector2i(16,17),color)
		"soul_guard":
			_shield(image,dark); _ghost(image,Vector2i(16,13),color)
		"renewal":
			_heart(image,Vector2i(16,20),dark)
			_line(image,Vector2i(16,23),Vector2i(17,5),bright,1)
			_line(image,Vector2i(17,11),Vector2i(8,5),color,3); _line(image,Vector2i(17,15),Vector2i(25,8),color,3)
		"adrenaline":
			_heart(image,Vector2i(16,17),dark); _bolt(image,Vector2i(18,15),color)
		"berserk":
			_axe(image,color); _line(image,Vector2i(5,26),Vector2i(10,21),bright,2)
			_line(image,Vector2i(24,5),Vector2i(28,2),bright,1)
		"stone_skin":
			_shield(image,dark)
			_rect(image,8,8,8,6,color); _rect(image,18,8,7,6,color); _rect(image,11,16,11,5,bright)
		"close_quarters":
			_ring(image,16,17,10,8,dark); _sword(image,color)
		"echo":
			_arrow(image,Vector2i(7,26),Vector2i(7,11),dark,2)
			_arrow(image,Vector2i(16,23),Vector2i(16,7),color,2)
			_arrow(image,Vector2i(25,20),Vector2i(25,3),bright,2)
		"split":
			_line(image,Vector2i(16,27),Vector2i(16,16),dark,2)
			_arrow(image,Vector2i(16,16),Vector2i(5,5),color,2); _arrow(image,Vector2i(16,16),Vector2i(27,5),bright,2)
		"blast":
			_circle(image,15,19,8,dark); _rect(image,13,9,5,4,color)
			_line(image,Vector2i(15,9),Vector2i(21,5),bright,1); _star(image,Vector2i(24,4),3,color)
		"leech":
			_drop(image,Vector2i(16,15),color)
			_rect(image,10,16,12,4,dark); _rect(image,12,17,2,5,bright); _rect(image,18,17,2,5,bright)
		"overkill":
			_star(image,Vector2i(16,15),13,dark); _skull(image,Vector2i(16,14),color)
			_rect(image,3,27,6,2,bright); _rect(image,23,27,6,2,bright)
		"convergence":
			for from: Vector2i in [Vector2i(4,4),Vector2i(28,4),Vector2i(4,28),Vector2i(28,28)]: _arrow(image,from,Vector2i(16,16),color,1)
			_circle(image,16,16,3,bright)
		"first_strike":
			_arrow(image,Vector2i(16,28),Vector2i(16,9),color,2); _star(image,Vector2i(16,6),4,bright)
			_rect(image,4,22,3,5,dark)
		"desperation":
			_heart(image,Vector2i(16,17),dark)
			_line(image,Vector2i(16,8),Vector2i(13,16),bright,1); _line(image,Vector2i(13,16),Vector2i(18,20),bright,1)
			_flame(image,Vector2i(23,23),color)
		_:
			_rect(image,9,5,15,22,color); _rect(image,12,9,9,2,bright); _rect(image,12,14,7,2,dark); _rect(image,12,19,9,2,dark)

static func _rect(image: Image, x: int, y: int, width: int, height: int, color: Color) -> void:
	image.fill_rect(Rect2i(x,y,width,height).intersection(Rect2i(0,0,32,32)),color)

static func _line(image: Image, from: Vector2i, to: Vector2i, color: Color, width: int = 1) -> void:
	var steps: int = maxi(absi(to.x-from.x),absi(to.y-from.y))
	for step: int in range(steps+1):
		var point: Vector2 = Vector2(from).lerp(Vector2(to),float(step)/maxi(1,steps))
		_rect(image,roundi(point.x),roundi(point.y),width,width,color)

static func _arrow(image: Image, from: Vector2i, to: Vector2i, color: Color, width: int = 1) -> void:
	_line(image,from,to,color,width)
	var direction: Vector2 = Vector2(to-from).normalized()
	for side: float in [-1.0,1.0]:
		var tip: Vector2i = Vector2i(Vector2(to)-direction*5+direction.orthogonal()*side*4)
		_line(image,to,tip,color,width)

static func _circle(image: Image, x: int, y: int, radius: int, color: Color) -> void:
	for py: int in range(maxi(0,y-radius),mini(32,y+radius+1)):
		for px: int in range(maxi(0,x-radius),mini(32,x+radius+1)):
			if Vector2i(px-x,py-y).length_squared() <= radius*radius: image.set_pixel(px,py,color)

static func _ring(image: Image, x: int, y: int, radius: int, inner: int, color: Color) -> void:
	for py: int in range(maxi(0,y-radius),mini(32,y+radius+1)):
		for px: int in range(maxi(0,x-radius),mini(32,x+radius+1)):
			var distance: int = Vector2i(px-x,py-y).length_squared()
			if distance <= radius*radius and distance >= inner*inner: image.set_pixel(px,py,color)

static func _star(image: Image, point: Vector2i, radius: int, color: Color) -> void:
	_line(image,point-Vector2i(radius,0),point+Vector2i(radius,0),color,2)
	_line(image,point-Vector2i(0,radius),point+Vector2i(0,radius),color,2)
	var diagonal: int = int(radius*0.6)
	_line(image,point-Vector2i(diagonal,diagonal),point+Vector2i(diagonal,diagonal),color,1)
	_line(image,point-Vector2i(diagonal,-diagonal),point+Vector2i(diagonal,-diagonal),color,1)

static func _heart(image: Image, point: Vector2i, color: Color) -> void:
	_circle(image,point.x-4,point.y-3,5,color); _circle(image,point.x+4,point.y-3,5,color)
	for row: int in range(10): _rect(image,point.x-9+row,point.y-1+row,19-row*2,1,color)

static func _flame(image: Image, point: Vector2i, color: Color) -> void:
	_circle(image,point.x,point.y+3,7,color)
	for row: int in range(13): _rect(image,point.x-1-int(row*0.35),point.y-12+row,maxi(1,int(row*0.8)),1,color)
	_circle(image,point.x,point.y+5,3,color.lightened(0.4))

static func _drop(image: Image, point: Vector2i, color: Color) -> void:
	_circle(image,point.x,point.y+4,7,color)
	for row: int in range(13): _rect(image,point.x-int(row*0.5),point.y-10+row,maxi(1,row),1,color)

static func _vial(image: Image, point: Vector2i, color: Color) -> void:
	_rect(image,point.x-3,point.y-11,7,4,color.lightened(0.35))
	_rect(image,point.x-2,point.y-7,5,5,color)
	_circle(image,point.x,point.y+3,6,color)
	_rect(image,point.x-3,point.y,2,5,color.lightened(0.35))

static func _snowflake(image: Image, point: Vector2i, radius: int, color: Color) -> void:
	_line(image,point-Vector2i(radius,0),point+Vector2i(radius,0),color,2)
	_line(image,point-Vector2i(0,radius),point+Vector2i(0,radius),color,2)
	_line(image,point-Vector2i(7,7),point+Vector2i(7,7),color,1)
	_line(image,point-Vector2i(7,-7),point+Vector2i(7,-7),color,1)
	for offset: Vector2i in [Vector2i(0,-radius),Vector2i(0,radius),Vector2i(-radius,0),Vector2i(radius,0)]: _rect(image,point.x+offset.x-1,point.y+offset.y-1,4,4,color)

static func _bolt(image: Image, point: Vector2i, color: Color) -> void:
	for row: int in range(11): _rect(image,point.x+2-int(row*0.7),point.y-11+row,6,1,color)
	for row: int in range(13): _rect(image,point.x-2-int(row*0.4),point.y+row,maxi(1,7-int(row*0.5)),1,color)
	_rect(image,point.x-5,point.y-1,12,3,color)

static func _shield(image: Image, color: Color) -> void:
	_rect(image,6,5,21,14,color)
	for row: int in range(10): _rect(image,6+row,19+row,21-row*2,1,color)
	_rect(image,8,7,2,10,color.lightened(0.3))

static func _ghost(image: Image, point: Vector2i, color: Color) -> void:
	_circle(image,point.x,point.y-3,5,color); _rect(image,point.x-5,point.y-3,11,11,color)
	_rect(image,point.x-3,point.y-3,2,3,Color("25142e")); _rect(image,point.x+2,point.y-3,2,3,Color("25142e"))
	_rect(image,point.x-1,point.y+5,2,3,Color.TRANSPARENT)

static func _skull(image: Image, point: Vector2i, color: Color) -> void:
	_circle(image,point.x,point.y-1,7,color); _rect(image,point.x-5,point.y+3,11,7,color)
	_rect(image,point.x-5,point.y-3,4,4,Color("25142e")); _rect(image,point.x+2,point.y-3,4,4,Color("25142e"))
	for x: int in [-3,1,5]: _rect(image,point.x+x,point.y+7,1,4,Color("25142e"))

static func _axe(image: Image, color: Color) -> void:
	_line(image,Vector2i(7,27),Vector2i(24,7),color.darkened(0.3),3)
	_rect(image,16,6,12,10,color); _rect(image,23,6,5,15,color.lightened(0.3))

static func _sword(image: Image, color: Color) -> void:
	_line(image,Vector2i(10,24),Vector2i(24,5),color,3)
	_line(image,Vector2i(7,18),Vector2i(18,26),color.lightened(0.35),2)
	_line(image,Vector2i(7,29),Vector2i(11,23),color.darkened(0.35),3)
