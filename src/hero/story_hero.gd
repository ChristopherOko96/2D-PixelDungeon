extends RefCounted
const CutoutMotion=preload("res://src/rig/cutout_motion.gd")
## The crypt's polished heroes in the story worlds (src/hell/hell_game.gd:
## Hell-Dungeon and Frostgruft). Shares the crypt's look and feel:
## - the hero and its weapon through hero_look.gd (lean into swings, crescent,
##   Rage's two blades and crossed second swing, whirl, dash afterimages, bow
##   draw, staff recoil), at the story worlds' pixel size; on the part rig the
##   weapon is the rig's held weapon item (src/rig_kit/rig_held.gd, through
##   src/hero/story_weapon_host.gd), so it and its effects follow his body;
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
## - the mage's element skin (src/hero/element_skin.gd): the wizard rig's parts
##   (and the world's wizard frames) in the colours of his main specialisation,
##   and his familiar, the Irrwisch (src/hero/familiar.gd), floating round his hat.
## The world keeps its own rules, skills, subclasses and relics.

const HeroLook = preload("res://src/hero/hero_look.gd")
const ElementSkin = preload("res://src/hero/element_skin.gd")
const Familiar = preload("res://src/hero/familiar.gd")
const AttackFx = preload("res://src/vfx/attack_fx.gd")
const PixelPaint = preload("res://src/vfx/pixel_paint.gd")
const FxSprites = preload("res://src/vfx/fx_sprites.gd")
const StorySkillFx = preload("res://src/hero/story_skill_fx.gd")
const ClassPerks = preload("res://src/player/class_perks.gd")
const RigLibrary = preload("res://src/rig/rig_library.gd")
const RigRenderer = preload("res://src/rig/rig_renderer.gd")
const StoryWeaponHost = preload("res://src/hero/story_weapon_host.gd")
## The crypt's class figures (src/dungeon_view.gd CLASS_RIGS). The mage is the
## 0x72 wizard rig, recoloured by his element (hero_skins.json); the necromancer
## wears necro_hero (assets/data/story_rigs.json: his 0x72 sprite, the Knochenstab held).
const CLASS_RIGS := {"swordsman": "knight", "archer": "elf", "mage": "wizard", "necromancer": "necro_hero"}
const KEY := "hero"
## How often the mage's element is read again from the profile (s): a talent
## build changed mid-run recolours him at the next check.
const SKIN_CHECK := 0.5
## Shots whose look comes from attack_fx (the hero's arrows and spells).
const SHOT_STYLES := {"arrow": "arrow", "magic": "magic"}
## The hero's outlines (theme "outline" keys of the same name override them):
## hero = colour of a rim one art pixel round his figure ("" none: the Frostgruft
## sets one so he reads on the snow), alpha = its opacity; cover_inner /
## cover_outer = the light and the dark ring round him, drawn over everything
## while an enemy standing in front of him covers him (cover_alpha their opacity).
const OUTLINE := {"hero": "", "alpha": 0.9, "cover_inner": "#f4ecdc", "cover_outer": "#120d16", "cover_alpha": 0.85}
## Hero box (world px) when his figure has no rig: width, height over the feet.
const GUARD_SIZE := Vector2(36, 66)

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
## The weapon the rig holds (its held weapon item, src/rig_kit/rig_held.gd).
var weapon_host: StoryWeaponHost
## Seconds the hero view has run, also while the hero lies fallen: the clock of
## his dropped weapon (hero_look.gd drop_weapon), independent of the world's time.
var drop_clock := 0.0
## Hits taken, for the rig's hit recoil (counted on each new invulnerability).
var hurts := 0
var _last_inv := 0.0
## The mage's element ("" neutral, "fire", "ice", "void"): his main specialisation.
var element := ""
## The mage's Irrwisch (src/hero/familiar.gd); null for the other classes.
var familiar: RefCounted
## The world's hero frames as loaded, before the element skin, by kind ("idle", "run").
var _source_frames: Dictionary = {}
var _skin_check := 0.0
## OUTLINE with the theme's "outline" keys over it.
var outline: Dictionary = OUTLINE.duplicate()
## The x-ray look read once (xray()).
var _xray: Dictionary = {}
## The fair-combat data that holds the hero's x-ray look (hero_xray).
const TELLS_PATH := "res://assets/data/combat_tells.json"
## The hero's rig figure was drawn in this frame's draw_hero (its opacity), so a
## cover ring may go round it; false for another figure (the ogre form).
var _rig_shown := false
var _rig_alpha := 1.0
## Perfect timing's feedback (balance package B3, src/hell/hero_kit.gd
## perfect_defense) and a seal's price: loose pixels of matter (world px, a
## height over the floor), rim flashes and short words, on the 3 px art grid.
var _bits: Array = []
var _rims: Array = []
var _words: Array = []
var _rng := RandomNumberGenerator.new()
const PIXEL_FONT := preload("res://assets/fonts/pixel_operator8.ttf")
const ART := 3.0
const Pal = preload("res://src/vfx/talent_palette.gd")
## How each kind of matter moves (src/vfx/talent_palette.gd KIND): start speed
## along the floor and upwards (px/s), gravity on the height (px/s², below 0 it
## rises), drag (1/s), bounce share off the floor and walls, life (s).
## Sparks skip and die fast, shards and chips arc and clatter, drops fall and
## stay a moment as a dot, motes drift up and flicker out.
const MATTER := {
	"spark": {"speed": [200.0, 360.0], "up": [60.0, 180.0], "grav": 900.0, "drag": 1.8, "bounce": 0.35, "life": [0.25, 0.45]},
	"shard": {"speed": [120.0, 240.0], "up": [120.0, 240.0], "grav": 1100.0, "drag": 1.0, "bounce": 0.25, "life": [0.5, 0.8]},
	"chip": {"speed": [100.0, 200.0], "up": [80.0, 160.0], "grav": 1000.0, "drag": 1.2, "bounce": 0.2, "life": [0.4, 0.7]},
	"drop": {"speed": [10.0, 50.0], "up": [-20.0, 40.0], "grav": 1000.0, "drag": 2.0, "bounce": 0.0, "life": [0.6, 0.9]},
	"mote": {"speed": [70.0, 150.0], "up": [10.0, 40.0], "grav": -90.0, "drag": 4.0, "bounce": 0.0, "life": [0.4, 0.7]},
}
## The matter a block's look is made of (talents.json defense look).
const LOOK_MATTER := {"mana_bubble": "void", "gold_bubble": "gold", "soul_bubble": "bone", "shield_bubble": "ice"}


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
	var theme_outline: Variant = g.theme.get("outline", {})
	if theme_outline is Dictionary:
		for k: String in theme_outline:
			if OUTLINE.has(k): outline[k] = theme_outline[k]
	skill_fx = StorySkillFx.new(g, scale)
	# one particle world (physics plan R2): the hero's skills and attacks throw into the world's
	if g.get("feel") != null and absf(float(g.feel.scale) - scale) < 0.001: skill_fx.share(g.feel.feedback.particles)
	rigs = RigRenderer.new(RigLibrary.shared())
	if not rigs.is_ready(): rigs = null
	weapon_host = StoryWeaponHost.new(look)
	# the mage's familiar and his element skin on the world's frames
	if Familiar.has_familiar(str(g.class_id)): familiar = Familiar.new()
	_apply_skin(true)
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
	# the push it moved with this frame (MotionKit.step_body push_in; the decay is per 60th s)
	var push: Vector2 = m.get("k_in", m.k)
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
	drop_clock += dt
	if rigs != null:
		rigs.step(dt)
		rigs.footfalls.clear()
	var inv := float(g.state.get("inv", 0.0))
	if inv > _last_inv + 0.05: hurts += 1
	_last_inv = inv
	# the mage's element follows his talent build (changed in the pause menu mid-run)
	_skin_check -= dt
	if _skin_check <= 0.0:
		_skin_check = SKIN_CHECK
		_apply_skin(false)
	if familiar != null:
		familiar.step(dt, float(g.state.get("t", 0.0)), Vector2(g.player.x, g.player.y), float(g.theme.get("hero_scale", 3.0)), g.player.get("vel", Vector2.ZERO))
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
			"style": SHOT_STYLES[str(s.kind)], "critical": float(s.get("big", 1.0)) > 1.5 or bool(s.get("counter", false))})
	_snapshot = {"bullets": bullets, "players": {1: {"glow": str(g.state.get("glow", "")), "class_id": str(g.class_id)}}}
	attack.observe(_snapshot, float(g.state.t))
	skill_fx.update(dt, float(g.state.t))
	_step_matter(dt)
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
	var archer_charge: Dictionary = {}
	if g.talents!=null:
		var charge: Dictionary=g.talents.tc.player_state(1).get("charge",{})
		archer_charge = charge
		if str(charge.get("talent",""))=="sniper_14": skills.charge=float(charge.power)
	if rage_on(): skills.rage = float(g.state.rage)
	for f: Dictionary in g.fx:
		if str(f.get("kind", "")) == "whirl" and Vector2(f.p).distance_to(Vector2(g.player.x, g.player.y - 40)) < 120.0: skills.whirl_time = float(f.t)
	if not (g.dash as Dictionary).is_empty(): skills.dash = "charge"
	if not (g.hold as Dictionary).is_empty() and str(g.hold.get("id", "")) == "ballista":
		var charge_time := float(g.HeroKit._skill(g, "ballista").get("charge", 1.0))
		skills.charge = clampf(float(g.hold.get("t", 0.0)) / maxf(0.1, charge_time), 0.0, 1.0)
	return {"class_id": str(g.class_id), "melee": str(weapon.get("type", "")) == "melee", "reach": float(weapon.get("reach", 120.0)),
		"swings": swings, "swing_angle": float(g.swing.a), "swing_arc": float(weapon.get("arc", 2.0)), "swing_dir": swing_dir,
		"shots": shots, "shot_interval": float(g.state.rate), "skills": skills, "talents":{"charge":archer_charge}, "leap": g.talents.tc.SoulLeap.snapshot(g.talents.tc.runtime(1)) if g.talents != null else {}}


