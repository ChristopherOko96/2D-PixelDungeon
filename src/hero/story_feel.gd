extends RefCounted
## The crypt's game feel in the story worlds (src/hell/hell_game.gd:
## Hell-Dungeon and Frostgruft). The world's hits, kills, blocks, hurts, shots,
## swings, spawns and level-ups run through the crypt's own src/vfx/feedback.gd,
## so every world reacts the same way, in its monsters' materials
## (assets/data/vfx_gore.json; docs/VFX-SYSTEM.de.md):
## - a hit: a red flash, squash and lean on a damped spring, sparks, a hit
##   spark, drops that land on the floor; liquids splash, bone chips; no hitstop;
## - a kill: a white flash, loose floor pixels jump, a burst in the material,
##   dust, a pool on the floor, the material's death sheet, shake and a short
##   hitstop (longer for a boss); monsters without a death animation of their
##   own fall over and fade like the crypt's;
## - wounded monsters leave a drip trail; new monsters rise from dust;
## - the hero: recoil on shots, a lean into swings, a red flash, blood and a
##   splat, shake and hitstop when hurt; the level-up sheet;
## - the crypt's poses: breathing while standing, a hop while running.
## Blasts of the enemy moves (src/hell/frost_moves.gd) burst like the crypt's
## boss moves. The crypt's sounds come with it (feedback.sfx is the world's
## sfx.gd): hits, kills, blocks, hurts, shots, swings, footsteps every
## theme.feel step_every, idle rattles and groans (the crypt's IDLE_RANGE and
## IDLE_GAP), windups and attacks, the boss sting, room clear, defeat and the
## level-up stinger; src/hero/story_sound.gd fills the snapshot's sound fields
## (docs/VFX-SYSTEM.de.md). The world's own crypt moments (a secret wall giving
## way, a pickup) are raised as the crypt's fx events (fx_event), so they look
## and sound like the crypt's. Everything runs in crypt units (world px / scale) on
## layers scaled by `scale`. Presentation only: the world stays authoritative.
## The hero's own moments follow the crypt too (docs/VFX-SYSTEM.de.md):
## - wall hits (wall_hit): shots and blades meeting a wall find their contact
##   by bisection like src/game.gd wall_hit, and feedback.gd chips, cracks,
##   sparks or splashes there in the shot's style;
## - perk markers (perk): heals, revives, shields, crits and the mage's splash
##   as the crypt's perk_events (feedback.gd bursts the splash; the markers are
##   src/dungeon_view.gd _draw_perk_events, drawn here);
## - level-ups, chests, pickups, potions and rubble as the crypt's fx events;
##   their life feeds src/vfx/skill_fx.gd's level-up pillar, ring and bloom;
## - the hero's conditions and thrown pools through the crypt's
##   src/vfx/boss_fx.gd; its shadow, its invulnerability blink with the hit
##   frame, the cast kick and the fall of a dead hero as src/dungeon_view.gd
##   and feedback.gd draw them.

