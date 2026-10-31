extends RefCounted
## The HUD parts every world draws the same way (crypt, Hell-Dungeon,
## Frostgruft), in the neutral look of src/ui/hud_style.gd. A world fills the
## data; mechanics a world does not have simply stay empty (no keys in the
## crypt yet, no team-mates in the story worlds), so the crypt is ready for
## keys, rune gems, puzzle progress and timed powers when it gets them.
## - hero_panel: top left, one compact strip: name and HP, the life bar (blood
##   that drains smoothly under poison, burn or lava) with the level beside it,
##   the EXP line, resources (keys, gems, braziers) and short status lines
##   (clone, blessings, shield).
## - floor_panel + menu_chip: top right: floor, place, the fight state and the
##   mini-map area; "ESC · MENÜ" under it.
## - boss_bar: top centre, with phase segments.
## - banner, toast, prompt: floor titles, hints over the skill bar, "E" prompts.
## - pet_panel: the companion bar right under the hero strip: portrait, name,
##   life, the two abilities on 5 and 6 (no command buttons).
## Static, display only. The only state is each life bar's animation (the
## ghost of a hit, the heal sweep), kept per bar key between frames, the
## cached companion portraits and the ability slots of the last companion bar
## (for the right-click on an icon).

const HudStyle = preload("res://src/ui/hud_style.gd")
const TalentIcons = preload("res://src/ui/talent_icons.gd")
const Profile = preload("res://src/progress/profile.gd")

# Per life bar key: gap (the ghost's length in half hearts), hold (seconds
# before it starts to shrink), speed (half hearts per second), heal (sweep
# progress 0..1, -1 none), last (life seen last frame), clock (that frame's time).
static var _life_bars: Dictionary = {}
# Companion kind -> {texture, region} (or {} when no frame exists), loaded once.
static var _portraits: Dictionary = {}
# Talent branch id -> {id, color, color2} for the companion's ability icons.
static var _specs: Dictionary = {}
# The ability slots of the companion bar drawn last, and the canvas it was drawn on.
static var _pet_slots: Array = []
static var _pet_canvas: CanvasItem = null


## The companion bar right under the hero strip (the "Begleiterleiste", user
## decision 31.10.2026: portrait, life and abilities, no command buttons): a
## framed row of `width` px, as wide as the hero strip. Left the portrait slot
## with the companion's idle frame (assets/data/ui_hud_style.json
## "pet_portraits"; a drawn glyph when the file is missing), beside it the
## name over its life bar (HudKit.life_bar, the fill green turning red as the
## life share falls, the bar's own state under "pet:<kind>") with the numbers
## at the right; fallen, the bar gives way to "GEFALLEN · 12 s" with the
## seconds until it returns. Right the two abilities as small slots: the
## talent icon, the key (5, 6), the cooldown as a shade with the seconds, the
## auto-cast marker (a pulsing glow and a dot in the corner). `pet` is
## talent_combat's player_state().pet ({kind, name, spec, alive, hp, hp_max,
## respawn, abilities: [{id, name, icon, text, cd, cd_max, auto, key}]}).
## Remembers the ability slots for pet_slot_at(). Returns the row's rectangle
## (zero size without a companion).
static func pet_panel(canvas: CanvasItem, font: Font, origin: Vector2, width: float, pet: Dictionary, clock: float) -> Rect2:
	_pet_slots = []
	_pet_canvas = canvas
	if pet.is_empty(): return Rect2(origin, Vector2.ZERO)
	var pad := HudStyle.size("pet_pad")
	var small := int(HudStyle.size("font_small"))
	var portrait_px := HudStyle.size("pet_portrait")
	var slot_px := HudStyle.size("pet_slot")
	var gap := HudStyle.size("pet_slot_gap")
	var rect := Rect2(origin, Vector2(width, HudStyle.size("pet_row_height")))
	HudStyle.panel(canvas, rect)
	var alive := bool(pet.get("alive", false))
	var kind := str(pet.get("kind", ""))
	var name := str(pet.get("name", kind)).to_upper()
	# the portrait slot at the left, the figure centred in it, grey once fallen
	var portrait := Rect2(rect.position + Vector2(pad, floorf((rect.size.y - portrait_px) * 0.5)), Vector2(portrait_px, portrait_px))
	_pet_portrait(canvas, font, portrait, kind, name, alive)
	# the ability slots at the right, a gap between them
	var abilities: Array = pet.get("abilities", [])
	var slots_w := abilities.size() * slot_px + maxi(0, abilities.size() - 1) * gap
	var slot_x := rect.end.x - pad - slots_w
	var spec := _spec(str(pet.get("spec", "")))
	for index in range(abilities.size()):
		var slot := Rect2(Vector2(slot_x + index * (slot_px + gap), rect.position.y + floorf((rect.size.y - slot_px) * 0.5)), Vector2(slot_px, slot_px))
		_pet_ability(canvas, font, slot, abilities[index], spec, alive, clock)
		_pet_slots.append(slot)
	# the text column between them: the name over the life bar
	var x := portrait.end.x + 8.0
	var right := (slot_x - 8.0) if not abilities.is_empty() else (rect.end.x - pad)
	var column_w := maxf(0.0, right - x)
	var bar_h := HudStyle.size("pet_bar_height")
	var top := rect.position.y + floorf((rect.size.y - (small + 4.0 + bar_h)) * 0.5)
	var baseline := top + small
	var bar := Rect2(Vector2(x, top + small + 4.0), Vector2(column_w, bar_h))
	HudStyle.text(canvas, font, Vector2(x, baseline), name, small, HudStyle.color("text") if alive else HudStyle.color("text_muted"))
	if alive:
		var hp_max := maxf(1.0, float(pet.get("hp_max", 1.0)))
		var hp := clampf(float(pet.get("hp", 0.0)), 0.0, hp_max)
		var share := hp / hp_max
		# the fill: green while hale, red when the share runs low
		var tint := HudStyle.color("ok").lerp(HudStyle.color("danger"), clampf((0.7 - share) / 0.45, 0.0, 1.0))
		life_bar(canvas, bar, hp, ceili(hp_max), "pet:" + kind, clock, false, tint)
		# the numbers only where they fit beside the name (the crypt's strip is narrow)
		var numbers := "%d / %d" % [ceili(hp - 0.001) if hp > 0.0 else 0, ceili(hp_max)]
		if HudStyle.width(font, name, small) + HudStyle.width(font, numbers, small) + 12.0 <= column_w:
			HudStyle.text(canvas, font, Vector2(right, baseline), numbers, small, HudStyle.color("text_dim"), 2)
	else:
		# fallen: no bar, the countdown in its place
		var wait := float(pet.get("respawn", 0.0))
		var fallen := ("GEFALLEN · %d s" % ceili(wait)) if wait > 0.0 else "GEFALLEN"
		var pulse := 0.75 + 0.25 * sin(clock * TAU * HudStyle.size("life_low_pulse_hz") * 0.5)
		HudStyle.text(canvas, font, Vector2(x, bar.end.y + 2.0), fallen, small, Color(HudStyle.color("danger"), pulse))
	return rect


