extends SceneTree
## Draws the combat effect animations as pixel-art strips in the 0x72 look
## (hard pixels, 3-5 colour ramps, dithered fades) and writes them to
## assets/sprites/fx/<name>.png plus assets/data/vfx_sprites.json (frame size,
## frame count, fps, anchor). The game draws them at 2x like every sprite.
## Deterministic: the same script always yields the same images.
##   godot --headless --path . -s res://scripts/make_fx_sprites.gd

const OUT := "res://assets/sprites/fx/"
const DATA := "res://assets/data/vfx_sprites.json"

const STEEL := ["ffffff", "dfeaf4", "a6bccd", "62788c"]
const RAGE := ["fff2c0", "ffb347", "ff5a3a", "a8241c"]
const FIRE := ["fff7c2", "ffd060", "ff8a2a", "d8461c", "5a3428"]
const FROST := ["ffffff", "c8f4ff", "7fd8ee", "3a8fb0"]
const ARCANE := ["ffffff", "e4d4ff", "b38cf0", "6a46b0"]
const MAGIC := ["f2fff6", "a8f7c8", "3fd08a", "1f7a5a"]
const GOLD := ["fffbe0", "ffe08a", "f0b440", "a86a20"]
const DUST := ["ece2d2", "c8b49e", "927f6e", "5e5049"]
const POISON := ["eaffc0", "a8e05a", "5fa83a", "2f6a2a"]
const VOID := ["f4e6ff", "c890f0", "8a4ac8", "4a2470"]
## Neutral ramp: the game tints these sheets per weapon (archer and mage shots).
const SPELL := ["ffffff", "ececec", "bdbdbd", "8a8a8a"]
const BLOOD := ["ffd0c8", "e05050", "a8242c", "5a1418"]
const BONE := ["ffffff", "f2e6d0", "c9b49a", "8a6a4a"]
const SHADOW := ["c8c0d8", "6a5a8a", "3a2a5a", "1a1030"]
const CURSE := ["eaffd0", "9ce06a", "5a9a4a", "3a2a5a"]
const MAGMA := ["ffe8a0", "ff9a3a", "c8381c", "6a2018", "3a2020"]

var _meta: Dictionary = {}
var _rng := RandomNumberGenerator.new()


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_slash("slash", STEEL, 56)
	_slash("slash_rage", RAGE, 56)
	_whirl("whirl", STEEL, 72)
	_spark("hit_spark", ["ffffff", "fff2b0", "ffd060"], 16)
	_spark("crit_spark", ["ffffff", "ffe66b", "ff8a2a"], 24)
	_burst("fire_burst", FIRE, 64, "smoke")
	_burst("frost_burst", FROST, 64, "shards")
	_burst("arcane_burst", ARCANE, 56, "runes")
	_burst("magic_burst", MAGIC, 32, "stars")
	_burst("stone_burst", DUST, 56, "smoke")
	_burst("void_burst", VOID, 56, "stars")
	_burst("poison_burst", POISON, 40, "smoke")
	_burst("blood_burst", ["ffd0c8", "e05050", "a8242c", "5a1418"], 40, "smoke")
	_orb("magic_orb", MAGIC, 14)
	_orb("spell_orb", SPELL, 14)
	_burst("spell_burst", SPELL, 40, "stars")
	_fireball("fireball", FIRE, 20)
	_wave("blade_wave", STEEL, 28, 44)
	_puff("dust", DUST, 20, 5)
	_blink("blink", ARCANE, 28)
	_spark("beam_hit", ["ffffff", "c8f4ff", "ffb347"], 24)
	_level_up("level_up", GOLD, 36, 56)
	_twinkle("pickup", GOLD, 24)
	_aura("rage_aura", RAGE, 40, 48)
	_splinters("arrow_hit", ["f4e6c8", "c9a27a", "8a6a4a"], 16)
	_splinters("wood_burst", ["e8c890", "b8864a", "7a5230"], 32)
	_stairwell("stairwell_down", true)
	_stairwell("stairwell_up", false)
	# Talent attacks (docs/TALENTE-SEELENSPLITTER.de.md, src/vfx/talent_fx.gd)
	_nova("fire_ring", FIRE, 96, "embers")
	_nova("frost_ring", FROST, 96, "shards")
	_nova("arcane_ring", ARCANE, 80, "motes")
	_nova("shout_ring", GOLD, 96, "motes")
	_nova("steel_ring", STEEL, 80, "motes")
	_pillar("inferno", FIRE, 64, 112)
	_burst("zero_burst", FROST, 96, "shards")
	_burst("star_burst", GOLD, 72, "stars")
	_bubble("shield_bubble", FROST, 44)
	_lance("ice_lance", FROST, 32, 12)
	_orb("arcane_orb", ARCANE, 16)
	_reticle("reticle", GOLD, 28)
	_cloud("poison_cloud", POISON, 48)
	_spikes("spike_trap", STEEL, 32)
	_claw("claw", ["ffffff", "f2e6d0", "c9b49a", "8a6a4a"], 40)
	# Every active talent its own look (user decision 30.10.2026): shots,
	# rings, blinks, shields and fields per branch
	_fireball("magma_bolt", MAGMA, 20)
	_lance("ice_shard", FROST, 20, 8)
	_lance("arcane_lance", ARCANE, 32, 12)
	_lance("poison_dart", POISON, 24, 8)
	_lance("bone_spear", BONE, 32, 10)
	_lance("soul_lance", VOID, 32, 12)
	_orb("blood_orb", BLOOD, 14)
	_fireball("soul_bolt", VOID, 18)
	_knife("knife", STEEL, 16)
	_curse_skull("curse_skull", CURSE, 18)
	_nova("blood_ring", BLOOD, 96, "embers")
	_nova("quake_ring", DUST, 96, "motes")
	_nova("curse_ring", CURSE, 88, "motes")
	_nova("soul_ring", VOID, 88, "motes")
	_burst("bone_burst", BONE, 72, "shards")
	_burst("shadow_burst", SHADOW, 48, "smoke")
	_puff("smoke_puff", DUST, 32, 6)
	_bubble("mana_bubble", ARCANE, 44)
	_bubble("soul_bubble", VOID, 44)
	_bubble("gold_bubble", GOLD, 44)
	_snowfall("snowfall", FROST, 32)
	_arrow_rain("arrow_rain", ["f4e6c8", "c9a27a", "8a6a4a", "62788c"], 24, 48)
	# The fire mage after the user's concept sheet (30.10.2026)
	_big_fireball("fireball_big", FIRE, 48)
	_explosion("fire_explosion", FIRE, 96)
	_lance("fire_spear", FIRE, 40, 14)
	_charge("fire_charge", FIRE, 24)
	_phoenix("phoenix", FIRE, 48, 36)
	_flame_tongue("flame_tongue", FIRE, 16, 30)
	_lava_pool("lava_pool", MAGMA, 64, 36)
	_rune_circle("rune_circle", FIRE, 64)
	# The 12 signature ultimates (user decision 30.10.2026)
	_meteor("meteor", FIRE, 36, 52)
	_ice_block("ice_block", FROST, 48, 44)
	_vortex("vortex", ARCANE, 64)
	_net("net", ["f4e6c8", "d8bc8a", "a8865a", "6a5038"], 72)
	_spear("sky_spear", GOLD, 64, 18)
	_orb("soul_wisp", VOID, 12)
	# Second effects round (user, 30.10.2026): a real meteor, Pfeilhagel, more fire
	_meteor_big("meteor_big", FIRE, 64, 96)
	_meteor_impact("meteor_impact", FIRE, 128)
	_hail_arrow("hail_arrow", 12, 40)
	_arrow_impact("arrow_impact", 40)
	_fire_sparks("fire_sparks", FIRE, 96)
	var file := FileAccess.open(DATA, FileAccess.WRITE)
	file.store_string(JSON.stringify({"_note": "Generated by scripts/make_fx_sprites.gd. Each sheet is one row of frames: size [w, h] art px, frames, fps, anchor [x, y] art px (the effect's origin). Drawn at 2x.", "sheets": _meta}, "  ") + "\n")
	file.close()
	print("FX_SPRITES ", _meta.keys().size())
	quit(0)


# --- Helpers -----------------------------------------------------------------------

func _c(hex: String) -> Color:
	return Color(hex)


