extends RefCounted
## The talent trees in the Frostgruft and the Hölle (src/hell/hell_game.gd),
## so every map plays the same 54 talents: this object stands in for the crypt
## game towards src/combat/talent_combat.gd (players, enemies, damage,
## statuses, movement, projectiles) and translates to the hell runtime: the
## hero (player.x/y, state.hp, state.dmg), the mobs (m.p, m.r, m.hp), the
## hell's status helpers (HeroKit.slow_mob / burn_mob / poison_mob / bleed_mob,
## SubKit.freeze), its
## walls (box_blocked) and its HUD. It also brings EXP, gold, level-ups and
## the difficulty of the shared profile into these maps.
## The Leerenmagier's Arkanes Gefüge works here too: the world's void
## (src/hell/story_elements.gd) feeds it through feed_all, his pools are
## friendly puddles of the monster runtime (talent_pool), and Leerenschild
## catches the monsters' shots (g.eshots) before they move (_catch_shots).

const HudKit = preload("res://src/ui/hud_kit.gd")
const TalentCombat = preload("res://src/combat/talent_combat.gd")
const TalentFx = preload("res://src/vfx/talent_fx.gd")
const PixelPaint = preload("res://src/vfx/pixel_paint.gd")
const PoolPaint = preload("res://src/vfx/pool_paint.gd")
const TalentBar = preload("res://src/ui/talent_bar.gd")
const SkillBar = preload("res://src/ui/skill_bar.gd")
const Profile = preload("res://src/progress/profile.gd")
const Rules = preload("res://src/progress/talent_rules.gd")
const HeroKit = preload("res://src/hell/hero_kit.gd")
const SubKit = preload("res://src/hell/sub_kit.gd")
const BossKit = preload("res://src/hell/boss_kit.gd")
## The hero's slowing conditions (src/hell/hero_fx.gd state.effects) a cleanse
## takes off: "slow" (curses, boss moves, frost pools' and gases' status).
const SLOW_CONDITIONS: Array[String] = ["slow"]
## The hero's slowing timers on g.state a cleanse ends: "chill" (the frost
## chill, theme chill_speed: chilling shots, defs and fields) and "slow" (half
## speed: hell_monsters.gd scream cones, the Archivar's Bannfluch).
const SLOW_TIMERS: Array[String] = ["chill", "slow"]
## The per-frame slows of what he stands in and breathes (hell_game.gd
## hero_medium, hero_gas: their "slow"), worked out again every frame where he
## stands: a cleanse drops them for the frame it happens in.
const SLOW_MEDIA: Array[String] = ["hero_medium", "hero_gas"]

var g: Node
## The world's element reactions for the talents' fire and frost
## (src/combat/talent_combat.gd _element asks game.elements): src/hell/story_elements.gd.
var elements: RefCounted:
	get:
		return g.get("story_elements") if g != null else null
var tc := TalentCombat.new()
var fx := TalentFx.new()
var bar := TalentBar.new()
var data: Dictionary = {}
var profile: Dictionary = {}
var profile_path := ""
var class_id := ""

# --- what talent_combat reads on its "game" -----------------------------------
var players: Dictionary = {}
var enemies: Array = []
var balance := {"player": {"radius": 14.0}, "bullet": {"radius": 4.0}}
var current_layout: Dictionary = {}
var perk_combat: Object
## Talent projectiles: {pos, velocity, owner, damage, life, talent, style, pierce, hit_ids, always_crit}.
var bullets: Array = []

var _next_mob_id := 1
var _damage_debt := 0.0
var _save_timer := 0.0
var _dirty := false


