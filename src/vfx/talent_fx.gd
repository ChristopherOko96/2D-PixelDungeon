extends RefCounted
## Client art of the talents (snapshot "talents", src/combat/talent_combat.gd):
## poison clouds and set traps on the floor, the wolves, the talent shots and
## short effects. Effects play the pixel-art sheets of scripts/make_fx_sprites.gd
## (fire, frost and arcane rings, the inferno column, absolute zero, shield
## bubble, target mark, spike trap, claws, slashes) over each event's life.
## The companions (wolf, bear) come from the 0x72 companion pack "Enchanted
## Forest Characters"; the water elemental and the bone warrior are drawn in
## the archive's style (scripts/make_companion_sprites.py). A permanent
## companion carries a small life bar and flashes when it casts or is hit.
## Presentation only.

const FxSprites = preload("res://src/vfx/fx_sprites.gd")
const FX_COLORS := {"fire": Color("ff7a2a"), "ice": Color("8fd8e6"), "arcane": Color("b07bff"), "steel": Color("d8dce6"), "poison": Color("8fd65a")}
## Nova rings per element.
const RINGS := {"fire": "fire_ring", "ice": "frost_ring", "arcane": "arcane_ring", "steel": "steel_ring"}
## Bursts at the start and end of a blink per element.
const BLINKS := {"fire": "fire_burst", "arcane": "blink", "ice": "frost_burst"}
## Shots per talent style: sheet and pixel scale.
const SHOTS := {"frost_lance": ["ice_lance", 1.4], "arcane": ["arcane_orb", 1.3], "fireball": ["fireball", 1.3], "blade": ["blade_wave", 1.0]}
## Every active talent its own look (user decision 30.10.2026). Shots per
## talent (they win over the style), then rings, blinks, dashes, swings, marks
## and cast flashes per talent.
const TALENT_SHOTS := {"fire_11": ["magma_bolt", 1.3], "frost_9": ["ice_shard", 1.4], "arcane_9": ["arcane_lance", 1.4], "trapper_1": ["poison_dart", 1.3],
	"minion_3": ["bone_spear", 1.3], "soul_9": ["soul_lance", 1.4], "curse_9": ["blood_orb", 1.4], "soul_1": ["soul_bolt", 1.3], "blade_9": ["knife", 1.2],
	"curse_1": ["curse_skull", 1.3], "fire_9": ["fire_spear", 1.5], "fire_1": ["fireball_big", 1.5]}
const TALENT_RINGS := {"berserk_11": "blood_ring", "guard_7": "quake_ring", "curse_5": "curse_ring", "soul_3": "soul_ring", "guard_4": "shout_ring"}
const TALENT_BURSTS := {"minion_7": "bone_burst", "berserk_11": "blood_burst", "guard_7": "stone_burst", "curse_5": "poison_burst", "soul_3": "void_burst", "arcane_7": "arcane_burst"}
const TALENT_BLINKS := {"sniper_9": "smoke_puff", "trapper_11": "smoke_puff", "blade_11": "shadow_burst", "curse_11": "shadow_burst", "minion_11": "bone_burst", "soul_7": "void_burst"}
const TALENT_DASHES := {"berserk_7": "stone_burst", "guard_11": "gold_bubble", "beast_11": "claw", "blade_5": "slash"}
const TALENT_SWINGS := {"berserk_1": ["slash_rage", ""], "berserk_9": ["slash_rage", "stone_burst"], "guard_1": ["slash", "gold_bubble"], "blade_1": ["slash", "blood_burst"], "blade_7": ["slash", "blood_burst"]}
const TALENT_CASTS := {"fire_1": ["fire_charge", 1.2], "fire_9": ["fire_charge", 1.5], "fire_11": ["fire_charge", 1.2], "fire_3": ["fire_burst", 0.9], "fire_7": ["fire_charge", 1.0],
	"frost_5": ["shield_bubble", 1.0], "arcane_11": ["mana_bubble", 1.1], "soul_5": ["soul_bubble", 1.1], "guard_9": ["gold_bubble", 1.2],
	"minion_9": ["bone_burst", 1.0], "sniper_6": ["star_burst", 1.0], "trapper_6": ["poison_burst", 2.0], "berserk_5": ["rage_aura", 1.0]}
const INK := Color("1a1414")

var sprites := FxSprites.new()


