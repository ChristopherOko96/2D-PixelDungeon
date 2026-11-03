extends RefCounted
## Large combat incarnation of the approved eight-part curse spirit.
## Same PNG parts, hierarchy solver and severable body-part path as companions.
const Library = preload("res://src/rig/rig_library.gd")
const Curse = preload("res://src/rig/curse_spirit_rig.gd")
const Poses = preload("res://src/rig/rig_poses.gd")

## Register cached approved cutouts in the host/client's actual combat library.
static func prepare(library: RefCounted) -> void:
	if library.rigs.has("curse_colossus") and library.rigs.has("curse_spawn"): return
	Curse.prepare()
	var rig: Dictionary = Curse.rig.duplicate(true)
	var cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/necromancer_rules.json")).curse.ultimate_monster
	rig.name = "curse_colossus"
	rig.family = "curse_monster"
	rig.ground = Vector2(16,40)
	rig.scale = Library.PIXEL_SCALE*float(cfg.art_scale)
	rig.by_id = {}
	for part: Dictionary in rig.parts:
		part.vital = str(part.id) in ["head","core"]
		part.hp = 3.0 if str(part.id)=="core" else 1.0
		rig.by_id[part.id] = part
	library.rigs.curse_colossus = rig
	var small: Dictionary = rig.duplicate(true)
	small.name = "curse_spawn"
	small.scale = Library.PIXEL_SCALE*float(cfg.brood.art_scale)
	small.by_id = {}
	for part: Dictionary in small.parts: small.by_id[part.id] = part
	library.rigs.curse_spawn = small

## Slow independent claw/jaw/tail motion, with a deliberate two-claw strike.
static func pose(_rig: Dictionary, actor: Dictionary) -> Dictionary:
	var out := Poses.blank()
	var t := float(actor.get("t",0.0))*1.8
	out.whole.dy = sin(t)*1.1
	Poses.P(out,"core").rot = sin(t)*0.035
	Poses.P(out,"head").rot = -sin(t+0.4)*0.07
	Poses.P(out,"jaw").dy = (0.5+0.5*sin(t*1.1))*0.8
	Poses.P(out,"jaw").rot = (0.5+0.5*sin(t*1.1))*0.15
	for n in range(3): Poses.P(out,["tail_root","tail_mid","tail_tip"][n]).rot = sin(t-0.6-n*0.6)*(0.12+n*0.08)
	var strike := 0.0
	if str(actor.get("clip",""))=="attack": strike = sin(clampf(float(actor.get("u",0.0)),0,1)*PI)
	Poses.P(out,"claw_l").rot = -0.15+sin(t+0.3)*0.14-strike*0.6
	Poses.P(out,"claw_r").rot = 0.15-sin(t+0.7)*0.14+strike*0.6
	Poses.P(out,"claw_l").dx = strike*2.5
	Poses.P(out,"claw_r").dx = strike*3.5
	var command := str(actor.get("curse_command",""))
	if not command.is_empty():
		var total := 0.8 if command=="curse_brood" else 0.65
		var progress := clampf(1-float(actor.get("curse_left",0))/total,0,1)
		var lift := sin(progress*PI*0.5)
		Poses.P(out,"claw_l").rot -= lift*1.1
		Poses.P(out,"claw_r").rot += lift*1.1
		Poses.P(out,"claw_l").dy = -lift*3
		Poses.P(out,"claw_r").dy = -lift*3
		Poses.P(out,"jaw").dy += lift*1.5
		out.whole.dy -= lift*2
	var rise := clampf(float(actor.get("blood_morph",0.0)),0,1)
	out.whole.dy += rise*14
	out.whole.sx = 1.0-rise*0.3
	out.whole.sy = 1.0-rise*0.5
	return out