## Binds the hell game and its profile; sets the hero's build for `class_name_id`.
func bind(game: Node, profile_ref: Dictionary, path: String, class_name_id: String) -> void:
	g = game
	perk_combat = self
	profile = profile_ref
	profile_path = path
	class_id = class_name_id
	data = Profile.data()
	tc.bind(self, data)
	tc.reset(randi())
	# the talent art on this world's 3 px grid, the hero's chest 38 px over his feet, cut at its walls
	fx.set_art(3.0, Vector2(0, -38), Vector2.ZERO)
	# fire bursts in the feel's particles (crypt units)
	if g.feel != null:
		fx.particles = g.feel.feedback.particles
	# the companions' part rigs draw through the story hero's rig renderer (debris, clocks)
	if g.get("story_hero") != null and g.story_hero.get("rigs") != null:
		fx.rigs = g.story_hero.rigs
		fx.to_particles = 1.0 / g.feel.scale
	# bound to the game node, not to this object: a callable on self kept by fx would
	# hold this object (and fx) alive forever (a reference cycle)
	fx.sprites.floor_open = g._floor_open
	_sync_hero()
	if data.resources.has(class_id): tc.set_build(1, Profile.build_of(profile, class_id))


## Breaks the references that point back here (perk_combat is this object, the
## talent runtime's game is this object), so a finished run is freed with its
## effects and their textures. The game calls it when it drops this object.
func release() -> void:
	perk_combat = null
	tc.game = null


func _sync_hero() -> void:
	var hero: Dictionary = players.get(1, {})
	hero.pos = Vector2(float(g.player.x), float(g.player.y))
	hero.hp = int(g.state.get("hp", 1))
	hero.max_hp = int(g.state.get("max_hp", 1))
	hero.damage = float(g.state.get("dmg", 1.0))
	hero.aim = Vector2(g.player.get("aim", Vector2.RIGHT))
	hero.face = float(g.player.get("face", 1.0))
	hero.class_id = class_id
	players[1] = hero
	_sync_gear_mana()


## Worn gear with mana (the Seelenmantel) widens the mana pool; a new talent build
## (set_build) sets a fresh base, which is noticed because res_max moved.
func _sync_gear_mana() -> void:
	var rt := tc.runtime(1)
	if rt.is_empty() or str(rt.get("res_kind", "")) != "mana": return
	var items: Object = g.get("story_items")
	var bonus: float = items.powers.mana_bonus() if items != null and items.get("powers") != null else 0.0
	if not is_equal_approx(float(rt.res_max), float(rt.get("res_max_applied", -1.0))):
		rt.res_max_base = float(rt.res_max)
	var want := float(rt.get("res_max_base", rt.res_max)) * (1.0 + bonus)
	if not is_equal_approx(want, float(rt.res_max)):
		rt.res_max = want
		rt.res = minf(float(rt.res), want)
	rt.res_max_applied = float(rt.res_max)


func _write_hero(before: Vector2, hp_before: int) -> void:
	var hero: Dictionary = players[1]
	if Vector2(hero.pos) != before:
		g.player.x = hero.pos.x
		g.player.y = hero.pos.y
	if int(hero.hp) != hp_before: g.state.hp = clampi(int(hero.hp), 0, int(g.state.max_hp))


func _sync_mobs() -> void:
	enemies = g.mobs
	for m: Dictionary in enemies:
		# the talents key monsters by a number; a story monster's "id" is its kind
		if not m.has("tid"):
			m.tid = _next_mob_id
			_next_mob_id += 1
		if not m.has("id"):
			m.id = m.tid
		m.pos = m.p
		m.radius = float(m.get("r", 14.0))
		if not m.has("statuses"): m.statuses = {}
		if not m.has("boss"): m.boss = str(m.get("kind", "")) == "boss"


## Runs a talent action with the hero and mobs in sync before and after.
func _with_sync(action: Callable) -> void:
	_sync_hero()
	_sync_mobs()
	var before: Vector2 = players[1].pos
	var hp_before: int = players[1].hp
	action.call()
	_write_hero(before, hp_before)


