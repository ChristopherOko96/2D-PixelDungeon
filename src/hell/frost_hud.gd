extends RefCounted
## The styled HUD parts of the story worlds (theme.styled_hud), in the neutral
## HUD look every world shares (src/ui/hud_style.gd, no world colours): the floor's mission list under the minimap (main goals
## in order, side goals below, a finished goal flashes and ticks off), the
## room banner as a sliding plate, the status sheet (C / Tab) and the three
## level-up cards. Draws into the game's HUD control through the game's font.

const Rules = preload("res://src/hell/hell_rules.gd")
const RelicKit = preload("res://src/hell/relic_kit.gd")
const CardKit = preload("res://src/hell/card_kit.gd")
const HeroKit = preload("res://src/hell/hero_kit.gd")
const FONT := preload("res://assets/fonts/pixel_operator8.ttf")
const HudStyle = preload("res://src/ui/hud_style.gd")
const HudKit = preload("res://src/ui/hud_kit.gd")


## A panel in the shared HUD look; `hot` (under the mouse) gets the accent edge.
static func frame(h: Control, r: Rect2, hot := false, alpha := 1.0) -> void:
	HudStyle.panel(h, r, alpha)
	if hot:
		h.draw_rect(r, Color(HudStyle.color("accent"), 0.9 * alpha), false, 1.0)


# ---------- mission ----------

## The floor's goals: main ones in order (key, gate, guardian, stairs), then side goals.
static func goals(g: Node) -> Array:
	var out: Array = []
	var boss_room: int = -1
	for r: Dictionary in g.W.rooms:
		if r.type == "boss":
			boss_room = r.index
	var gate: Dictionary = {}
	for d: Dictionary in g.W.doors:
		if d.kind == "lock" and (d.a == boss_room or d.b == boss_room):
			gate = d
	if not gate.is_empty():
		var k: String = gate.key
		out.append({"text": "Finde den %s" % g.key_name[k], "done": g.state.keys[k] or g.state.used[k] or gate.unlocked, "main": true})
		out.append({"text": "Entriegle das Tor der Wächterhalle", "done": gate.unlocked, "main": true})
	out.append({"text": "Besiege %s" % g.W.boss.name, "done": g.state.boss_dead, "main": true})
	out.append({"text": "Verlasse die Frostgruft" if g.W.final else "Steig die Treppe hinab", "done": g.state.won, "main": true})
	for key: String in g.W.groups:
		var grp: Dictionary = g.W.groups[key]
		if key == "relic":
			continue
		var prog: Vector2i = Rules.group_progress(g.W.ents, key)
		var what := "Entzünde die %s" % g.say("Feuerschalen") if grp.kind == "braziers" else "Löse das Plattenrätsel"
		out.append({"text": what + (" (%d/%d)" % [prog.x, prog.y] if grp.kind == "braziers" else ""), "done": grp.get("solved", false), "main": false})
	for r: Dictionary in g.W.rooms:
		if r.type == "secret":
			out.append({"text": "Finde den Geheimraum", "done": g.state.visited.has(r.index), "main": false})
	if g.state.has("relic_room") and int(g.state.get("relic_floor", 0)) == int(g.state.floor):
		out.append({"text": "Hebe das Relikt: %s" % g.theme[g.state.relic_item].name, "done": str(g.state.relic) != "", "main": false})
	return out


## Notes goals as they finish: a main goal plays a sound, every goal shows a
## short note ("Auftrag erfüllt: ..."). Goals done when the floor starts stay quiet.
## The list itself is on the pause menu's quest page. Returns the goals.
static func track(g: Node) -> Array:
	var list := goals(g)
	var seen: Dictionary = g.state.get("goal_done", {})
	for it: Dictionary in list:
		if it.done and not seen.has(it.text):
			seen[it.text] = g.state.t
			if float(g.state.t) > 0.5:
				if it.main:
					g._sound("puzzle_solved")
				g._toast("Auftrag erfüllt: " + str(it.text))
	g.state.goal_done = seen
	return list


