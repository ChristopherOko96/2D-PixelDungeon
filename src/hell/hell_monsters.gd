extends RefCounted
## Runtime of the hell monsters for hell_game.gd: spawning a floor's roster and
## boss, movement per AI, every attack kind with its floor warning, enemy shots,
## and Ignaroth's four phases (arrival by flight or from the floor, burrowing,
## flights in which he cannot be hit, breath sweeps, the echoes of his earlier
## forms, the change into his next form on floors 3, 6 and 9, and his death on 10).
## Monster data and sprite atlases come from tools/hell_dungeon/export_monsters.js.

const Rules = preload("res://src/hell/hell_monster_rules.gd")
const HeroKit = preload("res://src/hell/hero_kit.gd")
const FrostCombat = preload("res://src/hell/frost_combat.gd")
const StoryFeel = preload("res://src/hero/story_feel.gd")
const ElementRules = preload("res://src/combat/element_rules.gd")
const DATA_PATH := "res://assets/data/hell_monsters.json"
const SPRITE_DIR := "res://assets/sprites/hell/monsters/"
## Shot colours: core, middle, rim.
const SHOT_COL := {
	"fire": [Color8(255, 200, 200), Color8(230, 40, 30), Color8(120, 0, 0)],
	"void": [Color8(240, 200, 255), Color8(170, 70, 230), Color8(60, 10, 120)],
	"soul": [Color8(220, 255, 200), Color8(90, 200, 70), Color8(10, 70, 20)],
	"lava": [Color8(255, 240, 180), Color8(255, 140, 30), Color8(140, 40, 0)],
	"chain": [Color8(230, 240, 255), Color8(120, 150, 190), Color8(40, 50, 70)],
}
const LAVA_LOBBERS := ["kesselbrut", "glutwaechter"]
const PUDDLE_SLAMMERS := ["glutwaechter"]
## Pixel laser (an attack with "style": "laser", the Blutfledermaus): world px
## per laser pixel, the floor's and the figures' own art pixel (16 px art x3),
## so effects and world share one grid (art review,
## production/qa/evidence/hell-vfx-review); hot to cool palette, and the
## flicker rate of its ragged edge in frames a second.
const LASER_PX := 3.0
## Sizes counted in pixels were made for a 4 px pixel: this keeps them as big.
const PX_GROW := 4.0 / 3.0
## The dark outline round fire, lava and shots.
const OUTLINE := Color("1c1117")
## 4x4 ordered dither (fading without transparency).
const BAYER := [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]
const LASER_COL := [Color("fdf7ed"), Color("facb3e"), Color("da4e38"), Color("9f294e"), Color("5f2d56")]
const LASER_FPS := 12.0
## A void beam (a beam without "style": "laser") as a wide pixel laser of
## nothing: its core darker than the floor (light swallowed) with violet pulses
## running back up it, the light torn bright pink and white at its rim, its
## outer edge deep violet. Roles: pulse, core, rim, rim flicker, outer edge.
const VOID_BEAM_COL := [Color("c278d0"), Color("120a1c"), Color("f0b3dd"), Color("fdf7ed"), Color("4a2a6a")]
## A laser's wall burn: pixel fire hot to cool, and how long its embers glow
## on after the laser stops (s); the crypt's fire wall hit sparks there every
## SCORCH_SPARK s while it burns.
const SCORCH_COL := [Color("facb3e"), Color("ee8e2e"), Color("da4e38"), Color("9f294e")]
const SCORCH_GLOW := 1.6
const SCORCH_SPARK := 0.12
## The attacks' pixel look (shots, lobs, shockwaves, telegraphs, pools): per
## shot colour white-hot, hot, mid and edge, on the LASER_PX grid.
const PX_COL := {
	"fire": [Color("fdf7ed"), Color("facb3e"), Color("ee8e2e"), Color("da4e38")],
	"lava": [Color("facb3e"), Color("ee8e2e"), Color("da4e38"), Color("9f294e")],
	"void": [Color("fdf7ed"), Color("f0b3dd"), Color("c278d0"), Color("8156aa")],
	"soul": [Color("fdf7ed"), Color("cfe86b"), Color("97da3f"), Color("4ba747")],
	"chain": [Color("fdf7ed"), Color("b6cbcf"), Color("7b8994"), Color("414859")],
	"bone": [Color("fdf7ed"), Color("e8dcc8"), Color("c9b49a"), Color("8f7f70")],
	"poison": [Color("e8ff9a"), Color("a8e04a"), Color("6fae3a"), Color("3b6b2a")],
	"frost": [Color("ffffff"), Color("e6fbff"), Color("a6e3f7"), Color("6fbde8")],
	"gold": [Color("fdf7ed"), Color("ffe08a"), Color("facb3e"), Color("c08a2a")],
}
## A thrown boulder (an attack's "look": "boulder"): dark rock with a lava vein,
## turned a quarter at a time as it flies (a outline, b rock, c lit rock, d shade, l lava).
const BOULDER := [".aaaa..", "abbcca.", "abdlbca", "abllbba", "adbdbba", ".adbba.", "..aaa.."]
## How many points of its path a soul keeps for its gas tail (1.5 LASER_PX apart).
const WISP_TAIL := 12
## A soul's eyes.
const WISP_EYE := Color("1e3d24")
const BOULDER_COL := {"a": Color("1c1117"), "b": Color("4f343c"), "c": Color("8a5f52"), "d": Color("2e1e28"), "l": Color("ee8e2e")}
## Rock chunks of a smashed floor, then the hot sparks, for the bosses' slams.
const CHUNK_COL := [Color("4f343c"), Color("8a5f52"), Color("2e1e28")]
## Floor cracks of a slam glowing hot to cold, and how long they last (s).
const CRACK_COL := [Color("facb3e"), Color("ee8e2e"), Color("da4e38"), Color("5f2d56"), Color("1c1117")]
const CRACK_TIME := 2.6
## Cracks of a slam that is no fire (an element of the crypt): cold stone, no glow.
const CRACK_COLD := [Color("4a3e44"), Color("1c1117")]
## Lava running over a pool's rim, white-hot where it wells over to its cooling edge.
const SPILL_COL := [Color("ffe08a"), Color("facb3e"), Color("ee8e2e"), Color("b8401e")]
## Floor dust and grit a shockwave kicks up (it settles as rubble).
const WAVE_DUST := [Color("8a5f52"), Color("a8806a"), Color("6e4a4a"), Color("5a4656")]
## A shot's trail of glowing pixels: one every so many seconds.
const SHOT_TRAIL := 0.05
## A split floor's wall of flames: how long it burns (s), how high its flames rise (laser px).
const FIREWALL_TIME := 1.5
const FIREWALL_HIGH := 15.0
## Flakes of ash a burnt-out fire leaves drifting up.
const ASH_COL := [Color("5a5555"), Color("3a3535"), Color("7a7070")]
## A grave hand rising out of the floor, open then closed (o edge, b body, h light, w white knuckles), 7 x 9.
const HAND_OPEN := [".o.o.o.", "ohohoho", "ohohoho", "ohbhbho", "obbbbbo", "obbwbbo", ".obbbo.", ".obbbo.", "..obo.."]
const HAND_FIST := [".......", ".ooooo.", "ohwhwho", "obbbbbo", "obbbbbo", "obbbbbo", ".obbbo.", ".obbbo.", "..obo.."]
## Longest step of a knockback per frame (world px; well under a 96 px cell).
const KNOCK_STEP := 24.0
## The crypt's wall-hit style of an enemy shot by its colour (feedback.gd WALL_STYLES).
const SHOT_WALL := {"fire": "fire", "lava": "fire", "void": "void", "soul": "magic", "bone": "bone", "poison": "poison", "frost": "frost", "gold": "gold"}
## The crypt's elements (Story 1, krypta_monsters.json "shot"): a figure that
## names one shoots, lobs, breathes and slams in it, and what it leaves on the
## floor is its matter (bone splinters, poison drops, rime, gold glints). The
## hell's figures name none and keep Rules.shot_color and their fire.
const OWN_ELEMENTS := ["bone", "poison", "frost", "gold", "soul", "void"]
## The elements only the crypt has: their bursts, warnings and cracks are their own
## (_burst_in, _warn_col); void and soul look as in the hell.
const CRYPT_ELEMENTS := ["bone", "poison", "frost", "gold"]
## The elements that pool as a liquid or a sheet (assets/data/vfx_pools.json "materials"):
## a hopper of one leaves a puddle of it where it lands, the others only their residue.
const POOL_ELEMENTS := ["poison", "frost", "void"]
## What the hero reads when a shot of an element hits him.
const HURT_BY := {"void": "von Leerenfeuer getroffen", "soul": "von Seelenfeuer getroffen", "bone": "von Knochen getroffen", "poison": "von Gift getroffen",
	"frost": "von Frost getroffen", "gold": "von Gold getroffen"}

var g: Node
var defs: Dictionary = {}
var floors: Dictionary = {}
var cfg: Dictionary = {}
var atlas: Dictionary = {}
var zones: Array = []
var lobs: Array = []
var corpses: Array = []
## The pixel lasers' wall burns ({p, t, fire, T, seed, embers}, _scorch).
var scorches: Array = []
## Pixel chunks and sparks flying with gravity ({p, v, z, vz, t, T, c, s}, _pixel_burst).
var pfx: Array = []
## Glowing floor cracks of slams and boulders ({p, t, T, cells}, _crack_floor).
var cracks: Array = []
## White-hot pixel flashes at attack impacts ({p, t, T, r}, _impact).
var flashes: Array = []
## Walls of pixel flames out of a split floor ({p, dir, len, t, T, seed, ashed}, _fissure).
var firewalls: Array = []
## Tongues of lava sloshing over a pool's rim ({p, dir, len, w, t, T, crusted}, lava_splash).
var spills: Array = []
## Ignaroth's part rig (src/hell/drake_rig_host.gd), set by hell_game.gd; null keeps the atlas sprites.
var rig_host: RefCounted = null


## game: the hell game node; cfg: the "monsters" block of the world's balance file. A world with
## its own monster set names its data file and atlas folder there ("data", "sprites"; e.g. the
## crypt in assets/data/krypta_balance.json); without them the hell monsters load.
func _init(game: Node, monster_cfg: Dictionary) -> void:
	g = game
	cfg = monster_cfg
	var sprite_dir := str(cfg.get("sprites", SPRITE_DIR))
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(str(cfg.get("data", DATA_PATH))))
	defs = data.defs
	floors = data.floors
	# monsters a world borrows from another set without putting them in its floors' rosters
	# (cfg.borrow: data file, atlas folder, ids; e.g. the hell's mimic chests wake as the crypt's
	# mimic, drawn from a hell-coloured atlas)
	var borrow: Dictionary = cfg.get("borrow", {})
	var borrowed: Array = borrow.get("ids", [])
	if not borrowed.is_empty():
		var more: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(str(borrow.data)))
		for id: String in borrowed:
			defs[id] = more.defs[id]
	# experience per kill for the hero's levels (hero_kit.gd reads def.exp)
	var exp: Dictionary = cfg.get("exp", {})
	for id: String in defs:
		defs[id].exp = int(exp.get(id, 0))
	for id: String in defs:
		atlas[id] = load((str(borrow.sprites) if id in borrowed else sprite_dir) + id + ".png")


## Drops every attack effect (death, pit, new floor).
func reset() -> void:
	zones = []
	lobs = []
	corpses = []
	scorches = []
	pfx = []
	cracks = []
	flashes = []
	firewalls = []
	spills = []


## Monster id of the boss on floor n.
func boss_id(n: int) -> String:
	return String(floors[str(n)].boss)


## True while the monster cannot be hit.
func immune(m: Dictionary) -> bool:
	return Rules.is_immune(m, float(cfg.immune_altitude))


## Health-bar text for a boss: its name and what it is doing.
func boss_label(m: Dictionary) -> String:
	return String(m.def.name) + Rules.boss_status(m, float(cfg.immune_altitude))


# ---------- spawning ----------

## How high above its feet a monster's body centre sits (world px): where hero
## shots hit it and its shots and bursts start. The def's measured hit_cy (art
## px; the crypt's figures, tools/krypta_dungeon/export_monsters.js) when it has
## one, else 0.45 of its frame height.
static func hit_cy(def: Dictionary) -> float:
	if def.has("hit_cy"):
		return float(def.hit_cy) * float(def.scale)
	return float(def.h) * float(def.scale) * 0.45


## Adds monster id at pos to room; a boss takes the floor's boss HP.
func spawn(room: int, pos: Vector2, id: String, boss := false) -> Dictionary:
	var def: Dictionary = defs[id]
	var st: Dictionary = def.stats
	var hp: float = Rules.spawn_hp(st, boss, float(g.W.boss.hp), float(g.W.diff.hp)) * (g.talents.hp_scale() if g.talents != null else 1.0)
	var cds: Array = []
	for a: Dictionary in st.attacks:
		cds.append(Rules.first_cooldown(a, randf()))
	var m := {"room": room, "id": id, "def": def, "st": st, "boss": boss, "kind": "boss" if boss else "mob", "p": pos,
		"hp": hp, "max": hp, "sp": float(st.speed) * (1.0 if boss else float(g.W.diff.speed)), "s": float(def.scale),
		"r": float(st.r), "cy": hit_cy(def), "seed": randf() * 9.0, "k": Vector2.ZERO,
		"hit": 0.0, "spawn": float(cfg.spawn_grow), "act": null, "anim": "idle", "at": 0.0, "face": 1.0, "alpha": 1.0,
		"hop_t": randf(), "cds": cds, "alt": 0.0, "sink": 0.0, "burrowed": false, "intro": null, "trans": null,
		"dying": null, "circ": 1.0, "landed": false, "trail": 0.0}
	# Ignaroth's part rig: the HP split over his form's parts, an int uid (src/hell/drake_rig_host.gd)
	if rig_host != null:
		rig_host.attach(m)
	g.mobs.append(m)
	return m


## A free floor spot of room between min_d and max_d from near; near itself if none is found.
func free_spot(room: int, near: Vector2, min_d: float, max_d: float) -> Vector2:
	for k in range(40):
		var p := near + Vector2.from_angle(randf() * TAU) * randf_range(min_d, max_d)
		if g._room_at_world(p.x, p.y) == room and g._cell(int(floor(p.x / g.C)), int(floor(p.y / g.C))) == 1 \
				and not g.box_blocked(Rect2(p.x - 30, p.y - 30, 60, 30), true):
			return p
	return near


## Fills a room whose fight starts: the floor's roster on the given free cells,
## and in the boss room the floor's boss (Ignaroth arrives with his intro).
func populate(r: Dictionary, cells: Array) -> void:
	var roster: Array = floors[str(g.state.floor)].mobs
	var first := randi() % roster.size()
	var count: int = int(r.mobs if r.mobs > 0 else 3) + int(g.W.diff.extra)
	# a world with dormant mimics (theme.dormant_mimics) never shows one as a monster: it waits as a chest
	var dormant: String = str(g.theme.get("mimic_kind", "")) if g.theme.get("dormant_mimics", false) else ""
	for k in range(mini(count, cells.size())):
		var id: String = roster[(first + k) % roster.size()]
		if id == dormant:
			g.place_dormant_mimic(r.index, cells[k])
		else:
			spawn(r.index, cells[k], id)
	if r.type != "boss":
		g._toast("Die Gitter fallen. Besiege alle Gegner.")
		return
	var b := spawn(r.index, Vector2((r.bx + r.bw / 2.0) * g.C, (r.by + r.bh / 2.0 + 1.0) * g.C), boss_id(g.state.floor), true)
	if Rules.is_lord(b.def):
		b.spawn = 0.0
		start_intro(b)
		g._toast("Ein Schatten über der Arena …" if b.st.get("intro", "") == "flyin" else "Der Boden glüht …")
	else:
		g._toast("%s erwacht. Die Tore sind verriegelt." % b.def.name)


# ---------- update ----------

func _me() -> Vector2:
	return Vector2(g.player.x, g.player.y)


## Hurts the hero by `m`; when the hit lands (he was not invulnerable), it
## pushes him away from `from` with the knock of kind `push`
## (hell_balance.json monsters.feel.knock; "" pushes nothing).
func _hurt_by(m: Dictionary, n: int, how: String, from := Vector2.INF, push := "") -> void:
	var open := float(g.state.inv) <= 0.0 and float(g.state.dead) <= 0.0
	g._hurt("von %s %s" % [m.def.name, how], n, from if from.is_finite() else Vector2(m.p))
	if open and push != "" and from.is_finite() and float(g.state.inv) > 0.0:
		_knock(from, push, m)


## Starts the hero's knockback away from `from` (game feel + physics tuning):
## a speed by kind from hell_balance.json monsters.feel.knock (a mob's a share
## lower), squashed on the floor's depth like everything in this view; it eases
## out over knock.time in update_shots and never carries him through a wall.
func _knock(from: Vector2, kind: String, m: Dictionary = {}) -> void:
	var knock: Dictionary = (cfg.get("feel", {}) as Dictionary).get("knock", {}) if cfg.get("feel") is Dictionary else {}
	var speed := float(knock.get(kind, 0.0))
	if speed <= 0.0:
		return
	if not m.is_empty() and not bool(m.get("boss", false)):
		speed *= float(knock.get("mob_scale", 0.7))
	var away := Vector2(g.player.x, g.player.y) - from
	if away.length() < 1.0:
		away = Vector2.RIGHT.rotated(randf() * TAU)
	g.state.knock = {"v": away.normalized() * Vector2(1.0, 0.75) * speed, "t": 0.0, "T": float(knock.get("time", 0.22))}


## Moves the hero along his knockback: its speed eases out (quadratically)
## over its time, axis by axis so a wall stops one axis and he slides along
## it; no step is longer than KNOCK_STEP, so nothing tunnels.
func _update_knock(dt: float) -> void:
	var K: Variant = g.state.get("knock")
	if not K is Dictionary:
		return
	K.t = float(K.t) + dt
	var k := float(K.t) / maxf(0.01, float(K.T))
	if k >= 1.0:
		g.state.knock = null
		return
	var mv: Vector2 = (K.v as Vector2) * pow(1.0 - k, 2.0) * dt
	if mv.length() > KNOCK_STEP:
		mv = mv.normalized() * KNOCK_STEP
	if not g.box_blocked(g._player_box(g.player.x + mv.x, g.player.y)):
		g.player.x += mv.x
	if not g.box_blocked(g._player_box(g.player.x, g.player.y + mv.y)):
		g.player.y += mv.y


func _shake(n: float) -> void:
	g.state.shake = maxf(float(g.state.get("shake", 0.0)), n)


func _shot(from: Vector2, dir: Vector2, speed: float, extra := {}) -> void:
	var s := {"p": from, "v": dir.normalized() * speed, "t": 2.6, "c": "fire"}
	s.merge(extra, true)
	g.eshots.append(s)


## Serial ids of the lava puddles (their pools on the floor).
var _pool_serial := 0


func _zone(z: Dictionary) -> void:
	var base := {"t": 0.0, "tele": 0.0, "dmg": 0, "done": false}
	base.merge(z, true)
	if base.kind == "puddle":
		_pool_serial += 1
		base.id = _pool_serial
	zones.append(base)


## The lava puddles as pools for the floor's physics pools (src/vfx/pool_paint.gd
## via hell_game.pools): each runs out from where it landed along its flight
## and piles up against walls and props.
func pool_entries() -> Array:
	var out: Array = []
	for z: Dictionary in zones:
		if z.kind != "puddle":
			continue
		var dir: Vector2 = z.get("dir", Vector2.ZERO)
		out.append({"id": int(z.id), "k": "pool", "st": str(z.get("st", "lava")), "x": z.p.x, "y": z.p.y, "r": float(z.r) * 0.8, "dx": dir.x, "dy": dir.y,
			"p": clampf(float(z.t) / maxf(0.01, float(z.T)), 0.0, 1.0), "L": float(z.T), "cr": float(z.get("crust", 0.0))})
	return out


## Sound hook: the running act of `m` releases its strike, shot, wave or summon
## now (src/hero/story_sound.gd fires its crypt attack sound).
func _released(m: Dictionary) -> void:
	if g.get("sound") != null:
		g.sound.released(m)
	# rig hook: the act is out now (the throat opens for the breath; a part lost later only stops the breath and beams)
	if rig_host != null:
		rig_host.on_release(m)


## The attacks a blinded monster (in steam or smoke) can still make: blows at arm's length.
const BLIND_ATTACKS := ["swing", "dash", "slam", "ring", "sweep"]


## The element tags of a monster (src/combat/element_rules.gd tags): the words
## of its id, its own shot element and material; a figure without a shot of
## its own is one of the hell's (fire and lava do nothing to it).
static func mob_tags(m: Dictionary) -> Array:
	var def: Dictionary = m.def
	if not m.has("tags"):
		m.tags = ElementRules.tags(str(m.id), str(def.get("shot", "")), str(def.get("material", "")), [] if def.has("shot") else ["hell", "fire", "lava"])
	return m.tags


## The element physics on a monster (src/combat/element_rules.gd,
## assets/data/element_rules.json): the pool it stands in hurts it on its tick
## (hero hits per second, unless it is of that element), burns, poisons or
## slows it, douses its burning (water), takes its footing (ice, blood: the
## movement in update slides it) or pulls it (void); a gas cloud thick enough
## does the same and blinds its shots (steam, smoke). m.env carries the rule
## the movement reads.
func _step_medium(m: Dictionary, dt: float) -> void:
	m.env = {}
	m.blind = maxf(0.0, float(m.get("blind", 0.0)) - dt)
	if m.hp <= 0.0 or m.get("burrowed", false) or float(m.get("alt", 0.0)) > 20.0:
		return
	var layer: RefCounted = g._pool_layer() if g.has_method("_pool_layer") else g.get("pools")
	var tags := mob_tags(m)
	if layer != null:
		var under: Array = layer.materials_at(m.p)
		if not under.is_empty():
			var style := ElementRules.top(under)
			var rule := ElementRules.medium(style)
			# a burning monster sets the poison it stands in off, whatever its own element
			if _combo(m, ElementRules.material(style)):
				return
			# crusted lava (water met it: src/hell/story_elements.gd) is cool stone for a while
			var crusted: bool = ElementRules.material(style) == "lava" and g.get("story_elements") != null and g.story_elements.crusted(m.p)
			if not rule.is_empty() and not crusted and not ElementRules.immune(tags, rule):
				m.env = rule.duplicate()
				if rule.has("pull"):
					m.env.centre = g._pool_centre(m.p, style) if g.has_method("_pool_centre") else m.p
				_medium_on_mob(m, rule, "env_tick", dt)
	var gas: RefCounted = g.get("gas")
	if gas != null:
		# it parts the gas round itself (hell_game.gd _step_gas): what it breathes is the cloud at arm's length
		var cloud: Dictionary = gas.around(m.p, 18.0 + 24.0, 4)
		if float(cloud.d) >= ElementRules.dense_from():
			if _combo(m, str(cloud.mat)):
				return
			var rule := ElementRules.gas(str(cloud.mat))
			if not rule.is_empty() and not ElementRules.immune(tags, rule):
				_medium_on_mob(m, rule, "gas_tick", dt)
				if rule.has("blind_shots"):
					m.blind = maxf(float(m.blind), float(rule.blind_shots))


## What a monster's own condition does with the material it stands in
## (element_rules.json combos): burning, it sets poison off (true: the pool or
## cloud is gone); wet, frost freezes it solid for a moment.
func _combo(m: Dictionary, mat: String) -> bool:
	var combos: Dictionary = ElementRules.data().get("combos", {})
	# on fire (fire_t: lava, fire, a burn), not merely poisoned (burn_t is every damage over time)
	var burning := float(m.get("fire_t", 0.0)) > 0.0
	var wet := float(m.get("wet_t", 0.0)) > 0.0
	if burning and mat == "poison" and bool(combos.get("burn_ignites_poison", true)) and g.get("story_elements") != null:
		g.story_elements.fire_at(m.p, float(combos.get("explode_r", 30.0)) * g.PIXEL_WORLD / 2.0)
		return true
	if wet and mat in ["frost", "ice"] and float(combos.get("freeze_wet", 0.0)) > 0.0 and not m.boss and float(m.get("stun", 0.0)) <= 0.0:
		m.stun = float(combos.get("freeze_wet", 0.7))
		m.wet_t = 0.0
		_burst_in(m.p - Vector2(0, m.cy), 10, "frost")
	return false


