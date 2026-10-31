extends RefCounted
## Hero skins by element (assets/data/hero_skins.json). The mage is the 0x72
## wizard; so that the same figure tells his element at a glance, his blues
## (hat and robe) are mapped onto the ramp of his element: unchanged without a
## specialisation (his blue is the neutral mage), reds for fire (the old
## pyromancer look as colours only), pale ice blue for frost, violet for
## arcane (the void). The ink outline, beard and skin keep their colours.
##
## The element is the hero's main specialisation: the spec with the most spent
## talent points in his class (talents.json classes.<class>.specs); a tie or no
## points is the neutral mage. Textures are recoloured once per source texture
## and element and cached, so the rig renderer (src/rig/rig_renderer.gd
## draw_hero), the story worlds and the main menu share the work. Static and
## data-driven; no node, no singleton.

const Profile = preload("res://src/progress/profile.gd")
const DATA_PATH := "res://assets/data/hero_skins.json"

static var _data: Dictionary = {}
static var _talents: Dictionary = {}
## "<source texture rid>:<class>:<element>" -> recoloured ImageTexture.
static var _cache: Dictionary = {}


## The skin data (hero_skins.json), read once.
static func data() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH)) if FileAccess.file_exists(DATA_PATH) else null
		_data = parsed if parsed is Dictionary else {"skins": {}, "familiar": {}, "spec_elements": {}}
	return _data


## The skin entry of a hero class, or {} for classes without one.
static func skin(class_id: String) -> Dictionary:
	return data().get("skins", {}).get(class_id, {})


## The 0x72 sprite name the class skin recolours (e.g. "wizzard_m"), or "".
static func source(class_id: String) -> String:
	return str(skin(class_id).get("source", ""))


## The class whose skin colours the part rig `rig_name` (hero_skins.json skins.<class>.rig), or "".
static func class_for_rig(rig_name: String) -> String:
	for class_id: String in data().get("skins", {}):
		if str(data().skins[class_id].get("rig", "")) == rig_name: return class_id
	return ""


## The talent data (talents.json), read once for the spec sums.
static func talents() -> Dictionary:
	if _talents.is_empty(): _talents = Profile.data()
	return _talents


## The hero's main specialisation in `profile` (src/progress/profile.gd shape):
## the spec id with the most spent points in `class_id`'s ranks; "" when no
## points are spent or the lead is shared. `talent_data` overrides talents.json.
static func main_spec(profile: Dictionary, class_id: String, talent_data: Dictionary = {}) -> String:
	if profile.is_empty(): return ""
	var d := talent_data if not talent_data.is_empty() else talents()
	var infos: Dictionary = d.get("talents", {})
	var ranks: Dictionary = profile.get("classes", {}).get(class_id, {}).get("ranks", {})
	var points: Dictionary = {}
	for talent: Variant in ranks:
		var spec := str(infos.get(str(talent), {}).get("spec", ""))
		if spec.is_empty(): continue
		points[spec] = int(points.get(spec, 0)) + int(ranks[talent])
	return _leader(points)


## The element of a spec id ("fire", "ice", "void"; "" for none or unknown), hero_skins.json spec_elements.
static func element_of(spec: String) -> String:
	return str(data().get("spec_elements", {}).get(spec, ""))


## The element the hero of `class_id` plays by his profile (see main_spec).
static func element(profile: Dictionary, class_id: String) -> String:
	return element_of(main_spec(profile, class_id))


## The element read from a crypt snapshot's player talents (src/combat/talent_combat.gd
## player_state): the snapshot carries no ranks, so the ultimate's spec counts, else the
## spec most of the bar's talents belong to; "" when neither tells.
static func element_from_talents(talents_state: Dictionary) -> String:
	var spec := str(talents_state.get("ult", {}).get("spec", ""))
	if spec.is_empty():
		var counts: Dictionary = {}
		for slot: Variant in talents_state.get("slots", []):
			var s := str((slot as Dictionary).get("spec", "")) if slot is Dictionary else ""
			if not s.is_empty(): counts[s] = int(counts.get(s, 0)) + 1
		spec = _leader(counts)
	return element_of(spec)


## The element of a drawn hero: its "element" field when the host set one (the
## story worlds, from the profile), else from its snapshot talents (the crypt).
static func element_for_player(player: Dictionary) -> String:
	if player.has("element"): return str(player.element)
	return element_from_talents(player.get("talents", {}))


## The ramp of an element (dark to light) for `class_id`, as Colors; [] without one.
static func ramp(element_id: String, class_id: String = "mage") -> Array[Color]:
	var out: Array[Color] = []
	for hex: Variant in skin(class_id).get("elements", {}).get(element_id, {}).get("ramp", []): out.append(Color(str(hex)))
	return out


