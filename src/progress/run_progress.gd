extends RefCounted
## Connects a run to the lasting profile (src/progress/profile.gd): character
## EXP and levels, gold, the run's difficulty, and boss completions with their
## soul shard roll (src/progress/soul_drops.gd).
## The host decides everything that can be cheated: which enemy fell, whether
## a hero took part in the fight, how long it lasted, each hero's damage
## share, the boss level and the random roll. It then sends each hero a
## reward event; the hero's own game applies it to its own profile with the
## same pure rules (shards per boss, first Albtraum kills and already rewarded
## completions live in that profile) and saves. The host applies the events
## of its own hero directly. Clients send their talent builds once admitted;
## the host checks them against the rules before they count (talent_combat).

const Profile = preload("res://src/progress/profile.gd")
const Rules = preload("res://src/progress/talent_rules.gd")
const Drops = preload("res://src/progress/soul_drops.gd")

## Emitted on this machine when an event changed the local profile
## (kinds: "shard", "level", "boss"); the HUD shows it.
signal local_event(event: Dictionary)

var game: Node
var data: Dictionary = {}
## This machine's profile.
var profile: Dictionary = {}
var save_path := Profile.default_path()
## Remote heroes' builds per class: peer id -> {class_id: build}.
var remote_builds: Dictionary = {}
## The run's difficulty (the host's choice).
var difficulty := "normal"
## Identifies this run in completion ids, so a restart never repeats one.
var run_uid := ""
## Recent events for the snapshot (host): {id, peer, kind, ...}.
var recent: Array = []
var _next_id := 1
var _rng := RandomNumberGenerator.new()
var _dirty := false
var _save_timer := 0.0
## Fractional enemy damage per hero (difficulty scaling of whole hearts).
var _damage_debt: Dictionary = {}


func bind(owner: Node) -> void:
	game = owner
	if data.is_empty(): data = Profile.data()
	if profile.is_empty(): profile = Profile.load_profile(data, save_path)
	difficulty = str(profile.get("difficulty", "normal"))


## A new run: fresh completion ids, a new random source, the host's difficulty.
func begin_run(seed_value: int) -> void:
	_rng.randomize()
	run_uid = "%d-%d-%d" % [seed_value, Time.get_unix_time_from_system(), _rng.randi()]
	recent.clear()
	_damage_debt.clear()
	difficulty = str(profile.get("difficulty", "normal"))


## The build a hero plays with: the local profile for this machine's hero,
## the received build for a remote one, otherwise an empty level 1 build.
func build_for(id: int, class_id: String, local_id: int = 1) -> Dictionary:
	if id == local_id: return Profile.build_of(profile, class_id)
	var builds: Dictionary = remote_builds.get(id, {})
	if builds.has(class_id) and builds[class_id] is Dictionary:
		var build: Dictionary = builds[class_id].duplicate(true)
		build["class"] = class_id
		return build
	return {"class": class_id, "level": 1, "ranks": {}, "bar": []}


## Every class build of the local profile, to send to the host.
func all_builds() -> Dictionary:
	var out := {}
	for class_id: String in profile.classes: out[class_id] = Profile.build_of(profile, class_id)
	return out


## Host: stores a client's builds (shape-checked; ranks are checked again on use).
func receive_builds(id: int, builds: Variant) -> void:
	if not builds is Dictionary or builds.size() > 8: return
	var clean := {}
	for class_id: Variant in builds:
		if data.classes.has(str(class_id)) and builds[class_id] is Dictionary: clean[str(class_id)] = builds[class_id]
	remote_builds[id] = clean


## Enemy HP factor of the run's difficulty.
func hp_scale() -> float:
	return float(data.difficulties.get(difficulty, data.difficulties.normal).hp)


## Enemy damage to a hero, scaled by difficulty in whole hearts (the
## remainder carries over, so 1.3 x really means 30 % more over a fight).
func scale_incoming(id: int, damage: int) -> int:
	var factor := float(data.difficulties.get(difficulty, data.difficulties.normal).damage)
	if is_equal_approx(factor, 1.0) or damage <= 0: return damage
	var exact := float(damage) * factor + float(_damage_debt.get(id, 0.0))
	var whole := maxi(1, floori(exact))
	_damage_debt[id] = maxf(0.0, exact - whole)
	return whole


