extends SceneTree
## Cached native masks, real hierarchy and upward curse motion.
const Library = preload("res://src/rig/rig_library.gd")
const Poses = preload("res://src/vfx/companion_rigs.gd")
const Art = preload("res://src/vfx/necro_art.gd")
const Icons = preload("res://src/ui/talent_icons.gd")
const Trap = preload("res://src/rig/forest_trap_rig.gd")
var checked := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checked+=1
	if not ok: failures+=1; printerr("FOREST_ART_FAIL: ",label)
func _initialize() -> void:
	var lib := Library.shared()
	var poses := Poses.new()
	for name: String in ["poison_worm","fire_worm"]:
		var rig: Dictionary = lib.rig(name)
		check(rig.parts.size()==8,name+" has eight real source masks")
		var pixels := 0
		for part: Dictionary in rig.parts:
			var image: Image = part.texture.get_image()
			var count := 0
			for y in range(image.get_height()):
				for x in range(image.get_width()):
					if image.get_pixel(x,y).a>0.5: count+=1
			check(count>0,name+" "+str(part.id)+" is nonempty")
			pixels+=count
		var source := Image.load_from_file("res://assets/sprites/companions/forest_worms/"+("poison" if name=="poison_worm" else "fire")+".png")
		var total := 0
		for y in range(40):
			for x in range(32):
				if source.get_pixel(x,y).a>0.5: total+=1
		check(pixels==total,name+" assigns every opaque pixel exactly once")
		var a := poses.forest_worm(rig,{"t":0.2,"moving":true,"clip":"attack","u":0.1})
		var b := poses.forest_worm(rig,{"t":0.6,"moving":true,"clip":"attack","u":0.5})
		check(a!=b,name+" continuous independent part motion")
	var low := Art.rising_curses(Vector2.ZERO,0.2,0)
	var high := Art.rising_curses(Vector2.ZERO,0.4,0)
	check(low.size()==3 and float(high[0].at.y)<float(low[0].at.y),"curse spirits rise along each enemy")
	check(absf(float(high[0].at.x)-float(low[0].at.x))<2,"curse spirit stays on its own side instead of orbiting")
	var spec := {"id":"test","color":"#7cc23a","color2":"#e2ff9e"}
	var icon := Icons.make(spec,"trap",true)
	check(icon.get_width()==48 and icon.get_height()==48,"native forty-eight-pixel detailed icons")
	check(icon==Icons.make(spec,"trap",true),"icon built once and reused")
	check(Trap.parts(Vector2.ZERO,2,0.2,1).size()==9,"eight real rigged trap jaws and hub")
	print("FOREST_ART checked=%d failures=%d"%[checked,failures])
	quit(1 if failures else 0)
