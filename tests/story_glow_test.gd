extends SceneTree
## The crypt's bloom and darkness in the story worlds (src/hero/story_glow.gd):
## one crypt bloom node (src/vfx/glow.gd) above the crypt's darkness
## (src/vfx/darkness.gd) in the Hell-Dungeon and the Frostgruft, hidden with the
## light; everything bright lights the dark by the crypt's rules and in its
## order within the 48-light budget (the hero, the fires on screen, the lava,
## then the fight); map fires, magic, loot and lava banks bloom in the theme's
## colours; enemy shots bloom like the crypt's bullets; monster attacks, the
## world's own zones and blasts and the monsters' glowing parts (vfx_glow.json
## "story") bloom where the world drew them, never through a front wall; the
## values the crypt keeps inline still match its source. Deterministic: the
## worlds do not run on their own, every frame is stepped by hand and the items
## are read as data.

const FrostScene = preload("res://src/hell/frost_dungeon.tscn")
const HellScene = preload("res://src/hell/hell_dungeon.tscn")
const Glow = preload("res://src/vfx/glow.gd")
const Darkness = preload("res://src/vfx/darkness.gd")
const StoryGlow = preload("res://src/hero/story_glow.gd")
const Rules = preload("res://src/hell/hell_monster_rules.gd")
const SAVE := "user://story_glow_test.cfg"
## The worlds of this test read and write their graphics choice here, never the player's settings.
const GRAPHICS := "user://story_glow_graphics.cfg"
var checked := 0
var failures: Array[String] = []


func check(condition: bool, description: String) -> void:
	checked += 1
	if not condition:
		failures.append(description)
		printerr("STORY_GLOW_FAIL: ", description)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for path: String in [SAVE, GRAPHICS]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	test_data()
	test_crypt_parity()
	for spec: Array in [[HellScene, "Hölle"], [FrostScene, "Frostgruft"]]:
		await test_layers(spec[0], spec[1])
	await test_hell_lights()
	await test_light_order()
	await test_world_zones()
	await test_frost_lights()
	await test_map_bloom()
	await test_shots()
	await test_attacks()
	await test_mob_parts()
	await test_front_wall()
	await test_drawn_by_the_world()
	for path: String in [SAVE, GRAPHICS]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("STORY_GLOW checked=%d failures=%d" % [checked, failures.size()])
	quit(1 if failures.size() > 0 else 0)


func _new(scene: PackedScene, floor_n := 2, class_id := "mage") -> Node:
	var game: Node = scene.instantiate()
	game.start_floor = floor_n
	game.class_id = class_id
	game.meta_path = SAVE
	# the starting look comes from this test's own file (no file: the default pixel look)
	game.graphics_path = GRAPHICS
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.mobs.clear()
	game.eshots.clear()
	game.state.offer = []
	return game


func _free(game: Node) -> void:
	game.queue_free()
	await process_frame


func _hero(game: Node) -> Vector2:
	return Vector2(game.player.x, game.player.y)


## A light of `list` within `reach` px of `p` (Vector4.ZERO when none).
func _light_near(list: Array, p: Vector2, reach := 2.0) -> Vector4:
	for l: Vector4 in list:
		if Vector2(l.x, l.y).distance_to(p) <= reach:
			return l
	return Vector4.ZERO


## The index of the first light of `list` within 0.5 px of `p` (-1 when none).
func _index_near(list: Array, p: Vector2) -> int:
	for i in range(list.size()):
		if Vector2(list[i].x, list[i].y).distance_to(p) <= 0.5:
			return i
	return -1


func _of(items: Array, kind: String) -> Array:
	return items.filter(func(i: Dictionary) -> bool: return str(i.kind) == kind)


## A body as the world records it when it draws one (hell_monsters.gd _mark,
## hell_game.gd _draw_mob_sprite): through story_glow.mark.
func _drawn(sg: RefCounted, m: Dictionary, src: Vector2, sc: float, cut := 0.0, alpha := 1.0) -> Dictionary:
	var drawn := {"foot": m.p, "size": src * sc, "src": src, "face": 1.0, "lean": 0.0, "cut": cut, "alpha": alpha}
	sg.mark(m, drawn)
	return drawn


## Puts the hero and the camera in the middle of room `r`.
func _centre_on(g: Node, r: Dictionary) -> Vector2:
	var c := Vector2(r.bx + r.bw / 2.0, r.by + r.bh / 2.0) * float(g.C)
	g.player.x = c.x
	g.player.y = c.y
	g.state.room = r.index
	g.camera.position = c
	return c


## The kinds a world source file adds to a list (`list`.append({"kind": "..."})).
func _added_kinds(paths: Array, list: String) -> Dictionary:
	var re := RegEx.new()
	re.compile("(?:^|[\\s.(])" + list + "\\.append\\(\\{\"kind\": \"(\\w+)\"")
	var out := {}
	for path: String in paths:
		for m: RegExMatch in re.search_all(FileAccess.get_file_as_string(path)):
			out[m.get_string(1)] = path.get_file()
	return out


# --- the data -------------------------------------------------------------------------

