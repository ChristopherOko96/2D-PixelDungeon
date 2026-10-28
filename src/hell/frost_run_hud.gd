extends RefCounted
## Story 1's run HUD for the Frostgruft (theme "hud": "crypt"), drawn like
## src/ui/run_hud.gd with the crypt's bevelled frames (src/ui/crypt_ui.gd) and
## pixel font: the hero panel top left (class or subclass, hearts, HP, keys,
## runes, flames, shield, conditions), the guardian's bar top centre (one
## segment per phase), floor, rooms, fight state and minimap top right with
## the menu chip, and bottom centre the level chip, the skill slots with the
## crypt's skill icons (subclass skills get icons from their building block,
## the master skill on key 5) and the EXP bar. Hints and prompts sit in the
## same frames. Display only.

const CryptUI = preload("res://src/ui/crypt_ui.gd")
const PixelStyle = preload("res://src/pixel_style.gd")
const SkillIcons = preload("res://src/ui/skill_icons.gd")
const HeroKit = preload("res://src/hell/hero_kit.gd")
const RelicKit = preload("res://src/hell/relic_kit.gd")
const BossKit = preload("res://src/hell/boss_kit.gd")
const Rules = preload("res://src/hell/hell_rules.gd")
const HeroFx = preload("res://src/hell/hero_fx.gd")
const FrostItems = preload("res://src/hell/frost_items.gd")
const MARGIN := 20.0
const SLOT := 72.0
const GAP := 8.0
const MAP_W := 244.0
const BOSS_W := 560.0
## Icon of a subclass skill by its building block: glyph and badge of src/ui/skill_icons.gd.
const DO_ICON := {"shot": ["fan", ""], "wall": ["", "wall"], "zone": ["", "snow"], "nova": ["swirl", "snow"], "summon": ["", "skull"],
	"buff": ["rage", "shield"], "corpse": ["fireball", "skull"], "harvest": ["swirl", "heart"], "taunt": ["", "eye"], "leap": ["leap", ""],
	"stealth": ["", "mirror"], "step": ["blink", ""], "trap": ["", "target"], "rally": ["", "up"]}
## Weapon sprite (assets/sprites/0x72) the subclass icons are built on.
const SUB_BASE := {"frost": "weapon_green_magic_staff", "necro": "weapon_red_magic_staff", "tank": "weapon_knight_sword", "axe": "weapon_axe",
	"shadow": "weapon_knife", "beast": "weapon_bow"}

static var _font: Font


static func on(g: Node) -> bool:
	return str(g.theme.get("hud", "")) == "crypt"


static func font() -> Font:
	if _font == null:
		_font = PixelStyle.create_font()
	return _font


