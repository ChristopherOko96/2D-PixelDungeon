extends RefCounted
## Colour ramps of the talent effects (src/vfx/talent_fx.gd, talent_pixels.gd,
## talent_ults.gd), one per element, dark to light: deep/outline, shade, body,
## lite, spec. The spec colour is for single highlight cells only, never a
## white-hot core (art review, production/qa/evidence/talent-vfx-review).
## Presentation only.

## The dark outline under every effect (the 0x72 ink).
const INK := Color("1a1414")
const RAMPS := {
	"fire": [Color("5a1a0a"), Color("b8321a"), Color("ff7a2a"), Color("ffc24a"), Color("ffe9a0")],
	"ice": [Color("1e3a52"), Color("2a5a7a"), Color("4fa0c8"), Color("8fd8e6"), Color("e8fbff")],
	"arcane": [Color("2a1650"), Color("4a2a8a"), Color("7a4ad8"), Color("b07bff"), Color("e6d4ff")],
	"poison": [Color("1e3a10"), Color("2f5a1a"), Color("5aa02a"), Color("8fd65a"), Color("d8ff9a")],
	"beast": [Color("2a2216"), Color("4a3a22"), Color("7a6a3a"), Color("b8a060"), Color("e0cc90")],
	"spirit": [Color("1e2a44"), Color("3a5480"), Color("5a7aa8"), Color("8fb0d8"), Color("d8ecff")],
	"blood": [Color("2a0608"), Color("4a0e12"), Color("8a1a1e"), Color("c8323a"), Color("ff8a7a")],
	"steel": [Color("2a2c36"), Color("4a4e5e"), Color("8a90a4"), Color("d8dce6"), Color("f4f6fa")],
	"gold": [Color("4a3010"), Color("8a6020"), Color("c89a3a"), Color("f3ce7d"), Color("fff0c0")],
}
## Element of each specialisation (talent ids are "<spec>_<n>").
const SPEC_ELEMENT := {"fire": "fire", "frost": "ice", "arcane": "arcane", "sniper": "gold", "trapper": "poison",
	"beast": "beast", "berserk": "blood", "guard": "gold", "blade": "steel"}


## The ramp of `element` (unknown names fall back to steel).
static func ramp(element: String) -> Array:
	return RAMPS.get(element, RAMPS.steel)


## The element a talent's effect is drawn in: its specialisation's, the pack of
## Alpharuf as spirits, else the combat's own `fx` name.
static func element_of(talent: String, fx: String = "") -> String:
	if talent == "beast_6":
		return "spirit"
	var spec := talent.get_slice("_", 0)
	if SPEC_ELEMENT.has(spec):
		return SPEC_ELEMENT[spec]
	return fx if RAMPS.has(fx) else "steel"
