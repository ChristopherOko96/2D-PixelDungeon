extends RefCounted
## The story mode's room pool (assets/data/dungeon_rooms.json "templates"):
## every room has a role (entrance = only first room of a floor, normal, boss =
## the final room with the floor's boss or strong group and the stairs) and a
## floor range ("floors": [first, last]) it may appear on. Each floor draws its
## rooms from the rooms allowed there; when too few fit, the whole pool is
## used so a floor can always be built.

const ROLES := ["entrance", "normal", "boss"]
## Floors a room appears on when it names none.
const ALL_FLOORS := [1, 99]


## "entrance", "normal" or "boss" from a room's flags.
static func role(room: Dictionary) -> String:
	if bool(room.get("boss", false)): return "boss"
	if bool(room.get("crypt_entrance", false)): return "entrance"
	return "normal"


## Sets the flags the generator reads for a role.
static func set_role(room: Dictionary, value: String) -> void:
	room.boss = value == "boss"
	if value == "entrance": room.crypt_entrance = true
	else: room.erase("crypt_entrance")


## [first, last] floor of a room.
static func floors(room: Dictionary) -> Array:
	var value: Variant = room.get("floors", ALL_FLOORS)
	if value is Array and value.size() == 2: return [int(value[0]), int(value[1])]
	return ALL_FLOORS.duplicate()


## True when the room may appear on `floor_number`.
static func allowed(room: Dictionary, floor_number: int) -> bool:
	var range_value := floors(room)
	return floor_number >= int(range_value[0]) and floor_number <= int(range_value[1])


## A copy of `config` whose templates are the rooms allowed on the floor
## (plus `keep_id`, a room being test-played). Falls back to the whole pool
## when the floor would lack a boss room or `count` different rooms.
static func for_floor(config: Dictionary, floor_number: int, count: int, keep_id: String = "") -> Dictionary:
	var chosen: Array = []
	for room: Dictionary in config.get("templates", []):
		if allowed(room, floor_number) or str(room.get("id", "")) == keep_id: chosen.append(room)
	var bosses := chosen.filter(func(room: Dictionary) -> bool: return role(room) == "boss").size()
	var others := chosen.size() - bosses
	if bosses < 1 or others < maxi(3, count - 1): return config
	var result := config.duplicate()
	result.templates = chosen
	return result
