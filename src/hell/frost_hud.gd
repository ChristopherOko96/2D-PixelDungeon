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
	out.append({"text": "Verlasse die Frostgruft" if g.W.final else "Steige die Treppe hinab", "done": g.state.won, "main": true})
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


## Notes goals as they finish: a main goal plays a sound, one finished goal
## shows "Auftrag erfüllt: ...", several at once one "n Ziele erfüllt". The
## first look at a floor (a new floor, a debug jump) takes the goals already
## done without a word. The list itself is on the pause menu's quest page.
## Returns the goals.
static func track(g: Node) -> Array:
	var list := goals(g)
	var first: bool = not g.state.has("goal_done")
	var seen: Dictionary = g.state.get("goal_done", {})
	var fresh: Array = []
	for it: Dictionary in list:
		if it.done and not seen.has(it.text):
			seen[it.text] = g.state.t
			if not first:
				fresh.append(it)
	g.state.goal_done = seen
	if not fresh.is_empty():
		if fresh.any(func(it: Dictionary) -> bool: return bool(it.main)):
			g._sound("puzzle_solved")
		g._toast(("Auftrag erfüllt: " + str(fresh[0].text)) if fresh.size() == 1 else ("%d Ziele erfüllt" % fresh.size()))
	return list


## Takes every goal done right now as seen, silently (a jump into the boss room).
static func hush(g: Node) -> void:
	var seen: Dictionary = g.state.get("goal_done", {})
	for it: Dictionary in goals(g):
		if it.done:
			seen[it.text] = g.state.t
	g.state.goal_done = seen


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

## True while the room banner is on screen.
static func banner_up(g: Node) -> bool:
	return float(g.state.banner.t) < HudKit.rule("banner_time", 2.0)


## The room or level banner: a plate that slides down, holds and fades, all
## within banner_time (ui_hud_style.json "rules").
static func banner(g: Node, h: Control, size: Vector2, y: float) -> void:
	var b: Dictionary = g.state.banner
	var t: float = b.t
	var total := HudKit.rule("banner_time", 2.0)
	var fade_in := maxf(0.05, HudKit.rule("banner_in", 0.3))
	var a := clampf(t / fade_in, 0.0, 1.0) * clampf((total - t) / maxf(0.05, HudKit.rule("banner_out", 0.4)), 0.0, 1.0)
	var slide := (1.0 - clampf(t / fade_in, 0.0, 1.0)) * -30.0
	HudKit.banner(h, FONT, size, y + slide, str(b.text), String(b.sub), a)


# ---------- status ----------

## The status sheet (C / Tab): who the hero is and what the numbers are now.
## The card list only in a run that hands out level-up cards.
static func status(g: Node, h: Control, size: Vector2) -> void:
	var rel: Dictionary = RelicKit.wielded(g)
	var rate: float = float(g.state.rate) * CardKit.rate_mult(g)
	var atk: Dictionary = rel.get("ball", rel.get("attack", {}))
	var dmg: float = (float(atk.damage) if not atk.is_empty() else float(g.state.dmg)) * CardKit.damage_mult(g)
	if not atk.is_empty():
		rate = float(atk.cooldown) * CardKit.rate_mult(g)
	var cfg: Dictionary = g.theme.leveling
	# the life as the bar shows it: hp minus what a poison or burn has already taken (hp_f)
	var hp_f := clampf(float(g.state.get("hp_f", g.state.hp)), 0.0, float(g.state.max_hp))
	var rows := [
		["Klasse", str(g.hero.get("name", "-"))],
		["Waffe", str(rel.get("name", g.weapon.get("name", "-")))],
		["Laufstufe", "%d  (%d / %d EP)" % [int(g.state.level), int(g.state.exp), HeroKit.need(cfg, int(g.state.level))]],
		["LP", "%d / %d" % [HudKit.life_shown(int(g.state.hp), hp_f), int(g.state.max_hp)]],
		["Schaden", "%.1f je Treffer" % dmg],
		["Angriffe", "%.1f pro Sekunde" % (1.0 / maxf(0.05, rate))],
		["Lauftempo", "%d" % int(float(g.hero.get("speed", 300)) * CardKit.speed_mult(g) * float(g.state.speed_mul))],
		[g.say("Runensteine"), str(int(g.state.gems))]]
	var cards := CardKit.offers_cards(g)
	var row_h := 28.0
	var r := Rect2(40, 200, 440, 70.0 + rows.size() * row_h + (40.0 + 6 * 22.0 if cards else 0.0) + 34.0)
	frame(h, r)
	g._text(h, "STATUS", Vector2(r.position.x + 20, r.position.y + 34), 20, HudStyle.color("accent"))
	var y := r.position.y + 70.0
	for row: Array in rows:
		g._text(h, str(row[0]), Vector2(r.position.x + 20, y), 16, Color(HudStyle.color("text_dim"), 0.9))
		g._text(h, HudKit.ellipsis(FONT, str(row[1]), 16, r.size.x - 200.0), Vector2(r.position.x + 180, y), 16, HudStyle.color("text"))
		y += row_h
	if cards:
		g._text(h, "KARTEN", Vector2(r.position.x + 20, y + 10), 16, HudStyle.color("accent"))
		y += 40.0
		var ups: Dictionary = g.state.get("upgrades", {})
		var names: Array = []
		for c: Dictionary in CardKit._all(g):
			if ups.has(str(c.id)):
				names.append("%s %d/%d" % [c.name, int(ups[c.id]), int(c.max)])
		if names.is_empty():
			names = ["noch keine"]
		for n: String in names.slice(0, 6):
			g._text(h, n, Vector2(r.position.x + 20, y), 16, HudStyle.color("text"))
			y += 22.0
	g._text(h, "C / Tab / Esc schließt", Vector2(r.position.x + 20, r.end.y - 14), 16, Color(HudStyle.color("text"), 0.5))


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
	g._text(h, "LAUFSTUFE %d · WÄHLE EINE VERBESSERUNG" % int(g.state.level), Vector2(0, size.y / 2.0 - 60), 20, HudStyle.color("accent"), size.x)
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


