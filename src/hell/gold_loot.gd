extends RefCounted
## The gold of the story worlds (src/hell/hell_game.gd): one currency, the profile's gold, always
## seen. Chests, vaults, broken crates, room rewards and loose finds throw it out as turning coins
## and money bags (bag_value gold each); they arc out, bounce once and lie turning, glinting now
## and then; near the hero they fly to him and are taken. Every pickup and every slain enemy's
## gold rises as a small golden '+N' with a coin. Sounds are the same in every world: the spill
## (gold_spill), each landing (gold_land), a coin (gold_pickup, a little higher in a quick run),
## a bag (gold_bag), the glint of gold lying near (gold_glint).
## Look per graphics set: HD the 0x72 coin and the HD bag, pixel the items sheet's coin with its
## glint and bag (assets/sprites/loot, tools/loot/build_gold_sprites.py). Values from
## assets/data/loot_gold.json. The world's data keeps its counts (loot.gems, "gem" finds): they
## are the gold's amounts.

const DATA_PATH := "res://assets/data/loot_gold.json"
const SPRITES := "res://assets/sprites/loot/"

var g: Node
var cfg: Dictionary = {}
## The gold in the world: {p (ground point), h (height over it), v (ground speed), vh (upward
## speed), value, bag, wait (s before it leaves), bounced, landed (s since landing, -1 in the air),
## fly (pulled to the hero), phase}.
var pieces: Array = []
## Rising '+N': {p, amount, t}.
var pops: Array = []
var _tex: Dictionary = {}
var _set := ""
var _glint_t := 3.0
var _glint: Dictionary = {}
var _streak := 0
var _streak_t := 0.0
var _rng := RandomNumberGenerator.new()


func _init(game: Node, data: Dictionary = {}) -> void:
	g = game
	cfg = data
	if cfg.is_empty() and FileAccess.file_exists(DATA_PATH):
		cfg = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	_rng.randomize()


## A new floor: no gold lying, no '+N' rising.
func reset() -> void:
	pieces = []
	pops = []
	_glint = {}


## How `amount` gold falls: [bags, coins] (bag_value gold per bag, the rest in coins).
static func split(amount: int, bag_value: int) -> Vector2i:
	if amount <= 0:
		return Vector2i.ZERO
	if bag_value <= 0 or amount < bag_value:
		return Vector2i(0, amount)
	return Vector2i(amount / bag_value, amount % bag_value)


## Throws `amount` gold out at `at` (world px): it arcs out piece by piece and lands around.
func spew(at: Vector2, amount: int) -> void:
	var parts := split(amount, int(cfg.get("bag_value", 10)))
	if parts == Vector2i.ZERO:
		return
	var spill: Dictionary = cfg.get("spill", {})
	var n := 0
	for k in range(parts.x + parts.y):
		var bag := k < parts.x
		var dir := Vector2.from_angle(_rng.randf_range(0.0, TAU))
		dir.y *= 0.6
		pieces.append({"p": at, "h": float(spill.get("height", 34)), "v": dir * _rng.randf_range(float(spill.speed[0]), float(spill.speed[1])),
			"vh": _rng.randf_range(float(spill.up[0]), float(spill.up[1])), "value": int(cfg.get("bag_value", 10)) if bag else 1, "bag": bag,
			"wait": n * float(spill.get("stagger", 0.035)), "bounced": false, "landed": -1.0, "fly": false, "phase": _rng.randf() * 10.0})
		n += 1
	_play("gold_spill", at)


## Gold lying at `at` from the start (a loose find on the floor).
func place(at: Vector2, amount: int) -> void:
	var parts := split(amount, int(cfg.get("bag_value", 10)))
	for k in range(parts.x + parts.y):
		var bag := k < parts.x
		pieces.append({"p": at + Vector2(k * 14.0, k * 5.0), "h": 0.0, "v": Vector2.ZERO, "vh": 0.0, "value": int(cfg.get("bag_value", 10)) if bag else 1,
			"bag": bag, "wait": 0.0, "bounced": true, "landed": 9.0, "fly": false, "phase": _rng.randf() * 10.0})


## A slain enemy's gold: a small '+amount' with a coin rising where it fell.
func kill_popup(at: Vector2, amount: int) -> void:
	if amount > 0:
		# shortly after the fall (a negative age: not drawn yet)
		pops.append({"p": at + Vector2(0, -40), "amount": amount, "t": -float(cfg.popup.get("delay", 0.12))})


