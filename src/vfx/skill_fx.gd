extends RefCounted
## Draws hero skills, EXP orbs and ultimates from host snapshots (display only):
## ground effects under the actors (caltrops, poison and lava trails, storm
## fields, mirror images, EXP orbs), skill projectiles (blade wave, ballista
## bolt, Pfeilfaust, fireball, shards) and effects over the actors (whirl,
## chain lightning, blink, bursts, warnings, the Photoneneis beam, Rage aura and
## second blade, ballista charge line, shields, level-ups, wall rubble).

const ARROW := preload("res://assets/sprites/0x72/weapon_arrow.png")
const DECOY := preload("res://assets/sprites/0x72/wizzard_m_idle_anim_f0.png")
## A clone seal's clone looks like its hero's class.
const CLONE_LOOKS := {"swordsman": preload("res://assets/sprites/0x72/knight_m_idle_anim_f0.png"), "archer": preload("res://assets/sprites/0x72/elf_f_idle_anim_f0.png"), "mage": preload("res://assets/sprites/0x72/wizzard_m_idle_anim_f0.png")}
const PerkRules = preload("res://src/perk_rules.gd")
const SkillIcons = preload("res://src/ui/skill_icons.gd")
const PixelStyle = preload("res://src/pixel_style.gd")
const FxSprites = preload("res://src/vfx/fx_sprites.gd")
const Glow = preload("res://src/vfx/glow.gd")
const PixelPaint = preload("res://src/vfx/pixel_paint.gd")
const PixelBolt = preload("res://src/vfx/pixel_bolt.gd")
const PerfMarks = preload("res://src/debug/perf_marks.gd")
const CHEST_FRAMES := [preload("res://assets/sprites/0x72/chest_full_open_anim_f0.png"), preload("res://assets/sprites/0x72/chest_full_open_anim_f1.png"), preload("res://assets/sprites/0x72/chest_full_open_anim_f2.png")]
const CRATE := preload("res://assets/sprites/0x72/crate.png")
const BURSTS := {"fire": "fire_burst", "frost": "frost_burst", "arcane": "arcane_burst", "stone": "stone_burst", "void": "void_burst"}
const INK := Color("1a1414")
## Effect animations (FxSprites), set by the view.
var fx: RefCounted = null
## Pixel particles and floor marks (particles.gd), set by the view.
var particles: RefCounted = null
## The heroes' poison and lava zones as physics pools (src/vfx/pool_paint.gd,
## set by the host); null draws the old circles.
var pools: RefCounted = null
## The world's gas layer (src/vfx/gas.gd): poison zones give off fumes in it.
var gas: RefCounted = null
var _seen: Dictionary = {}
## The storm zones' pictures of the current beat (zone id -> {tick, at, picture}).
var _storm_pictures: Dictionary = {}
## Storm strikes already landed ("zone id:strike number"): each scorches once.
var _strikes: Dictionary = {}
## A storm zone strikes once every this many seconds (a bolt from the cloud).
const STORM_EVERY := 0.42
## Sparks of lightning: white-hot, blue, deep blue (PixelBolt.STORM).
const STORM_SPARKS := [Color("f4f6ff"), Color("8fa4ff"), Color("c8d4ff")]
var _rng := RandomNumberGenerator.new()
## Photoneneis per hero: start, strength and its last ends (kept to fade out).
var _beams: Dictionary = {}
## Seconds the beam takes to grow out of the hand, and to thin out after it ends.
const BEAM_GROW := 0.14
const BEAM_FADE := 0.35
## The beam leaves the hand this far above the hero's feet (world px).
const BEAM_LIFT := 12.0
## Particles per second from a burning beam.
const PHOTON_SPRAY := 70.0
## Ice sheath around a fire core, outermost first: [radius px, colour, motion]
## with motion 0 slow ice swell, 1 frost shimmer, 2 fast fire flicker, 3 steady.
const PHOTON_NAVY := Color("0e1a2e")
const PHOTON_ICE := Color("5fb4e6")
const PHOTON_FROST := Color("c6f1ff")
const PHOTON_FIRE := Color("ff6a1f")
const PHOTON_EMBER := Color("ffc94a")
const PHOTON_CORE := Color("fffbe6")
const PHOTON_LAYERS := [[19.0, PHOTON_NAVY, 0], [16.0, Color("23508c"), 0], [12.5, PHOTON_ICE, 0], [9.0, PHOTON_FROST, 1], [6.5, PHOTON_FIRE, 2], [4.0, PHOTON_EMBER, 2], [1.8, PHOTON_CORE, 3]]
const ELEMENT_TINTS := {"cinder": Color("f7b46b"), "venom": Color("b8d878"), "frost": Color("9bdde6"), "storm": Color("baabe9")}
var _chest_hits: Dictionary = {}
const GOLD_CRATE := preload("res://assets/sprites/items/crate_gold.png")
## Chest id -> clock when it was first seen open / chests seen at all.
var _chest_opened: Dictionary = {}
var _item_textures: Dictionary = {}
var _chest_seen: Dictionary = {}
var _open_reach := -1.0
var balance: Dictionary = {}
var local_class := ""
var local_point := Vector2.INF
## Id of the floor find nearest to the local hero (-1: none close); only it shows its name.
var nearest_loot := -1

const COLORS := {"fire": Color("f39a3c"), "frost": Color("8fd8e6"), "arcane": Color("b38cf0"), "stone": Color("c9b49a"), "void": Color("b06ad8")}


# --- Under the actors --------------------------------------------------------------

