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
const STYLE_PATH := "res://assets/data/ui_hud_style.json"

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
# The HUD rules (ui_hud_style.json "rules"), read once.
static var _rules: Dictionary = {}
## False: no mini-map corner panel (the story worlds; the map lives on M and in
## the pause). floor_rect then has no height, so the ESC and talent chips move
## up into the corner. The story game sets it while it runs and restores it.
static var map_corner := true


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
## (zero size without a companion). `alpha` below 1 steps the bar back (a
## companion at full life with nothing cooling down).
static func pet_panel(canvas: CanvasItem, font: Font, origin: Vector2, width: float, pet: Dictionary, clock: float, alpha: float = 1.0) -> Rect2:
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
	# each slot's key (5, 6) stands in its own column left of the slot, never on the icon
	var key_px := int(HudStyle.size("pet_key_size"))
	var key_w := HudStyle.width(font, "6", key_px) + 4.0
	var slots_w := abilities.size() * (key_w + slot_px) + maxi(0, abilities.size() - 1) * gap
	var slot_x := rect.end.x - pad - slots_w
	var spec := _spec(str(pet.get("spec", "")))
	for index in range(abilities.size()):
		var slot := Rect2(Vector2(slot_x + key_w + index * (key_w + slot_px + gap), rect.position.y + floorf((rect.size.y - slot_px) * 0.5)), Vector2(slot_px, slot_px))
		_pet_ability(canvas, font, slot, abilities[index], spec, alive, clock)
		var key := str((abilities[index] as Dictionary).get("key", ""))
		if not key.is_empty():
			HudStyle.text(canvas, font, Vector2(slot.position.x - key_w, slot.get_center().y + floorf(key_px * 0.45)), key, key_px, HudStyle.color("text_dim") if alive else HudStyle.color("text_muted"))
		_pet_slots.append(slot)
	# the text column between them: the name over the life bar
	var x := portrait.end.x + 8.0
	var right := (slot_x - 8.0) if not abilities.is_empty() else (rect.end.x - pad)
	var column_w := maxf(0.0, right - x)
	var bar_h := HudStyle.size("pet_bar_height")
	var top := rect.position.y + floorf((rect.size.y - (small + 4.0 + bar_h)) * 0.5)
	var baseline := top + small
	var bar := Rect2(Vector2(x, top + small + 4.0), Vector2(column_w, bar_h))
	if pet.has("blood"):
		bar.size.y = maxf(3.0, bar.size.y - 5.0)
		var blood_bar := Rect2(Vector2(x, bar.end.y + 2.0), Vector2(column_w, 3.0))
		canvas.draw_rect(blood_bar, HudStyle.color("track"))
		canvas.draw_rect(Rect2(blood_bar.position, Vector2(column_w * clampf(float(pet.blood) / 100.0, 0, 1), 3.0)), Color("e65c63"))
	var blood_number := "%d%%" % roundi(float(pet.get("blood", 0))) if pet.has("blood") else ""
	var name_room := column_w - (HudStyle.width(font, blood_number, small) + 8.0 if not blood_number.is_empty() else 0.0)
	HudStyle.text(canvas, font, Vector2(x, baseline), ellipsis(font, name, small, name_room), small, HudStyle.color("text") if alive else HudStyle.color("text_muted"))
	if not blood_number.is_empty(): HudStyle.text(canvas, font, Vector2(right, baseline), blood_number, small, Color("f4917a"), 2)
	if alive:
		var hp_max := maxf(1.0, float(pet.get("hp_max", 1.0)))
		var hp := clampf(float(pet.get("hp", 0.0)), 0.0, hp_max)
		var share := hp / hp_max
		# the fill: green while hale, red when the share runs low
		var tint := HudStyle.color("ok").lerp(HudStyle.color("danger"), clampf((0.7 - share) / 0.45, 0.0, 1.0))
		if bool(pet.get("duration", false)): tint = Color("83d1ca")
		life_bar(canvas, bar, hp, ceili(hp_max), "pet:" + kind, clock, false, tint)
		# the numbers only where they fit beside the name (the crypt's strip is narrow)
		var numbers := "%d / %d" % [ceili(hp - 0.001) if hp > 0.0 else 0, ceili(hp_max)]
		if bool(pet.get("duration", false)): numbers = "%d s" % ceili(hp)
		if not pet.has("blood") and HudStyle.width(font, name, small) + HudStyle.width(font, numbers, small) + 12.0 <= column_w:
			HudStyle.text(canvas, font, Vector2(right, baseline), numbers, small, HudStyle.color("text_dim"), 2)
	else:
		# fallen: no bar, the countdown in its place
		var wait := float(pet.get("respawn", 0.0))
		var fallen := ("GEFALLEN · %d s" % ceili(wait)) if wait > 0.0 else "GEFALLEN"
		var pulse := 0.75 + 0.25 * sin(clock * TAU * HudStyle.size("life_low_pulse_hz") * 0.5)
		HudStyle.text(canvas, font, Vector2(x, bar.end.y + 2.0), fallen, small, Color(HudStyle.color("danger"), pulse))
	dim(canvas, rect, alpha)
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
		# the seconds at the bottom right (the key stands left of the slot)
		HudStyle.text(canvas, font, slot.end - Vector2(3.0, 4.0), seconds, int(HudStyle.size("pet_number_size")), HudStyle.color("text"), 2)
	var frame := Color(HudStyle.color("accent"), 0.85) if ready else HudStyle.color("panel_edge")
	if not alive: frame = Color(HudStyle.color("panel_edge"), 0.08)
	canvas.draw_rect(slot, frame, false, 1.0)
	if alive and bool(ability.get("auto", false)):
		# auto-cast on: a soft pulsing glow around the slot and a dot in the corner
		var glow := HudStyle.color("auto")
		canvas.draw_rect(slot.grow(1.0), Color(glow, 0.35 + 0.2 * sin(clock * 5.0)), false, 1.0)
		var dot := Rect2(Vector2(slot.end.x - 7.0, slot.position.y + 3.0), Vector2(4.0, 4.0))
		canvas.draw_rect(dot.grow(1.0), HudStyle.color("outline"))
		canvas.draw_rect(dot, glow)


