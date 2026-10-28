extends RefCounted
## Story 1's combat system in the Frostgruft, in one place for the game
## (src/hell/hell_game.gd): conditions on the hero (hero_fx.gd), the crypt's
## enemy moves (frost_moves.gd), items, potions and curses (frost_items.gd,
## frost_bag.gd) and the feel (frost_feel.gd, owned by the game as `feel`).
## Every call is a no-op in worlds without those theme sections (the Hell-Dungeon).
## Talents, subclasses and relics stay as they are; the weapon in hand lifts
## them like the class weapon, and conditions or curses hold them back.

const HeroFx = preload("res://src/hell/hero_fx.gd")
const FrostMoves = preload("res://src/hell/frost_moves.gd")
const FrostItems = preload("res://src/hell/frost_items.gd")
const FrostBag = preload("res://src/hell/frost_bag.gd")
const FONT := preload("res://assets/fonts/pixel_operator8.ttf")


static func on(g: Node) -> bool:
	return g.feel != null


## Everything that runs per frame besides the game's own update.
static func update(g: Node, dt: float) -> void:
	if not on(g):
		return
	HeroFx.step(g, dt)
	FrostMoves.update(g, dt)
	for m: Dictionary in g.mobs:
		FrostMoves.tick_mob(g, m, dt)
	FrostItems.update(g, dt)
	FrostItems.update_pools(g, dt)
	# the unbound blessing: skill cooldowns run faster
	var cs := FrostItems.cooldown_scale(g)
	if cs < 1.0:
		var cds: Dictionary = g.state.skill_cd
		for k: String in cds:
			cds[k] = maxf(0.0, float(cds[k]) - dt * (1.0 / cs - 1.0))


## Damage factor of every hero hit: the weapon in hand, its precision effects,
## the strength potion and the enemy's ice armour. Remembers the shot for the procs.
static func hit_factor(g: Node, m: Dictionary) -> float:
	if not on(g):
		return 1.0
	return FrostItems.power(g) * FrostItems.hit_factor(g, m, g.cur_shot) * HeroFx.damage_scale(g) * FrostMoves.damage_taken(m)


## After a hero hit: feel and the weapon's procs.
static func after_hit(g: Node, m: Dictionary, push: Vector2, dealt: float) -> void:
	if not on(g):
		return
	g.feel.on_hit(m, push, bool(g.state.get("last_crit", false)))
	g.state.last_crit = false
	FrostItems.after_hit(g, m, dealt, g.cur_shot)


static func after_kill(g: Node, m: Dictionary) -> void:
	if not on(g):
		return
	g.feel.on_kill(m)
	FrostItems.after_kill(g, m)


## Factor on the time between attacks (weapon, curses, weakness).
static func rate(g: Node) -> float:
	return FrostItems.rate(g) * HeroFx.attack_scale(g) if on(g) else 1.0


## Factor on walking speed (slow, freeze, haste, sluggish).
static func move_scale(g: Node) -> float:
	return HeroFx.move_scale(g) * FrostItems.speed(g) if on(g) else 1.0


static func can_attack(g: Node) -> bool:
	return not on(g) or (HeroFx.can_act(g) and not FrostBag.is_open(g))


## False (with a hint) when a condition or the seal keeps a skill from casting.
static func can_cast(g: Node, key: String) -> bool:
	if not on(g):
		return true
	if not HeroFx.can_act(g):
		return false
	if HeroFx.skills_sealed(g):
		g._toast("Verstummt: keine Fähigkeiten.")
		return false
	if FrostItems.sealed_key(g) == key:
		g._toast("Versiegelt: Taste %s ist gesperrt, bis der Fluch bricht." % key)
		return false
	return true


## A fresh hero attack happened: the burning blade and the new shots' item shapes.
static func after_attack(g: Node, first_new_shot: int) -> void:
	if not on(g):
		return
	FrostItems.on_attack(g)
	for i in range(first_new_shot, g.shots.size()):
		FrostItems.shape_shot(g, g.shots[i])
	if float(g.swing.get("t", 0.0)) > 0.12:
		g.feel.on_swing(float(g.swing.a), float(g.weapon.get("reach", 150.0)))


## Before the hero loses hearts: extra damage of the fragile curse, the shield potion.
static func guard(g: Node) -> bool:
	return on(g) and FrostItems.guard(g)


static func extra_hurt(g: Node) -> int:
	return FrostItems.extra_hurt(g) if on(g) else 0


# ---------- drawing ----------

## Under the actors: stains and the move warnings.
static func draw_under(g: Node, l: CanvasItem, t: float) -> void:
	if not on(g):
		return
	g.feel.draw_under(l)
	FrostMoves.draw(g, l, t)


## Over the actors: loot, pools, the hero's conditions, shot looks, chips and effects.
static func draw_over(g: Node, l: CanvasItem, t: float) -> void:
	if not on(g):
		return
	FrostItems.draw(g, l, t)
	HeroFx.draw(g, l, t)
	g.feel.draw_over(l, t)


## Screen space: blindness and the night curse darken the view, the condition
## chips, the item note and the bag.
static func draw_hud(g: Node, h: CanvasItem, size: Vector2) -> void:
	if not on(g):
		return
	var dark := 0.0
	if HeroFx.has(g, "blind"):
		dark = 0.9
	elif FrostItems.dim(g):
		dark = 0.55
	if dark > 0.0 and g._vignette != null:
		var c: Vector2 = g._to_screen(Vector2(g.player.x, g.player.y - 40), size)
		var r := 260.0 if HeroFx.has(g, "blind") else 520.0
		h.draw_texture_rect(g._vignette, Rect2(c - Vector2(r, r) * 1.6, Vector2(r, r) * 3.2), false, Color(0, 0, 0, dark))
		h.draw_rect(Rect2(0, 0, size.x, c.y - r * 1.6), Color(0, 0, 0, dark))
		h.draw_rect(Rect2(0, c.y + r * 1.6, size.x, size.y), Color(0, 0, 0, dark))
		h.draw_rect(Rect2(0, 0, c.x - r * 1.6, size.y), Color(0, 0, 0, dark))
		h.draw_rect(Rect2(c.x + r * 1.6, 0, size.x, size.y), Color(0, 0, 0, dark))
	if str(g.theme.get("hud", "")) != "crypt":
		HeroFx.draw_hud(g, h, Vector2(24, 128), FONT)
	FrostBag.draw(g, h, size)
