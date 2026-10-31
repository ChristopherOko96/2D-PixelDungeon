@tool
extends Node2D
## Pixel chamber presentation for Basement Run. Receives authoritative state;
## owns no combat, movement, rewards, or networking decisions.

const Tiles = preload("res://src/dungeon_tiles.gd")
const ItemArt = preload("res://src/item_art.gd")
const PerkIcons = preload("res://src/perk_icons.gd")
const CryptEnemySprites = preload("res://src/crypt_enemy_sprites.gd")
const ActorBank = preload("res://src/actor_animation_bank.gd")
const ActorMotion = preload("res://src/actor_motion_controller.gd")
const INK := Color("#10101c")
const GOLD := Color("#efc76a")
const MUTED := Color("#77728b")
const PLAYER_COLORS := [
	Color("#72dcc8"), Color("#edb563"), Color("#bc91de"), Color("#ed8a91")
]
const HERO_SPRITES := ["knight_m","elf_f","wizzard_m","lizard_m","necromancer","custom_pyromancer"]
const PLAYER_ACTORS := ["player_warden","player_ranger","player_arcanist","player_lizard"]
const ENEMY_SPRITES := {"chaser":"goblin","shooter":"orc_shaman","boss":"big_demon"}
const SPRITE_ROOT := "res://assets/sprites/0x72/"
# Hero classes (step 2, from main): class -> 0x72 figure, weapon -> 0x72 sprite
# (drawn blade-up in the art). Players with a class use these, not the chibi bank.
## The mage is the 0x72 wizard; his element only recolours him (src/hero/element_skin.gd), the pyromancer look is the fire spec (user decision 2026-10-31).
const CLASS_SPRITES := {"swordsman":"knight_m","archer":"elf_f","mage":"wizzard_m","necromancer":"necromancer"}
const WEAPON_SPRITES := {"sword":"weapon_regular_sword","bow":"weapon_bow","staff":"weapon_green_magic_staff","bone_staff":"weapon_red_magic_staff"}
const ARROW_TEXTURE := preload("res://assets/sprites/0x72/weapon_arrow.png")
const FRAMES_PER_SECOND := 8.0
const Feedback = preload("res://src/vfx/feedback.gd")
const Sfx = preload("res://src/vfx/sfx.gd")
const Music = preload("res://src/audio/music.gd")
const Palette = preload("res://src/tile_palette.gd")
const CryptArt = preload("res://src/crypt_art.gd")
const Living = preload("res://src/living_sprite_library.gd")
const UnifiedSkin = preload("res://src/unified_dungeon_skin.gd")
const ORIGINAL_TORCH: Texture2D = preload("res://assets/sprites/torch.png")
const ClassicArt = preload("res://src/classic_dungeon_art.gd")
const RigRenderer = preload("res://src/rig/rig_renderer.gd")
const Darkness = preload("res://src/vfx/darkness.gd")
const Crypt72 = preload("res://src/crypt_0x72_art.gd")
const SkillFx = preload("res://src/vfx/skill_fx.gd")
const BossFx = preload("res://src/vfx/boss_fx.gd")
const PoolPaint = preload("res://src/vfx/pool_paint.gd")
const Gas = preload("res://src/vfx/gas.gd")
const ElementRules = preload("res://src/combat/element_rules.gd")
const PixelPaint = preload("res://src/vfx/pixel_paint.gd")
const PerkMarks = preload("res://src/vfx/perk_marks.gd")
const AttackFx = preload("res://src/vfx/attack_fx.gd")
const HeroLook = preload("res://src/hero/hero_look.gd")
const Familiar = preload("res://src/hero/familiar.gd")
const SliceFx = preload("res://src/vfx/slice_fx.gd")
const FxSprites = preload("res://src/vfx/fx_sprites.gd")
const Glow = preload("res://src/vfx/glow.gd")
const SheetArt = preload("res://src/vfx/sheet_art.gd")
const FogMemory = preload("res://src/vfx/fog_memory.gd")
const TalentFx = preload("res://src/vfx/talent_fx.gd")
const CryptAtmosphere = preload("res://src/vfx/crypt_atmosphere.gd")
## Hero class -> part rig of its 0x72 figure (assets/data/rigs.json).
## The mage is the wizard rig again, its parts recoloured by his element
## (src/hero/element_skin.gd, hero_skins.json; user decision 31.10.2026).
const CLASS_RIGS := {"swordsman":"knight","archer":"elf","mage":"wizard"}

@export var style_profile: Resource = preload("res://assets/data/art_style_reference.tres")

var _snapshot: Dictionary = {}
var _local_peer: int = 1
var _clock: float = 0.0
var _effects_visible := true
## Editor/reference previews may show spawn health; live play uses the heart HUD.
var show_player_health := true
var audio_enabled := false
var _animation_enabled := true
var _environment_animation_enabled := false
var _environment_clock := 0.0
var _sprites: Dictionary = {}
var _flash_textures: Dictionary = {}
var _feedback := Feedback.new()
var _sfx: Node
## Background music and ambience (src/audio/music.gd), made with the sound.
var _music: Node
## False while the view shows a menu backdrop rather than a run (the game sets it).
var music_in_run := true
var _base_position := Vector2.ZERO
var _shake_rng := RandomNumberGenerator.new()
## The room's gas layer (src/vfx/gas.gd), made with the room's pools.
var _gas: RefCounted = null
## The view inside gas (_step_vision, element_rules.json vision): k = how closed
## it is 0..1, r = world px kept open round the local hero, probe = s to the next
## measurement of the cloud's reach.
var _vision := {"k": 0.0, "r": 0.0, "probe": 0.0}
## Camera shake strength from the options (1 = full, 0 = off); presentation only.
var shake_scale := 1.0
var _classic := ClassicArt.new()
var _crypt_sprites := CryptEnemySprites.new()
var _crypt_bounds: Dictionary = {}
var _actor_bank := ActorBank.new()
var _actor_motion := ActorMotion.new()
var _actors_ready: bool = false
var _classic_enabled := false
var _decoration_enabled := true
var _layout_key := ""
var _presentation_layout: Dictionary = {}
var _base_cells: Array = []
var _room_entries: Array[Dictionary] = []
var _fire_entries: Array[Dictionary] = []
var _pending_snapshot: Dictionary = {}
var _observed_sequence := ""
var _accepted_visual := ""
var _weapon_textures: Dictionary = {}
## Part-rigged figures, debris and void effects (src/rig/rig_renderer.gd).
var _rigs: RefCounted
## Hero skills, EXP orbs and ultimates (src/vfx/skill_fx.gd).
var _skill_fx := SkillFx.new()
var _boss_fx := BossFx.new()
## Archer arrows and mage spells: streaks, orbs, release flashes, bursts.
var _attack_fx := AttackFx.new()
## Class heroes with their weapons (shared with the story worlds): swings, bow draw, Rage blades.
var _hero_look := HeroLook.new(2.0, preload("res://assets/sprites/0x72/weapon_knight_sword.png"), preload("res://assets/sprites/0x72/weapon_arrow.png"))
## Small enemies cut in two by Rage (created with the rigs).
var _slices: RefCounted
## Pixel-art effect animations (assets/sprites/fx), shared by feedback and skills.
var _fx := FxSprites.new()
## Sheet monsters of the themed endless floors, their hazards and shots.
var _sheet_art := SheetArt.new()
## Wolves, traps, poison zones and talent effects.
var _talent_fx := TalentFx.new()
## Fog of war on themed open floors (explored areas stay dimmed).
var _fog_memory: Node2D
var _fx_layout_key := ""
## Dark crypt (live runs only, set by the game): balance.json "lighting".
var darkness_enabled := false
var lighting: Dictionary = {}
var _darkness: Node2D
## Bloom over the dark crypt (src/vfx/glow.gd): shown with the darkness.
var _glow: Glow
## 0x72 crypt rooms (live runs only, set by the game) and the baked room.
var crypt_0x72_enabled := false
var _crypt72: RefCounted
## Wall torches of the 0x72 room (world px), lit in the dark crypt.
var _room_torches: Array[Vector2] = []
## Void atmosphere of the live crypt (assets/data/vfx_crypt_atmosphere.json,
## parsed by src/vfx/crypt_atmosphere.gd): room filter, fog, violet flames.
var atmosphere: Dictionary = {}
## The 0x72 room drawn behind the view's own drawing, so only it gets the filter.
var _room_layer: Node2D
var _fog: Node2D
var _grade_material: ShaderMaterial


