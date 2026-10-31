extends RefCounted
## The talent slots, the resource line and the reward banner, the same in
## every map: the run HUD of the crypt and the Frostgruft / Hölle HUD draw them
## through this object. There are no standard class skills (user decision
## 29.10.2026): the learned actives sit on keys 1-4 of the skill bar
## (src/ui/skill_bar.gd), the ultimate on R; empty slots wait for talents. The
## companion's abilities (5, 6) are drawn on the companion bar (HudKit.pet_panel).
## Above the bar the resource (mana blue, stamina green, rage red). Banner:
## "+2 SEELENSPLITTER" with the crystal, or a level-up note; queued, one at a time.

const CryptUI = preload("res://src/ui/crypt_ui.gd")
const PixelStyle = preload("res://src/pixel_style.gd")
const TalentIcons = preload("res://src/ui/talent_icons.gd")
const TalentScreen = preload("res://src/ui/talent_screen.gd")
const HudKit = preload("res://src/ui/hud_kit.gd")
const Profile = preload("res://src/progress/profile.gd")

var _font: Font = PixelStyle.create_font()
var _specs: Dictionary = {}
var _reward: Dictionary = {}
var _queue: Array = []
var _clock := 0.0


## Queues a reward from a profile event ({kind: "shard" | "level", ...}).
func show_reward(event: Dictionary) -> void:
	match str(event.get("kind", "")):
		"shard": _queue.append({"kind": "shard", "text": "+%d SEELENSPLITTER" % maxi(1, int(event.get("count", 1))), "sub": "Du hast jetzt %d. Verlorene Seelen gehören nun dir." % int(event.get("have", 0)), "time": 3.2})
		"level": _queue.append({"kind": "level", "text": "LEVEL %d" % int(event.get("level", 1)), "sub": "Ein neuer Talentpunkt (%d frei)." % int(event.get("points", 0)), "time": 2.2})


func step(delta: float) -> void:
	_clock += delta
	if not _reward.is_empty():
		_reward.time = float(_reward.time) - delta
		if float(_reward.time) <= 0.0: _reward = {}
	if _reward.is_empty() and not _queue.is_empty(): _reward = _queue.pop_front()


## The skill bar's slots (src/ui/skill_bar.gd entries) from a hero's talent
## state: keys 1-4 with the learned actives (empty until learned), R with the
## ultimate, Shift with the class's defense. The companion's two abilities
## (keys 5 and 6) are not here any more: they sit on the companion bar under
## the hero strip (HudKit.pet_panel, user decision 31.10.2026); the keys and
## the right-click on an icon (auto-cast on / off) keep working.
func skill_slots(talents: Dictionary) -> Array:
	_load_specs()
	var out: Array = []
	var slots: Array = talents.get("slots", [])
	for index in range(int(Profile.data().get("bar_slots", 4))):
		if index < slots.size():
			var slot: Dictionary = slots[index]
			out.append({"key": str(index + 1), "name": str(slot.get("name", "")), "cd": float(slot.get("cd", 0.0)), "max": float(slot.get("cd_max", 1.0)),
				"icon": TalentIcons.make(_specs.get(str(slot.get("spec", "")), {}), str(slot.get("icon", "burst")), true, false),
				"locked": false, "short": not bool(slot.get("ready", false)) and float(slot.get("cd", 0.0)) <= 0.0,
				"text": str(slot.get("text", "")), "meta": _meta(slot)})
		else:
			out.append({"key": str(index + 1), "name": "Frei: lerne ein aktives Talent", "locked": true, "empty": true})
	var ult: Dictionary = talents.get("ult", {})
	if ult.is_empty():
		out.append({"key": "R", "name": "Ultimate: noch nicht freigeschaltet", "locked": true, "empty": true, "ultimate": true})
	else:
		out.append({"key": "R", "name": str(ult.get("name", "")), "cd": float(ult.get("cd", 0.0)), "max": float(ult.get("cd_max", 1.0)), "ultimate": true,
			"icon": TalentIcons.make(_specs.get(str(ult.get("spec", "")), {}), str(ult.get("icon", "burst")), true, true), "locked": false,
			"text": str(ult.get("text", "")), "meta": _meta(ult)})
	# Shift: the class's defense, its charges or hits as pips (user decision 30.10.2026)
	var guard: Dictionary = talents.get("defense", {})
	if not guard.is_empty():
		out.append({"key": "SH", "name": "%s (Shift)" % str(guard.name), "cd": float(guard.get("cd", 0.0)), "max": float(guard.get("cd_max", 1.0)), "defense": true,
			"icon": TalentIcons.make({}, str(guard.get("icon", "shield")), true, false), "locked": false, "pips": [int(guard.left), int(guard.max)],
			"charge": float(guard.get("refill", 0.0)) if int(guard.left) < int(guard.max) and float(guard.get("cd", 0.0)) <= 0.0 else -1.0,
			"active": Color("8fd6ff") if bool(guard.get("up", false)) else Color(0, 0, 0, 0), "text": str(guard.get("text", "")),
			"meta": "Hält %d Treffer" % int(guard.max) if str(guard.type) == "block" else "%d Ladungen" % int(guard.max)})
	return out


