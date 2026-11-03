extends RefCounted
## Pure room and puzzle rules of the hell floors: when a door is shut, how far a
## puzzle group is, the order rule of sequence plates, which rooms the
## player knows, seal blessings, breakable seals and skull heaps, and the clone
## clock. Works on the dictionaries made by hell_floor_data.gd.


## True when the door blocks the way right now.
static func door_closed(door: Dictionary, rooms: Array, groups: Dictionary, boss_dead: bool) -> bool:
	var kind: String = door.kind
	if kind == "secret":
		return not door.broken
	if rooms[door.a].fight or rooms[door.b].fight:
		return true
	if kind == "lock":
		return not door.unlocked
	if kind == "puzzle":
		return not (groups.get(door.group, {}) as Dictionary).get("solved", false)
	if kind == "boss":
		return not boss_dead
	return false


## Returns Vector2i(done, total) for the pieces (braziers or plates) of a group.
static func group_progress(ents: Array, group: String) -> Vector2i:
	var done := 0
	var total := 0
	for e: Dictionary in ents:
		if e.get("group", "") == group:
			total += 1
			if e.get("lit", false) or e.get("on", false):
				done += 1
	return Vector2i(done, total)


## Steps on a sequence plate. Returns "right", "solved", "wrong" or "ignored".
## A wrong plate switches every plate of the group off again.
static func step_sequence(ents: Array, groups: Dictionary, plate: Dictionary) -> String:
	var group: String = plate.get("group", "")
	var g: Dictionary = groups.get(group, {})
	if g.is_empty() or g.get("solved", false) or plate.get("on", false):
		return "ignored"
	if int(plate.order) == int(g.next):
		plate.on = true
		g.next = int(g.next) + 1
		var p := group_progress(ents, group)
		if p.x == p.y:
			g.solved = true
			return "solved"
		return "right"
	for e: Dictionary in ents:
		if e.get("group", "") == group:
			e.on = false
	g.next = 1
	return "wrong"


## Rooms shown on the map: every visited room and its neighbours behind any
## door except a secret wall that is still closed.
static func known_rooms(doors: Array, visited: Dictionary) -> Dictionary:
	var known := visited.duplicate()
	for d: Dictionary in doors:
		if d.kind == "secret" and not d.broken:
			continue
		if visited.has(d.a):
			known[d.b] = true
		if visited.has(d.b):
			known[d.a] = true
	return known


## Blessings a broken demon seal can grant, in roll order.
const BLESSINGS := ["dmg", "rate", "speed", "range", "heart"]
const BLESSING_TEXT := {
	"dmg": "Höllenfeuer: +1 Schaden",
	"rate": "Schnellfeuer: 15 % schneller schießen",
	"speed": "Glutläufer: 10 % schneller laufen",
	"range": "Weitschuss: 25 % mehr Reichweite",
	"heart": "Herzcontainer: +1 Herz",
}
## The text of a last, shortened step that stops at the cap (%d = the real gain in %).
const BLESSING_CAPPED_TEXT := {
	"rate": "Schnellfeuer: %d %% schneller schießen (Höchstwert)",
	"speed": "Glutläufer: %d %% schneller laufen (Höchstwert)",
	"range": "Weitschuss: %d %% mehr Reichweite (Höchstwert)",
}


## The half hearts the worn gear adds to max_hp (state.items.hp_bonus, src/hero/story_items.gd).
static func gear_hp(hero: Dictionary) -> int:
	var items: Variant = hero.get("items", {})
	return int((items as Dictionary).get("hp_bonus", 0)) if items is Dictionary else 0


## Max life after a gain of `n` half hearts: the life that does not come from
## gear stops at `cap`, gear hearts sit on top, and a gain never lowers it.
static func raised_max_hp(hero: Dictionary, n: int, cap: int) -> int:
	var now := int(hero.get("max_hp", 0))
	var gear := gear_hp(hero)
	return maxi(now, mini(cap, now - gear + n) + gear)


