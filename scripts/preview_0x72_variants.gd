extends SceneTree
## Proofs of the 0x72 enemy and boss variants (candidates, NOT in the game):
## every rig of production/qa/evidence/0x72-variants/rigs_variants.json (made
## by `node production/art-proof/0x72-style/export_rigs.js --variants`) is
## drawn with the game's own RigLibrary and RigRenderer at 4 screen pixels per
## source pixel on a dark floor: the original 0x72 frame next to the game's
## recolour, the rest pose, the parts pulled apart with their pivots, eight
## frames each of standing and walking, the attack from windup to recovery,
## the family's special clip, hits, every breakable part cut off (with the
## renderer's own debris), legless crawl / lone-head hop where the rig allows
## them, and the death. Also roster.png, all variants by world.
## Needs a window (headless renders nothing):
##   godot --path . --resolution 1280x720 -s res://scripts/preview_0x72_variants.gd -- [out_dir] [only_id]

const RigLibrary = preload("res://src/rig/rig_library.gd")
const RigRenderer = preload("res://src/rig/rig_renderer.gd")
const DATA := "res://production/qa/evidence/0x72-variants/rigs_variants.json"
## Screen pixels per source pixel.
const PX := 4.0
const GAP := 8.0
const TITLE_W := 124.0
const LABEL_H := 18.0
const BG := Color("141119")
const FLOOR := Color("221e2a")
const TEXT := Color("eadfca")
const DIM := Color("a69bb5")
const WORLD_NAMES := {"crypt": "Krypta", "frost": "Frostgruft", "hell": "Hölle"}
const ROLE_NAMES := {"mob": "Gegner", "elite": "Elite", "miniboss": "Mini-Boss", "boss": "Boss"}
## Seconds per idle and walk cycle of each pose family (src/rig/rig_poses.gd).
const IDLE := {"skeleton": 1.1, "necro": 1.8, "biped": 1.2, "brute": 1.6}
const WALK := {"skeleton": 0.5, "necro": 1.8, "biped": 0.46, "brute": 0.8}
## The ice elf's alternative B: glowing eyes on top of map A (one pass).
const ELF_B := {"#5698cc": "#72d6ce"}

var _out := "res://production/qa/evidence/0x72-variants"
var _only := ""
var _library: RefCounted
var _data: Dictionary = {}
var _uid := 1000


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0: _out = args[0]
	if args.size() > 1: _only = args[1]
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("preview_0x72_variants: needs a window (headless draws nothing)")
		quit(1)
		return
	_data = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	_library = RigLibrary.new()
	if not _library.load_data(DATA, ""):
		printerr("preview_0x72_variants: could not load ", DATA)
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	var names: Array = _data.rigs.keys()
	for name: String in names:
		if not _only.is_empty() and name != _only: continue
		await _save(_proof_page(name), name + ".png")
	if _only.is_empty() or _only == "roster": await _save(_roster_page(), "roster.png")
	quit(0)


# ------------------------------------------------------------------ pages