func draw_ground(canvas: CanvasItem, snapshot: Dictionary, clock: float) -> void:
	PerfMarks.begin()
	# Stairs on a boss floor stay barred until its boss has fallen.
	if not bool(snapshot.get("stairs_open", true)):
		for exit: Dictionary in snapshot.get("room_layout", {}).get("exits", []):
			if str(exit.get("kind", "")) != "stairs": continue
			var rect := Rect2(float(exit.rect[0]) - 8.0, float(exit.rect[1]) - 8.0, 48.0, 48.0)
			canvas.draw_rect(rect, Color(0.1, 0.05, 0.08, 0.45))
			for i in range(5):
				canvas.draw_rect(Rect2(rect.position.x + 4.0 + i * 9.0, rect.position.y - 4.0, 4.0, rect.size.y + 8.0), INK)
				canvas.draw_rect(Rect2(rect.position.x + 5.0 + i * 9.0, rect.position.y - 4.0, 2.0, rect.size.y + 8.0), Color("8a8090"))
			canvas.draw_rect(Rect2(rect.position.x, rect.position.y + 10.0, rect.size.x, 4.0), INK)
			canvas.draw_rect(Rect2(rect.position.x, rect.position.y + 30.0, rect.size.x, 4.0), INK)
	if fx != null:
		for player: Dictionary in snapshot.get("players", {}).values():
			if player.get("skills", {}).has("rage") and float(player.get("hp", 0)) > 0:
				fx.draw_loop(canvas, "rage_aura", Vector2(float(player.x), float(player.y) + 6.0), 0.0, 0.8, clock, Color(1, 1, 1, 0.45))
	if pools != null:
		# poison and lava run out as pools that stop at the walls; first seen = just cast
		var entries: Array = []
		for zone: Dictionary in snapshot.get("skill_fx", {}).get("zones", []):
			if str(zone.kind) in ["poison", "lava"]:
				entries.append({"id": int(zone.id), "k": "pool", "st": str(zone.kind), "x": float(zone.x), "y": float(zone.y), "r": float(zone.r), "p": 0.0, "L": maxf(0.3, float(zone.t))})
		PerfMarks.add("sg.start")
		pools.sync(entries, clock, "skill")
		PerfMarks.add("sg.pools_sync")
		pools.draw(canvas, clock)
		PerfMarks.add("sg.pools_draw")
	if gas != null:
		var fumes: Array = []
		for zone: Dictionary in snapshot.get("skill_fx", {}).get("zones", []):
			if str(zone.kind) == "poison":
				fumes.append({"id": int(zone.id), "k": "gas", "st": "poison", "x": float(zone.x), "y": float(zone.y), "r": float(zone.r) * 0.8, "p": 0.0, "L": maxf(0.3, float(zone.t)), "d": 0.45})
		gas.sync(fumes, clock, "skill")
	PerfMarks.add("sg.gas_sync")
	for zone: Dictionary in snapshot.get("skill_fx", {}).get("zones", []):
		var point := Vector2(float(zone.x), float(zone.y))
		var radius := float(zone.r)
		var fade := clampf(float(zone.t) / 0.5, 0.0, 1.0)
		match str(zone.kind):
			"caltrops":
				PixelPaint.disc(canvas, point, radius, radius, Color(0.3, 0.27, 0.25), 2.0, 0.12 * fade)
				for index in range(9):
					var spot := point + Vector2.from_angle(float(index) * 2.4 + float(zone.id)) * radius * (0.25 + 0.08 * float(index))
					_spike(canvas, spot.round(), Color(0.8, 0.78, 0.72, fade))
			"poison":
				if pools != null: continue
				canvas.draw_circle(point, radius, Color(0.55, 0.85, 0.3, 0.22 * fade))
				canvas.draw_circle(point + Vector2(sin(clock * 3.0 + float(zone.id)) * 3.0, 0), radius * 0.5, Color(0.7, 0.95, 0.4, 0.2 * fade))
			"lava":
				if pools != null: continue
				canvas.draw_circle(point, radius, Color(1.0, 0.45, 0.1, 0.28 * fade))
				canvas.draw_circle(point, radius * 0.55, Color(1.0, 0.8, 0.3, (0.25 + 0.1 * sin(clock * 9.0 + float(zone.id))) * fade))
			"storm":
				# worked out once per 12 fps beat, drawn as a picture
				var tick := int(clock * PixelPaint.FPS)
				var held: Dictionary = _storm_pictures.get(int(zone.id), {})
				if int(held.get("tick", -1)) != tick or Vector2(held.get("at", Vector2.INF)) != point:
					var rec := PixelPaint.Recorder.new()
					rec.art = 2.0
					_draw_storm(rec, zone, point, radius, float(tick) / PixelPaint.FPS)
					held = {"tick": tick, "at": point, "picture": PixelPaint.bake(rec.cells, 2.0)}
					if _storm_pictures.size() > 16:
						_storm_pictures.clear()
					_storm_pictures[int(zone.id)] = held
				PixelPaint.draw_baked(canvas, held.picture, 2.0)
			"decoy":
				# the mirror image, or a clone seal's clone in its hero's own look
				var figure: Texture2D = CLONE_LOOKS.get(str(zone.get("look", "")), DECOY)
				var size := Vector2(figure.get_width(), figure.get_height()) * 2.0
				var clone := CLONE_LOOKS.has(str(zone.get("look", "")))
				var glow := Color(0.75, 0.85, 1.0, 0.8 + 0.1 * sin(clock * 6.0)) if clone else Color(0.6, 0.7, 1.0, 0.45 + 0.15 * sin(clock * 10.0))
				if clone: canvas.draw_circle(point + Vector2(0, 2), 9.0, Color(0.45, 0.6, 1.0, 0.25))
				canvas.draw_texture_rect(figure, Rect2(point - Vector2(size.x * 0.5, size.y - 6.0), size), false, glow)
	for orb: Dictionary in snapshot.get("team", {}).get("orbs", []):
		var point := Vector2(float(orb.x), float(orb.y) - 4.0 - 2.0 * sin(clock * 6.0 + float(orb.id))).round()
		var size := 3.0 + minf(3.0, float(orb.v) * 0.25)
		canvas.draw_circle(point, size + 4.0, Color(0.45, 1.0, 0.7, 0.18))
		var diamond := PackedVector2Array([point + Vector2(0, -size - 1), point + Vector2(size, 0), point + Vector2(0, size + 1), point + Vector2(-size, 0)])
		canvas.draw_colored_polygon(diamond, Color("5fe0a0"))
		canvas.draw_rect(Rect2(point - Vector2(1, 2), Vector2(2, 2)), Color("eafff2"))


# --- Projectiles -------------------------------------------------------------------

## Draws a skill projectile; false when the style is not a skill style.
func draw_bullet(canvas: CanvasItem, bullet: Dictionary, clock: float) -> bool:
	var point := Vector2(float(bullet.x), float(bullet.y)).round()
	var flight := Vector2(float(bullet.get("vx", 1.0)), float(bullet.get("vy", 0.0)))
	var aim := flight.normalized() if flight.length() > 0.1 else Vector2.RIGHT
	var radius := float(bullet.get("radius", 6.0))
	match str(bullet.get("style", "")):
		"wave" when fx != null and fx.has("blade_wave"):
			fx.draw_loop(canvas, "blade_wave", point, aim.angle(), radius / 20.0, clock, Color.WHITE, true)
		"fireball" when fx != null and fx.has("fireball"):
			for ghost in range(1, 4):
				fx.draw_loop(canvas, "fireball", point - aim * ghost * 9.0, aim.angle(), 1.4 - ghost * 0.25, clock - ghost * 0.05, Color(1, 1, 1, 0.45 - ghost * 0.12), true)
			fx.draw_loop(canvas, "fireball", point, aim.angle(), 1.4, clock, Color.WHITE, true)
			# flames trail off the flying fireball and rise behind it, sparks are shed
			if particles != null:
				particles.flames(point - aim * 6.0, 1, [], 2.0, 8.0, -aim * 30.0)
			if particles != null and _rng.randf() < 0.5:
				particles.emit(point - aim * 6.0, -aim.rotated(_rng.randf_range(-0.8, 0.8)) * _rng.randf_range(20.0, 80.0), [PHOTON_FIRE, PHOTON_EMBER][_rng.randi_range(0, 1)], _rng.randf_range(0.25, 0.5), "ember", 2.0, 8.0, _rng.randf_range(10.0, 50.0), 2.0)
		"wave":
			# A silver crescent across the flight, with a fading after-image.
			for layer in range(3):
				var back := point - aim * float(layer) * 10.0
				var alpha := 0.85 - 0.3 * float(layer)
				canvas.draw_arc(back, radius, aim.angle() - 1.2, aim.angle() + 1.2, 14, Color(0.9, 0.95, 1.0, alpha), 5.0 - layer)
			canvas.draw_arc(point + aim * 2.0, radius - 4.0, aim.angle() - 1.0, aim.angle() + 1.0, 12, Color("ffffff"), 2.0)
		"ballista":
			canvas.draw_line(point - aim * 46.0, point, Color(1, 1, 1, 0.35), 3.0)
			_arrow(canvas, point, aim, 3.0)
		"fist":
			if fx != null: fx.draw_loop(canvas, "blade_wave", point + aim * 10.0, aim.angle(), radius / 18.0, clock, Color(0.75, 0.95, 1.0, 0.9))
			canvas.draw_circle(point, radius + 6.0, Color(0.6, 0.9, 1.0, 0.14 + 0.06 * sin(clock * 30.0)))
			canvas.draw_arc(point, radius, aim.angle() - 1.4, aim.angle() + 1.4, 16, Color(0.85, 0.95, 1.0, 0.7), 4.0)
			_arrow(canvas, point, aim, 5.0)
		"fireball":
			var pulse := 0.5 + 0.5 * sin(clock * 22.0)
			canvas.draw_circle(point - aim * 8.0, 7.0, Color(1.0, 0.5, 0.15, 0.35))
			canvas.draw_circle(point, 12.0 + pulse * 2.0, Color(1.0, 0.55, 0.15, 0.25))
			canvas.draw_circle(point, 8.0, Color("f39a3c"))
			canvas.draw_circle(point, 4.0, Color("ffe7a8"))
		"shard":
			canvas.draw_line(point - aim * 6.0, point + aim * 6.0, INK, 5.0)
			canvas.draw_line(point - aim * 5.0, point + aim * 5.0, Color("bfeaf2"), 3.0)
		_: return false
	return true