func _ready() -> void:
	_feedback.fx = _fx
	_skill_fx.fx = _fx
	# The crypt's rigged hero figure is about 37 px tall with its anchor 16 px above
	# the feet: the staff is sized and gripped by that body (src/hero/hero_look.gd).
	_hero_look.hero_px = 1.75
	_hero_look.staff_hand = Vector2(3.5, -2.5)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_base_position = position
	_actors_ready = _actor_bank.prepare()
	_actor_motion.configure(_actor_bank.catalog())
	_rigs = RigRenderer.new()
	_slices = SliceFx.new(_rigs.library)
	_talent_fx.rigs = _rigs
	if not Engine.is_editor_hint():
		# Room and fog layers come first: they draw behind the view itself
		# (or the fog over the actors, under the darkness, when the data says so).
		atmosphere = CryptAtmosphere.load_data()
		_grade_material = CryptAtmosphere.grade_material(atmosphere.grade)
		_room_layer = CryptAtmosphere.RoomLayer.new()
		_room_layer.show_behind_parent = true
		_room_layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_room_layer.source = _draw_room_layer
		add_child(_room_layer)
		_fog = CryptAtmosphere.CryptFog.new()
		_fog.show_behind_parent = not bool(atmosphere.fog.over_actors)
		_fog.configure(atmosphere.fog)
		_fog.visible = false
		add_child(_fog)
		_darkness = Darkness.new()
		_darkness.visible = false
		add_child(_darkness)
		# Added after the darkness, so spells light up the dark around them.
		_glow = Glow.new()
		_glow.source = _draw_glow
		add_child(_glow)
		_glow.visible = false
		_fog_memory = FogMemory.new()
		_fog_memory.visible = false
		add_child(_fog_memory)
	for texture: Texture2D in _crypt_sprites.prepare():
		_flash_textures[texture] = _silhouette(texture)
		_crypt_bounds[texture] = texture.get_image().get_used_rect()
	for name: String in HERO_SPRITES+ENEMY_SPRITES.values():
		var entry := {"idle":[],"run":[],"hit":null}
		for state: String in ["idle","run"]:
			for frame in range(4):
				var texture: Texture2D = load("%s%s_%s_anim_f%d.png" % [SPRITE_ROOT,name,state,frame])
				entry[state].append(texture)
				_flash_textures[texture] = _silhouette(texture)
		var hit_path := "%s%s_hit_anim_f0.png" % [SPRITE_ROOT,name]
		if ResourceLoader.exists(hit_path):
			entry.hit = load(hit_path)
			_flash_textures[entry.hit] = _silhouette(entry.hit)
		_sprites[name] = entry
	_sheet_art.prepare(_flash_textures,_silhouette)
	for weapon_id: String in WEAPON_SPRITES:
		_weapon_textures[weapon_id] = load("%s%s.png" % [SPRITE_ROOT,WEAPON_SPRITES[weapon_id]])
	if audio_enabled: set_audio_enabled(true)
	if style_profile != null and not style_profile.changed.is_connected(_invalidate_presentation):
		style_profile.changed.connect(_invalidate_presentation)
	if _snapshot.is_empty(): _prepare_presentation({})


## Displays authoritative coordinates on the896×480 room with a32-pixel grid.
func set_state(snapshot: Dictionary, local_peer: int) -> void:
	_local_peer = local_peer
	_pending_snapshot = snapshot
	var key := _state_room_key(snapshot)
	var sequence := "%s:%s:%s" % [key,snapshot.get("seq",-1),snapshot.get("local_visual_tick",-1)]
	if not snapshot.has("seq") or sequence != _observed_sequence:
		_feedback.observe(snapshot,local_peer)
		_talent_feel(snapshot,local_peer)
		_actor_motion.observe(snapshot)
		if _rigs != null: _rigs.observe(snapshot)
		_observed_sequence = sequence
	if key != _layout_key or _feedback.hitstop <= 0 or snapshot.is_empty(): _accept_state(snapshot)
	queue_redraw()


func _state_room_key(snapshot: Dictionary) -> String:
	var layout: Dictionary = snapshot.get("room_layout",{})
	return "%s:%s:%s:%s" % [snapshot.get("run_seed",0),snapshot.get("floor_index",0),layout.get("id",""),snapshot.get("room_layout_revision",0)]


func _accept_state(snapshot: Dictionary) -> void:
	_pending_snapshot = {}
	var key := _state_room_key(snapshot)
	var visual := "%s:%s:%s" % [key,snapshot.get("seq",-1),snapshot.get("local_visual_tick",-1)]
	if snapshot.has("seq") and visual == _accepted_visual: return
	_snapshot = snapshot
	_accepted_visual = visual
	# Authoring snapshots have no sequence and may edit the same room in place.
	if key != _layout_key or not snapshot.has("seq"):
		_layout_key = key
		_prepare_presentation(snapshot)


func _invalidate_presentation() -> void:
	_prepare_presentation(_snapshot)
	queue_redraw()


## Static tile classification/baking belongs to a room change, never a redraw.
func _prepare_presentation(snapshot: Dictionary) -> void:
	_presentation_layout = snapshot.get("room_layout",{}).duplicate()
	if not _presentation_layout.has("art_style") and style_profile != null and style_profile.has_method("as_dictionary"):
		_presentation_layout.art_style = style_profile.as_dictionary()
	var layout := _presentation_layout
	var freeform: bool = layout.get("layout_mode","") == "freeform"
	var empty_layout: bool = snapshot.get("room_layout",{}).is_empty()
	_classic_enabled = layout.get("render_style","classic_quiet" if empty_layout else "") == "classic_quiet"
	_decoration_enabled = bool(layout.get("decoration_enabled",true))
	_base_cells = []
	_room_entries = []
	_fire_entries = []
	if _classic_enabled:
		var prepared := _classic.prepare(layout,int(snapshot.get("seed",0)))
		_room_entries.assign(prepared.wall_rows)
	else:
		for cell: Dictionary in layout.get("painted_tiles",[]):
			if not freeform or cell.get("layer","structure" if cell.get("solid",false) else "floor") == "floor": _base_cells.append(cell)
			elif freeform: _room_entries.append({"kind":"authored_tile","y":(float(cell.y)+1)*32,"cell":cell})
		if freeform and layout.has("entrance_marker"):
			_room_entries.append({"kind":"authored_tile","y":(float(layout.entrance_marker.y)+1)*32,"cell":layout.entrance_marker})
	if freeform or _classic_enabled:
		for exit: Dictionary in layout.get("exits",[]):
			_room_entries.append({"kind":"authored_exit","y":float(exit.rect[1])+float(exit.rect[3]),"exit":exit})
	if not freeform:
		for value: Variant in layout.get("visual_obstacles",layout.get("obstacles",[])):
			if value in layout.get("tile_obstacles",[]): continue
			if value is Array and value.size() == 4:
				var footprint := Rect2(float(value[0]),float(value[1]),float(value[2]),float(value[3]))
				_room_entries.append({"kind":"pillar","y":footprint.end.y,"rect":footprint})
	var offsets := [0.0,1.8,2.5,0.8]
	var fire_points: Array = layout.get("brazier_spawns",[] if freeform else [Vector2(72,78),Vector2(824,78),Vector2(72,402),Vector2(824,402)])
	for index in range(fire_points.size()):
		_fire_entries.append({"kind":"brazier","y":float(fire_points[index].y)+16,"point":fire_points[index],"offset":offsets[index%offsets.size()]})
	# Live crypt rooms in the approved 0x72 look: one baked image replaces the
	# classic floor, wall rows and braziers (candle columns stand there instead).
	_crypt72 = null
	_room_torches.clear()
	if crypt_0x72_enabled and bool(layout.get("crypt_profile",false)) and not empty_layout and not Engine.is_editor_hint():
		_crypt72 = Crypt72.new()
		_crypt72.bake(layout,hash(str(layout.get("id","")))^int(snapshot.get("run_seed",0)))
		# Void flames: torches, candle columns and floor fires in the 0x72 violet ramp.
		if bool(atmosphere.get("enabled",false)) and bool(atmosphere.flames.enabled):
			_crypt72.use_flame_colors(atmosphere.flames.recolor,bool(atmosphere.flames.floor_fires))
		_room_torches = _crypt72.light_points()
		_room_entries.clear()
		_fire_entries.clear()

## Microseconds spent in the view's process, draw and glow passes, and frames
## counted (a measure for scripts/bench_vfx.gd; it resets them).
var frame_stats := {"process": 0, "draw": 0, "glow": 0, "frames": 0}


## When the section being timed began (usec, _sec).
var _sec_t := 0


## Adds the time since _sec_t to frame_stats[`name`] (a measure for the benches).
func _sec(name: String) -> void:
	frame_stats[name] = int(frame_stats.get(name, 0)) + Time.get_ticks_usec() - _sec_t


func _process(delta: float) -> void:
	var started := Time.get_ticks_usec()
	_process_view(delta)
	frame_stats.process = int(frame_stats.process) + Time.get_ticks_usec() - started
	frame_stats.frames = int(frame_stats.frames) + 1


func _process_view(delta: float) -> void:
	# The music follows the moment even while menus hide the view.
	if _music != null: _music.request(Music.decide(_snapshot, is_visible_in_tree() and music_in_run))
	if not is_visible_in_tree(): return
	if _environment_animation_enabled: _environment_clock += delta
	if not _animation_enabled:
		queue_redraw()
		if _room_layer != null: _room_layer.queue_redraw()
		return
	if _feedback.hitstop <= 0:
		_clock += delta
		_actor_motion.advance(delta)
		if _rigs != null: _rigs.step(delta)
	_sec_t = Time.get_ticks_usec()
	_feedback.update(delta)
	_sec("particles")
	_sec_t = Time.get_ticks_usec()
	_fx.update(delta)
	_sec("sprites")
	_sec_t = Time.get_ticks_usec()
	if _gas != null and _feedback.hitstop <= 0: _gas.step(delta, _clock)
	_step_vision(delta)
	_sec("gas")
	if _feedback.hitstop <= 0 and not _pending_snapshot.is_empty(): _accept_state(_pending_snapshot)
	_update_darkness()
	_update_fog()
	_update_atmosphere()
	if _glow != null:
		_glow.visible = _glow.enabled and _darkness != null and _darkness.visible
		if _glow.visible: _glow.queue_redraw()
	var strength := roundf(_feedback.shake*_feedback.shake*9.0*shake_scale)
	position = _base_position+Vector2(_shake_rng.randf_range(-1,1),_shake_rng.randf_range(-1,1)).round()*strength
	queue_redraw()

