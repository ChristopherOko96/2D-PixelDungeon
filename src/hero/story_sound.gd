extends RefCounted
## The sound of the story worlds (src/hell/hell_game.gd: Krypta, Frostgruft,
## Hölle; docs/KLANG-KONZEPT.de.md, the keys: docs/KLANG-EREIGNISSE.de.md).
## The crypt's src/vfx/feedback.gd plays the combat sounds there
## (src/hero/story_feel.gd hands it the world's sfx.gd): hits, kills, blocks,
## the hero's hurt, shots and swings, footsteps, idle rattles and groans, the
## boss sting, room clear, defeat and level-up. This file fills the crypt
## snapshot's sound fields and routes what the world's kits still play
## directly, all from assets/data/audio_sfx.json:
## - every monster sounds in its material (rig_materials, audio_rules.json
##   materials on top: mat, coat, size, voice), the hell monsters by id, the
##   Frostgruft's by kind, guardians by look;
## - every attack winds up and fires like a crypt enemy's (attack,
##   attack_kind, attacks): the hell monsters' acts (fired by hell_monsters.gd's
##   sound hook, released), the Frostgruft's moves, basic enemies and guardian
##   kits name their crypt kind in story_attacks; regular monsters never take a
##   crypt boss sound (story_attacks.mob), guardians and bosses keep theirs.
##   With the world's own sfx.gd (play_ctx) the windups and attacks sound here,
##   at the monster (its raw attack first: audio_rules.json attacks.raw, then
##   the crypt kind, then windup_generic), and feedback.gd gets no kind;
## - while the hero's skills, relics and subclass act (source "hero") their
##   borrowed enemy sounds play at the hero's mix level, like the crypt's skill
##   casts; the moves' and kits' own attack sounds give way to the crypt routing;
## - a guardian's or boss's landings burst with the crypt's blast (a zone's own
##   strike sound first), raging guardians and Ignaroth's new forms roar.
## With the world's own sfx.gd it also sets up the world (configure, the
## world's reverb, the world's music, the particles' sound), moves the listener
## to the hero, dulls the world in gas, picks the floor of the steps, keeps
## the loops (heartbeat, gas breath, wading, talent zones, puddles), the
## companions' idle calls, the near misses of enemy shots and the ambience
## point sources going, and routes the talents' moments (talent), the
## monsters' zones (zone), voices and coats (mob_hit, mob_hurt, mob_died), the
## theme events (theme_event) and the damage over time (dot_tick).
## The body-part counters (part_breaks, part_regrows) are passed on as they
## are; nothing in the story worlds counts parts yet.
## Presentation only: the world stays authoritative.

const Music = preload("res://src/audio/music.gd")
const AudioMix = preload("res://src/audio/audio_mix.gd")
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
## The story world ("krypta", "frost", "hell") once the world's sfx.gd is set up.
var world := ""
## The hero's voice profile (audio_rules.json voices).
var voice := ""
var _clock := 0.0
var _blast_at := -INF
var _level := -1
var _audio_ready := false
var _medium := ""
var _cough_at := 0.0
var _amb_next: Dictionary = {}
var _pet_next: Dictionary = {}
var _rng := RandomNumberGenerator.new()


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


## The story world id of `game` (audio_rules.json worlds.by_theme by its theme file).
static func world_of(game: Node, rules: Dictionary) -> String:
	var worlds: Dictionary = rules.get("worlds", {})
	var file := str(game.get("theme_path")).get_file().get_basename()
	return str((worlds.get("by_theme", {}) as Dictionary).get(file, worlds.get("default", "")))


## The hero's voice profile in `game` (audio_rules.json voices: by sprite, else by class).
static func voice_of(game: Node, rules: Dictionary) -> String:
	var voices: Dictionary = rules.get("voices", {})
	var hero: Dictionary = game.get("hero") if game.get("hero") is Dictionary else {}
	var by_sprite: Dictionary = voices.get("by_sprite", {})
	var sprite := str(hero.get("sprite", ""))
	if by_sprite.has(sprite):
		return str(by_sprite[sprite])
	return str((voices.get("by_class", {}) as Dictionary).get(str(game.get("class_id")), ""))


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


