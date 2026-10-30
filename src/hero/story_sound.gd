extends RefCounted
## The crypt's sound standard in the story worlds (src/hell/hell_game.gd:
## Hell-Dungeon and Frostgruft). The crypt's src/vfx/feedback.gd plays the
## combat sounds there (src/hero/story_feel.gd hands it the world's sfx.gd):
## hits, kills, blocks, the hero's hurt, shots and swings, footsteps, idle
## rattles and groans, the boss sting, room clear, defeat and level-up. This
## file fills the crypt snapshot's sound fields and routes what the world's
## kits still play directly, all from assets/data/audio_sfx.json:
## - every monster sounds in its crypt material (rig_materials: bone, flesh,
##   void), the hell monsters by id, the Frostgruft's by kind, guardians by look;
## - every attack winds up and fires like a crypt enemy's (attack, attack_kind,
##   attacks): the hell monsters' acts (fired by hell_monsters.gd's sound hook,
##   released), the Frostgruft's moves, basic enemies and guardian kits name
##   their crypt kind in story_attacks; regular monsters never take a crypt
##   boss sound (story_attacks.mob), guardians and bosses keep theirs;
## - while the hero's skills, relics and subclass act (source "hero") their
##   borrowed enemy sounds play at the hero's mix level, like the crypt's skill
##   casts; the moves' and kits' own attack sounds give way to the crypt routing;
## - a guardian's or boss's landings burst with the crypt's blast, raging
##   guardians and Ignaroth's new forms roar.
## The body-part counters (part_breaks, part_regrows) are passed on as they
## are; nothing in the story worlds counts parts yet.
## Presentation only: the world stays authoritative.

const Music = preload("res://src/audio/music.gd")
const BossKit = preload("res://src/hell/boss_kit.gd")
const TABLE_PATH := "res://assets/data/audio_sfx.json"
## Seconds a crypt burst of src/hero/story_feel.gd counts as the same landing.
const BURST_WINDOW := 0.15

static var _table: Dictionary = {}

var g: Node
## Who is acting while the world runs a kit: "" (the world), "hero" (skills,
## relics, subclass, the hero's allies), "moves" (src/hell/frost_moves.gd) or
## "kit" (src/hell/boss_kit.gd). Set by src/hell/hell_game.gd.
var source := ""
## The story_attacks block of audio_sfx.json.
var attacks: Dictionary = {}
var _clock := 0.0
var _blast_at := -INF
var _level := -1


## `game` is the story world.
func _init(game: Node) -> void:
	g = game
	attacks = table().get("story_attacks", {})


## The sound table (assets/data/audio_sfx.json), cached.
static func table() -> Dictionary:
	if _table.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(TABLE_PATH)) if FileAccess.file_exists(TABLE_PATH) else null
		_table = parsed if parsed is Dictionary else {"events": {}, "rig_materials": {}}
	return _table


## True for a guardian or boss (the crypt's boss and minibosses), false for a
## regular monster.
static func is_boss(m: Variant) -> bool:
	if not m is Dictionary:
		return false
	var d: Dictionary = m
	return str(d.get("kind", "")) == "boss" or bool(d.get("boss", false))


# --- the world's direct sounds ----------------------------------------------------------

## False when a theme event (hell_game._sound) is the crypt's to play now: a
## guardian kit's own attack sound while the kit runs (boss_kit.gd
## ATTACK_SOUNDS; story_attacks.kits sounds it through feedback.gd) or the
## hero's level-up (feedback's level-up stinger from the snapshot's team
## level). Whatever else plays while a kit runs (a blow the subclass absorbs,
## the phoenix) still sounds.
func keep_event(event: String) -> bool:
	if source == "kit" and event in BossKit.ATTACK_SOUNDS.values():
		return false
	if event == "level_up" and _level >= 0 and int(g.state.get("level", 0)) > _level:
		return false
	return true


## False when a direct sound (hell_game._sound_raw) is the crypt's to play now:
## the Frostgruft moves' windups and attacks fire through feedback.gd, their
## blink stays silent and their ice armour sounds as the crypt's armour fx
## (story_attacks.moves_drop, move_fx).
func keep_raw(name: String) -> bool:
	if source != "moves":
		return true
	return not (name.begins_with("windup_") or name.begins_with("attack_") or name in attacks.get("moves_drop", []))


