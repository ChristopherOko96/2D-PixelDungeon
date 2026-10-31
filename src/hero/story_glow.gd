extends RefCounted
## The crypt's bloom and darkness in the story worlds (src/hell/hell_game.gd:
## Hell-Dungeon and Frostgruft), by the crypt's own rules (src/dungeon_view.gd
## _draw_glow and _update_darkness):
## - ONE bloom layer, the crypt's src/vfx/glow.gd (additive Gaussian dots and
##   bands, strengths from assets/data/vfx_glow.json), drawn ABOVE the darkness
##   and hidden whenever the darkness is (the light switch L). It also draws the
##   hero kit's and the feel's bloom (story_hero.gd, story_skill_fx.gd,
##   story_feel.gd), whose own layers sit under the darkness and stay hidden;
## - the darkness is the crypt's src/vfx/darkness.gd, lit in the crypt's order
##   (lights()): the hero and the clone (its players); the map's fires on screen
##   (its braziers and torches); the lava banks (like its light shafts, steady
##   pools); then the fight: warnings and impacts before shots (SHARES.fight) and
##   the monsters (SHARES.mobs); the map's magic; what lies in the margin outside
##   the view; the exits last (doors and glowing posts, merged), as the crypt's
##   exits. Each group nearest the view's centre first, at most
##   Darkness.MAX_LIGHTS. Shots light by the crypt's bullet rule, zones by
##   boss_fx.gd's strike / pool / vortex rule (the world's own zones through
##   vfx_glow.json story.world_zones), magma puddles by skill_fx.gd's lava zone,
##   Ignaroth 4's beams by rig_renderer.gd's beam rule;
## - the map's fires bloom like the crypt's torches and braziers (flicker,
##   'torches' level), in each light's own colour or the theme's flame colour
##   (theme "atmosphere".flames, the crypt atmosphere's schema); the vault, keys,
##   gems and hearts like the crypt's loot (skill_fx.gd draws them; like the
##   crypt's loot they cast no light); magma puddles like its lava zones;
## - enemy shots bloom like the crypt's bullets (skill_fx.gd bullet_glow);
## - the story worlds' own bright things (portals, seals, rune plates, gates,
##   the monsters' attacks, the world's skill blasts and icicle strikes) bloom by
##   vfx_glow.json story.bloom; the monsters' glowing parts (eyes, flames, cores)
##   by story.hell_monsters / story.frost_mobs, where the world drew the body this
##   frame (mark(), called by hell_monsters.gd and hell_game.gd);
## - what hides behind a front wall (the hell's south wall strips over the
##   actors) does not bloom through it: glowing parts, embers and enemy shots.
## Items are computed in world px; the bloom node is scaled by `scale` (crypt
## units, like the hero kit's layers), so drawing divides by it.
## Presentation only: the world stays authoritative.

const Glow = preload("res://src/vfx/glow.gd")
const Darkness = preload("res://src/vfx/darkness.gd")
const ElementRules = preload("res://src/combat/element_rules.gd")
const BossFx = preload("res://src/vfx/boss_fx.gd")
const SkillFx = preload("res://src/vfx/skill_fx.gd")
const CryptAtmosphere = preload("res://src/vfx/crypt_atmosphere.gd")
const RelicKit = preload("res://src/hell/relic_kit.gd")

## Darkness lights of the fight and the monsters (on screen first, then the
## margin) and of the lava banks; the fires on screen come before them.
const SHARES := {"fight": 16, "mobs": 12, "lava": 8}
## A fire counts as on screen this far outside the view (world px): its bloom
## reaches into the view, so it is lit before the fight (map_items blooms the same).
const FIRE_MARGIN := 150.0
## Lights this far outside the view still reach into it (world px).
const REACH := 300.0
## Exit lights (doors, glowing posts) closer than this merge into one (world px).
const EXIT_MERGE := 150.0
## A watched world zone that vanishes with this little time left has struck.
const STRUCK := 0.1
## Seconds a monster's act-bound glow takes to fade in.
const ACT_RAMP := 0.35
## Crypt bullet style of a hell monster shot colour (hell_monsters.gd SHOT_COL;
## the small breath flames are "magic" cinder). Chains do not glow.
## The crypt's elements (Story 1): bone shots do not glow, ice as a shard.
const HELL_STYLES := {"fire": "fireball", "lava": "fireball", "void": "void_skull", "soul": "magic", "bone": "", "frost": "shard", "poison": "magic", "gold": "magic"}
const HELL_ELEMENTS := {"soul": "venom", "fire": "cinder", "frost": "frost", "poison": "venom", "gold": "cinder"}
## The elements only the crypt's figures have (hell_monsters.gd CRYPT_ELEMENTS): their
## lobs, meteors, impacts and slams glow in them; the hell's stay fire.
const CRYPT_ELEMENTS := ["bone", "poison", "frost", "gold"]
## Crypt bullet style of an enemy move's shot style (frost_moves.gd STYLE).
const MOVE_STYLES := {"ice": "shard", "frost": "shard", "void": "void_skull", "curse": "void_skull", "fire": "fireball", "poison": "magic", "spit": "magic"}
const MOVE_ELEMENTS := {"poison": "venom", "spit": "venom"}

# --- the crypt's values its own code keeps inline (nothing to call): tests/story_glow_test.gd
# test_crypt_parity reads the crypt's source and fails when one of them is tuned there.

## Darkness light per bullet style: [radius crypt px, strength] (dungeon_view.gd
## _update_darkness: fireball 84 / 0.9, magic, void skull, soul and fist 46 / 0.8).
## The Frostgruft's ice shards are its main enemy shots, so they light like magic.
const BULLET_LIGHT := {"fireball": [84.0, 0.9], "magic": [46.0, 0.8], "void_skull": [46.0, 0.8], "soul": [46.0, 0.8], "fist": [46.0, 0.8], "shard": [46.0, 0.8]}
## Map fires by their light radius (tools/hell_dungeon/hell_core.js LIGHT):
## [from radius, bloom radius crypt px, alpha, Hz, kind]. Standing braziers bloom
## like the crypt's braziers (dungeon_view.gd _draw_glow: 50 px, 0.22, 8 Hz), wall
## torches, wall braziers, low braziers and altars like its torches (42 px, 0.2,
## 9 Hz). Smaller lights (rune pillars, obelisks, fire plates) are the story
## worlds' own slow glow (vfx_glow.json story.bloom.rune).
const FLAME_CLASSES := [[260.0, 50.0, 0.22, 8.0, "brazier"], [220.0, 42.0, 0.2, 9.0, "torch"]]
## The crypt's exit light (dungeon_view.gd _update_darkness): gates and glowing door posts, crypt px.
const EXIT_LIGHT := Vector2(56.0, 0.5)
## The crypt's ember bloom (particles.gd draw_glow): radius 5 + 5 * heat crypt px, alpha 0.3 * heat.
const EMBER_GLOW := Vector3(5.0, 5.0, 0.3)
## The crypt's light along a burning beam (rig_renderer.gd lights: 68 crypt px).
const BEAM_LIGHT := 68.0

var g: Node
## Story world px per crypt unit (hero_scale over the crypt's 2, as the hero kit).
var scale := 1.5
## The crypt's bloom node (above the darkness).
var glow: Glow
## vfx_glow.json "story": glowing parts, bloom kinds, world zones.
var data: Dictionary = {}
## vfx_glow.json story.bloom: the story worlds' own bloom kinds.
var bloom: Dictionary = {}
## The theme's flames in the crypt atmosphere's schema (empty: each map light keeps its colour).
var flames: Dictionary = {}
## The theme's "glow" colours and lava glow.
var look: Dictionary = {}
## The darkness lights of the last frame (world px).
var last_lights: Array = []
var _boss_fx := BossFx.new()
## The crypt's skill effects, for its lava zone and loot rules (no beams of its own).
var _skill := SkillFx.new()
## Bodies the world drew: [body, drawn, frame] (mark()).
var _marks: Array = []
## World zones that flare when they strike: [zone, time left when last seen].
var _watch: Array = []
## Strikes flaring now: {p, r, kind, t, T} world px, seconds.
var _flares: Array = []
var _last_clock := 0.0
var _walls_seen: Variant = null
## Front wall cover per cell: Vector2i -> [Vector2(y0, y1), ...] world px.
var _covers: Dictionary = {}


