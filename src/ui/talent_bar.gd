extends RefCounted
## The talent slots, the resource line and the reward banner, the same in
## every map: the run HUD of the crypt and the Frostgruft / Hölle HUD draw them
## through this object. There are no standard class skills (user decision
## 29.10.2026): the learned actives sit on keys 1-4 of the skill bar
## (src/ui/skill_bar.gd), the ultimate on R; empty slots wait for talents. The
## companion's abilities (5, 6) are drawn on the companion bar (HudKit.pet_panel).
## Above the bar the resource (mana blue, stamina green, rage red); beside the
## Leerenmagier's mana his Arkanes Gefüge (draw_gefuege). Banner:
## "+2 SEELENSPLITTER" with the crystal, or a level-up note; queued, one at a time.

const CryptUI = preload("res://src/ui/crypt_ui.gd")
const HudStyle = preload("res://src/ui/hud_style.gd")
const PixelStyle = preload("res://src/pixel_style.gd")
const TalentIcons = preload("res://src/ui/talent_icons.gd")
const TalentScreen = preload("res://src/ui/talent_screen.gd")
const HudKit = preload("res://src/ui/hud_kit.gd")
const Profile = preload("res://src/progress/profile.gd")
const Pal = preload("res://src/vfx/talent_palette.gd")
const PixelPaint = preload("res://src/vfx/pixel_paint.gd")
## The Gefüge gauge's look: assets/data/ui_hud_style.json "gefuege".
const STYLE_PATH := "res://assets/data/ui_hud_style.json"
## What the gauge falls back to when the style table lacks a key.
const GAUGE_DEFAULTS := {"radius": 17, "cell": 2, "gap": 6, "lift": -4, "glow": 0.4, "pulse_time": 0.35, "burst_time": 0.6,
	"burst_speed": 60, "orbit_speed": 1.4, "squash": 0.82, "core": 2, "tone": {}}
## The void's black heart (the orb's inside).
const VOID_BLACK := Color("0a0612")
const SkillBar = preload("res://src/ui/skill_bar.gd")

var _font: Font = PixelStyle.create_font()
var _specs: Dictionary = {}
var _reward: Dictionary = {}
var _queue: Array = []
var _clock := 0.0
## The Gefüge gauge's style (ui_hud_style.json "gefuege" over GAUGE_DEFAULTS), read once.
static var _gauge_style: Dictionary = {}
## The unit colours the gauge held when last drawn, oldest first (more pulse, none bursts).
var _gef_units: Array = []
## When units last entered (the swallow pulse), _clock s.
var _gef_pulse := -10.0
## The pixels flung out when the pocket emptied: [{col, a, v}] and when (_clock s).
var _gef_burst: Array = []
var _gef_burst_t := -10.0
## The quick potions' icons by sprite path (potion_slot), loaded once.
static var _potion_icons: Dictionary = {}