## Theme event `event` (hell_game._sound) in the concept's keys first
## (audio_rules.json theme_events: the first key that can play); true when it
## is handled here (played, or dropped by keep_event), false to let the theme's
## own mapping play it (a key list with "keep" plays that too).
func theme_event(event: String, category := "") -> bool:
	var sfx := _real()
	if sfx == null:
		return false
	var spec: Variant = (_rules().get("theme_events", {}) as Dictionary).get(event)
	if not spec is Dictionary:
		return false
	if not keep_event(event):
		return true
	# a world interaction next to the hero: centred, never at a particle burst of the same frame
	var ctx := {"pos": Vector2.INF} if category == "" else {"pos": Vector2.INF, "category": category}
	for key: Variant in _list((spec as Dictionary).get("keys", [])):
		if sfx.can_play(str(key), ctx):
			sfx.play_ctx(str(key), ctx)
			return not bool((spec as Dictionary).get("keep", false))
	return false


## A tick of damage over time on the hero (hell_game._lose_hp soft): the
## element's hurt (hurt_element_<burn|poison|frost|void|shock> by the words of
## `why`, audio_rules.json dot_words) instead of the full punch; false when
## there is no such sound (the world plays its hurt as before).
func dot_tick(why: String) -> bool:
	var sfx := _real()
	if sfx == null:
		return false
	var words: Dictionary = _rules().get("dot_words", {})
	var lower := why.to_lower()
	var kind := ""
	for word: String in words:
		if lower.contains(word):
			kind = str(words[word])
			break
	if not sfx.can_play("hurt_element", {"set": kind}):
		return false
	sfx.play_ctx("hurt_element", {"set": kind})
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


## Plays `name` at world point `pos` (INF: centred) through the world's
## sfx.gd (ctx as in sfx.gd play_ctx); a plain player (tests) plays it only
## when it knows the name.
func at(name: String, pos: Vector2, ctx: Dictionary = {}) -> void:
	var sfx: Variant = g.get("sfx")
	if sfx == null:
		return
	if (sfx as Object).has_method("play_ctx"):
		var full := ctx.duplicate()
		if pos.is_finite():
			full.pos = pos
		sfx.play_ctx(name, full)
	elif sfx.has_effect(name):
		sfx.play(name, 0.08, str(ctx.get("category", "")))


## True when the world's sfx.gd is the full player (positions, sets, loops).
func real() -> bool:
	return _real() != null


## A boss shows itself (hell_monsters.gd start_intro): `cue` (its fly-in) and
## its own roar (boss_roar_<id>, else boss_vo_<id>_roar).
func boss_roar(m: Dictionary, cue := "") -> void:
	var sfx := _real()
	if sfx == null:
		return
	if cue != "":
		sfx.play_ctx(cue, {"pos": _mob_at(m)})
	sfx.play_ctx("boss_roar_" + rig(m), {"fallback": ["boss_vo_%s_roar" % rig(m)]})


## The hero's own sound `name` (centred, in his voice profile where it has one).
func hero(name: String, ctx: Dictionary = {}) -> void:
	var full := ctx.duplicate()
	full.hero = true
	at(name, Vector2.INF, full)


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


## How monster `m` sounds: {mat, coat, size, voice} from audio_rules.json
## materials, else the table's rig_materials, else its def's material.
func sound_of(m: Dictionary) -> Dictionary:
	var r := rig(m)
	var own: Variant = (_rules().get("materials", {}) as Dictionary).get(r)
	if own is Dictionary:
		return own
	var legacy: Variant = (table().get("rig_materials", {}) as Dictionary).get(r)
	if legacy is Dictionary:
		return legacy
	return {"mat": str(legacy) if legacy != null else str((m.get("def", {}) as Dictionary).get("material", "flesh"))}


## The crypt sound fields of monster `m` for feedback.gd: rig, attack
## ("windup", "active" or ""), attack_kind, attack_p (windup share),
## attacks (fired attacks), part_breaks, part_regrows. With the world's own
## sfx.gd the windup sounds here and attack_kind stays empty for feedback.gd.
func enemy(m: Dictionary) -> Dictionary:
	var out := {"rig": rig(m), "part_breaks": int(m.get("part_breaks", 0)), "part_regrows": int(m.get("part_regrows", 0))}
	out.merge(_attack(m))
	out.attacks = int(m.get("feel_attacks", 0))
	_roars(m)
	if _takes_attacks():
		var state := str(out.get("attack", ""))
		if state == "windup" and str(m.get("feel_wind", "")) != "windup":
			_windup_sound(m, str(out.get("attack_kind", "")))
		m.feel_wind = state
		out.attack_kind = ""
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
	m.feel_raw = [behavior]
	_fire(m, attack_kind("behaviors", [behavior], count, is_boss(m)))


## Sound hook of src/hell/hell_monsters.gd: the running act of hell monster
## `m` releases its strike, shot, wave or summon now; feedback.gd plays its
## crypt attack sound on the feel's next frame (with the world's sfx.gd it
## sounds here, at the monster).
func released(m: Dictionary) -> void:
	var act: Variant = m.get("act")
	if not act is Dictionary:
		return
	(act as Dictionary).feel_out = true
	m.feel_raw = [str((act as Dictionary).get("kind", ""))]
	_fire(m, _hell_kind(m, act))