func _sheet(frames: int, w: int, h: int) -> Image:
	var image := Image.create_empty(frames * w, h, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	return image


func _px(image: Image, frame: int, w: int, x: int, y: int, color: Color) -> void:
	if x < 0 or y < 0 or x >= w or y >= image.get_height(): return
	image.set_pixel(frame * w + x, y, color)


## Dither: draw only on a checker (or sparser) pattern for fading pixels.
func _dither(x: int, y: int, level: int) -> bool:
	match level:
		0: return true
		1: return (x + y) % 2 == 0
		2: return (x % 2 == 0) and (y % 2 == 0)
		_: return (x % 3 == 0) and (y % 3 == 0)


func _save(name: String, image: Image, frames: int, w: int, h: int, fps: float, anchor: Vector2) -> void:
	_outline(image, w, frames)
	image.save_png(ProjectSettings.globalize_path(OUT + name + ".png"))
	_meta[name] = {"file": OUT + name + ".png", "size": [w, h], "frames": frames, "fps": fps, "anchor": [anchor.x, anchor.y]}


## A 1 px dark rim around solid pixels (not around faint dithered ones).
func _outline(image: Image, w: int, frames: int) -> void:
	var source := image.duplicate()
	var rim := Color("1a1414", 0.55)
	for frame in range(frames):
		for y in range(image.get_height()):
			for x in range(w):
				var gx := frame * w + x
				if source.get_pixel(gx, y).a > 0.0: continue
				for offset: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
					var nx := x + offset.x
					var ny := y + offset.y
					if nx < 0 or ny < 0 or nx >= w or ny >= image.get_height(): continue
					if source.get_pixel(frame * w + nx, ny).a >= 0.95:
						image.set_pixel(gx, y, rim)
						break


# --- Effects -----------------------------------------------------------------------

## Sword slash (aim = +x): a broad crescent smear sweeping 150°. A bright
## cutting edge on the outside, the steel ramp inwards and a dithered motion
## smear behind it; the tail thins out, then the whole arc fades.
func _slash(name: String, ramp: Array, size: int) -> void:
	var frames := 5
	var image := _sheet(frames, size, size)
	var center := Vector2(size * 0.36, size * 0.5)
	var outer := size * 0.46
	var sweep := [0.4, 0.75, 1.0, 1.0, 1.0]
	var shrink := [1.0, 1.0, 1.0, 0.6, 0.3]
	for frame in range(frames):
		var head := lerpf(-1.3, 1.3, sweep[frame])
		for y in range(size):
			for x in range(size):
				var offset := Vector2(x + 0.5, y + 0.5) - center
				var angle := offset.angle()
				if angle < -1.3 or angle > head: continue
				var along := (angle + 1.3) / maxf(head + 1.3, 0.01)
				var thickness := lerpf(2.0, 13.0, smoothstep(0.0, 1.0, along)) * float(shrink[frame])
				var depth := outer - offset.length()
				if depth < 0.0 or depth > thickness: continue
				var share := depth / maxf(thickness, 0.01)
				var level := 0
				if share > 0.62: level = 1
				if along < 0.25: level += 1
				if frame >= 3: level += frame - 2
				if not _dither(x, y, level): continue
				var tone := 0 if depth < 1.3 else 1 if share < 0.3 else 2 if share < 0.62 else 3
				_px(image, frame, size, x, y, _c(ramp[mini(tone + (1 if frame == 4 else 0), 3)]))
		# A glint at the blade tip while it swings.
		if frame >= 1 and frame <= 2:
			var tip := center + Vector2.from_angle(head) * (outer - 2.0)
			for dir: Vector2i in [Vector2i.ZERO, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]: _px(image, frame, size, int(tip.x) + dir.x, int(tip.y) + dir.y, _c(ramp[0]))
	_save(name, image, frames, size, size, 20.0, center)


## Whirl: a full ring of three broad blade smears turning, speed lines outside.
func _whirl(name: String, ramp: Array, size: int) -> void:
	var frames := 6
	var image := _sheet(frames, size, size)
	var center := Vector2(size, size) * 0.5
	var radius := size * 0.46
	for frame in range(frames):
		var turn := frame * 0.6
		var fade := 0 if frame < 4 else frame - 3
		for y in range(size):
			for x in range(size):
				var offset := Vector2(x + 0.5, y + 0.5) - center
				var angle := wrapf(offset.angle() - turn, 0.0, TAU)
				var segment := fmod(angle, TAU / 3.0) / (TAU / 3.0)
				if segment > 0.86: continue
				var thickness := lerpf(1.5, 10.0, segment * segment)
				var depth := radius - offset.length()
				if depth < 0.0 or depth > thickness: continue
				var share := depth / thickness
				var level := fade + (1 if share > 0.6 else 0) + (1 if segment < 0.2 else 0)
				if not _dither(x, y, level): continue
				var tone := 0 if depth < 1.3 else 1 if share < 0.3 else 2 if share < 0.6 else 3
				_px(image, frame, size, x, y, _c(ramp[tone]))
		if frame < 4:
			_rng.seed = 40 + frame
			for k in range(12):
				var a := _rng.randf() * TAU
				var r0 := radius + 2 + _rng.randi_range(0, 3)
				for step in range(4):
					var p := center + Vector2.from_angle(a + step * 0.05) * r0
					_px(image, frame, size, int(p.x), int(p.y), _c(ramp[1 if step == 0 else 2]))
	_save(name, image, frames, size, size, 20.0, center)


## Hit spark: a star that flashes out and breaks into dots.
func _spark(name: String, ramp: Array, size: int) -> void:
	var frames := 4
	var image := _sheet(frames, size, size)
	var c := Vector2i(size / 2, size / 2)
	var lengths := [size * 0.25, size * 0.42, size * 0.48, size * 0.5]
	for frame in range(frames):
		var length := int(lengths[frame])
		for dir: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]:
			var diagonal := dir.x != 0 and dir.y != 0
			var reach := length - (length / 3 if diagonal else 0)
			for i in range(reach):
				var start := 0 if frame < 2 else reach - 2
				if i < start: continue
				var tone := 0 if i < reach * 0.4 else 1 if i < reach * 0.75 else 2
				if frame == 3 and i % 2 == 1: continue
				_px(image, frame, size, c.x + dir.x * i, c.y + dir.y * i, _c(ramp[mini(tone + frame / 2, 2)]))
		if frame == 0:
			for y in range(-1, 2):
				for x in range(-1, 2): _px(image, frame, size, c.x + x, c.y + y, _c(ramp[0]))
	_save(name, image, frames, size, size, 18.0, Vector2(c))


## Smooth value noise in 0..1 (deterministic), for ragged, living edges.
func _noise(x: float, y: float, seed_value: int) -> float:
	var xi := floori(x)
	var yi := floori(y)
	var u := x - float(xi)
	var v := y - float(yi)
	u = u * u * (3.0 - 2.0 * u)
	v = v * v * (3.0 - 2.0 * v)
	var top := lerpf(_hash01(xi, yi, seed_value), _hash01(xi + 1, yi, seed_value), u)
	var bottom := lerpf(_hash01(xi, yi + 1, seed_value), _hash01(xi + 1, yi + 1, seed_value), u)
	return lerpf(top, bottom, v)


func _hash01(x: int, y: int, seed_value: int) -> float:
	return float(absi(hash(Vector3i(x, y, seed_value))) % 1024) / 1023.0


## Explosion in 9 frames: a white flash, then a cluster of round puffs that
## swells (lit from the top left: bright crowns, darker undersides), drifts
## apart and rises, cools down the colour ramp and dithers away. Element
## debris on top: smoke clouds, ice shards with a crystal ring, twinkling
## stars, or stars with a ring of runes.
func _burst(name: String, ramp: Array, size: int, debris: String) -> void:
	var frames := 9
	var image := _sheet(frames, size, size)
	var center := Vector2(size, size) * 0.5
	var full := size * 0.44
	var seed_value := absi(hash(name)) % 100000
	_rng.seed = seed_value
	var blobs: Array = []
	for i in range(7):
		blobs.append({"dir": Vector2.from_angle(TAU * float(i) / 7.0 + _rng.randf_range(-0.35, 0.35)), "reach": _rng.randf_range(0.3, 0.62), "size": _rng.randf_range(0.75, 1.1)})
	blobs.append({"dir": Vector2.ZERO, "reach": 0.0, "size": 1.25})
	var darkest := ramp.size() - 1
	for frame in range(frames):
		var t := float(frame) / float(frames - 1)
		var grow := 1.0 - pow(1.0 - minf(1.0, t * 1.9), 3.0)
		var fade := 0 if t < 0.45 else 1 if t < 0.65 else 2 if t < 0.85 else 3
		for y in range(size):
			for x in range(size):
				var p := Vector2(x + 0.5, y + 0.5)
				var heat := -1.0
				var underside := 0.0
				for blob: Dictionary in blobs:
					var middle: Vector2 = center + Vector2(blob.dir) * full * float(blob.reach) * (0.25 + grow) + Vector2(0, -full * 0.3 * t * t)
					var radius: float = full * 0.4 * float(blob.size) * (0.35 + 0.65 * grow) * (1.0 - 0.45 * t)
					if radius < 0.6: continue
					var offset := p - middle
					var value := 1.0 - offset.length() / radius + (_noise(p.x * 0.4, p.y * 0.4, seed_value + frame * 7) - 0.5) * 0.45
					if value > heat:
						heat = value
						underside = offset.dot(Vector2(0.55, 0.85)) / radius
				if heat <= 0.0 or not _dither(x, y, fade): continue
				var tone := 0 if heat > 0.72 else 1 if heat > 0.42 else 2 if heat > 0.18 else 3
				if underside > 0.35 and heat < 0.65: tone += 1
				elif underside < -0.45 and heat < 0.5: tone -= 1
				tone += int(t * 2.6)
				if frame == 0: tone = mini(tone, 1)
				_px(image, frame, size, x, y, _c(ramp[clampi(tone, 0, darkest)]))
		# The flash: a white star in the first two frames.
		if frame < 2:
			var arm := int(full * (0.55 if frame == 0 else 0.85))
			for i in range(arm):
				for dir: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
					_px(image, frame, size, int(center.x) + dir.x * i, int(center.y) + dir.y * i, _c(ramp[0 if i < arm * 0.6 else 1]))
		_debris(image, frame, frames, size, center, full, ramp, debris, seed_value)
	_save(name, image, frames, size, size, 22.0, center)


## Element details on top of a burst frame (see _burst).
func _debris(image: Image, frame: int, frames: int, size: int, center: Vector2, full: float, ramp: Array, debris: String, seed_value: int) -> void:
	var t := float(frame) / float(frames - 1)
	_rng.seed = seed_value + 31
	match debris:
		"shards":
			# Ice shards flying out with bright tips, and a crystal ring early on.
			for k in range(9):
				var direction := Vector2.from_angle(TAU * float(k) / 9.0 + _rng.randf_range(-0.2, 0.2))
				var speed := _rng.randf_range(0.7, 1.05)
				if frame == 0 or t > 0.85: continue
				var base := center + direction * full * speed * (0.35 + 0.75 * t)
				var length := int(4.0 - t * 2.0)
				for i in range(length + 1):
					var q := base + direction * float(i)
					_px(image, frame, size, int(q.x), int(q.y), _c(ramp[0 if i >= length - 1 else 2]))
			if frame >= 1 and frame <= 4:
				var ring := full * (0.5 + 0.5 * minf(1.0, t * 2.2))
				for side in range(6):
					var from := center + Vector2.from_angle(TAU * float(side) / 6.0 + PI / 6.0) * ring
					var to := center + Vector2.from_angle(TAU * float(side + 1) / 6.0 + PI / 6.0) * ring
					var steps := int(from.distance_to(to)) + 1
					for i in range(steps):
						var q := from.lerp(to, float(i) / float(steps))
						if _dither(int(q.x), int(q.y), maxi(0, frame - 2)): _px(image, frame, size, int(q.x), int(q.y), _c(ramp[1]))
		"stars", "runes":
			# Four-point stars twinkling outwards.
			for k in range(6):
				var direction := Vector2.from_angle(TAU * float(k) / 6.0 + 0.4 + _rng.randf_range(-0.25, 0.25))
				var speed := _rng.randf_range(0.8, 1.15)
				if frame == 0 or t > 0.9: continue
				var q := center + direction * full * speed * (0.45 + 0.6 * t)
				_px(image, frame, size, int(q.x), int(q.y), _c(ramp[0]))
				var arm := 2 if t < 0.5 else 1
				for i in range(1, arm + 1):
					for dir: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
						_px(image, frame, size, int(q.x) + dir.x * i, int(q.y) + dir.y * i, _c(ramp[1 if i == 1 else 2]))
			if debris == "runes" and frame >= 2 and frame <= 6:
				# A ring of rune marks turning outwards.
				var ring := full * (0.7 + 0.35 * t)
				for k in range(10):
					var q := center + Vector2.from_angle(TAU * float(k) / 10.0 + t * 1.2) * ring
					_px(image, frame, size, int(q.x), int(q.y), _c(ramp[1]))
					if _dither(k, frame, 1): _px(image, frame, size, int(q.x), int(q.y) - 1, _c(ramp[2]))
		"smoke":
			# Dark clouds rising behind the fire late on (only where nothing burns).
			if t < 0.35: return
			for k in range(4):
				var offset := Vector2(_rng.randf_range(-0.6, 0.6), _rng.randf_range(-0.2, 0.3)) * full
				var middle := center + offset + Vector2(0, -full * 0.7 * (t - 0.35))
				var radius := full * 0.22 * (1.0 + t)
				var level := 1 if t < 0.7 else 2 if t < 0.9 else 3
				for y in range(int(middle.y - radius), int(middle.y + radius) + 1):
					for x in range(int(middle.x - radius), int(middle.x + radius) + 1):
						if x < 0 or y < 0 or x >= size or y >= size: continue
						if Vector2(x + 0.5, y + 0.5).distance_to(middle) > radius or not _dither(x, y, level): continue
						if image.get_pixel(frame * size + x, y).a > 0.0: continue
						_px(image, frame, size, x, y, _c(ramp[ramp.size() - 1]))