## True while a heart container can still raise the life that does not come from gear.
static func heart_room(hero: Dictionary, cap: int) -> bool:
	return int(hero.get("max_hp", 0)) - gear_hp(hero) < cap


## The giant vault's note (hell_game.gd "vault"): the life it really added,
## `gained` half hearts (LP) after the life cap took its share, then the full
## heal and `gems` rune stones. Whole hearts read as heart containers with
## their LP; nothing gained says the life is already at its cap.
static func vault_note(gained: int, gems: int) -> String:
	if gained <= 0:
		return "Riesentresor! Leben schon am Höchstwert, volle Gesundheit, %d Gold" % gems
	if gained % 2 == 0:
		return "Riesentresor! +%d Herzcontainer (+%d LP), volle Gesundheit, %d Gold" % [int(gained / 2.0), gained, gems]
	return "Riesentresor! +%d LP Höchstleben, volle Gesundheit, %d Gold" % [gained, gems]


## Applies one blessing to the hero state (dmg, rate, speed_mul, range, hp,
## max_hp, buffs) with the values of hell_balance.json "blessings"; max_cap
## limits heart containers (raised_max_hp). The rate stops at rate_min, speed at
## speed_max and range at range_max (the last step is shortened to the cap); a
## blessing with less than half a step left gives the next open one instead
## (open_blessing). Returns the text of the blessing granted.
static func apply_blessing(hero: Dictionary, id: String, cfg: Dictionary, max_cap: int) -> String:
	id = open_blessing(hero, id, cfg, max_cap)
	var text: String = BLESSING_TEXT[id]
	match id:
		"dmg":
			hero.dmg = float(hero.dmg) + float(cfg.dmg)
		"rate":
			var was := float(hero.rate)
			hero.rate = maxf(float(cfg.rate_min), was * float(cfg.rate_mul))
			if float(hero.rate) > was * float(cfg.rate_mul) + 0.0001:
				text = BLESSING_CAPPED_TEXT.rate % roundi((1.0 - float(hero.rate) / was) * 100.0)
		"speed":
			var had := float(hero.get("speed_mul", 1.0))
			var now := minf(float(cfg.get("speed_max", INF)), had * float(cfg.speed_mul))
			hero.speed_mul = now
			if now < had * float(cfg.speed_mul) - 0.0001:
				text = BLESSING_CAPPED_TEXT.speed % roundi((now / had - 1.0) * 100.0)
		"range":
			var had := range_factor(hero, cfg)
			var now := minf(float(cfg.get("range_max", INF)), had * float(cfg.range_mul))
			hero.range = float(hero.range) * now / had
			if now < had * float(cfg.range_mul) - 0.0001:
				text = BLESSING_CAPPED_TEXT.range % roundi((now / had - 1.0) * 100.0)
		"heart":
			hero.max_hp = raised_max_hp(hero, int(cfg.heart), max_cap)
			hero.hp = mini(int(hero.max_hp), int(hero.hp) + int(cfg.heart))
	(hero.buffs as Array).append(text)
	return text


## The blessing a seal really grants for the rolled `id`: `id` while it still
## has at least half a step left below its cap, else the next open one in roll
## order (damage is always open; a heart only below `max_cap`, -1 = no cap).
static func open_blessing(hero: Dictionary, id: String, cfg: Dictionary, max_cap := -1) -> String:
	var at := BLESSINGS.find(id)
	if at < 0:
		return id
	for k in range(BLESSINGS.size()):
		var next: String = BLESSINGS[(at + k) % BLESSINGS.size()]
		if blessing_open(hero, next, cfg, max_cap):
			return next
	return "dmg"