## Keys 1-4 (`slot` 0-3) or the ultimate (`slot` -1). Returns true when it fired.
## The skill bar's slots: the learned talents on keys 1-4 and the ultimate on R.
func skill_slots() -> Array:
	return bar.skill_slots(hud_state())


func press(slot: int) -> bool:
	var rt := tc.runtime(1)
	if rt.is_empty() or int(g.state.get("hp", 0)) <= 0: return false
	var talent := str(rt.ultimate) if slot < 0 else (str(rt.bar[slot]) if slot < rt.bar.size() else "")
	if talent.is_empty(): return false
	var target: Vector2 = HeroKit.target(g)
	_sync_hero()
	_sync_mobs()
	var before: Vector2 = players[1].pos
	var hp_before: int = players[1].hp
	var fired := tc.cast(1, talent, {"aim": (target - Vector2(g.player.x, g.player.y)).normalized(), "target": target, "slot": maxi(0, slot)})
	_write_hero(before, hp_before)
	# the ultimate's moment: the camera punches in briefly (src/hell/story_camera.gd)
	if fired and slot < 0 and g.has_method("camera_punch"):
		g.camera_punch("ultimate")
	return fired


## The mana fountain: the hero's Mana, Ausdauer or Zorn full and every talent,
## companion and defense cooldown reset (src/combat/talent_combat.gd refill).
## False without a talent build.
func refill() -> bool:
	var done := false
	_with_sync(func(): done = tc.refill(1))
	return done


## The hero's resource name (Mana, Ausdauer, Zorn); "" without a talent build.
func resource_name() -> String:
	var rt := tc.runtime(1)
	return "" if rt.is_empty() else str(tc.data.resources[rt["class"]].name)


## Keys 5 and 6 (`slot` 0-1): the permanent companion's ability.
func press_pet(slot: int) -> void:
	_with_sync(func(): tc.pet_cast(1, slot, true))


## Right-click on a companion icon: its auto-cast on or off.
func toggle_pet(slot: int) -> void:
	tc.toggle_pet_auto(1, slot)


## The companion ability under `point` (screen px) on the companion bar
## (src/ui/hud_kit.gd pet_panel), or -1. `screen` is kept for the callers.
func pet_slot_at(_screen: Vector2, point: Vector2) -> int:
	return HudKit.pet_slot_at(point)


func update(dt: float) -> void:
	_with_sync(func():
		_hold()
		_catch_shots(dt)
		tc.step(dt)
		_step_bullets(dt)
		_step_statuses(dt))
	bar.step(dt)
	# the talents' weight on the view by importance (src/vfx/talent_fx.gd take_feel)
	for hit: Dictionary in fx.take_feel(tc.snapshot()):
		g.state.shake = maxf(float(g.state.get("shake", 0.0)), float(hit.shake_px))
		if float(hit.hitstop) > 0.0 and g.feel != null:
			g.feel.feedback.hitstop = maxf(float(g.feel.feedback.hitstop), float(hit.hitstop))
	_save_timer -= dt
	if _dirty and _save_timer <= 0.0: save()


## Held keys each frame: the drawn talent's key (its line follows the mouse)
## and Shift (dodge or block), like the crypt's input bits.
func _hold() -> void:
	var rt := tc.runtime(1)
	if rt.is_empty(): return
	var drawing: Dictionary = rt.get("drawing", {})
	var draw_held := not drawing.is_empty() and Input.is_physical_key_pressed(KEY_1 + int(drawing.get("slot", 0)))
	var move := Vector2(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)), float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
	var alive := int(g.state.get("hp", 0)) > 0
	tc.hold(1, draw_held, alive and Input.is_physical_key_pressed(KEY_SHIFT), HeroKit.target(g), move)


## The hero's talent state for the HUD (same shape as the crypt's snapshot).
func hud_state() -> Dictionary:
	var snapshot: Dictionary = tc.player_state(1)
	# the Arkanes Gefüge belongs to the void path (Leere) only; every other hero gets no orb
	if snapshot.has("gefuege") and not tc.feeds(1):
		snapshot.erase("gefuege")
	return snapshot