## Glowing orb, 6 frames: a white heart, the colour body lit from the top left
## with a darker rim, and two sparks circling it on a tilted orbit.
func _orb(name: String, ramp: Array, size: int) -> void:
	var frames := 6
	var image := _sheet(frames, size, size)
	var center := Vector2(size, size) * 0.5
	for frame in range(frames):
		var phase := float(frame) / float(frames) * TAU
		var pulse := 0.35 * sin(phase)
		for y in range(size):
			for x in range(size):
				var offset := Vector2(x + 0.5, y + 0.5) - center
				var d := offset.length()
				var edge := 5.0 + pulse
				if d > edge: continue
				var lit := offset.dot(Vector2(-0.7, -0.7)) / edge
				var tone := 0 if d < 1.5 else 1 if d < 2.9 + pulse else 2 if d < 4.1 + pulse else 3
				if tone >= 2 and lit > 0.35: tone -= 1
				_px(image, frame, size, x, y, _c(ramp[tone]))
		for k in range(2):
			var spark := center + Vector2.from_angle(phase + PI * float(k)) * Vector2(6.0, 3.5)
			_px(image, frame, size, int(spark.x), int(spark.y), _c(ramp[0]))
	_save(name, image, frames, size, size, 12.0, center)


## Fireball (flying +x), 6 frames: a round flame head with a white-hot heart
## and a darker underside, two flame tongues licking back and flickering, and
## embers shed behind it.
func _fireball(name: String, ramp: Array, size: int) -> void:
	var frames := 6
	var image := _sheet(frames, size, size)
	var head := Vector2(size * 0.68, size * 0.5)
	for frame in range(frames):
		var phase := float(frame) / float(frames) * TAU
		for y in range(size):
			for x in range(size):
				var p := Vector2(x + 0.5, y + 0.5)
				var behind := head.x - p.x
				var radius := 4.6 + 0.5 * sin(phase * 2.0 + (p - head).angle() * 3.0)
				var heat := 1.0 - p.distance_to(head) / radius
				if behind > 0.0:
					for tongue in range(2):
						var wave := sin(behind * 0.55 - phase * 2.0 + float(tongue) * 2.4) * (0.6 + behind * 0.14)
						var middle := head.y + wave + (float(tongue) - 0.5) * 1.6
						var width := 3.9 * (1.0 - behind / (size * 0.62)) + 0.6 * sin(behind * 1.3 + phase * 3.0)
						if width <= 0.0: continue
						heat = maxf(heat, (1.0 - absf(p.y - middle) / width) * (1.0 - behind / (size * 0.66)))
				if heat <= 0.0: continue
				var tone := 0 if heat > 0.7 else 1 if heat > 0.45 else 2 if heat > 0.22 else 3
				if p.y > head.y + 1.5 and tone < 3 and heat < 0.6: tone += 1
				if tone >= 3 and not _dither(x + frame, y, 1): continue
				_px(image, frame, size, x, y, _c(ramp[tone]))
		_rng.seed = 900 + frame
		for k in range(3):
			var ember := head + Vector2(-_rng.randf_range(7.0, size * 0.62), _rng.randf_range(-4.0, 4.0))
			_px(image, frame, size, int(ember.x), int(ember.y), _c(ramp[_rng.randi_range(1, 2)]))
	_save(name, image, frames, size, size, 16.0, head)


## Blink (teleport), 6 frames: a ring of arcane motes rushes in, flashes in a
## bright star, then scatters as fading sparkles.
func _blink(name: String, ramp: Array, size: int) -> void:
	var frames := 6
	var image := _sheet(frames, size, size)
	var center := Vector2(size, size) * 0.5
	for frame in range(frames):
		if frame <= 2:
			var ring := size * 0.45 * (1.0 - float(frame) / 3.0)
			for k in range(12):
				var direction := Vector2.from_angle(TAU * float(k) / 12.0 + float(frame) * 0.5)
				var q := center + direction * ring * Vector2(1.0, 0.8)
				_px(image, frame, size, int(q.x), int(q.y), _c(ramp[0 if k % 3 == 0 else 1]))
				var tail := q + direction * 2.0
				_px(image, frame, size, int(tail.x), int(tail.y), _c(ramp[2]))
		if frame == 3:
			for y in range(-4, 5):
				for x in range(-4, 5):
					var distance := absi(x) + absi(y)
					if distance <= 4: _px(image, frame, size, int(center.x) + x, int(center.y) + y, _c(ramp[0 if distance <= 2 else 1]))
			for i in range(5, 11):
				for dir: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
					_px(image, frame, size, int(center.x) + dir.x * i, int(center.y) + dir.y * i, _c(ramp[1 if i < 8 else 2]))
		if frame >= 3:
			_rng.seed = 50
			var spread := float(frame - 2) / 3.0
			for k in range(10):
				var q := center + Vector2.from_angle(_rng.randf() * TAU) * size * 0.45 * _rng.randf_range(0.35, 1.0) * spread
				if frame == 5 and k % 2 == 1: continue
				_px(image, frame, size, int(q.x), int(q.y), _c(ramp[0 if frame < 5 else 1]))
				if frame == 3 or k % 3 == 0:
					for dir: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]: _px(image, frame, size, int(q.x) + dir.x, int(q.y) + dir.y, _c(ramp[2]))
	_save(name, image, frames, size, size, 16.0, center)


## Blade wave (flying +x): a bright crescent with a cool glow.
func _wave(name: String, ramp: Array, w: int, h: int) -> void:
	var frames := 3
	var image := _sheet(frames, w, h)
	var center := Vector2(w * 0.25, h * 0.5)
	var outer := h * 0.46
	for frame in range(frames):
		for y in range(h):
			for x in range(w):
				var offset := Vector2(x + 0.5, y + 0.5) - center
				var angle := absf(offset.angle())
				if angle > 1.2: continue
				var thickness := lerpf(6.0, 1.0, angle / 1.2) + (1.0 if frame == 1 else 0.0)
				var depth := outer - offset.length()
				if depth < 0 or depth > thickness: continue
				var tone := 0 if depth < 1.5 else 1 if depth < thickness * 0.5 else 2 if depth < thickness * 0.8 else 3
				if angle > 0.9 and not _dither(x + frame, y, 1): continue
				_px(image, frame, w, x, y, _c(ramp[tone]))
	_save(name, image, frames, w, h, 14.0, Vector2(w * 0.5, h * 0.5))


## Smoke puff: a few round clouds that swell and thin out.
func _puff(name: String, ramp: Array, size: int, frames: int) -> void:
	var image := _sheet(frames, size, size)
	var center := Vector2(size, size) * 0.5
	var blobs := [Vector2(-3, 1), Vector2(3, 1), Vector2(0, -2), Vector2(-1, 3), Vector2(2, -3)]
	for frame in range(frames):
		var grow := 1.0 + frame * 0.5
		for blob: Vector2 in blobs:
			var c := center + blob * grow
			var r := size * 0.16 + frame * 0.6
			for y in range(size):
				for x in range(size):
					var d := (Vector2(x + 0.5, y + 0.5) - c).length()
					if d > r: continue
					if not _dither(x, y, maxi(0, frame - 2)): continue
					var tone := 0 if d < r * 0.35 and frame < 2 else 1 if d < r * 0.7 else 2
					_px(image, frame, size, x, y, _c(ramp[mini(tone + frame / 2, 3)]))
	_save(name, image, frames, size, size, 16.0, center)


## Level-up: a golden ring at the feet and sparkles rising in a column.
func _level_up(name: String, ramp: Array, w: int, h: int) -> void:
	var frames := 6
	var image := _sheet(frames, w, h)
	var foot := Vector2(w * 0.5, h - 6)
	for frame in range(frames):
		var ring := 6.0 + frame * 2.2
		for y in range(h):
			for x in range(w):
				var offset := Vector2(x + 0.5, y + 0.5) - foot
				var ellipse := Vector2(offset.x, offset.y * 2.4).length()
				if absf(ellipse - ring) < 1.2 and _dither(x, y, maxi(0, frame - 3)): _px(image, frame, w, x, y, _c(ramp[1 if frame < 3 else 2]))
		_rng.seed = 77
		for k in range(12):
			var x := int(foot.x + _rng.randf_range(-w * 0.32, w * 0.32))
			var y := int(foot.y - _rng.randf_range(4, 12) - frame * _rng.randf_range(5, 8))
			var tone := 0 if k % 3 == 0 else 1
			_px(image, frame, w, x, y, _c(ramp[tone]))
			if k % 3 == 0:
				for dir: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]: _px(image, frame, w, x + dir.x, y + dir.y, _c(ramp[2]))
	_save(name, image, frames, w, h, 12.0, foot)


## Pickup: a four-point star twinkling and spinning out.
func _twinkle(name: String, ramp: Array, size: int) -> void:
	var frames := 5
	var image := _sheet(frames, size, size)
	var c := Vector2i(size / 2, size / 2)
	for frame in range(frames):
		var length: int = [3, 7, 10, 8, 4][frame]
		var diagonal := frame % 2 == 1
		for i in range(length):
			var tone := 0 if i < 2 else 1 if i < length * 0.7 else 2
			for dir: Vector2i in ([Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)] if diagonal else [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]):
				var reach := i if not diagonal else int(i * 0.7)
				_px(image, frame, size, c.x + dir.x * reach, c.y + dir.y * reach, _c(ramp[tone]))
	_save(name, image, frames, size, size, 14.0, Vector2(c))


## Rage aura (drawn behind the hero): a hollow flame halo, an ellipse at the
## feet with tongues licking up the sides and over the head.
func _aura(name: String, ramp: Array, w: int, h: int) -> void:
	var frames := 4
	var image := _sheet(frames, w, h)
	var base := Vector2(w * 0.5, h - 6)
	for frame in range(frames):
		for y in range(h):
			for x in range(w):
				var p := Vector2(x + 0.5, y + 0.5)
				# Distance from an egg shape around the body.
				var q := Vector2((p.x - base.x) / (w * 0.42), (p.y - (base.y - h * 0.42)) / (h * 0.52))
				var r := q.length()
				var lick := 0.12 * sin(atan2(q.y, q.x) * 7.0 + frame * 1.9) + 0.06 * sin(atan2(q.y, q.x) * 13.0 - frame * 2.7)
				var top := 1.0 + (lick if q.y < 0.2 else lick * 0.3)
				if r > top or r < top - 0.32: continue
				var t := (top - r) / 0.32
				var tone := 0 if t > 0.75 else 1 if t > 0.45 else 2 if t > 0.2 else 3
				if t < 0.2 and not _dither(x + frame, y, 1): continue
				_px(image, frame, w, x, y, _c(ramp[tone]))
	_save(name, image, frames, w, h, 12.0, base)