func _draw() -> void:
	var started := Time.get_ticks_usec()
	_draw_view()
	frame_stats.draw = int(frame_stats.draw) + Time.get_ticks_usec() - started


func _draw_view() -> void:
	var ambient_time := _environment_clock if _environment_animation_enabled else _clock
	var render_snapshot := _snapshot.duplicate()
	render_snapshot.ambience_clock = ambient_time
	var layout: Dictionary = _presentation_layout
	render_snapshot.room_layout = layout
	var layers: Dictionary = _snapshot.get("presentation_layers", {})
	var freeform: bool = layout.get("layout_mode","") == "freeform"
	var room_visible: bool = layers.get("room", true)
	var actors_visible: bool = layers.get("actors", true)
	var props_visible: bool = layers.get("props", true)
	_effects_visible = layers.get("effects", true)
	if room_visible and _crypt72 != null:
		# Live runs draw the 0x72 room on the room layer (behind this node).
		if _room_layer == null: _draw_crypt_room(self)
	elif room_visible:
		if _classic_enabled and _snapshot.has("editor_background"):
			var dimensions: Array = layout.get("world_size",[896,480])
			draw_rect(Rect2(0,0,float(dimensions[0]),float(dimensions[1])),_snapshot.editor_background)
		elif _classic_enabled: _classic.draw_background(self,layout)
		else: Tiles.draw_room(self,render_snapshot)
	if room_visible and _crypt72 == null:
		if _classic_enabled: _classic.draw_floor(self)
		else:
			Palette.draw(self,_base_cells,1.0,Vector2.ZERO,1.0,ambient_time)
			if layout.get("crypt_profile",false): CryptArt.draw_floor_shadows(self,layout)
	if _effects_visible:
		if _fx_layout_key != _layout_key:
			_fx_layout_key = _layout_key
			_fx.set_layout(layout)
			# talent sheets are cut at this room's walls too (src/vfx/fx_sprites.gd clip)
			_talent_fx.sprites.set_layout(layout)
			_attack_fx.reset()
		# Particles bounce off this room's walls and settle on its floor.
		if _feedback.particles.layout_key != _layout_key:
			_feedback.particles.set_layout(layout, _layout_key)
			# pools are shaped by this room's walls (src/vfx/pool_paint.gd, 2 px art pixel)
			# one layer for the room: the same liquid from boss moves, skills and
			# talents is one pool; its drops fly in the feedback's particles and
			# blasts ring it (src/vfx/pool_paint.gd, src/vfx/particles.gd)
			var pools := PoolPaint.new(2.0, func(point: Vector2) -> bool: return not _feedback.particles.solid(point))
			pools.particles = _feedback.particles
			# the room's gas: clouds of puffs that spread, flow and are blown away (src/vfx/gas.gd)
			_gas = Gas.new(2.0, func(point: Vector2) -> bool: return not _feedback.particles.solid(point))
			_feedback.particles.set_liquids([[pools, 1.0], [_gas, 1.0]])
			_boss_fx.gas = _gas
			_boss_fx.particles = _feedback.particles
			_skill_fx.gas = _gas
			_talent_fx.gas = _gas
			_boss_fx.pools = pools
			_skill_fx.pools = pools
			_talent_fx.pools = pools
			_talent_fx.particles = _feedback.particles
		_skill_fx.particles = _feedback.particles
		_attack_fx.particles = _feedback.particles
		_attack_fx.fx = _fx
		_attack_fx.observe(_snapshot,_clock)
		_sec_t = Time.get_ticks_usec()
		_feedback.particles.draw_stains(self)
		_sec("stains")
		_sec_t = Time.get_ticks_usec()
		_skill_fx.draw_ground(self,_snapshot,_clock)
		_sec("skill.ground+pools")
		# warnings and pools stop at the walls like the pools' liquid (src/vfx/pixel_paint.gd clip)
		PixelPaint.clip = _open_floor
		_sec_t = Time.get_ticks_usec()
		_boss_fx.draw_ground(self,_snapshot,_clock)
		_sec("boss+pools")
		PixelPaint.clip = Callable()
		_sheet_art.draw_hazards(self,_snapshot.get("hazards",[]),false,_clock)
		PixelPaint.clip = _open_floor
		_sec_t = Time.get_ticks_usec()
		_talent_fx.draw_ground(self,_snapshot.get("talents",{}),_clock)
		_sec("talent.ground")
		PixelPaint.clip = Callable()
		_wade_pools()
		# the gas lies over the floor, under the actors (they stay readable over it)
		PixelPaint.clip = _open_floor
		_sec_t = Time.get_ticks_usec()
		if _gas != null: _gas.draw(self, _clock)
		_sec("gas")
		PixelPaint.clip = Callable()
	_sec_t = Time.get_ticks_usec()
	if actors_visible: _talent_fx.draw_pets(self,_snapshot.get("talents",{}),_clock)
	_sec("talent.pets")
	var rigs_on: bool = _rigs != null and _rigs.is_ready()
	_sec_t = Time.get_ticks_usec()
	if rigs_on and actors_visible: _rigs.draw_under(self)
	_sec("rigs")
	var enemies: Array = _snapshot.get("enemies", [])
	var players: Dictionary = _snapshot.get("players", {})
	var depth_entries: Array[Dictionary] = []
	if props_visible: depth_entries.append_array(_fire_entries)
	if room_visible: depth_entries.append_array(_room_entries)
	for enemy_value: Variant in enemies:
		if not actors_visible: continue
		# Rigged figures draw their own shadow under their feet.
		if float(enemy_value.get("dying_p",-1)) < 1.0 and not (rigs_on and enemy_value.has("rig")): _draw_shadow(_position(enemy_value), 24.0 if bool(enemy_value.get("boss", false)) else 14.0)
		depth_entries.append({"kind":"enemy","y":_position(enemy_value).y,"data":enemy_value})
	for peer_key: Variant in players:
		if not actors_visible: continue
		var player: Dictionary = players[peer_key]
		_draw_shadow(_position(player), 14.0)
		depth_entries.append({"kind":"player","y":_position(player).y,"data":player,"peer":int(peer_key)})
	# Breakable chests and dropped loot stand on the floor like actors.
	var loot_state: Dictionary = _snapshot.get("loot_chests", {})
	for chest: Dictionary in loot_state.get("chests", []):
		if props_visible: depth_entries.append({"kind":"chest","y":float(chest.y)+10.0,"data":chest})
	for item: Dictionary in loot_state.get("loot", []):
		if props_visible: depth_entries.append({"kind":"loot","y":float(item.y),"data":item})
	var local_hero: Dictionary = players.get(_local_peer, {})
	_skill_fx.local_class = str(local_hero.get("class_id",""))
	_skill_fx.local_point = Vector2(float(local_hero.get("x",0)),float(local_hero.get("y",0))) if not local_hero.is_empty() else Vector2.INF
	# Only the find closest to the local hero shows its name, so labels never pile up.
	_skill_fx.nearest_loot = -1
	var nearest_distance := 90.0
	for item: Dictionary in loot_state.get("loot", []):
		var distance := _skill_fx.local_point.distance_to(Vector2(float(item.x),float(item.y))) if _skill_fx.local_point.is_finite() else INF
		if distance < nearest_distance:
			nearest_distance = distance
			_skill_fx.nearest_loot = int(item.id)
	for bullet_value: Variant in _snapshot.get("bullets", []):
		if not _effects_visible: continue
		depth_entries.append({"kind":"bullet","y":_position(bullet_value).y,"data":bullet_value})
	if props_visible and _decoration_enabled and (not freeform or layout.has("reward_spawn")) and (str(_snapshot.get("phase", "")) == "reward" or bool(_snapshot.get("reference_reward", false))):
		depth_entries.append({"kind":"reward","y":float(layout.get("reward_spawn",Vector2(448,240)).y)})
	# Wall feet determine visual depth. A player behind a raised block is partly
	# hidden; a player in front draws over its face. No simulation positions move.
	depth_entries.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return float(a.y)<float(b.y))
	for entry: Dictionary in depth_entries:
		match entry.kind:
			"brazier": _draw_brazier(entry.point,entry.offset)
			"classic_wall_row": _classic.draw_wall_row(self,entry)
			"authored_tile": Palette.draw(self,[entry.cell],1.0,Vector2.ZERO,1.0,ambient_time)
			"authored_exit":
				if _classic_enabled: _classic.draw_exit(self,layout,entry.exit,_snapshot)
				else: Tiles.draw_authored_exit(self,layout,entry.exit,_snapshot)
			"pillar":
				if _classic_enabled: _classic.draw_obstacle(self,layout,entry.rect)
				else: Tiles.draw_obstacle(self,layout,entry.rect)
			"enemy": _draw_enemy(entry.data)
			"player": _draw_player(entry.data,entry.peer)
			"bullet": _draw_bullet(entry.data)
			"chest": _skill_fx.draw_chest(self,entry.data,_clock)
			"loot": _skill_fx.draw_loot(self,entry.data,_clock)
			"reward": _draw_pedestal()
	if room_visible and not _classic_enabled: Tiles.draw_foreground(self,render_snapshot)
	_sec_t = Time.get_ticks_usec()
	if rigs_on and actors_visible and _effects_visible: _rigs.draw_over(self,_snapshot)
	_sec("rigs")
	if _slices != null and actors_visible: _slices.draw(self,_clock)
	# Footsteps land exactly when a hero rig's foot touches down.
	_feedback.rig_footsteps = rigs_on
	if rigs_on:
		for key: String in _rigs.footfalls:
			if audio_enabled and _sfx != null: _sfx.play("step" if key == "p%d" % _local_peer else "step_ally", 0.05)
		_rigs.footfalls.clear()
	if _effects_visible:
		_draw_perk_events()
		_sec_t = Time.get_ticks_usec()
		_skill_fx.draw_over(self,_snapshot,_clock)
		_sec("skill.over")
		_sec_t = Time.get_ticks_usec()
		_boss_fx.draw_over(self,_snapshot,_clock,_position)
		_sec("boss+pools")
		_sheet_art.draw_hazards(self,_snapshot.get("hazards",[]),true,_clock)
		# talent effects and what lasts on the heroes stop at the walls (src/vfx/talent_fx.gd)
		PixelPaint.clip = _open_floor
		_sec_t = Time.get_ticks_usec()
		_talent_fx.draw_events(self,_snapshot.get("talents",{}),_clock)
		_sec("talent.events")
		_sec_t = Time.get_ticks_usec()
		_talent_fx.draw_auras(self,_snapshot.get("talents",{}),_clock,_talent_where)
		_sec("talent.auras")
		PixelPaint.clip = Callable()
		PixelPaint.clip = _open_floor
		_attack_fx.draw_flashes(self,_clock)
		PixelPaint.clip = Callable()
		_sec_t = Time.get_ticks_usec()
		_feedback.particles.draw_particles(self)
		_sec("particles")
		_sec_t = Time.get_ticks_usec()
		_fx.draw(self)
		_sec("sprites")
		if not freeform and not _classic_enabled: _draw_motes()