## Draws the hero through the shared look. `draw_body(feet, alpha)` draws the
## figure standing at `feet`; the hero's chest is `lift` pixels above the feet.
## With `hero_look` (SubKit.look: frames, tint, scale) the class figure is drawn
## as the crypt's part rig; a changed figure (the ogre form) keeps `draw_body`.
func draw_hero(canvas: CanvasItem, t: float, lift: float, draw_body: Callable, hero_look: Dictionary = {}) -> void:
	var view := view_state()
	look.observe_fireball(KEY, 1, g.talents.tc.events if g.talents != null else [], t, float(g.state.get("hp", 0)) > 0.0)
	var rig := rig_name(hero_look)
	_rig_shown = not rig.is_empty()
	# the weapon in the figure's hand: its rig's held weapon item (src/rig_kit/rig_held.gd),
	# posed by the rig, so the blade, the bow and the staff and their effects follow his body
	var held := not rig.is_empty() and RigHeld.holds(rigs.library.rig(rig))
	if not rig.is_empty():
		var size := scale * float(hero_look.get("scale", 1.0))
		var tint: Color = hero_look.get("tint", Color.WHITE)
		_rig_alpha = tint.a
		# steps keep pace with the hero's speed like the crypt's (stride 32 crypt px / speed)
		var pace := maxf(60.0, (g.player.get("vel", Vector2.ZERO) as Vector2).length())
		# the element goes with the view: the rig draws the mage's parts in its colours
		var body_view := {"moving": bool(g.player.get("moving", false)), "hp": float(g.state.get("hp", 1)), "hurts": hurts, "step_time": 32.0 * scale / pace, "element": element}
		body_view.render_shift = _draw_feet() - Vector2(g.player.x, g.player.y)
		body_view.leap = view.get("leap", {})
		var marksman_view := view.duplicate()
		marksman_view.hp = float(g.state.get("hp",1))
		body_view._marksman_motion = look.marksman.frame(KEY,marksman_view,t)
		# the world's rim round the hero (theme "outline": the Frostgruft's dark rim on the snow)
		if Color.html_is_valid(str(outline.hero)):
			body_view.outline = Color(Color.html(str(outline.hero)), float(outline.alpha))
		var facing := face(t)
		# the rig is placed by its centre; the story worlds give the feet
		var shape: Dictionary = rigs.library.rig(rig)
		var up := Vector2(0, (float(shape.ground.y) - float(shape.center.y)) * float(shape.scale) * size)
		draw_body = func(feet: Vector2, alpha: float) -> void:
			var key := KEY if alpha >= 1.0 else "ghost"
			rigs.draw_hero(canvas, key, body_view, feet - up, rig, facing, tint.a * alpha, size, Color(tint.r, tint.g, tint.b), weapon_host if alpha >= 1.0 and held else null)
	elif hero_look.get("frames") is Dictionary:
		var frames: Array=hero_look.frames.get("idle",[])
		if not frames.is_empty():
			var bind: Texture2D=frames[0]
			var size:=float(g.theme.get("hero_scale",3))*float(hero_look.get("scale",1))
			var tint: Color=hero_look.get("tint",Color.WHITE)
			draw_body=func(feet:Vector2,alpha:float)->void:
				CutoutMotion.draw(canvas,CutoutMotion.actor(bind,"hero_form",feet,size,face(t),t,view,Color(tint,tint.a*alpha)))
	var feet := _draw_feet()
	var chest := feet - Vector2(0, lift)
	var aim: Vector2 = look.casting_aim(KEY, g.HeroKit._aim(g), t)
	var fallen := float(g.state.get("hp", 1)) <= 0.0
	var armed: bool = g.weapon_tex != null and not g.relic_on()
	var glow := AttackFx.tint_for({"style": "arrow"}, {"glow": str(g.state.get("glow", ""))})
	var weapon_element := str(g.state.get("weapon_element", ""))
	weapon_host.frame(view, aim, t, g.weapon_tex, glow, weapon_element, armed and not fallen)
	look.observe(KEY, view, chest, t)
	look.draw_dash_lines(canvas, KEY, view, chest, t)
	look.draw_afterimages(KEY, t, func(at: Vector2, alpha: float) -> void: draw_body.call(at + Vector2(0, lift), alpha))
	var offset := look.body_offset(KEY, view, aim, t)
	draw_body.call(feet + offset, 1.0)
	# a fallen hero's weapon leaves his hand where the rig last held it and falls on its own
	# path (hero_look.gd drop_weapon, RigDebris); without a held item the look draws it itself
	if not fallen: look.forget_drop(KEY)
	if armed and fallen:
		look.drop_weapon(canvas, KEY, drop_clock, feet.y, face(t))
	elif armed and not held:
		look.draw_weapon(canvas, KEY, view, chest + offset, aim, t, g.weapon_tex, glow, weapon_element)
	# the mage's Irrwisch over the hero, on the world's art grid; gone with a fallen hero
	if familiar != null and float(g.state.get("dead", 0.0)) <= 0.0:
		familiar.draw(canvas, float(g.theme.get("hero_scale", 3.0)), t)