## The element's spec colour (its brightest accent, the familiar's core); white without one.
static func spec_color(element_id: String, class_id: String = "mage") -> Color:
	var entry: Dictionary = skin(class_id).get("elements", {}).get(element_id, {})
	return Color(str(entry.spec)) if entry.has("spec") else Color.WHITE


## `tex` in the colours of `element_id` for the skin of `class_id`: the mapped
## pixels on the element's ramp, the kept colours as they are. The source
## itself for "unchanged" elements (the neutral mage), unknown elements or
## classes without a skin. Cached by source texture and element.
static func texture(tex: Texture2D, element_id: String, class_id: String = "mage") -> Texture2D:
	if tex == null: return null
	var s := skin(class_id)
	var entry: Dictionary = s.get("elements", {}).get(element_id, {})
	if s.is_empty() or entry.is_empty() or bool(entry.get("unchanged", false)): return tex
	var key := "%d:%s:%s" % [tex.get_rid().get_id(), class_id, element_id]
	if _cache.has(key): return _cache[key]
	var image := tex.get_image()
	if image == null: return tex
	image = image.duplicate()
	if image.is_compressed(): image.decompress()
	image.convert(Image.FORMAT_RGBA8)
	recolor(image, s, entry)
	var out := ImageTexture.create_from_image(image)
	_cache[key] = out
	return out


## Recolours `image` in place. A pixel listed in the skin's "map" takes the ramp
## colour at its mapped position; any other pixel in the skin's hue "band" with
## enough saturation (and not in "keep") takes the ramp colour at its HSL
## lightness within the skin's lightness span. "snap" picks the nearest ramp
## step instead of blending between steps. Alpha stays.
static func recolor(image: Image, s: Dictionary, entry: Dictionary) -> void:
	var keep: Dictionary = {}
	for hex: Variant in s.get("keep", []): keep[str(hex).to_lower()] = true
	var mapped_t: Dictionary = {}
	for hex: Variant in s.get("map", {}): mapped_t[str(hex).to_lower()] = float(s.map[hex])
	var band: Dictionary = s.get("band", s.get("warm", {}))
	var hue_from := float(band.get("hue_from", 190)) / 360.0
	var hue_to := float(band.get("hue_to", 260)) / 360.0
	var sat_min := float(band.get("saturation_min", 0.25))
	var span: Array = s.get("lightness", [0.4, 0.7])
	var lo := float(span[0])
	var hi := maxf(lo + 0.001, float(span[1]))
	var steps: Array[Color] = []
	for hex: Variant in entry.get("ramp", []): steps.append(Color(str(hex)))
	if steps.is_empty(): return
	var snap := bool(s.get("snap", false))
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var c := image.get_pixel(x, y)
			if c.a <= 0.0: continue
			var html := c.to_html(false).to_lower()
			if keep.has(html): continue
			var t: float
			if mapped_t.has(html):
				t = float(mapped_t[html])
			elif c.s >= sat_min and _hue_in(c.h, hue_from, hue_to):
				var light := (maxf(c.r, maxf(c.g, c.b)) + minf(c.r, minf(c.g, c.b))) * 0.5
				t = (light - lo) / (hi - lo)
			else:
				continue
			var mapped := ramp_at(steps, clampf(t, 0.0, 1.0), snap)
			mapped.a = c.a
			image.set_pixel(x, y, mapped)


## The ramp colour at `t` (0 = darkest, 1 = lightest): the nearest step when
## `snap`, else blended between the two steps round `t`.
static func ramp_at(steps: Array[Color], t: float, snap: bool = false) -> Color:
	if steps.is_empty(): return Color.WHITE
	var p := clampf(t, 0.0, 1.0) * float(steps.size() - 1)
	if snap: return steps[clampi(roundi(p), 0, steps.size() - 1)]
	var i := clampi(floori(p), 0, steps.size() - 1)
	var j := mini(i + 1, steps.size() - 1)
	return steps[i].lerp(steps[j], p - float(i))


## True when hue `h` (0..1) lies in the band from `a` to `b`, which may wrap past red.
static func _hue_in(h: float, a: float, b: float) -> bool:
	if a <= b: return h >= a and h <= b
	return h >= a or h <= b


## The spec with strictly the most points; "" when none has any or the lead is shared.
static func _leader(points: Dictionary) -> String:
	var best := ""
	var best_n := 0
	var tied := false
	for spec: Variant in points:
		var n := int(points[spec])
		if n > best_n:
			best = str(spec)
			best_n = n
			tied = false
		elif n == best_n and n > 0:
			tied = true
	return "" if tied else best
