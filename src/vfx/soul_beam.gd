extends RefCounted
## Continuous ribbons leave the animated palm; all range/timing comes from the
## host snapshot. Hard pixel blocks retain the approved soul palette.
const COLORS := [Color("233347"), Color("355e73"), Color("4e9eaa"), Color("83d1ca"), Color("d9f5dc")]
const BeamRig = preload("res://src/rig/soul_beam_rig.gd")
const Spirit = preload("res://src/rig/soul_spirit_rig.gd")

## Shared envelope: preparation, sustained channel and a smooth release.
static func envelope(actor: Dictionary, age: float) -> float:
	var wind := float(actor.get("beam_windup", 0.45))
	var end := wind + float(actor.get("beam_time", 1.6))
	return smoothstep(wind, wind + 0.12, age) * (1.0 - smoothstep(end, float(actor.duration), age))

## Coiling strands travel continuously; their ends taper into the palm and hit.
static func ribbon(distance: float, length: float, age: float, strand: int, art: float) -> float:
	var taper := sin(clampf(distance / maxf(1.0, length), 0.0, 1.0) * PI)
	return sin(distance / (9.0 * art) - age * 6.0 + strand * PI) * (2.0 + 2.5 * taper) * art * taper

## Palm-height casting bends into the enemies' torso plane, following the
## ground trace thereafter. It never extends damage beyond the host's range.
static func point(ground: Vector2, palm: Vector2, aim: Vector2, distance: float, art: float, length: float) -> Vector2:
	var u := clampf(distance / maxf(0.01, length), 0.0, 1.0)
	var end := ground + aim * length - Vector2(0, 12.0 * art)
	var handle := aim * palm.distance_to(end) * 0.33
	return palm.bezier_interpolate(palm + handle, end - handle, end, u)

## Draws only a host-authorized channel. No timers here can deal damage.
static func draw(canvas: CanvasItem, actor: Dictionary, age: float, palm: Vector2, art: float, renderer: RefCounted) -> void:
	if str(actor.get("motion", "")) != "beam": return
	var ground := Vector2(actor.x, actor.y)
	var aim := Vector2(actor.get("aim_x", 1.0), actor.get("aim_y", 0.0)).normalized()
	var normal := aim.orthogonal()
	var wind := maxf(0.01, float(actor.get("beam_windup", 0.45)))
	var power := envelope(actor, age)
	var length := maxf(0.0, float(actor.get("beam_length", 0.0)))
	# Wisps converge into the actual solved hand during the wind-up.
	if age < wind:
		var charge := smoothstep(0.0, wind, age)
		for i in range(16):
			var angle := i * 2.39996 + age * 3.0
			var radius := (1.0 - charge) * (9.0 + i % 5 * 2.0) * art
			var at := palm + Vector2.from_angle(angle) * radius
			canvas.draw_rect(Rect2(at, Vector2.ONE * art), Color(COLORS[2 + i % 3], charge))
	if power <= 0.0 or length <= 0.0: return
	var end := ground+aim*length-Vector2(0,12*art)
	if bool(actor.get("beam_attached",false)):
		end = Vector2(actor.get("beam_socket_x",actor.beam_tx),actor.get("beam_socket_y",actor.beam_ty))
	var reach := smoothstep(wind,wind+0.1,age)
	end = palm.lerp(end,reach)
	renderer.draw_external_rig(canvas,BeamRig.parts(palm,end,age,art,power),ground)
	# Independently rigged spirits flow along the spine and fade at both ends.
	for i in range(int(BeamRig.cfg.travelers)):
		var u := fposmod((age-wind)*float(BeamRig.cfg.travel_rate)+float(i)/float(BeamRig.cfg.travelers),1.0)
		var at := BeamRig.sample(palm,end,u,age,art)
		var alpha := power*pow(sin(u*PI),2)
		if renderer.open(ground+aim*length*u): renderer.draw_external_rig(canvas,Spirit.draw_parts(at,art*0.65,age,alpha,float(i)),ground)
	# A slow, continuous grasp around the live torso makes the lock readable.
	if bool(actor.get("beam_attached",false)):
		for i in range(2):
			var angle := age*float(BeamRig.cfg.impact_orbit_rate)+i*PI
			var at := end+Vector2(cos(angle)*5,sin(angle)*3)*art
			renderer.draw_external_rig(canvas,Spirit.draw_parts(at,art*0.55,age,power*0.85,float(i)+0.4),ground)
	for i in range(12):
		var u := fposmod(age*0.6+i/12.0,1.0)
		var at := BeamRig.sample(palm,end,u,age,art)+normal*sin(age*2.0+i)*art*2
		if renderer.open(ground+aim*length*u): canvas.draw_rect(Rect2(at,Vector2.ONE*art),Color(COLORS[4],power*sin(u*PI)))