## Floor layer: zones and traps (under the actors).
func draw_ground(canvas: CanvasItem, state: Dictionary, clock: float) -> void:
	for drawing: Dictionary in state.get("drawings", []):
		_draw_line_preview(canvas, drawing, clock)
	for zone: Dictionary in state.get("zones", []):
		var at := Vector2(float(zone.x), float(zone.y))
		var r := float(zone.r)
		match str(zone.get("look", "")):
			"flames":
				# Flammenmeer: glowing cracked ground along the drawn line, flames standing on it
				var path: Array = zone.get("path", [])
				var fade := clampf(float(zone.get("time", 1.0)) / 0.6, 0.0, 1.0)
				var width := float(zone.get("w", 18.0))
				for i in range(path.size() - 1):
					var a := Vector2(float(path[i][0]), float(path[i][1]))
					var b := Vector2(float(path[i + 1][0]), float(path[i + 1][1]))
					canvas.draw_line(a, b, Color(0.35, 0.08, 0.04, 0.45 * fade), width * 2.2)
					canvas.draw_line(a, b, Color(1.0, 0.42, 0.1, 0.35 * fade), width * 1.3)
					canvas.draw_line(a, b, Color(1.0, 0.8, 0.35, 0.7 * fade), 3.0)
				var walked := 0.0
				for i in range(path.size() - 1):
					var a := Vector2(float(path[i][0]), float(path[i][1]))
					var b := Vector2(float(path[i + 1][0]), float(path[i + 1][1]))
					var length := a.distance_to(b)
					var spot_at := fmod(16.0 - fmod(walked, 16.0), 16.0)
					while spot_at <= length:
						var k := int((walked + spot_at) / 16.0)
						sprites.draw_loop(canvas, "flame_tongue", a.lerp(b, spot_at / maxf(0.01, length)) + Vector2(0, 4), 0.0, (0.5 + 0.12 * float(k % 3)) * (0.4 + 0.6 * fade), clock + k * 0.23)
						spot_at += 16.0
					walked += length
				continue
			"firewall":
				# Flammenwall: glowing ground along the line, tall flames flickering on it
				var a := Vector2(float(zone.get("ax", at.x)), float(zone.get("ay", at.y)))
				var b := Vector2(float(zone.get("bx", at.x)), float(zone.get("by", at.y)))
				canvas.draw_line(a, b, Color(1.0, 0.45, 0.1, 0.25), 22.0)
				canvas.draw_line(a, b, Color(1.0, 0.75, 0.3, 0.5), 4.0)
				var count := maxi(2, int(a.distance_to(b) / 14.0))
				for i in range(count + 1):
					var spot := a.lerp(b, float(i) / count) + Vector2(0, 6)
					sprites.draw_loop(canvas, "flame_tongue", spot, 0.0, 1.0 + 0.15 * float(i % 3), clock + i * 0.23)
				continue
			"lava":
				# Lavafeld: a pool of magma with flames licking up here and there
				sprites.draw_loop(canvas, "lava_pool", at, 0.0, r / 64.0, clock)
				for i in range(4):
					var spot := at + Vector2.from_angle(TAU * i / 4.0 + 0.6) * r * 0.45
					sprites.draw_loop(canvas, "flame_tongue", spot, 0.0, 0.7, clock + i * 0.4)
				continue
			"ice":
				# Gletschergrab: frozen ground with crystal clusters, the middle the tallest
				canvas.draw_circle(at, r, Color(0.55, 0.85, 1.0, 0.16))
				canvas.draw_arc(at, r, 0.0, TAU, 48, Color(0.8, 0.95, 1.0, 0.45), 2.0)
				for i in range(7):
					var spot := at + Vector2.from_angle(TAU * i / 7.0 + 0.4) * r * 0.62
					sprites.draw_loop(canvas, "ice_block", spot, 0.0, 0.55, clock + i * 0.21)
				sprites.draw_loop(canvas, "ice_block", at + Vector2(0, 10), 0.0, 1.0, clock)
				continue
			"arcane":
				# Singularität: the whirl turns over a dark disc, motes stream inwards
				canvas.draw_circle(at, r, Color(0.25, 0.12, 0.45, 0.22))
				sprites.draw_loop(canvas, "vortex", at, -clock * 2.5, clampf(r / 64.0, 0.6, 2.2), clock)
				for i in range(10):
					var k := fmod(clock * 0.8 + i * 0.1, 1.0)
					var mote := at + Vector2.from_angle(i * 2.4 + clock) * r * (1.0 - k)
					canvas.draw_rect(Rect2(mote - Vector2(1.5, 1.5), Vector2(3, 3)), Color(0.85, 0.75, 1.0, k))
				continue
			"snow":
				# Blizzard: a cold haze with snow driving across it
				canvas.draw_circle(at, r, Color(0.7, 0.9, 1.0, 0.14))
				for i in range(6):
					var spot := at + Vector2.from_angle(TAU * i / 6.0) * r * 0.5
					sprites.draw_loop(canvas, "snowfall", spot, 0.0, clampf(r / 40.0, 0.8, 2.0), clock + i * 0.17)
				sprites.draw_loop(canvas, "snowfall", at, 0.0, clampf(r / 40.0, 0.8, 2.0), clock)
				continue
			"arrows":
				# Pfeilhagel: the field darkens under the volley, big arrows plunge in all
				# over it and every one strikes with dust, splinters and a quivering shaft
				canvas.draw_circle(at, r, Color(0.1, 0.08, 0.06, 0.18))
				canvas.draw_arc(at, r, 0.0, TAU, 48, Color(0.95, 0.85, 0.6, 0.45), 2.0)
				var count := clampi(int(r / 7.0), 10, 24)
				for i in range(count):
					var cycle := clock * 1.6 + float(i) / count * 3.0
					var round_index := floori(cycle)
					var u := cycle - float(round_index)
					var seed_value := absi(hash(Vector3i(i, round_index, int(zone.get("id", 0)))))
					var spot := at + Vector2.from_angle(float(seed_value % 628) / 100.0) * r * sqrt(float((seed_value / 628) % 100) / 100.0) * 0.92
					if u < 0.3: sprites.draw_loop(canvas, "hail_arrow", spot + Vector2(18, -150) * (1.0 - u / 0.3), 0.12, 1.0, clock + i * 0.1)
					else: sprites.draw_at(canvas, "arrow_impact", spot, 0.0, 1.0, (u - 0.3) / 0.7)
				continue
			"crater":
				# the meteor's crater: scorched rock, lava pooling, glowing cracks, flames and smoke
				canvas.draw_circle(at, r, Color(0.12, 0.07, 0.05, 0.45))
				sprites.draw_loop(canvas, "lava_pool", at, 0.0, clampf(r / 96.0, 0.5, 1.8), clock)
				for i in range(6):
					var a := TAU * i / 6.0 + 0.3
					var from := at + Vector2.from_angle(a) * r * 0.25
					var bend := at + Vector2.from_angle(a + 0.2) * r * 0.6
					var to := at + Vector2.from_angle(a - 0.1) * r * 0.95
					var glow := 0.55 + 0.35 * sin(clock * 3.0 + i)
					canvas.draw_line(from, bend, Color(1.0, 0.55, 0.15, glow), 3.0)
					canvas.draw_line(bend, to, Color(1.0, 0.45, 0.1, glow * 0.7), 2.0)
				for i in range(3):
					sprites.draw_loop(canvas, "flame_tongue", at + Vector2.from_angle(TAU * i / 3.0 + 1.0) * r * 0.55, 0.0, 0.8, clock + i * 0.5)
					sprites.draw_loop(canvas, "smoke_puff", at + Vector2.from_angle(TAU * i / 3.0) * r * 0.4 - Vector2(0, 20), 0.0, 1.0, clock * 0.6 + i * 0.4, Color(1, 1, 1, 0.5))
				continue
			"souls":
				# Seelensturm: souls circle the field
				canvas.draw_circle(at, r, Color(0.45, 0.2, 0.7, 0.14))
				for i in range(8):
					var spot := at + Vector2.from_angle(TAU * i / 8.0 + clock * 1.6) * r * (0.45 + 0.35 * sin(clock + i))
					sprites.draw_loop(canvas, "soul_wisp", spot, 0.0, 1.1, clock + i * 0.2)
				continue
			"plague":
				# Seuchengrube: sickly green-violet clouds over bubbling ground
				canvas.draw_circle(at, r, Color(0.35, 0.6, 0.2, 0.16))
				if sprites.has("poison_cloud"):
					for i in range(7):
						var spot := at + Vector2.from_angle(TAU * i / 7.0 + clock * 0.1) * r * (0.2 + 0.5 * float(i % 3) / 2.0)
						sprites.draw_loop(canvas, "poison_cloud", spot, 0.0, clampf(r / 90.0, 0.6, 1.3), clock + i * 0.3, Color(0.85, 0.7, 1.0))
				continue
		if str(zone.get("status", "")) == "burn" and sprites.has("fire_burst"):
			# burning ground (Inferno, Feuersturm): a hot glow with flames flaring up across it
			canvas.draw_circle(at, r, Color(1.0, 0.45, 0.1, 0.12))
			for i in range(9):
				var spot := at + Vector2.from_angle(TAU * i / 9.0 + float(i % 3) * 0.7) * r * (0.3 + 0.55 * float((i * 5) % 9) / 8.0)
				sprites.draw_loop(canvas, "fire_burst", spot, 0.0, 0.7, clock * 0.8 + i * 0.29)
			continue
		canvas.draw_circle(at, r, Color(0.45, 0.8, 0.25, 0.10))
		if sprites.has("poison_cloud"):
			# a ring of churning clouds and one in the middle
			var cloud := sprites.frame_size("poison_cloud").x * FxSprites.PIXEL
			var scale := clampf(r / cloud, 0.5, 1.2)
			sprites.draw_loop(canvas, "poison_cloud", at, 0.0, scale, clock)
			for i in range(6):
				var spot := at + Vector2.from_angle(TAU * i / 6.0 + clock * 0.15) * r * 0.62
				sprites.draw_loop(canvas, "poison_cloud", spot, 0.0, scale * 0.8, clock + i * 0.37)
		else:
			canvas.draw_arc(at, r, 0.0, TAU, 48, Color(0.55, 0.9, 0.3, 0.6), 2.0)
	# mana on the ground: a small glowing orb, a boss's potion as the 0x72 blue flask
	for orb: Dictionary in state.get("orbs", []):
		var at := Vector2(float(orb.x), float(orb.y))
		var bob := sin(clock * 4.0 + float(orb.id)) * 2.0
		var fade := clampf(float(orb.get("life", 5.0)) / 3.0, 0.25, 1.0)
		canvas.draw_circle(at + Vector2(0, 4), 7.0, Color(0, 0, 0, 0.3 * fade))
		if bool(orb.get("potion", false)) and _flask() != null:
			canvas.draw_circle(at - Vector2(0, 10 - bob), 15.0, Color(0.35, 0.55, 1.0, 0.18 * fade))
			canvas.draw_texture_rect(_flask(), Rect2(at - Vector2(16, 30 - bob), Vector2(32, 32)), false, Color(1, 1, 1, fade))
			continue
		var c := at - Vector2(0, 8 - bob)
		canvas.draw_circle(c, 9.0, Color(0.3, 0.5, 1.0, 0.2 * fade))
		canvas.draw_circle(c, 5.0, Color(0.32, 0.55, 1.0, fade))
		canvas.draw_circle(c, 3.0, Color(0.62, 0.8, 1.0, fade))
		canvas.draw_rect(Rect2(c + Vector2(-2, -3), Vector2(2, 2)), Color(1, 1, 1, fade))
	for trap: Dictionary in state.get("traps", []):
		var at := Vector2(float(trap.x), float(trap.y))
		var boom := bool(trap.get("boom", false))
		if bool(trap.get("cloud", false)): canvas.draw_circle(at, 14.0, Color(0.5, 0.9, 0.3, 0.2 + 0.1 * sin(clock * 4.0)))
		if sprites.has("spike_trap"):
			sprites.draw_at(canvas, "spike_trap", at, 0.0, 1.0, 0.0, Color("ffc890") if boom else Color.WHITE)
		else:
			canvas.draw_arc(at, 12.0, 0.0, TAU, 16, Color("c87a3a") if boom else Color("8a8a96"), 2.0)
		if boom: canvas.draw_rect(Rect2(at - Vector2(3, 4), Vector2(6, 6)), Color(1.0, 0.6, 0.2, 0.6 + 0.4 * sin(clock * 10.0)))