## The line under a skill's description: its cost and cooldown.
static func _meta(slot: Dictionary) -> String:
	var parts: Array = []
	if float(slot.get("cost", 0.0)) > 0.0: parts.append("%d %s" % [roundi(float(slot.cost)), str(slot.get("res_name", ""))])
	if float(slot.get("cd_max", 0.0)) > 0.0: parts.append("Abklingzeit %s s" % _number(float(slot.cd_max)))
	return " · ".join(parts)


static func _number(value: float) -> String:
	return str(int(value)) if is_equal_approx(value, roundf(value)) else ("%.1f" % value).replace(".", ",")


## Which companion ability (0 or 1) a right-click means, or -1: the slot at
## `index` of skill_slots() when a bar still carries "pet" entries, otherwise
## the slot under the mouse on the companion bar (HudKit.pet_panel remembers
## its ability slots and the canvas it was drawn on). The HUDs call this with
## the skill bar's hit index; the companion bar is where the icons live now.
static func pet_slot(slots: Array, index: int) -> int:
	if index >= 0 and index < slots.size() and bool(slots[index].get("pet", false)):
		return int(str(slots[index].key)) - 5
	return HudKit.pet_slot_at()


## The resource line above the skill bar, `width` px wide, centred on
## `centre_x`, its top at `y`: mana, Ausdauer or Zorn with the number.
func draw_resource(canvas: CanvasItem, talents: Dictionary, centre_x: float, y: float, width: float = 236.0) -> void:
	if talents.is_empty(): return
	var kind := str(talents.get("res_kind", "mana"))
	var colour: Color = {"mana": Color("5b8ff0"), "stamina": Color("7fcf5a"), "rage": CryptUI.BLOOD}.get(kind, CryptUI.GOLD)
	var bar := Rect2(floorf(centre_x - width * 0.5), y, width, 8)
	canvas.draw_rect(bar, CryptUI.INK)
	canvas.draw_rect(Rect2(bar.position + Vector2(1, 1), Vector2((bar.size.x - 2) * clampf(float(talents.get("res", 0)) / maxf(1.0, float(talents.get("res_max", 100))), 0.0, 1.0), 6)), colour)
	if float(talents.get("shield", 0.0)) > 0.0: canvas.draw_rect(bar.grow(2), Color(CryptUI.FROST, 0.8), false, 2.0)
	var name: String = {"mana": "MANA", "stamina": "AUSDAUER", "rage": "ZORN"}.get(kind, "")
	_centered(canvas, bar.get_center() + Vector2(0, -6), "%s %d / %d" % [name, int(float(talents.get("res", 0))), int(float(talents.get("res_max", 100)))], 8, Color(colour.lightened(0.35)))


func _load_specs() -> void:
	if not _specs.is_empty(): return
	for class_entry: Dictionary in Profile.data().get("classes", {}).values():
		for spec: Dictionary in class_entry.specs: _specs[str(spec.id)] = spec