## Splinters: 2x2 chips flying out of an impact, dropping as they go.
func _splinters(name: String, ramp: Array, size: int) -> void:
	var frames := 5
	var image := _sheet(frames, size, size)
	var center := Vector2(size, size) * 0.5
	_rng.seed = hash(name)
	var chips: Array = []
	for k in range(10): chips.append({"a": _rng.randf() * TAU, "v": _rng.randf_range(0.45, 1.0), "tone": _rng.randi_range(0, 2)})
	for frame in range(frames):
		for chip: Dictionary in chips:
			var dist := size * 0.46 * float(chip.v) * (frame + 1) / frames
			var p: Vector2 = center + Vector2.from_angle(float(chip.a)) * dist + Vector2(0, frame * frame * 0.5)
			var tone := mini(int(chip.tone) + frame / 3, 2)
			for dy in range(2):
				for dx in range(2 if frame < 4 else 1): _px(image, frame, size, int(p.x) + dx, int(p.y) + dy, _c(ramp[tone]))
		if frame == 0:
			for dy in range(-2, 3):
				for dx in range(-2, 3):
					if absi(dx) + absi(dy) <= 2: _px(image, frame, size, int(center.x) + dx, int(center.y) + dy, _c("ffffff" if absi(dx) + absi(dy) <= 1 else ramp[0]))
	_save(name, image, frames, size, size, 18.0, center)


## Stairwell behind an open gate (32x32, the door leaf's opening): steps going
## down into darkness for the way on (deeper), or up towards a warm light for
## the way back. One frame, no outline.
func _stairwell(name: String, down: bool) -> void:
	var size := 32
	var image := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color("120d0d"))
	var steps := 6
	for i in range(steps):
		var bottom := 30 - i * 4
		var top := bottom - 4
		var t := float(i) / float(steps - 1)
		var half := lerpf(12.0, 6.0, t) if down else lerpf(11.0, 9.0, t)
		var tread: Color
		var riser: Color
		if down:
			tread = Color("9a887c").lerp(Color("1c1515"), t * 0.95)
			riser = tread.darkened(0.45)
		else:
			tread = Color("4a3e3a").lerp(Color("d8c2a4"), t)
			riser = tread.darkened(0.35)
		for y in range(top, bottom):
			for x in range(int(16 - half), int(16 + half)):
				var color := tread if (down and y < top + 3) or (not down and y >= top + 1) else riser
				if (down and y == top) or (not down and y == top + 1): color = color.lightened(0.18)
				if x >= 0 and y >= 0 and x < size and y < size: image.set_pixel(x, y, color)
	if not down:
		# Light from the room above spills down the steps.
		for y in range(0, 8):
			for x in range(8, 24):
				var glow := Color("ffd890", 0.35 * (1.0 - y / 8.0))
				image.set_pixel(x, y, image.get_pixel(x, y).blend(glow))
	image.save_png(ProjectSettings.globalize_path(OUT + name + ".png"))


# --- Talent attacks ------------------------------------------------------------------

## Nova ring, 8 frames: a ring of flame, ice or light rushes out from the caster
## to the sheet's edge, thick and white-hot first, then thinning and breaking
## up in a dither; tongues of noise along its outside and a short-lived glow
## inside. The game scales it so the ring's edge meets the talent's radius.
func _nova(name: String, ramp: Array, size: int, debris: String) -> void:
	var frames := 8
	var image := _sheet(frames, size, size)
	var center := Vector2(size, size) * 0.5
	var full := size * 0.47
	var seed_value := absi(hash(name)) % 100000
	var darkest := ramp.size() - 1
	for frame in range(frames):
		var t := float(frame) / float(frames - 1)
		var r := full * (0.16 + 0.84 * (1.0 - pow(1.0 - t, 2.2)))
		var thick := lerpf(full * 0.32, full * 0.07, t)
		var fade := 0 if t < 0.5 else 1 if t < 0.78 else 2
		for y in range(size):
			for x in range(size):
				var p := Vector2(x + 0.5, y + 0.5)
				var d := p.distance_to(center)
				var a := (p - center).angle()
				var tongue := (_noise(cos(a) * 4.0 + float(frame) * 0.9, sin(a) * 4.0, seed_value) - 0.5) * thick * 1.3
				var outer := r + maxf(0.0, tongue)
				var inner := r - thick
				if d < inner:
					if t < 0.45 and d > inner * 0.35 and _dither(x, y, 2): _px(image, frame, size, x, y, _c(ramp[darkest - 1]))
					continue
				if d > outer: continue
				if not _dither(x, y, fade): continue
				var heat := 1.0 - absf(d - (r - thick * 0.3)) / (thick * 0.85)
				var tone := 0 if heat > 0.7 else 1 if heat > 0.4 else 2 if heat > 0.1 else 3
				tone += int(t * 2.2)
				_px(image, frame, size, x, y, _c(ramp[clampi(tone, 0, darkest)]))
		_rng.seed = seed_value + frame
		match debris:
			"embers", "motes":
				for k in range(14):
					var q := center + Vector2.from_angle(_rng.randf() * TAU) * (r + _rng.randf_range(-thick, thick * 1.6))
					if debris == "embers": q.y -= t * 6.0
					if frame < frames - 1: _px(image, frame, size, int(q.x), int(q.y), _c(ramp[_rng.randi_range(0, 1)]))
			"shards":
				for k in range(12):
					var direction := Vector2.from_angle(TAU * float(k) / 12.0 + 0.2)
					var base := center + direction * (r + 2.0)
					if t > 0.85: continue
					for i in range(4):
						var q := base + direction * float(i)
						_px(image, frame, size, int(q.x), int(q.y), _c(ramp[0 if i >= 2 else 1]))
	_save(name, image, frames, size, size, 18.0, center)


## Inferno, 10 frames: a column of fire bursts up from a burning ring on the
## floor, roars, then sinks into smoke and embers. Anchor at its foot.
func _pillar(name: String, ramp: Array, w: int, h: int) -> void:
	var frames := 10
	var image := _sheet(frames, w, h)
	var foot := Vector2(w * 0.5, h - 10.0)
	var seed_value := absi(hash(name)) % 100000
	var darkest := ramp.size() - 1
	for frame in range(frames):
		var t := float(frame) / float(frames - 1)
		var rise := minf(1.0, t * 3.0)
		var shrink := 1.0 if t < 0.55 else 1.0 - (t - 0.55) / 0.45
		var top := (h - 14.0) * rise
		var fade := 0 if t < 0.6 else 1 if t < 0.8 else 2
		for y in range(h):
			for x in range(w):
				var up := foot.y - (y + 0.5)
				var dx := absf(x + 0.5 - foot.x)
				# the burning ring on the floor (an ellipse)
				var ring := Vector2(dx / (w * 0.46), (y + 0.5 - foot.y) / 7.0).length()
				if ring <= 1.0 and ring > 0.6 and t < 0.9 and _dither(x, y, fade):
					_px(image, frame, w, x, y, _c(ramp[clampi(1 + int(t * 3.0) + (1 if ring > 0.85 else 0), 0, darkest)]))
					continue
				if up < -2.0 or up > top: continue
				var k := up / maxf(top, 1.0)
				var flicker := _noise(x * 0.22, (y + frame * 7) * 0.16, seed_value) - 0.5
				var width := w * 0.30 * shrink * (1.0 - k * 0.7) + flicker * 9.0
				if width <= 0.0 or dx > width: continue
				if not _dither(x, y, fade): continue
				var heat := 1.0 - dx / width * 0.75 - k * 0.45 + flicker * 0.5
				var tone := 0 if heat > 0.7 else 1 if heat > 0.45 else 2 if heat > 0.2 else 3
				if t > 0.6: tone += 1
				_px(image, frame, w, x, y, _c(ramp[clampi(tone, 0, darkest)]))
		_rng.seed = seed_value + frame
		for k in range(10):
			var q := foot + Vector2(_rng.randf_range(-w * 0.4, w * 0.4), -_rng.randf_range(0.0, top + 8.0))
			_px(image, frame, w, int(q.x), int(q.y), _c(ramp[_rng.randi_range(0, 2)]))
	_save(name, image, frames, w, h, 14.0, foot)


## Shield bubble (looping), 6 frames: a pale dome around the hero with a bright
## rim, a dithered skin and a highlight that wanders around it.
func _bubble(name: String, ramp: Array, size: int) -> void:
	var frames := 6
	var image := _sheet(frames, size, size)
	var center := Vector2(size, size) * 0.5
	var radius := size * 0.45
	for frame in range(frames):
		var shine := TAU * float(frame) / float(frames)
		for y in range(size):
			for x in range(size):
				var p := Vector2(x + 0.5, y + 0.5)
				var d := p.distance_to(center)
				if d > radius: continue
				var a := (p - center).angle()
				var glint := cos(a - shine)
				if d > radius - 1.5:
					_px(image, frame, size, x, y, _c(ramp[0 if glint > 0.6 else 1 if glint > -0.2 else 2]))
				elif d > radius - 3.0 and glint > 0.75:
					_px(image, frame, size, x, y, _c(ramp[0]))
				elif _dither(x + frame, y, 2):
					_px(image, frame, size, x, y, Color(_c(ramp[2]), 0.55))
	_save(name, image, frames, size, size, 10.0, center)


## Ice lance (flying +x), 4 frames: a long crystal with a white tip, facets in
## the frost ramp and a trail of glittering motes.
func _lance(name: String, ramp: Array, w: int, h: int) -> void:
	var frames := 4
	var image := _sheet(frames, w, h)
	var tip := Vector2(w - 2.0, h * 0.5)
	for frame in range(frames):
		for y in range(h):
			for x in range(w):
				var p := Vector2(x + 0.5, y + 0.5)
				var back := tip.x - p.x
				if back < 0.0 or back > w * 0.62: continue
				var half := minf(back * 0.45, 4.2 - back * 0.12)
				var dy := p.y - tip.y
				if absf(dy) > half: continue
				var tone := 0 if back < 3.0 else (1 if dy < 0.0 else 2)
				if absf(dy) > half - 1.0 and back > 3.0: tone = 3
				_px(image, frame, w, x, y, _c(ramp[tone]))
		_rng.seed = 70 + frame
		for k in range(5):
			var q := Vector2(_rng.randf_range(0.0, w * 0.4), tip.y + _rng.randf_range(-3.0, 3.0))
			_px(image, frame, w, int(q.x), int(q.y), _c(ramp[_rng.randi_range(0, 1)]))
	_save(name, image, frames, w, h, 14.0, tip - Vector2(6, 0))


