extends RefCounted
## The pictures the Weltbauer shows for one world and graphics view: the same set, the same moving
## fires and fountains as the game (src/vfx/fire_anim.gd), and any other picture on demand.

const FireAnim = preload("res://src/vfx/fire_anim.gd")
const RoomWorld = preload("res://src/world_editor/world_room_world.gd")
const Data = preload("res://src/world_editor/world_room_data.gd")
const Graphics = preload("res://src/core/graphics_settings.gd")
const Game = preload("res://src/hell/hell_game.gd")

var world: String = "krypta"
## The theme with the shown set merged in, as in the game.
var theme: Dictionary = {}
var tex: Dictionary = {}
var fire_anim := FireAnim.new()
var pixel_tiles: bool = false
var _wanted: Dictionary = {}


## Loads `world` in view `mode` ("pixel" or "hd"; one the world lacks falls back to its default).
func _init(world_id: String, mode: String) -> void:
	world = world_id
	theme = load_theme(world_id)
	if Graphics.has(theme, mode):
		theme.merge(Graphics.skin(theme, mode), true)
	pixel_tiles = bool(theme.get("pixel_tiles", false))
	var folder := str(theme.get("sprites", ""))
	var names: Variant = JSON.parse_string(FileAccess.get_file_as_string(folder + "manifest.json"))
	if names is Dictionary:
		for n: String in names:
			if ResourceLoader.exists(folder + n + ".png"):
				tex[n] = load(folder + n + ".png")
	fire_anim.build(tex, 3 if bool(theme.get("pixel", false)) else 1)


## The world's theme as the game builds it (hell_game.gd _load_theme): the defaults, the keys shared
## from another theme, the file's keys on top; a theme without own sprites keeps the hell's sets.
static func load_theme(world_id: String) -> Dictionary:
	var out: Dictionary = Game.THEME_DEFAULT.duplicate(true)
	var parsed: Dictionary = DataCache.load_dict(str(Data.WORLDS[world_id].theme))
	if parsed.has("hero_from"):
		var shared: Dictionary = DataCache.load_dict(str(parsed.hero_from))
		for k: String in parsed.get("hero_keys", []):
			if shared.has(k):
				out[k] = (shared[k] as Variant)
	if parsed.has("skins") or parsed.has("sprites"):
		out.skins = parsed.get("skins", {})
	for k: String in parsed:
		if k == "skins":
			continue
		if parsed[k] is Dictionary and out.get(k) is Dictionary:
			(out[k] as Dictionary).merge(parsed[k], true)
		else:
			out[k] = parsed[k]
	return out


## The picture of an asset name for drawing: one not loaded yet comes with flush, a texture loaded
## in the middle of a draw shows white.
func picture(name: String) -> Texture2D:
	if name == "":
		return null
	if not tex.has(name):
		_wanted[name] = true
		return null
	return tex[name]


## The picture at once, outside drawing (placing a piece needs its size).
func picture_now(name: String) -> Texture2D:
	if name == "":
		return null
	if not tex.has(name):
		tex[name] = RoomWorld.resolve(name, theme)
	return tex[name]


## Loads up to `count` of the pictures asked for while drawing. Returns how many came.
func flush(count: int) -> int:
	var done := 0
	for name: String in _wanted.keys():
		if done >= count:
			break
		_wanted.erase(name)
		tex[name] = RoomWorld.resolve(name, theme)
		done += 1
	return done


## The picture at time `t` at place `at`: a fire or fountain moves like in the game.
func moving(name: String, at: Vector2, t: float) -> Texture2D:
	if fire_anim.has(name):
		return fire_anim.frame(name, at, t)
	return picture(name)