## The hero's figure once more at `feet` (the Frostgruft's mirror ghost, src/world_kit/frost_puzzles.gd):
## his rig with his subclass look and element colours, walking when he walks, faced `facing`, at
## `alpha` and tinted `tint`, holding his weapon; no effects. False without a rig (the caller then
## draws his frames).
func draw_mirror(canvas: CanvasItem, feet: Vector2, facing: float, alpha: float, hero_look: Dictionary, tint: Color) -> bool:
	var rig := rig_name(hero_look)
	if rig.is_empty() or rigs == null:
		return false
	var size := scale * float(hero_look.get("scale", 1.0))
	var own: Color = hero_look.get("tint", Color.WHITE)
	var pace := maxf(60.0, (g.player.get("vel", Vector2.ZERO) as Vector2).length())
	var body_view := {"moving": bool(g.player.get("moving", false)), "hp": 1.0, "hurts": 0, "step_time": 32.0 * scale / pace, "element": element}
	var shape: Dictionary = rigs.library.rig(rig)
	var up := Vector2(0, (float(shape.ground.y) - float(shape.center.y)) * float(shape.scale) * size)
	var held := RigHeld.holds(shape) and g.weapon_tex != null
	rigs.draw_hero(canvas, "mirror", body_view, feet - up, rig, facing, own.a * alpha, size, Color(own.r * tint.r, own.g * tint.g, own.b * tint.b), weapon_host if held else null)
	return true