## A line of fire being drawn (Flammenmeer while its key is held): the
## ember trail along the points so far and, at its tip, the fill bar of the
## length still left.
func _draw_line_preview(canvas: CanvasItem, drawing: Dictionary, clock: float) -> void:
	var points: Array = drawing.get("points", [])
	if points.is_empty(): return
	for i in range(points.size() - 1):
		var a := Vector2(float(points[i][0]), float(points[i][1]))
		var b := Vector2(float(points[i + 1][0]), float(points[i + 1][1]))
		canvas.draw_line(a, b, Color(1.0, 0.45, 0.1, 0.35), 10.0)
		canvas.draw_line(a, b, Color(1.0, 0.85, 0.4, 0.5 + 0.3 * sin(clock * 12.0 + i)), 3.0)
	var tip := Vector2(float(points[-1][0]), float(points[-1][1]))
	sprites.draw_loop(canvas, "fire_charge", tip, 0.0, 0.9, clock)
	var share := clampf(float(drawing.get("left", 0.0)) / maxf(1.0, float(drawing.get("max", 1.0))), 0.0, 1.0)
	var bar := Rect2((tip + Vector2(-22, -34)).round(), Vector2(44, 6))
	canvas.draw_rect(bar.grow(1), INK)
	canvas.draw_rect(Rect2(bar.position, Vector2(roundf(bar.size.x * share), bar.size.y)), Color("ff8a2a") if share > 0.25 else Color("e2584a"))
	canvas.draw_rect(Rect2(bar.position, Vector2(roundf(bar.size.x * share), 2)), Color("ffd060"))


## The mage's left-click (crypt and Hölle): a small fireball that sheds embers.
func draw_basic_fireball(canvas: CanvasItem, at: Vector2, velocity: Vector2, clock: float) -> void:
	var aim := velocity.normalized() if velocity.length() > 0.1 else Vector2.RIGHT
	for k in range(5):
		var age := fmod(clock * 4.0 + k * 0.2, 1.0)
		var spot := at - aim * (8.0 + age * 26.0) + aim.orthogonal() * sin(k * 2.1 + clock * 9.0) * (2.0 + age * 5.0) + Vector2(0, age * 4.0)
		canvas.draw_rect(Rect2(spot.round() - Vector2(1, 1), Vector2(2, 2)), Color(1.0, 0.8 - age * 0.45, maxf(0.0, 0.3 - age * 0.3), 1.0 - age))
	canvas.draw_circle(at, 14.0, Color(1.0, 0.5, 0.15, 0.18))
	if sprites.has("fireball"): sprites.draw_loop(canvas, "fireball", at, aim.angle(), 1.25, clock)
	else: canvas.draw_circle(at, 6.0, Color("ffd060"))