## Dark crypt: every living player carries a light circle; braziers, torches,
## magic shots and void effects light the dark too. Hidden outside live runs.
func _update_darkness() -> void:
	if _darkness == null: return
	var closed := float(_vision.k)
	var on: bool = (darkness_enabled and not _snapshot.is_empty() and bool(lighting.get("enabled", true))) or closed > 0.0
	_darkness.visible = on
	if not on: return
	var void_crypt := _atmosphere_on()
	var look: Dictionary = CryptAtmosphere.lighting_with_darkness(lighting, atmosphere) if void_crypt else lighting
	if closed > 0.0:
		# inside gas (element_rules.json vision): the world outside the cloud goes dark; the hero
		# keeps the cloud round him and the lights inside it (set below), nothing else
		look = look.duplicate()
		var base := float(look.get("darkness", 0.0)) if darkness_enabled else 0.0
		look.darkness = lerpf(base, float(ElementRules.vision().get("dark", 0.94)), closed)
	_darkness.configure(look)
	var size: Array = _presentation_layout.get("world_size", [1280, 720])
	_darkness.set_world_size(Vector2(float(size[0]), float(size[1])))
	var lights: Array = []
	var flicker: float = 4.0 * sin(_clock * 9.0)
	# Void flames burn colder: their light reaches a little less far.
	var torch_reach: float = float(lighting.get("torch_radius", 120)) * (float(atmosphere.flames.light_radius_scale) if void_crypt and bool(atmosphere.flames.enabled) else 1.0)
	for key: Variant in _snapshot.get("players", {}):
		var player: Dictionary = _snapshot.players[key]
		var point := _position(player)
		var reach := float(lighting.get("player_radius", 150)) * (1.0 if float(player.get("hp", 1)) > 0 else 0.45)
		# Blindness (potion) and the night curse shrink the hero's own light.
		if int(key) == _local_peer:
			if "blind" in Array(player.get("effects", [])): reach *= 0.3
			elif bool(player.get("inventory", {}).get("dim", false)): reach *= 0.6
		lights.append(Vector3(point.x, point.y - 8.0, reach))
	for entry: Dictionary in _fire_entries:
		var point: Vector2 = entry.point
		lights.append(Vector3(point.x, point.y - 12.0, float(lighting.get("torch_radius", 120)) + flicker))
	for torch: Vector2 in _room_torches:
		lights.append(Vector3(torch.x, torch.y, torch_reach * 0.8 + flicker))
	# Light shafts (decor): a bright, steady pool where the beam lands.
	if _crypt72 != null:
		for shaft: Vector2 in _crypt72.shafts: lights.append(Vector4(shaft.x, shaft.y - 20.0, float(lighting.get("shaft_radius", 150)), 1.0))
	# Spells light the dark around them: the Photoneneis, lava, magic bursts.
	lights.append_array(_skill_fx.lights(_snapshot))
	lights.append_array(_boss_fx.lights(_snapshot))
	lights.append_array(_fx.lights())
	if _rigs != null and _rigs.is_ready(): lights.append_array(_rigs.lights(_snapshot))
	# Heroes' arrows and spells light their path (src/vfx/attack_fx.gd).
	lights.append_array(_attack_fx.lights(_snapshot,_position))
	for bullet: Dictionary in _snapshot.get("bullets", []):
		var style := str(bullet.get("style", ""))
		if AttackFx.handles(bullet): continue
		if style in ["magic", "void_skull", "soul", "fireball", "fist"]:
			var point := _position(bullet)
			lights.append(Vector4(point.x, point.y, 84.0 if style == "fireball" else 46.0, 0.9 if style == "fireball" else 0.8))
	for exit: Dictionary in _presentation_layout.get("exits", []):
		var rect: Array = exit.get("rect", [])
		if rect.size() == 4: lights.append(Vector4(float(rect[0]) + float(rect[2]) * 0.5, float(rect[1]) + float(rect[3]) * 0.5, 56.0, 0.5))
	if closed > 0.0 and _snapshot.get("players", {}).has(_local_peer):
		# only what lies inside the cloud round the hero still shows (dimmer the more the view is closed)
		var me := _position(_snapshot.players[_local_peer])
		var keep := float(_vision.r)
		var seen: Array = [Vector4(me.x, me.y - 8.0, keep, 1.0)]
		for light: Variant in lights:
			var at := Vector2(light.x, light.y)
			var reach := float(light.z)
			if at.distance_to(me) + reach * 0.5 < keep:
				seen.append(Vector4(at.x, at.y, reach * (1.0 - 0.6 * closed), (float(light.w) if light is Vector4 else 1.0) * (1.0 - 0.5 * closed)))
		lights = seen
	_darkness.set_lights(lights)


## The view inside gas (src/combat/element_rules.gd vision): when the local hero
## stands in a cloud thick enough, the dark closes in round him to the cloud's
## reach (measured probe_hz times a second along eight rays) and opens again
## as he leaves; _update_darkness draws it.
func _step_vision(delta: float) -> void:
	var rules := ElementRules.vision()
	var goal := 0.0
	var mat := ""
	var me := Vector2.INF
	if _gas != null and _snapshot.get("players", {}).has(_local_peer):
		var hero: Dictionary = _snapshot.players[_local_peer]
		if float(hero.get("hp", 1)) > 0:
			me = _position(hero) + Vector2(0, 8)
			# the hero parts the gas round him (_wade_pools): what he stands in is the cloud at arm's length
			var cloud: Dictionary = _gas.around(me, 30.0)
			if float(cloud.d) >= ElementRules.dense_from():
				mat = str(cloud.mat)
				goal = float(ElementRules.gas(mat).get("vision", 0.0))
	var rate := delta / maxf(0.05, float(rules.get("fade_in", 0.35)) if goal > float(_vision.k) else float(rules.get("fade_out", 0.55)))
	_vision.k = move_toward(float(_vision.k), goal, rate)
	if goal <= 0.0:
		if float(_vision.k) <= 0.0: _vision.r = 0.0
		return
	_vision.probe = float(_vision.probe) - delta
	if float(_vision.probe) <= 0.0 and me != Vector2.INF:
		_vision.probe = 1.0 / maxf(1.0, float(rules.get("probe_hz", 8)))
		var lo := float(rules.get("min_radius", 70))
		var hi := float(rules.get("max_radius", 420))
		var reach: float = _gas.extent(me, mat, float(rules.get("thin", 0.12)), float(rules.get("step", 12)), hi)
		var want := clampf(reach + lo * 0.5, lo, hi)
		_vision.r = want if float(_vision.r) <= 0.0 else lerpf(float(_vision.r), want, 0.5)


## Fog of war on themed open floors: unseen areas black, explored ones dimmed,
## clear around every living hero (layout.floor_fog, src/vfx/fog_memory.gd).
func _update_fog() -> void:
	if _fog_memory == null: return
	var config: Dictionary = _presentation_layout.get("floor_fog",{})
	var on: bool = darkness_enabled and not config.is_empty() and not _snapshot.is_empty()
	_fog_memory.visible = on
	if not on: return
	var size: Array = _presentation_layout.get("world_size",[1280,720])
	_fog_memory.configure(_layout_key,Vector2(float(size[0]),float(size[1])),config)
	var lights: Array[Vector2] = []
	for key: Variant in _snapshot.get("players",{}):
		var player: Dictionary = _snapshot.players[key]
		if float(player.get("hp",1)) > 0: lights.append(_position(player))
	_fog_memory.reveal(lights)


## True while the void atmosphere shows: a live 0x72 crypt room in a run
## (the dark crypt is on) and vfx_crypt_atmosphere.json "enabled".
func _atmosphere_on() -> bool:
	return darkness_enabled and _crypt72 != null and not _snapshot.is_empty() and bool(atmosphere.get("enabled", false))