## The companion ability (0 or 1) whose slot on the last drawn companion bar
## holds `point` (px of the canvas the bar was drawn on), or -1. Without a
## point, the mouse over that canvas is used (the right-click toggle of the
## auto-cast asks that way through TalentBar.pet_slot).
static func pet_slot_at(point: Vector2 = Vector2.INF) -> int:
	if _pet_slots.is_empty(): return -1
	var at := point
	if not at.is_finite():
		if not is_instance_valid(_pet_canvas): return -1
		at = _pet_canvas.get_local_mouse_position()
	for index in range(_pet_slots.size()):
		if (_pet_slots[index] as Rect2).has_point(at): return index
	return -1


## The portrait slot: a dark box with the companion's idle frame centred in it
## (1x, or 2x when the figure is small enough), the first letter of its name
## in the accent colour when there is no frame. Grey and dim once fallen.
static func _pet_portrait(canvas: CanvasItem, font: Font, slot: Rect2, kind: String, name: String, alive: bool) -> void:
	canvas.draw_rect(slot, HudStyle.color("slot"))
	var frame := _portrait(kind)
	var inner := slot.grow(-1.0)
	var tint := Color.WHITE if alive else Color(0.36, 0.34, 0.38, 0.85)
	if frame.is_empty():
		HudStyle.text(canvas, font, Vector2(slot.get_center().x, slot.get_center().y + 7.0), name.left(1), int(HudStyle.size("font_body")), HudStyle.color("accent") if alive else HudStyle.color("text_muted"), 1)
	else:
		var texture: Texture2D = frame.texture
		var region: Rect2 = frame.region
		var scale := maxf(1.0, floorf(minf(inner.size.x / maxf(1.0, region.size.x), inner.size.y / maxf(1.0, region.size.y))))
		var size := (region.size * scale).round()
		canvas.draw_texture_rect_region(texture, Rect2((inner.get_center() - size * 0.5).round(), size), region, tint)
	canvas.draw_rect(slot, HudStyle.color("panel_edge") if alive else Color(HudStyle.color("panel_edge"), 0.08), false, 1.0)


