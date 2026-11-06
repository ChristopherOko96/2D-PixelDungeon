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
const MarksmanSprites = preload("res://src/vfx/marksman_sprites.gd")
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
var _talent_queries_ready := false
var _talent_queries_full := false
var _render_frame := -1
var _render_clock := -INF
var _render_snapshot: Dictionary = {}


func _invalidate_render_state() -> void:
	_render_frame = -1
	_render_snapshot = {}


# Read-only presentation state shared by ground, actors and additive bloom.
# Gameplay feedback still takes its own snapshot on every simulation step.
func _render_state(clock: float) -> Dictionary:
	var frame := Engine.get_process_frames()
	if frame != _render_frame or clock != _render_clock:
		_render_snapshot = tc.snapshot()
		_render_frame = frame
		_render_clock = clock
	return _render_snapshot


## Binds the hell game and its profile; sets the hero's build for `class_name_id`.
func bind(game: Node, profile_ref: Dictionary, path: String, class_name_id: String) -> void:
	_invalidate_render_state()
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
		fx.necro_staff = Callable(g.story_hero.look,"staff_socket")
		fx.marksman_socket = Callable(g.story_hero.look,"bow_socket")
		fx.marksman_socket_key = "hero"
		fx.necro_staff_key = "hero"
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
	_invalidate_render_state()
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
	_talent_queries_ready = false
	enemies = g.mobs
	for m: Dictionary in enemies:
		_sync_mob(m)


func _sync_mob(m: Dictionary) -> void:
	# Individual target/hit queries must not resynchronise every other body.
	if not m.has("tid"):
		m.tid = _next_mob_id
		_next_mob_id += 1
	if not m.has("id"): m.id = m.tid
	m.pos = m.p
	m.radius = float(m.get("r",14.0))
	if not m.has("statuses"): m.statuses = {}
	if not m.has("boss"): m.boss = str(m.get("kind",""))=="boss"


## Runs a talent action with the hero and mobs in sync before and after.
func _with_sync(action: Callable) -> void:
	_invalidate_render_state()
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


## The last talent shot's id (each flying shot sheds its matter by it: talent_fx _shed_flight).
var _bullet_serial := 0
## The mage's projectile talents stop and burst where the mouse pointed (talent_combat.gd
## _land_reach reads it; _step_bullets counts their `left` down and lands them).
var shots_land := true
## Talent events already put to the walls and props (id -> true; _wreck_blasts).
var _wrecked := {}


func update(dt: float) -> void:
	_invalidate_render_state()
	_with_sync(func():
		_hold()
		_catch_shots(dt)
		tc.step(dt)
		_step_bullets(dt)
		_step_statuses(dt))
	_wreck_blasts()
	# the talents' zones lying as pools of their own (the Seuchenfeld's plague) on the game clock in
	# the world's pool layer: the rules' truth of where they reach (physics plan R14, decision D1)
	var layer: RefCounted = g._pool_layer() if g.has_method("_pool_layer") else null
	if layer != null: layer.sync(tc.ground_pools(), float(g.state.t), "talent_ground")
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
	if rt.has("soul_charge"):
		var charge_key: int=KEY_R if int(rt.soul_charge.get("bit",0))==tc.ULT_BIT else KEY_1+int(rt.soul_charge.slot)
		var charge_held := Input.is_physical_key_pressed(charge_key)
		var charge_aim := (HeroKit.target(g) - Vector2(g.player.x, g.player.y)).normalized()
		TalentCombat.SoulCharge.hold(tc, 1, charge_held, charge_aim)
	var drawing: Dictionary = rt.get("drawing", {})
	var draw_held := not drawing.is_empty() and Input.is_physical_key_pressed(KEY_1 + int(drawing.get("slot", 0)))
	var move := Vector2(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)), float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
	var alive := int(g.state.get("hp", 0)) > 0
	tc.hold(1, draw_held, alive and Input.is_physical_key_pressed(KEY_SHIFT), HeroKit.target(g), move)


## While the HUD draws (hud_begin .. hud_end) its talent state is worked out once and read by
## the skill bar, the resource line and the companion panel (they only read it).
var _hud_open := false
var _hud_state: Dictionary = {}


## The HUD starts drawing (hell_game.gd draw_hud): hud_state() is worked out anew once.
func hud_begin() -> void:
	_hud_open = true
	_hud_state = {}