## Every hell monster and every Frostgruft sprite has its glowing parts; every
## part sits on the art (catches drift when the exporter redraws a monster);
## every world zone and skill effect has its entry; every bloom kind exists.
func test_data() -> void:
	var all := Glow.load_data()
	var story: Dictionary = all.get("story", {})
	var scales: Dictionary = all.get("scales", {})
	check(scales.has("mobs") and scales.has("lava"), "vfx_glow.json has the story scales mobs and lava")
	var monsters: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/hell_monsters.json"))
	var table: Dictionary = story.get("hell_monsters", {})
	var parts := 0
	var off_art: Array = []
	for id: String in monsters.defs:
		check(table.has(id), "%s has an entry in vfx_glow.json story.hell_monsters" % id)
		var def: Dictionary = monsters.defs[id]
		var img: Image = (load("res://assets/sprites/hell/monsters/%s.png" % id) as Texture2D).get_image()
		if img.is_compressed(): img.decompress()
		for part: Dictionary in table.get(id, []):
			parts += 1
			var at: Array = part.at
			check(float(at[0]) >= 0.0 and float(at[0]) < float(def.w) and float(at[1]) >= 0.0 and float(at[1]) < float(def.h), "%s anchor %s inside %dx%d" % [id, at, def.w, def.h])
			check(Color.html_is_valid(str(part.color)) and float(part.r) > 0.0 and float(part.alpha) > 0.0, "%s part colour, radius, alpha" % id)
			var anim := "idle"
			if part.has("anim"): anim = str(part.anim[0])
			if part.has("act"): anim = Rules.act_anim(str(part.act[0]), def)
			if not _opaque_near(img, int(def.px), Vector2(float(def.w), float(def.h)), int(def.anims[anim].row), Vector2(float(at[0]), float(at[1]))):
				off_art.append("%s %s %s" % [id, anim, at])
	check(off_art.is_empty(), "every hell glow anchor lies on the monster's art (%s)" % ", ".join(off_art))
	check(parts >= 40, "the hell monsters have their glowing parts (%d)" % parts)
	var frost: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/frost_theme.json"))
	var ftable: Dictionary = story.get("frost_mobs", {})
	var sprites := {}
	for kind: String in frost.mobs:
		sprites[str(frost.mobs[kind].sprite)] = true
	for n: String in frost.bosses:
		sprites[str(frost.bosses[n].sprite)] = true
	for kit: String in frost.get("boss_kits", {}):
		for phase: Dictionary in frost.boss_kits[kit].phases:
			if phase.has("look"): sprites[str(phase.look.sprite)] = true
	var missing := sprites.keys().filter(func(s: String) -> bool: return not ftable.has(s))
	check(missing.is_empty(), "every Frostgruft sprite (mobs, guardians, boss kit phases) has an entry in story.frost_mobs (missing %s)" % [missing])
	var frost_off: Array = []
	for sprite: String in ftable:
		var path := "res://assets/sprites/frost/%s.png" % (sprite if sprite.ends_with("_0") or not sprite.ends_with("_f") else sprite + "0")
		check(ResourceLoader.exists(path), "frost glow sprite %s exists" % sprite)
		if not ResourceLoader.exists(path): continue
		var img: Image = (load(path) as Texture2D).get_image()
		if img.is_compressed(): img.decompress()
		for part: Dictionary in ftable[sprite]:
			var at: Array = part.at
			if not _opaque_near(img, 1, Vector2(img.get_size()), 0, Vector2(float(at[0]), float(at[1]))):
				frost_off.append("%s %s" % [sprite, at])
	check(frost_off.is_empty(), "every frost glow anchor lies on its sprite (%s)" % ", ".join(frost_off))
	for sprite: String in ["mob_ice_crystal_0", "mob_frost_whirl_0", "mob_ice_slime_0", "mob_frost_imp_f", "boss_golem_p2_f", "boss_golem_p3_f"]:
		check(sprites.has(sprite) and not (ftable.get(sprite, []) as Array).is_empty(), "the Frostgruft's %s glows" % sprite)
	check((ftable.get("boss_golem_p1_f", [0]) as Array).is_empty() and (ftable.get("mob_ice_zombie_f", [0]) as Array).is_empty(), "Hrimgar's armour and the ice zombie do not glow")
	# the world's own zones and skill effects: every kind it adds is listed
	var worlds := ["res://src/hell/hell_game.gd", "res://src/hell/boss_kit.gd", "res://src/hell/hero_kit.gd", "res://src/hell/relic_kit.gd", "res://src/hell/sub_kit.gd", "res://src/hero/story_hero.gd", "res://src/hero/story_items.gd"]
	var zone_kinds := _added_kinds(worlds, "zones")
	var fx_kinds := _added_kinds(worlds, "fx")
	check(zone_kinds.has("icicle") and zone_kinds.has("meteor") and fx_kinds.has("quake"), "the world's zones and effects are found in its source (%s / %s)" % [zone_kinds.keys(), fx_kinds.keys()])
	var wz: Dictionary = story.get("world_zones", {})
	var wfx: Dictionary = story.get("world_fx", {})
	check(zone_kinds.keys().all(func(k: String) -> bool: return wz.has(k)), "every world zone kind has its story.world_zones entry (%s)" % [zone_kinds.keys().filter(func(k: String) -> bool: return not wz.has(k))])
	check(fx_kinds.keys().all(func(k: String) -> bool: return wfx.has(k)), "every world effect kind has its story.world_fx entry (%s)" % [fx_kinds.keys().filter(func(k: String) -> bool: return not wfx.has(k))])
	# every bloom kind the code draws exists (with its radius and intensity)
	var bloom: Dictionary = story.get("bloom", {})
	var kinds := ["rune", "portal", "portal_core", "relic", "seal", "plate", "vent", "gate", "wall_post", "wall_slit", "lava_bank", "impact", "impact_void",
		"wave", "swing", "slam", "scream", "scream_mouth", "beam_halo", "beam_core", "beam_mouth", "transform", "transform_core", "echo", "armor", "pull", "dash", "guard"]
	for k: String in wfx:
		if str(wfx[k]) != "" and not k.begins_with("_"): kinds.append(str(wfx[k]))
	for k: String in wz:
		if (wz[k] is Dictionary) and (wz[k] as Dictionary).has("impact"): kinds.append(str(wz[k].impact))
	var broken := kinds.filter(func(k: String) -> bool: return not bloom.has(k) or float(bloom[k].get("alpha", 0.0)) <= 0.0 or float(bloom[k].get("r", bloom[k].get("size", 0.0))) <= 0.0)
	check(broken.is_empty(), "every bloom kind of story.bloom has a radius and an intensity (%s)" % [broken])
	check(bloom.has("vault") and (bloom.vault.light as Array).size() == 2, "the vault keeps the world's own light")
	# a mirrored body mirrors its parts: pixel x of a body facing left sits where w - 1 - x sits facing right
	var drawn := {"foot": Vector2(100, 200), "size": Vector2(36, 48) * 4.2, "src": Vector2(36, 48), "face": -1.0, "lean": 0.0, "cut": 0.0}
	var right := drawn.duplicate()
	right.face = 1.0
	check(StoryGlow.anchor(drawn, [23, 10.5]).is_equal_approx(StoryGlow.anchor(right, [36 - 1 - 23, 10.5])), "facing left mirrors a glowing part")
	var sunk := right.duplicate()
	sunk.cut = 48.0 * 4.2 * 0.5
	check(not StoryGlow.anchor(sunk, [23, 40]).is_finite() and StoryGlow.anchor(sunk, [23, 10]).is_finite(), "a part sunk below the floor cut is hidden")


## True when the source pixel `at` (or one next to it) of the frame in `row` is opaque.
func _opaque_near(img: Image, px: int, grid: Vector2, row: int, at: Vector2) -> bool:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var x := int(round(at.x)) + dx
			var y := int(round(at.y)) + dy
			if x < 0 or y < 0 or x >= int(grid.x) or y >= int(grid.y): continue
			if img.get_pixel(x * px + px / 2, row * int(grid.y) * px + y * px + px / 2).a > 0.5:
				return true
	return false


## The values story_glow.gd takes over from the crypt's inline code (nothing to
## call) still match the crypt's source: tuning one there must not leave the
## story worlds behind silently.
func test_crypt_parity() -> void:
	var view := FileAccess.get_file_as_string("res://src/dungeon_view.gd")
	check(view.contains("84.0 if style == \"fireball\" else 46.0, 0.9 if style == \"fireball\" else 0.8") and StoryGlow.BULLET_LIGHT.fireball == [84.0, 0.9]
		and StoryGlow.BULLET_LIGHT.magic == [46.0, 0.8] and StoryGlow.BULLET_LIGHT.void_skull == [46.0, 0.8], "bullet lights match dungeon_view.gd _update_darkness")
	var brazier: Array = StoryGlow.FLAME_CLASSES[0]
	var torch: Array = StoryGlow.FLAME_CLASSES[1]
	check(view.contains("50.0 + 3.0 * sin(_clock * 8.0") and view.contains("0.22 * torches") and brazier.slice(1, 4) == [50.0, 0.22, 8.0], "brazier bloom matches dungeon_view.gd _draw_glow (50 px, 0.22, 8 Hz)")
	check(view.contains("42.0 + 3.0 * sin(_clock * 9.0") and view.contains("Color(1.0, 0.62, 0.28, 0.2)") and torch.slice(1, 4) == [42.0, 0.2, 9.0], "torch bloom matches dungeon_view.gd _draw_glow (42 px, 0.2, 9 Hz)")
	check(view.contains("float(rect[3]) * 0.5, 56.0, 0.5)") and StoryGlow.EXIT_LIGHT == Vector2(56.0, 0.5), "exit light matches dungeon_view.gd (56 px, 0.5)")
	var particles := FileAccess.get_file_as_string("res://src/vfx/particles.gd")
	check(particles.contains("5.0 + 5.0 * heat, Color(1.0, 0.5, 0.15, 0.3 * heat * level)") and StoryGlow.EMBER_GLOW == Vector3(5.0, 5.0, 0.3), "ember bloom matches particles.gd draw_glow")
	var rig := FileAccess.get_file_as_string("res://src/rig/rig_renderer.gd")
	check(rig.contains("- 16.0, 68.0))") and is_equal_approx(StoryGlow.BEAM_LIGHT, 68.0), "beam light matches rig_renderer.gd lights (68 px)")