## `game` is the story world; its `dark` must be the crypt's Darkness node.
func _init(game: Node) -> void:
	g = game
	data = Glow.load_data().get("story", {})
	bloom = data.get("bloom", {})
	look = g.theme.get("glow", {})
	var atmosphere: Variant = g.theme.get("atmosphere")
	if atmosphere is Dictionary and (atmosphere as Dictionary).has("flames"):
		var parsed: Dictionary = CryptAtmosphere.parse(atmosphere).flames
		if bool(parsed.get("enabled", true)):
			flames = parsed
	glow = Glow.new()
	glow.source = draw
	g.add_child(glow)
	# added over the darkness, like the crypt's (src/dungeon_view.gd), and drawn above it
	glow.z_index = (g.dark as CanvasItem).z_index + 1
	_follow_scale()


# --- per frame --------------------------------------------------------------------------

## The world's clock (stands still in a hitstop, as the picture does).
func clock() -> float:
	return float(g.state.get("t", 0.0))


## Per frame (src/hell/hell_game.gd _process): the darkness's look and lights,
## the bloom shown with the darkness only.
func frame() -> void:
	_follow_scale()
	_adopt()
	_track_strikes()
	# bodies the world no longer draws (felled, gone) are let go
	var now := Engine.get_process_frames()
	_marks = _marks.filter(func(e: Array) -> bool: return now - int(e[2]) <= 1)
	var on := bool(g.state.get("light", true))
	var dark: Darkness = g.dark
	dark.visible = on
	glow.visible = on and glow.enabled
	# inside gas the far blooms are swallowed with the view (hell_game.gd vision)
	var vision_k := float((g.get("vision") as Dictionary).get("k", 0.0)) if g.get("vision") is Dictionary else 0.0
	glow.modulate = Color(1.0, 1.0, 1.0, 1.0 - 0.85 * vision_k)
	if not on:
		return
	dark.configure({"darkness": darkness(), "shade_color": shade()})
	var mat := dark.material as ShaderMaterial
	mat.set_shader_parameter("light_bands", float(g.balance.view.get("light_bands", 5)))
	# a world with fog (theme "fog", the Frostgruft): the dark is a pale drifting frost fog
	var fog: Dictionary = g.theme.get("fog", {})
	mat.set_shader_parameter("fog_noise", float(fog.get("wisps", 0.0)))
	if not fog.is_empty():
		# light thins fog softly: more, finer steps than the dark's hard bands
		mat.set_shader_parameter("light_bands", float(fog.get("bands", 12)))
		mat.set_shader_parameter("fog_scale", float(fog.get("scale", 420.0)))
		var drift: Array = fog.get("drift", [22.0, 7.0])
		mat.set_shader_parameter("fog_drift", Vector2(float(drift[0]), float(drift[1])))
		mat.set_shader_parameter("time", clock())
	dark.set_world_size(Vector2(float(g.W.cols), float(g.W.rows)) * float(g.C))
	last_lights = lights()
	# inside gas (src/hell/hell_game.gd vision, element_rules.json): the world outside the
	# cloud goes dark, the hero keeps the cloud round him; the other lights are swallowed
	var vision: Dictionary = g.get("vision") if g.get("vision") is Dictionary else {}
	var closed := float(vision.get("k", 0.0))
	if closed > 0.0:
		var full := float(ElementRules.vision().get("dark", 0.94))
		dark.configure({"darkness": maxf(darkness(), lerpf(darkness(), full, closed)), "shade_color": shade().lerp(Color(0.02, 0.02, 0.03), closed * 0.8)})
		var keep := float(vision.get("r", 200.0))
		var seen: Array = [Vector4(g.player.x, g.player.y - 40, keep, 1.0)]
		for l: Vector4 in last_lights.slice(1):
			var d := Vector2(l.x, l.y).distance_to(Vector2(g.player.x, g.player.y - 40))
			# a light inside the cloud still shows, dimmer the more the view is closed
			if d + l.z * 0.5 < keep:
				seen.append(Vector4(l.x, l.y, l.z * (1.0 - 0.6 * closed), l.w * (1.0 - 0.5 * closed)))
		last_lights = seen
	dark.set_lights(last_lights)
	if glow.visible:
		glow.queue_redraw()


## Darkness of the floor (theme dark, deeper in a storm), as the world always had it. A world with
## fog (theme "fog") has its fog's density instead, a little thicker on deeper floors.
func darkness() -> float:
	var fog: Dictionary = g.theme.get("fog", {})
	if not fog.is_empty():
		return clampf(float(fog.get("density", 0.5)) + float(fog.get("deeper", 0.0)) * (int(g.state.get("floor", 1)) - 1) / 9.0, 0.0, 0.95)
	return clampf(float(g.W.theme.dark) + 0.16 + (0.14 if bool(g.state.get("storm", false)) else 0.0), 0.0, 0.95)


## Shade of the dark: the theme's shade, tinted by the floor's grade; a world with fog has its
## fog's colour.
func shade() -> Color:
	var fog: Dictionary = g.theme.get("fog", {})
	if not fog.is_empty():
		return Color(str(fog.get("color", "#c4d6ee")))
	var c: Color = g.col("shade") + g.col("shade_grade") * float(g.W.theme.grade)
	c.a = 1.0
	return c


func _follow_scale() -> void:
	scale = float(g.theme.get("hero_scale", 3.0)) / 2.0
	glow.scale = Vector2(scale, scale)


## The hero kit's and the feel's own bloom layers sit under the darkness; their
## bloom is drawn here, so they stay hidden (a graphics switch brings a new kit).
## (story_hero.gd and story_feel.gd create them; they have no switch to skip it.)
func _adopt() -> void:
	var hero: Variant = g.story_hero
	if hero != null:
		var layer: Variant = hero.get("_glow_layer")
		if is_instance_valid(layer) and layer is CanvasItem and (layer as CanvasItem).visible:
			(layer as CanvasItem).visible = false
	if g.feel != null:
		for layer: Variant in g.feel.get("_layers"):
			if is_instance_valid(layer) and layer is CanvasItem and str(layer.get("mode")) == "glow":
				(layer as CanvasItem).visible = false


## Glow hook (hell_monsters.gd _mark, hell_game.gd _draw_mob_sprite): the world
## drew `body` (a monster or a corpse) this frame as `drawn`: {foot, size, src,
## face, lean, cut, alpha} world px; its glowing parts follow it.
func mark(body: Dictionary, drawn: Dictionary) -> void:
	var now := Engine.get_process_frames()
	for i in range(_marks.size() - 1, -1, -1):
		if is_same(_marks[i][0], body):
			_marks[i] = [body, drawn, now]
			return
	_marks = _marks.filter(func(e: Array) -> bool: return now - int(e[2]) <= 1)
	_marks.append([body, drawn, now])


## Where the world drew `body` last ({} when it did not draw it this or the last frame).
func drawn_of(body: Dictionary) -> Dictionary:
	var now := Engine.get_process_frames()
	for e: Array in _marks:
		if is_same(e[0], body) and now - int(e[2]) <= 1:
			return e[1]
	return {}