## Target mark (looping), 6 frames: four corner brackets that turn and pulse
## around a small diamond.
func _reticle(name: String, ramp: Array, size: int) -> void:
	var frames := 6
	var image := _sheet(frames, size, size)
	var center := Vector2(size, size) * 0.5
	for frame in range(frames):
		var turn := float(frame) / float(frames) * (PI * 0.5)
		var reach := size * (0.40 + 0.05 * sin(float(frame) / float(frames) * TAU))
		for corner in range(4):
			var a := turn + PI * 0.25 + PI * 0.5 * corner
			var at := center + Vector2.from_angle(a) * reach
			for i in range(5):
				for side: float in [-1.0, 1.0]:
					var q := at + Vector2.from_angle(a + PI + side * PI * 0.75) * float(i)
					_px(image, frame, size, int(q.x), int(q.y), _c(ramp[0 if i < 2 else 1]))
		for y in range(-2, 3):
			for x in range(-2, 3):
				if absi(x) + absi(y) <= 2: _px(image, frame, size, int(center.x) + x, int(center.y) + y, _c(ramp[0 if absi(x) + absi(y) <= 1 else 2]))
	_save(name, image, frames, size, size, 8.0, center)


## Poison cloud (looping), 8 frames: lumpy green blobs that churn in place with
## a dithered edge and light bubbles; the game spreads a few over a zone.
func _cloud(name: String, ramp: Array, size: int) -> void:
	var frames := 8
	var image := _sheet(frames, size, size)
	var center := Vector2(size, size) * 0.5
	var seed_value := absi(hash(name)) % 100000
	for frame in range(frames):
		var phase := float(frame) / float(frames) * TAU
		for y in range(size):
			for x in range(size):
				var p := Vector2(x + 0.5, y + 0.5)
				var d := p.distance_to(center) / (size * 0.46)
				var n := _noise(p.x * 0.12 + cos(phase) * 1.5, p.y * 0.12 + sin(phase) * 1.5, seed_value)
				var v := 1.0 - d + (n - 0.5) * 0.7
				if v <= 0.0: continue
				if v < 0.18 and not _dither(x, y, 1): continue
				var tone := 1 if v > 0.55 else 2 if v > 0.3 else 3
				if n > 0.72 and v > 0.4: tone = 0
				_px(image, frame, size, x, y, Color(_c(ramp[tone]), 0.85))
	_save(name, image, frames, size, size, 6.0, center)


## Spike trap, 6 frames: steel spikes shoot up from a ring on the floor, hold,
## and sink back; frame 0 is the armed trap.
func _spikes(name: String, ramp: Array, size: int) -> void:
	var frames := 6
	var image := _sheet(frames, size, size)
	var center := Vector2(size * 0.5, size * 0.62)
	var heights := [0.0, 0.6, 1.0, 1.0, 0.7, 0.3]
	for frame in range(frames):
		for y in range(size):
			for x in range(size):
				var q := Vector2((x + 0.5 - center.x) / (size * 0.42), (y + 0.5 - center.y) / (size * 0.2))
				var ring := q.length()
				if ring <= 1.0 and ring > 0.7: _px(image, frame, size, x, y, _c(ramp[3]))
				elif ring <= 0.7 and _dither(x, y, 1): _px(image, frame, size, x, y, _c("2a2430"))
		for k in range(7):
			var base := center + Vector2((float(k) - 3.0) * size * 0.11, (absf(float(k) - 3.0) - 1.5) * 1.5)
			var length := int(round(float(heights[frame]) * size * 0.42 * (1.0 - absf(float(k) - 3.0) * 0.12)))
			if length <= 0:
				_px(image, frame, size, int(base.x), int(base.y), _c(ramp[1]))
				continue
			for i in range(length):
				var width := 1 if i > length * 0.6 else 2
				for j in range(width):
					_px(image, frame, size, int(base.x) + j, int(base.y) - i, _c(ramp[0 if i > length - 3 else (1 if j == 0 else 2)]))
	_save(name, image, frames, size, size, 16.0, center)


## Claw rake, 5 frames: three parallel tears across the target, drawn in, then
## fading; for the wolf's pounce and bite.
func _claw(name: String, ramp: Array, size: int) -> void:
	var frames := 5
	var image := _sheet(frames, size, size)
	var reach := [0.45, 1.0, 1.0, 1.0, 1.0]
	var fade := [0, 0, 0, 1, 2]
	for frame in range(frames):
		for k in range(3):
			var start := Vector2(size * 0.2 + k * 7.0, size * 0.15)
			var stop := Vector2(size * 0.05 + k * 7.0 + size * 0.3, size * 0.85)
			var full_length := start.distance_to(stop)
			var steps := int(full_length * float(reach[frame]))
			for i in range(steps):
				var t := float(i) / maxf(1.0, full_length)
				var q := start.lerp(stop, t)
				var thick := 1 if t < 0.15 or t > 0.8 else 2
				for j in range(thick):
					if _dither(int(q.x) + j, int(q.y), int(fade[frame])):
						_px(image, frame, size, int(q.x) + j, int(q.y), _c(ramp[0 if j == 0 and t > 0.3 and t < 0.7 else 1 if j == 0 else 2]))
	_save(name, image, frames, size, size, 16.0, Vector2(size, size) * 0.5)


# --- Ultimates (user decision 30.10.2026) ---------------------------------------

## Meteor, 6 frames looping while it falls (from the top right to the bottom
## left): a cratered rock with a hot rim and a long tongue of fire behind it.
func _meteor(name: String, ramp: Array, w: int, h: int) -> void:
	var frames := 6
	var image := _sheet(frames, w, h)
	var rock := Vector2(w * 0.38, h * 0.74)
	var back := Vector2(0.55, -1.0).normalized()
	var rock_ramp := ["d8c8b8", "9a8474", "6a5448", "3e3028"]
	for frame in range(frames):
		var phase := float(frame) / float(frames) * TAU
		for y in range(h):
			for x in range(w):
				var p := Vector2(x + 0.5, y + 0.5)
				var rel := p - rock
				var along := rel.dot(back)
				var side := rel.dot(back.orthogonal())
				var heat := 0.0
				if along > 0.0:
					var width := 7.5 * (1.0 - along / (h * 0.85)) + 1.2 * sin(along * 0.5 - phase * 2.0)
					if width > 0.0: heat = (1.0 - absf(side + sin(along * 0.35 + phase) * 1.5) / width) * (1.0 - along / (h * 0.9))
				if rel.length() <= 9.5: heat = maxf(heat, 0.55)
				if heat <= 0.0: continue
				var tone := 0 if heat > 0.75 else 1 if heat > 0.5 else 2 if heat > 0.28 else 3
				if tone >= 3 and not _dither(x + frame, y, 1): continue
				_px(image, frame, w, x, y, _c(ramp[tone]))
		# the rock itself: lit from the top right, two craters
		for y in range(h):
			for x in range(w):
				var rel := Vector2(x + 0.5, y + 0.5) - rock
				if rel.length() > 7.0: continue
				var light := -rel.dot(back) / 7.0
				var tone := 1 if light > 0.35 else 2 if light > -0.3 else 3
				if Vector2(x, y).distance_to(rock + Vector2(-2, 1)) < 1.6 or Vector2(x, y).distance_to(rock + Vector2(2, -2)) < 1.2: tone = 3
				if light > 0.7: tone = 0
				_px(image, frame, w, x, y, _c(rock_ramp[tone]))
		_rng.seed = 1300 + frame
		for k in range(5):
			var ember := rock + back * _rng.randf_range(10.0, h * 0.7) + back.orthogonal() * _rng.randf_range(-6.0, 6.0)
			_px(image, frame, w, int(ember.x), int(ember.y), _c(ramp[_rng.randi_range(0, 2)]))
	_save(name, image, frames, w, h, 14.0, rock)


## Ice block, 8 frames looping: a cluster of tall crystals with hard light
## faces and a glint running up them (Gletschergrab).
func _ice_block(name: String, ramp: Array, w: int, h: int) -> void:
	var frames := 8
	var image := _sheet(frames, w, h)
	var crystals := [[24, 40, 7, 34], [13, 40, 6, 24], [35, 41, 6, 26], [7, 42, 4, 14], [42, 42, 4, 15], [19, 42, 4, 16], [30, 42, 4, 18]]
	for frame in range(frames):
		for c: Array in crystals:
			var cx := float(c[0])
			var base := float(c[1])
			var half := float(c[2])
			var tall := float(c[3])
			for y in range(int(base - tall), int(base) + 1):
				var t := (base - float(y)) / tall
				var width := half * (1.0 - maxf(0.0, t - 0.72) / 0.28) if t > 0.72 else half
				for x in range(int(cx - width), int(cx + width) + 1):
					var d := (float(x) + 0.5 - cx) / maxf(1.0, width)
					var tone := 1 if d < -0.25 else 2 if d < 0.4 else 3
					if absf(d) < 0.12: tone = 0
					var glint := int(fmod(float(frame) * tall / 8.0 + cx, tall))
					if absf(float(base - y) - glint) < 1.0 and d < 0.3: tone = 0
					_px(image, frame, w, x, y, _c(ramp[tone]))
		for x in range(2, w - 2):
			if _dither(x + frame, 0, 1): _px(image, frame, w, x, h - 2, _c(ramp[2]))
	_save(name, image, frames, w, h, 8.0, Vector2(w * 0.5, h - 3))


## Vortex, 8 frames looping: four spiral arms of arcane light winding into a
## dark heart (Singularität).
func _vortex(name: String, ramp: Array, size: int) -> void:
	var frames := 8
	var image := _sheet(frames, size, size)
	var center := Vector2(size * 0.5, size * 0.5)
	for frame in range(frames):
		var turn := float(frame) / float(frames) * TAU * 0.25
		for y in range(size):
			for x in range(size):
				var rel := Vector2(x + 0.5, y + 0.5) - center
				var r := rel.length() / (size * 0.5)
				if r > 1.0: continue
				var arm := fmod(rel.angle() + r * 5.0 - turn + TAU * 4.0, TAU / 4.0) / (TAU / 4.0)
				var strength := (1.0 - absf(arm - 0.5) * 2.0) * (1.0 - r)
				if r < 0.16:
					_px(image, frame, size, x, y, _c("1a1030") if r < 0.1 else _c(ramp[3]))
					continue
				if strength < 0.12: continue
				var tone := 0 if strength > 0.6 else 1 if strength > 0.4 else 2 if strength > 0.24 else 3
				if tone >= 3 and not _dither(x + frame, y, 1): continue
				_px(image, frame, size, x, y, _c(ramp[tone]))
	_save(name, image, frames, size, size, 12.0, center)