# --- Over the actors ---------------------------------------------------------------

func draw_over(canvas: CanvasItem, snapshot: Dictionary, clock: float) -> void:
	var players: Dictionary = snapshot.get("players", {})
	for peer: Variant in players:
		_draw_player_state(canvas, players[peer], clock)
		_draw_photon(canvas, str(peer), players[peer], clock)
	for event: Dictionary in snapshot.get("skill_fx", {}).get("events", []):
		_draw_event(canvas, event, clock)
	for event: Dictionary in snapshot.get("fx_events", []):
		var point := Vector2(float(event.x), float(event.y))
		var life := clampf(float(event.get("life", 0.6)) / 0.6, 0.0, 1.0)
		if str(event.kind) == "level_up":
			# a pillar of light over each hero rising away (by the dither: dense in
			# its middle, thinning to its sides and its top) and a ring of gold
			# spreading over the floor; the holy motes are particles (feedback.gd)
			var rise := (1.0 - life) * 90.0
			var bottom := point.y - 40.0 - rise
			for gy in range(int(floor((bottom - 90.0) / 2.0)), int(ceil(bottom / 2.0))):
				for gx in range(int(floor((point.x - 18.0) / 2.0)), int(ceil((point.x + 18.0) / 2.0))):
					var q := Vector2i(gx, gy)
					var across := absf((float(gx) + 0.5) * 2.0 - point.x) / 18.0
					var up := clampf((bottom - (float(gy) + 0.5) * 2.0) / 90.0, 0.0, 1.0)
					if PixelPaint.shown(q, life * (1.0 - across * across) * (1.0 - up) * 0.6):
						PixelPaint.cell(canvas, q, Color("fff6d0") if across < 0.3 else Color("f3ce7d"), 2.0)
			var ring := 30.0 + (1.0 - life) * 30.0
			var crawl := int(clock * PixelPaint.FPS)
			PixelPaint.ellipse(canvas, point + Vector2(0, 2), ring, ring * 0.75, Color("1a1414"), 2.0, 1 if life > 0.5 else 2, crawl)
			PixelPaint.ellipse(canvas, point, ring, ring * 0.75, Color("f3ce7d"), 2.0, 1 if life > 0.5 else 2, crawl)
		elif str(event.kind) == "wall_break":
			canvas.draw_rect(Rect2(point - Vector2(18, 18) * (1.4 - life * 0.4), Vector2(36, 36) * (1.4 - life * 0.4)), Color(0.75, 0.68, 0.6, 0.35 * life))


func _draw_player_state(canvas: CanvasItem, player: Dictionary, clock: float) -> void:
	var skills: Dictionary = player.get("skills", {})
	if skills.is_empty() or float(player.get("hp", 0)) <= 0: return
	var point := Vector2(float(player.get("x", 0)), float(player.get("y", 0)))
	var aim := Vector2(float(player.get("ax", 1.0)), float(player.get("ay", 0.0))).normalized()
	if skills.has("rage"):
		# Rage: a red aura that pulses; the two blades are drawn by the hero look (src/hero/hero_look.gd).
		var pulse := 0.5 + 0.5 * sin(clock * 14.0)
		canvas.draw_circle(point + Vector2(0, -10), 26.0 + pulse * 3.0, Color(1.0, 0.2, 0.15, 0.12 if fx != null else 0.16))
	if skills.has("whirl_time") and fx == null:
		var spin := clock * 30.0
		canvas.draw_arc(point + Vector2(0, -8), 46.0, spin, spin + 2.2, 16, Color(1, 1, 1, 0.7), 4.0)
		canvas.draw_arc(point + Vector2(0, -8), 46.0, spin + PI, spin + PI + 2.2, 16, Color(1, 1, 1, 0.5), 3.0)
	if skills.has("phase_shield"):
		canvas.draw_circle(point + Vector2(0, -12), 22.0, Color(0.55, 0.65, 1.0, 0.18))
		canvas.draw_arc(point + Vector2(0, -12), 22.0, 0.0, TAU, 24, Color(0.75, 0.82, 1.0, 0.7), 2.0)
	if skills.has("charge"):
		# Ballista charge: the aim line brightens and thickens with the charge.
		var charge := float(skills.charge)
		canvas.draw_line(point + aim * 16.0, point + aim * (120.0 + charge * 260.0), Color(1.0, 0.95, 0.75, 0.25 + 0.5 * charge), 1.0 + charge * 3.0)
		if charge >= 0.999: canvas.draw_circle(point + aim * 18.0, 5.0 + sin(clock * 30.0) * 2.0, Color(1, 1, 0.8, 0.8))
	if skills.has("fist_aim"):
		var fist_aim := Vector2(float(skills.fist_aim[0]), float(skills.fist_aim[1]))
		var start := point + fist_aim * 20.0
		var end := point + fist_aim * 480.0
		canvas.draw_line(start, end, Color(1.0, 0.3, 0.25, 0.18), 64.0)
		canvas.draw_line(start, end, Color(1.0, 0.4, 0.3, 0.8), 2.0)


# --- Photoneneis --------------------------------------------------------------------

## One hero's Photoneneis: it grows out of the hand, burns while held, then
## thins out and fades instead of vanishing.
func _draw_photon(canvas: CanvasItem, key: String, player: Dictionary, clock: float) -> void:
	var skills: Dictionary = player.get("skills", {})
	var record: Dictionary = _beams.get(key, {})
	var active: bool = skills.has("beam") and float(player.get("hp", 0)) > 0
	var k := 0.0
	if active:
		if record.is_empty() or record.has("ended"): record = {"start": clock, "emitted": clock}
		record.beam = skills.beam
		record.prisms = skills.get("beam_prisms", [])
		_beams[key] = record
		k = ease(clampf((clock - float(record.start)) / BEAM_GROW, 0.0, 1.0), 0.4)
	else:
		if record.is_empty(): return
		if not record.has("ended"): record.ended = clock
		var left := 1.0 - (clock - float(record.ended)) / BEAM_FADE
		if left <= 0.0:
			_beams.erase(key)
			return
		# record.k keeps the strength the beam had when it ended.
		k = ease(left, 0.6) * float(record.get("k", 1.0))
	if active: record.k = k
	record.shown = k
	record.drawn = clock
	var beam: Array = record.beam
	var from := Vector2(float(beam[0]), float(beam[1]))
	var to := Vector2(float(beam[2]), float(beam[3]))
	_photon(canvas, from, to, k, clock, 1.0)
	for prism: Array in record.prisms:
		_photon(canvas, Vector2(float(prism[0]), float(prism[1])), Vector2(float(prism[2]), float(prism[3])), k, clock + 0.37, 0.5)
	if active: _photon_spray(record, from, to, clock)