## Room filter and fog follow the atmosphere each frame; the room layer
## redraws with the view (torches and doors animate).
func _update_atmosphere() -> void:
	if _room_layer == null: return
	var on := _atmosphere_on()
	var grade_on: bool = on and bool(atmosphere.grade.enabled)
	_room_layer.material = _grade_material if grade_on else null
	_room_layer.queue_redraw()
	_fog.visible = on and bool(atmosphere.fog.enabled) and _effects_visible
	if _fog.visible:
		var size: Array = _presentation_layout.get("world_size", [1280, 720])
		_fog.set_world_size(Vector2(float(size[0]), float(size[1])))
		_fog.set_clock(_environment_clock if _environment_animation_enabled else _clock)


## The room layer's drawing: the baked 0x72 room with its animated props.
func _draw_room_layer(canvas: CanvasItem) -> void:
	if _crypt72 == null: return
	if not bool(_snapshot.get("presentation_layers", {}).get("room", true)): return
	_draw_crypt_room(canvas)


func _draw_crypt_room(canvas: CanvasItem) -> void:
	_crypt72.draw_room(canvas)
	_crypt72.draw_props(canvas, _environment_clock if _environment_animation_enabled else _clock, false)


## Bloom: everything bright adds soft light over the dark crypt (the glow
## node calls this each frame; vfx_glow.json scales each source).
func _draw_glow(canvas: CanvasItem) -> void:
	var started := Time.get_ticks_usec()
	_draw_glow_view(canvas)
	frame_stats.glow = int(frame_stats.glow) + Time.get_ticks_usec() - started


func _draw_glow_view(canvas: CanvasItem) -> void:
	if _snapshot.is_empty() or not _effects_visible: return
	var torches := _glow.level("torches")
	# Void flames glow in their own violet (vfx_crypt_atmosphere.json "flames").
	var flame_glow := Color(1.0, 0.62, 0.28, 0.2)
	if _atmosphere_on() and bool(atmosphere.flames.enabled): flame_glow = Color(atmosphere.flames.light_color, float(atmosphere.flames.glow_strength))
	for torch: Vector2 in _room_torches:
		Glow.dot(canvas, torch, 42.0 + 3.0 * sin(_clock * 9.0 + torch.x), Color(flame_glow, flame_glow.a * torches))
	for entry: Dictionary in _fire_entries:
		var point: Vector2 = entry.point
		Glow.dot(canvas, point + Vector2(0, -12), 50.0 + 3.0 * sin(_clock * 8.0 + float(entry.offset)), Color(1.0, 0.6, 0.25, 0.22 * torches))
	if _crypt72 != null:
		# Light shafts glow along the beam and bloom where they land.
		var ambient := _environment_clock if _environment_animation_enabled else _clock
		for index in range(_crypt72.shafts.size()):
			var foot: Vector2 = _crypt72.shafts[index]
			var top := foot + Vector2(7.0 * sin((ambient + float(index) * 1.7) * 0.6), -Crypt72.SHAFT_HEIGHT)
			Glow.line(canvas, top, foot, 46.0, Color(1.0, 0.9, 0.62, 0.1 * torches))
			Glow.dot(canvas, foot, 64.0, Color(1.0, 0.88, 0.6, 0.22 * torches))
	var bullets := _glow.level("bullets")
	for bullet: Dictionary in _snapshot.get("bullets", []):
		if not AttackFx.handles(bullet): _skill_fx.bullet_glow(canvas, bullet, _position(bullet), _clock, bullets)
	PixelPaint.clip = _open_floor
	_attack_fx.draw_glow(canvas, _snapshot, _position, _clock, bullets)
	PixelPaint.clip = Callable()
	_skill_fx.draw_glow(canvas, _snapshot, _clock, _glow)
	_fx.draw_glow(canvas, _glow.level("spells"))
	_talent_fx.draw_glow(canvas, _snapshot.get("talents", {}), _glow.level("spells"), _clock, _talent_where)
	# the warm light breathing over fire and lava pools (src/vfx/pool_paint.gd)
	if _boss_fx.pools != null: _boss_fx.pools.draw_glow(canvas, _glow.level("spells"), _clock)
	_feedback.particles.draw_glow(canvas, _glow.level("particles"))
	if _rigs != null and _rigs.is_ready():
		var void_level := _glow.level("void")
		for light: Vector3 in _rigs.lights(_snapshot):
			Glow.dot(canvas, Vector2(light.x, light.y), light.z * 0.75, Color(0.66, 0.4, 1.0, 0.26 * void_level))


## Freezes all presentation animation for reference comparisons and screenshots.
func set_animation_enabled(enabled: bool) -> void:
	if _animation_enabled == enabled: return
	_animation_enabled = enabled
	set_process(enabled or _environment_animation_enabled)
	if not enabled: position = _base_position
	queue_redraw()


## The authoring canvas can animate plants without moving actors or hit effects.
func set_environment_animation_enabled(enabled: bool) -> void:
	_environment_animation_enabled = enabled
	set_process(enabled or _animation_enabled)
	queue_redraw()


## Keeps the camera-shake origin independent of the transient visual offset.
## True on the room's floor (false inside walls): where effect pixels may show.
func _open_floor(point: Vector2) -> bool:
	return not _feedback.particles.solid(point)


func set_world_origin(origin: Vector2) -> void:
	_base_position = origin
	if not _animation_enabled or _feedback.shake <= 0: position = origin


## Enables sound only for an actual game. Editor and art previews remain silent.
func set_audio_enabled(enabled: bool) -> void:
	audio_enabled = enabled and not Engine.is_editor_hint()
	if audio_enabled and _sfx == null and is_inside_tree():
		_sfx = Sfx.new()
		add_child(_sfx)
	if audio_enabled and _music == null and is_inside_tree():
		_music = Music.new()
		add_child(_music)
	_feedback.sfx = _sfx if audio_enabled else null
	if not audio_enabled and _sfx != null: _sfx.stop_all()
	if not audio_enabled and _music != null: _music.stop_all()


## Transition audio is explicit, so a staircase never plays the doorway effect.
func play_transition_sound(kind: String) -> void:
	if audio_enabled and _sfx != null and kind in ["door","stairs"]: _sfx.play(kind,0.03)


## Menu and lobby buttons: "ui_click" or "ui_back". Silent previews stay silent.
func play_ui_sound(name: String) -> void:
	if audio_enabled and _sfx != null and name in ["ui_click","ui_back"]: _sfx.play(name,0.0)


## Drops previous-run particles, springs, flash, hitstop and shake immediately.
func reset_feedback() -> void:
	_feedback = Feedback.new()
	_fx.clear()
	_feedback.fx = _fx
	_actor_motion.reset()
	if _rigs != null: _rigs.reset()
	if _slices != null: _slices.reset()
	_feedback.sfx = _sfx if audio_enabled else null
	_clock = 0.0
	_observed_sequence = ""
	_accepted_visual = ""
	position = _base_position
	if _sfx != null: _sfx.stop_all()


## Original idle/run PNG frame, advanced at8FPS with deterministic actor phase.
func actor_frame(name: String, moving: bool, phase: int = 0) -> Texture2D:
	if not _sprites.has(name): return null
	return _frame(_sprites[name],moving,phase)


func _silhouette(texture: Texture2D) -> Texture2D:
	var image: Image = texture.get_image()
	image.convert(Image.FORMAT_RGBA8)
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var alpha: float = image.get_pixel(x, y).a
			if alpha > 0.0:
				image.set_pixel(x, y, Color(1, 1, 1, alpha))
	return ImageTexture.create_from_image(image)

func _box(x: float, y: float, width: float, height: float, color: Color) -> void:
	draw_rect(Rect2(floorf(x), floorf(y), width, height), color)

## Heroes and enemies in the room's liquid leave a wake, and wet steps out of
## it (src/vfx/pool_paint.gd wade); their feet are 12 px under their point.
func _wade_pools() -> void:
	var pools: RefCounted = _boss_fx.pools
	if pools == null: return
	var players: Dictionary = _snapshot.get("players", {})
	for id: Variant in players:
		var hero: Dictionary = players[id]
		pools.wade("p%s" % str(id), _position(hero) + Vector2(0, 12), bool(hero.get("moving", false)), _clock)
		if _gas != null: _gas.part(_position(hero) + Vector2(0, 8), 14.0)
	var enemies: Array = _snapshot.get("enemies", [])
	for index in range(mini(enemies.size(), 24)):
		var enemy: Dictionary = enemies[index]
		if float(enemy.get("dying_p", -1.0)) >= 0.0: continue
		pools.wade("e%s" % str(enemy.get("id", index)), _position(enemy) + Vector2(0, 12), bool(enemy.get("moving", false)), _clock)
		if _gas != null: _gas.part(_position(enemy) + Vector2(0, 8), 12.0)
	# shots cut lanes through the gas
	if _gas != null:
		for bullet: Dictionary in _snapshot.get("bullets", []):
			_gas.cut(_position(bullet), Vector2(float(bullet.get("vx", 0.0)), float(bullet.get("vy", 0.0))), 5.0)


## Where hero `owner` stands now (his auras follow him); INF when he is not here.
func _talent_where(owner: int) -> Vector2:
	var players: Dictionary = _snapshot.get("players", {})
	var hero: Dictionary = players.get(owner, players.get(str(owner), {}))
	return Vector2.INF if hero.is_empty() else _position(hero)