## One ability slot of the companion bar: the talent icon, the key in the
## corner, the cooldown as a shade shrinking from the top with the seconds,
## a frame in the accent while ready, the auto-cast marker; dim while the
## companion is fallen.
static func _pet_ability(canvas: CanvasItem, font: Font, slot: Rect2, ability: Dictionary, spec: Dictionary, alive: bool, clock: float) -> void:
	var cooldown := float(ability.get("cd", 0.0))
	var maximum := maxf(0.01, float(ability.get("cd_max", 1.0)))
	var ready := alive and cooldown <= 0.0
	canvas.draw_rect(slot, HudStyle.color("slot"))
	var icon := TalentIcons.make(spec, str(ability.get("icon", "burst")), alive, false)
	var icon_px := HudStyle.size("pet_icon")
	var tint := Color(0.32, 0.3, 0.3, 0.8) if not alive else Color(0.62, 0.6, 0.6) if cooldown > 0.0 else Color.WHITE
	canvas.draw_texture_rect(icon, Rect2((slot.get_center() - Vector2(icon_px, icon_px) * 0.5).round(), Vector2(icon_px, icon_px)), false, tint)
	if alive and cooldown > 0.0:
		var share := clampf(cooldown / maximum, 0.0, 1.0)
		canvas.draw_rect(Rect2(slot.position, Vector2(slot.size.x, roundf(slot.size.y * share))), Color(HudStyle.color("outline"), 0.6))
		var seconds := ("%d" % ceili(cooldown)) if cooldown >= 1.0 else ("%.1f" % cooldown)
		HudStyle.text(canvas, font, slot.get_center() + Vector2(0.0, 5.0), seconds, int(HudStyle.size("pet_number_size")), HudStyle.color("text"), 1)
	var frame := Color(HudStyle.color("accent"), 0.85) if ready else HudStyle.color("panel_edge")
	if not alive: frame = Color(HudStyle.color("panel_edge"), 0.08)
	canvas.draw_rect(slot, frame, false, 1.0)
	if alive and bool(ability.get("auto", false)):
		# auto-cast on: a soft pulsing glow around the slot and a dot in the corner
		var glow := HudStyle.color("auto")
		canvas.draw_rect(slot.grow(1.0), Color(glow, 0.35 + 0.2 * sin(clock * 5.0)), false, 1.0)
		var dot := Rect2(slot.end - Vector2(7.0, 7.0), Vector2(4.0, 4.0))
		canvas.draw_rect(dot.grow(1.0), HudStyle.color("outline"))
		canvas.draw_rect(dot, glow)
	var key := str(ability.get("key", ""))
	if not key.is_empty():
		var key_px := int(HudStyle.size("pet_key_size"))
		HudStyle.text(canvas, font, slot.position + Vector2(3.0, key_px + 1.0), key, key_px, HudStyle.color("text_dim"))


## The companion `kind`'s portrait, loaded once: {texture, region (the pixels
## the frame uses, so the figure sits centred)}; {} when the table has no
## path for the kind or the file is missing.
static func _portrait(kind: String) -> Dictionary:
	if _portraits.has(kind): return _portraits[kind]
	var entry: Dictionary = {}
	var path := str(HudStyle.table("pet_portraits").get(kind, ""))
	if not path.is_empty() and ResourceLoader.exists(path):
		var texture := load(path) as Texture2D
		if texture != null:
			var region := Rect2(Vector2.ZERO, texture.get_size())
			var image := texture.get_image()
			if image != null:
				var used := image.get_used_rect()
				if used.size.x > 0 and used.size.y > 0: region = Rect2(used)
			entry = {"texture": texture, "region": region}
	_portraits[kind] = entry
	return entry


## The talent branch `id` ({id, color, color2}) for the icon colours, from the
## profile's class data; {} (grey icons) when unknown.
static func _spec(id: String) -> Dictionary:
	if _specs.is_empty():
		for class_entry: Dictionary in Profile.data().get("classes", {}).values():
			for spec: Dictionary in class_entry.get("specs", []): _specs[str(spec.get("id", ""))] = spec
	return _specs.get(id, {})