# --- one bloom over the darkness ------------------------------------------------------

func test_layers(scene: PackedScene, label: String) -> void:
	var g := await _new(scene)
	var sg: RefCounted = g.story_glow
	check(sg != null and sg.glow.get_script() == Glow, "%s: the bloom is the crypt's glow.gd" % label)
	check(g.dark.get_script() == Darkness, "%s: the darkness is the crypt's darkness.gd" % label)
	check(sg.glow.z_index > g.dark.z_index, "%s: the bloom draws above the darkness (%d > %d)" % [label, sg.glow.z_index, g.dark.z_index])
	check(is_equal_approx(sg.glow.scale.x, g.feel.scale) and is_equal_approx(sg.scale, g.story_hero.scale), "%s: the bloom works in the crypt units of the feel and the hero kit" % label)
	g.state.light = true
	sg.frame()
	check(sg.glow.visible and g.dark.visible, "%s: with the light on, darkness and bloom show" % label)
	check(int(g.dark.material.get_shader_parameter("light_count")) >= 1, "%s: the darkness has its lights" % label)
	# a world with fog (the Frostgruft) thins its fog in its own finer steps (theme fog.bands)
	var bands: float = float(g.theme.fog.get("bands", 12)) if g.theme.has("fog") else float(g.balance.view.light_bands)
	check(is_equal_approx(float(g.dark.material.get_shader_parameter("light_bands")), bands), "%s: the world keeps its light bands" % label)
	# nothing else blooms under the darkness: the hero kit's and the feel's layers are taken over
	var under: Array = []
	for child: Node in g.get_children():
		if child is CanvasItem and (child as CanvasItem).visible and (child as CanvasItem).z_index < g.dark.z_index:
			var mat: Material = (child as CanvasItem).material
			if mat is CanvasItemMaterial and (mat as CanvasItemMaterial).blend_mode == CanvasItemMaterial.BLEND_MODE_ADD and child != g.glow:
				under.append("%s z%d" % [child.get_class(), (child as CanvasItem).z_index])
	check(under.is_empty(), "%s: no additive layer blooms under the darkness (%s)" % [label, under])
	# each level is vfx_glow.json's strength times its scale, whatever they are tuned to
	var data := Glow.load_data()
	for key: String in ["bullets", "torches", "mobs", "lava"]:
		check(is_equal_approx(sg.glow.level(key), float(data.strength) * float(data.scales[key])), "%s: %s bloom at vfx_glow.json's level" % [label, key])
	g.state.light = false
	sg.frame()
	check(not sg.glow.visible and not g.dark.visible, "%s: switching the light off hides darkness and bloom together" % label)
	g.state.light = true
	sg.frame()
	# a graphics switch brings a new hero kit; its own bloom layer is taken over again
	var hero_layer: Variant = g.story_hero.get("_glow_layer")
	# (the Frostgruft has one look: no switch, its kit stays)
	if g.apply_graphics("hd" if g.graphics == "pixel" else "pixel"):
		sg.frame()
		var new_layer: Variant = g.story_hero.get("_glow_layer")
		check(new_layer != hero_layer and not (new_layer as CanvasItem).visible, "%s: after a graphics switch the new kit's layer stays hidden" % label)
		check(is_equal_approx(sg.scale, g.story_hero.scale) and is_equal_approx(sg.glow.scale.x, g.story_hero.scale), "%s: the bloom follows the hero size of the graphics set" % label)
		g.apply_graphics("pixel")
	await _free(g)


# --- the darkness's lights ------------------------------------------------------------

func test_hell_lights() -> void:
	var g := await _new(HellScene)
	var sg: RefCounted = g.story_glow
	var me := _hero(g)
	var s: float = sg.scale
	# a hero spell lights its path (attack_fx.gd lights: 72 crypt px)
	g.shots.append({"p": me + Vector2(120, -40), "v": Vector2(600, 0), "t": 1.0, "kind": "magic"})
	g.story_hero.update(0.016)
	var spell := _light_near(sg.combat_lights(), me + Vector2(120, -40))
	check(is_equal_approx(spell.z, 72.0 * s), "a hero spell lights the dark at the shot (%s)" % spell)
	g.shots.clear()
	g.story_hero.update(0.016)
	# enemy shots: the crypt's bullet rule
	g.eshots.append({"p": me + Vector2(200, 0), "v": Vector2(-300, 0), "t": 2.0, "c": "void"})
	g.eshots.append({"p": me + Vector2(-200, 0), "v": Vector2(300, 0), "t": 2.0, "c": "fire"})
	g.eshots.append({"p": me + Vector2(0, 200), "v": Vector2(0, -300), "t": 2.0, "c": "chain"})
	var lights: Array = sg.combat_lights()
	check(is_equal_approx(_light_near(lights, me + Vector2(200, 0)).z, 46.0 * s), "a void shot lights 46 crypt px like the crypt's magic")
	check(is_equal_approx(_light_near(lights, me + Vector2(-200, 0)).z, 84.0 * s), "a fire bolt lights 84 crypt px like the crypt's fireball")
	check(_light_near(lights, me + Vector2(0, 200)) == Vector4.ZERO, "a chain does not light the dark")
	check(not g.eshots.any(func(e: Dictionary) -> bool: return e.size() > 4), "the bloom leaves no mark on the world's shots")
	g.eshots.clear()
	# a magma puddle: skill_fx.gd's own lava zone light, twice its radius
	g.monsters.zones.append({"kind": "puddle", "p": me + Vector2(150, 50), "r": 52.0, "T": 2.6, "t": 0.0, "tele": 0.0, "dmg": 1, "done": false, "m": {}})
	var puddle := _light_near(sg.combat_lights(), me + Vector2(150, 50))
	check(is_equal_approx(puddle.z, 104.0) and is_equal_approx(puddle.w, 0.8), "a magma puddle lights twice its radius at 0.8 (%s)" % puddle)
	# a meteor's telegraph lights like boss_fx.gd's strike, its impact flares
	g.monsters.zones.clear()
	g.monsters.zones.append({"kind": "meteor", "p": me + Vector2(-150, 60), "r": 80.0, "T": 1.35, "t": 0.5, "tele": 1.0, "dmg": 1, "done": false, "m": {}})
	var tele := _light_near(sg.combat_lights(), me + Vector2(-150, 60))
	check(is_equal_approx(tele.z, maxf(40.0, 80.0 / s * 1.3) * s) and is_equal_approx(tele.w, 0.6), "a meteor's warning lights like the crypt's strike (%s)" % tele)
	g.monsters.zones.clear()
	# Ignaroth 4 burning three beams
	var boss: Dictionary = g.monsters.spawn(g.state.room, me + Vector2(300, 0), "drache4", true)
	boss.spawn = 0.0
	boss.act = {"kind": "beam", "beams": [0.0, 2.1, 4.2], "warn": false, "t": 1.2, "a": {"turn": 0.5, "duration": 4.0}, "anim": "cast", "dir": Vector2.RIGHT, "n": 0, "v": Vector2.ZERO}
	check(sg.beam_segments(boss).size() == 3, "Ignaroth 4's three burning beams are found")
	var beam_lights := 0
	var unbudgeted: Array = sg.zone_lights()
	for seg: Array in sg.beam_segments(boss):
		for i in range(1, 5):
			if _light_near(unbudgeted, (seg[0] as Vector2).lerp(seg[1], i / 4.0), 1.0).z > 60.0: beam_lights += 1
	check(beam_lights == 12, "the void beams light the dark along their path: 4 lights a beam (%d)" % beam_lights)
	g.mobs.clear()
	# lava at the bottom of the screen gets its light (the old scan stopped in the upper rows)
	var bank := _bank(g)
	check(bank != Vector2i(-1, -1), "the hell floor has a lava bank")
	if bank != Vector2i(-1, -1):
		g.player.x = (bank.x + 0.5) * g.C
		g.player.y = (bank.y + 1.5) * g.C
		g.camera.position = Vector2(g.player.x, g.player.y - 300.0)
		var lava: Array = sg.lava_lights(g._view_rect())
		check(not lava.is_empty() and lava.size() <= 8, "the lava banks have their lights (%d)" % lava.size())
		check(_light_near(lava, _hero(g), 300.0) != Vector4.ZERO, "a lava bank at the bottom of the view lights next to the hero")
		var items: Array = sg.lava_items()
		var c := float(g.C)
		check(not items.is_empty() and items.all(func(i: Dictionary) -> bool: return g._cell(int(i.p.x / c), int(i.p.y / c)) == 2 and [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)].any(func(n: Vector2i) -> bool: return g._cell(int(i.p.x / c) + n.x, int(i.p.y / c) + n.y) == 1)), "lava blooms on its banks only")
	await _free(g)