## Once per frame (src/hero/story_feel.gd update): the level seen, the audio
## of the world (listener, gas, floor, loops, ambience) and the landings of the
## hell monsters' zones.
func frame(dt: float) -> void:
	_clock += dt
	_level = int(g.state.get("level", 0))
	_audio_frame()
	if g.get("monsters") == null:
		return
	var real := _real() != null
	var landings: Array = attacks.get("landings", [])
	var bosses_only := bool(attacks.get("landings_boss_only", true))
	for z: Dictionary in g.monsters.zones:
		# a zone that strikes after its telegraph sounds its own strike (audio_rules.json zones)
		if real and not bool(z.get("feel_snd", false)) and float(z.get("tele", 0.0)) > 0.0 and float(z.t) >= float(z.tele):
			z.feel_snd = true
			if _zone_strike(z):
				z.feel_blast = true
		if bool(z.get("feel_blast", false)) or float(z.t) < float(z.get("tele", 0.0)) or not str(z.kind) in landings:
			continue
		z.feel_blast = true
		if bosses_only and not is_boss(z.get("m")):
			continue
		# a crypt burst raised for this landing (story_feel.on_blast) already sounds through feedback.gd
		if _clock - _blast_at < float(attacks.get("blast_gap", 0.08)) or (g.feel != null and g.feel.burst_near(z.p, float(z.get("r", 60.0)))):
			continue
		_blast_at = _clock
		at("blast", Vector2(z.p))


# --- monsters ---------------------------------------------------------------------------

## A talent's hit on monster `m` (src/hell/hell_talents.gd _damage_enemy): its
## material's hit at the monster, then its voice and coat (mob_hurt).
func mob_hit(m: Dictionary) -> void:
	var sfx := _real()
	if sfx == null:
		g._sound("hit_" + str((m.get("def", {}) as Dictionary).get("material", "void")))
		return
	var look := sound_of(m)
	sfx.play_ctx("hit_" + str(look.get("mat", "flesh")), {"pos": _mob_at(m), "size": str(look.get("size", "")), "fallback": ["boss_hit" if is_boss(m) else "hit"]})
	mob_hurt(m)


## Monster `m` was hurt (its base hit sounds through feedback.gd or mob_hit):
## its coat's layer (coat_<coat>_hit), now and then its pain voice
## (vo_enemy_hurt_<mat>, monsters.hurt_voice_chance); a boss adds the deep
## boss_hit_layer and seldom its own voice (boss_vo_<rig>_hurt).
func mob_hurt(m: Dictionary) -> void:
	var sfx := _real()
	if sfx == null:
		return
	var look := sound_of(m)
	var where := _mob_at(m)
	var coat := str(look.get("coat", ""))
	if coat != "":
		sfx.play_ctx("coat_%s_hit" % coat, {"pos": where})
	var spec: Dictionary = _rules().get("monsters", {})
	if is_boss(m):
		sfx.play_ctx("boss_hit_layer", {"pos": where})
		if _rng.randf() < float(spec.get("boss_hurt_voice_chance", 0.15)):
			sfx.play_ctx("boss_vo_%s_hurt" % rig(m), {"fallback": ["boss_hurt_" + rig(m)]})
		return
	if _rng.randf() < float(spec.get("hurt_voice_chance", 0.3)):
		sfx.play_ctx("vo_enemy_hurt_" + str(look.get("mat", "flesh")), {"pos": where, "voice": str(look.get("voice", "")), "size": str(look.get("size", ""))})


## Monster `m` died (its kill sound plays through feedback.gd): its coat's end
## (coat_<coat>_kill) and its death voice (vo_enemy_death_<mat>, a boss's own
## boss_vo_<rig>_death).
func mob_died(m: Dictionary) -> void:
	var sfx := _real()
	if sfx == null:
		return
	var look := sound_of(m)
	var where := _mob_at(m)
	var coat := str(look.get("coat", ""))
	if coat != "":
		sfx.play_ctx("coat_%s_kill" % coat, {"pos": where})
	if is_boss(m):
		sfx.play_ctx("boss_vo_%s_death" % rig(m), {"fallback": ["boss_death_" + rig(m)]})
		return
	sfx.play_ctx("vo_enemy_death_" + str(look.get("mat", "flesh")), {"pos": where, "voice": str(look.get("voice", "")), "size": str(look.get("size", ""))})


