@tool
extends RefCounted
## Pixel Operator 8 draws the capital umlauts Ä Ö Ü as a shortened letter with
## the dots inside the 7 px cap height, so they look like ä ö ü ("RüSTUNG").
## This patches the font bytes in memory: each capital umlaut becomes the full
## capital (A, O, U) plus two dots one pixel above the cap height. Advances and
## line metrics stay untouched; the glyphs reach 2 font pixels above the ascent.
## Pure byte work on the TrueType tables (glyf, loca, maxp, head); the asset on
## disk stays the unchanged original (see assets/fonts/PROVENANCE.md).

## Capital umlaut -> the capital whose full outline it reuses.
const CAPS := {"Ä": "A", "Ö": "O", "Ü": "U"}
## Font pixels per em of the 8 px design.
const DESIGN_PX := 8


## Returns `data` (a TrueType font) with tall capital umlauts, or `data`
## unchanged when the font is not a plain TrueType font with simple glyphs.
## `glyph_of` maps a character code to its glyph index (FontFile.get_glyph_index).
static func patch(data: PackedByteArray, glyph_of: Callable) -> PackedByteArray:
	var tables := _tables(data)
	if not (tables.has("glyf") and tables.has("loca") and tables.has("head") and tables.has("maxp")):
		return data
	var head: PackedByteArray = tables.head
	var long_loca := _s16(head, 50) == 1
	var upem := _u16(head, 18)
	var px := upem / DESIGN_PX
	var glyf: PackedByteArray = tables.glyf
	var loca: PackedByteArray = tables.loca
	var count := loca.size() / (4 if long_loca else 2) - 1
	var glyphs: Array[PackedByteArray] = []
	for i in count:
		var a := _u32(loca, i * 4) if long_loca else _u16(loca, i * 2) * 2
		var b := _u32(loca, i * 4 + 4) if long_loca else _u16(loca, i * 2 + 2) * 2
		glyphs.append(glyf.slice(a, b))
	var max_points := _u16(tables.maxp, 6)
	var max_contours := _u16(tables.maxp, 8)
	var changed := false
	for cap: String in CAPS:
		var target: int = glyph_of.call(cap.unicode_at(0))
		var base: int = glyph_of.call(str(CAPS[cap]).unicode_at(0))
		if target <= 0 or base <= 0 or target >= count or base >= count:
			continue
		var outline := _read_simple(glyphs[base])
		if outline.is_empty():
			continue
		# The small letter (ö, ü) is an alias of the capital in this face: it
		# takes over the capital's old composite so it keeps its own look.
		var aliases: Array[int] = []
		var safe := true
		for i in count:
			var parts := _components(glyphs[i])
			if parts.has(target):
				aliases.append(i)
				safe = safe and parts.size() == 1 and _plain_alias(glyphs[i])
		if not safe:
			continue
		for alias: int in aliases:
			glyphs[alias] = glyphs[target].duplicate()
		var top: int = outline.y_max + px
		var mid: int = (outline.x_min + outline.x_max) / 2
		for left: int in [mid - px * 3 / 2, mid + px / 2]:
			_add_square(outline, left, top, px)
		glyphs[target] = _write_simple(outline)
		max_points = maxi(max_points, (outline.xs as PackedInt32Array).size())
		max_contours = maxi(max_contours, (outline.ends as PackedInt32Array).size())
		changed = true
	if not changed:
		return data
	var new_glyf := PackedByteArray()
	var offsets: Array[int] = []
	for g: PackedByteArray in glyphs:
		offsets.append(new_glyf.size())
		new_glyf.append_array(g)
		while new_glyf.size() % 4 != 0:
			new_glyf.append(0)
	offsets.append(new_glyf.size())
	var new_loca := PackedByteArray()
	for offset: int in offsets:
		if long_loca: _put32(new_loca, offset)
		else: _put16(new_loca, offset / 2)
	var maxp: PackedByteArray = (tables.maxp as PackedByteArray).duplicate()
	_set16(maxp, 6, max_points)
	_set16(maxp, 8, max_contours)
	tables.glyf = new_glyf
	tables.loca = new_loca
	tables.maxp = maxp
	return _assemble(data, tables)