## What a medium or gas rule does to a monster: its hurt on the tick (enemy_hurt
## hero hits per second, bosses half), its conditions, its dousing.
func _medium_on_mob(m: Dictionary, rule: Dictionary, tick_key: String, dt: float) -> void:
	if rule.has("enemy_hurt"):
		m[tick_key] = float(m.get(tick_key, 0.0)) - dt
		if float(m[tick_key]) <= 0.0:
			var tick := float(rule.get("tick", 1.0))
			m[tick_key] = tick
			var hits := float(rule.enemy_hurt) * tick * (0.5 if m.boss else 1.0)
			m.hp -= hits * float(g.state.dmg)
			m.hit = 0.12
			if g.get("feel") != null:
				g.feel.on_hit(m, Vector2.ZERO, false)
	var status: Dictionary = rule.get("status", {})
	for kind: String in status:
		var spec: Array = status[kind]
		match kind:
			"burn", "poison":
				HeroKit.burn_mob(m, float(spec[0]) * 0.5, float(spec[1]))
				if kind == "burn" and float(m.get("wet_t", 0.0)) <= 0.0:
					m.fire_t = maxf(float(m.get("fire_t", 0.0)), float(spec[1]))
			"slow":
				HeroKit.slow_mob(g, m, 1.0 - float(spec[0]), float(spec[1]))
			"wet":
				m.wet_t = maxf(float(m.get("wet_t", 0.0)), float(spec[1]))
	if bool(rule.get("douse", false)):
		m.burn_t = 0.0
		m.fire_t = 0.0


## Moves, aims and attacks every monster, ends Ignaroth's phases, removes the dead
## and clears a room when its last monster falls.
func update(dt: float) -> void:
	var me := _me()
	for m: Dictionary in g.mobs:
		if m.spawn > 0.0:
			m.spawn -= dt
			continue
		m.hit = maxf(0.0, m.hit - dt)
		m.at += dt
		# the element physics: what it stands in and breathes (src/combat/element_rules.gd)
		_step_medium(m, dt)
		if m.has("echo"):
			m.echo -= dt
			if m.echo <= 0.0 and m.hp > 0.0:
				m.hp = 0.0
				m.quiet = true
				g._burst(m.p - Vector2(0, m.cy), 24)
		var lord := Rules.is_lord(m.def)
		if lord and m.boss and m.hp <= 0.0 and m.trans == null and m.dying == null:
			_start_lord_end(m)
		if m.intro != null:
			_update_intro(m, dt)
			continue
		if m.trans != null or m.dying != null:
			_update_lord_end(m, dt)
			if m.anim != m.get("last_anim", ""):
				m.last_anim = m.anim
				m.at = 0.0
			continue
		for i in range(m.cds.size()):
			m.cds[i] -= dt
		# hero skills: slows, burns and stuns tick here; a stunned or held monster waits
		var pace := HeroKit.tick_mob(g, m, dt)
		# a dragon reeling from a severed part (src/hell/drake_rig_host.gd) stands and starts no attack
		var held: bool = pace <= 0.0 or m.get("hold", false) or (rig_host != null and rig_host.staggered(m))
		var to: Vector2 = me - m.p
		var d := maxf(to.length(), 1.0)
		var v := Vector2.ZERO
		if m.act != null:
			_run_act(m, dt)
			if m.act != null:
				v = m.act.get("v", Vector2.ZERO)
		else:
			var i := -1 if g.state.dead > 0.0 or held else Rules.pick_attack(m.st.attacks, m.cds, d)
			# in steam or smoke it cannot see to shoot: only a blow at arm's length goes (element_rules.json blind_shots)
			if i >= 0 and float(m.get("blind", 0.0)) > 0.0 and not str(m.st.attacks[i].kind) in BLIND_ATTACKS:
				i = -1
			if i >= 0:
				_start_act(m, i, to, d)
			else:
				v = _move(m, dt, to, d)
		var act = m.act
		var locked: bool = act != null and ((act.kind == "dash" and not act.get("warn", false)) or act.kind == "sweep")
		if not locked and absf(to.x) > (float(cfg.lord_face_deadzone) if lord else 10.0):
			m.face = signf(to.x)
		for o: Dictionary in g.mobs:
			if o != m:
				var off: Vector2 = m.p - o.p
				var od := off.length()
				if od > 0.0 and od < (m.r + o.r) * 0.8:
					v += off / od * 120.0
		v *= 0.0 if held else pace
		# on ice or blood it keeps its momentum (element_rules.gd slide), the void pulls it in
		var env: Dictionary = m.get("env", {})
		if bool(env.get("slide", false)):
			m.sv = ElementRules.slide(m.get("sv", v), v, float(env.get("grip", 0.1)), dt)
			v = m.sv
		else:
			m.sv = v
		if env.has("pull"):
			v += ElementRules.pull(env, m.p, env.get("centre", m.p))
		v += m.k
		m.k *= 0.86
		var moved_from: Vector2 = m.p
		var rr := minf(m.r * 0.7, 40.0)
		var avoid: bool = not m.boss and m.st.ai != "hover" and m.st.ai != "drift"
		var nx: float = m.p.x + v.x * dt
		if not g.box_blocked(Rect2(nx - rr, m.p.y - rr, rr * 2.0, rr), avoid) and not HeroKit.wall_blocks(g, Vector2(nx, m.p.y), rr):
			m.p = Vector2(nx, m.p.y)
		var ny: float = m.p.y + v.y * dt
		if not g.box_blocked(Rect2(m.p.x - rr, ny - rr, rr * 2.0, rr), avoid) and not HeroKit.wall_blocks(g, Vector2(m.p.x, ny), rr):
			m.p = Vector2(m.p.x, ny)
		# a body thrown by Rage slams into the wall it meets (src/hero/story_hero.gd)
		if g.story_hero != null and m.has("slam"):
			# sound hook: the slam is the hero's (src/hero/story_sound.gd source "hero")
			g.as_source("hero", func() -> void: g.story_hero.check_slam(m, moved_from, dt))
		act = m.act
		var airborne: bool = act != null and float(act.get("air", 0.0)) > 20.0
		if d < m.r + float(cfg.contact_reach) and m.alpha > 0.6 and not immune(m) and not airborne:
			# a body blow pushes him off; a dashing beast runs him over harder
			_hurt_by(m, 1, "erschlagen" if m.boss else "erwischt", m.p, "dash" if act != null and str(act.kind) == "dash" else "contact")
		var want: String = act.anim if act != null else ("run" if v.length() > 20.0 else "idle")
		if want != m.anim:
			m.anim = want
			m.at = 0.0
	for m: Dictionary in g.mobs.duplicate():
		var lord_boss: bool = Rules.is_lord(m.def) and m.boss
		if not ((m.hp <= 0.0 and not lord_boss) or m.get("remove", false)):
			continue
		if m.dying != null or (m.trans == null and not m.has("echo")):
			# uid: Ignaroth's rig keeps falling apart in the corpse (src/hell/drake_rig_host.gd)
			corpses.append({"id": m.id, "p": m.p, "s": m.s, "face": m.face, "t": 0.0, "uid": m.get("uid", -1)})
		if m.trans == null and not m.get("quiet", false):
			# a crypt figure bursts in its element (bone splinters, poison, frost, gold), the hell's in embers
			_burst_in(m.p - Vector2(0, m.cy), 80 if m.boss else 18, own_element(m))
			# the shared combat feel: burst in the monster's material, chips, a stain
			FrostCombat.after_kill(g, m)
		# experience: felled monsters and a defeated boss form; echoes and swept-away adds give none
		if not m.get("quiet", false) and not m.has("echo"):
			HeroKit.gain(g, HeroKit.exp_for(g, m))
			if g.talents != null: g.talents.killed(m)
			# sound hook: with the feel the kill sounds in the crypt material (feedback.gd via after_kill)
			if g.feel == null:
				g._sound("kill_" + str(m.def.get("material", "void")))
		g.mobs.erase(m)
		var rest: Array = g.mobs.filter(func(o: Dictionary) -> bool: return o.room == m.room and o.hp > 0.0 and not o.get("remove", false))
		if rest.is_empty():
			if m.boss:
				g.eshots.clear()
				zones.clear()
				lobs.clear()
			g._clear_room(g.W.rooms[m.room], m.p)
	_update_zones(dt)
	_update_scorches(dt)
	_update_pixel_fx(dt)


func _move(m: Dictionary, dt: float, to: Vector2, d: float) -> Vector2:
	var n := to / d
	var side := Vector2(-n.y, n.x)
	var t: float = g.state.t
	var wob: float = sin(t * 3.0 + m.seed) * 0.7
	var v := Vector2.ZERO
	match String(m.st.ai):
		"hover":
			var a: float = t * 1.6 + m.seed
			var aim: Vector2 = _me() + Vector2(cos(a) * 190.0, -40.0 + sin(a) * 140.0) - m.p
			v = aim.normalized() * m.sp
		"keep":
			var k := float(m.st.get("keep", 380.0))
			var dir := -1.0 if d < k * 0.8 else (1.0 if d > k * 1.2 else 0.0)
			v = (n * dir + side * (wob * 0.4 if dir != 0.0 else 1.0)) * m.sp
		"hop":
			m.hop_t += dt
			var ph := fmod(float(m.hop_t), 1.1)
			if ph < 0.45:
				v = n * m.sp * 2.3
			elif ph < 0.45 + dt and not m.landed:
				m.landed = true
				# it lands in a splash of its matter: the hell's hoppers in lava, the crypt's zombies in
				# their poison; a chest of gold only scatters gold dust (no pool of gold or bone)
				var own := own_element(m)
				if own == "" or own in POOL_ELEMENTS:
					_zone({"kind": "puddle", "p": m.p, "r": 40.0, "T": 1.6, "dmg": 1, "m": m, "st": "lava" if own == "" else own})
				else:
					_residue(m.p, own, 3, 20.0)
			if ph > 0.5:
				m.landed = false
		"skirmish":
			if randf() < dt * 0.5:
				m.circ = -m.circ
			var k := 1.0 if d > 230.0 else (-1.0 if d < 230.0 * 0.7 else 0.0)
			v = (n * k + side * m.circ * (0.5 if k != 0.0 else 1.0)) * m.sp
		"drift":
			v = (n * 0.7 + side * sin(t + m.seed)) * m.sp
		_:
			v = (n + side * wob) * m.sp
	if m.boss and d < m.r * 0.9:
		v *= 0.2
	return v


func _start_act(m: Dictionary, i: int, to: Vector2, d: float) -> void:
	var a: Dictionary = m.st.attacks[i]
	m.cds[i] = Rules.next_cooldown(a, m.boss, randf())
	# rig hook: a lost part cancels this attack or weakens a COPY of it (m.st is shared, never changed);
	# {} while he staggers, the attack is gone or a flight would follow a landing too soon. The cooldown stays used.
	if rig_host != null:
		a = rig_host.prepare(m, a)
		if a.is_empty():
			return
	var act := {"a": a, "kind": a.kind, "t": 0.0, "dir": to / d, "n": 0, "anim": Rules.act_anim(a.kind, m.def), "v": Vector2.ZERO}
	if a.kind == "slam" and a.get("leap", false):
		act.leap = {"from": m.p, "to": _me()}
	if a.kind == "beam":
		# a single laser aims from its drawn origin at the hero's body
		var b0 := _beam_aim(m) if int(a.beams) == 1 else to.angle()
		var beams: Array = []
		for k in range(int(a.beams)):
			beams.append(b0 + float(k) / float(a.beams) * TAU)
		act.beams = beams
	m.act = act


## Where a beam of `m` starts (its drawn core, src/hell/drake_rig_host.gd).
func _beam_head(m: Dictionary) -> Vector2:
	return rig_host.muzzle(m, "beam", m.p - Vector2(0, m.cy)) if rig_host != null else m.p - Vector2(0, m.cy)


## Angle from a beam's origin to the hero's body: a single laser aims there.
func _beam_aim(m: Dictionary) -> float:
	return (_me() - Vector2(0, 30) - _beam_head(m)).angle()


## Distance from a point along a direction until a wall, at most max_len.
func _wall_len(from: Vector2, ang: float, max_len: float) -> float:
	var l := 0.0
	while l < max_len:
		var p := from + Vector2.from_angle(ang) * l
		if not g._walkable(g._cell(int(floor(p.x / g.C)), int(floor(p.y / g.C)))):
			return l
		l += 24.0
	return max_len


func _run_act(m: Dictionary, dt: float) -> void:
	var A: Dictionary = m.act
	var a: Dictionary = A.a
	A.t += dt
	# rig hook: a part fell in this act's windup (he reels), or the part of the running breath/beams fell: it stops here
	if rig_host != null and rig_host.cancels(m):
		m.act = null
		return
	var t: float = A.t
	var head: Vector2 = m.p - Vector2(0, m.cy)
	# rig hook: bolts, breath and lobs leave the drawn mouth, rings and beams the drawn core (src/hell/drake_rig_host.gd)
	if rig_host != null:
		head = rig_host.muzzle(m, String(A.kind), head)
		# an attack with "from" [part, x, y] leaves that drawn point (the Seelenhirte's staff tip), while the part is there
		var src: Variant = a.get("from")
		if src is Array and (src as Array).size() >= 3 and not str(src[0]) in Array(m.get("parts_lost", [])):
			head = rig_host.part_point(m, str(src[0]), Vector2(float(src[1]), float(src[2])), head)
	var me := _me()
	var dmg := int(cfg.hit_boss) if m.boss else int(cfg.hit_mob)
	# the crypt's figures attack in their own element, the hell's in fire (an echo is void)
	var own := own_element(m)
	var color := own if own != "" and not m.has("echo") else Rules.shot_color(m.id, m.has("echo"))
	var hot := own if own != "" else "fire"
	if A.kind in Rules.DRAGON_KINDS:
		_run_dragon_act(m, dt)
		return
	match String(A.kind):
		"dash":
			if t < 0.5:
				var aim: Vector2 = me - m.p
				if aim.length() > 0.0:
					A.dir = aim.normalized()
				A.v = Vector2.ZERO
				A.warn = true
				return
			if A.get("warn", true):
				_released(m)
				_impact(m.p, "small", m)
			A.warn = false
			A.v = A.dir * float(a.speed)
			_dash_fx(m, A, dt)
			if t > 0.5 + minf(0.55, float(a.get("range", 500.0)) / float(a.speed)):
				# it skids to a halt: grit flies and the rubble around lifts
				_pixel_burst(m.p - Vector2(0, 4), 12 if m.boss else 5, WAVE_DUST, 220.0, 220.0, 1.0, 2)
				_phys_blast(m.p, 70.0, 4, 0.5)
				_impact(m.p, "small", m)
				if int(A.get("rep", 1)) < int(a.get("repeat", 1)):
					A.rep = int(A.get("rep", 1)) + 1
					A.t = 0.3
				else:
					m.act = null
			return
		"lob":
			if t >= 0.45 and A.n == 0:
				A.n = 1
				_released(m)
				for k in range(int(a.get("count", 1))):
					var aim := me + (Vector2(randf_range(-130, 130), randf_range(-100, 100)) if k > 0 else Vector2.ZERO)
					lobs.append({"from": head, "to": aim, "t": 0.0, "T": 0.8 + k * 0.12, "r": float(a.get("radius", 70.0)),
						"dmg": dmg, "m": m, "c": "lava" if m.id in LAVA_LOBBERS else hot, "done": false, "look": str(a.get("look", "")), "pool": bool(m.def.get("pool", false))})
			if t > 0.7:
				m.act = null
			return
		"bolt", "breath", "homing":
			var wind := 0.3 if A.kind == "breath" else 0.35
			# a breath leaves every mouth it still has (a many-headed beast: its drawn mouths)
			var mouths: Array = _mouths(m, a, head) if A.kind == "breath" else []
			if A.kind == "breath":
				_breath_fx(A, a, mouths, t, wind, dt, hot)
			# souls gather in the staff before they are let go
			if str(a.get("look", "")) == "wisp" and A.n == 0 and t < wind:
				_charge_fx(m, A, head, color, dt)
			if t >= wind and A.n == 0:
				A.n = 1
				_released(m)
				A.jet_to = me - Vector2(0, 30)
				_impact(mouths[0] if not mouths.is_empty() else head, "small", m)
				var base := (me - Vector2(0, 30) - head).angle()
				var heads := int(a.get("heads", 1))
				var count := int(a.get("count", 1))
				var spread := 0.7 if A.kind == "breath" else float(a.get("spread", 0.3))
				for h in range(heads):
					for k in range(count):
						var ang := base + ((h - 1) * 0.45 if heads > 1 else 0.0) + ((float(k) / (count - 1) - 0.5) * spread if count > 1 else 0.0)
						if A.kind == "breath":
							var mouth: Vector2 = mouths[h % mouths.size()]
							ang = (me - Vector2(0, 30) - mouth).angle() + (float(h) - float(mini(heads, mouths.size()) - 1) / 2.0) * 0.25 \
								+ ((float(k) / (count - 1) - 0.5) * spread if count > 1 else 0.0) + randf_range(-0.075, 0.075)
							_shot(mouth, Vector2.from_angle(ang), 380.0 + randf() * 140.0,
								{"t": float(a.get("range", 260.0)) / 450.0, "small": true, "c": hot, "breath": true})
						elif A.kind == "homing":
							var fan := (k - (count - 1) / 2.0) * 0.6
							_shot(head - Vector2(0, 20), Vector2.from_angle(ang + fan), float(a.get("speed", 250.0)), {"t": 4.5, "homing": 2.2, "c": color, "look": str(a.get("look", ""))})
						else:
							_shot(head, Vector2.from_angle(ang), float(a.get("speed", 500.0)), {"c": color})
			if t > wind + 0.3:
				# a breath of poison, frost or fire hangs in the air where it went: a gas cloud that
				# poisons, chills or smokes whoever stands in it (element_rules.json gases)
				if A.kind == "breath" and A.has("jet_to"):
					_breath_cloud(m, hot, mouths[0] if not mouths.is_empty() else head, A.jet_to, float(a.get("range", 260.0)))
				m.act = null
			return
		"ring":
			var waves := int(a.get("waves", 1))
			# it gathers first: pixels rise and pop where it will burst (lava boils over the rim)
			if A.n == 0 and t < 0.45:
				_charge_fx(m, A, head, "void" if a.get("void", false) else ("lava" if m.id in LAVA_LOBBERS else color), dt)
			if t >= 0.45 + A.n * 0.35 and A.n < waves:
				if A.n == 0:
					_released(m)
					# the core bursts: sparks out of it, a low shockwave over the floor (no harm)
					var burst := "void" if a.get("void", false) else color
					_pixel_burst(head, 20 if m.boss else 8, PX_COL.get(burst, PX_COL.fire), 320.0, 260.0, 0.7)
					if m.boss:
						_zone({"kind": "wave", "p": m.p, "r": 150.0, "T": 0.35, "dmg": 0, "m": m, "c": burst})
						_phys_blast(m.p, 160.0, 0, 0.7)
						_residue(m.p, burst, 24, 120.0)
						_impact(head, "medium", m)
				var off: float = A.n * PI / float(a.count) + g.state.t * 0.2
				# the shots start on a ring round the burst, not stacked in one point (their glows would add up)
				for k in range(int(a.count)):
					var out := Vector2.from_angle(off + float(k) / float(a.count) * TAU)
					_shot(head + out * float(m.r) * 0.95, out, float(a.get("speed", 280.0)),
						{"c": "void" if a.get("void", false) else ("lava" if m.id in LAVA_LOBBERS else color), "look": str(a.get("look", ""))})
				A.n += 1
			if t > 0.55 + waves * 0.35:
				m.act = null
			return
		"spiral":
			A.spin = float(A.get("spin", randf() * 6.0)) + dt * 2.4
			A.acc = float(A.get("acc", 0.0)) + dt
			var arms := int(a.arms)
			# souls gather in the staff, then stream out in turning arms
			if t <= 0.4:
				_charge_fx(m, A, head, color, dt)
			if t > 0.4 and t - dt <= 0.4:
				_released(m)
				_impact(head, "small", m)
			while A.acc > float(a.rate) and t > 0.4:
				A.acc -= float(a.rate)
				for k in range(arms):
					var turn := (-1.0 if k % 2 == 1 else 1.0) * (-1.0 if arms > 2 and k >= 2 else 1.0)
					_shot(head, Vector2.from_angle(turn * A.spin + float(k) / arms * TAU), float(a.get("speed", 280.0)), {"c": color, "look": str(a.get("look", ""))})
			if t > 0.4 + float(a.duration):
				m.act = null
			return
		"slam":
			var leap: bool = A.has("leap")
			if leap:
				var L: Dictionary = A.leap
				var k := minf(1.0, t / 0.7)
				if k < 1.0:
					A.air = sin(k * PI) * 120.0
					var np: Vector2 = L.from.lerp(L.to, k)
					if not g.box_blocked(Rect2(np.x - m.r * 0.5, np.y - m.r * 0.5, m.r, m.r * 0.5), false):
						m.p = np
					A.warn_at = L.to
					return
				A.air = 0.0
			if A.n == 0 and t >= (0.7 if leap else 0.75):
				A.n = 1
				_released(m)
				if a.get("line", false):
					_zone({"kind": "line", "p": m.p, "ang": (me - m.p).angle(), "len": float(a.radius) * 2.6, "w": 70.0, "tele": 0.45, "T": 0.8, "dmg": dmg, "m": m, "c": hot})
				else:
					_zone({"kind": "wave", "p": m.p, "r": float(a.radius), "T": 0.5, "dmg": dmg, "m": m, "c": hot})
				_burst_in(m.p - Vector2(0, 10), 50 if m.boss else 16, hot)
				_react(hot, m.p, float(a.radius) * 0.5)
				# the floor breaks: glowing cracks, rock chunks and sparks thrown up
				if not a.get("line", false):
					_crack_floor(m.p, float(a.radius), 9 if m.boss else 5, own != "")
				_pixel_burst(m.p - Vector2(0, 4), 24 if m.boss else 8, CHUNK_COL, 300.0, 420.0, 1.1, 2)
				_pixel_burst(m.p - Vector2(0, 8), 30 if m.boss else 10, PX_COL.lava if own == "" else PX_COL[own], 420.0, 520.0, 0.7)
				_phys_blast(m.p, float(a.radius), (18 if m.boss else 6) if own == "" else 0, 1.2)
				if own != "":
					_residue(m.p, own, 14 if m.boss else 6, float(a.radius) * 0.5)
				# a cleave hits medium where the blade lands (its split strikes after); a stomp hits large
				_impact(m.p, "medium" if a.get("line", false) else "large", m)
				if m.id in PUDDLE_SLAMMERS or bool(m.def.get("pool", false)):
					_zone({"kind": "puddle", "p": m.p, "r": 120.0 if m.boss else 52.0, "T": 2.6, "dmg": 1, "m": m, "st": "lava" if own == "" else own})
			if A.n == 0 and not leap:
				A.warn_at = m.p
			if t > (1.1 if leap else 1.05):
				if leap and int(A.get("rep", 1)) < int(a.get("repeat", 1)):
					A.rep = int(A.get("rep", 1)) + 1
					A.t = 0.0
					A.n = 0
					A.leap = {"from": m.p, "to": me}
				else:
					m.act = null
			return
		"swing":
			if t >= 0.35 and A.n == 0:
				A.n = 1
				_released(m)
				_zone({"kind": "arc", "p": m.p - Vector2(0, m.cy * 0.5), "r": float(a.radius), "ang": (me - m.p).angle(), "arc": float(a.arc), "T": 0.25, "dmg": dmg, "m": m})
				# a burning blade leaves its element where it struck the floor in front
				if str(a.get("element", "")) != "":
					_residue(m.p + Vector2.from_angle((me - m.p).angle()) * float(a.radius) * 0.45, str(a.element), 4, 26.0)
			if t > 0.6:
				m.act = null
			return
		"summon":
			# a caller with a staff ("from") draws its power in first
			if a.has("from") and A.n == 0 and t < 0.6:
				_charge_fx(m, A, head, color, dt)
			if t >= 0.6 and A.n == 0:
				A.n = 1
				_released(m)
				var here: int = g.mobs.filter(func(o: Dictionary) -> bool: return o.room == m.room and not o.boss).size()
				for id: String in a.mobs:
					if here < int(a.get("max", 4)) + 1:
						var p := free_spot(m.room, m.p, 90, 200)
						var s := spawn(m.room, p, id)
						s.spawn = 0.8
						_burst_in(p - Vector2(0, 20), 14, color)
						# a brood thrown out of the cauldron: lava arcs over to where it hatches
						if str(a.get("hatch", "")) == "lava":
							_lava_arc(m.p, m.p.y - head.y, p, 12)
						_rift(p, "lava" if str(a.get("hatch", "")) == "lava" else color)
						_impact(p, "small", m)
			if t > 0.9:
				m.act = null
			return
		"teleport":
			if t < 0.35:
				m.alpha = 1.0 - t / 0.35
				return
			if A.n == 0:
				A.n = 1
				_released(m)
				_burst_in(head, 18, color)
				m.p = free_spot(m.room, me, 170, 260)
			m.alpha = minf(1.0, (t - 0.35) / 0.3)
			if t > 0.7:
				m.alpha = 1.0
				m.act = null
			return
		"meteors", "hands":
			var slag := str(a.get("look", "")) == "slag"
			# boiling over: the lava boils up in the cauldron, then shoots up as a fountain
			if slag and A.n == 0 and t < 0.5:
				_charge_fx(m, A, head, "lava", dt)
			if slag and A.n == 1 and t < 0.9:
				_fountain(m, A, head, dt)
			if t >= 0.5 and A.n == 0:
				A.n = 1
				_released(m)
				var meteor: bool = A.kind == "meteors"
				if slag:
					_impact(head, "medium", m)
					_pixel_burst(head, 24, PX_COL.lava, 160.0, 620.0, 1.2, 2)
				# the slag comes down a while after it went up, one drop after another
				var fall := float(a.get("fall", 0.12))
				for k in range(int(a.count)):
					var p := me if k == 0 else me + Vector2(randf_range(-260, 260), randf_range(-190, 190))
					_zone({"kind": "meteor" if meteor else "hand", "p": p, "r": float(a.radius), "t": -k * fall - float(a.get("delay", 0.0)),
						"tele": 1.0 if meteor else 0.85, "T": 1.35 if meteor else 1.25, "dmg": dmg, "m": m, "look": str(a.get("look", "")), "c": own})
			if t > (0.9 if slag else 0.8):
				m.act = null
			return
		"chain":
			if t >= 0.35 and A.n == 0:
				A.n = 1
				_released(m)
				var sp := float(a.get("speed", 700.0))
				_shot(head, me - Vector2(0, 30) - head, sp, {"chain": m, "c": "chain", "t": float(a.get("range", 600.0)) / sp})
				# the hook is flung: a rattle of sparks off the chain
				_pixel_burst(head, 8, PX_COL.chain, 220.0, 160.0, 0.4)
				_impact(head, "tiny", m)
			if t > 0.7:
				m.act = null
			return
		"scream":
			if A.n == 0 and t > 0.1:
				A.n = 1
				_released(m)
				_zone({"kind": "cone", "p": head + Vector2(0, 20), "ang": (me - head).angle(), "r": float(a.range), "arc": float(a.arc),
					"tele": 0.55, "T": 0.9, "dmg": 1, "slow": 2.0, "m": m, "push": "scream"})
			if t > 1.0:
				m.act = null
			return
		"beam":
			if t < 0.8:
				A.warn = true
				# a single laser follows the hero while it aims ("track" seconds), then locks
				if A.beams.size() == 1 and t < float(a.get("track", 0.0)):
					A.beams[0] = _beam_aim(m)
				return
			if A.get("warn", true):
				_released(m)
				# a laser fires with a muzzle flash and a kick
				if str(a.get("style", "")) == "laser":
					_impact(head, "small", m)
					_pixel_burst(head, 8, PX_COL.fire, 160.0, 80.0, 0.4)
			A.warn = false
			for k in range(A.beams.size()):
				A.beams[k] += float(a.turn) * dt
			var rel: Vector2 = me - Vector2(0, 30) - head
			var laser := str(a.get("style", "")) == "laser"
			var reach := float(a.get("range", 1100.0))
			for b: float in A.beams:
				var dir := Vector2.from_angle(b)
				var along := rel.dot(dir)
				var len := _beam_reach(head, b, reach) if laser else _wall_len(head, b, reach)
				if along > 0.0 and along < len and absf(dir.cross(rel)) < float(a.get("hit_width", 36.0)):
					_hurt_by(m, 1, "verbrannt", head, "laser" if laser else "")
				# a laser burns into the wall it meets: pixel fire that glows on, and the crypt's fire wall hit
				if laser and len < reach:
					var contact := head + dir * len
					if not A.has("scorched"):
						A.scorched = true
						_scorch(contact, maxf(0.0, 0.8 + float(a.duration) - t))
					# embers fall at the foot of the wall it burns into
					_residue(contact + Vector2(0, 24), "fire", 6, 22.0)
					A.spark = float(A.get("spark", 0.0)) - dt
					if float(A.spark) <= 0.0 and g.get("feel") != null:
						A.spark = SCORCH_SPARK
						g.feel.wall_hit(contact - dir * 16.0, contact + dir * 16.0, "fire")
			if t > 0.8 + float(a.duration):
				m.act = null
			return
	m.act = null