## The hero strip at `origin`. `data`: title, hp, max_hp (half hearts), hp_f
## (float, the life shown: hp minus the fraction a poison, burn or lava has
## already taken; falls back to hp), hearts (textures; kept for compatibility,
## no longer drawn), level (int, -1 none), exp (0..1, -1 none), points (unspent
## run talent points, "+n" beside the level), low (bool: the bar pulses harder
## and its frame turns red), resources [{icon, tint, text, dim}], status
## [{text, color}], clock, key (names the bar's animation state; defaults to
## the title). Returns the strip's rectangle.
static func hero_panel(canvas: CanvasItem, font: Font, origin: Vector2, data: Dictionary) -> Rect2:
	var pad := HudStyle.size("pad")
	var bar_w := HudStyle.size("bar_width")
	var bar_h := HudStyle.size("bar_height")
	var small := int(HudStyle.size("font_small"))
	var body := int(HudStyle.size("font_body"))
	var hp := int(data.get("hp", 0))
	var max_hp := int(data.get("max_hp", 0))
	var hp_f := clampf(float(data.get("hp_f", hp)), 0.0, float(maxi(max_hp, 0)))
	var level := int(data.get("level", -1))
	var experience := float(data.get("exp", -1.0))
	var resources: Array = data.get("resources", [])
	var status: Array = data.get("status", [])
	var hp_text := "%d / %d" % [life_shown(hp, hp_f), max_hp] if hp > 0 else "GEFALLEN"
	var title := str(data.get("title", ""))
	# widths: the life bar with the level badge beside it, the header, the resources
	# the level badge grows with its number (LV 9, LV 13, LV 100)
	var badge := Vector2(18.0 + HudStyle.width(font, "LV", small) + HudStyle.width(font, str(level), body), HudStyle.size("badge_height")) if level >= 0 else Vector2.ZERO
	# the bar row is as tall as the badge beside it; the bar sits centred in it
	var row_h := maxf(bar_h, badge.y)
	var resource_w := 0.0
	for r: Dictionary in resources: resource_w += 26.0 + HudStyle.width(font, str(r.get("text", "")), body) + 14.0
	# unspent run talent points: a small "+n" beside the level badge
	var points := int(data.get("points", 0))
	var points_w := (HudStyle.width(font, "+%d" % points, body) + 10.0) if points > 0 and level >= 0 else 0.0
	var inner_w := maxf(bar_w + (badge.x + 10.0 + points_w if level >= 0 else 0.0), maxf(HudStyle.width(font, title, small) + HudStyle.width(font, hp_text, small) + 24.0, resource_w))
	var height := pad + small + 6.0 + row_h + (8.0 if experience >= 0.0 else 0.0) + (30.0 if not resources.is_empty() else 0.0) + status.size() * (small + 6.0) + pad
	var rect := Rect2(origin, Vector2(inner_w + pad * 2.0, height))
	HudStyle.panel(canvas, rect)
	var x := rect.position.x + pad
	var y := rect.position.y + pad
	HudStyle.text(canvas, font, Vector2(x, y + small), title, small, HudStyle.color("text_dim"))
	HudStyle.text(canvas, font, Vector2(rect.end.x - pad, y + small), hp_text, small, HudStyle.color("text") if hp > 0 else HudStyle.color("danger"), 2)
	y += small + 6.0
	var clock := float(data.get("clock", 0.0))
	var low := bool(data.get("low", false))
	var bar := Rect2(Vector2(x, y + floorf((row_h - bar_h) * 0.5)), Vector2(bar_w, bar_h))
	life_bar(canvas, bar, hp_f, max_hp, str(data.get("key", title)), clock, low)
	if level >= 0:
		var b := Rect2(Vector2(x + bar_w + 10.0, y + floorf((row_h - badge.y) * 0.5)), badge)
		canvas.draw_rect(b, HudStyle.color("slot"))
		canvas.draw_rect(b, HudStyle.color("panel_edge"), false, 1.0)
		HudStyle.text(canvas, font, Vector2(b.position.x + 6, b.get_center().y + 5), "LV", small, HudStyle.color("text_dim"))
		HudStyle.text(canvas, font, Vector2(b.end.x - 6, b.get_center().y + 7), str(level), body, HudStyle.color("accent"), 2)
		if points > 0:
			var glow := 0.65 + 0.35 * sin(clock * 5.0)
			HudStyle.text(canvas, font, Vector2(b.end.x + 8, b.get_center().y + 7), "+%d" % points, body, Color(HudStyle.color("accent"), glow))
	y += row_h
	if experience >= 0.0:
		HudStyle.bar(canvas, Rect2(x, y + 4, inner_w, 3), experience, HudStyle.color("exp"))
		y += 8.0
	if not resources.is_empty():
		var rx := x
		for r: Dictionary in resources:
			var icon: Texture2D = r.get("icon", null)
			var dim := bool(r.get("dim", false))
			if icon != null:
				var s := icon.get_size()
				var scale := 22.0 / maxf(s.y, 1.0)
				var draw_size := (s * scale).round()
				var tint: Color = r.get("tint", Color.WHITE)
				if dim: tint.a *= 0.25
				canvas.draw_texture_rect(icon, Rect2(Vector2(rx, y + 6 + (22.0 - draw_size.y) * 0.5), draw_size), false, tint)
				rx += draw_size.x + 4.0
			var label := str(r.get("text", ""))
			if not label.is_empty():
				HudStyle.text(canvas, font, Vector2(rx, y + 24), label, body, HudStyle.color("text_muted") if dim else HudStyle.color("text"))
				rx += HudStyle.width(font, label, body)
			rx += 14.0
		y += 30.0
	for line: Dictionary in status:
		HudStyle.text(canvas, font, Vector2(x, y + small + 4), str(line.get("text", "")), small, line.get("color", HudStyle.color("text_dim")))
		y += small + 6.0
	return rect