## The hero's body in world px (his rig figure's height over the feet and its
## body width; GUARD_SIZE without a rig): what enemy weapons pass behind.
func guard_box() -> Rect2:
	var feet := _draw_feet()
	var size := GUARD_SIZE
	var rig_id := str(CLASS_RIGS.get(str(g.class_id), ""))
	var shape: Dictionary = rigs.library.rig(rig_id) if rigs != null and not rig_id.is_empty() else {}
	if not shape.is_empty():
		var px := float(shape.scale) * scale
		size = Vector2(float(shape.width) * px, (float(shape.ground.y) - float(shape.top) + 1.0) * px)
	return Rect2(feet.x - size.x / 2.0, feet.y - size.y, size.x, size.y)


func _draw_feet() -> Vector2:
	return g.render_hero_position() if g.has_method("render_hero_position") else Vector2(g.player.x, g.player.y)


## Starts a frame of the world's actors on `canvas`: the enemies' rig renderers
## (Krypta and Hölle: drake_rig, Frostgruft: frost_rigs) put held weapons that
## overlap the hero from in front behind the actors (rig_renderer.gd guard_hero).
func guard(canvas: CanvasItem) -> void:
	var box := guard_box()
	for host: Variant in [g.get("drake_rig"), g.get("frost_rigs")]:
		if host != null and host.get("renderer") != null:
			host.renderer.guard_hero(canvas, box)