# ---------- Ignaroth ----------

## Starts the boss arrival: a long swoop from the sky, or a burst out of the floor.
func start_intro(m: Dictionary) -> void:
	var kind := String(m.st.get("intro", "burrow"))
	m.intro = {"kind": kind, "t": 0.0}
	if kind == "flyin":
		m.intro.to = m.p
		m.alt = 900.0
		m.p = m.p - Vector2(700, 0)
		m.anim = "fly"
	else:
		m.burrowed = true
		m.sink = 1.0


func _update_intro(m: Dictionary, dt: float) -> void:
	var I: Dictionary = m.intro
	I.t += dt
	var t: float = I.t
	if I.kind == "flyin":
		# a long swoop in from above; the shadow grows on the floor, then a heavy landing
		var k := Rules.smooth(minf(1.0, t / 2.4))
		m.p = Vector2(I.to.x - 700.0 * (1.0 - k), I.to.y - 140.0 * sin(k * PI) * (1.0 - k))
		m.alt = 900.0 * pow(1.0 - k, 1.6)
		m.anim = "fly"
		if t > 0.2 and randf() < 0.3:
			g.embers.append({"p": m.p + Vector2(randf_range(-60, 60), -m.alt - m.cy), "v": Vector2(-80, 40), "t": 0.8, "big": true, "gold": false})
		if t >= 2.4 and not I.get("landed", false):
			I.landed = true
			m.alt = 0.0
			_shake(14)
			g._burst(m.p, 60)
			_zone({"kind": "wave", "p": m.p, "r": 380.0, "T": 0.6, "m": m, "c": "void" if m.id == "drache4" else "fire"})
		if t >= 2.4:
			m.anim = "cast"
		if t >= 3.4:
			m.intro = null
			m.anim = "idle"
			m.at = 0.0
			g._toast("%s greift an!" % m.def.name)
		return
	# phase 1 and 2: a glowing crack, then he bursts out of the floor
	if t < 1.1:
		m.burrowed = true
		if randf() < 0.5:
			g._burst(m.p + Vector2(randf_range(-30, 30), 0), 2)
		return
	if not I.get("out", false):
		I.out = true
		m.burrowed = false
		_shake(10)
		g._burst(m.p - Vector2(0, 10), 50)
		_zone({"kind": "wave", "p": m.p, "r": 260.0, "T": 0.45, "m": m, "c": "lava"})
	m.sink = maxf(0.0, 1.0 - (t - 1.1) / 0.35)
	m.anim = "cast"
	if t >= 2.2:
		m.intro = null
		m.sink = 0.0
		m.anim = "idle"
		m.at = 0.0
		g._toast("%s greift an!" % m.def.name)


func _run_dragon_act(m: Dictionary, dt: float) -> void:
	var A: Dictionary = m.act
	var a: Dictionary = A.a
	var t: float = A.t
	var me := _me()
	var dmg := int(cfg.hit_boss)
	match String(A.kind):
		"burrow":
			if t < 0.55:
				A.anim = "cast"
				m.sink = Rules.smooth(t / 0.55)
				if randf() < 0.6:
					g._burst(m.p + Vector2(randf_range(-25, 25), 0), 2)
				return
			if not A.get("under", false):
				A.under = true
				m.burrowed = true
				A.anim = "idle"
			if not A.has("warn_t"):
				var to: Vector2 = me - m.p
				var d := maxf(to.length(), 1.0)
				A.v = to / d * float(cfg.burrow_speed)
				m.trail += dt
				if m.trail > 0.05:
					m.trail = 0.0
					g._burst(m.p, 1)
				if d < 40.0 or t > 2.6:
					A.warn_t = t
					A.v = Vector2.ZERO
					_zone({"kind": "erupt", "p": m.p, "r": float(a.radius), "tele": 0.5, "T": 0.75, "dmg": dmg, "m": m})
				return
			A.v = Vector2.ZERO
			if t - A.warn_t >= 0.5 and not A.get("out", false):
				A.out = true
				_released(m)
				m.burrowed = false
				_shake(12)
				g._burst(m.p - Vector2(0, 20), 40)
				for k in range(int(a.ring)):
					# the ring bursts from the drawn core (src/hell/drake_rig_host.gd)
					_shot(rig_host.muzzle(m, "burrow", m.p - Vector2(0, m.cy)) if rig_host != null else m.p - Vector2(0, m.cy), Vector2.from_angle(float(k) / float(a.ring) * TAU), 330.0)
				if a.get("lava", false):
					for k in range(4):
						var ang := k / 4.0 * TAU + 0.4
						_zone({"kind": "puddle", "p": m.p + Vector2(cos(ang) * 120.0, sin(ang) * 80.0), "r": 60.0, "T": 3.0, "dmg": 1, "m": m})
			if A.get("out", false):
				A.anim = "cast"
				m.sink = maxf(0.0, 1.0 - (t - A.warn_t - 0.5) / 0.3)
			if t - A.warn_t > 1.2:
				m.sink = 0.0
				m.act = null
		"flight":
			var top := float(cfg.flight_altitude)
			var T := float(a.duration)
			A.anim = "fly"
			if t < 0.7:
				m.alt = top * Rules.smooth(t / 0.7)
				A.v = Vector2.ZERO
				if t < 0.1:
					_shake(5)
				return
			if t < 0.7 + T:
				if t - dt < 0.7:
					_released(m)
				# circle above the hero and drop bombs on where he stands
				var ang: float = g.state.t * 1.3
				var aim: Vector2 = me + Vector2(cos(ang) * 260.0, sin(ang) * 160.0) - m.p
				var l := maxf(aim.length(), 1.0)
				A.v = aim / l * minf(520.0, l * 3.0)
				m.alt = top + sin(t * 3.0) * 20.0
				A.drop = float(A.get("drop", 0.0)) + dt
				if A.drop > float(a.drop):
					A.drop = 0.0
					_zone({"kind": "meteor", "p": me + Vector2(randf_range(-60, 60), randf_range(-45, 45)), "r": float(a.radius),
						"tele": 0.85, "T": 1.15, "dmg": dmg, "m": m, "void": a.get("void", false)})
				return
			if not A.has("land"):
				A.land = {"from": m.p, "to": me + Vector2(0, 10), "t0": t}
				_zone({"kind": "land", "p": me + Vector2(0, 10), "r": 260.0, "tele": 0.7, "T": 0.7, "m": m})
			var L: Dictionary = A.land
			var k := Rules.smooth((t - L.t0) / 0.7)
			A.v = Vector2.ZERO
			m.p = L.from.lerp(L.to, k)
			m.alt = top * (1.0 - k)
			if k >= 1.0:
				m.alt = 0.0
				_shake(14)
				g._burst(m.p, 50)
				_zone({"kind": "wave", "p": m.p, "r": 300.0, "T": 0.55, "dmg": dmg, "m": m, "c": "void" if a.get("void", false) else "fire"})
				m.act = null
		"sweep":
			A.anim = "attack"
			A.v = Vector2.ZERO
			if not A.has("base"):
				# aimed from the drawn mouth (src/hell/drake_rig_host.gd)
				A.base = (me - (rig_host.muzzle(m, "sweep", m.p - Vector2(0, m.cy)) if rig_host != null else m.p - Vector2(0, m.cy))).angle()
				A.sign = 1.0 if randf() < 0.5 else -1.0
			if t < 0.45:
				return
			if t - dt < 0.45:
				_released(m)
			var k := minf(1.0, (t - 0.45) / float(a.duration))
			var ang: float = A.base + (k - 0.5) * float(a.arc) * A.sign
			m.face = 1.0 if cos(ang) >= 0.0 else -1.0
			A.acc = float(A.get("acc", 0.0)) + dt
			var mouth: Vector2 = m.p + Vector2(m.face * m.r * 0.95, -m.cy * 1.35)
			# the breath leaves the rig's mouth where the pose put it (src/hell/drake_rig_host.gd)
			if rig_host != null:
				mouth = rig_host.muzzle(m, "sweep", mouth)
			while A.acc > float(a.rate):
				A.acc -= float(a.rate)
				_shot(mouth, Vector2.from_angle(ang + randf_range(-0.04, 0.04)), float(a.speed) * randf_range(0.85, 1.15),
					{"c": "void" if a.get("void", false) else "fire", "small": true, "t": 1.6})
			if k >= 1.0:
				m.act = null
		"echoes":
			A.anim = "cast"
			A.v = Vector2.ZERO
			if t >= 0.8 and A.n == 0:
				A.n = 1
				_released(m)
				_shake(8)
				var k := 0
				# rig hook: lost horns call fewer echoes (round(3 x 0.34) = 1)
				for id: String in (rig_host.echo_forms(m, a, _earlier_forms(m.id)) if rig_host != null else _earlier_forms(m.id)):
					var p := free_spot(m.room, m.p, 200, 340)
					var e := spawn(m.room, p, id, false)
					e.echo = float(a.life)
					e.hp = round(float(g.W.boss.hp) * float(cfg.echo_hp_share))
					e.max = e.hp
					e.spawn = 0.7 + k * 0.2
					var st: Dictionary = e.st.duplicate()
					st.ai = "chase"
					st.attacks = Rules.echo_attacks(st.attacks, cfg.echo_kinds)
					e.st = st
					var cds: Array = []
					for x: Dictionary in st.attacks:
						cds.append(float(x.every) * randf_range(0.4, 1.0))
					e.cds = cds
					g._burst(p - Vector2(0, 40), 30)
					k += 1
				g._toast("Ignaroth ruft die Echos seiner früheren Formen!")
			if t > 1.4:
				m.act = null
		_:
			m.act = null


## Ignaroth's forms before this one, first phase first.
func _earlier_forms(id: String) -> Array:
	var phase := int(defs[id].phase)
	var out: Array = []
	for other: String in defs:
		if Rules.is_lord(defs[other]) and int(defs[other].phase) < phase:
			out.append(other)
	out.sort_custom(func(x: String, y: String) -> bool: return int(defs[x].phase) < int(defs[y].phase))
	return out


func _set_form(m: Dictionary, id: String) -> void:
	var def: Dictionary = defs[id]
	m.id = id
	m.def = def
	m.st = def.stats
	m.s = float(def.scale)
	m.r = float(def.stats.r)
	m.cy = hit_cy(def)
	# rig hook: the next form's rig comes complete, same uid and HP (no regrow inside his forms)
	if rig_host != null:
		rig_host.on_form_changed(m)


# At 0 HP on floors 3, 6 and 9 he changes into his next form and escapes; on 10 he dies.
func _start_lord_end(m: Dictionary) -> void:
	g.eshots.clear()
	zones = zones.filter(func(z: Dictionary) -> bool: return z.kind == "puddle")
	lobs.clear()
	m.act = null
	m.alt = 0.0
	m.sink = 0.0
	m.burrowed = false
	m.hp = 1.0
	for o: Dictionary in g.mobs:
		if o != m and o.room == m.room:
			o.hp = 0.0
			o.quiet = true
	var next := Rules.next_form(defs, m.id)
	if next != "":
		m.trans = {"t": 0.0, "next": next, "glow": 0.0, "grow": 1.0, "swapped": false}
		g._toast("%s verwandelt sich!" % m.def.name)
	else:
		m.dying = {"t": 0.0, "glow": 0.0}
		g._toast("%s wankt!" % m.def.name)


func _update_lord_end(m: Dictionary, dt: float) -> void:
	if m.trans != null:
		var T: Dictionary = m.trans
		T.t += dt
		var t: float = T.t
		m.anim = "cast" if t < 3.0 or not defs[m.id].anims.has("fly") else "fly"
		if t < 1.5:
			T.glow = 0.4 + 0.6 * absf(sin(t * (4.0 + t * 6.0)))
			if randf() < 0.8:
				var ang := randf() * TAU
				var r := 260.0
				g.embers.append({"p": m.p + Vector2(cos(ang) * r, -m.cy + sin(ang) * r * 0.6), "v": Vector2(-cos(ang) * r * 1.6, -sin(ang) * r),
					"t": 0.6, "big": false, "gold": true})
			_shake(3)
			return
		if not T.swapped:
			T.swapped = true
			_set_form(m, T.next)
			T.grow = 0.0
			g.state.white = 0.9
			_shake(18)
			g._burst(m.p - Vector2(0, m.cy), 90, true)
			_zone({"kind": "wave", "p": m.p, "r": 420.0, "T": 0.7, "m": m, "c": "void" if m.id == "drache4" else "fire"})
			g._toast("… zu %s!" % m.def.name)
		T.glow = maxf(0.0, 1.0 - (t - 1.5) * 1.5)
		T.grow = Rules.smooth((t - 1.5) / 0.6)
		if t < 3.0:
			if randf() < 0.3:
				g._burst(m.p + Vector2(randf_range(-m.r, m.r), -randf() * m.cy * 2.0), 3)
			return
		# escape: wingless forms sink into the floor, winged forms fly off upwards
		if not T.get("left", false):
			T.left = true
			g._toast("%s flieht in die Tiefe. Er kehrt zurück." % m.def.name)
		if defs[m.id].anims.has("fly"):
			m.alt = 1300.0 * pow(Rules.smooth((t - 3.0) / 1.6), 1.3)
			m.p = m.p + Vector2(160.0 * dt, 0)
		else:
			m.sink = Rules.smooth((t - 3.0) / 0.9)
			if randf() < 0.6:
				g._burst(m.p + Vector2(randf_range(-40, 40), 0), 2)
		if t > 4.7:
			m.remove = true
		return
	var D: Dictionary = m.dying
	D.t += dt
	var t: float = D.t
	m.anim = "cast"
	if t < 2.6:
		_shake(6)
	if randf() < 0.5:
		g._burst(m.p + Vector2(randf_range(-1.1, 1.1) * m.r, -randf() * m.cy * 2.2), 14, randf() < 0.4)
	D.glow = 0.3 + 0.5 * absf(sin(t * 9.0))
	if t > 2.6 and not D.get("boom", false):
		D.boom = true
		g.state.white = 1.0
		_shake(24)
		g._burst(m.p - Vector2(0, m.cy), 160, true)
		_zone({"kind": "wave", "p": m.p, "r": 600.0, "T": 1.0, "m": m, "c": "void"})
	if t > 2.8:
		m.remove = true


# ---------- zones, lobs and enemy shots ----------

func _update_zones(dt: float) -> void:
	var me := _me() - Vector2(0, 20)
	for z: Dictionary in zones:
		z.t += dt
		# a scream's sound runs on after it struck: its arcs shove the pixels they pass
		if z.kind == "cone" and z.t >= z.tele:
			_sound_fronts(z)
		if z.t < z.tele or (z.done and z.kind != "puddle"):
			continue
		var d := me.distance_to(z.p)
		var hit := false
		match String(z.kind):
			"wave":
				# its front is a ring of physical pixels (the drawn ring only without the pixel physics)
				z.phys = _wave_pixels(z, minf(1.0, z.t / z.T), dt)
				# and it shoves what it passes: flying pixels, embers, rubble, lava sloshing over
				var front := float(z.r) * minf(1.0, z.t / z.T)
				_blow_front(z, float(z.get("blown", 0.0)), front, 0.0, TAU, 0.62, 1.0)
				z.blown = front
				if z.dmg > 0 and absf(d - z.r * minf(1.0, z.t / z.T)) < 40.0:
					hit = true
			"puddle":
				# where the lava really lies (its pool) when the floor draws pools, else its circle
				var pools: RefCounted = g.get("pools")
				# crusted lava (water met it: src/hell/story_elements.gd) is harmless for a while;
				# a pool the hero threw himself (friend: a potion, src/hero/story_items.gd) spares him
				hit = not bool(z.get("friend", false)) and (pools.covers(me, str(z.get("st", "lava"))) if pools != null else d < z.r) and g.state.inv <= 0.0 and float(z.get("crust", 0.0)) <= 0.0
			"erupt", "land":
				hit = z.dmg > 0 and d < z.r
				z.done = true
			"arc", "cone":
				if d < z.r and Rules.angle_gap((me - z.p).angle(), z.ang) < z.arc / 2.0:
					hit = true
					if z.kind == "cone":
						g.state.slow = z.slow
				# the scream blows the floor's dust and rubble away all through its cone
				if z.kind == "cone" and not z.done:
					_scream_blast(z)
				z.done = true
			"line":
				var rel: Vector2 = me - z.p
				var dir := Vector2.from_angle(z.ang)
				var along := rel.dot(dir)
				hit = along > 0.0 and along < z.len and absf(dir.cross(rel)) < z.w / 2.0
				var k := 0.0
				while k < z.len:
					_burst_in(z.p + dir * k, 4, str(z.get("c", "")))
					k += 60.0
				_fissure(z)
				z.done = true
			_:
				hit = d < z.r
				_burst_in(z.p - Vector2(0, 20), 26 if z.kind == "meteor" else 10, str(z.get("c", "")))
				_react(str(z.get("c", "")), z.p, float(z.r))
				z.done = true
				# a meteor of an element shatters into its matter
				if z.kind == "meteor" and str(z.get("c", "")) in OWN_ELEMENTS:
					_pixel_burst(z.p - Vector2(0, 6), 14, PX_COL.get(str(z.c), PX_COL.fire), 260.0, 380.0, 0.8)
					_residue(z.p, str(z.c), 10, float(z.r) * 0.6)
				# a slag drop splashes: slag and lava thrown up, cracks, a small burning pool
				if str(z.get("look", "")) == "slag":
					_slag_spout(z.m, z.p, 7, float(z.r) * 0.6)
					_phys_blast(z.p, float(z.r), 4, 0.5)
					_impact(z.p, "small", z.m)
				# a grave hand breaks out of the floor: rubble thrown up, violet wisps, the floor marked
				if z.kind == "hand":
					_pixel_burst(z.p, 8, CHUNK_COL, 160.0, 300.0, 1.1, 2)
					_pixel_burst(z.p, 8, PX_COL.void, 180.0, 220.0, 0.6)
					_phys_blast(z.p, float(z.r), 0, 0.5)
					_residue(z.p, "void", 8, float(z.r) * 0.6)
					_impact(z.p, "small", z.m)
		if hit and g.state.dead <= 0.0:
			# the blow pushes him away from where it struck (a scream and a puddle do not)
			var push: String = str(z.get("push", {"wave": "wave", "arc": "arc", "line": "slam", "erupt": "slam", "land": "slam", "meteor": "lob", "hand": "lob"}.get(String(z.kind), "")))
			_hurt_by(z.m, int(z.dmg), "niedergeschrien" if z.kind == "cone" else "getroffen", z.p, push)
	# a lava pool that goes out leaves its crust glowing: embers that sizzle and cool to soot
	for z: Dictionary in zones:
		if z.kind == "puddle" and z.t >= z.T:
			_residue(z.p, str(z.get("st", "lava")), int(float(z.r) / 4.0), float(z.r) * 0.8)
	zones = zones.filter(func(z: Dictionary) -> bool: return z.t < z.T)
	for L: Dictionary in lobs:
		L.t += dt
		_lob_drips(L, dt)
		if L.t >= L.T and not L.done:
			L.done = true
			_burst_in(L.to - Vector2(0, 10), 22, str(L.c))
			_react(str(L.c), L.to, float(L.r))
			# it lands: sparks, and a boulder shatters into chunks and cracks the floor
			_pixel_burst(L.to - Vector2(0, 6), 16, PX_COL.get(str(L.c), PX_COL.fire), 260.0, 380.0, 0.8)
			if str(L.get("look", "")) == "boulder":
				_pixel_burst(L.to - Vector2(0, 4), 12, CHUNK_COL, 220.0, 360.0, 1.0, 2)
				_crack_floor(L.to, float(L.r), 5)
			_phys_blast(L.to, float(L.r), 8 if str(L.c) in ["fire", "lava"] else 0, 0.8)
			if str(L.c) in OWN_ELEMENTS:
				_residue(L.to, str(L.c), 8, float(L.r) * 0.5)
			_impact(L.to, "small", L.m)
			_zone({"kind": "wave", "p": L.to, "r": L.r, "T": 0.3, "dmg": L.dmg, "m": L.m, "c": L.c, "push": "lob"})
			if L.c == "lava":
				_zone({"kind": "puddle", "p": L.to, "r": L.r * 0.6, "T": 2.2, "dmg": 1, "m": L.m, "dir": ((L.to as Vector2) - (L.from as Vector2)).normalized() if L.has("from") else Vector2.ZERO})
			elif bool(L.get("pool", false)):
				_zone({"kind": "puddle", "p": L.to, "r": L.r * 0.6, "T": 2.2, "dmg": 1, "m": L.m, "st": str(L.c), "dir": ((L.to as Vector2) - (L.from as Vector2)).normalized() if L.has("from") else Vector2.ZERO})
	lobs = lobs.filter(func(L: Dictionary) -> bool: return not L.done)
	for c: Dictionary in corpses:
		c.t += dt
	corpses = corpses.filter(func(c: Dictionary) -> bool: return c.t < 0.75)