## World zones that strike (story.world_zones "impact") flare when they vanish.
func _track_strikes() -> void:
	var now := clock()
	var dt := clampf(now - _last_clock, 0.0, 0.5)
	_last_clock = now
	for f: Dictionary in _flares:
		f.t = float(f.t) + dt
	_flares = _flares.filter(func(f: Dictionary) -> bool: return float(f.t) < float(f.T))
	var zones: Array = g.zones
	for w: Array in _watch:
		var z: Dictionary = w[0]
		if float(w[1]) <= STRUCK and not zones.any(func(o: Dictionary) -> bool: return is_same(o, z)):
			var kind := str(world_zone(z).impact)
			_flares.append({"p": z.p, "r": float(z.r), "kind": kind, "t": 0.0, "T": float(_spec(kind).get("time", 0.35))})
	_watch = []
	for z: Dictionary in zones:
		if world_zone(z).has("impact"):
			_watch.append([z, float(z.t)])


## A world zone's entry in vfx_glow.json story.world_zones ({} for an unknown kind).
func world_zone(z: Dictionary) -> Dictionary:
	return data.get("world_zones", {}).get(str(z.get("kind", "")), {})


# --- darkness lights ----------------------------------------------------------------

## This frame's darkness lights (Vector4 x, y, radius, strength; world px), in
## the crypt's order (see the header).
func lights() -> Array:
	var view: Rect2 = g._view_rect()
	var reach := view.grow(REACH)
	var centre := view.get_center()
	var most := mini(int(g.balance.view.get("max_lights", Darkness.MAX_LIGHTS)), Darkness.MAX_LIGHTS)
	# a world with fog may give the hero a smaller light of its own (theme fog.player_light)
	var reach_own := float(g.theme.get("fog", {}).get("player_light", g.balance.view.player_light))
	var own := reach_own * (0.55 if g.story_items != null and g.story_items.dim() else 1.0)
	var out: Array = [Vector4(g.player.x, g.player.y - 40, own, 1.0)]
	if not (g.clone as Dictionary).is_empty():
		out.append(Vector4(g.clone.p.x, g.clone.p.y - 40, 240, 0.9))
	var fires := _split(fire_lights(), view.grow(FIRE_MARGIN), reach, centre)
	var warn := _split(zone_lights(), view, reach, centre)
	var shots := _split(shot_lights(), view, reach, centre)
	var mobs := _split(mob_lights(), view, reach, centre)
	var magic := _split(magic_lights(), view, reach, centre)
	var fight := int(SHARES.fight)
	var bodies := int(SHARES.mobs)
	_take(out, fires[0], most, most)
	_take(out, lava_lights(view), most, int(SHARES.lava))
	fight -= _take(out, (warn[0] as Array) + (shots[0] as Array), most, fight)
	bodies -= _take(out, mobs[0], most, bodies)
	_take(out, magic[0], most, most)
	_take(out, fires[1], most, most)
	_take(out, (warn[1] as Array) + (shots[1] as Array), most, fight)
	_take(out, mobs[1], most, bodies)
	_take(out, magic[1], most, most)
	_take(out, exit_lights(reach, centre), most, most)
	return out


## Appends up to `n` of `list` while `out` holds fewer than `most`; how many it took.
static func _take(out: Array, list: Array, most: int, n: int) -> int:
	var took := 0
	for l: Vector4 in list:
		if took >= n or out.size() >= most:
			break
		out.append(l)
		took += 1
	return took


## The lights of `list` inside `near` and those in the rest of `reach`, each
## nearest `centre` first: [near, margin].
static func _split(list: Array, near: Rect2, reach: Rect2, centre: Vector2) -> Array:
	var a: Array = []
	var b: Array = []
	for l: Vector4 in list:
		if l.z <= 0.5 or l.w <= 0.01:
			continue
		var p := Vector2(l.x, l.y)
		if near.has_point(p):
			a.append(l)
		elif reach.has_point(p):
			b.append(l)
	var by := func(x: Vector4, y: Vector4) -> bool: return Vector2(x.x, x.y).distance_squared_to(centre) < Vector2(y.x, y.y).distance_squared_to(centre)
	a.sort_custom(by)
	b.sort_custom(by)
	return [a, b]


## Everything that flies, bursts or burns in a fight (warnings and impacts, shots).
func combat_lights() -> Array:
	return zone_lights() + shot_lights()


## The hero's shots, skills and effect sheets and the enemy shots.
func shot_lights() -> Array:
	var out: Array = []
	var hero: Variant = g.story_hero
	if hero != null:
		var kit: Variant = hero.skill_fx
		var crypt: Array = []
		crypt.append_array(hero.attack.lights(hero.get("_snapshot"), func(b: Dictionary) -> Vector2: return Vector2(float(b.x), float(b.y))))
		crypt.append_array(kit.skill.lights(kit.snapshot))
		# the effect sheets: the skills' and the feel's (one FxSprites: story_feel uses the kit's)
		crypt.append_array(kit.fx.lights())
		for b: Dictionary in kit.bullets:
			var l := bullet_light(str(b.get("style", "")), Vector2(float(b.x), float(b.y)))
			if l.z > 0.0: crypt.append(l)
		for l: Vector4 in crypt:
			out.append(_world(l))
	for item: Dictionary in shot_items(true):
		var l := bullet_light(str(item.bullet.style), (item.p as Vector2) / scale)
		if l.z > 0.0: out.append(_world(l))
	return out


## The crypt's light of a flying bullet (crypt units; zero when its style casts none).
static func bullet_light(style: String, point: Vector2) -> Vector4:
	if not BULLET_LIGHT.has(style):
		return Vector4.ZERO
	return Vector4(point.x, point.y, float(BULLET_LIGHT[style][0]), float(BULLET_LIGHT[style][1]))