## The companion `kind`'s portrait, loaded once: {texture, region (the pixels
## the frame uses, so the figure sits centred)}; {} when the table has no
## path for the kind or the file is missing.
static func _portrait(kind: String) -> Dictionary:
	if _portraits.has(kind): return _portraits[kind]
	if kind == "soul_guardian":
		_portraits[kind] = {"texture": load("res://assets/vfx/soul_guardian/rig/bind.png"), "region": Rect2(43, 7, 22, 23)}
		return _portraits[kind]
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
## the title), level_label (the badge's word, default "LV"), hp_unit (after
## the life numbers, e.g. "LP"), resource_alpha (0..1: the resource row fades
## as a whole; at 0 it takes no room), fixed_rows (the story worlds: the strip
## keeps one height; resources and status share one row that is always there,
## the resources left, the status lines right-aligned in one line, cut with
## "+n" when they do not fit). Returns the strip's rectangle.
static func hero_panel(canvas: CanvasItem, font: Font, origin: Vector2, data: Dictionary) -> Rect2:
	if bool(data.get("compact", false)):
		return hero_compact(canvas, font, origin, data)
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
	var resource_alpha := clampf(float(data.get("resource_alpha", 1.0)), 0.0, 1.0)
	var resources: Array = data.get("resources", []) if resource_alpha > 0.0 else []
	var status: Array = data.get("status", [])
	var unit := str(data.get("hp_unit", ""))
	var hp_text := ("%d / %d" % [life_shown(hp, hp_f), max_hp] + (" " + unit if unit != "" else "")) if hp > 0 else "GEFALLEN"
	var level_label := str(data.get("level_label", "LV"))
	var title := str(data.get("title", ""))
	# widths: the life bar with the level badge beside it, the header, the resources
	# the level badge grows with its number (LV 9, LV 13, LV 100)
	var badge := Vector2(18.0 + HudStyle.width(font, level_label, small) + HudStyle.width(font, str(level), body), HudStyle.size("badge_height")) if level >= 0 else Vector2.ZERO
	# the bar row is as tall as the badge beside it; the bar sits centred in it
	var row_h := maxf(bar_h, badge.y)
	var resource_w := 0.0
	for r: Dictionary in resources: resource_w += 26.0 + HudStyle.width(font, str(r.get("text", "")), body) + 14.0
	# unspent run talent points: a small "+n" beside the level badge
	var points := int(data.get("points", 0))
	var points_w := (HudStyle.width(font, "+%d" % points, body) + 10.0) if points > 0 and level >= 0 else 0.0
	var inner_w := maxf(bar_w + (badge.x + 10.0 + points_w if level >= 0 else 0.0), maxf(HudStyle.width(font, title, small) + HudStyle.width(font, hp_text, small) + 24.0, resource_w))
	var fixed := bool(data.get("fixed_rows", false))
	var height := pad + small + 6.0 + row_h + (8.0 if experience >= 0.0 else 0.0) + (30.0 if not resources.is_empty() else 0.0) + status.size() * (small + 6.0) + pad
	if fixed:
		height = pad + small + 6.0 + row_h + (8.0 if experience >= 0.0 else 0.0) + 30.0 + pad
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
		HudStyle.text(canvas, font, Vector2(b.position.x + 6, b.get_center().y + floorf(small * 0.5) - 1.0), level_label, small, HudStyle.color("text_dim"))
		HudStyle.text(canvas, font, Vector2(b.end.x - 6, b.get_center().y + 7), str(level), body, HudStyle.color("accent"), 2)
		if points > 0:
			var glow := 0.65 + 0.35 * sin(clock * 5.0)
			HudStyle.text(canvas, font, Vector2(b.end.x + 8, b.get_center().y + 7), "+%d" % points, body, Color(HudStyle.color("accent"), glow))
	y += row_h
	if experience >= 0.0:
		HudStyle.bar(canvas, Rect2(x, y + 4, inner_w, 3), experience, HudStyle.color("exp"))
		y += 8.0
	var rx := x
	if not resources.is_empty():
		for r: Dictionary in resources:
			var icon: Texture2D = r.get("icon", null)
			var dim := bool(r.get("dim", false))
			if icon != null:
				var s := icon.get_size()
				var scale := 22.0 / maxf(s.y, 1.0)
				var draw_size := (s * scale).round()
				var tint: Color = r.get("tint", Color.WHITE)
				if dim: tint.a *= 0.25
				tint.a *= resource_alpha
				canvas.draw_texture_rect(icon, Rect2(Vector2(rx, y + 6 + (22.0 - draw_size.y) * 0.5), draw_size), false, tint)
				rx += draw_size.x + 4.0
			var label := str(r.get("text", ""))
			if not label.is_empty():
				var ink: Color = HudStyle.color("text_muted") if dim else HudStyle.color("text")
				HudStyle.text(canvas, font, Vector2(rx, y + 24), label, body, Color(ink, ink.a * resource_alpha))
				rx += HudStyle.width(font, label, body)
			rx += 14.0
		if not fixed: y += 30.0
	if fixed:
		_status_row(canvas, font, Rect2(rx if not resources.is_empty() else x, y, x + inner_w - (rx if not resources.is_empty() else x), 30.0), status, small)
		return rect
	for line: Dictionary in status:
		HudStyle.text(canvas, font, Vector2(x, y + small + 4), str(line.get("text", "")), small, line.get("color", HudStyle.color("text_dim")))
		y += small + 6.0
	return rect