## Queues a reward from a profile event ({kind: "shard" | "level", ...}).
func show_reward(event: Dictionary) -> void:
	match str(event.get("kind", "")):
		"shard": _queue.append({"kind": "shard", "text": "+%d SEELENSPLITTER" % maxi(1, int(event.get("count", 1))), "sub": "Du hast jetzt %d. Verlorene Seelen gehören nun dir." % int(event.get("have", 0)), "time": 3.2})
		"level": _queue.append({"kind": "level", "text": "HELDENSTUFE %d" % int(event.get("level", 1)), "sub": "Neuer Talentpunkt (%d frei) · K öffnet die Talente" % int(event.get("points", 0)), "time": 3.2})


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
	# every HUD frame: the shared, kept talent data, not a fresh parse of talents.json (F3)
	for index in range(int(Profile.data_view().get("bar_slots", 4))):
		if index < slots.size():
			var slot: Dictionary = slots[index]
			out.append({"key": str(index + 1), "name": str(slot.get("name", "")), "cd": float(slot.get("cd", 0.0)), "max": float(slot.get("cd_max", 1.0)),
				"icon": TalentIcons.make(_specs.get(str(slot.get("spec", "")), {}), str(slot.get("icon", "burst")), true, false),
				"locked": false, "short": not bool(slot.get("ready", false)) and float(slot.get("cd", 0.0)) <= 0.0,
				"text": str(slot.get("text", "")), "meta": _meta(slot)})
			if int(slot.get("charges_max",0))>0:
				out[-1].pips=[int(slot.charges_left),int(slot.charges_max)]
				out[-1].charge=1-float(slot.get("charge_next",0))/maxf(0.1,float(slot.cd_max)) if int(slot.charges_left)<int(slot.charges_max) else -1.0
		else:
			out.append({"key": str(index + 1), "name": "Frei: lerne ein aktives Talent", "locked": true, "empty": true, "lock": true})
	var ult: Dictionary = talents.get("ult", {})
	if ult.is_empty():
		out.append({"key": "R", "name": "Ultimate: noch nicht freigeschaltet", "locked": true, "empty": true, "lock": true, "ultimate": true})
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
			# the slot shows the Shift arrow; the card says the key in words
			"meta": "Taste Shift · " + ("Hält %d Treffer" % int(guard.max) if str(guard.type) == "block" else "%d Ladungen" % int(guard.max))})
	# F: the worn armour's ability (src/hero/armor_powers.gd slot_view), right of SH
	if talents.has("power") and not (talents.power as Dictionary).is_empty():
		out.append(power_slot(talents.power))
	return out


## The skill bar's F slot for a worn power armour (`power`: armor_powers.gd
## slot_view: name, text, cd, max, cooldown, icon motif, colour, running,
## armor): icon, cooldown shade, the hover card with name, text and cooldown,
## a glow in the power's colour while it runs.
static func power_slot(power: Dictionary) -> Dictionary:
	var colour := Color(str(power.get("color", "ffffff")))
	var meta := "Abklingzeit %s s" % _number(float(power.get("cooldown", power.get("max", 0.0))))
	if not str(power.get("armor", "")).is_empty(): meta += " · " + str(power.armor)
	return {"key": "F", "name": "%s (F)" % str(power.get("name", "")), "cd": float(power.get("cd", 0.0)), "max": maxf(0.01, float(power.get("max", 1.0))),
		"icon": TalentIcons.make({}, str(power.get("icon", "shield")), true, false), "locked": false, "power": true,
		"active": colour if bool(power.get("running", false)) else Color(0, 0, 0, 0), "text": str(power.get("text", "")), "meta": meta}


## The skill bar's quick-potion slot (keys H and G, R4 of
## production/qa/evidence/gameplay-review/BEWERTUNG.md). `potion`: the
## inventory.gd view of the stack (empty without a potion); `since`: seconds
## since it was last used. The icon in the potion's own colour, the count in the
## lower right corner (never over the icon), "H/G" as its key, a hover card with its
## name (or UNBEKANNTER TRANK) and the keys, a short glow after use
## (ui_hud_style.json rules.quick_potion_flash). Its own group right of the skills.
## Empty, it shows a dim flask ("hint": "potion", skill_bar.gd) and its hover card
## says how a potion gets there (story_items.gd quick_slot, set_quick) and what H and G do.
static func potion_slot(potion: Dictionary, since: float) -> Dictionary:
	var keys := "H trinken · G werfen"
	if potion.is_empty():
		return {"key": "H/G", "name": "SCHNELLTRANK", "text": "Leer. Ein gefundener Trank kommt von selbst hierher, ein Heiltrank zuerst. Im Inventar (I) legt ein Rechtsklick einen anderen Trank hierher.",
			"meta": keys, "locked": true, "empty": true, "gap_before": true, "hint": "potion"}
	var count := int(potion.get("count", 1))
	var path := str(potion.get("sprite", ""))
	if not _potion_icons.has(path): _potion_icons[path] = load(path) if ResourceLoader.exists(path) else null
	var flash := since >= 0.0 and since < HudKit.rule("quick_potion_flash", 0.35)
	return {"key": "H/G", "name": str(potion.get("name", "TRANK")) if bool(potion.get("identified", false)) else "UNBEKANNTER TRANK",
		"icon": _potion_icons[path], "count": str(count), "locked": false, "gap_before": true, "text": keys,
		"meta": "%d im Inventar" % count, "active": HudStyle.color("accent") if flash else Color(0, 0, 0, 0)}