## A blood-filled life bar in `rect` (its ink outline included): `hp_f` of
## `max_hp` half hearts, drawn every frame. The fill drains smoothly; a hit
## leaves a brighter ghost of what was lost that holds a moment and shrinks
## away; a heal sends a light across the bar; the surface wobbles, glows in a
## slow pulse and carries drifting highlights. `key` names the bar's state
## between frames (one per bar), `clock` drives every motion (a frozen clock
## freezes the bar), `low` pulses harder and tints the frame red; the bar does
## that on its own below the low-life share. `tint` (alpha > 0) colours the
## liquid instead of blood (the companion bar's green turning red); the dark
## base, light edge and glow follow it. Looks and timings:
## assets/data/ui_hud_style.json.
static func life_bar(canvas: CanvasItem, rect: Rect2, hp_f: float, max_hp: int, key: String, clock: float, low: bool = false, tint: Color = Color(0, 0, 0, 0)) -> void:
	var cap := maxf(1.0, float(max_hp))
	var life := clampf(hp_f, 0.0, cap)
	var s := _life_state(key, life, clock)
	var hot := low or (life > 0.0 and life / cap < HudStyle.size("life_low_share"))
	var pulse := 0.5 + 0.5 * sin(clock * TAU * HudStyle.size("life_low_pulse_hz" if hot else "life_pulse_hz"))
	# the frame: an ink outline around a dark slot; the outline turns red when life runs low
	var outline := HudStyle.color("outline")
	if hot: outline = outline.lerp(HudStyle.color("danger"), 0.4 + 0.5 * pulse)
	canvas.draw_rect(rect, outline)
	var slot := rect.grow(-1.0)
	canvas.draw_rect(slot, HudStyle.color("slot"))
	var inner := slot.grow(-1.0)
	if inner.size.x < 4.0 or inner.size.y < 3.0: return
	# the surface: the right end wobbles a pixel unless the vessel is full or dry
	var wobble := roundf(sin(clock * TAU * HudStyle.size("life_wobble_hz"))) if life > 0.0 and life < cap else 0.0
	var fill_w := clampf(floorf(inner.size.x * life / cap) + wobble, 1.0 if life > 0.0 else 0.0, inner.size.x)
	# the ghost: the chunk a hit took, still lit, shrinking towards the fill
	var ghost_w := clampf(floorf(inner.size.x * (life + float(s.gap)) / cap), fill_w, inner.size.x)
	if ghost_w > fill_w:
		canvas.draw_rect(Rect2(inner.position + Vector2(fill_w, 0.0), Vector2(ghost_w - fill_w, inner.size.y)), Color(HudStyle.color("text"), 0.85))
	if fill_w <= 0.0: return
	var fill := Rect2(inner.position, Vector2(fill_w, inner.size.y))
	# the liquid's colours: blood, or the tint with its own dark base, light edge and glow
	var tinted := tint.a > 0.0
	var body := Color(tint, 1.0) if tinted else HudStyle.color("danger")
	var dark := body.darkened(0.6) if tinted else HudStyle.color("danger_dark")
	var lite := body.lightened(0.45) if tinted else HudStyle.color("blood_lite")
	var glow := body.lightened(0.2) if tinted else HudStyle.color("blood_glow")
	var glow_a := (0.18 + 0.32 * pulse) if hot else (0.07 + 0.11 * pulse)
	# a faint rim of glow one pixel around the liquid, then the liquid itself:
	# a dark base, the body, a lighter top edge and the pulse over its upper half
	canvas.draw_rect(fill.grow(1.0), Color(glow, glow_a * 0.5))
	canvas.draw_rect(fill, dark)
	var base_h := minf(3.0, floorf(fill.size.y * 0.3))
	canvas.draw_rect(Rect2(fill.position, Vector2(fill_w, fill.size.y - base_h)), body)
	canvas.draw_rect(Rect2(fill.position, Vector2(fill_w, 1.0)), lite)
	canvas.draw_rect(Rect2(fill.position, Vector2(fill_w, floorf(fill.size.y * 0.5))), Color(glow, glow_a))
	# two or three highlight pixels drift along the surface
	if fill_w >= 6.0:
		for i in range(3 if fill_w >= 24.0 else 2):
			var drift := fposmod(clock * (7.0 + 4.0 * i) + i * 37.0, fill_w - 2.0)
			var spark := Rect2(fill.position + Vector2(1.0 + floorf(drift), 0.0), Vector2(2.0 if i == 0 else 1.0, 1.0))
			canvas.draw_rect(spark, lite.lerp(Color.WHITE, 0.5 + 0.3 * sin(clock * 3.0 + i)))
	# the heal sweep: a light band running left to right, fading as it goes
	var heal := float(s.heal)
	if heal >= 0.0:
		var fade := 1.0 - heal
		canvas.draw_rect(fill, Color(1.0, 1.0, 1.0, 0.22 * fade))
		var band := Rect2(floorf(fill.position.x + heal * fill_w) - 2.0, fill.position.y, 4.0, fill.size.y).intersection(fill)
		if band.size.x > 0.0: canvas.draw_rect(band, Color(1.0, 1.0, 1.0, 0.7 * fade))