## The HUD has drawn: hud_state() is worked out on every call again.
func hud_end() -> void:
	_hud_open = false
	_hud_state = {}


## The hero's talent state for the HUD (same shape as the crypt's snapshot); within one HUD
## drawing the same dictionary (read only).
func hud_state() -> Dictionary:
	var drawing := _hud_open
	if drawing and not _hud_state.is_empty():
		return _hud_state
	var snapshot: Dictionary = tc.player_state(1)
	# the Arkanes Gefüge belongs to the void path (Leere) only; every other hero gets no orb
	if snapshot.has("gefuege") and not tc.feeds(1):
		snapshot.erase("gefuege")
	if drawing:
		_hud_state = snapshot
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
	_sync_hero()
	enemies = g.mobs
	_sync_mob(m)
	var hp_before := int(players[1].hp)
	var out := tc.outgoing(1, m, dealt, true)
	tc.dealt(1, m, out, true, minf(float(m.hp), out))
	_write_hero(Vector2(g.player.x, g.player.y), hp_before)
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
	m.pos = Vector2(m.get("pos", m.get("p", Vector2.ZERO)))
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
	_sync_mob(m)
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
	if g.story_elements == null: return
	g.story_elements.add_pool({"kind": "puddle", "p": at, "r": r, "T": time, "dmg": 0, "friend": true, "st": style, "owner": owner, "fed_by": owner,
		"m": {"id": "leere", "def": {"name": "Leere"}, "boss": false}, "dir": Vector2.ZERO})


## Authoritative media references shared with the necromancer's finite absorption.
func talent_media() -> Array:
	return g.story_elements.media() if g.story_elements != null else []

## Reuse the story world's authoritative drawn-liquid footprint for alchemy ticks.
func talent_stands_in(pool: Dictionary, enemy: Dictionary) -> bool:
	return g.story_elements != null and g.story_elements._stands_in(pool,enemy)


## The real zone expires; the ordinary pool renderer observes that expiration.
func talent_consume_pool(zone: Dictionary) -> void:
	zone.t = float(zone.T)


# --- what talent_combat calls on its "game" ---------------------------------------

## Sound hook of src/combat/talent_combat.gd (_sound): a talent moment to the
## story's sound router (src/hero/story_sound.gd talent).
func talent_sound(kind: String, at: Vector2, extra: Dictionary) -> void:
	if g != null and g.get("sound") != null: g.sound.talent(kind, at, extra, tc)


## Whether talent zone `id` lying as a pool of its own (src/combat/talent_combat.gd _zone_reach)
## covers a body of `radius` standing at `at` (its middle and four points round it): 1 yes, 0 no,
## -1 not known (no pool layer yet, or its pool is still being shaped).
func talent_ground_covers(id: int, at: Vector2, radius: float) -> int:
	var layer: RefCounted = g._pool_layer() if g.has_method("_pool_layer") else null
	if layer == null or not layer.has_method("pool_covers"): return -1
	var key := "talent_ground:%d" % id
	if not layer.has_pool(key): return -1
	var reach := radius * 0.6
	for off: Vector2 in [Vector2.ZERO, Vector2(reach, 0.0), Vector2(-reach, 0.0), Vector2(0.0, reach * 0.6), Vector2(0.0, -reach * 0.6)]:
		if layer.pool_covers(key, at + off): return 1
	return 0


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


## Include both endpoints and the full shot/actor radius, even on short steps.
func talent_blocked(from: Vector2, to: Vector2, radius: float) -> bool:
	var steps := maxi(1, ceili(from.distance_to(to) / 4.0))
	for i in range(steps + 1):
		if g.box_blocked(Rect2(from.lerp(to, float(i) / steps) - Vector2.ONE * radius, Vector2.ONE * radius * 2.0)): return true
	return false

## Bounded local navigation around story cover, cached by CompanionTargets.
func talent_path(from: Vector2, to: Vector2, radius: float) -> PackedVector2Array:
	var low := Vector2i((from.min(to) / 32.0).floor()) - Vector2i(5, 5)
	var high := Vector2i((from.max(to) / 32.0).floor()) + Vector2i(5, 5)
	if high.x - low.x > 100 or high.y - low.y > 100: return PackedVector2Array()
	var grid := AStarGrid2D.new()
	grid.region = Rect2i(low, high - low + Vector2i.ONE)
	grid.cell_size = Vector2(32, 32)
	grid.offset = Vector2(16, 16)
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	for y in range(low.y, high.y + 1):
		for x in range(low.x, high.x + 1):
			var point := (Vector2(x, y) + Vector2.ONE * 0.5) * 32.0
			grid.set_point_solid(Vector2i(x, y), talent_blocked(point, point, radius))
	var result := grid.get_point_path(Vector2i((from / 32.0).floor()), Vector2i((to / 32.0).floor()))
	if result.is_empty(): return result
	result.remove_at(0)
	result.append(to)
	return result