## The gold lying in the world (not yet taken), in gold.
func lying() -> int:
	var sum := 0
	for piece: Dictionary in pieces:
		sum += int(piece.value)
	return sum


func update(dt: float) -> void:
	var hero := Vector2(float(g.player.x), float(g.player.y) - 20.0)
	var spill: Dictionary = cfg.get("spill", {})
	var gravity := float(spill.get("gravity", 980))
	var magnet := float(cfg.get("magnet_px", 150))
	var pick := float(cfg.get("pick_px", 30))
	_streak_t -= dt
	if _streak_t <= 0.0:
		_streak = 0
	for i in range(pieces.size() - 1, -1, -1):
		var piece: Dictionary = pieces[i]
		if float(piece.wait) > 0.0:
			piece.wait = float(piece.wait) - dt
			continue
		if not bool(piece.fly) and float(piece.landed) < 0.0:
			# in the air: out along its throw, falling, one small bounce
			piece.p += piece.v * dt
			piece.vh = float(piece.vh) - gravity * dt
			piece.h = float(piece.h) + float(piece.vh) * dt
			if float(piece.h) <= 0.0 and float(piece.vh) < 0.0:
				piece.h = 0.0
				if not bool(piece.bounced):
					piece.bounced = true
					piece.vh = -float(piece.vh) * float(spill.get("bounce", 0.35))
					piece.v *= 0.45
					_play("gold_land", piece.p, {"pitch": _rng.randf_range(0.92, 1.12), "volume_db": -4.0 if bool(piece.bag) else -7.0})
				else:
					piece.landed = 0.0
					piece.v = Vector2.ZERO
			continue
		piece.landed = float(piece.landed) + dt
		var d: float = (piece.p as Vector2).distance_to(hero)
		if not bool(piece.fly) and d < magnet and float(piece.landed) >= float(cfg.get("settle", 0.35)) and int(g.state.get("hp", 1)) > 0:
			piece.fly = true
			piece.speed = float(cfg.get("magnet_speed", 260))
		if bool(piece.fly):
			piece.speed = float(piece.speed) + 900.0 * dt
			piece.p = (piece.p as Vector2).move_toward(hero, float(piece.speed) * dt)
			piece.h = minf(18.0, float(piece.h) + 60.0 * dt)
			if (piece.p as Vector2).distance_to(hero) <= pick:
				_take(piece)
				pieces.remove_at(i)
	for i in range(pops.size() - 1, -1, -1):
		pops[i].t = float(pops[i].t) + dt
		if float(pops[i].t) >= float(cfg.popup.life):
			pops.remove_at(i)
	_update_glint(dt, hero)


## The gold reaches the hero: into the profile, its sound, and a '+N' over him (quick pickups add up).
func _take(piece: Dictionary) -> void:
	var value := int(piece.value)
	if g.has_method("add_gold"):
		g.add_gold(value)
	_streak += 1
	_streak_t = 0.6
	if bool(piece.bag):
		_play("gold_bag", piece.p)
	else:
		_play("gold_pickup", piece.p, {"pitch": 1.0 + minf(float(_streak - 1), 8.0) * 0.035})
	var hero := Vector2(float(g.player.x), float(g.player.y) - 90.0)
	if not pops.is_empty():
		var last: Dictionary = pops[-1]
		if bool(last.get("hero", false)) and float(last.t) < float(cfg.popup.get("merge", 0.45)):
			last.amount = int(last.amount) + value
			last.t = 0.0
			last.p = hero
			return
	pops.append({"p": hero, "amount": value, "t": 0.0, "hero": true})


## Now and then the gold lying nearest the hero glints (and is heard, quietly).
func _update_glint(dt: float, hero: Vector2) -> void:
	if not _glint.is_empty():
		_glint.t = float(_glint.t) + dt
		if float(_glint.t) > 0.35:
			_glint = {}
	_glint_t -= dt
	if _glint_t > 0.0:
		return
	var every: Array = cfg.get("glint_every", [2.5, 5.0])
	_glint_t = _rng.randf_range(float(every[0]), float(every[1]))
	var best: Dictionary = {}
	var best_d := float(cfg.get("hear_px", 640))
	for piece: Dictionary in pieces:
		if float(piece.landed) < 0.0 or bool(piece.fly):
			continue
		var d: float = (piece.p as Vector2).distance_to(hero)
		if d < best_d:
			best_d = d
			best = piece
	if not best.is_empty():
		_glint = {"piece": best, "t": 0.0}
		_play("gold_glint", best.p, {"pitch": _rng.randf_range(1.0, 1.15)})