## A lava cell with floor right below it.
func _bank(g: Node) -> Vector2i:
	for y in range(int(g.W.rows) - 1):
		for x in range(int(g.W.cols)):
			if g._cell(x, y) == 2 and g._cell(x, y + 1) == 1 and g._cell(x, y + 2) == 1:
				return Vector2i(x, y)
	return Vector2i(-1, -1)


## The crypt's order (dungeon_view.gd _update_darkness: players, braziers and
## torches, then spells and shots, exits last): in a crowded fight in every
## fight room of three hell floors, every fire on screen keeps its light, the
## fight and the monsters keep their shares, the screen comes before the margin
## and the exits come last.
func test_light_order() -> void:
	for n: int in [2, 5, 8]:
		var g := await _new(HellScene, n)
		var sg: RefCounted = g.story_glow
		var rooms := 0
		var dark_fires: Array = []
		var shares_kept := true
		var fires_first := true
		for r: Dictionary in g.W.rooms:
			if r.type != "combat" and r.type != "boss":
				continue
			rooms += 1
			g.mobs.clear()
			g.eshots.clear()
			var c := _centre_on(g, r)
			# a crowded fight: 60 fire shots, 20 monsters, three meteor warnings
			for i in range(60):
				g.eshots.append({"p": c + Vector2.from_angle(i * 0.1) * (80.0 + i * 6.0), "v": Vector2.ZERO, "t": 9.0, "c": "fire"})
			for i in range(20):
				var m: Dictionary = g.monsters.spawn(r.index, c + Vector2.from_angle(i * 0.31) * (150.0 + i * 12.0), "glutimp")
				m.spawn = 0.0
			for i in range(3):
				g.monsters.zones.append({"kind": "meteor", "p": c + Vector2(-300 + 300 * i, 120), "r": 80.0, "T": 1.35, "t": 0.5, "tele": 1.0, "dmg": 0, "done": false, "m": {}})
			var all: Array = sg.lights()
			var near: Rect2 = g._view_rect().grow(StoryGlow.FIRE_MARGIN)
			var last_fire := -1
			for li: Dictionary in g.W.lights:
				var p := Vector2(li.x, li.y)
				if not near.has_point(p):
					continue
				var at := _index_near(all, p)
				if at < 0:
					dark_fires.append("floor %d room %d at %s" % [n, r.index, p])
				last_fire = maxi(last_fire, at)
			var first_shot := _index_near(all, g.eshots[0].p)
			if last_fire >= 0 and first_shot >= 0 and first_shot < last_fire:
				fires_first = false
			var fight := (sg.combat_lights() as Array).filter(func(l: Vector4) -> bool: return _index_near(all, Vector2(l.x, l.y)) >= 0).size()
			var warnings := (g.monsters.zones as Array).filter(func(z: Dictionary) -> bool: return _light_near(all, z.p, 1.0) != Vector4.ZERO).size()
			var bodies := (g.mobs as Array).filter(func(m: Dictionary) -> bool: return _index_near(all, (m.p as Vector2) - Vector2(0, float(m.cy) + float(m.alt))) >= 0).size()
			# what is left after the hero, the fires and the lava goes to the fight first (16, its
			# warnings before its shots), then the monsters (12)
			if (all.size() < Darkness.MAX_LIGHTS and (fight < 16 or bodies < 12)) or warnings != 3 or fight > 16 or bodies > 12 or (fight < 16 and bodies > 0):
				shares_kept = false
				printerr("  floor %d room %d: %d lights, %d warnings, %d fight, %d monsters" % [n, r.index, all.size(), warnings, fight, bodies])
			g.monsters.zones.clear()
		check(rooms > 3, "hell floor %d has fight rooms (%d)" % [n, rooms])
		check(dark_fires.is_empty(), "floor %d: every fire on screen keeps its light in a crowded fight (dark: %s)" % [n, dark_fires])
		check(fires_first, "floor %d: the fires on screen come before the fight's shots, as the crypt's braziers before its bullets" % n)
		check(shares_kept, "floor %d: the fight's warnings come first and the fight and the monsters keep their shares (16, 12) of what is left" % n)
		# the screen before the margin: 20 shots on screen take the fight's share, one in the margin waits
		g.mobs.clear()
		g.eshots.clear()
		var room: Dictionary = g.W.rooms[g.state.room]
		var c := _centre_on(g, room)
		var view: Rect2 = g._view_rect()
		for i in range(20):
			g.eshots.append({"p": c + Vector2(-400 + i * 40, 60), "v": Vector2.ZERO, "t": 9.0, "c": "fire"})
		var outside := Vector2(view.end.x + 200.0, c.y)
		g.eshots.append({"p": outside, "v": Vector2.ZERO, "t": 9.0, "c": "fire"})
		var fill: Array = sg.lights()
		var on_screen := (g.eshots as Array).filter(func(e: Dictionary) -> bool: return view.has_point(e.p) and _index_near(fill, e.p) >= 0).size()
		check(on_screen == 16 and _index_near(fill, outside) < 0, "floor %d: shots on screen take the fight's share before a shot in the margin (%d)" % [n, on_screen])
		# the exits come last, glowing posts that stand together give one light
		g.eshots.clear()
		var quiet: Array = sg.lights()
		var exits: Array = sg.exit_lights(view.grow(StoryGlow.REACH), view.get_center())
		var first_exit := quiet.size()
		for l: Vector4 in exits:
			var at := _index_near(quiet, Vector2(l.x, l.y))
			if at >= 0: first_exit = mini(first_exit, at)
		var after := quiet.slice(first_exit).all(func(l: Vector4) -> bool: return exits.any(func(e: Vector4) -> bool: return Vector2(e.x, e.y).distance_to(Vector2(l.x, l.y)) < 0.5))
		check(not exits.is_empty() and after, "floor %d: the exits are the last lights, as the crypt's" % n)
		await _free(g)
	# two glowing posts of one door gap share one exit light
	var h := await _new(HellScene)
	var walls: Dictionary = h.walls
	var doors: Array = h.W.doors
	var at := _hero(h)
	h.walls = {"posts": [at, at + Vector2(96, 0), at + Vector2(900, 0)], "south": [], "side": []}
	h.W.doors = []
	var pair: Array = h.story_glow.exit_lights(Rect2(at - Vector2(2000, 2000), Vector2(4000, 4000)), at)
	check(pair.size() == 2 and is_equal_approx(pair[0].z, StoryGlow.EXIT_LIGHT.x * h.story_glow.scale), "two posts 96 px apart give one exit light, a third far off its own (%d)" % pair.size())
	h.walls = walls
	h.W.doors = doors
	await _free(h)


