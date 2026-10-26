extends RefCounted
## The player's lasting progress across runs: pure rules for recording a run and
## merging a local copy with the cloud copy. All values are counters or bests
## that only grow, so merging takes the larger value of each field and never
## loses a run that was saved on only one side.

const DEFAULTS := {"runs": 0, "wins": 0, "deaths": 0, "kills": 0, "bosses": 0,
	"best_level": 1, "total_exp": 0, "best_rooms": 0, "best_floor": 0, "play_seconds": 0, "updated": 0}


## A progress dictionary with every field present and of the right type.
static func normalized(progress: Dictionary) -> Dictionary:
	var result := {}
	for key: String in DEFAULTS:
		result[key] = maxi(int(progress.get(key, DEFAULTS[key])), int(DEFAULTS[key]))
	return result


## Adds one finished run. `run`: won (bool), level, exp, kills, bosses, rooms,
## seconds, and `floor` (deepest endless floor reached; 0 for a story run).
static func record_run(progress: Dictionary, run: Dictionary, now: int) -> Dictionary:
	var result := normalized(progress)
	var won: bool = bool(run.get("won", false))
	result.runs += 1
	result.wins += 1 if won else 0
	result.deaths += 0 if won else 1
	result.kills += maxi(0, int(run.get("kills", 0)))
	result.bosses += maxi(0, int(run.get("bosses", 0)))
	result.total_exp += maxi(0, int(run.get("exp", 0)))
	result.play_seconds += maxi(0, int(run.get("seconds", 0)))
	result.best_level = maxi(result.best_level, int(run.get("level", 1)))
	result.best_rooms = maxi(result.best_rooms, int(run.get("rooms", 0)))
	result.best_floor = maxi(result.best_floor, int(run.get("floor", 0)))
	result.updated = now
	return result


## Combines two copies field by field (largest value wins).
static func merge(first: Dictionary, second: Dictionary) -> Dictionary:
	var a := normalized(first)
	var b := normalized(second)
	var result := {}
	for key: String in DEFAULTS:
		result[key] = maxi(int(a[key]), int(b[key]))
	return result


## One summary line for the menu.
static func summary(progress: Dictionary) -> String:
	var p := normalized(progress)
	var line := "%d Läufe · %d Siege · %d Gegner · bestes Level %d" % [p.runs, p.wins, p.kills, p.best_level]
	if p.best_floor > 0: line += " · Endlos: Stockwerk %d" % p.best_floor
	return line