## After the world's actors: when an enemy standing in front of the hero
## covered him this frame, his x-ray over it (A3, combat_tells.json hero_xray):
## where the enemies' bodies hide him, his own silhouette in one solid colour
## with a dark one-pixel rim, partly transparent, so he is never lost in a
## crowd on bones, stone or snow; with hero_xray "ring" also the thin light and
## dark ring round his whole figure. Not for another figure (the ogre form), a
## fallen or a hidden (stealth) hero.
func draw_cover(canvas: CanvasItem) -> void:
	if rigs == null or not _rig_shown or _rig_alpha < 0.5 or float(g.state.get("hp", 1)) <= 0.0: return
	var covered := false
	var covers: Array = []
	for host: Variant in [g.get("drake_rig"), g.get("frost_rigs")]:
		if host != null and host.get("renderer") != null and bool(host.renderer.hero_covered):
			covered = true
			covers.append_array(host.renderer.get("hero_cover") if host.renderer.get("hero_cover") is Array else [])
	if not covered: return
	var x := xray()
	rigs.draw_xray(canvas, KEY, covers, Color(Color.html(str(x.fill)), float(x.fill_alpha)), Color(Color.html(str(x.rim)), float(x.rim_alpha)))
	if not bool(x.ring): return
	var a := float(outline.cover_alpha)
	rigs.draw_ring(canvas, KEY, Color(Color.html(str(outline.cover_inner)), a), Color(Color.html(str(outline.cover_outer)), a))


## The hero's x-ray look (combat_tells.json hero_xray: fill, fill_alpha, rim,
## rim_alpha, ring) with this world's theme "outline" xray_* keys over it.
## Without the data: no x-ray (alpha 0) and the ring as before.
func xray() -> Dictionary:
	if _xray.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(TELLS_PATH)) if FileAccess.file_exists(TELLS_PATH) else null
		var data: Dictionary = (parsed as Dictionary).get("hero_xray", {}) if parsed is Dictionary else {}
		_xray = {"fill": str(data.get("fill", "#ffffff")), "fill_alpha": float(data.get("fill_alpha", 0.0)), "rim": str(data.get("rim", "#000000")),
			"rim_alpha": float(data.get("rim_alpha", 0.0)), "ring": bool(data.get("ring", true))}
		var theme_outline: Variant = g.theme.get("outline", {}) if g.get("theme") is Dictionary else {}
		if theme_outline is Dictionary:
			for k: String in ["fill", "fill_alpha", "rim", "rim_alpha"]:
				if (theme_outline as Dictionary).has("xray_" + k): _xray[k] = theme_outline["xray_" + k]
	return _xray


## The mage's element (src/hero/element_skin.gd) for the rig and the familiar, and
## the world's wizard frames recoloured in place to match (the clone and any
## frame-drawn fallback); the sources are kept for the next change. Frames only
## for a class whose sprite the skin knows (hero_skins.json skins.<class>.source).
func _apply_skin(force: bool) -> void:
	var class_id := str(g.class_id)
	if ElementSkin.skin(class_id).is_empty(): return
	var profile: Dictionary = g.profile if g.get("profile") is Dictionary else {}
	var next := ElementSkin.element(profile, class_id)
	if not force and next == element: return
	element = next
	if familiar != null: familiar.element = element
	var sprite := str((g.hero as Dictionary).get("sprite", "")) if g.get("hero") is Dictionary else ""
	if sprite.is_empty() or sprite != ElementSkin.source(class_id): return
	for kind: String in g.hero_frames:
		if not _source_frames.has(kind): _source_frames[kind] = (g.hero_frames[kind] as Array).duplicate()
		var frames: Array = g.hero_frames[kind]
		var sources: Array = _source_frames[kind]
		for i in range(mini(frames.size(), sources.size())):
			frames[i] = ElementSkin.texture(sources[i], element, class_id)