## The world's own zones (hell_game.gd zones: Hrimgar's boss kit, the hero's and
## relics' skills) light the dark by boss_fx.gd's rule; an icicle's strike and
## the world's skill blasts flare.
func test_world_zones() -> void:
	var f := await _new(FrostScene)
	var sg: RefCounted = f.story_glow
	var s: float = sg.scale
	var me := _hero(f)
	# Hrimgar's icicles and chill fields (boss_kit.gd)
	f.zones.append({"kind": "icicle", "p": me + Vector2(160, 40), "r": 70.0, "t": 0.5, "max": 1.0})
	f.zones.append({"kind": "chill", "p": me + Vector2(-200, -40), "r": 110.0, "t": 3.0, "max": 3.0})
	f.zones.append({"kind": "telegraph", "p": me + Vector2(0, -220), "r": 150.0, "t": 0.8, "max": 0.8})
	var lights: Array = sg.combat_lights()
	var icicle := _light_near(lights, me + Vector2(160, 40))
	check(is_equal_approx(icicle.z, maxf(40.0, 70.0 / s * 1.3) * s) and is_equal_approx(icicle.w, 0.6), "Hrimgar's icicle warning lights like the crypt's ice strike (%s)" % icicle)
	var chill := _light_near(lights, me + Vector2(-200, -40))
	check(is_equal_approx(chill.z, maxf(40.0, 110.0 / s * 1.3) * s), "a chill field lights like the crypt's frost pool (%s)" % chill)
	check(_light_near(lights, me + Vector2(0, -220)) == Vector4.ZERO, "a charge telegraph is a ring: by the crypt's rule it casts no light")
	# the icicle strikes: it vanishes from the world and flares
	f.zones[0].t = 0.02
	f.state.light = true
	sg.frame()
	f.zones = []
	f.state.t = float(f.state.t) + 0.05
	sg.frame()
	var flare: Array = _of(sg.attack_items(), "strike")
	check(flare.size() == 1 and Color(flare[0].color).a > 0.3, "the icicle's strike flares in the bloom")
	check(_light_near(sg.combat_lights(), me + Vector2(160, 20), 1.0).z > 70.0, "the strike lights the dark")
	f.state.t = float(f.state.t) + 1.0
	sg.frame()
	check(_of(sg.attack_items(), "strike").is_empty(), "the flare fades")
	# a chill field that runs out does not flare
	f.zones = [{"kind": "chill", "p": me, "r": 110.0, "t": 0.02, "max": 3.0}]
	sg.frame()
	f.zones = []
	f.state.t = float(f.state.t) + 0.05
	sg.frame()
	check(_of(sg.attack_items(), "strike").is_empty(), "a chill field that ends does not strike")
	await _free(f)
	var g := await _new(HellScene)
	var hg: RefCounted = g.story_glow
	var hs: float = hg.scale
	me = _hero(g)
	# the hero's meteor rain (hero_kit.gd) and a relic's meteor (relic_kit.gd): fire strikes
	g.zones.append({"kind": "meteor", "p": me + Vector2(200, 0), "r": 150.0, "t": 0.6, "max": 0.6})
	var meteor := _light_near(hg.combat_lights(), me + Vector2(200, 0))
	check(is_equal_approx(meteor.z, maxf(40.0, 150.0 / hs * 1.3) * hs) and is_equal_approx(meteor.w, 0.6), "the hero's meteor warning lights like the crypt's fire strike (%s)" % meteor)
	g.zones.clear()
	# its impact: the quake the world leaves (relic_kit.gd) blooms and lights
	g.fx.append({"kind": "quake", "p": me + Vector2(-180, 0), "r": 150.0, "t": 0.5, "max": 0.5})
	check(_of(hg.attack_items(), "quake").size() == 1, "a quake (the meteor's impact) blooms")
	check(_light_near(hg.combat_lights(), me + Vector2(-180, 0)).z > 100.0, "a quake lights the dark")
	g.fx.clear()
	# a gravity blast and a subclass ring bloom in their colours
	g.fx.append({"kind": "blast", "p": me + Vector2(0, 150), "r": 90.0, "t": 0.3, "max": 0.3, "gravity": true, "shot": "gravity"})
	g.fx.append({"kind": "sub_ring", "p": me + Vector2(0, -150), "r": 120.0, "t": 0.45, "max": 0.45, "c": Color(0.5, 0.9, 0.4)})
	var items: Array = hg.attack_items()
	check(_of(items, "blast_gravity").size() == 1 and _of(items, "ring").size() == 1 and Color(_of(items, "ring")[0].color).g > 0.85, "a gravity blast and a subclass ring bloom, the ring in its own colour")
	# a fireball's blast is the crypt bridge's (story_skill_fx.gd): not bloomed twice
	g.fx.clear()
	g.fx.append({"kind": "blast", "p": me + Vector2(0, 150), "r": 90.0, "t": 0.3, "max": 0.3, "gravity": false, "shot": "fireball"})
	check(_of(hg.attack_items(), "blast").is_empty(), "a fireball's blast is left to the crypt bridge")
	g.fx.clear()
	await _free(g)