## The mix group a direct sound plays in: the hero's own while the hero acts,
## else the event's (src/audio/audio_mix.gd categories).
func raw_category() -> String:
	return "hero" if source == "hero" else ""


# --- the crypt snapshot -----------------------------------------------------------------

## The story world's phase in the crypt's words (feedback.gd room sounds,
## src/audio/music.gd): "dead" while the hero dies or after a lost run,
## "combat" while the hero's room fights, "reward" in a cleared room, else
## "explore". A pit that ends a fight is no clear.
static func phase(game: Node) -> String:
	var over: Dictionary = game.state.get("over", {})
	if float(game.state.get("dead", 0.0)) > 0.0 or (not over.is_empty() and not bool(over.get("won", false))):
		return "dead"
	var room: Dictionary = game.W.rooms[int(game.state.room)]
	if bool(room.get("fight", false)):
		return "combat"
	return "reward" if bool(room.get("cleared", false)) else "explore"


## The crypt's music state for the story world (src/audio/music.gd decide).
static func music_state(game: Node) -> String:
	var enemies: Array = []
	for m: Dictionary in game.mobs:
		enemies.append({"hp": float(m.hp), "boss": is_boss(m)})
	return Music.decide({"phase": phase(game), "enemies": enemies}, true)


## The crypt rig name monster `m` sounds like (a key of rig_materials): its
## real rig (src/combat/body_parts.gd), a hell monster's id, a Frostgruft
## kind, a guardian's look (its "rig", else its sprite without prefix and
## frame suffix: mob_frost_necromancer_f -> frost_necromancer).
static func rig(m: Dictionary) -> String:
	# a crypt rig worn at another world's size (drake_rig_host.gd adopt_looks: "skeleton@5@bone") sounds as that rig
	if str(m.get("rig", "")) != "":
		return str(m.rig).get_slice("@", 0)
	if m.has("id"):
		return str(m.id)
	var kind := str(m.get("kind", ""))
	if kind != "boss":
		return kind
	var look: Dictionary = m.get("look", {})
	if str(look.get("rig", "")) != "":
		return str(look.rig)
	var parts := Array(str(look.get("sprite", "")).split("_"))
	if not parts.is_empty() and str(parts[0]) in ["mob", "boss"]:
		parts.pop_front()
	while parts.size() > 1 and (str(parts[-1]) == "f" or str(parts[-1]).is_valid_int() or (str(parts[-1]).begins_with("p") and str(parts[-1]).substr(1).is_valid_int())):
		parts.pop_back()
	return "_".join(PackedStringArray(parts)) if not parts.is_empty() and str(parts[0]) != "" else kind


## The crypt sound fields of monster `m` for feedback.gd: rig, attack
## ("windup", "active" or ""), attack_kind, attack_p (windup share),
## attacks (fired attacks), part_breaks, part_regrows.
func enemy(m: Dictionary) -> Dictionary:
	var out := {"rig": rig(m), "part_breaks": int(m.get("part_breaks", 0)), "part_regrows": int(m.get("part_regrows", 0))}
	out.merge(_attack(m))
	out.attacks = int(m.get("feel_attacks", 0))
	_roars(m)
	return out


## The crypt attack kind of story attack `names` (the first that story_attacks
## knows; a Frostgruft move by id, then by type) in `group` ("hell", "moves",
## "behaviors", "kits") with `count` shots: a volley of many_from or more as
## many[group][name]. A regular monster (`boss` false) never takes a crypt
## boss kind: it sounds as mob[group][name] (mob.many for a volley), else as
## mob.any[kind]. "" stays silent.
func attack_kind(group: String, names: Array, count := 1, boss := true) -> String:
	var many := count >= int(attacks.get("many_from", 3))
	var found: Variant = _look(attacks, group, names, many)
	var kind := str(found) if found != null else ""
	if boss or not boss_only(kind):
		return kind
	var mob: Dictionary = attacks.get("mob", {})
	var calm: Variant = _look(mob, group, names, many)
	if calm != null and not boss_only(str(calm)):
		return str(calm)
	return str((mob.get("any", {}) as Dictionary).get(kind, ""))