## Advances and returns the animation state of the life bar `key` for the
## `life` seen at `clock`: a loss of at least the hit threshold within one
## frame lights the lost chunk as a ghost (held, then shrunk away in the ghost
## time); a gain of that size starts the heal sweep; smaller changes (a drain,
## a trickle) just move the bar and carry the ghost along unchanged.
static func _life_state(key: String, life: float, clock: float) -> Dictionary:
	var s: Dictionary = _life_bars.get(key, {})
	if s.is_empty():
		s = {"gap": 0.0, "hold": 0.0, "speed": 0.0, "heal": -1.0, "last": life, "clock": clock}
		_life_bars[key] = s
	var delta := clampf(clock - float(s.clock), 0.0, 0.25)
	var change := life - float(s.last)
	var threshold := HudStyle.size("life_hit_threshold")
	var gap := float(s.gap)
	if change <= -threshold:
		# a hit: the lost chunk stays lit, holds a moment, then shrinks away
		gap -= change
		s.hold = HudStyle.size("life_ghost_hold")
		s.speed = gap / maxf(0.05, HudStyle.size("life_ghost_time"))
	elif change >= threshold:
		# a heal: the ghost is gone, a light sweeps the bar
		gap = 0.0
		s.heal = 0.0
	s.hold = maxf(0.0, float(s.hold) - delta)
	if float(s.hold) <= 0.0 and gap > 0.0:
		gap = maxf(0.0, gap - delta * float(s.speed))
	s.gap = gap
	if float(s.heal) >= 0.0:
		s.heal = float(s.heal) + delta / maxf(0.05, HudStyle.size("life_heal_sweep"))
		if float(s.heal) >= 1.0: s.heal = -1.0
	s.last = life
	s.clock = clock
	return s


## The life to print for a hero with `hp` whole half hearts whose bar shows
## `hp_f`: the ceiling of the shown life, at least 1 while the hero stands,
## never above hp (0 once fallen).
static func life_shown(hp: int, hp_f: float) -> int:
	if hp <= 0: return 0
	return clampi(ceili(hp_f - 0.001), 1, hp)


## Heart icons for `hp` of `max_hp` (two HP per heart): "full", "half", "empty".
static func heart_icons(hp: int, max_hp: int) -> Array[String]:
	var result: Array[String] = []
	var health := clampi(hp, 0, maxi(max_hp, 0))
	for index in range(ceili(maxi(max_hp, 0) / 2.0)):
		var left := health - index * 2
		result.append("full" if left >= 2 else "half" if left == 1 else "empty")
	return result


## The floor panel at the top right of a `screen`. `data`: title, subtitle,
## tag, tag_color, alpha. Returns the area left for the mini-map.
static func floor_panel(canvas: CanvasItem, font: Font, screen: Vector2, data: Dictionary) -> Rect2:
	var rect := floor_rect(screen)
	var alpha := float(data.get("alpha", 1.0))
	var pad := HudStyle.size("pad")
	var small := int(HudStyle.size("font_small"))
	HudStyle.panel(canvas, rect, alpha)
	var x := rect.position.x + pad
	var y := rect.position.y + pad
	HudStyle.text(canvas, font, Vector2(x, y + 16), str(data.get("title", "")), int(HudStyle.size("font_title")), Color(HudStyle.color("text"), alpha))
	var line := y + 34.0
	var subtitle := str(data.get("subtitle", ""))
	if not subtitle.is_empty():
		HudStyle.text(canvas, font, Vector2(x, line), subtitle, small, Color(HudStyle.color("text_dim"), alpha))
		line += small + 6.0
	# the state of the floor (fight, horde, explore) on its own line
	var tag := str(data.get("tag", ""))
	if not tag.is_empty():
		var tint: Color = data.get("tag_color", HudStyle.color("text_dim"))
		HudStyle.text(canvas, font, Vector2(x, line), tag, small, Color(tint, tint.a * alpha))
	return map_area(screen)


## The mini-map's area inside the floor panel (under title, place and state;
## fixed, so the map never jumps when a line is empty).
static func map_area(screen: Vector2) -> Rect2:
	var rect := floor_rect(screen)
	var pad := HudStyle.size("pad")
	var small := HudStyle.size("font_small")
	var top := rect.position.y + pad + 34.0 + (small + 6.0) * 2.0 - small + 4.0
	return Rect2(rect.position.x + pad, top, rect.size.x - pad * 2.0, rect.end.y - pad - top)