## The mission list under the minimap (no longer drawn by the hell, kept for other
## callers); the current main goal pulses, a goal that just finished flashes.
static func mission(g: Node, h: Control, size: Vector2) -> void:
	var list := track(g)
	var seen: Dictionary = g.state.get("goal_done", {})
	# as wide as the longest goal, so nothing runs past the frame
	var w := 220.0
	for it: Dictionary in list:
		w = maxf(w, FONT.get_string_size(str(it.text), HORIZONTAL_ALIGNMENT_LEFT, -1, 14 if it.main else 12).x + 52.0)
	w = minf(w, 420.0)
	var x := size.x - w - 10.0
	var y := 200.0
	var lines := list.size()
	frame(h, Rect2(x, y, w, 40 + lines * 26))
	g._text(h, "AUFTRAG · ETAGE %d" % int(g.state.floor), Vector2(x + 14, y + 24), 16, HudStyle.color("accent"))
	var current_set := false
	var ly := y + 52.0
	for it: Dictionary in list:
		var flash: float = clampf(1.0 - (float(g.state.t) - float(seen.get(it.text, -9.0))) / 0.8, 0.0, 1.0)
		var current: bool = it.main and not it.done and not current_set
		if current:
			current_set = true
		var col: Color = Color(HudStyle.color("text"), 0.45) if it.done else (HudStyle.color("accent") if current else (Color(HudStyle.color("text"), 0.9) if it.main else Color(HudStyle.color("text_dim"), 0.85)))
		if flash > 0.0:
			h.draw_rect(Rect2(x + 6, ly - 18, w - 12, 24), Color(HudStyle.color("accent"), 0.35 * flash))
		var mark := "✓" if it.done else ("▶" if current else ("•" if it.main else "◇"))
		var off: float = sin(float(g.state.t) * 6.0) * 3.0 if current else 0.0
		g._text(h, mark, Vector2(x + 12 + off, ly), 16, HudStyle.color("accent") if (current or it.done) else col)
		g._text(h, str(it.text), Vector2(x + 34, ly), 12 if not it.main else 14, col)
		if it.done:
			var tw: float = FONT.get_string_size(str(it.text), HORIZONTAL_ALIGNMENT_LEFT, -1, 12 if not it.main else 14).x
			h.draw_line(Vector2(x + 34, ly - 5), Vector2(x + 34 + tw, ly - 5), Color(HudStyle.color("text"), 0.45), 1.0)
		ly += 26.0


# ---------- banner ----------

## The room or level banner: a plate that slides down, holds and fades.
static func banner(g: Node, h: Control, size: Vector2, y: float) -> void:
	var b: Dictionary = g.state.banner
	var t: float = b.t
	var a := clampf(t / 0.35, 0.0, 1.0) if t < 2.6 else maxf(0.0, 1.0 - (t - 2.6) / 0.6)
	var slide := (1.0 - clampf(t / 0.35, 0.0, 1.0)) * -30.0
	HudKit.banner(h, FONT, size, y + slide, str(b.text), String(b.sub), a)


# ---------- status ----------