## The line under a skill's description: its cost and cooldown.
static func _meta(slot: Dictionary) -> String:
	var parts: Array = []
	if float(slot.get("cost", 0.0)) > 0.0: parts.append("%d %s" % [roundi(float(slot.cost)), str(slot.get("res_name", ""))])
	if float(slot.get("cd_max", 0.0)) > 0.0: parts.append("Abklingzeit %s s" % _number(float(slot.cd_max)))
	if int(slot.get("charges_max",0))>0: parts.append("%d/%d Ladungen"%[int(slot.charges_left),int(slot.charges_max)])
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
func draw_resource(canvas: CanvasItem, talents: Dictionary, centre_x: float, y: float, width: float = 236.0, mouse: Vector2 = Vector2.INF, screen: Vector2 = Vector2(1280, 720)) -> void:
	if talents.is_empty(): return
	var kind := str(talents.get("res_kind", "mana"))
	var colour: Color = {"mana": Color("5b8ff0"), "souls": Color("72d7d0"), "stamina": Color("7fcf5a"), "rage": CryptUI.BLOOD}.get(kind, CryptUI.GOLD)
	var bar := Rect2(floorf(centre_x - width * 0.5), y, width, 8)
	var share := clampf(float(talents.get("res", 0)) / maxf(1.0, float(talents.get("res_max", 100))), 0.0, 1.0)
	canvas.draw_rect(bar, CryptUI.INK)
	canvas.draw_rect(Rect2(bar.position + Vector2(1, 1), Vector2((bar.size.x - 2) * share, 6)), colour)
	if float(talents.get("shield", 0.0)) > 0.0: canvas.draw_rect(bar.grow(2), Color(CryptUI.FROST, 0.8), false, 2.0)
	var name: String = {"mana": "MANA", "souls": "SEELEN", "stamina": "AUSDAUER", "rage": "ZORN"}.get(kind, "")
	# the name left of the bar; the numbers over it only under the mouse or when
	# the resource runs low (ui_hud_style.json "rules")
	var label_px := int(HudKit.rule("resource_label_size", 16.0))
	var tint := Color(colour.lightened(0.35))
	var name_w := HudStyle.width(_font, name, label_px)
	HudStyle.text(canvas, _font, Vector2(bar.position.x - 8.0, bar.get_center().y + 6.0), name, label_px, tint, 2)
	var near := Rect2(bar.position - Vector2(name_w + 12.0, 16.0), bar.size + Vector2(name_w + 12.0, 24.0)).has_point(canvas.get_local_mouse_position())
	# rage starts empty and builds up: its numbers only under the mouse
	if kind == "souls" or near or (kind != "rage" and share < HudKit.rule("resource_low_share", 0.25)):
		HudStyle.text(canvas, _font, Vector2(bar.get_center().x, bar.position.y - 4.0), "%d / %d" % [int(float(talents.get("res", 0))), int(float(talents.get("res_max", 100)))], label_px, tint, 1)
	if kind == "souls":
		HudStyle.text(canvas, _font, Vector2(bar.end.x + 8.0, bar.get_center().y + 4.0), str(talents.get("resource_passive_name", "Seelensog")).to_upper(), 8, tint)
		if bar.grow(8).has_point(mouse):
			SkillBar._card(canvas, _font, Vector2(bar.get_center().x, bar.position.y - 18), {"name": str(talents.get("resource_passive_name", "Seelensog")), "text": str(talents.get("resource_passive", ""))}, screen)
	# the Leerenmagier's Arkanes Gefüge right of his mana (only a snapshot that carries one)
	var gefuege: Variant = talents.get("gefuege", null)
	if gefuege is Dictionary and not gefuege.is_empty():
		var style := gauge_style()
		var radius := float(style.radius)
		draw_gefuege(canvas, gefuege, Vector2(bar.end.x + float(style.gap) + radius, bar.position.y + float(style.lift)))
	else:
		_gef_units = []