# Table tag -> its bytes, in the order of the table directory.
static func _tables(data: PackedByteArray) -> Dictionary:
	var tables := {}
	if data.size() < 12:
		return tables
	var version := _u32(data, 0)
	if version != 0x00010000 and version != 0x74727565:
		return tables
	for i in _u16(data, 4):
		var record := 12 + i * 16
		var tag := data.slice(record, record + 4).get_string_from_ascii()
		var offset := _u32(data, record + 8)
		tables[tag] = data.slice(offset, offset + _u32(data, record + 12))
	return tables


# Points of a simple glyph: contour ends, on-curve flags, absolute x / y, bbox.
static func _read_simple(g: PackedByteArray) -> Dictionary:
	if g.size() < 10 or _s16(g, 0) <= 0:
		return {}
	var contours := _s16(g, 0)
	var ends := PackedInt32Array()
	var p := 10
	for i in contours:
		ends.append(_u16(g, p))
		p += 2
	p += 2 + _u16(g, p)
	var total: int = ends[ends.size() - 1] + 1
	var flags := PackedInt32Array()
	while flags.size() < total:
		var flag := g[p]
		p += 1
		flags.append(flag)
		if flag & 8:
			var repeat := g[p]
			p += 1
			for r in repeat:
				flags.append(flag)
	var xs := PackedInt32Array()
	var ys := PackedInt32Array()
	var at := 0
	for flag in flags:
		if flag & 2:
			at += g[p] if flag & 16 else -g[p]
			p += 1
		elif flag & 16 == 0:
			at += _s16(g, p)
			p += 2
		xs.append(at)
	at = 0
	for flag in flags:
		if flag & 4:
			at += g[p] if flag & 32 else -g[p]
			p += 1
		elif flag & 32 == 0:
			at += _s16(g, p)
			p += 2
		ys.append(at)
	var on := PackedInt32Array()
	for flag in flags:
		on.append(flag & 1)
	return {"ends": ends, "on": on, "xs": xs, "ys": ys, "x_min": _s16(g, 2), "y_min": _s16(g, 4), "x_max": _s16(g, 6), "y_max": _s16(g, 8)}


# Glyph indices a composite glyph is built from; [] for a simple or empty glyph.
static func _components(g: PackedByteArray) -> Array[int]:
	var parts: Array[int] = []
	if g.size() < 10 or _s16(g, 0) >= 0:
		return parts
	var p := 10
	while p + 4 <= g.size():
		var flags := _u16(g, p)
		parts.append(_u16(g, p + 2))
		p += 4 + (4 if flags & 1 else 2)
		if flags & 8: p += 2
		elif flags & 0x40: p += 4
		elif flags & 0x80: p += 8
		if flags & 0x20 == 0:
			break
	return parts


# True for a composite of one component placed unscaled at offset 0.
static func _plain_alias(g: PackedByteArray) -> bool:
	if g.size() < 16:
		return false
	var flags := _u16(g, 10)
	var words := flags & 1 != 0
	var dx := _s16(g, 14) if words else g[14]
	var dy := (_s16(g, 16) if g.size() >= 18 else 1) if words else g[15]
	return flags & 2 != 0 and flags & (8 | 0x40 | 0x80) == 0 and dx == 0 and dy == 0