## Net, 5 frames: a hunter's net flies open and drops flat, knotted rope in a
## diamond weave with weights at the rim (Jagdgrund).
func _net(name: String, ramp: Array, size: int) -> void:
	var frames := 5
	var image := _sheet(frames, size, size)
	var center := Vector2(size * 0.5, size * 0.5)
	for frame in range(frames):
		var open := 0.35 + 0.65 * float(frame) / float(frames - 1)
		var radius := size * 0.47 * open
		for y in range(size):
			for x in range(size):
				var rel := Vector2(x + 0.5, y + 0.5) - center
				if rel.length() > radius: continue
				var u := (rel.x + rel.y) / (7.0 * open)
				var v := (rel.x - rel.y) / (7.0 * open)
				var on_rope := absf(u - roundf(u)) < 0.09 / open or absf(v - roundf(v)) < 0.09 / open
				var knot := absf(u - roundf(u)) < 0.16 and absf(v - roundf(v)) < 0.16
				if rel.length() > radius - 1.5: _px(image, frame, size, x, y, _c(ramp[2]))
				elif knot: _px(image, frame, size, x, y, _c(ramp[0]))
				elif on_rope: _px(image, frame, size, x, y, _c(ramp[1 if rel.y < 0 else 2]))
		for k in range(8):
			var at := center + Vector2.from_angle(TAU * k / 8.0) * radius
			for oy in range(-1, 2):
				for ox in range(-1, 2):
					_px(image, frame, size, int(at.x) + ox, int(at.y) + oy, _c(ramp[3]))
	_save(name, image, frames, size, size, 14.0, center)


## Sky spear, 4 frames looping: a giant golden arrow (aim = +x) with a bright
## head, fletching and a shimmer running along the shaft (Himmelsspeer).
func _spear(name: String, ramp: Array, w: int, h: int) -> void:
	var frames := 4
	var image := _sheet(frames, w, h)
	var mid := h / 2
	for frame in range(frames):
		for x in range(6, w - 12):
			for dy in range(-1, 2):
				var tone := 1 if dy < 0 else 2
				if (x + frame * 6) % 24 < 3: tone = 0
				_px(image, frame, w, x, mid + dy, _c(ramp[tone]))
		for i in range(12):
			for dy in range(-(11 - i) / 2, (11 - i) / 2 + 1):
				_px(image, frame, w, w - 12 + i, mid + dy, _c(ramp[0] if absf(dy) < 1 else ramp[1]))
		for i in range(10):
			for side in [-1, 1]:
				for k in range(3):
					_px(image, frame, w, 2 + i, mid + side * (2 + k + (i / 3)), _c(ramp[2 if k == 0 else 3]))
	_save(name, image, frames, w, h, 12.0, Vector2(w - 2, mid))


# --- Talent shots and fields (user decision 30.10.2026) ---------------------------

## Throwing knife (flying +x), 4 frames: a short steel blade with a dark grip
## that turns end over end.
func _knife(name: String, ramp: Array, size: int) -> void:
	var frames := 4
	var image := _sheet(frames, size, size)
	var center := Vector2(size, size) * 0.5
	for frame in range(frames):
		var turn := float(frame) / float(frames) * TAU
		var along := Vector2.from_angle(turn)
		for i in range(-6, 7):
			var q := center + along * float(i) * 0.9
			var tone := 0 if i > 3 else 1 if i > 0 else 3
			_px(image, frame, size, int(q.x), int(q.y), _c(ramp[tone]) if i > -2 else _c("5a3a2a"))
			if i > -2 and i < 4:
				var side := q + along.orthogonal()
				_px(image, frame, size, int(side.x), int(side.y), _c(ramp[2]))
	_save(name, image, frames, size, size, 16.0, center)


## Cursed skull (flying +x), 6 frames: a small bone skull with green eye
## light and a trail of sickly flame.
func _curse_skull(name: String, ramp: Array, size: int) -> void:
	var frames := 6
	var image := _sheet(frames, size, size)
	var head := Vector2(size * 0.66, size * 0.5)
	for frame in range(frames):
		var phase := float(frame) / float(frames) * TAU
		for y in range(size):
			for x in range(size):
				var p := Vector2(x + 0.5, y + 0.5)
				var behind := head.x - p.x
				if behind <= 0.0: continue
				var wave := sin(behind * 0.7 - phase * 2.0) * 1.2
				var width := 4.0 * (1.0 - behind / (size * 0.66))
				if width <= 0.0 or absf(p.y - head.y - wave) > width: continue
				var tone := 1 if absf(p.y - head.y - wave) < width * 0.4 else 2
				if behind > size * 0.4 and not _dither(x + frame, y, 1): continue
				_px(image, frame, size, x, y, _c(ramp[tone]))
		for y in range(-4, 4):
			for x in range(-4, 5):
				if x * x + y * y > 18: continue
				var tone := "f2e6d0" if x < 2 else "c9b49a"
				if y == -1 and (x == -2 or x == 1): tone = ramp[0]
				if y == 2 and absi(x) <= 2 and x % 2 == 0: tone = "3a2a2a"
				_px(image, frame, size, int(head.x) + x, int(head.y) + y, _c(tone))
	_save(name, image, frames, size, size, 14.0, head)


## Snowfall (looping), 8 frames: flakes drift down and sideways over a field
## (Blizzard); the game spreads a few over the zone.
func _snowfall(name: String, ramp: Array, size: int) -> void:
	var frames := 8
	var image := _sheet(frames, size, size)
	for frame in range(frames):
		_rng.seed = 4100
		for k in range(14):
			var x0 := _rng.randf_range(0.0, size)
			var y0 := _rng.randf_range(0.0, size)
			var fall := float(frame) / float(frames) * size
			var at := Vector2(fmod(x0 + fall * 0.4, size), fmod(y0 + fall, size))
			var big := k % 4 == 0
			_px(image, frame, size, int(at.x), int(at.y), _c(ramp[0]))
			if big:
				for o: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
					_px(image, frame, size, int(at.x) + o.x, int(at.y) + o.y, _c(ramp[1]))
	_save(name, image, frames, size, size, 10.0, Vector2(size, size) * 0.5)


## Arrow rain (looping), 6 frames: three arrows plunge in a slant, one after
## the other (Pfeilregen).
func _arrow_rain(name: String, ramp: Array, w: int, h: int) -> void:
	var frames := 6
	var image := _sheet(frames, w, h)
	var down := Vector2(-0.3, 1.0).normalized()
	for frame in range(frames):
		for k in range(3):
			var t := fmod(float(frame) / float(frames) + float(k) / 3.0, 1.0)
			var tip := Vector2(6.0 + k * 7.0 + 8.0 * (1.0 - t) * 0.3, t * (h + 10.0) - 4.0)
			for i in range(12):
				var q := tip - down * float(i)
				var tone := 3 if i < 2 else 1 if i < 9 else 0
				_px(image, frame, w, int(q.x), int(q.y), _c(ramp[tone]))
			var back := tip - down * 11.0
			_px(image, frame, w, int(back.x) - 1, int(back.y), _c(ramp[2]))
			_px(image, frame, w, int(back.x) + 1, int(back.y), _c(ramp[2]))
	_save(name, image, frames, w, h, 12.0, Vector2(w, h) * 0.5)


# --- The fire mage (concept sheet, 30.10.2026) ------------------------------------

## Charge, 6 frames: a glowing core at the staff tip swells while sparks are
## drawn in from all sides (the Feuerball before it flies).
func _charge(name: String, ramp: Array, size: int) -> void:
	var frames := 6
	var image := _sheet(frames, size, size)
	var center := Vector2(size, size) * 0.5
	for frame in range(frames):
		var grow := 2.0 + 5.0 * float(frame) / float(frames - 1)
		for y in range(size):
			for x in range(size):
				var d := Vector2(x + 0.5, y + 0.5).distance_to(center) / grow
				if d > 1.0: continue
				_px(image, frame, size, x, y, _c(ramp[0 if d < 0.4 else 1 if d < 0.7 else 2]))
		for k in range(8):
			var a := TAU * k / 8.0 + frame * 0.4
			var r := size * 0.5 - 1.0 - float(frame) * 1.2
			var q := center + Vector2.from_angle(a) * maxf(grow + 2.0, r)
			_px(image, frame, size, int(q.x), int(q.y), _c(ramp[1 + k % 2]))
	_save(name, image, frames, size, size, 14.0, center)


## Phoenix, 6 frames looping (flying +x): a bird of flame, wings beating, a
## long burning tail behind it (Phönixschritt).
func _phoenix(name: String, ramp: Array, w: int, h: int) -> void:
	var frames := 6
	var image := _sheet(frames, w, h)
	var body := Vector2(w * 0.62, h * 0.55)
	for frame in range(frames):
		var beat := sin(float(frame) / float(frames) * TAU)
		for y in range(h):
			for x in range(w):
				var p := Vector2(x + 0.5, y + 0.5)
				var rel := p - body
				var heat := 0.0
				# body and head
				heat = maxf(heat, 1.0 - Vector2(rel.x / 7.0, rel.y / 3.2).length())
				heat = maxf(heat, 1.0 - (p - (body + Vector2(8, -2))).length() / 3.2)
				# wings: two swept triangles that rise and fall with the beat
				for side: float in [-1.0, 1.0]:
					var lift := beat * 9.0 * side
					var tip := body + Vector2(-6, side * 14.0 - lift * 0.4)
					var along := Geometry2D.get_closest_point_to_segment(p, body + Vector2(3, 0), tip)
					var span := (along - (body + Vector2(3, 0))).length() / maxf(1.0, (tip - body).length())
					heat = maxf(heat, (1.0 - p.distance_to(along) / (4.5 * (1.0 - span * 0.7))) * (1.0 - span * 0.35))
				# tail: three flame tongues trailing to the left
				if rel.x < -4.0:
					for tongue in range(3):
						var wave := sin(-rel.x * 0.4 + float(frame) * 1.3 + tongue * 2.0) * 2.0
						var middle := float(tongue - 1) * 3.0 + wave
						var width := 2.6 * (1.0 + rel.x / (w * 0.62))
						if width > 0.0: heat = maxf(heat, (1.0 - absf(rel.y - middle) / width) * (1.0 + rel.x / (w * 0.62)))
				if heat <= 0.0: continue
				var tone := 0 if heat > 0.7 else 1 if heat > 0.45 else 2 if heat > 0.22 else 3
				if tone >= 3 and not _dither(x + frame, y, 1): continue
				_px(image, frame, w, x, y, _c(ramp[tone]))
		_px(image, frame, w, int(body.x) + 9, int(body.y) - 3, _c("3a1a10"))
	_save(name, image, frames, w, h, 12.0, body)


## Flame tongue, 6 frames looping: one tall flame of a fire wall flickering
## up from the floor (Flammenwall); the game sets them in a row.
func _flame_tongue(name: String, ramp: Array, w: int, h: int) -> void:
	var frames := 6
	var image := _sheet(frames, w, h)
	for frame in range(frames):
		var phase := float(frame) / float(frames) * TAU
		for y in range(h):
			var up := float(h - y) / float(h)
			var sway := sin(up * 5.0 - phase * 2.0) * 2.0 * up
			var width := (w * 0.42) * (1.0 - up * 0.85) + 1.0 * sin(up * 9.0 + phase)
			for x in range(w):
				var d := absf(x + 0.5 - (w * 0.5 + sway)) / maxf(0.5, width)
				if d > 1.0: continue
				var heat := (1.0 - d) * (0.55 + 0.45 * (1.0 - up))
				var tone := 0 if heat > 0.6 else 1 if heat > 0.38 else 2 if heat > 0.18 else 3
				if up > 0.8 and tone < 3 and not _dither(x, y + frame, 1): continue
				_px(image, frame, w, x, y, _c(ramp[tone]))
	_save(name, image, frames, w, h, 12.0, Vector2(w * 0.5, h - 2))