# --- hooks from the hell runtime -------------------------------------------------

## Hero damage before the hell's own extras: difficulty, reductions, shield,
## counter. `from`: where the blow came from (ZERO when unknown), so a shield
## dome dents on that side.
func incoming(n: int, from := Vector2.ZERO) -> int:
	var factor := float(data.get("difficulties", {}).get(str(profile.get("difficulty", "normal")), {}).get("damage", 1.0))
	var exact := float(n) * factor + _damage_debt
	n = maxi(1, floori(exact))
	_damage_debt = maxf(0.0, exact - n)
	_sync_hero()
	_sync_mobs()
	var before: Vector2 = players[1].pos
	var hp_before: int = players[1].hp
	var hero_at := Vector2(float(g.player.x), float(g.player.y))
	var taken := tc.incoming(1, n, (hero_at - from).normalized() if from != Vector2.ZERO and from != hero_at else Vector2.ZERO)
	_write_hero(before, hp_before)
	return taken


## The hero's basic hit on a mob: talent bonuses, crits, rage, lifesteal.
func basic_hit(m: Dictionary, dealt: float) -> float:
	_sync_mobs()
	var out := tc.outgoing(1, m, dealt, true)
	tc.dealt(1, m, out, true)
	return out


## Raserei on the hero's attack interval.
func interval_scale() -> float:
	return tc.interval_scale(players.get(1, {}), 1)


## A mob fell: Blutdurst, EXP and gold into the profile (its gold shown rising over it). A mob a reaction of
## the hero caught pays more EXP (src/hell/story_elements.gd exp_mul,
## assets/data/reactions_lexicon.json reward): the talents' EXP here and the
## run level's on top of what the world already gave (_reaction_bonus).
func killed(m: Dictionary) -> void:
	_sync_hero()
	tc.enemy_killed(m, 1)
	_write_hero(players[1].pos, int(g.state.hp))
	if bool(m.get("summoned", false)): return
	var kind := "boss" if str(m.get("kind", "")) == "boss" or bool(m.get("boss", false)) else "kill"
	var state := Profile.class_state(profile, class_id)
	var gold := int(data.gold.per_boss if kind == "boss" else data.gold.per_kill)
	g.add_gold(gold)
	# seen, never hidden: a small golden '+N' with a coin rises where it fell, and now and then
	# a rune stone drops there (src/hell/gold_loot.gd)
	if g.get("gold_loot") != null and m.has("p"):
		g.gold_loot.kill_popup(Vector2(m.p), gold)
		g.gold_loot.roll_rune(("final" if bool(g.W.get("final", false)) else "boss") if kind == "boss" else "mob", Vector2(m.p))
	var mul: float = float(elements.exp_mul(m)) if elements != null and elements.has_method("exp_mul") else 1.0
	var gained := Rules.add_exp(data, state, roundi(float(data.exp[kind]) * mul))
	if mul > 1.0: _reaction_bonus(m, mul)
	if gained > 0: bar.show_reward({"kind": "level", "level": int(state.level), "points": Rules.free_points(data, state)})
	_dirty = true


## The reaction reward of a kill: the run level's EXP share of `mul` (the
## world gave the plain EXP before calling killed) and "+N % EP" rising from it.
func _reaction_bonus(m: Dictionary, mul: float) -> void:
	var extra := roundi(float(HeroKit.exp_for(g, m)) * (mul - 1.0))
	if extra > 0: HeroKit.gain(g, extra)
	if elements != null and elements.has_method("exp_bonus"):
		elements.exp_bonus(Vector2(m.p) - Vector2(0, float(m.get("cy", 30.0))), roundi((mul - 1.0) * 100.0))


## Something lasting in the profile changed outside the talents (a reaction
## discovered, src/hell/story_elements.gd): written with the next save.
func note_progress() -> void:
	_dirty = true