## Actor layer: the companions (wolf or bear) with the "Enchanted Forest
## Characters" frames (assets/sprites/forest_0x72, the 0x72 companion pack),
## at 2x like every 0x72 actor; walk frames while moving, idle otherwise. The
## pack summoned by the ultimate shows as pale spirits.
func draw_pets(canvas: CanvasItem, state: Dictionary, clock: float) -> void:
	for pet: Dictionary in state.get("pets", []):
		var at := Vector2(float(pet.x), float(pet.y)).round()
		var face := -1.0 if float(pet.get("face", 1.0)) < 0.0 else 1.0
		var kind := str(pet.get("kind", "wolf"))
		var moving := bool(pet.get("moving", false))
		var frame := _companion_frame(kind, "walk" if moving else "idle", int(clock * (10.0 if moving else 6.0)) % 4)
		# the falcon flies: drawn above its shadow, bobbing with the wing beats
		var lift := Vector2(0, roundf(-22.0 - 3.0 * sin(clock * 3.0))) if kind == "falcon" else Vector2.ZERO
		if kind == "falcon":
			canvas.draw_set_transform(at, 0.0, Vector2(1.0, 0.4))
			canvas.draw_circle(Vector2.ZERO, 12.0, Color(0, 0, 0, 0.3))
			canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# Wildes Erwachen: the companion grows; the colossus is big anyway
		var grow := 3.0 if bool(pet.get("awake", false)) else 2.0
		if bool(pet.get("awake", false)): sprites.draw_loop(canvas, "rage_aura", at + Vector2(0, -24), 0.0, 1.3, clock)
		var lunge := 6.0 if float(pet.get("bite", 0.0)) > 0.0 and kind != "water_elemental" else 0.0
		var tint := Color(0.75, 0.9, 1.0, 0.85) if bool(pet.get("pack", false)) else Color.WHITE
		if float(pet.get("hurt", 0.0)) > 0.0: tint = Color(1.0, 0.55, 0.5)
		var casting := float(pet.get("cast", 0.0))
		if casting > 0.0:
			# casting: a bright flash and a ring of its element under the feet
			tint = tint.lerp(Color(1.6, 1.6, 1.6), clampf(casting / 0.45, 0.0, 1.0) * 0.6)
			_ring(canvas, "frost_ring" if kind == "water_elemental" else "fire_ring" if kind == "pyro" else "shout_ring", at, 26.0, 1.0 - clampf(casting / 0.45, 0.0, 1.0))
		if kind == "pyro":
			# the ground glows under the Pyro-Monster, embers rise off it
			canvas.draw_circle(at + Vector2(0, -1), 11.0 + sin(clock * 7.0), Color(1.0, 0.45, 0.12, 0.2))
			for k in range(3):
				var age := fmod(clock * 1.5 + k * 0.33, 1.0)
				canvas.draw_rect(Rect2((at + Vector2(sin(k * 2.3 + clock) * 10.0, -10.0 - age * 40.0)).round(), Vector2(2, 2)), Color(1.0, 0.75, 0.3, 1.0 - age))
		if kind == "water_elemental":
			# a wet shimmer on the floor under the gliding whirl
			canvas.draw_circle(at + Vector2(0, -1), 10.0 + sin(clock * 5.0), Color(0.4, 0.75, 1.0, 0.18))
		if frame != null:
			# feet on the point whatever the frame size (32 px forest beasts, 16 px skeletons)
			var frame_size := frame.get_size()
			canvas.draw_set_transform(at + lift + Vector2(lunge * face, 0), 0.0, Vector2(grow * face, grow))
			canvas.draw_texture(frame, Vector2(-frame_size.x * 0.5, 1.0 - frame_size.y), tint)
			canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if lunge > 0.0 and sprites.has("claw"):
			sprites.draw_loop(canvas, "claw", at + Vector2(22.0 * face, -20.0), 0.0, 0.7, clock)
		if bool(pet.get("permanent", false)) and frame != null:
			var bar := Rect2(at + lift + Vector2(-14, -frame.get_size().y * grow - 8.0), Vector2(28, 4))
			canvas.draw_rect(bar.grow(1), INK)
			canvas.draw_rect(Rect2(bar.position, Vector2(roundf(bar.size.x * clampf(float(pet.get("hp", 1.0)), 0.0, 1.0)), bar.size.y)), Color("8fd6a5") if float(pet.get("hp", 1.0)) > 0.35 else Color("e2584a"))


var _frames: Dictionary = {}
var _flask_texture: Texture2D


func _flask() -> Texture2D:
	if _flask_texture == null and ResourceLoader.exists("res://assets/sprites/0x72/flask_big_blue.png"):
		_flask_texture = load("res://assets/sprites/0x72/flask_big_blue.png")
	return _flask_texture


## A raised block (Shift): its bubble around the hero with one pip per hit
## left; a dodge: a faint shimmer while untouchable.
func _draw_guard(canvas: CanvasItem, guard: Dictionary) -> void:
	var at := Vector2(float(guard.x), float(guard.y)) - Vector2(0, 16)
	if bool(guard.get("dodge", false)):
		canvas.draw_circle(at, 18.0, Color(0.8, 1.0, 0.8, 0.12))
		return
	var look := str(guard.get("look", "mana_bubble"))
	var ticks := Time.get_ticks_msec() / 1000.0
	var whole := float(guard.get("left", 1.0)) >= float(guard.get("max", 1.0))
	if sprites.has(look): sprites.draw_loop(canvas, look, at, 0.0, 1.1, ticks, Color(1, 1, 1, 0.9 if whole else 0.6))
	else: canvas.draw_arc(at, 26.0, 0.0, TAU, 32, Color(0.6, 0.8, 1.0, 0.8), 3.0)
	if not whole:
		# cracks across a block that already took a hit
		for i in range(3):
			var a := Vector2.from_angle(1.0 + i * 2.1) * 22.0
			canvas.draw_line(at + a * 0.2, at + a, Color(1, 1, 1, 0.75), 1.0)
	var count := int(guard.get("max", 2))
	for i in range(count):
		var pip := Rect2((at + Vector2(-count * 4.0 + i * 8.0 + 1.0, -34)).round(), Vector2(6, 4))
		canvas.draw_rect(pip.grow(1), INK)
		canvas.draw_rect(pip, Color("8fd6ff") if i < int(floorf(float(guard.get("left", 0.0)))) else Color(0.25, 0.25, 0.3))