## Attack zones, telegraphs, impacts, beams and the transformation glow, the
## world's own zones and blasts.
func zone_lights() -> Array:
	var out: Array = []
	# zones in boss_fx.gd's terms (crypt units): its strike / pool / vortex light rule
	var crypt: Array = []
	if g.monsters != null:
		var puddles: Array = []
		for z: Dictionary in g.monsters.zones:
			var p: Vector2 = z.p
			var t := float(z.t)
			var tele := float(z.tele)
			match str(z.kind):
				"meteor", "hand":
					if t >= 0.0 and t < tele:
						# a meteor of the crypt's poison or frost lights in its element, the hell's in fire
						var lit := str(z.get("c", "")) if str(z.get("c", "")) in ["poison", "frost"] else "fire"
						crypt.append(_crypt_zone(p, float(z.r), "void" if z.kind == "hand" or z.get("void", false) else lit, "strike"))
					elif t >= tele:
						# the impact flares and fades
						var k := clampf((t - tele) / maxf(0.01, float(z.T) - tele), 0.0, 1.0)
						out.append(Vector4(p.x, p.y - 20.0, float(z.r) * _size("impact") * (1.0 - k), 1.0 - k))
				"erupt", "land":
					if t < tele:
						crypt.append(_crypt_zone(p, float(z.r), "fire", "strike"))
				"wave":
					var k := minf(1.0, t / maxf(0.01, float(z.T)))
					out.append(Vector4(p.x, p.y, float(z.r) * maxf(k, 0.2), 0.6 * (1.0 - 0.5 * k)))
				"puddle":
					# magma glows; a puddle of poison (the crypt's pool figures) does not
					if str(z.get("st", "lava")) == "lava":
						puddles.append(_puddle(z))
				"arc":
					# a swing glows as its blade's slash (rig_renderer.gd); only a full spin lights its middle
					if float(z.arc) >= 5.0:
						out.append(Vector4(p.x, p.y, float(z.r) * 0.8, 0.45 * (1.0 - t / maxf(0.01, float(z.T)))))
				"line":
					var dir := Vector2.from_angle(float(z.ang))
					var k := 0.0 if t < tele else clampf((t - tele) / maxf(0.01, float(z.T) - tele), 0.0, 1.0)
					for f: float in [0.25, 0.75]:
						var q := p + dir * float(z.len) * f
						out.append(Vector4(q.x, q.y, float(z.len) * 0.3, 0.5 * (1.0 - k)))
				"cone":
					var dir := Vector2.from_angle(float(z.ang))
					var q := p + dir * float(z.r) * 0.5
					out.append(Vector4(q.x, q.y, float(z.r) * 0.5, 0.5))
		# magma puddles: skill_fx.gd's own lava zone light
		for l: Vector4 in _skill.lights({"skill_fx": {"zones": puddles}}):
			out.append(_world(l))
		for L: Dictionary in g.monsters.lobs:
			crypt.append(_crypt_zone(L.to, float(L.r), "fire", "strike"))
		for m: Dictionary in g.mobs:
			# Ignaroth 4's void beams: rig_renderer.gd's beam rule (68 crypt px), 4 lights a beam
			for seg: Array in beam_segments(m):
				for i in range(1, 5):
					var q: Vector2 = (seg[0] as Vector2).lerp(seg[1], i / 4.0)
					out.append(Vector4(q.x, q.y, BEAM_LIGHT * scale, 1.0))
			var heat := float(g.monsters._glow(m))
			if heat > 0.0:
				out.append(Vector4(m.p.x, m.p.y - m.cy - m.alt, float(m.def.w) * float(m.s) * _size("transform"), heat))
		# a laser's wall burn lights the wall while it burns and glows on
		for s: Dictionary in g.monsters.scorches:
			out.append(Vector4(s.p.x, s.p.y - 12.0, BEAM_LIGHT * scale * 0.8, float(g.monsters.scorch_heat(s))))
		# a wall of flames out of a split floor lights it all along while it burns (spikes of bone or frost do not)
		for w: Dictionary in g.monsters.firewalls:
			if str(w.get("c", "fire")) in ["bone", "frost"]:
				continue
			var k := clampf(float(w.t) / maxf(0.01, float(w.T)), 0.0, 1.0)
			var heat := clampf(k / 0.1, 0.0, 1.0) * (1.0 - clampf((k - 0.45) / 0.55, 0.0, 1.0))
			var d := 0.0
			while d < float(w.len):
				var q: Vector2 = (w.p as Vector2) + (w.dir as Vector2) * d
				out.append(Vector4(q.x, q.y - 20.0, BEAM_LIGHT * scale * 0.9, heat))
				d += 70.0
		# an attack's impact flash lights its surroundings for that moment
		for f: Dictionary in g.monsters.flashes:
			var fade := 1.0 - clampf(float(f.t) / maxf(0.01, float(f.T)), 0.0, 1.0)
			out.append(Vector4(f.p.x, f.p.y - 10.0, float(f.r) * 2.2, fade))
	for z: Dictionary in g.state.get("mzones", []):
		var p: Vector2 = z.p
		match str(z.kind):
			"strike", "pool":
				crypt.append(_crypt_zone(p, float(z.r), str(z.get("style", "ice")), str(z.kind)))
			"lane":
				for f: float in [0.25, 0.75]:
					var q: Vector2 = p.lerp(z.q, f)
					out.append(Vector4(q.x, q.y, maxf(float(z.w), 80.0), 0.45))
			"cone":
				var q := p + Vector2.from_angle(float(z.a)) * float(z.r) * 0.5
				out.append(Vector4(q.x, q.y, float(z.r) * 0.5, 0.45))
	# the world's own zones (boss kits, the hero's, relics' and subclasses' skills)
	for z: Dictionary in g.zones:
		var spec := world_zone(z)
		if spec.has("kind"):
			crypt.append(_crypt_zone(z.p, float(z.r), str(spec.style), str(spec.kind)))
	for l: Vector4 in _boss_fx.lights({"boss_zones": crypt}):
		out.append(_world(l))
	# strikes and the world's skill blasts flare and fade
	for f: Dictionary in _flares:
		var k := clampf(float(f.t) / maxf(0.01, float(f.T)), 0.0, 1.0)
		var p: Vector2 = f.p
		out.append(Vector4(p.x, p.y - 20.0, float(f.r) * _size(str(f.kind)) * (1.0 - k), float(_spec(str(f.kind)).get("light", 1.0)) * (1.0 - k)))
	for f: Dictionary in world_fx():
		var spec := _spec(str(f.bloom))
		if spec.has("light") and f.has("r"):
			var p: Vector2 = f.p
			out.append(Vector4(p.x, p.y, float(f.r) * _size(str(f.bloom)) * float(f.k), float(spec.light) * float(f.k)))
	return out


## One zone in boss_fx.gd's snapshot terms (crypt units).
func _crypt_zone(p: Vector2, r: float, style: String, kind: String) -> Dictionary:
	return {"x": p.x / scale, "y": p.y / scale, "r": r / scale, "st": style, "k": kind}


## A magma puddle as the crypt's lava zone (skill_fx.gd snapshot terms, crypt units).
func _puddle(z: Dictionary) -> Dictionary:
	var p: Vector2 = z.p
	return {"kind": "lava", "x": p.x / scale, "y": p.y / scale, "r": float(z.r) / scale, "t": maxf(0.0, float(z.T) - float(z.t)), "id": int(p.x)}


## The world's skill blasts the crypt bridge does not draw (story_skill_fx.gd
## handles_fx): [{p, r?, k (1 fresh .. 0 gone), bloom kind, fx}] world px.
func world_fx() -> Array:
	var out: Array = []
	var table: Dictionary = data.get("world_fx", {})
	for f: Dictionary in g.fx:
		var kind := str(table.get(str(f.get("kind", "")), ""))
		if kind == "" or (g.story_hero != null and g.story_hero.handles_fx(f)):
			continue
		if kind == "blast" and f.get("gravity", false):
			kind = "blast_gravity"
		var item := {"p": f.p, "k": clampf(float(f.t) / maxf(0.01, float(f.get("max", 1.0))), 0.0, 1.0), "bloom": kind, "fx": f}
		if f.has("r"):
			item.r = float(f.r)
		out.append(item)
	return out


## The burning void beams of a monster (warnings excluded): [[from, to], ...] world px.
func beam_segments(m: Dictionary) -> Array:
	var out: Array = []
	var A: Variant = m.get("act")
	if g.monsters == null or not (A is Dictionary) or str(A.kind) != "beam" or bool(A.get("warn", false)):
		return out
	# from the drawn core, as far as the beam reaches (its range, else 1100 px)
	var head: Vector2 = g.monsters._beam_head(m)
	var reach := float((A.get("a", {}) as Dictionary).get("range", 1100.0))
	var laser := str((A.get("a", {}) as Dictionary).get("style", "")) == "laser"
	for b: float in A.get("beams", []):
		var len := float(g.monsters._beam_reach(head, b, reach) if laser else g.monsters._wall_len(head, b, reach))
		out.append([head, head + Vector2.from_angle(b) * len])
	return out


## The monsters: the world's own rule (its old darkness: hell monsters carry
## their light, the Frostgruft's a smaller one); a frost whirl lights its pull
## like boss_fx.gd's vortex.
func mob_lights() -> Array:
	var out: Array = []
	var crypt: Array = []
	for m: Dictionary in g.mobs:
		if g.monsters != null:
			var reach: float = 90.0 + float(m.r) * 2.2 * (1.3 if str(m.def.get("kind", "")) == "lord" else 1.0)
			out.append(Vector4(m.p.x, m.p.y - m.cy - m.alt, reach, 1.0))
		elif str((m.def as Dictionary).get("behavior", "")) == "puller":
			crypt.append(_crypt_zone(m.p, float(m.def.get("pull_radius", 300.0)) * _size("pull"), "frost", "vortex"))
		else:
			out.append(Vector4(m.p.x, m.p.y - 40.0 * m.s, 120.0 * m.s, 0.8))
	for l: Vector4 in _boss_fx.lights({"boss_zones": crypt}):
		out.append(_world(l))
	return out


