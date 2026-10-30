extends RefCounted
## The HUD parts every world draws the same way (crypt, Hell-Dungeon,
## Frostgruft), in the neutral look of src/ui/hud_style.gd. A world fills the
## data; mechanics a world does not have simply stay empty (no keys in the
## crypt yet, no team-mates in the story worlds), so the crypt is ready for
## keys, rune gems, puzzle progress and timed powers when it gets them.
## - hero_panel: top left, one compact strip: name and HP, hearts with the
##   level beside them, the EXP line, resources (keys, gems, braziers) and
##   short status lines (clone, blessings, shield).
## - floor_panel + menu_chip: top right: floor, place, the fight state and the
##   mini-map area; "ESC · MENÜ" under it.
## - boss_bar: top centre, with phase segments.
## - banner, toast, prompt: floor titles, hints over the skill bar, "E" prompts.
## - pet_panel: the permanent companion's life right under the hero strip.
## Static, display only.

const HudStyle = preload("res://src/ui/hud_style.gd")


## The permanent companion under the hero strip: its name, a life bar that
## turns red when low, or "GEFALLEN" with the seconds until it can be called
## again. `pet` is talent_combat's player_state().pet; `width` matches
## the hero strip. Returns the row's rectangle (zero size without a companion).
static func pet_panel(canvas: CanvasItem, font: Font, origin: Vector2, width: float, pet: Dictionary, clock: float) -> Rect2:
	if pet.is_empty(): return Rect2(origin, Vector2.ZERO)
	var small := int(HudStyle.size("font_small"))
	var rect := Rect2(origin, Vector2(width, small + 22.0))
	HudStyle.panel(canvas, rect)
	var alive := bool(pet.get("alive", false))
	HudStyle.text(canvas, font, rect.position + Vector2(10, small + 4), str(pet.get("name", "")).to_upper(), small, HudStyle.color("text_dim"))
	var bar := Rect2(rect.position + Vector2(10, small + 9), Vector2(width - 20, 6))
	canvas.draw_rect(bar, HudStyle.color("track"))
	if alive:
		var share := clampf(float(pet.get("hp", 0)) / maxf(0.1, float(pet.get("hp_max", 1))), 0.0, 1.0)
		var colour := HudStyle.color("ok") if share > 0.35 else HudStyle.color("danger").lerp(Color.WHITE, 0.2 + 0.2 * sin(clock * 9.0))
		canvas.draw_rect(Rect2(bar.position, Vector2(roundf(bar.size.x * share), bar.size.y)), colour)
		# the numbers only where they fit beside the name (the crypt's strip is narrow)
		var numbers := "%d / %d" % [ceili(float(pet.hp)), ceili(float(pet.hp_max))]
		if HudStyle.width(font, str(pet.get("name", "")).to_upper(), small) + HudStyle.width(font, numbers, small) + 30.0 <= width:
			HudStyle.text(canvas, font, Vector2(rect.end.x - 10, rect.position.y + small + 4), numbers, small, HudStyle.color("text"), 2)
	else:
		var wait := float(pet.get("respawn", 0.0))
		HudStyle.text(canvas, font, Vector2(rect.end.x - 10, rect.position.y + small + 4), "GEFALLEN · %d S" % ceili(wait) if wait > 0.0 else "GEFALLEN", small, HudStyle.color("danger"), 2)
	return rect