## Moves enemy shots (homing ones turn toward the hero), stops them at walls,
## hurts the hero, and drags him toward a chain's thrower.
func update_shots(dt: float) -> void:
	var me := Vector2(g.player.x, g.player.y - 34)
	for s: Dictionary in g.eshots:
		# gravity walls swallow shots, gravity bars hold them (hero_kit.gd)
		if HeroKit.catch_shot(g, s, dt) and float(s.get("held", 0.0)) > 0.0:
			continue
		if s.has("homing"):
			var a0: float = s.v.angle()
			var turn := clampf(wrapf((me - s.p).angle() - a0, -PI, PI), -s.homing * dt, s.homing * dt)
			s.v = Vector2.from_angle(a0 + turn) * s.v.length()
		var was: Vector2 = s.p
		s.p += s.v * dt
		s.t -= dt
		_shot_trail(s, dt)
		# a shot of fire through poison gas sets it off (src/hell/story_elements.gd)
		if str(s.get("c", "")) in ["fire", "lava"] and g.get("story_elements") != null:
			g.story_elements.fire_passes(s.p)
		# a soul keeps the path it flew: its gas tail streams along it
		if str(s.get("look", "")) in ["wisp", "tear"]:
			var hist: Array = s.get("hist", [])
			if hist.is_empty() or (hist[hist.size() - 1] as Vector2).distance_to(s.p) >= LASER_PX * 1.5:
				hist.append(s.p)
				if hist.size() > WISP_TAIL:
					hist = hist.slice(hist.size() - WISP_TAIL)
			s.hist = hist
		if g._cell_blocked(int(floor(s.p.x / g.C)), int(floor(s.p.y / g.C)), false):
			s.t = 0.0
			_shot_impact(s.p, str(s.get("c", "fire")), bool(s.get("small", false)))
			# it splashes on the wall like the crypt's shots: sparks, a splat and a crack there
			if g.get("feel") != null and not s.has("chain"):
				var dir: Vector2 = (s.v as Vector2).normalized()
				g.feel.wall_hit(was - dir * 24.0, s.p + dir * 8.0, SHOT_WALL.get(str(s.get("c", "fire")), "fire"))
		elif s.p.distance_to(me) < (26.0 if s.get("small", false) else float(g.balance.enemy_shot.hit_radius)):
			s.t = 0.0
			if s.has("chain"):
				g.state.pull = {"m": s.chain, "t": 0.6}
				g._hurt("von der Kette gepackt")
				# the hook bites: sparks and a jolt
				_pixel_burst(s.p, 10, PX_COL.chain, 240.0, 180.0, 0.45)
				_impact(s.p, "small", s.chain)
			else:
				var open := float(g.state.inv) <= 0.0 and float(g.state.dead) <= 0.0
				g._hurt(HURT_BY.get(s.get("c", ""), "von Feuer getroffen"))
				_shot_impact(s.p, str(s.get("c", "fire")), bool(s.get("small", false)))
				# a landed shot nudges him along its flight
				if open and float(g.state.inv) > 0.0:
					_knock((s.p as Vector2) - (s.v as Vector2).normalized() * 40.0, "shot")
	# a shot that is over (burnt out in the air, against a wall or on him) leaves its element on the floor below it
	for s: Dictionary in g.eshots:
		if float(s.t) <= 0.0 and not s.has("chain"):
			_residue((s.p as Vector2) + Vector2(0, 30), str(s.get("c", "fire")), 2 if s.get("small", false) else 5, 18.0)
	g.eshots = g.eshots.filter(func(s: Dictionary) -> bool: return s.t > 0.0)
	_update_knock(dt)
	var P = g.state.get("pull")
	if P != null:
		var to: Vector2 = P.m.p - Vector2(g.player.x, g.player.y)
		var dl := maxf(to.length(), 1.0)
		var step := minf(dl - P.m.r - 30.0, 1100.0 * dt)
		if step > 0.0:
			var mv := to / dl * step
			if not g.box_blocked(g._player_box(g.player.x + mv.x, g.player.y)):
				g.player.x += mv.x
			if not g.box_blocked(g._player_box(g.player.x, g.player.y + mv.y)):
				g.player.y += mv.y
			# dragged over the floor: his heels kick up dust and grit behind him
			var Ph := _phys()
			if Ph != null and randf() < 0.8:
				var sc := _phys_scale()
				Ph.emit(Vector2(g.player.x, g.player.y) / sc, (-mv / dt * 0.25 + Vector2(randf_range(-40.0, 40.0), randf_range(-20.0, 20.0))) / sc,
					WAVE_DUST[randi() % WAVE_DUST.size()], randf_range(1.2, 2.0), "debris", 2.0, 2.0, randf_range(40.0, 110.0) / sc, 3.0)
		P.t -= dt
		if P.t <= 0.0 or step <= 0.0:
			g.state.pull = null


# ---------- drawing ----------

func _ellipse(l: CanvasItem, c: Vector2, rx: float, ry: float, col: Color) -> void:
	if rx <= 0.0:
		return
	l.draw_set_transform(c, 0.0, Vector2(1.0, ry / rx))
	l.draw_circle(Vector2.ZERO, rx, col)
	l.draw_set_transform(Vector2.ZERO)


func _ellipse_line(l: CanvasItem, c: Vector2, rx: float, ry: float, col: Color, width: float) -> void:
	if rx <= 0.0:
		return
	var pts := PackedVector2Array()
	for k in range(49):
		var a := k / 48.0 * TAU
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	l.draw_polyline(pts, col, width)


func _fan(l: CanvasItem, c: Vector2, r: float, ang: float, arc: float, col: Color) -> void:
	# a sweep all around (tail whirl, ball and chain) is a full disc, not a fan
	if arc >= TAU - 0.05:
		l.draw_circle(c, r, col)
		return
	var pts := PackedVector2Array([c])
	for k in range(25):
		pts.append(c + Vector2.from_angle(ang - arc / 2.0 + arc * k / 24.0) * r)
	l.draw_colored_polygon(pts, col)


func _orb(l: CanvasItem, c: Vector2, r: float, cols: Array, alpha := 1.0) -> void:
	l.draw_circle(c, r, Color(cols[2], 0.35 * alpha))
	l.draw_circle(c, r * 0.62, Color(cols[1], 0.75 * alpha))
	l.draw_circle(c, r * 0.3, Color(cols[0], alpha))


## A telegraph on the pixel grid: the area as a sparse dot grid (fixed to the
## world grid, denser as it comes), its rim as dashes crawling round, and a
## ring growing from the middle to the rim as the strike comes (`k` 0..1).
func _ring(l: CanvasItem, c: Vector2, r: float, k: float, col: Color) -> void:
	var t: float = g.state.t
	var ry := r * 0.62
	var step := 3 if k > 0.6 else 4
	var x0 := int(floor((c.x - r) / LASER_PX / step))
	var x1 := int(ceil((c.x + r) / LASER_PX / step))
	var y0 := int(floor((c.y - ry) / LASER_PX / step))
	var y1 := int(ceil((c.y + ry) / LASER_PX / step))
	for gy in range(y0, y1 + 1):
		for gx in range(x0, x1 + 1):
			var q := Vector2(gx, gy) * LASER_PX * float(step)
			if Vector2((q.x - c.x) / r, (q.y - c.y) / ry).length() <= 1.0:
				l.draw_rect(Rect2(q, Vector2.ONE * LASER_PX), Color(col, 0.22 + 0.25 * k))
	# the rim crawls over a dark underlay one pixel lower, so it reads on the red-cracked floor
	_px_ellipse(l, c + Vector2(0, LASER_PX), r, ry, OUTLINE, 3 if k < 0.7 else 2, int(floorf(t * LASER_FPS)))
	_px_ellipse(l, c, r, ry, col, 3 if k < 0.7 else 2, int(floorf(t * LASER_FPS)))
	if k > 0.05:
		_px_ellipse(l, c + Vector2(0, LASER_PX), r * k, ry * k, OUTLINE)
		_px_ellipse(l, c, r * k, ry * k, col.lightened(0.25))


## Draws one atlas frame with its feet at foot; cut hides that many world pixels
## from the bottom (sinking into the floor). face -1 mirrors it.
func _sprite(l: CanvasItem, id: String, fr: Vector2i, foot: Vector2, sc: float, face: float, tint: Color, cut := 0.0, pose: Dictionary = {}) -> void:
	var def: Dictionary = defs[id]
	var px := float(def.px)
	var fw := float(def.w) * px
	var fh := float(def.h) * px
	# the crypt's pose of a hit (src/hero/story_feel.gd): squash and lean, pivoting at the feet
	var squash: Vector2 = pose.get("scale", Vector2.ONE)
	var w := float(def.w) * sc * squash.x
	var h := float(def.h) * sc * squash.y
	var keep := h - cut
	if keep <= 0.0:
		return
	var src := Rect2(fr.x * fw, fr.y * fh, fw, fh * keep / h)
	var dest := Rect2(-w / 2.0, -h + cut, w, keep)
	l.draw_set_transform(Vector2(round(foot.x), round(foot.y)), float(pose.get("lean", 0.0)), Vector2(face, 1.0))
	l.draw_texture_rect_region(atlas[id], dest, src, tint)
	# the crypt's hit flash: the monster's silhouette in the flash colour (red hit, white kill)
	if float(pose.get("flash", 0.0)) > 0.0 and g.feel != null:
		var step := int(px)
		l.draw_texture_rect_region(g.feel.mask(atlas[id], step), dest, Rect2(src.position / step, src.size / step), StoryFeel.flash_color(pose, tint.a))
	l.draw_set_transform(Vector2.ZERO)


## The crypt's pose of monster `m` and its tint (a white tint on a hit without the feel).
func _pose(m: Dictionary, tint: Color) -> Array:
	if g.feel == null:
		return [{}, Color(2.6, 2.6, 2.6, tint.a) if m.hit > 0.0 else tint]
	var pose: Dictionary = g.feel.pose(m)
	return [pose, Color(tint, tint.a * float(pose.get("alpha", 1.0)))]


## Draws a monster (sorted with the other actors by its feet).
func draw_mob(l: CanvasItem, m: Dictionary) -> void:
	if Rules.is_lord(m.def):
		_draw_lord(l, m)
		return
	var sc: float = m.s * (maxf(0.0, 1.0 - m.spawn * 1.6) if m.spawn > 0.0 else 1.0)
	if sc <= 0.0:
		return
	var air := float(m.act.get("air", 0.0)) if m.act != null else 0.0
	var w := float(m.def.w) * sc
	_ellipse(l, m.p, w * 0.34, w * 0.1 + 4.0, Color(0, 0, 0, 0.45))
	var hov := -10.0 + sin(g.state.t * 4.0 + m.seed) * 5.0 if m.st.ai in ["hover", "drift"] else 0.0
	var look := _pose(m, Color(1, 1, 1, m.alpha))
	# a mob with a part rig (assets/data/hell_rigs.json) moves part by part like the crypt's skeletons
	# and falls apart when it dies (src/hell/drake_rig_host.gd); the atlas otherwise
	if rig_host != null and rig_host.draws(m):
		rig_host.draw(l, m, m.p + Vector2(0, 4.0 + hov - air), sc / m.s, look[1], 0.0, look[0])
		return
	_mark(m, m.p + Vector2(0, 4.0 + hov - air), sc, 0.0, look[1], look[0])
	_sprite(l, m.id, Rules.frame_of(m.def, m.anim, m.at), m.p + Vector2(0, 4.0 + hov - air), sc, m.face, look[1], 0.0, look[0])


func _draw_lord(l: CanvasItem, m: Dictionary) -> void:
	if m.burrowed and m.sink >= 1.0:
		_draw_mound(l, m)
		return
	var T = m.trans
	var D = m.dying
	var alt: float = m.alt
	var grow := 0.75 + 0.25 * float(T.grow) if T != null and T.swapped else 1.0
	var sc: float = m.s * grow * (maxf(0.0, 1.0 - m.spawn * 1.6) if m.spawn > 0.0 else 1.0)
	if sc <= 0.0:
		return
	var w := float(m.def.w) * sc
	var h := float(m.def.h) * sc
	var shade := maxf(0.25, 1.0 - alt / 900.0)
	_ellipse(l, m.p, w * 0.34 * shade, (w * 0.1 + 4.0) * shade, Color(0, 0, 0, 0.45 * shade))
	var glow := _glow(m)
	var look := _pose(m, Color(1, 1, 1, m.alpha))
	var tint: Color = look[1]
	if glow > 0.0:
		tint = Color(1.0 + glow * 1.8, 1.0 + glow * 1.3, 1.0 + glow * 0.8, 1.0)
	if m.has("echo"):
		tint = Color(0.95, 0.6, 1.9, 0.55 + 0.15 * sin(g.state.t * 9.0 + m.seed))
	# Ignaroth's part rig (src/hell/drake_rig_host.gd): size from spawn/new-form growth, tint (glow, echo violet),
	# altitude in the feet, sink 0..1 cuts him at the floor; it hands the glow record to story_glow itself.
	# The atlas otherwise.
	if rig_host != null and rig_host.draws(m):
		rig_host.draw(l, m, m.p + Vector2(0, 4.0 - alt), sc / m.s, tint, m.sink, look[0])
	else:
		_mark(m, m.p + Vector2(0, 4.0 - alt), sc, m.sink * h, tint, look[0])
		_sprite(l, m.id, Rules.frame_of(m.def, m.anim, m.at), m.p + Vector2(0, 4.0 - alt), sc, m.face, tint, m.sink * h, look[0])
	if m.sink > 0.0 and m.sink < 1.0:
		_draw_mound(l, m)


## Glow hook (src/hero/story_glow.gd): where this frame draws the body of `who`
## (a monster or a corpse): feet, size, source grid, facing, lean, sink cut, alpha,
## so its glowing parts (assets/data/vfx_glow.json "story") follow it. The record
## stays with story_glow (keyed by the body), not in the world's dictionary.
func _mark(who: Dictionary, foot: Vector2, sc: float, cut: float, tint: Color, pose: Dictionary) -> void:
	if g.get("story_glow") == null:
		return
	var def: Dictionary = defs[who.id]
	var squash: Vector2 = pose.get("scale", Vector2.ONE)
	g.story_glow.mark(who, {"foot": foot.round(), "size": Vector2(float(def.w) * sc * squash.x, float(def.h) * sc * squash.y), "src": Vector2(float(def.w), float(def.h)),
		"face": float(who.face), "lean": float(pose.get("lean", 0.0)), "cut": cut, "alpha": tint.a})


func _glow(m: Dictionary) -> float:
	if m.trans != null:
		return float(m.trans.glow)
	if m.dying != null:
		return float(m.dying.glow)
	return 0.0


## Dust mound of a burrowed dragon, drawn on the floor.
func _draw_mound(l: CanvasItem, m: Dictionary) -> void:
	var t: float = g.state.t
	var r: float = m.r * 0.9
	var bob := sin(t * 18.0) * 3.0
	_ellipse(l, m.p + Vector2(0, 4), r * 1.1, r * 0.4, Color(0, 0, 0, 0.4))
	for part: Array in [[Vector2(0, -6 + bob), r, r * 0.38, Color("#3b3332")], [Vector2(-r * 0.2, -10 + bob), r * 0.55, r * 0.2, Color("#483b3a")]]:
		var pts := PackedVector2Array()
		for k in range(17):
			var a := PI + k / 16.0 * PI
			pts.append(m.p + part[0] + Vector2(cos(a) * part[1], sin(a) * part[2]))
		l.draw_colored_polygon(pts, part[3])
	for k in range(4):
		var x: float = m.p.x + sin(t * 5.0 + k * 1.7) * r * 0.7
		l.draw_rect(Rect2(x - 3, m.p.y - 8 - (k % 2) * 6 + bob, 6, 4), Color(1, 0.6, 0.25, 0.8))


## Draws a crumbling dead monster.
func draw_corpse(l: CanvasItem, c: Dictionary) -> void:
	# a dead form of Ignaroth keeps falling apart in his rig, fading; its glow goes to story_glow (src/hell/drake_rig_host.gd)
	if rig_host != null and rig_host.draw_corpse(l, c):
		return
	var def: Dictionary = defs[c.id]
	var n := int(def.anims.death.frames)
	var fr := Vector2i(mini(n - 1, int(c.t / 0.75 * n)), int(def.anims.death.row))
	_mark(c, c.p + Vector2(0, 4), c.s, 0.0, Color.WHITE, {})
	_sprite(l, c.id, fr, c.p + Vector2(0, 4), c.s, c.face, Color.WHITE)


## Floor warnings: where an attack will land, drawn under the actors.
func draw_warnings(l: CanvasItem) -> void:
	for z: Dictionary in zones:
		var k := clampf(z.t / z.tele, 0.0, 1.0) if z.tele > 0.0 else 1.0
		match String(z.kind):
			"meteor", "hand":
				if z.t >= 0.0 and z.t < z.tele:
					_ring(l, z.p, z.r, k, Color8(170, 80, 255) if z.kind == "hand" or z.get("void", false) else _warn_col(str(z.get("c", "")), Color8(255, 90, 30)))
			"erupt", "land":
				if z.t < z.tele:
					_ring(l, z.p, z.r, k, Color8(255, 60, 30) if z.kind == "land" else Color8(255, 140, 40))
			"puddle":
				# a physics pool on the floor layer (hell_game.pools) when there is one
				if g.get("pools") == null and str(z.get("st", "lava")) == "lava":
					_px_pool(l, z.p, z.r, z.r * 0.55, minf(1.0, (z.T - z.t) * 1.5), float(g.state.t))
			"line":
				if z.t < z.tele:
					_px_strip(l, z.p, Vector2.from_angle(float(z.ang)), float(z.len), float(z.w) / 2.0, k, _warn_col(str(z.get("c", "")), Color8(255, 70, 30)))
			"cone":
				if z.t < z.tele:
					_px_cone(l, z.p, float(z.r), float(z.ang), float(z.arc), k, Color8(194, 120, 208))
	_draw_cracks(l)
	_draw_spills(l, float(g.state.t))
	for L: Dictionary in lobs:
		var k: float = L.t / L.T
		_ring(l, L.to, L.r, k, _warn_col(str(L.c), Color8(255, 140, 40)))
		# its shadow on the floor, growing as it falls
		var under: Vector2 = (L.from as Vector2).lerp(L.to, k)
		var sh := 1.0 + 2.0 * (1.0 - sin(k * PI))
		_ellipse(l, under, sh * LASER_PX, sh * LASER_PX * 0.5, Color(0, 0, 0, 0.35))
	for m: Dictionary in g.mobs:
		var A = m.act
		if A == null:
			continue
		if A.kind == "dash" and A.get("warn", false):
			_pixel_lane(l, m.p - Vector2(0, 10), A.dir, float(A.a.get("range", 500.0)), float(m.r) * 0.8, float(A.t))
		if A.kind == "slam" and A.n == 0 and A.has("warn_at"):
			if A.a.get("line", false):
				# a cleave: its strip points at the hero while it is raised
				var aim: Vector2 = (_me() - (m.p as Vector2)).normalized()
				_px_strip(l, m.p, aim, float(A.a.radius) * 2.6, 35.0, minf(1.0, A.t / 0.75), _warn_col(own_element(m), Color8(255, 70, 30)))
			else:
				_ring(l, A.warn_at, float(A.a.radius), minf(1.0, A.t / 0.75), _warn_col(own_element(m), Color8(255, 70, 30)))
		if A.kind == "beam" and A.get("warn", false):
			# from the drawn core, like their damage (src/hell/drake_rig_host.gd)
			var head := _beam_head(m)
			for b: float in A.beams:
				if str(A.a.get("style", "")) == "laser":
					_pixel_aim(l, head, b, _wall_len(head, b, float(A.a.get("range", 1100.0))), float(A.t), float(A.t) >= float(A.a.get("track", 0.0)))
				else:
					l.draw_dashed_line(head, head + Vector2.from_angle(b) * 1000.0, Color(0.78, 0.47, 1, 0.55), 4.0, 10.0)