## Sound hook of src/hell/hell_monsters.gd _zone: a monster zone appears. A
## puddle splashes in its element (puddle_spawn_<el>; the hero's own talent
## pool: tal_pool_<el>); an instant zone or one of zones.at_start (the meteor's
## whistle) sounds its key now; the others strike in frame().
func zone(z: Dictionary) -> void:
	var sfx := _real()
	if sfx == null:
		return
	var kind := str(z.get("kind", ""))
	var where := Vector2(z.get("p", Vector2.INF))
	if kind == "puddle":
		sfx.play_ctx("tal_pool" if bool(z.get("friend", false)) else "puddle_spawn", {"pos": where, "set": _zone_element(z)})
		return
	var spec: Dictionary = _rules().get("zones", {})
	var tele := float(z.get("tele", 0.0))
	if tele > 0.0 and not (kind in _list(spec.get("at_start", []))):
		return
	var key := str((spec.get("keys", {}) as Dictionary).get(kind, ""))
	if key == "":
		return
	if tele <= 0.0:
		z.feel_snd = true
	sfx.play_ctx(key, {"pos": where, "set": _zone_element(z)})


## A telegraphed zone strikes: its key (not for zones.at_start, which sounded
## at the start), a boss's landing (boss_landing_<kind>); false when none plays.
func _zone_strike(z: Dictionary) -> bool:
	var sfx := _real()
	var kind := str(z.get("kind", ""))
	var spec: Dictionary = _rules().get("zones", {})
	var keys: Dictionary = spec.get("keys", {})
	var names: Array = []
	if keys.has(kind) and not (kind in _list(spec.get("at_start", []))):
		names.append(str(keys[kind]))
	if is_boss(z.get("m")):
		names.append("boss_landing_" + kind)
	if names.is_empty():
		return false
	var first := str(names.pop_front())
	var ctx := {"pos": Vector2(z.get("p", Vector2.INF)), "set": _zone_element(z), "fallback": names}
	if not sfx.can_play(first, ctx):
		return false
	return sfx.play_ctx(first, ctx)


func _zone_element(z: Dictionary) -> String:
	var el := str(z.get("st", z.get("c", z.get("style", z.get("el", "")))))
	if el == "" and z.get("m") is Dictionary:
		return _element_of(z.m)
	return _el(el)


func _mob_at(m: Dictionary) -> Vector2:
	return Vector2(m.get("p", Vector2.INF))


func _element_of(m: Dictionary) -> String:
	var el := ""
	var mons: Variant = g.get("monsters")
	if mons != null:
		el = str(mons.own_element(m))
	if el == "":
		el = str((m.get("def", {}) as Dictionary).get("element", m.get("element", "")))
	return _el(el)