## Whether blessing `id` still has at least half a step left below its cap
## (hell_balance.json blessings rate_min, speed_max, range_max; a heart while
## heart_room below `max_cap`, -1 = no cap).
static func blessing_open(hero: Dictionary, id: String, cfg: Dictionary, max_cap := -1) -> bool:
	match id:
		"heart":
			return max_cap < 0 or heart_room(hero, max_cap)
		"rate":
			var half := 1.0 - (1.0 - float(cfg.rate_mul)) * 0.5
			return float(hero.rate) * half >= float(cfg.rate_min) - 0.0001
		"speed":
			var half := 1.0 + (float(cfg.speed_mul) - 1.0) * 0.5
			return float(hero.get("speed_mul", 1.0)) * half <= float(cfg.get("speed_max", INF)) + 0.0001
		"range":
			var half := 1.0 + (float(cfg.range_mul) - 1.0) * 0.5
			return range_factor(hero, cfg) * half <= float(cfg.get("range_max", INF)) + 0.0001
	return true


## The range factor the hero's range blessings gave so far, counted from the
## buffs list (it is saved with the run): range_mul per blessing, at most range_max.
static func range_factor(hero: Dictionary, cfg: Dictionary) -> float:
	var name: String = BLESSING_TEXT.range.get_slice(":", 0)
	var count := 0
	for b: Variant in hero.get("buffs", []):
		if str(b).get_slice(":", 0) == name:
			count += 1
	return minf(float(cfg.get("range_max", INF)), pow(float(cfg.range_mul), count))


## The blessings a broken seal offers (balance package D1): `count` different
## ones that still have room below their caps (blessing_open, hearts below
## `max_cap`), drawn with `rng`. Damage is always open, so at least one is there.
static func seal_offer(hero: Dictionary, cfg: Dictionary, count: int, rng: RandomNumberGenerator, max_cap := -1) -> Array:
	var open: Array = BLESSINGS.filter(func(id: String) -> bool: return blessing_open(hero, id, cfg, max_cap))
	var out: Array = []
	while not open.is_empty() and out.size() < count:
		out.append(open.pop_at(rng.randi_range(0, open.size() - 1)))
	return out


## True while the hero can pay a seal's price of `price_hp` half hearts and
## keep at least one (the price never kills).
static func seal_affordable(hero: Dictionary, price_hp: int) -> bool:
	return int(hero.get("hp", 0)) > price_hp


## Takes blessing `id` of a seal: pays `price_hp` half hearts, then applies it
## (apply_blessing). Returns the blessing's text, "" when the hero cannot pay.
static func take_seal_blessing(hero: Dictionary, id: String, cfg: Dictionary, max_cap: int, price_hp: int) -> String:
	if not seal_affordable(hero, price_hp):
		return ""
	hero.hp = int(hero.hp) - price_hp
	return apply_blessing(hero, id, cfg, max_cap)


## A price in half hearts as the cards say it: "ein halbes Herz", "1 Herz",
## "1,5 Herzen" (the pixel font has no "½" glyph).
static func price_text(price_hp: int) -> String:
	if price_hp <= 0:
		return "nichts"
	if price_hp == 1:
		return "ein halbes Herz"
	var whole := floori(price_hp / 2.0)
	if price_hp % 2 == 1:
		return "%d,5 Herzen" % whole
	return "%d %s" % [whole, "Herz" if whole == 1 else "Herzen"]


## One hit on a seal or skull heap. Returns true when this hit breaks it.
static func hit_breakable(e: Dictionary) -> bool:
	if e.get("broken", false):
		return false
	e.hp = int(e.hp) - 1
	if int(e.hp) > 0:
		return false
	e.broken = true
	return true


## Starts the clone skill: "started", "none" (not owned), "running" (cannot be
## stopped) or "spent" (no time left).
static func start_skill(skill: Dictionary) -> String:
	if not skill.get("owned", false):
		return "none"
	if skill.get("active", false):
		return "running"
	if float(skill.get("left", 0.0)) <= 0.0:
		return "spent"
	skill.active = true
	return "started"


## Runs the clone's clock. Returns true when the time ran out on this tick.
static func tick_skill(skill: Dictionary, dt: float) -> bool:
	if not skill.get("active", false):
		return false
	skill.left = maxf(0.0, float(skill.left) - dt)
	if float(skill.left) > 0.0:
		return false
	skill.active = false
	return true