# The status lines in one row, right-aligned in `area`, each in its colour,
# a thin bar between them. When they do not fit, a line with a "short" form
# takes it first, then lines go from the end and become "+n" at the left (so
# the first lines, the hero's conditions, stay longest).
static func _status_row(canvas: CanvasItem, font: Font, area: Rect2, status: Array, size: int) -> void:
	if status.is_empty() or area.size.x <= 0.0:
		return
	var gap := 14.0
	var texts: Array[String] = []
	var widths: Array[float] = []
	for line: Dictionary in status:
		texts.append(str(line.get("text", "")))
		widths.append(HudStyle.width(font, texts[-1], size))
	# keep the first lines that fit (with room for "+n" when some must go)
	var shown := status.size()
	while shown > 0:
		var total := 0.0
		for i in range(shown): total += widths[i] + (gap if i > 0 else 0.0)
		var rest := status.size() - shown
		if rest > 0: total += gap + HudStyle.width(font, "+%d" % rest, size)
		if total <= area.size.x: break
		var shortened := false
		for i in range(shown - 1, -1, -1):
			var line: Dictionary = status[i]
			if line.has("short") and texts[i] != str(line.short):
				texts[i] = str(line.short)
				widths[i] = HudStyle.width(font, texts[i], size)
				shortened = true
				break
		if not shortened:
			shown -= 1
	var baseline := area.position.y + 24.0
	var right := area.end.x
	for i in range(shown - 1, -1, -1):
		var line: Dictionary = status[i]
		HudStyle.text(canvas, font, Vector2(right, baseline), texts[i], size, line.get("color", HudStyle.color("text_dim")), 2)
		right -= widths[i]
		if i > 0:
			canvas.draw_rect(Rect2(right - gap * 0.5 - 1.0, baseline - size + 2.0, 2.0, size - 2.0), Color(HudStyle.color("panel_edge"), 0.8))
			right -= gap
	if shown < status.size():
		HudStyle.text(canvas, font, Vector2(right - (gap if shown > 0 else 0.0), baseline), "+%d" % (status.size() - shown), size, HudStyle.color("text_dim"), 2)