## One proof page: header, panels and the clip rows of one variant.
func _proof_page(name: String) -> Dictionary:
	var rig: Dictionary = _library.rig(name)
	var spec: Dictionary = _data.rigs[name]
	var meta: Dictionary = _data.roster.get(name, {})
	var family := str(rig.family)
	var box := _box(rig)
	var cell := box.size * PX
	var page := {"cells": [], "texts": [], "size": Vector2.ZERO}
	var y := 12.0
	var title := "%s  (%s)   %s, %s, Faktor %s" % [str(meta.get("name", name)), name, WORLD_NAMES.get(str(meta.get("world", "")), "?"),
		ROLE_NAMES.get(str(meta.get("role", "")), "?"), str(meta.get("scale", 1))]
	_text(page, Vector2(12, y), title, 22, TEXT)
	y += 30.0
	var recolor: Variant = spec.get("recolor")
	_text(page, Vector2(12, y), "Quelle: 0x72 v1.7 %s.png (CC0, unverändert)   Familie: %s%s" % [str(meta.get("source", "")), family,
		(" / " + str(rig.variant)) if not str(rig.variant).is_empty() else ""], 13, DIM)
	y += 18.0
	_text(page, Vector2(12, y), "Pipette: " + (_map_text(recolor) if recolor is Dictionary else "keine (Originalfarben)"), 13, DIM)
	y += 26.0
	# Panels: original, game recolour, (ice elf B), rest pose, exploded parts.
	var source: Image = load(str(_data.images[spec.img])).get_image()
	var x := 12.0
	var panel_h := cell.y
	x = _image_cell(page, Vector2(x, y + LABEL_H), box, ImageTexture.create_from_image(source), "Original 0x72") + GAP
	if recolor is Dictionary:
		x = _parts_cell(page, Vector2(x, y + LABEL_H), box, rig, "Spiel-Umfärbung") + GAP
	if name == "frost_ice_elf":
		var map_b: Dictionary = recolor.duplicate()
		map_b.merge(ELF_B, true)
		x = _image_cell(page, Vector2(x, y + LABEL_H), box, ImageTexture.create_from_image(_swap(source, map_b)), "Variante B: Leuchtaugen") + GAP
	x = _rig_cell(page, Vector2(x, y + LABEL_H), name, box, "Ruhe-Pose", {"t": 0.0}) + GAP
	var exploded := Rect2(box.position - Vector2(8, 6), box.size + Vector2(16, 12))
	x = _exploded_cell(page, Vector2(x, y + LABEL_H), exploded, rig, "Teile einzeln (rot: Drehpunkt)") + GAP
	var lines := _part_lines(rig)
	for i in range(lines.size()): _text(page, Vector2(x + 6, y + LABEL_H + i * 17.0), lines[i], 13, TEXT if i == 0 else DIM)
	page.size.x = maxf(page.size.x, x + 420.0)
	y += LABEL_H + maxf(panel_h, exploded.size.y * PX) + 16.0
	# Clip rows.
	var idle: float = IDLE.get(family, 1.2)
	var walk: float = WALK.get(family, 0.5)
	y = _row(page, y, "Stehen", name, box, _times(8, idle).map(func(t: float) -> Dictionary: return {"t": t, "label": "t %.2f s" % t}))
	y = _row(page, y, "Gehen", name, box, _times(8, walk).map(func(t: float) -> Dictionary: return {"t": t, "moving": true, "label": "t %.2f s" % t}))
	y = _row(page, y, "Angriff", name, box, _attack_frames(rig, ""))
	match family:
		"necro": y = _row(page, y, "Beschwören", name, box, _attack_frames(rig, "summon"))
		"brute":
			var special: Array = _attack_frames(rig, "roar").slice(0, 5)
			for left: float in [1.1, 0.8, 0.5, 0.2]: special.append({"t": 0.4, "regrowing": {"arm": left}, "label": "nachwachsen %.0f %%" % (100.0 * (1.0 - left / 1.2))})
			y = _row(page, y, "Brüllen, Arm\nwächst nach", name, box, special)
		"skeleton":
			if str(rig.variant) == "guard":
				var guard: Array = []
				for k: float in [0.15, 0.35, 0.55, 0.8]: guard.append({"t": 0.3, "clip": "block", "clip_len": 0.9, "ct": k * 0.9, "label": "Block %.0f %%" % (k * 100.0)})
				y = _row(page, y, "Schild-Block", name, box, guard)
	var hits: Array = []
	for k: float in [0.05, 0.3, 0.6]: hits.append({"t": 0.2, "clip": "hit", "clip_len": 0.3, "ct": k * 0.3, "flash": 0.14 if k < 0.1 else 0.0, "label": "Treffer %.0f %%" % (k * 100.0)})
	y = _row(page, y, "Treffer", name, box, hits)
	y = _row(page, y, "Teile ab", name, box, _loss_frames(rig))
	y = _row(page, y, "Tod", name, _death_box(rig, box), _death_frames(rig))
	page.size.y = y + 8.0
	return page


## All variants by world: rest pose and the strike of the attack.
func _roster_page() -> Dictionary:
	var page := {"cells": [], "texts": [], "size": Vector2.ZERO}
	var y := 12.0
	_text(page, Vector2(12, y), "0x72-Varianten (Kandidaten, nicht im Spiel)   4 Bildpunkte je Quellpixel; links Ruhe, rechts Angriff", 20, TEXT)
	y += 36.0
	for world: String in ["crypt", "frost", "hell"]:
		_text(page, Vector2(12, y), WORLD_NAMES[world], 20, TEXT)
		var x := TITLE_W
		var row_h := 0.0
		for name: String in _data.rigs:
			if str(_data.roster.get(name, {}).get("world", "")) != world: continue
			var rig: Dictionary = _library.rig(name)
			var box := _box(rig)
			var frames: Array = _attack_frames(rig, "")
			var strike: Dictionary = frames[4]
			var label := "%s (%s)" % [str(_data.roster[name].name), name]
			_text(page, Vector2(x, y), label, 13, TEXT)
			var after := _rig_cell(page, Vector2(x, y + LABEL_H), name, box, "", {"t": 0.0})
			after = _rig_cell(page, Vector2(after + 2.0, y + LABEL_H), name, box, "", strike)
			x = maxf(after, x + label.length() * 7.5) + GAP * 2.0
			row_h = maxf(row_h, box.size.y * PX)
		page.size.x = maxf(page.size.x, x)
		y += LABEL_H + row_h + 24.0
	page.size.y = y
	return page