## True for a crypt attack kind only the crypt's bosses and minibosses use:
## its attack_<kind> sounds in the boss mix group (roar, slam, salve, beam),
## except story_attacks.mob.keeps (summon: the crypt's necromancer summons too).
func boss_only(kind: String) -> bool:
	if kind == "" or kind in (attacks.get("mob", {}) as Dictionary).get("keeps", []):
		return false
	var event: Variant = (table().get("events", {}) as Dictionary).get("attack_" + kind)
	return event is Dictionary and str((event as Dictionary).get("category", "")) == "boss"


## A one-shot attack of a basic Frostgruft enemy (behaviour shooter, turret,
## dasher; `count` shots): it fires now in its crypt kind.
func on_attack(m: Dictionary, behavior: String, count := 1) -> void:
	_fire(m, attack_kind("behaviors", [behavior], count, is_boss(m)))


## Sound hook of src/hell/hell_monsters.gd: the running act of hell monster
## `m` releases its strike, shot, wave or summon now; feedback.gd plays its
## crypt attack sound on the feel's next frame.
func released(m: Dictionary) -> void:
	var act: Variant = m.get("act")
	if not act is Dictionary:
		return
	(act as Dictionary).feel_out = true
	_fire(m, _hell_kind(m, act))


## Once per frame (src/hero/story_feel.gd update): the level seen and the
## landings of the hell guardians and bosses.
func frame(dt: float) -> void:
	_clock += dt
	_level = int(g.state.get("level", 0))
	if g.get("monsters") == null:
		return
	var landings: Array = attacks.get("landings", [])
	var bosses_only := bool(attacks.get("landings_boss_only", true))
	for z: Dictionary in g.monsters.zones:
		if bool(z.get("feel_blast", false)) or float(z.t) < float(z.get("tele", 0.0)) or not str(z.kind) in landings:
			continue
		z.feel_blast = true
		if bosses_only and not is_boss(z.get("m")):
			continue
		# a crypt burst raised for this landing (story_feel.on_blast) already sounds through feedback.gd
		if _clock - _blast_at < float(attacks.get("blast_gap", 0.08)) or (g.feel != null and g.feel.burst_near(z.p, float(z.get("r", 60.0)))):
			continue
		_blast_at = _clock
		_play("blast")


# --- inside -----------------------------------------------------------------------------

## The first of `names` that `map` knows in `group` (a volley first in
## map.many[group]); null when none.
static func _look(map: Dictionary, group: String, names: Array, many: bool) -> Variant:
	var volley: Dictionary = (map.get("many", {}) as Dictionary).get(group, {})
	var single: Dictionary = map.get(group, {})
	for name: Variant in names:
		if many and volley.has(name):
			return str(volley[name])
		if single.has(name):
			return str(single[name])
	return null


## Counts one fired attack in crypt kind `kind` (feedback plays attack_<kind>).
func _fire(m: Dictionary, kind: String) -> void:
	if kind == "":
		return
	m.feel_attacks = int(m.get("feel_attacks", 0)) + 1
	m.feel_kind = kind


## Follows the running attack `act` (a dict the world keeps while it runs, or
## null): a new one starts unfired; it fires once when `fired` turns true.
func _track(m: Dictionary, act: Variant, state: String, fired: bool, kind: String, share: float) -> Dictionary:
	if act == null:
		m.feel_act = null
		return {"attack": "", "attack_kind": str(m.get("feel_kind", "")), "attack_p": 0.0}
	if not is_same(m.get("feel_act"), act):
		m.feel_act = act
		m.feel_fired = false
	if fired and not bool(m.get("feel_fired", false)):
		_fire(m, kind)
	m.feel_fired = fired
	return {"attack": state, "attack_kind": kind, "attack_p": clampf(share, 0.0, 1.0)}


