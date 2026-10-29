extends RefCounted
## Story 1's combat system in the Frostgruft, in one place for the game
## (src/hell/hell_game.gd): conditions on the hero (hero_fx.gd), the crypt's
## enemy moves (frost_moves.gd) and the feel (frost_feel.gd, owned by the game
## as `feel`). Every call is a no-op in worlds without theme.feel (the
## Hell-Dungeon).
##
## Items, potions and curses are item system 2's (src/hero/story_items.gd,
## docs/ITEM-SYSTEM-V2.de.md) in every world; the conditions show as lines in
## the neutral hero panel (src/ui/hud_kit.gd, docs/HUD-EINHEITLICH.de.md).

const HeroFx = preload("res://src/hell/hero_fx.gd")
const FrostMoves = preload("res://src/hell/frost_moves.gd")


## True in a world with Story 1's combat feel (theme.feel).
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


## Damage factor of every hero hit from the conditions and the enemy's ice armour.
static func hit_factor(g: Node, m: Dictionary) -> float:
	if not on(g):
		return 1.0
	return HeroFx.damage_scale(g) * FrostMoves.damage_taken(m)


## After a hero hit: chips, squash, hitstop and shake.
static func after_hit(g: Node, m: Dictionary, push: Vector2, crit: bool) -> void:
	if not on(g):
		return
	g.feel.on_hit(m, push, crit)


## After a kill: the burst and the stain.
static func after_kill(g: Node, m: Dictionary) -> void:
	if not on(g):
		return
	g.feel.on_kill(m)


## Factor on the time between attacks (weakness).
static func rate(g: Node) -> float:
	return HeroFx.attack_scale(g) if on(g) else 1.0


## Factor on walking speed (slow, freeze).
static func move_scale(g: Node) -> float:
	return HeroFx.move_scale(g) if on(g) else 1.0


## False while a condition (freeze) keeps the hero from attacking.
static func can_attack(g: Node) -> bool:
	return not on(g) or HeroFx.can_act(g)


## False (with a hint) when a condition keeps a skill from casting. Sealed keys
## from cursed items are item system 2's (src/hell/hero_kit.gd).
static func can_cast(g: Node, _key: String) -> bool:
	if not on(g):
		return true
	if not HeroFx.can_act(g):
		return false
	if HeroFx.skills_sealed(g):
		g._toast("Verstummt: keine Fähigkeiten.")
		return false
	return true


## A fresh hero attack happened: the sword's swing gets its arc of light.
static func after_attack(g: Node) -> void:
	if not on(g):
		return
	if float(g.swing.get("t", 0.0)) > 0.12:
		g.feel.on_swing(float(g.swing.a), float(g.weapon.get("reach", 150.0)))


# ---------- drawing ----------

## Under the actors: stains and the move warnings.
static func draw_under(g: Node, l: CanvasItem, t: float) -> void:
	if not on(g):
		return
	g.feel.draw_under(l)
	FrostMoves.draw(g, l, t)


## Over the actors: the hero's conditions, shot looks, chips and effects.
static func draw_over(g: Node, l: CanvasItem, t: float) -> void:
	if not on(g):
		return
	HeroFx.draw(g, l, t)
	g.feel.draw_over(l, t)


## Screen space, under the HUD panels: blindness darkens the view around the hero.
static func draw_hud(g: Node, h: CanvasItem, size: Vector2) -> void:
	if not on(g) or not HeroFx.has(g, "blind") or g._vignette == null:
		return
	var dark := 0.9
	var c: Vector2 = g._to_screen(Vector2(g.player.x, g.player.y - 40), size)
	var r := 260.0
	h.draw_texture_rect(g._vignette, Rect2(c - Vector2(r, r) * 1.6, Vector2(r, r) * 3.2), false, Color(0, 0, 0, dark))
	h.draw_rect(Rect2(0, 0, size.x, c.y - r * 1.6), Color(0, 0, 0, dark))
	h.draw_rect(Rect2(0, c.y + r * 1.6, size.x, size.y), Color(0, 0, 0, dark))
	h.draw_rect(Rect2(0, 0, c.x - r * 1.6, size.y), Color(0, 0, 0, dark))
	h.draw_rect(Rect2(c.x + r * 1.6, 0, size.x, size.y), Color(0, 0, 0, dark))


## The hero's conditions as status lines of the hero panel ({text, color}),
## e.g. "GIFT · 9 s" in the condition's colour.
static func status_lines(g: Node) -> Array:
	var lines: Array = []
	if not on(g):
		return lines
	var all := HeroFx._all(g)
	for kind: String in all:
		var e: Dictionary = all[kind]
		lines.append({"text": "%s · %d s" % [HeroFx.NAMES.get(kind, kind.to_upper()), ceili(float(e.time))], "color": HeroFx.LOOK.get(kind, Color.WHITE)})
	return lines