## The slim hero strip of the story worlds (hero_panel with compact): one row
## with the life bar, the life numbers and the level badge, the thin EXP line
## under it, and one more row only while there is something to say (resources,
## conditions, blessings: the resources fade after a quiet while). No name: the
## character window (C) carries it. Same `data` as hero_panel; bar_width
## (ui_hud_style.json compact_bar_width) narrows the bar.
static func hero_compact(canvas: CanvasItem, font: Font, origin: Vector2, data: Dictionary) -> Rect2:
	var pad := HudStyle.size("pad")
	var bar_w := HudStyle.size("compact_bar_width") if HudStyle.size("compact_bar_width") > 0.0 else HudStyle.size("bar_width")
	var bar_h := HudStyle.size("bar_height")
	var small := int(HudStyle.size("font_small"))
	var body := int(HudStyle.size("font_body"))
	var hp := int(data.get("hp", 0))
	var max_hp := int(data.get("max_hp", 0))
	var hp_f := clampf(float(data.get("hp_f", hp)), 0.0, float(maxi(max_hp, 0)))
	var level := int(data.get("level", -1))
	var experience := float(data.get("exp", -1.0))
	var resource_alpha := clampf(float(data.get("resource_alpha", 1.0)), 0.0, 1.0)
	var resources: Array = data.get("resources", []) if resource_alpha > 0.0 else []
	var status: Array = data.get("status", [])
	var unit := str(data.get("hp_unit", ""))
	var hp_text := ("%d / %d" % [life_shown(hp, hp_f), max_hp] + (" " + unit if unit != "" else "")) if hp > 0 else "GEFALLEN"
	var level_label := str(data.get("level_label", "LV"))
	var badge := Vector2(18.0 + HudStyle.width(font, level_label, small) + HudStyle.width(font, str(level), body), HudStyle.size("badge_height")) if level >= 0 else Vector2.ZERO
	var points := int(data.get("points", 0))
	var points_w := (HudStyle.width(font, "+%d" % points, body) + 10.0) if points > 0 and level >= 0 else 0.0
	var row_h := maxf(bar_h, badge.y)
	# the numbers stand in a fixed width (the widest they get), so the badge never jumps while the life drains
	var hp_w := maxf(HudStyle.width(font, hp_text, small), HudStyle.width(font, "%d / %d" % [max_hp, max_hp] + (" " + unit if unit != "" else ""), small))
	var inner_w := bar_w + 10.0 + hp_w + (10.0 + badge.x + points_w if level >= 0 else 0.0)
	var extra := not resources.is_empty() or not status.is_empty()
	var height := pad + row_h + (8.0 if experience >= 0.0 else 0.0) + (30.0 if extra else 0.0) + pad
	var rect := Rect2(origin, Vector2(inner_w + pad * 2.0, height))
	HudStyle.panel(canvas, rect)
	var x := rect.position.x + pad
	var y := rect.position.y + pad
	var clock := float(data.get("clock", 0.0))
	var low := bool(data.get("low", false))
	life_bar(canvas, Rect2(Vector2(x, y + floorf((row_h - bar_h) * 0.5)), Vector2(bar_w, bar_h)), hp_f, max_hp, str(data.get("key", data.get("title", ""))), clock, low)
	HudStyle.text(canvas, font, Vector2(x + bar_w + 10.0, y + floorf(row_h * 0.5) + floorf(small * 0.5) - 1.0), hp_text, small, HudStyle.color("text") if hp > 0 else HudStyle.color("danger"))
	if level >= 0:
		var b := Rect2(Vector2(x + bar_w + 10.0 + hp_w + 10.0, y + floorf((row_h - badge.y) * 0.5)), badge)
		canvas.draw_rect(b, HudStyle.color("slot"))
		canvas.draw_rect(b, HudStyle.color("panel_edge"), false, 1.0)
		HudStyle.text(canvas, font, Vector2(b.position.x + 6, b.get_center().y + floorf(small * 0.5) - 1.0), level_label, small, HudStyle.color("text_dim"))
		HudStyle.text(canvas, font, Vector2(b.end.x - 6, b.get_center().y + 7), str(level), body, HudStyle.color("accent"), 2)
		if points > 0:
			var glow := 0.65 + 0.35 * sin(clock * 5.0)
			HudStyle.text(canvas, font, Vector2(b.end.x + 8, b.get_center().y + 7), "+%d" % points, body, Color(HudStyle.color("accent"), glow))
	y += row_h
	if experience >= 0.0:
		HudStyle.bar(canvas, Rect2(x, y + 4, inner_w, 3), experience, HudStyle.color("exp"))
		y += 8.0
	if not extra:
		return rect
	var rx := x
	for r: Dictionary in resources:
		var icon: Texture2D = r.get("icon", null)
		var dim := bool(r.get("dim", false))
		if icon != null:
			var s := icon.get_size()
			var draw_size := (s * (20.0 / maxf(s.y, 1.0))).round()
			var tint: Color = r.get("tint", Color.WHITE)
			if dim: tint.a *= 0.25
			tint.a *= resource_alpha
			canvas.draw_texture_rect(icon, Rect2(Vector2(rx, y + 7 + (20.0 - draw_size.y) * 0.5), draw_size), false, tint)
			rx += draw_size.x + 4.0
		var label := str(r.get("text", ""))
		if not label.is_empty():
			var ink: Color = HudStyle.color("text_muted") if dim else r.get("ink", HudStyle.color("text"))
			HudStyle.text(canvas, font, Vector2(rx, y + 24), label, body, Color(ink, ink.a * resource_alpha))
			rx += HudStyle.width(font, label, body)
		rx += 14.0
	_status_row(canvas, font, Rect2(rx, y, x + inner_w - rx, 30.0), status, small)
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