## The older stand-alone talent bar (kept for tools that draw it on its own):
## centred on `centre_x` with its slots' top at `y`.
func draw_bar(canvas: CanvasItem, talents: Dictionary, centre_x: float, y: float) -> void:
	if talents.is_empty(): return
	_load_specs()
	var slots: Array = talents.get("slots", [])
	var ult: Dictionary = talents.get("ult", {})
	var size_px := 44.0
	var gap := 6.0
	var count := slots.size() + (1 if not ult.is_empty() else 0)
	# no talent slot yet: no bar either (a lone resource bar read as a stray debug line)
	if count == 0: return
	var width := maxf(260.0, count * size_px + maxi(0, count - 1) * gap)
	var x := floorf(centre_x - width * 0.5)
	var kind := str(talents.get("res_kind", "mana"))
	var colour: Color = {"mana": Color("5b8ff0"), "stamina": Color("7fcf5a"), "rage": CryptUI.BLOOD}.get(kind, CryptUI.GOLD)
	var bar := Rect2(x, y - 14, width, 8)
	# framed like the slots: a dark frame, the fill with a lighter top row
	canvas.draw_rect(bar.grow(1), CryptUI.INK)
	canvas.draw_rect(bar, colour.darkened(0.7))
	var fill := (bar.size.x - 2) * clampf(float(talents.get("res", 0)) / maxf(1.0, float(talents.get("res_max", 100))), 0.0, 1.0)
	canvas.draw_rect(Rect2(bar.position + Vector2(1, 1), Vector2(fill, 6)), colour)
	canvas.draw_rect(Rect2(bar.position + Vector2(1, 1), Vector2(fill, 2)), colour.lightened(0.35))
	if float(talents.get("shield", 0.0)) > 0.0: canvas.draw_rect(bar.grow(2), Color(CryptUI.FROST, 0.8), false, 2.0)
	for index in range(count):
		var slot: Dictionary = slots[index] if index < slots.size() else ult
		var rect := Rect2(x + index * (size_px + gap), y, size_px, size_px)
		var ready := bool(slot.get("ready", false))
		CryptUI.draw_box(canvas, "slot_ready" if ready else "slot", rect)
		var is_ult := index >= slots.size()
		var icon := TalentIcons.make(_specs.get(str(slot.get("spec", "")), {}), str(slot.get("icon", "burst")), true, is_ult)
		canvas.draw_texture_rect(icon, rect.grow(-4), false, Color.WHITE if ready else Color(0.55, 0.53, 0.55))
		var cooldown := float(slot.get("cd", 0.0))
		if cooldown > 0.0:
			var share := clampf(cooldown / maxf(0.01, float(slot.get("cd_max", 1.0))), 0.0, 1.0)
			canvas.draw_rect(Rect2(rect.position + Vector2(4, 4), Vector2(size_px - 8, (size_px - 8) * share)), Color(CryptUI.INK, 0.6))
			_centered(canvas, rect.get_center() + Vector2(0, 6), ("%d" % ceili(cooldown)) if cooldown >= 1.0 else ("%.1f" % cooldown), 16, CryptUI.CREAM)
		if is_ult: canvas.draw_rect(rect.grow(2), CryptUI.VOID, false, 2.0)
		var key := Rect2(rect.position + Vector2(-4, -8), Vector2(28 if not is_ult else 18, 16))
		CryptUI.draw_box(canvas, "button", key)
		_centered(canvas, key.get_center() + Vector2(0, 5), "R" if is_ult else "%d" % (index + 1), 8, CryptUI.VOID if is_ult else CryptUI.CREAM)


## Draws the current reward banner centred at `centre` (top third of the screen).
func draw_reward(canvas: CanvasItem, centre: Vector2) -> void:
	if _reward.is_empty(): return
	var t := float(_reward.time)
	var alpha := clampf(t / 0.5, 0.0, 1.0)
	if str(_reward.kind) == "shard":
		var appear := clampf((3.2 - t) / 0.35, 0.0, 1.0)
		canvas.draw_circle(centre, 90.0 * appear, Color(0.55, 0.35, 1.0, 0.18 * alpha))
		TalentScreen.draw_crystal(canvas, centre - Vector2(0, 20), 2.2 * appear, _clock)
		_centered(canvas, centre + Vector2(0, 54), str(_reward.text), 24, Color(CryptUI.CREAM, alpha))
		_centered(canvas, centre + Vector2(0, 78), str(_reward.sub), 16, Color(Color("c9b6ff"), alpha))
	else:
		_centered(canvas, centre + Vector2(0, 30), str(_reward.text), 24, Color(CryptUI.GOLD, alpha))
		_centered(canvas, centre + Vector2(0, 52), str(_reward.sub), 16, Color(CryptUI.CREAM, alpha))


func _centered(canvas: CanvasItem, at: Vector2, text: String, font_size: int, color: Color) -> void:
	var width := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	canvas.draw_string(_font, at - Vector2(width * 0.5, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