const Feedback = preload("res://src/vfx/feedback.gd")
const StorySound = preload("res://src/hero/story_sound.gd")
## Crypt units per crypt cell (particles work in 32 px cells).
const CELL := 32.0
## Seconds a felled monster without a death animation takes to fall and fade.
const FALL_TIME := 0.45
## Crypt units between a monster's feet and the point the crypt reacts at.
const LIFT := 10.0
## Crypt units between the hero's feet and its reaction point.
const HERO_LIFT := 8.0
## Shake in crypt pixels at full trauma (src/dungeon_view.gd squares the trauma).
const SHAKE_PX := 9.0
## Crypt burst styles of the enemy moves' blasts (frost_moves.gd style -> zone_burst style).
const BLAST_STYLES := {"frost": "frost", "ice": "ice", "void": "void", "poison": "poison", "fire": "fire", "stone": "quake", "quake": "quake", "bone": "bone"}
## The crypt effect sheet each blast style bursts into.
const BLAST_SHEETS := {"fire": "fire_burst", "ice": "frost_burst", "frost": "frost_burst", "void": "void_burst", "poison": "poison_burst", "quake": "stone_burst", "bone": "stone_burst"}
## Pose of an actor the feel has not seen yet.
const REST := {"scale": Vector2.ONE, "lean": 0.0, "offset": Vector2.ZERO, "alpha": 1.0, "flash": 0.0, "flash_color": Color.WHITE}
const BossFx = preload("res://src/vfx/boss_fx.gd")
## The crypt balance (perk_rules.event_duration: how long a perk marker shows).
const BALANCE_PATH := "res://src/data/balance.json"
## Crypt units between the hero's feet and the crypt's hero point (src/dungeon_view.gd
## draws its heroes with the feet 16 px below the point): level-ups, markers, conditions, shadow.
const HERO_POINT := 16.0
## World px below its feet point where the story worlds draw the hero's sprite
## bottom (src/hell/hell_game.gd _draw_hero: feet.y + 6).
const SPRITE_DROP := 6.0
## Seconds an fx event lives in the crypt (src/game.gd add_fx: life 0.6); skill_fx.gd
## fades the level-up pillar and the rubble dust by it.
const EVENT_LIFE := 0.6
## At most this many fresh wall hits (younger than 0.1 s) at once (src/game.gd wall_hit).
const WALL_HITS := 8
## The crypt's invulnerability look (src/dungeon_view.gd _draw_player and
## _draw_class_hero): the hero at 45 % every other 0.08 s, its hit frame every other 0.12 s.
const INVULN_BLINK := 0.16
const INVULN_ALPHA := 0.45
const HIT_FRAME := 0.24
## The crypt's shadow under a hero (src/dungeon_view.gd _draw_shadow, half width 14).
const SHADOW_HALF := 14.0
const SHADOW_COLOR := Color(0.05, 0.04, 0.09)
## The crypt's perk marker colours (src/dungeon_view.gd _draw_perk_events).
const PERK_GOLD := Color("f6cf85")
const PERK_GREEN := Color("a7ddaa")
const PERK_BLUE := Color("a7cce8")
## Wall style of a hero shot kind, by the crypt's src/game.gd _shot_style (fireball
## fire, fist frost, the blade wave metal, magic magic, void shots void, rock
## stone, arrows arrow); the relic's gravity ball is void, its shards arcane.
const SHOT_WALL_STYLES := {"arrow": "arrow", "magic": "magic", "fireball": "fire", "fist": "frost", "wave": "metal", "gravity": "void", "rock": "stone", "shard": "arcane"}
## Wall style of an enemy move's shot (frost_moves.gd styles) by the same rule.
const ENEMY_WALL_STYLES := {"ice": "frost", "frost": "frost", "void": "void", "curse": "void", "fire": "fire", "poison": "poison", "spit": "poison"}
## Seconds a dead hero takes to fall (the crypt's fall of a felled actor, feedback.gd pose).
const DEATH_FALL := 0.45
## How far a dead hero falls (it stays lying, visible, like the crypt's fallen hero).
const DEATH_REST := 0.6

var g: Node
var cfg: Dictionary = {}
## The crypt's feedback layer; its particles are this feel's own.
var feedback := Feedback.new()
## Story world px per crypt unit (hero_scale over the crypt's 2).
var scale := 1.5
var _layers: Array[Node2D] = []
var _world: Variant = null
var _serial := 0
var _next_id := 1
var _events: Array = []
var _event_id := 1
var _fallen: Array = []
var _hurts := 0
var _hurt_dir := Vector2.ZERO
var _level := -1
var _clock := 0.0
var _masks: Dictionary = {}
## The crypt's condition and pool drawing (src/vfx/boss_fx.gd).
var boss_fx := BossFx.new()
## Perk markers of this moment (the crypt's perk_events: kind, x, y, tx, ty, time, o).
var _perks: Array = []
var _perk_time := 0.22
## Skill casts seen (the crypt's skill_casts counter) and the cooldowns last frame.
var _casts := 0
var _cooldowns: Dictionary = {}
var _hold := ""
var _death_at := -1.0
var _hit_frames: Dictionary = {}
## The floor's crypt cells (32 px) the particles and marks stay on.
var _cells: Dictionary = {}


class FeelLayer extends Node2D:
	var kit: RefCounted
	var mode := ""
	func _draw() -> void:
		kit.draw_layer(self, mode)


## `game` is the story world, `config` its theme.feel.
func _init(game: Node, config: Dictionary) -> void:
	g = game
	cfg = config
	scale = float(g.theme.get("hero_scale", 3.0)) / 2.0
	var crypt: Variant = JSON.parse_string(FileAccess.get_file_as_string(BALANCE_PATH)) if FileAccess.file_exists(BALANCE_PATH) else null
	if crypt is Dictionary:
		_perk_time = float((crypt as Dictionary).get("perk_rules", {}).get("mechanics", {}).get("event_duration", _perk_time))
	for spec: Array in [["ground", 5], ["over", 12], ["glow", 11]]:
		var layer := FeelLayer.new()
		layer.kit = self
		layer.mode = str(spec[0])
		layer.scale = Vector2(scale, scale)
		layer.z_index = int(spec[1])
		if layer.mode == "glow":
			var add := CanvasItemMaterial.new()
			add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
			layer.material = add
		g.add_child(layer)
		_layers.append(layer)