## Lava banks nearest the hero (theme "glow".liquid; none where it gives no light).
func lava_lights(view: Rect2) -> Array:
	var spec := liquid()
	if float(spec.light_radius) <= 0.0 or float(spec.light_strength) <= 0.0:
		return []
	var me := Vector2(g.player.x, g.player.y)
	var cells := lava_edges(view.grow(float(g.C) * 2.0))
	cells.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.distance_squared_to(me) < b.distance_squared_to(me))
	var out: Array = []
	var picked: Array = []
	for c: Vector2 in cells:
		if out.size() >= int(SHARES.lava):
			break
		# one light per two cells of bank
		if picked.any(func(o: Vector2) -> bool: return o.distance_to(c) < float(g.C) * 1.9):
			continue
		picked.append(c)
		out.append(Vector4(c.x, c.y, float(spec.light_radius), float(spec.light_strength)))
	return out


## The map's fires (each map light; a lit puzzle brazier joins them).
func fire_lights() -> Array:
	var out: Array = []
	var reach_scale := float(flames.get("light_radius_scale", 1.0))
	for li: Dictionary in g.W.lights:
		out.append(Vector4(li.x, li.y, float(li.r) * reach_scale, 0.95))
	return out


## The map's magic: awake portals, the closed vault, bursting vents, unbroken
## seals (the world's own lights, vfx_glow.json story.bloom "light").
func magic_lights() -> Array:
	var out: Array = []
	# the light's height over the thing's feet (world px), and when it shines
	var lifts := {"portal": 60.0, "vault": 80.0, "vent": 30.0, "seal": 50.0}
	for e: Dictionary in g.W.ents:
		var kind := str(e.type)
		if not lifts.has(kind):
			continue
		var on: bool = {"portal": e.get("active", false), "vault": not e.get("opened", false), "vent": e.get("burst", false), "seal": not e.get("broken", false)}[kind]
		var light: Array = _spec(kind).get("light", [])
		if on and light.size() == 2:
			out.append(Vector4(e.x, e.y - float(lifts[kind]), float(light[0]), float(light[1])))
	return out


## The exits in `area` by the crypt's exit light: closed doors and the walls'
## glowing posts, those closer than EXIT_MERGE merged, nearest `centre` first.
func exit_lights(area: Rect2, centre: Vector2) -> Array:
	var points: Array = []
	for d: Dictionary in g.W.doors:
		if str(d.kind) != "secret" and g._door_closed(d):
			points.append(Vector2(d.cx, d.cy))
	var post_h := _tex_height("wall_h_glowpost", 96.0)
	for p: Vector2 in g.walls.get("posts", []):
		points.append(p - Vector2(0, post_h * 0.5))
	var groups: Array = []
	for p: Vector2 in points:
		if not area.has_point(p):
			continue
		var joined := false
		for grp: Array in groups:
			if (grp[0] / float(grp[1])).distance_to(p) < EXIT_MERGE:
				grp[0] += p
				grp[1] += 1
				joined = true
				break
		if not joined:
			groups.append([p, 1])
	var out: Array = []
	for grp: Array in groups:
		var p: Vector2 = grp[0] / float(grp[1])
		out.append(Vector4(p.x, p.y, EXIT_LIGHT.x * scale, EXIT_LIGHT.y))
	out.sort_custom(func(a: Vector4, b: Vector4) -> bool: return Vector2(a.x, a.y).distance_squared_to(centre) < Vector2(b.x, b.y).distance_squared_to(centre))
	return out


## Every map light (fires, magic, exits) in `area`, unbudgeted.
func map_lights(area := Rect2(-1e9, -1e9, 2e9, 2e9)) -> Array:
	return fire_lights() + magic_lights() + exit_lights(area, area.get_center())


## A crypt-unit light in world px.
func _world(l: Vector4) -> Vector4:
	return Vector4(l.x * scale, l.y * scale, l.z * scale, l.w)


# --- vfx_glow.json story.bloom ----------------------------------------------------------

func _spec(kind: String) -> Dictionary:
	return bloom.get(kind, {})


## A bloom kind's radius in crypt px.
func _r(kind: String) -> float:
	return float(_spec(kind).get("r", 0.0))


## A bloom kind's radius as a share of the thing's own size.
func _size(kind: String) -> float:
	return float(_spec(kind).get("size", 1.0))


func _alpha(kind: String) -> float:
	return float(_spec(kind).get("alpha", 0.0))


func _color(kind: String, fallback := Color.WHITE) -> Color:
	var s := _spec(kind)
	return Color.html(str(s.color)) if s.has("color") else fallback


# --- the map --------------------------------------------------------------------------

## The theme's lava glow (theme "glow".liquid; the world's old lava light and an
## orange glow when the theme names none).
func liquid() -> Dictionary:
	var spec := {"light_radius": 230.0, "light_strength": 0.75, "color": "#ff6b1a", "alpha": 0.32}
	spec.merge(look.get("liquid", {}), true)
	return spec


## The lava banks inside `area` (world px): for every lava cell that touches the
## floor, a point on its edge to each floor side, just inside the lava (where the
## glow spills onto the bank). Its bloom dots (lava_items, 1.2 cells) reach 0.7
## cells into the river, so a narrow river glows across; a wide one keeps its
## middle as the texture paints it.
func lava_edges(area: Rect2) -> Array:
	var out: Array = []
	var c := float(g.C)
	for y in range(int(floor(area.position.y / c)), int(area.end.y / c) + 1):
		for x in range(int(floor(area.position.x / c)), int(area.end.x / c) + 1):
			if g._cell(x, y) != 2:
				continue
			for n: Vector2i in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
				if g._cell(x + n.x, y + n.y) == 1:
					out.append(Vector2((x + 0.5) * c, (y + 0.5) * c) + Vector2(n) * c * 0.48)
	return out


## The flame class of a map light by its radius (FLAME_CLASSES; [] for a rune light).
static func flame_class(radius: float) -> Array:
	for cls: Array in FLAME_CLASSES:
		if radius >= float(cls[0]):
			return cls
	return []


## The bloom colour of a map light: the theme's flame colour, else its own "r,g,b".
func flame_color(li: Dictionary) -> Color:
	if not flames.is_empty():
		return flames.light_color
	var parts := str(li.get("c", "255,140,60")).split(",")
	if parts.size() < 3:
		return Color(1.0, 0.62, 0.28)
	return Color8(int(parts[0]), int(parts[1]), int(parts[2]))