## Frames of a summon: the forest beasts (wolf, bear) or the 0x72 skeleton
## the necromancer raises.
func _companion_frame(kind: String, motion: String, index: int) -> Texture2D:
	var path := "res://assets/sprites/forest_0x72/%s_%s_f%d.png" % [kind, motion, index]
	if kind in ["water_elemental", "bone_warrior", "falcon", "pyro"]: path = "res://assets/sprites/companions/%s_%s_f%d.png" % [kind, motion, index]
	if kind == "colossus": path = "res://assets/sprites/0x72/big_zombie_%s_anim_f%d.png" % ["run" if motion == "walk" else "idle", index]
	if kind == "skeleton": path = "res://assets/sprites/0x72/skelet_%s_anim_f%d.png" % ["run" if motion == "walk" else "idle", index]
	if not _frames.has(path): _frames[path] = load(path) if ResourceLoader.exists(path) else null
	return _frames[path]


## A talent shot ({x, y, vx, vy, style}) as its sheet; false when the style
## has none (the caller draws it its own way).
func draw_bullet(canvas: CanvasItem, bullet: Dictionary, clock: float) -> bool:
	var shot: Array = TALENT_SHOTS.get(str(bullet.get("talent", "")), SHOTS.get(str(bullet.get("style", "")), []))
	if shot.is_empty() or not sprites.has(str(shot[0])): return false
	var at := Vector2(float(bullet.x), float(bullet.y)).round()
	var flight := Vector2(float(bullet.get("vx", 1.0)), float(bullet.get("vy", 0.0)))
	var aim := flight.normalized() if flight.length() > 0.1 else Vector2.RIGHT
	for ghost in range(1, 3):
		sprites.draw_loop(canvas, str(shot[0]), at - aim * ghost * 8.0, aim.angle(), float(shot[1]) - ghost * 0.25, clock - ghost * 0.05, Color(1, 1, 1, 0.4 - ghost * 0.12))
	if str(shot[0]) == "fireball_big":
		# embers peel off behind the Feuerball and sink as they cool
		for k in range(8):
			var age := fmod(clock * 3.0 + k * 0.125, 1.0)
			var spot := at - aim * (14.0 + age * 46.0) + aim.orthogonal() * sin(k * 2.3 + clock * 7.0) * (4.0 + age * 8.0) + Vector2(0, age * 6.0)
			canvas.draw_rect(Rect2(spot.round() - Vector2(1, 1), Vector2(3, 3) if age < 0.4 else Vector2(2, 2)), Color(1.0, 0.85 - age * 0.5, maxf(0.0, 0.3 - age * 0.25), 1.0 - age))
	sprites.draw_loop(canvas, str(shot[0]), at, aim.angle(), float(shot[1]), clock)
	return true