# --- the world's events -----------------------------------------------------------------

## A hero's hit landed on monster `m`, pushed along `push`.
func on_hit(m: Dictionary, push: Vector2, _crit := false) -> void:
	m.feel_hits = int(m.get("feel_hits", 0)) + 1
	m.feel_dir = push.normalized() if push.length() > 0.1 else Vector2.RIGHT.rotated(randf() * TAU)


## A monster's shield turned a hit aside.
func on_block(m: Dictionary) -> void:
	m.feel_blocks = int(m.get("feel_blocks", 0)) + 1


## Monster `m` fell. It stays in the crypt snapshot while it falls (dying 0..1):
## the crypt reacts once and, without a death animation of its own, shows the fall.
func on_kill(m: Dictionary) -> void:
	var e: Dictionary = _enemy(m).duplicate()
	e.dying_p = 0.0
	m.feel_e = e
	m.hit = 0.0
	_fallen.append({"m": m, "t": 0.0, "draw": not _own_death(m)})


## The hero lost a heart (from `from`, when known).
func on_hurt(from := Vector2.ZERO) -> void:
	_hurts += 1
	_hurt_dir = (Vector2(g.player.x, g.player.y) - from).normalized() if from != Vector2.ZERO else Vector2.ZERO


## A blast of an enemy move at world point `p`: the crypt's burst of its style.
func on_blast(p: Vector2, radius: float, style := "magic") -> void:
	var crypt_style := str(BLAST_STYLES.get(style, "void"))
	_event("zone_burst", p, {"style": crypt_style, "r": radius / scale})
	_spawn(str(BLAST_SHEETS.get(crypt_style, "magic_burst")), p, clampf(radius / 130.0, 0.5, 2.0))


## Any named crypt effect sheet at world point `p` (blink, whirl, level_up ...).
func spawn(name: String, p: Vector2, sheet_scale := 1.0, tint := Color.WHITE) -> void:
	_spawn(name, p, sheet_scale, tint)


## A crypt fx event of the world at world point `p` (feedback.gd fx_events:
## wall_break for a secret wall giving way, loot_taken for a pickup, armor for
## an enemy's ice armour ...): the crypt shows and sounds it like its own.
func fx_event(kind: String, p: Vector2, extra: Dictionary = {}) -> void:
	_event(kind, p, extra)


## A crypt fx event at the hero (the crypt sends hero events at its hero point):
## drink, curse, cleanse, identify, level_up ...
func hero_event(kind: String, extra: Dictionary = {}) -> void:
	_event(kind, hero_world(), extra)


## The crypt's hero point in world px: HERO_POINT crypt px above the drawn feet
## (the world draws the hero's sprite SPRITE_DROP px below its feet point).
func hero_world() -> Vector2:
	return Vector2(g.player.x, g.player.y + SPRITE_DROP) - Vector2(0, HERO_POINT * scale)


## A perk marker of the crypt (perk_combat.gd perk_events) at world point `p`
## (to `to` for a chain): "heal" and "revive" show a green cross, "shield" a
## blue ring, "crit" a gold ring, "blast" (the mage's splash, an area hit) a
## wide gold ring and feedback.gd's magic burst in the hero's staff glow.
func perk(kind: String, p: Vector2, to := Vector2.INF) -> void:
	var at := p / scale
	var end := to / scale if to.is_finite() else at
	_perks.append({"kind": kind, "x": at.x, "y": at.y, "tx": end.x, "ty": end.y, "time": _perk_time, "o": 1})
	if _perks.size() > 32:
		_perks.pop_front()


## A perk marker at the hero (heal, revive, shield).
func hero_perk(kind: String) -> void:
	perk(kind, hero_world())


## A perk marker at monster `m` (crit): where the crypt reacts on it.
func mob_perk(kind: String, m: Dictionary) -> void:
	perk(kind, (m.p as Vector2) - Vector2(0, LIFT * scale))


## The perk markers showing now (crypt units; for tests and the drawing).
func perk_events() -> Array:
	return _perks