## The hero's unspent talent points (Heldenstufe), for the HUD's talent chip.
func free_points() -> int:
	if profile.is_empty(): return 0
	return Rules.free_points(data, Profile.class_state(profile, class_id))


## Enemy HP factor of the profile's difficulty (applied when mobs spawn).
func hp_scale() -> float:
	return float(data.get("difficulties", {}).get(str(profile.get("difficulty", "normal")), {}).get("hp", 1.0))


## Where an enemy should walk: a wolf that drew it (Fass!) wins over the hero.
func chase_goal(m: Dictionary, goal: Vector2) -> Vector2:
	_sync_mobs()
	var forced := tc.forced_target(m)
	return Vector2(forced.pos) if not forced.is_empty() and int(forced.id) < 0 else goal


## The profile changed outside the talents (gold taken): saved with the next save tick.
func request_save() -> void:
	_dirty = true


func save() -> void:
	_dirty = false
	_save_timer = 3.0
	Profile.save_profile(profile, profile_path)


# --- the Arkane Gefüge in the story worlds ---------------------------------------

## The void ate something here (src/hell/story_elements.gd void_at and
## _void_swallows): into the hero's Gefüge (src/combat/talent_combat.gd feed_all).
func feed_all(owner: int, ate: Dictionary, mouth: Vector2 = Vector2.INF) -> int:
	return tc.feed_all(owner, ate, mouth)


## One swallowed thing into the Gefüge (src/combat/talent_combat.gd feed).
func feed(owner: int, el: String, n: int) -> int:
	return tc.feed(owner, el, n)


## What a swallowed thing is worth: [element, units] (talent_combat.gd swallow_value).
func swallow_value(mat: String, kind: String, radius: float) -> Array:
	return tc.swallow_value(mat, kind, radius)


## Leerenschild: an enemy shot about to reach the hero this frame while his
## shield catches is taken out of the world into his Gefüge (its element "c";
## the Frostgruft's shots their "style"). hell_game updates the talents before
## the shots, so a caught shot never hurts and leaves no residue.
func _catch_shots(dt: float) -> void:
	var rt := tc.runtime(1)
	if rt.is_empty() or int(rt.get("catch_left", 0)) <= 0 or g.get("eshots") == null: return
	var me := Vector2(float(g.player.x), float(g.player.y) - 34.0)
	var reach := float(g.balance.get("enemy_shot", {}).get("hit_radius", 26.0)) * 1.25
	var shots: Array = g.eshots
	for i in range(shots.size() - 1, -1, -1):
		var s: Dictionary = shots[i]
		if s.has("chain") or float(s.get("held", 0.0)) > 0.0 or float(s.get("t", 0.0)) <= 0.0: continue
		var at: Vector2 = s.p
		var next: Vector2 = at + Vector2(s.get("v", Vector2.ZERO)) * dt
		if Geometry2D.get_closest_point_to_segment(me, at, next).distance_to(me) > reach: continue
		if tc.catch_shot(1, str(s.get("c", s.get("style", ""))), at): shots.remove_at(i)


## A pool of the hero's from a talent (the Leerengeschoss's void stain, a
## Gefüge element landing): a friendly puddle of the monster runtime (it works
## on the monsters by the element physics and spares the hero), marked as his
## own Gefüge drop (fed_by) so his void does not eat it again. The Frostgruft
## has no monster runtime: no pool there (the landing still hurts and reacts).
func talent_pool(style: String, at: Vector2, r: float, time: float, owner: int) -> void:
	if g.get("monsters") == null: return
	g.monsters._zone({"kind": "puddle", "p": at, "r": r, "T": time, "dmg": 0, "friend": true, "st": style, "owner": owner, "fed_by": owner,
		"m": {"id": "leere", "def": {"name": "Leere"}, "boss": false}, "dir": Vector2.ZERO})


# --- what talent_combat calls on its "game" ---------------------------------------