## A row of rig frames with a title on the left; returns the next y.
func _row(page: Dictionary, y: float, title: String, name: String, box: Rect2, frames: Array) -> float:
	if frames.is_empty(): return y
	_text(page, Vector2(12, y + LABEL_H + 4.0), title, 15, TEXT)
	var x := TITLE_W
	for frame: Dictionary in frames: x = _rig_cell(page, Vector2(x, y + LABEL_H), name, box, str(frame.get("label", "")), frame) + GAP
	page.size.x = maxf(page.size.x, x + 4.0)
	return y + LABEL_H + box.size.y * PX + 12.0


func _times(count: int, period: float) -> Array:
	var result: Array = []
	for i in range(count): result.append(period * float(i) / float(count))
	return result


## Eight frames of an attack clip: three of the windup, two strike, three recovery.
func _attack_frames(rig: Dictionary, kind: String) -> Array:
	var renderer := RigRenderer.new(_library)
	var mapping: Array = renderer._attack_mapping(rig, kind)
	var frames: Array = []
	var phases := [["windup", 0.33], ["windup", 0.66], ["windup", 1.0], ["active", 0.5], ["active", 1.0], ["recover", 0.33], ["recover", 0.66], ["recover", 1.0]]
	var names := {"windup": "Ausholen", "active": "Treffen", "recover": "Zurück"}
	for phase: Array in phases:
		frames.append({"t": 0.3, "attack": phase[0], "attack_p": phase[1], "attack_kind": kind, "label": "%s %.0f %%" % [names[phase[0]], float(phase[1]) * 100.0]})
	return frames


## Every breakable part cut off (renderer debris), crawl and hop where allowed.
func _loss_frames(rig: Dictionary) -> Array:
	var frames: Array = []
	for part: Dictionary in rig.parts + rig.items:
		if bool(part.vital) or bool(part.unbreakable): continue
		var lost: Array = [part.id] + Array(part.also_detach)
		var what := "%s ab" % str(part.label)
		if not str(part.disables).is_empty(): what += ": kein %s" % {"attack": "Angriff", "cast": "Zauber", "block": "Block"}.get(str(part.disables), str(part.disables))
		frames.append({"t": 0.3, "cut": lost, "label": what})
	var by_id: Dictionary = rig.by_id
	var family := str(rig.family)
	if family == "skeleton":
		var legs_break: bool = by_id.has("leg_l") and not bool(by_id.leg_l.unbreakable)
		if legs_break:
			for t: float in [0.1, 0.35]: frames.append({"t": t, "moving": true, "lost": ["leg_l", "leg_r"], "label": "ohne Beine, kriecht"})
		if by_id.has("torso") and not bool(by_id.torso.unbreakable):
			for t: float in [0.05, 0.25]: frames.append({"t": t, "moving": true, "lost": ["torso", "leg_l", "leg_r"], "label": "nur Kopf, hüpft"})
	elif family == "biped":
		for t: float in [0.1, 0.3]: frames.append({"t": t, "moving": true, "lost": ["foot_l", "foot_r"], "label": "ohne Füße"})
	return frames


## Death: skeletons crumble into debris, the others play the death clip.
func _death_frames(rig: Dictionary) -> Array:
	if str(rig.family) == "skeleton": return [{"t": 0.3, "crumble": true, "label": "zerfällt (Trümmer)"}]
	var frames: Array = []
	for p: float in [0.15, 0.35, 0.55, 0.75, 0.95]: frames.append({"t": 0.3, "dying_p": p, "label": "Tod %.0f %%" % (p * 100.0)})
	return frames


# ------------------------------------------------------------------ cells

## Source-pixel box a figure needs, with room for the swing of its items.
func _box(rig: Dictionary) -> Rect2:
	var size: Vector2 = rig.size
	var box := Rect2(Vector2.ZERO, size)
	var reach := 4.0
	for item: Dictionary in rig.items:
		box = box.merge(item.bounds)
		var bounds: Rect2 = item.bounds
		reach = maxf(reach, minf(bounds.size.length() * 0.3, 10.0))
	match str(rig.family):
		"brute": reach = maxf(reach, 9.0)
		"necro": reach = maxf(reach, 6.0)
	return Rect2(box.position - Vector2(reach, reach + 2.0), box.size + Vector2(reach * 2.0, reach + 9.0))