## A shot or blade on its way from world point `from` to `to` met a wall (or a
## closed gate or a solid prop): the crypt's wall hit (src/game.gd wall_hit).
## The contact is found by bisection, the normal points back to the floor along
## the blocked axis; feedback.gd chips, cracks, sparks or splashes there in
## `style` (SHOT_WALL_STYLES, ENEMY_WALL_STYLES; "metal" clangs). `owner` 1 is
## the hero (a found staff splashes in its glow). False when WALL_HITS fresh
## ones already show (the crypt's limit).
func wall_hit(from: Vector2, to: Vector2, style: String, owner := 0) -> bool:
	var recent := 0
	for e: Dictionary in _events:
		if str(e.kind) == "wall_hit" and _clock - float(e.at) < EVENT_LIFE - 0.5:
			recent += 1
	if recent >= WALL_HITS:
		return false
	var low := 0.0
	var high := 1.0
	for step in range(7):
		var middle := (low + high) * 0.5
		if blocked(from.lerp(to, middle)):
			high = middle
		else:
			low = middle
	var contact := from.lerp(to, low)
	var travel := to - from
	var normal := -travel.normalized()
	var probe := 6.0 * scale
	var side_x := blocked(contact + Vector2(signf(travel.x) * probe, 0.0))
	var side_y := blocked(contact + Vector2(0.0, signf(travel.y) * probe))
	if side_x and not side_y:
		normal = Vector2(-signf(travel.x), 0.0)
	elif side_y and not side_x:
		normal = Vector2(0.0, -signf(travel.y))
	var extra := {"style": style, "nx": normal.x, "ny": normal.y, "r": 8.0}
	if owner > 0:
		extra.o = owner
	_event("wall_hit", contact, extra)
	return true


## True when world point `p` lies in a wall, a closed gate or a solid prop (what stops the world's shots).
func blocked(p: Vector2) -> bool:
	var C: float = g.C
	var cx := int(floor(p.x / C))
	var cy := int(floor(p.y / C))
	if g._cell_blocked(cx, cy, false):
		return true
	for r: Rect2 in (g.solid_grid as Dictionary).get(cy * int(g.W.cols) + cx, []):
		if r.grow_individual(0, 50, 0, 0).has_point(p):
			return true
	return false


## The wall style of a hero shot (SHOT_WALL_STYLES), "arrow" for the rest.
static func shot_wall_style(shot: Dictionary) -> String:
	return str(SHOT_WALL_STYLES.get(str(shot.get("kind", "")), "arrow"))


## The wall style of an enemy shot: its move's style, else the world's own
## (frost in the Frostgruft, fire in the hell).
func enemy_wall_style(shot: Dictionary) -> String:
	var own := str(ENEMY_WALL_STYLES.get(str(shot.get("style", "")), ""))
	if own != "":
		return own
	return "frost" if bool((g.W.get("theme", {}) as Dictionary).get("frost", false)) else "fire"


## A sword swing from world point `from` along `dir` with `reach`: when the
## blade's reach meets a wall, the crypt's metal clang (perk_combat.gd: a wall
## within reach * 0.85 in front of the hero).
func swing_wall(from: Vector2, dir: Vector2, reach: float) -> bool:
	var to := from + dir.normalized() * reach * 0.85
	var steps := maxi(2, int(from.distance_to(to) / 12.0))
	for i in range(1, steps + 1):
		if blocked(from.lerp(to, float(i) / float(steps))):
			return wall_hit(from, to, "metal", 1)
	return false


## The fx events with their life left (EVENT_LIFE from the crypt's add_fx),
## crypt units: what skill_fx.gd fades its level-up pillar, ring and bloom by.
func view_events() -> Array:
	var out: Array = []
	for e: Dictionary in _events:
		var life := EVENT_LIFE - (_clock - float(e.at))
		if life > 0.0:
			var v := e.duplicate()
			v.life = life
			out.append(v)
	return out


## The crypt's shake of a struck chest (src/vfx/skill_fx.gd draw_chest) in crypt
## px, `since` seconds after the blow (0 when not `active`).
static func hit_shake(since: float, active := true) -> float:
	return sin(since * 60.0) * 3.0 * maxf(0.0, 1.0 - since * 4.0) if active else 0.0


## The crypt's invulnerability look at time `t`: {alpha (1 or INVULN_ALPHA),
## hit (true while the hit frame shows)}.
static func invulnerable_look(t: float) -> Dictionary:
	return {"alpha": INVULN_ALPHA if fmod(t, INVULN_BLINK) < INVULN_BLINK * 0.5 else 1.0, "hit": fmod(t, HIT_FRAME) < HIT_FRAME * 0.5}


## The hit frame of a 0x72 hero frame (<sprite>_hit_anim_f0.png next to it,
## src/dungeon_view.gd loads the same), else `frame` itself.
func hit_frame(frame: Texture2D) -> Texture2D:
	if frame == null:
		return frame
	var path := frame.resource_path
	if not _hit_frames.has(path):
		var hit: Texture2D = null
		var cut := path.rfind("_anim_f")
		var name := path.substr(0, cut) if cut > 0 else ""
		for state: String in ["_idle", "_run"]:
			if name.ends_with(state):
				var hit_path := name.substr(0, name.length() - state.length()) + "_hit_anim_f0.png"
				if ResourceLoader.exists(hit_path):
					hit = load(hit_path)
		_hit_frames[path] = hit
	var found: Texture2D = _hit_frames[path]
	return found if found != null else frame