## The map's bloom this frame: [{p, r, color, kind}] in world px (the colour's
## alpha is the intensity, the vfx_glow.json level included); crypt loot items
## carry "crypt": "loot" and are drawn by skill_fx.gd.
func map_items() -> Array:
	var out: Array = []
	var t := clock()
	var near: Rect2 = g._view_rect().grow(FIRE_MARGIN)
	var torches := glow.level("torches")
	var spells := glow.level("spells")
	# fires: the same fires that lights() lights before the fight, so bloom and light agree
	var boost := float(flames.get("glow_strength", 0.2)) / 0.2 if not flames.is_empty() else 1.0
	for li: Dictionary in g.W.lights:
		var p := Vector2(li.x, li.y)
		if not near.has_point(p):
			continue
		var cls := flame_class(float(li.r))
		var phase := float(li.get("f", p.x * 0.01))
		if cls.is_empty():
			# the story worlds' own slow rune glow
			var a := _alpha("rune") + 0.04 * sin(t * 2.0 + phase)
			_add(out, p, _r("rune") * scale, Color(flame_color(li), a * boost * torches), "flame_rune")
		else:
			var r := float(cls[1]) + 3.0 * sin(t * float(cls[3]) + phase)
			_add(out, p, r * scale, Color(flame_color(li), float(cls[2]) * boost * torches), "flame_" + str(cls[4]))
	for e: Dictionary in g.W.ents:
		var p := Vector2(e.x, e.y)
		if not near.has_point(p) or e.get("taken", false):
			continue
		match str(e.type):
			"portal":
				if e.get("active", false):
					var c := _look_color("portal", g.col("accent"))
					var mid := p - Vector2(0, _tex_height("portal", 120.0) * 0.5)
					_add(out, mid, _r("portal") * scale, Color(c, (_alpha("portal") + 0.05 * sin(t * 3.0)) * spells), "portal")
					_add(out, mid, _r("portal_core") * scale, Color(c.lightened(0.4), _alpha("portal_core") * spells), "portal")
			"vault":
				if not e.get("opened", false):
					var h := _tex_height("chest_gold", 48.0) * 1.9
					out.append({"p": p - Vector2(0, h * 0.5), "kind": "loot", "crypt": "loot"})
			"key", "gem", "heart":
				var name := "rune_gem" if e.type == "gem" else (str(g.key_sprite.get(e.get("key", ""), "key")) if e.type == "key" else str(e.type))
				var s := 0.9 if e.type == "key" else (0.55 if e.type == "gem" else 0.7)
				var h := _tex_height(name, 48.0) * s
				var bob := sin(t * 3.0 + float(e.x)) * 6.0
				out.append({"p": p - Vector2(0, h * 0.5 + 10.0 - bob), "kind": "loot", "crypt": "loot"})
			"relic":
				if g.relic_tex != null and RelicKit.relic_free(g, e):
					_add(out, p - Vector2(0, 40.0 - sin(t * 2.0) * 8.0), _r("relic") * scale, Color(_color("relic"), _alpha("relic") * spells), "relic")
			"seal":
				if not e.get("broken", false):
					var h := _tex_height("demon_plate", 64.0) * 1.15
					_add(out, p - Vector2(0, h * 0.5), _r("seal") * scale, Color(_color("seal"), (_alpha("seal") + 0.1 * sin(t * 4.0 + float(e.x))) * spells), "seal")
			"plate":
				if e.get("on", false):
					_add(out, p, _r("plate") * scale, Color(_color("plate"), (_alpha("plate") + 0.05 * sin(t * 5.0)) * spells), "plate")
			"vent":
				if e.get("burst", false):
					var c: Color = flames.light_color if not flames.is_empty() else _color("vent")
					_add(out, p - Vector2(0, 30), _r("vent") * scale, Color(c, _alpha("vent") * torches), "vent")
	# gates that hold a fight or the boss pulse like their bars
	var gate_color := _look_color("gate", _color("gate"))
	for d: Dictionary in g.W.doors:
		var p := Vector2(d.cx, d.cy)
		if str(d.kind) == "secret" or not near.has_point(p) or not g._door_closed(d):
			continue
		if g.W.rooms[d.a].fight or g.W.rooms[d.b].fight or str(d.kind) == "boss":
			_add(out, p, _r("gate") * scale, Color(gate_color, (_alpha("gate") + 0.1 * (0.5 + 0.5 * sin(t * 5.0))) * spells), "gate")
	# the walls' glowing slits and door posts
	var wall_color := _look_color("wall", g.col("accent"))
	var post_h := _tex_height("wall_h_glowpost", 96.0)
	for p: Vector2 in g.walls.get("posts", []):
		var mid := p - Vector2(0, post_h * 0.5)
		if near.has_point(mid):
			_add(out, mid, _r("wall_post") * scale, Color(wall_color, _alpha("wall_post") * torches), "wall")
	for s: Dictionary in g.walls.get("side", []):
		if s.get("glow", false) and near.has_point(Vector2(s.x + 31, s.y)):
			_add(out, Vector2(s.x + 31, s.y), _r("wall_slit") * scale, Color(wall_color, _alpha("wall_slit") * torches), "wall")
	out.append_array(lava_items())
	# embers glow like the crypt's (particles.gd draw_glow), unless a front wall hides them
	var particles := glow.level("particles")
	for ember: Dictionary in g.embers:
		var p: Vector2 = ember.p
		if not near.has_point(p) or behind_wall(p):
			continue
		var heat := minf(1.0, float(ember.t) * 2.0)
		var c: Color = g.col("ember_gold") if ember.gold else (g.col("ember_big") if ember.big else g.col("ember"))
		_add(out, p, (EMBER_GLOW.x + EMBER_GLOW.y * heat) * (1.6 if ember.big else 1.0) * scale, Color(c, EMBER_GLOW.z * heat * particles), "ember")
	return out


## Bloom of the lava banks in view: a band of soft light along every edge where
## the river meets the floor (lava_edges; dots of story.bloom.lava_bank cells).
## Its pulse is skill_fx.gd's lava zone's.
func lava_items() -> Array:
	var out: Array = []
	var spec := liquid()
	var alpha := float(spec.alpha) * glow.level("lava")
	if alpha <= 0.0:
		return out
	var color := Color.html(str(spec.color))
	var t := clock()
	var c := float(g.C)
	for p: Vector2 in lava_edges(g._view_rect().grow(c)):
		var cell := Vector2i(int(p.x / c), int(p.y / c))
		var id := float(absi(cell.x * 73 + cell.y * 37) % 97)
		# neighbouring bank dots overlap: each carries a share of the theme's alpha
		_add(out, p, c * _size("lava_bank"), Color(color, (alpha + 0.06 * sin(t * 9.0 + id)) * _alpha("lava_bank") * clampf(alpha / 0.32, 0.0, 1.0)), "lava")
	return out


func _look_color(key: String, fallback: Color) -> Color:
	return Color.html(str(look[key])) if look.has(key) else fallback


func _tex_height(name: String, fallback: float) -> float:
	var t: Variant = g.tex.get(name)
	return (t as Texture2D).get_height() if t is Texture2D else fallback


## True when a front wall (the hell's south wall strips, drawn over the actors)
## covers world point `p`.
func behind_wall(p: Vector2) -> bool:
	if not is_same(_walls_seen, g.walls):
		_build_covers()
	var c := float(g.C)
	var spans: Variant = _covers.get(Vector2i(floori(p.x / c), floori(p.y / c)))
	if spans == null:
		return false
	for s: Vector2 in spans:
		if p.y >= s.x and p.y < s.y:
			return true
	return false


func _build_covers() -> void:
	_walls_seen = g.walls
	_covers = {}
	var c := float(g.C)
	var h := _tex_height("wall_h", c)
	for w: Dictionary in g.walls.get("south", []):
		var y0 := float(w.y)
		for cy in range(floori(y0 / c), floori((y0 + h - 0.01) / c) + 1):
			for cx in range(floori(float(w.x0) / c), ceili(float(w.x1) / c)):
				var key := Vector2i(cx, cy)
				if not _covers.has(key):
					_covers[key] = []
				(_covers[key] as Array).append(Vector2(y0, y0 + h))


# --- shots ----------------------------------------------------------------------------