## The crypt rig of the hero's class, or "" (no rigs, another figure such as the ogre form).
func rig_name(hero_look: Dictionary) -> String:
	if rigs == null or hero_look.is_empty() or not CLASS_RIGS.has(str(g.class_id)): return ""
	if hero_look.get("frames") != g.hero_frames: return ""
	return str(CLASS_RIGS[str(g.class_id)])


## The way the hero faces: the aim, or turning with a whirling blade.
func face(t: float) -> float:
	return look.face(view_state(), look.casting_aim(KEY, g.HeroKit._aim(g), t), t)


func draw_layer(canvas: CanvasItem, glow: bool) -> void:
	var t := float(g.state.t)
	if glow:
		PixelPaint.clip = open_floor
		attack.draw_glow(canvas, _snapshot, func(b: Dictionary) -> Vector2: return Vector2(float(b.x), float(b.y)), t, 1.0)
		PixelPaint.clip = Callable()
		skill_fx.draw_glow(canvas)
		_draw_matter(canvas, true, t)
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
	_draw_matter(canvas, false, t)


# --- perfect timing and a seal's price (balance packages B3, D1) ---------------------

## Perfect timing's feel at the hero standing at `at` (src/hell/hero_kit.gd
## perfect_defense): "block" (the shield's rim flashes white and its matter,
## of talents.json defense `look_id`, flies off towards the blow from world
## point `toward`), "counter" (a perfect roll: a gold rim, motes rising, the
## bow readied) or "counter_shot" (the counter arrow leaves in gold sparks along
## direction `toward`). A short word says what it was.
func perfect(kind: String, at: Vector2, toward: Vector2, look_id := "") -> void:
	var chest := at - Vector2(0, 40)
	match kind:
		"block":
			var dir := Vector2(float(g.player.get("face", 1.0)), 0.0)
			if toward.is_finite() and toward.distance_to(chest) > 1.0:
				dir = (toward - chest).normalized()
			var element := str(LOOK_MATTER.get(look_id, "steel"))
			var rim := chest + dir * 16.0
			_rims.append({"p": rim, "t": 0.0, "max": 0.18, "r0": 9.0, "r1": 30.0, "element": element})
			matter(element, rim, dir, 12, 0.9)
			_word("PERFEKT", at - Vector2(0, 86), element)
		"counter":
			_rims.append({"p": chest, "t": 0.0, "max": 0.24, "r0": 14.0, "r1": 42.0, "element": "gold"})
			matter("gold", chest, Vector2.UP, 8, PI, "mote")
			_word("KONTER", at - Vector2(0, 86), "gold")
		"counter_shot":
			var aim := toward.normalized() if toward.length() > 0.01 else Vector2.RIGHT
			_rims.append({"p": chest + aim * 20.0, "t": 0.0, "max": 0.12, "r0": 5.0, "r1": 20.0, "element": "gold"})
			matter("gold", chest + aim * 20.0, aim, 8, 0.5)


## Throws `count` pixels of `element`'s matter from world point `at` (`lift`
## px over the floor) along `dir` (`spread`: half the cone in radians, PI all
## round). They move as MATTER says for their kind (talent_palette.gd KIND, or
## `kind`): fall, skip off the floor and the walls, drift or rest, then fade.
func matter(element: String, at: Vector2, dir: Vector2, count: int, spread := 0.9, kind := "", lift := 40.0) -> void:
	var key: String = kind if MATTER.has(kind) else str(Pal.KIND.get(Pal.resolve(element), "spark"))
	# with the world's particles the matter is theirs (physics plan R18): it falls with the world's
	# gravity, lands and lies, sinks in lava, sounds, and blasts and wells move it
	var feel: Variant = g.get("feel")
	if feel != null:
		var P: RefCounted = feel.feedback.particles
		var s := float(feel.scale)
		var at_p := at / s
		var cols := Pal.ramp_hot(element)
		match key:
			"spark": P.sparks(at_p, dir, count, [cols[0], cols[1], cols[2]])
			"shard": P.shatter(at_p, count, dir, 180.0, cols, 2, lift / s)
			"chip": P.chips(at_p, count, dir, [cols[1], cols[2], cols[3]])
			"drop": P.drops(at_p, count, dir, [cols[1], cols[2]])
			_: P.motes(at_p, count, [cols[0], cols[1]], 12.0, lift / s)
		return
	var spec: Dictionary = MATTER[key]
	var base := dir.angle() if dir.length() > 0.01 else 0.0
	for i in range(count):
		var ang := base + _rng.randf_range(-spread, spread)
		var speed := _rng.randf_range(float(spec.speed[0]), float(spec.speed[1]))
		_bits.append({"p": at + Vector2(0, lift), "h": lift, "v": Vector2.from_angle(ang) * speed * Vector2(1.0, 0.6),
			"vh": _rng.randf_range(float(spec.up[0]), float(spec.up[1])), "t": 0.0, "life": _rng.randf_range(float(spec.life[0]), float(spec.life[1])),
			"kind": key, "element": element, "seed": _rng.randi_range(0, 7)})
	while _bits.size() > 160:
		_bits.pop_front()