func test_frost_lights() -> void:
	var g := await _new(FrostScene)
	var sg: RefCounted = g.story_glow
	var me := _hero(g)
	var s: float = sg.scale
	# the enemy moves' strikes light like the crypt's boss strikes
	g.state.mzones = [{"kind": "strike", "p": me + Vector2(140, 30), "r": 60.0, "t": 0.5, "max": 1.0, "dmg": 1, "effect": {}, "style": "ice", "pool": {}}]
	var strike := _light_near(sg.combat_lights(), me + Vector2(140, 30))
	check(is_equal_approx(strike.z, maxf(40.0, 60.0 / s * 1.3) * s), "a frost strike lights like the crypt's strike (%s)" % strike)
	g.state.mzones = []
	# move shots: the ice shard lights like magic
	g.eshots.append({"p": me + Vector2(220, 0), "v": Vector2(-300, 0), "t": 2.0, "style": "ice", "size": 14.0})
	check(is_equal_approx(_light_near(sg.combat_lights(), me + Vector2(220, 0)).z, 46.0 * s), "an ice shard lights the dark")
	g.eshots.clear()
	# glaze ice is no lava: no light, no bloom
	check(sg.lava_lights(g._view_rect().grow(4000)).is_empty() and sg.lava_items().is_empty(), "the Frostgruft's glaze ice neither lights nor blooms")
	await _free(g)


# --- the map --------------------------------------------------------------------------

func test_map_bloom() -> void:
	var g := await _new(HellScene, 1)
	var sg: RefCounted = g.story_glow
	var s: float = sg.scale
	var big: Dictionary = {}
	for li: Dictionary in g.W.lights:
		if float(li.r) >= 300.0 and str(li.c) == "255,140,60":
			big = li
			break
	check(not big.is_empty(), "hell floor 1 has a standing brazier")
	g.camera.position = Vector2(big.x, big.y)
	var items: Array = sg.map_items()
	var flame: Array = items.filter(func(i: Dictionary) -> bool: return (i.p as Vector2).is_equal_approx(Vector2(big.x, big.y)))
	check(flame.size() == 1 and str(flame[0].kind) == "flame_brazier", "the brazier blooms once at its light")
	if flame.size() == 1:
		check(absf(float(flame[0].r) - 50.0 * s) <= 3.0 * s + 0.01, "a standing brazier blooms like the crypt's brazier (50 crypt px, %s)" % flame[0].r)
		var c: Color = flame[0].color
		check(c.is_equal_approx(Color(Color8(255, 140, 60), c.a)) and is_equal_approx(c.a, 0.22 * sg.glow.level("torches")), "the hell brazier blooms in its own light colour (%s)" % c)
	var near: Rect2 = g._view_rect().grow(StoryGlow.FIRE_MARGIN)
	var in_view := (g.W.lights as Array).filter(func(li: Dictionary) -> bool: return near.has_point(Vector2(li.x, li.y))).size()
	check(items.filter(func(i: Dictionary) -> bool: return str(i.kind).begins_with("flame_")).size() == in_view, "fires outside the view do not bloom (%d in view)" % in_view)
	var all: Array = sg.lights()
	check((g.W.lights as Array).all(func(li: Dictionary) -> bool: return not near.has_point(Vector2(li.x, li.y)) or _index_near(all, Vector2(li.x, li.y)) >= 0), "every blooming fire lights the dark: bloom and light agree")
	var rune: Dictionary = {}
	for li: Dictionary in g.W.lights:
		if float(li.r) < 220.0:
			rune = li
			break
	if not rune.is_empty():
		g.camera.position = Vector2(rune.x, rune.y)
		var glow_items: Array = sg.map_items().filter(func(i: Dictionary) -> bool: return (i.p as Vector2).is_equal_approx(Vector2(rune.x, rune.y)))
		check(glow_items.size() == 1 and str(glow_items[0].kind) == "flame_rune" and is_equal_approx(float(glow_items[0].r), float(sg.bloom.rune.r) * s), "rune pillars and obelisks glow slowly (story.bloom.rune)")
	# loot: a key blooms as the crypt's loot (skill_fx.gd draws it) and, like the crypt's loot, casts no light
	var at := Vector2(g.camera.position)
	g.W.ents.append({"type": "key", "key": "A", "x": at.x + 40.0, "y": at.y, "room": g.state.room})
	var loot: Array = _of(sg.map_items(), "loot")
	check(loot.any(func(i: Dictionary) -> bool: return absf((i.p as Vector2).x - (at.x + 40.0)) < 1.0 and str(i.get("crypt", "")) == "loot"), "a key blooms like the crypt's loot")
	check(_light_near(sg.map_lights(), Vector2(at.x + 40.0, at.y - 30.0), 40.0) == Vector4.ZERO, "a key casts no light, like the crypt's loot")
	g.W.ents.pop_back()
	# a lit puzzle brazier brings its own light and bloom (hell_game.gd appends it to W.lights)
	var count: int = g.W.lights.size()
	g.W.lights.append({"x": at.x, "y": at.y - 70.0, "r": 280, "c": "255,140,60"})
	check(sg.map_items().any(func(i: Dictionary) -> bool: return (i.p as Vector2).is_equal_approx(Vector2(at.x, at.y - 70.0))), "a lit puzzle brazier blooms")
	check(_index_near(sg.lights(), Vector2(at.x, at.y - 70.0)) >= 0, "a lit puzzle brazier lights the dark")
	g.W.lights.resize(count)
	# portals and seals: the story worlds' own bloom kinds with the world's own lights
	g.W.ents.append({"type": "portal", "active": true, "x": at.x - 200.0, "y": at.y, "room": g.state.room})
	g.W.ents.append({"type": "seal", "broken": false, "x": at.x + 200.0, "y": at.y, "room": g.state.room})
	items = sg.map_items()
	check(_of(items, "portal").size() == 2 and _of(items, "seal").size() == 1, "an awake portal and a seal bloom")
	var portal := _light_near(sg.map_lights(), Vector2(at.x - 200.0, at.y - 60.0), 1.0)
	check(is_equal_approx(portal.z, float(sg.bloom.portal.light[0])), "an awake portal keeps the world's own light (%s)" % portal)
	g.W.ents.resize(g.W.ents.size() - 2)
	await _free(g)
	var f := await _new(FrostScene, 1)
	var fg: RefCounted = f.story_glow
	var any_light: Dictionary = f.W.lights[0]
	f.camera.position = Vector2(any_light.x, any_light.y)
	var frost_flames: Array = fg.map_items().filter(func(i: Dictionary) -> bool: return str(i.kind).begins_with("flame_"))
	var blue := Color("#8cc8f2")
	check(not frost_flames.is_empty() and frost_flames.all(func(i: Dictionary) -> bool: return Color(i.color).is_equal_approx(Color(blue, Color(i.color).a))), "the Frostgruft's fires bloom in its blue flame colour, not the hell's orange")
	check(frost_flames.all(func(i: Dictionary) -> bool: return not Color(i.color).is_equal_approx(Color(Color8(255, 140, 60), Color(i.color).a))), "no orange fire in the Frostgruft")
	await _free(f)


# --- shots ----------------------------------------------------------------------------