## The talents' weight on the view (src/vfx/talent_fx.gd take_feel, by
## importance): an ultimate shakes the view and holds the picture for its own
## hero; another hero's casts only shake it a little.
func _talent_feel(snapshot: Dictionary, local_peer: int) -> void:
	for hit: Dictionary in _talent_fx.take_feel(snapshot.get("talents", {})):
		var mine := int(hit.owner) == local_peer or int(hit.owner) < 0
		_feedback.shake = minf(1.0, _feedback.shake + float(hit.trauma) * (1.0 if mine else 0.35))
		if mine: _feedback.hitstop = maxf(_feedback.hitstop, float(hit.hitstop))


func _position(entity: Dictionary) -> Vector2:
	return Vector2(float(entity.get("x", 448.0)), float(entity.get("y", 240.0))).round()

func _draw_brazier(point: Vector2, offset: float) -> void:
	if UnifiedSkin.enabled() and UnifiedSkin.is_ready():
		var ambient_time := _environment_clock if _environment_animation_enabled else _clock
		var image := Living.texture("living_006",ambient_time if _effects_visible or _environment_animation_enabled else 0.0,offset)
		if image != null:
			var intensity := 0.06+0.012*sin(ambient_time*7+offset)
			_box(point.x-24,point.y-42,48,40,Color(0.20,0.72,0.70,intensity))
			draw_texture_rect(image,Rect2(point+Vector2(-32,-48),Vector2(64,64)),false)
			return
	var time := _clock + offset if _effects_visible else 0.0
	var flicker := sin(time * 7.0)
	var glow := Color(0.98,0.46,0.24,0.055+0.015*flicker)
	_box(point.x-36,point.y-36,72,72,glow)
	_box(point.x-24,point.y-24,48,48,glow)
	# The actual32px torch from the first committed Godot prototype. Only its
	# flame's light flickers; the lower holder keeps a fixed image and position.
	draw_texture_rect_region(ORIGINAL_TORCH,Rect2(point-Vector2(16,20),Vector2(32,16)),Rect2(0,0,32,16),Color(1.0+flicker*0.06,1,1))
	draw_texture_rect_region(ORIGINAL_TORCH,Rect2(point+Vector2(-16,-4),Vector2(32,16)),Rect2(0,16,32,16))
	if _effects_visible:
		_box(point.x+10,point.y-22-floorf(fmod(_clock*10.0+offset*4.0,14.0)),2,4,Color("edac68"))

func _draw_shadow(point: Vector2, half_width: float) -> void:
	_box(point.x-half_width,point.y+12,half_width*2,8,Color(0.05,0.04,0.09,0.55))
	_box(point.x-half_width+4,point.y+18,half_width*2-8,4,Color(0.05,0.04,0.09,0.25))

func _player_color(player: Dictionary, peer_id: int) -> Color:
	var fallback: Color = PLAYER_COLORS[absi(peer_id - 1) % PLAYER_COLORS.size()]
	var value: Variant = player.get("color", fallback)
	if value is Color:
		return value
	if value is String:
		return Color.from_string(value, fallback)
	if value is int:
		return PLAYER_COLORS[absi(int(value)) % PLAYER_COLORS.size()]
	return fallback

func _draw_player(player: Dictionary, peer_id: int) -> void:
	if CLASS_SPRITES.has(str(player.get("class_id",""))):
		_draw_class_hero(player, peer_id)
		return
	var point: Vector2 = _position(player).round()
	var color: Color = _player_color(player, peer_id)
	var hp: float = float(player.get("hp", 1))
	var role: String = str(player.get("skin",PLAYER_ACTORS[_sprite_index(color)]))
	var record: Dictionary = _actor_record(role,"p"+str(peer_id),player,true)
	if not record.is_empty():
		if peer_id == _local_peer and hp > 0: draw_rect(Rect2(point+Vector2(-20,8),Vector2(40,15)),Color(0.45,0.91,0.81,0.7),false,2)
		var pose: Dictionary = _feedback.pose("p%d"%peer_id,player,_clock,true)
		if hp > 0 and float(player.get("invulnerable",0)) > 0: pose.alpha *= 0.55 if fmod(_clock,0.16) < 0.08 else 1.0
		_draw_sprite(record.texture,point,1.0,float(record.feet),pose,float(record.scale),record.flash_texture,record.anchor)
		if show_player_health and hp > 0: _draw_health(point+Vector2(0,-44),hp,float(player.get("max_hp",hp)),32,color)
		return
	if hp <= 0:
		_box(point.x - 11, point.y + 2, 22, 9, INK)
		_box(point.x - 8, point.y + 3, 16, 5, color.darkened(0.6))
		_box(point.x - 4, point.y - 8, 8, 3, MUTED)
		_box(point.x - 1, point.y - 11, 3, 10, MUTED)
		return
	if peer_id == _local_peer:
		var ring_color := Color(0.45, 0.91, 0.81, 0.7)
		draw_rect(Rect2(point.x - 20, point.y + 8, 40, 15), ring_color, false, 2.0)
		_box(point.x - 4, point.y - 24, 8, 3, color)
		_box(point.x - 2, point.y - 21, 4, 3, color)
	# Optional aim vector; no input is sampled by the presentation layer.
	var aim := Vector2(float(player.get("ax", 1.0)), float(player.get("ay", 0.0)))
	if aim.length_squared() < 0.01:
		aim = Vector2.RIGHT
	aim = aim.normalized()
	# Heroes run while moving in any direction and face where they aim (Isaac-style);
	# while invulnerable they show the hit frame and blink.
	var hero: Dictionary = _sprites[HERO_SPRITES[_sprite_index(color)]]
	var hurt: bool = bool(player.get("hurt", false)) or float(player.get("invulnerable", 0.0)) > 0.0
	var texture: Texture2D = _frame(hero, bool(player.get("moving", false)), peer_id)
	var pose: Dictionary = _feedback.pose("p%d" % peer_id, player, _clock)
	if hurt:
		if hero.hit != null and fmod(_clock, 0.24) < 0.12: texture = hero.hit
		pose.alpha *= 0.45 if fmod(_clock, 0.16) < 0.08 else 1.0
	_draw_sprite(texture, point, -1.0 if aim.x < -0.1 else 1.0, 16.0, pose)
	if show_player_health: _draw_health(point + Vector2(0,-44),hp,float(player.get("max_hp",hp)),32.0,color)
	var hand: Vector2 = point + aim * 11.0 + Vector2(0, 3)
	draw_line(hand, hand + aim * 10.0, INK, 7.0)
	draw_line(hand, hand + aim * 10.0, Color("#c3b3ad"), 3.0)
	_box(hand.x - 3, hand.y - 3, 6, 6, Color("#e6b997"))
	if show_player_health and bool(player.get("ready", false)):
		_box(point.x + 15, point.y - 22, 8, 3, color)
		_box(point.x + 18, point.y - 25, 3, 9, color)

## Hero-class player (step 2, ported from main): the class's 0x72 figure at 2x,
## facing the aim, with the class weapon in hand. Every player keeps a ring in
## their own colour so identical classes stay distinguishable; the local
## player's ring is the brighter teal one.
func _draw_class_hero(player: Dictionary, peer_id: int) -> void:
	var point: Vector2 = _position(player).round()
	var color: Color = _player_color(player, peer_id)
	var hp: float = float(player.get("hp", 1))
	if hp <= 0:
		_box(point.x - 11, point.y + 2, 22, 9, INK)
		_box(point.x - 8, point.y + 3, 16, 5, color.darkened(0.6))
		_box(point.x - 4, point.y - 8, 8, 3, MUTED)
		_box(point.x - 1, point.y - 11, 3, 10, MUTED)
		return
	if peer_id == _local_peer:
		draw_rect(Rect2(point.x - 20, point.y + 8, 40, 15), Color(0.45, 0.91, 0.81, 0.7), false, 2.0)
	else:
		draw_rect(Rect2(point.x - 16, point.y + 10, 32, 10), Color(color, 0.6), false, 2.0)
	var aim := Vector2(float(player.get("ax", 1.0)), float(player.get("ay", 0.0)))
	if aim.length_squared() < 0.01: aim = Vector2.RIGHT
	aim = aim.normalized()
	var hero: Dictionary = _sprites[CLASS_SPRITES[str(player.class_id)]]
	var hurt: bool = float(player.get("invulnerable", 0.0)) > 0.0
	var face: float = _hero_look.face(player, aim, _clock)
	# Shared hero look (src/hero/hero_look.gd): lean into swings, dash afterimages.
	var look_key := "p%d" % peer_id
	_hero_look.observe(look_key, player, point, _clock)
	var rigged: bool = _rigs != null and _rigs.is_ready() and CLASS_RIGS.has(str(player.class_id))
	if rigged:
		_hero_look.draw_dash_lines(self, look_key, player, point, _clock)
		_hero_look.draw_afterimages(look_key, _clock, func(at: Vector2, alpha: float) -> void:
			_rigs.draw_hero(self, "ghost%d" % peer_id, player, at, CLASS_RIGS[str(player.class_id)], face, alpha))
	point += _hero_look.body_offset(look_key, player, aim, _clock)
	if rigged:
		# Part rig of the class figure: bob, walk, plume/hat sway, hit recoil.
		_rigs.draw_hero(self, look_key, player, point, CLASS_RIGS[str(player.class_id)], face, (0.45 if fmod(_clock, 0.16) < 0.08 else 1.0) if hurt else 1.0)
	else:
		var texture: Texture2D = _frame(hero, bool(player.get("moving", false)), peer_id)
		var pose: Dictionary = _feedback.pose("p%d" % peer_id, player, _clock)
		if hurt:
			if hero.hit != null and fmod(_clock, 0.24) < 0.12: texture = hero.hit
			pose.alpha *= 0.45 if fmod(_clock, 0.16) < 0.08 else 1.0
		_draw_sprite(texture, point, face, 16.0, pose)
	_draw_class_weapon(player, peer_id, point, aim)
	# the local mage's Irrwisch over him (src/hero/familiar.gd), on the crypt's 2 px art grid
	if peer_id == _local_peer: Familiar.draw_for("crypt:p%d" % peer_id, self, point + Vector2(0, 16.0), _clock, 2.0, player)
	if show_player_health: _draw_health(point + Vector2(0,-44), hp, float(player.get("max_hp", hp)), 32.0, color)


