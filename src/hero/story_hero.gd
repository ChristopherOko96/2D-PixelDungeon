extends RefCounted
## The crypt's polished heroes in the story worlds (src/hell/hell_game.gd:
## Hell-Dungeon and Frostgruft). Shares the crypt's look and feel:
## - the hero and its weapon through hero_look.gd (lean into swings, crescent,
##   Rage's two blades and crossed second swing, whirl, dash afterimages, bow
##   draw, staff recoil), at the story worlds' pixel size;
## - arrows and spells through attack_fx.gd (light streaks, glowing orbs, release
##   and impact flashes, bloom), drawn on a layer scaled to that pixel size;
## - the swordsman's feel (hero_skills.json "sword_feel"): a step into each
##   swing, Rage's second swing back the other way, bodies thrown by Rage that
##   slam into walls.
## - the skills' effects through story_skill_fx.gd (the crypt's skill_fx.gd:
##   whirl dust, blade wave, fireball, chain lightning, blink, Photoneneis,
##   caltrops, Rage, with pixel particles, floor marks and bloom).
## - the hero's body through the crypt's part rigs (assets/data/rigs.json knight,
##   elf, wizard via src/rig/rig_renderer.gd draw_hero): bob, walk, plume and hat
##   sway, hit recoil, death, at the story worlds' pixel size.
## The world keeps its own rules, skills, subclasses and relics.

const HeroLook = preload("res://src/hero/hero_look.gd")
const AttackFx = preload("res://src/vfx/attack_fx.gd")
const PixelPaint = preload("res://src/vfx/pixel_paint.gd")
const FxSprites = preload("res://src/vfx/fx_sprites.gd")
const StorySkillFx = preload("res://src/hero/story_skill_fx.gd")
const ClassPerks = preload("res://src/player/class_perks.gd")
const RigLibrary = preload("res://src/rig/rig_library.gd")
const RigRenderer = preload("res://src/rig/rig_renderer.gd")
## The crypt's class figures (src/dungeon_view.gd CLASS_RIGS).
const CLASS_RIGS := {"swordsman": "knight", "archer": "elf", "mage": "wizard"}
const KEY := "hero"
## Shots whose look comes from attack_fx (the hero's arrows and spells).
const SHOT_STYLES := {"arrow": "arrow", "magic": "magic"}

## Story world pixels per crypt pixel (hero_scale 3 over the crypt's 2).
var scale := 1.5
var look: HeroLook
var attack := AttackFx.new()
var swings := 0
var swing_dir := 1
var shots := 0
var feel: Dictionary = {}
var g: Node
var _queue: Array = []
var _next_id := 1
var _snapshot: Dictionary = {"bullets": [], "players": {}}
var _shot_layer: Node2D
var _glow_layer: Node2D
var _ground_layer: Node2D
## The skills' effects (crypt look).
var skill_fx: StorySkillFx
## The hero's part rig (the crypt's class figure); null when the rigs are missing.
var rigs: RigRenderer
## Hits taken, for the rig's hit recoil (counted on each new invulnerability).
var hurts := 0
var _last_inv := 0.0


class ShotLayer extends Node2D:
	var owner_kit: RefCounted
	var glow := false
	var ground := false
	func _draw() -> void:
		if ground: owner_kit.skill_fx.draw_ground(self)
		else: owner_kit.draw_layer(self, glow)