## Preserve story spawn/invulnerability rules during shared soul collision.
func talent_hittable(enemy: Dictionary) -> bool:
	return g._hittable(enemy)


## Where a talent shot flying from `from` to `to` first meets a wall (physics plan R1/F23,
## docs/PHYSIK-PLAN.md): samples every 6 px or less up to and with the end point (talent_blocked
## leaves the end out, so at 60 fps a shot never met a wall and flew on through it), then halves
## the last free stretch six times to the contact. Vector2.INF when nothing is in the way.
func _shot_contact(from: Vector2, to: Vector2) -> Vector2:
	var steps := maxi(1, ceili(from.distance_to(to) / 6.0))
	var free := from
	for i in range(1, steps + 1):
		var at := from.lerp(to, float(i) / float(steps))
		if _shot_wall(at):
			var hit := at
			for k in range(6):
				var mid := (free + hit) * 0.5
				if _shot_wall(mid): hit = mid
				else: free = mid
			return free
		free = at
	return Vector2.INF


## Talent explosions, novas and impacts bite the walls and break props, crates and urns the way
## the hero's own blasts do (story_wreck.gd blast; physics plan R5/F47), each event once; the pyro
## shot's explosions are skipped ("wrecked": hell_game blasted there already).
func _wreck_blasts() -> void:
	if g.get("wreck") == null: return
	var now := {}
	for event: Dictionary in tc.events:
		var id := int(event.get("id", 0))
		now[id] = true
		if _wrecked.has(id): continue
		if not str(event.get("kind", "")) in ["explosion", "nova", "impact"] or bool(event.get("wrecked", false)): continue
		var r := float(event.get("r", 0.0))
		if r < 24.0: continue
		g.wreck.blast(Vector2(float(event.x), float(event.y)), r, "blast", int(event.get("owner", 1)) > 0)
	_wrecked = now


func _shot_wall(p: Vector2) -> bool:
	return g.box_blocked(Rect2(p - Vector2(3, 3), Vector2(6, 6)))


## A talent's melee blow (talent_combat.gd "melee") meeting a wall or a prop in front: it clangs and
## chips there like the hero's own swing (story_feel.swing_wall) and breaks a smashable prop in its
## arc (story_wreck.swing; physics plan R3).
func talent_swing_wall(from: Vector2, aim: Vector2, reach: float, half: float) -> void:
	var at := from - Vector2(0, 40)
	if g.feel != null: g.feel.swing_wall(at, aim, reach)
	if g.get("wreck") != null: g.wreck.swing(at, aim, reach, half)


## The wall-wear style of a talent shot (story_wreck.gd wall_hit).
static func _wall_style(style: String) -> String:
	if style.begins_with("fire") or style.begins_with("inferno"): return "fire"
	if style.begins_with("frost"): return "frost"
	if style == "arcane": return "void"
	if style == "arrow": return "arrow"
	return "metal"


func _solid(p: Vector2, radius: float) -> bool:
	return g.box_blocked(Rect2(p.x - radius, p.y - radius * 0.6, radius * 2.0, radius * 0.6))