## The beam itself, modelled on the Leerenrufer's: pixel squares every 2 px in
## layers from a dark outline to a white-hot core. The ice sheath swells slowly,
## the fire inside flickers fast, bright surges run from the hand to the target,
## fire threads wind through the ice and crystals glint at its edge. `k` grows
## and thins it (0..1); `scale` 0.5 draws a prism side beam.
func _photon(canvas: CanvasItem, from: Vector2, to: Vector2, k: float, t: float, scale: float) -> void:
	var length := from.distance_to(to)
	if length < 2.0 or k <= 0.01: return
	var direction := (to - from) / length
	var normal := direction.orthogonal()
	var alpha := clampf(k * 1.5, 0.0, 1.0)
	var lift := Vector2(0.0, -BEAM_LIFT)
	var start := from + lift
	# Motion per sample first, so every layer shares the same outline.
	var samples := int(length / 2.0) + 1
	var swell := PackedFloat32Array()
	var shimmer := PackedFloat32Array()
	var flicker := PackedFloat32Array()
	var tapers := PackedFloat32Array()
	swell.resize(samples)
	shimmer.resize(samples)
	flicker.resize(samples)
	tapers.resize(samples)
	for index in range(samples):
		var s := float(index) * 2.0
		var surge := pow(maxf(0.0, sin(s * 0.045 - t * 24.0)), 6.0) * 3.0
		var taper := lerpf(0.45, 1.0, s / 28.0) if s < 28.0 else 1.0
		tapers[index] = taper
		swell[index] = (2.2 * sin(s * 0.09 - t * 14.0) + 1.3 * sin(s * 0.031 + t * 9.0) + surge) * taper
		shimmer[index] = (1.4 * sin(s * 0.13 - t * 22.0) + surge) * taper
		flicker[index] = (1.3 * sin(s * 0.21 - t * 46.0) + 0.8 * sin(s * 0.47 + t * 31.0) + surge * 0.6) * taper
	for layer: Array in PHOTON_LAYERS:
		var base := float(layer[0]) * scale
		var color: Color = layer[1]
		color.a *= alpha
		var motion := int(layer[2])
		# Wide layers overlap so much that every second sample is enough.
		var stride := 2 if base >= 9.0 else 1
		for index in range(0, samples, stride):
			var wobble := 0.0
			if motion == 0: wobble = swell[index]
			elif motion == 1: wobble = shimmer[index]
			elif motion == 2: wobble = flicker[index]
			var radius := (base * tapers[index] + wobble * scale) * k
			if radius < 0.9: continue
			var half := maxf(1.0, roundf(radius))
			var corner := ((start + direction * (float(index) * 2.0)) * 0.5 - Vector2(half, half) * 0.5).round() * 2.0
			canvas.draw_rect(Rect2(corner, Vector2(half, half) * 2.0), color)
	# Fire threads winding through the ice (bright where they face the viewer).
	for strand in range(2):
		var s := 6.0
		while s <= length:
			var phase := s * 0.075 - t * 26.0 + PI * float(strand)
			var front := cos(phase)
			var size := 4.0 if front > 0.2 else 2.0
			var thread: Color = PHOTON_EMBER if front > 0.2 else PHOTON_FIRE
			canvas.draw_rect(Rect2(_snap(start + direction * s + normal * sin(phase) * 8.5 * scale * k - Vector2(size, size) * 0.5), Vector2(size, size)), Color(thread, alpha))
			s += 3.0
	# Ice crystals glinting at the edge of the sheath.
	var bucket := int(t * 14.0)
	var index := 0
	var spot := 10.0
	while spot < length - 6.0:
		var roll := absi(hash(Vector3i(index, bucket, int(scale * 10.0))))
		if roll % 4 == 0:
			var outward := 1.0 if (roll / 8) % 2 == 0 else -1.0
			_glint(canvas, start + direction * spot + normal * outward * (13.0 + float((roll / 32) % 6)) * scale * k, Color(PHOTON_FROST, alpha))
		spot += 9.0
		index += 1
	# Impact: a flaring bulb of ice and fire with frost spikes, stopped at walls.
	var end := _back_off(to, direction)
	var limits: PackedFloat32Array = fx.reach(end, 34.0 * scale) if fx != null and fx.has_method("reach") else PackedFloat32Array()
	var flare := (14.0 + 4.0 * sin(t * 43.0)) * scale * k
	for ring: Array in [[flare + 5.0, PHOTON_NAVY], [flare + 2.0, PHOTON_ICE], [flare * 0.72, PHOTON_FROST], [flare * 0.5, PHOTON_FIRE], [flare * 0.28, PHOTON_CORE]]:
		FxSprites.clipped_disc(canvas, end + lift, float(ring[0]), limits, Color(ring[1], alpha))
	for spike in range(7):
		var angle := float(spike) * TAU / 7.0 + t * 1.3
		var room := 999.0
		if not limits.is_empty(): room = limits[int(roundf(wrapf(angle, 0.0, TAU) / TAU * float(limits.size()))) % limits.size()]
		var reach_out := minf(room, flare * (1.3 + 0.3 * sin(t * 17.0 + float(spike) * 1.9)))
		var along := flare * 0.6
		while along < reach_out:
			canvas.draw_rect(Rect2(_snap(end + lift + Vector2.from_angle(angle) * along - Vector2.ONE), Vector2(2, 2)), Color(PHOTON_FROST, alpha))
			along += 2.0
	# Muzzle flare at the hand.
	var muzzle := (8.0 + 2.0 * sin(t * 50.0)) * scale * k
	canvas.draw_circle(start, muzzle + 3.0, Color(PHOTON_NAVY, alpha))
	canvas.draw_circle(start, muzzle + 1.0, Color(PHOTON_ICE, alpha))
	canvas.draw_circle(start, muzzle * 0.6, Color(PHOTON_FROST, alpha))
	canvas.draw_circle(start, muzzle * 0.3, Color(PHOTON_CORE, alpha))


## Ice shards, embers and frost flakes from a burning beam (pixel particles
## that land and stay), and the floor under the impact freezes and scorches.
func _photon_spray(record: Dictionary, from: Vector2, to: Vector2, clock: float) -> void:
	var delta := clampf(clock - float(record.get("emitted", clock)), 0.0, 0.1)
	record.emitted = clock
	if particles == null or delta <= 0.0: return
	var length := from.distance_to(to)
	if length < 4.0: return
	var direction := (to - from) / length
	var end := _back_off(to, direction)
	record.spray = float(record.get("spray", 0.0)) + delta * PHOTON_SPRAY
	while float(record.spray) >= 1.0:
		record.spray = float(record.spray) - 1.0
		var roll := _rng.randf()
		if roll < 0.45:
			# Ice shards burst back from the impact, land and stay as frost.
			var velocity := (-direction).rotated(_rng.randf_range(-1.3, 1.3)) * _rng.randf_range(60.0, 230.0)
			particles.emit(end, velocity, [PHOTON_FROST, PHOTON_ICE, Color.WHITE][_rng.randi_range(0, 2)], 0.6, "frost", 2.0, BEAM_LIFT, _rng.randf_range(20.0, 130.0), 3.0)
		elif roll < 0.8:
			# Embers rise from the fire core.
			particles.emit(end, Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(30.0, 150.0), [PHOTON_FIRE, PHOTON_EMBER][_rng.randi_range(0, 1)], _rng.randf_range(0.3, 0.65), "ember", 2.0, BEAM_LIFT, _rng.randf_range(20.0, 80.0), 2.0)
		else:
			# Frost flakes drift off the sheath along the beam.
			var outward := 1.0 if _rng.randf() < 0.5 else -1.0
			var spot := from + direction * _rng.randf_range(20.0, length) + direction.orthogonal() * outward * 14.0
			particles.emit(spot, direction.orthogonal() * outward * _rng.randf_range(20.0, 70.0), PHOTON_FROST, 0.8, "frost", 2.0, BEAM_LIFT, 0.0, 2.0)
	# Frost crystals and soot build up on the floor where the impact passes or rests.
	var marked: Vector2 = record.get("marked", Vector2.INF)
	if not marked.is_finite() or marked.distance_to(end) > 6.0 or clock - float(record.get("marked_at", -1.0)) > 0.12:
		record.marked = end
		record.marked_at = clock
		particles.frost(end + Vector2(0, 2), 13.0, 9, Color(0.8, 0.95, 1.0, 0.55))
		particles.scatter(end + Vector2(0, 2), Color(0.1, 0.08, 0.1, 0.45), 5.0, 3)