## `game` is the story world; its weapon and arrow textures become the look's.
func _init(game: Node) -> void:
	g = game
	scale = float(g.theme.get("hero_scale", 3.0)) / 2.0
	# weapons at the world's weapon size (the Frostgruft draws them smaller than the hero)
	look = HeroLook.new(float(g.theme.get("weapon_scale", g.theme.get("hero_scale", 3.0))), g.weapon_tex, g.arrow_tex)
	# the staff is sized by the body; the story hero's anchor is its chest
	look.hero_px = float(g.theme.get("hero_scale", 3.0))
	look.staff_hand = Vector2(5, 0)
	feel = ClassPerks.data().get("sword_feel", {})
	skill_fx = StorySkillFx.new(g, scale)
	rigs = RigRenderer.new(RigLibrary.shared())
	if not rigs.is_ready(): rigs = null
	attack.fx = skill_fx.fx
	attack.particles = skill_fx.particles
	_ground_layer = ShotLayer.new()
	_ground_layer.owner_kit = self
	_ground_layer.ground = true
	_ground_layer.scale = Vector2(scale, scale)
	_ground_layer.z_index = 5
	g.add_child(_ground_layer)
	_shot_layer = ShotLayer.new()
	_shot_layer.owner_kit = self
	_shot_layer.scale = Vector2(scale, scale)
	_shot_layer.z_index = 12
	g.add_child(_shot_layer)
	_glow_layer = ShotLayer.new()
	_glow_layer.owner_kit = self
	_glow_layer.glow = true
	_glow_layer.scale = Vector2(scale, scale)
	_glow_layer.z_index = 11
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow_layer.material = add
	g.add_child(_glow_layer)


## Frees the hero's drawing layers (the world builds a new kit after a graphics switch).
func dispose() -> void:
	for node: Node in [_shot_layer, _glow_layer, _ground_layer, skill_fx.glow]:
		if is_instance_valid(node):
			node.queue_free()


# --- rules --------------------------------------------------------------------------

func rage_on() -> bool:
	return float(g.state.get("rage", 0.0)) > 0.0


## A sword swing starts: count it for the look, step into it, and in Rage queue
## the second swing coming back the other way.
func on_swing(dir: Vector2, mirrored: bool) -> void:
	swings += 1
	swing_dir = -1 if mirrored else 1
	var step := float(feel.get("rage_lunge" if rage_on() else "lunge", 8.0)) * scale
	var to := Vector2(g.player.x, g.player.y) + dir * step
	if not g.box_blocked(g._player_box(to.x, g.player.y)): g.player.x = to.x
	if not g.box_blocked(g._player_box(g.player.x, to.y)): g.player.y = to.y
	if rage_on() and not mirrored:
		_queue.append({"t": float(feel.get("rage_second_delay", 0.12)), "dir": dir})


## The hero shot (arrow or spell): counted for the bow's draw and the staff's recoil.
func on_shot() -> void:
	shots += 1


## A Rage swing hit `m`: a small enemy is thrown hard and slams into a wall it meets.
func rage_throw(m: Dictionary, dir: Vector2) -> void:
	if not rage_on() or m.has("kit") or str(m.get("kind", "")) == "boss" or bool(m.get("boss", false)) or float(m.hp) <= 0.0: return
	m.k = dir * float(feel.get("rage_push", 520.0)) * scale * 1.2
	m.slam = float(feel.get("slam_window", 0.45))


## After a monster moved: a thrown body that a wall stopped takes slam damage, is
## stunned and the floor shakes there.
func check_slam(m: Dictionary, before: Vector2, dt: float) -> void:
	if not m.has("slam"): return
	m.slam = float(m.slam) - dt
	var push: Vector2 = m.k / 0.86
	if float(m.slam) <= 0.0 or float(m.hp) <= 0.0:
		m.erase("slam")
		return
	if push.length() < float(feel.get("slam_speed", 220.0)) * scale: return
	if (m.p as Vector2).distance_to(before) >= push.length() * dt * 0.5: return
	m.erase("slam")
	g._damage_mob(m, Vector2.ZERO, float(feel.get("slam_damage", 0.8)))
	m.stun = maxf(float(m.get("stun", 0.0)), float(feel.get("slam_stun", 0.6)))
	m.k = Vector2.ZERO
	g.fx.append({"kind": "quake", "p": m.p, "r": 48.0, "t": 0.3, "max": 0.3})
	g._sound_raw("attack_slam")


