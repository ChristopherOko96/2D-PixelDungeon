extends RefCounted
## Pure rules for the hell monsters (data in assets/data/hell_monsters.json):
## which attack goes next, when a monster cannot be hit, what Ignaroth turns into,
## how much HP a monster has, and which animation frame shows. No scene access.

## Attack kinds whose animation is the cast pose (when the monster has one).
const CAST_KINDS := ["summon", "ring", "spiral", "meteors", "hands", "beam", "scream", "teleport"]
## Attack kinds the dragon runtime plays (burrowing, flying, sweeping breath, echoes).
const DRAGON_KINDS := ["burrow", "flight", "sweep", "echoes"]
const VOID_IDS := ["peingeist", "klagender_hueter", "drache4"]
const SOUL_IDS := ["aschenpriester", "seelenhirte"]


## Of all ready attacks in range, the one that has waited longest; -1 if none.
## A passive "trail" attack is never chosen.
static func pick_attack(attacks: Array, cds: Array, dist: float) -> int:
	var best := -1
	for k in range(attacks.size()):
		var a: Dictionary = attacks[k]
		if float(cds[k]) > 0.0 or a.kind == "trail" or dist > float(a.get("range", 99999.0)):
			continue
		if best < 0 or float(cds[k]) < float(cds[best]):
			best = k
	return best


## Cooldown before the first use: `first` when set, else a share of `every` from roll (0-1).
static func first_cooldown(a: Dictionary, roll: float) -> float:
	if a.has("first"):
		return float(a.first)
	return float(a.every) * (0.35 + roll * 0.5)


## Cooldown after a use: bosses keep their rhythm, mobs vary by roll (0-1).
static func next_cooldown(a: Dictionary, boss: bool, roll: float) -> float:
	return float(a.every) * (1.0 if boss else 0.9 + roll * 0.3)


## True while the monster arrives, transforms, dies, burrows or flies above min_alt.
static func is_immune(m: Dictionary, min_alt: float) -> bool:
	return m.get("intro") != null or m.get("trans") != null or m.get("dying") != null \
		or bool(m.get("burrowed", false)) or float(m.get("alt", 0.0)) > min_alt


## True for one of Ignaroth's forms.
static func is_lord(def: Dictionary) -> bool:
	return def.get("kind", "") == "lord"


## The form a lord changes into at 0 HP, or "" when it dies for good (the last phase).
static func next_form(defs: Dictionary, id: String) -> String:
	var def: Dictionary = defs[id]
	if not is_lord(def):
		return ""
	for other: String in defs:
		var o: Dictionary = defs[other]
		if is_lord(o) and int(o.phase) == int(def.phase) + 1:
			return other
	return ""


## HP of a new monster: a boss takes the floor's boss HP, a mob its own HP times the floor toughness.
static func spawn_hp(stats: Dictionary, boss: bool, floor_boss_hp: float, diff_hp: float) -> float:
	if boss:
		return round(floor_boss_hp * float(stats.get("hpMul", 1.0)))
	return round(float(stats.get("hp", 1.0)) * diff_hp)


## The animation an attack plays.
static func act_anim(kind: String, def: Dictionary) -> String:
	if kind in CAST_KINDS and def.anims.has("cast"):
		return "cast"
	return "attack"


## Frames per second: smooth 8-frame sets run faster than the classic 4-frame ones.
static func anim_fps(frames: int, anim: String) -> float:
	if frames >= 8:
		return 9.0 if anim == "idle" else (11.0 if anim == "fly" else 13.0)
	return 6.0 if anim == "idle" else (8.0 if anim == "death" else 10.0)


## Animation row and frame column of the atlas at the given time in the animation.
## A missing animation falls back to idle.
static func frame_of(def: Dictionary, anim: String, time: float) -> Vector2i:
	var a: Dictionary = def.anims.get(anim, def.anims.idle)
	var n := int(a.frames)
	return Vector2i(int(floor(time * anim_fps(n, anim))) % n, int(a.row))


## Colour of a monster's shots: fire, void (violet) or soul (green).
static func shot_color(id: String, echo: bool) -> String:
	if echo or id in VOID_IDS:
		return "void"
	return "soul" if id in SOUL_IDS else "fire"


## Attacks an echo of an earlier form keeps (no burrowing, flying or summoning).
static func echo_attacks(attacks: Array, kinds: Array) -> Array:
	return attacks.filter(func(a: Dictionary) -> bool: return a.kind in kinds)


## Smoothstep 0-1, clamped.
static func smooth(k: float) -> float:
	k = clampf(k, 0.0, 1.0)
	return k * k * (3.0 - 2.0 * k)


## Smallest absolute angle between two directions, in radians.
static func angle_gap(a: float, b: float) -> float:
	return absf(wrapf(a - b, -PI, PI))


## Text after the boss name on the health bar.
static func boss_status(m: Dictionary, min_alt: float) -> String:
	if m.get("trans") != null:
		return " · verwandelt sich"
	if m.get("dying") != null:
		return " · fällt"
	if m.get("intro") != null:
		return " · erscheint"
	if float(m.get("alt", 0.0)) > min_alt:
		return " · in der Luft"
	if bool(m.get("burrowed", false)):
		return " · im Boden"
	return ""