## The box of the death row: brutes fall forward, bipeds backward.
func _death_box(rig: Dictionary, box: Rect2) -> Rect2:
	match str(rig.family):
		"brute": return Rect2(box.position, box.size + Vector2(26, 0))
		"biped": return Rect2(box.position - Vector2(10, 0), box.size + Vector2(10, 0))
	return box


func _text(page: Dictionary, at: Vector2, text: String, size: int, color: Color) -> void:
	page.texts.append({"at": at, "text": text, "size": size, "color": color})


func _image_cell(page: Dictionary, at: Vector2, box: Rect2, texture: Texture2D, label: String) -> float:
	page.cells.append({"kind": "image", "at": at, "size": box.size * PX, "scale": PX, "texture": texture, "offset": -box.position, "label": label})
	return at.x + box.size.x * PX


func _parts_cell(page: Dictionary, at: Vector2, box: Rect2, rig: Dictionary, label: String) -> float:
	page.cells.append({"kind": "parts", "at": at, "size": box.size * PX, "scale": PX, "rig": rig, "offset": -box.position, "label": label})
	return at.x + box.size.x * PX


func _exploded_cell(page: Dictionary, at: Vector2, box: Rect2, rig: Dictionary, label: String) -> float:
	page.cells.append({"kind": "exploded", "at": at, "size": box.size * PX, "scale": PX, "rig": rig, "offset": -box.position, "label": label})
	return at.x + box.size.x * PX


## One rig frame drawn by the game's renderer. `frame`: t, moving, attack,
## attack_p, attack_kind, clip/clip_len/ct, flash, lost, regrowing, dying_p,
## cut (parts severed after a first draw: debris), crumble (skeleton death).
func _rig_cell(page: Dictionary, at: Vector2, name: String, box: Rect2, label: String, frame: Dictionary) -> float:
	var rig: Dictionary = _library.rig(name)
	var S: float = float(rig.scale)
	_uid += 1
	var ground: Vector2 = rig.ground
	var center: Vector2 = rig.center
	var feet := (ground - box.position) * S
	var enemy := {"uid": _uid, "rig": name, "face": 1.0, "moving": bool(frame.get("moving", false)), "hits": 0, "blocks": 0}
	for key: String in ["attack", "attack_p", "attack_kind", "dying_p"]:
		if frame.has(key): enemy[key] = frame[key]
	if frame.has("flash"):
		enemy.hit_flash = frame.flash
	var renderer := RigRenderer.new(_library)
	var actor: Dictionary = renderer._actor("e%d" % _uid, enemy)
	actor.t = float(frame.get("t", 0.0))
	var lost: Dictionary = {}
	for id: Variant in frame.get("lost", []): lost[str(id)] = true
	actor.lost = lost
	actor.regrowing = Dictionary(frame.get("regrowing", {})).duplicate()
	if frame.has("clip"):
		actor.clip = frame.clip
		actor.clip_len = frame.clip_len
		actor.ct = frame.ct
	page.cells.append({"kind": "rig", "at": at, "size": box.size * PX, "scale": PX / S, "renderer": renderer, "enemy": enemy,
		"point": feet - Vector2(0, (ground.y - center.y) * S), "label": label, "cut": frame.get("cut", []), "crumble": bool(frame.get("crumble", false))})
	return at.x + box.size.x * PX


# ------------------------------------------------------------------ drawing

func _save(page: Dictionary, file: String) -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(ceili(page.size.x), ceili(page.size.y))
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	root.add_child(viewport)
	var back := ColorRect.new()
	back.color = BG
	back.size = page.size
	viewport.add_child(back)
	var nodes: Array = []
	for cell: Dictionary in page.cells:
		var frame := Control.new()
		frame.position = cell.at
		frame.size = cell.size
		frame.clip_contents = true
		var floor_rect := ColorRect.new()
		floor_rect.color = FLOOR
		floor_rect.size = cell.size
		frame.add_child(floor_rect)
		var node := Node2D.new()
		node.scale = Vector2(cell.scale, cell.scale)
		node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		node.draw.connect(_draw_cell.bind(node, cell))
		frame.add_child(node)
		viewport.add_child(frame)
		nodes.append(node)
		if not str(cell.label).is_empty(): _label(viewport, cell.at - Vector2(0, LABEL_H - 1.0), str(cell.label), 11, DIM)
	for text: Dictionary in page.texts: _label(viewport, text.at, text.text, text.size, text.color)
	await process_frame
	await process_frame
	# Cut parts and crumbling skeletons: the renderer saw the figure whole,
	# now it observes the loss (debris, chips) and lets the pieces fall.
	for i in range(page.cells.size()):
		var cell: Dictionary = page.cells[i]
		if cell.kind != "rig" or (Array(cell.cut).is_empty() and not bool(cell.crumble)): continue
		var cut: Dictionary = Dictionary(cell.enemy).duplicate()
		if bool(cell.crumble): cut.dying_p = 0.0
		else: cut.lost = cell.cut
		cell.renderer.observe({"enemies": [cut]})
		for step in range(14): cell.renderer.step(0.05)
		cell.enemy = cut
		cell.debris = true
		nodes[i].queue_redraw()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	var path := ProjectSettings.globalize_path(_out.path_join(file))
	print("PROOF %s %dx%d result=%d" % [path, image.get_width(), image.get_height(), image.save_png(path)])
	viewport.queue_free()
	await process_frame