func _word(text: String, at: Vector2, element: String) -> void:
	_words.append({"text": text, "p": at, "t": 0.0, "max": 0.7, "element": element})


func _floor_at(p: Vector2) -> bool:
	return g._walkable(g._cell(int(floor(p.x / float(g.C))), int(floor(p.y / float(g.C)))))


## One step of the loose matter: drag along the floor, gravity on the height,
## a bounce off the floor and back off a wall; rims and words age.
func _step_matter(dt: float) -> void:
	for b: Dictionary in _bits:
		var spec: Dictionary = MATTER[str(b.kind)]
		b.t = float(b.t) + dt
		var v: Vector2 = (b.v as Vector2) * maxf(0.0, 1.0 - float(spec.drag) * dt)
		var next: Vector2 = (b.p as Vector2) + v * dt
		if v.length() > 0.0 and not _floor_at(next):
			v = -v * float(spec.bounce)
			next = b.p
		b.p = next
		b.vh = float(b.vh) - float(spec.grav) * dt
		b.h = float(b.h) + float(b.vh) * dt
		if float(b.h) <= 0.0 and float(spec.grav) > 0.0:
			b.h = 0.0
			# it lands: a little hop back (sparks skip), friction on the floor, then rest
			b.vh = -float(b.vh) * float(spec.bounce) if float(b.vh) < -40.0 else 0.0
			v *= 0.6 if float(spec.bounce) > 0.0 else 0.0
		b.v = v
	_bits = _bits.filter(func(b: Dictionary) -> bool: return float(b.t) < float(b.life))
	for r: Dictionary in _rims:
		r.t = float(r.t) + dt
	_rims = _rims.filter(func(r: Dictionary) -> bool: return float(r.t) < float(r.max))
	for w: Dictionary in _words:
		w.t = float(w.t) + dt
	_words = _words.filter(func(w: Dictionary) -> bool: return float(w.t) < float(w.max))