## The raw attack names of monster `m`'s running or last attack (an act's
## kind, a move's id and type, a kit's do, a behaviour).
func _raws(m: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var raw: Variant = m.get("feel_raw", [])
	for name: Variant in (raw if raw is Array else [raw]):
		if str(name) != "" and not str(name) in out:
			out.append(str(name))
	return out


## The windup of `m`'s attack at the monster: windup_<raw>, windup_<crypt
## kind>, then windup_generic (audio_rules.json prefix_fallback); heard a bit
## farther than other sounds (spatial.windup_reach).
func _windup_sound(m: Dictionary, kind: String) -> void:
	var names: Array = []
	for raw: String in _raws(m):
		names.append("windup_" + raw)
	if kind != "":
		names.append("windup_" + kind)
	if names.is_empty():
		return
	var first := str(names.pop_front())
	_real().play_ctx(first, {"pos": _mob_at(m), "set": _element_of(m), "fallback": names, "reach_scale": float(_spatial().get("windup_reach", 1.5))})


## The release of `m`'s attack at the monster: its raw attack's key
## (attacks.raw, in the monster's element), then attack_<crypt kind>. The
## bomber's fuse ends in its fx event's burst.
func _attack_sound(m: Dictionary, kind: String) -> void:
	if kind == "fuse":
		return
	var raw_map: Dictionary = (_rules().get("attacks", {}) as Dictionary).get("raw", {})
	var names: Array = []
	for raw: String in _raws(m):
		if raw_map.has(raw):
			names.append(str(raw_map[raw]))
	names.append("attack_" + kind)
	var first := str(names.pop_front())
	_real().play_ctx(first, {"pos": _mob_at(m), "set": _element_of(m), "fallback": names})


func _takes_attacks() -> bool:
	return _real() != null and bool((_rules().get("attacks", {}) as Dictionary).get("positional", true))


# --- talents ----------------------------------------------------------------------------

## Sound hook of src/combat/talent_combat.gd (its _event and the moments
## without one, through src/hell/hell_talents.gd talent_sound): kind, world
## point, the event's fields; `tc` the talent runtime (its talent data).
## Keys and sets: audio_rules.json talents (events, cast_by_type, status), in
## the talent's element; an ultimate's events play as focus, centred.
func talent(kind: String, where: Vector2, extra: Dictionary, tc: Object) -> void:
	var sfx := _real()
	if sfx == null:
		return
	var spec: Dictionary = _rules().get("talents", {})
	var id := str(extra.get("talent", ""))
	var info := _talent_info(tc, id)
	var el := _talent_element(extra, info, id)
	var ult := bool(extra.get("ult", false))
	var ctx := {"pos": where, "set": el}
	if ult:
		ctx = {"set": el, "category": "focus", "priority": 1}
	elif kind in _list(spec.get("hero_own", [])):
		ctx = {"set": el, "hero": true}
	if kind in _list(spec.get("pet_kinds", [])) or bool(extra.get("pet", false)):
		ctx.voice = _companion(str(extra.get("pet_kind", extra.get("kind", ""))))
	match kind:
		"cast":
			if ult or str(info.get("kind", "")) == "ultimate":
				sfx.play_ctx("ult_" + id, {"set": el, "category": "focus", "priority": 1, "fallback": ["ult_cast"]})
				sfx.play_ctx("vo_cast_ult", {})
				return
			sfx.play_ctx("tal_cast", {"set": el})
			var typed := str((spec.get("cast_by_type", {}) as Dictionary).get(str(info.get("type", "")), ""))
			if typed != "":
				sfx.play_ctx(typed, {"set": el, "hero": true})
			if _rng.randf() < float(spec.get("effort_chance", 0.3)):
				sfx.play_ctx("vo_effort", {})
		"nova":
			sfx.play_ctx("tal_meteor_hit" if bool(extra.get("impact", false)) else "tal_nova", ctx)
		"blink":
			sfx.play_ctx("blink_out", {"pos": where, "set": el})
			sfx.play_ctx("blink_in", {"pos": Vector2(float(extra.get("tx", where.x)), float(extra.get("ty", where.y))), "set": el, "delay": 0.05})
		"chain":
			var points := _list(extra.get("points", []))
			var step := float(spec.get("chain_step_s", 0.06))
			for i in range(mini(points.size(), 6)):
				sfx.play_ctx("tal_chain", {"pos": _point(points[i], where), "set": el, "pitch": 1.0 + float(spec.get("chain_pitch_step", 0.06)) * i, "delay": step * i})
		"swallow":
			sfx.play_ctx("void_gulp", ctx)
			var els: Dictionary = extra.get("els", {}) if extra.get("els") is Dictionary else {}
			if int(extra.get("stored", 0)) > 0:
				sfx.play_ctx("gefuege_store", {"hero": true, "set": _el(str(els.keys()[0])) if not els.is_empty() else ""})
		"shout":
			if bool(extra.get("pet", false)):
				sfx.play_ctx("pet_ability_2", ctx)
			else:
				sfx.play_ctx("tal_taunt_area", {"hero": true})
				sfx.play_ctx("vo_taunt", {})
		"dodge":
			sfx.play_ctx("dodge", ctx)
			if _rng.randf() < float(spec.get("dodge_effort_chance", 0.4)):
				sfx.play_ctx("vo_effort", {})
		_:
			var key := ""
			if kind.begins_with("status_"):
				key = str((spec.get("status", {}) as Dictionary).get(kind.substr(7), kind))
			else:
				key = str((spec.get("events", {}) as Dictionary).get(kind, ""))
			if key != "" and key.begins_with("pet_ability") and id != "":
				# a companion's ability by its own name first (pet_<ability id>@<companion>)
				var named := ctx.duplicate()
				named.fallback = [key]
				sfx.play_ctx("pet_" + id, named)
			elif key != "":
				sfx.play_ctx(key, ctx)


func _talent_info(tc: Object, id: String) -> Dictionary:
	if tc == null or id == "":
		return {}
	var data: Variant = tc.get("data")
	if not data is Dictionary:
		return {}
	var talents: Variant = (data as Dictionary).get("talents")
	return (talents as Dictionary).get(id, {}) if talents is Dictionary else {}


## The element a talent moment sounds in (audio_rules.json elements.alias of
## the event's el, fx or style, the talent's fx, style, element or status, its
## id prefix); "" when none is known.
func _talent_element(extra: Dictionary, info: Dictionary, id: String) -> String:
	var elements: Dictionary = _rules().get("elements", {})
	var alias: Dictionary = elements.get("alias", {})
	for value: Variant in [extra.get("el", ""), extra.get("fx", ""), extra.get("style", ""), info.get("fx", ""), info.get("style", ""), info.get("element", ""), info.get("status", ""), id.get_slice("_", 0)]:
		var name := str(value)
		if name == "":
			continue
		if name == "arcane" and id.begins_with(str(elements.get("void_prefix", "arcane_"))):
			return "void"
		if alias.has(name):
			return str(alias[name])
	return ""


func _companion(kind: String) -> String:
	return str((_voices().get("companion_by_kind", {}) as Dictionary).get(kind, kind))


static func _point(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	if value is Array and (value as Array).size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	if value is Dictionary:
		return Vector2(float((value as Dictionary).get("x", fallback.x)), float((value as Dictionary).get("y", fallback.y)))
	return fallback


# --- the world's audio each frame -------------------------------------------------------

func _audio_frame() -> void:
	var sfx := _real()
	if sfx == null:
		return
	if not _audio_ready:
		_setup(sfx)
	var hero_at := Vector2(float(g.player.x), float(g.player.y) - float(_spatial().get("listener_lift_px", 40)))
	sfx.listen(hero_at)
	var vision: Variant = g.get("vision")
	if vision is Dictionary:
		var gas_mat := str((vision as Dictionary).get("mat", ""))
		sfx.muffle(float((vision as Dictionary).get("k", 0.0)), gas_mat if gas_mat != "" else str(g.get("hero_gas_mat")))
	sfx.surface = _surface()
	_hero_loops(sfx)
	_pets(sfx)
	_passby(sfx, hero_at)
	_ambience(sfx, hero_at)
	_zone_loops(sfx, hero_at)


## Once per world: the world and the hero's voice into sfx.gd (story mode: no
## beeps), the world's reverb, the world's music, the feel's particles.
func _setup(sfx: Node) -> void:
	_audio_ready = true
	world = world_of(g, _rules())
	voice = voice_of(g, _rules())
	sfx.configure(world, voice, true)
	AudioMix.set_space(world)
	var music: Variant = g.get("music")
	if music != null and (music as Object).has_method("set_world"):
		music.set_world(world)
	var feel: Variant = g.get("feel")
	if feel != null:
		sfx.attach_particles(feel.feedback.particles, float(feel.scale))


## The hero's floor for the steps (audio_rules.json surfaces): the medium he
## wades in, else the world's floor.
func _surface() -> String:
	var spec: Dictionary = _rules().get("surfaces", {})
	var medium: Variant = g.get("hero_medium")
	if medium is Dictionary and not (medium as Dictionary).is_empty():
		var media: Dictionary = spec.get("media", {})
		var style := str(g.get("hero_medium_style"))
		if media.has(style):
			return str(media[style])
	return str(spec.get(world, ""))


## The hero's loops: the heartbeat below 30 % life (faster below 15 %), the
## breath in gas (and a cough now and then, not in steam), wading in a medium
## with its splash in and out.
func _hero_loops(sfx: Node) -> void:
	var alive := int(g.state.get("hp", 0)) > 0 and float(g.state.get("dead", 0.0)) <= 0.0
	var share := float(g.hp_f()) / maxf(1.0, float(g.state.get("max_hp", 1)))
	sfx.set_loop("lowhp", "lowhp_heartbeat", alive and share < 0.3, {"hero": true, "pitch": 1.25 if share < 0.15 else 1.0})
	var gas: Variant = g.get("hero_gas")
	var mat := str(g.get("hero_gas_mat"))
	var in_gas: bool = alive and gas is Dictionary and not (gas as Dictionary).is_empty()
	sfx.set_loop("gas", "gas_breath", in_gas, {"set": mat})
	if in_gas and not (mat in _list(_rules().get("cough_except", []))) and _clock >= _cough_at:
		_cough_at = _clock + 1.2 + _rng.randf() * 1.5
		sfx.play_ctx("vo_cough", {})
	var medium: Variant = g.get("hero_medium")
	var style := str(g.get("hero_medium_style")) if medium is Dictionary and not (medium as Dictionary).is_empty() else ""
	if style != _medium:
		if _medium != "":
			sfx.play_ctx("medium_exit", {"set": _medium})
		if style != "":
			sfx.play_ctx("medium_enter", {"set": style})
		_medium = style
	sfx.set_loop("wade", "medium_wade", alive and style != "", {"set": style})


## Now and then a companion calls (pet_idle@<companion>, every 6-12 s each).
func _pets(sfx: Node) -> void:
	var talents: Variant = g.get("talents")
	var tc: Variant = (talents as Object).get("tc") if talents != null else null
	var pets: Variant = (tc as Object).get("pets") if tc != null else null
	if not pets is Array:
		return
	for pet: Variant in pets:
		if not pet is Dictionary:
			continue
		var p: Dictionary = pet
		var id := int(p.get("id", 0))
		if not _pet_next.has(id):
			_pet_next[id] = _clock + _rng.randf_range(3.0, 8.0)
		elif _clock >= float(_pet_next[id]):
			_pet_next[id] = _clock + _rng.randf_range(6.0, 12.0)
			sfx.play_ctx("pet_idle", {"pos": Vector2(p.get("pos", Vector2.INF)), "voice": _companion(str(p.get("kind", "")))})
	if _pet_next.size() > 64:
		_pet_next.clear()


## An enemy shot passing close by hisses once (eshot_passby, spatial.passby_px).
func _passby(sfx: Node, hero_at: Vector2) -> void:
	var shots: Variant = g.get("eshots")
	if not shots is Array:
		return
	var reach := float(_spatial().get("passby_px", 150))
	for s: Variant in shots:
		if not s is Dictionary or (s as Dictionary).has("feel_by"):
			continue
		var shot: Dictionary = s
		var where := Vector2(shot.get("p", Vector2.INF))
		if where.is_finite() and where.distance_to(hero_at) < reach:
			shot.feel_by = true
			sfx.play_ctx("eshot_passby", {"pos": where})


## The world's ambience point sources (audio_rules.json ambience[world]): a
## drop, a creak or a far chain at a random spot around the hero now and then.
func _ambience(sfx: Node, hero_at: Vector2) -> void:
	for entry: Variant in _list((_rules().get("ambience", {}) as Dictionary).get(world, [])):
		if not entry is Dictionary:
			continue
		var e: Dictionary = entry
		var name := str(e.get("event", ""))
		var every := _list(e.get("every", [5, 10]))
		if not _amb_next.has(name):
			_amb_next[name] = _clock + _between(every)
		elif _clock >= float(_amb_next[name]):
			_amb_next[name] = _clock + _between(every)
			sfx.play_ctx(name, {"pos": hero_at + Vector2.from_angle(_rng.randf() * TAU) * _between(_list(e.get("near", [200, 900]))), "category": "ambience"})


## Loops of what lies near the hero: the talents' zones (tal_zone_loop_<el>)
## and the three nearest puddles (puddle_loop_<el>; a charged one also hums: charge_loop).
func _zone_loops(sfx: Node, hero_at: Vector2) -> void:
	var tile := float(_spatial().get("tile_px", 96))
	var talents: Variant = g.get("talents")
	var tc: Variant = (talents as Object).get("tc") if talents != null else null
	var zones: Variant = (tc as Object).get("zones") if tc != null else null
	if zones is Array:
		for z: Variant in zones:
			if not z is Dictionary:
				continue
			var zone_at := Vector2((z as Dictionary).get("pos", Vector2.INF))
			if zone_at.is_finite() and zone_at.distance_to(hero_at) < tile * 8.0:
				sfx.set_loop("tz%d" % int((z as Dictionary).get("id", 0)), "tal_zone_loop", true, {"pos": zone_at, "set": _el(str((z as Dictionary).get("status", "")))})
	var mons: Variant = g.get("monsters")
	if mons == null:
		return
	var near: Array = []
	for z: Dictionary in mons.zones:
		if str(z.get("kind", "")) != "puddle":
			continue
		var d := Vector2(z.get("p", Vector2.INF)).distance_to(hero_at)
		if d < tile * 6.0:
			near.append([d, z])
	near.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	for i in range(mini(3, near.size())):
		var z: Dictionary = near[i][1]
		sfx.set_loop("pd%d" % int(z.get("id", i)), "puddle_loop", true, {"pos": Vector2(z.p), "set": _zone_element(z), "category": "ambience"})
		if float(z.get("charge", 0.0)) > 0.0:
			sfx.set_loop("ch%d" % int(z.get("id", i)), "charge_loop", true, {"pos": Vector2(z.p)})


# --- inside -----------------------------------------------------------------------------

## The world's sfx.gd when it is the full player (play_ctx), else null (a
## plain test player keeps the crypt routing as it was).
func _real() -> Node:
	var sfx: Variant = g.get("sfx")
	return sfx if sfx is Node and (sfx as Node).has_method("play_ctx") else null


func _rules() -> Dictionary:
	var sfx := _real()
	return sfx.rules if sfx != null else {}


func _spatial() -> Dictionary:
	return _rules().get("spatial", {})


func _voices() -> Dictionary:
	return _rules().get("voices", {})


func _el(name: String) -> String:
	var alias: Dictionary = (_rules().get("elements", {}) as Dictionary).get("alias", {})
	return str(alias.get(name, name))


func _between(pair: Array) -> float:
	var low := float(pair[0]) if pair.size() > 0 else 1.0
	var high := float(pair[1]) if pair.size() > 1 else low
	return _rng.randf_range(low, high)


static func _list(v: Variant) -> Array:
	return v if v is Array else []


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


## Counts one fired attack in crypt kind `kind` (feedback plays attack_<kind>;
## with the world's sfx.gd it sounds here, at the monster).
func _fire(m: Dictionary, kind: String) -> void:
	if kind == "":
		return
	m.feel_attacks = int(m.get("feel_attacks", 0)) + 1
	m.feel_kind = kind
	if _takes_attacks():
		_attack_sound(m, kind)


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
	m.feel_raw = [str(run.id), str(spec.type)]
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
	m.feel_raw = [str(a.get("kind", ""))]
	var out := bool(a.get("feel_out", false)) and not bool(a.get("warn", false))
	return {"attack": "active" if out else "windup", "attack_kind": _hell_kind(m, a), "attack_p": 0.0}


## The crypt kind of hell act `a` of monster `m` (story_attacks.hell).
func _hell_kind(m: Dictionary, a: Dictionary) -> String:
	return attack_kind("hell", [str(a.kind)], int((a.get("a", {}) as Dictionary).get("count", 1)), is_boss(m))


## A guardian kit (src/hell/boss_kit.gd): instant attacks fire at their start,
## timed ones with a windup fire when it ends, telegraph_only ones only wind up.
func _kit(m: Dictionary) -> Dictionary:
	var started: Dictionary = {}
	var at_i := int(m.get("atk_i", 0))
	var stand := bool(m.get("stand_done", false))
	if m.has("feel_atk_i"):
		var attacks_now: Array = (m.kit.phases[int(m.phase)] as Dictionary).get("attacks", [])
		if at_i > int(m.feel_atk_i) and not attacks_now.is_empty():
			started = attacks_now[(at_i - 1) % attacks_now.size()]
		if stand and not bool(m.get("feel_stand", false)):
			started = {"do": "last_stand"}
	m.feel_atk_i = at_i
	m.feel_stand = stand
	var busy: Dictionary = m.get("busy", {})
	if not started.is_empty():
		var does := str(started.do)
		m.feel_raw = [does]
		var kind := attack_kind("kits", [does], int(started.get("count", 1)))
		if does in attacks.get("telegraph_only", []):
			return {"attack": "windup", "attack_kind": kind, "attack_p": 0.0}
		if not (busy.has("windup") and str(busy.get("do", "")) == does):
			_fire(m, kind)
	if busy.has("windup"):
		m.feel_raw = [str(busy.do)]
		var fired := float(busy.get("e", 0.0)) >= float(busy.windup)
		return _track(m, busy, "active" if fired else "windup", fired, attack_kind("kits", [str(busy.do)]), float(busy.get("e", 0.0)) / maxf(0.01, float(busy.windup)))
	return _track(m, null, "", false, "", 0.0)


## The crypt's rage roar when a Frostgruft guardian rages (frost_moves.gd
## rage_below) or Ignaroth changes into his next form; only guardians and
## bosses roar, like the crypt's (boss_rage / boss_form_swap and the boss's
## own roar first with the world's sfx.gd).
func _roars(m: Dictionary) -> void:
	var boss := is_boss(m)
	var rage := bool((m.get("mv", {}) as Dictionary).get("rage", false))
	if m.has("mv"):
		if rage and not bool(m.get("feel_rage", true)) and boss:
			_boss_cue(m, "boss_rage")
		m.feel_rage = rage
	var trans: Variant = m.get("trans")
	var swapped: bool = trans is Dictionary and bool((trans as Dictionary).get("swapped", false))
	if swapped and not bool(m.get("feel_swapped", false)) and boss:
		_boss_cue(m, "boss_form_swap")
	m.feel_swapped = swapped


func _boss_cue(m: Dictionary, name: String) -> void:
	var sfx := _real()
	if sfx == null:
		_play("attack_roar")
		return
	sfx.play_ctx(name, {"fallback": ["attack_roar"]})
	sfx.play_ctx("boss_roar_" + rig(m), {"fallback": ["boss_vo_%s_roar" % rig(m)]})


func _play(name: String) -> void:
	if g.sfx != null and g.sfx.has_effect(name):
		g.sfx.play(name, 0.08, "")