## Sound hook of src/combat/talent_combat.gd (_sound): a talent moment to the
## story's sound router (src/hero/story_sound.gd talent).
func talent_sound(kind: String, at: Vector2, extra: Dictionary) -> void:
	if g != null and g.get("sound") != null: g.sound.talent(kind, at, extra, tc)


## Story world px per crypt px (the hell runtime draws on a 3 px art grid, the
## crypt on 2): talent_combat scales the companions' follow distance and pace by it.
func talent_world_scale() -> float:
	return float(g.PIXEL_WORLD) / 2.0


## A talent that frees the hero (talents.json "cleanse": Raumsprung, called by
## src/combat/talent_combat.gd blink): every slow on him ends now, the
## conditions (SLOW_CONDITIONS), the timers (SLOW_TIMERS) and this frame's
## pool and gas slow (SLOW_MEDIA). A pool or gas he still stands in slows him
## again from the next frame; the story worlds have no webs. `_id`: the hero
## (the only one here).
func cleanse_slows(_id: int) -> void:
	if g == null or g.state.is_empty(): return
	var effects: Variant = g.state.get("effects")
	if effects is Dictionary:
		for kind: String in SLOW_CONDITIONS: (effects as Dictionary).erase(kind)
	for key: String in SLOW_TIMERS:
		if g.state.has(key): g.state[key] = 0.0
	for field: String in SLOW_MEDIA:
		var medium: Variant = g.get(field)
		if medium is Dictionary and (medium as Dictionary).has("slow"):
			# a copy: hero_gas may be the shared rule of element_rules.json itself
			var freed: Dictionary = (medium as Dictionary).duplicate()
			freed.erase("slow")
			g.set(field, freed)


func talent_move(from: Vector2, step: Vector2, radius: float) -> Vector2:
	var pos := from
	var steps := maxi(1, ceili(step.length() / 8.0))
	var part := step / steps
	for i in range(steps):
		var next := pos + part
		if not _solid(next, radius): pos = next
		elif not _solid(Vector2(next.x, pos.y), radius): pos = Vector2(next.x, pos.y)
		elif not _solid(Vector2(pos.x, next.y), radius): pos = Vector2(pos.x, next.y)
		else: break
	return pos


func talent_blocked(from: Vector2, to: Vector2, _radius: float) -> bool:
	var steps := maxi(1, ceili(from.distance_to(to) / 12.0))
	for i in range(1, steps):
		if g.box_blocked(Rect2(from.lerp(to, float(i) / steps) - Vector2(3, 3), Vector2(6, 6))): return true
	return false


func _solid(p: Vector2, radius: float) -> bool:
	return g.box_blocked(Rect2(p.x - radius, p.y - radius * 0.6, radius * 2.0, radius * 0.6))


func _damage_enemy(m: Dictionary, damage: float, direction: Vector2 = Vector2.ZERO, owner: int = 1, _kill_effects: bool = true, feedback: bool = true) -> float:
	if damage <= 0.0 or float(m.hp) <= 0.0: return 0.0
	if g.monsters != null and g.monsters.immune(m): return 0.0
	var factor := BossKit.damage_factor(g, m) if m.has("kit") else 1.0
	if factor <= 0.0: return 0.0
	damage = tc.outgoing(owner, m, damage * factor, feedback)
	m.hp = float(m.hp) - damage
	if feedback:
		m.hit = 0.12
		if not m.has("kit"): m.k = direction * (12.0 if str(m.get("kind", "")) == "boss" else 60.0)
		# sound hook: the talent hit in the monster's material at the monster, with its voice and coat
		if g.get("sound") != null: g.sound.mob_hit(m)
		else: g._sound("hit_" + str(m.get("def", {}).get("material", "void")))
	tc.dealt(owner, m, damage, feedback)
	return damage