## The floor panel at the top right of a `screen`. `data`: title, subtitle
## (cut to fit), tag (shown in the subtitle's place, e.g. "VERRIEGELT · 3"),
## tag_color, alpha. Returns the area left for the mini-map.
static func floor_panel(canvas: CanvasItem, font: Font, screen: Vector2, data: Dictionary) -> Rect2:
	var rect := floor_rect(screen)
	var alpha := float(data.get("alpha", 1.0))
	var pad := HudStyle.size("pad")
	var small := int(HudStyle.size("font_small"))
	# an opaque base: world sprites and snow never show through the map as false icons
	canvas.draw_rect(rect, Color(HudStyle.color("map_base"), alpha))
	HudStyle.panel(canvas, rect, alpha)
	var x := rect.position.x + pad
	var y := rect.position.y + pad
	HudStyle.text(canvas, font, Vector2(x, y + 16), str(data.get("title", "")), int(HudStyle.size("font_title")), Color(HudStyle.color("text"), alpha))
	# one line under the title: a fight's state while there is one, else the place
	var room := rect.size.x - pad * 2.0
	var tag := str(data.get("tag", ""))
	if not tag.is_empty():
		var tint: Color = data.get("tag_color", HudStyle.color("text_dim"))
		HudStyle.text(canvas, font, Vector2(x, y + 36.0), ellipsis(font, tag, small, room), small, Color(tint, tint.a * alpha))
	else:
		HudStyle.text(canvas, font, Vector2(x, y + 36.0), ellipsis(font, str(data.get("subtitle", "")), small, room), small, Color(HudStyle.color("text_dim"), alpha))
	return map_area(screen)