func test_shots() -> void:
	var g := await _new(HellScene)
	var sg: RefCounted = g.story_glow
	var me := _hero(g)
	g.eshots.append({"p": me + Vector2(100, 0), "v": Vector2.ZERO, "t": 2.0, "c": "fire"})
	g.eshots.append({"p": me + Vector2(150, 0), "v": Vector2.ZERO, "t": 2.0, "c": "void"})
	g.eshots.append({"p": me + Vector2(200, 0), "v": Vector2.ZERO, "t": 2.0, "c": "fire", "small": true})
	g.eshots.append({"p": me + Vector2(250, 0), "v": Vector2.ZERO, "t": 2.0, "c": "chain"})
	g.eshots.append({"p": me + Vector2(300, 0), "v": Vector2.ZERO, "t": 2.0, "c": "soul"})
	var items: Array = sg.shot_items()
	var styles: Array = items.map(func(i: Dictionary) -> String: return str(i.bullet.style))
	check(styles == ["fireball", "void_skull", "magic", "magic"], "hell shots bloom as the crypt's fireball, void skull and magic; chains do not (%s)" % [styles])
	check(items.size() == 4 and str(items[2].bullet.element) == "cinder" and str(items[3].bullet.element) == "venom", "breath flames are cinder, soulfire is green venom")
	sg.glow.scales["bullets"] = 0.0
	check(sg.shot_items().is_empty(), "vfx_glow.json bullets 0 switches the shots' bloom off")
	sg.glow.scales["bullets"] = 1.0
	# lobs and falling meteors glow in the air
	g.eshots.clear()
	g.monsters.lobs.append({"from": me, "to": me + Vector2(300, 0), "t": 0.4, "T": 0.8, "r": 70.0, "dmg": 1, "m": {}, "c": "lava", "done": false})
	g.monsters.zones.append({"kind": "meteor", "p": me + Vector2(0, 100), "r": 80.0, "T": 1.35, "t": 0.5, "tele": 1.0, "dmg": 1, "done": false, "m": {}})
	items = sg.shot_items()
	check(items.size() == 2 and (items[0].p as Vector2).y < me.y - 100.0 and (items[1].p as Vector2).y < me.y, "a lob and a falling meteor glow in the air")
	await _free(g)
	var f := await _new(FrostScene)
	var fg: RefCounted = f.story_glow
	f.eshots.append({"p": _hero(f) + Vector2(100, 0), "v": Vector2(1, 0), "t": 2.0, "style": "ice", "size": 14.0})
	f.eshots.append({"p": _hero(f) + Vector2(140, 0), "v": Vector2(1, 0), "t": 2.0})
	f.eshots.append({"p": _hero(f) + Vector2(180, 0), "v": Vector2(1, 0), "t": 2.0, "fist": true})
	var fstyles: Array = fg.shot_items().map(func(i: Dictionary) -> String: return str(i.bullet.style))
	check(fstyles == ["shard", "magic", "fist"], "Frostgruft shots bloom as shards, magic and Hrimgar's fist (%s)" % [fstyles])
	await _free(f)


# --- the monsters' attacks ------------------------------------------------------------

func test_attacks() -> void:
	var g := await _new(HellScene)
	var sg: RefCounted = g.story_glow
	var me := _hero(g)
	var boss: Dictionary = g.monsters.spawn(g.state.room, me + Vector2(300, 0), "drache4", true)
	boss.spawn = 0.0
	boss.act = {"kind": "beam", "beams": [0.5], "warn": false, "t": 1.2, "a": {"turn": 0.5, "duration": 4.0}, "anim": "cast", "dir": Vector2.RIGHT, "n": 0, "v": Vector2.ZERO}
	var beam: Array = _of(sg.attack_items(), "beam")
	check(beam.filter(func(i: Dictionary) -> bool: return i.has("to")).size() == 2 and beam.filter(func(i: Dictionary) -> bool: return not i.has("to")).size() == 1, "a burning void beam: a halo band, a core band, a flare at the mouth")
	boss.act.warn = true
	check(_of(sg.attack_items(), "beam").is_empty(), "a beam's warning does not bloom")
	boss.act.warn = false
	sg.glow.scales["void"] = 0.0
	check(_of(sg.attack_items(), "beam").is_empty(), "the beams bloom at vfx_glow.json's void level")
	sg.glow.scales["void"] = 1.0
	g.mobs.clear()
	g.monsters.zones.append({"kind": "meteor", "p": me + Vector2(0, 120), "r": 80.0, "T": 1.35, "t": 1.0, "tele": 1.0, "dmg": 1, "done": true, "m": {}})
	var impact: Array = _of(sg.attack_items(), "impact")
	check(impact.size() == 1 and Color(impact[0].color).a > 0.4, "a meteor's impact flares in the bloom")
	g.monsters.zones[0].t = 1.35
	check(_of(sg.attack_items(), "impact").is_empty(), "the impact's glow is gone when the zone ends")
	g.monsters.zones.clear()
	# a magma puddle glows as the crypt's lava zone (skill_fx.gd draws it)
	g.monsters.zones.append({"kind": "puddle", "p": me + Vector2(150, 50), "r": 52.0, "T": 2.6, "t": 0.5, "tele": 0.0, "dmg": 1, "done": false, "m": {}})
	var puddle: Array = _of(sg.attack_items(), "puddle")
	check(puddle.size() == 1 and str(puddle[0].crypt) == "lava" and str(puddle[0].zone.kind) == "lava" and is_equal_approx(float(puddle[0].zone.r), 52.0 / sg.scale), "a magma puddle glows as the crypt's lava zone")
	g.monsters.zones.clear()
	var lord: Dictionary = g.monsters.spawn(g.state.room, me + Vector2(200, 0), "drache1", true)
	lord.spawn = 0.0
	lord.trans = {"glow": 1.0, "grow": 1.0, "swapped": false}
	check(_of(sg.attack_items(), "transform").size() == 2, "the transformation glows as a halo and a core")
	await _free(g)
	var f := await _new(FrostScene)
	var fg: RefCounted = f.story_glow
	f._spawn_mob(f.state.room, _hero(f) + Vector2(200, 0), "frost_whirl")
	check(_of(fg.attack_items(), "pull").size() == 1, "a frost whirl's pull glows faintly")
	check(fg.mob_lights().size() == 1 and fg.mob_lights()[0].z > 120.0, "a frost whirl lights its pull like the crypt's vortex")
	await _free(f)


# --- the monsters' glowing parts -----------------------------------------------------

