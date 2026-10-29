extends RefCounted
## The run talent tree window (src/progress/run_tree.gd), the same in every
## world and in the neutral HUD look (src/ui/hud_style.gd): one column per
## branch (skills, then passives), tier-1 nodes over a thin line, tier-2 nodes
## under it; each node shows its icon, name and rank pips; taken nodes glow in
## the accent, open ones have a light edge, locked ones are dim with the reason.
## The hovered node's text sits at the foot. The game keeps running while it is
## open. Static: `draw` paints it, `hit` finds the node under a screen point.

const HudStyle = preload("res://src/ui/hud_style.gd")
const RunTree = preload("res://src/progress/run_tree.gd")
const PANEL := Vector2(1040, 560)
const NODE_H := 50.0
const NODE_GAP := 8.0


## Where the window and each node sit: {panel: Rect2, nodes: {id: Rect2}, heads: [Rect2]}.
static func layout(screen: Vector2, tree: Dictionary) -> Dictionary:
	var panel := Rect2(((screen - PANEL) * 0.5).floor(), PANEL)
	var branches: Array = tree.get("branches", [])
	var count := maxi(1, branches.size())
	var inner := Rect2(panel.position + Vector2(20, 76), Vector2(panel.size.x - 40, panel.size.y - 76 - 92))
	var col_w := floorf((inner.size.x - (count - 1) * 10.0) / count)
	# nodes shrink (down to 30 px) so the longest branch fits above the foot
	var most := 1
	for b: Dictionary in branches:
		most = maxi(most, (b.nodes as Array).size())
	var room := inner.size.y - 42.0 - 14.0
	var node_h := clampf(floorf((room - (most - 1) * NODE_GAP) / most), 30.0, NODE_H)
	var nodes := {}
	var heads: Array = []
	for i in range(branches.size()):
		var b: Dictionary = branches[i]
		var x := inner.position.x + i * (col_w + 10.0)
		heads.append(Rect2(x, inner.position.y, col_w, 34))
		var y := inner.position.y + 42.0
		var tier := 1
		for n: Dictionary in b.nodes:
			if int(n.tier) != tier:
				tier = int(n.tier)
				y += 14.0
			nodes[str(n.id)] = Rect2(x, y, col_w, node_h)
			y += node_h + NODE_GAP
	return {"panel": panel, "nodes": nodes, "heads": heads}


## The node id under `point` ("" for none).
static func hit(screen: Vector2, tree: Dictionary, point: Vector2) -> String:
	var rects: Dictionary = layout(screen, tree).nodes
	for id: String in rects:
		if (rects[id] as Rect2).has_point(point):
			return id
	return ""