## Where the floor panel sits on a `screen`.
static func floor_rect(screen: Vector2) -> Rect2:
	var margin := HudStyle.size("margin")
	var width := HudStyle.size("map_panel_width")
	return Rect2(screen.x - margin - width, margin, width, HudStyle.size("map_panel_height"))


## The "ESC · MENÜ" chip under the floor panel (drawn; the crypt uses a real button there).
static func menu_rect(screen: Vector2) -> Rect2:
	var panel := floor_rect(screen)
	return Rect2(panel.position.x, panel.end.y + 6, panel.size.x, 28)


static func menu_chip(canvas: CanvasItem, font: Font, screen: Vector2, label: String, alpha: float = 1.0, hot: bool = false) -> void:
	var rect := menu_rect(screen)
	HudStyle.panel(canvas, rect, alpha)
	if hot: canvas.draw_rect(rect, Color(HudStyle.color("accent"), 0.8 * alpha), false, 1.0)
	HudStyle.text(canvas, font, Vector2(rect.get_center().x, rect.get_center().y + 5), label, int(HudStyle.size("font_small")), Color(HudStyle.color("text") if hot else HudStyle.color("text_dim"), alpha), 1)


## The boss bar at the top centre. `data`: name, tag, ratio (0..1), chip
## (trailing white share), flash (0..1), segments (Array of 0..1 fills; empty =
## one bar), value (text right of the name), boss (bool: end boss). Leaves room
## for the corner panels.
static func boss_bar(canvas: CanvasItem, font: Font, screen: Vector2, data: Dictionary) -> Rect2:
	var margin := HudStyle.size("margin")
	var room := screen.x - 2.0 * (HudStyle.size("map_panel_width") + margin * 2.0)
	var width := minf(HudStyle.size("boss_bar_width"), room)
	if width < 200.0: return Rect2()
	var rect := Rect2((screen.x - width) * 0.5, margin, width, 52)
	HudStyle.panel(canvas, rect)
	var pad := HudStyle.size("pad")
	var small := int(HudStyle.size("font_small"))
	HudStyle.text(canvas, font, Vector2(rect.position.x + pad, rect.position.y + pad + 14), str(data.get("name", "")), int(HudStyle.size("font_title")), HudStyle.color("text"))
	HudStyle.text(canvas, font, Vector2(rect.end.x - pad, rect.position.y + pad + 13), str(data.get("value", "")), small, HudStyle.color("text_dim"), 2)
	var track := Rect2(rect.position.x + pad, rect.end.y - pad - 10, width - pad * 2.0, 10)
	var segments: Array = data.get("segments", [])
	var fill := HudStyle.color("danger").lerp(HudStyle.color("text"), clampf(float(data.get("flash", 0.0)), 0.0, 1.0) * 0.6)
	if segments.size() <= 1:
		var ratio := float(data.get("ratio", segments[0] if segments.size() == 1 else 1.0))
		canvas.draw_rect(track, HudStyle.color("danger_dark"))
		canvas.draw_rect(Rect2(track.position, Vector2(floorf(track.size.x * maxf(float(data.get("chip", ratio)), ratio)), track.size.y)), Color(HudStyle.color("text"), 0.85))
		canvas.draw_rect(Rect2(track.position, Vector2(floorf(track.size.x * ratio), track.size.y)), fill)
		for quarter in [0.25, 0.5, 0.75]:
			canvas.draw_rect(Rect2(track.position + Vector2(floorf(track.size.x * quarter), 0), Vector2(1, track.size.y)), Color(HudStyle.color("outline"), 0.6))
	else:
		var gap := 6.0
		var w := (track.size.x - gap * (segments.size() - 1)) / segments.size()
		for i in range(segments.size()):
			var seg := Rect2(track.position + Vector2(i * (w + gap), 0), Vector2(w, track.size.y))
			canvas.draw_rect(seg, HudStyle.color("danger_dark"))
			canvas.draw_rect(Rect2(seg.position, Vector2(floorf(w * clampf(float(segments[i]), 0.0, 1.0)), seg.size.y)), fill)
	var tag := str(data.get("tag", ""))
	if not tag.is_empty():
		HudStyle.text(canvas, font, Vector2(screen.x * 0.5, rect.end.y + 16), tag, small, HudStyle.color("text_dim"), 1)
	return rect


