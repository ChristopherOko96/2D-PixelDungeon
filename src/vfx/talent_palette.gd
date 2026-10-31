extends RefCounted
## Colour ramps of the talent effects (src/vfx/talent_fx.gd, talent_pixels.gd,
## talent_ults.gd), one per element, dark to light: deep/outline, shade, body,
## lite, spec. The spec colour is for single highlight cells only, never a
## white-hot core (art review, production/qa/evidence/talent-vfx-review).
## The Elementsprache (docs/ZAUBER-SPRACHE.de.md): every spell is pixel matter
## of its element; each specialisation has one element (SPEC_ELEMENT) and each
## element one kind of matter (KIND: sparks, shards, drops, motes or chips)
## that its impacts burst into. Presentation only.

## The dark outline under every effect (the 0x72 ink).
const INK := Color("1a1414")
const RAMPS := {
	"fire": [Color("5a1a0a"), Color("b8321a"), Color("ff7a2a"), Color("ffc24a"), Color("ffe9a0")],
	"ice": [Color("1e3a52"), Color("2a5a7a"), Color("4fa0c8"), Color("8fd8e6"), Color("e8fbff")],
	# the void: the void pool's colours (assets/data/vfx_pools.json materials.void)
	"void": [Color("241238"), Color("3a1f5c"), Color("7a3fb8"), Color("c27bff"), Color("f2d9ff")],
	"poison": [Color("1e3a10"), Color("2f5a1a"), Color("5aa02a"), Color("8fd65a"), Color("d8ff9a")],
	"beast": [Color("2a2216"), Color("4a3a22"), Color("7a6a3a"), Color("b8a060"), Color("e0cc90")],
	"spirit": [Color("1e2a44"), Color("3a5480"), Color("5a7aa8"), Color("8fb0d8"), Color("d8ecff")],
	"blood": [Color("2a0608"), Color("4a0e12"), Color("8a1a1e"), Color("c8323a"), Color("ff8a7a")],
	"steel": [Color("2a2c36"), Color("4a4e5e"), Color("8a90a4"), Color("d8dce6"), Color("f4f6fa")],
	"gold": [Color("4a3010"), Color("8a6020"), Color("c89a3a"), Color("f3ce7d"), Color("fff0c0")],
	# earthy grey-brown stone (the guard)
	"stone": [Color("2a231c"), Color("4a3f33"), Color("7a6a58"), Color("a89880"), Color("d8ccb4")],
	# off-white bone (the necromancer's minions)
	"bone": [Color("3a3328"), Color("6a5e4c"), Color("b8aa90"), Color("e6dcc4"), Color("fff8ec")],
	# dark red-violet curse
	"curse": [Color("2a0a22"), Color("4a1440"), Color("7a2a6a"), Color("b04a9a"), Color("e68ad0")],
	# pale blue-violet soul
	"soul": [Color("1e1e3e"), Color("3a3a74"), Color("6a6ab8"), Color("9a9ee6"), Color("dcdcff")],
	# water (the wet residue; vfx_pools.json materials.water)
	"water": [Color("173a5e"), Color("2a6a9e"), Color("4fa0c8"), Color("8fd8e6"), Color("e8fbff")],
}
## Element names other systems use for the same matter (talents.json fx, zone
## looks, statuses): the Arkanmagier is the Leerenmagier.
const ALIASES := {"arcane": "void", "frost": "ice", "snow": "ice", "flames": "fire", "firewall": "fire", "lava": "fire", "burn": "fire",
	"crater": "fire", "plague": "poison", "souls": "soul", "magic": "void", "bleed": "blood"}
## Element of each specialisation (talent ids are "<spec>_<n>").
const SPEC_ELEMENT := {"fire": "fire", "frost": "ice", "arcane": "void", "sniper": "gold", "trapper": "poison",
	"beast": "beast", "berserk": "blood", "guard": "stone", "blade": "steel", "minion": "bone", "curse": "curse", "soul": "soul"}
## The matter of each element: what its impacts burst into (src/vfx/particles.gd).
const KIND := {"fire": "spark", "gold": "spark", "steel": "spark", "ice": "shard", "bone": "shard", "poison": "drop", "blood": "drop",
	"water": "drop", "void": "mote", "soul": "mote", "spirit": "mote", "curse": "mote", "stone": "chip", "beast": "chip"}


## The element name `element` stands for (aliases resolved; unknown names stay).
static func resolve(element: String) -> String:
	return str(ALIASES.get(element, element))


## The ramp of `element` (aliases resolved; unknown names fall back to steel).
static func ramp(element: String) -> Array:
	return RAMPS.get(resolve(element), RAMPS.steel)


## The ramp of `element` the particles' way round: spec, lite, body, shade, deep.
static func ramp_hot(element: String) -> Array:
	var r: Array = ramp(element)
	return [r[4], r[3], r[2], r[1], r[0]]


## The matter kind of `element`: spark, shard, drop, mote or chip.
static func kind(element: String) -> String:
	return str(KIND.get(resolve(element), "spark"))


## The element a talent's effect is drawn in: its specialisation's, the pack of
## Alpharuf as spirits, else the combat's own `fx` name (aliases resolved).
static func element_of(talent: String, fx: String = "") -> String:
	if talent == "beast_14":
		return "spirit"
	var spec := talent.get_slice("_", 0)
	if SPEC_ELEMENT.has(spec):
		return SPEC_ELEMENT[spec]
	var named := resolve(fx)
	return named if RAMPS.has(named) else "steel"