## Lava pool, 8 frames looping: a flat ellipse of magma, dark crust plates
## drifting on it and bubbles that swell and burst (Lavafeld, the crater).
func _lava_pool(name: String, ramp: Array, w: int, h: int) -> void:
	var frames := 8
	var image := _sheet(frames, w, h)
	var center := Vector2(w, h) * 0.5
	for frame in range(frames):
		var phase := float(frame) / float(frames) * TAU
		for y in range(h):
			for x in range(w):
				var rel := Vector2((x + 0.5 - center.x) / (w * 0.48), (y + 0.5 - center.y) / (h * 0.46))
				var d := rel.length()
				if d > 1.0: continue
				var crust := _noise(x * 0.18 + cos(phase) * 0.6, y * 0.3 + sin(phase) * 0.4, 51)
				var tone := 4 if d > 0.9 else (3 if crust > 0.5 else 2 if crust > 0.42 else 1 if crust > 0.36 else 0)
				if d > 0.82 and tone < 3: tone = 2
				_px(image, frame, w, x, y, _c(ramp[tone]))
		for k in range(3):
			var at := center + Vector2(cos(k * 2.1) * w * 0.25, sin(k * 1.7) * h * 0.2)
			var life := fmod(float(frame) / float(frames) + k * 0.33, 1.0)
			var r := 1.0 + life * 3.0
			for y in range(-4, 5):
				for x in range(-4, 5):
					var dd := Vector2(x, y).length()
					if life < 0.85 and absf(dd - r) < 0.7: _px(image, frame, w, int(at.x) + x, int(at.y) + y, _c(ramp[0]))
	_save(name, image, frames, w, h, 8.0, center)


## Rune circle, 8 frames looping: a double ring with turning fire runes and
## a bright core (the Meteor's target mark).
func _rune_circle(name: String, ramp: Array, size: int) -> void:
	var frames := 8
	var image := _sheet(frames, size, size)
	var center := Vector2(size, size) * 0.5
	for frame in range(frames):
		var turn := float(frame) / float(frames) * TAU / 6.0
		for y in range(size):
			for x in range(size):
				var rel := Vector2(x + 0.5, y + 0.5) - center
				var r := rel.length()
				var outer := size * 0.47
				if absf(r - outer) < 1.0 or absf(r - outer * 0.72) < 0.8:
					_px(image, frame, size, x, y, _c(ramp[1]))
				elif r < outer * 0.18:
					_px(image, frame, size, x, y, _c(ramp[0 if r < outer * 0.1 else 2]))
		for k in range(6):
			var a := turn + TAU * k / 6.0
			var at := center + Vector2.from_angle(a) * size * 0.47 * 0.86
			for rune in range(5):
				var q := at + Vector2.from_angle(a + PI * 0.5) * float(rune - 2)
				_px(image, frame, size, int(q.x), int(q.y), _c(ramp[0 if rune == 2 else 2]))
			var tick := at + Vector2.from_angle(a) * 2.0
			_px(image, frame, size, int(tick.x), int(tick.y), _c(ramp[1]))
	_save(name, image, frames, size, size, 10.0, center)


## The big Feuerball, 8 frames looping (flying +x): a round head of white-hot
## core and swirling flame, three tongues of fire licking back in waves and
## sparks shed behind it. Bigger and smoother than the small fireball.
func _big_fireball(name: String, ramp: Array, size: int) -> void:
	var frames := 8
	var image := _sheet(frames, size, size)
	var head := Vector2(size * 0.68, size * 0.5)
	var radius := size * 0.25
	for frame in range(frames):
		var phase := float(frame) / float(frames) * TAU
		for y in range(size):
			for x in range(size):
				var p := Vector2(x + 0.5, y + 0.5)
				var rel := p - head
				var wobble := 0.6 * sin(phase * 2.0 + rel.angle() * 4.0) + 0.3 * sin(phase * 3.0 - rel.angle() * 7.0)
				var heat := 1.0 - rel.length() / (radius + wobble)
				var behind := -rel.x
				if behind > 0.0:
					for tongue in range(3):
						var wave := sin(behind * 0.35 - phase * 2.0 + float(tongue) * 2.1) * (0.3 + behind * 0.07)
						var middle := (float(tongue) - 1.0) * radius * 0.4 + wave
						var width := radius * (0.95 if tongue == 1 else 0.6) * (1.0 - behind / (size * 0.66)) + 0.5 * sin(behind * 1.1 + phase * 3.0 + tongue)
						if width <= 0.0: continue
						heat = maxf(heat, (1.0 - absf(rel.y - middle) / width) * (1.0 - behind / (size * 0.7)) * 0.9)
				if heat <= 0.0:
					# a faint hot halo around the head
					if heat > -0.18 and rel.x > -radius * 0.5 and _dither(x + frame, y, 3): _px(image, frame, size, x, y, _c(ramp[3]))
					continue
				# swirling bright streaks inside the head
				if rel.length() < radius * 0.8 and sin(rel.angle() * 2.0 + phase * 2.0 + rel.length() * 0.6) > 0.7: heat += 0.15
				var tone := 0 if heat > 0.72 else 1 if heat > 0.5 else 2 if heat > 0.28 else 3 if heat > 0.12 else 4
				if tone >= 3 and not _dither(x + frame, y, 1 if tone == 3 else 2): continue
				# a white-hot heart
				_px(image, frame, size, x, y, Color.WHITE if rel.length() < radius * 0.32 + 0.6 * sin(phase * 2.0) else _c(ramp[tone]))
		_rng.seed = 1700 + frame
		for k in range(6):
			var spark := head + Vector2(-_rng.randf_range(radius, size * 0.68), _rng.randf_range(-radius, radius))
			_px(image, frame, size, int(spark.x), int(spark.y), _c(ramp[_rng.randi_range(0, 2)]))
	_save(name, image, frames, size, size, 18.0, head)


## Fire explosion, 10 frames: a white flash, a churning ball of fire that
## swells and boils, a ring of flame racing out, then dark smoke breaking up
## with the last embers (the Feuerball's impact).
func _explosion(name: String, ramp: Array, size: int) -> void:
	var frames := 10
	var image := _sheet(frames, size, size)
	var center := Vector2(size, size) * 0.5
	var smoke := ["8a7a72", "5e5049", "3a302c"]
	for frame in range(frames):
		var t := float(frame) / float(frames - 1)
		var ball := size * (0.12 + 0.3 * sqrt(t))
		var ring := size * (0.18 + 0.32 * t)
		for y in range(size):
			for x in range(size):
				var rel := Vector2(x + 0.5, y + 0.5) - center
				var r := rel.length()
				var churn := _noise(x * 0.16 + t * 3.0, y * 0.16 - t * 2.0, 77) * 0.6
				# the fire ball: hot in the first frames, smoke later
				var inside := 1.0 - r / maxf(1.0, ball * (0.85 + churn))
				if inside > 0.0:
					if t < 0.6:
						var heat := inside + (0.5 - t) * 0.8
						var tone := 0 if heat > 0.8 else 1 if heat > 0.55 else 2 if heat > 0.3 else 3
						_px(image, frame, size, x, y, _c(ramp[tone]))
					else:
						var level := 0 if t < 0.75 else 1 if t < 0.9 else 2
						if not _dither(x + frame, y, level): continue
						var tone := 0 if inside > 0.6 else 1 if inside > 0.3 else 2
						_px(image, frame, size, x, y, _c(smoke[tone]))
						if inside > 0.7 and t < 0.8 and (x + y + frame) % 5 == 0: _px(image, frame, size, x, y, _c(ramp[2]))
					continue
				# the racing ring of flame
				if t > 0.15 and t < 0.8 and absf(r - ring) < 2.0 + churn * 2.0:
					var tone := 1 if t < 0.4 else 2 if t < 0.6 else 3
					if tone == 3 and not _dither(x, y + frame, 1): continue
					_px(image, frame, size, x, y, _c(ramp[tone]))
		_rng.seed = 2100 + frame
		for k in range(10):
			var a := _rng.randf() * TAU
			var dist := ring + _rng.randf_range(2.0, 10.0)
			var ember := center + Vector2.from_angle(a) * dist - Vector2(0, t * 6.0)
			if t > 0.1: _px(image, frame, size, int(ember.x), int(ember.y), _c(ramp[_rng.randi_range(0, 2)]))
	_save(name, image, frames, size, size, 20.0, center)


# --- The user's second effects round (30.10.2026): meteor, Pfeilhagel, fireball ----

## Big meteor, 8 frames looping (the Meteor ultimate): a craggy tumbling rock
## with glowing magma cracks inside a sheath of fire, a thick three-tongued
## tail streaming up and to the right, sparks peeling off its sides.
func _meteor_big(name: String, ramp: Array, w: int, h: int) -> void:
	var frames := 8
	var image := _sheet(frames, w, h)
	var rock := Vector2(w * 0.36, h * 0.8)
	var back := Vector2(0.5, -1.0).normalized()
	var across := back.orthogonal()
	var size := 10.0
	var rock_ramp := ["c8b4a0", "8a7060", "5a4438", "34261e"]
	for frame in range(frames):
		var phase := float(frame) / float(frames) * TAU
		var t := float(frame) / float(frames)
		for y in range(h):
			for x in range(w):
				var rel := Vector2(x + 0.5, y + 0.5) - rock
				var along := rel.dot(back)
				var side := rel.dot(across)
				# the sheath: a fire envelope hugging the rock, pushed back by the fall
				var sheath := size + 5.0 + 2.5 * _noise(x * 0.3 + t * 8.0, y * 0.3, 11)
				var heat := 1.0 - Vector2(side, along * (1.3 if along < 0.0 else 0.5)).length() / sheath
				if along > 0.0:
					# the tail: three tongues of fire licking backwards
					var length := h * 0.95
					for tongue in range(3):
						var off := (float(tongue) - 1.0) * 4.0 + sin(along * 0.16 - phase * 2.0 + tongue * 1.7) * (0.6 + along * 0.035)
						var width := (size + 4.0 - float(tongue % 2) * 3.0) * pow(maxf(0.0, 1.0 - along / length), 0.7)
						if width <= 0.0: continue
						var lick := (1.0 - absf(side - off) / width) * (1.0 - 0.75 * along / length)
						lick += (_noise(along * 0.2 - t * 12.0, side * 0.3, 23 + tongue) - 0.5) * 0.35
						heat = maxf(heat, lick)
				if heat <= 0.0: continue
				var tone := 0 if heat > 0.78 else 1 if heat > 0.55 else 2 if heat > 0.33 else 3 if heat > 0.15 else 4
				if tone == 4 and not _dither(x + frame, y, 2): continue
				_px(image, frame, w, x, y, _c(ramp[tone]))
		# the rock: a craggy edge, lit by the heat in front, magma cracks that pulse
		for y in range(h):
			for x in range(w):
				var rel := Vector2(x + 0.5, y + 0.5) - rock
				var turned := rel.rotated(phase * 0.25)
				var edge := size - 2.0 + 2.2 * _noise(turned.angle() * 1.6 + 4.0, 2.0, 31)
				if rel.length() > edge: continue
				var light := -rel.dot(back) / edge
				var tone := 1 if light > 0.3 else 2 if light > -0.35 else 3
				if light > 0.75: tone = 0
				var color := _c(rock_ramp[tone])
				var crack := absf(_noise(turned.x * 0.32 + 9.0, turned.y * 0.32 + 9.0, 41) - 0.5)
				if crack < 0.06 and rel.length() < edge - 1.0: color = _c(ramp[0] if sin(phase * 2.0 + turned.x) > 0.2 else ramp[1])
				_px(image, frame, w, x, y, color)
		_rng.seed = 3100 + frame
		for k in range(12):
			var spark := rock + back * _rng.randf_range(size, h * 0.8) + across * _rng.randf_range(-size - 6.0, size + 6.0)
			var tone := _rng.randi_range(0, 2)
			_px(image, frame, w, int(spark.x), int(spark.y), _c(ramp[tone]))
			if tone == 0: _px(image, frame, w, int(spark.x) + 1, int(spark.y), _c(ramp[1]))
	_save(name, image, frames, w, h, 14.0, rock)