## The fired pixel lasers ("style": "laser" beams) in their own colours, drawn
## by hell_game.gd over the actors; their soft glow is the crypt's bloom
## (src/hero/story_glow.gd laser_*).
func draw_lasers(l: CanvasItem) -> void:
	var t := float(g.state.t)
	for s: Dictionary in scorches:
		_draw_scorch(l, s, t)
	# lobs in their arc: a boulder or a pixel fireball
	for L: Dictionary in lobs:
		var k: float = L.t / L.T
		var at: Vector2 = (L.from as Vector2).lerp(L.to, k) - Vector2(0, sin(k * PI) * 220.0)
		var vel: Vector2 = ((L.to as Vector2) - (L.from as Vector2)) / maxf(0.01, float(L.T)) - Vector2(0, cos(k * PI) * PI * 220.0 / maxf(0.01, float(L.T)))
		if str(L.get("look", "")) == "boulder":
			_px_boulder(l, at, vel, t, float(int(L.to.x) % 17))
		else:
			_px_missile(l, at, 3, str(L.c), vel, t, float(int(L.to.x) % 17))
	# the enemy shots: pixel fireballs, a chain as links back to its thrower
	for s: Dictionary in g.eshots:
		var c := str(s.get("c", "fire"))
		if s.has("chain"):
			var from: Vector2 = s.chain.p - Vector2(0, s.chain.cy)
			var span: Vector2 = (s.p as Vector2) - from
			var links := int(span.length() / (LASER_PX * 3.0))
			for i in range(links):
				_px(l, from + span * float(i) / float(maxi(1, links)), PX_COL.chain[2 if i % 2 == 0 else 1])
		if str(s.get("look", "")) in ["wisp", "tear"]:
			_px_wisp(l, s.p, PX_COL.get(c, PX_COL.soul), s.get("hist", []), t, float(hash(s.get("v", Vector2.ZERO)) % 17), str(s.get("look", "")) == "wisp")
		else:
			_px_missile(l, s.p, 2 if s.get("small", false) else 3, c, s.get("v", Vector2.ZERO), t, float(hash(s.get("v", Vector2.ZERO)) % 17))
	# the swings' pixel slashes; slag raining down as pixel blobs with a dripping trail
	for z: Dictionary in zones:
		if str(z.kind) == "arc" and float(z.arc) >= 5.0:
			_px_slash(l, z, t)
		if str(z.kind) == "meteor" and str(z.get("look", "")) == "slag" and float(z.t) >= 0.0 and float(z.t) < float(z.tele):
			var fall := 900.0 / maxf(0.05, float(z.tele))
			var at := Vector2(z.p.x, z.p.y - 900.0 * (1.0 - float(z.t) / float(z.tele)))
			_px_ball(l, at, 3, PX_COL.lava, Vector2(0, fall), t, float(int(z.p.x) % 17))
	# the walls of flames out of split floors
	for w: Dictionary in firewalls:
		_draw_firewall(l, w, t)
	# a scream's sound waves, grave hands reaching out of the floor
	for z: Dictionary in zones:
		if str(z.kind) == "cone" and float(z.t) >= float(z.tele):
			_px_sound(l, z, t)
		elif str(z.kind) == "hand" and float(z.t) >= float(z.tele):
			_px_hand(l, z, t)
	# the impacts' white-hot flashes
	for f: Dictionary in flashes:
		_draw_flash(l, f)
	# chunks and sparks in the air
	for f: Dictionary in pfx:
		var a := 1.0 - clampf((float(f.t) / float(f.T) - 0.7) / 0.3, 0.0, 1.0)
		var col: Color = f.c
		_px(l, (f.p as Vector2) - Vector2(0, float(f.z)), Color(col, col.a * a), int(f.s))
	for m: Dictionary in g.mobs:
		var A = m.act
		if A == null or A.kind != "beam" or A.get("warn", false):
			continue
		var head := _beam_head(m)
		var life := (float(A.t) - 0.8) / maxf(0.05, float(A.a.get("duration", 1.0)))
		var laser := str(A.a.get("style", "")) == "laser"
		for b: float in A.beams:
			if laser:
				_pixel_laser(l, head, b, _beam_reach(head, b, float(A.a.get("range", 1100.0))), t, life)
			else:
				# a void beam: as wide as its old band, on the pixel grid, opaque
				_pixel_laser(l, head, b, _wall_len(head, b, float(A.a.get("range", 1100.0))), t, life, VOID_BEAM_COL, 3, true)


## A laser's aim on the pixel grid: every fourth laser pixel lit, crawling
## outward from the shooter and blinking, faster once the aim is locked.
func _pixel_aim(l: CanvasItem, from: Vector2, ang: float, length: float, t: float, locked: bool) -> void:
	if fmod(t * (9.0 if locked else 4.0), 1.0) > 0.65:
		return
	var dir := Vector2.from_angle(ang)
	var crawl := int(floorf(t * LASER_FPS))
	for i in range(int(length / LASER_PX)):
		if posmod(i - crawl, 4) != 0:
			continue
		var c := ((from + dir * float(i) * LASER_PX) / LASER_PX).floor() * LASER_PX
		l.draw_rect(Rect2(c, Vector2(LASER_PX, LASER_PX)), Color(LASER_COL[1] if locked else LASER_COL[2], 0.9))


## A fired laser on the pixel grid, three laser pixels wide: square blocks
## stepped along the line (each snapped to LASER_PX), a red edge flickering
## crimson and dropping out now and then at LASER_FPS, a yellow core with white
## pulses running outward. At its end (`life` 0..1) only the core is left.
## A few sparks crackle at the muzzle. A beam of void (`swallows`) runs the
## other way: its pulses run back up its dark core to the source, and sparks
## beside it are drawn in and vanish in it.
func _pixel_laser(l: CanvasItem, from: Vector2, ang: float, length: float, t: float, life: float, cols: Array = LASER_COL, wide := 1, swallows := false) -> void:
	var dir := Vector2.from_angle(ang)
	var tq := floorf(t * LASER_FPS)
	var steps := int(length / LASER_PX)
	var edge := life <= 0.85
	var block := func(p: Vector2, half: int, col: Color) -> void:
		var c := (p / LASER_PX).floor() * LASER_PX - Vector2(half, half) * LASER_PX
		l.draw_rect(Rect2(c, Vector2(2 * half + 1, 2 * half + 1) * LASER_PX), col)
	if edge:
		for i in range(steps):
			var n := sin(float(i) * 1.7 + tq * 2.3) + sin(float(i) * 0.61 - tq * 1.3)
			if n < -1.4:
				continue
			if wide > 1:
				block.call(from + dir * (float(i) * LASER_PX), wide, cols[4] if cols.size() > 4 else cols[3])
			block.call(from + dir * (float(i) * LASER_PX), wide - 1 if wide > 1 else 1, cols[3] if n > 1.0 else cols[2])
	var flow := -1 if swallows else 1
	for i in range(steps):
		block.call(from + dir * (float(i) * LASER_PX), maxi(0, wide - 2), cols[0] if posmod(i - flow * int(tq) * 3, 7) == 0 else cols[1])
	if swallows and edge:
		# sparks beside it drawn in, each over a short while (no state: by the clock)
		var across := dir.orthogonal()
		for j in range(8):
			var run := t * 2.5 + float(j) * 0.37
			var phase := fmod(run, 1.0)
			var cycle := int(floor(run))
			var along := float(posmod(cycle * 7919 + j * 104729, 997)) / 997.0 * float(steps) * LASER_PX
			var side := (1.0 if posmod(cycle + j, 2) == 0 else -1.0) * float(wide + 6) * LASER_PX * (1.0 - phase)
			block.call(from + dir * along + across * side, 0, cols[2] if phase < 0.7 else cols[3])
	for k in range(3):
		var ang_k := float(k) * 2.1 + tq * 0.9
		block.call(from + Vector2(cos(ang_k), sin(ang_k)) * LASER_PX * float(1 + (k + int(tq)) % 2), 0, cols[k % 2])


## One block of the pixel grid, `size` laser pixels wide, at world point `p`.
func _px(l: CanvasItem, p: Vector2, col: Color, size: int = 1) -> void:
	l.draw_rect(Rect2((p / LASER_PX).floor() * LASER_PX, Vector2.ONE * LASER_PX * float(size)), col)


## An ellipse outline on the pixel grid: one block per grid step along it, every
## `every`-th block (crawling with `phase`); `broken` 0..1 drops that share of
## the blocks, flickering at LASER_FPS (a ring breaking up as it spreads).
func _px_ellipse(l: CanvasItem, c: Vector2, rx: float, ry: float, col: Color, every: int = 1, phase: int = 0, broken: float = 0.0, t: float = 0.0) -> void:
	if rx < LASER_PX or ry <= 0.0:
		return
	var n := maxi(12, int(TAU * maxf(rx, ry) / LASER_PX))
	var last := Vector2i(1 << 30, 0)
	var tq := floorf(t * LASER_FPS)
	for k in range(n):
		if every > 1 and posmod(k + phase, every) != 0:
			continue
		var a := float(k) / float(n) * TAU
		var q := Vector2i(((c + Vector2(cos(a) * rx, sin(a) * ry)) / LASER_PX).floor())
		if q == last:
			continue
		last = q
		if broken > 0.0 and 0.5 + 0.5 * sin(float(k) * 2.7 + tq * 1.9) < broken:
			continue
		l.draw_rect(Rect2(Vector2(q) * LASER_PX, Vector2.ONE * LASER_PX), col)


## An impact at moment `k` (0..1) on the pixel grid: one ragged mass of fire
## (the union of a few lobes with a noisy rim), white-hot only in its middle
## and early, cooling outward to crimson, outlined; dark smoke clumps rising
## off its top that thin out by the dither as it ends; embers flung out.
func _px_burst(l: CanvasItem, c: Vector2, r: float, k: float, cols: Array, seed: float) -> void:
	var at := Vector2i((c / LASER_PX).floor())
	var R := r / LASER_PX * (0.75 + 0.45 * k)
	var lobes := [[0.0, 0.0, 0.62], [-0.45, -0.2, 0.42], [0.5, -0.15, 0.4], [-0.2, 0.42, 0.38], [0.35, 0.4, 0.36], [0.05, -0.55, 0.34]]
	var m := {}
	for y in range(-int(R) - 3, int(R) + 4):
		for x in range(-int(R) - 3, int(R) + 4):
			var p := Vector2(x, y) / maxf(1.0, R)
			for lb: Array in lobes:
				var rim := float(lb[2]) * (1.0 + 0.22 * (_px_noise(x, y, int(seed)) - 0.5))
				if p.distance_to(Vector2(float(lb[0]), float(lb[1]))) <= rim:
					m[at + Vector2i(x, y)] = p.length()
					break
	var smoke := {}
	for i in range(5):
		var a := PI + PI * (0.15 + 0.7 * float(i) / 4.0)
		var sc := at + Vector2i(int(cos(a) * R * 0.8), int(sin(a) * R * 0.7 - R * 0.25 * k))
		var sr := R * (0.28 + 0.06 * float(i % 2)) * (0.8 + 0.6 * k)
		for y in range(-int(sr) - 1, int(sr) + 2):
			for x in range(-int(sr) - 1, int(sr) + 2):
				if Vector2(x, y).length() <= sr * (1.0 + 0.25 * (_px_noise(x, y, 30 + i) - 0.5)):
					var q := sc + Vector2i(x, y)
					if not m.has(q) and float(BAYER[posmod(q.y, 4) * 4 + posmod(q.x, 4)]) < (1.0 - k * 0.6) * 16.0:
						smoke[q] = y < -int(sr * 0.3)
	for q: Vector2i in smoke:
		l.draw_rect(Rect2(Vector2(q) * LASER_PX, Vector2.ONE * LASER_PX), Color("5a4656") if smoke[q] else Color("3b2a35"))
	for q: Vector2i in m:
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if not m.has(q + d) and not smoke.has(q + d):
				l.draw_rect(Rect2(Vector2(q + d) * LASER_PX, Vector2.ONE * LASER_PX), OUTLINE)
	for q: Vector2i in m:
		var heat: float = float(m[q]) + 0.25 * (_px_noise(q.x, q.y, 9) - 0.5) + k * 0.45
		var col: Color = cols[0] if heat < 0.18 else cols[1] if heat < 0.42 else cols[2] if heat < 0.68 else cols[3] if heat < 0.88 else cols[3].darkened(0.3)
		l.draw_rect(Rect2(Vector2(q) * LASER_PX, Vector2.ONE * LASER_PX), col)
	for i in range(9):
		var a := TAU * float(i) / 9.0 + 0.4
		var e := at + Vector2i(int(cos(a) * R * (1.15 + k)), int(sin(a) * R * (1.15 + k) * 0.8))
		l.draw_rect(Rect2(Vector2(e) * LASER_PX, Vector2.ONE * LASER_PX), cols[1] if i % 2 == 0 else cols[2])


## Smooth value noise 0..1 over cells of 2 pixels.
func _px_noise(x: int, y: int, s: int) -> float:
	var fx := float(x) / 2.0
	var fy := float(y) / 2.0
	var gx := floori(fx)
	var gy := floori(fy)
	var u := fx - float(gx)
	var v := fy - float(gy)
	u = u * u * (3.0 - 2.0 * u)
	v = v * v * (3.0 - 2.0 * v)
	var h := func(a: int, b: int) -> float: return float(absi((a * 73856093) ^ (b * 19349663) ^ (s * 83492791)) % 1000) / 1000.0
	return lerpf(lerpf(h.call(gx, gy), h.call(gx + 1, gy), u), lerpf(h.call(gx, gy + 1), h.call(gx + 1, gy + 1), u), v)


## A shot or lob on the pixel grid: a ball of `r` pixels (of the old 4 px
## grid, PX_GROW) from a white-hot core (one or two pixels only) to its edge
## colour (`cols`: PX_COL), outlined in OUTLINE; flying, three stepped flame
## tongues stream back from it against `vel`, their lengths flickering at
## LASER_FPS, cooling to the edge colour and crimson, and embers trail it.
## Opaque: no soft trail, the bloom over it stays small (story_glow.gd).
func _px_ball(l: CanvasItem, p: Vector2, r: int, cols: Array, vel: Vector2, t: float, seed: float) -> void:
	r = maxi(1, int(round(float(r) * PX_GROW)))
	var tq := floorf(t * LASER_FPS)
	var at := Vector2i((p / LASER_PX).floor())
	var m := {}
	for y in range(-r, r + 1):
		for x in range(-r, r + 1):
			if Vector2(x, y).length() <= float(r) + 0.4:
				m[at + Vector2i(x, y)] = Vector2(x, y).length() / float(r)
	var tail_col: Color = cols[3].darkened(0.25)
	if vel.length() > 1.0:
		var back := -vel.normalized()
		var side := back.orthogonal()
		for f in range(-1, 2):
			var length := r * 2 + 2 + int(2.0 * sin(tq * 1.9 + float(f) * 2.3 + seed)) - absi(f) * 2
			for i in range(1, length):
				var k := float(i) / float(length)
				var w := maxi(0, int(round((1.0 - k) * float(r - 1) * (0.8 if f == 0 else 0.5))))
				var c := p + back * float(i + r - 1) * LASER_PX + side * float(f) * LASER_PX * float(r) * 0.8 * (1.0 - k * 0.3)
				for o in range(-w, w + 1):
					var q := Vector2i(((c + side * float(o) * LASER_PX) / LASER_PX).floor())
					if not m.has(q):
						m[q] = 1.0 + k
	for q: Vector2i in m:
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if not m.has(q + d):
				l.draw_rect(Rect2(Vector2(q + d) * LASER_PX, Vector2.ONE * LASER_PX), OUTLINE)
	for q: Vector2i in m:
		var d: float = m[q]
		var col: Color = cols[0] if d < 0.3 else cols[1] if d < 0.72 else cols[2] if d < 1.3 else cols[3] if d < 1.65 else tail_col
		l.draw_rect(Rect2(Vector2(q) * LASER_PX, Vector2.ONE * LASER_PX), col)
	if vel.length() > 1.0:
		var back := -vel.normalized()
		for i in range(3):
			if sin(tq * 2.0 + float(i) * 1.3 + seed) > -0.2:
				var e := p + back * float(r * 4 + i * 5) * LASER_PX + back.orthogonal() * LASER_PX * 3.0 * sin(float(i) * 2.7 + tq * 0.8)
				l.draw_rect(Rect2((e / LASER_PX).floor() * LASER_PX, Vector2.ONE * LASER_PX), cols[1] if i < 2 else cols[2])


## A burst at `at` in element `c`: the world's embers (g._burst) for fire and
## the hell's elements, `n` / 2 pixels of the element for the crypt's own.
## A breath's cloud (element_rules.json breath_gas: poison and frost their own,
## fire and lava smoke): where the breath went, as wide as breath_r of its
## range, drifting on along the breath for breath_time s; the hero and the
## monsters breathe it (element_rules.json gases).
func _breath_cloud(m: Dictionary, element: String, mouth: Vector2, aim: Vector2, reach: float) -> void:
	var gas: RefCounted = g.get("gas")
	var rules := ElementRules.data()
	var mat := str(rules.get("breath_gas", {}).get(element, ""))
	if gas == null or mat == "":
		return
	var dir := (aim - mouth).normalized() if aim.distance_to(mouth) > 1.0 else Vector2.RIGHT
	# where the breath went: at its aim (the hero's feet then), drawn a little back towards the mouth
	var at := (aim + Vector2(0, 30)).lerp(mouth, 0.2)
	var time := float(rules.get("breath_time", 3.5)) * (1.3 if m.boss else 1.0)
	gas.emit("breath:%d:%d" % [int(m.get("uid", 0)), int(g.state.t * 10.0)], mat, at, reach * float(rules.get("breath_r", 0.3)) * (1.3 if m.boss else 1.0), time, float(g.state.t), dir * 30.0, 0.9)


## An attack of element `c` landing at `at` reaching `r` meets what lies there
## (src/hell/story_elements.gd: fire sets poison off and boils water, frost
## freezes water); nothing in a world without the reactions.
func _react(c: String, at: Vector2, r: float) -> void:
	var reactions: RefCounted = g.get("story_elements")
	if reactions != null and c != "":
		reactions.touch(c, at, r)


func _burst_in(at: Vector2, n: int, c: String) -> void:
	if c in CRYPT_ELEMENTS:
		_pixel_burst(at, maxi(4, n / 2), PX_COL[c], 260.0, 340.0, 0.7)
	else:
		g._burst(at, n)


## A shot of element `c` landing at `at` (a wall, the hero): a white-hot flash
## frame, a burst of its element's pixels that fly, fall and settle, and the
## small impact feel; its residue on the floor below follows in update_shots.
## No sheet animation: the fireball ends as matter (user decision 2026-10-31).
func _shot_impact(at: Vector2, c: String, small: bool) -> void:
	var cols: Array = PX_COL.get(c, PX_COL.fire)
	flashes.append({"p": at, "t": 0.0, "T": 0.1, "r": 14.0 if small else 22.0, "c": c if c in CRYPT_ELEMENTS else "fire"})
	_pixel_burst(at, 6 if small else 12, cols, 200.0, 260.0, 0.75)
	_impact(at, "small")


## A warning's colour for element `c`: the element's middle tone for the crypt's
## own elements, else `fallback` (the hell's orange and red).
static func _warn_col(c: String, fallback: Color) -> Color:
	return PX_COL[c][2] if c in CRYPT_ELEMENTS else fallback


## A figure's own element: its def's "shot" when that is one of OWN_ELEMENTS
## (the crypt's figures), "" for the hell's (their attacks stay fire).
static func own_element(m: Dictionary) -> String:
	var def: Variant = m.get("def")
	var element := str((def as Dictionary).get("shot", "")) if def is Dictionary else ""
	return element if element in OWN_ELEMENTS else ""


## A shot, lob or falling block of element `c` on the pixel grid in its
## element's shape: a bone tumbling end over end, an ice shard, a gold coin
## turning, a dripping glob of poison; fire, lava, void and soul as the
## flaming pixel ball (_px_ball). `r` its size as _px_ball takes it.
func _px_missile(l: CanvasItem, p: Vector2, r: int, c: String, vel: Vector2, t: float, seed: float) -> void:
	match c:
		"bone": _px_bone(l, p, r, PX_COL.bone, vel, t, seed)
		"frost": _px_shard(l, p, r, PX_COL.frost, vel, t, seed)
		"gold": _px_coin(l, p, r, PX_COL.gold, vel, t, seed)
		"poison": _px_glob(l, p, r, PX_COL.poison, vel, t, seed)
		_: _px_ball(l, p, r, PX_COL.get(c, PX_COL.fire), vel, t, seed)


## Grid cells (Vector2i -> Color) drawn opaque with an OUTLINE round them.
func _px_flush(l: CanvasItem, cells: Dictionary) -> void:
	for q: Vector2i in cells:
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if not cells.has(q + d):
				l.draw_rect(Rect2(Vector2(q + d) * LASER_PX, Vector2.ONE * LASER_PX), OUTLINE)
	for q: Vector2i in cells:
		l.draw_rect(Rect2(Vector2(q) * LASER_PX, Vector2.ONE * LASER_PX), cells[q])


## A thrown bone: a shaft with a knuckle on each side of both ends, tumbling
## an eighth of a turn per beat (LASER_FPS), and bone dust falling behind it.
func _px_bone(l: CanvasItem, p: Vector2, r: int, cols: Array, vel: Vector2, t: float, seed: float) -> void:
	var n := maxi(2, int(round(float(r) * PX_GROW)))
	var tq := floorf(t * LASER_FPS)
	var dir := Vector2.from_angle(tq * PI / 4.0 + seed)
	var side := dir.orthogonal()
	var at := Vector2i((p / LASER_PX).floor())
	var cells := {}
	for i in range(-n + 1, n):
		cells[at + Vector2i((dir * float(i)).round())] = cols[1]
	for end: float in [-1.0, 1.0]:
		var e := at + Vector2i((dir * float(n) * end).round())
		cells[e] = cols[0]
		cells[e + Vector2i((side * 1.2).round())] = cols[2]
		cells[e - Vector2i((side * 1.2).round())] = cols[1]
	_px_flush(l, cells)
	if vel.length() > 1.0:
		var back := -vel.normalized()
		for i in range(2):
			if posmod(int(tq) + i, 2) == 0:
				var e := p + back * float(n + 2 + i * 3) * LASER_PX + Vector2(0, float(i + 1) * LASER_PX)
				l.draw_rect(Rect2((e / LASER_PX).floor() * LASER_PX, Vector2.ONE * LASER_PX), cols[3])


## An ice shard flying point first: a long diamond with a white ridge, lit on
## one flank and shaded on the other, frost glints blinking behind it.
func _px_shard(l: CanvasItem, p: Vector2, r: int, cols: Array, vel: Vector2, t: float, seed: float) -> void:
	var n := maxi(2, int(round(float(r) * PX_GROW)))
	var dir := vel.normalized() if vel.length() > 1.0 else Vector2.RIGHT
	var side := dir.orthogonal()
	var front := n + 1
	var back := n * 2
	var cells := {}
	for i in range(-back, front + 1):
		var k := float(i) / float(front) if i >= 0 else -float(i) / float(back)
		var w := int(round((1.0 - k) * float(n) * 0.5))
		for o in range(-w, w + 1):
			var q := Vector2i(((p + (dir * float(i) + side * float(o)) * LASER_PX) / LASER_PX).floor())
			var col: Color = cols[1]
			if o == 0: col = cols[0] if i > -back / 2 else cols[1]
			elif o > 0: col = cols[3] if o == w else cols[2]
			cells[q] = col
	_px_flush(l, cells)
	var tq := floorf(t * LASER_FPS)
	for i in range(3):
		if posmod(int(tq) + i + int(seed), 3) != 0:
			var e := p - dir * float(back + 2 + i * 2) * LASER_PX + side * sin(float(i) * 2.1 + tq * 0.9) * LASER_PX * 1.5
			l.draw_rect(Rect2((e / LASER_PX).floor() * LASER_PX, Vector2.ONE * LASER_PX), cols[0] if i == 0 else cols[1])


## A gold coin turning as it flies (full face to its edge on the beat), its
## rim darker, a glint on its face, gold specks trailing it.
func _px_coin(l: CanvasItem, p: Vector2, r: int, cols: Array, vel: Vector2, t: float, seed: float) -> void:
	var n := maxi(2, int(round(float(r) * PX_GROW * 0.7)))
	var tq := floorf(t * LASER_FPS)
	var face := absf(cos(tq * 0.6 + seed))
	var rx := maxf(0.5, float(n) * face)
	var at := Vector2i((p / LASER_PX).floor())
	var cells := {}
	for y in range(-n, n + 1):
		for x in range(-n, n + 1):
			var e := Vector2(float(x) / (rx + 0.4), float(y) / (float(n) + 0.4))
			if e.length() > 1.0:
				continue
			var col: Color = cols[2]
			if e.length() > 0.72: col = cols[3]
			elif x <= 0 and y < 0: col = cols[1]
			cells[at + Vector2i(x, y)] = col
	if face > 0.55 and posmod(int(tq + seed), 4) == 0:
		cells[at + Vector2i(-1, -1)] = cols[0]
	_px_flush(l, cells)
	if vel.length() > 1.0:
		var back := -vel.normalized()
		for i in range(3):
			if posmod(int(tq) + i, 3) != 1:
				var e := p + back * float(n * 2 + 2 + i * 3) * LASER_PX + back.orthogonal() * LASER_PX * 2.0 * sin(float(i) * 2.7 + tq)
				l.draw_rect(Rect2((e / LASER_PX).floor() * LASER_PX, Vector2.ONE * LASER_PX), cols[1] if i == 0 else cols[2])