## Host: a boss enters the fight (first time a hero is noticed or hits it).
func mark_fight(enemy: Dictionary) -> void:
	if not enemy.has("fight_start"): enemy.fight_start = Time.get_ticks_msec() / 1000.0


## Host: an enemy fell. Gold and EXP for every hero; a real floor boss also
## rolls a soul shard for each hero who took part.
func enemy_fell(enemy: Dictionary, _owner: int) -> void:
	if bool(enemy.get("summoned", false)): return
	var kind := "boss" if Drops.can_drop(enemy) else "miniboss" if bool(enemy.get("miniboss", false)) else "kill"
	var gold := int(data.gold.per_boss) if kind == "boss" else int(data.gold.per_kill)
	for id: int in game.players: _send(id, {"kind": "exp", "exp": int(data.exp[kind]), "gold": gold})
	if kind != "boss": return
	var total := 0.0
	var tally: Dictionary = enemy.get("damage_by", {})
	for amount: float in tally.values(): total += amount
	var seconds := Time.get_ticks_msec() / 1000.0 - float(enemy.get("fight_start", Time.get_ticks_msec() / 1000.0))
	var floor_number := int(game.get("floor_index")) if game.get("floor_index") != null else 1
	var boss_lv := Drops.boss_level(data, floor_number, difficulty)
	for id: int in game.players:
		var player: Dictionary = game.players[id]
		var fight := {"present": int(player.hp) > 0 or tally.has(id), "seconds": seconds, "damage_share": float(tally.get(id, 0.0)) / maxf(total, 0.001)}
		_send(id, {"kind": "boss", "boss_id": str(enemy.get("kind", "boss")), "difficulty": difficulty,
			"completion": "%s:%d:%d" % [run_uid, floor_number, int(enemy.get("id", 0))], "boss_level": boss_lv, "fight": fight, "roll": _rng.randf()})


## Host: the party reached a new floor.
func floor_entered() -> void:
	for id: int in game.players: _send(id, {"kind": "exp", "exp": int(data.exp.floor), "gold": int(data.gold.per_floor)})


## Applies a reward event to this machine's profile (host for its own hero,
## or a client receiving it). `class_id` is the class the hero plays.
func apply_local(event: Dictionary, class_id: String) -> void:
	var state := Profile.class_state(profile, class_id)
	match str(event.get("kind", "")):
		"exp":
			profile.gold = int(profile.gold) + maxi(0, int(event.get("gold", 0)))
			var gained := Rules.add_exp(data, state, maxi(0, int(event.get("exp", 0))))
			if gained > 0: local_event.emit({"kind": "level", "level": int(state.level), "points": Rules.free_points(data, state)})
		"boss":
			var result := Drops.resolve(data, profile, str(event.boss_id), str(event.difficulty), str(event.completion),
				int(state.level), int(event.boss_level), Dictionary(event.fight), clampf(float(event.roll), 0.0, 0.999999))
			if bool(result.shard): local_event.emit({"kind": "shard", "have": int(profile.shards.have), "count": int(result.count)})
			else: local_event.emit({"kind": "boss", "reason": str(result.reason)})
	_dirty = true


## Saves the local profile when it changed (at most every few seconds, and on demand).
func step(delta: float) -> void:
	_save_timer -= delta
	if _dirty and _save_timer <= 0.0: save()


func save() -> void:
	_dirty = false
	_save_timer = 3.0
	Profile.save_profile(profile, save_path)


## Snapshot: the run's difficulty and the latest reward notes.
func snapshot() -> Dictionary:
	return {"difficulty": difficulty, "difficulty_name": str(data.difficulties.get(difficulty, {}).get("name", "")), "events": recent.duplicate(true)}


func _send(id: int, event: Dictionary) -> void:
	event.id = _next_id
	_next_id += 1
	event["class"] = str(game.players.get(id, {}).get("class_id", game.player_classes.get(id, "")))
	# The host is always peer 1; its own hero's events change this machine's profile.
	if id == 1: apply_local(event, str(event["class"]))
	elif game.has_method("send_progress_event"):
		game.send_progress_event(id, event)
	if str(event.kind) == "boss":
		recent.append({"id": event.id, "peer": id, "kind": "boss"})
		if recent.size() > 8: recent.pop_front()