## Effect layer: short events over everything, each sheet played over the
## event's life (span).
func draw_events(canvas: CanvasItem, state: Dictionary) -> void:
	for guard: Dictionary in state.get("guards", []):
		_draw_guard(canvas, guard)
	for event: Dictionary in state.get("events", []):
		var at := Vector2(float(event.x), float(event.y))
		var span := maxf(0.05, float(event.get("span", 0.5)))
		var p := 1.0 - clampf(float(event.life) / span, 0.0, 1.0)
		var fade := 1.0 - p
		var fx := str(event.get("fx", "steel"))
		match str(event.kind):
			"nova":
				var talent := str(event.get("talent", ""))
				if bool(event.get("impact", false)):
					# a meteor lands: a flash over the field, the fire dome rising into a
					# mushroom, the dust shockwave, sparks and rock flying
					if p < 0.12: canvas.draw_circle(at, float(event.r) * 1.3, Color(1.0, 0.95, 0.8, (0.12 - p) * 5.0))
					sprites.draw_at(canvas, "meteor_impact", at, 0.0, float(event.r) / 150.0, p)
					sprites.draw_at(canvas, "fire_sparks", at - Vector2(0, 30), 0.0, float(event.r) / 50.0, minf(1.0, p * 1.4))
					sprites.draw_at(canvas, "stone_burst", at, 0.0, float(event.r) / 70.0, p)
				elif talent == "fire_14":
					# the small meteors of the shower burst like big fireballs
					sprites.draw_at(canvas, "fire_explosion", at - Vector2(0, 8), 0.0, float(event.r) / 44.0, p)
					sprites.draw_at(canvas, "fire_sparks", at - Vector2(0, 8), 0.0, float(event.r) / 40.0, p)
				if talent == "fire_6" and sprites.has("inferno"):
					_ring(canvas, "fire_ring", at, float(event.r), p)
					sprites.draw_at(canvas, "inferno", at + Vector2(0, 10), 0.0, 1.0, p, Color(1, 1, 1, 0.9))
				elif talent == "frost_6" and sprites.has("zero_burst"):
					_ring(canvas, "frost_ring", at, float(event.r), p)
					sprites.draw_at(canvas, "zero_burst", at, 0.0, 1.1, p, Color(1, 1, 1, 0.9))
				elif talent == "berserk_3" and sprites.has("whirl"):
					sprites.draw_at(canvas, "whirl", at, p * TAU, float(event.r) / 72.0, p)
				elif TALENT_RINGS.has(talent) or TALENT_BURSTS.has(talent):
					_ring(canvas, str(TALENT_RINGS.get(talent, RINGS.get(fx, "steel_ring"))), at, float(event.r), p)
					if TALENT_BURSTS.has(talent): sprites.draw_at(canvas, str(TALENT_BURSTS[talent]), at, 0.0, clampf(float(event.r) / 60.0, 0.6, 2.0), p)
				elif not _ring(canvas, str(RINGS.get(fx, "fire_ring")), at, float(event.r), p):
					var color: Color = FX_COLORS.get(fx, Color("f3ce7d"))
					canvas.draw_arc(at, float(event.r) * (0.3 + 0.7 * p), 0.0, TAU, 48, Color(color, fade), 3.0)
			"shout":
				_ring(canvas, "shout_ring", at, float(event.r), p)
				if bool(event.get("pet", false)): sprites.draw_at(canvas, "star_burst", at + Vector2(0, -18), 0.0, 0.6, p)
			"blink", "dash", "leap":
				var to := Vector2(float(event.get("tx", at.x)), float(event.get("ty", at.y)))
				var color: Color = FX_COLORS.get(fx, Color("d8dce6"))
				for i in range(8):
					var dot := at.lerp(to, i / 7.0)
					canvas.draw_rect(Rect2(dot - Vector2(2, 2), Vector2(4, 4)), Color(color, fade * (0.3 + i * 0.09)))
				match str(event.kind):
					"blink":
						if str(event.get("talent", "")) == "fire_5":
							# Phönixschritt: a bird of flame flies the way, flames at both ends
							# the bird flies the way, a trail of embers behind it
							var flight := minf(1.0, p * 1.3)
							var bird := at.lerp(to, flight) - Vector2(0, 22)
							for k in range(6):
								var ember := at.lerp(to, maxf(0.0, flight - k * 0.06)) - Vector2(0, 22 - k * 2)
								canvas.draw_rect(Rect2(ember - Vector2(2, 2), Vector2(4, 4)), Color(1.0, 0.6 - k * 0.06, 0.2, fade * (1.0 - k / 6.0)))
							if flight < 1.0: sprites.draw_loop(canvas, "phoenix", bird, (to - at).angle(), 1.8, p * 2.0)
							sprites.draw_at(canvas, "fire_burst", at, 0.0, 0.6, p)
							if flight >= 0.9: sprites.draw_at(canvas, "fire_burst", to, 0.0, 0.9, (flight - 0.9) * 4.0 + p * 0.5)
							continue
						var burst := str(TALENT_BLINKS.get(str(event.get("talent", "")), BLINKS.get(fx, "blink")))
						sprites.draw_at(canvas, burst, at, 0.0, 0.9, p)
						sprites.draw_at(canvas, burst if TALENT_BLINKS.has(str(event.get("talent", ""))) else "blink", to, 0.0, 1.0, p)
					"dash":
						var look := str(TALENT_DASHES.get(str(event.get("talent", "")), "slash"))
						sprites.draw_at(canvas, look, to, (to - at).angle() if look == "slash" else 0.0, 1.2, p)
						if look == "stone_burst":
							for i in range(4): sprites.draw_at(canvas, "dust", at.lerp(to, i / 4.0), 0.0, 1.0, minf(1.0, p + i * 0.1))
					"leap":
						sprites.draw_at(canvas, "claw", to + Vector2(0, -12), 0.0, 1.0, p)
			"swing":
				var angle := float(event.get("angle", 0.0))
				var swing: Array = TALENT_SWINGS.get(str(event.get("talent", "")), ["slash", ""])
				if sprites.has(str(swing[0])):
					sprites.draw_at(canvas, str(swing[0]), at, angle, maxf(0.8, float(event.r) / 52.0), p)
					if not str(swing[1]).is_empty(): sprites.draw_at(canvas, str(swing[1]), at + Vector2.from_angle(angle) * float(event.r) * 0.7, 0.0, 0.8, p)
				else:
					var arc := float(event.get("arc", 1.8))
					canvas.draw_arc(at, float(event.r), angle - arc * 0.5, angle + arc * 0.5, 16, Color(1, 1, 1, fade), 3.0)
			"crit":
				sprites.draw_at(canvas, "crit_spark", at + Vector2(0, -16), 0.0, 1.2, p)
				canvas.draw_string(ThemeDB.fallback_font, at + Vector2(-10, -30 - 14 * p), "KRIT", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1.0, 0.85, 0.3, fade))
			"shield":
				sprites.draw_at(canvas, "shield_bubble", at + Vector2(0, -14), 0.0, 1.0, p, Color(1, 1, 1, fade))
			"guard":
				sprites.draw_at(canvas, "shield_bubble", at + Vector2(0, -14), 0.0, 1.0, p, Color(0.75, 1.0, 0.6, fade))
			"parry":
				sprites.draw_at(canvas, "crit_spark", at + Vector2(0, -14), 0.0, 1.4, p)
			"mark":
				if str(event.get("talent", "")) == "curse_3":
					sprites.draw_loop(canvas, "curse_skull", at + Vector2(0, -34 - 6 * p), 0.0, 1.2, p, Color(1, 1, 1, fade))
					_ring(canvas, "curse_ring", at, 26.0, p)
				else:
					sprites.draw_loop(canvas, "reticle", at + Vector2(0, -8), 0.0, 1.0, p * 0.75, Color(1, 1, 1, fade))
			"trap":
				if bool(event.get("boom", false)):
					sprites.draw_at(canvas, "fire_burst", at, 0.0, float(event.r) / 56.0, p)
				else:
					sprites.draw_at(canvas, "spike_trap", at, 0.0, 1.2, p)
			"echo":
				_ring(canvas, "arcane_ring", at, 40.0, p)
			"buff":
				_buff(canvas, str(event.get("buff", "")), at, p, fade)
			"cast":
				_cast(canvas, str(event.get("talent", "")), at, p)
			"pet_bolt", "pet_lance":
				# the companion's shot flies to its target over the event's first half
				var to := Vector2(float(event.get("tx", at.x)), float(event.get("ty", at.y))) - Vector2(0, 14)
				var from := at - Vector2(0, 20)
				var flight := clampf(p * 2.0, 0.0, 1.0)
				var spot := from.lerp(to, flight)
				if flight < 1.0:
					if str(event.kind) == "pet_lance" and sprites.has("ice_lance"):
						sprites.draw_loop(canvas, "ice_lance", spot, (to - from).angle(), 1.3, p)
					else:
						canvas.draw_circle(spot, 5.0, Color(0.35, 0.65, 1.0, 0.5))
						canvas.draw_circle(spot, 3.0, Color("9fdcff"))
						canvas.draw_rect(Rect2(spot - Vector2(1, 2), Vector2(2, 2)), Color.WHITE)
				else:
					sprites.draw_at(canvas, "frost_burst" if str(event.kind) == "pet_lance" else "blink", to, 0.0, 0.7, (p - 0.5) * 2.0)
			"no_res":
				# "Wenig Mana" rises over the hero and fades
				var tint: Color = {"mana": Color("7fb0ff"), "stamina": Color("9fe07a"), "rage": Color("ff7a5a")}.get(str(event.get("res", "mana")), Color.WHITE)
				var label := str(event.get("text", ""))
				var font := ThemeDB.fallback_font
				var spot := at + Vector2(-font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x * 0.5, -46 - 18 * p)
				canvas.draw_string_outline(font, spot, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 4, Color(0, 0, 0, fade))
				canvas.draw_string(font, spot, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(tint, fade))
			"explosion":
				# the Feuerball's impact: the big explosion sheet, a ring of flame and a flash
				canvas.draw_circle(at, float(event.r) * 0.6, Color(0.1, 0.06, 0.04, 0.35 * fade))
				if p < 0.15: canvas.draw_circle(at, float(event.r) * 0.9, Color(1.0, 0.9, 0.6, (0.15 - p) * 3.0))
				sprites.draw_at(canvas, "fire_explosion", at - Vector2(0, 8), 0.0, float(event.r) / 44.0, p)
				sprites.draw_at(canvas, "fire_sparks", at - Vector2(0, 8), 0.0, float(event.r) / 40.0, p)
				if p > 0.4: sprites.draw_at(canvas, "smoke_puff", at - Vector2(0, 20 + 20 * p), 0.0, float(event.r) / 36.0, (p - 0.4) / 0.6, Color(1, 1, 1, 0.7))
				_ring(canvas, "fire_ring", at, float(event.r) * 1.2, p)
			"chain":
				# Glutkette: a crackling line of embers runs from link to link, each hit flares
				var points: Array = event.get("points", [])
				var links := points.size() - 1
				for i in range(links):
					var from := Vector2(float(points[i][0]), float(points[i][1])) - Vector2(0, 14)
					var to := Vector2(float(points[i + 1][0]), float(points[i + 1][1])) - Vector2(0, 14)
					var start := float(i) / links * 0.6
					var reach := clampf((p - start) / (0.6 / links), 0.0, 1.0)
					if reach <= 0.0: continue
					var end := from.lerp(to, reach)
					var steps := maxi(3, int(from.distance_to(end) / 10.0))
					var last := from
					for k in range(1, steps + 1):
						var spot := from.lerp(end, float(k) / steps)
						if k < steps: spot += (to - from).orthogonal().normalized() * (6.0 * sin(float(k * 7 + i * 3 + int(event.id))))
						canvas.draw_line(last, spot, Color(1.0, 0.45, 0.1, fade), 4.0)
						canvas.draw_line(last, spot, Color(1.0, 0.9, 0.5, fade), 2.0)
						last = spot
					if reach >= 1.0: sprites.draw_at(canvas, "fire_burst", to + Vector2(0, 14), 0.0, 0.6, clampf((p - start) * 2.0, 0.0, 1.0))
			"meteor_fall":
				# the rune circle glows, the shadow grows while the rock falls in from the top right
				var r := float(event.r)
				sprites.draw_loop(canvas, "rune_circle", at, p * 1.5, r / 60.0, p, Color(1, 1, 1, 0.4 + 0.5 * p))
				canvas.draw_circle(at, r * (0.3 + 0.7 * p), Color(0, 0, 0, 0.18 + 0.25 * p))
				canvas.draw_arc(at, r, 0.0, TAU, 40, Color(1.0, 0.45, 0.15, 0.25 + 0.5 * p), 2.0)
				canvas.draw_circle(at, r * 0.5 * p, Color(1.0, 0.5, 0.1, 0.18 * p))
				if bool(event.get("big", false)) and sprites.has("meteor_big"):
					sprites.draw_loop(canvas, "meteor_big", at + Vector2(150, -320) * (1.0 - p), 0.0, 1.3, p * 2.0)
				else:
					sprites.draw_loop(canvas, "meteor", at + Vector2(110, -260) * (1.0 - p), 0.0, 0.9, p * 2.0)
			"spear":
				# Himmelsspeer: the golden arrow streaks to the end of its line, a bright trail behind it
				var to := Vector2(float(event.get("tx", at.x)), float(event.get("ty", at.y)))
				var head := at.lerp(to, clampf(p * 2.5, 0.0, 1.0))
				canvas.draw_line(at - Vector2(0, 14), head - Vector2(0, 14), Color(1.0, 0.9, 0.5, 0.6 * fade), 6.0)
				canvas.draw_line(at - Vector2(0, 14), head - Vector2(0, 14), Color(1, 1, 1, 0.8 * fade), 2.0)
				sprites.draw_loop(canvas, "sky_spear", head - Vector2(0, 14), (to - at).angle(), 1.4, p, Color(1, 1, 1, minf(1.0, fade * 2.0)))
			"net":
				sprites.draw_at(canvas, "net", at, 0.0, float(event.r) / 68.0, minf(1.0, p * 1.6), Color(1, 1, 1, minf(1.0, fade * 3.0)))
			"leap_slam":
				# Erdspalter: an arc through the air, then the ground breaks
				var to := Vector2(float(event.get("tx", at.x)), float(event.get("ty", at.y)))
				for i in range(10):
					var k := i / 9.0
					var dot := at.lerp(to, k) - Vector2(0, sin(k * PI) * 60.0)
					canvas.draw_rect(Rect2(dot - Vector2(2, 2), Vector2(4, 4)), Color(0.9, 0.85, 0.75, fade * (0.2 + k * 0.6)))
				sprites.draw_at(canvas, "stone_burst", to, 0.0, float(event.r) / 50.0, p)
				_ring(canvas, "steel_ring", to, float(event.r), p)
			"soul":
				# a soul flies from the enemy to the hero
				var to := Vector2(float(event.get("tx", at.x)), float(event.get("ty", at.y))) - Vector2(0, 16)
				var spot := (at - Vector2(0, 12)).lerp(to, p * p) - Vector2(0, sin(p * PI) * 30.0)
				sprites.draw_loop(canvas, "soul_wisp", spot, 0.0, 1.2, p, Color(1, 1, 1, fade))
			"pet_cleave":
				sprites.draw_at(canvas, "claw", at + Vector2(0, -14), 0.0, float(event.r) / 40.0, p)
				_ring(canvas, "steel_ring", at, float(event.r), p)
			"arrow_finale":
				# Pfeilhagel's last volley: the whole field strikes at once, dust bursting across it
				var r := float(event.r)
				for i in range(12):
					var spot := at + Vector2.from_angle(i * 2.39996) * r * sqrt((i + 0.5) / 12.0) * 0.9
					var start := float(i % 4) * 0.08
					var k := clampf((p - start) / (1.0 - start), 0.0, 1.0)
					if k <= 0.0: sprites.draw_loop(canvas, "hail_arrow", spot + Vector2(18, -150) * (1.0 - p / start), 0.12, 1.0, p)
					else: sprites.draw_at(canvas, "arrow_impact", spot, 0.0, 1.2, k)
				_ring(canvas, "quake_ring", at, r, p)
				sprites.draw_at(canvas, "wood_burst", at, 0.0, r / 50.0, p)
				sprites.draw_at(canvas, "stone_burst", at, 0.0, r / 60.0, p)
			"dive":
				# Sturzflug: the falcon drops out of the sky onto its prey, feathers in its wake
				var to := Vector2(float(event.get("tx", at.x)), float(event.get("ty", at.y)))
				var high := at - Vector2(0, 70)
				for i in range(9):
					var k := i / 8.0
					var dot := high.lerp(to - Vector2(0, 10), k)
					canvas.draw_line(dot, dot + Vector2(-3, -6), Color(0.85, 0.82, 0.78, fade * (0.2 + k * 0.7)), 2.0)
				sprites.draw_at(canvas, "claw", to + Vector2(0, -12), 0.0, 1.0, p)
			"dodge":
				# Ausweichen: afterimages along the roll, dust where it starts
				var to := Vector2(float(event.get("tx", at.x)), float(event.get("ty", at.y)))
				for i in range(5):
					var k := i / 4.0
					canvas.draw_circle(at.lerp(to, k) - Vector2(0, 14), 9.0 - i, Color(0.85, 0.95, 0.8, fade * (0.15 + k * 0.25)))
				sprites.draw_at(canvas, "dust", at, 0.0, 1.2, p)
			"dodged":
				var font := ThemeDB.fallback_font
				var spot := at + Vector2(-20, -50 - 16 * p)
				canvas.draw_string_outline(font, spot, "AUSGEWICHEN", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, 4, Color(0, 0, 0, fade))
				canvas.draw_string(font, spot, "AUSGEWICHEN", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.75, 1.0, 0.7, fade))
			"block_hit":
				# a hit stopped by the block: the shield flashes white
				canvas.draw_arc(at - Vector2(0, 16), float(event.r) * (1.0 + 0.2 * p), 0.0, TAU, 32, Color(1, 1, 1, fade), 3.0)
				sprites.draw_at(canvas, "hit_spark", at - Vector2(0, 16), 0.0, 1.4, p)
			"block_break":
				# the last hit breaks the block: it bursts into shards
				var look := str(event.get("look", "mana_bubble"))
				var shards: String = {"mana_bubble": "arcane_burst", "gold_bubble": "star_burst", "soul_bubble": "bone_burst"}.get(look, "frost_burst")
				sprites.draw_at(canvas, str(shards), at - Vector2(0, 16), 0.0, 0.75, p)
				for i in range(8):
					var dir := Vector2.from_angle(TAU * i / 8.0 + 0.3)
					var bit := at - Vector2(0, 16) + dir * float(event.r) * (0.8 + p * 1.2) + Vector2(0, 30.0 * p * p)
					canvas.draw_rect(Rect2(bit.round() - Vector2(2, 2), Vector2(4, 3)), Color(0.85, 0.9, 1.0, fade))
			"drawn":
				# the drawn line catches fire along its length
				_ring(canvas, "fire_ring", at, float(event.r) * 0.4, p)
			"pet_strike":
				# a companion's wound: blood for bleeding, dizzy stars for a blinding blow
				if str(event.get("wound", "")) == "burn":
					sprites.draw_at(canvas, "fire_burst", at - Vector2(0, 12), 0.0, 0.7, p)
				elif str(event.get("wound", "")) == "blood":
					sprites.draw_at(canvas, "blood_burst", at - Vector2(0, 12), 0.0, 0.9, p)
					for i in range(5):
						var drop := at - Vector2(0, 14) + Vector2.from_angle(PI * (1.1 + i * 0.2)) * 18.0 * p + Vector2(0, 30.0 * p * p)
						canvas.draw_rect(Rect2(drop.round(), Vector2(3, 3)), Color(0.75, 0.1, 0.12, fade))
				else:
					for i in range(4):
						var star := at - Vector2(0, 34) + Vector2(cos(p * 9.0 + i * TAU / 4.0) * 12.0, sin(p * 9.0 + i * TAU / 4.0) * 4.0)
						canvas.draw_rect(Rect2(star.round() - Vector2(2, 2), Vector2(4, 4)), Color(1.0, 0.92, 0.4, fade))
					sprites.draw_at(canvas, "crit_spark", at - Vector2(0, 16), 0.0, 1.0, p)
			"summon":
				_ring(canvas, "frost_ring" if str(event.get("kind", "")) == "water_elemental" else "arcane_ring", at, 46.0, p)
				sprites.draw_at(canvas, "level_up", at, 0.0, 1.0, p)
			"pet_fell":
				sprites.draw_at(canvas, "frost_burst" if str(event.get("kind", "")) == "water_elemental" else "crit_spark", at + Vector2(0, -12), 0.0, 1.2, p)


