// Crypt void fog (Claude Code session, 2026-10-29).
// Purpose: a faint violet mist drifting slowly through the crypt rooms in a
// few wisps. Two or three layers of value noise move with their own wind and
// are stretched sideways into swathes; one layer bends the other (domain warp)
// so the wisps curl. The result is sampled on the art's pixel grid (2 world px
// = one 0x72 pixel) and stepped into a few alpha bands, so the fog reads as
// pixel art, not as a soft gradient.
// Target: every desktop renderer; one quad over the room, no texture reads,
// at most 3 layers x 3 octaves of hash noise per fragment.
// Fed by src/vfx/crypt_atmosphere.gd (CryptFog); values come from
// assets/data/vfx_crypt_atmosphere.json "fog". `clock` is the view's own
// clock, so a frozen view freezes the fog too.
shader_type canvas_item;

const int MAX_LAYERS = 3;
// fbm: three octaves, each about twice as fine and half as strong; the
// offsets keep the octaves from lining up.
const vec3 OCTAVE_WEIGHTS = vec3(0.57, 0.29, 0.14);
const vec2 OCTAVE_SCALES = vec2(2.03, 4.07);
const vec2 OCTAVE_OFFSETS = vec2(17.1, 41.7);
// Each layer starts elsewhere in the noise; the warp bends less upward than sideways.
const float LAYER_OFFSET = 13.7;
const float WARP_VERTICAL = 0.4;

group_uniforms fog;
uniform vec4 fog_color : source_color = vec4(0.506, 0.337, 0.667, 1.0);
// Alpha of the densest wisp (0..1); keep it low.
uniform float density : hint_range(0.0, 1.0) = 0.2;
// Noise level where fog starts; higher = fewer, thinner wisps.
uniform float coverage : hint_range(0.0, 1.0) = 0.5;
// Noise range over which a wisp fades in.
uniform float softness : hint_range(0.01, 1.0) = 0.16;
// Horizontal stretch of the wisps (1 = round blobs).
uniform float stretch : hint_range(0.5, 6.0) = 2.6;
// How strongly the first layer bends the others.
uniform float warp : hint_range(0.0, 3.0) = 0.9;
// World px per fog pixel and the number of alpha steps.
uniform float pixel : hint_range(1.0, 8.0) = 2.0;
uniform float bands : hint_range(1.0, 16.0) = 4.0;
// Per layer: x = size in world px, yz = wind in world px per second, w = weight.
uniform vec4 layers[MAX_LAYERS];
uniform int layer_count = 2;
uniform float clock = 0.0;
group_uniforms;

varying vec2 world_position;

void vertex() {
	// The fog node sits at the world origin, so local = world pixels.
	world_position = VERTEX;
}

// Hash without sine (stable on every GPU for the coordinates used here).
float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	return value_noise(p) * OCTAVE_WEIGHTS.x
		+ value_noise(p * OCTAVE_SCALES.x + OCTAVE_OFFSETS.x) * OCTAVE_WEIGHTS.y
		+ value_noise(p * OCTAVE_SCALES.y + OCTAVE_OFFSETS.y) * OCTAVE_WEIGHTS.z;
}

void fragment() {
	vec2 cell = floor(world_position / pixel) * pixel + pixel * 0.5;
	float total = 0.0;
	float weights = 0.0;
	float bend = 0.0;
	for (int i = 0; i < MAX_LAYERS; i++) {
		// Unused layers weigh zero without branching.
		float used = step(float(i) + 0.5, float(layer_count));
		vec4 layer = layers[i];
		vec2 p = (cell - layer.yz * clock) / (max(layer.x, 1.0) * vec2(stretch, 1.0));
		float n = fbm(p + vec2(1.0, WARP_VERTICAL) * bend * warp + float(i) * LAYER_OFFSET);
		// The first layer's noise bends the later ones (no branch).
		bend = mix(n, bend, step(0.5, float(i)));
		total += n * layer.w * used;
		weights += layer.w * used;
	}
	float fog = smoothstep(coverage, coverage + softness, total / max(weights, 0.001));
	fog = floor(fog * bands + 0.5) / bands;
	COLOR = vec4(fog_color.rgb, fog * density);
}