## A glob of poison: a round blob lit from the upper left, a drop hanging
## under it, drops falling off behind it on the beat.
func _px_glob(l: CanvasItem, p: Vector2, r: int, cols: Array, vel: Vector2, t: float, seed: float) -> void:
	var n := maxi(1, int(round(float(r) * PX_GROW)))
	var at := Vector2i((p / LASER_PX).floor())
	var cells := {}
	for y in range(-n, n + 1):
		for x in range(-n, n + 1):
			if Vector2(x, y).length() > float(n) + 0.4:
				continue
			var lit := Vector2(float(x) + float(n) * 0.4, float(y) + float(n) * 0.4).length() / float(n)
			cells[at + Vector2i(x, y)] = cols[0] if lit < 0.35 else cols[1] if lit < 0.8 else cols[2] if lit < 1.25 else cols[3]
	cells[at + Vector2i(0, n + 1)] = cols[2]
	_px_flush(l, cells)
	if vel.length() > 1.0:
		var back := -vel.normalized()
		var tq := floorf(t * LASER_FPS)
		for i in range(3):
			var k := fposmod(tq * 0.34 + float(i) * 0.33 + seed * 0.1, 1.0)
			var e := p + back * float(n * 2 + 2 + i * 3) * LASER_PX + Vector2(0, k * 5.0 * LASER_PX)
			var q := (e / LASER_PX).floor() * LASER_PX
			l.draw_rect(Rect2(q + Vector2(0, LASER_PX), Vector2.ONE * LASER_PX), OUTLINE)
			l.draw_rect(Rect2(q, Vector2.ONE * LASER_PX), cols[2] if i < 2 else cols[3])


## A lost soul on the pixel grid (a shot's "look": "wisp", the Seelenhirte's
## herd), gaseous rather than solid: a round head, white-hot at its heart and
## cooling to its colour's edge, and a tail of gas streaming along the path it
## flew (`hist`, oldest first): one unbroken band that narrows from the head's
## width to a thread, fades out towards its end and wavers sideways as it goes.
## `cols`: PX_COL, white-hot to edge.
func _px_wisp(l: CanvasItem, p: Vector2, cols: Array, hist: Array, t: float, seed: float, eyes := true) -> void:
	var tq := floorf(t * LASER_FPS)
	var path: Array = hist.duplicate()
	path.append(p)
	var n := path.size()
	# the tail: discs swept along the path in half-pixel steps, each grid cell
	# kept once at its hottest (nearest the head), so the band is filled and smooth
	if n >= 2:
		var total := 0.0
		for i in range(1, n):
			total += (path[i] as Vector2).distance_to(path[i - 1])
		var cells := {}
		var walked := 0.0
		for i in range(1, n):
			var a: Vector2 = path[i - 1]
			var b: Vector2 = path[i]
			var seg := a.distance_to(b)
			var side := (b - a).normalized().orthogonal() if seg > 0.01 else Vector2.ZERO
			var steps := maxi(1, int(seg / (LASER_PX * 0.5)))
			for s in range(steps):
				var k := 1.0 - (walked + seg * float(s) / float(steps)) / maxf(1.0, total)
				var c := a.lerp(b, float(s) / float(steps)) + side * sin(k * 7.0 - t * 9.0 + seed) * k * 1.4 * LASER_PX
				var half := maxf(0.4, (1.0 - k) * 2.4)
				var hi := int(ceil(half)) + 1
				var g := Vector2i((c / LASER_PX).floor())
				for gy in range(-hi, hi + 1):
					for gx in range(-hi, hi + 1):
						var cell := g + Vector2i(gx, gy)
						var d := ((Vector2(cell) + Vector2(0.5, 0.5)) * LASER_PX).distance_to(c) / LASER_PX / (half + 0.5)
						if d > 1.0:
							continue
						var prev: Variant = cells.get(cell)
						if prev == null or k < float(prev[0]):
							cells[cell] = [k, d]
			walked += seg
		for cell: Vector2i in cells:
			var k := float(cells[cell][0])
			var d := float(cells[cell][1])
			# its far end thins into wisps
			if k > 0.6 and sin(float(cell.x * 7 + cell.y * 13) + tq * 1.3 + seed) > 1.6 - k * 1.4:
				continue
			var col: Color = cols[1] if d < 0.4 and k < 0.55 else (cols[2] if d < 0.75 else cols[3])
			l.draw_rect(Rect2(Vector2(cell) * LASER_PX, Vector2.ONE * LASER_PX), Color(col, (1.0 - k * 0.85) * 0.95))
	# the head: a round glow, its heart white-hot and a little forward
	var heart := Vector2.ZERO if n < 2 else ((path[n - 1] as Vector2) - (path[n - 2] as Vector2)).normalized() * 0.6
	for y in range(-3, 4):
		for x in range(-3, 4):
			var d := Vector2(x, y).length() / 3.3
			if d > 1.0:
				continue
			if d > 0.85 and sin(tq * 1.9 + float(x * 3 + y * 5) + seed) > 0.5:
				continue
			var e := (Vector2(x, y) - heart * 2.0 - Vector2(0, -1)).length() / 3.3
			var col: Color = cols[0] if e < 0.3 else (cols[1] if d < 0.62 else (cols[2] if d < 0.85 else cols[3]))
			_px(l, p + Vector2(x, y) * LASER_PX, col)
	# two dark eyes, looking a little the way it flies (a soul; a tear has none)
	if eyes:
		var look := (heart * 1.6).round()
		for ex: int in [-1, 1]:
			_px(l, p + (Vector2(ex, 0) + look) * LASER_PX, WISP_EYE)


## A thrown boulder (BOULDER) on the pixel grid, turned a quarter at a time, with
## a trail of sparks behind it.
func _px_boulder(l: CanvasItem, p: Vector2, vel: Vector2, t: float, seed: float) -> void:
	var tq := floorf(t * LASER_FPS)
	if vel.length() > 1.0:
		var back := -vel.normalized()
		for i in range(2, 9):
			if sin(tq * 2.3 + float(i) * 1.9 + seed) > 0.3:
				continue
			_px(l, p + back * float(i) * LASER_PX * 1.3 + Vector2(sin(float(i) * 3.1 + tq), cos(float(i) * 2.3 + tq)) * LASER_PX, PX_COL.lava[mini(3, i / 2)])
	var turn := int(floorf(t * 8.0 + seed)) % 4
	var size := BOULDER.size()
	var base := (p / LASER_PX).floor() * LASER_PX - Vector2.ONE * float(size / 2) * LASER_PX
	for y in range(size):
		for x in range(size):
			# the pattern turned a quarter `turn` times
			var sx := x if turn == 0 else (y if turn == 1 else (size - 1 - x if turn == 2 else size - 1 - y))
			var sy := y if turn == 0 else (size - 1 - x if turn == 1 else (size - 1 - y if turn == 2 else x))
			var ch := str(BOULDER[sy][sx])
			if not BOULDER_COL.has(ch):
				continue
			var col: Color = BOULDER_COL[ch]
			if ch == "l" and sin(tq * 1.3 + seed) > 0.4:
				col = PX_COL.lava[0]
			l.draw_rect(Rect2(base + Vector2(x, y) * LASER_PX, Vector2.ONE * LASER_PX), col)


## The game feel of an attack's impact at `p` (skill gamedev:game-feel): one
## bundle per importance tier from hell_balance.json monsters.feel (tiny, small,
## medium, large): a smooth view shake, a white-hot pixel flash with its glow,
## and only for the large tier a short hold of the picture (hitstop). `m`'s
## tier: a boss's own, a mob's one step lower, so routine mob attacks stay light.
func _impact(p: Vector2, tier: String, m: Dictionary = {}) -> void:
	var feel_cfg: Dictionary = cfg.get("feel", {}) if cfg.get("feel") is Dictionary else {}
	var order := ["tiny", "small", "medium", "large"]
	var at := order.find(tier)
	if at < 0:
		return
	if not m.is_empty() and not bool(m.get("boss", false)):
		at = maxi(0, at - 1)
	var spec: Dictionary = feel_cfg.get(order[at], {})
	if spec.is_empty():
		return
	var shake := float(spec.get("shake", 0.0)) * float(feel_cfg.get("shake_scale", 1.0))
	if shake > 0.0:
		_shake(shake)
	if float(spec.get("flash", 0.0)) > 0.0:
		# white-hot for the hell's fire; the crypt's own elements flash in theirs
		var element := own_element(m) if not m.is_empty() else ""
		flashes.append({"p": p, "t": 0.0, "T": float(spec.flash), "r": float(spec.get("flash_r", 30.0)), "c": element if element in CRYPT_ELEMENTS else "fire"})
	var hold := float(spec.get("hitstop", 0.0))
	var feel: Variant = g.get("feel")
	if hold > 0.0 and feel != null and feel.get("feedback") != null:
		feel.feedback.hitstop = maxf(float(feel.feedback.hitstop), hold)


## A swing on the pixel grid (an "arc" zone): the blade's path as bands of
## blocks swept from one side of the arc to the other in an eased sweep, white
## at the leading edge, cooling to red behind it and fading; a full circle (the
## ball on its chain) runs once round. Sparks fly off the leading edge.
func _px_slash(l: CanvasItem, z: Dictionary, t: float) -> void:
	var k := clampf(float(z.t) / maxf(0.01, float(z.T)), 0.0, 1.0)
	var arc := float(z.arc)
	var start := float(z.ang) - arc / 2.0
	var lead := start + arc * (1.0 - pow(1.0 - minf(1.0, k * 1.8), 3.0))
	var fade := 1.0 - clampf((k - 0.65) / 0.35, 0.0, 1.0)
	var r := float(z.r)
	var steps := maxi(8, int(arc * r / LASER_PX / 1.5))
	for i in range(steps + 1):
		var a := start + (lead - start) * float(i) / float(steps)
		var behind := 1.0 - float(i) / float(steps)
		var col: Color = PX_COL.fire[0] if behind < 0.08 else PX_COL.fire[1] if behind < 0.25 else PX_COL.fire[2] if behind < 0.55 else PX_COL.fire[3]
		# the blade's band: widest at the leading edge, thinning behind it
		var bands := 4 if behind < 0.25 else (3 if behind < 0.55 else 2)
		for band in range(bands):
			var rr := r * (0.86 - 0.09 * float(band))
			_px(l, (z.p as Vector2) + Vector2(cos(a) * rr, sin(a) * rr * 0.62), Color(col, fade * (1.0 - behind * 0.5)))
	# sparks off the edge while it sweeps
	if k < 0.6 and not z.has("sparked"):
		z.sparked = true
		_pixel_burst((z.p as Vector2) + Vector2(cos(lead), sin(lead) * 0.62) * r * 0.8, 6, PX_COL.fire, 200.0, 140.0, 0.4)


## A white-hot flash on the pixel grid: a disc that shrinks from white through
## yellow to orange over its life.
func _draw_flash(l: CanvasItem, f: Dictionary) -> void:
	var k := clampf(float(f.t) / maxf(0.01, float(f.T)), 0.0, 1.0)
	var cols: Array = PX_COL.get(str(f.get("c", "fire")), PX_COL.fire)
	var r := float(f.r) * (1.0 - k * 0.7)
	var base := ((f.p as Vector2) / LASER_PX).floor() * LASER_PX
	var n := int(ceil(r / LASER_PX))
	for y in range(-n, n + 1):
		for x in range(-n, n + 1):
			var d := Vector2(x, float(y) / 0.62).length() * LASER_PX / maxf(1.0, r)
			if d > 1.0:
				continue
			var col: Color = cols[0] if d < 0.45 - k * 0.3 else cols[1] if d < 0.75 else cols[2]
			l.draw_rect(Rect2(base + Vector2(x, y) * LASER_PX, Vector2.ONE * LASER_PX), Color(col, 1.0 - k * 0.6))


## The crypt's pixel physics (src/vfx/particles.gd, run by the feel in crypt
## units, world px / feel.scale): pixels that fly with gravity, bounce off the
## floor and the walls, settle as floor pixels that later blasts lift again,
## embers that cool and smoke. Null without the feel (then pfx stands in).
func _phys() -> RefCounted:
	var feel: Variant = g.get("feel")
	if feel == null or feel.get("feedback") == null:
		return null
	return feel.feedback.particles


## World px per crypt px of the feel's layers.
func _phys_scale() -> float:
	return maxf(0.1, float(g.feel.scale))


## Pixels flying out of `p`: `n` blocks of `cols`, thrown out at up to `speed`
## world px/s over the floor and `up` px/s into the air; they fall back, bounce
## and settle (`size` 2 and more: chunks that stay on the floor as rubble) or
## glow and fade (sparks). Through the crypt's pixel physics, else pfx.
func _pixel_burst(p: Vector2, n: int, cols: Array, speed: float, up: float, life: float = 0.9, size: int = 1) -> void:
	var P := _phys()
	if P != null:
		var s := _phys_scale()
		for k in range(n):
			var ang := randf() * TAU
			var vel := Vector2(cos(ang), sin(ang) * 0.62) * speed * randf_range(0.35, 1.0) / s
			P.emit(p / s, vel, cols[randi() % cols.size()], life * randf_range(0.7, 1.25) * (2.5 if size >= 2 else 1.0),
				"debris" if size >= 2 else "spark", 2.0 * float(size), randf_range(4.0, 14.0), up * randf_range(0.45, 1.0) / s, 2.5)
		return
	for k in range(n):
		var ang := randf() * TAU
		var sp := speed * randf_range(0.35, 1.0)
		pfx.append({"p": p, "v": Vector2(cos(ang), sin(ang) * 0.62) * sp, "z": randf_range(4.0, 22.0), "vz": up * randf_range(0.45, 1.0),
			"t": 0.0, "T": life * randf_range(0.7, 1.25), "c": cols[randi() % cols.size()], "s": size if randf() < 0.6 else maxi(1, size - 1)})


## A shockwave's front at `k` (0..1) of zone `z` as physical pixels: floor dust
## and grit kicked up and outwards all round the ring, sparks of its colour
## among them; they fly, bounce off walls and settle as rubble. Through the
## crypt's pixel physics; returns false without it (the drawn ring stands in).
func _wave_pixels(z: Dictionary, k: float, dt: float) -> bool:
	var P := _phys()
	if P == null:
		return false
	var s := _phys_scale()
	var r: float = float(z.r) * k
	var big := float(z.r) > 150.0
	var front := float(z.r) / maxf(0.05, float(z.T))
	var cols: Array = PX_COL.get(str(z.get("c", "fire")), PX_COL.fire)
	# the front: sparks that run with the wave and flash out quickly, so it reads as a ring
	z.spark_acc = float(z.get("spark_acc", 0.0)) + (900.0 if big else 360.0) * (1.0 - k * 0.5) * dt
	while float(z.spark_acc) >= 1.0:
		z.spark_acc = float(z.spark_acc) - 1.0
		var ang := randf() * TAU
		var out := Vector2(cos(ang), sin(ang) * 0.62)
		P.emit(((z.p as Vector2) + out * r) / s, out * front * randf_range(0.8, 1.05) / s, cols[randi() % 3], randf_range(0.1, 0.22), "spark", 2.0, 3.0, randf_range(20.0, 70.0) / s, 0.5)
	# behind it: grit kicked up off the floor, falling back as rubble that stays
	z.emit_acc = float(z.get("emit_acc", 0.0)) + (300.0 if big else 120.0) * (1.0 - k * 0.6) * dt
	while float(z.emit_acc) >= 1.0:
		z.emit_acc = float(z.emit_acc) - 1.0
		var ang := randf() * TAU
		var out := Vector2(cos(ang), sin(ang) * 0.62)
		P.emit(((z.p as Vector2) + out * r * randf_range(0.85, 1.0)) / s, out * randf_range(40.0, 140.0) / s, WAVE_DUST[randi() % WAVE_DUST.size()], randf_range(1.8, 3.2), "debris", 2.0 * float(1 + int(randf() < 0.3)), 2.0, randf_range(120.0, 260.0) / s, 3.0)
	return true


## The mouths a breath leaves (world px): the attack's "mouths" [[part, x, y],
## ...] where the rig drew them, without the severed heads, in the listed order
## (the first first); just in front of `head` without them.
func _mouths(m: Dictionary, a: Dictionary, head: Vector2) -> Array:
	var out: Array = []
	if a.get("mouths") is Array and rig_host != null:
		var lost: Array = Array(m.get("parts_lost", []))
		for spec: Variant in a.mouths:
			if not spec is Array or (spec as Array).size() < 3 or str(spec[0]) in lost:
				continue
			out.append(rig_host.part_point(m, str(spec[0]), Vector2(float(spec[1]), float(spec[2])), head))
	if out.is_empty():
		out.append(head + Vector2(m.face * m.r * 0.6, 0))
	return out


## A breath as physical pixels: while it winds up, embers gather and rise at
## every mouth; once it is out, each mouth spits a jet of flame pixels at where
## the hero stood (they fly with drag, bounce off walls and flash out), and the
## floor where the jets end catches embers.
func _breath_fx(A: Dictionary, a: Dictionary, mouths: Array, t: float, wind: float, dt: float, element := "fire") -> void:
	var P := _phys()
	if P == null or mouths.is_empty():
		return
	var s := _phys_scale()
	# the crypt's elements: their colours, and drops for poison, splinters for bone
	var cols: Array = PX_COL.get(element, PX_COL.fire)
	var jet_mode := {"poison": "drop", "bone": "debris"}.get(element, "spark") as String
	var reach := float(a.get("range", 260.0))
	A.fx_acc = float(A.get("fx_acc", 0.0)) + (70.0 if t < wind else 190.0) * dt * float(mouths.size())
	while float(A.fx_acc) >= 1.0:
		A.fx_acc = float(A.fx_acc) - 1.0
		var mouth: Vector2 = mouths[randi() % mouths.size()]
		if t < wind:
			P.emit((mouth + Vector2(randf_range(-10.0, 10.0), randf_range(-6.0, 6.0))) / s, Vector2(randf_range(-20.0, 20.0), randf_range(-24.0, 8.0)) / s,
				cols[1 + randi() % 2], randf_range(0.2, 0.4), "ember", 2.0, 4.0, randf_range(10.0, 40.0) / s, 1.0)
		else:
			var to: Vector2 = A.get("jet_to", mouth + Vector2(1, 0))
			var dir := (to - mouth).normalized().rotated(randf_range(-0.32, 0.32))
			var sp := randf_range(420.0, 640.0)
			# mostly orange and red flames, a white-hot pixel now and then
			var col: Color = cols[0] if randf() < 0.08 else cols[1 + randi() % 3]
			P.emit(mouth / s, dir * sp / s, col, reach / sp * randf_range(0.7, 1.05), jet_mode, 2.0 * float(1 + int(randf() < 0.3)), 6.0, randf_range(0.0, 50.0) / s, 0.4)
	if t >= wind and not A.has("jet_floor"):
		A.jet_floor = true
		for mouth: Vector2 in mouths:
			var to: Vector2 = A.get("jet_to", mouth + Vector2(1, 0))
			var end := mouth + (to - mouth).normalized() * reach * 0.75 + Vector2(0, 30)
			if element == "fire":
				P.embers(end / s, 46.0 / s, 9)
			else:
				_residue(end, element, 9, 46.0)


## A dash on its way: floor grit kicked up behind the beast, sparks off its
## paws, and burning paw prints left behind (embers that smoke out).
func _dash_fx(m: Dictionary, A: Dictionary, dt: float) -> void:
	var P := _phys()
	if P == null:
		return
	var s := _phys_scale()
	var dir: Vector2 = A.dir
	var own := own_element(m)
	var sparks: Array = PX_COL[own] if own in CRYPT_ELEMENTS else PX_COL.fire
	A.fx_acc = float(A.get("fx_acc", 0.0)) + 160.0 * dt
	while float(A.fx_acc) >= 1.0:
		A.fx_acc = float(A.fx_acc) - 1.0
		var at: Vector2 = (m.p as Vector2) + Vector2(randf_range(-m.r, m.r), randf_range(-8.0, 8.0))
		var vel := (-dir * randf_range(40.0, 160.0) + dir.orthogonal() * randf_range(-60.0, 60.0)) / s
		if randf() < 0.7:
			P.emit(at / s, vel, WAVE_DUST[randi() % WAVE_DUST.size()], randf_range(1.5, 2.6), "debris", 2.0, 2.0, randf_range(60.0, 160.0) / s, 3.0)
		else:
			P.emit(at / s, vel * 1.5, sparks[1 + randi() % 3], randf_range(0.25, 0.5), "spark", 2.0, 4.0, randf_range(30.0, 90.0) / s, 1.5)
	A.paw = float(A.get("paw", 0.0)) - dt
	if float(A.paw) <= 0.0:
		A.paw = 0.07
		# its prints: burning for the hell's beasts, the element's matter for the crypt's (rime, drips, bone dust, glints)
		if own in CRYPT_ELEMENTS:
			_residue(m.p, own, 2, 10.0)
		else:
			P.embers((m.p as Vector2) / s, 10.0 / s, 2)


## The cauldron boiling over: a fountain of lava shooting up from `head`
## (physical pixels thrown high that fall back round the cauldron and stay as
## glowing spots, sparks among them), strongest as it bursts, then dying down.
func _fountain(m: Dictionary, A: Dictionary, head: Vector2, dt: float) -> void:
	var P := _phys()
	if P == null:
		return
	var s := _phys_scale()
	var k := clampf((float(A.t) - 0.5) / 0.4, 0.0, 1.0)
	A.fx_acc = float(A.get("fx_acc", 0.0)) + 560.0 * (1.0 - k * 0.6) * dt
	var lift := maxf(0.0, (m.p as Vector2).y - head.y)
	while float(A.fx_acc) >= 1.0:
		A.fx_acc = float(A.fx_acc) - 1.0
		var vel := Vector2(randf_range(-110.0, 110.0), randf_range(-60.0, 60.0)) / s
		var up := randf_range(560.0, 980.0) / s
		if randf() < 0.75:
			P.emit((head + Vector2(randf_range(-14.0, 14.0), 0)) / s, vel, PX_COL.lava[randi() % 4], randf_range(2.0, 3.0), "debris", 2.0 * float(1 + int(randf() < 0.3)), lift / s, up, 0.3)
		else:
			P.emit((head + Vector2(randf_range(-10.0, 10.0), 0)) / s, vel, PX_COL.fire[randi() % 3], randf_range(0.6, 1.0), "spark", 2.0, lift / s, up * 0.8, 0.3)


## Slag sprouting out of the floor at `p`: `n` chunks of hot slag and drops of
## lava thrown up that fall back and stay (physical pixels), a few glowing
## cracks, and a burning lava pool of radius `r` (it hurts while he stands in it).
func _slag_spout(m: Dictionary, p: Vector2, n: int, r: float) -> void:
	_pixel_burst(p, n, PX_COL.lava, 120.0, 340.0, 1.4, 2)
	_pixel_burst(p, n, [Color("2e1e28"), Color("4f343c"), PX_COL.lava[3]], 90.0, 260.0, 1.6, 2)
	_crack_floor(p, r * 1.4, 4)
	_zone({"kind": "puddle", "p": p, "r": r, "T": 2.2, "dmg": 1, "m": m})