func _play(event: String, at: Vector2, ctx: Dictionary = {}) -> void:
	var sound: Variant = g.get("sound")
	if sound != null:
		sound.at(event, at, ctx)


# --- look ---------------------------------------------------------------------------

func _look() -> Dictionary:
	var looks: Dictionary = cfg.get("look", {})
	return looks.get(str(g.get("graphics")), looks.get("hd", {}))


func _texture(name: String) -> Texture2D:
	if not _tex.has(name):
		var path := SPRITES + name + ".png"
		_tex[name] = load(path) if ResourceLoader.exists(path) else null
	return _tex[name]


## The coin's picture at time `t` (for the HUD and the '+N' too).
func coin(t: float, phase := 0.0) -> Texture2D:
	var look := _look()
	return _texture("%s_f%d" % [str(look.coin), int((t + phase) * float(cfg.get("fps", 8))) % int(look.get("frames", 4))])


## The gold on the floor and in the air, each piece over its own shadow.
func draw(l: CanvasItem, view: Rect2) -> void:
	var look := _look()
	var t := float(g.state.get("t", 0.0))
	for piece: Dictionary in pieces:
		if float(piece.wait) > 0.0 or not view.has_point(piece.p):
			continue
		var bag := bool(piece.bag)
		var tex := _texture(str(look.bag)) if bag else coin(t, float(piece.phase))
		if tex == null:
			continue
		var size := tex.get_size() * float(look.get("bag_scale" if bag else "coin_scale", 1.0))
		var bob := 0.0 if float(piece.landed) < 0.0 or bag else sin(t * 3.0 + float(piece.phase)) * 1.5
		var ground: Vector2 = piece.p
		l.draw_set_transform(ground, 0.0, Vector2(1.0, 0.35))
		l.draw_circle(Vector2.ZERO, size.x * (0.32 if bag else 0.22), Color(0, 0, 0, 0.28))
		l.draw_set_transform(Vector2.ZERO)
		var top := ground - Vector2(size.x / 2.0, size.y + float(piece.h) + bob)
		l.draw_texture_rect(tex, Rect2(top, size), false)
		if not _glint.is_empty() and _glint.piece == piece:
			_draw_glint(l, top + Vector2(size.x * 0.65, size.y * 0.3), float(_glint.t), look)


## A glint: the pixel set's own glint frames, the HD set a small four-pointed flash.
func _draw_glint(l: CanvasItem, at: Vector2, t: float, look: Dictionary) -> void:
	var k := clampf(t / 0.35, 0.0, 1.0)
	var glint := str(look.get("glint", ""))
	if glint != "":
		var tex := _texture("%s_f%d" % [glint, mini(1, int(k * 2.0))])
		if tex != null:
			var size := tex.get_size() * float(look.get("coin_scale", 1.0))
			l.draw_texture_rect(tex, Rect2(at - size / 2.0, size), false)
		return
	var a := sin(k * PI)
	var r := 7.0 * a
	var c := Color(1, 0.98, 0.85, a)
	l.draw_line(at - Vector2(r, 0), at + Vector2(r, 0), c, 2.0)
	l.draw_line(at - Vector2(0, r), at + Vector2(0, r), c, 2.0)


## The rising '+N' with a coin, fading out (over the actors).
func draw_pops(l: CanvasItem, font: Font) -> void:
	var t := float(g.state.get("t", 0.0))
	var look := _look()
	var life := float(cfg.popup.get("life", 0.85))
	for pop: Dictionary in pops:
		if float(pop.t) < 0.0:
			continue
		var k := clampf(float(pop.t) / life, 0.0, 1.0)
		var a := 1.0 - k * k
		var at: Vector2 = pop.p - Vector2(0, float(cfg.popup.get("rise", 46)) * (1.0 - (1.0 - k) * (1.0 - k)))
		var text := "+%d" % int(pop.amount)
		var size := int(cfg.popup.get("size", 26))
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var tex := coin(t)
		# the coin as tall as the digits
		var icon := tex.get_size() * (float(size) * 0.95 / maxf(1.0, tex.get_size().y)) if tex != null else Vector2.ZERO
		var left := at.x - (w + icon.x + 4.0) / 2.0
		if tex != null:
			l.draw_texture_rect(tex, Rect2(Vector2(left, at.y - icon.y + 3.0), icon), false, Color(1, 1, 1, a))
		var pos := Vector2(left + icon.x + 4.0, at.y)
		l.draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 6, Color(0.18, 0.09, 0.0, a * 0.9))
		l.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(1.0, 0.84, 0.28, a))