## The hero's crypt snapshot for boss_fx.gd: its point, hearts and conditions
## (the Frostgruft's state.effects and the potions' effects of item system 2).
func condition_snapshot() -> Dictionary:
	var at := hero_world() / scale
	var effects: Array = (g.state.get("effects", {}) as Dictionary).keys()
	var items: Node = g.get("story_items")
	if items != null:
		for kind: String in (items.effects as Dictionary).keys():
			if not kind in effects:
				effects.append(kind)
	return {"players": {1: {"x": at.x, "y": at.y, "hp": float(g.state.get("hp", 1)), "effects": effects}}, "boss_zones": _pools()}


## True when a crypt burst (on_blast) was raised within `radius` world px of
## `p` a moment ago: that landing already sounds through feedback.gd
## (src/hero/story_sound.gd skips its own blast then).
func burst_near(p: Vector2, radius: float) -> bool:
	var at := p / scale
	for e: Dictionary in _events:
		if str(e.kind) == "zone_burst" and _clock - float(e.at) <= StorySound.BURST_WINDOW \
				and at.distance_to(Vector2(float(e.x), float(e.y))) <= radius / scale + CELL:
			return true
	return false


## World cells (Vector2i, the world's grid) that became floor (a secret wall gave
## way): the crypt's rubble, marks and effect sheets reach into them now, as the
## crypt's new layout after a wall break (the skill kit's sheets and marks too).
func open_cells(world_cells: Array) -> void:
	if _cells.is_empty():
		return
	var per := int(round(float(g.C) / scale / CELL))
	for c: Vector2i in world_cells:
		for y in range(per):
			for x in range(per):
				_cells[Vector2i(c.x * per + x, c.y * per + y)] = true
	var kit: RefCounted = g.story_hero.skill_fx if g.story_hero != null else null
	if kit != null:
		var shared := _cells.duplicate()
		kit.fx.set_walkable(shared)
		kit.particles.set_walkable(shared, str(kit.particles.layout_key))


## A new floor: nothing of the last one lingers (the marks go with the world change).
func reset() -> void:
	_fallen.clear()
	_events.clear()
	_perks.clear()


# --- per frame ---------------------------------------------------------------------------

## True while a heavy blow holds the picture (hitstop).
func frozen() -> bool:
	return feedback.hitstop > 0.0


## One frame of hitstop: only the hold runs down.
func freeze(dt: float) -> void:
	feedback.update(dt)
	_redraw()


## Builds the crypt snapshot from the world and lets the crypt react.
func update(dt: float) -> void:
	_clock += dt
	var kit: RefCounted = g.story_hero.skill_fx if g.story_hero != null else null
	feedback.fx = kit.fx if kit != null else null
	# the crypt's sounds: feedback.gd plays them on the world's sound player (the
	# world plays these moments itself only without a feel: src/hell/hell_game.gd)
	feedback.sfx = g.get("sfx")
	if not is_same(_world, g.W):
		_world = g.W
		_set_floor()
	for f: Dictionary in _fallen:
		f.t = float(f.t) + dt
		(f.m.feel_e as Dictionary).dying_p = clampf(float(f.t) / FALL_TIME, 0.0, 1.0)
	_fallen = _fallen.filter(func(f: Dictionary) -> bool: return float(f.t) < FALL_TIME + 0.1)
	_events = _events.filter(func(e: Dictionary) -> bool: return _clock - float(e.at) < 1.0)
	for p: Dictionary in _perks:
		p.time = float(p.time) - dt
	_perks = _perks.filter(func(p: Dictionary) -> bool: return float(p.time) > 0.0)
	var level := int(g.state.get("level", 0))
	if _level >= 0 and level > _level:
		# at the crypt's hero point, like team_progress.gd's level_up (the sheet, pillar, ring and bloom)
		hero_event("level_up", {"r": 48.0})
	_level = level
	_count_casts()
	var enemies: Array = []
	var seen := {}
	for f: Dictionary in _fallen:
		enemies.append(f.m.feel_e)
		seen[int(f.m.feel_e.id)] = true
	for m: Dictionary in g.mobs:
		var e := _enemy(m)
		if not seen.has(int(e.id)):
			enemies.append(e)
	# phase and team level drive the crypt's room clear, defeat and level-up stingers
	feedback.observe({"room_layout": {"id": "story"}, "floor_index": int(g.state.get("floor", 0)), "room_serial": _serial,
		"phase": StorySound.phase(g), "team": {"level": level}, "enemies": enemies, "players": {1: _hero()}, "fx_events": _events, "perk_events": _perks}, 1)
	feedback.update(dt)
	# the skill kit's crypt snapshot gets the fx events with their life: skill_fx.gd draws the
	# level-up pillar and ring and the rubble dust from them, its bloom the level-up glow
	if kit != null and kit.get("snapshot") is Dictionary:
		kit.snapshot.fx_events = view_events()
	g.state.shake = maxf(float(g.state.get("shake", 0.0)), roundf(feedback.shake * feedback.shake * SHAKE_PX) * scale)
	if g.get("sound") != null:
		g.sound.frame(dt)
	_redraw()