## A burst gathering at `head` before it goes off: lava boils over the rim (hot
## drops thrown up a little that fall back round the cauldron and stay as
## glowing spots), any other colour rises as embers drawn in towards it.
func _charge_fx(m: Dictionary, A: Dictionary, head: Vector2, c: String, dt: float) -> void:
	var P := _phys()
	if P == null:
		return
	var s := _phys_scale()
	var cols: Array = PX_COL.get(c, PX_COL.fire)
	A.fx_acc = float(A.get("fx_acc", 0.0)) + (90.0 if m.boss else 30.0) * dt
	var lift := maxf(0.0, (m.p as Vector2).y - head.y)
	while float(A.fx_acc) >= 1.0:
		A.fx_acc = float(A.fx_acc) - 1.0
		var ang := randf() * TAU
		var rim := Vector2(cos(ang), sin(ang) * 0.5) * float(m.r) * randf_range(0.3, 0.7)
		if c == "lava":
			P.emit((head + rim) / s, rim.normalized() * randf_range(20.0, 90.0) / s, cols[randi() % 4], randf_range(1.5, 2.5), "debris", 2.0, lift / s, randf_range(120.0, 260.0) / s, 0.5)
		else:
			P.emit((head + rim * 1.6) / s, -rim * 1.2 / s, cols[1 + randi() % 3], randf_range(0.3, 0.5), "ember", 2.0, lift / s, randf_range(10.0, 50.0) / s, 0.5)


## A lava lob drips as it flies: hot drops fall from it to the floor and stay
## there as dark red spots (physical pixels, one every 0.05 s).
func _lob_drips(L: Dictionary, dt: float) -> void:
	if str(L.get("c", "")) != "lava" or str(L.get("look", "")) == "boulder":
		return
	var P := _phys()
	if P == null:
		return
	L.drip = float(L.get("drip", 0.0)) - dt
	if float(L.drip) > 0.0:
		return
	L.drip = 0.05
	var s := _phys_scale()
	var k := clampf(float(L.t) / maxf(0.01, float(L.T)), 0.0, 1.0)
	var height := sin(k * PI) * 220.0
	var seen: Vector2 = (L.from as Vector2).lerp(L.to, k) - Vector2(0, height)
	P.emit(seen / s, Vector2(randf_range(-20.0, 20.0), randf_range(-10.0, 10.0)) / s, PX_COL.lava[1 + randi() % 3], 2.5, "debris", 2.0, height / s, 0.0, 0.5)


## Lava thrown in an arc from a beast standing at `ground` (its mouth `height`
## px above it) to land at `to`: `n` blobs flying with gravity that splash down
## there and stay as glowing spots (physical pixels).
func _lava_arc(ground: Vector2, height: float, to: Vector2, n: int) -> void:
	var P := _phys()
	if P == null:
		return
	var s := _phys_scale()
	var gravity := 620.0
	for k in range(n):
		var T := randf_range(0.45, 0.65)
		var d := (to + Vector2(randf_range(-16.0, 16.0), randf_range(-10.0, 10.0)) - ground) / s
		var h := height / s
		var vz := (0.5 * gravity * T * T - h) / T
		P.emit((ground - Vector2(0, height)) / s, d / T, PX_COL.lava[randi() % 4], T + randf_range(1.0, 2.0), "debris", 2.0 * float(1 + int(randf() < 0.3)), h, vz, 0.0)


## A beast called up from below at `p`: the floor cracks open and glows, a
## pillar of rising flame pixels in the caller's colour, rubble lifted around.
## In the crypt's elements the floor breaks cold: bone, frost and gold are
## thrown up as splinters that fall back and lie there, poison rises as
## drops, and what is left on the floor is the element's residue, no embers.
func _rift(p: Vector2, c: String) -> void:
	var cold := c in CRYPT_ELEMENTS
	_crack_floor(p, 110.0, 6, cold)
	var P := _phys()
	if P == null:
		return
	var s := _phys_scale()
	var cols: Array = PX_COL.get(c, PX_COL.fire)
	var mode := "debris" if c in ["bone", "frost", "gold"] else "ember"
	for k in range(30):
		P.emit((p + Vector2(randf_range(-24.0, 24.0), randf_range(-10.0, 10.0))) / s, Vector2(randf_range(-30.0, 30.0), randf_range(-16.0, 16.0)) / s,
			cols[randi() % 4], randf_range(0.5, 1.0) + (1.5 if mode == "debris" else 0.0), mode, 2.0 * float(1 + int(randf() < 0.25)), 2.0, randf_range(140.0, 340.0) / s, 0.8)
	if cold:
		_residue(p, c, 5, 30.0)
	else:
		P.embers(p / s, 30.0 / s, 10)
	P.kick(p / s, 90.0 / s, 0.6)


## A dash's telegraph on the pixel grid: both edges of its lane as dotted lines
## crawling forward from the beast, blinking faster as it is about to go.
func _pixel_lane(l: CanvasItem, from: Vector2, dir: Vector2, length: float, half: float, t: float) -> void:
	if fmod(t * (8.0 if t > 0.3 else 4.0), 1.0) > 0.7:
		return
	var side := dir.orthogonal() * half
	var crawl := int(floorf(t * LASER_FPS))
	for i in range(int(length / LASER_PX)):
		if posmod(i - crawl, 3) != 0:
			continue
		var p := from + dir * float(i) * LASER_PX
		for edge: Vector2 in [p + side, p - side]:
			_px(l, edge, Color(LASER_COL[2], 0.9))
		if posmod(i - crawl, 9) == 0:
			_px(l, p, Color(LASER_COL[1], 0.8))


## A cone telegraph on the pixel grid (a scream), in the style of the round
## ones (_ring): the sector as a sparse dot grid fixed to the world, its two
## edges and its rim as crawling dashes, and an arc sweeping out from its
## point to the rim as the strike comes (`k` 0..1).
func _px_cone(l: CanvasItem, from: Vector2, r: float, ang: float, arc: float, k: float, col: Color) -> void:
	var t: float = g.state.t
	var crawl := int(floorf(t * LASER_FPS))
	var step := 3 if k > 0.6 else 4
	var x0 := int(floor((from.x - r) / LASER_PX / step))
	var x1 := int(ceil((from.x + r) / LASER_PX / step))
	var y0 := int(floor((from.y - r) / LASER_PX / step))
	var y1 := int(ceil((from.y + r) / LASER_PX / step))
	for gy in range(y0, y1 + 1):
		for gx in range(x0, x1 + 1):
			var q := Vector2(gx, gy) * LASER_PX * float(step)
			var rel := q - from
			if rel.length() <= r and Rules.angle_gap(rel.angle(), ang) < arc / 2.0:
				l.draw_rect(Rect2(q, Vector2.ONE * LASER_PX), Color(col, 0.22 + 0.25 * k))
	for e: float in [ang - arc / 2.0, ang + arc / 2.0]:
		var dir := Vector2.from_angle(e)
		for i in range(int(r / LASER_PX)):
			if posmod(i - crawl, 3) != 2:
				_px(l, from + dir * float(i) * LASER_PX, Color(col, 0.9))
	for rr: float in [r, r * k]:
		var n := maxi(6, int(arc * rr / LASER_PX))
		for i in range(n + 1):
			if rr == r and posmod(i - crawl, 3) == 2:
				continue
			_px(l, from + Vector2.from_angle(ang - arc / 2.0 + arc * float(i) / float(n)) * rr, Color(col, 0.9 if rr == r else 0.75))


## A scream's sound on the pixel grid: arcs of pale violet running out through
## its cone one after another, each wider and fainter as it goes, the newest
## brightest, a tremor in them.
func _px_sound(l: CanvasItem, z: Dictionary, t: float) -> void:
	var k := clampf((float(z.t) - float(z.tele)) / maxf(0.01, float(z.T) - float(z.tele)), 0.0, 1.0)
	var r := float(z.r)
	var arc := float(z.arc)
	var tq := floorf(t * LASER_FPS)
	for w in range(4):
		var f := k * 1.6 - float(w) * 0.22
		if f <= 0.05 or f >= 1.0:
			continue
		var rr := r * f
		var n := maxi(6, int(arc * rr / LASER_PX))
		var col: Color = PX_COL.void[0] if w == 0 else (PX_COL.void[1] if w == 1 else PX_COL.void[2])
		for i in range(n + 1):
			var a := float(z.ang) - arc / 2.0 + arc * float(i) / float(n)
			var shake := sin(float(i) * 1.9 + tq * 2.3) * LASER_PX * 0.6
			var at := (z.p as Vector2) + Vector2.from_angle(a) * (rr + shake)
			_px(l, at, Color(col, (1.0 - f) * 0.95))
			if w == 0:
				_px(l, at - Vector2.from_angle(a) * LASER_PX, Color(PX_COL.void[2], (1.0 - f) * 0.7))


## A scream strikes: the blow felt at its source and the floor at its mouth
## torn up; its sound then runs out through the cone (_sound_fronts).
func _scream_blast(z: Dictionary) -> void:
	_impact(z.p, "medium", z.m)
	var P := _phys()
	if P == null:
		return
	var s := _phys_scale()
	P.kick(((z.p as Vector2) + Vector2.from_angle(float(z.ang)) * 40.0) / s, 50.0 / s, 0.6)


## A scream's sound after it struck, arc by arc as _px_sound draws them: each
## arc shoves the pixels it runs over outward (the first hardest, hell_balance
## monsters.feel.blow "fronts"), and the first lifts the floor's dust and grit
## as it passes and tears violet wisps along, so the cone is blown clear front
## by front, pixel for pixel.
func _sound_fronts(z: Dictionary) -> void:
	var spec: Dictionary = (cfg.get("feel", {}) as Dictionary).get("blow", {})
	var shares: Array = spec.get("fronts", [1.0, 0.6, 0.4, 0.25])
	var k := clampf((float(z.t) - float(z.tele)) / maxf(0.01, float(z.T) - float(z.tele)), 0.0, 1.0)
	var r := float(z.r)
	if not z.has("fronts"):
		z.fronts = [0.0, 0.0, 0.0, 0.0]
	for w in range(4):
		var r1 := r * clampf(k * 1.6 - float(w) * 0.22, 0.0, 1.0)
		var r0: float = z.fronts[w]
		if r1 <= r0:
			continue
		z.fronts[w] = r1
		_blow_front(z, r0, r1, float(z.ang), float(z.arc), 1.0, float(shares[mini(w, shares.size() - 1)]))
		if w == 0:
			_sound_dust(z, r0, r1, spec)


## The first sound arc lifts the floor's dust as it runs from `r0` to `r1`: as
## many pixels as the swept slice of the cone holds (one per "dust_area" px²),
## thrown on outward with it; some are violet wisps of the scream itself.
func _sound_dust(z: Dictionary, r0: float, r1: float, spec: Dictionary) -> void:
	var P := _phys()
	if P == null:
		return
	var s := _phys_scale()
	var push := float(spec.get("push", 340.0))
	z.dust_acc = float(z.get("dust_acc", 0.0)) + (r1 * r1 - r0 * r0) * float(z.arc) * 0.5 / maxf(1.0, float(spec.get("dust_area", 3200.0)))
	while float(z.dust_acc) >= 1.0:
		z.dust_acc = float(z.dust_acc) - 1.0
		var dir := Vector2.from_angle(float(z.ang) + randf_range(-0.5, 0.5) * float(z.arc))
		var at := (z.p as Vector2) + dir * randf_range(r0, r1)
		if randf() < 0.72:
			P.emit(at / s, dir * push * randf_range(0.5, 1.1) / s, WAVE_DUST[randi() % WAVE_DUST.size()], randf_range(1.2, 2.2), "debris", 2.0, 1.0, randf_range(40.0, 120.0) / s, 2.0)
		else:
			P.emit(at / s, dir * push * randf_range(0.7, 1.3) / s, PX_COL.void[1 + randi() % 3], randf_range(0.4, 0.8), "spark", 2.0, 6.0, randf_range(20.0, 80.0) / s, 1.0)


## A pressure front of zone `z` (a shockwave's ring, a scream's sound) passing
## from `r0` to `r1` world px within `arc` around `ang` (`squash` flattens a
## ring's height as it is drawn), at `share` of the full push (hell_balance
## monsters.feel.blow "push" px/s): the crypt's pixels it passes are shoved
## outward (flying pixels, the floor's embers and rubble, particles.gd blow),
## the hell's drifting embers blown along, and every lava cell it crosses
## sloshes over in its direction (once per front, lava_splash).
func _blow_front(z: Dictionary, r0: float, r1: float, ang: float, arc: float, squash: float, share: float) -> void:
	if r1 <= r0 or share <= 0.0:
		return
	var spec: Dictionary = (cfg.get("feel", {}) as Dictionary).get("blow", {})
	var push := float(spec.get("push", 340.0)) * share
	var p: Vector2 = z.p
	var P := _phys()
	if P != null:
		var s := _phys_scale()
		P.blow(p / s, r0 / s, r1 / s, ang, arc, push / s, squash)
	# the hell's embers drifting up from the lava are blown along
	for e: Dictionary in g.embers:
		var off: Vector2 = (e.p as Vector2) - p
		var dist := Vector2(off.x, off.y / squash).length()
		if dist < r0 or dist > r1 or dist <= 0.0:
			continue
		if arc < TAU and absf(wrapf(off.angle() - ang, -PI, PI)) > arc * 0.5:
			continue
		e.push = (e.get("push", Vector2.ZERO) as Vector2) * 0.35 + off.normalized() * push * randf_range(0.7, 1.2)
		e.t = maxf(float(e.t), 0.6)
	# lava it crosses sloshes over
	if share < 0.5:
		return
	if not z.has("splashed"):
		z.splashed = {}
	var cs := float(g.C)
	var drops: Array = spec.get("lava_drops", [2, 4])
	for cy in range(int(floor((p.y - r1 * squash) / cs)), int(floor((p.y + r1 * squash) / cs)) + 1):
		for cx in range(int(floor((p.x - r1) / cs)), int(floor((p.x + r1) / cs)) + 1):
			var cell := Vector2i(cx, cy)
			if z.splashed.has(cell):
				continue
			var t: int = g._cell(cx, cy)
			if t != 2 and t != 3:
				continue
			var mid := Vector2((cx + 0.5) * cs, (cy + 0.5) * cs)
			var off := mid - p
			var dist := Vector2(off.x, off.y / squash).length()
			if dist < r0 or dist > r1:
				continue
			if arc < TAU and absf(wrapf(off.angle() - ang, -PI, PI)) > arc * 0.5:
				continue
			z.splashed[cell] = true
			var along := off.normalized() if dist > 0.0 else Vector2.DOWN
			# where the push points at the floor beyond the pool, the lava runs over that rim
			var axis := Vector2i(int(signf(along.x)), 0) if absf(along.x) >= absf(along.y) else Vector2i(0, int(signf(along.y)))
			if g._cell(cx + axis.x, cy + axis.y) == 1:
				var edge := mid + Vector2(axis) * cs * 0.4 + Vector2(axis).orthogonal() * randf_range(-0.3, 0.3) * cs
				lava_splash(edge, Vector2(axis), randi_range(int(drops[0]), int(drops[1])) + 2, 1.0 + 0.3 * share)
			else:
				var at := mid + Vector2(randf_range(-0.35, 0.35), randf_range(-0.35, 0.35)) * cs
				lava_splash(at, along, randi_range(int(drops[0]), int(drops[1])), 1.0 + 0.3 * share, false)


## Lava sloshing over at `at` toward `dir`: `n` drops as glowing pixels thrown
## up and out (hell_balance monsters.feel.lava: "speed" and "up" world px/s,
## times `power`), a bright glint where it breaks; on the floor they lie as
## embers that sizzle, smoke and cool to faint soot ("soot"), those falling
## back into the pool sink. Through the crypt's pixel physics.
func lava_splash(at: Vector2, dir: Vector2, n: int, power: float = 1.0, spill: bool = true) -> void:
	var spec: Dictionary = (cfg.get("feel", {}) as Dictionary).get("lava", {})
	# at a rim the lava itself runs over it as a tongue of pixels and back (_draw_spills)
	if spill:
		var reach: Array = spec.get("spill", [24, 44])
		spills.append({"p": at, "dir": dir.normalized(), "len": randf_range(float(reach[0]), float(reach[1])) * minf(power, 1.5),
			"w": randf_range(26.0, 40.0), "t": 0.0, "T": float(spec.get("spill_time", 0.9)), "crusted": false, "seed": randi() % 997})
	var P := _phys()
	if P == null or n <= 0:
		return
	var s := _phys_scale()
	var speed: Array = spec.get("speed", [70, 170])
	var up: Array = spec.get("up", [150, 260])
	var soot := float(spec.get("soot", 0.4))
	for k in range(n):
		var v := dir.rotated(randf_range(-0.55, 0.55)) * randf_range(float(speed[0]), float(speed[1])) * power
		var drop: Dictionary = P.emit(at / s, v / s, PX_COL.lava[randi() % 3], 3.0, "glut", 4.0 if randf() < 0.7 else 2.0, 2.0,
			randf_range(float(up[0]), float(up[1])) * power / s, 1.0)
		drop.soot = soot
	# the lip of the slosh glints white-hot for a moment
	for k in range(2):
		P.emit(at / s, dir.rotated(randf_range(-0.8, 0.8)) * randf_range(20.0, 60.0) / s, PX_COL.lava[0].lightened(0.4), randf_range(0.12, 0.25), "spark", 2.0, 4.0, randf_range(40.0, 90.0) / s, 2.0)


## A grave hand on the pixel grid (a "hand" zone after its telegraph): a
## violet hand rising out of the floor with its fingers spread, closing to a
## fist as it grabs, and sinking back; its glow white at the knuckles.
func _px_hand(l: CanvasItem, z: Dictionary, t: float) -> void:
	var k := clampf((float(z.t) - float(z.tele)) / maxf(0.01, float(z.T) - float(z.tele)), 0.0, 1.0)
	var shown := clampf(minf(k / 0.25, (1.0 - k) / 0.35), 0.0, 1.0)
	var frame: Array = HAND_OPEN if k < 0.35 else HAND_FIST
	var rows := frame.size()
	var up := int(roundf(float(rows) * shown))
	if up <= 0:
		return
	var base := ((z.p as Vector2) / LASER_PX).floor() * LASER_PX + Vector2(-3, -float(up)) * LASER_PX
	var cols := {"o": PX_COL.void[3], "b": PX_COL.void[2], "h": PX_COL.void[1], "w": PX_COL.void[0]}
	for y in range(up):
		var row: String = frame[y]
		for x in range(row.length()):
			var ch := row[x]
			if not cols.has(ch):
				continue
			l.draw_rect(Rect2(base + Vector2(x, y) * LASER_PX, Vector2.ONE * LASER_PX), cols[ch])


## A straight telegraph on the pixel grid (a cleave's strip), in the style of
## the round ones (_ring): the area as a sparse dot grid fixed to the world,
## both edges as dashes crawling forward, and a bar filling it from the start
## to its end as the strike comes (`k` 0..1).
func _px_strip(l: CanvasItem, from: Vector2, dir: Vector2, length: float, half: float, k: float, col: Color) -> void:
	var t: float = g.state.t
	var side := dir.orthogonal()
	var crawl := int(floorf(t * LASER_FPS))
	var steps := int(length / LASER_PX)
	var lit := {}
	for i in range(steps):
		var p := from + dir * float(i) * LASER_PX
		# the edges, dashed and crawling
		if posmod(i - crawl, 3) != 2:
			for e: float in [-half, half]:
				_px(l, p + side * e, Color(col, 0.9))
		# the dot grid inside, every third cell of the world grid
		for o in range(int(-half / LASER_PX) + 1, int(half / LASER_PX)):
			var q := Vector2i(((p + side * float(o) * LASER_PX) / LASER_PX).floor())
			if posmod(q.x, 3) == 0 and posmod(q.y, 3) == 0 and not lit.has(q):
				lit[q] = true
				l.draw_rect(Rect2(Vector2(q) * LASER_PX, Vector2.ONE * LASER_PX), Color(col, 0.22 + 0.25 * k))
		# the filling bar
		if float(i) / float(maxi(1, steps)) <= k:
			_px(l, p, Color(col, 0.75))


## A cleave splitting the floor along zone `z` ("line"): a jagged glowing
## crack running its length with short branches (cooling like a slam's
## cracks), rubble and sparks thrown up all along it, the rubble lying there
## lifted again, and the blow felt where it ends.
func _fissure(z: Dictionary) -> void:
	var dir := Vector2.from_angle(float(z.ang))
	var side := dir.orthogonal()
	var length := float(z.len)
	var cells: Array = []
	var off := 0.0
	var steps := int(length / LASER_PX)
	for i in range(steps):
		off = clampf(off + randf_range(-0.8, 0.8), -2.0, 2.0)
		var at := dir * float(i) * LASER_PX + side * off * LASER_PX
		cells.append([(at / LASER_PX).round(), 1.0 - float(i) / float(steps) * 0.5])
		if randf() < 0.08:
			var b := at
			var bdir := (dir + side * (1.0 if randf() < 0.5 else -1.0)).normalized()
			for j in range(randi_range(2, 5)):
				b += bdir * LASER_PX
				cells.append([(b / LASER_PX).round(), 0.6 - float(j) * 0.1])
	var c := str(z.get("c", "fire"))
	cracks.append({"p": z.p, "t": 0.0, "T": CRACK_TIME * 1.3, "cells": cells, "cold": c in CRYPT_ELEMENTS})
	var d := 0.0
	while d < length:
		var p: Vector2 = (z.p as Vector2) + dir * d
		_pixel_burst(p, 4, CHUNK_COL, 140.0, 300.0, 1.2, 2)
		_pixel_burst(p, 3, PX_COL.get(c, PX_COL.fire) if c in CRYPT_ELEMENTS else PX_COL.fire, 200.0, 240.0, 0.5)
		d += 48.0
	_phys_blast((z.p as Vector2) + dir * length * 0.5, length * 0.5, 0, 0.8)
	_impact((z.p as Vector2) + dir * length * 0.6, "medium", z.m)
	# flames burst out of the split all along it, then burn down to ash (in the crypt: its element, _draw_firewall)
	firewalls.append({"p": z.p, "dir": dir, "len": length, "t": 0.0, "T": FIREWALL_TIME, "seed": randf() * 10.0, "ashed": false, "c": c})


## A wall of pixel flames along a split floor: one column of fire per laser
## pixel, flickering at LASER_FPS like the rigs' burning (each column its own
## height, now and then a tongue breaking off above it), white-hot at the
## root through yellow and orange to red and crimson. It leaps up in the
## first tenth of its time, burns, and sinks and cools from 45 % on, its last
## flames only red: what is left becomes ash (_ash_line).
## In the crypt the split throws up its element ("c"): bone and frost break
## out as rigid spikes (a jagged row, tips the lightest, shooting up in a
## twentieth of the time and standing still until they sink), poison and gold
## well up like the flames in their own colours, slower for poison.
func _draw_firewall(l: CanvasItem, w: Dictionary, t: float) -> void:
	var c := str(w.get("c", "fire"))
	var cols: Array = PX_COL.get(c, PX_COL.fire) if c in CRYPT_ELEMENTS else PX_COL.fire
	var spikes := c in ["bone", "frost"]
	var k := clampf(float(w.t) / maxf(0.01, float(w.T)), 0.0, 1.0)
	var rise := clampf(k / (0.05 if spikes else 0.1), 0.0, 1.0)
	var fall := 1.0 - clampf((k - 0.45) / 0.55, 0.0, 1.0)
	var high := FIREWALL_HIGH * rise * fall
	if high < 0.5:
		return
	var cool := 1.0 - fall
	var tq := floorf(t * LASER_FPS * (0.5 if c == "poison" else 1.0))
	var seed := float(w.seed)
	var dir: Vector2 = w.dir
	var top: Color = Color("9f294e") if cols == PX_COL.fire else (cols[3] as Color).darkened(0.35)
	var drawn := {}
	var crypt := c in CRYPT_ELEMENTS
	for i in range(int(float(w.len) / LASER_PX)):
		if spikes and posmod(i, 3) != 0:
			continue
		var base := Vector2i((((w.p as Vector2) + dir * float(i) * LASER_PX) / LASER_PX).floor())
		if crypt:
			# a little to either side of the split, as its crack runs: a straight row of columns
			# along a split running down the screen would read as a beam
			base += Vector2i((dir.orthogonal() * roundf(sin(float(i) * 1.7 + seed) * 1.6)).round())
		if drawn.has(base):
			continue
		drawn[base] = true
		if spikes:
			# a spike every third cell, each its own height: three cells wide in its lower half,
			# the lit side right, the shade left, the tip the element's lightest
			var h := int(roundf(high * 1.3 * (0.55 + 0.45 * absf(sin(float(i) * 12.9898 + seed)))))
			for j in range(h):
				var f := float(j) / maxf(1.0, float(h))
				var half := 1 if f < 0.45 and h >= 5 else 0
				for x in range(-half, half + 1):
					var col: Color = cols[0] if f >= 0.8 else (cols[3] if x < 0 else (cols[1] if x > 0 else cols[2]))
					l.draw_rect(Rect2(Vector2(base.x + x, base.y - j - 1) * LASER_PX, Vector2.ONE * LASER_PX), col)
			continue
		var wave := 0.45 + 0.55 * absf(sin(tq * 1.9 + float(i) * 2.3 + seed) * cos(tq * 0.7 + float(i) * 0.9))
		var h := int(roundf(high * wave))
		for j in range(h):
			var f := float(j) / maxf(1.0, float(h)) + cool * 0.5
			var col: Color = cols[0] if f < 0.12 else (cols[1] if f < 0.35 else (cols[2] if f < 0.6 else (cols[3] if f < 0.85 else top)))
			l.draw_rect(Rect2(Vector2(base.x, base.y - j - 1) * LASER_PX, Vector2.ONE * LASER_PX), col)
		if h > 2 and sin(tq * 1.3 + float(i) * 3.1 + seed) > 0.72:
			l.draw_rect(Rect2(Vector2(base.x, base.y - h - 2) * LASER_PX, Vector2.ONE * LASER_PX), cols[3])