func _damage_player(_id: int, n: int, _direction: Vector2 = Vector2.ZERO) -> void:
	g.dot_hurt(n, "Wächtereid")


func _add_bullet(pos: Vector2, velocity: Vector2, owner: int, damage: float, meta: Dictionary = {}) -> Dictionary:
	var bullet := {"pos": pos, "velocity": velocity, "owner": owner, "damage": damage, "life": 1.6, "hit_ids": [], "pierce": 0}
	bullet.merge(meta, true)
	bullets.append(bullet)
	return bullet


## The perk status call of the crypt, mapped to the hell's own effects.
func _status(m: Dictionary, key: String, power: float, duration: float, _owner: int) -> void:
	var statuses: Dictionary = m.get("statuses", {})
	var old: Dictionary = statuses.get(key, {})
	statuses[key] = {"power": maxf(power, float(old.get("power", 0.0))), "time": maxf(duration, float(old.get("time", 0.0)))}
	m.statuses = statuses
	match key:
		# each its own damage over time (HeroKit.tick_mob), the hero's damage counted once (_story_dps)
		"burn":
			HeroKit.burn_mob(m, _story_dps(power), duration)
			# on fire for the element physics (a burning monster sets poison off; water puts it out)
			if float(m.get("wet_t", 0.0)) <= 0.0: m.fire_t = maxf(float(m.get("fire_t", 0.0)), duration)
		"poison": HeroKit.poison_mob(m, _story_dps(power), duration)
		"bleed": HeroKit.bleed_mob(m, _story_dps(power), duration)
		"freeze": SubKit.freeze(g, m, duration)
		"slow":
			if power >= 1.0: SubKit.freeze(g, m, duration, true)
			else: HeroKit.slow_mob(g, m, power, duration)


## A talent's damage over time in the story's unit. talent_combat.gd hands an
## absolute dps (the hero's damage x the status pct of talents.json
## "statuses", plus its bonuses); the story's monster ticks (HeroKit.tick_mob)
## count in hero hits per second and multiply by state.dmg themselves. So the
## dps is divided by state.dmg here, and the hero's damage counts once.
func _story_dps(power: float) -> float:
	var hit := float(g.state.get("dmg", 1.0))
	return power / hit if hit > 0.0 else 0.0


func _step_statuses(dt: float) -> void:
	for m: Dictionary in enemies:
		var statuses: Dictionary = m.get("statuses", {})
		for key: String in statuses.keys():
			statuses[key].time = float(statuses[key].time) - dt
			if float(statuses[key].time) <= 0.0: statuses.erase(key)


func _step_bullets(dt: float) -> void:
	for i in range(bullets.size() - 1, -1, -1):
		var b: Dictionary = bullets[i]
		var from: Vector2 = b.pos
		b.pos = from + Vector2(b.velocity) * dt
		b.life = float(b.life) - dt
		# a fire shot through poison gas sets it off (src/hell/story_elements.gd)
		if elements != null and str(b.get("style", "")).begins_with("fire"):
			elements.fire_passes(b.pos, int(b.get("owner", 1)))
		var gone: bool = float(b.life) <= 0.0 or talent_blocked(from, b.pos, 3.0)
		if not gone:
			for m: Dictionary in enemies:
				if float(m.hp) <= 0.0 or b.hit_ids.has(int(m.id)) or not g._hittable(m): continue
				if Geometry2D.get_closest_point_to_segment(m.p, from, b.pos).distance_to(m.p) > float(m.radius) + 10.0: continue
				b.hit_ids.append(int(m.id))
				tc.bullet_hit(b, m)
				if int(b.pierce) <= 0:
					gone = true
					break
				b.pierce = int(b.pierce) - 1
		if gone: bullets.remove_at(i)


# --- drawing ------------------------------------------------------------------------

## True on walkable floor at world point `p`: where pools and pixels may show.
func _open_floor(p: Vector2) -> bool:
	return g._walkable(g._cell(int(floor(p.x / float(g.C))), int(floor(p.y / float(g.C)))))