static func text(h: CanvasItem, at: Vector2, value: String, size: int, color: Color) -> void:
	h.draw_string_outline(font(), at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 4, CryptUI.INK)
	h.draw_string(font(), at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


static func width(value: String, size: int) -> float:
	return font().get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


static func text_right(h: CanvasItem, at: Vector2, value: String, size: int, color: Color) -> void:
	text(h, at - Vector2(width(value, size), 0), value, size, color)


static func text_centered(h: CanvasItem, at: Vector2, value: String, size: int, color: Color) -> void:
	text(h, at - Vector2(floorf(width(value, size) * 0.5), 0), value, size, color)


# ---------- top left: the hero ----------

static func hero_panel(g: Node, h: CanvasItem) -> float:
	var st: Dictionary = g.state
	var heart := Vector2(32, 32)
	var icons := int(st.max_hp) / 2
	var per_row := 8
	var rows := maxi(1, ceili(icons / float(per_row)))
	var who := str(g.sub_kit.name).to_upper() if not g.sub_kit.is_empty() else str(g.hero.get("name", "HELD")).to_upper()
	var title := "LV %d · %s" % [int(st.get("level", 1)), who]
	var hp_text := "%d / %d" % [int(st.hp), int(st.max_hp)] if int(st.hp) > 0 else "GEFALLEN"
	var heart_row := minf(icons, per_row) * (heart.x + 4.0)
	var w := maxf(300.0, maxf(width(title, 16) + 28.0, heart_row + width(hp_text, 16) + 44.0))
	var hgt := 44.0 + rows * (heart.y + 4.0) + 44.0
	var panel := Rect2(MARGIN, MARGIN, w, hgt)
	CryptUI.draw_box(h, "panel", panel)
	text(h, panel.position + Vector2(14, 26), title, 16, CryptUI.GOLD)
	text_right(h, Vector2(panel.end.x - 14, panel.position.y + 38 + heart.y - 6), hp_text, 16, CryptUI.BONE if int(st.hp) > 0 else CryptUI.BLOOD)
	for i in range(icons):
		var v: int = int(st.hp) - i * 2
		var at := panel.position + Vector2(14 + (i % per_row) * (heart.x + 4.0), 38 + (i / per_row) * (heart.y + 4.0))
		var pulse := 1.0 + (0.12 * sin(float(st.t) * 8.0) if int(st.hp) <= 2 and v > 0 else 0.0)
		h.draw_texture_rect(g.hearts.full if v >= 2 else (g.hearts.half if v == 1 else g.hearts.empty), Rect2(at + heart * (1.0 - pulse) / 2.0, heart * pulse), false)
	# keys, rune stones and flames in an inset row
	var row := Rect2(panel.position + Vector2(10, panel.size.y - 42), Vector2(panel.size.x - 20, 32))
	CryptUI.draw_box(h, "inset", row)
	var x := row.position.x + 10.0
	for k in ["A", "B", "C"]:
		var tint: Color = g.key_tint[k]
		tint.a = 1.0 if st.keys[k] else (0.14 if st.used[k] else 0.25)
		h.draw_texture_rect(g.tex[g.key_sprite[k]], Rect2(x, row.position.y + 5, 12, 22), false, tint)
		x += 20.0
	h.draw_texture_rect(g.tex.rune_gem, Rect2(x + 6, row.position.y + 5, 15, 22), false)
	text(h, Vector2(x + 26, row.position.y + 23), "%d" % int(st.gems), 16, CryptUI.BONE)
	x += 70.0
	var fire := Rules.group_progress(g.W.ents, "feuer")
	if fire.y > 0:
		h.draw_texture_rect(g.tex.brazier_bowl, Rect2(x, row.position.y + 3, 18, 26), false)
		text(h, Vector2(x + 24, row.position.y + 23), "%d/%d" % [fire.x, fire.y], 16, CryptUI.BONE)
	var shield := int(FrostItems.inv(g).get("shield", 0))
	if shield > 0:
		text_right(h, Vector2(row.end.x - 10, row.position.y + 23), "+%d SCHILD" % shield, 16, CryptUI.FROST)
	var y := panel.end.y + 8.0
	if not HeroFx._all(g).is_empty():
		HeroFx.draw_hud(g, h, Vector2(MARGIN, y), font())
		y += 28.0
	var sk: Dictionary = st.skill
	if sk.owned:
		var clock := "%d:%02d" % [int(sk.left) / 60, int(sk.left) % 60]
		text(h, Vector2(MARGIN + 4, y + 16), ("KLON AKTIV · " + clock) if sk.active else ("Q: KLON · " + clock), 16, CryptUI.FROST if sk.active else CryptUI.SAND)
		y += 24.0
	return y


# ---------- top right: floor, rooms, map ----------

static func floor_rect(size: Vector2) -> Rect2:
	return Rect2(size.x - MARGIN - MAP_W, MARGIN, MAP_W, 236)


static func floor_panel(g: Node, h: CanvasItem, size: Vector2) -> float:
	var panel := floor_rect(size)
	CryptUI.draw_box(h, "panel", panel)
	text(h, panel.position + Vector2(14, 32), "ETAGE %d" % int(g.state.floor), 24, CryptUI.GOLD)
	text(h, panel.position + Vector2(14, 54), "RÄUME %02d / %02d" % [(g.state.visited as Dictionary).size(), g.W.rooms.size()], 16, CryptUI.BONE)
	var cr: Dictionary = g.W.rooms[g.state.room]
	var tag := "ERKUNDEN"
	var c := CryptUI.SAND
	if cr.fight:
		var left := 0
		for m: Dictionary in g.mobs:
			if m.room == cr.index:
				left += 1
		tag = "KAMPF · %d" % left
		c = CryptUI.BLOOD
	elif g.state.boss_dead:
		tag = "WÄCHTER BESIEGT"
		c = CryptUI.GOLD
	text(h, panel.position + Vector2(14, 76), tag, 16, c)
	g._draw_map(h, size, false, Rect2(panel.position + Vector2(14, 88), Vector2(panel.size.x - 28, panel.size.y - 100)))
	var menu := Rect2(panel.position.x, panel.end.y + 6, MAP_W, 34)
	CryptUI.draw_box(h, "button", menu)
	text_centered(h, Vector2(menu.get_center().x, menu.position.y + 23), "MENÜ · ESC", 16, CryptUI.BONE)
	return menu.end.y + 8.0


# ---------- top centre: the guardian ----------

## The guardian's bar: name, one segment per phase, HP and its title. Returns its bottom.
static func boss_bar(g: Node, h: CanvasItem, size: Vector2, boss: Dictionary) -> float:
	var w := minf(BOSS_W, size.x - 2.0 * (MAP_W + MARGIN * 2.0))
	var top := MARGIN
	var frame := Rect2((size.x - w) * 0.5, top + 34, w, 32)
	var pname := str(BossKit.phase(boss).get("name", "")) if boss.has("kit") else ""
	text_centered(h, Vector2(size.x * 0.5, top + 26), str(g.W.boss.name).to_upper(), 24, CryptUI.CREAM)
	var tag := pname.to_upper() if pname != "" else ("ENDBOSS" if g.W.final else ("ZWISCHENBOSS" if g.W.boss.get("mini", false) else "WÄCHTER DER ETAGE"))
	text_centered(h, Vector2(size.x * 0.5, frame.end.y + 20), tag, 16, CryptUI.VOID if g.W.final else CryptUI.SAND)
	CryptUI.draw_box(h, "inset", frame)
	var inner := Rect2(frame.position + Vector2(6, 6), frame.size - Vector2(12, 12))
	h.draw_rect(inner, CryptUI.BLOOD_DARK)
	var bars: int = (boss.phase_hp as Array).size() if boss.has("kit") else 1
	var phase_i: int = int(boss.phase) if boss.has("kit") else 0
	var seg := inner.size.x / bars
	var total := 0.0
	var left := maxf(0.0, float(boss.hp))
	for i in range(bars):
		var fill: float = 0.0 if i < phase_i else (1.0 if i > phase_i else clampf(float(boss.hp) / maxf(1.0, float(boss.max)), 0.0, 1.0))
		var col := (CryptUI.VOID if g.W.final else CryptUI.BLOOD)
		if float(boss.get("inv", 0.0)) > 0.0:
			col = CryptUI.CREAM
		h.draw_rect(Rect2(inner.position + Vector2(seg * i, 0), Vector2(floorf(seg * fill), inner.size.y)), col)
		h.draw_rect(Rect2(inner.position + Vector2(seg * i, 0), Vector2(floorf(seg * fill), 4)), Color(1, 1, 1, 0.18))
		if i > 0:
			h.draw_rect(Rect2(inner.position + Vector2(floorf(seg * i) - 1, 0), Vector2(3, inner.size.y)), CryptUI.INK)
		if boss.has("kit"):
			total += float(boss.phase_hp[i])
			if i > phase_i:
				left += float(boss.phase_hp[i])
	if not boss.has("kit"):
		total = float(boss.max)
		for q in [0.25, 0.5, 0.75]:
			h.draw_rect(Rect2(inner.position + Vector2(floorf(inner.size.x * q), 0), Vector2(2, inner.size.y)), Color(CryptUI.INK, 0.6))
	text_centered(h, Vector2(size.x * 0.5, inner.end.y - 3), "%d / %d" % [ceili(left), roundi(total)], 16, CryptUI.CREAM)
	return frame.end.y + 30.0


# ---------- bottom centre: level, skills, EXP ----------

static func skill_bar_top(size: Vector2) -> float:
	return size.y - MARGIN - SLOT - 12.0


## The slot list: {key, icon, cd, max, open, unlock, gold}.
static func slots(g: Node) -> Array:
	var out: Array = []
	if g.relic_on():
		var rel := RelicKit.wielded(g)
		for s: Dictionary in rel.skills:
			out.append({"key": str(s.key), "icon": g.relic_tex, "tint": g._color(rel.tint), "cd": float(g.state.skill_cd.get(str(s.id), 0.0)), "max": float(s.cooldown),
				"open": int(g.state.level) >= int(s.unlock), "unlock": int(s.unlock), "name": str(s.short)})
	else:
		for i in range(g.skills.size()):
			var s: Dictionary = g.skills[i]
			var icon: Texture2D
			if g.sub_kit.is_empty():
				icon = SkillIcons.skill(g.class_id, i)
			else:
				var pair: Array = DO_ICON.get(str(s.do), ["", "plus"])
				icon = SkillIcons.icon({"base": SUB_BASE.get(str(g.sub_kit.id), "weapon_knight_sword"), "glyph": pair[0], "badge": pair[1]})
			out.append({"key": str(s.key), "icon": icon, "cd": float(g.state.skill_cd.get(str(s.key), 0.0)), "max": float(s.cooldown),
				"open": HeroKit.unlocked(g, s), "unlock": int(s.unlock), "name": str(s.get("short", s.name))})
	var master := str(g.state.get("talent", {}).get("master", ""))
	if master != "":
		var base: String = SUB_BASE.get(str(g.sub_kit.get("id", "")), {"mage": "weapon_red_magic_staff", "swordsman": "weapon_knight_sword", "archer": "weapon_bow"}.get(g.class_id, "weapon_knight_sword"))
		out.append({"key": "5", "icon": SkillIcons.icon({"base": base, "glyph": "rage", "badge": "crit"}), "cd": float(g.state.skill_cd.get("5", 0.0)),
			"max": float(g.theme.get("master_cooldown", 45.0)), "open": true, "unlock": 1, "gold": true})
	return out


static func skill_bar(g: Node, h: CanvasItem, size: Vector2) -> void:
	var list := slots(g)
	var count := list.size() + 1
	var total := SLOT * count + GAP * (count - 1)
	var x := floorf((size.x - total) * 0.5)
	var y := skill_bar_top(size)
	var chip := Rect2(x, y, SLOT, SLOT)
	CryptUI.draw_box(h, "slot_ready", chip)
	text_centered(h, Vector2(chip.get_center().x, chip.position.y + 24), "LV", 16, CryptUI.SAND)
	text_centered(h, Vector2(chip.get_center().x, chip.position.y + 54), str(int(g.state.level)), 32, CryptUI.GOLD)
	x += SLOT + GAP
	for sl: Dictionary in list:
		var r := Rect2(x, y, SLOT, SLOT)
		var ready: bool = sl.open and float(sl.cd) <= 0.0
		CryptUI.draw_box(h, "slot_ready" if ready else "slot", r)
		var icon: Texture2D = sl.icon
		if icon != null:
			var tint: Color = sl.get("tint", Color.WHITE)
			tint = Color(0.3, 0.28, 0.28) if not sl.open else (tint * Color(0.62, 0.6, 0.6) if float(sl.cd) > 0.0 else tint)
			var k := minf((SLOT - 8.0) / icon.get_width(), (SLOT - 8.0) / icon.get_height())
			var isz := icon.get_size() * k
			h.draw_texture_rect(icon, Rect2(r.get_center() - isz / 2.0, isz), false, tint)
		if sl.open and float(sl.cd) > 0.0:
			var share := clampf(float(sl.cd) / maxf(0.01, float(sl.max)), 0.0, 1.0)
			h.draw_rect(Rect2(r.position + Vector2(4, 4), Vector2(SLOT - 8, (SLOT - 8) * share)), Color(CryptUI.INK, 0.6))
			text_centered(h, r.get_center() + Vector2(0, 8), ("%d" % ceili(float(sl.cd))) if float(sl.cd) >= 1.0 else ("%.1f" % float(sl.cd)), 24, CryptUI.CREAM)
		if not sl.open:
			text_centered(h, r.get_center() + Vector2(0, 26), "LV %d" % int(sl.unlock), 16, CryptUI.SAND)
		if FrostItems.sealed_key(g) == str(sl.key):
			h.draw_line(r.position + Vector2(8, 8), r.end - Vector2(8, 8), CryptUI.VOID, 4.0)
		var key := Rect2(r.position + Vector2(-4, -6), Vector2(22, 22))
		CryptUI.draw_box(h, "button", key)
		text_centered(h, key.get_center() + Vector2(0, 6), str(sl.key), 16, CryptUI.GOLD if sl.get("gold", false) else CryptUI.CREAM)
		x += SLOT + GAP
	var bar := Rect2(floorf((size.x - total) * 0.5), y + SLOT + 4, total, 8)
	h.draw_rect(bar, CryptUI.INK)
	var cfg: Dictionary = g.theme.get("leveling", {})
	if not cfg.is_empty():
		var need := float(HeroKit.need(cfg, int(g.state.level)))
		h.draw_rect(Rect2(bar.position + Vector2(1, 1), Vector2((bar.size.x - 2) * clampf(float(g.state.exp) / maxf(1.0, need), 0.0, 1.0), bar.size.y - 2)), Color("5fe0a0"))


# ---------- hints, prompts, controls ----------

static func toasts(g: Node, h: CanvasItem, size: Vector2) -> void:
	var list: Array = g.state.toasts
	var base := skill_bar_top(size) - 34.0 if not g.skills.is_empty() else size.y - 60.0
	for i in range(list.size()):
		var tt: Dictionary = list[i]
		var fade := minf(1.0, float(tt.t) * 2.0)
		var ty := base - (list.size() - 1 - i) * 44.0
		var w := width(str(tt.text), 16) + 40.0
		var r := Rect2(size.x / 2.0 - w / 2.0, ty - 20, w, 38)
		h.draw_set_transform(Vector2.ZERO)
		CryptUI.draw_box(h, "inset", r)
		text_centered(h, Vector2(size.x / 2.0, ty + 5), str(tt.text), 16, Color(CryptUI.BONE, fade))


static func prompt(g: Node, h: CanvasItem, size: Vector2, p: Vector2, label: String) -> void:
	var sp: Vector2 = g._to_screen(p, size) - Vector2(0, 70)
	var w := width(label, 16) + 64.0
	var r := Rect2(sp.x - w / 2.0, sp.y - 20, w, 40)
	CryptUI.draw_box(h, "panel", r)
	var key := Rect2(r.position + Vector2(8, 8), Vector2(24, 24))
	CryptUI.draw_box(h, "button", key)
	text_centered(h, key.get_center() + Vector2(0, 6), "E", 16, CryptUI.GOLD)
	text(h, Vector2(r.position.x + 42, sp.y + 6), label, 16, CryptUI.CREAM)


static func controls(h: CanvasItem, size: Vector2) -> void:
	text(h, Vector2(MARGIN, size.y - 12), "C STATUS · I RUCKSACK · M KARTE · T WAFFE · F1-F10 ETAGE", 12, CryptUI.MUTED)