func test_mob_parts() -> void:
	var g := await _new(HellScene)
	var sg: RefCounted = g.story_glow
	var me := _hero(g)
	var shepherd: Dictionary = g.monsters.spawn(g.state.room, me + Vector2(250, 0), "seelenhirte", true)
	shepherd.spawn = 0.0
	var def: Dictionary = g.monsters.defs.seelenhirte
	var drawn := _drawn(sg, shepherd, Vector2(float(def.w), float(def.h)), float(shepherd.s))
	var items: Array = _of(sg.mob_items(), "seelenhirte")
	check(items.size() == 1, "the soul shepherd's lantern glows (no cast, no spiral: %d)" % items.size())
	if items.size() == 1:
		var lantern: Dictionary = items[0]
		var expected := StoryGlow.anchor(drawn, [23, 10.5])
		check((lantern.p as Vector2).is_equal_approx(expected) and (lantern.p as Vector2).y < (shepherd.p as Vector2).y - 100.0, "the lantern glows at the lantern, high on the body")
		check(Color(lantern.color).is_equal_approx(Color(Color("#97da3f"), Color(lantern.color).a)), "in soulfire green")
		var full := Color(lantern.color).a
		_drawn(sg, shepherd, Vector2(float(def.w), float(def.h)), float(shepherd.s), 0.0, 0.5)
		check(is_equal_approx(Color(_of(sg.mob_items(), "seelenhirte")[0].color).a, full * 0.5), "a fading body fades its glow")
		sg.glow.scales["mobs"] = 0.0
		check(_of(sg.mob_items(), "seelenhirte").is_empty(), "vfx_glow.json mobs 0 switches the parts off")
		sg.glow.scales["mobs"] = 1.0
	check(not shepherd.has("drawn"), "the bloom keeps its records itself: no mark on the world's monster")
	shepherd.act = {"kind": "spiral", "t": 1.0, "a": {}, "anim": "cast"}
	shepherd.anim = "cast"
	_drawn(sg, shepherd, Vector2(float(def.w), float(def.h)), float(shepherd.s))
	check(_of(sg.mob_items(), "seelenhirte").size() == 3, "casting a spiral the lantern flares and the hand burns")
	for i in range(3):
		await process_frame
	check(_of(sg.mob_items(), "seelenhirte").is_empty(), "a body the world did not draw this frame does not glow")
	g.mobs.clear()
	# a sinking dragon hides what is under the floor
	var drake: Dictionary = g.monsters.spawn(g.state.room, me + Vector2(250, 0), "drache4", true)
	drake.spawn = 0.0
	var ddef: Dictionary = g.monsters.defs.drache4
	_drawn(sg, drake, Vector2(float(ddef.w), float(ddef.h)), float(drake.s))
	var standing := _of(sg.mob_items(), "drache4").size()
	_drawn(sg, drake, Vector2(float(ddef.w), float(ddef.h)), float(drake.s), float(ddef.h) * float(drake.s) * 0.5)
	var sinking := _of(sg.mob_items(), "drache4").size()
	check(standing == 3 and sinking == 1, "a dragon sinking into the floor hides its tail and core glow (%d -> %d)" % [standing, sinking])
	await _free(g)
	# Frostgruft
	var f := await _new(FrostScene)
	var fg: RefCounted = f.story_glow
	f._spawn_mob(f.state.room, _hero(f) + Vector2(200, 0), "ice_crystal")
	var crystal: Dictionary = f.mobs[f.mobs.size() - 1]
	crystal.spawn = 0.0
	crystal.shoot = 2.0
	_drawn(fg, crystal, Vector2(48, 120), float(crystal.ds))
	var calm: Array = _of(fg.mob_items(), "mob_ice_crystal_0")
	crystal.shoot = 0.1
	var charged: Array = _of(fg.mob_items(), "mob_ice_crystal_0")
	check(calm.size() == 1 and charged.size() == 1 and Color(charged[0].color).a > Color(calm[0].color).a + 0.1, "an ice crystal's core brightens before it fires")
	f._spawn_mob(f.state.room, _hero(f) + Vector2(-200, 0), "ice_zombie")
	var zombie: Dictionary = f.mobs[f.mobs.size() - 1]
	_drawn(fg, zombie, Vector2(48, 48), 2.0)
	check(_of(fg.mob_items(), "mob_ice_zombie_f").is_empty(), "an ice zombie does not glow")
	var hrimgar := {"p": _hero(f) + Vector2(0, -250), "look": {"sprite": "boss_golem_p1_f"}, "seed": 0.0, "hp": 100.0}
	f.mobs.append(hrimgar)
	_drawn(fg, hrimgar, Vector2(192, 192), 1.0)
	check(_of(fg.mob_items(), "boss_golem_p1_f").is_empty(), "Hrimgar's armour phase has no glowing core")
	hrimgar.look = {"sprite": "boss_golem_p2_f"}
	var core: Array = _of(fg.mob_items(), "boss_golem_p2_f")
	check(core.size() == 1 and Color(core[0].color).a >= 0.45, "Hrimgar's glacier core glows clearly in phase 2")
	await _free(f)


## What hides behind a front wall (the hell's south wall strips, drawn over the
## actors) does not bloom through it.
func test_front_wall() -> void:
	var g := await _new(HellScene)
	var sg: RefCounted = g.story_glow
	var strip: Dictionary = {}
	for w: Dictionary in g.walls.south:
		if float(w.x1) - float(w.x0) >= 3.0 * float(g.C):
			strip = w
			break
	check(not strip.is_empty(), "the hell floor has a front wall")
	if strip.is_empty():
		await _free(g)
		return
	var behind := Vector2((float(strip.x0) + float(strip.x1)) * 0.5, float(strip.y) + 20.0)
	var above := behind - Vector2(0, 60.0)
	check(sg.behind_wall(behind) and not sg.behind_wall(above), "a point under a front wall is covered, the floor above it is not")
	g.camera.position = behind
	g.embers.append({"p": behind, "v": Vector2.ZERO, "t": 1.0, "big": false, "gold": false})
	g.embers.append({"p": above, "v": Vector2.ZERO, "t": 1.0, "big": false, "gold": false})
	var embers := _of(sg.map_items(), "ember")
	check(embers.size() == 1 and (embers[0].p as Vector2).is_equal_approx(above), "an ember behind a front wall does not bloom through it")
	g.embers.clear()
	# a soul shepherd whose lantern is behind the wall
	var shepherd: Dictionary = g.monsters.spawn(g.state.room, above, "seelenhirte", true)
	shepherd.spawn = 0.0
	var def: Dictionary = g.monsters.defs.seelenhirte
	var src := Vector2(float(def.w), float(def.h))
	var probe := {"foot": Vector2.ZERO, "size": src * float(shepherd.s), "src": src, "face": 1.0, "lean": 0.0, "cut": 0.0}
	var offset := StoryGlow.anchor(probe, [23, 10.5])
	sg.mark(shepherd, {"foot": behind - offset, "size": src * float(shepherd.s), "src": src, "face": 1.0, "lean": 0.0, "cut": 0.0, "alpha": 1.0})
	check(_of(sg.mob_items(), "seelenhirte").is_empty(), "a lantern behind a front wall does not bloom through it")
	sg.mark(shepherd, {"foot": above - offset, "size": src * float(shepherd.s), "src": src, "face": 1.0, "lean": 0.0, "cut": 0.0, "alpha": 1.0})
	check(_of(sg.mob_items(), "seelenhirte").size() == 1, "in front of the wall it blooms")
	await _free(g)


## The world itself records where it drew each body (hell_monsters.gd _mark and
## hell_game.gd _draw_mob_sprite), so the glow follows the real drawing.
func test_drawn_by_the_world() -> void:
	for spec: Array in [[HellScene, "glutschaedel"], [FrostScene, "ice_crystal"]]:
		var g := await _new(spec[0])
		var me := _hero(g)
		if g.monsters != null:
			var m: Dictionary = g.monsters.spawn(g.state.room, me + Vector2(160, 0), str(spec[1]))
			m.spawn = 0.0
		else:
			g._spawn_mob(g.state.room, me + Vector2(160, 0), str(spec[1]))
			g.mobs[g.mobs.size() - 1].spawn = 0.0
		var m: Dictionary = g.mobs[g.mobs.size() - 1]
		var drawn: Dictionary = {}
		for i in range(3):
			g.actors.queue_redraw()
			await process_frame
			drawn = g.story_glow.drawn_of(m)
			if not drawn.is_empty():
				break
		check(not drawn.is_empty() and (drawn.foot as Vector2).distance_to(m.p) < 30.0, "%s: the world records where it drew the %s" % [spec[0].resource_path.get_file(), spec[1]])
		await _free(g)