## True on walkable floor at crypt point `p` (this layer's units): where the
## shots' pixels may show.
func open_floor(p: Vector2) -> bool:
	var w := p * scale
	return g._walkable(g._cell(int(floor(w.x / float(g.C))), int(floor(w.y / float(g.C)))))


## Per frame: Rage's queued second swings, the shots' paths for attack_fx.
func update(dt: float) -> void:
	# the rig's clock, and a hit recoil on every new hit (invulnerability starts again)
	if rigs != null:
		rigs.step(dt)
		rigs.footfalls.clear()
	var inv := float(g.state.get("inv", 0.0))
	if inv > _last_inv + 0.05: hurts += 1
	_last_inv = inv
	for q: Dictionary in _queue:
		q.t = float(q.t) - dt
	var due := _queue.filter(func(q: Dictionary) -> bool: return float(q.t) <= 0.0)
	_queue = _queue.filter(func(q: Dictionary) -> bool: return float(q.t) > 0.0)
	for q: Dictionary in due:
		if rage_on(): g._swing(Vector2(q.dir), true)
	var bullets: Array = []
	for s: Dictionary in g.shots:
		if not SHOT_STYLES.has(str(s.get("kind", ""))): continue
		if not s.has("look_id"):
			s.look_id = _next_id
			_next_id += 1
		var v: Vector2 = s.v
		bullets.append({"id": int(s.look_id), "x": (s.p as Vector2).x / scale, "y": (s.p as Vector2).y / scale, "vx": v.x, "vy": v.y, "owner": 1,
			"style": SHOT_STYLES[str(s.kind)], "critical": float(s.get("big", 1.0)) > 1.5})
	_snapshot = {"bullets": bullets, "players": {1: {"glow": str(g.state.get("glow", ""))}}}
	attack.observe(_snapshot, float(g.state.t))
	skill_fx.update(dt, float(g.state.t))
	_shot_layer.queue_redraw()
	_glow_layer.queue_redraw()
	_ground_layer.queue_redraw()


## True for the shots drawn here (the world skips its own drawing for them):
## arrows and spells (attack_fx), skill shots (story_skill_fx).
func handles_shot(s: Dictionary) -> bool:
	return SHOT_STYLES.has(str(s.get("kind", ""))) or skill_fx.handles_shot(s)


## True for the world's skill effects drawn here (the world skips them).
func handles_fx(f: Dictionary) -> bool:
	return skill_fx.handles_fx(f)


## True for the world's skill zones drawn here.
func handles_zone(z: Dictionary) -> bool:
	return skill_fx.handles_zone(z)


## True for held skills whose look is drawn here.
func handles_hold(id: String) -> bool:
	return skill_fx.handles_hold(id)


# --- look ---------------------------------------------------------------------------

## The hero's view state for hero_look (the crypt snapshot's player fields).
func view_state() -> Dictionary:
	var weapon: Dictionary = g.weapon
	var skills := {}
	if rage_on(): skills.rage = float(g.state.rage)
	for f: Dictionary in g.fx:
		if str(f.get("kind", "")) == "whirl" and Vector2(f.p).distance_to(Vector2(g.player.x, g.player.y - 40)) < 120.0: skills.whirl_time = float(f.t)
	if not (g.dash as Dictionary).is_empty(): skills.dash = "charge"
	if not (g.hold as Dictionary).is_empty() and str(g.hold.get("id", "")) == "ballista":
		var charge_time := float(g.HeroKit._skill(g, "ballista").get("charge", 1.0))
		skills.charge = clampf(float(g.hold.get("t", 0.0)) / maxf(0.1, charge_time), 0.0, 1.0)
	return {"class_id": str(g.class_id), "melee": str(weapon.get("type", "")) == "melee", "reach": float(weapon.get("reach", 120.0)),
		"swings": swings, "swing_angle": float(g.swing.a), "swing_arc": float(weapon.get("arc", 2.0)), "swing_dir": swing_dir,
		"shots": shots, "shot_interval": float(g.state.rate), "skills": skills}