# ---------- the Arkanes Gefüge ----------

## The Gefüge gauge's style: ui_hud_style.json "gefuege" over GAUGE_DEFAULTS.
static func gauge_style() -> Dictionary:
	if _gauge_style.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(STYLE_PATH)) if FileAccess.file_exists(STYLE_PATH) else null
		var table: Variant = parsed.get("gefuege", {}) if parsed is Dictionary else {}
		_gauge_style = GAUGE_DEFAULTS.duplicate(true)
		if table is Dictionary: _gauge_style.merge(table, true)
	return _gauge_style


## The colour of one swallowed unit of `element`: its ramp's lite colour
## (src/vfx/talent_palette.gd), or the ramp step the style's "tone" names for
## it (lava, water and ice would read like fire and each other otherwise).
static func unit_colour(element: String) -> Color:
	var tones: Dictionary = gauge_style().get("tone", {})
	var ramp: Array = Pal.ramp(element)
	return ramp[clampi(int(tones.get(element, 3)), 0, ramp.size() - 1)]


## The units of a Gefüge snapshot ({cap, units: [{el, n}]}) as one colour per
## unit, oldest first, at most `cap` of them.
static func unit_colours(units: Variant, cap: int) -> Array:
	var out: Array = []
	if not units is Array: return out
	for group: Variant in units:
		if not group is Dictionary: continue
		var colour := unit_colour(str(group.get("el", "void")))
		for i in range(maxi(0, int(group.get("n", 0)))):
			if out.size() >= cap: return out
			out.append(colour)
	return out