## World layer (under the actors): zones, traps, wolves and projectiles.
func draw_world(canvas: CanvasItem, clock: float) -> void:
	var snap := tc.snapshot()
	# world px here: the world's 3 px art pixel; pools and pixels stop at the walls
	if fx.pools == null:
		if g.get("pools") != null:
			# the Hell's puddle layer: the same liquid is one pool; its ground layer draws it
			fx.pools = g.pools
			fx.draw_pools = false
		else:
			fx.pools = PoolPaint.new(3.0, g._floor_open)
			if g.feel != null:
				fx.pools.particles = g.feel.feedback.particles
				fx.pools.to_particles = 1.0 / g.feel.scale
	if fx.gas == null and g.get("gas") != null:
		fx.gas = g.gas
	PixelPaint.clip = _open_floor
	fx.draw_ground(canvas, snap, clock)
	# without the Hell's puddle layer the pools are drawn here: the gas lies over them
	if fx.draw_pools and fx.gas != null:
		fx.gas.draw(canvas, clock)
	fx.draw_pets(canvas, snap, clock)
	for b: Dictionary in bullets:
		var at := Vector2(b.pos) - Vector2(0, 30)
		var colour: Color = {"fireball": Color("ff7a2a"), "frost_lance": Color("8fd8e6"), "arcane": Color("b07bff")}.get(str(b.get("style", "")), Color("f3e2b0"))
		var shot := {"x": at.x, "y": at.y, "vx": Vector2(b.velocity).x, "vy": Vector2(b.velocity).y, "style": str(b.get("style", "")),
			"talent": str(b.get("talent", "")), "stage": int(b.get("stage", 0))}
		if fx.draw_bullet(canvas, shot, clock): continue
		if str(b.get("style", "")) == "arrow":
			# a shaft of pixels with a white tip and a dark outline
			var along := Vector2(b.velocity).normalized()
			for i in range(7):
				var q := PixelPaint.at(at + along * (8.0 - float(i) * 3.0), 3.0)
				PixelPaint.cell(canvas, q + Vector2i(0, 1), Color("1a1414"), 3.0)
				PixelPaint.cell(canvas, q, Color.WHITE if i == 0 else colour, 3.0)
		else:
			PixelPaint.ball(canvas, at, 2, [colour.lightened(0.5), colour.lightened(0.3), colour, colour.darkened(0.3)], Color("1a1414"), 3.0)
	# the mage's left-click fireballs (hell_game shots of kind "pyro")
	for s: Dictionary in g.shots:
		if str(s.get("kind", "")) == "pyro": fx.draw_basic_fireball(canvas, Vector2(s.p), Vector2(s.v), clock)
	PixelPaint.clip = Callable()


## Over the actors: the talent events and what lasts on the hero (shields,
## rage, the ultimates' auras), stopping at the walls.
func draw_over(canvas: CanvasItem, clock: float) -> void:
	var snap := tc.snapshot()
	PixelPaint.clip = _open_floor
	fx.draw_events(canvas, snap, clock)
	fx.draw_auras(canvas, snap, clock, _hero_at)
	PixelPaint.clip = Callable()


## Bloom of the talents on the additive glow layer.
func draw_glow(canvas: CanvasItem, clock: float) -> void:
	fx.draw_glow(canvas, tc.snapshot(), 1.0, clock, _hero_at)


## The hero's ground point (the only hero here).
func _hero_at(_owner: int) -> Vector2:
	return Vector2(float(g.player.x), float(g.player.y))


## HUD: the talent bar above the skill bar and the reward banner.
func draw_hud(canvas: CanvasItem, screen: Vector2, bar_top: float) -> void:
	bar.draw_resource(canvas, hud_state(), screen.x * 0.5, bar_top)
	bar.draw_reward(canvas, Vector2(screen.x * 0.5, screen.y * 0.24))