## A nova ring scaled so its edge meets `radius` (world px); false without the sheet.
func _ring(canvas: CanvasItem, sheet: String, at: Vector2, radius: float, p: float) -> bool:
	if not sprites.has(sheet): return false
	var edge := sprites.frame_size(sheet).x * 0.47 * FxSprites.PIXEL
	sprites.draw_at(canvas, sheet, at, 0.0, radius / maxf(1.0, edge), p)
	return true


func _buff(canvas: CanvasItem, buff: String, at: Vector2, p: float, fade: float) -> void:
	match buff:
		"frenzy", "bloodlust":
			sprites.draw_at(canvas, "rage_aura", at + Vector2(0, -20), 0.0, 1.2 if buff == "bloodlust" else 1.0, p)
			if buff == "bloodlust": _ring(canvas, "fire_ring", at, 70.0, p)
		"bulwark", "oath":
			sprites.draw_at(canvas, "shield_bubble", at + Vector2(0, -14), 0.0, 1.1, p, Color(1.0, 0.92, 0.7, fade))
		"unbreakable":
			sprites.draw_at(canvas, "shield_bubble", at + Vector2(0, -14), 0.0, 1.4, p, Color(1.0, 0.85, 0.5, fade))
			_ring(canvas, "shout_ring", at, 80.0, p)
		"timebreak":
			_ring(canvas, "arcane_ring", at, 90.0, p)
			sprites.draw_at(canvas, "star_burst", at + Vector2(0, -16), 0.0, 0.8, p, Color(0.8, 0.7, 1.0))
		_:
			sprites.draw_at(canvas, "level_up", at, 0.0, 1.0, p)


## Cast flashes of talents without an event of their own.
func _cast(canvas: CanvasItem, talent: String, at: Vector2, p: float) -> void:
	if TALENT_CASTS.has(talent):
		var look: Array = TALENT_CASTS[talent]
		sprites.draw_at(canvas, str(look[0]), at + Vector2(0, -14), 0.0, float(look[1]), p)
		return
	match talent:
		"frost_5":
			sprites.draw_at(canvas, "shield_bubble", at + Vector2(0, -14), 0.0, 1.0, p)
		"sniper_6":
			sprites.draw_at(canvas, "star_burst", at + Vector2(0, -12), 0.0, 1.0, p)
		"beast_6":
			_ring(canvas, "shout_ring", at, 90.0, p)
		"blade_6":
			_ring(canvas, "steel_ring", at, 110.0, p)
		"trapper_6":
			sprites.draw_at(canvas, "poison_burst", at, 0.0, 2.0, p)