## The Arkanes Gefüge, the Leerenmagier's pocket of swallowed elements, as a
## small dark orb centred on `centre` (screen px): an ink rim with a faint
## violet glow outside it (dithered), a black inside, a fill arc of n / cap
## running clockwise from the top just inside the rim, and one coloured pixel
## (style cell, 2x2 screen px) per unit swirling round a tiny core on its own
## orbit, the oldest nearest the core, inner orbits faster. When units enter
## the orb pulses (rim and glow brighten, the newest unit falls in from the
## rim); when it empties its last units burst outward and the glow flares.
## `gefuege` is talents.player_state(id).gefuege; every read has a default.
func draw_gefuege(canvas: CanvasItem, gefuege: Dictionary, centre: Vector2) -> void:
	var style := gauge_style()
	var cap := maxi(1, int(gefuege.get("cap", 1)))
	var units := unit_colours(gefuege.get("units", []), cap)
	if units.size() > _gef_units.size(): _gef_pulse = _clock
	elif units.is_empty() and not _gef_units.is_empty(): _burst_gefuege(_gef_units)
	_gef_units = units
	var cell := maxf(1.0, float(style.cell))
	var r := float(style.radius)
	var c := (centre / cell).floor() * cell
	var cols := Pal.ramp("void")
	var pulse := 1.0 - clampf((_clock - _gef_pulse) / maxf(0.05, float(style.pulse_time)), 0.0, 1.0)
	var burst := 1.0 - clampf((_clock - _gef_burst_t) / maxf(0.05, float(style.burst_time)), 0.0, 1.0)
	var flare := maxf(pulse, burst)
	var n := int(ceil((r + cell * 3.0) / cell))
	var cq := Vector2i((c / cell).round())
	var share := float(units.size()) / float(cap)
	var lead := -1
	if units.size() > 0: lead = clampi(int(share * 64.0) - 1, 0, 63)
	for gy in range(-n, n + 1):
		for gx in range(-n, n + 1):
			var rel := (Vector2(gx, gy) + Vector2(0.5, 0.5)) * cell
			var d := rel.length()
			var q := cq + Vector2i(gx, gy)
			var colour := Color(0, 0, 0, 0)
			if d > r + cell * 2.5:
				continue
			elif d > r:
				# the faint violet glow outside the rim, thinning outwards by the dither
				var cover := (float(style.glow) + 0.5 * flare) * (1.0 - (d - r) / (cell * 2.5))
				if PixelPaint.shown(q, cover): colour = cols[2] if d < r + cell else cols[1]
			elif d > r - cell:
				colour = CryptUI.INK if flare < 0.5 or d > r - cell * 0.5 else cols[1]
			elif d > r - cell * 2.0:
				# the fill arc: n / cap clockwise from the top, its leading cell lit
				var turn := fposmod(rel.angle() + PI * 0.5, TAU) / TAU
				var step := int(turn * 64.0)
				if turn < share: colour = cols[4] if step == lead else cols[3]
				else: colour = cols[0]
			elif d > r - cell * 3.0:
				# the inside's rim: deep violet, lit on a pulse
				colour = cols[1] if PixelPaint.shown(q, 0.5 + 0.5 * flare) else VOID_BLACK
			else:
				colour = VOID_BLACK
			if colour.a > 0.0: canvas.draw_rect(Rect2(Vector2(q) * cell, Vector2(cell, cell)), colour)
	# the tiny core: a dark heart with one violet glint crawling round it
	var core := float(style.core)
	var frame := int(floorf(_clock * PixelPaint.FPS))
	for i in range(8):
		var a := TAU * float(i) / 8.0
		var q := cq + Vector2i((Vector2(cos(a), sin(a)) * core).round())
		canvas.draw_rect(Rect2(Vector2(q) * cell, Vector2(cell, cell)), cols[4] if posmod(i - frame, 8) == 0 else cols[1])
	# the units: one pixel each on its orbit, the oldest nearest the core
	var count := units.size()
	var r_min := cell * (core + 1.5)
	var r_max := r - cell * 3.5
	var speed := float(style.orbit_speed)
	var squash := float(style.squash)
	for i in range(count):
		var f := float(i) / float(maxi(1, count - 1)) if count > 1 else 0.0
		var rad := lerpf(r_min, r_max, f)
		if i == count - 1 and pulse > 0.0: rad = lerpf(rad, r - cell * 2.0, pulse)
		var a := float(i) * 2.39996 + _clock * speed * sqrt(r_max / maxf(1.0, rad))
		var spot := c + Vector2(cos(a), sin(a) * squash) * rad
		var q := Vector2i((spot / cell).floor())
		var back := Vector2i(((c + Vector2(cos(a - 0.45), sin(a - 0.45) * squash) * rad) / cell).floor())
		var colour: Color = units[i]
		if back != q: canvas.draw_rect(Rect2(Vector2(back) * cell, Vector2(cell, cell)), colour.darkened(0.55))
		canvas.draw_rect(Rect2(Vector2(q) * cell, Vector2(cell, cell)), colour)
	# the burst when it emptied: the last units flung outward, thinning by the dither
	if burst > 0.0:
		var t := 1.0 - burst
		for piece: Dictionary in _gef_burst:
			var spot := c + Vector2.from_angle(float(piece.a)) * (r * 0.4 + float(piece.v) * t)
			var q := Vector2i((spot / cell).floor())
			if not PixelPaint.shown(q, burst + 0.2): continue
			canvas.draw_rect(Rect2(Vector2(q) * cell, Vector2(cell, cell)), piece.col)
			var tail := Vector2i(((spot - Vector2.from_angle(float(piece.a)) * cell * 1.5) / cell).floor())
			if tail != q: canvas.draw_rect(Rect2(Vector2(tail) * cell, Vector2(cell, cell)), (piece.col as Color).darkened(0.5))


## The units' pixels when the pocket empties: each flung out at its own angle and speed.
func _burst_gefuege(units: Array) -> void:
	var style := gauge_style()
	_gef_burst = []
	_gef_burst_t = _clock
	for i in range(units.size()):
		var spread := 0.6 + 0.4 * float((i * 7919) % 101) / 100.0
		_gef_burst.append({"col": units[i], "a": float(i) * 2.39996 + _clock, "v": float(style.burst_speed) * spread})


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
	var colour: Color = {"mana": Color("5b8ff0"), "souls": Color("72d7d0"), "stamina": Color("7fcf5a"), "rage": CryptUI.BLOOD}.get(kind, CryptUI.GOLD)
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
