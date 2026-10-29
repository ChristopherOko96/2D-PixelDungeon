extends RefCounted
## Crypt save data (src/game.gd): the run's seed and the floor number rebuild the
## floor; the host's hero (class, health, perks, class cards, skills, inventory),
## the team level and the known potions come back as they were when the floor
## began. Other players of a session are not saved: a loaded run starts solo.

## Player fields that only describe this moment (position, timers, input), not the build.
const TRANSIENT := ["pos", "motion", "aim", "knockback", "hit_direction", "ready", "picked", "shot_timer", "invulnerable", "hitstun",
	"hit_flash", "moving", "face", "shots", "hurts", "blocks", "interacts", "last_hit_damage", "color", "skin", "cheat_god",
	"cheat_no_cooldown", "cheat_legendary", "commands", "door_wait", "dead_time", "clone", "curse_timers"]


## The save record for the floor the game just entered ({} when there is no host hero).
static func capture(game: Node) -> Dictionary:
	if not game.players.has(1):
		return {}
	var hero: Dictionary = game.players[1]
	return {
		"class_id": str(hero.get("class_id", "")), "story_id": str(game.story_id), "endless": bool(game.open_floors),
		"run_seed": int(game.run_seed), "run_id": run_id(game), "floor": int(game.floor_index), "level": int(game.team_progress.team.get("level", 1)),
		"title": "ENDLOS" if game.open_floors else "", "team": game.team_progress.team.duplicate(true),
		"known": game.inventory.known.duplicate(true), "next_uid": int(game.inventory._next_uid), "player": plain_player(hero),
	}


## The crypt run's id for its saves: the run seed (a loaded run keeps its seed).
static func run_id(game: Node) -> String:
	return "crypt-%d" % int(game.run_seed)


## The hero's lasting fields only, as plain data.
static func plain_player(hero: Dictionary) -> Dictionary:
	var out := {}
	for key: String in hero:
		if key in TRANSIENT:
			continue
		var value: Variant = hero[key]
		if value is Object:
			continue
		out[key] = value.duplicate(true) if value is Dictionary or value is Array else value
	return out


## Puts the saved hero, team and potion knowledge back into a run already on the saved floor.
static func apply(game: Node, data: Dictionary) -> void:
	game.team_progress.team = (data.get("team", {"level": 1, "exp": 0}) as Dictionary).duplicate(true)
	game.inventory.known = (data.get("known", {}) as Dictionary).duplicate(true)
	game.inventory._next_uid = maxi(int(game.inventory._next_uid), int(data.get("next_uid", 1)))
	if not game.players.has(1):
		return
	var hero: Dictionary = game.players[1]
	var saved: Dictionary = data.get("player", {})
	for key: String in saved:
		var value: Variant = saved[key]
		hero[key] = value.duplicate(true) if value is Dictionary or value is Array else value
	# derived stats follow the weapon, perks and cards again
	game.inventory.equip_apply(hero)
	hero.hp = clampi(int(saved.get("hp", hero.hp)), 1, int(hero.max_hp))