## Enemy shots, lobs and falling meteors as crypt bullets: [{bullet, p}] (world
## px). Empty while the bullets' bloom is off, unless `all` (their light does not
## depend on the bloom).
func shot_items(all := false) -> Array:
	var out: Array = []
	if not all and glow.level("bullets") <= 0.0:
		return out
	for s: Dictionary in g.eshots:
		# a breath's flames glow as their own pixels (hell_monsters.gd _breath_fx)
		if s.get("breath", false):
			continue
		var style := ""
		var element := ""
		if s.has("c"):
			var c := str(s.c)
			if c == "chain":
				continue
			style = "magic" if c == "fire" and s.get("small", false) else str(HELL_STYLES.get(c, "fireball"))
			element = str(HELL_ELEMENTS.get(c, ""))
		elif s.has("style"):
			style = str(MOVE_STYLES.get(str(s.style), ""))
			element = str(MOVE_ELEMENTS.get(str(s.style), ""))
		else:
			# the Frostgruft's plain enemy shots (shooters, crystals, guardians): violet
			# magic like their drawn colour; Hrimgar's fist is the crypt's fist
			style = "fist" if s.get("fist", false) else "magic"
			element = "storm"
		if style == "":
			continue
		# the pulse phase follows the shot's flight (no mark on the world's shot)
		_shot(out, s.p, style, element, hash(s.get("v", Vector2.ZERO)))
	if g.monsters != null:
		for L: Dictionary in g.monsters.lobs:
			# a thrown boulder is dark rock, no fireball glow
			if str(L.get("look", "")) == "boulder":
				continue
			var k := clampf(float(L.t) / maxf(0.01, float(L.T)), 0.0, 1.0)
			# a lob of the crypt's elements glows as its shots do (a bone does not glow), the hell's as a fireball
			var lc := str(L.get("c", "fire"))
			var lob_style := str(HELL_STYLES.get(lc, "fireball")) if lc in CRYPT_ELEMENTS else "fireball"
			if lob_style != "":
				_shot(out, (L.from as Vector2).lerp(L.to, k) - Vector2(0, sin(k * PI) * 220.0), lob_style, str(HELL_ELEMENTS.get(lc, "")) if lc in CRYPT_ELEMENTS else "", int(L.to.x))
		for z: Dictionary in g.monsters.zones:
			if str(z.kind) == "meteor" and float(z.t) >= 0.0 and float(z.t) < float(z.tele):
				var my: float = z.p.y - 900.0 * (1.0 - float(z.t) / float(z.tele))
				var mc := str(z.get("c", ""))
				if mc in CRYPT_ELEMENTS and not z.get("void", false):
					if str(HELL_STYLES.get(mc, "")) != "":
						_shot(out, Vector2(z.p.x, my), str(HELL_STYLES[mc]), str(HELL_ELEMENTS.get(mc, "")), int(z.p.x))
					continue
				_shot(out, Vector2(z.p.x, my), "void_skull" if z.get("void", false) else "fireball", "", int(z.p.x))
	for z: Dictionary in g.state.get("mzones", []):
		if str(z.kind) == "strike" and z.has("from"):
			var k := 1.0 - float(z.t) / maxf(0.01, float(z.get("max", 1.0)))
			var style := str(MOVE_STYLES.get(str(z.get("style", "ice")), "shard"))
			_shot(out, (z.from as Vector2).lerp(z.p, k) - Vector2(0, sin(k * PI) * 160.0), style, str(MOVE_ELEMENTS.get(str(z.style), "")), int(z.p.x))
	return out


func _shot(out: Array, p: Vector2, style: String, element: String, id: int) -> void:
	out.append({"bullet": {"style": style, "element": element, "id": id % 100000, "owner": 0}, "p": p})


# --- the monsters' attacks ------------------------------------------------------------

## Bloom of the attacks and the world's skill blasts: dots {p, r, color, kind},
## bands {p, to, w, color, kind} in world px; magma puddles {p, kind, crypt:
## "lava", zone} are drawn by skill_fx.gd.
func attack_items() -> Array:
	var out: Array = []
	var t := clock()
	var spells := glow.level("spells")
	var void_level := glow.level("void")
	if g.monsters != null:
		for z: Dictionary in g.monsters.zones:
			var p: Vector2 = z.p
			var zt := float(z.t)
			var tele := float(z.tele)
			var span := maxf(0.01, float(z.T) - tele)
			match str(z.kind):
				"meteor", "hand":
					if zt >= tele:
						var k := clampf((zt - tele) / span, 0.0, 1.0)
						var kind := "impact_void" if z.kind == "hand" or z.get("void", false) else "impact"
						if kind == "impact" and bloom.has("impact_" + str(z.get("c", ""))):
							kind = "impact_" + str(z.c)
						_add(out, p - Vector2(0, 20), float(z.r) * _size(kind), Color(_color(kind), _alpha(kind) * (1.0 - k) * spells), "impact")
				"wave":
					var k := minf(1.0, zt / maxf(0.01, float(z.T)))
					var kind := "wave_" + str(z.get("c", "")) if bloom.has("wave_" + str(z.get("c", ""))) else "wave"
					_add(out, p, float(z.r) * _size(kind) * maxf(k, 0.15), Color(_color(kind), _alpha(kind) * (1.0 - k) * spells), "wave")
				"arc":
					# no straight band toward the aim: the swing is drawn as the blade's slash
					pass
				"line":
					if zt >= tele:
						var k := clampf((zt - tele) / span, 0.0, 1.0)
						var slam := "slam_" + str(z.get("c", "")) if bloom.has("slam_" + str(z.get("c", ""))) else "slam"
						_band(out, p, p + Vector2.from_angle(float(z.ang)) * float(z.len), float(z.w) * _size(slam), Color(_color(slam), _alpha(slam) * (1.0 - k) * spells), "slam")
				"cone":
					if zt >= tele:
						var k := clampf((zt - tele) / span, 0.0, 1.0)
						var reach := float(z.r) * (0.4 + 0.6 * k)
						_band(out, p, p + Vector2.from_angle(float(z.ang)) * reach, reach * _size("scream"), Color(_color("scream"), _alpha("scream") * (1.0 - k) * spells), "scream")
						_add(out, p, _r("scream_mouth") * scale, Color(_color("scream_mouth"), _alpha("scream_mouth") * (1.0 - k) * spells), "scream")
				"puddle":
					# skill_fx.gd's own lava zone glow (a poison puddle of the crypt does not glow)
					if str(z.get("st", "lava")) == "lava":
						out.append({"p": p, "kind": "puddle", "crypt": "lava", "zone": _puddle(z)})
		for m: Dictionary in g.mobs:
			# Ignaroth 4's void beams: a wide violet halo, a bright core, a flare at the mouth;
			# a pixel laser (the Blutfledermaus) the same in red, at the spells level
			var segs := beam_segments(m)
			var laser := str(((m.act if m.act is Dictionary else {}) as Dictionary).get("a", {}).get("style", "")) == "laser"
			var pre := "laser" if laser else "beam"
			var level := spells if laser else void_level
			for seg: Array in segs:
				var surge := 0.9 + 0.1 * sin(t * 24.0)
				for kind: String in [pre + "_halo", pre + "_core"]:
					_band(out, seg[0], seg[1], _r(kind) * scale, Color(_color(kind), _alpha(kind) * surge * level), "beam")
			if not segs.is_empty():
				_add(out, segs[0][0], _r(pre + "_mouth") * scale, Color(_color(pre + "_mouth"), _alpha(pre + "_mouth") * level), "beam")
			# the transformation and the dying glow
			var heat := float(g.monsters._glow(m))
			var mid: Vector2 = m.p - Vector2(0, m.cy + m.alt)
			var w := float(m.def.w) * float(m.s)
			if heat > 0.0:
				for kind: String in ["transform", "transform_core"]:
					_add(out, mid, w * _size(kind), Color(_color(kind), _alpha(kind) * heat * spells), "transform")
			if m.has("echo"):
				_add(out, mid, w * _size("echo"), Color(_color("echo"), _alpha("echo") * void_level), "echo")
	else:
		var mobs_level := glow.level("mobs")
		for m: Dictionary in g.mobs:
			var mid: Vector2 = (m.p as Vector2) - Vector2(0, m.cy)
			# the enemy moves' ice armour
			if float(m.get("armor_t", 0.0)) > 0.0:
				_add(out, mid, (float(m.r) * 1.3 + 10.0) * _size("armor"), Color(_color("armor"), _alpha("armor") * spells), "armor")
			var def: Dictionary = m.get("def", {})
			# a frost whirl's pull, faint over its whole reach
			if str(def.get("behavior", "")) == "puller":
				_add(out, m.p, float(def.get("pull_radius", 300.0)) * _size("pull"), Color(_color("pull"), _alpha("pull") * mobs_level), "pull")
			# a frost imp's dash leaves a cold streak
			if float(m.get("dash", 0.0)) > 0.0 and (m.get("dash_dir", Vector2.ZERO) as Vector2) != Vector2.ZERO:
				_band(out, mid, mid - (m.dash_dir as Vector2).normalized() * float(_spec("dash").get("length", 70.0)), _r("dash") * scale, Color(_color("dash"), _alpha("dash") * mobs_level), "dash")
			# the crystals that guard a guardian are bound to it by a cold thread
			var lord: Variant = m.get("guard_of")
			if lord is Dictionary and g.mobs.has(lord):
				var to: Vector2 = (lord.p as Vector2) - Vector2(0, lord.cy)
				_band(out, mid, to, _r("guard") * scale, Color(_color("guard"), _alpha("guard") * spells), "guard")
	# both worlds: the world's zones strike (an icicle's flare), its skills burst
	for f: Dictionary in _flares:
		var k := clampf(float(f.t) / maxf(0.01, float(f.T)), 0.0, 1.0)
		var kind := str(f.kind)
		_add(out, (f.p as Vector2) - Vector2(0, 20), float(f.r) * _size(kind), Color(_color(kind), _alpha(kind) * (1.0 - k) * spells), "strike")
	for f: Dictionary in world_fx():
		var kind := str(f.bloom)
		var c: Color = f.fx.c if (f.fx as Dictionary).get("c") is Color else _color(kind)
		var a := _alpha(kind) * float(f.k) * spells
		var p: Vector2 = f.p
		match str(f.fx.kind):
			"smash":
				_add(out, p + Vector2.from_angle(float(f.fx.a)) * float(f.r) * 0.6, float(f.r) * _size(kind), Color(c, a), kind)
			"charge", "lift":
				_add(out, p, _r(kind) * scale, Color(c, a), kind)
			_:
				if f.has("r"):
					_add(out, p, float(f.r) * _size(kind), Color(c, a), kind)
	return out