## Steps back from a beam end that lies in a wall until it is on the floor.
func _back_off(point: Vector2, direction: Vector2) -> Vector2:
	if fx == null or not fx.has_method("open"): return point
	var result := point
	for step in range(8):
		if fx.open(result): return result
		result -= direction * 3.0
	return result


## A tiny four-pointed ice glint.
func _glint(canvas: CanvasItem, point: Vector2, color: Color) -> void:
	var middle := _snap(point)
	canvas.draw_rect(Rect2(middle - Vector2(1, 3), Vector2(2, 6)), color)
	canvas.draw_rect(Rect2(middle - Vector2(3, 1), Vector2(6, 2)), color)


func _snap(point: Vector2) -> Vector2:
	return (point / 2.0).round() * 2.0


func _draw_event(canvas: CanvasItem, event: Dictionary, clock: float) -> void:
	var points: Array = event.get("points", [])
	if points.is_empty(): return
	var first := Vector2(float(points[0][0]), float(points[0][1]))
	if fx != null and not _seen.has(int(event.get("id", -1))):
		_seen[int(event.get("id", -1))] = true
		if _seen.size() > 400: _seen.clear()
		_spawn_event(event, points, first)
	if fx != null and str(event.kind) in ["whirl", "burst", "blink", "charge", "backflip", "parry", "rage"]: return
	var left := clampf(float(event.time) / maxf(float(event.get("length", 0.3)), 0.01), 0.0, 1.0)
	match str(event.kind):
		"whirl":
			var radius := float(event.get("radius", 80.0))
			canvas.draw_arc(first + Vector2(0, -6), radius * (1.1 - left * 0.2), 0.0, TAU, 32, Color(1, 1, 1, 0.6 * left), 6.0)
			canvas.draw_circle(first, radius, Color(1, 1, 1, 0.08 * left))
		"chain":
			# lightning: at once, a zigzag bright for a moment then an afterimage, each jump a little later
			var age := float(event.get("length", 0.3)) - float(event.time)
			for index in range(points.size() - 1):
				var a := Vector2(float(points[index][0]), float(points[index][1])) + Vector2(0, -12)
				var b := Vector2(float(points[index + 1][0]), float(points[index + 1][1])) + Vector2(0, -12)
				PixelBolt.draw(canvas, a, b, age - float(index) * 0.03, int(event.get("id", 0)) * 7 + index, 2.0)
		"blink":
			var landing := Vector2(float(points[1][0]), float(points[1][1])) if points.size() > 1 else first
			for spot: Vector2 in [first, landing]:
				canvas.draw_circle(spot + Vector2(0, -12), 18.0 * (1.2 - left * 0.4), Color(0.7, 0.55, 1.0, 0.35 * left))
			canvas.draw_line(first + Vector2(0, -12), landing + Vector2(0, -12), Color(0.8, 0.7, 1.0, 0.4 * left), 3.0)
		"burst":
			var radius := float(event.get("radius", 64.0))
			var tint: Color = COLORS.get(str(event.get("color", "fire")), COLORS.fire)
			canvas.draw_circle(first, radius * (1.0 - left * 0.35), Color(tint, 0.3 * left))
			canvas.draw_arc(first, radius * (1.05 - left * 0.3), 0.0, TAU, 32, Color(tint.lightened(0.4), left), 4.0)
		"parry":
			canvas.draw_circle(first, 8.0 + (1.0 - left) * 10.0, Color(1.0, 0.95, 0.7, left))
		"rage":
			canvas.draw_arc(first + Vector2(0, -10), 30.0 + (1.0 - left) * 40.0, 0.0, TAU, 28, Color(1.0, 0.3, 0.2, left), 4.0)
		"fist_warning":
			pass
		"charge", "backflip":
			canvas.draw_circle(first, 14.0 + (1.0 - left) * 10.0, Color(0.75, 0.7, 0.62, 0.35 * left))
		"wall_slam":
			# a body thrown into the wall: a dust ring and cracks spreading from the hit
			var reach := 10.0 + (1.0 - left) * 22.0
			canvas.draw_arc(first, reach, 0.0, TAU, 20, Color(0.85, 0.78, 0.7, 0.6 * left), 3.0)
			var angle := float(event.get("angle", 0.0))
			for index in range(5):
				var ray := Vector2.RIGHT.rotated(angle + PI + (float(index) - 2.0) * 0.45)
				canvas.draw_line(first, first + ray * reach * (0.6 + 0.1 * float(index % 3)), Color(0.12, 0.09, 0.1, left), 2.0)
		"charge_hit":
			canvas.draw_circle(first + Vector2(0, -10), 6.0 + (1.0 - left) * 14.0, Color(1.0, 0.95, 0.8, 0.5 * left))


## The animation that belongs to a skill event (once per event).
func _spawn_event(event: Dictionary, points: Array, first: Vector2) -> void:
	match str(event.kind):
		# the blade circling the hero carries the whirl (src/hero/hero_look.gd); the floor answers with dust
		"whirl": fx.spawn("dust", first + Vector2(0, 4), 0.0, float(event.get("radius", 80.0)) / 40.0)
		"burst": fx.spawn(str(BURSTS.get(str(event.get("color", "fire")), "fire_burst")), first, 0.0, float(event.get("radius", 64.0)) / 56.0, Color.WHITE, 1.0, true)
		"blink":
			for point: Array in points: fx.spawn("blink", Vector2(float(point[0]), float(point[1])) + Vector2(0, -12), 0.0, 1.4)
		"charge", "backflip": fx.spawn("dust", first + Vector2(0, 6), 0.0, 1.0)
		"wall_slam":
			fx.spawn("dust", first, 0.0, 2.2)
			fx.spawn("hit_spark", first + Vector2(0, -6), 0.0, 2.0, Color(1.0, 0.9, 0.75))
		"charge_hit": fx.spawn("hit_spark", first + Vector2(0, -10), 0.0, 1.8, Color(1.0, 0.95, 0.8))
		"parry": fx.spawn("hit_spark", first, 0.0, 1.6)
		"rage":
			fx.spawn("crit_spark", first + Vector2(0, -12), 0.0, 2.4)
			fx.spawn("fire_burst", first + Vector2(0, -8), 0.0, 0.7, Color(1.0, 0.55, 0.45))
		"chain":
			for index in range(1, points.size()):
				var hit := Vector2(float(points[index][0]), float(points[index][1]))
				fx.spawn("beam_hit", hit + Vector2(0, -12), float(index), 1.3, Color(0.85, 0.9, 1.0))
				# where it struck: a scorch star, sparks; a liquid there conducts it
				if particles != null:
					particles.scorch_star(hit + Vector2(0, 8), 12.0)
					particles.sparks(hit, Vector2.UP, 6, STORM_SPARKS)
				if pools != null: pools.electrify(hit + Vector2(0, 8), 24.0)
		"volley", "ballista": fx.spawn("hit_spark", first + Vector2(0, -10), 0.0, 1.0, Color(1.0, 0.95, 0.8))
		"fist": fx.spawn("frost_burst", first + Vector2(0, -10), 0.0, 0.5)
	if particles != null: _floor_reaction(event, first)