## The mini-map's area inside the floor panel, under the title and its one
## line (fixed, so the map never jumps).
static func map_area(screen: Vector2) -> Rect2:
	var rect := floor_rect(screen)
	var pad := HudStyle.size("pad")
	var top := rect.position.y + pad + 36.0 + 8.0
	return Rect2(rect.position.x + pad, top, rect.size.x - pad * 2.0, rect.end.y - pad - top)


## Where the floor panel sits on a `screen`.
static func floor_rect(screen: Vector2) -> Rect2:
	var margin := HudStyle.size("margin")
	var width := HudStyle.size("map_panel_width")
	if not map_corner:
		return Rect2(screen.x - margin - width, margin - 6.0, width, 0.0)
	return Rect2(screen.x - margin - width, margin, width, HudStyle.size("map_panel_height"))


## The "ESC · MENÜ" chip under the floor panel (drawn; the crypt uses a real button there).
static func menu_rect(screen: Vector2) -> Rect2:
	var panel := floor_rect(screen)
	return Rect2(panel.position.x, panel.end.y + 6, panel.size.x, 28)


## The talent chip under the ESC chip: "TALENTE · K", lit with "+n" while points are free.
static func talent_rect(screen: Vector2) -> Rect2:
	var above := menu_rect(screen)
	return Rect2(above.position.x, above.end.y + 4, above.size.x, above.size.y)


## Draws the talent chip; `free` above 0 lights it in the accent and shows "+free".
static func talent_chip(canvas: CanvasItem, font: Font, screen: Vector2, free: int, alpha: float, hot: bool, clock: float) -> void:
	var rect := talent_rect(screen)
	var lit := free > 0
	var shown := 1.0 if hot else (0.8 + 0.2 * sin(clock * 4.0) if lit else alpha)
	HudStyle.panel(canvas, rect, shown)
	if lit or hot: canvas.draw_rect(rect, Color(HudStyle.color("accent"), 0.8 * shown), false, 1.0)
	var size := int(HudStyle.size("font_small"))
	var label := "TALENTE · K"
	var plus := ("  +%d" % free) if lit else ""
	var width := HudStyle.width(font, label + plus, size)
	var x := rect.get_center().x - width * 0.5
	var y := rect.get_center().y + 5
	HudStyle.text(canvas, font, Vector2(x, y), label, size, Color(HudStyle.color("text") if (hot or lit) else HudStyle.color("text_dim"), shown))
	if lit:
		HudStyle.text(canvas, font, Vector2(x + HudStyle.width(font, label, size), y), plus, size, Color(HudStyle.color("accent"), shown))


static func menu_chip(canvas: CanvasItem, font: Font, screen: Vector2, label: String, alpha: float = 1.0, hot: bool = false) -> void:
	var rect := menu_rect(screen)
	HudStyle.panel(canvas, rect, alpha)
	if hot: canvas.draw_rect(rect, Color(HudStyle.color("accent"), 0.8 * alpha), false, 1.0)
	HudStyle.text(canvas, font, Vector2(rect.get_center().x, rect.get_center().y + 5), label, int(HudStyle.size("font_small")), Color(HudStyle.color("text") if hot else HudStyle.color("text_dim"), alpha), 1)


## The boss bar at the top centre. `data`: name, tag, ratio (0..1), chip
## (trailing white share), flash (0..1), segments (Array of 0..1 fills; empty =
## one bar), value (text right of the name), boss (bool: end boss), left /
## right (px: the free span between the hero strip's right end and the floor
## panel's left edge; the bar centres in it, a margin off both, never over
## them). Without them it leaves room for two corner panels.
static func boss_bar(canvas: CanvasItem, font: Font, screen: Vector2, data: Dictionary) -> Rect2:
	var margin := HudStyle.size("margin")
	var left := float(data.get("left", margin + HudStyle.size("map_panel_width") + margin))
	var right := float(data.get("right", screen.x - margin - HudStyle.size("map_panel_width") - margin))
	var width := minf(HudStyle.size("boss_bar_width"), right - left - margin * 2.0)
	if width < 200.0: return Rect2()
	var rect := Rect2(floorf((left + right - width) * 0.5), margin, width, 52)
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
		# the subtitle sits on its own small plate under the bar, readable on any wall
		var tag_w := HudStyle.width(font, tag, small) + 24.0
		var plate := Rect2(floorf(rect.get_center().x - tag_w * 0.5), rect.end.y + 2.0, tag_w, float(small) + 10.0)
		canvas.draw_rect(plate, HudStyle.color("map_base"))
		HudStyle.panel(canvas, plate)
		HudStyle.text(canvas, font, Vector2(rect.get_center().x, plate.position.y + float(small) + 3.0), tag, small, HudStyle.color("text_dim"), 1)
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
## rows, e.g. soul crystals), hints (e.g. "E · NEUER LAUF   ESC · MENÜ"),
## buttons (count of real buttons the game lays into result_button_row; they
## take the hint line's place).
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
	var buttons := int(data.get("buttons", 0))
	var height := 72.0 + lines.size() * 26.0 + 36.0 + (64.0 if buttons > 0 else 40.0)
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
	if buttons <= 0:
		HudStyle.text(canvas, font, Vector2(screen.x * 0.5, rect.end.y - 16), str(data.get("hints", "")), small, HudStyle.color("text_dim"), 1)
	return rect