## The class weapon at the hero's hand, drawn by the shared hero look
## (src/hero/hero_look.gd): sword swings and Rage blades, the bow's draw, the staff.
func _draw_class_weapon(player: Dictionary, peer_id: int, point: Vector2, aim: Vector2) -> void:
	var weapons: Array = player.get("weapons", [])
	var weapon_id: String = str(weapons[0]) if not weapons.is_empty() else ""
	# Items carry their own sprite path (src/items/item_rules.gd).
	if not _weapon_textures.has(weapon_id) and weapon_id.begins_with("res://") and ResourceLoader.exists(weapon_id): _weapon_textures[weapon_id] = load(weapon_id)
	if not _weapon_textures.has(weapon_id): return
	var glow: Color = AttackFx.tint_for({"style": "arrow"}, player)
	_hero_look.draw_weapon(self, "p%d" % peer_id, player, point, aim, _clock, _weapon_textures[weapon_id], glow)


func _draw_health(point: Vector2, hp: float, maximum: float, width: float, color: Color) -> void:
	_box(point.x - width / 2.0 - 1, point.y - 1, width + 2, 4, INK)
	_box(point.x - width / 2.0, point.y, width, 2, Color("#493444"))
	_box(point.x - width / 2.0, point.y, floorf(width * clampf(hp / maxf(maximum, 1.0), 0.0, 1.0)), 2, color)

func _draw_stun(point: Vector2) -> void:
	for index in range(3):
		var offset := Vector2(index*8-8,floorf(sin(_clock*11.0+index*2.0))*2)
		draw_texture_rect_region(ItemArt.ANIMATIONS,Rect2(point+offset-Vector2(16,16),Vector2(32,32)),ItemArt.stun_frame(_clock+index*0.1))

func _sprite_index(color: Color) -> int:
	var best_index := 0
	var closest := INF
	for index: int in range(PLAYER_COLORS.size()):
		var candidate: Color = PLAYER_COLORS[index]
		var distance := absf(color.r - candidate.r) + absf(color.g - candidate.g) + absf(color.b - candidate.b)
		if distance < closest:
			closest = distance
			best_index = index
	return best_index

func _draw_enemy(enemy: Dictionary) -> void:
	var point: Vector2 = _position(enemy).round()
	var is_boss: bool = bool(enemy.get("boss", false))
	if enemy.has("rig") and _rigs != null and _rigs.is_ready():
		_draw_rig_enemy(enemy, point, is_boss)
		return
	if bool(enemy.get("sheet",false)) and _sheet_art.has_kind(str(enemy.get("kind",""))):
		_sheet_art.draw_enemy(self,enemy,_clock)
		return
	var kind: String = "boss" if is_boss else str(enemy.get("kind", "chaser"))
	var sprite: Dictionary = _sprites[ENEMY_SPRITES.get(kind, "goblin")]
	var id: int = int(enemy.get("id", 0))
	var dying: bool = float(enemy.get("dying_p", -1.0)) >= 0.0
	var texture: Texture2D = _frame(sprite, bool(enemy.get("moving", false)) and not dying, id * 3)
	var feet: float = 24.0 if is_boss else 16.0
	var pixel_scale: float = 2.0
	var top_crop: float = 0.0
	var record: Dictionary = _actor_record(kind,"e"+str(id),enemy,false)
	var crypt_texture: Texture2D = _crypt_sprites.frame(kind,enemy,_clock) if record.is_empty() else null
	if not record.is_empty():
		texture = record.texture
		pixel_scale = float(record.scale)
		feet = float(record.feet)
		top_crop = float(record.top_crop)
	elif crypt_texture != null:
		texture = crypt_texture
		pixel_scale = 1.0
		var bounds: Rect2i = _crypt_bounds[texture]
		feet += float(texture.get_height()-bounds.end.y)
		top_crop = float(bounds.position.y)
	if _effects_visible and not dying: _draw_enemy_telegraph(enemy,point)
	_draw_sprite(texture,point,1.0 if not record.is_empty() else float(enemy.get("face",-1.0)),feet,_feedback.pose("e%d"%id,enemy,_clock,not record.is_empty()),pixel_scale,record.get("flash_texture"),record.get("anchor",Vector2(-1,-1)))
	var statuses: Array = enemy.get("statuses",[])
	for index: int in range(statuses.size()):
		var tint: Color = Color("f7a34b") if statuses[index] == "burn" else Color("a8d568") if statuses[index] == "poison" else Color("8fd8e6")
		_box(point.x-12+index*8,point.y+feet+3,5,3,tint)
	var hp: float = float(enemy.get("hp", 1.0))
	var max_hp: float = maxf(float(enemy.get("max_hp", hp)), 1.0)
	if not dying and (hp < max_hp or is_boss):
		var bar_width: float = 48.0 if is_boss else 26.0
		var bar_y: float = point.y + feet - float(texture.get_height())*pixel_scale + top_crop - 8.0
		_box(point.x - bar_width / 2.0 - 2, bar_y - 2, bar_width + 4, 7, INK)
		_box(point.x - bar_width / 2.0, bar_y, bar_width, 3, Color("#5e354d"))
		_box(point.x - bar_width / 2.0, bar_y, floorf(bar_width * clampf(hp / max_hp, 0.0, 1.0)), 3, Color("#ef8a9a"))


## Part-rigged enemy (0x72 figures, Leerenrufer, Leerenbomber): the rig, its
## telegraph, statuses and the health bar above the figure's top. Bosses and
## mini-bosses get a wider bar with their name.
func _draw_rig_enemy(enemy: Dictionary, point: Vector2, is_boss: bool) -> void:
	var dying: bool = float(enemy.get("dying_p", -1.0)) >= 0.0
	# cut in two by Rage: the slice effect draws the halves instead
	if _slices != null and _slices.handles(enemy):
		_slices.observe(enemy, point, _clock)
		return
	if _effects_visible and not dying: _draw_enemy_telegraph(enemy, point)
	var top: float = _rigs.draw_enemy(self, enemy, point)
	if is_nan(top) or dying: return
	var statuses: Array = enemy.get("statuses", [])
	for index: int in range(statuses.size()):
		var tint: Color = Color("f7a34b") if statuses[index] == "burn" else Color("a8d568") if statuses[index] == "poison" else Color("8fd8e6")
		_box(point.x-12+index*8, top-14, 5, 3, tint)
	var hp: float = float(enemy.get("hp", 1.0))
	var max_hp: float = maxf(float(enemy.get("max_hp", hp)), 1.0)
	# Bosses and mini-bosses show their health in the run HUD's top bar instead.
	var big: bool = is_boss or bool(enemy.get("miniboss", false))
	if hp < max_hp and not big:
		var bar_width := 26.0
		var bar_y: float = top - 8.0
		_box(point.x - bar_width / 2.0 - 2, bar_y - 2, bar_width + 4, 7, INK)
		_box(point.x - bar_width / 2.0, bar_y, bar_width, 3, Color("#5e354d"))
		_box(point.x - bar_width / 2.0, bar_y, floorf(bar_width * clampf(hp / max_hp, 0.0, 1.0)), 3, Color("#ef8a9a"))


## Current idle or run frame; `phase` desynchronises actors that started together.

func _frame(sprite: Dictionary, moving: bool, phase: int) -> Texture2D:
	var frames: Array = sprite.run if moving else sprite.idle
	return frames[(int(_clock * FRAMES_PER_SECOND) + absi(phase)) % frames.size()]


## Draws a 0x72 frame at 2x, standing with its feet `feet` px below `point` and
## mirrored when `face` is negative (the source art faces right). `pose` comes
## from the feedback layer: squash & stretch and lean pivot on the feet, so
## deformation never lifts an actor off the floor; the flash is a white
## silhouette drawn over the frame in the flash colour.

