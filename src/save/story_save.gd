extends RefCounted
## Story world save data (src/hell/hell_game.gd: Hell-Dungeon and Frostgruft):
## the floor number and everything the portal carries to the next floor
## (hearts, runestones, blessings, level, skills, relic, cards, talent bonus).
## Loading opens the same scene on that floor with these values.

## The state keys hell_game.load_floor carries from floor to floor.
const CARRIED := ["hp", "max_hp", "gems", "dmg", "rate", "speed_mul", "range", "buffs", "skill", "level", "exp", "relic", "relic_on",
	"upgrades", "offer", "cards_due", "relic_floor", "relic_item", "talent", "crystals_run", "run_id", "items", "world_run"]


## "frost" for the Frostgruft theme, "krypta" for the crypt (Story 1), otherwise "hell".
static func mode(game: Node) -> String:
	var path := str(game.theme_path)
	if path.contains("frost"):
		return "frost"
	return "krypta" if path.contains("krypta") else "hell"


## The save record for the floor the game just loaded.
static func capture(game: Node) -> Dictionary:
	var keep := {}
	for key: String in CARRIED:
		if game.state.has(key):
			var value: Variant = game.state[key]
			keep[key] = value.duplicate(true) if value is Dictionary or value is Array else value
	return {"class_id": str(game.class_id), "scene": str(game.scene_file_path), "floor": int(game.state.floor), "run_id": str(game.state.get("run_id", "")),
		"title": str(game.W.get("title", "")), "level": int(game.state.get("level", 1)), "keep": keep}