## The row the result panel `rect` keeps free for its buttons (data.buttons).
static func result_button_row(rect: Rect2) -> Rect2:
	return Rect2(rect.position.x + 28.0, rect.end.y - 58.0, rect.size.x - 56.0, 40.0)


## A hint centred at height `y` (hints stack over the skill bar).
static func toast(canvas: CanvasItem, font: Font, screen: Vector2, y: float, value: String, alpha: float) -> void:
	if alpha <= 0.0: return
	var body := int(HudStyle.size("font_body"))
	var width := HudStyle.width(font, value, body) + 40.0
	var rect := Rect2((screen.x - width) * 0.5, y - 17, width, 34)
	HudStyle.panel(canvas, rect, alpha)
	canvas.draw_rect(Rect2(rect.position, Vector2(3, rect.size.y)), Color(HudStyle.color("accent"), alpha))
	HudStyle.text(canvas, font, Vector2(screen.x * 0.5 + 1, y + 6), value, body, Color(HudStyle.color("text"), alpha), 1)


## A stone's inscription read out: a panel centred in the upper third of the `screen` with a small
## `title` and `value` wrapped to at most rule inscription_lines lines of rule inscription_width px.
static func inscription(canvas: CanvasItem, font: Font, screen: Vector2, title: String, value: String) -> Rect2:
	var body := int(HudStyle.size("font_body"))
	var small := maxi(10, body - 4)
	var most := minf(rule("inscription_width", 820.0), screen.x - 2.0 * HudStyle.size("margin"))
	# a line break in the text starts a new line (a riddle's verses)
	var lines: Array[String] = []
	for verse: String in value.split("\n"):
		lines.append_array(_wrap(font, verse, body, most - 40.0, int(rule("inscription_lines", 9.0))))
	lines = lines.slice(0, int(rule("inscription_lines", 9.0)))
	var width := HudStyle.width(font, title, small)
	for line: String in lines: width = maxf(width, HudStyle.width(font, line, body))
	var line_h := float(body) + 8.0
	var height := 30.0 + small + lines.size() * line_h
	var rect := Rect2((screen.x - width - 40.0) * 0.5, screen.y * 0.18, width + 40.0, height)
	HudStyle.panel(canvas, rect)
	canvas.draw_rect(Rect2(rect.position, Vector2(rect.size.x, 3)), HudStyle.color("accent"))
	HudStyle.text(canvas, font, Vector2(rect.get_center().x, rect.position.y + 10.0 + small), title, small, HudStyle.color("accent"), 1)
	for i in range(lines.size()):
		HudStyle.text(canvas, font, Vector2(rect.get_center().x, rect.position.y + 22.0 + small + body + i * line_h), lines[i], body, HudStyle.color("text"), 1)
	return rect