func _draw_sprite(texture: Texture2D, point: Vector2, face: float, feet: float, pose: Dictionary, pixel_scale: float = 2.0, flash_texture: Texture2D = null, source_anchor: Vector2 = Vector2(-1,-1)) -> void:
	var size := Vector2(texture.get_width(), texture.get_height()) * pixel_scale
	var scale: Vector2 = pose.get("scale", Vector2.ONE)
	var alpha: float = float(pose.get("alpha", 1.0))
	var anchor: Vector2 = point + Vector2(0, feet) + Vector2(pose.get("offset", Vector2.ZERO))
	# Atlas padding is outside the anatomy: recoil must pivot at the real foot.
	if source_anchor.y >= 0: anchor.y -= (texture.get_height()-source_anchor.y)*pixel_scale
	draw_set_transform(anchor, float(pose.get("lean", 0.0)), Vector2((-1.0 if face < 0.0 else 1.0) * scale.x, scale.y))
	var rect := Rect2(Vector2(-source_anchor.x*pixel_scale if source_anchor.x >= 0 else -size.x*0.5,-source_anchor.y*pixel_scale if source_anchor.y >= 0 else -size.y),size)
	draw_texture_rect(texture, rect, false, Color(1, 1, 1, alpha))
	var flash: float = float(pose.get("flash", 0.0))
	var mask: Texture2D = flash_texture if flash_texture != null else _flash_textures.get(texture)
	if flash > 0.0 and mask != null:
		var color: Color = pose.get("flash_color", Color.WHITE)
		draw_texture_rect(mask, rect, false, Color(color, flash * alpha))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _actor_record(role: String, key: String, entity: Dictionary, player: bool) -> Dictionary:
	if not _actors_ready: return {}
	var motion: Dictionary = _actor_motion.select(key,entity,player)
	return _actor_bank.sample(role,str(motion.clip),str(motion.direction),float(motion.elapsed),bool(motion.loop))

func _draw_bullet(bullet: Dictionary) -> void:
	var point: Vector2 = _position(bullet).round()
	var owner: int = int(bullet.get("owner", 1))
	var style: String = str(bullet.get("style",""))
	# a talent's own shot first (src/vfx/talent_fx.gd TALENT_SHOTS)
	if owner > 0 and not str(bullet.get("talent","")).is_empty() and _talent_fx.draw_bullet(self,bullet,_clock): return
	if owner > 0 and _skill_fx.draw_bullet(self,bullet,_clock): return
	# talent shots: ice lance and arcane orb sheets (src/vfx/talent_fx.gd)
	if owner > 0:
		PixelPaint.clip = _open_floor
		var talent_shot: bool = _talent_fx.draw_bullet(self,bullet,_clock)
		PixelPaint.clip = Callable()
		if talent_shot: return
	# the mage's left-click: a small fireball (user wish 30.10.2026)
	if style == "magic" and str(bullet.get("talent","")).is_empty() and str(_snapshot.get("players", {}).get(owner, {}).get("class_id", "")) == "mage":
		_talent_fx.draw_basic_fireball(self, point, Vector2(float(bullet.get("vx", 1.0)), float(bullet.get("vy", 0.0))), _clock)
		return
	if AttackFx.handles(bullet):
		# a hero's streak, rune ring and motes never shine through a wall
		PixelPaint.clip = _open_floor
		if style == "arrow": _attack_fx.draw_arrow(self,bullet,_position(bullet),_clock)
		else: _attack_fx.draw_orb(self,bullet,_position(bullet),_clock)
		PixelPaint.clip = Callable()
		return
	if _sheet_art.draw_bullet(self,bullet,point,_clock): return
	if owner == 0 and _boss_fx.draw_bullet(self,bullet,point,_clock): return
	if owner == 0 and style == "arrow":
		var aim: Vector2 = Vector2(float(bullet.get("vx",1)),float(bullet.get("vy",0))).normalized()
		draw_line((point-aim*8).round(),(point+aim*7).round(),INK,4,false)
		draw_line((point-aim*7).round(),(point+aim*6).round(),Color("b89b73"),2,false)
		draw_line((point+aim*7).round(),(point+aim*2+aim.orthogonal()*3).round(),Color("eee0b9"),2,false)
		draw_line((point+aim*7).round(),(point+aim*2-aim.orthogonal()*3).round(),Color("eee0b9"),2,false)
		return
	if owner == 0 and style == "soul":
		_box(point.x-6,point.y-6,12,12,INK)
		_box(point.x-4,point.y-4,8,8,Color("6ca9a1"))
		_box(point.x-2,point.y-3,4,5,Color("c3d9ba"))
		return
	if owner == 0 and style == "void_skull":
		# Leerenrufer's soul skull: the void.json skull at 2x in a violet glow.
		var skull: Texture2D = _rigs.library.rig("void").get("skull") if _rigs != null and _rigs.is_ready() else null
		draw_circle(point,9.0+sin(_clock*20.0)*1.5,Color("c06bd8",0.3))
		if skull != null:
			var flip: float = -1.0 if float(bullet.get("vx",1)) < 0.0 else 1.0
			draw_set_transform(point,0.0,Vector2(2.0*flip,2.0))
			draw_texture(skull,-Vector2(skull.get_width(),skull.get_height())*0.5)
			draw_set_transform(Vector2.ZERO,0.0,Vector2.ONE)
		return
	if owner == 0 and style == "roar":
		# Mini-boss shockwave: pale bone orbs.
		_box(point.x-6,point.y-6,12,12,INK)
		_box(point.x-4,point.y-4,8,8,Color("a99d93"))
		_box(point.x-2,point.y-2,4,4,Color("efe6d6"))
		return
	var colors: Dictionary = {"cinder":Color("f7b46b"),"venom":Color("b8d878"),"frost":Color("9bdde6"),"storm":Color("baabe9")}
	var color: Color = colors.get(str(bullet.get("element","")),Color("#f3ce7d")) if owner > 0 else Color("#f19791")
	_box(point.x - 6, point.y - 6, 12, 12, Color(color, 0.12))
	_box(point.x - 4, point.y - 4, 8, 8, INK)
	_box(point.x - 3, point.y - 3, 6, 6, color)
	_box(point.x - 2, point.y - 2, 3, 3, Color("#fff6dc"))
	if bool(bullet.get("critical",false)): _box(point.x-1,point.y-7,2,2,Color("fff6dc"))


func _draw_enemy_telegraph(enemy: Dictionary, point: Vector2) -> void:
	if str(enemy.get("attack","")) != "windup": return
	var kind: String = str(enemy.get("attack_kind",""))
	var aim: Vector2 = Vector2(float(enemy.get("aim_x",1)),float(enemy.get("aim_y",0))).normalized()
	var target: Vector2 = Vector2(float(enemy.get("tx",point.x)),float(enemy.get("ty",point.y))).round()
	# Knockback can displace a charging caster; the shot keeps its locked direction.
	if kind in ["arrow","soul"]: target = (point+aim*point.distance_to(target)).round()
	var tint: Color = Color("e5c58a",0.55) if kind in ["arrow","slash","bite","slam"] else Color("c06bd8",0.7) if kind in ["fuse","salve"] else Color("87bcae",0.65)
	if kind == "fuse":
		# Leerenbomber: the burst radius (balance enemy_roster.attacks.fuse.radius) blinks.
		if fmod(_clock*8.0,1.0) < 0.6:
			for index: int in range(24):
				var offset: Vector2 = (Vector2.from_angle(index*TAU/24)*Vector2(72,40)).round()
				_box(point.x+offset.x-1,point.y+16+offset.y-1,3,3,tint)
		return
	if kind == "slam":
		for index: int in range(7):
			var end: Vector2 = point+aim.rotated((index-3)*0.32)*110
			_box(end.x-2,end.y-2,4,4,tint)
		return
	if kind == "summon":
		for index: int in range(8):
			var offset: Vector2 = (Vector2.from_angle(index*TAU/8)*18).round()
			_box(target.x+offset.x-2,target.y+offset.y-2,4,4,tint)
		_box(target.x-3,target.y-3,6,6,Color("a7c5a5"))
	elif kind == "arrow":
		draw_line(point+aim*18,target,tint,2,false)
		_box(target.x-2,target.y-2,4,4,tint)
	elif kind == "soul":
		_box(point.x-5,point.y-30,10,10,tint)
		_box(target.x-8,target.y-1,16,2,tint)
		_box(target.x-1,target.y-8,2,16,tint)
	elif kind == "slash":
		for turn: float in [-0.65,0.0,0.65]:
			var end: Vector2 = point+aim.rotated(turn)*40
			_box(end.x-2,end.y-2,4,4,tint)


## The perk markers (src/vfx/perk_marks.gd: a chain is lightning, a heal a
## cross of light lifting off, a blast/crit/shield a ring spreading out).
func _draw_perk_events() -> void:
	PerkMarks.draw(self, _snapshot.get("perk_events", []))

func _draw_pedestal() -> void:
	var center: Vector2 = _snapshot.get("room_layout",{}).get("reward_spawn",Vector2(448,240))
	var pulse := 0.08+0.03*sin(_clock*2.5)
	draw_rect(Rect2(center-Vector2(64,64),Vector2(128,128)),Color(0.95,0.75,0.35,pulse))
	_draw_shadow(center,18)
	draw_texture_rect_region(ItemArt.ITEMS,Rect2(center-Vector2(16,16),Vector2(32,32)),ItemArt.CHEST_OPEN_REGION)
	var options: Array = _snapshot.get("perk_options",[])
	for index in range(mini(3,options.size())):
		var bob := floorf(sin(_clock*2.6+index)*4.0)
		var point := center+Vector2((index-1)*36,-44+bob)
		draw_texture_rect(PerkIcons.texture(str(options[index].get("id","")),options[index]),Rect2(point-Vector2(16,16),Vector2(32,32)),false)

func _draw_motes() -> void:
	for index: int in range(12):
		var x: float = float(105 + (index * 157) % 680)
		var y: float = 75.0 + fmod(float(index * 59) - _clock * 7.0 + 720.0, 330.0)
		var alpha: float = 0.14 + 0.08 * sin(_clock * 1.5 + float(index))
		_box(x, y, 2, 2, Color(0.94, 0.76, 0.59, alpha))