## What a skill does to the pixels on the floor: blasts lift loose debris and
## splash pools apart, fire leaves smoking embers, frost leaves melting crystals.
func _floor_reaction(event: Dictionary, first: Vector2) -> void:
	match str(event.kind):
		"burst":
			var radius := float(event.get("radius", 64.0))
			particles.kick(first, radius, 1.0)
			match str(event.get("color", "fire")):
				"fire":
					# flames thrown out and rising, embers tumbling up, smoke, a scorched floor with embers
					particles.fire_burst(first, radius * 0.7)
					particles.embers(first, radius * 0.6, int(radius * 0.3))
				"frost": particles.frost(first, radius * 0.7, int(radius * 0.8), PHOTON_FROST)
		"whirl":
			particles.kick(first, float(event.get("radius", 80.0)), 0.6)
			particles.dust_flat(first, float(event.get("radius", 80.0)) * 0.5, 10)
		"charge", "backflip":
			particles.kick(first, 28.0, 0.5)
			particles.dust_flat(first, 16.0, 6)
		"wall_slam":
			particles.kick(first, 22.0, 0.7)
			particles.rubble(first, 5, Vector2.ZERO, 110.0)
			particles.dust_flat(first, 14.0, 6)


# --- Chests and loot ------------------------------------------------------------------

## A breakable chest: shakes when hit, cracks show its damage, then it opens.
func draw_chest(canvas: CanvasItem, chest: Dictionary, clock: float) -> void:
	var point := Vector2(float(chest.x), float(chest.y))
	var id := int(chest.id)
	var hits := int(chest.get("hits", 0))
	var seen: Dictionary = _chest_hits.get(id, {"hits": hits, "at": -10.0})
	if hits != int(seen.hits):
		seen = {"hits": hits, "at": clock}
		if fx != null and not bool(chest.get("open", false)): fx.spawn("wood_burst", point + Vector2(0, -8), 0.0, 0.8)
	_chest_hits[id] = seen
	var since := clock - float(seen.at)
	var shake := Vector2(sin(since * 60.0) * 3.0 * maxf(0.0, 1.0 - since * 4.0), 0.0)
	var frame := 0
	if bool(chest.get("open", false)): frame = 2 if since > 0.12 else 1
	var size := Vector2(32, 32)
	if str(chest.get("kind", "chest")) == "gold_crate":
		if bool(chest.get("open", false)): return
		var shimmer := 0.5 + 0.5 * sin(clock * 3.0 + float(id))
		canvas.draw_circle(point + Vector2(0, -4), 26.0, Color(1.0, 0.8, 0.3, 0.08 + 0.08 * shimmer))
		canvas.draw_rect(Rect2(point + Vector2(-14, 11), Vector2(28, 5)), Color(0, 0, 0, 0.3))
		canvas.draw_texture_rect(GOLD_CRATE, Rect2(point - Vector2(16, 30) + shake.round(), Vector2(32, 48)), false)
		return
	if str(chest.get("kind", "chest")) in ["ice_block", "bone_cage"]:
		_draw_block(canvas, chest, point, shake, clock)
		return
	if str(chest.get("kind", "chest")) == "crate":
		if bool(chest.get("open", false)):
			# What is left of a smashed crate: a few planks on the floor.
			for plank in [[-10, 4, 12, 4], [2, 8, 10, 3], [-4, -2, 8, 3]]:
				canvas.draw_rect(Rect2(point + Vector2(plank[0], plank[1]), Vector2(plank[2], plank[3])), Color("3a2416"))
				canvas.draw_rect(Rect2(point + Vector2(plank[0], plank[1]), Vector2(plank[2], 1)), Color("7a5230"))
			return
		canvas.draw_rect(Rect2(point + Vector2(-14, 11), Vector2(28, 5)), Color(0, 0, 0, 0.3))
		canvas.draw_texture_rect(CRATE, Rect2(point - Vector2(16, 18) + shake.round(), size), false)
		if hits > 0:
			canvas.draw_line(point + Vector2(-7, -9) + shake, point + Vector2(0, 0) + shake, Color("1e120a"), 2.0)
			canvas.draw_line(point + Vector2(0, 0) + shake, point + Vector2(6, -4) + shake, Color("1e120a"), 2.0)
		return
	# Chests open with E: the lid swings up over 0.2 s the moment it opens
	# (a chest already open when first seen shows open at once).
	var opened: bool = bool(chest.get("open", false))
	if opened and not _chest_opened.has(id): _chest_opened[id] = clock if _chest_seen.has(id) else clock - 1.0
	_chest_seen[id] = true
	frame = 0
	if opened: frame = 2 if clock - float(_chest_opened[id]) > 0.1 else 1
	var lift := 0.0
	if opened: lift = 3.0 * maxf(0.0, 1.0 - (clock - float(_chest_opened[id])) / 0.25)
	canvas.draw_rect(Rect2(point + Vector2(-13, 9), Vector2(26, 5)), Color(0, 0, 0, 0.3))
	canvas.draw_texture_rect(CHEST_FRAMES[frame], Rect2(point - Vector2(16, 20 + lift), size), false)
	if not opened:
		# A soft glow invites a look; close enough, the key shows.
		var glow := 0.5 + 0.5 * sin(clock * 3.0 + float(id))
		canvas.draw_circle(point + Vector2(0, -4), 22.0, Color(1.0, 0.85, 0.4, 0.04 + 0.04 * glow))
		if local_point.is_finite() and local_point.distance_to(point) <= _chest_reach(): _draw_open_hint(canvas, point + Vector2(0, -30))


## How close the hero must stand for E to open a chest (the host rule in
## loot_chests.json: open_radius plus the hero radius).
func _chest_reach() -> float:
	if _open_reach < 0.0:
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/loot_chests.json"))
		var radius: float = float(balance.get("player", {}).get("radius", 12)) if balance is Dictionary else 12.0
		var reach := (float(data.get("open_radius", 30)) if data is Dictionary else 30.0) + radius
		if balance.is_empty(): return reach
		_open_reach = reach
	return _open_reach


## A boss's temporary block: an ice block (cyan, cracks with hits) or a bone
## cage post (white bones).
func _draw_block(canvas: CanvasItem, chest: Dictionary, point: Vector2, shake: Vector2, clock: float) -> void:
	var at := point + shake.round()
	var damage := float(chest.get("hits", 0)) / maxf(1.0, float(chest.get("max", 3)))
	if str(chest.kind) == "ice_block":
		canvas.draw_rect(Rect2(at + Vector2(-16, -22), Vector2(32, 36)), Color("3d7c8c"))
		canvas.draw_rect(Rect2(at + Vector2(-14, -20), Vector2(28, 32)), Color("9fe3ee", 0.9))
		canvas.draw_rect(Rect2(at + Vector2(-10, -16), Vector2(6, 14)), Color(1, 1, 1, 0.55 + 0.2 * sin(clock * 3.0)))
		if damage > 0.0: canvas.draw_line(at + Vector2(-8, -18), at + Vector2(4, 6), Color("3d7c8c"), 2.0)
		if damage > 0.5: canvas.draw_line(at + Vector2(10, -14), at + Vector2(0, 2), Color("3d7c8c"), 2.0)
		return
	for index in range(3):
		var x := -10.0 + index * 10.0
		canvas.draw_rect(Rect2(at + Vector2(x - 2, -26), Vector2(5, 38)), INK)
		canvas.draw_rect(Rect2(at + Vector2(x - 1, -25), Vector2(3, 36)), Color("e6dcc6"))
	canvas.draw_rect(Rect2(at + Vector2(-14, -20), Vector2(28, 4)), Color("e6dcc6"))
	canvas.draw_rect(Rect2(at + Vector2(-14, 6), Vector2(28, 4)), Color("e6dcc6"))