## The story worlds' one toast: its lower left corner at `corner`, one line,
## two when longer than `max_width` (the rest cut with "..."). Returns its rectangle.
static func toast_at(canvas: CanvasItem, font: Font, corner: Vector2, value: String, alpha: float, max_width: float = 620.0) -> Rect2:
	if alpha <= 0.0: return Rect2()
	var body := int(HudStyle.size("font_body"))
	var lines := _wrap(font, value, body, max_width - 34.0, 2)
	var width := 0.0
	for line: String in lines: width = maxf(width, HudStyle.width(font, line, body))
	var line_h := float(body) + 8.0
	var height := 12.0 + lines.size() * line_h
	var rect := Rect2(corner.x, corner.y - height, width + 34.0, height)
	HudStyle.panel(canvas, rect, alpha)
	canvas.draw_rect(Rect2(rect.position, Vector2(3, rect.size.y)), Color(HudStyle.color("accent"), alpha))
	for i in range(lines.size()):
		HudStyle.text(canvas, font, Vector2(rect.position.x + 17.0, rect.position.y + 7.0 + body + i * line_h), lines[i], body, Color(HudStyle.color("text"), alpha))
	return rect


## An interaction prompt centred on `at`: a key cap and what it does, kept on
## the `screen` (the canvas's viewport when not given) a margin off every edge.
static func prompt(canvas: CanvasItem, font: Font, at: Vector2, key: String, label: String, screen: Vector2 = Vector2.ZERO) -> void:
	var body := int(HudStyle.size("font_body"))
	var width := HudStyle.width(font, label, body) + 52.0
	var view := screen if screen != Vector2.ZERO else canvas.get_viewport_rect().size
	var margin := HudStyle.size("margin")
	var x := clampf(at.x - width * 0.5, margin, maxf(margin, view.x - margin - width))
	var y := clampf(at.y - 17.0, margin, maxf(margin, view.y - margin - 34.0))
	var rect := Rect2(x, y, width, 34)
	HudStyle.panel(canvas, rect)
	var cap := Rect2(rect.position + Vector2(6, 6), Vector2(22, 22))
	canvas.draw_rect(cap, HudStyle.color("slot"))
	canvas.draw_rect(cap, Color(HudStyle.color("accent"), 0.9), false, 1.0)
	HudStyle.text(canvas, font, Vector2(cap.get_center().x, cap.get_center().y + 6), key, body, HudStyle.color("accent"), 1)
	HudStyle.text(canvas, font, Vector2(cap.end.x + 10, rect.position.y + 23.0), label, body, HudStyle.color("text"))


## A value of the story worlds' HUD rules (assets/data/ui_hud_style.json
## "rules": fade timings, the toast queue, label sizes), `fallback` when missing.
static func rule(name: String, fallback: float) -> float:
	if _rules.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(STYLE_PATH)) if FileAccess.file_exists(STYLE_PATH) else null
		var table: Variant = (parsed as Dictionary).get("rules", {}) if parsed is Dictionary else {}
		_rules = (table as Dictionary).duplicate() if table is Dictionary else {}
		_rules["_read"] = true
	return float(_rules.get(name, fallback))


## Steps a drawn part back to `alpha` (0..1) by laying the HUD's ink over it.
static func dim(canvas: CanvasItem, rect: Rect2, alpha: float) -> void:
	if alpha >= 1.0: return
	canvas.draw_rect(rect, Color(HudStyle.color("outline"), clampf(1.0 - alpha, 0.0, 1.0)))


## `value` cut with "..." so it fits `max_width` px at `font_size`.
static func ellipsis(font: Font, value: String, font_size: int, max_width: float) -> String:
	if HudStyle.width(font, value, font_size) <= max_width: return value
	var cut := value
	while cut.length() > 1 and HudStyle.width(font, cut + "...", font_size) > max_width:
		cut = cut.left(cut.length() - 1)
	return cut.strip_edges() + "..."


## `value` broken into lines no wider than `width` px at `font_size`, at most
## `max_lines` (the last one cut with "...").
static func _wrap(font: Font, value: String, font_size: int, width: float, max_lines: int) -> Array[String]:
	var out: Array[String] = []
	var current := ""
	for word: String in value.split(" ", false):
		var next := word if current.is_empty() else current + " " + word
		if not current.is_empty() and HudStyle.width(font, next, font_size) > width:
			out.append(current)
			current = word
		else:
			current = next
	if not current.is_empty(): out.append(current)
	if out.size() > max_lines:
		var rest := " ".join(PackedStringArray(out.slice(max_lines - 1)))
		out = out.slice(0, max_lines - 1)
		out.append(ellipsis(font, rest, font_size, width))
	return out