## A split floor burnt out: embers sizzling all along it, soot left in the
## crack, and flakes of ash drifting up (the crypt's pixel physics). A split of
## the crypt's elements leaves only its residue (bone splinters, a film of
## poison, rime, gold dust): no embers, soot or ash.
func _ash_line(w: Dictionary) -> void:
	var P := _phys()
	if P == null:
		return
	var s := _phys_scale()
	var dir: Vector2 = w.dir
	var c := str(w.get("c", "fire"))
	var d := 0.0
	if c in CRYPT_ELEMENTS:
		while d < float(w.len):
			_residue((w.p as Vector2) + dir * d, c, 3, 22.0)
			d += 36.0
		return
	while d < float(w.len):
		var p: Vector2 = (w.p as Vector2) + dir * d
		_residue(p, "fire", 4, 22.0)
		P.scatter(p / s, Color(0.11, 0.08, 0.09, 0.6), 18.0 / s, 5)
		for k in range(2):
			P.emit((p + Vector2(randf_range(-10.0, 10.0), randf_range(-6.0, 6.0))) / s, Vector2(randf_range(-14.0, 14.0), randf_range(-8.0, 8.0)) / s,
				ASH_COL[randi() % ASH_COL.size()], randf_range(1.2, 2.2), "smoke", 2.0, 10.0 / s, randf_range(20.0, 50.0) / s, 0.6)
		d += 30.0


## A shot leaves glowing pixels behind it every SHOT_TRAIL s: embers of its
## colour that drift up a little and fade (the chain leaves none).
func _shot_trail(s: Dictionary, dt: float) -> void:
	var P := _phys()
	if P == null or s.has("chain"):
		return
	s.trail_t = float(s.get("trail_t", 0.0)) + dt
	# a soul sheds only a wisp now and then: its gas tail is drawn whole
	if float(s.trail_t) < SHOT_TRAIL * (3.0 if str(s.get("look", "")) in ["wisp", "tear"] else 1.0):
		return
	s.trail_t = 0.0
	var sc := _phys_scale()
	var cols: Array = PX_COL.get(str(s.get("c", "fire")), PX_COL.fire)
	var back: Vector2 = -(s.v as Vector2).normalized() * randf_range(20.0, 50.0) + Vector2(randf_range(-20.0, 20.0), randf_range(-14.0, 14.0))
	P.emit((s.p as Vector2) / sc, back / sc, cols[1 + randi() % 3], randf_range(0.35, 0.7), "ember", 2.0, 6.0, randf_range(10.0, 40.0) / sc, 1.5)


## What an attack of element `c` leaves on the floor at `p` once its effect is
## over (the crypt's pixel physics, like the heroes' fire and ice): fire and
## lava `n` embers within `r` that sizzle, smoke and cool to soot; void and
## soul glimmering wisps of their colour rising off the floor and dark traces
## left behind; frost crystals that melt to water and dry.
func _residue(p: Vector2, c: String, n: int, r: float) -> void:
	var P := _phys()
	if P == null or n <= 0:
		return
	var s := _phys_scale()
	match c:
		"fire", "lava":
			P.embers(p / s, r / s, n)
			if n >= 3:
				P.smoke(p / s, maxi(1, n / 3), r * 0.5 / s)
		"void", "soul":
			var cols: Array = PX_COL[c]
			for k in range(n):
				var at := p + Vector2.from_angle(randf() * TAU) * r * sqrt(randf()) * Vector2(1.0, 0.62)
				P.emit(at / s, Vector2(randf_range(-12.0, 12.0), randf_range(-8.0, 8.0)) / s, cols[1 + randi() % 3], randf_range(0.8, 1.6), "ember", 2.0, 2.0, randf_range(10.0, 40.0) / s, 1.0)
			P.scatter(p / s, Color(cols[3].darkened(0.5), 0.55), r / s, n)
		"frost", "ice":
			P.frost(p / s, r / s, n, Color(0.8, 0.95, 1.0, 0.55))
			# chips of ice skitter off and slide out
			for k in range(maxi(1, n / 3)):
				var out := Vector2.from_angle(randf() * TAU)
				P.emit(p / s, Vector2(out.x * randf_range(60.0, 160.0), out.y * randf_range(30.0, 80.0)) / s, PX_COL.frost[1 + randi() % 3], randf_range(1.2, 2.0), "shard", 2.0, randf_range(4.0, 10.0) / s, randf_range(30.0, 90.0) / s, 1.0)
		"bone":
			# splinters of bone thrown up that stay where they land, a puff of bone dust
			var cols: Array = PX_COL.bone
			for k in range(n):
				var out := Vector2.from_angle(randf() * TAU)
				P.emit((p + out * r * 0.3 * randf()) / s, Vector2(out.x * randf_range(40.0, 140.0), out.y * randf_range(20.0, 70.0)) / s, cols[1 + randi() % 3],
					randf_range(1.6, 2.6), "debris", 2.0, randf_range(4.0, 14.0) / s, randf_range(60.0, 160.0) / s, 2.5)
			P.scatter(p / s, Color(cols[3], 0.45), r * 0.6 / s, maxi(1, n / 2))
		"poison":
			# drops flung out that land as small splats, and a damp green stain
			var cols: Array = PX_COL.poison
			for k in range(n):
				var out := Vector2.from_angle(randf() * TAU)
				P.emit(p / s, Vector2(out.x * randf_range(30.0, 110.0), out.y * randf_range(15.0, 50.0)) / s, cols[1 + randi() % 3],
					randf_range(1.0, 1.8), "drop", 2.0, randf_range(6.0, 16.0) / s, randf_range(60.0, 140.0) / s, 1.5)
			P.scatter(p / s, Color(cols[3].darkened(0.3), 0.5), r / s, n)
		"gold":
			# gold sparks jump up, a few glints flicker on the floor
			var cols: Array = PX_COL.gold
			P.sparks(p / s, Vector2.UP, maxi(3, n), [cols[0], cols[1], cols[2]])
			for k in range(maxi(1, n / 2)):
				var at := p + Vector2.from_angle(randf() * TAU) * r * sqrt(randf()) * Vector2(1.0, 0.62)
				P.emit(at / s, Vector2(randf_range(-10.0, 10.0), randf_range(-6.0, 6.0)) / s, cols[1 + randi() % 2], randf_range(0.5, 1.0), "ember", 2.0, 2.0, randf_range(10.0, 30.0) / s, 1.0)


## A blast at `p` (radius `r`): the rubble already lying there flies again,
## embers glow on the floor, smoke rises. Through the crypt's pixel physics.
func _phys_blast(p: Vector2, r: float, embers: int, strength: float = 1.0) -> void:
	var P := _phys()
	if P == null:
		return
	var s := _phys_scale()
	P.kick(p / s, r / s, strength)
	if embers > 0:
		P.embers(p / s, r * 0.4 / s, embers)
		P.smoke(p / s, maxi(2, embers / 4), r * 0.25 / s)


## A slam's floor cracks around `p` (radius `r`): `n` jagged lines of grid cells
## running out from the impact, glowing hot near it, cooling to dark over CRACK_TIME.
func _crack_floor(p: Vector2, r: float, n: int, cold := false) -> void:
	var cells: Array = []
	var reach := maxi(3, int(r * 0.8 / LASER_PX))
	for k in range(n):
		var ang := float(k) / float(n) * TAU + randf_range(-0.3, 0.3)
		var pos := Vector2.ZERO
		var steps := int(float(reach) * randf_range(0.6, 1.0))
		for i in range(steps):
			ang += randf_range(-0.45, 0.45)
			pos += Vector2(cos(ang), sin(ang) * 0.62) * LASER_PX
			cells.append([(pos / LASER_PX).round(), 1.0 - float(i) / float(steps)])
	cracks.append({"p": p, "t": 0.0, "T": CRACK_TIME, "cells": cells, "cold": cold})


## Ages the flying pixels (gravity, bounce, rest) and the floor cracks.
func _update_pixel_fx(dt: float) -> void:
	for f: Dictionary in pfx:
		f.t = float(f.t) + dt
		if f.get("rest", false):
			continue
		# a mote the void draws in flies its line, nothing pulls it down (story_elements.gd)
		if f.get("fly", false):
			f.p = (f.p as Vector2) + (f.v as Vector2) * dt
			continue
		f.vz = float(f.vz) - 900.0 * dt
		f.z = float(f.z) + float(f.vz) * dt
		f.p = (f.p as Vector2) + (f.v as Vector2) * dt
		if float(f.z) <= 0.0:
			f.z = 0.0
			f.vz = -float(f.vz) * 0.3
			f.v = (f.v as Vector2) * 0.5
			if absf(float(f.vz)) < 40.0:
				f.rest = true
	pfx = pfx.filter(func(f: Dictionary) -> bool: return float(f.t) < float(f.T))
	if pfx.size() > 600:
		pfx = pfx.slice(pfx.size() - 600)
	for c: Dictionary in cracks:
		c.t = float(c.t) + dt
	cracks = cracks.filter(func(c: Dictionary) -> bool: return float(c.t) < float(c.T))
	for f: Dictionary in flashes:
		f.t = float(f.t) + dt
	flashes = flashes.filter(func(f: Dictionary) -> bool: return float(f.t) < float(f.T))
	for w: Dictionary in firewalls:
		w.t = float(w.t) + dt
		# as the flames die down they leave the split as ash: glowing embers, soot, flakes drifting up
		if not bool(w.ashed) and float(w.t) >= float(w.T) * 0.7:
			w.ashed = true
			_ash_line(w)
	firewalls = firewalls.filter(func(w: Dictionary) -> bool: return float(w.t) < float(w.T))
	for sp: Dictionary in spills:
		sp.t = float(sp.t) + dt
		# as the tongue runs back into the pool its crust stays: embers that cool to faint soot
		if not bool(sp.crusted) and float(sp.t) >= float(sp.T) * 0.45:
			sp.crusted = true
			var P := _phys()
			if P != null:
				var s := _phys_scale()
				var tip: Vector2 = (sp.p as Vector2) + (sp.dir as Vector2) * float(sp.len) * 0.6
				P.embers(tip / s, float(sp.w) * 0.35 / s, int(float(sp.len) * 0.4))
				P.smoke(tip / s, 2, float(sp.w) * 0.2 / s)
	spills = spills.filter(func(sp: Dictionary) -> bool: return float(sp.t) < float(sp.T))


## Lava running over a pool's rim on the pixel grid: a rounded tongue pushing
## out along its direction (eased out), lingering, then drawn back into the
## pool; white-hot where it wells over, cooling to dark red at its edge, its
## surface crawling.
func _draw_spills(l: CanvasItem, t: float) -> void:
	for sp: Dictionary in spills:
		var k := float(sp.t) / maxf(0.01, float(sp.T))
		var out := 1.0 - pow(1.0 - minf(1.0, k / 0.25), 3.0) if k < 0.4 else 1.0 - pow(clampf((k - 0.4) / 0.6, 0.0, 1.0), 2.0)
		if out <= 0.02:
			continue
		var dir: Vector2 = sp.dir
		var side := dir.orthogonal()
		var length := float(sp.len) * out
		var half := float(sp.w) * 0.5 * (0.6 + 0.4 * out)
		var crawl := floorf(t * LASER_FPS)
		var seen := {}
		var u := -LASER_PX * 2.0
		while u <= length:
			var v := -half
			while v <= half:
				var e := (u / maxf(1.0, length)) * (u / maxf(1.0, length)) * float(u > 0.0) + (v / half) * (v / half)
				if e <= 1.0:
					var at: Vector2 = (sp.p as Vector2) + dir * u + side * v
					var cell := Vector2i((at / LASER_PX).floor())
					if not seen.has(cell):
						seen[cell] = true
						var ripple := sin(float(cell.x) * 1.3 + float(cell.y) * 0.9 + crawl * 0.7 + float(sp.seed))
						var heat := 1.0 - e * 0.8 - maxf(0.0, u / maxf(1.0, float(sp.len))) * 0.4 + ripple * 0.15 - k * 0.3
						var col: Color = SPILL_COL[0] if heat > 0.8 else SPILL_COL[1] if heat > 0.5 else SPILL_COL[2] if heat > 0.2 else SPILL_COL[3]
						l.draw_rect(Rect2(Vector2(cell) * LASER_PX, Vector2.ONE * LASER_PX), col)
				v += LASER_PX * 0.75
			u += LASER_PX * 0.75


## The floor cracks: each cell's heat falls with its distance from the impact and
## with time, from yellow through red to a dark crack that fades at the end.
func _draw_cracks(l: CanvasItem) -> void:
	for c: Dictionary in cracks:
		var age := float(c.t) / float(c.T)
		var fade := 1.0 - clampf((age - 0.75) / 0.25, 0.0, 1.0)
		var base := ((c.p as Vector2) / LASER_PX).floor() * LASER_PX
		for cell: Array in c.cells:
			var heat := float(cell[1]) * 1.2 - age * 1.5
			var col: Color = CRACK_COL[0 if heat > 0.7 else 1 if heat > 0.4 else 2 if heat > 0.15 else 3 if heat > -0.2 else 4]
			if bool(c.get("cold", false)):
				col = CRACK_COLD[0 if heat > -0.2 else 1]
			# two pixels wide near the impact, one at the tips
			var wide := 2.0 if float(cell[1]) > 0.45 else 1.0
			l.draw_rect(Rect2(base + (cell[0] as Vector2) * LASER_PX, Vector2(wide, 1.0) * LASER_PX), Color(col, fade))


## A pool of lava on the pixel grid: cells inside the ellipse bubbling between
## orange and yellow, a dark red rim, fading out with `fade`.
func _px_pool(l: CanvasItem, c: Vector2, rx: float, ry: float, fade: float, t: float) -> void:
	var tq := floorf(t * 6.0)
	var x0 := int(floor((c.x - rx) / LASER_PX))
	var x1 := int(ceil((c.x + rx) / LASER_PX))
	var y0 := int(floor((c.y - ry) / LASER_PX))
	var y1 := int(ceil((c.y + ry) / LASER_PX))
	for gy in range(y0, y1 + 1):
		for gx in range(x0, x1 + 1):
			var q := Vector2(gx, gy) * LASER_PX + Vector2.ONE * LASER_PX * 0.5
			var d := Vector2((q.x - c.x) / rx, (q.y - c.y) / ry).length()
			if d > 1.0:
				continue
			var bubble := sin(float(gx) * 1.7 + float(gy) * 2.9 + tq * 1.3) + sin(float(gx) * 0.7 - tq * 0.9)
			var col: Color = PX_COL.lava[3] if d > 0.82 else (PX_COL.lava[0] if bubble > 1.4 else PX_COL.lava[1] if bubble > -0.6 else PX_COL.lava[2])
			l.draw_rect(Rect2(Vector2(gx, gy) * LASER_PX, Vector2.ONE * LASER_PX), Color(col, 0.85 * fade))


## Where a beam from `from` at `ang` stops: at the wall it meets (to a few px,
## by bisection after _wall_len's 24 px steps), else at `max_len`.
func _beam_reach(from: Vector2, ang: float, max_len: float) -> float:
	var hit := _wall_len(from, ang, max_len)
	if hit >= max_len:
		return max_len
	var lo := maxf(0.0, hit - 24.0)
	var hi := hit
	for k in range(6):
		var mid := (lo + hi) * 0.5
		var p := from + Vector2.from_angle(ang) * mid
		if g._walkable(g._cell(int(floor(p.x / g.C)), int(floor(p.y / g.C)))):
			lo = mid
		else:
			hi = mid
	return lo


## A laser burning into a wall at `p`: pixel flames there while it fires
## (`fire` s), then embers cooling off until `T` (update_scorches, _draw_scorch).
func _scorch(p: Vector2, fire: float) -> void:
	var embers: Array = []
	for k in range(7):
		embers.append({"o": Vector2(randi_range(-3, 3), randi_range(-2, 1)), "d": randf_range(0.0, 0.45)})
	scorches.append({"p": p, "t": 0.0, "fire": fire, "T": fire + SCORCH_GLOW, "seed": randf() * 10.0, "embers": embers})


## Ages the lasers' wall burns and drops the cold ones.
func _update_scorches(dt: float) -> void:
	for s: Dictionary in scorches:
		s.t = float(s.t) + dt
	scorches = scorches.filter(func(s: Dictionary) -> bool: return float(s.t) < float(s.T))


## How hot a wall burn is, 1 while the laser burns into it, falling to 0 as it cools.
func scorch_heat(s: Dictionary) -> float:
	if float(s.t) < float(s.fire):
		return 1.0
	return 1.0 - clampf((float(s.t) - float(s.fire)) / maxf(0.01, float(s.T) - float(s.fire)), 0.0, 1.0)


## A wall burn on the pixel grid: five columns of pixel fire rising from the
## contact, flickering at LASER_FPS and sinking as the burn cools, and around
## it embers that cool yellow, orange, red and crimson, then go out.
func _draw_scorch(l: CanvasItem, s: Dictionary, t: float) -> void:
	var heat := scorch_heat(s)
	var tq := floorf(t * LASER_FPS)
	var base := ((s.p as Vector2) / LASER_PX).floor() * LASER_PX
	var px := Vector2(LASER_PX, LASER_PX)
	var tall := 9.0 * heat
	for i in range(-2, 3):
		var edge := 1.0 - absf(float(i)) / 3.0
		var wave := 0.6 + 0.4 * sin(tq * 1.9 + float(i) * 2.3 + float(s.seed))
		var h := int(roundf(tall * edge * wave))
		for j in range(h):
			var k := float(j) / float(h)
			var c: Color = SCORCH_COL[0 if k < 0.3 else 1 if k < 0.6 else 2 if k < 0.85 else 3]
			l.draw_rect(Rect2(base + Vector2(i, -j - 1) * LASER_PX, px), c)
		if h > 1 and sin(tq * 1.3 + float(i) * 3.1 + float(s.seed)) > 0.75:
			l.draw_rect(Rect2(base + Vector2(i, -h - 2) * LASER_PX, px), SCORCH_COL[2])
	for e: Dictionary in s.embers:
		var hot := heat - float(e.d) * (1.0 - heat)
		if hot <= 0.0:
			continue
		var c: Color = SCORCH_COL[0 if hot > 0.75 else 1 if hot > 0.5 else 2 if hot > 0.25 else 3]
		if sin(tq * 2.7 + (e.o as Vector2).x * 1.9 + float(s.seed)) > 0.8:
			c = c.lightened(0.3)
		l.draw_rect(Rect2(base + (e.o as Vector2) * LASER_PX, px), c)


## Bright parts of attacks and the enemy shots, drawn on an additive layer under
## the darkness. Their soft light (the impacts' halo, the transformation and dying
## glow) is the crypt's bloom over the darkness (src/hero/story_glow.gd); with the
## light switched off (L: no darkness and no bloom) this layer draws it flat itself.
func draw_fx(l: CanvasItem) -> void:
	var t: float = g.state.t
	var flat := not bool(g.state.get("light", true))
	for z: Dictionary in zones:
		match String(z.kind):
			"wave":
				# without the pixel physics: a shockwave on the pixel grid, a bright leading rim and
				# cooler rings behind it, thinning and breaking up as it spreads
				if z.get("phys", false):
					continue
				var k := minf(1.0, z.t / z.T)
				var cols: Array = PX_COL.get(str(z.get("c", "fire")), PX_COL.fire)
				var rings := int(ceil(3.0 * (1.0 - k))) + 1
				for i in range(rings):
					var rx: float = z.r * k - float(i) * LASER_PX * 1.5
					_px_ellipse(l, z.p, rx, rx * 0.62, Color(cols[mini(i + 1, 3)], 1.0 - k * 0.6), 1, 0, k * 0.8, t)
			"arc":
				# drawn in its own colours over the actors (draw_lasers)
				pass
			"line":
				# the split floor is pixel cracks and flying rubble (_fissure), no band of light
				pass
			"cone":
				# the scream's sound waves are pixel arcs over the actors (draw_lasers)
				pass
			"meteor", "hand":
				# a falling slag drop is a pixel blob over the actors (draw_lasers); its splash is pixel physics;
				# a grave hand is a pixel hand over the actors too
				if str(z.get("look", "")) == "slag" or z.kind == "hand":
					continue
				if z.kind == "meteor" and z.t >= 0.0 and z.t < z.tele:
					var my: float = z.p.y - 900.0 * (1.0 - z.t / z.tele)
					var void_fire: bool = z.get("void", false)
					# a falling ball of fire with its flames streaming up behind it (a block of the crypt's element)
					if str(z.get("c", "")) in OWN_ELEMENTS and not void_fire:
						_px_missile(l, Vector2(z.p.x, my), 7, str(z.c), Vector2(0, 600), float(g.state.t), float(int(z.p.x) % 17))
					else:
						_px_ball(l, Vector2(z.p.x, my), 7, PX_COL.void if void_fire else PX_COL.lava, Vector2(0, 600), float(g.state.t), float(int(z.p.x) % 17))
				if z.t >= z.tele:
					var k: float = (z.t - z.tele) / (z.T - z.tele)
					# the hit: one ragged mass of pixel fire with smoke rising off it
					_px_burst(l, z.p - Vector2(0, 20), z.r * 0.7, k, PX_COL.void if z.kind == "hand" or z.get("void", false) else PX_COL.fire, float(int(z.p.x) % 17))
					if z.kind == "hand":
						for f in range(-2, 3):
							var fl := 70.0 * (1.0 - absi(f) * 0.2)
							l.draw_rect(Rect2(z.p.x + f * 12 - 4, z.p.y - 30 - fl * sin(minf(1.0, k * 2.0) * PI / 2.0), 8, fl), Color(0.9, 0.78, 1, 1.0 - k))
	# lobs are pixel fireballs or boulders over the actors (draw_lasers)
	for m: Dictionary in g.mobs:
		var A = m.act
		# every beam is a pixel laser in its own colours over the actors (draw_lasers)
		# the transformation and dying glow is the crypt's bloom (src/hero/story_glow.gd), flat without the light
		var heat := _glow(m)
		if flat and heat > 0.0:
			var c: Vector2 = m.p - Vector2(0, m.cy + m.alt)
			var r: float = float(m.def.w) * m.s * 0.9
			l.draw_circle(c, r, Color(1, 0.47, 0.16, 0.18 * heat))
			l.draw_circle(c, r * 0.55, Color(1, 0.9, 0.63, 0.35 * heat))
	# the enemy shots are pixel fireballs over the actors (draw_lasers); their soft glow is the bloom