## Draws the loose matter, rims and words in world px on the 3 px art grid,
## the reeling monsters' stars and the readied counter; `glow`: the additive
## pass (rims and fresh bright pixels only).
func _draw_matter(canvas: CanvasItem, glow: bool, t: float) -> void:
	var reeling: bool = g.mobs.any(func(m: Dictionary) -> bool: return float(m.get("reel", 0.0)) > 0.0)
	if _bits.is_empty() and _rims.is_empty() and _words.is_empty() and not reeling and (g.state.get("counter", {}) as Dictionary).is_empty():
		return
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE / scale)
	for r: Dictionary in _rims:
		var k := float(r.t) / float(r.max)
		var ramp: Array = Pal.ramp(str(r.element))
		var rad := lerpf(float(r.r0), float(r.r1), 1.0 - pow(1.0 - k, 3.0))
		var col: Color = ramp[4] if k < 0.35 else ramp[3]
		col.a = (1.0 - k) * (0.55 if glow else 1.0)
		PixelPaint.ellipse(canvas, _snap(r.p), rad, rad * 0.8, col, ART)
	for b: Dictionary in _bits:
		var k := float(b.t) / float(b.life)
		if glow and k > 0.4:
			continue
		# motes flicker as they burn out
		if str(b.kind) == "mote" and k > 0.5 and (int(t * 24.0) + int(b.seed)) % 3 == 0:
			continue
		var ramp: Array = Pal.ramp(str(b.element))
		var col: Color = ramp[4] if k < 0.25 else (ramp[3] if k < 0.6 else ramp[2])
		col.a = 1.0 if k < 0.7 else (1.0 - k) / 0.3
		var q := PixelPaint.at((b.p as Vector2) - Vector2(0, float(b.h)), ART)
		PixelPaint.cell(canvas, q, col, ART)
		# a fast spark draws a short streak behind it
		var v: Vector2 = b.v
		if str(b.kind) == "spark" and not glow and v.length() > 150.0:
			var tail := Color(ramp[2], col.a * 0.7)
			PixelPaint.cell(canvas, q - Vector2i(int(signf(v.x)), int(signf(v.y) if absf(v.y) > absf(v.x) * 0.5 else 0.0)), tail, ART)
	if not glow:
		_draw_reel(canvas, t)
		_draw_counter(canvas, t)
		for w: Dictionary in _words:
			var k := float(w.t) / float(w.max)
			var a := 1.0 if k < 0.6 else (1.0 - k) / 0.4
			var font_size := 24 if k < 0.12 else 16
			var width := PIXEL_FONT.get_string_size(str(w.text), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			var pos := _snap((w.p as Vector2) - Vector2(width / 2.0, 20.0 * (1.0 - pow(1.0 - k, 2.0))))
			var ramp: Array = Pal.ramp(str(w.element))
			canvas.draw_string_outline(PIXEL_FONT, pos, str(w.text), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 6, Color(ramp[0].darkened(0.6), a))
			canvas.draw_string(PIXEL_FONT, pos, str(w.text), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(ramp[4], a))
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _snap(p: Vector2) -> Vector2:
	return Vector2(PixelPaint.at(p, ART)) * ART


## Monsters reeling from a perfect block (hero_kit.gd stagger): three pixel
## stars circle over the head, the opening to strike; they fade as it ends.
func _draw_reel(canvas: CanvasItem, t: float) -> void:
	var ramp: Array = Pal.ramp("gold")
	for m: Dictionary in g.mobs:
		var left := float(m.get("reel", 0.0))
		if left <= 0.0 or float(m.get("hp", 1.0)) <= 0.0:
			continue
		var fade := clampf(left / 0.25, 0.0, 1.0)
		var head: Vector2 = Vector2(m.p) - Vector2(0, float(m.get("cy", 30.0)) * 2.0 + 12.0 + float(m.get("alt", 0.0)))
		var rx := maxf(float(m.get("r", 20.0)) * 0.7, 15.0)
		for i in range(3):
			var a := t * 7.0 + TAU * i / 3.0
			var q := PixelPaint.at(head + Vector2(cos(a) * rx, sin(a) * rx * 0.35), ART)
			var front := sin(a) > 0.0
			PixelPaint.cell(canvas, q, Color(ramp[4] if front else ramp[3], fade), ART)
			for o: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				PixelPaint.cell(canvas, q + o, Color(ramp[3] if front else ramp[2], fade * 0.85), ART)


## The archer's readied counter (a perfect roll): a gold glint blinks at his
## bow hand and two motes circle him until the shot leaves or the time is up.
func _draw_counter(canvas: CanvasItem, t: float) -> void:
	var counter: Dictionary = g.state.get("counter", {})
	if counter.is_empty():
		return
	var share := clampf(float(counter.get("t", 0.0)) / maxf(0.01, float(counter.get("max", 1.0))), 0.0, 1.0)
	var ramp: Array = Pal.ramp("gold")
	var chest := Vector2(g.player.x, g.player.y - 40)
	var aim: Vector2 = g.player.get("aim", Vector2.RIGHT)
	var hand := PixelPaint.at(chest + (aim.normalized() if aim.length() > 0.01 else Vector2.RIGHT) * 18.0, ART)
	var on := int(t * 10.0) % 2 == 0
	var a := 0.45 + 0.55 * share
	PixelPaint.cell(canvas, hand, Color(ramp[4] if on else ramp[3], a), ART)
	if on:
		for o: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			PixelPaint.cell(canvas, hand + o, Color(ramp[3], a * 0.8), ART)
	for i in range(2):
		var ang := t * 5.0 + PI * i
		PixelPaint.cell(canvas, PixelPaint.at(chest + Vector2(cos(ang) * 26.0, sin(ang) * 10.0), ART), Color(ramp[3], a * 0.8), ART)