# --- the monsters' glowing parts ------------------------------------------------------

## The monsters' glowing parts (vfx_glow.json "story") where the world drew them
## this frame (mark()): [{p, r, color, kind}] world px. Felled monsters fade with
## their fall; a part behind a front wall stays dark.
func mob_items() -> Array:
	var out: Array = []
	var t := clock()
	var hell: bool = g.monsters != null
	var table: Dictionary = data.get("hell_monsters" if hell else "frost_mobs", {})
	var now := Engine.get_process_frames()
	for e: Array in _marks:
		if now - int(e[2]) > 1:
			continue
		var m: Dictionary = e[0]
		var drawn: Dictionary = e[1]
		var key := str(m.get("id", "")) if hell else str((m.get("look", {}) as Dictionary).get("sprite", ""))
		var corpse := not m.has("hp")
		var fade := 1.0 - clampf(float(m.get("t", 0.0)) / 0.75, 0.0, 1.0) if corpse else 1.0
		var seed := float(m.get("seed", 0.0))
		# the crypt's figures carry their glowing parts (krypta_monsters.json "glow", from their painted glow pixels)
		var parts: Array = table.get(key, [])
		if parts.is_empty() and hell and m.get("def") is Dictionary:
			parts = (m.def as Dictionary).get("glow", [])
		for part: Dictionary in parts:
			var a := float(part.get("alpha", 0.3)) * float(drawn.get("alpha", 1.0)) * fade
			if part.has("anim") and (corpse or str(m.get("anim", "")) not in part.anim):
				continue
			if part.has("act"):
				var A: Variant = m.get("act")
				if corpse or not (A is Dictionary) or str(A.kind) not in part.act:
					continue
				a *= clampf(float(A.get("t", 0.0)) / ACT_RAMP, 0.0, 1.0)
			if str(part.get("when", "")) == "dash" and float(m.get("dash", 0.0)) <= 0.0:
				continue
			var p := anchor(drawn, part.at)
			if not p.is_finite() or behind_wall(p):
				continue
			var r := float(part.r) * (drawn.size as Vector2).x / maxf(1.0, (drawn.src as Vector2).x)
			if part.has("flicker"):
				r *= 1.0 + 0.08 * sin(t * float(part.flicker) * TAU + seed)
			if part.has("pulse"):
				a *= 0.75 + 0.25 * sin(t * float(part.pulse) * TAU + seed)
			if part.has("charge") and not corpse:
				var ch: Dictionary = part.charge
				var left := float(m.get(str(ch.timer), 99.0))
				var within := float(ch.get("within", 0.6))
				if left < within:
					a = lerpf(a, float(ch.alpha) * float(drawn.get("alpha", 1.0)), 1.0 - maxf(left, 0.0) / within)
			_add(out, p, r, Color(Color.html(str(part.color)), a * glow.level(str(part.get("level", "mobs")))), key)
	return out


## A source pixel [x, y] of a drawn body (`drawn`: foot, size, src, face, lean,
## cut) in world px; INF while it is sunk below the cut. The body is drawn with
## its feet at `foot`, mirrored by `face` and leaning by `lean` around the feet.
static func anchor(drawn: Dictionary, at: Array) -> Vector2:
	var size: Vector2 = drawn.size
	var src: Vector2 = drawn.src
	var cut := float(drawn.get("cut", 0.0))
	var down := (float(at[1]) + 0.5) / src.y * size.y
	if down > size.y - cut:
		return Vector2.INF
	var local := Vector2(((float(at[0]) + 0.5) / src.x * size.x - size.x * 0.5) * float(drawn.get("face", 1.0)), -size.y + cut + down)
	return (drawn.foot as Vector2) + local.rotated(float(drawn.get("lean", 0.0)))


# --- drawing (crypt units on the bloom node) --------------------------------------------

func _add(out: Array, p: Vector2, r: float, color: Color, kind: String) -> void:
	if r >= 1.0 and color.a > 0.003:
		out.append({"p": p, "r": r, "color": color, "kind": kind})


func _band(out: Array, from: Vector2, to: Vector2, width: float, color: Color, kind: String) -> void:
	if width >= 1.0 and color.a > 0.003 and from.distance_to(to) >= 1.0:
		out.append({"p": from, "to": to, "w": width, "color": color, "kind": kind})


## Draws dots and bands; collects the crypt's own loot and lava zones and lets
## skill_fx.gd draw them (its draw_glow: loot 44 crypt px gold, lava 1.8 r).
func _draw_items(canvas: CanvasItem, items: Array, t: float) -> void:
	var loot: Array = []
	var lava: Array = []
	for item: Dictionary in items:
		match str(item.get("crypt", "")):
			"loot":
				var p: Vector2 = (item.p as Vector2) / scale
				# the crypt draws its loot glow 14 px above the point it is given
				loot.append({"x": p.x, "y": p.y + 14.0})
			"lava":
				lava.append(item.zone)
			_:
				if item.has("to"):
					Glow.line(canvas, (item.p as Vector2) / scale, (item.to as Vector2) / scale, float(item.w) / scale, item.color)
				else:
					Glow.dot(canvas, (item.p as Vector2) / scale, float(item.r) / scale, item.color)
	if not loot.is_empty() or not lava.is_empty():
		_skill.draw_glow(canvas, {"skill_fx": {"zones": lava}, "loot_chests": {"loot": loot}}, t, glow)


## The bloom node's source, in the crypt's order: the map, shots, the monsters'
## attacks and parts, then the hero kit (shots, skills, effect sheets, particles)
## and the feel's glowing particles.
func draw(canvas: CanvasItem) -> void:
	var t := clock()
	_draw_items(canvas, map_items(), t)
	var hero: Variant = g.story_hero
	if hero != null:
		var bullets := glow.level("bullets")
		for item: Dictionary in shot_items():
			if not behind_wall(item.p):
				hero.skill_fx.skill.bullet_glow(canvas, item.bullet, (item.p as Vector2) / scale, t, bullets)
	_draw_items(canvas, attack_items(), t)
	_draw_items(canvas, mob_items(), t)
	if hero != null:
		hero.attack.draw_glow(canvas, hero.get("_snapshot"), func(b: Dictionary) -> Vector2: return Vector2(float(b.x), float(b.y)), t, glow.level("bullets"))
		hero.skill_fx.draw_glow(canvas)
	if g.feel != null:
		# the feel works in its own crypt units (its scale is fixed when the world starts)
		var k := float(g.feel.scale) / scale
		if not is_equal_approx(k, 1.0):
			canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2(k, k))
		g.feel.feedback.particles.draw_glow(canvas, glow.level("particles"))
		canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