## Meteor impact, 12 frames: a white flash, a dome of fire that swells and
## rises into a mushroom on a burning stem, a dust shockwave racing over the
## ground (flattened for the top-down floor), rock chunks thrown out on arcs,
## then smoke breaking up with the last embers.
func _meteor_impact(name: String, ramp: Array, size: int) -> void:
	var frames := 12
	var image := _sheet(frames, size, size)
	var ground := Vector2(size * 0.5, size * 0.66)
	var smoke := ["8a7a72", "5e5049", "3a302c"]
	for frame in range(frames):
		var t := float(frame) / float(frames - 1)
		var rx := size * (0.12 + 0.2 * sqrt(t))
		var dome := ground - Vector2(0, size * (0.02 + 0.2 * t))
		var ring := size * (0.12 + 0.36 * t)
		for y in range(size):
			for x in range(size):
				var p := Vector2(x + 0.5, y + 0.5)
				var churn := _noise(x * 0.14 + t * 3.0, y * 0.14 - t * 4.0, 91) * 0.5
				# the dust shockwave on the ground
				var flat := Vector2(p.x - ground.x, (p.y - ground.y) / 0.42)
				var band := absf(flat.length() - ring)
				if t > 0.05 and t < 0.85 and band < 3.5 + churn * 3.0:
					var tone := 1 if band < 1.5 else 2 if t < 0.5 else 3
					if t <= 0.55 or _dither(x + frame, y, 1): _px(image, frame, size, x, y, _c(DUST[tone]))
				# the stem under the rising dome
				var stem := absf(p.x - ground.x) - rx * (0.3 + 0.1 * sin(p.y * 0.3 + t * 9.0))
				if t > 0.12 and t < 0.75 and stem < 0.0 and p.y > dome.y and p.y < ground.y + 2.0:
					var tone := 1 if stem < -rx * 0.18 else 2
					if t > 0.5: tone += 1
					_px(image, frame, size, x, y, _c(ramp[mini(tone, 4)]))
				# the dome, later the mushroom cap
				var rel := Vector2(p.x - dome.x, (p.y - dome.y) / 0.78)
				var inside := 1.0 - rel.length() / maxf(1.0, rx * (0.85 + churn))
				if inside <= 0.0: continue
				if t < 0.62:
					var heat := inside * 0.9 + (0.45 - t) * 0.8 - (p.y - dome.y) / size * 0.6 + (churn - 0.25) * 0.5
					var tone := 0 if heat > 0.95 else 1 if heat > 0.65 else 2 if heat > 0.38 else 3 if heat > 0.12 else 4
					_px(image, frame, size, x, y, _c(ramp[tone]))
				else:
					var level := 0 if t < 0.75 else 1 if t < 0.9 else 2
					if not _dither(x + frame, y, level): continue
					var tone := 0 if inside > 0.6 and p.y < dome.y else 1 if inside > 0.3 else 2
					_px(image, frame, size, x, y, _c(smoke[tone]))
					if inside > 0.6 and t < 0.85 and (x * 3 + y + frame) % 7 == 0: _px(image, frame, size, x, y, _c(ramp[2]))
		# the flash
		if frame <= 1:
			for y in range(size):
				for x in range(size):
					var d := Vector2(x + 0.5, y + 0.5).distance_to(ground - Vector2(0, 4))
					if d < size * (0.2 - frame * 0.06): _px(image, frame, size, x, y, Color.WHITE if d < size * 0.12 else _c(ramp[0]))
		# rock chunks on arcs, glowing at the top edge
		_rng.seed = 4400
		for k in range(12):
			var a := _rng.randf_range(PI * 1.05, PI * 1.95)
			var speed := _rng.randf_range(0.3, 0.55) * size
			var spot := ground + Vector2(cos(a) * 1.4, sin(a)) * speed * t + Vector2(0, t * t * size * 0.55)
			if t < 0.08 or t > 0.92: continue
			var big := k % 3 == 0
			for oy in range(2 if big else 1):
				for ox in range(3 if big else 2):
					_px(image, frame, size, int(spot.x) + ox, int(spot.y) + oy, _c("5a4438" if oy > 0 else "8a7060"))
			_px(image, frame, size, int(spot.x), int(spot.y) - 1, _c(ramp[1]))
		_rng.seed = 4500 + frame
		for k in range(16):
			var a := _rng.randf() * TAU
			var ember := dome + Vector2.from_angle(a) * (rx + _rng.randf_range(2.0, 14.0)) - Vector2(0, t * 10.0)
			if t > 0.08: _px(image, frame, size, int(ember.x), int(ember.y), _c(ramp[_rng.randi_range(0, 2)]))
	_save(name, image, frames, size, size, 12.0, ground)


## Hail arrow, 4 frames: one big falling arrow (tip down) with a steel head,
## a red and white fletching and speed lines flickering above it.
func _hail_arrow(name: String, w: int, h: int) -> void:
	var frames := 4
	var image := _sheet(frames, w, h)
	var tip := Vector2(int(w * 0.5), h - 1)
	for frame in range(frames):
		# speed lines
		for k in range(3):
			var x := int(tip.x) + (k - 1) * 3
			var top := 2 + (frame * 3 + k * 5) % 7
			for y in range(top, top + 8):
				if _dither(x, y + frame, 1): _px(image, frame, w, x, y, _c("ffffff") if k == 1 else _c(STEEL[1]))
		# shaft
		for y in range(int(tip.y) - 24, int(tip.y) - 3):
			_px(image, frame, w, int(tip.x), y, _c("c9a27a"))
			_px(image, frame, w, int(tip.x) + 1, y, _c("8a6a4a"))
		# head
		for i in range(5):
			var y := int(tip.y) - i
			var half := mini(i, 2)
			for x in range(int(tip.x) - half, int(tip.x) + 2 + half):
				_px(image, frame, w, x, y, _c(STEEL[0] if x <= int(tip.x) else STEEL[2]))
		# fletching
		for i in range(5):
			var y := int(tip.y) - 26 + i
			_px(image, frame, w, int(tip.x) - 1 - (i % 2), y, _c("e05050") if (i + frame) % 2 == 0 else _c("ffffff"))
			_px(image, frame, w, int(tip.x) + 2 + (i % 2), y, _c("a8242c"))
	_save(name, image, frames, w, h, 16.0, tip)


## Arrow impact, 8 frames: a spark where the tip strikes, a flat dust puff
## and splinters thrown out, the arrow left quivering in the ground.
func _arrow_impact(name: String, size: int) -> void:
	var frames := 8
	var image := _sheet(frames, size, size)
	var spot := Vector2(int(size * 0.5), int(size * 0.66))
	for frame in range(frames):
		var t := float(frame) / float(frames - 1)
		# dust puff, flattened
		var rx := size * (0.12 + 0.3 * t)
		for y in range(size):
			for x in range(size):
				var rel := Vector2(x + 0.5 - spot.x, (y + 0.5 - spot.y) / 0.5)
				var inside := 1.0 - rel.length() / (rx * (0.8 + _noise(x * 0.3, y * 0.3 + t * 3.0, 51) * 0.4))
				if inside <= 0.0 or inside > 0.6: continue
				var level := 0 if t < 0.35 else 1 if t < 0.7 else 2
				if not _dither(x + frame, y, level): continue
				_px(image, frame, size, x, y, _c(DUST[1 if inside > 0.3 else 2]))
		# the strike spark
		if frame < 2:
			for i in range(-4 + frame * 2, 5 - frame * 2):
				_px(image, frame, size, int(spot.x) + i, int(spot.y) - 2, _c("ffffff"))
				_px(image, frame, size, int(spot.x), int(spot.y) - 2 + i, _c("fff2b0"))
		# splinters
		_rng.seed = 5100
		for k in range(7):
			var a := _rng.randf_range(PI * 1.1, PI * 1.9)
			var bit := spot + Vector2.from_angle(a) * size * 0.4 * t + Vector2(0, t * t * size * 0.3)
			if t > 0.05 and t < 0.9: _px(image, frame, size, int(bit.x), int(bit.y), _c(["e8c890", "b8864a", "a6bccd"][k % 3]))
		# the arrow stuck in the ground, quivering, then fading
		var wobble := sin(t * 18.0) * (1.0 - t) * 1.5
		if t < 0.85 or _dither(frame, 0, 1):
			for i in range(12):
				var q := spot + Vector2(0.45 + wobble * 0.08, -1.0).normalized() * float(i)
				_px(image, frame, size, int(q.x), int(q.y), _c("c9a27a" if i < 10 else "e05050"))
	_save(name, image, frames, size, size, 16.0, spot)


## Fire sparks, 8 frames: hot streaks flying out of an explosion in all
## directions and falling as they cool.
func _fire_sparks(name: String, ramp: Array, size: int) -> void:
	var frames := 8
	var image := _sheet(frames, size, size)
	var center := Vector2(size, size) * 0.5
	for frame in range(frames):
		var t := float(frame + 1) / float(frames)
		_rng.seed = 6100
		for k in range(22):
			var a := _rng.randf() * TAU
			var speed := _rng.randf_range(0.25, 0.48) * size
			var head := center + Vector2.from_angle(a) * speed * t + Vector2(0, t * t * size * 0.18)
			var late := maxf(0.0, t - 0.12)
			var tail := center + Vector2.from_angle(a) * speed * late + Vector2(0, late * late * size * 0.18)
			var tone := 0 if t < 0.35 else 1 if t < 0.6 else 2 if t < 0.85 else 3
			var steps := maxi(1, int(head.distance_to(tail)))
			for s in range(steps + 1):
				var q := tail.lerp(head, float(s) / steps)
				_px(image, frame, size, int(q.x), int(q.y), _c(ramp[mini(tone + (1 if s < steps / 2 else 0), 4)]))
	_save(name, image, frames, size, size, 16.0, center)
