extends RefCounted
## The perk markers over a fight (src/perk_combat.gd visual_events: kind, x,
## y, tx, ty, time counting down from LIFE s), shared by the crypt
## (src/dungeon_view.gd) and the story worlds (src/hero/story_feel.gd), on the
## 2 px art grid. A chain is a bolt of lightning (src/vfx/pixel_bolt.gd: there
## at once, bright for a moment, an afterimage, then gone); a heal or revive is
## a green cross of light lifting off the hero and thinning by the dither; a
## blast, crit or shield is a ring of eight blocks spreading out and thinning.
## Pure drawing from the event's own clock (no state).

const PixelBolt = preload("res://src/vfx/pixel_bolt.gd")
const PixelPaint = preload("res://src/vfx/pixel_paint.gd")
const GOLD := Color("f6cf85")
const GREEN := Color("a7ddaa")
const BLUE := Color("a7cce8")
## Seconds a marker lives (balance perk_combat event_duration, 0.22 by default).
const LIFE := 0.22
## The lightning of a perk chain: white-hot, a cool blue, deep blue (afterimage).
const CHAIN := [Color("f4f6ff"), Color("a7cce8"), Color("3a3a8a")]
## How fast a heal's cross lifts off (px/s).
const LIFT := 60.0


## Draws every marker of `events` on `canvas` (world px of the crypt grid).
static func draw(canvas: CanvasItem, events: Array) -> void:
	for event: Dictionary in events:
		var point := Vector2(float(event.x), float(event.y)).round()
		var kind := str(event.kind)
		var age := maxf(0.0, LIFE - float(event.get("time", LIFE)))
		var left := clampf(1.0 - age / LIFE, 0.0, 1.0)
		var tint: Color = GOLD if kind in ["blast", "crit"] else GREEN if kind in ["heal", "poison"] else BLUE
		if kind == "chain":
			var end := Vector2(float(event.tx), float(event.ty)).round()
			PixelBolt.draw(canvas, point + Vector2(0, -12), end + Vector2(0, -12), age, int(point.x) * 31 + int(end.y), 2.0, CHAIN, 0.2, 1)
		elif kind in ["heal", "revive"]:
			var c := point + Vector2(0, -20.0 - floorf(age * LIFT / 2.0) * 2.0)
			for r: Rect2 in [Rect2(c.x - 2.0, c.y - 6.0, 4.0, 12.0), Rect2(c.x - 6.0, c.y - 2.0, 12.0, 4.0)]:
				for gy in range(int(floor(r.position.y / 2.0)), int(floor(r.end.y / 2.0))):
					for gx in range(int(floor(r.position.x / 2.0)), int(floor(r.end.x / 2.0))):
						var q := Vector2i(gx, gy)
						if PixelPaint.shown(q, left * 1.4):
							PixelPaint.cell(canvas, q, tint, 2.0)
		else:
			var radius := (16.0 if kind in ["shield", "crit"] else 28.0) * (0.8 + 0.45 * (1.0 - left))
			for index in range(8):
				var offset := (Vector2.from_angle(TAU * float(index) / 8.0) * radius).round()
				if not PixelPaint.shown(Vector2i(((point + offset) / 2.0).floor()), left * 1.5):
					continue
				canvas.draw_rect(Rect2(floorf(point.x + offset.x - 2.0), floorf(point.y + offset.y - 2.0), 4.0, 4.0), tint)