func _attack(m: Dictionary) -> Dictionary:
	if m.has("act"):
		return _hell_act(m)
	if m.has("kit"):
		return _kit(m)
	var run: Dictionary = (m.get("mv", {}) as Dictionary).get("run", {})
	if run.is_empty():
		return _track(m, null, "", false, "", 0.0)
	# a Frostgruft move (src/hell/frost_moves.gd): windup -> active -> recovery
	var spec: Dictionary = run.spec
	var count := int(spec.get("count", 1)) if str(spec.get("pattern", "")) in ["fan", "ring"] else 1
	var kind := attack_kind("moves", [str(run.id), str(spec.type)], count, is_boss(m))
	var windup := str(run.phase) == "windup"
	var state := "windup" if windup else ("active" if str(run.phase) == "active" else "")
	var was_out := is_same(m.get("feel_act"), run) and bool(m.get("feel_fired", false))
	var out := _track(m, run, state, not windup, kind, 1.0 - float(run.t) / maxf(0.01, float(spec.get("windup", 0.5))))
	# a move the crypt shows as an fx event of its own (the ice armour) raises it as it releases
	var fx := str((attacks.get("move_fx", {}) as Dictionary).get(str(spec.type), ""))
	if not windup and not was_out and fx != "" and g.get("feel") != null:
		g.feel.fx_event(fx, m.p)
	return out


## A hell monster's act (src/hell/hell_monsters.gd _run_act, _run_dragon_act):
## it winds up until hell_monsters' sound hook releases it (released) and again
## while a repeat warns (a dash or beam with warn). The hell monsters animate
## their own windups, so the crypt's lean-back share stays 0.
func _hell_act(m: Dictionary) -> Dictionary:
	var act: Variant = m.act
	if act == null:
		return _track(m, null, "", false, "", 0.0)
	var a: Dictionary = act
	var out := bool(a.get("feel_out", false)) and not bool(a.get("warn", false))
	return {"attack": "active" if out else "windup", "attack_kind": _hell_kind(m, a), "attack_p": 0.0}


## The crypt kind of hell act `a` of monster `m` (story_attacks.hell).
func _hell_kind(m: Dictionary, a: Dictionary) -> String:
	return attack_kind("hell", [str(a.kind)], int((a.get("a", {}) as Dictionary).get("count", 1)), is_boss(m))


## A guardian kit (src/hell/boss_kit.gd): instant attacks fire at their start,
## timed ones with a windup fire when it ends, telegraph_only ones only wind up.
func _kit(m: Dictionary) -> Dictionary:
	var started: Dictionary = {}
	var at := int(m.get("atk_i", 0))
	var stand := bool(m.get("stand_done", false))
	if m.has("feel_atk_i"):
		var attacks_now: Array = (m.kit.phases[int(m.phase)] as Dictionary).get("attacks", [])
		if at > int(m.feel_atk_i) and not attacks_now.is_empty():
			started = attacks_now[(at - 1) % attacks_now.size()]
		if stand and not bool(m.get("feel_stand", false)):
			started = {"do": "last_stand"}
	m.feel_atk_i = at
	m.feel_stand = stand
	var busy: Dictionary = m.get("busy", {})
	if not started.is_empty():
		var does := str(started.do)
		var kind := attack_kind("kits", [does], int(started.get("count", 1)))
		if does in attacks.get("telegraph_only", []):
			return {"attack": "windup", "attack_kind": kind, "attack_p": 0.0}
		if not (busy.has("windup") and str(busy.get("do", "")) == does):
			_fire(m, kind)
	if busy.has("windup"):
		var fired := float(busy.get("e", 0.0)) >= float(busy.windup)
		return _track(m, busy, "active" if fired else "windup", fired, attack_kind("kits", [str(busy.do)]), float(busy.get("e", 0.0)) / maxf(0.01, float(busy.windup)))
	return _track(m, null, "", false, "", 0.0)


## The crypt's rage roar when a Frostgruft guardian rages (frost_moves.gd
## rage_below) or Ignaroth changes into his next form; only guardians and
## bosses roar, like the crypt's.
func _roars(m: Dictionary) -> void:
	var boss := is_boss(m)
	var rage := bool((m.get("mv", {}) as Dictionary).get("rage", false))
	if m.has("mv"):
		if rage and not bool(m.get("feel_rage", true)) and boss:
			_play("attack_roar")
		m.feel_rage = rage
	var trans: Variant = m.get("trans")
	var swapped: bool = trans is Dictionary and bool((trans as Dictionary).get("swapped", false))
	if swapped and not bool(m.get("feel_swapped", false)) and boss:
		_play("attack_roar")
	m.feel_swapped = swapped


func _play(name: String) -> void:
	if g.sfx != null and g.sfx.has_effect(name):
		g.sfx.play(name, 0.08, "")