# Appends a clockwise square contour (one font pixel) with its lower left at (x, y).
static func _add_square(outline: Dictionary, x: int, y: int, size: int) -> void:
	var xs: PackedInt32Array = outline.xs
	var ys: PackedInt32Array = outline.ys
	var on: PackedInt32Array = outline.on
	var ends: PackedInt32Array = outline.ends
	for corner: Vector2i in [Vector2i(x, y), Vector2i(x, y + size), Vector2i(x + size, y + size), Vector2i(x + size, y)]:
		xs.append(corner.x)
		ys.append(corner.y)
		on.append(1)
	ends.append(xs.size() - 1)
	outline.xs = xs
	outline.ys = ys
	outline.on = on
	outline.ends = ends


# Encodes a simple glyph without instructions, word deltas only.
static func _write_simple(outline: Dictionary) -> PackedByteArray:
	var xs: PackedInt32Array = outline.xs
	var ys: PackedInt32Array = outline.ys
	var out := PackedByteArray()
	_put16(out, (outline.ends as PackedInt32Array).size())
	var lo := Vector2i(xs[0], ys[0])
	var hi := lo
	for i in xs.size():
		lo = Vector2i(mini(lo.x, xs[i]), mini(lo.y, ys[i]))
		hi = Vector2i(maxi(hi.x, xs[i]), maxi(hi.y, ys[i]))
	for value: int in [lo.x, lo.y, hi.x, hi.y]:
		_put16(out, value)
	for end: int in outline.ends:
		_put16(out, end)
	_put16(out, 0)
	for flag: int in outline.on:
		out.append(1 if flag else 0)
	var last := 0
	for x: int in xs:
		_put16(out, x - last)
		last = x
	last = 0
	for y: int in ys:
		_put16(out, y - last)
		last = y
	return out


# Writes the font again: same directory order, 4-byte aligned tables, fresh checksums.
static func _assemble(original: PackedByteArray, tables: Dictionary) -> PackedByteArray:
	var tags: Array = tables.keys()
	var out := original.slice(0, 12)
	var body := PackedByteArray()
	var start := 12 + tags.size() * 16
	var head_at := -1
	for tag: String in tags:
		var bytes: PackedByteArray = tables[tag]
		if tag == "head":
			bytes = bytes.duplicate()
			_set32(bytes, 8, 0)
			head_at = start + body.size()
		out.append_array(tag.to_ascii_buffer())
		_put32(out, _checksum(bytes))
		_put32(out, start + body.size())
		_put32(out, bytes.size())
		body.append_array(bytes)
		while body.size() % 4 != 0:
			body.append(0)
	out.append_array(body)
	if head_at >= 0:
		_set32(out, head_at + 8, (0xB1B0AFBA - _checksum(out)) & 0xFFFFFFFF)
	return out


static func _checksum(bytes: PackedByteArray) -> int:
	var sum := 0
	var i := 0
	while i < bytes.size():
		var word := 0
		for k in 4:
			word = (word << 8) | (bytes[i + k] if i + k < bytes.size() else 0)
		sum = (sum + word) & 0xFFFFFFFF
		i += 4
	return sum


static func _u16(d: PackedByteArray, o: int) -> int:
	return (d[o] << 8) | d[o + 1]


static func _s16(d: PackedByteArray, o: int) -> int:
	var v := _u16(d, o)
	return v - 65536 if v >= 32768 else v


static func _u32(d: PackedByteArray, o: int) -> int:
	return (d[o] << 24) | (d[o + 1] << 16) | (d[o + 2] << 8) | d[o + 3]


static func _put16(out: PackedByteArray, v: int) -> void:
	out.append((v >> 8) & 0xFF)
	out.append(v & 0xFF)


static func _put32(out: PackedByteArray, v: int) -> void:
	for shift: int in [24, 16, 8, 0]:
		out.append((v >> shift) & 0xFF)


static func _set16(d: PackedByteArray, o: int, v: int) -> void:
	d[o] = (v >> 8) & 0xFF
	d[o + 1] = v & 0xFF


static func _set32(d: PackedByteArray, o: int, v: int) -> void:
	for k in 4:
		d[o + k] = (v >> (24 - k * 8)) & 0xFF