# --- poses for the world's drawing ------------------------------------------------------

## The crypt pose of monster `m` (scale, lean, offset in world px, alpha, flash).
func pose(m: Dictionary) -> Dictionary:
	var e: Dictionary = m.get("feel_e", {})
	if e.is_empty():
		return REST
	var p := feedback.pose("e%d" % int(e.id), e, _clock, _own_death(m))
	p.offset = (p.offset as Vector2) * scale
	return p


## The crypt pose of the hero (its look keeps the motion; the spring, lean and flash come from here).
## A dead hero falls like the crypt's felled actors (flatten, tip over away from
## the blow) and stays lying at DEATH_REST.
func hero_pose() -> Dictionary:
	var entity := {"face": float(g.player.face)}
	var dying := dying_share()
	if dying >= 0.0:
		entity.dying_p = dying
		entity.dx = _hurt_dir.x if _hurt_dir.x != 0.0 else -float(g.player.face)
	var p := feedback.pose("p1", entity, _clock, dying < 0.0)
	p.offset = (p.offset as Vector2) * scale
	return p


## How far the dead hero has fallen (0..DEATH_REST), -1 while it lives.
func dying_share() -> float:
	var over: Dictionary = g.state.get("over", {})
	var lost := not over.is_empty() and not bool(over.get("won", false))
	if float(g.state.get("dead", 0.0)) <= 0.0 and not lost:
		_death_at = -1.0
		return -1.0
	if _death_at < 0.0:
		_death_at = _clock
	return clampf((_clock - _death_at) / DEATH_FALL, 0.0, 1.0) * DEATH_REST


## The colour to draw a pose's flash silhouette in (alpha = strength), or
## transparent without a flash.
static func flash_color(p: Dictionary, alpha := 1.0) -> Color:
	var c: Color = p.get("flash_color", Color.WHITE)
	return Color(c, clampf(float(p.get("flash", 0.0)), 0.0, 1.0) * alpha)


## The white silhouette of `texture` the crypt draws its hit flash with
## (src/dungeon_view.gd _silhouette), cached. `step` > 1 builds it at 1/step of
## the size (atlases drawn at an art-pixel multiple); draw its regions / step.
func mask(texture: Texture2D, step := 1) -> Texture2D:
	var key := "%d:%d" % [texture.get_instance_id(), step]
	if _masks.has(key):
		return _masks[key]
	var image: Image = texture.get_image()
	if image.is_compressed():
		image.decompress()
	image.convert(Image.FORMAT_RGBA8)
	if step > 1:
		image.resize(maxi(1, image.get_width() / step), maxi(1, image.get_height() / step), Image.INTERPOLATE_NEAREST)
	var data := image.get_data()
	for i in range(0, data.size(), 4):
		if data[i + 3] > 0:
			data[i] = 255
			data[i + 1] = 255
			data[i + 2] = 255
	image.set_data(image.get_width(), image.get_height(), false, Image.FORMAT_RGBA8, data)
	_masks[key] = ImageTexture.create_from_image(image)
	return _masks[key]


## Felled monsters still falling and fading (the world draws them like monsters).
func fallen() -> Array:
	var out: Array = []
	for f: Dictionary in _fallen:
		if bool(f.draw):
			out.append(f.m)
	return out


# --- drawing (layers scaled by `scale`) -------------------------------------------------

func draw_layer(canvas: CanvasItem, mode: String) -> void:
	match mode:
		"ground":
			feedback.particles.draw_stains(canvas)
			# thrown pools (boss_fx.gd pools) and the hero's shadow, under the figures like the crypt's
			var conditions := condition_snapshot()
			boss_fx.draw_ground(canvas, conditions, _clock)
			draw_shadow(canvas, hero_world() / scale)
		"over":
			draw_perk_events(canvas, _perks)
			boss_fx.draw_over(canvas, condition_snapshot(), _clock, func(e: Dictionary) -> Vector2: return Vector2(float(e.x), float(e.y)))
			feedback.particles.draw_particles(canvas)
		"glow":
			var kit: RefCounted = g.story_hero.skill_fx if g.story_hero != null else null
			feedback.particles.draw_glow(canvas, kit.glow.level("particles") if kit != null else 1.0)