## The status sheet (C / Tab): who the hero is and what the numbers are now.
static func status(g: Node, h: Control, size: Vector2) -> void:
	var r := Rect2(40, 160, 420, 400)
	frame(h, r)
	var rel: Dictionary = RelicKit.wielded(g)
	var rate: float = float(g.state.rate) * CardKit.rate_mult(g)
	var atk: Dictionary = rel.get("ball", rel.get("attack", {}))
	var dmg: float = (float(atk.damage) if not atk.is_empty() else float(g.state.dmg)) * CardKit.damage_mult(g)
	if not atk.is_empty():
		rate = float(atk.cooldown) * CardKit.rate_mult(g)
	var cfg: Dictionary = g.theme.leveling
	# the life as the bar shows it: hp minus what a poison or burn has already taken (hp_f), in half hearts
	var hp_f := clampf(float(g.state.get("hp_f", g.state.hp)), 0.0, float(g.state.max_hp))
	var rows := [
		["Klasse", str(g.hero.get("name", "-"))],
		["Waffe", str(rel.get("name", g.weapon.get("name", "-")))],
		["Level", "%d  (%d / %d EP)" % [int(g.state.level), int(g.state.exp), HeroKit.need(cfg, int(g.state.level))]],
		["Leben", "%d / %d LP" % [HudKit.life_shown(int(g.state.hp), hp_f), int(g.state.max_hp)]],
		["Schaden", "%.1f je Treffer" % dmg],
		["Angriffe", "%.1f pro Sekunde" % (1.0 / maxf(0.05, rate))],
		["Lauftempo", "%d" % int(float(g.hero.get("speed", 300)) * CardKit.speed_mult(g) * float(g.state.speed_mul))],
		["Eissplitter", str(int(g.state.gems))]]
	g._text(h, "STATUS", Vector2(r.position.x + 20, r.position.y + 34), 20, HudStyle.color("accent"))
	var y := r.position.y + 70.0
	for row: Array in rows:
		g._text(h, row[0], Vector2(r.position.x + 20, y), 14, Color(HudStyle.color("text_dim"), 0.9))
		g._text(h, row[1], Vector2(r.position.x + 170, y), 14, HudStyle.color("text"))
		y += 26.0
	g._text(h, "KARTEN", Vector2(r.position.x + 20, y + 10), 16, HudStyle.color("accent"))
	y += 34.0
	var ups: Dictionary = g.state.get("upgrades", {})
	var names: Array = []
	for c: Dictionary in CardKit._all(g):
		if ups.has(str(c.id)):
			names.append("%s %d/%d" % [c.name, int(ups[c.id]), int(c.max)])
	if names.is_empty():
		names = ["noch keine"]
	for n: String in names.slice(0, 6):
		g._text(h, n, Vector2(r.position.x + 20, y), 12, HudStyle.color("text"))
		y += 20.0
	g._text(h, "C / Tab schließt", Vector2(r.position.x + 20, r.end.y - 14), 12, Color(HudStyle.color("text"), 0.5))


# ---------- level-up cards ----------

static func _card_rects(g: Node, size: Vector2) -> Array:
	var n: int = (g.state.offer as Array).size()
	var w := 230.0
	var gap := 20.0
	var x0 := size.x / 2.0 - (n * w + (n - 1) * gap) / 2.0
	var rise := (1.0 - clampf(float(g.state.get("offer_t", 1.0)) / 0.3, 0.0, 1.0)) * 40.0
	var out: Array = []
	for i in range(n):
		out.append(Rect2(x0 + i * (w + gap), size.y / 2.0 - 40 + rise, w, 150))
	return out


## The three cards of a level-up: name, effect, its step, key 7/8/9 or a click.
static func cards(g: Node, h: Control, size: Vector2) -> void:
	var rects := _card_rects(g, size)
	g._text(h, "LEVEL %d · WÄHLE EINE VERBESSERUNG" % int(g.state.level), Vector2(0, size.y / 2.0 - 60), 20, HudStyle.color("accent"), size.x)
	var mouse := h.get_local_mouse_position()
	for i in range(rects.size()):
		var c: Dictionary = g.state.offer[i]
		var r: Rect2 = rects[i]
		var hot := r.has_point(mouse)
		frame(h, r.grow(4.0 if hot else 0.0), hot)
		g._text(h, str(c.name), Vector2(r.position.x, r.position.y + 34), 16, HudStyle.color("accent"), r.size.x)
		var words: PackedStringArray = str(c.desc).split(" ")
		var line := ""
		var y := r.position.y + 66.0
		for wd: String in words:
			if FONT.get_string_size(line + " " + wd, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x > r.size.x - 24 and line != "":
				g._text(h, line, Vector2(r.position.x, y), 12, HudStyle.color("text"), r.size.x)
				y += 18.0
				line = wd
			else:
				line = wd if line == "" else line + " " + wd
		g._text(h, line, Vector2(r.position.x, y), 12, HudStyle.color("text"), r.size.x)
		g._text(h, "Stufe %d/%d" % [CardKit.level(g, str(c.id)) + 1, int(c.max)], Vector2(r.position.x, r.end.y - 30), 12, Color(HudStyle.color("text_dim"), 0.9), r.size.x)
		g._text(h, "[%d]" % (7 + i), Vector2(r.position.x, r.end.y - 10), 14, HudStyle.color("accent"), r.size.x)


## Which card lies under a screen point (-1 for none).
static func card_at(g: Node, p: Vector2, size: Vector2) -> int:
	var rects := _card_rects(g, size)
	for i in range(rects.size()):
		if (rects[i] as Rect2).has_point(p):
			return i
	return -1
