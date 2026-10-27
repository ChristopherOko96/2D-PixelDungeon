extends RefCounted
## World-sized, nearest-pixel crypt actors; the legacy 0x72 actors stay at2x.
const KINDS := ["skeleton_archer","necromancer","skeleton_guard"]
const ROOT := "res://assets/sprites/crypt_enemies/"
var _frames: Dictionary = {}

## Load all animation frames once, allowing the view to prepare its flash masks.
func prepare() -> Array[Texture2D]:
	var textures: Array[Texture2D] = []
	for kind: String in KINDS:
		var animations: Dictionary = {}
		for animation: String in ["idle","run","attack"]:
			var frames: Array[Texture2D] = []
			for index: int in range(4):
				var path: String = "%s%s_%s_f%d.png" % [ROOT,kind,animation,index]
				if not ResourceLoader.exists(path): continue
				var texture: Texture2D = load(path)
				frames.append(texture)
				textures.append(texture)
			animations[animation] = frames
		_frames[kind] = animations
	return textures

## Attack anticipation, release and recovery reuse the same host phase clocks.
func frame(kind: String, entity: Dictionary, clock: float) -> Texture2D:
	var animations: Dictionary = _frames.get(kind,{})
	if animations.is_empty(): return null
	var phase: String = str(entity.get("attack",""))
	var animation: String = "run" if bool(entity.get("moving",false)) else "idle"
	var index: int = posmod(int(clock*8.0)+int(entity.get("id",0)),4)
	if phase in ["windup","active","recovery"] and float(entity.get("dying_p",-1.0)) < 0:
		animation = "attack"
		index = mini(1,int(float(entity.get("attack_p",0.0))*2.0)) if phase == "windup" else 2 if phase == "active" else 3
	var frames: Array = animations.get(animation,[])
	return frames[index%frames.size()] if not frames.is_empty() else null