## The crypt's shadow under a hero at crypt point `at` (src/dungeon_view.gd _draw_shadow).
static func draw_shadow(canvas: CanvasItem, at: Vector2, half := SHADOW_HALF) -> void:
	canvas.draw_rect(Rect2(floorf(at.x - half), floorf(at.y + 12.0), half * 2.0, 8.0), Color(SHADOW_COLOR, 0.55))
	canvas.draw_rect(Rect2(floorf(at.x - half + 4.0), floorf(at.y + 18.0), half * 2.0 - 8.0, 4.0), Color(SHADOW_COLOR, 0.25))


## The crypt's perk markers (src/dungeon_view.gd _draw_perk_events), crypt units:
## a gold ring for blasts (28) and crits (16), a blue one for shields, a green
## cross for heals and revives, a bent line for a chain.
static func draw_perk_events(canvas: CanvasItem, events: Array) -> void:
	for event: Dictionary in events:
		var point := Vector2(float(event.x), float(event.y)).round()
		var kind := str(event.kind)
		var tint: Color = PERK_GOLD if kind in ["blast", "crit"] else PERK_GREEN if kind in ["heal", "poison"] else PERK_BLUE
		if kind == "chain":
			var end := Vector2(float(event.tx), float(event.ty)).round()
			var midpoint := ((point + end) * 0.5).round() + Vector2(4, -4)
			canvas.draw_line(point, midpoint, tint, 2, false)
			canvas.draw_line(midpoint, end, tint, 2, false)
		elif kind in ["heal", "revive"]:
			canvas.draw_rect(Rect2(floorf(point.x - 2), floorf(point.y - 26), 4, 12), tint)
			canvas.draw_rect(Rect2(floorf(point.x - 6), floorf(point.y - 22), 12, 4), tint)
		else:
			var radius: float = 16 if kind in ["shield", "crit"] else 28
			for index: int in range(8):
				var offset := (Vector2.from_angle(TAU * index / 8) * radius).round()
				canvas.draw_rect(Rect2(floorf(point.x + offset.x - 2), floorf(point.y + offset.y - 2), 4, 4), tint)


# --- inside -----------------------------------------------------------------------------

## The crypt enemy of monster `m` (crypt units).
func _enemy(m: Dictionary) -> Dictionary:
	if not m.has("feel_id"):
		m.feel_id = _next_id
		_next_id += 1
		if float(m.get("spawn", 0.0)) > 0.0:
			_event("enemy_spawn", m.p)
	var at: Vector2 = (m.p as Vector2) / scale - Vector2(0, LIFT)
	var last: Vector2 = m.get("feel_at", at)
	m.feel_at = at
	var dir: Vector2 = m.get("feel_dir", Vector2.ZERO)
	var face: Variant = m.get("face", 1.0)
	var e := {"id": int(m.feel_id), "x": at.x, "y": at.y, "dx": dir.x, "dy": dir.y, "hits": int(m.get("feel_hits", 0)),
		"blocks": int(m.get("feel_blocks", 0)), "boss": str(m.get("kind", "")) == "boss" or bool(m.get("boss", false)), "kind": "mob",
		"gore": _gore(m), "hp": float(m.hp), "max_hp": float(m.get("max", m.hp)), "moving": at.distance_to(last) > 0.2,
		"face": (face as Vector2).x if face is Vector2 else float(face)}
	# its sound: crypt rig material, windup and attacks, lost and regrown parts (story_sound.gd)
	if g.get("sound") != null:
		e.merge(g.sound.enemy(m))
	m.feel_e = e
	return e