## "E ÖFFNEN" above a chest: a key cap and the word, in the pixel font.
func _draw_open_hint(canvas: CanvasItem, at: Vector2) -> void:
	var font := PixelStyle.create_font()
	var text := "ÖFFNEN"
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	var left := at.x - (width + 26.0) * 0.5
	var cap := Rect2(Vector2(left, at.y - 15.0), Vector2(20, 20))
	canvas.draw_rect(cap, INK)
	canvas.draw_rect(cap.grow(-2.0), Color("edbf75"))
	canvas.draw_string(font, cap.position + Vector2(5, 16), "E", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, INK)
	canvas.draw_string_outline(font, Vector2(left + 26.0, at.y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 4, INK)
	canvas.draw_string(font, Vector2(left + 26.0, at.y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("fdf7ed"))


## A dropped perk: its class-matching icon bobbing in a golden glow, with its
## name when the local hero is close.
func draw_loot(canvas: CanvasItem, item: Dictionary, clock: float) -> void:
	if str(item.get("kind", "")) == "item":
		_draw_item_loot(canvas, item, clock)
		return
	_draw_perk_loot(canvas, item, clock)


## A found item on the floor: its sprite bobbing in its rarity's glow, the
## name in that colour when the local hero is close.
func _draw_item_loot(canvas: CanvasItem, item: Dictionary, clock: float) -> void:
	var view: Dictionary = item.get("view", {})
	var point := Vector2(float(item.x), float(item.y))
	var rise := clampf(float(item.get("age", 1.0)) / 0.4, 0.0, 1.0)
	var bob := -10.0 - 3.0 * sin(clock * 3.0 + float(item.id)) - (1.0 - rise) * 20.0
	var tint := Color(str(view.get("color", "d3bfa9")))
	var glow := 0.5 + 0.5 * sin(clock * 4.0 + float(item.id))
	canvas.draw_rect(Rect2(point + Vector2(-9, 4), Vector2(18, 4)), Color(0, 0, 0, 0.3))
	canvas.draw_circle(point + Vector2(0, bob), 18.0 + glow * 3.0, Color(tint, 0.16))
	if str(view.get("rarity", "")) in ["epic", "legendary"]:
		for ray in range(6):
			var angle := clock * 0.8 + float(ray) * TAU / 6.0
			canvas.draw_line(point + Vector2(0, bob), point + Vector2(0, bob) + Vector2.from_angle(angle) * (24.0 + glow * 6.0), Color(tint, 0.25), 2.0)
	var path := str(view.get("sprite", ""))
	if not _item_textures.has(path) and ResourceLoader.exists(path): _item_textures[path] = load(path)
	var texture: Texture2D = _item_textures.get(path)
	if texture != null:
		var size := Vector2(texture.get_width(), texture.get_height()) * 2.0
		canvas.draw_texture_rect(texture, Rect2(point + Vector2(-size.x * 0.5, bob - size.y * 0.5), size), false)
	if int(item.id) == nearest_loot:
		var font := PixelStyle.create_font()
		var text := str(view.get("name", "")).to_upper()
		var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		canvas.draw_string_outline(font, point + Vector2(-width * 0.5, bob - 26), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 4, INK)
		canvas.draw_string(font, point + Vector2(-width * 0.5, bob - 26), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, tint)


func _draw_perk_loot(canvas: CanvasItem, item: Dictionary, clock: float) -> void:
	var point := Vector2(float(item.x), float(item.y))
	var rise := clampf(float(item.get("age", 1.0)) / 0.4, 0.0, 1.0)
	var bob := -10.0 - 4.0 * sin(clock * 3.0 + float(item.id)) - (1.0 - rise) * 20.0
	var glow := 0.5 + 0.5 * sin(clock * 4.0)
	canvas.draw_rect(Rect2(point + Vector2(-9, 4), Vector2(18, 4)), Color(0, 0, 0, 0.3))
	canvas.draw_circle(point + Vector2(0, bob), 20.0 + glow * 3.0, Color(1.0, 0.85, 0.4, 0.14))
	canvas.draw_circle(point + Vector2(0, bob), 13.0, Color(1.0, 0.9, 0.6, 0.18))
	var definition: Dictionary = PerkRules.find(balance, str(item.get("perk", "")))
	var icon: Texture2D = SkillIcons.card(definition, local_class) if not definition.is_empty() else null
	if icon != null: canvas.draw_texture_rect(icon, Rect2(point + Vector2(-16, bob - 16), Vector2(32, 32)), false)
	if fx != null and int(clock * 2.0 + float(item.id)) % 3 == 0: fx.draw_loop(canvas, "pickup", point + Vector2(12, bob - 12), 0.0, 0.6, clock)
	if int(item.id) == nearest_loot:
		var font := PixelStyle.create_font()
		var text := str(item.get("name", "")).to_upper()
		var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		canvas.draw_string_outline(font, point + Vector2(-width * 0.5, bob - 24), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 4, INK)
		canvas.draw_string(font, point + Vector2(-width * 0.5, bob - 24), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("edbf75"))


# --- Bloom and light ------------------------------------------------------------------

## Draws this frame's skill lights into the additive glow layer: the
## Photoneneis, skill zones, chain lightning, level-ups, EXP orbs and loot.
func draw_glow(canvas: CanvasItem, snapshot: Dictionary, clock: float, glow: Glow) -> void:
	var beam_level := glow.level("beam")
	for key: String in _beams:
		var record: Dictionary = _beams[key]
		if float(record.get("drawn", -1.0)) != clock: continue
		var k := float(record.get("shown", 0.0))
		var beam: Array = record.beam
		var lift := Vector2(0.0, -BEAM_LIFT)
		var from := Vector2(float(beam[0]), float(beam[1])) + lift
		var to := Vector2(float(beam[2]), float(beam[3]))
		var end := _back_off(to, (to - from).normalized()) + lift
		var surge := 0.9 + 0.1 * sin(clock * 24.0)
		# A wide, soft halo; the core keeps its colours (no white-out).
		Glow.line(canvas, from, end, 150.0 * k, Color(0.25, 0.6, 1.0, 0.3 * k * surge * beam_level))
		Glow.line(canvas, from, end, 34.0 * k, Color(1.0, 0.5, 0.2, 0.18 * k * surge * beam_level))
		Glow.dot(canvas, end, 88.0 * k, Color(0.35, 0.75, 1.0, 0.42 * k * beam_level))
		Glow.dot(canvas, end, 30.0 * k, Color(1.0, 0.7, 0.4, 0.3 * k * beam_level))
		Glow.dot(canvas, from, 40.0 * k, Color(0.5, 0.85, 1.0, 0.35 * k * beam_level))
		for prism: Array in record.get("prisms", []):
			Glow.line(canvas, Vector2(float(prism[0]), float(prism[1])) + lift, Vector2(float(prism[2]), float(prism[3])) + lift, 56.0 * k, Color(0.35, 0.75, 1.0, 0.35 * k * beam_level))
	var spells := glow.level("spells")
	for zone: Dictionary in snapshot.get("skill_fx", {}).get("zones", []):
		var point := Vector2(float(zone.x), float(zone.y))
		var fade := clampf(float(zone.t) / 0.5, 0.0, 1.0)
		match str(zone.kind):
			"lava": Glow.dot(canvas, point, float(zone.r) * 1.8, Color(1.0, 0.42, 0.1, (0.32 + 0.06 * sin(clock * 9.0 + float(zone.id))) * fade * spells))
			"storm": Glow.dot(canvas, point, float(zone.r) * 1.5, Color(0.45, 0.55, 1.0, 0.22 * spells))
			"poison": Glow.dot(canvas, point, float(zone.r) * 1.4, Color(0.5, 0.95, 0.3, 0.12 * fade * spells))
	for event: Dictionary in snapshot.get("skill_fx", {}).get("events", []):
		var points: Array = event.get("points", [])
		if str(event.kind) != "chain" or points.size() < 2: continue
		# each jump flashes with its own bolt and is dark again with it (no light left hanging)
		var age := float(event.get("length", 0.3)) - float(event.time)
		for index in range(points.size() - 1):
			var k := 1.0 - (age - float(index) * 0.03) / 0.12
			if k <= 0.0 or k > 1.0:
				continue
			var a := Vector2(float(points[index][0]), float(points[index][1])) + Vector2(0, -12)
			var b := Vector2(float(points[index + 1][0]), float(points[index + 1][1])) + Vector2(0, -12)
			Glow.line(canvas, a, b, 36.0, Color(0.5, 0.6, 1.0, 0.55 * k * spells))
			Glow.dot(canvas, b, 30.0, Color(0.6, 0.7, 1.0, 0.5 * k * spells))
	for event: Dictionary in snapshot.get("fx_events", []):
		if str(event.kind) != "level_up": continue
		var life := clampf(float(event.get("life", 0.6)) / 0.6, 0.0, 1.0)
		Glow.dot(canvas, Vector2(float(event.x), float(event.y)) + Vector2(0, -24), 90.0, Color(1.0, 0.82, 0.4, 0.45 * life * spells))
	var orbs := glow.level("orbs")
	for orb: Dictionary in snapshot.get("team", {}).get("orbs", []):
		Glow.dot(canvas, Vector2(float(orb.x), float(orb.y) - 4.0), 18.0 + minf(10.0, float(orb.v)), Color(0.35, 1.0, 0.6, 0.32 * orbs))
	for item: Dictionary in snapshot.get("loot_chests", {}).get("loot", []):
		Glow.dot(canvas, Vector2(float(item.x), float(item.y) - 14.0), 44.0 + 4.0 * sin(clock * 4.0), Color(1.0, 0.8, 0.35, 0.3 * orbs))


## The light a flying projectile casts into the glow layer.
func bullet_glow(canvas: CanvasItem, bullet: Dictionary, point: Vector2, clock: float, level: float) -> void:
	if level <= 0.0: return
	var pulse := 0.85 + 0.15 * sin(clock * 20.0 + float(bullet.get("id", 0)))
	var owner := int(bullet.get("owner", 1))
	match str(bullet.get("style", "")):
		"fireball":
			# a warm halo only: no white core over the pixel ball (art review)
			Glow.dot(canvas, point, 48.0 * pulse, Color(1.0, 0.48, 0.12, 0.55 * level))
		"magic":
			var tint: Color = ELEMENT_TINTS.get(str(bullet.get("element", "")), Color("6fe3a0"))
			Glow.dot(canvas, point, 30.0 * pulse, Color(tint, 0.5 * level))
		"void_skull": Glow.dot(canvas, point, 38.0 * pulse, Color(0.72, 0.4, 1.0, 0.5 * level))
		"soul": Glow.dot(canvas, point, 26.0 * pulse, Color(0.45, 0.85, 0.8, 0.35 * level))
		"shard": Glow.dot(canvas, point, 18.0, Color(0.6, 0.9, 1.0, 0.35 * level))
		"fist": Glow.dot(canvas, point, 50.0 * pulse, Color(0.55, 0.88, 1.0, 0.45 * level))
		"wave": Glow.dot(canvas, point, 34.0, Color(0.85, 0.92, 1.0, 0.28 * level))
		"arrow", "ballista", "roar": pass
		_:
			var color: Color = Color("f19791") if owner == 0 else ELEMENT_TINTS.get(str(bullet.get("element", "")), Color("f3ce7d"))
			Glow.dot(canvas, point, 18.0, Color(color, 0.3 * level))


## Light circles for the dark crypt (Vector4 x, y, radius, strength): along
## every burning Photoneneis and over lava.
func lights(snapshot: Dictionary) -> Array:
	var result: Array = []
	for key: String in _beams:
		var record: Dictionary = _beams[key]
		var k := float(record.get("shown", 0.0))
		if k <= 0.05: continue
		var beam: Array = record.beam
		var from := Vector2(float(beam[0]), float(beam[1]))
		var to := Vector2(float(beam[2]), float(beam[3]))
		var steps := maxi(1, int(from.distance_to(to) / 80.0))
		for index in range(steps + 1):
			var point := from.lerp(to, float(index) / float(steps))
			result.append(Vector4(point.x, point.y - BEAM_LIFT, 110.0 * k, 1.0))
	for zone: Dictionary in snapshot.get("skill_fx", {}).get("zones", []):
		if str(zone.kind) == "lava": result.append(Vector4(float(zone.x), float(zone.y), float(zone.r) * 2.0, 0.8))
	return result


func _arrow(canvas: CanvasItem, point: Vector2, aim: Vector2, scale: float) -> void:
	var size := Vector2(ARROW.get_width(), ARROW.get_height()) * scale
	canvas.draw_set_transform(point, aim.angle() + PI * 0.5, Vector2.ONE)
	canvas.draw_texture_rect(ARROW, Rect2(-size * 0.5, size), false)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _spike(canvas: CanvasItem, point: Vector2, color: Color) -> void:
	canvas.draw_rect(Rect2(point - Vector2(1, 3), Vector2(2, 6)), INK)
	canvas.draw_rect(Rect2(point - Vector2(3, 1), Vector2(6, 2)), INK)
	canvas.draw_rect(Rect2(point - Vector2(0.5, 2), Vector2(1, 4)), color)
	canvas.draw_rect(Rect2(point - Vector2(2, 0.5), Vector2(4, 1)), color)


## A storm over the floor: the cloud's shadow on it (dark blue by the dither, a
## crawling dashed rim) and lightning striking out of it, one bolt every
## STORM_EVERY s at a spot inside it (src/vfx/pixel_bolt.gd: there at once,
## bright for a moment, then gone); where one lands it scorches the floor and
## throws sparks once, and a liquid there conducts it (pools.electrify).
func _draw_storm(canvas: Object, zone: Dictionary, point: Vector2, radius: float, clock: float) -> void:
	var id := int(zone.id)
	var crawl := int(clock * PixelPaint.FPS)
	PixelPaint.disc(canvas, point, radius, radius * 0.75, Color("1c2244"), 2.0, 0.3)
	PixelPaint.ellipse(canvas, point + Vector2(0, 2), radius, radius * 0.75, Color("1a1414"), 2.0, 3, crawl)
	PixelPaint.ellipse(canvas, point, radius, radius * 0.75, Color(0.75, 0.8, 1.0), 2.0, 3, crawl)
	var run := clock / STORM_EVERY + float(id) * 0.37
	var strike := int(floor(run))
	var age := (run - float(strike)) * STORM_EVERY
	var rng := RandomNumberGenerator.new()
	rng.seed = id * 7919 + strike * 104729
	var spot := point + Vector2.from_angle(rng.randf() * TAU) * radius * sqrt(rng.randf()) * Vector2(1.0, 0.75)
	var sky := spot + Vector2(rng.randf_range(-24.0, 24.0), -rng.randf_range(70.0, 100.0))
	PixelBolt.draw(canvas, sky, spot, age, id * 31 + strike, 2.0, PixelBolt.STORM, 0.18, 2)
	var key := "%d:%d" % [id, strike]
	if _strikes.has(key):
		return
	if _strikes.size() > 200:
		_strikes.clear()
	_strikes[key] = true
	if particles != null:
		particles.scorch_star(spot, 9.0)
		particles.sparks(spot, Vector2.UP, 5, STORM_SPARKS)
	if pools != null:
		pools.electrify(spot, 20.0)