func _label(parent: Node, at: Vector2, text: String, size: int, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.position = at
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)


func _draw_cell(node: Node2D, cell: Dictionary) -> void:
	match str(cell.kind):
		"image":
			node.draw_texture(cell.texture, cell.offset)
		"parts":
			for part: Dictionary in cell.rig.parts: node.draw_texture(part.texture, cell.offset)
		"exploded":
			_draw_exploded(node, cell)
		"rig":
			var renderer: RefCounted = cell.renderer
			if bool(cell.get("debris", false)): renderer.draw_under(node)
			renderer.draw_enemy(node, cell.enemy, cell.point)
			if bool(cell.get("debris", false)): renderer.draw_over(node, {"enemies": [cell.enemy]})


## The parts pulled away from the body centre, items at their hands, each
## pivot as a red pixel.
func _draw_exploded(node: Node2D, cell: Dictionary) -> void:
	var rig: Dictionary = cell.rig
	var center: Vector2 = rig.center
	var offset: Vector2 = cell.offset
	for part: Dictionary in rig.parts:
		var away: Vector2 = Vector2(part.center) - center
		var push: Vector2 = away * 0.3 + away.normalized() * 3.0
		node.draw_texture(part.texture, offset + push.round())
		node.draw_rect(Rect2(offset + push.round() + Vector2(part.pivot) - Vector2(0.5, 0.5), Vector2.ONE), Color("ff3b3b"))
	for item: Dictionary in rig.items:
		var hand: Vector2 = item.hand
		var push := (hand - center).normalized() * 6.0
		node.draw_set_transform_matrix(Transform2D(0.0, offset + push.round()) * Transform2D(float(item.rest), hand) * Transform2D(0.0, -Vector2(item.grip)))
		node.draw_texture(item.texture, Vector2.ZERO)
		node.draw_set_transform_matrix(Transform2D.IDENTITY)
		node.draw_rect(Rect2(offset + push.round() + hand - Vector2(0.5, 0.5), Vector2.ONE), Color("ff3b3b"))


## A copy of `image` with exact hex->hex swaps in one pass (comparison panel
## only; the rigs are recoloured by RigLibrary itself).
func _swap(image: Image, mapping: Dictionary) -> Image:
	var copy: Image = image.duplicate()
	copy.convert(Image.FORMAT_RGBA8)
	for y in range(copy.get_height()):
		for x in range(copy.get_width()):
			var color := copy.get_pixel(x, y)
			if color.a < 0.5: continue
			var key := "#" + color.to_html(false).to_lower()
			if mapping.has(key): copy.set_pixel(x, y, Color(str(mapping[key])))
	return copy


func _map_text(mapping: Dictionary) -> String:
	var pairs: Array[String] = []
	for from: String in mapping: pairs.append("%s→%s" % [from, mapping[from]])
	return ", ".join(pairs)


## "Teile:" and one line per part: id, label, HP weight and flags.
func _part_lines(rig: Dictionary) -> Array[String]:
	var lines: Array[String] = ["Teile (HP-Gewicht):"]
	for part: Dictionary in rig.parts + rig.items:
		var flags: Array[String] = []
		if bool(part.vital): flags.append("tödlich")
		if bool(part.unbreakable): flags.append("unzerstörbar")
		if not str(part.disables).is_empty(): flags.append("ab: kein " + {"attack": "Angriff", "cast": "Zauber", "block": "Block"}.get(str(part.disables), str(part.disables)))
		if float(part.regrow) > 0.0: flags.append("wächst in %.0f s nach" % float(part.regrow))
		if not Array(part.also_detach).is_empty(): flags.append("nimmt Beine mit")
		lines.append("%s%s  %s  %.0f  %s" % ["Gegenstand " if bool(part.is_item) else "", str(part.id), str(part.label), float(part.hp), ", ".join(flags)])
	return lines