## A floor or level banner centred at height `y`: title and a smaller line.
static func banner(canvas: CanvasItem, font: Font, screen: Vector2, y: float, title: String, sub: String, alpha: float) -> void:
	if alpha <= 0.0: return
	var big := int(HudStyle.size("font_banner"))
	var small := int(HudStyle.size("font_small"))
	var width := maxf(HudStyle.width(font, title, big), HudStyle.width(font, sub, small)) + 56.0
	var rect := Rect2((screen.x - width) * 0.5, y, width, 62 if not sub.is_empty() else 46)
	HudStyle.panel(canvas, rect, alpha)
	HudStyle.text(canvas, font, Vector2(screen.x * 0.5, rect.position.y + 34), title, big, Color(HudStyle.color("text"), alpha), 1)
	if not sub.is_empty():
		HudStyle.text(canvas, font, Vector2(screen.x * 0.5, rect.position.y + 53), sub.to_upper(), small, Color(HudStyle.color("accent"), alpha), 1)


## The result panel in the middle of the screen, the same in every world: a
## floor won, a run ended by death, a zone conquered. `data`: title, tone
## ("win", "loss", "floor"), lines [[label, value]], note (one line under the
## rows, e.g. soul crystals), hints (e.g. "E · NEUER LAUF   ESC · MENÜ").
static func result_panel(canvas: CanvasItem, font: Font, screen: Vector2, data: Dictionary) -> Rect2:
	canvas.draw_rect(Rect2(Vector2.ZERO, screen), Color(HudStyle.color("outline"), 0.62))
	var lines: Array = data.get("lines", [])
	var big := int(HudStyle.size("font_banner"))
	var body := int(HudStyle.size("font_body"))
	var small := int(HudStyle.size("font_small"))
	# as wide as its longest row (label, gap, value), at least 460 px
	var width := maxf(460.0, HudStyle.width(font, str(data.get("title", "")), big) + 80.0)
	for row: Array in lines:
		width = maxf(width, HudStyle.width(font, str(row[0]), body) + HudStyle.width(font, str(row[1]), body) + 96.0)
	width = minf(width, screen.x - 64.0)
	var height := 72.0 + lines.size() * 26.0 + 36.0 + 40.0
	var rect := Rect2((screen - Vector2(width, height)) * 0.5, Vector2(width, height))
	HudStyle.panel(canvas, rect)
	var tone := str(data.get("tone", "floor"))
	var tint := HudStyle.color("danger") if tone == "loss" else HudStyle.color("accent")
	canvas.draw_rect(Rect2(rect.position, Vector2(rect.size.x, 3)), tint)
	HudStyle.text(canvas, font, Vector2(screen.x * 0.5, rect.position.y + 44), str(data.get("title", "")), big, tint, 1)
	var y := rect.position.y + 84.0
	for row: Array in lines:
		HudStyle.text(canvas, font, Vector2(rect.position.x + 28, y), str(row[0]), body, HudStyle.color("text_dim"))
		HudStyle.text(canvas, font, Vector2(rect.end.x - 28, y), str(row[1]), body, HudStyle.color("text"), 2)
		y += 26.0
	var note := str(data.get("note", ""))
	if not note.is_empty():
		HudStyle.text(canvas, font, Vector2(screen.x * 0.5, y + 10), note, small, HudStyle.color("accent"), 1)
	HudStyle.text(canvas, font, Vector2(screen.x * 0.5, rect.end.y - 16), str(data.get("hints", "")), small, HudStyle.color("text_dim"), 1)
	return rect


## A hint centred at height `y` (hints stack over the skill bar).
static func toast(canvas: CanvasItem, font: Font, screen: Vector2, y: float, value: String, alpha: float) -> void:
	if alpha <= 0.0: return
	var body := int(HudStyle.size("font_body"))
	var width := HudStyle.width(font, value, body) + 40.0
	var rect := Rect2((screen.x - width) * 0.5, y - 17, width, 34)
	HudStyle.panel(canvas, rect, alpha)
	canvas.draw_rect(Rect2(rect.position, Vector2(3, rect.size.y)), Color(HudStyle.color("accent"), alpha))
	HudStyle.text(canvas, font, Vector2(screen.x * 0.5 + 1, y + 6), value, body, Color(HudStyle.color("text"), alpha), 1)


## An interaction prompt centred on `at`: a key cap and what it does.
static func prompt(canvas: CanvasItem, font: Font, at: Vector2, key: String, label: String) -> void:
	var body := int(HudStyle.size("font_body"))
	var width := HudStyle.width(font, label, body) + 52.0
	var rect := Rect2(at.x - width * 0.5, at.y - 17, width, 34)
	HudStyle.panel(canvas, rect)
	var cap := Rect2(rect.position + Vector2(6, 6), Vector2(22, 22))
	canvas.draw_rect(cap, HudStyle.color("slot"))
	canvas.draw_rect(cap, Color(HudStyle.color("accent"), 0.9), false, 1.0)
	HudStyle.text(canvas, font, Vector2(cap.get_center().x, cap.get_center().y + 6), key, body, HudStyle.color("accent"), 1)
	HudStyle.text(canvas, font, Vector2(cap.end.x + 10, at.y + 6), label, body, HudStyle.color("text"))