## The hero strip at `origin`. `data`: title, hp, max_hp, hearts ({full, half,
## empty} textures), level (int, -1 none), exp (0..1, -1 none), points (unspent
## run talent points, "+n" beside the level), low (bool:
## pulse the hearts), resources [{icon, tint, text, dim}], status [{text,
## color}], clock. Returns the strip's rectangle.
static func hero_panel(canvas: CanvasItem, font: Font, origin: Vector2, data: Dictionary) -> Rect2:
	var pad := HudStyle.size("pad")
	var heart := HudStyle.size("heart_size")
	var gap := HudStyle.size("heart_gap")
	var per_row := maxi(1, int(HudStyle.size("hearts_per_row")))
	var small := int(HudStyle.size("font_small"))
	var body := int(HudStyle.size("font_body"))
	var hp := int(data.get("hp", 0))
	var max_hp := int(data.get("max_hp", 0))
	var icons := heart_icons(hp, max_hp)
	var rows := maxi(1, ceili(icons.size() / float(per_row)))
	var level := int(data.get("level", -1))
	var experience := float(data.get("exp", -1.0))
	var resources: Array = data.get("resources", [])
	var status: Array = data.get("status", [])
	var hp_text := "%d / %d" % [hp, max_hp] if hp > 0 else "GEFALLEN"
	var title := str(data.get("title", ""))
	# widths: hearts row with the level badge beside it, the header, the resources
	var hearts_w := minf(icons.size(), per_row) * (heart + gap) - gap
	# the level badge grows with its number (LV 9, LV 13, LV 100)
	var badge := Vector2(18.0 + HudStyle.width(font, "LV", small) + HudStyle.width(font, str(level), body), heart) if level >= 0 else Vector2.ZERO
	var resource_w := 0.0
	for r: Dictionary in resources: resource_w += 26.0 + HudStyle.width(font, str(r.get("text", "")), body) + 14.0
	# unspent run talent points: a small "+n" beside the level badge
	var points := int(data.get("points", 0))
	var points_w := (HudStyle.width(font, "+%d" % points, body) + 10.0) if points > 0 and level >= 0 else 0.0
	var inner_w := maxf(hearts_w + (badge.x + 10.0 + points_w if level >= 0 else 0.0), maxf(HudStyle.width(font, title, small) + HudStyle.width(font, hp_text, small) + 24.0, resource_w))
	var height := pad + small + 6.0 + rows * (heart + gap) - gap + (8.0 if experience >= 0.0 else 0.0) + (30.0 if not resources.is_empty() else 0.0) + status.size() * (small + 6.0) + pad
	var rect := Rect2(origin, Vector2(inner_w + pad * 2.0, height))
	HudStyle.panel(canvas, rect)
	var x := rect.position.x + pad
	var y := rect.position.y + pad
	HudStyle.text(canvas, font, Vector2(x, y + small), title, small, HudStyle.color("text_dim"))
	HudStyle.text(canvas, font, Vector2(rect.end.x - pad, y + small), hp_text, small, HudStyle.color("text") if hp > 0 else HudStyle.color("danger"), 2)
	y += small + 6.0
	var textures: Dictionary = data.get("hearts", {})
	var clock := float(data.get("clock", 0.0))
	var low := bool(data.get("low", false))
	for index in range(icons.size()):
		var at := Vector2(x + (index % per_row) * (heart + gap), y + (index / per_row) * (heart + gap))
		var texture: Texture2D = textures.get(icons[index], null)
		if texture == null: continue
		var grow := 0.12 * sin(clock * 8.0) if low and icons[index] != "empty" else 0.0
		var box := Rect2(at - Vector2(heart, heart) * grow * 0.5, Vector2(heart, heart) * (1.0 + grow))
		canvas.draw_texture_rect(texture, box, false)
	if level >= 0:
		var b := Rect2(Vector2(x + hearts_w + 10.0, y), badge)
		canvas.draw_rect(b, HudStyle.color("slot"))
		canvas.draw_rect(b, HudStyle.color("panel_edge"), false, 1.0)
		HudStyle.text(canvas, font, Vector2(b.position.x + 6, b.get_center().y + 5), "LV", small, HudStyle.color("text_dim"))
		HudStyle.text(canvas, font, Vector2(b.end.x - 6, b.get_center().y + 7), str(level), body, HudStyle.color("accent"), 2)
		if points > 0:
			var glow := 0.65 + 0.35 * sin(clock * 5.0)
			HudStyle.text(canvas, font, Vector2(b.end.x + 8, b.get_center().y + 7), "+%d" % points, body, Color(HudStyle.color("accent"), glow))
	y += rows * (heart + gap) - gap
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