## Paints the window. `data`: title (e.g. "MAGIER"), mouse (screen point), clock.
static func draw(canvas: CanvasItem, font: Font, screen: Vector2, tree: Dictionary, ranks: Dictionary, level: int, data: Dictionary) -> void:
	var lay := layout(screen, tree)
	var panel: Rect2 = lay.panel
	canvas.draw_rect(Rect2(Vector2.ZERO, screen), Color(HudStyle.color("outline"), 0.45))
	# a dense base: the window reads clearly over the corner panels
	canvas.draw_rect(panel, Color(HudStyle.color("outline"), 0.85))
	HudStyle.panel(canvas, panel)
	var left := RunTree.points_left(tree, ranks, level)
	HudStyle.text(canvas, font, panel.position + Vector2(24, 40), "LAUF-TALENTE · %s" % str(data.get("title", "")).to_upper(), 24, HudStyle.color("text"))
	HudStyle.text(canvas, font, Vector2(panel.end.x - 24, panel.position.y + 38), "PUNKTE %d" % left, 16, HudStyle.color("accent") if left > 0 else HudStyle.color("text_dim"), 2)
	HudStyle.text(canvas, font, Vector2(panel.end.x - 24, panel.position.y + 58), "LEVEL %d · VERFÄLLT BEIM TOD" % level, 12, HudStyle.color("text_muted"), 2)
	var branches: Array = tree.get("branches", [])
	var mouse: Vector2 = data.get("mouse", Vector2(-1, -1))
	var hovered: Dictionary = {}
	var hovered_state := ""
	for i in range(branches.size()):
		var b: Dictionary = branches[i]
		var head: Rect2 = lay.heads[i]
		var open := level >= int(b.unlock)
		canvas.draw_rect(Rect2(head.position + Vector2(0, head.size.y - 2), Vector2(head.size.x, 2)), Color(HudStyle.color("accent") if open else HudStyle.color("panel_edge"), 0.8))
		HudStyle.text(canvas, font, head.position + Vector2(4, 16), str(b.title).to_upper(), 12, HudStyle.color("text") if open else HudStyle.color("text_muted"))
		var sub := "%d PUNKTE" % RunTree.branch_points(b, ranks) if open else "AB LEVEL %d" % int(b.unlock)
		HudStyle.text(canvas, font, head.position + Vector2(4, 30), sub, 10, HudStyle.color("text_dim") if open else HudStyle.color("text_muted"))
		var tier_drawn := false
		for n: Dictionary in b.nodes:
			var rect: Rect2 = lay.nodes[str(n.id)]
			if int(n.tier) > 1 and not tier_drawn:
				tier_drawn = true
				canvas.draw_rect(Rect2(rect.position + Vector2(0, -10), Vector2(rect.size.x, 1)), Color(HudStyle.color("panel_edge"), 0.6))
			var state := RunTree.state_of(tree, ranks, level, str(n.id))
			_node(canvas, font, rect, n, int(ranks.get(str(n.id), 0)), state, rect.has_point(mouse))
			if rect.has_point(mouse):
				hovered = n
				hovered_state = state
	# the hovered node's text, or how the tree works
	var foot := Rect2(panel.position.x + 20, panel.end.y - 82, panel.size.x - 40, 62)
	canvas.draw_rect(foot, HudStyle.color("slot"))
	if hovered.is_empty():
		HudStyle.text(canvas, font, foot.position + Vector2(12, 26), "Jedes Level gibt einen Punkt. Die ersten zwei Talente eines Astes sind frei, die übrigen öffnen nach 2 Punkten im Ast.", 12, HudStyle.color("text_dim"))
	else:
		HudStyle.text(canvas, font, foot.position + Vector2(12, 24), "%s  ·  %d / %d" % [str(hovered.name), int(ranks.get(str(hovered.id), 0)), int(hovered.max)], 16, HudStyle.color("accent"))
		var why: String = {"skill_locked": "  ·  Fähigkeit noch nicht frei", "tier_locked": "  ·  erst 2 Punkte im Ast", "no_points": "  ·  kein Punkt frei", "maxed": "  ·  voll",
			"meta_locked": "  ·  im Hauptmenü unter TALENTE freischalten"}.get(hovered_state, "")
		HudStyle.text(canvas, font, foot.position + Vector2(12, 46), str(hovered.get("text", "")) + why, 12, HudStyle.color("text"))
	HudStyle.text(canvas, font, Vector2(panel.get_center().x, panel.end.y - 8), "KLICK · PUNKT SETZEN     %s · SCHLIESSEN" % str(RunTree.settings().key), 10, HudStyle.color("text_muted"), 1)


static func _node(canvas: CanvasItem, font: Font, rect: Rect2, n: Dictionary, rank: int, state: String, hot: bool) -> void:
	var locked := state in ["skill_locked", "tier_locked", "meta_locked"]
	var fill := HudStyle.color("slot")
	if rank > 0:
		fill = Color(HudStyle.color("accent"), 0.16)
	canvas.draw_rect(rect, fill)
	var edge := HudStyle.color("panel_edge")
	if state == "open":
		edge = Color(HudStyle.color("accent"), 0.9 if hot else 0.55)
	elif rank > 0:
		edge = Color(HudStyle.color("accent"), 0.8)
	canvas.draw_rect(rect, edge, false, 2.0 if (hot and state == "open") else 1.0)
	var x := rect.position.x + 6
	var icon: Texture2D = n.get("icon", null)
	var side := minf(32.0, rect.size.y - 8.0)
	if icon != null:
		canvas.draw_texture_rect(icon, Rect2(Vector2(x, rect.get_center().y - side * 0.5), Vector2(side, side)), false, Color(1, 1, 1, 0.35 if locked else 1.0))
		x += side + 6.0
	var tint := HudStyle.color("text_muted") if locked else (HudStyle.color("accent") if rank > 0 else HudStyle.color("text"))
	# a long name takes the smaller size, so it stays inside its node; a talent lock shows a small mark
	var name := str(n.name)
	var size := 12 if HudStyle.width(font, name, 12) <= rect.end.x - x - 4.0 else 10
	var top := rect.position.y + (rect.size.y - 22.0) * 0.5
	HudStyle.text(canvas, font, Vector2(x, top + 12), name, size, tint)
	# rank pips
	for i in range(int(n.max)):
		var pip := Rect2(x + i * 12.0, top + 16, 8, 6)
		canvas.draw_rect(pip, HudStyle.color("accent") if i < rank else HudStyle.color("track"))