## Draws the hero through the shared look. `draw_body(feet, alpha)` draws the
## figure standing at `feet`; the hero's chest is `lift` pixels above the feet.
## With `hero_look` (SubKit.look: frames, tint, scale) the class figure is drawn
## as the crypt's part rig; a changed figure (the ogre form) keeps `draw_body`.
func draw_hero(canvas: CanvasItem, t: float, lift: float, draw_body: Callable, hero_look: Dictionary = {}) -> void:
	var view := view_state()
	var rig := rig_name(hero_look)
	if not rig.is_empty():
		var size := scale * float(hero_look.get("scale", 1.0))
		var tint: Color = hero_look.get("tint", Color.WHITE)
		# steps keep pace with the hero's speed like the crypt's (stride 32 crypt px / speed)
		var pace := maxf(60.0, (g.player.get("vel", Vector2.ZERO) as Vector2).length())
		var body_view := {"moving": bool(g.player.get("moving", false)), "hp": float(g.state.get("hp", 1)), "hurts": hurts, "step_time": 32.0 * scale / pace}
		var facing := face(t)
		# the rig is placed by its centre; the story worlds give the feet
		var shape: Dictionary = rigs.library.rig(rig)
		var up := Vector2(0, (float(shape.ground.y) - float(shape.center.y)) * float(shape.scale) * size)
		draw_body = func(feet: Vector2, alpha: float) -> void:
			var key := KEY if alpha >= 1.0 else "ghost"
			rigs.draw_hero(canvas, key, body_view, feet - up, rig, facing, tint.a * alpha, size, Color(tint.r, tint.g, tint.b))
	var feet := Vector2(g.player.x, g.player.y)
	var chest := feet - Vector2(0, lift)
	var aim: Vector2 = g.HeroKit._aim(g)
	look.observe(KEY, view, chest, t)
	look.draw_dash_lines(canvas, KEY, view, chest, t)
	look.draw_afterimages(KEY, t, func(at: Vector2, alpha: float) -> void: draw_body.call(at + Vector2(0, lift), alpha))
	var offset := look.body_offset(KEY, view, aim, t)
	draw_body.call(feet + offset, 1.0)
	if g.weapon_tex != null and not g.relic_on():
		look.draw_weapon(canvas, KEY, view, chest + offset, aim, t, g.weapon_tex, AttackFx.tint_for({"style": "arrow"}, {"glow": str(g.state.get("glow", ""))}))


## The crypt rig of the hero's class, or "" (no rigs, another figure such as the ogre form).
func rig_name(hero_look: Dictionary) -> String:
	if rigs == null or hero_look.is_empty() or not CLASS_RIGS.has(str(g.class_id)): return ""
	if hero_look.get("frames") != g.hero_frames: return ""
	return str(CLASS_RIGS[str(g.class_id)])


## The way the hero faces: the aim, or turning with a whirling blade.
func face(t: float) -> float:
	return look.face(view_state(), g.HeroKit._aim(g), t)


func draw_layer(canvas: CanvasItem, glow: bool) -> void:
	var t := float(g.state.t)
	if glow:
		PixelPaint.clip = open_floor
		attack.draw_glow(canvas, _snapshot, func(b: Dictionary) -> Vector2: return Vector2(float(b.x), float(b.y)), t, 1.0)
		PixelPaint.clip = Callable()
		skill_fx.draw_glow(canvas)
		return
	# the shots' streaks, rune rings, motes and flashes stop at the walls (src/vfx/pixel_paint.gd clip)
	PixelPaint.clip = open_floor
	for b: Dictionary in _snapshot.bullets:
		var at := Vector2(float(b.x), float(b.y))
		if str(b.style) == "arrow": attack.draw_arrow(canvas, b, at, t)
		else: attack.draw_orb(canvas, b, at, t)
	attack.draw_flashes(canvas, t)
	PixelPaint.clip = Callable()
	skill_fx.draw_over(canvas)