## The crypt hero (crypt units).
func _hero() -> Dictionary:
	var at := Vector2(g.player.x, g.player.y) / scale - Vector2(0, HERO_LIFT)
	var aim: Vector2 = g.HeroKit._aim(g)
	var hero: RefCounted = g.story_hero
	var skills := {}
	if float(g.state.get("rage", 0.0)) > 0.0:
		skills.rage = float(g.state.rage)
	return {"x": at.x, "y": at.y, "ax": aim.x, "ay": aim.y, "hurts": _hurts, "hit_dx": _hurt_dir.x, "hit_dy": _hurt_dir.y,
		"shots": int(hero.shots) if hero != null else 0, "swings": int(hero.swings) if hero != null else 0,
		"swing_angle": float(g.swing.get("a", aim.angle())), "reach": float(g.weapon.get("reach", 120.0)) / scale,
		"class_id": str(g.class_id), "skills": skills, "hp": float(g.state.get("hp", 1)), "moving": bool(g.player.get("moving", false)),
		"step_time": float(cfg.get("step_every", Feedback.STEP_INTERVAL)),
		# a found staff's or bow's glow (its splash and wall splash), the casts for the crypt's cast kick;
		# no last_skill: the world's kits sound their skills themselves (hero_kit.gd)
		"glow": str(g.state.get("glow", "")), "skill_casts": _casts, "last_skill": ""}


## Counts the hero's skill casts like the crypt's skill_casts: a cooldown that
## starts (rises) or a held skill that begins.
func _count_casts() -> void:
	var now: Dictionary = g.state.get("skill_cd", {})
	for key: Variant in now:
		if float(now[key]) > float(_cooldowns.get(key, 0.0)) + 0.01:
			_casts += 1
	_cooldowns = now.duplicate()
	var hold := str((g.get("hold") as Dictionary).get("id", "")) if g.get("hold") is Dictionary else ""
	if hold != "" and hold != _hold:
		_casts += 1
	_hold = hold


## The thrown pools of item system 2 (src/hero/story_items.gd pools) as the
## crypt's boss_zones pools (crypt units, p = share of the time gone).
func _pools() -> Array:
	var out: Array = []
	var items: Node = g.get("story_items")
	if items == null:
		return out
	for pool: Dictionary in items.pools:
		if not pool.has("feel_id"):
			pool.feel_id = _next_id
			_next_id += 1
		var at := (pool.p as Vector2) / scale
		var total := maxf(0.01, float(pool.get("max", pool.t)))
		out.append({"id": int(pool.feel_id), "k": "pool", "st": str(pool.get("style", "fire" if str(pool.get("status", "")) == "burn" else "poison")),
			"x": at.x, "y": at.y, "r": float(pool.r) / scale, "p": clampf(1.0 - float(pool.t) / total, 0.0, 1.0)})
	return out


## What monster `m` is made of (a vfx_gore.json kind or material): its id (the
## hell monsters), its kind (the crypt's enemies in the Frostgruft), its
## definition's material, else the crypt's default.
func _gore(m: Dictionary) -> String:
	var data := Feedback._gore_data()
	var kinds: Dictionary = data.get("kinds", {})
	var materials: Dictionary = data.get("materials", {})
	var id := str(m.get("id", ""))
	if kinds.has(id):
		return id
	var kind := str(m.get("kind", ""))
	if kind != "boss" and kinds.has(kind):
		return kind
	var mat := str((m.get("def", {}) as Dictionary).get("material", ""))
	mat = "blood" if mat == "flesh" else mat
	if materials.has(mat):
		return mat
	return kind if kinds.has(kind) else str(data.get("default", "blood"))


## True for monsters with a death animation of their own (the hell monsters' corpses).
func _own_death(m: Dictionary) -> bool:
	return g.monsters != null and m.has("id")


func _set_floor() -> void:
	_serial += 1
	var cells := {}
	var per := int(round(float(g.C) / scale / CELL))
	for cy in range(int(g.W.rows)):
		for cx in range(int(g.W.cols)):
			if not g._walkable(int(g.W.grid[cy * int(g.W.cols) + cx])): continue
			for y in range(per):
				for x in range(per):
					cells[Vector2i(cx * per + x, cy * per + y)] = true
	feedback.particles.clear()
	feedback.particles.set_walkable(cells, "feel_%d" % _serial)
	_cells = cells
	_fallen.clear()
	_events.clear()
	_perks.clear()
	# the hell monsters' flash silhouettes, built before the first hit needs them
	if g.monsters != null:
		for id: String in g.monsters.atlas:
			mask(g.monsters.atlas[id], int(g.monsters.defs[id].px))


func _event(kind: String, p: Vector2, extra: Dictionary = {}) -> void:
	var at := p / scale
	var e := {"id": _event_id, "kind": kind, "x": at.x, "y": at.y, "at": _clock}
	e.merge(extra)
	_events.append(e)
	_event_id += 1


func _spawn(name: String, p: Vector2, sheet_scale := 1.0, tint := Color.WHITE) -> void:
	if feedback.fx != null:
		feedback.fx.spawn(name, p / scale, 0.0, sheet_scale, tint, 1.0, true)


func _redraw() -> void:
	for layer: Node2D in _layers:
		if is_instance_valid(layer):
			layer.queue_redraw()