# ---------- the demon seal's choice (balance package D1) ----------

## The seal's cards side by side in the middle, rising into place over 0.3 s
## of real time (the world, and so its clock, waits while they are open).
static func _seal_rects(g: Node, size: Vector2) -> Array:
	var pick: Dictionary = g.state.get("seal_pick", {})
	var n: int = (pick.get("ids", []) as Array).size()
	var w := 250.0
	var gap := 28.0
	var x0 := size.x / 2.0 - (n * w + (n - 1) * gap) / 2.0
	var age := float(Time.get_ticks_msec() - int(pick.get("ms", 0))) / 1000.0
	var rise := (1.0 - clampf(age / 0.3, 0.0, 1.0)) * 40.0
	var out: Array = []
	for i in range(n):
		out.append(Rect2(x0 + i * (w + gap), size.y / 2.0 - 70 + rise, w, 170))
	return out


## Draws `text` word-wrapped and centred in `r` from line `y` on; returns the next line.
static func _wrap(g: Node, h: Control, text: String, r: Rect2, y: float, font_size: int, col: Color) -> float:
	var line := ""
	for wd: String in text.split(" "):
		if FONT.get_string_size(line + " " + wd, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > r.size.x - 24 and line != "":
			g._text(h, line, Vector2(r.position.x, y), font_size, col, r.size.x)
			y += font_size + 6.0
			line = wd
		else:
			line = wd if line == "" else line + " " + wd
	if line != "":
		g._text(h, line, Vector2(r.position.x, y), font_size, col, r.size.x)
		y += font_size + 6.0
	return y


## The text of the open seal's card `i`: what taking it really gives (CardKit.seal_offer's dry run).
static func _seal_text(g: Node, i: int) -> String:
	var pick: Dictionary = g.state.get("seal_pick", {})
	var texts: Array = pick.get("texts", [])
	if i < texts.size():
		return str(texts[i])
	var id := str((pick.get("ids", []) as Array)[i])
	return str(Rules.BLESSING_TEXT.get(id, id))


## A broken demon seal's choice: the frozen world dims, a card per blessing
## shows its name, what it does and the price it costs (the same safe price on
## each), keys 1 / 2 or a click take one, Esc leaves both for nothing. With too
## little life the cards stay dull and say so.
static func seal_cards(g: Node, h: Control, size: Vector2) -> void:
	var pick: Dictionary = g.state.get("seal_pick", {})
	if pick.is_empty():
		return
	var ids: Array = pick.get("ids", [])
	var price := int(pick.get("price", 0))
	var can := Rules.seal_affordable(g.state, price)
	var rects := _seal_rects(g, size)
	if rects.is_empty():
		return
	h.draw_rect(Rect2(Vector2.ZERO, size), Color(HudStyle.color("outline"), 0.5))
	var top: float = (rects[0] as Rect2).position.y
	# the world's own words for the seal breaking (frost_theme.json: the frozen chest springs open)
	g._text(h, "%s · WÄHLE EINEN SEGEN" % g.say("Das Siegel bricht").to_upper(), Vector2(0, top - 46), 20, HudStyle.color("accent"), size.x)
	g._text(h, "Jeder Segen kostet %s. Er bleibt für den ganzen Lauf." % Rules.price_text(price), Vector2(0, top - 16), 16, HudStyle.color("text"), size.x)
	var mouse := h.get_local_mouse_position()
	# no card lights up before the cards are armed (CardKit.seal_armed: the breaking blow picks nothing)
	var armed := CardKit.seal_armed(g)
	for i in range(rects.size()):
		var r: Rect2 = rects[i]
		var hot := can and armed and r.has_point(mouse)
		var dim := 1.0 if can else 0.55
		frame(h, r.grow(4.0 if hot else 0.0), hot, dim)
		var text: String = g.say(_seal_text(g, i))
		g._text(h, text.get_slice(":", 0).to_upper(), Vector2(r.position.x, r.position.y + 34), 16, Color(HudStyle.color("accent"), dim), r.size.x)
		_wrap(g, h, text.get_slice(":", 1).strip_edges() if text.contains(":") else text, r, r.position.y + 64.0, 16, Color(HudStyle.color("text"), dim))
		g._text(h, ("Preis: %s" % Rules.price_text(price)) if can else "Zu wenig Leben", Vector2(r.position.x, r.end.y - 34), 16, Color(HudStyle.color("danger"), 0.95), r.size.x)
		g._text(h, "[%d]" % (i + 1), Vector2(r.position.x, r.end.y - 10), 16, Color(HudStyle.color("accent"), dim), r.size.x)
	var hint := "%s · SEGEN NEHMEN    ESC · BEIDE LASSEN" % " / ".join(PackedStringArray(range(1, ids.size() + 1).map(func(k: int) -> String: return str(k))))
	g._text(h, hint, Vector2(0, (rects[0] as Rect2).end.y + 36), 16, Color(HudStyle.color("text_dim"), 0.95), size.x)


## Before the first blow: over a whole demon seal near the hero (within
## `reach` world px) a small plate says what breaking it offers and costs.
static func seal_hint(g: Node, h: Control, size: Vector2, reach := 300.0) -> void:
	var hero := Vector2(float(g.player.x), float(g.player.y))
	var best: Dictionary = {}
	var bd := reach
	for e: Dictionary in g.breakables:
		if str(e.get("type", "")) != "seal" or bool(e.get("broken", false)):
			continue
		var dd := hero.distance_to(Vector2(float(e.x), float(e.y)))
		if dd < bd:
			bd = dd
			best = e
	if best.is_empty():
		return
	var cfg := CardKit.seal_cfg(g)
	# neutral words: the Frostgruft's seal is a frozen chest (frost_theme.json words)
	var lines := ["SEGEN ZUR WAHL", "Zerschlagen: %d Segen · je %s" % [int(cfg.get("offers", 2)), Rules.price_text(int(cfg.get("price_hp", 2)))]]
	var w := 0.0
	for line: String in lines:
		w = maxf(w, FONT.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x)
	w += 28.0
	var at: Vector2 = g._to_screen(Vector2(float(best.x), float(best.y) - 120.0), size)
	var r := Rect2(clampf(at.x - w / 2.0, 8.0, size.x - w - 8.0), clampf(at.y - 56.0, 8.0, size.y - 64.0), w, 56.0)
	frame(h, r, false, 0.92)
	g._text(h, str(lines[0]), Vector2(r.position.x, r.position.y + 22), 16, HudStyle.color("accent"), r.size.x)
	g._text(h, str(lines[1]), Vector2(r.position.x, r.position.y + 46), 16, HudStyle.color("text"), r.size.x)


## Which of the seal's cards lies under a screen point (-1 for none).
static func seal_card_at(g: Node, p: Vector2, size: Vector2) -> int:
	var rects := _seal_rects(g, size)
	for i in range(rects.size()):
		if (rects[i] as Rect2).has_point(p):
			return i
	return -1