func _damage_enemy(m: Dictionary, damage: float, direction: Vector2 = Vector2.ZERO, owner: int = 1, _kill_effects: bool = true, feedback: bool = true) -> float:
	if damage <= 0.0 or float(m.hp) <= 0.0: return 0.0
	if g.monsters != null and g.monsters.immune(m): return 0.0
	var factor := BossKit.damage_factor(g, m) if m.has("kit") else 1.0
	if factor <= 0.0: return 0.0
	damage = tc.outgoing(owner, m, damage * factor, feedback)
	var resolved_hp := minf(float(m.hp), damage)
	m.hp = float(m.hp) - damage
	if feedback:
		m.hit = 0.12
		# the talent's push adds to what already pushes it, away from the blast that struck, less on
		# a heavier body, summed at most push.max (physics plan R23, decision D5)
		if not m.has("kit"):
			var pcfg: Dictionary = (g.motion_kit().cfg.get("push", {}) as Dictionary) if g.has_method("motion_kit") else {}
			var heavy: Array = pcfg.get("mass", [0.4, 4.0])
			var mass := float(g.body_mass(m)) if g.has_method("body_mass") else clampf(pow(float(m.get("r", 28.0)) / maxf(1.0, float(pcfg.get("mass_ref_r", 28.0))), 2.0), float(heavy[0]), float(heavy[1]))
			var push := float(pcfg.get("boss_talent", 12.0)) if str(m.get("kind", "")) == "boss" else float(pcfg.get("talent", 60.0))
			var now: Vector2 = m.get("k") if m.get("k") is Vector2 else Vector2.ZERO
			m.k = (now + direction.normalized() * push / mass).limit_length(float(pcfg.get("max", 1000.0)))
		# the creature's own matter flies from the talent hit (blood, chips, slime; physics plan
		# F25); the feel plays its material's hit sound itself
		if g.feel != null: g.feel.on_hit(m, direction, false)
		# sound hook: the talent hit in the monster's material at the monster, with its voice and coat
		elif g.get("sound") != null: g.sound.mob_hit(m)
		else: g._sound("hit_" + str(m.get("def", {}).get("material", "void")))
	tc.dealt(owner, m, damage, feedback, resolved_hp)
	return damage


func _damage_player(_id: int, n: int, _direction: Vector2 = Vector2.ZERO) -> void:
	g.dot_hurt(n, "Wächtereid")


func _add_bullet(pos: Vector2, velocity: Vector2, owner: int, damage: float, meta: Dictionary = {}) -> Dictionary:
	_bullet_serial += 1
	var bullet := {"pos": pos, "velocity": velocity, "owner": owner, "damage": damage, "life": 1.6, "hit_ids": [], "pierce": 0, "id": _bullet_serial}
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
		"soul_bind":
			m.stun = maxf(float(m.get("stun", 0.0)), duration)
			if m.has("act"): m.act = null
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
	if bullets.is_empty(): return
	g.prepare_mob_queries()
	for i in range(bullets.size() - 1, -1, -1):
		var b: Dictionary = bullets[i]
		if TalentCombat.SoulProjectiles.owns(b):
			if TalentCombat.SoulProjectiles.step(tc, b, dt): bullets.remove_at(i)
			continue
		var from: Vector2 = b.pos
		b.pos = from + Vector2(b.velocity) * dt
		b.life = float(b.life) - dt
		# a mage's spell stops at the point the mouse showed (talent_combat _land_reach); if
		# neither a wall nor an enemy stops it on the way there, it bursts on the floor
		var landed := false
		if b.has("left"):
			b.left = float(b.left) - Vector2(b.velocity).length() * dt
			if float(b.left) <= 0.0 or float(b.life) <= 0.0:
				b.pos = b.land
				landed = true
		# a fire shot through poison gas sets it off (src/hell/story_elements.gd)
		if elements != null and str(b.get("style", "")).begins_with("fire"):
			elements.fire_passes(b.pos, int(b.get("owner", 1)))
		# it stops at the wall it meets, there (R1): the burst and the wear are on the wall face
		var contact := _shot_contact(from, b.pos)
		var walled := contact != Vector2.INF
		if walled: b.pos = contact
		var gone: bool = (float(b.life) <= 0.0 and not landed) or walled
		if not gone:
			if str(b.get("style","")) == "arrow": tc.alchemist.arrow(tc,int(b.get("owner",1)),from,b.pos)
			for m: Dictionary in talent_candidates(from,b.pos,10.0):
				if float(m.hp) <= 0.0 or b.hit_ids.has(tc._eid(m)) or not g._hittable(m): continue
				if Geometry2D.get_closest_point_to_segment(m.p, from, b.pos).distance_to(m.p) > float(m.radius) + 10.0: continue
				b.hit_ids.append(tc._eid(m))
				tc.bullet_hit(b, m)
				if int(b.pierce) <= 0:
					gone = true
					break
				b.pierce = int(b.pierce) - 1
		if landed and not gone:
			tc.bullet_land(b)
			gone = true
		if walled and g.get("wreck") != null:
			g.wreck.hit_line(from, contact + Vector2(b.velocity).normalized() * 16.0, _wall_style(str(b.get("style", ""))), int(b.get("owner", 1)))
		# a fire shot that strikes an unlit fire bowl lights it (decision D7)
		if walled and _wall_style(str(b.get("style", ""))) == "fire" and g.has_method("fire_hits_brazier"):
			g.fire_hits_brazier(contact + Vector2(b.velocity).normalized() * 8.0)
		if gone: bullets.remove_at(i)


