extends RefCounted
## The talent bar and the reward banner, the same in every map: the run HUD of
## the crypt and the Frostgruft / Hölle HUD draw them through this object.
## Bar: resource (mana blue, stamina green, rage red), Shift + 1-4 slots with
## cooldown sweep, the ultimate on R. Banner: "SEELENSPLITTER ERHALTEN!" with
## the crystal, or a level-up note; queued, one at a time.

const CryptUI = preload("res://src/ui/crypt_ui.gd")
const PixelStyle = preload("res://src/pixel_style.gd")
const TalentIcons = preload("res://src/ui/talent_icons.gd")
const TalentScreen = preload("res://src/ui/talent_screen.gd")
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


## Draws the bar centred on `centre_x` with its slots' top at `y`.
func draw_bar(canvas: CanvasItem, talents: Dictionary, centre_x: float, y: float) -> void:
	if talents.is_empty(): return
	if _specs.is_empty():
		for class_entry: Dictionary in Profile.data().get("classes", {}).values():
			for spec: Dictionary in class_entry.specs: _specs[str(spec.id)] = spec
	var slots: Array = talents.get("slots", [])
	var ult: Dictionary = talents.get("ult", {})
	var size_px := 44.0
	var gap := 6.0
	var count := slots.size() + (1 if not ult.is_empty() else 0)
	var width := maxf(260.0, count * size_px + maxi(0, count - 1) * gap)
	var x := floorf(centre_x - width * 0.5)
	var kind := str(talents.get("res_kind", "mana"))
	var colour: Color = {"mana": Color("5b8ff0"), "stamina": Color("7fcf5a"), "rage": CryptUI.BLOOD}.get(kind, CryptUI.GOLD)
	var bar := Rect2(x, y - 14, width, 8)
	canvas.draw_rect(bar, CryptUI.INK)
	canvas.draw_rect(Rect2(bar.position + Vector2(1, 1), Vector2((bar.size.x - 2) * clampf(float(talents.get("res", 0)) / maxf(1.0, float(talents.get("res_max", 100))), 0.0, 1.0), 6)), colour)
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
		_centered(canvas, key.get_center() + Vector2(0, 5), "R" if is_ult else "S%d" % (index + 1), 8, CryptUI.VOID if is_ult else CryptUI.CREAM)


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
