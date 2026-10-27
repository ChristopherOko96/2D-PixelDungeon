extends RefCounted
## Read-only, cached playback of the articulated actor atlases baked offline.

const CATALOG_PATH: String = "res://assets/data/actor_animations.json"
var _catalog: Dictionary = {}
var _index: Dictionary = {}
var _actors: Dictionary = {}
var _actions: Dictionary = {}
var _action_ids: Array[String] = []
var _directions: Array = []
var _textures: Dictionary = {}
var _frames: Dictionary = {}
var _ready: bool = false

## Loads eight shared color/flash atlas pairs once. Missing art is an error.
func prepare() -> bool:
	if _ready: return true
	_catalog = _read_json(CATALOG_PATH)
	_index = _read_json(str(_catalog.get("index_path", "")))
	if int(_catalog.get("schema_version", 0)) != 1 or not bool(_index.get("quality_validated", false)): return false
	_directions = _catalog.get("directions", [])
	_action_ids.clear()
	_actions.clear()
	for action: Dictionary in _catalog.get("actions", []):
		var identifier: String = str(action.get("id", ""))
		_actions[identifier] = action
		_action_ids.append(identifier)
	_actors.clear()
	for actor: Dictionary in _catalog.get("actors", []):
		_actors[str(actor.get("id", ""))] = actor
	if _actors.size() != 8 or _actions.size() != 48 or _directions.size() != 4: return false
	if _index.get("action_ids", []) != _action_ids or _index.get("directions", []) != _directions: return false
	for identifier: String in _actors:
		var entry: Dictionary = _index.get("actors", {}).get(identifier, {})
		if entry.is_empty(): return false
		var color_path: String = str(entry.get("atlas", ""))
		var flash_path: String = str(entry.get("flash_atlas", ""))
		if not FileAccess.file_exists(color_path) or not FileAccess.file_exists(flash_path): return false
		var color: Texture2D = load(color_path) as Texture2D
		var flash: Texture2D = load(flash_path) as Texture2D
		if color == null or flash == null: return false
		_textures[identifier] = {"color": color, "flash": flash}
	_ready = true
	return true

## Schema metadata for animation selection and the studio; treat as read-only.
func catalog() -> Dictionary:
	if _catalog.is_empty(): _catalog = _read_json(CATALOG_PATH)
	return _catalog

## Actor identifiers, in the authored roster order.
func actors() -> Array[String]:
	var result: Array[String] = []
	for actor: Dictionary in catalog().get("actors", []): result.append(str(actor.id))
	return result

## These are 48 independent actions, irrespective of their four directions.
func animations(actor: String) -> Array[String]:
	if not _actors.has(actor): return []
	return _action_ids

## Duration in seconds; unknown actions do not acquire a guessed duration.
func duration(clip: String) -> float:
	return float(_actions.get(clip, {}).get("duration", 0.0))

## Returns a cached frame record. No image reads or image copies happen here.
func sample(actor: String, clip: String, direction: String, elapsed: float, loop: bool = true) -> Dictionary:
	if not _ready or not _textures.has(actor) or not _actions.has(clip) or not is_finite(elapsed): return {}
	var direction_index: int = _directions.find(direction)
	if direction_index < 0: return {}
	var seconds: float = duration(clip)
	if seconds <= 0.0: return {}
	var frame_count: int = int(_catalog.frames_per_clip)
	var playback: float = fposmod(maxf(elapsed, 0.0), seconds) if loop else minf(maxf(elapsed, 0.0), seconds)
	var tick: int = int(floor(playback / seconds * frame_count + 0.000001))
	var frame: int = tick % frame_count if loop else mini(tick, frame_count - 1)
	var key: String = actor + "/" + clip + "/" + direction + "/" + str(frame)
	if _frames.has(key): return _frames[key]
	var entry: Dictionary = _index.actors[actor]
	var width: int = int(entry.frame_size[0])
	var height: int = int(entry.frame_size[1])
	var region: Rect2 = Rect2((direction_index * frame_count + frame) * width, _action_ids.find(clip) * height, width, height)
	var texture: AtlasTexture = AtlasTexture.new()
	texture.atlas = _textures[actor].color
	texture.region = region
	var flash_texture: AtlasTexture = AtlasTexture.new()
	flash_texture.atlas = _textures[actor].flash
	flash_texture.region = region
	var scale: float = float(entry.render_scale)
	var bounds: Array = entry.clips[clip][direction].bounds[frame]
	var record: Dictionary = {"texture": texture, "flash_texture": flash_texture, "scale": scale,
		"feet": float(entry.base_feet) + (height - float(entry.anchor[1])) * scale,
		"anchor": Vector2(float(entry.anchor[0]), float(entry.anchor[1])),
		"top_crop": float(bounds[1]) * scale, "clip": clip, "frame": frame, "width": width, "height": height}
	_frames[key] = record
	return record

## Diagnostics for verifying the finite, lazy frame cache.
func cache_size() -> int:
	return _frames.size()

func _read_json(path: String) -> Dictionary:
	if path.is_empty() or not FileAccess.file_exists(path): return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}