## The shared projectile solver can use the story world's ordered broad phase.
func talent_candidates(from: Vector2, to: Vector2, padding: float) -> Array:
	return g.mob_segment_candidates(from,to,padding)


## Ordered nearby bodies for circular talent queries; exact ranges stay in combat.
func talent_near(point: Vector2, radius: float) -> Array:
	# No extra phase rebuild when no bounded talent query is needed.
	if not _talent_queries_ready:
		_talent_queries_full = g.mob_queries_dense()
		if not _talent_queries_full:
			g.prepare_mob_queries()
			_talent_queries_full = g.mob_queries_dense()
		_talent_queries_ready = true
	if _talent_queries_full: return enemies
	return g.mob_candidates(point, radius, true)


## Combat shoves immediately update spatial membership as well as both aliases.
func talent_moved(enemy: Dictionary) -> void:
	g.mob_moved(enemy)


# --- drawing ------------------------------------------------------------------------

## True on walkable floor at world point `p`: where pools and pixels may show.
func _open_floor(p: Vector2) -> bool:
	return g._walkable(g._cell(int(floor(p.x / float(g.C))), int(floor(p.y / float(g.C)))))


## World layer (under the actors): zones, traps, wolves and projectiles.
func draw_world(canvas: CanvasItem, clock: float) -> void:
	var snap := _render_state(clock)
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
				g.feel.feedback.particles.add_liquid(fx.pools,g.feel.scale)
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
			"talent": str(b.get("talent", "")), "stage": int(b.get("stage", 0)), "charge": float(b.get("charge", 0.0)), "radius": float(b.get("radius", 6.0)), "id": int(b.get("id", 0))}
		if fx.draw_bullet(canvas, shot, clock): continue
		if str(b.get("style", "")) == "arrow":
			if MarksmanSprites.arrow(canvas,str(b.get("talent","")),at,Vector2(b.velocity).normalized(),3.0,fx.sprites,Vector2(b.pos)): continue
			# a shaft of pixels with a white tip and a dark outline
			var along := Vector2(b.velocity).normalized()
			for i in range(7):
				var q := PixelPaint.at(at + along * (8.0 - float(i) * 3.0), 3.0)
				PixelPaint.cell(canvas, q + Vector2i(0, 1), Color("1a1414"), 3.0)
				PixelPaint.cell(canvas, q, Color.WHITE if i == 0 else colour, 3.0)
		else:
			PixelPaint.ball(canvas, at, 2, [colour.lightened(0.5), colour.lightened(0.3), colour, colour.darkened(0.3)], Color("1a1414"), 3.0)
	PixelPaint.clip = Callable()


## Over the actors: the talent events and what lasts on the hero (shields,
## rage, the ultimates' auras), stopping at the walls.
func draw_over(canvas: CanvasItem, clock: float) -> void:
	var snap := _render_state(clock)
	var actors: Array = []
	for m: Dictionary in g.mobs:
		actors.append({"id":int(m.get("tid",-1)),"x":Vector2(m.p).x,"y":Vector2(m.p).y-float(m.get("cy",14))*0.65,"rig":str(m.get("rig",""))})
	fx.set_necro_actors({1:{"x":g.player.x,"y":g.player.y}},actors)
	PixelPaint.clip = _open_floor
	fx.draw_events(canvas, snap, clock)
	fx.draw_auras(canvas, snap, clock, _hero_at)
	PixelPaint.clip = Callable()


## Bloom of the talents on the additive glow layer.
func draw_glow(canvas: CanvasItem, clock: float) -> void:
	fx.draw_glow(canvas, _render_state(clock), 1.0, clock, _hero_at)


## The hero's ground point (the only hero here).
func _hero_at(_owner: int) -> Vector2:
	return Vector2(float(g.player.x), float(g.player.y))


## HUD: the talent bar above the skill bar and the reward banner.
func draw_hud(canvas: CanvasItem, screen: Vector2, bar_top: float) -> void:
	bar.draw_resource(canvas, hud_state(), screen.x * 0.5, bar_top, 236.0, g.get_viewport().get_mouse_position(), screen)
	bar.draw_reward(canvas, Vector2(screen.x * 0.5, screen.y * 0.24))
